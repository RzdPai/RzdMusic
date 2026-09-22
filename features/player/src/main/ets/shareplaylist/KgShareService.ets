import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { Md5 } from '../recognize/Md5';
import { SharePlaylistInfo, SharePlaylistSong, SharePlaylistSource } from './SharePlaylistTypes';
import { ShareHttpClient } from './HttpClient';
import { TextUtils } from './TextUtils';

interface RawAlbum {
  name?: string;
}

interface KgRawSong {
  hash?: string;
  songname?: string;
  singername?: string;
  album_name?: string;
  duration?: number;
}

interface KgChainRawResponse {
  errcode?: number;
  list?: KgRawSong[];
  info?: KgChainInfo;
  global_collection_id?: string;
  id?: number;
}

interface KgChainInfo {
  name?: string;
  img?: string;
  username?: string;
}

interface KgPhpParam {
  specialname?: string;
  imgurl?: string;
  nickname?: string;
}

interface KgOtherListRawResponse {
  error_code?: number;
  info?: KgRawSong[];
}

interface KgZlistMeta {
  count?: number;
  name?: string;
  pic?: string;
  list_create_username?: string;
}

interface KgZlistList {
  info?: KgRawSong[];
}

interface KgZlistRawResponse {
  info?: Record<string, KgZlistMeta>;
  list?: KgZlistList;
}

interface KgDecodeRawResponse {
  data?: KgDecodeData;
}

interface KgDecodeData {
  list?: KgDecodeItem[];
}

interface KgDecodeItem {
  global_collection_id?: string;
}

interface KgCommandRawResponse {
  status?: number;
  data?: KgCommandData;
  list?: KgSongV2Item[];
  info?: KgCommandInfo;
}

interface KgCommandData {
  info?: KgCommandInfo;
  list?: KgSongV2Item[];
}

interface KgCommandInfo {
  type?: number;
  id?: string;
  name?: string;
  img?: string;
  img_size?: string;
  username?: string;
  userid?: number;
  count?: number;
  global_collection_id?: string;
}

interface KgInfoV2RawResponse {
  data?: KgInfoV2Data;
}

interface KgInfoV2Data {
  specialname?: string;
  imgurl?: string;
  intro?: string;
  nickname?: string;
  playcount?: number;
  songcount?: number;
}

interface KgSongV2RawResponse {
  data?: KgSongV2Data;
}

interface KgSongV2Data {
  info?: KgSongV2Item[];
}

interface KgSongV2Item {
  hash?: string;
}

interface KgGatewayRawResponse {
  data?: KgGatewayItem[][];
}

interface KgGatewayItem {
  hash?: string;
  songname?: string;
  author_name?: string;
  album_info?: KgGatewayAlbum;
  audio_info?: KgGatewayAudio;
}

interface KgGatewayAlbum {
  album_name?: string;
}

interface KgGatewayAudio {
  audio_id?: string;
  timelength?: string;
}

