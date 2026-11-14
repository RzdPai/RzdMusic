/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源更新检查的「代打」探测。
 *
 * 为什么需要它（2026-11-14 甲方：「有的源走的官方渠道，却不提示」）：
 * 为了让「未更新也能用」，引擎会拦截脚本自己的版本检查（见 `LXSourceEngine` 的
 * `UPDATE_MANIFEST_PATTERNS`）——拦掉之后脚本永远收不到新版本信息，于是它**不会**
 * 上报 `updateAlert`，设置页「检查更新」就只能沉默。这是个死结：
 *   放行 = 可能被"请更新后使用"挡住初始化（真机踩过）；
 *   拦截 = 永远查不到有没有新版本。
 *
 * 解法：**拦截照旧**（脚本行为不变、可用性不受影响），但把"被拦下的那条 URL"记下来，
 * 用户点「检查更新」时由应用**原样重放一次**这个请求拿真实结论。
 * 因为 URL 是从脚本自己的请求里抓的（含 `?ver=…` 等查询参数），不需要猜任何 URL 规则；
 * 而且只在用户主动点击时发，不做后台轮询。
 *
 * 解析策略（对未知 schema 保守处理）：
 * · 响应是 JSON ⇒ 递归找「名字像 update_url 的字段」里的 http(s) 地址；
 * · 找到地址 ⇒ `hasUpdate=true`（这是**唯一**敢说"有新版本"的依据）；
 * · 没找到地址但有 message/changelog ⇒ 如实体贴服务端原话（星海返回的
 *   `{"message":"你已是最新版本","update_url":null}` 就属这类），不自称"已是最新"；
 * · 请求失败 ⇒ 如实报错。
 */

import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

/** 更新接口里可能承载「更新地址」的字段名（全部小写比较）。 */
const URL_FIELDS: string[] = [
  'update_url', 'updateurl', 'update_link', 'updatelink', 'download_url', 'downloadurl',
  'new_url', 'newurl', 'latest_url', 'latesturl', 'url', 'link', 'href'
];

/** 承载「说明 / 版本」的字段名（按优先级挑第一个非空的）。 */
const MSG_FIELDS: string[] = [
  'changelog', 'message', 'msg', 'note', 'description', 'desc', 'content', 'update', 'version', 'ver'
];

/** 递归扫描的最大深度（避免病态响应把栈打穿）。 */
const MAX_DEPTH: number = 6;

/** 一次探测的结果。 */
export class SourceUpdateProbeResult {
  /** 拿到有效响应（HTTP 200 且解析出了内容）。 */
  ok: boolean = false;
  /** 响应里确实带了更新地址。**只有它为真才敢说"发现新版本"**。 */
  hasUpdate: boolean = false;
  /** 服务端原话 / 更新说明。 */
  message: string = '';
  /** 更新地址。 */
  updateUrl: string = '';
  /** 探测失败或无法判断的原因。 */
  error: string = '';
}

/** 是不是一个可打开的 http(s) 链接。 */
function isHttpUrl(v: string): boolean {
  return v.indexOf('http://') === 0 || v.indexOf('https://') === 0;
}

/**
 * 在任意 JSON 结构里找「像更新地址」的字符串。
 * @param node 当前节点
 * @param depth 当前深度
 * @returns 找到的地址；没找到返回空串
 */
function findUrlField(node: Object, depth: number): string {
  if (depth > MAX_DEPTH || node === null || node === undefined) {
    return '';
  }
  if (Array.isArray(node)) {
    const arr: Object[] = node as Object[];
    for (let i: number = 0; i < arr.length; i++) {
      const hit: string = findUrlField(arr[i], depth + 1);
      if (hit.length > 0) {
        return hit;
      }
    }
    return '';
  }
  // ⚠️ 这里**不能**把"任意 http 字符串"当命中：星海的响应里有个
  //   `ip_query_url: "https://…/ip.php"`，那样会被误判成"有新版本"。
  //   只认**字段名像更新地址**的那些（见下面的 URL_FIELDS），其余一律继续递归。
  if (typeof node !== 'object') {
    return '';
  }
  const rec: Record<string, Object> = node as Record<string, Object>;
  const keys: string[] = Object.keys(rec);
  // 先按"字段名像更新地址"精确找，找到就返回
  for (let i: number = 0; i < keys.length; i++) {
    const name: string = keys[i].toLowerCase();
    if (URL_FIELDS.indexOf(name) < 0) {
      continue;
    }
    const val: Object = rec[keys[i]];
    if (typeof val === 'string' && isHttpUrl(val as string)) {
      return val as string;
    }
  }
  // 再递归下去（响应常把内容套一层 data / result）
  for (let i: number = 0; i < keys.length; i++) {
    const hit: string = findUrlField(rec[keys[i]], depth + 1);
    if (hit.length > 0) {
      return hit;
    }
  }
  return '';
}

