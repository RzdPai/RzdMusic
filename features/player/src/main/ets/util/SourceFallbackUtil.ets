import { MusicStoreService, PlaybackPreferenceService, appendPlayLog } from 'musicbasic';
import { getLXMusicUrl } from '../source/LXPlayHelper';
import { lxSearch, LXSearchSong } from '../source/LXMusicSDK';
import { LXUserApiInfo, LXUserApiSourceInfo } from '../source/Interface';
import { lxSourceManager } from '../source/LXSourceManager';
import { markProbeFail, markProbeOk } from './LxQualityProbe';

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

/** 回退链上的一条候选：用哪个音源脚本、在哪个平台、用哪个音质。 */
export class FallbackCandidate {
  /** 音源脚本 id。 */
  scriptId: string = '';
  /** 音源脚本名（日志/提示用）。 */
  scriptName: string = '';
  /** 平台 id（`kw` / `tx` / …）。 */
  platform: string = '';
  /** 音质（`320k` / `flac` / …）。 */
  quality: string = '';
  /** 是否换过平台（相对入参平台）。 */
  platformSwitched: boolean = false;
}

/** 音质档位权重：越大越高。未识别的排最后。 */
/** ⑥「声明支持但实际不可用」的 (脚本, 平台) 会话级黑名单。 */
const blockedPairs: Set<string> = new Set();

function pairKey(scriptId: string, platform: string): string {
  return scriptId + '|' + platform;
}

function qualityWeight(quality: string): number {
  const order: string[] = ['128k', '192k', '320k', 'flac', 'flac24bit', 'hires', 'atmos', 'master'];
  const i: number = order.indexOf(quality);
  return i < 0 ? -1 : i;
}

/** 某个脚本在某个平台声明的"最高可用音质"：优先取 ≤ 偏好档的最高，否则取该平台最高。 */
function bestQualityFor(declared: string[], preferred: string): string {
  if (declared.length === 0) {
    return '';
  }
  let best: string = '';
  let bestWeight: number = -1;
  let atOrBelow: string = '';
  let atOrBelowWeight: number = -1;
  const prefWeight: number = qualityWeight(preferred);
  for (let i: number = 0; i < declared.length; i++) {
    const w: number = qualityWeight(declared[i]);
    if (w > bestWeight) {
      bestWeight = w;
      best = declared[i];
    }
    if (w >= 0 && (prefWeight < 0 || w <= prefWeight) && w > atOrBelowWeight) {
      atOrBelowWeight = w;
      atOrBelow = declared[i];
    }
  }
  return atOrBelow.length > 0 ? atOrBelow : best;
}

/**
 * ★ B2 唯一回退链：按"勾选顺序 → 同平台其它源 → 换平台"产出有序候选。
 *
 * 规则（与甲方口径一致）：
 * 1. 第一个启用的音源 + 当前平台，取"该源在此平台支持的最高音质（不超过偏好档）"；
 * 2. 该源不支持当前平台 ⇒ 依次尝试其余启用源在当前平台的最高音质；
 * 3. 没有任何源支持当前平台 ⇒ 换平台：其余源支持的平台按"最高音质"降序，逐个排进候选；
 * 4. 播放与下载都只调这一个函数（下载侧不得另写一份）。
 */
