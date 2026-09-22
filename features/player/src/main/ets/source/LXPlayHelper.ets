import { LXSourceRequestData, LXMusicUrlResult, LXLyricResult, LXPicResult, LXSource, toLXSource } from './Interface';
import { lxEngineSendRequest, lxEngineRegisterPromise, lxEngineIsReady } from './LXSourceEngine';
import { lxSearch, lxLeaderboard } from './LXMusicSDK';
import { appendError } from 'musicbasic';

interface MusicInfoBrief {
  songmid: string;
  source: string;
  name?: string;
  singer?: string;
  albumName?: string;
  img?: string;
}

interface MusicUrlRequestInfo {
  type: string;
  musicInfo: MusicInfoBrief;
}

interface LyricPicRequestInfo {
  musicInfo: MusicInfoBrief;
}

function logError(msg: string): void {
  appendError(msg);
}
export { logError };

/**
 * 播放期歌曲 id 统一兜底转换缓存：key 为 source|songId，避免同一首歌反复搜索。
 * 在线导入/歌单迁移等任何入口存入的非本源标准 id 都在这里最终转换。
 */
const playableIdCache: Map<string, string> = new Map();

function isKgHash(songId: string): boolean {
  return /^[0-9A-Fa-f]{32}$/.test(songId);
}

/** 酷狗要求 Hash：非 32 位 hash 的 id 通过搜索按歌名+歌手补齐。 */
async function resolveKgHash(name: string, singer: string): Promise<string> {
  const query: string = (name + ' ' + singer).trim();
  if (query.length === 0) {
    return '';
  }
  try {
    const res = await lxSearch('kg', query, 1, 10);
    const nameNorm: string = name.trim();
    for (let i: number = 0; i < res.list.length; i++) {
      if (isKgHash(res.list[i].songId) && res.list[i].name.trim() === nameNorm) {
        return res.list[i].songId;
      }
    }
    for (let i: number = 0; i < res.list.length; i++) {
      if (isKgHash(res.list[i].songId)) {
        return res.list[i].songId;
      }
    }
  } catch (_err) {
    // ignore
  }
  return '';
}

/**
 * 播放前统一把 id 转成各源播放要求的标准形态：
 * 酷狗数字/其它形式 id → 32 位 Hash；酷我带 MUSIC_ 前缀的旧导出 → 去前缀。
 * 其余源原样返回。
 */
export async function resolvePlayableSongId(source: string, songId: string, name?: string,
  singer?: string): Promise<string> {
  if (songId.length === 0) {
    return songId;
  }
  const cacheKey: string = source + '|' + songId;
  const cached: string | undefined = playableIdCache.get(cacheKey);
  if (cached !== undefined) {
    return cached;
  }
  let resolved: string = songId;
  if (source === 'kg' && !isKgHash(songId)) {
    const hash: string = await resolveKgHash(name ?? '', singer ?? '');
    if (hash.length > 0) {
      resolved = hash;
    }
  } else if (source === 'kw' && songId.startsWith('MUSIC_')) {
    resolved = songId.substring(6);
  }
  playableIdCache.set(cacheKey, resolved);
  return resolved;
}

function buildMusicInfo(source: string, songId: string, name?: string, singer?: string,
  albumName?: string, img?: string): MusicInfoBrief {
  const info: MusicInfoBrief = { songmid: songId, source: source };
  if (name !== undefined && name.length > 0) {
    info.name = name;
  }
  if (singer !== undefined && singer.length > 0) {
    info.singer = singer;
  }
  if (albumName !== undefined && albumName.length > 0) {
    info.albumName = albumName;
  }
  if (img !== undefined && img.length > 0) {
    info.img = img;
  }
  return info;
}

export async function getLXMusicUrl(source: string, songId: string, quality: string, name?: string,
  singer?: string): Promise<string> {
  if (!lxEngineIsReady || lxEngineSendRequest === null || lxEngineRegisterPromise === null) {
    logError('引擎未就绪或回调未初始化');
    throw new Error('引擎未就绪或回调未初始化');
  }
  let sendReq: (key: string, data: LXSourceRequestData) => void = lxEngineSendRequest!;
  let regReq: (key: string,
    resolve: (result: object) => void, reject: (reason: Error) => void) => void = lxEngineRegisterPromise!;
  let requestKey: string = 'musicUrl_' + Date.now() + '_' + Math.random().toString(36).substring(2);
  let playableId: string = await resolvePlayableSongId(source, songId, name, singer);
  let musicInfo: MusicInfoBrief = buildMusicInfo(source, playableId, name, singer);
  let info: MusicUrlRequestInfo = { type: quality, musicInfo: musicInfo };
  let reqData: LXSourceRequestData = { source: toLXSource(source), action: 'musicUrl', info: info };
  if (playableId !== songId) {
    logError('发送请求: ' + source + '/' + songId + ' → ' + playableId + '/' + quality);
  } else {
    logError('发送请求: ' + source + '/' + songId + '/' + quality);
  }
  return new Promise<string>((resolve: (url: string) => void, reject: (reason: Error) => void): void => {
    regReq(requestKey, (result: object): void => {
      let mr: LXMusicUrlResult = result as LXMusicUrlResult;
      if (mr !== undefined && mr.data !== undefined && mr.data.url !== undefined && mr.data.url.length > 0) {
        logError('获取成功: ' + mr.data.url.substring(0, 80));
        resolve(mr.data.url);
      } else {
        let msg: string = '响应数据无效: ' + JSON.stringify(result).substring(0, 200);
        logError(msg);
        reject(new Error(msg));
      }
    }, (reason: Error): void => {
      logError('请求失败: ' + reason.message);
      reject(reason);
    });
    sendReq(requestKey, reqData);
  });
}

