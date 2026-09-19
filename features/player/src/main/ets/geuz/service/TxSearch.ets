import { SingerInfo } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { SearchPageResult } from '../model/SearchModels'
import { httpPostJson } from './HttpUtils'

interface TxMusicResponse {
  code: number
  req: TxReqResp | undefined
}

interface TxReqResp {
  code: number
  data: TxData | undefined
}

interface TxData {
  body: TxDataBody | undefined
  meta: TxMeta | undefined
  totalNum: number | undefined
  total_num: number | undefined
}

interface TxDataBody {
  singer: TxListBody | undefined
  album: TxListBody | undefined
}

interface TxListBody {
  list: Object[] | undefined
}

interface TxMeta {
  estimate_sum: number | undefined
  singer: TxMeta | undefined
  album: TxMeta | undefined
}

interface TxRawSinger {
  singerID: number | undefined
  singerMID: string | undefined
  singerName: string | undefined
  singerPic: string | undefined
  albumNum: number | undefined
  songNum: number | undefined
}

interface TxRawAlbum {
  albumID: number | undefined
  albumMID: string | undefined
  albumName: string | undefined
  albumPic: string | undefined
  singerID: number | undefined
  singerName: string | undefined
  publicTime: string | undefined
  songNum: number | undefined
}

interface TxWebComm {
  ct: string
  cv: string
  uin: string
}

interface TxWebReq {
  module: string
  method: string
  param: Object
}

export function buildTxHeaders(): Record<string, string> {
  return {
    'Content-Type': 'application/json;charset=utf-8',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36',
    'Referer': 'https://y.qq.com/',
  }
}

export async function musicuRequest(reqModule: string, method: string, param: Object): Promise<TxData> {
  let comm: TxWebComm = { 'ct': '19', 'cv': '1859', 'uin': '0' }
  let req: TxWebReq = { 'module': reqModule, 'method': method, 'param': param }
  let body: Record<string, Object> = {
    'comm': comm,
    'req': req,
  }
  let resp = await httpPostJson('https://u.y.qq.com/cgi-bin/musicu.fcg', body, buildTxHeaders()) as TxMusicResponse
  if (resp.code !== 0 || resp.req === undefined || resp.req.code !== 0 || resp.req.data === undefined) {
    throw new Error('接口错误: code=' + resp.code)
  }
  return resp.req.data
}

function buildSearchParam(keyword: string, page: number, limit: number, searchType: number): Record<string, Object> {
  return {
    'grp': 1,
    'num_per_page': limit,
    'page_num': page,
    'query': keyword,
    'search_type': searchType,
  }
}

function extractEstimateSum(meta: TxMeta | undefined): number {
  if (meta === undefined) return 0
  if (meta.estimate_sum !== undefined) return meta.estimate_sum
  if (meta.singer !== undefined && meta.singer.estimate_sum !== undefined) return meta.singer.estimate_sum
  if (meta.album !== undefined && meta.album.estimate_sum !== undefined) return meta.album.estimate_sum
  return 0
}

function mapTxSingers(rawList: TxRawSinger[]): SingerInfo[] {
  let list: SingerInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let picRaw = item.singerPic ?? ''
    let picUrl = ''
    if (picRaw.length > 0) {
      picUrl = picRaw.replace(new RegExp('R\\d+x\\d+M000'), 'R800x800M000')
    }
    list.push(new SingerInfo(String(item.singerMID ?? item.singerID ?? 0), item.singerName ?? '',
      picUrl, '', item.albumNum ?? 0, item.songNum ?? 0))
  }
  return list
}

function mapTxAlbums(rawList: TxRawAlbum[]): AlbumInfo[] {
  let list: AlbumInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let mid = item.albumMID ?? ''
    let picRaw = item.albumPic ?? ''
    let picUrl = ''
    if (picRaw.length > 0) {
      picUrl = picRaw.replace(new RegExp('R\\d+x\\d+M000'), 'R300x300M000')
    }
    let size = item.songNum ?? 0
    list.push(new AlbumInfo(String(item.albumID ?? 0), mid, item.albumName ?? '', picUrl,
      item.singerID ?? 0, item.singerName ?? '', size, item.publicTime ?? ''))
  }
  return list
}

export async function searchSinger(keyword: string, page: number): Promise<SearchPageResult<SingerInfo>> {
  let data = await musicuRequest('music.search.SearchCgiService', 'DoSearchForQQMusicDesktop',
    buildSearchParam(keyword, page, 20, 1))
  let rawList = (data.body?.singer?.list ?? []) as TxRawSinger[]
  let list = mapTxSingers(rawList)
  let total = extractEstimateSum(data.meta)
  let allPage = total > 0 ? Math.ceil(total / 20) : 0
  return new SearchPageResult<SingerInfo>(list, allPage, total)
}

export async function getAlbumSongCount(albumMid: string): Promise<number> {
  if (albumMid.length === 0) return 0
  try {
    let param: Record<string, Object> = {
      'albumMid': albumMid,
      'begin': 0,
      'num': 1,
    }
    let data = await musicuRequest('music.musichallAlbum.AlbumSongList', 'GetAlbumSongList', param)
    return data.totalNum ?? data.total_num ?? 0
  } catch (e) {
    return 0
  }
}

export async function fillAlbumSizes(list: AlbumInfo[]): Promise<void> {
  let missing: AlbumInfo[] = []
  for (let i = 0; i < list.length; i++) {
    if (list[i].size === 0 && list[i].mid.length > 0) {
      missing.push(list[i])
    }
  }
  if (missing.length === 0) return
  let promises: Promise<number>[] = []
  for (let i = 0; i < missing.length; i++) {
    promises.push(getAlbumSongCount(missing[i].mid))
  }
  let counts = await Promise.all(promises)
  for (let i = 0; i < missing.length; i++) {
    missing[i].size = counts[i]
  }
}

export async function searchAlbum(keyword: string, page: number): Promise<SearchPageResult<AlbumInfo>> {
  let data = await musicuRequest('music.search.SearchCgiService', 'DoSearchForQQMusicDesktop',
    buildSearchParam(keyword, page, 20, 2))
  let list = mapTxAlbums((data.body?.album?.list ?? []) as TxRawAlbum[])
  await fillAlbumSizes(list)
  let total = extractEstimateSum(data.meta)
  let allPage = total > 0 ? Math.ceil(total / 20) : 0
  return new SearchPageResult<AlbumInfo>(list, allPage, total)
}
