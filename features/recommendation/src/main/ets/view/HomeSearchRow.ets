import { appendPlayLog, Logger, SearchGlassModifier, immersiveMedium } from 'musicbasic';

/** 涓€闀滃埌搴曡瘖鏂細鍚屾椂鍐?HiLog 涓?*搴旂敤鍐呰繍琛屾棩蹇?*锛堣缃啋杩愯鏃ュ織锛屾棤璁惧鏃跺彧鑳介潬瀹冨彇璇侊級銆?*/
function morphLog(message: string): void {
  appendPlayLog('[RzdSearchMorph] ' + message);
  Logger.info('RzdSearchMorph', message);
}

const SEARCH_FIELD_H: number = 40;
// wujie126.pa 113552鈥?13587 (Tokens export slot 0x10).
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
        // 鈽呪槄 2026-10-20锛?*涓嶈**鎶婃悳绱㈡鍖呭湪"鐜荤拑 Stack"閲屻€?
        //   涓€闀滃埌搴曞仛褰㈠彉鐨勬槸鎸?`geometryTransition` 鐨勯偅涓妭鐐癸紱鐜荤拑濡傛灉鎸傚湪澶栭潰閭ｅ眰 Stack 涓婏紝
        //   椋炶捣鏉ュ氨鍙湁妗嗛噷鐨勬枃瀛椼€佹鏈韩涓嶅姩锛堢敳鏂瑰師璇濓細"鍙湁鎼滅储妗嗛噷鐨勬枃瀛楁湁鍔ㄧ敾"锛夈€?
        //   瀹樻柟绀轰緥灏辨槸鎶婅儗鏅洿鎺ユ寕鍦?`Search` 涓婏紙`.backgroundColor('#0D000000')`锛夛紝杩欓噷鐓ф妱锛?
        //   鑳屾櫙/鍦嗚/楂樺害鍏ㄩ儴钀藉湪 `Search` 鑷繁韬笂锛屼袱绔悓涓€濂椼€?
        Search({ placeholder: '鑹轰汉銆佹瓕鏇叉垨涓撹緫' })
          .height(SEARCH_FIELD_H)
          // 鈽?2026-10-24锛堢敳鏂癸細銆屾悳绱㈡鐜板湪鍗婇€忔槑鐨勪笉鏄緢濂界湅銆嶏級锛氭敼**瀹炲簳鍗＄墖鑳屾澘**锛?
          //   涓庢悳绱㈤〉閭ｇ锛坄OnlineSearchPage.SearchInputBar`锛?*閫愬瓧鍚屼竴濂?*锛?
          //   `card_background` + 0.5vp 鎻忚竟銆備袱绔笉鍚岃壊浼氬湪闀块暅澶翠腑閫旂湅鍑洪鑹茶烦鍙樸€?
          .systemMaterial(immersiveMedium())
          .backgroundColor('#33FFFFFF')
          .borderRadius(SEARCH_FIELD_H / 2)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .clip(true)
          // 涓ょ鍗犱綅鑹插繀椤诲悓涓€涓?token锛氫笉鍚岃壊鏃跺舰鍙樹腑閫斾細鐪嬪埌"鐧藉瓧绐佺劧鍙樼伆"銆?
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
          // 璇婃柇鐢細婧愯妭鐐瑰湪 push/pop 鏃舵槸"淇濈暀"杩樻槸"閲嶅缓"鈥斺€旈€€鍑烘病鍔ㄧ敾鐨勫叧閿垽鎹€?
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

        // ★ 识别歌曲这颗也换成 Button 宿主（A 档，页面 body 里也能渲染材质）
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
