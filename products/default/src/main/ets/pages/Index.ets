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
  BarLayoutModes,
  BreakpointType,
  getWindowInfoState,
  HomeSourceState,
  ImmersiveType,
  MusicAppState,
  MusicDbApi,
  MusicStoreService,
  Logger,
  PlaybackIntentState,
  PlayerExpandState,
  SdkApiUtil,
  SdkConstants,
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
 * 二级页面这条永远是折叠形态（`followAppMiniBarExpanded` 在 `miniBarExpanded` 为真时不显示
 * 这条悬浮条），所以高度是常量，不会随形态变化。
 */
const FLOATING_MINI_BAR_HEIGHT_VP: number = 42;

/** 二级页面悬浮迷你条在宽屏下的最大宽度（vp）：胶囊不该铺满整个平板/桌面窗口。 */
const FLOATING_MINI_BAR_MAX_WIDTH_VP: number = 560;

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
   * 窗口宽度（vp），用于给悬浮迷你条算一个**稳定的显式宽度**。
   *
   * 悬浮条是叠在页面上的独立节点，宽度必须自己算准：靠 `width('100%')` + 外层 padding
   * 在部分形态下会算错（hugging 到右边 / 撑成整条大长方形），而百分比宽度又会在
   * 窗口尺寸变化时跳变。这里只在首次和尺寸真正变化时更新。
   */
  @Local viewportWidthVp: number = 0;

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
  }

  /** Dispatches playback shell intent when {@link PlaybackIntentState.requestVersion} changes. */
  @Monitor('intentState.requestVersion')
  onPlaybackIntentChanged() {
    dispatchShellPlaybackIntent(this.appState, this.intentState, () => {
      // 直接挂起播放页即可：播放页展开动画已整体移除（原因见
      // features/player/.../PlaybackPage.ets 末尾的注释块），不要在这里再做补间。
      this.appState.isShowPlay = true;
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
   * 关键点：**只有 `COLLAPSE` 分支写状态**。收到折叠就把排布模式拉回上下两排、
   * 同步 `miniBarExpanded`，整段包在 `animateTo(300ms, Smooth)` 里；
   * `EXPAND` 分支什么都不写（展开由 HDS 自己负责）。
   * `miniBarStyle` 因此是受控属性 —— 点击收起/展开由 HDS 透出事件、我们只回灌。
   */
  private onMiniBarStyleChangeFull(miniBarStyle: HdsBarStyle): void {
    if (miniBarStyle === HdsBarStyle.COLLAPSE) {
      this.getUIContext().animateTo({ duration: 300, curve: Curve.Smooth }, (): void => {
        this.appState.hdsBarLayoutMode = BarLayoutModes.VERTICAL;
        this.appState.miniBarExpanded = false;
      });
      return;
    }
    this.appState.miniBarExpanded = true;
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
   * `HomeMiniBarPlayer({ showPreviousTrack: false, followAppMiniBarExpanded: true })`，
   * 沉浸光感沿用首页底栏的环境光映射（见 {@link miniBarBlurStyle}）。
   *
   * 三个尺寸都必须**显式**给，不能靠百分比撑：
   *   - 高度：迷你条封面在「上下两排 / 浮窗 / 普通」三种形态下分别是 30 / 32 / 56vp
   *     （见 `HomeMiniBarAlbumCover.coverSideLengthVp()`），间距 6vp，且不会随展开态变化
   *     （二级页面永远是折叠形态），所以高度固定 56 + 1 边框。
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
          followAppMiniBarExpanded: true,
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
      // 与首页 HDS 浮动底栏同一套沉浸光感（环境光等级 → 毛玻璃强度）
      .backgroundBlurStyle(this.miniBarBlurStyle())
      .margin({ bottom: this.floatingMiniBarBottomMarginVp() })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignContent(Alignment.Bottom)
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(20)
  }

  /**
   * 迷你条毛玻璃强度：与首页底栏的 `systemMaterialEffect` 同一个环境光映射。
   * @returns 毛玻璃样式。
   */
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
    if (this.appState.isShowPlay || this.appState.miniBarExpanded) {
      return false;
    }
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
              miniBarStyle: this.appState.miniBarExpanded ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE,
              onBarStyleChange: (miniBarStyle: HdsBarStyle): void => {
                this.onMiniBarStyleChangeFull(miniBarStyle);
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
      .backgroundColor($r('app.color.home_page_background'))
      .hideTitleBar(true)
      .hideToolBar(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      // 播放页：照抄参考工程（MusicHome）的挂载方式 ——
      //   `bindContentCover(..., ModalTransition.NONE)`，**不传 options**。
      // 关键就是 `ModalTransition.NONE`：
      //   - `DEFAULT` 会做"从底部推上来"的位移过渡，结束后容器的安全区处理会留下
      //     底部一条空白（之前反复调 expandSafeArea / enableSafeArea 都没用，
      //     因为问题出在过渡本身）；
      //   - 参考工程用 NONE，播放页全屏铺满、底部不留白。
      // 播放页内部的底部留白由 `PlaybackPage.buildControlStack` 自己按
      // `navigationBarBottomVp` 加 padding，不需要外部再管安全区。
      //
      // ★ `onWillDismiss`：系统返回（返回手势/返回键）要求关闭这个模态时，
      //   **不要**直接放行 —— 先让播放页播收起动画（它收到 collapseVersion 后会自己
      //   把 isShowPlay 置 false）。不拦这一下，系统返回就是"啪"地消失、没有任何动画。
      .bindContentCover(this.appState.isShowPlay, PlaybackPageCoverContent(), {
        modalTransition: ModalTransition.NONE,
        onWillDismiss: (_action: DismissContentCoverAction): void => {
          this.expandState.requestCollapse();
          // ⚠️ 兜底：这里**没有**调 `_action.dismiss()`（调了就立刻消失、没动画），
          //    关闭交给播放页。万一播放页那边没接住（监听没到、动画卡住），
          //    最迟 700ms 后强制关闭 —— 绝不能出现"系统返回按了没反应"。
          //    （正常路径 380 + 20 = 400ms 就关了，兜底不会插进来。）
          setTimeout((): void => {
            if (this.appState.isShowPlay) {
              this.appState.isShowPlay = false;
            }
          }, 700);
        }
      })
      .onNavBarStateChange((isVisible: boolean): void => {
        // 每次导航栏可见性变化都刷新栈深度（推入/弹出二级页面都会触发）
        this.syncNavDepth();
      })

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
    // 窗口尺寸变化（折叠展开 / PC 浮窗拖拽）时刷新悬浮条算宽用的视口宽度
    .onAreaChange((_oldArea: Area, _newArea: Area): void => {
      this.syncViewportWidthVp();
    })
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
      const depth: number = this.pageIndexInfos.size();
      if (depth === this.navDepth) {
        return;
      }
      // 进二级页面前把迷你条收回折叠态：展开态下壳层那条是不显示的（见
      // shouldShowFloatingMiniBar），不收回来二级页面就会一条播放器都看不到。
      if (depth > 0 && this.appState.miniBarExpanded) {
        this.appState.miniBarExpanded = false;
      }
      this.navDepth = depth;
    }, 0);
  }
}