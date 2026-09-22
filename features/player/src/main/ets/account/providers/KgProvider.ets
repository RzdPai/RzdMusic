import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { httpFetch, HttpOptions, HttpResult, parseCookieString } from '../HttpUtil';
import { md5HexString } from '../CryptoUtil';
import { formatSeconds, requireSourceSession } from '../ProviderUtil';
import { AccountLoginResult, LoginSession, PlatformAccount, PlaylistInfo, PlaylistMutationTrack, PlaylistTrackInfo, PlatformTrackInfo, QrCodeLoginResult, QrCodeLoginState, QrLoginStatus } from '../AccountModels';
import { MusicProvider } from './MusicProvider';

const APP_ID: number = 1005;
const QR_APP_ID: number = 1014;
const SRC_APP_ID: number = 2919;
const CLIENT_VERSION: number = 20489;
const WEB_KEY: string = 'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt';
const ANDROID_KEY: string = 'OIlwieks28dk2k092lksi2UIkp';
const USER_AGENT: string = 'Android15-1070-11083-46-0-DiscoveryDRADProtocol-wifi';

interface PendingQrLogin {
  key: string;
  mid: string;
  dfid: string;
}

interface QrCreateData {
  qrcode: string;
}

interface QrCreateResponse {
  status: number;
  error: string;
  data: QrCreateData;
}

interface QrCheckData {
  status: number;
  userid: string;
  token: string;
  nickname: string;
  username: string;
  user_pic: string;
  user_avatar: string;
  avatar: string;
  pic: string;
}

interface QrCheckResponse {
  status: number;
  error: string;
  data: QrCheckData;
}

interface KgPlaylistItem {
  create_user_pic: string;
  user_avatar: string;
  user_pic: string;
  global_collection_id: string;
  listid: string;
  specialid: string;
  listname: string;
  specialname: string;
  name: string;
  count: number;
  m_count: number;
  songcount: number;
  trackcount: number;
}

interface KgPlaylistData {
  info: KgPlaylistItem[];
  list: KgPlaylistItem[];
}

interface KgPlaylistResponse {
  status: number;
  error: string;
  msg: string;
  data: KgPlaylistData;
  info: KgPlaylistItem[];
}

interface KgAudioInfo {
  hash: string;
  audio_id: string;
}

interface KgPlaylistTrack {
  hash: string;
  audio_info: KgAudioInfo;
  fileid: string;
  audio_id: string;
}

interface KgPlaylistTracksData {
  songs: KgPlaylistTrack[];
  count: number;
}

interface KgPlaylistTracksResponse {
  status: number;
  error: string;
  errmsg: string;
  msg: string;
  data: KgPlaylistTracksData;
}

interface KgMutationResponse {
  status: number;
  error: string;
  errmsg: string;
  msg: string;
  error_code: number;
}

interface KgDailySong {
  hash: string;
}

interface KgAudioReqItem {
  hash: string;
}

interface KgAudioDetailBody {
  area_code: string;
  show_privilege: number;
  show_album_info: string;
  is_publish: string;
  appid: number;
  clientver: number;
  mid: string;
  dfid: string;
  clienttime: number;
  key: string;
  fields: string;
  data: KgAudioReqItem[];
}

interface KgDailyData {
  song_list: KgDailySong[];
  info: KgDailySong[];
  list: KgDailySong[];
}

interface KgDailyResponse {
  status: number;
  error: string;
  msg: string;
  data: KgDailyData;
  info: KgDailySong[];
}

const pendingQrLogins: Map<string, PendingQrLogin> = new Map();

function randomHex(length: number): string {
  let result: string = '';
  for (let i = 0; i < length; i++) {
    result += Math.floor(Math.random() * 16).toString(16);
  }
  return result;
}

function paramsStringify(params: Map<string, string>): string {
  const keys: string[] = Array.from(params.keys()).sort();
  let result: string = '';
  for (let i = 0; i < keys.length; i++) {
    result += `${keys[i]}=${params.get(keys[i]) ?? ''}`;
  }
  return result;
}

function queryStringify(params: Map<string, string>): string {
  const parts: string[] = [];
  params.forEach((value: string, key: string) => {
    parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
  });
  return parts.join('&');
}

