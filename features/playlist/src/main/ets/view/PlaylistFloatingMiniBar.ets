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
import { AmbientState, AppStorageKeys, getWindowInfoState, ImmersiveType, StyleConstants, WindowInfo } from 'musicbasic';
import { HomeMiniBarPlayer } from './HomeMiniBarPlayer';

/**
 * Bottom sheet-style container for {@link MiniBarPlayer} with immersive-aware background and radius.
 */
@ComponentV2
export struct PlaylistFloatingMiniBar {
  /** Window decoration state controlling bar colors and border treatment. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** Ambient material level (0 = follow system) for the frosted glass background. */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;

  /** Sheet background: light frosted white (19%) and dark translucent sheet color, matching the home tab bar. */
  private miniBarBackground(): ResourceColor {
    if (this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE) {
      return $r('app.color.floating_mini_bar_immersive_background');
    }
    return $r('app.color.floating_mini_bar_background');
  }

  /** Frosted glass strength by ambient level, matching the home tab bar material (0 = adaptive). */
  private miniBarBlur(): BlurStyle {
    switch (this.ambientState.level) {
      case 1:
        return BlurStyle.Thin;
      case 2:
        return BlurStyle.Regular;
      case 3:
        return BlurStyle.Thick;
      default:
        return BlurStyle.Thin;
    }
  }

  /**
   * Builds the full-width mini player: non-immersive uses sheet background;
   * immersive uses `floating_mini_bar_immersive_background`.
   */
  build() {
    Column() {
      HomeMiniBarPlayer({ showPreviousTrack: true, followAppMiniBarExpanded: false })
    }
    .width(StyleConstants.FULL_WIDTH)
    .backgroundColor(this.miniBarBackground())
    .backgroundBlurStyle(this.miniBarBlur())
    .borderRadius(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 28)
    .borderWidth(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 1)
    .borderColor($r('app.color.comp_divider'))
  }
}
