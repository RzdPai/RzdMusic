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
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AppStorageKeys,
  LocalCoverImage,
  BreakpointType,
  MusicStoreService,
  PlayedSongRecord,
  StyleConstants,
  ThemeState
} from 'musicbasic';
import { PlaylistBatchSelectionStore } from '../model/PlaylistBatchSelectionStore';
import { PlaylistSongUi } from '../model/PlaylistUiModels';
import { PlaylistSongUiDataSource } from '../model/PlaylistSongUiDataSource';
import { MusicListPlaybackViewModel } from '../viewmodel/MusicListPlaybackViewModel';
import { SongMoreMenu } from './SongMoreMenu';

const BATCH_LOG_DOMAIN: number = 0x0000;
const BATCH_LOG_TAG: string = 'RzdPlaylistMultiSelect';

/** Sort modes: 0 = default, 1 = by title, 2 = by singer. */
const SORT_DEFAULT: number = 0;
const SORT_TITLE: number = 1;
const SORT_SINGER: number = 2;

/** 加载骨架的行数（固定 key，不需要 LazyForEach —— 只有 6 行）。 */
const SKELETON_ROW_KEYS: string[] = ['sk-0', 'sk-1', 'sk-2', 'sk-3', 'sk-4', 'sk-5'];

/**
 * Playlist song list with play-all header, MusicFree-style multi-select batch
 * operations, search filter, lazy list, and nested scroll behavior.
 * Sorting now lives in the host page's overflow menu (see {@link externalSortMode}).
 */
@ComponentV2
export struct PlaylistDetailSongListSection {
  /** Current window breakpoint for horizontal padding and lane count. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** View model supplying songs and play-by-index actions. */
  @Param listVm: MusicListPlaybackViewModel = new MusicListPlaybackViewModel();
  /** Currently displayed (filtered/sorted) song rows. */
  @Local displaySongs: PlaylistSongUi[] = [];
  /** Original song order from the store / view model (restored when search/sort cleared). */
  @Local originalSongs: PlaylistSongUi[] = [];
  @Param playlistId: string = '';
  /** Search keyword from the host page; filters the list in real-time. */
  @Param searchKeyword: string = '';
  /** External sort mode command from the host title-bar menu (-1 = none). */
  @Param externalSortMode: number = -1;
  /** 自定义排序顺序指令（递增触发进入排序模式）。 */
  @Param customSortCommand: number = 0;
  /** 歌曲去重指令（递增触发对歌单执行去重）。 */
  @Param dedupeCommand: number = 0;
  /** 强制退出多选模式指令（递增触发：宿主从菜单进入排序/去重时收起批量操作条）。 */
  @Param batchExitCommand: number = 0;
  /** 多选模式是否可用（本地歌单可批量删除；榜单/在线歌单只能批量播放/下载/收藏）。 */
  @Param allowBatchDelete: boolean = false;
  /**
   * 页面取色背景（Hero 渐变没入的那个颜色）。
   *
   * 只有一处用途：「播放全部」行吸顶时要有**不透明**背景，否则歌曲行会从它下面透出来。
   * 传入的必须是同一个色值，吸顶行才能和页面融成一体。
   */
  @Param backdropColor: string = '#1f1f22';
  @Param fgColor: ResourceColor = '#FFFFFF';
  @Param fgSecondaryColor: ResourceColor = '#B3FFFFFF';
  /**
   * 歌曲是否还在加载中（在线榜单/歌单的异步拉取）。
   *
   * 为真时渲染骨架屏，避免「先闪一下居中占位图标、再突然出现整列」的跳变。
   */
  @Param loading: boolean = false;
  /** 多选模式变化回调，宿主据此隐藏浮动迷你条。 */
  @Param onBatchModeChange: (active: boolean) => void = (_active: boolean): void => {};
  @Local sortMode: number = SORT_DEFAULT;
  /** True when custom reordering mode is active (drag handle on rows). */
  @Local customSortMode: boolean = false;
  /**
   * 多选（批量操作）共享状态。
   *
   * 由宿主页面创建并同时传给本组件与 {@link PlaylistBatchActionBar}，
   * 保证「勾选」和「已选 N 首 / 全选 / 取已选」读的是同一份。
   */
  @Param batch: PlaylistBatchSelectionStore = new PlaylistBatchSelectionStore();
  /** 主题色：多选勾选圈选中态用。 */
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** The page binds HDS title effects to this same bounded List. */
  @Param pageScroller: Scroller = new Scroller();
  @Param bottomPaddingVp: number = 96;
  @Param revealOffsetVp: number = 0;
  /** Report the already-bound List scroll; never bind the page Scroller to a second container. */
  @Event onContentDidScroll: () => void = (): void => {};
  @BuilderParam heroBuilder: () => void = this.EmptyHero;
  private displayDataSource: PlaylistSongUiDataSource = new PlaylistSongUiDataSource([]);
  private dataGeneration: number = 0;

