/*
 * 华为账号登录（双路径）。
 *
 * ┌ 主路径：系统级 Account Kit「获取头像昵称」接口
 * │   文档：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/account-get-avatar-nickname
 * │   接口：`HuaweiIDProvider.createAuthorizationWithHuaweiIDRequest()` + `scopes=['profile']`
 * │         + `permissions=['serviceauthcode']` + `forceAuthorization=true` + `state=<uuid>`。
 * └ 回退路径：网页授权（`HuaweiCloudSync` / `HuaweiLoginSheet` 那条 OAuth 链路）。
 *
 * 为什么要两条：网页 OAuth 客户端（Client ID 117755925）与系统 client 不是同一个，
 * 用户**侧载安装**时签名指纹与 AGC 登记的不一致、或设备未登录华为账号、或该设备/
 * 版本不支持 Account Kit 接口时，系统路径必然失败 —— 这时必须自动回退到网页授权，
 * 否则侧载用户完全没法登录。判据只看 Account Kit 的**真实错误码**
 * （见 `huaweiNeedsWebFallback`），不靠猜；两条路都保留，界面提示走的是哪条。
 *
 * 关于 forceAuthorization：**必须是 true**。文档说明 forceAuthorization=true 时，
 * 若用户已授权则仍直接返回资料、只有「未登录 / 未授权」才拉起系统页面；设为 false
 * 反而会在未登录时直接抛 1001502001、未授权时抛 1001502002 —— 所以刻意不做
 * 「先 false 静默、失败再 true」那套，直接 true 一次到位。
 *
 * 关于资料范围：只要 `profile`（头像 + 昵称），不申请手机号 / 邮箱，授权面最小；
 * 本场景**无需在 AGC 申请账号权限**。系统授权码不交给网页client；原生云同步不使用OAuth。
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
import { HuaweiAccountCode, huaweiFallbackReason, huaweiNeedsWebFallback } from './HuaweiAccountCode';

const DOMAIN: number = 0x0000;
const TAG: string = 'RzdHuaweiLogin';

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

// Account Kit 错误码统一放在 HuaweiAccountCode（两条登录链路共用同一套判据）
const ERR_FINGERPRINT: number = HuaweiAccountCode.FINGERPRINT;
const ERR_DUPLICATE: number = HuaweiAccountCode.DUPLICATE;
const ERR_UNSUPPORTED: number = HuaweiAccountCode.UNSUPPORTED;
const ERR_NOT_LOGIN: number = HuaweiAccountCode.NOT_LOGIN;
const ERR_NOT_AUTHORIZED: number = HuaweiAccountCode.NOT_AUTHORIZED;
const ERR_INVALID_PARAM: number = HuaweiAccountCode.INVALID_PARAM;
const ERR_NETWORK: number = HuaweiAccountCode.NETWORK;
const ERR_INTERNAL: number = HuaweiAccountCode.INTERNAL;
const ERR_USER_CANCEL: number = HuaweiAccountCode.USER_CANCEL;
const ERR_NO_SCOPE: number = HuaweiAccountCode.NO_SCOPE;
const ERR_SYSTEM: number = HuaweiAccountCode.SYSTEM;
const ERR_STATE_MISMATCH: number = HuaweiAccountCode.STATE_MISMATCH;

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
  /**
   * 这条资料是不是**网页授权**那条路写进来的。
   *
   * 两条路都能登录（见类顶部说明），但界面要说清用户走的是哪条，
   * 老版本存的 JSON 没这个字段（`undefined` ⇒ 按系统路径处理）。
   */
  loginViaWeb?: boolean;
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
  /** 当前登录态来自网页授权那条路（false = 系统 Account Kit）。 */
  @Trace public loginViaWeb: boolean = false;
  /** 系统路径不可用，已自动回退到网页授权（界面提示用）。 */
  @Trace public webFallback: boolean = false;
}

/**
 * 界面要的「走的是哪条路」显示档位。
 * 只用状态派生，不新起一份登录真源。
 */
export enum HuaweiLoginMode {
  /** 没登录。 */
  NONE = 0,
  /** 系统 Account Kit 登录。 */
  SYSTEM = 1,
  /** 网页授权登录（系统路径不可用时的回退）。 */
  WEB = 2
}

