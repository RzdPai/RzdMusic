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
  /** 歌单拥有者 userid（`collection_3_<suid>_<slid>_0` 的第二段）。 */
  suid?: number;
  global_specialid?: string;
}

interface KgSongV2RawResponse {
  data?: KgSongV2Data;
}

interface KgSongV2Data {
  total?: number;
  info?: KgSongV2Item[];
}

interface KgSongV2Item {
  hash?: string;
  /** 形如 `陈奕迅 - 十年`：歌手在前、歌名在后，空格-空格分隔。 */
  filename?: string;
  /** 时长（**秒**，不是毫秒）。 */
  duration?: number;
  album_id?: string | number;
  trans_param?: KgTransParam;
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
  sizable_cover?: string;
  cover?: string;
}

interface KgGatewayAudio {
  audio_id?: string;
  timelength?: string;
}

/**
 * `https://m.kugou.com/songlist/<gcid>/` 服务端注入的 `window.$output` JSON。
 *
 * 这是**唯一不需要签名**的酷狗歌单数据来源（真机/PC 均实测 200 且含数据），
 * 但它只内联**前 10 首**，且 `listinfo.global_collection_id` 常为空 ⇒
 * 只用来取"歌单名/封面/作者/拥有者 userid/is_def"，曲目仍走签名接口。
 */
interface KgHtmlOutput {
  encode_gic?: string;
  info?: KgHtmlInfo;
  global_collection_id?: string;
}

interface KgHtmlInfo {
  listinfo?: KgHtmlListInfo;
  songs?: KgHtmlSong[];
}

interface KgHtmlListInfo {
  name?: string;
  pic?: string;
  count?: number;
  intro?: string;
  is_def?: number;
  list_create_userid?: number;
  list_create_username?: string;
  global_collection_id?: string;
}

interface KgHtmlSong {
  hash?: string;
  name?: string;
  timelen?: number;
  cover?: string;
  albuminfo?: KgHtmlAlbum;
  trans_param?: KgTransParam;
}

interface KgHtmlAlbum {
  name?: string;
}

interface KgTransParam {
  union_cover?: string;
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
  /** `https://t1.kugou.com/76Kuhf5G6V2` / `https://t.kugou.com/xxx`（`t` 后面可能带数字）。 */
  private static readonly shortLinkRegex: RegExp = new RegExp('^https?://t\\d*\\.kugou\\.com/[A-Za-z0-9]+');
  private static readonly gcidAnyRegex: RegExp = new RegExp('gcid_[A-Za-z0-9]+');
  private static readonly collectionAnyRegex: RegExp = new RegExp('collection_\\d+_\\d+_\\d+_\\d+');
  /** H5 接口的 Web 盐（`infSign.min.js`，与无界 `KgSonglist.signatureParams` 同一份）。 */
  private static readonly webSalt: string = 'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt';
  /** 进程级稳定的 32 位 hex mid：接口按 header 取它，值不重要但必须每次一致。 */
  private static kgMid: string = '';

