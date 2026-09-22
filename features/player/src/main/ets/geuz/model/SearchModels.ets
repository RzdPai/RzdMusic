export class SingerInfo {
  id: string = ''
  name: string = ''
  picUrl: string = ''
  alias: string = ''
  albumSize: number = 0
  songNum: number = 0

  constructor(id: string, name: string, picUrl: string, alias: string, albumSize: number, songNum: number = 0) {
    this.id = id
    this.name = name
    this.picUrl = picUrl
    this.alias = alias
    this.albumSize = albumSize
    this.songNum = songNum
  }
}

export class AlbumInfo {
  id: string = ''
  mid: string = ''
  name: string = ''
  picUrl: string = ''
  artistId: number = 0
  artistName: string = ''
  size: number = 0
  publishTime: string = ''

  constructor(id: string, mid: string, name: string, picUrl: string, artistId: number, artistName: string,
    size: number, publishTime: string) {
    this.id = id
    this.mid = mid
    this.name = name
    this.picUrl = picUrl
    this.artistId = artistId
    this.artistName = artistName
    this.size = size
    this.publishTime = publishTime
  }
}

export class SearchPageResult<T> {
  list: T[] = []
  allPage: number = 0
  total: number = 0

  constructor(list: T[], allPage: number, total: number) {
    this.list = list
    this.allPage = allPage
    this.total = total
  }
}

export interface CloudSearchResponse {
  code: number
  result: CloudSearchResult | undefined
}

export interface CloudSearchResult {
  artists: RawArtist[] | undefined
  albums: RawAlbum[] | undefined
  artistCount: number
  albumCount: number
}

export interface RawArtist {
  id: number | undefined
  name: string | undefined
  picUrl: string | undefined
  alias: string[] | undefined
  albumSize: number | undefined
  musicSize: number | undefined
}

export interface RawAlbumArtist {
  id: number | undefined
  name: string | undefined
}

export interface RawAlbum {
  id: number | undefined
  name: string | undefined
  picUrl: string | undefined
  artist: RawAlbumArtist | undefined
  size: number | undefined
  publishTime: number | undefined
}

export function rawToSingerList(raw: CloudSearchResponse): SingerInfo[] {
  let source: RawArtist[] | undefined = raw.result?.artists
  let list: SingerInfo[] = []
  if (source !== undefined) {
    for (let i = 0; i < source.length; i++) {
      let item = source[i]
      let alias = item.alias !== undefined && item.alias.length > 0 ? item.alias[0] : ''
      list.push(new SingerInfo(String(item.id ?? 0), item.name ?? '', item.picUrl ?? '', alias,
        item.albumSize ?? 0, item.musicSize ?? 0))
    }
  }
  return list
}

export function rawToAlbumList(raw: CloudSearchResponse): AlbumInfo[] {
  let source: RawAlbum[] | undefined = raw.result?.albums
  let list: AlbumInfo[] = []
  if (source !== undefined) {
    for (let i = 0; i < source.length; i++) {
      let item = source[i]
      let artistId = item.artist !== undefined ? (item.artist.id ?? 0) : 0
      let artistName = item.artist !== undefined ? (item.artist.name ?? '') : ''
      list.push(new AlbumInfo(String(item.id ?? 0), '', item.name ?? '', item.picUrl ?? '', artistId, artistName,
        item.size ?? 0, String(item.publishTime ?? 0)))
    }
  }
  return list
}

export function rawToArtistCount(raw: CloudSearchResponse): number {
  return raw.result?.artistCount ?? 0
}

export function rawToAlbumCount(raw: CloudSearchResponse): number {
  return raw.result?.albumCount ?? 0
}

export class ArtistInfo {
  id: string = ''
  mid: string = ''
  name: string = ''
  picUrl: string = ''
  alias: string = ''
  albumSize: number = 0
  songNum: number = 0
  briefDesc: string = ''

  constructor(id: string, mid: string, name: string, picUrl: string, alias: string, albumSize: number,
    songNum: number, briefDesc: string) {
    this.id = id
    this.mid = mid
    this.name = name
    this.picUrl = picUrl
    this.alias = alias
    this.albumSize = albumSize
    this.songNum = songNum
    this.briefDesc = briefDesc
  }
}

export class SongInfo {
  id: string = ''
  name: string = ''
  singer: string = ''
  albumName: string = ''
  interval: number = 0
  picUrl: string = ''

  constructor(id: string, name: string, singer: string, albumName: string, interval: number, picUrl: string = '') {
    this.id = id
    this.name = name
    this.singer = singer
    this.albumName = albumName
    this.interval = interval
    this.picUrl = picUrl
  }
}

export class SongPageResult {
  list: SongInfo[] = []
  total: number = 0
  hasMore: boolean = false

  constructor(list: SongInfo[], total: number, hasMore: boolean) {
    this.list = list
    this.total = total
    this.hasMore = hasMore
  }
}

export class ArtistAlbumPageResult {
  list: AlbumInfo[] = []
  hasMore: boolean = false

  constructor(list: AlbumInfo[], hasMore: boolean) {
    this.list = list
    this.hasMore = hasMore
  }
}

export class AlbumDetailResult {
  info: AlbumInfo = new AlbumInfo('', '', '', '', 0, '', 0, '')
  list: SongInfo[] = []

  constructor(info: AlbumInfo, list: SongInfo[]) {
    this.info = info
    this.list = list
  }
}

export interface ArtistDetailParams {
  source: number
  id: string
  mid: string
  name: string
  picUrl: string
  albumSize: number
  songNum: number
}

export interface AlbumDetailParams {
  source: number
  id: string
  mid: string
  name: string
  picUrl: string
  artistName: string
  publishTime: string
  size: number
}

export function formatInterval(seconds: number): string {
  let s = seconds > 0 ? seconds : 0
  let m = Math.floor(s / 60)
  let r = s % 60
  let rs = r < 10 ? '0' + r : '' + r
  return m + ':' + rs
}

export function formatPublishTime(value: string): string {
  if (value.length === 0) return ''
  let num = Number(value)
  if (value.match(new RegExp('^\\d+$')) !== null && !Number.isNaN(num)) {
    let ms = num > 100000000000 ? num : num * 1000
    let d = new Date(ms)
    return d.getFullYear() + '.' + (d.getMonth() + 1) + '.' + d.getDate()
  }
  return value
}