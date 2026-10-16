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
 * 控制条「**拖动收起 / 展开**」的手势状态机 —— **逐条照搬无界 1.2.4 的
 * `design/src/main/ets/logic/BarCollapse.ets`**。
 *
 * 出处（字节码，`_recover/disasm/wujie.pa`，本文件所有数值与分支都对着它写）：
 *
 * | 内容 | 行号 |
 * | --- | --- |
 * | `Axis` 枚举（`NONE 0 / VERTICAL 1 / HORIZONTAL 2`） | 83706-83732 |
 * | `BarAction` 枚举（`NONE 0 / COLLAPSE 1 / EXPAND 2`） | 83737-83763 |
 * | `reportFingerTouch`（唯一入口） | 83768-83822 |
 * | 构造器字段默认值 | 83829-83851 |
 * | `isCollapsed` / `lockedAxis` | 83856 / 83865 |
 * | `onDown` | 83874-83889 |
 * | `onMove`（主体，231 行） | 83894-84100 |
 * | `onUp` | 84105-84114 |
 * | `reset` | 84119-84140 |
 * | 模块常量 `THRESHOLD = 1.5`（`fldai 1.500000e+00`） | 84165-84166 |
 *
 * ⚠️ 文档里那句「静止若干秒自动下沉」是把本模块**看错了**：它的真身是**手势**状态机
 *   （`onDown/onMove/onUp/reset` + `lockedAxis()`），不是定时器。
 *
 * ## 语义（照抄后的行为）
 *
 * ```
 *   · 按下（`onDown`）：记 downX/downY/lastY，axis = NONE，run = 0；
 *   · 移动（`onMove`）：
 *       ① 轴向未定 且 横/纵位移有一者超过 THRESHOLD(1.5) ⇒ **锁定轴向**
 *          （横向位移更大 ⇒ HORIZONTAL；否则 ⇒ VERTICAL）；
 *       ② 锁定为 HORIZONTAL ⇒ 这一串手势**完全不管**，只更新 lastY；
 *       ③ 锁定为 VERTICAL ⇒ 累积 `run += (本帧 y − 上一帧 y)`：
 *            · `run <= −THRESHOLD` ⇒ 目标 `collapsed = true`（**下拉收起**）；
 *            · `run >= +THRESHOLD` ⇒ 目标 `collapsed = false`（**上推展开**）；
 *            · 中间 ⇒ 不动作（返回 NONE）；
 *          ⚠️ 目标与当前状态相同 ⇒ 不动作；且两次动作之间**至少隔 150ms**
 *             （`ldai 0xfa` = 250？不 —— `0xfa` = **250**，见下面那条注释）；
 *       ④ 一旦动作过，`run` 归 0 重新累积；
 *   · 松开（`onUp`）：pressing = false、axis = NONE、run = 0；
 *   · `reset()`：回到初始（pressing=false / axis=NONE / 0 / 0 / 0 / collapsed=false / lastFireAt=0）。
 * ```
 *
 * ⚠️ **关于节流值**：字节码是 `ldai 0xfa` ⇒ 十进制 **250**，不是 150。
 *   本文件按 **250ms** 写（`FIRE_INTERVAL_MS`），与字节码一致。
 *
 * ⚠️ **`THRESHOLD` 的用途是双重的**：既用于"轴向锁定"的起手判定，也用于 `run` 的动作判定。
 *   两处都是同一个 1.5。
 *
 * ## 与「空闲计时」的关系（别混）
 *
 * 无界 `PlayerPage` 另有一个 `idleTimer` + `IDLE_MS`（自动收起），**与本状态机是两件事**：
 * 本文件只管**手势**；空闲计时见 `RzdMusic记忆.md` 的 D6 条目。
 */
export enum BarAxis {
  NONE = 0,
  VERTICAL = 1,
  HORIZONTAL = 2
}

