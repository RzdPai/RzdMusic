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
import { HomeMiniBarAlbumCover } from './HomeMiniBarAlbumCover';
import { HomeMiniBarPlayerAside } from './HomeMiniBarPlayerAside';

/**
 * Mini player shell: album cover with shared-element id, aside controls, padding by expand state,
 * vertical pan to full screen.
 */
@ComponentV2
export struct HomeMiniBarPlayer {
  /** Breakpoint env for horizontal padding when the bar is collapsed. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Player VM shared with cover and aside. */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** Global music UI state (mini bar expanded, play state). */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** Passed through to {@link HomeMiniBarPlayerAside} to toggle previous-track visibility. */
  @Param showPreviousTrack: boolean = false;
  /**
   * When false, row padding ignores global expand (list-style inset).
   * Cover image sizing is adjusted in HomeMiniBarAlbumCover.
   */
  @Param followAppMiniBarExpanded: boolean = true;
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  private effectiveMiniBarExpanded(): boolean {
    return this.followAppMiniBarExpanded && this.playerViewModel.appState.miniBarExpanded;
  }

  /**
   * Composes cover and aside in a row with gesture to open the full player on upward pan.
   */
  build() {
    Row({ space: 8 }) {
      HomeMiniBarAlbumCover({
        playerViewModel: this.playerViewModel,
        followAppMiniBarExpanded: this.followAppMiniBarExpanded
      })
      HomeMiniBarPlayerAside({
        playerViewModel: this.playerViewModel,
        showPreviousTrack: this.showPreviousTrack
      })
    }
    .padding({
      left: this.effectiveMiniBarExpanded() ? 6 :
        new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
      right: this.effectiveMiniBarExpanded() ? 16 :
        new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
      top: this.effectiveMiniBarExpanded() ? 6 : 6,
      bottom: this.effectiveMiniBarExpanded() ? 6 : 6,
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
