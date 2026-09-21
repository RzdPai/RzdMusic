/**
 * 对应 listen 的 entry/src/main/ets/core/sync/SyncGzip.ets
 *
 * 适配改动：
 *   - 中转目录：listen 由 SyncManager 在启动时把 `context.cacheDir` 传给 initGzip()；RzdMusic 里
 *     保留 initGzip()（可选）作为覆盖入口，同时默认从 `getAppRuntime().context.cacheDir` 取沙箱缓存目录，
 *     因此在没有显式初始化时也能工作。
 *   - 日志：listen 的 hilog 换成 musicbasic 的 appendError（压缩失败时不再阻断通信）。
 *   - 其余（`cg_` 前缀、>1024 才压缩、gzopen/gzread/gzwrite 文件形态中转、Uint8Array+Base64Helper
 *     的字节处理）与 listen 逐行一致。
 *
 * 同步消息的压缩层
 *
 * 洛雪在消息长度 > 1024 时用 gzip 压缩，再以 base64 传输，并在前面加 `cg_` 前缀：
 *   发送：msg.length > 1024 ? 'cg_' + gzip(msg) : msg
 *   接收：以 'cg_' 开头就 gunzip，否则原样
 * 歌单数据几乎必然超过 1024，所以这里必须有 gzip 能力。
 *
 * HarmonyOS 的 zlib 只提供文件形态的 GZip 接口（gzopen/gzread/gzwrite），
 * 没有内存版，所以这里用一个应用缓存目录下的临时文件做中转。
 *
 * 字节处理一律用 Uint8Array + util.Base64Helper / TextEncoder：
 * 逐字节 push 进 number[] 再手写 base64 的写法在几百 KB 的歌单上要跑好几秒，
 * 会把 JS 线程卡住 —— 心跳 ping 迟迟处理不到，就会被判成断线。
 */

import { fileIo as fs } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { appendError, getAppRuntime } from 'musicbasic';

const TAG: string = 'SyncGzip';

/** 中转目录（空串表示还没定，第一次用到时按沙箱 cacheDir 兜底） */
let tmpDir: string = '';
let seq: number = 0;

const ENCODER = new util.TextEncoder();
const DECODER = util.TextDecoder.create('utf-8');
const BASE64 = new util.Base64Helper();

/** 显式指定中转目录（可选；不调用时用 getAppRuntime().context.cacheDir） */
export function initGzip(dir: string): void {
  tmpDir = dir;
}

function resolveTmpDir(): string {
  if (tmpDir.length > 0) {
    return tmpDir;
  }
  const ctx: common.UIAbilityContext | undefined = getAppRuntime().context;
  if (ctx === undefined) {
    throw new Error('SyncGzip 未初始化：initGzip(cacheDir) 未调用，且 getAppRuntime().context 为空');
  }
  tmpDir = ctx.cacheDir;
  return tmpDir;
}

function ensureReady(): void {
  resolveTmpDir();
}

/** 取一段字节自己的 buffer（去掉可能存在的偏移和多余尾巴） */
function exactBuffer(u8: Uint8Array): ArrayBuffer {
  return u8.buffer.slice(u8.byteOffset, u8.byteOffset + u8.byteLength) as ArrayBuffer;
}

function writeU8(path: string, u8: Uint8Array): void {
  const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    fs.writeSync(file.fd, exactBuffer(u8));
  } finally {
    fs.closeSync(file);
  }
}

function readU8(path: string): Uint8Array {
  const stat: fs.Stat = fs.statSync(path);
  const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
  try {
    const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
    const read: number = fs.readSync(file.fd, buffer);
    return new Uint8Array(buffer, 0, read);
  } finally {
    fs.closeSync(file);
  }
}

function removeQuietly(path: string): void {
  try {
    if (fs.accessSync(path)) {
      fs.unlinkSync(path);
    }
  } catch (e) {
    // 清理失败无所谓，缓存目录会被系统回收
  }
}

function nextPath(ext: string): string {
  seq++;
  return `${resolveTmpDir()}/lx_sync_${seq}${ext}`;
}

/** 文本 -> gzip -> base64（不含 'cg_' 前缀） */
export async function gzipToBase64(text: string): Promise<string> {
  ensureReady();
  const outPath: string = nextPath('.gz');
  const u8: Uint8Array = ENCODER.encodeInto(text);
  const gz: zlib.GZip = zlib.createGZipSync();
  await gz.gzopen(outPath, 'wb');
  try {
    await gz.gzwrite(exactBuffer(u8), u8.byteLength);
  } finally {
    await gz.gzclosew();
  }
  try {
    return BASE64.encodeToStringSync(readU8(outPath));
  } finally {
    removeQuietly(outPath);
  }
}

/** base64(gzip) -> 文本 */
export async function gunzipFromBase64(b64: string): Promise<string> {
  ensureReady();
  const inPath: string = nextPath('.gz');
  writeU8(inPath, BASE64.decodeSync(b64));
  const gz: zlib.GZip = zlib.createGZipSync();
  await gz.gzopen(inPath, 'rb');
  const chunks: Uint8Array[] = [];
  let total: number = 0;
  const chunk: ArrayBuffer = new ArrayBuffer(64 * 1024);
  try {
    while (true) {
      const read: number = await gz.gzread(chunk);
      if (read > 0) {
        const part: Uint8Array = new Uint8Array(read);
        part.set(new Uint8Array(chunk, 0, read));
        chunks.push(part);
        total += read;
      }
      if (read <= 0) {
        break;
      }
      const eof: number = await gz.gzeof();
      if (eof === 1) {
        break;
      }
    }
  } finally {
    await gz.gzcloser();
    removeQuietly(inPath);
  }
  const all: Uint8Array = new Uint8Array(total);
  let offset: number = 0;
  for (const part of chunks) {
    all.set(part, offset);
    offset += part.length;
  }
  return DECODER.decodeToString(all);
}

const COMPRESS_THRESHOLD: number = 1024;

/** 按洛雪规则打包待发送的消息（与官方 encryptMsg 行为一致） */
export async function packMessage(text: string): Promise<string> {
  if (text.length <= COMPRESS_THRESHOLD) {
    return text;
  }
  try {
    return `cg_${await gzipToBase64(text)}`;
  } catch (e) {
    // 压缩失败不阻断通信：服务端的 decryptMsg 对不带 cg_ 前缀的消息原样解析
    appendError(`[${TAG}] gzip failed, send plain text: ${JSON.stringify(e)}`);
    return text;
  }
}

/** 按洛雪规则解开收到的消息（与官方 decryptMsg 行为一致） */
export async function unpackMessage(text: string): Promise<string> {
  if (text.length >= 3 && text.substring(0, 3) === 'cg_') {
    return await gunzipFromBase64(text.substring(3));
  }
  return text;
}
