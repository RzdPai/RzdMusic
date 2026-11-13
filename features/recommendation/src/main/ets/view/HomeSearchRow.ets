import { AppStorageV2 } from '@kit.ArkUI';
import { AmbientState, AppStorageKeys, appendPlayLog, Logger, immersiveFromLevel } from 'musicbasic';

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
  /**
   * ★ 2026-11-02：光感强度档位（与标题栏 `buildTitleMaterial` 同一张表）。
   * 首页这端与搜索页那端必须**同一档**，否则一镜到底形变途中能看出材质厚度跳变。
   */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;

  build() {
    Column() {
      // ★★ 2026-11-04（甲方：「最顶部时…改成整个搜索框，听歌识曲放进标题」）：
      //   这一行**只留搜索框**（整行铺满），识别歌曲已移到 HDS 标题栏的菜单里
      //   （见 `RecommendPage.getTitleBar()`）。`onOpenRecognize` 保留参数以免动调用方，
      //   但本行不再渲染识别按钮。
      Row() {
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
          // ★ 2026-11-13（参考 @tangs/components 调优）：底色改深浅色自适应资源 ——
          //   浅色白纱 #33FFFFFF、深色黑纱 #33000000（该库 light `#3fff` / dark `#3000` 的思路）。
          //   原来深色也写死 20% 白 ⇒ 深色下玻璃发灰发白。两端同一资源，形变中途仍无跳变。
          .systemMaterial(immersiveFromLevel(this.ambientState.level))
          .backgroundColor($r('app.color.immersive_glass_overlay'))
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

        // 识别歌曲按钮已移到标题栏菜单（2026-11-04 甲方要求）
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
