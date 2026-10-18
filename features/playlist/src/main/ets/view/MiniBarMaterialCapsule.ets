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

/** HDS 交给 `tabBar` 的**槽**探针节点 id（透明占位，尺寸 = 胶囊）。 */
const SLOT_PROBE_ID: string = 'rzd_mini_capsule_slot_probe';

/** 我们自己的**内容层**节点 id（= 胶囊矩形）。 */
const CONTENT_PROBE_ID: string = 'rzd_mini_capsule_content';

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
 *   内容层     = `bW × bH`，同尺寸子件被 `Stack(alignContent: Center)` 居中
 *   ⇒ **内容层矩形 ≡ 胶囊矩形**（两边同一个算式、同一组数）
 *   ⇒ 内容中心 ≡ 胶囊中心 ⇒ `.scale({x:1, y: squashY})`（默认绕盒中心）就是绕胶囊中心压
 *
 * ══════════════════════ 三、为什么可见内容**不**画在 `tabBar` 槽里 ══════════════════════
 *
 * `.tabBar` 给的那个**槽**的几何不可观测（真机上它比 `bW × bH` 小），子件比容器大时只能被
 * 锚在槽左上角向右下溢出 ⇒ 就是用户说的「内容偏右下」。
 * ⇒ `tabBar` 里只留一块与胶囊**同尺寸的透明占位**（HDS 画胶囊的输入不变），
 * 可见内容改画在我们自己算出的胶囊矩形上（第二节）。
 * ⚠️ 占位**必须**保留同一个尺寸：HDS 的浮动胶囊是"按 tabBar 内容量"的，换成 0 尺寸会让胶囊塌掉。
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
 * 这个**唯一不可观测的外部变量**消掉 —— 真机上若 `RzdMiniBarFit` 的 `contentR == capsuleR`
 * 且 `boxW == barW + slackW` 成立，删掉这一行也等价（届时可按需回归逐字照搬）。
 *
 * ══════════════════════ 五、右侧内容为什么不可能被切（算式） ══════════════════════
 *
 *   ① 胶囊宽 `bW ≤ availableW = winW − 2×side`（宿主用 `Math.min` 夹过，见 `Index.floatingMiniBarWidthVp()`）
 *   ② 盒右缘 = `winW − rightMargin`，`rightMargin = (winW − s)/2`（两条宿主**同一个函数**）
 *      ⇒ 胶囊右缘 = `(winW − s)/2 + (s − bW)/2 + bW = (winW + bW)/2 = winW − (winW − bW)/2 ≤ winW − side`
 *   ③ 内容层 ≡ 胶囊矩形（第二节）⇒ 内容右缘 = 胶囊右缘
 *   ④ 内容行右内距 = `actionsTrail`（= 12）≥ 盒的横向 slack/2（= 5）
 *      ⇒ **即使 HDS 把胶囊左对齐在盒里**，胶囊右缘也仍在最右按钮右侧 `12 − 5 = 7vp`
 *   ⑤ 最右按钮的图标右缘 = 胶囊右缘 − `actionsTrail(12)` − `Aside.margin.right(6)` − `(40−24)/2(8)`
 *      = `winW − side − 26` ⇒ 距屏幕右缘 `side + 26 = 38vp`
 *
 * ⇒ 判据日志 {@link logFitOnce} 的期望值：`rightGap == side`、`contentR == capsuleR`、
 *   `asideGap ≥ actionsTrail`。三项任一不成立就说明有人绕过了上面 ①~⑤ 的某一条。
 */
