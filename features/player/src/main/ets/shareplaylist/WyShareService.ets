import { SharePlaylistInfo, SharePlaylistSong, SharePlaylistSource } from './SharePlaylistTypes';
import { ShareHttpClient } from './HttpClient';
import { appendError } from 'musicbasic';

interface RawAlbum {
  name?: string;
}

interface WyRawResponse {
  playlist: WyRawPlaylist;
}

interface WyRawPlaylist {
  name?: string;
  coverImgUrl?: string;
  description?: string;
  playCount?: number;
  creator?: WyRawCreator;
  tracks?: WyRawTrack[];
  trackIds?: WyRawTrackId[];
}

interface WyRawTrackId {
  id?: number;
}

interface WyRawCreator {
  nickname?: string;
}

interface WyRawTrack {
  id?: number;
  name?: string;
  ar?: WyRawArtist[];
  al?: RawAlbum;
  dt?: number;
}

interface WyRawArtist {
  name?: string;
}

interface WyTrackAllRaw {
  songs?: WyRawTrack[];
}

interface WySongDetailRaw {
  songs?: WySongDetailItem[];
}

interface WySongDetailItem {
  id?: number;
  name?: string;
  artists?: WyRawArtist[];
  album?: RawAlbum;
  duration?: number;
}

export class WyShareService {
  private static readonly linkRegex: RegExp = new RegExp('[?&:/]');
  private static readonly idRegex1: RegExp = new RegExp('^.+(?:\\?|&)id=(\\d+)(?:&.*$|#.*$|$)');
  private static readonly idRegex2: RegExp = new RegExp('^.+/playlist/(\\d+)');
  private static readonly shortLinkPatterns: RegExp[] = [
    new RegExp('playlist\\?id=(\\d+)'),
    new RegExp('/playlist/(\\d+)'),
    new RegExp('"playlistId"[:=]+(\\d+)'),
  ];

  static async resolveShortLink(link: string): Promise<string> {
    const headers: Record<string, string> = {};
    const body: string = await ShareHttpClient.request(link, headers);
    for (let i = 0; i < WyShareService.shortLinkPatterns.length; i++) {
      const match: RegExpExecArray | null = WyShareService.shortLinkPatterns[i].exec(body);
      if (match !== null && match.length > 1) {
        return match[1];
      }
    }
    return '';
  }

  static async fetch(rawInput: string): Promise<SharePlaylistInfo> {
    let input: string = rawInput.trim();
    let token: string = '';
    const tokenIdx: number = input.indexOf('###');
    if (tokenIdx >= 0) {
      token = input.substring(tokenIdx + 3).trim();
      input = input.substring(0, tokenIdx).trim();
    }
    let id: string = WyShareService.parseId(input);
    if (id.length === 0) {
      id = await WyShareService.resolveShortLink(input);
    }
    if (id.length === 0) {
      throw new Error('无法解析歌单链接');
    }
    const headers: Record<string, string> = {};
    if (token.length > 0) {
      headers['Cookie'] = `MUSIC_U=${token}`;
    }
    const url: string = `https://music.163.com/api/v6/playlist/detail?id=${id}&n=100000&s=8`;
    const body: string = await ShareHttpClient.request(url, headers);
    const raw: WyRawResponse = JSON.parse(body) as WyRawResponse;
    const pl: WyRawPlaylist = raw.playlist;
    if (pl == null || pl.name === undefined) {
      throw new Error('歌单不存在或已被删除');
    }
    const info: SharePlaylistInfo = {
      source: SharePlaylistSource.Wy,
      id: id,
      name: pl.name ?? '',
      coverUrl: pl.coverImgUrl ?? '',
      desc: pl.description ?? '',
      author: pl.creator?.nickname ?? '',
      playCount: pl.playCount ?? 0,
      songs: []
    };
    let fullTracks: WyRawTrack[] = pl.tracks ?? [];
    const trackIds: WyRawTrackId[] = pl.trackIds ?? [];
    const expected: number = trackIds.length > fullTracks.length ? trackIds.length : fullTracks.length;
    if (fullTracks.length < expected) {
      const paged: WyRawTrack[] = await WyShareService.fetchAllTracksPaged(id, headers);
      if (paged.length > fullTracks.length) {
        fullTracks = paged;
      }
    }
    if (fullTracks.length < expected && trackIds.length > fullTracks.length) {
      try {
        const byIds: WyRawTrack[] = await WyShareService.fetchSongsByIds(trackIds, headers);
        if (byIds.length > fullTracks.length) {
          fullTracks = byIds;
        }
      } catch (e) {
        appendError('[网易歌单] 按 trackIds 补全失败: ' + JSON.stringify(e).substring(0, 120));
      }
    }
    appendError('[网易歌单] 解析完成 曲目=' + fullTracks.length + ' 期望=' + expected +
      ' trackIds=' + trackIds.length);
    info.songs = WyShareService.buildSongs(fullTracks);
    return info;
  }

