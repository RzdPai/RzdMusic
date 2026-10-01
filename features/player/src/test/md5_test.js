/*
 * Node 单测：校验 features/player/src/main/resources/rawfile/lx_bridge.html 里
 * 内联注入的 md5 实现是否为「标准字节级 MD5（UTF-8 输入）」。
 *
 * 背景（本测试要防的回归）：
 *   原实现的 lx.utils.crypto.md5 是 md5(encodeURIComponent(str))，且内部按
 *   UTF-16 code unit（charCodeAt）而非 UTF-8 字节计算。洛雪音源脚本用它生成
 *   请求签名，服务器校验失败会返回 403「时间签名验证失败」。
 *
 * 用法（在仓库根目录执行）：
 *   node features/player/src/test/md5_test.js
 * 退出码 0 = 全部通过，1 = 有失败用例。
 */

'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const BRIDGE = path.resolve(__dirname, '..', 'main', 'resources', 'rawfile', 'lx_bridge.html');
const BRIDGE_SRC = fs.readFileSync(BRIDGE, 'utf8');

/**
 * 从 lx_bridge.html 抽出内联 script 的 IIFE 主体，并在尾部导出 md5 供断言使用。
 * 这样测试跑的就是真正打进 App 的那份代码，而不是复制品。
 *
 * 桥接代码在末尾会挂 window._lx_init / window.lx / window.addEventListener，
 * 所以这里注入一个最小 window 桩。
 */
const windowStub = {
  addEventListener: function () {},
  removeEventListener: function () {},
};

function extractBridgeScope() {
  const start = BRIDGE_SRC.indexOf('(function() {');
  const end = BRIDGE_SRC.indexOf('})();');
  if (start === -1 || end === -1) {
    throw new Error('未能定位 lx_bridge.html 中的 IIFE 边界');
  }
  const body = BRIDGE_SRC.slice(start + '(function() {'.length, end);
  const exports = '\n;return { md5: function (v) { return md5(v); }, md5Bytes: md5Bytes, md5ToBytes: md5ToBytes };\n';
  // eslint-disable-next-line no-new-func
  return new Function('window', body + exports)(windowStub);
}

const scope = extractBridgeScope();

/** 标准参考实现（node:crypto），输入按 UTF-8 字节。 */
function refMd5(input) {
  return crypto.createHash('md5').update(input, typeof input === 'string' ? 'utf8' : undefined).digest('hex');
}

/** 旧实现复刻：md5(encodeURIComponent(str)) + UTF-16 charCodeAt，用来证明旧代码确实是坏的。 */
function legacyMd5(str) {
  // 直接复用 bridge 里的 md5 主体不现实（它已被替换），这里用等价语义复刻：
  // 旧 md5 对纯 ASCII 等价于 md5(latin1 bytes of encodeURIComponent(str))。
  const encoded = encodeURIComponent(str);
  return crypto.createHash('md5').update(Buffer.from(encoded, 'latin1')).digest('hex');
}

