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
import {
  AppStorageKeys,
  BarLayoutModes,
  ImmersiveType,
  MINI_BAR_COVER_ID,
  MusicAppState,
  SdkApiUtil,
  SdkConstants,
  getWindowInfoState,
  WindowInfo
} from 'musicbasic';
import { PlayerConstants, PlayerViewModel } from 'player';

/** 迷你条封面的组件 id（常量定义已提到 common 层，见 PlayerExpandState.ets）。 */
export { MINI_BAR_COVER_ID } from 'musicbasic';

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
  /**
   * 锁定封面为「双层底栏 · 上下两排 · 折叠态」的尺寸（30vp）。
   *
   * 二级页面的悬浮胶囊要和**首页底栏双层时上面那条**长得一模一样，那一条在
   * 上下两排时封面就是 30vp；但这个尺寸正常是靠 `isTwoRowBarLayout()` 读 HDS 栏排布
   * 算出来的，而二级页面根本没有底栏，读到的值不可靠 —— 所以由调用方直接锁定。
   */
  @Param lockTwoRowCoverSize: boolean = false;
  /** Window info for immersive vs standard mini bar layout. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** 全局播控状态：双层底栏「上下两排」时封面收缩到 30vp。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;

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
   * 双层底栏是否处于「上下两排」：此时迷你条只占半排，封面需要收缩到 30vp，
   * 否则会把页签那一排挤出去（musicfreeOH 的同款处理）。
   * @returns True when the HDS bar is in two-row (VERTICAL) layout.
   */
  private isTwoRowBarLayout(): boolean {
    if (!this.followAppMiniBarExpanded) {
      return false;
    }
    if (!SdkApiUtil.isDistributionOsApiAtLeast(SdkConstants.DISTRIBUTION_OS_6_1_1_CODE)) {
      return false;
    }
    return this.appState.hdsBarLayoutMode === BarLayoutModes.VERTICAL;
  }

  /**
   * @returns Album cover width/height in vp for current immersive and expand state.
   */
  private coverSideLengthVp(): number {
    if (this.isImmersiveFreeWindowCover()) {
      return 32;
    }
    if (this.lockTwoRowCoverSize || this.isTwoRowBarLayout()) {
      return 30;
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
    if (this.lockTwoRowCoverSize || this.isTwoRowBarLayout()) {
      return 30;
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
        .id(MINI_BAR_COVER_ID)
        .width(this.coverSideLengthVp())
        .height(this.coverSideLengthVp())
        .borderRadius(this.coverBorderRadiusVp())
        // 上下两排 <-> 单排切换时封面尺寸平滑过渡（30 <-> 44），不要瞬跳
        .animation({ duration: 500, curve: Curve.Smooth })
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