export function buildCandidateChain(preferredQuality: string, platform: string): FallbackCandidate[] {
  const out: FallbackCandidate[] = [];
  const all: LXUserApiInfo[] = lxSourceManager.getApiList();
  if (all.length === 0) {
    return out;
  }
  // ① 只用**已勾选**的音源，且按用户勾选顺序（第一个=默认源）
  const orderIds: string[] = MusicStoreService.getInstance().getSourceScriptOrder();
  const apis: LXUserApiInfo[] = [];
  if (orderIds.length > 0) {
    for (let i: number = 0; i < orderIds.length; i++) {
      for (let j: number = 0; j < all.length; j++) {
        if (all[j].id === orderIds[i]) {
          apis.push(all[j]);
          break;
        }
      }
    }
  }
  if (apis.length === 0) {
    appendPlayLog('[回退链] 没有勾选任何音源，直接返回');
    return out;
  }
  const declaredOf = (api: LXUserApiInfo, p: string): string[] => {
    const info: LXUserApiSourceInfo | undefined = api.sources[p];
    if (info === undefined) {
      return [];
    }
    const list: string[] = [];
    for (let i: number = 0; i < info.qualitys.length; i++) {
      const q: string = info.qualitys[i];
      if (q.length > 0) {
        list.push(q);
      }
    }
    return list;
  };
  // ① + ② 同平台：按脚本顺序，各自取最高可用音质
  // ★ 用户 2026-10-28：**起播先用用户选择的音质**。
  //   源里的「拓展音质」（master/atmos/hires…）不是原版洛雪的编码定义，脚本声明的档位常偏低，
  //   声明式取档会把本来能播的档位直接跳过。所以第一个候选一律从"用户音质"起步，
  //   由 getQualityChain 负责逐档降级；后续候选（换源/换平台）才按声明取档。
  let firstCandidate: boolean = true;
  for (let i: number = 0; i < apis.length; i++) {
    if (blockedPairs.has(pairKey(apis[i].id, platform))) {
      continue;
    }
    const declaredQ: string = bestQualityFor(declaredOf(apis[i], platform), preferredQuality);
    const q: string = (firstCandidate && preferredQuality.length > 0) ? preferredQuality : declaredQ;
    if (q.length > 0) {
      firstCandidate = false;
    }
    if (q.length > 0) {
      const cand: FallbackCandidate = new FallbackCandidate();
      cand.scriptId = apis[i].id;
      cand.scriptName = apis[i].name;
      cand.platform = platform;
      cand.quality = q;
      cand.platformSwitched = false;
      out.push(cand);
    }
  }
  // ③ 换平台：先按**平台**聚合出该平台能达到的最高音质，平台之间按这个音质降序；
  //    同一平台内部再按脚本勾选顺序排（甲方口径：哪个平台音质支持最高哪个优先）。
  const platformBest: string[] = [];
  const platformList: string[] = [];
  for (let i: number = 0; i < apis.length; i++) {
    const platforms: string[] = Object.keys(apis[i].sources);
    for (let j: number = 0; j < platforms.length; j++) {
      const p: string = platforms[j];
      if (p === platform) {
        continue;
      }
      const q: string = bestQualityFor(declaredOf(apis[i], p), preferredQuality);
      if (q.length === 0) {
        continue;
      }
      const idx: number = platformList.indexOf(p);
      if (idx < 0) {
        platformList.push(p);
        platformBest.push(q);
      } else if (qualityWeight(q) > qualityWeight(platformBest[idx])) {
        platformBest[idx] = q;
      }
    }
  }
  const order: number[] = [];
  for (let i: number = 0; i < platformList.length; i++) {
    order.push(i);
  }
  order.sort((a: number, b: number): number =>
    qualityWeight(platformBest[b]) - qualityWeight(platformBest[a]));
  const others: FallbackCandidate[] = [];
  for (let k: number = 0; k < order.length; k++) {
    const p: string = platformList[order[k]];
    for (let i: number = 0; i < apis.length; i++) {
      const q: string = bestQualityFor(declaredOf(apis[i], p), preferredQuality);
      if (q.length === 0) {
        continue;
      }
      const cand: FallbackCandidate = new FallbackCandidate();
      cand.scriptId = apis[i].id;
      cand.scriptName = apis[i].name;
      cand.platform = p;
      cand.quality = q;
      cand.platformSwitched = true;
      others.push(cand);
    }
  }
  // ③ 咪咕几乎没源支持 ⇒ 先把"换平台"排前面，同平台换源排后面
  if (platform === 'mg' && others.length > 0) {
    const merged: FallbackCandidate[] = [];
    for (let i: number = 0; i < others.length; i++) {
      merged.push(others[i]);
    }
    for (let i: number = 0; i < out.length; i++) {
      merged.push(out[i]);
    }
    out.length = 0;
    for (let i: number = 0; i < merged.length; i++) {
      out.push(merged[i]);
    }
    appendPlayLog('[回退链] 起点是咪咕 ⇒ 优先换平台');
  } else {
    for (let i: number = 0; i < others.length; i++) {
      out.push(others[i]);
    }
  }
  const head: string[] = [];
  for (let i: number = 0; i < Math.min(out.length, 6); i++) {
    head.push((out[i].platformSwitched ? '换平台:' : '') + out[i].scriptName + '/' + out[i].platform + '/' + out[i].quality);
  }
  appendPlayLog('[回退链] 起点=' + platform + ' 偏好=' + preferredQuality + ' 候选=' + out.length + ' → ' + head.join(' | '));
  return out;
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
  const originId: string = activeSourceId();
  // ★ B2/B3 唯一回退链：顺序完全由 buildCandidateChain() 决定（同平台源优先 → 换平台按音质）
  const cands: FallbackCandidate[] = buildCandidateChain(preferred, source);
  for (let i: number = 0; i < cands.length; i++) {
    const c: FallbackCandidate = cands[i];
    if (c.scriptId !== activeSourceId()) {
      if (scriptCooldown.get(c.scriptId) !== undefined && (scriptCooldown.get(c.scriptId) ?? 0) > Date.now()) {
        appendPlayLog('[换音源] ' + c.scriptName + ' 冷却中，跳过');
        continue;
      }
      const loaded: boolean = await switchToScript(c.scriptId);
      if (!loaded) {
        scriptCooldown.set(c.scriptId, Date.now() + SCRIPT_FAIL_COOLDOWN_MS);
        continue;
      }
    }
    const chain: string[] = getQualityChain(c.quality, c.platform);
    appendPlayLog('[回退链] 试 #' + i + ' ' + c.scriptName + '/' + c.platform + '/' + c.quality +
      ' 链路=' + chain.join(' > '));
    const r: UrlResolveOutcome | null = c.platformSwitched
      ? await tryPlatformSearch(c.platform, name, singer, c.quality, onNotice, opts)
      : await tryQualities(c.platform, songId, name, singer, chain, c.quality, true, onNotice, opts);
    if (r !== null) {
      // ★ 只有在**真正换了脚本**时才标记 switchedScriptName：
      //   命中用户自己设置的默认音源时不该弹「已切换音源：<默认源>」。
      if (c.scriptId !== originId) {
        r.switchedScriptName = c.scriptName;
      }
      appendPlayLog('[回退链] 命中 ' + c.scriptName + '/' + c.platform + '/' + r.quality);
      // A4：解析成功即证明该 (平台, 音质) 能返回真实音频，写进本次会话的探测缓存
      markProbeOk(c.platform, r.quality);
      return r;
    }
    // ⑥ 该 (脚本, 平台) 这一轮解析失败 ⇒ 会话内拉黑，后续不再浪费时间
    blockedPairs.add(pairKey(c.scriptId, c.platform));
    appendPlayLog('[回退链] 拉黑 ' + c.scriptName + '/' + c.platform);
  }
  // A4：全部候选都失败 ⇒ 把首选候选标记为"未通过"，ToolTip 立刻能反映出来
  if (cands.length > 0) {
    markProbeFail(cands[0].platform, cands[0].quality, '全部候选失败');
  }
  appendPlayLog('[回退链] 全部候选失败，恢复原音源');
  if (originId.length > 0) {
    AppStorage.setOrCreate('lxActiveSource', originId);
  }
  return new UrlResolveOutcome();
}