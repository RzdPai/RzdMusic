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

/**
 * 全屏播放页的 **NavDestination 路由壳**（施工图第 1 步）。
 *
 * 无界 1.2.4 的播放页就是一个被 `nav.pushPath({name, param:{pull:true}}, false)` 推入的
 * `HdsNavDestination`（第二参 animated = false，系统转场关掉）——这里照搬这个形状：
 *
 *   · `hideTitleBar(true)`   —— 播放页没有标题栏，形变容器要从迷你条一路长到整屏；
 *   · 背景**透明**            —— ★ 关键：形变早期可视矩形只有迷你条封面那么大，
 *                               其余区域必须透出下层的首页与迷你条，否则又是
 *                               "一块黑底 + 下方空白"（用户实测过的那两个 bug）；
 *   · ★★ `.mode(NavDestinationMode.DIALOG)` —— **补上这一句是 2026-09-25 那次回退的解药**，
 *                               详见下面「为什么必须是 DIALOG」。
 *
 * 官方依据：`document/cn/harmonyos-guides/arkts-shared-element-transition` 明确写
 * "为了避免触发 Navigation 的转场动画，在 pushPath() 的时候把动画选项设置成了 false"。
 *
 * ─────────────────── 为什么必须是 DIALOG（★ 本句的出处与理由）───────────────────
 * **逆向证据**：无界的播放页 `HdsNavDestination` **确实设了它** ——
 * `wujie.pa:190804-190811`：`ldobjbyname "mode"` → `tryldglobalbyname "NavDestinationMode"` → 取枚举值。
 *
 * **官方语义**（本机 SDK `openharmony/ets/component/nav_destination.d.ts:317-333`）：
 * > "Dialog mode, where the navigation destination is **transparent by default**,
 * >  and adding or removing the navigation destination **does not affect the underlying
 * >  page's lifecycle**."
 * `NavDestinationMode.DIALOG = 1`（`STANDARD = 0`）。
 *
 * **⇒ 这正是上次回退缺的那一块**：RzdMusic 2026-09-25 上机时播放页用的是 **STANDARD**，
 * 那个模式下 NavDestination 自带不透明底，"透明背景也压不住 HDS 自带的底"，
 * 于是**同在该 `HdsNavigation` 里的 HDS 浮动底栏（迷你条真身）被整片盖住** ——
 * 而形变恰恰要透出那条迷你条。DIALOG 模式**默认就是透明的、且不影响下层页面**，
 * 所以下层首页与迷你条在形变全程**可见、可量**（量得到是形变的前提：
 * `expand.init` 要靠 `getFrameNodeById` 的矩形算起点）。
 *
 * ⚠️ **DIALOG 的代价（必须知道）**：
 * 1. DIALOG 类型**默认不响应返回键** ⇒ 必须显式给 `.onBackPressed()`（本文件已有，
 *    否则系统返回会直接穿透到下层，播放页关不掉）。
 * 2. 它不再有系统转场与系统底 —— 顶栏/背景/裁剪全部由播放页自己画（本来就该如此，
 *    形变自己就是动画）。
 * 3. `.mode()` 的 API 归属已核：`HdsNavDestinationAttribute.mode(value: NavDestinationMode)`
 *    （HDS 声明 `@hms.hds.hdsBaseComponent.d.ets:2547`）。
 *
 * ⚠️ 这里**只放壳**：播放页本体、形变几何、克隆层都在原有位置
 *    （`PlaybackPage` / 壳层 `products/…/pages/Index.ets`），不重复实现。
 *    "先量目标节点、再压到起点"的顺序由 `PlaybackPage.playExpandIntro()`（onAppear 起，
 *    带 12×32ms 重试）负责，等价于反编译里 `setupExpandTransition` 的那一刻。
 */

