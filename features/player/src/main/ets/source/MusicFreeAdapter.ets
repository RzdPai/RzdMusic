import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { LXSearchResult, LXSearchSong, LXQualityType } from './LXMusicSDK';
import { LXUserApiInfo, MfSubscriptionInfo } from './Interface';
import {
  ensureMfReady, mfCall, mfEngineLoadScript, mfEngineMethods, mfEnginePlatform, mfEngineReady, waitMfReady
} from './MusicFreeEngine';
import { lxSourceManager } from './LXSourceManager';
import { isMfPlatformId, mfApiIdOf, mfPlatformIdOf, platformIdFromLabel } from '../util/SourceDeclaredInfo';
import { mfHasCap } from '../util/MfCapability';
import { appendPlayLog } from 'musicbasic';
import { SearchPlaylistInfo } from '../shareplaylistsearch/PlaylistSearchTypes';

// 平台识别全仓只有一个实现（util 层），这里 re-export 保持调用方不变
export { platformIdFromLabel };

/**
 * MusicFree 生态适配层。
 *
 * 三层职责：
 *   1. **订阅**：MusicFree 的订阅是一份 `{ "plugins": [{ name, url, version }] }`，
 *      逐条下载插件脚本后交给 {@link lxSourceManager.importMusicFreePlugin} 落库；
 *   2. **平台识别**：插件自己声明 `platform`（「元力WY」这种），这里把它折成项目内的
 *      平台 id（`wy` / `kw` / ...），播放链路才能按平台挑源；
 *   3. **能力适配**：把插件的 `search / getMediaSource / getLyric`
 *      转成项目统一的 `LXSearchResult` / URL / LRC 文本。
 */

/** 订阅里的一条插件。 */
export interface MfSubscriptionEntry {
  name: string;
  url: string;
  version: string;
}

/** 订阅导入结果。 */
export interface MfImportReport {
  ok: boolean;
  added: number;
  updated: number;
  failed: number;
  message: string;
}

/** 下载插件脚本的上限（元力系单个 130KB，留足余量）。 */
const MF_PLUGIN_MAX_BYTES: number = 8 * 1024 * 1024;
const MF_DOWNLOAD_TIMEOUT: number = 20000;

/** 传给插件的最小 music item（拿不到搜索结果原始对象时用）。 */
class MfMusicItem {
  id: string = '';
  platform: string = '';
  title: string = '';
  artist: string = '';
  album: string = '';
  duration: number = 0;
  artwork: string = '';
}

/** 搜索结果的原始 item 缓存：getMediaSource 需要插件自己那份完整对象。 */
const RAW_ITEM_CACHE_MAX: number = 400;
const rawItemCache: Map<string, string> = new Map();

function cacheKeyOf(apiId: string, songId: string): string {
  return apiId + '|' + songId;
}

function rememberRawItem(apiId: string, songId: string, json: string): void {
  if (songId.length === 0) {
    return;
  }
  if (rawItemCache.size >= RAW_ITEM_CACHE_MAX) {
    const first: string | undefined = rawItemCache.keys().next().value;
    if (first !== undefined) {
      rawItemCache.delete(first);
    }
  }
  rawItemCache.set(cacheKeyOf(apiId, songId), json);
}

function recallRawItem(apiId: string, songId: string): string {
  const hit: string | undefined = rawItemCache.get(cacheKeyOf(apiId, songId));
  return hit === undefined ? '' : hit;
}

/**
 * 解析订阅 JSON。
 *
 * 兼容三种常见写法：`{plugins:[...]}`（官方）、裸数组、以及单条 `{name,url}`。
 * @param text 订阅正文
 */
export function parseMusicFreeSubscription(text: string): MfSubscriptionEntry[] {
  const out: MfSubscriptionEntry[] = [];
  let parsed: Object | null = null;
  try {
    parsed = JSON.parse(text) as Object;
  } catch (_err) {
    return out;
  }
  if (parsed === null) {
    return out;
  }
  let list: Object[] = [];
  if (Array.isArray(parsed)) {
    list = parsed as Object[];
  } else {
    const obj: Record<string, Object> = parsed as Record<string, Object>;
    const plugins: Object | undefined = obj.plugins;
    if (plugins !== undefined && plugins !== null && Array.isArray(plugins)) {
      list = plugins as Object[];
    } else if (obj.url !== undefined) {
      list = [parsed];
    }
  }
  for (let i: number = 0; i < list.length; i++) {
    const row: Record<string, Object> = list[i] as Record<string, Object>;
    const url: string = (row.url as string) ?? '';
    if (url.length === 0) {
      continue;
    }
    out.push({
      name: (row.name as string) ?? '',
      url: url,
      version: (row.version as string) ?? ''
    });
  }
  return out;
}

/** 下载文本（订阅 / 插件脚本共用）。 */
async function fetchText(url: string): Promise<string> {
  const request: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await request.request(url, {
      method: http.RequestMethod.GET,
      connectTimeout: MF_DOWNLOAD_TIMEOUT,
      readTimeout: MF_DOWNLOAD_TIMEOUT,
      expectDataType: http.HttpDataType.STRING
    });
    if (resp.responseCode !== 200 || typeof resp.result !== 'string') {
      return '';
    }
    const text: string = resp.result as string;
    if (text.length > MF_PLUGIN_MAX_BYTES) {
      return '';
    }
    return text;
  } catch (_err) {
    return '';
  } finally {
    try {
      request.destroy();
    } catch (_e) {
      // ignore
    }
  }
}

