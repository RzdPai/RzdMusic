/*
 * 华为账号登录（系统级 Account Kit）—— 官方「获取头像昵称」接口方式。
 *
 * 文档：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/account-get-avatar-nickname
 * 接口：`HuaweiIDProvider.createAuthorizationWithHuaweiIDRequest()` + `scopes=['profile']`
 *       + `permissions=['serviceauthcode']` + `forceAuthorization=true` + `state=<uuid>`。
 *
 * 关于 forceAuthorization：**必须是 true**。文档说明 forceAuthorization=true 时，
 * 若用户已授权则仍直接返回资料、只有「未登录 / 未授权」才拉起系统页面；设为 false
 * 反而会在未登录时直接抛 1001502001、未授权时抛 1001502002 —— 所以刻意不做
 * 「先 false 静默、失败再 true」那套，直接 true 一次到位。
 *
 * 关于资料范围：只要 `profile`（头像 + 昵称），不申请手机号 / 邮箱，授权面最小；
 * 本场景**无需在 AGC 申请账号权限**。授权码只用于换华为云盘令牌（见 HuaweiCloudSync）。
 *
 * AGC 前置条件（缺一样就会报 1001500001 / 1001502003，且需要用户在 AGC 侧操作）：
 *   1. 签名证书的公钥指纹已登记（本工程用 release 证书手动签名，
 *      指纹 34:C9:3F:82:…:C5:2B，与 .sign/RzdMusicRelease.p7b 里的
 *      distribution-certificate 是同一张证书，可自证一致）；
 *   2. 指纹生效最长 25 小时（可选加速：改一次 AppScope/app.json5 的 versionCode）；
 *   3. 设备的「华为账号」已登录：设置 → 华为账号。
 * 不需要配 client_id：本应用 Client ID 与 APP ID 相同（都是 6917613022580384840），
 * 文档明确「相同则无需配置」（配置错了反而报 1001500001）。
 */

import { authentication } from '@kit.AccountKit';
import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppRuntime, MusicStoreService } from 'musicbasic';
import { PlayerConstants } from '../constant/PlayerConstants';

const DOMAIN: number = 0x0000;
const TAG: string = 'RzdHuaweiId';

/**
 * 「获取头像昵称」所需 scope（官方文档 account-get-avatar-nickname 的客户端开发）。
 *
 * ⚠️ 本应用是**普通应用（HAP）**，不是元服务，所以不要传 `supportAtomicService`
 *   （那个属性只给元服务用；普通应用传了反而可能拿到 1001500003）。
 */
const PROFILE_SCOPE: string = 'profile';

/**
 * 拿 Authorization Code 所需的 permission。
 *
 * 官方文档明确要求：`profile` + `serviceauthcode` **一起传**，
 * 才会在 `AuthorizationWithHuaweiIDCredential` 里同时给出头像昵称和授权码。
 * 授权码我要用去换华为云盘令牌，所以两个都传。
 *
 * 注意：只传 `permissions` 或只传 `scopes` 都可以，但**两个都不传**会报
 * 1001502003 输入参数值无效 —— 用户之前看到的 `Invalid input parameter value.`
 * 有一部分就是这么来的。（元数据 client_id 与 AppID 相同，无需配置，见文档
 * account-client-id：Client ID 与 APP ID 相同时不需要在 module.json5 里配。）
 */
const AUTHCODE_PERMISSION: string = 'serviceauthcode';

/** 头像下载失败之间的最小重试间隔（避免每次启动都去拉一遍失效链接）。 */
const AVATAR_RETRY_MS: number = 6 * 60 * 60 * 1000;
/** 头像在沙箱里的固定文件名（固定名字 = 每次覆盖，避免占满缓存目录）。 */
const AVATAR_FILE: string = 'huawei_avatar.img';

