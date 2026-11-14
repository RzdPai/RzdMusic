/*
 * 同步方式选择面板（服务端要求选择时弹出）
 *
 * 对应 listen 的 entry/src/main/ets/views/SyncModeSheet.ets（SyncModeContent）。
 *
 * 适配点：
 *  - listen 的宿主用 bindSheet 弹它、参数是 kind / serverName；RzdMusic 里请求体已经整包放在
 *    SyncUiState.pendingMode（SyncModeRequest：kind / serverName / title / options），
 *    所以这里直接吃请求体，不再自己拼标题。
 *  - listen 用 ui/Icons 里的自绘图标；RzdMusic 的 sync 模块只有系统资源可用，
 *    所以只保留文字 + 系统 SymbolGlyph（chevron_right），不引入 listen 的图标表。
 *  - 面板自绘（Stack 遮罩 + 底部卡片），不依赖 bindSheet：同一套界面既能被设置页内嵌面板使用，
 *    也能在宽屏内嵌布局里工作（SettingPage 的宽屏分支不会走弹窗）。
 *  - 选项来自 request.options（SyncManager 已经把 LIST_MODE_OPTIONS / DISLIKE_MODE_OPTIONS
 *    和末尾的「取消同步」拼好了），这里把取消项单独拿出来放最下面（与 listen 的版式一致），
 *    选完统一回调 onPick，由宿主调 syncManager.resolveSyncMode(choice)。
 */

import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys, ThemeState } from 'musicbasic';
import { SyncModeRequest } from '../core/SyncManager';
import { SyncModeOption, SYNC_MODE_CANCEL } from '../core/SyncTypes';

/** 只保留可选项（取消项单独渲染） */
function pickOptions(request: SyncModeRequest): SyncModeOption[] {
  const out: SyncModeOption[] = [];
  for (const option of request.options) {
    if (option.value !== SYNC_MODE_CANCEL.value) {
      out.push(option);
    }
  }
  return out;
}

@ComponentV2
export struct SyncModeSheet {
  /** 服务端发来的选择请求（非 null 才渲染面板） */
  @Param request: SyncModeRequest | null = null;
  /** 用户选完回传（'cancel' 或空串都表示取消） */
  @Param onPick: (mode: string) => void = (): void => {};
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local options: SyncModeOption[] = [];
  @Local title: string = '';
  @Local tip: string = '';

  aboutToAppear(): void {
    this.applyRequest();
  }

  /** 请求换了（同一个实例继续用）时同步刷新文案与选项 */
  @Monitor('request')
  onRequestChanged(): void {
    this.applyRequest();
  }

  private applyRequest(): void {
    const request: SyncModeRequest | null = this.request;
    if (request === null) {
      this.options = [];
      this.title = '';
      this.tip = '';
      return;
    }
    this.options = pickOptions(request);
    this.title = request.title;
    this.tip = request.kind === 'dislike'
      ? '合并会去掉重复规则；覆盖会用一方的规则替换另一方。'
      : '合并会把两边的歌单合并去重；覆盖会用一方的歌单替换 ID 相同的歌单。';
  }

  @Builder
  private optionRow(option: SyncModeOption) {
    Column() {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text(option.title)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
            .textAlign(TextAlign.Start)
          Text(option.desc)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(17)
          .fontColor([$r('sys.color.icon_tertiary')])
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 11, bottom: 11 })
      .onClick(() => {
        this.onPick(option.value);
      })

      Divider()
        .strokeWidth(0.6)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 16 })
    }
    .width('100%')
  }

  build() {
    if (this.request !== null) {
      Stack({ alignContent: Alignment.Bottom }) {
        // 遮罩：点空白处按「取消同步」处理，不让服务端一直等
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.onPick(SYNC_MODE_CANCEL.value);
          })

        Column() {
          Text(this.title)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 4 })
            .textAlign(TextAlign.Start)

          Text(this.tip)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 8 })
            .textAlign(TextAlign.Start)

          List() {
            ForEach(this.options, (option: SyncModeOption) => {
              ListItem() {
                this.optionRow(option)
              }
            }, (option: SyncModeOption) => option.value)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          Divider()
            .strokeWidth(0.6)
            .color($r('sys.color.comp_divider'))
            .margin({ left: 16 })

          Row() {
            Text(SYNC_MODE_CANCEL.title)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(this.themeState.color)
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .onClick(() => {
            this.onPick(SYNC_MODE_CANCEL.value);
          })
        }
        .width('100%')
        .constraintSize({ maxHeight: '75%' })
        .borderRadius({ topLeft: $r('sys.float.corner_radius_level16'),
          topRight: $r('sys.float.corner_radius_level16') })
        .backgroundColor($r('sys.color.background_primary'))
        .clip(true)
      }
      .width('100%')
      .height('100%')
    }
  }
}
