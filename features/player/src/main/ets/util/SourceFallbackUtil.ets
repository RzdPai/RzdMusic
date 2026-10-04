import { MusicStoreService, PlaybackPreferenceService, appendPlayLog } from 'musicbasic';
import { getLXMusicUrl } from '../source/LXPlayHelper';
import { lxSearch, LXSearchSong } from '../source/LXMusicSDK';
import { LXUserApiInfo, LXUserApiSourceInfo } from '../source/Interface';
import { lxSourceManager } from '../source/LXSourceManager';

export const QUALITY_CHAIN: string[] =
  ['master', 'atmos_plus', 'atmos', 'hires', 'flac24bit', 'flac', '320k', '128k'];

export const EXTENDED_QUALITIES: string[] = ['master', 'atmos_plus', 'atmos', 'hires'];

const STANDARD_LADDER: string[] = ['flac24bit', 'flac', '320k', '128k'];

const SOURCE_NAMES: Record<string, string> = {
  'kw': '酷我',
  'kg': '酷狗',
  'tx': 'QQ',
  'wy': '网易云',
  'mg': '咪咕'
};

/** 跨平台搜索顺序（排除原平台后按此优先）。 */
const PLATFORM_FALLBACK_ORDER: string[] = ['tx', 'kw', 'kg', 'mg', 'wy'];

const SCRIPT_SWITCH_TIMEOUT_MS: number = 8000;
const SCRIPT_READY_POLL_MS: number = 150;
const SCRIPT_FAIL_COOLDOWN_MS: number = 3 * 60 * 1000;
const SCRIPT_RELOAD_GRACE_MS: number = 1500;

export class FallbackOptions {
  excludeUrl: string = '';
  excludeQuality: string = '';
  allowScriptSwitch: boolean = true;
  /** 原平台全部失败后，按歌名+歌手到其它平台搜索重试（默认开）。 */
  allowPlatformSwitch: boolean = true;
}

export class UrlResolveOutcome {
  url: string = '';
  quality: string = '';
  source: string = '';
  songId: string = '';
  albumName: string = '';
  img: string = '';
  switched: boolean = false;
  switchedScriptName: string = '';
  scriptName: string = '';
}

const scriptCooldown: Map<string, number> = new Map();

/** 播放页/列表音质徽标展示名 */
export function qualityDisplayName(q: string): string {
  if (q === 'local') {
    return '本地';
  }
  if (q === '128k') {
    return '128K';
  }
  if (q === '192k') {
    return '192K';
  }
  if (q === '320k') {
    return '320K';
  }
  if (q === 'flac') {
    return 'FLAC';
  }
  if (q === 'flac24bit') {
    return 'FLAC 24-bit';
  }
  if (q === 'hires') {
    return 'HiRes';
  }
  if (q === 'atmos') {
    return 'Atmos';
  }
  if (q === 'atmos_plus') {
    return 'Atmos Plus';
  }
  if (q === 'master') {
    return 'Master';
  }
  if (q === 'ape') {
    return 'APE';
  }
  if (q === 'wav') {
    return 'WAV';
  }
  return q;
}

export function sourceDisplayName(source: string): string {
  const name: string = SOURCE_NAMES[source];
  return name === undefined ? source : name;
}

export function qualityTierKey(quality: string, source: string, scriptId: string): string {
  return scriptId + '|' + source + '|' + quality;
}

export const QUALITY_TIER_FAIL_THRESHOLD: number = 2;
export const QUALITY_TIER_COOLDOWN_MS: number = 12 * 60 * 60 * 1000;

export function activeSourceId(): string {
  return AppStorage.get<string>('lxActiveSource') ?? '';
}

export function activeSourceName(): string {
  const activeId: string = activeSourceId();
  try {
    const list: LXUserApiInfo[] = lxSourceManager.getApiList();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === activeId) {
        return list[i].name;
      }
    }
  } catch (_err) {
    return activeId;
  }
  return activeId;
}

