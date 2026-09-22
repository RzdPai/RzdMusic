import { SingerInfo } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { SearchPageResult } from '../model/SearchModels'
import { httpGetJson, MG_UA } from './HttpUtils'

interface MgSearchResponse {
  code: string
  data: MgSearchData | undefined
}

interface MgSearchData {
  hasNext: boolean
  items: MgSearchItem[] | undefined
}

interface MgSearchItem {
  singer: MgSinger | undefined
  dalbum: MgDalbum | undefined
  album: MgAlbum | undefined
}

interface MgAlbum {
  albumId: string | undefined
  title: string | undefined
  singer: string | undefined
  singerId: string | undefined
  totalCount: number | undefined
  publishDate: string | undefined
  imgItems: MgImg[] | undefined
}

interface MgSinger {
  singerId: string | undefined
  singer: string | undefined
  summary: string | undefined
  songNum: number | undefined
  albumNum: number | undefined
  imgs: MgImg[] | undefined
}

interface MgImg {
  img: string | undefined
  imgSizeType: string | undefined
}

interface MgDalbum {
  contentId: string | undefined
  title: string | undefined
  singer: string | undefined
  singerId: string | undefined
  totalCount: number | undefined
  publishDate: string | undefined
  imgItems: MgImg[] | undefined
}

function firstImg(imgs: MgImg[] | undefined): string {
  if (imgs === undefined || imgs.length === 0) return ''
  for (let i = 0; i < imgs.length; i++) {
    if (imgs[i].imgSizeType === '03') {
      return imgs[i].img ?? ''
    }
  }
  return imgs[imgs.length - 1].img ?? ''
}

export async function searchSinger(keyword: string, page: number): Promise<SearchPageResult<SingerInfo>> {
  let url = 'https://app.c.nf.migu.cn/bmw/search/singer/v2.0?pageNo=' + page + '&text=' + encodeURIComponent(keyword)
    let raw = await httpGetJson(url, { 'User-Agent': MG_UA }) as MgSearchResponse
  if (raw.code !== '000000') throw new Error('搜索失败')
  let data = raw.data
  if (data === undefined) throw new Error('搜索失败')
  let rawList = data.items ?? []
  let list: SingerInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i].singer
    if (item === undefined) continue
    let id = item.singerId ?? ''
    if (id.length === 0) continue
    let picUrl = firstImg(item.imgs).replace('http://', 'https://')
    list.push(new SingerInfo(id, item.singer ?? '', picUrl, '', item.albumNum ?? 0, item.songNum ?? 0))
  }
  let allPage = data.hasNext ? page + 1 : page
  return new SearchPageResult<SingerInfo>(list, allPage, list.length)
}

export async function searchAlbum(keyword: string, page: number): Promise<SearchPageResult<AlbumInfo>> {
  let url = 'https://app.c.nf.migu.cn/bmw/search/album/v1.0?pageNo=' + page + '&text=' + encodeURIComponent(keyword) + '&typeOrder=0'
    let raw = await httpGetJson(url, { 'User-Agent': MG_UA }) as MgSearchResponse
  if (raw.code !== '000000') throw new Error('搜索失败')
  let data = raw.data
  if (data === undefined) throw new Error('搜索失败')
  let rawList = data.items ?? []
  let list: AlbumInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let id = item.dalbum !== undefined ? (item.dalbum.contentId ?? '') : (item.album !== undefined ? (item.album.albumId ?? '') : '')
    if (id.length === 0) continue
    let title = item.dalbum !== undefined ? (item.dalbum.title ?? '') : (item.album !== undefined ? (item.album.title ?? '') : '')
    let singer = item.dalbum !== undefined ? (item.dalbum.singer ?? '') : (item.album !== undefined ? (item.album.singer ?? '') : '')
    let total = item.dalbum !== undefined ? (item.dalbum.totalCount ?? 0) : (item.album !== undefined ? (item.album.totalCount ?? 0) : 0)
    let publish = item.dalbum !== undefined ? (item.dalbum.publishDate ?? '') : (item.album !== undefined ? (item.album.publishDate ?? '') : '')
    let imgs = item.dalbum !== undefined ? (item.dalbum.imgItems ?? []) : (item.album !== undefined ? (item.album.imgItems ?? []) : [])
    let picUrl = firstImg(imgs).replace('http://', 'https://')
    list.push(new AlbumInfo(id, '', title, picUrl, 0, singer, total, publish))
  }
  let allPage = data.hasNext ? page + 1 : page
  return new SearchPageResult<AlbumInfo>(list, allPage, list.length)
}