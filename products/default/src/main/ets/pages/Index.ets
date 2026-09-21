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

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { HdsNavigation, hdsMaterial } from '@kit.UIDesignKit';
import {
  AmbientState,
  AppStorageKeys,
  getWindowInfoState,
  HomeSourceState,
  MusicAppState,
  MusicDbApi,
  MusicStoreService,
  PlaybackIntentState,
  PlaybackShellConstants,
  ShowMiniLyricState,
  StyleConstants,
  TabSwitchState,
  ThemeState,
  WindowInfo,
  WindowUtil
} from 'musicbasic';
import { dispatchShellPlaybackIntent, LXSourceHost, PlaybackPageCoverContent } from 'player';
import { RecommendPage } from 'recommendation';
import { HomeMiniBarPlayer, PlaylistsPage } from 'playlist';
import { MinePage, SettingPage } from 'setting';
import { localMusic } from 'localmusic';
import { syncManager } from 'sync';
import { common } from '@kit.AbilityKit';
import { HdsBarStyle, HdsTabs } from '@hms.hds.hdsBaseComponent';
import { deviceInfo } from '@kit.BasicServicesKit';

/**
 * Default phone shell: tabbed home with recommendation feed, floating mini player (API 601+),
 * and full-screen playback when MusicAppState.isShowPlay is true.
 */