  private logCrashStage(stage: string): void {
    const branch: string = this.loading ? 'loading' :
      (this.displaySongs.length === 0 ? 'empty' : (this.customSortMode ? 'repeat-sort' : 'lazy-songs'));
    hilog.info(0, 'RzdPlaylistCrashGuard',
      'list stage=%{public}s branch=%{public}s rows=%{public}d source=%{public}d gen=%{public}d',
      stage, branch, this.displaySongs.length, this.displayDataSource.totalCount(), this.dataGeneration);
  }

  @Builder
  private EmptyHero() {}

  aboutToAppear(): void {
    this.logCrashStage('appear-before-sync');
    this.syncOriginal();
    this.applyFilterAndSort();
    this.logCrashStage('appear-after-sync');
    hilog.info(0, 'RzdPlaylistSticky', 'appear single bounded List rows=%{public}d', this.displaySongs.length);
  }

  @Monitor('customSortCommand')
  onCustomSortCommand(): void {
    if (this.playlistId.length > 0) {
      this.exitBatchMode();
      this.customSortMode = true;
      this.syncOriginal();
      this.applyFilterAndSort();
    }
  }

  @Monitor('dedupeCommand')
  onDedupeCommand(): void {
    if (this.playlistId.length === 0) {
      return;
    }
    this.exitBatchMode();
    this.customSortMode = false;
    const removed: number = MusicStoreService.getInstance().dedupePlaylistSongs(this.playlistId);
    this.listVm.loadPlaylistSongs(this.playlistId);
    this.syncOriginal();
    this.applyFilterAndSort();
    const ui = this.getUIContext();
    if (removed > 0) {
      ui.getPromptAction().showToast({ message: '已移除 ' + removed + ' 首重复歌曲', duration: 2000 });
    } else {
      ui.getPromptAction().showToast({ message: '歌单中没有重复歌曲', duration: 2000 });
    }
  }

  @Monitor('listVm.songListVersion')
  onSongListChanged(): void {
    this.syncOriginal();
    this.applyFilterAndSort();
  }

  @Monitor('searchKeyword')
  onSearchKeywordChanged(): void {
    this.applyFilterAndSort();
  }

  /** 宿主标题栏「四个点」菜单里的排序项通过这里下发（0 默认 / 1 按歌名 / 2 按歌手）。 */
  @Monitor('externalSortMode')
  onExternalSortChanged(): void {
    if (this.externalSortMode >= 0) {
      this.exitBatchMode();
      this.customSortMode = false;
      this.sortMode = this.externalSortMode;
      this.applyFilterAndSort();
    }
  }

  /** 宿主强制退出多选模式（进入排序 / 去重 / 拖拽排序前收起批量操作条）。 */
  @Monitor('batchExitCommand')
  onBatchExitCommand(): void {
    this.exitBatchMode();
  }

  private syncOriginal(): void {
    this.originalSongs = [...this.listVm.playlistSongUis];
  }

  /** Re-reads the playlist from the store (after a song deletion) and re-applies filter/sort. */
  private reloadFromStore(): void {
    if (this.playlistId.length === 0) {
      return;
    }
    const p = MusicStoreService.getInstance().getPlaylistById(this.playlistId);
    const records: PlayedSongRecord[] = p !== undefined ? p.songs : [];
    const uis: PlaylistSongUi[] = [];
    for (let i = 0; i < records.length; i++) {
      const record = records[i];
      const ui = new PlaylistSongUi();
      ui.id = i + 1;
      ui.title = record.name;
      ui.singer = record.singer;
      ui.source = record.source;
      ui.songId = record.songId;
      ui.coverUrl = record.img;
      ui.albumName = record.albumName;
      ui.albumId = record.albumId;
      ui.interval = record.interval;
      uis.push(ui);
    }
    this.originalSongs = uis;
    this.applyFilterAndSort();
  }

