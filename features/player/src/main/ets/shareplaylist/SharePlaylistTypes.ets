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
