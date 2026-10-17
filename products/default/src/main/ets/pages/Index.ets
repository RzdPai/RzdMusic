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
import { HdsNavigation, HdsTabsController, HdsTabsBarChangeMode, SystemMaterialParams, hdsMaterial } from '@kit.UIDesignKit';
import {
  AmbientState,
  AppStorageKeys,
  BarLayoutModes,
  BreakpointType,
  getWindowInfoState,
  getNavigationBarBottomVpFromWindowUtil,
  getKeyboardBottomVpFromWindowUtil,
  getPlaylistTransitionState,
  HomeSourceState,
  ImmersiveType,
  MusicAppState,
  MusicDbApi,
  MusicStoreService,
  Logger,
  MORPH_HOST_ID,
  MorphStage,
  PlaybackIntentState,
  PlayerExpandState,
  MorphDrive,
  MorphMetaBridge,
  // ★ 2026-10-17（照搬无界 `MainPage.__shrink`）：非手势关闭的快照收缩浮层状态
  MorphShrinkState,
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
import { dispatchShellPlaybackIntent, LXSourceHost, PlaybackPage, PlaybackPageCoverContent, PlayerViewModel } from 'player';
import { RecommendPage } from 'recommendation';
import { EchoReviewPage } from 'recommendation';
// 「现在就听」：底栏第 2 个页签（推荐 / **现在就听** / 回响 / 我的）。
import { NowPlayingFeedPage } from 'recommendation';
import { HomeMiniBarPlayer, HomeMiniBarPlayerAside, PlaylistTransitionOverlay } from 'playlist';
import { MinePage } from 'setting';
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
 * **与首页底栏里那条一致（56）**：封面 44（`HomeMiniBarAlbumCover.coverSideLengthVp()` 常规态）
 * + 上下各 6vp 内边距。用户要求二级页面也用「主页那个高一点的」，不再用 30vp 封面的矮胶囊。
 * 它是播放页形变的起点，几何只随这一处常量变化（别再按首页单排/双排去动它）。
 */
const FLOATING_MINI_BAR_HEIGHT_VP: number = 56;

/** 二级页面悬浮迷你条在宽屏下的最大宽度（vp）：胶囊不该铺满整个平板/桌面窗口。 */
const FLOATING_MINI_BAR_MAX_WIDTH_VP: number = 560;

/**
 * 底栏「现在就听」那一页的页签下标。
 *
 * ★ 用户 2026-10-15（参考图对比）：**这一页要把浮动底栏上方那条小播放条整条藏掉**
 *   —— 参考图里 Tab 栏之上只有一行进度（左当前时间 / 中细条 / 右总时长），没有迷你条。
 *   所以本页做三件事（**排布模式一个字都不动**，见 `barLayoutModeForHds()` 的注释）：
 *   ① {@link miniBar} 条件渲染 ⇒ 那条迷你条的内容为空，HDS 按内容量高 ⇒ **没有那一排**；
 *   ② {@link miniBarStyleForHds} 恒回 `COLLAPSE` ⇒ 即便用户此前把迷你条展开过
 *      （`miniBarExpanded === true`），本页也不会画出一条展开的**空**栏；
 *   ③ `enableMiniBarBackground` 在本页为 false ⇒ 不会留下一枚空胶囊背板。
 * ⚠️ **不要**改用 `barLayoutMode = HORIZONTAL`（试过，真机反馈"tab 栏短一截"）：
 *   那个模式是"页签与迷你条**并排**"，迷你条空着时页签会被挤到左边、右端空出一格。
 * ⚠️ 顺序与 `HomeTabsPages()` 里 `TabContent` 的次序、`tabScrollTopCommands[i]` 的
 *   下标含义**必须一致**（`tab_now_playing` 那一项就是它）。
 */
const NOW_PLAYING_TAB_INDEX: number = 1;

/**
 * 键盘弹出时，二级页面悬浮迷你条**再往上抬多少**（vp）的两个常量。
 *
 * 背景（官方《自定义键盘》）：系统默认的键盘避让**只保证输入框不被遮挡**，
 * 输入框下面的组件（本条悬浮播放条就是）会被键盘压住 ⇒ 必须自己按键盘高度避让。
 *
 * 算式（`floatingMiniBarKeyboardLiftVp()`）：
 *   lift = 键盘高度 + {@link FLOATING_MINI_BAR_KEYBOARD_GAP_VP} − 常态下胶囊离屏底的既有间隙
 * 其中"既有间隙"按 2026-10-12 的真机两点标定 `gap ≈ 1.8 × barBottomMargin` 反推
 * （见 {@link floatingMiniBar} 里那两条实测记录）—— 减掉它是为了**不要把已经有的那份间隙
 * 重复算一遍**，否则键盘态会比常态明显浮高一截（§29.1 用户就报过"播放条浮得太高"）。
 *
 * ⚠️ 真机调法（只动这两个常量，别改算式）：
 *   · 键盘态偏高 ⇒ 调**大** FACTOR（多减一点）；偏低 / 仍被压住 ⇒ 调**小** FACTOR（减 0 = 整条上移一个键盘高）。
 *   · 想整体再多留一点缝 ⇒ 调大 GAP。
 */
const FLOATING_MINI_BAR_KEYBOARD_GAP_VP: number = 8;
const FLOATING_MINI_BAR_CAPSULE_GAP_FACTOR: number = 1.8;

/**
 * 上拉打开播放页的**起手热区**高度（vp，贴屏幕底那一条）。
 *
 * 迷你条 56 + 底部避让（导航条/小白条约 14~24）+ 8 的边距，再往上一小段余量 ≈ 112。
 * 只有落在这条带里的上滑才由壳层接管（详见 `pullOpenStartsNearBottom()`）——
 * 页面中段的上滑交还给列表，避免「我的页从播放器上面一部分上滑也打开播放器」。
 */
const PULL_OPEN_HANDLE_BAND_VP: number = 112;

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
 * ★ 2026-10-17：快照收缩浮层（`ShrinkOverlayHost`）的层次 —— **必须比上面所有浮层都高**。
 *   它代表"正在消失的那一屏播放页"，压在克隆层（110）与迷你条之上才不会被盖住。
 *   ⚠️ 无界那一侧它也没有专门的 z（`MainPage` 里它排在浮层宿主之后），
 *     这里显式给一个值只是为了**不依赖声明顺序**。
 */
const SHRINK_OVERLAY_Z_INDEX: number = 130;

/**
 * ★ 播放页入口**双轨开关**（施工图第 1 步）。
 *
 * - `true` ：播放页作为 **NavDestination** 推入（`pushPath(..., animated = false)`），
 *   完全对标无界 1.2.4。系统转场必须关掉 —— 形变自己就是动画，两套动画叠在一起
 *   就是用户报的"动画中途封面归位 / 底部空一块"。
 * - `false`：旧路径，播放页作为壳层 Stack 里的浮层（`isShowPlay` 条件渲染）。
 *
 * ─────────── ★★ 2026-10-15：**已打开**，因为上次回退的根因找到了 ───────────
 * **原来为什么回退**（2026-09-25 上机）：`NavDestination` 渲染在 `HdsNavigation` 内部，
 * 用的是 **STANDARD** 模式 —— 那个模式下它**自带不透明底**，"透明背景也压不住 HDS 自带的底"，
 * 于是同在该 Navigation 里的 **HDS 浮动底栏（迷你条真身）被整片盖住**，
 * 而形变恰恰要透出那条迷你条 ⇒ "一推入就成一块、底部又缺一块"。
 *
 * **这次的解药（逆向得到，已核实到 API 层）**：
 * 无界的播放页 `HdsNavDestination` **设了 `mode(NavDestinationMode.DIALOG)`**
 * （`wujie.pa:190804-190811`）。官方语义（本机 SDK
 * `openharmony/ets/component/nav_destination.d.ts:317-333`）：
 * > "Dialog mode, where the navigation destination is **transparent by default**,
 * >  and adding or removing the navigation destination **does not affect the underlying
 * >  page's lifecycle**."
 * ⇒ **默认透明 + 不影响下层页面** ⇒ 下层首页与迷你条**不被盖住、不被隐藏**，
 * 形变全程**可见且可量**（`expand.init` 正是靠 `getFrameNodeById` 的矩形算起点）。
 * 这一句已经加在 `features/player/.../PlaybackPageRoute.ets` 的 `.mode(...)` 上。
 *
 * ⚠️ **DIALOG 的两个代价**（`PlaybackPageRoute.ets` 里已处理/已注明）：
 *   ① DIALOG 默认**不响应返回键** ⇒ 必须显式 `.onBackPressed()`（已给）；
 *   ② 不再有系统转场与系统底 ⇒ 顶栏/背景/裁剪全由播放页自己画（本该如此）。
 *
 * ⚠️ **回退方法**：把这里改回 `false` 即可回到"壳层浮层"那条已验证可用的路
 *    （浮层代码与克隆层都还在，随包编译，不用重新搭）。
 */
const PLAYER_ROUTE_MODE: boolean = true;

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
 * 上拉松手后的收尾时长（ms）—— **提交（够阈值）** 与 **取消（不够阈值）** 两个值。
 *
 * ★★ 2026-10-15（照搬无界：改成**它那套形变自己的常量**）：
 *   无界的 `commitPull()` / `cancelPull()` 都走 `animateMorphT(SETTLE_MS, t, EASE_OUT_STR)`，
 *   而 **`SETTLE_MS = 400`，且提交与取消是同一个值**
 *   （`_recover/logic-src/开关播放器-手势路径定稿.md` §0 速查 L25/L26 与 §八 L219/L220，
 *   后者逐条给了字节码行号 L146973 / L146866）。
 *
 * ⚠️ 改前是 **300 / 180**，原注释写着"取无界 Tokens 里的 300（主转场）/ 180（微交互）" ——
 *   **取错了来源**：那是无界的**通用设计 token**，而这里要的是**这套形变自己的**常量
 *   （`MainPage.SETTLE_MS`）。同一个错误来源在"关闭时长"上已经犯过一次（§56.20：
 *   那处不仅时长偏短，缓动还整条抄成了"打开"用的那条 ⇒ 用户实测「关闭几乎没动画」）。
 *
 * ★ 顺带一个正面效果：壳层叠加层（`MorphCoverClone`）跑的是无界 `ENTER_MS = 560ms`（已对齐）。
 *   改前播放页 `300 + 20 = 320ms` 就落位，**离叠加层的 560 差 240ms**（要靠
 *   `morphOverlayBridging()` 兜着才不被切断）；改成 400 后落位在 `420ms`，
 *   **差距缩到 140ms** ⇒ 被切断的风险更小。
 *
 * ⚠️ 这是**纯观感**改动（无功能影响）。若你上机觉得"打开变钝了"、不如原来跟手，
 *   **回退就是把这两行改回 `300` / `180`** —— 一处一行，互不影响。
 */
const PULL_OPEN_SETTLE_MS: number = 400;
const PULL_OPEN_ABORT_MS: number = 400;

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
  /**
   * ★★★ 2026-10-17（照搬无界 `MainPage` 的 `__shrink` + `shrinkPixmap`）：
   * 「非手势关闭」（关闭按钮 / 系统返回）那一棒的**满窗快照浮层**。
   *
   * 无界那一侧这两样都挂在 `MainPage` 上（`wujie.pa:143995` / `144006`），
   * 渲染点也在 `MainPage`（`162465-162707`）—— 所以本仓同样由**壳层**持握与渲染。
   * 播放页负责"拍快照 + `start(...)`"（它才知道什么时候要关），壳层负责画。
   */
  @Local shrinkState: MorphShrinkState =
    AppStorageV2.connect(MorphShrinkState, AppStorageKeys.MORPH_SHRINK_STATE,
      () => new MorphShrinkState())!;
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
  @Local miniBarViewModel: PlayerViewModel = new PlayerViewModel();
  private pullOpenOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  /**
   * 诊断闸：本轮手势是否**已经记过一次**"跟手更新被判据拒掉"。
   *
   * 为什么需要它（而不是每次都记）：`onPullOpenUpdate` 由每个触摸移动事件调用，
   * 而计数落在 `PlayerExpandState` 的 `@Trace` 字段上 ⇒ 每次都写会让徽标那个
   * 13 行 `Text` 每帧重建，**诊断本身会把手感搅浑**。诊断只需要"这一轮有没有被拒"
   * 这一个事实 ⇒ 一次手势只记一次（`onPullOpenStart` 里清零）。
   * 读数：徽标第十行 `pd=<起手拒>/<更新拒>/<松手拒>`，见 `PlayerExpandState.pullDropBegin`。
   */
  private pullDropCountedThisGesture: boolean = false;

  /**
   * 一张截图就能拿到 x/y/w/h，下一轮按数字改完即删。
   */
  private tabsController: HdsTabsController = new HdsTabsController();
  /**
   * 进出二级页面期间抑制 HDS 的样式回调（进二级页面不再改布局状态，只用于出页面时的幂等对齐）。
   */
  private restoringHomeBar: boolean = false;

  /**
   * 壳层此刻是否**自己**持有浮层那一棒的补间（`MorphCoverClone` 的 `morphOverlayP`）。
   *
   * 用途只有一个：给 `@Monitor('expandState.morphDrive')` 让路 ——
   * `settlePullOpen` 起完壳层的浮层补间之后会把 `morphDrive` 置成 `ANIM`，
   * 那一瞬监控回调也会被触发；不回让的话它会再起一条方向相反的浮层补间
   * （"松手没过阈值、封面已经往回补了，又被拽到落位"）。
   * 注意它**不是**渲染门（渲染门在 `PlayerExpandState.morphOverlayBridging()` 里）。
   */
  private shellOwnsOverlayTween: boolean = false;

  /** Initializes play queue ids from local DB for the session. */
  aboutToAppear() {
    this.appState.playQueueIds = MusicDbApi.getInstance().getSongList().map((dto) => dto.id);
    // ★ 页签从 4 个收成 2 个（推荐 / 我的）之后，`TabSwitchState.tabIndex` 可能是上一版留下的
    //   越界下标（比如旧的「我的」= 2、「设置」= 3）—— HdsTabs 拿到越界下标会落在空白页上。
    //   共享状态里没有"页签数"这个概念，所以在这里夹一次：越界即回首页。
    // ★ 2026-10-15：「现在就听」插到「推荐」与「回响」之间 ⇒ 页签数变 4，上界 2 → 3。
    //   ⚠️ 这一层没有单一真源：插/删页签必须**同时**改四组按下标取的地方 ——
    //     ① 这里（越界夹取上界）；② `tabScrollTopCommands` 长度；
    //     ③ `tabBounceTriggers` 长度；④ `TabBarItem(i,…)` 与各页 `scrollTopCommand` 的下标。
    //   漏一组就是"错位 / 不弹 / 不复位"。
    if (this.tabState.tabIndex < 0 || this.tabState.tabIndex > 3) {
      Logger.warn(RzdShellLogTag, `tab index out of range (${this.tabState.tabIndex}), reset to 0`);
      this.tabState.tabIndex = 0;
    }
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

  /**
   * 键盘避让诊断：软键盘弹出 / 收起时打一行（`hdc shell hilog | grep RzdKeyboardAvoid`）。
   *
   * ⚠️ **不要在壳层再挂一份窗口监听**：`TYPE_KEYBOARD` 的避让区由
   * `common/musicbasic` 的 `WindowUtil.updateWindowInfo()` 统一监听（全进程唯一一处），
   * 这里只是**读**它写进 `WindowInfo.avoidKeyboard`（`@Trace`）的结果 ——
   * 读 `@Trace` 属性既能驱动本条悬浮条的重新布局，也正好是这个诊断断点。
   */
  @Monitor('windowInfo.avoidKeyboard')
  onKeyboardAvoidAreaChanged(): void {
    Logger.info('RzdKeyboardAvoid',
      `shell secondary bar keyboardVp=${this.keyboardBottomVp()} ` +
        `lift=${this.floatingMiniBarKeyboardLiftVp()} baseOffset=${this.homeTabBarBottomMarginVp()}`);
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
      // ★★★ 2026-10-16（**关闭过程黑匣子 · 唯一能记 `OPN` 的地方就是这里**）：
      //   用户报的「关闭后又突然放一遍展开」—— 头号嫌疑是**壳层把播放页又推了一次**
      //   （`isShowPlay` 在关闭途中被谁写回 true ⇒ 本 `@Monitor` 收到 false→true
      //   ⇒ `beginOpenMorphOnClick()` + `pushPlayerRoute()` ⇒ 新实例、新展开动画）。
      //   这一笔**只有壳层能记**（播放页那一刻已经 pop 了），所以事件日志做成了 public static
      //   （见 `PlaybackPage.evLog` 的说明）。读法见自证徽标第十三行：正常关闭后重新打开，
      //   日志里**只应有一条 `OPN`**；若关闭段之后紧跟一条 `OPN` 而用户并没有点开 ⇒ 就是它。
      PlaybackPage.ev('OPN', `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(2)}`);
      // ★★ 2026-10-15（照搬无界）：**点击打开也必须走形变**。
      //   无界里「点击播放条」和「上滑手势」**共用同一个 `beginMorphEnter`**
      //   （全包只有 `openPlayerMorph` 与 `pullStart` 两个调用者，见
      //   `_recover/logic-src/点击打开播放器形变链路.md` §一）。此前这里只推路由、
      //   不启动形变 ⇒ 点击走的是播放页里那套**派音自播**（`collapseProgress`），
      //   与上滑的壳层形变是两条互不相干的动画 —— 用户实测「点击打开播放器没有动画」
      //   「背景不对」就是它。顺序对齐无界：① 量源并进相位 → ② 推路由挂载
      //   → ③ 量终点（`onPullReady` 等价物）→ ④ 收尾补间 `commitPull()` 等价物。
      const morphStarted: boolean = this.beginOpenMorphOnClick();
      this.pushPlayerRoute();
      if (morphStarted) {
        // ★★★ 2026-10-16（**点击打开没有封面动画**的最后一块拼图）：
        //   显式把「浮层那一棒」（壳层 `MorphCoverClone` = 续飞封面）起起来，
        //   **不再只依赖** `@Monitor('expandState.morphDrive')`。
        //
        // ## 为什么必须显式
        //
        // 封面那一棒有**两条独立的进度**：
        //   · 播放页那层（`morphP`）—— 容器 scale/translate/clip，**背景也在里面**；
        //   · 浮层那层（`morphOverlayP`）—— 壳层的续飞封面，**封面就靠它飞**。
        // 两条驱动路径：
        //   · 手指跟手：`onPullOpenUpdate` → `syncMorphOverlayFromPage()`（**一比一同步**）✓
        //   · 点击/松手：`settlePullOpen` → `morphOverlayTweenTo()`，
        //     以及 `@Monitor('expandState.morphDrive')` → `focusMorphOverlayForPageIntro()`。
        // ⚠️ 后者是 **V2 异步回调**，而 `focusMorphOverlayForPageIntro()` 里有两道**静默 return**
        //   （`morphDrive !== MorphDrive.ANIM` / `!morphContainerActive()`）—— 它**不写日志**，
        //   一旦那一刻相位还没就位，这一棒就**整段不播、而且查不出来**。
        //   用户实测「**点击播放条打开播放器 / 点击关闭 / 系统返回关闭都没有封面动画**」
        //   而「上拉打开正常」，差异正是"跟手那条同步路走通了、非手势这条路没走通"。
        //
        // ⇒ 这里在**推路由之后、相位已就位**的位置显式喊一声
        //   （与 `PlaybackPage.closeFullScreenPlayback()` 里"同步驱动浮层"那条**同款做法**，
        //     见那边 2358-2370 行的长注释 —— 它当时修的正是"关闭没有封面动画"）。
        //   ⚠️ 幂等：`focusMorphOverlayForPageIntro()` 的两道守卫 + `morphOverlayTweenTo()`
        //     的"起点==终点直接返回" / `morphOverlayAnimating` 不抢 ⇒ 重复调用安全。
        this.expandState.focusMorphOverlayForPageIntro(this.getUIContext());
        this.schedulePullAnchorRemeasure(0);
        // 它自带"源几何还没量齐就 32ms 重试"那条窗口，等价于无界的 `ExpandSnapshot.onPullReady`。
        this.settlePullOpen(true);
      }
    } else {
      this.popPlayerRoute();
    }
  }

  /**
   * 点击打开（**非手势入口**）的形变启动 —— 对标无界 `MainPage.openPlayerMorph(src)`。
   *
   * 无界的原文（`点击打开播放器形变链路.md` §一 + 卷首更正）：
   * ```ts
   * openPlayerMorph(src?) {
   *   const s = src ?? this.ownMorphSource;
   *   if (!this.beginMorphEnter(s)) { this.enterAnimStarted = false;
   *                                   this.nav.pushPath({ name: R_PLAYER }); return; }  // 退化：无形变
   *   // beginMorphEnter 内部已经 pushPath({name, param:{pull:true}}, animated=false)
   *   ExpandSnapshot.onPullReady = λ;      // 就绪 → commitPull() → animateMorphT(400, t=1)
   * }
   * ```
   * 本方法只做①「量源并进相位」这一半；②推路由在调用点紧跟其后，③④也由调用点发起
   * （因为 `pushPath` 是壳层的私有动作，不能让本方法反调）。这样点击与上滑
   * **共用同一份几何、同一个相位、同一条收尾补间**，屏上只可能有一个动画主。
   *
   * ⚠️ 三条守卫，缺一条就会和手势或已有会话打架（每一条都有实测依据）：
   *   · `pullDragging` —— 手指正在驱动（`onPullOpenStart` 那条路），让给它，谁也别抢；
   *   · `morphContainerActive()` —— 已经在一个形变会话里（上滑那条路在
   *     `onPullOpenStart` 里已经 `pullOpenBegin` 过，且 `isShowPlay` 也是它置的）
   *     ⇒ 再 begin 一次会把刚量到的几何作废，那就是"覆盖层反复归零"的来源；
   *   · `pullOpenBegin` 返回假（迷你条没挂载 / 宿主没尺寸）—— 退化成"直接铺满"。
   *     这与无界量不到胶囊时打 `morph: 量不到胶囊 barId=… ⇒ 本次退回普通 push(无形变)`
   *     是同一形状：**宁可不做动画，也不能把播放页压成一条细缝**。
   * @returns true = 形变已进入相位（调用方应继续 ③④）；false = 已退化为无动画落位
   */
  private beginOpenMorphOnClick(): boolean {
    this.expandState.resetMorphTrace('clickOpen');
    // ★★★ 2026-10-16（**给这条守卫补自愈** —— 它此前会"永久"挡住点击打开）：
    //   原判据是 `pullDragging || morphContainerActive()`。两条都会**残留**：
    //   · `pullDragging`：手势被打断且没走到收尾（系统抢手势 / 页面被切走）；
    //   · `morphContainerActive()`：相位残留 `ENTERING/LEAVING/LANDING`。
    //   ⚠️ 而**相位残留不是"用户还在用播放页"**：用户点"打开"时 `isShowPlay`
    //      **必然刚从 false 变成 true**（`onShowPlayChanged` 就是它触发的）。
    //      ⇒ 只要"本轮开始时播放页**还没显示**"，那两条残留就都是**上一轮的垃圾**，
    //        应当**清掉并继续**，而不是把这一次打开判成"重复 / 已在会话里"。
    //   ⚠️ 原注释（本文件 4332-4336 行）已经点出这个形状会导致
    //     「**点击打开又退化成派音旧动画**」，但它只给 `dismissMorphActive` 做了自愈，
    //      **这条守卫本身没做**。⇒ 这就是"点了没动画"里最难复现的那一种。
    // ★★★ 2026-10-17（**判据订正 · 第二次**：第一版把**上拉手势**打断了 —— 用户实测「上滑不能自由了」）
    //
    // ## 第一版错在哪（必须记下来）
    //   第一版把判据从 `this.appState.isShowPlay`（恒真）换成 `playerRouteIndex() >= 0`，
    //   用意是让 `staleClr` 自愈真的能跑到。但**上拉打开这条路也走本函数**：
    //   ```ts
    //   // 壳层 onPullOpenStart：
    //   this.expandState.pullDragging = false;
    //   const morphOk = this.expandState.pullOpenBegin(...);   // ← 里面把 pullDragging 置 true
    //   if (!this.appState.isShowPlay) { this.appState.isShowPlay = true; }   // ← 触发本 Monitor
    //   ```
    //   ⇒ 走到这里时 `pullDragging === true`（手指正在驱动）而**路由还没 push**
    //     ⇒ 新判据算出 `routeOnStack === false` ⇒ 落进 `staleClr` 支
    //     ⇒ **`pullDragging = false` + `morphReset()`** ⇒ 跟手会话被自己掐死
    //     ⇒ 「上滑不能自由了」。(旧代码判据恒真 ⇒ 走 `skip` ⇒ 歪打正着地护住了手势。)
    //
    // ## 订正后的结构（**两件事分开判**，这才是原注释真正想表达的意思）
    //   · 原注释自己写着「上拉手势在首页起手时路由还没 push。但那时 `pullDragging === true`
    //     ⇒ 上面那条守卫会先 return（不影响手势）」—— **"手指在驱动就放行"是原有意图**，
    //     只是被恒真的标志实现坏了。
    //   · 所以：**`pullDragging === true` ⇒ 一律放行（那是活会话，不是残留）**；
    //     只有"相位残留**且**没有手指在驱动"才轮到判"是不是真已经在播放页里"。
    //   ⚠️ 第二层判据仍用**硬读数** `playerRouteIndex() >= 0`（与下面 `leakClr` 同口径）——
    //     因为 `isShowPlay` 在唯一调用点上必然已是 true，读它等于没判。
    //   ⚠️ 这一层是必需的：本轮把关闭收尾的 `morphReset()` 改成"等 pop 之后再复位"
    //     （`PlaybackPage.scheduleMorphResetAfterPop`，见 `RzdMusic记忆.md` §125）
    //     ⇒ 关闭后到复位前那一小段相位仍是 `LANDING`；点开时必须能清掉它。
    if (this.expandState.pullDragging) {
      // 手指正在驱动（上拉/下拉跟手）：**活会话**，谁也别动它
      this.expandState.pushMorphTrace('skip');
      Logger.info(RzdShellLogTag,
        `open morph: skip (finger driving; stage=${this.expandState.morphStage} ` +
        `routeOnStack=${this.playerRouteIndex() >= 0 ? 1 : 0})`);
      return false;
    }
    if (this.expandState.morphContainerActive()) {
      // 相位残留但没有手指在驱动 ⇒ 判"用户是不是真的已经在播放页里"
      if (this.playerRouteIndex() >= 0) {
        // 真的已经在播放页里（重复触发）⇒ 保持原行为：让给已有会话
        this.expandState.pushMorphTrace('skip');
        Logger.info(RzdShellLogTag,
          `open morph: skip (already in player; stage=${this.expandState.morphStage})`);
        return false;
      }
      // 残留垃圾 + 用户确实要打开 ⇒ **先清干净再继续**
      this.expandState.pushMorphTrace('staleClr');
      Logger.warn(RzdShellLogTag,
        `open morph: clearing STALE session (stage=${this.expandState.morphStage} ` +
        `drive=${this.expandState.morphDrive} routeOnStack=0)`);
      this.expandState.morphReset();
    }
    // ★★★ 2026-10-16（**判据订正：给"上一会话"补一条硬条件**）：
    //   原来只有上面那条 `pullDragging || morphContainerActive()` 守卫。上一轮把
    //   `aboutToDisappear()` 里那句无条件 `morphReset()` 加了门（"会话活着就不清"）之后，
    //   **会话泄漏**变成可能：`morphSessionStarted` 残留为 true，而 `pullDragging` /
    //   `morphContainerActive()` 都已是假 ⇒ 上面那条守卫**看不见它** ⇒ 下一轮点击
    //   读到 `isFreshSession = false` ⇒ 走"放弃会话"分支 ⇒ **又没动画**。
    //
    //   ⇒ 补一条**硬条件**：`playerRouteIndex() < 0`（播放页路由**不在**栈里）。
    //     全工程 8 处 `isShowPlay = true` 都**不自己 push**，push 只由本文件的
    //     `pushPlayerRoute()` 做 ⇒ **"路由不在栈里"就是"上一轮会话已经结束"的硬证据**
    //     （无论是正常关闭还是被中间打断）。
    //     ⚠️ 唯一要注意：上拉手势在**首页**起手时路由也还没 push。但那时
    //       `pullDragging === true` ⇒ 上面那条守卫会先 return（不影响手势）；
    //       而"点击打开"起手时 `isShowPlay` 刚变 true、`pullDragging` 必为假
    //       ⇒ 落到这里清一次是安全的（清完 `pullOpenBegin` 立刻重建）。
    const routeOnStack: boolean = this.playerRouteIndex() >= 0;
    if (!routeOnStack && this.expandState.morphSessionStarted) {
      this.expandState.pushMorphTrace('leakClr');
      Logger.warn(RzdShellLogTag,
        `open morph: clearing LEAKED session (route not on stack; stage=${this.expandState.morphStage} ` +
        `drive=${this.expandState.morphDrive} usable=${this.expandState.morphUsable} ` +
        `geom=${this.expandState.morphGeomReadyNow()})`);
      this.expandState.pullDragging = false;
      this.expandState.morphReset();
    }
    // ★★★ 2026-10-16（**记住"这一轮是不是新会话"**，它决定 `false` 怎么处理）：
    //   `pullOpenBegin()` 把 `morphSessionStarted` 置真的那一步就是"会话建立"。
    //   在它之前读到 false ⇒ 这是**全新一轮**（用户真的要打开播放器）。
    const isFreshSession: boolean = !this.expandState.morphSessionStarted;
    const ok: boolean = this.expandState.pullOpenBegin(this.getUIContext(), this.navDepth > 0);
    this.expandState.pushMorphTrace(ok ? 'beginOk' : 'beginNo');
    if (!ok && isFreshSession) {
      // ★★★ 2026-10-16（**"点击打开没有动画"的最后一块拼图**）：
      //   这一段原来是"`false` ⇒ `pullDragging=false` + `morphReset()` + `morphSettleOpen()`
      //   + `return false`"，也就是**整段放弃形变会话**。
      //   ⚠️ 而 `pullOpenBegin` 返回 `false` 的**唯一**原因是"这一拍量不到东西"——
      //   点击打开时这**必然**发生（播放页还没挂载、封面节点不存在），
      //   于是这一次打开被永久判成"几何没量到 ⇒ 无形变落位"，
      //   **连一次补量都没试过**（用户实测「点击打开播放器没有封面/背景动画」）。
      //   无界的形状（`MainPage.openPlayerMorph` 149679）：`beginMorphEnter` 返回 false 时
      //   **不放弃**，而是
      // ```ts
      //     this.enterAnimStarted = false;
      //     ExpandSnapshot.onPullReady = () => { … };   // ← 注册回调，等播放页上报几何再接着跑
      // ```
      //   ⇒ 我们的等价物就是**让补量链接手**：保持 `ENTERING/FINGER` 与 `pullDragging`，
      //     由 `settlePullOpen` 的 12×32ms 补量把终点量回来，量到那一拍
      //     （`measureMiniDuringPull` 里）把 `morphGeomReady` 置真、容器第一次落位。
      //   ⚠️ 只在 `isFreshSession` 时这样做：**已经在会话里**（重复触发 / 残留）仍然走原来的
      //     保守分支，免得把用户正在看的那一轮会话清掉。
      this.expandState.pushMorphTrace('awaitGeom');
      Logger.warn(RzdShellLogTag,
        `open morph: geometry not measurable yet ⇒ keep the session and retry ` +
        `(stage=${this.expandState.morphStage} drive=${this.expandState.morphDrive} ` +
        `bigKnown=${this.expandState.bigCoverAnchored()})`);
      return true;
    }
    if (!ok) {
      Logger.warn(RzdShellLogTag,
        'open morph: mini bar / host rect unavailable ⇒ plain landing (no morph)');
      this.expandState.pullDragging = false;
      this.expandState.morphReset();
      this.expandState.pushMorphTrace('noMorph');
      this.expandState.morphStage = MorphStage.OPEN;
      this.expandState.morphP = 1;
      return false;
    }
    Logger.info(RzdShellLogTag, 'open morph: begin from click entry (align Wujie openPlayerMorph)');
    // ★ 壳层浮层那一棒的进度也压回起点：它的静止态初值是 1（"已落位"语义），
    //   不压回 0 的话浮层第一帧会按"落位的大封面"画一次（= 动画里出现第二张封面）。
    this.expandState.morphOverlayReset();
    // ⚠️ **不要在这里**起浮层那一棒的补间：此刻 `morphContainerActive()` 还是假
    //   （`pullOpenBegin` 只把相位置成 ENTERING 的前一步），`focusMorphOverlayForPageIntro()`
    //   会静默 return。浮层的显式驱动放在 `onShowPlayChanged` 里（推路由之后）。
    return true;
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
      PlaybackPage.ev('REM', 'noIdx');
      return;
    }
    const names: string[] = this.pageIndexInfos.getAllPathName();
    Logger.info(RzdShellLogTag, `route: remove player at index=${idx} (top=${names.length - 1})`);
    // ★★★ 2026-10-16（**关闭过程黑匣子 · 第三笔**）：记"路由真的被删掉了"这一刻。
    //   为什么必须记：现在关闭链路的收尾是**同一个 tick 里连着做**的 ——
    //   `isShowPlay=false`（→ 本函数，但 V2 `@Monitor` 是**异步**回调）→ `morphReset()`
    //   （**同步**把 `morphP` 复位成 1、相位清成 NONE ⇒ 容器不再裁剪/缩放 = 满屏）。
    //   ⇒ 两者之间只要隔了哪怕一帧，屏上就是"已经缩成小圆点了" → 突然**满屏播放页**
    //     → 再被 pop 的转场带走。用户报的「动画结束了**突然来个展开播放器的动画**」正是这个形状。
    //   判读：`RST` 与 `REM` 之间的 `t+` 差 > ~16ms ⇒ 至少有一帧满屏中间态 ⇒ 就是它。
    PlaybackPage.ev('REM', `idx=${idx} top=${names.length - 1}`);
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

  /**
   * 上拉打开：起手点是否落在「迷你条那一条带」里（迷你条 = 那个把手）。
   *
   * ⚠️ 旧规则是「从屏幕下半部分（≥60% 屏高）起手就接管」，用户实测（2026-10-11）：
   *   「我的页我从播放器上面一部分的位置上滑也会打开播放器（只有我的页会出现）」。
   *   原因：旧规则把**整个下半屏**都划成拉伸手势的热区。别的页面在那一带正好是长列表 /
   *   滚动视图，竖直拖动被列表先吃掉，壳层这条 `.gesture(PanGesture)`（冒泡阶段，优先级
   *   低于子组件）根本收不到；而「我的」页内容不满一屏（或已经滚到底）时列表不消费拖动，
   *   于是手势冒泡上来、播放器被顺手拉开 —— 所以只有它「漏」。
   *   收紧成：起手点必须落在**底部那一条带**（迷你条 56 + 底部避让 + 上沿余量）内。
   *   页面中段、列表区域的上滑一律交还给滚动视图（这也和"迷你条是把手"的交互直觉一致）。
   * @param fingers 起手手指列表（窗口坐标 globalY，vp）。
   * @returns 是否由壳层接管这次拖动。
   */
  private pullOpenStartsNearBottom(fingers: FingerInfo[]): boolean {
    if (fingers === undefined || fingers.length === 0) {
      return false;
    }
    const h: number = this.viewportHeightVp > 0 ? this.viewportHeightVp : 800;
    const y: number = fingers[0].globalY;
    const bandTop: number = Math.max(h - PULL_OPEN_HANDLE_BAND_VP, h * 0.6);
    return y >= bandTop;
  }

  /** 上拉开始：进入 ENTERING 阶段（可跟手）并挂载播放页。 */
  private onPullOpenStart(fingers: FingerInfo[]): void {
    // ★ 诊断：新一轮手势开始 ⇒ 清掉"本次手势已记过一次拒绝"的闸（见 `onPullOpenUpdate`）。
    this.pullDropCountedThisGesture = false;
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
      // ★ 诊断计数（徽标第十行 `pd=` 的第一个数）：这个数涨 ⇒ 上拉**没有跟手动画**，
      //   原因是"起手那一刻几何没量齐"，与 `pullDragging` 那条路无关（见 `pullDropBegin`）。
      this.expandState.notePullDropBegin();
      this.expandState.pullDragging = false;
      this.expandState.morphReset();
      this.expandState.morphSettleOpen();
      return;
    }
    // ★ 起手那一刻播放页刚挂载，"续飞封面"的终点（它的大封面）还量不到 —— 补量。
    //   与迷你条自己那条手势里的补量同一套窗口（12 × 32ms，对标反编译 `onPullReady`）。
    this.schedulePullAnchorRemeasure(0);
    // ★ 壳层浮层那一棒（`MorphCoverClone`）也压回起点。它的进度 `morphOverlayP`
    //   静止态初值是 1（"已经在落位"的语义），不压回 0 的话浮层第一帧会画成大封面。
    this.expandState.morphOverlayReset();
  }

  /**
   * 跟手期间补量"续飞封面"的终点锚点（播放页大封面）。
   *
   * ⚠️ `attempt` **必须带默认值 `0`**，并且要挡住 `undefined`/`NaN`：
   * `attempt >= PULL_ANCHOR_RETRY_MAX` 对 `undefined` 和 `NaN` **都是 false**，
   * 于是无参调用（或某一层传了 `attempt + 1` 算出 NaN）会让这条 32ms 递归**永不停止**
   * （`features/playlist` 的另两份副本原来就是这个形状，2026-10-15 已对齐；见无界同步 §72）。
   * @param attempt 已尝试次数
   */
  private schedulePullAnchorRemeasure(attempt: number = 0): void {
    if (!Number.isFinite(attempt) || attempt >= PULL_ANCHOR_RETRY_MAX) {
      return;
    }
    setTimeout((): void => {
      // ★★★ 2026-10-16（**同一形状的第 4 处**：`morphGenAlive` 守卫 —— 前 3 处已在 §102/§104 修过）
      //   这里原来是 `if (!pullDragging || !morphGenAlive(gen)) return;`，其中
      //   `gen` 是**发起那一刻**捕获的 `morphGen`。
      //
      // ## 为什么它在点击这条路上是错的
      //   `morphGen` 的语义是"这一轮形变会话的编号"，它被 `morphReset()` **推高**。
      //   而点击打开时，`pushPath` 会让**旧页面实例卸载**，旧实例的 `onDisAppear` 会走
      //   （那条路上目前只有"`morphUsable` 为真就跳过"这一层保护，见 `PlaybackPage.onDisAppear`）
      //   —— 一旦它真的调到了 `morphReset()`，本函数的世代号立刻过期
      //   ⇒ **每一拍都在第 2 行静默 return**（不写日志，查不出来）。
      //   这与 §102 修掉的、以及 §104 修的**完全同一个形状**：
      //     > 用"会话编号"去判"用户还想不想看播放页" —— 两者无关。
      //
      // ## 改法（判据换成更早、更直接的事实）
      //   `pullDragging` 表示"这一轮跟手/收尾还没走完"（`settlePullOpen` 会一直保持它，
      //   直到补间起跑那一刻才置 false）—— 这正是"还要不要继续补量"的真判据。
      //   世代号在这里没有任何正确用途：补量只需要"几何还没齐 + 用户还在等"。
      //   ⇒ 去掉 `gen`，只判 `pullDragging`；再补一条 `isShowPlay`（用户已离开就别量了）。
      if (!this.expandState.pullDragging) {
        return;
      }
      // 用户已经离开播放页（`popPath` 那条路）⇒ 再补量也没人看，收工。
      // ⚠️ 判据用 `isShowPlay` 而**不是**世代号（世代号会被无关的事推高，见上面那段）。
      if (!this.appState.isShowPlay) {
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
      // ★ 诊断计数（徽标第十行 `pd=` 的中间那个数）—— 见 `PlayerExpandState.pullDropUpdate`：
      //   "手指在动但进度不跟"时，这个数会涨，并说明是**判据**拒的（而不是事件没到）。
      // ⚠️ **一次手势只记一次**：本函数由每个 `onActionUpdate` 调用（≈60~120 次/秒），
      //   而计数写的是 `@Trace` 字段 ⇒ 每次都写会让徽标那个 `Text` 每帧重建，
      //   恰好把"手感"搅浑（诊断本身变成干扰源）。诊断只需要"这一轮有没有被拒"这一个事实。
      if (!this.pullDropCountedThisGesture) {
        this.pullDropCountedThisGesture = true;
        this.expandState.notePullDropUpdate();
      }
      return;
    }
    this.expandState.applyMorphProgress(this.expandState.pullOpenFraction(offsetY));
    // ★ 手指跟手那条路上，浮层拷贝的进度与播放页进度**一比一同步**（不跑补间）：
    //   两层在跟手期必须是同一个值，否则松手补间时会先"跳"到浮层自己那个进度上。
    //   两条手势（壳层这条 + 迷你条那条）都写 `morphP`，所以浮层必须**跟着 morphP 走**
    //   而不是等某个入口去设 —— 这样不管哪条手势接到的都能对上。
    this.expandState.syncMorphOverlayFromPage();
  }

  /**
   * 松手：**提交判据交给 `PlayerExpandState.pullOpenShouldCommit()`**（清单 §一 1.2
   * 「进度 OR 速度」）—— 过阈值（或快速上甩）补间到 1（展开），否则回到 0 并卸载。
   *
   * ⚠️ 这里**不要再写 `morphP >= 0.45`**：那条判据原来在三个文件里各写了一遍
   *    （本文件 + 两个迷你条），收敛到 `PlayerExpandState` 一处之后，
   *    改阈值只改那一个常量，不会出现"两条手势临界值不一样"。
   * @param offsetY 松手时的竖直位移（vp，上拉为负）—— 只用来判**方向**
   * @param velocityY 松手时的竖直速度（`GestureEvent.velocityY`）—— 只用来判**快甩**
   */
  private onPullOpenEnd(offsetY: number, velocityY: number): void {
    if (!this.expandState.pullDragging) {
      // ★ 诊断计数（徽标第十行 `pd=` 的最后那个数）—— 见 `PlayerExpandState.pullDropEnd`。
      this.expandState.notePullDropEnd();
      return;
    }
    this.settlePullOpen(
      this.expandState.pullOpenShouldCommit(this.expandState.morphP, offsetY, velocityY));
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

  // ─────────────── 壳层浮层那一棒（续飞封面）的**独立时间线**（560ms）───────────────
  //
  // 结构（对标无界 1.2.4 的 `MainPage.MorphOverlayHost`）：
  //   · 下 层 = 播放页自己：`morphP`，**350ms `Curve.EaseInOut`**（一处没动）；
  //   · 上 层 = **壳层浮层**（`MorphCoverClone()`）：`morphOverlayP`，**560ms + 快出慢收**。
  //
  // 为什么用 `@Monitor` 去追「播放页那一层开始播了」：
  //   点击打开那条路的补间在播放页里（`PlaybackPage.playMorphOpenIntro`），
  //   而**播放页的 350ms 是明令不许动的**；`@Monitor` 是 V2 的**异步监听**，
  //   回调落在播放页那次状态写入的同一轮里 ⇒ 两层"同起"，播放页一行都不用改。
  //   两条路各自命中一个字段：
  //     · 点击打开 → `morphDrive` 变成 `ANIM`（`playMorphOpenIntro` 第一行）；
  //     · 首页/二级页返回、下拉提交 → `morphStage` 变成 `LEAVING`（`morphBeginLeaving`）。
  //   ⚠️ 手指跟手那条路**不走这里**（它在 `onPullOpenUpdate` 里一比一同步），
  //      所以这里不必判 `pullDragging`。

  /** 播放页开始**展开**补间 ⇒ 浮层这一层也起自己那 560ms。 */
  @Monitor('expandState.morphDrive')
  onMorphDriveChanged(): void {
    if (!this.appState.isShowPlay) {
      return;
    }
    // ★ 2026-10-17 现场读数：这一支到底有没有被自己的守卫挡住（`own=1` = 让给壳层那条）
    PlaybackPage.ev('OVI', `drive=${this.expandState.morphDrive} stage=${this.expandState.morphStage} ` +
      `p=${this.expandState.morphOverlayProgress().toFixed(3)} own=${this.shellOwnsOverlayTween ? 1 : 0}`);
    // ⚠️ 壳层自己刚起过浮层补间（`settlePullOpen`）时**让给它**：
    //    否则松手"没过阈值"那条路会被这里反向覆盖 —— 壳层在把浮层补到 0（回弹），
    //    而这里又补到 1，两层方向相反、观感是"封面不肯回去"。
    if (this.shellOwnsOverlayTween) {
      return;
    }
    this.expandState.focusMorphOverlayForPageIntro(this.getUIContext());
  }

  /** 播放页开始**收起** ⇒ 浮层这一层也按自己那 560ms 收回起点。 */
  @Monitor('expandState.morphStage')
  onMorphStageChanged(): void {
    if (!this.appState.isShowPlay) {
      return;
    }
    if (this.expandState.morphStage !== MorphStage.LEAVING) {
      return;
    }
    // ★ 2026-10-17 现场读数：收起这一支的浮层进度与"是否已被占用"
    PlaybackPage.ev('OVC', `stage=${this.expandState.morphStage} ` +
      `p=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
      `bridging=${this.expandState.morphOverlayBridging() ? 1 : 0}`);
    this.expandState.focusMorphOverlayForPageCollapse(this.getUIContext());
  }

  /**
   * 收尾补间：commit = 推到铺满并落定；否则补间回起点、交还迷你条、卸载播放页。
   *
   * ★★★ 2026-10-16（**"点击打开没有封面/背景动画"的真断点**）：
   *   原来的重试分支长这样：
   * ```ts
   *   if (!morphUsable) {
   *     pullDragging = true; morphDrive = FINGER;
   *     if (!measureMiniDuringPull(…)) { …重试/放弃…; return; }   // ← 失败才 return
   *     // 补量成功 ⇒ 掉出 if，**落到下面起补间** ✓
   *   }
   * ```
   *   看着没问题，**但这条 `return` 在外层**（`if (!morphUsable)` 那一层）——
   *   我读源码时先看成了"成功也 return"。复读确认：**补量成功后确实会落到起补间那一段**，
   *   所以这条不是断点。（留这段注释是为了记下"我一度误判过一次"。）
   *
   * ⚠️ 真正要记的是：**这条重试链（12×32ms）是点击路径唯一能把 `morphUsable` 变真的地方**
   *   —— 点击时 `pullOpenBegin` 跑在"播放页还没挂载"那一刻，终点锚点必然量不到。
   *   所以 `morphUsable` 变真之后**必须**有东西把浮层那一棒也起起来；
   *   播放页侧的 `onAppear` 补量（`PlaybackPage` §96.1）与这里的重试是**两条并行路径**，
   *   谁先成功都由各自负责起棒（幂等，重复调用安全）。
   * @param commit 是否提交展开
   */
  private settlePullOpen(commit: boolean, attempt: number = 0): void {
    this.expandState.pushMorphTrace(`settle${attempt}${commit ? 'C' : 'A'}`);
    // ★★★ 2026-10-16（**补量链的门换了个量**）：原来是 `if (!morphUsable)`。
    //   `morphUsable` 是 `morphInitParams()` 的"算出来了"（会因为退回 `onAreaChange`
    //   兜底值、甚至上一轮留下的值而为真）⇒ 用它当"还要不要补量"的判据，补量链会
    //   **提前收工**，而真正该判的是"**终点锚点这次到底量到没有**"。
    //   ⇒ 换成 `morphEndAnchorReady()`；真正的"可以落位"门是 `morphGeomReadyNow()`。
    if (!this.expandState.morphUsable || !this.expandState.morphEndAnchorReady()) {
      // 快速松手也要完成原尺寸锚点补量；不能先切 ANIM 导致补量停止。
      this.expandState.pullDragging = true;
      this.expandState.morphDrive = MorphDrive.FINGER;
      // ★★★ 2026-10-16（**"点击/返回没有动画"的最后一条因果链**）：
      //   这一段先做两步**抢救**，再做原来那次补量（顺序很重要）：
      //   ① 若"形变会话"已经被清掉（`morphSessionStarted === false`）——
      //      典型来源：播放页挂载那一刻，**旧页面实例的 `onDisappear`** 触发了
      //      无条件的 `morphReset()`（`morphGen++`、`morphUsable=false`、
      //      **`morphSessionStarted=false`**）—— 就先**重新起一次入口**，
      //      把 `stage/drive` 摆回 `ENTERING/FINGER`；
      //   ② 然后调原来那次 `measureMiniDuringPull` 补量（它要求 `stage=ENTERING &&
      //      drive=FINGER`，所以①必须在前）。
      //   ⚠️ 顺序反了 ⇒ 补量直接被守卫拦掉（静默返回 false）⇒ 重试 12 次全废。
      if (!this.expandState.morphSessionStarted) {
        this.expandState.pushMorphTrace('reEnter');
        Logger.info(RzdShellLogTag,
          `pull settle: re-enter morph session (was reset by an onDisappear) attempt=${attempt}`);
        if (!this.expandState.pullOpenBegin(this.getUIContext(), this.navDepth > 0)) {
          // 几何还是量不到：保持 `ENTERING/FINGER`，让下面的补量提前 return 去排队重试
          this.expandState.pullDragging = true;
          this.expandState.morphDrive = MorphDrive.FINGER;
        }
      }
      if (!this.expandState.measureMiniDuringPull(this.getUIContext(), this.navDepth > 0)) {
        if (attempt < PULL_ANCHOR_RETRY_MAX) {
          setTimeout((): void => {
            // ★★★ 2026-10-16（**"点击/返回没有动画"的最后一条因果链**）：
            //   这里原来是 `if (isShowPlay && morphGenAlive(pendingGen))`。
            //   ⚠️ `morphGenAlive` 在本场景下**必然为假**，于是整条重试链在第 1 拍就断掉。
            //   ⇒ 修法：**守卫不要挂世代号**。世代号在这里的语义是"这一轮会话是否还有效"，
            //     而"用户还在播放页"（`isShowPlay`）才是真正的有效性判据；
            //     中途被 `morphReset()` 清过一次，重试接着把几何量回来即可。
            //     ⚠️ 只在 `!isShowPlay`（用户已经离开播放页）时才放弃。
            if (this.appState.isShowPlay) {
              this.settlePullOpen(commit, attempt + 1);
            } else {
              Logger.info(RzdShellLogTag,
                `pull settle: aborted (player gone) attempt=${attempt}`);
            }
          }, PULL_ANCHOR_RETRY_MS);
        } else {
          Logger.warn(RzdShellLogTag, 'pull settle: end anchor unavailable, immediate landing');
          this.expandState.pullDragging = false;
          // ★★★ 2026-10-16（**照搬无界把"几何永远没量到"当退化路径**）：
          //   这段原来是"`morphReset()` + commit 时再 `morphSettleOpen()`"——
          //   自相矛盾：`morphReset()` 把几何清成恒等（`morphUsable = false`），
          //   紧接着的 `morphSettleOpen()` 内部 `applyMorphProgress(1)` 又因为
          //   `morphGeomReady` 为假而**什么都不做** ⇒ 容器停在恒等、相位却是 OPEN。
          //   无界的口径更干净（`wujie.pa` 的 `pickCapsuleRect` 那段：量不到就
          //   「**本次退回普通 push(无形变)**」）：**量不到就彻底不要这套动画**，
          //   让播放页以恒等几何、OPEN 相位正常显示，而不是留一个半死的形变会话。
          this.expandState.pushMorphTrace('noGeom');
          this.expandState.morphReset();
          this.expandState.morphStage = MorphStage.OPEN;
          this.expandState.morphP = 1;
          if (!commit) {
            this.appState.isShowPlay = false;
          }
        }
        return;
      }
      // 补量成功 ⇒ 故意**不 return**，落下去起那两条补间（见上面那段注释）。
      this.expandState.pushMorphTrace('measOk');
      Logger.info(RzdShellLogTag,
        `pull settle: remeasured at attempt=${attempt} usable=${this.expandState.morphUsable} ` +
        `stage=${this.expandState.morphStage}`);
    }
    const duration: number = commit ? PULL_OPEN_SETTLE_MS : PULL_OPEN_ABORT_MS;
    // ★★★ 2026-10-17（照搬无界 `MorphGuard.animateMorph` 的第一句）：把"配色安静窗口"
    //   推到**这条补间结束**（`quietMs` 用补间自己的时长 —— 无界那侧也是按调用点传的，
    //   本处没有任何新造常量）。⇒ 展开动画跑着的时候"上色"往后挪，不会在动画中途跳色
    //   （取色是异步的，换歌那一拍它极可能正好落在展开动画中间）。
    this.expandState.markMorphQuiet(duration);
    this.expandState.pushMorphTrace('tween');
    this.expandState.pullDragging = false;
    this.expandState.morphDrive = MorphDrive.ANIM;
    // ★★ 浮层拷贝这一层走**它自己**的时长/曲线（560ms + 快出慢收，对标无界 `animateMorphT`），
    //   与下面这条 300/180ms 的**播放页**补间**同起**（同一帧、同一个任务里两个 `animateTo`）。
    //   ⚠️ 播放页那条**另有一套数值**：`PULL_OPEN_SETTLE_MS` / `PULL_OPEN_ABORT_MS`
    //      （2026-10-15 起 = 无界 `SETTLE_MS` 400 / 400，见那两个常量的注释）。
    //   起点取浮层**当前**进度（跟手停在哪儿就从哪儿接着走）。
    this.expandState.morphOverlayTweenTo(commit, this.getUIContext());
    // ★ 2026-10-17（**浮层这一棒的现场读数** —— 用户「封面跟着播放器走、没有独立飞行」定性用）
    //   `from=` 是这一棒**起手那一刻**的浮层进度；`p=` 是播放页进度；
    //   若 `from=0` 而 commit=1 ⇒ 它本该从迷你条圆圈飞到播放页封面（0→1）；
    //   若 `from=1` ⇒ 已经贴在大封面位置（补间会被 `|to-from|<1e-4` 早退掉，等于**不飞**）。
    PlaybackPage.ev('OVS', `commit=${commit ? 1 : 0} from=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
      `p=${this.expandState.morphP.toFixed(2)} bridging=${this.expandState.morphOverlayBridging() ? 1 : 0} ` +
      `host=${this.expandState.hostsMorphOverlay() ? 1 : 0}`);
    // 标记"浮层这一棒的补间由壳层发起"：`@Monitor('expandState.morphDrive')` 在下面那行
    // 把 drive 置成 ANIM 之后**也会**被触发，没有这个标记的话它会再起一条**方向可能相反**的
    // 浮层补间（回弹那条路正是如此）。标记在补间结束/被新补间取代时清掉。
    this.shellOwnsOverlayTween = true;
    setTimeout((): void => {
      this.shellOwnsOverlayTween = false;
    }, PlayerExpandState.MORPH_OVERLAY_DURATION_MS + 20);
    // ★ 2026-10-16：这里原来还捕获了一个 `gen` 供两处守卫用；那两处守卫已按 §102/§103
    //   改成判 `isShowPlay`（世代号会被"旧实例卸载的 morphReset"推高，与用户意图无关）
    //   ⇒ `gen` 不再需要，删掉声明（ArkTS 对未使用的局部变量较严格，留着会被静态告警）。
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
        // ★★★ 2026-10-16（**同一条因果链的第四处**）：
        //   这里原来是 `if (isShowPlay && morphGenAlive(gen))`。**与重试那条守卫同一个毛病**：
        //   `morphGen` 会被"旧页面实例的 `onDisappear` 无条件 `morphReset()`"推高，
        //   而那个原因与"用户还想不想看播放页"毫无关系。
        //   ⇒ 一旦它变，`morphSettleOpen()` 被跳过 ⇒ **相位停在 ENTERING、`morphUsable` 保持真**
        //     ⇒ `morphClipping()` 恒真 ⇒ 容器一直停在最后那一帧的 `scale/translate/clip`
        //     ⇒ 观感就是「**背景整屏、封面位置不对**」。
        //   ⇒ 改法：只判 `isShowPlay`；再补一条 `geomReady` —— **几何没就绪时不能落位**
        //     （否则会把一帧"没量齐"的中间态固定下来）。
        //   ★★ 2026-10-16（二次订正）：这一条判据原来是 `morphUsable`。但 `morphUsable`
        //     会因为"退回 `onAreaChange` 兜底值"而为真（见 `morphIntroAnchorsReady` 的注释），
        //     它**不足以**说明"终点锚点真的量到了"。`morphGeomReady()` 才是无界
        //     `pullGeomReady` 的等价物（只在 `measureMiniDuringPull` 量到终点那一拍置位）
        //     ⇒ 落位门必须用它，否则会把"半份几何"落定成 OPEN。
        if (this.appState.isShowPlay && this.expandState.morphGeomReadyNow() &&
          this.expandState.morphUsable) {
          this.expandState.pushMorphTrace('settled');
          this.expandState.morphSettleOpen();
        } else {
          this.expandState.pushMorphTrace('settleSkip');
          Logger.info(RzdShellLogTag,
            `pull settle: skip morphSettleOpen showPlay=${this.appState.isShowPlay} ` +
            `usable=${this.expandState.morphUsable} geomReady=${this.expandState.morphGeomReadyNow()} ` +
            `stage=${this.expandState.morphStage}`);
          // ★★★ 2026-10-16（与上面"end anchor unavailable"那条**同一条规则**）：
          //   几何始终没量到 ⇒ 无界的口径是「本次退回普通 push(无形变)」——
          //   必须把相位从 ENTERING 收回来。原来是**只打条日志、什么都不做**：
          //   相位永远停在 ENTERING、`morphContainerActive()` 恒真 ⇒
          //   播放页那条路可能挂着一个半死的形变会话（用户实测的"背景整屏 / 没有动画"）。
          //   ⚠️ 只在"用户在播放页"（`isShowPlay`）时才收 —— 用户已经离开时由 `popPlayerRoute`
          //     那条路自己收（`morphReset` 已在 `onDisAppear` 里跑过）。
          if (this.appState.isShowPlay && !this.expandState.morphGeomReadyNow()) {
            this.expandState.pushMorphTrace('degrade');
            Logger.warn(RzdShellLogTag,
              'pull settle: geometry never ready ⇒ degrade to a plain full-screen player');
            this.expandState.morphReset();
            this.expandState.morphStage = MorphStage.OPEN;
            this.expandState.morphP = 1;
          }
        }
      }, duration + 20);
      return;
    }
    // 没过阈值：补间回起点，**动画播完**再交还迷你条并卸载。
    // ⚠️ `morphLand()` 不能在补间之前调：LANDING 之后播放页整页不再绘制
    //    （`morphPageOpacity()` 在 LANDING 返回 0；★ 见它自己的注释 —— 那个函数
    //     **目前没有消费者**，所以"不画"实际由 `.visibility(isCollapsing)` 与
    //     `morphClipping()` 那条裁剪门共同实现），提前调就看不到"缩回去"的过程了。
    setTimeout((): void => {
      // ★★★ 2026-10-16（**同一条因果链的第五处**）：与上面那条同款订正 ——
      //   去掉 `morphGenAlive`（它会被"旧页面实例卸载时的 `morphReset()`"推高，
      //   与"用户还想不想打开播放页"无关）。若这里被误拦，手势没到阈值的回弹
      //   就会**停在半路**（播放页挂在一块中间大小的窗口上、迷你条也不交还）。
      if (!this.appState.isShowPlay) {
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
      // ★ 与 `onPullOpenEnd` 同族（都是"收尾被拒"）⇒ 计到同一个数上，见 `pullDropEnd`。
      this.expandState.notePullDropEnd();
      return;
    }
    this.settlePullOpen(false);
  }

  /**
   * ★★★★ 2026-10-17（照搬无界 `MainPage` 的快照收缩浮层，`wujie.pa:162465-162707`）：
   * 「非手势关闭」= 把播放页根节点的一张**满窗快照**缩到迷你条胶囊，同时淡出。
   *
   * ## 为什么必须是这样（用户第 ② 条「有背景但是高度特低」的正解）
   * 我们原来（以及现在**下拉**那条路仍然）是**动活的播放页**：改裁剪窗口 + 缩放。
   * 只要"裁剪窗口高度"与"缩放"有一点不同步，屏上就是"有背景、但只剩很矮的一条"。
   * 无界的非手势关闭**根本不动活页面**：它在 `closeWithAnimation()` 里
   * `componentSnapshot.get(PLAYER_ROOT_ID, λ)` 拍一张图，然后 `nav.pop(false)` 把页面卸掉，
   * 再让**这张图**缩下去 ⇒ 图里的背景与封面**同比例一起缩** ⇒ 那种形状**不可能**出现。
   *
   * ## 逐条对照（全部直读，见 `MorphShrinkState` 文件头）
   * ```
   *   If (shrink.visible && shrinkPixmap !== undefined) {          // 162466-162492
   *     Column()
   *       .width('100%')                                            // 162726-162733
   *       .clip(true)                                               // 162734-162741
   *       .height(shrink.clipHeight)                                // 162742-162751
   *       .borderRadius(shrink.radius)                              // 162752-162761
   *       .scale({ x/y: shrink.scaleValue })                        // 162762-162777
   *       .translate({ x: shrink.translateX, y: shrink.translateY })// 162778-162793
   *       .opacity(shrink.opacity)                                  // 162794-162803
   *       .hitTestBehavior(HitTestMode.None)                        // 162804-162812
   *       { Image(shrinkPixmap)                                     // 162820-162828
   *           .width(整窗宽).height(整窗高)                          // 162829-162862（图恒为整窗）
   *           .objectFit(ImageFit.Cover)                            // 162863-162871
   *           .syncLoad(true) }                                     // 162872-162879
   *   }
   * ```
   * ⚠️ 那个 `Column` 的宽度是 `'100%'`（= 整窗宽）**且靠父 `Stack` 的左上角对齐**
   *    —— `MorphShrinkState` 里那组 `endTx/endTy` 正是按"绕自身中心缩放"反解出来的，
   *    两者是一对，**不要**给它加 `.position()` 或改对齐方式。
   * ⚠️ 整层不吃事件（关播放器的瞬间，下面的首页要立刻可用）。
   */
  @Builder
  private ShrinkOverlayHost() {
    if (this.shrinkState.visible && this.shrinkState.pixmap !== undefined) {
      // ⚠️ 外层 `Stack` 必须是 **`Alignment.TopStart` + 整窗盒**：
      //   `MorphShrinkState` 那组 `endTx/endTy` 是按"`Column` 未缩放时占 `x∈[0,W], y∈[0,C]`"
      //   反解出来的（见那个文件头的对账）—— 靠父容器的**左上角对齐**才成立。
      //   盒尺寸用**实测窗口尺寸**显式给（与另外三个浮层同一处修正：不给就只等于安全区之内那块）。
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          Image(this.shrinkState.pixmap)
            // 图恒为**整窗**（无界 `162829-162862` 就是 `px2vp(windowWidth_px/Height_px)`）
            .width(this.expandState.windowWidthVp > 0 ?
              this.expandState.windowWidthVp : StyleConstants.FULL_WIDTH)
            .height(this.expandState.windowHeightVp > 0 ?
              this.expandState.windowHeightVp : StyleConstants.FULL_HEIGHT)
            .objectFit(ImageFit.Cover)
            .syncLoad(true)
        }
        .width(StyleConstants.FULL_WIDTH)
        .clip(true)
        .height(this.shrinkState.clipHeight)
        .borderRadius(this.shrinkState.radius)
        .scale({ x: this.shrinkState.scaleValue, y: this.shrinkState.scaleValue })
        .translate({ x: this.shrinkState.translateX, y: this.shrinkState.translateY })
        .opacity(this.shrinkState.opacity)
      }
      .width(this.expandState.windowWidthVp > 0 ?
        this.expandState.windowWidthVp : StyleConstants.FULL_WIDTH)
      .height(this.expandState.windowHeightVp > 0 ?
        this.expandState.windowHeightVp : StyleConstants.FULL_HEIGHT)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .hitTestBehavior(HitTestMode.None)
      .zIndex(SHRINK_OVERLAY_Z_INDEX)
      .id('rzd_shrink_overlay_host')
    }
  }

  /**
   * 形变克隆层：迷你条那条"元信息 + 操作区"的**副本**，钉在它原来的位置，随进度位移并淡出。
   *
   * 反编译依据（`MiniMorph渲染方与顶底栏淡入公式.md`）：
   *   · `λ1e` 元信息克隆：`position(miniMetaLeft, miniMetaTop)` + `translate({x: coverRightShiftAt(t)})`
   *     + `opacity(metaOpacityAt(t))`（`clamp(1 - t/0.35)`）
   *   · `λ1f` 操作区克隆：`translate({y: coverRiseAt(t)})` + `opacity(actionsOpacityAt(t))`
   *     （`clamp(1 - t/0.20)`，比元信息更早消失 —— "右侧三个按钮慢慢隐藏"就是这条）
   *   · 面那一棒（封面克隆）**也在这个壳层里**了 —— 见 {@link MorphCoverClone}
   *     （2026-10-15 从 `PlaybackPage.MorphCoverBridge` 搬来；两侧矩形同源）。
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
    // ★★★ 2026-10-16（与 `MorphCoverClone()` **同一处修正**，理由逐字相同）：
    //   这里原来是 `LayoutPolicy.matchParent` ×2 ⇒ 拿的是**壳层根 `Stack`** 的尺寸，
    //   而根 `Stack` **没有 `ignoreLayoutSafeArea`** ⇒ 这一层的盒子只等于"安全区之内"那块。
    //   而它的子节点（上面那个 `Row`）用的是 `.position({x: asideWinX, y: asideWinY})`
    //   —— **全窗口坐标**（与迷你条量测同口径）⇒ 当迷你条靠近屏幕底部（`asideWinY ≈ 850`）
    //   时，这一块会落在层盒子**之外** ⇒ 被裁掉 ⇒ 观感是"关闭时**操作区那三个按钮不见了**"。
    //   ⇒ 用**实测窗口尺寸**显式给（量不到时退回 `'100%'`，与改动前逐字一致）。
    .width(this.expandState.windowWidthVp > 0 ? this.expandState.windowWidthVp : StyleConstants.FULL_WIDTH)
    .height(this.expandState.windowHeightVp > 0 ? this.expandState.windowHeightVp : StyleConstants.FULL_HEIGHT)
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

  /**
   * ★★ 形变**浮层**：续飞封面的**壳层克隆**（对标无界 `MainPage.MorphOverlayHost.morphCover`）。
   *
   * 这一棒原来画在播放页内部（`PlaybackPage.MorphCoverBridge`）。搬到这里的原因是**坐标系**：
   * 播放页那一版被画在**被 scale+translate 变换过、还带 `.clip()` 与动态 `.height(morphClipHeight())`
   * 的容器**里，而它拿到的矩形是**窗口坐标** ⇒ 只有 p=1（恒等变换）时严格正确。
   * 历史上它反复出问题（"封面前半段看不见""坐标口径推错""被别的元素挡住"）都出在这个前提上。
   * 浮层这一份**不在那个容器里**：它直接躺在壳层这个满屏 Stack 上，`morphOverlayCoverBridge()`
   * 给的窗口坐标就是它的绘制坐标，**不做任何"页内 ↔ 窗口"换算**。
   *
   * 两层各自的时长/曲线（这是"两层"的关键）：
   *   · 播放页那一层：`morphP`，350ms `Curve.EaseInOut`（**没动**）；
   *   · 这一层：`morphOverlayP`，560ms `cubic-bezier(0.23, 1.0, 0.32, 1.0)`（快出慢收）。
   *
   * ⚠️ 显隐门用 `morphOverlayBridging()`（= `morphBridging()` ∧ 宿主确实接管了这一棒），
   *    **不是**新造一把门；三个副本（封面 / 歌名歌手 / 操作区）能不能同时成立，
   *    以及"迷你条本体被占位顶掉、播放页真封面不画"这三条不变量见任务报告。
   * ⚠️ 整层不吃事件（下面就是播放页，点击/手势必须照常落到播放页上）。
   */
  @Builder
  private MorphCoverClone() {
    Stack() {
      Image(this.miniBarViewModel.songCoverUrl().length > 0 ?
        this.miniBarViewModel.songCoverUrl() : this.miniBarViewModel.songCover())
        // ⚠️ 矩形直接来自共享状态（vp，**窗口坐标**）：宽、高**分开取** ——
        //    播放页封面外有 `layoutWeight(1)` + `constraintSize`，量到的矩形不保证是正方形，
        //    按正方形画会在落位交棒那一刻跳一下（用户实测过的"结束时封面大小跳一下"）。
        .width(this.expandState.morphOverlayCoverBridge().size)
        .height(this.expandState.morphOverlayCoverBridge().height)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.expandState.morphOverlayCoverBridge().radius)
        .clip(true)
        .position({
          x: this.expandState.morphOverlayCoverBridge().x,
          y: this.expandState.morphOverlayCoverBridge().y
        })
    }
    // ★★★ 2026-10-16（**照无界把这一层显式铺满全窗口**）：
    //   原来这里是 `LayoutPolicy.matchParent` ×2 —— 那是拿**父容器（壳层根 `Stack`）的尺寸**，
    //   而**根 `Stack` 自己并没有 `ignoreLayoutSafeArea`**（见它的属性表：只有 `.width/.height('100%')`
    //   + `.id(MORPH_HOST_ID)` + 手势 + `onAreaChange`）⇒ 这一层的盒子只等于"**安全区之内**"那块，
    //   比窗口小（上下各少一个安全区）。
    //
    //   ⚠️ 而 `.position({x, y})` 用的是**全窗口坐标**（`morphCoverRectAt()` 的输出、
    //      与迷你条/播放页封面的量测同口径）⇒ 当封面在**屏上部**（封面页那一端 `y ≈ 136`）
    //      或**屏下部**（迷你条那一端 `y ≈ 850`）时，都会落在这层盒子**之外**
    //      ⇒ 被裁掉 / 不绘制 ⇒ **观感就是"没有封面动画"**。
    //
    //   ⇒ 用**实测窗口尺寸**显式给（与 `PlaybackPageRouteShell.boxWidth/boxHeight()` 同款做法，
    //     那是本仓已经验证过的"铺满窗口"写法），并保留 `ignoreLayoutSafeArea` 双保险。
    //     ⚠️ 量不到窗口时退回 `'100%'`（与改动前逐字一致，不会更差）。
    .width(this.expandState.windowWidthVp > 0 ? this.expandState.windowWidthVp : StyleConstants.FULL_WIDTH)
    .height(this.expandState.windowHeightVp > 0 ? this.expandState.windowHeightVp : StyleConstants.FULL_HEIGHT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .opacity(this.expandState.morphOverlayBridgeOpacity())
    // 整层不吃事件：下面就是播放页，玩家的点击必须照常落到播放页上
    .hitTestBehavior(HitTestMode.None)
    .zIndex(PLAYER_CLONE_Z_INDEX)
  }

  /**
   * 光感标题栏材质（HDS 官方 `systemMaterialEffect`），跟随环境光档位。
   *
   *
   * ⚠️ 这个函数**只能**喂给 HDS 的 `titleBar.style.systemMaterialEffect` 或
   *    `HdsTabs` 的 `barFloatingStyle.systemMaterialEffect`。官方《沉浸光感功耗优化》原文：
   *      「其他组件仅在 Navigation/NavDestination 标题栏或横向 Tabs 中 barPosition 为
   *        BarPosition.End 的底部 TabBar 中生效。在其他区域中设置沉浸光感效果不生效。」
   *    ⇒ 直接把它挂到普通容器（比如下面那条 `floatingMiniBar` 的 Column）上**是不生效的**，
   *    不要那样写。留着它，是为了在"把二级播放条搬进 HdsTabs 的 miniBar"那条路
   *    （见 {@link floatingMiniBar} 的说明）里能直接复用同一套档位。
   * @returns HDS 材质参数（`@since 6.1.0(23)`，default/pc 的 compatible 均 ≥ 23）。
   */
  private ambientTitleMaterial(): SystemMaterialParams {
    switch (this.ambientLevelIndex()) {
      case 1:
        return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.SMOOTH };
      case 2:
        return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.GENTLE };
      case 3:
        return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.EXQUISITE };
      default:
        return { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE };
    }
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
   * **各用各的计数** —— 共用一个的话两个图标会一起弹（设计规范要的是「选中态」那一颗弹）。
   *
   * ⚠️ 长度必须等于页签数（现在是 **4**：推荐 / 现在就听 / 回响 / 我的）：`TabBarItem` 按下标取。
   */
  @Local tabBounceTriggers: number[] = [0, 0, 0, 0];
  /**
   * 「回到顶部」指令（每个页签一个，递增触发）。
   *
   * 设计规范：点击**当前**页签要把界面回滚到顶部/指定位置。`onTabBarClick` 在
   * 点已选中页签时也会触发，所以不需要在页签里自己加 onClick（那会打断页签切换）。
   *
   * ⚠️ 长度必须等于页签数（现在是 **4**）：`HomeTabsPages()` 按下标取。
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
    // ★★ 2026-10-15 真机反馈**不要**在这一页把它压成 HORIZONTAL（我上一版就是那么写的，错了）：
    //   `HORIZONTAL` 是"页签与迷你条**并排**在同一排"的排布 ⇒ 迷你条那一格空着时，
    //   页签被挤到左边、右边留出一格 —— 用户原话「底部 tab 栏切换到这个页面的时候**会短一截**
    //   （像是以前那个**左侧 Tab 栏，右侧圆形播放器**的版本）」说的就是它。
    //   正解：**排布模式完全不动**（跟别的页签逐字一致），只把 {@link miniBar} 的内容让它量成 0 高
    //   （HDS 是按内容量高度的，空 builder ⇒ 没有那一排，见 `miniBar()` 的注释）。
    return this.appState.hdsBarLayoutMode === BarLayoutModes.HORIZONTAL ?
      HdsBarLayoutMode.HORIZONTAL : HdsBarLayoutMode.VERTICAL;
  }

  /** 设备发行版是否支持 `barLayoutMode`（6.1.1(24) 起）。 */
  private supportsTwoRowLayout(): boolean {
    return SdkApiUtil.isDistributionOsApiAtLeast(SdkConstants.DISTRIBUTION_OS_6_1_1_CODE);
  }

  /**
   * 传给 HDS 的迷你条样式。
   *
   * ★「现在就听」页恒为 `COLLAPSE`：那一页既没有迷你条内容（{@link miniBar} 不渲染），
   *   又被 {@link barLayoutModeForHds} 压成单排 —— 而"单排 + `EXPAND`"是已知的错误组合
   *   （底栏会变成「长条 Tab + 圆形播放器」）。见 {@link NOW_PLAYING_TAB_INDEX}。
   * @returns 迷你条样式。
   */
  private miniBarStyleForHds(): HdsBarStyle {
    if (this.tabState.tabIndex === NOW_PLAYING_TAB_INDEX) {
      return HdsBarStyle.COLLAPSE;
    }
    return this.appState.miniBarExpanded ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE;
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
   * ⚠️ **二级页面在栈上时不渲染**（`navDepth > 0`）：二级页面有自己的官方浮动栏
   * （见 {@link floatingMiniBar}），两边渲染的是同一个 `HomeMiniBarPlayer`，
   * 它硬编码 `.id(MINI_BAR_ID)` —— 同时存在就会有两份同 id 的节点，
   * 而播放页形变的起点是 `getRectangleById(MINI_BAR_ID)` 量的，量到哪一份不确定。
   * 2026-10-01 那次回退就是这个坑（记忆 §17.3 / §17.4-3：「两处只能留一处」）。
   *
   * **不要给它固定高度**（原来写死 `.height(56)`）：musicfreeOH 的 `PlayBar` 根节点
   * 只有一个 `.width('100%')`，高度是 HDS 量出来的、并由迷你条自己 `onAreaChange` 读回。
   * 写死高度会让 HDS 在「上下两排」时拿不到正确的内容高度，排布就退化。
   */
  @Builder
  private miniBar() {
    // ★ 用户 2026-10-15：底栏「现在就听」那一页**不画**这条迷你条（参考图里 Tab 栏之上只有进度行）。
    //   见 {@link NOW_PLAYING_TAB_INDEX}。用条件渲染而不是 `Visibility.Hidden`：
    //   保留占位的话 HDS 会继续按"两排"排布，Tab 胶囊会被顶高、底下留下一块空档。
    //   ⚠️ **排布模式不要跟着改**（`barLayoutModeForHds()` 里那段的坑）：
    //     HORIZONTAL 是"页签与迷你条并排"，会让页签被挤到左边、右端空一格（用户看到的"短一截"）。
    //     这里只让 HDS **量到 0 高**（它是按内容量高度的），排布模式与别的页签逐字一致。
    //   ⚠️ 代价：这一页上 `getRectangleById(MINI_BAR_ID)` 量不到迷你条 ⇒ 形变起点只能走兜底几何。
    //     可以接受：本页**不会打开播放页**（`NowPlayingFeedPage` 的 `playAt` 走
    //     `openPlayer=false` / `PlaybackIntentState.openPlayerUi=false`），
    //     而能开到播放页的入口（底栏迷你条点击、系统媒体控制）在本页也不存在/不形变。
    if (this.navDepth <= 0) {
      if (this.tabState.tabIndex === NOW_PLAYING_TAB_INDEX || this.navDepth > 0) {
        // ★★★★ 2026-10-17（**修用户实测「二级页面会出现两个播放条」**）
        //   原来这里只判 `tabIndex === 正在播放`，**没判 `navDepth`** —— 二级页在栈上时，
        //   二级页自己那条官方浮动栏（`floatingMiniBar`）已经在画，首页这条又没卸载
        //   ⇒ 屏上两条播放条。本文件 L1617 的注释早就写明这条不变量
        //   「⚠️ 二级页面在栈上时不渲染（`navDepth > 0`）」—— 代码没跟上。
        //   ⇒ 补上 `navDepth > 0`：二级页在栈上时这一条同样给 0 高（**不卸载**，
        //     保住 `MINI_BAR_ID` 仍在树上，形变起点还能量得到）。
        // ★★ 这一页**显式给 0 高**（而不是"整个 builder 不渲染"）：
        //   官方《设置页签栏的悬浮样式》原文——迷你栏是自定义区域，**跟页签栏高度相等且水平对齐**；
        //   本工程用 `barLayoutMode = VERTICAL` 把它改成上下两排，而 HDS 在那一档是**按内容量高**的
        //   （见 `miniBar()` 上面那段"不要给它固定高度"的记录）⇒ 给一个 0 高容器，
        //   "上面那一排"高度就是 0，页签胶囊的几何与别的页签**逐字一致**。
        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(0)
      } else {
        // ★★ 2026-10-15（回退后重做）**不变量**：一次形变会话期间，迷你条**真身不参与绘制**，
        //   由壳层克隆层（`MorphMiniBarClone` / `MorphMetaBridge`）与播放页内的续飞封面代表它。
        //   `sourceBarHidden` 由会话拥有者唯一写（`morphBeginEntering` / `morphBeginLeaving` 置 true，
        //   `morphLand` / `morphReset` 置 false）⇒ 三条打开路都成立。
        //   不这么做的话：播放页形变期间是**半透明**画出来的，真身会从底下透出来 ——
        //   一边是克隆层画的副本、一边是真身，用户看到的正是"迷你条压在播放页上"（重叠）。
        //   ⚠️ 必须用 `Visibility.Hidden`（保留布局）：形变起点要 `getRectangleById` 量这条栏，
        //   用 `None` 会量不到 ⇒ 动画直接退化。
        HomeMiniBarPlayer({ showPreviousTrack: false })
          .visibility(this.expandState.sourceBarHidden ? Visibility.Hidden : Visibility.Visible)
      }
    }
  }

  /**
   * 二级页面的悬浮迷你播放条：**官方 HDS 浮动栏 + 沉浸光感材质**（用户 2026-10-11 拍板的结构改造）。
   *
   * ══════════════════════ 为什么必须是"一个单页签的 HdsTabs"══════════════════════
   *
   * 官方《沉浸光感功耗优化》原文：「其他组件仅在 Navigation/NavDestination 标题栏或横向 Tabs 中
   * barPosition 为 BarPosition.End 的底部 TabBar 中生效。**在其他区域中设置沉浸光感效果不生效。**」
   * 也就是说：光感材质只有**标题栏**与**底部 TabBar**两个合法宿主。旧写法（壳层 Stack 里一个普通
   * Column 挂 `backgroundEffect`）**永远拿不到官方材质**，只能算自绘近似 —— 用户明确否掉了它。
   *
   * 现在的做法（= 参考工程 `lxmusic-harmony` 的 `views/PanePage.ets` 同一套）：**只有一个页签的
   * HdsTabs**，页签栏的内容（CustomBuilder）就是播放器本体，再加上官方三条件
   *   `barPosition(End)` + `barOverlap(true)` + `vertical(false)`
   * ⇒ 这条栏就落在"底部 TabBar"这个合法宿主里，`systemMaterialEffect` 真生效。
   * 材质档位复用标题栏那一份（{@link ambientTitleMaterial}），不要再内联一套三目。
   *
   * 宿主放在**壳层 Stack 的底部**（与旧胶囊同一个位置、同一套算术），所以二级页
   * （`NavDestination`）盖不住它 —— 这正是它能替掉旧胶囊的原因。
   *
   * ══════════════════════ ★ 一条硬约束：全屏**只能存在一条**迷你条 ══════════════════════
   *
   * 2026-10-01 09:39 试过同一套宿主，回退了，原因就是**同 id 撞车**：
   * 首页底栏的 `miniBar` 与这条二级栏渲染的是同一个 `HomeMiniBarPlayer`，它硬编码
   * `.id(MINI_BAR_ID)`（连带 `MINI_BAR_COVER_ID` / `MINI_BAR_ASIDE_ID`）。二级页在栈上时
   * 首页底栏并没有卸载 ⇒ 屏幕上出现**两份同 id** 的节点，而播放页形变的起点是
   * `getRectangleById(MINI_BAR_ID)` 量的 —— 量到哪一份不确定，起点就抖。
   * ⇒ 所以 {@link miniBar}（首页那条）在 `navDepth > 0` 时**不渲染**，两处只留一处。
   *    改这里之前先看那条注释。
   *
   * ══════════════════ 尺寸 / 触摸 / 形变语义（这些**不能**动）══════════════════
   *
   * 形态用**首页两排 Tab 时上面那条**的写法：同一个
   * `HomeMiniBarPlayer({ showPreviousTrack: false, followAppMiniBarExpanded: false })`。
   *
   * 两个尺寸**显式**给：
   *   - 高度：56vp（封面 44 + 上下各 6vp）。它是播放页形变的起点，几何只随
   *     `FLOATING_MINI_BAR_HEIGHT_VP` 这一个常量变化。
   *   - 宽度：**交给 HDS**（宿主铺满宽度，栏体/胶囊的宽度与居中由官方浮动栏自己算）。
   *     以前我们写死过宽度（`width(窗口宽 − 边距)` + `barFloatingStyle.barWidth`），
   *     真机反馈是"要么贴到屏幕右边、要么撑成整条大长方形，很丑"—— 那是和 HDS 的让位动画打架
   *     （2026-10-01 那次实验的教训），现在不再自己算。
   *   `clip(false)` 要留着：裁了会把 HDS 的背板/折射一起裁掉。
   *
   * 触摸：整屏 Stack 必须 `HitTestMode.Transparent` —— 默认的 Default 会把二级页面的
   * 点击全吃掉（踩过）；Transparent 表示自己不吃事件但子节点照常响应。
   */
  @Builder
  private floatingMiniBar() {
    Stack({ alignContent: Alignment.Bottom }) {
      /**
       * ★★ 关键：`TabContent()` **不能是空的**。
       *
       * 2026-10-01 那次实验就是"空 TabContent + 播放器当 tabBar"，真机上**没有胶囊背板**
       * （作者当时只能补一块自绘背板兜底）。2026-10-11 复现了同一个现象：用户报
       * 「底下播放条是透明的，只看得见封面和按钮」。现在往 TabContent 里放一个**真实的
       * 满尺寸容器**，让 HDS 认为这条栏有内容，从而按悬浮样式画出自己的胶囊背板 + 材质。
       *
       * 另外 `barFloatingStyle` 的键**与首页那条官方底栏保持一致**（只给
       * `barBottomMargin` / `adaptToHandedness` / `systemMaterialEffect`）：
       * 上一版多传的 `barWidth` / `barSideMargin: 0` / `gradientMask: {maskHeight: 0}` 是
       * 2026-10-01 实验那套（**当时正是配着那块自绘背板用的**），现在一律不传，避免任何
       * "自己接管栏体"的暗示，背板/材质全交给 HDS。
       */
      HdsTabs({ barPosition: BarPosition.End }) {
        TabContent() {
          Column()
            .width('100%')
            .height('100%')
        }
        .tabBar(this.floatingMiniBarContent())
      }
      .barMode(BarMode.Fixed)
      .barHeight(FLOATING_MINI_BAR_HEIGHT_VP)
      // ★ 官方三条件：barPosition(End) + barOverlap(true) + vertical(false)。
      //   缺一 `systemMaterialEffect` 就不生效（官方《设置页签栏的悬浮样式》约束条件）。
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .vertical(false)
      .scrollable(false)
      .animationDuration(0)
      // ★★★ 2026-10-16（**方案 A：自绘背板**，与首页那条成对）：
      //   二级页这条 HdsTabs 的**栏背景**同时就是迷你条的背板（整条栏只有一个页签）
      //   ⇒ 把它设成透明 + 无模糊，背板就交给 `HomeMiniBarPlayer.MiniBarBackplate()` 自绘，
      //   于是那一层与内容在**同一棵子树**里 ⇒ 能跟着 `morphSquashY` 一起弹。
      //
      // ⚠️ **代价（如实登记）**：这一栏原来是**官方 `systemMaterialEffect` 真材质**
      //   （`barFloatingStyle.systemMaterialEffect`）。自绘背板用的是我们既有的
      //   `floating_mini_bar_*` token + `BlurStyle` 档位，**与官方材质不会逐像素相同**
      //   ⇒ 二级页这条播放条的外观会与"沉浸光感"略有差别。这是用户 2026-10-16
      //   拍板选方案 A 时接受的代价（备选是"保持官方材质、但背景不会弹"）。
      //
      // ⚠️ 官方《组件适配沉浸光感》原文确实写着「设置悬浮材质后，**不建议**再通过
      //   `barBackgroundColor` / `barBackgroundBlurStyle` 为 TabBar 设置背景色或背景模糊，
      //   避免遮挡材质效果」—— 本处是**有意的例外**：我们要的正是"让 HDS 别再画背板"，
      //   而材质那一档由我们自己按 `ambientState.level` 给（同一套 `BlurStyle` 档位）。
      .barBackgroundColor(Color.Transparent)
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .barFloatingStyle({
        // ★★ 栏宽**必须显式给**（官方 `HdsTabsFloatingStyle.barWidth` 三档）。
        //   ⚠️ 2026-10-11 第六轮我按"参考首页那条"把它去掉了，装到机器上**更糟**
        //   （用户：「播放条原本是错位，现在还没上个版本正常」）⇒ 恢复三档 `barWidth`：
        //   不给就按 HDS 自己的默认宽度画 ⇒ 真机上那条悬浮胶囊只有"一小坨"，
        //   而里面的播放器是按 100% 排的 ⇒ 内容整个溢出胶囊外。
        //   按窗口宽 − 两侧留白给三档同值（宽屏再夹一个最大宽）。
        barWidth: {
          smallWidth: this.floatingMiniBarWidthVp(),
          mediumWidth: this.floatingMiniBarWidthVp(),
          largeWidth: this.floatingMiniBarWidthVp()
        },
        // 离底间距交给 HDS 的浮动栏自己算（与首页那条同口径）
        // ★ 用户 2026-10-12：「播放条整个往下移动一些，就用首页的 Tab 栏的位置」——
        //   原来用 loatingMiniBarBottomMarginVp()（= max(12, 避让 + 8)），比首页底栏高约 8vp；
        //   现在直接用首页那条的 homeTabBarBottomMarginVp()，两条栏**同一个离底口径**。
        // ★ GLM5.3 诊断 + 真机实测 2026-10-12：arBottomMargin 是相对**宿主盒底**算的，而这条宿主只有 56vp
        //   高（首页那条宿主是全屏）⇒ 同一个 margin 值下胶囊被顶高约一个安全区（实测 69vp vs 首页 37vp）。
        //   所以这里 margin 归零，改由宿主整体 offset 下移一份现有 helper 的值（不放魔法数、一行可回退）。
        // ★★ 真机两点标定（2026-10-12）：
        //   · margin = homeTabBarBottomMarginVp()（这台≈38）、无 offset ⇒ 胶囊离屏底 ≈ 69vp（太高）；
        //   · margin = 0 + 宿主 offset(38) ⇒ 胶囊**紧贴屏幕底**（0vp，太低）；
        //   ⇒ 实测近似线性：gap ≈ 1.8 × margin。要"导航条上面一点点"（≈18~22vp）⇒ 取 1/3 份。
        //   一行调法（别动宿主那句 offset）：更贴底改 / 4，更高改 / 2。
        barBottomMargin: this.homeTabBarBottomMarginVp() / 2,
        adaptToHandedness: false,
        // ★ 官方沉浸光感：档位与标题栏/首页底栏共用同一份（ambientTitleMaterial）。
        systemMaterialEffect: this.ambientTitleMaterial()
      })
      .width(StyleConstants.FULL_WIDTH)
      .height(FLOATING_MINI_BAR_HEIGHT_VP)
      // 与首页底栏同一屏幕位置：整块宿主向下让出底部避让那一份（barBottomMargin 已归零）
      // ★ 键盘避让（用户 2026-10-12「二级页面播放条加上键盘避让」）：键盘弹出时在这份偏移上
      //   再减掉 `floatingMiniBarKeyboardLiftVp()`（= 键盘高度 + 8 − 常态既有间隙）⇒ 整条宿主
      //   连同 HDS 胶囊一起上抬到键盘上沿之上；键盘收起后 lift 恒为 0 ⇒ 这一行**逐字等于**
      //   改动前的 `homeTabBarBottomMarginVp()`（回归红线，见那个函数的注释）。
      .offset({ y: this.floatingMiniBarHostOffsetYVp() })
      // 不要裁：HDS 的材质背板/折射范围比内容盒大，裁了会缺一圈。
      .clip(false)
      .onAppear((): void => {
        Logger.info('RzdSecondaryMiniMaterial',
          `mode=hds-systemMaterialEffect officialRegion=yes host=single-tab-hdstabs ` +
            `tabContent=nonEmpty height=${FLOATING_MINI_BAR_HEIGHT_VP} ` +
            `ambient=${this.ambientLevelIndex()} singleVisibleBar=true`);
      })
      .onAreaChange((_oldArea: Area, area: Area): void => {
        Logger.info('RzdSecondaryMiniMaterial',
          `host width=${area.width} height=${area.height} ambient=${this.ambientLevelIndex()} ` +
            `keyboardVp=${this.keyboardBottomVp()} lift=${this.floatingMiniBarKeyboardLiftVp()} ` +
            `offsetY=${this.floatingMiniBarHostOffsetYVp()}`);
      })
      // ⚠️ **不要**在这里再写一个 `.margin({ bottom: ... })`：离底距离已经由
      //    `barFloatingStyle.barBottomMargin` 给了（与首页那条官方底栏同一口径）。
      //    两个一起写 = 离底距离翻倍，真机上看着就是"播放条浮得太高"（用户 2026-10-11 让看的那条）。
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignContent(Alignment.Bottom)
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(20)
    // Hidden preserves anchors/layout and hides the floating bar with its controls immediately.
    .visibility(this.expandState.sourceBarHidden ? Visibility.Hidden : Visibility.Visible)
  }

  /**
   * 官方浮动栏里**唯一可见的内容**（页签栏 CustomBuilder）。
   *
   * 尺寸与 {@link floatingMiniBar} 的宿主盒严格一致：宿主是 56vp 高，这里再写死一次，
   * 免得 HDS 的排布变化（两排/单排）把封面从 44 缩成 30。
   *
   * ★ 2026-10-15（"播放条更粗"那条）：`HomeMiniBarPlayer` 自己的高度已经涨到 56vp
   *   （封面 40 + 上下各 8 —— 见 `HomeMiniBarAlbumCover.coverSideLengthVp()` 与
   *   `HomeMiniBarPlayer.sidePadVp()` 的注释），所以这一档（封面 44）在本 Builder 里
   *   算出来的高度是 44 + 8×2 = **60vp**，比宿主槽高 4vp —— 交给 HDS 居中即可
   *   （多出来的 4vp 是设计上明确让步的余量，不要再加固定 height 去夹它，
   *    2026-10-12 那次"强行定 56vp ⇒ 整排元素低 6~8vp"的教训就在下面那条注释里）。
   * 上拉/点击打开播放页的手势在 `HomeMiniBarPlayer` 内部，这里不要重复挂。
   */
  @Builder
  private floatingMiniBarContent() {
    HomeMiniBarPlayer({
      showPreviousTrack: false,
      followAppMiniBarExpanded: false
    })
      // ★★ 用户 2026-10-11 定论：「错位的是播放条上的**元素**而不是播放条本身」。
      //   胶囊宽度由 `barFloatingStyle.barWidth` 给出（= 窗口宽 − 两侧留白 side），HDS 把它**居中**画；
      //   而这里原来写 `width('100%')`（= 宿主盒全宽）⇒ 内容比胶囊宽 2×side，
      //   封面贴着胶囊左缘、右侧按钮顶到胶囊右缘 ⇒ 看着就是"元素错位"。
      //   现在把内容宽度也定成胶囊宽度（同一函数、同一口径），HDS 居中后两者**完全重合**。
      // ★★ 2026-10-12 方案 A 实验：内容宽 = 胶囊宽（与 barFloatingStyle.barWidth 同一函数同口径）
      //   诊断依据（另一模型交叉读码）：内容盒原本 = 宿主盒 = 窗口宽，比胶囊宽 2×side 且左对齐，
      //   右侧按钮簇被推到胶囊右缘之外 ⇒ 「元素跑到右下角」。② 若这版仍然更糟，一句话我立刻回退。
      .width(this.floatingMiniBarWidthVp())
      // ★★ 用户 2026-10-11：「二级页面播放器依旧错位…它是跑到右下角了」——
      //   结论：**不要改内容的宽高**（一改就与 HDS 的胶囊定位打架，元素整体右下偏），
      // ★★ GLM5.3（provider=zai）诊断 2026-10-12：HDS 浮动胶囊给 tabBar 的**内容槽只有胶囊那么高（≈40vp）**，
      //   而这里把内容强行定成 56vp（封面 44 + 上下 padding 6+6）⇒ 内容比槽高 ~16vp，
      //   于是整排元素相对胶囊中心**低约 6~8vp**（真机量到 6vp，与截图一致）。
      //   ⇒ 不再强制高度，交给 HDS 按真实槽位自量并居中；宽度仍按胶囊宽（方案 A，已见效）。
  }

  // ⚠️ 这里原来把"自己算栏宽"的两个辅助函数删掉过（2026-10-11 上午），理由是"栏宽交给 HDS"；
  //    真机证明**不行**：HDS 默认宽度只有一小坨，播放器内容整个溢出胶囊外（用户截图"一坨"）
  //    ⇒ 现在按官方 `barWidth` 三档显式给回来（见 `floatingMiniBar()`）。

  /** 悬浮迷你条的左右间距（vp）：只在小屏给一点边距，宽屏居中留白。 */
  private floatingMiniBarSideMarginVp(): number {
    return new BreakpointType(12, 16, 96, 160, 9).getWidthValueWithHeightSM(
      this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint);
  }

  /**
   * 悬浮迷你条宽度（vp）：写进 `barFloatingStyle.barWidth` 的三档。
   *
   * 手机：窗口宽 − 两侧边距（12 / 16）；宽屏：夹在 {@link FLOATING_MINI_BAR_MAX_WIDTH_VP} 内居中。
   * 量不到窗口宽时给 336 兜底（旧胶囊同口径）。
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
    //    起手那一帧播放页**几乎看不见**（它此刻只占"迷你条那么大的裁剪窗口"，
    //    而窗口里画的又是刚起步的缩放内容 —— ★ 不是"整页淡入"：
    //    `morphPageOpacity()` 那个函数**目前没有消费者**，见它自己的注释），
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
    // ★ 走 `getNavigationBarBottomVpFromWindowUtil()`：它「缓存 → 现向窗口量 → 最后一次好值 →
    //   启动快照」逐级兜底。老代码只读缓存 + 启动快照，两者都为 0 时（避让区一次都没上报成功）
    //   边距会退化成 12，胶囊贴着屏幕底、压在系统手势条上 —— 用户看到的「底部播放器错位」。
    const systemInset: number = getNavigationBarBottomVpFromWindowUtil();
    return Math.max(12, systemInset + 8);
  }

  /**
   * 软键盘高度（vp）：没有键盘时 0。
   *
   * 唯一监听点在 `common/musicbasic` 的 `WindowUtil`（`on('avoidAreaChange')` 的
   * `TYPE_KEYBOARD` 分支写 `WindowInfo.avoidKeyboard`）；本函数只是只读门面，
   * 读的是 `@Trace` 字段 ⇒ 键盘弹出/收起会自动驱动壳层重新布局。
   */
  private keyboardBottomVp(): number {
    return getKeyboardBottomVpFromWindowUtil();
  }

  /**
   * 键盘弹出时，二级页面悬浮迷你条**再往上抬**的距离（vp）；无键盘时**恒为 0**。
   *
   * 只作用于二级页面那条悬浮条（{@link floatingMiniBar}）：首页那条迷你条在 HDS 浮动底栏里、
   * 由官方栏体负责让位，**不要**把本值喂给它。
   *
   * 算式与两个常量怎么调，见 {@link FLOATING_MINI_BAR_KEYBOARD_GAP_VP} 头上那段。
   * @returns 上抬距离（vp）；无键盘时为 0（此时调用方算式逐字等于改动前的值）。
   */
  private floatingMiniBarKeyboardLiftVp(): number {
    const keyboardVp: number = this.keyboardBottomVp();
    if (keyboardVp <= 0) {
      return 0;
    }
    const existingGapVp: number =
      FLOATING_MINI_BAR_CAPSULE_GAP_FACTOR * (this.homeTabBarBottomMarginVp() / 2);
    const lift: number = keyboardVp + FLOATING_MINI_BAR_KEYBOARD_GAP_VP - existingGapVp;
    return lift > 0 ? lift : 0;
  }

  /**
   * 二级页面悬浮迷你条**宿主**的纵向偏移（vp）。
   *
   * ⚠️ 无键盘时必须**逐字等于** `homeTabBarBottomMarginVp()` —— 这是回归红线：
   *    键盘避让只允许在"真的弹了键盘"时改变这条栏的位置。
   * @returns 宿主 offset.y（vp）。
   */
  private floatingMiniBarHostOffsetYVp(): number {
    return this.homeTabBarBottomMarginVp() - this.floatingMiniBarKeyboardLiftVp();
  }

  /**
   * 底部页签：**只剩两个** —— 推荐 / 我的。
   *
   * 为什么是这两个（用户 2026-10-11 明确要求"底栏只剩两个 Tab"，另一个由我们自己判断）：
   *   - 「推荐」是内容主面（首页推荐流），也是全场所有"去首页"动作的落点，删掉它应用就没了入口；
   *   - 「我的」是参考工程 lxmusic-harmony 的做法：它自己也**从四个页签（推荐/歌单/我的/设置）
   *     收成了三个（推荐/听书/我的）**，理由逐字同构 —— 歌单与设置的**内容都搬进了「我的」页**
   *     （快捷入口 + 歌单卡 + 设置卡），再留着那两个页签就是"同一件事两个入口"。
   *     我们没有「听书」，所以正好是**两个**。
   *
   * 被删掉的两个页签，能力都有新入口（一条都没丢）：
   *   - 「设置」→「我的」页那张**入口卡**的「设置」行 → `SettingPage` 二级页
   *     （**就是我们原来那个大设置页本体**：搜索框 + 六组设置项 + 平台账号/平台音乐/下载管理；
   *      顶上那张「登录音乐」卡已搬到「我的」页顶部，见 `LoginMusicCard.ets`；
   *      点进去的详情仍是同一个 `SettingsDetailPage`）；
   *   - 「歌单」→「我的」页那张**歌单卡**：卡内直接列歌单（点进详情 / 长按重命名·删除）、
   *     动作区「新建歌单」（就地弹层）、「歌单导入」与卡头「全部」→ `MinePlaylistPage`
   *     二级页（薄壳，渲染的仍是 `PlaylistsPage` 整页：排序 / 导出 / 改封面 / 网络导入都在）。
   * ⚠️ 所有二级页都推**壳层共享栈** `pageIndexInfos`（`MinePage` 自带的那个内层 Navigation
   *    已在 2026-10-11 第十二轮删除，理由见 `MinePage` 文件头）。
   */
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

    // ★ 用户 2026-10-15：「Tab 的推荐和回响中间加个**现在就听**，上下滑动切换歌曲。」
    //   一屏一首歌、竖向 Swiper 换歌；未登录走当前平台榜单、登录走该平台每日推荐
    //   （两条通道都在 `NowPlayingFeedPage` 里，见该文件头）。
    //   图标 `sys.symbol.music_note_circle_fill` 与另外三枚同为 fill 系（已在本机
    //   `sysResource.js` 的 symbol 表里核实存在）。
    TabContent() {
      Column() {
        NowPlayingFeedPage({
          // 底部让位与上面「推荐」页同一判据（HDS 浮动胶囊底栏 6.1.1(24)/60100 起才存在）：
          // 56 = 胶囊高，+16 = `barBottomMargin` 的常规值。它加在**滑动卡片自己**身上，
          // 这样每一屏都能正好躲开底栏（见 `NowPlayingFeedPage.FEED_DEFAULT_BOTTOM_RESERVE_VP`）。
          bottomReserveVp: deviceInfo.distributionOSApiVersion >= 60100 ? 56 + 16 : 56,
          scrollTopCommand: this.tabScrollTopCommands[1],
          // ★★ 2026-10-15 用户：「我启动应用过一会就会自动开始播放，**自动开始播放的逻辑应该是我打开
          //    那个现在就听的页面的时候**」。根因是 `HdsTabs` 的 `TabContent` 子页面**启动时就挂载**
          //    ⇒ 页面里的 `applyRows()` 一到数据就起播了（用户还在首页）。
          //    ⇒ 下发**本页在底栏里的下标**（是个常量），页面自己连 `TabSwitchState` 判"现在在不在屏幕上"
          //      （`@Monitor('tabState.tabIndex')`），只有在前台才起播。
          //    ⚠️ **不要改成"壳层传 `isActive: this.tabState.tabIndex === …`"**：ArkUI V2 是"读才订阅"，
          //      切页签时重绘的是读了 `tabIndex` 的那几个 `TabBarItem` 节点，本页这个 `@Param`
          //      **不保证被重新求值** ⇒ `isActive` 会一直停在初值（静默失效）。
          //    ⚠️ 参数名**不能叫 `tabIndex`**：`CustomComponent` 自己有一个同名方法
          //      （通用属性 `tabIndex(index)`），自定义组件里同名会 **编译失败**（本机实测：
          //      `Property 'tabIndex' … is not assignable to the same property in base type 'CustomComponent'`）。
          barTabIndex: NOW_PLAYING_TAB_INDEX
        })
          .layoutWeight(1)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(1, $r('app.string.tab_now_playing'), $r('sys.symbol.music_round_triangle_fill')))

    // ★ 用户 2026-10-12：底栏中间加一页「回响」（月度听歌报告）
    TabContent() {
      Column() {
        EchoReviewPage({ scrollTopCommand: this.tabScrollTopCommands[2] })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(2, $r('app.string.tab_echo'), $r('sys.symbol.waveform')))

    TabContent() {
      Column() {
        MinePage({ scrollTopCommand: this.tabScrollTopCommands[3] })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    }
    .tabBar(this.TabBarItem(3, $r('app.string.tab_cafe_listen'), $r('sys.symbol.person_crop_circle_fill_1')))
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
            // ★ 这条是**官方真实光感**：HdsTabs 的浮动底栏（barOverlap + !vertical +
            //   barPosition(End) 三条件同时满足）+ `systemMaterialEffect`。
            //   档位与标题栏共用 ambientTitleMaterial()，不要再在本处内联一套三目。
            systemMaterialEffect: this.ambientTitleMaterial(),
            // 智感握姿：跟随握持手调整浮动条左右偏置
            adaptToHandedness: true,
            miniBar: {
              miniBarBuilder: (): void => {
                this.miniBar();
              },
              // ★ 双层底栏的关键：`barLayoutMode = VERTICAL` 才把迷你条与页签排成上下两排。
              //   该字段是 @since 6.1.1(24)，所以工程 targetSdkVersion 必须 ≥ 24
              //   （本项目已由 6.1.0(23) 提到 6.1.1(24)，compatibleSdkVersion 保持 23，
              //     设备覆盖不变）。低配发行版上传 undefined。
              //   ⚠️「现在就听」页由 `barLayoutModeForHds()` 强制 HORIZONTAL（见它和
              //     `NOW_PLAYING_TAB_INDEX` 的注释）：那一页不许有迷你条那一排。
              barLayoutMode: this.barLayoutModeForHds(),
              // 受控属性：折叠态 = 窄胶囊，点击后由 onBarStyleChange 透出再回灌
              // ⚠️ 单排（HORIZONTAL）配 `EXPAND` 是**已知的错误组合**（底栏会变成
              //   「长条 Tab + 圆形播放器」，见 `onMiniBarStyleChangeFull` 的注释）⇒
              //   在「现在就听」页一并把样式压回 `COLLAPSE`。
              //
              // ★★★ 2026-10-16（**方案 A：迷你条改自绘背板**，修用户实测
              //   「关闭播放器只有内容会弹，**播放条背景不弹**」）：
              //   `enableMiniBarBackground` 是 HDS 给**迷你条那一块**的背板开关
              //   （页签胶囊那块背板是**另一块**，不受它影响）。
              //   置 `false` ⇒ HDS 不再给迷你条画背板 ⇒ 背板改由
              //   `HomeMiniBarPlayer.MiniBarBackplate()` 自绘，于是它与内容在**同一棵子树**里，
              //   能跟着 `morphSquashY` 一起压/一起弹。
              //   ⚠️ 与 `HomeMiniBarPlayer` 里那一层**必须成对**：只关不画 ⇒ 迷你条底下空一块。
              enableMiniBarBackground: false,
              miniBarStyle: this.miniBarStyleForHds(),
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
              // ★ 迷你条显隐诊断（`hdc shell hilog | grep RzdMiniBarHide`）：
              //   切到「现在就听」应打出 `hidden=true barLayout=HORIZONTAL style=COLLAPSE`，
              //   切回来应打出 `hidden=false`。只能看日志，无设备验证。
              Logger.info(RzdShellLogTag,
                `RzdMiniBarHide tab=${index} hidden=${index === NOW_PLAYING_TAB_INDEX} ` +
                  `barLayout=${this.barLayoutModeForHds()} style=${this.miniBarStyleForHds()} ` +
                  `navDepth=${this.navDepth}`);
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

      // ★★ 第三份拷贝 = **续飞封面**（2026-10-15 从播放页搬来的那一棒）。
      //    它有自己的时间线（`morphOverlayP`，560ms + 快出慢收），与另两份同层（zIndex 110）。
      //    顶点/终点量测与另外两份同源（`reportMini` / `reportBig`），所以三者是一起走的。
      //    渲染门写在 builder 里（`morphOverlayBridging()`）。
      if (this.expandState.morphOverlayBridging()) {
        this.MorphCoverClone()
      }

      // ★★★ 2026-10-17（照搬无界 `MainPage` 的 `If (shrink.visible && shrinkPixmap)`）：
      //   「非手势关闭」那一棒：一张满窗快照缩到迷你条胶囊 + 淡出。
      //   放在**最上面**（zIndex 130）：它就是"正在消失的那一屏播放页"。
      this.ShrinkOverlayHost()

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
          // ★ 速度项也要传进去（清单 §一 1.2「进度 OR 速度」；判据在
          //   `PlayerExpandState.pullOpenShouldCommit()` 里，方向由位移判、大小取 abs）
          this.onPullOpenEnd(event.offsetY, event.velocityY);
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
      this.expandState.reportWindow(this.viewportWidthVp, this.viewportHeightVp,
        this.windowInfo.statusBarTopVp, this.windowInfo.navigationBarBottomVp);
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