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
import { HomeSongListSection } from './HomeSongListSection';

/**
 * 首页滚动位置恢复最多重试的帧数（见 {@link RecommendPage.onHomeListDidScroll}）。
 *
 * 容器刚重建时列表内容可能还没量完高度，`scrollTo` 会被夹到可滚范围；所以允许重试，
 * 但不能无限重试（否则用户滚动时每帧都在被"拽回"，看着像抢滚动）。
 */
const HOME_SCROLL_RESTORE_MAX_FRAMES: number = 10;

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
   * 首页滚动列表的**位置停留**（跨重建保住滚动偏移，vp）。
   *
   * 见 {@link onHomeListAttach} 的注释：首页滚动容器挂在
   * `if (this.recommendViewModel.homeLoaded)` 这个条件分支上，`RecommendViewModel.load()`
   * 会把 `homeLoaded` 置回 false（切平台、以及从设置页切回时的兜底复查都会走）⇒ 分支反转
   * = 容器**销毁重建** = 偏移归 0，用户看到的就是「切页签 / 进二级页再回来，首页跑回顶部」。
   * 偏移记在组件字段上（不是 `@Local`：滚动每帧都写，不需要驱动刷新），
   * 重建时由 `onAttach` → `pending` → `onDidScroll` 补回去。**不改渲染结构**（不改条件渲染、
   * 不把滚动容器改成常驻），所以不会牵动播放页形变起点（`MINI_BAR_ID` / 宿主矩形）的量测。
   */
  private homeScrollOffsetVp: number = 0;
  /** 本次挂载是否还需要把偏移补回去（`onAttach` 置位，补到位/放弃后清掉）。 */
  private homeScrollRestorePending: boolean = false;
  /** 本次挂载已经重试补位的帧数（上限 {@link HOME_SCROLL_RESTORE_MAX_FRAMES}）。 */
  private homeScrollRestoreTries: number = 0;
  /** 上一次尝试恢复时列表给出的偏移（vp）：用来判断"是不是用户自己滚的"（-1 = 还没有基线）。 */
  private homeScrollRestoredToVp: number = -1;
  /**
   * 上一次**已经按它加载过**的首页来源平台值。
   *
   * 用途：`@Monitor` 与刷新总线（见 common/musicbasic 的 HomeSourceBus）可能对同一次
   * 设置改动都触发一次，另外从设置页切回首页时还要再兜底复查一次 —— 靠这个字段去重，
   * 保证同一个平台值只真正重载一次。
   */
  private loadedHomeSource: string = '';

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
    // ★ 先归零"位置停留"的记录，否则下一次进来会被恢复回滚之前的位置，
    //   用户看到的就是「点了页签回到顶部，切出去再回来又跳下去了」。
    this.homeScrollOffsetVp = 0;
    this.homeScrollRestorePending = false;
    this.homeScrollRestoredToVp = 0;
    this.pageScroller.scrollEdge(Edge.Top);
    Logger.info('RzdHomeScroll', 'scroll top command: offset reset to 0');
  }

  /**
   * 首页滚动列表**挂载时**（含销毁重建、从二级页回来、切页签回来）记下"待恢复"。
   *
   * 根因：首页滚动容器（现在是 `List`，改前是 `Scroll`）挂在
   * `if (this.recommendViewModel.homeLoaded)` 这个条件分支上，而 `RecommendViewModel.load()`
   * 会把 `homeLoaded` 置回 false（切平台、以及从设置页切回时的兜底复查都会走）⇒ 分支反转
   * = 容器**销毁重建** = 偏移归 0。其余情况（同一实例上的滚动）偏移由框架自己保存，不受影响。
   *
   * 恢复分两步（`onAttach` 只标意向，真正补位在 `onDidScroll`）：
   *   ① 这里：置 `pending` 并复位重试计数 —— **不**在挂载回调里直接 `scrollTo`：
   *      那时列表首帧布局还没完成（官方对 List 的说明是"创建完成、首次布局前调
   *      scrollToIndex/scrollEdge 会覆盖 initialIndex"），像素偏移能不能被立刻接受没有保证，
   *      所以放到有滚动事件回来时补，最稳；
   *   ② {@link onHomeListDidScroll}：带 `pending` 时按目标偏移补（最多
   *      {@link HOME_SCROLL_RESTORE_MAX_FRAMES} 次，补不动就放手），补到位转回"记录"态。
   */
  private onHomeListAttach(): void {
    this.homeScrollRestorePending = this.homeScrollOffsetVp > 0;
    this.homeScrollRestoreTries = 0;
    this.homeScrollRestoredToVp = -1;
    Logger.info('RzdHomeScroll', `attach target=${this.homeScrollOffsetVp} pending=${this.homeScrollRestorePending}`);
  }

  /**
   * 首页滚动列表每帧的偏移记录 + 重建后的**位置补回**（任务 1）。
   *
   * ⚠️ 为什么不用 `onScroll`（那才是逐帧增量回调）：官方已把它标为 `@deprecated since 12`，
   *   `@useinstead ScrollableCommonMethod#onDidScroll`。这里沿用 `onDidScroll` +
   *   `Scroller.currentOffset()`（与 `PlaylistDetailPage` 量滚动位置同一套写法）。
   */
  private onHomeListDidScroll(): void {
    const offset: number = Math.max(0, this.pageScroller.currentOffset().yOffset);
    if (this.homeScrollRestorePending) {
      if (Math.abs(offset - this.homeScrollOffsetVp) < 1) {
        // 已站在目标位置（框架自己保住了重建、或者上一帧补到位了）⇒ 转回"记录"态
        this.homeScrollRestorePending = false;
        this.homeScrollRestoredToVp = -1;
        Logger.info('RzdHomeScroll', `restored offset=${offset} tries=${this.homeScrollRestoreTries}`);
        return;
      }
      if (this.homeScrollRestoreTries >= HOME_SCROLL_RESTORE_MAX_FRAMES) {
        // 补了这么多帧还没到位（内容比原来矮、或偏移已被夹到可滚范围）：放手，
        // 免得每一帧都发一次 scrollTo（用户滚动时看着像"抢滚动"）。
        this.homeScrollRestorePending = false;
        this.homeScrollRestoredToVp = -1;
        Logger.info('RzdHomeScroll', `restore gave up offset=${offset} target=${this.homeScrollOffsetVp}`);
      } else if (this.homeScrollRestoredToVp >= 0 && Math.abs(offset - this.homeScrollRestoredToVp) >= 1) {
        // 补过一次之后列表给的偏移**又变了** ⇒ 那是用户自己滚的，放弃恢复（不要和用户抢）
        this.homeScrollRestorePending = false;
        this.homeScrollRestoredToVp = -1;
        Logger.info('RzdHomeScroll', `restore cancelled by user scroll offset=${offset}`);
      } else {
        // 还没补到位 ⇒ 再补一次（容器刚重建时内容可能还没量完高，会被夹住）
        this.homeScrollRestoreTries = this.homeScrollRestoreTries + 1;
        this.homeScrollRestoredToVp = offset;
        this.pageScroller.scrollTo({ xOffset: 0, yOffset: this.homeScrollOffsetVp, animation: false });
        Logger.info('RzdHomeScroll',
          `restore target=${this.homeScrollOffsetVp} from=${offset} try=${this.homeScrollRestoreTries}`);
        return;
      }
    }
    // 记录态：用户滚到哪就记到哪（切页签 / 切平台重建时按它恢复）
    if (Math.abs(offset - this.homeScrollOffsetVp) >= 1) {
      this.homeScrollOffsetVp = offset;
    }
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

  /**
   * 首页滚动列表的**吸顶头部**：「精选 / 歌手 / 榜单 / 分类」那一行分类 Tab。
   *
   * 机制（`List` + `ListItemGroup({ header })` + `.sticky(StickyStyle.Header)`，
   * SDK `list.d.ts:sicky(value: StickyStyle)` / `StickyStyle.Header = 1`，**已核对 d.ts**）：
   * header 天然吸顶到**滚动视口顶边**；而本页视口已经在标题栏之下
   * （列表内容首项的顶部留白 = `状态栏 + ROW_HEIGHT_VP`），所以吸顶位置正好落在
   * HDS 标题栏下沿，不会盖住标题栏、也不受顶部安全区影响。
   *
   * ⚠️ 吸顶时这一行必须**不透明**：`CategoryChipsSection` 自己那一层是透明底
   *   （只有每个 chip 有底色），吸顶后下面的歌曲行会从它底下透出来 —— 所以这里套一层
   *   `Column` 并铺上页面底色（`app.color.background_secondary`，与整页底色同一个值）。
   *   另：d.ts 里 `sticky` 那条注释提到"浮点计算精度可能产生细小缝隙"，铺满底色同时兜住这个缝隙。
   */
  @Builder
  private StickyCategoryHeader() {
    Column() {
      CategoryChipsSection({ recommendViewModel: this.recommendViewModel })
    }
    .width(StyleConstants.FULL_WIDTH)
    .backgroundColor($r('app.color.background_secondary'))
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.recommendViewModel.homeLoaded) {
          // ★ 滚动容器 = 首页那个**唯一**的垂直 List（改前是 `Scroll`）。
          //
          //   为什么从 `Scroll` 换成 `List`：任务 2 要用 `ListItemGroup` 的 header 做吸顶
          //   （`Scroll` 没有吸顶能力）。换完三件事都还成立：
          //   ① 偏移仍然由同一个 `pageScroller` 管理 ⇒ HDS 标题栏的渐变模糊绑定不变
          //      （`.bindToScrollable([this.pageScroller])` 还在，§29.3 那条坑不碰）；
          //   ② 顶部留白仍在**滚动内容**里（作为第一个 `ListItemGroup` 的顶部 padding），
          //      所以"内容能一路滚进状态栏"的偏移口径与改前逐字一致；
          //   ③ `onScrollFrameBegin` / `onDidScroll` 都是滚动组件通用接口，签名不变。
          List({ scroller: this.pageScroller }) {
            // 第 1 组 = 顶部大卡（分类 Tab 上面的那块）。
            // 顶部留白仍写在**滚动内容**里（这一组第一个 ListItem 的顶部 padding），
            // 口径与改前的 `Scroll` 内容 padding 逐字一致：状态栏 + HDS 标题栏。
            ListItemGroup() {
              ListItem() {
                Column() {
                  HeroBannerSection({ recommendViewModel: this.recommendViewModel })
                }
                .width(StyleConstants.FULL_WIDTH)
                .padding({
                  top: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
                    0 : this.windowInfo.statusBarTopVp + TitleBarConstants.ROW_HEIGHT_VP
                })
              }
            }

            // 「新歌推荐」/「精选推荐」= 和「每日30首」同一款歌曲行竖排列表（任务 3）。
            // 两个组件各自渲染**一个无 header 的 `ListItemGroup`**（标题 + 行都在里面），
            // 所以它们是 List 的直接子节点 —— 不能再包进别的 ListItemGroup。
            HomeSongListSection({
              sectionTitle: $r('app.string.home_new_songs'),
              dataSource: this.recommendViewModel.privateSongDataSource,
              songCount: this.recommendViewModel.privateSongDisplayList.length,
              keyPrefix: 'ns',
              recommendViewModel: this.recommendViewModel
            })
            HomeSongListSection({
              sectionTitle: $r('app.string.home_category_featured'),
              dataSource: this.recommendViewModel.privateSongDataSource,
              songCount: this.recommendViewModel.privateSongDisplayList.length,
              keyPrefix: 'fs',
              recommendViewModel: this.recommendViewModel
            })

            // 分类 Tab 那一组：它的 **header 就是那四个分类 Tab** ⇒ 上滑到顶时 Tab 行吸顶（任务 2）。
            ListItemGroup({ header: this.StickyCategoryHeader() }) {
              // 分类内容（精选 / 歌手 / 榜单 / 分类 四选一）。
              // `CategoryContentSection` 自己也是一个无 header 的 `ListItemGroup`
              // ⇒ 这里以**自定义组件**的形式挂在本组内（官方允许 List/ListItemGroup 下用自定义组件）。
              CategoryContentSection({ recommendViewModel: this.recommendViewModel })
            }

            // 歌单广场（设置项控制，默认关闭）：放进自己的 group 里，别和上面那组的 header 混在一起
            // （`List` 的直接子节点只能是 `ListItem` / `ListItemGroup` / 自定义组件 / `if-else` / `ForEach`）。
            ListItemGroup() {
              if (this.homePlazaState.enabled) {
                ListItem() {
                  HomePlazaSection({ recommendViewModel: this.recommendViewModel })
                }
              }
            }
          }
          .layoutWeight(1)
          .padding({
            bottom: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 16
          })
          .backgroundColor($r('app.color.background_secondary'))
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .sticky(StickyStyle.Header)
          .clip(false)
          .align(Alignment.Top)
          .onAttach((): void => {
            this.onHomeListAttach();
          })
          .onDidScroll((): void => {
            this.onHomeListDidScroll();
          })
          .onScrollFrameBegin((offset: number): OnScrollFrameBeginHandlerResult => {
            return this.onHomeScrollFrameBegin(offset);
          })
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
