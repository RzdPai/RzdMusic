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
 *   | ① `AccountCard()`  账号卡（**我们的加法**，用户要求放最上面） | 参考里没有，本工程既有 `HuaweiAccountCard` |
 *   | ② `QuickCard()`    快捷入口那一排（图标方块 + 名字 + 条数） | `quickCard()` |
 *   | ③ `PlaylistCard()` 歌单卡（卡头 + 动作区 + 歌单行 + 长按菜单） | `playlistCard()` |
 *   | ④ 记录卡（`SegmentRow()` 卡头 + 记录行） | 复用 `playlistCard()` 的**卡头版式**当"内容卡" |
 *   | ⑤ `LinksCard()`    设置入口卡 | `linksCard()` |
 *   | ⑥ `MineTopFade`    顶栏自绘渐隐 | `TopFade` |
 *
 *   尺寸/字号常量照抄它的 `ui/Theme.ets`（`R_CARD=16` / `F_SECTION=17` / `F_ITEM=16.5` /
 *   `F_SUB=12.5` / 歌单行 70 / 入口行 58 / 卡头 54 / 快捷图标 44·圆角 15 / 动作区 64·圆角 16），
 *   **颜色一律走我们的 token**（`app.color.*` / `sys.color.*` / `ThemeState.color`），
 *   深浅色由 HDS 色板自动适配 —— 参考那套 `C_*` 是洛雪红 + 写死的白卡，不能照抄色值。
 *
 * ★ 与我们原有功能的衔接（**一个都没丢**）：
 *   - 四段记录（播放历史 / 收藏 / 平台音乐 / 下载管理）、多选删除、`SongMoreMenu`、
 *     收藏的歌手 / 专辑分组，全部搬进**第 ④ 张卡的卡头 + 卡身**（段标题从 HDS 标题栏的
 *     胶囊挪到卡里，就是参考 `playlistCard()` 头部那个「左标题 + 计数 + | + 加粗」的版式）；
 *   - 「歌单」页签被删掉后，它的能力由第 ③ 张卡承担：卡头右端「全部」进整页
 *     （`RouterUrlConstants.MINE_PLAYLIST` → `PlaylistsPage`），卡内直接列歌单、点进详情、
 *     长按重命名/删除，「新建歌单」就地弹层建，「歌单导入」进整页（整页有来源 + 链接表单）；
 *   - 「设置」页签被删掉后，入口在第 ⑤ 张卡（`MineSettingsPage` 二级页，链路不变）。
 *
 * ⚠️ 记录列表仍然是 `List` + `LazyForEach` + 稳定 key（**卡只是视觉上的**：卡头 / 行 /
 *    卡底是相邻的 ListItem，靠同一底色 + 首尾圆角拼出一张卡）。**不要**把记录行塞进
 *    Column 里包成一张卡 —— `LazyForEach` 离开滚动容器就不再懒加载，几千条历史会全建节点。
 */

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { guardPlayerBack } from 'musicbasic';
import { PlaybackIntentState, SongItem } from 'musicbasic';
import {
  AlbumRouteParam, AmbientState, AppStorageKeys, ArtistRouteParam, BarScrollHelper, BreakpointType,
  FavoriteEntry, LocalCoverImage, MusicAppState, MusicStoreService, PlayedSongRecord, PlaylistDto,
  RouterUrlConstants, ThemeState, TitleBarConstants, ToplistRouteParam, buildTitleMaterial,
  getStatusBarTopVpFromWindowUtil
} from 'musicbasic';
import {
  BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions,
  HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize
} from '@kit.UIDesignKit';
import { OnlinePlayUtil, sourceDisplayName, sourceToCode } from 'player';
import { SongMoreMenu } from 'playlist';
import { HuaweiAccountCard } from '../account/HuaweiAccountCard';
import { PlatformMusicPage } from '../account/PlatformMusicPage';
import { DownloadManagerSection } from './DownloadManagerSection';
import { SettingsDetailRouteParam } from './SettingsDetailPage';
import { MineSettingsPage } from './MineSettingsPage';
import { MinePlaylistPage } from './MinePlaylistPage';

/** 「我的」页快捷入口的四个分区下标（与 `segmentLabels` 一一对应）。 */
const SECTION_HISTORY: number = 0;
const SECTION_FAVORITE: number = 1;
const SECTION_PLATFORM: number = 2;
const SECTION_DOWNLOAD: number = 3;

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
/** 歌单 / 记录行高（参考 `playlistCard()` 的行 70）。 */
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
/**
 * 分段标题那一行的字号。
 *
 * 参考工程那张卡的头部只有**两个**标题（自建歌单 | 收藏歌单），我们有**四个**
 * （播放历史 | 收藏 | 平台音乐 | 下载管理）—— 17fp 四个标题在小屏（320vp）上会溢出，
 * 所以这一行收 1fp（`F_SECTION - 1`），其余字号一律照搬。
 */
const SEGMENT_TITLE_FONT: number = F_SECTION - 1;
/** 歌单卡里最多内联几张歌单（超出走卡头的「全部」）。 */
const PLAYLIST_PREVIEW_MAX: number = 4;
/** 「平台音乐 / 下载管理」两段的面板顶部留白（面板自己还会补一点）。 */
const PANE_TOP_GAP: number = 8;

/**
 * 记录（历史 / 收藏）列表的懒加载数据源。
 *
 * 为什么上 `LazyForEach`：播放历史没有条数上限（用户听一年就是几千条），
 * 原来的 `Repeat` 会给每条都建节点；这里改成「按需 + 批量上报」的标准做法。
 *
 * 数据本身仍由 `MinePage` 持有（`appState` / store 是唯一真源），
 * 这个类只是它的视图适配器：**任何数据变化都必须走 `applyRecords()`**，
 * 直接改数组不会触发刷新（文件头注释里写死这条，避免以后有人绕过）。
 */
class RecordDataSource implements IDataSource {
  private records: PlayedSongRecord[] = [];
  private listeners: DataChangeListener[] = [];
  /** 稳定 key 前缀：历史用 `h_`、收藏用 `f_`（跨分段不复用节点）。 */
  private prefix: string = 'h_';
  /** 强制重建版本号（换源后 key 全变，见 `MinePage.forceReloadRecords`）。 */
  private version: number = 0;

  public totalCount(): number {
    return this.records.length;
  }

  public getData(index: number): PlayedSongRecord {
    return this.records[index];
  }

