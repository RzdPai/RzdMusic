/*
 * Copyright (c) 2026 RzdPai
 *
 * QuickJS 侧的**宿主能力桥**（双引擎 Phase 3 的最小可用实现）。
 *
 * ── 它是干什么的 ─────────────────────────────────────────────────────────────
 * `QuickJsRuntime` 的投递箱只会吐出 `{id, method, args}`；真正干活的是这里：
 * 把每一次宿主调用翻译成 ArkTS 的真实动作，再把结果回填给 JS 侧那个 Promise。
 *
 * 支持的宿主方法（与 `lx_bridge.html` 里 WebView 那套**同一个契约**，只是实现不同）：
 *   · `request`  → `http.createHttp()`，返回 `{statusCode,statusMessage,headers,body,raw}`
 *   · `send`     → `inited` / `updateAlert`（脚本把自己的能力登记上来）
 *   · `fetch`    → 同上，返回简化形状
 *   · `crypto.md5` / `crypto.randomBytes` / `buffer.*`
 *
 * 为什么单独一个文件：交接书 §4.4 说"必须补齐的宿主能力是本方案最大的工作量"。
 * 那批能力最终要么给 WebView 用、要么给 QuickJS 用，**不应该写两遍** ——
 * 这里是唯一实现，`lx_bridge.html` 那边后续也收敛到同一份语义。
 *
 * ⚠️ 现状：只够跑**脚本初始化**（`lx.send('inited')`）和普通的 GET/POST 请求。
 * XHR、DOM 桩、定时器、`localStorage` 都还没有 —— 那是把引擎真正切过去之前必须补的。
 */

import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import CryptoJS from '@ohos/crypto-js';
import { appendPlayLog } from 'musicbasic';
import { QuickJsCall, QuickJsRuntime } from './QuickJsRuntime';

/** LX 脚本 `lx.send('inited', …)` 上报的能力。 */
export class LxScriptInitInfo {
  /** 是否收到过 inited */
  inited: boolean = false;
  /** 平台 id 列表（脚本声明的） */
  platforms: string[] = [];
  /** 每个平台声明支持的音质（`{kw:['128k','320k'], …}`） */
  qualitys: Map<string, string[]> = new Map<string, string[]>();
  /** `send` 里带上来的其它字段（原样保留，便于排查） */
  raw: string = '';
}

/** 一次「把脚本跑在 QuickJS 里」的结果。 */
export class QuickJsRunResult {
  ok: boolean = false;
  /** `lx.send('inited')` 是否到达 */
  inited: boolean = false;
  /** 平台列表 */
  platforms: string[] = [];
  /** 从建引擎到脚本上报 inited 的耗时（ms）；-1 = 没测到 */
  elapsedMs: number = -1;
  /** 处理了多少次宿主调用（含网络） */
  hostCalls: number = 0;
  /** 失败原因（ok=false 时有值） */
  error: string = '';
}

/** 宿主调用里 `request` 的最大并发（脚本初始化阶段一般就用 1~3 个）。 */
const MAX_SOCKET: number = 3;

/** 把 `Record<string, Object>` 的头信息原样转成小写键（与 WebView 侧契约一致）。 */
function lowerCaseHeaders(headers: Record<string, Object>): Record<string, string> {
  const out: Record<string, string> = {};
  const keys: string[] = Object.keys(headers);
  for (let i: number = 0; i < keys.length; i++) {
    const v: Object = headers[keys[i]];
    out[keys[i].toLowerCase()] = typeof v === 'string' ? v as string : JSON.stringify(v);
  }
  return out;
}

/** 解析 `args` JSON（失败返回空对象，不抛）。 */
function parseArgs(args: string): Record<string, Object> {
  try {
    const v: Object = JSON.parse(args) as Object;
    return (v === null || typeof v !== 'object') ? {} : v as Record<string, Object>;
  } catch (_e) {
    return {};
  }
}

/**
 * `lx.request` 的失败应答（形状与成功一致，脚本不用分支判断）。
 * @param message 失败原因（写进 statusMessage）
 */
function requestFailure(message: string): string {
  // ArkTS 禁止无类型对象字面量、且 null 不能赋给 Object ⇒ 逐字段赋值，headers 给空串
  // （脚本侧只会 `JSON.parse` 后按需取字段，空串能安全兜住）
  const payload: Record<string, Object> = {};
  payload['statusCode'] = 0;
  payload['statusMessage'] = message;
  payload['headers'] = '';
  payload['body'] = '';
  payload['raw'] = '';
  return JSON.stringify(payload);
}

/**
 * 执行一次 `lx.request`（与 WebView 侧返回形状一致）。
 * @param argsJson `{url, options}` 的 JSON
 * @returns 结果对象的 JSON 字符串（永远是可解析的）
 */
