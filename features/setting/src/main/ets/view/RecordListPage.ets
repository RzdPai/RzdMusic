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
 * 「我的」→「最近播放 / 收藏」二级页（**一页两模式**）。
 *
 * ★ 为什么是一页两模式（而不是两份列表页）：
 *   用户 2026-10-11 要求「我的」页**完全照搬**参考工程 lxmusic-harmony 的 `views/MineView.ets`。
 *   参考那一页的「最近播放 / 收藏」不是页内的分段胶囊，而是**各自一个子页面**
 *   （参考：`views/HistoryView.ets` + 内置收藏歌单详情）。我们这两个列表的数据、
 *   行版式、行菜单、多选删除**本来就是同一套代码**（原来都写在 `MinePage` 里），
 *   所以这里用同一份实现 + 一个 `mode` 参数，**没有第二份列表实现**。
 *
 * ★ 版式来源：参考工程的 `views/HistoryView.ets`（它自己把历史列表交给通用
 *   `SongListPane`）。**参考那个列表是"普通 List、行底透明"**（`SongListPane` 里
 *   `List() { ListItem() … }`，没有任何卡片底、没有圆角），所以本页照做：
 *   行直接落在**页面底色**上，`backgroundColor(Color.Transparent)`，**不做卡片**。
 *   行规格照我们原来那套（搬迁前 `MinePage.RecordRow()` 的版式）：行高 70 / 封面 46 圆角 14 /
 *   主标题 `F_ITEM=16.5` / 副标题 `F_SUB=12.5` / 行尾音质 + 平台标签 + `SongMoreMenu`；
 *   那几个数值与参考 `ui/Theme.ets` 的 `F_ITEM / F_SUB / R_COVER` 同档。
 *
 * ★ 数据来源**没有第二份**：仍由 `MusicStoreService`（唯一真源）提供，
 *   历史 = `getHistory()` / 收藏 = `getFavorites()` + 收藏的歌手 / 专辑
 *   （`getFavoriteArtists()` / `getFavoriteAlbums()`）；删除走 `removeHistoryByIds()` /
 *   `removeFavorite()`。本页只是它的视图适配器（`RecordDataSource` 那层懒加载）。
 *
 * ★ 长列表纪律：`List` + `LazyForEach` + 稳定 key（`recordSource.keyOfRecord(record)`，
 *   前缀区分历史 `h_` / 收藏 `f_`，带重建版本号）。**不要**把行塞进 Column 里
 *   —— `LazyForEach` 离开滚动容器就不再懒加载，几千条历史会全建节点（见全局记忆 §18.3）。
 *   **keyGenerator 只能用回调带进来的 item**，不能拿 index 反查数组（官方不保证调用顺序）。
 * ★ 行组件 `RecordRowItem` 必须是 **V2 复用组件**（`@ReusableV2 + @ComponentV2`）：
 *   本页是 `@ComponentV2`，官方混用矩阵里「V2 普通组件 + V1 复用组件」= 编译只告警、
 *   运行不创建 ⇒ 列表全空（2026-11-10 就是这么白屏的）。
 *
 * ★ 取色（用户明确：取色不能照搬参考工程 —— 我们有自定义主题色）：
 *   卡片 / 背景 / 分割线 / 正文与副标题文字走 `$r('app.color.*')` / `$r('sys.color.*')`（深浅自动适配）；
 *   选中态、勾选框、可点按钮走 `ThemeState.color`（**用户自定义的强调色**，`@Trace` 一改就重绘）；
 *   行尾那个**平台标签**是本工程既有实现里的**平台品牌色**（QQ / 酷狗 / 网易云…），是数据不是配色，保留。
 */

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { ConcertItem, ConcertService } from '../concert/ConcertService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  immersiveMedium,
  buildTitleMaterial,
   guardPlayerBack, PlaybackIntentState, SongItem
, immersiveFlat } from 'musicbasic';
import {
  AlbumRouteParam, AmbientState, AppStorageKeys, ArtistRouteParam, BreakpointType, barBlurOptions,
  buildBarBlurStyle, FavoriteEntry, LocateFloatButton,
  MusicAppState, MusicStoreService, NowPlayingIndicator, PageTopInsetHelper, PlayedSongRecord, PlaylistDto,
  RouterUrlConstants, SelectionActionCell,
  SongTitleMarquee, ThemeState, TitleBarConstants,
  getStatusBarTopVpFromWindowUtil, shouldUseSplitDetailLayout
} from 'musicbasic';
import {
  BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions,
  HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize
} from '@kit.UIDesignKit';
import { lxQualityLabel, OnlinePlayUtil, sourceDisplayName, sourceToCode } from 'player';
import { SongMoreMenu } from 'playlist';
import { displaySync } from '@kit.ArkGraphics2D';
import { RecordRowItem } from './RecordRowItem';

/** 「最近播放」模式。 */
export const RECORD_MODE_HISTORY: string = 'history';
/** 「收藏」模式。 */
export const RECORD_MODE_FAVORITES: string = 'favorites';
/**
 * 「关注」模式（用户 2026-10-20：我的页「下载管理」改成「关注」，收藏里的歌手提出来放这里）。
 *
 * 复用本页而不是新开一个路由页：歌手行、空状态、点击进歌手详情全都是本页已有的
 * `FavoriteEntryRow`，新开一页只会把这套代码抄第二遍。
 */
/** 关注页「近期演唱会」的一行：歌手 + 场次。 */
export interface UpcomingShow {
  artistName: string;
  artistId: string;
  source: string;
  item: ConcertItem;
}

export const RECORD_MODE_FOLLOWING: string = 'following';

/**
 * 路由参数（写法与 `SettingsDetailRouteParam` 一致：一个普通类，Builder 里读它的字段）。
 *
 * ⚠️ 字段名是 `mode`；`RecordListPage` 组件内的 `@Param` 也叫 `mode`。
 */
export class RecordListRouteParam {
  /** 'history' = 最近播放，'favorites' = 收藏（见 RECORD_MODE_*）。 */
  mode: string = RECORD_MODE_HISTORY;
}

// ─────────────── 照抄参考工程 `ui/Theme.ets` 的尺寸常量（数值照搬，颜色换成我们的 token） ───────────────

/** 列表封面圆角（参考 `R_COVER` 一档；我们的行用的是 14）。 */
const R_COVER: number = 14;
/** 列表主标题字号（参考 `F_ITEM`）。 */
const F_ITEM: number = 16.5;
/** 列表副标题字号（参考 `F_SUB`）。 */
const F_SUB: number = 12.5;
/** 行高（参考歌单 / 记录行的 70）。 */
const LIST_ROW_HEIGHT: number = 70;
/** 行内封面边长（参考的 46）。 */
const ROW_COVER: number = 46;

/** 日志域与标签（真机排查：`hdc shell hilog | findstr RzdRecordList`）。 */
const DOMAIN: number = 0x0000;
const TAG: string = 'RzdRecordList';

/**
 * 分帧装载：首帧只喂这么多行，其余按帧补（官方《高负载场景分帧渲染》「转场场景」）。
 *
 * 首帧的量 = 一屏可见行（高 800vp / 70vp ≈ 11 行）+ `cachedCount`（8 行）再留点余量 ⇒ 24。
 * 后续每帧 48 行：200 条历史 4 帧补完（120Hz 下约 33ms），用户感知不到，但转场首帧只处理 24 行。
 */
const FIRST_FRAME_ROWS: number = 24;
const FRAME_ROWS: number = 48;

