/*
 * 本地歌的在线歌词匹配（打分 / 自动采用判定 / 逐平台搜索）
 *
 * 对应 listen 的文件：entry/src/main/ets/core/local/LyricMatch.ets（逐行移植）
 *
 * 适配点（只动了「搜索来源」这一层，打分与接受条件一字未改）：
 *  - listen 用宿主内置的 searchMusic(keyword, platform, page, limit)（返回 LxMusicInfo[]）；
 *    RzdMusic 里平台搜索能力在 features/player/src/main/ets/geuz/ —— 那里只有
 *    searchSingers / searchAlbums（歌手 / 专辑，见 geuz/index.ets 与 service/SearchDispatch.ets），
 *    **没有歌曲搜索**；歌曲搜索走 features/player/src/main/ets/source/LXMusicSDK.ets 的
 *    lxSearch(source, query, page, limit): Promise<LXSearchResult>，由 'player' 包导出
 *    （features/player/Index.ets）。所以这里改用 lxSearch，平台 id 仍是
 *    'kw' | 'kg' | 'tx' | 'wy' | 'mg'（与 RzdMusic 的 SongItem.source 同一套）。
 *  - listen 的 LxMusicInfo 在 RzdMusic 里不存在，这里定义等价的 MatchSongInfo
 *    （字段取 LXSearchSong 里歌词取词真正用到的那几个），并提供与 LXSearchSong 的互转，
 *    播放链路拿到 match 后可直接调 player 的 lxGetLyricFull(source, songId, name, singer) 取词。
 *
 * 一个已知的行差异（不是打分差异）：lxSearch 内部把网络异常吞掉、返回空结果，
 * 调用方无法区分「接口挂了 / 断网」和「确实没有结果」。listen 靠「请求没抛异常」
 * 判定平台应答过；这里退化成「平台返回了非空结果（或报了 total>0）」才算应答过。
 * 后果：一首在平台上完全搜不到的本地歌会「每次播放重搜一次」（listen 只搜一次）。
 * 这个方向是保守的：绝不会因为第一次播放恰好没网而永久失去歌词（listen 最在意的那条）。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { lxSearch } from 'player';
import type { LXSearchSong, LXSearchResult } from 'player';

const DOMAIN: number = 0x0001;
const TAG: string = 'LyricMatch';

/**
 * 本地歌在线匹配到的一条平台歌曲（listen 的 LxMusicInfo 的等价物）
 *
 * 只保留歌词取词与展示需要的字段：source + songId 是平台身份，
 * name / singer / interval 参与打分，img / albumName 供播放页展示。
 */
export interface MatchSongInfo {
  /** 平台内的歌曲 id（tx 是 songmid，播放取词时 player 内部会解析 numId） */
  songId: string;
  name: string;
  singer: string;
  albumName: string;
  albumId: string;
  /** 平台 id：'kw' | 'kg' | 'tx' | 'wy' | 'mg' */
  source: string;
  /** `mm:ss`；缺失时为空串（打分里按「时长未知」处理） */
  interval: string;
  img: string;
}

/** 参与匹配的平台，按「搜索接口稳定程度」排序；某个平台搜不动会跳到下一个 */
export const MATCH_PLATFORMS: string[] = ['kw', 'kg', 'tx', 'mg', 'wy'];

/** 平台名（显示用） */
const PLATFORM_LABELS: Record<string, string> = {
  'kw': '酷我',
  'kg': '酷狗',
  'tx': 'QQ',
  'mg': '咪咕',
  'wy': '网易'
};

/** 平台的中文名（认不出来的就原样显示） */
export function platformLabel(source: string): string {
  const label: string | undefined = PLATFORM_LABELS[source];
  return label === undefined ? source : label;
}

/** 差在这个范围内认为「就是同一首」 */
const DURATION_STRONG_MS: number = 3000;
/** 差在这个范围内算弱信号（不足以单独支撑匹配） */
const DURATION_WEAK_MS: number = 8000;
/** 差得比这还多，基本可以断定是另一个版本（现场版、加长版、串烧） */
const DURATION_REJECT_MS: number = 20000;

