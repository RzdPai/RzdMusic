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

import { CapsuleSegmentedSelector } from './CapsuleSegmentedSelector';

/**
 * Bind-sheet option picker: a title plus the capsule segmented selector,
 * used by the settings page so every setting opens as a bottom sheet.
 */
@ComponentV2
export struct OptionChoiceSheet {
  @Param title: Resource | string = '';
  @Param labels: string[] = [];
  @Param selectedIndex: number = 0;
  @Param accentColor: ResourceColor = '#E60012';
  @Param onSelect: (index: number) => void = (_index: number) => {
  };

  build() {
    Column({ space: 18 }) {
      Text(this.title)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      CapsuleSegmentedSelector({
        labels: this.labels,
        selectedIndex: this.selectedIndex,
        accentColor: this.accentColor,
        onSelect: (index: number): void => {
          this.onSelect(index);
        }
      })
      .width('100%')
    }
    .padding({ left: 20, right: 20, top: 24, bottom: 32 })
  }
}