/*
 * Copyright (c) 2026 RzdPai
 *
 * QuickJS 引擎运行时（双引擎重构 Phase 1 的落地件）。
 *
 * ── 为什么现在有这个文件 ────────────────────────────────────────────────────
 * 交接书 `docs/双引擎重构交接书-20261114.md` 的 Phase 1 是「把 QuickJS 编进来」，
 * 原先估的代价主要在**交叉编译 QuickJS + 自己写 NAPI 绑定**。这两件都不用做了：
 * 社区已有 HAR `@devzeng/quickjs`（ohpm，`compatibleSdkVersion 12`、
 * `byteCodeHar` + `useNormalizedOHMUrl`，与本工程一致），预编译好 `libquickjs.so`。
 * 源码也在 `参考项目/ohos_quickjs/`（同一仓库 `hhtczengjing/ohos_quickjs`），要打补丁随时改。
 *
 * ── 它给了什么 / 没给什么 ───────────────────────────────────────────────────
 * 给了：`JSContext` / `JSValue`（JavaScriptCore 风格），`evaluateScript`、属性读写、
 *      `callWithArguments`、异常与 `errorStack`。44 个 NAPI 导出，够跑脚本。
 * **没给**：把 ArkTS 回调注册成 JS 函数的能力（没有 `createNativeFunction`）。
 *      ⇒ 宿主能力（`lx.request` / `lx.send` / `lx.on` / `fetch` …）不能直接注入，
 *        必须用下面这套 **"投递箱"协议**（Phase 2 的最小可行实现）：
 *
 *   1. ArkTS 先 `evaluateScript(PRELUDE)` 装上 `lx`/`fetch` 等桩函数；
 *   2. 桩函数把调用**塞进 JS 侧的 `__qjsOutbox` 数组**并登记一个 Promise 的 resolve；
 *   3. ArkTS 在每次 `evaluateScript` 之后调 `drain()`（一次 `__qjsDrain()`），
 *      拿到 JSON 数组 `[{id, method, args}, …]`；
 *   4. ArkTS 做完异步活儿再 `resolve(id, json)`（一次 `__qjsResolve(id, json)`）。
 *
 *   没有轮询、没有定时器：**一次 JS 调用最多多两次 evaluateScript**。
 *   QuickJS 本身没有事件循环，不能 `setInterval`，这也是它必须在 ArkTS 侧驱动的原因。
 *
 * ── 现在到哪一步了 ─────────────────────────────────────────────────────────
 * 只做了 Phase 1 + 协议骨架，并且**没有接进播放链路**。
 * `quickJsSelfTest()` 会在启动日志里留下一条 `[qjs] …`，用来在真机上确认
 * 「.so 能加载 / 引擎能建 / 脚本能跑 / 投递箱能往返」。看到 `ok` 才谈得上继续迁移。
 */

import { JSContext, JSValue } from '@devzeng/quickjs';
import { appendPlayLog } from 'musicbasic';

/** 一次被 JS 侧投递出来的宿主调用。 */
export class QuickJsCall {
  /** 投递序号（JS 侧自增，用来找回对应的 Promise resolve） */
  id: number = 0;
  /** 宿主方法名：`request` / `send` / `fetch` … */
  method: string = '';
  /** JSON 字符串形式的参数（避免 ArkTS ↔ JS 之间做复杂结构转换） */
  args: string = '';
}

/**
 * 装进 JS 全局的宿主桥（纯 JS，无 DOM 依赖）。
 *
 * 设计要点：
 * - 每个宿主调用都返回 **Promise**，与上游 LX 的 `lx.request/lx.send` 语义一致；
 * - 出栈用数组 + 自增 id，ArkTS 侧按 id 回填，天然支持并发；
 * - 所有参数/返回值都走 JSON 字符串，不做跨语言对象映射（快、也不会因为
 *   `Record<string, Object>` 的深拷贝出幺蛾子）；
 * - `lx.on()` 对未知事件**静默 resolve**（与 `lx_bridge.html` 里 2026-11-15 的修正保持一致）。
 */
