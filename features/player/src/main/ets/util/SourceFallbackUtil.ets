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
  'qs': '汽水',
  'mg': '咪咕'
};

/** 跨平台搜索顺序（排除原平台后按此优先）。 */
// 汽水（qs）也参与跨平台搜索（2026-10-30）
const PLATFORM_FALLBACK_ORDER: string[] = ['tx', 'kw', 'kg', 'mg', 'wy', 'qs'];

/**
 * ★★★ 2026-11-04：**平台别名** —— 脚本常用自己的键声明同一个平台，而我们全仓只用规范 id。
 *
 * 实测（甲方提供的「全豆要[聚合音源] v9.7 修复优化版.js」）：
 * ```js
 * const QISHUI_SOURCE_ID = "qsvip";              // ← 键是 qsvip
 * const QISHUI_SOURCE_NAME = "汽水VIP";
 * sourceConfig[QISHUI_SOURCE_ID] = { qualitys: ["128k","320k","flac","flac24bit"] };
 * ```
 * 它**没有 `qs` 键** ⇒ 不做映射时它对我们恒等于"不支持汽水"，
 * 回退链里 `qs` 只剩 `星海音乐源` 一个候选，那条一挂（实测其后端 `yy.zddyr.top` ECONNREFUSED）
 * 整个汽水平台就被换掉 —— 甲方看到的就是"一直切换酷我"。
 *
 * 规范 id → 脚本可能用的别名键（比较时统一小写）。
 */
const PLATFORM_ALIAS_KEYS: Map<string, string[]> = new Map<string, string[]>();
PLATFORM_ALIAS_KEYS.set('qs', ['qsvip', 'qishui', 'qishuivip', '汽水vip', '汽水']);

/** 判定"这条失败是链路/临时问题"而不是"平台真没这首歌"。 */
function isTransientFailure(reason: string): boolean {
  const r: string = reason.toLowerCase();
  // ★ 2026-11-05：把**引擎/回调层**的失败也算"临时"——它们跟具体平台无关，
  //   以前被当成"该平台不可用"写进 60s 黑名单，一旦整条链都这么失败，
  //   黑名单会把**所有候选**同时封掉 ⇒ 之后每次点播都在 0 次网络请求的情况下瞬间报失败。
  return r.indexOf('2300007') >= 0 || r.indexOf('failed to connect') >= 0 ||
    r.indexOf('timeout') >= 0 || r.indexOf('timed out') >= 0 || r.indexOf('超时') >= 0 ||
    r.indexOf('oserr') >= 0 || r.indexOf('network') >= 0 || r.indexOf('网络') >= 0 ||
    r.indexOf('econnrefused') >= 0 || r.indexOf('引擎未就绪') >= 0 ||
    r.indexOf('not ready') >= 0 || r.indexOf('回调未初始化') >= 0;
}

/**
 * 脚本声明键（`sourceConfig` 的键）→ 我们的规范平台 id；不认识的返回空串。
 * @param declaredKey 例如 `qsvip`、`kw`、`汽水VIP`
 */
function canonicalKeyOf(declaredKey: string): string {
  const k: string = declaredKey.trim().toLowerCase();
  if (k.length === 0) {
    return '';
  }
  if (k === 'kw' || k === 'kg' || k === 'tx' || k === 'wy' || k === 'mg') {
    return k;
  }
  if (k === 'qs') {
    return 'qs';
  }
  const aliases: string[] | undefined = PLATFORM_ALIAS_KEYS.get('qs');
  if (aliases !== undefined && aliases.indexOf(k) >= 0) {
    return 'qs';
  }
  return '';
}

/**
 * @returns 该脚本**实际声明**的、可用来访问 `canon` 平台的键（规范键在前，别名在后）。
 *          空数组 = 该脚本没声明这个平台。
 */
