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
import {
  DividerMode,
  HdsBarLayoutMode,
  HdsBarStyle,
  HdsTabs,
  hdsMaterial,
  SystemMaterialParams
} from '@kit.UIDesignKit';
import { AppStorageKeys, areaLengthToVp, Logger, MINI_BAR_ASIDE_ID, PlayerExpandState } from 'musicbasic';

/**
 * 胶囊的**横向**余量（vp）——照抄无界 `CAPSULE_SLACK_W`。
 *
 * 字节码：`wujie.pa:60315 ldai 0xa` + `60316 stmodulevar 0x1`（模块槽 1 = W = 10）。
 * 它只进**盒**宽（squash 的变换域），**不进** `barWidth/barHeight`（`wujie.pa:60207/60196`）
 * ⇒ 可见胶囊在盒内**居中**。
 */
export const CAPSULE_SLACK_W: number = 10;

/**
 * 胶囊的**纵向**余量（vp）——照抄无界 `CAPSULE_SLACK_H`。
 *
 * 字节码：`wujie.pa:60317 ldai 0x14`（= 20）+ `60318 stmodulevar 0x0`。
 * 无界把它折半当 `barFloatingStyle.barBottomMargin`（`wujie.pa:60229-60233`）
 * ⇒ 上下各 10vp ⇒ 胶囊在盒内**上下等距**，这是 squash 能"绕胶囊中心压"的前提。
 */
export const CAPSULE_SLACK_H: number = 20;

/**
 * 本组件**盒**的宽度（vp）——**唯一**一份算式，宿主也算这一份（第六轮新增）。
 *
 * 为什么必须导出去：上一轮宿主自己用 `(winW − barWidth)/2` 当右外边距，而盒宽是
 * `barWidth + slackW` ⇒ 首页那条整整**左偏 `slackW/2 = 5vp`**，与二级页那条对不齐
 * （用户第六轮「一级页面播放条问题越修越多」的另一半）。导出一份之后两处不可能再漂。
 *
 * 单层态（`barLayoutMode === HORIZONTAL`）横向 slack 归零：那时胶囊与页签**并排**，
 * 宿主算的必须是**胶囊矩形**（左缘给圆坞让位），盒再各留 5vp 会把缝撑成 13vp。
 * @param barWidth 胶囊可见宽度（vp）
 * @param singleRow 是否单层态（迷你条与页签并排）
 * @returns 盒宽（vp）
 */
export function capsuleBoxWidthVp(barWidth: number, singleRow: boolean): number {
  return singleRow ? barWidth : barWidth + CAPSULE_SLACK_W;
}

/**
 * 本组件**盒**的高度（vp）：`barHeight + 2 × bottomMargin`。
 * 上下留白恒等 ⇒ 盒中心 ≡ 胶囊中心 ⇒ `.scale` 绕胶囊中心压（与 `bottomMargin` 取多少无关）。
 * @param barHeight 胶囊可见高度（vp）
 * @param bottomMarginVp 条底到盒底的距离（vp），同时=胶囊上/下留白
 * @returns 盒高（vp）
 */
export function capsuleBoxHeightVp(barHeight: number, bottomMarginVp: number): number {
  return barHeight + bottomMarginVp * 2;
}

/** 诊断 tag（`hdc shell hilog | grep RzdMiniBarCapsule`）。 */
const LOG_TAG: string = 'RzdMiniBarCapsule';

/** 「胶囊装不装得下」专用 tag（`hdc shell hilog | grep RzdMiniBarFit`）。 */
const FIT_LOG_TAG: string = 'RzdMiniBarFit';

/**
 * **三个矩形同帧实测**专用 tag（`hdc shell hilog | grep RzdMiniBarRect`，第七轮新增）。
 *
 * 三行 `kind=box|slot|content`（各自 `x= y= w= h=`，窗口坐标、vp）+ 一行
 * `kind=delta`（两两之差）。判据见 {@link MiniBarMaterialCapsule.logRectDeltaOnce}。
 */
const RECT_LOG_TAG: string = 'RzdMiniBarRect';

/** HDS 交给 `tabBar` 的**槽**探针节点 id（`barW × barH` 透明占位：喂 HDS 的"内容量"）。 */
const SLOT_PROBE_ID: string = 'rzd_mini_capsule_slot_probe';

/**
 * **真槽**探针节点 id（`LayoutPolicy.matchParent` × 2 ⇒ 与槽同尺寸）。
 * 只有它量到的宽/位置才能当"槽矩形"用（另一块量到的是它自己的 `barW × barH`）。
 */
const FIT_PROBE_ID: string = 'rzd_mini_capsule_slot_fit';

/** 我们自己的**内容层**节点 id（= 胶囊矩形）。 */
const CONTENT_PROBE_ID: string = 'rzd_mini_capsule_content';

/**
 * 槽宽的**绝对可信下限**（vp）：低于它一律不采信（见 {@link MiniBarMaterialCapsule.syncContentToSlot}）。
 *
 * 首帧、动画期、页面切换时 HDS 可能给一个 0 或极小的槽（`onAreaChange` 先报 0 再报真值）；
 * 拿这种值去定内容层几何 = 内容被压成一条。本值再与 {@link MIN_SLOT_TRUST_RATIO} 的相对门槛取大者。
 */
const MIN_SANE_SLOT_VP: number = 40;

/**
 * 槽宽的**相对信任门槛**：实测槽宽必须 ≥ 胶囊宽 × 本值，否则不采信（见 {@link MiniBarMaterialCapsule.syncContentToSlot}）。
 *
 * 为什么要有这一条：内容层宽度取 `min(胶囊宽, 槽宽)`，如果在某个异常帧里 HDS 给了一个"单个页签项"
 * 那么窄的槽（例如 40vp 而胶囊 376vp），照它定宽会把内容压成一条、封面直接溢出行盒。
 * 0.5 是"它必须是那条条本身的内容区"的下限，正常态（槽 ≡ 胶囊 ≡ `barW`）离这个门槛很远。
 */
const MIN_SLOT_TRUST_RATIO: number = 0.5;

/** 实测值的"写回门槛"（vp）：变化小于它的不写回 `@Local`，避免 onAreaChange ↔ 重排 自激。 */
const MEASURE_EPS_VP: number = 0.5;

