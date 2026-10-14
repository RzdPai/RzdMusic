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

import { uiObserver } from '@kit.ArkUI';
import { BreakpointType, LocalCoverImage, SongTitleMarquee, StyleConstants } from 'musicbasic';
import { SongMoreMenu } from 'playlist';
import { RecommendPrivateSongUi } from '../model/RecommendUiModels';
import { RecommendSongUiDataSource } from '../model/RecommendSongUiDataSource';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';

/**
 * 「新歌推荐」/「精选推荐」共用的**歌曲列表**区块（和「每日30首」同一个行样式）。
 *
 * 为什么是同一个组件跑两次：用户要求这两块从"大卡／横滑卡"换成**歌曲行竖排列表**，
 * 行样式与「每日30首」（`PlaylistDetailPage` → `PlaylistDetailSongListSection`
 * 的 `PlaylistSongRow`）一致 —— 封面小图 + 歌名 + 歌手 + 右侧 ⋯。
 * 两块只差**标题文案**和 **LazyForEach 的键前缀**（两块读同一份歌曲列表，
 * 键前缀不同才能保证两套键互不干扰）。
 *
 * ⚠️ 只换展示形态：**不改数据来源、不改点击行为** ——
 * 数据仍是 `RecommendViewModel.privateSongDataSource`（= `privateSongDisplayList`），
 * 点击仍走 `recommendViewModel.requestPlayOnlineSong(item, uiContext)`
 * （与原来的 `CategoryContentSection.FeaturedRow` 同一条路）。
 *
 * ⚠️ 行内左右留白由本组件按断点自己给（原来在 `CategoryContentSection` 的整块 padding 上）：
 * 本组件每一行都是首页那个**吸顶 List** 的 `ListItem`，行自己带 gutter 才能在接缝那一条
 * 画满不透明底色，否则吸顶时下面的行会从两侧透出来。
 */
@ComponentV2
export struct HomeSongListSection {
  /** Breakpoint env for responsive row gutters. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** 区块标题（保留原来的「新歌推荐」/「精选推荐」）。 */
  @Param sectionTitle: Resource = $r('app.string.page_show');
  /** 歌曲行数据源（LazyForEach）：首页那个唯一实例，由 VM 在每次加载后整体替换。 */
  @Param dataSource: RecommendSongUiDataSource = new RecommendSongUiDataSource([]);
  /** 行数（空态判断用）。 */
  @Param songCount: number = 0;
  /** 键前缀：两个区块各一套键，见类注释。 */
  @Param keyPrefix: string = 'song';
  /**
   * 是否渲染区块标题。
   *
   * 「新歌推荐」/「精选推荐」（挂在首页那个 List 下）要标题；
   * 分类 Tab 里的「精选推荐」渲染时，标题由 `CategoryContentSection` 自己出 ⇒ 传 false，
   * 免得同一块内容出现两个标题。
   */
  @Param showTitle: boolean = true;
  /** View model：点击行时用它发起播放（沿用原有行为）。 */
  @Param recommendViewModel: RecommendViewModel = new RecommendViewModel();

  /** 行内左右留白（vp）：与首页各 section 的 gutter 同一档。 */
  private homeScrollGutterH(): number {
    const gutters: BreakpointType<number> = new BreakpointType<number>(16, 24, 32, 32);
    return gutters.getValue(this.breakpointEnv.widthBreakpoint);
  }

  /**
   * 单曲行的稳定键。
   *
   * ★ 必须带上 `coverUrl`：首页列表的封面是**异步补进来**的（`refillHomeCovers`），
   *   `LazyForEach` 只在键变化时重建子节点 —— 键里不含封面就会出现
   *   「补图完也不重绘、整列空图标」（`CategoryContentSection` 原来那段注释记的就是这个坑）。
   * @param item 歌曲行。
   * @returns 该行的唯一键。
   */
  private songRowKey(item: RecommendPrivateSongUi): string {
    return `${this.keyPrefix}-${item.source}_${item.songId}_${item.coverUrl}`;
  }

  /** 区块标题：与「歌手 / 榜单 / 分类」几个 section 的标题同一套排版。 */
  @Builder
  private SectionTitle() {
    Text(this.sectionTitle)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.font_primary'))
      .lineHeight(24)
      .width(StyleConstants.FULL_WIDTH)
      .padding({
        left: this.homeScrollGutterH(),
        right: this.homeScrollGutterH(),
        top: 16,
        bottom: 12
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
        left: this.homeScrollGutterH(),
        right: this.homeScrollGutterH(),
        top: 16,
        bottom: 16
      })
  }

