/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * QRC（QQ 音乐加密歌词）解密器。
 *
 * 对应原仓库 packages/lyric/src/formats/eqrc/ 下的 constants.ts / custom-des.ts / utils.ts / index.ts。
 * 非标准 3DES 算法 + zlib 解压（自实现 inflate）。
 */
import { util } from '@kit.ArkTS';
import { amllZlibInflate } from './AmllInflate';

const DES_BLOCK_SIZE = 8;

// 解密使用的 3 个 8 字节 DES 密钥
const KEY_1: Uint8Array = new util.TextEncoder().encodeInto("!@#)(*$%");
const KEY_2: Uint8Array = new util.TextEncoder().encodeInto("123ZXC!@");
const KEY_3: Uint8Array = new util.TextEncoder().encodeInto("!@#)(NHL");

// --- QQ 音乐使用的非标准 S 盒定义 ---
const SBOX1: number[] = [
  14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7, 0, 15, 7, 4, 14, 2, 13,
  1, 10, 6, 12, 11, 9, 5, 3, 8, 4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10,
  5, 0, 15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13
];
const SBOX2: number[] = [
  15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10, 3, 13, 4, 7, 15, 2, 8,
  15, 12, 0, 1, 10, 6, 9, 11, 5, 0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3,
  2, 15, 13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9
];
const SBOX3: number[] = [
  10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8, 13, 7, 0, 9, 3, 4, 6,
  10, 2, 8, 5, 14, 12, 11, 15, 1, 13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10,
  14, 7, 1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12
];
const SBOX4: number[] = [
  7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15, 13, 8, 11, 5, 6, 15, 0,
  3, 4, 7, 2, 12, 1, 10, 14, 9, 10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2,
  8, 4, 3, 15, 0, 6, 10, 10, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14
];
const SBOX5: number[] = [
  2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9, 14, 11, 2, 12, 4, 7, 13,
  1, 5, 0, 15, 10, 3, 9, 8, 6, 4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0,
  14, 11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3
];
const SBOX6: number[] = [
  12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11, 10, 15, 4, 2, 7, 12, 9,
  5, 6, 1, 13, 14, 0, 11, 3, 8, 9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13,
  11, 6, 4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13
];
const SBOX7: number[] = [
  4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1, 13, 0, 11, 7, 4, 9, 1,
  10, 14, 3, 5, 12, 2, 15, 8, 6, 1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5,
  9, 2, 6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12
];
const SBOX8: number[] = [
  13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7, 1, 15, 13, 8, 10, 3, 7,
  4, 12, 5, 6, 11, 0, 14, 9, 2, 7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3,
  5, 8, 2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11
];

const S_BOXES: number[][] = [SBOX1, SBOX2, SBOX3, SBOX4, SBOX5, SBOX6, SBOX7, SBOX8];

// QQ 音乐使用的标准 P 盒置换规则
const P_BOX: number[] = [
  16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26, 5, 18, 31, 10, 2, 8, 24, 14, 32,
  27, 3, 9, 19, 13, 30, 6, 22, 11, 4, 25
];

// QQ 音乐使用的标准扩展置换表
const E_BOX_TABLE: number[] = [
  32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9, 8, 9, 10, 11, 12, 13, 12, 13, 14, 15, 16,
  17, 16, 17, 18, 19, 20, 21, 20, 21, 22, 23, 24, 25, 24, 25, 26, 27, 28, 29,
  28, 29, 30, 31, 32, 1
];

// 每轮循环左移的位数表
const KEY_RND_SHIFT: number[] = [
  1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1
];

// 置换选择1 (PC-1) - C 部分
const KEY_PERM_C: number[] = [
  56, 48, 40, 32, 24, 16, 8, 0, 57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34,
  26, 18, 10, 2, 59, 51, 43, 35
];

// 置换选择1 (PC-1) - D 部分
const KEY_PERM_D: number[] = [
  62, 54, 46, 38, 30, 22, 14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 60, 52, 44, 36,
  28, 20, 12, 4, 27, 19, 11, 3
];