/** Account Kit 常见错误码（见 errorcode-account-kit）。 */
const ERR_FINGERPRINT: number = 1001500001;
const ERR_DUPLICATE: number = 1001500002;
const ERR_UNSUPPORTED: number = 1001500003;
const ERR_NOT_LOGIN: number = 1001502001;
const ERR_NOT_AUTHORIZED: number = 1001502002;
const ERR_INVALID_PARAM: number = 1001502003;
const ERR_NETWORK: number = 1001502005;
const ERR_INTERNAL: number = 1001502009;
const ERR_USER_CANCEL: number = 1001502012;
const ERR_NO_SCOPE: number = 1001502014;
const ERR_SYSTEM: number = 12300001;
const ERR_STATE_MISMATCH: number = -10001;

/** 登录后保存的资料（存 preferences 的就是这个形状的 JSON）。 */
export interface HuaweiAccountProfile {
  openID: string;
  unionID: string;
  nickName: string;
  /** 界面直接用的地址：头像已本地化时是 `file://<bundle>/<沙箱路径>`。 */
  avatarUri: string;
  /**
   * Account Kit 返回的**原始网络头像地址**（服务端下发的那个）。
   *
   * 为什么留一份：`avatarUri` 会被改写成沙箱本地地址，而沙箱缓存目录是**会被系统清理**的；
   * 一旦本地图没了，只有手里还攥着原始地址才能重新下回来 —— 否则头像就永久变占位图了。
   * 老版本存的 JSON 没有这个字段（`undefined`），读取处都做了兜底。
   */
  avatarNetworkUri?: string;
  /** 授权码：可填进华为云盘 WebDAV 网关的管理面板换长期令牌。 */
  authorizationCode: string;
  /** 登录时间（ms）。 */
  loginAt: number;
}

/** 给界面观察的华为账号登录态（V2：@ObservedV2 + @Trace）。 */
@ObservedV2
export class HuaweiAccountState {
  /** 状态版本号：任何变化都 +1，方便界面靠它刷新。 */
  @Trace public version: number = 0;
  @Trace public signedIn: boolean = false;
  @Trace public nickName: string = '';
  @Trace public avatarUri: string = '';
  /** 正在登录（按钮显示 loading / 防重复点击）。 */
  @Trace public loggingIn: boolean = false;
  /** 最近一次失败的文案。 */
  @Trace public lastError: string = '';
}

/**
 * 华为账号相关异常（自己拼的错误码，用于 state 校验失败等本应用内部场景）。
 * 用类而不是对象字面量：ArkTS 不允许把无类型对象字面量当异常抛。
 */
export class HuaweiAuthError extends Error {
  public readonly code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

/**
 * 华为账号登录服务（单例）。
 *
 * 登录态放在 AppStorageV2 里（`PlayerConstants.HUAWEI_ACCOUNT_STATE`），
 * 界面用 `AppStorageV2.connect(HuaweiAccountState, ...)` 观察同一份数据。
 */
export class HuaweiAccountService {
  private static instance: HuaweiAccountService | undefined = undefined;
  private context: common.UIAbilityContext | undefined = undefined;
  private cached: HuaweiAccountProfile | undefined = undefined;

  static getInstance(): HuaweiAccountService {
    if (HuaweiAccountService.instance === undefined) {
      HuaweiAccountService.instance = new HuaweiAccountService();
    }
    return HuaweiAccountService.instance;
  }

  /** 共享登录态（界面观察的是同一个实例）。 */
  public state(): HuaweiAccountState {
    return AppStorageV2.connect(HuaweiAccountState, PlayerConstants.HUAWEI_ACCOUNT_STATE,
      () => new HuaweiAccountState())!;
  }

  /** 记录 UIAbility 上下文（登录需要它拉起系统授权页）。 */
  public init(context: common.UIAbilityContext): void {
    this.context = context;
    this.restore();
  }

  /** 已保存的账号资料（没登录过返回 undefined）。 */
  public profile(): HuaweiAccountProfile | undefined {
    if (this.cached === undefined) {
      this.cached = HuaweiAccountService.parse(MusicStoreService.getInstance().getHuaweiAccount());
    }
    return this.cached;
  }

