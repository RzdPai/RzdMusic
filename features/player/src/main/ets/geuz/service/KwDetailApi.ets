import { http } from '@kit.NetworkKit'
import { ArtistInfo } from '../model/SearchModels'
import { SongInfo } from '../model/SearchModels'
import { SongPageResult } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { ArtistAlbumPageResult } from '../model/SearchModels'
import { AlbumDetailResult } from '../model/SearchModels'
import { kwGet } from './KwRequest'
import { cleanText } from './HttpUtils'

const KW_UA = 'Mozilla/5.0 (Linux; Android 12)'
const KW_REFERER = 'http://www.kuwo.cn/'
const PAGE_SIZE: number = 50

function buildUrl(ft: string, keyword: string, artistId: string, page: number, rn: number): string {
  let url = 'http://search.kuwo.cn/r.s?ft=' + ft
  if (keyword.length > 0) {
    url = url + '&all=' + encodeURIComponent(keyword)
  }
  if (artistId.length > 0) {
    url = url + '&artistid=' + artistId
  }
  return url + '&pn=' + (page - 1) + '&rn=' + rn +
    '&rformat=json&encoding=utf8&vipver=MUSIC_8.7.7.0_BCS37&plat=pc&devid=28156413&pay=0&needliveshow=0'
}

function toStandardJson(text: string): string {
  let out = ''
  let i = 0
  while (i < text.length) {
    let ch = text.charAt(i)
    if (ch === '\\' && i + 1 < text.length && text.charAt(i + 1) === '\'') {
      out = out + '"'
      i = i + 2
      continue
    }
    if (ch === '\'') {
      out = out + '"'
    } else {
      out = out + ch
    }
    i = i + 1
  }
  return out
}

async function httpGetText(url: string): Promise<string> {
  let headers: Record<string, string> = {
    'User-Agent': KW_UA,
    'Referer': KW_REFERER,
  }
  let httpRequest = http.createHttp()
  let response = await httpRequest.request(url, {
    method: http.RequestMethod.GET,
    header: headers,
    connectTimeout: 15000,
    readTimeout: 15000,
  } as http.HttpRequestOptions)
  httpRequest.destroy()
  if (response.responseCode !== 200) {
    throw new Error('请求失败: HTTP ' + response.responseCode)
  }
  return response.result as string
}

interface KwArtistRoot {
  abslist: KwArtistItem[] | undefined
}

interface KwArtistItem {
  ARTISTID: string | undefined
  ARTIST: string | undefined
  AARTIST: string | undefined
  hts_PICPATH: string | undefined
  ALBUMNUM: string | undefined
  SONGNUM: string | undefined
  desc: string | undefined
}

interface KwAlbumDetailResponse {
  code: number
  data: KwAlbumDetailData | undefined
}

interface KwAlbumDetailData {
  total: string | undefined
  albumList: KwAlbumInfoItem[] | undefined
  musicList: KwArtistMusicItem[] | undefined
  album: string | undefined
  artist: string | undefined
  artistid: number | undefined
  releaseDate: string | undefined
  pic: string | undefined
}

interface KwAlbumInfoItem {
  albumid: number | undefined
  album: string | undefined
  artist: string | undefined
  artistid: number | undefined
  pic: string | undefined
  releaseDate: string | undefined
}

export async function getArtistDetail(artistId: string): Promise<ArtistInfo> {
  let albumP = fetchArtistAlbumCount(artistId)
  let songP = fetchArtistSongCount(artistId)
  let descP = fetchArtistDesc(artistId)
  let albumNum = await albumP
  let songNum = await songP
  let desc = ''
  try {
    desc = await descP
  } catch (e) {
  }
  return new ArtistInfo(artistId, '', '', '', '', albumNum, songNum, desc)
}

async function fetchArtistAlbumCount(artistId: string): Promise<number> {
  let url = 'http://www.kuwo.cn/api/www/artist/artistAlbum?artistid=' + artistId + '&pn=1&rn=1&httpsStatus=1'
  let raw = await kwGet(url, 'http://www.kuwo.cn/singer_detail/' + encodeURIComponent(artistId) + '/album') as KwAlbumDetailResponse
  if (raw.code !== 200) return 0
  let data = raw.data
  if (data === undefined) return 0
  return Number(data.total ?? 0)
}

async function fetchArtistSongCount(artistId: string): Promise<number> {
  let url = 'http://www.kuwo.cn/api/www/artist/artistMusic?artistid=' + artistId + '&pn=1&rn=1&httpsStatus=1'
  let raw = await kwGet(url, 'http://www.kuwo.cn/singer_detail/' + encodeURIComponent(artistId)) as KwArtistMusicResponse
  if (raw.code !== 200) return 0
  let data = raw.data
  if (data === undefined) return 0
  return Number(data.total ?? 0)
}

