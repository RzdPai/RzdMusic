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
import {
  BreakpointType,
  ColorConversion,
  getWindowInfoState,
  ImmersiveType,
  RouterUrlConstants,
  StyleConstants,
  WindowInfo
} from 'musicbasic';
import { CoverWing } from './CoverWing';
import { ToplistRouteParam } from 'playlist';
import { RecommendHeroCardUi, RecommendPrivateSongUi } from '../model/RecommendUiModels';
import { MusicDataService } from '../util/MusicDataService';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';

/** 「每日30首」歌单在 AppStorage 里的中转结构（详情页读取）。 */
interface DailyThirtyRow {
  title: string;
  singer: string;
  source: string;
  songId: string;
  coverUrl: string;
}

/**
 * Responsive horizontal hero banner carousel for the phone recommendation home.
 */
@ComponentV2
export struct HeroBannerSection {
  /** Breakpoint env for card width/height and inter-card spacing. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** VM providing hero banner card data for the carousel. */
  @Param recommendViewModel: RecommendViewModel = new RecommendViewModel();
  /** Title bar insets, immersive decor, and related window metrics. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** Nav stack for routing to toplist detail. */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();

  /** Routes to the shared playlist detail page with the prefetched board. */
  private async openBoard(source: string, boardId: string, title: string | Resource): Promise<void> {
    if (boardId.length === 0) {
      return;
    }
    const param = await MusicDataService.buildBoardRouteParam(source, boardId,
      typeof title === 'string' ? title : '');
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
  }

  /** Routes to the QQ music toplist detail page when the card has a toplist id. */
  private openToplist(topid: string, title: string | Resource, cover: string): void {
    if (topid.length === 0) {
      return;
    }
    const titleText: string = typeof title === 'string' ? title : '';
    const param = new ToplistRouteParam();
    param.topid = topid;
    param.listTitle = titleText;
    // 榜单封面随路由带下去：详情页 Hero 用它，而不是第一首歌的封面
    param.listCover = cover;
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
  }

  /** Plays a daily-recommendation hero banner song through the online player. */
  private playBannerSong(item: RecommendHeroCardUi): void {
    if (item.songId.length === 0) {
      return;
    }
    const song = new RecommendPrivateSongUi();
    song.title = item.title;
    song.singer = item.subLine;
    song.source = item.source;
    song.songId = item.songId;
    song.coverUrl = item.coverUrl;
    void this.recommendViewModel.requestPlayOnlineSong(song, this.getUIContext());
  }

  /** 播放首页推荐歌单里的前几首（功能入口卡的统一动作）。 */
  private playHomeList(): void {
    const list = this.recommendViewModel.privateSongDisplayList;
    if (list.length === 0) {
      return;
    }
    void this.recommendViewModel.requestPlayOnlineSong(list[0], this.getUIContext());
  }

  /**
   * 播放首页列表里的某一首（按名字定位）。
   *
   * ⚠️ 不能永远播 `list[0]`：卡片下方显示的是**各自随机到的那首歌名**，
   *    如果点击统一播第一首，就会出现「五张卡歌名不一样、点下去都是同一首」。
   * @param subLine 卡片下方显示的歌名（空串表示回落到第一首）。
   */
  private playNamedSong(subLine: string): void {
    const list = this.recommendViewModel.privateSongDisplayList;
    if (list.length === 0) {
      return;
    }
    let target = list[0];
    if (subLine.length > 0) {
      for (let i: number = 0; i < list.length; i++) {
        const t = list[i].title;
        if (typeof t === 'string' && t === subLine) {
          target = list[i];
          break;
        }
      }
    }
    void this.recommendViewModel.requestPlayOnlineSong(target, this.getUIContext());
  }

