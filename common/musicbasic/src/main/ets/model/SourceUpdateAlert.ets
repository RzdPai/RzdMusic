/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源「更新提示」的**唯一事实来源**：AppStorage 键名 + 读取逻辑都收敛在这里。
 *
 * 为什么要有这个文件（2026-11-14 甲方报的两个问题）：
 *   ① 「有的源走的官方渠道，却不提示」；
 *   ② 「检查出来之后检查其它音源还是这个源的提示」。
 *
 * 背景：洛雪脚本在版本检查里发现新版本时会 `lx.send('updateAlert', { log, updateUrl })`。
 * 我们的引擎接住后过去**只写全局键**（`lxUpdateAlertUrl/Log`），于是：
 *   · 读取方不带脚本 id ⇒ 本次启动里第一个上报过告警的源，会把「发现新版本」对话框
 *     **劫持**给之后检查的所有源（问题②）；
 *   · 为了让「未更新也能用」，应用会**拦截**版本检查请求 ⇒ 脚本永远收不到新版本 ⇒
 *     它压根不会上报 ⇒ 检查更新只能静默，而「被拦截」这件事当时只有播放失败 toast 会读，
 *     检查更新流程完全看不到（问题①）。
 *
 * 所以这里做两件事：
 *   1. 键名只写一份（历史上键名写错过一次，导致「检查更新」恒为 false）；
 *   2. 告警**按脚本分键**，读取时绝不跨源借用；被拦截的脚本如实回报「查不了」。
 *
 * ⚠️ 约定：`readScriptUpdateAlert(scriptId)` 是设置页「检查更新」唯一该用的读法；
 * `readGlobalUpdateAlert()` 只给「拿不到脚本 id」的场合（如播放失败的兜底文案）用，
 * 它读的是全局键，跨源共用，**不要**拿它判断"当前这个源有没有更新"。
 */

/** 全局告警：最后一次上报的原文（播放失败提示用）。 */
export const KEY_ALERT_LOG: string = 'lxUpdateAlertLog';
/** 全局告警：最后一次上报的更新地址。 */
export const KEY_ALERT_URL: string = 'lxUpdateAlertUrl';
/** 全局告警：最后一次上报的时间戳。 */
export const KEY_ALERT_AT: string = 'lxUpdateAlertVersion';
/** 全局告警的归属脚本 id：读全局键的人据此判断"是不是当前这个源的"。 */
export const KEY_ALERT_OWNER: string = 'lxUpdateAlertOwner';
/** 全局「更新检查被拦截」记录（播放失败提示用）。 */
export const KEY_BLOCKED_LOG: string = 'lxUpdateBlockedLog';
/** 全局「更新检查被拦截」的 URL。 */
export const KEY_BLOCKED_URL: string = 'lxUpdateBlockedUrl';

const PREFIX_ALERT_URL: string = 'lxUpdateAlertUrl:';
const PREFIX_ALERT_LOG: string = 'lxUpdateAlertLog:';
const PREFIX_ALERT_AT: string = 'lxUpdateAlertAt:';
const PREFIX_BLOCKED_AT: string = 'lxUpdateBlocked:';
const PREFIX_BLOCKED_URL: string = 'lxUpdateBlockedUrl:';
/**
 * 某脚本被拦截时抓到的**全部**更新检查 URL（脚本通常会试主/备两个域名）。
 *
 * ★ 2026-11-26（用户："检查更新的时候提示无法连接到服务器"）：
 *   星海这类脚本会同时请求 `yy1.zddyr.top` 与 `yy.zddyr.top` 两个域名；
 *   只记最后一条时，若该域名在本机解析失败，代打查询就必然失败。
 *   ⇒ 全记下来（去重、上限 8 条），检查更新时逐条重放，任一条通就能给出结论。
 */
const PREFIX_BLOCKED_URLS: string = 'lxUpdateBlockedUrls:';
const PREFIX_ALLOW: string = 'lxUpdateCheckAllow:';

/** 某脚本上报的告警地址键。 */
export function scriptAlertUrlKey(scriptId: string): string {
  return PREFIX_ALERT_URL + scriptId;
}

/** 某脚本上报的告警原文键。 */
export function scriptAlertLogKey(scriptId: string): string {
  return PREFIX_ALERT_LOG + scriptId;
}

/** 某脚本上报告警的时间戳键。 */
export function scriptAlertAtKey(scriptId: string): string {
  return PREFIX_ALERT_AT + scriptId;
}

/** 某脚本「更新检查被拦截」的时间戳键。 */
export function scriptBlockedAtKey(scriptId: string): string {
  return PREFIX_BLOCKED_AT + scriptId;
}

/** 某脚本被拦截时抓到的那条更新检查 URL 键。 */
export function scriptBlockedUrlKey(scriptId: string): string {
  return PREFIX_BLOCKED_URL + scriptId;
}

/** 某脚本被拦截时抓到的全部更新检查 URL 列表键。 */
export function scriptBlockedUrlsKey(scriptId: string): string {
  return PREFIX_BLOCKED_URLS + scriptId;
}

