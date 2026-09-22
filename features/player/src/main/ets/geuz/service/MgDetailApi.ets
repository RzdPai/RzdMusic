import { ArtistInfo } from '../model/SearchModels'
import { SongInfo } from '../model/SearchModels'
import { SongPageResult } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { ArtistAlbumPageResult } from '../model/SearchModels'
import { AlbumDetailResult } from '../model/SearchModels'
import { httpGetJson, MG_UA } from './HttpUtils'

interface MgBaseResponse {
  code: string
  data: Object | undefined
}

interface MgContentBlock {
  view: string | undefined
  contents: MgContentBlock[] | undefined
  songItem: MgSongItem | undefined
  txt2: string | undefined
  resId: string | undefined
  img: string | undefined
  txt: string | undefined
  txt3: string | undefined
}

interface MgSongItem {
  songName: string | undefined
  contentId: string | undefined
  duration: number | undefined
  album: string | undefined
  singerList: MgSongSinger[] | undefined
  img1: string | undefined
  img2: string | undefined
  img3: string | undefined
}

interface MgSongSinger {
  name: string | undefined
}

interface MgContentData {
  header: Object | undefined
  contents: MgContentBlock[] | undefined
}

interface MgAlbumInfoResponse {
  code: string
  data: MgAlbumInfoData | undefined
}

interface MgAlbumInfoData {
  title: string | undefined
  singer: string | undefined
  singerId: string | undefined
  publishDate: string | undefined
  totalCount: number | undefined
  imgItem: MgImg[] | undefined
}

interface MgImg {
  img: string | undefined
  imgSizeType: string | undefined
}

function pickLargeImg(imgs: MgImg[]): string {
  if (imgs.length === 0) return ''
  for (let i = 0; i < imgs.length; i++) {
    if (imgs[i].imgSizeType === '03') {
      return imgs[i].img ?? ''
    }
  }
  return imgs[imgs.length - 1].img ?? ''
}

function mgCover(img1: string | undefined, img2: string | undefined, img3: string | undefined): string {
  let img = img3 ?? ''
  if (img.length === 0) {
    img = img2 ?? ''
  }
  if (img.length === 0) {
    img = img1 ?? ''
  }
  if (img.startsWith('/')) {
    img = 'https://d.musicapp.migu.cn' + img
  }
  return img.replace('http://', 'https://')
}

interface MgAlbumSongResponse {
  code: string
  data: MgAlbumSongData | undefined
}

interface MgAlbumSongData {
  songList: MgSongItem[] | undefined
  totalCount: number | undefined
}

interface MgSingerIndexResponse {
  code: string
  data: MgSingerIndexData | undefined
}

interface MgSingerIndexData {
  contents: MgContentBlock[] | undefined
}

function findDesc(contents: MgContentBlock[] | undefined): string {
  if (contents === undefined) return ''
  for (let i = 0; i < contents.length; i++) {
    let block = contents[i]
    if (block.view === 'ZJ-Singer-Intro-Scroll') {
      let inner = block.contents ?? []
      for (let j = 0; j < inner.length; j++) {
        if (inner[j].view === 'ZJ-Singer-Intro-Item') {
          return inner[j].txt2 ?? ''
        }
      }
    }
  }
  return ''
}

function findSongItems(contents: MgContentBlock[] | undefined): MgSongItem[] {
  let list: MgSongItem[] = []
  if (contents === undefined) return list
  for (let i = 0; i < contents.length; i++) {
    let block = contents[i]
    if (block.view === 'ZJ-Singer-Song-Scroll') {
      let inner = block.contents ?? []
      for (let j = 0; j < inner.length; j++) {
        let item = inner[j].songItem
        if (item !== undefined && (item.songName ?? '').length > 0) {
          list.push(item)
        }
      }
    }
  }
  return list
}

function mapMgSongs(rawList: MgSongItem[]): SongInfo[] {
  let list: SongInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let albumName = item.album ?? ''
    let author = ''
    if (item.singerList !== undefined && item.singerList.length > 0) {
      author = item.singerList[0].name ?? ''
    }
    let interval = item.duration ?? 0
    let pic = mgCover(item.img1, item.img2, item.img3)
    list.push(new SongInfo(item.contentId ?? String(i), item.songName ?? '', author, albumName, interval, pic))
  }
  return list
}

export async function getArtistDetail(singerId: string): Promise<ArtistInfo> {
  let url = 'https://app.c.nf.migu.cn/bmw/singer/index/v1.0?singerId=' + singerId
  let raw = await httpGetJson(url, { 'User-Agent': MG_UA }) as MgSingerIndexResponse
  if (raw.code !== '000000') throw new Error('获取歌手信息失败')
  let data = raw.data
  if (data === undefined) throw new Error('获取歌手信息失败')
  let desc = findDesc(data.contents)
  return new ArtistInfo(singerId, '', '', '', '', 0, 0, desc)
}

