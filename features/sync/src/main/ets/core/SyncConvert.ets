/**
 * 对应 listen 的 entry/src/main/ets/core/sync/SyncConvert.ets
 *
 * 适配改动（类型替换 + 少数不可得字段的处理，书写顺序一律照抄）：
 *   - 内部形态由 listen 的 SongItem(+musicInfoJson 里的 LxMusicInfo) 换成 RzdMusic 的
 *     `PlayedSongRecord`（musicbasic 导出的持久化行：songId/name/singer/albumName/albumId/source/
 *     interval/img/url/lyric/quality/playScript/time），因此：
 *       parseOldMusicInfo / toLxMusicInfo / isSyncable 的入参、fromLxMusicInfo 的返回都是 PlayedSongRecord；
 *       `if (info.source === 'local') return null;` 这条「本地歌不参与同步」的规则原样保留
 *       （判空从 listen 的 `songmid` 换成 `songId`）。
 *   - 同步用的 `LxMusicInfoNew`（id/name/singer/source/interval/meta）字段名与顺序与 listen 完全一致；
 *     meta 的书写顺序也照抄 toNewMusicInfo：songId → albumName → picUrl → qualitys → _qualitys →
 *     albumId（酷狗再补 hash）。顺序不能动：服务端快照 key 是列表 JSON 字符串的 md5，顺序一乱，
 *     重连时就会每次都被判成「不一致」而反复弹合并框。
 *   - id 规则：`${source}_${songId}`。listen 的 musicIdOf 对酷狗用的是 `${songmid}_${hash}`，
 *     这里因为内部形态只剩一个 songId，统一成一种形式，并且与 RzdMusic 内部的
 *     `source + '_' + songId`（MusicStoreService 的收藏/历史/歌单去重键）保持一致。
 *   - 不可得字段的处理：
 *       `types/_types`（多音质列表）→ PlayedSongRecord 只有单个 quality，因此 qualitys 给空数组，
 *       _qualitys 用该 quality 造一条 { size: null }（官方的 _qualitys 值本身就不带 type 字段）；
 *       酷狗 meta.hash 用 songId 填（RzdMusic 的 kg songId 就是酷狗 hash，见 LXMusicSDK 的搜索映射）；
 *       tx 的 strMediaMid/albumMid/数字 id、mg 的 copyrightId 这些平台私有字段 PlayedSongRecord 里没有，
 *       一律省略（对 RzdMusic 自己的播放链路无影响，它按 source+songId 解析）。
 *
 * 内部歌曲（PlayedSongRecord）与同步用歌曲（LxMusicInfoNew，洛雪 MusicInfoOnline 的
 * id/name/singer/source/interval/meta）之间的转换。
 *
 * 这份映射不是自己编的，是照抄洛雪官方的两个函数：
 *   - toNewMusicInfo（lx-music-mobile/src/utils/index.ts）：内部结构 -> 同步用结构
 *   - toOldMusicInfo（同文件）：同步用结构 -> 内部结构
 */

import { PlayedSongRecord } from 'musicbasic';
import { LxMusicInfoNew, LxMusicMeta, LxQualitySize } from './SyncTypes';

/** 音质从高到低，用来给同步回来的歌曲挑一个默认音质 */
const QUALITY_ORDER: string[] = ['flac24bit', 'flac', '320k', '128k'];

/** 洛雪的兼容修正：老数据里的 flac32bit 统一成 flac24bit */
const LEGACY_QUALITY: string = 'flac32bit';
const FIXED_QUALITY: string = 'flac24bit';

/** 这条内部歌曲能不能参与同步：必须有真实的平台标识（演示数据 source/songId 为空） */
export function isSyncable(item: PlayedSongRecord): boolean {
  return parseOldMusicInfo(item) !== null;
}

function parseOldMusicInfo(item: PlayedSongRecord): PlayedSongRecord | null {
  if (item === null || item === undefined) {
    return null;
  }
  if (typeof item.source !== 'string' || item.source.length === 0) {
    return null;
  }
  // 本地文件不在同步范围内（洛雪也只同步在线歌曲）
  if (item.source === 'local') {
    return null;
  }
  if (item.songId === undefined || item.songId === null || item.songId.length === 0) {
    return null;
  }
  return item;
}

/** 歌曲在同步数据里的 id（与 RzdMusic 内部的 source + '_' + songId 一致） */
export function musicIdOf(item: PlayedSongRecord): string {
  const songId: string = item.songId !== undefined && item.songId !== null ? item.songId : '';
  return `${item.source}_${songId}`;
}

