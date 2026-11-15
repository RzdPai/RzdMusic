/*
 * Copyright (c) 2026 RzdPai
 *
 * 音频容器嗅探：**按文件头**认清真实格式，不看扩展名。
 *
 * 为什么需要它（两条独立的痛点，共用同一份判定）：
 *   ① 下载：文件名按**请求音质**起（要 flac 就叫 .flac），但回退链实际可能给的是 128k MP3
 *      ⇒ 扩展名和内容对不上，导入本地音乐时被判「格式不支持」。
 *   ② 导入：用户手上本来就有这种「名字写着 .flac、内容其实是 mp3」的文件（就是 ① 时期的产物）。
 *
 * 2026-11-15：`DownloadService` 与 `LocalMusic` 各写过一份嗅探器，**判定不一致**
 * （一份跳 ID3v2 前置标签、一份不跳；WAV 一份看 "WA"、一份看 "WAVE"），
 * 于是「带 ID3 标签的 FLAC」在下载侧被改名成 `.mp3`、在导入侧又被认回 `.flac`。
 * 现在只有这一份，两边共用。
 */

import { fileIo as fs } from '@kit.CoreFileKit';

/** 一次读够判断容器头 + ID3 标签头（10 字节）的字节数 */
const SNIFF_BYTES: number = 16;

/** 嗅探器认得的容器 → 规范扩展名（含点） */
const EXT_FLAC: string = '.flac';
const EXT_OGG: string = '.ogg';
const EXT_WAV: string = '.wav';
const EXT_M4A: string = '.m4a';
const EXT_AMR: string = '.amr';
const EXT_AAC: string = '.aac';
const EXT_MP3: string = '.mp3';

/**
 * 读文件头前 `count` 字节；读不到返回 null（不抛）。
 * @param pathOrUri 沙箱路径或 `file://` URI（`fs.openSync` 两者都收）
 * @param count 期望字节数
 * @param fileOffset 从文件哪个位置开始读，默认 0
 */
function readHead(pathOrUri: string, count: number, fileOffset: number = 0): Uint8Array | null {
  let file: fs.File | null = null;
  try {
    file = fs.openSync(pathOrUri, fs.OpenMode.READ_ONLY);
    const buf: ArrayBuffer = new ArrayBuffer(count);
    const read: number = fileOffset > 0 ?
      fs.readSync(file.fd, buf, { offset: fileOffset, length: count }) :
      fs.readSync(file.fd, buf);
    if (read < 4) {
      return null;
    }
    return new Uint8Array(buf, 0, read);
  } catch (_e) {
    return null;
  } finally {
    if (file !== null) {
      try {
        fs.closeSync(file);
      } catch (_e) {
        // 关不掉就当关好了
      }
    }
  }
}

/**
 * ID3v2 前置标签的长度（含标签头与可选 footer）；没有标签返回 0。
 *
 * MP3 几乎总有；个别 FLAC / 其它容器也会被写入 ID3v2 ⇒ 不跳过去就会把 FLAC 认成 MP3。
 * @param head 从文件 0 位置读到的前 10+ 字节
 */
function id3v2Size(head: Uint8Array): number {
  if (head.length < 10) {
    return 0;
  }
  if (!(head[0] === 0x49 && head[1] === 0x44 && head[2] === 0x33)) {
    return 0;                                                            // 不是 "ID3"
  }
  // 6~9 字节是 syncsafe 长度（每字节只用低 7 位）
  const size: number = ((head[6] & 0x7F) << 21) | ((head[7] & 0x7F) << 14) |
    ((head[8] & 0x7F) << 7) | (head[9] & 0x7F);
  const footer: number = (head[5] & 0x10) !== 0 ? 10 : 0;
  return 10 + size + footer;
}

