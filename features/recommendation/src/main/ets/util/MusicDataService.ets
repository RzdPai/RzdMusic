import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { lxTxToplistInfo, TxToplistInfo } from 'player';
import { BoardSongParam, ToplistRouteParam } from 'musicbasic';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer, util } from '@kit.ArkTS';

const LOG_DOMAIN: number = 0x0000;
const LOG_TAG: string = 'RzdPlazaNet';

/**
 * 请求失败日志（只写 hilog，不写应用内日志面板）。
 *
 * 保留原因：酷狗广场/榜单走的是明文 HTTP，这类「请求成功但解析崩」或
 * 「域名解析不了」的问题靠错误码一眼可辨；错误码含义见 errorcode-net-http。
 * 排查用：`hdc shell hilog | findstr RzdPlazaNet`。
 */
function logHttpFailure(stage: string, url: string, err: Object): void {
  const e: BusinessError = err as BusinessError;
  hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s failed: code=%{public}d msg=%{public}s url=%{public}s',
    stage, e.code ?? 0, e.message ?? '', url);
}

export interface PlaylistData {
  id: string;
  name: string;
  author: string;
  image: string;
  count: string;
  time: string;
  listenCount: string;
  category: string;
  source: string;
}

export interface PlaylistPage {
  list: PlaylistData[];
  page: number;
  limit: number;
  total: number;
  hasNext: boolean;
}

const boardCoverCache: Map<string, Record<string, string>> = new Map();

export interface BoardData {
  id: string;
  name: string;
  source: string;
  cover: string;
}

export interface TrackData {
  songId: string;
  name: string;
  artist: string;
  album: string;
  image: string;
  duration: string;
  source: string;
}

export interface SortOption {
  id: string;
  name: string;
}

export interface CategoryOption {
  id: string;
  name: string;
}

export interface CategoryGroup {
  title: string;
  items: CategoryOption[];
}

type JsonObject = Record<string, Object>;

interface NeteaseLinuxParams {
  method: string;
  url: string;
  params: JsonObject;
}

const TX_BOARD_HEADERS: Record<string, string> = {
  'Referer': 'https://y.qq.com/',
  'User-Agent': 'Mozilla/5.0'
};

const KW_BOARD_HEADERS: Record<string, string> = {
  'Referer': 'http://www.kuwo.cn/',
  'csrf': 'RZDMUSIC',
  'Cookie': 'kw_token=RZDMUSIC',
  'User-Agent': 'Mozilla/5.0'
};

const MIGU_HEADERS: Record<string, string> = {
  'Content-Type': 'application/json',
  'Accept': 'application/json, text/plain, */*',
  'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
  'Referer': 'https://m.music.migu.cn/'
};


class TxRequestComm {
  ct: number = 24;
  cv: number = 0;
}

class TxRequestTopList {
  module: string = 'musicToplist.ToplistInfoServer';
  method: string = 'GetAll';
  param: string = '{}';
}

class TxRequestPayload {
  comm: TxRequestComm = new TxRequestComm();
  topList: TxRequestTopList = new TxRequestTopList();
}

/** Kugou rank list: covers live under data.info[] and contain a {size} placeholder. */
async function fillKgCovers(map: Record<string, string>): Promise<void> {
  const root: JsonObject = await requestJson(
    'http://mobilecdnbj.kugou.com/api/v3/rank/list?version=9108&plat=0&area_code=1&page=1&pagesize=200');
  const data: JsonObject = asObject(root['data']);
  let items: JsonObject[] = asArray(data['info']);
  if (items.length === 0) {
    items = asArray(root['data']);
  }
  for (let i: number = 0; i < items.length; i++) {
    const id: string = text(items[i]['rankid']);
    const cover: string = text(items[i]['imgurl']).replace('{size}', '480');
    if (id.length > 0 && cover.length > 0) {
      map[id] = cover;
    }
  }
}

/**
 * QQ music toplist covers: the list API no longer returns usable pictures, so each
 * known toplist id is queried through the per-toplist info API (same source the
 * home chart tab uses, which still serves covers).
 */
async function fillTxCovers(map: Record<string, string>): Promise<void> {
  const ids: string[] = boardIdList('tx');
  const tasks: Promise<TxToplistInfo | undefined>[] = [];
  for (let i: number = 0; i < ids.length; i++) {
    tasks.push(lxTxToplistInfo(ids[i]));
  }
  const settled: PromiseSettledResult<TxToplistInfo | undefined>[] = await Promise.allSettled(tasks);
  for (let i: number = 0; i < settled.length; i++) {
    const r: PromiseSettledResult<TxToplistInfo | undefined> = settled[i];
    if (r.status !== 'fulfilled') {
      continue;
    }
    const info: TxToplistInfo | undefined = r.value;
    if (info === undefined || info.pic.length === 0) {
      continue;
    }
    map[ids[i]] = info.pic;
  }
}

/** 酷我榜单列表接口（PC 端页面用的那个，不需要签名）。 */
const KW_BANG_LIST_URL: string = 'http://wapi.kuwo.cn/api/pc/bang/list';

/** 酷我榜单歌曲接口（老 PC 接口，不需要签名）。 */
const KW_BANG_SONG_URL: string = 'http://kbangserver.kuwo.cn/ksong.s';

/** 榜单歌曲每页条数。 */
const KW_BANG_PAGE_SIZE: number = 80;

/** 一个榜单在列表里展示所需的字段。 */
export class KwBangEntry {
  /** 榜单 id，同时也是歌曲接口的 `id` 参数。 */
  id: string = '';
  /** 榜单名称。 */
  name: string = '';
  /** 榜单封面。 */
  cover: string = '';
}

/**
 * 递归收集酷我榜单列表里的叶子榜单。
 *
 * 接口返回的是两级（有时三级）分组树：顶层是「排行榜」壳，第二层是「官方榜 / 特色榜」，
 * 第三层才是真正的榜单（带 `sourceid`）。只有带非空 `sourceid` 的才是可用榜单。
 *
 * @param nodes 当前层的节点数组。
 * @param out 收集结果（按接口顺序去重）。
 */
function collectKwBangs(nodes: JsonObject[], out: KwBangEntry[]): void {
  for (let i: number = 0; i < nodes.length; i++) {
    const node: JsonObject = nodes[i];
    const id: string = text(node['sourceid']);
    if (id.length > 0) {
      const entry = new KwBangEntry();
      entry.id = id;
      entry.name = text(node['disname'] ?? node['name']);
      // pic5 是 PC 大图，pic2 次之，pic 是小图
      let cover: string = text(node['pic5']);
      if (cover.length === 0) {
        cover = text(node['pic2']);
      }
      if (cover.length === 0) {
        cover = text(node['pic']);
      }
      entry.cover = cover;
      if (entry.name.length > 0 && !out.some((item: KwBangEntry) => item.id === entry.id)) {
        out.push(entry);
      }
    }
    const children: JsonObject[] = asArray(node['child']);
    if (children.length > 0) {
      collectKwBangs(children, out);
    }
  }
}

/**
 * 拉取酷我榜单列表（**带封面的实时列表**）。
 *
 * 为什么不再用写死的 id/名字表：那张表是照着酷我老版 PC 页面抄的，酷我换版之后
 * 榜单 id 大面积变化 —— 表现就是「排行榜点进去全是空的 / 打不开」。
 * 现在直接读官方的榜单列表接口，id、名字、封面都从接口来。
 *
 * @returns 榜单列表；失败时返回空数组，由调用方回退到写死的表。
 */
async function fetchKwBangs(): Promise<KwBangEntry[]> {
  const root: JsonObject = await requestJson(KW_BANG_LIST_URL, http.RequestMethod.GET,
    undefined, KW_BOARD_HEADERS);
  const out: KwBangEntry[] = [];
  collectKwBangs(asArray(root['child']), out);
  if (out.length === 0) {
    // 有的机房返回的是 data 包一层
    collectKwBangs(asArray(asObject(root['data'])['child']), out);
  }
  return out;
}

