import axios, { AxiosResponse } from '@ohos/axios';
import CryptoJS from '@ohos/crypto-js';
import { zlib } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { amllDecryptQrcHex } from '../amll/parse/AmllQrcCodec';

export interface LXSearchSong {
  songId: string;
  name: string;
  singer: string;
  albumName: string;
  albumId: string;
  source: string;
  interval: string;
  img: string;
  types: LXQualityType[];
}

export interface LXQualityType {
  type: string;
  size: string;
}

export interface LXSearchResult {
  list: LXSearchSong[];
  total: number;
  limit: number;
  source: string;
}

export interface LXLeaderboardEntry {
  id: string;
  name: string;
}
interface MgSongItem {
  copyrightId: string;
  songId: string;
  name: string;
  singerList: SingerItem[];
  album: MgAlbumInfo;
  duration: string;
  img3: string;
  img2: string;
  img1: string;
  audioFormats: MgAudioFormat[];
}

interface SingerItem {
  singerName: string;
}

interface MgAlbumInfo {
  albumName: string;
  albumId: string;
}

interface MgAudioFormat {
  formatType: string;
}
interface HttpGetOptions {
  headers: Record<string, string>;
  timeout: number;
}

function encodeParam(s: string): string {
  return encodeURIComponent(s);
}

function formatTime(ms: number): string {
  let s: number = Math.floor(ms / 1000);
  let m: number = Math.floor(s / 60);
  s = s % 60;
  let sStr: string = s < 10 ? '0' + s : s.toString();
  return m.toString() + ':' + sStr;
}

function decodeName(s: string): string {
  return s.replace(/&apos;/g, "'").replace(/&quot;/g, '"').replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>');
}

/** Formats a kg singer field: array of {name} rows, a JSON string of such rows, or a plain string. */
function formatKgSingers(singers: Object): string {
  if (Array.isArray(singers)) {
    const names: string[] = [];
    for (let i: number = 0; i < singers.length; i++) {
      const row: Record<string, Object> = singers[i] as Record<string, Object>;
      const name: string = row.name as string || '';
      if (name.length > 0) {
        names.push(name);
      }
    }
    if (names.length > 0) {
      return decodeName(names.join('、'));
    }
    return '';
  }
  if (typeof singers === 'string' && singers.length > 0 && singers.charAt(0) === '[') {
    try {
      const parsed: Object[] = JSON.parse(singers) as Object[];
      if (Array.isArray(parsed)) {
        const names: string[] = [];
        for (let i: number = 0; i < parsed.length; i++) {
          const row: Record<string, Object> = parsed[i] as Record<string, Object>;
          const name: string = row.name as string || '';
          if (name.length > 0) {
            names.push(name);
          }
        }
        if (names.length > 0) {
          return decodeName(names.join('、'));
        }
      }
    } catch (_err) {
      // fall through to plain string
    }
  }
  return decodeName(String(singers ?? ''));
}

/**
 * Resolves the QQ numeric song id for a mid (songmid). Uses the mid->numId cache
 * filled by txSearch; on a miss (history/leaderboard play) it searches by name once.
 */
export async function lxResolveTxNumId(songId: string, name?: string, singer?: string): Promise<string> {
  let numId: string = qqNumIdCache.get(songId) ?? '';
  if (numId.length === 0) {
    try {
      const txName: string = name !== undefined && name.length > 0 ? name : songId;
      const txSinger: string = singer !== undefined ? singer : '';
      const searchQuery: string = (txSinger.length > 0 ? txSinger + ' ' : '') + txName;
      await txSearch(searchQuery, 1, 8);
      numId = qqNumIdCache.get(songId) ?? '';
    } catch (_err) {
      // ignore
    }
  }
  return numId;
}

export async function lxSearch(source: string, query: string, page: number,
  limit: number): Promise<LXSearchResult> {
  try {
    switch (source) {
      case 'kw': return await kwSearch(query, page, limit);
      case 'kg': return await kgSearch(query, page, limit);
      case 'tx': return await txSearch(query, page, limit);
      case 'wy': return await wySearch(query, page, limit);
      case 'mg': return await mgSearch(query, page, limit);
    }
  } catch (_err) {
    // fall through
  }
  return { list: [], total: 0, limit: limit, source: source };
}

export function getLeaderboardEntries(): LXLeaderboardEntry[] {
  return [
    { id: 'kw_93', name: '酷我飙升榜' }, { id: 'kw_16', name: '酷我热歌榜' },
    { id: 'kw_17', name: '酷我新歌榜' }, { id: 'kg_8888', name: '酷狗TOP500' },
    { id: 'kg_6666', name: '酷狗飙升榜' }, { id: 'tx_26', name: 'QQ音乐热歌榜' },
    { id: 'tx_27', name: 'QQ音乐新歌榜' }, { id: 'tx_4', name: 'QQ音乐流行指数榜' },
    { id: 'wy_0', name: '网易云热歌榜' }, { id: 'wy_1', name: '网易云新歌榜' },
    { id: 'mg_1', name: '咪咕新歌榜' }, { id: 'mg_2', name: '咪咕热歌榜' }
  ];
}

export async function lxLeaderboard(boardId: string, page: number,
  limit: number): Promise<LXSearchResult> {
  let parts: string[] = boardId.split('_');
  let src: string = parts[0];
  let id: string = parts[1];
  try {
    switch (src) {
      case 'kw': return await kwLeaderboard(id, page, limit);
      case 'kg': return await kgLeaderboard(id, page, limit);
      case 'mg': return await mgLeaderboard(id, page, limit);
      case 'tx': return await lxTxToplist(id, limit);
      case 'wy': return await wyLeaderboard(id, limit);
    }
  } catch (_err) {
    // fall through
  }
  return { list: [], total: 0, limit: limit, source: src };
}

/**
 * 网易云榜单歌曲。
 *
 * 之前 `lxLeaderboard` 里**没有 wy 分支**（直接落到空结果），所以网易榜单
 * 一首歌都取不到。这里补上：网易的榜单就是一个特殊歌单，直接读歌单详情。
 *
 * @param id 榜单 id（网易榜单就是 playlist id）。
 * @param limit 期望条数。
 * @returns 与其它平台一致的搜索结果。
 */
async function wyLeaderboard(id: string, limit: number): Promise<LXSearchResult> {
  const url: string = 'https://music.163.com/api/v6/playlist/detail?id=' + id +
    '&n=' + limit + '&s=0';
  const text: string = await httpGet(url, { 'Referer': 'https://music.163.com/' });
  if (text.length === 0) {
    return { list: [], total: 0, limit: limit, source: 'wy' };
  }
  let resp: Record<string, Object> = {};
  try {
    resp = JSON.parse(text) as Record<string, Object>;
  } catch (_err) {
    return { list: [], total: 0, limit: limit, source: 'wy' };
  }
  const playlist: Record<string, Object> = (resp.playlist as Record<string, Object>) || {};
  const tracks: Object[] = (playlist.tracks as Object[]) || [];
  const list: LXSearchSong[] = [];
  const seen: Record<string, boolean> = {};
  for (let i: number = 0; i < tracks.length && list.length < limit; i++) {
    const item: Record<string, Object> = tracks[i] as Record<string, Object>;
    const songId: string = String(item.id || '');
    if (songId.length === 0 || seen[songId]) {
      continue;
    }
    seen[songId] = true;
    const artists: Object[] = (item.ar as Object[]) || [];
    const names: string[] = [];
    for (let a: number = 0; a < artists.length; a++) {
      names.push(((artists[a] as Record<string, Object>).name as string) || '');
    }
    const album: Record<string, Object> = (item.al as Record<string, Object>) || {};
    const durationMs: number = parseInt(String(item.dt || '0'));
    const durationSec: number = Math.floor(durationMs / 1000);
    list.push({
      songId: songId,
      name: (item.name as string) || '',
      singer: names.join('、'),
      albumName: (album.name as string) || '',
      albumId: String(album.id || ''),
      source: 'wy',
      interval: durationSec > 0 ?
        String(Math.floor(durationSec / 60)).padStart(2, '0') + ':' +
        String(durationSec % 60).padStart(2, '0') : '',
      img: (album.picUrl as string) || '',
      types: [{ type: '128k', size: '-1' }]
    });
  }
  const total: number = parseInt(String(playlist.trackCount || list.length));
  return { list: list, total: total > 0 ? total : list.length, limit: limit, source: 'wy' };
}

const REQ_TIMEOUT: number = 10000;

/** QQ mid -> 数字 songid 缓存（musicu.fcg GetPlayLyricInfo 需要数字 id） */
const qqNumIdCache: Map<string, string> = new Map<string, string>();

async function httpGet(url: string, headers: Record<string, string> = {}): Promise<string> {
  try {
    let opts: HttpGetOptions = { headers: headers, timeout: REQ_TIMEOUT };
    let response: AxiosResponse = await axios.get<AxiosResponse>(url, opts);
    if (typeof response.data === 'string') {
      return response.data;
    }
    return JSON.stringify(response.data);
  } catch (_err) {
    return '';
  }
}

async function httpPost(url: string, body: string,
  headers: Record<string, string> = {}): Promise<string> {
  try {
    let opts: HttpGetOptions = { headers: headers, timeout: REQ_TIMEOUT };
    let response: AxiosResponse = await axios.post<string, AxiosResponse>(url, body, opts);
    if (typeof response.data === 'string') {
      return response.data;
    }
    return JSON.stringify(response.data);
  } catch (_err) {
    return '';
  }
}

/** 以二进制方式获取响应（用于 newlyric.kuwo.cn 等需要原始字节的接口） */
async function httpGetBuffer(url: string, headers: Record<string, string> = {}): Promise<Uint8Array | undefined> {
  const httpRequest = http.createHttp();
  try {
    const resp = await httpRequest.request(url, {
      method: http.RequestMethod.GET,
      header: headers,
      connectTimeout: REQ_TIMEOUT,
      readTimeout: REQ_TIMEOUT,
      expectDataType: http.HttpDataType.ARRAY_BUFFER
    });
    const data = resp.result;
    if (data instanceof ArrayBuffer) {
      return new Uint8Array(data);
    }
    return undefined;
  } catch (_err) {
    return undefined;
  } finally {
    httpRequest.destroy();
  }
}

// ===================== KW =====================

async function kwSearch(query: string, page: number, limit: number): Promise<LXSearchResult> {
  let encoded: string = encodeParam(query);
  let pn: number = page - 1;
  let url: string =
    'https://search.kuwo.cn/r.s?client=kt&all=' + encoded +
    '&pn=' + pn + '&rn=' + limit +
    '&uid=794762570&ver=kwplayer_ar_9.2.2.1&vipver=1&show_copyright_off=1&newver=1' +
    '&ft=music&cluster=0&strategy=2012&encoding=utf8&rformat=json&vermerge=1&mobi=1&issubtitle=1';
  let text: string = await httpGet(url);
  let result: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
  let total: number = parseInt(result.TOTAL as string || '0');
  let abslist: Object[] = result.abslist as Object[] || [];
  let list: LXSearchSong[] = [];
  for (let i: number = 0; i < abslist.length; i++) {
    let item: Record<string, Object> = abslist[i] as Record<string, Object>;
    if (item === undefined) {
      continue;
    }
    let songmid: string = (item.MUSICRID as string || '').replace('MUSIC_', '');
    let name: string = decodeName(item.SONGNAME as string || '');
    let artist: string = decodeName(item.ARTIST as string || '');
    let album: string = decodeName(item.ALBUM as string || '');
    let albumId: string = item.ALBUMID as string || '';
    let duration: number = parseInt(item.DURATION as string || '0');
    let nMinfo: string = item.N_MINFO as string || '';
    let types: LXQualityType[] = parseKwQuality(nMinfo);
    let song: LXSearchSong = {
      songId: songmid, name: name, singer: artist,
      albumName: album, albumId: albumId, source: 'kw',
      interval: formatTime(duration * 1000), img: '', types: types
    };
    list.push(song);
  }
  return { list: list, total: total, limit: limit, source: 'kw' };
}

