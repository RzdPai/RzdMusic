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
import { immersiveCapsuleShadow } from '../util/ImmersiveMaterialV26';

/**
 * **沉浸光感底板**：给页面 body 里的自绘控件（圆钮 / 胶囊 / 浮层）挂上**真**系统材质。
 *
 * ## 为什么需要它
 *
 * API 26 的材质生效范围分两档：
 * - **A 档**（页面任意位置）：弹窗类接口 / `Slider` / `Toggle` / `Select` …
 * - **B 档**（只有两个槽位）：`Navigation/NavDestination` **标题栏** 与
 *   横向 `Tabs` 且 `barPosition=End` 的**底部悬浮页签**
 *
 * 页面 body 里的自绘 `Row/Column/Stack` 不在任何槽位里 ⇒ 直接写 `.systemMaterial()` 不渲染。
 * 本组件按官方 FAQ 给的解决措施第二条办事：**借 `Tabs` 底部悬浮栏这一条槽位**承载材质，
 * 内容自己叠在上面；壳不抢事件。
 *
 * ## 结构（自下而上，别再改顺序）
 *
 * ① `fallbackColor` 兜底 → ② `Tabs` 悬浮栏（材质 + **栏内白纱**）→ ③ 内容 → ④ 触点光斑，
 * 最后整颗挂一份 `immersiveCapsuleShadow()` 胶囊投影。
 *
 * 三条硬约束（踩过很多次）：
 * - **白纱要画在材质之上、且在同一节点**：真机实验（`dded32c` 的 A/B/C）证明灰只由
 *   "材质盖住白底"引起。壳的材质由悬浮栏绘制 ⇒ 白纱放**悬浮栏内容区**（`washTabBar`），
 *   放兄弟 `Column` 会被材质盖住；
 * - **壳/内容区一律透明**：`Tabs`、`TabContent`、内容层默认带系统表面色，不涂透明会漏灰；
 * - **一份材质**：同一子树只设一次，嵌套会重复计算并互相干扰（官方功耗文档）；
 *   投影同理 —— 材质自带的投影按**矩形**算，胶囊形状要自己投。
 *
 * ## 槽位细节（缺一个就看不到材质）
 *
 * - `barWidth` 只认**具体数值**，不能写 `'100%'`；
 * - `barSideMargin / barBottomMargin` 必须是 0；
 * - `maskColor = Color.Transparent`（否则上下有渐变白/黑边）；
 * - `barHeight` 与壳高一致，`barOverlap(true)`。
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

  /**
   * 悬浮栏内容 = **白纱**（等价官方 `Select` 的 `backgroundColor`）。
   *
   * ★★★★ 2026-11-22（真机实验结论，`dded32c` 那版的长按 A/B/C）：
   *   **只有 B（把 `.systemMaterial()` 挪到 `.backgroundColor()` 之后）会变灰**，A/C 都不灰
   *   ⇒ 根因是**顺序**：材质站在白底之上，白底被盖住，胶囊只剩材质自身的灰调。
   *   官方 `Select` 之所以不灰，是因为「材质 + 白底」**在同一个节点上、底画在材质之上**。
   *   壳的材质由 `Tabs` 悬浮栏绘制 ⇒ 与之"同节点"的区域就是**悬浮栏内容区**，
   *   把白纱放在这里，才真正做到"材质在下、白纱在上"（放在兄弟 `Column` 里会被材质盖住）。
   */
  @Builder
  private washTabBar() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.immersive_glass_overlay'))
      .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
      .clip(true)
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')
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
      // 材质赋色：与全仓其它材质同一份（20% 白/黑纱）。
      // ⚠️ 白纱**不在**这里加重 —— 那样等于"材质自己变白"，材质缺位的帧仍然是灰的；
      //   白纱由悬浮栏内容区提供（见 `washTabBar`）⇒ 与官方 `Select` 同构。
      materialColor: $r('app.color.immersive_glass_overlay'),
      lightEffect: { color: '#66FFFFFF' }
    });
  }

  private radiusVp(): number {
    return this.surfaceRadius >= 0 ? this.surfaceRadius : this.surfaceHeight / 2;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ① 兜底色（只在"材质不渲染"的设备/时刻显形；必须画在材质**下面**）
      //   官方 FAQ：材质层位于 backgroundColor 之下，不透明背景会盖住材质。
      //   所以这一层永远在 `Tabs` 之前，不能搬到它后面。
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.fallbackColor)
        .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
        .clip(true)
        .hitTestBehavior(HitTestMode.None)

      // ② 材质层：借 `Tabs` 底部悬浮栏这一条**官方材质槽位**（`barFloatingStyle.systemMaterial`）。
      //   ⚠️ 壳自身、`TabContent`、内容区**一律透明**：`Tabs`/`TabContent` 默认带系统表面色，
      //     不涂透明就会在材质没画出来的那几帧露出一整块灰（历史回归记录见 `9f79a5f` / `2603d3a`）。
      //   ⚠️ 不要再给 `barBackgroundColor` / `barBackgroundBlurStyle` 赋值 —— 官方口径是"不设置"。
      Tabs({ barPosition: BarPosition.End, index: 0 }) {
        TabContent() {
          Column().backgroundColor(Color.Transparent)
        }
        .backgroundColor(Color.Transparent)
        .height(this.surfaceHeight)
        .tabBar(this.washTabBar())
      }
      .barMode(BarMode.Fixed)
      .barHeight(this.surfaceHeight)
      .barOverlap(true)
      .barWidth(this.surfaceWidth)
      .barFloatingStyle({
        maskColor: Color.Transparent,
        systemMaterial: this.buildShellMaterial(),
        barSideMargin: 0,
        barBottomMargin: 0
      })
      .width(this.surfaceWidth)
      .height(this.surfaceHeight)
      .backgroundColor(Color.Transparent)
      .scrollable(false)
      .hitTestBehavior(HitTestMode.None)

      // ③ 内容层。⚠️ 这里**不能再挂** `.systemMaterial()` ——
      //   官方功耗文档「避免材质嵌套」：同一子树只在外层设一次，内层再设会重复计算、视觉互相干扰。
      Stack({ alignContent: Alignment.Center }) {
        this.content()
      }
      // ★ 2026-11-20（用户："演唱会按钮还是直接变大变小而不是形变"）：
      //   内容层那 0.97 的缩放就是"变大变小"的来源 ⇒ **删掉**。
      //   官方观感只来自外层"朝触点方向让形"的位移（见下面 `translate`），不做任何缩放。
      .width(this.surfaceWidth)
      .height(this.surfaceHeight)
      .borderRadius(this.radiusVp(), RenderStrategy.OFFSCREEN)
      .clip(true)

      // ④ 跟随触点的光斑（材质只负责"玻璃"，光感反馈的兜底靠自己画）。
      //   光斑是胶囊的 2.4 倍大，必须自带一层裁剪容器，否则会溢到胶囊外面
      //   （根节点为了让胶囊投影透出去已经不裁了）。
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
    // 形状仍由**每一层自己裁**（兜底层 / 内容层 / 光斑层各自 `borderRadius + clip`），
    // 根节点不裁：胶囊投影要画到外面去。
    .clip(false)
    // ★★★★ 2026-11-20 最终结论（用户）：**形变是 API 26 官方自带的行为** ——
    //   "API 23 上不设置形变按钮就是硬的；API 26 不设置 = 默认形变"。
    //   所以这里**什么位移/缩放都不要写**：自绘的 scale/translate 只会破坏官方形变
    //   （演唱会那颗长胶囊就是被我这层 `scale` 弄成"自动缩小"的）。
    //   本组件只负责：① 材质底板（`Tabs` 悬浮栏这条官方槽位）② 跟随触点的光晕。
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
