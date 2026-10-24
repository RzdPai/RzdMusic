/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { http } from '@kit.NetworkKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MotionCover, MotionCoverKind } from '../model/MotionCover';
import { getAppRuntime } from '../model/AppRuntimeStorage';

/**
 * Apple Music **动态封面（motion artwork）**解析服务 —— 纯 SSR 抓网页，不需要 token/账号。
 *
 * 实现规格：`RzdMusic/docs/apple-motion-cover.md`（甲方给的说明）。
 *
 * ```
 * 名字 ──① 搜索页 https://music.apple.com/{cc}/search?term=… ──► 实体 id + slug + 封面
 *      └─② 详情页 https://music.apple.com/{cc}/{artist|album|playlist}/… ──► motion.*
 *            { video: https://mvod.itunes.apple.com/…/xxx_default.m3u8,
 *              poster: https://is1-ssl.mzstatic.com/…/900x900bb.jpg }
 * ```
 *
 * ## 几条必须记住的约束（都是规格里"必踩的坑"）
 * 1. **不带 `Origin`**：Apple 用它做防盗链（curl 200 / 浏览器 fetch 403）。本服务只发 UA + Accept-Language。
 * 2. **名字别用 `aria-label`**：中间是 `U+2004`（三分空格）。用 href 的 slug 做 `decodeURIComponent`。
 * 3. **图片模板四个占位符全替换**（`{w}{h}{c}{f}`），少一个就 404。
 * 4. **视频字段不能用跨段懒匹配**：整页 HTML 压缩成一行，`.*?` 会跨字段误匹配。
 *    这里一律 `indexOf` 定位 + **定长截取**。
 * 5. **负结果也要缓存**：多数实体没有投放 motion，不缓存就会每次进页面都重拉 ~690KB。
 *
 * ## 缓存
 * | key | TTL | 说明 |
 * | --- | --- | --- |
 * | `s_{kind}_{name}` | 7 天 | 名字 → id/slug |
 * | `e_{kind}_{name}` | 24 小时 | 详情页结果（**无动态封面也缓存**） |
 *
 * 内存 Map 做一级缓存，`preferences`（`rzd_motion_cover`）做跨进程/跨次启动的二级缓存。
 * 同一 key 的并发请求在途去重（`inflight`），避免三个页面同时解析同一实体。
 *
 * 排查关键字：`RzdMotionCover`（search/entity/motion/cache 四类日志）。
 */
const LOG_TAG: string = 'RzdMotionCover';
/** 二级缓存（preferences）文件名。 */
const STORE_NAME: string = 'rzd_motion_cover';
const UA: string = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
/** 店面：`cn` 返简体；`hk`/`tw` 繁体；`us`/`jp` 对应语言（名字简繁不一致属正常）。 */
const STOREFRONT: string = 'cn';
const SEARCH_TTL_MS: number = 7 * 24 * 3600 * 1000;
const ENTITY_TTL_MS: number = 24 * 3600 * 1000;
/** 详情页里 `motion*` 字段的定长截取窗口（规格要求 ~1400，这里留余量）。 */
const MOTION_BLOCK_LEN: number = 1600;
/** 搜索页最多扫多少个 marker（页面内嵌 JSON 会先占掉几百个）。 */
const MAX_SCAN_MARKERS: number = 900;
/** 搜索页最多采纳多少个**解析成功**的候选链接。 */
const MAX_SEARCH_CANDIDATES: number = 40;

/** 一条缓存（内存级）。 */
class CacheEntry {
  public value: string = '';
  public until: number = 0;

  public constructor(value: string, until: number) {
    this.value = value;
    this.until = until;
  }
}

/** 搜索页解析出的「实体定位信息」。 */
class SearchHit {
  public storefront: string = '';
  public slug: string = '';
  public id: string = '';
  public pageUrl: string = '';

  public valid(): boolean {
    return this.id.length > 0 && this.pageUrl.length > 0;
  }
}

