import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { httpFetch, HttpOptions, HttpResult, parseCookieString } from '../HttpUtil';
import { eapiEncrypt, linuxapiEncrypt, weapiEncrypt, WeapiResult } from '../CryptoUtil';
import { formatSeconds, requireSourceSession } from '../ProviderUtil';
import { AccountLoginResult, LoginSession, PlatformAccount, PlaylistInfo, PlaylistMutationTrack, PlaylistTrackInfo, PlatformTrackInfo, QrCodeLoginResult, QrCodeLoginState, QrLoginStatus } from '../AccountModels';
import { MusicProvider } from './MusicProvider';

const BASE_URL: string = 'https://music.163.com';
const INTERFACE_URL: string = 'https://interface.music.163.com';
const USER_AGENT: string = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
const DESKTOP_USER_AGENT: string = 'NeteaseMusic/9.1.65.240927161425 CFNetwork/1496.0.7 Darwin/23.5.0';

interface PendingQrLogin {
  key: string;
  cookies: Map<string, string>;
}

interface Profile {
  userId: number;
  nickname: string;
  avatarUrl: string;
}

interface AccountResponse {
  code: number;
  message: string;
  profile: Profile;
}

interface UnikeyData {
  unikey: string;
}

interface UnikeyResponse {
  code: number;
  message: string;
  data: UnikeyData;
  unikey: string;
}

interface QrLoginResponse {
  code: number;
  cookie: string;
  message: string;
}

interface PlaylistCreator {
  userId: number;
}

interface PlaylistItem {
  id: number;
  name: string;
  creator: PlaylistCreator;
  trackCount: number;
}

interface PlaylistResponse {
  code: number;
  message: string;
  playlist: PlaylistItem[];
}

interface TrackIdItem {
  id: number;
}

interface PlaylistDetail {
  trackIds: TrackIdItem[];
}

interface LinuxForwardResponse {
  code: number;
  message: string;
  playlist: PlaylistDetail;
}

interface MutateResponse {
  code: number;
  message: string;
}

interface DailySong {
  id: number;
}

interface DailyData {
  dailySongs: DailySong[];
}

interface DailyResponse {
  code: number;
  message: string;
  data: DailyData;
}

interface SongDetailArtist {
  name: string;
}

interface SongDetailAlbum {
  name: string;
  picUrl: string;
}

interface SongDetailItem {
  id: number;
  name: string;
  ar: SongDetailArtist[];
  al: SongDetailAlbum;
  dt: number;
}

interface SongDetailReqItem {
  id: number;
}

interface SongDetailResponse {
  code: number;
  message: string;
  songs: Array<SongDetailItem | null>;
}

const pendingQrLogins: Map<string, PendingQrLogin> = new Map();

function randomHex(length: number): string {
  let result: string = '';
  for (let i = 0; i < length; i++) {
    result += Math.floor(Math.random() * 16).toString(16);
  }
  return result;
}

function createAnonymousCookies(): Map<string, string> {
  const cookies: Map<string, string> = new Map();
  const anonymousId: string = randomHex(16);
  cookies.set('__remember_me', 'true');
  cookies.set('_ntes_nuid', anonymousId);
  cookies.set('_ntes_nnid', `${anonymousId},${Date.now()}`);
  cookies.set('deviceId', randomHex(26).toUpperCase());
  cookies.set('os', 'pc');
  cookies.set('osver', 'Microsoft-Windows-10-Professional-build-19045-64bit');
  cookies.set('appver', '3.1.17.204416');
  cookies.set('channel', 'netease');
  return cookies;
}

function mergeSetCookies(target: Map<string, string>, setCookies: Map<string, string>): void {
  setCookies.forEach((value: string, key: string) => {
    target.set(key, value);
  });
}

interface EapiResult {
  statusCode: number;
  body: string;
  setCookies: Map<string, string>;
}