function declaredQualitys(source: string): string[] | null {
  try {
    const raw: string = AppStorage.get<string>('lxEngineSources') ?? '';
    if (raw.length === 0 || raw === '{}') {
      return null;
    }
    const map: Record<string, LXUserApiSourceInfo> = JSON.parse(raw) as Record<string, LXUserApiSourceInfo>;
    const info: LXUserApiSourceInfo | undefined = map[source];
    if (info === undefined || info.qualitys === undefined || info.qualitys.length === 0) {
      return null;
    }
    const list: string[] = [];
    for (let i: number = 0; i < info.qualitys.length; i++) {
      list.push(info.qualitys[i]);
    }
    return list;
  } catch (_err) {
    return null;
  }
}

export function getQualityChain(preferred: string, source: string): string[] {
  const ladder: string[] = [];
  const start: number = STANDARD_LADDER.indexOf(preferred);
  for (let i: number = start >= 0 ? start : 0; i < STANDARD_LADDER.length; i++) {
    ladder.push(STANDARD_LADDER[i]);
  }
  const declared: string[] | null = declaredQualitys(source);
  let standard: string[] = ladder;
  if (declared !== null) {
    const filtered: string[] = [];
    for (let i: number = 0; i < ladder.length; i++) {
      if (declared.indexOf(ladder[i]) >= 0) {
        filtered.push(ladder[i]);
      }
    }
    if (filtered.length > 0) {
      standard = filtered;
    }
  }
  const out: string[] = [];
  if (EXTENDED_QUALITIES.indexOf(preferred) >= 0) {
    // Explicit selected tier wins even for downloads; source declaration must not hide this attempt.
    out.push(preferred);
  }
  // Every explicitly requested tier is attempted first, even if a script declaration omits it.
  if (out.indexOf(preferred) < 0 && QUALITY_CHAIN.indexOf(preferred) >= 0) {
    out.unshift(preferred);
  }
  console.info('[RzdQualityPolicy] chain source=' + source + ' preferred=' + preferred +
    ' policy=network-or-explicit');
  for (let i: number = 0; i < standard.length; i++) {
    if (out.indexOf(standard[i]) < 0) {
      out.push(standard[i]);
    }
  }
  return out;
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, ms);
  });
}

function engineReady(): boolean {
  return AppStorage.get<boolean>('lxEngineReady') === true;
}

async function switchToScript(scriptId: string): Promise<boolean> {
  appendPlayLog('[换音源] 切换音源脚本 → ' + scriptId);
  const start: number = Date.now();
  AppStorage.setOrCreate('lxActiveSource', scriptId);
  const deadline: number = start + SCRIPT_SWITCH_TIMEOUT_MS;
  let sawReloading: boolean = false;
  while (Date.now() < deadline) {
    if (activeSourceId() !== scriptId) {
      appendPlayLog('[换音源] 目标音源已被其它流程改写，放弃本次切换');
      return false;
    }
    if (!engineReady()) {
      sawReloading = true;
    } else if (sawReloading) {
      appendPlayLog('[换音源] 音源脚本已就绪 ' + scriptId);
      return true;
    } else if (Date.now() - start > SCRIPT_RELOAD_GRACE_MS) {
      appendPlayLog('[换音源] 音源脚本未观察到重载信号，按就绪处理 ' + scriptId);
      return true;
    }
    await sleep(SCRIPT_READY_POLL_MS);
  }
  appendPlayLog('[换音源] 音源脚本加载超时 ' + scriptId);
  return false;
}

function scriptSupportsPlatform(info: LXUserApiInfo, source: string): boolean {
  const map: Record<string, LXUserApiSourceInfo> | undefined = info.sources;
  if (map === undefined) {
    return false;
  }
  return map[source] !== undefined;
}