function parseKwQuality(nMinfo: string): LXQualityType[] {
  let types: LXQualityType[] = [];
  if (nMinfo.length === 0) {
    return types;
  }
  let rxp: RegExp = /level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)/g;
  let matches: RegExpExecArray[] = [];
  let match: RegExpExecArray | null;
  while ((match = rxp.exec(nMinfo)) !== null) {
    matches.push(match);
  }
  for (let i: number = matches.length - 1; i >= 0; i--) {
    let m: RegExpExecArray = matches[i];
    let bitrate: number = parseInt(m[2]);
    let type: string = '';
    switch (bitrate) {
      case 128: type = '128k'; break;
      case 320: type = '320k'; break;
      case 2000: type = 'flac'; break;
      case 4000: type = 'flac24bit'; break;
    }
    if (type.length > 0) {
      types.push({ type: type, size: m[4] });
    }
  }
  return types;
}

// ===================== KG =====================

async function kgSearch(query: string, page: number, limit: number): Promise<LXSearchResult> {
  let encoded: string = encodeParam(query);
  let url: string =
    'https://songsearch.kugou.com/song_search_v2?keyword=' + encoded +
    '&page=' + page + '&pagesize=' + limit +
    '&userid=0&clientver=&platform=WebFilter&filter=2&iscorrection=1' +
    '&privilege_filter=0&area_code=1';
  let text: string = await httpGet(url);
  let result: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
  if (result.error_code as number !== 0) {
    return { list: [], total: 0, limit: limit, source: 'kg' };
  }
  let data: Record<string, Object> = result.data as Record<string, Object>;
  let lists: Object[] = data.lists as Object[] || [];
  let total: number = parseInt(data.total as string || '0');
  let songList: LXSearchSong[] = [];
  let seenIds: Record<string, boolean> = {};
  for (let i: number = 0; i < lists.length; i++) {
    let rawItem: Record<string, Object> = lists[i] as Record<string, Object>;
    let grp: Object[] = rawItem.Grp as Object[] || [];
    if (grp.length === 0 && rawItem.Audioid !== undefined) {
      grp = [rawItem];
    }
    for (let g: number = 0; g < grp.length; g++) {
      let item: Record<string, Object> = grp[g] as Record<string, Object>;
      let songmid: string = item.Audioid as string || '';
      if (songmid.length === 0) {
        if (seenIds[songmid]) {
          continue;
        }
        seenIds[songmid] = true;
      }
      let hash: string = item.FileHash as string || '';
      let name: string = item.SongName as string || '';
      let artist: string = formatKgSingers(item.Singers);
      if (songList.length === 0) {
        let singersRaw: string = '';
        try {
          singersRaw = JSON.stringify(item.Singers);
        } catch (_err) {
          singersRaw = String(item.Singers);
        }
        appendLxLog('[kgSearch] hash=' + hash + ' Singers=' + (singersRaw.length > 120 ? singersRaw.substring(0, 120) : singersRaw));
      }
      let album: string = item.AlbumName as string || '';
      let albumId: string = item.AlbumID as string || '';
      let duration: number = parseInt(item.Duration as string || '0');
      let hqSize: string = item.HQFileSize as string || '';
      let sqSize: string = item.SQFileSize as string || '';
      let resSize: string = item.ResFileSize as string || '';
      let fileSize: string = item.FileSize as string || '';
      let types: LXQualityType[] = [];
      if (fileSize !== '0' && fileSize.length > 0) {
        types.push({ type: '128k', size: '-1' });
      }
      if (hqSize !== '0' && hqSize.length > 0) {
        types.push({ type: '320k', size: '-1' });
      }
      if (sqSize !== '0' && sqSize.length > 0) {
        types.push({ type: 'flac', size: '-1' });
      }
      if (resSize !== '0' && resSize.length > 0) {
        types.push({ type: 'flac24bit', size: '-1' });
      }
      types.reverse();
      let song: LXSearchSong = {
        songId: hash, name: name, singer: artist,
        albumName: album, albumId: albumId, source: 'kg',
        interval: formatTime(duration * 1000), img: '', types: types
      };
      songList.push(song);
    }
  }
  return { list: songList, total: total, limit: limit, source: 'kg' };
}

interface TxSearchParam {
  search_type: number;
  searchid: string;
  query: string;
  page_num: number;
  num_per_page: number;
  highlight: number;
  nqc_flag: number;
  multi_zhida: number;
  cat: number;
  grp: number;
  sin: number;
  sem: number;
}

interface TxSearchReq {
  module: string;
  method: string;
  param: TxSearchParam;
}

interface TxSearchComm {
  ct: string;
  cv: string;
  v: string;
  tmeAppID: string;
  phonetype: string;
  deviceScore: string;
  devicelevel: string;
  newdevicelevel: string;
  rom: string;
  os_ver: string;
  OpenUDID: string;
  OpenUDID2: string;
  QIMEI36: string;
  udid: string;
  chid: string;
  aid: string;
  oaid: string;
  taid: string;
  tid: string;
  wid: string;
  uid: string;
  sid: string;
  modeSwitch: string;
  teenMode: string;
  ui_mode: string;
  nettype: string;
  v4ip: string;
}

interface TxRequestBody {
  comm: TxSearchComm;
  req: TxSearchReq;
}

function txSign(bodyStr: string): string {
  let sha1: string = CryptoJS.SHA1(bodyStr).toString();
  let picks1: number[] = [23, 14, 6, 36, 16, 40, 7, 19];
  let picks2: number[] = [16, 1, 32, 12, 19, 27, 8, 5];
  let part1: string = '';
  let part2: string = '';
  for (let i: number = 0; i < picks1.length; i++) {
    part1 += sha1.charAt(picks1[i]);
    part2 += sha1.charAt(picks2[i]);
  }
  let scramble: number[] = [
    89, 39, 179, 150, 218, 82, 58, 252, 177, 52, 186, 123, 120, 64, 242, 133, 143, 161, 121, 179
  ];
  let bytes: number[] = [];
  for (let i: number = 0; i < scramble.length; i++) {
    let hexPair: string = sha1.substring(i * 2, i * 2 + 2);
    let val: number = parseInt(hexPair, 16);
    bytes.push(scramble[i] ^ val);
  }
  let baseStr: string = '';
  for (let i: number = 0; i < bytes.length; i++) {
    baseStr += String.fromCharCode(bytes[i]);
  }
  let wordArr = CryptoJS.enc.Latin1.parse(baseStr);
  let b64: string = CryptoJS.enc.Base64.stringify(wordArr);
  b64 = b64.replace(/\\/g, '').replace(/\+/g, '').replace(/=/g, '').replace(/\//g, '');
  return ('zzc' + part1 + b64 + part2).toLowerCase();
}

async function txSearch(query: string, page: number, limit: number): Promise<LXSearchResult> {
  let searchId: string = Math.random().toString(36).substring(2);
  let paramObj: TxSearchParam = {
    search_type: 0, searchid: searchId, query: query,
    page_num: page, num_per_page: limit,
    highlight: 0, nqc_flag: 0, multi_zhida: 0, cat: 2, grp: 1, sin: 0, sem: 0
  };
  let reqObj: TxSearchReq = {
    module: 'music.search.SearchCgiService',
    method: 'DoSearchForQQMusicMobile',
    param: paramObj
  };
  let commObj: TxSearchComm = {
    ct: '11', cv: '14090508', v: '14090508', tmeAppID: 'qqmusic',
    phonetype: 'EBG-AN10', deviceScore: '553.47', devicelevel: '50', newdevicelevel: '20',
    rom: 'HuaWei/EMOTION/EmotionUI_14.2.0', os_ver: '12',
    OpenUDID: '0', OpenUDID2: '0', QIMEI36: '0', udid: '0',
    chid: '0', aid: '0', oaid: '0', taid: '0', tid: '0', wid: '0',
    uid: '0', sid: '0', modeSwitch: '6', teenMode: '0',
    ui_mode: '2', nettype: '1020', v4ip: ''
  };
  let bodyObj: TxRequestBody = { comm: commObj, req: reqObj };
  let bodyStr: string = JSON.stringify(bodyObj) || '';
  let sign: string = txSign(bodyStr);
  let url: string = 'https://u.y.qq.com/cgi-bin/musics.fcg?sign=' + sign;
  let headers: Record<string, string> = {
    'User-Agent': 'QQMusic 14090508(android 12)',
    'Content-Type': 'application/json'
  };
  let text: string = await httpPost(url, bodyStr, headers);
  let resp: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
  if (resp.code as number !== 0) {
    return { list: [], total: 0, limit: limit, source: 'tx' };
  }
  let reqResp: Record<string, Object> = resp.req as Record<string, Object>;
  if (reqResp === undefined || reqResp.code as number !== 0) {
    return { list: [], total: 0, limit: limit, source: 'tx' };
  }
  let reqData: Record<string, Object> = reqResp.data as Record<string, Object>;
  let body: Record<string, Object> = reqData.body as Record<string, Object>;
  let items: Object[] = body.song as Object[] || body.item_song as Object[] || [];
  let totalNum: number = parseInt(body.total_num as string || body.totalNum as string || '0');
  let list: LXSearchSong[] = [];
  for (let i: number = 0; i < items.length; i++) {
    let item: Record<string, Object> = items[i] as Record<string, Object>;
    let songmid: string = item.mid as string || '';
    if (songmid.length === 0) {
      continue;
    }
    let name: string = item.title as string || item.name as string || '';
    let singers: Object[] = item.singer as Object[] || [];
    let singerNames: string[] = [];
    for (let s: number = 0; s < singers.length; s++) {
      let singer: Record<string, Object> = singers[s] as Record<string, Object>;
      singerNames.push(singer.name as string || '');
    }
    let alb: Record<string, Object> = item.album as Record<string, Object> || {};
    let albumName: string = alb.title as string || alb.name as string || '';
    let albumId: string = alb.mid as string || '';
    let intervalVal: number = parseInt(item.interval as string || '0');
    let file: Record<string, Object> = item.file as Record<string, Object> || {};
    let types: LXQualityType[] = parseTxQuality(file);
    let img: string = '';
    if (albumId.length > 0) {
      img = 'https://y.gtimg.cn/music/photo_new/T002R500x500M000' + albumId + '.jpg';
    }
    let song: LXSearchSong = {
      songId: songmid, name: name, singer: singerNames.join('、'),
      albumName: albumName, albumId: albumId, source: 'tx',
      interval: formatTime(intervalVal * 1000), img: img, types: types
    };
    list.push(song);
    // 缓存 mid -> 数字 songid（musicu.fcg GetPlayLyricInfo 需要数字 id）
    const numId: string = String(item.id ?? '');
    if (songmid.length > 0 && numId.length > 0) {
      qqNumIdCache.set(songmid, numId);
    }
  }
  return { list: list, total: totalNum, limit: limit, source: 'tx' };
}

function parseTxQuality(file: Record<string, Object>): LXQualityType[] {
  let types: LXQualityType[] = [];
  let sizeHires: string = file.size_hires as string || '';
  if (sizeHires !== '0' && sizeHires.length > 0) {
    types.push({ type: 'flac24bit', size: '-1' });
  }
  let sizeFlac: string = file.size_flac as string || '';
  if (sizeFlac !== '0' && sizeFlac.length > 0) {
    types.push({ type: 'flac', size: '-1' });
  }
  let size320: string = file.size_320mp3 as string || '';
  if (size320 !== '0' && size320.length > 0) {
    types.push({ type: '320k', size: '-1' });
  }
  let size128: string = file.size_128mp3 as string || '';
  if (size128 !== '0' && size128.length > 0) {
    types.push({ type: '128k', size: '-1' });
  }
  return types;
}

// ===================== WY =====================

interface WySearchForm {
  keyword: string;
  needCorrect: string;
  channel: string;
  offset: number;
  scene: string;
  total: string;
  limit: number;
}

async function wySearch(query: string, page: number, limit: number): Promise<LXSearchResult> {
  let offset: number = (page - 1) * limit;
  let totalFlag: string = page === 1 ? 'true' : 'false';
  let formObj: WySearchForm = {
    keyword: query, needCorrect: '1', channel: 'typing',
    offset: offset, scene: 'normal', total: totalFlag, limit: limit
  };
  let msg: string = 'nobody' + '/api/search/song/list/page' + 'use' + JSON.stringify(formObj) +
    'md5forencrypt';
  let digest: string = CryptoJS.MD5(msg).toString();
  let data: string = '/api/search/song/list/page' + '-36cd479b6b5-' + JSON.stringify(formObj) +
    '-36cd479b6b5-' + digest;
  let keyUtf8 = CryptoJS.enc.Utf8.parse('e82ckenh8dichen8');
  let encrypted = CryptoJS.AES.encrypt(data, keyUtf8, {
    mode: CryptoJS.mode.ECB,
    padding: CryptoJS.pad.Pkcs7
  });
  let params: string = encrypted.ciphertext.toString().toUpperCase();
  let url: string = 'https://interface.music.163.com/eapi/batch';
  let headers: Record<string, string> = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
    'Content-Type': 'application/x-www-form-urlencoded'
  };
  let text: string = await httpPost(url, 'params=' + encodeParam(params), headers);
  let resp: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
  if (resp.code as number !== 200) {
    return { list: [], total: 0, limit: limit, source: 'wy' };
  }
  let respData: Record<string, Object> = resp.data as Record<string, Object>;
  let resources: Object[] = respData.resources as Object[] || [];
  let total: number = respData.total as number || 0;
  let list: LXSearchSong[] = [];
  for (let i: number = 0; i < resources.length; i++) {
    let res: Record<string, Object> = resources[i] as Record<string, Object>;
    let baseInfo: Record<string, Object> = res.baseInfo as Record<string, Object>;
    if (baseInfo === undefined) {
      continue;
    }
    let simple: Record<string, Object> = baseInfo.simpleSongData as Record<string, Object>;
    if (simple === undefined) {
      simple = baseInfo;
    }
    let privilege: Record<string, Object> = baseInfo.privilege as Record<string, Object> || {};
    let songmid: string = simple.id as string || '';
    if (songmid.length === 0) {
      continue;
    }
    let name: string = simple.name as string || '';
    let artists: Object[] = simple.ar as Object[] || [];
    let singerNames: string[] = [];
    for (let a: number = 0; a < artists.length; a++) {
      let ar: Record<string, Object> = artists[a] as Record<string, Object>;
      singerNames.push(ar.name as string || '');
    }
    let alb: Record<string, Object> = simple.al as Record<string, Object> || {};
    let albumName: string = alb.name as string || '';
    let albumId: string = alb.id as string || '';
    let img: string = alb.picUrl as string || '';
    let duration: number = parseInt(simple.dt as string || '0');
    let types: LXQualityType[] = [];
    let maxBr: number = privilege.maxbr as number || 0;
    if (privilege.maxBrLevel as string === 'hires') {
      types.push({ type: 'flac24bit', size: '-1' });
    }
    if (maxBr >= 999000) {
      types.push({ type: 'flac', size: '-1' });
    }
    if (maxBr >= 320000) {
      types.push({ type: '320k', size: '-1' });
    }
    if (maxBr === 192000 || maxBr === 128000) {
      types.push({ type: '128k', size: '-1' });
    }
    let song: LXSearchSong = {
      songId: songmid, name: name, singer: singerNames.join('、'),
      albumName: albumName, albumId: albumId, source: 'wy',
      interval: formatTime(duration), img: img, types: types
    };
    list.push(song);
  }
  return { list: list, total: total, limit: limit, source: 'wy' };
}

