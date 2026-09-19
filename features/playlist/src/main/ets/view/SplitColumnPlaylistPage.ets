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


import { HdsNavDestination } from '@kit.UIDesignKit';
import { StyleConstants, WindowUtil } from 'musicbasic';
import { MusicListPlaybackViewModel } from '../viewmodel/MusicListPlaybackViewModel';
import { PlaylistLaneListSection } from './PlaylistLaneListSection';
import { PlaylistSplitHero } from './PlaylistSplitHero';

/**
 * Split-column playlist experience with hero row and lane-based song list on a dark gradient shell.
 */
@ComponentV2
export struct SplitColumnPlaylistPage {
  /** Shared list and playback view model for hero and list sections. */
  @Local listVm: MusicListPlaybackViewModel = new MusicListPlaybackViewModel();

  /**
   * Builds the nav destination, hero, list, and window bar styling for split layout.
   */
  build() {
    if (canIUse('SystemCapability.UIDesign.HDSComponent.Core')) {
      HdsNavDestination() {
        Column({ space: 32 }) {
          PlaylistSplitHero({ listVm: this.listVm })
          PlaylistLaneListSection({ listVm: this.listVm })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .padding({
          left: 56,
          right: 56,
          top: 56
        })
        .layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .linearGradient({
          angle: 180,
          colors: [
            ['#243850', 0.0],
            ['#18191D', 1.0]
          ]
        })
      }
      .hideTitleBar(true)
      .backgroundColor('#18181a')
      .onAppear(() => {
        this.listVm.syncPlaylistFromApi();
        WindowUtil.getInstance().setWindowSystemBarProperties({
          statusBarContentColor: '#FFFFFF'
        });
      })
      .onDisAppear(() => {
        WindowUtil.getInstance().setWindowSystemBarProperties({
          statusBarContentColor: '#000000'
        });
      })
    } else {
      NavDestination() {
        Column({ space: 32 }) {
          PlaylistSplitHero({ listVm: this.listVm })
          PlaylistLaneListSection({ listVm: this.listVm })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .padding({
          left: 56,
          right: 56,
          top: 56
        })
        .layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .linearGradient({
          angle: 180,
          colors: [
            ['#243850', 0.0],
            ['#18191D', 1.0]
          ]
        })
      }
      .hideTitleBar(true)
      .backgroundColor('#18181a')
      .onAppear(() => {
        this.listVm.syncPlaylistFromApi();
        WindowUtil.getInstance().setWindowSystemBarProperties({
          statusBarContentColor: '#FFFFFF'
        });
      })
      .onDisAppear(() => {
        WindowUtil.getInstance().setWindowSystemBarProperties({
          statusBarContentColor: '#000000'
        });
      })
    }
  }
}


/**
 * Global builder entry for routing to {@link SplitColumnPlaylistPage}.
 * @param name Route or page name (unused placeholder for navigation integration).
 * @param param Optional route parameters object.
 */
@Builder
export function SplitColumnPlaylistPageBuilder(name: string, param: Object) {
  SplitColumnPlaylistPage()
}
