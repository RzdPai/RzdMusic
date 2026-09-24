import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LXSearchSong, LXQualityType, lxResolveTxNumId, lxSearch } from './LXMusicSDK';
import { LXUserApiSourceInfo } from './Interface';

const LOG_DOMAIN: number = 0x0000;
const LOG_TAG: string = 'RzdLxQuality';

/** 音质选项（对齐 lx-music/mg3 的 QualityOption：type + 字节大小）。 */
export class LXQualityOption {
  type: string = '';
  size: number = 0;

  static of(type: string, size: number): LXQualityOption {
    const q = new LXQualityOption();
    q.type = type;
    q.size = size;
    return q;
  }
}

const QUALITY_TIMEOUT: number = 15000;

function numOf(obj: Record<string, Object>, key: string): number {
  const v = obj[key] as number;
  return v === undefined || v === null ? 0 : v;
}

async function httpGetText(url: string, headers: Record<string, string> = {}): Promise<string> {
  const client = http.createHttp();
  try {
    const resp = await client.request(url, {
      method: http.RequestMethod.GET,
      connectTimeout: QUALITY_TIMEOUT,
      readTimeout: QUALITY_TIMEOUT,
      header: headers
    });
    if (resp.responseCode === 200 && typeof resp.result === 'string') {
      return resp.result as string;
    }
    // 失败要留痕：以前这里静默返回空串，上层只能看到「暂无可用音质」，查不出是接口挂了
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'http GET failed code=%{public}d url=%{public}s',
      resp.responseCode, url);
    return '';
  } catch (err) {
    const e: Error = err as Error;
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'http GET threw url=%{public}s : %{public}s', url, e.message ?? '');
    return '';
  } finally {
    client.destroy();
  }
}

async function httpPostText(url: string, body: string,
  headers: Record<string, string> = {}): Promise<string> {
  const client = http.createHttp();
  try {
    const resp = await client.request(url, {
      method: http.RequestMethod.POST,
      connectTimeout: QUALITY_TIMEOUT,
      readTimeout: QUALITY_TIMEOUT,
      header: headers,
      extraData: body
    });
    if (resp.responseCode === 200 && typeof resp.result === 'string') {
      return resp.result as string;
    }
    return '';
  } catch (_e) {
    return '';
  } finally {
    client.destroy();
  }
}

/** 解析 N_MINFO 的 size 字段字符串（如 '3.5MB' / '1024KB' / '1.2GB' / '123456'）为字节。 */
function parseSizeStr(sizeStr: string): number {
  if (sizeStr === '') {
    return 0;
  }
  let numEnd: number = 0;
  while (numEnd < sizeStr.length) {
    const ch: string = sizeStr.charAt(numEnd);
    if ((ch >= '0' && ch <= '9') || ch === '.') {
      numEnd += 1;
    } else {
      break;
    }
  }
  if (numEnd === 0) {
    return 0;
  }
  const num: number = Number(sizeStr.substring(0, numEnd));
  if (Number.isNaN(num)) {
    return 0;
  }
  const unit: string = sizeStr.substring(numEnd).toLowerCase();
  if (unit.startsWith('gb')) {
    return Math.floor(num * 1024 * 1024 * 1024);
  }
  if (unit.startsWith('mb')) {
    return Math.floor(num * 1024 * 1024);
  }
  if (unit.startsWith('kb')) {
    return Math.floor(num * 1024);
  }
  return Math.floor(num);
}

/** 搜索结果预解析的 types -> 音质选项（kw / mg 兜底路径）。 */
function typesToOptions(types: LXQualityType[]): LXQualityOption[] {
  const list: LXQualityOption[] = [];
  for (let i: number = 0; i < types.length; i++) {
    list.push(LXQualityOption.of(types[i].type, parseSizeStr(types[i].size)));
  }
  return list;
}

// ===================== WY（music.163.com 歌曲音质明细，实时查询） =====================