/** 一条候选的评估结果 */
export interface LyricCandidate {
  info: MatchSongInfo;
  /** 歌名归一化后完全一致 */
  nameExact: boolean;
  /** 歌名是包含关系（`晴天` vs `晴天live`） */
  nameClose: boolean;
  /** 歌手有交集 */
  singerHit: boolean;
  /** 本地歌手未知（标签与文件名都没给） */
  singerUnknown: boolean;
  /** 时长差（毫秒）；-1 = 有一边没有时长，比不了 */
  durationDiffMs: number;
  /** 够不够格自动采用 */
  autoOk: boolean;
  /** 排序用的综合分 */
  score: number;
}

/** 匹配结果：平台 + 那条在线歌 */
export interface LyricMatch {
  source: string;
  info: MatchSongInfo;
}

/** 自动匹配的结果 */
export interface AutoMatchResult {
  /** 匹配到的在线歌（没匹配到就是 null） */
  match: LyricMatch | null;
  /**
   * 至少有一个平台正常应答过
   *
   * 全平台都请求失败（断网、接口全都不可用）时是 false —— 调用方据此决定
   * **不要**把这次当成「已经搜过了」记下来，否则第一次播放恰好没网的用户
   * 以后有网也永远不会再匹配，等于永久没有歌词。
   *
   * 见文件头的说明：RzdMusic 的 lxSearch 吞异常，这里只能以「返回了非空结果」为应答证据。
   */
  searched: boolean;
}

/** 歌名归一化：小写、去掉空白与括号（与 PlaySession.normalizeName 同一套口径） */
export function normalizeForMatch(name: string): string {
  let out: string = '';
  for (let i = 0; i < name.length; i++) {
    const ch: string = name.charAt(i).toLowerCase();
    if (ch === ' ' || ch === '\t' || ch === '（' || ch === '）' || ch === '(' || ch === ')') {
      continue;
    }
    out += ch;
  }
  return out;
}

/** 歌手名拆成一个个名字（搜索结果里常见 `A/B`、`A、B`、`A feat. B`） */
export function singerTokens(singer: string): string[] {
  const out: string[] = [];
  let current: string = '';
  for (let i = 0; i < singer.length; i++) {
    const ch: string = singer.charAt(i);
    if (ch === '/' || ch === '、' || ch === ',' || ch === '，' || ch === ';' || ch === '；'
      || ch === '&' || ch === '|' || ch === ' ' || ch === '\t') {
      if (current.length > 0) {
        out.push(current);
        current = '';
      }
      continue;
    }
    current += ch;
  }
  if (current.length > 0) {
    out.push(current);
  }
  return out;
}

/** `mm:ss` -> 毫秒（搜索结果的 interval 就是这个格式） */
export function parseIntervalMs(interval: string): number {
  if (typeof interval !== 'string') {
    return 0;
  }
  const text: string = interval.trim();
  if (text.length === 0) {
    return 0;
  }
  const parts: string[] = text.split(':');
  if (parts.length === 1) {
    const only: number = Number.parseInt(parts[0], 10);
    return Number.isNaN(only) ? 0 : only * 1000;
  }
  const minutes: number = Number.parseInt(parts[0], 10);
  const seconds: number = Number.parseInt(parts[1], 10);
  if (Number.isNaN(minutes) || Number.isNaN(seconds)) {
    return 0;
  }
  return (minutes * 60 + seconds) * 1000;
}

function singerHit(localSinger: string, remoteSinger: string): boolean {
  // 先按分隔符拆，再逐个归一化（归一化会吃掉空格，反过来做就拆不开了）
  const local: string[] = singerTokens(localSinger);
  const remote: string[] = singerTokens(remoteSinger);
  if (local.length === 0 || remote.length === 0) {
    return false;
  }
  for (const rawOne of local) {
    const one: string = normalizeForMatch(rawOne);
    // 单个字符的名字（`A`、`李`）容易误命中，要求至少两个字
    if (one.length < 2) {
      continue;
    }
    for (const rawOther of remote) {
      const other: string = normalizeForMatch(rawOther);
      if (other.length < 2) {
        continue;
      }
      if (other === one || other.includes(one) || one.includes(other)) {
        return true;
      }
    }
  }
  return false;
}

