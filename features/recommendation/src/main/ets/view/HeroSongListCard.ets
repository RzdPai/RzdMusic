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

import { LocalCoverImage, SongTitleMarquee, StyleConstants } from 'musicbasic';
import { SongMoreMenu } from 'playlist';
import { RecommendPrivateSongUi } from '../model/RecommendUiModels';
import { RecommendSongUiDataSource } from '../model/RecommendSongUiDataSource';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';

/**
 * 首页顶部**大卡片**里「新歌推荐」/「精选推荐」的**卡面内容**：一张歌曲列表。
 *
 * ⚠️⚠️ **本文件当前无人引用（2026-10-15 起）—— 保留但不要照它做那两张卡。**
 *   用户 2026-10-15 纠正：「新歌推荐不是说了改成歌曲列表，就是**和每日三十首一样
 *   点开是个歌单**，并且**封面也是四张封面拼一块**，**只要把上面文字改了**」
 *   ⇒ 那两张卡已改成与「每日30首」**逐字同款**的四宫格拼图卡
 *   （`HeroBannerSection.DailyCollage`），点击进歌单详情（`openHeroSongList`）。
 *   "卡里嵌一个列表"是**做错了**的方向，本组件因此下线（与 `HomeSongListSection.ets`
 *   同一种状态：文件在、无引用）。要复用请先跟主线确认。
 *
 * 下面是它原本的说明（保留作参考）
 * ---------------------------------------------------------------------------
 * 用户原话（澄清版）：「新歌推荐和精选推荐还是一首歌，你是不是改错了，
 * 是**首页大卡片**的新歌推荐和精选推荐」——
 * 指的是首页顶部那一排 5 张大卡（见 `RecommendDataUtil.getFeatureHeroCards`）里
 * `feature === 'newSongs'` / `feature === 'picked'` 这两张：它们原先卡面是
 * **一首歌的封面 + 一首歌的歌名**，现在改成**歌曲列表**（行样式与「每日30首」同款）。
 *
 * ★ 只换卡面内容形态，**不动卡片的框**：外层 `HeroBannerSection.HeroBannerCard` 仍然是
 *   同一个 `Stack`（宽 `cardWidth()` / 高 `cardHeight()` / `clip(true)` / `borderRadius(20)`），
 *   仍然只渲染**这一个**根节点（`build()` 根节点唯一，官方《创建自定义组件》硬约束）。
 *
 * ★ 行样式与「每日30首」（`PlaylistDetailSongListSection.PlaylistSongRow`）同款：
 *   封面小图 44 + 歌名（`sys.float.Body_M` + 跑马灯）+ 歌手（`sys.float.Caption_M`）+ 右侧 ⋯。
 *   与 `HomeSongListSection.SongRow` 是同一套版式，只是**行内左右留白收窄**
 *   （这里装在卡片里、外面已经有卡片自己的边距；那一版装在整页 List 的 ListItem 上）。
 *
 * ★ 数据来源与点击行为**逐字沿用**卡片原来的那一条：
 *   数据 = `RecommendViewModel.privateSongDataSource`（= `privateSongDisplayList`，首页那份唯一实例）；
 *   点行 = `recommendViewModel.requestPlayOnlineSong(item, uiContext)`。
 *   ⇒ 不新造数据、不新增导航、不碰 `PlaybackIntentState`。
 *
 * ⚠️ 卡片内容区是**固定高度的卡内滚动列表**（`List` + `LazyForEach`）：
 *   卡高固定（手机 280vp）、装不下 12 行 ⇒ 给它卡内滚动。
 *   **只在卡片内部**，页面级滚动容器一个字节都没动（`RecommendPage` 仍是 `Scroll`）。
 *   `nestedScroll` 全部 `SELF_ONLY`：上下滑交给卡内 List，左右滑照常交给外层那个
 *   横向轮播 `Scroll` —— 不这样写，卡内 List 会把横向手势也吃掉，轮播就滑不动了。
 */