async function eapiPost(uri: string, dataJson: string, cookies: Map<string, string>): Promise<EapiResult> {
  const header: Record<string, string> = {
    'osver': cookies.get('osver') ?? 'Microsoft-Windows-10-Professional-build-19045-64bit',
    'deviceId': cookies.get('deviceId') ?? randomHex(26).toUpperCase(),
    'os': cookies.get('os') ?? 'pc',
    'appver': cookies.get('appver') ?? '3.1.17.204416',
    'versioncode': cookies.get('versioncode') ?? '140',
    'mobilename': '',
    'buildver': String(Date.now()).slice(0, 10),
    'resolution': '1920x1080',
    '__csrf': cookies.get('__csrf') ?? '',
    'channel': cookies.get('channel') ?? 'netease',
    'requestId': `${Date.now()}_${Math.floor(Math.random() * 1000).toString().padStart(4, '0')}`,
  };
  if (cookies.has('MUSIC_U')) header['MUSIC_U'] = cookies.get('MUSIC_U') ?? '';
  if (cookies.has('MUSIC_A')) header['MUSIC_A'] = cookies.get('MUSIC_A') ?? '';
  const encodedHeader: string[] = [];
  for (const key of Object.keys(header)) {
    encodedHeader.push(`${encodeURIComponent(key)}=${encodeURIComponent(header[key])}`);
  }
  const options: HttpOptions = new HttpOptions();
  options.method = http.RequestMethod.POST;
  const headerList: Array<[string, string]> = [
    ['User-Agent', DESKTOP_USER_AGENT],
    ['Cookie', encodedHeader.join('; ')],
  ];
  options.headers = new Map(headerList);
  const params: string = await eapiEncrypt(uri, dataJson);
  options.form = `params=${encodeURIComponent(params)}`;
  const response: HttpResult = await httpFetch(`${INTERFACE_URL}${uri.replace(/^\/api/, '/eapi')}`, options);
  const result: EapiResult = {
    statusCode: response.statusCode,
    body: response.body,
    setCookies: response.setCookies,
  };
  return result;
}

async function getAccount(cookies: Map<string, string>): Promise<AccountLoginResult> {
  const options: HttpOptions = new HttpOptions();
  options.method = http.RequestMethod.GET;
  options.headers = new Map([
    ['User-Agent', USER_AGENT],
    ['Referer', `${BASE_URL}/`],
  ]);
  options.cookie = cookies;
  const response: HttpResult = await httpFetch(`${BASE_URL}/api/nuser/account/get`, options);
  if (response.statusCode !== 200) throw new Error(`登录失败（HTTP ${response.statusCode}）`);
  const body: AccountResponse = JSON.parse(response.body) as AccountResponse;
  if (body.code !== 200 || !body.profile || !body.profile.userId) {
    throw new Error(body.message || '登录失败，请检查 Cookie 是否有效');
  }
  const profile: Profile = body.profile;
  const account: PlatformAccount = new PlatformAccount();
  account.id = `wy_${profile.userId}`;
  account.source = 'wy';
  account.nickname = profile.nickname;
  account.avatar = profile.avatarUrl;
  const session: LoginSession = new LoginSession();
  session.source = 'wy';
  cookies.forEach((value: string, key: string) => {
    session.cookies.set(key, value);
  });
  session.tokens.set('userId', String(profile.userId));
  return { account: account, session: session };
}

export class WyProvider implements MusicProvider {
  async loginByCookie(cookie: string): Promise<AccountLoginResult> {
    const cookies: Map<string, string> = parseCookieString(cookie);
    if (!cookies.has('MUSIC_U') && !cookies.has('MUSIC_A')) {
      throw new Error('Cookie 中缺少 MUSIC_U 或 MUSIC_A');
    }
    return getAccount(cookies);
  }

  async createQrCode(): Promise<QrCodeLoginState> {
    const cookies: Map<string, string> = createAnonymousCookies();
    const result: EapiResult = await eapiPost('/api/login/qrcode/unikey', '{"type":3}', cookies);
    if (result.statusCode !== 200) throw new Error(`获取二维码密钥失败（HTTP ${result.statusCode}）`);
    const body: UnikeyResponse = JSON.parse(result.body) as UnikeyResponse;
    const key: string = body.data?.unikey ?? body.unikey ?? '';
    if (body.code !== 200 || key.length === 0) {
      throw new Error(body.message || `获取二维码密钥失败（code ${body.code}）`);
    }
    mergeSetCookies(cookies, result.setCookies);
    const requestId: string = util.generateRandomUUID();
    const pending: PendingQrLogin = { key: key, cookies: cookies };
    pendingQrLogins.set(requestId, pending);
    setTimeout(() => {
      pendingQrLogins.delete(requestId);
    }, 10 * 60 * 1000);
    const state: QrCodeLoginState = new QrCodeLoginState();
    state.key = requestId;
    state.qrUrl = `${BASE_URL}/login?codekey=${key}`;
    state.status = QrLoginStatus.Waiting;
    return state;
  }

