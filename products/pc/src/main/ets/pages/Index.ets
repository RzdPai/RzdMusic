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

import { AppStorageV2 } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { HdsNavigation } from '@kit.UIDesignKit';
import {
  AppStorageKeys,
  getWindowInfoState,
  getPlaylistTransitionState,
  HomeSourceState,
  MusicAppState,
  MusicDbApi,
  MusicStoreService,
  Logger,
  MORPH_HOST_ID,
  PlaybackIntentState,
  PlayerExpandState,
  MorphMetaBridge,
  StyleConstants,
  TabSwitchState,
  ThemeState,
  WindowInfo,
  areaLengthToVp
} from 'musicbasic';
import { dispatchShellPlaybackIntent, LXSourceHost, PlaybackPageCoverContent } from 'player';
import { RecommendPage } from 'recommendation';
import { PlaylistTransitionOverlay } from 'playlist';
import { MinePage } from 'setting';
import { localMusic } from 'localmusic';
import type { MatchSongInfo } from 'localmusic';
import { syncManager } from 'sync';
import { setCommentTargetResolver } from 'comment';
import type { CommentSongRef } from 'comment';
import { common } from '@kit.AbilityKit';

/**
 * PC root page: sidebar navigation, recommend tab in HdsNavigation, placeholders for other tabs,
 * and overlay playback UI when isShowPlay is true.
 */
