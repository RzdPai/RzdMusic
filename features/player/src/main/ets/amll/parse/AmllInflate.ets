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
 * 纯 ArkTS 实现的 Zlib Inflate/Deflate（RFC 1950/1951）。
 *
 * 用于替代 pako 以解密 QQ 音乐 QRC 歌词。
 * - inflate 支持 stored / fixed / dynamic 三种块类型
 * - deflate 仅输出 stored 块（合法且可被标准 inflate 解压）
 */

/** 位读取器（LSB first） */
class BitReader {
  private data: Uint8Array;
  bytePos: number = 0;
  private bitPos: number = 0;

  constructor(data: Uint8Array) {
    this.data = data;
  }

  readBits(count: number): number {
    let result = 0;
    for (let i = 0; i < count; i++) {
      const byte: number =
        this.bytePos < this.data.length ? this.data[this.bytePos] : 0;
      result |= ((byte >> this.bitPos) & 1) << i;
      this.bitPos++;
      if (this.bitPos === 8) {
        this.bitPos = 0;
        this.bytePos++;
      }
    }
    return result;
  }

  alignToByte(): void {
    if (this.bitPos !== 0) {
      this.bitPos = 0;
      this.bytePos++;
    }
  }

  readUint16LE(): number {
    const b0: number =
      this.bytePos < this.data.length ? this.data[this.bytePos] : 0;
    const b1: number =
      this.bytePos + 1 < this.data.length ? this.data[this.bytePos + 1] : 0;
    this.bytePos += 2;
    return b0 | (b1 << 8);
  }

  atEnd(): boolean {
    return this.bytePos >= this.data.length;
  }
}

/** 可增长输出缓冲区 */
class ByteSink {
  private buffer: Uint8Array = new Uint8Array(1024);
  private length: number = 0;

  ensure(capacity: number): void {
    if (this.buffer.length >= capacity) {
      return;
    }
    let newSize = this.buffer.length * 2;
    while (newSize < capacity) {
      newSize *= 2;
    }
    const newBuffer = new Uint8Array(newSize);
    newBuffer.set(this.buffer.subarray(0, this.length));
    this.buffer = newBuffer;
  }

  push(byte: number): void {
    this.ensure(this.length + 1);
    this.buffer[this.length] = byte;
    this.length++;
  }

  pushBytes(bytes: Uint8Array): void {
    this.ensure(this.length + bytes.length);
    for (let i = 0; i < bytes.length; i++) {
      this.buffer[this.length + i] = bytes[i];
    }
    this.length += bytes.length;
  }

  backCopy(dist: number, len: number): void {
    if (dist === 0 || dist > this.length) {
      return;
    }
    this.ensure(this.length + len);
    let src = this.length - dist;
    for (let i = 0; i < len; i++) {
      this.buffer[this.length] = this.buffer[src];
      this.length++;
      src++;
    }
  }

  toBytes(): Uint8Array {
    const result = new Uint8Array(this.length);
    result.set(this.buffer.subarray(0, this.length));
    return result;
  }
}

/** 长度符号表 */
const LENGTH_BASE: number[] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
  35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
];
const LENGTH_EXTRA: number[] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
  3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
];

/** 距离符号表 */
const DIST_BASE: number[] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
  257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577
];
const DIST_EXTRA: number[] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
  7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
];

/** 标准 Huffman 解码表（canonical，puff.c 算法） */
class HuffTable {
  private symbols: number[] = [];
  private counts: number[] = [];
  private maxBits: number = 0;

  build(lengths: number[]): void {
    this.symbols = [];
    this.maxBits = 0;
    for (let i = 0; i < lengths.length; i++) {
      if (lengths[i] > this.maxBits) {
        this.maxBits = lengths[i];
      }
    }
    this.counts = new Array<number>(this.maxBits + 1).fill(0);
    for (let i = 0; i < lengths.length; i++) {
      if (lengths[i] > 0) {
        this.counts[lengths[i]]++;
      }
    }
    // 生成每个长度的第一个符号对应的起始序号
    let offs: number[] = new Array<number>(this.maxBits + 1).fill(0);
    for (let bits = 1; bits < this.maxBits; bits++) {
      offs[bits + 1] = offs[bits] + this.counts[bits];
    }
    // 按 (长度, 符号) 排序填充 symbols 数组
    this.symbols = new Array<number>(lengths.length).fill(0);
    for (let i = 0; i < lengths.length; i++) {
      if (lengths[i] > 0) {
        this.symbols[offs[lengths[i]]] = i;
        offs[lengths[i]]++;
      }
    }
  }