async function fetchArtistDesc(artistId: string): Promise<string> {
  let url = buildUrl('artist', '', artistId, 1, 1)
  let text = await httpGetText(url)
  if (text.length === 0) return ''
  let root = JSON.parse(toStandardJson(text)) as KwArtistRoot
  let item = root.abslist !== undefined && root.abslist.length > 0 ? root.abslist[0] : undefined
  if (item === undefined) return ''
  return cleanText(item.desc ?? '')
}

interface KwArtistMusicResponse {
  code: number
  data: KwArtistMusicData | undefined
}

interface KwArtistMusicData {
  total: string | undefined
  list: KwArtistMusicItem[] | undefined
}

interface KwArtistMusicItem {
  rid: number | undefined
  name: string | undefined
  artist: string | undefined
  album: string | undefined
  duration: number | undefined
  pic: string | undefined
}

export async function getArtistSongs(artistId: string, order: string, limit: number, offset: number,
  artistName: string = ''): Promise<SongPageResult> {
  let page = Math.floor(offset / limit) + 1
  let url = 'http://www.kuwo.cn/api/www/artist/artistMusic?artistid=' + artistId +
    '&pn=' + page + '&rn=' + limit + '&httpsStatus=1'
  let raw = await kwGet(url, 'http://www.kuwo.cn/singer_detail/' + encodeURIComponent(artistId)) as KwArtistMusicResponse
  if (raw.code !== 200) throw new Error('获取歌手歌曲失败: code=' + raw.code)
  let data = raw.data
  if (data === undefined) throw new Error('获取歌手歌曲失败')
  let rawList = data.list ?? []
  let list: SongInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let id = item.rid ?? 0
    if (id === 0) continue
    let pic = (item.pic ?? '').replace('http://', 'https://')
    list.push(new SongInfo(String(id), cleanText(item.name ?? ''), cleanText(item.artist ?? ''),
      cleanText(item.album ?? ''), item.duration ?? 0, pic))
  }
  let total = Number(data.total ?? 0)
  return new SongPageResult(list, total, offset + limit < total)
}

export async function getArtistAlbums(artistId: string, limit: number,
  offset: number): Promise<ArtistAlbumPageResult> {
  let page = Math.floor(offset / limit) + 1
  return artistAlbumsNew(artistId, page, limit, offset)
}

async function artistAlbumsNew(artistId: string, page: number, limit: number,
  offset: number): Promise<ArtistAlbumPageResult> {
  let url = 'http://www.kuwo.cn/api/www/artist/artistAlbum?artistid=' + artistId +
    '&pn=' + page + '&rn=' + limit + '&httpsStatus=1'
  let raw = await kwGet(url, 'http://www.kuwo.cn/singer_detail/' + encodeURIComponent(artistId) + '/album') as KwAlbumDetailResponse
  if (raw.code !== 200) throw new Error('获取歌手专辑失败')
  let data = raw.data
  if (data === undefined) throw new Error('获取歌手专辑失败')
  let rawList = data.albumList ?? []
  let list: AlbumInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let id = item.albumid ?? 0
    if (id === 0) continue
    let picUrl = (item.pic ?? '').replace('http://', 'https://')
    list.push(new AlbumInfo(String(id), '', cleanText(item.album ?? ''), picUrl, item.artistid ?? 0,
      cleanText(item.artist ?? ''), 0, item.releaseDate ?? ''))
  }
  let total = Number(data.total ?? 0)
  return new ArtistAlbumPageResult(list, offset + limit < total)
}

export async function getAlbum(albumId: string, albumName: string = ''): Promise<AlbumDetailResult> {
  let url = 'http://www.kuwo.cn/api/www/album/albumInfo?albumId=' + albumId +
    '&pn=1&rn=1000&httpsStatus=1'
  let raw = await kwGet(url) as KwAlbumDetailResponse
  if (raw.code !== 200) throw new Error('获取专辑失败')
  let data = raw.data
  if (data === undefined) throw new Error('获取专辑失败')
  let rawList = data.musicList ?? []
  let albumPic = (data.pic ?? '').replace(new RegExp('/albumcover/\\d+/'), '/albumcover/500/')
  let list: SongInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let id = item.rid ?? 0
    if (id === 0) continue
    let pic = (item.pic ?? '').replace('http://', 'https://')
    if (pic.length === 0) {
      pic = albumPic
    }
    list.push(new SongInfo(String(id), cleanText(item.name ?? ''), cleanText(item.artist ?? ''),
      cleanText(item.album ?? ''), item.duration ?? 0, pic))
  }
  let total = Number(data.total ?? 0)
  let size = total > 0 ? total : list.length
  let picUrl = (data.pic ?? '').replace(new RegExp('/albumcover/\\d+/'), '/albumcover/1080/')
  let info = new AlbumInfo(albumId, '', cleanText(data.album ?? ''), picUrl,
    data.artistid ?? 0, cleanText(data.artist ?? ''), size, data.releaseDate ?? '')
  return new AlbumDetailResult(info, list)
}
