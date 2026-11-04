/*
 * Copyright (c) 2026 RzdPai
 *
 * 汽水音乐（source = 'qs'）的**内置**歌词 / 曲目详情（不依赖 LX 脚本，也不需要登录）。
 *
 * ★ 依据（外部参考实现 `guowenye/qishui-api` + 本机实测复核 2026-11-04）：
 *   ```
 *   GET https://beta-luna.douyin.com/luna/h5/seo_track?track_id=<id>&device_platform=web
 *   200 → {
 *     "status_info": { log_id, now, status_msg? },          ← 失败时**只有** status_msg，没有 lyric/seo_track
 *     "lyric":  { type: "krc", content: "[60,1470]<0,350,0>不<400,340,0>敢…",
 *                 hide_request_lyrics: false, lyric_contributor: { filter_reason } },
 *     "seo_track": { track: { name, duration(ms), artists[], album{name,url_cover}, chorus, lang_codes } },
 *     "track_player": { video_model, url_player_info, expire_at }   ← 播放用，需 spade 解密，本轮不接
 *   }
 *   ```
 *   这个接口是给**站外分享页 / 搜索引擎爬虫**用的 SEO 口子，所以按设计不校验登录：
 *   实测**带不带 UA 都返回 200**；`luna/lyric`、`luna/track/lyric`、`luna/app/lyric` 全是 404，
 *   `luna/pc/track_v2` 要 `X-Helios`/`X-Medusa` 签名（返回空 body）⇒ **这里是唯一可用的歌词入口**。
 *
 * ⚠️ **上游是 KRC（字节自家格式），不是 LRC，也不等于 QQ 的 QRC**：
 *   KRC ：`[行起始ms,行持续ms]` + 每词 `<词偏移ms,词时长ms,0>字`   ← 偏移相对**行首**
 *   QRC ：`[行起始ms,行持续ms]` + 每词 `字(绝对起始ms,词时长ms)`   ← 我们 `amllParseQrc` 认这个
 *   直接把 KRC 原文塞进 `SongItem.lyricText` 会解析出 **0 行**（看着就像"没有歌词"）。
 *   `qsKrcToQrc()` 把它归一化成 QRC（**逐字时间轴保留**，不是降级成 LRC）。
 *
 * ⚠️ 边界（都按"降级，不报错"处理）：
 *   · **无效 id 也是 200**：响应只有 `status_info.status_msg`（如「SEO页面歌曲未知」），无 `lyric`/`seo_track`
 *     ⇒ 判为失败、**不写缓存**（否则风控/网络抖动会被永久缓存成"没歌词"）；
 *   · `lyric.hide_request_lyrics = true` 或没有 `lyric` 节点 ⇒ 正常歌曲但无词，**可缓存**（避免重复请求）；
 *   · 未登录**没有翻译**（`translation_contributor` 只有 `filter_reason`）⇒ 翻译/罗马音固定空串。
 *
 * 排查关键字：`RzdSoda`
 */
import { http } from '@kit.NetworkKit';
import { appendPlayLog } from 'musicbasic';

const QS_H5_SEO_TRACK: string = 'https://beta-luna.douyin.com/luna/h5/seo_track';
const QS_TAG: string = '[RzdSoda]';
/** 浏览器 UA：本来不带头也能通，带上更稳（顺便让 `seo_url` 等字段按 Web 形态返回）。 */
const QS_H5_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) ' +
    'Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'application/json'
};

/**
 * 汽水这边所有诊断都走这里：**两路都打**。
 *
 * ★ 2026-11-04：以前只用 `console.info`（→ hilog），而甲方贴的是 App 内「播放日志」面板
 *   （`appendPlayLog` → `AppStorage['lxPlayLog']`）⇒ 面板里根本看不到汽水歌词的日志，
 *   排查只能靠 `hdc shell hilog -x | Select-String RzdSoda`。现在两路都写。
 */
function qsLog(message: string): void {
  const line: string = QS_TAG + ' ' + message;
  console.info(line);
  appendPlayLog(line);
}

/** 汽水一首歌的 H5 SEO 详情（只保留我们会用到的那几个字段）。 */
export class QsH5TrackInfo {
  /** 汽水 track id（`songId`）。 */
  trackId: string = '';
  name: string = '';
  /** 多位歌手用 `、` 连接（与汽水 App 内一致）。 */
  singer: string = '';
  album: string = '';
  /** 500×500 封面。 */
  cover: string = '';
  /** 时长（秒）。 */
  durationSec: number = 0;
  /** 上游 `lyric.type`（`krc` / `lrc` / 空）——只用于日志与排查。 */
  lyricType: string = '';
  /** **已归一化**的歌词文本（KRC→QRC，可直接交给 `amllParseQrc`）；空串 = 这首歌没有歌词。 */
  qrc: string = '';
}

