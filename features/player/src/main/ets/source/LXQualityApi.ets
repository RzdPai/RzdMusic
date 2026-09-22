import { http } from '@kit.NetworkKit';
import { LXSearchSong, LXQualityType, lxResolveTxNumId } from './LXMusicSDK';

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
    return '';
  } catch (_e) {
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

async function wyQualitys(songId: string): Promise<LXQualityOption[]> {
  const url: string = `https://music.163.com/api/song/music/detail/get?songId=${songId}`;
  const text: string = await httpGetText(url);
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
    const keys: string[] = ['l', 'h', 'sq', 'hr', 'jm', 'je'];
    const fallbacks: string[] = ['m', '', '', '', '', 'db'];
    const names: string[] = ['128k', '320k', 'flac', 'hires', 'master', 'atmos'];
    for (let i: number = 0; i < keys.length; i++) {
      let q = data[keys[i]] as Record<string, Object>;
      if (q === undefined || q === null) {
        if (fallbacks[i] === '') {
          continue;
        }
        q = data[fallbacks[i]] as Record<string, Object>;
      }
      if (q === undefined || q === null) {
        continue;
      }
      if (numOf(q, 'size') <= 0) {
        continue;
      }
      list.push(LXQualityOption.of(names[i], numOf(q, 'size')));
    }
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
 * 查询一首歌的可用音质 + 文件大小（mg3 getQualitys 同源实现）：
 * - wy/tx/kg/mg：实时请求各源音质接口
 * - kw：使用搜索结果预解析的 N_MINFO（含真实大小）
 */
export async function lxGetQualityOptions(song: LXSearchSong): Promise<LXQualityOption[]> {
  switch (song.source) {
    case 'wy': {
      const list: LXQualityOption[] = await wyQualitys(song.songId);
      return list.length > 0 ? list : typesToOptions(song.types);
    }
    case 'tx':
      return await txQualitys(song);
    case 'kg': {
      const list: LXQualityOption[] = await kgQualitys(song.songId);
      return list.length > 0 ? list : typesToOptions(song.types);
    }
    case 'mg': {
      const list: LXQualityOption[] = await mgQualitys(song.songId);
      return list.length > 0 ? list : typesToOptions(song.types);
    }
    case 'kw':
      return typesToOptions(song.types);
  }
  return typesToOptions(song.types);
}
