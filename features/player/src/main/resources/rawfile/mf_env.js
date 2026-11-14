/**
 * MusicFree 插件运行时（浏览器侧 shim）。
 *
 * 目标：让 MusicFree 生态里那些 `module.exports = {...}` 的 CommonJS 插件，
 * 在**不改脚本**的前提下跑起来。插件普遍 `require` 这七个库：
 *   axios / crypto-js / qs / dayjs / big-integer / he / cheerio
 * 这里全部用原生 JS 实现（不依赖 CDN，离线可用）：
 *   · axios      → 走原生 http 桥（绕开 WebView 的 CORS）
 *   · cheerio    → 直接建在原生 DOM 上（解析 + querySelectorAll），体积几乎为零
 *   · crypto-js  → 同步 MD5 / SHA1 / SHA256 / HMAC / AES-CBC/ECB / Base64
 *   · 其余       → 插件实际用到的那一小块 API
 *
 * 与宿主（ArkTS）的协议：
 *   宿主 → 页：window._mf_load(gen, b64) / window._mf_call(callId, method, argsJson)
 *   页 → 宿主：{event:'mfReady'|'mfResult'|'nativeFetch'|'log', data:{...}}
 */
(function (global) {
  'use strict';

  var HAS_BRIDGE = typeof global.ohos_bridge !== 'undefined' && global.ohos_bridge !== null;

  function sendToNative(obj) {
    if (!HAS_BRIDGE) {
      console.log('[mf] no bridge: ' + obj.event);
      return;
    }
    try {
      global.ohos_bridge.onMessage(JSON.stringify(obj));
    } catch (e) {
      console.error('sendToNative error: ' + (e && e.message));
    }
  }

  function log(message) {
    sendToNative({ event: 'log', data: { message: '[mf] ' + message } });
  }

  // ───────────────────────────── bytes / base64 ─────────────────────────────

  function b64ToBytes(b64) {
    var bin = atob(b64);
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) {
      out[i] = bin.charCodeAt(i);
    }
    return out;
  }

  function bytesToB64(bytes) {
    var bin = '';
    var CHUNK = 0x8000;
    for (var i = 0; i < bytes.length; i += CHUNK) {
      var sub = bytes.subarray(i, Math.min(i + CHUNK, bytes.length));
      bin += String.fromCharCode.apply(null, sub);
    }
    return btoa(bin);
  }

  function utf8ToBytes(str) {
    return new TextEncoder().encode(str);
  }

  function bytesToUtf8(bytes) {
    return new TextDecoder('utf-8').decode(bytes);
  }

  // ───────────────────────────── MD5（同步） ─────────────────────────────

  var MD5_S = [7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21];

  var MD5_K = [
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391];

  function md5Bytes(input) {
    var msg = typeof input === 'string' ? utf8ToBytes(input) : input;
    var len = msg.length;
    var bitLenLo = (len << 3) >>> 0;
    var bitLenHi = Math.floor(len / 0x20000000) >>> 0;
    var withPad = (((len + 8) >> 6) + 1) << 6;
    var buf = new Uint8Array(withPad);
    buf.set(msg);
    buf[len] = 0x80;
    var dv = new DataView(buf.buffer);
    dv.setUint32(withPad - 8, bitLenLo, true);
    dv.setUint32(withPad - 4, bitLenHi, true);
    var h0 = 0x67452301, h1 = 0xefcdab89, h2 = 0x98badcfe, h3 = 0x10325476;
    var w = new Int32Array(16);
    for (var off = 0; off < withPad; off += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = dv.getInt32(off + i * 4, true);
      }
      var a = h0, b = h1, c = h2, d = h3;
      for (var r = 0; r < 64; r++) {
        var f, g;
        if (r < 16) {
          f = (b & c) | (~b & d);
          g = r;
        } else if (r < 32) {
          f = (d & b) | (~d & c);
          g = (5 * r + 1) % 16;
        } else if (r < 48) {
          f = b ^ c ^ d;
          g = (3 * r + 5) % 16;
        } else {
          f = c ^ (b | ~d);
          g = (7 * r) % 16;
        }
        var tmp = d;
        d = c;
        c = b;
        var sum = (a + f + MD5_K[r] + w[g]) | 0;
        b = (b + ((sum << MD5_S[r]) | (sum >>> (32 - MD5_S[r])))) | 0;
        a = tmp;
      }
      h0 = (h0 + a) | 0;
      h1 = (h1 + b) | 0;
      h2 = (h2 + c) | 0;
      h3 = (h3 + d) | 0;
    }
    var out = new Uint8Array(16);
    var ov = new DataView(out.buffer);
    ov.setInt32(0, h0, true);
    ov.setInt32(4, h1, true);
    ov.setInt32(8, h2, true);
    ov.setInt32(12, h3, true);
    return out;
  }

  function bytesToHex(bytes) {
    var hex = '';
    for (var i = 0; i < bytes.length; i++) {
      var h = bytes[i].toString(16);
      hex += h.length === 1 ? '0' + h : h;
    }
    return hex;
  }

  function md5Hex(input) {
    return bytesToHex(md5Bytes(input));
  }

  // ───────────────────────────── SHA1 / SHA256 / HMAC（同步） ─────────────────────────────

  function sha1Bytes(msg) {
    var len = msg.length;
    var withPad = (((len + 8) >> 6) + 1) << 6;
    var buf = new Uint8Array(withPad);
    buf.set(msg);
    buf[len] = 0x80;
    var dv = new DataView(buf.buffer);
    var bitsHi = Math.floor(len / 0x20000000) >>> 0;
    var bitsLo = (len << 3) >>> 0;
    dv.setUint32(withPad - 8, bitsHi, false);
    dv.setUint32(withPad - 4, bitsLo, false);
    var h = new Int32Array([0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0]);
    var w = new Int32Array(80);
    for (var off = 0; off < withPad; off += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = dv.getInt32(off + i * 4, false);
      }
      for (var i = 16; i < 80; i++) {
        var v = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16];
        w[i] = (v << 1) | (v >>> 31);
      }
      var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4];
      for (var j = 0; j < 80; j++) {
        var f, k;
        if (j < 20) {
          f = (b & c) | (~b & d); k = 0x5a827999;
        } else if (j < 40) {
          f = b ^ c ^ d; k = 0x6ed9eba1;
        } else if (j < 60) {
          f = (b & c) | (b & d) | (c & d); k = 0x8f1bbcdc;
        } else {
          f = b ^ c ^ d; k = 0xca62c1d6;
        }
        var t = (((a << 5) | (a >>> 27)) + f + e + k + w[j]) | 0;
        e = d; d = c; c = (b << 30) | (b >>> 2); b = a; a = t;
      }
      h[0] = (h[0] + a) | 0; h[1] = (h[1] + b) | 0; h[2] = (h[2] + c) | 0;
      h[3] = (h[3] + d) | 0; h[4] = (h[4] + e) | 0;
    }
    var out = new Uint8Array(20);
    var ov = new DataView(out.buffer);
    for (var i = 0; i < 5; i++) {
      ov.setInt32(i * 4, h[i], false);
    }
    return out;
  }

  var SHA256_K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2];

  function sha256Bytes(msg) {
    var len = msg.length;
    var withPad = (((len + 8) >> 6) + 1) << 6;
    var buf = new Uint8Array(withPad);
    buf.set(msg);
    buf[len] = 0x80;
    var dv = new DataView(buf.buffer);
    dv.setUint32(withPad - 8, Math.floor(len / 0x20000000) >>> 0, false);
    dv.setUint32(withPad - 4, (len << 3) >>> 0, false);
    var h = new Int32Array([0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]);
    var w = new Int32Array(64);
    for (var off = 0; off < withPad; off += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = dv.getInt32(off + i * 4, false);
      }
      for (var i = 16; i < 64; i++) {
        var x = w[i - 15], y = w[i - 2];
        var s0 = ((x >>> 7) | (x << 25)) ^ ((x >>> 18) | (x << 14)) ^ (x >>> 3);
        var s1 = ((y >>> 17) | (y << 15)) ^ ((y >>> 19) | (y << 13)) ^ (y >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0;
      }
      var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
      for (var j = 0; j < 64; j++) {
        var S1 = ((e >>> 6) | (e << 26)) ^ ((e >>> 11) | (e << 21)) ^ ((e >>> 25) | (e << 7));
        var ch = (e & f) ^ (~e & g);
        var t1 = (hh + S1 + ch + SHA256_K[j] + w[j]) | 0;
        var S0 = ((a >>> 2) | (a << 30)) ^ ((a >>> 13) | (a << 19)) ^ ((a >>> 22) | (a << 10));
        var maj = (a & b) ^ (a & c) ^ (b & c);
        var t2 = (S0 + maj) | 0;
        hh = g; g = f; f = e; e = (d + t1) | 0;
        d = c; c = b; b = a; a = (t1 + t2) | 0;
      }
      h[0] = (h[0] + a) | 0; h[1] = (h[1] + b) | 0; h[2] = (h[2] + c) | 0; h[3] = (h[3] + d) | 0;
      h[4] = (h[4] + e) | 0; h[5] = (h[5] + f) | 0; h[6] = (h[6] + g) | 0; h[7] = (h[7] + hh) | 0;
    }
    var out = new Uint8Array(32);
    var ov = new DataView(out.buffer);
    for (var i = 0; i < 8; i++) {
      ov.setInt32(i * 4, h[i], false);
    }
    return out;
  }

  function concatBytes(a, b) {
    var out = new Uint8Array(a.length + b.length);
    out.set(a);
    out.set(b, a.length);
    return out;
  }

  function hmacBytes(hashFn, blockSize, keyBytes, msgBytes) {
    if (keyBytes.length > blockSize) {
      keyBytes = hashFn(keyBytes);
    }
    var k = new Uint8Array(blockSize);
    k.set(keyBytes);
    var ipad = new Uint8Array(blockSize);
    var opad = new Uint8Array(blockSize);
    for (var i = 0; i < blockSize; i++) {
      ipad[i] = k[i] ^ 0x36;
      opad[i] = k[i] ^ 0x5c;
    }
    return hashFn(concatBytes(opad, hashFn(concatBytes(ipad, msgBytes))));
  }

  // ───────────────────────────── AES（同步，CBC / ECB + PKCS7） ─────────────────────────────

  var AES_SBOX = null;
  var AES_RCON = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d];

  function aesBuildSbox() {
    if (AES_SBOX !== null) {
      return AES_SBOX;
    }
    var sbox = new Uint8Array(256);
    var p = 1, q = 1;
    do {
      // p 乘 3，q 除 3
      p = (p ^ ((p << 1) & 0xff) ^ ((p & 0x80) ? 0x1b : 0)) & 0xff;
      q ^= q << 1;
      q ^= q << 2;
      q ^= q << 4;
      q &= 0xff;
      if (q & 0x80) {
        q ^= 0x09;
      }
      var x = q ^ ((q << 1) | (q >> 7)) ^ ((q << 2) | (q >> 6)) ^ ((q << 3) | (q >> 5)) ^ ((q << 4) | (q >> 4));
      sbox[p] = (x ^ 0x63) & 0xff;
    } while (p !== 1);
    sbox[0] = 0x63;
    AES_SBOX = sbox;
    return sbox;
  }

  function aesMul(a, b) {
    var p = 0;
    for (var i = 0; i < 8; i++) {
      if (b & 1) {
        p ^= a;
      }
      var hi = a & 0x80;
      a = (a << 1) & 0xff;
      if (hi) {
        a ^= 0x1b;
      }
      b >>= 1;
    }
    return p;
  }

  function aesExpandKey(key) {
    var Nk = key.length / 4;
    var Nr = Nk + 6;
    var w = new Uint8Array(16 * (Nr + 1));
    w.set(key);
    var sbox = aesBuildSbox();
    for (var i = Nk; i < 4 * (Nr + 1); i++) {
      var t = w.subarray((i - 1) * 4, i * 4);
      var tmp = [t[0], t[1], t[2], t[3]];
      if (i % Nk === 0) {
        var rot = [tmp[1], tmp[2], tmp[3], tmp[0]];
        tmp[0] = sbox[rot[0]] ^ AES_RCON[Math.floor(i / Nk) - 1];
        tmp[1] = sbox[rot[1]];
        tmp[2] = sbox[rot[2]];
        tmp[3] = sbox[rot[3]];
      } else if (Nk > 6 && i % Nk === 4) {
        tmp = [sbox[tmp[0]], sbox[tmp[1]], sbox[tmp[2]], sbox[tmp[3]]];
      }
      for (var j = 0; j < 4; j++) {
        w[i * 4 + j] = w[(i - Nk) * 4 + j] ^ tmp[j];
      }
    }
    return { key: w, rounds: Nr };
  }

  function aesEncryptBlock(block, ks) {
    var sbox = aesBuildSbox();
    var s = new Uint8Array(16);
    for (var i = 0; i < 16; i++) {
      s[i] = block[i] ^ ks.key[i];
    }
    for (var round = 1; round <= ks.rounds; round++) {
      // SubBytes + ShiftRows
      var t = new Uint8Array(16);
      for (var c = 0; c < 4; c++) {
        for (var r = 0; r < 4; r++) {
          t[r + 4 * c] = sbox[s[r + 4 * ((c + r) % 4)]];
        }
      }
      // MixColumns（最后一轮不做）
      if (round !== ks.rounds) {
        for (var c2 = 0; c2 < 4; c2++) {
          var a0 = t[4 * c2], a1 = t[4 * c2 + 1], a2 = t[4 * c2 + 2], a3 = t[4 * c2 + 3];
          s[4 * c2] = aesMul(a0, 2) ^ aesMul(a1, 3) ^ a2 ^ a3;
          s[4 * c2 + 1] = a0 ^ aesMul(a1, 2) ^ aesMul(a2, 3) ^ a3;
          s[4 * c2 + 2] = a0 ^ a1 ^ aesMul(a2, 2) ^ aesMul(a3, 3);
          s[4 * c2 + 3] = aesMul(a0, 3) ^ a1 ^ a2 ^ aesMul(a3, 2);
        }
      } else {
        s.set(t);
      }
      // AddRoundKey
      for (var k = 0; k < 16; k++) {
        s[k] ^= ks.key[round * 16 + k];
      }
    }
    return s;
  }

  function pkcs7Pad(bytes) {
    var pad = 16 - (bytes.length % 16);
    var out = new Uint8Array(bytes.length + pad);
    out.set(bytes);
    for (var i = bytes.length; i < out.length; i++) {
      out[i] = pad;
    }
    return out;
  }

  function pkcs7Unpad(bytes) {
    if (bytes.length === 0) {
      return bytes;
    }
    var pad = bytes[bytes.length - 1];
    if (pad < 1 || pad > 16 || pad > bytes.length) {
      return bytes;
    }
    return bytes.subarray(0, bytes.length - pad);
  }

  function aesCbcEncrypt(dataBytes, keyBytes, ivBytes) {
    var padded = pkcs7Pad(dataBytes);
    var ks = aesExpandKey(keyBytes);
    var prev = ivBytes;
    var out = new Uint8Array(padded.length);
    for (var off = 0; off < padded.length; off += 16) {
      var block = new Uint8Array(16);
      for (var i = 0; i < 16; i++) {
        block[i] = padded[off + i] ^ prev[i];
      }
      var enc = aesEncryptBlock(block, ks);
      out.set(enc, off);
      prev = enc;
    }
    return out;
  }

  function aesEcbEncrypt(dataBytes, keyBytes) {
    var padded = pkcs7Pad(dataBytes);
    var ks = aesExpandKey(keyBytes);
    var out = new Uint8Array(padded.length);
    for (var off = 0; off < padded.length; off += 16) {
      out.set(aesEncryptBlock(padded.subarray(off, off + 16), ks), off);
    }
    return out;
  }

  // ───────────────────────────── CryptoJS 兼容层 ─────────────────────────────

  function WordArray(words, sigBytes) {
    if (typeof words === 'string') {
      var bytes = utf8ToBytes(words);
      this.words = [];
      for (var i = 0; i < bytes.length; i++) {
        this.words[i >>> 2] |= bytes[i] << (24 - (i % 4) * 8);
      }
      this.sigBytes = bytes.length;
      return;
    }
    this.words = words || [];
    this.sigBytes = sigBytes !== undefined ? sigBytes : this.words.length * 4;
  }

  WordArray.prototype.toBytes = function () {
    var out = new Uint8Array(this.sigBytes);
    for (var i = 0; i < this.sigBytes; i++) {
      out[i] = (this.words[i >>> 2] >>> (24 - (i % 4) * 8)) & 0xff;
    }
    return out;
  };

  WordArray.prototype.toString = function (encoder) {
    return (encoder || CryptoJS.enc.Hex).stringify(this);
  };

  WordArray.prototype.concat = function (other) {
    var a = this.toBytes();
    var b = other.toBytes();
    return wordArrayFromBytes(concatBytes(a, b));
  };

  function wordArrayFromBytes(bytes) {
    var wa = new WordArray([], bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      wa.words[i >>> 2] |= bytes[i] << (24 - (i % 4) * 8);
    }
    return wa;
  }

  function wordArrayFromHex(hex) {
    var clean = String(hex).replace(/[^0-9a-fA-F]/g, '');
    var bytes = new Uint8Array(clean.length / 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = parseInt(clean.substr(i * 2, 2), 16);
    }
    return wordArrayFromBytes(bytes);
  }

  var CryptoJS = {
    lib: {
      WordArray: {
        create: function (words, sigBytes) {
          return new WordArray(words, sigBytes);
        }
      }
    },
    enc: {
      Hex: {
        stringify: function (wa) {
          return bytesToHex(wa.toBytes ? wa.toBytes() : new Uint8Array(wa));
        },
        parse: function (hex) {
          return wordArrayFromHex(hex);
        }
      },
      Base64: {
        stringify: function (wa) {
          return bytesToB64(wa.toBytes ? wa.toBytes() : new Uint8Array(wa));
        },
        parse: function (b64) {
          return wordArrayFromBytes(b64ToBytes(b64));
        }
      },
      Utf8: {
        stringify: function (wa) {
          return bytesToUtf8(wa.toBytes ? wa.toBytes() : new Uint8Array(wa));
        },
        parse: function (str) {
          return wordArrayFromBytes(utf8ToBytes(str));
        }
      },
      Latin1: {
        stringify: function (wa) {
          var bytes = wa.toBytes ? wa.toBytes() : new Uint8Array(wa);
          var s = '';
          for (var i = 0; i < bytes.length; i++) {
            s += String.fromCharCode(bytes[i]);
          }
          return s;
        },
        parse: function (str) {
          var bytes = new Uint8Array(str.length);
          for (var i = 0; i < str.length; i++) {
            bytes[i] = str.charCodeAt(i) & 0xff;
          }
          return wordArrayFromBytes(bytes);
        }
      }
    },
    mode: { CBC: 'CBC', ECB: 'ECB', CFB: 'CFB', OFB: 'OFB', CTR: 'CTR' },
    pad: { Pkcs7: 'Pkcs7', NoPadding: 'NoPadding', ZeroPadding: 'ZeroPadding' },
    algo: {}
  };

  function toBytesAny(value) {
    if (value instanceof WordArray) {
      return value.toBytes();
    }
    if (typeof value === 'string') {
      return utf8ToBytes(value);
    }
    if (value instanceof Uint8Array) {
      return value;
    }
    if (value instanceof ArrayBuffer) {
      return new Uint8Array(value);
    }
    if (value && typeof value.toBytes === 'function') {
      return value.toBytes();
    }
    return utf8ToBytes(String(value));
  }

  function hashToWordArray(bytes) {
    return wordArrayFromBytes(bytes);
  }

  CryptoJS.MD5 = function (message) {
    return hashToWordArray(md5Bytes(toBytesAny(message)));
  };
  CryptoJS.SHA1 = function (message) {
    return hashToWordArray(sha1Bytes(toBytesAny(message)));
  };
  CryptoJS.SHA256 = function (message) {
    return hashToWordArray(sha256Bytes(toBytesAny(message)));
  };
  CryptoJS.HmacMD5 = function (message, key) {
    return hashToWordArray(hmacBytes(md5Bytes, 64, toBytesAny(key), toBytesAny(message)));
  };
  CryptoJS.HmacSHA1 = function (message, key) {
    return hashToWordArray(hmacBytes(sha1Bytes, 64, toBytesAny(key), toBytesAny(message)));
  };
  CryptoJS.HmacSHA256 = function (message, key) {
    return hashToWordArray(hmacBytes(sha256Bytes, 64, toBytesAny(key), toBytesAny(message)));
  };

  /** OpenSSL EVP_BytesToKey（MD5 版本）：字符串 key 走这条路，与 crypto-js 一致。 */
  function evpKdf(passwordBytes, saltBytes, keyLen, ivLen) {
    var derived = new Uint8Array(0);
    var block = null;
    while (derived.length < keyLen + ivLen) {
      block = md5Bytes(concatBytes(block === null ? new Uint8Array(0) : block,
        concatBytes(passwordBytes, saltBytes)));
      derived = concatBytes(derived, block);
    }
    return { key: derived.subarray(0, keyLen), iv: derived.subarray(keyLen, keyLen + ivLen) };
  }

  function aesEncrypt(message, key, cfg) {
    cfg = cfg || {};
    var keyBytes;
    var salt = null;
    if (typeof key === 'string') {
      salt = new Uint8Array(8);
      crypto.getRandomValues(salt);
      keyBytes = evpKdf(utf8ToBytes(key), salt, 32, 16).key;
    } else {
      keyBytes = toBytesAny(key);
    }
    var ivBytes;
    if (cfg.iv) {
      ivBytes = toBytesAny(cfg.iv);
    } else if (salt !== null) {
      ivBytes = evpKdf(utf8ToBytes(key), salt, 32, 16).iv;
    } else {
      ivBytes = new Uint8Array(16);
    }
    var data = toBytesAny(message);
    var mode = cfg.mode === 'ECB' ? 'ECB' : 'CBC';
    var cipherBytes = mode === 'ECB' ? aesEcbEncrypt(data, keyBytes) : aesCbcEncrypt(data, keyBytes, ivBytes);
    if (salt !== null) {
      cipherBytes = concatBytes(concatBytes(utf8ToBytes('Salted__'), salt), cipherBytes);
    }
    var ct = wordArrayFromBytes(cipherBytes);
    return {
      ciphertext: ct,
      key: wordArrayFromBytes(keyBytes),
      iv: wordArrayFromBytes(ivBytes),
      salt: salt === null ? undefined : wordArrayFromBytes(salt),
      toString: function (encoder) {
        return (encoder || CryptoJS.enc.Base64).stringify(ct);
      }
    };
  }

  function aesDecrypt(cipherInput, key, cfg) {
    cfg = cfg || {};
    var cipherBytes = toBytesAny(cipherInput);
    var keyBytes;
    var ivBytes;
    var salt = null;
    if (typeof key === 'string') {
      if (cipherBytes.length > 16 && bytesToUtf8(cipherBytes.subarray(0, 8)) === 'Salted__') {
        salt = cipherBytes.subarray(8, 16);
        cipherBytes = cipherBytes.subarray(16);
      } else {
        salt = new Uint8Array(8);
      }
      var derived = evpKdf(utf8ToBytes(key), salt, 32, 16);
      keyBytes = derived.key;
      ivBytes = derived.iv;
    } else {
      keyBytes = toBytesAny(key);
      ivBytes = cfg.iv ? toBytesAny(cfg.iv) : new Uint8Array(16);
    }
    // 解密：CBC 用逆推（先反 AddRoundKey 再逆轮），这里用最简实现——CBC 解密
    var plain = aesCbcDecryptRaw(cipherBytes, keyBytes, ivBytes);
    return {
      toString: function (encoder) {
        return (encoder || CryptoJS.enc.Utf8).stringify(wordArrayFromBytes(plain));
      }
    };
  }

  // AES 解密需要逆 S-box 与逆列混合
  var AES_INV_SBOX = null;
  function aesBuildInvSbox() {
    if (AES_INV_SBOX !== null) {
      return AES_INV_SBOX;
    }
    var sbox = aesBuildSbox();
    var inv = new Uint8Array(256);
    for (var i = 0; i < 256; i++) {
      inv[sbox[i]] = i;
    }
    AES_INV_SBOX = inv;
    return inv;
  }

  function aesDecryptBlock(block, ks) {
    var inv = aesBuildInvSbox();
    var s = new Uint8Array(16);
    for (var i = 0; i < 16; i++) {
      s[i] = block[i] ^ ks.key[ks.rounds * 16 + i];
    }
    for (var round = ks.rounds - 1; round >= 0; round--) {
      // InvShiftRows + InvSubBytes
      var t = new Uint8Array(16);
      for (var c = 0; c < 4; c++) {
        for (var r = 0; r < 4; r++) {
          t[r + 4 * ((c + r) % 4)] = inv[s[r + 4 * c]];
        }
      }
      // AddRoundKey
      for (var k = 0; k < 16; k++) {
        t[k] ^= ks.key[round * 16 + k];
      }
      if (round !== 0) {
        // InvMixColumns
        for (var c2 = 0; c2 < 4; c2++) {
          var a0 = t[4 * c2], a1 = t[4 * c2 + 1], a2 = t[4 * c2 + 2], a3 = t[4 * c2 + 3];
          s[4 * c2] = aesMul(a0, 14) ^ aesMul(a1, 11) ^ aesMul(a2, 13) ^ aesMul(a3, 9);
          s[4 * c2 + 1] = aesMul(a0, 9) ^ aesMul(a1, 14) ^ aesMul(a2, 11) ^ aesMul(a3, 13);
          s[4 * c2 + 2] = aesMul(a0, 13) ^ aesMul(a1, 9) ^ aesMul(a2, 14) ^ aesMul(a3, 11);
          s[4 * c2 + 3] = aesMul(a0, 11) ^ aesMul(a1, 13) ^ aesMul(a2, 9) ^ aesMul(a3, 14);
        }
      } else {
        s.set(t);
      }
    }
    return s;
  }

  function aesCbcDecryptRaw(dataBytes, keyBytes, ivBytes) {
    var ks = aesExpandKey(keyBytes);
    var out = new Uint8Array(dataBytes.length);
    var prev = ivBytes;
    for (var off = 0; off < dataBytes.length; off += 16) {
      var block = dataBytes.subarray(off, off + 16);
      var dec = aesDecryptBlock(block, ks);
      for (var i = 0; i < 16; i++) {
        out[off + i] = dec[i] ^ prev[i];
      }
      prev = block;
    }
    return pkcs7Unpad(out);
  }

  CryptoJS.AES = { encrypt: aesEncrypt, decrypt: aesDecrypt };

  // ───────────────────────────── axios（走原生 http 桥） ─────────────────────────────

  var gFetchSeq = 0;
  var gFetchPending = {};

  global._mf_fetch_response = function (requestId, err, statusCode, headersJson, body) {
    var entry = gFetchPending[requestId];
    if (!entry) {
      return;
    }
    delete gFetchPending[requestId];
    if (err) {
      var msg = 'Network Error';
      try {
        msg = JSON.parse(err).message || msg;
      } catch (e) {
        msg = String(err).substring(0, 120);
      }
      var ne = new Error(msg);
      ne.code = 'ERR_NETWORK';
      entry.reject(ne);
      return;
    }
    var headers = {};
    try {
      var raw = JSON.parse(headersJson || '{}');
      var keys = Object.keys(raw);
      for (var i = 0; i < keys.length; i++) {
        headers[keys[i].toLowerCase()] = raw[keys[i]];
      }
    } catch (e) {
      // ignore
    }
    entry.resolve({ status: statusCode, headers: headers, body: body });
  };

  function nativeRequest(options) {
    return new Promise(function (resolve, reject) {
      var id = ++gFetchSeq;
      gFetchPending[id] = { resolve: resolve, reject: reject };
      sendToNative({
        event: 'nativeFetch',
        data: {
          requestId: id,
          url: options.url,
          method: options.method || 'GET',
          headers: options.headers || {},
          body: options.body || '',
          timeout: options.timeout || 15000
        }
      });
    });
  }

  function appendParams(url, params) {
    if (!params) {
      return url;
    }
    var parts = [];
    var keys = Object.keys(params);
    for (var i = 0; i < keys.length; i++) {
      var v = params[keys[i]];
      if (v === undefined || v === null) {
        continue;
      }
      parts.push(encodeURIComponent(keys[i]) + '=' + encodeURIComponent(typeof v === 'object' ? JSON.stringify(v) : v));
    }
    if (parts.length === 0) {
      return url;
    }
    return url + (url.indexOf('?') >= 0 ? '&' : '?') + parts.join('&');
  }

  function axiosInstance(defaults) {
    defaults = defaults || {};

    function request(config) {
      config = config || {};
      var method = (config.method || 'get').toUpperCase();
      var url = config.url || '';
      var baseURL = config.baseURL || defaults.baseURL || '';
      if (baseURL && url.indexOf('http') !== 0) {
        url = baseURL.replace(/\/$/, '') + (url.charAt(0) === '/' ? url : '/' + url);
      }
      url = appendParams(url, config.params || defaults.params);
      var headers = {};
      var hk = Object.keys(defaults.headers || {});
      for (var i = 0; i < hk.length; i++) {
        headers[hk[i]] = defaults.headers[hk[i]];
      }
      var ck = Object.keys(config.headers || {});
      for (var j = 0; j < ck.length; j++) {
        headers[ck[j]] = config.headers[ck[j]];
      }
      var body = '';
      if (config.data !== undefined && config.data !== null) {
        if (typeof config.data === 'string') {
          body = config.data;
        } else if (typeof config.data === 'object') {
          var ct = '';
          var keys = Object.keys(headers);
          for (var k = 0; k < keys.length; k++) {
            if (keys[k].toLowerCase() === 'content-type') {
              ct = String(headers[keys[k]]);
            }
          }
          if (ct.indexOf('x-www-form-urlencoded') >= 0) {
            body = qsStringify(config.data);
          } else {
            body = JSON.stringify(config.data);
            if (ct.length === 0) {
              headers['Content-Type'] = 'application/json';
            }
          }
        } else {
          body = String(config.data);
        }
      }
      var timeout = config.timeout || defaults.timeout || 15000;
      return nativeRequest({ url: url, method: method, headers: headers, body: body, timeout: timeout })
        .then(function (resp) {
          var data = resp.body;
          var respType = config.responseType || defaults.responseType || '';
          if (respType !== 'text' && respType !== 'arraybuffer') {
            try {
              data = JSON.parse(resp.body);
            } catch (e) {
              data = resp.body;
            }
          }
          var out = {
            data: data,
            status: resp.status,
            statusText: String(resp.status),
            headers: resp.headers,
            config: config,
            request: {}
          };
          if (config.validateStatus && !config.validateStatus(resp.status)) {
            var err = new Error('Request failed with status code ' + resp.status);
            err.response = out;
            err.config = config;
            throw err;
          }
          if (resp.status >= 400) {
            var e2 = new Error('Request failed with status code ' + resp.status);
            e2.response = out;
            e2.config = config;
            throw e2;
          }
          return out;
        });
    }

    var instance = function (configOrUrl, config) {
      if (typeof configOrUrl === 'string') {
        return request(Object.assign({ url: configOrUrl }, config || {}));
      }
      return request(configOrUrl);
    };
    instance.request = request;
    instance.get = function (url, config) {
      return request(Object.assign({}, config || {}, { url: url, method: 'get' }));
    };
    instance.delete = function (url, config) {
      return request(Object.assign({}, config || {}, { url: url, method: 'delete' }));
    };
    instance.head = function (url, config) {
      return request(Object.assign({}, config || {}, { url: url, method: 'head' }));
    };
    instance.options = function (url, config) {
      return request(Object.assign({}, config || {}, { url: url, method: 'options' }));
    };
    instance.post = function (url, data, config) {
      return request(Object.assign({}, config || {}, { url: url, method: 'post', data: data }));
    };
    instance.put = function (url, data, config) {
      return request(Object.assign({}, config || {}, { url: url, method: 'put', data: data }));
    };
    instance.patch = function (url, data, config) {
      return request(Object.assign({}, config || {}, { url: url, method: 'patch', data: data }));
    };
    instance.defaults = defaults;
    instance.interceptors = {
      request: { use: function () {} },
      response: { use: function () {} }
    };
    instance.create = function (cfg) {
      return axiosInstance(Object.assign({}, defaults, cfg || {}));
    };
    return instance;
  }

  var axios = axiosInstance({
    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36' },
    timeout: 20000
  });
  // 插件里的 `import axios from 'axios'` 被 babel 编译成 `_axios.default`；
  // 这里补一个自引用，兼容"已解包"和"未解包"两种取值路径。
  axios.default = axios;

  // ───────────────────────────── qs ─────────────────────────────

  function qsStringify(obj, prefix) {
    var out = [];
    var keys = Object.keys(obj || {});
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      var val = obj[key];
      if (val === undefined) {
        continue;
      }
      var name = prefix ? prefix + '[' + key + ']' : key;
      if (val === null) {
        out.push(encodeURIComponent(name) + '=');
      } else if (Array.isArray(val)) {
        for (var j = 0; j < val.length; j++) {
          out.push(encodeURIComponent(name + '[' + j + ']') + '=' + encodeURIComponent(val[j] === null ? '' : val[j]));
        }
      } else if (typeof val === 'object') {
        var nested = qsStringify(val, name);
        if (nested.length > 0) {
          out.push(nested);
        }
      } else {
        out.push(encodeURIComponent(name) + '=' + encodeURIComponent(val));
      }
    }
    return out.join('&');
  }

  function qsParse(str) {
    var out = {};
    if (!str) {
      return out;
    }
    var parts = String(str).replace(/^\?/, '').split('&');
    for (var i = 0; i < parts.length; i++) {
      if (!parts[i]) {
        continue;
      }
      var idx = parts[i].indexOf('=');
      var k = idx < 0 ? parts[i] : parts[i].substring(0, idx);
      var v = idx < 0 ? '' : parts[i].substring(idx + 1);
      try {
        k = decodeURIComponent(k.replace(/\+/g, ' '));
        v = decodeURIComponent(v.replace(/\+/g, ' '));
      } catch (e) {
        // keep raw
      }
      var m = /^(.+)\[([0-9]*)\]$/.exec(k);
      if (m) {
        if (!out[m[1]]) {
          out[m[1]] = [];
        }
        out[m[1]].push(v);
      } else {
        out[k] = v;
      }
    }
    return out;
  }

  var qs = { stringify: qsStringify, parse: qsParse, encode: qsStringify, decode: qsParse };

  // ───────────────────────────── dayjs ─────────────────────────────

  function pad2(n) {
    return n < 10 ? '0' + n : String(n);
  }

  function Dayjs(input) {
    if (input instanceof Dayjs) {
      this.d = new Date(input.d.getTime());
    } else if (input === undefined || input === null) {
      this.d = new Date();
    } else if (input instanceof Date) {
      this.d = new Date(input.getTime());
    } else if (typeof input === 'number') {
      this.d = new Date(input);
    } else {
      this.d = new Date(String(input));
    }
  }

  Dayjs.prototype.format = function (fmt) {
    if (!fmt) {
      return this.d.toISOString();
    }
    var d = this.d;
    var map = {
      'YYYY': String(d.getFullYear()),
      'YY': String(d.getFullYear()).substring(2),
      'MM': pad2(d.getMonth() + 1),
      'M': String(d.getMonth() + 1),
      'DD': pad2(d.getDate()),
      'D': String(d.getDate()),
      'HH': pad2(d.getHours()),
      'H': String(d.getHours()),
      'mm': pad2(d.getMinutes()),
      'm': String(d.getMinutes()),
      'ss': pad2(d.getSeconds()),
      's': String(d.getSeconds()),
      'SSS': String(d.getMilliseconds()).padStart(3, '0'),
      'dddd': ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][d.getDay()]
    };
    var out = fmt;
    var keys = ['YYYY', 'YY', 'MM', 'DD', 'HH', 'mm', 'ss', 'SSS', 'dddd', 'M', 'D', 'H', 'm', 's'];
    for (var i = 0; i < keys.length; i++) {
      out = out.split(keys[i]).join(map[keys[i]]);
    }
    return out;
  };
  Dayjs.prototype.add = function (n, unit) {
    var d = new Date(this.d.getTime());
    unit = unit || 'day';
    if (unit.indexOf('day') >= 0 || unit === 'd') {
      d.setDate(d.getDate() + n);
    } else if (unit.indexOf('month') >= 0 || unit === 'M') {
      d.setMonth(d.getMonth() + n);
    } else if (unit.indexOf('year') >= 0 || unit === 'y') {
      d.setFullYear(d.getFullYear() + n);
    } else if (unit.indexOf('hour') >= 0 || unit === 'h') {
      d.setHours(d.getHours() + n);
    } else if (unit.indexOf('minute') >= 0 || unit === 'm') {
      d.setMinutes(d.getMinutes() + n);
    } else if (unit.indexOf('second') >= 0 || unit === 's') {
      d.setSeconds(d.getSeconds() + n);
    } else {
      d.setTime(d.getTime() + n);
    }
    return new Dayjs(d);
  };
  Dayjs.prototype.subtract = function (n, unit) {
    return this.add(-n, unit);
  };
  Dayjs.prototype.valueOf = function () {
    return this.d.getTime();
  };
  Dayjs.prototype.unix = function () {
    return Math.floor(this.d.getTime() / 1000);
  };
  Dayjs.prototype.toDate = function () {
    return new Date(this.d.getTime());
  };
  Dayjs.prototype.startOf = function (unit) {
    var d = new Date(this.d.getTime());
    if (unit === 'day') {
      d.setHours(0, 0, 0, 0);
    } else if (unit === 'month') {
      d.setDate(1);
      d.setHours(0, 0, 0, 0);
    } else if (unit === 'year') {
      d.setMonth(0, 1);
      d.setHours(0, 0, 0, 0);
    }
    return new Dayjs(d);
  };
  Dayjs.prototype.diff = function (other, unit) {
    var ms = this.d.getTime() - new Dayjs(other).d.getTime();
    if (unit === 'day') {
      return Math.floor(ms / 86400000);
    }
    if (unit === 'hour') {
      return Math.floor(ms / 3600000);
    }
    if (unit === 'minute') {
      return Math.floor(ms / 60000);
    }
    return ms;
  };

  function dayjs(input) {
    return new Dayjs(input);
  }
  dayjs.unix = function (s) {
    return new Dayjs(s * 1000);
  };
  dayjs.extend = function () {
    return dayjs;
  };

  // ───────────────────────────── big-integer ─────────────────────────────

  function BigIntWrapper(v) {
    this.v = typeof v === 'bigint' ? v : BigInt(v);
  }

  BigIntWrapper.prototype.add = function (x) {
    return new BigIntWrapper(this.v + toBig(x));
  };
  BigIntWrapper.prototype.subtract = function (x) {
    return new BigIntWrapper(this.v - toBig(x));
  };
  BigIntWrapper.prototype.multiply = function (x) {
    return new BigIntWrapper(this.v * toBig(x));
  };
  BigIntWrapper.prototype.divide = function (x) {
    return new BigIntWrapper(this.v / toBig(x));
  };
  BigIntWrapper.prototype.mod = function (x) {
    return new BigIntWrapper(this.v % toBig(x));
  };
  BigIntWrapper.prototype.pow = function (x) {
    return new BigIntWrapper(this.v ** BigInt(x));
  };
  BigIntWrapper.prototype.shiftLeft = function (n) {
    return new BigIntWrapper(this.v << BigInt(n));
  };
  BigIntWrapper.prototype.shiftRight = function (n) {
    return new BigIntWrapper(this.v >> BigInt(n));
  };
  BigIntWrapper.prototype.and = function (x) {
    return new BigIntWrapper(this.v & toBig(x));
  };
  BigIntWrapper.prototype.or = function (x) {
    return new BigIntWrapper(this.v | toBig(x));
  };
  BigIntWrapper.prototype.xor = function (x) {
    return new BigIntWrapper(this.v ^ toBig(x));
  };
  BigIntWrapper.prototype.toString = function (radix) {
    return this.v.toString(radix === 16 ? 16 : (radix || 10));
  };
  BigIntWrapper.prototype.valueOf = function () {
    return Number(this.v);
  };
  BigIntWrapper.prototype.toJSNumber = function () {
    return Number(this.v);
  };
  BigIntWrapper.prototype.equals = function (x) {
    return this.v === toBig(x);
  };
  BigIntWrapper.prototype.eq = BigIntWrapper.prototype.equals;
  BigIntWrapper.prototype.lt = function (x) {
    return this.v < toBig(x);
  };
  BigIntWrapper.prototype.leq = function (x) {
    return this.v <= toBig(x);
  };
  BigIntWrapper.prototype.gt = function (x) {
    return this.v > toBig(x);
  };
  BigIntWrapper.prototype.geq = function (x) {
    return this.v >= toBig(x);
  };
  BigIntWrapper.prototype.isZero = function () {
    return this.v === BigInt(0);
  };

  function toBig(x) {
    if (x instanceof BigIntWrapper) {
      return x.v;
    }
    return typeof x === 'bigint' ? x : BigInt(x);
  }

  function bigIntFactory(v, radix) {
    if (radix !== undefined && radix !== 10 && typeof v === 'string') {
      // big-integer 的 `bigInt('ff', 16)` 语义：按指定进制解析
      var s = v.trim();
      var neg = s.charAt(0) === '-';
      if (neg) {
        s = s.substring(1);
      }
      var acc = BigInt(0);
      var base = BigInt(radix);
      for (var i = 0; i < s.length; i++) {
        var digit = parseInt(s.charAt(i), radix);
        if (isNaN(digit)) {
          continue;
        }
        acc = acc * base + BigInt(digit);
      }
      return new BigIntWrapper(neg ? -acc : acc);
    }
    return new BigIntWrapper(v === undefined ? 0 : v);
  }
  bigIntFactory.zero = new BigIntWrapper(0);
  bigIntFactory.one = new BigIntWrapper(1);

  // ───────────────────────────── he ─────────────────────────────

  var HE_ENTITIES = {
    amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: '\u00a0',
    copy: '\u00a9', reg: '\u00ae', trade: '\u2122', hellip: '\u2026',
    mdash: '\u2014', ndash: '\u2013', lsquo: '\u2018', rsquo: '\u2019',
    ldquo: '\u201c', rdquo: '\u201d', middot: '\u00b7', times: '\u00d7',
    divide: '\u00f7', deg: '\u00b0', plusmn: '\u00b1', laquo: '\u00ab', raquo: '\u00bb'
  };

  var he = {
    decode: function (str) {
      if (typeof str !== 'string') {
        return str;
      }
      return str.replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);?/g, function (m, body) {
        if (body.charAt(0) === '#') {
          var code = body.charAt(1) === 'x' || body.charAt(1) === 'X'
            ? parseInt(body.substring(2), 16) : parseInt(body.substring(1), 10);
          if (!isNaN(code)) {
            try {
              return String.fromCodePoint(code);
            } catch (e) {
              return m;
            }
          }
          return m;
        }
        var key = body.toLowerCase();
        return HE_ENTITIES[key] !== undefined ? HE_ENTITIES[key] : m;
      });
    },
    encode: function (str) {
      return String(str).replace(/[&<>"']/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' }[c];
      });
    },
    escape: function (str) {
      return he.encode(str);
    }
  };

  // ───────────────────────────── cheerio（基于原生 DOM） ─────────────────────────────

  function CheerioNode(el) {
    this.el = el;
  }

  function wrap(el) {
    return el === null || el === undefined ? null : new CheerioNode(el);
  }

  function Cheerio(nodes) {
    this.nodes = nodes || [];
    this.length = this.nodes.length;
  }

  Cheerio.prototype.each = function (fn) {
    for (var i = 0; i < this.nodes.length; i++) {
      fn.call(this.nodes[i], i, this.nodes[i]);
    }
    return this;
  };
  Cheerio.prototype.map = function (fn) {
    var out = [];
    for (var i = 0; i < this.nodes.length; i++) {
      var r = fn.call(this.nodes[i], i, this.nodes[i]);
      if (r !== null && r !== undefined) {
        out.push(r);
      }
    }
    return new Cheerio(out);
  };
  Cheerio.prototype.get = function (i) {
    return i === undefined ? this.nodes.slice() : this.nodes[i];
  };
  Cheerio.prototype.toArray = function () {
    return this.nodes.slice();
  };
  Cheerio.prototype.eq = function (i) {
    var idx = i < 0 ? this.nodes.length + i : i;
    return new Cheerio(idx >= 0 && idx < this.nodes.length ? [this.nodes[idx]] : []);
  };
  Cheerio.prototype.first = function () {
    return this.eq(0);
  };
  Cheerio.prototype.last = function () {
    return this.eq(-1);
  };
  Cheerio.prototype.find = function (selector) {
    var out = [];
    for (var i = 0; i < this.nodes.length; i++) {
      var node = this.nodes[i];
      if (node.nodeType === 1) {
        var found = node.querySelectorAll(selector);
        for (var j = 0; j < found.length; j++) {
          out.push(found[j]);
        }
      }
    }
    return new Cheerio(out);
  };
  Cheerio.prototype.children = function (selector) {
    var out = [];
    for (var i = 0; i < this.nodes.length; i++) {
      var kids = this.nodes[i].children || [];
      for (var j = 0; j < kids.length; j++) {
        if (kids[j].nodeType === 1) {
          if (!selector || kids[j].matches(selector)) {
            out.push(kids[j]);
          }
        }
      }
    }
    return new Cheerio(out);
  };
  Cheerio.prototype.parent = function () {
    var out = [];
    for (var i = 0; i < this.nodes.length; i++) {
      var p = this.nodes[i].parentElement;
      if (p) {
        out.push(p);
      }
    }
    return new Cheerio(out);
  };
  Cheerio.prototype.next = function () {
    var out = [];
    for (var i = 0; i < this.nodes.length; i++) {
      var n = this.nodes[i].nextElementSibling;
      if (n) {
        out.push(n);
      }
    }
    return new Cheerio(out);
  };
  Cheerio.prototype.prev = function () {
    var out = [];
    for (var i = 0; i < this.nodes.length; i++) {
      var n = this.nodes[i].previousElementSibling;
      if (n) {
        out.push(n);
      }
    }
    return new Cheerio(out);
  };
  Cheerio.prototype.text = function () {
    var s = '';
    for (var i = 0; i < this.nodes.length; i++) {
      s += this.nodes[i].textContent || '';
    }
    return s;
  };
  Cheerio.prototype.html = function (value) {
    if (value === undefined) {
      return this.nodes.length > 0 ? this.nodes[0].innerHTML : null;
    }
    for (var i = 0; i < this.nodes.length; i++) {
      this.nodes[i].innerHTML = value;
    }
    return this;
  };
  Cheerio.prototype.attr = function (name, value) {
    if (value === undefined) {
      if (this.nodes.length === 0) {
        return undefined;
      }
      var v = this.nodes[0].getAttribute(name);
      return v === null ? undefined : v;
    }
    for (var i = 0; i < this.nodes.length; i++) {
      this.nodes[i].setAttribute(name, value);
    }
    return this;
  };
  Cheerio.prototype.removeAttr = function (name) {
    for (var i = 0; i < this.nodes.length; i++) {
      this.nodes[i].removeAttribute(name);
    }
    return this;
  };
  Cheerio.prototype.hasClass = function (cls) {
    return this.nodes.length > 0 && this.nodes[0].classList.contains(cls);
  };
  Cheerio.prototype.addClass = function (cls) {
    for (var i = 0; i < this.nodes.length; i++) {
      this.nodes[i].classList.add(cls);
    }
    return this;
  };
  Cheerio.prototype.removeClass = function (cls) {
    for (var i = 0; i < this.nodes.length; i++) {
      this.nodes[i].classList.remove(cls);
    }
    return this;
  };
  Cheerio.prototype.remove = function () {
    for (var i = 0; i < this.nodes.length; i++) {
      if (this.nodes[i].parentNode) {
        this.nodes[i].parentNode.removeChild(this.nodes[i]);
      }
    }
    return this;
  };
  Cheerio.prototype.is = function (selector) {
    for (var i = 0; i < this.nodes.length; i++) {
      if (this.nodes[i].matches && this.nodes[i].matches(selector)) {
        return true;
      }
    }
    return false;
  };
  Cheerio.prototype.closest = function (selector) {
    var out = [];
    for (var i = 0; i < this.nodes.length; i++) {
      var n = this.nodes[i].closest ? this.nodes[i].closest(selector) : null;
      if (n && out.indexOf(n) < 0) {
        out.push(n);
      }
    }
    return new Cheerio(out);
  };
  Cheerio.prototype.filter = function (fn) {
    var out = [];
    for (var i = 0; i < this.nodes.length; i++) {
      if (fn.call(this.nodes[i], i, this.nodes[i])) {
        out.push(this.nodes[i]);
      }
    }
    return new Cheerio(out);
  };
  Cheerio.prototype.prop = function (name) {
    return this.nodes.length > 0 ? this.nodes[0][name] : undefined;
  };
  Cheerio.prototype.val = function () {
    return this.nodes.length > 0 ? this.nodes[0].value : undefined;
  };
  // 插件里有 `for (const el of $(...).children())`：cheerio 的集合本身可迭代
  Cheerio.prototype[Symbol.iterator] = function () {
    return this.nodes[Symbol.iterator]();
  };

  // 把 DOM 元素映射成 cheerio 节点字段（属性可直接读）
  function decorateDomNode(el) {
    if (el.__cheerioDecorated) {
      return el;
    }
    try {
      Object.defineProperty(el, '__cheerioDecorated', { value: true, enumerable: false });
      Object.defineProperty(el, 'tagName', {
        get: function () {
          return this.nodeName ? this.nodeName.toLowerCase() : '';
        },
        configurable: true
      });
      Object.defineProperty(el, 'attribs', {
        get: function () {
          var out = {};
          for (var i = 0; i < this.attributes.length; i++) {
            out[this.attributes[i].name] = this.attributes[i].value;
          }
          return out;
        },
        configurable: true
      });
      if (!el[Symbol.iterator]) {
        Object.defineProperty(el, Symbol.iterator, {
          value: function () {
            var kids = [];
            for (var i = 0; i < this.children.length; i++) {
              if (this.children[i].nodeType === 1) {
                kids.push(this.children[i]);
              }
            }
            return kids[Symbol.iterator]();
          },
          configurable: true
        });
      }
    } catch (e) {
      // ignore
    }
    return el;
  }

  function cheerioLoad(html) {
    var container = document.createElement('div');
    container.innerHTML = html === undefined || html === null ? '' : String(html);
    var root = container;
    function $(selector) {
      if (selector === undefined || selector === null) {
        return new Cheerio([]);
      }
      if (typeof selector === 'string') {
        var trimmed = selector.trim();
        if (trimmed.charAt(0) === '<') {
          var tmp = document.createElement('div');
          tmp.innerHTML = trimmed;
          var nodes = [];
          for (var i = 0; i < tmp.children.length; i++) {
            nodes.push(decorateDomNode(tmp.children[i]));
          }
          return new Cheerio(nodes);
        }
        var found = root.querySelectorAll(selector);
        var list = [];
        for (var j = 0; j < found.length; j++) {
          list.push(decorateDomNode(found[j]));
        }
        return new Cheerio(list);
      }
      if (selector && selector.nodeType === 1) {
        return new Cheerio([decorateDomNode(selector)]);
      }
      if (selector instanceof Cheerio) {
        return selector;
      }
      return new Cheerio([]);
    }
    $.html = function (sel) {
      if (sel === undefined) {
        return root.innerHTML;
      }
      var r = $(sel);
      return r.length > 0 ? r.html() : null;
    };
    $.root = function () {
      return new Cheerio([root]);
    };
    $.load = cheerioLoad;
    $.contains = function (a, b) {
      return a !== b && a.contains && a.contains(b);
    };
    return $;
  }

  // ───────────────────────────── CommonJS 加载器 ─────────────────────────────

  var MODULES = {
    'axios': axios,
    'crypto-js': CryptoJS,
    'qs': qs,
    'dayjs': dayjs,
    'big-integer': bigIntFactory,
    'he': he,
    'cheerio': { load: cheerioLoad, default: { load: cheerioLoad }, __esModule: true }
  };
  // 同上：`import CryptoJS from 'crypto-js'` / `import qs from 'qs'` 等默认导入要走 `.default`
  CryptoJS.default = CryptoJS;
  qs.default = qs;
  dayjs.default = dayjs;
  bigIntFactory.default = bigIntFactory;

  function makeRequire() {
    return function require(name) {
      var key = String(name).replace(/^node:/, '');
      if (MODULES[key] !== undefined) {
        return MODULES[key];
      }
      // 未实现的依赖：返回一个"惰性空壳"，让插件加载不中断（调用时才报错）
      log('未实现的依赖: ' + key);
      return new Proxy({}, {
        get: function (target, prop) {
          if (prop === 'then' || typeof prop === 'symbol') {
            return undefined;
          }
          return function () {
            throw new Error('module not implemented: ' + key + '.' + String(prop));
          };
        }
      });
    };
  }

  var plugin = null;
  var pluginMeta = { platform: '', version: '', methods: [] };

  function loadPlugin(code) {
    var module = { exports: {} };
    var exportsObj = module.exports;
    var require = makeRequire();
    var fn = new Function('module', 'exports', 'require', 'console', 'setTimeout', 'clearTimeout',
      'setInterval', 'clearInterval', 'Buffer', 'global', 'process', 'globalThis', code);
    var consoleShim = {
      log: function () {
        log(Array.prototype.slice.call(arguments).join(' '));
      },
      info: function () {},
      warn: function () {},
      error: function () {
        log('[error] ' + Array.prototype.slice.call(arguments).join(' '));
      }
    };
    var processShim = { env: {}, nextTick: function (f) { setTimeout(f, 0); }, version: 'v18.0.0' };
    var bufferShim = {
      from: function (s, enc) {
        if (enc === 'base64') {
          return b64ToBytes(s);
        }
        return utf8ToBytes(String(s));
      },
      isBuffer: function () {
        return false;
      }
    };
    var sandboxGlobal = {
      setTimeout: setTimeout, clearTimeout: clearTimeout, setInterval: setInterval,
      clearInterval: clearInterval, console: consoleShim, process: processShim,
      Buffer: bufferShim, atob: atob, btoa: btoa, global: null, globalThis: null
    };
    sandboxGlobal.global = sandboxGlobal;
    sandboxGlobal.globalThis = sandboxGlobal;
    fn.call(sandboxGlobal, module, exportsObj, require, consoleShim, setTimeout, clearTimeout,
      setInterval, clearInterval, bufferShim, sandboxGlobal, processShim, sandboxGlobal);
    var exported = module.exports;
    if (exported && exported.__esModule && exported.default) {
      exported = exported.default;
    }
    if (!exported || (typeof exported !== 'object' && typeof exported !== 'function')) {
      throw new Error('插件没有导出对象（module.exports 为空）');
    }
    return exported;
  }

  // ───────────────────────────── 对外协议 ─────────────────────────────

  // 分片注入：单次 runJavaScript 有长度上限（API 26 会截断并报 Invalid token），
  // 大插件必须切片传，最后一次性拼回。
  var gChunks = { gen: -1, parts: [] };

  global._mf_begin = function (gen) {
    gChunks = { gen: gen, parts: [] };
  };

  global._mf_chunk = function (gen, part) {
    if (gChunks.gen !== gen) {
      gChunks = { gen: gen, parts: [] };
    }
    gChunks.parts.push(part);
  };

  global._mf_end = function (gen) {
    if (gChunks.gen !== gen) {
      sendToNative({ event: 'mfReady', data: { gen: gen, ok: false, error: 'chunk gen mismatch' } });
      return;
    }
    var joined = gChunks.parts.join('');
    gChunks = { gen: -1, parts: [] };
    global._mf_load(gen, joined);
  };

  global._mf_load = function (gen, b64) {
    var code;
    try {
      code = bytesToUtf8(b64ToBytes(b64));
    } catch (e) {
      sendToNative({ event: 'mfReady', data: { gen: gen, ok: false, error: 'decode failed: ' + e.message } });
      return;
    }
    applyPluginCode(gen, code);
  };

  // 快通道：载荷由原生 onInterceptRequest 一次性返回**原文**（不再 base64）。
  // 协议与 LX 桥的 _lx_init_fetch 一致（这里改叫 _mf_init_*，避开已有的 _mf_fetch_response）：先回 ack 再解析/装载，原生据此判断
  // 「载荷是否到手」而不是「插件是否已就绪」——后者会把插件自身启动慢误判成通道失败。
  var MF_INIT_URL = 'https://rzd-mf-init.invalid/plugin.js';
  /** 最近一次请求载荷的代际：晚到的旧代际响应直接丢弃。 */
  var mfFetchGen = -1;

  global._mf_init_fetch = function (gen) {
    mfFetchGen = gen;
    // 不加 cache:'no-store'：会带出 Cache-Control 请求头变成非简单请求、触发 CORS 预检
    fetch(MF_INIT_URL + '?gen=' + gen).then(function (resp) {
      if (!resp.ok) {
        throw new Error('http ' + resp.status);
      }
      return resp.text();
    }).then(function (text) {
      if (gen !== mfFetchGen) {
        log('快通道丢弃过期代际 gen=' + gen + ' 当前=' + mfFetchGen);
        return;
      }
      global._mf_init_apply(gen, text);
    }).catch(function (e) {
      sendToNative({
        event: 'mfFetchError',
        data: { gen: gen, message: String(e && e.message ? e.message : e) }
      });
    });
  };

  global._mf_init_apply = function (gen, code) {
    sendToNative({ event: 'mfFetchAck', data: { gen: gen, length: (code || '').length } });
    if (!code) {
      sendToNative({ event: 'mfReady', data: { gen: gen, ok: false, error: 'empty payload' } });
      return;
    }
    applyPluginCode(gen, code);
  };

  /** 插件源码（原文）→ 加载并上报 mfReady。分片通道与快通道共用这一段。 */
  function applyPluginCode(gen, code) {
    try {
      plugin = loadPlugin(code);
      var methods = [];
      var keys = Object.keys(plugin);
      for (var i = 0; i < keys.length; i++) {
        if (typeof plugin[keys[i]] === 'function') {
          methods.push(keys[i]);
        }
      }
      pluginMeta = {
        platform: plugin.platform || '',
        version: plugin.version || '',
        author: plugin.author || '',
        srcUrl: plugin.srcUrl || '',
        primaryKey: plugin.primaryKey || '',
        supportedSearchType: plugin.supportedSearchType || [],
        methods: methods
      };
      log('插件就绪 platform=' + pluginMeta.platform + ' methods=' + methods.length);
      sendToNative({ event: 'mfReady', data: { gen: gen, ok: true, meta: pluginMeta } });
    } catch (e) {
      var msg = (e && e.message) ? e.message : String(e);
      log('插件加载失败: ' + msg);
      sendToNative({ event: 'mfReady', data: { gen: gen, ok: false, error: msg } });
    }
  }

  global._mf_call = function (callId, method, argsJson) {
    if (plugin === null) {
      sendToNative({ event: 'mfResult', data: { callId: callId, ok: false, error: '插件未加载' } });
      return;
    }
    var fn = plugin[method];
    if (typeof fn !== 'function') {
      sendToNative({ event: 'mfResult', data: { callId: callId, ok: false, error: '方法不存在: ' + method } });
      return;
    }
    var args;
    try {
      args = JSON.parse(argsJson || '[]');
    } catch (e) {
      sendToNative({ event: 'mfResult', data: { callId: callId, ok: false, error: '参数解析失败' } });
      return;
    }
    try {
      var ret = fn.apply(plugin, args);
      Promise.resolve(ret).then(function (result) {
        var json;
        try {
          json = JSON.stringify(result === undefined ? null : result);
        } catch (e) {
          json = 'null';
        }
        sendToNative({ event: 'mfResult', data: { callId: callId, ok: true, result: json } });
      }).catch(function (e) {
        sendToNative({
          event: 'mfResult',
          data: { callId: callId, ok: false, error: (e && e.message) ? e.message : String(e) }
        });
      });
    } catch (e) {
      sendToNative({
        event: 'mfResult',
        data: { callId: callId, ok: false, error: (e && e.message) ? e.message : String(e) }
      });
    }
  };

  global._mf_meta = function () {
    return pluginMeta;
  };

  // 少数插件会直接摸全局（不走 require），这里补上同名全局对象。
  global.CryptoJS = CryptoJS;
  global.qs = qs;
  global.dayjs = dayjs;
  global.bigInt = bigIntFactory;
  global.axios = axios;

  log('runtime 就绪');
})(window);
