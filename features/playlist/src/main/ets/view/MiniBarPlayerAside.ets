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

import { PlayerConstants, PlayerViewModel } from 'player';
import { MINI_BAR_ASIDE_FLOATING_ID } from 'musicbasic';


/**
 * Mini player row: title, artist, transport controls, and playlist shortcut beside the cover.
 */
@ComponentV2
export struct MiniBarPlayerAside {
  /** Navigation stack consumed from the parent for pushing playlist detail. */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Player state and actions for the current track. */
  @Param playerViewModel: PlayerViewModel = new PlayerViewModel();

  /** When true, shows the previous-track control in the control cluster. */
  @Param showPreviousTrack: boolean = false;
  /**
   * 元信息（歌名/歌手）那一块的不透明度：真实迷你条恒为 1；
   * 形变克隆层按反编译的 `MiniMorph.metaOpacityAt = clamp(1 - t/0.35)` 传值
   * （比操作区的 0.20 晚消失 —— "按钮先没、文字后没"）。
   */
  @Param metaOpacity: number = 1;
  /**
   * 元信息那一块的横向位移（vp）：反编译 `MiniMorph.coverRightShiftAt(t)`，
   * 封面长大后把歌名/歌手往右推。真实迷你条上恒为 0。
   */
  @Param metaShiftX: number = 0;

  /**
   * Builds title, subtitle, play/pause, skip, optional previous, and queue actions.
   */
  build() {
    Row() {
      Column() {
        Text(this.playerViewModel.songTitle())
          .fontColor($r('app.color.mini_bar_primary'))
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .lineHeight(16)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.playerViewModel.songSinger())
          .fontColor($r('app.color.primary60'))
          .fontSize($r('sys.float.Caption_S'))
          .lineHeight(13)
          .fontWeight(FontWeight.Regular)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(PlayerConstants.LAYOUT_WEIGHT_PLAYER_CONTROL)
      // 允许被压缩到 0：空间不够时先挤歌名，按钮簇必须留在条内（异型屏兜底）
      .constraintSize({ minWidth: 0 })
      // 元信息那一档的透明度（真实迷你条恒 1，克隆层按 metaOpacityAt 传值）
      .opacity(this.metaOpacity)
      // 被封面"推着往右走"（反编译 λ1e）；真实迷你条恒 0
      .translate({ x: this.metaShiftX })
      .onClick(() => {
        this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
      })

      Row({ space: 16 }) {
        if (this.showPreviousTrack) {
          SymbolGlyph($r('sys.symbol.backward_end_fill'))
            .fontSize(24)
            .fontWeight(FontWeight.Regular)
            .height(24)
            .fontColor([$r('app.color.mini_bar_primary')])
            .displayPriority(3)
            .onClick(() => {
              this.playerViewModel.playPrevious();
            })
        }

        SymbolGlyph(this.playerViewModel.appState.isPlay ?
          $r('sys.symbol.pause_round_triangle_fill') :
          $r('sys.symbol.play_round_triangle_fill'))
          .fontSize(24)
          .fontWeight(FontWeight.Regular)
          .height(24)
          .fontColor([$r('app.color.mini_bar_primary')])
          .displayPriority(6)
          .onClick(() => {
            this.playerViewModel.togglePlayPause();
          })

        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(24)
          .fontWeight(FontWeight.Regular)
          .height(24)
          .fontColor([$r('app.color.mini_bar_primary')])
          .displayPriority(5)
          .onClick(() => this.playerViewModel.playNext())

        // 播放列表：空间不足时**在条内隐藏**（优先级低于播放/下一首），
        // 绝不允许被推出条的右边界之外 —— 异型屏/折叠屏/宽屏都靠这条兜底
        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize(24)
          .fontWeight(FontWeight.Regular)
          .height(24)
          .fontColor([$r('app.color.mini_bar_primary')])
          .displayPriority(4)
          .onClick(() => {
            this.playerViewModel.pushPlaylistDetail(this.pageIndexInfos);
          })
      }
    }
    .layoutWeight(1)
    // 量的是**整块 aside**（不是里面那一列元信息），克隆层按这个宽度还原排布
    .id(MINI_BAR_ASIDE_FLOATING_ID)
    .onClick(() => {
      this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
    })
  }
}
