import { http } from '@kit.NetworkKit'
import { md5Hex } from './CryptoUtils'

const KG_SALT = 'OIlwieks28dk2k092lksi2UIkp'
const KG_APPID = 1005
const KG_CLIENTVER = 20489
const KG_DFID = '-'
const KG_MID = '150330140572226157714874292511398898608'
const KG_UA = 'Android15-1070-11083-46-0-DiscoveryDRADProtocol-wifi'
const KG_RF = 'B9EDA08A64250DEFFBCADDEE00F8F25F'

function paramValueToString(v: Object): string {
  if (typeof v === 'object') {
    return JSON.stringify(v)
  }
  return String(v)
}

function mergeParams(target: Record<string, Object>, extra: Record<string, Object>): void {
  let keys = Object.keys(extra)
  for (let i = 0; i < keys.length; i++) {
    target[keys[i]] = extra[keys[i]]
  }
}

function mergeStringParams(target: Record<string, string>, extra: Record<string, string>): void {
  let keys = Object.keys(extra)
  for (let i = 0; i < keys.length; i++) {
    target[keys[i]] = extra[keys[i]]
  }
}

async function signAndroid(params: Record<string, Object>, data: string): Promise<string> {
  let keys = Object.keys(params)
  keys.sort()
  let ps = ''
  for (let i = 0; i < keys.length; i++) {
    ps = ps + keys[i] + '=' + paramValueToString(params[keys[i]])
  }
  return md5Hex(KG_SALT + ps + data + KG_SALT)
}

async function gatewayRequest(method: string, path: string, body: Object | undefined,
  extraParams: Record<string, Object> | undefined,
  extraHeaders: Record<string, string> | undefined): Promise<Object> {
  let clienttime = String(Math.floor(Date.now() / 1000))
  let params: Record<string, Object> = {
    'dfid': KG_DFID,
    'mid': KG_MID,
    'uuid': '-',
    'appid': KG_APPID,
    'clientver': KG_CLIENTVER,
    'clienttime': clienttime,
  }
  if (extraParams !== undefined) {
    mergeParams(params, extraParams)
  }
  let dataStr = body !== undefined ? JSON.stringify(body) : ''
  let signature = await signAndroid(params, dataStr)
  params['signature'] = signature

  let headers: Record<string, string> = {
    'User-Agent': KG_UA,
    'dfid': KG_DFID,
    'clienttime': clienttime,
    'mid': KG_MID,
    'kg-rc': '1',
    'kg-thash': '5d816a0',
    'kg-rec': '1',
    'kg-rf': KG_RF,
    'Content-Type': 'application/json',
  }
  if (extraHeaders !== undefined) {
    mergeStringParams(headers, extraHeaders)
  }

  let qs = ''
  let keys = Object.keys(params)
  for (let i = 0; i < keys.length; i++) {
    if (i > 0) qs = qs + '&'
    qs = qs + encodeURIComponent(keys[i]) + '=' + encodeURIComponent(paramValueToString(params[keys[i]]))
  }
  let url = 'https://gateway.kugou.com' + path + '?' + qs

  let httpRequest = http.createHttp()
  let response = await httpRequest.request(url, {
    method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
    header: headers,
    extraData: dataStr,
    connectTimeout: 15000,
    readTimeout: 15000,
  } as http.HttpRequestOptions)
  httpRequest.destroy()
  if (response.responseCode !== 200) {
    throw new Error('请求失败: HTTP ' + response.responseCode)
  }
  return JSON.parse(response.result as string) as Object
}

export async function kgSearchSinger(keyword: string, page: number): Promise<Object> {
  let params: Record<string, Object> = {
    'keyword': keyword,
    'page': page,
    'pagesize': 30,
    'platform': 'AndroidFilter',
  }
  let headers: Record<string, string> = { 'x-router': 'complexsearch.kugou.com' }
  return gatewayRequest('GET', '/v1/search/author', undefined, params, headers)
}

export async function kgSearchAlbum(keyword: string, page: number): Promise<Object> {
  let params: Record<string, Object> = {
    'keyword': keyword,
    'page': page,
    'pagesize': 30,
    'platform': 'AndroidFilter',
  }
  let headers: Record<string, string> = { 'x-router': 'complexsearch.kugou.com' }
  return gatewayRequest('GET', '/v1/search/album', undefined, params, headers)
}

export async function kgArtistDetail(authorId: string): Promise<Object> {
  let body: Record<string, Object> = { 'author_id': authorId }
  let headers: Record<string, string> = { 'x-router': 'openapi.kugou.com', 'kg-tid': '36' }
  return gatewayRequest('POST', '/kmr/v3/author', body, undefined, headers)
}

export async function kgArtistAlbums(authorId: string, page: number, pagesize: number, sort: number): Promise<Object> {
  let body: Record<string, Object> = {
    'author_id': authorId,
    'pagesize': pagesize,
    'page': page,
    'sort': sort,
    'category': 1,
    'area_code': 'all',
  }
  let headers: Record<string, string> = { 'x-router': 'openapi.kugou.com', 'kg-tid': '36' }
  return gatewayRequest('POST', '/kmr/v1/author/albums', body, undefined, headers)
}

export async function kgArtistSongs(authorId: string, page: number, pagesize: number, sort: number): Promise<Object> {
  let params: Record<string, Object> = {
    'author_id': authorId,
    'area_code': 'all',
    'sort': sort,
    'page': page,
    'pagesize': pagesize,
    'replace_api_version': 1,
    'mvdata_need': 1,
    'show_audio_honor': 1,
    'show_audio_tag': 1,
    'replace_need': 1,
  }
  let headers: Record<string, string> = { 'kg-tid': '36' }
  return gatewayRequest('GET', '/openapi/kmr/v2/audio_group/author', undefined, params, headers)
}

export async function kgAlbumDetail(albumId: string): Promise<Object> {
  let dataArr: Object[] = []
  let item: Record<string, Object> = { 'album_id': albumId }
  dataArr.push(item)
  let body: Record<string, Object> = {
    'data': dataArr,
    'is_buy': 0,
    'fields': 'album_id,album_name,publish_date,sizable_cover,intro,language,is_publish,heat,type,quality,authors,exclusive,author_name,trans_param',
  }
  let headers: Record<string, string> = { 'x-router': 'openapi.kugou.com', 'kg-tid': '255' }
  return gatewayRequest('POST', '/kmr/v2/albums', body, undefined, headers)
}

export async function kgAlbumSongs(albumId: string, page: number, pagesize: number): Promise<Object> {
  let body: Record<string, Object> = {
    'album_id': albumId,
    'is_buy': '',
    'page': page,
    'pagesize': pagesize,
  }
  let headers: Record<string, string> = { 'x-router': 'openapi.kugou.com', 'kg-tid': '255' }
  return gatewayRequest('POST', '/v1/album_audio/lite', body, undefined, headers)
}