export async function getArtistSongs(singerId: string, order: string, limit: number, offset: number): Promise<SongPageResult> {
  let page = Math.floor(offset / limit) + 1
  let url = 'https://app.c.nf.migu.cn/bmw/singer/song/v1.0?pageNo=' + page + '&singerId=' + singerId + '&type=1'
  let raw = await httpGetJson(url, { 'User-Agent': MG_UA }) as MgBaseResponse
  if (raw.code !== '000000') throw new Error('获取歌手歌曲列表失败')
  let contentData = raw.data as MgContentData
  let items = findSongItems(contentData.contents)
  let list = mapMgSongs(items)
  return new SongPageResult(list, list.length, list.length >= limit)
}

async function getMgAlbumCount(id: string, retryNum: number = 0): Promise<number> {
  if (retryNum > 2 || id.length === 0) return 0
  try {
    let raw = await httpGetJson('https://app.c.nf.migu.cn/MIGUM3.0/resource/dalbum/v2.0?dAlbumId=' + id, { 'User-Agent': MG_UA }) as MgAlbumInfoResponse
    if (raw.code === '000000' && raw.data !== undefined) {
      let total = raw.data.totalCount ?? 0
      if (total > 0) return total
    }
    let raw2 = await httpGetJson('https://app.c.nf.migu.cn/MIGUM3.0/resource/album/song/v2.0?albumId=' + id + '&pageNo=1', { 'User-Agent': MG_UA }) as MgAlbumSongResponse
    if (raw2.code === '000000' && raw2.data !== undefined) {
      let total = raw2.data.totalCount ?? 0
      if (total > 0) return total
    }
    return getMgAlbumCount(id, retryNum + 1)
  } catch (e) {
    return getMgAlbumCount(id, retryNum + 1)
  }
}

export async function getArtistAlbums(singerId: string, limit: number, offset: number): Promise<ArtistAlbumPageResult> {
  let page = Math.floor(offset / limit) + 1
  let url = 'https://app.c.nf.migu.cn/bmw/singer/album/v1.0?singerId=' + singerId + '&pageNo=' + page
  let raw = await httpGetJson(url, { 'User-Agent': MG_UA }) as MgBaseResponse
  if (raw.code !== '000000') throw new Error('获取歌手专辑列表失败')
  let contentData = raw.data as MgContentData
  let list: AlbumInfo[] = []
  let blocks = contentData.contents ?? []
  for (let i = 0; i < blocks.length; i++) {
    let item = blocks[i]
    let id = item.resId ?? ''
    if (id.length === 0) continue
    let picUrl = (item.img ?? '').replace('http://', 'https://')
    list.push(new AlbumInfo(id, '', item.txt ?? '', picUrl, 0, item.txt2 ?? '', 0, item.txt3 ?? ''))
  }
  let hasMore = false
  if (contentData.header !== undefined) {
    let hdr = contentData.header as Record<string, Object>
    let nextUrl = hdr['nextPageUrl'] as string
    if (nextUrl !== undefined && nextUrl.length > 0) {
      hasMore = true
    }
  }
  if (list.length > 0) {
    let toFetch = list.length > 30 ? list.slice(0, 30) : list
    let promises: Promise<number>[] = []
    for (let i = 0; i < toFetch.length; i++) {
      promises.push(getMgAlbumCount(toFetch[i].id))
    }
    let counts = await Promise.all(promises)
    for (let i = 0; i < toFetch.length; i++) {
      toFetch[i].size = counts[i]
    }
  }
  return new ArtistAlbumPageResult(list, hasMore)
}

export async function getAlbum(albumId: string): Promise<AlbumDetailResult> {
  let infoUrl = 'https://app.c.nf.migu.cn/MIGUM3.0/resource/dalbum/v2.0?dAlbumId=' + albumId
  let infoRaw = await httpGetJson(infoUrl, { 'User-Agent': MG_UA }) as MgAlbumInfoResponse
  if (infoRaw.code !== '000000') throw new Error('获取专辑信息失败')
  let infoData = infoRaw.data
  let name = ''
  let picUrl = ''
  let authorName = ''
  let publishDate = ''
  let total = 0
  if (infoData !== undefined) {
    name = infoData.title ?? ''
    let imgs = infoData.imgItem ?? []
    if (imgs.length > 0) {
      picUrl = pickLargeImg(imgs).replace('http://', 'https://')
    }
    authorName = infoData.singer ?? ''
    publishDate = infoData.publishDate ?? ''
    total = infoData.totalCount ?? 0
  }

  let songUrl = 'https://app.c.nf.migu.cn/MIGUM3.0/resource/dalbum/song/v2.0?dAlbumId=' + albumId
  let songRaw = await httpGetJson(songUrl, { 'User-Agent': MG_UA }) as MgAlbumSongResponse
  if (songRaw.code !== '000000') throw new Error('获取专辑歌曲失败')
  let songData = songRaw.data
  let list = songData !== undefined ? mapMgSongs(songData.songList ?? []) : []
  if (picUrl.length > 0) {
    for (let i = 0; i < list.length; i++) {
      if (list[i].picUrl.length === 0) {
        list[i].picUrl = picUrl
      }
    }
  }
  let size = total > 0 ? total : list.length
  let info = new AlbumInfo(albumId, '', name, picUrl, 0, authorName, size, publishDate)
  return new AlbumDetailResult(info, list)
}