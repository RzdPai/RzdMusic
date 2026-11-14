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

import { AppStorageV2, Chip, ChipSize, LengthMetrics, uiObserver } from '@kit.ArkUI';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { AlbumRouteParam, ArtistRouteParam, BreakpointType, ThemeState, TitleBarConstants, WindowUtil, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions, HdsNavigationTitleBarOptions, HideMode, ScrollEffectType, TextStyleMode, TitleSize } from '@kit.UIDesignKit';
import { AppStorageKeys, AmbientState, MusicAppState, MusicStoreService, PlayedSongRecord, QualityInfo, RouterUrlConstants, SongItem, ToplistRouteParam, buildTitleMaterial } from 'musicbasic';
import { AlbumInfo, LXQualityOption, LXSearchSong, LXSearchResult, SingerInfo, lxGetPicFallback, lxGetQualityOptions, lxSearch, lxTxHotSearch, searchAlbums, searchSingers, sourceToCode, DownloadService, DownloadUtil, OnlinePlayUtil, PlaylistSearchApi } from 'player';
import type { SearchPlaylistInfo, SearchPlaylistSong } from 'player';
import { SongMoreMenu } from 'playlist';

/** Observable per-source checkbox state. */
@ObservedV2
export class SourceCheck {
  @Trace name: string = '';
  @Trace id: string = '';
  @Trace checked: boolean = true;

  constructor(name: string, id: string, checked: boolean) {
    this.name = name;
    this.id = id;
    this.checked = checked;
  }
}

/** 批量下载共享选择状态：@Trace 保证勾选时只刷新读取它的行内节点，不重建整行。 */
@ObservedV2
export class BatchSelectionStore {
  @Trace batchMode: boolean = false;
  @Trace keys: string[] = [];
}

/** 歌曲结果行：批量勾选/长按逻辑内聚，避免父级 ForEach 因 key 变化整行重建导致封面闪烁。 */
@ComponentV2
struct SongRowItem {
  @Require @Param song: LXSearchSong;
  @Param selection: BatchSelectionStore = new BatchSelectionStore();
  @Param coverUrl: ResourceStr = '';
  @Param sourceLabel: string = '';
  @Param sourceColor: ResourceColor = Color.Transparent;
  @Param onLoadCover: (song: LXSearchSong) => void = (_s: LXSearchSong): void => {};
  @Param onPlay: (song: LXSearchSong) => void = (_s: LXSearchSong): void => {};
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;

  private selected(): boolean {
    return this.selection.keys.indexOf(this.song.source + '_' + this.song.songId) >= 0;
  }

  private toggle(): void {
    const key: string = this.song.source + '_' + this.song.songId;
    const idx: number = this.selection.keys.indexOf(key);
    if (idx >= 0) {
      this.selection.keys.splice(idx, 1);
    } else {
      this.selection.keys.push(key);
    }
  }

  build() {
    Row({ space: 12 }) {
      if (this.selection.batchMode) {
        Row() {
          if (this.selected()) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(13)
              .fontColor([$r('sys.color.font_on_primary')])
          }
        }
        .width(22)
        .height(22)
        .borderRadius(11)
        .border({ width: 1.5, color: this.selected() ?
          this.themeState.color : $r('sys.color.font_tertiary') })
        .backgroundColor(this.selected() ? this.themeState.color : Color.Transparent)
        .justifyContent(FlexAlign.Center)
      }
      Image(this.coverUrl)
        .width(48)
        .height(48)
        .borderRadius($r('sys.float.corner_radius_level3'))
        .objectFit(ImageFit.Cover)
        .onAppear(() => {
          this.onLoadCover(this.song);
        })
      Column({ space: 2 }) {
        Text(this.song.name)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.song.singer)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (!this.selection.batchMode) {
        Row({ space: 8 }) {
          Column({ space: 4 }) {
            Text(this.sourceLabel)
              .fontSize($r('sys.float.Caption_S'))
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius($r('sys.float.corner_radius_level2'))
              .fontColor($r('sys.color.font_on_primary'))
              .backgroundColor(this.sourceColor)

            if (this.song.interval.length > 0) {
              Text(this.song.interval)
                .fontSize($r('sys.float.Caption_S'))
                .fontColor($r('sys.color.font_tertiary'))
            }
          }
          .alignItems(HorizontalAlign.Center)

          SongMoreMenu({
            song: {
              songId: this.song.songId, name: this.song.name, singer: this.song.singer,
              albumName: this.song.albumName, albumId: this.song.albumId, source: this.song.source,
              interval: this.song.interval, img: this.song.img, types: this.song.types
            },
            iconSize: 18
          })
        }
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 6, bottom: 6, left: 16, right: 16 })
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('app.color.card_background'))
    .gesture(LongPressGesture().onAction((): void => {
      // 长按进入批量选择模式并勾选该歌曲
      this.selection.batchMode = true;
      this.toggle();
    }))
    .onClick(() => {
      if (this.selection.batchMode) {
        this.toggle();
      } else {
        this.onPlay(this.song);
      }
    })
  }
}

/**
 * Online multi-source music search page (routed from the home top bar search entry).
 */