/**
 * 导入单个插件脚本：先跑一遍拿到 `platform`，再落库。
 *
 * 平台名只有运行时才知道（脚本是混淆的，正则抓不到），所以这里必须真的加载一次插件。
 * 失败也不阻塞导入：platform 留空，用户仍可在「实际支持平台」里手动勾。
 */
export async function importMusicFreePluginScript(script: string, fallbackName: string): Promise<string> {
  const info: LXUserApiInfo | null = await importMusicFreePluginInternal(script, fallbackName);
  return info !== null ? info.name : fallbackName;
}

/** 导入插件并返回落库后的条目（订阅导入要拿 id 做归属）。 */
async function importMusicFreePluginInternal(script: string, fallbackName: string,
  subId: string = ''): Promise<LXUserApiInfo | null> {
  if (script.length === 0) {
    throw new Error('插件脚本为空');
  }
  // ★ 2026-11-09（用户：「现在平台全都显示元力音源」）：
  //   只信 manifest 里的 `platform` 字面量（bilibili / Youtube 这类）；
  //   `@name` 是插件**品牌名**（元力音源），元力系的 platform 是运行时才解密的
  //   （元力WY / 元力KG）—— 静态读不到就留空，交给后台探测，绝不拿品牌名充平台名。
  const manifestName: string = lxSourceManager.parseMusicFreePlatform(script);
  // 先落库：条目立刻出现在音源管理里（名字用订阅项名，平台名随后探测回填）
  const result = lxSourceManager.importMusicFreePlugin(script, manifestName, fallbackName, subId);
  if (!result.ok) {
    throw new Error(result.message);
  }
  const info: LXUserApiInfo | null = result.info;
  if (info !== null) {
    AppStorage.setOrCreate('mfEngineNeeded', true);
    if (manifestName.length === 0) {
      // 不 await：探测要等隐藏 WebView 挂载 + 重载 + 注入，几秒钟起步，
      // 卡在这里会让「导入 6 个插件的订阅」等到 1 分钟以上。
      probePlatformAsync(info.id, script);
    }
  }
  appendPlayLog('[mf] 导入 ' + result.message);
  return info;
}

/**
 * 平台探测串行队列。
 *
 * ★ 2026-11-09：订阅一次导入 6 个插件，原来 6 个探测**并行**跑，而隐藏 WebView 只有一份
 *   —— 后一个 `loadScript` 会把前一个顶掉，`mfEnginePlatform` 拿到的是最后一次加载的
 *   平台名 ⇒ 平台回填张冠李戴（元力WY 被标成元力MG）。改成链式串行，一次只识别一个。
 */
let probeChain: Promise<void> = Promise.resolve();

function probePlatformAsync(apiId: string, script: string): void {
  probeChain = probeChain.then((): Promise<boolean> => probeOnePlatform(apiId, script))
    .then((): void => {
      // 只取结果，不关心单个插件成功与否
    })
    .catch((): void => {
      // 单个失败不影响后续插件
    });
}

/** 异步探测插件平台名并回填（失败静默：用户仍可手动勾选实际支持平台）。 */
async function probeOnePlatform(apiId: string, script: string): Promise<boolean> {
  try {
    // 引擎可能还没挂载（AppStorage 刚置位，UI 还没重建），最多等 8s
    const deadline: number = Date.now() + 8000;
    while (mfEngineLoadScript === null && Date.now() < deadline) {
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => resolve(), 200);
      });
    }
    if (mfEngineLoadScript === null) {
      appendPlayLog('[mf] 引擎未挂载，跳过平台探测');
      return false;
    }
    const probeId: string = '__probe__' + apiId;
    mfEngineLoadScript(probeId, script);
    const ok: boolean = await waitMfReady(probeId, 12000);
    if (!ok || mfEnginePlatform.length === 0) {
      appendPlayLog('[mf] 平台探测未拿到结果');
      return false;
    }
    lxSourceManager.updateMusicFreePlatform(apiId, mfEnginePlatform);
    appendPlayLog('[mf] 平台已识别: ' + mfEnginePlatform);
    return true;
  } catch (err) {
    appendPlayLog('[mf] 平台探测异常: ' + ((err as Error).message ?? ''));
    return false;
  }
}

/** 一次回填任务正在进行（避免「导入」和「打开平台管理」两条路径同时刷同一个插件）。 */
let backfillRunning: boolean = false;

/**
 * 回填所有「还没识别出平台」的 MusicFree 插件。
 *
 * ★ 2026-11-09（用户：「现在平台全都显示元力音源」）：元力系插件的平台名是运行时
 *   解密的，静态解析只能拿到空串；旧数据又被写成了品牌名。这里在后台串行探测一遍，
 *   成功后把 `platform` 写成「元力WY」这类真名，源列表 / 平台管理 / 搜索页立刻变准。
 *
 * 只在**引擎已挂载**时跑：没挂载就等下一次（导入时会置 `mfEngineNeeded`，
 * 宿主组件挂载后 AppStorage 里的标记就有效了），不做长时间空转。
 *
 * @param apis 当前音源列表
 * @returns 成功回填的数量
 */