/** 榜单列表的会话级缓存：首页在榜单模块里会切平台反复请求，没必要每次都打网络。 */
let kwBangsCache: KwBangEntry[] | undefined = undefined;

/** 拉取并缓存酷我榜单列表。 */
async function kwBangs(): Promise<KwBangEntry[]> {
  if (kwBangsCache !== undefined) {
    return kwBangsCache;
  }
  const list: KwBangEntry[] = await fetchKwBangs();
  if (list.length > 0) {
    kwBangsCache = list;
  }
  return list;
}

/**
 * 酷我榜单歌曲。
 *
 * 原来走的是 `wbd.kuwo.cn/api/bd/bang/bang_info`（需要 AES + md5 签名那套），
 * 现在那个 AppId 已经被封，返回 `{"code":10004,"msg":"AppId错误"}` ——
 * 这就是「酷我排行榜完全不可用」的直接原因。
 * 改用老 PC 端的 `kbangserver.kuwo.cn/ksong.s`：无需签名，参数与元力音源插件一致。
 *
 * @param boardId 榜单 id（来自 {@link fetchKwBangs} 的 `sourceid`）。
 * @returns 与其它平台一致的原始响应结构（`data.musiclist`）。
 */
async function requestKwBangSongs(boardId: string): Promise<JsonObject> {
  const url: string = `${KW_BANG_SONG_URL}?from=pc&fmt=json&pn=0&rn=${KW_BANG_PAGE_SIZE}` +
    `&type=bang&data=content&id=${encodeURIComponent(boardId)}` +
    `&show_copyright_off=0&pcmp4=1&isbang=1&userid=0&httpStatus=1`;
  const root: JsonObject = await requestJson(url, http.RequestMethod.GET, undefined, KW_BOARD_HEADERS);
  const songs: JsonObject[] = asArray(root['musiclist']);
  const data: JsonObject = {};
  data['musiclist'] = songs;
  const wrapped: JsonObject = {};
  wrapped['data'] = data;
  return wrapped;
}

/** Kuwo bang list: data.bangList[] carry bangId + pic (needs a kw referer/csrf pair). */
async function fillKwCovers(map: Record<string, string>): Promise<void> {
  const list: KwBangEntry[] = await kwBangs();
  for (let i: number = 0; i < list.length; i++) {
    if (list[i].id.length > 0 && list[i].cover.length > 0) {
      map[list[i].id] = list[i].cover;
    }
  }
}

/** Migu chart list: data[] carry chartId + picUrl (best effort; endpoint may change). */
async function fillMgCovers(map: Record<string, string>): Promise<void> {
  const root: JsonObject = await requestJson('https://music.migu.cn/v3/api/music/chart/list?pageSize=100',
    http.RequestMethod.GET, undefined, MIGU_HEADERS);
  let items: JsonObject[] = asArray(root['data']);
  if (items.length === 0) {
    items = asArray(asObject(root['data'])['list']);
  }
  for (let i: number = 0; i < items.length; i++) {
    const id: string = text(items[i]['chartId']);
    let cover: string = text(items[i]['picUrl']);
    if (cover.length === 0) {
      cover = text(items[i]['pic']);
    }
    if (id.length > 0 && cover.length > 0) {
      map[id] = cover;
    }
  }
}

const SOURCES: string[] = ['kw', 'kg', 'tx', 'wy', 'mg'];

function sourceDisplayName(source: string): string {
  if (source === 'kw') {
    return '酷我';
  }
  if (source === 'kg') {
    return '酷狗';
  }
  if (source === 'tx') {
    return 'QQ';
  }
  if (source === 'wy') {
    return '网易';
  }
  return '咪咕';
}

function boardIdList(source: string): string[] {
  if (source === 'kw') {
    return ['93', '17', '16', '158', '292', '284', '290', '286', '279', '281', '255', '280', '282', '283', '278', '264', '242', '187', '204', '186', '185', '26', '104', '182', '22', '184', '183', '145', '153', '64', '176', '106', '12', '49', '180', '13', '164', '246', '265', '14', '8', '15', '151'];
  }
  if (source === 'kg') {
    return ['8888', '6666', '59703', '52144', '52767', '24971', '23784', '44412', '31308', '33160', '31313', '51341', '54848', '31310', '33162', '31311', '31312', '49225', '49223', '49224', '33165', '33166', '33163', '51340', '35811', '37361', '21101', '46910', '30972', '60170', '65234', '4681', '25028', '4680', '38623', '42807', '36107', '4673', '46868', '42808', '60171', '60172', '59895', '59896', '59897', '59900', '59899', '22603', '21335', '33161'];
  }
  if (source === 'tx') {
    return ['4', '26', '27', '62', '58', '57', '28', '5', '3', '59', '16', '60', '29', '17', '52', '36', '61', '63', '64', '65', '67', '72', '73', '75', '131'];
  }
  if (source === 'wy') {
    return ['19723756', '3779629', '2884035', '3778678', '991319590', '71384707', '1978921795', '5453912201', '71385702', '745956260', '10520166', '180106', '60198', '3812895', '21845217', '60131', '2809513713', '2809577409', '27135204', '3001835560', '3001795926', '3001890046', '3112516681', '5059644681', '5059633707', '5059642708', '5338990334', '5059661515', '6688069460', '6723173524', '6732051320', '6732014811', '6886768100', '6939992364', '7095271308', '7356827205', '7603212484', '7775163417', '7785123708', '7785066739', '7785091694'];
  }
  return ['27553319', '27186466', '27553408', '75959118', '76557036', '76557745', '23189800', '23189399', '19190036', '83176390'];
}

function boardNameList(source: string): string[] {
  if (source === 'kw') {
    return ['飙升榜', '新歌榜', '热歌榜', '抖音热歌榜', '铃声榜', '热评榜', 'ACG新歌榜', '台湾KKBOX榜', '冬日暖心榜', '巴士随身听榜', 'KTV点唱榜', '家务进行曲榜', '熬夜修仙榜', '枕边轻音乐榜', '古风音乐榜', 'Vlog音乐榜', '电音榜', '流行趋势榜', '现场音乐榜', 'ACG神曲榜', '最强翻唱榜', '经典怀旧榜', '华语榜', '粤语榜', '欧美榜', '韩语榜', '日语榜', '会员畅听榜', '网红新歌榜', '影视金曲榜', 'DJ嗨歌榜', '真声音', 'Billboard榜', 'iTunes音乐榜', 'beatport电音榜', '英国UK榜', '百大DJ榜', 'YouTube音乐排行榜', '韩国Genie榜', '韩国M-net榜', '香港电台榜', '日本公信榜', '腾讯音乐人原创榜'];
  }
  if (source === 'kg') {
    return ['TOP500', '飙升榜', '蜂鸟流行音乐榜', '抖音热歌榜', '快手热歌榜', 'DJ热歌榜', '网络红歌榜', '说唱先锋榜', '内地榜', '电音榜', '香港地区榜', '民谣榜', '台湾地区榜', '欧美榜', 'ACG新歌榜', '韩国榜', '日本榜', '80后热歌榜', '90后热歌榜', '00后热歌榜', '粤语金曲榜', '欧美金曲榜', '影视金曲榜', '伤感榜', '会员专享榜', '雷达榜', '分享榜', '综艺新歌榜', '酷狗音乐人原创榜', '闽南语榜', '儿歌榜', '美国BillBoard榜', 'Beatport电子舞曲榜', '英国单曲榜', '韩国Melon音乐榜', 'joox本地热歌榜', '小语种热歌榜', '日本公信榜', '日本SPACE SHOWER榜', 'KKBOX风云榜', '越南语榜', '泰语榜', 'R&B榜', '摇滚榜', '爵士榜', '乡村音乐榜', '纯音乐榜', '古典榜', '5sing音乐榜', '繁星音乐榜', '古风新歌榜'];
  }
  if (source === 'tx') {
    return ['流行指数榜', '热歌榜', '新歌榜', '飙升榜', '说唱榜', '喜力电音榜', '网络歌曲榜', '内地榜', '欧美榜', '香港地区榜', '韩国榜', '抖快榜', '影视金曲榜', '日本榜', '腾讯音乐人原创榜', 'K歌金曲榜', '台湾地区榜', 'DJ舞曲榜', '综艺新歌榜', '国风热歌榜', '听歌识曲榜', '动漫音乐榜', '游戏音乐榜', '有声榜', '校园音乐人排行榜'];
  }
  if (source === 'wy') {
    return ['飙升榜', '新歌榜', '原创榜', '热歌榜', '说唱榜', '古典榜', '电音榜', '黑胶VIP爱听榜', 'ACG榜', '韩语榜', '国电榜', 'UK排行榜周榜', '美国Billboard榜', 'Beatport全球电子舞曲榜', 'KTV唛榜', '日本Oricon榜', '欧美热歌榜', '欧美新歌榜', '法国 NRJ Vos Hits 周榜', 'ACG动画榜', 'ACG游戏榜', 'ACG VOCALOID榜', '中国新乡村音乐排行榜', '日语榜', '摇滚榜', '国风榜', '潜力爆款榜', '民谣榜', '听歌识曲榜', '网络热歌榜', '俄语榜', '越南语榜', '中文DJ榜', '俄罗斯top hit流行音乐榜', '泰语榜', 'BEAT排行榜', 'LOOK直播歌曲榜', '赏音榜', '黑胶VIP新歌榜', '黑胶VIP热歌榜', '黑胶VIP爱搜榜'];
  }
  return ['新歌榜', '热歌榜', '原创榜', '音乐风向榜', '彩铃分贝榜', '会员臻爱榜', '港台榜', '内地榜', '欧美榜', '国风金曲榜'];
}

