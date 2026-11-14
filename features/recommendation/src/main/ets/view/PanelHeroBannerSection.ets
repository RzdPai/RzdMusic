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


import { MusicDbApi, RouterUrlConstants, StyleConstants } from 'musicbasic';
import { RecommendHeroCardUi } from '../model/RecommendUiModels';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';

/**
 * Wide-panel horizontal hero banner strip with playlist navigation and play-first-song action.
 */
@ComponentV2
export struct PanelHeroBannerSection {
  /** Hero data and play intent from the recommendation view model. */
  @Param recommendViewModel: RecommendViewModel = new RecommendViewModel();
  /** Nav stack for split-column playlist route. */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  private bannerScroller: Scroller = new Scroller();

  /**
   * Navigates to the split-column playlist placeholder route.
   */
  private goPlaylistDetail(): void {
    this.pageIndexInfos.replacePathByName(RouterUrlConstants.SPLIT_COLUMN_PLAYLIST, null);
  }

  /**
   * Starts playback of the first song in the music DB global song list if non-empty.
   */
  private playBannerHero(): void {
    const list = MusicDbApi.getInstance().getSongList();
    if (list.length > 0) {
      this.recommendViewModel.requestPlayBySongId(list[0].id);
    }
  }

  /**
   * Single wide or narrow hero card for the panel layout.
   *
   * @param item - Hero card UI model.
   * @param index - Card index; first card uses a fixed hero asset width.
   */
  @Builder
  private PanelHeroBannerCard(item: RecommendHeroCardUi, index: number) {
    Stack() {
      Image(index === 0 ?
        (item.coverUrl.length > 0 ? item.coverUrl : $r('app.media.ic_banner_hero_first')) :
        (item.coverUrl.length > 0 ? item.coverUrl : item.coverImage))
        .constraintSize({ maxWidth: index === 0 ? 568 : 268, maxHeight: 345 })
        .width(index === 0 ? '66%' : '34%')
        .aspectRatio(index === 0 ? 568 / 345 : 268 / 345)
        .objectFit(ImageFit.Cover)
        .onClick(() => {
          this.goPlaylistDetail();
        })

      Column() {
        Row({ space: 4 }) {
          Image($r('app.media.ic_music_symbol'))
            .width(14)
            .height(14)
            .fillColor($r('app.color.banner_text_primary'))
          Text(item.badge)
            .fontSize(12)
            .lineHeight(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.banner_text_primary'))
        }
        .padding(12)
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .onClick(() => {
          this.goPlaylistDetail();
        })

        Row() {
          Column({ space: 4 }) {
            Text(item.title)
              .fontSize(20)
              .fontColor($r('app.color.banner_text_tertiary'))
              .fontWeight(FontWeight.Bold)
              .lineHeight(27)
            Text(item.subLine)
              .fontSize(12)
              .fontColor($r('app.color.banner_text_secondary'))
              .maxLines(1)
              .lineHeight(16)
              .fontWeight(FontWeight.Regular)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
            .fontSize(36)
            .fontWeight(FontWeight.Regular)
            .height(36)
            .fontColor([$r('app.color.banner_text_tertiary')])
            .onClick(() => {
              this.playBannerHero();
            })
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .backgroundColor($r('app.color.banner_overlay_background'))
        .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK)
        .padding(12)
      }
      .height('100%')
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width(index === 0 ? 568 : 268)
    .height(345)
    .clip(true)
    .borderRadius(20)
  }

  /**
   * Horizontal scroll of panel hero cards built from the view model hero list.
   */
  build() {
    Scroll(this.bannerScroller) {
      Row({ space: 32 }) {
        ForEach(this.recommendViewModel.heroCards, (item: RecommendHeroCardUi, index?: number) => {
          Column() {
            this.PanelHeroBannerCard(item, index ?? 0);
          }
        }, (_item: RecommendHeroCardUi, index?: number) => `panel-hero-${index}`)
      }
      .padding({ left: 56, right: 56 })
    }
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .width(StyleConstants.FULL_WIDTH)
  }
}

