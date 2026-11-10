/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源更新：**优先脚本自带更新接口，官方通道兜底**。
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
 *
 * ★ 2026-11-10 修复（用户：点「检查更新」不能自动覆盖，只能重新输入地址）：
 *   检查更新只弹 toast / 跳浏览器，**从不真正更新** —— 原因是有更新时走的是
 *   `openInBrowser`，而不是下载脚本覆盖。现在统一走 `checkAndApplySourceUpdate`：
 *     ① 脚本自带 API_URL/API_KEY/SCRIPT_MD5 → 主动请求 checkUpdate 接口（最可靠）
 *     ② 读官方 updateAlert 兜底（有些脚本不上报，见上面三条优先级）
 *     有 updateUrl 就**下载脚本文本 → importApi 原地覆盖**（同 @name 不同版本
 *     保留原 id 与选中状态，正是「自动覆盖更新」）；下载内容不是脚本（如 kdocs
 *     网页）才返回 openUrl 让调用方跳浏览器。
 */

import { AppStorageV2 } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { lxSourceManager } from 'player';
import type { LXUserApiInfo } from 'player';

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

/** 检查并应用更新的最终结果（给 UI 用）。 */
export class SourceUpdateApplyResult {
  /** 是否发现更新。 */
  hasUpdate: boolean = false;
  /** 是否已自动下载并覆盖更新。 */
  applied: boolean = false;
  /** 提示信息（成功/失败/无更新说明）。 */
  message: string = '';
  /** 需要跳浏览器打开的地址（updateUrl 是网页而非脚本时）。 */
  openUrl: string = '';
}

const UPDATE_CHECK_TIMEOUT: number = 10000;
const UPDATE_DOWNLOAD_MAX_BYTES: number = 9 * 1024 * 1024;

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

/** 从脚本文本里取 `key = "value"` 形式的配置项（API_URL / API_KEY / SCRIPT_MD5）。 */
function pickScriptField(script: string, key: string): string {
  const re: RegExp = new RegExp(key + '\\s*=\\s*["\']([^"\']+)["\']');
  const m: RegExpMatchArray | null = script.match(re);
  return m === null ? '' : m[1];
}

/**
 * 主动检查某个音源是否有更新（读本地脚本文本 → 提取 API_URL/API_KEY/SCRIPT_MD5 →
 * 请求脚本的 checkUpdate 接口）。这是**最可靠**的一条路：不依赖脚本是否上报 alert。
 */
export async function checkSourceUpdateRemote(apiId: string): Promise<SourceUpdateInfo> {
  const out: SourceUpdateInfo = new SourceUpdateInfo();
  let script: string = '';
  try {
    script = await lxSourceManager.getScript(apiId);
  } catch (err) {
    out.error = '读取脚本失败';
    return out;
  }
  if (script.length === 0) {
    out.error = '脚本为空';
    return out;
  }
  const apiUrl: string = pickScriptField(script, 'API_URL');
  const apiKey: string = pickScriptField(script, 'API_KEY');
  const md5: string = pickScriptField(script, 'SCRIPT_MD5');
  if (apiUrl.length === 0 || md5.length === 0) {
    out.error = '该脚本未声明更新接口';
    console.info('[RzdSourceUpdate] ' + apiId + ' no API_URL/SCRIPT_MD5');
    return out;
  }
  const url: string = apiUrl + '/script/lxmusic?checkUpdate=' + md5 +
    (apiKey.length > 0 ? ('&key=' + apiKey) : '');
  const req: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await req.request(url, {
      method: http.RequestMethod.GET,
      connectTimeout: UPDATE_CHECK_TIMEOUT,
      readTimeout: UPDATE_CHECK_TIMEOUT
    });
    const text: string = typeof resp.result === 'string' ? resp.result : JSON.stringify(resp.result);
    let body: Record<string, Object>;
    try {
      body = JSON.parse(text) as Record<string, Object>;
    } catch (_parseErr) {
      out.error = '更新接口返回异常';
      return out;
    }
    if (Number(body.code) !== 200) {
      out.error = '服务端返回 ' + String(body.code);
      console.info('[RzdSourceUpdate] ' + apiId + ' code=' + String(body.code));
      return out;
    }
    const data: Record<string, Object> | undefined = body.data as Record<string, Object> | undefined;
    if (data === undefined) {
      out.error = '已是最新版本';
      console.info('[RzdSourceUpdate] ' + apiId + ' up-to-date');
      return out;
    }
    out.hasUpdate = true;
    out.updateUrl = String(data.updateUrl ?? '');
    out.message = String(data.updateMsg ?? '');
    console.info('[RzdSourceUpdate] ' + apiId + ' update available url=' + out.updateUrl);
    return out;
  } catch (err) {
    out.error = '检查更新请求失败';
    console.info('[RzdSourceUpdate] ' + apiId + ' request failed');
    return out;
  } finally {
    req.destroy();
  }
}

