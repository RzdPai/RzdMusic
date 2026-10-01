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
import { AppStorageKeys, MINI_BAR_ID, PlayerExpandState, StyleConstants } from 'musicbasic';
import { MusicAppState, PlayerConstants, PlayerViewModel } from 'player';
import { HomeMiniBarAlbumCover } from './HomeMiniBarAlbumCover';
import { HomeMiniBarPlayerAside } from './HomeMiniBarPlayerAside';

/**
 * Mini player shell: album cover with shared-element id, aside controls, padding by expand state,
 * vertical pan to full screen.
 */
@ComponentV2
export struct HomeMiniBarPlayer {
  /** Player VM shared with cover and aside. */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** Global music UI state (mini bar expanded, play state). */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /**
   * 整页形变状态：只用来读"迷你条该淡到多少"（对标无界 `MiniMorph.alpha = 1 - p/0.20`）。
   *
   * 为什么迷你条要让位：播放页那条可视矩形是从**迷你条封面**的位置长出来的，
   * 前 20% 只有封面的一两倍宽，而整条迷你条（封面 + 歌名 + 按钮）有 300 多 vp ——
   * 不让位就是"一条迷你条右边窜出个方块"，不是无界那种"播放条逐渐变大"。
   * 静止态它恒返回 1，所以不展开时逐像素不变。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  /** Passed through to {@link HomeMiniBarPlayerAside} to toggle previous-track visibility. */
  @Param showPreviousTrack: boolean = false;
  /**
   * When false, row padding ignores global expand (list-style inset).
   * Cover image sizing is adjusted in HomeMiniBarAlbumCover.
   */
  @Param followAppMiniBarExpanded: boolean = true;
  /**
   * 锁定封面为 44vp（单排折叠态）。二级页面悬浮胶囊在外层固定了 56vp 高度，
   * 封面必须跟着固定，否则 HDS 栏排布变化会把封面缩到 30vp。
   */
  @Param lockTwoRowCoverSize: boolean = false;
  /** 上拉打开播放页（跟手）：驱动共享形变进度，收尾补间交给壳层。 */
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  /**
   * 上拉起手后补量终点锚点的重试次数 / 间隔（ms）。
   *
   * 与 `PlaybackPage` 的 12 × 32ms 是同一个窗口（对标反编译 `schedulePublishRetry`）：
   * 播放页是起手那一刻才挂载的，"它的大封面什么时候可量"取决于布局帧数。
   */
  private static readonly PULL_ANCHOR_RETRY_MAX: number = 12;
  private static readonly PULL_ANCHOR_RETRY_MS: number = 32;

  private effectiveMiniBarExpanded(): boolean {
    return this.followAppMiniBarExpanded && this.playerViewModel.appState.miniBarExpanded;
  }

  /**
   * 上拉起手后补量"续飞封面"的终点锚点。
   *
   * 播放页是**起手那一刻**才挂载的，所以第一帧量不到它的大封面（`getFrameNodeById` 返回空）。
   * 反编译侧靠 `onPullReady` 回调补量；这里用同样的窗口（12 × 32ms）轮询，
   * 一旦量到就按当前进度重落几何（`measureMiniDuringPull` 内部做），
   * 于是"手指已经拖到一半、封面才出现"也能立刻接上，不会一直缺这一棒。
   * @param attempt 已经尝试过的次数
   */
  private schedulePullAnchorRemeasure(attempt: number): void {
    if (attempt >= HomeMiniBarPlayer.PULL_ANCHOR_RETRY_MAX) {
      return;
    }
    const gen: number = this.expandState.morphGen;
    setTimeout((): void => {
      // 手势已经收尾 / 页面已卸载 / 换了一轮形变：不再补量
      if (!this.expandState.pullDragging || !this.expandState.morphGenAlive(gen)) {
        return;
      }
      if (this.expandState.measureMiniDuringPull(this.getUIContext(), false)) {
        return;
      }
      this.schedulePullAnchorRemeasure(attempt + 1);
    }, HomeMiniBarPlayer.PULL_ANCHOR_RETRY_MS);
  }

  /**
   * @returns 胶囊的**左**内边距（vp）：`高度/2 − 封面边长/2`。
   *
   * 这是逆向规格里 `MiniPlayer.sidePad` 的原式（`MiniPlayer胶囊布局与宽度约束.md` §三）：
   * 语义是"让封面在胶囊里垂直居中、且封面左边缘与内边距左边缘对齐"。
   * 折叠态高度 `40 × 1.4 = 56`、封面 `40 × 0.8 = 32` ⇒ `sidePad = 12`。
   */
  private sidePadVp(): number {
    const h: number = this.effectiveMiniBarExpanded()
      ? PlayerConstants.MINI_BAR_CONTENT_H
      : PlayerConstants.MINI_BAR_CONTENT_H * PlayerConstants.MINI_BAR_COLLAPSED_RATIO;
    const cover: number = PlayerConstants.MINI_BAR_CONTENT_H * PlayerConstants.MINI_COVER_RATIO;
    return h / 2 - cover / 2;
  }

