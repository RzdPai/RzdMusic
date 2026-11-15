// 由 features/player/src/main/ets/source/QuickJsRuntime.ets 的 PRELUDE 抽出（自动生成，别手改）。
// 用途：在没有真机的情况下，用 node 复现 QuickJS 侧脚本失败。见 tools/README.md。

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