/**
 * 网易云歌曲音质明细。
 *
 * 接口返回的字段（实测）：
 *   l 128k / m 192k / h 320k / sq 无损 / hr 高解析 / je 沉浸声母带 / jm 沉浸声环绕 / sk 空间音频
 *
 * 两个坑：
 *   1. 原来只认 6 个键且**丢掉了 h 之外的中档映射**（`fallbacks` 里把 'm' 写成 192k 却排在
 *      128k 后面当兜底），阵型是 `['l','h','sq','hr','jm','je']`，映射到
 *      128k/320k/flac/hires/master/atmos —— 少了两档，而且 je/jm 会**重复映射成两个 master**。
 *   2. 必须补 `Referer: https://music.163.com/`：这个接口对空 Referer 不一定稳，
 *      拿不到就整段空 → 上层退回「脚本声明档位」，用户看到的就是「只有两个低音质」。
 *
 * 现在按「一个档位只留一条、体积大的优先（jm→je）」去重。
 */
async function wyQualitys(songId: string): Promise<LXQualityOption[]> {
  const url: string = `https://music.163.com/api/song/music/detail/get?songId=${songId}`;
  const headers: Record<string, string> = {
    'Referer': 'https://music.163.com/',
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
  };
  const text: string = await httpGetText(url, headers);
  const list: LXQualityOption[] = [];
  if (text === '') {
    return list;
  }
  try {
    const root = JSON.parse(text) as Record<string, Object>;
    const data = root['data'] as Record<string, Object>;
    if (data === undefined || data === null) {
      return list;
    }
    const keys: string[] = ['l', 'm', 'h', 'sq', 'hr', 'je', 'jm', 'sk'];
    const names: string[] = ['128k', '192k', '320k', 'flac', 'hires', 'master', 'master', '沉浸声'];
    // 按体积去重：同一档位只保留最大的那条（je 比 jm 大，就留 je）
    const best: Map<string, number> = new Map<string, number>();
    for (let i: number = 0; i < keys.length; i++) {
      const q = data[keys[i]] as Record<string, Object>;
      if (q === undefined || q === null) {
        continue;
      }
      const size: number = numOf(q, 'size');
      if (size <= 0) {
        continue;
      }
      const exist: number | undefined = best.get(names[i]);
      if (exist === undefined || size > exist) {
        best.set(names[i], size);
      }
    }
    best.forEach((size: number, name: string): void => {
      list.push(LXQualityOption.of(name, size));
    });
    hilog.info(LOG_DOMAIN, LOG_TAG, 'wy quality keys hit=%{public}d options=%{public}d',
      best.size, list.length);
  } catch (_e) {
    // parse failure: empty list
  }
  return list;
}

// ===================== TX（musicu.fcg CgiGetTrackInfo，实时查询） =====================

function txAppendSizeNew(list: LXQualityOption[], sizeNew: Object[] | undefined): void {
  if (sizeNew === undefined) {
    return;
  }
  const names: string[] = ['master', 'atmos', 'atmos_plus'];
  for (let i: number = 0; i < sizeNew.length && i < 3; i++) {
    const size = sizeNew[i] as number;
    if (size !== undefined && size > 0) {
      list.push(LXQualityOption.of(names[i], size));
    }
  }
}

async function txQualitys(song: LXSearchSong): Promise<LXQualityOption[]> {
  const numId: string = await lxResolveTxNumId(song.songId, song.name, song.singer);
  if (numId === '' || Number(numId) === 0) {
    return typesToOptions(song.types);
  }
  const comm: Record<string, Object> = {
    'ct': '19',
    'cv': '1859',
    'uin': '0'
  };
  const param: Record<string, Object> = {
    'types': [1],
    'ids': [Number(numId)],
    'ctx': 0
  };
  const req: Record<string, Object> = {
    'module': 'music.trackInfo.UniformRuleCtrl',
    'method': 'CgiGetTrackInfo',
    'param': param
  };
  const data: Record<string, Object> = {
    'comm': comm,
    'req': req
  };
  const headers: Record<string, string> = {
    'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)',
    'Content-Type': 'application/json'
  };
  const text: string = await httpPostText('https://u.y.qq.com/cgi-bin/musicu.fcg',
    JSON.stringify(data), headers);
  const list: LXQualityOption[] = [];
  if (text === '') {
    return typesToOptions(song.types);
  }
  try {
    const root = JSON.parse(text) as Record<string, Object>;
    if (numOf(root, 'code') !== 0) {
      return typesToOptions(song.types);
    }
    const req2 = root['req'] as Record<string, Object>;
    if (req2 === undefined || numOf(req2, 'code') !== 0) {
      return typesToOptions(song.types);
    }
    const data2 = req2['data'] as Record<string, Object>;
    if (data2 === undefined) {
      return typesToOptions(song.types);
    }
    const tracks = data2['tracks'] as Object[];
    if (tracks === undefined || tracks.length === 0) {
      return typesToOptions(song.types);
    }
    const track = tracks[0] as Record<string, Object>;
    if (track === null) {
      return typesToOptions(song.types);
    }
    const file = track['file'] as Record<string, Object>;
    if (file === undefined || file === null) {
      return typesToOptions(song.types);
    }
    if (numOf(file, 'size_128mp3') > 0) {
      list.push(LXQualityOption.of('128k', numOf(file, 'size_128mp3')));
    }
    if (numOf(file, 'size_320mp3') > 0) {
      list.push(LXQualityOption.of('320k', numOf(file, 'size_320mp3')));
    }
    if (numOf(file, 'size_flac') > 0) {
      list.push(LXQualityOption.of('flac', numOf(file, 'size_flac')));
    }
    if (numOf(file, 'size_hires') > 0) {
      list.push(LXQualityOption.of('hires', numOf(file, 'size_hires')));
    }
    txAppendSizeNew(list, file['size_new'] as Object[]);
    if (list.length === 0) {
      return typesToOptions(song.types);
    }
  } catch (_e) {
    return typesToOptions(song.types);
  }
  return list;
}

