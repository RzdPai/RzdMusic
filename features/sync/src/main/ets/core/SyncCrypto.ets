/**
 * 对应 listen 的 entry/src/main/ets/core/sync/SyncCrypto.ets
 *
 * 【加密方案选型：方案 (b) —— @ohos/crypto-js】
 *   - AES-128-ECB/PKCS7 与 MD5 用 @ohos/crypto-js 实现：它是同步 API，能保持与 listen 版本
 *     完全一致的函数签名（aesEncryptBase64 / aesDecryptBase64 / toMD5 都是同步返回），
 *     上层 SyncClient 的调用点不用改成 await。若改用 @kit.CryptoArchitectureKit（方案 a），
 *     cipher.doFinal / createMd 全是 async，派生密钥、加密认证消息这些调用点全都得改成异步。
 *   - RSA-2048 仍走 @kit.CryptoArchitectureKit：密钥生成与 OAEP 解密用纯 JS 实现不可靠，
 *     这部分 listen 本来就是用系统能力，签名也本来就是 Promise。
 *   依赖：features/sync/oh-package.json5 里新增了 "@ohos/crypto-js": "^2.0.5"（与 features/player 同版本）。
 *
 * 适配改动：
 *   - listen 复用了自己的 core/music/LxCrypto.ets（纯 ArkTS 手写 AES/MD5/Base64），RzdMusic 里没有这个
 *     文件，所以本文件把 Base64 / UTF-8 / MD5 / AES / RSA 全套自带实现，对外仍导出 listen 的
 *     SyncCrypto 名字（deriveKeyB64 / aesEncryptBase64 / aesDecryptBase64 / generateRsaKey /
 *     rsaDecryptBase64 / toMD5 / logCryptoError），另外把 LxCrypto 风格的字节级函数
 *     （utf8Bytes / bytesToUtf8 / toBase64 / fromBase64 / md5Hex /
 *     aes128EcbPkcs7EncryptBytes / aes128EcbPkcs7DecryptBytes / aes128EcbPkcs7Encrypt /
 *     aes128EcbPkcs7Decrypt）一并导出，避免上层再引 listen 的模块。
 *   - 日志由 listen 的 hilog 换成 musicbasic 的 appendError。
 *
 * 洛雪同步用到的加解密
 *
 * 与官方实现对位关系：
 *   - 对称：AES-128-ECB / PKCS7（洛雪 AES_MODE.ECB_128_NoPadding 的真实取值是 Java 的 "AES"，
 *     即 AES/ECB/PKCS5Padding），密文以 base64 传输；
 *   - 非对称：RSA-2048 + OAEP(SHA-1, MGF1-SHA1)，与服务端 Node 的
 *     RSA_PKCS1_OAEP_PADDING 默认参数、移动端 OAEPWithSHA1AndMGF1Padding 一致；
 *   - 摘要：MD5 小写 hex（洛雪 toMD5 就是 crypto.createHash('md5').digest('hex')）。
 */

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import CryptoJS from '@ohos/crypto-js';
import { appendError } from 'musicbasic';
import { RsaKeyPairB64 } from './SyncTypes';

// ------------------------------------------------------------------ 文本编码

/** 全局复用的编解码器（与 listen 的 SyncGzip 一样，避免每次调用都新建） */
const TEXT_ENCODER: util.TextEncoder = new util.TextEncoder();
const TEXT_DECODER: util.TextDecoder = util.TextDecoder.create('utf-8');

// ------------------------------------------------------------------ 工具

function numbersToU8(bytes: number[]): Uint8Array {
  const out = new Uint8Array(bytes.length);
  for (let i = 0; i < bytes.length; i++) {
    out[i] = bytes[i] & 0xFF;
  }
  return out;
}

function u8ToNumbers(data: Uint8Array): number[] {
  const out: number[] = [];
  for (let i = 0; i < data.length; i++) {
    out.push(data[i]);
  }
  return out;
}

/** UTF-8 文本 -> 字节数组 */
export function utf8Bytes(str: string): number[] {
  return u8ToNumbers(TEXT_ENCODER.encodeInto(str));
}

