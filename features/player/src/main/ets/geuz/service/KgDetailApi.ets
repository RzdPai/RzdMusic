import { ArtistInfo } from '../model/SearchModels'
import { SongInfo } from '../model/SearchModels'
import { SongPageResult } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { ArtistAlbumPageResult } from '../model/SearchModels'
import { AlbumDetailResult } from '../model/SearchModels'
import { kgArtistDetail, kgArtistSongs, kgArtistAlbums, kgAlbumDetail, kgAlbumSongs } from './KgGateway'

interface KgGwArtistResponse {
  status: number
  error_code: number
  data: KgGwArtistData | undefined
}

interface KgGwArtistData {
  author_name: string | undefined
  album_count: number | undefined
  song_count: number | undefined
  audio_count: number | undefined
  sizable_avatar: string | undefined
  intro: string | undefined
  long_intro: KgGwLongIntro[] | undefined
}

interface KgGwLongIntro {
  content: string | undefined
}

interface KgGwSongsResponse {
  status: number
  error_code: number
  data: KgGwSongsData | undefined
}

interface KgGwSongsData {
  songs: KgGwSong[] | undefined
  total: number | undefined
}

interface KgGwSong {
  audio_name: string | undefined
  author_name: string | undefined
  album_id: number | undefined
  album_name: string | undefined
  audio_id: number | undefined
  audio_info: KgGwAudioInfo | undefined
  base: KgGwSongBase | undefined
  album_info: KgGwSongAlbumInfo | undefined
  authors: KgGwAlbumAuthor[] | undefined
}

interface KgGwSongBase {
  audio_id: number | undefined
  audio_name: string | undefined
  author_name: string | undefined
}

interface KgGwSongAlbumInfo {
  album_name: string | undefined
  cover: string | undefined
  sizable_cover: string | undefined
}

interface KgGwAudioInfo {
  timelength: number | undefined
  duration: number | undefined
  hash: string | undefined
}

interface KgGwAlbumsResponse {
  total: number | undefined
  error_code: number
  data: KgGwAlbum[] | undefined
}

interface KgGwAlbumDetailResponse {
  status: number
  error_code: number
  data: KgGwAlbum[] | undefined
}

interface KgGwAlbum {
  album_id: number | undefined
  album_name: string | undefined
  sizable_cover: string | undefined
  publish_date: string | undefined
  intro: string | undefined
  authors: KgGwAlbumAuthor[] | undefined
}

interface KgGwAlbumAuthor {
  author_name: string | undefined
}

interface KgGwAlbumSongsResponse {
  total: number | undefined
  error_code: number
  data: KgGwSongsData | undefined
}

export async function getArtistDetail(singerid: string): Promise<ArtistInfo> {
  let raw = await kgArtistDetail(singerid) as KgGwArtistResponse
  if (raw.status !== 1 || raw.error_code !== 0) throw new Error('获取歌手信息失败')
  let data = raw.data
  if (data === undefined) throw new Error('获取歌手信息失败')
  let img = data.sizable_avatar ?? ''
  let picUrl = img.replace('{size}', '1080').replace('http://', 'https://')
  let desc = ''
  if (data.long_intro !== undefined && data.long_intro.length > 0) {
    desc = data.long_intro[0].content ?? ''
  }
  if (desc.length === 0) {
    desc = data.intro ?? ''
  }
  return new ArtistInfo(singerid, '', data.author_name ?? '', picUrl, '', data.album_count ?? 0,
    data.song_count ?? data.audio_count ?? 0, desc)
}

function mapGwSongs(rawList: KgGwSong[]): SongInfo[] {
  let list: SongInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let name = item.audio_name ?? ''
    let author = item.author_name ?? ''
    let albumName = item.album_name ?? ''
    let audioId = item.audio_id ?? 0
    let base = item.base
    if (base !== undefined) {
      if (name.length === 0) name = base.audio_name ?? ''
      if (author.length === 0) author = base.author_name ?? ''
      if (audioId === 0) audioId = base.audio_id ?? 0
    }
    if (albumName.length === 0 && item.album_info !== undefined) {
      albumName = item.album_info.album_name ?? ''
    }
    let pic = ''
    if (item.album_info !== undefined) {
      pic = item.album_info.cover ?? ''
      if (pic.length === 0) {
        pic = item.album_info.sizable_cover ?? ''
      }
      pic = pic.replace('{size}', '240').replace('http://', 'https://')
    }
    if (author.length === 0 && item.authors !== undefined && item.authors.length > 0) {
      author = item.authors[0].author_name ?? ''
    }
    let interval = 0
    let audioInfo = item.audio_info
    let hash = ''
    if (audioInfo !== undefined) {
      hash = audioInfo.hash ?? ''
      let ms = audioInfo.timelength ?? 0
      if (ms <= 0) ms = audioInfo.duration ?? 0
      if (ms > 0) {
        interval = Math.floor(ms / 1000)
      }
    }
    let id = hash.length > 0 ? hash : String(audioId > 0 ? audioId : i)
    list.push(new SongInfo(id, name, author, albumName, interval, pic))
  }
  return list
}