export async function backfillMusicFreePlatforms(apis: LXUserApiInfo[]): Promise<number> {
  const pending: LXUserApiInfo[] = [];
  for (let i: number = 0; i < apis.length; i++) {
    const api: LXUserApiInfo = apis[i];
    if (api.kind !== 'mf' || api.id.length === 0) {
      continue;
    }
    const platform: string = api.platform !== undefined ? api.platform.trim() : '';
    if (platform.length === 0) {
      pending.push(api);
    }
  }
  if (pending.length === 0 || backfillRunning) {
    return 0;
  }
  backfillRunning = true;
  AppStorage.setOrCreate('mfEngineNeeded', true);
  let done: number = 0;
  try {
    // 引擎挂载最多等 6s（打开面板时通常已经在了）；等不到就下次再来
    const deadline: number = Date.now() + 6000;
    while (mfEngineLoadScript === null && Date.now() < deadline) {
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => resolve(), 200);
      });
    }
    if (mfEngineLoadScript === null) {
      appendPlayLog('[mf] 平台回填跳过：引擎未挂载');
      return 0;
    }
    for (let i: number = 0; i < pending.length; i++) {
      const script: string = await lxSourceManager.getScript(pending[i].id);
      if (script.length === 0) {
        continue;
      }
      if (await probeOnePlatform(pending[i].id, script)) {
        done++;
      }
    }
  } finally {
    backfillRunning = false;
  }
  appendPlayLog('[mf] 平台回填完成 ' + done + '/' + pending.length);
  return done;
}

/**
 * 订阅 JSON 自带的展示名（顶层 `name` / `title`）。
 *
 * ★ 2026-11-09（用户：「只显示域名太难看了」）：订阅里写了名字就用它，
 *   没写才退回主机名；主机名在界面上会被 `musicFreeSubscriptionLabel()` 折成中性文案。
 */
export function parseMusicFreeSubscriptionName(text: string): string {
  try {
    const parsed: Object = JSON.parse(text) as Object;
    if (parsed === null || Array.isArray(parsed)) {
      return '';
    }
    const obj: Record<string, Object> = parsed as Record<string, Object>;
    const candidates: Object[] = [obj.name, obj.title];
    for (let i: number = 0; i < candidates.length; i++) {
      const v: Object | undefined = candidates[i];
      if (v !== undefined && v !== null && typeof v === 'string') {
        const s: string = (v as string).trim();
        if (s.length > 0) {
          return s;
        }
      }
    }
  } catch (_e) {
    return '';
  }
  return '';
}

/**
 * 导入一份订阅（URL）。
 */
/** 从订阅地址里取一个像样的名字（主机名），避免列表里全是「MusicFree 订阅」。 */
function subscriptionNameOfUrl(url: string): string {
  const m: RegExpExecArray | null = /^https?:\/\/([^/]+)/i.exec(url.trim());
  if (m !== null && m[1].length > 0) {
    return m[1];
  }
  return 'MusicFree 订阅';
}

/**
 * 导入一份订阅（URL）。
 *
 * ★ 2026-11-09：订阅现在是一等对象 —— 记住 url / 名字 / 成员，源管理按它分组，
 *   之后「更新」就是重新拉这份 JSON（见 {@link updateSubscription}）。
 */
export async function importMusicFreeSubscription(url: string): Promise<MfImportReport> {
  const text: string = await fetchText(url.trim());
  if (text.length === 0) {
    return { ok: false, added: 0, updated: 0, failed: 0, message: '订阅拉取失败，请检查链接' };
  }
  const declared: string = parseMusicFreeSubscriptionName(text);
  return await importMusicFreeSubscriptionText(text, url,
    declared.length > 0 ? declared : subscriptionNameOfUrl(url));
}

/**
 * 导入订阅（正文已在手上时用这个，避免把同一份 JSON 下载两次）。
 * @param text 订阅 JSON 正文
 * @param url 订阅地址（文件导入传空串 → 之后只能重新选文件更新）
 * @param name 订阅名（空则用主机名 / 「MusicFree 订阅」）
 */
export async function importMusicFreeSubscriptionText(text: string, url: string = '',
  name: string = ''): Promise<MfImportReport> {
  const report: MfImportReport = { ok: false, added: 0, updated: 0, failed: 0, message: '' };
  const entries: MfSubscriptionEntry[] = parseMusicFreeSubscription(text);
  if (entries.length === 0) {
    report.message = '订阅里没有插件（需要 {"plugins":[...]} 格式）';
    return report;
  }
  const subName: string = name.length > 0 ? name :
    (url.length > 0 ? subscriptionNameOfUrl(url) : 'MusicFree 订阅');
  const subId: string = lxSourceManager.beginSubscription(subName, url);
  const importedIds: string[] = [];
  for (let i: number = 0; i < entries.length; i++) {
    const entry: MfSubscriptionEntry = entries[i];
    const script: string = await fetchText(entry.url);
    if (script.length === 0) {
      report.failed++;
      appendPlayLog('[mf] 下载失败 ' + entry.name);
      continue;
    }
    try {
      const before: number = lxSourceManager.getApiList().length;
      const info: LXUserApiInfo | null = await importMusicFreePluginInternal(script, entry.name, subId);
      const after: number = lxSourceManager.getApiList().length;
      if (info !== null) {
        lxSourceManager.attachApiToSubscription(subId, info.id);
        importedIds.push(info.id);
      }
      if (after > before) {
        report.added++;
      } else {
        report.updated++;
      }
    } catch (err) {
      report.failed++;
      appendPlayLog('[mf] 导入失败 ' + entry.name + ': ' + ((err as Error).message ?? ''));
    }
  }
  // 更新语义：这次订阅里已经没有的插件从本地移除（有失败时保守保留）
  const removed: number = lxSourceManager.syncSubscriptionMembers(subId, importedIds, report.failed === 0);
  lxSourceManager.finishSubscription(subId);
  report.ok = report.added + report.updated > 0;
  if (removed > 0) {
    report.message += '，移除 ' + removed;
  }
  report.message = '新增 ' + report.added + '，更新 ' + report.updated +
    (report.failed > 0 ? '，失败 ' + report.failed : '');
  return report;
}

