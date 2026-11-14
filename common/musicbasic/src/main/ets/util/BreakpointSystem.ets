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
 * Per-breakpoint value bundle for width (and optional short-height SM) layouts.
 * @template T Value type stored for each breakpoint (e.g. column count, flag).
 */
export class BreakpointType<T> {
  /** Value for XS/SM width breakpoints. */
  public sm: T;
  /** Value for MD width breakpoint. */
  public md: T;
  /** Value for LG width breakpoint. */
  public lg: T;
  /** Value for XL width breakpoint. */
  public xl: T;
  /** Optional override when height is MD and width is SM (fold / short layouts). */
  public heightSm?: T;

  /**
   * @param sm Value for XS/SM widths.
   * @param md Value for MD width.
   * @param lg Value for LG width.
   * @param xl Value for XL width.
   * @param heightSm Optional SM-height override; falls back to sm when omitted.
   */
  public constructor(sm: T, md: T, lg: T, xl: T, heightSm?: T) {
    this.sm = sm;
    this.md = md;
    this.lg = lg;
    this.xl = xl;
    this.heightSm = heightSm;
  }

  /**
   * Selects the value for the given width breakpoint only.
   * @param widthBp Current window width breakpoint.
   * @returns Mapped value; defaults to sm for unknown values.
   */
  public getValue(widthBp: WidthBreakpoint): T {
    switch (widthBp) {
      case WidthBreakpoint.WIDTH_XS:
      case WidthBreakpoint.WIDTH_SM:
        return this.sm;
      case WidthBreakpoint.WIDTH_MD:
        return this.md;
      case WidthBreakpoint.WIDTH_LG:
        return this.lg;
      case WidthBreakpoint.WIDTH_XL:
        return this.xl;
      default:
        return this.sm;
    }
  }

  /**
   * Like {@link getValue} but may return {@link heightSm} for SM width + MD height.
   * @param widthBp Current width breakpoint.
   * @param heightBp Current height breakpoint.
   * @returns Effective layout value.
   */
  public getWidthValueWithHeightSM(widthBp: WidthBreakpoint, heightBp: HeightBreakpoint): T {
    if (heightBp === HeightBreakpoint.HEIGHT_MD && widthBp === WidthBreakpoint.WIDTH_SM) {
      return this.heightSm !== undefined ? this.heightSm : this.sm;
    }
    return this.getValue(widthBp);
  }
}

/**
 * @param widthBp Current width breakpoint.
 * @returns True when width is LG or XL (wide layouts).
 */
export function isWidthBreakpointLgOrXl(widthBp: WidthBreakpoint): boolean {
  return widthBp === WidthBreakpoint.WIDTH_LG || widthBp === WidthBreakpoint.WIDTH_XL;
}

/**
 * @returns 详情页是否该用「**左侧卡片 + 右侧列表**」的分栏版式。
 *
 * ★ 2026-10-24（甲方：「我手机横屏看，那两个页面还是之前的差不多的样式」）：
 *   原来只判 `LG/XL`，而**手机横屏是「宽 MD + 矮 SM」**（典型 780×360vp）⇒ 永远不命中。
 *   现在 = 平板/阔屏（LG/XL）**或** 手机横屏（MD 宽 + SM 高）。
 * @param widthBp 当前宽度断点
 * @param heightBp 当前高度断点
 */
export function shouldUseSplitDetailLayout(widthBp: WidthBreakpoint, heightBp: HeightBreakpoint): boolean {
  if (widthBp === WidthBreakpoint.WIDTH_LG || widthBp === WidthBreakpoint.WIDTH_XL) {
    return true;
  }
  return widthBp === WidthBreakpoint.WIDTH_MD && heightBp === HeightBreakpoint.HEIGHT_SM;
}

/**
 * @returns 分栏版式左侧那张卡片的宽度（vp）——**跟着可用高度收**，保证卡内「方形封面 + 文字」放得下。
 *
 * 卡片是竖的：内容 = 方形封面（边长 = 卡宽 − 32 内边距）+ 标题/副标题/播放钮（≈110vp）。
 * - 平板/阔屏：取基数（LG 360 / XL 420）；
 * - 手机横屏（可用高只有 ~300）：按 `可用高 − 110` 反推卡宽，否则方形封面会被挤成一条缝。
 * @param widthBp 当前宽度断点
 * @param availableHeightVp 卡片可用的高度（已扣掉标题栏让位与页面内边距）
 */
export function splitDetailCardWidthVp(widthBp: WidthBreakpoint, availableHeightVp: number): number {
  const base: number = widthBp === WidthBreakpoint.WIDTH_XL ? 420
    : (widthBp === WidthBreakpoint.WIDTH_LG ? 360 : 260);
  if (!(availableHeightVp > 0)) {
    return base;
  }
  // 卡片内容最少要：方形封面 + 文字块
  const byHeight: number = Math.round(availableHeightVp - 110 + 32);
  return Math.max(160, Math.min(base, byHeight));
}