  /** Applies the current search keyword and sort mode onto the original songs. */
  private applyFilterAndSort(): void {
    let result: PlaylistSongUi[] = [...this.originalSongs];
    const kw: string = this.searchKeyword.trim().toLowerCase();
    if (kw.length > 0) {
      result = result.filter((s: PlaylistSongUi): boolean => {
        const t: string = typeof s.title === 'string' ? s.title : '';
        const si: string = typeof s.singer === 'string' ? s.singer : '';
        return t.toLowerCase().includes(kw) || si.toLowerCase().includes(kw);
      });
    }
    if (this.sortMode === SORT_TITLE) {
      result.sort((a: PlaylistSongUi, b: PlaylistSongUi): number => {
        const at: string = typeof a.title === 'string' ? a.title : '';
        const bt: string = typeof b.title === 'string' ? b.title : '';
        return at.localeCompare(bt);
      });
    } else if (this.sortMode === SORT_SINGER) {
      result.sort((a: PlaylistSongUi, b: PlaylistSongUi): number => {
        const as: string = typeof a.singer === 'string' ? a.singer : '';
        const bs: string = typeof b.singer === 'string' ? b.singer : '';
        return as.localeCompare(bs);
      });
    }
    this.displaySongs = result;
    this.dataGeneration++;
    this.logCrashStage('data-before-reload');
    this.displayDataSource.reloadData(result);
    this.logCrashStage('data-after-reload');
    this.pruneSelection();
    hilog.info(0, 'RzdPlaylistSticky', 'data rows=%{public}d custom=%{public}d loading=%{public}d',
      result.length, this.customSortMode ? 1 : 0, this.loading ? 1 : 0);
  }

  /** 列表变化（删除/去重/过滤）后丢弃已不存在的选择键，避免"已选 N"与实际不符。 */
  private pruneSelection(): void {
    if (this.batch.keys.length === 0) {
      return;
    }
    const alive: string[] = [];
    for (let i: number = 0; i < this.displaySongs.length; i++) {
      const key: string = this.displaySongs[i].selectionKey();
      if (this.batch.has(key)) {
        alive.push(key);
      }
    }
    if (alive.length !== this.batch.keys.length) {
      this.batch.keys = alive;
    }
  }

  /** 拖动排序回调：仅排序模式下应用新顺序。 */
  private moveSong(from: number, to: number): void {
    if (!this.customSortMode) {
      return;
    }
    if (from === to || from < 0 || to < 0 || from >= this.displaySongs.length || to >= this.displaySongs.length) {
      return;
    }
    const moved: PlaylistSongUi[] = this.displaySongs.splice(from, 1);
    this.displaySongs.splice(to, 0, moved[0]);
    this.displaySongs = [...this.displaySongs];
  }

  /** 保存自定义排序结果到歌单并退出排序模式。 */
  private saveCustomSort(): void {
    if (this.playlistId.length > 0) {
      const orderedKeys: string[] = [];
      for (let i: number = 0; i < this.displaySongs.length; i++) {
        const s = this.displaySongs[i];
        orderedKeys.push(s.source + '_' + s.songId);
      }
      MusicStoreService.getInstance().reorderPlaylistSongs(this.playlistId, orderedKeys);
      this.listVm.songListVersion++;
      this.listVm.playlistSongUis = [...this.displaySongs];
      this.listVm.songListDataSource.reloadData(this.displaySongs);
    }
    this.customSortMode = false;
    this.syncOriginal();
    this.applyFilterAndSort();
  }

  /** Stable per-song key (source_songId) so deletions and selection update correctly. */
  private songKeyOf(item: PlaylistSongUi): string {
    if (item.source.length > 0 && item.songId.length > 0) {
      return 'pl-' + item.source + '_' + item.songId + '-' + item.id;
    }
    return 'pl-local-' + item.id;
  }