  /**
   * 一行歌曲：封面小图 + 歌名 + 歌手 + 右侧 ⋯ 菜单（和「每日30首」的行一致）。
   *
   * ⚠️ 播放动作**不在行内改**：仍旧交给 `RecommendViewModel.requestPlayOnlineSong`，
   *   所以"点行播放"与"⋯ 菜单里的操作"两条路都和改动前逐字一致。
   * @param item 歌曲行。
   */
  @Builder
  private SongRow(item: RecommendPrivateSongUi) {
    Row({ space: 8 }) {
      if (item.coverUrl.length > 0) {
        LocalCoverImage({ src: item.coverUrl, cacheHttp: true, imageWidth: 44, imageHeight: 44, radius: 8 })
      }
      Column({ space: 4 }) {
        // ★ 歌名过长时跑马灯（用户要求「各个页面歌曲名过长时改为用跑马灯显示」）。
        //   本行是「新歌推荐」/「精选推荐」共用行，与「每日30首」
        //   （`PlaylistDetailSongListSection.PlaylistSongRow`）同一套版式，
        //   字号/字色/字重逐字保留 ⇒ 两处观感仍然一致。
        SongTitleMarquee({
          text: item.title,
          titleFontSize: $r('sys.float.Body_M'),
          titleFontColor: $r('app.color.font_primary'),
          titleFontWeight: FontWeight.Medium,
          // ⚠️ 这一处父容器是 **Row**（左边封面、右侧"更多"按钮）⇒ 宽度必须用 `layoutWeight(1)` 吃**剩余**宽。
          //    在 Row 里用 `width('100%')` 会把右侧按钮挤掉；只有 Column 父容器才用 width('100%')（= 默认）。
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
        iconSize: 18
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: this.homeScrollGutterH(),
      right: this.homeScrollGutterH(),
      top: 10,
      bottom: 10
    })
    // ★ 2026-10-15：行下方细分隔线（与 `CategoryContentSection.FeaturedRow` 同一口径：
    //   语义色 `app.color.comp_divider`）。本组件**当前无人引用**（首页已回到 `Scroll`，
    //   见文件头），这里同步改是为了"万一哪天重新启用，行样式与现役那一份仍然一致"。
    //   ⚠️ 这里用 `border` 而不是 `Divider()` 子节点：本行根节点是 `Row`（不是 `Column`），
    //      加子节点会改变行内排布；`border` 只作用于自身底边，没有这个问题。
    .borderWidth({ bottom: 0.6 })
    .borderColor({ bottom: $r('app.color.comp_divider') })
    .onClick(() => {
      void this.recommendViewModel.requestPlayOnlineSong(item, this.getUIContext());
    })
  }

  /**
   * 区块 = 一个 `ListItemGroup`：**标题 + 歌曲行**都在里面 ⇒ 整块只有**一个根节点**。
   *
   * ⚠️ 为什么必须只有一个根节点：官方《创建自定义组件》→「build() 函数实现规则」明写
   *   「@Component 装饰的自定义组件，其 **build() 函数下的根节点唯一且必要**」
   *   ⇒ 不能写成 `ListItem(){标题} ListItemGroup(){歌行}` 这种兄弟节点。
   *   所以标题并进 group 内（`LazyForEach` 必须由 `ListItemGroup` **直接持有**，
   *   中间不能再套 `Column`）。
   *
   * ⚠️ 标题**不会**吸顶：本 group 用**无 header** 的写法，而 `sticky(StickyStyle.Header)`
   *   只作用于「带 header 的 ListItemGroup」—— 全页只有**分类 Tab 那一组**写了
   *   `ListItemGroup({ header })` ⇒ 滚上去只有那一行钉住，本区块的标题照常随内容滚走。
   */
  build() {
    ListItemGroup() {
      if (this.showTitle) {
        // 第一个 ListItem 就是区块标题（「新歌推荐」/「精选推荐」）
        ListItem() {
          this.SectionTitle()
        }
      }
      if (this.songCount === 0) {
        ListItem() {
          this.EmptyHint()
        }
      } else {
        LazyForEach(this.dataSource, (item: RecommendPrivateSongUi) => {
          ListItem() {
            this.SongRow(item)
          }
        }, (item: RecommendPrivateSongUi): string => this.songRowKey(item))
      }
    }
  }
}
