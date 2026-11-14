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

import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys, SongItem, StyleConstants, ThemeState } from 'musicbasic';
import { MusicAppState } from '../model/PlayerModels';
import { MediaService } from '../model/MediaService';

/**
 * Lazy queue data source: resolves rows on demand from the live play queue so
 * long queues (hundreds of songs) never materialize all rows at once.
 */
class QueueSongDataSource implements IDataSource {
  private listener: DataChangeListener | undefined = undefined;
  private readonly state: MusicAppState;

  constructor(state: MusicAppState) {
    this.state = state;
  }

  totalCount(): number {
    return this.state.getQueueLength();
  }

  getData(index: number): SongItem | undefined {
    return this.state.resolveSongAtQueueIndex(index);
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listener = listener;
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    if (this.listener === listener) {
      this.listener = undefined;
    }
  }

  reload(): void {
    if (this.listener !== undefined) {
      this.listener.onDataReloaded();
    }
  }
}

/**
 * Reusable current-play-queue bottom sheet: header with count, lazy list rows with
 * jump-to-play and per-row removal. Hosts render a tiny anchor and drive {@link isShow}.
 */
@ComponentV2
export struct QueuePlaylistSheet {
  /** Parent-driven visibility; reset via {@link onDismiss} after the user closes the sheet. */
  @Param isShow: boolean = false;
  /** Invoked when the sheet is closed by the user (drag down / close icon). */
  @Event onDismiss: () => void = (): void => {};
  /** Global playback and queue state. */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** App accent color for the current-track highlight. */
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** Lazy queue rows data source. */
  @Local queueSource: QueueSongDataSource = new QueueSongDataSource(this.appState);

  /** Refreshes the lazy queue source when the queue or the current index changes. */
  @Monitor('appState.playQueue', 'appState.playQueueIds', 'appState.selectIndex')
  onQueueChanged(): void {
    this.queueSource.reload();
  }

  aboutToAppear(): void {
    this.queueSource = new QueueSongDataSource(this.appState);
  }

  /** Whether the given queue index is the currently playing track. */
  private isCurrentQueueIndex(index: number): boolean {
    return index === this.appState.selectIndex;
  }

  /** Starts playback at the given queue index and mirrors it in MusicAppState. */
  private playQueueIndex(index: number): void {
    if (index < 0 || index >= this.appState.getQueueLength()) {
      return;
    }
    this.appState.selectIndex = index;
    void MediaService.getInstance().loadAsset(index);
  }

  /** Removes the song at the given queue index from the play queue. */
  private removeQueueIndex(index: number): void {
    MediaService.getInstance().removeQueueIndex(index);
  }

  /** One queue row: cover, title, singer, playing indicator, and remove button. */
  @Builder
  QueueSongRow(song: SongItem, index: number) {
    Row({ space: 12 }) {
      Image(song.cover.length > 0 ? song.cover : $r('app.media.ic_avatar1'))
        .width(44)
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level3'))
        .objectFit(ImageFit.Cover)
      Column({ space: 4 }) {
        Text(song.title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isCurrentQueueIndex(index) ? this.themeState.color : $r('app.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(song.singer)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('app.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.isCurrentQueueIndex(index)) {
        SymbolGlyph($r('sys.symbol.speaker_wave_2_fill'))
          .fontSize(18)
          .fontWeight(FontWeight.Regular)
          .fontColor([this.themeState.color])
      }
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
        .fontColor([$r('app.color.font_tertiary')])
        .width(32)
        .height(32)
        .accessibilityText('从播放列表移除')
        .accessibilityLevel('yes')
        .onClick(() => {
          this.removeQueueIndex(index);
        })
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ top: 10, bottom: 10 })
    .onClick(() => {
      this.playQueueIndex(index);
    })
  }

  /** Sheet content: scrollable queue rows with nested scroll for detent dragging. */
  @Builder
  SheetContent() {
    Column() {
      List() {
        LazyForEach(this.queueSource, (song: SongItem, index: number) => {
          ListItem() {
            this.QueueSongRow(song, index);
          }
        }, (song: SongItem, index: number) => song.source.length > 0 ?
          `queue-${song.source}-${song.songId}` : `queue-local-${song.id}`)
      }
      .width(StyleConstants.FULL_WIDTH)
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .contentEndOffset(16)
      .padding({ left: 16, right: 16 })
      .nestedScroll({
        scrollForward: NestedScrollMode.SELF_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ bottom: 24 })
  }

  /** Sheet header: label with the queue count spaced on its right in a lighter tone. */
  @Builder
  SheetTitle() {
    Row({ space: 12 }) {
      Text('播放列表')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.font_primary'))
      Text(`${this.appState.getQueueLength()}`)
        .fontSize(15)
        .fontColor($r('app.color.font_tertiary'))
        .opacity(0.7)
    }
  }

  build() {
    Column()
      .width(1)
      .height(1)
      .hitTestBehavior(HitTestMode.None)
      .bindSheet(this.isShow, this.SheetContent(), {
        detents: [480, SheetSize.LARGE],
        preferType: SheetType.BOTTOM,
        dragBar: true,
        showClose: true,
        scrollSizeMode: ScrollSizeMode.FOLLOW_DETENT,
        title: this.SheetTitle(),
        backgroundColor: $r('app.color.background_secondary'),
        onDisappear: (): void => {
          this.onDismiss();
        }
      })
  }
}