@ComponentV2
struct OnlineSearchPage {
  /** Window width breakpoint for responsive result columns. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Initial search query supplied by the route param (e.g. singer name). */
  @Param routeParam: Object = '';
  @Consumer('pageIndexInfos') pageStack: NavPathStack = new NavPathStack();
  @Local query: string = '';
  @Local searching: boolean = false;
  @Local songs: LXSearchSong[] = [];
  @Local errorMsg: string = '';
  @Local playingNow: string = '';
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  @Local sources: SourceCheck[] = [
    new SourceCheck('酷我', 'kw', true),
    new SourceCheck('酷狗', 'kg', true),
    new SourceCheck('QQ', 'tx', true),
    new SourceCheck('网易', 'wy', true),
    new SourceCheck('咪咕', 'mg', true)
  ];
  /** Index of the selected source in {@link sourceSelectOptions}; 0 means all sources. */
  @Local selectedSourceIndex: number = 0;
  /** Display text of the selected source on the dropdown button. */
  @Local selectedSourceText: string = '全部';
  private readonly sourceSelectOptions: SelectOption[] = [
    { value: '全部' },
    { value: '酷我' },
    { value: '酷狗' },
    { value: 'QQ' },
    { value: '网易' },
    { value: '咪咕' }
  ];
  /** 搜索类别选项（歌曲/歌单/歌手/专辑）。 */
  private readonly modeSelectOptions: SelectOption[] = [
    { value: '歌曲' },
    { value: '歌单' },
    { value: '歌手' },
    { value: '专辑' }
  ];
  @Local searchHistory: string[] = [];
  @Local hotWords: string[] = [];
  /** Lazily fetched cover urls keyed by source_songId. */
  @Local covers: Record<string, string> = {};
  /** In-flight cover keys to avoid duplicate requests while rows reappear. */
  private loadingCovers: Set<string> = new Set();
  /** Scroller of the result list, bound to the HDS title bar for the search-row hide. */
  private listScroller: Scroller = new Scroller();
  /** Top inset cleared as the search row hides on scroll; stays at the title bar height. */
  @Local contentPaddingTop: number = 148;
  @Local searchBarHeight: number = 40;
  @Local searchHeaderHeight: number = 96;
  /** titleBar 区总高（状态栏 + 标题行，不含搜索框）。搜索框在主体顶部时用它避开系统区域。 */
  @Local titleBarTopHeight: number = 108;
  /** Search mode: 0 = songs, 1 = playlists, 2 = singers, 3 = albums. */
  @Local searchMode: number = 0;
  /** Playlist search results. */
  @Local playlists: SearchPlaylistInfo[] = [];
  /** Singer search results (mode 2). */
  @Local singers: SingerInfo[] = [];
  /** Album search results (mode 3). */
  @Local albums: AlbumInfo[] = [];
  /** 批量下载共享选择状态（仅歌曲结果；长按行进入）。 */
  @Local selection: BatchSelectionStore = new BatchSelectionStore();
  /** 批量下载音质选择弹窗。 */
  @Local showQualitySheet: boolean = false;
  /** 批量音质弹层加载态 + 各音质大小文案（打开时实时查询回填）。 */
  @Local batchQualityLoading: boolean = false;
  @Local batchSizeText: Record<string, string> = {};
  private readonly qualityOptions: string[] =
    ['128k', '320k', 'flac', 'flac24bit', 'hires', 'atmos', 'atmos_plus', 'master'];

  /** 歌手/专辑搜索必须指定单一音源：这两种模式下源下拉不含「全部」。 */
  private sourceOptionsForMode(): SelectOption[] {
    if (this.searchMode === 2 || this.searchMode === 3) {
      return this.sourceSelectOptions.slice(1);
    }
    return this.sourceSelectOptions;
  }

  /** 当前模式下源下拉的选中下标（歌手/专辑模式把「全部」映射为第一个音源）。 */
  private displaySourceIndex(): number {
    if (this.searchMode === 2 || this.searchMode === 3) {
      return this.selectedSourceIndex === 0 ? 0 : this.selectedSourceIndex - 1;
    }
    return this.selectedSourceIndex;
  }

  /** 应用音源选择（semanticIndex: 0=全部，1..5=对应音源）并按需重搜。 */
  private applySourceSelection(semanticIndex: number): void {
    this.selectedSourceIndex = semanticIndex;
    this.selectedSourceText = semanticIndex === 0 ? '全部' :
      this.sourceSelectOptions[semanticIndex].value as string;
    for (let i: number = 0; i < this.sources.length; i++) {
      this.sources[i].checked = (semanticIndex === 0) || (i === semanticIndex - 1);
    }
    this.store.setSearchSource(semanticIndex === 0 ? 'all' : this.sources[semanticIndex - 1].id);
    if (this.query.trim().length > 0 && !this.searching) {
      void this.doSearch();
    }
  }

  /** 当前专辑搜索是否为酷我源（酷我结果不展示歌曲数）。 */
  private isKwAlbumSource(): boolean {
    return this.searchMode === 3 && this.selectedSourceIndex === 1;
  }

  private formatByteSize(n: number): string {
    if (n >= 1073741824) {
      return (n / 1073741824).toFixed(2) + 'GB';
    }
    return (n / 1048576).toFixed(1) + 'MB';
  }

  /** 批量已选歌曲（top-down 顺序）。 */
  private selectedSongs(): LXSearchSong[] {
    const out: LXSearchSong[] = [];
    for (let i: number = 0; i < this.songs.length; i++) {
      if (this.selection.keys.indexOf(this.songKey(this.songs[i])) >= 0) {
        out.push(this.songs[i]);
      }
    }
    return out;
  }

  /** 批量音质弹层大小列（打开时由真实音质查询回填）。 */
  private batchQualitySizeText(q: string): string {
    const text: string = this.batchSizeText[q];
    return text === undefined ? '' : text;
  }

  /** 打开批量音质弹层并并发拉取每首歌的真实音质+大小，按音质合计。 */
  private async openBatchQualitySheet(): Promise<void> {
    this.showQualitySheet = true;
    this.batchQualityLoading = true;
    this.batchSizeText = {};
    const texts: Record<string, string> = {};
    const selected: LXSearchSong[] = this.selectedSongs();
    if (selected.length > 0) {
      const tasks: Promise<LXQualityOption[]>[] = [];
      for (let i: number = 0; i < selected.length; i++) {
        tasks.push(lxGetQualityOptions(selected[i]));
      }
      const settled: PromiseSettledResult<LXQualityOption[]>[] = await Promise.allSettled(tasks);
      const totals: Record<string, number> = {};
      const known: Record<string, number> = {};
      for (let i: number = 0; i < settled.length; i++) {
        const r: PromiseSettledResult<LXQualityOption[]> = settled[i];
        if (r.status !== 'fulfilled') {
          continue;
        }
        const opts: LXQualityOption[] = r.value;
        for (let j: number = 0; j < opts.length; j++) {
          const o: LXQualityOption = opts[j];
          if (o.size > 0) {
            totals[o.type] = (totals[o.type] ?? 0) + o.size;
            known[o.type] = (known[o.type] ?? 0) + 1;
          }
        }
      }
      for (let i: number = 0; i < this.qualityOptions.length; i++) {
        const q: string = this.qualityOptions[i];
        const t: number = totals[q] ?? 0;
        const k: number = known[q] ?? 0;
        if (t > 0) {
          texts[q] = k >= selected.length ? '共约 ' + this.formatByteSize(t) :
            '已知 ≥ ' + this.formatByteSize(t);
        }
      }
    }
    this.batchSizeText = texts;
    this.batchQualityLoading = false;
  }

  /** Recomputes the content top inset from the actual status bar height + title row + search row. */
  private refreshContentPaddingTop(): void {
    // titleBar 区总高（状态栏 + 标题行）：搜索框现在位于主体顶部，只需避开这一段
    this.titleBarTopHeight =
      getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP;
    // 主体内容顶部：标题行 + bottomBuilder（搜索框+模式切换）实测高度
    this.contentPaddingTop = this.titleBarTopHeight + this.searchHeaderHeight;
  }

