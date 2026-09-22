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


import { StyleConstants } from 'musicbasic';
import { LengthMetrics } from '@kit.ArkUI';

/**
 * Immersive-style capsule header: profile/search affordances, horizontal nav chips, and brand marquee.
 */
@ComponentV2
export struct HomeCapsuleHeader {
  /** Index of the highlighted top-nav chip in the local nav label list. */
  @Local selectedNavIndex: number = 0;
  /**
   * Top navigation tab labels (string resources for base, en_US, zh_CN, etc.).
   */
  private readonly navLabels: Resource[] = [
    $r('app.string.capsule_nav_home'),
    $r('app.string.capsule_nav_concert_hall'),
    $r('app.string.capsule_nav_kids'),
    $r('app.string.capsule_nav_spatial_audio'),
    $r('app.string.capsule_nav_home_time')
  ];
  private navScroll: Scroller = new Scroller();

  /**
   * Full-width row with centered capsule list and trailing brand block with marquee text.
   */
  build() {
    Row() {
      Blank()
        .width('25%')
      Row({ space: 10 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.person_fill'))
            .fontSize(26)
            .fontWeight(FontWeight.Regular)
            .height(26)
            .fontColor([$r('app.color.capsule_brand_icon')])
            .margin(11)
            .accessibilityText('个人中心')
            .accessibilityLevel('yes')
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(26)
            .fontWeight(FontWeight.Regular)
            .height(26)
            .fontColor([$r('app.color.capsule_brand_icon')])
            .margin(11)
            .accessibilityText('搜索')
            .accessibilityLevel('yes')
        }

        List({ space: 6, scroller: this.navScroll }) {
          ForEach(this.navLabels, (label: Resource, index: number) => {
            ListItem() {
              Row() {
                Text(label)
                  .fontSize(24)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.selectedNavIndex === index ? $r('app.color.capsule_nav_text_active') : $r('app.color.capsule_nav_text_inactive'))
                  .lineHeight(32)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .padding({
                left: 18,
                right: 18,
                top: 8,
                bottom: 8
              })
              .borderRadius(64)
              .backgroundColor(this.selectedNavIndex === index ? $r('app.color.capsule_nav_bg_active') : Color.Transparent)
              .height(48)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.selectedNavIndex = index;
                this.navScroll.scrollToIndex(index, true, ScrollAlign.CENTER);
              })
            }
          }, (label: Resource, index: number) => `capsule-nav-${index}`)
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .height(48)
        .fadingEdge(true, {
          fadingEdgeLength: LengthMetrics.vp(40) 
        })
      }
      .backgroundColor($r('app.color.capsule_container_bg'))
      .height(64)
      .padding(8)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(48)
      .width('55%')
      .borderWidth(1)
      .borderColor($r('app.color.capsule_container_border'))

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.rhythm'))
          .fontSize(22)
          .fontWeight(FontWeight.Regular)
          .height(22)
          .fontColor([$r('app.color.capsule_brand_icon')])
        Text($r('app.string.brand_huawei_music'))
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.capsule_brand_text'))
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .maxLines(1)
          .layoutWeight(1)
          .shaderStyle({
            direction: GradientDirection.Right, 
            colors: [
              ['#00ffffff', 0.0], 
              ['#ffffffff', 0.5], 
              ['#00ffffff', 1.0]  
            ]
          })
          .marqueeOptions({
            start: true,
            fromStart: true,
            step: 6,
            loop: -1,
            delay: 0,
            fadeout: false,
            marqueeStartPolicy: MarqueeStartPolicy.DEFAULT
          })
      }
      .width(182)
      .height(64)
      .padding({
        left: 19,
        right: 19,
        top: 17,
        bottom: 17
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(48)
      .backgroundColor('#26ffffff')
      .borderWidth(1)
      .borderColor('#26ffffff')
      .margin({ left: 45 })
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 24, right: 24 })
    .margin({
      top: 32,
      bottom: 32
    })
    .alignItems(VerticalAlign.Center)
  }
}