/**
 * 给一条候选打分
 *
 * 歌名不一致的直接出局（同名歌太多，靠歌手猜不可靠）；歌名一致之后，
 * 歌手与时长是「第二个信号」，至少要有一个才能自动采用。
 *
 * 本函数与 listen 的实现逐行一致，不要放宽。
 */
export function scoreCandidate(info: MatchSongInfo, name: string, singer: string,
  durationMs: number): LyricCandidate {
  // 搜索结果是各平台 JSON 拼出来的，字段缺失比类型声明更常见 —— 一律按空串兜底
  const remoteName: string = typeof info.name === 'string' ? info.name : '';
  const remoteSinger: string = typeof info.singer === 'string' ? info.singer : '';
  const target: string = normalizeForMatch(name);
  const candidate: string = normalizeForMatch(remoteName);
  const nameExact: boolean = target.length > 0 && candidate === target;
  const nameClose: boolean = !nameExact && target.length > 1 && candidate.length > 1
    && (candidate.includes(target) || target.includes(candidate));

  const localSinger: string = singer.trim();
  const singerUnknown: boolean = localSinger.length === 0;
  const hit: boolean = !singerUnknown && singerHit(localSinger, remoteSinger);

  const remoteMs: number = parseIntervalMs(info.interval);
  let diff: number = -1;
  if (durationMs > 0 && remoteMs > 0) {
    diff = Math.abs(durationMs - remoteMs);
  }

  let score: number = 0;
  if (nameExact) {
    score += 60;
  } else if (nameClose) {
    score += 35;
  }
  if (hit) {
    score += 25;
  }
  if (diff >= 0 && diff <= DURATION_STRONG_MS) {
    score += 15;
  } else if (diff >= 0 && diff <= DURATION_WEAK_MS) {
    score += 8;
  }
  const durationStrong: boolean = diff >= 0 && diff <= DURATION_STRONG_MS;
  const durationTooFar: boolean = diff >= DURATION_REJECT_MS;
  if (durationTooFar) {
    // 时长差太多：多半是另一个版本（现场版 / 串烧 / 加长版），直接判出局
    score = 0;
  }

  // 「宁缺勿错」：歌名完全一致时，歌手或时长有一个对上就采用；
  // 歌名只是包含关系时，要求歌手与时长**都**对上，否则可能配到另一个版本。
  let autoOk: boolean = false;
  if (score > 0 && !durationTooFar) {
    if (nameExact) {
      autoOk = hit || durationStrong;
    } else if (nameClose) {
      autoOk = hit && durationStrong;
    }
  }

  return {
    info: info,
    nameExact: nameExact,
    nameClose: nameClose,
    singerHit: hit,
    singerUnknown: singerUnknown,
    durationDiffMs: diff,
    autoOk: autoOk,
    score: score
  };
}

/** 从候选里挑一条能自动采用的（时长最接近的优先）；没有返回 null */
export function pickAutoMatch(candidates: LyricCandidate[]): MatchSongInfo | null {
  let best: LyricCandidate | null = null;
  for (const candidate of candidates) {
    if (!candidate.autoOk) {
      continue;
    }
    if (best === null) {
      best = candidate;
      continue;
    }
    const better: boolean = candidate.score > best.score
      || (candidate.score === best.score && closerDuration(candidate, best));
    if (better) {
      best = candidate;
    }
  }
  return best === null ? null : best.info;
}

function closerDuration(a: LyricCandidate, b: LyricCandidate): boolean {
  if (a.durationDiffMs < 0) {
    return false;
  }
  if (b.durationDiffMs < 0) {
    return true;
  }
  return a.durationDiffMs < b.durationDiffMs;
}

// ------------------------------------------------------------ 平台搜索适配

/** 平台搜索结果 -> 本文件的 MatchSongInfo */
export function fromSearchSong(song: LXSearchSong): MatchSongInfo {
  return {
    songId: typeof song.songId === 'string' ? song.songId : '',
    name: typeof song.name === 'string' ? song.name : '',
    singer: typeof song.singer === 'string' ? song.singer : '',
    albumName: typeof song.albumName === 'string' ? song.albumName : '',
    albumId: typeof song.albumId === 'string' ? song.albumId : '',
    source: typeof song.source === 'string' ? song.source : '',
    interval: typeof song.interval === 'string' ? song.interval : '',
    img: typeof song.img === 'string' ? song.img : ''
  };
}