@ComponentV2
export struct HeroSongListCard {
  /** 卡面标题（保留卡片原来的标题：`新歌推荐` / `精选推荐`）。 */
  @Param title: string = '';
  /** 歌曲行数据源（`LazyForEach`）：首页那份唯一实例，由 VM 在每次加载后整体替换。 */
  @Param dataSource: RecommendSongUiDataSource = new RecommendSongUiDataSource([]);
  /** 行数（空态判断用），与 `dataSource.totalCount()` 同源。 */
  @Param songCount: number = 0;
  /** 键前缀：两张卡各一套键，互不干扰（`'newSongs'` / `'picked'`）。 */
  @Param keyPrefix: string = 'hero';
  /**
   * 卡面顶部要不要**自绘**标题条。
   *
   * 首页那张大卡的 `HeroBannerCard` 里已经有一条**铺在卡底的**标题条
   * （角标图标 + `item.title` + 播放图标 + 半透明底），它自带 `onClick`。
   * 那条在列表卡上会**盖住列表最上面一行**，所以这一支走 `showHeader: false`，
   * 由外面那条标题条负责"卡片的标题"，本组件只画列表；卡高也被让给列表。
   * （自绘那一支留给"不叠外层标题条"的用法，两条路径都保留、都不重复出标题。）
   */
  @Param showHeader: boolean = true;
  /** View model：点行时用它发起播放（沿用卡片原来的播放动作）。 */
  @Param recommendViewModel: RecommendViewModel = new RecommendViewModel();

  /** 卡片内容区左右留白（vp）：卡面窄，比整页 section 的 gutter 收窄一档。 */
  private static readonly CARD_GUTTER_VP: number = 12;
  /** 卡面标题条高度（vp），与改动前那条角标/标题条同一高度。 */
  private static readonly CARD_HEADER_VP: number = 40;

  /**
   * 单曲行的稳定键。
   *
   * ★ 必须带上 `coverUrl`：首页列表的封面是**异步补进来**的（`refillHomeCovers`），
   *   `LazyForEach` 只在键变化时重建子节点 —— 键里不含封面就会出现
   *   「补图完也不重绘、整列空图标」（`CategoryContentSection` 原来那段注释记的就是这个坑）。
   * @param item 歌曲行。
   * @returns 该行的唯一键。
   */
  private rowKey(item: RecommendPrivateSongUi): string {
    return `${this.keyPrefix}-${item.source}_${item.songId}_${item.coverUrl}`;
  }

