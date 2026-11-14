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
import { BreakpointType, getWindowInfoState, ImmersiveType, RouterUrlConstants, StyleConstants, WindowInfo } from 'musicbasic';

/**
 * Recommendation home top bar: title, identify-song and search entry points;
 * layout varies by breakpoint and immersive decor.
 */
@ComponentV2
export struct HomeTopBar {
  /** System breakpoint for typography and search width constraints. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Window metrics (immersive decor, title button width) for PC-style bar padding. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** Nav stack for routing to the online search page. */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();

  private homeScrollGutterH(): number {
    return new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint);
  }

  /** Routes to the online multi-source search page. */
  private openSearch(): void {
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.ONLINE_SEARCH, null);
  }

  /**
   * Simple circular image button shell (used for icon-only actions in some layouts).
   *
   * @param icon - Image resource to render at 40×40 vp.
   */
  @Builder
  private CircleIconButton(icon: Resource) {
    Image(icon)
      .width(40)
      .height(40)
  }

  /**
   * Picks among narrow two-row, narrow single-row+search, or wide title+search layouts.
   */
  build() {
    if (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD) {
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.home_page_title'))
            .fontSize(new BreakpointType(28, 30, 32, 32).getValue(this.breakpointEnv.widthBreakpoint))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.font_primary'))
          Blank()
          Row({ space: 12 }) {
            Row() {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(24)
                .fontWeight(FontWeight.Regular)
                .height(24)
                .fontColor([$r('app.color.font_primary')])
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor($r('app.color.home_icon_button_background'))
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .borderWidth(1)
            .borderColor($r('app.color.home_icon_button_border'))
            .onClick(() => {
              this.openSearch();
            })
            Row() {
              SymbolGlyph($r('sys.symbol.identify_song'))
                .fontSize(24)
                .fontWeight(FontWeight.Regular)
                .height(24)
                .fontColor([$r('app.color.font_primary')])
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor($r('app.color.home_icon_button_background'))
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .borderWidth(1)
            .borderColor($r('app.color.home_icon_button_border'))
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .padding({
          left: this.homeScrollGutterH(),
          right: this.homeScrollGutterH(),
          top: 8,
          bottom: 16
        })
      }
      .width(StyleConstants.FULL_WIDTH)
    } else if (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM) {
      Column() {
        Row() {
          Text($r('app.string.home_page_title'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .lineHeight(32)
            .fontColor($r('app.color.font_primary'))
          Blank()
          Row({ space: 12 }) {
            Row() {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(24)
                .fontWeight(FontWeight.Regular)
                .height(24)
                .fontColor([$r('app.color.font_primary')])
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor($r('app.color.home_icon_button_background'))
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .borderWidth(1)
            .borderColor($r('app.color.home_icon_button_border'))
            .onClick(() => {
              this.openSearch();
            })
            Row() {
              SymbolGlyph($r('sys.symbol.identify_song'))
                .fontSize(24)
                .fontWeight(FontWeight.Regular)
                .height(24)
                .fontColor([$r('app.color.font_primary')])
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor($r('app.color.home_icon_button_background'))
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .borderWidth(1)
            .borderColor($r('app.color.home_icon_button_border'))
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(56)
        .alignItems(VerticalAlign.Center)
      }
      .width(StyleConstants.FULL_WIDTH)
      .padding({
        left: this.homeScrollGutterH(),
        right: this.homeScrollGutterH(),
        bottom: 12
      })
    } else {
      Row() {
        Text(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
          $r('app.string.home_page_title_pc') :
          $r('app.string.home_page_title'))
          .fontSize(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 20 : 24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))

        Row({ space: 12 }) {
          Row() {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(24)
              .fontWeight(FontWeight.Regular)
              .height(24)
              .fontColor([$r('app.color.font_primary')])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.home_icon_button_background'))
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .borderWidth(1)
          .borderColor($r('app.color.home_icon_button_border'))
          .onClick(() => {
            this.openSearch();
          })

          if (this.windowInfo.immersiveDecor !== ImmersiveType.IMMERSIVE) {
            Row() {
              SymbolGlyph($r('sys.symbol.identify_song'))
                .fontSize(24)
                .fontWeight(FontWeight.Regular)
                .height(24)
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor($r('app.color.home_icon_button_background'))
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .borderWidth(1)
            .borderColor($r('app.color.home_icon_button_border'))
          }
        }
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width(StyleConstants.FULL_WIDTH)
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({
        left: this.homeScrollGutterH(),
        right: Math.max(
          this.homeScrollGutterH(),
          this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
            Math.max(0, this.windowInfo.titleButtonWidthVp) : 0
        ),
        bottom: 12,
        top: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 12 : 0
      })
    }
  }
}
