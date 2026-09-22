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

import { getWindowInfoState, ImmersiveType, StyleConstants, WindowInfo } from 'musicbasic';
import { HomeMiniBarPlayer } from 'playlist';

/**
 * Bottom floating mini player container; styles differ for immersive vs normal window decor.
 */
@ComponentV2
export struct HomeFloatingMiniBar {
  /** Window metrics used to pick background, radius, blur, and border. */
  @Local windowInfo: WindowInfo = getWindowInfoState();

  /**
   * Wraps {@link HomeMiniBarPlayer} with full width and immersive-aware chrome.
   */
  build() {
    Column() {
      HomeMiniBarPlayer({ showPreviousTrack: true, followAppMiniBarExpanded: false })
    }
    .width(StyleConstants.FULL_WIDTH)
    .backgroundColor(
      this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
        $r('app.color.pc_floating_mini_bar_immersive_surface') :
        $r('app.color.floating_mini_bar_sheet_background'))
    .borderRadius(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 28)
    .borderWidth(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 1)
    .borderColor(
      this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
        Color.Transparent : $r('app.color.comp_divider'))
  }
}
