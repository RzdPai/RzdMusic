/*
 * 生成 lx_bridge.html 的「标准字节级 MD5」代码块并原地替换旧实现。
 * 只在开发期运行一次；产物是 lx_bridge.html 中的内联 JS。
 *   node features/player/src/test/patch_md5.js --check   # 只检查是否需要打补丁
 *   node features/player/src/test/patch_md5.js           # 执行替换
 */
'use strict';

const fs = require('fs');
const path = require('path');

const BRIDGE = path.resolve(__dirname, '..', 'main', 'resources', 'rawfile', 'lx_bridge.html');
const MARK_START = '  // >>> LX-BRIDGE-MD5-START';
const MARK_END = '  // <<< LX-BRIDGE-MD5-END';

const BLOCK = `  // >>> LX-BRIDGE-MD5-START
  // ---------------------------------------------------------------------------
  // 标准字节级 MD5（RFC 1321），与 Node 的 crypto.createHash('md5') 完全一致。
  //
  // 历史实现有【三处】错误，是音源请求 403「时间签名验证失败」的根因：
  //   1) 调用侧把签名输入先做了 URI 转义（斜杠变 %2F、空格变 %20 …），签名输入被篡改；
  //   2) 内部按 UTF-16 code unit（charCodeAt）而非 UTF-8 字节填充，非 ASCII 全错；
  //   3) 常量表被抄错（例如第 22 项少了首位、第 57 项数值不对），即便纯 ASCII 输入也算错。
  // 现统一为「先取 UTF-8 字节，再走标准 MD5 轮函数 + 标准常量表」。
  // 回归由 features/player/src/test/md5_test.js 守住（逐条比对 node:crypto）。
  // ---------------------------------------------------------------------------

  // 标准 MD5 每轮左移位数（RFC 1321）
  var MD5_S = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
  ];

  // 标准 MD5 正弦常量表 T[i] = floor(abs(sin(i+1)) * 2^32)（RFC 1321）
  var MD5_K = [
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
  ];

  // 每轮消息字索引：g = 16 轮里的下标规则
  function md5WordIndex(round, i) {
    if (round === 0) return i;
    if (round === 1) return (5 * i + 1) % 16;
    if (round === 2) return (3 * i + 5) % 16;
    return (7 * i) % 16;
  }

  function md5RotateLeft(v, n) {
    return ((v << n) | (v >>> (32 - n))) | 0;
  }

  /**
   * 任意输入 → UTF-8 字节。
   * 支持 string / Uint8Array / 其他 TypedArray / ArrayBuffer / Array。
   */
  function md5ToBytes(input) {
    if (typeof input === 'string') return new TextEncoder().encode(input);
    if (input instanceof Uint8Array) return input;
    if (input instanceof ArrayBuffer) return new Uint8Array(input);
    if (ArrayBuffer.isView(input)) {
      return new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
    }
    if (Array.isArray(input)) return new Uint8Array(input);
    throw new Error('md5 param required a string or byte array');
  }

  /** 字节级 MD5，返回 32 位小写十六进制串。 */
  function md5Bytes(bytes) {
    var i;
    var len = bytes.length;

    // ---- 填充：0x80 + 若干 0x00，使总长 ≡ 56 (mod 64)，末尾 8 字节小端存放比特长度 ----
    var padLen = len + 1;
    while (padLen % 64 !== 56) { padLen++; }
    var total = padLen + 8;
    var msg = new Uint8Array(total);
    msg.set(bytes, 0);
    msg[len] = 0x80;
    // 比特长度 = 字节数 * 8；高 32 位保留（本桥接不会出现 >512MB 的输入）
    var bitLenLow = (len * 8) >>> 0;
    msg[total - 8] = bitLenLow & 0xff;
    msg[total - 7] = (bitLenLow >>> 8) & 0xff;
    msg[total - 6] = (bitLenLow >>> 16) & 0xff;
    msg[total - 5] = (bitLenLow >>> 24) & 0xff;
    msg[total - 4] = 0;
    msg[total - 3] = 0;
    msg[total - 2] = 0;
    msg[total - 1] = 0;

    // ---- 压缩 ----
    var a0 = 0x67452301;
    var b0 = 0xefcdab89;
    var c0 = 0x98badcfe;
    var d0 = 0x10325476;
    var m = new Array(16);

    for (var chunk = 0; chunk < total; chunk += 64) {
      for (i = 0; i < 16; i++) {
        var o = chunk + i * 4;
        m[i] = (msg[o] | (msg[o + 1] << 8) | (msg[o + 2] << 16) | (msg[o + 3] << 24)) | 0;
      }
      var a = a0, b = b0, c = c0, d = d0;
      for (i = 0; i < 64; i++) {
        var round = (i / 16) | 0;
        var f, g;
        if (round === 0) {
          f = (b & c) | ((~b) & d);
        } else if (round === 1) {
          f = (d & b) | ((~d) & c);
        } else if (round === 2) {
          f = b ^ c ^ d;
        } else {
          f = c ^ (b | (~d));
        }
        g = md5WordIndex(round, i);
        f = (f + a + MD5_K[i] + m[g]) | 0;
        a = d;
        d = c;
        c = b;
        b = (b + md5RotateLeft(f, MD5_S[i])) | 0;
      }
      a0 = (a0 + a) | 0;
      b0 = (b0 + b) | 0;
      c0 = (c0 + c) | 0;
      d0 = (d0 + d) | 0;
    }

    return md5WordToHex(a0) + md5WordToHex(b0) + md5WordToHex(c0) + md5WordToHex(d0);
  }

  /** 32 位整数 → 8 位小写十六进制（小端字节序输出，与标准 MD5 一致）。 */
  function md5WordToHex(word) {
    var hex = '';
    for (var i = 0; i < 4; i++) {
      var byte = (word >>> (i * 8)) & 0xff;
      hex += (byte < 16 ? '0' : '') + byte.toString(16);
    }
    return hex;
  }

  /** 对外签名：md5(string | bytes) → 32 位小写十六进制。 */
  function md5(input) {
    return md5Bytes(md5ToBytes(input));
  }
  // <<< LX-BRIDGE-MD5-END
`;

