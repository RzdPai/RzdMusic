/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源更新：**只走官方通道**（读脚本自己上报的 updateAlert，不自研请求）。
 *
 * 2026-11-14 收敛到 `musicbasic` 的 `SourceUpdateAlert`：
 *   · 键名与读取逻辑只有一份（历史上键名写错过一次，导致「检查更新」恒为 false）；
 *   · 告警**按脚本分键**，`readOfficialUpdateAlert(scriptId)` 绝不跨源借用
 *     —— 修「检查出来之后检查其它音源还是这个源的提示」；
 *   · 更新检查被应用拦截过的脚本如实回报 `blocked`（我们没查到，也不该说"已是最新"）。
 *
 * 旧实现里的两处已删除：
 *   ① 扫播放日志 `lastIndexOf('更新提示')`：日志是全局的，抓到的必然是**最后一个**打
 *      「更新提示」的源，正是串台的来源。现在引擎在 onConsole 里就按脚本分键写好了。
 *   ② AppStorageV2 的 `UpdateAlertState` 镜像：同一份数据存两处，只会漂移。
 */

import { SourceUpdateInfo, readScriptUpdateAlert, readGlobalUpdateAlert } from 'musicbasic';

export { SourceUpdateInfo };

/**
 * 读取官方 updateAlert（不发生任何网络请求）。
 * @param scriptId 音源脚本 id；传了就只看**这个源**自己的告警（推荐）
 * @returns 结果；`hasUpdate` / `blocked` 都为假表示该源没有任何更新线索
 */
export function readOfficialUpdateAlert(scriptId: string = ''): SourceUpdateInfo {
  if (scriptId.length > 0) {
    return readScriptUpdateAlert(scriptId);
  }
  // 拿不到脚本 id 才退回全局口径（会跨源共用，只适合做"本会话有没有提示过"的判断）
  return readGlobalUpdateAlert();
}
