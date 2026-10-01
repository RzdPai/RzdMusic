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

import { curves } from '@kit.ArkUI';
import { BarLayoutModes, SdkConstants } from '../constants/Constants';
import { MusicAppState } from '../model/MusicAppState';
import { SdkApiUtil } from './SdkApiUtil';
import { Logger } from './Logger';

/**
 * 双层底栏（迷你条 + 页签）的滚动联动。
 *
 * 放在 common 层而不是某个 feature 里：滚动回调发生在多个 feature 页面
 * （推荐首页 / 歌单页 / 我的 / 设置），若 helper 落在单个 feature，
 * 其它页面就要反向依赖它，容易成环。这里只依赖 `MusicAppState` 的 number 字段，
 * 不引入任何 HDS UI 类型。
 */
export class BarScrollHelper {
  /** 触发切换的最小滚动增量（vp），过滤掉惯性抖动。 */
  private static readonly DELTA_THRESHOLD: number = 2;
  /** 弹簧动效时长（ms）。 */
  private static readonly ANIMATION_MS: number = 500;
  /** 只在小屏宽度断点（< lg）参与联动，宽屏保持两排。 */
  private static readonly COMPACT_WIDTH_BREAKPOINT_MAX: number = 1;
  /**
   * 滚动联动总开关。
   *
   * **已开启**：列表上滑 → 单层（左圆Tab右长播放器）；列表下滑 → 双层。
   * 用户明确要求「全都自动收起展开」，所以首页、歌单页、我的页、设置页**都要接**
   * 滚动回调 —— 只要有一个页面不接，就会出现「有的页面收、有的页面不收」的不一致。
   * 调用点见各 feature 页面的 `onScrollFrameBegin` / `onDidScroll`。
   */
  private static readonly SCROLL_LINK_ENABLED: boolean = true;

  /** @returns 滚动联动是否开启。 */
  public static isEnabled(): boolean {
    return BarScrollHelper.SCROLL_LINK_ENABLED;
  }

  /**
   * 根据滚动增量切换双层底栏排布模式。
   *
   * 方向（**已按真机反馈确认**）：
   *   增量 > 0（内容偏移增加、手指上滑）→ 单排（HORIZONTAL）+ 长迷你条
   *   增量 < 0（内容偏移减少、手指下滑）→ 双排（VERTICAL）
   *
   * offset是内容滚动距离，不是手指位移；不要反转这两个坐标口径。
   *
   * 入参是**本帧滚动增量**，不是累计偏移：调用方用
   * `onScrollFrameBegin((offset) => { ...; return { offsetRemain: offset }; })` 的 offset。
   *
   * @param ctx UIContext，用于 animateTo。
   * @param appState 全局播控状态（写入 hdsBarLayoutMode / miniBarExpanded）。
   * @param delta 本帧滚动增量（vp）。
   * @param widthBreakpoint 当前宽度断点（0 = sm）。
   */
  public static notifyScrollDelta(ctx: UIContext, appState: MusicAppState, delta: number,
    widthBreakpoint: number): void {
    // barLayoutMode / miniBarStyle 仅在 6.1.1(24) 及以上可用，低版本直接跳过，
    // 避免在旧机上写入无效状态。
    if (!SdkApiUtil.isDistributionOsApiAtLeast(SdkConstants.DISTRIBUTION_OS_6_1_1_CODE)) {
      return;
    }
    if (widthBreakpoint > BarScrollHelper.COMPACT_WIDTH_BREAKPOINT_MAX) {
      return;
    }
    if (delta > BarScrollHelper.DELTA_THRESHOLD) {
      // 列表上滑 → 单层：左侧圆页签，右侧长播放器。
      if (appState.hdsBarLayoutMode === BarLayoutModes.HORIZONTAL && appState.miniBarExpanded) {
        return;
      }
      ctx.animateTo({
        duration: BarScrollHelper.ANIMATION_MS,
        curve: curves.springMotion(0.5, 0.7, 0.6)
      }, (): void => {
        Logger.info('RzdBarLayout', `scroll delta=${delta} target=single-row`);
        appState.hdsBarLayoutMode = BarLayoutModes.HORIZONTAL;
        appState.miniBarExpanded = true;
      });
    } else if (delta < -BarScrollHelper.DELTA_THRESHOLD) {
      // 列表下滑 → 双层：页签与播放器上下各一排。
      if (appState.hdsBarLayoutMode === BarLayoutModes.VERTICAL && !appState.miniBarExpanded) {
        return;
      }
      ctx.animateTo({
        duration: BarScrollHelper.ANIMATION_MS,
        curve: curves.springMotion(0.5, 0.7, 0.6)
      }, (): void => {
        Logger.info('RzdBarLayout', `scroll delta=${delta} target=two-rows`);
        appState.hdsBarLayoutMode = BarLayoutModes.VERTICAL;
        appState.miniBarExpanded = false;
      });
    }
  }
}

/**
 * 把连续的滚动偏移换算成增量，供 {@link BarScrollHelper} 使用。
 * ArkUI 的 `onDidScroll` 只给绝对偏移，需要调用方自己记住上一次的值。
 */
export class BarScrollDeltaTracker {
  private lastOffset: number = 0;
  private started: boolean = false;

  /**
   * @param offset 本次滚动内容的绝对偏移（vp）。
   * @returns 相对上一次的增量；首次调用返回 0。
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

  /** 复位（页面重新出现时调用），避免切页后第一帧算出一个巨大的增量。 */
  public reset(): void {
    this.started = false;
    this.lastOffset = 0;
  }
}
