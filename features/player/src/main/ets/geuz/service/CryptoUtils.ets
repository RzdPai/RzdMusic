import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { util } from '@kit.ArkTS'

export function stringToUint8Array(str: string): Uint8Array {
  let encoder = new util.TextEncoder()
  return encoder.encodeInto(str)
}

export function bytesToHex(bytes: Uint8Array): string {
  let hex = ''
  for (let i = 0; i < bytes.length; i++) {
    let b = bytes[i]
    let h = b.toString(16)
    hex = hex + (h.length < 2 ? '0' + h : h)
  }
  return hex
}

export function base64EncodeBytes(bytes: Uint8Array): string {
  let helper = new util.Base64Helper()
  return helper.encodeToStringSync(bytes)
}

export function base64DecodeToBytes(b64: string): Uint8Array {
  let helper = new util.Base64Helper()
  return helper.decodeSync(b64)
}

export async function md5Hex(str: string): Promise<string> {
  let md = cryptoFramework.createMd('MD5')
  await md.update({ data: stringToUint8Array(str) })
  let digest = await md.digest()
  return bytesToHex(digest.data)
}

export async function aesEcbPkcs7Encrypt(plainText: string, keyStr: string): Promise<string> {
  let keyBlob: cryptoFramework.DataBlob = { data: stringToUint8Array(keyStr) }
  let symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128')
  let symKey = await symKeyGenerator.convertKey(keyBlob)
  let cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7')
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null)
  let output = await cipher.doFinal({ data: stringToUint8Array(plainText) })
  return base64EncodeBytes(output.data)
}