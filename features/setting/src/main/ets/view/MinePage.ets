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
 * 版式照参考工程（lxmusic-harmony 的 MineView）重排成**卡片流**：
 *   ① 顶部账号卡（本工程既有的 `HuaweiAccountCard`，用户明确要求保留在「我的」页顶部）；
 *   ② 快捷入口卡（播放历史 / 收藏 / 下载管理 / 平台音乐 —— 一排平分，图标 + 名字 + 条数）；
 *   ③ 记录卡（原来的分段表：播放历史 / 收藏 / 平台音乐 / 下载管理，行样式不变）；
 *   ④ 入口卡（设置 → 二级页；关于 → 二级页）。
 *
 * 与改之前的区别只有一个：**搜索框与设置项分组列表不在本页了**，
 * 它们整体搬到二级页 `MineSettingsPage`（`RouterUrlConstants.MINE_SETTINGS`），
 * 由下面入口卡的「设置」推入。所以本页不再直接渲染任何设置项。
 *
 * ⚠️ 只用 V2 装饰器（`@ComponentV2` / `@Local` / `@Param` / `@Monitor` / `@Env`）；
 *    记录列表用 `LazyForEach` + 稳定 key（`source_songId`），不再整表重建。
 */

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { guardPlayerBack } from 'musicbasic';
import { PlaybackIntentState, SongItem } from 'musicbasic';
import {
  AlbumRouteParam, AmbientState, AppStorageKeys, ArtistRouteParam, BarScrollHelper, BreakpointType,
  FavoriteEntry, MusicAppState, MusicStoreService, PlayedSongRecord, RouterUrlConstants, ThemeState,
  TitleBarConstants, buildTitleMaterial, getStatusBarTopVpFromWindowUtil
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
import { CapsuleSegmentedSelector } from './CapsuleSegmentedSelector';
import { SettingsDetailRouteParam } from './SettingsDetailPage';
import { MineSettingsPage } from './MineSettingsPage';

/** 「我的」页快捷入口的四个分区下标（与 `segmentLabels` 一一对应）。 */
const SECTION_HISTORY: number = 0;
const SECTION_FAVORITE: number = 1;
const SECTION_PLATFORM: number = 2;
const SECTION_DOWNLOAD: number = 3;

/** 快捷入口卡的一格宽度（图标方块的边长，vp）。 */
const QUICK_ICON_BOX: number = 44;
/** 快捷入口卡的圆角。 */
const QUICK_ICON_RADIUS: number = 15;
/** 入口卡一行的行高。 */
const LINK_ROW_HEIGHT: number = 58;

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
 * Mine tab: the "我的" page.
 *
 * 账号卡 → 快捷入口卡 → 记录卡（播放历史 / 收藏 / 平台音乐 / 下载管理）→ 入口卡。
 * 设置项本体在二级页 `MineSettingsPage`（本页只留一个入口）。
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
  /** 标题栏分段按钮选项（SegmentButtonV2）。 */
  @Local segmentLabels: string[] = ['播放历史', '收藏', '平台音乐', '下载管理'];
  /** 当前分段的播放记录快照（历史 / 收藏共用；平台音乐与下载管理各走自己的组件）。 */
  @Local records: PlayedSongRecord[] = [];
  /** 记录列表的懒加载数据源（`@Local` 保证 `LazyForEach` 能拿到同一个实例）。 */
  @Local recordSource: RecordDataSource = new RecordDataSource();
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /**
   * 「我的 → 设置」二级页用的路由栈（**本页自带**，不走壳层的共享栈）。
   *
   * 为什么自带：共享栈上这一页是 `HdsNavDestination`，而二级页
   * `MineSettingsPage` 自己还要往同一个栈上推 `SettingsDetailPage`（两级嵌套
   * `HdsNavDestination`）；自带一个 `Navigation` 层级干净、返回路径单一，
   * 而且 `products/pc` 那种「壳层给的是 `HdsNavigation(new NavPathStack())`」
   * 也照样能用（往壳层那个空栈上推会静默失败，点了没反应）。
   *
   * 注意 `pageIndexInfos`（壳层共享栈）本页**仍在用**：收藏里的歌手/专辑详情
   * 走 `RouterUrlConstants.ARTIST_DETAIL` / `ALBUM_DETAIL`，与其它页面一致。
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
    this.localStackDepth = this.localStack.size();
  }

  /** 推进「我的 → 设置」二级页。 */
  private pushMineSettings(): void {
    this.pushOnLocalStack(RouterUrlConstants.MINE_SETTINGS, new Object());
  }

  /** 推设置详情页（「关于」这类直达项）。 */
  private pushSettingsDetail(param: SettingsDetailRouteParam): void {
    this.pushOnLocalStack(RouterUrlConstants.SETTINGS_DETAIL, param);
  }

  /**
   * push 进本页自带的路由栈，并刷新 `localStackDepth`。
   *
   * ★ 为什么「我的 → 设置」**有意不走壳层的共享栈**：共享栈上这一页就是
   *   `HdsNavDestination`，而二级页 `MineSettingsPage` 自己还要再往同一个栈上推
   *   `SettingsDetailPage`（两级 `HdsNavDestination` 嵌套）。本页自带一个 `Navigation`
   *   时层级干净、返回路径单一；`products/pc` 那种「壳层给的是 `HdsNavigation(new NavPathStack())`」
   *   也能用（往壳层那个空栈上推是静默失败，点了没反应）。
   *
   * `localStackDepth` 是**唯一的渲染门**：它一 >0 就把二级页画在本页之内
   * （`NavPathStack` 本身是可变对象，只 push 不改别的字段，ArkUI 不会因此重画）。
   */
  private pushOnLocalStack(name: string, param: Object): void {
    this.localStack.pushPathByName(name, param);
    this.localStackDepth = this.localStack.size();
  }

  /** 壳层点了当前页签：滚回顶部（底部页签设计规范）。 */
  @Monitor('scrollTopCommand')
  onScrollTopCommand(): void {
    this.pageScroller.scrollEdge(Edge.Top);
  }

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

  /** 快捷入口点了某个分区：切到那一段并回到顶部。 */
  private jumpToSection(section: number): void {
    this.recordSection = section;
    this.selectionMode = false;
    this.selectedMap = {};
    this.refreshRecords();
    this.pageScroller.scrollEdge(Edge.Top);
  }

  /** 快捷入口上显示的条数。 */
  private countOfSection(section: number): number {
    if (section === SECTION_HISTORY) {
      return this.historyCount;
    }
    if (section === SECTION_FAVORITE) {
      return this.favoriteCount;
    }
    return 0;
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

  /** 底部入口卡：设置（二级页）+ 关于（直达设置详情页）。 */
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

  // ---------------------------------------------------------------- 版式

  /**
   * 顶部账号卡。
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
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
  }

  /**
   * 快捷入口卡（照参考工程那一排：图标在上、名字与条数在下）。
   *
   * 四格平分宽度、不做横向滚动：只有四样，平分比「露出半截」好点。
   */
  @Builder
  private QuickCard() {
    Row() {
      ForEach(this.quickEntries(), (entry: MineQuickEntry) => {
        Column({ space: 6 }) {
          Row() {
            SymbolGlyph(entry.symbol)
              .fontSize(23)
              .fontColor([$r('sys.color.font_primary')])
          }
          .width(QUICK_ICON_BOX)
          .height(QUICK_ICON_BOX)
          .borderRadius(QUICK_ICON_RADIUS)
          .backgroundColor($r('sys.color.background_secondary'))
          .justifyContent(FlexAlign.Center)

          Text(entry.label)
            .fontSize($r('sys.float.Caption_L'))
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (entry.section === SECTION_HISTORY || entry.section === SECTION_FAVORITE) {
            Text(String(this.countOfSection(entry.section)) + ' 首')
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ top: 12, bottom: 12 })
        .borderRadius(14)
        .stateStyles({
          normal: { .backgroundColor(Color.Transparent) },
          pressed: { .backgroundColor($r('sys.color.background_secondary')) }
        })
        .onClick(() => {
          this.jumpToSection(entry.section);
        })
        .accessibilityText(entry.label + '，共 ' + this.countOfSection(entry.section) + ' 首')
        .accessibilityLevel('yes')
      }, (entry: MineQuickEntry) => 'mine_quick_' + entry.section)
    }
    .width('100%')
    .padding({ left: 6, right: 6 })
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
  }

  /** 入口卡：设置 / 关于与帮助。 */
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
              .fontSize($r('sys.float.Body_L'))
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
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
    .clip(true)
  }

  /** 列表头部：账号卡 + 快捷入口卡（跟着内容一起滚走）。 */
  @Builder
  private ListHeader() {
    Column({ space: 14 }) {
      this.AccountCard()
      this.QuickCard()
    }
    .width('100%')
    .padding({ top: this.sectionTopOffset(), bottom: 4 })
  }

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
    .padding({ top: 8, bottom: 8 })
  }

  /** 单条播放记录行（多选模式下带勾选框）。 */
  @Builder
  private RecordRow(record: PlayedSongRecord) {
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
          .width(40)
          .height(40)
          .borderRadius($r('sys.float.corner_radius_level3'))
          .objectFit(ImageFit.Cover)
      } else {
        Row() {
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(16)
            .fontColor([$r('sys.color.font_tertiary')])
        }
        .width(40)
        .height(40)
        .borderRadius($r('sys.float.corner_radius_level3'))
        .backgroundColor($r('sys.color.background_tertiary'))
        .justifyContent(FlexAlign.Center)
      }
      Column({ space: 2 }) {
        Text(record.name)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(((record.singer ?? '').length > 0 ? record.singer : ''))
          .fontSize($r('sys.float.Caption_M'))
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
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      if (this.selectionMode) {
        this.toggleSelect(record, !this.isSelected(record));
        return;
      }
      this.playRecord(record);
    })
  }

  /** Section header used by the three favorite groups (歌手 / 专辑 / 歌曲). */
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
    .padding({ left: 4, right: 4, top: 12, bottom: 6 })
  }

  /** One favorite artist / album row: cover, name, subtitle and a remove action. */
  @Builder
  private FavoriteEntryRow(entry: FavoriteEntry, isAlbum: boolean) {
    Row({ space: 12 }) {
      Image(entry.img.length > 0 ? entry.img : $r('app.media.ic_avatar1'))
        .width(52)
        .height(52)
        .borderRadius(isAlbum ? $r('sys.float.corner_radius_level3') : 26)
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
    .padding({ left: 4, right: 4 })
    .onClick(() => {
      this.openFavoriteDetail(entry, isAlbum);
    })
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

  /** HDS 标题栏第二行分段按钮：与设置页同款胶囊选择器。 */
  @Builder
  private SegmentBarBuilder() {
    Column() {
      CapsuleSegmentedSelector({
        labels: this.segmentLabels,
        selectedIndex: this.recordSection,
        accentColor: this.themeState.color,
        onSelect: (index: number): void => {
          this.recordSection = index;
          this.selectionMode = false;
          this.selectedMap = {};
          this.refreshRecords();
        }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
  }

  /** HDS title bar: same style as the playlists page; menu buttons follow the active segment. */
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
        },
        bottomBuilder: {
          builder: (): void => {
            this.SegmentBarBuilder()
          }
        }
      }
    };
    return bar;
  }

  /** 内容视口顶部要避让的高度（状态栏 + 标题栏 + 分段胶囊那一行）。 */
  private sectionTopOffset(): number {
    return getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP + 48;
  }

  /** 底部预留：HDS 浮动页签栏(56) + 页签栏间距(16) + 呼吸空间(16)。 */
  private bottomReservedVp(): number {
    return 56 + 16 + 16;
  }

  /** 平台音乐 / 下载管理这两个分段（各自是现成组件，不参与懒加载列表）。 */
  @Builder
  private SectionPane() {
    if (this.recordSection === SECTION_PLATFORM) {
      Column() {
        PlatformMusicPage({
          onClose: (): void => {},
          refreshSignal: this.platformRefreshSignal,
          contentTopOffset: this.sectionTopOffset(),
          pageScroller: this.pageScroller
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        left: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
        right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
        bottom: this.bottomReservedVp()
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else if (this.recordSection === SECTION_DOWNLOAD) {
      Column() {
        DownloadManagerSection({
          contentTopOffset: this.sectionTopOffset(),
          pageScroller: this.pageScroller
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        left: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
        right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
        bottom: this.bottomReservedVp()
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }

  /** 历史 / 收藏分段：列表头（账号卡 + 快捷入口卡）+ 记录行 + 入口卡。 */
  @Builder
  private RecordsPane() {
    List({ space: 2, scroller: this.pageScroller }) {
      ListItem() {
        this.ListHeader()
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
      if (this.recordSection === SECTION_FAVORITE) {
        ListItem() {
          this.FavoriteGroupHeader('歌曲', this.records.length)
        }
      }

      // ★ 长列表用 LazyForEach + 稳定 key（数据源见 RecordDataSource）
      LazyForEach(this.recordSource, (record: PlayedSongRecord) => {
        ListItem() {
          this.RecordRow(record)
        }
      }, (record: PlayedSongRecord, index: number) => this.recordSource.keyOf(index))

      if (this.records.length === 0) {
        ListItem() {
          Text(this.recordSection === SECTION_HISTORY ? '暂无播放历史' : '暂无收藏歌曲')
            .fontSize($r('sys.float.Caption_L'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .textAlign(TextAlign.Center)
        }
      }

      // 入口卡放在列表最后：设置项本体在二级页，这里只是一个入口
      ListItem() {
        Column({ space: 14 }) {
          this.LinksCard()
        }
        .width('100%')
        .padding({ top: 14 })
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
    .divider({
      strokeWidth: 0.5,
      color: $r('sys.color.comp_divider'),
      startMargin: 16,
      endMargin: 16
    })
    .padding({
      left: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
      right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint)
    })
  }

  build() {
    if (this.localStackDepth > 0) {
      // ── 二级页形态：本页自带一个 Navigation，把「我的 → 设置」二级页画在**本页之内** ──
      // 不写 `.hideTitleBar(true)`：Navigation 默认就带标题栏与返回箭头，这里正是它有用的时候
      // （用户从「我的」进设置后要能顺着箭头回来）。
      Navigation(this.localStack) {
        MineSettingsPage()
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
      .backgroundColor($r('sys.color.background_secondary'))
    } else {
      HdsNavDestination() {
        Stack() {
          if (this.recordSection === SECTION_PLATFORM || this.recordSection === SECTION_DOWNLOAD) {
            this.SectionPane()
          } else {
            this.RecordsPane()
          }
        }
        .width('100%')
        .height('100%')
      }
      .onBackPressed((): boolean => guardPlayerBack('MinePage'))
      .hideTitleBar(false)
      .hideBackButton(true)
      .titleBar(this.getTitleBar())
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .bindToScrollable([this.pageScroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor($r('sys.color.background_secondary'))
    }
  }
}
