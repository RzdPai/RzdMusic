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
import { immersiveMedium } from '../util/ImmersiveMaterialV26';

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
  @Prop fallbackColor: ResourceColor = Color.Transparent;
  /** 点击回调（壳不抢事件，事件落在这层） */
  onTap?: () => void;
  /** 内容 */
  @BuilderParam content: () => void = this.emptyContent;
  /** 按下中（驱动形变与光晕） */
  @State touching: boolean = false;
  /** 触点（相对本组件左上角，vp） */
  @State touchX: number = 0;
  @State touchY: number = 0;

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

  /** 跟随手指的形变：朝触点方向微位移（上限 2vp）。 */
  private deformDx(): number {
    const dx: number = this.touchX - this.surfaceWidth / 2;
    return Math.max(-3, Math.min(3, dx * 0.10));
  }

  private deformDy(): number {
    const dy: number = this.touchY - this.surfaceHeight / 2;
    return Math.max(-3, Math.min(3, dy * 0.10));
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

      // 兜底色（**默认透明**：用户 2026-11-20「不要垫半透明」；材质不可用时再按需传实色）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.fallbackColor)
        .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
        .clip(true)
        .hitTestBehavior(HitTestMode.None)

      // ★ 2026-11-20（用户："光斑能不能用官方属性"）：
      //   官方光感反馈是 `uiMaterial.ImmersiveMaterial.lightEffect`（`.systemMaterial()` 的字段）。
      //   壳里这一层**再挂一次**：若能渲染，跟随手指的光就由**系统**给（比自绘光斑准），
      //   自绘光斑留作兜底（外壳材质不生效时仍有反馈）。
      Stack({ alignContent: Alignment.Center }) {
        this.content()
      }
      // ★ 2026-11-20（用户："演唱会按钮还是直接变大变小而不是形变"）：
      //   内容层那 0.97 的缩放就是"变大变小"的来源 ⇒ **删掉**。
      //   官方观感只来自外层"朝触点方向让形"的位移（见下面 `translate`），不做任何缩放。
      .systemMaterial(immersiveMedium())
      .width(this.surfaceWidth)
      .height(this.surfaceHeight)
      .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
      .clip(true)

      // ★ 2026-11-19（用户："官方的手拖动是有**形变和光效**的"）：
      //   系统材质本身只负责"玻璃"，按下/拖动时的**形变**与**跟随触点的光晕**要自己做 ——
      //   与参考工程 `qingye-reader` 的 `ImmersiveMaterialSurface` 同一做法：
      //   一层 radialGradient 圆斑，中心跟随触点，透明度按下渐显（160ms Friction）。
      Row()
        .width(this.surfaceHeight * 2.4)
        .height(this.surfaceHeight * 2.4)
        .position({ x: this.touchX - this.surfaceHeight * 1.2, y: this.touchY - this.surfaceHeight * 1.2 })
        .radialGradient({
          center: [this.surfaceHeight * 1.2, this.surfaceHeight * 1.2],
          radius: this.surfaceHeight * 1.2,
          // ★ 2026-11-20（用户："受光看不太出来"）：光斑太淡 ⇒ 提亮 + 加一圈内亮环，
          //   观感接近 legado 那种"手指按住有一团光跟着走"。
          colors: [['#B3FFFFFF', 0], ['#4DFFFFFF', 0.45], [Color.Transparent, 1]]
        })
        .opacity(this.touching ? 1 : 0)
        .animation({ duration: 160, curve: Curve.Friction })
        .hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no')
    }
    .width(this.surfaceWidth)
    .height(this.surfaceHeight)
    .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
    .clip(true)
    // ★ 2026-11-20（用户："官方按压后不是变大变小，是**跟随手指的轻微形变**"）：
    //   原来整颗 `scale(0.94)` = 缩小，那是错的。官方是**朝触点方向微微让形**：
    //   把内容按"触点相对中心的偏移"做极小位移（≈3%，上限 2vp），松手回中。
    //   观感是"这块玻璃被手指按得有点软"，而不是"按钮变小了"。
    .translate({
      x: this.touching ? this.deformDx() : 0,
      y: this.touching ? this.deformDy() : 0
    })
    .animation({ duration: 120, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      if (event.touches.length === 0) {
        this.touching = false;
        return;
      }
      const t: TouchObject = event.touches[0];
      this.touchX = t.x;
      this.touchY = t.y;
      if (event.type === TouchType.Down || event.type === TouchType.Move) {
        this.touching = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.touching = false;
      }
    })
    .onClick(() => {
      if (this.onTap !== undefined) {
        this.onTap();
      }
    })
  }
}