  async checkQrCodeStatus(requestId: string): Promise<QrCodeLoginResult> {
    const pending: PendingQrLogin | undefined = pendingQrLogins.get(requestId);
    const result: QrCodeLoginResult = new QrCodeLoginResult();
    if (pending === undefined) {
      result.status = QrLoginStatus.Expired;
      result.message = '二维码已过期';
      return result;
    }
    const qrResult: EapiResult = await eapiPost('/api/login/qrcode/client/login', `{"key":"${pending.key}","type":3}`, pending.cookies);
    let body: QrLoginResponse;
    try {
      body = JSON.parse(qrResult.body) as QrLoginResponse;
    } catch (err) {
      result.status = QrLoginStatus.Failed;
      result.message = '扫码登录请求失败';
      return result;
    }
    let status: QrLoginStatus;
    if (body.code === 800) {
      status = QrLoginStatus.Expired;
    } else if (body.code === 801) {
      status = QrLoginStatus.Waiting;
    } else if (body.code === 802) {
      status = QrLoginStatus.Scanned;
    } else if (body.code === 803) {
      status = QrLoginStatus.Confirmed;
    } else {
      status = QrLoginStatus.Failed;
    }
    if (status !== QrLoginStatus.Confirmed) {
      if (status === QrLoginStatus.Expired || status === QrLoginStatus.Failed) pendingQrLogins.delete(requestId);
      result.status = status;
      result.message = body.message;
      return result;
    }
    const cookies: Map<string, string> = new Map();
    pending.cookies.forEach((value: string, key: string) => {
      cookies.set(key, value);
    });
    mergeSetCookies(cookies, qrResult.setCookies);
    if (body.cookie && body.cookie.length > 0) {
      const fromBody: Map<string, string> = parseCookieString(body.cookie);
      fromBody.forEach((value: string, key: string) => {
        cookies.set(key, value);
      });
    }
    pendingQrLogins.delete(requestId);
    const loginResult: AccountLoginResult = await getAccount(cookies);
    result.status = QrLoginStatus.Confirmed;
    result.account = loginResult.account;
    result.session = loginResult.session;
    return result;
  }

  private async weapiPost(uri: string, dataJson: string, session: LoginSession): Promise<HttpResult> {
    const encrypted: WeapiResult = await weapiEncrypt(dataJson);
    const options: HttpOptions = new HttpOptions();
    options.method = http.RequestMethod.POST;
    options.headers = new Map([
      ['User-Agent', USER_AGENT],
      ['Referer', `${BASE_URL}/`],
    ]);
    options.cookie = session.cookies;
    options.form = `params=${encodeURIComponent(encrypted.params)}&encSecKey=${encodeURIComponent(encrypted.encSecKey)}`;
    return httpFetch(`${BASE_URL}${uri}`, options);
  }

  private async linuxapiPost(uri: string, dataJson: string, session: LoginSession): Promise<HttpResult> {
    const encrypted: string = await linuxapiEncrypt(dataJson);
    const options: HttpOptions = new HttpOptions();
    options.method = http.RequestMethod.POST;
    options.headers = new Map([
      ['User-Agent', USER_AGENT],
      ['Referer', `${BASE_URL}/`],
    ]);
    options.cookie = session.cookies;
    options.form = `eparams=${encodeURIComponent(encrypted)}`;
    return httpFetch(`${BASE_URL}${uri}`, options);
  }

