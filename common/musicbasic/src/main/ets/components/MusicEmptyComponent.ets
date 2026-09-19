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

import { StyleConstants } from '../constants/Constants';
import { MusicTextIcon } from './MusicTextIcon';

/** Centered empty-state illustration and hint text for placeholder tabs or lists. */
@Builder
export function MusicEmptyComponent() {
  Column() {
    MusicTextIcon({ src: $r('app.media.ic_empty'), iconSize: 120 })
    Text($r('app.string.empty_text'))
      .fontSize($r('sys.float.Body_M'))
      .fontColor($r('sys.color.font_secondary'))
      .fontWeight($r('sys.float.font_weight_regular'))
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
  .alignItems(HorizontalAlign.Center)
  .justifyContent(FlexAlign.Center)
}
