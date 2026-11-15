#!/usr/bin/env node
/*
 * 在没有真机的情况下，用 node 复现「脚本跑在 QuickJS 里为什么失败」。
 *
 * 为什么要它：QuickJS 的宿主环境是**我们自己用 PRELUDE 仿的**（console/window/定时器/
 * localStorage 全是我们补的），脚本一失败只能靠真机日志猜。2026-11-15 两支脚本报
 * `cannot read property 'request' of undefined`，靠这个工具 3 分钟就定位到
 * 「脚本第 16 行解构 globalThis.lx 的 EVENT_NAMES，而我们没给」。
 *
 * 用法：
 *   node tools/qjs-repro.js /path/to/lx-script.js
 * 输出（写到 stdout，避免某些环境吞 stdout 用 OUT 文件）：
 *   - 脚本顶层 eval 是否抛错 + 栈（含行号）
 *   - 脚本自己 console.log 的内容
 *   - 投递箱里攒下的宿主调用（request / send … 的参数）
 */
const fs = require('fs');
const path = require('path');

const scriptPath = process.argv[2];
if (!scriptPath) {
  console.error('用法: node tools/qjs-repro.js <脚本.js>');
  process.exit(1);
}
const script = fs.readFileSync(scriptPath, 'utf8');
const prelude = fs.readFileSync(path.join(__dirname, 'qjs-prelude.js'), 'utf8');

// 模拟 QuickJS 裸环境：删掉 node 自带的那批全局
delete globalThis.setTimeout; delete globalThis.setInterval;
delete globalThis.clearTimeout; delete globalThis.clearInterval;
delete globalThis.localStorage; delete globalThis.sessionStorage;
delete globalThis.window; delete globalThis.self; delete globalThis.fetch;

globalThis.__calls = [];
globalThis.__qjsCall = function (method, args) {
  globalThis.__calls.push({ method: method, args: args });
  // 永不 resolve：模拟"宿主还没回填"，这样只看脚本自己发出了什么
  return new Promise(function () {});
};

process.on('unhandledRejection', (e) => {
  console.error('[repro] unhandledRejection: ' + (e && e.message));
});

eval(prelude);
console.error('[repro] prelude ok, typeof lx = ' + typeof globalThis.lx);

try {
  eval(script);
  console.error('[repro] 顶层 eval 通过（没抛）');
} catch (e) {
  console.error('[repro] 顶层 eval 抛错: ' + e.name + ': ' + e.message);
  const st = String(e.stack || '').split('\n').slice(0, 8).join('\n');
  console.error(st);
  // 有行号时把那一行源码打出来，省得再翻文件
  const m = /<anonymous>:(\d+):/.exec(String(e.stack || ''));
  if (m) {
    const n = Number(m[1]);
    const line = script.split('\n')[n - 1];
    console.error('[repro] 脚本第 ' + n + ' 行: ' + (line || '').trim());
  }
  process.exit(2);
}

const drained = JSON.parse(globalThis.__qjsDrain());
console.error('[repro] 投递箱里有 ' + drained.length + ' 条宿主调用');
drained.forEach((c) => {
  console.error('  · ' + c.method + ' ' + String(c.args).substring(0, 240));
});
