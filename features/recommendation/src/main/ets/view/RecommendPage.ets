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
import {
  AmbientState,
  AppStorageKeys,
  BarScrollHelper,
  BreakpointType,
  getWindowInfoState,
  HomePlazaState,
  HomeRankingState,
  HomeSourceState,
  ImmersiveType,
  MusicAppState,
  MusicStoreService,
  RouterUrlConstants,
  SdkApiUtil,
  SdkConstants,
  SongConstants,
  StyleConstants,
  TitleBarConstants,
  UseAccountRecState,
  WindowInfo,
  buildTitleMaterial
} from 'musicbasic';
import { AccountChangedState, PlayerConstants } from 'player';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';
import { CategoryContentSection } from './CategoryContentSection';
import { HomeFloatingMiniBar } from './HomeFloatingMiniBar';
import { CategoryChipsSection } from './CategoryChipsSection';
import { HeroBannerSection } from './HeroBannerSection';
import { HomePlazaSection } from './HomePlazaSection';

@ComponentV2
export struct RecommendPage {
  @Param shellProvidesFloatingMiniBar: boolean = false;
  /**
   * 壳层双层底栏「上下两排」时额外占用的底部高度（vp）。
   * 迷你条与页签分两排后，滚动到底的最后一行会被第二条遮住，必须由壳层告知。
   */
  @Param floatingBarExtraBottomReserveVp: number = 0;
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local windowInfo: WindowInfo = getWindowInfoState();
  @Local recommendViewModel: RecommendViewModel = new RecommendViewModel();
  @Local homeSourceState: HomeSourceState =
    AppStorageV2.connect(HomeSourceState, AppStorageKeys.HOME_SOURCE_STATE, () => new HomeSourceState())!;
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  @Local useAccountRecState: UseAccountRecState =
    AppStorageV2.connect(UseAccountRecState, AppStorageKeys.USE_ACCOUNT_REC_STATE, () => new UseAccountRecState())!;
  /** 首页「歌单广场」模块开关（设置项控制，默认关闭）。 */
  @Local homePlazaState: HomePlazaState =
    AppStorageV2.connect(HomePlazaState, AppStorageKeys.HOME_PLAZA_STATE, () => new HomePlazaState())!;
  /** 首页「排行榜」模块开关（设置项控制，默认关闭）。 */
  @Local homeRankingState: HomeRankingState =
    AppStorageV2.connect(HomeRankingState, AppStorageKeys.HOME_RANKING_STATE, () => new HomeRankingState())!;
  @Local accountChangedState: AccountChangedState =
    AppStorageV2.connect(AccountChangedState, PlayerConstants.ACCOUNT_CHANGED_STATE, () => new AccountChangedState())!;
  /** 全局播控状态：滚动联动底栏时需要写 hdsBarLayoutMode / miniBarExpanded。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Scroller bound to the HDS title bar so the scroll effect (gradient blur) can fire. */
  private pageScroller: Scroller = new Scroller();

  aboutToAppear() {
    // 首页歌单广场/排行榜开关：从持久化设置同步到共享状态（默认关闭）
    this.homePlazaState.enabled = MusicStoreService.getInstance().getShowHomePlaza();
    this.homeRankingState.enabled = MusicStoreService.getInstance().getShowHomeRanking();
    this.recommendViewModel.load();
  }

