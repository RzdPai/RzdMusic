/*
 * Copyright (c) 2026 RzdPai
 *
 * 音源自更新（A4 配套）。
 *
 * 洛雪脚本的更新机制写在脚本自己里（见用户提供的 RzdMusic.js）：
 *   const API_URL / API_KEY / SCRIPT_MD5 = ...
 *   GET `${API_URL}/script/lxmusic?checkUpdate=${SCRIPT_MD5}&key=${API_KEY}`
 *   → { code:200, data:{ updateMsg, updateUrl } }
 * 脚本可以 `UPDATE_ENABLE=false` 关掉自检，所以由 App 代查。
 */

import { http } from '@kit.NetworkKit';
import { lxSourceManager } from 'player';

/** 一次检查的结果。 */
export class SourceUpdateInfo {
  /** 是否有新版本。 */
  hasUpdate: boolean = false;
  /** 服务端给的更新说明。 */
  message: string = '';
  /** 新版本脚本地址。 */
  updateUrl: string = '';
  /** 失败原因（hasUpdate=false 且 message 非空时用于提示）。 */
  error: string = '';
}

/** 从脚本文本里取一个常量：兼容 const/let/var、单双引号、反引号与多余空格。 */
function pick(text: string, key: string): string {
  const re: RegExp = new RegExp('(?:const|let|var)?\\s*' + key + '\\s*=\\s*["\'`]([^"\'`]+)["\'`]');
  const m: RegExpMatchArray | null = text.match(re);
  return m === null ? '' : m[1];
}

/** 取 API 根地址：不同脚本可能叫 API_URL / API_URI / BASE_URL / API。 */
function pickApiUrl(text: string): string {
  const keys: string[] = ['API_URL', 'API_URI', 'BASE_URL', 'API_HOST', 'API'];
  for (let i: number = 0; i < keys.length; i++) {
    const v: string = pick(text, keys[i]);
    if (v.length > 0 && (v.startsWith('http://') || v.startsWith('https://'))) {
      return v;
    }
  }
  return '';
}

/** 取 MD5：不同脚本可能叫 SCRIPT_MD5 / MD5 / SCRIPT_HASH。 */
function pickMd5(text: string): string {
  const keys: string[] = ['SCRIPT_MD5', 'MD5', 'SCRIPT_HASH', 'HASH'];
  for (let i: number = 0; i < keys.length; i++) {
    const v: string = pick(text, keys[i]);
    if (v.length >= 8) {
      return v;
    }
  }
  return '';
}

/**
 * 检查某个音源是否有更新（读本地脚本文本 → 提取 API_URL/API_KEY/SCRIPT_MD5 → 请求 checkUpdate）。
 * @param apiId 音源脚本 id
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
  const apiUrl: string = pickApiUrl(script);
  const apiKey: string = pick(script, 'API_KEY');
  const md5: string = pickMd5(script);
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
      connectTimeout: 8000,
      readTimeout: 8000
    });
    const text: string = typeof resp.result === 'string' ? resp.result : JSON.stringify(resp.result);
    const body: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
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