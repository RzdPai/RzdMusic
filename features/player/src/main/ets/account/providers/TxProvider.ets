import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { cookieStringify, httpFetch, HttpOptions, HttpResult, parseCookieString } from '../HttpUtil';
import { MqttClient, MqttClientOptions, MqttConnectError, MqttConnackInfo, MqttPublishMessage } from '../MqttUtil';
import { formatSeconds, requireSourceSession } from '../ProviderUtil';
import { AccountLoginResult, LoginSession, PlatformAccount, PlaylistInfo, PlaylistMutationTrack, PlaylistTrackInfo, PlatformTrackInfo, QrCodeLoginResult, QrCodeLoginState, QrLoginStatus } from '../AccountModels';
import { MusicProvider } from './MusicProvider';

const LOGIN_ENDPOINT: string = 'https://u.y.qq.com/cgi-bin/musicu.fcg';
const LOGIN_TME_APP_ID: string = 'qqmusic';
const LOGIN_CLIENT_TYPE: number = 19;
const LOGIN_CLIENT_VERSION: number = 11060000;
const USER_AGENT: string = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
const LOG_TAG: string = 'LXAccount';
const MAX_QR_RECONNECT_ATTEMPTS: number = 6;

interface PendingQrLogin {
  client: MqttClient | undefined;
  status: QrLoginStatus;
  cookies: Map<string, string>;
  message: string;
  qrcodeID: string;
  serverReference: string;
  connected: boolean;
  cancelled: boolean;
  suspendRequestId: number;
  reconnectAttempts: number;
  reconnectTimer: number;
  generation: number;
}

interface MusicUComm {
  ct: number;
  cv: number;
  v: number;
  chid: string;
  uid: string;
  qq: string;
  authst: string;
  tmeAppID: string;
  tmeLoginType: number;
  format: string;
  inCharset: string;
  outCharset: string;
  g_tk: number;
}

interface MusicUReq0 {
  module: string;
  method: string;
  param: Object;
}

interface MusicUBody {
  comm: MusicUComm;
  req_0: MusicUReq0;
}

class FavPlaylistParam {
  uin: string = '';
  offset: number = 0;
  size: number = 100;
}

interface MusicUResult {
  code: number;
  message: string;
  data: Record<string, Object>;
}

interface MusicUResponse {
  code: number;
  req_0: MusicUResult;
}

interface LoginResult {
  code: number;
  message: string;
  data: Record<string, Object>;
}

interface LoginResponse {
  code: number;
  req_0: LoginResult;
}

interface DissData {
  hostname: string;
  encrypt_uin: string;
}

interface DissResponse {
  code: number;
  message: string;
  data: DissData;
}

interface SongDetailSinger {
  name: string;
}

interface SongDetailTrack {
  mid: string;
  id: number;
  title: string;
  singer: SongDetailSinger[];
  album: SongDetailAlbum;
  interval: number;
}

interface SongDetailAlbum {
  mid: string;
  name: string;
}

interface SongDetailReqData {
  track_info: SongDetailTrack | undefined;
}

interface SongDetailReq {
  code: number;
  message: string;
  data: SongDetailReqData;
}

interface SongDetailResponse {
  code: number;
  req: SongDetailReq;
}

interface SongDetailParam {
  song_type: number;
  song_mid: string;
}

interface SongDetailReqObj {
  module: string;
  method: string;
  param: SongDetailParam;
}

interface SongDetailComm {
  ct: string;
  cv: string;
  uin: string;
}

interface SongDetailBody {
  comm: SongDetailComm;
  req: SongDetailReqObj;
}

const pendingQrLogins: Map<string, PendingQrLogin> = new Map();

function hash33(value: string, seed: number): number {
  let hash: number = seed;
  for (let i = 0; i < value.length; i++) {
    hash += (hash << 5) + value.charCodeAt(i);
  }
  return hash & 0x7fffffff;
}

function getUin(cookies: Map<string, string>): string {
  const raw: string = cookies.get('qqmusic_uin') ?? cookies.get('musicid') ?? cookies.get('uin') ??
    cookies.get('p_uin') ?? cookies.get('pt2gguin') ?? '';
  return raw.replace(/^o/, '').replace(/\D/g, '');
}

function getMusicKey(cookies: Map<string, string>): string {
  return cookies.get('qqmusic_key') ?? cookies.get('qm_keyst') ?? cookies.get('musickey') ??
    cookies.get('psrf_musickey') ?? cookies.get('p_skey') ?? cookies.get('skey') ?? '';
}