  /** 当前搜索类别结果区是否为空（用于热搜/历史/空态渲染）。 */
  private resultEmpty(): boolean {
    if (this.searchMode === 1) {
      return this.playlists.length === 0;
    }
    if (this.searchMode === 2) {
      return this.singers.length === 0;
    }
    if (this.searchMode === 3) {
      return this.albums.length === 0;
    }
    return this.songs.length === 0;
  }

  /** 批量选择用的歌曲唯一 key。 */
  private songKey(song: LXSearchSong): string {
    return song.source + '_' + song.songId;
  }

  private toggleSelectAll(): void {
    if (this.songs.length > 0 && this.selection.keys.length >= this.songs.length) {
      this.selection.keys = [];
      return;
    }
    const keys: string[] = [];
    for (let i: number = 0; i < this.songs.length; i++) {
      keys.push(this.songKey(this.songs[i]));
    }
    this.selection.keys = keys;
  }

  private exitBatchMode(): void {
    this.selection.batchMode = false;
    this.selection.keys = [];
  }

  /** 按所选音质把勾选歌曲批量加入下载队列。 */
  private confirmBatchDownload(quality: string): void {
    const service: DownloadService = DownloadService.getInstance();
    let count: number = 0;
    for (let i: number = 0; i < this.songs.length; i++) {
      const song: LXSearchSong = this.songs[i];
      if (this.selection.keys.indexOf(this.songKey(song)) >= 0) {
        service.enqueue(song.source, song.songId, song.name, song.singer, quality,
          this.getUIContext(), song.img, song.albumName, true);
        count++;
      }
    }
    this.showQualitySheet = false;
    this.exitBatchMode();
    if (count > 0) {
      this.toast('已加入下载队列 ' + count + ' 首（' + quality + '）');
    }
  }

  /** True when the app currently renders in dark color mode (drives status bar icon color).
   *  Follows the app's own 日间/夜间/跟随系统 setting first, then the host context color mode. */
  private isDarkTheme(): boolean {
    const mode: number = this.store.getColorMode();
    if (mode === 0) {
      return false;
    }
    if (mode === 1) {
      return true;
    }
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined || ctx.config === undefined) {
      return false;
    }
    return ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  /** 进页前先把状态栏图标色翻到本页应有的值，避免从首页（彩色 Hero 上白图标）push 过来时
   *  状态栏颜色比页面晚一帧更新、产生一小会割裂。 */
  private preapplyStatusBarColor(): void {
    const color: string = this.isDarkTheme() ? '#FFFFFF' : '#000000';
    WindowUtil.getInstance().setWindowSystemBarProperties({ statusBarContentColor: color });
  }

  /** 搜索框/Select 的磨砂强度，跟随软件内沉浸光感设置（与浮层迷你播放器一致）。 */
  private searchControlBlur(): BlurStyle {
    switch (this.ambientState.level) {
      case 1:
        return BlurStyle.Thin;
      case 2:
        return BlurStyle.Regular;
      case 3:
        return BlurStyle.Thick;
      default:
        return BlurStyle.Thin;
    }
  }

  /** 光感等级变化时重建标题栏缓存，让搜索框/Select 的背景材质实时跟随。 */
  @Monitor('ambientState.level')
  onAmbientLevelChanged(): void {
    this.cachedTitleBar = undefined;
  }

  aboutToAppear(): void {
    this.refreshContentPaddingTop();
    this.searchHistory = this.store.getSearchHistory();
    this.restoreSearchSource();
    this.preapplyStatusBarColor();
    void this.loadHotWords();
    if (this.routeParam !== '' && typeof this.routeParam === 'string' && (this.routeParam as string).length > 0) {
      this.query = this.routeParam as string;
      void this.doSearch();
    } else {
      const initial: string = (this.routeParam as SearchRouteParam | undefined)?.query ?? '';
      if (initial.length > 0) {
        this.query = initial;
        void this.doSearch();
      }
    }
  }

  /** Restores the persisted source selection; defaults to all sources. */
  private restoreSearchSource(): void {
    const cached: string = this.store.getSearchSource();
    let index: number = 0;
    for (let i: number = 0; i < this.sources.length; i++) {
      if (this.sources[i].id === cached) {
        index = i + 1;
        break;
      }
    }
    this.selectedSourceIndex = index;
    this.selectedSourceText = index === 0 ? '全部' : this.sourceSelectOptions[index].value as string;
    for (let i: number = 0; i < this.sources.length; i++) {
      this.sources[i].checked = (index === 0) || (i === index - 1);
    }
  }

  /** Loads the QQ hot search words for the search hint area. */
  private async loadHotWords(): Promise<void> {
    const words = await lxTxHotSearch();
    this.hotWords = words.slice(0, 10);
  }