  static async fetch(rawId: string): Promise<SharePlaylistInfo> {
    const id: string = rawId.trim();
    if (id.length === 0) {
      throw new Error('无法解析歌单链接');
    }
    // ★ 短链 `https://t1.kugou.com/76Kuhf5G6V2`（也有 `t.kugou.com/xxx` 形态）。
    //   以前两种形态都不匹配：`chainRegex2` 写死 `t\.kugou\.com`，`t1.` 漏掉；
    //   于是掉进末尾的"通用重定向"分支 —— 而 302 目标是 `activity.kugou.com` 的纯 SPA
    //   （HTML 里没有任何内联数据，见项目记忆 §199）⇒ 必然"无法解析酷狗链接"。
    if (KgShareService.shortLinkRegex.test(id)) {
      return KgShareService.fetchByShortLink(id);
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
        duration: Math.floor((t.duration ?? 0) / 1000),
        img: ''
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

  /**
   * `gcid_xxx` 形态（`https://m.kugou.com/songlist/gcid_3ztkscspz1z09d/?src_cid=…`）。
   *
   * 三级兜底（2026-11-03 实测）：
   * ① `m.kugou.com/songlist/<gcid>/` 的 `window.$output`（**免签名**）：拿到歌单名/封面/作者，以及
   *    `list_create_userid` + `is_def`。`is_def=1` = 该用户的「默认收藏」⇒ 反推
   *    `collection_3_<userid>_1_0`，再用签名接口取**全量**（实测 66 首一次拿全）。
   * ② `batch_decode`（旧路，签名算法已对但服务端一直回 20006，见记忆 §195–§199）。
   * ③ `$output` 里内联的前 10 首（**预览**），只有前两级都失败才用，并在 `desc` 里说明。
   */
  private static async fetchByGcid(gcid: string): Promise<SharePlaylistInfo> {
    const html: KgHtmlOutput | undefined = await KgShareService.fetchHtmlOutput(gcid);
    const listInfo: KgHtmlListInfo | undefined = html?.info?.listinfo;
    const htmlSongs: SharePlaylistSong[] = KgShareService.buildHtmlOutputSongs(html?.info?.songs ?? []);
    const ownerId: number = listInfo?.list_create_userid ?? 0;
    const isDefaultList: boolean = (listInfo?.is_def ?? 0) === 1;
    if (isDefaultList && ownerId > 0) {
      const collectionId: string = `collection_3_${ownerId}_1_0`;
      try {
        const full: SharePlaylistInfo = await KgShareService.fetchByGlobalId(collectionId);
        if (full.songs.length > 0) {
          return full;
        }
      } catch (e) {
        // 反推出来的 id 不成立就往下走，不要让整次导入失败
      }
    }
    try {
      const globalId: string = await KgShareService.decodeGcid(gcid);
      if (globalId.length > 0) {
        return await KgShareService.fetchByGlobalId(globalId);
      }
    } catch (e) {
      // 签名接口可能 20006（服务端不认这套盐），落到 ③
    }
    if (htmlSongs.length > 0) {
      const previewName: string = listInfo?.name ?? '';
      return {
        source: SharePlaylistSource.Kg,
        id: gcid,
        name: previewName,
        coverUrl: (listInfo?.pic ?? '').replace('{size}', '240'),
        desc: '分享页只给了前 10 首预览',
        author: listInfo?.list_create_username ?? '',
        playCount: 0,
        songs: htmlSongs
      };
    }
    throw new Error('这个酷狗歌单打不开');
  }

  /** 拉 `m.kugou.com/songlist/<gcid>/` 并解析 `window.$output`；任何失败都返回 undefined。 */
  private static async fetchHtmlOutput(gcid: string): Promise<KgHtmlOutput | undefined> {
    const headers: Record<string, string> = {
      'User-Agent': KgShareService.mobileHeaders['User-Agent'],
      'Referer': 'https://m.kugou.com/',
    };
    try {
      const html: string = await ShareHttpClient.request(
        `https://m.kugou.com/songlist/${gcid}/`, headers, http.RequestMethod.GET, '', 1);
      const json: string = KgShareService.extractOutputJson(html);
      if (json.length === 0) {
        return undefined;
      }
      return JSON.parse(json) as KgHtmlOutput;
    } catch (e) {
      return undefined;
    }
  }

  /**
   * 从页面里抠出 `window.$output = {…}` 的 JSON 文本。
   *
   * ⚠️ **不能用正则** `\{[\s\S]*?\};`：JSON 里含 `\/` 转义与长字符串，非贪婪匹配会截断在
   * 第一个 `};`（可能出现在某个字符串内）⇒ `JSON.parse` 直接炸。这里做**花括号配平**，
   * 并跳过字符串内的括号。
   */
  private static extractOutputJson(html: string): string {
    const anchor: string = 'window.$output';
    const at: number = html.indexOf(anchor);
    if (at < 0) {
      return '';
    }
    const start: number = html.indexOf('{', at);
    if (start < 0) {
      return '';
    }
    let depth: number = 0;
    let inString: boolean = false;
    let escaped: boolean = false;
    for (let i: number = start; i < html.length; i++) {
      const ch: string = html.charAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch === '\\') {
          escaped = true;
        } else if (ch === '"') {
          inString = false;
        }
        continue;
      }
      if (ch === '"') {
        inString = true;
        continue;
      }
      if (ch === '{') {
        depth++;
        continue;
      }
      if (ch === '}') {
        depth--;
        if (depth === 0) {
          return html.substring(start, i + 1);
        }
      }
    }
    return '';
  }

  /** 把 `$output.info.songs` 转成导入用的曲目（`name` 形如 `歌手 - 歌名`，`timelen` 是毫秒）。 */
  private static buildHtmlOutputSongs(rawList: KgHtmlSong[]): SharePlaylistSong[] {
    const songs: SharePlaylistSong[] = [];
    for (let i: number = 0; i < rawList.length; i++) {
      const item: KgHtmlSong = rawList[i];
      const hash: string = item.hash ?? '';
      if (hash.length === 0) {
        continue;
      }
      const parts: string[] = KgShareService.splitFileName(item.name ?? '');
      const cover: string = (item.trans_param?.union_cover ?? item.cover ?? '').replace('{size}', '240');
      const ms: number = item.timelen ?? 0;
      songs.push({
        id: hash,
        name: parts[1],
        artist: parts[0],
        album: item.albuminfo?.name ?? '',
        duration: Math.floor(ms / 1000),
        img: cover
      });
    }
    return songs;
  }