/**
 * 把任意值当作 JsonObject 用（取不到就返回**空对象**，绝不返回 undefined）。
 *
 * ⚠️ 为什么必须兜住 undefined/null：这个函数几乎总是被连着下标用，
 * 例如 `asObject(root['data'])['params']`。如果这里原样返回 undefined，
 * 下一层 `undefined['params']` 会抛
 * 「Cannot load property of null or undefined」——**请求成功了却在解析时崩**，
 * 表现成「这个源加载不出来」。酷狗广场就是踩了这个坑（列表响应没有 `data` 节点）。
 * 返回 `{}` 之后，所有 `asObject(...)[...]` 都退化成「读到 undefined」，只会走到各个
 * `?? 兜底`，不会再抛异常。
 */
function asObject(value: Object | undefined): JsonObject {
  if (value === undefined || value === null) {
    return {};
  }
  return value as JsonObject;
}

function asArray(value: Object | undefined): JsonObject[] {
  if (value === undefined || value === null) {
    return [];
  }
  const array = value as Object[];
  if (!Array.isArray(array)) {
    return [];
  }
  return array.map((item: Object) => asObject(item));
}

function text(value: Object | undefined): string {
  return value === undefined ? '' : `${value}`;
}

function num(value: Object | undefined): number {
  const parsed = Number(text(value));
  return Number.isNaN(parsed) ? 0 : parsed;
}

function countText(value: Object | undefined): string {
  const n = num(value);
  if (n >= 100000000) {
    return `${(n / 100000000).toFixed(1)} 亿`;
  }
  if (n >= 10000) {
    return `${(n / 10000).toFixed(1)} 万`;
  }
  return n > 0 ? `${n}` : '';
}

function singerText(value: Object | undefined): string {
  if (value === undefined) {
    return '';
  }
  if (Array.isArray(value)) {
    return (value as Object[]).map((item: Object) => {
      const obj = asObject(item);
      return text(obj['name'] ?? obj['singerName'] ?? obj['author_name']);
    }).filter((item: string) => item.length > 0).join('、');
  }
  return text(value);
}

function albumText(value: Object | undefined): string {
  if (value === undefined) {
    return '';
  }
  if (typeof value === 'object') {
    return text(asObject(value)['name'] ?? asObject(value)['albumName']);
  }
  return text(value);
}

