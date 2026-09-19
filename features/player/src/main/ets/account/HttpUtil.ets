import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_TAG: string = 'LXAccount';

export class HttpResult {
  statusCode: number = 0;
  body: string = '';
  setCookies: Map<string, string> = new Map();
}

export class HttpOptions {
  method: http.RequestMethod = http.RequestMethod.GET;
  headers: Map<string, string> = new Map();
  form: string = '';
  json: string = '';
  cookie: Map<string, string> = new Map();
  connectTimeout: number = 20000;
  readTimeout: number = 20000;
}

const IGNORED_COOKIE_KEYS: Set<string> = new Set(['path', 'domain', 'expires', 'max-age', 'samesite', 'secure', 'httponly']);

export function parseCookieString(value: string): Map<string, string> {
  const cookies: Map<string, string> = new Map();
  const parts: string[] = value.split(';');
  for (let i = 0; i < parts.length; i++) {
    const part: string = parts[i].trim();
    const eqIndex: number = part.indexOf('=');
    if (eqIndex <= 0) continue;
    const key: string = part.substring(0, eqIndex).trim();
    if (IGNORED_COOKIE_KEYS.has(key.toLowerCase())) continue;
    const cookieValue: string = part.substring(eqIndex + 1).trim();
    if (cookieValue.length > 0) cookies.set(key, cookieValue);
  }
  return cookies;
}

function parseSetCookieValue(value: string): Map<string, string> {
  const first: string = value.split(';')[0];
  const eqIndex: number = first.indexOf('=');
  if (eqIndex <= 0) return new Map();
  return new Map([[first.substring(0, eqIndex).trim(), first.substring(eqIndex + 1).trim()]]);
}

export function cookieStringify(cookies: Map<string, string>): string {
  const parts: string[] = [];
  cookies.forEach((value: string, key: string) => {
    parts.push(`${key}=${value}`);
  });
  return parts.join('; ');
}

function buildHeaderObject(headers: Map<string, string>): Record<string, string> {
  const result: Record<string, string> = {};
  headers.forEach((value: string, key: string) => {
    result[key] = value;
  });
  return result;
}

export async function httpFetch(url: string, options: HttpOptions): Promise<HttpResult> {
  const httpRequest: http.HttpRequest = http.createHttp();
  hilog.info(0x0000, LOG_TAG, 'http start: %{private}s', url);
  try {
    const header: Record<string, string> = buildHeaderObject(options.headers);
    if (options.cookie.size > 0) header['Cookie'] = cookieStringify(options.cookie);
    if (options.form.length > 0) header['Content-Type'] = 'application/x-www-form-urlencoded';
    if (options.json.length > 0) header['Content-Type'] = 'application/json';
    let extraData: string | undefined = undefined;
    if (options.json.length > 0) {
      extraData = options.json;
    } else if (options.form.length > 0) {
      extraData = options.form;
    }
    const requestOptions: http.HttpRequestOptions = {
      method: options.method,
      header: header,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: options.connectTimeout,
      readTimeout: options.readTimeout,
    };
    if (extraData !== undefined) requestOptions.extraData = extraData;
    const response: http.HttpResponse = await httpRequest.request(url, requestOptions);
    hilog.info(0x0000, LOG_TAG, 'http done: %{private}s status %{public}d', url, Number(response.responseCode));
    const result: HttpResult = new HttpResult();
    result.statusCode = Number(response.responseCode);
    result.body = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
    const headerRecord: Record<string, Object> = response.header as Record<string, Object>;
    let rawCookies: Object | undefined = undefined;
    for (const key of Object.keys(headerRecord)) {
      if (key.toLowerCase() === 'set-cookie') {
        rawCookies = headerRecord[key];
        break;
      }
    }
    if (rawCookies !== undefined) {
      const list: string[] = Array.isArray(rawCookies) ? (rawCookies as string[]) : [String(rawCookies)];
      for (let i = 0; i < list.length; i++) {
        const parsed: Map<string, string> = parseSetCookieValue(list[i]);
        parsed.forEach((value: string, key: string) => {
          result.setCookies.set(key, value);
        });
      }
    }
    return result;
  } catch (err) {
    const error: BusinessError = err as BusinessError;
    hilog.error(0x0000, LOG_TAG, 'http error: %{private}s %{private}s', url, error.message ?? '');
    throw new Error(`请求失败：${error.message ?? '网络异常'}`);
  } finally {
    httpRequest.destroy();
  }
}
