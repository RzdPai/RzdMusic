/*
 * 华为账号「网页授权」登录（Account Kit 走不通时的兜底，也是云盘备份的前提）。
 *
 * 为什么要有这条路：系统一键登录（Account Kit）要求应用在 AGC 里登记**签名证书指纹**
 * 并开通华为账号 + 申请 profile 权限，缺一样就报「Invalid clientId or profile」。
 * 而「华为云盘 WebDAV 网关」那套 OAuth 网页授权不依赖这些配置 —— 只要那个
 * OAuth 客户端（client_id 117755925）有效就能登录拿授权码。
 *
 * 流程：内嵌 Web 打开授权页 → 用户登录授权 → 回调到 redirect_uri 时**拦截**（不真的加载）
 *      → 取 `?code=` → 换云盘令牌 → 拉头像昵称写进登录态。
 */

import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { HuaweiAccountService, HuaweiCloudSync } from 'player';
import type { HuaweiDriveUser } from 'player';

const DOMAIN: number = 0x0000;
const TAG: string = 'RzdHuaweiWebLogin';

/** 与 RzdPai/Huawei_Cloud_Webdav 同一个 OAuth 客户端。 */
const CLIENT_ID: string = '117755925';
const REDIRECT_URI: string = 'https://webdav.rzdpai.com';
const SCOPE: string = 'openid+profile+https://www.huawei.com/auth/drive+https://www.huawei.com/auth/drive.file';
const AUTHORIZE_URL: string = 'https://oauth-login.cloud.huawei.com/oauth2/v3/authorize' +
  '?response_type=code&access_type=offline&state=rzdmusic' +
  `&client_id=${CLIENT_ID}&redirect_uri=${encodeURIComponent(REDIRECT_URI)}&scope=${SCOPE}`;

@ComponentV2
export struct HuaweiLoginSheet {
  /** 关闭回调（宿主收起覆盖层）。 */
  @Param onClose: () => void = () => {};
  /** 登录成功回调（宿主刷新卡片状态 / 提示）。 */
  @Param onLinked: (message: string) => void = () => {};
  /** 当前进度 / 结果文案。 */
  @Local status: string = '登录后即可把设置和歌单备份到华为云盘';
  /** 是否已经成功。 */
  @Local done: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();

  /** 从地址里取一个查询参数。 */
  private paramOf(url: string, name: string): string {
    const key: string = name + '=';
    const start: number = url.indexOf(key);
    if (start < 0) {
      return '';
    }
    const from: number = start + key.length;
    const end: number = url.indexOf('&', from);
    const raw: string = end < 0 ? url.substring(from) : url.substring(from, end);
    try {
      return decodeURIComponent(raw);
    } catch (_err) {
      return raw;
    }
  }

  /** 回调地址被拦截：拿到 code 就换令牌，不再真的加载它。 */
  private intercept(url: string): boolean {
    if (!url.startsWith(REDIRECT_URI)) {
      return false;
    }
    const code: string = this.paramOf(url, 'code');
    const error: string = this.paramOf(url, 'error');
    if (code.length === 0) {
      this.status = error.length > 0 ? `授权失败：${error}` : '授权失败：没有拿到授权码';
      hilog.warn(DOMAIN, TAG, 'redirect without code: %{public}s', url);
      return true;
    }
    void this.link(code);
    return true;
  }

  /** 用授权码换云盘令牌，并把头像昵称写进登录态。 */
  private async link(code: string): Promise<void> {
    this.status = '正在连接华为云盘…';
    const message: string = await HuaweiCloudSync.getInstance().linkWithCode(code);
    if (!HuaweiCloudSync.getInstance().linked()) {
      this.status = message;
      return;
    }
    const user: HuaweiDriveUser | undefined = await HuaweiCloudSync.getInstance().fetchUserInfo();
    const nickName: string = user !== undefined && user.displayName.length > 0 ? user.displayName : '华为账号';
    const avatarUri: string = user !== undefined ? user.avatarUri : '';
    const uid: string = user !== undefined ? user.uid : '';
    HuaweiAccountService.getInstance().applyWebProfile(nickName, avatarUri, uid);
    this.done = true;
    this.status = '已登录：' + nickName;
    this.onLinked('已登录华为账号（网页授权）');
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

      Text(this.status)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .padding({ left: 16, right: 16 })

      // 授权页：登录成功后回调地址会被拦截，页面停在这里由用户点「完成」收起
      Web({ src: AUTHORIZE_URL, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .width('100%')
        .layoutWeight(1)
        .onLoadIntercept((event: OnLoadInterceptEvent): boolean => {
          return this.intercept(event.data.getRequestUrl());
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