/**
 * 记录（历史 / 收藏）列表的懒加载数据源。
 *
 * 数据本身仍由 `MusicStoreService` 持有（唯一真源），这个类只是它的视图适配器：
 * **任何数据变化都必须走 `applyRecords()`**，直接改数组不会触发刷新。
 */
class RecordDataSource implements IDataSource {
  private records: PlayedSongRecord[] = [];
  private listeners: DataChangeListener[] = [];
  /** 稳定 key 前缀：历史用 `h_`、收藏用 `f_`（跨模式不复用节点）。 */
  private prefix: string = 'h_';
  /** 强制重建版本号（换源后 key 全变，见 `RecordListPage.forceReloadRecords`）。 */
  private version: number = 0;

  public totalCount(): number {
    return this.records.length;
  }

  public getData(index: number): PlayedSongRecord {
    return this.records[index];
  }

  /** 稳定 key：同一首歌在历史 / 收藏里都不会因为插入删除而错位。 */
  public keyOf(index: number): string {
    const record: PlayedSongRecord = this.records[index];
    if (record === undefined) {
      return this.prefix + this.version + '#' + index;
    }
    return this.keyOfRecord(record);
  }

  /**
   * 直接按记录生成 key（`LazyForEach` 的 keyGenerator 用这个）。
   *
   * ⚠️ 官方《LazyForEach 使用限制》原文：「itemGenerator 函数的调用顺序不一定和数据源中的数据项
   *   相同，开发过程中不要假设 itemGenerator 和 keyGenerator 函数是否执行及其执行顺序」。
   *   所以 keyGenerator **不能拿 index 反查数组**（会错位/取到 undefined ⇒ 多行同 key ⇒ 少行甚至全空），
   *   只能用回调带进来的 item 本身算。
   */
  public keyOfRecord(record: PlayedSongRecord): string {
    if (record === undefined) {
      return this.prefix + this.version + '#';
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

  /**
   * 往尾部追加一批（分帧装载用）。
   *
   * 走 `onDataAdd` 而不是 `onDataReloaded`：官方《LazyForEach 数据更新》要求增量更新用
   * `onDataAdd`，这样框架只新建新增那几行，**已经建好的行不会重建**；
   * 而 `onDataReloaded` 会把已建节点全部丢掉重建 —— 分帧就白做了。
   */
  public appendRecords(next: PlayedSongRecord[], prefix: string, version: number): void {
    if (next.length === 0) {
      return;
    }
    const start: number = this.records.length;
    this.prefix = prefix;
    this.version = version;
    for (let i: number = 0; i < next.length; i++) {
      this.records.push(next[i]);
    }
    for (let l: number = 0; l < this.listeners.length; l++) {
      const listener: DataChangeListener = this.listeners[l];
      for (let i: number = 0; i < next.length; i++) {
        listener.onDataAdd(start + i);
      }
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
 * 最近播放 / 收藏（一页两模式）。
 *
 * 由「我的」页的快捷入口推进**壳层的共享栈**（`RouterUrlConstants.RECORD_LIST`），
 * 页内**不再自带 Navigation**：这样它整屏盖住底栏、底部的播放条由壳层那条官方浮动栏负责，
 * 系统返回手势也走壳层栈（见 `MinePage` 文件头那段说明）。
 */
@ComponentV2
export struct RecordListPage {
  /** 'history' = 最近播放，'favorites' = 收藏（由路由参数给，页面存活期间不变）。 */
  @Param mode: string = RECORD_MODE_HISTORY;
  /** Window breakpoint for the responsive horizontal padding. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /** 共享播放状态（记录行播放用）。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** 当前模式的记录快照（历史 / 收藏共用一份）。 */
  @Local records: PlayedSongRecord[] = [];
  /** 记录列表的懒加载数据源（`@Local` 保证 `LazyForEach` 能拿到同一个实例）。 */
  @Local recordSource: RecordDataSource = new RecordDataSource();
  /** 收藏模式下的「收藏的歌单 / 专辑」两组（历史模式恒为空）。 */
  @Local favoriteAlbums: FavoriteEntry[] = [];
  @Local favoritePlaylists: FavoriteEntry[] = [];
  /** 关注模式：关注（收藏）的歌手。 */
  @Local followingArtists: FavoriteEntry[] = [];
  /**
   * 分类页签（用户 2026-10-20 截图：Tab 在标题下方，选中项下面一条主题色短横线）。
   * - `song`    = 歌曲（历史 = 播放记录；收藏 = 收藏的歌曲）
   * - `playlist`= 歌单（历史 = 按**歌曲元信息里的歌单/专辑名**归组；收藏 = `getFavoritePlaylists()`）
   * - `album`   = 专辑（只有收藏有这一格）
   */
  @Local category: string = 'song';
  /** 多选删除模式。 */
  @Local selectionMode: boolean = false;
  /** 多选底栏「添加至歌单」的面板开关。 */
  @Local addSheetOpen: boolean = false;
  /** 多选勾选表（key = source_songId）。 */
  @Local selectedMap: Record<string, boolean> = {};
  /**
   * 列表重建版本号：只用于「切换平台」后强制重建所有行（key 里带上它），
   * 见 {@link forceReloadRecords}。
   */
  @Local recordsVersion: number = 0;
  /**
   * 本页是否在前台（`onShown` / `onHidden` 维护）。
   *
   * 只用来决定「后台要不要重建列表」，不参与 UI 绘制，所以走普通成员不占状态槽。
   * 配合 `pendingRefresh`：后台期间数据变了先记账，回到本页再一次性刷新。
   */
  private pageVisible: boolean = true;
  /** 后台期间被 @Monitor 拦下的刷新请求（回到本页时补做）。 */
  private pendingRefresh: boolean = false;
  /**
   * 分帧装载（官方《高负载场景分帧渲染》→「转场场景」）：
   * 转场动画首帧只加载一屏数据，其余在后续帧补，避免首帧被 200 行撑爆导致动画掉帧。
   */
  private pendingRecords: PlayedSongRecord[] = [];
  /** 下一帧要从哪儿开始补。 */
  private pendingNext: number = 0;
  private pendingPrefix: string = 'h_';
  private frameSync: displaySync.DisplaySync | undefined = undefined;
  /** 本机拿不到帧回调（极少数）时置 true，退化成一次性装载。 */
  private frameSyncUnavailable: boolean = false;
  /** 关注页顶部「近期演唱会」：{ 歌手名, 场次 }，拿不到就是空数组（卡片不显示） */
  @Local upcomingShows: UpcomingShow[] = [];
  /**
   * 页根（`HdsNavDestination`）在**窗口坐标**里的顶边 y（vp），由 `onAreaChange` 实测。
   *
   * 默认 0 = "页盒贴屏幕顶"（此前写死的假设）。量到非 0 后，内容让位（`titleTopInset()`）
   * 与标题栏的 `avoidLayoutSafeArea` 一起按它换算 ⇒ 标题与内容都不会整体下移一个状态栏。
   */
  @Local boxTopVp: number = 0;
  /**
   * 壳层的共享路由栈（「我的」页推本页用的就是它）。
   *
   * ⚠️ 本页**不自带** Navigation：返回箭头与系统返回都作用在壳层栈上（见文件头说明）。
   */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Scroller bound to the HDS title bar so the scroll effect (gradient blur) can fire. */
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'appear mode=%{public}s', this.mode);
    this.refreshRecords();
  }

  /**
   * 页面销毁时**必须**把 `selectionActive` 复位：否则用户在多选态直接返回上一页，
   * 壳层那条悬浮播放条会一直不显示（全局开关卡在 true）。
   */
  aboutToDisappear(): void {
    // 分帧还没补完就离开页面 ⇒ 必须停帧回调，否则它会一直跟着 vsync 跑
    this.stopFramePump();
    if (this.appState.selectionActive) {
      this.appState.selectionActive = false;
      hilog.info(DOMAIN, TAG, 'reset selectionActive on disappear');
    }
  }

  /** 历史 / 收藏在别处被改动（播放器、歌曲菜单…）时刷新列表。 */
  @Monitor('store.historyVersion', 'store.favoriteVersion')
  refreshRecords(): void {
    // ★ 2026-11-10（用户：这两个页面切页面卡）：页面被上层页面盖住时**不要**重建列表。
    //   播放器每切一首歌都会 `addHistory()` → `historyVersion++`，原实现会立刻重读+重建整表
    //   （`onDataReloaded()` 让 LazyForEach 丢掉已建节点）。等用户真的回到本页（`onShown`）再刷。
    if (!this.pageVisible) {
      this.pendingRefresh = true;
      return;
    }
    this.pendingRefresh = false;
    if (this.isFollowing()) {
      this.followingArtists = this.store.getFavoriteArtists();
      if (this.records.length > 0) {
        this.records = [];
      }
      if (this.favoriteAlbums.length > 0) {
        this.favoriteAlbums = [];
      }
      if (this.favoritePlaylists.length > 0) {
        this.favoritePlaylists = [];
      }
      void this.loadUpcomingShows();
    } else if (this.isHistory()) {
      this.records = this.normalizeRecords(this.store.getHistory());
      if (this.favoriteAlbums.length > 0) {
        this.favoriteAlbums = [];
      }
      if (this.favoritePlaylists.length > 0) {
        this.favoritePlaylists = [];
      }
    } else {
      this.records = this.normalizeRecords(this.store.getFavorites());
      this.favoriteAlbums = this.store.getFavoriteAlbums();
      this.favoritePlaylists = this.store.getFavoritePlaylists();
    }
    this.publishRecords();
  }

  /** 关注模式（关注/收藏的歌手列表）。 */
  private isFollowing(): boolean {
    return this.mode === RECORD_MODE_FOLLOWING;
  }

  /** 当前是不是「最近播放」模式。 */
  private isHistory(): boolean {
    return this.mode === RECORD_MODE_HISTORY;
  }

  /** 把当前 `records` 灌进懒加载数据源（**分帧**：首帧一屏，其余按帧补）。 */
  private publishRecords(): void {
    const prefix: string = this.isHistory() ? 'h_' : 'f_';
    this.stopFramePump();
    const total: number = this.records.length;
    const first: number = Math.min(total, FIRST_FRAME_ROWS);
    this.recordSource.applyRecords(this.records.slice(0, first), prefix, this.recordsVersion);
    this.pendingRecords = this.records;
    this.pendingPrefix = prefix;
    this.pendingNext = first;
    if (first < total) {
      hilog.info(DOMAIN, TAG, 'paged load total=%{public}d first=%{public}d', total, first);
      this.startFramePump();
    }
  }

  /** 开帧回调（displaySync，与屏幕 vsync 对齐；拿不到就退化成一帧装完）。 */
  private startFramePump(): void {
    if (this.frameSyncUnavailable || this.frameSync !== undefined) {
      return;
    }
    try {
      const sync: displaySync.DisplaySync = displaySync.create();
      sync.setExpectedFrameRateRange({ expected: 120, min: 60, max: 120 });
      sync.on('frame', (): void => {
        this.pumpOneFrame();
      });
      sync.start();
      this.frameSync = sync;
    } catch (err) {
      this.frameSyncUnavailable = true;
      hilog.warn(DOMAIN, TAG, 'frame pump unavailable: %{public}s', (err as Error).message);
      this.appendRemainingRecords();
    }
  }

  /** 每帧补一批（`onDataAdd` 增量，不重建已建行）。 */
  private pumpOneFrame(): void {
    const total: number = this.pendingRecords.length;
    if (this.pendingNext >= total) {
      this.stopFramePump();
      return;
    }
    const to: number = Math.min(total, this.pendingNext + FRAME_ROWS);
    this.recordSource.appendRecords(this.pendingRecords.slice(this.pendingNext, to),
      this.pendingPrefix, this.recordsVersion);
    this.pendingNext = to;
    if (this.pendingNext >= total) {
      this.stopFramePump();
    }
  }

  /** 兜底：没有帧回调时一次性补完。 */
  private appendRemainingRecords(): void {
    const total: number = this.pendingRecords.length;
    if (this.pendingNext < total) {
      this.recordSource.appendRecords(this.pendingRecords.slice(this.pendingNext, total),
        this.pendingPrefix, this.recordsVersion);
      this.pendingNext = total;
    }
  }

  private stopFramePump(): void {
    const sync: displaySync.DisplaySync | undefined = this.frameSync;
    this.frameSync = undefined;
    if (sync === undefined) {
      return;
    }
    try {
      sync.stop();
      sync.off('frame');
    } catch (_err) {
      // 已经停了就算了
    }
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
    this.recordsVersion++;
    this.refreshRecords();
  }

  // ─────────────────────────────── 记录：播放 / 多选 / 删除 ───────────────────────────────

  /** 播放一条历史 / 收藏记录（复用在线播放编排）。 */
  private playRecord(record: PlayedSongRecord): void {
    void OnlinePlayUtil.playRecord(this.appState, record, this.getUIContext());
  }

  /** 「播放全部」：整队交给壳层的播放意图分发器（不自己推播放页）。历史/收藏共用。 */
  private playAllRecords(): void {
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
      this.getUIContext().getPromptAction().showToast({ message: '暂无可播放歌曲' });
      return;
    }
    this.appState.replaceQueue(queue, 0);
    const intent: PlaybackIntentState = AppStorageV2.connect(PlaybackIntentState,
      AppStorageKeys.PLAYBACK_INTENT_STATE, (): PlaybackIntentState => new PlaybackIntentState())!;
    intent.pendingPlaySongId = -1;
    intent.pendingQueueIndex = 0;
    intent.openPlayerUi = true;
    intent.requestVersion++;
    hilog.info(DOMAIN, TAG, 'play-all rows=%{public}d queue=%{public}d', this.records.length, queue.length);
  }

  /** 收藏模式的「播放全部」：与 {@link playAllRecords} 同一条路（保留名字给标题栏菜单用）。 */
  private playAllFavorites(): void {
    this.playAllRecords();
  }

  /**
   * 历史模式的「歌单」分组：按**歌曲元信息里的歌单/专辑名**（`PlayedSongRecord.albumName`）归组。
   *
   * 用户 2026-10-20 明确：「历史页第二格歌单 = 歌曲元信息中的歌单」。存储里没有"播放过的歌单"
   * 记录，所以这一格是把历史里的歌按它们自带的歌单/专辑名聚成组，**不新增任何埋点**。
   * 组按"最近一次播放时间"倒序，组内保持历史原有顺序。
   */
  private historyPlaylistGroups(): FavoriteEntry[] {
    const out: FavoriteEntry[] = [];
    const indexByName: Map<string, number> = new Map<string, number>();
    for (let i: number = 0; i < this.records.length; i++) {
      const record: PlayedSongRecord = this.records[i];
      const groupName: string = (record.albumName ?? '').length > 0 ? record.albumName : '未知歌单';
      const hit: number | undefined = indexByName.get(groupName);
      if (hit === undefined) {
        const entry: FavoriteEntry = new FavoriteEntry();
        entry.id = groupName;
        entry.name = groupName;
        entry.source = record.source;
        entry.img = record.img ?? '';
        entry.count = 1;
        entry.time = record.time;
        entry.sub = record.singer ?? '';
        indexByName.set(groupName, out.length);
        out.push(entry);
      } else {
        const exist: FavoriteEntry = out[hit];
        exist.count = exist.count + 1;
      }
    }
    hilog.info(DOMAIN, TAG, 'history groups rows=%{public}d groups=%{public}d',
      this.records.length, out.length);
    return out;
  }

  /** 当前分类下要显示的分组条目（历史 = 按元信息歌单聚组；收藏 = 收藏的歌单/专辑）。 */
  private categoryEntries(): FavoriteEntry[] {
    if (this.category === 'playlist') {
      return this.isHistory() ? this.historyPlaylistGroups() : this.favoritePlaylists;
    }
    if (this.category === 'album') {
      return this.isHistory() ? [] : this.favoriteAlbums;
    }
    return [];
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

  /**
   * 这一行是不是**当前正在播放**的那首（用户 2026-10-19：歌名变色 + 动态竖条）。
   *
   * 判定口径与播放队列一致：`source + songId`；本地歌（`source='local'`）用 songId 直接比。
   * @param record 列表行记录
   * @returns 是否当前播放
   */
  private isCurrentRecord(record: PlayedSongRecord): boolean {
    // ★ 2026-11-04：同 `PlaylistDetailSongListSection.isCurrentSong` —— 换源后身份被改写，
    //   纯比对会丢掉"正在播放"高亮；统一走 `isCurrentRowIdentity()`（多认换源前的原始身份）。
    return this.appState.isCurrentRowIdentity(record.source, record.songId);
  }

  /** 当前播放那首在本列表里的下标（找不到 -1）。 */
  private currentRecordIndex(): number {
    for (let i: number = 0; i < this.records.length; i++) {
      if (this.isCurrentRecord(this.records[i])) {
        return i;
      }
    }
    return -1;
  }

  /**
   * 定位到当前播放：把列滚动到那首歌（用户 2026-10-19：「加个定位到当前播放」）。
   *
   * ⚠️「智感握姿」在 HarmonyOS 里**没有对三方应用开放**（SDK 只有 HDS 自己的
   * `adaptToHandedness`，那是给 HDS 底栏用的，不能拿来给自绘按钮用），所以这里做成
   * **贴右下角的浮动圆按钮**：拇指自然落点，且不挡列表内容。
   */
  private locateCurrent(): void {
    // 分帧还没补完时先把剩余数据补进去，否则 `scrollToIndex` 会越界（数据源里只有前 24 条）
    this.appendRemainingRecords();
    this.stopFramePump();
    const index: number = this.currentRecordIndex();
    if (index < 0) {
      this.getUIContext().getPromptAction().showToast({ message: '当前没有正在播放的歌曲', duration: 1600 });
      return;
    }
    this.pageScroller.scrollToIndex(index, true, ScrollAlign.CENTER);
    hilog.info(DOMAIN, TAG, 'locate current index=%{public}d', index);
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
    // ★ 用户 2026-10-19：让壳层把二级页那条悬浮播放条**临时隐藏**（底部要放多选操作条）
    this.appState.selectionActive = true;
  }

  /** Exits multi-select mode and clears the selection. */
  private exitSelectionMode(): void {
    this.selectionMode = false;
    this.selectedMap = {};
    this.appState.selectionActive = false;
  }

  /** Selects or clears all entries of the current mode. */
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
      if (this.isHistory()) {
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

  /**
   * 行尾平台标签的品牌色。
   *
   * ⚠️ 这是**平台品牌色**（数据标识，与 QQ / 酷狗 / 网易云一致），不是页面配色，
   *    所以保留在本工程既有实现里的字面量；页面配色一律走我们的 token（见文件头）。
   *    映射与 `OnlineSearchPage` 的 `SongRowItem.sourceColor` 逐条一致。
   */
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

  /**
   * LX 音质 id → 短标签。
   * ★ 2026-11-14：不再自带一份对照表，统一取 `lxQualityLabel()`（唯一一份）。
   *   旧表把 `flac24bit` 标成「Hi-Res」，而权威表里 `Hi-Res` 是 `hires`、
   *   `flac24bit` 是「24Bit」—— 同档位两个名字且标错了。
   */
  private qualityLabel(quality: string | undefined): string {
    const q: string = quality ?? '';
    return q.length > 0 ? lxQualityLabel(q) : '—';
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

  /** Opens the artist / album detail page for a favorite entry（走壳层共享栈）。 */
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
    // ★ 收藏时存下来的可能是 mid（部分音源 `effectiveArtistId` 为空时会回退到 mid），
    //   这里两个字段都带上，歌手页才能正确解析（此前只带 id ⇒ 从关注页进来 0 首歌/0 张专辑）。
    param.mid = entry.id;
    param.name = entry.name;
    param.picUrl = entry.img;
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.ARTIST_DETAIL, param);
  }

  // ─────────────────────────────── 版式：几何 ───────────────────────────────

  /** 左右安全边距（按断点，与其它页面同一档）。 */
  private contentPaddingSide(): number {
    // ★ 用户 2026-10-11：「历史页、收藏页列表离屏幕两端距离太大了」⇒ 收紧一档
    //   （原 16/24/32/32 → 8/12/16/16）。行内的 14vp 是行自身内边距，卡片/行会贴着这条间距。
    return new BreakpointType(8, 12, 16, 16).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /**
   * 内容顶部要避让的高度 = **状态栏 + HDS 标题栏**（38 + 56）。
   *
   * ★ 2026-10-11 口径（问过用户，两次）：**页面要"延伸进状态栏"** ——
   *   内容（列表）滚上去时一直能画到屏幕最顶端（状态栏那一条也归页面），
   *   所以**不能**把状态栏高度加到"容器"的 padding 上（那样列表视口从状态栏下沿开始，
   *   状态栏那一条就永远是一段死背景，用户明确说不要）。
   *   正确做法是把这个偏移**放进滚动内容里**（下面那个 `Blank()`），
   *   于是：静止时第一行正好在标题栏下沿，往上滚则整行从标题栏底下、再穿到状态栏里。
   *   根节点的 `expandSafeArea([SYSTEM],[TOP,BOTTOM])` 继续负责把页面底色也铺满整屏。
   */
  private titleTopInset(): number {
    // ⚠️ 不再假设页盒从窗口 y=0 起排：由 `boxTopVp`（页根 `onAreaChange` 实测）换算，
    //    盒顶 0 → 94、盒顶 38 → 56，两种情形内容都落在窗口的 94 那条线上（`PageTopInsetHelper`）。
    return PageTopInsetHelper.contentOffsetVp(this.boxTopVp);
  }

  /** 底部预留：壳层那条官方浮动播放条(56) + 间距(16) + 呼吸空间(16)。 */
  private bottomReservedVp(): number {
    // 多选时播放条已临时隐藏（见 MusicAppState.selectionActive），改为给底部操作条让位
    return 56 + 16 + 16 + (this.selectionMode ? 76 : 0);
  }

  // ─────────────────────────────── 版式：列表 ───────────────────────────────

  /**
   * 分类页签（用户 2026-10-20 截图）：文字页签，选中项 = `font_primary` + 下方一条
   * **主题色短横线**；未选中 = `font_secondary`。历史只有 歌曲/歌单 两格（截图里就是两格）。
   *
   * ★ 2026-10-20 第二轮（用户：「Tab 和播放全部按钮**固定在顶部**」）：从列表内容里搬出来，
   *   现在是页面顶部固定头的一部分（见 `build()`），不再跟着列表滚。
   */
  @Builder
  private CategoryTabs() {
    Row({ space: 0 }) {
      this.CategoryTab('歌曲', 'song')
      this.CategoryTab('歌单', 'playlist')
      if (!this.isHistory()) {
        this.CategoryTab('专辑', 'album')
      }
      Blank()
    }
    .width('100%')
    .height(46)
    .padding({ left: 6 })
    .alignItems(VerticalAlign.Center)
  }

  /** 单个页签（文字 + 选中下划线）。 */
  @Builder
  private CategoryTab(label: string, key: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(this.category === key ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.category === key ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
      Row()
        .width(this.category === key ? 18 : 0)
        .height(2.5)
        .borderRadius(1.25)
        .backgroundColor(this.themeState.color)
        .animation({ duration: 160, curve: Curve.Friction })
    }
    .height(46)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 10, right: 10 })
    .onClick((): void => {
      if (this.category !== key) {
        this.category = key;
        hilog.info(DOMAIN, TAG, 'category=%{public}s', key);
      }
    })
  }

  /**
   * 「播放全部 N」行（用户 2026-10-20：「参考歌单页的，圆形按钮太难看」）。
   *
   * 与 `PlaylistDetailSongListSection.PlayAllHeader()` **逐项对齐**：
   * `sys.symbol.play_round_triangle_fill` 32vp 描边三角（**没有圆形底**）+「播放全部」+ 首数。
   */
  @Builder
  private PlayAllRow() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
        .fontSize(32)
        .fontWeight(FontWeight.Regular)
        .height(32)
        .fontColor([$r('sys.color.font_primary')])
      Text('播放全部')
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .lineHeight(24)
        .fontColor($r('sys.color.font_primary'))
      Text(`${this.records.length}`)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .lineHeight(24)
        .fontColor($r('sys.color.font_primary'))
      Blank()
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.playAllRecords();
    })
  }

  /**
   * 多选底栏（用户 2026-10-19：全选/删除/取消 那一排改成**HDS 底栏那种操作条**）。
   *
   * 参照用户给的参考图：底部是一条悬浮胶囊，里面是「删除 / 添加至歌单 / 取消收藏」三格
   * （图标 + 小字）。「全选」上移到标题栏右侧（见 getTitleBar）。
   * 多选期间壳层那条悬浮播放条会被 `MusicAppState.selectionActive` 临时隐藏，所以两者不叠。
   *
   * ★★ 2026-10-19 第二轮（用户：「颜色不对，不能是蓝色」「要接入光感」）：
   *   原来整条 `backgroundColor(sys.color.background_emphasize)` = 一坨蓝。
   *   现在改成 **HDS 风格材质背板 + 光感**：
   *   - 背板：`backgroundBlurStyle(buildBarBlurStyle(档位), barBlurOptions())` ——
   *     `adaptiveColor = AVERAGE` 才会"取背后画面平均色"，底下的画面换色它跟着换；
   *   - ⚠️ 2026-10-20（用户：「接入的是**沉浸光感**，不是发光，把这堆发光删了」）：
   *     原来这里还挂了 `hdsEffect` 点光（每格按下发亮 + 条子本体受光），**已全部删除**；
   *   - 颜色：删除用**用户自定义主题色**，其余文字用 `font_primary`（不再有写死的蓝）。
   *
   * 多选底部操作条（光感版）：与本地音乐页同一套做法 —— 放进空 `Tabs` 壳的 tabBar 槽，材质才生效；
   * 壳宽收敛、无阴影（详见项目记忆 §202）。
   */
  @Builder
  private SelectionActionBar() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        Column().width(0).height(0)
      }
      .tabBar(this.SelectionActionSlot())
    }
    .barHeight(66)
    .barWidth(300)
    .barBackgroundColor(Color.Transparent)
    .barBackgroundBlurStyle(BlurStyle.NONE)
    .width(300)
    .height(66)
    .align(Alignment.Center)
  }

  /** 槽内胶囊本体（材质挂这里才生效）。 */
  @Builder
  private SelectionActionSlot() {
      Row() {
      SelectionActionCell({
        icon: $r('sys.symbol.trash'),
        label: this.selectedCount() > 0 ? '删除(' + this.selectedCount() + ')' : '删除',
        tint: this.themeState.color,
        onTap: (): void => {
          this.deleteSelected();
        }
      })
      SelectionActionCell({
        icon: $r('sys.symbol.plus'),
        label: '添加至歌单',
        tint: $r('sys.color.font_primary'),
        onTap: (): void => {
          this.addSheetOpen = true;
        }
      })

      SelectionActionCell({
        icon: $r('sys.symbol.xmark'),
        label: '取消',
        tint: $r('sys.color.font_primary'),
        onTap: (): void => {
          this.exitSelectionMode();
        }
      })
      }
    // ★ 恢复最初那版（用户确认当时正常）：Row + borderRadius(33) + systemMaterial。
    //   不要再包 Button、也不要叠 backgroundColor/backgroundBlurStyle —— 都会让药丸变方或变色。
    .width('100%')
    .height(66)
    .borderRadius(33)
    .systemMaterial(immersiveFlat())
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }


  /** 把选中的歌一次性加进某个本地歌单（多选底栏「添加至歌单」）。 */
  private addSelectedToPlaylist(playlistId: string): void {
    let added: number = 0;
    for (let i: number = 0; i < this.records.length; i++) {
      if (this.isSelected(this.records[i])) {
        if (this.store.addSongToPlaylist(playlistId, this.records[i])) {
          added++;
        }
      }
    }
    this.addSheetOpen = false;
    this.getUIContext().getPromptAction().showToast({ message: '已添加 ' + added + ' 首', duration: 1800 });
    this.exitSelectionMode();
  }

    /** 「添加至歌单」选择面板：列出本地歌单。 */
  @Builder
  private AddToPlaylistSheet() {
    Column({ space: 8 }) {
      Text('添加到歌单')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .padding({ left: 4, bottom: 4 })
      List({ space: 4 }) {
        ForEach(this.store.getPlaylists(), (p: PlaylistDto) => {
          ListItem() {
            Row() {
              Text(p.name)
                .fontSize(15)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              Text(p.songs.length + ' 首')
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
            }
            .width('100%')
            .height(52)
            .padding({ left: 14, right: 14 })
            .borderRadius(14)
            .backgroundColor($r('sys.color.background_primary'))
            .onClick(() => {
              this.addSelectedToPlaylist(p.id);
            })
          }
        }, (p: PlaylistDto) => 'atl_' + p.id)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /** 收藏分组的小标题（歌手 / 专辑 / 歌曲）。 */
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
    .backgroundColor(Color.Transparent)
  }

  /** One favorite artist / album row: cover, name, subtitle and a chevron. */
  @Builder
  private FavoriteEntryRow(entry: FavoriteEntry, isAlbum: boolean) {
    Row({ space: 12 }) {
      Image(entry.img.length > 0 ? entry.img : $r('app.media.ic_avatar1'))
        .width(52)
        .height(52)
        .borderRadius(isAlbum ? R_COVER : 26)
        .objectFit(ImageFit.Cover)
        // 图没到位时的占位底（走 token，深浅色自动适配）
        .backgroundColor($r('sys.color.background_tertiary'))
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
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.openFavoriteDetail(entry, isAlbum);
    })
  }

  // ─────────────────────────────── HDS 标题栏 ───────────────────────────────

  /** HDS 标题栏：大标题（最近播放 / 我的收藏）+ 播放全部 / 多选删除 / 返回。 */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    const menus: HdsNavigationMenuItemOptions[] = [];
    if (this.selectionMode) {
      // ★ 用户 2026-10-19：多选时「全选」放标题栏右侧（参照参考图），底部只留操作按钮
      const allSelected: boolean = this.selectedCount() === this.records.length && this.records.length > 0;
      menus.push({
        content: {
          label: allSelected ? '取消全选' : '全选',
          icon: allSelected ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.checkmark_circle'),
          isEnabled: true,
          action: (): void => {
            this.toggleSelectAll();
          }
        }
      });
    }
    // ★ 2026-10-29（用户）：收藏页列表里已经有「播放全部 N」横条了，
    //   标题栏再放一个「播放全部」是重复，这里删掉（保留横条那一处入口）。
    if (this.records.length > 0 && !this.selectionMode) {
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
      // ★ 盒顶实测贴屏幕顶（0）时才让 HDS 标题栏自己退回状态栏下方；盒顶已在状态栏下沿时
      //   不能再退（否则标题掉到 38+38，用户报的「历史/收藏页标题下移」）。
      avoidLayoutSafeArea: PageTopInsetHelper.avoidLayoutSafeArea(this.boxTopVp),
      // ★★ 2026-10-20（用户：「历史页收藏页上方不要**渐变模糊**了，直接一块大黑板就行了」）：
      //   去掉 `scrollEffectOpts: IMMERSIVE_GRADIENT_BLUR`（那玩意是滚动渐变的模糊托底），
      //   也去掉 `systemMaterialEffect`，背景直接给**页面底色**（深浅色自动适配 = 深色下就是一块黑板）。
      style: {
        // ★ 用户 2026-10-29 澄清：**只有「关注」页**要模糊/光感标题栏；
        //   历史 / 收藏 页因为头部还压着「播放全部」横条，黑色背板才是对的（保持原样）。
        //   关注页对齐「设置页 / 平台音乐页」：开模糊 + 渐变模糊 + 透明底 + 标题栏材质。
        systemMaterialEffect: this.isFollowing() ? buildTitleMaterial(this.ambientState.level) : undefined,
        blurStrategy: this.isFollowing() ? BlurStrategy.ENABLE : BlurStrategy.DISABLE,
        scrollEffectOpts: this.isFollowing() ? {
          // ★ 与设置页 / 搜索页一致：HDS 自带「沉浸渐变模糊」（枚举来自 @kit.UIDesignKit，
          //   不是 ArkUI navigation 里那个 GRADUAL_BLUR）。
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        } : undefined,
        originalStyle: {
          backgroundStyle: {
            backgroundColor: this.isFollowing()
              ? Color.Transparent
              : $r('app.color.background_secondary')
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            backIconStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: this.isFollowing()
              ? Color.Transparent
              : $r('app.color.background_secondary')
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            backIconStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        }
      },
      content: {
        title: {
          // ★ 多选时标题显示「已选中 N 项」（参照用户给的参考图）
          mainTitle: this.selectionMode ? ('已选中 ' + this.selectedCount() + ' 项') :
            (this.isFollowing() ? '关注' :
              (this.isHistory() ? $r('app.string.mine_history_title') : $r('app.string.mine_favorites_title'))),
          mainTitleSize: TitleSize.TITLE_ML
        },
        backIcon: {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true,
          action: (): void => {
            // ★ 多选时返回键先退出多选，否则才弹壳层共享栈（本页不自带 Navigation）
            if (this.selectionMode) {
              this.exitSelectionMode();
              return;
            }
            this.pageIndexInfos.pop();
          }
        },
        menu: {
          value: menus
        }
      }
    };
    return bar;
  }

  /**
   * @returns 宽屏（平板 / 阔屏 / **手机横屏**）用多列列表（历史、收藏两页共用本页）。
   *
   * 甲方 2026-10-24：「回响页…历史页、收藏页…都适配一下其它比例（平板、阔屏、横屏等）」。
   * 本页没有封面 hero（历史/收藏都是 70vp 的行），所以宽屏只做**列数**，不做左卡。
   */
  private isWideRecordLayout(): boolean {
    return shouldUseSplitDetailLayout(this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint);
  }

  /**
   * 宽屏多列的 `Grid.columnsTemplate`：XL 三列、其余（含手机横屏）两列。
   *
   * ⚠️ 原来这里返回的是列数，给 `List.lanes(count, 16)` 用 —— 那条属性会让 List 丢懒加载，
   *   已改成 Grid 的模板字符串（见 build 里 SongGrid 的注释）。
   */
  private wideRecordColumns(): string {
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_XL ? '1fr 1fr 1fr' : '1fr 1fr';
  }

  /**
   * 关注页顶部「近期演唱会」：取前 6 位关注歌手的最近场次（每位最多 2 场，总数 ≤ 6）。
   * 任何一位拿不到都不影响其它位；全空则整块卡片不显示。
   * 日志：`RzdConcert`
   */
  /** 关注页顶部卡片：近期演唱会（歌手 + 时间 + 场馆）。 */
  @Builder
  private UpcomingConcertsCard() {
    Button() {
      Column({ space: 10 }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.auditorium'))
          .fontSize(15)
          .fontColor([$r('sys.color.font_primary')])
        Text('近期演唱会')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      .width('100%')

      ForEach(this.upcomingShows, (show: UpcomingShow) => {
        Row({ space: 10 }) {
          Column({ space: 3 }) {
            Text(show.artistName + (show.item.venueName.length > 0 ? (' · ' + show.item.venueName) : ''))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              // 超长跑马灯
              .textOverflow({ overflow: TextOverflow.MARQUEE })
              .marqueeOptions({ start: true, step: 6 })
            Text(show.item.whenText + (show.item.city.length > 0 ? (' · ' + show.item.city) : ''))
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
              .marqueeOptions({ start: true, step: 6 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
      }, (show: UpcomingShow) => show.item.id)
    }
    .alignItems(HorizontalAlign.Start)
    }
    .type(ButtonType.Normal)
    .systemMaterial(immersiveMedium())
    .backgroundColor('#33FFFFFF')
    .width('100%')
    .padding(14)
    .borderRadius(16)
  }

  private async loadUpcomingShows(): Promise<void> {
    const out: UpcomingShow[] = [];
    const limit: number = Math.min(this.followingArtists.length, 6);
    for (let i: number = 0; i < limit; i++) {
      const entry: FavoriteEntry = this.followingArtists[i];
      if (entry.name.length === 0) {
        continue;
      }
      const list: ConcertItem[] = await ConcertService.getInstance().upcoming(entry.name);
      const take: number = Math.min(list.length, 2);
      for (let k: number = 0; k < take; k++) {
        out.push({ artistName: entry.name, artistId: entry.id, source: entry.source, item: list[k] });
      }
      if (out.length >= 6) {
        break;
      }
    }
    out.sort((a: UpcomingShow, b: UpcomingShow): number => a.item.startISO.localeCompare(b.item.startISO));
    this.upcomingShows = out;
    console.info('[RzdConcert] following card count=' + out.length);
  }

  build() {
    HdsNavDestination() {
      Column() {
        // ★★ 用户 2026-10-20：「历史收藏那几个 Tab 和播放全部按钮**固定在顶部**」。
        //   所以从列表内容里搬出来，做成页面顶部的固定头（不跟列表滚）。
        //   头里第一段是让开"状态栏 + 标题栏"的空高（`titleTopInset()`）。
        //   ★ 底色用**材质背板**（不是死底色）：`adaptiveColor = AVERAGE` ⇒ 取列表滚过去时的
        //     背后画面色，这才有光感（与标题栏 `buildTitleMaterial` 同一档）。
        // ★ 关注页：头部整块不占位（高度 0），让列表**滚到标题栏下面**，
        //   这样标题栏的 `GRADUAL_BLUR` 才有内容可糊（对齐平台音乐页的渐变模糊）。
        //   历史/收藏页保持不变（那里有「播放全部」横条，黑板才是对的）。
        Column() {
          Column()
            .height(this.isFollowing() ? 0 : this.titleTopInset())
            .width('100%')
          if (!this.selectionMode && !this.isFollowing()) {
            this.CategoryTabs()
            this.PlayAllRow()
          }
        }
        .width('100%')
        .backgroundBlurStyle(
          this.isFollowing() ? BlurStyle.NONE : buildBarBlurStyle(this.ambientState.level),
          barBlurOptions())

        Stack({ alignContent: Alignment.TopStart }) {
          // ★★ 2026-11-10「切页面卡」的真正修法：**容器分离**。
          //   ① 官方《LazyForEach 使用限制》原文：「容器组件内只能包含一个 LazyForEach。以 List 为例，
          //      **不建议同时包含 ListItem、ForEach、LazyForEach**」—— 原实现把关注页/歌单页的
          //      ForEach、空态与底部占位的 ListItem、歌曲的 LazyForEach 全塞在同一个 List 里。
          //   ② 原来还挂着 `.lanes(...)`：List 一旦进入多列布局模式，懒加载就退化成**全量创建**
          //      （同样 200 条数据，滚动不卡是因为节点早建完了，卡的是"进入页面的那一帧"）。
          //   现在按数据量分流：
          //      · 关注 / 歌单 / 专辑 —— 数据少，`List + ForEach`，保留 `contentStartOffset` 等 List 专有能力；
          //      · 历史 / 收藏的歌曲 —— 长列表，`Grid + LazyForEach`，多列用 `columnsTemplate`
          //        （**绝不能用 List.lanes**），首帧只建可视区 + cachedCount。
          if (this.isFollowing() || this.category !== 'song') {
          List({ space: 0, scroller: this.pageScroller }) {

          // ★ 关注模式（用户 2026-10-20）：只列关注的歌手，点进歌手详情
          if (this.isFollowing()) {
            // ★ 顶部「近期演唱会」卡片（拿不到就整块不显示）
            if (this.upcomingShows.length > 0) {
              ListItem() {
                // 左右留白放在这里（不能给卡片本体加 margin：Button 宽度已是 100%，会溢出到屏幕外）
                Column() {
                  this.UpcomingConcertsCard()
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 10, bottom: 6 })
              }
            }
            ForEach(this.followingArtists, (entry: FavoriteEntry) => {
              ListItem() {
                this.FavoriteEntryRow(entry, false)
              }
            }, (entry: FavoriteEntry) => 'flw_' + entry.source + '_' + entry.id)
            if (this.followingArtists.length === 0) {
              ListItem() {
                Text('还没有关注任何歌手（在歌手页点「关注」）')
                  .fontSize($r('sys.float.Caption_L'))
                  .fontColor($r('sys.color.font_tertiary'))
                  .width('100%')
                  .height(96)
                  .padding({ left: 14, right: 14 })
                  .textAlign(TextAlign.Center)
              }
            }
          }

          // ★ 用户 2026-10-20（6b）：收藏里的**歌手**已独立成「关注」页，这一组从本页移除。
          if (!this.isFollowing() && (this.category === 'playlist' || this.category === 'album')) {
            ForEach(this.categoryEntries(), (entry: FavoriteEntry) => {
              ListItem() {
                this.FavoriteEntryRow(entry, this.category === 'album')
              }
            }, (entry: FavoriteEntry) => 'cat_' + this.category + '_' + entry.source + '_' + entry.id)
            if (this.categoryEntries().length === 0) {
              ListItem() {
                Text(this.category === 'album' ? '暂无收藏专辑' : '暂无歌单')
                  .fontSize($r('sys.float.Caption_L'))
                  .fontColor($r('sys.color.font_tertiary'))
                  .width('100%')
                  .height(72)
                  .textAlign(TextAlign.Center)
              }
            }
          }

          // ★ 2026-10-29（用户：收藏页「歌曲 17」删掉 → 随后又说历史页的也删掉）：
          //   两个模式的歌曲列表都不再插这行分组标题（`FavoriteGroupHeader` 保留定义，当前无人调用）。
          // ★ 多选操作条已移到**底部**（见 build 里的 SelectionActionBar），列表内不再插入。
          // ★ 歌曲列表**不在这里**：为了保住懒加载，它单独走下面的 `Grid + LazyForEach`
          //   （本 List 只服务关注 / 歌单 / 专辑三个短列表，纯 `ForEach`，符合官方「一个容器只放一种渲染方式」）。

          ListItem() {
            Column()
              .height(this.bottomReservedVp())
              .width('100%')
          }
        }
        .width('100%')
        .height('100%')
        // ★ 关注页：列表自带**顶部预留**（contentStartOffset），而不是在列表外面加占位 Column。
        //   这样静止时首行不会被标题栏压住；一旦上滑，内容就滚到标题栏底下，
        //   HDS 标题栏自带的渐变模糊（GRADUAL_BLUR）才会显形 —— 与「平台音乐」页同一机制。
        .contentStartOffset(this.isFollowing() ? this.titleTopInset() : 0)
        // ⚠️ 这里**绝对不能**再写 `.lanes(...)`：List 一旦进多列布局模式，懒加载会退化为
        //   全量创建（200 条历史 = 转场首帧建 200 行）。宽屏多列交给下面 Grid 的 columnsTemplate。
        // 官方长列表优化：预缓存可视区外的节点，避免滚动时反复创建/销毁行组件
        // （每行含跑马灯、播放指示竖条、SongMoreMenu 等重组件）。
        .cachedCount(8)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        // ★★ 让内容能画进状态栏（"延伸进状态栏"）的**官方正解**。
        //   官方《开发应用沉浸式效果》→「滚动类场景」原文：
        //     「滚动容器设置 expandSafeArea 属性生效，但当父组件是滚动容器时，子组件设置 expandSafeArea
        //      不生效。对于滚动容器的子组件……② 设置父组件滚动容器和子组件相同的背景色，
        //      设置滚动容器的内容裁剪属性 `clipContent(ContentClipMode.SAFE_AREA)`，
        //      **将内容层裁剪区域扩展至避让区**。」
        //   原来这里写的是 `.clip(true)`（= 裁到 padding 内侧的内容矩形）⇒ 行一滚到状态栏就被裁掉，
        //   所以"偏移放哪都没用"。换成 SAFE_AREA 后裁剪区含避让区，行才能一路画到屏幕最顶端。
        //   ⚠️ 链上任何祖先都**不能**再写 `clip(true)`（官方："需要确保父组件未设置 clip 等裁剪属性"）。
        .clipContent(ContentClipMode.SAFE_AREA)
        .padding({
          left: this.contentPaddingSide(),
          right: this.contentPaddingSide()
        })
        }

        // ★★ 历史 / 收藏的歌曲列表：`Grid + LazyForEach`。
        //   为什么不是 List：List 的 `lanes` 一设就丢懒加载；而 `columnsTemplate` 不会。
        //   为什么不是和上面共用 List：官方「一个容器只放一种渲染方式」，混放会把整个容器拉回全量创建。
        //   首帧只建「可视区 + cachedCount 行」，200 条历史不再一次性全建。
        if (!this.isFollowing() && this.category === 'song') {
          Grid(this.pageScroller) {
            LazyForEach(this.recordSource, (record: PlayedSongRecord, index: number) => {
              GridItem() {
                // @ReusableV2 行组件（V2 体系）：滑出屏幕进复用池，滑回来只更新 @Param 不重建子树
                RecordRowItem({
                  record: record,
                  rowIndex: index,
                  selectionMode: this.selectionMode,
                  selected: this.isSelected(record),
                  isCurrent: this.isCurrentRecord(record),
                  playing: this.appState.isPlay,
                  accent: this.themeState.color,
                  qualityText: this.qualityLabel(record.quality),
                  platformText: this.platformLabel(record.source),
                  platformTint: this.platformColor(record.source),
                  onTapRow: (row: PlayedSongRecord): void => {
                    this.playRecord(row);
                  },
                  onToggleRow: (row: PlayedSongRecord, on: boolean): void => {
                    this.toggleSelect(row, on);
                  },
                  onSongSwitched: (): void => {
                    this.forceReloadRecords();
                  }
                })
              }
              // Grid 的 item 必须有确定高度，父容器才能算出行数 → 懒加载才成立
              .height(LIST_ROW_HEIGHT)
            }, (record: PlayedSongRecord) => this.recordSource.keyOfRecord(record))
          }
          .width('100%')
          .height('100%')
          // 宽屏多列：XL 三列、其余两列；窄屏单列（等价于原来的 lanes，但不破坏懒加载）
          .columnsTemplate(this.isWideRecordLayout() ? this.wideRecordColumns() : '1fr')
          .columnsGap(this.isWideRecordLayout() ? 16 : 0)
          .rowsGap(0)
          .cachedCount(this.isWideRecordLayout() ? 6 : 8)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .clipContent(ContentClipMode.SAFE_AREA)
          .padding({
            left: this.contentPaddingSide(),
            right: this.contentPaddingSide(),
            // Grid 没有 List 的「底部占位 ListItem」，底部让位（浮动播放条）用 padding 给
            bottom: this.bottomReservedVp()
          })
        }

        // 歌曲模式的空态放容器外面：塞进 Grid 会破坏「容器里只有 LazyForEach」这条纪律。
        if (!this.isFollowing() && this.category === 'song' && this.records.length === 0) {
          Text(this.isHistory() ? '暂无播放历史' : '暂无收藏歌曲')
            .fontSize($r('sys.float.Caption_L'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .height(72)
            .padding({ left: 14, right: 14 })
            .textAlign(TextAlign.Center)
            .margin({ top: this.titleTopInset() })
        }


        // ★ 用户 2026-10-19：多选时底部放一条**HDS 风格操作条**（删除 / 添加至歌单 / 取消收藏 / 取消）；
        //   同一时刻壳层那条悬浮播放条会被 `selectionActive` 隐藏，两者不重叠。
        if (this.selectionMode) {
          Column() {
            this.SelectionActionBar()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.End)
          .padding({ left: 16, right: 16, bottom: 28 })
          .hitTestBehavior(HitTestMode.Transparent)
        } else if (!this.isFollowing() && (!this.isHistory() || this.records.length > 0)) {
          // ★ 定位到当前播放（用户 2026-10-19 第二轮：图标换成本播放列表那颗、缩小、
          //   去掉蓝底、加智感握姿 ⇒ 统一用 musicbasic 的 `LocateFloatButton`，
          //   与播放器播放列表里的定位按钮同一个 SVG，见该组件头部注释）
          LocateFloatButton({
            tint: this.themeState.color,
            // ★ 2026-11-01（用户：定位歌曲按钮位置调高）：原来 bottomInset 用默认 96，贴着底部；
            //   历史/收藏页底部还有一行内边距，抬到 150 让它明显离开底边。
            bottomInset: 150,
            clickable: this.currentRecordIndex() >= 0,
            onTap: (): void => {
              this.locateCurrent();
            }
          })
        }
      }
      .width('100%')
      // ★ 列表占满"固定头"以下的剩余高度（原来这里是页根，给的是 height('100%')）
      .layoutWeight(1)
      // ★ 这里**不加** `padding({ top: 状态栏 })`：那会让列表视口从状态栏下沿起排，
      //   状态栏那一条变死背景 —— 用户要的是"**延伸进状态栏**"（见 `titleTopInset()` 说明）。
      //   让开状态栏 + 标题栏的空高现在由**固定头**里那段 `titleTopInset()` 给。
      }
      .width('100%')
      .height('100%')
    }
    .onBackPressed((): boolean => {
      // ★ 多选态返回 = 先退出多选（与底栏「取消」同义），不要一下子把整页弹掉
      if (this.selectionMode) {
        this.exitSelectionMode();
        return true;
      }
      return guardPlayerBack('RecordListPage');
    })
    // ★ 2026-11-10：后台期间挂起刷新（见 `refreshRecords` 头部），回到本页补做一次。
    //   没有这两条时，播放器每切一首歌都会在**看不见的本页**上重建 200 条的列表。
    .onShown((): void => {
      this.pageVisible = true;
      if (this.pendingRefresh) {
        this.refreshRecords();
      }
    })
    .onHidden((): void => {
      this.pageVisible = false;
    })
    .hideTitleBar(false)
    .hideBackButton(false)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    // ★★ 状态栏三件套（2026-10-11 定稿，用户第三次纠正后）：
    //   ① `expandSafeArea(TOP,BOTTOM)`：把**页面底色**铺到状态栏/导航条那两条（只扩绘制区）；
    //   ② `ignoreLayoutSafeArea(...[TOP, BOTTOM])` —— **TOP 必须给**：
    //      HDS 的标题栏自己会按"状态栏高度"往下让位，所以**页面盒子必须从屏幕 y=0 起排**，
    //      否则就是"盒子已经让开状态栏(38) + 标题栏再让一次(38)" ⇒ 整条标题掉到
    //      状态栏下面约一个状态栏高度（用户原话：「整个标题移到了状态栏下面」），
    //      连带内容也多顶下去 38vp（「上方留的空距有点大了」）。
    //      盒子从 0 起排后：标题栏 = 38..94 ✔，内容偏移 94（= 状态栏 + 标题栏）落在 94 ✔。
    //   ③ 滚动容器 `clipContent(ContentClipMode.SAFE_AREA)`：让行能**画进**状态栏那一条（"延伸进状态栏"）。
    // ★★ 用户 2026-10-11：「顶栏标题错位的问题还在，你应该参考一下其他显示正常的页面是怎么写的」。
    //   逐页对比后：显示正常的 MinePage / RecommendPage **都没有** expandSafeArea，
    //   而所有标题偏低的页面都有 ⇒ 照正常页面去掉它。页面底色由页盒自身 backgroundColor 铺满。
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    // ★ 实测页盒顶边（窗口坐标 vp）：内容让位与标题栏 `avoidLayoutSafeArea` 都由它推出来，
    //   不再假设盒顶 = 0。只在变化超过 0.5vp 时写状态，避免与布局互相追。
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const top: number = newArea.globalPosition.y as number;
      if (Math.abs(top - this.boxTopVp) > 0.5) {
        this.boxTopVp = top;
        hilog.info(DOMAIN, TAG, 'RzdPageTopInset boxTopVp=%{public}f page=record offset=%{public}f avoid=%{public}s',
          top, PageTopInsetHelper.contentOffsetVp(top),
          String(PageTopInsetHelper.avoidLayoutSafeArea(top)));
      }
    })
    .backgroundColor($r('app.color.background_secondary'))
    // 多选底栏「添加至歌单」面板
    .bindSheet(this.addSheetOpen, this.AddToPlaylistSheet(), {
      height: 420,
      dragBar: true,
      showClose: true,
      onDisappear: (): void => {
        this.addSheetOpen = false;
      }
    })
  }
}

/** 路由表里注册的 Builder（`features/setting` 的 router_map.json）。 */
@Builder
export function RecordListPageBuilder(name: string, param: Object) {
  RecordListPage({ mode: (param as RecordListRouteParam | undefined)?.mode ?? RECORD_MODE_HISTORY })
}
