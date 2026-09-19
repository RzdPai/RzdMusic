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


import { uiObserver } from '@kit.ArkUI';
import { BreakpointType, MusicStoreService, PlayedSongRecord, StyleConstants } from 'musicbasic';
import { PlaylistSongUi } from '../model/PlaylistUiModels';
import { MusicListPlaybackViewModel } from '../viewmodel/MusicListPlaybackViewModel';
import { SongMoreMenu } from './SongMoreMenu';

/** Bottom reserve (vp) inside the list so the last row clears the floating mini bar. */
const SONG_LIST_END_RESERVE_VP: number = 72;

/** Sort modes: 0 = default, 1 = by title, 2 = by singer. */
const SORT_DEFAULT: number = 0;
const SORT_TITLE: number = 1;
const SORT_SINGER: number = 2;

/**
 * Playlist song list with play-all header, sort menu, search filter, lazy list,
 * and nested scroll behavior for detail page.
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
  @Param listHeightVp: number = 700;
  @Param playlistId: string = '';
  /** Search keyword from the host page; filters the list in real-time. */
  @Param searchKeyword: string = '';
  /** External sort mode command from the host title-bar menu (-1 = none). */
  @Param externalSortMode: number = -1;
  /** 自定义排序顺序指令（递增触发进入排序模式）。 */
  @Param customSortCommand: number = 0;
  /** 歌曲去重指令（递增触发对歌单执行去重）。 */
  @Param dedupeCommand: number = 0;
  @Local sortMode: number = SORT_DEFAULT;
  /** True when custom reordering mode is active (up/down arrows on rows). */
  @Local customSortMode: boolean = false;
  /** List vertical scroller instance bound to the List. */
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.syncOriginal();
    this.applyFilterAndSort();
  }

  @Monitor('customSortCommand')
  onCustomSortCommand(): void {
    if (this.playlistId.length > 0) {
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

  @Monitor('externalSortMode')
  onExternalSortChanged(): void {
    if (this.externalSortMode >= 0) {
      this.sortMode = this.externalSortMode;
      this.applyFilterAndSort();
    }
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

  /** Stable per-song key (source_songId) so deletions update the list correctly. */
  private songKeyOf(item: PlaylistSongUi): string {
    if (item.source.length > 0 && item.songId.length > 0) {
      return 'pl-' + item.source + '_' + item.songId;
    }
    return 'pl-local-' + item.id;
  }

  /** Sort menu items for the list-check icon. */
  private sortMenuItems(): MenuElement[] {
    return [
      {
        value: '默认排序',
        action: (): void => {
          this.sortMode = SORT_DEFAULT;
          this.applyFilterAndSort();
        }
      },
      {
        value: '按歌名排序',
        action: (): void => {
          this.sortMode = SORT_TITLE;
          this.applyFilterAndSort();
        }
      },
      {
        value: '按歌手排序',
        action: (): void => {
          this.sortMode = SORT_SINGER;
          this.applyFilterAndSort();
        }
      }
    ];
  }

  /**
   * Builds a single playlist row: metadata, tags, overflow affordance, and tap-to-play.
   * @param item Song UI model for the row.
   * @param index Zero-based index in the playlist for playback requests.
   */
  @Builder
  private PlaylistSongRow(item: PlaylistSongUi, index: number) {
    Row({ space: 8 }) {
      if (item.coverUrl.length > 0) {
        Image(item.coverUrl)
          .width(44)
          .height(44)
          .borderRadius($r('sys.float.corner_radius_level3'))
          .objectFit(ImageFit.Cover)
      }
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.playlist_detail_song_title'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          Text('VIP')
            .fontSize($r('sys.float.Caption_S'))
            .lineHeight(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.playlist_detail_tag_text'))
            .padding({
              left: 4,
              right: 4,
              top: 1,
              bottom: 1
            })
            .backgroundColor($r('app.color.playlist_detail_tag_background'))
            .borderRadius($r('sys.float.corner_radius_level2'))
          Text($r('app.string.playlist_tag_spatial'))
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('app.color.playlist_detail_tag_text'))
            .padding({
              left: 4,
              right: 4,
              top: 1,
              bottom: 1
            })
            .backgroundColor($r('app.color.playlist_detail_tag_background'))
            .borderRadius($r('sys.float.corner_radius_level2'))
          Text(item.singer)
            .fontSize($r('sys.float.Caption_M'))
            .lineHeight(16)
            .fontWeight(FontWeight.Regular)
            .fontColor($r('app.color.primary40'))
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
          .fontColor([$r('sys.color.icon_tertiary')])
          .margin({ right: 4 })
      } else {
        SongMoreMenu({
          song: {
            songId: item.songId, name: typeof item.title === 'string' ? item.title : '',
            singer: typeof item.singer === 'string' ? item.singer : '',
            albumName: '', albumId: '', source: item.source,
            interval: '', img: item.coverUrl, types: []
          },
          iconSize: 18,
          playlistId: this.playlistId,
          onSongDeleted: (): void => {
            this.reloadFromStore();
          }
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      top: 10,
      bottom: 10,
    })
    .onClick(() => {
      if (this.customSortMode) {
        return;
      }
      this.listVm.requestPlayByListIndex(index, this.getUIContext());
    })
  }

  /**
   * Keeps the list viewport at the host-provided height so long playlists can
   * scroll inside their own List (enabling the scroll bar and edge bounce).
   * @returns Effective section height in vp.
   */
  private effectiveListHeightVp(): number {
    return this.listHeightVp;
  }

  /**
   * Builds header, sort affordance, and multi-lane list of songs.
   */
  build() {
    Column() {
      Row() {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
            .fontSize(32)
            .fontWeight(FontWeight.Regular)
            .height(32)
            .fontColor([$r('app.color.playlist_play_all_icon')])
          Text($r('app.string.playlist_play_all'))
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .lineHeight(24)
            .fontColor($r('app.color.mini_bar_primary'))
          Text(`${this.displaySongs.length}`)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .lineHeight(24)
            .fontColor($r('app.color.mini_bar_primary'))
        }
        .onClick(() => {
          if (this.displaySongs.length > 0) {
            this.listVm.requestPlayByListIndex(0, this.getUIContext());
          }
        })

        Blank()
        if (this.customSortMode) {
          Text('完成')
            .fontSize($r('sys.float.Body_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary40'))
            .onClick(() => {
              this.saveCustomSort();
            })
        } else {
          SymbolGlyph($r('sys.symbol.list_checkmask'))
            .fontSize(20)
            .fontWeight(FontWeight.Regular)
            .height(20)
            .fontColor([$r('app.color.primary40')])
            .bindMenu(this.sortMenuItems())
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .padding({
        left: new BreakpointType(16, 24, 0, 0).getValue(this.breakpointEnv.widthBreakpoint),
        right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
        top: new BreakpointType(8, 8, 16, 16).getValue(this.breakpointEnv.widthBreakpoint)
      })

      if (this.displaySongs.length === 0) {
        Column() {
          Text('未找到歌曲')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(120)
        .justifyContent(FlexAlign.Center)
      }

      List({ scroller: this.scroller }) {
        Repeat<PlaylistSongUi>(this.displaySongs)
          .each((obj: RepeatItem<PlaylistSongUi>) => {
            ListItem() {
              this.PlaylistSongRow(obj.item, this.displaySongs.indexOf(obj.item))
            }
          })
          .key((item: PlaylistSongUi) => this.songKeyOf(item))
          .onMove((from: number, to: number): void => {
            this.moveSong(from, to);
          })
      }
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
      .lanes(new BreakpointType(1, 2, 2, 2).getValue(this.breakpointEnv.widthBreakpoint), 32)
      .width(StyleConstants.FULL_WIDTH)
      .scrollBar(BarState.On)
      .edgeEffect(EdgeEffect.Spring)
      .contentEndOffset(SONG_LIST_END_RESERVE_VP)
      .padding({
        left: new BreakpointType(16, 24, 0, 0).getValue(this.breakpointEnv.widthBreakpoint),
        right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
        bottom: 0
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(this.effectiveListHeightVp())
  }
}