export class KgShareService {
  private static readonly pcHeaders: Record<string, string> = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
  };

  private static readonly mobileHeaders: Record<string, string> = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1',
  };

  private static readonly linkRegex: RegExp = new RegExp('[?&:/]');
  private static readonly pureNumRegex: RegExp = new RegExp('^\\d+$');
  private static readonly specialIdRegex: RegExp = new RegExp('^.+/special/single/(\\d+)\\.html(?:\\?.*|&.*$|#.*$|$)');
  private static readonly songListIdRegex: RegExp = new RegExp('^.+/songlist/(\\d+)(?:\\?.*|&.*$|#.*$|$)');
  private static readonly gcidRegex: RegExp = new RegExp('gcid_\\w+');
  private static readonly chainRegex1: RegExp = new RegExp('chain=(\\w+)');
  private static readonly chainRegex2: RegExp = new RegExp('^https?://t\\.kugou\\.com/(\\w+)');
  private static readonly listDataRegex: RegExp = new RegExp('global\\.data = (\\[.+\\]);');
  private static readonly listInfoRegex: RegExp =
    new RegExp('global = \\{[\\s\\S]+?name: "(.+)"[\\s\\S]+?pic: "(.+)"[\\s\\S]+?\\};');
  private static readonly globalCollectionIdRegex: RegExp = new RegExp('global_collection_id=(\\w+)');
  private static readonly htmlGlobalCollectionIdRegex: RegExp = new RegExp('"global_collection_id":"(\\w+)"');
  private static readonly encodeGcidRegex: RegExp = new RegExp('"encode_(?:gic|src_gid)":"(\\w+)"');
  private static readonly phpParamRegex: RegExp = new RegExp('var\\sphpParam\\s=\\s(\\{.+?\\});');
  private static readonly dataFromSmartyRegex: RegExp = new RegExp('var\\sdataFromSmarty\\s=\\s(\\[.+?\\])');
  private static readonly htmlChainRegex: RegExp = new RegExp('/(\\w+)\\.html');
  private static readonly zlistRewriteRegex: RegExp = new RegExp('^(.*)zlist\\.html');
  private static readonly pagesizeRegex: RegExp = new RegExp('pagesize=\\d+');
  private static readonly pageParamRegex: RegExp = new RegExp('page=\\d+');

  static async fetch(rawId: string): Promise<SharePlaylistInfo> {
    const id: string = rawId.trim();
    if (id.length === 0) {
      throw new Error('无法解析歌单链接');
    }
    if (id.includes('special/single/') || id.includes('/songlist/')) {
      const gcidMatch: RegExpExecArray | null = KgShareService.gcidRegex.exec(id);
      if (gcidMatch !== null) {
        return KgShareService.fetchByGcid(gcidMatch[0]);
      }
      const m: RegExpExecArray | null = KgShareService.specialIdRegex.exec(id);
      if (m !== null && m.length > 1) {
        return KgShareService.fetchBySpecialId(m[1]);
      }
      const m2: RegExpExecArray | null = KgShareService.songListIdRegex.exec(id);
      if (m2 !== null && m2.length > 1) {
        return KgShareService.fetchBySpecialId(m2[1]);
      }
      throw new Error('无法解析酷狗链接');
    }
    if (KgShareService.pureNumRegex.test(id)) {
      return KgShareService.fetchByCode(id);
    }
    if (id.startsWith('id_')) {
      return KgShareService.fetchBySpecialId(id.substring(3));
    }
    let chainMatch: RegExpExecArray | null = KgShareService.chainRegex1.exec(id);
    if (chainMatch === null || chainMatch.length < 2) {
      chainMatch = KgShareService.chainRegex2.exec(id);
    }
    if (chainMatch !== null && chainMatch.length > 1) {
      return KgShareService.fetchByChain(chainMatch[1]);
    }
    if (id.includes('global_collection_id=')) {
      const gcidParamMatch: RegExpExecArray | null = KgShareService.globalCollectionIdRegex.exec(id);
      if (gcidParamMatch !== null && gcidParamMatch.length > 1) {
        return KgShareService.fetchByGlobalId(gcidParamMatch[1]);
      }
    }
    if (id.includes('gcid_')) {
      const gcidMatch2: RegExpExecArray | null = KgShareService.gcidRegex.exec(id);
      if (gcidMatch2 !== null) {
        return KgShareService.fetchByGcid(gcidMatch2[0]);
      }
    }
    if (id.includes('zlist.html')) {
      return KgShareService.fetchByZlist(id);
    }
    if (id.includes('.html') && !id.includes('song.html')) {
      const chainHtmlMatch: RegExpExecArray | null = KgShareService.htmlChainRegex.exec(id);
      if (chainHtmlMatch !== null && chainHtmlMatch.length > 1) {
        return KgShareService.fetchByChain(chainHtmlMatch[1]);
      }
    }
    return KgShareService.fetchByRedirect(id);
  }

  private static async fetchBySpecialId(id: string): Promise<SharePlaylistInfo> {
    const url: string = `http://www2.kugou.kugou.com/yueku/v9/special/single/${id}-5-9999.html`;
    const body: string = await ShareHttpClient.request(url, KgShareService.pcHeaders);
    return KgShareService.parseHtml(body, id);
  }

  private static parseHtml(html: string, id: string): SharePlaylistInfo {
    const dataMatch: RegExpExecArray | null = KgShareService.listDataRegex.exec(html);
    if (dataMatch === null || dataMatch.length < 2) {
      throw new Error('歌单不存在或已被删除');
    }
    const rawList: KgRawSong[] = JSON.parse(dataMatch[1]) as KgRawSong[];
    if (rawList == null) {
      throw new Error('歌单数据解析失败');
    }
    const infoMatch: RegExpExecArray | null = KgShareService.listInfoRegex.exec(html);
    const info: SharePlaylistInfo = {
      source: SharePlaylistSource.Kg,
      id: id,
      name: infoMatch !== null && infoMatch.length > 1 ? infoMatch[1] : '',
      coverUrl: infoMatch !== null && infoMatch.length > 2 ? infoMatch[2] : '',
      desc: KgShareService.parseDesc(html),
      author: '',
      playCount: 0,
      songs: KgShareService.buildHtmlSongs(rawList)
    };
    return info;
  }

  private static parseDesc(html: string): string {
    const prefix: string = '<div class="pc_specail_text pc_singer_tab_content" id="specailIntroduceWrap">';
    const start: number = html.indexOf(prefix);
    if (start < 0) {
      return '';
    }
    const after: string = html.substring(start + prefix.length);
    const end: number = after.indexOf('</div>');
    if (end < 0) {
      return '';
    }
    return TextUtils.decodeName(after.substring(0, end).trim());
  }

  private static buildHtmlSongs(rawList: KgRawSong[]): SharePlaylistSong[] {
    const songs: SharePlaylistSong[] = [];
    for (let i = 0; i < rawList.length; i++) {
      const t: KgRawSong = rawList[i];
      songs.push({
        id: t.hash ?? '',
        name: TextUtils.decodeName(t.songname ?? ''),
        artist: TextUtils.decodeName(t.singername ?? ''),
        album: TextUtils.decodeName(t.album_name ?? ''),
        duration: Math.floor((t.duration ?? 0) / 1000)
      });
    }
    return songs;
  }

  private static kgCommandHeaders(): Record<string, string> {
    return {
      'KG-RC': '1',
      'KG-THash': 'network_super_call.cpp:3676261689:379',
      'User-Agent': '',
      'Content-Type': 'application/json',
    };
  }

  private static async fetchByCode(id: string): Promise<SharePlaylistInfo> {
    const bodyText: string = JSON.stringify({
      'appid': 1001,
      'clientver': 9020,
      'mid': '21511157a05844bd085308bc76ef3343',
      'clienttime': 640612895,
      'key': '36164c4015e704673c588ee202b9ecb8',
      'data': id,
    });
    const body: string = await ShareHttpClient.request('http://t.kugou.com/command/', KgShareService.kgCommandHeaders(),
      http.RequestMethod.POST, bodyText);
    const raw: KgCommandRawResponse = JSON.parse(body) as KgCommandRawResponse;
    if (raw == null || raw.status !== 1) {
      throw new Error('酷狗码无效或已失效');
    }
    const info: KgCommandInfo | undefined = raw.data?.info ?? raw.info;
    if (info == null || info.type === undefined) {
      throw new Error('酷狗码解析失败');
    }
    if (info.type === 2 && (info.global_collection_id === undefined || info.global_collection_id.length === 0)) {
      const specialId: string = info.id ?? '';
      if (specialId.length === 0) {
        throw new Error('酷狗码无效');
      }
      return KgShareService.fetchBySpecialId(specialId);
    }
    if (info.global_collection_id !== undefined && info.global_collection_id.length > 0) {
      return KgShareService.fetchByGlobalId(info.global_collection_id);
    }
    let hashList: KgSongV2Item[] = [];
    if (info.userid !== undefined) {
      hashList = await KgShareService.fetchUserList(info.id ?? '', String(info.userid), info.count ?? 0);
    } else {
      hashList = raw.data?.list ?? raw.list ?? [];
    }
    const hashs: string[] = KgShareService.collectHashs([hashList]);
    if (hashs.length === 0) {
      throw new Error('该酷狗码不是歌单');
    }
    const details: KgGatewayItem[] = await KgShareService.fetchGateway(hashs);
    const result: SharePlaylistInfo = {
      source: SharePlaylistSource.Kg,
      id: id,
      name: info.name ?? '',
      coverUrl: (info.img_size !== undefined && info.img_size.length > 0
        ? info.img_size.replace('{size}', '240') : info.img) ?? '',
      desc: '',
      author: info.username ?? '',
      playCount: 0,
      songs: KgShareService.buildGatewaySongs(details)
    };
    return result;
  }

  private static async fetchUserList(id: string, userid: string, count: number): Promise<KgSongV2Item[]> {
    const dataObj: Record<string, Object> = {
      'id': id,
      'type': 3,
      'userid': userid,
      'collect_type': 0,
      'page': 1,
      'pagesize': count,
    };
    const bodyText: string = JSON.stringify({
      'appid': 1001,
      'clientver': 9020,
      'mid': '21511157a05844bd085308bc76ef3343',
      'clienttime': 640612895,
      'key': '36164c4015e704673c588ee202b9ecb8',
      'data': dataObj,
    });
    const body: string = await ShareHttpClient.request('http://www2.kugou.kugou.com/apps/kucodeAndShare/app/',
      KgShareService.kgCommandHeaders(), http.RequestMethod.POST, bodyText);
    const raw: KgSongV2RawResponse = JSON.parse(body) as KgSongV2RawResponse;
    return raw?.data?.info ?? [];
  }

  private static async fetchByChain(chain: string): Promise<SharePlaylistInfo> {
    const url: string =
      `http://m.kugou.com/schain/transfer?pagesize=9999&chain=${chain}&su=1&page=1&n=0.7928855356604456`;
    const body: string = await ShareHttpClient.request(url, KgShareService.mobileHeaders);
    const raw: KgChainRawResponse = JSON.parse(body) as KgChainRawResponse;
    if (raw == null || raw.errcode !== 0) {
      throw new Error('酷狗歌单解析失败');
    }
    const list: KgRawSong[] = raw.list ?? [];
    if (list.length > 0) {
      const info: SharePlaylistInfo = {
        source: SharePlaylistSource.Kg,
        id: chain,
        name: raw.info?.name ?? '',
        coverUrl: raw.info?.img ?? '',
        desc: '',
        author: raw.info?.username ?? '',
        playCount: 0,
        songs: KgShareService.buildHtmlSongs(list)
      };
      return info;
    }
    if (raw.global_collection_id !== undefined && raw.global_collection_id.length > 0) {
      return KgShareService.fetchByGlobalId(raw.global_collection_id);
    }
    const specialId: string = raw.id !== undefined ? String(raw.id) : '';
    if (specialId.length > 0) {
      try {
        return await KgShareService.fetchByChainSpecialId(specialId, chain);
      } catch (e) {
      }
    }
    return KgShareService.fetchByChainPcShare(chain);
  }

  private static async fetchByRedirect(link: string): Promise<SharePlaylistInfo> {
    const headers: Record<string, string> = {
      'User-Agent': KgShareService.mobileHeaders['User-Agent'],
      'Referer': link,
    };
    const body: string = await ShareHttpClient.request(link, headers);
    const dataMatch: RegExpExecArray | null = KgShareService.listDataRegex.exec(body);
    if (dataMatch !== null && dataMatch.length > 1) {
      return KgShareService.parseHtml(body, link);
    }
    const gcidMatch: RegExpExecArray | null = KgShareService.htmlGlobalCollectionIdRegex.exec(body);
    if (gcidMatch !== null && gcidMatch.length > 1) {
      return KgShareService.fetchByGlobalId(gcidMatch[1]);
    }
    const encodeMatch: RegExpExecArray | null = KgShareService.encodeGcidRegex.exec(body);
    if (encodeMatch !== null && encodeMatch.length > 1) {
      const globalId: string = await KgShareService.decodeGcid(encodeMatch[1]);
      return KgShareService.fetchByGlobalId(globalId);
    }
    throw new Error('无法解析酷狗链接');
  }

  private static async fetchChainInfo(chain: string): Promise<KgPhpParam | null> {
    const url: string = `https://m.kugou.com/share/?chain=${chain}&id=${chain}`;
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
    };
    const body: string = await ShareHttpClient.request(url, headers);
    const match: RegExpExecArray | null = KgShareService.phpParamRegex.exec(body);
    if (match === null || match.length < 2) {
      return null;
    }
    return JSON.parse(match[1]) as KgPhpParam;
  }

  private static async fetchOtherListPage(specialId: string, page: number, limit: number): Promise<KgRawSong[]> {
    const params: string = `appid=1058&clientver=20000&module=playlist&page=${page}&pagesize=${limit}&specialid=${specialId}&srcappid=2919&type=0`;
    const sig: string = await KgShareService.signature(params, 'web', '');
    const url: string = `https://pubsongscdn.kugou.com/v2/get_other_list_file?srcappid=2919&clientver=20000&appid=1058&type=0&module=playlist&page=${page}&pagesize=${limit}&specialid=${specialId}&signature=${sig}`;
    const headers: Record<string, string> = {
      'Referer': 'https://m3ws.kugou.com/share/index.php',
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1',
      'dfid': '-',
    };
    const body: string = await ShareHttpClient.request(url, headers);
    const raw: KgOtherListRawResponse = JSON.parse(body) as KgOtherListRawResponse;
    return raw?.info ?? [];
  }

  private static async fetchByChainSpecialId(specialId: string, chain: string): Promise<SharePlaylistInfo> {
    const chainInfo: KgPhpParam | null = await KgShareService.fetchChainInfo(chain);
    let songs: KgRawSong[] = await KgShareService.fetchOtherListPage(specialId, 1, 100);
    if (songs.length === 0) {
      throw new Error('酷狗歌单解析失败');
    }
    for (let page = 2; page <= 100 && songs.length < 10000; page++) {
      const more: KgRawSong[] = await KgShareService.fetchOtherListPage(specialId, page, 100);
      if (more.length === 0) {
        break;
      }
      songs = songs.concat(more);
    }
    const hashs: string[] = KgShareService.collectRawHashs(songs);
    const details: KgGatewayItem[] = await KgShareService.fetchGateway(hashs);
    const info: SharePlaylistInfo = {
      source: SharePlaylistSource.Kg,
      id: chain,
      name: chainInfo?.specialname ?? '',
      coverUrl: (chainInfo?.imgurl ?? '').replace('{size}', '240'),
      desc: '',
      author: chainInfo?.nickname ?? '',
      playCount: 0,
      songs: KgShareService.buildGatewaySongs(details)
    };
    return info;
  }

  private static async fetchByChainPcShare(chain: string): Promise<SharePlaylistInfo> {
    const url: string = `http://www.kugou.com/share/${chain}.html`;
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36',
    };
    const body: string = await ShareHttpClient.request(url, headers);
    const match: RegExpExecArray | null = KgShareService.dataFromSmartyRegex.exec(body);
    if (match === null || match.length < 2) {
      throw new Error('酷狗歌单解析失败');
    }
    const rawList: KgRawSong[] = JSON.parse(match[1]) as KgRawSong[];
    const hashs: string[] = KgShareService.collectRawHashs(rawList ?? []);
    if (hashs.length === 0) {
      throw new Error('酷狗歌单解析失败');
    }
    const details: KgGatewayItem[] = await KgShareService.fetchGateway(hashs);
    const chainInfo: KgPhpParam | null = await KgShareService.fetchChainInfo(chain);
    const info: SharePlaylistInfo = {
      source: SharePlaylistSource.Kg,
      id: chain,
      name: chainInfo?.specialname ?? '',
      coverUrl: (chainInfo?.imgurl ?? '').replace('{size}', '240'),
      desc: '',
      author: chainInfo?.nickname ?? '',
      playCount: 0,
      songs: KgShareService.buildGatewaySongs(details)
    };
    return info;
  }

  private static collectRawHashs(list: KgRawSong[]): string[] {
    const hashs: string[] = [];
    const seen: Set<string> = new Set<string>();
    for (let i = 0; i < list.length; i++) {
      const h: string = list[i].hash ?? '';
      if (h.length > 0 && !seen.has(h)) {
        seen.add(h);
        hashs.push(h);
      }
    }
    return hashs;
  }

  private static async fetchByZlist(link: string): Promise<SharePlaylistInfo> {
    const base: string = link.replace(KgShareService.zlistRewriteRegex, 'https://m3ws.kugou.com/zlist/list');
    const buildPageUrl = (page: number): string => {
      let url: string = KgShareService.pagesizeRegex.test(base)
        ? base.replace(KgShareService.pagesizeRegex, 'pagesize=90')
        : `${base}&pagesize=90`;
      url = KgShareService.pageParamRegex.test(url)
        ? url.replace(KgShareService.pageParamRegex, `page=${page}`)
        : `${url}&page=${page}`;
      return url;
    };
    const headers: Record<string, string> = {
      'User-Agent': KgShareService.mobileHeaders['User-Agent'],
    };
    const firstBody: string = await ShareHttpClient.request(buildPageUrl(1), headers);
    const first: KgZlistRawResponse = JSON.parse(firstBody) as KgZlistRawResponse;
    const container: Record<string, KgZlistMeta> | undefined = first?.info;
    const meta: KgZlistMeta | undefined = container == null ? undefined : container['0'];
    let songs: KgRawSong[] = first?.list?.info ?? [];
    const total: number = meta?.count ?? songs.length;
    for (let page = 2; page <= 120 && songs.length < total; page++) {
      const more: KgRawSong[] = await KgShareService.fetchZlistPage(buildPageUrl(page), headers);
      if (more.length === 0) {
        break;
      }
      songs = songs.concat(more);
    }
    if (songs.length === 0) {
      throw new Error('酷狗歌单解析失败');
    }
    const hashs: string[] = KgShareService.collectRawHashs(songs);
    const details: KgGatewayItem[] = await KgShareService.fetchGateway(hashs);
    const info: SharePlaylistInfo = {
      source: SharePlaylistSource.Kg,
      id: link,
      name: meta?.name ?? '',
      coverUrl: (meta?.pic ?? '').replace('{size}', '240'),
      desc: '',
      author: meta?.list_create_username ?? '',
      playCount: 0,
      songs: KgShareService.buildGatewaySongs(details)
    };
    return info;
  }

  private static async fetchZlistPage(url: string, headers: Record<string, string>): Promise<KgRawSong[]> {
    const body: string = await ShareHttpClient.request(url, headers);
    const raw: KgZlistRawResponse = JSON.parse(body) as KgZlistRawResponse;
    return raw?.list?.info ?? [];
  }

  private static async fetchByGcid(gcid: string): Promise<SharePlaylistInfo> {
    const globalId: string = await KgShareService.decodeGcid(gcid);
    return KgShareService.fetchByGlobalId(globalId);
  }

  private static async decodeGcid(gcid: string): Promise<string> {
    const params: string = 'dfid=-&appid=1005&mid=0&clientver=20109&clienttime=640612895&uuid=-';
    const decodeItem: Record<string, Object> = { 'id': gcid, 'id_type': 2 };
    const decodeList: Record<string, Object>[] = [decodeItem];
    const bodyObj: string = JSON.stringify({ 'ret_info': 1, 'data': decodeList });
    const sig: string = await KgShareService.signature(params, 'android', bodyObj);
    const url: string = `https://t.kugou.com/v1/songlist/batch_decode?${params}&signature=${sig}`;
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; HUAWEI HMA-AL00) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.106 Mobile Safari/537.36',
      'Referer': 'https://m.kugou.com/',
      'Content-Type': 'application/json',
    };
    const body: string = await ShareHttpClient.request(url, headers, http.RequestMethod.POST, bodyObj);
    const raw: KgDecodeRawResponse = JSON.parse(body) as KgDecodeRawResponse;
    const list: KgDecodeItem[] = raw?.data?.list ?? [];
    if (list.length === 0 || list[0].global_collection_id === undefined) {
      throw new Error('酷狗歌单解析失败');
    }
    return list[0].global_collection_id;
  }

  private static async fetchByGlobalId(globalId: string): Promise<SharePlaylistInfo> {
    const headers: Record<string, string> = {
      'mid': '1586163242519',
      'Referer': 'https://m3ws.kugou.com/share/index.php',
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1',
      'dfid': '-',
      'clienttime': '1586163242519',
    };
    const infoParams: string =
      `appid=1058&specialid=0&global_specialid=${globalId}&format=jsonp&srcappid=2919&clientver=20000&clienttime=1586163242519&mid=1586163242519&uuid=1586163242519&dfid=-`;
    const infoSig: string = await KgShareService.signature(infoParams, 'web', '');
    const infoUrl: string = `https://mobiles.kugou.com/api/v5/special/info_v2?${infoParams}&signature=${infoSig}`;
    const infoBody: string = await ShareHttpClient.request(infoUrl, headers);
    const infoRaw: KgInfoV2RawResponse = JSON.parse(infoBody) as KgInfoV2RawResponse;
    const info: KgInfoV2Data | undefined = infoRaw?.data;
    if (info == null || info.specialname === undefined) {
      throw new Error('歌单不存在或已被删除');
    }
    const songcount: number = info.songcount ?? 0;
    const pageCount: number = Math.ceil(songcount / 300);
    const pageTasks: Promise<KgSongV2Item[]>[] = [];
    for (let page = 1; page <= pageCount; page++) {
      pageTasks.push(KgShareService.fetchSongV2Page(globalId, page, headers));
    }
    const lists: KgSongV2Item[][] = await Promise.all(pageTasks);
    const hashs: string[] = KgShareService.collectHashs(lists);
    const details: KgGatewayItem[] = await KgShareService.fetchGateway(hashs);
    const result: SharePlaylistInfo = {
      source: SharePlaylistSource.Kg,
      id: globalId,
      name: info.specialname ?? '',
      coverUrl: (info.imgurl ?? '').replace('{size}', '240'),
      desc: info.intro ?? '',
      author: info.nickname ?? '',
      playCount: info.playcount ?? 0,
      songs: KgShareService.buildGatewaySongs(details)
    };
    return result;
  }

  private static async fetchSongV2Page(globalId: string, page: number,
    headers: Record<string, string>): Promise<KgSongV2Item[]> {
    const songParams: string =
      `appid=1058&global_specialid=${globalId}&specialid=0&plat=0&version=8000&page=${page}&pagesize=300&srcappid=2919&clientver=20000&clienttime=1586163263991&mid=1586163263991&uuid=1586163263991&dfid=-`;
    const songSig: string = await KgShareService.signature(songParams, 'web', '');
    const songUrl: string = `https://mobiles.kugou.com/api/v5/special/song_v2?${songParams}&signature=${songSig}`;
    const songBody: string = await ShareHttpClient.request(songUrl, headers);
    const songRaw: KgSongV2RawResponse = JSON.parse(songBody) as KgSongV2RawResponse;
    return songRaw?.data?.info ?? [];
  }

  private static collectHashs(lists: KgSongV2Item[][]): string[] {
    const hashs: string[] = [];
    const seen: Set<string> = new Set<string>();
    for (let i = 0; i < lists.length; i++) {
      const list: KgSongV2Item[] = lists[i];
      for (let j = 0; j < list.length; j++) {
        const h: string = list[j].hash ?? '';
        if (h.length > 0 && !seen.has(h)) {
          seen.add(h);
          hashs.push(h);
        }
      }
    }
    return hashs;
  }

  private static async fetchGateway(hashs: string[]): Promise<KgGatewayItem[]> {
    const result: KgGatewayItem[] = [];
    const headers: Record<string, string> = {
      'KG-THash': '13a3164',
      'KG-RC': '1',
      'KG-Fake': '0',
      'KG-RF': '00869891',
      'User-Agent': 'Android712-AndroidPhone-11451-376-0-FeeCacheUpdate-wifi',
      'x-router': 'kmr.service.kugou.com',
      'Content-Type': 'application/json',
    };
    for (let i = 0; i < hashs.length; i += 100) {
      const batch: Record<string, Object>[] = [];
      const end: number = i + 100 < hashs.length ? i + 100 : hashs.length;
      for (let j = i; j < end; j++) {
        batch.push({ 'hash': hashs[j] });
      }
      const bodyObj: string = JSON.stringify({
        'data': batch,
        'area_code': '1',
        'show_privilege': 1,
        'show_album_info': 1,
        'is_publish': '',
        'appid': 1005,
        'clientver': 11451,
        'mid': '1',
        'dfid': '-',
        'clienttime': Date.now(),
        'key': 'OIlwieks28dk2k092lksi2UIkp',
        'fields': 'album_info,author_name,audio_info,ori_audio_name,base,songname',
      });
      const body: string = await ShareHttpClient.request('http://gateway.kugou.com/v2/album_audio/audio',
        headers, http.RequestMethod.POST, bodyObj);
      const raw: KgGatewayRawResponse = JSON.parse(body) as KgGatewayRawResponse;
      const groups: KgGatewayItem[][] = raw?.data ?? [];
      for (let k = 0; k < groups.length; k++) {
        const group: KgGatewayItem[] = groups[k];
        if (group.length > 0 && group[0] != null) {
          result.push(group[0]);
        }
      }
    }
    return result;
  }

  private static buildGatewaySongs(details: KgGatewayItem[]): SharePlaylistSong[] {
    const songs: SharePlaylistSong[] = [];
    for (let i = 0; i < details.length; i++) {
      const item: KgGatewayItem = details[i];
      songs.push({
        id: item.hash ?? item.audio_info?.audio_id ?? '',
        name: item.songname ?? '',
        artist: item.author_name ?? '',
        album: item.album_info?.album_name ?? '',
        duration: Math.floor(Number(item.audio_info?.timelength ?? '0') / 1000)
      });
    }
    return songs;
  }

  private static async signature(params: string, platform: string, body: string): Promise<string> {
    let key: string = 'OIlwieks28dk2k092lksi2UIkp';
    if (platform === 'web') {
      key = 'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt';
    }
    const parts: string[] = params.split('&');
    parts.sort();
    const signText: string = `${key}${parts.join('')}${body}${key}`;
    return KgShareService.md5Hex(signText);
  }

  private static md5Hex(text: string): string {
    const encoder: util.TextEncoder = new util.TextEncoder();
    return Md5.hex(encoder.encodeInto(text));
  }
}
