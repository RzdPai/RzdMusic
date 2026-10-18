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
 *   内容盒   ≡ 胶囊盒   = `barWidth` × `barHeight`（同一个数既给 HDS 也给内容盒）
 *   本组件盒 = `(barWidth + slackW)` × `(barHeight + slackH)`
 *   胶囊在盒内的位置：横向由 HDS 居中；纵向上下各 `slackH / 2`（= `barBottomMargin`）
 *   ⇒ 本盒的几何中心 ≡ 可见胶囊的几何中心 ⇒ `.scale({x:1, y: squashY})` 就是"绕胶囊中心压扁"
 *   ⇒ 二级页"内容偏右下"的根因（内容盒 ≠ 胶囊盒，偏了就只能靠 `.offset` 凑）在这里被**结构性消掉**。
 *
 * ══════════════════════ 三、退路（只有一条，不再两套并存） ══════════════════════
 *
 * 若某条真机上本组件被宿主裁掉/材质不生效（判据：`hdc shell hilog | grep RzdMiniBarCapsule` 里
 * `box` 行有值、但胶囊区域全透明），替代**只有**一个：把该宿主退回
 * `barFloatingStyle.miniBar { enableMiniBarBackground: true }` 让 HDS 画背板（光感在、弹跳没了），
 * 并把宿主里的 `contentOwnsSquash` 置回 `true`（否则那条会既不弹也压不到背板）。
 * **不要**在同一个宿主里既开 HDS 背板又叠本组件 —— 两层材质 = 洗白（2026-10-18 已踩过）。
 */
@ComponentV2
export struct MiniBarMaterialCapsule {
  /**
   * 胶囊**可见**宽度（vp）。调用方必须与宿主自己算宽度用的是**同一个函数**，
   * 否则又会出现"胶囊一大一小"。
   */
  @Param barWidth: number = 0;
  /** 胶囊**可见**高度（vp）。二级页 / 首页统一 `FLOATING_MINI_BAR_HEIGHT_VP`（56）。 */
  @Param barHeight: number = 56;
  /** 横向余量（vp）：只参与本组件盒宽，不参与胶囊宽。 */
  @Param slackW: number = CAPSULE_SLACK_W;
  /** 纵向余量（vp）：只参与本组件盒高与离底，不参与胶囊高。 */
  @Param slackH: number = CAPSULE_SLACK_H;
  /**
   * 条底到**本组件盒底**的距离（vp）。`-1`（缺省）= 无界口径 `slackH / 2`
   * ⇒ 盒子上下留白对称 ⇒ 胶囊居中、squash 绕中心。
   *
   * 传具体值时注意：`barBottomMargin` 在 SDK 里的语义是
   * 「the distance between tab bar and bottom of tabs」（:5311）—— 是"本盒底 → 条底"，
   * 所以 `条底离页盒底 = margin − (本盒底离页盒底)`，别把两个口径混用。
   */
  @Param bottomMargin: number = -1;
  /** 官方材质参数（二级页 / 首页都传 `ambientTitleMaterial()`，保证同一套光感）。 */
  @Param material: SystemMaterialParams = DEFAULT_MATERIAL;
  /** 胶囊里画什么（内容盒 = 胶囊盒，内部自行居中）。 */
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

  /** @returns 写进 `barFloatingStyle.barBottomMargin` 的那个数（vp）。 */
  private resolvedBottomMarginVp(): number {
    return this.bottomMargin >= 0 ? this.bottomMargin : this.slackH / 2;
  }

  /**
   * 胶囊里的**内容盒**：宽高与胶囊**完全相等**（同一对参数），内容在里面居中。
   *
   * ⚠️ 这里**不要**写 `LayoutPolicy.matchParent` / `height(56)` 之类的第二次猜测：
   *    盒子由 `barWidth / barHeight` 唯一确定，任何"再对齐一次"都会把内容推偏
   *    （上一版二级页的"内容偏右下"就是拿 HDS 的**槽高**当内容盒高算出来的）。
   */
  @Builder
  private BarContent() {
    Stack({ alignContent: Alignment.Center }) {
      this.content()
    }
    .width(this.barWidth)
    .height(this.barHeight)
    // 内容盒本身不吃事件（事件要落到内容里的按钮上）
    .hitTestBehavior(HitTestMode.Transparent)
    // 诊断（`hdc shell hilog | grep RzdMiniBarCapsule`）：内容盒**实测**尺寸/位置 + 挤压系数。
    // 判据：`contentW ≈ barW` 且 `contentH ≈ barH` 且 `padL ≈ padR ≈ 0` ⇒ 内容盒 ≡ 胶囊盒。
    .onAreaChange((_oldArea: Area, area: Area): void => {
      Logger.info('RzdMiniBarCapsule',
        `content box w=${areaLengthToVp(area.width)} h=${areaLengthToVp(area.height)} ` +
          `x=${areaLengthToVp(area.globalPosition.x)} y=${areaLengthToVp(area.globalPosition.y)} ` +
          `barW=${this.barWidth} barH=${this.barHeight} squashY=${this.expandState.morphSquashY} ` +
          `bottomMargin=${this.resolvedBottomMarginVp()}`);
    })
  }