  /** 从持久化里恢复登录态（进程启动时调一次即可，重复调无副作用）。 */
  public restore(): void {
    const profile: HuaweiAccountProfile | undefined = this.profile();
    const state: HuaweiAccountState = this.state();
    if (profile === undefined) {
      state.signedIn = false;
      state.nickName = '';
      state.avatarUri = '';
      state.version++;
      return;
    }
    state.signedIn = true;
    state.nickName = profile.nickName;
    state.avatarUri = profile.avatarUri;
    state.version++;
    this.ensureLocalAvatar(profile);
  }

  /**
   * 头像链接本地化（后台静默做，不阻塞界面）。
   *
   * 官方注意项：用户换头像后**原头像链接立即失效**，所以登录时就把图下到沙箱、
   * 之后一直读本地文件；只有本地还没有图、或隔了很久仍是网络地址时才重试。
   */
  private refreshAvatarIfStale(profile: HuaweiAccountProfile): void {
    if (profile.avatarUri.length === 0 || profile.avatarUri.startsWith('file://')) {
      return;
    }
    if (Date.now() - profile.loginAt < AVATAR_RETRY_MS) {
      return;
    }
    void this.cacheAvatar(profile.avatarUri);
  }

  /**
   * 本地头像缓存还在不在 + 本地文件丢了时重新下回来。
   *
   * 场景：`cacheDir` 是**会被系统清理**的目录，而 `avatarUri` 已经写成沙箱地址，光靠
   * `refreshAvatarIfStale`（它见 `file://` 就 return）发现不了「图没了」。所以这里显式
   * 用 `fs.accessSync` 探一下；文件不在就拿留存的原始网络地址重下。
   */
  private ensureLocalAvatar(profile: HuaweiAccountProfile): void {
    if (!profile.avatarUri.startsWith('file://')) {
      this.refreshAvatarIfStale(profile);
      return;
    }
    const context: common.UIAbilityContext | undefined = this.effectiveContext();
    if (context === undefined) {
      return;
    }
    if (fs.accessSync(context.cacheDir + '/' + AVATAR_FILE)) {
      return;   // 本地图还在，直接用
    }
    const network: string = this.networkAvatarUrl(profile);
    if (network.length === 0) {
      hilog.warn(DOMAIN, TAG, 'local avatar missing and no network url to restore it');
      return;
    }
    hilog.info(DOMAIN, TAG, 'local avatar cache missing, re-downloading');
    void this.cacheAvatar(network);
  }

  /** 原始网络头像地址：新字段优先，老数据（只有被改写过的本地地址）返回空串。 */
  private networkAvatarUrl(profile: HuaweiAccountProfile): string {
    const saved: string | undefined = profile.avatarNetworkUri;
    if (saved !== undefined && saved.startsWith('http')) {
      return saved;
    }
    if (profile.avatarUri.startsWith('http')) {
      return profile.avatarUri;
    }
    return '';
  }

  /** 当前可用上下文：优先显式 `init()` 传进来的，其次全局 AppRuntime 里的。 */
  private effectiveContext(): common.UIAbilityContext | undefined {
    if (this.context !== undefined) {
      return this.context;
    }
    return getAppRuntime().context;
  }

