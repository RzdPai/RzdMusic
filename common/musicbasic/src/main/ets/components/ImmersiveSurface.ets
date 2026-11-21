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
import { uiMaterial } from '@kit.ArkUI';
import { immersiveCapsuleShadow, immersiveMedium } from '../util/ImmersiveMaterialV26';

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
  /**
   * 材质**之上**那层纱（默认不加）。
   *
   * ★ 2026-11-22：官方 `Select` 这类组件开材质后，结构是「材质在下 + `backgroundColor` 在上」，
   * 所以它看起来比"纯材质"白一层、而且自带投影。用户要求"把那几个按钮和平台切换对齐" ⇒
   * 需要对齐的点位传 `$r('app.color.immersive_glass_overlay')`（与 Select 的底色同一份资源），
   * 观感就与平台切换一致：白一层 + 有投影。
   * 默认 `Color.Transparent`（不加纱）—— 播放页盖在封面上的浮钮等点位不受影响。
   */
  @Prop washColor: ResourceColor = Color.Transparent;
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

  /**
   * 壳用的系统材质（API 26 `uiMaterial`；与全仓 `immersiveMedium()` 同一份参数）。
   *
   * ★ 2026-11-22（用户截图："现在阴影成了四角的方向（颜色比较淡）"）：
   *   材质投影是系统按**节点矩形**画的 —— 我们把材质托在 `Tabs` 悬浮栏上，拿到的是"方影子"，
   *   而官方 `Select` 的材质画在胶囊自己身上，影子是胶囊形。
   *   ⇒ 壳里**关掉材质投影**，改由根节点用 `immersiveCapsuleShadow()`（胶囊形状）统一投，
   *     这样四颗玻璃的投影才是同一份（官方 FAQ 也是这么写的：要自定义 shadow 就先把 applyShadow 置 false）。
   */
  private buildShellMaterial(): uiMaterial.ImmersiveMaterial {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: false,
      interactive: true,
      materialColor: $r('app.color.immersive_glass_overlay'),
      lightEffect: { color: '#66FFFFFF' }
    });
  }

  private radiusVp(): number {
    return this.surfaceRadius >= 0 ? this.surfaceRadius : this.surfaceHeight / 2;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ★★★ 2026-11-21（查官方 FAQ 得到的关键一条）：
      //   "沉浸光感的视觉层级位于组件的 backgroundColor / backgroundBlurStyle **之下**，
      //    不透明的背景会**覆盖在材质层之上**，导致材质不可见"。
      //   ⇒ 兜底色必须画在 **HdsTabs 之前（下层）**，不能画在它上面 ——
      //     之前它盖在材质上，所以材质永远出不来（表现为"纯白不透明"）。
      // 兜底色（传实色时只管兜底；默认透明）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.fallbackColor)
        .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
        .clip(true)
        .hitTestBehavior(HitTestMode.None)

      // 材质层：空 HdsTabs 壳（只为了那一条悬浮栏的 systemMaterialEffect）
      Tabs({ barPosition: BarPosition.End, index: 0 }) {
        TabContent() {
          // ★ 2026-11-21（用户："返回、搜索框、播放条都发灰，但平台切换是正常白"）：
          //   灰底来自 `TabContent` 的**系统表面色** —— 它默认不是透明的。
          //   这里把内容区涂成透明，只让悬浮栏那条材质可见。
          Column().backgroundColor(Color.Transparent)
        }
        .backgroundColor(Color.Transparent)
        .height(this.surfaceHeight)
        .tabBar(this.emptyTabBar())
      }
      .barMode(BarMode.Fixed)
      .barHeight(this.surfaceHeight)
      .barOverlap(true)
      // ★★★ 2026-11-21（H2 修法）：官方 API 26 示例里，Tabs 悬浮栏的材质字段是
      //   `barFloatingStyle.systemMaterial`（`uiMaterial.ImmersiveMaterial`）+ `maskColor`，
      //   **不是** HDS 的 `systemMaterialEffect`（那是 HDS 组件自己的口）。
      //   我们之前用 `systemMaterialEffect` ⇒ 壳只出**系统表面色（灰）**，材质根本没参与渲染。
      .barWidth(this.surfaceWidth)
      .barFloatingStyle({
        maskColor: Color.Transparent,
        // ★ 2026-11-21（H2）：ArkUI `Tabs` 的 `barFloatingStyle.systemMaterial` 才是官方 API 26 口；
        //   HDS 的 `HdsTabsFloatingStyle` 没有这个字段（只有 systemMaterialEffect，那条路只出灰表面）。
        systemMaterial: this.buildShellMaterial(),
        barSideMargin: 0,
        barBottomMargin: 0
      })
      .width(this.surfaceWidth)
      .height(this.surfaceHeight)
      .hitTestBehavior(HitTestMode.None)

      // ★ 2026-11-22（用户："我是想让你把那几个按钮和平台切换对齐"）：
      //   上一轮我把平台切换（官方 `Select`）"降级"成旁两颗的观感 —— 方向错了。
      //   用户要的是**反过来**：让返回/搜索框这几颗长成平台切换的样子。
      //   平台切换为什么"更白 + 有投影"（有据可查）：
      //     ① 材质层在**下**、`backgroundColor` 那层 20% 白纱在**上** ⇒ 白一层；
      //     ② 材质 `applyShadow` 默认 true ⇒ 自带投影。
      //   我们这颗壳的问题是 ① 根本没有那层纱、② 投影被根节点的 `clip(true)` 裁掉了。
      //   ⇒ 补一层纱（`washColor`，默认透明＝不加；要对齐的点位传 `immersive_glass_overlay`），
      //     并把根的裁切去掉，让**材质自带的投影**能画到胶囊外面（圆角由各层自己裁）。
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.washColor)
        .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
        .clip(true)
        .hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no')

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
      // ★ 2026-11-22：光斑本身是胶囊的 2.4 倍大，原来靠**根节点**的 `clip(true)` 裁成胶囊形状；
      //   根节点为了露出材质投影已经不裁了 ⇒ 光斑必须自己裁（否则光会溢到胶囊外面）。
      Stack({ alignContent: Alignment.TopStart }) {
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
      .width('100%')
      .height('100%')
      .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
      .clip(true)
      .hitTestBehavior(HitTestMode.None)
    }
    .width(this.surfaceWidth)
    .height(this.surfaceHeight)
    .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
    // ★★★ 2026-11-22（用户截图："现在阴影成了四角的方向（颜色比较淡）"）：
    //   上一版放开裁切后露出的是**材质自带的投影**，而材质投影按"节点矩形"算 ⇒ 长成方影子。
    //   正确写法（官方 FAQ："如需自定义阴影，应将 applyShadow 置为 false 后再使用 shadow"）：
    //     ① 壳里的材质 `applyShadow: false`（见 `buildShellMaterial`）；
    //     ② 由**这个胶囊形状的根节点**投一份统一投影（`immersiveCapsuleShadow()`）。
    //   ⇒ 四颗玻璃（返回 / 搜索框 / 平台切换 / 其余壳）投的是同一份胶囊阴影，与"谁画材质"无关。
    .shadow(immersiveCapsuleShadow())
    // 形状仍由**每一层自己裁**（兜底层 / 白纱层 / 内容层 / 光斑层都各自 `borderRadius + clip`），
    // 根节点不裁：胶囊投影要画到外面去。
    .clip(false)
    // ★★★★ 2026-11-20 最终结论（用户）：**形变是 API 26 官方自带的行为** ——
    //   "API 23 上不设置形变按钮就是硬的；API 26 不设置 = 默认形变"。
    //   所以这里**什么位移/缩放都不要写**：自绘的 scale/translate 只会破坏官方形变
    //   （演唱会那颗长胶囊就是被我这层 `scale` 弄成"自动缩小"的）。
    //   本组件只负责：① 材质底板（空 HdsTabs 悬浮栏）② 跟随触点的光晕。
    //   ⚠️ 不要再往这里加 `.scale()` / `.translate()`。
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
