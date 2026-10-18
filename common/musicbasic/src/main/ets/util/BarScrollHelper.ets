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

import { SdkConstants } from '../constants/Constants';
import { MusicAppState } from '../model/MusicAppState';
import { BarAction, BarAxis, BarCollapse } from '../logic/BarCollapse';
import { SdkApiUtil } from './SdkApiUtil';
import { Logger } from './Logger';

/**
 * 底栏「迷你条展开 / 收起」的**意图判定**：`BarCollapse` 的滚动适配层。
 *
 * ══════════════════ 一、判定逻辑不在本文件（2026-10-18 照搬无界） ══════════════════
 *
 * 判据、阈值（1.5vp）、轴锁、节流（250ms）全部在 {@link BarCollapse} 里 —— 那是上游
 * `design/logic/BarCollapse` 的逐字移植（`wujie.pa:83829-84220`）。本文件只负责两件事：
 * 把各页面喂进来的**滚动增量**折算成 `BarCollapse` 需要的一串 `y`，然后把 `BarAction`
 * 翻译成"展开意图"交给壳层。
 *
 * ══════════════════ 二、落地同样不在本文件 ══════════════════
 *
 * 上游把"判意图"和"落地"拆成两段（`wujie.pa:145755-145790`）：
 * ```
 *   ① BarCollapse.onDown/onMove/onUp → BarAction
 *   ② applyBarAction(action) → controller.applyMiniBarStyle(
 *          action === COLLAPSE ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE)   // 映射是反向的
 * ```
 * 且 **`barLayoutMode` 运行期从不改**（整份 abc 只有 4 处写、值恒 `VERTICAL`：
 * `wujie.pa:143295` / `:144066` / `:144083` / `:520524`），`MainPage` 整模块 `animateTo` 零命中
 * —— 切换动画由 HDS 内部默认动效给（SDK `@hms.hds.hdsBaseComponent.d.ets:5729`）。
 *
 * ⇒ 本文件只到第 ① 段的出口：把意图交给壳层注册的 {@link expandApplier}
 *   （common 层拿不到 `HdsTabsController`，与上游 `MainPage` 的分层一致）。
 */
export class BarScrollHelper {
  /** 滚动联动总开关。 */
  private static readonly SCROLL_LINK_ENABLED: boolean = true;
  /** 宽度断点闸：大于此断点（`WIDTH_MD` 之后）不做滚动联动。 */
  private static readonly COMPACT_WIDTH_BREAKPOINT_MAX: number = 1;
  /** 上游那个状态机（一个实例就够：它自己维护 pressing/axis/run/节流）。 */
  private static readonly collapse: BarCollapse = new BarCollapse();
  /** 折算用的"虚拟 y"：每次滚动增量都叠到它上面，喂给 `BarCollapse.onMove`。 */
  private static virtualY: number = 0;
  /**
   * 壳层注册的落地回调：把「展开意图」交给 `HdsTabsController.applyMiniBarStyle()`。
   * 注册点：`Index.aboutToAppear()`。
   */
  public static expandApplier: ((expand: boolean) => void) | undefined = undefined;

  /**
   * @returns 是否启用滚动联动（沿用既有开关）。
   */
  public static isEnabled(): boolean {
    return BarScrollHelper.SCROLL_LINK_ENABLED;
  }

  /**
   * @returns 当前是否收起（上游 `BarCollapse.isCollapsed()`）。
   */
  public static isCollapsed(): boolean {
    return BarScrollHelper.collapse.isCollapsed();
  }

  /**
   * 滚动联动入口：把滚动增量喂给上游状态机，跨过阈值时把意图交给壳层。
   *
   * @param _ctx 壳层 UIContext（保留签名兼容既有调用点；本函数不起任何动画）
   * @param appState 全局状态（只写 `miniBarExpanded`）
   * @param delta 本次滚动增量（vp；正 = 内容向下滚）
   * @param widthBreakpoint 宽度断点
   */
  public static notifyScrollDelta(_ctx: UIContext, appState: MusicAppState, delta: number,
    widthBreakpoint: number): void {
    if (!SdkApiUtil.isDistributionOsApiAtLeast(SdkConstants.DISTRIBUTION_OS_6_1_1_CODE)) {
      return;
    }
    if (widthBreakpoint > BarScrollHelper.COMPACT_WIDTH_BREAKPOINT_MAX) {
      return;
    }
    if (delta === 0) {
      return;
    }
    // 滚动增量 → 虚拟手势：首帧按下，之后逐帧移动（判据全在 BarCollapse 里）。
    if (BarScrollHelper.collapse.lockedAxis() === BarAxis.NONE) {
      BarScrollHelper.collapse.onDown(0, BarScrollHelper.virtualY);
    }
    BarScrollHelper.virtualY = BarScrollHelper.virtualY + delta;
    const action: BarAction = BarScrollHelper.collapse.onMove(0, BarScrollHelper.virtualY, Date.now());
    if (action === BarAction.NONE) {
      return;
    }
    // 方向以用户实测为准：**上滑 ⇒ 单行（展开档）**、下滑 ⇒ 两排。
    const expand: boolean = action === BarAction.EXPAND;
    Logger.info('RzdBarLayout', `scroll delta=${delta} action=${action} expand=${expand}`);
    if (appState.miniBarExpanded === expand) {
      return;
    }
    appState.miniBarExpanded = expand;
    if (BarScrollHelper.expandApplier !== undefined) {
      BarScrollHelper.expandApplier(expand);
    }
  }

  /** 滚动结束时收尾（与上游 `onUp()` 同义）。 */
  public static endScroll(): void {
    BarScrollHelper.collapse.onUp();
    BarScrollHelper.virtualY = 0;
  }
}

/**
 * 滚动增量跟踪器：把列表的累计 `offset` 转成"本帧增量"。
 *
 * 只在同一轮滚动里有效；`reset()` 由调用方在滚动结束时调。
 */
export class BarScrollDeltaTracker {
  private lastOffset: number = 0;
  private started: boolean = false;

  /**
   * @param offset 当前累计滚动偏移（vp）
   * @returns 相对上一帧的增量（第一帧返回 0）
   */
  public delta(offset: number): number {
    if (!this.started) {
      this.started = true;
      this.lastOffset = offset;
      return 0;
    }
    const d: number = offset - this.lastOffset;
    this.lastOffset = offset;
    return d;
  }

  /** 复位（新一次滚动开始时调用）。 */
  public reset(): void {
    this.started = false;
    this.lastOffset = 0;
  }
}