// 置换选择2 (PC-2)
const KEY_COMPRESSION: number[] = [
  13, 16, 10, 23, 0, 4, 2, 27, 14, 5, 20, 9, 22, 18, 11, 3, 25, 7, 15, 6, 26,
  19, 12, 1, 40, 51, 30, 36, 46, 54, 29, 39, 50, 44, 32, 47, 43, 48, 38, 55, 33,
  52, 45, 41, 49, 35, 28, 31
];

/**
 * 从 8 字节密钥中根据置换表提取位，生成一个 BigInt。
 * 模拟 QQ 音乐特有的非标准字节序处理方式（对应原仓库 permuteFromKeyBytes）
 */
function permuteFromKeyBytes(key: Uint8Array, table: number[]): bigint {
  let output = 0n;
  let currentBitMask = 1n << BigInt(table.length - 1);
  for (let i = 0; i < table.length; i++) {
    const pos = table[i];
    const wordIndex = pos >> 5;
    const bitInWord = pos & 31;
    const byteInWord = bitInWord >> 3;
    const bitInByte = bitInWord & 7;
    const byteIndex = wordIndex * 4 + 3 - byteInWord;
    const bit = (key[byteIndex] >> (7 - bitInByte)) & 1;
    if (bit === 1) {
      output |= currentBitMask;
    }
    currentBitMask >>= 1n;
  }
  return output;
}

/** 对一个 28 位密钥部分进行循环左移 */
function rotateLeft28Bit(value: bigint, amount: number): bigint {
  const BITS_28_MASK = 0xfffffff0n;
  const val = value & BITS_28_MASK;
  const shifted = (val << BigInt(amount)) | (val >> BigInt(28 - amount));
  return shifted & BITS_28_MASK;
}

enum QrcMode {
  Encrypt,
  Decrypt
}

/**
 * DES 密钥调度算法，生成 16 个 48 位的轮密钥
 */
function keySchedule(key: Uint8Array, mode: QrcMode): Int32Array {
  const schedule = new Int32Array(32);
  const c0 = permuteFromKeyBytes(key, KEY_PERM_C);
  const d0 = permuteFromKeyBytes(key, KEY_PERM_D);
  let c = c0 << 4n;
  let d = d0 << 4n;

  for (let i = 0; i < 16; i++) {
    const shift = KEY_RND_SHIFT[i];
    c = rotateLeft28Bit(c, shift);
    d = rotateLeft28Bit(d, shift);
    const toGen = mode === QrcMode.Decrypt ? 15 - i : i;

    let subkey48bit = 0n;
    for (let k = 0; k < KEY_COMPRESSION.length; k++) {
      const pos = KEY_COMPRESSION[k];
      const bitBigInt: bigint =
        pos < 28
          ? (c >> BigInt(31 - pos)) & 1n
          : (d >> BigInt(31 - (pos - 27))) & 1n;
      if (bitBigInt === 1n) {
        subkey48bit |= 1n << BigInt(47 - k);
      }
    }

    const b5 = Number((subkey48bit >> 40n) & 0xffn);
    const b4 = Number((subkey48bit >> 32n) & 0xffn);
    const b3 = Number((subkey48bit >> 24n) & 0xffn);
    const high24 = (b5 << 16) | (b4 << 8) | b3;

    const b2 = Number((subkey48bit >> 16n) & 0xffn);
    const b1 = Number((subkey48bit >> 8n) & 0xffn);
    const b0 = Number(subkey48bit & 0xffn);
    const low24 = (b2 << 16) | (b1 << 8) | b0;

    schedule[toGen * 2] = high24;
    schedule[toGen * 2 + 1] = low24;
  }
  return schedule;
}

// 初始置换规则
const IP_RULE: number[] = [
  34, 42, 50, 58, 2, 10, 18, 26, 36, 44, 52, 60, 4, 12, 20, 28, 38, 46, 54, 62,
  6, 14, 22, 30, 40, 48, 56, 64, 8, 16, 24, 32, 33, 41, 49, 57, 1, 9, 17, 25,
  35, 43, 51, 59, 3, 11, 19, 27, 37, 45, 53, 61, 5, 13, 21, 29, 39, 47, 55, 63,
  7, 15, 23, 31
];

