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

import { AppStorageV2 } from '@kit.ArkUI';
import { DividerMode, HdsTabs, hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';
import { AppStorageKeys, areaLengthToVp, Logger, PlayerExpandState } from 'musicbasic';

/**
 * 胶囊的**横向**余量（vp）——照抄无界 `CAPSULE_SLACK_W`。
 *
 * 字节码：`wujie.pa:60315 ldai 0xa` + `60316 stmodulevar 0x1`（模块槽 1 = W = 10），
 * 槽位方向由 `59958-59960 ldlocalmodulevar 0x1 + throw.undefinedifholewithname "CAPSULE_SLACK_W"` 反证。
 */
export const CAPSULE_SLACK_W: number = 10;

/**
 * 胶囊的**纵向**余量（vp）——照抄无界 `CAPSULE_SLACK_H`。
 *
 * 字节码：`wujie.pa:60317 ldai 0x14` + `60318 stmodulevar 0x0`（= 20）。
 * 它同时决定"条底到本盒底的距离"：无界 `barFloatingStyle.barBottomMargin = slackH / 2`
 * （`wujie.pa:60229-60233`：`ldobjbyname "slackH"` → `ldai 0x2` → `div2` → `definepropertybyname "barBottomMargin"`）
 * ⇒ 上下各 10vp ⇒ 胶囊在盒子里**居中对齐**，这就是 squash 能"绕胶囊中心压"的前提。
 */
export const CAPSULE_SLACK_H: number = 20;

/** 诊断 tag（`hdc shell hilog | grep RzdMiniBarCapsule`）。 */
const LOG_TAG: string = 'RzdMiniBarCapsule';

/** HDS 交给 `tabBar` 的**槽**探针节点 id（透明占位，尺寸与旧内容盒逐像素相同）。 */
const SLOT_PROBE_ID: string = 'rzd_mini_capsule_slot_probe';

/** 我们自己的**内容层**节点 id（= 胶囊矩形）。 */
const CONTENT_PROBE_ID: string = 'rzd_mini_capsule_content';

/**
 * `material` 的缺省值：无界 `adaptiveMaterial()` 的兜底档。
 *
 * 依据：`design__src__main__ets__theme__Material.ets:31-40`（反编译）——
 * `adaptiveMaterial()` 返回 `{ materialType, materialLevel }`，且 SDK
 * `@hms.hds.hdsBaseComponent.d.ets:1391/1401` 两个字段的 `@default` 分别是
 * `MaterialType.NONE` / `MaterialLevel.ADAPTIVE`；本仓 `ambientTitleMaterial()` 的 `default` 分支
 * 也是 `ADAPTIVE + ADAPTIVE`，两处同一口径。
 */
const DEFAULT_MATERIAL: SystemMaterialParams = {
  materialType: hdsMaterial.MaterialType.ADAPTIVE,
  materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
};

/**
 * 迷你播放条**材质胶囊**：无界 `design/components/MaterialCapsule.ets` 的 V2 移植版。
 *
 * ══════════════════════ 一、为什么必须是"我们子树里的一个 HdsTabs" ══════════════════════
 *
 * 要同时拿到「沉浸光感」+「关闭播放器时整条压/弹」，只有这一种结构成立：
 *
 *   · 光感的**唯一合法载体**（API 23/24 档）是 `HdsTabsFloatingStyle.systemMaterialEffect`
 *     （`@hms.hds.hdsBaseComponent.d.ets:5357` ← `HdsTabs.barFloatingStyle` :5582）。
 *     `CommonMethod` 上没有这个属性 ⇒ `.backgroundColor + .backgroundBlurStyle` 那种自绘
 *     永远只是"近似"，不是官方材质（前两轮分别被用户否掉过一次）。
 *   · 挤压（`morphSquashY`）要求"材质层"落在**能被 `.scale` 压到的子树**里。
 *     HDS 帮我们画背板时（`HdsTabsMiniBar.enableMiniBarBackground` :5169），那块背板在
 *     **宿主 HdsTabs 的子树**里、是 `miniBar` 槽的兄弟 ⇒ 我们怎么 scale 都压不到它。
 *     ⇒ 唯一解法：**把 HdsTabs 搬进我们自己的子树**（下面这一层），`.scale` 挂在它的**父** `Stack` 上。
 *
 * 无界就是这么做的，两处直接字节码为证：
 *   · `MaterialCapsule`（`wujie.pa:60082-60279`）= `HdsTabs` + `TabContent.tabBar(content)` +
 *     `barOverlap(true)` + `barPosition(End)` + `vertical(false)` + `barHeight/barWidth` +
 *     `barFloatingStyle{ systemMaterialEffect: adaptiveMaterial(), barBottomMargin: slackH/2,
 *      gradientMask: { maskColor: '#00000000' } }`，外框 `(barWidth + slackW) × (barHeight + slackH)`。
 *   · `MainPage.morphGlass`（`wujie.pa:155701-155766`）把 `MaterialCapsule` 包在一个 `Stack` 里，
 *     `Stack` 上依次 `.position({x: glassX, y: glassY})`（:155706-155723）、
 *     `.scale({ x: glassScaleX, y: glassScaleY * morphSquashY })`（:155724-155745）、
 *     `.opacity(morphGlassOpacity)`（:155746-155756）、`.hitTestBehavior(None)`（:155757-155766）。
 *     ⇒ **缩放对象里只有 x / y 两个键**（`createobjectwithbuffer 0x1a, { 4 [ "x", "y" ] }`，:155728）
 *     ⇒ 没有 `centerX/centerY` ⇒ 默认 `50% / 50%` = **几何中心**缩放。
 *     本组件因此也**不写** `centerX/centerY`（写了就和无界不一致）。
 *
 * ══════════════════════ 二、几何账（一眼可算，没有魔法数） ══════════════════════
 *
 *   记  bW = `barWidth`、bH = `barHeight`、m = {@link resolvedBottomMarginVp}
 *       （缺省 m = `slackH / 2`，与无界 `barBottomMargin: slackH / 2` 逐字同源）
 *
 *   本组件盒   = `(bW + slackW)` × `(bH + 2m)`      ← **上下留白都等于 m**（见下面 ③）
 *   可见胶囊   = `bW × bH`，横向 HDS 居中 ⇒ 左 = `slackW/2`；纵向离盒底 `m` ⇒ 上 = `(bH+2m) − m − bH = m`
 *   内容层     = `bW × bH`，作为同尺寸子件被 `Stack(alignContent: Center)` **居中**在盒里
 *   ⇒ 内容层矩形 ≡ 胶囊矩形：左 `slackW/2`、上 `m`、尺寸 `bW × bH`（两边**同一个算式、同一组数**）
 *   ⇒ 内容中心 ≡ 胶囊中心 ⇒ `.scale({x:1, y: squashY})`（默认绕盒中心）**就是绕胶囊中心压扁**
 *   ⇒ 二级页"内容偏右下"被**结构性**消掉：不再依赖 HDS 给 `tabBar` 的槽几何（见 ③）。
 *
 * ══════════════════════ 三、为什么内容**不再**画在 `tabBar` 槽里（2026-10-20 第四轮） ══════════════════════
 *
 * 上一版把内容塞进 `.tabBar(this.BarContent())`（照搬无界），内容盒写死 `bW × bH`。真机反馈
 * 「二级页胶囊里的内容**还是偏右下**」。判据（`grep RzdMiniBarCapsule` 的 `content` / `slot` 两行）：
 *   · `slot` 行 = HDS 真给 `tabBar` 的那个槽的实测矩形；
 *   · 若 `slot` 比 `bW × bH` **小**，那么"子件比容器大"时 ArkUI 只能把子件锚在槽的**左上角**、
 *     让它向右下溢出 ⇒ 内容中心 = 胶囊中心 + (Δx, Δy)，**dx > 0 且 dy > 0** —— 正是"偏右下"。
 *     即"内容盒比胶囊大/被槽裁"这一类（上一版判据 A）在**槽高不可知**时无法靠调数收口。
 * ⇒ 这一版把**可见内容**搬出槽：`tabBar` 里只留一块**与旧内容盒逐像素同尺寸**的透明占位
 *   （HDS 画胶囊的输入不变 ⇒ 胶囊的尺寸/位置/材质与上一版**一模一样**），
 *   可见内容改画在**我们自己算出来的胶囊矩形**上（第二节那个算式）。
 *   ⇒ 内容位置不再经过 HDS 的槽：**槽给多大都不影响内容**，偏右下在结构上不可能发生。
 *   ⚠️ 占位**必须**保留同一个尺寸：HDS 的浮动胶囊是"按 tabBar 内容量"的，
 *      换成 0 尺寸/空 builder 会让胶囊塌掉（2026-10-01 那次"空 TabContent 没胶囊"同一类）。
 *   ⚠️ 退路（真机上若胶囊整块消失）：把 `this.ContentLayer()` 换回 `.tabBar(this.ContentLayer())`
 *      并删掉 `BarSlotSpacer()` —— 两处 builder 已经在结构上等价，改一行即可。
 *
 * ══════════════════════ 四、盒子为什么是 `bH + 2m`（而不是 `bH + slackH`） ══════════════════════
 *
 *   无界盒高 `bH + slackH` 之所以"正好对称"，只是因为它永远传 `m = slackH/2`。
 *   本仓二级页要传 `m = 12`（离底空隙）、键盘态还会传 `m ≈ 282`（避让键盘）——
 *   这时如果盒子仍是 `bH + slackH`，胶囊就不在盒中心，`.scale` 会**绕着胶囊下方**压，
 *   而且"居中的内容"也会与胶囊上下错开 `(2m − slackH) / 2`。
 *   写成 `bH + 2m` 之后：上留白 ≡ 下留白 ≡ m ⇒ **胶囊恒在盒中心**，与 m 取多少无关
 *   （键盘态盒子会变高，那是纯透明的 slack，换来的是胶囊位置与内容位置恒等）。
 */
@ComponentV2
export struct MiniBarMaterialCapsule {
  /**
   * 胶囊**可见**宽度（vp）。调用方必须与宿主自己算宽度用的是**同一个函数**，
   * 否则又会出现"胶囊一大一小"。
   */
  @Param barWidth: number = 0;
  /**
   * 胶囊**可见**高度（vp）。
   *
   * 两个宿主口径不同，**不要互相抄**：
   *   · 二级页（`Index.floatingMiniBar`）：`FLOATING_MINI_BAR_HEIGHT_VP`(56) —— 用户明确说这条 OK；
   *   · 首页（`Index.homeMiniCapsule`）：**内容自然高** = 封面 + 上下各 8（常态两排/封面 30 ⇒ 46vp）
   *     —— 用户要求"恢复低调/矮"，这个值就是上一版之前 HDS 按其内容量出来的那一格高度。
   */
  @Param barHeight: number = 56;
  /** 横向余量（vp）：只参与本组件盒宽，不参与胶囊宽。 */
  @Param slackW: number = CAPSULE_SLACK_W;
  /** 纵向余量（vp）：缺省 `bottomMargin` 时决定上下留白（`slackH / 2`），不参与胶囊高。 */
  @Param slackH: number = CAPSULE_SLACK_H;
  /**
   * 条底到**本组件盒底**的距离（vp）= 胶囊的上/下留白（盒子恒为 `bH + 2m`，见类注释第四节）。
   *
   * `-1`（缺省）= 无界口径 `slackH / 2` ⇒ 盒子 `bH + slackH`，与无界 `MaterialCapsule` 逐字一致。
   * 传具体值时注意：`barBottomMargin` 在 SDK 里的语义是
   * 「the distance between tab bar and bottom of tabs」（:5311）—— 是"本盒底 → 条底"，
   * 所以 `条底离页盒底 = margin − (本盒底离页盒底)`，别把两个口径混用。
   */
  @Param bottomMargin: number = -1;
  /** 官方材质参数（二级页 / 首页都传 `ambientTitleMaterial()`，保证同一套光感）。 */
  @Param material: SystemMaterialParams = DEFAULT_MATERIAL;
  /** 胶囊里画什么（内容层 ≡ 胶囊矩形，内部自行居中）。 */
  @BuilderParam content: () => void = this.emptyContent;
  /**
   * 整页形变状态（`morphSquashY` 的唯一来源）。
   *
   * 为什么由本组件自己连、而不是让宿主当 `@Param` 传：两处宿主（首页底栏 / 二级页浮动条）
   * 必须是**同一个挤压源**，多一次转手就多一次漏传的机会（本仓已有"三处跟手链必接"的旧坑）。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  // ── 诊断缓存（**普通字段**：不进状态 ⇒ 不会因写日志触发重绘/自激） ──
  /** 本组件盒左上角（窗口坐标 vp）。 */
  private probeBoxX: number = 0;
  private probeBoxY: number = 0;
  /** HDS 给 `tabBar` 的槽（窗口坐标 vp + 实测尺寸）。 */
  private probeSlotX: number = 0;
  private probeSlotY: number = 0;
  private probeSlotW: number = 0;
  private probeSlotH: number = 0;
  /** 内容层实测矩形（窗口坐标 vp + 尺寸）：与 {@link probeBoxX} 一起算 `dx/dy`。 */
  private probeContentX: number = 0;
  private probeContentY: number = 0;
  private probeContentW: number = 0;
  private probeContentH: number = 0;

  /**
   * `@BuilderParam` 的缺省实现：**空 builder**。
   *
   * 写法与本仓已验证可编译的同类组件逐字一致（`PlaylistDetailSongListSection.ets:115/128`
   * 的 `@BuilderParam heroBuilder: () => void = this.EmptyHero;` + `@Builder private EmptyHero() {}`）。
   * 壳层 `MiniBarGlassClone()`（克隆材质胶囊）就不传内容，走这一支。
   */
  @Builder
  private emptyContent() {
  }

  /** @returns 写进 `barFloatingStyle.barBottomMargin` 的那个数（vp），同时 = 胶囊上/下留白。 */
  private resolvedBottomMarginVp(): number {
    return this.bottomMargin >= 0 ? this.bottomMargin : this.slackH / 2;
  }

  /** @returns 本组件盒宽（vp）= 胶囊宽 + 横向余量（左右各 `slackW / 2`）。 */
  private boxWidthVp(): number {
    return this.barWidth + this.slackW;
  }

  /** @returns 本组件盒高（vp）= 胶囊高 + 上下各 `m`（`m` = {@link resolvedBottomMarginVp}）。 */
  private boxHeightVp(): number {
    return this.barHeight + this.resolvedBottomMarginVp() * 2;
  }

  /** @returns 可见胶囊在本盒里的左边（vp）：横向由 HDS 居中 ⇒ 左右各留 `slackW / 2`。 */
  private capsuleLeftVp(): number {
    return this.slackW / 2;
  }

  /** @returns 可见胶囊在本盒里的顶边（vp）= 盒高 − m − 胶囊高 ≡ m（第三节那个恒等式）。 */
  private capsuleTopVp(): number {
    return this.resolvedBottomMarginVp();
  }

  /**
   * HDS `tabBar` 槽里的**透明占位**：尺寸与上一版的可见内容盒**逐像素相同**。
   *
   * ⇒ 交给 HDS 测胶囊的输入（barWidth / barHeight / 内容尺寸）完全不变 ⇒ 胶囊的尺寸、位置、
   *   材质与上一版一致，唯一变化是"这一格不画像素"（可见内容搬到下面的 {@link ContentLayer}）。
   * 它同时是**槽探针**：`onAreaChange` 报出来的就是 HDS 真给的那个槽的矩形（窗口坐标）。
   */
  @Builder
  private BarSlotSpacer() {
    Column()
      .width(this.barWidth)
      .height(this.barHeight)
      .hitTestBehavior(HitTestMode.None)
      .id(SLOT_PROBE_ID)
      // 诊断（`hdc shell hilog | grep RzdMiniBarCapsule`）：HDS 槽的实测矩形。
      // 判据：`slotDx`/`slotDy`（槽中心 − 胶囊中心）应为 0；为正就是"偏右下"的 HDS 侧来源。
      .onAreaChange((_oldArea: Area, area: Area): void => {
        this.probeSlotX = areaLengthToVp(area.globalPosition.x);
        this.probeSlotY = areaLengthToVp(area.globalPosition.y);
        this.probeSlotW = areaLengthToVp(area.width);
        this.probeSlotH = areaLengthToVp(area.height);
        Logger.info(LOG_TAG,
          `slot x=${this.probeSlotX} y=${this.probeSlotY} ` +
            `w=${this.probeSlotW} h=${this.probeSlotH} ` +
            `expectW=${this.barWidth} expectH=${this.barHeight} ` +
            `capsuleTop=${this.probeBoxY + this.capsuleTopVp()} ` +
            `capsuleLeft=${this.probeBoxX + this.capsuleLeftVp()}`);
      })
  }

  /**
   * 可见内容层：**尺寸 = 胶囊**，作为同尺寸子件被盒子的 `Stack(alignContent: Center)` 居中
   * ⇒ 位置 = `(slackW/2, m)` = 胶囊矩形（第二节），与 HDS 的槽几何**无关**。
   */
  @Builder
  private ContentLayer() {
    Stack({ alignContent: Alignment.Center }) {
      this.content()
    }
    .width(this.barWidth)
    .height(this.barHeight)
    // 本层不吃事件（事件要落到内容里的按钮上）
    .hitTestBehavior(HitTestMode.Transparent)
    .id(CONTENT_PROBE_ID)
    // 诊断（`hdc shell hilog | grep RzdMiniBarCapsule`）：内容层**实测**矩形 + 与胶囊中心的差。
    // 判据（用户口径）：`dx > 0 && dy > 0` 才是"偏右下"；本版按结构应为 `dx = dy = 0`。
    .onAreaChange((_oldArea: Area, area: Area): void => {
      const w: number = areaLengthToVp(area.width);
      const h: number = areaLengthToVp(area.height);
      const x: number = areaLengthToVp(area.globalPosition.x);
      const y: number = areaLengthToVp(area.globalPosition.y);
      this.probeContentX = x;
      this.probeContentY = y;
      this.probeContentW = w;
      this.probeContentH = h;
      const m: number = this.resolvedBottomMarginVp();
      const capX: number = this.probeBoxX + this.capsuleLeftVp();
      const capY: number = this.probeBoxY + this.capsuleTopVp();
      const dx: number = (x + w / 2) - (capX + this.barWidth / 2);
      const dy: number = (y + h / 2) - (capY + this.barHeight / 2);
      const slotDx: number = (this.probeSlotX + this.probeSlotW / 2) - (capX + this.barWidth / 2);
      const slotDy: number = (this.probeSlotY + this.probeSlotH / 2) - (capY + this.barHeight / 2);
      Logger.info(LOG_TAG,
        `content x=${x} y=${y} w=${w} h=${h} ` +
          `capsule x=${capX} y=${capY} w=${this.barWidth} h=${this.barHeight} ` +
          `dx=${dx} dy=${dy} slotDx=${slotDx} slotDy=${slotDy} ` +
          `barW=${this.barWidth} barH=${this.barHeight} m=${m} ` +
          `squashY=${this.expandState.morphSquashY}`);
    })
  }

  /**
   * 胶囊本体：结构 / 属性逐条照抄无界 `MaterialCapsule`（`wujie.pa:60082-60279`）。
   *
   * 属性证据（行号 = `wujie.pa`，全部直接字节码）：
   *   `.width(barWidth + slackW)`           60093-60103
   *   `.height(barHeight + slackH)`         60108-60118   ← 本仓写成 `barHeight + 2m`（类注释第四节）
   *   `.backgroundColor(Color.Transparent)` 60123-60129
   *   `.clip(false)`                        60134-60139   ← 裁了会把材质/折射范围切掉
   *   `.barOverlap(true)`                   60144-60149   ← 官方三条件之一
   *   `.barPosition(BarPosition.End)`       60154-60160   ← 官方三条件之一
   *   `.vertical(false)`                    60165-60170   ← 官方三条件之一
   *   `.scrollable(false)`                  60175-60180
   *   `.divider(NO_DIVIDER)`                60185-60191   → `{ mode: DividerMode.NONE }`
   *   `.barHeight(barHeight)`               60196-60202   ← SDK `HdsTabsAttribute.barHeight`(:5448)
   *                                                          ⇒ 浮动胶囊的高度就是这个数（`HdsTabsFloatingStyle`
   *                                                          里**没有** barHeight 字段，见 SDK :5284-5378）
   *   `.barWidth(barWidth)`                 60207-60213
   *   `.barFloatingStyle({...})`            60218-60240
   *   `TabContent().tabBar({ builder: content })` 60254-60269
   *   `TabContent().backgroundColor(Color.Transparent)` 60272-60278
   */
  build() {
    // ★★★ 这一层 `Stack` 就是无界 `morphGlass` 里那个 `Stack`（`wujie.pa:155702-155705`）：
    //   `.scale` 挂在**它的父级**（也就是这里）上，HdsTabs 自己在子树里 ⇒
    //   HDS 画的胶囊背板 + 我们画的内容**同一个变换域** ⇒ 一起压、一起弹。
    //   `alignContent: Center` 是"内容层落到胶囊上"的前提（盒上下留白对称，见类注释第二/四节）。
    Stack({ alignContent: Alignment.Center }) {
      HdsTabs({ barPosition: BarPosition.End }) {
        TabContent() {
          // 非空占位：空 `TabContent` 在真机上 HDS 不画浮动胶囊背板/材质（2026-10-01 实测过）。
          // 可见内容由下面的 {@link ContentLayer} 承担（`tabBar` 里只留同尺寸透明占位）。
          Column()
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.None)
        }
        .tabBar(this.BarSlotSpacer())
        .backgroundColor(Color.Transparent)
      }
      .barMode(BarMode.Fixed)
      .barHeight(this.barHeight)
      .barPosition(BarPosition.End)
      .barOverlap(true)
      .vertical(false)
      .scrollable(false)
      .divider({ mode: DividerMode.NONE })
      .barWidth(this.barWidth)
      // `barOverlap` 自带一层隐式厚模糊，会盖住材质背板 ⇒ 一律关掉，材质交回 HDS 自己画。
      .barBackgroundColor(Color.Transparent)
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .barFloatingStyle({
        // 宽度口径：与胶囊、与内容层**同一个数** ⇒ 严格重合。
        barWidth: {
          smallWidth: this.barWidth,
          mediumWidth: this.barWidth,
          largeWidth: this.barWidth
        },
        // 无界：`slackH / 2`（缺省）⇒ 胶囊在盒内上下等距 ⇒ squash 绕胶囊中心。
        barBottomMargin: this.resolvedBottomMarginVp(),
        // 不跟随握持手左右偏置：两侧留白已由 barWidth 精确给出，偏置会让胶囊与内容错位。
        adaptToHandedness: false,
        // ★ 光感的来源：官方沉浸光感材质。
        systemMaterialEffect: this.material,
        // 无界 `NO_GRADIENT_MASK = { maskColor: '#00000000' }`（`wujie.pa:60329-60330`）：
        // 底部渐变遮罩全透明 ⇒ 不要把胶囊下面那圈压暗。
        gradientMask: { maskColor: '#00000000' }
      })
      .width(this.boxWidthVp())
      .height(this.boxHeightVp())
      .backgroundColor(Color.Transparent)
      .clip(false)

      // ★ 可见内容：画在**我们算出的胶囊矩形**上（同尺寸 + 盒子居中 ⇒ 中心恒等），
      //   位置与 HDS 的 `tabBar` 槽几何完全无关 ⇒ "偏右下"在结构上不可能发生。
      this.ContentLayer()
    }
    .width(this.boxWidthVp())
    .height(this.boxHeightVp())
    // ★★★ 挤压：无界 `MainPage.morphGlass` 的 `.scale({ x: glassScaleX, y: glassScaleY * morphSquashY })`
    //   （`wujie.pa:155724-155745`）。这里 glassScale = 1（本组件不做"飞"，只做"弹"），
    //   所以只剩 `y = morphSquashY`。**不写 centerX/centerY**（:155728 的对象只有 x/y 两个键）
    //   ⇒ 默认 50%/50% = 本盒几何中心 = 可见胶囊几何中心（第二节那个恒等式）。
    //   `morphSquashY`：0.86（110ms 压下）→ 1（320ms `cubic-bezier(0.34,1.56,0.64,1)` 过冲回弹），
    //   驱动在 `PlayerExpandState.squashLandAnim()`；静止态恒为 1 ⇒ 完全不影响静置版面。
    .scale({ x: 1, y: this.expandState.morphSquashY })
    // 本层不吃事件（事件交给胶囊里的按钮 / 宿主自己的手势）；子节点照常响应。
    .hitTestBehavior(HitTestMode.Transparent)
    // 诊断（`hdc shell hilog | grep RzdMiniBarCapsule`）：本组件盒（= 胶囊 + slack）+ 挤压系数。
    .onAreaChange((_oldArea: Area, area: Area): void => {
      this.probeBoxX = areaLengthToVp(area.globalPosition.x);
      this.probeBoxY = areaLengthToVp(area.globalPosition.y);
      // 盒这一行也把 `dx/dy` 打一次：`onAreaChange` 两次回调的先后不确定，
      // 只打一处会有一侧读到还没填的缓存（0）。两行都带 dx/dy ⇒ 至少一行是真值。
      const capX: number = this.probeBoxX + this.capsuleLeftVp();
      const capY: number = this.probeBoxY + this.capsuleTopVp();
      const dx: number = this.probeContentW > 0 ?
        (this.probeContentX + this.probeContentW / 2) - (capX + this.barWidth / 2) : Number.NaN;
      const dy: number = this.probeContentH > 0 ?
        (this.probeContentY + this.probeContentH / 2) - (capY + this.barHeight / 2) : Number.NaN;
      Logger.info(LOG_TAG,
        `box w=${areaLengthToVp(area.width)} h=${areaLengthToVp(area.height)} ` +
          `x=${this.probeBoxX} y=${this.probeBoxY} ` +
          `capsule x=${capX} y=${capY} dx=${dx} dy=${dy} ` +
          `barW=${this.barWidth} barH=${this.barHeight} slackW=${this.slackW} slackH=${this.slackH} ` +
          `bottomMargin=${this.resolvedBottomMarginVp()} ` +
          `expectW=${this.boxWidthVp()} expectH=${this.boxHeightVp()} ` +
          `material=${this.material.materialType}/${this.material.materialLevel} ` +
          `squashY=${this.expandState.morphSquashY}`);
    })
  }
}