function pickScriptCandidates(source: string, currentId: string): LXUserApiInfo[] {
  const now: number = Date.now();
  let list: LXUserApiInfo[] = [];
  try {
    list = lxSourceManager.getApiList();
  } catch (_err) {
    return [];
  }
  const byId: Map<string, LXUserApiInfo> = new Map();
  for (let i: number = 0; i < list.length; i++) {
    if (list[i].id !== undefined && list[i].id.length > 0) {
      byId.set(list[i].id, list[i]);
    }
  }
  // 用户配置的多选顺序；空则用全部导入顺序
  let orderIds: string[] = [];
  try {
    orderIds = MusicStoreService.getInstance().getSourceScriptOrder();
  } catch (_e) {
    orderIds = [];
  }
  if (orderIds.length === 0) {
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== undefined && list[i].id.length > 0) {
        orderIds.push(list[i].id);
      }
    }
  }
  // 从当前音源之后按顺序轮转，保证「第一个失败再试下一个」
  const rotated: string[] = [];
  let start: number = orderIds.indexOf(currentId);
  if (start < 0) {
    start = -1;
  }
  for (let i: number = start + 1; i < orderIds.length; i++) {
    rotated.push(orderIds[i]);
  }
  for (let i: number = 0; i < start; i++) {
    rotated.push(orderIds[i]);
  }
  const ordered: LXUserApiInfo[] = [];
  for (let i: number = 0; i < rotated.length; i++) {
    const id: string = rotated[i];
    if (id === currentId) {
      continue;
    }
    const info: LXUserApiInfo | undefined = byId.get(id);
    if (info === undefined) {
      continue;
    }
    const until: number | undefined = scriptCooldown.get(id);
    if (until !== undefined && until > now) {
      appendPlayLog('[换音源] 跳过冷却中的音源 ' + info.name);
      continue;
    }
    ordered.push(info);
  }
  // 日志标明调用顺序
  if (ordered.length > 0) {
    const names: string[] = [];
    for (let i: number = 0; i < ordered.length; i++) {
      names.push(ordered[i].name);
    }
    appendPlayLog('[换音源] 依次候选: ' + names.join(' → '));
  }
  return ordered;
}

async function tryQualities(source: string, songId: string, name: string, singer: string,
  chain: string[], preferred: string, noticeDowngrade: boolean,
  onNotice: ((msg: string) => void) | null, options: FallbackOptions): Promise<UrlResolveOutcome | null> {
  for (let i: number = 0; i < chain.length; i++) {
    const q: string = chain[i];
    if (options.excludeQuality.length > 0 && q === options.excludeQuality) {
      appendPlayLog('[播放] 音质 ' + q + ' 上次已失败，跳过');
      continue;
    }
    try {
      const url: string = await getLXMusicUrl(source, songId, q, name, singer);
      if (url.length > 0 && (options.excludeUrl.length === 0 || url !== options.excludeUrl)) {
        const outcome: UrlResolveOutcome = new UrlResolveOutcome();
        outcome.url = url;
        outcome.quality = q;
        outcome.source = source;
        outcome.songId = songId;
        outcome.scriptName = activeSourceName();
        if (noticeDowngrade && q !== preferred && onNotice !== null) {
          appendPlayLog('[播放] 音质降级 ' + preferred + ' -> ' + q);
          onNotice('当前音质不可用，已切换 ' + qualityDisplayName(q));
        }
        return outcome;
      }
      if (url.length > 0) {
        appendPlayLog('[播放] 音质 ' + q + ' 返回上次失败地址，跳过');
      } else {
        appendPlayLog('[播放] 音质 ' + q + ' 无地址');
      }
    } catch (e) {
      appendPlayLog('[播放] 音质 ' + q + ' 异常: ' + JSON.stringify(e).substring(0, 80));
    }
  }
  return null;
}


function normalizeMatchText(s: string): string {
  let t: string = s.trim().toLowerCase();
  // 去掉常见括号附注，提高同名匹配率
  t = t.replace(/\(.*?\)/g, ' ').replace(/（.*?）/g, ' ');
  t = t.replace(/\s+/g, ' ').trim();
  return t;
}

/** 歌名+歌手与搜索结果的匹配分，越高越好；0 表示不合格。 */
function scoreSearchHit(song: LXSearchSong, name: string, singer: string): number {
  const n: string = normalizeMatchText(name);
  const s: string = normalizeMatchText(singer);
  const sn: string = normalizeMatchText(song.name);
  const ss: string = normalizeMatchText(song.singer);
  if (n.length === 0 || sn.length === 0) {
    return 0;
  }
  let score: number = 0;
  if (sn === n) {
    score += 100;
  } else if (sn.indexOf(n) >= 0 || n.indexOf(sn) >= 0) {
    score += 60;
  } else {
    return 0;
  }
  if (s.length > 0 && ss.length > 0) {
    if (ss === s) {
      score += 40;
    } else if (ss.indexOf(s) >= 0 || s.indexOf(ss) >= 0) {
      score += 20;
    }
  }
  return score;
}

