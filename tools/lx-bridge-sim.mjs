// 本地仿真：把 RzdMusic 的 lx_bridge.html 原样跑在 Node 里，喂用户那个音源脚本，
// 复现「脚本初始化 + 取链」全流程，用来区分「脚本/桥的问题」与「服务端/平台权限的问题」。
// 用法: node tools/lx-bridge-sim.mjs <脚本路径> [source] [songId] [quality]
import fs from 'node:fs';
import path from 'node:path';

const scriptPath = process.argv[2] ?? 'C:\\Users\\Administrator\\Desktop\\RzdProject\\.buildcache\\lx-source-under-test.js';
const wantSource = process.argv[3] ?? 'kw';
const wantSongId = process.argv[4] ?? '158131';
const wantQuality = process.argv[5] ?? '320k';

const bridgeHtml = fs.readFileSync(
  'C:\\Users\\Administrator\\Desktop\\RzdProject\\RzdMusic\\features\\player\\src\\main\\resources\\rawfile\\lx_bridge.html',
  'utf8');
const bridgeJs = bridgeHtml.split('<script>')[1].split('</script>')[0];
const userScript = fs.readFileSync(scriptPath, 'utf8');

const log = (...a) => console.log(...a);

// ---- 原生侧桩：把桥发出的消息接住，nativeFetch 用真网络实现（等价于 LXSourceEngine.handleNativeFetch） ----
let initResult = null;
const responses = new Map();
const updates = [];

async function handleNative(message) {
  const msg = JSON.parse(message);
  if (msg.event === 'init') {
    initResult = msg.data;
    log('[native] init 上报 status=' + msg.data.status + (msg.data.message ? ' message=' + JSON.stringify(msg.data.message) : ''));
    if (msg.data.sources) {
      for (const [k, v] of Object.entries(msg.data.sources)) {
        log('        平台 ' + k + ' actions=' + JSON.stringify(v.actions) + ' qualitys=' + JSON.stringify(v.qualitys));
      }
    }
    return;
  }
  if (msg.event === 'updateAlert') {
    updates.push(msg.data);
    log('[native] updateAlert ' + JSON.stringify(msg.data).slice(0, 160));
    return;
  }
  if (msg.event === 'response') {
    const d = msg.data;
    log('[native] response key=' + d.requestKey + ' status=' + d.status + (d.status ? '' : ' message=' + JSON.stringify(d.message)));
    if (d.status && d.result) {
      log('        结果 ' + JSON.stringify(d.result).slice(0, 260));
    }
    const wait = responses.get(d.requestKey);
    if (wait) { responses.delete(d.requestKey); wait(d); }
    return;
  }
  if (msg.event === 'nativeFetch') {
    const { requestId, url, method, headers, body, timeout } = msg.data;
    log('[native] fetch ' + method + ' ' + url.slice(0, 120));
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), Math.min(timeout ?? 15000, 60000));
      const resp = await fetch(url, {
        method, headers, body: (body && body.length > 0) ? body : undefined, signal: controller.signal
      });
      clearTimeout(timer);
      const text = await resp.text();
      const hdrs = {};
      resp.headers.forEach((v, k) => { hdrs[k] = v; });
      globalThis.window._lx_handleFetchResponse(requestId, null, resp.status, JSON.stringify(hdrs), text);
    } catch (e) {
      globalThis.window._lx_handleFetchResponse(requestId, String(e && e.message || e), 0, '{}', '');
    }
    return;
  }
  log('[native] 未处理事件 ' + msg.event);
}

// ---- 桥需要的浏览器全局 ----
globalThis.window = globalThis;
// 桥用 window.addEventListener 兜脚本错误，Node 主线程没有，补一个够用的实现
globalThis.__simListeners = {};
globalThis.addEventListener = (type, fn) => {
  const list = globalThis.__simListeners[type] ?? [];
  list.push(fn);
  globalThis.__simListeners[type] = list;
};
globalThis.removeEventListener = () => {};
globalThis.ohos_bridge = { onMessage: (m) => { void handleNative(m); } };
window.ohos_bridge = globalThis.ohos_bridge;
if (!globalThis.atob) globalThis.atob = (b) => Buffer.from(b, 'base64').toString('binary');
if (!globalThis.btoa) globalThis.btoa = (s) => Buffer.from(s, 'binary').toString('base64');
globalThis.console = console;
// 桥里用的 escape/unescape
globalThis.escape = globalThis.escape ?? ((s) => encodeURIComponent(s).replace(/%([0-9A-F]{2})/g, (_, h) => String.fromCharCode(parseInt(h, 16))));
globalThis.unescape = globalThis.unescape ?? ((s) => decodeURIComponent(s.split('').map((c) => '%' + c.charCodeAt(0).toString(16).padStart(2, '0')).join('')));

// ---- 加载桥（与 WebView 中同样的 eval 路径） ----
new Function(bridgeJs)();
log('[sim] 桥已加载, _lx_init=' + typeof window._lx_init);

// ---- 注入音源脚本（走桥的分片协议，和原生 injectScript 一样） ----
const payload = {
  name: '聆澜音源(公益版)', description: 'sim', version: 'v8.9.1', author: 'sim',
  homepage: '', script: userScript, proxy: { host: '', port: '' }
};
// 原生侧注入的是 **UTF-8 字节的 base64**（桥侧 atob → escape → decodeURIComponent 还原 UTF-8）
const b64 = Buffer.from(JSON.stringify(payload), 'utf8').toString('base64');
const partSize = 20000;
window._lx_init_begin(1);
for (let i = 0; i < b64.length; i += partSize) {
  window._lx_init_chunk(1, b64.substring(i, i + partSize));
}
window._lx_init_end(1);

// 等脚本自己的 update 检查（异步）跑完
await new Promise((r) => setTimeout(r, 3000));
log('[sim] 注入后 initResult=' + JSON.stringify(initResult && { status: initResult.status, message: initResult.message, sources: initResult.sources ? Object.keys(initResult.sources) : null }));

// ---- 走一次取链请求（等价于点击播放时引擎 sendRequest） ----
const key = 'sim-1';
const reqData = {
  source: wantSource,
  action: 'musicUrl',
  info: { type: wantQuality, musicInfo: { songmid: wantSongId, source: wantSource, name: 'sim', singer: 'sim' } }
};
const done = new Promise((resolve) => responses.set(key, resolve));
window._lx_handleRequest(key, JSON.stringify(reqData));
const result = await Promise.race([done, new Promise((r) => setTimeout(() => r({ status: 'timeout' }), 20000))]);
log('[sim] 取链结论: ' + JSON.stringify(result).slice(0, 300));
process.exit(0);