  /** 稳定 key：同一首歌在历史/收藏里都不会因为插入删除而错位。 */
  public keyOf(index: number): string {
    const record: PlayedSongRecord = this.records[index];
    if (record === undefined) {
      return this.prefix + this.version + '#' + index;
    }
    return this.prefix + this.version + '_' + record.source + '_' + record.songId;
  }

  /** 整批替换内容并通知刷新（唯一入口）。 */
  public applyRecords(next: PlayedSongRecord[], prefix: string, version: number): void {
    this.records = next;
    this.prefix = prefix;
    this.version = version;
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
 * 「关于」在设置详情页里的 sheetIndex（与 `SettingsDetailPage.detailTitle()` 的 case 9 对应）。
 */
const ABOUT_SHEET_INDEX: number = 9;

/** 快捷入口的一格。 */
class MineQuickEntry {
  symbol: Resource = $r('sys.symbol.person_crop_circle_fill_1');
  label: string = '';
  section: number = SECTION_HISTORY;
}

/** 底部入口卡的一行。 */
class MineLinkRow {
  symbol: Resource = $r('sys.symbol.gearshape_fill');
  label: string = '';
  /** 'settings' = 二级设置页，'about' = 关于（直接进设置详情页）。 */
  action: string = 'settings';
}

/**
 * 顶栏自绘渐隐蒙版（**照搬**参考工程 `ui/Widgets.ets` 的 `TopFade`）。
 *
 * 从页面底色渐隐到全透明，压在滚动内容之上、HDS 标题栏之下（标题栏是独立图层，
 * 永远在这之上）：内容越靠近顶部越淡，标题「我的」始终清晰。
 *
 * 铺满宽度、**不拦触摸**（`HitTestMode.Transparent`）—— 它只是一层视觉遮罩，
 * 不能影响滚动与点击。
 *
 * ⚠️ 属性名不能叫 `height`（与组件基类自带的同名属性冲突，编译报 not assignable），
 *    所以照搬参考的 `fadeHeight`。
 * ⚠️ 两个渐变色是**同名双值 token**（`base` 不透明 / `dark` 各一份 + alpha 0 的孪生）：
 *    `linearGradient` 的端点不能对资源色算 alpha，直接拿 `Color.Transparent` 当终点会在
 *    浅色底上"穿过黑色"（中途发暗）。见 `features/setting/src/main/resources/{base,dark}/element/color.json`。
 */
@ComponentV2
struct MineTopFade {
  /** 蒙版高度（vp）：调用方按「状态栏 + 标题栏 + 一点余量」给。 */
  @Param fadeHeight: number = 120;

  build() {
    Column()
      .width('100%')
      .height(this.fadeHeight)
      .linearGradient({
        // Bottom = 从上往下：0.0 落在顶边（底色本身），越往下越透
        direction: GradientDirection.Bottom,
        colors: [[$r('app.color.mine_top_fade'), 0.0], [$r('app.color.mine_top_fade_end'), 1.0]]
      })
      .hitTestBehavior(HitTestMode.Transparent)
  }
}

/**
 * Mine tab: the "我的" page.
 *
 * 账号卡 → 快捷入口卡 → 歌单卡 → 记录卡（四段：播放历史 / 收藏 / 平台音乐 / 下载管理）→ 入口卡。
 * 设置项本体在二级页 `MineSettingsPage`；歌单整页在二级页 `MinePlaylistPage`。
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
  /** 共享播放状态（记录行播放用）。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** 我的分段：0=播放历史，1=收藏，2=平台音乐，3=下载管理。 */
  @Local recordSection: number = SECTION_HISTORY;
  /** 卡头那四个分段标题（与 `SECTION_*` 一一对应）。 */
  @Local segmentLabels: string[] = ['播放历史', '收藏', '平台音乐', '下载管理'];
  /** 当前分段的播放记录快照（历史 / 收藏共用；平台音乐与下载管理各走自己的组件）。 */
  @Local records: PlayedSongRecord[] = [];
  /** 记录列表的懒加载数据源（`@Local` 保证 `LazyForEach` 能拿到同一个实例）。 */
  @Local recordSource: RecordDataSource = new RecordDataSource();
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /**
   * 二级页用的路由栈（**本页自带**，不走壳层的共享栈）。
   *
   * 为什么自带：
   *   ① 共享栈上这一页是 `HdsNavDestination`，而 `MineSettingsPage` 还要在**同一个栈**上
   *      再推 `SettingsDetailPage`（两级 `HdsNavDestination` 嵌套）；
   *   ② `products/pc` 的壳层给的是 `HdsNavigation(new NavPathStack())`（inline、未登记路由表），
   *      往它上面 push **静默失败**（按钮点了没反应）。
   *   自带一个 `Navigation` 时层级干净、两个 product 行为一致。
   *
   * ⚠️ `pageIndexInfos`（壳层共享栈）本页**仍在用**，而且必须用：
   *   收藏里的歌手/专辑详情、以及 `MinePlaylistPage`（= `PlaylistsPage`）里点歌单进的详情页，
   *   都走**壳层**栈 —— 它们要在整屏（含底栏之上）弹出来，与其它页面同一条路由。
   */
  @Local localStack: NavPathStack = new NavPathStack();
  /** 本地栈深度：>0 ⇒ `build()` 把二级页画在本页之内（壳层底栏仍在下面）。 */
  @Local localStackDepth: number = 0;
  @Local favoriteArtists: FavoriteEntry[] = [];
  @Local favoriteAlbums: FavoriteEntry[] = [];
  /** 多选删除模式。 */
  @Local selectionMode: boolean = false;
  /** 多选勾选表（key = source_songId）。 */
  @Local selectedMap: Record<string, boolean> = {};
  /** 平台音乐刷新信号（标题栏刷新按钮触发）。 */
  @Local platformRefreshSignal: number = 0;
  /** 快捷入口卡上「播放历史 / 收藏」的条数（与当前分段的条数分开：卡片始终显示历史与收藏各自的量）。 */
  @Local historyCount: number = 0;
  @Local favoriteCount: number = 0;
  /** 歌单卡的数据（`store.playlistVersion` 变一次就读一次）。 */
  @Local playlists: PlaylistDto[] = [];
  /** 新建 / 重命名共用的小面板：`editingId` 为空表示新建。 */
  @Local editOpen: boolean = false;
  @Local editingId: string = '';
  @Local editName: string = '';
  /**
   * 历史/收藏列表的重建版本号。
   *
   * 只用于「切换平台」后强制重建所有行（key 里带上它），见 {@link forceReloadRecords}。
   */
  @Local recordsVersion: number = 0;
  /** Scroller bound to the HDS title bar so the scroll effect (gradient blur) can fire. */
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.refreshRecords();
    this.refreshCounts();
    this.refreshPlaylists();
    this.localStackDepth = this.localStack.size();
  }

