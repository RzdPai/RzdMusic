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
 *
 * `onRequestOpenPlayerUi` 的写法是**裸置位**：
 * ```ts
 * () => { this.appState.isShowPlay = true; }
 * ```
 * ⚠️ **不要把 `isShowPlay = true` 包进 `UIContext.animateTo`**（本注释原来就写着那个错写法，
 *    已按 `派音动画Bug清单.md` P1-9 改正）。那层隐式动画会给"挂载播放页浮层 +
 *    形变几何初始化"整段套一层补间，**把形变起点吃掉** —— 表现为"打开播放器不是从迷你条长出来、
 *    而是从中间某处开始长大"。展开动画由播放页自己播
 *    （`PlaybackPage.playExpandIntro` → `playMorphOpenIntro`，配 `UIUtils.applySync`）。
 *    参考实现：`products/default/src/main/ets/pages/Index.ets` 的
 *    `onPlaybackIntentChanged` 里那个闭包。
 *
 * ⚠️ PC 壳层 `products/pc/src/main/ets/pages/Index.ets` 的 `onPlaybackIntentChanged`
 *    **仍然**把 `isShowPlay = true` 包在 `animateTo` 里（P1-9 的第二处）—— 那一处待主线收。
 */
export function dispatchShellPlaybackIntent(
  appState: MusicAppState,
  intentState: PlaybackIntentState,
  onRequestOpenPlayerUi: () => void
): void {
  const songId: number = intentState.pendingPlaySongId;
  const openUi: boolean = intentState.openPlayerUi;
  const queueIndex: number = intentState.pendingQueueIndex;
  Logger.debug(
    PlaybackIntentLogEvent.SHELL_DISPATCH,
    'songId=' + songId,
    'openUi=' + openUi
  );
  if (songId < 0 && queueIndex < 0 && !openUi) {
    return;
  }
  if (openUi) {
    Logger.info(PlaybackIntentLogEvent.OPEN_PLAYER_UI, 'request');
    onRequestOpenPlayerUi();
  }
  if (queueIndex >= 0) {
    if (queueIndex < appState.getQueueLength()) {
      Logger.info(PlaybackIntentLogEvent.LOAD_QUEUE, 'queueIndex=' + queueIndex);
      void MediaService.getInstance().loadAsset(queueIndex);
    } else {
      Logger.warn(PlaybackIntentLogEvent.SONG_NOT_IN_DB, 'invalid queueIndex=' + queueIndex);
    }
  } else if (songId >= 0) {
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
  intentState.pendingQueueIndex = -1;
  intentState.openPlayerUi = false;
}
