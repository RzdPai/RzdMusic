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
  HeroCardApiDto,
  MusicAppState,
  MusicDbApi,
  StyleConstants,
  WatchNavRouteConstants
} from 'musicbasic';

/** Pinned-to-top header for WearableHome: page title row + now-playing capsule. */
@ComponentV2
struct WearableHomeHeader {
  @Consumer() pageStack: NavPathStack = new NavPathStack();
  @Local state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  private readonly contentWidth: string = '90%';

  /** Top row: Home 19vp / line-height 26; search 24x24, radius 12; distance to bottom player bar 33vp. */
  @Builder
  private headerRow() {
    Row({ space: 1 }) {
      Text($r('app.string.capsule_nav_home'))
        .fontSize(19)
        .lineHeight(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.font_color'))

      Row() {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(11)
          .fontWeight(FontWeight.Regular)
          .fontColor(['#FFFFFF'])
      }
      .width(24)
      .height(24)
      .justifyContent(FlexAlign.Center)
      .borderRadius(12)
      .backgroundColor($r('app.color.top_bar_search_background'))
    }
    .justifyContent(FlexAlign.Center)
    .width(this.contentWidth)
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 33, top: 18 })
  }

  /** Now-playing capsule: album cover, title marquee + shader like {@link SongPage}, singer color, white play_fill. */
  @Builder
  private nowPlayingRow() {
    Row() {
      Image(this.state.getCurrentSongItem()?.label ?? $r('app.string.page_show'))
        .width($r('app.float.home_icon_width'))
        .height($r('app.float.home_icon_width'))
        .borderRadius(StyleConstants.CIRCLE_BORDER_RADIUS)
        .objectFit(ImageFit.Cover)
        .clip(true)
        .margin({ right: 8 })

      Column({ space: 4 }) {
        Text(this.state.getCurrentSongItem()?.title ?? '')
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_color'))
          .maxLines(1)
          .width(StyleConstants.FULL_WIDTH)
          .textAlign(TextAlign.Start)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .shaderStyle({
            direction: GradientDirection.Right,
            colors: [
              ['#00FFFFFF', 0.0],
              ['#FFFFFFFF', 0.5],
              ['#00FFFFFF', 1.0]
            ]
          })
          .marqueeOptions({
            start: true,
            fromStart: true,
            step: 6,
            loop: -1,
            delay: 0,
            fadeout: false,
            marqueeStartPolicy: MarqueeStartPolicy.DEFAULT
          })
        Text(this.state.getCurrentSongItem()?.singer ?? '')
          .fontColor($r('app.color.play_singer_color'))
          .maxLines(1)
          .width(StyleConstants.FULL_WIDTH)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(24)
        .fontWeight(FontWeight.Regular)
        .height(24)
        .fontColor(['#FFFFFF'])
    }
    .width(this.contentWidth)
    .padding({
      left: $r('app.float.list_btn_padding'),
      right: $r('app.float.list_btn_padding'),
      top: 10,
      bottom: 10
    })
    .margin({
      left: 3,
      right: 3
    })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .borderRadius(StyleConstants.CIRCLE_BORDER_RADIUS)
    .backgroundColor($r('app.color.home_btn_background'))
    .onClick(() => {
      this.pageStack.replacePathByName(WatchNavRouteConstants.SONG_PAGE, null);
    })
  }

  build() {
    Column({ space: 0 }) {
      this.headerRow()
      this.nowPlayingRow()
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(HorizontalAlign.Center)
  }
}

@Builder
function buildWearableHomeHeader(): void {
  WearableHomeHeader();
}

/**
 * Smart wearable home: ArcList with pinned header (title + now-playing) and a stacked banner deck below.
 * Stack is display-only: front card at 100% / full opacity; adjacent cards 0.75 scale / 0.6 opacity; outer 0.6 / 0.4.
 */
@ComponentV2
export struct WearableHome {
  private static readonly bannerCenterWidth: string = '50%';
  /** Second layer (left/right of front): 75% of front size. */
  private static readonly bannerSideScale: number = 0.75;
  private static readonly bannerSideOpacity: number = 0.6;
  /** Back/outer layer: 60% of front size. */
  private static readonly bannerBackScale: number = 0.6;
  private static readonly bannerBackOpacity: number = 0.4;
  private static readonly bannerSideShiftVp: number = 30;
  private static readonly bannerBackShiftVp: number = 60;
  @Consumer() pageStack: NavPathStack = new NavPathStack();
  private heroCards: HeroCardApiDto[] = MusicDbApi.getInstance().getHeroCards();
  /** Center index for the stacked deck (display-only; no swipe). */
  private readonly bannerCenterIndex: number = 0;
  readonly homeContentWidth: string = '90%';

  private normalizeHeroIndex(idx: number): number {
    const n: number = this.heroCards.length;
    if (n <= 0) {
      return 0;
    }
    return ((idx % n) + n) % n;
  }

  @Builder
  private heroStackCover(cover: Resource, translateX: number, scale: number, zIdx: number, opacity: number,
    isFront: boolean) {
    Image(cover)
      .width(WearableHome.bannerCenterWidth)
      .aspectRatio(1)
      .borderRadius(4)
      .objectFit(ImageFit.Cover)
      .clip(true)
      .opacity(opacity)
      .scale({ x: scale, y: scale, centerX: '50%', centerY: '50%' })
      .translate({ x: translateX, y: 0 })
      .zIndex(zIdx)
      .onClick(() => {
        if (isFront) {
          this.pageStack.replacePathByName(WatchNavRouteConstants.PLAY_LIST, null);
        }
      })
  }

  build() {
    Scroll() {
      Column() {
        buildWearableHomeHeader()

        if (this.heroCards.length === 1) {
          Column() {
            Image(this.heroCards[0].coverImage)
              .width(WearableHome.bannerCenterWidth)
              .aspectRatio(1)
              .borderRadius(16)
              .objectFit(ImageFit.Cover)
              .clip(true)
              .onClick(() => {
                this.pageStack.replacePathByName(WatchNavRouteConstants.PLAY_LIST, null);
              })
          }
          .width(this.homeContentWidth)
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 8, bottom: 20 })
        } else if (this.heroCards.length > 1) {
          Stack({ alignContent: Alignment.Center }) {
            this.heroStackCover(
              this.heroCards[this.normalizeHeroIndex(this.bannerCenterIndex - 2)].coverImage,
              -WearableHome.bannerBackShiftVp,
              WearableHome.bannerBackScale,
              1,
              WearableHome.bannerBackOpacity,
              false
            )
            this.heroStackCover(
              this.heroCards[this.normalizeHeroIndex(this.bannerCenterIndex - 1)].coverImage,
              -WearableHome.bannerSideShiftVp,
              WearableHome.bannerSideScale,
              2,
              WearableHome.bannerSideOpacity,
              false
            )
            this.heroStackCover(
              this.heroCards[this.normalizeHeroIndex(this.bannerCenterIndex)].coverImage,
              0,
              1,
              4,
              1,
              true
            )
            this.heroStackCover(
              this.heroCards[this.normalizeHeroIndex(this.bannerCenterIndex + 1)].coverImage,
              WearableHome.bannerSideShiftVp,
              WearableHome.bannerSideScale,
              2,
              WearableHome.bannerSideOpacity,
              false
            )
            this.heroStackCover(
              this.heroCards[this.normalizeHeroIndex(this.bannerCenterIndex + 2)].coverImage,
              WearableHome.bannerBackShiftVp,
              WearableHome.bannerBackScale,
              1,
              WearableHome.bannerBackOpacity,
              false
            )
          }
          .width(this.homeContentWidth)
          .height(150)
          .clip(false)
          .margin({ top: 1, bottom: 20 })
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .alignItems(HorizontalAlign.Center)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .borderRadius(StyleConstants.CIRCLE_BORDER_RADIUS)
  }
}