// 逆初始置换规则
const INV_IP_RULE: number[] = [
  37, 5, 45, 13, 53, 21, 61, 29, 38, 6, 46, 14, 54, 22, 62, 30, 39, 7, 47, 15,
  55, 23, 63, 31, 40, 8, 48, 16, 56, 24, 64, 32, 33, 1, 41, 9, 49, 17, 57, 25,
  34, 2, 42, 10, 50, 18, 58, 26, 35, 3, 43, 11, 51, 19, 59, 27, 36, 4, 44, 12,
  52, 20, 60, 28
];

const IP_LEFT_TABLE = new Int32Array(2048);
const IP_RIGHT_TABLE = new Int32Array(2048);
const INV_IP_LEFT_TABLE = new Int32Array(2048);
const INV_IP_RIGHT_TABLE = new Int32Array(2048);

function applyPermutation(input: bigint, rule: number[]): bigint {
  let output = 0n;
  for (let i = 0; i < 64; i++) {
    const srcBit1Based = rule[i];
    if (((input >> BigInt(64 - srcBit1Based)) & 1n) === 1n) {
      output |= 1n << BigInt(63 - i);
    }
  }
  return output;
}

function generatePermutationTables(): void {
  for (let bytePos = 0; bytePos < 8; bytePos++) {
    for (let byteVal = 0; byteVal < 256; byteVal++) {
      const input = BigInt(byteVal) << BigInt(56 - bytePos * 8);
      const permuted = applyPermutation(input, IP_RULE);
      const idx = (bytePos << 8) | byteVal;
      IP_LEFT_TABLE[idx] = Number((permuted >> 32n) & 0xffffffffn);
      IP_RIGHT_TABLE[idx] = Number(permuted & 0xffffffffn);
    }
  }
  for (let blockPos = 0; blockPos < 8; blockPos++) {
    for (let blockVal = 0; blockVal < 256; blockVal++) {
      const input = BigInt(blockVal) << BigInt(56 - blockPos * 8);
      const permuted = applyPermutation(input, INV_IP_RULE);
      const idx = (blockPos << 8) | blockVal;
      INV_IP_LEFT_TABLE[idx] = Number((permuted >> 32n) & 0xffffffffn);
      INV_IP_RIGHT_TABLE[idx] = Number(permuted & 0xffffffffn);
    }
  }
}
generatePermutationTables();

/** 计算 DES S-盒的查找索引 */
function calculateSboxIndex(a: number): number {
  return (a & 0x20) | ((a & 0x1f) >> 1) | ((a & 0x01) << 4);
}

/** 对一个 32 位整数应用非标准的 P 盒置换规则 */
function applyQqPboxPermutation(input: number): number {
  let output = 0;
  for (let i = 0; i < 32; i++) {
    const sourceBit1Based = P_BOX[i];
    const destBitMask = 1 << (31 - i);
    const sourceBitMask = 1 << (32 - sourceBit1Based);
    if ((input & sourceBitMask) !== 0) {
      output |= destBitMask;
    }
  }
  return output;
}

const SP_TABLE = new Int32Array(512);

function generateSpTables(): void {
  for (let sBoxIdx = 0; sBoxIdx < 8; sBoxIdx++) {
    for (let sBoxInput = 0; sBoxInput < 64; sBoxInput++) {
      const sBoxIndex = calculateSboxIndex(sBoxInput);
      const fourBitOutput = S_BOXES[sBoxIdx][sBoxIndex];
      const prePBoxVal = fourBitOutput << (28 - sBoxIdx * 4);
      SP_TABLE[(sBoxIdx << 6) | sBoxInput] = applyQqPboxPermutation(prePBoxVal);
    }
  }
}
generateSpTables();