async function doRequest(argsJson: string): Promise<string> {
  const args: Record<string, Object> = parseArgs(argsJson);
  const url: string = (args['url'] as string) ?? '';
  const opts: Record<string, Object> = (args['options'] as Record<string, Object>) ?? {};
  if (url.length < 8) {
    return requestFailure('Bad url');
  }
  const method: string = ((opts['method'] as string) ?? 'GET').toUpperCase();
  const headersIn: Record<string, Object> = (opts['headers'] as Record<string, Object>) ?? {};
  const body: string = (opts['body'] as string) ?? '';
  const timeout: number = (opts['timeout'] as number) ?? 15000;
  const req: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await req.request(url, {
      method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
      header: headersIn,
      extraData: body.length > 0 ? body : undefined,
      connectTimeout: timeout,
      readTimeout: timeout,
      expectDataType: http.HttpDataType.STRING
    });
    const raw: string = typeof resp.result === 'string' ? resp.result as string : '';
    let parsed: Object | null = null;
    try {
      parsed = JSON.parse(raw) as Object;
    } catch (_e) {
      parsed = null;
    }
    const payload: Record<string, Object> = {
      'statusCode': resp.responseCode,
      'statusMessage': resp.responseCode === 200 ? 'OK' : String(resp.responseCode),
      'headers': lowerCaseHeaders(resp.header as Record<string, Object>),
      'body': parsed === null ? raw : parsed,
      'raw': raw
    };
    return JSON.stringify(payload);
  } catch (e) {
    return requestFailure(e instanceof Error ? e.message : 'request failed');
  } finally {
    try {
      req.destroy();
    } catch (_e) {
      // 请求已结束：destroy 幂等失败无意义
    }
  }
}

/** md5（脚本里用得最多的一类：签名/去重）。失败返回空串。 */
function md5Of(text: string): string {
  try {
    // 用 Node 风格实现太重；这里走 @ohos/crypto-js 的 MD5（player 已依赖）
    return CryptoJS.MD5(text).toString();
  } catch (e) {
    appendPlayLog('[qjs] md5 失败: ' + JSON.stringify(e).substring(0, 100));
    return '';
  }
}

/** 随机字节 → base64。 */
function randomBytesBase64(n: number): string {
  try {
    const len: number = n > 0 ? n : 16;
    const bytes: Uint8Array = cryptoFramework.createRandom().generateRandomSync(len).data;
    return new util.Base64Helper().encodeToStringSync(bytes);
  } catch (e) {
    appendPlayLog('[qjs] randomBytes 失败: ' + JSON.stringify(e).substring(0, 100));
    return '';
  }
}

/**
 * 宿主调用处理器：把 `QuickJsRuntime.drain()` 吐出来的调用逐个执行并回填。
 *
 * 用法（典型循环）：
 * ```ts
 * let rounds = 0;
 * while (rounds++ < 40) {
 *   const calls = rt.drain();
 *   if (calls.length === 0) break;
 *   await handleHostCalls(rt, calls, initInfo);
 * }
 * ```
 */
export async function handleHostCalls(rt: QuickJsRuntime, calls: QuickJsCall[],
  initInfo: LxScriptInitInfo): Promise<number> {
  for (let i: number = 0; i < calls.length; i++) {
    const call: QuickJsCall = calls[i];
    try {
      switch (call.method) {
        case 'request': {
          const json: string = await doRequest(call.args);
          rt.resolve(call.id, json, true);
          break;
        }
        case 'fetch': {
          const json: string = await doRequest(call.args);
          rt.resolve(call.id, json, true);
          break;
        }
        case 'send': {
          const args: Record<string, Object> = parseArgs(call.args);
          const event: string = (args['event'] as string) ?? '';
          const data: Record<string, Object> = (args['data'] as Record<string, Object>) ?? {};
          if (event === 'inited') {
            collectInitInfo(data, initInfo);
          } else if (event === 'updateAlert') {
            appendPlayLog('[qjs] 脚本上报 updateAlert: ' +
              (data['log'] !== undefined ? String(data['log']).substring(0, 80) : '(no log)'));
          }
          rt.resolve(call.id, 'true', true);
          break;
        }
        case 'crypto.md5': {
          const args: Record<string, Object> = parseArgs(call.args);
          rt.resolve(call.id, JSON.stringify(md5Of(String(args['s'] ?? ''))), true);
          break;
        }
        case 'crypto.randomBytes': {
          const args: Record<string, Object> = parseArgs(call.args);
          rt.resolve(call.id, JSON.stringify(randomBytesBase64(Number(args['n'] ?? 16))), true);
          break;
        }
        case 'buffer.from': {
          const args: Record<string, Object> = parseArgs(call.args);
          const v: string = String(args['v'] ?? '');
          rt.resolve(call.id, JSON.stringify(new util.Base64Helper().encodeToStringSync(
            new util.TextEncoder().encodeInto(v))), true);
          break;
        }
        case 'buffer.toString': {
          const args: Record<string, Object> = parseArgs(call.args);
          const b64: string = String(args['buf'] ?? '');
          try {
            const bytes: Uint8Array = new util.Base64Helper().decodeSync(b64);
            rt.resolve(call.id, JSON.stringify(util.TextDecoder.create('utf-8').decodeToString(bytes)), true);
          } catch (_e) {
            rt.resolve(call.id, JSON.stringify(''), true);
          }
          break;
        }
        default:
          // 未实现的宿主能力：**明确拒绝**，脚本能自己兜住（比静默挂住好）
          appendPlayLog('[qjs] 未实现的宿主调用: ' + call.method);
          rt.resolve(call.id, JSON.stringify('unsupported host call: ' + call.method), false);
          break;
      }
    } catch (e) {
      appendPlayLog('[qjs] 宿主调用异常 ' + call.method + ': ' + JSON.stringify(e).substring(0, 120));
      rt.resolve(call.id, JSON.stringify(String(e)), false);
    }
  }
  return calls.length;
}

