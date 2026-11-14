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


import { PathShape, uiObserver } from '@kit.ArkUI';
import { BreakpointType, isWidthBreakpointLgOrXl, StyleConstants } from 'musicbasic';

/**
 * Playlist detail hero: cover, title, description, collect/download actions, and header size reporting.
 */
@ComponentV2
export struct PlaylistDetailHeroSection {
  /** Breakpoint-driven typography and spacing. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Header width in pixels for small-screen curved clip geometry. */
  @Param headerWidthPx: number = 0;
  /** Header height in pixels for small-screen curved clip geometry. */
  @Param headerHeightPx: number = 0;
  /** Vertical curve depth in pixels used in the path clip on compact layouts. */
  @Param depth: number = 18;
  /** Callback invoked when the hero container area changes (width/height in px). */
  @Param onHeaderAreaChange: (widthPx: number, heightPx: number) => void = (): void => {};

  /**
   * Renders large-column stacked hero or compact row hero with optional path clip.
   */
  build() {
    if (isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint)) {
      Column() {
        Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Image($r('app.media.ic_list_cover'))
              .width('100%')
              .aspectRatio(1)
              .borderRadius($r('sys.float.corner_radius_level4'))
              .objectFit(ImageFit.Cover)
            Text($r('app.string.playlist_play_count'))
              .fontSize(new BreakpointType(12, 12, 12, 12, 10).getWidthValueWithHeightSM(
                this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
              .fontColor($r('sys.color.font_on_primary'))
              .lineHeight(new BreakpointType(16, 16, 16, 16, 13).getWidthValueWithHeightSM(
                this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
              .fontWeight(FontWeight.Regular)
              .margin({
                left: new BreakpointType(6, 6, 8, 8).getValue(this.breakpointEnv.widthBreakpoint),
                bottom: new BreakpointType(6, 6, 8, 8).getValue(this.breakpointEnv.widthBreakpoint)
              })
          }
          .margin({
            top: 48,
            left: 24,
            right: 24,
            bottom: 24
          })

          Column({ space: 8 }) {
            Text($r('app.string.playlist_detail_title'))
              .fontSize(new BreakpointType(20, 30, 30, 30, 18).getWidthValueWithHeightSM(
                this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
              .lineHeight(new BreakpointType(27, 40, 40, 40, 24).getWidthValueWithHeightSM(
                this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_on_primary'))
            Text($r('app.string.playlist_detail_desc'))
              .fontSize($r('sys.float.Caption_M'))
              .fontWeight(FontWeight.Regular)
              .fontColor($r('app.color.hero_overlay_text_secondary'))
              .maxLines(2)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .align(Alignment.Center)
      }
      .margin({
        top: 16,
        left: 32,
        right: 32,
        bottom: 76
      })
      .padding({
        left: 24,
        right: 24,
        bottom: 24
      })
      .onAreaChange((oldRect: Area, newRect: Area) => {
        this.onHeaderAreaChange(
          this.getUIContext().vp2px(newRect.width as number),
          this.getUIContext().vp2px(newRect.height as number)
        );
      })
      .borderRadius($r('sys.float.corner_radius_level10'))
      .backgroundColor('#0F4587')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(HorizontalAlign.Center)
    } else {
      Column() {
        Flex({ direction: FlexDirection.Row }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Image($r('app.media.ic_list_cover'))
              .width(new BreakpointType(112, 156, 288, 288, 72).getWidthValueWithHeightSM(
                this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
              .height(new BreakpointType(112, 156, 288, 288, 72).getWidthValueWithHeightSM(
                this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
              .borderRadius($r('sys.float.corner_radius_level4'))
              .objectFit(ImageFit.Fill)
            Text($r('app.string.playlist_play_count'))
              .fontSize(new BreakpointType(12, 12, 12, 12, 10).getWidthValueWithHeightSM(
                this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
              .fontColor($r('sys.color.font_on_primary'))
              .lineHeight(new BreakpointType(16, 16, 16, 16, 13).getWidthValueWithHeightSM(
                this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
              .fontWeight(FontWeight.Regular)
              .margin({
                left: new BreakpointType(6, 6, 8, 8).getValue(this.breakpointEnv.widthBreakpoint),
                bottom: new BreakpointType(6, 6, 8, 8).getValue(this.breakpointEnv.widthBreakpoint)
              })
          }
          .width(new BreakpointType(112, 156, 288, 288, 72).getWidthValueWithHeightSM(
            this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
          .height(new BreakpointType(112, 156, 288, 288, 72).getWidthValueWithHeightSM(
            this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))

          Column({ space: 8 }) {
            Text($r('app.string.playlist_detail_title'))
              .fontSize(new BreakpointType(20, 30, 30, 30, 18).getWidthValueWithHeightSM(
                this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
              .lineHeight(new BreakpointType(27, 40, 40, 40, 24).getWidthValueWithHeightSM(
                this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_on_primary'))
            Text($r('app.string.playlist_detail_desc'))
              .fontSize($r('sys.float.Caption_M'))
              .fontWeight(FontWeight.Regular)
              .fontColor($r('app.color.hero_overlay_text_secondary'))
              .maxLines(2)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({
            left: new BreakpointType(12, 24, 24, 24, 11).getWidthValueWithHeightSM(
              this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint)
          })
        }
        .width(StyleConstants.FULL_WIDTH)
      }
      .padding({
        top: 56,
        left: new BreakpointType(16, 113, 24, 24).getValue(this.breakpointEnv.widthBreakpoint),
        right: new BreakpointType(16, 113, 24, 24).getValue(this.breakpointEnv.widthBreakpoint),
        bottom: 24
      })
      .onAreaChange((oldRect: Area, newRect: Area) => {
        this.onHeaderAreaChange(
          this.getUIContext().vp2px(newRect.width as number),
          this.getUIContext().vp2px(newRect.height as number)
        );
      })
      .clipShape(new PathShape({
        commands: `M 0 0 L ${this.headerWidthPx} 0 L ${this.headerWidthPx} ${this.headerHeightPx - this.depth} ` +
          `Q ${this.headerWidthPx / 2} ${this.headerHeightPx} 0 ${this.headerHeightPx - this.depth} Z`
      }))
      .backgroundColor('#0F4587')
      .width(StyleConstants.FULL_WIDTH)
      .justifyContent(FlexAlign.SpaceBetween)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
  }
}