function durationText(value: Object | undefined, milliseconds: boolean = false): string {
  if (value === undefined) {
    return '';
  }
  const raw = text(value).trim();
  if (raw.length === 0) {
    return '';
  }
  const parts = raw.split(':');
  if (parts.length === 2) {
    const minutes = Number(parts[0]);
    const seconds = Number(parts[1]);
    if (!Number.isNaN(minutes) && !Number.isNaN(seconds)) {
      return `${Math.max(0, Math.trunc(minutes)).toString().padStart(2, '0')}:${Math.max(0, Math.trunc(seconds)).toString().padStart(2, '0')}`;
    }
  }
  if (parts.length === 3) {
    const minutes = Number(parts[1]);
    const seconds = Number(parts[2]);
    if (!Number.isNaN(minutes) && !Number.isNaN(seconds)) {
      return `${Math.max(0, Math.trunc(minutes)).toString().padStart(2, '0')}:${Math.max(0, Math.trunc(seconds)).toString().padStart(2, '0')}`;
    }
  }
  const numberValue = Number(raw);
  if (Number.isNaN(numberValue) || numberValue <= 0) {
    return '';
  }
  const totalSeconds = Math.trunc(milliseconds ? numberValue / 1000 : numberValue);
  const minutes = Math.trunc(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

function arrayCount(value: Object | undefined): string {
  if (value === undefined) {
    return '';
  }
  return Array.isArray(value) ? `${(value as Object[]).length}` : countText(value);
}

function dateText(value: Object | undefined): string {
  const rawText = value === undefined ? '' : text(value).trim();
  if (/^\d{4}[-/]\d{1,2}[-/]\d{1,2}/.test(rawText)) {
    return rawText.substring(0, 10).replace(/\//g, '-');
  }
  const raw = num(value);
  if (raw <= 0) {
    return '';
  }
  const millis = raw < 100000000000 ? raw * 1000 : raw;
  const date = new Date(millis);
  return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
}

async function requestMiguTrackDetails(ids: string[]): Promise<JsonObject[]> {
  if (ids.length === 0) {
    return [];
  }
  const root = await requestFormJson(
    'https://c.musicapp.migu.cn/MIGUM2.0/v1.0/content/resourceinfo.do?resourceType=2',
    `resourceId=${encodeURIComponent(ids.join('|'))}`
  );
  return asArray(root['resource']);
}

async function requestJsonValue(url: string, method: http.RequestMethod = http.RequestMethod.GET,
  body?: string, extraHeaders?: Record<string, string>): Promise<Object> {
  const request = http.createHttp();
  try {
    const headers: Record<string, string> = { 'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0' };
    if (extraHeaders !== undefined) {
      Object.keys(extraHeaders).forEach((key: string) => {
        headers[key] = extraHeaders[key];
      });
    }
    const response = await request.request(url, {
      method,
      header: headers,
      extraData: body,
      connectTimeout: 8000,
      readTimeout: 12000
    });
    return JSON.parse(response.result as string) as Object;
  } catch (err) {
    // 记一条带错误码的日志再抛：否则调用方只看到「加载失败」，
    // 分不清明文被拦(2300997) / DNS(2300006) / 连不上(2300007) / 证书(2300060)。
    logHttpFailure('requestJsonValue', url, err);
    throw err as Error;
  } finally {
    request.destroy();
  }
}

async function requestJson(url: string, method: http.RequestMethod = http.RequestMethod.GET,
  body?: string, extraHeaders?: Record<string, string>): Promise<JsonObject> {
  return asObject(await requestJsonValue(url, method, body, extraHeaders));
}

async function requestMiguJsonValue(url: string): Promise<Object> {
  let lastError: Error = new Error('Migu request failed');
  for (let retry = 0; retry < 3; retry++) {
    try {
      return await requestJsonValue(url, http.RequestMethod.GET, undefined, MIGU_HEADERS);
    } catch (error) {
      lastError = error as Error;
    }
  }
  throw lastError;
}

async function requestKuwoJson(url: string): Promise<JsonObject> {
  let lastError: Error = new Error('Kuwo request failed');
  for (let retry = 0; retry < 3; retry++) {
    try {
      const root = await requestJson(url);
      if (num(root['code']) === 200) {
        return root;
      }
      lastError = new Error(`Kuwo response code: ${text(root['code'])}`);
    } catch (error) {
      lastError = error as Error;
    }
  }
  throw lastError;
}

/**
 * 酷狗 `yueku/v9/special/getSpecial` 专用请求（歌单广场的分类 + 列表都走它）。
 *
 * 为什么要单独包一层：
 *   1. 这两个接口是 **HTTP 明文**，偶发失败要重试（和酷我一样的 3 次）；
 *   2. `status !== 1` 时接口其实没给数据（例如分类参数不对），必须**抛错**，
 *      否则调用方会把它当成「成功但列表为空」——界面上就是「一直在加载/什么都没有」，
 *      连错误提示都不给（歌单广场酷狗加载不出来就是这个症状）；
 *   3. 顺手带上 `Referer: https://www.kugou.com/`，省得被 CDN 当成爬虫。
 *
 * 实测响应结构（2026-09 抓包）：
 *   列表   `?is_ajax=1&cdn=cdn&t=5&c=&p=1`  → `{ status, special_db: [...] }`（**没有 data 包壳**）
 *   分类   `?is_smarty=1&cdn=cdn`           → `{ status, data: { hotTag, tagids, params } }`
 */
async function requestKgJson(url: string): Promise<JsonObject> {
  let lastError: Error = new Error('Kugou request failed');
  for (let retry = 0; retry < 3; retry++) {
    try {
      const root = await requestJson(url, http.RequestMethod.GET, undefined,
        { 'Referer': 'https://www.kugou.com/' });
      if (num(root['status']) === 1) {
        return root;
      }
      lastError = new Error(`Kugou status=${text(root['status'])}`);
    } catch (error) {
      lastError = error as Error;
    }
  }
  hilog.warn(LOG_DOMAIN, LOG_TAG, 'kg legacy endpoint gave up: %{public}s url=%{public}s',
    lastError.message ?? '', url);
  throw lastError;
}

/**
 * 酷狗歌单广场（**HTTPS 备用通道**）：`https://m.kugou.com/plist/index&json=true&page=N`
 *
 * 定位：**只作为降级通道**。主通道是带分类/排序的 `kgPlazaLegacy`
 * （`yueku/v9/special/getSpecial`），这条只在它失败时兜底。
 *
 * 为什么留着它：主通道是明文 HTTP，而那个域名 `www2.kugou.kugou.com` 连 HTTPS 都用不了
 * （实测 TLS 握手「未能为 SSL/TLS 安全通道建立信任关系」）——一旦遇到「明文被拦」的
 * 网络环境就没有退路，这条 HTTPS 接口是那时唯一还能出数据的路。
 *
 * 接口特征（实测）：`plist.list[0]` = `{ total:600, has_next:1, info:[30 条] }`，
 * 字段齐全（specialid / specialname / songcount / playcount / play_count_text /
 * publishtime / username / imgurl），`page` 参数分页有效；封面 `imgurl` 里的 `{size}`
 * 占位要替换，域名 `imgessl.kugou.com` 是 HTTPS。
 * 缺陷：不认识排序参数（实测 t/sort/order 都返回同一批 id），也没有分类 —— 降级时功能缩水。
 *
 * @returns 成功返回列表页；拿不到真数据时 reject。
 */
async function kgPlazaViaHttps(pageNumber: number, limit: number): Promise<PlaylistPage> {
  const url: string = `https://m.kugou.com/plist/index&json=true&page=${pageNumber}`;
  const root: JsonObject = await requestJson(url, http.RequestMethod.GET, undefined,
    { 'Referer': 'https://m.kugou.com/' });
  const listNode = asObject(root['plist'])['list'];
  const wrapper: JsonObject = Array.isArray(listNode) ? asObject(asArray(listNode)[0]) : asObject(listNode);
  const info: JsonObject[] = asArray(wrapper['info']);
  if (info.length === 0) {
    throw new Error('Kugou https plaza returned no items');
  }
  const total: number = num(wrapper['total']);
  const hasNextFlag: number = num(wrapper['has_next']);
  const pageSize: number = num(root['pagesize']) || limit;
  const list: PlaylistData[] = info.map((item: JsonObject): PlaylistData => ({
    id: text(item['specialid']),
    name: text(item['specialname']),
    author: text(item['username'] ?? item['nickname']),
    // imgurl 形如 https://imgessl.kugou.com/soft/collection/{size}/...jpg
    image: text(item['imgurl']).replace('{size}', '240'),
    count: text(item['songcount'] ?? item['song_count']),
    time: dateText(item['publishtime'] ?? item['publish_time']),
    // play_count_text 是「1689.9万」这种现成文案，直接用
    listenCount: text(item['play_count_text'] ?? item['playcount'] ?? item['play_count']),
    category: text(item['tagname']),
    source: 'kg'
  })).filter((item: PlaylistData) => item.name.length > 0);
  if (list.length === 0) {
    throw new Error('Kugou https plaza items all unnamed');
  }
  const hasNext: boolean = total > 0
    ? pageNumber * pageSize < total
    : hasNextFlag === 1 || list.length >= pageSize;
  // 降级路径留一条 hilog（应用内日志面板不再输出）
  hilog.info(LOG_DOMAIN, LOG_TAG, 'kg https channel ok: items=%{public}d total=%{public}d',
    list.length, total);
  return { list, page: pageNumber, limit: pageSize, total, hasNext };
}

/**
 * 酷狗歌单广场（**老线路，明文 HTTP**）：`yueku/v9/special/getSpecial`
 *
 * 保留原因：它认识 `t=` 排序参数（推荐/最热/最新/热藏/飙升），而 HTTPS 那条不认识。
 * 两条并行发、谁先有真数据用谁，见 `playlists()` 里的 `Promise.any`。
 *
 * 注意响应层级（实测）：列表 `{status, special_db:[…]}` 的 `special_db` 在**根节点**，
 * 没有 `data` 包壳；分类 `{status, data:{hotTag,tagids}}` 才有 `data`。
 * 这里两种都认，避免再犯「取 data.special_db 永远为空」的老错。
 *
 * @returns 成功返回列表页；`status !== 1` 或解析为空时 reject（由 Promise.any 判负）。
 */
async function kgPlazaLegacy(pageNumber: number, selectedSort: string,
  categoryId?: string): Promise<PlaylistPage> {
  const url: string =
    `http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_ajax=1&cdn=cdn&t=${selectedSort}&c=${categoryId ?? ''}&p=${pageNumber}`;
  const root: JsonObject = await requestKgJson(url);
  // ⚠️ 这里曾经这么写（错）：
  //     asObject(root['params'] ?? asObject(root['data'])['params'])
  //   列表响应里**没有 `data` 节点**，`asObject(undefined)` 返回 undefined，
  //   接着读 `undefined['params']` 就抛
  //   「Cannot load property of null or undefined」—— 请求明明成功、却在解析时崩，
  //   然后被降级到 HTTPS 通道（表现为「老接口没有分类/排序」）。
  //   正确做法：先安全取出 `data`（可能是空对象），再逐层兜底。
  const dataNode: JsonObject = asObject(root['data']);
  const rootList: JsonObject[] = asArray(root['special_db']);
  const nestedList: JsonObject[] = asArray(dataNode['special_db']);
  const raw: JsonObject[] = rootList.length > 0 ? rootList : nestedList;
  const params: JsonObject = asObject(root['params'] ?? dataNode['params']);
  const limit: number = num(params['pagesize']) || 20;
  if (raw.length === 0) {
    throw new Error('Kugou plaza returned no items');
  }
  const list: PlaylistData[] = raw
    .map((item: JsonObject): PlaylistData => formatPlaylist('kg', item))
    .filter((item: PlaylistData) => item.name.length > 0);
  if (list.length === 0) {
    throw new Error('Kugou plaza items all unnamed');
  }
  const total: number = num(params['total']);
  const responsePage: number = num(params['p']) || pageNumber;
  const hasNext: boolean = total > 0 ? responsePage * limit < total : list.length >= limit;
  return { list, page: responsePage, limit, total, hasNext };
}

async function requestFormJson(url: string, body: string): Promise<JsonObject> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'Mozilla/5.0' },
      extraData: body,
      connectTimeout: 8000,
      readTimeout: 15000
    });
    return asObject(JSON.parse(response.result as string) as Object);
  } finally {
    request.destroy();
  }
}



