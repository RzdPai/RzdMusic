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

import { AppStorageV2, ComponentContent, LengthMetrics } from '@kit.ArkUI';
import { ArcList, ArcListItem } from '@kit.ArkUI';
import { AppStorageKeys, StyleConstants, WatchNavRouteConstants } from 'musicbasic';
import { MediaService, MusicAppState } from 'player';
import { getWatchNavContext, WatchNavContext } from '../model/WatchNavContext';

@ComponentV2
struct SongQueueArcHeader {
  @Local private nav: WatchNavContext = getWatchNavContext();
  @Local private st: MusicAppState =
      AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;

  build() {
    Column({ space: 6 }) {
      Text(this.nav.selectedPlaylistTitle)
        .fontSize($r('app.float.watch_song_header_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.watch_text_on_dark_primary'))
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(StyleConstants.FULL_WIDTH)
      Row({ space: 0 }) {
        Text('' + this.st.playQueueIds.length)
          .fontSize($r('app.float.watch_song_header_sub'))
          .fontColor($r('app.color.watch_text_secondary'))
        Text($r('app.string.watch_song_count_suffix'))
          .fontSize($r('app.float.watch_song_header_sub'))
          .fontColor($r('app.color.watch_text_secondary'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      top: 8,
      bottom: 10,
      left: 12,
      right: 12
    })
    .alignItems(HorizontalAlign.Center)
  }
}

@Builder
function buildSongQueueArcHeader(): void {
  SongQueueArcHeader();
}

@Builder
export function SongListBuilder() {
  SongQueueList();
}

@ComponentV2
struct SongQueueList {
  @Consumer() pageStack: NavPathStack = new NavPathStack();
  @Local private state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  private headerContent: ComponentContent<Object> =
    new ComponentContent(this.getUIContext(), wrapBuilder(buildSongQueueArcHeader));

  aboutToAppear(): void {
    MediaService.getInstance();
  }

  build() {
    NavDestination() {
      Column() {
        ArcList({ initialIndex: 0, header: this.headerContent }) {
          ForEach(this.state.playQueueIds, (id: number, index: number) => {
            ArcListItem() {
              Row({ space: 0 }) {
                Image(this.state.resolveSongAtQueueIndex(index)?.label ?? $r('app.string.page_show'))
                  .width($r('app.float.watch_song_row_cover'))
                  .height($r('app.float.watch_song_row_cover'))
                  .borderRadius(StyleConstants.CIRCLE_BORDER_RADIUS)
                  .objectFit(ImageFit.Cover)
                Column({ space: 2 }) {
                  Text(this.state.resolveSongAtQueueIndex(index)?.title ?? '')
                    .fontSize($r('app.float.watch_song_title_size'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.watch_text_on_dark_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.state.resolveSongAtQueueIndex(index)?.singer ?? '')
                    .fontSize($r('app.float.watch_song_singer_size'))
                    .fontColor($r('app.color.watch_text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Center)
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
              }
              .padding({
                top: $r('app.float.watch_song_row_padding_v'),
                bottom: $r('app.float.watch_song_row_padding_v'),
                left: 12,
                right: 12
              })
              .backgroundColor($r('app.color.watch_song_row_capsule'))
              .borderRadius('100%')
              .onClick(async () => {
                await MediaService.getInstance().loadAsset(index);
                this.pageStack.replacePathByName(WatchNavRouteConstants.SONG_PAGE, null);
              })
            }
            .width('90%')
          }, (id: number) => id.toString())
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .space(LengthMetrics.vp(8))
        .focusable(true)
        .focusOnTouch(true)
        .defaultFocus(true)
      }
      .align(Alignment.Center)
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .backgroundColor($r('app.color.watch_page_background'))
      .padding({
        left: $r('app.float.watch_arc_list_padding_h'),
        right: $r('app.float.watch_arc_list_padding_h'),
        bottom: 8
      })
    }
    .hideTitleBar(true)
  }
}