  /** 从位读取器解码一个符号；返回 -1 表示非法 */
  decode(reader: BitReader): number {
    let code = 0;
    let first = 0;
    let index = 0;
    for (let len = 1; len <= this.maxBits; len++) {
      code |= reader.readBits(1);
      const count: number = this.counts[len];
      if (code - count < first) {
        return this.symbols[index + (code - first)];
      }
      index += count;
      first += count;
      first <<= 1;
      code <<= 1;
    }
    return -1;
  }
}

// 固定 Huffman 表
function buildFixedLiteralTable(): HuffTable {
  const lengths: number[] = new Array<number>(288).fill(8);
  for (let i = 144; i < 256; i++) {
    lengths[i] = 9;
  }
  for (let i = 256; i < 280; i++) {
    lengths[i] = 7;
  }
  const table = new HuffTable();
  table.build(lengths);
  return table;
}

function buildFixedDistTable(): HuffTable {
  const lengths: number[] = new Array<number>(30).fill(5);
  const table = new HuffTable();
  table.build(lengths);
  return table;
}

const FIXED_LITERAL_TABLE: HuffTable = buildFixedLiteralTable();
const FIXED_DIST_TABLE: HuffTable = buildFixedDistTable();

/** 解析一个 deflate 块内的符号流 */
function inflateBlock(
  reader: BitReader,
  sink: ByteSink,
  litTable: HuffTable,
  distTable: HuffTable
): boolean {
  while (true) {
    const symbol: number = litTable.decode(reader);
    if (symbol < 0) {
      return false;
    }
    if (symbol < 256) {
      sink.push(symbol);
    } else if (symbol === 256) {
      return true;
    } else {
      const lengthIndex = symbol - 257;
      if (lengthIndex < 0 || lengthIndex >= LENGTH_BASE.length) {
        return false;
      }
      let length: number = LENGTH_BASE[lengthIndex];
      const extraLen = LENGTH_EXTRA[lengthIndex];
      if (extraLen > 0) {
        length += reader.readBits(extraLen);
      }
      const distSymbol: number = distTable.decode(reader);
      if (distSymbol < 0 || distSymbol >= DIST_BASE.length) {
        return false;
      }
      let dist: number = DIST_BASE[distSymbol];
      const extraDist = DIST_EXTRA[distSymbol];
      if (extraDist > 0) {
        dist += reader.readBits(extraDist);
      }
      sink.backCopy(dist, length);
    }
  }
}

/** 解析 dynamic Huffman 块头并构建解码表 */
function inflateDynamicBlock(reader: BitReader, sink: ByteSink): boolean {
  const hlit: number = reader.readBits(5) + 257;
  const hdist: number = reader.readBits(5) + 1;
  const hclen: number = reader.readBits(4) + 4;

  const order: number[] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];
  const codeLengthLengths: number[] = new Array<number>(19).fill(0);
  for (let i = 0; i < hclen; i++) {
    codeLengthLengths[order[i]] = reader.readBits(3);
  }
  const codeLengthTable = new HuffTable();
  codeLengthTable.build(codeLengthLengths);

  const allLengths: number[] = [];
  while (allLengths.length < hlit + hdist) {
    const sym: number = codeLengthTable.decode(reader);
    if (sym < 0) {
      return false;
    }
    if (sym < 16) {
      allLengths.push(sym);
    } else if (sym === 16) {
      const repeat: number = reader.readBits(2) + 3;
      const prev: number = allLengths.length > 0 ? allLengths[allLengths.length - 1] : 0;
      for (let i = 0; i < repeat; i++) {
        allLengths.push(prev);
      }
    } else if (sym === 17) {
      const repeat: number = reader.readBits(3) + 3;
      for (let i = 0; i < repeat; i++) {
        allLengths.push(0);
      }
    } else {
      const repeat: number = reader.readBits(7) + 11;
      for (let i = 0; i < repeat; i++) {
        allLengths.push(0);
      }
    }
  }
  if (allLengths.length < hlit + hdist) {
    return false;
  }
  const litLengths: number[] = allLengths.slice(0, hlit);
  const distLengths: number[] = allLengths.slice(hlit, hlit + hdist);
  const litTable = new HuffTable();
  litTable.build(litLengths);
  const distTable = new HuffTable();
  distTable.build(distLengths);
  return inflateBlock(reader, sink, litTable, distTable);
}

