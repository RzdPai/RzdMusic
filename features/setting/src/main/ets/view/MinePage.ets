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

/*
 * 「我的」页。
 *
 * ★ 版式**照搬**参考工程 `lxmusic-harmony` 的 `entry/src/main/ets/views/MineView.ets`
 *   （是"照搬结构 / 观感"，不是"参考风格"）。从上到下与它的对应关系：
 *
 *   | 本页 | 参考工程 |
 *   | --- | --- |
 *   | ① `LoginMusicCard()` 账号卡 | 参考里没有 —— 用户要求把**我们原本大设置页顶上那张**「登录音乐」卡放这里（见 `LoginMusicCard.ets`） |
 *   | ② `QuickCard()`   快捷入口那一排（图标方块 + 名字 + 条数） | `quickCard()`（5 格：本地音乐 / 最近播放 / 收藏 / 下载管理 / 云端音乐） |
 *   | ③ `PlaylistCard()` 歌单卡（卡头 + 动作区 + 歌单行 + 长按菜单） | `playlistCard()` |
 *   | ④ `LinksCard()`   入口卡（设置 / 帮助和反馈 + **我们的加法**：平台音乐） | `linksCard()` |
 *   | ⑤ `MineTopFade`   顶栏自绘渐隐 | `TopFade`（`ui/Widgets.ets`，件在同目录 `MineWidgets.ets`） |
 *
 *   尺寸/字号常量照抄它的 `ui/Theme.ets`（`R_CARD=16` / `F_SECTION=17` / `F_ITEM=16.5` /
 *   `F_SUB=12.5` / 歌单行 70 / 入口行 58 / 卡头 54 / 快捷图标 44·圆角 15 / 动作区 64·圆角 16 /
 *   行内封面 46 / 淡底 12%）。
 *
 * ★★ 取色**不照搬**（用户 2026-10-11 明确：「我的页取色不能照搬，我们的软件有自定义主题颜色」）：
 *   - 卡片底 `app.color.card_background`、页面底 `app.color.background_secondary`、
 *     分割线 `app.color.comp_divider`、浅底（动作区）`app.color.capsule_background`、
 *     文字/图标 `sys.color.font_* / icon_tertiary`、按钮与强调元素 `themeState.color`
 *     —— 一律 token，**代码里没有一个写死的十六进制**；
 *   - 参考工程那套 `C_BG / C_CARD / C_RED / C_RED_TINT / C_FILL_SOFT / C_PRESSED …`
 *     （洛雪红 + 写死白卡）**一个都没引用**
 *     （自检：`node tools/theme-color-check.mjs <本文件>` → `ref-palette=0`）。
 *
 *   三件事怎么保证的：
 *   1. **深色模式**：所有颜色都是资源 token（`app.color.*` 在 `resources/base` 与
 *      `resources/dark` 各一份同名同义值；`sys.color.*` 由系统按深浅色给），本页**没有字面量颜色**，
 *      所以切深浅色时这一页跟着系统换，不需要额外代码。
 *   2. **宽屏断点**：`@Env(SystemProperties.BREAK_POINT)` 提供断点；左右留白按断点取
 *      （`BreakpointType(16,24,32,32)`），宽屏（WIDTH_LG / WIDTH_XL）把**歌单卡与入口卡并排**
 *      （照搬参考那段排法：歌单卡 `layoutWeight(2)`、入口卡 `layoutWeight(1)`、顶对齐）。
 *   3. **用户改主题色后立刻跟着变**：强调色只从 `this.themeState.color` 取，而 `ThemeState`
 *      是 `@ObservedV2 + @Trace color`，本页 `@Local themeState` 通过 AppStorageV2 连的是**同一个**
 *      实例 ⇒ 在设置页改一次色，这一页的快捷入口图标底 / 图形、卡头「全部」、动作区按钮
 *      会**同一帧**重绘，不需要任何手动刷新。
 *
 * ★★ 二级页**一律推壳层的共享栈**（`@Consumer('pageIndexInfos')`），本页**不再自带 Navigation**。
 *   原来那一版在本页里套了一个 `Navigation(this.localStack)`，把「设置 / 全部歌单」画在**本页之内**，
 *   那是用户报的两个 bug 的根因，**别再改回去**：
 *     ① 内层 Navigation 是**页签内容的一部分** ⇒ 壳层那条 HDS 底栏（两个页签 + 迷你条）就画在它上面，
 *        于是二级页的底部和一级页**一模一样**（用户：「二级页面底部还是完整的，和一级页面没有任何区别」）；
 *     ② 那两次 push 不进 `pageIndexInfos` ⇒ 壳层 `navDepth` 恒为 0 ⇒ 悬浮播放条不显示，
 *        且系统返回手势时壳层栈是空的，框架把返回交给页面级 `onBackPress()`（播放页没开时返回 false）
 *        ⇒ **按了没反应 / 直接把 App 退掉**。
 *   推到共享栈之后：二级页整屏盖住底栏（底部只剩壳层那条官方浮动播放条，由壳层负责，
 *   本页**不自己加播放条**），系统返回走壳层栈正常弹回。
 *
 * ★ 与我们原有功能的衔接（**一个都没丢**）：
 *   - 「歌单」页签被删掉后，它的能力在第 ③ 张卡里：卡头右端「全部」进整页
 *     （`RouterUrlConstants.MINE_PLAYLIST`），卡内直接列歌单、点进详情、长按重命名/删除，
 *     「新建歌单」就地弹层建，「歌单导入」也进整页（整页有来源 + 链接表单，本卡不重写一份）；
 *   - 「设置」页签被删掉后，入口在第 ④ 张卡的「设置」行（`RouterUrlConstants.SETTING_PAGE`
 *     = **我们原本那个大设置页本体**，不是副本、不是二级入口列表）；
 *   - 记录（播放历史 / 收藏）不再在页内分段，各是一个子页面：`RouterUrlConstants.RECORD_LIST`
 *     一页两模式（见 `RecordListPage.ets`），行版式与动作**整套搬过去**，本页不再保留那份代码；
 *   - 下载管理 → `RouterUrlConstants.SETTINGS_DETAIL` + `index = 10`（设置详情页的下载管理那一档）；
 *   - 本地音乐 → `localmusic` 自己的路由页 `LocalMusicPage`；
 *   - 平台音乐 → `RouterUrlConstants.SETTINGS_DETAIL` + `index = 3`（设置详情页里渲染的就是
 *     `PlatformMusicPage` 本体）。**原第 5 格的「云端音乐」已按用户要求撤掉**
 *     （那套 WebDAV 曲库是参考工程的逻辑，用户说"不要用他那套"）；页面代码仍在
 *     `features/sync/.../CloudMusicPage.ets`、路由也还登记着，只是**本页不再有入口**。
 *
 * ⚠️ 歌单行用 `LazyForEach` + 稳定 key（数据源 `MinePlaylistSource`，挂在歌单卡的 Column 里）。
 *    **不要**换回 `Repeat`；也**不要**把无上限的列表搬回本页 —— 记录列表那种"听一年几千条"的
 *    必须在自己的滚动容器里懒加载（见 `RecordListPage` 的 `List` + `LazyForEach`）。
 */

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { guardPlayerBack } from 'musicbasic';
import {
  AmbientState, AppRuntimeStorage, AppStorageKeys, BarScrollHelper, BreakpointType, FavoriteEntry,
  LocalCoverImage, MusicAppState, MusicStoreService, PlaylistDto, RouterUrlConstants, ThemeState,
  TitleBarConstants, ToplistRouteParam, buildTitleMaterial, getAppRuntime, getStatusBarTopVpFromWindowUtil
} from 'musicbasic';
import {
  BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions,
  ScrollEffectType, TitleSize
} from '@kit.UIDesignKit';
import { LocalMusicImportState, localMusic, localMusicImportState } from 'localmusic';
// 平台账号数（那一格的条数）/ 下载完成数（那一格的条数）/ 收藏歌单行上的平台名（sourceName）
import { AccountService, DownloadService, DownloadStatus, DownloadTask, sourceName } from 'player';
// 「网络导入」表单：与「全部歌单」页**同一个组件**（用户要求这一格直接进网络导入，不要再提示/跳整页）
import { NetworkImportSheet } from 'playlist';
import { LoginMusicCard } from './LoginMusicCard';
import { MineTopFade } from './MineWidgets';
import { RECORD_MODE_FAVORITES, RECORD_MODE_HISTORY, RecordListRouteParam } from './RecordListPage';
import { SettingsDetailRouteParam } from './SettingsDetailPage';