/**
 * 内部单音质 -> 洛雪的 `_qualitys`（{size,hash}，没有 type 字段）
 * 官方这里是把 SDK 的 `_types` 逐个搬过来；RzdMusic 只有 record.quality 一个值，
 * 因此只造一条（flac32bit 按洛雪规则改名成 flac24bit）。
 */
function qualitySizesOf(quality: string): Record<string, LxQualitySize> {
  const out: Record<string, LxQualitySize> = {};
  if (quality === undefined || quality === null || quality.length === 0) {
    return out;
  }
  const key: string = quality === LEGACY_QUALITY ? FIXED_QUALITY : quality;
  const entry: LxQualitySize = { size: null };
  out[key] = entry;
  return out;
}

/**
 * 内部歌曲 -> 同步用歌曲（对应洛雪 toNewMusicInfo）。
 * 顺序不能动：id / name / singer / source / interval / meta，
 * meta 内部：songId / albumName / picUrl / qualitys / _qualitys / albumId (+ kg 的 hash)。
 */
export function toLxMusicInfo(item: PlayedSongRecord): LxMusicInfoNew | null {
  const old: PlayedSongRecord | null = parseOldMusicInfo(item);
  if (old === null) {
    return null;
  }
  // PlayedSongRecord 没有 SDK 的 types 列表，官方在没有 types 时也是给空数组
  const qualitys: Object[] = [];
  const qualitySizes: Record<string, LxQualitySize> = qualitySizesOf(old.quality);
  const albumName: string = old.albumName !== undefined && old.albumName !== null ? old.albumName : '';
  const picUrl: string = old.img !== undefined && old.img !== null ? old.img : '';
  const albumId: string = old.albumId !== undefined && old.albumId !== null ? old.albumId : '';
  const songId: string = old.songId;

  const meta: LxMusicMeta = {
    songId: songId,
    albumName: albumName,
    picUrl: picUrl,
    qualitys: qualitys,
    _qualitys: qualitySizes,
    albumId: albumId,
  };
  // 与洛雪的 kg 分支对位：hash 写在 albumId 之后（RzdMusic 的 kg songId 即酷狗 hash）
  if (old.source === 'kg') {
    meta.hash = songId;
  }

  return {
    id: musicIdOf(old),
    name: old.name,
    singer: old.singer,
    source: old.source,
    interval: old.interval,
    meta: meta,
  };
}

/**
 * 同步回来的歌曲里可用的音质，挑一个默认值。
 * 首选 QUALITY_ORDER 里的档位（与 RzdMusic 的播放链路一致），都没有时退回 _qualitys 的第一个键，
 * 这样「我们自己写上去的单档位音质」来回转换后不会变样。
 */
export function bestQuality(info: LxMusicInfoNew): string {
  const qualitys: Record<string, LxQualitySize> | undefined =
    info.meta !== undefined ? info.meta._qualitys : undefined;
  if (qualitys !== undefined && qualitys !== null) {
    for (const quality of QUALITY_ORDER) {
      if (qualitys[quality] !== undefined) {
        return quality;
      }
    }
    const keys: string[] = Object.keys(qualitys);
    if (keys.length > 0) {
      return keys[0];
    }
  }
  return '128k';
}

/**
 * 同步用歌曲 -> 内部歌曲（对应洛雪 toOldMusicInfo）。
 * 只还原 PlayedSongRecord 有的字段：播放链接 / 歌词 / 用户源脚本名都是本机解析出来的，
 * 不在同步数据里（洛雪同步的也只有歌曲元信息），留空由播放时再解析。
 */
export function fromLxMusicInfo(info: LxMusicInfoNew): PlayedSongRecord {
  const meta: LxMusicMeta = info.meta;
  const picUrl: string = (meta.picUrl !== undefined && meta.picUrl !== null) ? meta.picUrl : '';
  const record = new PlayedSongRecord();
  record.songId = meta.songId !== undefined && meta.songId !== null ? String(meta.songId) : '';
  record.name = info.name;
  record.singer = info.singer;
  record.albumName = meta.albumName !== undefined && meta.albumName !== null ? meta.albumName : '';
  record.albumId = meta.albumId !== undefined && meta.albumId !== null ? String(meta.albumId) : '';
  record.source = info.source;
  record.interval = info.interval !== undefined && info.interval !== null ? info.interval : '';
  record.img = picUrl;
  record.url = '';
  record.lyric = '';
  record.quality = bestQuality(info);
  record.playScript = '';
  record.time = Date.now();
  return record;
}
