import { LXSourceRequestData, LXMusicUrlResult, LXLyricResult, LXPicResult, LXSource, toLXSource, toLXSourceKey } from './Interface';
import { lxEngineSendRequest, lxEngineRegisterPromise, lxEngineIsReady, lxLastRequestData,
  scriptCanRunWithoutWebView, lxEngineEnsureWebView } from './LXSourceEngine';
import { lxSearch, lxLeaderboard, LXSearchSong } from './LXMusicSDK';
import { lxSourceManager } from './LXSourceManager';
import { isMfOnlyPlatform, mfGetLyric, mfGetMediaSource, mfGetSheetSongs, mfSearch, musicFreeApisForPlatform } from './MusicFreeAdapter';
import { isLxPlatform, isMfPlatformId } from '../util/SourceDeclaredInfo';
import { LXUserApiInfo } from './Interface';
import { qsBoardSongs, qsPlaylistDetail } from '../geuz/QsApi';
import {AppStorageKeys,  appendError, appendPlayLog, MusicStoreService } from 'musicbasic';
import { QuickJsScriptSession, runScriptInQuickJs, runScriptAndInvoke, QuickJsRunResult, QuickJsInvokeResult } from './LxHostBridge';
import { quickJsSelfTest } from './QuickJsRuntime';
import { lxLastInitTotalMs } from './LXSourceEngine';

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
 *
 * 这是 id 标准化的**唯一真源**：在线导入 / 歌单迁移 / 播放队列等任何入口存入的
 * 非本源标准 id（酷狗数字 id、kw 的 MUSIC_ 前缀、网易旧导出空 id）都在这里最终
 * 转换，且只在真正要播放那首歌时才发生。导入期不再做任何转换或网络请求。
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
 * 播放前统一把 id 转成各源播放要求的标准形态（**唯一真源**）：
 * · 酷狗数字/其它形式 id → 32 位 Hash（按歌名+歌手搜索补齐）；
 * · 酷我带 MUSIC_ 前缀的旧导出 → 去前缀；
 * · 网易旧导出的空 id → 按歌名+歌手搜索补齐。
 * 其余源原样返回。
 *
 * 空 id 的缓存 key 必须带上歌名与歌手：否则所有缺 id 的歌会共用 `wy|`，互相污染。
 * 搜索失败时保持原值且**不写缓存**，避免一次失败导致该首歌永久失败。
 */
