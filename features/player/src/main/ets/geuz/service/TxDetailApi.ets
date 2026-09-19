import { musicuRequest, buildTxHeaders, fillAlbumSizes } from './TxSearch'
import { httpGetJson, httpPostJson } from './HttpUtils'
import { ArtistInfo } from '../model/SearchModels'
import { SongInfo } from '../model/SearchModels'
import { SongPageResult } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { ArtistAlbumPageResult } from '../model/SearchModels'
import { AlbumDetailResult } from '../model/SearchModels'

interface TxSingerDetailResp {
  code: number
  singer: TxSingerWrap | undefined
}

interface TxSingerWrap {
  code: number
  data: TxSingerData | undefined
}

interface TxSingerData {
  songlist: Object[] | undefined
  singer_info: TxSingerInfo | undefined
  singer_brief: string | undefined
  total_album: number | undefined
  total_song: number | undefined
}

interface TxSingerInfo {
  name: string | undefined
}

interface TxRawSong {
  mid: string | undefined
  name: string | undefined
  title: string | undefined
  singer: TxRawSongSinger[] | undefined
  album: TxRawSongAlbum | undefined
  interval: number | undefined
}

interface TxRawSongSinger {
  name: string | undefined
}

interface TxRawSongAlbum {
  name: string | undefined
  mid: string | undefined
}

interface TxRawAlbumItem {
  albumID: number | undefined
  albumMid: string | undefined
  albumName: string | undefined
  publishDate: string | undefined
  totalNum: number | undefined
  singerName: string | undefined
}

interface TxAlbumListData {
  albumList: Object[] | undefined
  total: number | undefined
}

interface TxAlbumInfoResp {
  code: number
  data: TxAlbumInfoData | undefined
}

interface TxAlbumInfoData {
  name: string | undefined
  singername: string | undefined
  total: number | undefined
  aDate: string | undefined
  list: Object[] | undefined
}

interface TxAlbumSong {
  songmid: string | undefined
  songname: string | undefined
  singer: TxRawSongSinger[] | undefined
  albumname: string | undefined
  interval: number | undefined
}

interface TxSingerReqComm {
  ct: number
  cv: number
}

interface TxSingerReqBody {
  method: string
  param: Object
  module: string
}

export async function getArtistDetail(artistMid: string): Promise<ArtistInfo> {
  let data = await singerDetailData(artistMid, 5, 0, 1)
  let name = data.singer_info?.name ?? ''
  let picUrl = `https://y.gtimg.cn/music/photo_new/T001R800x800M000${artistMid}.jpg`
  return new ArtistInfo(artistMid, artistMid, name, picUrl, '', data.total_album ?? 0,
    data.total_song ?? 0, data.singer_brief ?? '')
}

export async function getArtistSongs(artistMid: string, order: string, limit: number,
  offset: number): Promise<SongPageResult> {
  let sort = order === 'hot' ? 5 : 2
  let data = await singerDetailData(artistMid, sort, offset, limit)
  let list = mapTxSongs((data.songlist ?? []) as TxRawSong[])
  return new SongPageResult(list, data.total_song ?? 0, offset + limit < (data.total_song ?? 0))
}

export async function getArtistAlbums(artistMid: string, limit: number,
  offset: number): Promise<ArtistAlbumPageResult> {
  let param: Record<string, Object> = {
    'singerMid': artistMid,
    'begin': offset,
    'num': limit,
  }
  let data = await musicuRequest('music.musichallAlbum.AlbumListServer', 'GetAlbumList', param)
  let dataRec = data as Object as TxAlbumListData
  let rawList = (dataRec.albumList ?? []) as TxRawAlbumItem[]
  let list: AlbumInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let mid = item.albumMid ?? ''
    let picUrl = mid.length > 0 ? `https://y.gtimg.cn/music/photo_new/T002R300x300M000${mid}.jpg` : ''
    list.push(new AlbumInfo(String(item.albumID ?? 0), mid, item.albumName ?? '', picUrl, 0,
      item.singerName ?? '', item.totalNum ?? 0, item.publishDate ?? ''))
  }
  await fillAlbumSizes(list)
  let total = dataRec.total ?? 0
  return new ArtistAlbumPageResult(list, offset + limit < total)
}

export async function getAlbum(albumMid: string): Promise<AlbumDetailResult> {
  let url = 'https://i.y.qq.com/v8/fcg-bin/fcg_v8_album_info_cp.fcg?platform=h5page&albummid=' + albumMid +
    '&g_tk=938407465&uin=0&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&needNewCode=1'
  let resp = await httpGetJson(url, buildTxHeaders()) as TxAlbumInfoResp
  if (resp.code !== 0 || resp.data === undefined) {
    throw new Error('接口错误: code=' + resp.code)
  }
  let d = resp.data
  let rawList = (d.list ?? []) as TxAlbumSong[]
  let albumPic = `https://y.gtimg.cn/music/photo_new/T002R300x300M000${albumMid}.jpg`
  let list: SongInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let songMid = item.songmid ?? ''
    let pic = songMid.length > 0 ? txAlbumPic(songMid) : albumPic
    list.push(new SongInfo(songMid, item.songname ?? '', joinTxSingers(item.singer),
      item.albumname ?? '', item.interval ?? 0, pic))
  }
  let picUrl = `https://y.gtimg.cn/music/photo_new/T002R800x800M000${albumMid}.jpg`
  let info = new AlbumInfo(albumMid, albumMid, d.name ?? '', picUrl, 0, d.singername ?? '',
    d.total ?? rawList.length, d.aDate ?? '')
  return new AlbumDetailResult(info, list)
}

async function singerDetailData(artistMid: string, sort: number, sin: number, num: number): Promise<TxSingerData> {
  let param: Record<string, Object> = {
    'sort': sort,
    'singermid': artistMid,
    'sin': sin,
    'num': num,
  }
  let comm: TxSingerReqComm = { 'ct': 24, 'cv': 0 }
  let singer: TxSingerReqBody = { 'method': 'get_singer_detail_info', 'param': param, 'module': 'music.web_singer_info_svr' }
  let body: Record<string, Object> = {
    'comm': comm,
    'singer': singer,
  }
  let resp = await httpPostJson('https://u.y.qq.com/cgi-bin/musicu.fcg', body, buildTxHeaders()) as TxSingerDetailResp
  if (resp.code !== 0 || resp.singer === undefined || resp.singer.code !== 0 || resp.singer.data === undefined) {
    throw new Error('接口错误: code=' + resp.code)
  }
  return resp.singer.data
}

function mapTxSongs(rawList: TxRawSong[]): SongInfo[] {
  let list: SongInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let name = item.name ?? item.title ?? ''
    let albumName = item.album !== undefined ? (item.album.name ?? '') : ''
    let albumMid = item.album !== undefined ? (item.album.mid ?? '') : ''
    list.push(new SongInfo(item.mid ?? '', name, joinTxSingers(item.singer), albumName, item.interval ?? 0,
      txAlbumPic(albumMid)))
  }
  return list
}

function txAlbumPic(mid: string): string {
  if (mid.length === 0) {
    return ''
  }
  return `https://y.gtimg.cn/music/photo_new/T002R300x300M000${mid}.jpg`
}

function joinTxSingers(rawList: TxRawSongSinger[] | undefined): string {
  let names: string[] = []
  let list = rawList ?? []
  for (let i = 0; i < list.length; i++) {
    let name = list[i].name ?? ''
    if (name.length > 0) {
      names.push(name)
    }
  }
  return names.join('、')
}