async function neteaseLinuxParams(value: NeteaseLinuxParams): Promise<string> {
  const textValue = JSON.stringify(value);
  const key: cryptoFramework.DataBlob = { data: new Uint8Array(buffer.from('rFgB&h#%2?^eDg:Q', 'utf-8').buffer) };
  const cipher = cryptoFramework.createCipher('AES128|ECB|PKCS5');
  const symKey = cryptoFramework.createSymKeyGenerator('AES128');
  const result = cipher;
  result.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, await symKey.convertKey(key), null);
  const encrypted = result.doFinalSync({ data: new Uint8Array(buffer.from(textValue, 'utf-8').buffer) });
  return `eparams=${buffer.from(encrypted.data).toString('hex').toUpperCase()}`;
}



async function requestNeteaseRank(boardId: string): Promise<JsonObject> {
  const requestParams: JsonObject = {};
  requestParams['id'] = boardId;
  requestParams['n'] = 100000;
  requestParams['s'] = 8;
  const requestBody: NeteaseLinuxParams = {
    method: 'POST',
    url: 'https://music.163.com/api/v3/playlist/detail',
    params: requestParams
  };
  const params = await neteaseLinuxParams(requestBody);
  return requestFormJson('https://music.163.com/api/linux/forward', params);
}

function kwSongId(item: JsonObject): string {
  const rid = text(item['rid']);
  if (rid.length > 0) {
    return rid;
  }
  const musicrid = text(item['musicrid']);
  if (musicrid.startsWith('MUSIC_')) {
    return musicrid.substring('MUSIC_'.length);
  }
  if (musicrid.length > 0) {
    return musicrid;
  }
  // kbangserver.kuwo.cn/ksong.s 的榜单歌曲用 `id` 这个字段（既不是 rid 也不是 musicrid）
  return text(item['id']);
}

function formatPlaylist(source: string, item: JsonObject): PlaylistData {
  if (source === 'kw') {
    return { id: text(item['id']), name: text(item['name']), author: text(item['uname']), image: text(item['img']), count: text(item['total']), time: dateText(item['publish_time']), listenCount: countText(item['listencnt']), category: text(item['tag']), source };
  }
  if (source === 'kg') {
    // 广场接口给的 play_count 常常是 0，而 total_play_count/collect_count 有值，
    // 依次兜底，免得卡片上「播放量」永远是 0
    return { id: text(item['specialid']), name: text(item['specialname']), author: text(item['nickname']), image: text(item['img'] ?? item['imgurl']), count: text(item['song_count'] ?? item['songcount']), time: dateText(item['publish_time'] ?? item['publishtime']), listenCount: text(item['total_play_count'] ?? item['play_count'] ?? item['collect_count']), category: text(item['tagname']), source };
  }
  if (source === 'tx' && item['basic'] !== undefined) {
    const basic = asObject(item['basic']);
    const cover = asObject(basic['cover']);
    const creator = asObject(basic['creator']);
    return { id: text(basic['tid']), name: text(basic['title']), author: text(creator['nick']), image: text(cover['medium_url'] ?? cover['default_url']), count: '', time: '', listenCount: countText(basic['play_cnt']), category: '', source };
  }
  if (source === 'tx') {
    return { id: text(item['tid']), name: text(item['title']), author: text(asObject(item['creator_info'])['nick']), image: text(item['cover_url_medium']), count: arrayCount(item['song_ids']), time: dateText(item['modify_time']), listenCount: countText(item['access_num']), category: text(item['tag_name']), source };
  }
  if (source === 'mg') {
    return { id: text(item['contentId'] ?? item['playlistId']), name: text(item['title'] ?? item['playlistName']), author: text(item['ownerName']), image: text(item['img'] ?? item['image']), count: text(item['songCount']), time: dateText(item['createTime']), listenCount: countText(item['playNum']), category: text(item['categoryName']), source };
  }
  return { id: text(item['id']), name: text(item['name']), author: text(asObject(item['creator'])['nickname']), image: text(item['coverImgUrl']), count: text(item['trackCount']), time: dateText(item['createTime']), listenCount: countText(item['playCount']), category: text(item['category']), source };
}

function collectMiguPlaylists(items: JsonObject[], result: PlaylistData[]): void {
  items.forEach((item: JsonObject) => {
    const nested = asArray(item['contents']);
    const contentGroups = asArray(item['contentItemList']);
    const itemList = asArray(item['itemList']);
    const logEventValue = item['logEvent'];
    const logEvent: JsonObject = logEventValue === undefined ? {} : asObject(logEventValue);
    const barList = asArray(item['barList']);
    if (logEvent['contentId'] !== undefined && (item['title'] !== undefined || item['txt'] !== undefined)) {
      result.push({
        id: text(logEvent['contentId']),
        name: text(item['title'] ?? item['txt']),
        author: '',
        image: text(item['imageUrl'] ?? item['img']),
        count: '',
        time: '',
        listenCount: barList.length > 0 ? text(asObject(barList[0])['title']) : '',
        category: '',
        source: 'mg'
      });
    }
    const resourceId = text(item['resId'] ?? item['resourceId']);
    const title = text(item['txt'] ?? item['title']);
    if (resourceId.length > 0 && title.length > 0 && logEvent['contentId'] === undefined && !result.some((entry: PlaylistData) => entry.id === resourceId)) {
      result.push({ id: resourceId, name: title, author: '', image: text(item['img']), count: '', time: '', listenCount: '', category: '', source: 'mg' });
    }
    if (nested.length > 0) {
      collectMiguPlaylists(nested, result);
    }
    if (contentGroups.length > 0) {
      collectMiguPlaylists(contentGroups, result);
    }
    if (itemList.length > 0) {
      collectMiguPlaylists(itemList, result);
    }
  });
}

