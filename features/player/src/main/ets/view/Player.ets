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

import { uiObserver } from '@kit.ArkUI';
import { BreakpointType, StyleConstants } from 'musicbasic';
import { PlayerConstants } from '../constant/PlayerConstants';
import { PlayerViewModel } from '../viewmodel/PlayerViewModel';

/** Inline mini player row: cover, title, transport controls, and entry to full-screen playback. */
@ComponentV2
export struct Player {
  /** Window breakpoint for responsive typography and widths. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Navigation stack from parent shell for playlist navigation. */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** When true, row sits at bottom (y=0); otherwise offset above tab bar. */
  @Param dockAtBottom: boolean = false;
  /** View model bridging MusicAppState and MediaService. */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** Vertical pan recognizer to open full-screen on upward flick. */
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  /** Builds the horizontal mini player layout. */
  build() {
    Row() {
      Row() {
        Image(this.playerViewModel.songCover())
          .height($r('app.float.cover_height'))
          .width($r('app.float.cover_width'))
          .borderRadius($r('app.float.label_border_radius'))
          .margin({ right: $r('app.float.cover_margin') })
        Column() {
          Text(this.playerViewModel.songTitle())
            .fontColor($r('app.color.song_name'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .lineHeight(32)
          Row() {
            Text(this.playerViewModel.songSinger())
              .fontColor($r('app.color.singer'))
              .fontSize(new BreakpointType(14, 14, 18, 18).getValue(this.breakpointEnv.widthBreakpoint))
              .lineHeight(19)
              .fontWeight(FontWeight.Regular)
            Text('VIP')
              .fontColor($r('app.color.singer'))
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .lineHeight(13)
              .padding({
                left: 4,
                right: 4,
                top: 1,
                bottom: 1
              })
              .backgroundColor($r('app.color.play_text_color'))
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(PlayerConstants.LAYOUT_WEIGHT_PLAYER_CONTROL)
      .onClick(() => {
        this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
      })

      Blank()
        .onClick(() => {
          this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
        })

      Row() {
        Image($r('app.media.ic_previous'))
          .height($r('app.float.control_icon_height'))
          .width($r('app.float.control_icon_width'))
          .margin({ right: $r('app.float.control_icon_margin') })
          .displayPriority(PlayerConstants.DISPLAY_PRIORITY_TRACK_SKIP)
          .onClick(() => this.playerViewModel.playPrevious())
        Image(this.playerViewModel.appState.isPlay ? $r('app.media.ic_play') : $r('app.media.ic_pause'))
          .height($r('app.float.control_icon_height'))
          .width($r('app.float.control_icon_width'))
          .displayPriority(PlayerConstants.DISPLAY_PRIORITY_PLAY_PAUSE)
          .onClick(() => {
            this.playerViewModel.togglePlayPause();
          })
        Image($r('app.media.ic_next'))
          .height($r('app.float.control_icon_height'))
          .width($r('app.float.control_icon_width'))
          .margin({
            right: $r('app.float.control_icon_margin'),
            left: $r('app.float.control_icon_margin')
          })
          .displayPriority(PlayerConstants.DISPLAY_PRIORITY_TRACK_SKIP)
          .onClick(() => this.playerViewModel.playNext())
      }
      .width(new BreakpointType(
        $r('app.float.play_width_sm'),
        $r('app.float.play_width_sm'),
        $r('app.float.play_width_lg'),
        $r('app.float.play_width_lg')
      ).getValue(this.breakpointEnv.widthBreakpoint))
      .justifyContent(FlexAlign.End)

      
      Image($r('app.media.ic_sort_list'))
        .height($r('app.float.control_icon_height'))
        .width($r('app.float.control_icon_width'))
        .opacity(0.88)
        .margin({ left: 4 })
        .displayPriority(PlayerConstants.DISPLAY_PRIORITY_PLAYLIST_ENTRY)
        .onClick(() => {
          this.playerViewModel.pushPlaylistDetail(this.pageIndexInfos);
        })
    }
    .width(StyleConstants.FULL_WIDTH)
    .backgroundColor($r('app.color.player_background'))
    .padding({
      left: $r('app.float.player_padding'),
      right: $r('app.float.player_padding')
    })
    .translate(this.dockAtBottom ? { x: 0, y: 0 } : {
      x: 0,
      y: -(48 + 56)
    })
    .gesture(
      PanGesture(this.panOption)
        .onActionEnd((event?: GestureEvent) => {
          if (event && event.offsetY < -10) {
            this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
          }
        })
    )
    .height(48)
  }
}