const EBOX_HIGH_TABLE = new Int32Array(1024);
const EBOX_LOW_TABLE = new Int32Array(1024);

function generateEBoxTables(): void {
  for (let chunkIdx = 0; chunkIdx < 4; chunkIdx++) {
    const shiftIn32 = (3 - chunkIdx) * 8;
    for (let byteVal = 0; byteVal < 256; byteVal++) {
      let high24 = 0;
      let low24 = 0;
      const input = byteVal << shiftIn32;
      for (let i = 0; i < 24; i++) {
        const sourceBitPos = E_BOX_TABLE[i];
        const bit = (input >>> (32 - sourceBitPos)) & 1;
        if (bit === 1) {
          high24 |= 1 << (23 - i);
        }
      }
      for (let i = 24; i < 48; i++) {
        const sourceBitPos = E_BOX_TABLE[i];
        const bit = (input >>> (32 - sourceBitPos)) & 1;
        if (bit === 1) {
          low24 |= 1 << (47 - i);
        }
      }
      const tableIdx = (chunkIdx << 8) | byteVal;
      EBOX_HIGH_TABLE[tableIdx] = high24;
      EBOX_LOW_TABLE[tableIdx] = low24;
    }
  }
}
generateEBoxTables();

/** DES 的 F 函数 */
function fFunction(state: number, keyHigh24: number, keyLow24: number): number {
  const b0 = (state >>> 24) & 0xff;
  const b1 = (state >>> 16) & 0xff;
  const b2 = (state >>> 8) & 0xff;
  const b3 = state & 0xff;

  const eboxHigh24 =
    EBOX_HIGH_TABLE[b0] |
    EBOX_HIGH_TABLE[256 | b1] |
    EBOX_HIGH_TABLE[512 | b2] |
    EBOX_HIGH_TABLE[768 | b3];
  const eboxLow24 =
    EBOX_LOW_TABLE[b0] |
    EBOX_LOW_TABLE[256 | b1] |
    EBOX_LOW_TABLE[512 | b2] |
    EBOX_LOW_TABLE[768 | b3];

  const xorHigh24 = eboxHigh24 ^ keyHigh24;
  const xorLow24 = eboxLow24 ^ keyLow24;

  return (
    SP_TABLE[(xorHigh24 >>> 18) & 0x3f] |
    SP_TABLE[64 | ((xorHigh24 >>> 12) & 0x3f)] |
    SP_TABLE[128 | ((xorHigh24 >>> 6) & 0x3f)] |
    SP_TABLE[192 | (xorHigh24 & 0x3f)] |
    SP_TABLE[256 | ((xorLow24 >>> 18) & 0x3f)] |
    SP_TABLE[320 | ((xorLow24 >>> 12) & 0x3f)] |
    SP_TABLE[384 | ((xorLow24 >>> 6) & 0x3f)] |
    SP_TABLE[448 | (xorLow24 & 0x3f)]
  );
}

/** DES 加密/解密单个 64 位数据块 */
function desCrypt(
  input: Uint8Array,
  output: Uint8Array,
  schedule: Int32Array
): void {
  let left = 0;
  let right = 0;
  for (let i = 0; i < 8; i++) {
    const idx = (i << 8) | input[i];
    left |= IP_LEFT_TABLE[idx];
    right |= IP_RIGHT_TABLE[idx];
  }

  for (let i = 0; i < 15; i++) {
    const temp = right;
    right = (left ^ fFunction(right, schedule[i * 2], schedule[i * 2 + 1])) >>> 0;
    left = temp;
  }
  left = (left ^ fFunction(right, schedule[30], schedule[31])) >>> 0;

  let outLeft = 0;
  let outRight = 0;
  for (let i = 0; i < 4; i++) {
    const idxL = (i << 8) | ((left >>> (24 - i * 8)) & 0xff);
    outLeft |= INV_IP_LEFT_TABLE[idxL];
    outRight |= INV_IP_RIGHT_TABLE[idxL];

    const idxR = ((i + 4) << 8) | ((right >>> (24 - i * 8)) & 0xff);
    outLeft |= INV_IP_LEFT_TABLE[idxR];
    outRight |= INV_IP_RIGHT_TABLE[idxR];
  }

  output[0] = (outLeft >>> 24) & 0xff;
  output[1] = (outLeft >>> 16) & 0xff;
  output[2] = (outLeft >>> 8) & 0xff;
  output[3] = outLeft & 0xff;
  output[4] = (outRight >>> 24) & 0xff;
  output[5] = (outRight >>> 16) & 0xff;
  output[6] = (outRight >>> 8) & 0xff;
  output[7] = outRight & 0xff;
}