/** 手势要执行的动作（`BarAction`，字节码 83737-83763）。 */
export enum BarAction {
  NONE = 0,
  COLLAPSE = 1,
  EXPAND = 2
}

/**
 * 控制条拖动手势状态机（无界 `BarCollapse`）。
 *
 * ⚠️ 它是**纯逻辑**、不碰任何 UI：调用方负责把"当前时间戳"与"是否已收起"喂进来，
 *    并根据返回的 `BarAction` 去驱动自己的收起/展开动画。
 */
export class BarCollapse {
  /** 动作判定阈值（无界模块常量 `THRESHOLD`，`fldai 1.5`）。 */
  private static readonly THRESHOLD: number = 1.5;
  /** 两次动作之间的最小间隔（ms）—— 字节码 `ldai 0xfa` = **250**。 */
  private static readonly FIRE_INTERVAL_MS: number = 250;

  /** 上一帧的 y（vp，窗口坐标）。 */
  private lastY: number = 0;
  /** 手指是否按着。 */
  private pressing: boolean = false;
  /** 起手点的 x / y（vp，窗口坐标）—— 只用于**轴向锁定**。 */
  private downX: number = 0;
  private downY: number = 0;
  /** 锁定的轴向（`NONE` = 还没定）。 */
  private axis: BarAxis = BarAxis.NONE;
  /** 累计的纵向行程（vp）；每次动作后归 0 重新累积。 */
  private run: number = 0;
  /** 上一次动作时"目标状态"是否等于"已收起"。 */
  private collapsed: boolean = false;
  /** 上一次动作的时间戳（ms）；0 = 还没动作过。 */
  private lastFireAt: number = 0;

  /** @returns 当前是否处于"已收起"（无界 `isCollapsed` getter）。 */
  public isCollapsed(): boolean {
    return this.collapsed;
  }

  /** @returns 已锁定的轴向（无界 `lockedAxis` getter）。 */
  public lockedAxis(): BarAxis {
    return this.axis;
  }

  /** 按下（`onDown`，字节码 83874-83889）。 */
  public onDown(x: number, y: number): void {
    this.pressing = true;
    this.lastY = y;
    this.downX = x;
    this.downY = y;
    this.axis = BarAxis.NONE;
    this.run = 0;
  }

  /**
   * 移动（`onMove`，字节码 83894-84100）—— 本状态机的主体。
   * @param x 当前 x（vp，窗口坐标）
   * @param y 当前 y（vp，窗口坐标）
   * @param now 当前时间戳（ms）
   * @returns 本次要执行的动作
   */
  public onMove(x: number, y: number, now: number): BarAction {
    // ① 轴向未定 ⇒ 用"横/纵位移绝对值"决定锁定哪一根轴
    if (this.axis === BarAxis.NONE) {
      const dx: number = Math.abs(this.downX - x);
      const dy: number = Math.abs(this.downY - y);
      const overX: boolean = dx > BarCollapse.THRESHOLD;
      const overY: boolean = dy > BarCollapse.THRESHOLD;
      if (overX || overY) {
        // 横向位移更大 ⇒ 横向；否则 ⇒ 纵向（`dx > dy ? HORIZONTAL : VERTICAL`）
        this.axis = dx > dy ? BarAxis.HORIZONTAL : BarAxis.VERTICAL;
      }
    } else if (this.axis === BarAxis.HORIZONTAL) {
      // ② 已经锁定横向 ⇒ 这串手势不归本状态机管（只更新 lastY 后返回）
      this.lastY = y;
      this.run = 0;
      return BarAction.NONE;
    }
    // ③ 纵向（或本轮刚锁定为纵向）⇒ 累积行程
    if (!this.pressing) {
      this.lastY = y;
      return BarAction.NONE;
    }
    const delta: number = this.lastY - y;
    this.lastY = y;
    if (delta === 0) {
      return BarAction.NONE;
    }
    const down: boolean = delta > 0;
    const firedBefore: boolean = this.run > 0;
    if (down === firedBefore) {
      // 同向继续累积
      this.run = this.run + delta;
    } else {
      // 反向 ⇒ 重新开始累积（字节码 L84019-84020）
      this.run = delta;
    }
    // 目标状态：run <= −1.5 ⇒ 收起；run >= +1.5 ⇒ 展开；中间 ⇒ 不动作
    let want: boolean | undefined = undefined;
    if (this.run <= -BarCollapse.THRESHOLD) {
      want = true;
    } else if (this.run >= BarCollapse.THRESHOLD) {
      want = false;
    }
    if (want === undefined) {
      return BarAction.NONE;
    }
    this.run = 0;
    // 目标与当前一致 ⇒ 不动作
    if (this.collapsed === want) {
      return BarAction.NONE;
    }
    // 节流：两次动作至少间隔 FIRE_INTERVAL_MS（250ms）
    if (this.lastFireAt !== 0 && (now - this.lastFireAt) < BarCollapse.FIRE_INTERVAL_MS) {
      return BarAction.NONE;
    }
    this.lastFireAt = now;
    this.collapsed = want;
    return want ? BarAction.COLLAPSE : BarAction.EXPAND;
  }