/**
 * 解压 zlib 格式的数据（RFC 1950 + 1951）
 */
export function amllZlibInflate(data: Uint8Array): Uint8Array {
  if (data.length < 2) {
    throw new Error('Zlib inflate: 数据过短');
  }
  const cmf: number = data[0];
  const flg: number = data[1];
  const cm: number = cmf & 0x0f;
  if (cm !== 8) {
    throw new Error('Zlib inflate: 不支持的压缩方法');
  }
  // 检查 FCHECK
  if ((cmf * 256 + flg) % 31 !== 0) {
    throw new Error('Zlib inflate: FCHECK 校验失败');
  }
  const fdict: number = (flg >> 5) & 1;
  let startPos: number = 2;
  if (fdict === 1) {
    startPos += 4; // 跳过 DICTID
  }

  const reader = new BitReader(data.subarray(startPos));
  const sink = new ByteSink();

  let final = false;
  while (!final) {
    final = reader.readBits(1) === 1;
    const btype: number = reader.readBits(2);
    if (btype === 0) {
      // stored
      reader.alignToByte();
      const len: number = reader.readUint16LE();
      reader.readUint16LE(); // NLEN
      const chunk = data.subarray(startPos + reader.bytePos);
      if (len > 0) {
        if (chunk.length < len) {
          throw new Error('Zlib inflate: stored 块数据不足');
        }
        sink.pushBytes(chunk.subarray(0, len));
        reader.bytePos += len;
      }
    } else if (btype === 1) {
      if (!inflateBlock(reader, sink, FIXED_LITERAL_TABLE, FIXED_DIST_TABLE)) {
        throw new Error('Zlib inflate: fixed 块解码失败');
      }
    } else if (btype === 2) {
      if (!inflateDynamicBlock(reader, sink)) {
        throw new Error('Zlib inflate: dynamic 块解码失败');
      }
    } else {
      throw new Error('Zlib inflate: 非法块类型');
    }
  }
  return sink.toBytes();
}

/** 计算 Adler-32 校验和 */
function adler32(data: Uint8Array): number {
  let a = 1;
  let b = 0;
  for (let i = 0; i < data.length; i++) {
    a = (a + data[i]) % 65521;
    b = (b + a) % 65521;
  }
  return (b << 16) | a;
}

/**
 * 使用 stored 块生成合法的 zlib 压缩数据（RFC 1950 + 1951）
 */
export function amllZlibDeflate(data: Uint8Array): Uint8Array {
  const header: number[] = [0x78, 0x01];
  const out: number[] = [];
  for (let i = 0; i < header.length; i++) {
    out.push(header[i]);
  }

  let pos = 0;
  let last = false;
  while (!last) {
    const remaining: number = data.length - pos;
    const len: number = remaining > 65535 ? 65535 : remaining;
    last = pos + len >= data.length;
    // BFINAL(1) + BTYPE=00(2) + 对齐
    out.push(last ? 1 : 0);
    const bitPos = (out.length * 8) % 8;
    if (bitPos !== 0) {
      out.push(0); // 对齐字节
    }
    const lenLow: number = len & 0xff;
    const lenHigh: number = (len >> 8) & 0xff;
    const nlen: number = (~len) & 0xffff;
    out.push(lenLow);
    out.push(lenHigh);
    out.push(nlen & 0xff);
    out.push((nlen >> 8) & 0xff);
    for (let i = 0; i < len; i++) {
      out.push(data[pos + i]);
    }
    pos += len;
  }

  const checksum: number = adler32(data);
  out.push((checksum >> 24) & 0xff);
  out.push((checksum >> 16) & 0xff);
  out.push((checksum >> 8) & 0xff);
  out.push(checksum & 0xff);

  const result = new Uint8Array(out.length);
  for (let i = 0; i < out.length; i++) {
    result[i] = out[i];
  }
  return result;
}