/** 进程内小缓存：`enrichOnlineTrack` 一首歌会跑 2~3 次（loadAsset / resolve / playing），不能每次重下。 */
const QS_H5_CACHE: Map<string, QsH5TrackInfo> = new Map<string, QsH5TrackInfo>();
/** 缓存淘汰顺序（FIFO）。 */
const QS_H5_ORDER: string[] = [];
const QS_H5_CACHE_MAX: number = 12;

function asString(value: Object | undefined): string {
  return typeof value === 'string' ? (value as string) : '';
}

function asNumber(value: Object | undefined): number {
  return typeof value === 'number' ? (value as number) : 0;
}

function asBoolean(value: Object | undefined): boolean {
  return value === true;
}

function asRecord(value: Object | undefined): Record<string, Object> {
  if (value === undefined || value === null || typeof value !== 'object') {
    return {};
  }
  return value as Record<string, Object>;
}

function asArray(value: Object | undefined): Object[] {
  return Array.isArray(value) ? (value as Object[]) : [];
}

/**
 * 汽水 KRC → **QQ 版 QRC**（我们 `amllParseQrc` 认的那一份）。
 *
 * 输入：`[15971,3799]<0,169,0>如<169,168,0>果<480,297,0>那`
 * 输出：`[15971,3799]如(15971,169)果(16140,168)那(16451,297)`
 * （词绝对时间 = 行起始 + 相对偏移；偏移可不连续＝句内有停顿，原样保留）
 * @param raw `lyric.content`
 * @returns 归一化后的 QRC；没有可用行时返回空串。
 */
export function qsKrcToQrc(raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  const lines: string[] = raw.split(/\r?\n/);
  const out: string[] = [];
  let dropped: number = 0;
  for (let i: number = 0; i < lines.length; i++) {
    const line: string = lines[i].trim();
    if (line.length === 0) {
      continue;
    }
    const head: RegExpMatchArray | null = line.match(/^\[(\d+),(\d+)\](.*)$/);
    if (head === null || head.length < 4) {
      dropped++;
      continue;
    }
    const lineStart: number = Number(head[1]);
    const lineDur: number = Number(head[2]);
    const rest: string = head[3];
    let words: string = '';
    // 词元：`<偏移,时长[,标志]>文本`（标志位实测为 0，允许缺省）
    const re: RegExp = new RegExp('<([0-9]+),([0-9]+)(?:,[0-9]+)?>([^<]*)', 'g');
    let m: RegExpExecArray | null = re.exec(rest);
    while (m !== null) {
      const offset: number = Number(m[1]);
      const dur: number = Number(m[2]);
      const text: string = m[3];
      if (text.length > 0) {
        words += text + '(' + (lineStart + offset) + ',' + dur + ')';
      }
      m = re.exec(rest);
    }
    if (words.length === 0) {
      // 纯伴奏行（只有 `[start,dur]` 没有词元）：不丢整行，按行级空词保留时间点
      dropped++;
      continue;
    }
    out.push('[' + lineStart + ',' + lineDur + ']' + words);
  }
  qsLog(' qsKrcToQrc lines=' + out.length + ' dropped=' + dropped +
    ' rawLen=' + raw.length);
  return out.join('\n');
}

/**
 * 按上游 `lyric.type` 决定怎么交给 UI。
 *
 * - `krc`（实测就是这个）：归一化成 QRC，保住逐字；
 * - `lrc`（上游将来若切格式）：原样返回，标准 LRC 我们的解析器本来就会；
 * - 类型缺失/不认识：**看内容形状**判断，实在认不出就原样返回（宁可让 UI 的自动识别试一次，
 *   也不要因为"不认识类型"就把歌词丢掉）。
 */
function qsLyricOfType(type: string, raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  const lower: string = type.toLowerCase();
  if (lower === 'krc' || /^\[\d+,\d+\]\s*</.test(raw)) {
    return qsKrcToQrc(raw);
  }
  if (lower === 'lrc' || /^\[\d{1,2}:\d{2}/.test(raw)) {
    return raw;
  }
  return raw;
}

/** 从 `seo_track.track.album.url_cover` 拼 500×500 封面（与搜索接口同一套拼法）。 */
function qsCoverFromAlbum(album: Record<string, Object>): string {
  const pic: Record<string, Object> = asRecord(album['url_cover']);
  const uri: string = asString(pic['uri']);
  if (uri.length === 0) {
    return '';
  }
  if (/^https?:\/\//i.test(uri)) {
    return uri;
  }
  const urls: Object[] = asArray(pic['urls']);
  const base: string = urls.length > 0 ? asString(urls[0]) : '';
  if (base.length === 0) {
    return '';
  }
  if (/\.(jpg|jpeg|png|webp)$/i.test(uri)) {
    return base + uri;
  }
  return base + uri + '~c5_500x500.jpg';
}

/**
 * 发一次 GET，失败/非 200 返回空串（不抛）。
 * @param headers 传 `{}` 表示**不带任何头**。
 */
async function qsHttpGet(url: string, headers: Record<string, string>): Promise<string> {
  try {
    const client = http.createHttp();
    try {
      const resp: http.HttpResponse = await client.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200) {
        qsLog(' h5/seo_track http=' + resp.responseCode);
        return '';
      }
      return typeof resp.result === 'string' ? (resp.result as string) : '';
    } finally {
      client.destroy();
    }
  } catch (err) {
    qsLog(' h5/seo_track failed err=' + JSON.stringify(err).substring(0, 80));
    return '';
  }
}