  /** Paginates /api/playlist/track/all to obtain the full track list (detail API caps at ~10). */
  private static async fetchAllTracksPaged(id: string,
    headers: Record<string, string>): Promise<WyRawTrack[]> {
    const out: WyRawTrack[] = [];
    const pageSize: number = 1000;
    let offset: number = 0;
    while (offset < 20000) {
      const url: string = `https://music.163.com/api/playlist/track/all?id=${id}&limit=${pageSize}&offset=${offset}`;
      let list: WyRawTrack[] = [];
      try {
        const body: string = await ShareHttpClient.request(url, headers);
        const raw: WyTrackAllRaw = JSON.parse(body) as WyTrackAllRaw;
        list = raw.songs ?? [];
      } catch (e) {
        appendError('[网易歌单] track/all 分页失败 offset=' + offset + ': ' +
          JSON.stringify(e).substring(0, 120));
        break;
      }
      for (let i: number = 0; i < list.length; i++) {
        out.push(list[i]);
      }
      if (list.length < pageSize) {
        break;
      }
      offset += pageSize;
    }
    appendError('[网易歌单] track/all 拉取=' + out.length);
    return out;
  }

  private static parseId(input: string): string {
    const text: string = input.trim();
    if (text.length === 0 || !WyShareService.linkRegex.test(text)) {
      return text;
    }
    let match: RegExpExecArray | null = WyShareService.idRegex1.exec(text);
    if (match === null) {
      match = WyShareService.idRegex2.exec(text);
    }
    if (match === null || match.length < 2) {
      return '';
    }
    return match[1];
  }

  private static async fetchSongsByIds(trackIds: WyRawTrackId[],
    headers: Record<string, string>): Promise<WyRawTrack[]> {
    const result: WyRawTrack[] = [];
    for (let i = 0; i < trackIds.length; i += 100) {
      const ids: string[] = [];
      const end: number = i + 100 < trackIds.length ? i + 100 : trackIds.length;
      for (let j = i; j < end; j++) {
        ids.push(String(trackIds[j].id));
      }
      const url: string = `https://music.163.com/api/song/detail?ids=${encodeURIComponent(JSON.stringify(ids))}`;
      const body: string = await ShareHttpClient.request(url, headers);
      const raw: WySongDetailRaw = JSON.parse(body) as WySongDetailRaw;
      const list: WySongDetailItem[] = raw.songs ?? [];
      for (let k = 0; k < list.length; k++) {
        const s: WySongDetailItem = list[k];
        const t: WyRawTrack = {
          id: s.id,
          name: s.name,
          ar: s.artists,
          al: s.album,
          dt: s.duration,
        };
        result.push(t);
      }
    }
    return result;
  }

  private static buildSongs(tracks: WyRawTrack[]): SharePlaylistSong[] {
    const songs: SharePlaylistSong[] = [];
    for (let i = 0; i < tracks.length; i++) {
      const t: WyRawTrack = tracks[i];
      songs.push({
        id: String(t.id ?? ''),
        name: t.name ?? '',
        artist: t.ar?.map((a: WyRawArtist): string => a.name ?? '').join(' / ') ?? '',
        album: t.al?.name ?? '',
        duration: Math.floor((t.dt ?? 0) / 1000)
      });
    }
    return songs;
  }
}