/**
 * `material` 的缺省值：无界 `adaptiveMaterial()` 的兜底档。
 *
 * 依据：`design__src__main__ets__theme__Material.ets:31-40`（反编译）——
 * `adaptiveMaterial()` 返回 `{ materialType, materialLevel }`，且 SDK
 * `@hms.hds.hdsBaseComponent.d.ets:1391/1401` 两个字段的 `@default` 分别是
 * `MaterialType.NONE` / `MaterialLevel.ADAPTIVE`。
 */
const DEFAULT_MATERIAL: SystemMaterialParams = {
  materialType: hdsMaterial.MaterialType.ADAPTIVE,
  materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
};

/**
 * 迷你播放条**材质胶囊**：无界 `design/components/MaterialCapsule.ets` 的 V2 移植版
 * （宿主是 `HdsTabs` 浮动栏，`wujie.pa:60082-60279`）。
 *
 * ══════════════════════ 一、为什么必须是"我们子树里的一个 HdsTabs" ══════════════════════
 *
 * 「沉浸光感」的唯一合法载体（API 23/24）是 `HdsTabsFloatingStyle.systemMaterialEffect`
 * （`@hms.hds.hdsBaseComponent.d.ets:5357` ← `HdsTabs.barFloatingStyle` :5582；`CommonMethod` 上没有）；
 * 「关闭播放器时整条压/弹」要求材质层落在能被 `.scale` 压到的子树里。
 * HDS 帮我们画背板时（`enableMiniBarBackground` :5169），那块背板在**壳层** `HdsTabs` 里、
 * 是 `miniBar` 槽的兄弟 ⇒ 我们压不到。唯一的交集就是把 `HdsTabs` 搬进我们自己的子树，
 * `.scale` 挂在它的**父** `Stack` 上 —— 这就是无界 `MaterialCapsule` 的结构。
 *
 * ══════════════════════ 二、几何账（一眼可算，没有魔法数） ══════════════════════
 *
 *   记  bW = `barWidth`、bH = `barHeight`、m = {@link resolvedBottomMarginVp}
 *       （缺省 m = `slackH / 2`，与无界 `barBottomMargin: slackH / 2` 同源）、
 *       s = {@link capsuleBoxWidthVp}（单层态 = bW，双层态 = bW + slackW）
 *
 *   本组件盒   = `s × (bH + 2m)`
 *   可见胶囊   = `bW × bH`，在本盒里**横向居中、纵向居中**
 *               ⇒ 胶囊左 = `(s − bW)/2`、胶囊上 = `m`
 *   ⇒ `.scale({x:1, y: squashY})`（默认绕盒中心）就是绕胶囊中心压
 *
 * ══════════════════════ 三、内容层为什么**按实测槽摆**，而不是按"我们算的胶囊矩形" ══════════════════════
 *
 * ★★★ 第七轮现场（用户截图 + 逐字反馈）：「**封面离左侧太远，右侧跑到框框外面**」。
 * 上一版的写法是：`tabBar` 里放同尺寸透明占位（探针），**可见内容**画在"我们自己算出来的
 * 胶囊矩形"上（`bW × bH`，`Stack(alignContent: Center)` 居中）。
 * 它成立的前提是「内容盒 ≡ 胶囊矩形」——**真机上这条不成立**：HDS 真正画出来的胶囊
 * 跟我们用 `barWidth` 推出来的矩形不是同一个（横向尤甚），于是内容整块相对胶囊右溢：
 * 左边留白被顶大、最右那颗"播放列表"图标压到圆角外/被屏右缘切。
 *
 * ⇒ 现在改成"**实测驱动**"，只信 HDS 自己给的槽（`TabContent().tabBar(builder)` 拿到的那个矩形）：
 *
 * ```
 *   slotW   = 槽实测宽           slotCenterX = 槽实测中心（盒内坐标）
 *   内容宽 w = min(bW, slotW)               // 槽 ⊂ 胶囊 ⇒ 取小值一定不出框
 *   内容左 x = slotCenterX − w / 2          // 槽心 ≡ 胶囊心（HDS 的条内留白左右对称）
 * ```
 *
 * 由此得到**可证明的包含关系**（这就是"内容矩形 ≡ 槽矩形"的可验证版本）：
 *
 * ```
 *   content ⊂ slot ⊂ capsule
 *   ⇒ contentR ≤ slotR ≤ capsuleR      ⇒ 右侧那颗按钮**结构上**不可能出框
 *   ⇒ content.center ≡ slot.center     ⇒ 内容不会整块右溢（左边留白不再被顶大）
 * ```
 *
 * 三种退化情形都会被这条算式自动收口：
 *
 * | HDS 实际行为 | w | x | 结果 |
 * | --- | --- | --- | --- |
 * | 槽 ≡ 胶囊 | `bW` | `胶囊左` | 与上一版**逐字相同**（本条是纯兜底） |
 * | 槽 = 胶囊内缩 p（左右对称） | `bW − 2p` | `胶囊左 + p` | 内容再内缩 p，仍居中、仍不出框 |
 * | 胶囊比 `bW` 窄（被 HDS 缩过） | `≈ 胶囊宽` | `胶囊心 − w/2` | 跟着缩，按钮不出框 |
 *
 * ★★ **"槽"到底怎么量**（本轮踩到的第一个坑）：一个 `Column` 的 `onAreaChange` 报的是**它自己**的盒，
 *   所以"塞一块 `barW × barH` 的去量槽"永远只会量到 `barW × barH` —— 槽被 HDS 缩窄了也看不出来。
 *   ⇒ `tabBar` 里放**两块**：尺寸占位（`barW × barH`，喂 HDS 的内容量，与改动前逐字相同）
 *   + 真槽探针（`LayoutPolicy.matchParent`，`100%` 解析到定尺寸祖先 = 那格槽）。
 *   判据：`RzdMiniBarRect kind=slot` 那行带 `probe=fit|spacer`，**只有 `probe=fit` 的数值能当槽**。
 *
 * ⚠️ **纵向不跟槽**（这是有意的、有证据的）：用户第七轮的反馈只点名"左侧/右侧"（横向），
 * 纵向自第六轮"盒内居中"之后就没人报了 ⇒ 说明了 `slotY/slotH == 胶囊矩形` 的纵向假设成立。
 * 因此内容层的 `y/height` 仍取 `m / bH`（胶囊矩形），只让 `x/width` 吃实测。
 * 判据在 `RzdMiniBarRect kind=delta` 那行的 `dy=` / `dh=`：它们若明显不为 0，
 * 下一轮把 {@link ContentLayer} 里的 `y/height` 也换成槽值即可（一处改动）。
 *
 * ══════════════════════ 四、`barSideMargin: 0` 为什么是必写项（第六轮新增） ══════════════════════
 *
 * SDK `:5302` 原文「The margin between the bar and the edge」⇒ HDS 排版胶囊时会在容器两侧
 * 各留这么多，容器不够宽时**先缩胶囊**。本组件容器宽 `s = bW + 10`，如果 HDS 的缺省 sideMargin
 * 大于 5，胶囊就会被缩成 `bW + 10 − 2×sideMargin < bW` ⇒ **内容比胶囊宽**（右端那颗按钮压到
 * 圆角上，看起来就是"被切"）。写 `0` 之后：`胶囊宽 = min(bW, s) = bW` 恒成立。
 *
 * ⚠️ **这是本仓相对上游的唯一一处"加法"**：上游 `MaterialCapsule` 的 `barFloatingStyle`
 * 只有 3 个键（`systemMaterialEffect` / `barBottomMargin` / `gradientMask`，
 * `wujie.pa:60220-60238`），`barSideMargin` 走缺省。本仓显式写 0，是为了把"胶囊会不会被缩窄"
 * 这个**唯一不可观测的外部变量**消掉 —— 真机上若 `RzdMiniBarRect` 的 `dw=0`（内容宽 == 槽宽）
 * 且 `RzdMiniBarFit` 的 `contentR ≈ capsuleR` 成立，删掉这一行也等价。
 *
 * ══════════════════════ 五、右侧内容为什么不可能被切（算式） ══════════════════════
 *
 *   ① 胶囊宽 `bW ≤ availableW = winW − 2×side`（宿主用 `Math.min` 夹过，见 `Index.floatingMiniBarWidthVp()`）
 *   ② 盒右缘 = `winW − rightMargin`，`rightMargin = (winW − s)/2`（两条宿主**同一个函数**）
 *      ⇒ 胶囊右缘 = `(winW − s)/2 + (s − bW)/2 + bW = (winW + bW)/2 = winW − (winW − bW)/2 ≤ winW − side`
 *   ③ 内容 ⊂ 槽 ⊂ 胶囊（第三节）⇒ 内容右缘 ≤ 胶囊右缘
 *   ④ 内容行右内距 = `actionsTrail`（= 12）≥ 盒的横向 slack/2（= 5）
 *   ⑤ 最右按钮的图标右缘 = 内容右缘 − `actionsTrail(12)` − `Aside.margin.right(6)` − `(40−24)/2(8)`
 *      ≤ `胶囊右缘 − 26` ⇒ 距屏幕右缘 ≥ `side + 26 = 38vp`
 *
 * ⇒ 判据日志 {@link logFitOnce} 的期望值：`rightGap == side`、`contentR <= capsuleR`、
 *   `asideGap >= actionsTrail`。三项任一不成立就说明有人绕过了上面 ①~⑤ 的某一条。
 */