  /** 松开（`onUp`，字节码 84105-84114）。 */
  public onUp(): void {
    this.pressing = false;
    this.axis = BarAxis.NONE;
    this.run = 0;
  }

  /** 复位（`reset`，字节码 84119-84140）。 */
  public reset(): void {
    this.pressing = false;
    this.axis = BarAxis.NONE;
    this.lastY = 0;
    this.downX = 0;
    this.downY = 0;
    this.run = 0;
    this.collapsed = false;
    this.lastFireAt = 0;
  }

  /**
   * 唯一入口（无界 `reportFingerTouch`，字节码 83768-83822）—— 把 `TouchEvent` 喂进来。
   *
   * 无界的原文行为：
   * ```
   *   if (event.type === TouchType.Up/Cancel ？) { ... }
   *   if (event.touches.length !== 0 && <非抬起>) return;      // 只在单指且按下/移动时处理
   *   const x = px2vp(event.touches[0].windowX);
   *   const y = px2vp(event.touches[0].windowY);
   *   handler(event.type, x, y);
   * ```
   * ⚠️ 字节码里那个"手势类型"实参是 `a4`（一个回调对象），`istrue/isfalse` 那两跳我按
   *   "抬起类事件直接丢给回调、否则要求 `touches.length === 0` 就早退"转写（见 `PlaybackPage` 的用法）。
   * @param type 触摸类型
   * @param windowX 触点窗口坐标 x（px）
   * @param windowY 触点窗口坐标 y（px）
   * @param touchCount 当前触点个数
   * @param now 当前时间戳（ms）
   * @returns 本次要执行的动作
   */
  public reportTouch(type: TouchType, windowX: number, windowY: number,
    touchCount: number, now: number): BarAction {
    const x: number = px2vp(windowX);
    const y: number = px2vp(windowY);
    // ⚠️ `TouchType` 的成员名是**驼峰**：`Down / Up / Move / Cancel`
    //   （本机 SDK `ets-loader/declarations/enums.d.ts:1283/1305/1327/1349`）。
    //   本轮实测踩过一次：写成 `DOWN/MOVE/UP/CANCEL` 会编译报
    //   `Property 'DOWN' does not exist on type 'typeof TouchType'`。
    if (type === TouchType.Down) {
      this.onDown(x, y);
      return BarAction.NONE;
    }
    if (type === TouchType.Move) {
      // 多指时不管（无界：`touches.length !== 0` 的那条早退）
      if (touchCount !== 1) {
        return BarAction.NONE;
      }
      return this.onMove(x, y, now);
    }
    if (type === TouchType.Up || type === TouchType.Cancel) {
      this.onUp();
      return BarAction.NONE;
    }
    return BarAction.NONE;
  }
}