export async function resolvePlayableSongId(source: string, songId: string, name?: string,
  singer?: string): Promise<string> {
  const cacheKey: string = songId.length === 0
    ? source + '|' + (name ?? '') + '|' + (singer ?? '')
    : source + '|' + songId;
  const cached: string | undefined = playableIdCache.get(cacheKey);
  if (cached !== undefined) {
    return cached;
  }
  let resolved: string = songId;
  if (songId.length === 0 && source === 'wy') {
    const query: string = ((name ?? '') + ' ' + (singer ?? '')).trim();
    if (query.length > 0) {
      try {
        const res = await lxSearch('wy', query, 1, 10);
        if (res.list.length > 0 && res.list[0].songId.length > 0) {
          resolved = res.list[0].songId;
        }
      } catch (_err) {
        // 搜索失败保持空 id，由上层走正常的失败流程
      }
    }
  } else if (source === 'kg' && !isKgHash(songId)) {
    const hash: string = await resolveKgHash(name ?? '', singer ?? '');
    if (hash.length > 0) {
      resolved = hash;
    }
  } else if (source === 'kw' && songId.startsWith('MUSIC_')) {
    resolved = songId.substring(6);
  }
  // 只缓存成功结果：搜索失败留空以便下次重试，也避免脏 id 被永久固化
  if (resolved.length > 0) {
    playableIdCache.set(cacheKey, resolved);
  }
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

/**
 * 该平台可用的 MusicFree 音源（已按用户启用状态过滤）。
 *
 * ★ 只在**需要兜底时**才查：MusicFree 插件要现加载（重载页面 + 注入），
 *   不能因为"列表里有 mf 源"就让每次播放都多绕一圈。
 */
function enabledMusicFreeApis(source: string): LXUserApiInfo[] {
  // ★ 2026-11-09：播放只按**平台**找插件（`mfplat:` 精确匹配；洛雪六平台按插件声明的
  //   platform / 名字匹配），不看「平台管理里勾没勾」—— 勾选决定的是搜索 / 广场要不要显示；
  //   已经进了歌单 / 历史的歌，用户主动播时不能因为平台栏被取消勾选就放不出来。
  return musicFreeApisForPlatform(source, lxSourceManager.getApiList());
}

/** 逐个别 MusicFree 源试播放地址；全失败返回空串（不抛，让调用方决定报哪个错）。 */
async function tryMusicFreeUrl(source: string, songId: string, quality: string, name?: string,
  singer?: string): Promise<string> {
  const apis: LXUserApiInfo[] = enabledMusicFreeApis(source);
  if (apis.length > 0) {
    // 兜底：极端路径（通知栏/桌面快捷方式冷启动直接播）可能还没走到首页宿主，
    // 先把「需要 mf 运行时」置位，宿主组件随之挂载。
    AppStorage.setOrCreate(AppStorageKeys.MF_ENGINE_NEEDED, true);
  }
  for (let i: number = 0; i < apis.length; i++) {
    try {
      const url: string = await mfGetMediaSource(apis[i], songId, quality, name, singer);
      if (url.length > 0) {
        logError('[mf] ' + source + ' 命中 ' + apis[i].name);
        return url;
      }
    } catch (err) {
      logError('[mf] ' + apis[i].name + ' 失败: ' + ((err as Error).message ?? ''));
      // ★★★ 2026-11-09（用户：「播放洛雪的歌直接播放失败，已尝试所有平台和音源」）：
      //   跨源兜底时 `songId` 是**别的来源**的 id（洛雪脚本搜出来的 wy/kw id），
      //   插件不一定认识。按歌名 + 歌手在插件里搜一次，用搜到的 id 再取一次地址。
      const found: string = await searchIdInPlugin(apis[i], name, singer);
      if (found.length > 0 && found !== songId) {
        try {
          const retry: string = await mfGetMediaSource(apis[i], found, quality, name, singer);
          if (retry.length > 0) {
            logError('[mf] ' + source + ' 命中 ' + apis[i].name + '（按歌名匹配 ' + found + '）');
            return retry;
          }
        } catch (_e2) {
          // 换下一个插件
        }
      }
    }
  }
  return '';
}

/** `插件id|歌名|歌手` → 插件侧歌曲 id（避免每档音质都搜一遍）。 */
const mfIdCache: Map<string, string> = new Map<string, string>();
/** 搜不到时的冷却（同一首歌 60s 内不再重复搜，避免每档音质都白等一次）。 */
const mfIdMiss: Map<string, number> = new Map<string, number>();

function normalizeSongText(s: string): string {
  return s.trim().toLowerCase().replace(/\(.*?\)/g, ' ').replace(/（.*?）/g, ' ')
    .replace(/\s+/g, ' ').trim();
}

/**
 * 在插件里按歌名 + 歌手找歌曲 id。
 *
 * 只在 `getMediaSource` 失败后才调用：说明这个 id 插件不认（跨来源兜底），
 * 用插件自己的搜索结果重新定位。命中要求**歌名一致**，歌手只做排序加权，
 * 宁可返回空也不要放错歌。
 */
async function searchIdInPlugin(api: LXUserApiInfo, name?: string, singer?: string): Promise<string> {
  const title: string = (name ?? '').trim();
  if (title.length === 0) {
    return '';
  }
  const key: string = api.id + '|' + title + '|' + (singer ?? '');
  const cached: string | undefined = mfIdCache.get(key);
  if (cached !== undefined) {
    return cached;
  }
  const missUntil: number | undefined = mfIdMiss.get(key);
  if (missUntil !== undefined && missUntil > Date.now()) {
    return '';
  }
  const wantTitle: string = normalizeSongText(title);
  const wantSinger: string = normalizeSongText(singer ?? '');
  let picked: string = '';
  try {
    const res = await mfSearch(api, title, 1, 10);
    for (let i: number = 0; i < res.list.length; i++) {
      if (normalizeSongText(res.list[i].name) !== wantTitle) {
        continue;
      }
      if (wantSinger.length > 0 &&
        normalizeSongText(res.list[i].singer).indexOf(wantSinger) < 0 &&
        wantSinger.indexOf(normalizeSongText(res.list[i].singer)) < 0) {
        continue;
      }
      picked = res.list[i].songId;
      break;
    }
  } catch (_err) {
    picked = '';
  }
  if (picked.length > 0) {
    mfIdCache.set(key, picked);
  } else {
    mfIdMiss.set(key, Date.now() + 60 * 1000);
  }
  return picked;
}

/**
 * 直接向 MusicFree 插件要一个播放地址（不经过 LX 引擎）。
 *
 * ★ 2026-11-09（用户：「你别把这个禁了啊」）：洛雪脚本全部失败、或用户一个
 *   LX 脚本都没装时，声明了同名平台的插件（元力WY / 元力KW …）仍然能供地址。
 *   回退链在「零候选 / 全失败」时用这个入口补最后一枪。
 */
export async function getMusicFreeUrlForPlatform(source: string, songId: string, quality: string,
  name?: string, singer?: string): Promise<string> {
  try {
    return await tryMusicFreeUrl(source, songId, quality, name, singer);
  } catch (_e) {
    return '';
  }
}

/** 逐个 MusicFree 源试歌词；全失败返回空串。 */
async function tryMusicFreeLyric(source: string, songId: string, name?: string,
  singer?: string): Promise<string> {
  const apis: LXUserApiInfo[] = enabledMusicFreeApis(source);
  for (let i: number = 0; i < apis.length; i++) {
    try {
      const lyric: string = await mfGetLyric(apis[i], songId, name, singer);
      if (lyric.length > 0) {
        return lyric;
      }
    } catch (_err) {
      // 换下一个
    }
  }
  return '';
}

/**
 * 常驻的 QuickJS 会话（按 scriptId 复用；换脚本才重建）。
 *
 * ★ 2026-11-15：「混合引擎」的落地件 —— 用户定调「关键追求效率，不是完全独立」。
 *   真机实测（聆澜音源 7749 字）：
 *     · WebView 换脚本：`totalMs=871`（页面创建 + 导航 + onPageEnd）
 *     · QuickJS 冷启：`耗时=122~318ms`
 *     · 两边**取回的播放地址完全一致**（同一个 kuwo URL）
 *   ⇒ 引擎选择不再是非此即彼：`lxEngineMode` 选 `quickjs` 时走这里，
 *     任何一步失败都**自动回落 WebView**，两条腿都留着。
 */
let quickJsSession: QuickJsScriptSession = new QuickJsScriptSession();

/**
 * 最近一次**经 WebView**取回的播放地址与耗时（ms）。
 * ★ 2026-11-15：给「一键测」做 A/B 对照 —— 直接比"两个引擎返回的地址是否一致"，
 *   比人工看两条日志可靠得多。
 */
export let lastWebViewUrl: string = '';
export let lastWebViewUrlMs: number = -1;

/**
 * 每支脚本「能不能在 QuickJS 里跑」的判定缓存（本次进程内有效）。
 *
 * ★ 2026-11-15 实测定了 auto 的口径：QuickJS 与 WebView **取回的地址逐字节相同**
 *   （`③ 一致 ✓`），且取址 218ms vs 245ms、脚本初始化 119ms vs 821ms。
 *   所以 `auto` = **QuickJS 优先，失败回落 WebView**。
 *   缓存是为了让"跑不了 QuickJS 的脚本"只付一次 4s 超时代价，之后直接走 WebView。
 * @key 脚本 id
 * @value true=可跑（已验证） / false=跑不了（已验证，别重试）
 */
const quickJsVerdict: Map<string, boolean> = new Map<string, boolean>();

/**
 * 取某脚本的 QuickJS 判定：内存 → 持久化（跨重启）。
 * ★ 2026-11-16：以前只看内存，冷启动后又要为跑不了的脚本再付一次 4s 超时。
 * @param scriptId 脚本 id
 * @returns true/false/undefined（未测过）
 */
function lookupVerdict(scriptId: string): boolean | undefined {
  const inMem: boolean | undefined = quickJsVerdict.get(scriptId);
  if (inMem !== undefined) {
    return inMem;
  }
  const persisted: boolean | undefined = MusicStoreService.getInstance().getQuickJsVerdict(scriptId);
  if (persisted !== undefined) {
    quickJsVerdict.set(scriptId, persisted);
  }
  return persisted;
}

/**
 * 记住判定：内存 + 持久化一起。
 */
function rememberVerdict(scriptId: string, can: boolean): void {
  quickJsVerdict.set(scriptId, can);
  MusicStoreService.getInstance().setQuickJsVerdict(scriptId, can);
}

/**
 * 从脚本 handler 的返回值里抠出播放地址。
 *
 * LX 的契约是 `{data:{url}}`，但实测有的脚本直接 resolve 一个字符串
 * （真机日志 `结果="http://car-er.kuwo.cn/…"`）⇒ 三种形状都认。
 * @param valueJson `JSON.stringify(handler 返回值)`
 */
function extractUrlFromValue(valueJson: string): string {
  if (valueJson.length === 0) {
    return '';
  }
  try {
    const v: Object = JSON.parse(valueJson) as Object;
    if (typeof v === 'string') {
      return v as string;
    }
    if (v !== null && typeof v === 'object') {
      const obj: Record<string, Object> = v as Record<string, Object>;
      const data: Object = obj['data'];
      if (data !== undefined && data !== null && typeof data === 'object') {
        const u: Object = (data as Record<string, Object>)['url'];
        if (typeof u === 'string' && (u as string).length > 0) {
          return u as string;
        }
      }
      const direct: Object = obj['url'];
      if (typeof direct === 'string' && (direct as string).length > 0) {
        return direct as string;
      }
    }
  } catch (_e) {
    // 不是 JSON：可能就是裸 URL
    if (valueJson.indexOf('http') === 0) {
      return valueJson;
    }
  }
  return '';
}

/**
 * 用 QuickJS 取一次播放地址。
 * @returns 地址；拿不到返回空串（调用方据此回落 WebView）
 */
async function resolveUrlViaQuickJs(reqData: LXSourceRequestData): Promise<string> {
  try {
    const activeId: string = MusicStoreService.getInstance().getActiveSource();
    if (activeId.length === 0 || activeId.indexOf('mfplat:') === 0) {
      return '';
    }
    const script: string = await lxSourceManager.getScript(activeId);
    if (script.length === 0) {
      appendPlayLog('[qjs] 取不到脚本原文，回落 WebView');
      return '';
    }
    const ready: boolean = await quickJsSession.open(activeId, script, 4000);
    if (!ready) {
      appendPlayLog('[qjs] 会话未就绪，回落 WebView');
      return '';
    }
    const valueJson: string = await quickJsSession.invoke('request', JSON.stringify(reqData), 8000);
    return extractUrlFromValue(valueJson);
  } catch (e) {
    appendPlayLog('[qjs] 取址异常，回落 WebView: ' + JSON.stringify(e).substring(0, 140));
    return '';
  }
}

/**
 * 「一键测」：把 QuickJS 侧的三项验证跑成一条结论，并和 WebView 的实测数据对照。
 *
 * 为什么做成一键：三项分别点会得到三行散日志，还得人工判断"两个引擎给的地址是不是同一个"、
 * "871 和 122 到底是不是同一口径"。这里一次跑完、一次判定。
 *
 * 全过程**不碰正在播的 WebView**（走独立的 QuickJS 实例），随时可点。
 * @returns 多行文本（直接贴到设置页那张卡片里）
 */
export async function runQuickJsOneClickCheck(): Promise<string> {
  const lines: string[] = [];
  // 每一行也写进运行日志（[qjs]{check}）—— 用户看界面、我看日志，
  // 否则让人手抄四行结论太蠢。最后再打 [qjs]{check} DONE 便于 grep。
  const note = (line: string): void => {
    lines.push(line);
    appendPlayLog('[qjs]{check} ' + line);
  };
  // ① 引擎自检
  const self: string = quickJsSelfTest();
  note('① 自检：' + (self.indexOf('通过') === 0 ? '通过 · ' + self : self));

  // ② 当前音源脚本在 QuickJS 里初始化
  const activeId: string = MusicStoreService.getInstance().getActiveSource();
  if (activeId.length === 0 || activeId.indexOf('mfplat:') === 0) {
    note('② 脚本：跳过（当前音源不是 LX 脚本）');
    return lines.join('\n');
  }
  const script: string = await lxSourceManager.getScript(activeId);
  if (script.length === 0) {
    note('② 脚本：跳过（读不到脚本原文）');
    return lines.join('\n');
  }
  const run: QuickJsRunResult = await runScriptInQuickJs(script, 4000);
  note('② 脚本：' + (run.ok ?
    ('ok · 平台 ' + run.platforms.join('/') + ' · ' + run.elapsedMs + 'ms') :
    ('失败 · ' + run.error)));

  // ③ 重放最近一次真实取址，并与 WebView 的结果对拍
  if (lxLastRequestData === undefined) {
    note('③ 取址：跳过（还没播过歌，没有可重放的请求）');
  } else {
    const inv: QuickJsInvokeResult = await runScriptAndInvoke(script, 'request',
      JSON.stringify(lxLastRequestData), 6000);
    const qjsUrl: string = extractUrlFromValue(inv.valueJson);
    if (!inv.ok || qjsUrl.length === 0) {
      note('③ 取址：失败 · ' + (inv.error.length > 0 ? inv.error : '没拿到地址'));
    } else {
      let verdict: string = '（WebView 还没结果，无法对拍）';
      if (lastWebViewUrl.length > 0) {
        verdict = lastWebViewUrl === qjsUrl ? '· 与 WebView **一致** ✓' : '· 与 WebView **不一致** ✗';
      }
      note('③ 取址：ok · ' + inv.elapsedMs + 'ms · ' + qjsUrl.substring(0, 56) + '… ' + verdict);
    }
  }

  // ④ 对照：WebView 侧最近一次实测
  const wvInit: string = lxLastInitTotalMs > 0 ? (lxLastInitTotalMs + 'ms') : '未记录';
  const wvUrl: string = lastWebViewUrlMs >= 0 ? (lastWebViewUrlMs + 'ms') : '未记录';
  note('④ 对照：WebView 脚本初始化 ' + wvInit + ' · 取址 ' + wvUrl);
  // ★ 验证通过 ⇒ 允许 `auto` 对这支脚本走 QuickJS（失败过一次就永远不许）
  if (run.ok && lookupVerdict(activeId) !== false) {
    rememberVerdict(activeId, true);
    note('⑤ 结论：这支脚本可以走 QuickJS（`自动` 模式下次会用它）');
  }
  appendPlayLog('[qjs]{check} DONE');
  return lines.join('\n');
}

export async function getLXMusicUrl(source: string, songId: string, quality: string, name?: string,
  singer?: string): Promise<string> {
  // ★ 2026-11-09：MusicFree 独有平台（哔哩哔哩 / YouTube / `mf:xxx`）LX 脚本不认识，
  //   直接问插件。以前会先发一次必然失败的 LX 请求，白白多等 5 秒。
  if (isMfOnlyPlatform(source)) {
    const direct: string = await tryMusicFreeUrl(source, songId, quality, name, singer);
    if (direct.length > 0) {
      return direct;
    }
    throw new Error('该平台没有可用的 MusicFree 音源');
  }
  let sendReq: (key: string, data: LXSourceRequestData) => void = lxEngineSendRequest!;
  let regReq: (key: string,
    resolve: (result: object) => void, reject: (reason: Error) => void) => void = lxEngineRegisterPromise!;
  let requestKey: string = 'musicUrl_' + Date.now() + '_' + Math.random().toString(36).substring(2);
  let playableId: string = await resolvePlayableSongId(source, songId, name, singer);
  let musicInfo: MusicInfoBrief = buildMusicInfo(source, playableId, name, singer);
  let info: MusicUrlRequestInfo = { type: quality, musicInfo: musicInfo };
  let reqData: LXSourceRequestData = { source: toLXSourceKey(source), action: 'musicUrl', info: info };
  if (playableId !== songId) {
    logError('req ' + source + '/' + songId + ' -> ' + playableId + '/' + quality);
  } else {
    logError('req ' + source + '/' + songId + '/' + quality);
  }
  // ★ 2026-11-15：`quickjs` 与 `auto` 都先试 QuickJS；
  //   `auto` 额外看判定缓存（跑不了就别每次都白等 4s）。拿不到就继续走下面的 WebView 流程。
  // ★ 2026-11-15（用户：「似乎都是 QuickJS 更快，那还需要混合吗」）：
  //   混合的意义**不是**"两个引擎交替用"，而是「QuickJS 优先 + WebView 兜底」。
  //   `auto` 的闸门从「一键测验证过」放宽到「脚本能力探测过关（不需要 DOM）」——
  //   `ScriptProbe` 纯文本扫描（~4ms）就能判，覆盖绝大多数脚本；跑不通再由下面兜底。
  //   另外：**WebView 引擎没就绪时也允许走 QuickJS**（否则没导入脚本就只能报错）。
  const engineMode: string = MusicStoreService.getInstance().getLxEngineMode();
  const activeScriptId: string = MusicStoreService.getInstance().getActiveSource();
  const verdict: boolean | undefined = lookupVerdict(activeScriptId);
  const engineReady: boolean = lxEngineIsReady && lxEngineSendRequest !== null &&
    lxEngineRegisterPromise !== null;
  const autoEligible: boolean = engineMode === 'auto' &&
    (verdict === true || (verdict === undefined && scriptCanRunWithoutWebView(activeScriptId)));
  const wantQuickJs: boolean = engineMode === 'quickjs' || autoEligible || !engineReady;
  if (wantQuickJs && engineMode !== 'webview') {
    const quickUrl: string = await resolveUrlViaQuickJs(reqData);
    if (quickUrl.length > 0) {
      rememberVerdict(activeScriptId, true);
      logError('qjs ok ' + quickUrl.substring(0, 80));
      return quickUrl;
    }
    // 记下"这支脚本在这台机器上跑不了"，下次 auto 直接走 WebView（不重复付超时）
    rememberVerdict(activeScriptId, false);
    // ★ 2026-11-16：QuickJS 没接住 ⇒ 立刻把 WebView 拉起来（混合的"兜底腿"）。
    //   接下来 `sendReq` 会因为引擎未就绪而进队列（TTL 20s），页面加载完自动补发。
    if (lxEngineEnsureWebView !== null) {
      lxEngineEnsureWebView();
    }
    logError('qjs miss -> webview (' + engineMode + ')');
  }
  if (!lxEngineIsReady || lxEngineSendRequest === null || lxEngineRegisterPromise === null) {
    // ★ LX 引擎没就绪（没导入 LX 脚本 / 脚本全部不可用）不再直接失败：
    //   用户可能只导入了 MusicFree 插件，那就该走插件取地址。
    // ★ 2026-11-14：但**洛雪六平台**同样不许升级到插件 —— 与 `allowMfRescue`、
    //   `buildCandidateChain`（六平台候选链不摆插件）保持同一条定稿规则，
    //   否则「LX 不能回退到 MF」就有第三个后门。插件歌回退洛雪是反方向，不在此列。
    if (!isLxPlatform(source)) {
      const fallback: string = await tryMusicFreeUrl(source, songId, quality, name, singer);
      if (fallback.length > 0) {
        return fallback;
      }
    }
    logError('engine not ready');
    throw new Error('引擎未就绪或回调未初始化');
  }
  return new Promise<string>((resolve: (url: string) => void, reject: (reason: Error) => void): void => {
    const reqStartedAt: number = Date.now();
    regReq(requestKey, (result: object): void => {
      let mr: LXMusicUrlResult = result as LXMusicUrlResult;
      if (mr !== undefined && mr.data !== undefined && mr.data.url !== undefined && mr.data.url.length > 0) {
        logError('ok ' + mr.data.url.substring(0, 80));
        lastWebViewUrl = mr.data.url;
        lastWebViewUrlMs = Date.now() - reqStartedAt;
        resolve(mr.data.url);
      } else {
        let msg: string = '响应数据无效: ' + JSON.stringify(result).substring(0, 200);
        logError(msg);
        reject(new Error(msg));
      }
    }, (reason: Error): void => {
      logError('fail ' + reason.message);
      // ★ 2026-11-14（甲方再次确认：「LX 不能回退到 MF，但是 MF 可以回退到 LX」，
      //   且提醒「mf 的源里面也可以有 kw」）：
      //   洛雪六平台**失败后不得临时升级到 MusicFree 插件** —— 这条定稿本来只写在
      //   SourceFallbackUtil 的 `allowMfRescue` 里，而这里是个后门：无条件 try 一次
      //   同平台插件，既不看平台规则、也不看用户勾选（`enabledMusicFreeApis` 只看平台），
      //   后果是每次洛雪失败都白等一次插件装载（真机实测 502 之后白等 6s），
      //   还会把**没勾选**的插件拉起来。
      //   勾选过的 MusicFree 插件要参与洛雪平台播放，走的是回退链里的 `isMf` 候选
      //   （按勾选顺序），不需要这个后门。非洛雪平台保留原行为。
      if (isLxPlatform(source)) {
        logError('mf-skip lx ' + source);
        reject(reason);
        return;
      }
      tryMusicFreeUrl(source, songId, quality, name, singer).then((url: string): void => {
        if (url.length > 0) {
          resolve(url);
        } else {
          reject(reason);
        }
      }).catch((): void => {
        reject(reason);
      });
    });
    sendReq(requestKey, reqData);
  });
}

export async function getLXLyric(source: string, songId: string, name?: string, singer?: string): Promise<string> {
  if (isMfOnlyPlatform(source)) {
    const direct: string = await tryMusicFreeLyric(source, songId, name, singer);
    if (direct.length > 0) {
      return direct;
    }
    throw new Error('该平台没有可用的 MusicFree 音源');
  }
  if (!lxEngineIsReady || lxEngineSendRequest === null || lxEngineRegisterPromise === null) {
    const fallback: string = await tryMusicFreeLyric(source, songId, name, singer);
    if (fallback.length > 0) {
      return fallback;
    }
    logError('getLXLyric: engine not ready');
    throw new Error('LX engine not ready');
  }
  let sendReq: (key: string, data: LXSourceRequestData) => void = lxEngineSendRequest!;
  let regReq: (key: string,
    resolve: (result: object) => void, reject: (reason: Error) => void) => void = lxEngineRegisterPromise!;
  let requestKey: string = 'lyric_' + Date.now() + '_' + Math.random().toString(36).substring(2);
  let playableId: string = await resolvePlayableSongId(source, songId, name, singer);
  let musicInfo: MusicInfoBrief = buildMusicInfo(source, playableId, name, singer);
  let info: LyricPicRequestInfo = { musicInfo: musicInfo };
  let reqData: LXSourceRequestData = { source: toLXSourceKey(source), action: 'lyric', info: info };
  return new Promise<string>((resolve: (text: string) => void, reject: (reason: Error) => void): void => {
    regReq(requestKey, (result: object): void => {
      let lr: LXLyricResult = result as LXLyricResult;
      if (lr.data !== undefined) {
        resolve(lr.data.lyric);
      } else {
        logError('getLXLyric: invalid resp');
        reject(new Error('Invalid lyric response'));
      }
    }, (reason: Error): void => {
      tryMusicFreeLyric(source, songId, name, singer).then((lyric: string): void => {
        if (lyric.length > 0) {
          resolve(lyric);
        } else {
          reject(reason);
        }
      }).catch((): void => {
        reject(reason);
      });
    });
    sendReq(requestKey, reqData);
  });
}

export async function getLXPic(source: string, songId: string, name?: string, singer?: string): Promise<string> {
  if (!lxEngineIsReady || lxEngineSendRequest === null || lxEngineRegisterPromise === null) {
    logError('getLXPic: engine not ready');
    throw new Error('LX engine not ready');
  }
  let sendReq: (key: string, data: LXSourceRequestData) => void = lxEngineSendRequest!;
  let regReq: (key: string,
    resolve: (result: object) => void, reject: (reason: Error) => void) => void = lxEngineRegisterPromise!;
  let requestKey: string = 'pic_' + Date.now() + '_' + Math.random().toString(36).substring(2);
  let playableId: string = await resolvePlayableSongId(source, songId, name, singer);
  let musicInfo: MusicInfoBrief = buildMusicInfo(source, playableId, name, singer);
  let info: LyricPicRequestInfo = { musicInfo: musicInfo };
  let reqData: LXSourceRequestData = { source: toLXSourceKey(source), action: 'pic', info: info };
  return new Promise<string>((resolve: (url: string) => void, reject: (reason: Error) => void): void => {
    regReq(requestKey, (result: object): void => {
      let pr: LXPicResult = result as LXPicResult;
      if (pr.data !== undefined) {
        resolve(pr.data);
      } else {
        logError('getLXPic: invalid resp');
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
    // ★ 2026-11-09（用户：「我记 MusicFree 是有榜单的」）：MF 榜单详情走插件协议，
    //   不能拼 `source + '_' + boardId` 去问洛雪引擎（那里没有这个平台）。
    if (isMfPlatformId(source)) {
      const apis: LXUserApiInfo[] = musicFreeApisForPlatform(source, lxSourceManager.getApiList());
      if (apis.length === 0) {
        return [];
      }
      const songs: LXSearchSong[] = await mfGetSheetSongs(apis[0], boardId, 1, true);
      const mfOut: BoardSongEntry[] = [];
      for (let i: number = 0; i < songs.length; i++) {
        if (songs[i].songId.length === 0) {
          continue;
        }
        mfOut.push({
          title: songs[i].name, singer: songs[i].singer, source: source,
          songId: songs[i].songId, coverUrl: songs[i].img
        });
      }
      logError('[榜单] mf/' + boardId + ' n=' + mfOut.length);
      return mfOut;
    }
    // ★ 汽水（qs）：没有脚本榜单接口，榜/歌单都走内置 Luna（见 geuz/QsApi）。
    //   boardId 形如 `qs_hot` / `qs_new` / `qs_west`（榜单卡）或纯歌单 id（歌单详情）。
    if (source === 'qs') {
      const isBoard: boolean = boardId.startsWith('qs_');
      const songs = isBoard
        ? await qsBoardSongs(boardId.substring(3), 1, 500)
        : await qsPlaylistDetail(boardId, 1, 500);
      const sodaOut: BoardSongEntry[] = [];
      for (let i: number = 0; i < songs.length; i++) {
        if (songs[i].songId.length === 0) {
          continue;
        }
        sodaOut.push({
          title: songs[i].name, singer: songs[i].singer, source: 'qs',
          songId: songs[i].songId, coverUrl: songs[i].img
        });
      }
      logError('[榜单] qs/' + boardId + ' n=' + sodaOut.length);
      return sodaOut;
    }
    const result = await lxLeaderboard(source + '_' + boardId, 1, 500);
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
    logError('[榜单] ' + source + '/' + boardId + ' n=' + out.length);
    return out;
  } catch (err) {
    logError('[榜单] ' + source + '/' + boardId + ' fail: ' + JSON.stringify(err).substring(0, 120));
    return [];
  }
}