@ComponentV2
export struct MiniBarMaterialCapsule {
  /** 上游 `BAR_ANIM = { duration: 350, curve: Curve.Friction }`（`wujie.pa:70120-70126`）。 */
  private static readonly BAR_ANIM: AnimateParam = { duration: 350, curve: Curve.Friction };
  /** 胶囊**可见**宽度（vp）。调用方必须与宿主算宽度用的是**同一个函数**。 */
  @Param barWidth: number = 0;
  /**
   * 胶囊**可见**高度（vp）。
   *
   * ★★★ 首页 / 二级页**必须传同一个常量**（`Index.FLOATING_MINI_BAR_HEIGHT_VP` = 56）。
   * 上一版让首页传"内容自然高"（46/56/60/72 随封面档位变）⇒ 用户一眼看出"两条不是同一个"。
   * "低调"属于**内容**（封面档位），不要用减小胶囊高度实现。
   */
  @Param barHeight: number = 56;
  /** 横向余量（vp）：只参与本组件盒宽，不参与胶囊宽。 */
  @Param slackW: number = CAPSULE_SLACK_W;
  /** 纵向余量（vp）：缺省 `bottomMargin` 时决定上下留白（`slackH / 2`），不参与胶囊高。 */
  @Param slackH: number = CAPSULE_SLACK_H;
  /**
   * 条底到**本组件盒底**的距离（vp）= 胶囊的上/下留白（盒子恒为 `bH + 2m`）。
   *
   * `-1`（缺省）= 无界口径 `slackH / 2` ⇒ 盒子 `bH + slackH`，与无界 `MaterialCapsule` 一致。
   * 语义与 SDK `barFloatingStyle.barBottomMargin`（:5311「the distance between tab bar and
   * bottom of tabs」）同口径：是"本盒底 → 条底"。
   */
  @Param bottomMargin: number = -1;
  /** 官方材质参数（首页 / 二级页都传 `ambientTitleMaterial()`，保证同一套光感）。 */
  @Param material: SystemMaterialParams = DEFAULT_MATERIAL;
  /** 迷你栏样式（HDS `HdsBarStyle` 的镜像）= 宿主 `miniBar.miniBarStyle` 的同一个值（只进日志）。 */
  @Param capsuleStyle: HdsBarStyle = HdsBarStyle.COLLAPSE;
  /**
   * 底栏排布模式（HDS `HdsBarLayoutMode` 的镜像）。
   *
   * `HORIZONTAL` = 迷你条与页签**并排一排**（用户说的"收起为单层"）⇒ 本盒横向 slack 归零。
   * `VERTICAL` = 上下两排（默认）。`undefined` = 发行版 < 6.1.1(24)，保持两排。
   */
  @Param barLayoutMode: HdsBarLayoutMode | undefined = undefined;
  /**
   * 窗口宽（vp）——**只进 `RzdMiniBarFit` 诊断**，不参与任何几何（几何全由宿主传进来）。
   */
  @Param fitWinWVp: number = 0;
  /**
   * 宿主允许胶囊占用的**单侧**最小边距（vp）——**只进 `RzdMiniBarFit` 诊断**。
   * 判据：`rightGap` 应恒等于它。
   */
  @Param fitSideMarginVp: number = 0;
  /** 胶囊里画什么（内容层内部自行居中）。 */
  @BuilderParam content: () => void = this.emptyContent;
  /**
   * 整页形变状态（`morphSquashY` 的唯一来源）。
   * 两处宿主必须是**同一个挤压源**，所以由本组件自己连，不经宿主转手。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  // ── 实测几何（**@Local**：内容层的 width/x 直接由它们算出来 ⇒ 必须可响应） ──
  /**
   * HDS 给的**槽**实测宽（vp）；`0` = 还没量到 ⇒ 内容层退回"胶囊矩形"兜底。
   * 写入点只有 {@link BarSlotSpacer} 与 {@link syncContentToSlot}（带 `MEASURE_EPS_VP` 门槛）。
   */
  @Local slotW: number = 0;
  /** 槽的实测中心（相对本组件盒左上角，vp）。 */
  @Local slotCenterX: number = 0;

