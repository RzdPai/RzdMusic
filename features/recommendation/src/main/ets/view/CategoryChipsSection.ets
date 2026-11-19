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


import { LengthMetrics, uiObserver } from '@kit.ArkUI';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { buildImmersiveMaterial, immersiveMaterialSupported } from 'musicbasic';
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
  /** 仅吸顶副本开启：用官方边缘渐隐代替黑色覆盖层（流内那一行保持原样）。 */
  @Param enableFadingEdge: boolean = false;
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
  /** 当前是否浅色（日间）模式。日间胶囊保持实心浅色，不叠材质（避免色差）。 */
  private colorModeIsLight(): boolean {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (ctx === undefined || ctx.config === undefined) {
        return false;
      }
      return ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } catch (_e) {
      return false;
    }
  }

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
              // 未选中：有材质就让材质决定底色（否则日间会浮出一层灰 = 用户说的"色差"）
              (immersiveMaterialSupported() ? Color.Transparent :
                $r('app.color.chip_unselected_background')))
          .borderRadius(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 8 : 21)
          // ★★★ 2026-11-19（用户给了官方华为音乐截图：「Tab 栏**胶囊**改光感，不是加个背板」）：
          //   材质挂在**每个胶囊**上 —— 吸顶那一份画在 `Navigation` 标题栏槽位里（B 档白名单）⇒ 生效；
          //   流内那一份在 body 里 ⇒ 不生效（无所谓，观感一致）。
          //   不支持该能力的设备返回 undefined ⇒ 无材质，胶囊原底色照旧。
          // 官方截图里**选中那枚是实心浅色胶囊**（不是玻璃）⇒ 材质只挂**未选中**的。
          // ★ 2026-11-19 订正（用户："官方日间模式也有材质"）：**日夜都挂材质**。
          //   日间那点色差的原因是**底色冲突**：材质生效时系统会把 backgroundColor 改成透明，
          //   我们原来给未选中胶囊写死了 `chip_unselected_background` ⇒ 日间在材质上浮出一层灰。
          //   ⇒ 见下面 `backgroundColor`：有材质时给 `Color.Transparent`，让材质自己决定底色。
          .systemMaterial(this.recommendViewModel.selectedCategoryIndex === index ?
            undefined : buildImmersiveMaterial())
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
    // 官方边缘渐隐：作用于内容自身 alpha，露出下方背景，不会像黑色覆盖层那样遮挡内容。
    // 仅吸顶副本（`stackBuilder`）开启；流内那一行默认 false。
    .fadingEdge(this.enableFadingEdge, {
      fadingEdgeLength: LengthMetrics.vp(40)
    })
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
