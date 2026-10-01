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

/**
 * ▼ QQ 扫码 MQTT 的官方入口与信任边界
 *
 * MQTT 5 规范（OASIS MQTT 5.0 §3.2.2.3.16 Server Reference / §4.11 Server redirection）：Server Reference
 * 只在 CONNACK / DISCONNECT 的 0x9C（Use another server）、0x9D（Server moved）里出现，取值是「空格分隔的
 * 多个候选」，**格式未作规定**（非规范建议形如 name[:port]，也允许服务端不发、客户端忽略）。
 *
 * 血泪史（三轮）：
 *   1) 旧实现要求它必须是「wss://*.y.qq.com[:443]/…」⇒ 任何其它形态都被误判成
 *      「扫码服务返回不受信任的连接地址」；
 *   2) 放宽成「官方域名族放行、其余忽略并回官方入口」之后 ⇒ 变成了
 *      **概率性「扫码服务拒绝连接（reason 157）」**：服务端说"服务端已迁移"，
 *      我们却当没听见，反复去敲 mu.y.qq.com:443，于是 157 一直复现。
 *
 * 现在的口径：**服务端让去哪就去哪**（这才是 MQTT 5 规定的行为，真实 QQ 客户端也是这么做的），
 *   只做「明显不可能是一个 broker」的排除：
 *     · 非 ws(s)/http(s) 协议、含 userinfo（@）或反斜杠、缺 host、端口非法；
 *     · 本机 / 回环 / 链路本地 / 内网段（.local/.internal/.lan、127.、169.254.、10.、192.168.、172.16-31.、::1、fe80::）。
 *   其余（官方域名族、公网 IP、任意域名、带路径/端口/无路径/URL 编码/多候选）一律**照用**，
 *   每次连接前把 `raw=… -> endpoint=… source=…` 写日志（tag `RzdTxLogin`）便于回传排查。
 *   连接始终是 wss（TLS）且地址来自我们自己刚建立的那条 TLS 会话，票据不会发给第三方。
 */
const QR_BROKER_HOST: string = 'mu.y.qq.com';
const QR_BROKER_PORT: string = '443';
const QR_BROKER_PATH: string = '/ws/handshake';
const QR_DEFAULT_ENDPOINT: string = `wss://${QR_BROKER_HOST}:${QR_BROKER_PORT}${QR_BROKER_PATH}`;
/** 官方域名族：只用于日志里标注「这是官方域」，不再是放行门槛。 */
const QR_TRUSTED_DOMAINS: string[] = ['qq.com', 'tencentmusic.com', 'tencent.com'];
/** 扫码链路专用日志 tag：真机排障 grep RzdTxLogin（日志里带服务端实际返回的地址）。 */
const QR_LOG_TAG: string = 'RzdTxLogin';
const QR_LOG_VALUE_LIMIT: number = 96;
/**
 * 被要求「迁移服务器」时最多重试几次官方入口。
 *
 * 实测官方 WS 网关的迁移概率约 83%（本机采样 10/12），每次重试都是**新连接**，
 * 有机会落到不迁移的网关上；6 次重试把成功率从 ~17% 抬到 ~90%。
 */
const QR_MAX_REDIRECTS: number = 6;
/** 每次重试之间的间隔（ms）：给负载均衡换个网关的机会，也不至于让用户干等。 */
const QR_REDIRECT_DELAY_MS: number = 300;

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

/**
 * 读取 refresh 材料。
 * QQ 的 musickey 是有寿命的（服务端下发 keyExpiresIn），没有 refresh_key /
 * refresh_token 就无法静默续期，过期后接口一律 1000/104401，表现成
 * 「登录过但用不了」。这里把服务端可能用的几种字段名都兜住。
 */
function getRefreshKey(cookies: Map<string, string>): string {
  return cookies.get('refresh_key') ?? cookies.get('refreshKey') ??
    cookies.get('psrf_qqrefresh_key') ?? cookies.get('psrf_qqrefresh_token') ?? '';
}