function getGtk(session: LoginSession): number {
  const seed: string = session.cookies.get('p_skey') ?? session.cookies.get('skey') ?? session.tokens.get('musicKey') ?? '';
  return hash33(seed, 5381);
}

function buildLoginResult(uin: string, musicKey: string, cookies: Map<string, string>, nickname: string): AccountLoginResult {
  const account: PlatformAccount = new PlatformAccount();
  account.id = `tx_${uin}`;
  account.source = 'tx';
  account.nickname = nickname.trim().length > 0 ? nickname : `QQ用户 ${uin}`;
  account.avatar = `https://q1.qlogo.cn/g?b=qq&nk=${uin}&s=100`;
  const session: LoginSession = new LoginSession();
  session.source = 'tx';
  cookies.forEach((value: string, key: string) => {
    session.cookies.set(key, value);
  });
  session.tokens.set('uin', uin);
  session.tokens.set('musicKey', musicKey);
  return { account: account, session: session };
}

function commonHeaders(session: LoginSession): Map<string, string> {
  return new Map([
    ['Cookie', cookieStringify(session.cookies)],
    ['User-Agent', USER_AGENT],
    ['Referer', 'https://y.qq.com/portal/profile.html'],
  ]);
}

async function requestMusicU(session: LoginSession, module: string, method: string, param: Record<string, Object>): Promise<Record<string, Object>> {
  const uin: string = session.tokens.get('uin') ?? '';
  const musicKey: string = session.tokens.get('musicKey') ?? '';
  const comm: MusicUComm = {
    ct: 11,
    cv: 14090008,
    v: 14090008,
    chid: '10003505',
    uid: uin,
    qq: uin,
    authst: musicKey,
    tmeAppID: LOGIN_TME_APP_ID,
    tmeLoginType: musicKey.startsWith('W_X') ? 1 : 2,
    format: 'json',
    inCharset: 'utf-8',
    outCharset: 'utf-8',
    g_tk: getGtk(session),
  };
  const req0: MusicUReq0 = { module: module, method: method, param: param };
  const body: MusicUBody = { comm: comm, req_0: req0 };
  const options: HttpOptions = new HttpOptions();
  options.method = http.RequestMethod.POST;
  options.headers = commonHeaders(session);
  options.headers.set('Origin', 'https://y.qq.com');
  options.json = JSON.stringify(body);
  const response: HttpResult = await httpFetch(LOGIN_ENDPOINT, options);
  if (response.statusCode !== 200) throw new Error(`QQ 音乐请求失败（${method}，HTTP ${response.statusCode}）`);
  const parsed: MusicUResponse = JSON.parse(response.body) as MusicUResponse;
  const result: MusicUResult = parsed.req_0;
  if (parsed.code !== 0 || result.code !== 0) {
    const message: string = result.message || `QQ 音乐请求失败（${method}）`;
    throw new Error(`${message}（code ${parsed.code}/${result.code}）`);
  }
  return result.data ?? {};
}

async function requestLogin(method: string, param: Record<string, Object>): Promise<Record<string, Object>> {
  const req0: MusicUReq0 = { module: 'music.login.LoginServer', method: method, param: param };
  const comm: Record<string, Object> = {};
  const body: Record<string, Object> = {
    'comm': comm,
    'req_0': req0,
  };
  const options: HttpOptions = new HttpOptions();
  options.method = http.RequestMethod.POST;
  options.headers = new Map([
    ['Origin', 'https://y.qq.com'],
    ['Referer', 'https://y.qq.com/'],
    ['User-Agent', USER_AGENT],
  ]);
  options.json = JSON.stringify(body);
  const response: HttpResult = await httpFetch(LOGIN_ENDPOINT, options);
  if (response.statusCode !== 200) throw new Error(`QQ 音乐登录请求失败（${method}）`);
  const parsed: LoginResponse = JSON.parse(response.body) as LoginResponse;
  const result: LoginResult = parsed.req_0;
  if (parsed.code !== 0 || result.code !== 0) {
    throw new Error(String(result.data?.['errMsg'] ?? result.message ?? `QQ 音乐登录请求失败（${method}）`));
  }
  const emptyData: Record<string, Object> = {};
  return result.data ?? emptyData;
}

function parseMqttCookies(value: Object): Map<string, string> {
  const cookies: Map<string, string> = new Map();
  const entries: Record<string, Object> = value as Record<string, Object>;
  for (const name of Object.keys(entries)) {
    const cookie: Object = entries[name];
    let raw: Object | undefined = cookie;
    if (cookie && typeof cookie === 'object') {
      const cookieRecord: Record<string, Object> = cookie as Record<string, Object>;
      if (Object.keys(cookieRecord).includes('value')) {
        raw = cookieRecord['value'];
      }
    }
    if (raw != null && String(raw).length > 0) cookies.set(name, String(raw));
  }
  return cookies;
}