// ===================== 音源脚本声明的音质（最终兜底） =====================

/**
 * 当前音源脚本在 `init` 里声明的每个平台支持的音质档位。
 *
 * 数据来源：`LXSourceEngine` 就绪时会把脚本上报的 `sources` 写进
 * `AppStorage['lxEngineSources']`（形如 `{ kw: { qualitys: ['128k','320k','flac'], ... } }`）。
 *
 * 为什么需要它：wy/tx/kg/mg 的「实时查音质」接口会挂（风控/改版/网络），kw 更是只有搜索
 * 结果里才带音质字段。**只有脚本自己声明的档位是权威的** —— 而它恰好也是真正下载时
 * `getQualityChain()` 用来筛档位的依据（见 SourceFallbackUtil）。查不到明细时用这份
 * 声明档位兜底，至少让用户能选并成功下载，而不是被一句「暂无可用音质」挡在门外。
 *
 * @param source 平台 id（kw/wy/tx/kg/mg）。
 * @returns 音质档位列表；拿不到返回空数组。
 */
export function declaredSourceQualitys(source: string): string[] {
  try {
    const raw: string = AppStorage.get<string>('lxEngineSources') ?? '';
    if (raw.length === 0 || raw === '{}') {
      return [];
    }
    const map: Record<string, LXUserApiSourceInfo> = JSON.parse(raw) as Record<string, LXUserApiSourceInfo>;
    const info: LXUserApiSourceInfo | undefined = map[source];
    if (info === undefined || info.qualitys === undefined) {
      return [];
    }
    const list: string[] = [];
    for (let i: number = 0; i < info.qualitys.length; i++) {
      list.push(info.qualitys[i]);
    }
    return list;
  } catch (_err) {
    return [];
  }
}

/** 声明档位 -> 音质选项（没有大小信息，展示时只是不显示体积）。 */
function declaredOptions(source: string): LXQualityOption[] {
  const list: string[] = declaredSourceQualitys(source);
  const options: LXQualityOption[] = [];
  for (let i: number = 0; i < list.length; i++) {
    options.push(LXQualityOption.of(list[i], 0));
  }
  return options;
}

// ===================== KW（搜索补齐 N_MINFO，实时查询） =====================

/** 比对用的歌名/歌手归一化：去空白、去大小写、去常见括号补充说明。 */
function normalizeKey(text: string): string {
  return text.toLowerCase().replace(/\s+/g, '').replace(/[（(【\[].*?[）)】\]]/g, '');
}

/**
 * 歌单里存的 kw 歌曲**没有** `N_MINFO`（那是搜索结果里才有的字段），
 * 而 `lxGetQualityOptions` 对 kw 只有 `typesToOptions(song.types)` 这一条路
 * —— 于是「歌单内多选 → 下载」经常直接弹「该歌曲暂无可用音质」，而先播放一次
 * （播放走的是音源脚本自己的取链逻辑，能拿到音质列表）再下载就正常。
 *
 * 修法：拿歌名 + 歌手去 kw 搜索接口重查一遍，把 `N_MINFO` 补回来。搜索走的是
 * 已经存在的 `lxSearch('kw', ...)`（`kwSearch` 里会把 N_MINFO 解析成 types），
 * 所以这里只做「挑对那一首」。
 *
 * 匹配顺序：songId 精确命中 → 歌名与歌手都归一化相等 → 歌名互相包含。
 * 找不到就返回空数组（调用方继续走 types 兜底，不引入错误结果）。
 */
