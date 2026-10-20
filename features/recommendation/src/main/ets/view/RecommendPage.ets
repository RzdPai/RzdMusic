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
import { AppStorageV2, curves, SymbolGlyphModifier, uiObserver } from '@kit.ArkUI';
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
import { HomeSearchRow } from './HomeSearchRow';

/**
 * 首页滚动位置「记录 + 恢复」补位的最大帧数（每帧 16ms ⇒ 约 **480ms** 的补位窗口）。
 *
 * 为什么不是"补一次就完"：`Scroll` 刚重建时**内容还在异步长高**（首页顶部 5 张大卡要等
 * `dailySongsReady`、封面要等网络补三轮），而 `scrollTo` 的目标会被当前可滚范围夹住 ——
 * 夹住时逐帧再补一次，等内容够高了自然就到位。
 * ⚠️ 窗口不能太短：160ms（第 2 版的 10 帧）在真机上常常还没等到内容量完就放弃了。
 */
const HOME_SCROLL_RESTORE_MAX_FRAMES: number = 30;
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
   * 「位置停留」的记录面：由 {@link onHomeScrollDidScroll} 在**用户真的拖动/惯性滚动**时
   * 写入（`Scroller.currentOffset().yOffset`，绝对位置 —— 回调入参是本帧增量，不能直接记）。
   *
   * ⚠️ 全仓**没有任何** `scrollTo({y:0})` 之类的"主动重置"；记录被清掉的时机只有两处，
   *   都在 {@link resetHomeScrollRecord} 的调用点上：
   *   ① 壳层点**当前**页签要求回顶部（`@Monitor('scrollTopCommand')`）；
   *   ② 首页来源平台变了（内容整体换掉，同一段偏移指向另一批数据，停留没有意义）。
   */
  private homeScrollOffsetVp: number = 0;
  /**
   * 补位链是否在跑（`true` 期间每 16ms 复核一次「实测 vs 目标」）。
   *
   * ★★★ **这里是第 2 版失败的真正根因，别再改回去**：
   *    第 2 版（§58）另有一个 `homeUserScrolled` 闩 —— 用户一拖动就置 `true`，
   *    而它**只由 `resetHomeScrollRecord()` 清**（只有"点当前页签回顶部"和"换平台"两条路会调）。
   *    可是**唯一能让 `homeScrollOffsetVp` 变成非 0 的动作，就是用户拖动**（记录只在
   *    `ScrollState.Scroll/Fling` 时写）⇒ 「记录非 0」与「用户滚过」是同一件事的两个说法
   *    ⇒ `startHomeScrollRestore()` 每次都在第二道闸就 `return`（日志里是满屏
   *    `restore skipped reason=… cause=user-scrolled`）⇒ **补位链一次都没真正跑过**。
   *    这就是"加了逻辑还是不能停"的答案，也是本版把那个闩**整个删掉**的原因。
   *
   * 现在的口径：`onDidScroll` 只在**本次补位窗口内**收到 `Scroll`/`Fling` 时取消
   * **本次**补位（用户的停位就是他的意愿）；窗口之外用户怎么滚都不影响下一次补位。
   */
  private homeScrollRestorePending: boolean = false;
  /** 本次补位链已经跑过的帧数（上限 {@link HOME_SCROLL_RESTORE_MAX_FRAMES}）。 */
  private homeScrollRestoreTries: number = 0;
  /**
   * 本次补位链的**目标偏移快照**（vp）。
   *
   * 为什么快照而不是每帧读 `homeScrollOffsetVp`：补位期间用户可能又滚了一下（那会被判成
   * "接管"并取消），目标跟着记录漂移会让"到位没有"的判据自相矛盾。
   */
  private homeScrollRestoreTargetVp: number = 0;
  /**
   * 上一帧量到的偏移；-1 = 本链还没补过。**只用于日志**（打印每帧的
   * `measured=` 序列，无设备时靠它判断两件事：`initialOffset` 有没有生效、
   * 目标是不是被可滚范围夹住）。
   *
   * ⚠️ 它**不再参与任何判定**。第 2 版拿它当"用户滚过没有"的判据是个错：
   *    `scrollTo` 自己造成的偏移变化（尤其被可滚范围夹住时逐帧变一点）会被误判成
   *    用户滚动 ⇒ 链条第二帧就自己掐断。现在"用户接管"只看 `onDidScroll` 的
   *    `scrollState`（`Scroll`=手指拖动、`Fling`=惯性；无动画 `scrollTo` 官方口径是 `Idle`）。
   */
  private homeScrollRestoreLastMeasuredVp: number = -1;
  /**
   * 本帧的"记录值"是不是**位置停留自己补出来的**。
   *
   * 后台补位（`scrollTo` 无动画）会以 `ScrollState.Idle` 回调 `onDidScroll`（本机 SDK
   * `list.d.ts` 的 `ScrollState.Idle` 原文：「Triggered when the scroll state returns to
   * idle, and when the controller's **non-animated** methods are used to control the
   * scroll」）—— 也就是说 `Idle` **不能**直接当成"用户没滚"。这里自己置位、回调里消费，
   * 把"我补的"和"用户滚的"分开。
   */
  private homeScrollProgrammaticMove: boolean = false;

  /**
   * 「内容已经真正量出来了」这件事只通知一次（见 {@link notifyHomeContentLaidOut}）。
   *
   * 为什么不用 `@Local` 做闸：本字段**只影响是否再补一次位**，不影响任何绘制，
   * 做成状态只会多触发一轮重渲染。
   */
  private homeContentLaidOutNotified: boolean = false;

  /**
   * 四个分类 Tab：「吸顶副本」当前是否显示（由 {@link onHomeScrollDidScroll} 按偏移判定）。
   *
   * ★ 全套做法**照 RzdVideo 首页**（`RzdVideo/entry/src/main/ets/pages/HomePage.ets`
   *   的 `syncStickyChips()` + `chipsRow(sticky)` + 最外层 `Stack` 里那份副本），
   *   口径逐条对齐（它是在真机上迭代了几十个 build 才定的）：
   *   ① 滚动容器**仍是 `Scroll`**，不换 `List` / `sticky`（§56 换成 List 那次整体回退过）；
   *   ② 流内那一行与吸顶那一行是**同一份实现**（同一个 `CategoryChipsSection`），
   *      吸顶生效时流内那份走 `Visibility.Hidden`（**保留占位** ⇒ 布局不跳、切换不闪）；
   *   ③ 副本挂在滚动内容**外面**、与 `Scroll` 同层（`Stack` 的子节点）⇒ 不参与滚动、
   *      不抢手势；位置 = 「`Stack` 顶对齐 + `padding({ top: 吸顶线 })`」（**不是** `.position()`）；
   *   ④ 判据用**顶边法**（RzdVideo 的公式）：`offset >= 行顶边 − 吸顶线` ⇒ 副本出现；
   *      这一刻副本与流内那一行的像素位置**完全重合** ⇒ 吸顶瞬间零跳变。
   */
  @Local chipStickyActive: boolean = false;
  @Local titleSearchShown: boolean = false;
  /**
   * 分类 Tab 行**在滚动内容里的顶边**（vp）；0 = 还没量到（此时不判吸顶）。
   *
   * 由包在那一行外面的「只负责量它」的容器 `onAreaChange` 给出（取 `area.position.y`）：
   * 官方口径里 `position` = 目标元素左上角相对**父元素**的位置 ⇒ **不随滚动变化**，
   * 所以不需要（也不该）只在"偏移 ≈ 0"时才采纳。
   * ⚠️ 唯一前提：它的父元素（滚动内容根 `Column`）**没有 padding** —— 顶部那段留白
   *    已从 `padding.top` 改成内容里第一个「固定高度容器」（见 build()），
   *    这样 `position.y` 只有一种解释 = 该行在内容里的位置，不用再猜 padding 算不算在内。
   */
  private chipRowTopInContentVp: number = 0;
  /** 分类 Tab 行**自身高度**（vp）；只用于诊断日志（副本高度由那一行自己决定，不读它）。 */
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

  /**
   * 位置记录清零（点当前页签回顶部 / 换首页平台时用；恢复相关状态一并收干净）。
   *
   * ⚠️ 调完之后这次"位置停留"应当**彻底作废**：不能留下一个"pending 但目标为 0"的半截状态
   * （否则补位链会拿着一帧前的旧目标继续 `scrollTo`）。
   */
  private resetHomeScrollRecord(): void {
    this.homeScrollOffsetVp = 0;
    this.homeScrollRestorePending = false;
    this.homeScrollRestoreTries = 0;
    this.homeScrollRestoreTargetVp = 0;
    this.homeScrollRestoreLastMeasuredVp = -1;
    this.homeScrollProgrammaticMove = false;
  }

  /**
   * 首页滚动容器**每次挂载**都会走这里（`homeLoaded` 反转导致的重建也会走）。
   *
   * ⚠️ **这里承认前两版都没成功，并把两条错路都写清楚，别再踩**：
   *   ① 第一版：`onAttach` 只置 `pending`，真正补位写在 `onDidScroll` 里 ——
   *      而 `onDidScroll` **只有真的发生滚动时**才回调（官方 `OnScrollCallback`：
   *      "列表滑动时触发"；`scrollEdge` / 不带动画的 `scrollTo`/`scrollToIndex` 都不触发）
   *      ⇒ 容器刚重建时偏移 0、用户手指没动 ⇒ **回调一次都不来 ⇒ 位置永远补不回去**。
   *   ② 第二版：`initialOffset(记录值)` 作首选 + `onAttach` 帧循环兜底 —— 真机**仍无效**。
   *      ★★★ **真根因（本轮查出来的，别再猜是"首次布局没触发"）**：
   *      第二版在 {@link startHomeScrollRestore} 里加了一道闸
   *      **「本次挂载用户已经自己滚过 ⇒ 直接跳过」**，而那个标志
   *      （`homeUserScrolled`）**只有 `resetHomeScrollRecord()` 会清**，
   *      却被**唯一能让记录值变成非 0 的动作**（用户在 `onDidScroll` 里拖动/惯性滚动）置上
   *      ⇒ 「记录非 0」⇔「用户滚过」是同一件事 ⇒ **补位链一次都没跑起来过**
   *      （真机日志里是满屏 `restore skipped … cause=user-scrolled`，一行 `tick` 都没有）。
   *      也就是说：这一版失败跟 `initialOffset` 的语义、跟内容长高**都无关** ——
   *      它在"要不要补"这一步就被自己否决了。**本版已把这个闩整个删掉。**
   *      ⚠️ 另外它那句判据"补过一次后偏移又变了 ⇒ 用户滚的"也是错的：`scrollTo` 自己的
   *      效果（尤其被可滚范围夹住时逐帧只挪一点）会被误读成用户接管 ⇒ 链条第二帧自杀。
   *      现在"用户接管"只认 `onDidScroll` 的 `scrollState`（`Scroll`/`Fling`）。
   *   ③ 第二版还有一个**次要**的机制缺陷（本版仍在兜它）：首页的"重建"是一条**异步链**——
   *      `load()` 把 `homeLoaded=false` → 容器重建 → 首次布局时顶部大卡还是占位卡
   *      （`dailySongsReady` 为 false）、封面还在补 ⇒ 内容高度小于最终高度
   *      ⇒ `initialOffset` 的目标值当场被可滚范围夹住，而它**只有这一次机会**。
   *      （实测口径：容器挂载后第一行 `tick t=0 measured=… target=…`，`measured` 明显偏小即为此。）
   *
   * ⇒ **本版（第 3 版）不再把任何一步押在"首次布局"上，也不再有任何"用户滚过就永久放弃"的闩**：
   *   恢复链由四个**可观测事件**驱动，每个事件都自己复核"实测偏移 vs 目标"，
   *   且都能在内容变高之后**再来一次**：
   *     · `onAttach`（容器刚重建）→ {@link startHomeScrollRestore}；
   *     · 内容量完（顶部留白容器 `onAreaChange`）→ {@link notifyHomeContentLaidOut}；
   *     · 首页页签重新可见（`onVisibleAreaChange`）→ {@link onHomeVisibleChanged}；
   *     · 首页数据/封面就绪（`@Monitor('recommendViewModel.homeLoaded')` /
   *       `@Monitor('recommendViewModel.dailySongsReady')`）→ 见两个 `@Monitor` 方法。
   *   四者都只是"发起"，真正的补位与重试仍在 {@link restoreHomeScrollOnFrame} 里，
   *   `initialOffset` 保留为**顺手的第一笔**（不再是唯一指望）。
   */
  private onHomeScrollAttach(): void {
    // 分类 Tab 顶边随容器重建一起作废：重建后的首帧布局会再走一次 `onAreaChange`
    // （旧 area 为空 ⇒ 必然回调），那时量到的是**内容坐标**，与当前偏移无关。
    this.chipRowTopInContentVp = 0;
    this.chipStickyActive = false;
    this.homeContentLaidOutNotified = false;
    // 容器重建 = 上一轮的补位链已经失去意义（它对着的是那个已经被销毁的 `Scroll`）
    this.homeScrollRestorePending = false;
    this.homeScrollRestoreTries = 0;
    this.homeScrollRestoreLastMeasuredVp = -1;
    // ★ 诊断三连（无设备时唯一的证据）：容器是不是**真的重建过**、这一刻记录值/实测值各是多少。
    //   `measured` 与 `target` 相等 ⇒ `initialOffset` 生效了；`measured` 明显小于 `target`
    //   ⇒ 目标被"内容还没长高"的可滚范围夹住了（补位链接下来会逐帧把它顶上去）。
    Logger.info('RzdHomeScroll',
      `container attach target=${this.homeScrollOffsetVp} measured=${this.readHomeScrollOffset()}`
        + ` homeLoaded=${this.recommendViewModel.homeLoaded}`
        + ` dailySongsReady=${this.recommendViewModel.dailySongsReady}`);
    this.startHomeScrollRestore('attach');
  }

  /**
   * 发起（或沿用）一次"把偏移补回记录值"的补位链。
   *
   * 「什么时候**不**该恢复」——全部闸门就这两条，写清楚免得后面有人又加回一条错的：
   *   ① 没有记录值（`homeScrollOffsetVp <= 0`）：本来就在顶，没什么可恢复；
   *   ② 已经有补位链在跑：沿用，不叠加（重复发起会让帧计数互相覆盖）。
   *
   * ★★ **这里曾经还有第三条"本次访问用户已经自己滚过 ⇒ 跳过"，它已被删除**：
   *   那个闩（`homeUserScrolled`）只由 `resetHomeScrollRecord()` 清，而它恰恰被
   *   **唯一能让记录值非 0 的动作**（用户拖动）置上 ⇒ 条件恒真 ⇒ 补位链永远跑不起来
   *   （真机上表现为"加了逻辑还是不能停"）。详见 {@link homeScrollRestorePending} 的注释。
   *   现在的替代口径：补位链跑起来之后，`onDidScroll` 在**本次窗口内**收到
   *   `Scroll`/`Fling` 就取消**本次**（见 {@link onHomeScrollDidScroll}）——
   *   用户的停位仍然是他的意愿，但不会连累下一次补位。
   *
   * @param reason 触发原因，只用于日志
   *   （attach / content-laid-out / tab-visible / home-loaded / covers-ready）。
   */
  private startHomeScrollRestore(reason: string): void {
    if (this.homeScrollOffsetVp <= 0) {
      return;
    }
    if (this.homeScrollRestorePending) {
      return;
    }
    this.homeScrollRestorePending = true;
    this.homeScrollRestoreTries = 0;
    this.homeScrollRestoreTargetVp = this.homeScrollOffsetVp;
    this.homeScrollRestoreLastMeasuredVp = -1;
    Logger.info('RzdHomeScroll',
      `restore start target=${this.homeScrollRestoreTargetVp} reason=${reason}`
        + ` measured=${this.readHomeScrollOffset()}`);
    this.restoreHomeScrollNextFrame();
  }

  /**
   * 「滚动内容**真的量出来了**」的那一次通知（挂在内容里第一个固定高度的容器上）。
   *
   * 为什么必须有这一条：`initialOffset` 唯一失效的地方就是"首次布局时内容还太矮"，
   * 而**内容何时变高**在页面里没有别的可观测信号（`homeLoaded` 反转时数据还在路上）。
   * 顶部留白容器是滚动内容里的**第一个节点**：它被量到，就意味着这一轮内容布局
   * 已经跑过一遍；此时再去补位，`scrollTo` 的目标才有意义。
   */
  private notifyHomeContentLaidOut(): void {
    if (this.homeContentLaidOutNotified) {
      return;
    }
    this.homeContentLaidOutNotified = true;
    this.startHomeScrollRestore('content-laid-out');
  }

  /** 排一帧回调，在下一帧继续尝试补位（见 {@link restoreHomeScrollOnFrame}）。 */
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
   * 每帧的顺序固定为：**先读实测 → 先落一行日志 → 再判定 → 最后才动**。
   *   · 实测 ≈ 目标 ⇒ 真的到位，收工（`restored`）；
   *   · 超帧数 ⇒ 放弃（内容比记录时矮 / 该位置已不可达）（`gave up`）；
   *   · 其余 ⇒ 记下本帧实测，`scrollTo` 到目标，排下一帧。
   *
   * ★★ **"用户接管"不再在这里判**（第 2 版的错就在这）：`scrollTo` 自己造成的偏移变化
   *    （尤其被可滚范围夹住时逐帧只挪一点点）会被旧判据误读成"用户滚了" ⇒ 链条自杀。
   *    现在只有 `onDidScroll` 的 `Scroll`/`Fling` 才算用户接管，且它会直接
   *    `homeScrollRestorePending = false`（见 {@link onHomeScrollDidScroll}）。
   *
   * ★ 每帧都打一行 `tick t=… measured=… target=…`：这就是"`initialOffset` 到底有没有生效"
   *    的**证据行**——第 0 帧（`t=0`）的 `measured` 已经 ≈ `target` ⇒ 生效；
   *    `measured` 明显偏小且逐帧只长一点点 ⇒ 目标被可滚范围夹住（内容还在长）。
   */
  private restoreHomeScrollOnFrame(): void {
    if (!this.homeScrollRestorePending) {
      return;
    }
    const target: number = this.homeScrollRestoreTargetVp;
    if (target <= 0 || this.homeScrollOffsetVp <= 0) {
      // 记录被清零了（点当前页签回顶部 / 换平台）：别再把用户拉回旧位置
      this.homeScrollRestorePending = false;
      this.homeScrollRestoreTries = 0;
      this.homeScrollRestoreLastMeasuredVp = -1;
      Logger.info('RzdHomeScroll', `restore cancelled target cleared target=${this.homeScrollOffsetVp}`);
      return;
    }
    const measured: number = this.readHomeScrollOffset();
    // ★ 补位帧里顺手把吸顶也复算一次：重建这一路不触发 `onDidScroll`，
    //   而恢复后的偏移恰恰决定"分类 Tab 是不是已经滚过去了"。
    this.updateChipSticky(measured);
    Logger.info('RzdHomeScroll',
      `tick t=${this.homeScrollRestoreTries} measured=${measured} target=${target}`
        + ` prev=${this.homeScrollRestoreLastMeasuredVp}`);
    if (Math.abs(measured - target) < HOME_SCROLL_RESTORE_EPS_VP) {
      this.homeScrollRestorePending = false;
      this.homeScrollRestoreLastMeasuredVp = -1;
      Logger.info('RzdHomeScroll',
        `restored measured=${measured} target=${target} ticks=${this.homeScrollRestoreTries}`);
      return;
    }
    if (this.homeScrollRestoreTries >= HOME_SCROLL_RESTORE_MAX_FRAMES) {
      // 补了这么多帧还不到位（内容比原来矮、或偏移已被夹到可滚范围）：放手
      this.homeScrollRestorePending = false;
      this.homeScrollRestoreLastMeasuredVp = -1;
      Logger.info('RzdHomeScroll',
        `restore gave up measured=${measured} target=${target} ticks=${this.homeScrollRestoreTries}`);
      return;
    }
    this.homeScrollRestoreTries = this.homeScrollRestoreTries + 1;
    this.homeScrollRestoreLastMeasuredVp = measured;
    // ★ 标一句"这一次滚动是我自己发的"：**无动画 `scrollTo` 会以 `ScrollState.Idle`
    //   回调 `onDidScroll`**（本机 SDK `list.d.ts`：`Idle` =「滚动状态回到空闲时，
    //   以及控制器**无动画**方法控制滚动时」触发）⇒ 不标就会被当成"用户滚过"而把补位链自己掐掉。
    this.homeScrollProgrammaticMove = true;
    this.pageScroller.scrollTo({ xOffset: 0, yOffset: target, animation: false });
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
   * 首页滚动容器每帧的**偏移记录** + 「分类 Tab 吸顶」判定 + 「用户接管」判定。
   *
   * ⚠️ 为什么不用 `onScroll`：官方已把它标为 `@deprecated since 12`，
   *   `@useinstead ScrollableCommonMethod#onDidScroll`。
   * 记录用 `onDidScroll` + `Scroller.currentOffset()`（与 `PlaylistDetailPage` 量滚动位置同一套写法）。
   *
   * ⚠️ `onDidScroll` 的回调入参是**本帧增量**不是绝对偏移（Scroll 的
   *   `ScrollOnScrollCallback = (xOffset, yOffset, scrollState)` ⇒ d.ts 里就是"本帧偏移量"），
   *   所以要**绝对位置**必须回调 `currentOffset()` —— 这一点别改回去。
   *
   * ★★ **它不是"位置停留"的触发源，只是两件事的证据来源**：
   *   ① 用户滚到哪了（记录面）：`Scroll`=手指拖动、`Fling`=惯性，只有这两种是用户意愿；
   *   ② 用户有没有在**补位窗口内**接管：是 ⇒ 立刻取消**本次**补位（别跟用户抢滚动），
   *      但**不再**留下"滚过就永久放弃"的闩（那个闩是第 2 版把整个功能变成死代码的根因，
   *      见 {@link homeScrollRestorePending}）。
   *   它**不能**当"恢复触发源"——不滚动就一次都不回调（第一版把补位写在它里面 ⇒ 永远补不回去）。
   *
   * @param _frameDelta 本帧滚动增量（不参与计算，留着按官方签名接）。
   * @param scrollState 本帧滚动状态；`Scroll`=用户拖动、`Fling`=惯性、
   *   `Idle`=滚动停下 **或控制器用无动画方法滚**（后者是我们自己补的位，见
   *   {@link homeScrollProgrammaticMove}）。
   */
  private onHomeScrollDidScroll(_frameDelta: number, scrollState: ScrollState): void {
    const offset: number = this.readHomeScrollOffset();
    const titleSearchShown: boolean = offset > 20;
    if (titleSearchShown !== this.titleSearchShown) {
      this.titleSearchShown = titleSearchShown;
    }
    if (scrollState === ScrollState.Scroll || scrollState === ScrollState.Fling) {
      // ① 用户真的在滚：记下位置（用户的停位就是他的意愿）。
      //    ★ 这里**只记录**，不再设任何"滚过就永久放弃"的闩 —— 那是第 2 版把整个
      //      位置停留变成死代码的原因（见 homeScrollRestorePending 的注释）。
      if (Math.abs(offset - this.homeScrollOffsetVp) >= HOME_SCROLL_RESTORE_EPS_VP) {
        this.homeScrollOffsetVp = offset;
        Logger.info('RzdHomeScroll', `record offset=${offset}`);
      }
      // 补位链正在跑时被用户打断：立刻收手，别等到下一帧的判据
      if (this.homeScrollRestorePending) {
        this.homeScrollRestorePending = false;
        this.homeScrollRestoreTries = 0;
        this.homeScrollRestoreLastMeasuredVp = -1;
        Logger.info('RzdHomeScroll',
          `restore cancelled by user scroll measured=${offset} target=${this.homeScrollRestoreTargetVp}`);
      }
    } else if (scrollState === ScrollState.Idle) {
      // ② `Idle` 有两种来源，必须分开（见方法头注释）：
      //    自己补位发起的 ⇒ 什么都不做；其它（点页签回顶的 `scrollEdge`、
      //    回弹动画结束…）⇒ 只跟随记录，**不算用户滚动、也不启动恢复**。
      if (this.homeScrollProgrammaticMove) {
        this.homeScrollProgrammaticMove = false;
      } else if (!this.homeScrollRestorePending && this.homeScrollOffsetVp > 0 &&
        Math.abs(offset - this.homeScrollOffsetVp) >= HOME_SCROLL_RESTORE_EPS_VP) {
        this.homeScrollOffsetVp = offset;
        Logger.info('RzdHomeScroll', `record offset=${offset} cause=idle`);
      }
    }
    // ③ 吸顶判定（同一份偏移，不另开滚动监听）
    this.updateChipSticky(offset);
  }

  /**
   * 一次性的偏移/目标落日志（无设备时靠它确认"容器重建过没有、目标值是多少"）。
   *
   * 触发点只剩 `onScrollStop`（每次滚动停下打一行）—— 它是**被动观测**，
   * 不参与任何恢复判定。
   * @param stage 阶段名（`scroll-stop`）。
   */
  private logHomeScrollOffset(stage: string): void {
    Logger.info('RzdHomeScroll', `${stage} offset=${this.readHomeScrollOffset()} target=${this.homeScrollOffsetVp}`);
  }

  /**
   * 分类 Tab 行在滚动内容里的顶边（父元素无 padding ⇒ 量到的就是**内容坐标**）。
   *
   * ⚠️ 与上一版（§58）的差别：**去掉了"只在偏移 ≈ 0 时才采纳"的闸**。
   *   那条闸的出发点是"滚动中量到的可能是视口坐标"，但 `Area.position` 官方口径是
   *   **相对父元素**、不随滚动变化；而带上那条闸反而制造了一个真 bug ——
   *   容器因 `homeLoaded` 反转而重建时，`initialOffset` 已经把偏移恢复成非 0，
   *   首帧 `onAreaChange` 就被闸挡掉，之后滚动不会再改变"相对父元素的位置"⇒
   *   `onAreaChange` **不会再回调** ⇒ 顶边永远停在 0 ⇒ **吸顶永远不生效**。
   */
  private onChipRowAreaChange(area: Area): void {
    const height: number = areaLengthToVp(area.height);
    if (height > 0 && Math.abs(height - this.chipRowHeightVp) > 0.5) {
      this.chipRowHeightVp = height;
    }
    const top: number = areaLengthToVp(area.position.y);
    if (top > 0 && Math.abs(top - this.chipRowTopInContentVp) > 0.5) {
      this.chipRowTopInContentVp = top;
    }
    // ★ 量到顶边后**立刻按当前偏移复算一次**吸顶：容器重建（`homeLoaded` 反转）时
    //   `initialOffset` 会把偏移直接恢复成非 0，而那条路**不会**触发 `onDidScroll`
    //   ⇒ 不复算的话"四个 Tab 已经滚过去"这一屏上副本不会出现，要等用户手动滚一下才回来。
    this.updateChipSticky(this.readHomeScrollOffset());
    Logger.info('RzdHomeScroll',
      `chip area h=${height} top=${this.chipRowTopInContentVp} sticky=${this.chipStickyActive}`);
  }

  /**
   * 分类 Tab 吸顶判定：这一行的**顶边**到达吸顶线就显示"吸顶副本"。
   *
   * ★ 判据抄 RzdVideo 首页（`syncStickyChips()`）：`y >= 行顶边 − 吸顶线`，即**顶边法**。
   *   为什么不是"下边沿法"（行完整滑出视口顶才接管）：顶边法下，副本出现的那一瞬间
   *   流内那一行的顶边**正好也在吸顶线**上 ⇒ 两份像素级重合、切换零跳变；
   *   而下边沿法要等整整一行滚进标题栏底下才接管，中间那一段会"看不见任何一行"。
   * @param offset 当前垂直偏移（vp）。
   */
  private updateChipSticky(offset: number): void {
    if (this.chipRowTopInContentVp <= 0) {
      // 还没量到那一行的位置（首帧 / 分类行还没出现）⇒ 不判吸顶，免得闪一下
      return;
    }
    const stickLine: number = this.contentTopInsetVp();
    const active: boolean = offset >= this.chipRowTopInContentVp - stickLine;
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
    // ★ 位置停留的触发点之一：**首页页签重新可见**（切到「回响」/「我的」再切回来，
    //   以及从二级页返回）。
    //   为什么用这里：壳层是 `HdsTabs`，而 `HdsTabsOptions extends TabsOptions`、
    //   子节点就是 `TabContent` ⇒ 官方 `ts-container-tabs` 的口径适用：
    //   「**已经显示的 Tabs 子组件 TabContent 后续隐藏时不会被销毁**」⇒ 切页签时
    //   本页与里面的 `Scroll` **都不重建**、`onAttach` 不会再来一次；而"可见了没有"
    //   恰恰是这一条回调唯一能保证的事（`onVisibleAreaChange` 挂在页面内容根节点上，
    //   随页签切换必然翻转）。
    //   ⇒ 这就是"进该 Tab / 从二级页返回"时的**主动复核点**：位置没丢时它是一次空操作
    //   （第 0 帧实测 ≈ 目标 ⇒ `restored`），真丢了时才真的 `scrollTo` 补回去。
    //   `startHomeScrollRestore` 只有两道闸（无记录 / 已在补位）⇒ 不会重复补。
    this.startHomeScrollRestore('tab-visible');
  }

  /**
   * 首页数据加载状态变化（`RecommendViewModel.load()` 把 `homeLoaded` 置 false、
   * 数据回来后置 true）。
   *
   * 为什么要接这一条：`homeLoaded` 是**首页唯一滚动容器所在条件分支**的判据
   * （`build()` 里 `if (this.recommendViewModel.homeLoaded)`）⇒ 它一翻 false，
   * `Scroll` 就被销毁、偏移归 0；翻回 true 时是一次全新的"首次布局"。
   *   ① 翻 false：在跑的补位链失去意义（它手里那个 `Scroller` 马上要被销毁）⇒ 收掉；
   *   ② 翻 true：容器重建完成 ⇒ 立刻发起一次补位（真正的重试仍在帧循环里，
   *      因为这一刻首页封面/歌曲列表可能还在异步补，内容还没长到最终高度）。
   */
  @Monitor('recommendViewModel.homeLoaded')
  onHomeLoadedChanged(): void {
    if (!this.recommendViewModel.homeLoaded) {
      this.homeScrollRestorePending = false;
      this.homeScrollRestoreTries = 0;
      this.homeScrollRestoreLastMeasuredVp = -1;
      Logger.info('RzdHomeScroll',
        `chain dropped cause=home-loaded-false target=${this.homeScrollOffsetVp}`);
      return;
    }
    this.startHomeScrollRestore('home-loaded');
  }

  /**
   * 顶部大卡「整块出现」的时刻（`dailySongsReady`：封面全部就绪才画真卡片）。
   *
   * 这是**内容高度最终确定**的信号 —— 内容一长高，可滚范围变大，之前被夹住的
   * `scrollTo` 目标才真正可达 ⇒ 在这里再复核一次（这就是"在数据重载完成回调里恢复"）。
   *
   * ⚠️ 已知局限（写清楚免得当成 bug）：`dailySongsReady` 只在 `load()` 的第 1 轮之后
   *   置 true，`load()` 本身**不会**把它重置为 false ⇒ 第 2 次以后的换平台/换账号
   *   这条 `@Monitor` 不会再触发。那几条路靠 `onAttach` + `home-loaded` + 480ms 帧循环兜住。
   */
  @Monitor('recommendViewModel.dailySongsReady')
  onHomeDailySongsReadyChanged(): void {
    if (!this.recommendViewModel.dailySongsReady) {
      return;
    }
    this.startHomeScrollRestore('covers-ready');
  }

  /** 平台值确实变了才重载首页（多条触发路径共用这一道闸）。 */
  private applyHomeSourceIfChanged(): void {
    const source: string = this.homeSourceState.source;
    if (source === this.loadedHomeSource) {
      return;
    }
    this.loadedHomeSource = source;
    Logger.info('RzdHomeSource', `page reload source=${source}`);
    // ★ 换平台 = 首页内容**整体换掉**：这时"停留"没有意义（同一段偏移指向的是另一批数据），
    //   而且旧记录会让 `startHomeScrollRestore` 在新内容上乱拉 ⇒ 记录一并清零并记一行日志。
    this.resetHomeScrollRecord();
    Logger.info('RzdHomeScroll', `record reset cause=source-change source=${source}`);
    this.recommendViewModel.load();
  }

  /**
   * 首页搜索入口。
   *
   * 一镜到底的写法**照官方示例**（`transitions-collection` 的
   * `SearchLongTakeTransition/SearchLongTakeTransitionPageOne.ets:74-81`）：
   *
   * ```ts
   * this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 342, 38) }, () => {
   *   this.pageInfos.pushPath({ name: '...' }, false);   // ★ animated=false：关掉系统推页动画
   * });
   * ```
   * 只有关掉系统转场、再用 `animateTo` 包住 push，两端的 `geometryTransition` 才会接成一镜到底；
   * 页面本身的淡入淡出由目标页 `NavDestination.transition(TransitionEffect.OPACITY)` 负责。
   *
   * 顺手复位标题栏那个「滚动后才出现」的搜索图标（照上游 `onSearchOpenFlip`，
   * wujie126.pa 498612-498621）。
   */
  private openSearch(): void {
    if (this.titleSearchShown) {
      this.titleSearchShown = false;
    }
    Logger.info('RzdSearchMorph', `open route=${RouterUrlConstants.ONLINE_SEARCH}`);
    this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 342, 38) }, (): void => {
      this.pageIndexInfos.pushPath({ name: RouterUrlConstants.ONLINE_SEARCH }, false);
    });
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
        menu: this.breakpointEnv.widthBreakpoint !== WidthBreakpoint.WIDTH_SM || this.titleSearchShown ? {
          value: [
            {
              content: {
                label: 'search',
                icon: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass'))
                  .fontSize(22)
                  .fontColor([$r('sys.color.font_primary')]),
                isEnabled: true,
                action: (): void => {
                  this.openSearch();
                }
              }
            },
            {
              content: {
                label: 'identify',
                icon: new SymbolGlyphModifier($r('sys.symbol.identify_song'))
                  .fontSize(22)
                  .fontColor([$r('sys.color.font_primary')]),
                isEnabled: true,
                action: (): void => {
                  this.pageIndexInfos.pushPathByName(RouterUrlConstants.MUSIC_RECOGNITION, null);
                }
              }
            }
          ]
        } : undefined
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

  @Builder
  private HomeBranch() {
      Column() {
        if (this.recommendViewModel.homeLoaded) {
          // ★ 结构**照 RzdVideo 首页**（`HomePage.ets` 的 `build()`，真机迭代过几十个 build）：
          //     Stack(顶对齐) { Column { Scroll(layoutWeight(1)) … } ; 吸顶副本(同层) }
          //   · 滚动容器**仍然是 `Scroll`**（不换 `List` / `sticky` —— §56 换成 List 那版
          //     在真机上四 Tab 整行消失、内容错位，已整体回退）；
          //   · 中间那层 `Column` 是 RzdVideo 的关键一笔：`layoutWeight(1)` 只在
          //     Row / Column / Flex 里生效，`Scroll` **直接**挂在 `Stack` 下等于没有高度
          //     （表现就是整块空）。撑满由「`Stack` 的 `layoutWeight(1)` + 这层 `100%`」完成。
          Stack({ alignContent: Alignment.TopStart }) {
            Column() {
              Scroll(this.pageScroller) {
                Column() {
                  // ★ 顶部留白（状态栏 + HDS 标题栏 ≈ 94vp）：从"内容根的 `padding.top`"
                  //   改成**内容里第一个固定高度的空容器**。视觉完全等价（都是把下面的内容下移 94），
                  //   但滚动内容根的 padding 因此恒为 0 —— 分类 Tab 那一行 `onAreaChange`
                  //   量到的 `area.position.y` 只有一种解释 = 它在**内容**里的位置，
                  //   不用再猜"父元素的 padding 算不算在内"。
                  // ★ 它同时是**"滚动内容这一轮已经量过"的信号源**（`onAreaChange`）：
                  //   内容何时从"5 张占位卡"长成真正的高度，页面里没有别的可观测点，
                  //   而这一步正是 `initialOffset` 失效的地方（见 onHomeScrollAttach 注释）。
                  Column()
                    .width(StyleConstants.FULL_WIDTH)
                    .height(this.contentTopInsetVp())
                    .onAreaChange((_old: Area, _area: Area): void => {
                      this.notifyHomeContentLaidOut();
                    })

                  if (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM) {
                    HomeSearchRow({
                      gutter: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
                      onOpenSearch: (): void => {
                        this.openSearch();
                      },
                      onOpenRecognize: (): void => {
                        this.pageIndexInfos.pushPathByName(RouterUrlConstants.MUSIC_RECOGNITION, null);
                      }
                    })
                  }

                  HeroBannerSection({ recommendViewModel: this.recommendViewModel })

                  // ★ 四个分类 Tab 那一行：外面包一层**只负责量它**的容器（顶边 / 高度）。
                  //   吸顶生效时**流内这一份走 `Visibility.Hidden`**（保留占位、不参与绘制）——
                  //   与 RzdVideo 逐字同一条口径：屏上任何时刻只有一行分类可见，且布局不跳。
                  //   ⚠️ 别改成 `Visibility.None`：那会把后面所有内容整体上移，吸顶瞬间闪一下。
                  Column() {
                    CategoryChipsSection({ recommendViewModel: this.recommendViewModel })
                  }
                  .width(StyleConstants.FULL_WIDTH)
                  .visibility(this.chipStickyActive ? Visibility.Hidden : Visibility.Visible)
                  .onAreaChange((_old: Area, area: Area): void => {
                    this.onChipRowAreaChange(area);
                  })

                  CategoryContentSection({ recommendViewModel: this.recommendViewModel })
                  if (this.homePlazaState.enabled) {
                    HomePlazaSection({ recommendViewModel: this.recommendViewModel })
                  }
                }
              }
              .width(StyleConstants.FULL_WIDTH)
              // ⚠️ 这里能（也必须）用 `layoutWeight(1)`：它现在挂在**外层那个 `Column`** 里，
              //   不是挂在 `Stack` 里（`Stack` 的子节点按自身尺寸排，写 layoutWeight 等于没高度）。
              .layoutWeight(1)
              .padding({
                bottom: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 16
              })
              .backgroundColor($r('app.color.background_secondary'))
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .clip(false)
              .align(Alignment.Top)
              // ★ 位置停留的**第一笔**（⚠️ 不再是唯一指望，见 onHomeScrollAttach 那段根因）：
              //   `initialOffset` 只在**首次布局**生效（官方原文：「设置初始滚动偏移量。
              //   **只在首次布局时生效**，后续动态修改该属性值不生效」）。
              //   ⇒ 它在本工程里**确实触发**，但只有两类时机：
              //     ① App 首次进首页：`homeLoaded` 首次翻 true、`Scroll` 节点第一次创建，
              //        此刻 `homeScrollOffsetVp` 还是 0 ⇒ **属性生效但等于没做**；
              //     ② 之后每次 `homeLoaded` 反转（`load()` 造成）重建 `Scroll`：
              //        这时它带着记录值生效 —— 但**只有这一次机会**，而首页内容
              //        （顶部 5 张大卡要等 `dailySongsReady`、封面要等网络补）是**异步长高**的，
              //        内容还矮时目标当场被可滚范围夹住 ⇒ 之后再改这个属性也不会重放。
              //   ⇒ 所以它只负责"顺手就对"的那一半；另一半由
              //     `onAttach` / 内容量完 / 页签重新可见 / 数据与封面就绪 四条路各自补
              //     （见 {@link restoreHomeScrollOnFrame} 的帧循环）。
              //   ⚠️ 它是渲染期读的普通字段（不是 `@Local`）⇒ 偏移变化**不会**触发重渲染。
              //   🔎 验证它到底有没有生效：`grep RzdHomeScroll` 看容器挂载后的第一行
              //     `tick t=0 measured=… target=…` —— `measured ≈ target` 就是生效了。
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
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)

            // ★ 四个分类 Tab 的**吸顶副本**：与 `Scroll` **同层**（`Stack` 的子节点）⇒
            //   不参与滚动、不抢手势（与 RzdVideo 的 `chipsRow(true)` 那一层同构）。
            //   · 位置：靠 `Stack` 的顶对齐 + `.padding({ top: 吸顶线 })` 给出
            //     （RzdVideo 的做法；**不用** `.position()`），吸顶线 = 滚动内容里那段
            //     顶部留白 `contentTopInsetVp()`（非沉浸式 = 状态栏 + 标题栏 ≈ 94）
            //     —— 与上面那个空容器**同一个数** ⇒ 副本落在 HDS 标题栏下沿，**不盖标题栏**。
            //   · ★★ **这一层自己不铺任何底色**（用户 2026-10-15：
            //     「吸顶后这四个 Tab 后面那一条背景去掉」）。
            //     对齐参考实现 RzdVideo 首页（`HomePage.ets` build 163：
            //     `chipsRow()` 里那句「这一行**自己不再铺任何底色/模糊**」）——
            //     四个胶囊**各自**有不透明底（`app.color.chip_selected_background` /
            //     `chip_unselected_background`，见 `CategoryChipsSection`），所以
            //     "下面内容从胶囊之外那条缝里透出来"本来就不该靠整行底色去挡：
            //     那层底色会把**吸顶线以下、行以外**的整条区域（含 padding 段）也压成死色，
            //     看起来就是一条横贯屏幕的色带。
            //   · `hitTestBehavior(Transparent)`：只有这一行自己吃点击，其余一律放行给下面的内容
            //     （与 RzdVideo 同一口径）。
            if (this.chipStickyActive) {
              Column() {
                CategoryChipsSection({ recommendViewModel: this.recommendViewModel })
              }
              .width(StyleConstants.FULL_WIDTH)
              .padding({ top: this.contentTopInsetVp() })
              .hitTestBehavior(HitTestMode.Transparent)
              .zIndex(5)
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

  build() {
    HdsNavDestination() {
      this.HomeBranch()
    }
    .onBackPressed((): boolean => guardPlayerBack('RecommendPage'))
    .hideTitleBar(false)
    .hideBackButton(true)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.background_secondary'))
    // 官方一镜到底示例里源页也挂这个（PageOne 的 `NavDestination().transition(OPACITY)`）：
    // 推入时源页保持不动（animated=false），返回时它淡回来，不会"啪"地出现。
    .transition(TransitionEffect.OPACITY)
  }

  pageTransition() {
    PageTransitionEnter({ duration: SongConstants.TRANSITION_DURATION, curve: Curve.Smooth, type: RouteType.Pop })
    PageTransitionExit({ duration: SongConstants.TRANSITION_DURATION, curve: Curve.Smooth, type: RouteType.Push })
  }
}