@Entry
@ComponentV2
struct Index {
  /** Navigation stack for HdsNavigation routes and modal playback cover. */
  @Provider('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Reactive window width / height breakpoint from the system. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Index of the selected bottom tab (0 = home), shared for cross-tab navigation. */
  @Local tabState: TabSwitchState =
    AppStorageV2.connect(TabSwitchState, AppStorageKeys.TAB_SWITCH_STATE, () => new TabSwitchState())!;
  /** Bottom-bar immersive material level, reactive to settings changes. */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /** App accent color, reactive to settings changes. */
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** Home recommendation source, reactive to settings changes. */
  @Local homeSourceState: HomeSourceState =
    AppStorageV2.connect(HomeSourceState, AppStorageKeys.HOME_SOURCE_STATE, () => new HomeSourceState())!;
  /** Playback page mini lyric switch, reactive to settings changes. */
  @Local miniLyricState: ShowMiniLyricState =
    AppStorageV2.connect(ShowMiniLyricState, AppStorageKeys.SHOW_MINI_LYRIC_STATE, () => new ShowMiniLyricState())!;
  /** Shared playback and UI state (queue, mini bar, full-screen flag). */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** External intents (e.g. deep link) that request opening the player shell. */
  @Local intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!;
  /** Cached window metrics (safe areas, size) for layout padding. */
  @Local windowInfo: WindowInfo = getWindowInfoState();

  /** Initializes play queue ids from local DB for the session. */
  aboutToAppear() {
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto) => dto.id);
    this.ambientState.level = MusicStoreService.getInstance().getAmbientLevel();
    this.themeState.color = MusicStoreService.getInstance().getThemeColor();
    this.homeSourceState.source = MusicStoreService.getInstance().getHomeSource();
    this.miniLyricState.enabled = MusicStoreService.getInstance().getShowMiniLyric();
    AppStorage.setOrCreate('lxPlayQuality', MusicStoreService.getInstance().getPlayQuality());
    // 本地音乐库与同步客户端在启动时初始化：本地音乐要建沙箱目录并载入索引，
    // 同步客户端要读回服务器地址与开关（开关为关时不连服务端）。
    const hostContext: common.UIAbilityContext | undefined =
      this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (hostContext !== undefined) {
      localMusic.init(hostContext);
      syncManager.init(hostContext);
    }
  }

  /** Dispatches playback shell intent when {@link PlaybackIntentState.requestVersion} changes. */
  @Monitor('intentState.requestVersion')
  onPlaybackIntentChanged() {
    dispatchShellPlaybackIntent(this.appState, this.intentState, () => {
      this.getUIContext().animateTo({
        duration: PlaybackShellConstants.OPEN_PLAYER_UI_ANIMATION_MS,
        curve: Curve.EaseInOut
      }, () => {
        this.appState.isShowPlay = true;
      });
    });
  }

  /** Bottom inset (vp) for the floating tab bar; smaller on short-height SM layout. */
  private homeTabBarBottomMarginVp(): number {
    const compactLayout: boolean = this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD;
    const liveInset: number = this.windowInfo.navigationBarBottomVp;
    const systemInset: number = liveInset > 0 ? liveInset :
      WindowUtil.getInstance().getStartupNavigationBarBottomVp();
    const base: number = compactLayout ? 16 : systemInset;
    return Math.max(base, systemInset);
  }

  /** Small-width breakpoint (vp) for floating bar responsive layout. */
  private floatingBarSmallWidthVp(): number {
    const wPx = this.windowInfo.windowSize.width;
    if (wPx > 0) {
      const wVp = this.getUIContext().px2vp(wPx);
      return wVp - 96;
    }
    return 264;
  }

  /** Ambient level (0=follow system, 1=weak, 2=balanced, 3=strong). */
  private ambientLevelIndex(): number {
    return this.ambientState.level;
  }

  /** Single bottom-tab label: icon + title, styled by selection. */
  @Builder
  private TabBarItem(index: number, title: Resource, symbol: Resource) {
    Column({ space: 4 }) {
      SymbolGlyph(symbol)
        .fontSize(22)
        .fontWeight(FontWeight.Regular)
        .height(22)
        .fontColor([this.tabState.tabIndex === index ? this.themeState.color : $r('sys.color.icon_primary')])
      Text(title)
        .fontSize(11)
        .fontColor(this.tabState.tabIndex === index ? this.themeState.color : $r('sys.color.icon_primary'))
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(16)
  }

  /** Syncs expanded/collapsed mini bar style into {@link MusicAppState.miniBarExpanded}. */
  private onMiniBarStyleChange(miniBarStyle: HdsBarStyle): void {
    if (miniBarStyle === HdsBarStyle.EXPAND) {
      this.appState.miniBarExpanded = true;
    } else {
      this.appState.miniBarExpanded = false;
    }
  }

  /** Compact mini player row shown inside the floating HDS bar. */
  @Builder
  private miniBar() {
    Column() {
      HomeMiniBarPlayer({ showPreviousTrack: false })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  /** Tab pages: recommend, playlist (history/favorites), mine, settings. */
  @Builder
  private HomeTabsPages() {
    TabContent() {
      Column() {
        RecommendPage({ shellProvidesFloatingMiniBar: deviceInfo.distributionOSApiVersion >= 60100 })
          .layoutWeight(1)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .tabBar(this.TabBarItem(0, $r('app.string.tab_home'), $r('sys.symbol.house_fill')))

    TabContent() {
      Column() {
        PlaylistsPage()
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(1, $r('app.string.tab_music_hall'), $r('sys.symbol.auditorium')))

    TabContent() {
      Column() {
        MinePage()
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(2, $r('app.string.tab_cafe_listen'), $r('sys.symbol.person_crop_circle_fill_1')))

    TabContent() {
      Column() {
        SettingPage()
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .tabBar(this.TabBarItem(3, $r('app.string.tab_mine'), $r('sys.symbol.gearshape_fill')))
  }

  /** Root UI: {@link HdsNavigation} with tabs and optional playback cover. */
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      HdsNavigation(this.pageIndexInfos) {
        if (deviceInfo.distributionOSApiVersion >= 60100) {
          HdsTabs({ barPosition: BarPosition.End }) {
            this.HomeTabsPages()
          }
          .barMode(BarMode.Fixed)
          .barHeight(56)
          .zIndex(1)
          .barOverlap(true)
          .barPosition(BarPosition.End)
          .vertical(false)
          .scrollable(true)
          .barFloatingStyle({
            barWidth: {
              smallWidth: this.floatingBarSmallWidthVp(),
              mediumWidth: 284,
              largeWidth: 328
            },
            barBottomMargin: this.homeTabBarBottomMarginVp(),
            systemMaterialEffect: this.ambientLevelIndex() === 1 ?
              { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.SMOOTH } :
              this.ambientLevelIndex() === 2 ?
                { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.GENTLE } :
                this.ambientLevelIndex() === 3 ?
                  { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.EXQUISITE } :
                  { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
            miniBar: {
              miniBarBuilder: (): void => {
                this.miniBar();
              },
              onBarStyleChange: (miniBarStyle: HdsBarStyle): void => {
                this.onMiniBarStyleChange(miniBarStyle);
              }
            }
          })
          .onChange((index: number) => {
            this.tabState.tabIndex = index;
          })
          .height(StyleConstants.FULL_HEIGHT)
          .width(StyleConstants.FULL_WIDTH)
        } else {
          HdsTabs({ barPosition: BarPosition.End }) {
            this.HomeTabsPages()
          }
          .barMode(BarMode.Fixed)
          .barHeight(56)
          .zIndex(1)
          .barOverlap(true)
          .barPosition(BarPosition.End)
          .vertical(false)
          .scrollable(true)
          .padding({ bottom: WindowUtil.getInstance().getStartupNavigationBarBottomVp() })
          .onChange((index: number) => {
            this.tabState.tabIndex = index;
          })
          .height(StyleConstants.FULL_HEIGHT)
          .width(StyleConstants.FULL_WIDTH)
        }
      }
      .mode(NavigationMode.Stack)
      .backgroundColor($r('app.color.home_page_background'))
      .hideTitleBar(true)
      .hideToolBar(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .bindSheet($$this.appState.isShowPlay, PlaybackPageCoverContent(), {
        height: '100%',
        dragBar: false,
        showClose: false,
        backgroundColor: Color.Transparent,
        preferType: SheetType.BOTTOM,
        maskColor: $r('sys.color.ohos_id_color_mask_thin')
      })

      // Persistent hidden LX source engine host (webview sandbox for user API scripts).
      LXSourceHost()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }
}