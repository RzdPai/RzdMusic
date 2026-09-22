import { SharePlaylistInfo, SharePlaylistSong, SharePlaylistSource } from './SharePlaylistTypes';
import { ShareHttpClient } from './HttpClient';
import { TextUtils } from './TextUtils';

interface KwRawResponse {
  title?: string;
  pic?: string;
  info?: string;
  uname?: string;
  playnum?: string;
  musiclist?: KwRawTrack[];
}

interface KwRawTrack {
  id?: string;
  name?: string;
  artist?: string;
  album?: string;
  duration?: string;
}

export class KwShareService {
  static async fetch(id: string): Promise<SharePlaylistInfo> {
    const url: string = 'https://nplserver.kuwo.cn/pl.svc?op=getlistinfo' +
      `&pid=${id}&pn=0&rn=1000&encode=utf8&keyset=pl2012&identity=kuwo&pcmp4=1` +
      '&vipver=MUSIC_9.0.5.0_W1&newver=1';
    const body: string = await ShareHttpClient.request(url, {});
    const raw: KwRawResponse = JSON.parse(body) as KwRawResponse;
    if (raw == null || raw.title === undefined) {
      throw new Error('歌单不存在或已被删除');
    }
    const info: SharePlaylistInfo = {
      source: SharePlaylistSource.Kw,
      id: id,
      name: raw.title ?? '',
      coverUrl: raw.pic ?? '',
      desc: raw.info ?? '',
      author: raw.uname ?? '',
      playCount: Number(raw.playnum ?? '0'),
      songs: []
    };
    const tracks: KwRawTrack[] = raw.musiclist ?? [];
    const songs: SharePlaylistSong[] = [];
    for (let i = 0; i < tracks.length; i++) {
      const t: KwRawTrack = tracks[i];
      songs.push({
        id: t.id ?? '',
        name: TextUtils.decodeName(t.name ?? ''),
        artist: TextUtils.decodeName(t.artist ?? ''),
        album: TextUtils.decodeName(t.album ?? ''),
        duration: Number(t.duration ?? '0')
      });
    }
    info.songs = songs;
    return info;
  }
}
