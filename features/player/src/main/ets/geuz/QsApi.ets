/**
 * 汽水音乐（ByteDance「汽水」App 侧 Luna 接口）内置适配。
 *
 * ★ 与 kw/kg/tx/wy/mg 不同：汽水**不是 LX 脚本平台**，它没有脚本能给出直链，
 *   所以在 RzdMusic 里必须内置实现（参考 lxmusic-harmony 的 `core/music/MusicSearch.ets` qs 一节）。
 *
 * 端点（App 侧，免登录；PC 那条要签名头 X-Helios / X-Medusa，不用）：
 *   - 单曲搜索：GET  https://beta-luna.douyin.com/luna/search/track
 *   - 歌单搜索：POST https://beta-luna.douyin.com/luna/search/playlist
 * 分页是**绝对 cursor**（0,20,40…），接口固定 20 条/页，`has_more` 决定还有没有下一页。
 *
 * 日志关键字：`RzdSoda`
 */
import { http } from '@kit.NetworkKit';
import { LXQualityType, LXSearchResult, LXSearchSong } from '../source/LXMusicSDK';

const QS_SEARCH_TRACK: string = 'https://beta-luna.douyin.com/luna/search/track';
const QS_SEARCH_PLAYLIST: string = 'https://beta-luna.douyin.com/luna/search/playlist';
/** 接口固定每页 20 条 */
const QS_PAGE_SIZE: number = 20;

/** 汽水 App 侧公共请求头（搜索 / 发现页 / 歌单详情共用）。 */
const QS_HEADERS: Record<string, string> = {
  'User-Agent': 'Luna/19.1.0 Android',
  'Accept': 'application/json',
  'Content-Type': 'application/json'
};

/** 与汽水客户端同形的 16 位纯数字设备号（进程内固定）。 */
const QS_DEVICE_ID: string = qsRandomId(16);
const QS_INSTALL_ID: string = qsRandomId(16);

function qsRandomId(length: number): string {
  let out: string = '';
  while (out.length < length) {
    out += Math.floor(Math.random() * 10).toString();
  }
  return out;
}

/** 汽水 App 侧公共设备参数。 */
export function qsDeviceQuery(): string {
  return 'aid=386088&app_name=luna&region=cn&geo_region=cn&os_region=cn' +
    '&device_id=' + QS_DEVICE_ID + '&iid=' + QS_INSTALL_ID + '&device_platform=android' +
    '&version_code=30020100&version_name=3.0.2.1&channel=official';
}

function asString(value: Object | undefined): string {
  return typeof value === 'string' ? (value as string) : '';
}

function asNumber(value: Object | undefined): number {
  return typeof value === 'number' ? (value as number) : 0;
}

function asArray(value: Object | undefined): Object[] {
  return Array.isArray(value) ? (value as Object[]) : [];
}

function asRecord(value: Object | undefined): Record<string, Object> {
  if (value === undefined || value === null || typeof value !== 'object') {
    return {};
  }
  return value as Record<string, Object>;
}

/** 汽水封面：`urls[0] + uri + ~c5_500x500.jpg`（uri 自带扩展名时不再拼尺寸后缀）。 */
export function qsCoverOf(coverJson: Record<string, Object>): string {
  const uri: string = asString(coverJson['uri']);
  if (uri.length === 0) {
    return '';
  }
  if (/^https?:\/\//i.test(uri)) {
    return uri;
  }
  const urls: Object[] = asArray(coverJson['urls']);
  const base: string = urls.length > 0 ? asString(urls[0]) : '';
  if (base.length === 0) {
    return '';
  }
  if (/\.(jpg|jpeg|png|webp)$/i.test(uri)) {
    return base + uri;
  }
  return base + uri + '~c5_500x500.jpg';
}

/** 汽水 `quality_map` 的键 → 我们的音质档位。 */
function qsQualityOf(key: string): string {
  if (key === 'lossless') {
    return 'flac';
  }
  if (key === 'hi_res') {
    return 'hires';
  }
  if (key === 'higher' || key === 'highest') {
    return '320k';
  }
  if (key === 'medium') {
    return '128k';
  }
  return '';
}

/** 秒数 → `m:ss`。 */
function formatInterval(seconds: number): string {
  if (seconds <= 0) {
    return '';
  }
  const m: number = Math.floor(seconds / 60);
  const s: number = seconds % 60;
  return m + ':' + (s < 10 ? ('0' + s) : s.toString());
}

/**
 * 汽水的一条 track（搜索结果 / 歌单详情 / 榜单里的 `entity.track`）→ 我们的 LXSearchSong。
 * 没有 id 的条目返回 undefined（调用方过滤掉）。
 */
