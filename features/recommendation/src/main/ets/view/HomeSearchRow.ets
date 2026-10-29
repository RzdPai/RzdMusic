import { appendPlayLog, Logger, SearchGlassModifier, immersiveMedium } from 'musicbasic';

/** 一镜到底诊断：同时写 HiLog 与**应用内运行日志**（设置→运行日志，无设备时只能靠它取证）。 */
function morphLog(message: string): void {
  appendPlayLog('[RzdSearchMorph] ' + message);
  Logger.info('RzdSearchMorph', message);
}

const SEARCH_FIELD_H: number = 40;
// wujie126.pa 113552–113587 (Tokens export slot 0x10).
const FIELD_GAP: number = 16;
const RECOGNIZE_GAP: number = 10;
const SEARCH_GEO_ID: string = 'wanting_search_field';

@ComponentV2
export struct HomeSearchRow {
  @Param gutter: number = 16;
  @Event onOpenSearch: () => void = () => {};
  @Event onOpenRecognize: () => void = () => {};

  build() {
    Column() {
      Row({ space: RECOGNIZE_GAP }) {
        // ★★ 2026-10-20：**不要**把搜索框包在"玻璃 Stack"里。
        //   一镜到底做形变的是挂 `geometryTransition` 的那个节点；玻璃如果挂在外面那层 Stack 上，
        //   飞起来就只有框里的文字、框本身不动（甲方原话："只有搜索框里的文字有动画"）。
        //   官方示例就是把背景直接挂在 `Search` 上（`.backgroundColor('#0D000000')`），这里照抄：
        //   背景/圆角/高度全部落在 `Search` 自己身上，两端同一套。
        Search({ placeholder: '艺人、歌曲或专辑' })
          .height(SEARCH_FIELD_H)
          // ★ 2026-10-24（甲方：「搜索框现在半透明的不是很好看」）：改**实底卡片背板**，
          //   与搜索页那端（`OnlineSearchPage.SearchInputBar`）**逐字同一套**：
          //   `card_background` + 0.5vp 描边。两端不同色会在长镜头中途看出颜色跳变。
          // 与搜索页那端保持同一套：光感 + 半透明底（否则形变途中颜色会跳）
          .systemMaterial(immersiveMedium())
          .backgroundColor('#33FFFFFF')
          .borderRadius(SEARCH_FIELD_H / 2)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .clip(true)
          // 两端占位色必须同一个 token：不同色时形变中途会看到"白字突然变灰"。
          .placeholderColor($r('sys.color.font_secondary'))
          .placeholderFont({ size: 16 })
          .textFont({ size: 16 })
          .fontColor($r('sys.color.font_primary'))
          .caretStyle({ color: $r('sys.color.font_primary') })
          .searchIcon({ size: 16, color: $r('sys.color.font_secondary') })
          .cancelButton({
            style: CancelButtonStyle.INPUT,
            icon: { size: 17, color: $r('sys.color.font_secondary') }
          })
          .layoutWeight(1)
          .focusable(false)
          .focusOnTouch(false)
          .defaultFocus(false)
          .geometryTransition(SEARCH_GEO_ID, { follow: true })
          // 诊断用：源节点在 push/pop 时是"保留"还是"重建"——退出没动画的关键判据。
          .onAppear((): void => {
            morphLog('source appear');
          })
          .onDisAppear((): void => {
            morphLog('source disappear');
          })
          .onAreaChange((_oldArea: Area, area: Area): void => {
            morphLog(`source rect x=${area.globalPosition.x} y=${area.globalPosition.y} ` +
              `w=${area.width} h=${area.height}`);
          })
          .onTouch((event: TouchEvent): void => {
            if (event.type === TouchType.Up) {
              morphLog('source tap-open');
              this.onOpenSearch();
            }
          })

        // 识别歌曲：用 Button 作宿主（A 档），页面 body 里也能渲染沉浸材质
        Button() {
          SymbolGlyph($r('sys.symbol.identify_song'))
            .fontSize('24fp')
            .fontColor([$r('sys.color.font_primary')])
        }
        .type(ButtonType.Normal)
        .width(SEARCH_FIELD_H)
        .height(SEARCH_FIELD_H)
        .borderRadius(SEARCH_FIELD_H / 2)
        .systemMaterial(immersiveMedium())
        .backgroundColor('#33FFFFFF')
        .onClick((): void => {
          this.onOpenRecognize();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: FIELD_GAP })
    }
    .width('100%')
    .padding({ left: this.gutter, right: this.gutter })
    .onAreaChange((_oldArea: Area, area: Area): void => {
      Logger.info('RzdSearchHome',
        `row-area x=${area.globalPosition.x} y=${area.globalPosition.y} w=${area.width} h=${area.height}`);
    })
  }
}