  // ─────────────────────────────── 二级页（本页自带栈） ───────────────────────────────

  /** 推进「我的 → 设置」二级页（设置页签被删掉后，这里是唯一的设置入口）。 */
  private pushMineSettings(): void {
    this.pushOnLocalStack(RouterUrlConstants.MINE_SETTINGS, new Object());
  }

  /**
   * 推进「我的 → 全部歌单」二级页（歌单页签被删掉后，整页能力从这里进）。
   *
   * 二级页是 `MinePlaylistPage` —— 一层薄壳，渲染的仍是 `features/playlist`
   * 的 `PlaylistsPage`（新建 / 排序 / 导入 / 导出 / 改封面 / 删除全在里面，**没有第二份实现**）。
   */
  private pushMinePlaylist(): void {
    this.pushOnLocalStack(RouterUrlConstants.MINE_PLAYLIST, new Object());
  }

  /** 推设置详情页（「关于」这类直达项）。 */
  private pushSettingsDetail(param: SettingsDetailRouteParam): void {
    this.pushOnLocalStack(RouterUrlConstants.SETTINGS_DETAIL, param);
  }

  /**
   * push 进本页自带的路由栈，并刷新 `localStackDepth`。
   *
   * `localStackDepth` 是**唯一的渲染门**：它一 >0 就把二级页画在本页之内
   * （`NavPathStack` 本身是可变对象，只 push 不改别的字段，ArkUI 不会因此重画）。
   */
  private pushOnLocalStack(name: string, param: Object): void {
    this.localStack.pushPathByName(name, param);
    this.localStackDepth = this.localStack.size();
  }

  /** 本页自带栈的栈顶路由名（二级页形态下选渲染哪一页）。 */
  private localStackTopName(): string {
    const names: string[] = this.localStack.getAllPathName();
    return names.length > 0 ? names[names.length - 1] : '';
  }

  /** 壳层点了当前页签：滚回顶部（底部页签设计规范）。 */
  @Monitor('scrollTopCommand')
  onScrollTopCommand(): void {
    this.pageScroller.scrollEdge(Edge.Top);
  }

  // ─────────────────────────────── 数据 ───────────────────────────────

  /** 历史/收藏版本变化时刷新当前分段列表。 */
  @Monitor('store.historyVersion', 'store.favoriteVersion')
  refreshRecords(): void {
    if (this.recordSection === SECTION_HISTORY) {
      this.records = this.normalizeRecords(this.store.getHistory());
      this.favoriteArtists = [];
      this.favoriteAlbums = [];
    } else {
      this.records = this.normalizeRecords(this.store.getFavorites());
      this.favoriteArtists = this.store.getFavoriteArtists();
      this.favoriteAlbums = this.store.getFavoriteAlbums();
    }
    this.publishRecords();
    this.refreshCounts();
  }

  /** 快捷入口卡上那两个条数（与当前分段无关，所以单独取一次）。 */
  private refreshCounts(): void {
    this.historyCount = this.store.getHistory().length;
    this.favoriteCount = this.store.getFavorites().length;
  }

  /** 歌单卡的数据（`playlistVersion` 是 `@Trace`，增删改都会走到这里）。 */
  @Monitor('store.playlistVersion')
  refreshPlaylists(): void {
    this.playlists = this.store.getPlaylists();
  }

  /** 把当前 `records` 灌进懒加载数据源（**数据变化后必须调它**）。 */
  private publishRecords(): void {
    const prefix: string = this.recordSection === SECTION_HISTORY ? 'h_' : 'f_';
    this.recordSource.applyRecords(this.records, prefix, this.recordsVersion);
  }

  /**
   * 「切换平台」后强制刷新列表（照搬「重命名歌单」那套显式刷新做法）。
   *
   * 光靠上面的 `@Monitor` 不够实时：`LazyForEach` 是**按 key 复用节点**的，
   * 而这里的 key 就是 `source_songId` —— 换源后 key 变了理论上会重建，
   * 但实测会出现"库已经改了、列表还是旧的"（页面复用/时机问题）。
   * 所以这里先重读一遍数据，再把 `recordsVersion` 抬一位：key 里带上版本号，
   * 所有行 key 全变 → 强制全部重建，立即显示新平台。
   */
  private forceReloadRecords(): void {
    this.refreshRecords();
    this.recordsVersion++;
    this.publishRecords();
  }

  /** 卡头点某一段：切过去、清掉多选、回到顶部。 */
  private switchSection(section: number): void {
    if (this.recordSection === section) {
      return;
    }
    this.recordSection = section;
    this.selectionMode = false;
    this.selectedMap = {};
    this.refreshRecords();
    this.pageScroller.scrollEdge(Edge.Top);
  }

  /**
   * 快捷入口上显示的条数。
   *
   * 只有「播放历史 / 收藏」有明确的条数语义；「平台音乐 / 下载管理」两格的条数是
   * 异步取回来的（要登录 / 要读下载库），本卡不假装知道 —— 返回 0，UI 也不显示。
   */
  private countOfSection(section: number): number {
    if (section === SECTION_HISTORY) {
      return this.historyCount;
    }
    if (section === SECTION_FAVORITE) {
      return this.favoriteCount;
    }
    return 0;
  }

  /** 快捷入口的无障碍播报文本（没有条数的那两格不提条数）。 */
  private quickA11y(entry: MineQuickEntry): string {
    if (entry.section === SECTION_HISTORY || entry.section === SECTION_FAVORITE) {
      return entry.label + '，共 ' + this.countOfSection(entry.section) + ' 首';
    }
    return entry.label;
  }

  /** 快捷入口清单（只放本页真有的四样，不做没有的会员/权益那些）。 */
  private quickEntries(): MineQuickEntry[] {
    const history = new MineQuickEntry();
    history.symbol = $r('sys.symbol.clock_fill');
    history.label = '播放历史';
    history.section = SECTION_HISTORY;
    const favorite = new MineQuickEntry();
    favorite.symbol = $r('sys.symbol.heart_fill');
    favorite.label = '收藏';
    favorite.section = SECTION_FAVORITE;
    const download = new MineQuickEntry();
    download.symbol = $r('sys.symbol.circle_and_arrow_down_fill');
    download.label = '下载管理';
    download.section = SECTION_DOWNLOAD;
    const platform = new MineQuickEntry();
    platform.symbol = $r('sys.symbol.auditorium');
    platform.label = '平台音乐';
    platform.section = SECTION_PLATFORM;
    return [history, favorite, download, platform];
  }