// ===================== MG =====================

function mgSign(str: string, time: number): Record<string, string> {
  let deviceId: string = '963B7AA0D21511ED807EE5846EC87D20';
  let signMd5: string = '6cdc72a439cef99a3418d2a78aa28c73';
  let raw: string = str + signMd5 + 'yyapp2d16148780a1dcc7408e06336b98cfd50' + deviceId +
    time.toString();
  let signStr: string = CryptoJS.MD5(raw).toString();
  let result: Record<string, string> = { 'sign': signStr, 'deviceId': deviceId };
  return result;
}

async function mgSearch(query: string, page: number, limit: number): Promise<LXSearchResult> {
  let time: number = Date.now();
  let signData: Record<string, string> = mgSign(query, time);
  let timestampStr: string = time.toString();
  let headers: Record<string, string> = {
    'uiVersion': 'A_music_3.6.1',
    'deviceId': signData.deviceId,
    'timestamp': timestampStr,
    'sign': signData.sign,
    'channel': '0146921',
    'User-Agent': 'Mozilla/5.0 (Linux; U; Android 11.0.0; zh-cn; MI 11) AppleWebKit/537.36'
  };
  let switchJson: string = '{"song":1,"album":0,"singer":0,"tagSong":1,"mvSong":0,"bestShow":1,"songlist":0,"lyricSong":0}';
  let url: string =
    'https://jadeite.migu.cn/music_search/v3/search/searchAll?isCorrect=0&isCopyright=1' +
    '&searchSwitch=' + encodeParam(switchJson) +
    '&pageSize=' + limit + '&text=' + encodeParam(query) +
    '&pageNo=' + page + '&sort=0&sid=USS';
  let text: string = await httpGet(url, headers);
  let result: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
  if (result.code as string !== '000000') {
    return { list: [], total: 0, limit: limit, source: 'mg' };
  }
  let songData: Record<string, Object> = result.songResultData as Record<string, Object> || {};
  let resultList: Object[][] = songData.resultList as Object[][] || [];
  let total: number = parseInt(songData.totalCount as string || '0');
  let list: LXSearchSong[] = [];
  let seenIds: Record<string, string> = {};
  for (let i: number = 0; i < resultList.length; i++) {
    let inner: Object[] = resultList[i];
    for (let j: number = 0; j < inner.length; j++) {
      let item: Record<string, Object> = inner[j] as Record<string, Object>;
      let copyrightId: string = item.copyrightId as string || '';
      if (copyrightId.length === 0 || seenIds[copyrightId] !== undefined) {
        continue;
      }
      seenIds[copyrightId] = copyrightId;
      let songId: string = item.songId as string || '';
      let name: string = item.name as string || '';
      let singers: Object[] = item.singerList as Object[] || [];
      let singerNames: string[] = [];
      for (let s: number = 0; s < singers.length; s++) {
        let singer: Record<string, Object> = singers[s] as Record<string, Object>;
        singerNames.push(singer.singerName as string || '');
      }
      let album: Record<string, Object> = item.album as Record<string, Object> || {};
      let albumName: string = album.albumName as string || '';
      let albumId: string = album.albumId as string || '';
      let duration: number = parseInt(item.duration as string || '0');
      let img1: string = item.img3 as string || item.img2 as string || item.img1 as string || '';
      let img: string = img1.length > 0 ? 'https://d.musicapp.migu.cn' + img1 : '';
      let audioFormats: Object[] = item.audioFormats as Object[] || [];
      let types: LXQualityType[] = parseMgQuality(audioFormats);
      let song: LXSearchSong = {
        songId: copyrightId, name: name, singer: singerNames.join('、'),
        albumName: albumName, albumId: albumId, source: 'mg',
        interval: formatTime(duration * 1000), img: img, types: types
      };
      list.push(song);
    }
  }
  return { list: list, total: total, limit: limit, source: 'mg' };
}

function parseMgQuality(formats: Object[]): LXQualityType[] {
  let types: LXQualityType[] = [];
  for (let i: number = 0; i < formats.length; i++) {
    let fmt: Record<string, Object> = formats[i] as Record<string, Object>;
    let formatType: string = fmt.formatType as string || '';
    switch (formatType) {
      case 'ZQ24': types.push({ type: 'flac24bit', size: '-1' }); break;
      case 'SQ': types.push({ type: 'flac', size: '-1' }); break;
      case 'HQ': types.push({ type: '320k', size: '-1' }); break;
      case 'PQ': types.push({ type: '128k', size: '-1' }); break;
    }
  }
  return types;
}

// ===================== Leaderboard =====================

// ===================== Built-in fallback (pic / lyric) =====================
// Cover and lyric are fully resolved by built-in interfaces; user API scripts are NOT used.

/** Appends a line to the shared lx play log (visible in the settings page). */
function appendLxLog(msg: string): void {
  let prev: string = AppStorage.get<string>('lxPlayLog') || '';
  let now: Date = new Date();
  let time: string = now.getHours().toString().padStart(2, '0') + ':' +
    now.getMinutes().toString().padStart(2, '0') + ':' +
    now.getSeconds().toString().padStart(2, '0');
  let log: string = prev + '[' + time + '] ' + msg + '\n';
  if (log.length > 20000) {
    log = log.substring(log.length - 5000);
  }
  AppStorage.setOrCreate('lxPlayLog', log);
}

/**
 * Built-in cover resolution for kw/kg (tx/wy/mg already carry covers in search results).
 * @param source Music source id.
 * @param songId Song id (kw: songmid, kg: hash).
 * @param albumId Album id (kg fallback only).
 * @param name Song name (kg fallback only).
 * @param singer Singer line (kg fallback only).
 * @returns Cover url, or empty when unavailable.
 */
export async function lxGetPicFallback(source: string, songId: string, albumId?: string, name?: string,
  singer?: string): Promise<string> {
  const cacheKey: string = 'lxPicCache_' + source + '_' + songId;
  const cached: string = AppStorage.get<string>(cacheKey) ?? '';
  if (cached.length > 0) {
    return cached;
  }
  let result: string = '';
  try {
    switch (source) {
      case 'kw': {
        // artistpicserver returns a plain image url.
        const url: string = 'https://artistpicserver.kuwo.cn/pic.web?corp=kuwo&type=rid_pic&pictype=500&size=500&rid=' +
          songId;
        const text: string = await httpGet(url);
        if (/^http/i.test(text)) {
          result = text.trim();
          break;
        }
        // Fallback: musicInfo -> data.img (full cover url)
        const infoUrl: string = 'https://www.kuwo.cn/api/www/music/musicInfo?mid=' + songId + '&httpsStatus=1';
        const infoText: string = await httpGet(infoUrl);
        if (infoText.length > 0) {
          try {
            const infoResp: Record<string, Object> = JSON.parse(infoText) as Record<string, Object>;
            if (infoResp.code as number === 200) {
              const infoData: Record<string, Object> = infoResp.data as Record<string, Object> || {};
              const infoImg: string = infoData.img as string || '';
              if (infoImg.length > 0) {
                result = infoImg;
              }
            }
          } catch (_err) {
            // fall through
          }
        }
        break;
      }
      case 'kg': {
        // m.kugou playInfo -> album_img (album cover, verified); imgUrl (singer art) as fallback.
        const headers: Record<string, string> = {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 12; EBG-AN10) AppleWebKit/537.36',
          'Referer': 'https://m.kugou.com/'
        };
        const infoUrl: string = 'https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=' + songId;
        const infoText: string = await httpGet(infoUrl, headers);
        if (infoText.length > 0) {
          try {
            const infoResp: Record<string, Object> = JSON.parse(infoText) as Record<string, Object>;
            let cover: string = infoResp.album_img as string || '';
            if (cover.length === 0) {
              cover = infoResp.imgUrl as string || '';
            }
            if (cover.length > 0) {
              if (cover.indexOf('{size}') >= 0) {
                cover = cover.replace('{size}', '480');
              }
              if (cover.startsWith('http://')) {
                cover = 'https://' + cover.substring(7);
              }
              result = cover;
            }
          } catch (_err) {
            // fall through
          }
        }
        break;
      }
      case 'tx': {
        // QQ 音乐封面。
        //
        // 为什么必须在这里补：QQ 榜单接口（fcg_v8_toplist_cp）把 `albummid` 放在
        // `songlist[].data` 里，而 `MusicDataService.formatTrack('tx')` 读的是外层字段
        // → 永远拿不到 → 未登录时首页 QQ 歌曲整排没封面（酷狗/网易各自有别的来源）。
        // 这里走歌词接口：它对 `songmid` 就返回 `albummid`，拿它拼 y.gtimg.cn 封面。
        const headers: Record<string, string> = {
          'Referer': 'https://y.qq.com/portal/player.html',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        };
        const lyricUrl: string = 'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg' +
          '?songmid=' + songId + '&format=json&nobase64=1&g_tk=5381&loginUin=0&hostUin=0' +
          '&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=0';
        const lyricText: string = await httpGet(lyricUrl, headers);
        if (lyricText.length > 0) {
          try {
            const lyricResp: Record<string, Object> = JSON.parse(lyricText) as Record<string, Object>;
            const albumMid: string = lyricResp.albummid as string || '';
            if (albumMid.length > 0) {
              result = 'https://y.gtimg.cn/music/photo_new/T002R300x300M000' + albumMid + '.jpg';
            }
          } catch (_err) {
            // fall through
          }
        }
        break;
      }
      case 'wy': {
        // 网易云封面：歌曲详情接口直接给 `al.picUrl`
        const wyUrl: string = 'https://music.163.com/api/song/detail/?ids=[' + songId + ']';
        const wyText: string = await httpGet(wyUrl, { 'Referer': 'https://music.163.com/' });
        if (wyText.length > 0) {
          try {
            const wyResp: Record<string, Object> = JSON.parse(wyText) as Record<string, Object>;
            const songs: Object[] = wyResp.songs as Object[] || [];
            if (songs.length > 0) {
              const first: Record<string, Object> = songs[0] as Record<string, Object>;
              const al: Record<string, Object> = first.al as Record<string, Object> || {};
              const pic: string = al.picUrl as string || '';
              if (pic.length > 0) {
                result = pic;
              }
            }
          } catch (_err) {
            // fall through
          }
        }
        break;
      }
    }
  } catch (err) {
    appendLxLog('内置封面[' + source + '] 异常: ' + JSON.stringify(err).substring(0, 120));
  }
  if (result.length > 0) {
    AppStorage.setOrCreate(cacheKey, result);
  }
  return result;
}

