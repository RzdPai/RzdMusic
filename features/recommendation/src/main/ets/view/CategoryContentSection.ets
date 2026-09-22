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
  areaLengthToVp,
  ArtistRouteParam,
  BreakpointType,
  getWindowInfoState,
  RouterUrlConstants,
  StyleConstants,
  WindowInfo
} from 'musicbasic';
import { ToplistRouteParam, SongMoreMenu } from 'playlist';
import { RecommendChartUi, RecommendPrivateSongUi, RecommendSingerUi } from '../model/RecommendUiModels';
import { MusicDataService } from '../util/MusicDataService';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';
import { HomeRankingSection } from './HomeRankingSection';

/**
 * Category content list below the home category chips: featured songs (index 0),
 * singer chart (index 1) and full toplist overview (index 2). The remaining
 * categories have no data source yet and render nothing.
 */
@ComponentV2
export struct CategoryContentSection {
  /** Breakpoint env for responsive gutters. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** 窗口信息：首帧还没量到宽度时用它兜底算内容宽度。 */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /**
   * 内容区实测宽度（vp），= 「原本一行占满的宽度」。
   *
   * 由 build() 里那条不可见的量宽条（`width('100%')` 的空节点）写入：
   * 它没有 padding、宽度只由父容器的内容区决定，所以是稳定的测量源。
   * 用实测值而不是写死断点表，折叠屏 / PC 浮窗 / 侧边栏这些情况才都算得对。
   */
  @Local featuredContentVp: number = 0;
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
      .padding({ top: 16, bottom: 12 })
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
        Text('酷狗歌手榜')
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
    .padding({ top: 10, bottom: 10 })
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
    .padding({ top: 10, bottom: 10 })
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

  /** 「精选推荐」固定 3 行 —— 行数写死，列数按歌曲数量算。 */
  private static readonly FEATURED_ROWS: number = 3;
  /** 「精选推荐」列间距 / 行间距（vp）。 */
  private static readonly FEATURED_COL_GAP: number = 12;
  private static readonly FEATURED_ROW_GAP: number = 10;

  /** 「精选推荐」单元格宽度 = 原本整行宽度 × 这个系数（0.9 = 收窄 10%）。 */
  private static readonly FEATURED_WIDTH_SCALE: number = 0.9;

  /**
   * 「精选推荐」**一行**的宽度（vp）。
   *
   * 版式不变（封面在左、歌名/歌手在中间、更多按钮在右），宽度定成
   * **「原本占满一行」的 90%**，这样一行里能并排放多列。
   * @returns 单元格宽度（vp）。
   */
  private featuredCellWidth(): number {
    return this.featuredContentWidthVp() * CategoryContentSection.FEATURED_WIDTH_SCALE;
  }

  /** @returns 内容区宽度（vp）：优先用实测值，首帧还没量到时用窗口宽兜底。 */
  private featuredContentWidthVp(): number {
    return this.featuredContentVp > 0 ? this.featuredContentVp : this.fallbackContentWidthVp();
  }

  /** @returns 一列的步距（vp）= 单元格宽度 + 列间距。 */
  private featuredColPitch(): number {
    return this.featuredCellWidth() + CategoryContentSection.FEATURED_COL_GAP;
  }

