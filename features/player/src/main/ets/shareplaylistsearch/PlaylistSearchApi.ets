import { SearchPlaylistInfo, SearchPlaylistSong, fmtDuration } from './PlaylistSearchTypes';
import { PlaylistSearchHttp, numOf, strOf, toHttps, fixSingleQuoteJson } from './PlaylistSearchHttp';

const WY_SEARCH_LIMIT: number = 30;
const TX_PLAYLIST_PAGE_SIZE: number = 20;
const KW_PLAYLIST_PAGE_SIZE: number = 20;
const KG_PLAYLIST_PAGE_SIZE: number = 20;
const MG_PLAYLIST_PAGE_SIZE: number = 20;

const MG_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15',
  'Referer': 'https://m.music.migu.cn/'
};

const KW_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  'Referer': 'http://www.kuwo.cn/'
};

const TX_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  'Origin': 'https://y.qq.com',
  'Referer': 'https://y.qq.com/'
};

const KG_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
};

/**
 * 酷狗歌单详情专用请求头 + 分页参数。
 *
 * 接口 `mobilecdn.kugou.com/api/v3/special/song` 是移动端明文接口（实测可用），
 * 每页上限 100 条；`KG_DETAIL_MAX_PAGES * KG_DETAIL_PAGE_SIZE` 是单次加载的歌曲上限。
 */
const KG_DETAIL_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Linux; Android 12)',
  'Referer': 'https://m.kugou.com/'
};
const KG_DETAIL_PAGE_SIZE: number = 100;
const KG_DETAIL_MAX_PAGES: number = 10;

export class PlaylistSearchApi {
  static supportsPlaylists(source: string): boolean {
    return source === 'all' || source === 'wy' || source === 'tx' || source === 'kw' ||
      source === 'kg' || source === 'mg';
  }

  static async searchPlaylists(source: string, keyword: string, page: number): Promise<SearchPlaylistInfo[]> {
    if (source === 'all') {
      return PlaylistSearchApi.searchAllPlaylists(keyword, page);
    }
    if (source === 'wy') {
      return PlaylistSearchApi.wySearchPlaylists(keyword, page);
    }
    if (source === 'tx') {
      return PlaylistSearchApi.txSearchPlaylists(keyword, page);
    }
    if (source === 'kw') {
      return PlaylistSearchApi.kwSearchPlaylists(keyword, page);
    }
    if (source === 'kg') {
      return PlaylistSearchApi.kgSearchPlaylists(keyword, page);
    }
    if (source === 'mg') {
      return PlaylistSearchApi.mgSearchPlaylists(keyword, page);
    }
    const empty: SearchPlaylistInfo[] = [];
    return empty;
  }

  static async getPlaylistDetail(source: string, id: string): Promise<SearchPlaylistSong[]> {
    if (source === 'wy') {
      return PlaylistSearchApi.wyPlaylistDetail(id);
    }
    if (source === 'tx') {
      return PlaylistSearchApi.txPlaylistDetail(id);
    }
    if (source === 'kw') {
      return PlaylistSearchApi.kwPlaylistDetail(id);
    }
    if (source === 'kg') {
      return PlaylistSearchApi.kgPlaylistDetail(id);
    }
    if (source === 'mg') {
      return PlaylistSearchApi.mgPlaylistDetail(id);
    }
    const empty: SearchPlaylistSong[] = [];
    return empty;
  }

  private static async searchAllPlaylists(keyword: string, page: number): Promise<SearchPlaylistInfo[]> {
    const sources: string[] = ['wy', 'tx', 'kw', 'kg', 'mg'];
    const merged: SearchPlaylistInfo[] = [];
    const tasks: Promise<void>[] = [];
    for (let i = 0; i < sources.length; i++) {
      tasks.push(PlaylistSearchApi.searchPlaylists(sources[i], keyword, page).then((list: SearchPlaylistInfo[]) => {
        for (let j = 0; j < list.length; j++) {
          merged.push(list[j]);
        }
      }).catch((e: Error) => {
      }));
    }
    await Promise.all(tasks);
    return merged;
  }

