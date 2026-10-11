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
 * ★ 长列表纪律：`List` + `LazyForEach` + 稳定 key（`recordSource.keyOf(index)`，
 *   前缀区分历史 `h_` / 收藏 `f_`，带重建版本号）。**不要**把行塞进 Column 里
 *   —— `LazyForEach` 离开滚动容器就不再懒加载，几千条历史会全建节点（见全局记忆 §18.3）。
 *
 * ★ 取色（用户明确：取色不能照搬参考工程 —— 我们有自定义主题色）：
 *   卡片 / 背景 / 分割线 / 正文与副标题文字走 `$r('app.color.*')` / `$r('sys.color.*')`（深浅自动适配）；
 *   选中态、勾选框、可点按钮走 `ThemeState.color`（**用户自定义的强调色**，`@Trace` 一改就重绘）；
 *   行尾那个**平台标签**是本工程既有实现里的**平台品牌色**（QQ / 酷狗 / 网易云…），是数据不是配色，保留。
 */

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { guardPlayerBack, PlaybackIntentState, SongItem } from 'musicbasic';
import {
  AlbumRouteParam, AmbientState, AppStorageKeys, ArtistRouteParam, BreakpointType, FavoriteEntry,
  MusicAppState, MusicStoreService, PlayedSongRecord, RouterUrlConstants, ThemeState, TitleBarConstants,
  buildTitleMaterial, getStatusBarTopVpFromWindowUtil
} from 'musicbasic';
import {
  BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions,
  HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize
} from '@kit.UIDesignKit';
import { OnlinePlayUtil, sourceDisplayName, sourceToCode } from 'player';
import { SongMoreMenu } from 'playlist';
import { MineTopFade } from './MineWidgets';