  /** Resolve on click, not while building every row; filtered/sorted indices are not VM indices. */
  private playDisplayedSong(item: PlaylistSongUi): void {
    const rows: PlaylistSongUi[] = this.listVm.playlistSongUis;
    let index: number = rows.indexOf(item);
    if (index < 0) {
      index = rows.findIndex((row: PlaylistSongUi): boolean => {
        return row.id === item.id && row.source === item.source && row.songId === item.songId;
      });
    }
    hilog.info(0, 'RzdPlaylistSticky', 'play mapped vmIndex=%{public}d', index);
    if (index >= 0) {
      this.listVm.requestPlayByListIndex(index, this.getUIContext());
    }
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  /** 是否已全选当前可见行（批量操作条与列表头共用同一份选择状态）。 */
  private isAllSelected(): boolean {
    return this.displaySongs.length > 0 && this.batch.keys.length >= this.displaySongs.length;
  }

  /** 全选 / 取消全选。 */
  private toggleSelectAll(): void {
    if (this.isAllSelected()) {
      this.batch.keys = [];
      return;
    }
    const keys: string[] = [];
    for (let i: number = 0; i < this.displaySongs.length; i++) {
      keys.push(this.displaySongs[i].selectionKey());
    }
    this.batch.keys = keys;
  }

  // ---------------------------------------------------------------------------
  // MusicFree 式多选（批量操作）
  // ---------------------------------------------------------------------------

  /** 进入多选模式：清空上一次的选择，并通知宿主隐藏浮动迷你条。 */
  private enterBatchMode(): void {
    if (this.displaySongs.length === 0) {
      this.toast('暂无歌曲');
      return;
    }
    this.customSortMode = false;
    this.batch.keys = [];
    // 与 MusicFree 同款：进出都包一层 250ms EaseInOut，避免底栏突变
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, (): void => {
      this.batch.batchMode = true;
    });
    this.onBatchModeChange(true);
    hilog.info(BATCH_LOG_DOMAIN, BATCH_LOG_TAG, 'enter batch mode rows=%{public}d', this.displaySongs.length);
  }