/** KRC decryption XOR key (from lx-music-desktop). */
const krcXorKey: number[] = [
  0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69
];

/** 酷狗歌词接口签名密钥 */
const kgLyricSecret: string = 'LnT6xpN3khm36zse0QzvmgTZ3waWdRSA';
/** 酷狗歌词接口 Android UA（服务端按 UA 返回逐字候选） */
const kgLyricUA: string = 'Android14-1070-11070-201-0-Lyric-wifi';

/** 酷狗歌词接口 md5 签名：md5(secret + 排序参数拼接 + secret) */
function kgLyricSign(params: Record<string, string>): string {
  const keys: string[] = Object.keys(params).sort();
  let body: string = '';
  for (let i: number = 0; i < keys.length; i++) {
    body += keys[i] + '=' + params[keys[i]];
  }
  return CryptoJS.MD5(kgLyricSecret + body + kgLyricSecret).toString();
}

/** URL 拼接（key=value&...，值做编码） */
function buildQuery(params: Record<string, string>): string {
  let out: string = '';
  const keys: string[] = Object.keys(params);
  for (let i: number = 0; i < keys.length; i++) {
    if (i > 0) {
      out += '&';
    }
    out += keys[i] + '=' + encodeParam(params[keys[i]]);
  }
  return out;
}
/**
 * 酷狗带签名歌词接口（lyrics.kugou.com/v1/search + download）。
 * 返回 KRC 逐字转 LRC 后的文本；失败返回空串。
 * @param name 歌名
 * @param singer 歌手（可为空）
 * @param hash 歌曲 FileHash
 * @param durationMs 歌曲时长（毫秒）
 */
async function kgLyricV1(name: string, singer: string, hash: string, durationMs: number): Promise<string> {
  try {
    const keyword: string = (singer.length > 0 ? singer + ' - ' : '') + name;
    const base: Record<string, string> = {
      'appid': '3116',
      'clientver': '11070',
      'duration': Math.max(1, Math.round(durationMs)).toString(),
      'hash': hash,
      'keyword': keyword,
      'lrctxt': '1',
      'man': 'no'
    };
    base['signature'] = kgLyricSign(base);
    const headers: Record<string, string> = { 'User-Agent': kgLyricUA };
    const searchUrl: string = 'https://lyrics.kugou.com/v1/search?' + buildQuery(base);
    const searchText: string = await httpGet(searchUrl, headers);
    appendLxLog('[kg歌词] v1/search resp len=' + searchText.length);
    if (searchText.length === 0) {
      return '';
    }
    const searchResp: Record<string, Object> = JSON.parse(searchText) as Record<string, Object>;
    const candidates: Object[] = searchResp.candidates as Object[] || [];
    if (candidates.length === 0) {
      return '';
    }
    const first: Record<string, Object> = candidates[0] as Record<string, Object>;
    const krcId: string = first.id as string || '';
    const accesskey: string = first.accesskey as string || '';
    if (krcId.length === 0 || accesskey.length === 0) {
      return '';
    }
    const dl: Record<string, string> = {
      'appid': '3116',
      'clientver': '11070',
      'accesskey': accesskey,
      'charset': 'utf8',
      'client': 'mobi',
      'fmt': 'krc',
      'id': krcId,
      'ver': '1'
    };
    dl['signature'] = kgLyricSign(dl);
    const dlUrl: string = 'http://lyrics.kugou.com/download?' + buildQuery(dl);
    const dlText: string = await httpGet(dlUrl, headers);
    appendLxLog('[kg歌词] v1 download resp len=' + dlText.length);
    if (dlText.length === 0) {
      return '';
    }
    const dlResp: Record<string, Object> = JSON.parse(dlText) as Record<string, Object>;
    const content: string = dlResp.content as string || '';
    if (content.length === 0) {
      return '';
    }
    const contentType: number = parseInt(dlResp.contenttype as string || '0', 10);
    if (contentType === 2) {
      // 纯文本 LRC（base64 直接解码）
      const base64Helper: util.Base64Helper = new util.Base64Helper();
      const raw: Uint8Array = base64Helper.decodeSync(content);
      const textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      return textDecoder.decodeToString(raw);
    }
    // KRC 逐字：解密后返回 KRC 原文（由 AMLL 解析器做逐字解析）
    const krc: string = await kgKrcDecode(content);
    if (krc.length > 0) {
      appendLxLog('内置歌词[kg] v1 KRC ok, len=' + krc.length);
      return krc;
    }
    return '';
  } catch (_err) {
    return '';
  }
}
/** Decodes a base64 KRC payload and returns the raw KRC text (word-timed, for AMLL parser). */
async function kgKrcDecode(contentBase64: string): Promise<string> {
  try {
    const base64Helper: util.Base64Helper = new util.Base64Helper();
    const raw: Uint8Array = base64Helper.decodeSync(contentBase64);
    const body: Uint8Array = raw.subarray(4);
    const xored: Uint8Array = new Uint8Array(body.length);
    for (let i: number = 0; i < body.length; i++) {
      xored[i] = body[i] ^ krcXorKey[i % 16];
    }
    const zipObj: zlib.Zip = zlib.createZipSync();
    const outBufSize: number = Math.max(xored.byteLength * 8 + 1024, 64 * 1024);
    const outBuf: ArrayBuffer = new ArrayBuffer(outBufSize);
    const result: zlib.ZipOutputInfo = await zipObj.uncompress(outBuf, xored.buffer as ArrayBuffer, xored.byteLength);
    if (result === undefined || result.destLen <= 0) {
      return '';
    }
    const textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return textDecoder.decodeToString(new Uint8Array(outBuf, 0, result.destLen));
  } catch (_err) {
    return '';
  }
}

/** 酷我 lrcx 逐字歌词解密密钥 */
const kwLrcxKey: number[] = [0x79, 0x65, 0x65, 0x6c, 0x69, 0x6f, 0x6e];

/** 逐字节异或（密钥循环） */
function xorBytes(data: Uint8Array, key: number[]): Uint8Array {
  const out: Uint8Array = new Uint8Array(data.length);
  for (let i: number = 0; i < data.length; i++) {
    out[i] = data[i] ^ key[i % key.length];
  }
  return out;
}

/**
 * 酷我 newlyric.kuwo.cn lrcx 逐字歌词：
 * 参数 XOR('yeelion') + base64 -> GET -> tp=content + zlib -> base64 -> XOR -> gb18030。
 * @param songId 酷我 MUSIC_rid（不带前缀）
 * @returns lrcx 歌词文本，失败返回空串
 */
async function kwLrcxLyric(songId: string): Promise<string> {
  try {
    // Step 1: 构建并加密请求参数
    const params: string = `user=12345,web,web,web&requester=localhost&req=1&rid=MUSIC_${songId}&lrcx=1`;
    const paramBytes: Uint8Array = new util.TextEncoder().encodeInto(params);
    const xored: Uint8Array = xorBytes(paramBytes, kwLrcxKey);
    const base64Helper: util.Base64Helper = new util.Base64Helper();
    // encodeSync 可能返回 Uint8Array（base64 为纯 ASCII，转字符串后拼 URL）
    const encBytes: Uint8Array = base64Helper.encodeSync(xored);
    const utf8Enc: util.TextDecoder = util.TextDecoder.create('utf-8');
    const encrypted: string = utf8Enc.decodeToString(encBytes);

    // Step 2: 请求
    const url: string = 'http://newlyric.kuwo.cn/newlyric.lrc?' + encrypted;
    const raw: Uint8Array | undefined = await httpGetBuffer(url);
    appendLxLog('[kw歌词] newlyric resp len=' + (raw !== undefined ? raw.length : 0));
    if (raw === undefined || raw.length < 20) {
      return '';
    }

    // Step 3: 校验 tp=content 头并截取 zlib 数据
    const utf8Dec: util.TextDecoder = util.TextDecoder.create('utf-8');
    const head: string = utf8Dec.decodeToString(raw.subarray(0, 10));
    if (head !== 'tp=content') {
      appendLxLog('[kw歌词] newlyric 响应头不匹配: ' + head);
      return '';
    }
    let sep: number = -1;
    for (let i: number = 0; i + 3 < raw.length; i++) {
      if (raw[i] === 13 && raw[i + 1] === 10 && raw[i + 2] === 13 && raw[i + 3] === 10) {
        sep = i;
        break;
      }
    }
    if (sep < 0) {
      return '';
    }
    const compressed: Uint8Array = new Uint8Array(raw.subarray(sep + 4));

    // Step 4: zlib 解压（与 KRC 同一机制）
    const outBufSize: number = Math.max(compressed.length * 8 + 1024, 256 * 1024);
    const outBuf: ArrayBuffer = new ArrayBuffer(outBufSize);
    const zipObj: zlib.Zip = zlib.createZipSync();
    const result: zlib.ZipOutputInfo = await zipObj.uncompress(
      outBuf, compressed.buffer as ArrayBuffer, compressed.byteLength);
    if (result === undefined || result.destLen <= 0) {
      return '';
    }
    const inflated: Uint8Array = new Uint8Array(outBuf, 0, result.destLen);

    // Step 5: base64 -> XOR -> gb18030
    const base64Str: string = utf8Dec.decodeToString(inflated);
    const bufStr: Uint8Array = base64Helper.decodeSync(base64Str);
    const decrypted: Uint8Array = xorBytes(bufStr, kwLrcxKey);
    const gbDec: util.TextDecoder = util.TextDecoder.create('gb18030');
    const lrcx: string = gbDec.decodeToString(decrypted);
    appendLxLog('[kw歌词] newlyric lrcx ok, len=' + lrcx.length);
    return lrcx;
  } catch (_err) {
    return '';
  }
}

/**
 * QQ GetPlayLyricInfo（musicu.fcg, crypt=1）完整歌词：
 * lyric=主歌词（hex 加密 QRC/XML）、trans=翻译（hex 加密 LRC）、roma=罗马音（hex 加密 QRC/XML）。
 * 单请求返回三项，hex 3DES 解密（密钥 !@#)(*$%123ZXC!@!@#)(NHL）+ zlib。
 * @param musicId QQ 数字 songid
 */