/** 非标准 3DES 编解码器 */
class QqMusicCodec {
  private readonly encryptSchedule: Int32Array[];
  private readonly decryptSchedule: Int32Array[];

  constructor() {
    // 解密流程 D(K3) -> E(K2) -> D(K1)
    this.decryptSchedule = [
      keySchedule(KEY_3, QrcMode.Decrypt),
      keySchedule(KEY_2, QrcMode.Encrypt),
      keySchedule(KEY_1, QrcMode.Decrypt)
    ];
    // 加密流程 E(K1) -> D(K2) -> E(K3)
    this.encryptSchedule = [
      keySchedule(KEY_1, QrcMode.Encrypt),
      keySchedule(KEY_2, QrcMode.Decrypt),
      keySchedule(KEY_3, QrcMode.Encrypt)
    ];
  }

  public decryptBlock(input: Uint8Array, output: Uint8Array): void {
    const temp1 = new Uint8Array(8);
    const temp2 = new Uint8Array(8);
    desCrypt(input, temp1, this.decryptSchedule[0]);
    desCrypt(temp1, temp2, this.decryptSchedule[1]);
    desCrypt(temp2, output, this.decryptSchedule[2]);
  }

  public encryptBlock(input: Uint8Array, output: Uint8Array): void {
    const temp1 = new Uint8Array(8);
    const temp2 = new Uint8Array(8);
    desCrypt(input, temp1, this.encryptSchedule[0]);
    desCrypt(temp1, temp2, this.encryptSchedule[1]);
    desCrypt(temp2, output, this.encryptSchedule[2]);
  }
}

const CODEC = new QqMusicCodec();
/** 使用 Zlib 解压缩字节数据，同时移除头部的 UTF-8 BOM */
function decompress(data: Uint8Array): Uint8Array {
  const decompressed = amllZlibInflate(data);
  if (
    decompressed.length >= 3 &&
    decompressed[0] === 0xef &&
    decompressed[1] === 0xbb &&
    decompressed[2] === 0xbf
  ) {
    return decompressed.slice(3);
  }
  return decompressed;
}

/** 将十六进制字符串转换为 Uint8Array */
export function amllHexToUint8Array(hex: string): Uint8Array {
  if (hex.length % 2 !== 0) {
    throw new Error('无效的十六进制字符串: 长度必须是偶数');
  }
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = Number.parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}
/**
 * 解密十六进制字符串格式的 QRC 歌词数据
 * 解密后可去头尾 XML 数据后通过 parseQrc 解析歌词行
 */
export function amllDecryptQrcHex(encryptedHexString: string): string {
  const encryptedBytes = amllHexToUint8Array(encryptedHexString);
  if (encryptedBytes.length % DES_BLOCK_SIZE !== 0) {
    throw new Error(`加密数据长度不是${DES_BLOCK_SIZE}的倍数`);
  }
  const decryptedData = new Uint8Array(encryptedBytes.length);
  for (let i = 0; i < encryptedBytes.length; i += DES_BLOCK_SIZE) {
    const chunk = encryptedBytes.subarray(i, i + DES_BLOCK_SIZE);
    const outChunk = decryptedData.subarray(i, i + DES_BLOCK_SIZE);
    CODEC.decryptBlock(chunk, outChunk);
  }
  const decompressedBytes = decompress(decryptedData);
  return new util.TextDecoder('utf-8').decodeToString(decompressedBytes);
}