/**
 * 在指定平台按歌名+歌手搜索，取匹配分最高且可解析出播放地址的结果。
 */
async function tryPlatformSearch(platform: string, name: string, singer: string,
  preferred: string, onNotice: ((msg: string) => void) | null,
  options: FallbackOptions): Promise<UrlResolveOutcome | null> {
  const query: string = (name + ' ' + singer).trim();
  if (query.length === 0) {
    return null;
  }
  const platformName: string = sourceDisplayName(platform);
  appendPlayLog('[换平台] 在 ' + platformName + ' 搜索: ' + query);
  if (onNotice !== null) {
    onNotice('正在切换到' + platformName + '搜索…');
  }
  let hits: LXSearchSong[] = [];
  try {
    const res = await lxSearch(platform, query, 1, 15);
    hits = res.list;
  } catch (e) {
    appendPlayLog('[换平台] ' + platformName + ' 搜索异常: ' + JSON.stringify(e).substring(0, 80));
    return null;
  }
  if (hits.length === 0) {
    appendPlayLog('[换平台] ' + platformName + ' 无搜索结果');
    return null;
  }
  // 按匹配分排序，优先精确同名
  const ranked: LXSearchSong[] = [];
  const scores: number[] = [];
  for (let i: number = 0; i < hits.length; i++) {
    const sc: number = scoreSearchHit(hits[i], name, singer);
    if (sc <= 0) {
      continue;
    }
    ranked.push(hits[i]);
    scores.push(sc);
  }
  // 简单选择排序（分高在前）
  for (let i: number = 0; i < ranked.length; i++) {
    for (let j: number = i + 1; j < ranked.length; j++) {
      if (scores[j] > scores[i]) {
        const ts: number = scores[i];
        scores[i] = scores[j];
        scores[j] = ts;
        const th: LXSearchSong = ranked[i];
        ranked[i] = ranked[j];
        ranked[j] = th;
      }
    }
  }
  // 无合格匹配时仍试第一首（宽松兜底）
  const candidates: LXSearchSong[] = ranked.length > 0 ? ranked : [hits[0]];
  const chain: string[] = getQualityChain(preferred, platform);
  const altBase: string = chain.length > 0 ? chain[0] : preferred;
  const tryCount: number = Math.min(candidates.length, 5);
  for (let i: number = 0; i < tryCount; i++) {
    const hit: LXSearchSong = candidates[i];
    if (hit.songId.length === 0) {
      continue;
    }
    appendPlayLog('[换平台] 尝试 ' + platformName + '/' + hit.songId + ' 「' + hit.name + '」');
    const altOpts: FallbackOptions = new FallbackOptions();
    altOpts.excludeUrl = options.excludeUrl;
    const outcome: UrlResolveOutcome | null = await tryQualities(platform, hit.songId, hit.name, hit.singer,
      chain, altBase, false, null, altOpts);
    if (outcome !== null) {
      outcome.switched = true;
      outcome.source = platform;
      outcome.songId = hit.songId;
      if (hit.albumName.length > 0) {
        outcome.albumName = hit.albumName;
      }
      if (hit.img.length > 0) {
        outcome.img = hit.img;
      }
      appendPlayLog('[换平台] 成功 → ' + platformName + ' (' + outcome.quality + ')');
      if (onNotice !== null) {
        onNotice('已切换到' + platformName + '播放');
      }
      return outcome;
    }
  }
  appendPlayLog('[换平台] ' + platformName + ' 搜索到歌曲但均无法解析地址');
  return null;
}

/**
 * 原平台失败后，依次到其它音乐平台搜索同名歌曲并尝试播放。
 */
async function tryOtherPlatforms(originSource: string, name: string, singer: string,
  preferred: string, onNotice: ((msg: string) => void) | null,
  options: FallbackOptions): Promise<UrlResolveOutcome | null> {
  if (name.trim().length === 0) {
    appendPlayLog('[换平台] 无歌名，无法跨平台搜索');
    return null;
  }
  for (let i: number = 0; i < PLATFORM_FALLBACK_ORDER.length; i++) {
    const platform: string = PLATFORM_FALLBACK_ORDER[i];
    if (platform === originSource) {
      continue;
    }
    const outcome: UrlResolveOutcome | null = await tryPlatformSearch(platform, name, singer,
      preferred, onNotice, options);
    if (outcome !== null) {
      return outcome;
    }
  }
  appendPlayLog('[换平台] 全部平台均无法加载');
  return null;
}