interface QqPlayLyricParam {
  crypt: number;
  lrc_t: number;
  qrc: number;
  qrc_t: number;
  roma: number;
  roma_t: number;
  trans: number;
  trans_t: number;
  needSingingAnnotations: boolean;
  type: number;
  songId: number;
}

interface QqPlayLyricReq {
  module: string;
  method: string;
  param: QqPlayLyricParam;
}

interface QqPlayLyricBody {
  comm: Record<string, Object>;
  req_1: QqPlayLyricReq;
}

async function qqLyricV4Full(musicId: string): Promise<LyricFullResult> {
  const empty: LyricFullResult = { main: '', translation: '', romanLyric: '' };
  try {
    const param: QqPlayLyricParam = {
      crypt: 1, lrc_t: 0, qrc: 1, qrc_t: 0, roma: 1, roma_t: 0, trans: 1, trans_t: 0,
      needSingingAnnotations: false, type: 1, songId: parseInt(musicId)
    };
    const req: QqPlayLyricReq = {
      module: 'music.musichallSong.PlayLyricInfo',
      method: 'GetPlayLyricInfo',
      param: param
    };
    const comm: Record<string, Object> = {
      'ct': 19, 'cv': 1859, 'uin': 0, 'format': 'json', 'inCharset': 'utf-8',
      'outCharset': 'utf-8', 'platform': 'yqq', 'notice': 0, 'need_new_code': 1
    };
    const bodyObj: QqPlayLyricBody = { comm: comm, req_1: req };
    const body: string = JSON.stringify(bodyObj);
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://y.qq.com/portal/player.html',
      'Content-Type': 'application/json'
    };
    const text: string = await httpPost('https://u.y.qq.com/cgi-bin/musicu.fcg', body, headers);
    appendLxLog('[tx歌词] GetPlayLyricInfo resp len=' + text.length);
    if (text.length === 0) {
      return empty;
    }
    const resp: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const reqResp: Record<string, Object> = resp['req_1'] as Record<string, Object> || {};
    const data: Record<string, Object> = reqResp['data'] as Record<string, Object> || {};
    const decodeNode = (raw: string): string => {
      const trimmed: string = raw.trim();
      if (trimmed.length === 0) {
        return '';
      }
      try {
        return amllDecryptQrcHex(trimmed);
      } catch (_err) {
        return trimmed;
      }
    };
    const extractContent = (raw: string): string => {
      if (raw.includes('<?xml') || raw.includes('<Qrc')) {
        // QQ 的 LyricContent 属性值内可能含未转义的字面双引号（歌词中的 "），
        // 不能用 [^"]* 按引号边界匹配（会在第一个字面引号处截断）；
        // 用 LyricContent=" 定位起点、"/> 定位终点（QRC 文本中不会出现 "/>"）。
        const startMarker: string = 'LyricContent="';
        const startIdx: number = raw.indexOf(startMarker);
        if (startIdx >= 0) {
          const valueStart: number = startIdx + startMarker.length;
          const endIdx: number = raw.indexOf('"/>', valueStart);
          if (endIdx > valueStart) {
            return raw.substring(valueStart, endIdx);
          }
        }
      }
      return raw;
    };

    const mainRaw: string = decodeNode(data['lyric'] as string || '');
    const main: string = extractContent(mainRaw);
    const trans: string = decodeNode(data['trans'] as string || '');
    const roma: string = extractContent(decodeNode(data['roma'] as string || ''));
    appendLxLog('[tx歌词] GetPlayLyricInfo main=' + main.length + ' trans=' + trans.length +
      ' roma=' + roma.length);
    const result: LyricFullResult = { main: main, translation: trans, romanLyric: roma };
    return result;
  } catch (_err) {
    return empty;
  }
}

/** kg lyric via play/getdata with appid/mid parameters (KRC fallback). */
async function kgLyricViaGetdata(songId: string): Promise<string> {  try {
    const url: string = 'https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash=' + songId +
      '&appid=1014&mid=56bbbd2918b95d6975f420f96c5c29bb&_=' + Date.now().toString();
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 12; EBG-AN10) AppleWebKit/537.36',
      'Referer': 'https://www.kugou.com/'
    };
    const text: string = await httpGet(url, headers);
    appendLxLog('[kg歌词] getdata resp len=' + text.length +
      (text.indexOf('30020') >= 0 ? ' err=30020' : ''));
    if (text.length > 0) {
      const resp: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const data: Record<string, Object> = resp.data as Record<string, Object> || {};
      const lyrics: string = data.lyrics as string || '';
      if (lyrics.length > 0) {
        appendLxLog('内置歌词[kg] getdata ok, len=' + lyrics.length);
        return lyrics;
      }
    }
  } catch (_err) {
    // ignore
  }
  return '';
}

/**
 * Built-in lyric resolution for kw/kg.
 * @param source Music source id.
 * @param songId Song id (kw: songmid, kg: hash).
 * @param name Song name (kg KRC search).
 * @param singer Singer line (kg KRC search).
 * @returns LRC lyric text, or empty when unavailable.
 */
export async function lxGetLyricFallback(source: string, songId: string, name?: string,
  singer?: string): Promise<string> {
  appendLxLog('[歌词请求] source=' + source + ' id=' + songId);
  try {
    switch (source) {
      case 'kw': {
        // Try 0: newlyric.kuwo.cn lrcx 逐字歌词（XOR + zlib + gb18030）
        const lrcx: string = await kwLrcxLyric(songId);
        if (lrcx.length > 0) {
          return lrcx;
        }
        // Try 1: songinfoandlrc -> data.lrc (plain LRC text)
        // Try 1: songinfoandlrc (http + httpStatus=1) -> data.lrclist (time in seconds).
        const url1: string = 'https://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=' + songId + '&httpStatus=1';
        const text1: string = await httpGet(url1);
        appendLxLog('[kw歌词] songinfoandlrc resp len=' + text1.length);
        if (text1.length > 0) {
          try {
            const resp1: Record<string, Object> = JSON.parse(text1) as Record<string, Object>;
            const data1: Record<string, Object> = resp1.data as Record<string, Object> || {};
            const lrclist: Object[] = data1.lrclist as Object[] || [];
            if (lrclist.length > 0) {
              let lrcText: string = '';
              for (let i: number = 0; i < lrclist.length; i++) {
                const row: Record<string, Object> = lrclist[i] as Record<string, Object>;
                const timeSec: number = Number.parseFloat(row.time as string || '0');
                const line: string = row.lineLyric as string || '';
                if (line.length > 0 && Number.isFinite(timeSec)) {
                  const totalMs: number = Math.floor(timeSec * 1000);
                  const totalSec: number = Math.floor(totalMs / 1000);
                  const mm: string = Math.floor(totalSec / 60).toString().padStart(2, '0');
                  const ss: string = (totalSec % 60).toString().padStart(2, '0');
                  const ms: string = (totalMs % 1000).toString().padStart(3, '0');
                  lrcText += '[' + mm + ':' + ss + '.' + ms + ']' + line + '\n';
                }
              }
              if (lrcText.length > 0) {
                appendLxLog('内置歌词[kw] songinfoandlrc ok, len=' + lrcText.length);
                return lrcText;
              }
            }
          } catch (_err) {
            // fall through
          }
        }
        // Try 2: musicInfo -> data.lrclist (time + lineLyric rows)
        const url2: string = 'https://www.kuwo.cn/api/www/music/musicInfo?mid=' + songId + '&httpsStatus=1';
        const text2: string = await httpGet(url2);
        if (text2.length > 0) {
          try {
            const resp2: Record<string, Object> = JSON.parse(text2) as Record<string, Object>;
            const data2: Record<string, Object> = resp2.data as Record<string, Object> || {};
            const lrclist2: Object[] = data2.lrclist as Object[] || [];
            if (lrclist2.length > 0) {
              let lrcText: string = '';
              for (let i: number = 0; i < lrclist2.length; i++) {
                const row: Record<string, Object> = lrclist2[i] as Record<string, Object>;
                const time: string = row.time as string || '';
                const line: string = row.lineLyric as string || '';
                if (line.length > 0) {
                  lrcText += '[' + time + ']' + line + '\n';
                }
              }
              if (lrcText.length > 0) {
                appendLxLog('内置歌词[kw] musicInfo ok, len=' + lrcText.length);
                return lrcText;
              }
            }
          } catch (_err) {
            // fall through
          }
        }
        appendLxLog('内置歌词[kw] 接口均无歌词');
        return '';
      }
      case 'kg': {
        // Try 0: 带签名接口 v1/search + download（Android UA，KRC 逐字）
        const nameText0: string = name !== undefined && name.length > 0 ? name : songId;
        const singerText0: string = singer !== undefined ? singer : '';
        const v1Lrc: string = await kgLyricV1(nameText0, singerText0, songId, 0);
        if (v1Lrc.length > 0) {
          return v1Lrc;
        }
        // Try 1: 无签名 lyrics.kugou.com/search -> download -> decode (base64 + xor + inflate) -> LRC.
        const nameText: string = nameText0;
        const singerText: string = singerText0;
        const keyword: string = encodeParam(
          (singerText.length > 0 ? singerText + ' - ' : '') + nameText);
        const searchUrl: string = 'https://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=' + keyword;
        const searchText: string = await httpGet(searchUrl);
        appendLxLog('[kg歌词] search resp len=' + searchText.length +
          (searchText.length > 0 ? ' hasCandidate=' + searchText.indexOf('candidates') : ''));
        if (searchText.length > 0) {
          try {
            const searchResp: Record<string, Object> = JSON.parse(searchText) as Record<string, Object>;
            const candidates: Object[] = searchResp.candidates as Object[] || [];
            if (candidates.length > 0) {
              const first: Record<string, Object> = candidates[0] as Record<string, Object>;
              const krcId: string = first.id as string || '';
              const accesskey: string = first.accesskey as string || '';
              if (krcId.length > 0 && accesskey.length > 0) {
                const dlUrl: string = 'https://lyrics.kugou.com/download?ver=1&client=pc&id=' + krcId +
                  '&accesskey=' + accesskey + '&fmt=krc';
                const dlText: string = await httpGet(dlUrl);
                appendLxLog('[kg歌词] download resp len=' + dlText.length);
                if (dlText.length > 0) {
                  const dlResp: Record<string, Object> = JSON.parse(dlText) as Record<string, Object>;
                  const content: string = dlResp.content as string || '';
                  if (content.length > 0) {
                    const krc: string = await kgKrcDecode(content);
                    if (krc.length > 0) {
                      appendLxLog('内置歌词[kg] KRC ok, len=' + krc.length);
                      return krc;
                    }
                    appendLxLog('内置歌词[kg] KRC 解密失败');
                  }
                }
              }
            }
            // Fallback: search by song name only.
            if (singerText.length > 0) {
              appendLxLog('内置歌词[kg] 歌手-歌名无候选，用歌名重搜');
              const nameKeyword: string = encodeParam(nameText);
              const nameSearchUrl: string = 'https://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=' +
                nameKeyword;
              const nameSearchText: string = await httpGet(nameSearchUrl);
              appendLxLog('[kg歌词] 歌名重搜 resp len=' + nameSearchText.length);
              if (nameSearchText.length > 0) {
                try {
                  const nameResp: Record<string, Object> = JSON.parse(nameSearchText) as Record<string, Object>;
                  const nameCandidates: Object[] = nameResp.candidates as Object[] || [];
                  if (nameCandidates.length > 0) {
                    const first: Record<string, Object> = nameCandidates[0] as Record<string, Object>;
                    const krcId: string = first.id as string || '';
                    const accesskey: string = first.accesskey as string || '';
                    if (krcId.length > 0 && accesskey.length > 0) {
                      const dlUrl: string = 'https://lyrics.kugou.com/download?ver=1&client=pc&id=' + krcId +
                        '&accesskey=' + accesskey + '&fmt=krc';
                      const dlText: string = await httpGet(dlUrl);
                      appendLxLog('[kg歌词] 歌名重搜 download resp len=' + dlText.length);
                      if (dlText.length > 0) {
                        const dlResp: Record<string, Object> = JSON.parse(dlText) as Record<string, Object>;
                        const content: string = dlResp.content as string || '';
                        if (content.length > 0) {
                          const krc: string = await kgKrcDecode(content);
                          if (krc.length > 0) {
                            appendLxLog('内置歌词[kg] KRC ok(歌名重搜), len=' + krc.length);
                            return krc;
                          }
                        }
                      }
                    }
                  }
                } catch (_err) {
                  // fall through
                }
              }
            }
            appendLxLog('内置歌词[kg] search 无候选，尝试 getdata');
            return await kgLyricViaGetdata(songId);
          } catch (_err) {
            appendLxLog('内置歌词[kg] search 解析失败，尝试 getdata');
            return await kgLyricViaGetdata(songId);
          }
        }
        appendLxLog('内置歌词[kg] search 空响应，尝试 getdata');
        return await kgLyricViaGetdata(songId);
      }
      case 'tx': {
        const txName: string = name !== undefined && name.length > 0 ? name : songId;
        const txSinger: string = singer !== undefined ? singer : '';
        // Try 0: musicu.fcg GetPlayLyricInfo（crypt=1）加密 QRC 逐字歌词
        let numId: string = qqNumIdCache.get(songId) ?? '';
        if (numId.length === 0) {
          // 缓存 miss（历史记录/榜单播放）：按歌名搜索一次拿数字 id（txSearch 会填充缓存）
          try {
            const searchQuery: string = (txSinger.length > 0 ? txSinger + ' ' : '') + txName;
            await txSearch(searchQuery, 1, 8);
            numId = qqNumIdCache.get(songId) ?? '';
          } catch (_err) {
            // ignore
          }
        }
        if (numId.length > 0) {
          const full: LyricFullResult = await qqLyricV4Full(numId);
          if (full.main.length > 0) {
            appendLxLog('内置歌词[tx] QRC 逐字 ok, len=' + full.main.length);
            return full.main;
          }
        }
        // Try 1: QQ music lyric: fcg_query_lyric_new with nobase64=1 returns plain LRC.
        const url: string = 'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=' + songId +
          '&format=json&nobase64=1&g_tk=5381&loginUin=0&hostUin=0&inCharset=utf8&outCharset=utf-8' +
          '&notice=0&platform=yqq.json&needNewCode=0';
        const headers: Record<string, string> = {
          'Referer': 'https://y.qq.com/portal/player.html',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        };
        const text: string = await httpGet(url, headers);
        appendLxLog('[tx歌词] resp len=' + text.length + ' preview=' +
          (text.length > 0 ? text.substring(0, 100) : '(空)'));
        if (text.length > 0) {
          try {
            const resp: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
            const lyric: string = resp.lyric as string || '';
            if (lyric.length > 0) {
              appendLxLog('内置歌词[tx] ok, len=' + lyric.length);
              return lyric;
            }
          } catch (_err) {
            // fall through
          }
        }
        appendLxLog('内置歌词[tx] 无歌词');
        return '';
      }
      case 'wy': {
        // NetEase eapi lyric: yrc (word-timed) preferred, then plain lrc.
        const all: WyLyricResult = await lxGetWyLyricAll(songId);
        if (all.main.length > 0) {
          appendLxLog('内置歌词[wy] ok, len=' + all.main.length + ' wordLyric=' +
            (all.main.indexOf(']') > 0 ? all.main.substring(0, 60) : ''));
          return all.main;
        }
        appendLxLog('内置歌词[wy] 无歌词');
        return '';
      }
      case 'mg': {
        // Migu lyric by copyrightId.
        const url: string = 'https://music.migu.cn/v3/api/music/audioPlayer/getLyric?copyrightId=' + songId;
        const headers: Record<string, string> = {
          'Referer': 'https://music.migu.cn/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        };
        const text: string = await httpGet(url, headers);
        appendLxLog('[mg歌词] resp len=' + text.length + ' preview=' +
          (text.length > 0 ? text.substring(0, 100) : '(空)'));
        if (text.length > 0) {
          try {
            const resp: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
            const lyric: string = resp.lyric as string || '';
            if (lyric.length > 0) {
              appendLxLog('内置歌词[mg] ok, len=' + lyric.length);
              return lyric;
            }
          } catch (_err) {
            // fall through
          }
        }
        appendLxLog('内置歌词[mg] 无歌词');
        return '';
      }
    }
  } catch (err) {
    appendLxLog('内置歌词[' + source + '] 异常: ' + JSON.stringify(err).substring(0, 120));
  }
  return '';
}

// ===================== 逐字歌词 (YRC/QRC/TTML) =====================

/** Main lyric plus translation, fetched in one NetEase eapi call. */
export interface WyLyricResult {
  /** Main lyric: word-timed LRC when yrc available, else plain lrc. */
  main: string;
  /** tlyric translation in LRC format; empty when unavailable. */
  translation: string;
  /** romalrc transliteration (romaji) in LRC format; empty when unavailable. */
  romanLyric: string;
}

/**
 * QQ music toplist info (banner / card).
 */
async function wyLyricPlain(songId: string): Promise<Record<string, Object>> {
  try {
    const url: string = 'https://interface3.music.163.com/api/song/lyric';
    const body: string = 'id=' + songId +
      '&os=pc&lv=-1&kv=-1&tv=-1&rv=-1&yv=-1&ytv=-1&yrv=-1&csrf_token=';
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
      'Referer': 'https://music.163.com/',
      'Content-Type': 'application/x-www-form-urlencoded'
    };
    const text: string = await httpPost(url, body, headers);
    appendLxLog('[wy歌词] plain resp len=' + text.length +
      (text.length > 0 ? ' preview=' + text.substring(0, 80) : '(空)'));
    if (text.length === 0) {
      return {};
    }
    try {
      const parsed: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const yrcObj: Record<string, Object> = parsed.yrc as Record<string, Object> || {};
      const yrcLen: number = (yrcObj.lyric as string || '').length;
      const lrcObj: Record<string, Object> = parsed.lrc as Record<string, Object> || {};
      const lrcLen: number = (lrcObj.lyric as string || '').length;
      console.info('[wyPlain] code=' + String(parsed.code) + ' yrcLen=' + yrcLen + ' lrcLen=' + lrcLen);
      return parsed;
    } catch (_err) {
      return {};
    }
  } catch (_err) {
    return {};
  }
}