async function signature(params: Map<string, string>, key: string, data: string): Promise<string> {
  const values: string = paramsStringify(params);
  return md5HexString(`${key}${values}${data}${key}`);
}

async function buildUrl(baseUrl: string, params: Map<string, string>, key: string, data: string): Promise<string> {
  const sig: string = await signature(params, key, data);
  const query: string = queryStringify(params);
  return `${baseUrl}?${query}&signature=${sig}`;
}

function commonParams(session: LoginSession | undefined, midOverride?: string): Map<string, string> {
  const params: Map<string, string> = new Map();
  params.set('dfid', session?.cookies.get('dfid') ?? '-');
  params.set('mid', midOverride ?? session?.cookies.get('KUGOU_API_MID') ?? session?.cookies.get('mid') ?? randomHex(32));
  params.set('uuid', '-');
  params.set('appid', String(APP_ID));
  params.set('clientver', String(CLIENT_VERSION));
  params.set('clienttime', String(Math.floor(Date.now() / 1000)));
  return params;
}

function commonHeaders(params: Map<string, string>, extra: Map<string, string>): Map<string, string> {
  const headers: Map<string, string> = new Map();
  headers.set('User-Agent', USER_AGENT);
  headers.set('dfid', params.get('dfid') ?? '-');
  headers.set('mid', params.get('mid') ?? '-');
  headers.set('clienttime', params.get('clienttime') ?? '0');
  headers.set('kg-rc', '1');
  headers.set('kg-thash', '5d816a0');
  headers.set('kg-rec', '1');
  headers.set('kg-rf', 'B9EDA08A64250DEFFBCADDEE00F8F25F');
  extra.forEach((value: string, key: string) => {
    headers.set(key, value);
  });
  return headers;
}

function normalizeImageUrl(value: string, size: number): string {
  if (value.length === 0) return '';
  return value.replace(/\{size\}/g, String(size)).replace(/^http:/, 'https:');
}

function buildLoginResult(userid: string, token: string, cookies: Map<string, string>, nickname: string, avatar: string): AccountLoginResult {
  const account: PlatformAccount = new PlatformAccount();
  account.id = `kg_${userid}`;
  account.source = 'kg';
  account.nickname = nickname.trim().length > 0 ? nickname : `酷狗用户 ${userid}`;
  account.avatar = normalizeImageUrl(avatar, 165);
  const session: LoginSession = new LoginSession();
  session.source = 'kg';
  cookies.forEach((value: string, key: string) => {
    session.cookies.set(key, value);
  });
  session.cookies.set('userid', userid);
  session.cookies.set('token', token);
  session.tokens.set('userId', userid);
  session.tokens.set('token', token);
  return { account: account, session: session };
}

async function getPlaylistItems(session: LoginSession): Promise<KgPlaylistItem[]> {
  const params: Map<string, string> = commonParams(session);
  params.set('plat', '1');
  params.set('userid', session.tokens.get('userId') ?? '');
  params.set('token', session.tokens.get('token') ?? '');
  const body: string = JSON.stringify({
    userid: session.tokens.get('userId') ?? '',
    token: session.tokens.get('token') ?? '',
    total_ver: 979,
    type: 2,
    page: 1,
    pagesize: 1000,
  });
  const url: string = await buildUrl('https://gateway.kugou.com/v7/get_all_list', params, ANDROID_KEY, body);
  const options: HttpOptions = new HttpOptions();
  options.method = http.RequestMethod.POST;
  options.headers = commonHeaders(params, new Map([
    ['Content-Type', 'application/json'],
    ['x-router', 'cloudlist.service.kugou.com'],
  ]));
  options.json = body;
  const response: HttpResult = await httpFetch(url, options);
  if (response.statusCode !== 200) throw new Error(`获取酷狗歌单失败（HTTP ${response.statusCode}）`);
  const parsed: KgPlaylistResponse = JSON.parse(response.body) as KgPlaylistResponse;
  if (parsed.status !== 1) throw new Error(parsed.error || parsed.msg || '获取酷狗歌单失败');
  const items: KgPlaylistItem[] = parsed.data?.info ?? parsed.data?.list ?? parsed.info ?? [];
  return items;
}