@ComponentV2
export struct MiniBarMaterialCapsule {
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
  /** 胶囊里画什么（内容层 ≡ 胶囊矩形，内部自行居中）。 */
  @BuilderParam content: () => void = this.emptyContent;
  /**
   * 整页形变状态（`morphSquashY` 的唯一来源）。
   * 两处宿主必须是**同一个挤压源**，所以由本组件自己连，不经宿主转手。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  // ── 诊断缓存（**普通字段**：不进状态 ⇒ 写日志不会触发重绘/自激） ──
  /** 本组件盒左上角（窗口坐标 vp）。 */
  private probeBoxX: number = 0;
  private probeBoxY: number = 0;
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
  /** `RzdMiniBarFit` 是否已经打过（一次布局会回调多次，只打第一份完整数据）。 */
  private fitLogged: boolean = false;

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
   * 量一个节点的窗口矩形（vp）；量不到返回 `undefined`（日志里打 -1）。
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
   * `RzdMiniBarFit`：**"右侧内容装不装得下"的唯一判据**（第六轮新增）。
   *
   * 口径（全部 vp、窗口坐标）：
   * ```
   *   winW        窗口宽
   *   side        宿主允许的单侧最小边距          期望：胶囊右缘 = winW − side
   *   availableW  winW − 2×side                 期望：barW ≤ availableW
   *   boxW/boxH   本盒（含 slack，见类注释第二节）
   *   capsuleX/R  可见胶囊左/右缘                期望：capsuleR − contentR = 0
   *   contentX/W/R 内容层实测                    期望：contentX == capsuleX、contentR == capsuleR
   *   rightGap    winW − capsuleR                期望：== side（> side 说明胶囊偏左；< side 就是"贴边/被切"）
   *   asideR/gap  内容行右缘 / 胶囊右缘到它的距离  期望：asideGap ≥ actionsTrail（内容行右内距）
   * ```
   * 判读口诀：**只要 `rightGap ≥ side` 且 `asideGap ≥ 12`，右侧那颗按钮在结构上不可能出屏**。
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
        `slackW=${this.slackW} slackH=${this.slackH} m=${this.resolvedBottomMarginVp()} ` +
        `rightGap=${rightGap} expectRightGap=${side} ` +
        `asideR=${asideR} asideGap=${asideGap} ` +
        `single=${this.isSingleRow()} layout=${this.barLayoutMode} style=${this.capsuleStyle}`);
    this.fitLogged = true;
  }

  /**
   * HDS `tabBar` 槽里的**透明占位**：尺寸 = 胶囊（`bW × bH`）。
   * ⇒ 交给 HDS 测胶囊的输入不变（胶囊的尺寸/位置/材质不受影响），这一格不画像素；
   * 它同时是**槽探针**（`onAreaChange` 报出来的就是 HDS 真给的那个槽的矩形）。
   */
  @Builder
  private BarSlotSpacer() {
    Column()
      .width(this.barWidth)
      .height(this.barHeight)
      .hitTestBehavior(HitTestMode.None)
      .id(SLOT_PROBE_ID)
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
   * ⇒ 位置 = 胶囊矩形，与 HDS 的槽几何**无关**。
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
    // ★ 绝不裁：裁了就等于把"内容比胶囊宽"这件事变成可见的"被切"。
    //   正确做法是让内容盒 ≡ 胶囊（本层宽高就是胶囊），不是靠 clip 掩盖。
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
          `barW=${this.barWidth} barH=${this.barHeight} m=${this.resolvedBottomMarginVp()} ` +
          `style=${this.capsuleStyle} layout=${this.barLayoutMode} ` +
          `squashY=${this.expandState.morphSquashY}`);
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
    //   **同一个变换域** ⇒ 一起压、一起弹。`alignContent: Center` 是"内容层落到胶囊上"的前提。
    Stack({ alignContent: Alignment.Center }) {
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

      // ★ 可见内容：画在**我们算出的胶囊矩形**上（同尺寸 + 盒子居中 ⇒ 中心恒等）。
      this.ContentLayer()
    }
    .width(this.boxWidthVp())
    .height(this.boxHeightVp())
    // ★★★ 挤压：无界 `MainPage.morphGlass` 的 `.scale({ x: glassScaleX, y: glassScaleY * morphSquashY })`
    //   （`wujie.pa:155724-155745`）。glassScale = 1 ⇒ 只剩 `y = morphSquashY`。
    //   **不写 centerX/centerY**（:155728 的对象只有 x/y 两个键）⇒ 默认 50%/50% = 盒中心 = 胶囊中心。
    //   `morphSquashY`：0.86（110ms）→ 1（320ms `cubic-bezier(0.34,1.56,0.64,1)`）；静止恒为 1。
    .scale({ x: 1, y: this.expandState.morphSquashY })
    // 本层不吃事件（事件交给胶囊里的按钮 / 宿主自己的手势）；子节点照常响应。
    .hitTestBehavior(HitTestMode.Transparent)
    .onAreaChange((_oldArea: Area, area: Area): void => {
      this.probeBoxX = areaLengthToVp(area.globalPosition.x);
      this.probeBoxY = areaLengthToVp(area.globalPosition.y);
      const boxW: number = areaLengthToVp(area.width);
      const boxH: number = areaLengthToVp(area.height);
      // 盒这一行也把 `dx/dy` 打一次：`onAreaChange` 两次回调的先后不确定，
      // 只打一处会有一侧读到还没填的缓存（0）。两行都带 dx/dy ⇒ 至少一行是真值。
      const capX: number = this.probeBoxX + this.capsuleLeftVp();
      const capY: number = this.probeBoxY + this.capsuleTopVp();
      const dx: number = this.probeContentW > 0 ?
        (this.probeContentX + this.probeContentW / 2) - (capX + this.barWidth / 2) : Number.NaN;
      const dy: number = this.probeContentH > 0 ?
        (this.probeContentY + this.probeContentH / 2) - (capY + this.barHeight / 2) : Number.NaN;
      Logger.info(LOG_TAG,
        `box w=${boxW} h=${boxH} ` +
          `x=${this.probeBoxX} y=${this.probeBoxY} ` +
          `capsule x=${capX} y=${capY} dx=${dx} dy=${dy} ` +
          `barW=${this.barWidth} barH=${this.barHeight} slackW=${this.slackW} slackH=${this.slackH} ` +
          `bottomMargin=${this.resolvedBottomMarginVp()} ` +
          `expectW=${this.boxWidthVp()} expectH=${this.boxHeightVp()} ` +
          `style=${this.capsuleStyle} layout=${this.barLayoutMode} ` +
          `material=${this.material.materialType}/${this.material.materialLevel} ` +
          `squashY=${this.expandState.morphSquashY}`);
      this.logFitOnce(boxW, boxH);
    })
  }
}