  /** 入口卡：设置（二级页）+ 关于（直达设置详情页）。 */
  private linkRows(): MineLinkRow[] {
    const settings = new MineLinkRow();
    settings.symbol = $r('sys.symbol.gearshape_fill');
    settings.label = '设置';
    settings.action = 'settings';
    const about = new MineLinkRow();
    about.symbol = $r('sys.symbol.info_circle_fill');
    about.label = '关于与帮助';
    about.action = 'about';
    return [settings, about];
  }

  /** 入口卡点了某一行。 */
  private onLinkTap(action: string): void {
    if (action === 'about') {
      // 「关于」直接落到设置详情页的「关于」那一块（sheetIndex = 9），少一次点击
      const aboutParam = new SettingsDetailRouteParam();
      aboutParam.index = ABOUT_SHEET_INDEX;
      this.pushSettingsDetail(aboutParam);
      return;
    }
    this.pushMineSettings();
  }

  // ─────────────────────────────── 歌单（原「歌单」页签的能力） ───────────────────────────────

  /** 歌单卡里内联展示的那几张（超出走卡头的「全部」）。 */
  private playlistPreview(): PlaylistDto[] {
    return this.playlists.slice(0, PLAYLIST_PREVIEW_MAX);
  }

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
   * 「歌单导入」：进整页。
   *
   * 导入要选来源平台 + 粘贴分享链接（外加进度层），那套表单在 `PlaylistsPage` 里，
   * 本卡不重复实现一遍 —— 直接进整页，用户点右上角那个「+」就是了。
   */
  private openImportPlaylist(): void {
    this.pushMinePlaylist();
    this.getUIContext().getPromptAction().showToast({
      message: '在「歌单」页点右上角的「+」导入',
      duration: 2200
    });
  }

