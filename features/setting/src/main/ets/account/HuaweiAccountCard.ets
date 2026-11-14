/*
 * 华为账号卡片（**双路径登录**：系统 Account Kit 优先，走不通自动回退网页授权）。
 *
 * 放在「登录平台音乐」那个面板（AccountManageSheet）的**最上方**，并用一条分隔线
 * 与下面的音乐平台账号（网易云 / QQ / 酷狗）分开 —— 它们是两码事：
 *   - 华为账号：系统账号，用来做登录身份与数据同步；
 *   - 平台账号：听歌用的第三方账号（扫码 / Cookie 登录）。
 *
 * 为什么两条路都要（用户最初的设计就是这个）：
 *   有些用户是**侧载安装**，签名与 AGC 登记指纹不一致 ⇒ 系统 Account Kit 必然失败
 *   （1001500001/1001502003），设备未登录华为账号或设备不支持该能力时同样失败。
 *   这种用户必须能走网页授权（HuaweiCloudSync/HuaweiLoginSheet 那条链路）登录。
 *   判据只用 Account Kit 的**真实错误码**（`huaweiNeedsWebFallback`），
 *   界面一定会告诉用户走的是哪条（toast + 卡片副标题 + hilog `RzdHuaweiLogin`）。
 *
 * 两套云空间（历史遗留）：
 *   系统云同步 = CoreFileKit 原生个人云空间；旧云盘（网页）= 旧 Drive OAuth 那套，凭据单独保存。
 *   ⚠️ 2026-10-01 用户明确要求：**卡片上那一坨云空间说明文字全部删掉**（「原生备份须在…」「旧网页
 *   云盘凭据已保存；与系统云同步是独立空间」等），但**功能一个都不能删** —— 系统云空间备份/恢复、
 *   旧云盘（网页）备份/恢复四个入口都要留着，只是标签写短一点、不再堆解释。
 */

import { HuaweiNativeCloudBackup } from 'player';
import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageKeys, getAppRuntime, LocalCoverImage, ThemeState } from 'musicbasic';
import { HuaweiAccountService, HuaweiAccountState, HuaweiLoginOutcome } from 'player';
import { HuaweiCloudSync } from 'player';
import { PlayerConstants } from 'player';
import { HuaweiLoginSheet } from './HuaweiLoginSheet';

/** 旧云盘（网页）两个入口的短标签：功能保留，解释文字一律不要。 */
const LEGACY_BACKUP_LABEL: string = '旧云盘备份';
const LEGACY_RESTORE_LABEL: string = '旧云盘恢复';

@ComponentV2
export struct HuaweiAccountCard {
  /** 是否在卡片下面画一条分隔线（放在列表最上面时用）。 */
  @Param showDivider: boolean = true;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local huaweiState: HuaweiAccountState =
    AppStorageV2.connect(HuaweiAccountState, PlayerConstants.HUAWEI_ACCOUNT_STATE,
      () => new HuaweiAccountState())!;
  /** 正在备份 / 恢复。 */
  @Local cloudBusy: boolean = false;
  /** 网页授权登录层（系统 Account Kit 走不通时的回退）。 */
  @Local showWebLogin: boolean = false;
  /** 是不是「系统登录不可用 ⇒ 自动回退」打开的网页层。 */
  @Local webLoginViaFallback: boolean = false;

  aboutToAppear(): void {
    // 卡片是设置里最常打开的入口：进来的地方顺手把服务初始化一遍，
    // 保证 Account Kit 拿得到 UIAbilityContext（早于设置页 aboutToAppear 也不会漏）
    HuaweiAccountService.getInstance().init(getAppRuntime().context as common.UIAbilityContext);
  }

  /** 卡片副标题：只报登录状态，不做任何解释（用户要求文案从简）。 */
  private loginMethodLabel(): string {
    return this.huaweiState.signedIn ? '已登录' : '未登录';
  }