const PRELUDE: string = `
(function () {
  if (globalThis.__qjsReady) { return; }
  globalThis.__qjsReady = true;
  var outbox = [];
  var pending = Object.create(null);
  var seq = 0;
  var handlers = Object.create(null);

  globalThis.__qjsCall = function (method, args) {
    var id = ++seq;
    outbox.push({ id: id, method: method, args: JSON.stringify(args === undefined ? null : args) });
    return new Promise(function (resolve, reject) { pending[id] = { resolve: resolve, reject: reject }; });
  };

  // ArkTS 侧调用：取走当前所有待处理的宿主调用
  globalThis.__qjsDrain = function () {
    var out = outbox;
    outbox = [];
    return JSON.stringify(out);
  };

  // ArkTS 侧调用：回填结果（ok=false 时走 reject）
  globalThis.__qjsResolve = function (id, dataJson, ok) {
    var p = pending[id];
    if (!p) { return; }
    delete pending[id];
    var value;
    try { value = JSON.parse(dataJson); } catch (e) { value = dataJson; }
    if (ok === false) { p.reject(value); } else { p.resolve(value); }
  };

  var SUPPORTED_EVENTS = { request: 1, inited: 1, updateAlert: 1 };

  globalThis.lx = {
    request: function (url, options, callback) {
      if (typeof callback === 'function') {
        // 老式回调风格：包一层
        globalThis.__qjsCall('request', { url: url, options: options }).then(
          function (r) { callback(null, r); }, function (e) { callback(e, null); });
        return;
      }
      return globalThis.__qjsCall('request', { url: url, options: options });
    },
    send: function (eventName, data) { return globalThis.__qjsCall('send', { event: eventName, data: data }); },
    on: function (eventName, handler) {
      if (!SUPPORTED_EVENTS[eventName]) {
        // 未知事件静默放行（上游 LX 同行为；reject 会变成 unhandled rejection 打断脚本初始化）
        return Promise.resolve();
      }
      handlers[eventName] = handler;
      return Promise.resolve();
    },
    // 宿主 → 脚本的事件派发入口
    __emit: function (eventName, dataJson) {
      var h = handlers[eventName];
      if (!h) { return; }
      try { h(JSON.parse(dataJson)); } catch (e) { /* 脚本自己的错，不往上抛 */ }
    },
    version: '2.0.0',
    env: 'mobile',
    currentScriptInfo: { name: '', description: '', version: '', author: '', homepage: '' },
    utils: {
      crypto: {
        // 先用占位：真正的 md5/randomBytes 由 ArkTS 侧通过 __qjsCall('crypto', …) 提供
        md5: function (s) { return globalThis.__qjsCall('crypto.md5', { s: s }); },
        randomBytes: function (n) { return globalThis.__qjsCall('crypto.randomBytes', { n: n }); },
        aesEncrypt: function (buf, mode, key, iv) {
          return globalThis.__qjsCall('crypto.aesEncrypt', { buf: buf, mode: mode, key: key, iv: iv });
        },
        rsaEncrypt: function (buf, key) { return globalThis.__qjsCall('crypto.rsaEncrypt', { buf: buf, key: key }); }
      },
      buffer: {
        from: function (v, enc) { return globalThis.__qjsCall('buffer.from', { v: v, enc: enc }); },
        bufToString: function (buf, enc) { return globalThis.__qjsCall('buffer.toString', { buf: buf, enc: enc }); }
      }
    }
  };

  // LX 脚本里常见的几个 globals（QuickJS 里没有 DOM，但脚本会直接摸）
  if (typeof globalThis.fetch !== 'function') {
    globalThis.fetch = function (url, options) { return globalThis.__qjsCall('fetch', { url: url, options: options }); };
  }
  if (typeof globalThis.atob !== 'function') {
    // atob/btoa 是同步的、且脚本里用得极多 ⇒ 用 QuickJS 自带能力实现，不走投递箱
    globalThis.atob = function (b64) {
      var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
      var str = String(b64).replace(/[\\s=]+/g, '');
      var out = '';
      for (var i = 0; i < str.length; i += 4) {
        var e1 = chars.indexOf(str.charAt(i)), e2 = chars.indexOf(str.charAt(i + 1)),
            e3 = chars.indexOf(str.charAt(i + 2)), e4 = chars.indexOf(str.charAt(i + 3));
        out += String.fromCharCode(((e1 << 2) | (e2 >> 4)) & 0xff);
        if (e3 !== -1 && e3 !== 64) { out += String.fromCharCode(((e2 << 4) | (e3 >> 2)) & 0xff); }
        if (e4 !== -1 && e4 !== 64) { out += String.fromCharCode(((e3 << 6) | e4) & 0xff); }
      }
      return out;
    };
  }
  if (typeof globalThis.btoa !== 'function') {
    globalThis.btoa = function (s) {
      var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
      var str = String(s), out = '';
      for (var i = 0; i < str.length; i += 3) {
        var c1 = str.charCodeAt(i), c2 = str.charCodeAt(i + 1), c3 = str.charCodeAt(i + 2);
        out += chars.charAt(c1 >> 2) + chars.charAt(((c1 & 3) << 4) | (isNaN(c2) ? 0 : c2 >> 4));
        out += isNaN(c2) ? '=' : (chars.charAt(((c2 & 15) << 2) | (isNaN(c3) ? 0 : c3 >> 6)));
        out += isNaN(c2) || isNaN(c3) ? '=' : chars.charAt(c3 & 63);
      }
      return out;
    };
  }
})();
`;