  /**
   * @returns 横向滚动的**分页点**（vp，单调递增）。
   *
   * ⚠️ 这里踩过一次坑，务必看清官方文档的语义（ts-container-scroll / snapPagination）：
   *   - 传**单个** `Dimension` 时，它表示"**每页的大小**"，系统按该大小分页；
   *   - 传 **`Array<Dimension>`** 时，每个元素表示一个"**分页点**"（即最终停靠的滚动偏移），
   *     取值必须在 `[0, 可滑动距离]` 内、且**必须单调递增**。
   *
   * 之前传的是 `[一列步距]` —— 那只有**一个**分页点，于是全部能停的位置只有
   * 「开头 / 一列 / 末尾」三个：第一列→第二列正常，第二列再往后一松手就弹回第二列，
   * 只有使劲甩才能一路到末尾。用户反馈的正是这个现象。
   *
   * 所以这里把**每一列对齐的位置**全部列出来，外加末尾那一点：
   *   第 k 列对齐（左边缘落在 gutter 上）所需偏移 = `k × 步距`；
   *   最后一列对齐所需偏移会超出可滑动距离（内容右侧本来就不够），
   *   于是用**可滑动距离**（末尾）兜住，保证最后一列也能停住、不会弹回去。
   */
  private featuredSnapPoints(): number[] {
    const n: number = this.featuredColumnCount();
    if (n <= 0) {
      return [0];
    }
    const pitch: number = this.featuredColPitch();
    const gutter: number = this.homeScrollGutterH();
    const gap: number = CategoryContentSection.FEATURED_COL_GAP;
    // 内容总宽 = 左右 gutter + n 列 + (n-1) 个列间距
    const contentWidth: number = gutter * 2 + n * this.featuredCellWidth() + (n - 1) * gap;
    const maxOffset: number = Math.max(0, contentWidth - this.featuredScrollerWidth());

    const points: number[] = [];
    for (let k: number = 0; k < n; k++) {
      const offset: number = k * pitch;
      // 超出可滑动距离的分页点是非法的（文档要求落在 [0, 可滑动距离] 内）
      if (offset >= maxOffset) {
        break;
      }
      points.push(offset);
    }
    const last: number = points.length > 0 ? points[points.length - 1] : -1;
    if (Math.abs(maxOffset - last) > 0.5) {
      points.push(maxOffset);
    }
    return points;
  }

  /**
   * @returns 横向滚动容器宽度（vp）= 内容区宽度 + 两侧留白。
   *
   * 配合两侧的负 margin，滚动区域正好覆盖 0..窗口宽 —— 卡片能滑到屏幕边缘，
   * 不会被 section 的左右 padding 挡住（用户反馈的"左右会挡住一点"）。
   */
  private featuredScrollerWidth(): number {
    return this.featuredContentWidthVp() + this.homeScrollGutterH() * 2;
  }

  /** @returns 兜底的内容区宽度（vp）：窗口宽 − 两侧留白。 */
  private fallbackContentWidthVp(): number {
    const px: number = this.windowInfo.windowSize.width;
    if (px <= 0) {
      return 328;
    }
    return Math.max(120, this.getUIContext().px2vp(px) - this.homeScrollGutterH() * 2);
  }

  /**
   * 记录内容区实测宽度。
   *
   * ⚠️ 量的是 build() 里那条**不可见的量宽条**（`width('100%')` 的空节点），
   *    不是横向滚动容器本身：滚动容器的宽度现在由实测值反算出来，
   *    再拿它当测量源就会形成"量到 W → 把宽度设成 W+2g → 又量到 W+2g"的正反馈。
   *    量宽条是叶子节点、宽度只由父容器内容区决定，天然稳定。
   * @param area onAreaChange 回传的布局区域。
   */
  private onFeaturedAreaChange(area: Area): void {
    const width: number = areaLengthToVp(area.width);
    if (width > 0 && Math.abs(width - this.featuredContentVp) > 0.5) {
      this.featuredContentVp = width;
    }
  }

  /** @returns 「精选推荐」的列数（每列最多 3 张卡）。 */
  private featuredColumnCount(): number {
    const total: number = this.recommendViewModel.privateSongDisplayList.length;
    if (total <= 0) {
      return 0;
    }
    return Math.ceil(total / CategoryContentSection.FEATURED_ROWS);
  }

  /** @returns 展开成 [0, 1, ... 列数-1]，给 ForEach 用。 */
  private featuredColumnIndexes(): number[] {
    const count: number = this.featuredColumnCount();
    const indexes: number[] = [];
    for (let i: number = 0; i < count; i++) {
      indexes.push(i);
    }
    return indexes;
  }

