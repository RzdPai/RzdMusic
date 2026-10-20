import { Logger, SearchGlassModifier } from 'musicbasic';

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
        Stack() {
          Search({ placeholder: '艺人、歌曲或专辑' })
            .height(SEARCH_FIELD_H)
            .backgroundColor(Color.Transparent)
            // ★ 目标页那端必须用**同一个**占位色（官方示例两端都是 sys.color.mask_secondary）：
            //   两端不同色时，形变中途会看到"白字突然变灰"，很割裂。
            .placeholderColor($r('sys.color.mask_secondary'))
            .placeholderFont({ size: 16 })
            .textFont({ size: 16 })
            .fontColor($r('sys.color.font_primary'))
            .caretStyle({ color: $r('sys.color.font_primary') })
            .searchIcon({ size: 16, color: $r('sys.color.mask_secondary') })
            .cancelButton({
              style: CancelButtonStyle.INPUT,
              icon: { size: 17, color: $r('sys.color.mask_secondary') }
            })
            .width('100%')
            .focusable(false)
            .focusOnTouch(false)
            .defaultFocus(false)
            .geometryTransition(SEARCH_GEO_ID, { follow: true })
            .onAreaChange((_oldArea: Area, area: Area): void => {
              Logger.info('RzdSearchMorph',
                `source rect x=${area.globalPosition.x} y=${area.globalPosition.y} w=${area.width} h=${area.height}`);
            })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Up) {
                Logger.info('RzdSearchHome', 'tap-open');
                this.onOpenSearch();
              }
            })
        }
        .layoutWeight(1)
        .attributeModifier(new SearchGlassModifier())

        Stack() {
          SymbolGlyph($r('sys.symbol.identify_song'))
            .fontSize('24fp')
            .fontColor([$r('sys.color.font_primary')])
        }
        .width(SEARCH_FIELD_H)
        .attributeModifier(new SearchGlassModifier())
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