function getRefreshToken(cookies: Map<string, string>): string {
  return cookies.get('refresh_token') ?? cookies.get('refreshToken') ??
    cookies.get('psrf_qqrefresh_token') ?? '';
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
  // 补齐可续期/可诊断字段（历史实现只存 uin + musicKey，登录态一过期就彻底废掉）
  const refreshKey: string = getRefreshKey(cookies);
  const refreshToken: string = getRefreshToken(cookies);
  if (refreshKey.length > 0) {
    session.tokens.set('refreshKey', refreshKey);
  }
  if (refreshToken.length > 0) {
    session.tokens.set('refreshToken', refreshToken);
  }
  session.tokens.set('musicKeyCreateTime', String(Math.floor(Date.now() / 1000)));
  session.tokens.set('loginType', musicKey.startsWith('W_X') ? '1' : '2');
  const encryptUin: string = cookies.get('encrypt_uin') ?? '';
  if (encryptUin.length > 0) {
    session.tokens.set('encryptUin', encryptUin);
  }
  // 只列 key 名，便于排障时确认服务端下发了哪些字段（不落敏感值）
  const cookieKeys: string[] = [];
  cookies.forEach((_value: string, key: string) => {
    cookieKeys.push(key);
  });
  hilog.info(0x0000, LOG_TAG, 'QQ 登录凭证 keys=[%{public}s] hasRefreshKey=%{public}d',
    cookieKeys.join(','), refreshKey.length > 0 ? 1 : 0);
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
          hilog.info(0x0000, QR_LOG_TAG, 'QQ 扫码挂起延迟已到期');
        });
      pending.suspendRequestId = info.requestId;
      hilog.info(0x0000, QR_LOG_TAG, 'QQ 扫码挂起延迟已申请 %{public}d ms', info.actualDelayTime);
    }
  } catch (err) {
    const error: Error = err as Error;
    hilog.warn(0x0000, QR_LOG_TAG, 'QQ 扫码挂起申请失败: %{public}s', error.message ?? '');
  }
}

function endSuspendDelay(pending: PendingQrLogin): void {
  if (pending.suspendRequestId <= 0) return;
  try {
    backgroundTaskManager.cancelSuspendDelay(pending.suspendRequestId);
  } catch (err) {
    const error: Error = err as Error;
    hilog.warn(0x0000, QR_LOG_TAG, 'QQ 扫码挂起取消失败: %{public}s', error.message ?? '');
  }
  pending.suspendRequestId = 0;
}

function scheduleQrReconnect(qrcodeID: string, pending: PendingQrLogin, serverReference: string): void {
  // 注意：重连（含 checkQrCodeStatus / onConnectionLost 这条路）只把地址原样带下去，
  // 真正的「服务端地址 → 连接目标」判定统一在 connectQrMqtt 里的 resolveQrBrokerEndpoint 做，
  // 所以不要在任何其它地方直接拼 options.endpoint。
  if (pending.cancelled) return;
  if (pending.status !== QrLoginStatus.Waiting && pending.status !== QrLoginStatus.Scanned) return;
  if (pending.reconnectTimer >= 0) return;
  if (pending.reconnectAttempts >= MAX_QR_RECONNECT_ATTEMPTS) {
    pending.status = QrLoginStatus.Failed;
    pending.message = 'QQ 音乐扫码连接不稳定，请刷新二维码重试';
    // 置终态时必须把已排的定时器清掉，否则它会用已删除的 pending 再重连一轮（僵尸重连）
    if (pending.reconnectTimer >= 0) {
      clearTimeout(pending.reconnectTimer);
      pending.reconnectTimer = -1;
    }
    endSuspendDelay(pending);
    return;
  }
  pending.reconnectAttempts++;
  const delay: number = Math.min(1000 * Math.pow(2, pending.reconnectAttempts - 1), 15000);
  pending.reconnectTimer = setTimeout(() => {
    pending.reconnectTimer = -1;
    void reconnectQrMqtt(qrcodeID, pending, serverReference);
  }, delay);
  hilog.info(0x0000, QR_LOG_TAG, 'QQ 扫码连接断开，%{public}d ms 后重连（第 %{public}d 次，沿用 %{public}s）',
    delay, pending.reconnectAttempts, serverReference.length > 0 ? limitLogValue(serverReference) : QR_DEFAULT_ENDPOINT);
}

async function reconnectQrMqtt(qrcodeID: string, pending: PendingQrLogin, serverReference: string): Promise<void> {
  if (pending.cancelled) return;
  if (pending.status !== QrLoginStatus.Waiting && pending.status !== QrLoginStatus.Scanned) return;
  try {
    await connectQrMqtt(qrcodeID, pending, serverReference, 0);
    pending.connected = true;
  } catch (err) {
    const error: Error = err as Error;
    hilog.warn(0x0000, QR_LOG_TAG, 'QQ 扫码重连失败: %{public}s', error.message ?? '');
    scheduleQrReconnect(qrcodeID, pending, serverReference);
  }
}