import { AppStorageKeys, areaLengthToVp, guardPlayerBack, Logger, PlayerExpandState, StyleConstants } from 'musicbasic';
import { AppStorageV2 } from '@kit.ArkUI';
import { HdsNavDestination } from '@kit.UIDesignKit';
import { PlaybackPageCoverContent } from './PlaybackPage';

/**
 * 播放页路由壳。
 *
 * ## 它为什么必须存在（两个用户实测 bug 的同一个落点）
 *
 * 无界的播放页 `HdsNavDestination` 上有这么一句（`wujie.pa:190867-190884`，
 * 转写见 `_recover/logic-src/PlayerPage完整UI定稿.md` L62）：
 *
 * ```ts
 * .backgroundColor( this.pullMode && this.effT() >= 1 ? PULL_REST_BG : this.expand.overlayColor )
 * ```
 *
 * 即 **形变期透明（要透出下层的首页与迷你条）、静止态不透明（`PULL_REST_BG`）**。
 * 我们原来只有 `Color.Transparent` 一档恒定值 ⇒ 在两个地方露出破绽：
 *
 * 1. **「播放页底部一条空白（会漏出后面的内容）」**：DIALOG 类型的目的地默认透明，
 *    内容区又不覆盖底部避让区 ⇒ 那一条上透出的就是下层的首页；
 * 2. **「内容没延伸进状态栏」**：同上，状态栏那一条也没被播放页自己的底盖住。
 *
 * ★★★ 2026-10-17（**本轮回原始字节码复核这一段，两条结论：一处存疑、一处已对**）
 *
 * **(a) `PULL_REST_BG` 的确切值 = `"#FF000000"`（不透明纯黑）** —— 常量表
 *   `MiniMorph渲染方与顶底栏淡入公式.md:175` 记 `PULL_REST_BG | "#FF000000"`。
 *   ⚠️ 而本仓 `REST_BG` 取的是 **`#1c1c1e`**（深灰，非纯黑）。
 *   差别只在"内容盖不住的那两条带（状态栏/底部避让）"上可见；
 *   **没改**，因为还要先确认一件事（见 (b)）—— 它属于**待用户看一眼**的清单，见
 *   `RzdMusic待确认清单.md`（问法："播放页静止时，状态栏那一条 / 底部那一条是什么颜色？"）。
 *
 * **(b) 那句三元的**前半段是 `pullMode &&**（`wujie.pa:190867` 之前那几行）
 *   ⇒ **我们这条路（`pullMode === false` 的路由模式）走的是后半段 `expand.overlayColor`**，
 *   而它在静止态恒为 `"#00000000"`（构造器 `wujie.pa:50868` 附近；`applyPullProgress`
 *   与 `doEnter/doBack` 的两个 `onFinish` 也都把它写回 `#00000000`）
 *   ⇒ **无界在路由模式下静止态其实也是透明的**。
 *   ⚠️ 那为什么本仓要给它一个不透明色？因为**我们页面的内容并不自己盖住那两条带**
 *   （见本段开头 1️⃣2️⃣ 两条实测）—— 所以这里**不是**简单照抄就能对的：
 *   照抄 ⇒ 那两条带会漏出首页；不照抄 ⇒ 颜色值对不上。⇒ 先按 (a) 的用户读数再定。
 *
 * **(c) 已确认**：判据用 `morphContainerActive()` 与无界的 `effT() >= 1` **语义等价**
 *   （本仓 L166-167 的原注释已经论证过）✓ 不用改。
 *
 * ## 为什么做成"内容外面包一层 `@ComponentV2`"而不是直接写在 NavDestination 上
 *
 * 那句底色**必须跟着形变相位变**（透明 ⇄ 不透明），而本文件里的 `PlaybackPageBuilder`
 * 是**顶层 `@Builder` 函数**：它在 `@ObservedV2` 属性上的读**不被视图登记**，
 * 改成"读状态"很可能只取到首帧的值（而首帧正好是形变期 ⇒ 永远透明 ⇒ 白改）。
 * 包一层 `@ComponentV2` 后，`build()` 里对 `@Trace` 的读是**被登记的** ⇒ 相位一变就重绘 ✓。
 *
 * `expandSafeArea([SYSTEM],[TOP,BOTTOM])` 挂在**这一层**（不是页面内部）：
 * 它把本层的**绘制区**（含 `backgroundColor`）铺进状态栏与底部导航条那两条。
 * ⚠️ 这正是 `PlaybackPage.ets` L3247 那条"**不许在 `PlaybackPageCoverContent` 里写
 *    `expandSafeArea`**"的合规落点 —— 那条规矩反对的是"在页面内容里再扩一次"（会和外壳
 *    容器冲突、底部留白反而变大），而**外壳边界这一层**才是无界放它的地方
 *    （`PlayerPage完整UI定稿.md` L98：内容根 `winW×winH` + `expandSafeArea`）。
 */