function beginSuspendDelay(pending: PendingQrLogin): void {
  if (pending.suspendRequestId > 0) return;
  try {
    if (canIUse('SystemCapability.ResourceSchedule.BackgroundTaskManager.TransientTask')) {
      const info: backgroundTaskManager.DelaySuspendInfo =
        backgroundTaskManager.requestSuspendDelay('QQ 音乐扫码登录，等待手机确认', () => {
          pending.suspendRequestId = 0;
          hilog.info(0x0000, LOG_TAG, 'QQ 扫码挂起延迟已到期');
        });
      pending.suspendRequestId = info.requestId;
      hilog.info(0x0000, LOG_TAG, 'QQ 扫码挂起延迟已申请 %{public}d ms', info.actualDelayTime);
    }
  } catch (err) {
    const error: Error = err as Error;
    hilog.warn(0x0000, LOG_TAG, 'QQ 扫码挂起申请失败: %{public}s', error.message ?? '');
  }
}

function endSuspendDelay(pending: PendingQrLogin): void {
  if (pending.suspendRequestId <= 0) return;
  try {
    backgroundTaskManager.cancelSuspendDelay(pending.suspendRequestId);
  } catch (err) {
    const error: Error = err as Error;
    hilog.warn(0x0000, LOG_TAG, 'QQ 扫码挂起取消失败: %{public}s', error.message ?? '');
  }
  pending.suspendRequestId = 0;
}

function scheduleQrReconnect(qrcodeID: string, pending: PendingQrLogin, serverReference: string): void {
  if (pending.cancelled) return;
  if (pending.status !== QrLoginStatus.Waiting && pending.status !== QrLoginStatus.Scanned) return;
  if (pending.reconnectTimer >= 0) return;
  if (pending.reconnectAttempts >= MAX_QR_RECONNECT_ATTEMPTS) {
    pending.status = QrLoginStatus.Failed;
    pending.message = 'QQ 音乐扫码连接不稳定，请刷新二维码重试';
    endSuspendDelay(pending);
    return;
  }
  pending.reconnectAttempts++;
  const delay: number = Math.min(1000 * Math.pow(2, pending.reconnectAttempts - 1), 15000);
  pending.reconnectTimer = setTimeout(() => {
    pending.reconnectTimer = -1;
    void reconnectQrMqtt(qrcodeID, pending, serverReference);
  }, delay);
  hilog.info(0x0000, LOG_TAG, 'QQ 扫码连接断开，%{public}d ms 后重连（第 %{public}d 次）', delay, pending.reconnectAttempts);
}

async function reconnectQrMqtt(qrcodeID: string, pending: PendingQrLogin, serverReference: string): Promise<void> {
  if (pending.cancelled) return;
  if (pending.status !== QrLoginStatus.Waiting && pending.status !== QrLoginStatus.Scanned) return;
  try {
    await connectQrMqtt(qrcodeID, pending, serverReference, 0);
    pending.connected = true;
  } catch (err) {
    const error: Error = err as Error;
    hilog.warn(0x0000, LOG_TAG, 'QQ 扫码重连失败: %{public}s', error.message ?? '');
  }
}

function bindQrMqttEvents(client: MqttClient, pending: PendingQrLogin, onConnectionLost: () => void): void {
  client.onPublish = (message: MqttPublishMessage) => {
    const event: string = message.userProperties.get('type') ?? '';
    if (event === 'scanned') {
      pending.status = QrLoginStatus.Scanned;
      return;
    }
    if (event === 'cookies') {
      const payloadText: string = utf8Decode(message.payload);
      let payload: Record<string, Object>;
      try {
        payload = JSON.parse(payloadText) as Record<string, Object>;
      } catch (err) {
        return;
      }
      const cookies: Map<string, string> = parseMqttCookies(payload['cookies'] ?? new Object());
      if (getUin(cookies).length > 0 && getMusicKey(cookies).length > 0) {
        pending.cookies = cookies;
        pending.status = QrLoginStatus.Confirmed;
      } else {
        pending.status = QrLoginStatus.Failed;
        pending.message = 'QQ 音乐登录成功，但未收到有效音乐凭证';
      }
      client.close();
      return;
    }
    if (event === 'timeout') pending.status = QrLoginStatus.Expired;
    if (event === 'canceled' || event === 'loginFailed') pending.status = QrLoginStatus.Failed;
    if (pending.status === QrLoginStatus.Expired || pending.status === QrLoginStatus.Failed) client.close();
  };
  client.onError = (err: Error) => {
    if (pending.status === QrLoginStatus.Waiting || pending.status === QrLoginStatus.Scanned) {
      if (!pending.connected) {
        pending.status = QrLoginStatus.Failed;
        pending.message = `QQ 音乐扫码连接异常：${err.message}`;
        endSuspendDelay(pending);
      } else {
        pending.connected = false;
        onConnectionLost();
      }
    }
  };
  client.onClose = () => {
    if (pending.status === QrLoginStatus.Waiting || pending.status === QrLoginStatus.Scanned) {
      pending.connected = false;
      onConnectionLost();
    }
  };
}