// ─────────────── 照抄参考工程 `ui/Theme.ets` 的尺寸常量（数值照搬，颜色换成我们的 token） ───────────────

/** 卡片圆角（参考 `R_CARD`）。 */
const R_CARD: number = 16;
/** 列表封面圆角（参考 `R_COVER` 一档；它的歌单行实际用的是 14）。 */
const R_COVER: number = 14;
/** 分组 / 卡头标题字号（参考 `F_SECTION`）。 */
const F_SECTION: number = 17;
/** 列表主标题字号（参考 `F_ITEM`）。 */
const F_ITEM: number = 16.5;
/** 列表副标题与计数（参考 `F_SUB`）。 */
const F_SUB: number = 12.5;
/** 卡片头部高度（参考 `playlistCard()` 的头部 54）。 */
const CARD_HEADER_HEIGHT: number = 54;
/** 歌单行高（参考 `playlistCard()` 的行 70）。 */
const LIST_ROW_HEIGHT: number = 70;
/** 入口卡一行的高度（参考 `linksCard()` 的 58）。 */
const LINK_ROW_HEIGHT: number = 58;
/** 快捷入口图标方块边长与圆角（参考 `quickCard()` 的 44 / 15）。 */
const QUICK_ICON_BOX: number = 44;
const QUICK_ICON_RADIUS: number = 15;
/** 动作区高度与圆角（参考 `playlistCard()` 里「新建歌单 / 歌单导入」那块 64 / 16）。 */
const CARD_ACTION_HEIGHT: number = 64;
const CARD_ACTION_RADIUS: number = 16;
/** 行内封面的边长（参考歌单行的 46）。 */
const ROW_COVER: number = 46;
/** 强调色淡底的不透明度（参考 `C_RED_TINT` = 强调色 12%）。 */
const ACCENT_TINT_OPACITY: number = 0.12;
/** 歌单卡里最多内联几张歌单（超出走卡头的「全部」/ 末尾那行「查看全部」）。 */
const PLAYLIST_PREVIEW_MAX: number = 4;

/** 设置详情页里「下载管理」那一档的下标（见 `SettingsDetailPage.detailTitle()` 的 case 10）。 */
const DOWNLOAD_SHEET_INDEX: number = 10;
/** 设置详情页里「关于」那一档的下标（入口卡「帮助和反馈」直达）。 */
const ABOUT_SHEET_INDEX: number = 9;
/** 设置详情页里「平台音乐」那一档的下标（入口卡那一行）。 */
const PLATFORM_MUSIC_SHEET_INDEX: number = 3;
/**
 * 本地音乐的路由名。
 *
 * `RouterUrlConstants` 里**没有**这条（本地音乐是独立 HAR，只在自己的 `router_map.json`
 * 里登记了 `LocalMusicPage`），所以这里按 `features/playlist` 的
 * `PlaylistsPage.LOCAL_MUSIC_ROUTE` 同一口径取字面量。
 */
const LOCAL_MUSIC_ROUTE: string = 'LocalMusicPage';

/** 日志域与标签（真机排查：`hdc shell hilog | findstr RzdMineRoute`）。 */
const DOMAIN: number = 0x0000;
const TAG: string = 'RzdMineRoute';

/** 快捷入口的一格。 */
class MineQuickEntry {
  symbol: Resource = $r('sys.symbol.folder');
  label: string = '';
  /** 'local' | 'history' | 'favorites' | 'downloads' | 'platform'（原 'cloud' 已撤）。 */
  action: string = 'local';
}

/** 底部入口卡的一行。 */
class MineLinkRow {
  symbol: Resource = $r('sys.symbol.gearshape_fill');
  label: string = '';
  /** 'settings' = 大设置页本体，'about' = 关于（设置详情页）。 */
  action: string = 'settings';
}

/**
 * 歌单卡的懒加载数据源（`LazyForEach` 用）。
 *
 * 数据本身仍由 `MusicStoreService` 持有（唯一真源），这个类只是视图适配器：
 * **任何变化都必须走 `applyItems()`**（`@Monitor('store.playlistVersion')` 里调）。
 */
class MinePlaylistSource implements IDataSource {
  private items: PlaylistDto[] = [];
  private listeners: DataChangeListener[] = [];

  public totalCount(): number {
    return this.items.length;
  }

  public getData(index: number): PlaylistDto {
    return this.items[index];
  }

  /**
   * 稳定 key：歌单 id + 曲目数 + 封面。
   *
   * 带上曲目数 / 封面是为了"同一个歌单里加了歌 / 换了封面"时 key 变化 → 那一行重建；
   * id 不变则**行不会错位**（删除中间一张时不会把别人的封面留在原位）。
   */
  public keyOf(index: number): string {
    const item: PlaylistDto = this.items[index];
    if (item === undefined) {
      return 'mine_pl_missing_' + index;
    }
    return 'mine_pl_' + item.id + '_' + item.songs.length + '_' + item.cover;
  }

  /** 整批替换内容并通知刷新（唯一入口）。 */
  public applyItems(next: PlaylistDto[]): void {
    this.items = next;
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }
}

/**
 * Mine tab: the "我的" page.
 *
 * 账号卡 → 快捷入口卡 → 歌单卡 → 入口卡（宽屏：歌单卡与入口卡并排）。
 * 二级页全部推**壳层共享栈**（设置页 / 全部歌单 / 最近播放 / 收藏 / 下载管理 / 本地音乐 /
 * 云端音乐 / 平台音乐 / 歌单详情），本页不再自带路由栈。
 */
