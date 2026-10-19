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

import { PlayerConstants, PlayerViewModel, QueuePlaylistSheet } from 'player';
import { Logger } from 'musicbasic';

/**
 * 迷你播放条的**操作区**（上游 `MiniPlayer` 胶囊 `Row` 的第二个直接子节点）。
 *
 * ══════════════════ 为什么单独成一个组件（2026-10-18 照搬上游） ══════════════════
 *
 * 上游组件树（`wujie.pa:69128-69474`）：
 * ```
 * Row({ space: 4 })                                     ← 胶囊本体
 *   ├ Row({space:0}).layoutWeight(1)                    ← 左段：封面 + meta
 *   └ Row({space: MINI_ACT_GAP}).id(actionsNodeId)      ← **操作区：胶囊的直接子节点，无 layoutWeight**
 * ```
 * 本仓原来把操作区套在 `HomeMiniBarPlayerAside`（`layoutWeight(1)`）**里面**，
 * 于是它跟着 Aside 的盒子走、不吃胶囊的右内距 —— 右端那颗「播放列表」按钮会压到胶囊圆角外。
 * ⇒ 拆成本组件，由 `HomeMiniBarPlayer` 按上游摆成"左段(weight 1) + 操作区(固有宽)"两个直接子节点。
 *
 * ══════════════════ 逐条照搬的规格 ══════════════════
 * · 每颗按钮 = **40 × 40 的 `Stack`** 包一颗 `SymbolGlyph(fontSize 24)`，`clickEffect({level: LIGHT})`
 *   （`:69480-69573`）；`SymbolGlyph` **只有** `fontSize` + `fontColor`，没有 `width/height`。
 * · 按钮间距 = `MINI_ACT_GAP = 2`。
 * · 操作区 `Row` **不给 `layoutWeight`、不给 `width`**：按固有宽度先占位，被压缩的永远是左侧文字。
 * · 尾部留白 6vp 是用户 2026-10-12「右边三个按钮往左移动一点」的自定需求（上游没有），保留。
 * · 面板沿用既有 `QueuePlaylistSheet({ isShow, onDismiss })`，与改动前同一个用法
 *   （它是自绘半模态，外层不再套 `bindSheet`）。
 */
@ComponentV2
export struct MiniBarActions {
  /** 播放器 VM（图标状态与点击行为都来自它）。 */
  @Param playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** 是否显示"上一首"（缺省不显示，与上游三形态一致）。 */
  @Param showPreviousTrack: boolean = false;
  /** 操作区在形变期的整体不透明度（上游 `MiniMorph.actionsOpacityAt`）。 */
  @Param actionsOpacity: number = 1;
  /** 本组件自己的节点 id（形变起点锚点 / 克隆层锚点）。 */
  @Param actionsNodeId: string = '';
  /** V12: hide paint only; retain the source cluster's measured layout. */
  @Param paintHidden: boolean = false;
  /** 队列半模态开关。 */
  @Local showPlaylistSheet: boolean = false;
  /** 操作按钮簇右侧的留白（vp）：用户自定需求，见类注释。 */
  private static readonly ACTIONS_TRAIL_GAP_VP: number = 6;

