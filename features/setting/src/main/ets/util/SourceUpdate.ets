/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源更新：**只走官方通道**。
 *
 * 洛雪脚本在 `UPDATE_ENABLE` 为真时会调用它的 checkUpdate，并通过
 * `lx.EVENT_NAMES.updateAlert` 上报 `{ log, updateUrl }`；我们的引擎已经接住并写入
 * AppStorage（见 `LXSourceEngine.ets` 的 `case 'updateAlert'`：
 * `lxUpdateAlertUrl` / `lxUpdateAlertLog` / `lxUpdateAlertVersion`）。
 *
 * ★ 2026-10-30 清理：之前我额外加过一套 `rzd_update_alert_*` 键与 `appendLog` 抓取，
 *   既是重复通道、键名又写错（官方键是 `lxUpdateAlert*`），于是「检查更新」一直是 false。
 *   现在收敛到这一处，按三条优先级读：
 *     ① 官方 alert（引擎写 AppStorage）
 *     ② 播放日志缓冲里的「更新提示: … url=…」（有些脚本只打日志、不上报 alert）
 *     ③ AppStorageV2 的 UpdateAlertState 镜像（历史兼容）
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
 * 读取官方 updateAlert（不发生任何网络请求）。
 * @returns 有更新时 `hasUpdate=true` 并带 url/log；否则 `error` 给出说明。
 */
export function readOfficialUpdateAlert(): SourceUpdateInfo {
  const out: SourceUpdateInfo = new SourceUpdateInfo();
  const state: UpdateAlertState | undefined =
    AppStorageV2.connect(UpdateAlertState, 'rzd_update_alert', () => new UpdateAlertState());

  // ① 官方通道：引擎接住脚本的 updateAlert 事件后写下的键
  let url: string = AppStorage.get<string>('lxUpdateAlertUrl') ?? '';
  let log: string = AppStorage.get<string>('lxUpdateAlertLog') ?? '';

  // ② 日志兜底：脚本只打「更新提示: … url=…」时，从播放日志缓冲里抓
  if (url.length === 0) {
    const buf: string = AppStorage.get<string>('lxPlayLog') ?? '';
    const idx: number = buf.lastIndexOf('更新提示');
    if (idx >= 0) {
      const line: string = buf.substring(idx, Math.min(buf.length, idx + 200));
      const m: RegExpMatchArray | null = line.match(/url=(\S+)/);
      if (m !== null && m.length > 1) {
        url = m[1];
      }
      log = line.split('\n')[0].substring(0, 120);
    }
  }

  // ③ 历史镜像兜底
  if (url.length === 0 && state !== undefined && state.updateUrl.length > 0) {
    url = state.updateUrl;
    log = state.log;
  }

  if (url.length > 0) {
    out.hasUpdate = true;
    out.updateUrl = url;
    out.message = log;
    console.info('[RzdSourceUpdate] alert url=' + url);
    return out;
  }
  out.error = '该音源未上报更新（脚本 UPDATE_ENABLE 未开启或已是最新）';
  console.info('[RzdSourceUpdate] no alert');
  return out;
}