  /**
   * 一行歌曲：封面小图 + 歌名 + 歌手 + 右侧 ⋯ 菜单（「每日30首」同款）。
   *
   * ⚠️ 播放动作**不在行内另起一条路**：仍旧是 `requestPlayOnlineSong`，
   *   与改动前卡片 `onClick` 里那条播放路径同一个函数。
   * @param item 歌曲行。
   */
  @Builder
  private SongRow(item: RecommendPrivateSongUi) {
    Row({ space: 8 }) {
      if (item.coverUrl.length > 0) {
        LocalCoverImage({ src: item.coverUrl, cacheHttp: true, imageWidth: 44, imageHeight: 44, radius: 8 })
      }
      Column({ space: 2 }) {
        // ★ 歌名过长时跑马灯（用户要求「各个页面歌曲名过长时改为用跑马灯显示」）。
        //   字号/字色/字重与「每日30首」那一行逐字一致。
        //   ⚠️ 父容器是 **Row**（左边封面、右侧"更多"按钮）⇒ 宽度用 `layoutWeight(1)` 吃剩余宽；
        //      在 Row 里用 `width('100%')` 会把右侧按钮挤掉。
        SongTitleMarquee({
          text: item.title,
          titleFontSize: $r('sys.float.Body_M'),
          titleFontColor: $r('app.color.font_primary'),
          titleFontWeight: FontWeight.Medium,
          fillByWidth: false
        })
        Text(item.singer)
          .fontSize($r('sys.float.Caption_M'))
          .lineHeight(16)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('app.color.font_tertiary'))
          .maxLines(1)
          .layoutWeight(1)
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
        iconSize: 16
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: HeroSongListCard.CARD_GUTTER_VP,
      right: HeroSongListCard.CARD_GUTTER_VP,
      top: 6,
      bottom: 6
    })
    .onClick(() => {
      void this.recommendViewModel.requestPlayOnlineSong(item, this.getUIContext());
    })
  }

  /** 空态：一句话，不加解释性文案（与首页其它 section 同口径）。 */
  @Builder
  private EmptyHint() {
    Text($r('app.string.home_category_empty'))
      .fontSize(13)
      .fontColor($r('app.color.font_tertiary'))
      .width(StyleConstants.FULL_WIDTH)
      .padding({
        left: HeroSongListCard.CARD_GUTTER_VP,
        right: HeroSongListCard.CARD_GUTTER_VP,
        top: 16,
        bottom: 16
      })
  }

  /**
   * 卡面标题条：**逐字保留改动前那一条**（角标图标 + 卡片标题 + 右侧播放图标 + 不透明底）。
   *
   * ⚠️ 这一条是**不透明**的：下面的歌曲列表在它底下滚动、卡片本身又有圆角，
   *   透明底会让行从标题条下面透出来。
   * ⚠️ 这里**没有** `onClick`：改动前整张卡有 `onClick`，但 `HeroBannerCard` 那一次改动
   *   已经把它去掉了（卡片改名"卡片外壳"，点击行为交给卡内热点）；
   *   本组件同样不加，免得"点标题条"与"点卡片"两处各触发一次播放。
   */
  @Builder
  private CardHeader() {
    Row({ space: 4 }) {
      Image($r('app.media.ic_music_symbol'))
        .width(14)
        .height(14)
        .fillColor($r('app.color.banner_text_primary'))
      Text(this.title)
        .fontSize(14)
        .lineHeight(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.banner_text_primary'))
        .maxLines(1)
        .layoutWeight(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
        .fontSize(22)
        .fontWeight(FontWeight.Regular)
        .height(22)
        .fontColor([$r('app.color.banner_text_tertiary')])
        .accessibilityText('播放')
        .accessibilityLevel('no')
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(HeroSongListCard.CARD_HEADER_VP)
    .padding({ left: HeroSongListCard.CARD_GUTTER_VP, right: HeroSongListCard.CARD_GUTTER_VP })
    .backgroundColor($r('app.color.banner_overlay_background'))
    .justifyContent(FlexAlign.SpaceBetween)
  }

  /**
   * 卡面 = （可选）标题条 + **卡内滚动**的歌曲列表（整块只有一个根节点）。
   *
   * ⚠️ `List` 的 `height` 用 `layoutWeight(1)` 吃卡片剩余高度（不写死数值）⇒
   *   卡片高度换断点/换形态时列表自动跟着变，不需要第二处维护；
   *   `showHeader: false`（首页大卡那一支）时列表拿到**整张卡的高度**——
   *   这样外层那条铺在卡底的标题条就不会盖住列表第一行。
   */
  build() {
    Column() {
      if (this.showHeader) {
        this.CardHeader()
      }

      if (this.songCount === 0) {
        this.EmptyHint()
      } else {
        List() {
          LazyForEach(this.dataSource, (item: RecommendPrivateSongUi) => {
            ListItem() {
              this.SongRow(item)
            }
          }, (item: RecommendPrivateSongUi): string => this.rowKey(item))
        }
        .width(StyleConstants.FULL_WIDTH)
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_ONLY,
          scrollBackward: NestedScrollMode.SELF_ONLY
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .backgroundColor($r('app.color.background_secondary'))
  }
}
