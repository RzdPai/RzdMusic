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


import { SongConstants } from 'musicbasic';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';
import { PanelHeroBannerSection } from './PanelHeroBannerSection';

/**
 * Embedded panel home: hero in a scroll with panel background.
 */
@ComponentV2
export struct PanelMusicHomePage {
  /** Own view model instance loaded on appear for panel child sections. */
  @Local recommendViewModel: RecommendViewModel = new RecommendViewModel();

  /**
   * Calls load on the local view model to populate hero data for the panel.
   */
  aboutToAppear() {
    this.recommendViewModel.load();
  }

  /**
   * Scroll column stacking panel hero with panel padding and color.
   */
  build() {
    Column() {
      Scroll() {
        Column() {
          PanelHeroBannerSection({ recommendViewModel: this.recommendViewModel })
        }
      }
      .padding({ bottom: 56 })
      .scrollBar(BarState.Off)
    }
  }

  /**
   * Page enter/exit transitions for this panel route.
   */
  pageTransition() {
    PageTransitionEnter({ duration: SongConstants.TRANSITION_DURATION, curve: Curve.Smooth, type: RouteType.Pop })
    PageTransitionExit({ duration: SongConstants.TRANSITION_DURATION, curve: Curve.Smooth, type: RouteType.Push })
  }
}
