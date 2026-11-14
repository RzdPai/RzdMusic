import { http } from '@kit.NetworkKit'
import { buildEapiParams } from './Eapi'
import { SearchPageResult } from '../model/SearchModels'
import { SingerInfo } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { CloudSearchResponse } from '../model/SearchModels'
import { rawToSingerList } from '../model/SearchModels'
import { rawToAlbumList } from '../model/SearchModels'
import { rawToArtistCount } from '../model/SearchModels'
import { rawToAlbumCount } from '../model/SearchModels'

const EAPI_SEARCH_URL = 'https://interfacepc.music.163.com/eapi/cloudsearch/pc'
const USER_AGENT = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'

class CloudSearchHeader {
  osver: string = 'iOS 18.0'
  deviceId: string = ''
  os: string = 'ios'
  appver: string = '9.0.0'
  versioncode: string = '140'
  mobilename: string = ''
  buildver: string = ''
  resolution: string = '1920x1080'
  __csrf: string = ''
  channel: string = ''
  requestId: string = ''

  constructor() {
    this.buildver = String(Date.now())
    this.requestId = String(Date.now())
  }
}

function buildHeaders(): Record<string, string> {
  return {
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent': USER_AGENT,
    'Origin': 'https://music.163.com',
    'Referer': 'https://music.163.com',
  }
}

class CloudSearchParams {
  s: string = ''
  type: number = 1
  limit: number = 20
  offset: number = 0
  total: boolean = false
  header: CloudSearchHeader = new CloudSearchHeader()

  constructor(keyword: string, type: number, page: number, limit: number) {
    this.s = keyword
    this.type = type
    this.limit = limit
    this.offset = limit * (page - 1)
    this.total = page === 1
  }
}

async function requestCloudSearch(keyword: string, type: number, page: number, limit: number): Promise<string> {
  let params = new CloudSearchParams(keyword, type, page, limit)
  let eapiParams = await buildEapiParams('/api/cloudsearch/pc', params)
  let httpRequest = http.createHttp()
  let response = await httpRequest.request(EAPI_SEARCH_URL, {
    method: http.RequestMethod.POST,
    header: buildHeaders(),
    extraData: 'params=' + eapiParams,
    connectTimeout: 15000,
    readTimeout: 15000,
  } as http.HttpRequestOptions)
  httpRequest.destroy()
  if (response.responseCode !== 200) {
    throw new Error('请求失败: HTTP ' + response.responseCode)
  }
  let body = response.result as string
  return body
}

function parseCloudBody(body: string): CloudSearchResponse {
  let resp = JSON.parse(body) as CloudSearchResponse
  if (resp.code !== 200) {
    throw new Error('搜索失败(code=' + resp.code + ')')
  }
  return resp
}

export async function searchSinger(keyword: string, page: number): Promise<SearchPageResult<SingerInfo>> {
  let body = await requestCloudSearch(keyword, 100, page, 20)
  let resp = parseCloudBody(body)
  let list = rawToSingerList(resp)
  let total = rawToArtistCount(resp)
  let allPage = total > 0 ? Math.ceil(total / 20) : 0
  return new SearchPageResult<SingerInfo>(list, allPage, total)
}

export async function searchAlbum(keyword: string, page: number): Promise<SearchPageResult<AlbumInfo>> {
  let body = await requestCloudSearch(keyword, 10, page, 20)
  let resp = parseCloudBody(body)
  let list = rawToAlbumList(resp)
  let total = rawToAlbumCount(resp)
  let allPage = total > 0 ? Math.ceil(total / 20) : 0
  return new SearchPageResult<AlbumInfo>(list, allPage, total)
}