export async function getAccountAvatar(session: LoginSession): Promise<string> {
  const list: KgPlaylistItem[] = await getPlaylistItems(session);
  for (let i = 0; i < list.length; i++) {
    const item: KgPlaylistItem = list[i];
    if (item.create_user_pic || item.user_avatar || item.user_pic) {
      return normalizeImageUrl(item.create_user_pic ?? item.user_avatar ?? item.user_pic, 165);
    }
  }
  return '';
}

export class KgProvider implements MusicProvider {
  async loginByCookie(cookie: string): Promise<AccountLoginResult> {
    const cookies: Map<string, string> = parseCookieString(cookie);
    const userid: string = cookies.get('userid') ?? cookies.get('KugooID') ?? '';
    const token: string = cookies.get('token') ?? cookies.get('t') ?? '';
    if (userid.length === 0 || token.length === 0) throw new Error('Cookie 中缺少 userid 或 token');
    const result: AccountLoginResult = buildLoginResult(userid, token, cookies, cookies.get('nickname') ?? '', '');
    result.account.avatar = await getAccountAvatar(result.session);
    return result;
  }

  async createQrCode(): Promise<QrCodeLoginState> {
    const mid: string = randomHex(32);
    const dfid: string = randomHex(16);
    const params: Map<string, string> = new Map();
    params.set('dfid', dfid);
    params.set('mid', mid);
    params.set('uuid', '-');
    params.set('appid', String(QR_APP_ID));
    params.set('clientver', String(CLIENT_VERSION));
    params.set('clienttime', String(Math.floor(Date.now() / 1000)));
    params.set('type', '1');
    params.set('plat', '4');
    params.set('qrcode_txt', `https://h5.kugou.com/apps/loginQRCode/html/index.html?appid=${APP_ID}&`);
    params.set('srcappid', String(SRC_APP_ID));
    const headerParams: Map<string, string> = new Map(params);
    headerParams.set('appid', String(APP_ID));
    headerParams.set('plat', '1');
    const url: string = await buildUrl('https://login-user.kugou.com/v2/qrcode', params, WEB_KEY, '');
    const options: HttpOptions = new HttpOptions();
    options.method = http.RequestMethod.GET;
    options.headers = commonHeaders(headerParams, new Map());
    const response: HttpResult = await httpFetch(url, options);
    if (response.statusCode !== 200) throw new Error(`获取酷狗二维码失败（HTTP ${response.statusCode}）`);
    const body: QrCreateResponse = JSON.parse(response.body) as QrCreateResponse;
    const key: string = body.data?.qrcode ?? '';
    if (body.status !== 1 || key.length === 0) throw new Error(body.error || '获取酷狗二维码失败');
    const requestId: string = util.generateRandomUUID();
    const pending: PendingQrLogin = { key: key, mid: mid, dfid: dfid };
    pendingQrLogins.set(requestId, pending);
    setTimeout(() => {
      pendingQrLogins.delete(requestId);
    }, 10 * 60 * 1000);
    const state: QrCodeLoginState = new QrCodeLoginState();
    state.key = requestId;
    state.qrUrl = `https://h5.kugou.com/apps/loginQRCode/html/index.html?qrcode=${encodeURIComponent(key)}`;
    state.status = QrLoginStatus.Waiting;
    return state;
  }

