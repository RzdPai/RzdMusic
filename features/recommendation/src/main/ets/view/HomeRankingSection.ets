import { uiObserver } from '@kit.ArkUI';
import {
  BreakpointType,
  RouterUrlConstants,
  StyleConstants
} from 'musicbasic';
import { RecommendBoardUi } from '../model/RecommendUiModels';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';
import { MusicDataService } from '../util/MusicDataService';

@ComponentV2
export struct HomeRankingSection {
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Param recommendViewModel: RecommendViewModel = new RecommendViewModel();
  /** True when hosted inside the category content (parent already applies the gutter). */
  @Param embedded: boolean = false;
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  private hotBoardCount: number = 12;

  private homeScrollGutterH(): number {
    return new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint);
  }

  private hotBoards(): RecommendBoardUi[] {
    if (this.recommendViewModel.rankingBoards.length <= this.hotBoardCount) {
      return this.recommendViewModel.rankingBoards;
    }
    return this.recommendViewModel.rankingBoards.slice(0, this.hotBoardCount);
  }

  @Builder
  private SectionHeader() {
    Row() {
      Text($r('app.string.home_ranking_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.font_primary'))
      Blank()
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ top: 16, bottom: 10 })
  }

  @Builder
  private SourceChip(name: string, index: number) {
    Text(name)
      .fontSize(13)
      .fontWeight(this.recommendViewModel.rankingSourceIndex === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.recommendViewModel.rankingSourceIndex === index ?
        $r('app.color.chip_selected_text') : $r('app.color.chip_unselected_text'))
      .padding({ left: 16, right: 16, top: 7, bottom: 7 })
      .borderRadius(18)
      .backgroundColor(this.recommendViewModel.rankingSourceIndex === index ?
        $r('app.color.chip_selected_background') : $r('app.color.chip_unselected_background'))
      .onClick(() => {
        this.recommendViewModel.selectRankingSource(index);
      })
  }

  @Builder
  private SourceBar() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(MusicDataService.sourceList, (item: string, index?: number) => {
          this.SourceChip(MusicDataService.sourceName(item), index ?? 0)
        }, (item: string) => `rank-src-${item}`)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width(StyleConstants.FULL_WIDTH)
  }

  /** Opens a board with the shared playlist detail page (prefetched songs). */
  private async openBoard(source: string, boardId: string, boardName: string): Promise<void> {
    const param = await MusicDataService.buildBoardRouteParam(source, boardId, boardName);
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
  }

  @Builder
  private BoardRow(item: RecommendBoardUi, index: number) {
    Row({ space: 10 }) {
      Text(`${index + 1}`)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(index < 3 ? $r('sys.color.warning') : $r('app.color.font_tertiary'))
        .width(24)
        .textAlign(TextAlign.Center)
      Image(item.cover.length > 0 ? item.cover : $r('app.media.ic_avatar1'))
        .width(40)
        .height(40)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
        .backgroundColor($r('sys.color.background_tertiary'))
      Text(item.name)
        .fontSize(14)
        .fontColor($r('app.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .height(14)
        .fontColor([$r('app.color.font_tertiary')])
    }
    .width('100%')
    .padding({ left: 12, right: 8, top: 12, bottom: 12 })
    .borderRadius(12)
    .backgroundColor($r('app.color.background_secondary'))
    .onClick(() => {
      void this.openBoard(item.source, item.id, item.name);
    })
  }

  build() {
    Column() {
      this.SectionHeader()
      this.SourceBar()
      Column({ space: 8 }) {
        ForEach(this.hotBoards(), (item: RecommendBoardUi, index?: number) => {
          this.BoardRow(item, index ?? 0)
        },
        // ★ key 里必须带上 cover。
        // 榜单列表是**两次**赋值：先给不带封面的列表，异步拿到封面后再整体替换。
        // ForEach 只在 key 变化时才重建子节点；key 只用 source_id 时两次完全相同
        // → 第二次带封面的赋值不会重绘 → 封面看起来"加载不出来"；
        // 切平台时 id 变了才刷新，这就是"来回切平台才能加载出来"的原因。
        (item: RecommendBoardUi) => `rank-${item.source}_${item.id}_${item.cover}`)
      }
      .width(StyleConstants.FULL_WIDTH)
      .margin({ top: 10 })
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: this.embedded ? 0 : this.homeScrollGutterH(),
      right: this.embedded ? 0 : this.homeScrollGutterH(),
      bottom: this.embedded ? 0 : 16
    })
  }
}