  /**
   * 一颗操作按钮（上游 `:69480-69522` + `:69528-69573`）。
   * @param icon 符号资源
   * @param color 图标颜色
   * @param action 点击回调
   */
  @Builder
  private ActionButton(icon: Resource, color: ResourceColor, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph(icon)
        .fontSize(PlayerConstants.MINI_ACT_ICON)
        .fontWeight(FontWeight.Regular)
        .fontColor([color])
    }
    .width(PlayerConstants.MINI_ACT_SIZE)
    .height(PlayerConstants.MINI_ACT_SIZE)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(() => {
      action();
    })
  }

  /**
   * 操作区：三颗按钮按上游顺序（可选的"上一首" → 播放/暂停 → 下一首 → 播放列表）。
   */
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row({ space: PlayerConstants.MINI_ACT_GAP }) {
        if (this.showPreviousTrack) {
          this.ActionButton($r('sys.symbol.backward_end_fill'), $r('app.color.mini_bar_primary'), (): void => {
            this.playerViewModel.playPrevious();
          })
        }
        // ★★★ 2026-10-18（用户：「点暂停/播放，歌会停/放，但按钮样式不刷新」）：
        //   根因**不是**状态没变（`MusicAppState.isPlay` 是 `@Trace`，`MediaService.updateIsPlay`
        //   在 `stateChange` 里逐次回写），而是**图标走了 `@Builder` 的按值传参**：
        //   官方《@Builder 参数传递》——「按值传递时，状态变量的改变不会引起 @Builder 内的 UI 刷新」。
        //   原来写成 `this.ActionButton(this.playerViewModel.appState.isPlay ? A : B, ...)`：
        //   三目在**调用点**就求值成一个 `Resource` 传进去，`isPlay` 变化时那个 `SymbolGlyph`
        //   没有任何依赖登记 ⇒ 图标永远停在首次渲染的那一张。
        //   ⇒ 播放/暂停这颗**必须**在 `build()` 里直接读状态（与 `PlaylistLaneListSection`
        //     `SymbolGlyph(this.listVm.appState.isPlay ? …)` 同款写法），不能再走 builder 参数。
        //   其余三颗图标是常量、不随状态变，留在 `ActionButton` 里没问题。
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph(this.playerViewModel.appState.isPlay ?
            $r('sys.symbol.pause_round_triangle_fill') :
            $r('sys.symbol.play_round_triangle_fill'))
            .fontSize(PlayerConstants.MINI_ACT_ICON)
            .fontWeight(FontWeight.Regular)
            .fontColor([$r('app.color.icon_primary')])
        }
        .width(PlayerConstants.MINI_ACT_SIZE)
        .height(PlayerConstants.MINI_ACT_SIZE)
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .onClick((): void => {
          this.playerViewModel.togglePlayPause();
        })
        this.ActionButton($r('sys.symbol.forward_end_fill'), $r('app.color.mini_bar_primary'), (): void => {
          this.playerViewModel.playNext();
        })
        this.ActionButton($r('sys.symbol.music_note_list'), $r('app.color.icon_primary'), (): void => {
          this.showPlaylistSheet = true;
        })
      }
      .height(PlayerConstants.MINI_ACT_SIZE)
      .alignItems(VerticalAlign.Center)
      .margin({ right: MiniBarActions.ACTIONS_TRAIL_GAP_VP })
      .opacity(this.actionsOpacity)

      QueuePlaylistSheet({
        isShow: this.showPlaylistSheet,
        onDismiss: (): void => {
          this.showPlaylistSheet = false;
        }
      })
    }
    // Measure the complete cluster, including the Row's 6vp trailing margin.
    // Source and clone now anchor the same component root (no nested margin replay).
    .id(this.actionsNodeId)
    .visibility(this.paintHidden ? Visibility.Hidden : Visibility.Visible)
    .onAreaChange((): void => {
      this.logHandoffRect();
    })
  }

  @Monitor('paintHidden', 'playerViewModel.appState.isPlay')
  onPaintOwnerChanged(): void {
    this.logHandoffRect();
  }

  private logHandoffRect(): void {
    if (this.actionsNodeId.length === 0) {
      return;
    }
    try {
      const ui: UIContext = this.getUIContext();
      const rect = ui.getComponentUtils().getRectangleById(this.actionsNodeId);
      Logger.info('RzdActionsHandoffV12',
        `kind=measured id=${this.actionsNodeId} hidden=${this.paintHidden} ` +
          `rect=${ui.px2vp(rect.windowOffset.x)},${ui.px2vp(rect.windowOffset.y)},` +
          `${ui.px2vp(rect.size.width)},${ui.px2vp(rect.size.height)} ` +
          `isPlay=${this.playerViewModel.appState.isPlay} iconFp=${PlayerConstants.MINI_ACT_ICON} ` +
          `buttonVp=${PlayerConstants.MINI_ACT_SIZE} gapVp=${PlayerConstants.MINI_ACT_GAP}`);
    } catch (error) {
      Logger.warn('RzdActionsHandoffV12', `kind=measure-miss id=${this.actionsNodeId} error=${error}`);
    }
  }
}