export async function getLXLyric(source: string, songId: string, name?: string, singer?: string): Promise<string> {
  if (!lxEngineIsReady || lxEngineSendRequest === null || lxEngineRegisterPromise === null) {
    logError('getLXLyric: 引擎未就绪');
    throw new Error('LX engine not ready');
  }
  let sendReq: (key: string, data: LXSourceRequestData) => void = lxEngineSendRequest!;
  let regReq: (key: string,
    resolve: (result: object) => void, reject: (reason: Error) => void) => void = lxEngineRegisterPromise!;
  let requestKey: string = 'lyric_' + Date.now() + '_' + Math.random().toString(36).substring(2);
  let playableId: string = await resolvePlayableSongId(source, songId, name, singer);
  let musicInfo: MusicInfoBrief = buildMusicInfo(source, playableId, name, singer);
  let info: LyricPicRequestInfo = { musicInfo: musicInfo };
  let reqData: LXSourceRequestData = { source: toLXSource(source), action: 'lyric', info: info };
  return new Promise<string>((resolve: (text: string) => void, reject: (reason: Error) => void): void => {
    regReq(requestKey, (result: object): void => {
      let lr: LXLyricResult = result as LXLyricResult;
      if (lr.data !== undefined) {
        resolve(lr.data.lyric);
      } else {
        logError('getLXLyric: 无效响应');
        reject(new Error('Invalid lyric response'));
      }
    }, reject);
    sendReq(requestKey, reqData);
  });
}

export async function getLXPic(source: string, songId: string, name?: string, singer?: string): Promise<string> {
  if (!lxEngineIsReady || lxEngineSendRequest === null || lxEngineRegisterPromise === null) {
    logError('getLXPic: 引擎未就绪');
    throw new Error('LX engine not ready');
  }
  let sendReq: (key: string, data: LXSourceRequestData) => void = lxEngineSendRequest!;
  let regReq: (key: string,
    resolve: (result: object) => void, reject: (reason: Error) => void) => void = lxEngineRegisterPromise!;
  let requestKey: string = 'pic_' + Date.now() + '_' + Math.random().toString(36).substring(2);
  let playableId: string = await resolvePlayableSongId(source, songId, name, singer);
  let musicInfo: MusicInfoBrief = buildMusicInfo(source, playableId, name, singer);
  let info: LyricPicRequestInfo = { musicInfo: musicInfo };
  let reqData: LXSourceRequestData = { source: toLXSource(source), action: 'pic', info: info };
  return new Promise<string>((resolve: (url: string) => void, reject: (reason: Error) => void): void => {
    regReq(requestKey, (result: object): void => {
      let pr: LXPicResult = result as LXPicResult;
      if (pr.data !== undefined) {
        resolve(pr.data);
      } else {
        logError('getLXPic: 无效响应');
        reject(new Error('Invalid pic response'));
      }
    }, reject);
    sendReq(requestKey, reqData);
  });
}

/** 榜单里的一首歌（供歌单详情页异步填充列表）。 */
export interface BoardSongEntry {
  /** 歌名。 */
  title: string;
  /** 歌手。 */
  singer: string;
  /** 平台代号（kw / kg / tx / wy / mg）。 */
  source: string;
  /** 平台内歌曲 id。 */
  songId: string;
  /** 封面；拿不到时留空，由调用方异步补。 */
  coverUrl: string;
}

/**
 * 拉取榜单歌曲。
 *
 * 放在 player 层是有意的：榜单页在 playlist 层，而 playlist **不能**依赖
 * recommendation（那是上层），所以取数只能靠底层的 player。但用「路由参数里传函数」
 * 这条路走不通 —— 导航参数经过框架传递后，对象里挂的回调函数会丢，页面拿到的
 * `loader` 是个默认空实现，表现就是"榜单打开后一首歌都没有"。
 * 现在由页面直接调这个函数，不依赖任何回调传递。
 *
 * @param source 平台代号。
 * @param boardId 榜单 id。
 * @returns 榜单歌曲；失败返回空数组。
 */
export async function fetchBoardSongs(source: string, boardId: string): Promise<BoardSongEntry[]> {
  if (source.length === 0 || boardId.length === 0) {
    return [];
  }
  try {
    const result = await lxLeaderboard(source + '_' + boardId, 1, 100);
    const out: BoardSongEntry[] = [];
    for (let i: number = 0; i < result.list.length; i++) {
      const s = result.list[i];
      if (s.songId.length === 0) {
        continue;
      }
      out.push({
        title: s.name, singer: s.singer, source: s.source, songId: s.songId, coverUrl: s.img
      });
    }
    logError('[榜单] ' + source + '/' + boardId + ' 取到 ' + out.length + ' 首');
    return out;
  } catch (err) {
    logError('[榜单] ' + source + '/' + boardId + ' 取歌失败: ' + JSON.stringify(err).substring(0, 120));
    return [];
  }
}
