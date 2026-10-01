/*
 * Node 单测：校验 features/player/src/main/resources/rawfile/lx_bridge.html 的
 * 「初始化代际状态机」是否修掉了三个历史 bug。
 *
 * 背景（本测试要防的回归）：桥里原本有两个「页面级单向闩锁」——
 *   isInitedApi   —— onError 与 lx.send('inited') 共用，任一先到就永久置位；
 *   initEnvCalled —— _lx_init 只能进入一次。
 * 后果是「音源就绪」偶发失败且不可恢复：
 *   a) 脚本启动期任意一次瞬时错误（未捕获 Promise 拒绝也会走 onError）→ 上报
 *      init:false 并永久置位 → 脚本恢复后 lx.send('inited') 被 reject，
 *      同一页面永远不会再上报 status:true；
 *   b) WebView 被系统回收/刷新后原生侧重新注入，_lx_init 直接早退，脚本永不执行，
 *      而原生侧的就绪标志仍是 true（假就绪）。
 *
 * 用法（在仓库根目录执行）：
 *   node features/player/src/test/bridge_init_test.js
 * 退出码 0 = 全部通过，1 = 有失败用例。
 */

'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const BRIDGE = path.resolve(__dirname, '..', 'main', 'resources', 'rawfile', 'lx_bridge.html');
const BRIDGE_SRC = fs.readFileSync(BRIDGE, 'utf8');

/** 从 lx_bridge.html 抽出内联 IIFE 主体。 */
function extractBridgeBody() {
  const start = BRIDGE_SRC.indexOf('(function() {');
  const end = BRIDGE_SRC.indexOf('})();');
  if (start === -1 || end === -1) {
    throw new Error('未能定位 lx_bridge.html 中的 IIFE 边界');
  }
  return BRIDGE_SRC.slice(start + '(function() {'.length, end);
}

const BRIDGE_BODY = extractBridgeBody();

/**
 * 每次用例都建一个全新的 JS 全局上下文。
 *
 * 必须用 vm 上下文而不是把 window 当普通对象传进来：桥里用裸标识符 `lx`
 * （不是 `window.lx`）访问 API，只有真正的全局对象才能解析到；用对象传参会让
 * 脚本报 `lx is not defined`，把测试本身弄成假失败。
 */
function newSandbox() {
  const sent = [];
  const listeners = {};
  const sandbox = {
    console: console,
    TextEncoder: TextEncoder,
    TextDecoder: TextDecoder,
    atob: atob,
    btoa: btoa,
    crypto: globalThis.crypto,
    setTimeout: setTimeout,
    clearTimeout: clearTimeout,
    setInterval: setInterval,
    clearInterval: clearInterval
  };
  sandbox.window = sandbox;
  sandbox.document = {};
  sandbox.addEventListener = (name, fn) => {
    (listeners[name] = listeners[name] || []).push(fn);
  };
  sandbox.removeEventListener = () => {};
  sandbox.ohos_bridge = { onMessage: (m) => sent.push(JSON.parse(m)) };

  vm.createContext(sandbox);
  vm.runInContext(BRIDGE_BODY, sandbox, { filename: 'lx_bridge.html' });

  return {
    sandbox,
    sent,
    listeners,
    scope: {
      init: sandbox._lx_init,
      begin: sandbox._lx_init_begin,
      chunk: sandbox._lx_init_chunk,
      end: sandbox._lx_init_end
    },
    fireUnhandledRejection: (msg) => {
      (listeners['unhandledrejection'] || []).forEach((f) => f({ isTrusted: true, reason: new Error(msg) }));
    },
    fireWindowError: (msg) => {
      (listeners['error'] || []).forEach((f) => f({ isTrusted: true, message: 'Uncaught Error: ' + msg }));
    },
    hookCount: () => (listeners['error'] || []).length + (listeners['unhandledrejection'] || []).length
  };
}

function payload(name, script) {
  return {
    name: name,
    description: '',
    version: '1',
    author: '',
    homepage: '',
    script: script,
    proxy: { host: '', port: '' }
  };
}

/** 按原生侧协议注入：begin(gen) -> chunk(gen, part)* -> end(gen)。 */
function injectGen(scope, gen, obj) {
  const b64 = Buffer.from(JSON.stringify(obj), 'utf8').toString('base64');
  const parts = [];
  for (let i = 0; i < b64.length; i += 20000) {
    parts.push(b64.substring(i, i + 20000));
  }
  scope.begin(gen);
  for (const p of parts) {
    scope.chunk(gen, p);
  }
  scope.end(gen);
}