  async checkQrCodeStatus(requestId: string): Promise<QrCodeLoginResult> {
    const pending: PendingQrLogin | undefined = pendingQrLogins.get(requestId);
    const result: QrCodeLoginResult = new QrCodeLoginResult();
    if (pending === undefined) {
      result.status = QrLoginStatus.Expired;
      return result;
    }
    const params: Map<string, string> = new Map();
    params.set('dfid', pending.dfid);
    params.set('mid', pending.mid);
    params.set('uuid', '-');
    params.set('appid', String(APP_ID));
    params.set('clientver', String(CLIENT_VERSION));
    params.set('clienttime', String(Math.floor(Date.now() / 1000)));
    params.set('plat', '4');
    params.set('srcappid', String(SRC_APP_ID));
    params.set('qrcode', pending.key);
    const headerParams: Map<string, string> = new Map(params);
    headerParams.set('plat', '1');
    const url: string = await buildUrl('https://login-user.kugou.com/v2/get_userinfo_qrcode', params, WEB_KEY, '');
    const options: HttpOptions = new HttpOptions();
    options.method = http.RequestMethod.GET;
    options.headers = commonHeaders(headerParams, new Map());
    const response: HttpResult = await httpFetch(url, options);
    if (response.statusCode !== 200) {
      result.status = QrLoginStatus.Failed;
      result.message = `检查扫码状态失败（HTTP ${response.statusCode}）`;
      return result;
    }
    const body: QrCheckResponse = JSON.parse(response.body) as QrCheckResponse;
    const data: QrCheckData | undefined = body.data;
    const code: number = Number(data?.status ?? body.status);
    let status: QrLoginStatus;
    if (code === 0) {
      status = QrLoginStatus.Expired;
    } else if (code === 1) {
      status = QrLoginStatus.Waiting;
    } else if (code === 2) {
      status = QrLoginStatus.Scanned;
    } else if (code === 4) {
      status = QrLoginStatus.Confirmed;
    } else {
      status = QrLoginStatus.Failed;
    }
    if (status !== QrLoginStatus.Confirmed) {
      if (status === QrLoginStatus.Expired || status === QrLoginStatus.Failed) pendingQrLogins.delete(requestId);
      result.status = status;
      result.message = body.error;
      return result;
    }
    const userid: string = String(data?.userid ?? '');
    const token: string = String(data?.token ?? '');
    if (userid.length === 0 || token.length === 0) {
      result.status = QrLoginStatus.Failed;
      result.message = '登录成功但未获取到凭证';
      return result;
    }
    pendingQrLogins.delete(requestId);
    const cookies: Map<string, string> = new Map();
    cookies.set('userid', userid);
    cookies.set('token', token);
    cookies.set('KUGOU_API_MID', pending.mid);
    cookies.set('mid', pending.mid);
    cookies.set('dfid', pending.dfid);
    const nickname: string = String(data?.nickname ?? data?.username ?? '');
    const avatar: string = String(data?.user_pic ?? data?.user_avatar ?? data?.avatar ?? data?.pic ?? '');
    const loginResult: AccountLoginResult = buildLoginResult(userid, token, cookies, nickname, avatar);
    if (loginResult.account.avatar.length === 0) {
      loginResult.account.avatar = await getAccountAvatar(loginResult.session).catch(() => '');
    }
    result.status = QrLoginStatus.Confirmed;
    result.account = loginResult.account;
    result.session = loginResult.session;
    return result;
  }