  /** 功能入口卡点击：现在就听 / 每日30首 / 新歌推荐 / 心动模式 / 精选推荐。 */
  private onFeatureTap(item: RecommendHeroCardUi): void {
    if (item.feature === 'daily30') {
      // 「每日30首」**直接用现有的榜单页面**（PlaylistDetailPage），不再新写一个页面。
      // 走 sectionType='daily30'，歌单通过 AppStorage 中转给详情页
      // （playlist 不能反向依赖 recommendation）。
      const list = this.recommendViewModel.privateSongDisplayList;
      const rows: DailyThirtyRow[] = [];
      for (let i: number = 0; i < list.length; i++) {
        const t = list[i].title;
        const s = list[i].singer;
        rows.push({
          title: typeof t === 'string' ? t : '',
          singer: typeof s === 'string' ? s : '',
          source: list[i].source,
          songId: list[i].songId,
          coverUrl: list[i].coverUrl
        });
      }
      AppStorage.setOrCreate('dailyThirtySongs', JSON.stringify(rows));
      const param = new ToplistRouteParam();
      param.sectionType = 'daily30';
      param.listTitle = '每日30首';
      if (list.length > 0) {
        param.listCover = list[0].coverUrl;
      }
      this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
      return;
    }
    if (item.feature === 'listenNow') {
      // 「现在就听」：**永远播这张卡上显示的那首歌**（不是当前在播的歌）。
      // 之前这里写的是"有在播就打开播放页"，于是点卡片打开的是当前播放，
      // 与卡片上的封面/歌名对不上 —— 用户明确反馈过。
      this.playNamedSong(typeof item.subLine === 'string' ? item.subLine : '');
      return;
    }
    // 其余三张：播各自显示的那首歌
    this.playNamedSong(typeof item.subLine === 'string' ? item.subLine : '');
  }

  /** 当月英文名（「每日30首」卡上的月份文案，按当天日期实时取）。 */
  private monthName(): string {
    const names: string[] = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    const index: number = new Date().getMonth();
    return names[index >= 0 && index < names.length ? index : 0];
  }

  /** 当天日期数字（「每日30首」卡上的大号数字）。 */
  private dayOfMonth(): number {
    return new Date().getDate();
  }

  /**
   * 「现在就听」卡显示的封面。
   *
   * 由 VM 在首页装配时定稿（
owPlayingCoverUrl），**不是**实时读在播歌曲 ——
   * 否则换歌后卡片会变成"上一次的封面配旧的背景色"。空串时退回打包内配图。
   */
  private nowPlayingCover(): string {
    return this.recommendViewModel.nowPlayingCoverUrl;
  }

  /** 「现在就听」卡的背景取色：由当前封面异步算出，失败时用兜底色。 */
  private nowPlayingTint(): string {
    const tint: string = this.recommendViewModel.nowPlayingTint;
    return tint.length > 0 ? tint : '#2E4A78';
  }

