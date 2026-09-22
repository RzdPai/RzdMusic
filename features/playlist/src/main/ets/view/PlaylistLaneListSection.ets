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


import { StyleConstants } from 'musicbasic';
import { PlayerViewModel } from 'player';
import { PlaylistSongUi } from '../model/PlaylistUiModels';
import { MusicListPlaybackViewModel } from '../viewmodel/MusicListPlaybackViewModel';

/**
 * Two-lane glass-style playlist list for split-column layout with inline play for the current row.
 */
@ComponentV2
export struct PlaylistLaneListSection {
  /** Playlist and playback coordination view model. */
  @Param listVm: MusicListPlaybackViewModel = new MusicListPlaybackViewModel();
  /** Local player VM for toggling play state on the active row control. */
  @Local private playerVm: PlayerViewModel = new PlayerViewModel();

  /**
   * Builds a wide playlist card row with cover, tags, optional inline play/pause, and tap-to-play.
   * @param item Song UI model for the row.
   * @param index Zero-based playlist index passed to play requests.
   */
  @Builder
  private PlaylistSongRow(item: PlaylistSongUi, index: number) {
    Row() {
      Image(item.label)
        .width(64)
        .height(64)
        .borderRadius($r('sys.float.corner_radius_level4'))
        .objectFit(ImageFit.Cover)
        .margin({
          right: 22
        })

      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text(item.title)
            .fontSize(24)
            .lineHeight(32)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.listVm.isCurrentSong(item) ? $r('sys.color.brand') : $r('sys.color.font_on_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.listVm.isCurrentSong(item) && this.listVm.appState.isPlay) {
            SymbolGlyph($r('sys.symbol.rhythm'))
              .fontSize(32)
              .fontWeight(FontWeight.Regular)
              .height(32)
              .fontColor([$r('sys.color.brand')])
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .justifyContent(FlexAlign.Start)

        Row({ space: 6 }) {
          Text('VIP')
            .fontSize(16)
            .lineHeight(21)
            .fontWeight(FontWeight.Medium)
            .fontColor('#e6b673')
            .padding({
              left: 6,
              right: 6,
              top: 1.5,
              bottom: 1.5
            })
            .backgroundColor('#33c79e63')
            .borderRadius($r('sys.float.corner_radius_level3'))
          Text($r('app.string.playlist_tag_spatial'))
            .fontSize(16)
            .lineHeight(21)
            .fontColor('#e6b673')
            .padding({
              left: 6,
              right: 6,
              top: 1.5,
              bottom: 1.5
            })
            .backgroundColor('#33c79e63')
            .borderRadius($r('sys.float.corner_radius_level3'))
          Text(item.singer)
            .fontSize(22)
            .lineHeight(29)
            .fontWeight(FontWeight.Regular)
            .fontColor(this.listVm.isCurrentSong(item) ? $r('sys.color.brand') : $r('app.color.hero_overlay_text_secondary'))
            .maxLines(1)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.listVm.isCurrentSong(item)) {
        SymbolGlyph(this.listVm.appState.isPlay ? $r('sys.symbol.pause_round_triangle_fill') :
          $r('sys.symbol.play_round_triangle_fill'))
          .fontSize(44)
          .fontWeight(FontWeight.Regular)
          .height(44)
          .fontColor([$r('sys.color.font_on_secondary')])
          .onClick(() => {
            this.playerVm.togglePlayPause();
          })
      }
    }
    .height(96)
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(VerticalAlign.Center)
    .padding(16)
    .backgroundColor($r('app.color.floating_mini_bar_background'))
    .borderRadius($r('sys.float.corner_radius_level12'))
    .borderWidth(1)
    .borderColor('#26ffffff')
    .onClick(() => {
      this.listVm.requestPlayByListIndex(index, this.getUIContext());
    })
  }

  /**
   * Builds the scrollable two-lane list of playlist cards.
   */
  build() {
    Column() {
      List({ space: 16 }) {
        LazyForEach(this.listVm.songListDataSource, (item: PlaylistSongUi, index: number) => {
          ListItem() {
            this.PlaylistSongRow(item, index);
          }
        }, (item: PlaylistSongUi, index?: number) => `pl-${index}-${item.id}`)
      }
      .lanes(2, 32)
      .width(StyleConstants.FULL_WIDTH)
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width(StyleConstants.FULL_WIDTH)
    .layoutWeight(1)
  }
}