  /**
   * 短链：`https://t1.kugou.com/76Kuhf5G6V2` → 302 → `activity.kugou.com/share/…&global_specialid=collection_…`。
   *
   * @ohos 的 `http` 对 GET 会在 `header['location']` 里给出跳转目标（实测，见记忆 §195）；
   * 若被自动跟随（没有 location），再从响应体里找 `global_specialid=` / `gcid_`。
   */
  private static async fetchByShortLink(link: string): Promise<SharePlaylistInfo> {
    let finalUrl: string = '';
    try {
      const client = http.createHttp();
      const requestHeaders: Record<string, string> = {
        'User-Agent': KgShareService.mobileHeaders['User-Agent'],
      };
      try {
        const resp: http.HttpResponse = await client.request(link, {
          method: http.RequestMethod.GET,
          header: requestHeaders,
          connectTimeout: 8000,
          readTimeout: 8000,
          expectDataType: http.HttpDataType.STRING,
        });
        const headers: Record<string, string> = resp.header as Record<string, string>;
        finalUrl = headers['location'] ?? headers['Location'] ?? '';
        if (finalUrl.length === 0 && typeof resp.result === 'string') {
          finalUrl = resp.result as string;
        }
      } finally {
        client.destroy();
      }
    } catch (e) {
      throw new Error('酷狗短链请求失败（网络或链接已失效）');
    }
    const gcidMatch: RegExpExecArray | null = KgShareService.gcidAnyRegex.exec(finalUrl);
    if (gcidMatch !== null && gcidMatch.length > 0) {
      return KgShareService.fetchByGcid(gcidMatch[0]);
    }
    const gidMatch: RegExpExecArray | null = KgShareService.globalCollectionIdRegex.exec(finalUrl);
    if (gidMatch !== null && gidMatch.length > 1) {
      return KgShareService.fetchByGlobalId(gidMatch[1]);
    }
    const collectionMatch: RegExpExecArray | null = KgShareService.collectionAnyRegex.exec(finalUrl);
    if (collectionMatch !== null && collectionMatch.length > 0) {
      return KgShareService.fetchByGlobalId(collectionMatch[0]);
    }
    throw new Error('这个酷狗短链里没有歌单信息');
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

  /**
   * `global_specialid`（形如 `collection_3_1554363080_1_0`）→ 歌单信息 + 全量曲目。
   *
   * ★★★ 2026-11-03 实测订正（此前一直 1001 / 20006 的真因）：
   * 服务端是**按 header 取 `mid`/`dfid`/`clienttime`** 的（`mid` 缺失时报
   * `bad type, key: mid (string expected, got nil)`），旧实现把这三个塞进 query 又一起签名 ⇒ 永远 1001。
   * 现在的口径（与无界 `KgSonglist.signatureParams` 逐字一致，且本机实测通）：
   * ```
   *   headers: mid=<32 位 hex>、dfid=-、clienttime=<now>
   *   query  : appid=1058 & … & clienttime=<now> & mid=<同上> & uuid=<同上> & dfid=-
   *   signature = md5(盐 + 排序后的 "k=v" 拼接 + 盐)，盐 = NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt
   * ```
   * 曲目走 `song_v2`（`pagesize=300` 一页，实测 66 首一次拿全），**不再调 `gateway/v2/album_audio`
   * 补详情**——那个接口要 app 侧签名，实测直接 `20006 sign error`。
   * 排查关键字：见 `SharePlaylistInfo.desc` 与调用方 toast。
   */
  private static async fetchByGlobalId(globalId: string): Promise<SharePlaylistInfo> {
    const mid: string = KgShareService.newKgMid();
    const clienttime: string = `${Date.now()}`;
    const headers: Record<string, string> = KgShareService.webHeaders(mid, clienttime);
    const infoParams: string =
      `appid=1058&specialid=0&global_specialid=${globalId}&format=jsonp&srcappid=2919&clientver=20000` +
        `&clienttime=${clienttime}&mid=${mid}&uuid=${mid}&dfid=-`;
    const infoSig: string = await KgShareService.signature(infoParams, 'web', '');
    const infoUrl: string = `https://mobiles.kugou.com/api/v5/special/info_v2?${infoParams}&signature=${infoSig}`;
    const infoBody: string = await ShareHttpClient.request(infoUrl, headers);
    const infoRaw: KgInfoV2RawResponse = JSON.parse(infoBody) as KgInfoV2RawResponse;
    const info: KgInfoV2Data | undefined = infoRaw?.data;
    if (info == null || info.specialname === undefined) {
      throw new Error('歌单不存在或已被删除');
    }
    const songcount: number = info.songcount ?? 0;
    const pageCount: number = songcount > 0 ? Math.ceil(songcount / 300) : 1;
    const rawSongs: KgSongV2Item[] = [];
    for (let page: number = 1; page <= pageCount; page++) {
      const list: KgSongV2Item[] = await KgShareService.fetchSongV2Page(globalId, page, mid);
      for (let i: number = 0; i < list.length; i++) {
        rawSongs.push(list[i]);
      }
      if (list.length === 0) {
        break;
      }
    }
    const result: SharePlaylistInfo = {
      source: SharePlaylistSource.Kg,
      id: globalId,
      name: info.specialname ?? '',
      coverUrl: (info.imgurl ?? '').replace('{size}', '240'),
      desc: info.intro ?? '',
      author: info.nickname ?? '',
      playCount: info.playcount ?? 0,
      songs: KgShareService.buildSongV2Songs(rawSongs)
    };
    return result;
  }

  private static async fetchSongV2Page(globalId: string, page: number, mid: string): Promise<KgSongV2Item[]> {
    const clienttime: string = `${Date.now()}`;
    const headers: Record<string, string> = KgShareService.webHeaders(mid, clienttime);
    const songParams: string =
      `appid=1058&global_specialid=${globalId}&specialid=0&plat=0&version=8000&page=${page}&pagesize=300` +
        `&srcappid=2919&clientver=20000&clienttime=${clienttime}&mid=${mid}&uuid=${mid}&dfid=-`;
    const songSig: string = await KgShareService.signature(songParams, 'web', '');
    const songUrl: string = `https://mobiles.kugou.com/api/v5/special/song_v2?${songParams}&signature=${songSig}`;
    const songBody: string = await ShareHttpClient.request(songUrl, headers);
    const songRaw: KgSongV2RawResponse = JSON.parse(songBody) as KgSongV2RawResponse;
    return songRaw?.data?.info ?? [];
  }

  /** H5 接口要求的头：`mid`/`dfid`/`clienttime` 必须在这里（query 里那份不参与取值）。 */
  private static webHeaders(mid: string, clienttime: string): Record<string, string> {
    return {
      'mid': mid,
      'dfid': '-',
      'clienttime': clienttime,
      'Referer': 'https://m.kugou.com/',
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15' +
        ' (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    };
  }

  /** @returns 进程内稳定的 32 位 hex mid（接口只要求字符串，但固定下来签名口径才稳定）。 */
  private static newKgMid(): string {
    if (KgShareService.kgMid.length === 32) {
      return KgShareService.kgMid;
    }
    let out: string = '';
    const hexChars: string = '0123456789abcdef';
    for (let i: number = 0; i < 32; i++) {
      const idx: number = Math.floor(Math.random() * 16);
      out += hexChars.charAt(idx);
    }
    KgShareService.kgMid = out;
    return out;
  }

  /** `陈奕迅 - 十年` → `['陈奕迅', '十年']`（按**最后**一个 ` - ` 切，歌名里本身可能带连字符）。 */
  private static splitFileName(fileName: string): string[] {
    const sep: string = ' - ';
    const at: number = fileName.lastIndexOf(sep);
    if (at <= 0 || at + sep.length >= fileName.length) {
      return ['', fileName];
    }
    return [fileName.substring(0, at), fileName.substring(at + sep.length)];
  }

  /** `song_v2` 的原始项 → 导入用曲目（`filename`/`hash`/`duration` 秒/`union_cover`）。 */
  private static buildSongV2Songs(rawList: KgSongV2Item[]): SharePlaylistSong[] {
    const songs: SharePlaylistSong[] = [];
    for (let i: number = 0; i < rawList.length; i++) {
      const item: KgSongV2Item = rawList[i];
      const hash: string = item.hash ?? '';
      if (hash.length === 0) {
        continue;
      }
      const parts: string[] = KgShareService.splitFileName(item.filename ?? '');
      const cover: string = (item.trans_param?.union_cover ?? '').replace('{size}', '240');
      songs.push({
        id: hash,
        name: parts[1],
        artist: parts[0],
        album: '',
        duration: item.duration ?? 0,
        img: cover
      });
    }
    return songs;
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
      let pic: string = item.album_info?.sizable_cover ?? item.album_info?.cover ?? '';
      if (pic.length > 0) {
        pic = pic.replace('{size}', '240');
      }
      songs.push({
        id: item.hash ?? item.audio_info?.audio_id ?? '',
        name: item.songname ?? '',
        artist: item.author_name ?? '',
        album: item.album_info?.album_name ?? '',
        duration: Math.floor(Number(item.audio_info?.timelength ?? '0') / 1000),
        img: pic
      });
    }
    return songs;
  }

  private static async signature(params: string, platform: string, body: string): Promise<string> {
    const key: string = platform === 'web'
      ? KgShareService.webSalt
      : 'OIlwieks28dk2k092lksi2UIkp';
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