/**
 * 更新一份已经导入的订阅（重新拉 url 并覆盖其插件）。
 * @param subId 订阅 id
 * @returns 导入报告；订阅没有 url（文件导入）时返回失败说明
 */
export async function updateSubscription(subId: string): Promise<MfImportReport> {
  const subs: MfSubscriptionInfo[] = lxSourceManager.getSubscriptions();
  for (let i: number = 0; i < subs.length; i++) {
    if (subs[i].id !== subId) {
      continue;
    }
    if (subs[i].url.length === 0) {
      return { ok: false, added: 0, updated: 0, failed: 0, message: '这份订阅来自文件，请重新选择文件导入' };
    }
    return await importMusicFreeSubscription(subs[i].url);
  }
  return { ok: false, added: 0, updated: 0, failed: 0, message: '订阅不存在' };
}

/**
 * 判断一段文本像不像 MusicFree 插件。
 *
 * 特征：CommonJS 导出（`module.exports` / `exports.xxx =`）+ `require(`。
 * LX 脚本虽然也可能有 `module` 字样，但它一定带 `window.lx` / `lx.on(` / `lx.send(`。
 */
export function looksLikeMusicFreePlugin(text: string): boolean {
  const hasCommonJs: boolean = text.indexOf('module.exports') >= 0 || /exports\.[A-Za-z_$]+\s*=/.test(text);
  if (!hasCommonJs) {
    return false;
  }
  if (text.indexOf('window.lx') >= 0 || text.indexOf('lx.send(') >= 0 || text.indexOf('lx.on(') >= 0) {
    return false;
  }
  return text.indexOf('require(') >= 0 || /getMediaSource\s*[:(]/.test(text) || /getMediaSource\s*=/.test(text);
}

/**
 * 统一导入入口：一段脚本文本自动分派给 LX / MusicFree 两条通道。
 *
 * 用户不需要知道自己在导什么 —— 音源管理的「从文件导入」「从链接导入」都走这里。
 * @param script 脚本文本
 * @param fallbackName 名字兜底（订阅里给的 name 或文件名）
 * @returns 给用户看的提示
 */
export async function importSourceScriptAuto(script: string, fallbackName: string): Promise<string> {
  if (looksLikeMusicFreePlugin(script)) {
    return await importMusicFreePluginScript(script, fallbackName);
  }
  const result = lxSourceManager.importApi(script);
  if (!result.ok) {
    throw new Error(result.message);
  }
  return result.message;
}

/** 导入单个插件 URL。 */
export async function importMusicFreePluginUrl(url: string, name: string): Promise<string> {
  const script: string = await fetchText(url.trim());
  if (script.length === 0) {
    throw new Error('插件下载失败，请检查链接');
  }
  return await importMusicFreePluginScript(script, name);
}

/**
 * 某个平台条目对应的 MusicFree 插件。
 *
 * ★ 2026-11-09 第三版（用户：「源和平台都分开」「一个源一个平台」）：
 *   平台 id 就是 `mfplat:<插件id>`，所以这里最多命中一个（一插件一平台），
 *   不再按「逻辑平台」把多个插件合并到同一栏。
 */
/**
 * 能供这个平台播放的 MusicFree 插件。
 *
 * ★★★ 2026-11-09（用户：「播放洛雪的歌直接播放失败，已尝试所有平台和音源。
 *   你别把这个禁了啊」）：
 *   上一版只认 `mfplat:` 平台 id（插件自己的平台），于是**洛雪平台（wy/kw/…）**
 *   永远拿不到插件兜底 —— 元力系插件本来就同时支持六平台，洛雪脚本全挂时它们
 *   是唯一的活路。这里补上「按插件声明的平台匹配」：
 *     · `mfplat:xxx` → 只取那一个插件；
 *     · `wy` / `kw` / … → 取所有声明了该平台的插件（多份订阅可能有同名平台）。
 */
export function musicFreeApisForPlatform(source: string, apis: LXUserApiInfo[]): LXUserApiInfo[] {
  const out: LXUserApiInfo[] = [];
  const apiId: string = mfApiIdOf(source);
  if (apiId.length > 0) {
    for (let i: number = 0; i < apis.length; i++) {
      if (apis[i].kind === 'mf' && apis[i].id === apiId) {
        out.push(apis[i]);
        break;
      }
    }
    return out;
  }
  const canon: string = platformIdFromLabel(source);
  if (canon.length === 0) {
    return out;
  }
  for (let i: number = 0; i < apis.length; i++) {
    if (apis[i].kind !== 'mf') {
      continue;
    }
    // 平台名可能还没回填（旧数据被清污染后处于空窗期）：**名字也要认**。
    // 元力订阅里的条目名就是「网易 / QQ音乐」，`platformIdFromLabel` 一样能识别。
    const byPlatform: string = platformIdFromLabel(apis[i].platform);
    const byName: string = platformIdFromLabel(apis[i].name);
    if (byPlatform === canon || byName === canon) {
      out.push(apis[i]);
    }
  }
  return out;
}

/** 平台 id → 对应插件（`mfplat:` 直接取；洛雪平台取第一个声明它的插件）。 */
export function mfApiForPlatform(platformId: string, apis: LXUserApiInfo[]): LXUserApiInfo | undefined {
  const list: LXUserApiInfo[] = musicFreeApisForPlatform(platformId, apis);
  return list.length > 0 ? list[0] : undefined;
}

/** 这个平台对应的插件有没有某个能力（能力未知按「有」处理）。 */
export function mfPlatformHasCap(platformId: string, cap: string, apis: LXUserApiInfo[]): boolean {
  const api: LXUserApiInfo | undefined = mfApiForPlatform(platformId, apis);
  if (api === undefined) {
    return false;
  }
  return mfHasCap(api, cap);
}

/** 插件 → 平台 id（一插件一平台，名称跟随插件名）。 */
export function mfPlatformIdOfApi(api: LXUserApiInfo): string {
  return mfPlatformIdOf(api.id);
}

/**
 * 是否 MusicFree 平台（一插件一平台）。
 * 播放 / 搜索链路据此跳过 LX 引擎，直接走插件。
 */
export function isMfOnlyPlatform(platformId: string): boolean {
  return isMfPlatformId(platformId);
}

/** MusicFree 的 quality 档位。 */
function mfQualityOf(lxQuality: string): string {
  if (lxQuality === '128k') {
    return 'standard';
  }
  if (lxQuality === '320k') {
    return 'high';
  }
  if (lxQuality.length > 0) {
    return 'super';
  }
  return 'standard';
}

/** 秒 → `mm:ss`。 */
function formatInterval(seconds: number): string {
  if (seconds === undefined || seconds === null || seconds <= 0) {
    return '';
  }
  const total: number = Math.floor(seconds);
  const m: number = Math.floor(total / 60);
  const s: number = total % 60;
  return m.toString() + ':' + (s < 10 ? '0' + s : s.toString());
}

/**
 * 插件侧的歌单 / 榜单条目（`getMusicSheetInfo` / `getTopListDetail` 的入参）。
 * 多数插件只读 `id`，少数会看 `platform` / `title`，能带上的都带上。
 */
class MfSheetItem {
  id: string = '';
  platform: string = '';
  title: string = '';
  coverImg: string = '';
}

/** 插件返回的单行歌曲 → 项目统一结构（source 用平台 id，播放才能路由）。 */
function songOfRow(row: Record<string, Object>, platform: string, apiId: string): LXSearchSong | null {
  const id: string = row.id !== undefined && row.id !== null ? String(row.id) : '';
  if (id.length === 0) {
    return null;
  }
  const qualities: Record<string, Object> = (row.qualities ?? {}) as Record<string, Object>;
  const types: LXQualityType[] = [];
  const qKeys: string[] = Object.keys(qualities);
  for (let q: number = 0; q < qKeys.length; q++) {
    const info: Record<string, Object> = qualities[qKeys[q]] as Record<string, Object>;
    const size: number = info !== undefined && info.size !== undefined ? info.size as number : 0;
    types.push({ type: qKeys[q], size: size > 0 ? String(size) : '' });
  }
  const song: LXSearchSong = {
    songId: id,
    name: (row.title as string) ?? '',
    singer: (row.artist as string) ?? '',
    albumName: (row.album as string) ?? '',
    albumId: row.album_id !== undefined && row.album_id !== null ? String(row.album_id) : '',
    source: platform,
    interval: formatInterval(row.duration as number),
    img: (row.artwork as string) ?? '',
    types: types
  };
  rememberRawItem(apiId, id, JSON.stringify(row));
  return song;
}

/** 从插件返回的 `{ musicList: [...] }` / 裸数组里取歌曲列表。 */
function songsOfMusicList(parsed: Object | null, platform: string, apiId: string): LXSearchSong[] {
  const out: LXSearchSong[] = [];
  if (parsed === null) {
    return out;
  }
  let rows: Object[] = [];
  if (Array.isArray(parsed)) {
    rows = parsed as Object[];
  } else {
    const obj: Record<string, Object> = parsed as Record<string, Object>;
    const list: Object | undefined = obj.musicList;
    if (list !== undefined && list !== null && Array.isArray(list)) {
      rows = list as Object[];
    }
  }
  for (let i: number = 0; i < rows.length; i++) {
    const song: LXSearchSong | null = songOfRow(rows[i] as Record<string, Object>, platform, apiId);
    if (song !== null) {
      out.push(song);
    }
  }
  return out;
}

/**
 * 用插件搜索。
 * @param api 目标音源（必须是 `kind === 'mf'`）
 * @param query 关键词
 * @param page 页码（MusicFree 从 1 开始）
 * @param limit 期望条数（插件一般固定返回 20/30，这里只做截断）
 */
export async function mfSearch(api: LXUserApiInfo, query: string, page: number,
  limit: number): Promise<LXSearchResult> {
  const empty: LXSearchResult = { list: [], total: 0, limit: limit, source: '' };
  if (!(await ensureMfReady(api.id))) {
    appendPlayLog('[mf] 未就绪 ' + api.name);
    return empty;
  }
  // 结果里的 source 必须是**平台 id**（不是插件名）：播放 / 歌词 / 换源都按它路由。
  const platform: string = mfPlatformIdOfApi(api);
  const json: string = await mfCall('search', [query, page, 'music']);
  let parsed: Record<string, Object>;
  try {
    parsed = JSON.parse(json) as Record<string, Object>;
  } catch (_err) {
    return empty;
  }
  const rows: Object = parsed.data as Object;
  if (rows === undefined || rows === null || !Array.isArray(rows)) {
    return empty;
  }
  const arr: Object[] = rows as Object[];
  const out: LXSearchSong[] = [];
  for (let i: number = 0; i < arr.length && out.length < limit; i++) {
    const song: LXSearchSong | null = songOfRow(arr[i] as Record<string, Object>, platform, api.id);
    if (song !== null) {
      out.push(song);
    }
  }
  return { list: out, total: out.length, limit: limit, source: platform };
}

/**
 * 取播放地址。
 * @param api 目标音源
 * @param songId 插件侧的歌曲 id
 * @param quality 期望档位（LX 口径的 `128k` / `320k` / `flac`…）
 * @param name 歌名（拿不到原始 item 时构造最小对象用）
 * @param singer 歌手
 */
export async function mfGetMediaSource(api: LXUserApiInfo, songId: string, quality: string,
  name?: string, singer?: string): Promise<string> {
  if (!(await ensureMfReady(api.id))) {
    throw new Error('MusicFree 插件未就绪');
  }
  if (mfEngineMethods.indexOf('getMediaSource') < 0) {
    throw new Error(api.name + ' 不提供播放地址');
  }
  const rawJson: string = recallRawItem(api.id, songId);
  let music: Object;
  if (rawJson.length > 0) {
    music = JSON.parse(rawJson) as Object;
  } else {
    const minimal: MfMusicItem = new MfMusicItem();
    minimal.id = songId;
    minimal.platform = api.platform;
    minimal.title = name ?? '';
    minimal.artist = singer ?? '';
    music = minimal;
  }
  const json: string = await mfCall('getMediaSource', [music, mfQualityOf(quality)]);
  let parsed: Record<string, Object>;
  try {
    parsed = JSON.parse(json) as Record<string, Object>;
  } catch (_err) {
    // 少数插件直接返回 URL 字符串
    const plain: string = json.replace(/^"|"$/g, '');
    if (plain.startsWith('http')) {
      return plain;
    }
    throw new Error('播放地址解析失败');
  }
  const url: string = (parsed.url as string) ?? '';
  if (url.length === 0) {
    throw new Error('插件没有返回播放地址');
  }
  return url;
}

/**
 * 取歌词（LRC 文本）。
 */
export async function mfGetLyric(api: LXUserApiInfo, songId: string, name?: string,
  singer?: string): Promise<string> {
  if (!(await ensureMfReady(api.id))) {
    throw new Error('MusicFree 插件未就绪');
  }
  // 视频类插件（哔哩哔哩）本来就没有歌词方法 —— 直接返回空，别让上层把它当失败重试一轮
  if (mfEngineMethods.indexOf('getLyric') < 0) {
    return '';
  }
  const rawJson: string = recallRawItem(api.id, songId);
  let music: Object;
  if (rawJson.length > 0) {
    music = JSON.parse(rawJson) as Object;
  } else {
    const minimal: MfMusicItem = new MfMusicItem();
    minimal.id = songId;
    minimal.platform = api.platform;
    minimal.title = name ?? '';
    minimal.artist = singer ?? '';
    music = minimal;
  }
  const json: string = await mfCall('getLyric', [music]);
  if (json === 'null' || json.length === 0) {
    return '';
  }
  try {
    const parsed: Record<string, Object> = JSON.parse(json) as Record<string, Object>;
    const raw: string = (parsed.rawLrc as string) ?? '';
    if (raw.length > 0) {
      return raw;
    }
    const lrc: string = (parsed.lyric as string) ?? '';
    return lrc;
  } catch (_err) {
    const plain: string = json.replace(/^"|"$/g, '');
    return plain.startsWith('[') ? plain : '';
  }
}

/** 引擎是否已加载任意 MusicFree 插件。 */
export function musicFreeEngineAlive(): boolean {
  return mfEngineReady;
}


/** MusicFree 榜单分组（插件 `getTopLists` 的返回）。 */
export class MfTopListGroup {
  title: string = '';
  items: SearchPlaylistInfo[] = [];
}

/** 从任意 JSON 行里尽力取字符串字段（不同插件字段名略有差异）。 */
function strField(row: Record<string, Object>, keys: string[]): string {
  for (let i: number = 0; i < keys.length; i++) {
    const v: Object | undefined = row[keys[i]];
    if (v !== undefined && v !== null) {
      const text: string = String(v);
      if (text.length > 0 && text !== 'undefined' && text !== 'null') {
        return text;
      }
    }
  }
  return '';
}

function numField(row: Record<string, Object>, keys: string[]): number {
  const text: string = strField(row, keys);
  const n: number = Number(text);
  return Number.isFinite(n) ? n : 0;
}

/** 把插件返回的歌单行转成 project 统一结构（source 用平台 id，播放/详情才能路由）。 */
function playlistInfoOf(row: Record<string, Object>, platformId: string): SearchPlaylistInfo | null {
  const id: string = strField(row, ['id', 'sheetId', 'dissid', 'disstid']);
  if (id.length === 0) {
    return null;
  }
  return SearchPlaylistInfo.of(
    id,
    strField(row, ['title', 'name']),
    numField(row, ['playCount', 'play_count', 'listenCount', 'visitorCount']),
    numField(row, ['songCount', 'trackCount', 'dataCount', 'total', 'worksNum', 'worksCount']),
    strField(row, ['coverImgUrl', 'coverImg', 'artwork', 'pic', 'img']),
    strField(row, ['creator', 'author', 'nickname', 'userName']),
    platformId
  );
}

/**
 * 用插件搜歌单（MusicFree 的 `searchSheet`）。
 *
 * 搜索页「歌单」页签 / 歌单广场的 MusicFree 平台入口都走这里；
 * 插件没实现 `searchSheet` 时返回空数组（UI 显示空态，不报错）。
 */
export async function mfSearchSheets(api: LXUserApiInfo, query: string, page: number): Promise<SearchPlaylistInfo[]> {
  const out: SearchPlaylistInfo[] = [];
  if (!(await ensureMfReady(api.id))) {
    return out;
  }
  if (mfEngineMethods.indexOf('searchSheet') < 0) {
    return out;
  }
  const platformId: string = mfPlatformIdOfApi(api);
  let parsed: Object | null = null;
  try {
    const json: string = await mfCall('searchSheet', [query, page]);
    parsed = JSON.parse(json) as Object;
  } catch (_err) {
    return out;
  }
  if (parsed === null) {
    return out;
  }
  let rows: Object[] = [];
  if (Array.isArray(parsed)) {
    rows = parsed as Object[];
  } else {
    const obj: Record<string, Object> = parsed as Record<string, Object>;
    const data: Object | undefined = obj.data;
    if (data !== undefined && data !== null && Array.isArray(data)) {
      rows = data as Object[];
    }
  }
  for (let i: number = 0; i < rows.length; i++) {
    const info: SearchPlaylistInfo | null =
      playlistInfoOf(rows[i] as Record<string, Object>, platformId);
    if (info !== null) {
      out.push(info);
    }
  }
  return out;
}

/** `插件id|歌单id` —— 由 `getTopLists` 产出的 id 集合（决定取歌时该走哪个入口）。 */
const topListIds: Set<string> = new Set<string>();

/**
 * 插件的榜单分组（`getTopLists`）。
 *
 * 只服务「排行榜」页；**不要**拿它顶替歌单广场的推荐内容 ——
 * 见 `mfRecommendGroups()`。
 */
export async function mfTopLists(api: LXUserApiInfo): Promise<MfTopListGroup[]> {
  const out: MfTopListGroup[] = [];
  if (!(await ensureMfReady(api.id))) {
    return out;
  }
  if (mfEngineMethods.indexOf('getTopLists') < 0) {
    return out;
  }
  const platformId: string = mfPlatformIdOfApi(api);
  let parsed: Object | null = null;
  try {
    const json: string = await mfCall('getTopLists', []);
    parsed = JSON.parse(json) as Object;
  } catch (_err) {
    return out;
  }
  if (parsed === null || !Array.isArray(parsed)) {
    return out;
  }
  const groups: Object[] = parsed as Object[];
  for (let g: number = 0; g < groups.length; g++) {
    const group: Record<string, Object> = groups[g] as Record<string, Object>;
    const data: Object | undefined = group.data;
    if (data === undefined || data === null || !Array.isArray(data)) {
      continue;
    }
    const items: SearchPlaylistInfo[] = [];
    const rows: Object[] = data as Object[];
    for (let i: number = 0; i < rows.length; i++) {
      const info: SearchPlaylistInfo | null =
        playlistInfoOf(rows[i] as Record<string, Object>, platformId);
      if (info !== null) {
        items.push(info);
        topListIds.add(api.id + '|' + info.id);
      }
    }
    if (items.length > 0) {
      const entry: MfTopListGroup = new MfTopListGroup();
      entry.title = strField(group, ['title', 'name']);
      entry.items = items;
      out.push(entry);
    }
  }
  return out;
}

/** 推荐标签（`getRecommendSheetTags` 返回的 tag，原样回传给插件）。 */
class MfRecommendTag {
  id: string = '';
  title: string = '';
}

/**
 * 插件的**推荐歌单**分组（`getRecommendSheetTags` + `getRecommendSheetsByTag`）。
 *
 * ★★★ 2026-11-09（用户：「歌单广场没获取到就提示没获取到，现在显示一个榜单。
 *   我用原版 MusicFree 测试，有些在原版正常，现在就返回榜单」）：
 *   上一版把 `getTopLists`（榜单）当成了广场内容 —— 这是错的。原版 MusicFree
 *   的歌单广场用的是**推荐歌单**接口，只有实现了这两个方法的插件才有推荐；
 *   没实现的平台（例如元力的哔哩哔哩）原版就**不显示推荐**，而不是拿榜单顶替。
 *
 * 实现策略：每个标签组取**第一个标签**拉第一页歌单（广场是平铺卡片流，
 * 没有「标签筛选」的 UI 位），组间保持插件给的顺序。
 */
export async function mfRecommendGroups(api: LXUserApiInfo): Promise<MfTopListGroup[]> {
  const out: MfTopListGroup[] = [];
  if (!(await ensureMfReady(api.id))) {
    return out;
  }
  if (mfEngineMethods.indexOf('getRecommendSheetTags') < 0 ||
    mfEngineMethods.indexOf('getRecommendSheetsByTag') < 0) {
    return out;
  }
  const platformId: string = mfPlatformIdOfApi(api);
  let tagsParsed: Object | null = null;
  try {
    tagsParsed = JSON.parse(await mfCall('getRecommendSheetTags', [])) as Object;
  } catch (_err) {
    return out;
  }
  if (tagsParsed === null) {
    return out;
  }
  const root: Record<string, Object> = tagsParsed as Record<string, Object>;
  const rawGroups: Object | undefined = root.data;
  if (rawGroups === undefined || rawGroups === null || !Array.isArray(rawGroups)) {
    return out;
  }
  const groups: Object[] = rawGroups as Object[];
  for (let g: number = 0; g < groups.length && out.length < 4; g++) {
    const group: Record<string, Object> = groups[g] as Record<string, Object>;
    const tagRows: Object | undefined = group.data;
    if (tagRows === undefined || tagRows === null || !Array.isArray(tagRows)) {
      continue;
    }
    const tags: Object[] = tagRows as Object[];
    let tag: MfRecommendTag | null = null;
    for (let t: number = 0; t < tags.length; t++) {
      const row: Record<string, Object> = tags[t] as Record<string, Object>;
      const id: string = strField(row, ['id', 'tagId', 'key']);
      const title: string = strField(row, ['title', 'name']);
      if (id.length > 0 || title.length > 0) {
        tag = new MfRecommendTag();
        tag.id = id;
        tag.title = title;
        break;
      }
    }
    if (tag === null) {
      continue;
    }
    const items: SearchPlaylistInfo[] = [];
    try {
      const sheetsParsed: Object = JSON.parse(
        await mfCall('getRecommendSheetsByTag', [tag, 1])) as Object;
      const obj: Record<string, Object> = sheetsParsed as Record<string, Object>;
      let rows: Object[] = [];
      if (Array.isArray(sheetsParsed)) {
        rows = sheetsParsed as Object[];
      } else {
        const data: Object | undefined = obj.data;
        if (data !== undefined && data !== null && Array.isArray(data)) {
          rows = data as Object[];
        }
      }
      for (let i: number = 0; i < rows.length; i++) {
        const info: SearchPlaylistInfo | null =
          playlistInfoOf(rows[i] as Record<string, Object>, platformId);
        if (info !== null) {
          items.push(info);
        }
      }
    } catch (_err) {
      items.length = 0;
    }
    if (items.length > 0) {
      const entry: MfTopListGroup = new MfTopListGroup();
      entry.title = strField(group, ['title', 'name']);
      entry.items = items;
      out.push(entry);
    }
  }
  return out;
}

/**
 * 取插件歌单 / 榜单里的歌曲（歌单广场卡片点进去用）。
 *
 * MusicFree 协议里有两个入口，插件实现哪个就用哪个：
 *   - `getTopListDetail(topListItem, page)`：榜单类（哔哩哔哩的每周必看 / 排行榜）；
 *   - `getMusicSheetInfo(sheetItem, page)`：歌单类（`searchSheet` / 导入的歌单）。
 * 两者返回结构都是 `{ musicList: [...] }`。
 */
export async function mfGetSheetSongs(api: LXUserApiInfo, sheetId: string, page: number = 1,
  preferTopList: boolean = false): Promise<LXSearchSong[]> {
  const out: LXSearchSong[] = [];
  if (sheetId.length === 0 || !(await ensureMfReady(api.id))) {
    return out;
  }
  const platform: string = mfPlatformIdOfApi(api);
  const sheet: MfSheetItem = new MfSheetItem();
  sheet.id = sheetId;
  sheet.platform = api.platform;
  // 榜单入口优先（`preferTopList`）：只有 id **确实来自** `getTopLists` 时才先走
  // `getTopListDetail`。推荐歌单 / 搜索歌单的 id 属于 `getMusicSheetInfo` 体系，
  // 喂错入口有的插件会返回别的内容（不是空数组），点进去就变成另一张歌单。
  const fromTopList: boolean = preferTopList && topListIds.has(api.id + '|' + sheetId);
  if (fromTopList && mfEngineMethods.indexOf('getTopListDetail') >= 0) {
    try {
      const json: string = await mfCall('getTopListDetail', [sheet, page]);
      const parsed: Object | null = JSON.parse(json) as Object;
      const songs: LXSearchSong[] = songsOfMusicList(parsed, platform, api.id);
      for (let i: number = 0; i < songs.length; i++) {
        out.push(songs[i]);
      }
    } catch (_err) {
      // 再试歌单入口
    }
  }
  // 先试歌单入口：搜索页「歌单」页签拿到的 id 属于歌单体系；
  // 拿不到再试榜单入口（广场卡片来自 `getTopLists`，它给的是榜单 id）。
  if (out.length === 0 && mfEngineMethods.indexOf('getMusicSheetInfo') >= 0) {
    try {
      const json: string = await mfCall('getMusicSheetInfo', [sheet, page]);
      const parsed: Object | null = JSON.parse(json) as Object;
      const songs: LXSearchSong[] = songsOfMusicList(parsed, platform, api.id);
      for (let i: number = 0; i < songs.length; i++) {
        out.push(songs[i]);
      }
    } catch (_err) {
      // 换榜单入口
    }
  }
  if (out.length === 0 && mfEngineMethods.indexOf('getTopListDetail') >= 0) {
    try {
      const json: string = await mfCall('getTopListDetail', [sheet, page]);
      const parsed: Object | null = JSON.parse(json) as Object;
      const songs: LXSearchSong[] = songsOfMusicList(parsed, platform, api.id);
      for (let i: number = 0; i < songs.length; i++) {
        out.push(songs[i]);
      }
    } catch (_err) {
      // 返回空
    }
  }
  return out;
}