/**
 * 按内容认出音频容器，返回规范扩展名。
 *
 * @param pathOrUri 沙箱路径或 `file://` URI
 * @param hasId3Tag 出参不可用；若需要知道"是否带 ID3 标签"，用 {@link sniffAudioContainer} 的返回对象
 * @returns `.flac` / `.ogg` / `.wav` / `.m4a` / `.amr` / `.aac` / `.mp3`；认不出返回空串
 */
export function sniffAudioContainerExt(pathOrUri: string): string {
  return sniffAudioContainer(pathOrUri).ext;
}

/** 嗅探结果 */
export class AudioContainerInfo {
  /** 规范扩展名（含点）；认不出为空串 */
  ext: string = '';
  /** 文件是否带 ID3v2 前置标签（ID3 本身不是容器，只是标签） */
  hasId3Tag: boolean = false;
  /** 用于日志的容器名（`flac` / `mp3` / `''`） */
  name: string = '';

  constructor(ext: string = '', hasId3Tag: boolean = false) {
    this.ext = ext;
    this.hasId3Tag = hasId3Tag;
    this.name = ext.length > 0 ? ext.substring(1) : '';
  }
}

/**
 * 按内容认出音频容器（详细版）。
 *
 * 判定顺序有讲究：**ADTS(AAC) 也满足 MP3 的 11 位帧同步**，所以 `.aac` 必须先判。
 * @param pathOrUri 沙箱路径或 `file://` URI
 */
export function sniffAudioContainer(pathOrUri: string): AudioContainerInfo {
  const head: Uint8Array | null = readHead(pathOrUri, SNIFF_BYTES);
  if (head === null) {
    return new AudioContainerInfo();
  }
  let b: Uint8Array = head;
  const tagSize: number = id3v2Size(head);
  if (tagSize > 0) {
    // 真正的容器头在 ID3v2 标签之后
    const next: Uint8Array | null = readHead(pathOrUri, SNIFF_BYTES, tagSize);
    if (next === null) {
      return new AudioContainerInfo();
    }
    b = next;
  }
  const hasId3: boolean = tagSize > 0;
  const b0: number = b[0];
  const b1: number = b[1];
  const b2: number = b[2];
  const b3: number = b[3];
  if (b0 === 0x66 && b1 === 0x4C && b2 === 0x61 && b3 === 0x43) {
    return new AudioContainerInfo(EXT_FLAC, hasId3);                     // fLaC
  }
  if (b0 === 0x4F && b1 === 0x67 && b2 === 0x67 && b3 === 0x53) {
    return new AudioContainerInfo(EXT_OGG, hasId3);                      // OggS
  }
  if (b0 === 0x52 && b1 === 0x49 && b2 === 0x46 && b3 === 0x46 && b.length >= 12 &&
    b[8] === 0x57 && b[9] === 0x41 && b[10] === 0x56 && b[11] === 0x45) {
    return new AudioContainerInfo(EXT_WAV, hasId3);                      // RIFF....WAVE
  }
  if (b.length >= 8 && b[4] === 0x66 && b[5] === 0x74 && b[6] === 0x79 && b[7] === 0x70) {
    return new AudioContainerInfo(EXT_M4A, hasId3);                      // box size + 'ftyp'
  }
  if (b0 === 0x23 && b1 === 0x21 && b2 === 0x41 && b3 === 0x4D) {
    return new AudioContainerInfo(EXT_AMR, hasId3);                      // #!AMR
  }
  if (b0 === 0xFF && (b1 & 0xF6) === 0xF0) {
    return new AudioContainerInfo(EXT_AAC, hasId3);                      // ADTS：sync 1111 + layer 00
  }
  if (b0 === 0xFF && (b1 & 0xE0) === 0xE0) {
    return new AudioContainerInfo(EXT_MP3, hasId3);                      // MPEG 帧同步
  }
  // 只剩"带 ID3 标签、但标签后认不出容器"这一种：仍按 MP3 处理（ID3 几乎只出现在 MP3 上）
  if (hasId3) {
    return new AudioContainerInfo(EXT_MP3, true);
  }
  return new AudioContainerInfo();
}