/** 某脚本「豁免拦截」的键（上次拦了它还是起不来 ⇒ 下次放行让脚本自己判断）。 */
export function scriptAllowKey(scriptId: string): string {
  return PREFIX_ALLOW + scriptId;
}

/** 一次「检查更新」的结果。 */
export class SourceUpdateInfo {
  /** 这个脚本确实上报过更新。 */
  hasUpdate: boolean = false;
  /** 脚本给的更新说明（首行可展示）。 */
  message: string = '';
  /** 脚本给的更新地址。 */
  updateUrl: string = '';
  /**
   * 这个脚本的更新检查**被应用拦截过**（为了"未更新也能用"）。
   * 为真时 `hasUpdate` 必然为假 —— 我们没能查到更新，也没资格说"已是最新"。
   */
  blocked: boolean = false;
  /** 被拦截的那条 URL，可作为用户手动更新的线索。 */
  blockedUrl: string = '';
  /** 没更新 / 查不了的原因（进日志，也用于区分"静默"与"有情况"）。 */
  error: string = '';
}

/**
 * 这段告警文本是不是"连不上服务器"（= 我们拦截更新检查的后果，**不是**新版本线索）。
 *
 * ★ 2026-11-26：星海源把 `versionh2.php` 拦成失败后，脚本打印
 *   "无法连接到服务器，请手动查看更新 url=…/lx/vers.php"（那个页面还是 404）。
 *   这条文本被当成告警后，`hasUpdate` 恒为真、跳转地址是死链。
 *   引擎侧已经不再记录这类文本（`LXSourceEngine.isUpdateFailureText`），
 *   这里再兜一层：**历史已存下的脏数据也不能当真**。
 * @param text 告警原文
 * @returns 属于"连不上/被拦"时为 true
 */
function looksLikeConnectionFailure(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  const lower: string = text.toLowerCase();
  const bad: string[] = ['无法连接', '连接失败', '无法访问', '连接超时', '网络异常', '网络错误',
    'failed to connect', 'connect failed', 'timeout', 'network error'];
  for (let i: number = 0; i < bad.length; i++) {
    if (lower.indexOf(bad[i].toLowerCase()) >= 0) {
      return true;
    }
  }
  return false;
}

/**
 * 读取**某一个脚本**的更新告警（绝不跨源借用）。
 * @param scriptId 音源脚本 id
 * @returns 结果；`hasUpdate` / `blocked` 全为假表示"该脚本没有任何更新线索"
 */
export function readScriptUpdateAlert(scriptId: string): SourceUpdateInfo {
  const out: SourceUpdateInfo = new SourceUpdateInfo();
  if (scriptId.length === 0) {
    out.error = '缺少脚本 id';
    return out;
  }
  const url: string = AppStorage.get<string>(scriptAlertUrlKey(scriptId)) ?? '';
  const logText: string = AppStorage.get<string>(scriptAlertLogKey(scriptId)) ?? '';
  if (url.length > 0 && !looksLikeConnectionFailure(logText)) {
    out.hasUpdate = true;
    out.updateUrl = url;
    out.message = logText;
    return out;
  }
  const blockedAt: number = AppStorage.get<number>(scriptBlockedAtKey(scriptId)) ?? 0;
  if (blockedAt > 0) {
    out.blocked = true;
    out.blockedUrl = AppStorage.get<string>(scriptBlockedUrlKey(scriptId)) ?? '';
    out.error = '该音源的更新检查已被拦截（为保持可用）';
    return out;
  }
  out.error = '该音源未上报更新（脚本未开启更新检查，或确实已是最新）';
  return out;
}

/**
 * 读取**全局**告警（不区分脚本）。
 * @returns 全局键里的告警；只有在"拿不到脚本 id"时才该用它
 */
export function readGlobalUpdateAlert(): SourceUpdateInfo {
  const out: SourceUpdateInfo = new SourceUpdateInfo();
  const url: string = AppStorage.get<string>(KEY_ALERT_URL) ?? '';
  const log: string = AppStorage.get<string>(KEY_ALERT_LOG) ?? '';
  if (url.length > 0 || log.length > 0) {
    out.hasUpdate = url.length > 0;
    out.updateUrl = url;
    out.message = log;
    if (url.length === 0) {
      // 有文案没地址：算"提示存在但取不到跳转"，调用方自行决定怎么说
      out.error = '告警缺少更新地址';
    }
    return out;
  }
  out.error = '本会话尚未收到任何更新提示';
  return out;
}

/**
 * 全局告警是否属于指定脚本。
 * @param scriptId 脚本 id
 * @returns 归属一致时为 true；全局键为空时一律 false
 */
export function globalAlertOwnedBy(scriptId: string): boolean {
  const owner: string = AppStorage.get<string>(KEY_ALERT_OWNER) ?? '';
  return scriptId.length > 0 && owner === scriptId;
}