  /** 备份 / 恢复结果文案（只在服务给出明确结论后调用）。 */
  private toast(message: string, duration: number): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: duration });
  }

  /** 打开网页授权层（系统登录不可用时的自动回退）；原因只进日志，不铺在界面上。 */
  private openWebLogin(viaFallback: boolean, _reason: string): void {
    this.webLoginViaFallback = viaFallback;
    this.showWebLogin = true;
  }

  /**
   * 登录华为账号：**先系统 Account Kit，走不通再自动回退网页授权**。
   *
   * 回退判据 = `HuaweiLoginOutcome.systemUnavailable`，它只由
   * `huaweiNeedsWebFallback(真实错误码)` 决定：
   *   1001500001 指纹校验失败（侧载最常见）/ 1001502001 设备未登录华为账号 /
   *   1001502003 入参无效（未上架、签名 profile 不被认可）/ 1001500003 能力不支持 /
   *   1001502014 未申请权限 / 12300001 系统服务异常 / 拿不到 UIAbilityContext。
   * 用户主动取消（1001502012）与网络异常不回退：重试即可，弹网页反而反直觉。
   *
   * 两条路成功都算已登录（写进同一个 HuaweiAccountState，`loginViaWeb` 标来源）。
   * 界面只报「登录成功 / 登录失败」这一句结论，走哪条路与失败原因都只写 hilog。
   */
  private async signIn(): Promise<void> {
    const service: HuaweiAccountService = HuaweiAccountService.getInstance();
    const outcome: HuaweiLoginOutcome = await service.signIn();
    if (outcome.signedIn) {
      // 只报结论，不做任何说明（用户要求）
      this.toast('登录成功', 1800);
      return;
    }
    if (outcome.systemUnavailable) {
      // 系统这条路走不通 ⇒ 直接弹网页授权层，界面上不再解释原因（原因写日志 RzdHuaweiLogin）
      hilog.info(0, 'RzdHuaweiLogin', 'system sign-in unavailable, opening web fallback: %{public}s',
        HuaweiAccountService.describeFallback(outcome.errorCode));
      this.openWebLogin(true, '');
      return;
    }
    this.toast('登录失败', 3000);
  }

  /** 网页授权登录层（系统 Account Kit 走不通时自动打开）。 */
  @Builder
  private WebLoginContent() {
    HuaweiLoginSheet({
      viaFallback: this.webLoginViaFallback,
      onClose: (): void => {
        this.showWebLogin = false;
      },
      onLinked: (_message: string): void => {
        // 只提示「登录成功」，不用网页层给的那句长文案（用户要求）
        this.toast('登录成功', 1800);
      }
    })
  }

  /** 备份「设置 + 歌单」到系统华为云空间（原生 FileSync）。 */
  private async backup(): Promise<void> {
    if (this.cloudBusy) {
      return;
    }
    this.cloudBusy = true;
    // 服务内部只在 getCoreFileSyncState()===UPLOAD_SUCCESS 时才回「已备份…」，
    // 未确认上云时给的是「文件已保存在本机，但未确认上云」⇒ 这里原样播报，不提前报成功
    const message: string = await HuaweiNativeCloudBackup.getInstance().backup();
    this.cloudBusy = false;
    this.toast(message, 3000);
  }

  /** 从系统华为云空间恢复「设置 + 歌单」。 */
  private async restore(): Promise<void> {
    if (this.cloudBusy) {
      return;
    }
    this.cloudBusy = true;
    // 没有任何「已上云」备份时服务返回「系统云空间没有已上云的应用备份；…」⇒ 照样原样播报
    const message: string = await HuaweiNativeCloudBackup.getInstance().restore();
    this.cloudBusy = false;
    this.toast(message, 3000);
  }

  /** 旧网页云盘备份 / 恢复（**功能保留**，只是界面上不再有那句解释文字）。 */
  private async legacyBackup(restore: boolean): Promise<void> {
    if (this.cloudBusy) {
      return;
    }
    if (!HuaweiCloudSync.getInstance().linked()) {
      // 还没有旧网页凭据：先走网页授权，授权成功后再让用户点一次
      this.openWebLogin(false, '');
      return;
    }
    this.cloudBusy = true;
    const message: string = restore ? await HuaweiCloudSync.getInstance().downloadSnapshot() :
      await HuaweiCloudSync.getInstance().uploadSnapshot();
    this.cloudBusy = false;
    hilog.info(0, 'RzdHuaweiCloud', 'legacy web drive action=%{public}s done', restore ? 'restore' : 'backup');
    this.toast(message, 3000);
  }

  /** 系统云空间备份 / 恢复（功能保留）。 */

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
            Text(this.loginMethodLabel())
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (this.huaweiState.signedIn) {
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

        // 系统云空间备份 / 恢复（卡片上不再有任何说明文字：失败原因只进日志，见文件头注释）
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
            Button(this.cloudBusy ? '处理中…' : '从云盘恢复')
              .height(32)
              .fontSize($r('sys.float.Body_S'))
              .backgroundColor($r('sys.color.background_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .onClick(() => {
                void this.restore();
              })
            Text('系统云空间')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
              .layoutWeight(1)
              .textAlign(TextAlign.End)
          }
          .width('100%')

          // 旧云盘（网页）：**功能保留**（与系统云同步是两个独立空间），只是不再堆解释文字
          Row({ space: 8 }) {
            Button(LEGACY_BACKUP_LABEL)
              .height(32)
              .fontSize($r('sys.float.Body_S'))
              .backgroundColor($r('sys.color.background_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .onClick(() => {
                void this.legacyBackup(false);
              })
            Button(LEGACY_RESTORE_LABEL)
              .height(32)
              .fontSize($r('sys.float.Body_S'))
              .backgroundColor($r('sys.color.background_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .onClick(() => {
                void this.legacyBackup(true);
              })
            Text('旧云盘')
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