  /**
   * 胶囊本体：结构 / 属性逐条照抄无界 `MaterialCapsule`（`wujie.pa:60082-60279`）。
   *
   * 属性证据（行号 = `wujie.pa`，全部直接字节码）：
   *   `.width(barWidth + slackW)`           60093-60103
   *   `.height(barHeight + slackH)`         60108-60118
   *   `.backgroundColor(Color.Transparent)` 60123-60129
   *   `.clip(false)`                        60134-60139   ← 裁了会把材质/折射范围切掉
   *   `.barOverlap(true)`                   60144-60149   ← 官方三条件之一
   *   `.barPosition(BarPosition.End)`       60154-60160   ← 官方三条件之一
   *   `.vertical(false)`                    60165-60170   ← 官方三条件之一
   *   `.scrollable(false)`                  60175-60180
   *   `.divider(NO_DIVIDER)`                60185-60191   → `{ mode: DividerMode.NONE }`
   *   `.barHeight(barHeight)`               60196-60202
   *   `.barWidth(barWidth)`                 60207-60213
   *   `.barFloatingStyle({...})`            60218-60240
   *   `TabContent().tabBar({ builder: content })` 60254-60269
   *   `TabContent().backgroundColor(Color.Transparent)` 60272-60278
   */
  build() {
    // ★★★ 这一层 `Stack` 就是无界 `morphGlass` 里那个 `Stack`（`wujie.pa:155702-155705`）：
    //   `.scale` 挂在**它的父级**（也就是这里）上，HdsTabs 自己在子树里 ⇒
    //   HDS 画的胶囊背板 + 我们画的内容**同一个变换域** ⇒ 一起压、一起弹。
    //   `alignContent: TopStart` 让 HdsTabs 从盒左上角开始排（盒尺寸已写死，等价于铺满）。
    Stack({ alignContent: Alignment.TopStart }) {
      HdsTabs({ barPosition: BarPosition.End }) {
        TabContent() {
          // 非空占位：空 `TabContent` 在真机上 HDS 不画浮动胶囊背板/材质（2026-10-01 实测过）。
          // 本占位透明且不吃事件 —— 可见内容全部由下面 `.tabBar()` 那一份承担。
          Column()
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.None)
        }
        .tabBar(this.BarContent())
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
        // 宽度口径：与内容盒**同一个数**（`BarContent()` 里的 `this.barWidth`）⇒ 严格重合。
        barWidth: {
          smallWidth: this.barWidth,
          mediumWidth: this.barWidth,
          largeWidth: this.barWidth
        },
        // 无界：`slackH / 2`（缺省）⇒ 上下等距 ⇒ 胶囊居中 ⇒ squash 绕中心。
        barBottomMargin: this.resolvedBottomMarginVp(),
        // 不跟随握持手左右偏置：两侧留白已由 barWidth 精确给出，偏置会让胶囊与内容错位。
        adaptToHandedness: false,
        // ★ 光感的来源：官方沉浸光感材质。
        systemMaterialEffect: this.material,
        // 无界 `NO_GRADIENT_MASK = { maskColor: '#00000000' }`（`wujie.pa:60329-60330`）：
        // 底部渐变遮罩全透明 ⇒ 不要把胶囊下面那圈压暗。
        gradientMask: { maskColor: '#00000000' }
      })
      .width(this.barWidth + this.slackW)
      .height(this.barHeight + this.slackH)
      .backgroundColor(Color.Transparent)
      .clip(false)
    }
    .width(this.barWidth + this.slackW)
    .height(this.barHeight + this.slackH)
    // ★★★ 挤压：无界 `MainPage.morphGlass` 的 `.scale({ x: glassScaleX, y: glassScaleY * morphSquashY })`
    //   （`wujie.pa:155724-155745`）。这里 glassScale = 1（本组件不做"飞"，只做"弹"），
    //   所以只剩 `y = morphSquashY`。**不写 centerX/centerY**（:155728 的对象只有 x/y 两个键）
    //   ⇒ 默认 50%/50% = 本盒几何中心 = 可见胶囊几何中心（几何账见类注释第二节）。
    //   `morphSquashY`：0.86（110ms 压下）→ 1（320ms `cubic-bezier(0.34,1.56,0.64,1)` 过冲回弹），
    //   驱动在 `PlayerExpandState.squashLandAnim()`；静止态恒为 1 ⇒ 完全不影响静置版面。
    .scale({ x: 1, y: this.expandState.morphSquashY })
    // 本层不吃事件（事件交给胶囊里的按钮 / 宿主自己的手势）；子节点照常响应。
    .hitTestBehavior(HitTestMode.Transparent)
    // 诊断（`hdc shell hilog | grep RzdMiniBarCapsule`）：本组件盒（= 胶囊 + slack）+ 挤压系数。
    .onAreaChange((_oldArea: Area, area: Area): void => {
      Logger.info('RzdMiniBarCapsule',
        `box w=${areaLengthToVp(area.width)} h=${areaLengthToVp(area.height)} ` +
          `y=${areaLengthToVp(area.globalPosition.y)} ` +
          `barW=${this.barWidth} barH=${this.barHeight} slackW=${this.slackW} slackH=${this.slackH} ` +
          `bottomMargin=${this.resolvedBottomMarginVp()} material=${this.material.materialType}/` +
          `${this.material.materialLevel} squashY=${this.expandState.morphSquashY}`);
    })
  }
}
