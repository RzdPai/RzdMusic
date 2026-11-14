import { SharePlaylistInfo, SharePlaylistSong, SharePlaylistSource } from './SharePlaylistTypes';
import { ShareHttpClient } from './HttpClient';

interface MgRawResponse {
  data?: MgRawData;
}

interface MgRawData {
  totalCount?: number;
  songList?: MgRawSong[];
}

interface MgRawSong {
  songId?: string;
  songName?: string;
  duration?: number;
  album?: string;
  singerList?: MgRawSinger[];
}

interface MgRawSinger {
  name?: string;
}

interface MgInfoResponse {
  data?: MgInfoData;
}

interface MgInfoData {
  title?: string;
  summary?: string;
  imgItem?: MgImgItem;
  ownerName?: string;
  opNumItem?: MgOpNumItem;
}

interface MgImgItem {
  img?: string;
}

interface MgOpNumItem {
  playNum?: number;
}

export class MgShareService {
  private static readonly pageSize: number = 50;
  private static readonly headers: Record<string, string> = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
    'Referer': 'https://m.music.migu.cn/',
  };
  private static readonly shortLinkPatterns: RegExp[] = [
    new RegExp('playlistId=(\\d+)'),
    new RegExp('[?&]id=(\\d+)'),
    new RegExp('"playlistId"[:=]+(\\d+)'),
  ];

  static async resolveShortLink(link: string): Promise<string> {
    const body: string = await ShareHttpClient.request(link, MgShareService.headers);
    for (let i = 0; i < MgShareService.shortLinkPatterns.length; i++) {
      const match: RegExpExecArray | null = MgShareService.shortLinkPatterns[i].exec(body);
      if (match !== null && match.length > 1) {
        return match[1];
      }
    }
    return '';
  }

  static async fetch(id: string): Promise<SharePlaylistInfo> {
    const songsUrl: string =
      `https://app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0?pageNo=1&pageSize=${MgShareService.pageSize}&playlistId=${id}`;
    const songsBody: string = await ShareHttpClient.request(songsUrl, MgShareService.headers);
    const songsRaw: MgRawResponse = JSON.parse(songsBody) as MgRawResponse;
    if (songsRaw?.data === undefined) {
      throw new Error('歌单不存在或已被删除');
    }
    const total: number = songsRaw.data.totalCount ?? 0;
    let allSongs: MgRawSong[] = songsRaw.data.songList ?? [];
    if (allSongs.length < total) {
      allSongs = await MgShareService.fetchAllPages(id, total, allSongs);
    }
    const infoUrl: string = `https://c.musicapp.migu.cn/MIGUM3.0/resource/playlist/v2.0?playlistId=${id}`;
    const infoBody: string = await ShareHttpClient.request(infoUrl, MgShareService.headers);
    const infoRaw: MgInfoResponse = JSON.parse(infoBody) as MgInfoResponse;
    const info: SharePlaylistInfo = {
      source: SharePlaylistSource.Mg,
      id: id,
      name: '',
      coverUrl: '',
      desc: '',
      author: '',
      playCount: 0,
      songs: MgShareService.buildSongs(allSongs)
    };
    if (infoRaw?.data !== undefined) {
      info.name = infoRaw.data.title ?? '';
      info.coverUrl = infoRaw.data.imgItem?.img ?? '';
      info.desc = infoRaw.data.summary ?? '';
      info.author = infoRaw.data.ownerName ?? '';
      info.playCount = infoRaw.data.opNumItem?.playNum ?? 0;
    }
    return info;
  }

  private static async fetchAllPages(id: string, total: number,
    firstList: MgRawSong[]): Promise<MgRawSong[]> {
    const pageCount: number = Math.ceil(total / MgShareService.pageSize);
    const tasks: Promise<MgRawSong[]>[] = [];
    for (let pageNo = 2; pageNo <= pageCount; pageNo++) {
      tasks.push(MgShareService.fetchPage(id, pageNo));
    }
    const results: MgRawSong[][] = await Promise.all(tasks);
    let all: MgRawSong[] = firstList;
    for (let i = 0; i < results.length; i++) {
      const list: MgRawSong[] = results[i];
      if (list.length > 0) {
        all = all.concat(list);
      }
    }
    return all;
  }

  private static async fetchPage(id: string, pageNo: number): Promise<MgRawSong[]> {
    const url: string =
      `https://app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0?pageNo=${pageNo}&pageSize=${MgShareService.pageSize}&playlistId=${id}`;
    const body: string = await ShareHttpClient.request(url, MgShareService.headers);
    const raw: MgRawResponse = JSON.parse(body) as MgRawResponse;
    return raw?.data?.songList ?? [];
  }

  private static buildSongs(trackList: MgRawSong[]): SharePlaylistSong[] {
    const songs: SharePlaylistSong[] = [];
    for (let i = 0; i < trackList.length; i++) {
      const t: MgRawSong = trackList[i];
      songs.push({
        id: t.songId ?? '',
        name: t.songName ?? '',
        artist: t.singerList?.map((s: MgRawSinger): string => s.name ?? '').join(' / ') ?? '',
        album: t.album ?? '',
        duration: t.duration ?? 0
      });
    }
    return songs;
  }
}
