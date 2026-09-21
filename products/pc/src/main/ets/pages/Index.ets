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
import { HdsNavigation } from '@kit.UIDesignKit';
import {
  AppStorageKeys,
  getWindowInfoState,
  MusicAppState,
  MusicDbApi,
  MusicStoreService,
  PlaybackIntentState,
  PlaybackShellConstants,
  StyleConstants,
  TabSwitchState,
  ThemeState,
  WindowInfo
} from 'musicbasic';
import { dispatchShellPlaybackIntent, LXSourceHost, PlaybackPageCoverContent } from 'player';
import { RecommendPage } from 'recommendation';
import { PlaylistsPage } from 'playlist';
import { MinePage, SettingPage } from 'setting';
import { localMusic } from 'localmusic';
import { syncManager } from 'sync';
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

  /** Initializes play queue from the local database. */
  aboutToAppear() {
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto) => dto.id);
    this.themeState.color = MusicStoreService.getInstance().getThemeColor();
    AppStorage.setOrCreate('lxPlayQuality', MusicStoreService.getInstance().getPlayQuality());
    // 本地音乐库与同步客户端在启动时初始化（与手机端入口一致）。
    const hostContext: common.UIAbilityContext | undefined =
      this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (hostContext !== undefined) {
      localMusic.init(hostContext);
      syncManager.init(hostContext);
    }
  }

  /** Handles playback intent changes and animates opening the in-app player. */
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
          this.SideNavItem(1, $r('app.string.tab_music_hall'), $r('sys.symbol.auditorium'));
          this.SideNavItem(2, $r('app.string.tab_cafe_listen'), $r('sys.symbol.person_crop_circle_fill_1'));
          this.SideNavItem(3, $r('app.string.tab_mine'), $r('sys.symbol.gearshape_fill'));
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
          if (this.tabState.tabIndex === 0) {
            Column() {
              HdsNavigation(this.pageIndexInfos) {
                RecommendPage()
              }
              .width(StyleConstants.FULL_WIDTH)
              .layoutWeight(1)
              .mode(NavigationMode.Stack)
              .hideTitleBar(true)
              .hideToolBar(true)
              .backgroundColor($r('sys.color.slider_outset_and_none_track_color'))
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
          } else if (this.tabState.tabIndex === 1) {
            Column() {
              HdsNavigation(new NavPathStack()) {
                PlaylistsPage()
              }
              .width(StyleConstants.FULL_WIDTH)
              .layoutWeight(1)
              .mode(NavigationMode.Stack)
              .hideTitleBar(true)
              .hideToolBar(true)
              .backgroundColor($r('app.color.pc_main_alt_background'))
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
          } else if (this.tabState.tabIndex === 2) {
            Column() {
              HdsNavigation(new NavPathStack()) {
                MinePage()
              }
              .width(StyleConstants.FULL_WIDTH)
              .layoutWeight(1)
              .mode(NavigationMode.Stack)
              .hideTitleBar(true)
              .hideToolBar(true)
              .backgroundColor($r('app.color.pc_main_alt_background'))
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
          } else {
            Column() {
              HdsNavigation(new NavPathStack()) {
                SettingPage()
              }
              .width(StyleConstants.FULL_WIDTH)
              .layoutWeight(1)
              .mode(NavigationMode.Stack)
              .hideTitleBar(true)
              .hideToolBar(true)
              .backgroundColor($r('app.color.pc_main_alt_background'))
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
          }
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

      if (this.appState.isShowPlay) {
        Column() {
          PlaybackPageCoverContent()
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .zIndex(100)
      }

      // Persistent hidden LX source engine host (webview sandbox for user API scripts).
      LXSourceHost()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
  }
}