/**
 * 一次登录尝试的结果（把「走系统还是走网页」这件事显式交给调用方）。
 * 用类而不是对象字面量：ArkTS 不给无类型对象字面量当返回值。
 */
export class HuaweiLoginOutcome {
  /** 是否已登录（两条路任一条成功都算）。 */
  public readonly signedIn: boolean;
  /** 是否走网页授权。 */
  public readonly viaWeb: boolean;
  /** 失败时给用户看的文案（成功时空串）。 */
  public readonly reason: string;
  /** 失败时是否应该自动回退到网页授权。 */
  public readonly systemUnavailable: boolean;
  /** 失败时的原始错误码（0 = 本应用内部原因，例如拿不到 UIAbilityContext）。 */
  public readonly errorCode: number;

  constructor(signedIn: boolean, viaWeb: boolean, reason: string, systemUnavailable: boolean,
    errorCode: number = 0) {
    this.signedIn = signedIn;
    this.viaWeb = viaWeb;
    this.reason = reason;
    this.systemUnavailable = systemUnavailable;
    this.errorCode = errorCode;
  }
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
  /** `cached` 是不是已经从持久化里读过了（`undefined` 也可能是「确实没登录过」）。 */
  private hasCached: boolean = false;

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

  /**
   * 登录态走的是哪条路（界面文案用）。
   * 直接从状态派生，**不另起一份真源**：`loginViaWeb` 由写入 profile 的那一方维护。
   */
  public loginMode(): HuaweiLoginMode {
    const state: HuaweiAccountState = this.state();
    if (!state.signedIn) {
      return HuaweiLoginMode.NONE;
    }
    return state.loginViaWeb ? HuaweiLoginMode.WEB : HuaweiLoginMode.SYSTEM;
  }

  /** 记录 UIAbility 上下文（登录需要它拉起系统授权页）。 */
  public init(context: common.UIAbilityContext): void {
    this.context = context;
    this.restore();
  }

  /** 已保存的账号资料（没登录过返回 undefined）。 */
  public profile(): HuaweiAccountProfile | undefined {
    if (!this.hasCached) {
      this.cached = HuaweiAccountService.parse(MusicStoreService.getInstance().getHuaweiAccount());
      this.hasCached = true;
    }
    return this.cached;
  }

  /** 落盘一份资料（两条登录路径共用同一份形状，`loginViaWeb` 标明来自哪条）。 */
  private writeProfile(profile: HuaweiAccountProfile): void {
    this.cached = profile;
    this.hasCached = true;
    MusicStoreService.getInstance().setHuaweiAccount(JSON.stringify(profile));
  }

  /** 从持久化里恢复登录态（进程启动时调一次即可，重复调无副作用）。 */
  public restore(): void {
    const profile: HuaweiAccountProfile | undefined = this.profile();
    const state: HuaweiAccountState = this.state();
    if (profile === undefined) {
      state.signedIn = false;
      state.nickName = '';
      state.avatarUri = '';
      state.loginViaWeb = false;
      state.version++;
      return;
    }
    state.signedIn = true;
    state.nickName = profile.nickName;
    state.avatarUri = profile.avatarUri;
    state.loginViaWeb = profile.loginViaWeb === true;
    state.version++;
    hilog.info(DOMAIN, TAG, 'restored signed-in state via=%{public}s',
      state.loginViaWeb ? 'web' : 'system');
    this.ensureLocalAvatar(profile);
  }

