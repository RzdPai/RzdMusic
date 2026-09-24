/*
 * 华为云空间（华为云盘）直存：把设置 + 歌单存进用户自己的华为云盘。
 *
 * 不走 WebDAV 网关 —— 直接照 RzdPai/Huawei_Cloud_Webdav 里那套接口调：
 *   OAuth：POST https://oauth-login.cloud.huawei.com/oauth2/v3/token
 *          （authorization_code / refresh_token 两种 grant）
 *   云盘：https://driveapis.cloud.huawei.com.cn
 *          GET    /drive/v1/files?queryParam='<folderId>' in parentFolder&fields=*
 *          POST   /drive/v1/files?fields=*            （建目录）
 *          DELETE /drive/v1/files/<fileId>
 *          POST   /upload/drive/v1/files?uploadType=resume   （取上传地址，响应头 location）
 *          PUT    <location>  Content-Range: bytes a-b/total （分片上传）
 *          GET    /drive/v1/files/<fileId>?form=content      （下载）
 *
 * 凭据用的是那个仓库里公开的 OAuth 客户端（client_id / secret / redirect_uri），
 * 所以**不需要你先在 AGC 里给本应用额外配置**（前提是同一个开发者账号下的这个
 * OAuth 客户端仍然有效）。
 *
 * ⚠️ 前提：先拿到授权码。授权码来自华为账号登录（Account Kit 的
 *    `authorizationCode`）。Account Kit 那条路要在 AGC 里给应用登记签名证书指纹、
 *    开通华为账号并申请 profile 权限，否则会报「Invalid clientId or profile」。
 */

import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Logger, MusicStoreService } from 'musicbasic';

const DOMAIN: number = 0x0000;
const TAG: string = 'RzdHuaweiDrive';

// ---- OAuth 客户端（取自 RzdPai/Huawei_Cloud_Webdav） ----
const CLIENT_ID: string = '117755925';
const CLIENT_SECRET: string = 'ba95fc3b100404e22043431a7fca19ea916fe38597f121bfa7908f02ffe1199a';
const REDIRECT_URI: string = 'https://webdav.rzdpai.com';
const TOKEN_URL: string = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';

// ---- 云盘 API ----
const API_BASE: string = 'https://driveapis.cloud.huawei.com.cn';
const FOLDER_MIME: string = 'application/vnd.huawei-apps.folder';
/** 云盘分片上限 5MB（照仓库里的 MAX_UPLOAD_SIZE）。 */
const UPLOAD_CHUNK: number = 5 * 1024 * 1024;
/** 备份目录与文件名。 */
const BACKUP_FOLDER: string = 'RzdMusic';
const BACKUP_FILE: string = 'rzdmusic-backup.json';
/** 备份格式版本。 */
const SNAPSHOT_VERSION: number = 1;

const TIMEOUT_MS: number = 20000;

/** 云盘令牌（存 preferences 的 JSON）。 */
interface DriveToken {
  accessToken: string;
  refreshToken: string;
  /** 过期时刻（ms）。 */
  expiresAt: number;
  /** OAuth 返回的 id_token（JWT）：头像昵称等资料从这里解，兼容性比 /about 好。 */
  idToken: string;
}

interface DriveFile {
  id: string;
  fileName: string;
  mimeType: string;
  size: number;
  editedTime: string;
}

interface DriveFileList {
  files?: DriveFile[];
  nextCursor?: string;
}

/** 备份快照里的一项设置。 */
interface SnapshotSetting {
  key: string;
  value: Object;
}

/** 华为账号资料（从云盘 OpenAPI 取）。 */
export interface HuaweiDriveUser {
  uid: string;
  displayName: string;
  avatarUri: string;
}

/** 备份快照。 */
interface CloudSnapshot {
  version: number;
  exportedAt: number;
  settings: SnapshotSetting[];
  playlists: string;
}

function asRecord(value: Object | undefined): Record<string, Object> {
  if (value === undefined || value === null || typeof value !== 'object') {
    return {};
  }
  return value as Record<string, Object>;
}

function asString(value: Object | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  return typeof value === 'string' ? value : String(value);
}

function formEncode(pairs: string[]): string {
  return pairs.join('&');
}