function declaredKeysFor(api: LXUserApiInfo, canon: string): string[] {
  const out: string[] = [];
  const sources: Record<string, LXUserApiSourceInfo> = api.sources;
  if (sources === undefined || sources === null) {
    return out;
  }
  if (sources[canon] !== undefined) {
    out.push(canon);
  }
  const aliases: string[] | undefined = PLATFORM_ALIAS_KEYS.get(canon);
  if (aliases === undefined) {
    return out;
  }
  const keys: string[] = Object.keys(sources);
  for (let i: number = 0; i < keys.length; i++) {
    const key: string = keys[i];
    if (key === canon) {
      continue;
    }
    if (aliases.indexOf(key.trim().toLowerCase()) >= 0) {
      out.push(key);
      appendPlayLog('[回退链] alias ' + key + ' -> ' + canon + ' script=' + api.name);
    }
  }
  return out;
}

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
  /**
   * ★ 显式指定的首选音质档位（下载用）：空串 = 用播放偏好。
   * 下载弹层选了 FLAC 而播放偏好是 128k 时，如果不传它，
   * 回退链会按播放偏好从 128k 起步 —— 用户选的档位被静默忽略。
   */
  preferredQuality: string = '';
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
  /**
   * ★ 2026-11-05：失败原因分类，调用方据此给**准确**提示（以前一律「已尝试全部平台与音源」，
   * 但"零候选"和"候选全失败"是完全不同的两件事，用户看到的却是同一句话）。
   * 取值：`''`（成功）/`engine-not-ready`/`no-candidate`/`all-skipped`/`all-failed`。
   */
  failReason: string = '';
}

const scriptCooldown: Map<string, number> = new Map();

/**
 * ★★★ 2026-11-05（甲方：「勾选好多源，一点播放就瞬间提示失败，之后怎么点都失败」）：
 *   启动/恢复备份后的 `warmUpLxSources()` 会**串行**把每个未上报 sources 的脚本切一遍，
 *   每次最长 8s（10 个脚本就 80s）。它全程在改写 `lxActiveSource`；
 *   这期间用户点播放 ⇒ `switchToScript()` 里"目标音源已被其它流程改写，放弃本次切换"
 *   ⇒ 候选被记 3 分钟冷却 ⇒ **一次网络请求都没发**就瞬间报失败，
 *   而且接下来几分钟内每个候选都在冷却里 ⇒ 继续瞬间失败。
 *   ⇒ 播放解析开始时就**抢占式取消预热**，让它立刻收手。
 */
let warmUpToken: number = 0;

/** 让正在跑的预热尽快退出（播放链路开头调用）。 */
export function cancelWarmUp(): void {
  warmUpToken++;
}

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
  /**
   * ★ 2026-11-04：真正发给脚本的**平台键**（可能≠`platform`）。
   * 例：规范平台 `qs` 在「全豆要」里声明成 `qsvip` ⇒ `platform='qs'`、`scriptPlatform='qsvip'`。
   * 请求时必须发 `scriptPlatform`，而对外的 `outcome.source` 仍用规范 `platform`
   * （否则队列条目会变成应用不认识的平台 id）。
   */
  scriptPlatform: string = '';
}

/**
 * ⑥「声明支持但实际不可用」的 (脚本, 平台) 黑名单 —— **带 TTL**。
 *
 * ★★★ 2026-11-04（甲方：「我这一直切换酷我，没法测试」）：原来是模块级 `Set` + 进程内永不过期。
 *   一次**网络抖动**（实测脚本后端 `yy.zddyr.top` ECONNREFUSED / 2300007）就把
 *   `(星海音乐源, qs)` 永久拉黑 ⇒ 之后**每一首**汽水歌都直接跳到换平台，只有重启 App 才恢复。
 *   现在两条纪律：① 带 60s TTL（到期自动解封）；② **网络类失败不拉黑**。
 */
const blockedPairs: Map<string, number> = new Map<string, number>();
/** 黑名单有效期（毫秒）。 */
const BLOCK_TTL_MS: number = 60000;

function pairKey(scriptId: string, platform: string): string {
  return scriptId + '|' + platform;
}

/** 该 (脚本,平台) 现在是否仍在黑名单有效期内。 */
function isPairBlocked(scriptId: string, platform: string): boolean {
  const at: number | undefined = blockedPairs.get(pairKey(scriptId, platform));
  if (at === undefined) {
    return false;
  }
  if (Date.now() - at >= BLOCK_TTL_MS) {
    blockedPairs.delete(pairKey(scriptId, platform));
    appendPlayLog('[回退链] unblock ' + platform);
    return false;
  }
  return true;
}

/** 记一次失败：网络类失败**永不**拉黑（链路问题 ≠ 平台不可用）。 */
function notePairFailure(scriptId: string, scriptName: string, platform: string, reason: string): void {
  if (isTransientFailure(reason)) {
    appendPlayLog('[回退链] net-fail no-block ' + scriptName + '/' + platform +
      ' ' + reason.substring(0, 60));
    return;
  }
  blockedPairs.set(pairKey(scriptId, platform), Date.now());
  appendPlayLog('[回退链] block ' + scriptName + '/' + platform + ' ' + (BLOCK_TTL_MS / 1000) + 's ' +
    reason.substring(0, 60) + '）');
}

