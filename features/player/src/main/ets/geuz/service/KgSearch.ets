import { SingerInfo } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { SearchPageResult } from '../model/SearchModels'
import { kgSearchSinger, kgSearchAlbum } from './KgGateway'

interface KgGwSearchResponse {
  status: number
  error_code: number
  data: KgGwSearchData | undefined
}

interface KgGwSearchData {
  lists: KgGwSearchItem[] | undefined
  total: number | undefined
}

interface KgGwSearchItem {
  AuthorId: number | undefined
  AuthorName: string | undefined
  Avatar: string | undefined
  AlbumCount: number | undefined
  AudioCount: number | undefined
  albumid: number | undefined
  albumname: string | undefined
  singer: string | undefined
  img: string | undefined
  publish_time: string | undefined
  songcount: number | undefined
}

export async function searchSinger(keyword: string, page: number): Promise<SearchPageResult<SingerInfo>> {
  let raw = await kgSearchSinger(keyword, page) as KgGwSearchResponse
  if (raw.status !== 1 || raw.error_code !== 0) throw new Error('搜索失败')
  let data = raw.data
  if (data === undefined) throw new Error('搜索失败')
  let rawList = data.lists ?? []
  let list: SingerInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let id = item.AuthorId ?? 0
    if (id === 0) continue
    let avatar = item.Avatar ?? ''
    let picUrl = avatar.replace('/softhead/240/', '/softhead/1080/').replace('http://', 'https://')
    list.push(new SingerInfo(String(id), item.AuthorName ?? '', picUrl, '', item.AlbumCount ?? 0,
      item.AudioCount ?? 0))
  }
  let total = data.total ?? list.length
  let allPage = total > 0 ? Math.ceil(total / 30) : 0
  return new SearchPageResult<SingerInfo>(list, allPage, total)
}

export async function searchAlbum(keyword: string, page: number): Promise<SearchPageResult<AlbumInfo>> {
  let raw = await kgSearchAlbum(keyword, page) as KgGwSearchResponse
  if (raw.status !== 1 || raw.error_code !== 0) throw new Error('搜索失败')
  let data = raw.data
  if (data === undefined) throw new Error('搜索失败')
  let rawList = data.lists ?? []
  let list: AlbumInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let id = item.albumid ?? 0
    if (id === 0) continue
    let img = item.img ?? ''
    let picUrl = img.replace('http://', 'https://')
    list.push(new AlbumInfo(String(id), '', item.albumname ?? '', picUrl, 0, item.singer ?? '',
      item.songcount ?? 0, item.publish_time ?? ''))
  }
  let total = data.total ?? list.length
  let allPage = total > 0 ? Math.ceil(total / 30) : 0
  return new SearchPageResult<AlbumInfo>(list, allPage, total)
}