/** 通用歌词结果（主歌词 + 翻译 + 罗马音） */
export interface LyricFullResult {
  main: string;
  translation: string;
  romanLyric: string;
}

/**
 * 通用歌词获取：按平台聚合主歌词/翻译/罗马音。
 * - wy：lxGetWyLyricAll（yrc 逐字 + tlyric + romalrc）
 * - tx：GetPlayLyricInfo（musicu.fcg crypt=1）QRC 逐字 + 翻译 + 罗马音
 * - kg/kw/mg：主歌词（kg=KRC 逐字、kw=lrcx 逐字）；翻译/罗马音视平台数据
 */
export async function lxGetLyricFull(source: string, songId: string, name?: string,
  singer?: string): Promise<LyricFullResult> {
  const empty: LyricFullResult = { main: '', translation: '', romanLyric: '' };
  try {
    if (source === 'wy') {
      const all: WyLyricResult = await lxGetWyLyricAll(songId);
      const result: LyricFullResult = {
        main: all.main,
        translation: all.translation,
        romanLyric: all.romanLyric
      };
      return result;
    }
    if (source === 'tx') {
      // QQ：GetPlayLyricInfo（musicu.fcg crypt=1）单请求（主歌词 QRC + 翻译 + 罗马音）
      let numId: string = qqNumIdCache.get(songId) ?? '';
      if (numId.length === 0) {
        try {
          const searchQuery: string = ((singer !== undefined && singer.length > 0 ? singer + ' ' : '')) +
            (name !== undefined && name.length > 0 ? name : songId);
          await txSearch(searchQuery, 1, 8);
          numId = qqNumIdCache.get(songId) ?? '';
        } catch (_err) {
          // ignore
        }
      }
      if (numId.length > 0) {
        return await qqLyricV4Full(numId);
      }
    }
    const main: string = await lxGetLyricFallback(source, songId, name, singer);
    const result: LyricFullResult = { main: main, translation: '', romanLyric: '' };
    return result;
  } catch (_err) {
    return empty;
  }
}

/** NetEase eapi /api/song/lyric encrypted request returning the raw response object. */
async function wyEapiSongLyric(songId: string): Promise<Record<string, Object>> {  interface WyLyricBody {
    id: string;
    lv: number;
    kv: number;
    tv: number;
    yv: number;
  }
  const path: string = '/api/song/lyric';
  const bodyObj: WyLyricBody = { id: songId, lv: -1, kv: -1, tv: -1, yv: -1 };
  const bodyStr: string = JSON.stringify(bodyObj) || '';
  const msg: string = 'nobody' + path + 'use' + bodyStr + 'md5forencrypt';
  const digest: string = CryptoJS.MD5(msg).toString();
  const data: string = path + '-36cd479b6b5-' + bodyStr + '-36cd479b6b5-' + digest;
  const keyUtf8 = CryptoJS.enc.Utf8.parse('e82ckenh8dichen8');
  const encrypted = CryptoJS.AES.encrypt(data, keyUtf8, {
    mode: CryptoJS.mode.ECB,
    padding: CryptoJS.pad.Pkcs7
  });
  const params: string = encrypted.ciphertext.toString().toUpperCase();
  const url: string = 'https://interface.music.163.com/eapi/song/lyric';
  const headers: Record<string, string> = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
    'Content-Type': 'application/x-www-form-urlencoded'
  };
  const text: string = await httpPost(url, 'params=' + encodeParam(params), headers);
  appendLxLog('[wy歌词] resp len=' + text.length + ' preview=' +
    (text.length > 0 ? text.substring(0, 100) : '(空)'));
  if (text.length === 0) {
    return {};
  }
  try {
    return JSON.parse(text) as Record<string, Object>;
  } catch (_err) {
    return {};
  }
}

/**
 * Fetches NetEase main lyric (yrc word-timed preferred) and translation in one call.
 * 优先使用免加密接口（interface3），失败回退 eapi。
 */
export async function lxGetWyLyricAll(songId: string): Promise<WyLyricResult> {
  try {
    let resp: Record<string, Object> = await wyLyricPlain(songId);
    if ((resp.code as number) !== 200) {
      appendLxLog('[wy歌词] 免加密接口失败，回退 eapi');
      resp = await wyEapiSongLyric(songId);
    }
    if (resp.code as number !== 200) {
      const empty: WyLyricResult = { main: '', translation: '', romanLyric: '' };
      return empty;
    }
    const yrc: Record<string, Object> = resp.yrc as Record<string, Object> || {};
    const lrc: Record<string, Object> = resp.lrc as Record<string, Object> || {};
    const tlyric: Record<string, Object> = resp.tlyric as Record<string, Object> || {};
    const romalrc: Record<string, Object> = resp.romalrc as Record<string, Object> || {};
    const yrcText: string = yrc.lyric as string || '';
    const lrcText: string = lrc.lyric as string || '';
    const translation: string = tlyric.lyric as string || '';
    const romanLyric: string = romalrc.lyric as string || '';
    let main: string = '';
    if (yrcText.trim().length > 0) {
      // 直接返回 YRC 原文（词级时间戳），由 AMLL 解析器逐字解析
      main = yrcText;
      appendLxLog('内置歌词[wy] yrc 逐字, len=' + main.length);
    }
    if (main.length === 0 && lrcText.trim().length > 0) {
      main = lrcText;
      appendLxLog('内置歌词[wy] 使用普通 lrc, len=' + main.length);
    }
    const result: WyLyricResult = { main: main, translation: translation, romanLyric: romanLyric };
    return result;
  } catch (err) {
    appendLxLog('内置歌词[wy] 异常: ' + JSON.stringify(err).substring(0, 120));
    const empty: WyLyricResult = { main: '', translation: '', romanLyric: '' };
    return empty;
  }
}

/** One hit returned by the amll-ttml-db "search-lyrics" endpoint. */
export interface TtmlSearchItem {
  id: string;
  file: string;
  score: number;
}