function bindQrMqttEvents(client: MqttClient, pending: PendingQrLogin, generation: number, onConnectionLost: () => void): void {
  client.onPublish = (message: MqttPublishMessage) => {
    if (pending.cancelled || generation !== pending.generation) {
      return;
    }
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
    if (pending.cancelled || generation !== pending.generation) {
      return;
    }
    if (pending.status === QrLoginStatus.Waiting || pending.status === QrLoginStatus.Scanned) {
      pending.connected = false;
      onConnectionLost();
    }
  };
  client.onClose = () => {
    if (pending.cancelled || generation !== pending.generation) {
      return;
    }
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

/** 一次「服务端给的地址 → 实际连接目标」的判定结果（只用于日志与拒绝判断）。 */
class QrEndpointDecision {
  endpoint: string = QR_DEFAULT_ENDPOINT;
  trusted: boolean = true;
  source: string = 'default';
  raw: string = '';
  reason: string = '';
}

function limitLogValue(value: string): string {
  if (value.length <= QR_LOG_VALUE_LIMIT) return value;
  return `${value.substring(0, QR_LOG_VALUE_LIMIT)}...(+${value.length - QR_LOG_VALUE_LIMIT})`;
}

function isTrustedQrHost(host: string): boolean {
  const normalized: string = host.toLowerCase().replace(/\.$/, '');
  for (const domain of QR_TRUSTED_DOMAINS) {
    if (normalized === domain || normalized.endsWith(`.${domain}`)) return true;
  }
  return false;
}

/**
 * 明显不可能是一个可用 broker 的目标：本机 / 回环 / 链路本地 / 内网段 / 内网名。
 * 公网 IP 是**允许**的 —— MQTT 5 规范给出的 Server Reference 示例里就有 IP。
 */
function isUnroutableHost(host: string): boolean {
  if (host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.local') ||
    host.endsWith('.internal') || host.endsWith('.lan')) {
    return true;
  }
  const v4: RegExpMatchArray | null = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (v4 !== null) {
    const a: number = Number(v4[1]);
    const b: number = Number(v4[2]);
    if (a === 0 || a === 10 || a === 127 || a === 169 && b === 254) {
      return true;
    }
    if (a === 172 && b >= 16 && b <= 31) {
      return true;
    }
    if (a === 192 && b === 168) {
      return true;
    }
  }
  const lower: string = host.toLowerCase();
  return lower === '::1' || lower.startsWith('fe80:') || lower.startsWith('fc') || lower.startsWith('fd');
}

function rejectQrEndpoint(decision: QrEndpointDecision, reason: string): QrEndpointDecision {
  decision.trusted = false;
  decision.source = 'rejected';
  decision.endpoint = QR_DEFAULT_ENDPOINT;
  decision.reason = reason;
  return decision;
}

/**
 * 把服务端给的 Server Reference 归一成一次合法的 wss 连接目标。
 *
 * 只有「明显不可能是一个 broker」的目标才会返回 `trusted = false`（调用方据此忽略并回官方入口）；
 * 其余情况一律照服务端说的地址连（MQTT 5 的服务端重定向语义），host 是否为官方域名只影响日志措辞。
 */
function resolveQrBrokerEndpoint(rawReference: string): QrEndpointDecision {
  const decision: QrEndpointDecision = new QrEndpointDecision();
  decision.raw = limitLogValue(rawReference);
  let value: string = rawReference.trim();
  if (value.length === 0) {
    decision.source = 'default';
    decision.reason = '服务端未给出地址，使用官方默认入口';
    return decision;
  }
  if (value.indexOf('%') >= 0) {
    // 有的实现会把地址整体 URL 编码后再塞进来；只解一层，解码结果仍要过下面的全部校验
    try {
      const decoded: string = decodeURIComponent(value).trim();
      if (decoded.length > 0) value = decoded;
    } catch (err) {
      const decodeError: Error = err as Error;
      hilog.warn(0x0000, QR_LOG_TAG, 'QQ 扫码：serverReference 解码失败（%{public}s），按原样校验',
        decodeError.message ?? '');
    }
  }
  // MQTT 5 允许「空格分隔的多个候选」，取第一个可用候选（逗号一并兼容）
  const candidates: string[] = value.split(/[\s,]+/);
  let token: string = '';
  for (const candidate of candidates) {
    if (candidate.length > 0) {
      token = candidate;
      break;
    }
  }
  if (token.length === 0 || token.length > 256) {
    return rejectQrEndpoint(decision, '地址为空或长度异常');
  }
  if ((token.startsWith('"') && token.endsWith('"')) || (token.startsWith("'") && token.endsWith("'"))) {
    token = token.substring(1, token.length - 1);
  }
  if (token.indexOf('@') >= 0 || token.indexOf('\\') >= 0) {
    return rejectQrEndpoint(decision, '地址含 userinfo 或反斜杠（authority 混淆）');
  }
  let rest: string = token;
  const schemeEnd: number = token.indexOf('://');
  if (schemeEnd > 0) {
    const scheme: string = token.substring(0, schemeEnd).toLowerCase();
    if (scheme !== 'wss' && scheme !== 'ws' && scheme !== 'https' && scheme !== 'http') {
      return rejectQrEndpoint(decision, `不支持的协议 ${scheme}`);
    }
    rest = token.substring(schemeEnd + 3);
  }
  // 没有 `://` 的一律按「authority[/path]」解析：host[:port]、host:port/path、node1 都走这条。
  // 形如 javascript:alert(1)、ftp:y.qq.com:21 这种会被下面的端口/内网校验挡掉。
  let authority: string = rest;
  let path: string = '';
  const slashIndex: number = rest.indexOf('/');
  if (slashIndex >= 0) {
    authority = rest.substring(0, slashIndex);
    path = rest.substring(slashIndex);
  }
  if (authority.length === 0) {
    return rejectQrEndpoint(decision, '地址缺少 host');
  }
  let host: string = authority;
  let port: string = '';
  if (authority.startsWith('[')) {
    const closeIndex: number = authority.indexOf(']');
    if (closeIndex < 0) {
      return rejectQrEndpoint(decision, '方括号地址不完整');
    }
    host = authority.substring(1, closeIndex);
    const tail: string = authority.substring(closeIndex + 1);
    if (tail.startsWith(':')) {
      port = tail.substring(1);
    } else if (tail.length > 0) {
      return rejectQrEndpoint(decision, '方括号地址后缀非法');
    }
  } else if (authority.indexOf(':') >= 0) {
    const separator: number = authority.lastIndexOf(':');
    host = authority.substring(0, separator);
    port = authority.substring(separator + 1);
  }
  const lowerHost: string = host.toLowerCase().replace(/\.$/, '');
  if (lowerHost.length === 0) {
    return rejectQrEndpoint(decision, '地址缺少 host');
  }
  if (isUnroutableHost(lowerHost)) {
    return rejectQrEndpoint(decision, '目标是本机/回环/链路本地/内网段，不可能是可用的 broker');
  }
  if (port.length > 0 && (!/^\d{1,5}$/.test(port) || Number(port) <= 0 || Number(port) > 65535)) {
    return rejectQrEndpoint(decision, `端口非法（${port}）`);
  }
  const portValue: string = port.length > 0 ? port : QR_BROKER_PORT;
  const pathValue: string = path.length > 1 ? path : QR_BROKER_PATH;
  if (isTrustedQrHost(lowerHost)) {
    decision.trusted = true;
    decision.source = 'reference-host';
    decision.endpoint = `wss://${lowerHost}:${portValue}${pathValue}`;
    decision.reason = '服务端给出的官方域名（协议统一按 wss 连接）';
    return decision;
  }
  // 单标签节点名（不是域名形态）：拼到官方入口的握手路径上，host 仍是 mu.y.qq.com
  if (port.length === 0 && path.length === 0 && /^[A-Za-z0-9_-]+$/.test(lowerHost)) {
    decision.trusted = true;
    decision.source = 'reference-path';
    decision.endpoint = `wss://${QR_BROKER_HOST}:${QR_BROKER_PORT}${QR_BROKER_PATH}/${lowerHost}`;
    decision.reason = '服务端给的是节点名而非域名，拼到官方入口的握手路径上（host 仍为官方）';
    return decision;
  }
  // ★ 非官方域名 / 公网 IP：先看这个地址**我们的 WebSocket 传输能不能用**。
  //
  //   本机实测（tools/qq-qr-probe*.mjs，2026-10-01）：
  //     官方入口 wss://mu.y.qq.com:443/ws/handshake 现在大概率回 CONNACK 157（0x9D 服务端已迁移），
  //     Server Reference 形如 `11.168.22.98:29001` —— 那是**原生 MQTT/TCP 的节点端口**，
  //     拿 wss 去连它只会超时/失败（真机上表现为「连接扫码服务失败：」）。
  //     官方入口本身是概率可用的（采样 2/12 ≈ 17%）。
  //   ⇒ 这类「原生端口」的 reference 对 WebSocket 客户端没有意义：**忽略它、重新连官方入口**
  //     （调用方会重试若干次，撞上一个不迁移的网关即可成功）。
  //   只有看着就像 WebSocket 端点（443/8443，或没写端口）的 reference 才照用。
  const wsUsablePort: boolean = port.length === 0 || port === '443' || port === '8443';
  if (!wsUsablePort) {
    return rejectQrEndpoint(decision,
      `服务端把连接迁移到原生 TCP 节点 ${lowerHost}:${portValue}，WebSocket 传输用不了这个地址`);
  }
  decision.trusted = true;
  decision.source = 'reference-honored';
  decision.endpoint = `wss://${lowerHost}:${portValue}${pathValue}`;
  decision.reason = '服务端重定向给出的地址（不在官方域名族内，但看着像 WebSocket 端点，按服务端指示连接）';
  return decision;
}

async function connectQrMqtt(qrcodeID: string, pending: PendingQrLogin, serverReference: string, redirectCount: number): Promise<void> {
  const options: MqttClientOptions = new MqttClientOptions();
  // 空的 serverReference 也显式落回官方默认入口（不再依赖 MqttClientOptions 的隐式默认值）
  const endpointDecision: QrEndpointDecision = resolveQrBrokerEndpoint(serverReference);
  hilog.info(0x0000, QR_LOG_TAG,
    'QQ 扫码 MQTT 入口 raw=%{public}s -> endpoint=%{public}s source=%{public}s trusted=%{public}d note=%{public}s',
    endpointDecision.raw.length > 0 ? endpointDecision.raw : '(empty)', endpointDecision.endpoint,
    endpointDecision.source, endpointDecision.trusted ? 1 : 0, endpointDecision.reason);
  if (!endpointDecision.trusted) {
    // ★ 不能因为服务端给了一个「不认识的地址」就让扫码直接失败（旧实现就是这么炸的：
    //   「扫码服务返回不受信任的连接地址」，而且时好时坏 —— 因为服务端有时给、有时不给）。
    //   MQTT 5 明确允许客户端**忽略** Server Reference；忽略之后回到我们自己的官方入口
    //   `wss://mu.y.qq.com:443/ws/handshake`，票据只会发往官方域名，安全性不变。
    hilog.error(0x0000, QR_LOG_TAG,
      'QQ 扫码忽略不受信任的 serverReference actual=%{public}s reason=%{public}s -> 改用官方入口 endpoint=%{public}s',
      endpointDecision.raw, endpointDecision.reason, QR_DEFAULT_ENDPOINT);
    endpointDecision.endpoint = QR_DEFAULT_ENDPOINT;
    endpointDecision.source = 'official-fallback';
  }
  options.endpoint = endpointDecision.endpoint;
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
  if (pending.reconnectTimer >= 0) {
    clearTimeout(pending.reconnectTimer);
    pending.reconnectTimer = -1;
  }
  pending.generation++;
  pending.client?.close();
  pending.connected = false;
  const myGeneration: number = pending.generation;
  const client: MqttClient = new MqttClient();
  pending.client = client;
  let currentReference: string = serverReference;
  client.onConnack = (info: MqttConnackInfo) => {
    if (pending.cancelled || myGeneration !== pending.generation) {
      client.close();
      return;
    }
    pending.connected = true;
    if (info.serverReference.length > 0) {
      const connackReference: QrEndpointDecision = resolveQrBrokerEndpoint(info.serverReference);
      hilog.info(0x0000, QR_LOG_TAG,
        'QQ 扫码 CONNACK 带 serverReference=%{public}s trusted=%{public}d source=%{public}s note=%{public}s',
        connackReference.raw, connackReference.trusted ? 1 : 0, connackReference.source, connackReference.reason);
      // 只有能落到官方域上的地址才拿去做后续重连，免得一次不可用的 CONNACK
      // 让之后每一次重连都撞在校验上（旧实现无条件采纳）
      if (connackReference.trusted) {
        currentReference = info.serverReference;
      } else {
        hilog.warn(0x0000, QR_LOG_TAG, 'QQ 扫码忽略该 serverReference（重连沿用 %{public}s）',
          currentReference.length > 0 ? limitLogValue(currentReference) : QR_DEFAULT_ENDPOINT);
      }
    }
    pending.serverReference = currentReference;
    hilog.info(0x0000, QR_LOG_TAG, 'QQ 扫码 MQTT 已连接 endpoint=%{public}s，订阅 management.qrcode_login/%{private}s',
      endpointDecision.endpoint, qrcodeID);
    client.subscribe(`management.qrcode_login/${qrcodeID}`, new Map([
      ['authorization', 'tmelogin'],
      ['pubsub', 'unicast'],
    ]));
  };
  // SUBACK 非成功：订阅被拒时扫码事件永远不会到达，必须立刻给出可诊断的失败，
  // 而不是让 UI 一直停在"等待扫码"（旧实现把 SUBACK 整体丢弃）。
  client.onSuback = (reasonCode: number) => {
    if (reasonCode < 0x80) {
      return;
    }
    hilog.error(0x0000, QR_LOG_TAG, 'QQ 扫码订阅被拒 reason=%{public}d', reasonCode);
    pending.status = QrLoginStatus.Failed;
    pending.message = `QQ 音乐扫码订阅失败（reason ${reasonCode}）`;
    if (pending.reconnectTimer >= 0) {
      clearTimeout(pending.reconnectTimer);
      pending.reconnectTimer = -1;
    }
    endSuspendDelay(pending);
    if (myGeneration === pending.generation) {
      client.close();
    }
  };
  // CONNACK 拒绝码：把服务端拒绝原因直接暴露出来
  client.onConnectError = (reasonCode: number) => {
    hilog.error(0x0000, QR_LOG_TAG, 'QQ 扫码连接被拒 reason=%{public}d', reasonCode);
  };
  const onConnectionLost: () => void = () => {
    if (myGeneration !== pending.generation) return;
    scheduleQrReconnect(qrcodeID, pending, currentReference);
  };
  bindQrMqttEvents(client, pending, myGeneration, onConnectionLost);
  try {
    await client.connect(options);
    pending.connected = true;
  } catch (err) {
    const connectError: MqttConnectError = err as MqttConnectError;
    const code: number = connectError?.code ?? 0;
    const serverRedirect: string = connectError?.serverReference ?? '';
    // 服务端在 CONNACK 拒绝里给的地址同样要过 resolveQrBrokerEndpoint：
    // 只有判定可信（落到官方域名族）才记进 currentReference，
    // 这样 currentReference / pending.serverReference 里永远不会存下不可信的地址。
    let redirectReference: string = '';
    if (serverRedirect.length > 0) {
      const redirectDecision: QrEndpointDecision = resolveQrBrokerEndpoint(serverRedirect);
      hilog.warn(0x0000, QR_LOG_TAG,
        'QQ 扫码 CONNACK 拒绝（reason=%{public}d）带 serverReference=%{public}s trusted=%{public}d source=%{public}s note=%{public}s',
        code, redirectDecision.raw, redirectDecision.trusted ? 1 : 0, redirectDecision.source, redirectDecision.reason);
      if (redirectDecision.trusted) {
        redirectReference = serverRedirect;
      } else {
        hilog.error(0x0000, QR_LOG_TAG,
          'QQ 扫码拒绝按该地址重定向 actual=%{public}s expected=官方域名族[%{public}s] 或官方入口[%{public}s] reason=%{public}s',
          redirectDecision.raw, QR_TRUSTED_DOMAINS.join('/'), QR_DEFAULT_ENDPOINT, redirectDecision.reason);
      }
    }
    if (code === 156 || code === 157) {
      // 0x9C/0x9D = MQTT 5 的「改用别的服务端 / 服务端已迁移」。
      //
      // 本机实测：官方 WS 网关**概率性**迁移（157 约 83%、直接接受约 17%），
      // 而它给的地址是原生 TCP 节点（IP:29001），WebSocket 客户端用不了。
      // ⇒ 策略就是「忽略这个地址、重连官方入口」，多试几次撞上不迁移的网关即可。
      if (redirectReference.length > 0 && redirectCount < QR_MAX_REDIRECTS) {
        hilog.info(0x0000, QR_LOG_TAG, 'QQ 扫码按服务端重定向重连（第 %{public}d 次，reason=%{public}d）',
          redirectCount + 1, code);
        await connectQrMqtt(qrcodeID, pending, redirectReference, redirectCount + 1);
        return;
      }
      if (redirectCount < QR_MAX_REDIRECTS) {
        // 无参考地址 / 参考地址我们的传输用不了：间隔一下再敲一次官方入口
        hilog.warn(0x0000, QR_LOG_TAG,
          'QQ 扫码第 %{public}d 次被要求迁移（reason=%{public}d，ref=%{public}s），忽略并重试官方入口',
          redirectCount + 1, code, serverRedirect.length > 0 ? limitLogValue(serverRedirect) : '(empty)');
        await new Promise<void>((resolve) => { setTimeout(resolve, QR_REDIRECT_DELAY_MS); });
        if (pending.cancelled || pending.status === QrLoginStatus.Failed) {
          return;
        }
        await connectQrMqtt(qrcodeID, pending, '', redirectCount + 1);
        return;
      }
    }
    hilog.error(0x0000, QR_LOG_TAG, 'QQ 扫码 MQTT 建连失败 endpoint=%{public}s code=%{public}d message=%{public}s',
      endpointDecision.endpoint, code, connectError.message ?? '');
    if (code === 156 || code === 157) {
      // 重试用完了还在迁移：给用户一句能看懂的话（细节都在日志里）
      throw new Error('扫码服务暂时不可用，请稍后重试');
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
    // cookie 登录必须真校验一次：旧实现把 getUserPlaylists 的异常整个吞掉，
    // 于是随便粘贴一段乱码也会「登录成功」并以「QQ用户 <uin>」落库，之后平台音乐页
    // 什么都拉不到，用户看到的是「登录了但不能用」。网易云/酷狗都会 throw，这里对齐。
    try {
      const playlists: PlaylistInfo[] = await this.getUserPlaylists(result.session);
      if (playlists.length > 0) {
        const nick: string = result.session.tokens.get('nickname') ?? '';
        if (nick.length > 0) {
          result.account.nickname = nick;
        }
      }
    } catch (err) {
      const error: Error = err as Error;
      const message: string = error.message ?? '';
      hilog.error(0x0000, LOG_TAG, 'QQ cookie 登录校验失败: %{public}s', message);
      // musicu 返回了业务错误码 => 凭证无效；网络层异常则放行（登录态可能仍然可用）
      if (message.indexOf('code ') >= 0 || message.indexOf('登录失效') >= 0) {
        throw new Error(`QQ 音乐登录失败：${message || '登录凭证无效'}`);
      }
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
    // 上游偶尔返回 JPEG（微信通道）或用首字母大写的字段名；旧实现写死
    // 'data:image/png;base64,' 前缀 + 精确字段名，遇到这两种情况直接抛错，
    // 表现就是"二维码都出不来"。
    const qrcodeID: string = String(data['qrcodeID'] ?? data['QrcodeID'] ?? '');
    const qrUrl: string = String(data['qrcode'] ?? data['Qrcode'] ?? '');
    if (qrcodeID.length === 0 || !/^data:image\//.test(qrUrl)) {
      hilog.error(0x0000, QR_LOG_TAG, 'CreateQRCode 响应异常 keys=[%{public}s] qrPrefix=%{public}s',
        Object.keys(data).join(','), qrUrl.substring(0, 32));
      throw new Error('获取 QQ 音乐二维码失败');
    }
    hilog.info(0x0000, QR_LOG_TAG, 'CreateQRCode 成功 keys=[%{public}s] expiresIn=%{public}s qrPrefix=%{public}s',
      Object.keys(data).join(','), String(data['expiresIn'] ?? ''), qrUrl.substring(0, 24));
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
      // 先置终态再 close：close 会同步触发 onClose → onConnectionLost → scheduleQrReconnect，
      // 而 scheduleQrReconnect 只对 Waiting/Scanned 排重连。旧实现 close 时状态还是 Waiting，
      // 于是排出一个定时器，而 map 里的项已被删除，这段重连再也没人能取消（僵尸重连）。
      pending.status = QrLoginStatus.Expired;
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