export async function getArtistSongs(singerid: string, order: string, limit: number, offset: number): Promise<SongPageResult> {
  let page = Math.floor(offset / limit) + 1
  let sort = order === 'hot' ? 1 : 2
  let raw = await kgArtistSongs(singerid, page, limit, sort) as KgGwSongsResponse
  if (raw.status !== 1 || raw.error_code !== 0) throw new Error('获取歌手歌曲列表失败')
  let data = raw.data
  if (data === undefined) throw new Error('获取歌手歌曲列表失败')
  let list = mapGwSongs(data.songs ?? [])
  let total = data.total ?? 0
  return new SongPageResult(list, total, offset + limit < total)
}

async function getAlbumSongCount(id: string, retryNum: number = 0): Promise<number> {
  if (retryNum > 2 || id.length === 0) return 0
  try {
    let raw = await kgAlbumSongs(id, 1, 1) as KgGwAlbumSongsResponse
    if (raw.error_code !== 0) return getAlbumSongCount(id, retryNum + 1)
    let total = raw.total ?? 0
    if (total > 0) return total
    return getAlbumSongCount(id, retryNum + 1)
  } catch (e) {
    return getAlbumSongCount(id, retryNum + 1)
  }
}

export async function getArtistAlbums(singerid: string, limit: number, offset: number): Promise<ArtistAlbumPageResult> {
  let page = Math.floor(offset / limit) + 1
  let raw = await kgArtistAlbums(singerid, page, limit, 1) as KgGwAlbumsResponse
  if (raw.error_code !== 0) throw new Error('获取歌手专辑列表失败')
  let rawList = raw.data ?? []
  let list: AlbumInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let id = item.album_id ?? 0
    if (id === 0) continue
    let img = item.sizable_cover ?? ''
    let picUrl = img.replace('{size}', '480').replace('http://', 'https://')
    let authorName = ''
    if (item.authors !== undefined && item.authors.length > 0) {
      authorName = item.authors[0].author_name ?? ''
    }
    list.push(new AlbumInfo(String(id), '', item.album_name ?? '', picUrl, 0, authorName, 0,
      item.publish_date ?? ''))
  }
  if (list.length === 0) {
    let total = raw.total ?? 0
    let hasMore = total > 0 ? offset + limit < total : rawList.length > 0
    return new ArtistAlbumPageResult(list, hasMore)
  }
  let toFetch = list.length > 30 ? list.slice(0, 30) : list
  let promises: Promise<number>[] = []
  for (let i = 0; i < toFetch.length; i++) {
    promises.push(getAlbumSongCount(toFetch[i].id))
  }
  let counts = await Promise.all(promises)
  for (let i = 0; i < toFetch.length; i++) {
    toFetch[i].size = counts[i]
  }
  let total = raw.total ?? 0
  let hasMore = total > 0 ? offset + limit < total : rawList.length > 0
  return new ArtistAlbumPageResult(list, hasMore)
}

export async function getAlbum(id: string): Promise<AlbumDetailResult> {
  let detailRaw = await kgAlbumDetail(id) as KgGwAlbumDetailResponse
  if (detailRaw.status !== 1 || detailRaw.error_code !== 0) throw new Error('获取专辑信息失败')
  let rawList = detailRaw.data ?? []
  let name = ''
  let picUrl = ''
  let authorName = ''
  let publishDate = ''
  if (rawList.length > 0) {
    let item = rawList[0]
    name = item.album_name ?? ''
    let img = item.sizable_cover ?? ''
    picUrl = img.replace('{size}', '1080').replace('http://', 'https://')
    if (item.authors !== undefined && item.authors.length > 0) {
      authorName = item.authors[0].author_name ?? ''
    }
    publishDate = item.publish_date ?? ''
  }

  let songsRaw = await kgAlbumSongs(id, 1, 50) as KgGwAlbumSongsResponse
  if (songsRaw.error_code !== 0) throw new Error('获取专辑歌曲失败')
  let songsData = songsRaw.data
  let list = songsData !== undefined ? mapGwSongs(songsData.songs ?? []) : []
  let total = songsRaw.total ?? 0
  let page = 2
  while (list.length < total && page <= 4) {
    let moreRaw = await kgAlbumSongs(id, page, 50) as KgGwAlbumSongsResponse
    if (moreRaw.error_code !== 0) break
    let moreData = moreRaw.data
    let moreList = moreData !== undefined ? mapGwSongs(moreData.songs ?? []) : []
    if (moreList.length === 0) break
    list = list.concat(moreList)
    page++
  }
  let size = total > 0 ? total : list.length
  let info = new AlbumInfo(id, '', name, picUrl, 0, authorName, size, publishDate)
  return new AlbumDetailResult(info, list)
}