/** Request body of the "search-lyrics" endpoint. */
interface TtmlSearchBody {
  query: string;
  type: string;
}

/**
 * Searches the amll-ttml-db community database by song name (type "all") and returns
 * the matching entries including cross-platform ids (ncm/qq/apple/spotify).
 */
async function ttmlSearchLyrics(query: string, type: string): Promise<TtmlSearchItem[]> {
  const url: string = 'https://amlldb.bikonoo.com/api/search-lyrics';
  const headers: Record<string, string> = {
    'Content-Type': 'application/json; charset=utf-8',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
  };
  const bodyObj: TtmlSearchBody = { query: query, type: type };
  const body: string = JSON.stringify(bodyObj);
  try {
    const text: string = await httpPost(url, body, headers);
    if (text.length === 0) {
      return [];
    }
    const arr: Object[] = JSON.parse(text) as Object[];
    const items: TtmlSearchItem[] = [];
    for (let i: number = 0; i < arr.length; i++) {
      const obj: Record<string, Object> = arr[i] as Record<string, Object>;
      items.push({
        id: obj.id as string || '',
        file: obj.file as string || '',
        score: obj.score as number || 0
      });
    }
    return items;
  } catch (_err) {
    return [];
  }
}

/** Picks the entry with the highest score (id-search hits all match exactly). */
function ttmlPickBestById(items: TtmlSearchItem[]): TtmlSearchItem {
  let best: TtmlSearchItem = items[0];
  for (let i: number = 1; i < items.length; i++) {
    if (items[i].score > best.score) {
      best = items[i];
    }
  }
  return best;
}

/** Tries one source id: search the community db by id, then download the matched ttml file. Empty when not found. */
async function ttmlFetchById(sourceSongId: string): Promise<string> {
  if (!sourceSongId || sourceSongId.length === 0) {
    return '';
  }
  try {
    const items: TtmlSearchItem[] = await ttmlSearchLyrics(sourceSongId, 'id');
    if (items.length === 0) {
      appendLxLog('[ttml] id=\"' + sourceSongId + '\" 无候选');
      return '';
    }
    const target: TtmlSearchItem = ttmlPickBestById(items);
    if (target.file.length === 0) {
      appendLxLog('[ttml] id=\"' + sourceSongId + '\" 无下载文件(file=' + target.file + ')');
      return '';
    }
    const dlUrl: string = 'https://amlldb.bikonoo.com/raw-lyrics/' + encodeParam(target.file);
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    };
    // 服务器以 application/octet-stream 返回，必须走二进制读取再按 UTF-8 解码（axios 会拿到 ArrayBuffer）
    const bytes: Uint8Array | undefined = await httpGetBuffer(dlUrl, headers);
    let text: string = '';
    if (bytes !== undefined && bytes.length > 0) {
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      text = decoder.decodeToString(bytes, { stream: false });
    }
    appendLxLog('[ttml] id=\"' + sourceSongId + '\" file=' + target.file + ' len=' + text.length);
    if (text.length === 0 || text.indexOf('<tt') < 0) {
      return '';
    }
    // 直接返回 TTML 原文：由 AMLL 解析器逐字解析，并保留翻译（x-translation）与罗马音（x-roman）
    return text;
  } catch (err) {
    appendLxLog('[ttml] 异常: ' + JSON.stringify(err).substring(0, 120));
    return '';
  }
}

/**
 * Fetches word-timed TTML lyric from the amll-ttml-db mirror. QQ 歌曲同时持有 songmid 与
 * 数字 songid（两条 id 在 TTML 库的 qqIds 里分别存储），因此依次尝试两个 id，任一命中即用。
 * Empty when no id matches.
 */
export async function lxGetTTMLLyric(sourceSongId: string): Promise<string> {
  if (!sourceSongId || sourceSongId.length === 0) {
    return '';
  }
  const ids: string[] = [sourceSongId];
  const numId: string = qqNumIdCache.get(sourceSongId) ?? '';
  if (numId.length > 0 && ids.indexOf(numId) === -1) {
    ids.push(numId);
  }
  for (let i: number = 0; i < ids.length; i++) {
    const text: string = await ttmlFetchById(ids[i]);
    if (text.length > 0) {
      return text;
    }
  }
  return '';
}

/** QQ music toplist info (banner / card). */
export interface TxToplistInfo {
  name: string;
  pic: string;
  updateInfo: string;
}

/**
 * QQ music classic toplist API (no signature required).
 * @param topid Toplist id (26=热歌, 27=新歌, 4=流行指数, 5=港台, 6=内地, 16=欧美).
 * @param songNum How many songs to fetch.
 * @returns Merged song list.
 */
export async function lxTxToplist(topid: string, songNum: number): Promise<LXSearchResult> {
  try {
    const url: string = 'https://c.y.qq.com/v8/fcg-bin/fcg_v8_toplist_cp.fcg?topid=' + topid +
      '&page=detail&type=top&tpl=3&song_begin=0&song_num=' + songNum;
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://y.qq.com/'
    };
    const text: string = await httpGet(url, headers);
    if (text.length === 0) {
      return { list: [], total: 0, limit: songNum, source: 'tx' };
    }
    const resp: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const songlist: Object[] = resp.songlist as Object[] || [];
    const list: LXSearchSong[] = [];
    for (let i: number = 0; i < songlist.length; i++) {
      const item: Record<string, Object> = songlist[i] as Record<string, Object>;
      const data: Record<string, Object> = item.data as Record<string, Object> || {};
      const songmid: string = data.songmid as string || '';
      if (songmid.length === 0) {
        continue;
      }
      const name: string = data.songname as string || '';
      const singers: Object[] = data.singer as Object[] || [];
      const singerNames: string[] = [];
      for (let s: number = 0; s < singers.length; s++) {
        const singer: Record<string, Object> = singers[s] as Record<string, Object>;
        singerNames.push(singer.name as string || '');
      }
      const albumName: string = data.albumname as string || '';
      const albummid: string = data.albummid as string || '';
      const interval: number = parseInt(data.interval as string || '0');
      const img: string = albummid.length > 0 ?
        'https://y.gtimg.cn/music/photo_new/T002R500x500M000' + albummid + '.jpg' : '';
      const song: LXSearchSong = {
        songId: songmid, name: name, singer: singerNames.join('、'),
        albumName: albumName, albumId: albummid, source: 'tx',
        interval: formatTime(interval * 1000), img: img, types: []
      };
      list.push(song);
    }
        return { list: list, total: list.length, limit: songNum, source: 'tx' };
  } catch (err) {
        return { list: [], total: 0, limit: songNum, source: 'tx' };
  }
}

/**
 * Fetches QQ music toplist header info (name + banner pic).
 * @param topid Toplist id.
 * @returns Toplist info, or undefined when unavailable.
 */
export async function lxTxToplistInfo(topid: string): Promise<TxToplistInfo | undefined> {
  try {
    const url: string = 'https://c.y.qq.com/v8/fcg-bin/fcg_v8_toplist_cp.fcg?topid=' + topid +
      '&page=detail&type=top&tpl=3&song_begin=0&song_num=1';
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://y.qq.com/'
    };
    const text: string = await httpGet(url, headers);
    if (text.length === 0) {
      return undefined;
    }
    const resp: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const topinfo: Record<string, Object> = resp.topinfo as Record<string, Object> || {};
    const info: TxToplistInfo = {
      name: topinfo.ListName as string || '',
      pic: topinfo.pic as string || '',
      updateInfo: topinfo.UpdateType as string || ''
    };
    return info;
  } catch (_err) {
    return undefined;
  }
}

/** One QQ music singer row from the singer chart API. */
export interface TxSinger {
  /** Numeric singer id used by QQ singer pages. */
  singerId: string;
  /** QQ singer mid used for image urls. */
  singerMid: string;
  /** Display name of the singer. */
  name: string;
  /** Singer photo url (may be empty). */
  pic: string;
}

/**
 * Fetches the Kugou top singer chart (m.kugou.com mobile api). The QQ singer
 * endpoints (fcg_v8_singer_list / spl_get_top_singer) are offline, so the home
 * singer tab uses Kugou's mobile chart which still serves singer photos.
 * @param count How many singers to fetch.
 * @returns Singer chart rows, or empty array on failure.
 */
export async function lxKgSingerList(count: number): Promise<TxSinger[]> {
  try {
    const url: string = 'https://m.kugou.com/singer/list/88?json=true';
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://m.kugou.com/'
    };
    const text: string = await httpGet(url, headers);
    appendLxLog('[kg歌手] resp len=' + text.length);
    if (text.length === 0) {
      return [];
    }
    const resp: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const singersNode: Record<string, Object> = resp.singers as Record<string, Object> || {};
    const listNode: Record<string, Object> = singersNode.list as Record<string, Object> || {};
    const info: Object[] = listNode.info as Object[] || [];
    const singers: TxSinger[] = [];
    for (let i: number = 0; i < info.length && singers.length < count; i++) {
      const group: Record<string, Object> = info[i] as Record<string, Object>;
      const singerRows: Object[] = group.singer as Object[] || [];
      for (let j: number = 0; j < singerRows.length && singers.length < count; j++) {
        const row: Record<string, Object> = singerRows[j] as Record<string, Object>;
        const name: string = row.singername as string || '';
        const singerId: string = row.singerid as string || '';
        if (name.length === 0) {
          continue;
        }
        let pic: string = row.imgurl as string || '';
        pic = pic.replace('{size}', '300');
        if (pic.startsWith('https://')) {
          pic = 'https://' + pic.substring(7);
        }
        singers.push({ singerId: singerId, singerMid: '', name: name, pic: pic });
      }
    }
    appendLxLog('[kg歌手] 解析歌手=' + singers.length);
    return singers;
  } catch (err) {
    appendLxLog('[kg歌手] 异常: ' + JSON.stringify(err).substring(0, 120));
    return [];
  }
}

/**
 * Fetches the QQ music top singer chart.
 * @param count How many singers to fetch (max 60).
 * @returns Singer chart rows, or empty array on failure.
 */
export async function lxTxSingerList(count: number): Promise<TxSinger[]> {
  const urls: string[] = [
    'https://c.y.qq.com/v8/fcg-bin/fcg_v8_singer_list.fcg?channel=-2&page=1&key=all' +
      '&pagesize=' + count + '&curpage=1',
    'https://c.y.qq.com/splcloud/fcgi-bin/spl_get_top_singer.fcg?page=1&num=' + count
  ];
  for (let u: number = 0; u < urls.length; u++) {
    try {
      const headers: Record<string, string> = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://y.qq.com/'
      };
      const text: string = await httpGet(urls[u], headers);
      appendLxLog('[tx歌手] url#' + u + ' resp len=' + text.length);
      if (text.length === 0) {
        continue;
      }
      const singers = parseTxSingers(text);
      if (singers.length > 0) {
        appendLxLog('[tx歌手] 解析歌手=' + singers.length);
        return singers;
      }
    } catch (err) {
      appendLxLog('[tx歌手] url#' + u + ' 异常: ' + JSON.stringify(err).substring(0, 120));
    }
  }
  return [];
}

/** Parses singer rows from either fcg_v8_singer_list or spl_get_top_singer payloads. */
function parseTxSingers(text: string): TxSinger[] {
  const cleaned: string = stripJsonp(text);
  if (cleaned.length === 0) {
    return [];
  }
  const resp: Record<string, Object> = JSON.parse(cleaned) as Record<string, Object>;
  const data: Record<string, Object> = resp.data as Record<string, Object> || {};
  const singers: TxSinger[] = [];
  const list: Object[] = data.list as Object[] || [];
  for (let i: number = 0; i < list.length; i++) {
    const item: Record<string, Object> = list[i] as Record<string, Object>;
    const mid: string = item.Fsinger_mid as string || '';
    if (mid.length > 0) {
      singers.push({
        singerId: item.Fsinger_id as string || '',
        singerMid: mid,
        name: item.Fsinger_name as string || '',
        pic: 'https://y.gtimg.cn/music/photo_new/T001R300x300M000' + mid + '.jpg'
      });
      continue;
    }
    const singerName: string = item.singerName as string || '';
    if (singerName.length > 0) {
      const picUrl: string = item.singerPic as string || '';
      singers.push({
        singerId: item.singerId as string || '',
        singerMid: '',
        name: singerName,
        pic: toHttps(picUrl)
      });
    }
  }
  return singers;
}

