export class SearchPlaylistInfo {
  id: string = '';
  name: string = '';
  playCount: number = 0;
  trackCount: number = 0;
  coverUrl: string = '';
  creator: string = '';
  source: string = '';

  static of(id: string, name: string, playCount: number, trackCount: number,
    coverUrl: string, creator: string, source: string): SearchPlaylistInfo {
    const p = new SearchPlaylistInfo();
    p.id = id;
    p.name = name;
    p.playCount = playCount;
    p.trackCount = trackCount;
    p.coverUrl = coverUrl;
    p.creator = creator;
    p.source = source;
    return p;
  }
}

export class SearchPlaylistSong {
  songId: string = '';
  name: string = '';
  singer: string = '';
  album: string = '';
  interval: string = '';
  source: string = '';
  picUrl: string = '';

  static of(songId: string, name: string, singer: string, album: string,
    interval: string, source: string, picUrl: string = ''): SearchPlaylistSong {
    const s = new SearchPlaylistSong();
    s.songId = songId;
    s.name = name;
    s.singer = singer;
    s.album = album;
    s.interval = interval;
    s.source = source;
    s.picUrl = picUrl;
    return s;
  }
}

export function fmtDuration(seconds: number): string {
  const sec: number = Math.max(0, Math.floor(seconds));
  const mm: number = Math.floor(sec / 60);
  const ss: number = sec % 60;
  return `${mm.toString().padStart(2, '0')}:${ss.toString().padStart(2, '0')}`;
}