  /**
   * 登录华为账号。
   *
   * 走官方「获取头像昵称」接口：`scopes=['profile']` + `permissions=['serviceauthcode']`
   * + `forceAuthorization=true` + `state=<uuid>`。
   * @returns 成功与否；失败时 `state().lastError` 里有**可直接展示给用户**的文案。
   */
  public async signIn(): Promise<boolean> {
    const state: HuaweiAccountState = this.state();
    if (state.loggingIn) {
      return false;
    }
    // 兜底：调用方（设置页 / 卡片）不一定走过 init()，这里再从全局运行时补一次上下文
    if (this.context === undefined) {
      const runtime: common.UIAbilityContext | undefined = getAppRuntime().context;
      if (runtime !== undefined) {
        this.context = runtime;
      }
    }
    if (this.effectiveContext() === undefined) {
      state.lastError = '拿不到应用上下文，登录失败';
      state.version++;
      return false;
    }
    state.loggingIn = true;
    state.lastError = '';
    state.version++;
    try {
      const credential: authentication.AuthorizationWithHuaweiIDCredential =
        await this.requestProfile(true);
      const profile: HuaweiAccountProfile = {
        openID: credential.openID ?? '',
        unionID: credential.unionID ?? '',
        nickName: credential.nickName ?? '',
        avatarUri: credential.avatarUri ?? '',
        authorizationCode: credential.authorizationCode ?? '',
        loginAt: Date.now()
      };
      this.cached = profile;
      MusicStoreService.getInstance().setHuaweiAccount(JSON.stringify(profile));
      state.signedIn = true;
      state.nickName = profile.nickName;
      state.avatarUri = profile.avatarUri;
      hilog.info(DOMAIN, TAG,
        'account kit signed in: nick=%{public}s avatar=%{public}s openID=%{public}s authCode=%{public}s',
        profile.nickName, profile.avatarUri.length > 0 ? 'yes' : 'empty',
        profile.openID, profile.authorizationCode.length > 0 ? 'yes' : 'empty');
      // 头像链接随时会失效：先存到沙箱，界面随后换成 file:// 本地路径
      const local: string = await this.cacheAvatar(profile.avatarUri);
      if (local.length > 0) {
        hilog.info(DOMAIN, TAG, 'avatar cached locally: %{public}s', local);
      }
      return true;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      const code: number = error.code ?? 0;
      state.lastError = HuaweiAccountService.describeError(code, error.message ?? '');
      hilog.warn(DOMAIN, TAG, 'account kit sign-in failed: code=%{public}d msg=%{public}s mapped=%{public}s',
        code, error.message ?? '', state.lastError);
      return false;
    } finally {
      state.loggingIn = false;
      state.version++;
    }
  }

  /** 退出登录（只清本地资料；不调系统的取消授权，用户可在系统设置里撤销）。 */
  public signOut(): void {
    this.cached = undefined;
    MusicStoreService.getInstance().setHuaweiAccount('');
    // 云盘令牌是跟着这个账号来的，退出时一起清掉（下次登录会重新换）
    MusicStoreService.getInstance().setHuaweiDriveToken('');
    const state: HuaweiAccountState = this.state();
    state.signedIn = false;
    state.nickName = '';
    state.avatarUri = '';
    state.lastError = '';
    state.version++;
    hilog.info(DOMAIN, TAG, 'huawei id signed out');
  }

  /**
   * 网页授权登录成功后写入登录态（Account Kit 失败时的兜底路径）。
   *
   * 两条路的区别：Account Kit 的资料来自系统账号服务（可信、免跳网页），
   * 但要求 AGC 里签好公钥指纹；网页授权用云盘那套 OAuth 客户端，不依赖 AGC 配置，
   * 资料从 OAuth 的 id_token / 云盘 OpenAPI 取。界面优先走 Account Kit。
   */
  public applyWebProfile(nickName: string, avatarUri: string, openID: string): void {
    const profile: HuaweiAccountProfile = {
      openID: openID,
      unionID: '',
      nickName: nickName,
      avatarUri: avatarUri,
      authorizationCode: '',
      loginAt: Date.now()
    };
    this.cached = profile;
    MusicStoreService.getInstance().setHuaweiAccount(JSON.stringify(profile));
    const state: HuaweiAccountState = this.state();
    state.signedIn = true;
    state.nickName = nickName;
    state.avatarUri = avatarUri;
    state.lastError = '';
    state.version++;
    hilog.info(DOMAIN, TAG, 'huawei id signed in via web oauth, nick=%{public}s', nickName);
  }