export class HuaweiCloudSync {
  private static instance: HuaweiCloudSync | undefined = undefined;

  public static getInstance(): HuaweiCloudSync {
    if (HuaweiCloudSync.instance === undefined) {
      HuaweiCloudSync.instance = new HuaweiCloudSync();
    }
    return HuaweiCloudSync.instance;
  }

  // ---------------------------------------------------------------- 令牌

  private readToken(): DriveToken | undefined {
    const json: string = MusicStoreService.getInstance().getHuaweiDriveToken();
    if (json.length === 0) {
      return undefined;
    }
    try {
      const token: DriveToken = JSON.parse(json) as DriveToken;
      if (token.accessToken.length === 0) {
        return undefined;
      }
      return token;
    } catch (_err) {
      return undefined;
    }
  }

  private saveToken(token: DriveToken): void {
    MusicStoreService.getInstance().setHuaweiDriveToken(JSON.stringify(token));
  }

  /** 有没有可用的云盘授权（授权码换过令牌就算有）。 */
  public linked(): boolean {
    return this.readToken() !== undefined;
  }

  /**
   * 拉一下华为账号资料（头像 / 昵称）。
   *
   * 两条来源，哪条有值用哪条：
   *   1. **OAuth 的 id_token**（JWT，`openid`+`profile` scope 下会返回）：
   *      里面的 `display_name` / `nickname` / `picture` 就是昵称头像 —— 这条最稳，
   *      因为不依赖云盘 `/about` 的返回结构；
   *   2. 云盘 `GET /drive/v1/about?fields=*`：字段名各版本不一样，按常见名字兜底取。
   *
   * 两条都没给头像的话，界面就用内置的人形占位图标（不会空白）。
   */
  public async fetchUserInfo(): Promise<HuaweiDriveUser | undefined> {
    const fromToken: HuaweiDriveUser | undefined = this.userFromIdToken();
    const fromDrive: HuaweiDriveUser | undefined = await this.userFromDriveAbout();
    if (fromToken === undefined && fromDrive === undefined) {
      return undefined;
    }
    const name: string = HuaweiCloudSync.pick(fromToken?.displayName, fromDrive?.displayName);
    const avatar: string = HuaweiCloudSync.pick(fromToken?.avatarUri, fromDrive?.avatarUri);
    const uid: string = HuaweiCloudSync.pick(fromToken?.uid, fromDrive?.uid);
    hilog.info(DOMAIN, TAG, 'user info name=%{public}d avatar=%{public}d',
      name.length > 0 ? 1 : 0, avatar.length > 0 ? 1 : 0);
    return { uid: uid, displayName: name, avatarUri: avatar };
  }

  /** 两个候选值里取第一个非空的。 */
  private static pick(first: string | undefined, second: string | undefined): string {
    if (first !== undefined && first.length > 0) {
      return first;
    }
    return second !== undefined ? second : '';
  }

  /** 从 id_token（JWT）里解出昵称 / 头像。 */
  private userFromIdToken(): HuaweiDriveUser | undefined {
    const token: DriveToken | undefined = this.readToken();
    if (token === undefined || token.idToken.length === 0) {
      return undefined;
    }
    const claims: Record<string, Object> = HuaweiCloudSync.decodeJwtPayload(token.idToken);
    if (Object.keys(claims).length === 0) {
      return undefined;
    }
    const user: HuaweiDriveUser = {
      uid: asString(claims['sub'] ?? claims['openid'] ?? claims['unionid']),
      displayName: asString(claims['display_name'] ?? claims['nickname'] ?? claims['name']),
      avatarUri: asString(claims['picture'] ?? claims['head_picture_url'] ?? claims['avatar'])
    };
    return user;
  }

  /** 解 JWT 的 payload（base64url，不校验签名 —— 我们只是读自己的资料）。 */
  private static decodeJwtPayload(jwt: string): Record<string, Object> {
    const parts: string[] = jwt.split('.');
    if (parts.length < 2) {
      return {};
    }
    let payload: string = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    while (payload.length % 4 !== 0) {
      payload += '=';
    }
    try {
      const bytes: Uint8Array = new util.Base64Helper().decodeSync(payload);
      const text: string = util.TextDecoder.create('utf-8').decodeToString(bytes);
      return JSON.parse(text) as Record<string, Object>;
    } catch (err) {
      const e: Error = err as Error;
      hilog.warn(DOMAIN, TAG, 'decode id_token failed: %{public}s', e.message ?? '');
      return {};
    }
  }

