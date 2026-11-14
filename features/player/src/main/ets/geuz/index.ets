import { SingerInfo } from './model/SearchModels'
import { AlbumInfo } from './model/SearchModels'
import { SongInfo } from './model/SearchModels'
import { ArtistInfo } from './model/SearchModels'
import { SearchPageResult } from './model/SearchModels'
import { SongPageResult } from './model/SearchModels'
import { ArtistAlbumPageResult } from './model/SearchModels'
import { AlbumDetailResult } from './model/SearchModels'
import { searchSinger, searchAlbum } from './service/SearchDispatch'
import { getArtistDetail as dispatchArtistDetail, getArtistSongs as dispatchArtistSongs, getArtistAlbums as dispatchArtistAlbums,
  getAlbumDetail as dispatchAlbumDetail } from './service/DetailDispatch'

export { SingerInfo } from './model/SearchModels'
export { AlbumInfo } from './model/SearchModels'
export { SongInfo } from './model/SearchModels'
export { ArtistInfo } from './model/SearchModels'
export { SearchPageResult } from './model/SearchModels'
export { SongPageResult } from './model/SearchModels'
export { ArtistAlbumPageResult } from './model/SearchModels'
export { AlbumDetailResult } from './model/SearchModels'
export type { ArtistDetailParams, AlbumDetailParams } from './model/SearchModels'

export async function searchSingers(source: number, keyword: string, page: number): Promise<SearchPageResult<SingerInfo>> {
  return searchSinger(source, keyword, page)
}

/** Maps an RzdMusic source id ('kw'|'kg'|'tx'|'wy'|'mg') to the geuz source code (0=kg,1=tx,2=wy,3=mg,4=kw). */
export function sourceToCode(source: string): number {
  switch (source) {
    case 'kg': return 0;
    case 'tx': return 1;
    case 'mg': return 3;
    case 'kw': return 4;
    default: return 2;
  }
}

/** Maps a geuz source code (0=kg,1=tx,2=wy,3=mg,4=kw) back to the RzdMusic source id. */
export function codeToSource(code: number): string {
  switch (code) {
    case 0: return 'kg';
    case 1: return 'tx';
    case 3: return 'mg';
    case 4: return 'kw';
    default: return 'wy';
  }
}

export async function searchAlbums(source: number, keyword: string, page: number): Promise<SearchPageResult<AlbumInfo>> {
  return searchAlbum(source, keyword, page)
}

export async function getArtistDetail(source: number, id: string, mid: string): Promise<ArtistInfo> {
  return dispatchArtistDetail(source, id, mid)
}

export async function getArtistSongs(source: number, id: string, mid: string, order: string, limit: number,
  offset: number, artistName?: string): Promise<SongPageResult> {
  let name = artistName ?? ''
  return dispatchArtistSongs(source, id, mid, order, limit, offset, name)
}

export async function getArtistAlbums(source: number, id: string, mid: string, limit: number,
  offset: number): Promise<ArtistAlbumPageResult> {
  return dispatchArtistAlbums(source, id, mid, limit, offset)
}

export async function getAlbumDetail(source: number, id: string, mid: string, name?: string,
  artistName?: string): Promise<AlbumDetailResult> {
  let albumName = name ?? ''
  let albumArtist = artistName ?? ''
  return dispatchAlbumDetail(source, id, mid, albumName, albumArtist)
}