/** 音质档位权重：越大越高。未识别的排最后。 */
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
  // ★★★ 2026-11-05（甲方：「勾选了好多源，一点播放就瞬间提示失败」）：
  //   `getSourceScriptOrder()` 的契约是"空数组 = 未配置 ⇒ 回退为全部已导入脚本"
  //   （见 MusicStoreService 注释），但这里以前**只**按 orderIds 取 ⇒ 只要这个 key
  //   没写过（旧版本升上来、或只在新版设置页勾过但没触发排序落盘），`apis` 就是空数组，
  //   函数直接 return 空链 ⇒ 一次网络请求都不发 ⇒ 「获取播放地址失败，已尝试全部平台与音源」
  //   在几十毫秒内弹出。这正是"瞬间失败"的第一号成因。
  let orderIds: string[] = MusicStoreService.getInstance().getSourceScriptOrder();
  if (orderIds.length === 0) {
    for (let i: number = 0; i < all.length; i++) {
      if (all[i].id !== undefined && all[i].id.length > 0) {
        orderIds.push(all[i].id);
      }
    }
    appendPlayLog('[回退链] no order, use all n=' + orderIds.length);
  }
  const apis: LXUserApiInfo[] = [];
  const missing: string[] = [];
  for (let i: number = 0; i < orderIds.length; i++) {
    let hit: boolean = false;
    for (let j: number = 0; j < all.length; j++) {
      if (all[j].id === orderIds[i]) {
        apis.push(all[j]);
        hit = true;
        break;
      }
    }
    if (!hit) {
      missing.push(orderIds[i]);
    }
  }
  if (missing.length > 0) {
    // 勾选记录里有、已导入列表里没有（脚本被删/换过 id）——记日志，别静默
    appendPlayLog('[回退链] missing ids n=' + missing.length + ' ' +
      missing.slice(0, 3).join(','));
  }
  if (apis.length === 0) {
    appendPlayLog('[回退链] no selected source');
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
  // ★★★ 2026-11-05（甲方：「音源管理里很多源没显示平台行，得手动一个个点一下」）：
  //   `api.sources` 只有脚本**被加载过**才会由 init 上报（`saveApiSources`），
  //   所以"已勾选但从没加载过"的源，`declaredKeysFor()` 返回空 ⇒ 以前直接 `continue` 跳过，
  //   用户勾了 10 个源，真正能进候选的可能只有 1 个（甚至 0 个）⇒ 瞬间失败。
  //   现在：这类"未声明"的源也**允许硬试**（用户音质 + 当前平台），最多 2 个，
  //   排在所有"已声明"候选之后 —— 既不会瞬间失败，也不会让脚本切换次数失控。
  const MAX_UNDECLARED_CANDIDATES: number = 2;
  let undeclaredAdded: number = 0;
  for (let i: number = 0; i < apis.length; i++) {
    if (isPairBlocked(apis[i].id, platform)) {
      appendPlayLog('[回退链] ' + apis[i].name + '/' + platform + ' blocked, skip');
      continue;
    }
    // ★ 2026-11-04：该脚本可能用**别名键**声明这个平台（如 `qsvip`），逐个展开成候选。
    const keys: string[] = declaredKeysFor(apis[i], platform);
    if (keys.length === 0) {
      // 一个都没声明：第一个脚本照旧"用户音质硬试一次"；其余未声明源限量硬试
      const needHardTry: boolean = (firstCandidate && preferredQuality.length > 0) ||
        (undeclaredAdded < MAX_UNDECLARED_CANDIDATES && preferredQuality.length > 0);
      if (needHardTry) {
        const hardTry: FallbackCandidate = new FallbackCandidate();
        hardTry.scriptId = apis[i].id;
        hardTry.scriptName = apis[i].name;
        hardTry.platform = platform;
        hardTry.scriptPlatform = platform;
        hardTry.quality = preferredQuality;
        hardTry.platformSwitched = false;
        out.push(hardTry);
        firstCandidate = false;
        undeclaredAdded++;
        appendPlayLog('[回退链] undeclared, hard-try ' + apis[i].name + '/' + platform);
      }
      continue;
    }
    for (let k: number = 0; k < keys.length; k++) {
      const key: string = keys[k];
      const declaredQ: string = bestQualityFor(declaredOf(apis[i], key), preferredQuality);
      const q: string = (firstCandidate && preferredQuality.length > 0) ? preferredQuality : declaredQ;
      if (q.length === 0) {
        continue;
      }
      firstCandidate = false;
      const cand: FallbackCandidate = new FallbackCandidate();
      cand.scriptId = apis[i].id;
      cand.scriptName = apis[i].name;
      cand.platform = platform;
      cand.scriptPlatform = key;
      cand.quality = q;
      cand.platformSwitched = false;
      out.push(cand);
    }
  }
  // ③ 换平台：先按**平台**聚合出该平台能达到的最高音质，平台之间按这个音质降序；
  //    同一平台内部再按脚本勾选顺序排（甲方口径：哪个平台音质支持最高哪个优先）。
  //    ★ 2026-11-04：脚本键先**归一化**成规范平台 id（`qsvip`→`qs`），否则别的脚本声明了
  //      别名时，同一个平台会被当成两个不同平台，排进"换平台"里。
  const platformBest: string[] = [];
  const platformList: string[] = [];
  for (let i: number = 0; i < apis.length; i++) {
    const keys: string[] = Object.keys(apis[i].sources);
    for (let j: number = 0; j < keys.length; j++) {
      const canon: string = canonicalKeyOf(keys[j]);
      if (canon.length === 0 || canon === platform) {
        continue;
      }
      const q: string = bestQualityFor(declaredOf(apis[i], keys[j]), preferredQuality);
      if (q.length === 0) {
        continue;
      }
      const idx: number = platformList.indexOf(canon);
      if (idx < 0) {
        platformList.push(canon);
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
      const keys: string[] = declaredKeysFor(apis[i], p);
      for (let n: number = 0; n < keys.length; n++) {
        const key: string = keys[n];
        const q: string = bestQualityFor(declaredOf(apis[i], key), preferredQuality);
        if (q.length === 0) {
          continue;
        }
        const cand: FallbackCandidate = new FallbackCandidate();
        cand.scriptId = apis[i].id;
        cand.scriptName = apis[i].name;
        cand.platform = p;
        cand.scriptPlatform = key;
        cand.quality = q;
        cand.platformSwitched = true;
        others.push(cand);
      }
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
    appendPlayLog('[回退链] mg origin, platform-first');
  } else {
    for (let i: number = 0; i < others.length; i++) {
      out.push(others[i]);
    }
  }
  // ★★★ 2026-11-05（"瞬间失败"的第二号成因）：
  //   候选**全部**被黑名单/未声明过滤掉时（`sources` 还没上报、或整批刚被拉黑），
  //   以前就返回空链 ⇒ 0 次请求 ⇒ 立刻报失败。这里兜底放一个"硬试"候选：
  //   优先当前激活脚本，其次第一个勾选脚本，用**用户音质 + 当前平台**硬打一次。
  //   一次真实请求换来的是"要么能播，要么日志里有真实失败原因"，比空链可靠。
  if (out.length === 0) {
    const activeId: string = activeSourceId();
    let pick: LXUserApiInfo | undefined = undefined;
    for (let i: number = 0; i < apis.length; i++) {
      if (activeId.length > 0 && apis[i].id === activeId) {
        pick = apis[i];
        break;
      }
    }
    if (pick === undefined) {
      pick = apis[0];
    }
    if (pick !== undefined && preferredQuality.length > 0) {
      const last: FallbackCandidate = new FallbackCandidate();
      last.scriptId = pick.id;
      last.scriptName = pick.name;
      last.platform = platform;
      last.scriptPlatform = platform;
      last.quality = preferredQuality;
      last.platformSwitched = false;
      out.push(last);
      appendPlayLog('[回退链] empty cands, hard-try ' + pick.name + '/' + platform +
        '/' + preferredQuality);
    }
  }
  const head: string[] = [];
  for (let i: number = 0; i < Math.min(out.length, 6); i++) {
    head.push((out[i].platformSwitched ? '换平台:' : '') + out[i].scriptName + '/' + out[i].platform + '/' + out[i].quality);
  }
  appendPlayLog('[回退链] src=' + platform + ' pref=' + preferredQuality + ' cands=' + out.length + ' -> ' + head.join(' | '));
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
  appendPlayLog('[换音源] switch script -> ' + scriptId);
  const start: number = Date.now();
  // ★ 2026-11-04（用户：一直提示「音源未就绪」）：进入前先记下原 active，
  //   失败（超时）时必须**回滚**——否则 `lxActiveSource` 会停在一个永远 init 不成功的脚本上，
  //   之后每次播放都撞"引擎未就绪"（日志实证：预热完 `active=` 指向最后那个超时脚本）。
  const prevActive: string = activeSourceId();
  AppStorage.setOrCreate('lxActiveSource', scriptId);
  const deadline: number = start + SCRIPT_SWITCH_TIMEOUT_MS;
  let sawReloading: boolean = false;
  while (Date.now() < deadline) {
    if (activeSourceId() !== scriptId) {
      appendPlayLog('[换音源] script changed by other flow, abort');
      return false;
    }
    if (!engineReady()) {
      sawReloading = true;
    } else if (sawReloading) {
      appendPlayLog('[换音源] script ready ' + scriptId);
      return true;
    } else if (Date.now() - start > SCRIPT_RELOAD_GRACE_MS) {
      appendPlayLog('[换音源] no reload signal, treat ready ' + scriptId);
      return true;
    }
    await sleep(SCRIPT_READY_POLL_MS);
  }
  appendPlayLog('[换音源] script load timeout ' + scriptId +
    (prevActive !== scriptId ? ' rollback active -> ' + (prevActive.length > 0 ? prevActive : '(empty)') : ''));
  // 只回滚"本次自己写进去的那个"：若期间被别的流程改写，就别抢回来
  if (activeSourceId() === scriptId) {
    AppStorage.setOrCreate('lxActiveSource', prevActive);
  }
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
      appendPlayLog('[换音源] cooldown skip ' + info.name);
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
    appendPlayLog('[换音源] order: ' + names.join(' → '));
  }
  return ordered;
}

/**
 * 上一轮 `tryQualities` 的失败原因（给黑名单判定用：网络类失败不拉黑）。
 * key = `脚本id|平台键`。
 */
const transients: Map<string, string> = new Map<string, string>();

function lastFailureReason(scriptId: string, scriptPlatform: string): string {
  const r: string | undefined = transients.get(pairKey(scriptId, scriptPlatform));
  return r !== undefined ? r : '';
}

/**
 * 按音质链逐档取址。
 * @param sourceCanonical 我们的**规范平台 id**（`outcome.source` 用它，队列/身份才不会被写坏）
 * @param scriptKey 真正发给脚本的**平台键**（可能是别名，如 `qsvip`）；空串 = 同 `sourceCanonical`
 */
async function tryQualities(sourceCanonical: string, scriptKey: string, songId: string, name: string,
  singer: string, chain: string[], preferred: string, noticeDowngrade: boolean,
  onNotice: ((msg: string) => void) | null, options: FallbackOptions): Promise<UrlResolveOutcome | null> {
  const key: string = scriptKey.length > 0 ? scriptKey : sourceCanonical;
  let lastReason: string = '';
  for (let i: number = 0; i < chain.length; i++) {
    const q: string = chain[i];
    if (options.excludeQuality.length > 0 && q === options.excludeQuality) {
      appendPlayLog('[播放] quality ' + q + ' failed before, skip');
      continue;
    }
    try {
      const url: string = await getLXMusicUrl(key, songId, q, name, singer);
      if (url.length > 0 && (options.excludeUrl.length === 0 || url !== options.excludeUrl)) {
        const outcome: UrlResolveOutcome = new UrlResolveOutcome();
        outcome.url = url;
        outcome.quality = q;
        // ★ 对外永远是**规范平台**（脚本键可能是别名，写进队列会变成应用不认识的 id）
        outcome.source = sourceCanonical;
        outcome.songId = songId;
        outcome.scriptName = activeSourceName();
        if (noticeDowngrade && q !== preferred && onNotice !== null) {
          appendPlayLog('[播放] quality downgrade ' + preferred + ' -> ' + q);
          onNotice('当前音质不可用，已切换 ' + qualityDisplayName(q));
        }
        return outcome;
      }
      if (url.length > 0) {
        appendPlayLog('[播放] quality ' + q + ' same failed url, skip');
      } else {
        appendPlayLog('[播放] quality ' + q + ' no url');
      }
    } catch (e) {
      // ★ 2026-11-04：以前打 `JSON.stringify(e)` 得到 `{}`，真正的 2300007/ECONNREFUSED 全丢了。
      const err: Error = e as Error;
      const msg: string = (err !== undefined && err.message !== undefined && err.message.length > 0)
        ? err.message : JSON.stringify(e);
      lastReason = msg;
      appendPlayLog('[播放] quality ' + q + ' error: ' + msg.substring(0, 200));
      // ★★ 网络类失败（DNS/连接/超时）**与音质档位无关**：再试下一档只是白等。
      //   实测 `2300006 Failed to resolve the host name` 单次要 8.8s，一首歌两档就是 17s+，
      //   再加一个脚本候选 ⇒ 汽水歌要等半分钟才换平台。这里直接跳出音质链。
      if (isTransientFailure(msg)) {
        appendPlayLog('[播放] 网络失败 skip ' + sourceCanonical);
        break;
      }
    }
  }
  transients.set(pairKey(activeSourceId(), key), lastReason);
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
  appendPlayLog('[换平台] search ' + platformName + ': ' + query);
  if (onNotice !== null) {
    onNotice('正在切换到' + platformName + '搜索…');
  }
  let hits: LXSearchSong[] = [];
  try {
    const res = await lxSearch(platform, query, 1, 15);
    hits = res.list;
  } catch (e) {
    appendPlayLog('[换平台] ' + platformName + ' search error: ' + JSON.stringify(e).substring(0, 80));
    return null;
  }
  if (hits.length === 0) {
    appendPlayLog('[换平台] ' + platformName + ' no hit');
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
    appendPlayLog('[换平台] try ' + platformName + '/' + hit.songId + ' ' + hit.name);
    const altOpts: FallbackOptions = new FallbackOptions();
    altOpts.excludeUrl = options.excludeUrl;
    const outcome: UrlResolveOutcome | null = await tryQualities(platform, platform, hit.songId,
      hit.name, hit.singer, chain, altBase, false, null, altOpts);
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
      appendPlayLog('[换平台] ok -> ' + platformName + ' (' + outcome.quality + ')');
      if (onNotice !== null) {
        onNotice('已切换到' + platformName + '播放');
      }
      return outcome;
    }
  }
  appendPlayLog('[换平台] ' + platformName + ' hits but no url');
  return null;
}