  async getUserPlaylists(sessionValue: LoginSession | undefined): Promise<PlaylistInfo[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'wy', '网易云');
    const bodyData: Record<string, Object> = {
      'uid': session.tokens.get('userId') ?? '',
      'limit': 1000,
      'offset': 0,
    };
    const response: HttpResult = await this.weapiPost(
      '/weapi/user/playlist',
      JSON.stringify(bodyData),
      session,
    );
    if (response.statusCode !== 200) throw new Error(`获取用户歌单失败（HTTP ${response.statusCode}）`);
    const body: PlaylistResponse = JSON.parse(response.body) as PlaylistResponse;
    if (body.code !== 200) throw new Error(body.message || '获取用户歌单失败');
    const list: PlaylistInfo[] = [];
    for (const item of body.playlist ?? []) {
      const info: PlaylistInfo = new PlaylistInfo();
      info.id = String(item.id);
      info.name = item.name ?? '';
      info.source = 'wy';
      info.total = String(item.trackCount ?? 0);
      info.isEditable = String(item.creator?.userId ?? '') === session.tokens.get('userId');
      list.push(info);
    }
    return list;
  }

  async getPlaylistTrackIds(sessionValue: LoginSession | undefined, playlistId: string, dirId: string | undefined): Promise<PlaylistTrackInfo[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'wy', '网易云');
    const params: Record<string, Object> = {
      'id': playlistId,
      'n': 100000,
      's': 8,
    };
    const linuxBody: Record<string, Object> = {
      'method': 'POST',
      'url': `${BASE_URL}/api/v3/playlist/detail`,
      'params': params,
    };
    const linuxData: string = JSON.stringify(linuxBody);
    const response: HttpResult = await this.linuxapiPost('/api/linux/forward', linuxData, session);
    if (response.statusCode !== 200) throw new Error(`获取歌单歌曲失败（HTTP ${response.statusCode}）`);
    const body: LinuxForwardResponse = JSON.parse(response.body) as LinuxForwardResponse;
    if (body.code !== 200) throw new Error(body.message || '获取歌单歌曲失败');
    const trackIds: TrackIdItem[] = body.playlist?.trackIds ?? [];
    const list: PlaylistTrackInfo[] = [];
    for (const item of trackIds) {
      const track: PlaylistTrackInfo = new PlaylistTrackInfo();
      track.id = String(item.id);
      track.removeId = String(item.id);
      list.push(track);
    }
    return list;
  }

  private async mutatePlaylistTracks(
    sessionValue: LoginSession | undefined,
    playlistId: string,
    tracks: PlaylistMutationTrack[],
  ): Promise<void> {
    const session: LoginSession = requireSourceSession(sessionValue, 'wy', '网易云');
    const trackIds: string[] = [];
    for (const track of tracks) {
      if (track.songId.length > 0) trackIds.push(track.songId);
    }
    if (trackIds.length === 0) return;
    const bodyData: Record<string, Object> = {
      'op': 'del',
      'pid': playlistId,
      'trackIds': JSON.stringify(trackIds),
      'imme': 'true',
    };
    const response: HttpResult = await this.weapiPost(
      '/weapi/playlist/manipulate/tracks',
      JSON.stringify(bodyData),
      session,
    );
    if (response.statusCode !== 200) throw new Error(`歌单操作失败（HTTP ${response.statusCode}）`);
    const body: MutateResponse = JSON.parse(response.body) as MutateResponse;
    if (body.code !== 200) throw new Error(body.message || '删除歌曲失败');
  }

  async removePlaylistTracks(sessionValue: LoginSession | undefined, playlistId: string, dirId: string | undefined, tracks: PlaylistMutationTrack[]): Promise<void> {
    await this.mutatePlaylistTracks(sessionValue, playlistId, tracks);
  }

  async getDailyTrackIds(sessionValue: LoginSession | undefined): Promise<string[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'wy', '网易云');
    const response: HttpResult = await this.weapiPost('/weapi/v3/discovery/recommend/songs', '{}', session);
    if (response.statusCode !== 200) throw new Error(`获取每日推荐失败（HTTP ${response.statusCode}）`);
    const body: DailyResponse = JSON.parse(response.body) as DailyResponse;
    if (body.code !== 200) throw new Error(body.message || '获取每日推荐失败');
    const songs: DailySong[] = body.data?.dailySongs ?? [];
    const ids: string[] = [];
    for (const song of songs) ids.push(String(song.id));
    return ids;
  }

  async getTrackDetails(sessionValue: LoginSession | undefined, ids: string[]): Promise<PlatformTrackInfo[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'wy', '网易云');
    const result: PlatformTrackInfo[] = [];
    const chunkSize: number = 500;
    for (let i = 0; i < ids.length; i += chunkSize) {
      const chunk: string[] = ids.slice(i, i + chunkSize);
      const cJson: string = JSON.stringify(chunk.map((id: string): SongDetailReqItem => ({ id: Number(id) })));
      const bodyData: Record<string, Object> = { 'c': cJson, 'ids': `[${chunk.join(',')}]` };
      const response: HttpResult = await this.weapiPost('/weapi/v3/song/detail', JSON.stringify(bodyData), session);
      if (response.statusCode !== 200) throw new Error(`获取歌曲详情失败（HTTP ${response.statusCode}）`);
      const body: SongDetailResponse = JSON.parse(response.body) as SongDetailResponse;
      if (body.code !== 200) throw new Error(body.message || '获取歌曲详情失败');
      for (const item of body.songs ?? []) {
        if (!item || !item.name) continue;
        const track: PlatformTrackInfo = new PlatformTrackInfo();
        track.id = String(item.id);
        track.removeId = String(item.id);
        track.name = item.name;
        const singerNames: string[] = [];
        for (const artist of item.ar ?? []) {
          if (artist.name) singerNames.push(artist.name);
        }
        track.singer = singerNames.join('、');
        track.album = item.al?.name ?? '';
        track.picUrl = item.al?.picUrl ?? '';
        track.interval = formatSeconds(Number(item.dt ?? 0) / 1000);
        track.source = 'wy';
        result.push(track);
      }
    }
    return result;
  }
}
