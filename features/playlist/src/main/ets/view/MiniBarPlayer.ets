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
import { AppStorageKeys, BreakpointType, StyleConstants } from 'musicbasic';
import { MusicAppState, PlayerViewModel } from 'player';
import { MiniBarAlbumCover } from './MiniBarAlbumCover';
import { MiniBarPlayerAside } from './MiniBarPlayerAside';


/**
 * Compact mini player row: album cover, metadata, controls, swipe-up to expand, and breakpoint padding.
 */
@ComponentV2
export struct MiniBarPlayer {
  /** Responsive horizontal padding based on window breakpoint. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** View model for current track, playback, and navigation to full player. */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** Global music UI state (play, mini bar expansion) from app storage. */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;

  /** When true, the aside shows a previous-track button. */
  @Param showPreviousTrack: boolean = false;
  /**
   * When false, row padding ignores global expand (always “collapsed�?row inset on list).
   * Playlist cover image size is handled in MiniBarAlbumCover when this is false.
   */
  @Param followAppMiniBarExpanded: boolean = true;
  /** Vertical pan gesture configuration for opening the full-screen player. */
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  private effectiveMiniBarExpanded(): boolean {
    return this.followAppMiniBarExpanded && this.playerViewModel.appState.miniBarExpanded;
  }

  /**
   * Composes cover, aside controls, padding, and upward pan-to-full-screen gesture.
   */
  build() {
    Row({ space: 8 }) {
      MiniBarAlbumCover({
        playerViewModel: this.playerViewModel,
        followAppMiniBarExpanded: this.followAppMiniBarExpanded
      })
      MiniBarPlayerAside({
        playerViewModel: this.playerViewModel,
        showPreviousTrack: this.showPreviousTrack
      })
    }
    .padding({
      left: this.effectiveMiniBarExpanded() ? 6 : 0,
      right: this.effectiveMiniBarExpanded() ? 16 : 16,
      top: this.effectiveMiniBarExpanded() ? 6 : 0,
      bottom: this.effectiveMiniBarExpanded() ? 6 : 0,
    })
    .alignItems(VerticalAlign.Center)
    .width(StyleConstants.FULL_WIDTH)
    .gesture(
      PanGesture(this.panOption)
        .onActionEnd((event?: GestureEvent) => {
          if (event && event.offsetY < -10) {
            this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
          }
        })
    )
  }
}
