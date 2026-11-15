/*
 * Copyright (c) 2026 RzdPai
 *
 * QuickJS 引擎运行时（双引擎重构 Phase 1 的落地件）。
 *
 * ── 为什么现在有这个文件 ────────────────────────────────────────────────────
 * 交接书 `docs/双引擎重构交接书-20261114.md` 的 Phase 1 是「把 QuickJS 编进来」，
 * 原先估的代价主要在**交叉编译 QuickJS + 自己写 NAPI 绑定**。这两件都不用做了：
 * 社区 HAR `@devzeng/quickjs`（ohpm）确实能跑脚本，但它**不打微任务泵** ——
 * 它的 `evaluateScript` 就是一次 `JS_Eval` 就返回，而 QuickJS 的 Promise 回调
 * （`.then` / `catch` / `await` 续体）全在 job queue 里，必须宿主循环调
 * `JS_ExecutePendingJob` 才执行。真机实测（2026-11-15 14:20）表现就是
 * `[qjs] self-test fail: Promise 未回填，__t=pending`；LX 脚本全是 async 的 ⇒ 这条路走不通。
 *
 * 所以本工程用的是 **本地自建 HAR `quickjs-rzd`**（`common/quickjs/`，源自
 * `参考项目/ohos_quickjs/` 同一份源码），在 `napi_init.cpp` 里补了：
 *   · `RunPendingJobs()`，并挂在 `evaluateScript` / `callFunction` / `construct` 之后；
 *   · 额外导出 `runPendingJobs(engineHandle)` 给 ArkTS 侧显式催一次。
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

import { JSContext, JSValue } from 'quickjs';
import { runPendingJobs } from 'libquickjs.so';
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

  // ── 宿主 → 脚本 的事件派发（2026-11-15：Phase 2 的另一半）──────────────
  // lx.on('request', handler) 注册的 handler 只能由宿主调用。WebView 侧靠
  // window._lx_handleRequest；QuickJS 侧就靠这两个函数：
  //   __qjsInvoke(event, payloadJson)  发起一次调用（结果异步写进 slot）
  //   __qjsInvokeResult()              查询是否完成 + 返回值/错误
  globalThis.__qjsInvokeSlot = null;
  globalThis.__qjsInvoke = function (eventName, dataJson) {
    var h = handlers[eventName];
    var slot = { done: false, value: null, error: null };
    globalThis.__qjsInvokeSlot = slot;
    if (!h) {
      slot.done = true;
      slot.error = 'no handler for event: ' + eventName;
      return 'no-handler';
    }
    var finish = function (v) { slot.done = true; slot.value = v === undefined ? null : v; };
    var fail = function (e) { slot.done = true; slot.error = String((e && e.message) || e); };
    try {
      var r = h(JSON.parse(dataJson));
      if (r && typeof r.then === 'function') { r.then(finish, fail); } else { finish(r); }
    } catch (e) {
      fail(e);
    }
    return 'pending';
  };
  globalThis.__qjsInvokeResult = function () {
    var s = globalThis.__qjsInvokeSlot;
    if (!s) { return JSON.stringify({ done: true, value: null, error: 'no slot' }); }
    return JSON.stringify({ done: s.done, value: s.value, error: s.error });
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

  // ── 宿主环境补齐（2026-11-15 真机教训）────────────────────────────────────
  // QuickJS 里**没有** console / window / setTimeout / localStorage。
  // 实录：两支脚本跑 QuickJS 都在 ~2s 后抛 「TypeError: cannot read property 'request' of undefined」，
  // 说明它们在某个异步回调里摸了一个我们没提供的全局 —— 先把常见的这几个补齐。
  if (typeof globalThis.console !== 'object' || globalThis.console === null) {
    var logBuf = [];
    globalThis.__qjsLogs = logBuf;
    var push = function (level) {
      return function () {
        try {
          var parts = [];
          for (var i = 0; i < arguments.length; i++) {
            var v = arguments[i];
            parts.push(typeof v === 'string' ? v : JSON.stringify(v));
          }
          logBuf.push(level + ' ' + parts.join(' '));
          if (logBuf.length > 200) { logBuf.shift(); }
        } catch (e) { /* 日志失败不能影响脚本 */ }
      };
    };
    globalThis.console = { log: push('log'), info: push('info'), warn: push('warn'),
      error: push('error'), debug: push('debug') };
  }
  // 脚本常用 「window」 / 「self」 / 「global」 做环境判定
  if (typeof globalThis.window === 'undefined') { globalThis.window = globalThis; }
  if (typeof globalThis.self === 'undefined') { globalThis.self = globalThis; }
  if (typeof globalThis.global === 'undefined') { globalThis.global = globalThis; }

  // ── 定时器：QuickJS 没有事件循环 ⇒ 只登记，由 ArkTS 侧 __qjsRunTimers() 驱动 ──
  // ⚠️ __qjsRunTimers 必须**无条件**定义（driveTimers() 每次都调），
  //    不能放在 if(!setTimeout) 里面 —— 否则宿主已有 setTimeout 时就缺这个函数。
  globalThis.__qjsTimers = globalThis.__qjsTimers || [];
  globalThis.__qjsTimerSeq = globalThis.__qjsTimerSeq || 0;
  if (typeof globalThis.__qjsRunTimers !== 'function') {
    globalThis.__qjsRunTimers = function () {
      var now = Date.now();
      var due = [];
      var list = globalThis.__qjsTimers;
      for (var i = list.length - 1; i >= 0; i--) {
        if (list[i].at <= now) {
          var t = list[i];
          due.push(t);
          if (t.interval > 0) { t.at = now + t.interval; } else { list.splice(i, 1); }
        }
      }
      for (var j = due.length - 1; j >= 0; j--) {
        try { due[j].fn.apply(globalThis, due[j].args); } catch (e) { /* 脚本自己的错 */ }
      }
      return due.length;
    };
  }
  if (typeof globalThis.setTimeout !== 'function') {
    var addTimer = function (fn, delay, args, repeat) {
      var id = ++globalThis.__qjsTimerSeq;
      globalThis.__qjsTimers.push({ id: id, at: Date.now() + (delay > 0 ? delay : 0),
        fn: fn, args: args, interval: repeat ? (delay > 0 ? delay : 1) : 0 });
      return id;
    };
    globalThis.setTimeout = function (fn, delay) {
      return addTimer(fn, delay, Array.prototype.slice.call(arguments, 2), false);
    };
    globalThis.setInterval = function (fn, delay) {
      return addTimer(fn, delay, Array.prototype.slice.call(arguments, 2), true);
    };
    var clearTimer = function (id) {
      for (var i = 0; i < globalThis.__qjsTimers.length; i++) {
        if (globalThis.__qjsTimers[i].id === id) { globalThis.__qjsTimers.splice(i, 1); return; }
      }
    };
    globalThis.clearTimeout = clearTimer;
    globalThis.clearInterval = clearTimer;
  }

  // ── CompressionStream / DecompressionStream：**明确不支持** ────────────────
  // 2026-11-16 结论：@ohos.zlib 只有**文件/fd 级**接口（gzopen/zip/unzip），
  // 没有内存版 inflate。要做就得落临时文件中转（每次 2 次文件 IO + zlib），
  // 而目前**没有一支实测脚本用到它** —— 与其写一条没验证过的半吊子路径，
  // 不如让它**立刻失败**：宿主侧 qjs miss -> webview 会接住并回落 ArkWeb。
  // 等真出现 zip=true 的脚本再按临时文件方案补（见 docs/TODO-20261115.md）。
  if (typeof globalThis.DecompressionStream === 'undefined') {
    globalThis.DecompressionStream = function () {
      throw new Error('DecompressionStream 尚未在 QuickJS 侧实现（请回落 ArkWeb）');
    };
  }
  if (typeof globalThis.CompressionStream === 'undefined') {
    globalThis.CompressionStream = function () {
      throw new Error('CompressionStream 尚未在 QuickJS 侧实现（请回落 ArkWeb）');
    };
  }

  // ── WebCrypto 子集（2026-11-15：把"签名类"能力从 WebView 搬到 ArkTS）──────
  // LX 脚本用 crypto.subtle 绝大多数是为了**签名**：digest(SHA-256) 与 HMAC。
  // 这里给出这两个的最小实现（底层是 ArkTS 的 cryptoFramework），
  // 于是"用了 crypto.subtle"不再一票否决 QuickJS —— 真用到 AES/RSA 之类没实现的算子时，
  // Promise 会 reject，宿主侧 qjs miss -> webview 接住并记住判定（失败即回落）。
  var b64FromBuf = function (buf) {
    var bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    var bin = '';
    for (var i = 0; i < bytes.length; i++) { bin += String.fromCharCode(bytes[i]); }
    return globalThis.btoa(bin);
  };
  var bufFromB64 = function (b64) {
    var bin = globalThis.atob(b64);
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) { out[i] = bin.charCodeAt(i); }
    return out.buffer;
  };
  var normalizeAlg = function (alg) {
    var m = alg && alg.hash ? alg.hash : alg;
    var name = (m && m.name) ? m.name : m;
    return String(name || '').toUpperCase().replace('-', '');
  };
  if (typeof globalThis.crypto === 'undefined') { globalThis.crypto = {}; }
  if (typeof globalThis.crypto.getRandomValues !== 'function') {
    globalThis.crypto.getRandomValues = function (arr) {
      var n = arr.length;
      globalThis.__qjsCall('crypto.randomBytes', { n: n }).then(function (b64) {
        var bytes = new Uint8Array(bufFromB64(b64));
        for (var i = 0; i < n && i < bytes.length; i++) { arr[i] = bytes[i]; }
      });
      return arr;
    };
  }
  if (typeof globalThis.crypto.subtle === 'undefined') {
    globalThis.crypto.subtle = {
      digest: function (alg, data) {
        return globalThis.__qjsCall('crypto.digest',
          { alg: normalizeAlg(alg), b64: b64FromBuf(data) }).then(function (out) {
            return bufFromB64(out);
          });
      },
      importKey: function (format, keyData, alg) {
        // 只支持 raw 的 HMAC 密钥：直接存字节，sign 时再交给宿主
        return Promise.resolve({ __hmacKeyB64: b64FromBuf(keyData), __alg: normalizeAlg(alg) });
      },
      sign: function (alg, key, data) {
        if (!key || !key.__hmacKeyB64) {
          return Promise.reject(new Error('unsupported key for crypto.subtle.sign'));
        }
        return globalThis.__qjsCall('crypto.hmac', {
          alg: normalizeAlg(alg) || key.__alg,
          keyB64: key.__hmacKeyB64,
          dataB64: b64FromBuf(data)
        }).then(function (out) { return bufFromB64(out); });
      },
      // 未实现的算子：**明确 reject**（让宿主回落 WebView，别静默返回错数据）
      encrypt: function () { return Promise.reject(new Error('crypto.subtle.encrypt not available in QuickJS')); },
      decrypt: function () { return Promise.reject(new Error('crypto.subtle.decrypt not available in QuickJS')); },
      verify: function () { return Promise.reject(new Error('crypto.subtle.verify not available in QuickJS')); }
    };
  }

  // ── XMLHttpRequest（2026-11-15：按**特性**路由的关键一块）───────────────
  // LX 脚本里有一部分是直接用 new XMLHttpRequest() 的，不走 lx.request。
  // 以前这类脚本只能整支丢给 WebView；现在用它把请求转成宿主调用（ArkTS 侧 http），
  // 于是「支持 XHR」不再等于「必须有 WebView」——这就是按特性混合的意义。
  if (typeof globalThis.XMLHttpRequest === 'undefined') {
    var XHR = function () {
      this.readyState = 0;
      this.status = 0;
      this.statusText = '';
      this.responseText = '';
      this.response = '';
      this.responseType = '';
      this.withCredentials = false;
      this.timeout = 0;
      this.onload = null;
      this.onerror = null;
      this.onreadystatechange = null;
      this.ontimeout = null;
      this._headers = {};
      this._method = 'GET';
      this._url = '';
      this._body = null;
      this._aborted = false;
    };
    XHR.prototype.open = function (method, url) {
      this._method = String(method || 'GET').toUpperCase();
      this._url = String(url || '');
      this.readyState = 1;
      if (typeof this.onreadystatechange === 'function') { this.onreadystatechange(); }
    };
    XHR.prototype.setRequestHeader = function (k, v) { this._headers[k] = v; };
    XHR.prototype.getAllResponseHeaders = function () {
      var src = this._respHeaders || {};
      var out = '';
      for (var k in src) { if (Object.prototype.hasOwnProperty.call(src, k)) { out += k + ': ' + src[k] + '\r\n'; } }
      return out;
    };
    XHR.prototype.getResponseHeader = function (k) {
      var src = this._respHeaders || {};
      var hit = src[String(k).toLowerCase()];
      return hit === undefined ? null : hit;
    };
    XHR.prototype.abort = function () { this._aborted = true; };
    XHR.prototype.send = function (body) {
      var self = this;
      this._body = body === undefined ? null : body;
      var opts = { method: this._method, headers: this._headers, timeout: this.timeout > 0 ? this.timeout : 15000 };
      if (this._body !== null) { opts.body = typeof this._body === 'string' ? this._body : JSON.stringify(this._body); }
      globalThis.__qjsCall('request', { url: this._url, options: opts }).then(function (resp) {
        if (self._aborted) { return; }
        self.readyState = 4;
        self.status = resp && resp.statusCode ? resp.statusCode : 0;
        self.statusText = (resp && resp.statusMessage) || '';
        self._respHeaders = (resp && resp.headers) || {};
        var raw = resp && resp.raw !== undefined && resp.raw !== null ? resp.raw : '';
        self.responseText = typeof raw === 'string' ? raw : JSON.stringify(raw);
        self.response = self.responseType === 'json' ? (resp ? resp.body : null) : self.responseText;
        if (typeof self.onreadystatechange === 'function') { self.onreadystatechange(); }
        if (typeof self.onload === 'function') { self.onload(); }
      }, function (err) {
        if (self._aborted) { return; }
        self.readyState = 4;
        self.status = 0;
        if (typeof self.onerror === 'function') { self.onerror(err); }
      });
    };
    globalThis.XMLHttpRequest = XHR;
  }

  // ── TextEncoder / TextDecoder（QuickJS 无；脚本用它处理 UTF-8/GBK 字节）──
  if (typeof globalThis.TextEncoder === 'undefined') {
    globalThis.TextEncoder = function () {};
    globalThis.TextEncoder.prototype.encode = function (str) {
      var s = String(str === undefined ? '' : str);
      var utf8 = unescape(encodeURIComponent(s));
      var out = new Uint8Array(utf8.length);
      for (var i = 0; i < utf8.length; i++) { out[i] = utf8.charCodeAt(i); }
      return out;
    };
  }
  if (typeof globalThis.TextDecoder === 'undefined') {
    globalThis.TextDecoder = function (enc) { this.encoding = enc || 'utf-8'; };
    globalThis.TextDecoder.prototype.decode = function (bytes) {
      if (!bytes) { return ''; }
      var arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
      var bin = '';
      for (var i = 0; i < arr.length; i++) { bin += String.fromCharCode(arr[i]); }
      try { return decodeURIComponent(escape(bin)); } catch (e) { return bin; }
    };
  }

  // ── localStorage / sessionStorage：内存版（脚本用它们存 token）──
  if (typeof globalThis.localStorage === 'undefined') {
    var makeStore = function () {
      var data = Object.create(null);
      return {
        getItem: function (k) { return Object.prototype.hasOwnProperty.call(data, k) ? data[k] : null; },
        setItem: function (k, v) { data[k] = String(v); },
        removeItem: function (k) { delete data[k]; },
        clear: function () { data = Object.create(null); },
        key: function (i) { return Object.keys(data)[i] ?? null; },
        get length() { return Object.keys(data).length; }
      };
    };
    globalThis.localStorage = makeStore();
    globalThis.sessionStorage = makeStore();
  }

  var SUPPORTED_EVENTS = { request: 1, inited: 1, updateAlert: 1 };  // 与 LX_EVENT_NAMES 同集合

  // ★ 2026-11-15（真机 + 本地复现双重确认）：EVENT_NAMES 必须挂在 lx 上！
  //   脚本第 16 行是 const { EVENT_NAMES, request, on, send, env, version } = globalThis.lx，
  //   少了 EVENT_NAMES 就会在 on(EVENT_NAMES.request, …) 处抛
  //   cannot read property 'request' of undefined —— 两支脚本死在同一行就是这个原因。
  var LX_EVENT_NAMES = { request: 'request', inited: 'inited', updateAlert: 'updateAlert' };

  globalThis.lx = {
    EVENT_NAMES: LX_EVENT_NAMES,
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
        // ★ 必须打 errorStack：`toString()` 对异常对象常给空串，上一版因此丢掉了行号
        let stack: string = '';
        try {
          stack = exception.errorStack;
        } catch (_e) {
          stack = '';
        }
        appendPlayLog('[qjs] 未捕获异常: ' + exception.toString() +
          (stack.length > 0 ? ' | stack=' + stack.substring(0, 400) : ''));
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
        let stack: string = '';
        try {
          stack = v.errorStack;
        } catch (_e) {
          stack = '';
        }
        appendPlayLog('[qjs] 脚本异常 ' + (sourceURL ?? '') + ': ' + v.toString() +
          (stack.length > 0 ? ' | stack=' + stack.substring(0, 400) : ''));
        return '';
      }
      return v.isUndefined ? '' : v.toString();
    } catch (e) {
      appendPlayLog('[qjs] 执行失败: ' + JSON.stringify(e).substring(0, 200));
      return '';
    }
  }

  /**
   * 跑掉已到期的 `setTimeout` / `setInterval`（QuickJS 没有事件循环，只能由这里驱动）。
   * @returns 本次执行了几个
   */
  public driveTimers(): number {
    const n: string = this.evaluate('__qjsRunTimers()', 'rzd_timers.js');
    const v: number = n.length > 0 ? Number(n) : 0;
    return Number.isFinite(v) ? v : 0;
  }

  /** 脚本侧攒下的 console 输出（最多 200 条），取走即清空 */
  public takeConsoleLogs(): string[] {
    const raw: string = this.evaluate('JSON.stringify(globalThis.__qjsLogs || [])', 'rzd_logs.js');
    this.evaluate('(globalThis.__qjsLogs = [])', 'rzd_logs_clear.js');
    try {
      const arr: Object[] = JSON.parse(raw) as Object[];
      return Array.isArray(arr) ? arr.map((x: Object): string => String(x)) : [];
    } catch (_e) {
      return [];
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
    // 显式再泵一次：不依赖 "evaluateScript 顺带泵" 这层隐含行为，
    // 脚本的 .then 续体、以及续体里继续发起的宿主调用都能立刻反映到下一次 drain()。
    this.pump();
  }

  /** 催一次微任务队列（自建 HAR 的 `runPendingJobs`） */
  public pump(): void {
    const ctx: JSContext | null = this.ctx;
    if (ctx === null || this.released) {
      return;
    }
    try {
      runPendingJobs(ctx.engineHandle);
    } catch (e) {
      appendPlayLog('[qjs] pump 失败: ' + JSON.stringify(e).substring(0, 120));
    }
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
export function quickJsSelfTest(): string {
  const rt: QuickJsRuntime = new QuickJsRuntime();
  try {
    if (!rt.start('selftest')) {
      appendPlayLog('[qjs] self-test: 引擎不可用（start 失败，详见上一条）');
      return '引擎不可用';
    }
    // 1) 纯计算
    const sum: string = rt.evaluate('1 + 41', 'selftest.js');
    if (sum !== '42') {
      appendPlayLog('[qjs] self-test fail: 1+41 = ' + sum);
      return '脚本执行失败（1+41=' + sum + '）';
    }
    // 2) 投递箱往返：JS 侧发起一次 lx.send，ArkTS 侧取走并回填
    rt.evaluate(`globalThis.__t = 'pending'; lx.send('inited', { ok: 1 }).then(function (r) {
      globalThis.__t = 'resolved:' + JSON.stringify(r);
    });`, 'selftest_bridge.js');
    const calls: QuickJsCall[] = rt.drain();
    if (calls.length !== 1 || calls[0].method !== 'send') {
      appendPlayLog('[qjs] self-test fail: 投递箱空/错，calls=' + calls.length);
      return '投递箱异常（calls=' + calls.length + '）';
    }
    rt.resolve(calls[0].id, '{"ok":1}');
    const settled: string = rt.evaluate('globalThis.__t', 'selftest_check.js');
    if (settled.indexOf('resolved') !== 0) {
      appendPlayLog('[qjs] self-test fail: Promise 未回填，__t=' + settled);
      return 'Promise 未回填（缺微任务泵？）';
    }
    // 3) 宿主桥的两件基础能力（atob/btoa 走 JS 侧实现，不发投递箱）
    const b64: string = rt.evaluate("btoa('abc')", 'selftest_b64.js');
    const line: string = '[qjs] self-test ok · eval=1+41:' + sum + ' · bridge=' + calls[0].method +
      ' → ' + settled + ' · btoa(abc)=' + b64;
    appendPlayLog(line);
    return '通过：' + settled + ' · btoa=' + b64;
  } catch (e) {
    appendPlayLog('[qjs] self-test 抛异常: ' + JSON.stringify(e).substring(0, 200));
    return '抛异常：' + JSON.stringify(e).substring(0, 80);
  } finally {
    rt.release();
  }
  return '未知结果';
}