@ComponentV2
struct PlaybackPageRouteShell {
  /** 静止态（非形变期）播放页自己的底：与页面内那层近黑垫底同值 ⇒ 静止态观感零变化。 */
  private static readonly REST_BG: string = '#1c1c1e';

  private expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /**
   * @returns 内容根宽度 —— **实测窗口宽**（对标无界 `winWVp()`）。
   *
   * ★★ 2026-10-15（`RzdMusic记忆.md` §56.40 的像素证据）：用户报的「顶部/底部空一块」
   *   经裁图量出是**上下各 ≈47vp / ≈45vp**（正好状态栏与导航条高度），
   *   而**形变几何全走窗口坐标** ⇒ 内容盒一旦比窗口小，飞入起点与封面落点就整体偏下。
   *   无界对这一处的写法是明确的（`PlayerPage完整UI定稿.md` L98）：
   *   **内容根 = `winWVp() × winHVp()`（实测窗口尺寸）+ `expandSafeArea`** —— **不是 `'100%'`**。
   *   ⇒ 这里照抄换成实测尺寸。**量不到（= 0）时退回 `'100%'`**，与改前行为一致（不会把页面搞成 0 尺寸）。
   *   ⚠️ 若 `'100%'` 本来就等于窗口，这一条**是无副作用的**（与改前逐像素相同）——
   *      所以它属于"要么无害、要么治病"的加固，不引入新的不确定。
   */
  private boxWidth(): number | string {
    const w: number = this.expandState.windowWidthVp;
    return w > 0 ? w : StyleConstants.FULL_WIDTH;
  }

  /** @returns 内容根高度 —— **实测窗口高**（对标无界 `winHVp()`）；量不到时退回 `'100%'`。理由同上。 */
  private boxHeight(): number | string {
    const h: number = this.expandState.windowHeightVp;
    return h > 0 ? h : StyleConstants.FULL_HEIGHT;
  }

