import { md5Hex, aesEcbPkcs7Encrypt, base64DecodeToBytes, bytesToHex } from './CryptoUtils'

const EAPI_KEY = 'e82ckenh8dichen8'
const EAPI_SECRET = '36cd479b6b5'

export async function buildEapiParams(url: string, object: Object): Promise<string> {
  let text = JSON.stringify(object)
  let message = 'nobody' + url + 'use' + text + 'md5forencrypt'
  let digest = await md5Hex(message)
  let source = url + '-' + EAPI_SECRET + '-' + text + '-' + EAPI_SECRET + '-' + digest
  let encrypted = await aesEcbPkcs7Encrypt(source, EAPI_KEY)
  let bytes = base64DecodeToBytes(encrypted)
  return bytesToHex(bytes).toUpperCase()
}