  private homeScrollGutterH(): number {
    return new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /**
   * 卡片宽度（vp）。
   *
   * 抽成方法是因为「现在就听」卡的封面/侧片都要按卡片宽度**等比**算
   * （比例是从参考工程的 `ic_recommend1.png` 上量出来的，见 {@link NowPlayingCard}），
   * 写死尺寸在平板上会明显偏小。
   * @returns 卡片宽度（vp）。
   */
  private cardWidth(): number {
    return this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 187 :
      new BreakpointType(223, 223, 292, 292, 203).getWidthValueWithHeightSM(this.breakpointEnv.widthBreakpoint,
        this.breakpointEnv.heightBreakpoint);
  }

  /**
   * 卡片高度（vp）。
   * @returns 卡片高度（vp）。
   */
  private cardHeight(): number {
    return this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 234 :
      new BreakpointType(280, 280, 365, 365, 186).getWidthValueWithHeightSM(this.breakpointEnv.widthBreakpoint,
        this.breakpointEnv.heightBreakpoint);
  }

  /**
   * 「现在就听」卡中间封面的边长（vp）。
   *
   * 比例 0.589 是从参考图 `ic_recommend1.png` 上量出来的
   * （封面 110.2vp / 卡片宽 187vp）；再用**卡片高度的一半**兜一下：
   * HEIGHT_SM 那种矮卡片（203×186）按宽度算出来会占到高度的 65%，会顶到标题条。
   * @returns 封面边长（vp）。
   */
  private nowPlayingCoverSize(): number {
    return Math.min(this.cardWidth() * 0.589, this.cardHeight() * 0.5);
  }

  /**
   * 侧翼观感的旋钮（用户说"小25%"→ 两个比例各乘 0.75；要再大/再小就同时乘同一个系数）。
   *    - `WING_WIDTH_RATIO` 宽度比例（0.15 × 0.75 = 0.1125）；
   *    - `WING_HEIGHT_RATIO` 外缘高度 / 封面高度（1.15 × 0.75 ≈ 0.8625）；
   *    - `WING_OVERLAP_RATIO` 封面往两侧各盖住多少（相对翼宽的比例，0.22 ≈ 盖住约五分之一）；
   *    - `WING_GROUP_SHIFT_RATIO` 整组相对卡片中心的纵向偏移（0 = 正中）。
   */
  private static readonly WING_WIDTH_RATIO: number = 0.1125;
  private static readonly WING_HEIGHT_RATIO: number = 0.8625;
  private static readonly WING_OVERLAP_RATIO: number = 0.22;
  /** 整组相对卡片中心的纵向偏移（0 = 正中）。 */
  private static readonly WING_GROUP_SHIFT_RATIO: number = 0;

  /** 侧翼宽度（vp）。 */
  private wingWidth(): number {
    return this.cardWidth() * HeroBannerSection.WING_WIDTH_RATIO;
  }

  /** 侧翼外缘高度（vp）。 */
  private wingHeight(): number {
    return this.nowPlayingCoverSize() * HeroBannerSection.WING_HEIGHT_RATIO;
  }

  /** 侧翼内缘上下各收进量（vp）：等腰梯形，收进 10% → 内缘高 = 外缘的 80%。 */
  private wingInset(): number {
    return this.wingHeight() * 0.10;
  }

  /** 封面往两侧各盖住侧翼的宽度（vp）：正数 = 重叠，用负 margin 实现。 */
  private wingOverlap(): number {
    return this.wingWidth() * HeroBannerSection.WING_OVERLAP_RATIO;
  }

  /** 「现在就听」卡显示的封面图源（动态封面优先，取不到用通用占位图）。 */
  private nowPlayingCoverSource(item: RecommendHeroCardUi): ResourceStr {
    return this.nowPlayingCover().length > 0 ? this.nowPlayingCover() : $r('app.media.ic_avatar1');
  }

  /**
   * 「现在就听」卡：**封面取色底 + 两侧竖等腰梯形侧翼 + 中间动态封面**。
   *
   * 侧翼见 {@link CoverWing}。这里只负责按卡片尺寸算比例：
   * 三件东西用 `Row` 自然排布（翼 + 间隙 + 封面 + 间隙 + 翼），
   * 因为封面在卡面里本来就是水平居中的，Row 居中之后侧翼的落点自动与参考图一致
   * （187 宽的卡片算下来两侧各留 11.7vp，正是参考图量到的 11.7vp）。
   * 整组再上移 0.039 × 卡高 —— 参考图的装饰组中心比卡片中心偏上 9.1vp。
   * @param item 卡片数据（取不到动态封面时回落到打包内配图）。
   */
  @Builder
  private NowPlayingCard(item: RecommendHeroCardUi) {
    Stack({ alignContent: Alignment.Center }) {
      // 1) 底色：封面动态取色
      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .backgroundColor(this.nowPlayingTint())

      // 2) 侧翼 + 封面。三件都是正立形状，靠 Row 居中排布；Row 默认垂直居中，
      //    所以侧翼和封面天然同心（不存在谁偏上偏下）。
      //    重叠用**负 margin**：封面往两侧各盖住 `wingOverlap()`，
      //    所以 Row 里没有 space（正 space 会变成留缝，方向正好相反）。
      //    ⚠️ 层次必须靠 zIndex 指定，**不能**靠书写顺序：Row 的子节点是按声明顺序绘制的，
      //       右翼排在封面后面就会被画在封面之上（用户反馈的"右翼挡住了一小块封面"），
      //       而左翼排在前面正好是对的 —— 只有右边出问题就是因为这个。
      //       封面 zIndex(1)、两侧 zIndex(0)，与声明顺序无关。
      Row() {
        CoverWing({
          isStart: true,
          wingWidth: this.wingWidth(),
          wingHeight: this.wingHeight(),
          insetTop: this.wingInset(),
          insetBottom: this.wingInset(),
          outerRadius: this.wingWidth() * 0.55,
          // 靠封面那侧不再需要圆角：那段本来就被封面盖住了，留着反而在重叠边缘多一道弧
          innerRadius: 0,
          fill: this.wingFill()
        })
          .zIndex(0)
          .margin({ right: -this.wingOverlap() })

        Image(this.nowPlayingCoverSource(item))
          .width(this.nowPlayingCoverSize())
          .height(this.nowPlayingCoverSize())
          .objectFit(ImageFit.Cover)
          .borderRadius(this.nowPlayingCoverSize() * 0.105)
          .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.45)', offsetX: 0, offsetY: 8 })
          .zIndex(1)

        CoverWing({
          isStart: false,
          wingWidth: this.wingWidth(),
          wingHeight: this.wingHeight(),
          insetTop: this.wingInset(),
          insetBottom: this.wingInset(),
          outerRadius: this.wingWidth() * 0.55,
          innerRadius: 0,
          fill: this.wingFill()
        })
          .zIndex(0)
          .margin({ left: -this.wingOverlap() })
      }
      .translate({ y: this.cardHeight() * HeroBannerSection.WING_GROUP_SHIFT_RATIO })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  /**
   * 侧翼填充色：按卡片底色的明暗自动选「半透明白」或「半透明黑」。
   *
   * 为什么必须按底色算：原来写死 `#26FFFFFF`（15% 白），配上
   * `vividFlowColors` 给的中高亮度底色，叠上去和底色几乎没差别 ——
   * 用户看到的就是「侧翼根本没渲染出来」。
   * @returns `#AARRGGBB` 填充色。
   */
  private wingFill(): string {
    return ColorConversion.contrastOverlay(this.nowPlayingTint(), 0x40);
  }

  /**
   * 「每日30首」卡的实时背景：**列表前 4 首的封面拼 2×2**。
   *
   * 参考工程的 `ic_recommend2.png` 就是一张"四宫格封面 + 大号日期"的静态图
   * （11 月 / 30），所以这里照它的构图做实时的：四个格子放真实封面，
   * 拿不到封面的格子用主题浅色块占位。
   * @param item 卡片数据（`dailyCovers` 为 4 个封面地址）。
   */
  @Builder
  private DailyCollage(item: RecommendHeroCardUi) {
    Column() {
      Row() {
        this.DailyCell(item, 0)
        this.DailyCell(item, 1)
      }
      .width(StyleConstants.FULL_WIDTH)
      .layoutWeight(1)

      Row() {
        this.DailyCell(item, 2)
        this.DailyCell(item, 3)
      }
      .width(StyleConstants.FULL_WIDTH)
      .layoutWeight(1)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .justifyContent(FlexAlign.Center)
  }

  /** 2×2 里的一个格子。 */
  @Builder
  private DailyCell(item: RecommendHeroCardUi, index: number) {
    Stack() {
      if (item.dailyCovers.length > index && item.dailyCovers[index].length > 0) {
        Image(item.dailyCovers[index])
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .backgroundColor(index === 0 ? '#3A4A68' : index === 1 ? '#2E4A78' :
            index === 2 ? '#4A3A68' : '#2B3F5C')
      }
    }
    .layoutWeight(1)
    .height(StyleConstants.FULL_HEIGHT)
  }

  /**
   * Single full-bleed hero card with badge, title stack, and decorative play icon.
   *
   * @param item - Hero card UI model.
   */
  @Builder
  private HeroBannerCard(item: RecommendHeroCardUi) {
    Stack() {
      if (item.feature === 'daily30') {
        // 「每日30首」：四宫格封面 + 大号日期（实时）。
        // 四宫格直接用首页列表**缓存下来的封面**（`dailyCovers` 就是列表前 4 首的
        // coverUrl，不再额外请求），整块轮播在封面就绪后一次性出现（见 build）。
        this.DailyCollage(item)

        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .linearGradient({
            colors: [['#66000000', 0], ['#CC12203A', 1]],
            angle: 180,
            direction: GradientDirection.Bottom
          })

        Column({ space: 0 }) {
          Text(this.monthName())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text(`${this.dayOfMonth()}`)
            .fontSize(56)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .lineHeight(60)
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (item.feature === 'listenNow') {
        // 「现在就听」：封面 + 封面取色背景
        this.NowPlayingCard(item)
      } else {
        // 新歌推荐 / 心动模式 / 精选推荐：直接用**下方那首歌自己的封面**
        // （取不到就用通用占位图；不再有打包内配图，那 5 张 ic_recommend* 已删除）
        Image(item.coverUrl.length > 0 ? item.coverUrl : $r('app.media.ic_avatar1'))
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.ic_avatar1'))
      }

      Column() {
        Row({ space: 4 }) {
          Image($r('app.media.ic_music_symbol'))
            .width(14)
            .height(14)
            .fillColor($r('app.color.banner_text_primary'))
          Text(item.badge)
            .fontSize(12)
            .lineHeight(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.banner_text_primary'))
        }
        .padding(12)
        .width('100%')
        .justifyContent(FlexAlign.Start)

        Row() {
          Column({ space: 4 }) {
            Text(item.title)
              .fontSize(20)
              .fontColor($r('app.color.banner_text_tertiary'))
              .fontWeight(FontWeight.Bold)
              .lineHeight(27)
            Text(item.subLine)
              .fontSize(12)
              .fontColor($r('app.color.banner_text_secondary'))
              .maxLines(1)
              .lineHeight(16)
              .fontWeight(FontWeight.Regular)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
            .fontSize(36)
            .fontWeight(FontWeight.Regular)
            .height(36)
            .fontColor([$r('app.color.banner_text_tertiary')])
            .accessibilityText('播放')
            .accessibilityLevel('no')
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .backgroundColor($r('app.color.banner_overlay_background'))
        .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK)
        .padding(12)
      }
      .height('100%')
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width(this.cardWidth())
    .height(this.cardHeight())
    .clip(true)
    .borderRadius(20)
    .onClick(() => {
      if (item.feature.length > 0) {
        this.onFeatureTap(item);
      } else if (item.songId.length > 0) {
        this.playBannerSong(item);
      } else if (item.boardId.length > 0) {
        this.openBoard(item.source, item.boardId, item.title);
      } else {
        this.openToplist(item.topid, item.title, item.coverUrl);
      }
    })
  }

  /**
   * Horizontal scroll of hero cards driven by the view model hero list.
   */
  build() {
    // ★ 整块轮播**一次性出现**：封面没补完之前不渲染卡片。
    //
    //   之前卡片先画出来、封面异步补完再刷新，用户看到的就是"过一会儿突然换图"。
    //   现在等首页列表的封面全部就绪（`dailySongsReady`）再画，几张卡连同
    //   四宫格、歌名一起出现，没有中途跳变。
    if (!this.recommendViewModel.dailySongsReady) {
      Scroll() {
        Row({ space: new BreakpointType(8, 12, 16, 16).getValue(this.breakpointEnv.widthBreakpoint) }) {
          ForEach([0, 1, 2, 3, 4], (_index: number) => {
            Column()
              .width(this.cardWidth())
              .height(this.cardHeight())
              .borderRadius(20)
              .backgroundColor($r('app.color.background_secondary'))
          }, (index: number) => `hero-skeleton-${index}`)
        }
        .padding({ left: this.homeScrollGutterH(), right: this.homeScrollGutterH() })
      }
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Horizontal)
      .width(StyleConstants.FULL_WIDTH)
      .align(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? Alignment.Start : Alignment.Center)
    } else {
      Scroll() {
        Row({ space: new BreakpointType(8, 12, 16, 16).getValue(this.breakpointEnv.widthBreakpoint) }) {
          ForEach(this.recommendViewModel.heroCards, (item: RecommendHeroCardUi, index?: number) => {
            Column() {
              this.HeroBannerCard(item);
            }
          },
          // key 必须带上 subLine（每张卡随机到的歌名）与四宫格封面：
          // 只按 index 做 key 时，卡片数据更新（歌名换了、封面补上了）不会重建子节点，
          // 表现就是「卡片确实重算了，但下面显示的歌名一直没刷新」。
          (item: RecommendHeroCardUi, index?: number) =>
          `hero-${index}-${item.subLine}-${item.dailyCovers.join(',')}`)
        }
        .padding({ left: this.homeScrollGutterH(), right: this.homeScrollGutterH() })
      }
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Horizontal)
      .width(StyleConstants.FULL_WIDTH)
      .align(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? Alignment.Start : Alignment.Center)
    }
  }
}
