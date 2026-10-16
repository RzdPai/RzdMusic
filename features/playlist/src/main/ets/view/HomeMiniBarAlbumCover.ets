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
  PlayerExpandState,
  SdkApiUtil,
  SdkConstants,
  areaLengthToVp,
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
  /** 共享展开几何：迷你条封面要把自己的窗口矩形上报进去（展开动画的起点端点）。 */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

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

  /** Only the short two-row cover shifts; the tall single-row cover keeps its original position. */
  private coverOffsetXVp(): number {
    // 用户反馈（双层底栏的矮播放条）：-4vp 还是略微偏右，再往左挪一点点（-6vp 合计）。
    return !this.isImmersiveFreeWindowCover() && (this.lockTwoRowCoverSize || this.isTwoRowBarLayout()) ? -6 : 0;
  }

  /**
   * @returns Album cover width/height in vp for current immersive and expand state.
   *
   * ★★ 2026-10-15（修用户实测「**无界的播放条更粗一些**」）：
   *   无界 `MiniPlayer` 的胶囊内容高度是 **56vp**（逆向定稿：
   *   `MiniPlayer胶囊布局与宽度约束.md` §八 + `播放条三形态完整UI.md` §1.8.1 ——
   *   `sidePad() = h/2 − coverEdge()/2`，折叠态 `h = BAR_CONTENT_H(40) × 1.4 = 56`，
   *   `coverEdge() = 40 × MINI_COVER_RATIO(0.8) = 32` ⇒ `sidePad = 12`，即
   *   **32 内容 + 12×2 内边距 = 56**）。
   *
   *   我们这条原来在沉浸式自由窗口（= 这台机器）下给的是 **32**（真正的内容高），
   *   ⇒ 内容行只有 32vp，HDS 的 56vp 槽位里上下各空 12vp ⇒ **观感明显比无界细一圈**。
   *   ⇒ 把"沉浸式自由窗口"这一档的封面从 32 提到 **40**（内容高），
   *     再由 `HomeMiniBarPlayer` 的上下各 8vp 内边距补成 **56** ⇒ 与无界同厚。
   *   ⚠️ 只改**这一档**（`isImmersiveFreeWindowCover`）：下面那两档（44 / 30）是
   *      首页双层底栏与二级页锁定档，与"播放条更粗"这条反馈无关，**一个字不动**。
   *   ⚠️ 圆角仍按"封面边长"给（同一档返回同一个数 ⇒ 圆形封面），见 {@link coverBorderRadiusVp}。
   */
  private coverSideLengthVp(): number {
    if (this.isImmersiveFreeWindowCover()) {
      return 40;
    }
    if (this.lockTwoRowCoverSize || this.isTwoRowBarLayout()) {
      return 30;
    }
    return this.isCompactMiniBarCover() ? 44 : 56;
  }

  /**
   * @returns Corner radius in vp matching the square side length logic.
   *
   * ⚠️ 沉浸式自由窗口那一档原来返回的是 **8**（一个固定圆角）—— 那是早期"圆角封面还没定"
   *    的遗留值，与另一档"圆角 = 边长"（圆形封面）**不是同一种封面形状**。
   *    本轮把这一档也统一成**圆角 = 边长**（与迷你条在播放页形变里被当成"小圆片"的观感一致），
   *    它是**同一个函数的三个分支必须同形**这条既有约定的最后一块（见 `MiniBarAlbumCover` 的同名方法）。
   */
  private coverBorderRadiusVp(): number {
    if (this.isImmersiveFreeWindowCover()) {
      return 40;
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
        // 把迷你条封面的窗口矩形报给共享状态：它是"展开动画"的起点端点。
        // 与播放页大封面的 reportBig 配对，两个端点齐了以后整页形变才有依据。
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.expandState.reportMini(
            areaLengthToVp(newValue.globalPosition.x) + this.coverOffsetXVp(),
            areaLengthToVp(newValue.globalPosition.y),
            areaLengthToVp(newValue.width),
            this.coverBorderRadiusVp());
        })
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
    // 形变期间按反编译的 `MiniMorph.metaOpacityAt = clamp(1 - t/0.35)` 淡出：
    // 封面这一档比右侧按钮（`actionsOpacityAt = 1 - t/0.20`）**晚**消失，
    // 观感就是用户描述的"按钮先没、文字/封面后没"。
    .opacity(this.expandState.miniBarMetaOpacity())
    .translate({ x: this.coverOffsetXVp() })
    .onAreaChange((): void => {
      console.info('[RzdMiniCoverLayout] twoRow=' + this.isTwoRowBarLayout() +
        ' lockedShort=' + this.lockTwoRowCoverSize + ' offsetX=' + this.coverOffsetXVp());
    })
  }
}
