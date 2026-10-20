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
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { guardPlayerBack } from 'musicbasic';
import { AlbumRouteParam, ArtistRouteParam, BreakpointType, ThemeState, TitleBarConstants, WindowUtil, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions, HdsNavigationTitleBarOptions, HideMode, ScrollEffectType, TextStyleMode, TitleSize } from '@kit.UIDesignKit';
import { AppStorageKeys, AmbientState, FavoriteEntry, MusicAppState, MusicStoreService, PageTopInsetHelper, PlayedSongRecord, QualityInfo, RouterUrlConstants, SongItem, SongTitleMarquee, ToplistRouteParam, barBlurOptions, buildTitleMaterial } from 'musicbasic';
import { AlbumInfo, LXQualityOption, LXSearchSong, LXSearchResult, SingerInfo, lxGetPicFallback, lxGetQualityOptions, lxSearch, lxTxHotSearch, lxSearchSuggest, searchAlbums, searchSingers, sourceToCode, DownloadTask, DownloadUtil, OnlinePlayUtil, PlaylistSearchApi } from 'player';
import type { SearchPlaylistInfo, SearchPlaylistSong } from 'player';
import { sourceName } from 'player';
import { SongMoreMenu } from 'playlist';

/** 日志域与标签（真机排查：`hdc shell hilog | findstr RzdSearchPage`）。 */
const SEARCH_LOG_DOMAIN: number = 0x0000;
const SEARCH_LOG_TAG: string = 'RzdSearchPage';

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
        // ★ 歌名过长时跑马灯（用户要求「各个页面歌曲名过长时改为用跑马灯显示」）。
        //   换掉了原来的 `Text(song.name).maxLines(1).textOverflow(Ellipsis)`，
        //   字号/字色/字重/宽度约束**逐字保留**（`textAlign(TextAlign.Start)` 本来就是默认值，
        //   且 `TextOverflow.MARQUEE` 生效时官方注明 textAlign 不生效）；`SongTitleMarquee` 自带 `layoutWeight(1)`，
        //   等价于这里原来那句 `.width('100%')`（父 Column 已 `layoutWeight(1)`）。
        SongTitleMarquee({
          text: this.song.name,
          titleFontSize: $r('sys.float.Body_L'),
          titleFontColor: $r('sys.color.font_primary'),
          titleFontWeight: FontWeight.Normal
        })
        // ⚠️ 这一行原来误写成 `TextOverflow.MARQUEE`（歌手名跑马灯 = 用户没要的东西，
        //   且没有 `marqueeOptions` ⇒ 走的是 SDK 默认参数）。本次**恢复成 Ellipsis**，
        //   把跑马灯让给真正该滚的歌名那一行。
        Text(this.song.singer)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
    // ★ 用户 2026-10-20（截图口径）：**歌曲行去卡片、改分隔线**。
    //   原来这里是 `borderRadius + backgroundColor(card_background)`（= 一行一张卡片），
    //   现在只留一条底部细分隔线，行与行贴在一起。
    .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
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
  /** 输入中的联想候选（洛雪式：输入后下方弹出推荐） */
  @Local suggestWords: string[] = [];
  @Local showSuggest: boolean = false;
  private suggestTimerId: number = -1;
  /**
   * 程序化改 `query` 后要"吃掉"一次 `onChange`（不排联想请求）。
   * 见 `applyKeyword()` 的注释：点词条会先把 query 赋好，`onChange` 若照常排联想，
   * 联想层就会在搜索结果出来后再冒出来。
   */
  private suppressSuggestOnce: boolean = false;
  private suggestSeq: number = 0;
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
  /**
   * 页签清单（用户 2026-10-20 截图）：**综合 / 歌曲 / 歌单 / 歌手 / 专辑**，纯文字胶囊。
   *
   * 第 0 格「综合」不对应 `searchMode`（那套枚举 0..3 是给"单类结果页"用的），
   * 它由 {@link overview} 单独控制；1..4 与 `searchMode` 0..3 一一对应。
   */
  private readonly tabLabels: string[] = ['综合', '歌曲', '歌单', '歌手', '专辑'];
  /**
   * 是否停在「综合」页签（用户 2026-10-20：综合页 = 歌手卡 + 歌曲区 + 专辑区 + 查看更多）。
   * 默认 true —— 一进来搜完就是综合页，与华为音乐一致。
   */
  @Local overview: boolean = true;
  @Local searchHistory: string[] = [];
  @Local hotWords: string[] = [];
  /** Lazily fetched cover urls keyed by source_songId. */
  @Local covers: Record<string, string> = {};
  /** In-flight cover keys to avoid duplicate requests while rows reappear. */
  private loadingCovers: Set<string> = new Set();
  /** Scroller of the result list, bound to the HDS title bar for the search-row hide. */
  private listScroller: Scroller = new Scroller();
  /**
   * 结果列表的顶部偏移（= "状态栏 + 标题栏 + 搜索行"）。
   *
   * ★ 这里只是**占位初值**，`aboutToAppear()` 里的 `refreshContentPaddingTop()` 会立刻按
   *   标题栏与搜索行的实测高度重算（2026-10-11 第二十轮：从 56 提到 94，口径 = 状态栏 + 56）。
   */
  @Local contentPaddingTop: number = 94;
  @Local searchBarHeight: number = 40;
  @Local searchHeaderHeight: number = 96;
  /**
   * "状态栏 + HDS 标题栏"（vp）。
   *
   * ★ 2026-10-11（用户：「我想让它延伸进状态栏」）：这段留白由**滚动内容**的
   *   `contentStartOffset` 提供（见 `refreshContentPaddingTop()`），页根带
   *   `ignoreLayoutSafeArea([SYSTEM], [TOP, BOTTOM])` ⇒ 页面盒子从屏幕 y=0 起排
   *   （HDS 标题栏自己让位到 38..94）⇒ 值必须是「状态栏 + 56」= 94（**不能**只写 56，
   *   那一档是"盒子从状态栏下沿起排"时代的旧口径）。
   */
  @Local titleBarTopHeight: number = 94;
  /**
   * 页根在**窗口坐标**里的顶边 y（vp），由页根 `onAreaChange` 实测。
   *
   * ★ 2026-10-20（用户：「搜索页顶部怎么又一块空白。之前是正常的，你参考一下之前怎么写的」）：
   *   自绘顶栏后顶部留白**不能写死** —— `hideTitleBar(true)` 之后 HDS 的 NavDestination 究竟
   *   有没有把标题栏那 56vp 让出来，取决于系统版本，写死 `状态栏高度` 就会在"系统已经让过"的
   *   机型上**多空一条**。所以照其它页（`RecordListPage` / `MinePage`）的成熟做法：
   *   量盒顶 → 用 `PageTopInsetHelper.targetContentTopVp() - 标题栏高度` 反推"标题行顶边"，
   *   两者相减就是**还差多少**（盒顶已在标题行下方时正好为 0，不会多空）。
   */
  @Local boxTopVp: number = 0;
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
  private downloadSongs: LXSearchSong[] = [];

  private async openBatchQualitySheet(): Promise<void> {
    this.downloadSongs = this.selectedSongs().map((song: LXSearchSong): LXSearchSong => {
      return {
        source: song.source, songId: song.songId, name: song.name, singer: song.singer,
        albumName: song.albumName, albumId: song.albumId, interval: song.interval,
        img: song.img, types: song.types.slice()
      };
    });
    if (this.downloadSongs.length === 0) {
      return;
    }
    if (this.store.getDownloadQualityMode() === 'follow') {
      console.info('[RzdDownloadQuality] mode=follow direct entry=search-batch');
      await this.confirmBatchDownload('');
      return;
    }
    console.info('[RzdDownloadQuality] mode=manual picker-open entry=search-batch');
    this.showQualitySheet = true;
    this.batchQualityLoading = true;
    this.batchSizeText = {};
    const texts: Record<string, string> = {};
    const selected: LXSearchSong[] = this.downloadSongs.slice();
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

  /**
   * Recomputes the content top inset from the title row height + search row height.
   *
   * ★ 2026-10-11（用户：「我想让它延伸进状态栏」）：这段留白住在**滚动内容里**
   *   （`List.contentStartOffset`），页根 `NavDestination` 带
   *   `ignoreLayoutSafeArea([SYSTEM], [TOP, BOTTOM])` ⇒ 页面盒子从屏幕 **y=0** 起排
   *   （HDS 标题栏自己让位到 38..94）⇒ 要"静止时第一行落在标题栏下沿"，就必须写「状态栏 + 56」= 94。
   *   上滑时行从标题栏底下**再穿进状态栏** —— 靠 `List.clipContent(ContentClipMode.SAFE_AREA)`
   *   （List 默认是 `ContentClipMode.CONTENT_ONLY`，按内容区裁，行到状态栏那条就被切一刀）。
   */
  private refreshContentPaddingTop(): void {
    this.titleBarTopHeight = getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP;
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
  private async confirmBatchDownload(quality: string): Promise<void> {
    const tasks: DownloadTask[] = [];
    for (const song of this.downloadSongs.slice()) {
      if (song.source.length > 0 && song.songId.length > 0) {
        const task: DownloadTask = new DownloadTask();
        task.source = song.source;
        task.songId = song.songId;
        task.name = song.name;
        task.singer = song.singer;
        task.quality = quality;
        task.imgUrl = song.img;
        task.albumName = song.albumName;
        tasks.push(task);
      }
    }
    this.showQualitySheet = false;
    this.exitBatchMode();
    const count: number = (await DownloadUtil.downloadBatch(tasks, this.getUIContext())).length;
    this.toast(count > 0 ? '已加入下载队列 ' + count + ' 首' : '没有新增下载任务');
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

  /** 输入防抖后拉联想词（对齐 lx-music 搜索框下方候选） */
  private scheduleSuggest(value: string): void {
    const key: string = value.trim();
    if (this.suggestTimerId >= 0) {
      try {
        clearTimeout(this.suggestTimerId);
      } catch (_e) {
      }
      this.suggestTimerId = -1;
    }
    if (key.length === 0) {
      this.suggestWords = [];
      this.showSuggest = false;
      return;
    }
    // 已有搜索结果时仍可显示联想，方便改关键词
    const seq: number = ++this.suggestSeq;
    this.suggestTimerId = setTimeout((): void => {
      void this.loadSuggest(key, seq);
    }, 280) as number;
  }

  private currentSuggestSource(): string {
    if (this.selectedSourceIndex <= 0) {
      return 'all';
    }
    const idx: number = this.selectedSourceIndex - 1;
    if (idx < 0 || idx >= this.sources.length) {
      return 'all';
    }
    return this.sources[idx].id;
  }

  private async loadSuggest(key: string, seq: number): Promise<void> {
    try {
      const words: string[] = await lxSearchSuggest(key, this.currentSuggestSource());
      if (seq !== this.suggestSeq) {
        return;
      }
      // 新数组引用，确保 ForEach 刷新
      this.suggestWords = words.slice();
      this.showSuggest = this.suggestWords.length > 0 && this.query.trim().length > 0;
      console.info('[搜索联想UI] n=' + this.suggestWords.length + ' src=' + this.currentSuggestSource());
    } catch (_e) {
      if (seq === this.suggestSeq) {
        this.suggestWords = [];
        this.showSuggest = false;
      }
    }
  }

  /**
   * 收起联想层。
   *
   * ★ 2026-10-20（用户：「**回车搜索时联想词不会消失**」）：
   *   原来这里只把 `showSuggest` 置 false，但 `scheduleSuggest` 那个 **280ms 防抖定时器还在跑**，
   *   定时器一到就把 `showSuggest` 又置回 true ⇒ 表现就是"按了回车，联想层过一会儿又冒出来"。
   *   现在顺手**清定时器**并 `suggestSeq++`（让已经在途的请求作废，不再写回状态）。
   */
  private hideSuggest(): void {
    this.showSuggest = false;
    this.suggestSeq++;
    if (this.suggestTimerId >= 0) {
      try {
        clearTimeout(this.suggestTimerId);
      } catch (_e) {
      }
      this.suggestTimerId = -1;
    }
  }

  private pickSuggest(word: string): void {
    this.hideSuggest();
    this.suppressSuggestOnce = true;
    this.query = word;
    this.suggestWords = [];
    void this.doSearch();
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

  /**
   * 点词条（最近搜索 / 热搜）发起搜索。
   *
   * ★★ 2026-10-20（用户：「点击词条搜索后会出现联想词（之前修过一次）」—— 回归了）：
   *   真因是 `this.query = keyword` 是**程序化赋值**，`Search.onChange` 照样会触发 ⇒
   *   `scheduleSuggest()` 又排了一个 280ms 的联想请求，定时器一到联想层就冒出来。
   *   上一轮只清了 `doSearch()` 之前的那批定时器，清不到"赋值之后新排的那个"。
   *   现在用 `suppressSuggestOnce` 标记：程序化赋值后**第一次** `onChange` 只同步值、不排联想。
   */
  private applyKeyword(keyword: string): void {
    this.hideSuggest();
    this.suppressSuggestOnce = true;
    this.query = keyword;
    void this.doSearch();
  }

  private async doSearch(): Promise<void> {
    // ★ 2026-10-20（用户：「点击词条跳转搜索时还会显示联想词」）：真因是这里只把
    //   `showSuggest` 置 false、**没清 280ms 防抖定时器**，定时器一到又把联想层打开。
    //   `hideSuggest()` 现在会一起 clearTimeout + `suggestSeq++`，所以这里统一走它
    //   （回车提交、点词条、点联想词三条路都覆盖）。
    this.hideSuggest();
    this.suggestWords = [];
    if (this.query.trim().length === 0) {
      return;
    }
    this.searching = true;
    this.errorMsg = '';
    // ★ 用户 2026-10-20：综合页要**一次**同时拿到歌曲/歌手/专辑（三份并发），
    //   任一有结果就清掉错误提示（单类搜索各自会写 errorMsg，这里统一兜回来）。
    if (this.overview) {
      this.songs = [];
      this.singers = [];
      this.albums = [];
      this.covers = {};
      await Promise.all([this.doSongSearch(), this.doSingerSearch(), this.doAlbumSearch()]);
      if (this.songs.length > 0 || this.singers.length > 0 || this.albums.length > 0) {
        this.errorMsg = '';
        this.store.addSearchHistory(this.query);
      }
      this.searching = false;
      hilog.info(SEARCH_LOG_DOMAIN, SEARCH_LOG_TAG, 'overview songs=%{public}d singers=%{public}d albums=%{public}d',
        this.songs.length, this.singers.length, this.albums.length);
      return;
    }
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
    await this.doSongSearch();
    this.searching = false;
    return;
  }

  /**
   * 歌曲搜索（用户 2026-10-20：「综合」页签要一次同时有歌曲/歌手/专辑）。
   *
   * 从 `doSearch()` 里**原样抽出来**，不碰 `this.searching`（由调用方管），
   * 这样「综合」页签可以 `Promise.all` 三份搜索，「歌曲」页签仍走原来的单份路径。
   */
  /**
   * 本次搜索要走哪些音源。
   *
   * ★ 2026-10-20（用户：「搜索页还是卡」）：综合页要同时拉 歌曲/歌手/专辑 三份，
   *   若再乘上"已勾选的 N 个音源"就是十几条并发请求，进页面会明显卡。
   *   ⇒ **综合页只取第一个勾选的音源**；单类页签（歌曲/歌单/歌手/专辑）保持原样，全勾的都搜。
   */
  private searchSources(): string[] {
    const out: string[] = [];
    for (let i: number = 0; i < this.sources.length; i++) {
      if (this.sources[i].checked) {
        out.push(this.sources[i].id);
        if (this.overview) {
          break;
        }
      }
    }
    return out;
  }

  private async doSongSearch(): Promise<void> {
    this.songs = [];
    this.covers = {};
    const activeSources: string[] = this.searchSources();
    if (activeSources.length === 0) {
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
  }

  /** Searches playlists across the enabled sources. */
  private async doPlaylistSearch(): Promise<void> {
    const activeSources: string[] = this.searchSources();
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
    const activeSources: string[] = this.searchSources();
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
    const activeSources: string[] = this.searchSources();
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
    // 歌单自己的封面随路由带下去：详情页 Hero 用它，而不是第一首歌的封面
    param.listCover = p.coverUrl;
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
  /**
   * 收藏 / 取消收藏这张**在线歌单**（写 `favorite_playlists`，我的页「收藏歌单」那一段读它）。
   *
   * 只存"身份 + 展示信息"（id / source / 名字 / 作者 / 曲目数 / 封面），**不拉歌曲列表**——
   * 收藏是"留着以后听"的动作，不是导入；要落到本地歌单请用菜单里的「导入为我的歌单」。
   * 已经收藏过的再点 = 取消收藏（同一颗星在平台音乐页也能取消，两处同一份数据）。
   */
  private collectPlaylist(p: SearchPlaylistInfo): void {
    const store = this.store;
    if (store.isFavoritePlaylist(p.source, p.id)) {
      store.removeFavoritePlaylist(p.source, p.id);
      this.getUIContext().getPromptAction().showToast({ message: '已取消收藏', duration: 1800 });
      return;
    }
    const entry = new FavoriteEntry();
    entry.id = p.id;
    entry.source = p.source;
    entry.name = p.name.length > 0 ? p.name : '在线歌单';
    entry.sub = p.creator.length > 0 ? p.creator : sourceName(p.source);
    entry.count = p.trackCount;
    entry.img = p.coverUrl;
    entry.time = Date.now();
    store.addFavoritePlaylist(entry);
    this.getUIContext().getPromptAction().showToast(
      { message: '已收藏', duration: 1500 });
  }

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
      // ★ 导入时把**源歌单封面**一起存下来：在线歌单自带封面，存了之后列表与详情页大图
      //   都能显示（以前没存，详情页就只能显示占位图 —— 用户反馈的「导入的歌单没封面」）。
      //   源歌单没给封面时退一步用第一首歌的专辑图（导入这一刻的快照）。
      const cover: string = p.coverUrl.length > 0 ? p.coverUrl : (songs[0].picUrl ?? '');
      if (cover.length > 0) {
        store.setPlaylistCover(targetId, cover);
      }
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
            .textAlign(TextAlign.Start)
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
            // ★ 用户 2026-10-11：「歌单菜单添加到我的歌单行为从创建一个歌单改为收藏该歌单」。
            //   原来这一项 = `addPlaylistToMine()`（拉全量歌曲、`createPlaylist()` 落一张本地歌单）。
            //   现在改成**收藏该在线歌单**（写 `MusicStoreService` 的 `favorite_playlists`），
            //   与「我的 → 歌单卡 → 收藏歌单」那一段同一份数据；导入能力保留为下面单独一项，
            //   免得多出来的歌单没人知道从哪来（能力一个都没丢）。
            value: '收藏该歌单',
            action: (): void => {
              this.collectPlaylist(p);
            }
          },
          {
            value: '导入为我的歌单',
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
    .padding({ top: 8, bottom: 8, left: 16, right: 16 })
    // ★ 2026-10-20（用户：「专辑和歌手怎么还是卡片」）⇒ 歌单行同样去卡片、改分隔线
    .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
    .onClick(() => {
      void this.openPlaylist(p);
    })
  }

  /** 歌手 id 形如 `source_rawId`（见 `doSingerSearch`）：拆出音源号。 */
  private singerSource(s: SingerInfo): number {
    const sep: number = s.id.indexOf('_');
    return sep > 0 ? Number(s.id.substring(0, sep)) : 2;
  }

  /** 歌手 id 里真正的原始 id（去掉 `source_` 前缀）。 */
  private singerRawId(s: SingerInfo): string {
    const sep: number = s.id.indexOf('_');
    return sep > 0 && sep < s.id.length - 1 ? s.id.substring(sep + 1) : s.id;
  }

  /** 是否已关注（关注 = 收藏歌手，与「我的 → 关注」页共用同一份数据）。 */
  private isFollowingSinger(s: SingerInfo): boolean {
    return this.store.isFavoriteArtist(String(this.singerSource(s)), this.singerRawId(s));
  }

  /** 关注 / 取消关注。 */
  private toggleFollowSinger(s: SingerInfo): void {
    const source: string = String(this.singerSource(s));
    const rawId: string = this.singerRawId(s);
    if (this.store.isFavoriteArtist(source, rawId)) {
      this.store.removeFavoriteArtist(source, rawId);
      this.toast('已取消关注');
      hilog.info(SEARCH_LOG_DOMAIN, SEARCH_LOG_TAG, 'unfollow singer=%{public}s', s.name);
      return;
    }
    const entry: FavoriteEntry = new FavoriteEntry();
    entry.source = source;
    entry.id = rawId;
    entry.name = s.name;
    entry.img = s.picUrl;
    entry.sub = s.albumSize > 0 ? `专辑 ${s.albumSize}` : '';
    entry.count = s.songNum;
    entry.time = Date.now();
    this.store.addFavoriteArtist(entry);
    this.toast('已关注');
    hilog.info(SEARCH_LOG_DOMAIN, SEARCH_LOG_TAG, 'follow singer=%{public}s', s.name);
  }

  /**
   * 关注 / 已关注 胶囊按钮（用户 2026-10-20：「搜索页的歌手部分后面加上关注/已关注」）。
   * 搜索结果的歌手行、综合页顶部歌手卡共用这一个。
   */
  @Builder
  private FollowButton(s: SingerInfo) {
    Text(this.isFollowingSinger(s) ? '已关注' : '+ 关注')
      .fontSize($r('sys.float.Caption_M'))
      .fontWeight(FontWeight.Medium)
      .fontColor(this.isFollowingSinger(s) ? $r('sys.color.font_tertiary') : this.themeState.color)
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .onClick((): void => {
        this.toggleFollowSinger(s);
      })
  }

  /** 歌手搜索结果行：封面 + 名字 + 专辑/歌曲数；点击进入歌手详情页。 */
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
      // ★ 2026-10-20（用户：「搜索页的歌手部分后面加上关注/已关注」）
      this.FollowButton(s)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
        .height(18)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 16, right: 16 })
    // ★ 2026-10-20（用户：「专辑和歌手怎么还是卡片」）⇒ 去卡片、改分隔线
    .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
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
    .padding({ top: 8, bottom: 8, left: 16, right: 16 })
    // ★ 2026-10-20（用户：「专辑和歌手怎么还是卡片」）⇒ 去卡片、改分隔线
    .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
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

  /**
   * 顶部固定区（挂在 HDS 标题栏的 `bottomBuilder` 里，与「我的」页/历史页同一套）：
   * 第 1 行 = [音源钮 + 搜索框] 胶囊；第 2 行 = [综合/歌曲/歌单/歌手/专辑] 胶囊页签。
   *
   * ★★ 2026-10-20 第六轮（用户第三次反馈「顶部还是没延伸到状态栏」）：**不再自绘顶栏**。
   *   自绘那套要自己算状态栏让位，怎么调都差一截；而「我的」页/历史页用 HDS 标题栏出来的位置
   *   一直是准的（用户自己也说「参考 RzdSchool 的标题栏和我的页的配色」）⇒ 回到 HDS：
   *   - 标题栏保留（返回键、状态栏让位、渐变托底全由 HDS 负责），只是**不写标题文字**；
   *   - 搜索框 + 页签挂 `bottomBuilder`（HDS 自己会把它们排在标题行下面）；
   *   - 列表用 `contentStartOffset(contentPaddingTop)` 把这段高度让进**滚动内容**里，
   *     行才能一路画进状态栏（与历史页 `titleTopInset()` 同一口径）。
   */
  @Builder
  private SearchHeaderBar() {
    Column({ space: 6 }) {
      this.SearchInputBar()
      this.SearchTabRow()
    }
    .width('100%')
    .padding({ bottom: 6 })
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const height: number = Number(newArea.height);
      if (height > 0 && Math.abs(height - this.searchHeaderHeight) > 0.5) {
        this.searchHeaderHeight = height;
      }
    })
  }

  /**
   * 页签行：**综合 / 歌曲 / 歌单 / 歌手 / 专辑**（纯文字胶囊，选中 = 主题色实心）。
   * 用户截图里就是这套：没有图标、可横滚。
   */
  @Builder
  private SearchTabRow() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.tabLabels, (label: string, idx: number) => {
          Text(label)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(this.currentTabIndex() === idx ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.currentTabIndex() === idx ?
              $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
            .padding({ left: 16, right: 16, top: 7, bottom: 7 })
            .borderRadius(18)
            .backgroundColor(this.currentTabIndex() === idx ?
              this.themeState.color : $r('app.color.background_secondary'))
            .onClick((): void => {
              this.selectTab(idx);
            })
        }, (label: string) => 'findtab-' + label)
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(44)
    .align(Alignment.Start)
  }

  /** 当前选中的页签下标（0 = 综合，1..4 = `searchMode` 0..3）。 */
  private currentTabIndex(): number {
    return this.overview ? 0 : this.searchMode + 1;
  }

  /** 点页签：综合只切标志，其余走既有的 `changeSearchMode`（会自己重搜）。 */
  private selectTab(index: number): void {
    if (index === 0) {
      if (!this.overview) {
        this.overview = true;
        if (this.query.trim().length > 0 && !this.searching) {
          void this.doSearch();
        }
      }
      return;
    }
    const mode: number = index - 1;
    this.overview = false;
    if (this.searchMode === mode) {
      if (this.query.trim().length > 0 && !this.searching) {
        void this.doSearch();
      }
      return;
    }
    this.changeSearchMode(mode);
    hilog.info(SEARCH_LOG_DOMAIN, SEARCH_LOG_TAG, 'tab switch mode=%{public}d', mode);
  }

  /** 综合页的分区标题（可带一颗"播放全部"三角钮 —— 用户 2026-10-20：圆形不好看，要三角）。 */
  @Builder
  private SectionHeader(label: string, withPlay: boolean) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      if (withPlay) {
        SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
          .fontSize(30)
          .fontWeight(FontWeight.Regular)
          .height(30)
          .fontColor([this.themeState.color])
          .onClick((): void => {
            this.playAll();
          })
      }
      Blank()
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  /** 综合页底部的「查看更多 ›」。 */
  @Builder
  private MoreRow(label: string, tabIndex: number) {
    Row({ space: 2 }) {
      Text(label)
        .fontSize($r('sys.float.Caption_L'))
        .fontColor($r('sys.color.font_tertiary'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Center)
    .onClick((): void => {
      this.selectTab(tabIndex);
    })
  }

  /** 综合页顶部的歌手卡：头像 + 「歌手：X」+ 歌曲/专辑数，点进歌手详情。 */
  @Builder
  private OverviewSingerCard(s: SingerInfo) {
    Row({ space: 12 }) {
      Image(s.picUrl.length > 0 ? s.picUrl : $r('app.media.ic_avatar1'))
        .width(56)
        .height(56)
        .borderRadius(28)
        .objectFit(ImageFit.Cover)
      Column({ space: 4 }) {
        Text('歌手：' + s.name)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text((s.songNum > 0 ? `歌曲：${s.songNum}` : `歌曲：${this.songs.length}`) +
          ' ｜ ' + (s.albumSize > 0 ? `专辑：${s.albumSize}` : `专辑：${this.albums.length}`))
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      // ★ 2026-10-20：综合页的歌手卡也带关注按钮
      this.FollowButton(s)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick((): void => {
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
          .geometryTransition('wanting_search_field', { follow: true })
          .layoutWeight(1)
          .height(40)
          .borderWidth(0)
          .backgroundColor(Color.Transparent)
          // ★ 2026-10-20：搜索框本体不再挂模糊 —— 外层胶囊已经是实色卡片底，
          //   里面再模糊一层等于白开销（用户反馈"进页面很卡"就有它的份）。
          // ★ 2026-10-20（用户：「搜索页右侧的**搜索两个字去掉**」）：
          //   原来这里 `.searchButton(...)` 会在输入框右端塞一颗「搜索」文字按钮，已移除；
          //   提交走键盘回车（`onSubmit`）与下面的清除按钮。
          .onChange((value: string) => {
            this.query = value;
            // 程序化赋值引起的那一次 onChange：只同步值，不排联想（见 applyKeyword）
            if (this.suppressSuggestOnce) {
              this.suppressSuggestOnce = false;
              return;
            }
            this.scheduleSuggest(value);
          })
          .onSubmit(() => {
            this.hideSuggest();
            void this.doSearch();
          })
          .onEditChange((isEditing: boolean) => {
            // ★ 2026-10-20（用户：「我输入搜索词后**收起键盘联想词就会消失**」）：
            //   原来这里 `!isEditing` 就 `hideSuggest()` ⇒ 键盘一收联想层跟着没了。
            //   现在收键盘**不动**联想层（只有真的提交/点词条/滚动列表才收起）。
            if (isEditing) {
              this.showSuggest = this.suggestWords.length > 0 && this.query.trim().length > 0;
            }
          })
      }
      .width('100%')
      .height(40)
      .borderRadius(20)
      // ★ 2026-10-20（用户：「深色模式下依旧看不到搜索胶囊」「参考我的页的配色」）：
      //   改用**卡片底色** `app.color.card_background`（我的页的快捷卡/歌单卡就是这个），
      //   深浅两套里都是"比页面底亮一档"的实色 ⇒ 一定看得见，也不再依赖模糊。
      //   `backgroundBlurStyle` 一并去掉：标题栏外层本来就是材质，再叠一层既没效果又更慢。
      .backgroundColor($r('app.color.card_background'))
      // 注意：左右 padding 由调用方（`SearchHeaderBar`）控制
    }
    // ★ 2026-10-20：本行现在和「返回」按钮同排 ⇒ 用 `layoutWeight(1)` 吃剩余宽度，
    //   左右内边距交给外层 Row（`TopSearchRow`）统一给。
    .layoutWeight(1)
    .padding({ left: 0, right: 0 })
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
            // ★ 2026-10-20（用户：顶部「搜索」二字去掉）：标题留空，标题行只留返回键 ——
            //   HDS 仍照常给标题行让状态栏，只是不画文字。
            mainTitle: '',
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
        // ★ 2026-10-20 第六轮：搜索框 + 页签回到 **HDS 标题栏的 bottomBuilder**（见
        //   `getSearchTitleBar()`），页面主体只剩列表 ⇒ 顶部让位/状态栏延伸全由 HDS + 
        //   `List.contentStartOffset(contentPaddingTop)` 负责，与历史页/我的页同一套。

        Stack({ alignContent: Alignment.Center }) {
          List({ scroller: this.listScroller }) {
            if (!this.searching && this.resultEmpty()) {
              ListItem() {
              if (this.hotWords.length > 0) {
                Column({ space: 12 }) {
                  Row() {
                    Text($r('app.string.search_hot_title'))
                      .fontSize($r('sys.float.Body_L'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))
                    Blank()
                  }
                  .width('100%')

                  // 热搜：Flex 自动换行 + 文字宽度自适应。
                  // 原来用 4 栏等宽 Grid 且文字居中，短词两侧留一大片空白、
                  // 长词被截断，整块看起来就是"每个词条长度都一样"。
                  Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                    ForEach(this.hotWords, (keyword: string) => {
                      Text(keyword)
                        .fontSize($r('sys.float.Body_M'))
                        .fontColor($r('sys.color.font_primary'))
                        // ⚠️ 不设 maxLines(1)、也不设固定宽度：词条宽度完全由文字决定，
                        //    长词整条显示，短词就是短胶囊。原来固定宽度 + 省略号就是
                        //    「看着每个词条长度都像固定，长的词条显示不完整」的根因。
                        .textAlign(TextAlign.Start)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .borderRadius(18)
                        // ★ 2026-10-20（用户：「刚进搜索页非常卡」）：词条**不再挂模糊**
                        //   ——每屏 20 来个胶囊各挂一层 blur，进页面就是一卡。改纯色卡片底，
                        //   与我的页卡片同色（深色下也看得见）。
                        .backgroundColor($r('app.color.card_background'))
                        .margin({ right: 8, bottom: 8 })
                        .onClick(() => {
                          this.applyKeyword(keyword);
                        })
                    }, (keyword: string) => 'hot-' + keyword)
                  }
                  .width('100%')
                  .padding({ left: 0, right: 0 })
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .margin({ top: 4, bottom: 12 })
              }
              }

              ListItem() {
              if (this.searchHistory.length > 0) {
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

                  // 搜索历史：与热搜同款「自动换行 + 宽度自适应」。
                  // 原来也是 4 栏等宽 Grid + 文字居中，长词被截断、短词两边一片空白，
                  // 看起来就是「每个词条长度都固定」。
                  Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                    ForEach(this.searchHistory, (keyword: string) => {
                      Text(keyword)
                        .fontSize($r('sys.float.Body_M'))
                        .fontColor($r('sys.color.font_primary'))
                        // 不设 maxLines / 不设固定宽度：词条宽度完全由文字决定
                        .textAlign(TextAlign.Start)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .borderRadius(18)
                        // 与热搜同一处理：纯色卡片底、不挂模糊（卡顿根因之一）
                        .backgroundColor($r('app.color.card_background'))
                        .margin({ right: 8, bottom: 8 })
                        .onClick(() => {
                          this.applyKeyword(keyword);
                        })
                    }, (keyword: string) => keyword)
                  }
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

          if (this.overview && !this.searching) {
            // ── 综合页（用户 2026-10-20 截图）：歌手卡 → 歌曲区 → 专辑区 → 歌手区，各带「查看更多」
            if (this.singers.length > 0) {
              ListItem() {
                this.OverviewSingerCard(this.singers[0])
              }
            }
            if (this.songs.length > 0) {
              ListItem() {
                this.SectionHeader('歌曲', true)
              }
              ForEach(this.songs.slice(0, 10), (song: LXSearchSong) => {
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
              }, (song: LXSearchSong) => 'ovw-s-' + song.source + '_' + song.songId + '_' + song.img)
              if (this.songs.length > 10) {
                ListItem() {
                  this.MoreRow('查看更多歌曲', 1)
                }
              }
            }
            if (this.albums.length > 0) {
              ListItem() {
                this.SectionHeader('专辑', false)
              }
              ForEach(this.albums.slice(0, 3), (a: AlbumInfo) => {
                ListItem() {
                  this.AlbumResultRow(a)
                }
              }, (a: AlbumInfo) => 'ovw-a-' + a.id + '_' + a.name)
              ListItem() {
                this.MoreRow('查看更多专辑', 4)
              }
            }
            if (this.singers.length > 1) {
              ListItem() {
                this.SectionHeader('歌手', false)
              }
              ForEach(this.singers.slice(1, 3), (s: SingerInfo) => {
                ListItem() {
                  this.SingerResultRow(s)
                }
              }, (s: SingerInfo) => 'ovw-g-' + s.id)
              ListItem() {
                this.MoreRow('查看更多歌手', 3)
              }
            }
            if (this.songs.length === 0 && this.singers.length === 0 && this.albums.length === 0) {
              ListItem() {
                Text('没有找到相关内容')
                  .fontSize($r('sys.float.Caption_L'))
                  .fontColor($r('sys.color.font_tertiary'))
                  .width('100%')
                  .height(88)
                  .textAlign(TextAlign.Center)
              }
            }
          } else if (this.searchMode === 1) {
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
              // ★ 用户 2026-10-20：去卡片改分隔线 ⇒ 行间不再留 12vp 空隙
              //   （细线由 `SongRowItem` 自己那条 bottom border 画，左右各内缩 16）
            }, (song: LXSearchSong) => song.source + '_' + song.songId + '_' + song.img)
          }
        }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          // ⚠️ 不要给结果列表开多栏（原来按断点 1/2/3/4 栏）：
          //    歌曲行本身是「封面 + 标题/歌手 + 来源/时长」的整行卡片，铺成多栏会把
          //    文字挤窄、行与行长度还参差不齐，看起来就是"文字被拉伸对齐了"。
          //    搜索结果统一单栏、左对齐。
          .contentStartOffset(this.contentPaddingTop)
          .padding({
            left: 12,
            right: 12,
            bottom: 0
          })
          // ★★ 让内容能画进状态栏（"延伸进状态栏"）的**官方正解**：
          //   官方《开发应用沉浸式效果》→「滚动类场景」② —— 设置滚动容器的内容裁剪属性
          //   `clipContent(ContentClipMode.SAFE_AREA)`，**将内容层裁剪区域扩展至避让区**。
          //   原来 List 用的是默认 `ContentClipMode.CONTENT_ONLY`（按内容区裁）
          //   ⇒ 行一滚到状态栏那条就被裁掉，所以"偏移放哪都没用"。
          //   ⚠️ 链上任何祖先都**不能**再写 `clip(true)`（官方："需要确保父组件未设置 clip 等裁剪属性"）。
          .clipContent(ContentClipMode.SAFE_AREA)
          // ★ 底部留白**必须放在滚动视口里**（`contentEndOffset` = 内容末端到显示区边界的距离，随内容滚走）：
          //   这一页原来**一点底部留白都没有** ⇒ 滚到底最后一行会被壳层那条悬浮播放条压住。
          //   值与其他二级页同口径：56(播放条) + 16 + 16 = 88。
          //   ⚠️ 别写在外层容器的 `padding({bottom})` 上 —— 那是固定在屏幕底部的死带（用户点过的老毛病）。
          .contentEndOffset(88)
          .onScrollFrameBegin((offset: number): OnScrollFrameBeginHandlerResult => {
            // 列表滑动时自动收起联想（签名与 MinePage 一致）
            if (this.showSuggest && Math.abs(offset) > 1) {
              this.hideSuggest();
            }
            return { offsetRemain: offset };
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

          // 半透明悬浮候选：顶边与搜索框底对齐（contentPaddingTop = 标题+搜索区高度）
          if (this.showSuggest && this.suggestWords.length > 0 && !this.searching) {
            // 父层 Transparent：点击/滑动可穿透到下方 List，从而触发滚动自动收起
            Column() {
              Scroll() {
                Column({ space: 0 }) {
                  ForEach(this.suggestWords, (word: string, idx: number) => {
                    // ★ 用户 2026-10-20 截图：联想词每行 = 放大镜 + 文字 + 一条分隔线
                    Row({ space: 12 }) {
                      SymbolGlyph($r('sys.symbol.magnifyingglass'))
                        .fontSize(17)
                        .fontColor([$r('sys.color.font_tertiary')])
                      Text(word)
                        .fontSize(15)
                        .fontColor($r('sys.color.font_primary'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                        .textAlign(TextAlign.Start)
                    }
                    .width('100%')
                    .padding({ left: 20, right: 16, top: 11, bottom: 11 })
                    .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
                    .onClick(() => {
                      this.pickSuggest(word);
                    })
                  }, (word: string, idx: number) => 'sgf-' + idx + '-' + word)
                }
                .width('100%')
              }
              .width('100%')
              .constraintSize({ maxHeight: 480 })
              .scrollBar(BarState.Off)
              // 与迷你播放条/搜索框同款磨砂：#30 透明度灰底 + 材质模糊
              .backgroundColor(this.isDarkTheme() ? '#33202224' : '#30F1F3F5')
              .backgroundBlurStyle(this.searchControlBlur())
              .borderRadius(20)
              .shadow({ radius: 12, color: '#22000000', offsetX: 0, offsetY: 3 })
              .clip(true)
              .hitTestBehavior(HitTestMode.Default)
            }
            .width('100%')
            .height('100%')
            .padding({
              left: 16,
              right: 16,
              // ★ 顶栏已改成页面内固定区 ⇒ 联想层贴在 Stack 顶部（= 搜索框正下方）
              top: 0
            })
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Start)
            .hitTestBehavior(HitTestMode.Transparent)
            .zIndex(30)
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
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        // 量盒顶（窗口坐标 vp）只用于排查日志：HDS 标题栏方案下顶部由 HDS 自己让位
        const top: number = newArea.globalPosition.y as number;
        if (Math.abs(top - this.boxTopVp) > 0.5) {
          this.boxTopVp = top;
          hilog.info(SEARCH_LOG_DOMAIN, SEARCH_LOG_TAG, 'RzdSearchTop boxTop=%{public}f', top);
        }
      })
      // 页面主体从屏幕顶起排，让位由 `List.contentStartOffset(contentPaddingTop)` 负责
      .padding({ top: 0 })
    }
    .onBackPressed((): boolean => guardPlayerBack('OnlineSearchPage'))
    // ★★ 2026-10-20 第六轮（用户第三次说「顶部没延伸到状态栏」+「参考 RzdSchool 的标题栏和我的页」）：
    //   **回到 HDS 标题栏**（不再自绘、不再 hideTitleBar）。标题栏只保留返回键（标题文字留空），
    //   搜索框与页签挂在 `bottomBuilder`，状态栏让位 / 沉浸托底全交给 HDS —— 与「我的」页、
    //   历史页完全同一套，位置不会再偏。
    .hideTitleBar(false)
    .hideBackButton(false)
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
    // ★★ 用户 2026-10-11：「顶栏标题错位的问题还在，你应该参考一下其他显示正常的页面是怎么写的」。
    //   逐页对比后：显示正常的 MinePage / RecommendPage **都没有** expandSafeArea，
    //   而所有标题偏低的页面都有 ⇒ 照正常页面去掉它（官方语义：expandSafeArea 只延伸**绘制区**，
    //   「子组件相对屏幕位置不变」，但它会让 HDS 标题栏的定位多让一次）。
    //   页面底色由页盒自身 ackgroundColor 铺满（盒顶 = 0，实测见 RzdPageTopInset），不需要它补状态栏那一条。
    // ★★ 状态栏三件套（2026-10-11 定稿，用户第三次纠正后）：这里的 `ignoreLayoutSafeArea` **必须带 TOP** ——
    //   HDS 标题栏自己会按"状态栏高度"往下让位，所以页面盒子必须从屏幕 y=0 起排；
    //   只写 BOTTOM（盒子从状态栏下沿起排）会变成"盒子让一次 + 标题栏再让一次" ⇒
    //   整条标题掉到状态栏下面约一个状态栏高度（用户原话「整个标题移到了状态栏下面」），
    //   内容也跟着多顶 38vp（「上方留的空距有点大了」）。
    //   盒子从 0 起排后：标题栏 = 38..94 ✔，`List.contentStartOffset(titleBarTopHeight + searchHeaderHeight)`
    //   里的 `titleBarTopHeight`（= 状态栏 + 56 = 94）正好落在 94 ✔。
    //   ⚠️ 旧注释里"根节点带 TOP 会把标题/搜索按钮顶进状态栏 / 只能留 BOTTOM"那句**是错的**，已作废。
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