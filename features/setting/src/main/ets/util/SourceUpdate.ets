/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源更新：**只走官方通道**。
 *
 * 洛雪脚本自己在 `UPDATE_ENABLE` 为真时会调用它的 checkUpdate，并通过
 * `lx.EVENT_NAMES.updateAlert` 上报 `{ log, updateUrl }`；我们的引擎已经接住并写入
 * AppStorage（见 `LXSourceEngine.ets:578-588`：`lxUpdateAlertUrl` / `lxUpdateAlertLog`）。
 * 所以这里**不做任何自研请求**，只读引擎上报的结果。
 */

import { AppStorageV2 } from '@kit.ArkUI';

/** 引擎上报的 updateAlert 镜像（AppStorageV2 通道）。 */
@ObservedV2
export class UpdateAlertState {
  @Trace updateUrl: string = '';
  @Trace log: string = '';
}

/** 一次检查的结果。 */
export class SourceUpdateInfo {
  hasUpdate: boolean = false;
  message: string = '';
  updateUrl: string = '';
  error: string = '';
}

/**
 * 读取官方 updateAlert（不发起任何网络请求）。
 * 没有上报时返回 `hasUpdate=false` 并给出提示文案。
 */
export function readOfficialUpdateAlert(): SourceUpdateInfo {
  const out: SourceUpdateInfo = new SourceUpdateInfo();
  const state: UpdateAlertState | undefined =
    AppStorageV2.connect(UpdateAlertState, 'rzd_update_alert', () => new UpdateAlertState());
  // ★ 优先读引擎抓到的脚本日志（AppStorage 两个键），再退回 UpdateAlertState
  const liveUrl: string = AppStorage.get<string>('rzd_update_alert_url') ?? '';
  const liveLog: string = AppStorage.get<string>('rzd_update_alert_log') ?? '';
  const url: string = liveUrl.length > 0 ? liveUrl : (state === undefined ? '' : state.updateUrl);
  if (url.length > 0) {
    out.hasUpdate = true;
    out.updateUrl = url;
    out.message = liveLog.length > 0 ? liveLog : (state === undefined ? '' : state.log);
    console.info('[RzdSourceUpdate] official alert url=' + url);
    return out;
  }
  out.error = '该音源未上报更新（脚本 UPDATE_ENABLE 未开启或已是最新）';
  console.info('[RzdSourceUpdate] no official alert');
  return out;
}
/**
 * ★ 2026-10-29：脚本只打日志「更新提示: … url=…」、从不上报 updateAlert。
 *  引擎抓到这类日志时用它写进官方 alert，「检查更新」才读得到。
 */
export function recordOfficialUpdateAlert(log: string, url: string): void {
  const st: UpdateAlertState | undefined =
    AppStorageV2.connect(UpdateAlertState, 'rzd_update_alert', () => new UpdateAlertState());
  if (st !== undefined) {
    st.updateUrl = url;
    st.log = log;
  }
  console.info('[RzdSourceUpdate] captured url=' + url);
}