  /**
   * 取第 `column` 列的歌曲。
   *
   * ⚠️ 必须是**列优先**分配（`column * 3 + row`）：这样「第 r 行」从左往右读
   *    正好是第 r、r+3、r+6… 首，横向滑动的顺序才是自然的（行内从左到右）。
   *    按行优先切（`column * rows + i` 之外的写法）会让每列是连续 3 首，
   *    横向滚动时阅读顺序就变成上→下→右，很别扭。
   * @param column 列下标。
   * @returns 该列的歌曲（最多 `FEATURED_ROWS` 首）。
   */
  private featuredColumnItems(column: number): RecommendPrivateSongUi[] {
    const source: RecommendPrivateSongUi[] = this.recommendViewModel.privateSongDisplayList;
    const rows: number = CategoryContentSection.FEATURED_ROWS;
    const out: RecommendPrivateSongUi[] = [];
    for (let r: number = 0; r < rows; r++) {
      const index: number = column * rows + r;
      if (index < source.length) {
        out.push(source[index]);
      }
    }
    return out;
  }

  /**
   * 「精选推荐」的一行：封面 + 歌名/歌手 + 更多按钮，**横向**排布（与改动前的版式一致）。
   *
   * ⚠️ 只有宽度变了：原来是 `FULL_WIDTH`（一整行），现在固定成 {@link featuredCellWidth}，
   *    于是同一行里能并排放多列。
   * ⚠️ 歌名、歌手都是 `maxLines(1)`：多列网格里每格必须等高，
   *    歌名换行会让同一行的格子高低不齐。
   * @param item 歌曲。
   */
  @Builder
  private FeaturedRow(item: RecommendPrivateSongUi) {
    Row({ space: 12 }) {
      Image(item.coverUrl.length > 0 ? item.coverUrl : $r('app.media.ic_avatar1'))
        .width(48)
        .height(48)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.ic_avatar1'))
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.singer)
          .fontSize(12)
          .fontColor($r('app.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SongMoreMenu({
        song: {
          songId: item.songId, name: typeof item.title === 'string' ? item.title : '',
          singer: typeof item.singer === 'string' ? item.singer : '',
          albumName: '', albumId: '', source: item.source,
          interval: '', img: item.coverUrl, types: []
        },
        iconSize: 18
      })
    }
    .width(this.featuredCellWidth())
    .padding({ top: 10, bottom: 10 })
    .onClick(() => {
      if (item.source.length > 0) {
        void this.recommendViewModel.requestPlayOnlineSong(item, this.getUIContext());
      }
    })
  }

  /**
   * 「精选推荐」：**最多 3 行、横向滚动的多列布局**（原来是一长条竖列表）。
   *
   * 为什么改成这个版式：竖列表 10 多首要滑很久，「歌单广场」被顶到很下面；
   * 换成 3 行 × N 列横滑之后，一屏能看 9~10 首、整块高度只剩原来的四成左右。
   *
   * 排布方式：`Scroll(横向) { Row { 每列一个 Column(最多 3 张卡) } }`，
   * 行数写死 3、列数按歌曲数量算，不设上限（即"可以很多列"）。
   * 不用 `Grid` 是因为横向滚动的 Grid 要调 `rowsTemplate`/`columnsTemplate` 的配合，
   * 而这里列数本来就是算出来的，`Row` 里摆列更直接、也没有行列模板的坑。
   */
  @Builder
  private FeaturedList() {
    Column() {
      this.CategoryTitle($r('app.string.home_category_featured'))
      if (this.recommendViewModel.privateSongDisplayList.length === 0) {
        Text($r('app.string.home_category_empty'))
          .fontSize(13)
          .fontColor($r('app.color.font_tertiary'))
          .width(StyleConstants.FULL_WIDTH)
          .padding({ top: 16, bottom: 16 })
      } else {
        Scroll() {
          Row({ space: CategoryContentSection.FEATURED_COL_GAP }) {
            ForEach(this.featuredColumnIndexes(), (column: number) => {
              Column({ space: CategoryContentSection.FEATURED_ROW_GAP }) {
                ForEach(this.featuredColumnItems(column), (item: RecommendPrivateSongUi) => {
                  this.FeaturedRow(item);
                  // ★ key 必须带上 coverUrl：这几张卡的封面是**异步补进来**的，
                  //   ForEach 只在 key 变化时重建子节点；key 只用 source_songId 时补图完
                  //   也不会重绘，表现就是「首页歌曲永远没有封面」。
                }, (item: RecommendPrivateSongUi) =>
                'feat-' + column + '-' + item.source + '_' + item.songId + '_' + item.coverUrl)
              }
              .alignItems(HorizontalAlign.Start)
            }, (column: number) =>
            `feat-col-${column}-${this.featuredColumnCount()}-${this.featuredCellWidth()}`)
          }
          // 内容自己留出左右 gutter：第一行与标题左对齐、最后一行能滑到右边留白处
          .padding({
            left: this.homeScrollGutterH(),
            right: this.homeScrollGutterH()
          })
          // 最后一列可能只有 1~2 行，顶部对齐才不会看起来"矮一截还居中"
          .alignItems(VerticalAlign.Top)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        // ★ 铺到屏幕两侧：宽度 = 内容宽 + 两侧留白，再用负 margin 抵消父容器的 padding，
        //   滚动区域正好是 0..窗口宽 —— 卡片能滑到屏幕边缘，不会被 section 的左右
        //   padding 挡住（用户反馈的"左右会挡住一点"）。
        .width(this.featuredScrollerWidth())
        .margin({
          left: -this.homeScrollGutterH(),
          right: -this.homeScrollGutterH()
        })
        // ★ 一次吸附一列：把**每一列对齐的偏移**都作为分页点传进去（单调递增），
        //   末尾用可滑动距离兜住。文档里数组的语义是"分页点"而不是"步距"，
        //   只传一个值会导致只有开头/一列/末尾三个停靠位置（见 featuredSnapPoints 注释）。
        .scrollSnap({
          snapAlign: ScrollSnapAlign.START,
          snapPagination: this.featuredSnapPoints(),
          enableSnapToStart: true
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
  }

  /** Renders the singer chart list when category 1 is selected. */
  @Builder
  private SingerList() {
    Column() {
      this.CategoryTitle($r('app.string.home_category_singers'))
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
   */
  build() {
    Column() {
      // ★ 不可见的量宽条：只用来测「内容区宽度」（= 原本一行占满的宽度）。
      //
      //   为什么单独放一条：横向滚动容器的宽度现在是由实测值**反算**出来的
      //   （内容宽 + 两侧留白），再拿它当测量源就成了"量到 W → 宽度设成 W+2g →
      //   又量到 W+2g"的正反馈、会一直变宽。这条是叶子节点、宽度只由父容器
      //   内容区决定、与任何子节点无关，所以稳定；高度 1vp 且无背景，看不见。
      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(1)
        .onAreaChange((_old: Area, area: Area): void => {
          this.onFeaturedAreaChange(area);
        })

      if (this.recommendViewModel.selectedCategoryIndex === 0) {
        this.FeaturedList()
      } else if (this.recommendViewModel.selectedCategoryIndex === 1) {
        this.SingerList()
      } else if (this.recommendViewModel.selectedCategoryIndex === 2) {
        HomeRankingSection({ recommendViewModel: this.recommendViewModel, embedded: true })
      } else if (this.recommendViewModel.selectedCategoryIndex === 3) {
        this.RegionList()
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: this.homeScrollGutterH(), right: this.homeScrollGutterH() })
  }
}