function utf8Decode(bytes: Uint8Array): string {
  const decoder: util.TextDecoder = new util.TextDecoder('utf-8');
  return decoder.decode(bytes);
}

async function connectQrMqtt(qrcodeID: string, pending: PendingQrLogin, serverReference: string, redirectCount: number): Promise<void> {
  const options: MqttClientOptions = new MqttClientOptions();
  options.clientId = `${Date.now()}${Math.floor(1000 + Math.random() * 9000)}`;
  options.authenticationMethod = 'pass';
  options.userProperties = new Map([
    ['tmeAppID', LOGIN_TME_APP_ID],
    ['business', 'management'],
    ['hashTag', qrcodeID],
    ['clientTag', 'management.user'],
    ['userID', qrcodeID],
  ]);
  options.headers = new Map([
    ['Origin', 'https://y.qq.com'],
    ['Referer', 'https://y.qq.com/'],
  ]);
  pending.generation++;
  const myGeneration: number = pending.generation;
  const client: MqttClient = new MqttClient();
  pending.client = client;
  let currentReference: string = serverReference;
  client.onConnack = (info: MqttConnackInfo) => {
    pending.connected = true;
    if (info.serverReference.length > 0) currentReference = info.serverReference;
    pending.serverReference = currentReference;
    client.subscribe(`management.qrcode_login/${qrcodeID}`, new Map([
      ['authorization', 'tmelogin'],
      ['pubsub', 'unicast'],
    ]));
  };
  const onConnectionLost: () => void = () => {
    if (myGeneration !== pending.generation) return;
    scheduleQrReconnect(qrcodeID, pending, currentReference);
  };
  bindQrMqttEvents(client, pending, onConnectionLost);
  try {
    await client.connect(options);
    pending.connected = true;
  } catch (err) {
    const connectError: MqttConnectError = err as MqttConnectError;
    const code: number = connectError?.code ?? 0;
    if ((code === 156 || code === 157) && currentReference.length > 0 && redirectCount < 3) {
      await connectQrMqtt(qrcodeID, pending, currentReference, redirectCount + 1);
      return;
    }
    throw connectError;
  }
}

class LegacyDissResult {
  nickname: string = '';
  encryptUin: string = '';
}

async function fetchLegacyUserDiss(session: LoginSession): Promise<LegacyDissResult> {
  const uin: string = session.tokens.get('uin') ?? '';
  const params: Map<string, string> = new Map([
    ['hostUin', '0'],
    ['hostuin', uin],
    ['sin', '0'],
    ['size', '1000'],
    ['g_tk', String(getGtk(session))],
    ['loginUin', uin],
    ['format', 'json'],
    ['platform', 'yqq.json'],
  ]);
  const parts: string[] = [];
  params.forEach((value: string, key: string) => {
    parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
  });
  const url: string = `https://c.y.qq.com/rsc/fcgi-bin/fcg_user_created_diss?${parts.join('&')}`;
  const options: HttpOptions = new HttpOptions();
  options.method = http.RequestMethod.GET;
  options.headers = commonHeaders(session);
  const response: HttpResult = await httpFetch(url, options);
  if (response.statusCode !== 200) throw new Error(`获取 QQ 音乐信息失败（HTTP ${response.statusCode}）`);
  const body: DissResponse = JSON.parse(response.body) as DissResponse;
  if (body.code !== 0) throw new Error(body.message || '获取 QQ 音乐信息失败');
  const data: DissData = body.data ?? { hostname: '', encrypt_uin: '' };
  const result: LegacyDissResult = new LegacyDissResult();
  result.nickname = data.hostname ?? '';
  result.encryptUin = data.encrypt_uin ?? '';
  return result;
}

