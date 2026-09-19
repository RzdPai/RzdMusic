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

  private static async wyPlaylistDetail(id: string): Promise<SearchPlaylistSong[]> {
    const url: string = `https://music.163.com/api/v6/playlist/detail?id=${id}&n=100000&s=8`;
    const text: string = await PlaylistSearchHttp.getText(url, {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://music.163.com/'
    });
    const list: SearchPlaylistSong[] = [];
    if (text === '') {
      return list;
    }
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const playlist: Record<string, Object> = root['playlist'] as Record<string, Object>;
    if (playlist === undefined || playlist === null) {
      return list;
    }
    const tracks: Object[] = playlist['tracks'] as Object[] ?? [];
    for (let i = 0; i < tracks.length; i++) {
      const item: Record<string, Object> = tracks[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const idN: number = numOf(item, 'id');
      if (idN === 0) {
        continue;
      }
      const artists: Object[] = item['ar'] as Object[] ?? [];
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
      const album: Record<string, Object> = item['al'] as Record<string, Object>;
      const albumName: string = album === undefined || album === null ? '' : strOf(album, 'name');
      const picUrl: string = album === undefined || album === null ? '' :
        toHttps(strOf(album, 'picUrl'));
      list.push(SearchPlaylistSong.of(String(idN), strOf(item, 'name'), names.join(' / '),
        albumName, fmtDuration(numOf(item, 'dt') / 1000), 'wy', picUrl));
    }
    return list;
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

  private static async txPlaylistDetail(id: string): Promise<SearchPlaylistSong[]> {
    const url: string =
      `https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg?type=1&json=1&utf8=1&onlysong=0&new_format=1` +
      `&disstid=${id}&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=0`;
    const text: string = await PlaylistSearchHttp.getText(url, TX_HEADERS);
    const list: SearchPlaylistSong[] = [];
    if (text === '') {
      return list;
    }
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const cdlist: Object[] = root['cdlist'] as Object[] ?? [];
    if (cdlist.length === 0) {
      return list;
    }
    const cd: Record<string, Object> = cdlist[0] as Record<string, Object>;
    if (cd === null) {
      return list;
    }
    const songs: Object[] = cd['songlist'] as Object[] ?? [];
    for (let i = 0; i < songs.length; i++) {
      const item: Record<string, Object> = songs[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const mid: string = strOf(item, 'mid');
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
      const albumName: string = album === undefined || album === null ? '' : strOf(album, 'name');
      const albumMid: string = album === undefined || album === null ? '' : strOf(album, 'mid');
      const picUrl: string = albumMid === '' ? '' :
        `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumMid}.jpg`;
      list.push(SearchPlaylistSong.of(mid, strOf(item, 'name'), singerNames.join(' / '),
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

  private static async kwPlaylistDetail(id: string): Promise<SearchPlaylistSong[]> {
    const url: string =
      `http://nplserver.kuwo.cn/pl.svc?op=getlistinfo&pid=${id}&pn=0&rn=100&encode=utf8` +
      `&keyset=pl2012&identity=kuwo&pcmp4=1&vipver=MUSIC_9.0.5.0_W1&newver=1`;
    const text: string = await PlaylistSearchHttp.getText(url, KW_HEADERS);
    const list: SearchPlaylistSong[] = [];
    if (text === '') {
      return list;
    }
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const items: Object[] = root['musiclist'] as Object[] ?? [];
    for (let i = 0; i < items.length; i++) {
      const item: Record<string, Object> = items[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const rid: string = strOf(item, 'id');
      if (rid === '') {
        continue;
      }
      list.push(SearchPlaylistSong.of(rid, strOf(item, 'name'), strOf(item, 'artist'),
        strOf(item, 'album'), fmtDuration(numOf(item, 'duration')), 'kw'));
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

  private static async kgPlaylistDetail(id: string): Promise<SearchPlaylistSong[]> {
    const url: string = `https://www2.kugou.kugou.com/yueku/v9/special/single/${id}-5-9999.html`;
    const text: string = await PlaylistSearchHttp.getText(url, KG_HEADERS);
    const list: SearchPlaylistSong[] = [];
    if (text === '') {
      return list;
    }
    const marker: string = 'global.data = [';
    const start: number = text.indexOf(marker);
    if (start < 0) {
      return PlaylistSearchApi.kgPlaylistDetailFallback(id);
    }
    const jsonStart: number = start + 'global.data = '.length;
    const jsonEnd: number = text.lastIndexOf('];');
    if (jsonEnd <= jsonStart) {
      return PlaylistSearchApi.kgPlaylistDetailFallback(id);
    }
    let parsed: Object[];
    try {
      parsed = JSON.parse(text.substring(jsonStart, jsonEnd + 1)) as Object[];
    } catch (e) {
      return PlaylistSearchApi.kgPlaylistDetailFallback(id);
    }
    const seen: string[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const item: Record<string, Object> = parsed[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const hash: string = strOf(item, 'hash');
      if (hash === '') {
        continue;
      }
      if (seen.indexOf(hash) >= 0) {
        continue;
      }
      seen.push(hash);
      list.push(SearchPlaylistSong.of(hash, strOf(item, 'songname'), strOf(item, 'singername'),
        strOf(item, 'album_name'), fmtDuration(numOf(item, 'duration')), 'kg'));
    }
    if (list.length === 0) {
      return PlaylistSearchApi.kgPlaylistDetailFallback(id);
    }
    return list;
  }

  /** 酷狗歌单详情兜底：HTML 解析失败时用移动端 JSON 接口。 */
  private static async kgPlaylistDetailFallback(id: string): Promise<SearchPlaylistSong[]> {
    const url: string = `https://m.kugou.com/plist/list/${id}?json=true`;
    const text: string = await PlaylistSearchHttp.getText(url, KG_HEADERS);
    const list: SearchPlaylistSong[] = [];
    if (text === '') {
      return list;
    }
    let root: Record<string, Object>;
    try {
      root = JSON.parse(text) as Record<string, Object>;
    } catch (e) {
      return list;
    }
    const outer: Record<string, Object> = root['list'] as Record<string, Object>;
    if (outer === undefined || outer === null) {
      return list;
    }
    const listObj: Record<string, Object> = outer['list'] as Record<string, Object>;
    if (listObj === undefined || listObj === null) {
      return list;
    }
    const items: Object[] = listObj['info'] as Object[] ?? [];
    for (let i = 0; i < items.length; i++) {
      const item: Record<string, Object> = items[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const hash: string = strOf(item, 'hash');
      if (hash === '') {
        continue;
      }
      const filename: string = strOf(item, 'filename');
      const sep: number = filename.indexOf(' - ');
      let name: string = filename;
      let singer: string = '';
      if (sep >= 0) {
        singer = filename.substring(0, sep);
        name = filename.substring(sep + 3);
      }
      list.push(SearchPlaylistSong.of(hash, name, singer, '',
        fmtDuration(numOf(item, 'duration')), 'kg'));
    }
    return list;
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

  private static async mgPlaylistDetail(id: string): Promise<SearchPlaylistSong[]> {
    const url: string = `https://app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0?pageNo=1&pageSize=200&playlistId=${id}`;
    const text: string = await PlaylistSearchHttp.getText(url, MG_HEADERS);
    const list: SearchPlaylistSong[] = [];
    if (text === '') {
      return list;
    }
    const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
    const data: Record<string, Object> = root['data'] as Record<string, Object>;
    if (data === undefined || data === null) {
      return list;
    }
    const items: Object[] = data['songList'] as Object[] ?? [];
    for (let i = 0; i < items.length; i++) {
      const item: Record<string, Object> = items[i] as Record<string, Object>;
      if (item === null) {
        continue;
      }
      const id: string = strOf(item, 'songId');
      if (id === '') {
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
      list.push(SearchPlaylistSong.of(id, strOf(item, 'songName'), singerNames.join(' / '),
        strOf(item, 'album'), fmtDuration(numOf(item, 'duration')), 'mg'));
    }
    return list;
  }
}