export function qsTrackToSong(trackJson: Record<string, Object>): LXSearchSong | undefined {
  const id: string = asString(trackJson['id']);
  if (id.length === 0) {
    return undefined;
  }
  const album: Record<string, Object> = asRecord(trackJson['album']);
  const label: Record<string, Object> = asRecord(trackJson['label_info']);
  const qualityMapRaw: Record<string, Object> = asRecord(label['quality_map']);
  const types: LXQualityType[] = [];
  const seenQuality: Record<string, boolean> = {};
  const keys: string[] = Object.keys(qualityMapRaw);
  for (let i: number = 0; i < keys.length; i++) {
    const quality: string = qsQualityOf(keys[i]);
    if (quality.length === 0 || seenQuality[quality] === true) {
      continue;
    }
    seenQuality[quality] = true;
    const item: LXQualityType = { type: quality, size: '' };
    types.push(item);
  }
  // 少数翻唱 / 用户上传不报音质：按汽水常规三档兜底，别让音质面板空着
  if (types.length === 0) {
    const fallback: string[] = ['128k', '320k', 'flac'];
    for (let i: number = 0; i < fallback.length; i++) {
      const item: LXQualityType = { type: fallback[i], size: '' };
      types.push(item);
    }
  }
  const names: string[] = [];
  const artists: Object[] = asArray(trackJson['artists']);
  for (let i: number = 0; i < artists.length; i++) {
    const artist: Record<string, Object> = asRecord(artists[i]);
    let name: string = asString(artist['name']);
    if (name.length === 0) {
      name = asString(asRecord(artist['user_info'])['nickname']);
    }
    if (name.length > 0) {
      names.push(name);
    }
  }
  const seconds: number = Math.round(asNumber(trackJson['duration']) / 1000);
  const song: LXSearchSong = {
    songId: id,
    name: asString(trackJson['name']),
    singer: names.join('、'),
    albumName: asString(album['name']),
    albumId: asString(album['id']),
    source: 'qs',
    interval: formatInterval(seconds),
    img: qsCoverOf(asRecord(album['url_cover'])),
    types: types
  };
  return song;
}

/** 解析汽水搜索结果（`result_groups[].data[].entity.track`）。 */
export function parseQsTracks(body: Record<string, Object>): LXSearchSong[] {
  const out: LXSearchSong[] = [];
  const groups: Object[] = asArray(body['result_groups']);
  for (let g: number = 0; g < groups.length; g++) {
    const group: Record<string, Object> = asRecord(groups[g]);
    const rows: Object[] = asArray(group['data']);
    for (let r: number = 0; r < rows.length; r++) {
      const row: Record<string, Object> = asRecord(rows[r]);
      const entity: Record<string, Object> = asRecord(row['entity']);
      const song: LXSearchSong | undefined = qsTrackToSong(asRecord(entity['track']));
      if (song !== undefined) {
        out.push(song);
      }
    }
  }
  return out;
}

function hasMore(body: Record<string, Object>): boolean {
  const groups: Object[] = asArray(body['result_groups']);
  for (let g: number = 0; g < groups.length; g++) {
    if (asRecord(groups[g])['has_more'] === true) {
      return true;
    }
  }
  return false;
}

async function qsGetJson(url: string): Promise<Record<string, Object>> {
  const req: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await req.request(url, {
      method: http.RequestMethod.GET,
      header: QS_HEADERS,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 12000,
      readTimeout: 20000
    });
    if (resp.responseCode !== 200) {
      console.info('[RzdSoda] http=' + resp.responseCode + ' ' + url.substring(0, 80));
      return {};
    }
    const text: string = typeof resp.result === 'string' ? (resp.result as string) : '';
    return text.length > 0 ? (JSON.parse(text) as Record<string, Object>) : {};
  } catch (error) {
    console.info('[RzdSoda] request error: ' + JSON.stringify(error).substring(0, 100));
    return {};
  } finally {
    req.destroy();
  }
}

/** 汽水单曲搜索。 */
export async function qsSearchTracks(query: string, page: number, limit: number): Promise<LXSearchResult> {
  const cursor: number = Math.max(0, page - 1) * QS_PAGE_SIZE;
  const url: string = QS_SEARCH_TRACK + '?' + qsDeviceQuery() +
    '&q=' + encodeURIComponent(query) + '&cursor=' + cursor +
    '&count=' + QS_PAGE_SIZE + '&search_method=input';
  const body: Record<string, Object> = await qsGetJson(url);
  let list: LXSearchSong[] = parseQsTracks(body);
  if (list.length > limit) {
    list = list.slice(0, limit);
  }
  console.info('[RzdSoda] search q=' + query + ' page=' + page + ' got=' + list.length +
    ' more=' + hasMore(body));
  return { list: list, total: 0, limit: limit, source: 'qs' };
}

