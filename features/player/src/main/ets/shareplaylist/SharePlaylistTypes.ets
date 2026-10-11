export enum SharePlaylistSource {
  Wy = 'wy',
  Tx = 'tx',
  Kw = 'kw',
  Kg = 'kg',
  Mg = 'mg'
}

export interface SharePlaylistSong {
  id: string;
  name: string;
  artist: string;
  album: string;
  duration: number;
  /** 歌曲封面；没有时导入侧留空，勿用歌单封面顶替。 */
  img: string;
}

export interface SharePlaylistInfo {
  source: SharePlaylistSource;
  id: string;
  name: string;
  coverUrl: string;
  desc: string;
  author: string;
  playCount: number;
  songs: SharePlaylistSong[];
}

export interface SharePlaylistSourceOption {
  type: SharePlaylistSource;
  name: string;
}
