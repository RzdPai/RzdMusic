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
import { AppStorageKeys, BreakpointType, MINI_BAR_FLOATING_ID, PlayerExpandState, StyleConstants } from 'musicbasic';
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
  /**
   * 整页形变状态：只读"迷你条该淡到多少"（对标无界 `MiniMorph.alpha = 1 - p/0.20`）。
   * 播放页那条可视矩形就是从这条迷你条的封面位置长出来的，迷你条不让位，
   * 前 20% 就是"一条迷你条右边窜出个方块"。静止态恒返回 1。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /** When true, the aside shows a previous-track button. */
  @Param showPreviousTrack: boolean = false;
  /**
   * When false, row padding ignores global expand (always “collapsed�?row inset on list).
   * Playlist cover image size is handled in MiniBarAlbumCover when this is false.
   */
  @Param followAppMiniBarExpanded: boolean = true;
  /** 上拉打开播放页（跟手）：驱动共享形变进度，收尾补间交给壳层。 */
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  private effectiveMiniBarExpanded(): boolean {
    return this.followAppMiniBarExpanded && this.playerViewModel.appState.miniBarExpanded;
  }

  private schedulePullAnchorRemeasure(attempt: number = 0): void {
    if (attempt >= 12) {
      return;
    }
    const gen: number = this.expandState.morphGen;
    setTimeout((): void => {
      if (!this.expandState.pullDragging || !this.expandState.morphGenAlive(gen)) {
        return;
      }
      if (!this.expandState.measureMiniDuringPull(this.getUIContext(), true)) {
        this.schedulePullAnchorRemeasure(attempt + 1);
      }
    }, 32);
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
        // 操作区：`MiniMorph.actionsOpacityAt = clamp(1 - t/0.20)`，比封面那档更早消失
        .opacity(this.expandState.miniBarOpacity())
    }
    .padding({
      left: this.effectiveMiniBarExpanded() ? 6 : 0,
      right: this.effectiveMiniBarExpanded() ? 16 : 16,
      top: this.effectiveMiniBarExpanded() ? 6 : 0,
      bottom: this.effectiveMiniBarExpanded() ? 6 : 0,
    })
    .alignItems(VerticalAlign.Center)
    .width(StyleConstants.FULL_WIDTH)
    // 展开形变的**起点矩形**就是这条胶囊：给个 id 让 `getFrameNodeById` 量它
    .id(MINI_BAR_FLOATING_ID)
    // ⚠️ 不要给整条 Row 加透明度：两档淡出（操作区 0.20 / 封面元信息 0.35）分别在
    //    `MiniBarPlayerAside` 与 `MiniBarAlbumCover` 上生效，这里再叠一份就分不出先后了。
    // 上拉打开播放页：**跟手**（手指每动一帧写一次形变进度），松手只发收尾请求 ——
    // 补间与挂载/卸载只有壳层能做（它拥有 isShowPlay）。见 PlayerExpandState.pullOpenBegin。
    .gesture(
      PanGesture(this.panOption)
        .onActionStart((): void => {
          if (this.appState.isShowPlay) {
            return;
          }
          const ok: boolean = this.expandState.pullOpenBegin(this.getUIContext(), true);
          if (!this.appState.isShowPlay) {
            this.appState.isShowPlay = true;
          }
          if (!ok) {
            this.expandState.pullDragging = false;
            this.expandState.morphReset();
            this.expandState.morphSettleOpen();
            return;
          }
          this.schedulePullAnchorRemeasure();
        })
        .onActionUpdate((event: GestureEvent): void => {
          if (!this.expandState.pullDragging) {
            return;
          }
          this.expandState.applyMorphProgress(this.expandState.pullOpenFraction(event.offsetY));
        })
        .onActionEnd((event: GestureEvent): void => {
          if (!this.expandState.pullDragging) {
            return;
          }
          this.expandState.requestPullOpenSettle(
            this.expandState.pullOpenFraction(event.offsetY) >= 0.45);
        })
        .onActionCancel((): void => {
          if (!this.expandState.pullDragging) {
            return;
          }
          this.expandState.requestPullOpenSettle(false);
        })
    )
    // 点一下也能打开（拖动与点击是两类手势，不会互相抢）
    .onClick((): void => {
      this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
    })
  }
}