/** 字节数组 -> UTF-8 文本 */
export function bytesToUtf8(bytes: number[]): string {
  return TEXT_DECODER.decodeToString(numbersToU8(bytes));
}

/** 0..255 的单字符查表，避免逐字节调 String.fromCharCode */
const LATIN1_CHARS: string[] = buildLatin1Chars();

function buildLatin1Chars(): string[] {
  const out: string[] = [];
  for (let i = 0; i < 256; i++) {
    out.push(String.fromCharCode(i));
  }
  return out;
}

/**
 * 字节数组 -> crypto-js 的 WordArray
 * 走 `enc.Latin1.parse`（1 字节 = 1 字符，无损）而不是 `WordArray.create`：
 * 前者在 @ohos/crypto-js 的类型声明里有，后者没有静态 create（靠 any 才能过，DevEco 严格解析时会报错）。
 */
function bytesToWordArray(bytes: number[]): CryptoJS.lib.WordArray {
  const parts: string[] = [];
  for (let i = 0; i < bytes.length; i++) {
    parts.push(LATIN1_CHARS[bytes[i] & 0xFF]);
  }
  return CryptoJS.enc.Latin1.parse(parts.join(''));
}

/** crypto-js 的 WordArray -> 字节数组（Latin1 编码天然按 sigBytes 截断尾部填充） */
function wordArrayToBytes(wa: CryptoJS.lib.WordArray): number[] {
  const latin1: string = CryptoJS.enc.Latin1.stringify(wa);
  const out: number[] = [];
  for (let i = 0; i < latin1.length; i++) {
    out.push(latin1.charCodeAt(i) & 0xFF);
  }
  return out;
}

/** 字节数组 -> 标准 base64（带 = 补齐，与洛雪的 base64 一致） */
export function toBase64(bytes: number[]): string {
  return CryptoJS.enc.Base64.stringify(bytesToWordArray(bytes));
}

/** 标准 base64 -> 字节数组 */
export function fromBase64(text: string): number[] {
  return wordArrayToBytes(CryptoJS.enc.Base64.parse(text));
}

// ------------------------------------------------------------------ 摘要

/** MD5 小写 hex（与洛雪 toMD5 一致） */
export function md5Hex(input: string): string {
  const digest: CryptoJS.lib.WordArray = CryptoJS.MD5(input);
  return digest.toString();
}

/** 摘要：MD5 小写 hex（与洛雪 toMD5 一致） */
export function toMD5(text: string): string {
  return md5Hex(text);
}

// ------------------------------------------------------------------ 对称

/**
 * AES-128-ECB/PKCS7 加密（字节级）
 * @param keyBytes 16 字节密钥
 * @param dataBytes 明文
 * @returns 密文字节（长度已补齐到 16 字节的整数倍）
 */
export function aes128EcbPkcs7EncryptBytes(keyBytes: number[], dataBytes: number[]): number[] {
  const key: CryptoJS.lib.WordArray = bytesToWordArray(keyBytes);
  const message: CryptoJS.lib.WordArray = bytesToWordArray(dataBytes);
  const params: CryptoJS.lib.CipherParams = CryptoJS.AES.encrypt(message, key, {
    mode: CryptoJS.mode.ECB,
    padding: CryptoJS.pad.Pkcs7,
  });
  return wordArrayToBytes(params.ciphertext);
}

/**
 * AES-128-ECB/PKCS7 解密（字节级）
 * @param keyBytes 16 字节密钥
 * @param dataBytes 密文字节
 * @returns 明文
 */
export function aes128EcbPkcs7DecryptBytes(keyBytes: number[], dataBytes: number[]): number[] {
  const key: CryptoJS.lib.WordArray = bytesToWordArray(keyBytes);
  // 把密文转成 base64 再交给 CryptoJS.AES.decrypt：它的默认 format(OpenSSL) 会 parse 成
  // CipherParams，这样就不用手搓 CipherParams 对象（ArkTS 禁止无类型对象字面量）
  const cipherB64: string = toBase64(dataBytes);
  const plain: CryptoJS.lib.WordArray = CryptoJS.AES.decrypt(cipherB64, key, {
    mode: CryptoJS.mode.ECB,
    padding: CryptoJS.pad.Pkcs7,
  });
  return wordArrayToBytes(plain);
}

