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
  areaLengthToVp,
  BreakpointType,
  getPlaylistTransitionState,
  ColorConversion,
  getWindowInfoState,
  ImmersiveType,
  Logger,
  RouterUrlConstants,
  StyleConstants,
  WindowInfo
} from 'musicbasic';
import { CoverWing } from './CoverWing';
import { ToplistRouteParam } from 'playlist';
import { RecommendHeroCardUi, RecommendPrivateSongUi } from '../model/RecommendUiModels';
import { MusicDataService } from '../util/MusicDataService';
import {
  RecommendDataUtil,
  isFeatureBoardCard,
  pickFeatureBoardBareId,
  pickFeatureBoardId
} from '../util/RecommendDataUtil';
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
  /**
   * 大卡横向滚动容器（`Scroll`）的视口宽度实测值（vp）。
   *
   * 只为算横向吸附的**分页点**而存在（末页要用"可滑动距离"兜住，见 {@link heroSnapPoints}）。
   * ⚠️ 量的是**滚动容器自己**（它的宽度是写死的 `100%`、不随内容变），
   *    不是内容里那条 `Row` —— 拿内容当测量源会形成"量到 W₂ → 分页点变 → 又量到 W₂"的正反馈。
   */
  @Local heroScrollWidthVp: number = 0;

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

  /**
   * 这张卡的卡面是不是「四张封面拼一块」的**歌单卡**形态。
   *
   * 用户 2026-10-15 纠正原话：「**新歌推荐不是说了改成歌曲列表，就是和每日三十首一样
   * 点开是个歌单**，并且**封面也是四张封面拼一块**，**只要把上面文字改了**。」
   * ⇒ `newSongs` / `picked` 与 `daily30` 走**同一个卡面**（`DailyCollage`，逐字同款），
   *   差别只有卡上/卡底的文字（`item.badge` / `item.title` / `item.subLine`，都来自数据层，
   *   本文件不判类型、不写死文案）。
   *
   * ⚠️ 上一版把这两张做成"卡内嵌一个歌曲列表"（`HeroSongListCard`）—— 那是**做错了**：
   *    用户要的是"卡 = 歌单入口"，不是"卡里放一个列表"。本轮已撤掉该用法；
   *    `HeroSongListCard.ets` 文件保留但**当前无人引用**。
   * @param item 卡片数据。
   * @returns true = 卡面渲染四宫格拼图（歌单卡）。
   */
  private isCollageFeature(item: RecommendHeroCardUi): boolean {
    return item.feature === 'daily30' || item.feature === 'newSongs' || item.feature === 'picked';
  }

  /**
   * 四宫格第一格的组件 id：既是**共享元素转场**的量测锚点（`PlaylistTransitionState.prepare`），
   * 也**必须按卡片区分** —— 同屏最多有 3 张拼图卡（每日30首 / 新歌推荐 / 精选推荐），
   * id 重名会让 `getFrameNodeById` 量到错的那张卡。
   *
   * `daily30` 算出来仍是 `playlist-daily30-cover`（与改动前逐字相同，转场链路不变）。
   * @param feature 卡片去向标识（`daily30` / `newSongs` / `picked`）。
   * @returns 组件 id。
   */
  private static collageCoverId(feature: string): string {
    return `playlist-${feature}-cover`;
  }

  /**
   * 「每日30首」的点击：走**首页推荐列表**那条通道进歌单详情页。
   *
   * ⚠️ 本通道**只服务 `daily30` 一张卡**，数据经 `AppStorage['dailyThirtySongs']` 中转
   *   （读侧：`features/playlist/.../MusicListPlaybackViewModel.loadDailyThirtySongs`），
   *   内容是**首页列表的快照** `privateSongDisplayList`。
   *
   * ⚠️⚠️ **榜单卡（新歌推荐 / 精选推荐）绝对不能走这里** —— 这条通道里没有任何榜单数据，
   *   而榜单卡的四宫格封面来自**各自平台的榜单**（`loadFeatureBoardSongsAsync`，
   *   见 `RecommendViewModel.loadFeatureBoardCovers`）⇒ 两者不同源，
   *   走这里点进去就是**0 首歌**（用户 2026-10-15 报的 bug 正是这个：0ee1320 那一版
   *   把三张拼图卡一起塞进了本方法）。榜单卡的去向是 {@link openFeatureBoard}。
   * @param item 卡片数据（`title` 即歌单标题）。
   */
  private openHeroSongList(item: RecommendHeroCardUi): void {
    // ★ 防御性护栏：榜单卡一律不得走这条「首页推荐列表」通道（见本方法注释的 ⚠️⚠️）。
    //   这里 return 而不是"兜底走榜单"：本方法是同步的，跳转要等榜单路由参数里的封面，
    //   所以真正的分发在 `onFeatureTap` 那一处（它在进本方法之前就把榜单卡分走了）。
    if (isFeatureBoardCard(item.feature)) {
      Logger.warn('RzdHomeBoard',
        `refuse daily30 channel for board card feature=${item.feature} (use openFeatureBoard)`);
      return;
    }
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
    param.listTitle = typeof item.title === 'string' && item.title.length > 0 ? item.title : '每日30首';
    if (list.length > 0) {
      param.listCover = list[0].coverUrl;
    }
    const coverId: string = HeroBannerSection.collageCoverId(item.feature);
    const animated: boolean = !getPlaylistTransitionState().prepare(this.getUIContext(),
      coverId, param.listCover);
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param, animated);
  }

  /**
   * 「新歌推荐 / 精选推荐」的点击：进**对应的榜单歌单页**。
   *
   * 用户原话：「新歌推荐和精选推荐改成对应榜单（比如当前设置首页推荐为 QQ，
   * 就用 QQ 的新歌榜和热歌榜）」⇒ 这两张卡**不再是首页推荐列表**（那条 `sectionType='daily30'`
   * 通道只留给「每日30首」），而是各自平台的新歌榜 / 热歌榜。
   *
   * ★ 通道**完全复用现成的那一条**，一个新接口都没有：
   *   `ToplistRouteParam{ boardSource, boardId }` → `PlaylistDetailPage`
   *   → `player.fetchBoardSongs(boardSource, boardId)` → `lxLeaderboard('<boardSource>_<boardId>')`。
   *   榜单来自 `RecommendDataUtil.pickFeatureBoardId()`（即 player 的 `getLeaderboardEntries()`
   *   那张表，`tx_27` = QQ 新歌榜 / `tx_26` = QQ 热歌榜 …）—— 与卡面四宫格取歌**同一个榜**，
   *   所以「卡上看到的 4 张封面」和「点进去的第一页」是同一张榜。
   *
   * ⚠️⚠️ 但**两个 id 的形态不一样**，这是本方法最容易写错的一处（2026-10-15 真机「点进去 0 首歌」就是它）：
   *   - 卡面四宫格：`lxLeaderboard(fullId)` —— `fullId` 是**带前缀的完整 id**（`tx_27`），
   *     因为 `lxLeaderboard` 自己 `split('_')`；取它用 {@link pickFeatureBoardId}。
   *   - 路由参数：`fetchBoardSongs` **自己会拼** `source + '_' + boardId`
   *     ⇒ `boardId` 必须是**不带前缀的榜单号**（`27`），与首页排行榜
   *     `HomeRankingSection.openBoard`、「精选推荐」`CategoryContentSection.openBoardChart`
   *     完全同形（它们传的 `boardId` 来自 `boardsWithCovers()`，那个是裸的）；
   *     取它用 {@link pickFeatureBoardBareId}。
   *   传错成 `fetchBoardSongs('tx', 'tx_27')` ⇒ `lxLeaderboard('tx_tx_27')` ⇒ `split('_')` 得
   *   `src='tx'`/`id='tx'` ⇒ `lxTxToplist('tx')` ⇒ **0 首**。
   *
   * ⚠️ 取不到榜单 id（该平台没有这张榜）时**什么都不做**并记日志，绝不退回 daily30
   *   —— 退回去会出现"卡上写新歌推荐、点开是每日30首"的错位。
   * @param item 卡片数据（`feature` 决定取新歌榜还是热歌榜）。
   */
  private async openFeatureBoard(item: RecommendHeroCardUi): Promise<void> {
    const svcSource: string = RecommendDataUtil.mapHomeSource(this.recommendViewModel.homeSourceCode());
    // 卡面四宫格那条通道要的形态（带前缀，`lxLeaderboard` 自己拆）—— 只用于日志比对。
    const fullBoardId: string = pickFeatureBoardId(item.feature, svcSource);
    // 路由参数那条通道要的形态（不带前缀，`fetchBoardSongs` 自己拼回 `svcSource + '_' + boardId`）。
    const routeBoardId: string = pickFeatureBoardBareId(item.feature, svcSource);
    const boardName: string = RecommendDataUtil.pickFeatureBoardName(item.feature, svcSource);
    if (routeBoardId.length === 0) {
      Logger.info('RzdHomeBoard', `feature board tap: no board feature=${item.feature} source=${svcSource}`);
      return;
    }
    const param: ToplistRouteParam = await MusicDataService.buildBoardRouteParam(svcSource, routeBoardId, boardName);
    // ★ 因果链自查口径（`grep RzdHomeBoard`）：一行里把三段字符串**逐字**打全，一眼就能对上/对上不：
    //   `board=tx_27`     —— 与卡面四宫格取封面时打的 `feature board loaded … board=tx_27` 同一个值；
    //   `route=tx 27`     —— 真正进路由参数的形态（`boardSource` / `boardId`）；
    //   `lxLeaderboard(tx_27)` —— `fetchBoardSongs` 内部拼出来的最终字符串，
    //                        与详情页 `board songs loaded board=tx_27` 同一行。
    Logger.info('RzdHomeBoard',
      `feature board tap feature=${item.feature} source=${svcSource} board=${fullBoardId}` +
      ` route=${svcSource} ${routeBoardId} name=${boardName}` +
      ` detail=fetchBoardSongs(${svcSource},${routeBoardId}) lx=lxLeaderboard(${svcSource}_${routeBoardId})`);
    const coverId: string = HeroBannerSection.collageCoverId(item.feature);
    const animated: boolean = !getPlaylistTransitionState().prepare(this.getUIContext(), coverId, param.listCover);
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param, animated);
  }

  /** 功能入口卡点击：现在就听 / 每日30首 / 新歌推荐 / 心动模式 / 精选推荐。 */
  private onFeatureTap(item: RecommendHeroCardUi): void {
    if (isFeatureBoardCard(item.feature)) {
      // ★ 「新歌推荐 / 精选推荐」= 该平台的新歌榜 / 热歌榜（见 openFeatureBoard 注释）。
      void this.openFeatureBoard(item);
      return;
    }
    if (item.feature === 'daily30') {
      // 只有「每日30首」走首页推荐列表那条通道（用户可以：「和每日三十首一样点开是个歌单」）。
      this.openHeroSongList(item);
      return;
    }
    if (item.feature === 'listenNow') {
      // 「现在就听」：**永远播这张卡上显示的那首歌**（不是当前在播的歌）。
      // 之前这里写的是"有在播就打开播放页"，于是点卡片打开的是当前播放，
      // 与卡片上的封面/歌名对不上 —— 用户明确反馈过。
      this.playNamedSong(typeof item.subLine === 'string' ? item.subLine : '');
      return;
    }
    // 其余卡（心动模式）：播各自显示的那首歌
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

  /** 无界 `gradientOf` 的固定角度（`wujie126.pa`：`{ angle: 150 }`）。 */
  private static readonly HERO_GRADIENT_ANGLE: number = 150;
  /** 起色 `hsl(h, .62, .62)`（无界原值）。 */
  private static readonly GRADIENT_START_S: number = 0.62;
  private static readonly GRADIENT_START_L: number = 0.62;
  /** 止色色相偏移（无界原值 `+130°`，再 `% 360`）。 */
  private static readonly GRADIENT_END_HUE_SHIFT: number = 130;
  /** 止色 `hsl(h+130, .55, .38)`（无界原值）。 */
  private static readonly GRADIENT_END_S: number = 0.55;
  private static readonly GRADIENT_END_L: number = 0.38;

  /**
   * 「现在就听」卡背景的两个渐变停靠色。
   *
   * ★★★ 2026-10-21（甲方：「背景用纯色也不好看，参考无界的」）：
   *   无界 `design/src/main/ets/components/Cover` 的 `gradientOf()`（`wujie126.pa:67670` 起）是：
   *   `linearGradient({ angle: 150, colors: [[hsl(h, .62, .62), 0], [hsl((h+130)%360, .55, .38), 1]] })`
   *   —— 起色取封面主色相的**中亮**档，止色**色相 +130°**、更暗 ⇒ 一张卡里出两种色调，
   *   所以它看起来不像纯色。这里逐值照搬，色相 h 取自本卡已有的封面取色 `nowPlayingTint`
   *   （`vividFlowColors(...)[0]`，本身就是封面主色的鲜艳档）。
   * @returns `[[起色, 0], [止色, 1]]`
   */
  private nowPlayingGradientStops(): Array<[string, number]> {
    const hsl: number[] = HeroBannerSection.hexToHsl(this.nowPlayingTint());
    const start: string = HeroBannerSection.hslToHex(hsl[0],
      HeroBannerSection.GRADIENT_START_S, HeroBannerSection.GRADIENT_START_L);
    const end: string = HeroBannerSection.hslToHex(hsl[0] + HeroBannerSection.GRADIENT_END_HUE_SHIFT,
      HeroBannerSection.GRADIENT_END_S, HeroBannerSection.GRADIENT_END_L);
    return [[start, 0], [end, 1]];
  }

  /**
   * `#RRGGBB` / `#AARRGGBB` → `[色相 0–360, 饱和度 0–1, 亮度 0–1]`。
   * 解析失败时退中性蓝紫（与 `vividFlowColors` 的灰度兜底同一个色系）。
   * @param hex 颜色串
   * @returns `[h, s, l]`
   */
  private static hexToHsl(hex: string): number[] {
    let body: string = hex.trim();
    if (body.startsWith('#')) {
      body = body.substring(1);
    }
    if (body.length === 8) {
      body = body.substring(2);
    }
    if (body.length !== 6) {
      return [233, 0.45, 0.62];
    }
    const r: number = parseInt(body.substring(0, 2), 16) / 255;
    const g: number = parseInt(body.substring(2, 4), 16) / 255;
    const b: number = parseInt(body.substring(4, 6), 16) / 255;
    const max: number = Math.max(Math.max(r, g), b);
    const min: number = Math.min(Math.min(r, g), b);
    const l: number = (max + min) / 2;
    const delta: number = max - min;
    if (delta < 0.000001) {
      return [0, 0, l];
    }
    const s: number = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);
    let h: number = 0;
    if (max === r) {
      h = ((g - b) / delta) % 6;
    } else if (max === g) {
      h = (b - r) / delta + 2;
    } else {
      h = (r - g) / delta + 4;
    }
    return [(h * 60 + 360) % 360, s, l];
  }

  /**
   * HSL → `#RRGGBB`（`h` 0–360，`s` / `l` 0–1）。
   * @param h 色相
   * @param s 饱和度
   * @param l 亮度
   * @returns `#RRGGBB`
   */
  private static hslToHex(h: number, s: number, l: number): string {
    const c: number = (1 - Math.abs(2 * l - 1)) * s;
    const hp: number = (((h % 360) + 360) % 360) / 60;
    const x: number = c * (1 - Math.abs((hp % 2) - 1));
    let r: number = 0;
    let g: number = 0;
    let b: number = 0;
    if (hp < 1) {
      r = c;
      g = x;
    } else if (hp < 2) {
      r = x;
      g = c;
    } else if (hp < 3) {
      g = c;
      b = x;
    } else if (hp < 4) {
      g = x;
      b = c;
    } else if (hp < 5) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }
    const m: number = l - c / 2;
    return '#' + HeroBannerSection.toHexByte(r + m) + HeroBannerSection.toHexByte(g + m) +
      HeroBannerSection.toHexByte(b + m);
  }

  /** 0–1 通道 → 两位大写十六进制。 */
  private static toHexByte(value: number): string {
    const byte: number = Math.max(0, Math.min(255, Math.round(value * 255)));
    const hex: string = byte.toString(16).toUpperCase();
    return hex.length === 1 ? '0' + hex : hex;
  }

  private homeScrollGutterH(): number {
    return new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /** 大卡之间的列间距（vp）—— 与 build() 里两条 `Row({ space })` 用的**同一个**断点表。 */
  private heroCardGap(): number {
    return new BreakpointType(8, 12, 16, 16).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /** 记录横向滚动容器的视口宽度（vp），供 {@link heroSnapPoints} 算"可滑动距离"。 */
  private onHeroScrollAreaChange(area: Area): void {
    const width: number = areaLengthToVp(area.width);
    if (width > 0 && Math.abs(width - this.heroScrollWidthVp) > 0.5) {
      this.heroScrollWidthVp = width;
    }
  }

  /**
   * @returns 大卡横向滚动的**分页点**（vp，单调递增）——「与 `featuredSnapPoints()` 同口径」
   *   （对方在 `CategoryContentSection.ets`，即"精选推荐"那一行，用户要的正是它的行为）。
   *
   * 官方语义（ts-container-scroll / `snapPagination`）：
   *   - 传**单个** `Dimension` = "每页大小"，系统按它分页；
   *   - 传 **`Array<Dimension>`** = 逐个"**分页点**"（最终停靠的滚动偏移），
   *     每个值必须落在 `[0, 可滑动距离]` 内、且**必须单调递增**。
   *
   * ⚠️ 之所以要把**每一张卡**对齐的偏移都列出来：只传一个步距时全部能停的位置只有
   *    「开头 / 一张卡 / 末尾」三个 ⇒ 甩一下停在哪算哪、卡片半截可见（用户反馈的"没有停留"）。
   *   ⇒ 步长 = **卡片宽度 + 列间距**（`k × 步长` = 第 k 张卡左边缘对齐时所需偏移）；
   *   ⇒ 末页 = **可滑动距离**：最后一张卡对齐所需偏移会超出可滑动距离（内容右侧本来就不够），
   *      用可滑动距离兜住，**保证最后一张卡也能停住、不会弹回去**。
   *   ⚠️ 落点用 `Math.floor(kMax)`：框架按"向下取整"归到分页点，
   *      算出比真范围大 1px 的点会让"甩到底"停在倒数第二条缝上。
   */
  private heroSnapPoints(): number[] {
    const count: number = this.recommendViewModel.heroCards.length;
    if (count <= 0) {
      return [0];
    }
    const gutter: number = this.homeScrollGutterH();
    const pitch: number = this.cardWidth() + this.heroCardGap();
    // 内容总宽 = 左右 gutter + n 张卡 + (n-1) 个列间距
    const contentWidth: number = gutter * 2 + count * this.cardWidth() + (count - 1) * this.heroCardGap();
    const maxOffset: number = Math.max(0, contentWidth - this.heroScrollWidthVp);

    const points: number[] = [];
    const kMax: number = maxOffset > 0 && pitch > 0 ? Math.floor(maxOffset / pitch) : -1;
    for (let k: number = 0; k <= kMax; k++) {
      points.push(k * pitch);
    }
    const last: number = points.length > 0 ? points[points.length - 1] : -1;
    if (Math.abs(maxOffset - last) > 0.5) {
      points.push(maxOffset);
    }
    return points;
  }

  /**
   * 卡片宽度（vp）。
   *
   * 抽成方法是因为「现在就听」卡的封面/侧片都要按卡片宽度**等比**算
   * （比例是从参考工程的 `ic_recommend1.png` 上量出来的，见 {@link NowPlayingCard}），
   * 写死尺寸在平板上会明显偏小。
   * @returns 卡片宽度（vp）。
   */
  /** 大卡宽度的下限（vp）：再挤也别缩成一条。 */
  private static readonly MIN_CARD_WIDTH_VP: number = 140;

  private cardWidth(): number {
    const want: number = this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 187 :
      new BreakpointType(223, 223, 292, 292, 203).getWidthValueWithHeightSM(this.breakpointEnv.widthBreakpoint,
        this.breakpointEnv.heightBreakpoint);
    // ★★★ 2026-10-21（真机：横屏转回竖屏后，首页第一张大卡变成"整屏宽"的大封面，
    //   把 hero 行和底部迷你条都顶掉）：
    //   `cardWidth()` 只吃 `breakpointEnv`（ArkUI 的 BREAK_POINT 环境值），旋转后它可能**还是上一档**
    //   ⇒ 竖屏 363vp 的窗口按 292 宽出卡 ⇒ 溢出画面。
    //   ⇒ 再按**实测窗口宽**夹一道（破折点错了也不会画错尺寸）：
    //   卡宽 ≤ 窗口宽 − 左右两侧 gutter。
    const win: number = this.liveWindowWidthVp();
    if (win <= 0) {
      return want;
    }
    const maxW: number = Math.max(HeroBannerSection.MIN_CARD_WIDTH_VP, win - 2 * this.homeScrollGutterH());
    return Math.min(want, maxW);
  }

  /**
   * @returns 实测窗口宽（vp，0 = 还没量到）。
   *
   * 与 `breakpointEnv` 的区别：这个来自 `WindowInfo.windowSize`（`windowSizeChange` 实时写），
   * 旋转/分屏后**立刻**是真实值；破折点环境值可能滞后一档，所以尺寸要用它兜底。
   */
  private liveWindowWidthVp(): number {
    const size = this.windowInfo.windowSize;
    const px: number = size !== undefined && size !== null ? size.width : 0;
    if (px <= 0) {
      return 0;
    }
    return this.getUIContext().px2vp(px);
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
  /**
   * 装饰组相对卡片中心的纵向偏移（**负 = 上移**，按卡高比例，保证平板上等比）。
   *
   * ★★★ 2026-10-21（甲方：「首页这个现在就听，卡片里的封面/装饰组本身偏下」）：
   *   卡面被"顶部角标行 + 底部标题带"夹着，装饰组原来按**整卡**居中 ⇒ 视觉重心落在
   *   那条半透明标题带上，看着就往下坠。把可见空区（角标下沿 ~ 标题带上沿）当参考框后，
   *   它的中心比卡片中心高约 5% 卡高 ⇒ 取 −0.05（234 高卡 ≈ 上移 11.7vp）。
   *   要再高/再低就只改这一个数（0 = 回退到"整卡居中"）。
   */
  private static readonly WING_GROUP_SHIFT_RATIO: number = -0.05;

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
   * 「现在就听」卡：**封面取色的双色调渐变底 + 两侧竖等腰梯形侧翼 + 中间动态封面**。
   *
   * 侧翼见 {@link CoverWing}。这里只负责按卡片尺寸算比例：
   * 三件东西用 `Row` 自然排布（翼 + 间隙 + 封面 + 间隙 + 翼），
   * 因为封面在卡面里本来就是水平居中的，Row 居中之后侧翼的落点自动与参考图一致
   * （187 宽的卡片算下来两侧各留 11.7vp，正是参考图量到的 11.7vp）。
   * 整组再按 {@link WING_GROUP_SHIFT_RATIO} 上移 —— 卡片底部那条半透明标题带会把装饰组的
   * 下半段压住，按整卡居中会让视觉重心往下坠（甲方 2026-10-21：「装饰组本身偏下」）。
   * @param item 卡片数据（取不到动态封面时回落到打包内配图）。
   */
  @Builder
  private NowPlayingCard(item: RecommendHeroCardUi) {
    Stack({ alignContent: Alignment.Center }) {
      // 1) 底色：照搬无界 `HeroTile` 的**双色调渐变**（`Cover.gradientOf`，见
      //    {@link nowPlayingGradientStops}）。原来这里是 `backgroundColor(封面取色)` 的**纯色**，
      //    甲方口径：「背景用纯色也不好看」⇒ 换渐变（角度 150°，止色色相 +130°）。
      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .linearGradient({
          colors: this.nowPlayingGradientStops(),
          angle: HeroBannerSection.HERO_GRADIENT_ANGLE
        })

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
   * 「歌单卡」（每日30首 / 新歌推荐 / 精选推荐）的实时背景：**列表前 4 首的封面拼 2×2**。
   *
   * 参考工程的 `ic_recommend2.png` 就是一张"四宫格封面 + 大号日期"的静态图
   * （11 月 / 30），所以这里照它的构图做实时的：四个格子放真实封面，
   * 拿不到封面的格子用主题浅色块占位。
   *
   * ⚠️ 三张卡**共用这一份实现**（用户：「和每日三十首一样…只要把上面文字改了」）；
   *    `idPrefix` 按卡片区分，避免同屏三张拼图卡的组件 id 重名。
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

  /** 2×2 里的一个格子（id 按卡片区分：`playlist-<feature>-cover` / `…-tile-N`）。 */
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
    .id(index === 0 ? HeroBannerSection.collageCoverId(item.feature)
      : `playlist-${item.feature}-tile-${index}`)
  }

  /**
   * Single full-bleed hero card with badge, title stack, and decorative play icon.
   *
   * @param item - Hero card UI model.
   */
  @Builder
  private HeroBannerCard(item: RecommendHeroCardUi) {
    Stack() {
      if (this.isCollageFeature(item)) {
        // ★ 三张**歌单卡**（每日30首 / 新歌推荐 / 精选推荐）**共用这一个卡面**：
        //   四张封面拼 2×2 + 底部渐变 + 居中大号文字。
        //   差别**只有文字** —— 卡上/卡底的 `item.badge` / `item.title` / `item.subLine`
        //   来自数据层（`NEW 新歌推荐` / `PICK 精选推荐`），这里一个文案都不写死。
        //   四宫格封面用首页列表**缓存下来的前 4 张封面**（`dailyCovers`，不再额外请求），
        //   整块轮播在封面就绪后一次性出现（见 build）。
        this.DailyCollage(item)

        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .linearGradient({
            colors: [['#66000000', 0], ['#CC12203A', 1]],
            angle: 180,
            direction: GradientDirection.Bottom
          })

        // ★ 卡面正中的大号文字。
        //   用户 2026-10-15（本轮）：「**上面不显示时间，就显示类似于新歌推荐四个大字**」
        //   ⇒ **只有「每日30首」**保留"月份 + 日期"（那是它的卡面语言），
        //     新歌推荐 / 精选推荐只留**大号标题**一行。
        //   ⚠️ 这不是"删掉文字"：三张卡上原本就没有别的大字，「新歌推荐 / 精选推荐」
        //     这行字来自数据层（`item.title`，见 `RecommendDataUtil.getFeatureHeroCards`
        //     的 specs），所以这里新增的 `Text(item.title)` **不会写死任何文案**。
        //   ⚠️ 卡片底那条 overlay 标题条（角标 NEW/PICK + 标题 + 副标题 + 播放图标）
        //     一个字未动，仍在下面那一层。
        Column({ space: 0 }) {
          if (item.feature === 'daily30') {
            Text(this.monthName())
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text(`${this.dayOfMonth()}`)
              .fontSize(56)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .lineHeight(60)
          } else {
            // 「新歌推荐」/「精选推荐」：只显示那四个大字（字号与日期同档，居中）。
            Text(item.title)
              .fontSize(40)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .lineHeight(52)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (item.feature === 'listenNow') {
        // 「现在就听」：封面 + 封面取色背景
        this.NowPlayingCard(item)
      } else {
        // 心动模式等**其余**功能卡：直接用**下方那首歌自己的封面**
        // （取不到就用通用占位图；不再有打包内配图，那 5 张 ic_recommend* 已删除）
        Image(item.coverUrl.length > 0 ? item.coverUrl : $r('app.media.ic_avatar1'))
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.ic_avatar1'))
      }

      // ★ 卡片标题条（角标图标 + `item.badge` + `item.title` + `item.subLine` + 播放图标）：
      //   **改动前就在这一层**，本轮一个字都没动 —— 它铺在卡面之上（`SpaceBetween`），
      //   「新歌推荐」/「精选推荐」的卡面已与「每日30首」同款（四宫格），
      //   **这三张卡的"文字"仍全部由它承担**（角标 `NEW`/`PICK`/`每日推荐` + 标题 + 副标题），
      //   也就是用户要的"只要把上面文字改了"—— 文案来自数据层，这里不判类型。
      //   它自己的 `.onClick` 在**外层那个 `Stack`** 上（见本 @Builder 末尾）：
      //   标题条不单独消费点击 ⇒ 点整张卡都是"进歌单"（与「每日30首」逐字同一条行为）。
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
        Row({ space: this.heroCardGap() }) {
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
      // ★ 横向**吸附**：每张卡停住（与「精选推荐」那一行同一个口径，见 {@link heroSnapPoints}）。
      //   用户原话「首页那几张大卡片还是没有停留」＝甩一下停在哪算哪、卡片半截可见；
      //   之前这里**既没有 Scroller 也没有 scrollSnap**，所以「跟精选推荐一样」这件事从来没成立过。
      //   ⚠️ `scrollSnap` 是 **`Scroll`** 的属性（`component/scroll.d.ts:1875`）；
      //      `List` 的吸附接口才叫 `scrollSnapAlign(ScrollSnapAlign)`（`list.d.ts:1925`），别写混。
      .onAreaChange((_old: Area, area: Area): void => {
        this.onHeroScrollAreaChange(area);
      })
      .scrollSnap({
        snapAlign: ScrollSnapAlign.START,
        snapPagination: this.heroSnapPoints(),
        enableSnapToStart: true
      })
    }
  }
}