@ComponentV2
export struct MinePage {
  /** 「回到顶部」指令：壳层点了当前页签时递增（底部页签设计规范）。 */
  @Param scrollTopCommand: number = 0;
  /** Window breakpoint for the HDS home-style responsive title. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /** 全局播控状态：滚动联动双层底栏需要写 miniBarExpanded / hdsBarLayoutMode。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /**
   * 壳层的共享路由栈（**二级页唯一的出口**）。
   *
   * ⚠️ 本页**不许**再自带 `Navigation`（理由见文件头那段）：自带栈会让二级页底部带上壳层底栏、
   *    并让系统返回失效。
   */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** 本地音乐的库状态（读它的 `version` 就能跟着"导入 / 删除 / 歌词匹配"刷新条数）。 */
  @Local localMusicState: LocalMusicImportState = localMusicImportState();
  /** 快捷入口卡上「本地音乐 / 最近播放 / 收藏」的条数。 */
  @Local historyCount: number = 0;
  @Local favoriteCount: number = 0;
  @Local localCount: number = 0;
  /** 「下载管理」那一格的条数 = **已下载完成**的任务数（一首一个任务）。 */
  @Local downloadedCount: number = 0;
  /** 「平台音乐」那一格的条数 = 已登录的平台账号数（单位「个」，见 `countOf`）。 */
  @Local platformAccountCount: number = 0;
  /** 「歌单导入」面板（`NetworkImportSheet`，与全部歌单页同一个组件）。 */
  @Local importSheetOpen: boolean = false;
  /** 歌单卡的数据（`store.playlistVersion` 变一次就读一次）。 */
  @Local playlists: PlaylistDto[] = [];
  /**
   * 歌单卡当前显示哪一段：`0` = 自建歌单，`1` = 收藏歌单（照搬参考 `playlistTab`）。
   */
  @Local playlistTab: number = 0;
  /** 收藏的在线歌单（`store.favoritePlaylistVersion` 变一次就读一次）。 */
  @Local collectedPlaylists: FavoriteEntry[] = [];
  /** 歌单行的懒加载数据源（`@Local` 保证 `LazyForEach` 拿到同一个实例）。 */
  @Local playlistSource: MinePlaylistSource = new MinePlaylistSource();
  /** 新建 / 重命名共用的小面板：`editingId` 为空表示新建。 */
  @Local editOpen: boolean = false;
  @Local editingId: string = '';
  @Local editName: string = '';
  /** Scroller bound to the HDS title bar so the scroll effect (gradient blur) can fire. */
  private pageScroller: Scroller = new Scroller();
  /** 下载队列监听句柄（`aboutToDisappear` 里要摘掉）。 */
  private downloadListener: (() => void) | undefined = undefined;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'mine page appear');
    this.refreshCounts();
    this.loadPlaylistData();
    // 下载 / 账号两个条数：进页各读一次，之后靠监听跟着变（见下）
    this.refreshDownloadCount();
    this.refreshPlatformCount();
    this.downloadListener = (): void => {
      this.refreshDownloadCount();
    };
    DownloadService.getInstance().addListener(this.downloadListener);
  }

  aboutToDisappear(): void {
    // 监听一定要摘（本页在页签里会反复进出）
    if (this.downloadListener !== undefined) {
      DownloadService.getInstance().removeListener(this.downloadListener);
      this.downloadListener = undefined;
    }
  }

  /** 下载队列变化（完成一首 / 清空已完成）时更新那一格的条数。 */
  private refreshDownloadCount(): void {
    const tasks: DownloadTask[] = DownloadService.getInstance().getTasksSnapshot();
    let done: number = 0;
    for (let i = 0; i < tasks.length; i++) {
      if (tasks[i].status === DownloadStatus.COMPLETED) {
        done++;
      }
    }
    this.downloadedCount = done;
  }

  /**
   * 「平台音乐」那一格：已登录的平台账号数。
   *
   * 为什么是账号数而不是曲目数：平台曲库的歌曲数要**联网拉歌单**才知道，
   * 为了一个角标在进页时发请求不划算 ⇒ 报"几个账号"（单位「个」）；没登录就是 0 个。
   *
   * ⚠️ `AccountService.listAccounts()` 里的 `getStore()` 在**没 init 过**时会直接抛
   *    「AccountService 未初始化」——本页进页顺序不保证推荐页已经 init 过，所以这里
   *    照 `RecommendViewModel.refreshGuestMode()` 的写法：先 `init(runtime.context)`，
   *    并整段 try/catch 兜住（读不到就当 0，绝不让它把本页的 `aboutToAppear` 带崩）。
   */
  private refreshPlatformCount(): void {
    try {
      const runtime: AppRuntimeStorage = getAppRuntime();
      AccountService.init(runtime.context);
      this.platformAccountCount = AccountService.listAccounts().length;
    } catch (err) {
      const message: string = err instanceof Error ? err.message : String(err);
      hilog.warn(DOMAIN, TAG, 'platform account count unavailable: %{public}s', message);
      this.platformAccountCount = 0;
    }
  }

  /** 壳层点了当前页签：滚回顶部（底部页签设计规范）。 */
  @Monitor('scrollTopCommand')
  onScrollTopCommand(): void {
    this.pageScroller.scrollEdge(Edge.Top);
  }

  // ─────────────────────────────── 数据 ───────────────────────────────

  /** 历史 / 收藏在别处被改动（播放器、歌曲菜单…）时更新快捷入口上的条数。 */
  @Monitor('store.historyVersion', 'store.favoriteVersion')
  refreshCounts(): void {
    this.historyCount = this.store.getHistory().length;
    this.favoriteCount = this.store.getFavorites().length;
  }

  /** 本地音乐导入 / 删除 / 歌词匹配后更新条数。 */
  @Monitor('localMusicState.version')
  refreshLocalCount(): void {
    // ★★ 用户 2026-10-11：「我的页本地音乐不论多少首都显示 0 首」——根因：`LocalMusic` 是单例，
    //   `count()` 读的是内存里的 songs，填内存的只有 `LocalMusicView.aboutToAppear` 那句 `localMusic.init(context)`。
    //   我的页从没 init 过 ⇒ 恒 0（本地音乐页自己 init 过所以显示 1 首）。照它补上（幂等 + try 兜住）。
    try {
      if (!localMusic.isReady()) {
        localMusic.init(this.getUIContext().getHostContext() as common.UIAbilityContext);
      }
    } catch (err) {
      const message: string = err instanceof Error ? err.message : String(err);
      hilog.warn(DOMAIN, TAG, 'localMusic init failed: %{public}s', message);
    }
    this.localCount = localMusic.count();
  }

  /** 歌单卡的数据（`playlistVersion` 是 `@Trace`，增删改都会走到这里）。 */
  @Monitor('store.playlistVersion')
  refreshPlaylists(): void {
    this.playlists = this.store.getPlaylists();
    this.publishPlaylists();
  }

  /** 把当前歌单灌进懒加载数据源（**数据变化后必须调它**）。 */
  private publishPlaylists(): void {
    this.playlistSource.applyItems(this.playlists.slice(0, PLAYLIST_PREVIEW_MAX));
  }

  /** 收藏的在线歌单（平台音乐页那颗收藏按钮写入，`favoritePlaylistVersion` 是 `@Trace`）。 */
  @Monitor('store.favoritePlaylistVersion')
  refreshCollectedPlaylists(): void {
    this.collectedPlaylists = this.store.getFavoritePlaylists();
    hilog.info(DOMAIN, TAG, 'collected playlists refreshed: count=%{public}d tab=%{public}d',
      this.collectedPlaylists.length, this.playlistTab);
  }

  /** 歌单卡首次进页时把两段数据都读齐（`@Monitor` 只在**变化**时触发）。 */
  private loadPlaylistData(): void {
    this.refreshPlaylists();
    this.refreshCollectedPlaylists();
  }

  /**
   * 快捷入口那一格的条数（**五格都要有数**，用户 2026-10-11 明确要求统一）。
   *
   *   · 本地音乐 / 最近播放 / 收藏 = 各自的曲目数（`MusicStoreService`）；
   *   · 下载管理 = **已下载完成的任务数**（`DownloadService` 的 `COMPLETED`；
   *     一个任务对应一首，排队/下载中/暂停/失败的不算 —— 这是"下载好了几首"的口径）；
   *   · 平台音乐 = **已登录的平台账号数**（`AccountService.listAccounts()`）。
   *     这一格**不报"几首"**：平台曲库的歌曲数要联网拉歌单才知道，本页不做那次请求，
   *     所以按"账号数"显示单位「个」，不编一个可能过期的曲目数。
   * @param action 快捷入口的 action
   * @returns 条数（≥0 才画）
   */
  private countOf(action: string): number {
    if (action === 'history') {
      return this.historyCount;
    }
    if (action === 'favorites') {
      return this.favoriteCount;
    }
    if (action === 'local') {
      return this.localCount;
    }
    if (action === 'downloads') {
      return this.downloadedCount;
    }
    if (action === 'platform') {
      return this.platformAccountCount;
    }
    return -1;
  }

  /** 条数的显示单位：「平台音乐」报的是账号数，其余都是曲目数。 */
  private countUnitOf(action: string): string {
    return action === 'platform' ? '个' : '首';
  }

  /**
   * 快捷入口清单（照搬参考那 5 格：本地音乐 / 最近播放 / 收藏 / 下载管理 / 平台音乐）。
   *
   * 图标（用户 2026-10-11 逐个点名，全部核对过 `sdk\default\openharmony\ets\build-tools\
   * ets-loader\sysResource.js` 里 `sys.symbol` 的符号表，5 个名字都存在）：
   *   本地音乐 `music_square_stack_fill` / 最近播放 `doc_text_badge_clock_fill` /
   *   收藏 `star_square_stack_fill` / 下载管理 `download_fill` / 设置 `gearshape`。
   */
  private quickEntries(): MineQuickEntry[] {
    const local = new MineQuickEntry();
    local.symbol = $r('sys.symbol.music_square_stack_fill');
    local.label = '本地音乐';
    local.action = 'local';
    const history = new MineQuickEntry();
    history.symbol = $r('sys.symbol.doc_text_badge_clock_fill');
    history.label = '最近播放';
    history.action = 'history';
    const favorite = new MineQuickEntry();
    favorite.symbol = $r('sys.symbol.star_square_stack_fill');
    favorite.label = '收藏';
    favorite.action = 'favorites';
    const download = new MineQuickEntry();
    download.symbol = $r('sys.symbol.download_fill');
    download.label = '下载管理';
    download.action = 'downloads';
    // ★ 第 5 格用**我们自己的「平台音乐」**（原「云端音乐」= 参考那套 WebDAV 曲库）：
    //   用户 2026-10-11 明确「那个云端音乐还是不要用他那套逻辑了，正好用我们多出来的这个平台音乐」。
    //   平台音乐页仍在 `features/setting/.../account/PlatformMusicPage.ets`，
    //   入口走大设置页那一档（`SETTINGS_DETAIL` + index 3，渲染的就是它本体，没有第二份实现）。
    const platform = new MineQuickEntry();
    platform.symbol = $r('sys.symbol.auditorium');
    platform.label = '平台音乐';
    platform.action = 'platform';
    return [local, history, favorite, download, platform];
  }

  /** 快捷入口的无障碍播报文本（带单位的条数一起播报）。 */
  private quickA11y(entry: MineQuickEntry): string {
    const count: number = this.countOf(entry.action);
    return count >= 0 ?
      entry.label + '，共 ' + count + this.countUnitOf(entry.action) : entry.label;
  }

  /** 入口卡：设置（大设置页本体）+ 帮助和反馈（设置详情页的「关于」）。 */
  private linkRows(): MineLinkRow[] {
    const settings = new MineLinkRow();
    settings.symbol = $r('sys.symbol.gearshape');
    settings.label = '设置';
    settings.action = 'settings';
    const help = new MineLinkRow();
    help.symbol = $r('sys.symbol.questionmark_circle');
    help.label = '帮助和反馈';
    help.action = 'about';
    return [settings, help];
  }

  // ─────────────────────────────── 路由（全部走壳层共享栈） ───────────────────────────────

  /** 统一的推栈入口（带一行日志，真机 `findstr RzdMineRoute` 一眼看出点了哪一格）。 */
  private pushOnShellStack(name: string, param: Object): void {
    hilog.info(DOMAIN, TAG, 'push name=%{public}s stackSize=%{public}d', name, this.pageIndexInfos.size());
    this.pageIndexInfos.pushPathByName(name, param);
  }

  /** 推进设置详情页的某一档。 */
  private pushSettingsDetail(index: number): void {
    const param = new SettingsDetailRouteParam();
    // ⚠️ 字段名是 `index`（组件内的 @Param 才叫 sheetIndex）
    param.index = index;
    this.pushOnShellStack(RouterUrlConstants.SETTINGS_DETAIL, param);
  }

  /**
   * 打开「平台音乐」（设置详情页第 3 档，渲染的就是 `PlatformMusicPage` 本体）。
   *
   * 收藏歌单那一行的点击落点：我们没有在线歌单详情页，在线歌单只能在平台音乐页里
   * 播放或导入（见 `CollectedRow` 的说明）。
   */
  private openPlatformMusic(): void {
    hilog.info(DOMAIN, TAG, 'open platform music from collected playlist row');
    this.pushSettingsDetail(PLATFORM_MUSIC_SHEET_INDEX);
  }

  /** 快捷入口点了某一格。 */
  private onQuickTap(action: string): void {
    if (action === 'local') {
      // 本地音乐是独立 HAR，路由名在它自己的 router_map.json 里（无参数）
      this.pushOnShellStack(LOCAL_MUSIC_ROUTE, new Object());
      return;
    }
    if (action === 'history' || action === 'favorites') {
      // 最近播放 / 收藏：一页两模式（RecordListPage）
      const param = new RecordListRouteParam();
      param.mode = action === 'history' ? RECORD_MODE_HISTORY : RECORD_MODE_FAVORITES;
      this.pushOnShellStack(RouterUrlConstants.RECORD_LIST, param);
      return;
    }
    if (action === 'downloads') {
      // 下载管理 = 设置详情页的 index 10（与设置页那一档是同一个页面、同一份实现）
      this.pushSettingsDetail(DOWNLOAD_SHEET_INDEX);
      return;
    }
    if (action === 'platform') {
      // ★ 第 5 格 = 我们自己的「平台音乐」（原「云端音乐」那套 WebDAV 曲库已按用户要求不用了）。
      //   平台音乐页本体在 `features/setting/.../account/PlatformMusicPage.ets`，
      //   由大设置页的那一档渲染出来（`SETTINGS_DETAIL` + index 3），**没有第二份实现**。
      this.pushSettingsDetail(PLATFORM_MUSIC_SHEET_INDEX);
    }
  }

  /** 入口卡点了某一行。 */
  private onLinkTap(action: string): void {
    if (action === 'about') {
      // 「帮助和反馈」直接落到大设置页的「关于」那一档（少一次点击）
      this.pushSettingsDetail(ABOUT_SHEET_INDEX);
      return;
    }
    // 「设置」= 我们原本那个大设置页**本体**（不是副本、不是二级入口列表）
    this.pushOnShellStack(RouterUrlConstants.SETTING_PAGE, new Object());
  }

  // ─────────────────────────────── 歌单（原「歌单」页签的能力） ───────────────────────────────

  /** 打开「新建歌单」小面板。 */
  private openCreatePlaylist(): void {
    this.editingId = '';
    this.editName = '';
    this.editOpen = true;
  }

  /** 打开「重命名歌单」小面板。 */
  private openRenamePlaylist(item: PlaylistDto): void {
    this.editingId = item.id;
    this.editName = item.name;
    this.editOpen = true;
  }

  /** 提交新建 / 重命名（空名字直接忽略）。 */
  private submitEdit(): void {
    const name: string = this.editName.trim();
    if (name.length === 0) {
      return;
    }
    if (this.editingId.length === 0) {
      this.store.createPlaylist(name);
    } else {
      this.store.renamePlaylist(this.editingId, name);
    }
    this.editOpen = false;
    this.refreshPlaylists();
  }

  /**
   * 「歌单导入」：**直接开从网络导入的表单**（选来源 + 粘贴分享链接）。
   *
   * 用户 2026-10-11 明确：「我的页的歌单导入别提示了，直接用从网络导入」——
   * 所以这里不再跳「全部歌单」整页、也不再弹那句"去点右上角 +"的提示，
   * 而是把**同一个** `NetworkImportSheet` 组件（「全部歌单」页用的就是它）就地弹出来。
   * 导入落库仍走 `MusicStoreService.importPlaylist()`，没有第二份实现。
   */
  private openImportPlaylist(): void {
    this.importSheetOpen = true;
  }

  /** 进「全部歌单」整页（= 原来那个「歌单」页签的整页能力）。 */
  private openAllPlaylists(): void {
    this.pushOnShellStack(RouterUrlConstants.MINE_PLAYLIST, new Object());
  }

  /** 点歌单行：进歌单详情（走壳层共享栈，与歌单页同一条路由）。 */
  private openPlaylistDetail(item: PlaylistDto): void {
    const param = new ToplistRouteParam();
    param.sectionType = 'playlist';
    param.playlistId = item.id;
    param.listTitle = item.name;
    param.listCover = item.cover;
    this.pushOnShellStack(RouterUrlConstants.PLAYLIST_DETAIL, param);
  }

  /** 长按歌单行 → 重命名（同一套小面板，`editingId` 非空即重命名）。 */
  private renamePlaylist(item: PlaylistDto): void {
    this.openRenamePlaylist(item);
  }

  /**
   * 长按歌单行 → 删除。
   *
   * 走的就是歌单页那一支 `MusicStoreService.deletePlaylist`，所以**不存在两套删除语义**；
   * 区别只是这里没有"改封面 / 导出"那几项（那些在整页里）。
   */
  private removePlaylist(item: PlaylistDto): void {
    this.getUIContext().showAlertDialog({
      title: '删除歌单',
      message: `确定要删除「${item.name}」吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '删除',
        // 危险操作的字色：走系统 token（原来这里写死十六进制）
        fontColor: $r('sys.color.warning'),
        action: (): void => {
          this.store.deletePlaylist(item.id);
          this.refreshPlaylists();
        }
      }
    });
  }

  // ─────────────────────────────── 版式：几何 ───────────────────────────────

  /** 左右安全边距（按断点，与其它页面同一档）。 */
  private contentPaddingSide(): number {
    return new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /** 内容视口顶部要避让的高度（状态栏 + HDS 标题栏）。 */
  private titleTopInset(): number {
    return getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP;
  }

  /** 宽屏（平板 / 折叠展开 / PC 浮窗）：歌单卡与入口卡并排（照搬参考那段排法）。 */
  private isWide(): boolean {
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
      this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_XL;
  }

  /** 底部预留：HDS 浮动页签栏(56) + 页签栏间距(16) + 呼吸空间(16)。 */
  private bottomReservedVp(): number {
    return 56 + 16 + 16;
  }

  // ─────────────────────────────── 版式：卡片 ───────────────────────────────

  /**
   * ② 快捷入口卡（照搬参考 `quickCard()`：一排平分，图标方块在上、名字与条数在下）。
   *
   * 参考用「淡红方块 + 红图形」（`C_RED_TINT` + `C_RED` —— 那是洛雪红，**不能抄**）。
   * 我们用**用户自定义强调色 12% 的方块 + 强调色图形**合成同一观感：
   * `themeState.color` 是 `@ObservedV2 + @Trace`，用户改主题色时这一排**同一帧**跟着变。
   *
   * ⚠️ 5 格平分宽度、不做横向滚动（参考也是平分）：320vp 小屏上每格 64vp 左右，
   *    名字 13fp 用 `maxLines(1)` + 省略号兜住。
   */
  @Builder
  private QuickCard() {
    Row() {
      ForEach(this.quickEntries(), (entry: MineQuickEntry) => {
        Column({ space: 6 }) {
          Stack({ alignContent: Alignment.Center }) {
            // ★ 用户 2026-10-11：「那五个图标后面的小背景去掉（不是大卡片，是小卡片）」。
            //   原来这里垫了一块 44×44、圆角 15、强调色 12% 的方块（`QUICK_ICON_BOX/RADIUS` +
            //   `ACCENT_TINT_OPACITY`）—— 现在只留图标本身；外框尺寸保留 44×44 ，
            //   五格的图标中心与文字基线不会因为删背景而挪位。
            SymbolGlyph(entry.symbol)
              .fontSize(26)
              .fontColor([this.themeState.color])
          }
          .width(QUICK_ICON_BOX)
          .height(QUICK_ICON_BOX)

          Text(entry.label)
            .fontSize(F_SUB + 0.5)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 五格**都**画条数（用户要求统一）；单位按格算：「平台音乐」是账号数、其余是曲目数
          Text(String(this.countOf(entry.action)) + ' ' + this.countUnitOf(entry.action))
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ top: 16, bottom: 14 })
        .borderRadius(QUICK_ICON_RADIUS)
        .stateStyles({
          normal: { .backgroundColor(Color.Transparent) },
          pressed: { .backgroundColor($r('sys.color.background_secondary')) }
        })
        .onClick(() => {
          this.onQuickTap(entry.action);
        })
        .accessibilityText(this.quickA11y(entry))
        .accessibilityLevel('yes')
      }, (entry: MineQuickEntry) => 'mine_quick_' + entry.action)
    }
    .width('100%')
    .borderRadius(R_CARD)
    .backgroundColor($r('app.color.card_background'))
    .clip(true)
  }

  /**
   * ③ 歌单卡（照搬参考 `playlistCard()`：卡头两段 + 浅底动作区 + 歌单行 + 长按菜单）。
   *
   * ★ 卡头是「自建歌单 | 收藏歌单」两段（各自的计数、`|` 分隔、**当前那段加粗**），
   *   照搬参考的 `playlistTab` 切换。
   *
   * ★ 两段的数据来源（2026-10-11 第四轮补齐）：
   *   · 自建歌单 = `store.getPlaylists()`（本地自建 + 网络导入落下来的）；
   *   · 收藏歌单 = `store.getFavoritePlaylists()` —— **收藏的在线歌单**（平台歌单），
   *     存 `FavoriteEntry`（id / source / name / sub / img / count），
   *     由平台音乐页每行右侧那颗「收藏」按钮写入（`addFavoritePlaylist`）。
   *     上一轮这里只有一段，是因为当时**确实没有这个本地存储**（全仓 grep 零命中）；
   *     现在在 `MusicStoreService` 里按"收藏歌手 / 收藏专辑"同一套写法补上了
   *     （键 `favorite_playlists` + `@Trace favoritePlaylistVersion`），所以两段都有真数据，
   *     仍然**不编造**任何一条。
   *
   * ★ 卡头右端是我们原有的「全部」入口（参考没有），只对**自建歌单**那一段显示：
   *   整页能力（新建 / 排序 / 导入 / 导出 / 改封面 / 删除）都在 `MinePlaylistPage` 里。
   */
  @Builder
  private PlaylistCard() {
    Column() {
      // 卡头：两段标题 + 计数 + 右侧「全部」（照搬参考卡头的版式与高度 54）
      Row({ space: 6 }) {
        Text('自建歌单')
          .fontSize(F_SECTION)
          .fontWeight(this.playlistTab === 0 ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.playlistTab === 0 ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
          .onClick(() => {
            this.playlistTab = 0;
          })
        Text(String(this.playlists.length))
          .fontSize(F_SUB)
          .fontColor($r('sys.color.font_tertiary'))
        Text('|')
          .fontSize(F_SUB)
          .fontColor($r('app.color.comp_divider'))
        Text('收藏歌单')
          .fontSize(F_SECTION)
          .fontWeight(this.playlistTab === 1 ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.playlistTab === 1 ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
          .onClick(() => {
            this.playlistTab = 1;
          })
        Text(String(this.collectedPlaylists.length))
          .fontSize(F_SUB)
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
        if (this.playlistTab === 0) {
          Text('全部')
            .fontSize(F_SUB)
            // 可点文字用**用户自定义强调色**
            .fontColor(this.themeState.color)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .fontColor([$r('sys.color.icon_tertiary')])
        }
      }
      .width('100%')
      .height(CARD_HEADER_HEIGHT)
      .padding({ left: 14, right: 14 })
      .onClick(() => {
        // ⚠️ 整行点击只在「自建歌单」那一段生效：段标题自己带 onClick（先消费掉），
        //    点到空白处才算「全部歌单」——切到收藏段时这里不做任何事。
        if (this.playlistTab === 0) {
          this.openAllPlaylists();
        }
      })
      .accessibilityText(this.playlistTab === 0 ? '全部歌单' : '收藏歌单')
      .accessibilityLevel('yes')

      // 动作区（照搬参考：64 高、圆角 16、浅灰底，两格平分）——只属于「自建歌单」那一段
      if (this.playlistTab === 0) {
        Column() {
          Row() {
            this.PlaylistAction(0)
            this.PlaylistAction(1)
          }
          .width('100%')
          .height(CARD_ACTION_HEIGHT)
          .borderRadius(CARD_ACTION_RADIUS)
          .backgroundColor($r('app.color.capsule_background'))
          .clip(true)
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 10 })
      }

      if (this.playlistTab === 0) {
        if (this.playlists.length === 0) {
          Text('还没有歌单，点上面的「新建歌单」建一个，或者用「歌单导入」粘贴一张分享链接')
            .fontSize(F_SUB)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .padding({ left: 14, right: 14, top: 4, bottom: 18 })
            .textAlign(TextAlign.Start)
        } else {
          // ★ 歌单行：LazyForEach + 稳定 key（数据源见 MinePlaylistSource）
          LazyForEach(this.playlistSource, (item: PlaylistDto, index: number) => {
            this.PlaylistRow(item, index > 0)
          }, (item: PlaylistDto, index: number) => this.playlistSource.keyOf(index))

          if (this.playlists.length > PLAYLIST_PREVIEW_MAX) {
            Text(`查看全部 ${this.playlists.length} 张歌单`)
              .fontSize(F_SUB)
              .fontColor(this.themeState.color)
              .width('100%')
              .height(44)
              .padding({ left: 14, right: 14 })
              .textAlign(TextAlign.Start)
              .onClick(() => {
                this.openAllPlaylists();
              })
          }
        }
      } else {
        if (this.collectedPlaylists.length === 0) {
          Text('')
            .width('100%')
            .height(12)
            .fontSize(F_SUB)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .padding({ left: 14, right: 14, top: 4, bottom: 18 })
            .textAlign(TextAlign.Start)
        } else {
          ForEach(this.collectedPlaylists.slice(0, PLAYLIST_PREVIEW_MAX),
            (entry: FavoriteEntry, index: number) => {
              this.CollectedRow(entry, index > 0)
            }, (entry: FavoriteEntry) => 'mine_collected_' + entry.source + '_' + entry.id)
        }
      }
    }
    .width('100%')
    .borderRadius(R_CARD)
    .backgroundColor($r('app.color.card_background'))
    .clip(true)
  }

  /**
   * 收藏歌单的一行（封面 + 名字 + 平台·曲目数 + 右箭头，行高与自建歌单一致）。
   *
   * 打开位置：**平台音乐**（设置详情页那一档）。我们没有"在线歌单详情页"——
   * 在线歌单在本工程里只有两条出路：① 在平台音乐页里直接播放；② 走 `NetworkImportSheet`
   * 导入成本地歌单。所以这一行不假装能打开详情，统一跳到平台音乐；
   * 长按给「取消收藏」。
   */
  @Builder
  private CollectedRow(entry: FavoriteEntry, showDivider: boolean) {
    Column() {
      if (showDivider) {
        Divider()
          .strokeWidth(0.6)
          .color($r('app.color.comp_divider'))
          .margin({ left: 72 })
      }

      Row({ space: 12 }) {
        Stack() {
          if (entry.img.length > 0) {
            Image(entry.img)
              .width(ROW_COVER)
              .height(ROW_COVER)
              .borderRadius(R_COVER)
              .objectFit(ImageFit.Cover)
              .alt($r('sys.symbol.music_note_list'))
          } else {
            Row() {
              SymbolGlyph($r('sys.symbol.star_square_stack_fill'))
                .fontSize(22)
                .fontColor([$r('sys.color.font_tertiary')])
            }
            .width(ROW_COVER)
            .height(ROW_COVER)
            .borderRadius(R_COVER)
            .backgroundColor($r('sys.color.background_tertiary'))
            .justifyContent(FlexAlign.Center)
          }
        }
        .width(ROW_COVER)
        .height(ROW_COVER)

        Column({ space: 4 }) {
          Text(entry.name)
            .fontSize(F_ITEM)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
          Text(this.collectedMeta(entry))
            .fontSize(F_SUB)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .height(18)
          .fontColor([$r('sys.color.icon_tertiary')])
      }
      .width('100%')
      .height(LIST_ROW_HEIGHT)
      .padding({ left: 14, right: 14 })
      .onClick(() => {
        this.openPlatformMusic();
      })
      .bindContextMenu(this.CollectedRowMenu(entry), ResponseType.LongPress)
    }
    .width('100%')
  }

  /** 收藏行的副标题：平台名 + 曲目数（都没有就退回来源 id）。 */
  private collectedMeta(entry: FavoriteEntry): string {
    const parts: string[] = [];
    if (entry.sub.length > 0) {
      parts.push(entry.sub);
    } else if (entry.source.length > 0) {
      parts.push(sourceName(entry.source));
    }
    if (entry.count > 0) {
      parts.push(String(entry.count) + ' 首');
    }
    return parts.length > 0 ? parts.join(' · ') : '在线歌单';
  }

  /** 收藏行的长按菜单：取消收藏 / 打开平台音乐。 */
  @Builder
  private CollectedRowMenu(entry: FavoriteEntry) {
    Menu() {
      MenuItem({ content: '取消收藏' })
        .onClick(() => {
          this.store.removeFavoritePlaylist(entry.source, entry.id);
          hilog.info(DOMAIN, TAG, 'uncollect playlist source=%{public}s id=%{public}s',
            entry.source, entry.id);
        })
      MenuItem({ content: '打开平台音乐' })
        .onClick(() => {
          this.openPlatformMusic();
        })
    }
  }

  /** 歌单卡动作区的一格（照搬参考 `cardAction()`：图标 23 + 名字）。 */
  @Builder
  private PlaylistAction(index: number) {
    Column({ space: 6 }) {
      SymbolGlyph(index === 0 ? $r('sys.symbol.plus') : $r('sys.symbol.square_and_arrow_down'))
        .fontSize(23)
        .fontColor([$r('sys.color.font_primary')])
      Text(index === 0 ? '新建歌单' : '歌单导入')
        .fontSize(F_SUB + 0.5)
        .fontColor($r('sys.color.font_primary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .stateStyles({
      normal: { .backgroundColor(Color.Transparent) },
      pressed: { .backgroundColor($r('app.color.capsule_background')) }
    })
    .onClick(() => {
      if (index === 0) {
        this.openCreatePlaylist();
      } else {
        this.openImportPlaylist();
      }
    })
    .accessibilityText(index === 0 ? '新建歌单' : '导入歌单')
    .accessibilityLevel('yes')
  }

  /**
   * 歌单行（照搬参考 `playlistRow()`：占位封面 + 名字 + 曲目数 + 右箭头，行高 70）。
   *
   * 长按是那套行菜单（照搬参考 `rowMenu()` 的形状：重命名 / 删除 / 打开歌单）；
   * 重命名走本页的小面板、删除走确认框，两者最终都调 `MusicStoreService` 的同一支方法
   * —— 与完整歌单页**没有两套实现**。完整歌单页另外还有「拖动排序 / 导出 / 设置封面 /
   * 网络导入 / 本地音乐入口」，那些只从卡头的「全部」进。
   */
  @Builder
  private PlaylistRow(item: PlaylistDto, showDivider: boolean) {
    Column() {
      if (showDivider) {
        Divider()
          .strokeWidth(0.6)
          .color($r('app.color.comp_divider'))
          .margin({ left: 72 })
      }

      Row({ space: 12 }) {
        // ★ 封面三级优先级（与「全部歌单」页 `PlaylistsPage.PlaylistRow` 逐字同构）：
        //   ① 歌单自己的封面（自定义 / 在线导入时带过来的沙箱 URI）→ `LocalCoverImage` 用 fd 解码；
        //   ② 第一首歌的专辑图（在线导入进来的歌单都有 `img`，这一级才是"我的页也有封面"的关键）；
        //   ③ 灰底音符占位。
        //   ⚠️ 这里曾经**只有 ① 和 ③**（注释还写着"不用第一首歌的封面顶替"），
        //      结果就是用户看到的「我的页歌单不显示封面，点进歌单页就正常」——
        //      两级列表用的不是同一套优先级。现在两级共用同一套。
        Stack() {
          if (item.cover.length > 0) {
            // 自定义封面是沙箱文件 URI，走 LocalCoverImage 用 fd 解码（真机 Image 直喂不显示）
            LocalCoverImage({
              src: item.cover,
              imageWidth: ROW_COVER,
              imageHeight: ROW_COVER,
              radius: R_COVER,
              fit: ImageFit.Cover
            })
          } else if (item.songs.length > 0 && item.songs[0].img.length > 0) {
            Image(item.songs[0].img)
              .width(ROW_COVER)
              .height(ROW_COVER)
              .borderRadius(R_COVER)
              .objectFit(ImageFit.Cover)
              .alt($r('sys.symbol.music_note_list'))
          } else {
            Row() {
              SymbolGlyph($r('sys.symbol.music_note_list'))
                .fontSize(22)
                .fontColor([$r('sys.color.font_tertiary')])
            }
            .width(ROW_COVER)
            .height(ROW_COVER)
            .borderRadius(R_COVER)
            .backgroundColor($r('sys.color.background_tertiary'))
            .justifyContent(FlexAlign.Center)
          }
        }
        .width(ROW_COVER)
        .height(ROW_COVER)

        Column({ space: 4 }) {
          Text(item.name)
            .fontSize(F_ITEM)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
          Text(String(item.songs.length) + ' 首')
            .fontSize(F_SUB)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .height(18)
          .fontColor([$r('sys.color.icon_tertiary')])
      }
      .width('100%')
      .height(LIST_ROW_HEIGHT)
      .padding({ left: 14, right: 14 })
      .onClick(() => {
        this.openPlaylistDetail(item);
      })
      .bindContextMenu(this.PlaylistRowMenu(item), ResponseType.LongPress)
    }
    .width('100%')
  }

  /** 歌单行的长按菜单（照搬参考 `rowMenu()` 的形状）。 */
  @Builder
  private PlaylistRowMenu(item: PlaylistDto) {
    Menu() {
      MenuItem({ content: '重命名' })
        .onClick(() => {
          this.renamePlaylist(item);
        })
      MenuItem({ content: '删除' })
        .onClick(() => {
          this.removePlaylist(item);
        })
      MenuItem({ content: '打开歌单' })
        .onClick(() => {
          this.openPlaylistDetail(item);
        })
    }
  }

  /** ④ 入口卡：设置 / 帮助和反馈 / 平台音乐（照搬参考 `linksCard()`：行高 58、图标 22、右箭头、左缩进 50）。 */
  @Builder
  private LinksCard() {
    Column() {
      ForEach(this.linkRows(), (row: MineLinkRow, index: number) => {
        Column() {
          if (index > 0) {
            Divider()
              .strokeWidth(0.6)
              .color($r('app.color.comp_divider'))
              .margin({ left: 50 })
          }
          Row({ space: 14 }) {
            SymbolGlyph(row.symbol)
              .fontSize(22)
              .fontColor([$r('sys.color.font_primary')])
            Text(row.label)
              .fontSize(F_ITEM)
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(18)
              .height(18)
              .fontColor([$r('sys.color.icon_tertiary')])
          }
          .width('100%')
          .height(LINK_ROW_HEIGHT)
          .padding({ left: 14, right: 14 })
          .stateStyles({
            normal: { .backgroundColor(Color.Transparent) },
            pressed: { .backgroundColor($r('sys.color.background_secondary')) }
          })
          .onClick(() => {
            this.onLinkTap(row.action);
          })
          .accessibilityText(row.label)
          .accessibilityLevel('yes')
        }
        .width('100%')
      }, (row: MineLinkRow) => 'mine_link_' + row.action)
    }
    .width('100%')
    .borderRadius(R_CARD)
    .backgroundColor($r('app.color.card_background'))
    .clip(true)
  }

  // ─────────────────────────────── HDS 标题栏 ───────────────────────────────

  /**
   * HDS 标题栏：大标题「我的」。
   *
   * 记录列表的「播放全部 / 多选删除」动作钮跟着记录一起搬去了 `RecordListPage`
   * （本页不再有列表），分段胶囊也早就搬走了，所以这里**没有菜单**。
   * 标题栏保留 HDS 沉浸材质（`buildTitleMaterial`）与滚动渐变模糊 —— 光感只在这类
   * 合规区域（标题栏 / 底部 TabBar）生效，别挪到普通容器上。
   */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    const bar: HdsNavigationTitleBarOptions = {
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
            }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            }
          }
        },
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        title: {
          mainTitle: $r('app.string.mine_title'),
          mainTitleSize: TitleSize.TITLE_ML
        }
      }
    };
    return bar;
  }

  /**
   * 「歌单导入」面板：**直接复用** `features/playlist` 的 `NetworkImportSheet`。
   *
   * 版式、来源下拉、链接校验、`SharePlaylistService.fetchPlaylist()` 与
   * `MusicStoreService.importPlaylist()` 全在那个组件里 —— 本页一行都不重复实现，
   * 与「全部歌单」页点「+ → 网络导入」是**同一个入口**。
   */
  @Builder
  private ImportPlaylistSheet() {
    NetworkImportSheet({
      onClose: (): void => {
        this.importSheetOpen = false;
      },
      onImported: (name: string, count: number): void => {
        this.importSheetOpen = false;
        // 歌单卡的数据靠 `store.playlistVersion` 自己刷新（`@Monitor('store.playlistVersion')`）
        this.getUIContext().getPromptAction().showToast(
          { message: '已导入歌单「' + name + '」(' + count + ' 首)', duration: 2500 });
      }
    })
  }

  /** 「新建 / 重命名歌单」小面板的内容（照搬参考 `editSheet()` 的形状）。 */
  @Builder
  private EditPlaylistSheet() {
    Column({ space: 12 }) {
      TextInput({ text: this.editName, placeholder: '歌单名称' })
        .placeholderColor($r('sys.color.font_tertiary'))
        .placeholderFont({ size: 14 })
        .fontSize(14)
        .height(46)
        .backgroundColor($r('sys.color.background_tertiary'))
        .onChange((value: string) => {
          this.editName = value;
        })
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .backgroundColor($r('sys.color.background_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            this.editOpen = false;
          })
        Button('确定')
          .layoutWeight(1)
          .height(40)
          // 主操作按钮用**用户自定义强调色**
          .backgroundColor(this.themeState.color)
          .fontColor($r('sys.color.font_on_primary'))
          .onClick(() => {
            this.submitEdit();
          })
      }
      .width('100%')
      Column()
        .height(this.bottomReservedVp() + 8)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 8 })
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        /**
         * 页面是一张 `List`：卡片之间靠 `space: 14` 留缝（照搬参考 `Column({space:14})` 的间距）。
         *
         * ⚠️ 顶部那段占位也是 ListItem，所以它也会吃到 `space`：写 `titleTopInset() - 8`
         *    补回那一段（最终 = 状态栏 + 标题栏 + 6）。
         */
        List({ space: 14, scroller: this.pageScroller }) {
          ListItem() {
            Column()
              .height(this.titleTopInset() - 8)
              .width('100%')
          }

          // ① 账号卡（我们原本大设置页顶上那张「登录音乐」）
          ListItem() {
            LoginMusicCard()
          }

          // ② 快捷入口卡
          ListItem() {
            this.QuickCard()
          }

          /**
           * ③④ 宽屏：歌单卡与入口卡**并排**（照搬参考那段：歌单卡 2 份、入口卡 1 份，顶对齐）；
           *      窄屏：一上一下（顺序照参考：歌单卡在前，入口卡在后）。
           */
          if (this.isWide()) {
            ListItem() {
              Row({ space: 14 }) {
                Column() {
                  this.PlaylistCard()
                }
                .layoutWeight(2)

                Column() {
                  this.LinksCard()
                }
                .layoutWeight(1)
              }
              .width('100%')
              // 顶对齐：两张卡高度差得远（歌单卡可能好几行），居中的话入口卡会飘在半空
              .alignItems(VerticalAlign.Top)
            }
          } else {
            ListItem() {
              this.PlaylistCard()
            }
            ListItem() {
              this.LinksCard()
            }
          }

          // 底部预留：HDS 浮动页签栏 + 手势条
          ListItem() {
            Column()
              .height(this.bottomReservedVp())
              .width('100%')
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        // ★ 底部（以及顶部）回弹：`List` 的 `edgeEffect` 默认是 `Spring`，但
        //   `EdgeEffectOptions.alwaysEnabled` 对 **List/Grid/WaterFlow 默认 false**、
        //   对 Scroll 才是 true（官方《滚动组件通用接口 · edgeEffect》原文：
        //   「组件内容大小小于组件自身时是否开启滑动效果……默认值：List、Grid、WaterFlow
        //   组件默认 { alwaysEnabled: false }，Scroll 组件默认 { alwaysEnabled: true }」）。
        //   我的页内容短于一屏时（或用大屏/折叠展开）拖到底就没有回弹，用户点名的就是这个
        //   ⇒ 显式打开 alwaysEnabled。
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .clip(true)
        // 滚动联动双层底栏：上滑收起、下滑展开（与首页/歌单/设置一致）
        .onScrollFrameBegin((offset: number): OnScrollFrameBeginHandlerResult => {
          if (BarScrollHelper.isEnabled()) {
            BarScrollHelper.notifyScrollDelta(this.getUIContext(), this.appState, offset,
              this.breakpointEnv.widthBreakpoint as number);
          }
          return { offsetRemain: offset };
        })
        .padding({
          left: this.contentPaddingSide(),
          right: this.contentPaddingSide()
        })

        // ⑤ 顶栏渐隐：卡片从透明标题栏底下穿过时靠近顶部淡出（照搬参考的 TopFade）
        MineTopFade({ fadeHeight: this.titleTopInset() + 10 })
      }
      .width('100%')
      .height('100%')
      .bindSheet($$this.editOpen, this.EditPlaylistSheet(), {
        preferType: SheetType.BOTTOM,
        detents: [SheetSize.MEDIUM],
        detentSelection: SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        title: { title: this.editingId.length === 0 ? '新建歌单' : '重命名歌单' },
        backgroundColor: $r('app.color.background_secondary')
      })
      // 「歌单导入」= 就地弹**从网络导入**那张表单（与「全部歌单」页同一个组件，见 openImportPlaylist）
      .bindSheet($$this.importSheetOpen, this.ImportPlaylistSheet(), {
        preferType: SheetType.BOTTOM,
        detents: [SheetSize.MEDIUM],
        detentSelection: SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        title: { title: '网络导入歌单' },
        backgroundColor: $r('sys.color.background_secondary'),
        onDisappear: (): void => {
          this.importSheetOpen = false;
        }
      })
    }
    .onBackPressed((): boolean => guardPlayerBack('MinePage'))
    .hideTitleBar(false)
    .hideBackButton(true)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.background_secondary'))
  }
}