  /**
   * @returns 胶囊的**右**内边距（vp）：`sidePad() + （未量到高度时的 MINI_EDGE_PAD）`。
   *
   * ⚠️ 左右**不对称**是规格里就有的（反编译 `actionsTrail()`；`capsuleH` 已量到时为 0 增量
   *    = 左右相等，未量到时右侧多 10vp）。这里我们没有"capsuleH 已量到"这个信号，
   *    一律按折叠态那一档给（这也是首页迷你条的常态）。
   *    **绝不能在右侧额外加 16 之类的大值** —— 之前右侧给 16、左侧给 6，
   *    右侧那 16vp 会和按钮簇抢宽度，把"播放列表"按钮挤出可见胶囊。
   */
  private actionsTrailVp(): number {
    const expanded: boolean = this.effectiveMiniBarExpanded();
    const extra: number = expanded ? 0 : PlayerConstants.MINI_EDGE_PAD;
    return this.sidePadVp() + extra;
  }

  /**
   * Composes cover and aside in a row with gesture to open the full player on upward pan.
   */
  build() {
    Row({ space: 8 }) {
      HomeMiniBarAlbumCover({
        playerViewModel: this.playerViewModel,
        followAppMiniBarExpanded: this.followAppMiniBarExpanded,
        lockTwoRowCoverSize: this.lockTwoRowCoverSize
      })
      HomeMiniBarPlayerAside({
        playerViewModel: this.playerViewModel,
        showPreviousTrack: this.showPreviousTrack,
        floatingMeta: !this.followAppMiniBarExpanded
      })
        // 操作区：`MiniMorph.actionsOpacityAt = clamp(1 - t/0.20)`，比封面那档更早消失
        .opacity(this.expandState.miniBarOpacity())
    }
    // ★ 非对称内边距（照抄逆向规格 `MiniPlayer.sidePad / actionsTrail`）：
    //   左 = 高度/2 − 封面/2（让封面贴住内容左边缘、垂直居中），右 = 左 + 折叠态 10vp。
    //   ⚠️ 原来折叠态给的是 `BreakpointType(16,24,32,32)`（左右**完全对称**且大到 32vp），
    //      横向净宽被吃掉 64vp，右边那 32vp 正好压在按钮簇上 —— 这是"列表按钮被挤出播放条"
    //      的另一半原因（见 `MiniPlayer胶囊布局与宽度约束.md` 第六节第 2、3 条）。
    .padding({
      left: this.sidePadVp(),
      right: this.actionsTrailVp(),
      top: 6,
      bottom: 6,
    })
    .alignItems(VerticalAlign.Center)
    .width(StyleConstants.FULL_WIDTH)
    // 展开形变的**起点矩形**就是这条胶囊：给个 id 让 `getFrameNodeById` 量它
    //（`onAreaChange` 给的是布局几何、不含祖先 transform，量出来的起点会偏）
    .id(MINI_BAR_ID)
    .visibility(this.expandState.sourceBarHidden ? Visibility.Hidden : Visibility.Visible)
    // ⚠️ 这里**不要**给整条 Row 加透明度：反编译里迷你条是**两档**淡出 ——
    //    右侧操作区 `1 - t/0.20` 先没、封面/元信息 `1 - t/0.35` 后没。
    //    两档分别在 `HomeMiniBarPlayerAside` 与 `HomeMiniBarAlbumCover` 上生效，
    //    在 Row 上加一份会把封面也按 0.20 提前淡掉（就分不出先后了）。
    // ⚠️ 上拉打开播放页：**跟手** —— 手指每动一帧就写一次形变进度。
    //    以前这条手势只在 `onActionEnd` 里"一次性打开"，所以手指拖动期间画面纹丝不动，
    //    用户实测的「只能上拉完成后，不能跟手」就是这个。
    //    现在：起手量几何 + 压到起点 → 更新写进度 → 松手只发"收尾请求"
    //    （补间与挂载/卸载只有壳层能做，它拥有 `isShowPlay`）。
    //    壳层根节点上还有一条同样的手势兜底（从别处起手也能上拉）：谁接到谁驱动，
    //    几何与进度是同一份，不会打架。
    .gesture(
      PanGesture(this.panOption)
        .onActionStart((): void => {
          if (this.appState.isShowPlay) {
            return;
          }
          const ok: boolean = this.expandState.pullOpenBegin(this.getUIContext(), false);
          if (!this.appState.isShowPlay) {
            this.appState.isShowPlay = true;
          }
          if (!ok) {
            this.expandState.pullDragging = false;
            this.expandState.morphReset();
            this.expandState.morphSettleOpen();
            return;
          }
          // ★ 起手这一刻播放页**刚挂载**，它的封面节点还没布局完（量不到）——
          //   而"续飞封面"的终点正是它。补量几次（对标反编译 `onPullReady` 回调里那次补量），
          //   免得手指一路往上拖、屏上却只有底色窗口在长大、一张封面都看不到。
          //   补量成功后就按当前进度重落一次几何，收尾时不会跳。
          this.schedulePullAnchorRemeasure(0);
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