  build() {
    Stack() {
      PlaybackPageCoverContent()
    }
    // ★ 内容根尺寸 = **实测窗口**（无界的 `winWVp()/winHVp()`），不是 `'100%'` —— 见上面两个方法的注释。
    .width(this.boxWidth())
    .height(this.boxHeight())
    // ★★ 2026-10-15 决定性判据（`hdc shell hilog -x | Select-String 'RzdPlayerRouteBox'`）：
    //   **这是唯一能直接回答「内容盒是不是等于窗口」的一条** ——
    //   ⚠️ 壳层那条 `RzdPlayerViewport`（`RzdPlayerViewport`）只在**非路由模式**
    //      （`PLAYER_ROUTE_MODE === false`）下才挂载，而我们是**路由模式** ⇒ 它**从来不会打**。
    //   **判据**：`box` 与 `win` 两个尺寸**
    //     · 相等 ⇒ 内容盒 = 窗口 ⇒ 「顶部/底部空一块」**不是**内容盒问题
    //       ⇒ 那两条空白只能是**页面内部**自己画的（例如网格背景的渲染色域/暗角），或者
    //         是「安全区里画了底色而内容没铺」的层序问题；
    //     · `box` 比 `win` **小**（差 ≈ 上下安全区之和）⇒ **内容盒仍被顶掉**
    //       ⇒ 说明 HDS 那一层还在压（`ignoreLayoutSafeArea` 没吃透），要继续往上找。
    .onAreaChange((_oldArea: Area, area: Area): void => {
      // ★ 2026-10-15（§56.50 / §56.51）：把**页盒顶边**喂给 `expandState` ——
      //   它是 `topInsetVp()` 的自适应修正项（"让位量是相对盒顶的"）。
      //   量到之后：盒顶 0 ⇒ 让位 56、盒顶 47 ⇒ 让位 9，**两者内容顶边都落在窗口的 56 线上** ✓
      //   ⇒ 结果对"页根扩展到底有没有生效"免疫（不需要先确认 `expandSafeArea` 是否被 HDS 吃透）。
      this.expandState.reportPageBoxTop(areaLengthToVp(area.position.y));
      // ⚠️ `Area.width/height/position.*` 的类型是 `Length`（`number | string | Resource`）
      //   ⇒ **不能调 `.toFixed()`**（编译期报 `Property 'toFixed' does not exist on type 'Length'`，
      //   本轮实测踩过一次）。模板串里**直接插值**即可（壳层那条 `RzdPlayerViewport` 就是这么写的）。
      Logger.info('RzdPlayerRouteBox',
        `box=${area.width}x${area.height} ` +
        `pos=(${area.position.x},${area.position.y}) ` +
        `win=${this.expandState.windowWidthVp.toFixed(0)}x${this.expandState.windowHeightVp.toFixed(0)} ` +
        `pad=${this.expandState.topInsetVp().toFixed(1)}/${this.expandState.navigationBarBottomVp.toFixed(1)}`);
    })
    // ★ 形变期透明 / 静止态不透明（对标无界那一句三元表达式）。
    //   判据用 `morphContainerActive()`（stage ∈ ENTERING/LEAVING/LANDING）而不是
    //   `effT()>=1`：两者语义等价（形变中为真、落位后为假），而前者在本仓已有稳定实现。
    .backgroundColor(this.expandState.morphContainerActive() ? Color.Transparent : PlaybackPageRouteShell.REST_BG)
    // ★★★ 2026-10-17（**删掉这里那条 `.scale({y: morphSquashY})` —— 它是本仓自创的消费点**）
    //
    // 上一轮为了让"关闭落位那一记弹"连背景一起压，把 `morphSquashY` 挂到了**路由壳**这一层
    // （播放页的绘制层）。**无界没有这个消费点**：
    //   · `SQUASH_Y = 0.86` 真正消费在**迷你条胶囊**的 `scaleY` 弹簧上
    //     （`MainPage`；见 `RzdMusic记忆.md` §56.33 / 待确认清单 E1，
    //      声明 `wujie.pa:198175-198192`、唯一使用点 `176560-176579`）；
    //   · `PlayerPage` 只把 `morphSquashing` 当**布尔绘制门**读
    //     （`pullPaintable()`：`!pullGeomReady ? true : !morphSquashing`），**从不拿它做缩放**。
    //
    // ## 为什么它有害（这就是用户第 ③ 条「关闭后突然来个展开动画」的候选机制）
    //   关闭落位那一 tick 的顺序是
    //   `morphLand()` → `squashLandAnim()`（起 110ms 压 + 320ms 回弹）→ `isShowPlay = false`（→ pop）
    //   ⇒ 路由壳在被 pop 之前的那 1~2 帧里，正被 `.scale({x:1, y:0.86})` 压着，
    //     而**整个播放页（含背景、含裁剪窗口）都在这个壳里** ⇒ 那 1~2 帧屏上是
    //     "一幅被纵向压扁/回弹的播放页" ⇒ 观感正是"**突然又来一下展开/弹动**"。
    //   ⚠️ 而它在**静止态恒为 1**，所以删掉它对静止版面与展开动画**零影响**
    //     （这一条上一轮的注释里也写了）。
    //   ⚠️ 迷你条那一份消费点**保留**（`HomeMiniBarPlayer` / `MiniBarPlayer` 的
    //     `.scale({x:1, y: morphSquashY})`）—— 那才是无界对应的那个（用户确认过的 ⑥）。
    //   ⚠️ `PlaybackPage.morphOpacityValue()` 里那处只读判断（`morphSquashY !== 1` 的诊断位）保留。
    //
    // 复核命令：`grep -rn 'morphSquashY' RzdMusic --include=*.ets`
    //   期望：写入处只有 `PlayerExpandState.squashLandAnim()`；
    //         消费处只有迷你条那两个（`HomeMiniBarPlayer` / `MiniBarPlayer`）+ 诊断位。
    // ⚠️ 2026-10-15：本层的 `.expandSafeArea(...)` 已**移走** —— 安全区的两个属性统一写在
    //   **页根（`HdsNavDestination`）**上（见那个 builder 里的注释）。
    //   理由：写两层会与外壳容器打架（`PlaybackPage.ets` L3247 那条"写错地方反而留白更大"
    //   说的就是这种情况）；而且**页根的布局区一旦铺满整窗**，本层 `height('100%')` 自然就是整窗，
    //   上面那层 `backgroundColor` 也就跟着铺满，**不需要**在这里再扩一次绘制区。
  }
}