  /** Routes to the online multi-source search page. */
  private openSearch(): void {
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.ONLINE_SEARCH, null);
  }

  /** HDS title bar with system material and gradient blur. */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        title: {
          mainTitle: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
            $r('app.string.home_page_title_pc') :
            $r('app.string.home_page_title'),
          mainTitleSize: TitleSize.TITLE_ML
        },
        menu: {
          value: [
            {
              content: {
                label: 'identify',
                icon: $r('sys.symbol.identify_song'),
                isEnabled: true,
                action: (): void => {
                  this.pageIndexInfos.pushPathByName(RouterUrlConstants.MUSIC_RECOGNITION, null);
                }
              }
            },
            {
              content: {
                label: 'search',
                icon: $r('sys.symbol.magnifyingglass'),
                isEnabled: true,
                action: (): void => {
                  this.openSearch();
                }
              }
            }
          ]
        }
      }
    };
  }

  @Monitor('homeSourceState.source')
  onHomeSourceChanged(): void {
    this.recommendViewModel.load();
  }

  @Monitor('useAccountRecState.enabled')
  onUseAccountRecChanged(): void {
    this.recommendViewModel.load();
  }

  @Monitor('accountChangedState.version')
  onAccountChanged(): void {
    this.recommendViewModel.load();
  }

  private homeFloatingMiniBarTabOverlapReserveBottomVp(): number {
    if (this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE) {
      return 0;
    }
    if (this.shellProvidesFloatingMiniBar) {
      // 悬浮 Tab 条（barOverlap，高 56 + 底部间距 16）叠在内容上方，
      // 不预留高度时滚动到底的最后一行会被遮挡（推荐/歌手/榜单共用本页 Scroll）。
      // 双层底栏「上下两排」时还要再加上迷你条那一排的高度。
      return 56 + 16 + this.floatingBarExtraBottomReserveVp;
    }
    return SdkApiUtil.isSdkApiAtLeast(SdkConstants.HDS_TABS_BAR_FLOATING_MIN_SDK_API) ? 0 : 56;
  }

  /**
   * 滚动帧开始回调：驱动双层底栏的收起/展开。
   *
   * 方向（按产品需求）：列表**上滑** → Tab 收起；列表**下滑** → Tab 展开。
   * `onScrollFrameBegin` 的 offset 就是本帧增量，直接交给 helper；返回值不消费滚动。
   * @param offset 本帧滚动增量（vp）。
   * @returns 不消费滚动：offsetRemain 原样返回。
   */
  private onHomeScrollFrameBegin(offset: number): OnScrollFrameBeginHandlerResult {
    if (this.shellProvidesFloatingMiniBar && BarScrollHelper.isEnabled()) {
      BarScrollHelper.notifyScrollDelta(this.getUIContext(), this.appState, offset,
        this.breakpointEnv.widthBreakpoint);
    }
    return { offsetRemain: offset };
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.recommendViewModel.homeLoaded) {
          Scroll(this.pageScroller) {
            Column() {
              HeroBannerSection({ recommendViewModel: this.recommendViewModel })
              CategoryChipsSection({ recommendViewModel: this.recommendViewModel })
              CategoryContentSection({ recommendViewModel: this.recommendViewModel })
              if (this.homePlazaState.enabled) {
                HomePlazaSection({ recommendViewModel: this.recommendViewModel })
              }
            }
            .padding({
              top: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
                0 : this.windowInfo.statusBarTopVp + TitleBarConstants.ROW_HEIGHT_VP
            })
          }
          .layoutWeight(1)
          .padding({
            bottom: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 16
          })
          .backgroundColor($r('app.color.background_secondary'))
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .clip(false)
          .align(Alignment.Top)
          .onScrollFrameBegin((offset: number): OnScrollFrameBeginHandlerResult => {
            return this.onHomeScrollFrameBegin(offset);
          })
        } else {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color($r('app.color.mini_bar_primary'))
          }
          .width(StyleConstants.FULL_WIDTH)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

        if (!this.shellProvidesFloatingMiniBar) {
          HomeFloatingMiniBar()
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .padding({ bottom: this.homeFloatingMiniBarTabOverlapReserveBottomVp() })
    }
    .hideTitleBar(false)
    .hideBackButton(true)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.background_secondary'))
  }

  pageTransition() {
    PageTransitionEnter({ duration: SongConstants.TRANSITION_DURATION, curve: Curve.Smooth, type: RouteType.Pop })
    PageTransitionExit({ duration: SongConstants.TRANSITION_DURATION, curve: Curve.Smooth, type: RouteType.Push })
  }
}
