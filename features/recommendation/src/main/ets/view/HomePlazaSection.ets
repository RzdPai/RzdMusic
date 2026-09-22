import { uiObserver } from '@kit.ArkUI';
import {
  BreakpointType,
  RouterUrlConstants,
  StyleConstants
} from 'musicbasic';
import { ToplistRouteParam } from 'playlist';
import { RecommendPlazaPlaylistUi } from '../model/RecommendUiModels';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';
import { CategoryGroup, CategoryOption, MusicDataService, SortOption } from '../util/MusicDataService';

@ComponentV2
export struct HomePlazaSection {
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Param recommendViewModel: RecommendViewModel = new RecommendViewModel();
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  @Local categoryOpen: boolean = false;

  private homeScrollGutterH(): number {
    return new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint);
  }

  private playlistMeta(item: RecommendPlazaPlaylistUi): string {
    const values: string[] = [];
    if (item.count.length > 0 && item.source !== 'kg') {
      values.push(`${item.count}首`);
    }
    if (item.listenCount.length > 0) {
      values.push(`${item.listenCount}次播放`);
    }
    return values.join(' · ');
  }

  @Builder
  private SectionHeader() {
    Row() {
      Text($r('app.string.home_plaza_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.font_primary'))
      Blank()
      if (this.recommendViewModel.plazaLoading) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color($r('app.color.font_tertiary'))
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ top: 16, bottom: 10 })
  }

  @Builder
  private SourceChip(name: string, index: number) {
    Text(name)
      .fontSize(13)
      .fontWeight(this.recommendViewModel.plazaSourceIndex === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.recommendViewModel.plazaSourceIndex === index ?
        $r('app.color.chip_selected_text') : $r('app.color.chip_unselected_text'))
      .padding({ left: 16, right: 16, top: 7, bottom: 7 })
      .borderRadius(18)
      .backgroundColor(this.recommendViewModel.plazaSourceIndex === index ?
        $r('app.color.chip_selected_background') : $r('app.color.chip_unselected_background'))
      .onClick(() => {
        void this.recommendViewModel.selectPlazaSource(index);
      })
  }

  @Builder
  private SourceBar() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(MusicDataService.sourceList, (item: string, index?: number) => {
          this.SourceChip(MusicDataService.sourceName(item), index ?? 0)
        }, (item: string) => `plaza-src-${item}`)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width(StyleConstants.FULL_WIDTH)
  }

  @Builder
  private FilterBar() {
    Flex({ wrap: FlexWrap.Wrap }) {
      Row({ space: 4 }) {
        Text(this.recommendViewModel.plazaCategoryName.length > 0 ?
          this.recommendViewModel.plazaCategoryName : $r('app.string.home_plaza_default'))
          .fontSize(13)
          .fontColor($r('app.color.font_primary'))
        SymbolGlyph(this.categoryOpen ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
          .fontSize(14)
          .height(14)
          .fontColor([$r('sys.color.font_secondary')])
      }
      .padding({ left: 14, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .backgroundColor($r('app.color.background_secondary'))
      .margin({ right: 8, bottom: 6 })
      .onClick(() => {
        this.categoryOpen = !this.categoryOpen;
      })

      ForEach(MusicDataService.sortOptions(this.recommendViewModel.plazaSourceCode()),
        (item: SortOption, index?: number) => {
          Text(item.name)
            .fontSize(13)
            .fontColor(this.recommendViewModel.plazaSortIndex === index ?
              $r('app.color.chip_selected_text') : $r('app.color.font_primary'))
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .borderRadius(16)
            .backgroundColor(this.recommendViewModel.plazaSortIndex === index ?
              $r('app.color.chip_selected_background') : $r('app.color.background_secondary'))
            .margin({ right: 8, bottom: 6 })
            .onClick(() => {
              void this.recommendViewModel.selectPlazaSort(index ?? 0);
            })
        }, (item: SortOption) => `plaza-sort-${item.id}`)
    }
    .width(StyleConstants.FULL_WIDTH)
    .margin({ top: 10, bottom: 10 })
  }

  @Builder
  private PlaylistCard(item: RecommendPlazaPlaylistUi) {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(item.image.length > 0 ? item.image : $r('app.media.ic_avatar1'))
          .width('100%')
          .aspectRatio(1)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.ic_avatar1'))
        if (item.listenCount.length > 0) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
              .fontSize(14)
              .height(14)
              .fontColor([$r('app.color.card_play_count_icon')])
            Text(item.listenCount)
              .fontSize(10)
              .fontColor($r('app.color.card_play_count_icon'))
              .maxLines(1)
          }
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
        }
      }
      .width('100%')

      Text(item.name)
        .fontSize(13)
        .lineHeight(17)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 2 })
        .width('100%')

      if (this.playlistMeta(item).length > 0 || item.author.length > 0) {
        Text(item.author.length > 0 && this.playlistMeta(item).length > 0 ?
          `${item.author} · ${this.playlistMeta(item)}` :
          (item.author.length > 0 ? item.author : this.playlistMeta(item)))
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 1 })
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      if (item.id.length === 0) {
        return;
      }
      const param = new ToplistRouteParam();
      param.sectionType = 'onlinePlaylist';
      param.onlineSource = item.source;
      param.playlistId = item.id;
      param.listTitle = item.name;
      // 在线歌单封面随路由带下去：详情页 Hero 用它，而不是第一首歌的封面
      param.listCover = item.image;
      this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
    })
  }

  /** Column count for the plaza grid: 2 on phones, more on tablets / desktop. */
  private plazaColumnCount(): number {
    switch (this.breakpointEnv.widthBreakpoint) {
      case WidthBreakpoint.WIDTH_MD:
        return 3;
      case WidthBreakpoint.WIDTH_LG:
        return 4;
      case WidthBreakpoint.WIDTH_XL:
        return 5;
      default:
        return 2;
    }
  }

  private plazaColumnIndexes(): number[] {
    const count: number = this.plazaColumnCount();
    const indexes: number[] = [];
    for (let i: number = 0; i < count; i++) {
      indexes.push(i);
    }
    return indexes;
  }

  private plazaColumnItems(column: number): RecommendPlazaPlaylistUi[] {
    const count: number = this.plazaColumnCount();
    const list: RecommendPlazaPlaylistUi[] = [];
    for (let i: number = column; i < this.recommendViewModel.plazaPlaylists.length; i += count) {
      list.push(this.recommendViewModel.plazaPlaylists[i]);
    }
    return list;
  }

  @Builder
  @Builder
  private PlaylistGrid() {
    Row({ space: 12 }) {
      ForEach(this.plazaColumnIndexes(), (column: number) => {
        Column({ space: 12 }) {
          ForEach(this.plazaColumnItems(column), (item: RecommendPlazaPlaylistUi) => {
            this.PlaylistCard(item)
          }, (item: RecommendPlazaPlaylistUi) => `plaza-${column}-${item.source}_${item.id}`)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }, (column: number) => `plaza-col-${column}-${this.plazaColumnCount()}`)
    }
    .width(StyleConstants.FULL_WIDTH)
  }

  @Builder
  private CategorySheet() {
    Column() {
      Row() {
        Text($r('app.string.home_plaza_choose_category'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_primary'))
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(20)
          .height(20)
          .fontColor([$r('sys.color.font_secondary')])
          .onClick(() => {
            this.categoryOpen = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 8 })

      Scroll() {
        Column() {
          Row() {
            Text($r('app.string.home_plaza_default'))
              .fontSize(14)
              .fontColor(this.recommendViewModel.plazaCategoryId.length === 0 ?
                $r('app.color.chip_selected_text') : $r('app.color.font_primary'))
              .padding({ left: 16, right: 16, top: 7, bottom: 7 })
              .borderRadius(18)
              .backgroundColor(this.recommendViewModel.plazaCategoryId.length === 0 ?
                $r('app.color.chip_selected_background') : $r('app.color.background_secondary'))
              .onClick(() => {
                void this.recommendViewModel.selectPlazaCategory('', '');
                this.categoryOpen = false;
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .margin({ bottom: 8 })

          ForEach(this.recommendViewModel.plazaCategoryGroups, (group: CategoryGroup) => {
            Column() {
              Text(group.title)
                .fontSize(14)
                .fontColor($r('sys.color.font_secondary'))
                .alignSelf(ItemAlign.Start)
                .margin({ top: 12, bottom: 8 })
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(group.items, (item: CategoryOption) => {
                  Text(item.name)
                    .fontSize(14)
                    .fontColor(item.id === this.recommendViewModel.plazaCategoryId ?
                      $r('app.color.chip_selected_text') : $r('app.color.font_primary'))
                    .padding({ left: 16, right: 16, top: 7, bottom: 7 })
                    .borderRadius(18)
                    .backgroundColor(item.id === this.recommendViewModel.plazaCategoryId ?
                      $r('app.color.chip_selected_background') : $r('app.color.background_secondary'))
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => {
                      void this.recommendViewModel.selectPlazaCategory(item.id, item.name);
                      this.categoryOpen = false;
                    })
                }, (item: CategoryOption) => `cat-${group.title}-${item.id}`)
              }
              .width('100%')
            }
            .width('100%')
          }, (group: CategoryGroup) => `plaza-group-${group.title}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .scrollBar(BarState.Auto)
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private PlazaBody() {
    if (this.recommendViewModel.plazaLoading) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color($r('app.color.font_tertiary'))
        Text($r('app.string.home_category_loading'))
          .fontSize(13)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width(StyleConstants.FULL_WIDTH)
      .padding({ top: 24, bottom: 24 })
      .justifyContent(FlexAlign.Center)
    } else if (this.recommendViewModel.plazaErrorText.length > 0 &&
      this.recommendViewModel.plazaPlaylists.length === 0) {
      Column({ space: 8 }) {
        Text(this.recommendViewModel.plazaErrorText)
          .fontSize(13)
          .fontColor($r('sys.color.font_tertiary'))
          .textAlign(TextAlign.Center)
        Text($r('app.string.home_guest_retry'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_primary'))
      }
      .width(StyleConstants.FULL_WIDTH)
      .padding({ top: 24, bottom: 24 })
      .onClick(() => {
        this.recommendViewModel.retryGuestSections();
      })
    } else {
      this.PlaylistGrid()
    }
  }

  @Builder
  private PlazaFooter() {
    if (!this.recommendViewModel.plazaLoading &&
      this.recommendViewModel.plazaPlaylists.length > 0) {
      if (this.recommendViewModel.plazaHasNext) {
        Row({ space: 6 }) {
          if (this.recommendViewModel.plazaLoadingMore) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color($r('app.color.font_tertiary'))
          }
          Text(this.recommendViewModel.plazaLoadingMore ?
            $r('app.string.home_category_loading') : $r('app.string.home_plaza_load_more'))
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
        }
        .justifyContent(FlexAlign.Center)
        .padding({ left: 20, right: 20, top: 8, bottom: 8 })
        .borderRadius(20)
        .backgroundColor($r('app.color.background_secondary'))
        .margin({ top: 12 })
        .onClick(() => {
          this.recommendViewModel.loadMorePlazaPlaylists();
        })
      } else {
        Text($r('app.string.home_plaza_no_more'))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .margin({ top: 12 })
      }
    }
  }

  build() {
    Column() {
      this.SectionHeader()
      this.SourceBar()
      this.FilterBar()
      this.PlazaBody()
      this.PlazaFooter()
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: this.homeScrollGutterH(),
      right: this.homeScrollGutterH(),
      bottom: 8
    })
    .bindSheet($$this.categoryOpen, this.CategorySheet(), {
      height: 560,
      showClose: false,
      dragBar: true
    })
  }
}
