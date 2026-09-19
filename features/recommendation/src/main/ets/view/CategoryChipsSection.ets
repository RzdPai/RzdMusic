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


import { uiObserver } from '@kit.ArkUI';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { BreakpointType, getWindowInfoState, ImmersiveType, StyleConstants, WindowInfo } from 'musicbasic';
import { RecommendCategoryTabUi } from '../model/RecommendUiModels';
import { RecommendViewModel } from '../viewmodel/RecommendViewModel';

/**
 * Horizontally scrollable category chips bound to the view model tab list and selection index.
 */
@ComponentV2
export struct CategoryChipsSection {
  /** Breakpoint env for chip width, spacing, and vertical margins. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** VM supplying tabs and handling category selection changes. */
  @Param recommendViewModel: RecommendViewModel = new RecommendViewModel();
  /** Title bar insets, immersive decor, and related window metrics. */
  @Local windowInfo: WindowInfo = getWindowInfoState();

  private homeScrollGutterH(): number {
    return new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /** True when host is in dark color mode (chip icon assets swap vs light mode). */
  private isDarkTheme(): boolean {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined || ctx.config === undefined) {
      return false;
    }
    return ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  /**
   * Chip icon: light mode uses selected/unselected assets by selection;
   * dark mode inverts — unselected rows use {@link RecommendCategoryTabUi.iconSelected},
   * selected row uses {@link RecommendCategoryTabUi.iconUnselected} (light pill + line icon).
   */
  private chipTabIcon(item: RecommendCategoryTabUi, index: number): Resource {
    const selected = this.recommendViewModel.selectedCategoryIndex === index;
    if (this.isDarkTheme()) {
      return selected ? item.iconUnselected : item.iconSelected;
    }
    return selected ? item.iconSelected : item.iconUnselected;
  }

  /**
   * Renders a row of selectable category pills with icon+title and selected styling.
   */
  build() {
    Scroll() {
      Row({ space: new BreakpointType(8, 12, 16, 16).getValue(this.breakpointEnv.widthBreakpoint) }) {
        ForEach(this.recommendViewModel.categoryTabItems, (item: RecommendCategoryTabUi, index?: number) => {
          Row({ space: 6 }) {
            Image(this.chipTabIcon(item, index ?? 0))
              .width(16)
              .height(16)
            Text(item.title)
              .fontSize(12)
              .fontWeight(this.recommendViewModel.selectedCategoryIndex === index ? 500 : 400)
              .lineHeight(16)
              .fontColor(this.recommendViewModel.selectedCategoryIndex === index ? $r('app.color.chip_selected_text') :
                $r('app.color.chip_unselected_text'))
          }
          .width(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 102 :
            new BreakpointType(78, 114, 134, 134).getValue(this.breakpointEnv.widthBreakpoint))
          .height(36)
          .backgroundColor(
            this.recommendViewModel.selectedCategoryIndex === index ?
              $r('app.color.chip_selected_background') :
              $r('app.color.chip_unselected_background'))
          .borderRadius(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 8 : 21)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.recommendViewModel.selectCategory(index ?? 0);
          })
        }, (_item: RecommendCategoryTabUi, index?: number) => `cat-${index}`)
      }
      .padding({ left: this.homeScrollGutterH(), right: this.homeScrollGutterH() })
    }
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .width(StyleConstants.FULL_WIDTH)
    .align(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? Alignment.Start : Alignment.Center)
    .padding({
      top: new BreakpointType(8, 10, 10, 10).getValue(this.breakpointEnv.widthBreakpoint),
      bottom: new BreakpointType(8, 10, 10, 10).getValue(this.breakpointEnv.widthBreakpoint)
    })
    .margin({
      top: new BreakpointType(8, 16, 16, 16).getValue(this.breakpointEnv.widthBreakpoint),
      bottom: new BreakpointType(8, 16, 16, 16).getValue(this.breakpointEnv.widthBreakpoint)
    })
  }
}