  /** 云盘 `/drive/v1/about` 里的用户信息（字段名兜底 + 原样打日志便于排查）。 */
  private async userFromDriveAbout(): Promise<HuaweiDriveUser | undefined> {
    try {
      await this.ensureAccessToken();
      const resp: http.HttpResponse = await this.api(http.RequestMethod.GET, '/drive/v1/about?fields=*',
        undefined, undefined);
      const text: string = typeof resp.result === 'string' ? resp.result as string : '';
      if (resp.responseCode !== 200 || text.length === 0) {
        return undefined;
      }
      // 打前 400 个字：万一字段名又不对，日志里能直接看到真实结构
      hilog.info(DOMAIN, TAG, 'about body: %{public}s', text.substring(0, Math.min(400, text.length)));
      const body: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const raw: Record<string, Object> = asRecord(body['user'] ?? body['userInfo'] ?? body);
      const user: HuaweiDriveUser = {
        uid: asString(raw['uid'] ?? raw['openId'] ?? raw['openID']),
        displayName: asString(raw['displayName'] ?? raw['nickName'] ?? raw['nickname'] ?? raw['name']),
        avatarUri: asString(raw['avatarUri'] ?? raw['picture'] ?? raw['headPicture']
          ?? raw['headPictureUrl'] ?? raw['avatar'])
      };
      return user;
    } catch (err) {
      const e: Error = err as Error;
      hilog.warn(DOMAIN, TAG, 'fetch user info failed: %{public}s', e.message ?? '');
      return undefined;
    }
  }

  /**
   * 用华为账号登录拿到的授权码换取云盘令牌（登录成功后调用一次）。
   * @param code Account Kit 返回的 `authorizationCode`。
   * @returns 给用户看的文案。
   */
  public async linkWithCode(code: string): Promise<string> {
    if (code.length === 0) {
      return '没有授权码，无法开通云盘';
    }
    const body: string = formEncode([
      'grant_type=authorization_code',
      `code=${encodeURIComponent(code)}`,
      `client_id=${CLIENT_ID}`,
      `client_secret=${CLIENT_SECRET}`,
      `redirect_uri=${encodeURIComponent(REDIRECT_URI)}`
    ]);
    try {
      const resp: Record<string, Object> = await this.postForm(TOKEN_URL, body);
      const accessToken: string = asString(resp['access_token']);
      if (accessToken.length === 0) {
        return '云盘授权失败：' + asString(resp['error_description'] ?? resp['error']);
      }
      const expiresIn: number = Number(resp['expires_in'] ?? 3600);
      this.saveToken({
        accessToken: accessToken,
        refreshToken: asString(resp['refresh_token']),
        expiresAt: Date.now() + Math.max(60, expiresIn - 120) * 1000,
        idToken: asString(resp['id_token'])
      });
      hilog.info(DOMAIN, TAG, 'huawei drive token linked, idToken=%{public}d',
        asString(resp['id_token']).length > 0 ? 1 : 0);
      return '华为云盘已连接（备份目录：' + BACKUP_FOLDER + '/' + BACKUP_FILE + '）';
    } catch (err) {
      const e: Error = err as Error;
      hilog.warn(DOMAIN, TAG, 'drive link failed: %{public}s', e.message ?? '');
      return '云盘授权失败：' + (e.message ?? '未知错误');
    }
  }

