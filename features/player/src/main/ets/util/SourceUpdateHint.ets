/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源脚本「请更新」提示的读取口 + 统一的「引擎未就绪」文案。
 *
 * ★ 2026-11-04（甲方转来的用户反馈：「一直提示音源未就绪」）：
 *   真因不是"没导入音源"，而是**脚本一个都没初始化成功**（`warmUpLxSources` 打出 `warmed=0 total=10`）。
 *   其中两类失败在日志里看得很清楚：
 *     · `init status=false msg=require is not defined`  → 我们的注入沙箱缺 CommonJS `require`；
 *     · 脚本能发 native 请求拿更新信息，紧接着 `[音源] 更新提示: … 请更新后使用`，**之后不再发 inited**
 *       → 脚本自己判断版本过旧、主动拒绝初始化，我们等 8s 超时。
 *   而播放失败的提示永远是「请在设置中导入并选中源」——用户明明有 10 个源，纯属误导。
 *
 *   所以：只要本会话收到过脚本的更新提示，就把"需要更新"如实说出来。
 *   数据源与设置页同一个（`lxUpdateAlert*`，由 `LXSourceEngine.handleJsMessage` 的 `updateAlert` 写）。
 */
const KEY_UPDATE_LOG: string = 'lxUpdateAlertLog';
const KEY_BLOCKED_LOG: string = 'lxUpdateBlockedLog';

/**
 * @returns 本会话内脚本上报的「需要更新」摘要（取首行，超过 60 字截断）；没有则空串。
 *          ⚠️ `AppStorage` 是内存态，所以拿到的必然是**本次启动**的提示，不存在陈旧数据。
 */
export function pendingSourceUpdateHint(): string {
  let log: string = '';
  try {
    log = AppStorage.get<string>(KEY_UPDATE_LOG) ?? '';
  } catch (e) {
    return '';
  }
  if (log.length === 0) {
    return '';
  }
  const lines: string[] = log.split('\n');
  const first: string = lines.length > 0 ? lines[0].trim() : log.trim();
  const text: string = first.length > 0 ? first : log.trim();
  if (text.length === 0) {
    return '';
  }
  return text.length > 60 ? text.substring(0, 60) + '…' : text;
}

/**
 * 「引擎未就绪」时给用户看的文案。
 * 有更新提示 ⇒ 说"需要更新"（并指路设置）；没有 ⇒ 才说"导入并选中源"。
 */
export function engineNotReadyToast(): string {
  const hint: string = pendingSourceUpdateHint();
  if (hint.length > 0) {
    return '音源需要更新：' + hint + '（设置 → 音源）';
  }
  // ★ 2026-11-04：我们**拦掉了**该脚本的更新检查（为了"未更新也能用"），
  //   但它仍然起不来 ⇒ 说明这次拦截救不了它，如实告诉用户去手动更新。
  let blocked: string = '';
  try {
    blocked = AppStorage.get<string>(KEY_BLOCKED_LOG) ?? '';
  } catch (e) {
    blocked = '';
  }
  if (blocked.length > 0) {
    return '音源无法就绪：该音源有新版本但更新检查已被拦截（设置 → 音源 手动更新后再试）';
  }
  return '音源未就绪，请在设置中导入并选中源';
}
