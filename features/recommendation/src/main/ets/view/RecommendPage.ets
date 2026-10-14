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

import { guardPlayerBack } from 'musicbasic';
import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import {
  AmbientState,
  AppStorageKeys,
  areaLengthToVp,
  BarScrollHelper,
  BreakpointType,
  getWindowInfoState,
  HomePlazaState,
  HomeRankingState,
  HomeSourceState,
  ImmersiveType,
  Logger,
  MusicAppState,
  MusicStoreService,
  registerHomeSourceRefresh,
  RouterUrlConstants,
  SdkApiUtil,
  SdkConstants,
  SongConstants,
  StyleConstants,
  TitleBarConstants,
  unregisterHomeSourceRefresh,
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

/**
 * 首页滚动位置「记录 + 恢复」补位的最大帧数。
 *
 * 内容没量完高时 `scrollTo` 会被夹在可滚范围内 —— 补不到目标就下一帧再补，
 * 补到 / 超帧数 / 用户自己滚过就收手。
 */
const HOME_SCROLL_RESTORE_MAX_FRAMES: number = 10;
/** 判定"补到位"的容差（vp）：小于它就认为已经在目标位置了。 */
const HOME_SCROLL_RESTORE_EPS_VP: number = 1;

@ComponentV2
export struct RecommendPage {
  @Param shellProvidesFloatingMiniBar: boolean = false;
  /**
   * 壳层双层底栏「上下两排」时额外占用的底部高度（vp）。
   * 迷你条与页签分两排后，滚动到底的最后一行会被第二条遮住，必须由壳层告知。
   */
  @Param floatingBarExtraBottomReserveVp: number = 0;
  /**
   * 「回到顶部」指令（壳层在**点击当前页签**时递增）。
   *
   * 底部页签设计规范要求：点击已选中的页签要把界面回滚至顶部。
   */
  @Param scrollTopCommand: number = 0;
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
  /**
   * 上一次**已经按它加载过**的首页来源平台值。
   *
   * 用途：`@Monitor` 与刷新总线（见 common/musicbasic 的 HomeSourceBus）可能对同一次
   * 设置改动都触发一次，另外从设置页切回首页时还要再兜底复查一次 —— 靠这个字段去重，
   * 保证同一个平台值只真正重载一次。
   */
  private loadedHomeSource: string = '';
  /**
   * 首页垂直滚动的**当前位置**（vp）。
   *
   * 「位置停留」的记录面：由 {@link onHomeScrollDidScroll} 每帧记录
   * （`Scroller.currentOffset().yOffset`），容器被重建时按它补回去。
   *
   * ⚠️ 为什么需要它：首页**唯一**的垂直滚动容器挂在
   * `if (this.recommendViewModel.homeLoaded)` 这个条件分支上，而
   * `RecommendViewModel.load()` 第 235 行会把 `homeLoaded` 置回 **false**
   * （切平台、从设置页切回首页的可见性兜底复查都会走）⇒ **分支反转 = 容器销毁重建
   * = 偏移归 0**。`Scroll` 实例自己不会重置偏移，是这个重建把它吃掉的。
   * 全仓**没有任何** `scrollTo({y:0})` 之类的"主动重置"，唯一的归零入口是壳层
   * 点当前页签时的 `@Monitor('scrollTopCommand')`（那条**必须先清零本字段**）。
   */
  private homeScrollOffsetVp: number = 0;
  /** 本次挂载是否还需要把偏移补回去（`onAttach` 置位，补到位/放弃后清掉）。 */
  private homeScrollRestorePending: boolean = false;
  /** 本次挂载已经重试补位的帧数（上限 {@link HOME_SCROLL_RESTORE_MAX_FRAMES}）。 */
  private homeScrollRestoreTries: number = 0;
  /** 本帧 `scrollTo` 之前量到的偏移；-1 = 还没补过。用于区分"没补动"与"用户滚了"。 */
  private homeScrollRestoredToVp: number = -1;

  /** 四个分类 Tab：「吸顶副本」当前是否显示（由 {@link onHomeScrollDidScroll} 按偏移判定）。 */
  @Local chipStickyActive: boolean = false;
  /** 分类 Tab 行**在滚动内容里的顶边**（vp）；0 = 还没量到（此时不判吸顶）。 */
  private chipRowTopInContentVp: number = 0;
  /** 分类 Tab 行**自身高度**（vp），量到之前用 0（吸顶副本高度取不到时按 0 放置，下一帧就补上）。 */
  @Local chipRowHeightVp: number = 0;

  aboutToAppear() {
    // 首页歌单广场/排行榜开关：从持久化设置同步到共享状态（默认关闭）
    this.homePlazaState.enabled = MusicStoreService.getInstance().getShowHomePlaza();
    this.homeRankingState.enabled = MusicStoreService.getInstance().getShowHomeRanking();
    this.loadedHomeSource = this.homeSourceState.source;
    this.recommendViewModel.load();
    // 设置页写完平台值后会显式通知一次（常驻 Tab 页只靠 @Monitor 不可靠，见 HomeSourceBus 注释）
    registerHomeSourceRefresh((): void => {
      this.applyHomeSourceIfChanged();
    });
  }

  aboutToDisappear() {
    unregisterHomeSourceRefresh();
  }

  /** 壳层点了当前页签：滚回顶部（值变化才触发，所以不会误滚）。 */
  @Monitor('scrollTopCommand')
  onScrollTopCommand(): void {
    // ★ 顺序：**先把记录清零**，再滚。
    //   否则"回顶"只改了框架里的偏移，记录还是旧值 —— 下一次容器重建
    //   （切平台 / 从设置页切回）又会把用户**拉回原来那个位置**，看着像"回顶没生效"。
    this.resetHomeScrollRecord();
    this.pageScroller.scrollEdge(Edge.Top);
    Logger.info('RzdHomeScroll', `scroll top command: record reset to 0 tries=${this.homeScrollRestoreTries}`);
  }

  /** 位置记录清零（点当前页签回顶部时用；恢复相关状态一并收干净）。 */
  private resetHomeScrollRecord(): void {
    this.homeScrollOffsetVp = 0;
    this.homeScrollRestorePending = false;
    this.homeScrollRestoreTries = 0;
    this.homeScrollRestoredToVp = -1;
  }

  /**
   * 首页滚动容器**每次挂载**都会走这里（`homeLoaded` 反转导致的重建也会走）。
   *
   * ⚠️ **这里是上一版没做对的地方，写清楚留给下一次**：
   *   上一版只在 `onAttach` 里置一个 `pending`，真正补位放在 `onDidScroll` 里
   *   —— 而 `onDidScroll` **只有真正发生滚动时才回调**（官方 `OnScrollCallback`：
   *   "列表滑动时触发"；`scrollEdge` / 不带动画的 `scrollToIndex` **不触发**它）。
   *   容器刚重建时偏移是 0、用户手指也没动 ⇒ **`onDidScroll` 一次都不会来
   *   ⇒ `pending` 永远等不到人来消费 ⇒ 位置永远补不回去**。
   *   这就是上一轮"加了逻辑但实测仍然不能停"的根因：**恢复的触发源选错了**。
   *
   * 本版两条恢复路径**都不依赖 `onDidScroll`**：
   *   ① 渲染期的 `initialOffset`（首选，见 build() 里那一句）：它在**首次布局**时
   *      就把偏移定好，既没有"先画在顶部再跳一下"的闪，也不需要等量测；
   *   ② 这里的帧循环（兜底 + 留证据）：`onAttach` 之后连补若干帧，
   *      每帧读一次真实偏移 —— 内容还没量完高时 `scrollTo` 会被夹住，
   *      那就下一帧再来，直到补到位 / 超帧数 / 用户自己滚过。
   *
   * 为什么"补不动"时按 `homeScrollOffsetVp > 0` 就敢放手：容器刚重建时偏移必然从 0 起，
   * 读过一次真实偏移之后 ② 的判据就变成"目标 vs 实测"而不是"目标 vs 0"，
   * 所以不会出现"把用户滚动误判成补位、每帧抢一次滚动"。
   */
  private onHomeScrollAttach(): void {
    this.homeScrollRestorePending = this.homeScrollOffsetVp > 0;
    this.homeScrollRestoreTries = 0;
    this.homeScrollRestoredToVp = -1;
    // 分类 Tab 顶边随容器重建一起作废：静止态那次 onAreaChange 会把它重新标成 0。
    this.chipRowTopInContentVp = 0;
    this.chipStickyActive = false;
    Logger.info('RzdHomeScroll',
      `attach target=${this.homeScrollOffsetVp} pending=${this.homeScrollRestorePending}`);
    if (this.homeScrollRestorePending) {
      this.restoreHomeScrollNextFrame();
    } else {
      this.logHomeScrollOffset('first-layout');
    }
  }

  /** 排一帧回调，在下一帧继续尝试补位（见 {@link restoreHomeScrollNextFrame}）。 */
  private restoreHomeScrollNextFrame(): void {
    // ⚠️ 这里**不要**用 `UIContext.postFrameCallback`：本机 SDK 里
    //    `FrameCallback` 是 **abstract class**（`@ohos.arkui.UIContext.d.ts`，方法 `onFrame(frameTimeInNano)`），
    //    传裸函数或 `{ onFrame: … }` 字面量都会编译报
    //    `Argument of type '…' is not assignable to parameter of type 'FrameCallback'`（已实测两次）。
    //    工程里要帧循环的那处（`AmllLyricView`）是老老实实 `class FrameTicker extends FrameCallback`；
    //    这里只需要"下一帧再试一次"，用 `setTimeout(…, 16)` 最省 —— 与形变补量那条路同一手法。
    setTimeout((): void => {
      this.restoreHomeScrollOnFrame();
    }, 16);
  }

  /**
   * 帧循环里的一次补位尝试。
   *
   * 三件事按顺序做（顺序不能颠倒）：
   *   ① 读**真实**偏移（`Scroller.currentOffset()`）—— 不信任记录值；
   *   ② 判定：到位 / 用户已经自己滚过（放弃，别和用户抢）/ 超帧数（放弃）/ 还要再补；
   *   ③ 还要再补时 `scrollTo`（无动画），下一帧回来读结果。
   */
  private restoreHomeScrollOnFrame(): void {
    if (!this.homeScrollRestorePending) {
      return;
    }
    const offset: number = this.readHomeScrollOffset();
    const target: number = this.homeScrollOffsetVp;
    if (Math.abs(offset - target) < HOME_SCROLL_RESTORE_EPS_VP) {
      this.homeScrollRestorePending = false;
      this.homeScrollRestoredToVp = -1;
      Logger.info('RzdHomeScroll', `restored offset=${offset} tries=${this.homeScrollRestoreTries}`);
      return;
    }
    if (this.homeScrollRestoredToVp >= 0 &&
      Math.abs(offset - this.homeScrollRestoredToVp) >= HOME_SCROLL_RESTORE_EPS_VP) {
      // 补过一次之后偏移**又变了** ⇒ 那是用户自己滚的：放手，别抢滚动
      this.homeScrollRestorePending = false;
      this.homeScrollRestoredToVp = -1;
      Logger.info('RzdHomeScroll', `restore cancelled by user scroll offset=${offset} target=${target}`);
      return;
    }
    if (this.homeScrollRestoreTries >= HOME_SCROLL_RESTORE_MAX_FRAMES) {
      // 补了这么多帧还不到位（内容比原来矮、或偏移已被夹到可滚范围）：放手
      this.homeScrollRestorePending = false;
      this.homeScrollRestoredToVp = -1;
      Logger.info('RzdHomeScroll', `restore gave up offset=${offset} target=${target} tries=${this.homeScrollRestoreTries}`);
      return;
    }
    this.homeScrollRestoreTries = this.homeScrollRestoreTries + 1;
    this.homeScrollRestoredToVp = offset;
    this.pageScroller.scrollTo({ xOffset: 0, yOffset: target, animation: false });
    Logger.info('RzdHomeScroll', `restore target=${target} from=${offset} try=${this.homeScrollRestoreTries}`);
    this.restoreHomeScrollNextFrame();
  }

  /** @returns 当前垂直偏移（vp）；控制器还没绑定到组件时按 0 处理。 */
  private readHomeScrollOffset(): number {
    try {
      return Math.max(0, this.pageScroller.currentOffset().yOffset);
    } catch (_err) {
      // Scroller 未绑定组件时会抛异常（官方 contentSize 那段说明）⇒ 视作 0
      return 0;
    }
  }

  /**
   * 首页滚动容器每帧的**偏移记录** + 「分类 Tab 吸顶」判定。
   *
   * ⚠️ 为什么不用 `onScroll`：官方已把它标为 `@deprecated since 12`，
   *   `@useinstead ScrollableCommonMethod#onDidScroll`。
   * 记录用 `onDidScroll` + `Scroller.currentOffset()`（与 `PlaylistDetailPage` 量滚动位置同一套写法）。
   *
   * ⚠️ `onDidScroll` 的回调入参是**本帧增量**不是绝对偏移（Scroll 的
   *   `ScrollOnScrollCallback = (xOffset, yOffset, scrollState)` ⇒ d.ts 里就是"本帧偏移量"），
   *   所以要**绝对位置**必须回调 `currentOffset()` —— 这一点别改回去。
   *
   * @param _frameDelta 本帧滚动增量（不参与计算，留着按官方签名接）。
   * @param scrollState 本帧滚动状态；`Idle` = 框架/控制器发起的（不是用户滚动）。
   */
  private onHomeScrollDidScroll(_frameDelta: number, scrollState: ScrollState): void {
    const offset: number = this.readHomeScrollOffset();
    // ① 记录：只在**用户真的滚**的时候记（Idle 是控制器/框架自己滚出来的，记它没意义）
    if (scrollState === ScrollState.Scroll || scrollState === ScrollState.Fling) {
      if (Math.abs(offset - this.homeScrollOffsetVp) >= HOME_SCROLL_RESTORE_EPS_VP) {
        this.homeScrollOffsetVp = offset;
        Logger.info('RzdHomeScroll', `record offset=${offset}`);
      }
    }
    // ② 吸顶判定（同一份偏移，不另开滚动监听）
    this.updateChipSticky(offset);
  }

  /** 记录态的一次性日志（无设备时靠它确认"容器确实重建过、目标值是多少"）。 */
  private logHomeScrollOffset(stage: string): void {
    Logger.info('RzdHomeScroll', `${stage} offset=${this.readHomeScrollOffset()} target=${this.homeScrollOffsetVp}`);
  }

  /** 分类 Tab 行在滚动内容里的顶边（静止态量到的那次就是它的内容坐标）。 */
  private onChipRowAreaChange(area: Area): void {
    const height: number = areaLengthToVp(area.height);
    if (height > 0 && Math.abs(height - this.chipRowHeightVp) > 0.5) {
      this.chipRowHeightVp = height;
    }
    // 静止态（偏移 0）量到的顶边 = 该行在**滚动内容**里的位置；
    // 滚动中它也会变（那是视口坐标，不是内容坐标）⇒ 只在偏移 ~0 时采纳。
    if (this.readHomeScrollOffset() < HOME_SCROLL_RESTORE_EPS_VP) {
      this.chipRowTopInContentVp = areaLengthToVp(area.position.y);
    }
    Logger.info('RzdHomeScroll',
      `chip area h=${height} top=${this.chipRowTopInContentVp} sticky=${this.chipStickyActive}`);
  }

  /**
   * 分类 Tab 吸顶判定：这一行的**下边沿**越过吸顶线就显示"吸顶副本"。
   *
   * 为什么用下边沿（`top + height`）而不是顶边：用顶边时行"半截还露着"就提前钉住了，
   * 视觉上会跳一下；用下边沿 = 原位置那一行**完整滑出视口顶**的瞬间才接管 ——
   * 这正是 `List` 的 `sticky` 语义（一行完整离开才吸附）。
   * @param offset 当前垂直偏移（vp）。
   */
  private updateChipSticky(offset: number): void {
    if (this.chipRowTopInContentVp <= 0) {
      // 还没量到那一行的位置（首帧）⇒ 不判吸顶，免得闪一下
      return;
    }
    const stickLine: number = this.contentTopInsetVp();
    const active: boolean = offset > this.chipRowTopInContentVp - stickLine + this.chipRowHeightVp;
    if (active !== this.chipStickyActive) {
      this.chipStickyActive = active;
      Logger.info('RzdHomeScroll',
        `sticky=${active} offset=${offset} rowTop=${this.chipRowTopInContentVp} rowH=${this.chipRowHeightVp} line=${stickLine}`);
    }
  }

  /**
   * 吸顶线（vp）：吸气顶副本那一行的**顶边**落在哪里。
   *
   * 非沉浸式 = 「状态栏 + HDS 标题栏」（`statusBarTopVp + ROW_HEIGHT_VP` ≈ 38 + 56 = 94），
   * 与滚动内容顶部那段留白**同一个数**（见 build() 里内容根的 `padding.top`）——
   * 这样副本落在标题栏下沿、**不盖标题栏**（两处必须同进同出：改一处就要改另一处）。
   * 沉浸式 = 没有 HDS 标题栏（内容从 y=0 起排）⇒ 吸顶线就是 0。
   */
  private contentTopInsetVp(): number {
    if (this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE) {
      return 0;
    }
    return this.windowInfo.statusBarTopVp + TitleBarConstants.ROW_HEIGHT_VP;
  }

  /**
   * 页签重新可见时兜底复查一次。
   *
   * 用户是在**「设置」Tab 里**改的平台，改完切回首页 —— 这条路径上 @Monitor / 总线
   * 任意一条没生效，用户看到的就是"改了设置，首页没变"。这里用一个很便宜的判据
   * （当前平台值 vs 已加载的平台值）再兜一层，代价只是一次字符串比较。
   *
   * @param isVisible 当前是否可见（不可见时直接返回，不做任何事）。
   */
  private onHomeVisibleChanged(isVisible: boolean): void {
    if (!isVisible) {
      return;
    }
    this.applyHomeSourceIfChanged();
  }

  /** 平台值确实变了才重载首页（多条触发路径共用这一道闸）。 */
  private applyHomeSourceIfChanged(): void {
    const source: string = this.homeSourceState.source;
    if (source === this.loadedHomeSource) {
      return;
    }
    this.loadedHomeSource = source;
    Logger.info('RzdHomeSource', `page reload source=${source}`);
    this.recommendViewModel.load();
  }

  /** Routes to the online multi-source search page. */
  private openSearch(): void {
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.ONLINE_SEARCH, null);
  }

  /** HDS title bar with system material and gradient blur. */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    return {
      // ★ 2026-10-11 真机定论（设置页截图量出来的）：HDS 标题栏容器本来就在状态栏下沿，
      //   voidLayoutSafeArea: true 会让它**再退一个状态栏**（标题 76..132）⇒ 恒为 false（标题 38..94）。
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
    this.applyHomeSourceIfChanged();
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
          // ★ 滚动容器**仍然是 `Scroll`**（本轮一个字都没改成 `List`）——
          //   外层只多套一层 `Stack`，用来在**同一层**叠"四个分类 Tab 的吸顶副本"。
          Stack({ alignContent: Alignment.TopStart }) {
            Scroll(this.pageScroller) {
              Column() {
                HeroBannerSection({ recommendViewModel: this.recommendViewModel })
                // 四个分类 Tab 那一行：外面包一层只负责**量它**（顶边 / 高度）的容器，
                // 不参与任何布局决策 —— 原来的位置、留白、点击行为逐字未动。
                Column() {
                  CategoryChipsSection({ recommendViewModel: this.recommendViewModel })
                }
                .width(StyleConstants.FULL_WIDTH)
                .onAreaChange((_old: Area, area: Area): void => {
                  this.onChipRowAreaChange(area);
                })

                CategoryContentSection({ recommendViewModel: this.recommendViewModel })
                if (this.homePlazaState.enabled) {
                  HomePlazaSection({ recommendViewModel: this.recommendViewModel })
                }
              }
              .padding({
                top: this.contentTopInsetVp()
              })
            }
            // ⚠️ 这里**必须**是 `width/height 100%`，**不能**沿用 `layoutWeight(1)`：
            //   `layoutWeight` 只在 Row / Column / Flex 里生效，`Stack` 的子节点
            //   是按自身尺寸排的 ⇒ 在 Stack 里写 `layoutWeight(1)` 等于没有高度
            //   （表现就是整块空、或者只剩一小条）。撑满改由外层 Stack 的
            //   `layoutWeight(1)` + 这里的 `100%` 一起完成。
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .padding({
              bottom: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 16
            })
            .backgroundColor($r('app.color.background_secondary'))
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .clip(false)
            .align(Alignment.Top)
            // ★ 位置停留的**首选恢复路径**：`initialOffset` 只在**首次布局**生效
            //   （官方：「设置初始滚动偏移量。只在首次布局时生效」）——
            //   容器被 `homeLoaded` 反转销毁重建时正好又是一次"首次布局"，
            //   于是重建那一帧就带着记录值排布，**没有"先画在顶部再跳一下"的闪**，
            //   也不受"内容还没量完高、scrollTo 被夹住"的影响。
            //   ⚠️ 它是渲染期读的普通字段（不是 `@Local`）⇒ 偏移变化**不会**触发重渲染。
            .initialOffset({ xOffset: 0, yOffset: this.homeScrollOffsetVp })
            .onAttach((): void => {
              this.onHomeScrollAttach();
            })
            .onDidScroll((_frameDelta: number, scrollState: ScrollState): void => {
              this.onHomeScrollDidScroll(_frameDelta, scrollState);
            })
            .onScrollFrameBegin((offset: number): OnScrollFrameBeginHandlerResult => {
              return this.onHomeScrollFrameBegin(offset);
            })
            .onScrollStop((): void => {
              this.logHomeScrollOffset('scroll-stop');
            })

            // ★ 四个分类 Tab 的**吸顶副本**：只在"原位置那一行完整滑出视口顶"时出现
            //   （判据见 `updateChipSticky`），位置 = 吸顶线（非沉浸式 = 状态栏 + 标题栏 = 94）。
            //   ⚠️ 为什么吸顶线是 94：滚动内容顶部那段留白就是 `statusBarTopVp + ROW_HEIGHT_VP`
            //      （内容根的 `padding.top`），副本与它**同一个数** ⇒ 副本落在 HDS 标题栏下沿、
            //      **不盖标题栏**（两处必须同进同出）。
            //   ⚠️ 副本必须**不透明**：它下面是滚过去的卡片/列表，透明底会从底下透出来。
            //      这一行自己不带底色（它是 `Scroll` 横滑的胶囊行），所以这里补一层
            //      `Column` 铺 `app.color.background_secondary`（与整页底色同一个 token）。
            //   ⚠️ 原生 `List` 的 `sticky` 语义是"整行钉住"；这里整行钉在 94 处，
            //      行**上方**那一段（94 - 行高）在真机上会看到内容从标题栏底下穿过 ——
            //      那是 HDS 标题栏本来就要有的沉浸观感，故**不**把副本底拉到状态栏。
            if (this.chipStickyActive) {
              Column() {
                CategoryChipsSection({ recommendViewModel: this.recommendViewModel })
              }
              .width(StyleConstants.FULL_WIDTH)
              .backgroundColor($r('app.color.background_secondary'))
              .position({ y: this.contentTopInsetVp() })
              .zIndex(1)
            }
          }
          .width(StyleConstants.FULL_WIDTH)
          .layoutWeight(1)
        } else {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color($r('app.color.mini_bar_primary'))
            // ⚠️ 用户要求简洁：加载态只留转圈，**不再写"正在加载 QQ音乐·新歌榜…"这种说明文字**。
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
      // 从「设置」Tab 切回首页时兜底复查平台值（见 onHomeVisibleChanged 注释）。
      // 挂在页面内容根节点（内置组件）上而不是 HdsNavDestination 上：
      // 自定义组件上的事件属性在框架里不一定落到根节点，这里必须是**一定生效**的那一层。
      .onVisibleAreaChange([0.0], (isVisible: boolean, _ratio: number): void => {
        this.onHomeVisibleChanged(isVisible);
      })
    }
    .onBackPressed((): boolean => guardPlayerBack('RecommendPage'))
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