// ────────────────────────────────────────────────────────────────
// 汽水榜单：三张榜整块塞在发现页的 `discover_top_song_list` 里（各 50 首，每周四更新）。
// 发现页响应约 1.6MB，60 秒内复用同一份，避免为三张榜连拉三次。
// ────────────────────────────────────────────────────────────────
const QS_LUNA: string = 'https://beta-luna.douyin.com';
/** 我们的榜单短标识 → 汽水发现页里的块标题 */
const QS_BOARD_TITLES: Record<string, string> = {
  'hot': '热歌榜',
  'new': '新歌榜',
  'west': '欧美榜'
};
let qsDiscoverCacheAt: number = 0;
let qsDiscoverCache: Record<string, Object> = {};

async function qsPostJson(path: string, payloadJson: string): Promise<Record<string, Object>> {
  const req: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await req.request(QS_LUNA + path + '?' + qsDeviceQuery(), {
      method: http.RequestMethod.POST,
      header: QS_HEADERS,
      extraData: payloadJson,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 12000,
      readTimeout: 25000
    });
    if (resp.responseCode !== 200) {
      console.info('[RzdSoda] POST http=' + resp.responseCode + ' ' + path);
      return {};
    }
    const text: string = typeof resp.result === 'string' ? (resp.result as string) : '';
    return text.length > 0 ? (JSON.parse(text) as Record<string, Object>) : {};
  } catch (error) {
    console.info('[RzdSoda] POST error: ' + JSON.stringify(error).substring(0, 100));
    return {};
  } finally {
    req.destroy();
  }
}

/** 发现页所有榜单块（`discover_top_song_list` 的 inner_block）。 */
function qsChartBlocks(body: Record<string, Object>): Object[] {
  const out: Object[] = [];
  const blocks: Object[] = asArray(body['blocks']);
  for (let i: number = 0; i < blocks.length; i++) {
    const block: Record<string, Object> = asRecord(blocks[i]);
    if (asString(block['type']) !== 'discover_top_song_list') {
      continue;
    }
    const inner: Object[] = asArray(block['inner_block']);
    for (let k: number = 0; k < inner.length; k++) {
      out.push(inner[k]);
    }
  }
  return out;
}

async function qsDiscoverBody(): Promise<Record<string, Object>> {
  const now: number = Date.now();
  if (qsDiscoverCacheAt > 0 && now - qsDiscoverCacheAt < 60000 &&
    Object.keys(qsDiscoverCache).length > 0) {
    return qsDiscoverCache;
  }
  let body: Record<string, Object> = await qsPostJson('/luna/discover', '{"first_request":true}');
  if (qsChartBlocks(body).length === 0) {
    // 发现页偶发空响应（限流）：再问一次，别让榜单页直接报错
    body = await qsPostJson('/luna/discover', '{}');
  }
  if (Object.keys(body).length > 0) {
    qsDiscoverCache = body;
    qsDiscoverCacheAt = now;
  }
  return body;
}

/** 汽水某张榜的歌曲（`ranked_track`）；没有下一页（page > 1 返回空）。 */
export async function qsBoardSongs(bangid: string, page: number,
  limit: number): Promise<LXSearchSong[]> {
  if (page > 1) {
    return [];
  }
  const body: Record<string, Object> = await qsDiscoverBody();
  const charts: Object[] = qsChartBlocks(body);
  const wanted: string = QS_BOARD_TITLES[bangid] !== undefined ? QS_BOARD_TITLES[bangid] : bangid;
  let chart: Record<string, Object> = {};
  for (let i: number = 0; i < charts.length; i++) {
    const one: Record<string, Object> = asRecord(charts[i]);
    if (asString(one['title']) === wanted) {
      chart = one;
      break;
    }
  }
  if (Object.keys(chart).length === 0) {
    console.info('[RzdSoda] board not found: ' + wanted + ' charts=' + charts.length);
    return [];
  }
  const songs: LXSearchSong[] = [];
  const resources: Object[] = asArray(chart['resources']);
  for (let i: number = 0; i < resources.length; i++) {
    const ranked: Record<string, Object> =
      asRecord(asRecord(asRecord(resources[i])['entity'])['ranked_track']);
    const song: LXSearchSong | undefined = qsTrackToSong(asRecord(ranked['track']));
    if (song !== undefined) {
      songs.push(song);
    }
  }
  const out: LXSearchSong[] = limit > 0 && songs.length > limit ? songs.slice(0, limit) : songs;
  console.info('[RzdSoda] board=' + wanted + ' got=' + out.length);
  return out;
}