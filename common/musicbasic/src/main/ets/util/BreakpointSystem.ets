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