export async function resolveMusicUrlWithFallback(source: string, songId: string,
  name: string, singer: string, interval: string,
  onNotice: ((msg: string) => void) | null,
  options?: FallbackOptions): Promise<UrlResolveOutcome> {
  const opts: FallbackOptions = options ?? new FallbackOptions();
  const preferred: string = await PlaybackPreferenceService.resolveDefaultQuality();
  const currentId: string = activeSourceId();
  const chain: string[] = getQualityChain(preferred, source);
  appendPlayLog('[播放] 音质链(' + sourceDisplayName(source) + '): ' + chain.join(' > '));
  const noticeBase: string = chain.length > 0 ? chain[0] : preferred;
  const outcome: UrlResolveOutcome | null = await tryQualities(source, songId, name, singer,
    chain, noticeBase, true, onNotice, opts);
  if (outcome !== null) {
    return outcome;
  }
  // —— 跨平台：原平台（如网易）全部音质失败后，按歌名到 QQ/酷我/酷狗/咪咕 等搜索 ——
  if (opts.allowPlatformSwitch) {
    appendPlayLog('[换平台] 原平台 ' + sourceDisplayName(source) + ' 失败，开始跨平台搜索');
    const cross: UrlResolveOutcome | null = await tryOtherPlatforms(source, name, singer,
      preferred, onNotice, opts);
    if (cross !== null) {
      return cross;
    }
  } else {
    appendPlayLog('[换平台] 已关闭跨平台搜索');
  }

  if (!opts.allowScriptSwitch) {
    appendPlayLog('[换音源] 已关闭自动换音源脚本');
    return new UrlResolveOutcome();
  }
  if (currentId.length === 0) {
    appendPlayLog('[换音源] 当前无可用音源脚本');
    return new UrlResolveOutcome();
  }
  appendPlayLog('[换音源] 跨平台仍失败，尝试更换音源脚本（仍用原平台 id）');
  const candidates: LXUserApiInfo[] = pickScriptCandidates(source, currentId);
  for (let i: number = 0; i < candidates.length; i++) {
    const info: LXUserApiInfo = candidates[i];
    const loaded: boolean = await switchToScript(info.id);
    if (!loaded) {
      scriptCooldown.set(info.id, Date.now() + SCRIPT_FAIL_COOLDOWN_MS);
      continue;
    }
    const altChain: string[] = getQualityChain(preferred, source);
    appendPlayLog('[换音源] 音质链(' + info.name + '): ' + altChain.join(' > '));
    const altBase: string = altChain.length > 0 ? altChain[0] : preferred;
    const altOpts: FallbackOptions = new FallbackOptions();
    const altOutcome: UrlResolveOutcome | null = await tryQualities(source, songId, name, singer,
      altChain, altBase, false, null, altOpts);
    if (altOutcome !== null) {
      altOutcome.switchedScriptName = info.name;
      appendPlayLog('[换音源] 成功 ' + source + ' via ' + info.name + ' (' + altOutcome.quality + ')');
      if (onNotice !== null) {
        onNotice('当前音源不可用，已切换音源：' + info.name);
      }
      return altOutcome;
    }
    // 换脚本后再做一轮跨平台
    if (opts.allowPlatformSwitch) {
      const cross2: UrlResolveOutcome | null = await tryOtherPlatforms(source, name, singer,
        preferred, onNotice, altOpts);
      if (cross2 !== null) {
        cross2.switchedScriptName = info.name;
        return cross2;
      }
    }
    appendPlayLog('[换音源] 音源 ' + info.name + ' 解析失败');
    scriptCooldown.set(info.id, Date.now() + SCRIPT_FAIL_COOLDOWN_MS);
  }
  appendPlayLog('[换音源] 全部音源脚本与平台均失败，恢复原音源');
  AppStorage.setOrCreate('lxActiveSource', currentId);
  return new UrlResolveOutcome();
}
