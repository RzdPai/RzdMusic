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

import { ComponentContent, LengthMetrics } from '@kit.ArkUI';
import { ArcList, ArcListItem } from '@kit.ArkUI';
import { StyleConstants, WatchNavRouteConstants } from 'musicbasic';
import { getWatchNavContext, WatchNavContext } from '../model/WatchNavContext';

@Builder
export function PlayListBuilder() {
  PlaylistHub();
}

class PlaylistCard {
  public title: Resource;
  public playCount: Resource;
  public cover: Resource;
  public cardColor: Resource;

  public constructor(title: Resource, playCount: Resource, cover: Resource, cardColor: Resource) {
    this.title = title;
    this.playCount = playCount;
    this.cover = cover;
    this.cardColor = cardColor;
  }
}

@ComponentV2
struct PlaylistHubArcHeader {
  build() {
    Text($r('app.string.watch_playlist_section_title'))
      .fontSize($r('app.float.watch_playlist_section_title'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.watch_text_on_dark_primary'))
      .textAlign(TextAlign.Center)
      .width(StyleConstants.FULL_WIDTH)
      .padding({ top: 8, bottom: 12 })
  }
}

@Builder
function buildPlaylistHubArcHeader(): void {
  PlaylistHubArcHeader();
}

/** One playlist card row: use borderRadius only for side shape. */
@ComponentV2
struct PlaylistHubArcCardRow {
  @Param item: PlaylistCard = new PlaylistCard(
    $r('app.string.page_show'),
    $r('app.string.page_show'),
    $r('app.string.page_show'),
    $r('app.color.watch_text_on_dark_primary')
  );
  @Consumer() pageStack: NavPathStack = new NavPathStack();
  @Local private navContext: WatchNavContext = getWatchNavContext();

  private openSongListFromCard(): void {
    this.navContext.selectedPlaylistTitle = this.item.title;
    this.pageStack.replacePathByName(WatchNavRouteConstants.SONG_LIST, null);
  }

  build() {
    ArcListItem() {
      Row({ space: 10 }) {
        Image(this.item.cover)
          .height(64)
          .width(64)
          .objectFit(ImageFit.Cover)
          .borderRadius($r('sys.float.corner_radius_level4'))
        Column({ space: 4 }) {
          Text(this.item.title)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Regular)
            .fontColor($r('app.color.watch_text_on_dark_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.item.playCount)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.watch_text_secondary'))
          SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
            .fontSize(18)
            .fontWeight(FontWeight.Regular)
            .fontColor([$r('app.color.watch_text_on_dark_primary')])
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      }
      .borderRadius($r('app.float.watch_playlist_card_radius'))
      .onClick(() => {
        this.openSongListFromCard();
      })
    }
    .backgroundColor('#332028')
    .width('90%')
    .borderRadius(25)
    .padding({
      left: 25,
      right: 25,
      top: 10,
      bottom: 10
    })
  }
}

/** Playlist hub (swiper page + routed destination): demo cards opening the song list. */
@ComponentV2
export struct PlaylistHub {
  @Consumer() pageStack: NavPathStack = new NavPathStack();
  @Local private navContext: WatchNavContext = getWatchNavContext();
  private headerContent: ComponentContent<Object> =
    new ComponentContent(this.getUIContext(), wrapBuilder(buildPlaylistHubArcHeader));
  private cards: PlaylistCard[] = [
    new PlaylistCard(
      $r('app.string.watch_playlist_card_title_party'),
      $r('app.string.watch_playlist_play_count_one'),
      $r('app.media.playlist_bg1'),
      $r('app.color.watch_playlist_card_maroon')
    ),
    new PlaylistCard(
      $r('app.string.watch_playlist_card_title_xmas'),
      $r('app.string.watch_playlist_play_count_two'),
      $r('app.media.playlist_bg2'),
      $r('app.color.watch_playlist_card_blue')
    )
  ];

  build() {
    NavDestination() {
      Column() {
        ArcList({ initialIndex: 0, header: this.headerContent }) {
          ForEach(this.cards, (item: PlaylistCard, index: number) => {
            PlaylistHubArcCardRow({ item: item })
          }, (item: PlaylistCard, index: number) => `playlist-card-${index}`)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .space(LengthMetrics.vp(8))
        .focusable(true)
        .focusOnTouch(true)
        .defaultFocus(true)
        .padding({
          left: 4,
          right: 4
        })
      }
      .align(Alignment.Center)
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .backgroundColor($r('app.color.watch_page_background'))
      .padding({
        bottom: 8
      })
    }
    .hideTitleBar(true)
  }
}