  /** Reloads search history when the store changes. */
  @Monitor('store.searchHistoryVersion')
  onSearchHistoryChanged(): void {
    this.searchHistory = this.store.getSearchHistory();
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  private sourceColor(source: string): string {
    switch (source) {
      case 'kw': return '#FF6B35';
      case 'kg': return '#4A90D9';
      case 'tx': return '#31C27C';
      case 'wy': return '#C62F2F';
      case 'mg': return '#FF4081';
    }
    return '#6B6B6B';
  }

  private sourceLabel(source: string): string {
    switch (source) {
      case 'kw': return '酷我';
      case 'kg': return '酷狗';
      case 'tx': return 'QQ';
      case 'wy': return '网易';
      case 'mg': return '咪咕';
    }
    return source;
  }

  /** Result columns template per width breakpoint: 1 (SM) / 2 (MD) / 3 (LG) / 4 (XL). */
  private resultColumnsTemplate(): string {
    return new BreakpointType<string>(
      '1fr',
      '1fr 1fr',
      '1fr 1fr 1fr',
      '1fr 1fr 1fr 1fr'
    ).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /** Responsive lane count for the results List (1/2/3/4 columns). */
  private resultLaneCount(): number {
    return new BreakpointType<number>(1, 2, 3, 4).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /** Cache key for the current query + enabled sources. */
  private searchCacheKey(): string {    const active: string[] = [];
    for (let i: number = 0; i < this.sources.length; i++) {
      if (this.sources[i].checked) {
        active.push(this.sources[i].id);
      }
    }
    return this.query.trim() + '|' + active.join(',');
  }

  private async doSearch(): Promise<void> {
    if (this.query.trim().length === 0) {
      return;
    }
    this.searching = true;
    this.errorMsg = '';
    if (this.searchMode === 1) {
      this.playlists = [];
      await this.doPlaylistSearch();
      this.searching = false;
      return;
    }
    if (this.searchMode === 2) {
      this.singers = [];
      await this.doSingerSearch();
      this.searching = false;
      return;
    }
    if (this.searchMode === 3) {
      this.albums = [];
      await this.doAlbumSearch();
      this.searching = false;
      return;
    }
    this.songs = [];
    this.covers = {};
    const activeSources: string[] = [];
    for (let i: number = 0; i < this.sources.length; i++) {
      if (this.sources[i].checked) {
        activeSources.push(this.sources[i].id);
      }
    }
    if (activeSources.length === 0) {
      this.searching = false;
      return;
    }
    const cacheKey: string = this.searchCacheKey();
    const cached: string = this.store.getSearchResultCache(cacheKey);
    if (cached.length > 0) {
      try {
        const parsed: LXSearchSong[] = JSON.parse(cached) as LXSearchSong[];
        if (parsed !== undefined && parsed.length > 0) {
          this.songs = parsed;
          this.searching = false;
          this.covers = {};
          return;
        }
      } catch (_err) {
        // corrupt cache: fall through to a fresh search
      }
    }
    let all: LXSearchSong[] = [];
    const searchPromises: Promise<LXSearchResult>[] = [];
    for (let i: number = 0; i < activeSources.length; i++) {
      searchPromises.push(lxSearch(activeSources[i], this.query, 1, 20));
    }
    const results: PromiseSettledResult<LXSearchResult>[] = await Promise.allSettled(searchPromises);
    for (let i: number = 0; i < results.length; i++) {
      const r: PromiseSettledResult<LXSearchResult> = results[i];
      if (r.status === 'fulfilled' && r.value.list !== undefined) {
        for (let j: number = 0; j < r.value.list.length; j++) {
          all.push(r.value.list[j]);
        }
      }
    }
    this.songs = all;
    if (all.length > 0) {
      this.store.setSearchResultCache(cacheKey, JSON.stringify(all));
    }
    if (all.length === 0) {
      this.errorMsg = '未找到结果，请检查网络';
    } else {
      this.store.addSearchHistory(this.query);
    }
    this.searching = false;
  }

  /** Searches playlists across the enabled sources. */
  private async doPlaylistSearch(): Promise<void> {
    const activeSources: string[] = [];
    for (let i: number = 0; i < this.sources.length; i++) {
      if (this.sources[i].checked) {
        activeSources.push(this.sources[i].id);
      }
    }
    if (activeSources.length === 0) {
      this.errorMsg = '请至少选择一个音源';
      return;
    }
    const all: SearchPlaylistInfo[] = [];
    for (let i: number = 0; i < activeSources.length; i++) {
      try {
        const list: SearchPlaylistInfo[] =
          await PlaylistSearchApi.searchPlaylists(activeSources[i], this.query, 1);
        for (let j: number = 0; j < list.length; j++) {
          all.push(list[j]);
        }
      } catch (_err) {
        // skip failing source
      }
    }
    this.playlists = all;
    if (all.length === 0) {
      this.errorMsg = '未找到相关歌单，请检查网络';
    } else {
      this.store.addSearchHistory(this.query);
    }
  }

  /** Searches singers across the enabled sources (geuz source codes). */
  private async doSingerSearch(): Promise<void> {
    const activeSources: string[] = [];
    for (let i: number = 0; i < this.sources.length; i++) {
      if (this.sources[i].checked) {
        activeSources.push(this.sources[i].id);
      }
    }
    if (activeSources.length === 0) {
      this.errorMsg = '请至少选择一个音源';
      return;
    }
    const all: SingerInfo[] = [];
    for (let i: number = 0; i < activeSources.length; i++) {
      try {
        const code: number = sourceToCode(activeSources[i]);
        const result = await searchSingers(code, this.query, 1);
        for (let j: number = 0; j < result.list.length; j++) {
          const singer: SingerInfo = result.list[j];
          singer.id = code + '_' + singer.id;
          all.push(singer);
        }
      } catch (_err) {
        // skip failing source
      }
    }
    this.singers = all;
    if (all.length === 0) {
      this.errorMsg = '未找到相关歌手，请检查网络';
    } else {
      this.store.addSearchHistory(this.query);
    }
  }

  /** Searches albums across the enabled sources. */
  private async doAlbumSearch(): Promise<void> {
    const activeSources: string[] = [];
    for (let i: number = 0; i < this.sources.length; i++) {
      if (this.sources[i].checked) {
        activeSources.push(this.sources[i].id);
      }
    }
    if (activeSources.length === 0) {
      this.errorMsg = '请至少选择一个音源';
      return;
    }
    const all: AlbumInfo[] = [];
    for (let i: number = 0; i < activeSources.length; i++) {
      try {
        const code: number = sourceToCode(activeSources[i]);
        const result = await searchAlbums(code, this.query, 1);
        for (let j: number = 0; j < result.list.length; j++) {
          all.push(result.list[j]);
        }
      } catch (_err) {
        // skip failing source
      }
    }
    this.albums = all;
    if (all.length === 0) {
      this.errorMsg = '未找到相关专辑，请检查网络';
    } else {
      this.store.addSearchHistory(this.query);
    }
  }

  /** Opens a playlist detail by routing to the shared playlist detail page. */
  private openPlaylist(p: SearchPlaylistInfo): void {
    const param = new ToplistRouteParam();
    param.sectionType = 'onlinePlaylist';
    param.playlistId = p.id;
    param.onlineSource = p.source;
    param.listTitle = p.name;
    this.pageStack.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
  }

  /** Converts a fetched playlist song into a playable queue record. */
  private searchPlaylistSongToRecord(s: SearchPlaylistSong): PlayedSongRecord {
    const record = new PlayedSongRecord();
    record.songId = s.songId;
    record.name = s.name;
    record.singer = s.singer;
    record.albumName = s.album;
    record.albumId = '';
    record.source = s.source;
    record.interval = s.interval;
    record.img = s.picUrl;
    record.time = Date.now();
    return record;
  }

  /** Fetches playlist songs and appends them to the current play queue. */
  private async addPlaylistToQueue(p: SearchPlaylistInfo): Promise<void> {
    try {
      const songs: SearchPlaylistSong[] = await PlaylistSearchApi.getPlaylistDetail(p.source, p.id);
      if (songs.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '歌单为空或获取失败', duration: 2000 });
        return;
      }
      const queue = this.appState.playQueue;
      for (let i = 0; i < songs.length; i++) {
        const item = new SongItem();
        item.id = Date.now() + i;
        item.title = songs[i].name;
        item.singer = songs[i].singer;
        item.source = songs[i].source;
        item.songId = songs[i].songId;
        item.albumName = songs[i].album;
        item.cover = songs[i].picUrl;
        item.url = '';
        item.lyricText = '';
        queue.push(item);
      }
      this.appState.playQueue = [...queue];
      this.getUIContext().getPromptAction().showToast(
        { message: '已添加 ' + songs.length + ' 首到播放列表', duration: 2000 });
    } catch (_err) {
      this.getUIContext().getPromptAction().showToast({ message: '获取歌单失败', duration: 2000 });
    }
  }

  /** Fetches playlist songs and saves them into a brand-new playlist named after it. */
  private async addPlaylistToMine(p: SearchPlaylistInfo): Promise<void> {
    try {
      const songs: SearchPlaylistSong[] = await PlaylistSearchApi.getPlaylistDetail(p.source, p.id);
      if (songs.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '歌单为空或获取失败', duration: 2000 });
        return;
      }
      const store = this.store;
      const created = store.createPlaylist(p.name.length > 0 ? p.name : '导入的歌单');
      const targetId: string = created.id;
      let added = 0;
      for (let i = 0; i < songs.length; i++) {
        const record = this.searchPlaylistSongToRecord(songs[i]);
        if (store.addSongToPlaylist(targetId, record)) {
          added++;
        }
      }
      this.getUIContext().getPromptAction().showToast(
        { message: '已创建歌单「' + created.name + '」并添加 ' + added + ' 首', duration: 2200 });
    } catch (_err) {
      this.getUIContext().getPromptAction().showToast({ message: '获取歌单失败', duration: 2000 });
    }
  }

  /** Cover cache key for a search song. */
  private coverKeyOf(song: LXSearchSong): string {
    return song.source + '_' + song.songId;
  }

  /** Cover source for a song row: cached cover first, then the search-provided one, then placeholder. */
  private songCover(song: LXSearchSong): ResourceStr {
    const key: string = this.coverKeyOf(song);
    const cached: string | undefined = this.covers[key];
    if (cached !== undefined && cached.length > 0) {
      return cached;
    }
    if (song.img.length > 0) {
      return song.img;
    }
    return $r('app.media.ic_avatar1');
  }

  /** Loads the cover of a song on demand when its row becomes visible. */
  private async loadSongCover(song: LXSearchSong): Promise<void> {
    if (song.img.length > 0) {
      return;
    }
    const key: string = this.coverKeyOf(song);
    if (this.covers[key] !== undefined || this.loadingCovers.has(key)) {
      return;
    }
    this.loadingCovers.add(key);
    try {
      const pic: string = await lxGetPicFallback(song.source, song.songId, song.albumId, song.name, song.singer);
      if (pic.length > 0) {
        const next: Record<string, string> = {};
        const keys: string[] = Object.keys(this.covers);
        for (let i: number = 0; i < keys.length; i++) {
          next[keys[i]] = this.covers[keys[i]];
        }
        next[key] = pic;
        this.covers = next;
      }
    } catch (_err) {
      // keep default cover
    }
    this.loadingCovers.delete(key);
  }

  private toggleFavorite(song: LXSearchSong): void {
    if (this.store.isFavorite(song.source, song.songId)) {
      this.store.removeFavorite(song.source, song.songId);
    } else {
      const record = new PlayedSongRecord();
      record.songId = song.songId;
      record.name = song.name;
      record.singer = song.singer;
      record.albumName = song.albumName;
      record.source = song.source;
      record.interval = song.interval;
      record.img = song.img;
      // 搜歌结果未播放就收藏,quality 留空;后续点开播放时 OnlinePlayUtil
      // playRecord 会通过 refreshFavoriteQuality 自动回填。
      record.quality = '';
      record.time = Date.now();
      this.store.addFavorite(record);
    }
  }

  /** 播放前把懒加载到的封面写回歌曲数据，保证播放页/迷你条显示封面。 */
  private fillCover(song: LXSearchSong): void {
    if (song.img.length > 0) {
      return;
    }
    const cached: string | undefined = this.covers[this.coverKeyOf(song)];
    if (cached !== undefined && cached.length > 0) {
      song.img = cached;
    }
  }

  private playSong(song: LXSearchSong): void {
    this.fillCover(song);
    void OnlinePlayUtil.playSearchSong(this.appState, song, this.getUIContext());
  }

  private playAll(): void {
    for (let i = 0; i < this.songs.length; i++) {
      this.fillCover(this.songs[i]);
    }
    void OnlinePlayUtil.playList(this.appState, this.songs, 0, this.getUIContext());
  }

  /** Formats a play count for display (e.g. 1.2万). */
  private formatCount(n: number): string {
    if (n >= 100000000) {
      return (n / 100000000).toFixed(1) + '亿';
    }
    if (n >= 10000) {
      return (n / 10000).toFixed(1) + '万';
    }
    return String(n);
  }

  /** Playlist search result row. */
  @Builder
  private PlaylistRow(p: SearchPlaylistInfo) {
    Row({ space: 12 }) {
      if (p.coverUrl.length > 0) {
        Image(p.coverUrl)
          .width(48)
          .height(48)
          .borderRadius($r('sys.float.corner_radius_level3'))
          .objectFit(ImageFit.Cover)
      } else {
        Row() {
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(18)
            .fontColor([$r('sys.color.font_tertiary')])
        }
        .width(48)
        .height(48)
        .borderRadius($r('sys.float.corner_radius_level3'))
        .backgroundColor($r('sys.color.background_tertiary'))
        .justifyContent(FlexAlign.Center)
      }
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(this.sourceLabel(p.source))
            .fontSize($r('sys.float.Caption_S'))
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius($r('sys.float.corner_radius_level2'))
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor(this.sourceColor(p.source))
          Text(p.name)
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        Text(`${p.creator}${p.creator.length > 0 ? ' · ' : ''}${this.formatCount(p.playCount)}播放 · ${p.trackCount}首`)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.dot_grid_1x2_circle'))
        .fontSize(18)
        .fontColor([$r('sys.color.font_tertiary')])
        .margin({ right: 4 })
        .bindMenu([
          {
            value: '添加到我的歌单',
            action: (): void => {
              void this.addPlaylistToMine(p);
            }
          },
          {
            value: '添加到播放列表',
            action: (): void => {
              void this.addPlaylistToQueue(p);
            }
          }
        ])
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding({ top: 6, bottom: 6, left: 16, right: 16 })
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('app.color.card_background'))
    .onClick(() => {
      void this.openPlaylist(p);
    })
  }

  /** 歌手搜索结果行：圆头像 + 名字 + 专辑/歌曲数；点击进入歌手详情页。 */
  @Builder
  private SingerResultRow(s: SingerInfo) {
    Row({ space: 12 }) {
      Image(s.picUrl.length > 0 ? s.picUrl : $r('app.media.ic_avatar1'))
        .width(52)
        .height(52)
        .borderRadius(26)
        .objectFit(ImageFit.Cover)
      Column({ space: 3 }) {
        Text(s.name)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text((s.albumSize > 0 ? `专辑 ${s.albumSize} · ` : '') + `歌曲 ${s.songNum}`)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
        .height(18)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding({ top: 6, bottom: 6, left: 16, right: 16 })
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('app.color.card_background'))
    .onClick(() => {
      const param = new ArtistRouteParam();
      const sep: number = s.id.indexOf('_');
      if (sep > 0 && sep < s.id.length - 1) {
        param.source = Number(s.id.substring(0, sep));
        param.id = s.id.substring(sep + 1);
      } else {
        param.source = 2;
        param.id = s.id;
      }
      param.name = s.name;
      param.picUrl = s.picUrl;
      param.albumSize = s.albumSize;
      param.songNum = s.songNum;
      this.pageStack.pushPathByName(RouterUrlConstants.ARTIST_DETAIL, param);
    })
  }

  /** 专辑搜索结果行：封面 + 专辑名 + 歌手/歌曲数；点击进入专辑详情页。 */
  @Builder
  private AlbumResultRow(a: AlbumInfo) {
    Row({ space: 12 }) {
      Image(a.picUrl.length > 0 ? a.picUrl : $r('app.media.ic_avatar1'))
        .width(52)
        .height(52)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
      Column({ space: 3 }) {
        Text(a.name)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(a.artistName + (this.isKwAlbumSource() ? '' :
          (a.artistName.length > 0 ? ' · ' : '') + `${a.size} 首`))
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
        .height(18)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding({ top: 6, bottom: 6, left: 16, right: 16 })
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('app.color.card_background'))
    .onClick(() => {
      const param = new AlbumRouteParam();
      param.source = 2;
      param.id = a.id;
      param.name = a.name;
      param.picUrl = a.picUrl;
      param.artistName = a.artistName;
      param.size = a.size;
      this.pageStack.pushPathByName(RouterUrlConstants.ALBUM_DETAIL, param);
    })
  }

  /** Title-bar bottom area: search input plus the fixed mode chips right below it. */
  @Builder
  private SearchHeaderBar() {
    Column() {
      this.SearchInputBar()

      Row({ space: 8 }) {
        ForEach(this.modeSelectOptions, (opt: SelectOption, index: number) => {
          this.ModeTabChip(opt.value as string, this.modeTabIcon(index), this.searchMode === index,
            (): void => {
              this.changeSearchMode(index);
            })
        }, (opt: SelectOption) => 'mode-' + opt.value + '-' + this.searchMode)
      }
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16 })
      .margin({ top: 8 })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .padding({ bottom: 8 })
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const height: number = Number(newArea.height);
      if (height > 0 && Math.abs(height - this.searchHeaderHeight) > 0.5) {
        this.searchHeaderHeight = height;
      }
    })
  }

  /** 搜索输入行：音源选择嵌在最左 + 搜索框，整行一个圆角胶囊。 */
  @Builder
  private SearchInputBar() {
    Row() {
      Row() {
        // 音源选择：自定义触发按钮 + bindMenu 自定义菜单。系统 Select 的菜单宽度跟随
        // 控件宽度且菜单项文字左对齐，无法满足「文字居中 + 窄菜单」的要求。
        Row({ space: 4 }) {
          Text(this.sourceOptionsForMode()[this.displaySourceIndex()].value as string)
            .fontSize(14)
            .fontWeight(FontWeight.Regular)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(12)
            .fontWeight(FontWeight.Regular)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .height(40)
        .constraintSize({ minWidth: 78 })
        .padding({ left: 10, right: 8 })
        .justifyContent(FlexAlign.Center)
        .bindMenu(this.SourceMenuBuilder())

        // 搜索框
        Search({ value: this.query, placeholder: $r('app.string.home_search_placeholder') })
          .id('online_search_input')
          .layoutWeight(1)
          .height(40)
          .borderWidth(0)
          .backgroundColor(Color.Transparent)
          .backgroundBlurStyle(this.searchControlBlur())
          .searchButton($r('app.string.search_button'))
          .onChange((value: string) => {
            this.query = value;
          })
          .onSubmit(() => {
            void this.doSearch();
          })
      }
      .width('100%')
      .height(40)
      .borderRadius(20)
      .backgroundColor($r('app.color.floating_mini_bar_background'))
      .backgroundBlurStyle(this.searchControlBlur())
      // 注意：左右 padding 由调用方（build 主体顶部）控制，保证与 List padding(12,12) 严格对
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const height: number = Number(newArea.height);
      if (height > 0 && Math.abs(height - this.searchBarHeight) > 0.5) {
        this.searchBarHeight = height;
        this.refreshContentPaddingTop();
      }
    })
  }

  /** 音源下拉菜单：菜单项文字居中、整体宽度贴合内容（替代系统 Select 的宽菜单）。 */
  @Builder
  private SourceMenuBuilder() {
    Column({ space: 2 }) {
      ForEach(this.sourceOptionsForMode(), (opt: SelectOption, idx: number) => {
        Text(opt.value as string)
          .fontSize(14)
          .fontWeight(FontWeight.Regular)
          .textAlign(TextAlign.Center)
          .width(88)
          .padding({ top: 9, bottom: 9, left: 16, right: 16 })
          .borderRadius(10)
          .fontColor(this.displaySourceIndex() === idx ? $r('sys.color.brand') :
            $r('sys.color.font_primary'))
          .backgroundColor(this.displaySourceIndex() === idx ? $r('sys.color.comp_background_tertiary') :
            Color.Transparent)
          .onClick(() => {
            const semantic: number = (this.searchMode === 2 || this.searchMode === 3) ? idx + 1 : idx;
            this.applySourceSelection(semantic);
          })
      }, (opt: SelectOption) => opt.value as string)
    }
    .padding(6)
  }

  /** 标题栏自定义内容：返回 + 「搜索」大标题 + 播放全部。模式切换已移到主体顶部。 */
  @Builder
  private SearchTitleStackBuilder() {
    Row({ space: 10 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontWeight(FontWeight.Regular)
          .height(20)
          .fontColor([$r('sys.color.font_primary')])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor($r('app.color.floating_mini_bar_background'))
      .backgroundBlurStyle(this.searchControlBlur())
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.pageStack.pop();
      })

      Text($r('app.string.search_title'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)

      Blank()

      if (this.songs.length > 0 && this.searchMode === 0) {
        Text($r('app.string.search_play_all'))
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .height(40)
          .padding({ left: 14, right: 14 })
          .borderRadius(20)
          .backgroundColor($r('app.color.floating_mini_bar_background'))
          .backgroundBlurStyle(this.searchControlBlur())
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.playAll();
          })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  /** 切换模式时同步处理歌手/专辑自动选源。复用原 ModeSwitchBuilder 行为。 */
  private changeSearchMode(index: number): void {
    if (this.searchMode === index) {
      return;
    }
    this.searchMode = index;
    if ((index === 2 || index === 3) && this.selectedSourceIndex === 0) {
      // 歌手/专辑不支持聚合搜索，自动落到第一个音源（applySourceSelection 内部会重搜）
      this.applySourceSelection(1);
      return;
    }
    if (this.query.trim().length > 0 && !this.searching) {
      void this.doSearch();
    }
  }

  /** 搜索模式 tab 图标（与首页分类 chips 对应）。 */
  private modeTabIcon(index: number): Resource {
    switch (index) {
      case 0:
        return $r('sys.symbol.music_note_circle');
      case 1:
        return $r('sys.symbol.music_note_list');
      case 2:
        return $r('sys.symbol.person_crop_circle_fill_1');
      case 3:
        return $r('sys.symbol.square_stack_3d_fill');
      default:
        return $r('sys.symbol.music_note_circle');
    }
  }

  /** 单个模式 tab：首页分类 chips 同款胶囊（图标 + 文字）。 */
  @Builder
  private ModeTabChip(label: string, icon: Resource, active: boolean, onClick: () => void) {
    Row({ space: 6 }) {
      SymbolGlyph(icon)
        .width(16)
        .height(16)
        .fontColor([active ? $r('app.color.chip_selected_text') : $r('app.color.chip_unselected_text')])
      Text(label)
        .fontSize(12)
        .fontWeight(active ? FontWeight.Medium : FontWeight.Regular)
        .lineHeight(16)
        .fontColor(active ? $r('app.color.chip_selected_text') : $r('app.color.chip_unselected_text'))
    }
    .width(78)
    .height(36)
    .borderRadius(21)
    .backgroundColor(active ? $r('app.color.chip_selected_background') :
      $r('app.color.chip_unselected_background'))
    .justifyContent(FlexAlign.Center)
    .onClick(onClick)
  }

  /** HDS title bar: back icon, search title, play-all menu (when results exist), and bottom search input. */
  private cachedTitleBar: HdsNavigationTitleBarOptions | undefined = undefined;

  /** 标题栏配置：mini 模式，无 bottomBuilder（搜索框已搬到主体顶部，与 List 等宽）。 */
  private getSearchTitleBar(): HdsNavigationTitleBarOptions {
    let bar = this.cachedTitleBar;
    if (bar === undefined) {
      bar = {
        style: {
          blurStrategy: BlurStrategy.ENABLE,
          scrollEffectOpts: {
            scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: Color.Transparent
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary')
              },
              menuStyle: {
                textColor: $r('sys.color.font_primary'),
                iconColor: $r('sys.color.font_primary'),
                backgroundColor: '#1AFFFFFF'
              },
              backIconStyle: {
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
                textColor: $r('sys.color.font_primary'),
                iconColor: $r('sys.color.font_primary'),
                backgroundColor: '#1AFFFFFF'
              },
              backIconStyle: {
                iconColor: $r('sys.color.font_primary'),
                backgroundColor: '#1AFFFFFF'
              }
            }
          }
        },
        content: {
          title: {
            mainTitle: $r('app.string.search_title'),
            mainTitleSize: TitleSize.TITLE_ML
          },
          backIcon: {
            label: 'back',
            icon: $r('sys.symbol.chevron_left'),
            isEnabled: true
          },
          bottomBuilder: {
            builder: (): void => {
              this.SearchHeaderBar()
            }
          }
        }
      };
      this.cachedTitleBar = bar;
    }
    const style = bar.style;
    if (style !== undefined) {
      style.systemMaterialEffect = buildTitleMaterial(this.ambientState.level);
    }
    return bar;
  }

  /** 批量下载音质选择弹层（与单曲弹层同款样式）。 */
  @Builder
  private BatchQualitySheet() {
    Column() {
      Text('批量下载')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text('已选 ' + this.selection.keys.length + ' 首 · 选择下载音质')
        .fontSize(13)
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .margin({ top: 4 })
      if (this.batchQualityLoading) {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(20)
            .height(20)
          Text('获取音质信息...')
            .fontSize(13)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')
        .height(56)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 2 }) {
          ForEach(this.qualityOptions, (q: string) => {
            ListItem() {
              Row() {
                Text(q)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                if (this.batchQualitySizeText(q).length > 0) {
                  Text(this.batchQualitySizeText(q))
                    .fontSize(13)
                    .fontColor($r('sys.color.font_tertiary'))
                }
              }
              .width('100%')
              .padding({ left: 4, right: 4, top: 13, bottom: 13 })
              .onClick(() => {
                this.confirmBatchDownload(q);
              })
            }
          }, (q: string) => 'batchq-' + q)
        }
        .width('100%')
        .height(this.qualityOptions.length * 50)
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  build() {
    HdsNavDestination() {
      Column() {
        // 模式切换/加载/错误态统一放进下方 List 作为滚动内容：
        // 初始位于标题栏与搜索框下方，滚动时可滑到标题栏后面（内容延伸至屏幕顶部）。

        Stack({ alignContent: Alignment.Center }) {
          List({ scroller: this.listScroller }) {
            if (this.query.trim().length === 0 && !this.searching) {
              ListItem() {
              if (!this.searching && this.hotWords.length > 0 &&
                this.resultEmpty()) {
                Column({ space: 12 }) {
                  Row() {
                    Text($r('app.string.search_hot_title'))
                      .fontSize($r('sys.float.Body_L'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))
                    Blank()
                  }
                  .width('100%')

                  // 热搜：原生 Grid 4 列，等宽对齐
                  Grid() {
                    ForEach(this.hotWords, (keyword: string) => {
                      GridItem() {
                        Text(keyword)
                          .fontSize($r('sys.float.Body_M'))
                          .fontColor($r('sys.color.font_primary'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('100%')
                          .height(40)
                          .borderRadius(20)
                          .backgroundColor($r('app.color.background_secondary'))
                          .textAlign(TextAlign.Center)
                          .onClick(() => {
                            this.query = keyword;
                            void this.doSearch();
                          })
                      }
                    }, (keyword: string) => 'hot-' + keyword)
                  }
                  .columnsTemplate('1fr 1fr 1fr 1fr')
                  .columnsGap(8)
                  .rowsGap(8)
                  .width('100%')
                  .padding({ left: 0, right: 0 })
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .margin({ top: 4, bottom: 12 })
              }
              }

              ListItem() {
              if (!this.searching && this.searchHistory.length > 0 &&
                this.resultEmpty()) {
                Column({ space: 12 }) {
                  Row() {
                    Text($r('app.string.search_history_title'))
                      .fontSize($r('sys.float.Body_L'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))
                    Blank()
                    SymbolGlyph($r('sys.symbol.trash'))
                      .width(22)
                      .height(22)
                      .fontColor([$r('sys.color.font_primary')])
                      .onClick(() => {
                        this.store.clearSearchHistory();
                      })
                  }
                  .width('100%')

                  // 搜索历史：原生 Grid 4 列，等宽对齐
                  Grid() {
                    ForEach(this.searchHistory, (keyword: string) => {
                      GridItem() {
                        Text(keyword)
                          .fontSize($r('sys.float.Body_M'))
                          .fontColor($r('sys.color.font_primary'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('100%')
                          .height(40)
                          .borderRadius(20)
                          .backgroundColor($r('app.color.background_secondary'))
                          .textAlign(TextAlign.Center)
                          .onClick(() => {
                            this.query = keyword;
                            void this.doSearch();
                          })
                      }
                    }, (keyword: string) => keyword)
                  }
                  .columnsTemplate('1fr 1fr 1fr 1fr')
                  .columnsGap(8)
                  .rowsGap(8)
                  .width('100%')
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .margin({ top: 4, bottom: 12 })
              }
              }
            }

          if (this.errorMsg.length > 0 && !this.searching) {
            ListItem() {
              Text(this.errorMsg)
                .fontSize($r('sys.float.Caption_L'))
                .fontColor($r('sys.color.font_tertiary'))
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ left: 16, right: 16 })
                .margin({ top: 12, bottom: 12 })
            }
          }

          if (this.searchMode === 1) {
            ForEach(this.playlists, (p: SearchPlaylistInfo) => {
              ListItem() {
                this.PlaylistRow(p)
              }
              .margin({ bottom: 12 })
            }, (p: SearchPlaylistInfo) => p.source + '_' + p.id)
          } else if (this.searchMode === 2) {
            ForEach(this.singers, (s: SingerInfo) => {
              ListItem() {
                this.SingerResultRow(s)
              }
              .margin({ bottom: 12 })
            }, (s: SingerInfo) => s.id + '_' + s.name)
          } else if (this.searchMode === 3) {
            ForEach(this.albums, (a: AlbumInfo) => {
              ListItem() {
                this.AlbumResultRow(a)
              }
              .margin({ bottom: 12 })
            }, (a: AlbumInfo) => a.id + '_' + a.name)
          } else {
            ForEach(this.songs, (song: LXSearchSong) => {
              ListItem() {
                SongRowItem({
                  song: song,
                  selection: this.selection,
                  coverUrl: this.songCover(song),
                  sourceLabel: this.sourceLabel(song.source),
                  sourceColor: this.sourceColor(song.source),
                  onLoadCover: (s: LXSearchSong): void => {
                    this.loadSongCover(s);
                  },
                  onPlay: (s: LXSearchSong): void => {
                    this.playSong(s);
                  }
                })
              }
              .margin({ bottom: 12 })
            }, (song: LXSearchSong) => song.source + '_' + song.songId + '_' + song.img)
          }
        }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .lanes(this.resultLaneCount(), 12)
          .contentStartOffset(this.contentPaddingTop)
          .padding({
            left: 12,
            right: 12,
            bottom: 0
          })

          if (this.searching) {
            Column({ space: 8 }) {
              LoadingProgress()
                .width(40)
                .height(40)
              Text('加载中…')
                .fontSize($r('sys.float.Caption_L'))
                .fontColor($r('sys.color.font_tertiary'))
            }
          }
        }
        .width('100%')
        .layoutWeight(1)

        if (this.selection.batchMode && this.searchMode === 0) {
          Row({ space: 12 }) {
            Text('取消')
              .fontSize(14)
              .fontColor($r('sys.color.font_primary'))
              .onClick(() => {
                this.exitBatchMode();
              })
            Text(this.songs.length > 0 && this.selection.keys.length >= this.songs.length ?
              '取消全选' : '全选')
              .fontSize(14)
              .fontColor($r('sys.color.font_primary'))
              .onClick(() => {
                this.toggleSelectAll();
              })
            Blank()
            Text('已选 ' + this.selection.keys.length)
              .fontSize(14)
              .fontColor($r('sys.color.font_tertiary'))
            Text('下载')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selection.keys.length > 0 ? $r('sys.color.font_on_primary') :
                $r('sys.color.font_tertiary'))
              .padding({ left: 18, right: 18, top: 8, bottom: 8 })
              .borderRadius(18)
              .backgroundColor(this.selection.keys.length > 0 ? this.themeState.color :
                $r('sys.color.background_tertiary'))
              .onClick(() => {
                if (this.selection.keys.length > 0) {
                  void this.openBatchQualitySheet();
                }
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.floating_mini_bar_background'))
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: 0 })
    }
    .hideTitleBar(false)
    .hideBackButton(true)
    .titleBar(this.getSearchTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .dynamicHideTitleBar({
      hideTitleArea: false,
      hideBottomBuilder: false,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
      hideOffset: 0,
      hideRatio: 2.0
    })
    .bindToScrollable([this.listScroller])
    .backgroundColor($r('app.color.background_secondary'))
    .systemBarStyle(
      { statusBarContentColor: this.isDarkTheme() ? '#FFFFFF' : '#000000' },
      { statusBarContentColor: this.isDarkTheme() ? '#FFFFFF' : '#000000' })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .bindSheet(this.showQualitySheet, this.BatchQualitySheet(), {
      detents: [SheetSize.FIT_CONTENT],
      dragBar: true,
      showClose: true,
      backgroundColor: $r('app.color.background_secondary'),
      onWillDismiss: (action: DismissSheetAction) => {
        action.dismiss();
        this.showQualitySheet = false;
      }
    })
  }
}

/** Route parameters for opening the online search page with an initial query. */
export class SearchRouteParam {
  /** Initial search keyword (e.g. a singer name). */
  query: string = '';

  constructor(query: string = '') {
    this.query = query;
  }
}

@Builder
export function OnlineSearchPageBuilder(name: string, param: Object) {
  OnlineSearchPage({
    routeParam: param
  });
}