function formatTrack(source: string, item: JsonObject): TrackData {
  if (source === 'kg') {
    return { songId: text(item['hash']), name: text(item['songname']), artist: singerText(item['authors'] ?? item['singername']), album: albumText(item['remark'] ?? item['album_name']), image: '', duration: durationText(item['duration']), source };
  }
  if (source === 'mg') {
    return { songId: text(item['copyrightId'] ?? item['songId']), name: text(item['songName'] ?? item['songname']), artist: singerText(item['artists'] ?? item['singerList'] ?? item['singerName'] ?? item['singer']), album: albumText(item['album'] ?? item['albumName']), image: text(item['img3'] ?? item['img2'] ?? item['albumPic']), duration: durationText(item['length'] ?? item['duration']), source };
  }
  if (source === 'tx') {
    // ⚠️ QQ 榜单的 albummid 在 `songlist[].data.albummid` 里，不在外层。
    //    只读外层会永远拿不到 albumMid → 拼不出封面 → 未登录时首页 QQ 整排没封面。
    //    这里兼容两种层级（榜单 / 搜索返回的结构不同）。
    const inner = asObject(item['data']);
    const albumMid = text(item['albumMid'] ?? item['albummid'] ?? inner['albummid'] ?? inner['albumMid']);
    const cover = albumMid.length > 0
      ? `https://y.gtimg.cn/music/photo_new/T002R300x300M000${albumMid}.jpg` : '';
    const singerValue = item['singer'] ?? item['singerName'] ?? item['artists'] ?? inner['singer'];
    return { songId: text(item['mid'] ?? item['songmid'] ?? inner['songmid'] ?? inner['mid']), name: text(item['songName'] ?? item['title'] ?? inner['songname'] ?? inner['songname']), artist: singerText(singerValue), album: albumText(item['album'] ?? item['albumName'] ?? inner['albumname']), image: cover, duration: durationText(item['interval'] ?? inner['interval']), source };
  }
  if (source === 'kw') {
    return { songId: kwSongId(item), name: text(item['name'] ?? item['songname']), artist: singerText(item['artist'] ?? item['singer'] ?? item['artists']), album: albumText(item['album'] ?? item['albumName']), image: text(item['pic']), duration: durationText(item['duration']), source };
  }
  const artists = asArray(item['ar']).map((artist: JsonObject) => text(artist['name'])).join('、');
  return { songId: text(item['id']), name: text(item['name']), artist: artists, album: text(asObject(item['al'])['name']), image: text(asObject(item['al'])['picUrl']), duration: durationText(item['dt'], true), source };
}

/**
 * 首页「精选推荐」默认使用的榜单。
 *
 * 需求：**未登录时不要用整张榜单列表拼歌，而是固定用一个内容最稳的榜单**。
 *   - QQ  → 新歌榜（topid 27）
 *   - 酷狗 → 飙升榜（rankid 6666）
 *   - 网易 → 飙升榜（playlist 19723756）
 * 榜单 id 都实测过可用。
 *
 * @param source 平台代号（tx / kg / wy）。
 * @returns 榜单 id；未知平台返回空串（调用方回落到第一个榜单）。
 */
export function pickDedicatedBoardId(source: string): string {
  if (source === 'tx') {
    return '27';
  }
  if (source === 'kg') {
    return '6666';
  }
  if (source === 'wy') {
    return '19723756';
  }
  return '';
}

export class MusicDataService {
  static readonly sourceList: string[] = SOURCES;

  static sourceName(source: string): string {
    return sourceDisplayName(source);
  }

  static sortOptions(source: string): SortOption[] {
    // 酷狗老接口（`yueku/v9/special/getSpecial`）**认 `t=` 排序参数**，所以这里保留
    // 完整排序胶囊。注意：只有当广场走的是老接口时才有效 —— 万一降级到 HTTPS 通道
    // （`m.kugou.com/plist/index`），排序参数会被忽略，但分类和排序的 UI 仍然正确存在，
    // 只是点了不换数据；日志里会出现「本次由 HTTPS 通道兜底」提示降级。
    if (source === 'kg') {
      return [{ id: '5', name: '推荐' }, { id: '6', name: '最热' }, { id: '7', name: '最新' }, { id: '3', name: '热藏' }, { id: '8', name: '飙升' }];
    }
    if (source === 'kw') {
      return [{ id: 'new', name: '最新' }, { id: 'hot', name: '最热' }];
    }
    if (source === 'tx') {
      return [{ id: '5', name: '最热' }, { id: '2', name: '最新' }];
    }
    if (source === 'wy') {
      return [{ id: 'hot', name: '最热' }];
    }
    return [{ id: '15127315', name: '推荐' }];
  }

  static async categories(source: string): Promise<CategoryGroup[]> {
    try {
      if (source === 'kw') {
        const tagUrl = 'http://wapi.kuwo.cn/api/pc/classify/playlist/getTagList?cmd=rcm_keyword_playlist&user=0&prod=kwplayer_pc_9.0.5.0&vipver=9.0.5.0&source=kwplayer_pc_9.0.5.0&loginUid=0&loginSid=0&appUid=76039576';
        const hotUrl = 'http://wapi.kuwo.cn/api/pc/classify/playlist/getRcmTagList?loginUid=0&loginSid=0&appUid=76039576';
        const tagRoot = await requestKuwoJson(tagUrl);
        const hotRoot = await requestKuwoJson(hotUrl);
        const groups: CategoryGroup[] = [];
        const hotData = asArray(asArray(hotRoot['data'])[0]?.['data']);
        if (hotData.length > 0) {
          groups.push({ title: '热门标签', items: hotData.map((item: JsonObject): CategoryOption => ({ id: `${text(item['id'])}-${text(item['digest'])}`, name: text(item['name']) })) });
        }
        asArray(tagRoot['data']).forEach((type: JsonObject) => {
          const items = asArray(type['data']).map((item: JsonObject): CategoryOption => ({ id: `${text(item['id'])}-${text(item['digest'])}`, name: text(item['name']) }));
          if (items.length > 0) {
            groups.push({ title: text(type['name']), items });
          }
        });
        return groups;
      }
      if (source === 'kg') {
        const root = await requestKgJson('http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_smarty=1&cdn=cdn');
        const data = asObject(root['data']);
        const groups: CategoryGroup[] = [];
        const hotData = asObject(asObject(data['hotTag'])['data']);
        const hotItems: CategoryOption[] = [];
        Object.keys(hotData).forEach((key: string) => {
          const item = asObject(hotData[key]);
          hotItems.push({ id: text(item['special_id']), name: text(item['special_name']) });
        });
        if (hotItems.length > 0) {
          groups.push({ title: '热门标签', items: hotItems });
        }
        const tagids = asObject(data['tagids']);
        Object.keys(tagids).forEach((name: string) => {
          const groupData = asObject(tagids[name]);
          const items = asArray(groupData['data']).map((item: JsonObject): CategoryOption => ({ id: text(item['id']), name: text(item['name']) }));
          if (items.length > 0) {
            groups.push({ title: name, items });
          }
        });
        return groups;
      }
      if (source === 'tx') {
        const url = 'https://u.y.qq.com/cgi-bin/musicu.fcg?loginUin=0&hostUin=0&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=wk_v15.json&needNewCode=0&data=%7B%22tags%22%3A%7B%22method%22%3A%22get_all_categories%22%2C%22param%22%3A%7B%22qq%22%3A%22%22%7D%2C%22module%22%3A%22playlist.PlaylistAllCategoriesServer%22%7D%7D';
        const root = await requestJson(url);
        const groups: CategoryGroup[] = [];
        const rawGroups = asArray(asObject(asObject(root['tags'])['data'])['v_group']);
        rawGroups.forEach((group: JsonObject) => {
          const items = asArray(group['v_item']).map((item: JsonObject): CategoryOption => ({ id: text(item['id']), name: text(item['name']) }));
          if (items.length > 0) {
            groups.push({ title: text(group['group_name']), items });
          }
        });
        return groups;
      }
      if (source === 'wy') {
        const root = await requestJson('https://music.163.com/api/playlist/catalogue');
        const categories = asObject(root['categories']);
        const grouped: CategoryOption[][] = [[], [], [], [], []];
        asArray(root['sub']).forEach((item: JsonObject) => {
          const category = num(item['category']);
          if (category >= 0 && category < grouped.length) {
            grouped[category].push({ id: text(item['name']), name: text(item['name']) });
          }
        });
        const groups: CategoryGroup[] = [];
        Object.keys(categories).sort((a: string, b: string) => Number(a) - Number(b)).forEach((key: string) => {
          const items = grouped[Number(key)];
          if (items.length > 0) {
            groups.push({ title: text(categories[key]), items });
          }
        });
        return groups;
      }
      const root = await requestJson('https://app.c.nf.migu.cn/pc/v1.0/template/musiclistplaza-taglist/release', http.RequestMethod.GET, undefined, MIGU_HEADERS);
      const groups: CategoryGroup[] = [];
      asArray(root['data']).forEach((rawGroup: JsonObject, index: number) => {
        const content = asArray(rawGroup['content']);
        const items: CategoryOption[] = [];
        content.forEach((item: JsonObject) => {
          const values = item['texts'] as Object[];
          if (values !== undefined && values.length > 1) {
            items.push({ id: text(values[1]), name: text(values[0]) });
          }
        });
        const header = asObject(rawGroup['header']);
        const title = index === 0 ? '热门标签' : text(header['title']);
        if (items.length > 0) {
          groups.push({ title, items });
        }
      });
      return groups;
    } catch (_err) {
      return [];
    }
  }

