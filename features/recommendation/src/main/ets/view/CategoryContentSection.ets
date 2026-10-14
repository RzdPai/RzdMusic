/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { LengthMetrics, uiObserver } from '@kit.ArkUI';
import {
  ArtistRouteParam,
  BreakpointType,
  RouterUrlConstants,
  StyleConstants
} from 'musicbasic';
import { ToplistRouteParam } from 'playlist';
import { RecommendChartUi, RecommendSingerUi } from '../model/RecommendUiModels';
import { MusicDataService } from '../util/MusicDataService';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';
import { HomeRankingSection } from './HomeRankingSection';
import { HomeSongListSection } from './HomeSongListSection';

/**
 * Category content list below the home category chips: featured songs (index 0),
 * singer chart (index 1) and full toplist overview (index 2). The remaining
 * categories have no data source yet and render nothing.
 */
@ComponentV2
export struct CategoryContentSection {
  /** Breakpoint env for responsive gutters. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Recommendation VM supplying category content lists. */
  @Param recommendViewModel: RecommendViewModel = new RecommendViewModel();
  /** Nav stack for routing to toplist detail on chart row tap. */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();

  private homeScrollGutterH(): number {
    return new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /** Region board entries: [display name, QQ toplist id]. */
  private readonly regionBoards: string[][] = [
    ['内地', '6'], ['港台', '5'], ['欧美', '16'], ['日韩', '17']
  ];

  /** Section title row for category lists. */
  @Builder
  private CategoryTitle(title: Resource) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.font_primary'))
      .lineHeight(24)
      .width(StyleConstants.FULL_WIDTH)
      // ★ 左右 gutter 由**行自己**给（本页的滚动容器是 List，行必须自己带 gutter：
      //   否则内容会顶到屏幕边，而且 separator/gutter 那一条透不出底色）。
      .padding({
        left: this.homeScrollGutterH(),
        right: this.homeScrollGutterH(),
        top: 16,
        bottom: 12
      })
  }

