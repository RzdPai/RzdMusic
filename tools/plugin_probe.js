// Run the obfuscated lx-music plugin with stubs to observe which endpoints it calls.
// Usage: node plugin_probe.js
const fs = require('fs');
const path = require('path');
const Module = require('module');

const PLUGIN = process.argv[2];
const src = fs.readFileSync(PLUGIN, 'utf8');

const calls = [];

// --- stub axios: record every request, return a shaped fake response ---
function makeAxios() {
  const record = (cfg) => {
    const url = typeof cfg === 'string' ? cfg : (cfg && (cfg.url || cfg.baseURL));
    const method = (cfg && cfg.method) || 'get';
    const params = cfg && cfg.params;
    const data = cfg && cfg.data;
    calls.push({ method, url, params, data });
    return Promise.resolve({ status: 200, data: { code: 200, data: {}, msg: 'stub' } });
  };
  const axios = (cfg) => record(cfg);
  axios.get = (url, cfg) => record(Object.assign({}, cfg, { url, method: 'get' }));
  axios.post = (url, data, cfg) => record(Object.assign({}, cfg, { url, data, method: 'post' }));
  axios.request = (cfg) => record(cfg);
  axios.create = () => axios;
  axios.defaults = { headers: { common: {} } };
  axios.interceptors = { request: { use() {} }, response: { use() {} } };
  return axios;
}

const origResolve = Module._resolveFilename;
Module._resolveFilename = function (request, ...rest) {
  if (request === 'axios') {
    return 'axios';
  }
  if (request === 'he') {
    return 'he';
  }
  if (request === 'crypto') {
    return 'crypto';
  }
  return origResolve.call(this, request, ...rest);
};
const origLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === 'axios') {
    return makeAxios();
  }
  if (request === 'he') {
    return { decode: (s) => s, encode: (s) => s };
  }
  return origLoad.call(this, request, parent, isMain);
};

const m = new Module(PLUGIN, null);
m.filename = PLUGIN;
m.paths = Module._nodeModulePaths(path.dirname(PLUGIN));
m._compile(src, PLUGIN);
const plugin = m.exports;

const info = {};
for (const key of Object.keys(plugin)) {
  info[key] = typeof plugin[key];
}
console.log('EXPORTS=' + JSON.stringify(info));
console.log('PLATFORM=' + plugin.platform);

async function tryCall(label, fn, args) {
  try {
    const r = await fn(...args);
    console.log(`--- ${label} OK: ` + JSON.stringify(r).slice(0, 400));
  } catch (e) {
    console.log(`--- ${label} ERR: ` + (e && e.message ? e.message : String(e)).slice(0, 300));
  }
}

(async () => {
  const handler = plugin;
  if (typeof handler.leaderboard === 'function') {
    const lb = handler.leaderboard;
    // list all boards
    await tryCall('leaderboard.list', lb, [{}, null, false]);
  }
  if (typeof handler.topList === 'function') {
    await tryCall('topList.list', handler.topList, [{}, null, false]);
  }
  // probe every exported function with an empty arg to see which reach the network
  for (const key of Object.keys(plugin)) {
    if (typeof plugin[key] !== 'function') {
      continue;
    }
    if (key === 'leaderboard' || key === 'topList') {
      continue;
    }
    await tryCall(key, plugin[key], [{}, null, false]);
  }
  console.log('=== NETWORK CALLS ===');
  const seen = new Set();
  for (const c of calls) {
    const line = `${c.method.toUpperCase()} ${c.url} ${c.params ? JSON.stringify(c.params) : ''} ${c.data ? JSON.stringify(c.data) : ''}`;
    if (seen.has(line)) {
      continue;
    }
    seen.add(line);
    console.log(line.slice(0, 600));
  }
})();
