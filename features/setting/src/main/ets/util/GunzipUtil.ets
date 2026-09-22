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
 * Minimal RFC1951 (deflate) inflater used to decompress gzip (.lxmc) playlists,
 * since the current SDK exposes no raw-deflate / gunzip API.
 */

/** Huffman decode table: maps (code | length<<16) to symbol. */
class HuffTable {
  public codes: Map<number, number> = new Map<number, number>();

  /** Builds a canonical huffman table from code lengths (RFC1951 3.2.2). */
  public build(lens: number[]): boolean {
    let maxLen: number = 0;
    for (let i: number = 0; i < lens.length; i++) {
      if (lens[i] > maxLen) {
        maxLen = lens[i];
      }
    }
    // count per length
    const blCount: number[] = new Array<number>(maxLen + 1).fill(0);
    for (let i: number = 0; i < lens.length; i++) {
      if (lens[i] > 0) {
        blCount[lens[i]]++;
      }
    }
    // next codes per length
    const nextCode: number[] = new Array<number>(maxLen + 1).fill(0);
    let code: number = 0;
    for (let bits: number = 1; bits <= maxLen; bits++) {
      code = (code + blCount[bits - 1]) << 1;
      nextCode[bits] = code;
    }
    for (let i: number = 0; i < lens.length; i++) {
      if (lens[i] > 0) {
        const c: number = nextCode[lens[i]];
        nextCode[lens[i]]++;
        this.codes.set(c | (lens[i] << 16), i);
      }
    }
    return true;
  }
}

/**
 * Decompresses a deflate stream (RFC1951) into raw bytes.
 */
export class DeflateReader {
  private input: Uint8Array;
  private pos: number = 0;
  private bitBuf: number = 0;
  private bitCnt: number = 0;

  /** Fixed literal/length table (RFC1951 3.2.6). */
  private static buildFixedLit(): HuffTable {
    const lens: number[] = new Array<number>(288).fill(8);
    for (let i: number = 144; i <= 255; i++) {
      lens[i] = 9;
    }
    for (let i: number = 256; i <= 279; i++) {
      lens[i] = 7;
    }
    const t = new HuffTable();
    t.build(lens);
    return t;
  }

  /** Fixed distance table: all 5-bit codes 0-31. */
  private static buildFixedDist(): HuffTable {
    const lens: number[] = new Array<number>(30).fill(5);
    const t = new HuffTable();
    t.build(lens);
    return t;
  }