  /** Region chip grid: tap opens the region toplist detail. */
  @Builder
  private RegionList() {
    Column() {
      this.CategoryTitle($r('app.string.home_category_regions'))
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) } }) {
        ForEach(this.regionBoards, (item: string[]) => {
          Text(item[0])
            .fontSize(15)
            .fontColor($r('app.color.font_primary'))
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .borderRadius(20)
            .backgroundColor($r('app.color.background_secondary'))
            .onClick(() => {
              const param = new ToplistRouteParam();
              param.topid = item[1];
              param.listTitle = item[0];
              this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
            })
        }, (item: string[]) => 'region-' + item[1])
      }
      .width(StyleConstants.FULL_WIDTH)
      .padding({ left: this.homeScrollGutterH(), right: this.homeScrollGutterH() })
    }
    .width(StyleConstants.FULL_WIDTH)
  }

  /** One singer row: round avatar and name; tap opens the artist detail page. */
  @Builder
  private SingerRow(item: RecommendSingerUi, index: number) {
    Row({ space: 12 }) {
      Text(`${index + 1}`)
        .fontSize(13)
        .fontColor($r('app.color.font_tertiary'))
        .width(24)
        .textAlign(TextAlign.Center)
      Image(item.picUrl.length > 0 ? item.picUrl : $r('app.media.ic_avatar1'))
        .width(44)
        .height(44)
        .borderRadius(22)
        .objectFit(ImageFit.Cover)
      Column({ space: 2 }) {
        Text(item.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.sourceLabel.length > 0 ? item.sourceLabel : '热门歌手')
          .fontSize(11)
          .fontColor($r('app.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
        .height(18)
        .fontColor([$r('app.color.font_tertiary')])
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: this.homeScrollGutterH(),
      right: this.homeScrollGutterH(),
      top: 10,
      bottom: 10
    })
    .onClick(() => {
      if (item.name.length > 0) {
        const param = new ArtistRouteParam();
        param.source = 0;
        param.id = item.singerId;
        param.name = item.name;
        param.picUrl = item.picUrl;
        this.pageIndexInfos.pushPathByName(RouterUrlConstants.ARTIST_DETAIL, param);
      }
    })
  }

  /** One chart row: cover, name and chevron; tap opens toplist detail. */
  @Builder
  private ChartRow(item: RecommendChartUi) {
    Row({ space: 12 }) {
      Image(item.picUrl.length > 0 ? item.picUrl : $r('app.media.ic_avatar1'))
        .width(48)
        .height(48)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
      Text(item.name)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.font_primary'))
        .maxLines(1)
        .layoutWeight(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
        .height(18)
        .fontColor([$r('app.color.font_tertiary')])
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: this.homeScrollGutterH(),
      right: this.homeScrollGutterH(),
      top: 10,
      bottom: 10
    })
    .onClick(() => {
      if (item.boardId.length > 0) {
        void this.openBoardChart(item.source, item.boardId, item.name);
      } else if (item.topid.length > 0) {
        const param = new ToplistRouteParam();
        param.topid = item.topid;
        param.listTitle = item.name;
        // 榜单封面随路由带下去：详情页 Hero 用它，而不是第一首歌的封面
        param.listCover = item.picUrl;
        this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
      }
    })
  }

  /** Opens a board chart with the shared playlist detail page (prefetched songs). */
  private async openBoardChart(source: string, boardId: string, boardName: string): Promise<void> {
    const param = await MusicDataService.buildBoardRouteParam(source, boardId, boardName);
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
  }

  /** Renders the singer chart list when category 1 is selected. */
  @Builder
  private SingerList() {
    Column() {
      this.CategoryTitle($r('app.string.home_category_singers'))
      // ⚠️ 用户要求删掉「歌手榜数据来自酷狗音乐（…）」那行说明 —— 简洁优先，不解释数据来源。
      if (this.recommendViewModel.singerList.length === 0) {
        Text(this.recommendViewModel.categoryLoading ?
          $r('app.string.home_category_loading') : $r('app.string.home_category_empty'))
          .fontSize(13)
          .fontColor($r('app.color.font_tertiary'))
          .width(StyleConstants.FULL_WIDTH)
          .padding({ top: 16, bottom: 16 })
      } else {
        List({ space: 2 }) {
          ForEach(this.recommendViewModel.singerList, (item: RecommendSingerUi, index?: number) => {
            ListItem() {
              this.SingerRow(item, index ?? 0);
            }
          }, (item: RecommendSingerUi) => 'singer-' + item.singerId)
        }
        .width(StyleConstants.FULL_WIDTH)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
    }
    .width(StyleConstants.FULL_WIDTH)
  }

  /** Renders the full toplist overview when category 2 is selected. */
  @Builder
  private ChartList() {
    Column() {
      this.CategoryTitle($r('app.string.home_category_charts'))
      if (this.recommendViewModel.chartList.length === 0) {
        Text(this.recommendViewModel.categoryLoading ?
          $r('app.string.home_category_loading') : $r('app.string.home_category_empty'))
          .fontSize(13)
          .fontColor($r('app.color.font_tertiary'))
          .width(StyleConstants.FULL_WIDTH)
          .padding({ top: 16, bottom: 16 })
      } else {
        List({ space: 2 }) {
          ForEach(this.recommendViewModel.chartList, (item: RecommendChartUi) => {
            ListItem() {
              this.ChartRow(item);
            }
          }, (item: RecommendChartUi) => 'chart-' + item.source + '_' + item.boardId + '_' + item.topid)
        }
        .width(StyleConstants.FULL_WIDTH)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
    }
    .width(StyleConstants.FULL_WIDTH)
  }

  /**
   * Category content by selection: 0 = featured songs, 1 = singers, 2 = charts,
   * 3 = region categories; others render nothing.
   *
   * ⚠️ 必须返回**单个根节点**（官方《创建自定义组件》→「build() 函数实现规则」：
   *   「@Component 装饰的自定义组件，其 build() 函数下的根节点唯一且必要」），
   *   而且本组件是**直接挂在首页那个 List 下**的，根节点只能是 `ListItem` / `ListItemGroup`
   *   ⇒ 用**一个无 header 的 `ListItemGroup`** 包住四选一的内容。
   *   （无 header ⇒ 它不参与 `sticky(StickyStyle.Header)` 的吸顶，吸顶的只有分类 Tab 那一组。）
   *
   * ⚠️ 左右 gutter 一律由**行自己**给（标题 / 歌手行 / 榜单行 / 地区 chips 都各带
   *   `homeScrollGutterH()`）—— 本组件不再给整块加左右 padding，否则会双份。
   */
  build() {
    ListItemGroup() {
      if (this.recommendViewModel.selectedCategoryIndex === 0) {
        // 「精选推荐」：竖排歌曲列表，和「每日30首」同款行（标题由本 group 自己出）
        HomeSongListSection({
          dataSource: this.recommendViewModel.privateSongDataSource,
          songCount: this.recommendViewModel.privateSongDisplayList.length,
          keyPrefix: 'cat-featured',
          showTitle: false,
          recommendViewModel: this.recommendViewModel
        })
      } else if (this.recommendViewModel.selectedCategoryIndex === 1) {
        this.SingerList()
      } else if (this.recommendViewModel.selectedCategoryIndex === 2) {
        HomeRankingSection({ recommendViewModel: this.recommendViewModel, embedded: true })
      } else if (this.recommendViewModel.selectedCategoryIndex === 3) {
        this.RegionList()
      }
    }
  }
}