/**
 * 一个 QuickJS 运行时实例（= 一支 LX 脚本自己的上下文）。
 *
 * 生命周期：`new` → `installBridge()` → 反复 `evaluate/drain/resolve` → `release()`。
 * ⚠️ 与 WebView 相比**没有 DOM、没有 XHR、没有定时器**，脚本里凡是摸 `document`/`window.setTimeout`
 * 的地方都要靠 PRELUDE 里的桩兜住 —— 这就是交接书 §4.4 说的"必须补齐的宿主能力"，
 * 现在只补了最小集（lx / fetch / atob / btoa）。
 */
export class QuickJsRuntime {
  private ctx: JSContext | null = null;
  private released: boolean = false;

  /** @returns 引擎是否已就绪 */
  public isReady(): boolean {
    return this.ctx !== null && !this.released;
  }

  /** 建上下文并装上宿主桥（失败返回 false，异常已记日志） */
  public start(tag: string = ''): boolean {
    try {
      this.ctx = new JSContext();
      this.ctx.name = 'qjs-' + tag;
      this.ctx.exceptionHandler = (context: JSContext, exception: JSValue): void => {
        appendPlayLog('[qjs] 未捕获异常: ' + exception.toString());
      };
      this.evaluate(PRELUDE, 'rzd_prelude.js');
      return true;
    } catch (e) {
      appendPlayLog('[qjs] 启动失败: ' + JSON.stringify(e).substring(0, 200));
      this.release();
      return false;
    }
  }

  /** 执行一段脚本；返回值的字符串形式（异常返回空串并记日志） */
  public evaluate(script: string, sourceURL?: string): string {
    const ctx: JSContext | null = this.ctx;
    if (ctx === null || this.released) {
      return '';
    }
    try {
      const v: JSValue = ctx.evaluateScript(script, sourceURL);
      if (v.isException) {
        appendPlayLog('[qjs] 脚本异常 ' + (sourceURL ?? '') + ': ' + v.toString());
        return '';
      }
      return v.isUndefined ? '' : v.toString();
    } catch (e) {
      appendPlayLog('[qjs] 执行失败: ' + JSON.stringify(e).substring(0, 200));
      return '';
    }
  }

