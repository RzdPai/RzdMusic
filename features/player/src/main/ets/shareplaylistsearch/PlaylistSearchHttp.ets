import { http } from '@kit.NetworkKit';

export class PlaylistSearchHttp {
  static async getText(url: string, headers?: Record<string, string>): Promise<string> {
    const client = http.createHttp();
    try {
      const resp: http.HttpResponse = await client.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 15000,
        header: headers
      });
      if (resp.responseCode === 200) {
        return resp.result as string;
      }
      return '';
    } catch (e) {
      throw new Error('歌单网络请求失败');
    } finally {
      client.destroy();
    }
  }
}

export function numOf(obj: Record<string, Object>, key: string): number {
  const v: Object = obj[key];
  if (v === undefined || v === null) {
    return 0;
  }
  return Number(v) || 0;
}

export function strOf(obj: Record<string, Object>, key: string): string {
  const v: Object = obj[key];
  if (v === undefined || v === null) {
    return '';
  }
  return decodeEntities(String(v));
}

export function decodeEntities(text: string): string {
  let t: string = text;
  const unicodeRe: RegExp = new RegExp('\\\\u([0-9a-fA-F]{4})', 'g');
  t = t.replace(unicodeRe, (m: string, hex: string): string => String.fromCharCode(parseInt(hex, 16)));
  const hexRe: RegExp = new RegExp('&#x([0-9a-fA-F]+);', 'g');
  t = t.replace(hexRe, (m: string, hex: string): string => String.fromCharCode(parseInt(hex, 16)));
  const numRe: RegExp = new RegExp('&#(\\d+);', 'g');
  t = t.replace(numRe, (m: string, num: string): string => String.fromCharCode(Number(num)));
  t = t.split('&nbsp;').join(' ').split('&amp;').join('&').split('&lt;').join('<')
    .split('&gt;').join('>').split('&quot;').join('"').split('&#39;').join("'").split('&apos;').join("'");
  return t;
}

export function toHttps(url: string): string {
  if (url.startsWith('http://')) {
    return 'https://' + url.substring(7);
  }
  return url;
}

export function fixSingleQuoteJson(text: string): string {
  return text.split("'").join('"');
}
