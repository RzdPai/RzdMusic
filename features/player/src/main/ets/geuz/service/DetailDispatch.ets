import { ArtistInfo } from '../model/SearchModels'
import { SongPageResult } from '../model/SearchModels'
import { ArtistAlbumPageResult } from '../model/SearchModels'
import { AlbumDetailResult } from '../model/SearchModels'
import { getArtistDetail as wyDetail, getArtistSongs as wySongs, getArtistAlbums as wyAlbums } from './WyDetailApi'
import { getArtistDetail as kgDetail, getArtistSongs as kgSongs, getArtistAlbums as kgAlbums } from './KgDetailApi'
import { getArtistDetail as txDetail, getArtistSongs as txSongs, getArtistAlbums as txAlbums } from './TxDetailApi'
import { getArtistDetail as mgDetail, getArtistSongs as mgSongs, getArtistAlbums as mgAlbums } from './MgDetailApi'
import { getArtistDetail as kwDetail, getArtistSongs as kwSongs, getArtistAlbums as kwAlbums } from './KwDetailApi'
import { getAlbum as wyAlbum } from './WyDetailApi'
import { getAlbum as kgAlbum } from './KgDetailApi'
import { getAlbum as txAlbum } from './TxDetailApi'
import { getAlbum as mgAlbum } from './MgDetailApi'
import { getAlbum as kwAlbum } from './KwDetailApi'

export async function getArtistDetail(source: number, id: string, mid: string): Promise<ArtistInfo> {
  if (source === 0) return kgDetail(id)
  if (source === 1) return txDetail(mid.length > 0 ? mid : id)
  if (source === 3) return mgDetail(id)
  if (source === 4) return kwDetail(id)
  return wyDetail(id)
}

export async function getArtistSongs(source: number, id: string, mid: string, order: string, limit: number,
  offset: number, artistName: string = ''): Promise<SongPageResult> {
  if (source === 0) return kgSongs(id, order, limit, offset)
  if (source === 1) return txSongs(mid.length > 0 ? mid : id, order, limit, offset)
  if (source === 3) return mgSongs(id, order, limit, offset)
  if (source === 4) return kwSongs(id, order, limit, offset, artistName)
  return wySongs(id, order, limit, offset)
}

export async function getArtistAlbums(source: number, id: string, mid: string, limit: number,
  offset: number): Promise<ArtistAlbumPageResult> {
  if (source === 0) return kgAlbums(id, limit, offset)
  if (source === 1) return txAlbums(mid.length > 0 ? mid : id, limit, offset)
  if (source === 3) return mgAlbums(id, limit, offset)
  if (source === 4) return kwAlbums(id, limit, offset)
  return wyAlbums(id, limit, offset)
}

export async function getAlbumDetail(source: number, id: string, mid: string, name: string = '',
  artistName: string = ''): Promise<AlbumDetailResult> {
  if (source === 0) return kgAlbum(id)
  if (source === 1) return txAlbum(mid.length > 0 ? mid : id)
  if (source === 3) return mgAlbum(id)
  if (source === 4) return kwAlbum(id, name)
  return wyAlbum(id)
}