  static async playlists(source: string, sortId?: string, categoryId?: string, page: number = 1): Promise<PlaylistPage> {
    let url = '';
    const selectedSort = sortId ?? (MusicDataService.sortOptions(source).length > 0
      ? MusicDataService.sortOptions(source)[0].id
      : '');
    const pageNumber = Math.max(1, page);
    // 酷狗有两条通道，顺序按「功能完整度」定：
    //   主通道（明文）`www2.kugou.kugou.com/yueku/v9/special/getSpecial` —— 带**分类 + 排序**
    //   备用通道（HTTPS）`m.kugou.com/plist/index` —— 只认 page，无分类无排序
    // 备用通道存在的意义：主通道那个域名连 HTTPS 都用不了（TLS 握不上），
    // 一旦遇到「明文被封」的网络环境，它是唯一还能出数据的路。
    if (source === 'kg') {
      let legacyPage: PlaylistPage | null = null;
      try {
        legacyPage = await kgPlazaLegacy(pageNumber, selectedSort, categoryId);
      } catch (err) {
        const e: Error = err as Error;
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'kg legacy plaza failed: %{public}s → fallback to https', e.message ?? '');
      }
      if (legacyPage !== null) {
        return legacyPage;
      }
      try {
        const httpsPage: PlaylistPage = await kgPlazaViaHttps(pageNumber, 30);
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'kg plaza served by HTTPS fallback (no category/sort): items=%{public}d', httpsPage.list.length);
        return httpsPage;
      } catch (err) {
        const e: Error = err as Error;
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'kg https plaza also failed: %{public}s', e.message ?? '');
        // 继续走下面的老代码（会再抛一次，由上层给出错误文案）
      }
    }
    if (source === 'kw') {
      if (categoryId !== undefined && categoryId.length > 0) {
        const parts = categoryId.split('-');
        const id = parts[0];
        const type = parts.length > 1 ? parts[1] : '10000';
        url = type === '43'
          ? `http://mobileinterfaces.kuwo.cn/er.s?type=get_pc_qz_data&f=web&id=${id}&prod=pc`
          : `http://wapi.kuwo.cn/api/pc/classify/playlist/getTagPlayList?loginUid=0&loginSid=0&appUid=76039576&pn=${pageNumber}&id=${id}&rn=36`;
      } else {
        url = `http://wapi.kuwo.cn/api/pc/classify/playlist/getRcmPlayList?loginUid=0&loginSid=0&appUid=76039576&&pn=${pageNumber}&rn=36&order=${selectedSort}`;
      }
    }
    if (source === 'kg') {
      url = `http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_ajax=1&cdn=cdn&t=${selectedSort}&c=${categoryId ?? ''}&p=${pageNumber}`;
    }
    if (source === 'tx') {
      const dataText = categoryId !== undefined && categoryId.length > 0
        ? `{"comm":{"cv":1602,"ct":20},"playlist":{"method":"get_category_content","param":{"titleid":${Number(categoryId)},"caller":"0","category_id":${Number(categoryId)},"size":36,"page":${pageNumber - 1},"use_page":1},"module":"playlist.PlayListCategoryServer"}}`
        : `{"playlist":{"method":"get_playlist_by_tag","param":{"id":10000000,"sin":${36 * (pageNumber - 1)},"size":36,"order":${Number(selectedSort)},"cur_page":${pageNumber}},"module":"playlist.PlayListPlazaServer"}}`;
      url = 'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&data=' + encodeURIComponent(dataText);
    }
    if (source === 'wy') {
      url = `https://music.163.com/api/playlist/list?cat=${encodeURIComponent(categoryId ?? '全部')}&order=${selectedSort}&limit=30&offset=${30 * (pageNumber - 1)}&total=true`;
    }
    if (source === 'mg') {
      url = categoryId !== undefined && categoryId.length > 0
        ? `https://app.c.nf.migu.cn/pc/v1.0/template/musiclistplaza-listbytag/release?pageNumber=${pageNumber}&templateVersion=2&tagId=${categoryId}`
        : `https://app.c.nf.migu.cn/pc/bmw/page-data/playlist-square-recommend/v1.0?templateVersion=2&pageNo=${pageNumber}`;
    }
    const rawValue = source === 'mg'
      ? await requestMiguJsonValue(url)
      : await requestJsonValue(url);
    const root = asObject(rawValue);
    // ⚠️ 酷狗广场列表的 `special_db` 在**根节点**上，没有 `data` 包壳：
    //    `{"status":1,"special_db":[...]}`。
    //    `data` 只存在于 `is_smarty=1`（分类）那个响应里。以前这里无条件取
    //    `data.special_db`，酷狗列表永远是空数组 —— 界面上「酷狗歌单广场加载不出来」
    //    （既不报错也没有内容）就是这么来的。现在两种层级都认。
    const rootKgList: JsonObject[] | undefined = source === 'kg' ? asArray(root['special_db']) : undefined;
    if (source === 'kg' && rootKgList !== undefined && rootKgList.length > 0) {
      const params = asObject(root['params']);
      const limit: number = num(params['pagesize']) || 20;
      const total: number = num(params['total']);
      const list = rootKgList
        .map((item: JsonObject): PlaylistData => formatPlaylist(source, item))
        .filter((item: PlaylistData) => item.name.length > 0);
      const responsePage: number = num(params['p']) || pageNumber;
      const hasNext: boolean = total > 0 ? responsePage * limit < total : list.length >= limit;
      return { list, page: responsePage, limit, total, hasNext };
    }
    let data = asObject(root['data'] ?? root['playlist'] ?? root['result'] ?? root);
    if (source === 'tx') {
      data = asObject(asObject(root['playlist'])['data']);
    }
    let limit = source === 'tx' ? 36 : source === 'wy' ? 30 : 36;
    let total = 0;
    let responsePage = pageNumber;
    let raw: JsonObject[] = [];
    if (source === 'kw') {
      if (Array.isArray(rawValue)) {
        const sections = asArray(rawValue);
        const flattened: JsonObject[] = [];
        sections.forEach((section: JsonObject) => {
          if (text(section['label']).length === 0) {
            return;
          }
          asArray(section['list']).forEach((item: JsonObject) => {
            flattened.push(item);
          });
        });
        raw = flattened;
        limit = 1000;
        total = 1000;
      } else {
        raw = asArray(data['data']);
        limit = num(data['rn']) || 36;
        total = num(data['total']);
        responsePage = num(data['pn']) || pageNumber;
      }
    } else if (source === 'kg') {
      raw = asArray(data['special_db']);
      const params = asObject(data['params']);
      limit = num(params['pagesize']) || 36;
      total = num(params['total']);
      responsePage = num(params['p']) || pageNumber;
    } else if (source === 'tx') {
      const content = asObject(data['content']);
      raw = asArray(data['v_playlist'] ?? content['v_item']);
      total = num(data['total'] ?? content['total_cnt']);
    } else if (source === 'wy') {
      raw = asArray(root['playlists']);
      total = num(root['total']);
    } else {
      raw = asArray(data['contents'] ?? data['itemList']);
      total = num(data['total'] ?? data['totalCount'] ?? root['total']);
    }
    if (source === 'mg') {
      const result: PlaylistData[] = [];
      collectMiguPlaylists([data], result);
      const hasNext = result.length >= limit;
      return { list: result, page: pageNumber, limit, total: total > 0 ? total : pageNumber * limit + (hasNext ? limit : 0), hasNext };
    }
    const list = raw.map((item: JsonObject): PlaylistData => formatPlaylist(source, item)).filter((item: PlaylistData) => item.name.length > 0);
    const hasNext = total > 0 ? responsePage * limit < total : list.length >= limit;
    return { list, page: responsePage, limit, total, hasNext };
  }

  static boards(source: string): BoardData[] {
    const ids = boardIdList(source);
    const names = boardNameList(source);
    return ids.map((id: string, index: number): BoardData => ({ id, name: names[index], source, cover: '' }));
  }

  /**
   * 带封面的榜单列表（**推荐走这个**）。
   *
   * 酷我走实时接口：老版写死的 id 表在酷我换版后大面积失效，列表本身就是坏的。
   * 接口失败时回退到写死的表（至少列表还在，只是可能点进去没歌）。
   *
   * @param source 平台代号（kw / kg / tx / wy / mg）。
   * @returns 榜单列表（含封面）。
   */
  static async boardsWithCovers(source: string): Promise<BoardData[]> {
    if (source === 'kw') {
      try {
        const live: KwBangEntry[] = await kwBangs();
        if (live.length > 0) {
          return live.map((item: KwBangEntry): BoardData =>
            ({ id: item.id, name: item.name, source, cover: item.cover }));
        }
      } catch (_err) {
        // 落到下面的写死表
      }
    }
    const list: BoardData[] = MusicDataService.boards(source);
    let covers: Record<string, string> = {};
    try {
      covers = await MusicDataService.boardCovers(source);
    } catch (_err) {
      covers = {};
    }
    const out: BoardData[] = [];
    for (let i: number = 0; i < list.length; i++) {
      const item: BoardData = list[i];
      const cover: string = covers[item.id] === undefined ? '' : covers[item.id];
      out.push({ id: item.id, name: item.name, source: item.source, cover });
    }
    return out;
  }

  /**
   * Fetches board cover images for a source (netease toplist list / kugou rank
   * list). Results are cached per source for the session; failures return an
   * empty map so callers fall back to placeholders.
   */
  static async boardCovers(source: string): Promise<Record<string, string>> {
    const cached: Record<string, string> | undefined = boardCoverCache.get(source);
    if (cached !== undefined) {
      return cached;
    }
    const map: Record<string, string> = {};
    try {
      if (source === 'wy') {
        const root: JsonObject = await requestJson('https://music.163.com/api/toplist');
        const items: JsonObject[] = asArray(root['list']);
        for (let i: number = 0; i < items.length; i++) {
          const id: string = text(items[i]['id']);
          const cover: string = text(items[i]['coverImgUrl']);
          if (id.length > 0 && cover.length > 0) {
            map[id] = cover;
          }
        }
      } else if (source === 'kg') {
        await fillKgCovers(map);
      } else if (source === 'tx' || source === 'qq') {
        await fillTxCovers(map);
      } else if (source === 'kw') {
        await fillKwCovers(map);
      } else if (source === 'mg') {
        await fillMgCovers(map);
      }
    } catch (_err) {
      return map;
    }
    if (Object.keys(map).length > 0) {
      boardCoverCache.set(source, map);
    }
    return map;
  }

  /**
   * 把榜单歌曲转成路由参数里的条目。
   * @param source 平台代号。
   * @param boardId 榜单 id。
   * @returns 歌曲条目数组；失败返回空数组。
   */
  static async boardSongParams(source: string, boardId: string): Promise<BoardSongParam[]> {
    const songs: BoardSongParam[] = [];
    try {
      const tracks: TrackData[] = await MusicDataService.tracks(source, boardId);
      for (let i: number = 0; i < tracks.length; i++) {
        const t = tracks[i];
        if (t.songId.length === 0) {
          continue;
        }
        const song: BoardSongParam = {
          title: t.name, singer: t.artist, source: t.source, songId: t.songId, coverUrl: t.image
        };
        songs.push(song);
      }
    } catch (_err) {
      // 失败就返回空数组，由详情页显示空态
    }
    return songs;
  }

  /**
   * 组装打开榜单详情页的路由参数。
   *
   * **只取封面，不预取歌曲**：歌曲交给详情页自己异步拉（`player.fetchBoardSongs`），
   * 这样点击后页面立刻出现、列表里显示加载骨架；预取会让"点一下 → 页面出现"之间卡住。
   * 封面很快（榜单列表本身带封面、且有会话缓存），且 Hero 大图必须首帧就有，
   * 所以这里保留同步等待。
   *
   * @param source 平台代号。
   * @param boardId 榜单 id。
   * @param boardName 榜单名（做标题）。
   * @returns 已填好封面与标识的路由参数。
   */
  static async buildBoardRouteParam(source: string, boardId: string, boardName: string): Promise<ToplistRouteParam> {
    const param = new ToplistRouteParam();
    param.listTitle = boardName;
    param.boardSource = source;
    param.boardId = boardId;
    // 榜单自己的封面（不是榜单里第一首歌的封面）。取不到就留空，由详情页显示占位图。
    try {
      const covers: Record<string, string> = await MusicDataService.boardCovers(source);
      const boardCover: string = covers[boardId];
      if (boardCover !== undefined && boardCover.length > 0) {
        param.listCover = boardCover;
      }
    } catch (_err) {
      // 封面获取失败不影响打开榜单
    }
    return param;
  }

  static async tracks(source: string, boardId: string): Promise<TrackData[]> {
    let root: JsonObject;
    if (source === 'kg') {
      root = await requestJson(`http://mobilecdnbj.kugou.com/api/v3/rank/song?version=9108&ranktype=1&plat=0&pagesize=100&area_code=1&page=1&rankid=${boardId}&with_res_tag=0&show_portrait_mv=1`);
    } else if (source === 'wy') {
      root = await requestNeteaseRank(boardId);
    } else if (source === 'mg') {
      root = await requestJson(`https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/querycontentbyId.do?columnId=${boardId}&needAll=0`);
    } else if (source === 'tx') {
      root = await requestJson('https://u.y.qq.com/cgi-bin/musicu.fcg', http.RequestMethod.POST, `{"toplist":{"module":"musicToplist.ToplistInfoServer","method":"GetDetail","param":{"topid":${Number(boardId)},"num":100}},"comm":{"uin":0,"format":"json","ct":20,"cv":1859}}`);
    } else {
      // 酷我：老签名接口（wbd.kuwo.cn，AppId 已被封）换成 kbangserver.kuwo.cn/ksong.s
      root = await requestKwBangSongs(boardId);
    }
    let data = asObject(root['data'] ?? root['result'] ?? root['toplist'] ?? root);
    if (source === 'mg') {
      data = asObject(root['columnInfo']);
    }
    let raw: JsonObject[] = [];
    if (source === 'kg') {
      raw = asArray(data['info']);
    } else if (source === 'wy') {
      raw = asArray(asObject(data['playlist'] ?? root['playlist'])['tracks']);
    } else if (source === 'mg') {
      raw = asArray(data['contents']).map((item: JsonObject) => asObject(item['objectInfo']));
    } else if (source === 'tx') {
      raw = asArray(asObject(data['data'])['songInfoList']);
    } else {
      raw = asArray(asObject(data['data'] ?? data)['musiclist'] ?? data['musiclist']);
    }
    if (source === 'mg') {
      const ids = raw.map((item: JsonObject) => text(item['songId'] ?? item['copyrightId'])).filter((id: string) => id.length > 0);
      try {
        const details = await requestMiguTrackDetails(ids);
        if (details.length > 0) {
          raw = details;
        }
      } catch (_err) {
      }
    }
    return raw.map((item: JsonObject): TrackData => formatTrack(source, item)).filter((item: TrackData) => item.name.length > 0);
  }
}