  // ── 诊断缓存（**普通字段**：不进状态 ⇒ 写日志不会触发重绘/自激） ──
  /** 本组件盒左上角（窗口坐标 vp）+ 实测尺寸。 */
  private probeBoxX: number = 0;
  private probeBoxY: number = 0;
  private probeBoxW: number = 0;
  private probeBoxH: number = 0;
  /** HDS 给 `tabBar` 的槽（窗口坐标 vp + 实测尺寸）。 */
  private probeSlotX: number = 0;
  private probeSlotY: number = 0;
  private probeSlotW: number = 0;
  private probeSlotH: number = 0;
  /** 内容层实测矩形（窗口坐标 vp + 尺寸）。 */
  private probeContentX: number = 0;
  private probeContentY: number = 0;
  private probeContentW: number = 0;
  private probeContentH: number = 0;
  /** 三个矩形各自是否已经拿到过一份非零实测。 */
  private probeBoxValid: boolean = false;
  private probeSlotValid: boolean = false;
  private probeContentValid: boolean = false;
  /** `RzdMiniBarFit` / `RzdMiniBarRect kind=delta` 是否已经打过（一次布局会回调多次，只打第一份完整数据）。 */
  private fitLogged: boolean = false;
  private deltaLogged: boolean = false;
  private settleLogged: boolean = false;
  private slotRejectLogged: boolean = false;

  /**
   * `@BuilderParam` 的缺省实现：**空 builder**。
   * 写法与本仓已验证可编译的同类组件一致（`PlaylistDetailSongListSection.ets:115/128`）。
   * 壳层 `MiniBarGlassClone()` 就不传内容，走这一支。
   */
  @Builder
  private emptyContent() {
  }

  /** @returns 写进 `barFloatingStyle.barBottomMargin` 的那个数（vp），同时 = 胶囊上/下留白。 */
  private resolvedBottomMarginVp(): number {
    return this.bottomMargin >= 0 ? this.bottomMargin : this.slackH / 2;
  }

  /** @returns 是否单层态（迷你条与页签并排）。 */
  private isSingleRow(): boolean {
    return this.barLayoutMode === HdsBarLayoutMode.HORIZONTAL;
  }

  /** @returns 本组件盒宽（vp）——与宿主共用 {@link capsuleBoxWidthVp} 这一份算式。 */
  private boxWidthVp(): number {
    return capsuleBoxWidthVp(this.barWidth, this.isSingleRow());
  }

  /** @returns 本组件盒高（vp）= 胶囊高 + 上下各 `m`。 */
  private boxHeightVp(): number {
    return capsuleBoxHeightVp(this.barHeight, this.resolvedBottomMarginVp());
  }

  /** @returns 可见胶囊在本盒里的左边（vp）：横向居中 ⇒ `(s − bW)/2`。 */
  private capsuleLeftVp(): number {
    return (this.boxWidthVp() - this.barWidth) / 2;
  }

  /** @returns 可见胶囊在本盒里的顶边（vp）= `m`（盒上下留白对称）。 */
  private capsuleTopVp(): number {
    return this.resolvedBottomMarginVp();
  }

  /**
   * @returns 内容层的**宽度**（vp）= `min(胶囊宽, 槽实测宽)`。
   *
   * 取小值是有理由的一步，不是保守：槽一定在胶囊**内**（HDS 用它排 tabBar 内容），
   * 所以 `w ≤ slotW` ⇒ 内容不可能横向出框；槽 ≡ 胶囊时 `w = bW`，与上一版逐字相同。
   */
  private contentLayerWidthVp(): number {
    // 内容盒 ≡ 胶囊盒（同一个 `barWidth`）：不跟槽心、不跟槽宽 —— 上游的内容与胶囊**同源**（HDS 槽 / 同一节点），
    // 我们没有那条同源关系，跟槽真机验证过一次"整块右移"，已回退（见记忆 §194.5）。
    return this.barWidth;
  }

  private contentLayerLeftVp(): number {
    // 与 `contentLayerWidthVp` 同一条依据：内容盒 ≡ 胶囊盒。
    return this.capsuleLeftVp();
  }

  /** @returns 内容层的**顶边**（相对本组件盒左上角，vp）= 胶囊上缘（纵向不跟槽，见类注释第三节）。 */
  private contentLayerTopVp(): number {
    return this.capsuleTopVp();
  }

  /** @returns 内容层的**高度**（vp）= 胶囊高（纵向不跟槽，见类注释第三节）。 */
  private contentLayerHeightVp(): number {
    return this.barHeight;
  }

