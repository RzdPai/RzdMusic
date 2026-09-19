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


import { SongItem } from 'musicbasic';
import { MediaService } from '../model/MediaService';
import { MusicPlayMode } from '../model/MusicData';
import { MusicAppState, PlayerTrackUi } from '../model/PlayerModels';

/** Bridges MusicAppState / MediaService for UI layers that avoid direct player singleton calls. */
export class PlayerDataUtil {
  /** Builds a lightweight PlayerTrackUi for the currently selected queue item, if any. */
  public static getCurrentTrackUi(appState: MusicAppState): PlayerTrackUi | undefined {
    const song = PlayerDataUtil.getCurrentSongItem(appState);
    if (song === undefined) {
      return undefined;
    }
    return PlayerDataUtil.songItemToTrackUi(song);
  }

  /** Current SongItem from appState queue and selectIndex. */
  private static getCurrentSongItem(appState: MusicAppState): SongItem | undefined {
    return appState.getCurrentSongItem();
  }

  /** Maps SongItem fields into PlayerTrackUi for presentation components. */
  private static songItemToTrackUi(song: SongItem): PlayerTrackUi {
    const ui = new PlayerTrackUi();
    ui.id = song.id;
    ui.title = song.title;
    ui.singer = song.singer;
    ui.cover = song.source.length > 0 && song.cover.length === 0 ? $r('app.media.ic_avatar1') : song.label;
    ui.coverUrl = song.cover;
    return ui;
  }

  /** Current repeat / order / shuffle policy from MediaService. */
  public static getPlayMode(): MusicPlayMode {
    return MediaService.getInstance().getPlayMode();
  }

  /**
   * Cycles play mode: order -> single cycle -> shuffle -> order.
   *
   * @returns The mode after the cycle.
   */
  public static cyclePlayMode(): MusicPlayMode {
    const order = [MusicPlayMode.ORDER, MusicPlayMode.SINGLE_CYCLE, MusicPlayMode.RANDOM];
    const cur = MediaService.getInstance().getPlayMode();
    const i = order.indexOf(cur);
    const next = order[(i >= 0 ? i + 1 : 0) % order.length];
    MediaService.getInstance().setPlayMode(next);
    return next;
  }

  /** Delegates to MediaService.playPrevious. */
  public static playPrevious(): void {
    MediaService.getInstance().playPrevious();
  }

  /** Delegates to MediaService.playNextAuto from user control. */
  public static playNext(): void {
    MediaService.getInstance().playNextAuto(true);
  }

  /** Seeks current playback to the given position in milliseconds. */
  public static seek(ms: number): void {
    MediaService.getInstance().seek(ms);
  }

  /**
   * Toggles between play and pause; if the engine is on its first load, resolves queue index and loadAsset.
   *
   * @param appState Shared state for isPlay and queue indices.
   */
  public static togglePlayPause(appState: MusicAppState): void {
    const media = MediaService.getInstance();
    if (appState.isPlay) {
      media.pause();
    } else {
      if (media.getFirst()) {
        if (appState.getQueueLength() === 0) {
          return;
        }
        const idx = appState.selectIndex;
        const playIndex = idx < 0 || idx >= appState.getQueueLength() ? 0 : idx;
        media.loadAsset(playIndex);
      } else {
        media.play();
      }
    }
  }
}
