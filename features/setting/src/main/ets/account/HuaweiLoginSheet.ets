/*
 * 网页授权登录层 —— **系统 Account Kit 走不通时的自动回退路径**。
 *
 * 侧载安装、签名指纹对不上、设备未登录华为账号、能力不支持等情况下，
 * `HuaweiAccountCard` 会按 Account Kit 的真实错误码自动打开本层；
 * 成功后写进同一个 `HuaweiAccountState`，只是 `loginViaWeb = true`。
 *
 * 系统profile仅需正确签名指纹与应用Client ID，不需要申请profile账号权限。
 * 网页Drive客户端须在AGC配置Drive服务与合法回调；与系统client的code不能互换。
 *
 * 流程：内嵌 Web 打开授权页 → 用户登录授权 → 回调到 redirect_uri 时**拦截**（不真的加载）
 *      → 取 `?code=` → 换云盘令牌 → 拉头像昵称写进登录态。
 */

import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { HuaweiAccountService, HuaweiCloudSync } from 'player';
import type { HuaweiDriveUser } from 'player';

const DOMAIN: number = 0x0000;
const TAG: string = 'RzdHuaweiLogin';

/** 与 RzdPai/Huawei_Cloud_Webdav 同一个 OAuth 客户端。 */
const CLIENT_ID: string = '117755925';
const REDIRECT_URI: string = 'https://webdav.rzdpai.com';
const SCOPE: string = 'openid+profile+https://www.huawei.com/auth/drive+https://www.huawei.com/auth/drive.file';
const AUTHORIZE_BASE: string = 'https://oauth-login.cloud.huawei.com/oauth2/v3/authorize';

@ComponentV2
export struct HuaweiLoginSheet {
  /** 关闭回调（宿主收起覆盖层）。 */
  @Param onClose: () => void = () => {};
  /** 登录成功回调（宿主刷新卡片状态 / 提示）。 */
  @Param onLinked: (message: string) => void = () => {};
  /** 是否由「系统登录不可用」自动回退进来的。 */
  @Param viaFallback: boolean = false;
  /** 当前进度 / 结果文案（界面从简，不解释原因）。 */
  @Local status: string = '';
  /** 是否已经成功。 */
  @Local done: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private oauthState: string = util.generateRandomUUID().replace(/-/g, '');
  private linking: boolean = false;
  private authorizeUrl: string = AUTHORIZE_BASE + '?response_type=code&access_type=offline' +
    `&state=${this.oauthState}&client_id=${CLIENT_ID}&redirect_uri=${encodeURIComponent(REDIRECT_URI)}&scope=${SCOPE}`;

  /** 顶部说明：一律只用一句话，不铺系统登录失败的原因（用户要求文案从简）。 */
  private subtitle(): string {
    return this.done ? '登录成功' : '网页授权登录';
  }

  /** 从地址里取一个查询参数。 */
  private paramOf(url: string, name: string): string {
    const query: number = url.indexOf('?');
    if (query < 0) {
      return '';
    }
    const params: string = '&' + url.substring(query + 1).split('#')[0];
    const key: string = '&' + name + '=';
    const start: number = params.indexOf(key);
    if (start < 0) {
      return '';
    }
    const from: number = start + key.length;
    const end: number = params.indexOf('&', from);
    const raw: string = end < 0 ? params.substring(from) : params.substring(from, end);
    try {
      return decodeURIComponent(raw);
    } catch (_err) {
      return raw;
    }
  }

  /** 回调地址被拦截：拿到 code 就换令牌，不再真的加载它。 */
  private intercept(url: string): boolean {
    const callback: string = url.split('?')[0].split('#')[0];
    if (callback !== REDIRECT_URI && callback !== REDIRECT_URI + '/') {
      return false;
    }
    if (this.done || this.linking) {
      return true;
    }
    if (this.paramOf(url, 'state') !== this.oauthState) {
      this.status = '授权校验失败，请关闭后重新登录';
      hilog.warn(DOMAIN, TAG, 'oauth callback state rejected');
      return true;
    }
    const code: string = this.paramOf(url, 'code');
    const error: string = this.paramOf(url, 'error');
    if (code.length === 0) {
      this.status = error.length > 0 ? `授权失败：${error}` : '授权失败：没有拿到授权码';
      hilog.warn(DOMAIN, TAG, 'oauth callback without code');
      return true;
    }
    this.linking = true;
    hilog.info(DOMAIN, TAG, 'oauth callback accepted, exchanging once');
    void this.link(code);
    return true;
  }

  /** 用授权码换令牌，并把头像昵称写进登录态。 */
  private async link(code: string): Promise<void> {
    this.status = '';
    const message: string = await HuaweiCloudSync.getInstance().linkWithCode(code);
    if (!message.startsWith('华为云盘已连接') || !HuaweiCloudSync.getInstance().linked()) {
      // 失败原因只进日志；界面只说「登录失败」
      hilog.warn(DOMAIN, TAG, 'web oauth link failed: %{public}s', message);
      this.status = '登录失败';
      return;
    }
    const user: HuaweiDriveUser | undefined = await HuaweiCloudSync.getInstance().fetchUserInfo();
    const nickName: string = user !== undefined && user.displayName.length > 0 ? user.displayName : '华为账号';
    const avatarUri: string = user !== undefined ? user.avatarUri : '';
    const uid: string = user !== undefined ? user.uid : '';
    // 系统身份优先保留；不同client的OpenID不是同一命名空间。
    if (!HuaweiAccountService.getInstance().state().signedIn) {
      // 网页授权成功 = 已登录（与系统路径共用同一份 HuaweiAccountState，只标来源）
      HuaweiAccountService.getInstance().applyWebProfile(nickName, avatarUri, uid, this.viaFallback);
    }
    this.done = true;
    this.status = '';
    hilog.info(DOMAIN, TAG, 'sign-in ok via=web fallback=%{public}d nick=%{public}s',
      this.viaFallback ? 1 : 0, nickName);
    this.onLinked('登录成功');
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text('华为账号登录')
          .fontSize($r('sys.float.Subtitle_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        Text(this.done ? '完成' : '关闭')
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.done ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
          .padding({ left: 12, right: 4, top: 6, bottom: 6 })
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 12, top: 8 })

      Text(this.subtitle())
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .padding({ left: 16, right: 16 })

      Text(this.status)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .padding({ left: 16, right: 16 })

      // 授权页：登录成功后回调地址会被拦截，页面停在这里由用户点「完成」收起
      Web({ src: this.authorizeUrl, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .width('100%')
        .layoutWeight(1)
        .onLoadIntercept((event: OnLoadInterceptEvent): boolean => {
          return event.data.isMainFrame() && this.intercept(event.data.getRequestUrl());
        })
    }
    .width('100%')
    .height('100%')
    // 顶栏要让开状态栏：这个覆盖层是铺满全屏的，不加就会像用户看到的那样
    // 「状态栏把标题栏压住了」
    .padding({ top: getStatusBarTopVpFromWindowUtil() })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