/**
 * MatchSongInfo -> player 的 LXSearchSong
 *
 * 播放链路取平台歌词走 lxGetLyricFull(source, songId, name, singer)，
 * 需要 LXSearchSong 形态时用这个转一下（types 留空：本地歌匹配到平台歌后
 * 只用来取词与展示封面，不参与音质协商）。
 */
export function toSearchSong(info: MatchSongInfo): LXSearchSong {
  const song: LXSearchSong = {
    songId: info.songId,
    name: info.name,
    singer: info.singer,
    albumName: info.albumName,
    albumId: info.albumId,
    source: info.source,
    interval: info.interval,
    img: info.img,
    types: []
  };
  return song;
}

/** 落盘/取盘用：匹配结果存成 JSON 字符串（索引里的 matchJson） */
export function infoToJson(info: MatchSongInfo): string {
  return JSON.stringify(info);
}

/** JSON 字符串 -> MatchSongInfo；解析不了返回 null（字段一律按空串兜底） */
export function infoFromJson(json: string): MatchSongInfo | null {
  if (json.length === 0) {
    return null;
  }
  try {
    const raw: MatchSongInfo = JSON.parse(json) as MatchSongInfo;
    if (raw === null || raw === undefined) {
      return null;
    }
    return {
      songId: typeof raw.songId === 'string' ? raw.songId : '',
      name: typeof raw.name === 'string' ? raw.name : '',
      singer: typeof raw.singer === 'string' ? raw.singer : '',
      albumName: typeof raw.albumName === 'string' ? raw.albumName : '',
      albumId: typeof raw.albumId === 'string' ? raw.albumId : '',
      source: typeof raw.source === 'string' ? raw.source : '',
      interval: typeof raw.interval === 'string' ? raw.interval : '',
      img: typeof raw.img === 'string' ? raw.img : ''
    };
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'parse match json failed: %{public}s', JSON.stringify(e));
    return null;
  }
}

/** 在某个平台上搜一批候选（手动匹配面板用） */
export async function searchCandidates(keyword: string, platform: string): Promise<MatchSongInfo[]> {
  const text: string = keyword.trim();
  if (text.length === 0) {
    return [];
  }
  const result: LXSearchResult = await lxSearch(platform, text, 1, 20);
  const out: MatchSongInfo[] = [];
  for (const song of result.list) {
    out.push(fromSearchSong(song));
  }
  return out;
}

/**
 * 自动匹配：按 MATCH_PLATFORMS 逐个平台试，找到一条够格的就用它
 *
 * 某个平台搜不动（网络、接口下线）只记一条日志就换下一个 ——
 * 平台搜索本身在 player 的 lxSearch 里逐平台独立，互不影响。
 */
export async function autoMatchLyric(name: string, singer: string,
  durationMs: number): Promise<AutoMatchResult> {
  if (name.trim().length === 0) {
    return { match: null, searched: false };
  }
  const keyword: string = singer.trim().length > 0 ? `${name} ${singer}` : name;
  let searched: boolean = false;
  for (const platform of MATCH_PLATFORMS) {
    let results: MatchSongInfo[] = [];
    try {
      results = await searchCandidates(keyword, platform);
    } catch (e) {
      hilog.info(DOMAIN, TAG, 'search on %{public}s failed: %{public}s',
        platform, (e as Error).message);
      continue;
    }
    if (results.length > 0) {
      // lxSearch 把网络异常吞成空结果，所以「有结果」是这里唯一能拿到的应答证据
      searched = true;
    }
    if (results.length === 0) {
      continue;
    }
    const candidates: LyricCandidate[] = [];
    for (const info of results) {
      candidates.push(scoreCandidate(info, name, singer, durationMs));
    }
    const best: MatchSongInfo | null = pickAutoMatch(candidates);
    if (best !== null) {
      hilog.info(DOMAIN, TAG, 'matched "%{public}s" on %{public}s', name, platform);
      return { match: { source: platform, info: best }, searched: true };
    }
    hilog.info(DOMAIN, TAG, 'no confident match on %{public}s (%{public}d results)',
      platform, results.length);
  }
  return { match: null, searched: searched };
}
