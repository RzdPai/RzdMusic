import { MusicStoreService, appendPlayLog } from 'musicbasic';
import { getLXMusicUrl } from '../source/LXPlayHelper';
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

const SCRIPT_SWITCH_TIMEOUT_MS: number = 8000;
const SCRIPT_READY_POLL_MS: number = 150;
const SCRIPT_FAIL_COOLDOWN_MS: number = 3 * 60 * 1000;
const SCRIPT_RELOAD_GRACE_MS: number = 1500;

export class FallbackOptions {
  excludeUrl: string = '';
  excludeQuality: string = '';
  allowScriptSwitch: boolean = true;
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
  const store: MusicStoreService = MusicStoreService.getInstance();
  const extendedEnabled: boolean = (AppStorage.get<boolean>('lxExtendedEnabled') ?? false) ||
    store.getPlayExtendedEnabled();
  const liveQuality: string = AppStorage.get<string>('lxExtendedQuality') ?? '';
  const extendedQuality: string = liveQuality.length > 0 ? liveQuality : store.getPlayExtendedQuality();
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
  if (extendedEnabled && extendedQuality.length > 0) {
    out.push(extendedQuality);
  }
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
  const support: LXUserApiInfo[] = [];
  const others: LXUserApiInfo[] = [];
  let list: LXUserApiInfo[] = [];
  try {
    list = lxSourceManager.getApiList();
  } catch (_err) {
    return [];
  }
  for (let i: number = 0; i < list.length; i++) {
    const info: LXUserApiInfo = list[i];
    if (info.id === undefined || info.id.length === 0 || info.id === currentId) {
      continue;
    }
    const until: number | undefined = scriptCooldown.get(info.id);
    if (until !== undefined && until > now) {
      appendPlayLog('[换音源] 跳过冷却中的音源 ' + info.name);
      continue;
    }
    if (scriptSupportsPlatform(info, source)) {
      support.push(info);
    } else {
      others.push(info);
    }
  }
  const ordered: LXUserApiInfo[] = [];
  for (let i: number = 0; i < support.length; i++) {
    ordered.push(support[i]);
  }
  for (let i: number = 0; i < others.length; i++) {
    ordered.push(others[i]);
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
          onNotice('当前音质不可用，已切换 ' + q);
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

export async function resolveMusicUrlWithFallback(source: string, songId: string,
  name: string, singer: string, interval: string,
  onNotice: ((msg: string) => void) | null,
  options?: FallbackOptions): Promise<UrlResolveOutcome> {
  const opts: FallbackOptions = options ?? new FallbackOptions();
  const preferred: string = AppStorage.get<string>('lxPlayQuality') ?? '128k';
  const currentId: string = activeSourceId();
  const chain: string[] = getQualityChain(preferred, source);
  appendPlayLog('[播放] 音质链(' + sourceDisplayName(source) + '): ' + chain.join(' > '));
  const noticeBase: string = chain.length > 0 ? chain[0] : preferred;
  const outcome: UrlResolveOutcome | null = await tryQualities(source, songId, name, singer,
    chain, noticeBase, true, onNotice, opts);
  if (outcome !== null) {
    return outcome;
  }
  if (!opts.allowScriptSwitch) {
    appendPlayLog('[换音源] 已关闭自动换音源');
    return new UrlResolveOutcome();
  }
  if (currentId.length === 0) {
    appendPlayLog('[换音源] 当前无可用音源脚本');
    return new UrlResolveOutcome();
  }
  appendPlayLog('[换音源] 当前音源 ' + sourceDisplayName(source) + ' 全部音质失败，尝试更换音源脚本');
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
    appendPlayLog('[换音源] 音源 ' + info.name + ' 解析失败');
    scriptCooldown.set(info.id, Date.now() + SCRIPT_FAIL_COOLDOWN_MS);
  }
  appendPlayLog('[换音源] 全部音源脚本均失败，恢复原音源');
  AppStorage.setOrCreate('lxActiveSource', currentId);
  return new UrlResolveOutcome();
}