  /** 取一个未过期的访问令牌（快过期就用 refresh_token 换）。 */
  private async ensureAccessToken(): Promise<string> {
    const token: DriveToken | undefined = this.readToken();
    if (token === undefined) {
      throw new Error('还没有连接华为云盘');
    }
    if (token.expiresAt > Date.now()) {
      return token.accessToken;
    }
    if (token.refreshToken.length === 0) {
      throw new Error('云盘授权已过期，请重新登录');
    }
    const body: string = formEncode([
      'grant_type=refresh_token',
      `refresh_token=${encodeURIComponent(token.refreshToken)}`,
      `client_id=${CLIENT_ID}`,
      `client_secret=${CLIENT_SECRET}`
    ]);
    const resp: Record<string, Object> = await this.postForm(TOKEN_URL, body);
    const accessToken: string = asString(resp['access_token']);
    if (accessToken.length === 0) {
      throw new Error('刷新云盘授权失败');
    }
    const expiresIn: number = Number(resp['expires_in'] ?? 3600);
    const nextRefresh: string = asString(resp['refresh_token']);
    const nextIdToken: string = asString(resp['id_token']);
    this.saveToken({
      accessToken: accessToken,
      refreshToken: nextRefresh.length > 0 ? nextRefresh : token.refreshToken,
      expiresAt: Date.now() + Math.max(60, expiresIn - 120) * 1000,
      idToken: nextIdToken.length > 0 ? nextIdToken : token.idToken
    });
    return accessToken;
  }

  // ---------------------------------------------------------------- HTTP 底座