async function kwQualitysBySearch(song: LXSearchSong): Promise<LXQualityOption[]> {
  const name: string = song.name ?? '';
  if (name.length === 0) {
    return [];
  }
  const query: string = (song.singer.length > 0 ? song.singer + ' ' : '') + name;
  const result = await lxSearch('kw', query, 1, 10);
  const candidates = result.list;
  if (candidates.length === 0) {
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'kw re-search empty: songId=%{public}s query=%{public}s',
      song.songId, query);
    return [];
  }
  let pick: LXSearchSong | undefined = undefined;
  for (let i: number = 0; i < candidates.length; i++) {
    if (candidates[i].songId === song.songId) {
      pick = candidates[i];
      break;
    }
  }
  const wantName: string = normalizeKey(name);
  const wantSinger: string = normalizeKey(song.singer ?? '');
  if (pick === undefined) {
    for (let i: number = 0; i < candidates.length; i++) {
      const c: LXSearchSong = candidates[i];
      if (normalizeKey(c.name ?? '') === wantName &&
        (wantSinger.length === 0 || normalizeKey(c.singer ?? '') === wantSinger)) {
        pick = c;
        break;
      }
    }
  }
  if (pick === undefined && wantName.length > 0) {
    for (let i: number = 0; i < candidates.length; i++) {
      const c: LXSearchSong = candidates[i];
      const cName: string = normalizeKey(c.name ?? '');
      if (cName.length === 0) {
        continue;
      }
      if (cName.indexOf(wantName) >= 0 || wantName.indexOf(cName) >= 0) {
        pick = c;
        break;
      }
    }
  }
  if (pick === undefined) {
    hilog.warn(LOG_DOMAIN, LOG_TAG,
      'kw no match: songId=%{public}s name=%{public}s candidates=%{public}d',
      song.songId, name, candidates.length);
    return [];
  }
  hilog.info(LOG_DOMAIN, LOG_TAG,
    'kw matched via re-search: %{public}s -> %{public}s types=%{public}d',
    song.songId, pick.songId, pick.types.length);
  return typesToOptions(pick.types);
}

// ===================== KG（goodsmstore get_res_privilege 批量网关，实时查询） =====================

const KG_QUALITY_NAMES: string[] = ['128k', '320k', 'flac', 'hires', 'master', 'atmos'];
const KG_QUALITY_KEYS: string[] = ['128', '320', 'flac', 'high', 'viper_clear', 'viper_atmos'];

async function kgQualitys(hash: string): Promise<LXQualityOption[]> {
  const resource: Record<string, Object>[] = [];
  const item: Record<string, Object> = {
    'id': 0,
    'type': 'audio',
    'hash': hash
  };
  resource.push(item);
  const body: Record<string, Object> = {
    'behavior': 'play',
    'clientver': '20049',
    'resource': resource,
    'area_code': '1',
    'quality': '128',
    'qualities': ['128', '320', 'flac', 'high', 'dolby', 'viper_atmos', 'viper_tape', 'viper_clear']
  };
  const url: string = `https://gateway.kugou.com/goodsmstore/v1/get_res_privilege?appid=1005&clientver=20049&clienttime=${Date.now()}&mid=NeZha`;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json'
  };
  const text: string = await httpPostText(url, JSON.stringify(body), headers);
  const list: LXQualityOption[] = [];
  if (text === '') {
    return list;
  }
  try {
    const root = JSON.parse(text) as Record<string, Object>;
    if (numOf(root, 'error_code') !== 0) {
      return list;
    }
    const dataArr = root['data'] as Object[];
    if (dataArr === undefined || dataArr.length === 0) {
      return list;
    }
    const songData = dataArr[0] as Record<string, Object>;
    if (songData === null) {
      return list;
    }
    const goods = songData['relate_goods'] as Object[];
    if (goods === undefined) {
      return list;
    }
    const seen: string[] = [];
    for (let j: number = 0; j < goods.length; j++) {
      const g = goods[j] as Record<string, Object>;
      if (g === null) {
        continue;
      }
      const quality = g['quality'] as string;
      const gHash = g['hash'] as string;
      if (gHash === undefined || gHash === '') {
        continue;
      }
      let name = '';
      for (let k: number = 0; k < KG_QUALITY_KEYS.length; k++) {
        if (KG_QUALITY_KEYS[k] === quality) {
          name = KG_QUALITY_NAMES[k];
          break;
        }
      }
      if (name === '' || seen.indexOf(name) >= 0) {
        continue;
      }
      seen.push(name);
      const info = g['info'] as Record<string, Object>;
      let size = 0;
      if (info !== undefined && info !== null) {
        size = numOf(info, 'filesize');
      }
      list.push(LXQualityOption.of(name, size));
    }
  } catch (_e) {
    // parse failure: empty list
  }
  return list;
}