  /**
   * 把**实测槽**写进内容层的几何状态。
   *
   * 触发点两处（槽自己的 `onAreaChange` + 盒的 `onAreaChange`）：前者给尺寸、后者给参考原点，
   * 两者任意一个晚到都要重算"盒内坐标"。写入带 `MEASURE_EPS_VP` 门槛 ⇒ 收敛后不再写
   * ⇒ 不会 onAreaChange ↔ 重排 自激（槽的几何也不依赖内容层，结构上不成环）。
   */
  private syncContentToSlot(): void {
    if (!this.probeSlotValid || !this.probeBoxValid) {
      return;
    }
    // 采信门槛：槽宽至少要"像一条内容区"（≥ 胶囊宽的一半，且不低于 {{@link MIN_SANE_SLOT_VP}}）。
    // 首帧 / 动画收缩期的 0 或极小槽一律拒绝 —— 拿它定几何会把内容压成一条。
    const minTrustW: number = Math.max(MIN_SANE_SLOT_VP, this.barWidth * MIN_SLOT_TRUST_RATIO);
    if (this.probeSlotW < minTrustW) {
      if (!this.slotRejectLogged) {
        this.slotRejectLogged = true;
        Logger.info(LOG_TAG,
          `slot-rejected slotW=${this.probeSlotW} slotH=${this.probeSlotH} minTrustW=${minTrustW} ` +
            `barW=${this.barWidth} fallbackContentW=${this.contentLayerWidthVp()} ` +
            `fallbackContentX=${this.contentLayerLeftVp()}`);
      }
      return;
    }
    const wantSlotW: number = this.probeSlotW;
    const wantCenterX: number = (this.probeSlotX + this.probeSlotW / 2) - this.probeBoxX;
    const sizeChanged: boolean = Math.abs(wantSlotW - this.slotW) > MEASURE_EPS_VP;
    const centerChanged: boolean = Math.abs(wantCenterX - this.slotCenterX) > MEASURE_EPS_VP;
    if (!sizeChanged && !centerChanged) {
      return;
    }
    this.slotW = wantSlotW;
    this.slotCenterX = wantCenterX;
    const capsuleLeft: number = this.capsuleLeftVp();
    const capsuleR: number = this.probeBoxX + capsuleLeft + this.barWidth;
    const slotR: number = this.probeSlotX + this.probeSlotW;
    Logger.info(LOG_TAG,
      `follow-slot slotW=${wantSlotW} slotCenterX=${wantCenterX} ` +
        `contentW=${this.contentLayerWidthVp()} contentX=${this.contentLayerLeftVp()} ` +
        `capsuleLeft=${capsuleLeft} barW=${this.barWidth} ` +
        `slotInsetL=${(this.probeSlotX - this.probeBoxX) - capsuleLeft} ` +
        `slotInsetR=${capsuleR - slotR}`);
  }

  /**
   * 量一个节点的窗口矩形右缘（vp）；量不到返回 `undefined`（日志里打 -1）。
   * 口径与 `Index.measureNodeBottomToWindowVp` 一致：`getComponentUtils().getRectangleById` 返回 px。
   * @param id 节点 `.id()` 值
   */
  private measureRightVp(id: string): number {
    try {
      const rect = this.getUIContext().getComponentUtils().getRectangleById(id);
      const rightPx: number = rect.windowOffset.x + rect.size.width;
      return this.getUIContext().px2vp(rightPx);
    } catch (error) {
      return -1;
    }
  }

  /**
   * `RzdMiniBarRect`：**三个矩形同帧量出来的那一份证据**（第七轮新增，本轮所有改动的依据）。
   *
   * 口径：全部窗口坐标、单位 vp，每行 `kind=… x= y= w= h= …`。
   * ```
   *   kind=box      ① HdsTabs 组件盒（= 胶囊 + slackW + 上下各 m）
   *   kind=slot     ② HDS 交给 tabBar 的槽（探针 = 同尺寸透明占位）
   *   kind=content  ③ 我们画的内容层
   *   kind=delta    // ②−① / ③−② / "胶囊矩形−②"（= 上一版内容相对槽的溢出量）
   * ```
   * 判据（一行就能定案"内容整体右溢"）：
   * ```
   *   delta.dxCapsuleVsSlot > 0  ⇒ 上一版内容比槽**偏右** delta 那么多（= 用户说的"封面离左太远 + 右侧出框"）
   *   delta.dwCapsuleVsSlot > 0  ⇒ 上一版内容比槽**宽** delta（多出来的部分顶到胶囊圆角外）
   *   delta.dxContentVsSlot ≈ 0 且 dwContentVsSlot ≈ 0  ⇒ 本轮修的"内容 ⊂ 槽"成立
   *   delta.dy / dh              ⇒ 纵向槽与胶囊矩形的偏差（≈0 才说明"纵向不跟槽"这条选择正确）
   * ```
   * @param kind `box` / `slot` / `content`
   * @param x 窗口坐标 x（vp）
   * @param y 窗口坐标 y（vp）
   * @param w 实测宽（vp）
   * @param h 实测高（vp）
   * @param extra 该行专属的附加字段（已格式化好）
   */
  private logRect(kind: string, x: number, y: number, w: number, h: number, extra: string): void {
    Logger.info(RECT_LOG_TAG, `kind=${kind} x=${x} y=${y} w=${w} h=${h} ${extra}`);
  }

  /**
   * 三行实测齐了以后打**两行**：
   * ① 第一份 `kind=delta`（= 上一版几何留下的差，**证据行**，只在首次打）；
   * ② 第一份 `kind=delta-settled`（= 本轮"内容 ⊂ 槽、中心 ≡ 槽心"的**验收行**）。
   * 为什么要两行：首帧的 `content` 还是兜底几何 ⇒ ① 记的就是用户看到的那个溢出量；
   * 采信实测之后 `content` 换成跟随几何 ⇒ ② 才是本轮改动生效的证明。
   */
  private logRectDeltaOnce(): void {
    if (!this.probeBoxValid || !this.probeSlotValid || !this.probeContentValid) {
      return;
    }
    const capX: number = this.probeBoxX + this.capsuleLeftVp();
    const capY: number = this.probeBoxY + this.capsuleTopVp();
    const dxCapsuleVsSlot: number = capX - this.probeSlotX;
    const dyCapsuleVsSlot: number = capY - this.probeSlotY;
    const dwCapsuleVsSlot: number = this.barWidth - this.probeSlotW;
    const dhCapsuleVsSlot: number = this.barHeight - this.probeSlotH;
    const dxContentVsSlot: number = this.probeContentX - this.probeSlotX;
    const dwContentVsSlot: number = this.probeContentW - this.probeSlotW;
    const dyContentVsSlot: number = this.probeContentY - this.probeSlotY;
    const dhContentVsSlot: number = this.probeContentH - this.probeSlotH;
    if (!this.deltaLogged) {
      // 头部四个数取"内容 − 槽"：跟随生效时就是 0 0 0 0（首帧那份非 0 就是溢出量）。
      this.logRect('delta',
        dxContentVsSlot, dyContentVsSlot, dwContentVsSlot, dhContentVsSlot,
        `dxCapsuleVsSlot=${dxCapsuleVsSlot} dwCapsuleVsSlot=${dwCapsuleVsSlot} ` +
          `dyCapsuleVsSlot=${dyCapsuleVsSlot} dhCapsuleVsSlot=${dhCapsuleVsSlot} ` +
          `dxContentVsSlot=${dxContentVsSlot} dwContentVsSlot=${dwContentVsSlot} ` +
          `dyContentVsSlot=${dyContentVsSlot} dhContentVsSlot=${dhContentVsSlot} ` +
          `slotW=${this.probeSlotW} slotH=${this.probeSlotH} ` +
          `contentW=${this.probeContentW} contentH=${this.probeContentH} ` +
          `barW=${this.barWidth} barH=${this.barHeight} ` +
          `single=${this.isSingleRow()}`);
      this.deltaLogged = true;
    }
    if (this.settleLogged) {
      return;
    }
    // 验收：内容**包含在槽内**且**中心 ≡ 槽心**（w = min(bW, slotW) 时不会与槽等宽，故不用"相等"判）。
    const contentR: number = this.probeContentX + this.probeContentW;
    const slotR: number = this.probeSlotX + this.probeSlotW;
    const inSlotL: boolean = this.probeContentX >= this.probeSlotX - MEASURE_EPS_VP;
    const inSlotR: boolean = contentR <= slotR + MEASURE_EPS_VP;
    const centerDx: number = (this.probeContentX + this.probeContentW / 2) - (this.probeSlotX + this.probeSlotW / 2);
    const centerMatch: boolean = Math.abs(centerDx) <= MEASURE_EPS_VP;
    if (!inSlotL || !inSlotR || !centerMatch) {
      return;
    }
    this.logRect('delta-settled', centerDx, dyContentVsSlot, dwContentVsSlot, dhContentVsSlot,
      `inSlotL=${inSlotL} inSlotR=${inSlotR} centerMatch=${centerMatch} centerDx=${centerDx} ` +
        `contentX=${this.probeContentX} contentW=${this.probeContentW} contentR=${contentR} ` +
        `slotX=${this.probeSlotX} slotW=${this.probeSlotW} slotR=${slotR} ` +
        `capsuleX=${capX} capsuleR=${capX + this.barWidth} barW=${this.barWidth} barH=${this.barHeight} ` +
        `boundByMin=${this.probeSlotW < this.barWidth} ` +
        `dyVsSlot=${dyContentVsSlot} dhVsSlot=${dhContentVsSlot} single=${this.isSingleRow()}`);
    this.settleLogged = true;
  }