const check = process.argv.includes('--check');
const src = fs.readFileSync(BRIDGE, 'utf8');

/** 首次打补丁用：按当前实现（含错误的常量表）的边界切片替换。 */
function firstTimePatch(text) {
  const endAnchor = '  async function cryptoAesEncrypt(data, mode, key, iv) {';
  let start = text.indexOf('  // 标准字节级 MD5（RFC 1321）。');
  if (start !== -1) {
    // 连同上面的分隔注释行一起吃掉
    const sep = '  // ---------------------------------------------------------------------------\n';
    const sepIdx = text.lastIndexOf(sep, start);
    if (sepIdx !== -1) {
      start = sepIdx;
    }
  } else {
    start = text.indexOf('  function md5(str) {');
  }
  const end = text.indexOf(endAnchor);
  if (start === -1 || end === -1) {
    throw new Error('未能定位旧 md5 实现的边界');
  }
  return text.slice(0, start) + BLOCK + '\n' + text.slice(end);
}

if (src.includes(MARK_START)) {
  const start = src.indexOf(MARK_START);
  const end = src.indexOf(MARK_END);
  if (end === -1) {
    throw new Error('发现 MD5 起始标记但没有结束标记，文件可能被手工改坏');
  }
  const endLine = src.indexOf('\n', end) + 1;
  const next = src.slice(0, start) + BLOCK + src.slice(endLine);
  if (next === src) {
    console.log('MD5 代码块已是最新，无需修改。');
    process.exit(0);
  }
  if (check) {
    console.log('MD5 代码块与生成器不一致（需要重新生成）。');
    process.exit(1);
  }
  fs.writeFileSync(BRIDGE, next, 'utf8');
  console.log('已更新 MD5 代码块。');
  process.exit(0);
}

// 首次：把旧的（错的）md5 实现整段换成标准实现
if (check) {
  console.log('尚未打补丁。');
  process.exit(1);
}
fs.writeFileSync(BRIDGE, firstTimePatch(src), 'utf8');
console.log('首次打补丁完成：旧 md5 实现已替换为标准字节级 MD5。');
process.exit(0);
