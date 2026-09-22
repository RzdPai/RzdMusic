import { SingerInfo } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { SearchPageResult } from '../model/SearchModels'
import { kwGet } from './KwRequest'
import { cleanText } from './HttpUtils'

const PAGE_SIZE: number = 30

interface KwSearchResponse {
  code: number
  data: KwSearchData | undefined
}

interface KwSearchData {
  total: string | undefined
  list: KwArtistItem[] | undefined
  albumList: KwAlbumItem[] | undefined
}

interface KwArtistItem {
  id: number | undefined
  name: string | undefined
  pic: string | undefined
  musicNum: number | undefined
}

interface KwAlbumItem {
  albumid: number | undefined
  album: string | undefined
  artist: string | undefined
  pic: string | undefined
  releaseDate: string | undefined
}

interface KwAlbumCountResp {
  code: number
  data: KwAlbumCountData | undefined
}

interface KwAlbumCountData {
  total: string | undefined
}

async function fetchArtistAlbumNum(artistId: string): Promise<number> {
  let url = 'http://www.kuwo.cn/api/www/artist/artistAlbum?artistid=' + artistId + '&pn=1&rn=1&httpsStatus=1'
  let raw = await kwGet(url, 'http://www.kuwo.cn/singer_detail/' + encodeURIComponent(artistId) + '/album') as KwAlbumCountResp
  if (raw.code !== 200) return 0
  let data = raw.data
  if (data === undefined) return 0
  return Number(data.total ?? 0)
}

async function fillSingerAlbumSizes(list: SingerInfo[]): Promise<void> {
  const CONCURRENCY = 5
  let idx = 0
  while (idx < list.length) {
    let promises: Promise<number>[] = []
    let ids: string[] = []
    for (let k = 0; k < CONCURRENCY && idx < list.length; k++) {
      ids.push(list[idx].id)
      promises.push(fetchArtistAlbumNum(list[idx].id))
      idx++
    }
    try {
      let sizes = await Promise.all(promises)
      for (let k = 0; k < sizes.length; k++) {
        if (sizes[k] > 0) {
          for (let j = 0; j < list.length; j++) {
            if (list[j].id === ids[k]) {
              list[j].albumSize = sizes[k]
            }
          }
        }
      }
    } catch (e) {
    }
  }
}

export async function searchSinger(keyword: string, page: number): Promise<SearchPageResult<SingerInfo>> {
  let result = await searchSingerNew(keyword, page)
  await fillSingerAlbumSizes(result.list)
  return result
}

async function searchSingerNew(keyword: string, page: number): Promise<SearchPageResult<SingerInfo>> {
  let url = 'http://www.kuwo.cn/api/www/search/searchArtistBykeyWord?key=' + encodeURIComponent(keyword) +
    '&pn=' + page + '&rn=' + PAGE_SIZE + '&httpsStatus=1'
  let raw = await kwGet(url) as KwSearchResponse
  if (raw.code !== 200) {
    throw new Error('搜索失败: code=' + raw.code + ' resp=' + JSON.stringify(raw).slice(0, 150))
  }
  let data = raw.data
  if (data === undefined) throw new Error('搜索失败: 无数据')
  let rawList = data.list ?? []
  let list: SingerInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let id = item.id ?? 0
    if (id === 0) continue
    let picUrl = (item.pic ?? '').replace('/starheads/240/', '/starheads/1080/').replace('http://', 'https://')
    list.push(new SingerInfo(String(id), cleanText(item.name ?? ''), picUrl, '', 0, item.musicNum ?? 0))
  }
  let total = Number(data.total ?? 0)
  let allPage = total > 0 ? Math.ceil(total / PAGE_SIZE) : (list.length > 0 ? page + 1 : page)
  return new SearchPageResult<SingerInfo>(list, allPage, total)
}

export async function searchAlbum(keyword: string, page: number): Promise<SearchPageResult<AlbumInfo>> {
  return searchAlbumNew(keyword, page)
}

async function searchAlbumNew(keyword: string, page: number): Promise<SearchPageResult<AlbumInfo>> {
  let url = 'http://www.kuwo.cn/api/www/search/searchAlbumBykeyWord?key=' + encodeURIComponent(keyword) +
    '&pn=' + page + '&rn=' + PAGE_SIZE + '&httpsStatus=1'
  let raw = await kwGet(url) as KwSearchResponse
  if (raw.code !== 200) {
    throw new Error('搜索失败: code=' + raw.code + ' resp=' + JSON.stringify(raw).slice(0, 150))
  }
  let data = raw.data
  if (data === undefined) throw new Error('搜索失败: 无数据')
  let rawList = data.albumList ?? []
  let list: AlbumInfo[] = []
  for (let i = 0; i < rawList.length; i++) {
    let item = rawList[i]
    let id = item.albumid ?? 0
    if (id === 0) continue
    let picUrl = (item.pic ?? '').replace('http://', 'https://')
    list.push(new AlbumInfo(String(id), '', cleanText(item.album ?? ''), picUrl, 0,
      cleanText(item.artist ?? ''), 0, item.releaseDate ?? ''))
  }
  let total = Number(data.total ?? 0)
  let allPage = total > 0 ? Math.ceil(total / PAGE_SIZE) : (list.length > 0 ? page + 1 : page)
  return new SearchPageResult<AlbumInfo>(list, allPage, total)
}
