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
import { MusicListPlaybackViewModel } from '../viewmodel/MusicListPlaybackViewModel';

/**
 * Split-layout hero: large cover, title block, play-all, collect affordances, and overflow menu row.
 */
@ComponentV2
export struct PlaylistSplitHero {
  private static readonly likesIconW: number = 32 * 44 / 24;
  private static readonly likesIconH: number = 32;
  private static readonly likesIconBaseW: number = 44;
  private static readonly likesIconBaseH: number = 24;
  /** Match text anchor with the SVG internal scale+translate transform. */
  private static readonly likesIconPathTx: number = -0.7632;
  private static readonly likesIconPathTy: number = -2.4061;
  /** View model used for play-all from index 0 and shared playlist state. */
  @Param listVm: MusicListPlaybackViewModel = new MusicListPlaybackViewModel();

  /**
   * Builds the horizontal hero row with primary actions aligned to the bottom of the cover stack.
   */
  build() {
    Row({ space: 32 }) {
      Image($r('app.media.ic_list_cover'))
        .width(268)
        .height(268)
        .borderRadius($r('sys.float.corner_radius_level8'))
        .objectFit(ImageFit.Fill)

      Column() {
        Column({ space: 8 }) {
          Text($r('app.string.playlist_detail_title'))
            .fontSize(48)
            .lineHeight(64)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_on_primary'))
          Text($r('app.string.playlist_detail_desc'))
            .fontSize($r('sys.float.Subtitle_L'))
            .lineHeight(24)
            .fontWeight(FontWeight.Regular)
            .fontColor($r('app.color.hero_overlay_text_secondary'))
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)

        Row({ space: 32 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
              .fontSize(32)
              .fontWeight(FontWeight.Regular)
              .height(32)
              .fontColor([$r('sys.color.font_on_secondary')])
            Text($r('app.string.playlist_play_all'))
              .fontSize(24)
              .lineHeight(32)
              .fontWeight(FontWeight.Regular)
              .fontColor($r('sys.color.font_on_secondary'))
          }
          .width(268)
          .height(54)
          .justifyContent(FlexAlign.Center)
          .borderRadius(27)
          .backgroundColor($r('sys.color.brand'))
          .onClick(() => {
            this.listVm.requestPlayFromPlaylistIndex(0);
          })

          Row({ space: 12 }) {
            Stack() {
              Image($r('app.media.ic_public_likes_tv'))
                .width(PlaylistSplitHero.likesIconW)
                .height(PlaylistSplitHero.likesIconH)
                .objectFit(ImageFit.Contain)
                .align(Alignment.TopStart)

              Text('22W+')
                .fontSize(10)
                .lineHeight(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_on_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Clip })
                .constraintSize({ minWidth: 40 })
                .position({
                  x: (14.704 + PlaylistSplitHero.likesIconPathTx) *
                    (PlaylistSplitHero.likesIconW / PlaylistSplitHero.likesIconBaseW) + 6,
                  y: ((0.408 + 6.6) + PlaylistSplitHero.likesIconPathTy) *
                    (PlaylistSplitHero.likesIconH / PlaylistSplitHero.likesIconBaseH) - 2.5 - 2
                })
            }
            .width(PlaylistSplitHero.likesIconW)
            .height(PlaylistSplitHero.likesIconH)
            .margin({ right: -8 })
            .clip(false)
            Text($r('app.string.playlist_collect'))
              .fontSize(24)
              .lineHeight(32)
              .fontWeight(FontWeight.Regular)
              .fontColor($r('sys.color.font_on_secondary'))
          }
          .width(268)
          .height(54)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('sys.color.font_on_tertiary'))
          .borderRadius(27)
          .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK)
          .borderWidth(1)
          .borderColor('#26ffffff')

          Row() {
            SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
              .fontSize(32)
              .fontWeight(FontWeight.Regular)
              .height(32)
              .fontColor([$r('sys.color.font_on_secondary')])
          }
          .width(54)
          .height(54)
          .backgroundColor($r('sys.color.font_on_tertiary'))
          .borderRadius(30)
          .borderWidth(1)
          .borderColor('#26ffffff')
          .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK)
          .justifyContent(FlexAlign.Center)
        }
        .margin({ top: 65 })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Start)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(268)
    .justifyContent(FlexAlign.Start)
  }
}