// ===================== MG（resourceinfo.do 批量详情，实时补音质大小） =====================

const MG_QUALITY_NAMES: Record<string, string> = {
  'LQ': '128k',
  'PQ': '128k',
  'HQ': '320k',
  'SQ': 'flac',
  'ZQ': 'flac24bit',
  'ZQ24': 'flac24bit'
};

async function mgQualitys(songId: string): Promise<LXQualityOption[]> {
  const url: string = 'https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/resourceinfo.do?resourceType=2';
  const headers: Record<string, string> = {
    'User-Agent': 'Mozilla/5.0 (Linux; U; Android 11.0.0; zh-cn; MI 11) AppleWebKit/537.36',
    'Referer': 'https://music.migu.cn/',
    'Content-Type': 'application/x-www-form-urlencoded'
  };
  const text: string = await httpPostText(url, 'resourceId=' + songId, headers);
  const list: LXQualityOption[] = [];
  if (text === '') {
    return list;
  }
  try {
    const root = JSON.parse(text) as Record<string, Object>;
    const resources = root['resource'] as Object[];
    if (resources === undefined || resources.length === 0) {
      return list;
    }
    const item = resources[0] as Record<string, Object>;
    if (item === null) {
      return list;
    }
    const formats = item['newRateFormats'] as Object[];
    if (formats === undefined) {
      return list;
    }
    const seen: string[] = [];
    for (let i: number = 0; i < formats.length; i++) {
      const f = formats[i] as Record<string, Object>;
      if (f === null) {
        continue;
      }
      const formatType = f['formatType'] as string;
      const name: string = formatType !== undefined ?
        (MG_QUALITY_NAMES[formatType] ?? '') : '';
      if (name === '' || seen.indexOf(name) >= 0) {
        continue;
      }
      seen.push(name);
      let size = numOf(f, 'size');
      if (size === 0) {
        size = numOf(f, 'androidSize');
      }
      if (size === 0) {
        size = numOf(f, 'asize');
      }
      if (size === 0) {
        size = numOf(f, 'isize');
      }
      list.push(LXQualityOption.of(name, size));
    }
  } catch (_e) {
    // parse failure: empty list
  }
  return list;
}

/**
 * 查询一首歌的可用音质 + 文件大小。
 *
 * 解析顺序（逐级降级，任何一级拿到结果就返回）：
 *   1. 各源的**实时音质接口**（wy/tx/kg/mg）；
 *   2. kw：按 `songId` 查不到就**按歌名 + 歌手重查搜索**补 `N_MINFO`；
 *      wy/kg/mg 同样会退回「搜索结果预解析的 types」；
 *   3. **音源脚本声明的档位** —— 歌单里的歌 `types` 为空、实时接口又被风控挡住时，
 *      这是唯一还能给用户可选档位的来源（也是真正下载时用的那份声明）；
 *   4. 都没有 → 空数组（调用方据此提示）。
 *
 * 为什么第 3 级必须存在：歌单落库时不保存 `types`（`N_MINFO` 只在搜索结果里），
 * 而实时接口并不总是可靠；只靠 1/2 级就会出现「多选下载 → 暂无可用音质」，
 * 但同一首歌先播放再下载又正常（播放走的是脚本自己的取链逻辑）。
 */