  /**
   * `RzdMiniBarFit`：**"右侧内容装不装得下"的唯一判据**（第六轮新增）。
   *
   * 口径（全部 vp、窗口坐标）：
   * ```
   *   winW        窗口宽
   *   side        宿主允许的单侧最小边距          期望：胶囊右缘 = winW − side
   *   availableW  winW − 2×side                 期望：barW ≤ availableW
   *   boxW/boxH   本盒（含 slack，见类注释第二节）
   *   capsuleX/R  可见胶囊左/右缘                期望：contentR ≤ capsuleR
   *   contentX/W/R 内容层实测                    期望：content 中心 ≡ slot 中心
   *   rightGap    winW − capsuleR                期望：== side（> side 说明胶囊偏左；< side 就是"贴边/被切"）
   *   asideR/gap  内容行右缘 / 胶囊右缘到它的距离  期望：asideGap ≥ actionsTrail（内容行右内距）
   * ```
   * 判读口诀：**只要 `rightGap ≥ side` 且 `asideGap ≥ 12` 且 `contentR ≤ capsuleR`，
   * 右侧那颗按钮在结构上不可能出屏**。
   * @param boxW 盒宽实测
   * @param boxH 盒高实测
   */
  private logFitOnce(boxW: number, boxH: number): void {
    if (this.fitLogged) {
      return;
    }
    const winW: number = this.fitWinWVp;
    const side: number = this.fitSideMarginVp;
    const capsuleX: number = this.probeBoxX + this.capsuleLeftVp();
    const capsuleR: number = capsuleX + this.barWidth;
    const contentR: number = this.probeContentX + this.probeContentW;
    const rightGap: number = winW > 0 ? winW - capsuleR : -1;
    const availableW: number = winW > 0 ? winW - side * 2 : -1;
    const asideR: number = this.measureRightVp(MINI_BAR_ASIDE_ID);
    const asideGap: number = asideR > 0 ? capsuleR - asideR : -1;
    Logger.info(FIT_LOG_TAG,
      `winW=${winW} side=${side} availableW=${availableW} ` +
        `barW=${this.barWidth} barH=${this.barHeight} ` +
        `boxW=${boxW} boxH=${boxH} boxX=${this.probeBoxX} boxY=${this.probeBoxY} ` +
        `capsuleX=${capsuleX} capsuleR=${capsuleR} ` +
        `contentX=${this.probeContentX} contentW=${this.probeContentW} contentR=${contentR} ` +
        `contentH=${this.probeContentH} ` +
        `slotW=${this.probeSlotW} slotX=${this.probeSlotX} contentInCapsule=${contentR <= capsuleR} ` +
        `slackW=${this.slackW} slackH=${this.slackH} m=${this.resolvedBottomMarginVp()} ` +
        `rightGap=${rightGap} expectRightGap=${side} ` +
        `asideR=${asideR} asideGap=${asideGap} ` +
        `single=${this.isSingleRow()} layout=${this.barLayoutMode} style=${this.capsuleStyle}`);
    this.fitLogged = true;
  }

