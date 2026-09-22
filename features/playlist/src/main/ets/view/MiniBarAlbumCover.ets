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

import { ImmersiveType, getWindowInfoState, WindowInfo } from 'musicbasic';
import { PlayerConstants, PlayerViewModel } from 'player';

/**
 * Mini bar album art with optional ring progress and playing indicator.
 */
@ComponentV2
export struct MiniBarAlbumCover {
  /** Player view model providing cover art URL and playback state. */
  @Param playerViewModel: PlayerViewModel = new PlayerViewModel();
  /**
   * Home HDS: cover image 56vp when bar collapsed, 44vp when expanded.
   * List/embedded (`false`): cover image always 44vp.
   */
  @Param followAppMiniBarExpanded: boolean = true;
  /** Window layout flags affecting compact immersive cover sizing. */
  @Local windowInfo: WindowInfo = getWindowInfoState();

  /**
   * Returns a safe positive total duration for the ring progress control.
   * @returns Progress max from app state, or 1 when unset.
   */
  private progressTotal(): number {
    const max = this.playerViewModel.appState.progressMax;
    return max > 0 ? max : 1;
  }

  /**
   * Whether the window uses immersive free-form decoration (compact cover chrome).
   * @returns True when immersive decor is active.
   */
  private isImmersiveFreeWindowCover(): boolean {
    return this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE;
  }

  /**
   * 44×44 **image** only: list/embedded, or home HDS expanded. 56×56 image only home HDS collapsed.
   */
  private isCompactMiniBarCover(): boolean {
    return !this.followAppMiniBarExpanded || this.playerViewModel.appState.miniBarExpanded;
  }

  /**
   * Cover width/height in vp for current window and mini bar expansion mode.
   * @returns Side length in vp for the square cover.
   */
  private coverSideLengthVp(): number {
    if (this.isImmersiveFreeWindowCover()) {
      return 32;
    }
    return this.isCompactMiniBarCover() ? 44 : 56;
  }

  /**
   * Border radius in vp matching pill vs circle presentation for the cover.
   * @returns Corner radius in vp.
   */
  private coverBorderRadiusVp(): number {
    if (this.isImmersiveFreeWindowCover()) {
      return 8;
    }
    return this.isCompactMiniBarCover() ? 44 : 56;
  }

  /**
   * Renders cover image, optional ring progress, rhythm glyph.
   */
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.playerViewModel.songCoverUrl().length > 0 ?
        this.playerViewModel.songCoverUrl() : this.playerViewModel.songCover())
        .width(this.coverSideLengthVp())
        .height(this.coverSideLengthVp())
        .borderRadius(this.coverBorderRadiusVp())
      if (!this.isImmersiveFreeWindowCover()) {
        Progress({
          value: this.playerViewModel.appState.progress,
          total: this.progressTotal(),
          type: ProgressType.Ring
        })
          .width(this.coverSideLengthVp())
          .height(this.coverSideLengthVp())
          .backgroundColor($r('app.color.mini_bar_cover_ring_track'))
          .color($r('app.color.mini_bar_cover_ring_progress'))
          .style({ strokeWidth: '1.8vp' })
      }
      if (this.playerViewModel.appState.isPlay) {
        SymbolGlyph($r('sys.symbol.rhythm'))
          .fontSize(this.isImmersiveFreeWindowCover() ? 14 : 24)
          .fontWeight(FontWeight.Regular)
          .height(this.isImmersiveFreeWindowCover() ? 14 : 24)
          .fontColor([$r('app.color.mini_bar_cover_rhythm_glyph')])
      }
    }
    .padding(this.isImmersiveFreeWindowCover() ? { top: 8, bottom: 8, left: 32 } : { top: 6, bottom: 6, left: 6 })
  }
}
