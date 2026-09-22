import { http } from '@kit.NetworkKit'

const DEFAULT_TIMEOUT = 15000

export const MG_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'

export function httpGetJson(url: string, headers: Record<string, string>): Promise<Object> {
  return httpRequest(url, 'GET', undefined, headers)
}

export function httpPostJson(url: string, body: Object, headers: Record<string, string>): Promise<Object> {
  return httpRequest(url, 'POST', JSON.stringify(body), headers)
}

async function httpRequest(url: string, method: string, extraData: string | undefined,
  headers: Record<string, string>): Promise<Object> {
  let req = http.createHttp()
  try {
    let response = await req.request(url, {
      method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
      header: headers,
      extraData: extraData,
      connectTimeout: DEFAULT_TIMEOUT,
      readTimeout: DEFAULT_TIMEOUT,
    } as http.HttpRequestOptions)
    if (response.responseCode !== 200) {
      throw new Error('请求失败: HTTP ' + response.responseCode)
    }
    return JSON.parse(response.result as string) as Object
  } finally {
    req.destroy()
  }
}

export function cleanText(text: string): string {
  let s = decodeUnicodeEscapes(text)
  s = s.replace(new RegExp('&nbsp;', 'g'), ' ')
  s = s.replace(new RegExp('&quot;', 'g'), '"')
  s = s.replace(new RegExp('&lt;br&gt;', 'g'), '\n')
  s = s.replace(new RegExp('&lt;', 'g'), '<')
  s = s.replace(new RegExp('&gt;', 'g'), '>')
  s = s.replace(new RegExp('&amp;', 'g'), '&')
  return s
}

function decodeUnicodeEscapes(text: string): string {
  let re = new RegExp('\\\\+u([0-9a-fA-F]{4})', 'g')
  return text.replace(re, (match: string, ...groups: string[]): string => {
    let hex = groups.length > 0 ? groups[0] : '0'
    return String.fromCharCode(parseInt(hex, 16))
  })
}