@Entry
@ComponentV2
struct Index {
  /** Navigation stack for the recommend / home HdsNavigation region. */
  @Provider('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Selected sidebar tab index (0 = home), shared for cross-tab navigation. */
  @Local tabState: TabSwitchState =
    AppStorageV2.connect(TabSwitchState, AppStorageKeys.TAB_SWITCH_STATE, () => new TabSwitchState())!;
  /** App accent color, reactive to settings changes. */
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** Global music state including queue and player visibility. */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** Playback shell intent state monitored for external “open player�?requests. */
  @Local intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!;
  /** Window layout info (e.g. status bar inset for main column padding). */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /**
   * 首页来源平台（设置里选的 `qq`/`kg`/`wy`）。
   *
   * ⚠️ PC 壳层原来**没有**这一段：手机壳 `products/default` 会在 aboutToAppear 里把持久化的
   * 平台值灌进 HomeSourceState，PC 没有 ⇒ 冷启动后 `HomeSourceState.source` 一直是类默认值
   * `'qq'`，而设置页却是从 preferences 读的（显示"酷狗"）—— 于是"设置里选了平台，首页却不是那个平台"。
   */
  @Local homeSourceState: HomeSourceState =
    AppStorageV2.connect(HomeSourceState, AppStorageKeys.HOME_SOURCE_STATE, () => new HomeSourceState())!;
  /**
   * 整页形变状态（播放页的展开/收起几何）。
   *
   * PC 壳层本来就是把播放页当浮层挂在 Stack 里（没有模态），所以形变那套几何需要的
   * "宿主尺寸 / 窗口尺寸"必须由这里上报 —— 播放页自己那层是被形变的容器，量不了。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /** Initializes play queue from the local database. */
  aboutToAppear() {
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto) => dto.id);
    // ★ 侧栏从 4 项收成 2 项（推荐 / 我的）之后，`TabSwitchState.tabIndex` 可能是上一版留下的
    //   越界下标（旧「歌单」= 1、「我的」= 2、「设置」= 3）—— 越界时下面两个分支都不成立，
    //   主区会整片空白。共享状态里没有"页签数"这个概念，所以在这里夹一次。
    if (this.tabState.tabIndex < 0 || this.tabState.tabIndex > 1) {
      Logger.warn('RzdShell', `pc tab index out of range (${this.tabState.tabIndex}), reset to 0`);
      this.tabState.tabIndex = 0;
    }
    this.themeState.color = MusicStoreService.getInstance().getThemeColor();
    // 与手机壳一致：把持久化的「首页来源平台」灌进共享状态（漏了这一段 = 冷启动后首页平台永远是 qq）
    this.homeSourceState.source = MusicStoreService.getInstance().getHomeSource();
    AppStorage.setOrCreate('lxPlayQuality', MusicStoreService.getInstance().getPlayQuality());
    // 本地音乐库与同步客户端启动初始化（与手机壳层一致）：
    // 同时把这两个 HAR 拉进 pc 的构建图（hvigor 对 HAR 是按引用编译的）。
    // ⚠️ 各自包 try/catch：它们不是播放的前置条件，但一旦抛出去会中断 aboutToAppear。
    const hostContext: common.UIAbilityContext | undefined =
      this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (hostContext !== undefined) {
      try {
        localMusic.init(hostContext);
      } catch (err) {
        const e = err as BusinessError;
        Logger.error('RzdShell', `localMusic init failed code=${e.code} msg=${e.message}`);
      }
      try {
        syncManager.init(hostContext);
      } catch (err) {
        const e = err as BusinessError;
        Logger.error('RzdShell', `syncManager init failed code=${e.code} msg=${e.message}`);
      }
    }
    // 评论面板要能处理本地音乐：把「本地歌 -> 平台身份」的解析交给 comment（与手机壳层一致）
    setCommentTargetResolver((song: CommentSongRef): Promise<CommentSongRef | null> => {
      return Promise.resolve(this.resolveCommentTarget(song));
    });
  }

  /**
   * 本地音乐 -> 平台身份（评论面板内部会调用）。
   * @param song 评论面板给的歌曲身份（本地歌的 songId 就是本地 key）。
   * @returns 平台身份，或 null（没有匹配记录）。
   */
  private resolveCommentTarget(song: CommentSongRef): CommentSongRef | null {
    const matched: MatchSongInfo | null = localMusic.matchOf(song.songId);
    if (matched === null) {
      return null;
    }
    const ref: CommentSongRef = {
      source: matched.source,
      songId: matched.songId,
      name: matched.name.length > 0 ? matched.name : song.name,
      singer: matched.singer.length > 0 ? matched.singer : song.singer
    };
    return ref;
  }

  /**
   * Handles playback intent changes and opens the in-app player.
   *
   * ★ 2026-10-15（无界逆向 P1-9，`[我核]✅`）：**不要把 `isShowPlay = true` 包进
   *   `uiContext.animateTo`**。那会给"挂载播放页浮层 + 形变几何初始化"整段套一层隐式动画，
   *   于是形变的起点被那层动画吃掉（用户症状："从搜索结果/播放记录打开时从中间某处长出来"）。
   *   展开动画由播放页自己按反编译的 `doEnter` 播（350ms EaseInOut，起点在 `aboutToAppear` 压好），
   *   壳层只负责**裸置位**。默认壳层（`products/default/.../Index.ets`）早已是裸置位，本处是
   *   全仓最后一处旧写法；`PlayerViewModel.openFullScreenWithSharedElementTransition()` 的注释同口径。
   */
  @Monitor('intentState.requestVersion')
  onPlaybackIntentChanged() {
    dispatchShellPlaybackIntent(this.appState, this.intentState, () => {
      this.appState.isShowPlay = true;
    });
  }

  /** Sets the active sidebar tab index. */
  private selectSidebarTab(index: number): void {
    this.tabState.tabIndex = index;
  }

  /** Main column background by tab; uses app color resources (light/dark). */
  private mainContentBackgroundColor(): ResourceColor {
    return this.tabState.tabIndex === 0 ? $r('app.color.pc_main_home_background') : $r('app.color.pc_main_alt_background');
  }

  /**
   * One sidebar row with icon and title; highlights when index matches currentTab.
   * @param index Tab index this row represents.
   * @param title Localized title resource.
   * @param symbol System symbol resource for the row icon.
   */
  @Builder
  SideNavItem(index: number, title: Resource, symbol: Resource) {
    Row({ space: 8 }) {
      SymbolGlyph(symbol)
        .fontSize(22)
        .fontWeight(FontWeight.Regular)
        .height(22)
        .fontColor([this.tabState.tabIndex === index ? this.themeState.color : $r('sys.color.icon_primary')])
      Text(title)
        .fontSize(16)
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(21)
        .fontWeight(FontWeight.Medium)
    }
    .height(45)
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.tabState.tabIndex === index ? $r('app.color.pc_nav_item_selected_bg') : Color.Transparent)
    .borderRadius(8)
    .padding(8)
    .stateStyles({
      pressed: {
        .backgroundColor($r('sys.color.ohos_id_color_click_effect'))
      },
      focused: {
        .border({ width: 2, color: $r('sys.color.ohos_id_color_focused_outline') })
      }
    })
    .onClick(() => {
      this.selectSidebarTab(index);
    })
  }

  /** Builds sidebar + main area stack with optional full-screen playback overlay. */
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      SideBarContainer(SideBarContainerType.Embed) {
        Column({ space: 8 }) {
          Row({ space: 12 }) {
            Image($r('app.media.ic_music_icon'))
              .width(24)
              .height(24)
              .objectFit(ImageFit.Contain)
              .draggable(false)
            Text($r('app.string.sidebar_brand_music'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .lineHeight(21)
              .fontColor($r('sys.color.font_primary'))
          }
          .height(64)
          .width(StyleConstants.FULL_WIDTH)
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Center)

          this.SideNavItem(0, $r('app.string.tab_home'), $r('sys.symbol.house_fill'));
          this.SideNavItem(1, $r('app.string.tab_cafe_listen'), $r('sys.symbol.person_crop_circle_fill_1'));
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .padding({
          left: 16,
          right: 16
        })
        .backgroundColor($r('app.color.pc_sidebar_background'))
        .alignItems(HorizontalAlign.Start)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.START])

        Column() {
          /**
           * ★ 两个页签（推荐 / 我的）**共用同一个 `HdsNavigation`**，与 `products/default`
           *   的手机壳结构一致（那边是 `HdsNavigation(pageIndexInfos) { HdsTabs { … } }`）。
           *
           * 为什么必须合成一个（2026-10-11 修）：
           *   官方文档《Navigation 开发指导》原文 —— "每个 Navigation 都有自己的路由栈，
           *   **不可共享**"。所以不能把同一个 `NavPathStack` 分别塞给两个 `HdsNavigation`。
           *   而 `MinePage` 里的「收藏 → 歌手 / 专辑详情」「歌单 → 歌单详情」是往
           *   `@Consumer('pageIndexInfos')`（= 壳层这个共享栈）上 push 的：以前「我的」那一支
           *   给的是 inline `new NavPathStack()`，推上去的页面没登记路由表；而共享栈又只绑在
           *   「推荐」那一支上，切到「我的」时那一支**已卸载** —— 表现就是"点了没反应"。
           *   现在只有一个 Navigation、一个栈，页签切换发生在它**内部**，栈与渲染者始终同一个。
           *
           * `MinePage` 自带的 `MinePage.localStack` 不受影响：它管自己的设置页 / 全部歌单页，
           * 属于"内层 Navigation 用系统路由表"，与本层这一支互不干扰。
           */
          HdsNavigation(this.pageIndexInfos) {
            if (this.tabState.tabIndex === 0) {
              Column() {
                RecommendPage()
              }
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
              .backgroundColor($r('sys.color.slider_outset_and_none_track_color'))
              .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
            } else {
              /**
               * 「我的」（侧栏第 2 项 = 最后一项）。
               *
               * ★ 侧栏从 4 项收成 2 项（推荐 / 我的），与手机壳同一套口径：
               *   「歌单」「设置」两项的内容都在「我的」页里（歌单卡 / 入口卡），
               *   所以这里不再各占一格 —— 被删掉的那两项的能力入口见
               *   `products/default` 的同名注释（`MinePage` 的二级页）。
               */
              Column() {
                MinePage()
              }
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
              .backgroundColor($r('app.color.pc_main_alt_background'))
              .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
            }
          }
          .width(StyleConstants.FULL_WIDTH)
          .layoutWeight(1)
          .mode(NavigationMode.Stack)
          .customNavContentTransition((from: NavContentInfo, _to: NavContentInfo,
            operation: NavigationOperation): NavigationAnimatedTransition | undefined => {
            return getPlaylistTransitionState().navigationReturn(this.getUIContext(), from, operation);
          })
          .hideTitleBar(true)
          .hideToolBar(true)
          .backgroundColor(this.mainContentBackgroundColor())
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .layoutWeight(1)
        .padding({ top: this.windowInfo.statusBarTopVp })
        .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .backgroundColor(this.mainContentBackgroundColor())
      }
      .sideBarPosition(SideBarPosition.Start)
      .showSideBar(true)
      .showControlButton(false)
      .sideBarWidth(200)
      .autoHide(false)
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .backgroundColor($r('app.color.pc_shell_background'))

      PlaylistTransitionOverlay()
        .zIndex(90)
        .hitTestBehavior(HitTestMode.Transparent)

      if (this.appState.isShowPlay) {
        Column() {
          PlaybackPageCoverContent()
        }
        .width(LayoutPolicy.matchParent)
        .height(LayoutPolicy.matchParent)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
        .zIndex(100)
      }

      MorphMetaBridge()
        .zIndex(110)
        .hitTestBehavior(HitTestMode.None)

      // Persistent hidden LX source engine host (webview sandbox for user API scripts).
      LXSourceHost()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // 形变宿主：`getRectangleById(MORPH_HOST_ID)` 量的就是这层的渲染矩形
    .id(MORPH_HOST_ID)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
    // ★ 形变几何的来源：本容器恒为满屏、不参与形变，它的实测尺寸就是"铺满"目标。
    //   （手机壳不行 —— 那边的 `MORPH_HOST_ID` 是播放页自己的根容器，高度就是裁剪窗口，
    //     所以手机壳只按 `windowSize` 上报窗口尺寸，见 products/default/.../Index.ets）
    //   坐标一律**窗口坐标**，不做原点换算。
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.expandState.reportHost(areaLengthToVp(newArea.width), areaLengthToVp(newArea.height));
      this.expandState.reportWindow(areaLengthToVp(newArea.width), areaLengthToVp(newArea.height));
      this.expandState.updateChromeTier(areaLengthToVp(newArea.width));
    })
  }

  /**
   * 系统返回：播放页开着就先让它播收起动画，并消费掉这次返回。
   *
   * PC 壳层的播放页一直是 Stack 里的浮层（没有模态兜底），所以这里必须自己拦，
   * 否则返回会直接退出应用。
   * @returns true = 已消费
   */
  onBackPress(): boolean {
    if (!this.appState.isShowPlay) {
      return false;
    }
    this.expandState.requestCollapse();
    return true;
  }
}
