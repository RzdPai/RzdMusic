/*
 * 华为账号卡片（系统 Account Kit）。
 *
 * 放在「登录平台音乐」那个面板（AccountManageSheet）的**最上方**，并用一条分隔线
 * 与下面的音乐平台账号（网易云 / QQ / 酷狗）分开 —— 它们是两码事：
 *   - 华为账号：系统账号，用来做登录身份与数据同步；
 *   - 平台账号：听歌用的第三方账号（扫码 / Cookie 登录）。
 *
 * 已授权过就**静默**拿头像昵称（`forceAuthorization = false`），没授权过才弹系统授权页；
 * 登录后可以「复制授权码」—— 把它填进「华为云盘 WebDAV 网关」的管理面板即可换取
 * 长期访问令牌（应用侧不保存云盘令牌）。
 */

import { pasteboard } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys, getAppRuntime, LocalCoverImage, ThemeState } from 'musicbasic';
import { HuaweiAccountService, HuaweiAccountState } from 'player';
import { HuaweiCloudSync } from 'player';
import { PlayerConstants } from 'player';
import { HuaweiLoginSheet } from './HuaweiLoginSheet';

const DANGER_COLOR: string = '#E64545';

@ComponentV2
export struct HuaweiAccountCard {
  /** 是否在卡片下面画一条分隔线（放在列表最上面时用）。 */
  @Param showDivider: boolean = true;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local huaweiState: HuaweiAccountState =
    AppStorageV2.connect(HuaweiAccountState, PlayerConstants.HUAWEI_ACCOUNT_STATE,
      () => new HuaweiAccountState())!;
  /** 云盘是否已连上（登录后自动用授权码换令牌）。 */
  @Local cloudLinked: boolean = false;
  /** 正在备份 / 恢复。 */
  @Local cloudBusy: boolean = false;
  /** 网页授权登录层（Account Kit 走不通时的兜底）。 */
  @Local showWebLogin: boolean = false;

  aboutToAppear(): void {
    // 卡片是设置里最常打开的入口：进来的地方顺手把服务初始化一遍，
    // 保证 Account Kit 拿得到 UIAbilityContext（早于设置页 aboutToAppear 也不会漏）
    HuaweiAccountService.getInstance().init(getAppRuntime().context as common.UIAbilityContext);
    this.cloudLinked = HuaweiCloudSync.getInstance().linked();
  }

  /**
   * 登录华为账号。
   *
   * 主路径是系统 Account Kit「获取头像昵称」接口（`HuaweiAccountService.signIn()`）。
   * 成功则顺手用授权码换云盘令牌。
   *
   * **失败时把真实错误码文案原样提示出来**，再切网页授权兜底 —— 之前只提示
   * 「已切换为网页授权」，把 1001500001/1001502003 这类关键信息吃掉了，
   * 不利于用户去 AGC 配指纹。
   */
  private async signIn(): Promise<void> {
    const service: HuaweiAccountService = HuaweiAccountService.getInstance();
    const ok: boolean = await service.signIn();
    if (ok) {
      this.getUIContext().getPromptAction().showToast({ message: '华为账号已登录', duration: 1800 });
      const code: string = service.authorizationCode();
      const message: string = await HuaweiCloudSync.getInstance().linkWithCode(code);
      this.cloudLinked = HuaweiCloudSync.getInstance().linked();
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
      return;
    }
    const reason: string = this.huaweiState.lastError.length > 0 ? this.huaweiState.lastError : '系统登录不可用';
    this.getUIContext().getPromptAction().showToast({
      message: reason + '（已切换为网页授权登录）',
      duration: 4000
    });
    this.showWebLogin = true;
  }

  /** 网页授权登录层。 */
  @Builder
  private WebLoginContent() {
    HuaweiLoginSheet({
      onClose: (): void => {
        this.showWebLogin = false;
      },
      onLinked: (message: string): void => {
        this.cloudLinked = HuaweiCloudSync.getInstance().linked();
        this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
      }
    })
  }

  /** 备份「设置 + 歌单」到华为云盘。 */
  private async backup(): Promise<void> {
    if (this.cloudBusy) {
      return;
    }
    this.cloudBusy = true;
    const message: string = await HuaweiCloudSync.getInstance().uploadSnapshot();
    this.cloudBusy = false;
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
  }

