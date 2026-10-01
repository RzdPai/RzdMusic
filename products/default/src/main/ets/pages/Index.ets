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

import { AppStorageV2, curves, uiObserver } from '@kit.ArkUI';
import { HdsNavigation, HdsTabsController, HdsTabsBarChangeMode, hdsMaterial } from '@kit.UIDesignKit';
import {
  AmbientState,
  AppStorageKeys,
  BarLayoutModes,
  BreakpointType,
  getWindowInfoState,
  getPlaylistTransitionState,
  HomeSourceState,
  ImmersiveType,
  MusicAppState,
  MusicDbApi,
  MusicStoreService,
  Logger,
  MORPH_HOST_ID,
  PlaybackIntentState,
  PlayerExpandState,
  MorphDrive,
  MorphMetaBridge,
  RouterUrlConstants,
  SdkApiUtil,
  SdkConstants,
  ShowMiniLyricState,
  StyleConstants,
  TabSwitchState,
  ThemeState,
  WindowInfo,
  WindowUtil
} from 'musicbasic';
import { dispatchShellPlaybackIntent, LXSourceHost, PlaybackPageCoverContent, PlayerViewModel } from 'player';
import { RecommendPage } from 'recommendation';
import { HomeMiniBarPlayer, HomeMiniBarPlayerAside, PlaylistsPage, PlaylistTransitionOverlay } from 'playlist';
import { MinePage, SettingPage } from 'setting';
// 新模块：本地音乐（导入设备音频到沙箱）与洛雪同步客户端。
// ⚠️ hvigor 对 HAR 是**按引用编译**的：没有任何代码 import 它们时，
//    即使已登记进 build-profile.json5，这两个模块也**不会被编译**（构建照样绿）。
//    所以这里的 import 同时承担"启动初始化"和"把它拉进构建图"两个作用。
import { localMusic } from 'localmusic';
import type { MatchSongInfo } from 'localmusic';
import { syncManager } from 'sync';
// 歌曲评论（内置平台评论）：启动时把「本地音乐 -> 平台身份」的解析注册进 comment，
// 这样评论面板既能看在线歌的评论，也能看本地歌（匹配过的那些）的评论。
import { setCommentTargetResolver } from 'comment';
import type { CommentSongRef } from 'comment';
import { HdsBarLayoutMode, HdsBarStyle, HdsTabs } from '@hms.hds.hdsBaseComponent';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

/**
 * 二级页面悬浮迷你条的固定高度（vp）。
 *
 * 56 = 封面 44（折叠态，`HomeMiniBarAlbumCover.coverSideLengthVp()`）+ 上下各 6vp 内边距。
 * 二级页面这条永远是折叠形态（`followAppMiniBarExpanded: false` + `lockTwoRowCoverSize: true`），
 * 与首页底栏当前是单排还是双排无关 —— 它同时是播放页形变的起点，几何必须稳定。
 */
const FLOATING_MINI_BAR_HEIGHT_VP: number = 42;

  /** 二级页面悬浮迷你条在宽屏下的最大宽度（vp）：胶囊不该铺满整个平板/桌面窗口。 */
  const FLOATING_MINI_BAR_MAX_WIDTH_VP: number = 560;

/**
 * 播放页浮层在壳层 Stack 里的层级。
 *
 * 必须高于 HdsTabs（自己 `zIndex(1)`，浮动底栏也在它里面）和二级页面的悬浮迷你条。
 * 播放页**不再用 `bindContentCover`**：模态宿主是不透明的一层，会盖住首页与迷你条，
 * 而"从迷你条长出来"的形变恰恰要透出它们（详见 build() 里的注释）。
 */
const PLAYER_OVERLAY_Z_INDEX: number = 100;

/**
 * 形变克隆层（迷你条副本）在壳层 Stack 里的层级：必须**高于**播放页浮层。
 * 反编译里克隆层挂在 `MainPage` 的最上层（三个 lambda），比播放页容器更高。
 */
const PLAYER_CLONE_Z_INDEX: number = 110;

/**
 * ★ 播放页入口**双轨开关**（施工图第 1 步）。
 *
 * - `true` ：播放页作为 **NavDestination** 推入（`pushPath(..., animated = false)`），
 *   完全对标无界 1.2.4。系统转场必须关掉 —— 形变自己就是动画，两套动画叠在一起
 *   就是用户报的"动画中途封面归位 / 底部空一块"。
 * - `false`（**当前，已回退**）：旧路径，播放页作为壳层 Stack 里的浮层（`isShowPlay` 条件渲染）。
 *
 * ⚠️ 回退原因（2026-09-25 上机）：`NavDestination` 是渲染在 `HdsNavigation` 内部的，
 *    它会把**同在该 Navigation 里的 HDS 浮动底栏（迷你条真身）盖住** —— 而形变恰恰要透出
 *    那条迷你条；透明背景也压不住 HDS 自带的底。结果就是"一推入就成一块、底部又缺一块"，
 *    比第 1 步之前更差。**要再走路由化，必须先解决"被盖住的迷你条真身"**（例如把真身也搬进
 *    壳层克隆层、或让迷你条画在 NavDestination 之上），否则不要打开这个开关。
 *
 * 保留它的价值：路由壳（`PlaybackPageRoute.ets` + router_map 的 `player` 条目）已经就位、
 * 随包编译，想再试只需把这里改成 `true`，不用重新搭一遍。
 */
const PLAYER_ROUTE_MODE: boolean = false;

/**
 * 播放页路由参数（对标反编译里的 `param.pull`）。
 *
 * 用类而不是匿名对象字面量：ArkTS 对 `NavPathInfo.param`（`Object`）传字面量容易报类型问题，
 * 显式类型也让"这次进入要不要走形变"这件事在日志里可读。
 */
class PlayerRouteParam {
  /** true = 这次进入要走形变（由手指拖入或点击/意图打开时统一置 true）。 */
  pull: boolean = true;

  constructor(pull: boolean) {
    this.pull = pull;
  }
}

/** 壳层日志标签（`hdc shell hilog | grep HomeShell` 可捞形变/路由链路）。 */
const RzdShellLogTag: string = 'HomeShell';

/**
 * 上拉松手后的收尾时长（ms）。
 *
 * 取无界 Tokens 里的 300（主转场）/ 180（微交互）：够 = 补间到铺满，
 * 不够 = 补间回迷你条那一小块再卸载。
 */
const PULL_OPEN_SETTLE_MS: number = 300;
const PULL_OPEN_ABORT_MS: number = 180;

/**
 * 跟手期间补量"续飞封面终点"的重试次数 / 间隔（ms）。
 *
 * 与 `PlaybackPage` 的 12 × 32ms 同一套窗口（对标反编译 `schedulePublishRetry`）：
 * 播放页是**起手那一刻**才挂载的，它的大封面什么时候可量取决于布局帧数。
 */
