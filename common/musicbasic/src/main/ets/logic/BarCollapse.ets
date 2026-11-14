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
 * 无界 `design/logic/BarCollapse` 的**逐字移植**（`wujie.pa:83829-84220`）。
 *
 * 这是上游底栏「展开 / 收起」手势判定的**唯一**实现：字段与方法一一对应字节码里的
 * `pressing / lastY / downX / downY / axis / run / collapsed / lastFireAt` 与
 * `isCollapsed() / lockedAxis() / onDown() / onMove() / onUp()`（`:83856` / `:83865` / `:83874` /
 * `:83894` / `:84105`）。
 *
 * 判据（逐行直读）：
 * ```
 *   THRESHOLD = 1.5                       fldai 1.5  :84165 → stlexvar :84166
 *   轴锁 |dx| > |dy| → HORIZONTAL          greater :83936
 *   HORIZONTAL 直接 return NONE            :83957-83966
 *   run += y − lastY（向下为正）           sub2 0x3b,a4  :83990
 *   方向反转 ⇒ run 清零                    :84005-84020
 *   节流 250ms                             ldai 0xfa / less  :84077-84078
 *   run ≤ −1.5 ⇒ collapsed=true ⇒ COLLAPSE :84023-84044
 *   run ≥ +1.5 ⇒ collapsed=false ⇒ EXPAND  :84086-84097
 * ```
 * 上游把"判意图"和"落地"分开：本文件只判意图（`BarAction`），落地由
 * `MainPage.applyBarAction()` → `controller.applyMiniBarStyle()` 负责（`:145755-145790`，
 * 注意映射是**反向**的：`action === COLLAPSE ? HdsBarStyle.EXPAND : HdsBarStyle.COLLAPSE`）。
 */

/** 上游 `BarAction`（`wujie.pa:84105` 一带的返回值）。 */
export enum BarAction {
  NONE = 0,
  COLLAPSE = 1,
  EXPAND = 2
}

/** 上游 `BarAxis`（`wujie.pa:83936` 一带的 `NONE/HORIZONTAL/VERTICAL`）。 */
export enum BarAxis {
  NONE = 0,
  HORIZONTAL = 1,
  VERTICAL = 2
}

/** 上游 `design/logic/BarCollapse`（`wujie.pa:83829-84220`）。 */
export class BarCollapse {
  /** 触发阈值（vp）：`wujie.pa:84165`。 */
  public static readonly THRESHOLD: number = 1.5;
  /** 节流窗口（ms）：`wujie.pa:84077`。 */
  public static readonly THROTTLE_MS: number = 250;

  /** 是否正在按压（`onDown` 置真、`onUp` 置假）。 */
  private pressing: boolean = false;
  /** 上一次的 y（累计量 `run` 靠它求差）。 */
  private lastY: number = 0;
  /** 按下点 x / y（轴锁用）。 */
  private downX: number = 0;
  private downY: number = 0;
  /** 本轮的锁定轴。 */
  private axis: BarAxis = BarAxis.NONE;
  /** 竖向累计位移（向下为正）。 */
  private run: number = 0;
  /** 当前是否处于"收起"态。 */
  private collapsed: boolean = false;
  /** 上一次真正发放动作的时刻。 */
  private lastFireAt: number = 0;

  /**
   * @returns 上游 `isCollapsed()`（`wujie.pa:83856`）：当前是否收起。
   */
  public isCollapsed(): boolean {
    return this.collapsed;
  }

  /**
   * @returns 上游 `lockedAxis()`（`wujie.pa:83865`）：本轮锁定的轴。
   */
  public lockedAxis(): BarAxis {
    return this.axis;
  }

  /**
   * 上游 `onDown(x, y)`（`wujie.pa:83874`）。
   * @param x 按下点 x（vp）
   * @param y 按下点 y（vp）
   */
  public onDown(x: number, y: number): void {
    this.pressing = true;
    this.lastY = y;
    this.downX = x;
    this.downY = y;
    this.axis = BarAxis.NONE;
    this.run = 0;
  }

  /**
   * 上游 `onMove(x, y, now)`（`wujie.pa:83894`）：返回本轮该发的动作。
   * @param x 当前 x（vp）
   * @param y 当前 y（vp）
   * @param now 当前时间戳（ms，节流用）
   * @returns BarAction（NONE / COLLAPSE / EXPAND）
   */
  public onMove(x: number, y: number, now: number): BarAction {
    if (!this.pressing) {
      return BarAction.NONE;
    }
    // 轴锁：第一次移动时定轴，横向之后一律放行（`wujie.pa:83936` / `:83957-83966`）。
    if (this.axis === BarAxis.NONE) {
      const dx: number = Math.abs(x - this.downX);
      const dy: number = Math.abs(y - this.downY);
      this.axis = dx > dy ? BarAxis.HORIZONTAL : BarAxis.VERTICAL;
    }
    if (this.axis === BarAxis.HORIZONTAL) {
      return BarAction.NONE;
    }
    const step: number = y - this.lastY;
    this.lastY = y;
    if (step === 0) {
      return BarAction.NONE;
    }
    // 方向反转 ⇒ 累计清零（`wujie.pa:84005-84020`）。
    if ((this.run > 0 && step < 0) || (this.run < 0 && step > 0)) {
      this.run = 0;
    }
    this.run = this.run + step;
    // 节流（`wujie.pa:84077-84078`）。
    if (now - this.lastFireAt < BarCollapse.THROTTLE_MS) {
      return BarAction.NONE;
    }
    if (this.run <= -BarCollapse.THRESHOLD) {
      this.collapsed = true;
      this.run = 0;
      this.lastFireAt = now;
      return BarAction.COLLAPSE;
    }
    if (this.run >= BarCollapse.THRESHOLD) {
      this.collapsed = false;
      this.run = 0;
      this.lastFireAt = now;
      return BarAction.EXPAND;
    }
    return BarAction.NONE;
  }

  /**
   * 上游 `onUp()`（`wujie.pa:84105`）。
   */
  public onUp(): void {
    this.pressing = false;
    this.axis = BarAxis.NONE;
    this.run = 0;
  }

  /**
   * 上游 `reset()`（HDS 点击 `USER_CLICK + EXPAND` 时会调，`wujie.pa:149195-149205`）。
   */
  public reset(): void {
    this.pressing = false;
    this.axis = BarAxis.NONE;
    this.run = 0;
    this.collapsed = false;
  }
}