/**
 * 在任意 JSON 结构里找「说明文案」。
 * @param node 当前节点
 * @param depth 当前深度
 * @returns 找到的文案；没找到返回空串
 */
function findMessageField(node: Object, depth: number): string {
  if (depth > MAX_DEPTH || node === null || node === undefined || typeof node !== 'object') {
    return '';
  }
  if (Array.isArray(node)) {
    return '';
  }
  const rec: Record<string, Object> = node as Record<string, Object>;
  const keys: string[] = Object.keys(rec);
  for (let i: number = 0; i < MSG_FIELDS.length; i++) {
    const want: string = MSG_FIELDS[i];
    for (let j: number = 0; j < keys.length; j++) {
      if (keys[j].toLowerCase() !== want) {
        continue;
      }
      const val: Object = rec[keys[j]];
      if (typeof val === 'string' && (val as string).length > 0) {
        return val as string;
      }
    }
  }
  // 套了一层 data / result 的常见写法
  for (let j: number = 0; j < keys.length; j++) {
    const hit: string = findMessageField(rec[keys[j]], depth + 1);
    if (hit.length > 0) {
      return hit;
    }
  }
  return '';
}

/**
 * 原样重放脚本被拦截的那条版本检查请求，解析出「有没有新版本」。
 *
 * ⚠️ 只在用户主动点「检查更新」时调用，不做后台轮询。
 *
 * @param updateUrl 从脚本请求里抓到的完整 URL（含查询参数），空则直接失败
 * @param currentVersion 当前脚本版本，仅用于日志
 * @param timeoutMs 超时（默认 8s；源站的版本接口通常很快）
 * @returns 探测结果
 */
export async function probeScriptUpdate(updateUrl: string, currentVersion: string,
  timeoutMs: number = 8000): Promise<SourceUpdateProbeResult> {
  const out: SourceUpdateProbeResult = new SourceUpdateProbeResult();
  if (!isHttpUrl(updateUrl)) {
    out.error = '没有可用的更新检查地址';
    return out;
  }
  const request: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await request.request(updateUrl, {
      method: http.RequestMethod.GET,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    });
    if (resp.responseCode !== 200) {
      out.error = '更新接口返回 HTTP ' + resp.responseCode;
      return out;
    }
    let body: string = '';
    if (typeof resp.result === 'string') {
      body = resp.result as string;
    } else if (resp.result !== undefined && resp.result !== null) {
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      body = decoder.decodeToString(resp.result as Uint8Array);
    }
    if (body.length === 0) {
      out.error = '更新接口返回空内容';
      return out;
    }
    // JSON 优先；不是 JSON 就**不算探测成功**（我们判断不了，别假装查过了）
    let parsed: Object | null = null;
    try {
      parsed = JSON.parse(body) as Object;
    } catch (e) {
      parsed = null;
    }
    if (parsed === null) {
      out.error = '更新接口返回的不是 JSON，无法判断';
      return out;
    }
    out.ok = true;
    out.updateUrl = findUrlField(parsed, 0);
    out.message = findMessageField(parsed, 0);
    out.hasUpdate = out.updateUrl.length > 0;
    // 给日志留一条可核对的痕迹（版本号只用于人工对照）
    console.info('[RzdSourceUpdateProbe] ver=' + currentVersion +
      ' hasUpdate=' + out.hasUpdate + ' msg=' + out.message.substring(0, 80));
    return out;
  } catch (err) {
    out.error = '更新接口请求失败：' + ((err as Error).message ?? '');
    return out;
  } finally {
    request.destroy();
  }
}