  /** 从华为云盘恢复「设置 + 歌单」。 */
  private async restore(): Promise<void> {
    if (this.cloudBusy) {
      return;
    }
    this.cloudBusy = true;
    const message: string = await HuaweiCloudSync.getInstance().downloadSnapshot();
    this.cloudBusy = false;
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
  }

  /** 复制授权码：可直接填进华为云盘 WebDAV 网关的管理面板。 */
  private copyAuthCode(): void {
    const code: string = HuaweiAccountService.getInstance().authorizationCode();
    if (code.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '没有可用授权码，请重新登录', duration: 2000 });
      return;
    }
    const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, code);
    const sysPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    sysPasteboard.setData(pasteData);
    this.getUIContext().getPromptAction().showToast({ message: '授权码已复制', duration: 2000 });
  }

  build() {
    // 只能有一个根节点：卡片 + （可选）分隔线一起包在 Column 里
    Column({ space: 10 }) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('华为账号')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('系统账号')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')

        Row({ space: 12 }) {
          if (this.huaweiState.signedIn && this.huaweiState.avatarUri.length > 0) {
            // 头像已经落到沙箱（file://…）：交给 LocalCoverImage 用 fd 解码，
            // 避免真机上「沙箱 file:// 直接喂 Image 不显示」的老问题
            LocalCoverImage({
              src: this.huaweiState.avatarUri,
              imageWidth: 44,
              imageHeight: 44,
              radius: 22,
              fit: ImageFit.Cover
            })
          } else {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
              .fontSize(44)
              .fontWeight(FontWeight.Regular)
              .fontColor([$r('sys.color.icon_tertiary')])
          }

          Column({ space: 2 }) {
            Text(this.huaweiState.signedIn ?
              (this.huaweiState.nickName.length > 0 ? this.huaweiState.nickName : '华为账号') : '登录华为账号')
              .fontSize($r('sys.float.Body_L'))
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.huaweiState.signedIn ? '已登录' : '用系统华为账号登录，可同步设置与歌单')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (this.huaweiState.signedIn) {
            Text('复制授权码')
              .fontSize($r('sys.float.Body_S'))
              .fontColor(this.themeState.color)
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .onClick(() => {
                this.copyAuthCode();
              })
            Text('退出')
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .onClick(() => {
                HuaweiAccountService.getInstance().signOut();
              })
          } else {
            Button(this.huaweiState.loggingIn ? '登录中…' : '登录')
              .height(32)
              .fontSize($r('sys.float.Body_S'))
              .backgroundColor(this.themeState.color)
              .fontColor($r('sys.color.font_on_primary'))
              .onClick(() => {
                void this.signIn();
              })
          }
        }
        .width('100%')

        if (this.huaweiState.lastError.length > 0) {
          Text(this.huaweiState.lastError)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(DANGER_COLOR)
            .width('100%')
        }

        // 云盘备份 / 恢复：登录后自动连上云盘（用授权码换令牌），之后一键备份设置与歌单
        if (this.huaweiState.signedIn) {
          Row({ space: 8 }) {
            Button(this.cloudBusy ? '处理中…' : '备份到云盘')
              .height(32)
              .fontSize($r('sys.float.Body_S'))
              .backgroundColor($r('sys.color.background_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .onClick(() => {
                void this.backup();
              })
            Button('从云盘恢复')
              .height(32)
              .fontSize($r('sys.float.Body_S'))
              .backgroundColor($r('sys.color.background_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .onClick(() => {
                void this.restore();
              })
            Text(this.cloudLinked ? '云盘已连接' : '云盘未连接')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
              .layoutWeight(1)
              .textAlign(TextAlign.End)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .borderRadius($r('sys.float.corner_radius_level12'))
      .backgroundColor($r('sys.color.background_secondary'))

      // 与下面的音乐平台账号分开
      if (this.showDivider) {
        Divider()
          .strokeWidth(0.6)
          .color($r('sys.color.background_tertiary'))
      }
    }
    .width('100%')
    .bindContentCover($$this.showWebLogin, this.WebLoginContent(), {
      // 用 NONE：DEFAULT 的「从底部推上来」过渡结束后容器会在底部留一条空白
      // （播放页那边踩过同一个坑，见 products/default 的注释）
      modalTransition: ModalTransition.NONE
    })
  }
}
