import { http } from '@kit.NetworkKit'
import { buildWeapiParams } from './Weapi'
import { ArtistInfo } from '../model/SearchModels'
import { SongInfo } from '../model/SearchModels'
import { SongPageResult } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { ArtistAlbumPageResult } from '../model/SearchModels'
import { AlbumDetailResult } from '../model/SearchModels'

function buildWyHeaders(): Record<string, string> {
  return {
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    'Origin': 'https://music.163.com',
    'Referer': 'https://music.163.com',
  }
}

async function wyPostForm(url: string, object: Object): Promise<Object> {
  let params = await buildWeapiParams(object)
  let form = 'params=' + encodeURIComponent(params.params) + '&encSecKey=' + encodeURIComponent(params.encSecKey)
  let httpRequest = http.createHttp()
  let response = await httpRequest.request(url, {
    method: http.RequestMethod.POST,
    header: buildWyHeaders(),
    extraData: form,
    connectTimeout: 15000,
    readTimeout: 15000,
  } as http.HttpRequestOptions)
  httpRequest.destroy()
  if (response.responseCode !== 200) {
    throw new Error('请求失败: HTTP ' + response.responseCode)
  }
  let body = response.result as string
  return JSON.parse(body) as Object
}

interface WyResponse {
  code: number
  data: WyArtistData | undefined
}

interface WyArtistData {
  artist: WyRawArtist | undefined
}

interface WyRawArtist {
  name: string | undefined
  alias: string[] | undefined
  briefDesc: string | undefined
  picUrl: string | undefined
  img1v1Url: string | undefined
  albumSize: number | undefined
  musicSize: number | undefined
}

interface WyArtistSongsResponse {
  code: number
  songs: WyRawSong[] | undefined
  total: number | undefined
  more: boolean | undefined
}

interface WyRawSong {
  id: number | undefined
  name: string | undefined
  ar: WyRawSongArtist[] | undefined
  al: WyRawSongAlbum | undefined
  dt: number | undefined
}

interface WyRawSongArtist {
  name: string | undefined
}

interface WyRawSongAlbum {
  name: string | undefined
  picUrl: string | undefined
}

interface WyArtistAlbumsResponse {
  code: number
  hotAlbums: WyRawAlbum[] | undefined
  more: boolean | undefined
}

interface WyRawAlbum {
  id: number | undefined
  name: string | undefined
  picUrl: string | undefined
  artist: WyRawAlbumArtist | undefined
  size: number | undefined
  publishTime: number | undefined
}

interface WyRawAlbumArtist {
  id: number | undefined
  name: string | undefined
}

interface WyAlbumResponse {
  code: number
  album: WyRawAlbum | undefined
  songs: WyRawSong[] | undefined
}

function joinSingerNames(rawList: WyRawSongArtist[] | undefined): string {
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

function mapWySongs(rawList: WyRawSong[]): SongInfo[] {
  let list: SongInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let albumName = item.al !== undefined ? (item.al.name ?? '') : ''
    let picUrl = item.al !== undefined ? (item.al.picUrl ?? '').replace('http://', 'https://') : ''
    list.push(new SongInfo(String(item.id ?? 0), item.name ?? '', joinSingerNames(item.ar), albumName,
      Math.floor((item.dt ?? 0) / 1000), picUrl))
  }
  return list
}

function mapWyAlbum(raw: WyRawAlbum): AlbumInfo {
  let artist = raw.artist
  let artistId = artist !== undefined ? (artist.id ?? 0) : 0
  let artistName = artist !== undefined ? (artist.name ?? '') : ''
  return new AlbumInfo(String(raw.id ?? 0), '', raw.name ?? '', raw.picUrl ?? '', artistId, artistName,
    raw.size ?? 0, String(raw.publishTime ?? 0))
}

export async function getArtistDetail(id: string): Promise<ArtistInfo> {
  let param: Record<string, string> = { 'id': id }
  let resp = await wyPostForm('https://music.163.com/weapi/artist/head/info/get', param) as WyResponse
  if (resp.code !== 200) throw new Error('获取歌手详情失败')
  let raw = resp.data?.artist
  if (raw === undefined) throw new Error('获取歌手详情失败')
  let alias = raw.alias !== undefined && raw.alias.length > 0 ? raw.alias[0] : ''
  let picUrl = raw.picUrl ?? raw.img1v1Url ?? ''
  return new ArtistInfo(id, '', raw.name ?? '', picUrl, alias, raw.albumSize ?? 0,
    raw.musicSize ?? 0, raw.briefDesc ?? '')
}

export async function getArtistSongs(id: string, order: string, limit: number, offset: number): Promise<SongPageResult> {
  let params: Record<string, string | number | boolean> = {
    'id': id,
    'private_cloud': 'true',
    'work_type': 1,
    'order': order,
    'offset': offset,
    'limit': limit,
  }
  let resp = await wyPostForm('https://music.163.com/weapi/v1/artist/songs', params) as WyArtistSongsResponse
  if (resp.code !== 200) throw new Error('获取歌手歌曲失败')
  let list = mapWySongs(resp.songs ?? [])
  let total = resp.total ?? 0
  let hasMore = resp.more ?? false
  return new SongPageResult(list, total, hasMore)
}

export async function getArtistAlbums(id: string, limit: number, offset: number): Promise<ArtistAlbumPageResult> {
  let params: Record<string, number | boolean> = { 'limit': limit, 'offset': offset, 'total': true }
  let resp = await wyPostForm('https://music.163.com/weapi/artist/albums/' + id, params) as WyArtistAlbumsResponse
  if (resp.code !== 200) throw new Error('获取歌手专辑失败')
  let rawList = resp.hotAlbums ?? []
  let list: AlbumInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    list.push(mapWyAlbum(rawList[i]))
  }
  return new ArtistAlbumPageResult(list, resp.more ?? false)
}

export async function getAlbum(albumId: string): Promise<AlbumDetailResult> {
  let empty: Record<string, string> = {}
  let resp = await wyPostForm('https://music.163.com/weapi/v1/album/' + albumId, empty) as WyAlbumResponse
  if (resp.code !== 200) throw new Error('获取专辑详情失败')
  let info = resp.album !== undefined ? mapWyAlbum(resp.album) : new AlbumInfo(albumId, '', '', '', 0, '', 0, '')
  let list = mapWySongs(resp.songs ?? [])
  return new AlbumDetailResult(info, list)
}