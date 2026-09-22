import { http } from '@kit.NetworkKit'

const KW_UA = 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.77 Safari/537.36'

class KwToken {
  name: string = ''
  value: string = ''
  ts: number = 0
}

let kwTokenCache: KwToken | undefined = undefined
let kwTokenPromise: Promise<KwToken> | undefined = undefined

function parseLongInt(str: string): number {
  let i = 0
  let sign = 1
  while (i < str.length && str.charAt(i) === ' ') {
    i++
  }
  if (i < str.length && (str.charAt(i) === '+' || str.charAt(i) === '-')) {
    if (str.charAt(i) === '-') sign = -1
    i++
  }
  while (i < str.length && str.charAt(i) === '0') {
    i++
  }
  let digits = str.substring(i)
  let j = 0
  while (j < digits.length && digits.charAt(j) >= '0' && digits.charAt(j) <= '9') {
    j++
  }
  digits = digits.substring(0, j)
  if (digits.length === 0) return NaN
  return sign * Number(digits)
}

function signSecret(t: string, e: string): string {
  let n: string = ''
  let i: number = 0
  for (i = 0; i < e.length; i++) {
    n = n + e.charCodeAt(i).toString()
  }
  let r = Math.floor(n.length / 5)
  let o = parseInt(n.charAt(r) + n.charAt(2 * r) + n.charAt(3 * r) + n.charAt(4 * r) + n.charAt(5 * r))
  let l = Math.ceil(e.length / 2)
  let c = Math.pow(2, 31) - 1
  let d = Math.round(1e9 * Math.random()) % 1e8
  n = n + d.toString()
  while (n.length > 10) {
    n = (parseLongInt(n.substring(0, 10)) + parseLongInt(n.substring(10, n.length))).toString()
  }
  let nn = (o * parseInt(n) + l) % c
  let out = ''
  for (i = 0; i < t.length; i++) {
    let hh = t.charCodeAt(i) ^ Math.floor(nn / c * 255)
    out = out + (hh < 16 ? '0' + hh.toString(16) : hh.toString(16))
    nn = (o * nn + l) % c
  }
  let ds = d.toString(16)
  while (ds.length < 8) {
    ds = '0' + ds
  }
  return out + ds
}

function extractSetCookie(header: Record<string, Object>): string {
  let keys = Object.keys(header)
  for (let i = 0; i < keys.length; i++) {
    if (keys[i].toLowerCase() === 'set-cookie') {
      let v = header[keys[i]]
      if (typeof v === 'string') {
        return v
      }
      if (Array.isArray(v)) {
        let arr = v as string[]
        let out = ''
        for (let j = 0; j < arr.length; j++) {
          out = out + arr[j] + '; '
        }
        return out
      }
    }
  }
  return ''
}

async function fetchToken(): Promise<KwToken> {
  let entries: string[] = ['https://www.kuwo.cn/', 'https://www.kuwo.cn/search/list?key=1']
  for (let e = 0; e < entries.length; e++) {
    let httpRequest = http.createHttp()
    let headerObj: Record<string, Object> = {}
    httpRequest.on('headersReceive', (header: Object) => {
      headerObj = header as Record<string, Object>
    })
    let response = await httpRequest.request(entries[e], {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': KW_UA },
      connectTimeout: 10000,
      readTimeout: 10000,
    } as http.HttpRequestOptions)
    httpRequest.destroy()
    let cookieStr = extractSetCookie(headerObj)
    if (cookieStr.length === 0) {
      let cookies = response.cookies
      if (cookies !== undefined && cookies.length > 0) {
        for (let i = 0; i < cookies.length; i++) {
          cookieStr = cookieStr + cookies[i] + '; '
        }
      }
    }
    if (cookieStr.length === 0 && response.responseCode === 200) {
      cookieStr = extractSetCookie(response.header as Record<string, Object>)
    }
    let match = cookieStr.match(new RegExp('(Hm_Iuvt_[a-z0-9]+)=([^;]+)'))
    if (match !== null && match.length >= 3) {
      let tk = new KwToken()
      tk.name = match[1]
      tk.value = match[2]
      tk.ts = Date.now()
      return tk
    }
  }
  throw new Error('获取酷我 token 失败: 所有入口均无 Set-Cookie')
}

async function ensureToken(): Promise<KwToken> {
  if (kwTokenCache !== undefined && Date.now() - kwTokenCache.ts < 3600000) {
    return kwTokenCache
  }
  if (kwTokenPromise !== undefined) {
    return kwTokenPromise
  }
  kwTokenPromise = fetchToken()
  try {
    let tk = await kwTokenPromise
    kwTokenCache = tk
    return tk
  } finally {
    kwTokenPromise = undefined
  }
}

function isIllegal(raw: Object): boolean {
  let rec = raw as Record<string, Object>
  let success = rec['success'] as boolean
  if (success === false) return true
  let message = rec['message'] as string
  if (message !== undefined && message.indexOf('illegal') >= 0) return true
  return false
}

async function doKwRequest(url: string, referer: string, tk: KwToken, secret: string): Promise<Object> {
  let reqId = String(Date.now()) + Math.random().toString(16).slice(2)
  let cookie = tk.name + '=' + tk.value
  let fullUrl = url + '&reqId=' + reqId
  let headers: Record<string, string> = {
    'cookie': cookie,
    'Secret': secret,
    'Referer': referer,
    'User-Agent': KW_UA,
  }
  let httpRequest = http.createHttp()
  let response = await httpRequest.request(fullUrl, {
    method: http.RequestMethod.GET,
    header: headers,
    proxy: false,
    connectTimeout: 15000,
    readTimeout: 15000,
  } as http.HttpRequestOptions)
  httpRequest.destroy()
  if (response.responseCode !== 200) {
    throw new Error('请求失败: HTTP ' + response.responseCode)
  }
  return JSON.parse(response.result as string) as Object
}

export async function kwGet(url: string, referer: string = 'http://www.kuwo.cn/'): Promise<Object> {
  let tk = await ensureToken()
  let secret = signSecret(tk.value, tk.name)
  let raw = await doKwRequest(url, referer, tk, secret)
  if (isIllegal(raw)) {
    kwTokenCache = undefined
    let tk2 = await ensureToken()
    let secret2 = signSecret(tk2.value, tk2.name)
    raw = await doKwRequest(url, referer, tk2, secret2)
  }
  return raw
}