  /** 当前授权码（给「复制授权码」用；没登录返回空串）。 */
  public authorizationCode(): string {
    const profile: HuaweiAccountProfile | undefined = this.profile();
    return profile !== undefined ? profile.authorizationCode : '';
  }

  /**
   * 走官方「获取头像昵称」接口取一次资料。
   *
   * 与文档示例逐项对齐：
   *   `scopes = ['profile']`            —— 头像昵称
   *   `permissions = ['serviceauthcode']` —— 顺带拿授权码（换云盘令牌用）
   *   `forceAuthorization = true`        —— 已授权直接返回，未登录/未授权才拉系统页
   *   `state = util.generateRandomUUID()` —— 回包校验，防跨站
   *
   * 不做「先静默再显式」那套：文档说得很明白，forceAuthorization=true 本身就带
   * 「已授权就不再打扰用户」的语义，传 false 只会在未登录/未授权时直接抛错误码。
   *
   * @param forceAuthorization 未登录或未授权时是否拉起系统页面（本应用恒为 true）。
   * @returns 授权凭据（含 avatarUri / nickName / authorizationCode）。
   */
  private async requestProfile(forceAuthorization: boolean):
    Promise<authentication.AuthorizationWithHuaweiIDCredential> {
    const context: common.UIAbilityContext | undefined = this.effectiveContext();
    if (context === undefined) {
      throw new HuaweiAuthError(0, 'no ability context');
    }
    const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
    const request: authentication.AuthorizationWithHuaweiIDRequest =
      provider.createAuthorizationWithHuaweiIDRequest();
    request.scopes = [PROFILE_SCOPE];
    request.permissions = [AUTHCODE_PERMISSION];
    request.forceAuthorization = forceAuthorization;
    request.state = util.generateRandomUUID();
    const expectState: string = request.state;
    const controller: authentication.AuthenticationController =
      new authentication.AuthenticationController(context);
    const response: authentication.AuthenticationResponse = await controller.executeRequest(request);
    const authResponse: authentication.AuthorizationWithHuaweiIDResponse =
      response as authentication.AuthorizationWithHuaweiIDResponse;
    // state 不一致 = 回包不是这次请求的，按失败处理（文档建议的一致性校验）
    const gotState: string = authResponse.state ?? '';
    if (gotState.length === 0 || gotState !== expectState) {
      hilog.error(DOMAIN, TAG, 'state mismatch: expect=%{public}s got=%{public}s', expectState, gotState);
      throw new HuaweiAuthError(ERR_STATE_MISMATCH, 'state mismatch');
    }
    const credential: authentication.AuthorizationWithHuaweiIDCredential | undefined = authResponse.data;
    if (credential === undefined) {
      throw new HuaweiAuthError(ERR_INTERNAL, 'empty credential');
    }
    hilog.info(DOMAIN, TAG, 'authorized scopes=%{public}s',
      (credential.authorizedScopes ?? []).join(','));
    return credential;
  }

