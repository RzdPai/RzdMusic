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
import { HdsTabs, hdsMaterial } from '@kit.UIDesignKit';

/**
 * **沉浸光感底板**：给任意自绘控件（圆钮 / 胶囊 / 浮层）挂**真**系统材质。
 *
 * ## 为什么需要这么一个组件
 *
 * 官方把材质生效范围分成两档（API 26）：
 * - **A 档**：弹窗类 / Button / Slider / Toggle / Select …
 * - **B 档**：**只有** `Navigation/NavDestination` 标题栏 与 `barPosition=End` 的**底部悬浮页签**
 *
 * 页面 body 里的自绘 `Row/Column/Stack` 属 B 档且不在槽位内 ⇒ `.systemMaterial()` 写了也不渲染
 * （编译能过，屏上什么都没有 —— 我们前几轮踩的就是这个）。
 *
 * ## 做法（照 `qingye-reader` 的 `ImmersiveMaterialSurface`）
 *
 * **借一个只有悬浮栏的空 `HdsTabs` 壳**：材质由 `barFloatingStyle.systemMaterialEffect` 提供，
 * 内容自己叠在上面；壳 `hitTestBehavior(None)` 不抢事件。
 *
 * ⚠️ 几个必须照抄的细节（缺一个就看不到材质）：
 * - `barWidth` 只认**具体数值**（三种断点都写同一个数），不能写 `'100%'`；
 * - `barSideMargin / barBottomMargin` 必须是 0；
 * - `gradientMask.maskColor = Color.Transparent`（否则上下有渐变白/黑边）；
 * - `barHeight` 与壳高一致，`barOverlap(true)`；
 * - 圆角要 `borderRadius(r, RenderStrategy.OFFSCREEN)` + `clip(true)`。
 */
@Component
export struct ImmersiveSurface {
  /** 宽（vp，具体数值） */
  @Prop surfaceWidth: number = 40;
  /** 高（vp，具体数值） */
  @Prop surfaceHeight: number = 40;
  /** 圆角（vp）；默认按高度取圆钮 */
  @Prop surfaceRadius: number = -1;
  /** 不支持材质的设备用这个底色兜底 */
  @Prop fallbackColor: ResourceColor = '#33000000';
  /** 点击回调（壳不抢事件，事件落在这层） */
  onTap?: () => void;
  /** 内容 */
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  /** 空的页签内容（材质由悬浮栏画，内容区必须是 0 高）。 */
  @Builder
  emptyTabBar() {
    Stack()
      .width(0)
      .height(0)
  }

  private radiusVp(): number {
    return this.surfaceRadius >= 0 ? this.surfaceRadius : this.surfaceHeight / 2;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 材质层：空 HdsTabs 壳（只为了那一条悬浮栏的 systemMaterialEffect）
      HdsTabs({ barPosition: BarPosition.End, index: 0 }) {
        TabContent() {
          Column()
        }
        .height(this.surfaceHeight)
        .tabBar(this.emptyTabBar())
      }
      .barMode(BarMode.Fixed)
      .barHeight(this.surfaceHeight)
      .barOverlap(true)
      .barFloatingStyle({
        barWidth: {
          smallWidth: this.surfaceWidth,
          mediumWidth: this.surfaceWidth,
          largeWidth: this.surfaceWidth
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        barSideMargin: 0,
        barBottomMargin: 0,
        gradientMask: { maskColor: Color.Transparent, maskHeight: this.surfaceHeight },
        adaptToHandedness: false,
        thermoCtrl: true,
        barOpacity: 1
      })
      .scrollable(false)
      .onContentWillChange(() => false)
      .width(this.surfaceWidth)
      .height(this.surfaceHeight)
      .hitTestBehavior(HitTestMode.None)

      // 兜底色（材质不可用时才看得见）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.fallbackColor)
        .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
        .clip(true)
        .hitTestBehavior(HitTestMode.None)

      // 内容
      Stack({ alignContent: Alignment.Center }) {
        this.content()
      }
      .width(this.surfaceWidth)
      .height(this.surfaceHeight)
      .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
      .clip(true)
    }
    .width(this.surfaceWidth)
    .height(this.surfaceHeight)
    .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
    .clip(true)
    .onClick(() => {
      if (this.onTap !== undefined) {
        this.onTap();
      }
    })
  }
}
