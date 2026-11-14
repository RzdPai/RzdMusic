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

import {
  Logger,
  MusicAppState,
  MusicDbApi,
  PlaybackIntentLogEvent,
  PlaybackIntentState
} from 'musicbasic';
import { MediaService } from '../model/MediaService';

/**
 * Handles PlaybackIntentState for phone/TV/PC entry shells: queue sync, play, and optional full-screen open.
 * Caller supplies onRequestOpenPlayerUi (typically UIContext.animateTo + appState.isShowPlay = true).
 */
export function dispatchShellPlaybackIntent(
  appState: MusicAppState,
  intentState: PlaybackIntentState,
  onRequestOpenPlayerUi: () => void
): void {
  const songId: number = intentState.pendingPlaySongId;
  const openUi: boolean = intentState.openPlayerUi;
  Logger.debug(
    PlaybackIntentLogEvent.SHELL_DISPATCH,
    'songId=' + songId,
    'openUi=' + openUi
  );
  if (songId < 0 && !openUi) {
    return;
  }
  if (openUi) {
    Logger.info(PlaybackIntentLogEvent.OPEN_PLAYER_UI, 'request');
    onRequestOpenPlayerUi();
  }
  if (songId >= 0) {
    const ids: number[] = [...appState.playQueueIds];
    let playIndex: number = ids.findIndex((id: number) => id === songId);
    if (playIndex < 0) {
      const dto = MusicDbApi.getInstance().getSongById(songId);
      if (dto === undefined) {
        Logger.warn(PlaybackIntentLogEvent.SONG_NOT_IN_DB, 'id=' + songId);
        intentState.pendingPlaySongId = -1;
        intentState.openPlayerUi = false;
        return;
      }
      ids.push(songId);
      appState.playQueueIds = ids;
      playIndex = ids.length - 1;
    }
    Logger.info(PlaybackIntentLogEvent.LOAD_QUEUE, 'index=' + playIndex, 'songId=' + songId);
    void MediaService.getInstance().loadAsset(playIndex);
  }
  intentState.pendingPlaySongId = -1;
  intentState.openPlayerUi = false;
}