  /**
   * 把头像下载到沙箱并返回**本地地址**（失败返回空串，不影响登录）。
   *
   * 为什么要下本地：官方注意项 —— 用户更新头像后原链接**立即失效**，直接长期引用
   * 网络地址早晚会 404。落盘成固定文件名 `huawei_avatar.img`，每次覆盖。
   *
   * 返回的地址形如 `file://<bundleName>/<沙箱路径>`，交给 `LocalCoverImage` 渲染
   * （它会用 fd 解码成 PixelMap —— 真机上沙箱 file:// 直接喂给 `Image` 出过
   * 「地址对、图不显示」的问题）。
   */
  private async cacheAvatar(url: string): Promise<string> {
    const profile: HuaweiAccountProfile | undefined = this.cached;
    if (url.length === 0 || profile === undefined) {
      return '';
    }
    const context: common.UIAbilityContext | undefined = this.effectiveContext();
    if (context === undefined) {
      return '';
    }
    const filePath: string = context.cacheDir + '/' + AVATAR_FILE;
    let request: http.HttpRequest | undefined = undefined;
    try {
      request = http.createHttp();
      const resp: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 20000,
        usingCache: false
      });
      if (resp.responseCode !== 200 || !(resp.result instanceof ArrayBuffer)) {
        hilog.warn(DOMAIN, TAG, 'avatar download failed: code=%{public}d url=%{public}s',
          resp.responseCode, url);
        return '';
      }
      const bytes: ArrayBuffer = resp.result as ArrayBuffer;
      if (bytes.byteLength === 0) {
        return '';
      }
      const file: fs.File = fs.openSync(filePath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, bytes);
      } finally {
        fs.closeSync(file);
      }
      const local: string = 'file://' + context.applicationInfo.name + filePath;
      // 原始网络地址要留着：本地缓存被系统清了以后，只能靠它把图重新下回来
      const network: string = profile.avatarNetworkUri !== undefined && profile.avatarNetworkUri.length > 0 ?
        profile.avatarNetworkUri : url;
      const updated: HuaweiAccountProfile = {
        openID: profile.openID,
        unionID: profile.unionID,
        nickName: profile.nickName,
        avatarUri: local,
        avatarNetworkUri: network,
        authorizationCode: profile.authorizationCode,
        // 这里同时兼任「上次尝试下载的时间」：失败时靠它做退避，别每次启动都去拉一遍
        loginAt: Date.now()
      };
      this.cached = updated;
      MusicStoreService.getInstance().setHuaweiAccount(JSON.stringify(updated));
      const state: HuaweiAccountState = this.state();
      state.avatarUri = local;
      state.version++;
      return local;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'avatar download error: %{public}s', error.message ?? '');
      return '';
    } finally {
      if (request !== undefined) {
        request.destroy();
      }
    }
  }

  /**
   * 错误码 → 用户看得懂的一句话（同时把原始 code 写进 hilog，方便对着
   * errorcode-account-kit 排查）。0/未知一律给「稍后重试」。
   */
  private static describeError(code: number, message: string): string {
    if (code === ERR_USER_CANCEL) {
      return '已取消授权';
    }
    if (code === ERR_NOT_LOGIN) {
      return '本机还没登录华为账号，请先到「设置 → 华为账号」登录后重试';
    }
    if (code === ERR_FINGERPRINT) {
      return '应用指纹证书校验失败（1001500001）：请确认已用当前签名证书的指纹在 AGC 登记并生效';
    }
    if (code === ERR_NOT_AUTHORIZED) {
      return '应用未获授权（1001502002）：请重新点击登录并在系统页面同意授权';
    }
    if (code === ERR_INVALID_PARAM) {
      return '参数无效（1001502003）：client_id 与实际应用不一致，或签名 profile 无效';
    }
    if (code === ERR_NO_SCOPE) {
      return '当前应用未申请 profile 权限（1001502014）';
    }
    if (code === ERR_UNSUPPORTED) {
      return '本设备/系统版本不支持该能力（1001500003）';
    }
    if (code === ERR_NETWORK) {
      return '网络异常，请检查网络后重试';
    }
    if (code === ERR_SYSTEM || code === ERR_INTERNAL) {
      return '华为账号服务异常，请稍后重试';
    }
    if (code === ERR_DUPLICATE) {
      return '上一次请求还在处理中，请稍候重试';
    }
    if (code === ERR_STATE_MISMATCH) {
      return '授权校验未通过，请重新登录';
    }
    return '登录失败（' + code + '）：' + (message.length > 0 ? message : '未知错误');
  }

  /** 解析持久化的 JSON（坏数据当作没登录）。 */
  private static parse(json: string): HuaweiAccountProfile | undefined {
    if (json.length === 0) {
      return undefined;
    }
    try {
      const profile: HuaweiAccountProfile = JSON.parse(json) as HuaweiAccountProfile;
      if (profile === undefined || profile.openID === undefined) {
        return undefined;
      }
      return profile;
    } catch (_err) {
      return undefined;
    }
  }
}