const READY_SCRIPT = "lx.on('request', function(){}); lx.send('inited', " +
  "{sources:{wy:{type:'music',actions:['musicUrl','lyric','pic'],qualitys:['128k','320k']}}});";
const SILENT_SCRIPT = "lx.on('request', function(){});";

const results = [];
function check(name, cond, detail) {
  results.push({ name, ok: !!cond, detail: detail || '' });
}

function summary(sent) {
  return JSON.stringify(sent.map((m) => m.event + (m.data.status === true ? ':ok' : ':fail') +
    '@gen' + (m.data.gen !== undefined ? m.data.gen : '?')));
}

// ---------------------------------------------------------------------------
// 用例 1-3：代际可重入
// ---------------------------------------------------------------------------
{
  const sb = newSandbox();
  injectGen(sb.scope, 1, payload('A', READY_SCRIPT));
  check('首次注入即就绪', summary(sb.sent) === '["init:ok@gen1"]', summary(sb.sent));

  sb.sent.length = 0;
  injectGen(sb.scope, 2, payload('B', READY_SCRIPT));
  check('刷新/回收后重新注入可重入（新代际）', summary(sb.sent) === '["init:ok@gen2"]', summary(sb.sent));

  sb.sent.length = 0;
  injectGen(sb.scope, 2, payload('B', READY_SCRIPT));
  check('同代际且已成功 → 忽略重复注入', sb.sent.length === 0,
    sb.sent.length === 0 ? 'IGNORED' : summary(sb.sent));
}

// ---------------------------------------------------------------------------
// 用例 4-6：失败不再永久闩锁
// ---------------------------------------------------------------------------
{
  const sb = newSandbox();
  injectGen(sb.scope, 3, payload('C', SILENT_SCRIPT));
  sb.fireUnhandledRejection('transient network fail');
  check('启动期瞬时错误 → 上报 init:false',
    sb.sent.some((m) => m.data.status === false && m.data.gen === 3), summary(sb.sent));

  sb.sent.length = 0;
  sb.fireUnhandledRejection('another transient fail');
  check('同一代际失败只上报一次（不刷屏）', sb.sent.length === 0,
    sb.sent.length === 0 ? 'IGNORED' : summary(sb.sent));

  sb.sent.length = 0;
  sb.scope.init(3, payload('C', READY_SCRIPT));
  check('失败后脚本恢复 → 仍能升级为 status:true（旧实现被永久闩锁）',
    sb.sent.some((m) => m.data.status === true && m.data.gen === 3), summary(sb.sent));
}

// ---------------------------------------------------------------------------
// 用例 7-8：就绪后不再降级；错误监听不重复注册
// ---------------------------------------------------------------------------
{
  const sb = newSandbox();
  injectGen(sb.scope, 1, payload('D', READY_SCRIPT));
  sb.sent.length = 0;
  sb.fireWindowError('post-ready boom');
  check('就绪后的错误不再把状态打回未就绪', sb.sent.length === 0,
    sb.sent.length === 0 ? 'IGNORED' : summary(sb.sent));

  injectGen(sb.scope, 2, payload('E', READY_SCRIPT));
  check('全局错误监听取页面内只注册一次', sb.hookCount() === 2, 'hooks=' + sb.hookCount());
}

// ---------------------------------------------------------------------------
// 用例 9：旧协议兼容（单参数 _lx_init(initData)）
// ---------------------------------------------------------------------------
{
  const sb = newSandbox();
  sb.scope.init(payload('F', READY_SCRIPT));
  check('兼容旧的单参数 _lx_init(initData) 调用',
    sb.sent.some((m) => m.data.status === true), summary(sb.sent));
}

// ---------------------------------------------------------------------------
// 用例 10：载荷缺失要显式失败
// ---------------------------------------------------------------------------
{
  const sb = newSandbox();
  sb.scope.init(7, undefined);
  check('载荷缺失 → 显式上报 init:false', sb.sent.some((m) => m.data.status === false), summary(sb.sent));
}

// ---------------------------------------------------------------------------
// 输出
// ---------------------------------------------------------------------------
const failed = results.filter((r) => !r.ok);
console.log('=== lx_bridge.html 初始化状态机回归 ===');
console.log(`bridge: ${BRIDGE}`);
for (const r of results) {
  console.log(`  ${r.ok ? 'PASS' : 'FAIL'}  ${r.name}${r.detail ? '   ' + r.detail : ''}`);
}
console.log(`通过: ${results.length - failed.length}  失败: ${failed.length}`);
if (failed.length > 0) {
  process.exit(1);
}
console.log('\n✓ 全部通过：代际可重入、失败可升级、就绪不降级、旧协议兼容');
process.exit(0);