const PULL_ANCHOR_RETRY_MAX: number = 12;
const PULL_ANCHOR_RETRY_MS: number = 32;

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
  /**
   * 收起请求通道（与播放页共用）。
   *
   * 系统返回要求关闭播放页模态时，壳层只在这里 `requestCollapse()`；
   * 真正的收起动画由播放页播，播完它自己把 `isShowPlay` 置 false。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  /** Cached window metrics (safe areas, size) for layout padding. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /**
   * 当前导航栈深度（0 = 还在首页 Tab 上，>0 = 已经推入了二级页面）。
   *
   * 只用来决定「全局悬浮迷你播放条」是否显示：首页那份迷你条在 HDS 浮动底栏里，
   * 二级页面会把整个浮动底栏盖住，所以二级页面需要在最外层再挂一份（见
   * {@link floatingMiniBar}）。
   *
   * ⚠️ 不要再拿它去改底部导航的 `barHeight` / `barFloatingStyle`（试过，底栏直接坏掉）。
   */
  @Local navDepth: number = 0;
  /**
   * 形变克隆层用的播放器 VM。
   *
   * 克隆层要画迷你条右侧那一块的**副本**（歌名/歌手 + 播放按钮），它要读当前曲目与播控状态；
   * 与真实迷你条各自持有一个 VM 实例是安全的（VM 只是 `MusicAppState`/`MediaService` 的门面，
   * 状态本身仍然只有一份）。
   */
  @Local miniBarViewModel: PlayerViewModel = new PlayerViewModel();

  /**
   * 窗口宽度（vp），用于给悬浮迷你条算一个**稳定的显式宽度**。
   *
   * 悬浮条是叠在页面上的独立节点，宽度必须自己算准：靠 `width('100%')` + 外层 padding
   * 在部分形态下会算错（hugging 到右边 / 撑成整条大长方形），而百分比宽度又会在
   * 窗口尺寸变化时跳变。这里只在首次和尺寸真正变化时更新。
   */
  @Local viewportWidthVp: number = 0;
  /** 视口高度（vp）：上拉打开的"起手是否在底部"判定与位移映射都要用它。 */
  @Local viewportHeightVp: number = 0;
  /** 上拉打开手势（竖直方向）。 */
  private pullOpenOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });
  private tabsController: HdsTabsController = new HdsTabsController();
  /**
   * 进出二级页面期间抑制 HDS 的样式回调（进二级页面不再改布局状态，只用于出页面时的幂等对齐）。
   */
  private restoringHomeBar: boolean = false;

  /** Initializes play queue ids from local DB for the session. */
  aboutToAppear() {
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto) => dto.id);
    this.ambientState.level = MusicStoreService.getInstance().getAmbientLevel();
    this.themeState.color = MusicStoreService.getInstance().getThemeColor();
    this.homeSourceState.source = MusicStoreService.getInstance().getHomeSource();
    this.miniLyricState.enabled = MusicStoreService.getInstance().getShowMiniLyric();
    AppStorage.setOrCreate('lxPlayQuality', MusicStoreService.getInstance().getPlayQuality());
    AppStorage.setOrCreate('lxPlaybackFlowLight', MusicStoreService.getInstance().getPlaybackFlowLight());
    // 本地音乐库与同步客户端在启动时初始化：本地音乐要建沙箱目录并载入索引，
    // 同步客户端要读回服务器地址与开关（开关为关时不连服务端）。
    //
    // ⚠️ 两个都包 try/catch：它们**不是**播放的前置条件，但都在 `aboutToAppear` 里。
    //    一旦这里抛出去，`aboutToAppear` 会中断，后面（以及将来加在这里的）初始化
    //    全被跳过 —— 那会表现成"莫名其妙整个播放都用不了"，排查起来非常绕。
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
    // 评论面板要能处理本地音乐：把「本地歌 -> 平台身份」的解析交给 comment
    // （comment / player 都不能反向依赖 localmusic，所以这个映射只能由壳层拼）。
    setCommentTargetResolver((song: CommentSongRef): Promise<CommentSongRef | null> => {
      return Promise.resolve(this.resolveCommentTarget(song));
    });
    this.syncViewportWidthVp();
  }

  /**
   * 本地音乐 -> 平台身份（评论面板内部会调用）。
   *
   * 本地歌只存了本地 key，要取评论得先知道它匹配到平台上的哪一首：
   * 用 `localMusic.matchOf` 读匹配记录（自动匹配成功或用户在「匹配歌词」里手选的那条）。
   * 没有记录就返回 null，评论面板会提示「这首歌还没匹配到平台上的版本」。
   *
   * @param song 评论面板给的歌曲身份（本地歌的 songId 就是本地 key）。
   * @returns 平台身份，或 null。
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
   * 记录窗口宽度（vp），供悬浮迷你条算宽度。
   *
   * 只在这里算一次、并在 `onAreaChange` 里刷新：悬浮条是叠在页面上的独立节点，
   * 直接读 `windowInfo.windowSize`（px）在 build 里换算会带进一个不稳定的依赖。
   * @returns 宽度（vp）。
   */
  private syncViewportWidthVp(): void {
    const px: number = this.windowInfo.windowSize.width;
    if (px <= 0) {
      return;
    }
    const vp: number = this.getUIContext().px2vp(px);
    if (Math.abs(vp - this.viewportWidthVp) > 1) {
      this.viewportWidthVp = vp;
    }
    // 高度一起刷（同一份 windowSize，不多花代价）
    const hPx: number = this.windowInfo.windowSize.height;
    if (hPx > 0) {
      const hVp: number = this.getUIContext().px2vp(hPx);
      if (Math.abs(hVp - this.viewportHeightVp) > 1) {
        this.viewportHeightVp = hVp;
      }
    }
  }

  /** Dispatches playback shell intent when {@link PlaybackIntentState.requestVersion} changes. */
  @Monitor('intentState.requestVersion')
  onPlaybackIntentChanged() {
    dispatchShellPlaybackIntent(this.appState, this.intentState, () => {
      // 直接挂起播放页即可：展开动画由播放页自己播（见 playExpandIntro / morphScaleValue）。
      this.appState.isShowPlay = true;
    });
  }

  // ─────────────── 播放页入口：`isShowPlay` → NavDestination 推入 / 弹出 ───────────────
  //
  // ★ 施工图第 1 步的做法：**不逐个改调用点**。
  //   工程里"打开播放页"的写法有五六处（迷你条点击、播放意图、起播意图、上拉松手…），
  //   "关闭"也有三处（播放页返回按钮、下拉收起完成、ControlArea），
  //   与其逐个替换成 push/pop（漏一个就是"有的入口还是旧动画"），不如在壳层把
  //   `MusicAppState.isShowPlay` 这个**既有唯一真源**翻译成路由动作：
  //       isShowPlay: false → true   ⇒ 推入播放页路由
  //       isShowPlay: true  → false  ⇒ 弹出播放页路由
  //   既有调用点一行都不用改，新增入口也自动覆盖。

  /** 播放页挂载/卸载的唯一收口（所有 `isShowPlay` 写入最终都会走到这里）。 */
  @Monitor('appState.isShowPlay')
  onShowPlayChanged(): void {
    if (!PLAYER_ROUTE_MODE) {
      Logger.info('RzdPlayerRoute', `overlay visible=${this.appState.isShowPlay} retainedPaths=${JSON.stringify(this.pageIndexInfos.getAllPathName())}`);
      return;
    }
    if (this.appState.isShowPlay) {
      this.pushPlayerRoute();
    } else {
      this.popPlayerRoute();
    }
  }

  /** 播放页路由在栈里的下标（不在栈里返回 -1）。 */
  private playerRouteIndex(): number {
    const names: string[] = this.pageIndexInfos.getAllPathName();
    if (names === undefined || names.length === 0) {
      return -1;
    }
    return names.indexOf(RouterUrlConstants.PLAYER_PAGE);
  }

  /**
   * 推入播放页路由。
   *
   * ⚠️ 第二参 `animated` **必须是 false**：形变自己就是动画，系统转场会和它叠加
   *    （无界 1.2.4 关掉了它；官方《共享元素转场》指南同样要求 `pushPath()` 关动画）。
   * `param.pull = true` = 这次进入要走形变（对标反编译里的 `param.pull`）。
   */
  private pushPlayerRoute(): void {
    if (this.playerRouteIndex() >= 0) {
      return;
    }
    Logger.info(RzdShellLogTag, 'route: push player (animated=false, param.pull=true)');
    this.pageIndexInfos.pushPath({
      name: RouterUrlConstants.PLAYER_PAGE,
      param: new PlayerRouteParam(true)
    }, false);
  }

  /**
   * 移除播放页路由：收起动画已经由播放页播完，这里不再带系统转场。
   *
   * ⚠️ 不能写成"是栈顶才 pop"：`ControlAreaComponent` 里存在"先 `isShowPlay = false`
   *    再 `pushPathByName(艺人页/搜索页)`"的写法，两个动作的先后顺序不确定。
   *    所以这里按**名字找下标**再删：它在栈顶就 pop，不在栈顶就 `removeByIndexes`，
   *    两种顺序都得到正确结果，也不会留下一条僵尸播放页路由。
   */
  private popPlayerRoute(): void {
    const idx: number = this.playerRouteIndex();
    if (idx < 0) {
      return;
    }
    const names: string[] = this.pageIndexInfos.getAllPathName();
    Logger.info(RzdShellLogTag, `route: remove player at index=${idx} (top=${names.length - 1})`);
    if (idx === names.length - 1) {
      this.pageIndexInfos.pop(false);
    } else {
      this.pageIndexInfos.removeByIndexes([idx]);
    }
  }

  // ─────────────────────── 上拉打开播放页（跟手，壳层侧）───────────────────────
  //
  // 为什么手势必须在**壳层**而不是播放页：播放页在 `bindContentCover` 的模态里，
  // 而模态在 `isShowPlay` 为 false 时**根本不存在** —— 没挂载的页面收不到手指事件。
  // 所以链路是：
  //
  //   壳层 onActionStart（从底部起手）→ 挂载模态（进度 100 = 迷你条那一小块）
  //   → 壳层 onActionUpdate 写 transitionProgress → 播放页 @Monitor 镜像成 collapseProgress
  //   → 高度/缩放/位置/圆角/透明度全部跟着手指走
  //   → 壳层 onActionEnd 过阈值则补间到 0（完全展开），否则补间到 100 并卸载

  /** 上拉打开：起手是否落在屏幕下半部分（只有从底部起手才接管）。 */
  private pullOpenStartsNearBottom(fingers: FingerInfo[]): boolean {
    if (fingers === undefined || fingers.length === 0) {
      return false;
    }
    const h: number = this.viewportHeightVp > 0 ? this.viewportHeightVp : 800;
    return fingers[0].globalY >= h * 0.6;
  }

  /** 上拉开始：进入 ENTERING 阶段（可跟手）并挂载播放页。 */
  private onPullOpenStart(fingers: FingerInfo[]): void {
    // ⚠️ 播放页已经开着就别接管：播放页现在是壳层 Stack 里的普通浮层（不再是模态），
    //    壳层这条手势在它上面依然收得到 —— 不挡一下，用户在播放页里从下半屏往上拖
    //    会把形变进度复位到 0（播放页"啪"地缩回迷你条），
    //    而播放页自己的下拉收起手势同时在跑，两套动画直接打架。
    if (this.appState.isShowPlay) {
      return;
    }
    // ⚠️ 残留在 true 的 `pullDragging` 会**让点击打开永远跳过形变初始化**（页面那边按它
    //    判断"手指正在驱动"）。起手这一刻统一清一次，保证每次打开都是从干净状态开始。
    this.expandState.pullDragging = false;
    if (!this.pullOpenStartsNearBottom(fingers)) {
      return;
    }
    // ★ 先量一次迷你条与宿主的**渲染矩形**（`getRectangleById`，口径 px → vp）：
    //   `onAreaChange` 给的是布局几何、不含祖先 transform，HDS 浮动底栏那点偏移
    //   会让动画起点整体偏（用户实测的"从封面偏左下角开始"）。
    const morphOk: boolean = this.expandState.pullOpenBegin(this.getUIContext(), this.navDepth > 0);
    if (!this.appState.isShowPlay) {
      this.appState.isShowPlay = true;
    }
    if (!morphOk) {
      // 几何没量齐（迷你条没挂载 / 宿主没尺寸）：直接铺满，别硬做形变
      // —— 硬做的话播放页会被压成一条细缝（见 PlayerExpandState.morphUsable）。
      this.expandState.pullDragging = false;
      this.expandState.morphReset();
      this.expandState.morphSettleOpen();
      return;
    }
    // ★ 起手那一刻播放页刚挂载，"续飞封面"的终点（它的大封面）还量不到 —— 补量。
    //   与迷你条自己那条手势里的补量同一套窗口（12 × 32ms，对标反编译 `onPullReady`）。
    this.schedulePullAnchorRemeasure(0);
  }

  /**
   * 跟手期间补量"续飞封面"的终点锚点（播放页大封面）。
   * @param attempt 已尝试次数
   */
  private schedulePullAnchorRemeasure(attempt: number): void {
    if (attempt >= PULL_ANCHOR_RETRY_MAX) {
      return;
    }
    const gen: number = this.expandState.morphGen;
    setTimeout((): void => {
      if (!this.expandState.pullDragging || !this.expandState.morphGenAlive(gen)) {
        return;
      }
      if (this.expandState.measureMiniDuringPull(this.getUIContext(), this.navDepth > 0)) {
        return;
      }
      this.schedulePullAnchorRemeasure(attempt + 1);
    }, PULL_ANCHOR_RETRY_MS);
  }

  /** 跟手更新：位移 → 进度 0…1（**线性**，跟手阶段不加缓动）。 */
  private onPullOpenUpdate(offsetY: number): void {
    if (!this.expandState.pullDragging) {
      return;
    }
    this.expandState.applyMorphProgress(this.expandState.pullOpenFraction(offsetY));
  }

  /** 松手：过阈值补间到 1（展开），否则回到 0 并卸载。 */
  private onPullOpenEnd(_offsetY: number): void {
    if (!this.expandState.pullDragging) {
      return;
    }
    this.settlePullOpen(this.expandState.morphP >= 0.45);
  }

  /**
   * 迷你条自己那条手势发来的收尾请求（松手时它只发请求，补间由壳层播 —— 见
   * `PlayerExpandState.requestPullOpenSettle`）。
   */
  @Monitor('expandState.pullSettleVersion')
  onPullSettleRequested(): void {
    if (!this.appState.isShowPlay) {
      return;
    }
    this.settlePullOpen(this.expandState.pullSettleCommit);
  }

  /**
   * 收尾补间：commit = 推到铺满并落定；否则补间回起点、交还迷你条、卸载播放页。
   * @param commit 是否提交展开
   */
  private settlePullOpen(commit: boolean, attempt: number = 0): void {
    if (!this.expandState.morphUsable) {
      // 快速松手也要完成原尺寸锚点补量；不能先切 ANIM 导致补量停止。
      this.expandState.pullDragging = true;
      this.expandState.morphDrive = MorphDrive.FINGER;
      if (!this.expandState.measureMiniDuringPull(this.getUIContext(), this.navDepth > 0)) {
        if (attempt < PULL_ANCHOR_RETRY_MAX) {
          const pendingGen: number = this.expandState.morphGen;
          setTimeout((): void => {
            if (this.appState.isShowPlay && this.expandState.morphGenAlive(pendingGen)) {
              this.settlePullOpen(commit, attempt + 1);
            }
          }, PULL_ANCHOR_RETRY_MS);
        } else {
          Logger.warn(RzdShellLogTag, 'pull settle: end anchor unavailable, immediate landing');
          this.expandState.pullDragging = false;
          this.expandState.morphReset();
          if (commit) {
            this.expandState.morphSettleOpen();
          } else {
            this.appState.isShowPlay = false;
          }
        }
        return;
      }
    }
    const duration: number = commit ? PULL_OPEN_SETTLE_MS : PULL_OPEN_ABORT_MS;
    this.expandState.pullDragging = false;
    this.expandState.morphDrive = MorphDrive.ANIM;
    const gen: number = this.expandState.morphGen;
    this.getUIContext().animateTo({
      // 无界 Tokens 的标准时长：180ms 微交互 / 300ms 主转场
      duration: duration,
      curve: curves.cubicBezierCurve(commit ? 0.23 : 0.68, 1.0, commit ? 0.32 : 0.77, 1.0)
    }, (): void => {
      this.expandState.applyMorphProgress(commit ? 1 : 0);
    });
    if (commit) {
      // ⚠️ 相位在**补间之外**改：`morphSettleOpen()` 会把"是否裁剪"翻成 false，
      //    放进 animateTo 闭包里会让这种离散属性也去吃补间。
      setTimeout((): void => {
        if (this.appState.isShowPlay && this.expandState.morphGenAlive(gen)) {
          this.expandState.morphSettleOpen();
        }
      }, duration + 20);
      return;
    }
    // 没过阈值：补间回起点，**动画播完**再交还迷你条并卸载。
    // ⚠️ `morphLand()` 不能在补间之前调：LANDING 会让播放页整体不透明度过 0
    //    （见 morphPageOpacity），提前调就看不到"缩回去"的过程了。
    setTimeout((): void => {
      if (!this.appState.isShowPlay || !this.expandState.morphGenAlive(gen)) {
        return;
      }
      this.expandState.morphLand();
      this.appState.isShowPlay = false;
      this.expandState.morphReset();
    }, duration + 20);
  }

  /** 手势被系统抢走：回弹到起点并卸载（否则播放页会一直挂在迷你条那一小块上）。 */
  private onPullOpenCancel(): void {
    if (!this.expandState.pullDragging) {
      return;
    }
    this.settlePullOpen(false);
  }

  /**
   * 形变克隆层：迷你条那条"元信息 + 操作区"的**副本**，钉在它原来的位置，随进度位移并淡出。
   *
   * 反编译依据（`MiniMorph渲染方与顶底栏淡入公式.md`）：
   *   · `λ1e` 元信息克隆：`position(miniMetaLeft, miniMetaTop)` + `translate({x: coverRightShiftAt(t)})`
   *     + `opacity(metaOpacityAt(t))`（`clamp(1 - t/0.35)`）
   *   · `λ1f` 操作区克隆：`translate({y: coverRiseAt(t)})` + `opacity(actionsOpacityAt(t))`
   *     （`clamp(1 - t/0.20)`，比元信息更早消失 —— "右侧三个按钮慢慢隐藏"就是这条）
   *   · 面那一棒（封面克隆）在播放页里（`MorphCoverBridge`），两侧矩形同源。
   *
   * 位移量是**相对量**（`coverRightShiftAt = coverRight(t) - coverRight(0)`），
   * 所以它只会"被封面推着往右走、跟着封面往上抬"，不会跳到别的位置。
   */
  @Builder
  private MorphMiniBarClone() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ⚠️ 必须包一层**定宽的 Row**（不是 Column）：`HomeMiniBarPlayerAside` 的根节点带
      //    `.layoutWeight(1)`，它只在 Row/Column 里生效，而且**方向要对** ——
      //    放进 Column 会让它按"竖直剩余空间"分配、横向退化成 wrap-content，
      //    结果就是右侧那三个按钮整体左移（用户实测两次都是这个症状）。
      Row() {
        HomeMiniBarPlayerAside({
          playerViewModel: this.miniBarViewModel,
          showPreviousTrack: false,
          // 元信息（歌名/歌手）用 `clamp(1 - t/0.35)`，与操作区那一档分开；
          // 它同时被封面"推着往右走"（`coverRightShiftAt`，反编译 λ1e）
          isMorphClone: true,
          metaOpacity: 0,
          metaShiftX: this.expandState.coverRightShiftAt(this.expandState.morphP)
        })
      }
      .width(this.expandState.asideWinW)
      .height(this.expandState.asideWinH)
      .alignItems(VerticalAlign.Center)
      .position({ x: this.expandState.asideWinX, y: this.expandState.asideWinY })
      // 操作区那一档：整块按 `clamp(1 - t/0.20)` 淡出（按钮先没、文字后没）
      .opacity(PlayerExpandState.actionsOpacityAt(this.expandState.morphP))
      // ⚠️ 只做**纵向**位移（反编译 λ1f 的 `coverRiseAt`）。
      //    横向的 `coverRightShiftAt` 是给**元信息**那一层的，套到按钮上会让按钮
      //    横着滑出去 —— 收起时表现成"一个暂停按钮从屏幕外飞进来"。
      .translate({ y: 0 })
    }
    .width(LayoutPolicy.matchParent)
    .height(LayoutPolicy.matchParent)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    // 整层不吃事件：下面就是播放页，玩家的点击必须照常落到播放页上
    .hitTestBehavior(HitTestMode.None)
    .zIndex(PLAYER_CLONE_Z_INDEX)
    .id('rzd_player_actions_clone_host')
    .onAreaChange((): void => {
      const node = this.getUIContext().getFrameNodeById('rzd_player_actions_clone_host');
      if (node !== null) {
        const point = node.getPositionToWindowWithTransform();
        const size = node.getMeasuredSize();
        Logger.info('RzdPlayerViewport', `clone origin=${point.x},${point.y} sizePx=${size.width}x${size.height}`);
      }
    })
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

  /**
   * 单个页签被点击/选中时的弹跳触发计数（每个页签一个）。
   *
   * `symbolEffect(effect, trigger)` 是「trigger 变化就播一次」，所以每个页签必须
   * **各用各的计数** —— 共用一个的话四个图标会一起弹（设计规范要的是「选中态」那一颗弹）。
   */
  @Local tabBounceTriggers: number[] = [0, 0, 0, 0];
  /**
   * 「回到顶部」指令（每个页签一个，递增触发）。
   *
   * 设计规范：点击**当前**页签要把界面回滚到顶部/指定位置。`onTabBarClick` 在
   * 点已选中页签时也会触发，所以不需要在页签里自己加 onClick（那会打断页签切换）。
   */
  @Local tabScrollTopCommands: number[] = [0, 0, 0, 0];

  /** 页签选中态弹跳（BounceSymbolEffect + EffectDirection.DOWN，见底部页签设计规范）。 */
  private playTabBounce(index: number): void {
    const next: number[] = [...this.tabBounceTriggers];
    next[index] = (next[index] ?? 0) + 1;
    this.tabBounceTriggers = next;
  }

  /** 让第 index 个页签的页面回到顶部（该页自己监听这个计数）。 */
  private requestTabScrollTop(index: number): void {
    const next: number[] = [...this.tabScrollTopCommands];
    next[index] = (next[index] ?? 0) + 1;
    this.tabScrollTopCommands = next;
  }

  /** 点页签：切到别的页签由 onChange 处理；点当前页签则回滚到顶部。 */
  private onTabBarClicked(index: number): void {
    if (index === this.tabState.tabIndex) {
      this.playTabBounce(index);
      this.requestTabScrollTop(index);
    }
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
        // 选中态弹跳：`trigger` 变化即播一次（只有这个页签的计数在变，所以只有它弹）
        .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.DOWN),
          this.tabBounceTriggers[index])
      Text(title)
        .fontSize(11)
        .fontColor(this.tabState.tabIndex === index ? this.themeState.color : $r('sys.color.icon_primary'))
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(16)
  }

  /**
   * HDS 回调：迷你条样式变化（与 musicfreeOH 的 `onBarStyleChange` 同款**受控**写法）。
   *
   * USER_CLICK 点击单层圆形胶囊时恢复完整双排。
   * NORMAL/APP_TRIGGER 仅报告输出，不能反向篡改唯一布局状态。
   * miniBarStyle受控；控制器与布局同步切换。
   */
  private onMiniBarStyleChangeFull(miniBarStyle: HdsBarStyle, mode: HdsTabsBarChangeMode): void {
    if (this.navDepth > 0 || this.restoringHomeBar) {
      return;
    }
    if (mode === HdsTabsBarChangeMode.USER_CLICK &&
      this.appState.hdsBarLayoutMode === BarLayoutModes.HORIZONTAL) {
      // HDS expands the round tab inside a horizontal row; restore the entire two-row layout instead.
      this.getUIContext().animateTo({ duration: 300, curve: Curve.Smooth }, (): void => {
        this.appState.hdsBarLayoutMode = BarLayoutModes.VERTICAL;
        this.appState.miniBarExpanded = false;
      });
      this.tabsController.applyMiniBarStyle(HdsBarStyle.COLLAPSE);
      Logger.info(RzdShellLogTag, 'home bar user click restored two rows');
      return;
    }
    const expectedStyle: HdsBarStyle = this.appState.miniBarExpanded ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE;
    Logger.info(RzdShellLogTag, `home bar callback style=${miniBarStyle} expected=${expectedStyle} mode=${mode}`);
    // NORMAL/APP_TRIGGER reports are output, not a second source of layout state.
  }

  /**
   * 传给 HDS 的排布模式。
   *
   * `barLayoutMode` / `HdsBarLayoutMode` 是 **@since 6.1.1(24)** —— 所以工程必须把
   * `targetSdkVersion` 提到 24 以上（本项目已改为 6.1.1(24)，`compatibleSdkVersion`
   * 保持 6.1.0(23) 不影响设备覆盖）。在 target 23 的工程里这个字段不存在，
   * 传进去也不生效，底栏就只能是单排 —— 这正是之前"两排修不出来"的根因。
   *
   * 低配设备（发行版 < 6.1.1(24)）上传 undefined：字段不可用，由 HDS 自行决定。
   * @returns HdsBarLayoutMode 或 undefined。
   */
  private barLayoutModeForHds(): HdsBarLayoutMode | undefined {
    if (!this.supportsTwoRowLayout()) {
      return undefined;
    }
    return this.appState.hdsBarLayoutMode === BarLayoutModes.HORIZONTAL ?
      HdsBarLayoutMode.HORIZONTAL : HdsBarLayoutMode.VERTICAL;
  }

  /** 设备发行版是否支持 `barLayoutMode`（6.1.1(24) 起）。 */
  private supportsTwoRowLayout(): boolean {
    return SdkApiUtil.isDistributionOsApiAtLeast(SdkConstants.DISTRIBUTION_OS_6_1_1_CODE);
  }

  /**
   * 双层底栏占据的额外底部高度。
   *
   * 恒为 0：排布由 HDS 自己处理，页面再额外预留就会多出一块空白。
   * @returns 额外底部预留（vp）。
   */
  private twoRowExtraBottomVp(): number {
    return 0;
  }

  /**
   * HDS 浮动底栏里的迷你播放条。
   *
   * **不要给它固定高度**（原来写死 `.height(56)`）：musicfreeOH 的 `PlayBar` 根节点
   * 只有一个 `.width('100%')`，高度是 HDS 量出来的、并由迷你条自己 `onAreaChange` 读回。
   * 写死高度会让 HDS 在「上下两排」时拿不到正确的内容高度，排布就退化。
   */
  @Builder
  private miniBar() {
    HomeMiniBarPlayer({ showPreviousTrack: false })
  }

  /**
   * 二级页面的悬浮迷你播放条（胶囊）。
   *
   * 形态用**首页两排 Tab 时上面那条**的写法：同一个
   * `HomeMiniBarPlayer({ showPreviousTrack: false, followAppMiniBarExpanded: false })`，
   * 回退普通 Column 胶囊与原 sheet 背景/模糊，不再使用二级 HDS Tabs 试验宿主。
   *
   * 三个尺寸都必须**显式**给，不能靠百分比撑：
   *   - 高度：二级固定封面 30vp + 上下各 6vp，宿主与浮动栏均固定 42vp。
   *     保留原封面、内边距与折叠形态，不改变形变起点。
   *   - 宽度：**显式 vp**（见 {@link floatingMiniBarWidthVp}）。之前靠 `width('100%')` +
   *     外层 padding 居中，在部分形态下算错 —— 要么贴到屏幕右边，要么撑成整条大长方形
   *     （用户反馈的「大长方形，很丑」就是宽度算成了整屏）。写死宽度后居中由
   *     `Column` 的 `alignItems(HorizontalAlign.Center)` 保证，和窗口宽度无关。
   *   - 圆角：胶囊用高度的一半，视觉上才是"一条胶囊"而不是"一块板子"。
   *
   * 触摸：整屏 Stack 必须 `HitTestMode.Transparent` —— 默认的 Default 会把二级页面的
   * 点击全吃掉（踩过）；Transparent 表示自己不吃事件但子节点照常响应。
   */
  @Builder
  private floatingMiniBar() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        HomeMiniBarPlayer({
          showPreviousTrack: false,
          followAppMiniBarExpanded: false,
          lockTwoRowCoverSize: true
        })
          .width(StyleConstants.FULL_WIDTH)
      }
      .width(this.floatingMiniBarWidthVp())
      .height(FLOATING_MINI_BAR_HEIGHT_VP)
      .backgroundColor($r('app.color.floating_mini_bar_sheet_background'))
      .borderRadius(FLOATING_MINI_BAR_HEIGHT_VP / 2)
      .borderWidth(1)
      .borderColor($r('app.color.comp_divider'))
      .clip(true)
      .backgroundBlurStyle(this.miniBarBlurStyle())
      .onAppear((): void => {
        Logger.info('RzdSecondaryMiniMaterial', 'rollback ordinary capsule before HDS experiment');
      })
      .margin({ bottom: this.floatingMiniBarBottomMarginVp() })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignContent(Alignment.Bottom)
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(20)
    // Hidden preserves anchors/layout and hides the restored capsule with its controls immediately.
    .visibility(this.expandState.sourceBarHidden ? Visibility.Hidden : Visibility.Visible)
  }

  /** Restored ordinary capsule blur, not HDS immersive material. */
  private miniBarBlurStyle(): BlurStyle {
    switch (this.ambientLevelIndex()) {
      case 1:
        return BlurStyle.Thin;
      case 2:
        return BlurStyle.Regular;
      case 3:
        return BlurStyle.Thick;
      default:
        return BlurStyle.Regular;
    }
  }

  /** 悬浮迷你条的左右间距（vp）：只在小屏给一点边距，宽屏居中留白。 */
  private floatingMiniBarSideMarginVp(): number {
    return new BreakpointType(12, 16, 96, 160, 9).getWidthValueWithHeightSM(
      this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint);
  }

  /**
   * 悬浮迷你条宽度（vp）。
   *
   * 手机：窗口宽 − 两侧边距（12 / 16）。宽屏：固定胶囊宽度、居中，不再拉满 ——
   * 二级页面上的播放器是"浮起来的一条"，撑满整屏就变成用户说的"大长方形"。
   * @returns 宽度（vp）。
   */
  private floatingMiniBarWidthVp(): number {
    const side: number = this.floatingMiniBarSideMarginVp();
    if (this.viewportWidthVp <= 0) {
      return 336;
    }
    const full: number = this.viewportWidthVp - side * 2;
    const isWide: boolean = this.breakpointEnv.widthBreakpoint !== WidthBreakpoint.WIDTH_SM &&
      this.breakpointEnv.widthBreakpoint !== WidthBreakpoint.WIDTH_MD;
    return isWide ? Math.min(FLOATING_MINI_BAR_MAX_WIDTH_VP, full) : Math.max(220, full);
  }

  /**
   * 悬浮迷你条是否可见。
   *
   * 首页不显示（HDS 底栏里的迷你条负责）；正在播放全屏页或处于批量选择模式时也不显示。
   * @returns True 表示显示壳层这条悬浮迷你条。
   */
  private shouldShowFloatingMiniBar(): boolean {
    if (this.navDepth <= 0) {
      return false;
    }
    // ⚠️ 形变期间**必须继续显示**：播放页浮层是从这条迷你条那里长出来的，
    //    起手那一帧播放页还是全透明的（`morphPageOpacity` 前 12% 才淡到 1），
    //    这时候把迷你条藏了，用户看到的就是"屏幕下方突然空了一块"再冒出一个方块。
    //    它自己在形变期间会淡出（`miniBarOpacity`），交棒给播放页。
    if (this.appState.isShowPlay && !this.expandState.morphContainerActive()) {
      return false;
    }
    // ★ 二级页面上 HDS 浮动底栏不可见（被 NavDestination 盖住），播放器只能由壳层这一条负责 ——
    //   所以**展开态也必须显示**。旧代码在这里 `miniBarExpanded` 为真就返回 false，
    //   于是进二级页面时必须把 `miniBarExpanded` 强行收回折叠态，
    //   而 HDS 的 barLayoutMode 还是 HORIZONTAL ⇒ 底栏变成「长条Tab + 圆形播放器」这种错误组合，
    //   只能在退出二级页面时再纠正一次（用户反馈的动画异常就是这么来的）。
    //   现在不再收：二级页面照常显示这条播放器（它同时是播放页形变的起点）。
    return true;
  }

  /**
   * 悬浮迷你条距底部间距。
   *
   * 二级页面没有浮动页签，所以只需避开系统导航栏 + 少量留白，
   * 比首页那条（在底栏内）明显更靠下。
   * @returns 底部间距（vp）。
   */
  private floatingMiniBarBottomMarginVp(): number {
    const systemInset: number = this.windowInfo.navigationBarBottomVp > 0 ?
      this.windowInfo.navigationBarBottomVp :
      WindowUtil.getInstance().getStartupNavigationBarBottomVp();
    return Math.max(12, systemInset + 8);
  }

  /** Tab pages: recommend, playlist (history/favorites), mine, settings. */
  @Builder
  private HomeTabsPages() {
    TabContent() {
      Column() {
        RecommendPage({
          shellProvidesFloatingMiniBar: deviceInfo.distributionOSApiVersion >= 60100,
          floatingBarExtraBottomReserveVp: this.twoRowExtraBottomVp(),
          scrollTopCommand: this.tabScrollTopCommands[0]
        })
          .layoutWeight(1)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .tabBar(this.TabBarItem(0, $r('app.string.tab_home'), $r('sys.symbol.house_fill')))

    TabContent() {
      Column() {
        PlaylistsPage({ scrollTopCommand: this.tabScrollTopCommands[1] })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(1, $r('app.string.tab_music_hall'), $r('sys.symbol.auditorium')))

    TabContent() {
      Column() {
        MinePage({ scrollTopCommand: this.tabScrollTopCommands[2] })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(2, $r('app.string.tab_cafe_listen'), $r('sys.symbol.person_crop_circle_fill_1')))

    TabContent() {
      Column() {
        SettingPage({ scrollTopCommand: this.tabScrollTopCommands[3] })
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
          HdsTabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
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
            // ⚠️ 不要传 barWidth。
            // musicfreeOH 的浮动底栏只有 barBottomMargin / systemMaterialEffect /
            // adaptToHandedness / miniBar 四个键 —— 没有 barWidth。我们原来传的三档
            // （smallWidth = 窗口宽 − 96 / 284 / 328）会让整条底栏明显窄于屏幕，
            // 「上下两排」时两侧就留出很大空隙（用户反馈的就是这个）。
            barBottomMargin: this.homeTabBarBottomMarginVp(),
            systemMaterialEffect: this.ambientLevelIndex() === 1 ?
              { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.SMOOTH } :
              this.ambientLevelIndex() === 2 ?
                { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.GENTLE } :
                this.ambientLevelIndex() === 3 ?
                  { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.EXQUISITE } :
                  { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
            // 智感握姿：跟随握持手调整浮动条左右偏置
            adaptToHandedness: true,
            miniBar: {
              miniBarBuilder: (): void => {
                this.miniBar();
              },
              // ★ 双层底栏的关键：barLayoutMode = VERTICAL 才把迷你条与页签排成上下两排。
              //   该字段是 @since 6.1.1(24)，所以工程 targetSdkVersion 必须 ≥ 24
              //   （本项目已由 6.1.0(23) 提到 6.1.1(24)，compatibleSdkVersion 保持 23，
              //     设备覆盖不变）。低配发行版上传 undefined。
              barLayoutMode: this.barLayoutModeForHds(),
              // 受控属性：折叠态 = 窄胶囊，点击后由 onBarStyleChange 透出再回灌
              enableMiniBarBackground: !this.expandState.sourceBarHidden,
              miniBarStyle: this.appState.miniBarExpanded ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE,
              onBarStyleChange: (miniBarStyle: HdsBarStyle, _tabStyle: HdsBarStyle,
                _miniWidth: number, _tabWidth: number, mode: HdsTabsBarChangeMode): void => {
                this.onMiniBarStyleChangeFull(miniBarStyle, mode);
              }
            }
          })
          .onChange((index: number) => {
            if (index !== this.tabState.tabIndex) {
              this.tabState.tabIndex = index;
              // 切到新页签：选中态弹一下（点击与滑动切换都会走这里）
              this.playTabBounce(index);
            }
          })
          // 点页签：点的是**当前**页签时回到顶部（切页签交给 onChange）
          .onTabBarClick((index: number): void => {
            this.onTabBarClicked(index);
          })
          .height(StyleConstants.FULL_HEIGHT)
          .width(StyleConstants.FULL_WIDTH)
        } else {
          HdsTabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
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
            if (index !== this.tabState.tabIndex) {
              this.tabState.tabIndex = index;
              this.playTabBounce(index);
            }
          })
          .onTabBarClick((index: number): void => {
            this.onTabBarClicked(index);
          })
          .height(StyleConstants.FULL_HEIGHT)
          .width(StyleConstants.FULL_WIDTH)
        }
      }
      .mode(NavigationMode.Stack)
      .customNavContentTransition((from: NavContentInfo, _to: NavContentInfo,
        operation: NavigationOperation): NavigationAnimatedTransition | undefined => {
        return getPlaylistTransitionState().navigationReturn(this.getUIContext(), from, operation);
      })
      .backgroundColor($r('app.color.home_page_background'))
      .hideTitleBar(true)
      .hideToolBar(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      // 播放页**不再用 `bindContentCover`**：直接作为本 Stack 的浮层挂载（见下面那段注释）。
      // 模态那条路走过很久，结论是它和"从迷你条长出来"的形变根本不兼容：
      //   · `ModalTransition.DEFAULT` 自带"从底部推上来"的位移，会和形变的位移叠加；
      //   · `ModalTransition.NONE` 虽然没有位移，但模态宿主是不透明的一层，
      //     把首页和迷你条全盖住（形变要透出来的正是它们），于是只剩"黑底 + 下方空白"。
      .onNavBarStateChange((isVisible: boolean): void => {
        // 每次导航栏可见性变化都刷新栈深度（推入/弹出二级页面都会触发）
        this.syncNavDepth();
      })

      // ★ 播放页：**不用模态，直接挂在壳层的 Stack 里**（对标无界：播放页与首页在同一个
      //   视图树里；PC 壳层本来就是这么挂的）。
      //
      // 为什么把 `bindContentCover` 换掉（三个用户实测 bug 的根因都在这里）：
      //   1. 模态的宿主是**不透明**的一层，它盖住了首页和迷你条 —— 而形变的观感靠的正是
      //      "迷你条在那、它慢慢变大"：迷你条被盖住后，剩下的就是"一块黑背景 + 下方空白"
      //      （模态自己的底色），跟无界的"播放条逐渐变大"完全不是一回事；
      //   2. 形变早期可视矩形只有迷你条封面那么大，模态其余部分是模态底色，不是首页
      //      —— 于是屏幕上是一块黑、一块空；
      //   3. 手势：模态在 `isShowPlay=false` 时根本不存在（上拉打开必须在壳层），
      //      而它存在时又会把壳层的手势全吃掉，导致跟手逻辑两头受制。
      //   挂在壳层 Stack 里就没有这些问题：下层的首页/迷你条还在画，形变的透明区域
      //   透出来的就是首页 —— "播放条逐渐变大、颜色逐渐变成背景、慢慢拓展到整屏"。
      //
      // 系统返回不再由模态的 `onWillDismiss` 拦了，改由本页的 `onBackPress` 拦（见文件末尾）。
      //
      // ⚠️ `PLAYER_ROUTE_MODE = true` 时这一段**不渲染**：播放页由 NavDestination 负责
      //    （见 pushPlayerRoute）。两条路都保留，回退只需改上面那个常量。
      PlaylistTransitionOverlay()
        .zIndex(90)
        .hitTestBehavior(HitTestMode.Transparent)

      if (this.appState.isShowPlay && !PLAYER_ROUTE_MODE) {
        Column() {
          PlaybackPageCoverContent()
        }
        .width(LayoutPolicy.matchParent)
        .height(LayoutPolicy.matchParent)
        // matchParent expands SIZE too; percent height only moved the overlay and left a bottom gap.
        // Expand ONLY the player overlay; do not relayout the retained Navigation window.
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
        // 盖住 HdsTabs（它自己是 zIndex(1)）与二级页面的悬浮迷你条
        .zIndex(PLAYER_OVERLAY_Z_INDEX)
        .id('rzd_player_overlay_viewport')
        .onAreaChange((_oldArea: Area, area: Area): void => {
          Logger.info('RzdPlayerViewport', `overlay=${area.width}x${area.height} window=${this.viewportWidthVp}x${this.viewportHeightVp} top=${this.windowInfo.statusBarTopVp} bottom=${this.windowInfo.navigationBarBottomVp}`);
        })
      }

      // ★ 形变**克隆层**（对标反编译里 `MainPage` 上那三个 lambda：封面克隆 / 元信息克隆 /
      //   操作区克隆）。反编译明确：克隆层挂在 **MainPage**（壳层）而不是播放页，
      //   而且是"画一个副本"、不是给真实封面加 transform。
      //   它必须在**播放页浮层之上**：迷你条真身在浮层之下，背景一不透明就被盖掉了，
      //   所以"起点看起来还是那条迷你条"靠的就是这一层副本。
      //
      // ⚠️ 渲染门用 `morphSessionDriving()`（**真的在播**），不是 `morphContainerActive()`：
      //    点击打开会先进 ENTERING、再重试最多 12×32ms（≈400ms）等终点锚点就绪，
      //    这段"假动画"里形变其实还没开始，但 `morphP` 已被压到 0 ⇒
      //    `actionsOpacityAt(0) = 1` ⇒ 克隆层全亮地挂在屏上漂 ——
      //    用户实测的"三个按钮一直漂移"就是这一段。
      if (this.expandState.morphSessionDriving() && this.expandState.asideWinW > 0) {
        this.MorphMiniBarClone()
      }
      MorphMetaBridge()
        .zIndex(PLAYER_CLONE_Z_INDEX)
        .hitTestBehavior(HitTestMode.None)

      // 全局悬浮迷你播放条：只在二级页面渲染（首页那份在 HDS 浮动底栏里）。
      // 条件渲染而不是常驻 + visibility —— 常驻的整屏透明节点会吃掉底栏手势。
      if (this.shouldShowFloatingMiniBar()) {
        this.floatingMiniBar()
      }

      // Persistent hidden LX source engine host (webview sandbox for user API scripts).
      LXSourceHost()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // 形变宿主：`getRectangleById(MORPH_HOST_ID)` 量的就是这层的渲染矩形
    .id(MORPH_HOST_ID)
    // ★ 上拉打开播放页（跟手，对标无界 ExpandAnimation.applyPullProgress）。
    //   必须挂在**壳层**：播放页在 `isShowPlay` 为 false 时还没挂载，收不到手指事件。
    //   与播放页里的下拉收起方向相反，两条手势互不冲突；
    //   并且只有"从屏幕下半部分起手"才接管，中间区域的上滑照旧交给列表/歌词滚动。
    .gesture(
      PanGesture(this.pullOpenOption)
        .onActionStart((event: GestureEvent): void => {
          this.onPullOpenStart(event.fingerList);
        })
        .onActionUpdate((event: GestureEvent): void => {
          this.onPullOpenUpdate(event.offsetY);
        })
        .onActionEnd((event: GestureEvent): void => {
          this.onPullOpenEnd(event.offsetY);
        })
        .onActionCancel((): void => {
          this.onPullOpenCancel();
        })
    )
    // 窗口尺寸变化（折叠展开 / PC 浮窗拖拽）时刷新悬浮条算宽用的视口宽度
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      // ⚠️ 视口宽高（手势阈值用）仍然只由 `syncViewportWidthVp` 从 windowSize 取整窗口径，
      //    这里**不要**再按本容器的高度覆盖它：那是"内容区高度"，与 `globalY`（窗口坐标）
      //    不是一个口径，混用会让"从下半屏起手"的判定偏移几十 vp。
      this.syncViewportWidthVp();
      // ★ 形变几何的**尺寸**只有唯一的权威来源：**窗口尺寸**。
      //   ⚠️ 千万别拿本容器（或任何参与形变的层）的实测高度当"铺满目标"：那种自噬已经
      //      踩过三次（底部缺一块 / 一块近正方形背景 / 黑底展不开）—— 被形变的那层，
      //      它自己的尺寸就是裁剪窗口，喂回去等于让目标追着自己的中间态跑。
      //      本容器只在**静止态**才等于窗口大小，形变期间并不等于，所以连它也不能信。
      this.expandState.reportWindow(this.viewportWidthVp, this.viewportHeightVp);
      this.expandState.updateChromeTier(this.viewportWidthVp);
    })
  }

  /**
   * 系统返回（返回键 / 返回手势）：播放页开着就先播收起动画，并**消费掉**这次返回。
   *
   * ⚠️ 以前这一步是模态的 `onWillDismiss` 干的；播放页改成壳层 Stack 里的普通浮层之后，
   *    必须在这里拦，否则返回会直接退出应用（或者把播放页底下的二级页面弹掉）。
   * @returns true = 已消费，不再走默认返回逻辑
   */
  onBackPress(): boolean {
    if (!this.appState.isShowPlay) {
      return false;
    }
    // 真正的收起动画由播放页播（它监听 collapseVersion），播完自己把 isShowPlay 置 false
    this.expandState.requestCollapse();
    return true;
  }

  /**
   * 同步导航栈深度。
   *
   * 放在 `onNavBarStateChange` 的下一帧：该回调触发时栈可能还没完成推入，
   * 立刻读 `size()` 会拿到旧值，导致迷你条不出现 / 不消失。
   *
   * ⚠️ **不要包 animateTo**：`animateTo` 会把"节点刚被创建"这件事也一起补间 ——
   * 壳层悬浮迷你条是条件渲染出来的新节点，包进动画就成了淡入，用户明确不要。
   * 迷你条的显隐必须一帧内直接切换；需要动效的只有 `miniBarExpanded` 的收起。
   */
  private syncNavDepth(): void {
    setTimeout((): void => {
      // ★ `navDepth` 的口径是"**二级页面**深度"，**不含播放页**：
      //   形变入口改成 NavDestination 之后播放页自己占一格栈深，如果把它算进来，
      //   （1）播放页底下会凭空冒出一条悬浮迷你条（`shouldShowFloatingMiniBar`），
      //   （2）进播放页会把用户展开的迷你胶囊强行收回折叠态（下面那段），
      //   两条都会破坏形变的起点几何。所以统一在这里扣掉。
      const playerIdx: number = this.playerRouteIndex();
      const depth: number = this.pageIndexInfos.size() - (playerIdx >= 0 ? 1 : 0);
      if (depth === this.navDepth) {
        return;
      }
      const previousDepth: number = this.navDepth;
      this.navDepth = depth;
      if (depth > 0) {
        // ★ 进二级页面**不再**把迷你条强行收回折叠态（旧方案）。
        //   旧方案：`miniBarExpanded = false` 而 `hdsBarLayoutMode` 保持 HORIZONTAL
        //   ⇒ HDS 进入「长条Tab + 圆形播放器」这种错误组合，底栏动画看着就不对，
        //   还得在退出二级页面时再纠正回「长条播放器 + 圆形Tab」。
        //   现在保持 (barLayoutMode, miniBarExpanded) 这一对本来就一致的状态不动：
        //     HORIZONTAL + EXPAND 仍是「长播放器 + 圆Tab」；VERTICAL + COLLAPSE 仍是双层。
        //   二级页面上的播放器由壳层悬浮条负责显示（见 shouldShowFloatingMiniBar）。
        Logger.info(RzdShellLogTag,
          `enter secondary depth=${depth} keep mode=${this.appState.hdsBarLayoutMode} expanded=${this.appState.miniBarExpanded}`);
      } else if (previousDepth > 0) {
        // 出二级页面：状态全程没被改过，这里只跟 HDS 重新对齐一次（幂等，不产生"纠正"跳变）
        this.restoringHomeBar = true;
        this.tabsController.applyMiniBarStyle(this.appState.miniBarExpanded ?
          HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE);
        Logger.info(RzdShellLogTag,
          `leave secondary reassert style=${this.appState.miniBarExpanded ? 'EXPAND' : 'COLLAPSE'}`);
        setTimeout((): void => { this.restoringHomeBar = false; }, 400);
      }
    }, 0);
  }
}