/** Strips a JSONP wrapper (e.g. `callback({...})`) leaving only the JSON object. */
function stripJsonp(text: string): string {
  const trimmed: string = text.trim();
  if (trimmed.length === 0) {
    return '';
  }
  if (trimmed.startsWith('{')) {
    return trimmed;
  }
  const start: number = trimmed.indexOf('{');
  const end: number = trimmed.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return trimmed.substring(start, end + 1);
  }
  return '';
}

/** Upgrades an http image url to https (mixed-content guards on device). */
function toHttps(url: string): string {
  if (url.startsWith('http://')) {
    return 'https://' + url.substring(7);
  }
  return url;
}

/**
 * Fetches the QQ music hot search keywords.
 * @returns Hot search words (trimmed), or empty array on failure.
 */
export async function lxTxHotSearch(): Promise<string[]> {
  try {
    const url: string = 'https://c.y.qq.com/splcloud/fcgi-bin/gethotkey.fcg?g_tk=5381&format=json' +
      '&inCharset=utf-8&outCharset=utf-8';
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://y.qq.com/'
    };
    const text: string = await httpGet(url, headers);
    appendLxLog('[tx热搜] resp len=' + text.length);
    if (text.length === 0) {
      return [];
    }
    const cleaned: string = stripJsonp(text);
    if (cleaned.length === 0) {
      return [];
    }
    const resp: Record<string, Object> = JSON.parse(cleaned) as Record<string, Object>;
    const data: Record<string, Object> = resp.data as Record<string, Object> || {};
    const hotkey: Object[] = data.hotkey as Object[] || [];
    const words: string[] = [];
    for (let i: number = 0; i < hotkey.length; i++) {
      const item: Record<string, Object> = hotkey[i] as Record<string, Object>;
      const word: string = (item.k as string || '').trim();
      if (word.length > 0) {
        words.push(word);
      }
    }
    appendLxLog('[tx热搜] 解析词=' + words.length);
    return words;
  } catch (err) {
    appendLxLog('[tx热搜] 异常: ' + JSON.stringify(err).substring(0, 120));
    return [];
  }
}

/** One QQ music toplist entry from the full toplist overview API. */
export interface TxToplistEntry {
  /** Toplist id usable with {@link lxTxToplist}. */
  topid: string;
  /** Display name of the toplist. */
  name: string;
  /** Toplist banner pic url. */
  pic: string;
}

/**
 * Fetches the full QQ music toplist overview (all charts).
 * @returns Toplist entries, or empty array on failure.
 */
export async function lxTxToplistList(): Promise<TxToplistEntry[]> {
  try {
    const url: string = 'https://c.y.qq.com/v8/fcg-bin/fcg_v8_toplist_cp.fcg?page=detail&type=top&tpl=3' +
      '&song_begin=0&song_num=1';
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://y.qq.com/'
    };
    const text: string = await httpGet(url, headers);
        if (text.length === 0) {
      return [];
    }
    const cleaned: string = stripJsonp(text);
    if (cleaned.length === 0) {
      return [];
    }
    const resp: Record<string, Object> = JSON.parse(cleaned) as Record<string, Object>;
    const data: Record<string, Object> = resp.data as Record<string, Object> || {};
    const list: Object[] = data.topList as Object[] || [];
    const entries: TxToplistEntry[] = [];
    for (let i: number = 0; i < list.length; i++) {
      const item: Record<string, Object> = list[i] as Record<string, Object>;
      const topid: string = item.topID as string || '';
      if (topid.length === 0) {
        continue;
      }
      entries.push({
        topid: topid,
        name: item.listName as string || '',
        pic: toHttps(item.pic as string || '')
      });
    }
        return entries;
  } catch (err) {
        return [];
  }
}

async function kwLeaderboard(id: string, page: number, limit: number): Promise<LXSearchResult> {
  // 酷我榜单：走老 PC 端接口 `kbangserver.kuwo.cn/ksong.s`（无需签名）。
  // 原来的空实现让酷我榜单永远是空的；签名接口 wbd.kuwo.cn 的 AppId 又已被封。
  const url: string = 'http://kbangserver.kuwo.cn/ksong.s?from=pc&fmt=json&pn=0&rn=' + limit +
    '&type=bang&data=content&id=' + encodeURIComponent(id) +
    '&show_copyright_off=0&pcmp4=1&isbang=1&userid=0&httpStatus=1';
  const text: string = await httpGet(url);
  if (text.length === 0) {
    return { list: [], total: 0, limit: limit, source: 'kw' };
  }
  let resp: Record<string, Object> = {};
  try {
    resp = JSON.parse(text) as Record<string, Object>;
  } catch (_err) {
    return { list: [], total: 0, limit: limit, source: 'kw' };
  }
  const items: Object[] = (resp.musiclist as Object[]) || [];
  const total: number = parseInt((resp.num as string) || String(items.length));
  const list: LXSearchSong[] = [];
  const seen: Record<string, boolean> = {};
  for (let i: number = 0; i < items.length; i++) {
    const item: Record<string, Object> = items[i] as Record<string, Object>;
    // ⚠️ 这个接口的歌曲 id 字段是 `id`（不是 `rid` / 不是 `musicrid`），
    //    取错会让每一首都因 songId 为空而被过滤掉 —— 表现就是"榜单里一首歌都没有"。
    const songId: string = (item.id as string) || '';
    if (songId.length === 0 || seen[songId]) {
      continue;
    }
    seen[songId] = true;
    const durationSec: number = parseInt((item.song_duration as string) || (item.duration as string) || '0');
    const minutes: number = Math.floor(durationSec / 60);
    const seconds: number = durationSec % 60;
    const interval: string = durationSec > 0 ?
      String(minutes).padStart(2, '0') + ':' + String(seconds).padStart(2, '0') : '';
    const song: LXSearchSong = {
      songId: songId,
      name: (item.name as string) || '',
      singer: (item.artist as string) || '',
      albumName: (item.album as string) || '',
      albumId: (item.albumid as string) || '',
      source: 'kw',
      interval: interval,
      img: '',
      types: [{ type: '128k', size: '-1' }]
    };
    list.push(song);
  }
  return { list: list, total: total > 0 ? total : list.length, limit: limit, source: 'kw' };
}

async function kgLeaderboard(id: string, page: number, limit: number): Promise<LXSearchResult> {
  // ⚠️ 必须用 **http**：酷狗这个 CDN 的 HTTPS 证书与 `mobilecdnbj.kugou.com`
  //    对不上（curl 实测 `schannel: SNI or certificate check failed:
  //    SEC_E_WRONG_PRINCIPAL`），HTTPS 请求在设备上直接建连失败 ——
  //    这就是「酷狗榜单加载不出来」的原因。http 实测 200 且返回 100 条。
  let url: string =
    'http://mobilecdnbj.kugou.com/api/v3/rank/song?version=9108&ranktype=1&plat=0' +
    '&pagesize=' + limit + '&area_code=1&page=' + page + '&rankid=' + id +
    '&with_res_tag=0&show_portrait_mv=1';
  let text: string = await httpGet(url);
  if (text.length === 0) {
    return { list: [], total: 0, limit: limit, source: 'kg' };
  }
  let resp: Record<string, Object> = {};
  try {
    resp = JSON.parse(text) as Record<string, Object>;
  } catch (_err) {
    return { list: [], total: 0, limit: limit, source: 'kg' };
  }
  if (resp.errcode as number !== 0) {
    return { list: [], total: 0, limit: limit, source: 'kg' };
  }
  let data: Record<string, Object> = resp.data as Record<string, Object>;
  let items: Object[] = data.info as Object[] || [];
  let total: number = data.total as number || 0;
  let list: LXSearchSong[] = [];
  let seenIds: Record<string, boolean> = {};
  for (let i: number = 0; i < items.length; i++) {
    let item: Record<string, Object> = items[i] as Record<string, Object>;
    let hash: string = item.hash as string || '';
    if (hash.length === 0 || seenIds[hash]) {
      continue;
    }
    seenIds[hash] = true;
    let name: string = item.songname as string || '';
    let authors: Object[] = item.authors as Object[] || [];
    let singerNames: string[] = [];
    for (let a: number = 0; a < authors.length; a++) {
      let author: Record<string, Object> = authors[a] as Record<string, Object>;
      singerNames.push(author.author_name as string || '');
    }
    let album: string = item.remark as string || '';
    let albumId: string = item.album_id as string || '';
    let duration: number = parseInt(item.duration as string || '0');
    let fileSize: string = item.filesize as string || '';
    let hqSize: string = item['320filesize'] as string || '';
    let sqSize: string = item.sqfilesize as string || '';
    let resSize: string = item.filesize_high as string || '';
    let types: LXQualityType[] = [];
    if (fileSize !== '0' && fileSize.length > 0) {
      types.push({ type: '128k', size: '-1' });
    }
    if (hqSize !== '0' && hqSize.length > 0) {
      types.push({ type: '320k', size: '-1' });
    }
    if (sqSize !== '0' && sqSize.length > 0) {
      types.push({ type: 'flac', size: '-1' });
    }
    if (resSize !== '0' && resSize.length > 0) {
      types.push({ type: 'flac24bit', size: '-1' });
    }
    types.reverse();
    let song: LXSearchSong = {
      songId: hash, name: name, singer: singerNames.join('、'),
      albumName: album, albumId: albumId, source: 'kg',
      interval: formatTime(duration * 1000), img: '', types: types
    };
    list.push(song);
  }
  return { list: list, total: total, limit: limit, source: 'kg' };
}

async function mgLeaderboard(id: string, page: number, limit: number): Promise<LXSearchResult> {
  let url: string =
    'https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/querycontentbyId.do?columnId=' +
    id + '&needAll=0';
  let text: string = await httpGet(url);
  let resp: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
  let columnInfo: Record<string, Object> = resp.columnInfo as Record<string, Object> || {};
  let contents: Object[] = columnInfo.contents as Object[] || [];
  let list: LXSearchSong[] = [];
  let seenIds: Record<string, string> = {};
  for (let i: number = 0; i < contents.length; i++) {
    let content: Record<string, Object> = contents[i] as Record<string, Object>;
    let objInfo: Record<string, Object> = content.objectInfo as Record<string, Object> || {};
    let songId: string = objInfo.songId as string || '';
    let copyrightId: string = objInfo.copyrightId as string || '';
    if (copyrightId.length === 0 || seenIds[copyrightId] !== undefined) {
      continue;
    }
    seenIds[copyrightId] = copyrightId;
    let name: string = objInfo.songName as string || '';
    let artists: Object[] = objInfo.artists as Object[] || [];
    let singerNames: string[] = [];
    for (let a: number = 0; a < artists.length; a++) {
      let artist: Record<string, Object> = artists[a] as Record<string, Object>;
      singerNames.push(artist.artistName as string || '');
    }
    let album: string = objInfo.album as string || '';
    let albumId: string = objInfo.albumId as string || '';
    let duration: number = parseInt(objInfo.length as string || '0');
    let formats: Object[] = objInfo.newRateFormats as Object[] || [];
    let types: LXQualityType[] = parseMgQuality(formats);
    let img: string = '';
    let imgs: Object[] = objInfo.albumImgs as Object[] || [];
    if (imgs.length > 0) {
      let imgObj: Record<string, Object> = imgs[0] as Record<string, Object>;
      img = imgObj.img as string || '';
    }
    if (img.length > 0 && !img.startsWith('http')) {
      img = 'https://d.musicapp.migu.cn' + img;
    }
    let song: LXSearchSong = {
      songId: copyrightId, name: name, singer: singerNames.join('、'),
      albumName: album, albumId: albumId, source: 'mg',
      interval: formatTime(duration * 1000), img: img, types: types
    };
    list.push(song);
  }
  return { list: list, total: list.length, limit: limit, source: 'mg' };
}