/**
 * 原平台失败后，依次到其它音乐平台搜索同名歌曲并尝试播放。
 */
async function tryOtherPlatforms(originSource: string, name: string, singer: string,
  preferred: string, onNotice: ((msg: string) => void) | null,
  options: FallbackOptions): Promise<UrlResolveOutcome | null> {
  if (name.trim().length === 0) {
    appendPlayLog('[换平台] no title, skip');
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
  appendPlayLog('[换平台] all platforms failed');
  return null;
}

export async function resolveMusicUrlWithFallback(source: string, songId: string,
  name: string, singer: string, interval: string,
  onNotice: ((msg: string) => void) | null,
  options?: FallbackOptions): Promise<UrlResolveOutcome> {
  const opts: FallbackOptions = options ?? new FallbackOptions();
  // ★ 2026-11-05：先抢占预热 —— 否则后台预热正在反复改写 `lxActiveSource`，
  //   本次解析的每次 switchToScript 都会被判定"被其它流程改写"而放弃 ⇒ 瞬间失败。
  cancelWarmUp();
  // ★ 2026-11-01（全新安装导入音源后"瞬间"报"获取播放地址失败"）：
  //   根因是脚本引擎（WebView）当时还没 ready，链上每个候选都在 tryQualities 里毫秒级失败 ⇒ 整条链瞬间走完。
  //   解析前先主动等引擎就绪（最多 4s）；超时返回空结果并留下可诊断日志。
  const bootDeadline: number = Date.now() + 4000;
  while (!engineReady() && Date.now() < bootDeadline) {
    await sleep(120);
  }
  if (!engineReady()) {
    appendPlayLog('[换源] engine not ready (4s timeout), abort');
    const noEngine: UrlResolveOutcome = new UrlResolveOutcome();
    noEngine.failReason = 'engine-not-ready';
    return noEngine;
  }
  // ★ 2026-11-01（全新安装"瞬间"失败的第二道保险）：导入过音源但**没有任何脚本被选中**时，
  //   activeSourceId() 为空 ⇒ 回退链拿不到脚本 ⇒ 每个候选毫秒级失败。这里自动选用列表里第一个脚本。
  if (activeSourceId().length === 0) {
    const apisFirst: LXUserApiInfo[] = lxSourceManager.getApiList();
    if (apisFirst.length > 0) {
      const firstScriptId: string = apisFirst[0].id;
      appendPlayLog('[换源] no active source, use first id=' + firstScriptId);
      AppStorage.setOrCreate('lxActiveSource', firstScriptId);
      await switchToScript(firstScriptId);
    }
  }
  const preferred: string = opts.preferredQuality.length > 0 ? opts.preferredQuality
    : await PlaybackPreferenceService.resolveDefaultQuality();
  const activeAtStart: string = activeSourceId();
  // ★ B2/B3 唯一回退链：顺序完全由 buildCandidateChain() 决定（同平台源优先 → 换平台按音质）
  const cands: FallbackCandidate[] = buildCandidateChain(preferred, source);
  // ★ 本次播放"预期使用的脚本"：引擎已加载脚本时就是它；冷启动（未加载任何脚本）时
  //   取回退链第一个候选（= 用户设置的默认音源脚本）。
  //   只有命中脚本**不等于**它，才算真的"切换了音源"，否则不该弹「已切换音源：xxx」。
  const intendedScriptId: string = activeAtStart.length > 0
    ? activeAtStart
    : (cands.length > 0 ? cands[0].scriptId : '');
  if (cands.length === 0) {
    // ★ 2026-11-05：真的一个候选都没有（未导入音源 / 勾选 id 全部对不上） —— 明确区分出来，
    //   别让用户以为是"所有平台都试过了"。
    appendPlayLog('[回退链] no candidate, no request');
    const none: UrlResolveOutcome = new UrlResolveOutcome();
    none.failReason = 'no-candidate';
    return none;
  }
  let attempted: number = 0;
  let skippedCooldown: number = 0;
  for (let i: number = 0; i < cands.length; i++) {
    const c: FallbackCandidate = cands[i];
    if (c.scriptId !== activeSourceId()) {
      if (scriptCooldown.get(c.scriptId) !== undefined && (scriptCooldown.get(c.scriptId) ?? 0) > Date.now()) {
        appendPlayLog('[换音源] ' + c.scriptName + ' cooldown, skip');
        skippedCooldown++;
        continue;
      }
      const loaded: boolean = await switchToScript(c.scriptId);
      if (!loaded) {
        scriptCooldown.set(c.scriptId, Date.now() + SCRIPT_FAIL_COOLDOWN_MS);
        skippedCooldown++;
        continue;
      }
    }
    attempted++;
    const chain: string[] = getQualityChain(c.quality, c.platform);
    const key: string = c.scriptPlatform.length > 0 ? c.scriptPlatform : c.platform;
    appendPlayLog('[回退链] try #' + i + ' ' + c.scriptName + '/' + c.platform +
      (key !== c.platform ? '(脚本键=' + key + ')' : '') + '/' + c.quality +
      ' chain=' + chain.join(' > '));
    const r: UrlResolveOutcome | null = c.platformSwitched
      ? await tryPlatformSearch(c.platform, name, singer, c.quality, onNotice, opts)
      : await tryQualities(c.platform, key, songId, name, singer, chain, c.quality, true, onNotice, opts);
    if (r !== null) {
      // ★ 只有命中脚本**不是**本次预期脚本时，才算真的换了音源（见 intendedScriptId 注释）。
      if (c.scriptId !== intendedScriptId) {
        r.switchedScriptName = c.scriptName;
      }
      appendPlayLog('[回退链] hit ' + c.scriptName + '/' + c.platform +
        (key !== c.platform ? '(脚本键=' + key + ')' : '') + '/' + r.quality);
      // A4：解析成功即证明该 (平台, 音质) 能返回真实音频，写进本次会话的探测缓存
      markProbeOk(c.platform, r.quality);
      return r;
    }
    // ⑥ 这一轮该 (脚本, 平台) 失败：**只在确定性失败时**拉黑；网络类失败不拉黑（带 60s TTL）
    //    ⚠️ 黑名单按**规范平台**记（`qs`），不按脚本键（`qsvip`）—— 否则跳过检查那侧对不上。
    if (!c.platformSwitched) {
      notePairFailure(c.scriptId, c.scriptName, c.platform, lastFailureReason(c.scriptId, key));
    }
  }
  // A4：全部候选都失败 ⇒ 把首选候选标记为"未通过"，ToolTip 立刻能反映出来
  if (cands.length > 0) {
    markProbeFail(cands[0].platform, cands[0].quality, '全部候选失败');
  }
  appendPlayLog('[回退链] all failed cands=' + cands.length + ' tried=' + attempted +
    ' skipped=' + skippedCooldown + ' blocked=' + blockedPairs.size + ' restore origin');
  if (activeAtStart.length > 0) {
    AppStorage.setOrCreate('lxActiveSource', activeAtStart);
  }
  const failed: UrlResolveOutcome = new UrlResolveOutcome();
  // ★ 2026-11-05：区分"一个候选都没真正发出去"（全被冷却/换脚本失败挡掉）和"发了但全失败"。
  failed.failReason = attempted === 0 ? 'all-skipped' : 'all-failed';
  return failed;
}

/**
 * 启动 / 恢复备份后的**音源预热**。
 *
 * 背景（2026-11-01 用户反馈）：音源卡片上"平台那一行"来自脚本 init 上报的 `sources`，
 * 而 `sources` 只有在脚本被**加载**时才会由 `LXSourceEngine` 调 `saveApiSources()` 落盘。
 * 恢复备份后 `lxActiveSource` 可能为空 ⇒ 一个脚本都没加载 ⇒ 所有卡片显示"异常状态"，
 * 必须手动点一下卡片才能恢复。
 *
 * 做法：把 `sources` 为空的音源逐个切过去加载一遍（每次 `switchToScript` 会等引擎 ready，
 * 从而触发 init 上报并落盘），全部走完后恢复用户原来的选中项。
 *
 * 排查关键字：`[换源] 预热`。
 * @returns 实际预热（加载过）的音源数量
 */
export async function warmUpLxSources(): Promise<number> {
  const list: LXUserApiInfo[] = lxSourceManager.getApiList();
  if (list.length === 0) {
    return 0;
  }
  const originalActive: string = activeSourceId();
  const myToken: number = warmUpToken;
  let warmed: number = 0;
  // ★ 2026-11-04：记下**第一个真的就绪**的脚本。原始 active 为空时（全新安装/恢复备份后），
  //   以前预热完不恢复 ⇒ active 停在最后那个"试过但超时"的脚本上 ⇒ 之后每次播放都弹
  //   「音源未就绪」（日志实证：`预热完成 warmed=0 total=10 active=<超时脚本>`）。
  let firstWarmedId: string = '';
  for (let i: number = 0; i < list.length; i++) {
    // ★ 2026-11-05：播放请求已抢占 ⇒ 立刻收手（并把 active 还给用户原来的选择）
    if (warmUpToken !== myToken) {
      appendPlayLog('[换源] 预热被抢占 ' + warmed + '/' + list.length);
      if (originalActive.length > 0) {
        AppStorage.setOrCreate('lxActiveSource', originalActive);
      }
      return warmed;
    }
    const api: LXUserApiInfo = list[i];
    const declared: number = api.sources !== undefined ? Object.keys(api.sources).length : 0;
    if (declared > 0) {
      continue;
    }
    appendPlayLog('[换源] 预热音源 ' + api.name + ' id=' + api.id);
    AppStorage.setOrCreate('lxActiveSource', api.id);
    await sleep(60);
    const ok: boolean = await switchToScript(api.id);
    if (ok) {
      warmed++;
      if (firstWarmedId.length === 0) {
        firstWarmedId = api.id;
      }
    }
  }
  if (originalActive.length > 0 && activeSourceId() !== originalActive) {
    // 用户本来选过：恢复原选中项（哪怕它这次没就绪 —— 那是用户自己的选择）
    AppStorage.setOrCreate('lxActiveSource', originalActive);
    await switchToScript(originalActive);
  } else if (originalActive.length === 0) {
    // 全新/未选过：优先落到**第一个成功**的脚本；一个都没成功就**清空**，
    // 让后续 `resolveMusicUrlWithFallback()` 走它自己的"未选中音源 ⇒ 自动选第一个"兜底，
    // 而不是继续指着一个 init 失败的脚本。
    const pick: string = firstWarmedId.length > 0 ? firstWarmedId : '';
    AppStorage.setOrCreate('lxActiveSource', pick);
    appendPlayLog('[换源] 预热选定 active=' + (pick.length > 0 ? pick : '(空)'));
  }
  appendPlayLog('[换源] 预热完成 warmed=' + warmed + ' total=' + list.length +
    ' active=' + activeSourceId());
  return warmed;
}