  private async postForm(url: string, body: string): Promise<Record<string, Object>> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded' },
        extraData: body,
        connectTimeout: TIMEOUT_MS,
        readTimeout: TIMEOUT_MS
      });
      const text: string = typeof resp.result === 'string' ? resp.result as string : '';
      if (text.length === 0) {
        throw new Error(`HTTP ${resp.responseCode}`);
      }
      return JSON.parse(text) as Record<string, Object>;
    } finally {
      request.destroy();
    }
  }

  /** 云盘 API 请求（401 时自动刷新一次令牌）。 */
  private async api(method: http.RequestMethod, path: string, body: string | undefined,
    extraHeaders: Record<string, string> | undefined): Promise<http.HttpResponse> {
    let token: string = await this.ensureAccessToken();
    let resp: http.HttpResponse = await this.apiOnce(token, method, path, body, extraHeaders);
    if (resp.responseCode === 401) {
      // 令牌可能被服务端提前失效：清掉过期时间强制刷新一次
      const cached: DriveToken | undefined = this.readToken();
      if (cached !== undefined) {
        this.saveToken({
          accessToken: cached.accessToken,
          refreshToken: cached.refreshToken,
          expiresAt: 0,
          idToken: cached.idToken
        });
      }
      token = await this.ensureAccessToken();
      resp = await this.apiOnce(token, method, path, body, extraHeaders);
    }
    return resp;
  }

  private async apiOnce(token: string, method: http.RequestMethod, path: string, body: string | undefined,
    extraHeaders: Record<string, string> | undefined): Promise<http.HttpResponse> {
    const request: http.HttpRequest = http.createHttp();
    const header: Record<string, string> = {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/json'
    };
    if (extraHeaders !== undefined) {
      const keys: string[] = Object.keys(extraHeaders);
      for (let i: number = 0; i < keys.length; i++) {
        header[keys[i]] = extraHeaders[keys[i]];
      }
    }
    if (body !== undefined && header['Content-Type'] === undefined) {
      header['Content-Type'] = 'application/json';
    }
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: header,
        connectTimeout: TIMEOUT_MS,
        readTimeout: TIMEOUT_MS,
        expectDataType: http.HttpDataType.STRING
      };
      if (body !== undefined) {
        options.extraData = body;
      }
      return await request.request(API_BASE + path, options);
    } finally {
      request.destroy();
    }
  }

  /** 从响应头里大小写不敏感地取一个头。 */
  private headerOf(resp: http.HttpResponse, name: string): string {
    const headers: Record<string, Object> = asRecord(resp.header as Object);
    const keys: string[] = Object.keys(headers);
    const want: string = name.toLowerCase();
    for (let i: number = 0; i < keys.length; i++) {
      if (keys[i].toLowerCase() === want) {
        return asString(headers[keys[i]]);
      }
    }
    return '';
  }

  // ---------------------------------------------------------------- 云盘操作

  private async listFiles(parentId: string): Promise<DriveFile[]> {
    const query: string = `queryParam=${encodeURIComponent(`'${parentId}' in parentFolder`)}&fields=*&pageSize=200`;
    const resp: http.HttpResponse = await this.api(http.RequestMethod.GET, `/drive/v1/files?${query}`, undefined, undefined);
    const text: string = typeof resp.result === 'string' ? resp.result as string : '';
    if (resp.responseCode !== 200 || text.length === 0) {
      throw new Error(`列目录失败 HTTP ${resp.responseCode}`);
    }
    const parsed: DriveFileList = JSON.parse(text) as DriveFileList;
    return parsed.files !== undefined ? parsed.files : [];
  }

  /** 确保备份目录存在（没有就建），返回其 fileId。 */
  private async ensureBackupFolder(): Promise<string> {
    const rootFiles: DriveFile[] = await this.listFiles('root');
    for (let i: number = 0; i < rootFiles.length; i++) {
      if (rootFiles[i].fileName === BACKUP_FOLDER && rootFiles[i].mimeType === FOLDER_MIME) {
        return rootFiles[i].id;
      }
    }
    const resp: http.HttpResponse = await this.api(http.RequestMethod.POST, '/drive/v1/files?fields=*',
      JSON.stringify({ fileName: BACKUP_FOLDER, mimeType: FOLDER_MIME, parentFolder: ['root'] }), undefined);
    const text: string = typeof resp.result === 'string' ? resp.result as string : '';
    if (resp.responseCode !== 200 || text.length === 0) {
      throw new Error(`创建备份目录失败 HTTP ${resp.responseCode}`);
    }
    const created: DriveFile = JSON.parse(text) as DriveFile;
    return created.id;
  }

  private async findBackupFile(folderId: string): Promise<DriveFile | undefined> {
    const files: DriveFile[] = await this.listFiles(folderId);
    for (let i: number = 0; i < files.length; i++) {
      if (files[i].fileName === BACKUP_FILE) {
        return files[i];
      }
    }
    return undefined;
  }

  private async deleteFile(fileId: string): Promise<void> {
    const resp: http.HttpResponse = await this.api(http.RequestMethod.DELETE, `/drive/v1/files/${fileId}`, undefined, undefined);
    if (resp.responseCode >= 400) {
      Logger.warn(TAG, `delete old backup failed HTTP ${resp.responseCode}`);
    }
  }

  /** 上传一段文本（内容小，按分片循环，实际通常一个分片就完）。 */
  private async uploadText(folderId: string, fileName: string, text: string): Promise<void> {
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(text);
    const total: number = bytes.length;
    const initResp: http.HttpResponse = await this.api(http.RequestMethod.POST, '/upload/drive/v1/files?uploadType=resume',
      JSON.stringify({ fileName: fileName, parentFolder: [folderId] }),
      {
        'X-Upload-Content-Type': 'application/json',
        'X-Upload-Content-Length': String(total)
      });
    const uploadUrl: string = this.headerOf(initResp, 'location');
    if (uploadUrl.length === 0) {
      const body: string = typeof initResp.result === 'string' ? initResp.result as string : '';
      throw new Error(`创建上传会话失败 HTTP ${initResp.responseCode} ${body}`);
    }
    if (total === 0) {
      return;
    }
    let start: number = 0;
    let guard: number = 0;
    while (start < total && guard < 64) {
      guard++;
      const end: number = Math.min(start + UPLOAD_CHUNK, total);
      const chunk: Uint8Array = bytes.slice(start, end);
      const range: string = `bytes ${start}-${end - 1}/${total}`;
      const resp: http.HttpResponse = await this.putChunk(uploadUrl, chunk, range);
      if (resp.responseCode === 200 || resp.responseCode === 201) {
        return;
      }
      if (resp.responseCode === 308) {
        const rangeHeader: string = this.headerOf(resp, 'range');
        const match: RegExpMatchArray | null = rangeHeader.match(/bytes=0-(\d+)/);
        start = match !== null ? Number(match[1]) + 1 : 0;
        if (start === 0) {
          // 服务端没给进度，按已发送量继续（避免死循环）
          start = end;
        }
        continue;
      }
      throw new Error(`分片上传失败 HTTP ${resp.responseCode}`);
    }
  }

  private async putChunk(uploadUrl: string, chunk: Uint8Array, range: string): Promise<http.HttpResponse> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const token: string = await this.ensureAccessToken();
      return await request.request(uploadUrl, {
        method: http.RequestMethod.PUT,
        header: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
          'Content-Length': String(chunk.length),
          'Content-Range': range
        },
        extraData: chunk.buffer as ArrayBuffer,
        connectTimeout: TIMEOUT_MS,
        readTimeout: 60000,
        expectDataType: http.HttpDataType.STRING
      });
    } finally {
      request.destroy();
    }
  }

  private async downloadText(fileId: string): Promise<string> {
    const resp: http.HttpResponse = await this.api(http.RequestMethod.GET,
      `/drive/v1/files/${fileId}?form=content`, undefined, undefined);
    if (resp.responseCode !== 200) {
      throw new Error(`下载备份失败 HTTP ${resp.responseCode}`);
    }
    return typeof resp.result === 'string' ? resp.result as string : '';
  }

  // ---------------------------------------------------------------- 快照

  /** 快照里带上哪些设置（都是 MusicStoreService 现成的 get/set 对）。 */
  private readSettings(): SnapshotSetting[] {
    const store: MusicStoreService = MusicStoreService.getInstance();
    const out: SnapshotSetting[] = [];
    out.push({ key: 'themeColor', value: store.getThemeColor() });
    out.push({ key: 'colorMode', value: store.getColorMode() });
    out.push({ key: 'ambientLevel', value: store.getAmbientLevel() });
    out.push({ key: 'homeSource', value: store.getHomeSource() });
    out.push({ key: 'useAccountRec', value: store.getUseAccountRec() });
    out.push({ key: 'playQuality', value: store.getPlayQuality() });
    out.push({ key: 'playMode', value: store.getPlayMode() });
    out.push({ key: 'lyricBlur', value: store.getLyricBlurEnabled() });
    out.push({ key: 'lyricCenter', value: store.getLyricCenterEnabled() });
    out.push({ key: 'lyricFontSize', value: store.getLyricFontSize() });
    out.push({ key: 'lyricFps', value: store.getLyricFps() });
    out.push({ key: 'showMiniLyric', value: store.getShowMiniLyric() });
    out.push({ key: 'showSubLyric', value: store.getShowSubLyric() });
    out.push({ key: 'desktopLyric', value: store.getDesktopLyric() });
    out.push({ key: 'playbackFlowLight', value: store.getPlaybackFlowLight() });
    out.push({ key: 'keepScreenOn', value: store.getKeepScreenOn() });
    out.push({ key: 'audioMix', value: store.getAudioMix() });
    out.push({ key: 'coverCornerRadius', value: store.getCoverCornerRadius() });
    out.push({ key: 'playlistAddPosition', value: store.getPlaylistAddPosition() });
    out.push({ key: 'downloadSaveMode', value: store.getDownloadSaveMode() });
    out.push({ key: 'downloadNameFormat', value: store.getDownloadNameFormat() });
    out.push({ key: 'downloadLrc', value: store.getDownloadLrc() });
    out.push({ key: 'showHomePlaza', value: store.getShowHomePlaza() });
    out.push({ key: 'showHomeRanking', value: store.getShowHomeRanking() });
    return out;
  }

  /** 把快照里的设置写回去。 */
  private applySettings(settings: SnapshotSetting[]): number {
    const store: MusicStoreService = MusicStoreService.getInstance();
    let applied: number = 0;
    for (let i: number = 0; i < settings.length; i++) {
      const entry: SnapshotSetting = settings[i];
      const value: Object = entry.value;
      switch (entry.key) {
        case 'themeColor':
          store.setThemeColor(asString(value));
          break;
        case 'colorMode':
          store.setColorMode(Number(value));
          break;
        case 'ambientLevel':
          store.setAmbientLevel(Number(value));
          break;
        case 'homeSource':
          store.setHomeSource(asString(value));
          break;
        case 'useAccountRec':
          store.setUseAccountRec(value === true);
          break;
        case 'playQuality':
          store.setPlayQuality(asString(value));
          break;
        case 'playMode':
          store.setPlayMode(Number(value));
          break;
        case 'lyricBlur':
          store.setLyricBlurEnabled(value === true);
          break;
        case 'lyricCenter':
          store.setLyricCenterEnabled(value === true);
          break;
        case 'lyricFontSize':
          store.setLyricFontSize(Number(value));
          break;
        case 'lyricFps':
          store.setLyricFps(Number(value));
          break;
        case 'showMiniLyric':
          store.setShowMiniLyric(value === true);
          break;
        case 'showSubLyric':
          store.setShowSubLyric(value === true);
          break;
        case 'desktopLyric':
          store.setDesktopLyric(value === true);
          break;
        case 'playbackFlowLight':
          store.setPlaybackFlowLight(value === true);
          break;
        case 'keepScreenOn':
          store.setKeepScreenOn(value === true);
          break;
        case 'audioMix':
          store.setAudioMix(value === true);
          break;
        case 'coverCornerRadius':
          store.setCoverCornerRadius(Number(value));
          break;
        case 'playlistAddPosition':
          store.setPlaylistAddPosition(asString(value));
          break;
        case 'downloadSaveMode':
          store.setDownloadSaveMode(asString(value));
          break;
        case 'downloadNameFormat':
          store.setDownloadNameFormat(asString(value));
          break;
        case 'downloadLrc':
          store.setDownloadLrc(value === true);
          break;
        case 'showHomePlaza':
          store.setShowHomePlaza(value === true);
          break;
        case 'showHomeRanking':
          store.setShowHomeRanking(value === true);
          break;
        default:
          continue;
      }
      applied++;
    }
    return applied;
  }

  // ---------------------------------------------------------------- 对外动作

  /** 上传：设置 + 歌单 → 云盘 RzdMusic/rzdmusic-backup.json。 */
  public async uploadSnapshot(): Promise<string> {
    try {
      await this.ensureAccessToken();
      const snapshot: CloudSnapshot = {
        version: SNAPSHOT_VERSION,
        exportedAt: Date.now(),
        settings: this.readSettings(),
        playlists: MusicStoreService.getInstance().playlistsJson()
      };
      const folderId: string = await this.ensureBackupFolder();
      const existing: DriveFile | undefined = await this.findBackupFile(folderId);
      if (existing !== undefined) {
        // 云盘同名上传会产生副本，先删旧的（与网关上那套做法一致）
        await this.deleteFile(existing.id);
      }
      await this.uploadText(folderId, BACKUP_FILE, JSON.stringify(snapshot));
      hilog.info(DOMAIN, TAG, 'snapshot uploaded, settings=%{public}d', snapshot.settings.length);
      // 把落点直接写在提示里：备份在**华为云盘根目录**的 RzdMusic 文件夹下
      return '已备份到云盘：' + BACKUP_FOLDER + '/' + BACKUP_FILE;
    } catch (err) {
      const e: Error = err as Error;
      hilog.warn(DOMAIN, TAG, 'upload snapshot failed: %{public}s', e.message ?? '');
      return '备份失败：' + (e.message ?? '未知错误');
    }
  }

  /** 下载并恢复：设置 + 歌单。 */
  public async downloadSnapshot(): Promise<string> {
    try {
      await this.ensureAccessToken();
      const folderId: string = await this.ensureBackupFolder();
      const file: DriveFile | undefined = await this.findBackupFile(folderId);
      if (file === undefined) {
        return '云盘里还没有备份';
      }
      const text: string = await this.downloadText(file.id);
      if (text.length === 0) {
        return '云盘里的备份是空的';
      }
      const snapshot: CloudSnapshot = JSON.parse(text) as CloudSnapshot;
      const settingsCount: number = this.applySettings(snapshot.settings !== undefined ? snapshot.settings : []);
      const playlistsOk: boolean = MusicStoreService.getInstance()
        .replacePlaylistsJson(snapshot.playlists !== undefined ? snapshot.playlists : '');
      hilog.info(DOMAIN, TAG, 'snapshot applied, settings=%{public}d playlists=%{public}d',
        settingsCount, playlistsOk ? 1 : 0);
      return `已从云盘恢复（${settingsCount} 项设置${playlistsOk ? ' + 歌单' : ''}）`;
    } catch (err) {
      const e: Error = err as Error;
      hilog.warn(DOMAIN, TAG, 'download snapshot failed: %{public}s', e.message ?? '');
      return '恢复失败：' + (e.message ?? '未知错误');
    }
  }
}