/** 「最近播放」模式。 */
export const RECORD_MODE_HISTORY: string = 'history';
/** 「收藏」模式。 */
export const RECORD_MODE_FAVORITES: string = 'favorites';

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
  /** 收藏模式下的「收藏的歌手 / 专辑」两组（历史模式恒为空）。 */
  @Local favoriteArtists: FavoriteEntry[] = [];
  @Local favoriteAlbums: FavoriteEntry[] = [];
  /** 多选删除模式。 */
  @Local selectionMode: boolean = false;
  /** 多选勾选表（key = source_songId）。 */
  @Local selectedMap: Record<string, boolean> = {};
  /**
   * 列表重建版本号：只用于「切换平台」后强制重建所有行（key 里带上它），
   * 见 {@link forceReloadRecords}。
   */
  @Local recordsVersion: number = 0;
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

  /** 历史 / 收藏在别处被改动（播放器、歌曲菜单…）时刷新列表。 */
  @Monitor('store.historyVersion', 'store.favoriteVersion')
  refreshRecords(): void {
    if (this.isHistory()) {
      this.records = this.normalizeRecords(this.store.getHistory());
      this.favoriteArtists = [];
      this.favoriteAlbums = [];
    } else {
      this.records = this.normalizeRecords(this.store.getFavorites());
      this.favoriteArtists = this.store.getFavoriteArtists();
      this.favoriteAlbums = this.store.getFavoriteAlbums();
    }
    this.publishRecords();
  }

  /** 当前是不是「最近播放」模式。 */
  private isHistory(): boolean {
    return this.mode === RECORD_MODE_HISTORY;
  }

  /** 把当前 `records` 灌进懒加载数据源（**数据变化后必须调它**）。 */
  private publishRecords(): void {
    const prefix: string = this.isHistory() ? 'h_' : 'f_';
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

  // ─────────────────────────────── 记录：播放 / 多选 / 删除 ───────────────────────────────

  /** 播放一条历史 / 收藏记录（复用在线播放编排）。 */
  private playRecord(record: PlayedSongRecord): void {
    void OnlinePlayUtil.playRecord(this.appState, record, this.getUIContext());
  }

  /** 收藏模式的「播放全部」：整队交给壳层的播放意图分发器（不自己推播放页）。 */
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
    hilog.info(DOMAIN, TAG, 'favorite play-all rows=%{public}d queue=%{public}d',
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
    return getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP;
  }

  /** 底部预留：壳层那条官方浮动播放条(56) + 间距(16) + 呼吸空间(16)。 */
  private bottomReservedVp(): number {
    return 56 + 16 + 16;
  }

  // ─────────────────────────────── 版式：列表 ───────────────────────────────

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
        // 可用时是**用户自定义的强调色**；不可用时退回中性底（原来是写死的 10% 黑）
        .backgroundColor(this.selectedCount() > 0 ? this.themeState.color : $r('sys.color.background_tertiary'))
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
    .backgroundColor(Color.Transparent)
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
            // 平台标签（与搜索 SongRowItem 位置/样式/颜色一致；品牌色是数据）
            Text(this.platformLabel(record.source))
              .fontSize($r('sys.float.Caption_S'))
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius($r('sys.float.corner_radius_level2'))
              .fontColor($r('sys.color.font_on_primary'))
              .backgroundColor(this.platformColor(record.source))
          }
          .alignItems(HorizontalAlign.Center)
          // ★ 右侧是**和其它界面一致的歌曲菜单**（`SongMoreMenu`：播放/下载/加歌单/加收藏/加队列）。
          //   历史与收藏两个模式共用这一行，所以两边同时生效。
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
    // 行底**透明**（= 页面底色）：参考工程的 HistoryView 用的就是普通 `List`（`SongListPane`
    // 里没有任何卡片底），不是"一张张卡" —— 照搬参考就不该给它加卡面
    .backgroundColor(Color.Transparent)
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
    if (!this.isHistory() && this.records.length > 0 && !this.selectionMode) {
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
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        title: {
          mainTitle: this.isHistory() ? $r('app.string.mine_history_title') : $r('app.string.mine_favorites_title'),
          mainTitleSize: TitleSize.TITLE_ML
        },
        backIcon: {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true,
          action: (): void => {
            // 返回 = 弹壳层共享栈（本页不自带 Navigation）
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

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        List({ space: 0, scroller: this.pageScroller }) {
          // 顶部占位：第一行落在透明标题栏下方，但它跟着列表一起滚走
          ListItem() {
            Column()
              .height(this.titleTopInset() + 6)
              .width('100%')
          }

          if (!this.isHistory() && this.favoriteArtists.length > 0) {
            ListItem() {
              this.FavoriteGroupHeader('歌手', this.favoriteArtists.length)
            }
            ForEach(this.favoriteArtists, (entry: FavoriteEntry) => {
              ListItem() {
                this.FavoriteEntryRow(entry, false)
              }
            }, (entry: FavoriteEntry) => 'rla_' + entry.source + '_' + entry.id)
          }
          if (!this.isHistory() && this.favoriteAlbums.length > 0) {
            ListItem() {
              this.FavoriteGroupHeader('专辑', this.favoriteAlbums.length)
            }
            ForEach(this.favoriteAlbums, (entry: FavoriteEntry) => {
              ListItem() {
                this.FavoriteEntryRow(entry, true)
              }
            }, (entry: FavoriteEntry) => 'rlb_' + entry.source + '_' + entry.id)
          }
          if (!this.isHistory() && this.records.length > 0) {
            ListItem() {
              this.FavoriteGroupHeader('歌曲', this.records.length)
            }
          }

          if (this.selectionMode) {
            ListItem() {
              this.SelectionBar()
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
              Text(this.isHistory() ? '暂无播放历史' : '暂无收藏歌曲')
                .fontSize($r('sys.float.Caption_L'))
                .fontColor($r('sys.color.font_tertiary'))
                .width('100%')
                .height(72)
                .padding({ left: 14, right: 14 })
                .textAlign(TextAlign.Center)
            }
          }

          ListItem() {
            Column()
              .height(this.bottomReservedVp())
              .width('100%')
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .clip(true)
        .padding({
          left: this.contentPaddingSide(),
          right: this.contentPaddingSide()
        })

        // 顶栏渐隐：行从透明标题栏底下穿过时靠近顶部淡出（与「我的」页同一个件）
        MineTopFade({ fadeHeight: this.titleTopInset() + 10 })
      }
      .width('100%')
      .height('100%')
      // ★ 这里**不加** `padding({ top: 状态栏 })`：那会让列表视口从状态栏下沿起排，
      //   状态栏那一条变死背景 —— 用户要的是"**延伸进状态栏**"（见 `titleTopInset()` 说明）。
      //   让开状态栏 + 标题栏的偏移在**滚动内容里**（下面那个 `Blank()`）。
    }
    .onBackPressed((): boolean => guardPlayerBack('RecordListPage'))
    .hideTitleBar(false)
    .hideBackButton(false)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    // ★ 状态栏两件套（全工程二级页统一口径，见「我的」→「最近播放」这一页的现场）：
    //   ① `expandSafeArea` 的 TOP —— 只扩**绘制**区（官方《安全区域》原文：「expandSafeArea 属性
    //      支持组件在不改变布局情况下扩展其绘制区域至安全区外」）⇒ 本页 `backgroundColor` 才能铺到
    //      状态栏那一条，不再透出上一页（用户截图里透出的就是首页迷你播放条）；
    //   ② `ignoreLayoutSafeArea` **只留 BOTTOM** —— 它会**改布局**，根节点带 TOP 会把 HDS 标题栏
    //      的返回 / 菜单按钮一起顶进状态栏（用户报的"标题跑到状态栏下面"）。
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.background_secondary'))
  }
}

/** 路由表里注册的 Builder（`features/setting` 的 router_map.json）。 */
@Builder
export function RecordListPageBuilder(name: string, param: Object) {
  RecordListPage({ mode: (param as RecordListRouteParam | undefined)?.mode ?? RECORD_MODE_HISTORY })
}
