import { SharePlaylistInfo, SharePlaylistSong, SharePlaylistSource } from './SharePlaylistTypes';
import { ShareHttpClient } from './HttpClient';
import { TextUtils } from './TextUtils';

interface RawAlbum {
  name?: string;
}

interface TxRawResponse {
  cdlist?: TxRawList[];
}

interface TxRawList {
  dissname?: string;
  logo?: string;
  desc?: string;
  nickname?: string;
  songnum?: number;
  visitnum?: number;
  songlist?: TxRawTrack[];
}

interface TxRawTrack {
  songmid?: string;
  name?: string;
  singer?: TxRawSinger[];
  album?: RawAlbum;
  interval?: number;
}

interface TxRawSinger {
  name?: string;
}

export class TxShareService {
  private static readonly brRegex: RegExp = new RegExp('<br\\s*/?>', 'g');
  private static readonly txHosts: string[] = ['c.y.qq.com', 'i.y.qq.com'];

  private static readonly shortLinkPatterns: RegExp[] = [
    new RegExp('og:url[^>]*content="[^"]*?/playlist/(\\d+)'),
    new RegExp('/playlist/(\\d+)'),
    new RegExp('details/taoge\\.html\\?[^"]*?id=(\\d+)'),
    new RegExp('disstid[=:"\\s]*(\\d+)'),
  ];

  static async resolveShortLink(link: string): Promise<string> {
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36',
    };
    const body: string = await ShareHttpClient.request(link, headers);
    for (let i = 0; i < TxShareService.shortLinkPatterns.length; i++) {
      const match: RegExpExecArray | null = TxShareService.shortLinkPatterns[i].exec(body);
      if (match !== null && match.length > 1) {
        return match[1];
      }
    }
    return '';
  }

  static async fetch(id: string): Promise<SharePlaylistInfo> {
    let lastError = new Error('未知错误');
    for (let i = 0; i < TxShareService.txHosts.length; i++) {
      try {
        return await TxShareService.fetchByHost(TxShareService.txHosts[i], id);
      } catch (e) {
        lastError = e instanceof Error ? e : new Error(String(e));
      }
    }
    return Promise.reject(lastError);
  }

  private static async fetchByHost(host: string, id: string): Promise<SharePlaylistInfo> {
    const url: string = `https://${host}/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg?type=1&json=1&utf8=1` +
      `&onlysong=0&new_format=1&disstid=${id}&loginUin=0&hostUin=0&format=json&inCharset=utf8` +
      '&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=0';
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36',
      'Referer': `https://y.qq.com/n/yqq/playsquare/${id}.html`,
      'Origin': 'https://y.qq.com',
    };
    const body: string = await ShareHttpClient.request(url, headers);
    const raw: TxRawResponse = JSON.parse(body) as TxRawResponse;
    const list: TxRawList[] = raw.cdlist ?? [];
    if (list.length === 0) {
      throw new Error('歌单不存在或已被删除');
    }
    const pl: TxRawList = list[0];
    const info: SharePlaylistInfo = {
      source: SharePlaylistSource.Tx,
      id: id,
      name: pl.dissname ?? '',
      coverUrl: pl.logo ?? '',
      desc: TextUtils.decodeName(pl.desc ?? '').replace(TxShareService.brRegex, '\n'),
      author: pl.nickname ?? '',
      playCount: pl.visitnum ?? pl.songnum ?? 0,
      songs: []
    };
    const tracks: TxRawTrack[] = pl.songlist ?? [];
    const songs: SharePlaylistSong[] = [];
    for (let i = 0; i < tracks.length; i++) {
      const t: TxRawTrack = tracks[i];
      songs.push({
        id: t.songmid ?? '',
        name: t.name ?? '',
        artist: t.singer?.map((s: TxRawSinger): string => s.name ?? '').join(' / ') ?? '',
        album: t.album?.name ?? '',
        duration: t.interval ?? 0
      });
    }
    info.songs = songs;
    return info;
  }
}