/** 把 `inited` 里的 sources 收进 initInfo。 */
function collectInitInfo(data: Record<string, Object>, initInfo: LxScriptInitInfo): void {
  initInfo.inited = true;
  initInfo.raw = JSON.stringify(data).substring(0, 4000);
  const sources: Record<string, Object> | undefined = data['sources'] as Record<string, Object>;
  if (sources === undefined || sources === null) {
    return;
  }
  const keys: string[] = Object.keys(sources);
  for (let i: number = 0; i < keys.length; i++) {
    const key: string = keys[i];
    const src: Record<string, Object> = sources[key] as Record<string, Object>;
    if (src === null || src === undefined) {
      continue;
    }
    if ((src['type'] as string) !== 'music') {
      continue;
    }
    initInfo.platforms.push(key);
    const qs: Object = src['qualitys'];
    if (qs !== undefined && qs !== null && Array.isArray(qs)) {
      initInfo.qualitys.set(key, (qs as Object[]).map((x: Object): string => String(x)));
    }
  }
}

/**
 * 「把这支脚本真正跑在 QuickJS 里」——Phase 4 灰度要比的就是这个数。
 *
 * 做四件事：建引擎 → 装宿主桥 → eval 脚本 → 循环「drain → 执行宿主调用 → 回填」，
 * 直到脚本 `lx.send('inited')` 上报、或者超时/轮次用完。
 *
 * @param scriptText 脚本原文
 * @param timeoutMs 总预算（默认 4000ms）
 */
export async function runScriptInQuickJs(scriptText: string, timeoutMs: number = 4000): Promise<QuickJsRunResult> {
  const out: QuickJsRunResult = new QuickJsRunResult();
  const started: number = Date.now();
  const rt: QuickJsRuntime = new QuickJsRuntime();
  try {
    if (!rt.start('script')) {
      out.error = '引擎启动失败';
      return out;
    }
    // 脚本常把自己挂到 `globalThis.` 上；直接 eval 即可（PRELUDE 已装好 lx/fetch/atob）
    rt.evaluate(scriptText, 'lx_script.js');
    const initInfo: LxScriptInitInfo = new LxScriptInitInfo();
    let rounds: number = 0;
    while (Date.now() - started < timeoutMs && rounds < 60) {
      rounds++;
      const calls: QuickJsCall[] = rt.drain();
      if (calls.length > 0) {
        out.hostCalls += await handleHostCalls(rt, calls, initInfo);
      }
      if (initInfo.inited) {
        out.inited = true;
        break;
      }
      // 让出事件循环：网络请求要等回调（QuickJS 里没有定时器，只能由这里驱动）
      await sleep(calls.length > 0 ? 8 : 24);
    }
    out.elapsedMs = Date.now() - started;
    out.platforms = initInfo.platforms;
    out.ok = initInfo.inited;
    if (!out.inited) {
      out.error = '脚本没有在 ' + timeoutMs + 'ms 内上报 inited（可能依赖 WebView 专有 API）';
    }
    appendPlayLog('[qjs] 跑脚本完成 ok=' + out.ok + ' 平台=' + out.platforms.length +
      ' 宿主调用=' + out.hostCalls + ' 耗时=' + out.elapsedMs + 'ms' +
      (out.ok ? '' : ' 原因=' + out.error));
    return out;
  } catch (e) {
    out.error = JSON.stringify(e).substring(0, 160);
    appendPlayLog('[qjs] 跑脚本抛异常: ' + out.error);
    return out;
  } finally {
    rt.release();
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, ms);
  });
}

/** 允许的并发上限（当前未使用，留给后续批量请求调度）。 */
export const QUICKJS_MAX_SOCKET: number = MAX_SOCKET;