const cases = [
  { name: '空串', input: '' },
  { name: 'ascii', input: 'abc' },
  { name: '长 ascii', input: 'message digest' },
  { name: 'a-z', input: 'abcdefghijklmnopqrstuvwxyz' },
  { name: 'a-z0-9', input: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789' },
  { name: '数字串', input: '12345678901234567890123456789012345678901234567890123456789012345678901234567890' },
  { name: 'RFC1321 7', input: '123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890' },
  { name: '中文', input: '你好，世界' },
  { name: '中文+歌名', input: '晴天 - 周杰伦' },
  { name: '日文', input: 'こんにちは世界' },
  { name: '韩文', input: '안녕하세요' },
  { name: 'emoji(非BMP)', input: '🎵 music 🎶' },
  { name: 'URL 含斜杠', input: 'a/b/c' },
  { name: 'URL 查询串', input: 'key=你好&path=/a b/c&x=1+2' },
  { name: '含空格', input: 'hello world 中文 空格' },
  { name: '时间戳式签名串', input: 'appid=5794&ts=1726800000000&key=abcdefghijklmnop' },
  { name: '特殊字符', input: '!@#$%^&*()_+-=[]{}|;\':",.<>?/\\`~' },
  { name: '百分号', input: '100%25 已解码' },
  { name: '换行与制表', input: 'line1\nline2\tTabbed\r\n' },
  { name: '恰好 55 字节(UTF-8)', input: 'a'.repeat(55) },
  { name: '恰好 56 字节(UTF-8)', input: 'a'.repeat(56) },
  { name: '恰好 64 字节(UTF-8)', input: 'a'.repeat(64) },
  { name: '中文恰好触发补位边界', input: '中'.repeat(18) + 'a'.repeat(2) },
  { name: '代理对边界', input: '𝄞'.repeat(10) },
];

let pass = 0;
const failures = [];
const legacyDiverged = [];

for (const c of cases) {
  const expected = refMd5(c.input);
  let actual;
  try {
    actual = scope.md5(c.input);
  } catch (e) {
    failures.push(`${c.name}: 抛异常 ${e.message}`);
    continue;
  }
  if (actual === expected) {
    pass++;
  } else {
    failures.push(`${c.name}: 期望 ${expected} 实际 ${actual}  (input=${JSON.stringify(c.input)})`);
  }
  const legacy = legacyMd5(c.input);
  if (legacy !== expected) {
    legacyDiverged.push(c.name);
  }
}

// TypedArray / Array 输入
const bytesCases = [
  { name: 'Uint8Array(abc)', input: new Uint8Array([0x61, 0x62, 0x63]) },
  { name: 'Uint8Array(utf8 中文)', input: new TextEncoder().encode('你好，世界') },
  { name: 'Uint8Array(空)', input: new Uint8Array([]) },
  { name: 'Uint8Array(全字节)', input: new Uint8Array(Array.from({ length: 256 }, (_, i) => i)) },
  { name: 'Array(abc)', input: [0x61, 0x62, 0x63] },
  { name: 'Array(utf8 bytes)', input: Array.from(new TextEncoder().encode('Café ☕')) },
];

for (const c of bytesCases) {
  const expected = crypto.createHash('md5').update(Buffer.from(c.input)).digest('hex');
  let actual;
  try {
    actual = scope.md5(c.input);
  } catch (e) {
    failures.push(`${c.name}: 抛异常 ${e.message}`);
    continue;
  }
  if (actual === expected) {
    pass++;
  } else {
    failures.push(`${c.name}: 期望 ${expected} 实际 ${actual}`);
  }
}

// 非 string/TypedArray/Array 必须抛错
for (const bad of [123, null, undefined, {}, true]) {
  let threw = false;
  try {
    scope.md5(bad);
  } catch (e) {
    threw = true;
  }
  if (threw) {
    pass++;
  } else {
    failures.push(`非法入参 ${JSON.stringify(bad)} 应当抛错但没有`);
  }
}

// 语法面：确认旧的「先 URI 转义再 md5」调用已经彻底移除（只看代码，不看注释）
const codeOnly = BRIDGE_SRC
  .split('\n')
  .map((line) => line.replace(/\/\/.*$/, ''))
  .join('\n');
if (/md5\s*\(\s*encodeURIComponent/.test(codeOnly)) {
  failures.push('bridge 代码中仍存在 md5(encodeURIComponent(...))，签名输入会被篡改');
} else {
  pass++;
}

// 必须与标准 MD5 常量一致（防实现被再次改坏）
const fixedVectors = [
  ['', 'd41d8cd98f00b204e9800998ecf8427e'],
  ['abc', '900150983cd24fb0d6963f7d28e17f72'],
  ['message digest', 'f96b697d7cb7938d525a2f31aaf161d0'],
  ['abcdefghijklmnopqrstuvwxyz', 'c3fcd3d76192e4007dfb496cca67e13b'],
  ['12345678901234567890123456789012345678901234567890123456789012345678901234567890', '57edf4a22be3c955ac49da2e2107b67a'],
  ['你好，世界', refMd5('你好，世界')],
];

for (const [input, expected] of fixedVectors) {
  const actual = scope.md5(input);
  if (actual === expected) {
    pass++;
  } else {
    failures.push(`固定向量 ${JSON.stringify(input)}: 期望 ${expected} 实际 ${actual}`);
  }
}

console.log('=== lx_bridge.html md5 单测 ===');
console.log(`bridge: ${BRIDGE}`);
console.log(`通过: ${pass}  失败: ${failures.length}`);
console.log(`旧实现会算错的用例（共 ${legacyDiverged.length} 个，证明修复必要性）:`);
console.log('  ' + legacyDiverged.join(', '));

if (failures.length > 0) {
  console.log('\n失败详情:');
  for (const f of failures) {
    console.log('  ✗ ' + f);
  }
  process.exit(1);
}

console.log('\n✓ 全部通过：新实现与标准 MD5（UTF-8 字节级）完全一致');
process.exit(0);