  /** Length base values and extra bits for codes 257-285 (RFC1951 3.2.5). */
  private static readonly LENGTH_BASE: number[] = [
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
  ];
  private static readonly LENGTH_EXTRA: number[] = [
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
  ];
  /** Distance base values and extra bits (RFC1951 3.2.5). */
  private static readonly DIST_BASE: number[] = [
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
    8193, 12289, 16385, 24577
  ];
  private static readonly DIST_EXTRA: number[] = [
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
  ];
  /** Order of code-length code lengths (RFC1951 3.2.7). */
  private static readonly CLEN_ORDER: number[] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];

  constructor(input: Uint8Array) {
    this.input = input;
  }

  private readBits(n: number): number {
    while (this.bitCnt < n) {
      this.bitBuf |= this.input[this.pos] << this.bitCnt;
      this.pos++;
      this.bitCnt += 8;
    }
    const v: number = this.bitBuf & ((1 << n) - 1);
    this.bitBuf >>>= n;
    this.bitCnt -= n;
    return v;
  }

  private decodeSymbol(table: HuffTable): number {
    let code: number = 0;
    for (let len: number = 1; len <= 15; len++) {
      code = (code << 1) | this.readBits(1);
      const sym: number | undefined = table.codes.get(code | (len << 16));
      if (sym !== undefined) {
        return sym;
      }
    }
    return -1;
  }

  /** Decodes a stored (uncompressed) block: byte-aligned LEN/NLEN/data. */
  private decodeStored(out: number[]): void {
    // discard partial bits
    this.bitBuf = 0;
    this.bitCnt = 0;
    const len: number = this.input[this.pos] | (this.input[this.pos + 1] << 8);
    this.pos += 2;
    // NLEN skipped (2 bytes)
    this.pos += 2;
    for (let i: number = 0; i < len; i++) {
      out.push(this.input[this.pos]);
      this.pos++;
    }
  }

  /**
   * Inflates the whole deflate stream.
   * @returns Decompressed bytes.
   */
  public inflate(): Uint8Array {
    const out: number[] = [];
    let litTable: HuffTable = DeflateReader.buildFixedLit();
    let distTable: HuffTable = DeflateReader.buildFixedDist();
    let done: boolean = false;
    while (!done) {
      const bfinal: number = this.readBits(1);
      const btype: number = this.readBits(2);
      if (btype === 0) {
        this.decodeStored(out);
      } else if (btype === 1) {
        litTable = DeflateReader.buildFixedLit();
        distTable = DeflateReader.buildFixedDist();
      } else if (btype === 2) {
        const hlit: number = this.readBits(5) + 257;
        const hdist: number = this.readBits(5) + 1;
        const hclen: number = this.readBits(4) + 4;
        const clenLens: number[] = new Array<number>(19).fill(0);
        for (let i: number = 0; i < hclen; i++) {
          clenLens[DeflateReader.CLEN_ORDER[i]] = this.readBits(3);
        }
        const clenTable = new HuffTable();
        clenTable.build(clenLens);
        const litLens: number[] = new Array<number>(hlit).fill(0);
        const distLens: number[] = new Array<number>(hdist).fill(0);
        let litIdx: number = 0;
        while (litIdx < hlit + hdist) {
          const sym: number = this.decodeSymbol(clenTable);
          if (sym < 0) {
            throw new Error('bad clen symbol');
          }
          if (sym < 16) {
            if (litIdx < hlit) {
              litLens[litIdx] = sym;
            } else {
              distLens[litIdx - hlit] = sym;
            }
            litIdx++;
          } else if (sym === 16) {
            const prev: number = litIdx > 0 ?
              (litIdx <= hlit ? litLens[litIdx - 1] : distLens[litIdx - 1 - hlit]) : 0;
            const rep: number = 3 + this.readBits(2);
            for (let r: number = 0; r < rep; r++) {
              if (litIdx < hlit) {
                litLens[litIdx] = prev;
              } else {
                distLens[litIdx - hlit] = prev;
              }
              litIdx++;
            }
          } else if (sym === 17) {
            const rep: number = 3 + this.readBits(3);
            for (let r: number = 0; r < rep; r++) {
              if (litIdx < hlit) {
                litLens[litIdx] = 0;
              } else {
                distLens[litIdx - hlit] = 0;
              }
              litIdx++;
            }
          } else {
            const rep: number = 11 + this.readBits(7);
            for (let r: number = 0; r < rep; r++) {
              if (litIdx < hlit) {
                litLens[litIdx] = 0;
              } else {
                distLens[litIdx - hlit] = 0;
              }
              litIdx++;
            }
          }
        }
        litTable = new HuffTable();
        litTable.build(litLens);
        distTable = new HuffTable();
        distTable.build(distLens);
      } else {
        throw new Error('bad btype');
      }
      // decode symbols until end-of-block
      while (true) {
        const sym: number = this.decodeSymbol(litTable);
        if (sym < 0) {
          throw new Error('bad literal');
        }
        if (sym === 256) {
          break;
        }
        if (sym < 256) {
          out.push(sym);
        } else {
          const li: number = sym - 257;
          const length: number = DeflateReader.LENGTH_BASE[li] + this.readBits(DeflateReader.LENGTH_EXTRA[li]);
          const dsym: number = this.decodeSymbol(distTable);
          if (dsym < 0) {
            throw new Error('bad distance');
          }
          const dist: number = DeflateReader.DIST_BASE[dsym] + this.readBits(DeflateReader.DIST_EXTRA[dsym]);
          const start: number = out.length - dist;
          for (let c: number = 0; c < length; c++) {
            out.push(out[start + c]);
          }
        }
      }
      if (bfinal === 1) {
        done = true;
      }
    }
    return new Uint8Array(out);
  }
}

/**
 * Decompresses a gzip payload (RFC1952): validates the header, skips optional
 * fields, and inflates the deflate body.
 * @param gz Gzip-compressed bytes.
 * @returns Decompressed bytes.
 */
export function gunzipBytes(gz: Uint8Array): Uint8Array {
  if (gz.length < 18 || gz[0] !== 0x1F || gz[1] !== 0x8B || gz[2] !== 8) {
    throw new Error('not gzip');
  }
  let offset: number = 10;
  const flags: number = gz[3];
  if ((flags & 0x04) !== 0) {
    const xlen: number = gz[offset] | (gz[offset + 1] << 8);
    offset += 2 + xlen;
  }
  if ((flags & 0x08) !== 0) {
    while (gz[offset] !== 0) {
      offset++;
    }
    offset++;
  }
  if ((flags & 0x10) !== 0) {
    while (gz[offset] !== 0) {
      offset++;
    }
    offset++;
  }
  if ((flags & 0x02) !== 0) {
    offset += 2;
  }
  const deflateLen: number = gz.length - offset - 8;
  if (deflateLen <= 0) {
    throw new Error('empty deflate');
  }
  const reader = new DeflateReader(gz.subarray(offset, offset + deflateLen));
  return reader.inflate();
}