export class TxProvider implements MusicProvider {
  async loginByCookie(cookie: string): Promise<AccountLoginResult> {
    const cookies: Map<string, string> = parseCookieString(cookie);
    const uin: string = getUin(cookies);
    const musicKey: string = getMusicKey(cookies);
    if (uin.length === 0 || musicKey.length === 0) {
      throw new Error('Cookie 中缺少 QQ 账号或音乐凭证');
    }
    const result: AccountLoginResult = buildLoginResult(uin, musicKey, cookies, '');
    try {
      const playlists: PlaylistInfo[] = await this.getUserPlaylists(result.session);
      if (playlists.length > 0) {
        const nick: string = result.session.tokens.get('nickname') ?? '';
        if (nick.length > 0) result.account.nickname = nick;
      }
    } catch (err) {
      // 歌单昵称获取失败不阻断登录
    }
    return result;
  }

  async createQrCode(): Promise<QrCodeLoginState> {
    const param: Record<string, Object> = {
      'tmeAppID': LOGIN_TME_APP_ID,
      'ct': LOGIN_CLIENT_TYPE,
      'cv': LOGIN_CLIENT_VERSION,
    };
    const data: Record<string, Object> = await requestLogin('CreateQRCode', param);
    const qrcodeID: string = String(data['qrcodeID'] ?? '');
    const qrUrl: string = String(data['qrcode'] ?? '');
    if (qrcodeID.length === 0 || !qrUrl.startsWith('data:image/png;base64,')) {
      throw new Error('获取 QQ 音乐二维码失败');
    }
    const requestId: string = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    const pending: PendingQrLogin = {
      client: undefined,
      status: QrLoginStatus.Waiting,
      cookies: new Map(),
      message: '',
      qrcodeID: qrcodeID,
      serverReference: '',
      connected: false,
      cancelled: false,
      suspendRequestId: 0,
      reconnectAttempts: 0,
      reconnectTimer: -1,
      generation: 0,
    };
    pendingQrLogins.set(requestId, pending);
    try {
      await connectQrMqtt(qrcodeID, pending, '', 0);
      pending.connected = true;
      beginSuspendDelay(pending);
    } catch (err) {
      pending.cancelled = true;
      endSuspendDelay(pending);
      if (pending.reconnectTimer >= 0) {
        clearTimeout(pending.reconnectTimer);
        pending.reconnectTimer = -1;
      }
      pendingQrLogins.delete(requestId);
      const connectError: Error = err as Error;
      throw new Error(connectError.message || '连接 QQ 音乐扫码服务失败');
    }
    const expiresIn: number = Number(data['expiresIn'] ?? 900);
    setTimeout(() => {
      const current: PendingQrLogin | undefined = pendingQrLogins.get(requestId);
      if (current && (current.status === QrLoginStatus.Waiting || current.status === QrLoginStatus.Scanned)) {
        current.status = QrLoginStatus.Expired;
      }
      endSuspendDelay(pending);
      if (pending.reconnectTimer >= 0) {
        clearTimeout(pending.reconnectTimer);
        pending.reconnectTimer = -1;
      }
      pending.client?.close();
    }, expiresIn * 1000);
    const state: QrCodeLoginState = new QrCodeLoginState();
    state.key = requestId;
    state.qrUrl = qrUrl;
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
    if (pending.status === QrLoginStatus.Confirmed || pending.status === QrLoginStatus.Expired || pending.status === QrLoginStatus.Failed) {
      endSuspendDelay(pending);
    }
    if (pending.status !== QrLoginStatus.Confirmed || pending.cookies.size === 0) {
      if (!pending.connected && !pending.cancelled &&
        (pending.status === QrLoginStatus.Waiting || pending.status === QrLoginStatus.Scanned) &&
        pending.reconnectTimer < 0) {
        scheduleQrReconnect(pending.qrcodeID, pending, pending.serverReference);
      }
      result.status = pending.status;
      result.message = pending.message;
      return result;
    }
    const uin: string = getUin(pending.cookies);
    const musicKey: string = getMusicKey(pending.cookies);
    if (uin.length === 0 || musicKey.length === 0) {
      result.status = QrLoginStatus.Failed;
      result.message = '登录成功但未获取到 QQ 音乐凭证';
      return result;
    }
    pendingQrLogins.delete(requestId);
    endSuspendDelay(pending);
    if (pending.reconnectTimer >= 0) {
      clearTimeout(pending.reconnectTimer);
      pending.reconnectTimer = -1;
    }
    pending.client?.close();
    const loginResult: AccountLoginResult = buildLoginResult(uin, musicKey, pending.cookies, '');
    try {
      const playlists: PlaylistInfo[] = await this.getUserPlaylists(loginResult.session);
      if (playlists.length > 0) {
        const nick: string = loginResult.session.tokens.get('nickname') ?? '';
        if (nick.length > 0) loginResult.account.nickname = nick;
      }
    } catch (err) {
      // 忽略昵称获取失败
    }
    result.status = QrLoginStatus.Confirmed;
    result.account = loginResult.account;
    result.session = loginResult.session;
    return result;
  }

