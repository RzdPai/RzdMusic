/*
 * 评论接口的 HTTP 与 JSON 小工具。
 *
 * 与 `features/player/src/main/ets/geuz/service/HttpUtils.ets` 的分工：
 * 那份服务的是「搜索 / 详情 / 歌词」那条链路（有它自己的 UA、错误文案）；
 * 评论接口的 UA、Content-Type、返回码语义都不一样，所以这里自带一套，
 * 并且 `features/comment` 不依赖 player（player 反过来要依赖 comment）。
 */

import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Md5 } from './Md5';

const DOMAIN: number = 0x0000;
export const COMMENT_TAG: string = 'RzdComment';

const DEFAULT_TIMEOUT: number = 15000;

/** GET 一个 JSON 接口。非 2xx 抛错（错误文案带上 what） */
export async function commentGetJson(url: string, headers: Record<string, string>,
  what: string): Promise<Record<string, Object>> {
  return await commentRequest(url, http.RequestMethod.GET, undefined, headers, what);
}

/** POST 一个 JSON 请求体。 */
export async function commentPostJson(url: string, body: Object, headers: Record<string, string>,
  what: string): Promise<Record<string, Object>> {
  return await commentRequest(url, http.RequestMethod.POST, JSON.stringify(body), headers, what);
}

/** POST 一个 `a=1&b=2` 表单（QQ 的老 fcg 接口只吃表单）。 */
export async function commentPostForm(url: string, form: Record<string, string>,
  headers: Record<string, string>, what: string): Promise<Record<string, Object>> {
  const parts: string[] = [];
  const keys: string[] = Object.keys(form);
  for (let i: number = 0; i < keys.length; i++) {
    const key: string = keys[i];
    parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(form[key]));
  }
  const merged: Record<string, string> = {
    'Content-Type': 'application/x-www-form-urlencoded'
  };
  const headerKeys: string[] = Object.keys(headers);
  for (let i: number = 0; i < headerKeys.length; i++) {
    merged[headerKeys[i]] = headers[headerKeys[i]];
  }
  return await commentRequest(url, http.RequestMethod.POST, parts.join('&'), merged, what);
}

async function commentRequest(url: string, method: http.RequestMethod, body: string | undefined,
  headers: Record<string, string>, what: string): Promise<Record<string, Object>> {
  const req: http.HttpRequest = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      connectTimeout: DEFAULT_TIMEOUT,
      readTimeout: DEFAULT_TIMEOUT
    };
    if (body !== undefined) {
      options.extraData = body;
    }
    const resp: http.HttpResponse = await req.request(url, options);
    const text: string = typeof resp.result === 'string' ? resp.result as string : '';
    if (resp.responseCode !== 200 || text.length === 0) {
      hilog.warn(DOMAIN, COMMENT_TAG, '%{public}s HTTP %{public}d len=%{public}d',
        what, resp.responseCode, text.length);
      throw new Error(`${what}失败（HTTP ${resp.responseCode}）`);
    }
    try {
      return JSON.parse(text) as Record<string, Object>;
    } catch (_err) {
      throw new Error(`${what}失败（返回的不是 JSON）`);
    }
  } finally {
    req.destroy();
  }
}

/** 字符串原样返回；数字 / 布尔转成字符串（平台有的给数字码、有的给字符串码）。 */
export function asString(value: Object | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number') {
    return String(value);
  }
  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }
  return '';
}

/** 取数字，取不到就用 fallback（评论里用 -1 表示「平台没给这个数」）。 */
export function asNumber(value: Object | undefined, fallback: number): number {
  if (value === undefined || value === null) {
    return fallback;
  }
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') {
    const parsed: number = Number(value);
    return Number.isNaN(parsed) ? fallback : parsed;
  }
  return fallback;
}

/** 取对象（不是对象就给空对象，避免到处判空）。 */
export function asRecord(value: Object | undefined): Record<string, Object> {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, Object>;
}

/** 取对象数组（不是数组就给空数组）。 */
export function asObjectArray(value: Object | undefined): Object[] {
  if (value === undefined || value === null || !Array.isArray(value)) {
    return [];
  }
  return value as Object[];
}

/** HTML 实体解码（酷狗 / 酷我的评论文本里带实体）。 */
export function decodeName(text: string): string {
  return text.replace(/&apos;/g, '\'').replace(/&quot;/g, '"').replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&nbsp;/g, ' ');
}

/** 字符串的 MD5（小写十六进制），酷狗评论签名用。 */
export function md5Hex(text: string): string {
  const encoder: util.TextEncoder = new util.TextEncoder();
  const bytes: Uint8Array = encoder.encodeInto(text);
  return Md5.hex(bytes);
}