  /** 点歌单行：进歌单详情（走壳层共享栈，与歌单页同一条路由）。 */
  private openPlaylistDetail(item: PlaylistDto): void {
    const param = new ToplistRouteParam();
    param.sectionType = 'playlist';
    param.playlistId = item.id;
    param.listTitle = item.name;
    param.listCover = item.cover;
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
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
        fontColor: '#E64545',
        action: (): void => {
          this.store.deletePlaylist(item.id);
          this.refreshPlaylists();
        }
      }
    });
  }

  // ─────────────────────────────── 记录：播放 / 多选 / 删除 ───────────────────────────────

  /** 播放一条历史/收藏记录（复用在线播放编排）。 */
  private playRecord(record: PlayedSongRecord): void {
    void OnlinePlayUtil.playRecord(this.appState, record, this.getUIContext());
  }

  /** Favorite play-all uses the existing app queue and shell intent dispatcher. */
  private playAllFavorites(): void {
    const queue: SongItem[] = [];
    const seed: number = Date.now();
    for (let i: number = 0; i < this.records.length; i++) {
      const record: PlayedSongRecord = this.records[i];
      if (record.songId.length === 0 || record.source.length === 0) {
        continue;
      }
      const item: SongItem = MusicStoreService.toSongItem(record);
      item.id = seed + i;
      queue.push(item);
    }
    if (queue.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '暂无可播放收藏歌曲' });
      return;
    }
    this.appState.replaceQueue(queue, 0);
    const intent: PlaybackIntentState = AppStorageV2.connect(PlaybackIntentState,
      AppStorageKeys.PLAYBACK_INTENT_STATE, (): PlaybackIntentState => new PlaybackIntentState())!;
    intent.pendingPlaySongId = -1;
    intent.pendingQueueIndex = 0;
    intent.openPlayerUi = true;
    intent.requestVersion++;
    hilog.info(0, 'RzdMinePlayback', 'favorite play-all rows=%{public}d queue=%{public}d',
      this.records.length, queue.length);
  }

  /** 多选 key。 */
  private songKeyOf(record: PlayedSongRecord): string {
    return record.source + '_' + record.songId;
  }

  private isSelected(record: PlayedSongRecord): boolean {
    return this.selectedMap[this.songKeyOf(record)] === true;
  }

  /** Toggles selection of one entry. */
  private toggleSelect(record: PlayedSongRecord, on: boolean): void {
    const next: Record<string, boolean> = {};
    const keys: string[] = Object.keys(this.selectedMap);
    for (let i: number = 0; i < keys.length; i++) {
      next[keys[i]] = this.selectedMap[keys[i]];
    }
    next[this.songKeyOf(record)] = on;
    this.selectedMap = next;
  }

  /** Selected keys. */
  private selectedIds(): string[] {
    const ids: string[] = [];
    const keys: string[] = Object.keys(this.selectedMap);
    for (let i: number = 0; i < keys.length; i++) {
      if (this.selectedMap[keys[i]] === true) {
        ids.push(keys[i]);
      }
    }
    return ids;
  }

  /** Count of selected entries. */
  private selectedCount(): number {
    return this.selectedIds().length;
  }

  /** Enters multi-select mode. */
  private enterSelectionMode(): void {
    this.selectionMode = true;
    this.selectedMap = {};
  }

  /** Exits multi-select mode and clears the selection. */
  private exitSelectionMode(): void {
    this.selectionMode = false;
    this.selectedMap = {};
  }

  /** Selects or clears all entries of the current segment. */
  private toggleSelectAll(): void {
    const next: Record<string, boolean> = {};
    const selectAll: boolean = this.selectedCount() < this.records.length;
    if (selectAll) {
      for (let i: number = 0; i < this.records.length; i++) {
        next[this.songKeyOf(this.records[i])] = true;
      }
    }
    this.selectedMap = next;
  }

  /** Deletes selected entries: history ids batch; favorites one by one. */
  private deleteSelected(): void {
    const ids: string[] = this.selectedIds();
    if (ids.length > 0) {
      if (this.recordSection === SECTION_HISTORY) {
        this.store.removeHistoryByIds(ids);
      } else {
        for (let i: number = 0; i < this.records.length; i++) {
          if (this.isSelected(this.records[i])) {
            this.store.removeFavorite(this.records[i].source, this.records[i].songId);
          }
        }
      }
    }
    this.exitSelectionMode();
  }

  /** Maps an LX source id to a short Chinese label for the history / favorite row. */
  private platformLabel(source: string | undefined): string {
    const src: string = source ?? '';
    return src.length > 0 ? sourceDisplayName(src) : '其他';
  }

  /** Returns a brand color per platform so the tag is recognizable.
   *  Matches the OnlineSearchPage SongRowItem sourceColor mapping exactly. */
  private platformColor(source: string | undefined): string {
    switch (source ?? '') {
      case 'kw': return '#FF6B35';
      case 'kg': return '#4A90D9';
      case 'tx': return '#31C27C';
      case 'wy': return '#C62F2F';
      case 'mg': return '#FF4081';
      default: return '#8C9095';
    }
  }

  /** Maps an LX quality id to a short Chinese label. */
  private qualityLabel(quality: string | undefined): string {
    const q: string = quality ?? '';
    switch (q) {
      case '128k': return '128k';
      case '320k': return '320k';
      case 'flac': return 'FLAC';
      case 'flac24bit': return 'Hi-Res';
      default: return q.length > 0 ? q : '—';
    }
  }

  /** Normalizes missing fields so rows never render `undefined`. */
  private normalizeRecords(list: PlayedSongRecord[]): PlayedSongRecord[] {
    for (let i: number = 0; i < list.length; i++) {
      const r: PlayedSongRecord = list[i];
      r.name = r.name ?? '';
      r.singer = r.singer ?? '';
      r.source = r.source ?? '';
      r.songId = r.songId ?? '';
      r.img = r.img ?? '';
      r.albumName = r.albumName ?? '';
      r.url = r.url ?? '';
      r.quality = r.quality ?? '';
      r.playScript = r.playScript ?? '';
    }
    return list;
  }

  /** Opens the artist / album detail page for a favorite entry. */
  private openFavoriteDetail(entry: FavoriteEntry, isAlbum: boolean): void {
    const code: number = sourceToCode(entry.source);
    if (isAlbum) {
      const param: AlbumRouteParam = new AlbumRouteParam();
      param.source = code;
      param.id = entry.id;
      param.name = entry.name;
      param.picUrl = entry.img;
      param.artistName = entry.sub;
      this.pageScroller.scrollEdge(Edge.Top);
      this.pageIndexInfos.pushPathByName(RouterUrlConstants.ALBUM_DETAIL, param);
      return;
    }
    const param: ArtistRouteParam = new ArtistRouteParam();
    param.source = code;
    param.id = entry.id;
    param.name = entry.name;
    param.picUrl = entry.img;
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.ARTIST_DETAIL, param);
  }

  // ─────────────────────────────── 版式：几何 ───────────────────────────────

  /** 左右安全边距（按断点，与其它页面同一档）。 */
  private contentPaddingSide(): number {
    return new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /**
   * 内容视口顶部要避让的高度（状态栏 + HDS 标题栏）。
   *
   * ⚠️ 分段标题已经搬进记录卡的卡头（照搬参考 `playlistCard()`），**不再**加原来那 48vp。
   */
  private titleTopInset(): number {
    return getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP;
  }

  /** 宽屏（平板 / 折叠展开 / PC 浮窗）：歌单卡与入口卡并排（照搬参考的宽屏排法）。 */
  private isWide(): boolean {
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
      this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_XL;
  }

  /** 平台音乐 / 下载管理两段的面板顶部留白（面板自己还会加一点）。 */
  private paneTopOffset(): number {
    return PANE_TOP_GAP;
  }

  /** 底部预留：HDS 浮动页签栏(56) + 页签栏间距(16) + 呼吸空间(16)。 */
  private bottomReservedVp(): number {
    return 56 + 16 + 16;
  }

  // ─────────────────────────────── 版式：卡片 ───────────────────────────────

  /**
   * ① 顶部账号卡。
   *
   * 直接复用本工程既有的 `HuaweiAccountCard`（用户明确要求它留在「我的」页顶部）：
   * 华为账号登录 / 退出、系统云空间备份恢复、旧云盘（网页）备份恢复都在里面，
   * 本页不做任何二次包装，避免两套账号入口。
   */
  @Builder
  private AccountCard() {
    Column() {
      HuaweiAccountCard({ showDivider: false })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 4, bottom: 4 })
    .borderRadius(R_CARD)
    .backgroundColor($r('app.color.card_background'))
    .clip(true)
  }

  /**
   * ② 快捷入口卡（照搬参考 `quickCard()`：一排平分，图标方块在上、名字与条数在下）。
   *
   * 参考用「淡红方块 + 红图形」（`C_RED_TINT` + `C_RED`）。我们没有那张淡底 token，
   * 用**强调色 12% 的方块 + 强调色图形**合成同一观感（`themeState.color` 会跟着
   * 用户选的强调色/深浅模式变）。
   */
  @Builder
  private QuickCard() {
    Row() {
      ForEach(this.quickEntries(), (entry: MineQuickEntry) => {
        Column({ space: 6 }) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(QUICK_ICON_BOX)
              .height(QUICK_ICON_BOX)
              .borderRadius(QUICK_ICON_RADIUS)
              .backgroundColor(this.themeState.color)
              .opacity(ACCENT_TINT_OPACITY)
            SymbolGlyph(entry.symbol)
              .fontSize(23)
              .fontColor([this.themeState.color])
          }
          .width(QUICK_ICON_BOX)
          .height(QUICK_ICON_BOX)

          Text(entry.label)
            .fontSize(F_SUB + 0.5)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (entry.section === SECTION_HISTORY || entry.section === SECTION_FAVORITE) {
            Text(String(this.countOfSection(entry.section)) + ' 首')
              .fontSize(11)
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
          }
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
          this.switchSection(entry.section);
        })
        .accessibilityText(this.quickA11y(entry))
        .accessibilityLevel('yes')
      }, (entry: MineQuickEntry) => 'mine_quick_' + entry.section)
    }
    .width('100%')
    .borderRadius(R_CARD)
    .backgroundColor($r('app.color.card_background'))
    .clip(true)
  }

  /**
   * ③ 歌单卡（照搬参考 `playlistCard()`：卡头 + 浅底动作区 + 歌单行）。
   *
   * 参考的卡头是「自建歌单 | 收藏歌单」两个标题 —— 我们**没有"收藏别人的在线歌单"**
   * 这个概念（本工程的"收藏"是收藏的**歌**，那是 ④ 卡里的一个分段），所以卡头左边
   * 只留「自建歌单 + 数量」，右端给一个「全部」进整页（= 原「歌单」页签的整页能力）。
   */
  @Builder
  private PlaylistCard() {
    Column() {
      // 卡头：标题 + 计数 + 右侧「全部」（照搬参考卡头的版式与高度）
      Row({ space: 6 }) {
        Text('自建歌单')
          .fontSize(F_SECTION)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(String(this.playlists.length))
          .fontSize(F_SUB)
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
        Text('全部')
          .fontSize(F_SUB)
          .fontColor(this.themeState.color)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([$r('sys.color.icon_tertiary')])
      }
      .width('100%')
      .height(CARD_HEADER_HEIGHT)
      .padding({ left: 14, right: 14 })
      .onClick(() => {
        this.pushMinePlaylist();
      })

      // 动作区（照搬参考：64 高、圆角 16、浅灰底，两格平分）
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

      if (this.playlists.length === 0) {
        Text('还没有歌单，点上面的「新建歌单」建一个，或者用「歌单导入」粘贴一张分享链接')
          .fontSize(F_SUB)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .padding({ left: 14, right: 14, top: 4, bottom: 18 })
          .textAlign(TextAlign.Start)
      } else {
        ForEach(this.playlistPreview(), (item: PlaylistDto, index: number) => {
          this.PlaylistRow(item, index > 0)
        }, (item: PlaylistDto) => 'mine_pl_' + item.id + '_' + item.songs.length + '_' + item.cover)
        if (this.playlists.length > PLAYLIST_PREVIEW_MAX) {
          Text(`查看全部 ${this.playlists.length} 张歌单`)
            .fontSize(F_SUB)
            .fontColor(this.themeState.color)
            .width('100%')
            .height(44)
            .padding({ left: 14, right: 14 })
            .textAlign(TextAlign.Start)
            .onClick(() => {
              this.pushMinePlaylist();
            })
        }
      }
    }
    .width('100%')
    .borderRadius(R_CARD)
    .backgroundColor($r('app.color.card_background'))
    .clip(true)
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
        if (item.cover.length > 0) {
          // 自定义封面是沙箱文件 URI，走 LocalCoverImage 用 fd 解码（真机 Image 直喂不显示）
          LocalCoverImage({
            src: item.cover,
            imageWidth: ROW_COVER,
            imageHeight: ROW_COVER,
            radius: R_COVER,
            fit: ImageFit.Cover
          })
        } else {
          // 歌单没有封面时用占位图形，**不用第一首歌的封面顶替**（见 PlaylistDto 的说明）
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

  /**
   * ④ 记录卡的卡头（**照搬参考 `playlistCard()` 的头部版式**：标题 + 计数 + `|` + 当前加粗）。
   *
   * 参考那张卡的头部是两个标题（自建歌单 | 收藏歌单），我们是四个分段
   * （播放历史 | 收藏 | 平台音乐 | 下载管理）—— 段标题从 HDS 标题栏的胶囊搬到这里，
   * 就是为了"把我们原有的四段融进照搬过来的版式里"。
   *
   * ⚠️ 计数只在「播放历史 / 收藏」这两段显示（2 与 4 两个分段的条数是别的东西，
   *    列出来反而误导），这也让这一行在 320vp 小屏上不会溢出。
   */
  @Builder
  private SegmentRow() {
    Row({ space: 5 }) {
      ForEach(this.segmentLabels, (label: string, index: number) => {
        Text(label)
          .fontSize(SEGMENT_TITLE_FONT)
          .fontWeight(this.recordSection === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.recordSection === index ? $r('sys.color.font_primary') :
            $r('sys.color.font_secondary'))
          .maxLines(1)
          .onClick(() => {
            this.switchSection(index);
          })
        if (index < this.segmentLabels.length - 1) {
          Text('|')
            .fontSize(SEGMENT_TITLE_FONT)
            .fontColor($r('app.color.comp_divider'))
        }
      }, (label: string) => 'mine_seg_' + label)
      Blank()
    }
    .width('100%')
    .height(CARD_HEADER_HEIGHT)
    .padding({ left: 14, right: 14 })
  }

  /** 记录卡的卡头（只有上面两个圆角：下面接的是记录行，同一个底色拼成一张卡）。 */
  @Builder
  private RecordsCardHeader() {
    Column() {
      this.SegmentRow()
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius({ topLeft: R_CARD, topRight: R_CARD })
    .clip(true)
  }

  /** 独立成卡的分段标题（平台音乐 / 下载管理两段固定在上方，四个圆角）。 */
  @Builder
  private SegmentCard() {
    Column() {
      this.SegmentRow()
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(R_CARD)
    .clip(true)
  }

  /** 记录卡的卡底（只有下面两个圆角），接在最后一行之后把这张卡收口。 */
  @Builder
  private RecordsCardBottom() {
    Column()
      .width('100%')
      .height(14)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius({ bottomLeft: R_CARD, bottomRight: R_CARD })
      .clip(true)
  }

  /** ⑤ 入口卡：设置 / 关于与帮助（照搬参考 `linksCard()`：行高 58、图标 22、右箭头、左缩进 50）。 */
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

  // ─────────────────────────────── 版式：记录卡内的行 ───────────────────────────────

  /** 多选模式操作条：全选 / 删除(n) / 取消。 */
  @Builder
  private SelectionBar() {
    Row({ space: 12 }) {
      Text(this.selectedCount() === this.records.length && this.records.length > 0 ? '取消全选' : '全选')
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('sys.color.background_primary'))
        .onClick(() => {
          this.toggleSelectAll();
        })
      Text(this.selectedCount() > 0 ? '删除(' + this.selectedCount() + ')' : '删除')
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedCount() > 0 ? $r('sys.color.font_on_primary') : $r('sys.color.font_tertiary'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor(this.selectedCount() > 0 ? this.themeState.color : '#1A000000')
        .onClick(() => {
          this.deleteSelected();
        })
      Text('取消')
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: 4, right: 4 })
        .onClick(() => {
          this.exitSelectionMode();
        })
      Blank()
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.card_background'))
  }

  /** 单条播放记录行（多选模式下带勾选框；行高与封面照搬参考的行规格）。 */
  @Builder
  private RecordRow(record: PlayedSongRecord, index: number) {
    Column() {
      if (index > 0) {
        Divider()
          .strokeWidth(0.6)
          .color($r('app.color.comp_divider'))
          .margin({ left: 72 })
      }
      Row({ space: 12 }) {
        if (this.selectionMode) {
          Toggle({ type: ToggleType.Checkbox, isOn: this.isSelected(record) })
            .width(24)
            .height(24)
            .selectedColor(this.themeState.color)
            .onChange((isOn: boolean) => {
              this.toggleSelect(record, isOn);
            })
        }
        if ((record.img ?? '').length > 0) {
          Image(record.img)
            .width(ROW_COVER)
            .height(ROW_COVER)
            .borderRadius(R_COVER)
            .objectFit(ImageFit.Cover)
        } else {
          Row() {
            SymbolGlyph($r('sys.symbol.music_note_list'))
              .fontSize(16)
              .fontColor([$r('sys.color.font_tertiary')])
          }
          .width(ROW_COVER)
          .height(ROW_COVER)
          .borderRadius(R_COVER)
          .backgroundColor($r('sys.color.background_tertiary'))
          .justifyContent(FlexAlign.Center)
        }
        Column({ space: 4 }) {
          Text(record.name)
            .fontSize(F_ITEM)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(((record.singer ?? '').length > 0 ? record.singer : ''))
            .fontSize(F_SUB)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (!this.selectionMode) {
          Column({ space: 4 }) {
            // 音质（与时长同色同字号；无 quality 时显示 "—"）
            Text(this.qualityLabel(record.quality))
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
            // 平台标签（与搜索 SongRowItem 位置/样式/颜色一致）
            Text(this.platformLabel(record.source))
              .fontSize($r('sys.float.Caption_S'))
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius($r('sys.float.corner_radius_level2'))
              .fontColor($r('sys.color.font_on_primary'))
              .backgroundColor(this.platformColor(record.source))
          }
          .alignItems(HorizontalAlign.Center)
          // ★ 右侧是**和其它界面一致的歌曲菜单**（`SongMoreMenu`：播放/下载/加歌单/加收藏/加队列）。
          //   历史与收藏两个分段共用这一行，所以两边同时生效。
          //   行本身仍然可点（点整行 = 播放），菜单按钮自己消费点击、不会连带触发播放。
          SongMoreMenu({
            song: {
              songId: record.songId, name: record.name, singer: record.singer,
              albumName: record.albumName, albumId: record.albumId, source: record.source,
              interval: record.interval, img: record.img, types: []
            },
            iconSize: 18,
            // 换源后立刻重建列表，保证平台标签/封面实时更新
            onSongSwitched: (): void => {
              this.forceReloadRecords();
            }
          })
        }
      }
      .width('100%')
      .height(LIST_ROW_HEIGHT)
      .padding({ left: 14, right: 14 })
      .onClick(() => {
        if (this.selectionMode) {
          this.toggleSelect(record, !this.isSelected(record));
          return;
        }
        this.playRecord(record);
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
  }

  /** 收藏分组的小标题（歌手 / 专辑 / 歌曲），同属记录卡。 */
  @Builder
  private FavoriteGroupHeader(title: string, count: number) {
    Row({ space: 8 }) {
      Text(title)
        .fontSize($r('sys.float.Subtitle_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(count > 0 ? String(count) : '')
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_tertiary'))
      Blank()
    }
    .width('100%')
    .height(40)
    .padding({ left: 14, right: 14 })
    .backgroundColor($r('app.color.card_background'))
  }

  /** One favorite artist / album row: cover, name, subtitle and a remove action. */
  @Builder
  private FavoriteEntryRow(entry: FavoriteEntry, isAlbum: boolean) {
    Row({ space: 12 }) {
      Image(entry.img.length > 0 ? entry.img : $r('app.media.ic_avatar1'))
        .width(52)
        .height(52)
        .borderRadius(isAlbum ? R_COVER : 26)
        .objectFit(ImageFit.Cover)
        .backgroundColor($r('app.color.card_background'))
      Column({ space: 4 }) {
        Text(entry.name)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(entry.sub.length > 0 ? entry.sub : (isAlbum ? '专辑' : '歌手'))
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .height(18)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .width('100%')
    .height(68)
    .padding({ left: 14, right: 14 })
    .backgroundColor($r('app.color.card_background'))
    .onClick(() => {
      this.openFavoriteDetail(entry, isAlbum);
    })
  }

  // ─────────────────────────────── HDS 标题栏 ───────────────────────────────

  /**
   * HDS 标题栏：大标题「我的」+ 依当前分段变化的动作钮。
   *
   * 分段胶囊**已搬进记录卡的卡头**（照搬参考 `playlistCard()` 的头部），所以这里不再挂
   * `bottomBuilder`。动作钮留在标题栏里是因为 HDS 的沉浸光感只在标题栏 / 底栏生效。
   */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    const menus: HdsNavigationMenuItemOptions[] = [];
    if (this.recordSection === SECTION_PLATFORM) {
      menus.push({
        content: {
          label: 'refresh',
          icon: $r('sys.symbol.arrow_clockwise'),
          isEnabled: true,
          action: (): void => {
            this.platformRefreshSignal++;
          }
        }
      });
    }
    if (this.recordSection === SECTION_FAVORITE && this.records.length > 0 && !this.selectionMode) {
      menus.push({
        content: {
          label: '播放全部',
          icon: $r('sys.symbol.play_fill'),
          isEnabled: true,
          action: (): void => {
            this.playAllFavorites();
          }
        }
      });
    }
    if ((this.recordSection === SECTION_HISTORY || this.recordSection === SECTION_FAVORITE) &&
      this.records.length > 0 && !this.selectionMode) {
      menus.push({
        content: {
          label: 'delete',
          icon: $r('sys.symbol.trash'),
          isEnabled: true,
          action: (): void => {
            this.enterSelectionMode();
          }
        }
      });
    }
    const bar: HdsNavigationTitleBarOptions = {
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
          mainTitle: $r('app.string.mine_title'),
          mainTitleSize: TitleSize.TITLE_ML
        },
        menu: {
          value: menus
        }
      }
    };
    return bar;
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

  // ─────────────────────────────── 版式：两个面板 ───────────────────────────────

  /**
   * 头部区（账号卡 → 快捷入口卡 → 歌单卡）。
   *
   * 宽屏把「歌单卡」与「入口卡」并排（照搬参考宽屏 2:1 的排法）；窄屏顺序照参考：
   * 快捷入口 → 歌单卡 → …（入口卡在窄屏落到整页最后，见 `RecordsPane`）。
   */
  @Builder
  private HeaderBlock() {
    Column({ space: 14 }) {
      // 顶部占位：第一张卡落在透明标题栏下方，但它跟着内容一起滚走
      // （用容器内边距会把这一段裁在标题栏下缘，看着像「被顶栏挡住」）
      Column()
        .height(this.titleTopInset() + 6)
        .width('100%')

      this.AccountCard()
      this.QuickCard()

      if (this.isWide()) {
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
        // 顶对齐：两张卡高度差得远，居中的话入口卡会飘在半空
        .alignItems(VerticalAlign.Top)
      } else {
        this.PlaylistCard()
      }
    }
    .width('100%')
    // ⚠️ `List` 用的是 `space: 0`（记录卡的行必须严丝合缝地拼成一张卡），所以头部这几张卡
    //    之间的间隔全靠这里的 `space: 14`，与下面那张记录卡之间的间隔靠这条 bottom 内边距。
    .padding({ bottom: 14 })
  }

  /** 平台音乐 / 下载管理这两段（各自是现成组件，不参与懒加载列表）。 */
  @Builder
  private SectionPane() {
    Column() {
      // 分段标题**固定**在上面（不参与滚动）：从这两段切回历史/收藏的唯一入口
      Column() {
        this.SegmentCard()
      }
      .width('100%')
      .padding({
        left: this.contentPaddingSide(),
        right: this.contentPaddingSide(),
        top: this.titleTopInset() + 6
      })

      Column() {
        if (this.recordSection === SECTION_PLATFORM) {
          PlatformMusicPage({
            onClose: (): void => {},
            refreshSignal: this.platformRefreshSignal,
            contentTopOffset: this.paneTopOffset(),
            pageScroller: this.pageScroller
          })
        } else {
          DownloadManagerSection({
            contentTopOffset: this.paneTopOffset(),
            pageScroller: this.pageScroller
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        left: this.contentPaddingSide(),
        right: this.contentPaddingSide(),
        bottom: this.bottomReservedVp()
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 历史 / 收藏分段：一张 `List` 里依次是
   * 头部三张卡 → 记录卡卡头 → （多选条）→ （收藏的歌手/专辑分组）→ 记录行 → 卡底 → 入口卡。
   *
   * ⚠️ 卡是**视觉上的**：卡头 / 行 / 卡底是相邻的 ListItem，靠同一底色 + 首尾圆角拼出来；
   *    记录行必须留在 List 的**直接子级**，`LazyForEach` 才是懒的（见文件头注释）。
   */
  @Builder
  private RecordsPane() {
    List({ space: 0, scroller: this.pageScroller }) {
      ListItem() {
        this.HeaderBlock()
      }

      ListItem() {
        this.RecordsCardHeader()
      }

      if (this.selectionMode) {
        ListItem() {
          this.SelectionBar()
        }
      }

      if (this.recordSection === SECTION_FAVORITE && this.favoriteArtists.length > 0) {
        ListItem() {
          this.FavoriteGroupHeader('歌手', this.favoriteArtists.length)
        }
        ForEach(this.favoriteArtists, (entry: FavoriteEntry) => {
          ListItem() {
            this.FavoriteEntryRow(entry, false)
          }
        }, (entry: FavoriteEntry) => 'fa_' + entry.source + '_' + entry.id)
      }
      if (this.recordSection === SECTION_FAVORITE && this.favoriteAlbums.length > 0) {
        ListItem() {
          this.FavoriteGroupHeader('专辑', this.favoriteAlbums.length)
        }
        ForEach(this.favoriteAlbums, (entry: FavoriteEntry) => {
          ListItem() {
            this.FavoriteEntryRow(entry, true)
          }
        }, (entry: FavoriteEntry) => 'fb_' + entry.source + '_' + entry.id)
      }
      if (this.recordSection === SECTION_FAVORITE && this.records.length > 0) {
        ListItem() {
          this.FavoriteGroupHeader('歌曲', this.records.length)
        }
      }

      // ★ 长列表用 LazyForEach + 稳定 key（数据源见 RecordDataSource）
      LazyForEach(this.recordSource, (record: PlayedSongRecord, index: number) => {
        ListItem() {
          this.RecordRow(record, index)
        }
      }, (record: PlayedSongRecord, index: number) => this.recordSource.keyOf(index))

      if (this.records.length === 0) {
        ListItem() {
          Text(this.recordSection === SECTION_HISTORY ? '暂无播放历史' : '暂无收藏歌曲')
            .fontSize($r('sys.float.Caption_L'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .height(72)
            .padding({ left: 14, right: 14 })
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.card_background'))
        }
      }

      // 记录卡的卡底
      ListItem() {
        this.RecordsCardBottom()
      }

      // 入口卡：窄屏放整页最后（宽屏已经并到头部那一排里去了）
      if (!this.isWide()) {
        ListItem() {
          Column({ space: 14 }) {
            this.LinksCard()
          }
          .width('100%')
          .padding({ top: 14 })
        }
      }

      ListItem() {
        Column()
          .height(this.bottomReservedVp())
          .width('100%')
      }
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
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
  }

  build() {
    if (this.localStackDepth > 0) {
      // ── 二级页形态：本页自带一个 Navigation，把二级页画在**本页之内** ──
      // 不写 `.hideTitleBar(true)`：Navigation 默认就带标题栏与返回箭头，这里正是它有用的时候
      // （用户从「我的」进设置 / 全部歌单后要能顺着箭头回来）。
      // 栈里那一格由**系统路由表**建出 NavDestination；navBar 那一份只是兜底，
      // Stack 模式下列表非空时它本来就不显示。
      Navigation(this.localStack) {
        Column() {
          if (this.localStackTopName() === RouterUrlConstants.MINE_PLAYLIST) {
            MinePlaylistPage()
          } else {
            MineSettingsPage()
          }
        }
        .width('100%')
        .height('100%')
      }
      .mode(NavigationMode.Stack)
      .hideToolBar(true)
      .onNavBarStateChange((_isVisible: boolean): void => {
        // push / pop 之后同步深度（pop 最常见：用户点了返回箭头或系统返回）。
        // ⚠️ `Navigation` 上**没有** `onBackPressed`（那是 NavDestination 的接口）——
        //    系统返回由 Navigation 自己弹出它的栈，这里只负责把渲染门同步回来。
        this.localStackDepth = this.localStack.size();
      })
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    } else {
      HdsNavDestination() {
        Stack({ alignContent: Alignment.TopStart }) {
          Column() {
            if (this.recordSection === SECTION_PLATFORM || this.recordSection === SECTION_DOWNLOAD) {
              this.SectionPane()
            } else {
              this.RecordsPane()
            }
          }
          .width('100%')
          .height('100%')

          // ⑥ 顶栏渐隐：卡片从透明标题栏底下穿过时靠近顶部淡出（照搬参考的 TopFade）
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
}
