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
 * Mini player album art with optional ring progress and play icon overlay.
 */
@ComponentV2
export struct HomeMiniBarAlbumCover {
  /** Player VM providing cover URI, progress, and play/expand state. */
  @Param playerViewModel: PlayerViewModel = new PlayerViewModel();
  /**
   * Home HDS: cover image 56vp when bar collapsed, 44vp when expanded.
   * Embedded (`false`): cover image always 44vp.
   */
  @Param followAppMiniBarExpanded: boolean = true;
  /** Window info for immersive vs standard mini bar layout. */
  @Local windowInfo: WindowInfo = getWindowInfoState();

  /**
   * @returns Progress denominator for the ring; at least 1 to avoid division issues.
   */
  private progressTotal(): number {
    const max = this.playerViewModel.appState.progressMax;
    return max > 0 ? max : 1;
  }

  /**
   * @returns True when window uses immersive decor (compact title-area treatment).
   */
  private isImmersiveFreeWindowCover(): boolean {
    return this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE;
  }

  private effectiveMiniBarExpanded(): boolean {
    return this.followAppMiniBarExpanded && this.playerViewModel.appState.miniBarExpanded;
  }

  /** Cover image side / radius only (ring matches): list/embedded 44vp; home 56vp iff collapsed. */
  private isCompactMiniBarCover(): boolean {
    return !this.followAppMiniBarExpanded || this.playerViewModel.appState.miniBarExpanded;
  }

  /**
   * @returns Album cover width/height in vp for current immersive and expand state.
   */
  private coverSideLengthVp(): number {
    if (this.isImmersiveFreeWindowCover()) {
      return 32;
    }
    return this.isCompactMiniBarCover() ? 44 : 56;
  }

  /**
   * @returns Corner radius in vp matching the square side length logic.
   */
  private coverBorderRadiusVp(): number {
    if (this.isImmersiveFreeWindowCover()) {
      return 8;
    }
    return this.isCompactMiniBarCover() ? 44 : 56;
  }

  /**
   * Stacks cover image, optional ring progress, and rhythm icon.
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
          .blendMode(BlendMode.OVERLAY)
      }
      if (this.playerViewModel.appState.isPlay) {
        SymbolGlyph($r('sys.symbol.rhythm'))
          .fontSize(this.isImmersiveFreeWindowCover() ? 14 : 24)
          .fontWeight(FontWeight.Regular)
          .height(this.isImmersiveFreeWindowCover() ? 14 : 24)
          .fontColor([$r('app.color.mini_bar_cover_rhythm_glyph')])
      }
    }
  }
}