/**
 * 检查更新并**自动下载覆盖**（「检查更新」按钮统一入口）。
 *
 * 流程：
 *   ① 主动请求脚本 checkUpdate 接口（脚本声明了 API_URL/SCRIPT_MD5 时）；
 *   ② 主动检查未命中时，读官方 updateAlert 兜底；
 *   ③ 有 updateUrl：下载脚本文本 → `lxSourceManager.importApi(script)` 原地覆盖
 *      （importApi 按 @name 去重：同版本跳过、不同版本替换并保留原 id 与选中状态）；
 *   ④ 下载内容不是音源脚本（网页/kdocs）→ 返回 openUrl，调用方跳浏览器兜底。
 *
 * @returns SourceUpdateApplyResult
 */
export async function checkAndApplySourceUpdate(api: LXUserApiInfo): Promise<SourceUpdateApplyResult> {
  const out: SourceUpdateApplyResult = new SourceUpdateApplyResult();
  let updateUrl: string = '';
  let updateMsg: string = '';

  // ① 主动检查（最可靠）
  const remote: SourceUpdateInfo = await checkSourceUpdateRemote(api.id);
  if (remote.hasUpdate && remote.updateUrl.length > 0) {
    updateUrl = remote.updateUrl;
    updateMsg = remote.message;
    console.info('[RzdSourceUpdate] ' + api.name + ' remote hasUpdate');
  }

  // ② 官方 alert 兜底（主动检查没命中时）
  if (updateUrl.length === 0) {
    const alert: SourceUpdateInfo = readOfficialUpdateAlert();
    if (alert.hasUpdate && alert.updateUrl.length > 0) {
      updateUrl = alert.updateUrl;
      updateMsg = alert.message;
      console.info('[RzdSourceUpdate] ' + api.name + ' alert fallback');
    }
  }

  // 都没有更新
  if (updateUrl.length === 0) {
    out.hasUpdate = false;
    out.applied = false;
    out.message = remote.error.length > 0 ? remote.error : '已是最新版本';
    return out;
  }

  // ③ 有更新：下载脚本并原地覆盖
  out.hasUpdate = true;
  const req: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await req.request(updateUrl, {
      method: http.RequestMethod.GET,
      connectTimeout: UPDATE_CHECK_TIMEOUT,
      readTimeout: UPDATE_CHECK_TIMEOUT,
      expectDataType: http.HttpDataType.STRING
    });
    if (resp.responseCode !== 200 || typeof resp.result !== 'string') {
      out.applied = false;
      out.message = '新版本下载失败，请检查网络';
      out.openUrl = updateUrl;
      return out;
    }
    const script: string = resp.result as string;
    if (script.length > UPDATE_DOWNLOAD_MAX_BYTES) {
      out.applied = false;
      out.message = '新版本脚本过大（超过 9MB）';
      out.openUrl = updateUrl;
      return out;
    }
    // importApi 同 @name 不同版本会原地替换（保留原 id 与选中状态）→ 自动覆盖更新
    const imported = lxSourceManager.importApi(script);
    if (imported.ok) {
      out.applied = true;
      out.message = '已更新：' + imported.message;
      console.info('[RzdSourceUpdate] ' + api.name + ' applied ok=' + imported.message);
      return out;
    }
    // ④ 内容不是脚本（网页/kdocs）：交回调用方跳浏览器
    out.applied = false;
    out.message = imported.message + '，已打开更新页';
    out.openUrl = updateUrl;
    return out;
  } catch (err) {
    out.applied = false;
    out.message = '下载失败，请检查网络';
    out.openUrl = updateUrl;
    return out;
  } finally {
    req.destroy();
  }
}