  /**
   * HDS `tabBar` 槽里的**两块探针**（都不画像素）。
   *
   * ★★★ 为什么必须是**两块**（第七轮新增，这是"量槽"能成立的前提）：
   * 一块 `Column` 的 `onAreaChange` 报的是**它自己的盒**，不是父槽的盒 ——
   * 所以"塞一块 `barW × barH` 的占位去量槽"量到的永远是自己（`w == barW`），
   * 槽真被 HDS 缩窄了也看不出来（上一版就是这么把 `slotW` 当成恒等于 `barWidth` 的）。
   * ⇒
   *   ① {@link BarSlotSpacer}（`barW × barH`，尺寸**保持与改动前逐字相同**）
   *      —— 它的作用只有一个：喂给 HDS 的"tabBar 内容量"一个字都不变（胶囊几何不受扰动）；
   *   ② 真槽探针（同一 builder 里的第二个兄弟节点，`LayoutPolicy.matchParent` × 2）
   *      —— `100%` 解析到最近的定尺寸祖先 = HDS 给的那格槽 ⇒ 量到的**才是槽本身**。
   * 两块是同一个槽里的兄弟节点，槽的内容量 = max(两者的固有尺寸) = `barW × barH`（百分比节点
   * 不贡献固有尺寸）⇒ ②对 HDS 的排布是惰性的。
   */
  @Builder
  private BarSlotSpacer() {
    // ② 真槽探针：`matchParent` ⇒ 与槽同尺寸（"内容 ≡ 槽"的唯一可靠量法）。
    Column()
      .width(LayoutPolicy.matchParent)
      .height(LayoutPolicy.matchParent)
      .hitTestBehavior(HitTestMode.None)
      .id(FIT_PROBE_ID)
      .onAreaChange((_oldArea: Area, area: Area): void => {
        const w: number = areaLengthToVp(area.width);
        const h: number = areaLengthToVp(area.height);
        if (w <= 0 || h <= 0) {
          return;
        }
        this.probeSlotX = areaLengthToVp(area.globalPosition.x);
        this.probeSlotY = areaLengthToVp(area.globalPosition.y);
        this.probeSlotW = w;
        this.probeSlotH = h;
        this.probeSlotValid = true;
        this.logRect('slot', this.probeSlotX, this.probeSlotY, this.probeSlotW, this.probeSlotH,
          `probe=fit expectW=${this.barWidth} expectH=${this.barHeight} ` +
            `capsuleLeft=${this.probeBoxX + this.capsuleLeftVp()} ` +
            `capsuleTop=${this.probeBoxY + this.capsuleTopVp()} ` +
            `boxX=${this.probeBoxX} boxY=${this.probeBoxY} ` +
            `barW=${this.barWidth} barH=${this.barHeight} layout=${this.barLayoutMode}`);
        this.syncContentToSlot();
        this.logRectDeltaOnce();
      })
    // ① 尺寸占位（喂 HDS 的输入，**不许改尺寸**）+ 兜底探针（真槽探针没量到时用它的原点）。
    Column()
      .width(this.barWidth)
      .height(this.barHeight)
      .hitTestBehavior(HitTestMode.None)
      .id(SLOT_PROBE_ID)
      .onAreaChange((_oldArea: Area, area: Area): void => {
        if (this.probeSlotValid) {
          // 真槽已经量到了 ⇒ 这一块的尺寸只是"我们自己的显式值"，不再当作槽宽。
          return;
        }
        this.probeSlotX = areaLengthToVp(area.globalPosition.x);
        this.probeSlotY = areaLengthToVp(area.globalPosition.y);
        this.probeSlotW = areaLengthToVp(area.width);
        this.probeSlotH = areaLengthToVp(area.height);
        this.probeSlotValid = this.probeSlotW > 0 && this.probeSlotH > 0;
        this.logRect('slot', this.probeSlotX, this.probeSlotY, this.probeSlotW, this.probeSlotH,
          `probe=spacer fallback=1 expectW=${this.barWidth} expectH=${this.barHeight} ` +
            `capsuleLeft=${this.probeBoxX + this.capsuleLeftVp()} ` +
            `capsuleTop=${this.probeBoxY + this.capsuleTopVp()} ` +
            `boxX=${this.probeBoxX} boxY=${this.probeBoxY} ` +
            `barW=${this.barWidth} barH=${this.barHeight} layout=${this.barLayoutMode}`);
        this.syncContentToSlot();
        this.logRectDeltaOnce();
      })
  }

  /**
   * 可见内容层：**几何由实测槽决定**（类注释第三节），首帧之前退回胶囊矩形。
   *
   * ⚠️ 这里用 `.position()` 是**结构**的一部分（把内容钉到 HDS 自己的槽矩形上），
   * 不是为了掩盖溢出 —— 上一版正是"按我们算的胶囊矩形摆 + 差多少 offset 补多少"那条路走不通。
   */
  @Builder
  private ContentLayer() {
    Stack({ alignContent: Alignment.Center }) {
      this.content()
    }
    .width(this.contentLayerWidthVp())
    .height(this.contentLayerHeightVp())
    // 盒内定位：x 吃实测槽心（见 contentLayerLeftVp），y 取胶囊上缘（纵向不跟槽）。
    .position({ x: this.contentLayerLeftVp(), y: this.contentLayerTopVp() })
    // 本层不吃事件（事件要落到内容里的按钮上）
    .hitTestBehavior(HitTestMode.Transparent)
    // ★ 绝不裁：裁了就等于把"内容比胶囊宽"这件事变成可见的"被切"。
    //   正确做法是让内容 ⊂ 槽 ⊂ 胶囊（类注释第三节），不是靠 clip 掩盖。
    .clip(false)
    .id(CONTENT_PROBE_ID)
    .onAreaChange((_oldArea: Area, area: Area): void => {
      const w: number = areaLengthToVp(area.width);
      const h: number = areaLengthToVp(area.height);
      const x: number = areaLengthToVp(area.globalPosition.x);
      const y: number = areaLengthToVp(area.globalPosition.y);
      this.probeContentX = x;
      this.probeContentY = y;
      this.probeContentW = w;
      this.probeContentH = h;
      this.probeContentValid = w > 0 && h > 0;
      const capX: number = this.probeBoxX + this.capsuleLeftVp();
      const capY: number = this.probeBoxY + this.capsuleTopVp();
      const dx: number = (x + w / 2) - (capX + this.barWidth / 2);
      const dy: number = (y + h / 2) - (capY + this.barHeight / 2);
      const slotDx: number = (this.probeSlotX + this.probeSlotW / 2) - (capX + this.barWidth / 2);
      const slotDy: number = (this.probeSlotY + this.probeSlotH / 2) - (capY + this.barHeight / 2);
      this.logRect('content', x, y, w, h,
        `capsuleX=${capX} capsuleY=${capY} capsuleW=${this.barWidth} capsuleH=${this.barHeight} ` +
          `dxVsCapsule=${dx} dyVsCapsule=${dy} ` +
          `slotCenterDxVsCapsule=${slotDx} slotCenterDyVsCapsule=${slotDy} ` +
          `slotW=${this.probeSlotW} slotX=${this.probeSlotX} ` +
          `wantW=${this.contentLayerWidthVp()} wantX=${this.contentLayerLeftVp()} ` +
          `m=${this.resolvedBottomMarginVp()} style=${this.capsuleStyle} ` +
          `layout=${this.barLayoutMode} squashY=${this.expandState.morphSquashY}`);
      this.syncContentToSlot();
      this.logRectDeltaOnce();
      this.logFitOnce(this.boxWidthVp(), this.boxHeightVp());
    })
  }