  async getUserPlaylists(sessionValue: LoginSession | undefined): Promise<PlaylistInfo[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'kg', '酷狗');
    const list: KgPlaylistItem[] = await getPlaylistItems(session);
    const result: PlaylistInfo[] = [];
    for (const item of list) {
      const info: PlaylistInfo = new PlaylistInfo();
      info.id = String(item.global_collection_id ?? item.listid ?? item.specialid ?? '');
      info.name = String(item.listname ?? item.specialname ?? item.name ?? '');
      info.source = 'kg';
      info.total = String(item.count ?? item.m_count ?? item.songcount ?? item.trackcount ?? 0);
      info.dirId = String(item.listid ?? '');
      info.isEditable = Boolean(item.listid);
      if (info.id.length > 0) result.push(info);
    }
    return result;
  }

  async getPlaylistTrackIds(sessionValue: LoginSession | undefined, playlistId: string, dirId: string | undefined): Promise<PlaylistTrackInfo[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'kg', '酷狗');
    const pageSize: number = 300;
    const tracks: PlaylistTrackInfo[] = [];
    let beginIndex: number = 0;
    while (true) {
      const params: Map<string, string> = commonParams(session);
      params.set('token', session.tokens.get('token') ?? '');
      params.set('userid', session.tokens.get('userId') ?? '');
      params.set('area_code', '1');
      params.set('begin_idx', String(beginIndex));
      params.set('plat', '1');
      params.set('type', '1');
      params.set('mode', '1');
      params.set('personal_switch', '1');
      params.set('extend_fields', 'abtags,hot_cmt,popularization');
      params.set('pagesize', String(pageSize));
      params.set('global_collection_id', playlistId);
      const url: string = await buildUrl('https://gateway.kugou.com/pubsongs/v2/get_other_list_file_nofilt', params, ANDROID_KEY, '');
      const options: HttpOptions = new HttpOptions();
      options.method = http.RequestMethod.GET;
      options.headers = commonHeaders(params, new Map());
      const response: HttpResult = await httpFetch(url, options);
      if (response.statusCode !== 200) throw new Error(`获取酷狗歌单歌曲失败（HTTP ${response.statusCode}）`);
      const body: KgPlaylistTracksResponse = JSON.parse(response.body) as KgPlaylistTracksResponse;
      if (body.status !== 1) {
        throw new Error(body.error || body.errmsg || body.msg || '获取酷狗歌单歌曲失败');
      }
      const songs: KgPlaylistTrack[] = body.data?.songs ?? [];
      for (const song of songs) {
        const id: string = String(song.hash ?? song.audio_info?.hash ?? '');
        if (id.length === 0) continue;
        const track: PlaylistTrackInfo = new PlaylistTrackInfo();
        track.id = id;
        track.removeId = String(song.fileid ?? song.audio_id ?? song.audio_info?.audio_id ?? '');
        tracks.push(track);
      }
      const total: number = Number(body.data?.count) || 0;
      if (songs.length === 0 || songs.length < pageSize || (total > 0 && tracks.length >= total)) break;
      beginIndex += songs.length;
    }
    const unique: Map<string, PlaylistTrackInfo> = new Map();
    for (const track of tracks) unique.set(track.id, track);
    return Array.from(unique.values());
  }

  private async requestPlaylistMutation(
    session: LoginSession,
    endpoint: string,
    bodyData: Record<string, Object>,
    extraParams: Map<string, string>,
    extraHeaders: Map<string, string>,
  ): Promise<void> {
    const params: Map<string, string> = commonParams(session);
    params.set('userid', session.tokens.get('userId') ?? '');
    params.set('token', session.tokens.get('token') ?? '');
    extraParams.forEach((value: string, key: string) => {
      params.set(key, value);
    });
    const body: string = JSON.stringify(bodyData);
    const url: string = await buildUrl(endpoint, params, ANDROID_KEY, body);
    const options: HttpOptions = new HttpOptions();
    options.method = http.RequestMethod.POST;
    const headers: Map<string, string> = commonHeaders(params, new Map([['Content-Type', 'application/json']]));
    extraHeaders.forEach((value: string, key: string) => {
      headers.set(key, value);
    });
    options.headers = headers;
    options.json = body;
    const response: HttpResult = await httpFetch(url, options);
    if (response.statusCode !== 200) throw new Error(`酷狗歌单操作失败（HTTP ${response.statusCode}）`);
    const parsed: KgMutationResponse = JSON.parse(response.body) as KgMutationResponse;
    if (parsed.status === 0 || Number(parsed.error_code ?? 0) !== 0) {
      throw new Error(parsed.error || parsed.errmsg || parsed.msg || '酷狗歌单操作失败');
    }
  }

  async removePlaylistTracks(sessionValue: LoginSession | undefined, playlistId: string, dirId: string | undefined, tracks: PlaylistMutationTrack[]): Promise<void> {
    const session: LoginSession = requireSourceSession(sessionValue, 'kg', '酷狗');
    if (!dirId || dirId.length === 0) throw new Error('酷狗歌单缺少列表 ID');
    const ids: number[] = [];
    for (const track of tracks) {
      if (track.platformId.length > 0) ids.push(Number(track.platformId));
    }
    if (ids.length !== tracks.length) throw new Error('部分歌曲缺少酷狗歌单条目 ID');
    const fileIds: Array<Record<string, number>> = [];
    for (const fileid of ids) {
      fileIds.push({ 'fileid': fileid });
    }
    const bodyData: Record<string, Object> = {
      'listid': dirId,
      'userid': session.tokens.get('userId') ?? '',
      'data': fileIds,
      'type': 0,
      'token': session.tokens.get('token') ?? '',
      'list_ver': 0,
    };
    const extraHeaders: Map<string, string> = new Map([['x-router', 'cloudlist.service.kugou.com']]);
    await this.requestPlaylistMutation(session, 'https://gateway.kugou.com/v4/delete_songs', bodyData, new Map(), extraHeaders);
  }

  async getDailyTrackIds(sessionValue: LoginSession | undefined): Promise<string[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'kg', '酷狗');
    const params: Map<string, string> = commonParams(session);
    params.set('token', session.tokens.get('token') ?? '');
    params.set('userid', session.tokens.get('userId') ?? '');
    params.set('platform', 'ios');
    const url: string = await buildUrl('https://gateway.kugou.com/everyday_song_recommend', params, ANDROID_KEY, '');
    const options: HttpOptions = new HttpOptions();
    options.method = http.RequestMethod.POST;
    const headers: Map<string, string> = commonHeaders(params, new Map([['x-router', 'everydayrec.service.kugou.com']]));
    options.headers = headers;
    const response: HttpResult = await httpFetch(url, options);
    if (response.statusCode !== 200) throw new Error(`获取酷狗每日推荐失败（HTTP ${response.statusCode}）`);
    const body: KgDailyResponse = JSON.parse(response.body) as KgDailyResponse;
    if (body.status !== 1) throw new Error(body.error || body.msg || '获取酷狗每日推荐失败');
    const songs: KgDailySong[] = body.data?.song_list ?? body.data?.info ?? body.info ?? body.data?.list ?? [];
    const ids: string[] = [];
    for (const song of songs) {
      const hash: string = String(song.hash ?? '');
      if (hash.length > 0) ids.push(hash);
    }
    return ids;
  }

  async getTrackDetails(sessionValue: LoginSession | undefined, hashes: string[]): Promise<PlatformTrackInfo[]> {
    const result: PlatformTrackInfo[] = [];
    const chunkSize: number = 100;
    for (let i = 0; i < hashes.length; i += chunkSize) {
      const chunk: string[] = hashes.slice(i, i + chunkSize);
      const dataList: KgAudioReqItem[] = [];
      for (const hash of chunk) {
        const item: KgAudioReqItem = { hash: hash };
        dataList.push(item);
      }
      const bodyData: KgAudioDetailBody = {
        area_code: '1',
        show_privilege: 1,
        show_album_info: '1',
        is_publish: '',
        appid: APP_ID,
        clientver: 11451,
        mid: '1',
        dfid: '-',
        clienttime: Date.now(),
        key: ANDROID_KEY,
        fields: 'album_info,author_name,audio_info,ori_audio_name,base,songname,classification',
        data: dataList,
      };
      const options: HttpOptions = new HttpOptions();
      options.method = http.RequestMethod.POST;
      options.headers = new Map([
        ['KG-THash', '13a3164'],
        ['KG-RC', '1'],
        ['KG-Fake', '0'],
        ['KG-RF', '00869891'],
        ['User-Agent', 'Android712-AndroidPhone-11451-376-0-FeeCacheUpdate-wifi'],
        ['x-router', 'kmr.service.kugou.com'],
      ]);
      options.json = JSON.stringify(bodyData);
      try {
        const response: HttpResult = await httpFetch('https://gateway.kugou.com/v3/album_audio/audio', options);
        if (response.statusCode !== 200) continue;
        const parsed: Record<string, Object> = JSON.parse(response.body) as Record<string, Object>;
        if (Number(parsed['status']) !== 1) continue;
        const rows: Array<Array<Record<string, Object>>> = (parsed['data'] ?? []) as Array<Array<Record<string, Object>>>;
        for (const row of rows) {
          const item: Record<string, Object> = (row[0] ?? {}) as Record<string, Object>;
          const audioInfo: Record<string, Object> = (item['audio_info'] ?? {}) as Record<string, Object>;
          const name: string = String(item['songname'] ?? '');
          const hash: string = String(audioInfo['hash'] ?? '');
          if (name.length === 0 || hash.length === 0) continue;
          const track: PlatformTrackInfo = new PlatformTrackInfo();
          track.id = hash;
          track.removeId = '';
          track.name = name;
          track.singer = String(item['author_name'] ?? '');
          const albumInfo: Record<string, Object> = (item['album_info'] ?? {}) as Record<string, Object>;
          track.album = String(albumInfo['album_name'] ?? '');
          const cover: string = String(albumInfo['sizable_cover'] ?? '');
          track.picUrl = cover.replace(/\{size\}/g, '240').replace(/^http:/, 'https:');
          const seconds: number = Math.floor(Number(audioInfo['timelength'] ?? 0) / 1000);
          track.interval = seconds > 0 ? formatSeconds(seconds) : '';
          track.source = 'kg';
          result.push(track);
        }
      } catch (err) {
        // 单批详情获取失败跳过
      }
    }
    return result;
  }
}