export async function lxGetQualityOptions(song: LXSearchSong): Promise<LXQualityOption[]> {
  let list: LXQualityOption[] = [];
  let via: string = 'types';
  switch (song.source) {
    case 'wy': {
      const wy: LXQualityOption[] = await wyQualitys(song.songId);
      list = wy.length > 0 ? wy : typesToOptions(song.types);
      via = wy.length > 0 ? 'wy-api' : 'types';
      break;
    }
    case 'tx': {
      list = await txQualitys(song);
      via = 'tx-api';
      break;
    }
    case 'kg': {
      const kg: LXQualityOption[] = await kgQualitys(song.songId);
      list = kg.length > 0 ? kg : typesToOptions(song.types);
      via = kg.length > 0 ? 'kg-api' : 'types';
      break;
    }
    case 'mg': {
      const mg: LXQualityOption[] = await mgQualitys(song.songId);
      list = mg.length > 0 ? mg : typesToOptions(song.types);
      via = mg.length > 0 ? 'mg-api' : 'types';
      break;
    }
    case 'kw': {
      // 歌单里的 kw 歌曲 types 通常是空的（N_MINFO 只在搜索结果里），
      // 所以这里必须走「重查搜索」这条路，否则必然报「暂无可用音质」
      const kw: LXQualityOption[] = await kwQualitysBySearch(song);
      list = kw.length > 0 ? kw : typesToOptions(song.types);
      via = kw.length > 0 ? 'kw-search' : 'types';
      break;
    }
    default:
      list = typesToOptions(song.types);
      break;
  }
  if (list.length === 0) {
    // 最后兜底：脚本声明的档位
    list = declaredOptions(song.source);
    if (list.length > 0) {
      via = 'declared';
    }
  }
  hilog.info(LOG_DOMAIN, LOG_TAG,
    'quality resolved: source=%{public}s songId=%{public}s via=%{public}s options=%{public}d',
    song.source, song.songId, via, list.length);
  return list;
}

/** 批量查询上限：避免勾了 50 首就串行打 50 次网络请求。 */
const BATCH_QUERY_LIMIT: number = 5;

/** 批量音质查询结果。 */
export interface LXBatchQualityResult {
  /** 并集档位（按 size 升序）。 */
  options: LXQualityOption[];
  /** 查不到音质的歌曲下标（相对传入数组）。 */
  missing: number[];
}

/**
 * 批量下载用：多首歌曲**取并集**（按 size 升序）。
 *
 * 以前只查第一首，那首查不到就直接判「暂无可用音质」并关掉弹层 —— 用户其实是
 * 多选了 5 首，其余几首完全能查出来。现在逐首查、合并档位、并记录哪几首查不到。
 *
 * @param songs 已选歌曲（按列表顺序）。
 * @returns options = 并集档位；missing = 查不到音质的歌曲下标。
 */
export async function lxGetQualityOptionsForSongs(songs: LXSearchSong[]): Promise<LXBatchQualityResult> {
  const merged: Map<string, LXQualityOption> = new Map<string, LXQualityOption>();
  const missing: number[] = [];
  const limit: number = Math.min(songs.length, BATCH_QUERY_LIMIT);
  for (let i: number = 0; i < limit; i++) {
    let one: LXQualityOption[] = [];
    try {
      one = await lxGetQualityOptions(songs[i]);
    } catch (err) {
      const e: Error = err as Error;
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'batch quality query threw at %{public}d: %{public}s',
        i, e.message ?? '');
      one = [];
    }
    if (one.length === 0) {
      missing.push(i);
      continue;
    }
    for (let j: number = 0; j < one.length; j++) {
      const opt: LXQualityOption = one[j];
      const exist: LXQualityOption | undefined = merged.get(opt.type);
      // 同一档位保留「有大小信息」的那条
      if (exist === undefined || (exist.size === 0 && opt.size > 0)) {
        merged.set(opt.type, opt);
      }
    }
  }
  const options: LXQualityOption[] = [];
  merged.forEach((value: LXQualityOption): void => {
    options.push(value);
  });
  options.sort((a: LXQualityOption, b: LXQualityOption): number => a.size - b.size);
  hilog.info(LOG_DOMAIN, LOG_TAG,
    'batch quality: queried=%{public}d missing=%{public}d options=%{public}d',
    limit, missing.length, options.length);
  return { options: options, missing: missing };
}
