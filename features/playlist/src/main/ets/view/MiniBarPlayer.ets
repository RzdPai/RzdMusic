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

  /**
   * 补量终点锚点的重试次数 / 间隔（ms）。
   *
   * 与 `HomeMiniBarPlayer` 的 `PULL_ANCHOR_RETRY_MAX / PULL_ANCHOR_RETRY_MS`、
   * 以及 `PlaybackPage` 的 12 × 32ms 是**同一个窗口**（对标反编译 `schedulePublishRetry`）。
   * ★ 2026-10-15：本文件原来是**写死的两个字面量**（`12` / `32`），
   *   与 `HomeMiniBarPlayer` 的具名常量重复；改成具名常量只为让三处副本好对账
   *   （`派音动画Bug清单.md` P1-10 的判据就是"三处签名/常量应完全一致"）。**值一个字没改。**
   */
  private static readonly PULL_ANCHOR_RETRY_MAX: number = 12;
  private static readonly PULL_ANCHOR_RETRY_MS: number = 32;

  private effectiveMiniBarExpanded(): boolean {
    return this.followAppMiniBarExpanded && this.playerViewModel.appState.miniBarExpanded;
  }

  /**
   * 上拉起手后补量"续飞封面"的终点锚点（12 × 32ms 轮询，对标反编译侧的 `onPullReady` 补量）。
   *
   * ★★ 2026-10-15（`派音动画Bug清单.md` **P1-10**）：本方法是同一份逻辑的**三个副本之一**
   *    （另两个：`HomeMiniBarPlayer.ets` 与壳层 `products/default/.../Index.ets:565`）。
   *    原来只有这里带默认值 `= 0`；本轮把默认值与"非有限数直接返回"这条护栏补齐到
   *    `HomeMiniBarPlayer`，并把下面那个写死的 `12` 换成与本文件同一个常量的写法。
   *    ⚠️ 壳层那一份属禁区文件，**本轮没动**（见本轮报告"需要壳层配合的条目"）。
   * @param attempt 已经尝试过的次数（默认 0；非有限数一律直接返回，避免 `NaN` 递归成死循环）
   */
  private schedulePullAnchorRemeasure(attempt: number = 0): void {
    if (!Number.isFinite(attempt) || attempt >= MiniBarPlayer.PULL_ANCHOR_RETRY_MAX) {
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
    }, MiniBarPlayer.PULL_ANCHOR_RETRY_MS);
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
    // ★★ 2026-10-15（照搬无界 `squashLand`）：关闭落位时胶囊挤压回弹 ——
    //   与 `HomeMiniBarPlayer` 那一处**同一把标量、同一个语义**（静止态恒为 1）。
    //   两处都挂的理由与"三条迷你条各自持有手势"一致：屏幕上同一时刻只渲染其中一条，
    //   但**哪一条在渲染取决于导航栈深度**（首页底栏 / 二级页悬浮条），不能只改一处。
    .scale({ x: 1, y: this.expandState.morphSquashY })
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
          // ★ 壳层浮层那份续飞封面（`Index.MorphCoverClone`）也压回起点：
          //   它有自己的进度 `morphOverlayP`（静止态初值是 1），不压回 0 的话
          //   浮层的第一帧会按"落位的大封面"画一次。
          this.expandState.morphOverlayReset();
        })
        .onActionUpdate((event: GestureEvent): void => {
          if (!this.expandState.pullDragging) {
            return;
          }
          this.expandState.applyMorphProgress(this.expandState.pullOpenFraction(event.offsetY));
          // 跟手期壳层浮层必须与播放页同值（否则松手补间时会先跳一下浮层那个进度）
          this.expandState.syncMorphOverlayFromPage();
        })
        .onActionEnd((event: GestureEvent): void => {
          if (!this.expandState.pullDragging) {
            return;
          }
          // ★ 提交判据**只有一份**：`PlayerExpandState.pullOpenShouldCommit()`
          //   （清单 §一 1.2「进度 OR 速度」）—— 原来这里只判 `>= 0.45`，
          //   "位移不大但甩得很快"打不开。判据收敛后，两条迷你条 + 壳层三处一致。
          this.expandState.requestPullOpenSettle(
            this.expandState.pullOpenShouldCommit(this.expandState.morphP,
              event.offsetY, event.velocityY));
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
