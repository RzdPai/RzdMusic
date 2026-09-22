/*
 * 同步设置（洛雪同步协议）
 *
 * 对应 listen 的 entry/src/main/ets/views/SyncSettingsView.ets。
 *
 * 界面能力与 listen 一致：
 *   启用开关 / 服务器地址输入（含历史地址列表）/ 认证码 / 本机设备名 /
 *   连接状态与同步进度 / 同步内容摘要 / 不喜欢规则的增删与清空 /
 *   服务端要求选择同步方式时弹出选择面板（SyncModeSheet）。
 *
 * 适配点（与 listen 的差异）：
 *  - 状态管理 V1 -> V2：listen 是 @StorageLink 的几个扁平 key + @Watch；这里直接观察
 *    SyncUiState（AppStorageV2 + @ObservedV2/@Trace），另外用 @Monitor 盯
 *    LocalLibrary.libraryVersion（远端数据到达 / 本地改动后重读摘要与规则）。
 *  - 同步方式的回传：listen 是 SyncManager.answerMode(mode)；这里调
 *    syncManager.resolveSyncMode(mode)，请求体本身在 SyncUiState.pendingMode 里。
 *  - 面板自绘（不依赖 bindSheet），导出 SyncSettingsPanel 供设置页内嵌；
 *    同时导出 SyncSettingsPageBuilder 作为路由页（router_map.json 的 SyncSettingsPage），
 *    两条路径共用同一份界面（宽屏内嵌 / 窄屏二级页都可用）。
 *  - 颜色 / 字号一律用系统资源（$r('sys.color.*') / $r('sys.float.*')）与主题色
 *    （ThemeState.color）：sync 这个 HAR 自己的 resources 下只有一条字符串资源，
 *    不引用别的模块的 app.* 资源（与 features/localmusic 的视图保持同一做法）。
 */

import { AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppStorageKeys, TitleBarConstants, ThemeState, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { LocalLibrary } from '../core/LocalLibrary';
import { syncManager, SyncUiState } from '../core/SyncManager';
import { SYNC_CODE_AUTH_FAILED, SYNC_CODE_MISSING_AUTH_CODE } from '../core/SyncTypes';
import { SyncModeSheet } from './SyncModeSheet';

@ComponentV2
export struct SyncSettingsPanel {
  /**
   * 内容顶部要额外避让的高度（vp）
   *
   * 作为路由页时由 SettingsDetailPage 传标题栏高度（内容区铺到标题栏下面）；
   * 内嵌在设置页宽屏右栏时传 0。
   */
  @Param topOffset: number = 0;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** 同步模块的可观察状态（改值由 SyncManager 负责） */
  @Local state: SyncUiState = syncManager.uiState();
  /** 音乐库适配层：盯它的 @Trace libraryVersion，远端数据到达后重读摘要 */
  @Local library: LocalLibrary = LocalLibrary.getInstance();
  @Local host: string = '';
  @Local authCode: string = '';
  @Local deviceName: string = '';
  @Local statusText: string = '';
  @Local summaryText: string = '';
  @Local dislikeRules: string[] = [];
  @Local hostHistory: string[] = [];
  @Local newName: string = '';
  @Local newSinger: string = '';
  @Local busy: boolean = false;
  @Local errorText: string = '';

  aboutToAppear(): void {
    this.ensureInit();
    this.host = this.state.serverUrl;
    this.deviceName = this.state.deviceName;
    this.authCode = this.state.authCode;
    this.refresh();
  }

  /** 库版本变了（远端数据到达 / 本地改动）重新读一次摘要与规则 */
  @Monitor('library.libraryVersion')
  onLibraryChanged(): void {
    this.refresh();
  }

  /** 宿主没初始化过时自己初始化（拿 UIContext 的 host context） */
  private ensureInit(): void {
    if (syncManager.isInited()) {
      return;
    }
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    syncManager.init(context);
  }

  private refresh(): void {
    this.summaryText = syncManager.summaryText();
    this.dislikeRules = syncManager.dislikeRuleList();
    this.hostHistory = this.state.hostHistory.slice();
    this.deviceName = this.state.deviceName;
    this.statusText = this.state.statusText.length > 0 ? this.state.statusText : '未连接';
  }

  // ------------------------------------------------------------ 动作

  private async toggleSync(on: boolean): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      if (on) {
        await syncManager.enable(this.host);
        // 地址会被规范化（补协议 / 去尾斜杠），把生效的那个显示回输入框
        this.host = this.state.serverUrl;
      } else {
        await syncManager.disable();
      }
    } catch (e) {
      const message: string = (e as Error).message;
      if (message === SYNC_CODE_AUTH_FAILED || message === SYNC_CODE_MISSING_AUTH_CODE) {
        this.errorText = '认证失败：请在下面填入服务端配置的认证码后点「连接」';
      } else {
        this.errorText = message.length > 0 ? message : '连接失败';
      }
    } finally {
      this.busy = false;
      this.refresh();
    }
  }

  private async connectWithCode(): Promise<void> {
    const code: string = this.authCode.trim();
    if (code.length === 0) {
      this.errorText = '请先填写认证码';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      syncManager.updateHost(this.host);
      await syncManager.connectWithCode(code);
      this.authCode = '';
    } catch (e) {
      this.errorText = `认证失败：${(e as Error).message}`;
    } finally {
      this.busy = false;
      this.refresh();
    }
  }

  private async reconnect(): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      syncManager.updateHost(this.host);
      await syncManager.reconnect();
    } catch (e) {
      this.errorText = `连接失败：${(e as Error).message}`;
    } finally {
      this.busy = false;
      this.refresh();
    }
  }

  private addDislikeRule(): void {
    const name: string = this.newName.trim();
    const singer: string = this.newSinger.trim();
    if (name.length === 0 && singer.length === 0) {
      return;
    }
    syncManager.addDislike(name, singer);
    this.newName = '';
    this.newSinger = '';
    this.refresh();
  }

  private removeDislikeRule(rule: string): void {
    syncManager.removeDislike(rule);
    this.refresh();
  }

  private clearDislikeRules(): void {
    syncManager.clearDislike();
    this.refresh();
  }

  private resolveMode(mode: string): void {
    syncManager.resolveSyncMode(mode);
  }

  // ------------------------------------------------------------ 卡片

  /** 开关 + 地址 + 认证码 + 设备名 */
  @Builder
  private infoCard() {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('启用同步')
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
            .textAlign(TextAlign.Start)
          Text(this.statusText)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(this.state.connected ? '#2FBE5B' : $r('sys.color.font_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Toggle({ type: ToggleType.Switch, isOn: this.state.enabled })
          .selectedColor(this.themeState.color)
          .enabled(!this.busy)
          .onChange((isOn: boolean) => {
            void this.toggleSync(isOn);
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 12 })

      Divider().strokeWidth(0.6).color($r('sys.color.comp_divider')).margin({ left: 14 })

      Row({ space: 10 }) {
        Text('服务端')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
        TextInput({ text: this.host, placeholder: 'http://192.168.1.10:9527' })
          .placeholderColor($r('sys.color.font_tertiary'))
          .placeholderFont({ size: 14 })
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .enabled(!this.state.enabled && !this.busy)
          .onChange((value: string) => {
            this.host = value;
          })
          .onSubmit(() => {
            syncManager.updateHost(this.host);
            this.refresh();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 14, right: 14 })

      Divider().strokeWidth(0.6).color($r('sys.color.comp_divider')).margin({ left: 14 })

      Row({ space: 10 }) {
        Text('认证码')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
        TextInput({ text: this.authCode, placeholder: '服务端配置的认证码' })
          .type(InputType.Password)
          .placeholderColor($r('sys.color.font_tertiary'))
          .placeholderFont({ size: 14 })
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .enabled(!this.busy)
          .onChange((value: string) => {
            this.authCode = value;
          })
        Button('连接')
          .fontSize($r('sys.float.Caption_M'))
          .height(32)
          .fontColor($r('sys.color.font_on_primary'))
          .backgroundColor(this.themeState.color)
          .enabled(!this.busy)
          .onClick(() => {
            void this.connectWithCode();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 14, right: 14 })

      Divider().strokeWidth(0.6).color($r('sys.color.comp_divider')).margin({ left: 14 })

      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text('本机设备名')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Start)
          TextInput({ text: this.deviceName, placeholder: '设备名' })
            .placeholderColor($r('sys.color.font_tertiary'))
            .placeholderFont({ size: 14 })
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
            .backgroundColor(Color.Transparent)
            .padding(0)
            .onChange((value: string) => {
              this.deviceName = value;
            })
            .onSubmit(() => {
              syncManager.updateDeviceName(this.deviceName);
              this.refresh();
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('重新连接')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.themeState.color)
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .borderRadius($r('sys.float.corner_radius_level12'))
          .backgroundColor($r('sys.color.background_secondary'))
          .onClick(() => {
            void this.reconnect();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor('#E53935')
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 12 })
          .textAlign(TextAlign.Start)
      }
    }
    .width('100%')
    .borderRadius($r('sys.float.corner_radius_level12'))
    .backgroundColor($r('sys.color.background_secondary'))
    .clip(true)
  }

  /** 连接 / 同步进度：开着同步就显示，同步完成停在 100% */
  @Builder
  private progressCard() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.state.stage.length > 0 ? this.state.stage :
          (this.state.connected ? '已连接，等待变化' : '未连接'))
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        if (this.state.progress > 0) {
          Text(`${this.state.progress}%`)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(this.state.progress >= 100 ? '#2FBE5B' : this.themeState.color)
        }
      }
      .width('100%')

      Progress({ value: this.state.progress, total: 100, type: ProgressType.Linear })
        .width('100%')
        .color(this.state.progress >= 100 ? '#2FBE5B' : this.themeState.color)
        .backgroundColor($r('sys.color.background_tertiary'))
        .style({ strokeWidth: 6 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius($r('sys.float.corner_radius_level12'))
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /** 同步内容摘要 + 说明 */
  @Builder
  private summaryCard() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text('同步内容')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.summaryText)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
      }
      .width('100%')

      Text('试听列表 = 本机的播放队列；收藏与歌单会与同一服务端的其它设备（洛雪桌面端 / 移动端）互通。')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .textAlign(TextAlign.Start)
      Text('注意：本地歌曲无法同步 —— 同步协议只传在线歌曲，本地音乐（从设备导入的音频）'
        + '在同步时会被直接抛弃：不会上传到服务端，也不会从其它设备同步过来'
        + '（歌单 / 收藏里的本地歌曲只留在本机）。')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius($r('sys.float.corner_radius_level12'))
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /** 最近使用过的服务器地址 */
  @Builder
  private hostHistoryCard() {
    Column() {
      Text('最近使用')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: 16, right: 16, top: 12, bottom: 6 })

      ForEach(this.hostHistory, (item: string, index: number) => {
        Column() {
          Row({ space: 10 }) {
            Text(item)
              .fontSize(14)
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
            Text('删除')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
              .padding({ left: 6, right: 6, top: 4, bottom: 4 })
              .onClick(() => {
                syncManager.removeHostHistory(item);
                this.refresh();
              })
          }
          .width('100%')
          .height(46)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.host = item;
            syncManager.updateHost(item);
            this.refresh();
          })

          if (index < this.hostHistory.length - 1) {
            Divider().strokeWidth(0.6).color($r('sys.color.comp_divider')).margin({ left: 16 })
          }
        }
        .width('100%')
      }, (item: string) => item)
    }
    .width('100%')
    .borderRadius($r('sys.float.corner_radius_level12'))
    .backgroundColor($r('sys.color.background_secondary'))
    .clip(true)
  }

  /** 不喜欢的歌曲规则（同步服务端下发 + 手动添加） */
  @Builder
  private dislikeCard() {
    Column() {
      Row({ space: 8 }) {
        Text('不喜欢的歌曲')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        if (this.dislikeRules.length > 0) {
          Text('清空')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(this.themeState.color)
            .padding({ left: 6, right: 6, top: 4, bottom: 4 })
            .onClick(() => {
              this.clearDislikeRules();
            })
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 6 })

      if (this.dislikeRules.length === 0) {
        Text('暂无规则。规则来自同步服务端，也可以在下面手动添加。')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 12 })
          .textAlign(TextAlign.Start)
      } else {
        ForEach(this.dislikeRules, (rule: string, index: number) => {
          Column() {
            Row({ space: 10 }) {
              Text(describeDislikeRule(rule))
                .fontSize(14)
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Start)
              SymbolGlyph($r('sys.symbol.trash'))
                .fontSize(17)
                .fontColor([$r('sys.color.icon_tertiary')])
                .onClick(() => {
                  this.removeDislikeRule(rule);
                })
            }
            .width('100%')
            .height(46)
            .padding({ left: 14, right: 14 })
            if (index < this.dislikeRules.length - 1) {
              Divider().strokeWidth(0.6).color($r('sys.color.comp_divider')).margin({ left: 14 })
            }
          }
          .width('100%')
        }, (rule: string, index: number) => `${index}_${rule}`)
      }

      Divider().strokeWidth(0.6).color($r('sys.color.comp_divider')).margin({ left: 14 })

      Row({ space: 8 }) {
        TextInput({ text: this.newName, placeholder: '歌名' })
          .placeholderColor($r('sys.color.font_tertiary'))
          .placeholderFont({ size: 13 })
          .fontSize(13)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.background_tertiary'))
          .layoutWeight(1)
          .onChange((value: string) => {
            this.newName = value;
          })
        TextInput({ text: this.newSinger, placeholder: '歌手' })
          .placeholderColor($r('sys.color.font_tertiary'))
          .placeholderFont({ size: 13 })
          .fontSize(13)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.background_tertiary'))
          .layoutWeight(1)
          .onChange((value: string) => {
            this.newSinger = value;
          })
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(20)
          .fontColor([this.themeState.color])
          .onClick(() => {
            this.addDislikeRule();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 12 })
    }
    .width('100%')
    .borderRadius($r('sys.float.corner_radius_level12'))
    .backgroundColor($r('sys.color.background_secondary'))
    .clip(true)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 14 }) {
          this.infoCard()

          if (this.state.enabled) {
            this.progressCard()
          }

          this.summaryCard()

          if (this.hostHistory.length > 0) {
            this.hostHistoryCard()
          }

          this.dislikeCard()

          Text('协议与洛雪官方一致：/hello + /id + /ah 认证、WebSocket 长连接、'
            + '列表与「不喜欢的歌曲」两个模块，均可在设置里选择同步方式。')
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .padding({ left: 4, right: 4 })
            .textAlign(TextAlign.Start)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: this.topOffset + 12, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      // 服务端要求选择同步方式：盖一层自绘底部面板（不用 bindSheet，内嵌时也能工作）
      if (this.state.pendingMode !== null) {
        SyncModeSheet({
          request: this.state.pendingMode,
          onPick: (mode: string): void => {
            this.resolveMode(mode);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}

/** '歌名@歌手' / '歌名' / '@歌手' 的展示形式 */
function describeDislikeRule(rule: string): string {
  const at: number = rule.indexOf('@');
  if (at < 0) {
    return `歌名：${rule}`;
  }
  const name: string = rule.substring(0, at);
  const singer: string = rule.substring(at + 1);
  if (name.length === 0) {
    return `歌手：${singer}`;
  }
  if (singer.length === 0) {
    return `歌名：${name}`;
  }
  return `${name} — ${singer}`;
}

/**
 * 路由页入口（features/sync/router_map.json 登记的 SyncSettingsPage）
 *
 * 内容区铺到标题栏下面（与 setting 模块的二级页一致），所以这里补一段顶部避让。
 */
@Builder
export function SyncSettingsPageBuilder(name: string, param: Object) {
  NavDestination() {
    SyncSettingsPanel({
      topOffset: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP
    })
  }
  .title('同步设置')
  .hideTitleBar(false)
  .backgroundColor($r('sys.color.background_primary'))
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
}