  /**
   * 登录华为账号（**双路径**）：先系统 Account Kit，走不通再自动回退网页授权。
   *
   * 回退判据只有一条：系统路径抛出的**真实错误码**能被
   * `huaweiNeedsWebFallback` 判定为「这台设备/这个安装包上系统登录不可用」
   * （典型：侧载安装 ⇒ 1001500001 指纹校验失败；设备未登录华为账号 ⇒ 1001502001；
   * 未上架/签名 profile 无效 ⇒ 1001502003；能力不支持 ⇒ 1001500003；系统服务异常 ⇒ 12300001）。
   * 用户主动取消（1001502012）与网络/内部错误**不回退** —— 那两种重试就好，
   * 而且用户在系统页面点了取消却弹个网页出来是反直觉的。
   *
   * 结果用 `HuaweiLoginOutcome` 显式带回给界面，界面据此提示「走的是哪条」。
   */
  public async signIn(): Promise<HuaweiLoginOutcome> {
    const state: HuaweiAccountState = this.state();
    if (state.loggingIn) {
      return new HuaweiLoginOutcome(false, false, '登录正在进行中', false);
    }
    // 兜底：调用方（设置页 / 卡片）不一定走过 init()，这里再从全局运行时补一次上下文
    if (this.context === undefined) {
      const runtime: common.UIAbilityContext | undefined = getAppRuntime().context;
      if (runtime !== undefined) {
        this.context = runtime;
      }
    }
    if (this.effectiveContext() === undefined) {
      // 拿不到 UIAbilityContext ⇒ 系统路径连请求都发不出去：这正是「能力不可用」的一种，回退网页
      state.lastError = '拿不到应用上下文，系统登录不可用';
      state.version++;
      const reason: string = huaweiFallbackReason(0);
      hilog.warn(DOMAIN, TAG, 'sign-in aborted: no ability context, fallbackToWeb=1 reason=%{public}s', reason);
      return new HuaweiLoginOutcome(false, false, state.lastError, true);
    }
    state.loggingIn = true;
    state.lastError = '';
    state.webFallback = false;
    state.version++;
    hilog.info(DOMAIN, TAG, 'sign-in start: try system account kit first');
    try {
      const credential: authentication.AuthorizationWithHuaweiIDCredential =
        await this.requestProfile(true);
      const profile: HuaweiAccountProfile = {
        openID: credential.openID ?? '',
        unionID: credential.unionID ?? '',
        nickName: credential.nickName ?? '',
        avatarUri: credential.avatarUri ?? '',
        // 一次性系统code不落盘、不复制给不同client；原生云文件同步不使用OAuth。
        authorizationCode: '',
        loginAt: Date.now(),
        loginViaWeb: false
      };
      this.writeProfile(profile);
      state.signedIn = true;
      state.nickName = profile.nickName;
      state.avatarUri = profile.avatarUri;
      state.loginViaWeb = false;
      state.lastError = '';
      hilog.info(DOMAIN, TAG,
        'sign-in ok via=system avatar=%{public}d codePresent=%{public}d; drive requires separate authorization',
        profile.avatarUri.length > 0 ? 1 : 0, profile.authorizationCode.length > 0 ? 1 : 0);
      // 头像链接随时会失效：先存到沙箱，界面随后换成 file:// 本地路径
      const local: string = await this.cacheAvatar(profile.avatarUri);
      if (local.length > 0) {
        hilog.info(DOMAIN, TAG, 'avatar cached locally: %{public}s', local);
      }
      return new HuaweiLoginOutcome(true, false, '', false);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      const code: number = error.code ?? 0;
      state.lastError = HuaweiAccountService.describeError(code, error.message ?? '');
      const fallback: boolean = huaweiNeedsWebFallback(code);
      hilog.warn(DOMAIN, TAG,
        'sign-in failed via=system code=%{public}d msg=%{public}s mapped=%{public}s fallbackToWeb=%{public}d',
        code, error.message ?? '', state.lastError, fallback ? 1 : 0);
      return new HuaweiLoginOutcome(false, false, state.lastError, fallback, code);
    } finally {
      state.loggingIn = false;
      state.version++;
    }
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

  /** 退出登录（只清本地资料；不调系统的取消授权，用户可在系统设置里撤销）。 */
  public signOut(): void {
    this.cached = undefined;
    this.hasCached = true;
    MusicStoreService.getInstance().setHuaweiAccount('');
    // 云盘令牌是跟着这个账号来的，退出时一起清掉（下次登录会重新换）
    MusicStoreService.getInstance().setHuaweiDriveToken('');
    const state: HuaweiAccountState = this.state();
    state.signedIn = false;
    state.nickName = '';
    state.avatarUri = '';
    state.lastError = '';
    state.loginViaWeb = false;
    state.webFallback = false;
    state.version++;
    hilog.info(DOMAIN, TAG, 'signed out (music account + legacy drive token cleared)');
  }

  /**
   * 网页授权登录成功后写入登录态（**回退路径**：系统 Account Kit 走不通时用）。
   *
   * 两条路的区别：Account Kit 的资料来自系统账号服务（可信、免跳网页），
   * 但要求 AGC 里签好公钥指纹；网页授权用云盘那套 OAuth 客户端，不依赖 AGC 配置，
   * 资料从 OAuth 的 id_token / 云盘 OpenAPI 取。登录成功后**两条路共用同一份
   * `HuaweiAccountState`**（`signedIn`/`nickName`/`avatarUri`），只是 `loginViaWeb`
   * 标明来源，界面据此显示「已登录（网页授权）」。
   *
   * @param viaFallback 是否因系统路径不可用而自动回退进来的（界面提示用）。
   */
  public applyWebProfile(nickName: string, avatarUri: string, openID: string,
    viaFallback: boolean = false): void {
    const profile: HuaweiAccountProfile = {
      openID: openID,
      unionID: '',
      nickName: nickName,
      avatarUri: avatarUri,
      authorizationCode: '',
      loginAt: Date.now(),
      loginViaWeb: true
    };
    this.writeProfile(profile);
    const state: HuaweiAccountState = this.state();
    state.signedIn = true;
    state.nickName = nickName;
    state.avatarUri = avatarUri;
    state.loginViaWeb = true;
    state.webFallback = viaFallback;
    state.lastError = '';
    state.version++;
    hilog.info(DOMAIN, TAG, 'sign-in ok via=web fallback=%{public}d nick=%{public}s',
      viaFallback ? 1 : 0, nickName);
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
        loginAt: Date.now(),
        // 头像缓存不能改掉「这条资料从哪条路来」的标记
        loginViaWeb: profile.loginViaWeb === true
      };
      this.writeProfile(updated);
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
   *
   * 文案里保留原始错误码：用户拿这一句去 AGC 配指纹/查文档时不用再猜。
   */
  private static describeError(code: number, message: string): string {
    if (code === ERR_USER_CANCEL) {
      return '已取消授权';
    }
    if (code === ERR_NOT_LOGIN) {
      return '本机还没登录华为账号（1001502001），系统登录不可用';
    }
    if (code === ERR_FINGERPRINT) {
      return '应用指纹证书校验失败（1001500001）：当前安装包签名未被系统识别，系统登录不可用';
    }
    if (code === ERR_NOT_AUTHORIZED) {
      return '应用未获授权（1001502002）：请重新点击登录并在系统页面同意授权';
    }
    if (code === ERR_INVALID_PARAM) {
      return '参数无效（1001502003）：client_id 与实际应用不一致，或签名 profile 无效';
    }
    if (code === ERR_NO_SCOPE) {
      return '当前应用未申请 profile 权限（1001502014），系统登录不可用';
    }
    if (code === ERR_UNSUPPORTED) {
      return '本设备/系统版本不支持该能力（1001500003），系统登录不可用';
    }
    if (code === ERR_NETWORK) {
      return '网络异常，请检查网络后重试';
    }
    if (code === ERR_SYSTEM) {
      return '系统华为账号服务异常（12300001），请稍后重试';
    }
    if (code === ERR_INTERNAL) {
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

  /**
   * 为什么改用网页授权：**只用于日志**（界面上一律只说「登录成功 / 登录失败」，用户要求文案从简）。
   * 判据与 `huaweiNeedsWebFallback` 同一套，不另起一份。
   */
  public static describeFallback(code: number): string {
    return 'system sign-in unavailable (' + huaweiFallbackReason(code) + '), using web authorization';
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
      profile.authorizationCode = '';
      // 老版本（只有系统路径时）存的 JSON 没有这个字段：undefined 按系统路径处理
      profile.loginViaWeb = profile.loginViaWeb === true;
      return profile;
    } catch (_err) {
      return undefined;
    }
  }
}