export class MotionCoverService {
  private static instance: MotionCoverService | undefined = undefined;
  private memory: Map<string, CacheEntry> = new Map();
  private inflight: Map<string, Promise<MotionCover | undefined>> = new Map();
  private store: preferences.Preferences | undefined = undefined;
  private storeTried: boolean = false;

  public static getInstance(): MotionCoverService {
    if (MotionCoverService.instance === undefined) {
      MotionCoverService.instance = new MotionCoverService();
    }
    return MotionCoverService.instance;
  }

  /**
   * 查一个实体的动态封面（**有缓存**；没有就返回 `undefined`，负结果同样入缓存）。
   * @param kind 实体类型
   * @param name 实体名（歌手名 / 专辑名 / 歌单名）
   * @param artist 专辑页建议带上歌手名（同名专辑靠它挑对）
   */
  public async resolve(kind: MotionCoverKind, name: string, artist: string = ''): Promise<MotionCover | undefined> {
    const query: string = MotionCoverService.normalize(name);
    if (query.length === 0) {
      return undefined;
    }
    const key: string = `e_${kind}_${query}_${MotionCoverService.normalize(artist)}`;
    const cached: string | undefined = this.readCache(key);
    if (cached !== undefined) {
      const hit: MotionCover | undefined = MotionCoverService.decode(cached);
      hilog.info(0, LOG_TAG, 'cache entity kind=%{public}s hit=%{public}d name=%{public}s',
        kind, hit !== undefined ? 1 : 0, query);
      return hit;
    }
    const running: Promise<MotionCover | undefined> | undefined = this.inflight.get(key);
    if (running !== undefined) {
      return running;
    }
    const job: Promise<MotionCover | undefined> = this.fetchByKind(kind, query, MotionCoverService.normalize(artist));
    this.inflight.set(key, job);
    let result: MotionCover | undefined = undefined;
    try {
      result = await job;
    } catch (err) {
      hilog.warn(0, LOG_TAG, 'resolve failed kind=%{public}s err=%{public}s', kind, JSON.stringify(err));
      result = undefined;
    }
    this.inflight.delete(key);
    this.writeCache(key, result === undefined ? '' : MotionCoverService.encode(result), ENTITY_TTL_MS);
    return result;
  }

  /** 名字 → 搜索页候选 → 详情页 → motion。 */
  private async fetchByKind(kind: MotionCoverKind, name: string, artist: string): Promise<MotionCover | undefined> {
    const hit: SearchHit = await this.search(kind, name, artist);
    if (!hit.valid()) {
      hilog.info(0, LOG_TAG, 'search miss kind=%{public}s name=%{public}s', kind, name);
      return undefined;
    }
    const html: string = await this.getHtml(hit.pageUrl);
    if (html.length === 0) {
      return undefined;
    }
    const motion: MotionCover | undefined = MotionCoverService.extractMotion(html);
    hilog.info(0, LOG_TAG, 'motion kind=%{public}s name=%{public}s id=%{public}s field=%{public}s',
      kind, name, hit.id, motion !== undefined ? motion.field : 'none');
    if (motion === undefined) {
      return undefined;
    }
    // 海报缺失时退回搜索页给的封面（至少不会白屏）
    if (motion.posterUrl.length === 0 && hit.slug.length > 0) {
      return new MotionCover(motion.videoUrl, '', motion.field);
    }
    return motion;
  }

  /** 名字 → id/slug（带 7 天缓存）。 */
  private async search(kind: MotionCoverKind, name: string, artist: string): Promise<SearchHit> {
    const key: string = `s_${kind}_${name}_${artist}`;
    const cached: string | undefined = this.readCache(key);
    if (cached !== undefined) {
      return MotionCoverService.decodeHit(cached);
    }
    const url: string = `https://music.apple.com/${STOREFRONT}/search?term=${encodeURIComponent(name)}`;
    const html: string = await this.getHtml(url);
    const hit: SearchHit = html.length > 0
      ? MotionCoverService.parseSearch(html, kind, name, artist)
      : new SearchHit();
    this.writeCache(key, MotionCoverService.encodeHit(hit), SEARCH_TTL_MS);
    return hit;
  }

