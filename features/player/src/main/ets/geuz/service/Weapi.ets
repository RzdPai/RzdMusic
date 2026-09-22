import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { stringToUint8Array, bytesToHex, base64EncodeBytes } from './CryptoUtils'

const PRESET_KEY = '0CoJUm6Qyw8W8jud'
const IV = '0102030405060708'
const PUBLIC_KEY = '-----BEGIN PUBLIC KEY-----\n' +
  'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgtQn2JZ34ZC28NWYpAUd98iZ37BUrX/aKzmFbt7clFSs6sXqHauqKWqdtLkF2KexO40H1YTX8z2lSgBBOAxLsvaklV8k4cBFK9snQXE9/DDaFt6Rr7iVZMldczhC0JNgTz+SHXT6CBHuX3e9SdB1Ua44oncaTWz7OBGLbCiK45wIDAQAB\n' +
  '-----END PUBLIC KEY-----'

class WeapiParams {
  params: string = ''
  encSecKey: string = ''

  constructor(params: string, encSecKey: string) {
    this.params = params
    this.encSecKey = encSecKey
  }
}

async function aesCbcPkcs7Encrypt(plainText: string, keyStr: string, ivStr: string): Promise<string> {
  let keyBlob: cryptoFramework.DataBlob = { data: stringToUint8Array(keyStr) }
  let symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128')
  let symKey = await symKeyGenerator.convertKey(keyBlob)
  let ivSpec: cryptoFramework.IvParamsSpec = {
    algName: 'IvParamsSpec',
    iv: { data: stringToUint8Array(ivStr) },
  }
  let cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7')
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, ivSpec)
  let output = await cipher.doFinal({ data: stringToUint8Array(plainText) })
  return base64EncodeBytes(output.data)
}

async function rsaNoPaddingEncrypt(secretKeyReversed: string): Promise<string> {
  let keyBytes = stringToUint8Array(secretKeyReversed)
  let padded = new Uint8Array(128)
  padded.set(keyBytes, 128 - keyBytes.length)
  let generator = cryptoFramework.createAsyKeyGenerator('RSA1024')
  let keyPair = await generator.convertPemKey(PUBLIC_KEY, null)
  let cipher = cryptoFramework.createCipher('RSA1024|ECB|NoPadding')
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, keyPair.pubKey, null)
  let output = await cipher.doFinal({ data: padded })
  return bytesToHex(output.data)
}

function reverseString(str: string): string {
  let out = ''
  for (let i = str.length - 1; i >= 0; i--) {
    out = out + str.charAt(i)
  }
  return out
}

export async function buildWeapiParams(object: Object): Promise<WeapiParams> {
  let text = JSON.stringify(object)
  let secretKey = Math.random().toString().slice(2, 18)
  let b1 = await aesCbcPkcs7Encrypt(text, PRESET_KEY, IV)
  let params = await aesCbcPkcs7Encrypt(b1, secretKey, IV)
  let encSecKey = await rsaNoPaddingEncrypt(reverseString(secretKey))
  return new WeapiParams(params, encSecKey)
}