  private static async wySearchPlaylists(keyword: string, page: number): Promise<SearchPlaylistInfo[]> {
    const url: string = 'https://music.163.com/api/search/get' +
      `?s=${encodeURIComponent(keyword)}&type=1000&limit=${WY_SEARCH_LIMIT}&offset=${(page - 1) * WY_SEARCH_LIMIT}`;
    const text: string = await PlaylistSearchHttp.getText(url, {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://music.163.com/'
    });
    const list: SearchPlaylistInfo[] = [];
    if (text === '') {
      return list;
    }
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const result: Record<string, Object> = root['result'] as Record<string, Object>;
    if (result === undefined || result === null) {
      return list;
    }
    const playlists: Object[] = result['playlists'] as Object[] ?? [];
    for (let i = 0; i < playlists.length; i++) {
      const item: Record<string, Object> = playlists[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const id: number = numOf(item, 'id');
      if (id === 0) {
        continue;
      }
      const creator: Record<string, Object> = item['creator'] as Record<string, Object>;
      const creatorName: string = creator === undefined || creator === null ? '' : strOf(creator, 'nickname');
      list.push(SearchPlaylistInfo.of(String(id), strOf(item, 'name'), numOf(item, 'playCount'),
        numOf(item, 'trackCount'), toHttps(strOf(item, 'coverImgUrl')), creatorName, 'wy'));
    }
    return list;
  }

  /**
   * 网易云歌单详情。
   * detail 的 tracks 常被截断；用 track/all 分页 + trackIds 批量 song/detail 补全。
   */
  private static async wyPlaylistDetail(id: string): Promise<SearchPlaylistSong[]> {
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://music.163.com/'
    };
    const url: string = `https://music.163.com/api/v6/playlist/detail?id=${id}&n=100000&s=8`;
    const textBody: string = await PlaylistSearchHttp.getText(url, headers, 30000);
    const list: SearchPlaylistSong[] = [];
    if (textBody === '') {
      return list;
    }
    let root: Record<string, Object>;
    try {
      root = JSON.parse(textBody) as Record<string, Object>;
    } catch (_e) {
      return list;
    }
    const playlist: Record<string, Object> = root['playlist'] as Record<string, Object>;
    if (playlist === undefined || playlist === null) {
      return list;
    }
    let tracks: Object[] = playlist['tracks'] as Object[] ?? [];
    const trackIdsRaw: Object[] = playlist['trackIds'] as Object[] ?? [];
    const expected: number = trackIdsRaw.length > tracks.length ? trackIdsRaw.length : tracks.length;

    if (tracks.length < expected) {
      const paged: Object[] = await PlaylistSearchApi.wyFetchTracksAll(id, headers, expected);
      if (paged.length > tracks.length) {
        tracks = paged;
      }
    }
    if (tracks.length < expected && trackIdsRaw.length > tracks.length) {
      try {
        const byIds: Object[] = await PlaylistSearchApi.wyFetchSongsByIds(trackIdsRaw, headers);
        if (byIds.length > tracks.length) {
          tracks = byIds;
        }
      } catch (_e) {
      }
    }

    const seen: Record<string, boolean> = {};
    for (let i = 0; i < tracks.length; i++) {
      const item: Record<string, Object> = tracks[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const idN: number = numOf(item, 'id');
      if (idN === 0) {
        continue;
      }
      const sid: string = String(idN);
      if (seen[sid]) {
        continue;
      }
      seen[sid] = true;
      const artists: Object[] = (item['ar'] as Object[] ?? item['artists'] as Object[]) ?? [];
      const names: string[] = [];
      for (let j = 0; j < artists.length; j++) {
        const ar: Record<string, Object> = artists[j] as Record<string, Object>;
        if (ar !== null) {
          const an: string = strOf(ar, 'name');
          if (an.length > 0) {
            names.push(an);
          }
        }
      }
      const album: Record<string, Object> =
        (item['al'] as Record<string, Object>) ?? (item['album'] as Record<string, Object>);
      const albumName: string = album === undefined || album === null ? '' : strOf(album, 'name');
      const picUrl: string = album === undefined || album === null ? '' :
        toHttps(strOf(album, 'picUrl'));
      const durationMs: number = numOf(item, 'dt') || numOf(item, 'duration');
      list.push(SearchPlaylistSong.of(sid, strOf(item, 'name'), names.join(' / '),
        albumName, fmtDuration(durationMs / 1000), 'wy', picUrl));
    }
    return list;
  }

  private static async wyFetchTracksAll(id: string, headers: Record<string, string>,
    need: number): Promise<Object[]> {
    const out: Object[] = [];
    const pageSize: number = 1000;
    let offset: number = 0;
    while (offset < need && offset < 20000) {
      const pageUrl: string =
        `https://music.163.com/api/playlist/track/all?id=${id}&limit=${pageSize}&offset=${offset}`;
      let page: Object[] = [];
      try {
        const body: string = await PlaylistSearchHttp.getText(pageUrl, headers, 30000);
        if (body === '') {
          break;
        }
        const raw: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
        page = (raw['songs'] as Object[]) ?? [];
      } catch (_e) {
        break;
      }
      for (let i = 0; i < page.length; i++) {
        out.push(page[i]);
      }
      if (page.length < pageSize) {
        break;
      }
      offset += pageSize;
    }
    return out;
  }

  private static async wyFetchSongsByIds(trackIds: Object[],
    headers: Record<string, string>): Promise<Object[]> {
    const result: Object[] = [];
    for (let i = 0; i < trackIds.length; i += 100) {
      const ids: number[] = [];
      const end: number = i + 100 < trackIds.length ? i + 100 : trackIds.length;
      for (let j = i; j < end; j++) {
        const tid: Record<string, Object> = trackIds[j] as Record<string, Object>;
        if (tid === null) {
          continue;
        }
        const sid: number = numOf(tid, 'id');
        if (sid > 0) {
          ids.push(sid);
        }
      }
      if (ids.length === 0) {
        continue;
      }
      const detailUrl: string =
        `https://music.163.com/api/song/detail?ids=${encodeURIComponent(JSON.stringify(ids))}`;
      try {
        const body: string = await PlaylistSearchHttp.getText(detailUrl, headers, 20000);
        if (body === '') {
          continue;
        }
        const raw: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
        const songs: Object[] = (raw['songs'] as Object[]) ?? [];
        for (let k = 0; k < songs.length; k++) {
          result.push(songs[k]);
        }
      } catch (_e) {
      }
    }
    return result;
  }

  private static async txSearchPlaylists(keyword: string, page: number): Promise<SearchPlaylistInfo[]> {
    const url: string =
      `https://c.y.qq.com/soso/fcgi-bin/client_music_search_songlist?page_no=${page - 1}&num_per_page=${TX_PLAYLIST_PAGE_SIZE}` +
      `&format=json&query=${encodeURIComponent(keyword)}&remoteplace=txt.yqq.playlist&inCharset=utf8&outCharset=utf-8`;
    const text: string = await PlaylistSearchHttp.getText(url, TX_HEADERS);
    const list: SearchPlaylistInfo[] = [];
    if (text === '') {
      return list;
    }
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const data: Record<string, Object> = root['data'] as Record<string, Object>;
    if (data === undefined || data === null) {
      return list;
    }
    const items: Object[] = data['list'] as Object[] ?? [];
    for (let i = 0; i < items.length; i++) {
      const item: Record<string, Object> = items[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const id: number = numOf(item, 'dissid');
      if (id === 0) {
        continue;
      }
      const creator: Record<string, Object> = item['creator'] as Record<string, Object>;
      const creatorName: string = creator === undefined || creator === null ? '' : strOf(creator, 'name');
      list.push(SearchPlaylistInfo.of(String(id), strOf(item, 'dissname'), numOf(item, 'listennum'),
        numOf(item, 'song_count'), toHttps(strOf(item, 'imgurl')), creatorName, 'tx'));
    }
    return list;
  }

  /**
   * QQ 歌单详情。getcdinfo 在部分网络/热门歌单会空返回，失败则走 musicu CgiGetDiss。
   */
  private static async txPlaylistDetail(id: string): Promise<SearchPlaylistSong[]> {
    let songs: Object[] = await PlaylistSearchApi.txSongsViaGetCdInfo(id);
    if (songs.length === 0) {
      songs = await PlaylistSearchApi.txSongsViaCgiGetDiss(id);
    }
    return PlaylistSearchApi.txMapSongs(songs);
  }

  private static txDetailHeaders(id: string): Record<string, string> {
    return {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Origin': 'https://y.qq.com',
      'Referer': `https://y.qq.com/n/yqq/playsquare/${id}.html`
    };
  }

  private static async txSongsViaGetCdInfo(id: string): Promise<Object[]> {
    const hosts: string[] = ['c.y.qq.com', 'i.y.qq.com'];
    const empty: Object[] = [];
    for (let h = 0; h < hosts.length; h++) {
      const url: string =
        `https://${hosts[h]}/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg?type=1&json=1&utf8=1&onlysong=0&new_format=1` +
        `&disstid=${id}&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=0`;
      try {
        const body: string = await PlaylistSearchHttp.getText(url, PlaylistSearchApi.txDetailHeaders(id), 30000);
        if (body === '') {
          continue;
        }
        const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
        const cdlist: Object[] = root['cdlist'] as Object[] ?? [];
        if (cdlist.length === 0) {
          continue;
        }
        const cd: Record<string, Object> = cdlist[0] as Record<string, Object>;
        if (cd === null) {
          continue;
        }
        const songs: Object[] = cd['songlist'] as Object[] ?? [];
        if (songs.length > 0) {
          return songs;
        }
      } catch (_e) {
      }
    }
    return empty;
  }

  private static async txSongsViaCgiGetDiss(id: string): Promise<Object[]> {
    const empty: Object[] = [];
    const numericId: number = Number(id);
    const disstidParam: string = Number.isFinite(numericId) && numericId > 0 ?
      String(Math.trunc(numericId)) : `"${id}"`;
    const body: string =
      `{"req_0":{"module":"srf_diss_info.DissInfoServer","method":"CgiGetDiss",` +
      `"param":{"disstid":${disstidParam},"userinfo":1,"tag":1}},` +
      `"comm":{"g_tk":5381,"uin":0,"format":"json","ct":20,"cv":0}}`;
    try {
      const textBody: string = await PlaylistSearchHttp.postText(
        'https://u.y.qq.com/cgi-bin/musicu.fcg', body, {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://y.qq.com/',
          'Origin': 'https://y.qq.com',
          'Content-Type': 'application/json'
        }, 30000);
      if (textBody === '') {
        return empty;
      }
      const root: Record<string, Object> = JSON.parse(textBody) as Record<string, Object>;
      const req0: Record<string, Object> = root['req_0'] as Record<string, Object>;
      if (req0 === undefined || req0 === null) {
        return empty;
      }
      const data: Record<string, Object> = req0['data'] as Record<string, Object>;
      if (data === undefined || data === null) {
        return empty;
      }
      return data['songlist'] as Object[] ?? empty;
    } catch (_e) {
      return empty;
    }
  }

  private static txMapSongs(songs: Object[]): SearchPlaylistSong[] {
    const list: SearchPlaylistSong[] = [];
    for (let i = 0; i < songs.length; i++) {
      const item: Record<string, Object> = songs[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      let mid: string = strOf(item, 'mid');
      if (mid === '') {
        mid = strOf(item, 'songmid');
      }
      if (mid === '') {
        continue;
      }
      const singersArr: Object[] = item['singer'] as Object[] ?? [];
      const singerNames: string[] = [];
      for (let j = 0; j < singersArr.length; j++) {
        const sg: Record<string, Object> = singersArr[j] as Record<string, Object>;
        if (sg !== null) {
          const sn: string = strOf(sg, 'name');
          if (sn.length > 0) {
            singerNames.push(sn);
          }
        }
      }
      const album: Record<string, Object> = item['album'] as Record<string, Object>;
      let albumName: string = '';
      let albumMid: string = '';
      if (album !== undefined && album !== null) {
        albumName = strOf(album, 'name');
        albumMid = strOf(album, 'mid');
        if (albumMid === '') {
          albumMid = strOf(album, 'pmid');
        }
      }
      if (albumName === '') {
        albumName = strOf(item, 'albumname');
      }
      if (albumMid === '') {
        albumMid = strOf(item, 'albummid');
      }
      const picUrl: string = albumMid === '' ? '' :
        `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumMid}.jpg`;
      let name: string = strOf(item, 'name');
      if (name === '') {
        name = strOf(item, 'songname');
      }
      if (name === '') {
        name = strOf(item, 'title');
      }
      list.push(SearchPlaylistSong.of(mid, name, singerNames.join(' / '),
        albumName, fmtDuration(numOf(item, 'interval')), 'tx', picUrl));
    }
    return list;
  }

  private static async kwSearchPlaylists(keyword: string, page: number): Promise<SearchPlaylistInfo[]> {
    const url: string =
      `http://search.kuwo.cn/r.s?all=${encodeURIComponent(keyword)}&pn=${page - 1}&rn=${KW_PLAYLIST_PAGE_SIZE}` +
      `&rformat=json&encoding=utf8&ver=mbox&vipver=MUSIC_8.7.7.0_BCS37&plat=pc&devid=28156413&ft=playlist&pay=0&needliveshow=0`;
    const text: string = await PlaylistSearchHttp.getText(url, KW_HEADERS);
    const list: SearchPlaylistInfo[] = [];
    if (text === '') {
      return list;
    }
    const root: Record<string, Object> = JSON.parse(fixSingleQuoteJson(text)) as Record<string, Object>;
    const items: Object[] = root['abslist'] as Object[] ?? [];
    for (let i = 0; i < items.length; i++) {
      const item: Record<string, Object> = items[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const id: string = strOf(item, 'playlistid');
      if (id === '') {
        continue;
      }
      let pic: string = strOf(item, 'pic');
      if (pic === '') {
        pic = strOf(item, 'hts_pic');
      }
      list.push(SearchPlaylistInfo.of(id, strOf(item, 'name'), numOf(item, 'playcnt'),
        numOf(item, 'songnum'), toHttps(pic), strOf(item, 'username'), 'kw'));
    }
    return list;
  }

  /**
   * 酷我歌单详情。原实现 rn=100 只取一页；按 total 分页拉全量（每页 500，上限约 5000）。
   */
  private static async kwPlaylistDetail(id: string): Promise<SearchPlaylistSong[]> {
    const list: SearchPlaylistSong[] = [];
    const pageSize: number = 500;
    let page: number = 0;
    let total: number = -1;
    const seen: Record<string, boolean> = {};
    while (page * pageSize < 5000) {
      const url: string =
        `http://nplserver.kuwo.cn/pl.svc?op=getlistinfo&pid=${id}&pn=${page}&rn=${pageSize}&encode=utf8` +
        `&keyset=pl2012&identity=kuwo&pcmp4=1&vipver=MUSIC_9.0.5.0_W1&newver=1`;
      let body: string = '';
      try {
        body = await PlaylistSearchHttp.getText(url, KW_HEADERS, 20000);
      } catch (_e) {
        break;
      }
      if (body === '') {
        break;
      }
      let root: Record<string, Object>;
      try {
        root = JSON.parse(body) as Record<string, Object>;
      } catch (_e) {
        break;
      }
      if (total < 0) {
        total = numOf(root, 'total');
        if (total <= 0) {
          total = numOf(root, 'songnum');
        }
      }
      const items: Object[] = root['musiclist'] as Object[] ?? [];
      if (items.length === 0) {
        break;
      }
      for (let i = 0; i < items.length; i++) {
        const item: Record<string, Object> = items[i] as Record<string, Object>;
        if (item === null) {
          continue;
        }
        const rid: string = strOf(item, 'id');
        if (rid === '' || seen[rid]) {
          continue;
        }
        seen[rid] = true;
        list.push(SearchPlaylistSong.of(rid, strOf(item, 'name'), strOf(item, 'artist'),
          strOf(item, 'album'), fmtDuration(numOf(item, 'duration')), 'kw'));
      }
      if (items.length < pageSize) {
        break;
      }
      if (total > 0 && list.length >= total) {
        break;
      }
      page = page + 1;
    }
    return list;
  }

  private static async kgSearchPlaylists(keyword: string, page: number): Promise<SearchPlaylistInfo[]> {
    const url: string =
      `https://msearchretry.kugou.com/api/v3/search/special?keyword=${encodeURIComponent(keyword)}` +
      `&page=${page}&pagesize=${KG_PLAYLIST_PAGE_SIZE}&showtype=10&filter=0&version=7910&sver=2`;
    const text: string = await PlaylistSearchHttp.getText(url, KG_HEADERS);
    const list: SearchPlaylistInfo[] = [];
    if (text === '') {
      return list;
    }
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const data: Record<string, Object> = root['data'] as Record<string, Object>;
    if (data === undefined || data === null) {
      return list;
    }
    const items: Object[] = data['info'] as Object[] ?? [];
    for (let i = 0; i < items.length; i++) {
      const item: Record<string, Object> = items[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const id: number = numOf(item, 'specialid');
      if (id === 0) {
        continue;
      }
      let cover: string = toHttps(strOf(item, 'imgurl'));
      if (cover !== '') {
        cover = cover.replace('{size}', '150');
      }
      list.push(SearchPlaylistInfo.of(String(id), strOf(item, 'specialname'), numOf(item, 'playcount'),
        numOf(item, 'songcount'), cover, strOf(item, 'nickname'), 'kg'));
    }
    return list;
  }

  /**
   * 酷狗歌单详情（歌单广场点进来的那条路）。
   *
   * ⚠️ 这条以前是坏的，两段**都失效**（2026-09 实测）：
   *   1. 主通道 `https://www2.kugou.kugou.com/yueku/v9/special/single/<id>-5-9999.html`
   *      —— 该域名**没有可用 HTTPS**（TLS 握手「未能为 SSL/TLS 安全通道建立信任关系」），
   *      `getText` 直接返回空串，必然进兜底；
   *   2. 兜底 `https://m.kugou.com/plist/list/<id>?json=true` —— 现在返回的是 **HTML 页面**
   *      （`<!DOCTYPE HTML>`），`JSON.parse` 必然抛错 → 歌单里**一首歌都没有**。
   *
   * 现在走 `mobilecdn.kugou.com/api/v3/special/song`（明文 HTTP，实测可用：
   * 每页 100 条、`data.total` 给总数、一次请求带齐 hash / filename / duration），
   * 与榜单列表用的 `.../api/v3/rank/song` 是同一族移动端接口。
   *
   * @param id 酷狗歌单 id（`specialid`，即歌单广场卡片上的 `item.id`）。
   * @returns 歌单歌曲；接口不可用时返回空数组。
   */
  private static async kgPlaylistDetail(id: string): Promise<SearchPlaylistSong[]> {
    if (id.length === 0) {
      return [];
    }
    const all: SearchPlaylistSong[] = [];
    const seen: string[] = [];
    for (let page: number = 1; page <= KG_DETAIL_MAX_PAGES; page++) {
      const url: string = `http://mobilecdn.kugou.com/api/v3/special/song?version=9108&plat=0` +
        `&pagesize=${KG_DETAIL_PAGE_SIZE}&area_code=1&page=${page}&specialid=${id}&with_res_tag=0`;
      const text: string = await PlaylistSearchHttp.getText(url, KG_DETAIL_HEADERS);
      if (text === '') {
        break;
      }
      let root: Record<string, Object>;
      try {
        root = JSON.parse(text) as Record<string, Object>;
      } catch (_err) {
        break;
      }
      const data: Record<string, Object> = root['data'] as Record<string, Object>;
      if (data === undefined || data === null) {
        break;
      }
      const items: Object[] = data['info'] as Object[] ?? [];
      for (let i: number = 0; i < items.length; i++) {
        const item: Record<string, Object> = items[i] as Record<string, Object>;
        if (item === null) {
          continue;
        }
        const hash: string = strOf(item, 'hash');
        if (hash === '' || seen.indexOf(hash) >= 0) {
          continue;
        }
        const filename: string = strOf(item, 'filename');
        let name: string = strOf(item, 'songname');
        let singer: string = strOf(item, 'singername');
        if (name.length === 0 && filename.length > 0) {
          // filename 形如「大头针 Official - 伴郎 (Best Man)」
          const sep: number = filename.indexOf(' - ');
          if (sep >= 0) {
            if (singer.length === 0) {
              singer = filename.substring(0, sep);
            }
            name = filename.substring(sep + 3);
          } else {
            name = filename;
          }
        }
        if (name.length === 0) {
          continue;
        }
        seen.push(hash);
        all.push(SearchPlaylistSong.of(hash, name, singer, strOf(item, 'album_name'),
          fmtDuration(numOf(item, 'duration')), 'kg'));
      }
      if (items.length < KG_DETAIL_PAGE_SIZE) {
        break;
      }
    }
    // 超大歌单（几千首）全拉会明显卡，截到上限
    const cap: number = KG_DETAIL_MAX_PAGES * KG_DETAIL_PAGE_SIZE;
    if (all.length > cap) {
      all.length = cap;
    }
    return all;
  }

  private static async mgSearchPlaylists(keyword: string, page: number): Promise<SearchPlaylistInfo[]> {
    const sw: string = encodeURIComponent('{"song":0,"album":0,"singer":0,"tagSong":0,"mvSong":0,"songlist":1,"bestShow":0}');
    const url: string =
      `https://c.musicapp.migu.cn/MIGUM2.0/v1.0/content/search_all.do?ua=Android_migu&version=5.1` +
      `&text=${encodeURIComponent(keyword)}&pageSize=${MG_PLAYLIST_PAGE_SIZE}&pageNo=${page}&searchSwitch=${sw}`;
    const text: string = await PlaylistSearchHttp.getText(url, MG_HEADERS);
    const list: SearchPlaylistInfo[] = [];
    if (text === '') {
      return list;
    }
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const plResult: Record<string, Object> = root['songListResultData'] as Record<string, Object>;
    if (plResult === undefined || plResult === null) {
      return list;
    }
    const items: Object[] = plResult['result'] as Object[] ?? [];
    for (let i = 0; i < items.length; i++) {
      const item: Record<string, Object> = items[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const id: number = numOf(item, 'id');
      if (id === 0) {
        continue;
      }
      list.push(SearchPlaylistInfo.of(String(id), strOf(item, 'name'), numOf(item, 'playNum'),
        numOf(item, 'musicNum'), toHttps(strOf(item, 'musicListPicUrl')), '', 'mg'));
    }
    return list;
  }

  /**
   * 咪咕歌单详情。
   * 上游硬限制：无论 pageSize 传 50/100/200，每页最多返回 50 首。
   * 必须按 pageNo 翻页，直到凑齐 totalCount 或本页不足 50。
   */
  private static async mgPlaylistDetail(id: string): Promise<SearchPlaylistSong[]> {
    const list: SearchPlaylistSong[] = [];
    // ★ 必须用 50：接口单页上限就是 50；若写 100，首页只回 50 会被误判为「最后一页」提前结束
    const pageSize: number = 50;
    let pageNo: number = 1;
    let totalCount: number = 0;
    const maxPages: number = 100; // 上限约 5000 首
    while (pageNo <= maxPages) {
      const url: string =
        `https://app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0` +
        `?pageNo=${pageNo}&pageSize=${pageSize}&playlistId=${id}`;
      const text: string = await PlaylistSearchHttp.getText(url, MG_HEADERS);
      if (text === '') {
        break;
      }
      let root: Record<string, Object>;
      try {
        root = JSON.parse(text) as Record<string, Object>;
      } catch (_e) {
        break;
      }
      const data: Record<string, Object> = root['data'] as Record<string, Object>;
      if (data === undefined || data === null) {
        break;
      }
      if (pageNo === 1) {
        totalCount = numOf(data, 'totalCount');
        if (totalCount === 0) {
          totalCount = numOf(data, 'total');
        }
      }
      const items: Object[] = data['songList'] as Object[] ?? [];
      if (items.length === 0) {
        break;
      }
      for (let i = 0; i < items.length; i++) {
        const item: Record<string, Object> = items[i] as Record<string, Object>;
        if (item === null) {
          continue;
        }
        const songId: string = strOf(item, 'songId');
        if (songId === '') {
          continue;
        }
        const singersArr: Object[] = item['singerList'] as Object[] ?? [];
        const singerNames: string[] = [];
        for (let j = 0; j < singersArr.length; j++) {
          const sg: Record<string, Object> = singersArr[j] as Record<string, Object>;
          if (sg !== null) {
            const sn: string = strOf(sg, 'name');
            if (sn.length > 0) {
              singerNames.push(sn);
            }
          }
        }
        // 带上歌曲封面（img），便于详情页展示
        let picUrl: string = toHttps(strOf(item, 'img'));
        if (picUrl.length === 0) {
          const imgItems: Object[] = item['imgItems'] as Object[] ?? [];
          if (imgItems.length > 0) {
            const img0: Record<string, Object> = imgItems[0] as Record<string, Object>;
            if (img0 !== null) {
              picUrl = toHttps(strOf(img0, 'img'));
            }
          }
        }
        list.push(SearchPlaylistSong.of(songId, strOf(item, 'songName'), singerNames.join(' / '),
          strOf(item, 'album'), fmtDuration(numOf(item, 'duration')), 'mg', picUrl));
      }
      // 已凑够 totalCount
      if (totalCount > 0 && list.length >= totalCount) {
        break;
      }
      // 本页不足 50 → 没有下一页
      if (items.length < pageSize) {
        break;
      }
      pageNo += 1;
    }
    return list;
  }
}