/**
 * 路由构建函数（`router_map.json` 的 `buildFunction` 指向它）。
 */
@Builder
export function PlaybackPageBuilder(): void {
  HdsNavDestination() {
    PlaybackPageRouteShell()
  }
  // ★★ 必须设 DIALOG：默认透明 + 不影响下层页面 ⇒ 迷你条真身在形变全程可见、可量。
  //    （不给它就会退回 2026-09-25 那次"一推入就成一块、底部又缺一块"的失败状态。）
  .mode(NavDestinationMode.DIALOG)
  // ⚠️ DIALOG 类型默认不吃返回键，必须显式接管，否则系统返回会穿透到下层页面。
  .onBackPressed((): boolean => guardPlayerBack('PlaybackPageRoute'))
  .hideTitleBar(true)
  .backgroundColor(Color.Transparent)
  .width('100%')
  .height('100%')
  // ★★ 2026-10-15（修用户实测「**播放页顶部和底部还是空一块**」，并顺带修「**动画起始位置偏下**」
  //   与「**播放页封面位置不对**」）：**这里缺的是 `ignoreLayoutSafeArea`**。
  //
  //   工程里既有的成功范例写得很清楚（`SongQueueListPage` 的注释）：全屏页的**页根**要**三件套**
  //   —— `NavDestination` + **`expandSafeArea`（扩绘制区）** + **`ignoreLayoutSafeArea`（扩布局区）**。
  //   我上一版**只加了 `expandSafeArea`、而且加在内层 Stack 上** ⇒ **只扩了绘制、没扩布局**
  //   ⇒ 内容盒上下仍被安全区顶掉两条：
  //     · ① 那两条**空块照旧**（用户实测"还是空一块"）；
  //     · ② **更要紧**：形变几何全走**窗口坐标**（`getRectangleById` 量的、`reportBig` 报的、
  //       迷你条胶囊的起点矩形），内容盒整体一偏 ⇒ **量到的矩形偏下**
  //       ⇒ 用户看到的「动画起始位置偏下」「播放页封面位置不对」。
  //   ⇒ **三条症状是同一个根因**（内容盒 ≠ 窗口盒）。
  //   ⚠️ 两个属性**都写在页根上**：写在内容里会与外壳容器冲突（`PlaybackPage.ets` L3247 的警告）。
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
}