  /**
   * 胶囊本体：结构 / 属性逐条照抄无界 `MaterialCapsule`（`wujie.pa:60082-60279`）。
   *
   * 属性证据（行号 = `wujie.pa`，全部直接字节码）：
   *   `.width(barWidth + slackW)`           60093-60103
   *   `.height(barHeight + slackH)`         60108-60118  ← 本仓写 `barHeight + 2m`（类注释第二节）
   *   `.backgroundColor(Color.Transparent)` 60123-60129
   *   `.clip(false)`                        60134-60139  ← 裁了会把材质/折射范围切掉
   *   `.barOverlap(true)`                   60144-60149  ← 官方三条件之一
   *   `.barPosition(BarPosition.End)`       60154-60160  ← 官方三条件之一
   *   `.vertical(false)`                    60165-60170  ← 官方三条件之一
   *   `.scrollable(false)`                  60175-60180
   *   `.divider(NO_DIVIDER)`                60185-60191  → `{ mode: DividerMode.NONE }`
   *   `.barHeight(barHeight)`               60196-60202  ← SDK `HdsTabsAttribute.barHeight`(:5448)
   *                                                       （`HdsTabsFloatingStyle` 里没有 barHeight）
   *   `.barWidth(barWidth)`                 60207-60213
   *   `.barFloatingStyle({...})`            60218-60240
   *   `TabContent().tabBar({ builder })`    60254-60269
   *   `TabContent().backgroundColor(Transparent)` 60272-60278
   */
  build() {
    // ★★★ 这一层 `Stack` 就是无界 `morphGlass` 里那个 `Stack`（`wujie.pa:155702-155705`）：
    //   `.scale` 挂在这里，HdsTabs 在子树里 ⇒ HDS 画的胶囊背板 + 我们画的内容
    //   **同一个变换域** ⇒ 一起压、一起弹。
    //   `alignContent: TopStart`：内容层改成 `.position()` 之后就按盒左上角定位（见 ContentLayer），
    //   不再靠 Stack 的居中"顺带"对齐（那也是上一版错位的隐因之一）。
    Stack({ alignContent: Alignment.TopStart }) {
      HdsTabs({ barPosition: BarPosition.End }) {
        TabContent() {
          // 非空占位：空 `TabContent` 在真机上 HDS 不画浮动胶囊背板/材质（2026-10-01 实测）。
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
        // ★★ 第六轮新增（类注释第四节）：两侧边距清零 ⇒ HDS 不会把胶囊缩得比 `barWidth` 窄。
        //   这一条是"内容比胶囊宽 ⇒ 右侧按钮看起来被切"的结构性堵口。
        barSideMargin: 0,
        // 无界：`slackH / 2`（缺省）⇒ 胶囊在盒内上下等距 ⇒ squash 绕胶囊中心。
        barBottomMargin: this.resolvedBottomMarginVp(),
        // 不跟随握持手左右偏置：两侧留白已由 barWidth 精确给出。
        adaptToHandedness: false,
        // ★ 光感的来源：官方沉浸光感材质。
        systemMaterialEffect: this.material,
        // 无界 `NO_GRADIENT_MASK = { maskColor: '#00000000' }`（`wujie.pa:60329-60330`）。
        gradientMask: { maskColor: '#00000000' }
      })
      .width(this.boxWidthVp())
      .height(this.boxHeightVp())
      .backgroundColor(Color.Transparent)
      .clip(false)

      // ★ 可见内容：几何 = 实测槽（q.v. 类注释第三节），首帧之前 = 胶囊矩形。
      this.ContentLayer()
    }
    // ★★★ 2026-10-18（用户：「切换单双行动画不是很流畅」）：盒高/盒宽随形态在 56 ↔ 40 之间变，
    //   原来**没有任何补间**（状态一变就瞬跳）。上游把 `BAR_ANIM = { duration: 350, curve: Curve.Friction }`
    //   （`wujie.pa:70120-70126`）挂在**带 height/padding 的那个节点**上（胶囊 `Row` `:69053-69057`，
    //   收口 `:69118-69121`）⇒ 这里给胶囊根同样挂一条，顺序照抄 `animation(…) → 属性 → animation(null)`。
    .animation(MiniBarMaterialCapsule.BAR_ANIM)
    .width(this.boxWidthVp())
    .height(this.boxHeightVp())
    // ★★★ 挤压：无界 `MainPage.morphGlass` 的 `.scale({ x: glassScaleX, y: glassScaleY * morphSquashY })`
    //   （`wujie.pa:155724-155745`）。glassScale = 1 ⇒ 只剩 `y = morphSquashY`。
    //   **不写 centerX/centerY**（:155728 的对象只有 x/y 两个键）⇒ 默认 50%/50% = 盒中心 = 胶囊中心。
    //   `morphSquashY`：0.86（110ms）→ 1（320ms `cubic-bezier(0.34,1.56,0.64,1)`）；静止恒为 1。
    .scale({ x: 1, y: this.expandState.morphSquashY })
    .animation(null)
    // 本层不吃事件（事件交给胶囊里的按钮 / 宿主自己的手势）；子节点照常响应。
    .hitTestBehavior(HitTestMode.Transparent)
    .onAreaChange((_oldArea: Area, area: Area): void => {
      this.probeBoxX = areaLengthToVp(area.globalPosition.x);
      this.probeBoxY = areaLengthToVp(area.globalPosition.y);
      this.probeBoxW = areaLengthToVp(area.width);
      this.probeBoxH = areaLengthToVp(area.height);
      this.probeBoxValid = this.probeBoxW > 0 && this.probeBoxH > 0;
      const capX: number = this.probeBoxX + this.capsuleLeftVp();
      const capY: number = this.probeBoxY + this.capsuleTopVp();
      this.logRect('box', this.probeBoxX, this.probeBoxY, this.probeBoxW, this.probeBoxH,
        `capsuleX=${capX} capsuleY=${capY} capsuleW=${this.barWidth} capsuleH=${this.barHeight} ` +
          `expectW=${this.boxWidthVp()} expectH=${this.boxHeightVp()} ` +
          `slackW=${this.slackW} slackH=${this.slackH} m=${this.resolvedBottomMarginVp()} ` +
          `style=${this.capsuleStyle} layout=${this.barLayoutMode} ` +
          `material=${this.material.materialType}/${this.material.materialLevel} ` +
          `squashY=${this.expandState.morphSquashY}`);
      // 盒的位置一变（换机型 / 键盘 / 窗口缩放），"盒内坐标"就要重算。
      this.syncContentToSlot();
      this.logRectDeltaOnce();
      this.logFitOnce(this.probeBoxW, this.probeBoxH);
    })
  }
}
