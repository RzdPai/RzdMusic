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

@ComponentV2
export struct MusicTextIcon {
  @Require @Param src: PixelMap | ResourceStr | DrawableDescriptor;
  @Param iconSize: Length = 32;
  @Param iconOnly: boolean = true;
  @Param content: string | Resource = '';
  @Param fontSize: string | number | Resource = $r('sys.float.Body_M');
  @Param fontColor: ResourceColor = $r('sys.color.font_on_primary');
  @Param fontWeight: number | FontWeight | ResourceStr = $r('sys.float.font_weight_regular');
  @Param gap: Length = 2;

  build() {
    Column({ space: this.gap }) {
      Image(this.src)
        .width(this.iconSize)
        .aspectRatio(1)
        .objectFit(ImageFit.Contain)
      if (!this.iconOnly) {
        Text(this.content)
          .fontSize(this.fontSize)
          .fontColor(this.fontColor)
          .fontWeight(this.fontWeight)
      }
    }
  }
}