/**
 * 拉一首歌的 H5 SEO 详情（含歌词）。失败返回 `undefined`（歌词是可选能力，不抛异常）。
 * @param trackId 汽水 track id（= `SongItem.songId`）。
 */
export async function qsH5SeoTrack(trackId: string): Promise<QsH5TrackInfo | undefined> {
  if (trackId.length === 0) {
    return undefined;
  }
  const cached: QsH5TrackInfo | undefined = QS_H5_CACHE.get(trackId);
  if (cached !== undefined) {
    return cached;
  }
  const url: string = QS_H5_SEO_TRACK + '?track_id=' + trackId + '&device_platform=web';
  let text: string = await qsHttpGet(url, QS_H5_HEADERS);
  if (text.length === 0) {
    // 兜底：实测**不带任何请求头**也能通（万一哪天按 UA 风控了，这条还能救回来）
    text = await qsHttpGet(url, {});
    if (text.length > 0) {
      qsLog(' h5/seo_track retried without UA ok id=' + trackId);
    }
  }
  if (text.length === 0) {
    return undefined;
  }
  const info: QsH5TrackInfo = new QsH5TrackInfo();
  info.trackId = trackId;
  try {
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const status: Record<string, Object> = asRecord(root['status_info']);
    const statusMsg: string = asString(status['status_msg']);
    const seo: Record<string, Object> = asRecord(root['seo_track']);
    const track: Record<string, Object> = asRecord(seo['track']);
    const trackName: string = asString(track['name']);
    // ⚠️ **无效 id 也是 200**：只有 status_msg、没有 seo_track.track。
    //   判成失败且**不写缓存**，避免把"风控/抖动"永久固化成"这首歌没歌词"。
    if (statusMsg.length > 0 || (trackName.length === 0 && asNumber(track['duration']) <= 0)) {
      qsLog(' h5/seo_track invalid id=' + trackId + ' statusMsg=' +
        (statusMsg.length > 0 ? statusMsg : '(无)'));
      return undefined;
    }
    info.name = trackName;
    const artists: Object[] = asArray(track['artists']);
    const names: string[] = [];
    for (let i: number = 0; i < artists.length; i++) {
      const nm: string = asString(asRecord(artists[i])['name']);
      if (nm.length > 0) {
        names.push(nm);
      }
    }
    info.singer = names.join('、');
    const album: Record<string, Object> = asRecord(track['album']);
    info.album = asString(album['name']);
    info.cover = qsCoverFromAlbum(album);
    // `duration` 是毫秒
    info.durationSec = Math.floor(asNumber(track['duration']) / 1000);
    const lyric: Record<string, Object> = asRecord(root['lyric']);
    info.lyricType = asString(lyric['type']);
    const hidden: boolean = asBoolean(lyric['hide_request_lyrics']);
    const rawLyric: string = asString(lyric['content']);
    if (hidden) {
      qsLog(' h5/seo_track lyric hidden id=' + trackId);
    }
    info.qrc = hidden ? '' : qsLyricOfType(info.lyricType, rawLyric);
  } catch (err) {
    qsLog(' h5/seo_track parse failed id=' + trackId);
    return undefined;
  }
  qsLog(' h5/seo_track ok id=' + trackId + ' name=' + info.name +
    ' singer=' + info.singer + ' type=' + (info.lyricType.length > 0 ? info.lyricType : '(空)') +
    ' lyricLines=' + (info.qrc.length > 0 ? info.qrc.split('\n').length : 0) +
    ' cover=' + (info.cover.length > 0 ? 1 : 0));
  if (QS_H5_CACHE.size >= QS_H5_CACHE_MAX && QS_H5_ORDER.length > 0) {
    // FIFO 淘汰（不用迭代器：ArkTS 下更稳）
    const evict: string = QS_H5_ORDER.shift() as string;
    QS_H5_CACHE.delete(evict);
  }
  QS_H5_CACHE.set(trackId, info);
  QS_H5_ORDER.push(trackId);
  return info;
}

/**
 * @returns 已归一化的歌词文本（可直接当 `LyricFullResult.main`）；没有则空串。
 */
export async function qsLyricText(trackId: string): Promise<string> {
  const info: QsH5TrackInfo | undefined = await qsH5SeoTrack(trackId);
  return info !== undefined ? info.qrc : '';
}

/**
 * @returns 500×500 封面地址；没有则空串（`lxGetPicFallback` 的 qs 分支用它）。
 */
export async function qsCoverUrl(trackId: string): Promise<string> {
  const info: QsH5TrackInfo | undefined = await qsH5SeoTrack(trackId);
  return info !== undefined ? info.cover : '';
}
