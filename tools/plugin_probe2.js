// Probe #2: find which exported handler issues which HTTP call, and dump that handler's source.
// Usage: node plugin_probe2.js <plugin.js> <urlSubstring>
const fs = require('fs');
const path = require('path');
const Module = require('module');

const PLUGIN = process.argv[2];
const WANT = process.argv[3] || '';
const src = fs.readFileSync(PLUGIN, 'utf8');

let currentLabel = 'module-load';
const calls = [];

function makeAxios() {
  const record = (cfg) => {
    const url = typeof cfg === 'string' ? cfg : (cfg && (cfg.url || cfg.baseURL));
    const method = ((cfg && cfg.method) || 'get').toLowerCase();
    const params = cfg && cfg.params;
    const data = cfg && cfg.data;
    let where = '';
    const stack = new Error().stack || '';
    const lines = stack.split('\n').slice(1, 4).map((l) => l.trim());
    where = lines.join(' | ');
    calls.push({ label: currentLabel, method, url, params, data, where });
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

(async () => {
  for (const key of Object.keys(plugin)) {
    if (typeof plugin[key] !== 'function') {
      continue;
    }
    currentLabel = key;
    try {
      await plugin[key]({}, null, false);
    } catch (e) {
      // ignore: we only care about which URLs got hit
    }
  }
  console.log('=== matched calls ===');
  const seen = new Set();
  for (const c of calls) {
    const line = `${c.method.toUpperCase()} ${c.url} ${c.params ? JSON.stringify(c.params) : ''}`;
    if (WANT.length > 0 && !line.includes(WANT)) {
      continue;
    }
    if (seen.has(line)) {
      continue;
    }
    seen.add(line);
    console.log(`[${c.label}] ${line}`);
    console.log(`    @ ${c.where}`);
  }
  // Dump source of the handlers that touched the wanted endpoint
  const labels = new Set(calls.filter((c) => WANT.length === 0 || (`${c.url}`).includes(WANT)).map((c) => c.label));
  for (const label of labels) {
    if (typeof plugin[label] === 'function') {
      console.log(`\n=== SOURCE ${label} ===\n` + plugin[label].toString().slice(0, 3000));
    }
  }
})();