  /** 取走 JS 侧投递的宿主调用（可能为空数组） */
  public drain(): QuickJsCall[] {
    const raw: string = this.evaluate('__qjsDrain()', 'rzd_drain.js');
    if (raw.length === 0 || raw === 'undefined') {
      return [];
    }
    try {
      const arr = JSON.parse(raw) as QuickJsCall[];
      return Array.isArray(arr) ? arr : [];
    } catch (e) {
      appendPlayLog('[qjs] 投递箱解析失败: ' + raw.substring(0, 120));
      return [];
    }
  }

  /**
   * 回填一次宿主调用的结果。
   * @param id 投递序号
   * @param dataJson 结果（JSON 字符串；字符串类结果请自己加引号）
   * @param ok false = 让 JS 侧 Promise reject
   */
  public resolve(id: number, dataJson: string, ok: boolean = true): void {
    const safe: string = dataJson.length > 0 ? dataJson : 'null';
    this.evaluate(`__qjsResolve(${id}, ${JSON.stringify(safe)}, ${ok ? 'true' : 'false'})`, 'rzd_resolve.js');
  }

  /** 释放引擎（幂等） */
  public release(): void {
    if (this.released) {
      return;
    }
    this.released = true;
    const ctx: JSContext | null = this.ctx;
    this.ctx = null;
    if (ctx !== null) {
      try {
        ctx.release();
      } catch (e) {
        appendPlayLog('[qjs] release 失败: ' + JSON.stringify(e).substring(0, 120));
      }
    }
  }
}

/**
 * 启动自检：**唯一目的**是在真机日志里留下一条 `[qjs] …`，证明
 * 「`libquickjs.so` 能加载 / 引擎能建 / 脚本能跑 / 投递箱能往返」。
 *
 * 看到 `[qjs] self-test ok` 才谈得上把脚本迁到 QuickJS；
 * 看到 `[qjs] start fail` / `[qjs] 引擎不可用` 就是这条路的第一个坑。
 *
 * 现在**不参与任何业务逻辑**，只在 `EntryAbility.onCreate` 里跑一次（约 1~3ms）。
 */
export function quickJsSelfTest(): void {
  const rt: QuickJsRuntime = new QuickJsRuntime();
  try {
    if (!rt.start('selftest')) {
      appendPlayLog('[qjs] self-test: 引擎不可用（start 失败，详见上一条）');
      return;
    }
    // 1) 纯计算
    const sum: string = rt.evaluate('1 + 41', 'selftest.js');
    if (sum !== '42') {
      appendPlayLog('[qjs] self-test fail: 1+41 = ' + sum);
      return;
    }
    // 2) 投递箱往返：JS 侧发起一次 lx.send，ArkTS 侧取走并回填
    rt.evaluate(`globalThis.__t = 'pending'; lx.send('inited', { ok: 1 }).then(function (r) {
      globalThis.__t = 'resolved:' + JSON.stringify(r);
    });`, 'selftest_bridge.js');
    const calls: QuickJsCall[] = rt.drain();
    if (calls.length !== 1 || calls[0].method !== 'send') {
      appendPlayLog('[qjs] self-test fail: 投递箱空/错，calls=' + calls.length);
      return;
    }
    rt.resolve(calls[0].id, '{"ok":1}');
    const settled: string = rt.evaluate('globalThis.__t', 'selftest_check.js');
    if (settled.indexOf('resolved') !== 0) {
      appendPlayLog('[qjs] self-test fail: Promise 未回填，__t=' + settled);
      return;
    }
    // 3) 宿主桥的两件基础能力（atob/btoa 走 JS 侧实现，不发投递箱）
    const b64: string = rt.evaluate("btoa('abc')", 'selftest_b64.js');
    appendPlayLog('[qjs] self-test ok · eval=1+41:' + sum + ' · bridge=' + calls[0].method +
      ' → ' + settled + ' · btoa(abc)=' + b64);
  } catch (e) {
    appendPlayLog('[qjs] self-test 抛异常: ' + JSON.stringify(e).substring(0, 200));
  } finally {
    rt.release();
  }
}