  // ────────────────────────────── 解析（纯函数，可离线核对） ──────────────────────────────

  /**
   * 解析搜索页：找**第一个名字对得上**的实体链接（规格 §2.1）。
   *
   * ⚠️ 不能用 `aria-label`（名字与"艺人"之间是 `U+2004`）；用 href 的 slug 解码。
   * ⚠️ 首个 `/artist/` 链接不一定精确（推荐位里还有相关艺人）⇒ 名字包含校验 + 歌手里程碑加成。
   */
  public static parseSearch(html: string, kind: MotionCoverKind, name: string, artist: string): SearchHit {
    const seg: string = kind === MotionCoverKind.ARTIST ? 'artist'
      : (kind === MotionCoverKind.ALBUM ? 'album' : 'playlist');
    const marker: string = '/' + seg + '/';
    const artistNeedle: string = artist.length > 0 ? artist : '';
    let best: SearchHit = new SearchHit();
    let bestScore: number = 0;
    let from: number = 0;
    let scanned: number = 0;
    let accepted: number = 0;
    while (scanned < MAX_SCAN_MARKERS && accepted < MAX_SEARCH_CANDIDATES) {
      const at: number = html.indexOf(marker, from);
      if (at < 0) {
        break;
      }
      scanned++;
      from = at + marker.length;
      // 实体地址有两种写法：搜索结果里的 `href="https://music.apple.com/…"`，
      // 以及页面内嵌 JSON 里的 `"url":"https://music.apple.com/…"`。
      // ⚠️ 前端那一段 `<script>` 里的 JSON 会先出现几百个 marker，全是没有 `href=` 上下文的，
      //   所以"扫描上限"必须与"采纳上限"分开（否则真正的链接还没走到就放弃了）。
      const hAt: number = html.lastIndexOf('href="', at);
      const uAt: number = html.lastIndexOf('"url":"', at);
      let start: number = -1;
      let skip: number = 0;
      if (hAt >= uAt && hAt >= 0) {
        start = hAt;
        skip = 6;
      } else if (uAt >= 0) {
        start = uAt;
        skip = 7;
      }
      if (start < 0 || at - start > 96) {
        continue;
      }
      const hrefEnd: number = html.indexOf('"', at);
      if (hrefEnd < 0) {
        continue;
      }
      const href: string = html.substring(start + skip, hrefEnd);
      const hit: SearchHit = MotionCoverService.parseHref(href, seg);
      if (hit.id.length === 0 || hit.slug.length === 0) {
        continue;
      }
      accepted++;
      let score: number = 0;
      // ⚠️ 两侧都要归一化再比：`name` 是小写归一化后的查询词，slug 是网页原文（可能带大写/空格）。
      // ⚠️ 歌单**不做相似度"猜"**：Apple 的编辑歌单名多数与我们的歌单名不同，
      //    硬凑只会把**别的歌单的封面**播出来（观感就是"封面换错了"）。
      //    ⇒ 只接受"包含关系"（如「国语流行」⊂「热播金曲-国语流行」），否则整页保持静态。
      const slugNorm: string = MotionCoverService.normalize(hit.slug);
      if (slugNorm.indexOf(name) >= 0 || name.indexOf(slugNorm) >= 0) {
        score += 3;
      }
      if (artistNeedle.length > 0) {
        const nearFrom: number = Math.max(0, start - 1600);
        const nearTo: number = Math.min(html.length, hrefEnd + 1600);
        if (html.substring(nearFrom, nearTo).toLowerCase().indexOf(artistNeedle) >= 0) {
          score += 2;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = hit;
      }
      if (score >= 5) {
        break;
      }
    }
    if (bestScore < 3) {
      return new SearchHit();
    }
    return best;
  }

  /** `cn/artist/周杰伦/300117743?l=en`（或带 scheme 的完整 URL）→ 结构化定位信息。 */
  private static parseHref(href: string, seg: string): SearchHit {
    const out: SearchHit = new SearchHit();
    let path: string = href;
    const hostAt: number = path.indexOf('music.apple.com/');
    if (hostAt >= 0) {
      path = path.substring(hostAt + 'music.apple.com/'.length);
    }
    const queryAt: number = path.indexOf('?');
    if (queryAt >= 0) {
      path = path.substring(0, queryAt);
    }
    const parts: string[] = path.split('/');
    if (parts.length < 4 || parts[1] !== seg) {
      return out;
    }
    out.storefront = parts[0];
    try {
      out.slug = decodeURIComponent(parts[2]);
    } catch (err) {
      out.slug = parts[2];
    }
    out.id = parts[3];
    const cc: string = out.storefront.length > 0 ? out.storefront : STOREFRONT;
    if (seg === 'artist') {
      out.pageUrl = `https://music.apple.com/${cc}/artist/${out.id}`;
    } else if (seg === 'album') {
      out.pageUrl = `https://music.apple.com/${cc}/album/${out.id}`;
    } else {
      out.pageUrl = `https://music.apple.com/${cc}/playlist/${encodeURIComponent(out.slug)}/${out.id}`;
    }
    return out;
  }

  /**
   * 从详情页 HTML 里抽 motion（规格 §3.2）：反转义 → `indexOf` 定位 → 定长截取 → 正则取值。
   *
   * 字段优先级（竖屏手机用 1:1）：
   * `motionArtistSquare1x1` → `motionDetailSquare` → `motionArtistWide16x9` → `motionDetailTall`
   * → `motionArtistFullscreen16x9` → 兜底：任何 `.m3u8`。
   */
  public static extractMotion(html: string): MotionCover | undefined {
    const text: string = html.split('\\"').join('"');
    const keys: string[] = [
      'motionArtistSquare1x1',
      'motionDetailSquare',
      'motionArtistWide16x9',
      'motionDetailTall',
      'motionArtistFullscreen16x9',
      'motionDetailFullscreen'
    ];
    for (let i = 0; i < keys.length; i++) {
      const at: number = text.indexOf('"' + keys[i] + '":');
      if (at < 0) {
        continue;
      }
      const block: string = text.substring(at, Math.min(text.length, at + MOTION_BLOCK_LEN));
      const video: string = MotionCoverService.firstGroup(block, 0);
      if (video.length === 0) {
        continue;
      }
      const posterRaw: string = MotionCoverService.firstGroup(block, 1);
      const poster: string = posterRaw.length > 0 ? MotionCoverService.fillTemplate(posterRaw, 900) : '';
      return new MotionCover(video, poster, keys[i]);
    }
    return MotionCoverService.scanAnyM3u8(text);
  }

  /**
   * 兜底：整页扫第一个 `"video":"…m3u8"`，并往**前**找海报 URL。
   * 规格里的结构是 `"previewFrame":{"url":"…"},"video":"…m3u8"` ⇒ 海报在视频**前面**。
   */
  private static scanAnyM3u8(text: string): MotionCover | undefined {
    let from: number = 0;
    while (true) {
      const at: number = text.indexOf('.m3u8', from);
      if (at < 0) {
        return undefined;
      }
      from = at + 5;
      const head: number = text.lastIndexOf('"video":"', at);
      if (head < 0 || at - head > 1200) {
        continue;
      }
      const start: number = head + '"video":"'.length;
      const end: number = text.indexOf('"', start);
      if (end <= start) {
        continue;
      }
      const video: string = text.substring(start, end);
      const backFrom: number = Math.max(0, head - 600);
      const posterRaw: string = MotionCoverService.lastUrlBefore(text.substring(backFrom, head));
      const poster: string = posterRaw.length > 0 ? MotionCoverService.fillTemplate(posterRaw, 900) : '';
      return new MotionCover(video, poster, 'scan');
    }
  }

  /** 取块内第 n 个"取值"结果：0 = `"video":"…"`，1 = `"url":"…"`。 */
  private static firstGroup(block: string, which: number): string {
    const key: string = which === 0 ? '"video"' : '"url"';
    const at: number = block.indexOf(key);
    if (at < 0) {
      return '';
    }
    const colon: number = block.indexOf(':', at + key.length);
    if (colon < 0) {
      return '';
    }
    let start: number = colon + 1;
    while (start < block.length && block.charAt(start) === ' ') {
      start++;
    }
    if (start >= block.length || block.charAt(start) !== '"') {
      return '';
    }
    start++;
    const end: number = block.indexOf('"', start);
    return end > start ? block.substring(start, end) : '';
  }

  /** 文本里**最后一个** `https://is*.mzstatic.com/…` 图片（海报在视频前面，所以取最后一个）。 */
  private static lastUrlBefore(text: string): string {
    const needle: string = 'mzstatic.com/';
    let at: number = text.lastIndexOf(needle);
    if (at < 0) {
      return '';
    }
    let start: number = at;
    while (start > 0) {
      const ch: string = text.charAt(start - 1);
      if (ch === '"' || ch === ' ' || ch === '{' || ch === ',') {
        break;
      }
      start--;
    }
    let end: number = at + needle.length;
    while (end < text.length) {
      const ch: string = text.charAt(end);
      if (ch === '"' || ch === ' ' || ch === '}' || ch === ',') {
        break;
      }
      end++;
    }
    const url: string = text.substring(start, end);
    return url.indexOf('http') === 0 ? url : '';
  }

  /** 图片模板四个占位符全替换（少一个就 404）。 */
  public static fillTemplate(url: string, size: number): string {
    const n: string = String(size);
    return url.split('{w}').join(n).split('{h}').join(n)
      .split('{c}').join('bb').split('{f}').join('jpg');
  }

  /** 名字归一化：去空白、去零宽、全角空格，小写。 */
  public static normalize(name: string): string {
    let out: string = name;
    out = out.split('\u2004').join('').split('\u200b').join('').split('\u3000').join(' ');
    out = out.split('\n').join(' ').split('\r').join(' ').split('\t').join(' ');
    out = out.split('（').join('(').split('）').join(')');
    while (out.indexOf('  ') >= 0) {
      out = out.split('  ').join(' ');
    }
    return out.trim().toLowerCase();
  }

  // ────────────────────────────── 网络 ──────────────────────────────

  /**
   * 拉一页 HTML。**不带 `Origin`**（Apple 用它做防盗链，带了必 403）。
   * @param url 目标地址
   * @returns HTML 文本；失败返回空串（调用方按"没有结果"处理）
   */
  private async getHtml(url: string): Promise<string> {
    const client: http.HttpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = {};
      headers['User-Agent'] = UA;
      headers['Accept-Language'] = 'zh-CN,zh;q=0.9';
      headers['Accept'] = 'text/html,application/xhtml+xml';
      const resp: http.HttpResponse = await client.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 20000,
        header: headers,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200) {
        hilog.warn(0, LOG_TAG, 'http %{public}d url=%{public}s', resp.responseCode, url);
        return '';
      }
      const body: string | Object | ArrayBuffer = resp.result;
      if (typeof body === 'string') {
        return body as string;
      }
      return '';
    } catch (err) {
      hilog.warn(0, LOG_TAG, 'http failed url=%{public}s err=%{public}s', url, JSON.stringify(err));
      return '';
    } finally {
      client.destroy();
    }
  }

  // ────────────────────────────── 缓存 ──────────────────────────────

  private getStore(): preferences.Preferences | undefined {
    if (this.store !== undefined || this.storeTried) {
      return this.store;
    }
    this.storeTried = true;
    const ctx = getAppRuntime().context;
    if (ctx === undefined) {
      return undefined;
    }
    try {
      this.store = preferences.getPreferencesSync(ctx, { name: STORE_NAME });
    } catch (err) {
      this.store = undefined;
      hilog.warn(0, LOG_TAG, 'preferences open failed err=%{public}s', JSON.stringify(err));
    }
    return this.store;
  }

  /** @returns 命中的缓存值（`''` = 已缓存的**负结果**；`undefined` = 没缓存/过期）。 */
  private readCache(key: string): string | undefined {
    const now: number = Date.now();
    const cacheKey: string = MotionCoverService.safeKey(key);
    const mem: CacheEntry | undefined = this.memory.get(cacheKey);
    if (mem !== undefined) {
      return now < mem.until ? mem.value : undefined;
    }
    const store: preferences.Preferences | undefined = this.getStore();
    if (store === undefined) {
      return undefined;
    }
    let raw: string = '';
    try {
      raw = store.getSync(cacheKey, '') as string;
    } catch (err) {
      return undefined;
    }
    if (raw.length === 0) {
      return undefined;
    }
    const sep: number = raw.indexOf('|');
    if (sep <= 0) {
      return undefined;
    }
    const until: number = Number(raw.substring(0, sep));
    if (!(until > now)) {
      return undefined;
    }
    const value: string = raw.substring(sep + 1);
    this.memory.set(cacheKey, new CacheEntry(value, until));
    return value;
  }

  private writeCache(key: string, value: string, ttlMs: number): void {
    const until: number = Date.now() + ttlMs;
    const cacheKey: string = MotionCoverService.safeKey(key);
    this.memory.set(cacheKey, new CacheEntry(value, until));
    const store: preferences.Preferences | undefined = this.getStore();
    if (store === undefined) {
      return;
    }
    try {
      store.putSync(cacheKey, `${until}|${value}`);
      store.flush();
    } catch (err) {
      hilog.warn(0, LOG_TAG, 'cache write failed err=%{public}s', JSON.stringify(err));
    }
  }

  /**
   * `preferences` 的 key 有长度上限（老版本 80 字节），而实体名是中文/长标题
   * ⇒ 超长的 key 折成一个短哈希（`h_<hash>`），避免 `putSync` 直接抛错。
   * 注意：内存 Map 与 preferences 必须用**同一个** key，所以两边都过这个函数。
   */
  private static safeKey(key: string): string {
    if (key.length <= 48) {
      return key;
    }
    let hash: number = 5381;
    for (let i = 0; i < key.length; i++) {
      hash = ((hash << 5) + hash + key.charCodeAt(i)) | 0;
    }
    return `h_${hash}`;
  }

  /** 调试用：清掉全部动态封面缓存（设置页"清除封面缓存"可以顺手调）。 */
  public clearCache(): void {
    this.memory.clear();
    const store: preferences.Preferences | undefined = this.getStore();
    if (store === undefined) {
      return;
    }
    try {
      store.clearSync();
      store.flush();
    } catch (err) {
      hilog.warn(0, LOG_TAG, 'cache clear failed err=%{public}s', JSON.stringify(err));
    }
  }

  // ────────────────────────────── 序列化 ──────────────────────────────

  /** `video\nposter\nfield`（三个字段都不含换行）。 */
  private static encode(cover: MotionCover): string {
    return `${cover.videoUrl}\n${cover.posterUrl}\n${cover.field}`;
  }

  private static decode(value: string): MotionCover | undefined {
    if (value.length === 0) {
      return undefined;
    }
    const parts: string[] = value.split('\n');
    if (parts.length < 1 || parts[0].length === 0) {
      return undefined;
    }
    const poster: string = parts.length > 1 ? parts[1] : '';
    const field: string = parts.length > 2 ? parts[2] : '';
    return new MotionCover(parts[0], poster, field);
  }

  /** `storefront|id|slug|pageUrl`；空串 = 负结果。 */
  private static encodeHit(hit: SearchHit): string {
    if (!hit.valid()) {
      return '';
    }
    return `${hit.storefront}|${hit.id}|${hit.slug}|${hit.pageUrl}`;
  }

  private static decodeHit(value: string): SearchHit {
    const out: SearchHit = new SearchHit();
    if (value.length === 0) {
      return out;
    }
    const parts: string[] = value.split('|');
    if (parts.length < 4) {
      return out;
    }
    out.storefront = parts[0];
    out.id = parts[1];
    out.slug = parts[2];
    out.pageUrl = parts[3];
    return out;
  }
}