  cancelQrCode(requestId: string): void {
    const pending: PendingQrLogin | undefined = pendingQrLogins.get(requestId);
    if (pending) {
      pending.cancelled = true;
      endSuspendDelay(pending);
      if (pending.reconnectTimer >= 0) {
        clearTimeout(pending.reconnectTimer);
        pending.reconnectTimer = -1;
      }
      pending.client?.close();
      pendingQrLogins.delete(requestId);
    }
  }

  async getUserPlaylists(sessionValue: LoginSession | undefined): Promise<PlaylistInfo[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'tx', 'QQ 音乐');
    try {
      const legacy: LegacyDissResult = await fetchLegacyUserDiss(session);
      if (legacy.encryptUin.length > 0) session.tokens.set('encryptUin', legacy.encryptUin);
      if (legacy.nickname.length > 0) session.tokens.set('nickname', legacy.nickname);
    } catch (err) {
      const error: Error = err as Error;
      hilog.warn(0x0000, 'LXAccount', 'fetchLegacyUserDiss failed: %{public}s', error.message ?? '');
    }
    const uin: string = session.tokens.get('uin') ?? '';
    const param: Record<string, Object> = { 'uin': uin };
    const data: Record<string, Object> = await requestMusicU(session, 'music.musicasset.PlaylistBaseRead', 'GetPlaylistByUin', param);
    const rawList: Object | undefined = data['v_playlist'];
    const items: Array<Record<string, Object>> = (rawList ?? []) as Array<Record<string, Object>>;
    const list: PlaylistInfo[] = [];
    for (const item of items) {
      const info: PlaylistInfo = new PlaylistInfo();
      info.id = String(item['tid'] ?? item['disstid'] ?? '');
      info.name = String(item['dirName'] ?? item['title'] ?? item['name'] ?? '');
      info.source = 'tx';
      info.total = String(item['songNum'] ?? item['songnum'] ?? 0);
      info.dirId = String(item['dirId'] ?? item['dirid'] ?? '');
      info.isEditable = true;
      if (info.id.length > 0) list.push(info);
    }
    const collected: PlaylistInfo[] = await this.getCollectedPlaylists(sessionValue).catch((err: Error) => {
      hilog.warn(0x0000, 'LXAccount', 'getCollectedPlaylists failed: %{public}s', err.message ?? String(err));
      return [];
    });
    for (const item of collected) list.push(item);
    return list;
  }

  private async getCollectedPlaylists(sessionValue: LoginSession | undefined): Promise<PlaylistInfo[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'tx', 'QQ 音乐');
    const uin: string = session.tokens.get('uin') ?? '';
    const musicKey: string = session.tokens.get('musicKey') ?? '';
    const comm: MusicUComm = {
      ct: 11,
      cv: 14090008,
      v: 14090008,
      chid: '10003505',
      uid: uin,
      qq: uin,
      authst: musicKey,
      tmeAppID: LOGIN_TME_APP_ID,
      tmeLoginType: musicKey.startsWith('W_X') ? 1 : 2,
      format: 'json',
      inCharset: 'utf-8',
      outCharset: 'utf-8',
      g_tk: getGtk(session),
    };
    const paramObj: FavPlaylistParam = new FavPlaylistParam();
    const storedEnc: string = session.tokens.get('encryptUin') ?? '';
    paramObj.uin = storedEnc.length > 0 ? storedEnc : uin;
    paramObj.offset = 0;
    paramObj.size = 100;
    const req0: MusicUReq0 = {
      module: 'music.musicasset.PlaylistFavRead',
      method: 'CgiGetPlaylistFavInfo',
      param: paramObj,
    };
    const body: MusicUBody = { comm: comm, req_0: req0 };
    const options: HttpOptions = new HttpOptions();
    options.method = http.RequestMethod.POST;
    options.headers = commonHeaders(session);
    options.headers.set('Origin', 'https://y.qq.com');
    options.json = JSON.stringify(body);
    const response: HttpResult = await httpFetch(LOGIN_ENDPOINT, options);
    if (response.statusCode !== 200) throw new Error(`QQ 音乐请求失败（CgiGetPlaylistFavInfo，HTTP ${response.statusCode}）`);
    hilog.info(0x0000, 'LXAccount', 'favplaylist raw body: %{private}s (uinSet=%{private}s)', response.body.substring(0, 800), paramObj.uin.length > 0 ? 'yes' : 'no');
    const parsed: MusicUResponse = JSON.parse(response.body) as MusicUResponse;
    const result: MusicUResult = parsed.req_0;
    if (parsed.code !== 0 || result.code !== 0) {
      throw new Error(`${result.message || 'QQ 音乐请求失败（CgiGetPlaylistFavInfo）'}（code ${parsed.code}/${result.code}）`);
    }
    const data: Record<string, Object> = result.data ?? {};
    let raw: Object | undefined = data['v_list'];
    if (raw === undefined) raw = [];
    const items: Array<Record<string, Object>> = raw as Array<Record<string, Object>>;
    const list: PlaylistInfo[] = [];
    for (const item of items) {
      const id: string = String(item['tid'] ?? item['disstid'] ?? item['dissid'] ?? item['id'] ?? '');
      if (id.length === 0) continue;
      const infoItem: PlaylistInfo = new PlaylistInfo();
      infoItem.id = id;
      infoItem.name = String(item['title'] ?? item['name'] ?? '');
      infoItem.source = 'tx';
      infoItem.total = String(item['songnum'] ?? item['song_cnt'] ?? 0);
      infoItem.dirId = String(item['dirId'] ?? item['dirid'] ?? '');
      infoItem.isEditable = false;
      list.push(infoItem);
    }
    return list;
  }

  async getPlaylistTrackIds(sessionValue: LoginSession | undefined, playlistId: string, dirId: string | undefined): Promise<PlaylistTrackInfo[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'tx', 'QQ 音乐');
    if (playlistId === '0') return [];
    const pageSize: number = 500;
    const tracks: PlaylistTrackInfo[] = [];
    let songBegin: number = 0;
    while (true) {
      const param: Record<string, Object> = {
        'disstid': Number(playlistId),
        'dirid': Number(dirId) || 0,
        'tag': true,
        'song_begin': songBegin,
        'song_num': pageSize,
        'userinfo': true,
        'orderlist': true,
        'onlysonglist': false,
      };
      const data: Record<string, Object> = await requestMusicU(session, 'music.srfDissInfo.DissInfo', 'CgiGetDiss', param);
      const songs: Array<Record<string, Object>> = (data['songlist'] ?? []) as Array<Record<string, Object>>;
      for (const song of songs) {
        const id: string = String(song['mid'] ?? song['songmid'] ?? '');
        if (id.length === 0) continue;
        const item: PlaylistTrackInfo = new PlaylistTrackInfo();
        item.id = id;
        item.removeId = String(song['id'] ?? song['songid'] ?? '');
        tracks.push(item);
      }
      const totalNum: number = Number(data['total_song_num'] ?? 0);
      const hasMore: number = Number(data['hasmore'] ?? 1);
      if (songs.length === 0 || songs.length < pageSize || hasMore === 0 || tracks.length >= totalNum) break;
      songBegin += songs.length;
    }
    const unique: Map<string, PlaylistTrackInfo> = new Map();
    for (const track of tracks) unique.set(track.id, track);
    return Array.from(unique.values());
  }

  private async requestLegacyPlaylist(session: LoginSession, endpoint: string, params: Map<string, string>): Promise<void> {
    const parts: string[] = [];
    params.forEach((value: string, key: string) => {
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    });
    const url: string = `${endpoint}?g_tk=${getGtk(session)}&${parts.join('&')}`;
    const options: HttpOptions = new HttpOptions();
    options.method = http.RequestMethod.GET;
    options.headers = commonHeaders(session);
    const response: HttpResult = await httpFetch(url, options);
    if (response.statusCode !== 200) throw new Error(`QQ 音乐歌单操作失败（HTTP ${response.statusCode}）`);
    const body: Record<string, Object> = JSON.parse(response.body) as Record<string, Object>;
    if (Number(body['code']) !== 0) {
      throw new Error(String(body['msg'] ?? body['message'] ?? 'QQ 音乐歌单操作失败'));
    }
  }

  async removePlaylistTracks(sessionValue: LoginSession | undefined, playlistId: string, dirId: string | undefined, tracks: PlaylistMutationTrack[]): Promise<void> {
    const session: LoginSession = requireSourceSession(sessionValue, 'tx', 'QQ 音乐');
    const ids: string[] = [];
    for (const track of tracks) {
      if (track.platformId.length > 0) ids.push(track.platformId);
    }
    if (!dirId || dirId.length === 0) throw new Error('QQ 音乐歌单缺少目录 ID');
    if (ids.length !== tracks.length) throw new Error('部分歌曲缺少 QQ 音乐歌曲 ID');
    const params: Map<string, string> = new Map();
    params.set('loginUin', session.tokens.get('uin') ?? '');
    params.set('hostUin', '0');
    params.set('format', 'json');
    params.set('inCharset', 'utf8');
    params.set('outCharset', 'utf-8');
    params.set('notice', '0');
    params.set('platform', 'yqq.post');
    params.set('needNewCode', '0');
    params.set('uin', session.tokens.get('uin') ?? '');
    params.set('dirid', dirId);
    params.set('ids', ids.join(','));
    params.set('source', '103');
    params.set('types', ids.map(() => '3').join(','));
    params.set('formsender', '4');
    params.set('flag', '2');
    params.set('utf8', '1');
    params.set('from', '3');
    await this.requestLegacyPlaylist(session, 'https://c.y.qq.com/qzone/fcg-bin/fcg_music_delbatchsong.fcg', params);
  }

  async getDailyTrackIds(sessionValue: LoginSession | undefined): Promise<string[]> {
    const session: LoginSession = requireSourceSession(sessionValue, 'tx', 'QQ 音乐');
    const ids: string[] = [];
    for (let page: number = 1; page <= 3; page++) {
      const param: Record<string, Object> = {
        'Page': page,
        'ReqType': 0,
        'FavSongs': [],
        'EntranceSongs': [],
      };
      const data: Record<string, Object> = await requestMusicU(session, 'music.recommend.TrackRelationServer', 'GetRadarSong', param);
      const songs: Array<Record<string, Object>> = (data['VecSongs'] ?? []) as Array<Record<string, Object>>;
      for (const raw of songs) {
        const track: Record<string, Object> = (raw['Track'] ?? raw) as Record<string, Object>;
        const mid: string = String(track['mid'] ?? '');
        if (mid.length > 0) ids.push(mid);
      }
      const hasMore: boolean = Boolean(data['HasMore']);
      if (!hasMore || songs.length === 0) break;
    }
    return Array.from(new Set(ids));
  }

  async getTrackDetails(sessionValue: LoginSession | undefined, mids: string[]): Promise<PlatformTrackInfo[]> {
    const result: PlatformTrackInfo[] = [];
    const batchSize: number = 20;
    for (let i = 0; i < mids.length; i += batchSize) {
      const chunk: string[] = mids.slice(i, i + batchSize);
      const items: Array<PlatformTrackInfo | undefined> = await Promise.all(chunk.map(
        async (mid: string): Promise<PlatformTrackInfo | undefined> => {
          try {
            const req0: SongDetailReqObj = {
              module: 'music.pf_song_detail_svr',
              method: 'get_song_detail_yqq',
              param: { song_type: 0, song_mid: mid },
            };
            const body: SongDetailBody = {
              comm: { ct: '19', cv: '1859', uin: '0' },
              req: req0,
            };
            const options: HttpOptions = new HttpOptions();
            options.method = http.RequestMethod.POST;
            options.headers = new Map([['User-Agent', USER_AGENT]]);
            options.json = JSON.stringify(body);
            const response: HttpResult = await httpFetch(LOGIN_ENDPOINT, options);
            if (response.statusCode !== 200) return undefined;
            const parsed: SongDetailResponse = JSON.parse(response.body) as SongDetailResponse;
            if (parsed.code !== 0 || parsed.req.code !== 0) return undefined;
            const item: SongDetailTrack | undefined = parsed.req.data?.track_info;
            if (!item || !item.title || !item.mid) return undefined;
            const track: PlatformTrackInfo = new PlatformTrackInfo();
            track.id = item.mid;
            track.removeId = String(item.id ?? '');
            track.name = item.title;
            const singerNames: string[] = [];
            for (const singer of item.singer ?? []) {
              if (singer.name) singerNames.push(singer.name);
            }
            track.singer = singerNames.join('、');
            track.album = item.album?.name ?? '';
            const coverId: string = item.album?.mid ?? '';
            track.picUrl = coverId.length > 0 && coverId !== '空'
              ? `https://y.gtimg.cn/music/photo_new/T002R300x300M000${coverId}.jpg`
              : '';
            track.interval = formatSeconds(Number(item.interval ?? 0));
            track.source = 'tx';
            return track;
          } catch (err) {
            return undefined;
          }
        },
      ));
      for (const item of items) {
        if (item) result.push(item);
      }
    }
    return result;
  }
}
