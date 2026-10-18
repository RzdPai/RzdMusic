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
import { SdkApiUtil } from './SdkApiUtil';
import { Logger } from './Logger';

/**
 * 底栏「迷你条展开 / 收起」的**意图判定**（滚动联动）。
 *
 * ══════════════════ 一、只判意图，不碰布局、不自己起动画（2026-10-18 照搬无界） ══════════════════
 *
 * 上游把这件事拆成**两段**（`wujie.pa:145755-145790`）：
 * ```
 *   ① 判意图：design/logic/BarCollapse.onDown/onMove/onUp → BarAction.COLLAPSE | EXPAND
 *   ② 落地  ：applyBarAction(action) → controller.applyMiniBarStyle(
 *                action === COLLAPSE ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE)
 * ```
 * 并且 **`barLayoutMode` 运行期从不改**（整份 abc 只有 4 处写、全是对象字面量、值恒 `VERTICAL`：
 * `wujie.pa:143295` / `:144066` / `:144083` / `:520524`），`MainPage` 整模块 `animateTo` **零命中**
 * —— 样式切换的动画由 HDS 内部默认动效给（SDK `@hms.hds.hdsBaseComponent.d.ets:5729` 原文
 * 「Switch the display style of the mini bar. **The style switch will be accompanied by a
 * default animation.**」）。
 *
 * ⇒ 本文件只做第 ① 段：判断"该展开还是该收起"，然后把意图交给壳层注册的 {@link expandApplier}。
 *   本文件在 `common` 层，拿不到 `HdsTabsController`，所以必须走回调。
 *
 * ══════════════════ 二、判据照上游 `BarCollapse`（`wujie.pa:83829-84220`） ══════════════════
 *
 * | 量 | 值 | 出处 |
 * | --- | --- | --- |
 * | 触发阈值 | **1.5**（`fldai 1.5` → `stlexvar 0x0,0x0`） | `:84165-84166` |
 * | 累计量 | `sub2 0x3b,a4` = `y − lastY`（向下为正） | `:83990` |
 * | 方向反转 | 累计清零 | `:84005-84020` |
 * | 节流 | **250ms**（`ldai 0xfa`、`less`） | `:84077-84078` |
 *
 * 本仓的入口是**滚动增量**（多个页面已经在喂 {@link BarScrollDeltaTracker}），语义与上游的
 * "手指累计位移"同向：内容向下滚（`delta > 0`）≡ 手指上滑 ≡ 上游的 `EXPAND` 意图。
 */
export class BarScrollHelper {
  /** 滚动联动总开关。 */
  private static readonly SCROLL_LINK_ENABLED: boolean = true;
  /** 宽度断点闸：大于此断点（`WIDTH_MD` 之后）不做滚动联动。 */
  private static readonly COMPACT_WIDTH_BREAKPOINT_MAX: number = 1;
  /** 上游 `BarCollapse` 的触发阈值（vp）：`wujie.pa:84165`。 */
  private static readonly FLING_THRESHOLD_VP: number = 1.5;
  /** 上游 `BarCollapse` 的节流窗口（ms）：`wujie.pa:84077`（`0xfa` = 250）。 */
  private static readonly THROTTLE_MS: number = 250;
  /** 上一次真正发放意图的时刻（节流用）。 */
  private static lastFireAtMs: number = 0;
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
   * 滚动联动：**只表达展开意图**，不写 `barLayoutMode`、不自己起 `animateTo`。
   *
   * @param _ctx 壳层 UIContext（保留签名兼容既有调用点；本函数不再用它起动画）
   * @param appState 全局状态（只写 `miniBarExpanded`）
   * @param delta 本次滚动增量（vp；正 = 内容向下滚 = 手指上滑 = 展开意图）
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
    const expand: boolean = delta > BarScrollHelper.FLING_THRESHOLD_VP;
    const collapse: boolean = delta < -BarScrollHelper.FLING_THRESHOLD_VP;
    if (!expand && !collapse) {
      return;
    }
    const now: number = Date.now();
    if (now - BarScrollHelper.lastFireAtMs < BarScrollHelper.THROTTLE_MS) {
      return;
    }
    if (appState.miniBarExpanded === expand) {
      return;
    }
    BarScrollHelper.lastFireAtMs = now;
    appState.miniBarExpanded = expand;
    Logger.info('RzdBarLayout', `scroll delta=${delta} expand=${expand}`);
    if (BarScrollHelper.expandApplier !== undefined) {
      BarScrollHelper.expandApplier(expand);
    }
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
