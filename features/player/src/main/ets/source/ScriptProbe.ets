/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * 音源脚本能力探测。
 *
 * 用途：决定某个脚本能不能跑在「不带 DOM 的运行时」（QuickJS / 纯 API 环境）上。
 * 分界线是**脚本能力**，不是品牌 —— LX 订阅脚本可能用 `document` 做 HTML 嗅探，
 * MusicFree 插件只有 `require('cheerio')` 的那部分才真的需要 DOM。
 *
 * 约束（务必遵守）：
 * 1. **纯静态文本扫描，绝不执行脚本**：这里只做 indexOf，不 eval、不 JSON.parse 载荷。
 * 2. **宁可误判有，不可漏判无**：判成「需要 DOM」只是多占一个 WebView（功能正常）；
 *    漏判会让脚本直接 ReferenceError（音源整个不可用）。所以 `document` 这个词
 *    **出现在字符串常量里也算命中**，不做语法分析。
 * 3. 不缓存、不落盘：由调用方决定要不要记住结果。
 */

/** 脚本能力画像。 */
export interface ScriptProfile {
  /** 是否需要 DOM（决定能不能离开 WebView）。 */
  needsDom: boolean;
  /** 是否用到 Web Crypto（crypto.subtle），QuickJS 侧未补齐时必须留在 WebView。 */
  needsWebCrypto: boolean;
  /** 是否用到压缩流（Compression/DecompressionStream），QuickJS 侧未补齐时必须留在 WebView。 */
  needsCompression: boolean;
  /**
   * 是否直接用 `XMLHttpRequest`（不走 `lx.request`）。
   * ★ 2026-11-15：**不再阻断 QuickJS** —— PRELUDE 已提供 XHR 垫片（转成宿主 http 调用）。
   *   单独记下来只为了在日志里说明"这支脚本用了 XHR，走的是垫片"。
   */
  needsXhr: boolean;
  /**
   * 是否用 WebSocket。（QuickJS 侧**没有**实现，也难在不引入真实 socket 的情况下实现
   * —— 目前判为「必须 WebView」。）
   */
  needsWebSocket: boolean;
  /** 命中的关键词（最多 {@link MAX_REASON} 个），只用于日志排查。 */
  reason: string;
}

/** `reason` 里最多列几个命中词，避免日志被长脚本刷爆。 */
const MAX_REASON: number = 4;

/**
 * DOM 依赖关键词（全部小写，与 `script.toLowerCase()` 比较）。
 * 刻意放宽：`document` 单独一项就能覆盖 `document.` / `documentElement` / 字符串里的 `document`。
 */
const DOM_KEYS: string[] = [
  'document',
  'domparser',
  'innerhtml',
  'outerhtml',
  'queryselector',
  'createelement',
  'require(\'cheerio\')',
  'require("cheerio")',
  'cheerio'
];

/** Web Crypto 关键词。 */
const CRYPTO_KEYS: string[] = [
  'crypto.subtle',
  'mscrypto.subtle'
];

/** 压缩流关键词。 */
const COMPRESSION_KEYS: string[] = [
  'decompressionstream',
  'compressionstream'
];

/** XHR 关键词（有垫片 ⇒ 不阻断 QuickJS，只做记录）。 */
const XHR_KEYS: string[] = [
  'xmlhttprequest'
];

/** WebSocket 关键词（QuickJS 侧未实现 ⇒ 阻断）。 */
const WEBSOCKET_KEYS: string[] = [
  'websocket'
];

/**
 * 扫描一组关键词，返回命中的第一个（未命中返回空串）。
 * @param haystack 已转小写的脚本文本。
 * @param keys 关键词表（小写）。
 * @param hits 命中收集器，便于一次产出完整的 reason。
 * @returns 是否命中至少一个关键词。
 */
function scanKeys(haystack: string, keys: string[], hits: string[]): boolean {
  let matched: boolean = false;
  for (let i: number = 0; i < keys.length; i++) {
    const key: string = keys[i];
    if (haystack.indexOf(key) >= 0) {
      matched = true;
      if (hits.indexOf(key) < 0 && hits.length < MAX_REASON) {
        hits.push(key);
      }
    }
  }
  return matched;
}

/**
 * 探测脚本需要哪些「WebView 专属」能力。
 *
 * 复杂度 O(n·k)（n = 脚本长度，k = 关键词条数，共 15 条），对 1.6 MB 的 LX 脚本
 * 是十几次 indexOf，毫秒级，可以在脚本装载时同步调用。
 *
 * @param script 脚本原文（Lua/JS 订阅脚本或 MusicFree 插件源码）。
 * @returns 能力画像；`script` 为空串时三项均为 false（空脚本没有依赖）。
 */
export function probeScript(script: string): ScriptProfile {
  if (script.length === 0) {
    return { needsDom: false, needsWebCrypto: false, needsCompression: false,
      needsXhr: false, needsWebSocket: false, reason: '' };
  }
  // 只转一次小写：关键词全小写，脚本里大小写混写都要认（`document` / `Document` / `DOCUMENT`）。
  const haystack: string = script.toLowerCase();
  const hits: string[] = [];
  const needsDom: boolean = scanKeys(haystack, DOM_KEYS, hits);
  const needsWebCrypto: boolean = scanKeys(haystack, CRYPTO_KEYS, hits);
  const needsCompression: boolean = scanKeys(haystack, COMPRESSION_KEYS, hits);
  const needsXhr: boolean = scanKeys(haystack, XHR_KEYS, hits);
  const needsWebSocket: boolean = scanKeys(haystack, WEBSOCKET_KEYS, hits);
  return {
    needsDom: needsDom,
    needsWebCrypto: needsWebCrypto,
    needsCompression: needsCompression,
    needsXhr: needsXhr,
    needsWebSocket: needsWebSocket,
    reason: hits.join(',')
  };
}

/**
 * 该脚本能否跑在「无 DOM 运行时」上（QuickJS 路径的准入条件）。
 * @param profile 探测结果。
 * @returns 三项能力都不需要时为 true。
 */
export function canRunWithoutWebView(profile: ScriptProfile): boolean {
  // ★ 2026-11-15（用户：「是特性，不是整个脚本」）——按**能力**判，不是按脚本整体一刀切：
  //   · XHR：PRELUDE 有垫片（转宿主 http）⇒ 不阻断；
  //   · DOM / WebCrypto / CompressionStream / WebSocket：QuickJS 侧确实提供不了 ⇒ 阻断。
  //   以后每补齐一项能力，就从这里去掉一个条件 —— 这就是"按特性混合"的进度条。
  return !profile.needsDom && !profile.needsWebCrypto &&
    !profile.needsCompression && !profile.needsWebSocket;
}

/**
 * 生成一行可读的探测摘要，供日志使用。
 * @param profile 探测结果。
 * @returns 形如 `dom=false crypto=false zip=false reason=-` 的字符串。
 */
export function formatProfile(profile: ScriptProfile): string {
  const reason: string = profile.reason.length > 0 ? profile.reason : '-';
  // xhr 只做记录（有垫片，不阻断）；ws 阻断（QuickJS 侧未实现）
  return 'dom=' + profile.needsDom + ' crypto=' + profile.needsWebCrypto +
    ' zip=' + profile.needsCompression + ' xhr=' + profile.needsXhr +
    ' ws=' + profile.needsWebSocket + ' reason=' + reason;
}
