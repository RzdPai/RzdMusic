import { SingerInfo } from '../model/SearchModels'
import { AlbumInfo } from '../model/SearchModels'
import { SearchPageResult } from '../model/SearchModels'
import { searchSinger as wySearchSinger, searchAlbum as wySearchAlbum } from './WySearch'
import { searchSinger as kgSearchSinger, searchAlbum as kgSearchAlbum } from './KgSearch'
import { searchSinger as txSearchSinger, searchAlbum as txSearchAlbum } from './TxSearch'
import { searchSinger as mgSearchSinger, searchAlbum as mgSearchAlbum } from './MgSearch'
import { searchSinger as kwSearchSinger, searchAlbum as kwSearchAlbum } from './KwSearch'

export function searchSinger(source: number, keyword: string, page: number): Promise<SearchPageResult<SingerInfo>> {
  if (source === 0) return kgSearchSinger(keyword, page)
  if (source === 1) return txSearchSinger(keyword, page)
  if (source === 3) return mgSearchSinger(keyword, page)
  if (source === 4) return kwSearchSinger(keyword, page)
  return wySearchSinger(keyword, page)
}

export function searchAlbum(source: number, keyword: string, page: number): Promise<SearchPageResult<AlbumInfo>> {
  if (source === 0) return kgSearchAlbum(keyword, page)
  if (source === 1) return txSearchAlbum(keyword, page)
  if (source === 3) return mgSearchAlbum(keyword, page)
  if (source === 4) return kwSearchAlbum(keyword, page)
  return wySearchAlbum(keyword, page)
}