  /** 退出多选模式。 */
  private exitBatchMode(): void {
    if (!this.batch.batchMode) {
      return;
    }
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, (): void => {
      this.batch.batchMode = false;
    });
    this.batch.keys = [];
    this.onBatchModeChange(false);
    hilog.info(BATCH_LOG_DOMAIN, BATCH_LOG_TAG, 'exit batch mode');
  }

  /** 勾选/取消勾选单行。 */
  private toggleSelect(item: PlaylistSongUi): void {
    this.batch.toggle(item.selectionKey());
    hilog.info(BATCH_LOG_DOMAIN, BATCH_LOG_TAG, 'toggle key=%{public}s selected=%{public}d',
      item.selectionKey(), this.batch.keys.length);
  }

  @Builder
  private BatchCheckRing(row: PlaylistSongUi) {
    SymbolGlyph(this.batch.has(row.selectionKey()) ?
      $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
      .fontSize(24)
      .fontColor([this.batch.has(row.selectionKey()) ? this.themeState.color : this.fgSecondaryColor])
      .transition(TransitionEffect.OPACITY)
  }

  /**
   * Builds a single playlist row: optional selection ring, metadata, tags,
   * overflow affordance, and tap-to-play.
   * @param item Song UI model for the row.
   * @param index Zero-based index in the playlist for playback requests.
   */
  @Builder
  private PlaylistSongRow(item: PlaylistSongUi, index: number) {
    Row({ space: 8 }) {
      if (this.batch.batchMode) {
        this.BatchCheckRing(item)
      }

      if (item.coverUrl.length > 0) {
        LocalCoverImage({ src: item.coverUrl, cacheHttp: true, imageWidth: 44, imageHeight: 44, radius: 8 })
      }
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.fgColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          // VIP / 空间音频标识已按需求**移除**：这两枚标签目前是写死的（不看歌曲真实
          // 版权字段），只会让每一行都挂两个没有信息量的角标，视觉上很吵。
          Text(item.singer)
            .fontSize($r('sys.float.Caption_M'))
            .lineHeight(16)
            .fontWeight(FontWeight.Regular)
            .fontColor(this.fgSecondaryColor)
            .maxLines(1)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.customSortMode) {
        SymbolGlyph($r('sys.symbol.line_3_horizontal'))
          .fontSize(20)
          .fontWeight(FontWeight.Regular)
          .height(20)
          .fontColor([this.fgSecondaryColor])
          .margin({ right: 4 })
      } else if (!this.batch.batchMode) {
        SongMoreMenu({
          song: {
            songId: item.songId, name: typeof item.title === 'string' ? item.title : '',
            singer: typeof item.singer === 'string' ? item.singer : '',
            albumName: item.albumName, albumId: item.albumId, source: item.source,
            interval: item.interval, img: item.coverUrl, types: []
          },
          iconSize: 18,
          iconColor: this.fgSecondaryColor,
          playlistId: this.playlistId,
          onSongDeleted: (): void => {
            this.reloadFromStore();
          }
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    // 行内左右留白：之前把内边距放在 List 上，而 List 两侧 padding 会被 lanes 分栏
    // 吃掉一部分，行内容（封面、右侧按钮）就贴到屏幕边上了。改成按行加。
    .padding({
      left: new BreakpointType(16, 24, 0, 0).getValue(this.breakpointEnv.widthBreakpoint),
      right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
      top: 10,
      bottom: 10,
    })
    .gesture(LongPressGesture().onAction((): void => {
      // MusicFree 同款：长按任意一行进入多选并勾选该行
      if (this.customSortMode) {
        return;
      }
      if (!this.batch.batchMode) {
        this.enterBatchMode();
      }
      this.toggleSelect(item);
    }))
    .onClick(() => {
      if (this.customSortMode) {
        return;
      }
      if (this.batch.batchMode) {
        this.toggleSelect(item);
        return;
      }
      this.playDisplayedSong(item);
    })
  }

  /** 「播放全部」行：多选模式下切换为「已选 N 首 / 全选 / 完成」。 */
  @Builder
  private PlayAllHeader() {
    Row() {
      if (this.batch.batchMode) {
        Text('已选 ' + this.batch.keys.length + ' 首')
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .lineHeight(24)
          .fontColor(this.fgColor)
      } else {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
            .fontSize(32)
            .fontWeight(FontWeight.Regular)
            .height(32)
            .fontColor([this.fgColor])
          Text($r('app.string.playlist_play_all'))
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .lineHeight(24)
            .fontColor(this.fgColor)
          Text(`${this.displaySongs.length}`)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .lineHeight(24)
            .fontColor(this.fgColor)
        }
        .onClick(() => {
          if (this.displaySongs.length > 0) {
            this.playDisplayedSong(this.displaySongs[0]);
          }
        })
      }

      Blank()

      if (this.batch.batchMode) {
        Text(this.isAllSelected() ? '取消全选' : '全选')
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.fgSecondaryColor)
          .onClick(() => {
            this.toggleSelectAll();
          })
        Text('完成')
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.fgSecondaryColor)
          .margin({ left: 20 })
          .onClick(() => {
            this.exitBatchMode();
          })
      } else if (this.customSortMode) {
        Text('完成')
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.fgSecondaryColor)
          .onClick(() => {
            this.saveCustomSort();
          })
      } else {
        // 多选入口：沿用原来那个图标按钮的样式（不额外加文字标签）
        SymbolGlyph($r('sys.symbol.list_checkmask'))
          .fontSize(20)
          .fontWeight(FontWeight.Regular)
          .height(20)
          .fontColor([this.fgSecondaryColor])
          .onClick(() => {
            this.enterBatchMode();
          })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: new BreakpointType(16, 24, 0, 0).getValue(this.breakpointEnv.widthBreakpoint),
      right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
      top: new BreakpointType(8, 8, 16, 16).getValue(this.breakpointEnv.widthBreakpoint)
    })
  }

  /**
   * 播放全部行 + 歌曲列表。
   *
   * 唯一有界 List：首项 Hero，ListItemGroup.header 为播放全部行。
   * 普通歌曲用 LazyForEach；仅自定义排序保留 Repeat.onMove。
   * 批量操作条由宿主作为 List 的同级节点固定在屏幕底部。
   */
  @Builder
  private StickyPlayAllHeader() {
    Column() {
      this.PlayAllHeader()
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ bottom: 8 })
    .backgroundColor(this.backdropColor)
  }

  build() {
    List({ scroller: this.pageScroller }) {
      ListItem() {
        this.heroBuilder()
      }
      ListItemGroup({ header: this.StickyPlayAllHeader() }) {
      // 加载态排在最前面：在线榜单/歌单的歌曲是异步拉的，之前这里直接把空态画出来，
      // 结果是「先闪一下居中的占位图标，再突然整列出现」。现在先给骨架 + 转圈，
      // 数据到了再换成真正的列表，视觉上不会跳。
      if (this.loading) {
        ListItem() {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(28)
            .height(28)
            .color($r('app.color.primary40'))
          Text('正在加载歌曲…')
            .fontSize($r('sys.float.Body_S'))
            .fontColor(this.fgSecondaryColor)
        }
        .width(StyleConstants.FULL_WIDTH)
        .padding({ top: 48, bottom: 48 })
        .justifyContent(FlexAlign.Center)
        }

        // 骨架行：只画几条占位，让「马上要出现一列歌」这件事有预期
        ForEach(SKELETON_ROW_KEYS, (key: string) => {
          ListItem() {
          Row({ space: 12 }) {
            Column()
              .width(44)
              .height(44)
              .borderRadius(8)
              .backgroundColor($r('sys.color.background_tertiary'))
            Column({ space: 8 }) {
              Column()
                .width('62%')
                .height(13)
                .borderRadius(4)
                .backgroundColor($r('sys.color.background_tertiary'))
              Column()
                .width('38%')
                .height(11)
                .borderRadius(4)
                .backgroundColor($r('sys.color.background_tertiary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(64)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          }
        }, (key: string) => key)
      } else if (this.displaySongs.length === 0) {
        ListItem() {
        Column() {
          Text('未找到歌曲')
            .fontSize($r('sys.float.Body_S'))
            .fontColor(this.fgSecondaryColor)
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(120)
        .justifyContent(FlexAlign.Center)
        }
      } else if (this.customSortMode) {
          // Keep the original drag callback only in explicit custom-sort mode.
          // Nested group drag delivery remains device-unverified.
          Repeat<PlaylistSongUi>(this.displaySongs)
            .each((obj: RepeatItem<PlaylistSongUi>) => {
              ListItem() {
                // ★ 用 `obj.index`，**不要**再写 `this.displaySongs.indexOf(obj.item)`：
                //   后者是 O(n) 的线性查找，而 `displaySongs` 是 @Local 观测数组，
                //   每次元素读取都要走一遍代理陷阱 —— 几百行时整体是 O(n²) 的代理访问，
                //   这是「打开几百首歌的歌单要等一会」的主要来源。
                this.PlaylistSongRow(obj.item, obj.index)
              }
            })
            .key((item: PlaylistSongUi) => this.songKeyOf(item))
            .onMove((from: number, to: number): void => {
              this.moveSong(from, to);
            })
      } else {
        LazyForEach(this.displayDataSource, (item: PlaylistSongUi, index: number) => {
          ListItem() {
            this.PlaylistSongRow(item, index)
          }
        }, (item: PlaylistSongUi): string => this.songKeyOf(item))
      }
      ListItem() {
        Column().width(StyleConstants.FULL_WIDTH).height(this.bottomPaddingVp)
      }
      }
      .translate({ y: this.revealOffsetVp })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .sticky(StickyStyle.Header)
    .onDidScroll((): void => { this.onContentDidScroll(); })
    .cachedCount(4)
    .scrollBar(BarState.On)
    .edgeEffect(EdgeEffect.Spring)
    .onAppear((): void => {
      this.logCrashStage('list-build-mounted');
    })
    .onAreaChange((_old: Area, area: Area): void => {
      hilog.info(0, 'RzdPlaylistSticky', 'viewport width=%{public}s height=%{public}s bottom=%{public}d',
        String(area.width), String(area.height), this.bottomPaddingVp);
    })
  }
}
