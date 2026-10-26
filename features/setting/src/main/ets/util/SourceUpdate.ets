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
  const url: string = state === undefined ? '' : state.updateUrl;
  if (url.length > 0) {
    out.hasUpdate = true;
    out.updateUrl = url;
    out.message = state === undefined ? '' : state.log;
    console.info('[RzdSourceUpdate] official alert url=' + url);
    return out;
  }
  out.error = '该音源未上报更新（脚本 UPDATE_ENABLE 未开启或已是最新）';
  console.info('[RzdSourceUpdate] no official alert');
  return out;
}