/** 字符串版：AES-128-ECB/PKCS7 加密，明文 UTF-8，密钥 base64，返回 base64 密文 */
export function aes128EcbPkcs7Encrypt(text: string, b64Key: string): string {
  return aesEncryptBase64(text, b64Key);
}

/** 字符串版：AES-128-ECB/PKCS7 解密，输入 base64 密文，返回 UTF-8 文本 */
export function aes128EcbPkcs7Decrypt(cipherB64: string, b64Key: string): string {
  return aesDecryptBase64(cipherB64, b64Key);
}

/** 由认证码/密码派生 AES 密钥：md5(code) 的前 16 个字符，再 base64（洛雪的做法） */
export function deriveKeyB64(authCode: string): string {
  const key: string = md5Hex(authCode).substring(0, 16);
  return toBase64(utf8Bytes(key));
}

/** AES-128-ECB/PKCS7 加密，明文按 UTF-8，输出 base64 */
export function aesEncryptBase64(text: string, b64Key: string): string {
  const keyBytes: number[] = fromBase64(b64Key);
  return toBase64(aes128EcbPkcs7EncryptBytes(keyBytes, utf8Bytes(text)));
}

/** AES-128-ECB/PKCS7 解密，输入 base64 密文，输出 UTF-8 文本 */
export function aesDecryptBase64(cipherB64: string, b64Key: string): string {
  const keyBytes: number[] = fromBase64(b64Key);
  return bytesToUtf8(aes128EcbPkcs7DecryptBytes(keyBytes, fromBase64(cipherB64)));
}

// ------------------------------------------------------------------ 非对称

/**
 * 生成 RSA-2048 密钥对，导出格式与洛雪移动端原生模块一致：
 *   - 公钥：X.509(SPKI) DER 的 base64（认证时发给服务端，不带 PEM 头尾与换行）
 *   - 私钥：PKCS#8 DER 的 base64（用于解开服务端用公钥加密的身份信息）
 */
export async function generateRsaKey(): Promise<RsaKeyPairB64> {
  const generator: cryptoFramework.AsyKeyGenerator = cryptoFramework.createAsyKeyGenerator('RSA2048');
  const pair: cryptoFramework.KeyPair = await generator.generateKeyPair();
  const pubDer: cryptoFramework.DataBlob = pair.pubKey.getEncoded();
  const priDer: cryptoFramework.DataBlob = pair.priKey.getEncoded();
  return {
    publicKey: toBase64(u8ToNumbers(pubDer.data)),
    privateKey: toBase64(u8ToNumbers(priDer.data)),
  };
}

/** RSA-OAEP(SHA-1) 解密：输入 base64 密文与 PKCS#8 私钥 base64，输出 UTF-8 文本 */
export async function rsaDecryptBase64(cipherB64: string, privateKeyB64: string): Promise<string> {
  const generator: cryptoFramework.AsyKeyGenerator = cryptoFramework.createAsyKeyGenerator('RSA2048');
  const priBlob: cryptoFramework.DataBlob = { data: numbersToU8(fromBase64(privateKeyB64)) };
  const pair: cryptoFramework.KeyPair = await generator.convertKey(null, priBlob);
  const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('RSA2048|PKCS1_OAEP|SHA1|MGF1_SHA1');
  await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, pair.priKey, null);
  const input: cryptoFramework.DataBlob = { data: numbersToU8(fromBase64(cipherB64)) };
  const output: cryptoFramework.DataBlob = await cipher.doFinal(input);
  return bytesToUtf8(u8ToNumbers(output.data));
}

export function logCryptoError(where: string, err: Object): void {
  appendError(`${where} failed: ${JSON.stringify(err)}`);
}
