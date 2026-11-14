import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

const EAPI_KEY: string = 'e82ckenh8dichen8';
const PRESET_KEY: string = '0CoJUm6Qyw8W8jud';
const LINUXAPI_KEY: string = 'rFgB&h#%2?^eDg:Q';
const IV_BYTES: string = '0102030405060708';
const BASE62: string = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const ACTUAL_PUBLIC_KEY: string = '-----BEGIN PUBLIC KEY-----\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgtQn2JZ34ZC28NWYpAUd98iZ37BUrX/aKzmFbt7clFSs6sXqHauqKWqdtLkF2KexO40H1YTX8z2lSgBBOAxLsvaklV8k4cBFK9snQXE9/DDaFt6Rr7iVZMldczhC0JNgTz+SHXT6CBHuX3e9SdB1Ua44oncaTWz7OBGLbCiK45wIDAQAB\n-----END PUBLIC KEY-----';

export class WeapiResult {
  params: string = '';
  encSecKey: string = '';
}

function utf8Bytes(value: string): Uint8Array {
  const encoder: util.TextEncoder = new util.TextEncoder();
  const buffer: ArrayBuffer = new ArrayBuffer(value.length * 4);
  const view: Uint8Array = new Uint8Array(buffer);
  const result = encoder.encodeInto(value, view);
  return view.slice(0, result.written);
}

function bytesToHex(bytes: Uint8Array): string {
  const chars: string[] = [];
  for (let i = 0; i < bytes.length; i++) {
    chars.push(bytes[i].toString(16).padStart(2, '0'));
  }
  return chars.join('');
}

function bytesToAscii(bytes: Uint8Array): string {
  let result: string = '';
  for (let i = 0; i < bytes.length; i++) {
    result += String.fromCharCode(bytes[i]);
  }
  return result;
}

function base64Encode(bytes: Uint8Array): string {
  const helper: util.Base64Helper = new util.Base64Helper();
  return bytesToAscii(helper.encodeSync(bytes));
}

function base64Decode(value: string): Uint8Array {
  const helper: util.Base64Helper = new util.Base64Helper();
  return helper.decodeSync(utf8Bytes(value));
}

export async function md5Hex(data: Uint8Array): Promise<string> {
  const md: cryptoFramework.Md = cryptoFramework.createMd('MD5');
  await md.update({ data: data });
  const digest: cryptoFramework.DataBlob = await md.digest();
  return bytesToHex(digest.data);
}

export async function md5HexString(value: string): Promise<string> {
  return md5Hex(utf8Bytes(value));
}

async function aesEcbEncrypt(keyBytes: Uint8Array, dataBytes: Uint8Array): Promise<string> {
  const keyGenerator: cryptoFramework.SymKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  const key: cryptoFramework.SymKey = await keyGenerator.convertKey({ data: keyBytes });
  const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7');
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, null);
  const encrypted: cryptoFramework.DataBlob = await cipher.doFinal({ data: dataBytes });
  return bytesToHex(encrypted.data);
}

async function aesCbcEncrypt(keyBytes: Uint8Array, dataBytes: Uint8Array): Promise<Uint8Array> {
  const keyGenerator: cryptoFramework.SymKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  const key: cryptoFramework.SymKey = await keyGenerator.convertKey({ data: keyBytes });
  const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7');
  const ivSpec: cryptoFramework.IvParamsSpec = {
    algName: 'IvParamsSpec',
    iv: { data: utf8Bytes(IV_BYTES) },
  };
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, ivSpec);
  const encrypted: cryptoFramework.DataBlob = await cipher.doFinal({ data: dataBytes });
  return encrypted.data;
}

async function rsaNoPaddingEncrypt(dataBytes: Uint8Array): Promise<string> {
  const keyGenerator: cryptoFramework.AsyKeyGenerator = cryptoFramework.createAsyKeyGenerator('RSA1024');
  const pemLines: string[] = ACTUAL_PUBLIC_KEY.split('\n');
  let base64Body: string = '';
  for (let i = 0; i < pemLines.length; i++) {
    const line: string = pemLines[i];
    if (line.startsWith('-----') || line.length === 0) continue;
    base64Body += line;
  }
  const derBytes: Uint8Array = base64Decode(base64Body);
  const keyPair: cryptoFramework.KeyPair = await keyGenerator.convertKey({ data: derBytes }, null);
  const key: cryptoFramework.PubKey = keyPair.pubKey;
  const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('RSA1024|ECB|NoPadding');
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, null);
  const encrypted: cryptoFramework.DataBlob = await cipher.doFinal({ data: dataBytes });
  return bytesToHex(encrypted.data);
}

async function randomBytes(length: number): Promise<Uint8Array> {
  const random: cryptoFramework.Random = cryptoFramework.createRandom();
  const blob: cryptoFramework.DataBlob = await random.generateRandom(length);
  return blob.data;
}

export async function eapiEncrypt(uri: string, text: string): Promise<string> {
  const digest: string = await md5Hex(utf8Bytes(`nobody${uri}use${text}md5forencrypt`));
  const data: string = `${uri}-36cd479b6b5-${text}-36cd479b6b5-${digest}`;
  const encrypted: string = await aesEcbEncrypt(utf8Bytes(EAPI_KEY), utf8Bytes(data));
  return encrypted.toUpperCase();
}

export async function weapiEncrypt(valueJson: string): Promise<WeapiResult> {
  const randomSource: Uint8Array = await randomBytes(16);
  const secretKeyChars: string[] = [];
  for (let i = 0; i < randomSource.length; i++) {
    secretKeyChars.push(BASE62.charAt(randomSource[i] % 62));
  }
  const secretKey: Uint8Array = utf8Bytes(secretKeyChars.join(''));
  const firstPass: Uint8Array = await aesCbcEncrypt(utf8Bytes(PRESET_KEY), utf8Bytes(valueJson));
  const params: Uint8Array = await aesCbcEncrypt(secretKey, utf8Bytes(base64Encode(firstPass)));
  const reversed: Uint8Array = new Uint8Array(secretKey.length);
  for (let i = 0; i < secretKey.length; i++) {
    reversed[i] = secretKey[secretKey.length - 1 - i];
  }
  const padded: Uint8Array = new Uint8Array(128);
  padded.set(reversed, 128 - reversed.length);
  const encSecKey: string = await rsaNoPaddingEncrypt(padded);
  const result: WeapiResult = new WeapiResult();
  result.params = base64Encode(params);
  result.encSecKey = encSecKey;
  return result;
}

export async function linuxapiEncrypt(valueJson: string): Promise<string> {
  const encrypted: string = await aesEcbEncrypt(utf8Bytes(LINUXAPI_KEY), utf8Bytes(valueJson));
  return encrypted.toUpperCase();
}
