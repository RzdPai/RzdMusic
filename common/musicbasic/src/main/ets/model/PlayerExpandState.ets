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
 * 迷你条封面的组件 id。
 *
 * ⚠️ 常量必须放在公共层：迷你条在 `features/playlist`、动画宿主在 `features/player`，
 * 两边要用同一个字符串，而 features 之间**禁止互相 import**（三层架构硬约束）。
 */
export const MINI_BAR_COVER_ID: string = 'rzd_mini_bar_cover';

/** 播放页大封面的组件 id（同上，放公共层避免 features 横向依赖）。 */
export const PLAYER_BIG_COVER_ID: string = 'rzd_player_big_cover';

/** clip 窗口在静止态向外扩张的余量（vp）：保证任何窗口尺寸都不会裁到内容。 */
const CLIP_IDLE_MARGIN_VP: number = 120;

/**
 * 把 `Area` 里的 `Length` 取成 vp 数值。
 *
 * `Area.width` / `Area.globalPosition.x` 的静态类型是 `Length = string | number | Resource`，
 * 直接 `Number()` 在 ArkTS 下过不了类型检查（Resource 分支没法转），所以显式收窄。
 * @param value Length 值
 * @returns vp 数值；无法解析时返回 0
 */
export function areaLengthToVp(value: Length | undefined): number {
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') {
    const parsed: number = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

/**
 * 播放页「一镜到底」展开动画的**共享几何 + 相位**。
 *
 * 为什么放在 common：迷你条在 `features/playlist`、播放页/动画宿主在 `features/player`、
 * 触发点在 products 的壳层 —— 三方都要读写同一份数据，只能放公共层
 * （只含 number / boolean / string，不引入任何 UI 组件类型，不会造成循环依赖）。
 *
 * ## 观感（参考 musicfreeOH 的 `PlayerExpandAnim`）
 *
 * 播放页**彻底不动**（始终铺在窗口原位），只做两件事：
 *   1. **clip 窗口**从「迷你条封面那个小方块」长到整屏 —— 这就是「向上下延伸铺满」；
 *   2. 另画一张**飞行封面**（见宿主里的 `Image`），从迷你条封面的矩形逐帧插值到
 *      播放页大封面的矩形 —— 这就是「封面慢慢变大并移动到整个大封面」。
 *
 * 这样做的关键好处：整页不做缩放/位移，文字与控件**全程不变形**；
 * 而且迷你条封面与播放页大封面在动画期间都被隐藏，画面上只有一张封面在飞，
 * 不会出现两张封面同时可见的重影。
 *
 * ## 相位
 *
 * ```
 *   空闲         preparing            animating             空闲
 *  progress=1 → progress=0 ────────→ progress 0→1 ────────→ progress=1
 *  （未挂载）   页面透明、量两端矩形    飞行封面可见、迷你条封面隐藏
 * ```
 *
 * `preparing` 相位是**防闪的关键**：播放页已经挂载（能测量、能布局），但整页不透明度为 0，
 * 所以看不到「播放页先整个弹出来、封面再飞过去」的断层。
 */
@ObservedV2
export class PlayerExpandState {
  // ───────────────────────── 相位 ─────────────────────────

  /** 播放页已挂载、正在测量两端矩形（此期间整页不透明度为 0）。 */
  @Trace public preparing: boolean = false;
  /** 一镜到底动画进行中（飞行封面可见、迷你条封面与播放页大封面隐藏）。 */
  @Trace public animating: boolean = false;
  /** 动画进度：0 = 收在迷你条位置，1 = 完全展开。 */
  @Trace public progress: number = 1;

  // ─────────────────── 起点：迷你条封面（窗口坐标 vp）───────────────────

  /** 迷你条封面在窗口中的左边界（vp）。 */
  @Trace public miniX: number = 0;
  /** 迷你条封面在窗口中的上边界（vp）。 */
  @Trace public miniY: number = 0;
  /** 迷你条封面边长（vp）。 */
  @Trace public miniSize: number = 0;
  /** 迷你条封面圆角（vp）。 */
  @Trace public miniRadius: number = 12;

  // ─────────────────── 终点：播放页大封面（窗口坐标 vp）───────────────────

  /** 播放页大封面在窗口中的左边界（vp）。 */
  @Trace public bigX: number = 0;
  /** 播放页大封面在窗口中的上边界（vp）。 */
  @Trace public bigY: number = 0;
  /** 播放页大封面边长（vp）。 */
  @Trace public bigSize: number = 0;
  /** 播放页大封面圆角（vp）。 */
  @Trace public bigRadius: number = 12;

  // ───────────────────────── 窗口与时长 ─────────────────────────

  /** 窗口宽度（vp）：clip 窗口展开的终点。 */
  @Trace public windowWidthVp: number = 360;
  /** 窗口高度（vp）：clip 窗口展开的终点。 */
  @Trace public windowHeightVp: number = 780;
  /** 一镜到底动画时长（ms）。 */
  @Trace public durationMs: number = 460;

  /**
   * 收起请求版本号。
   *
   * 播放页的返回按钮只负责 `collapseVersion + 1`；真正的反向动画由动画宿主
   * （`PlaybackPageCoverHost`）在 `@Monitor` 里播 —— 因为只有宿主同时拥有
   * 「整页 clip」和「飞行封面」这两个需要一起动的节点。
   */
  @Trace public collapseVersion: number = 0;

  // ───────────────────────── 上报 ─────────────────────────

  /**
   * 迷你条封面上报自己在窗口中的矩形（由 `onAreaChange` 的 `globalPosition` + `width` 得来）。
   *
   * ⚠️ 用 `onAreaChange` 而不是 `getRectangleById`：后者的文档没有写单位（实测口径为 px），
   * 前者明确是 vp。动画的位移与尺寸都直接当 vp 用，单位错了会整体错位一整个密度倍。
   * @param x 左边界（vp，窗口坐标）
   * @param y 上边界（vp，窗口坐标）
   * @param size 边长（vp）
   * @param radius 圆角（vp）
   */
  public reportMini(x: number, y: number, size: number, radius: number): void {
    if (size <= 0) {
      return;
    }
    this.miniX = x;
    this.miniY = y;
    this.miniSize = size;
    this.miniRadius = radius;
  }

  /**
   * 播放页大封面上报自己在窗口中的矩形。动画宿主靠它判断「终点量到了没有」。
   * @param x 左边界（vp，窗口坐标）
   * @param y 上边界（vp，窗口坐标）
   * @param size 边长（vp）
   * @param radius 圆角（vp）
   */
  public reportBig(x: number, y: number, size: number, radius: number): void {
    if (size <= 0) {
      return;
    }
    this.bigX = x;
    this.bigY = y;
    this.bigSize = size;
    this.bigRadius = radius;
  }

  /** 记录窗口尺寸（vp），作为 clip 窗口展开的终点。 */
  public reportWindow(widthVp: number, heightVp: number): void {
    if (widthVp > 0 && heightVp > 0) {
      this.windowWidthVp = widthVp;
      this.windowHeightVp = heightVp;
    }
  }

  // ───────────────────────── 相位切换 ─────────────────────────

  /**
   * @returns 两端的封面矩形是否都量到了（可以开跑动画）。
   */
  public hasGeometry(): boolean {
    return this.miniSize > 0 && this.bigSize > 0;
  }

  /**
   * 进入 `preparing` 相位：进度归零、整页透明、清掉旧的终点矩形逼它重新上报。
   *
   * 起点（迷你条）**不清**：首页的 HDS 迷你条不会随播放页开关重新挂载，
   * 拿不到新的上报，沿用上一次的值即可（它本来就没动过）。
   */
  public armExpand(): void {
    this.progress = 0;
    this.bigSize = 0;
    this.preparing = true;
    this.animating = false;
  }

  /** 进入 `animating` 相位：飞行封面登场，迷你条封面与播放页大封面退场。 */
  public beginAnimating(): void {
    this.preparing = false;
    this.animating = true;
  }

  /** 展开动画播完：交还给静态布局。 */
  public finishAnimating(): void {
    this.animating = false;
    this.progress = 1;
  }

  /** 回到「已展开的静止态」。测量失败、宿主卸载、收起结束时都走这里。 */
  public reset(): void {
    this.preparing = false;
    this.animating = false;
    this.progress = 1;
  }

  /** 请求播放反向（收起）动画。播放页的返回按钮调用它，不要自己置 `isShowPlay`。 */
  public requestCollapse(): void {
    this.collapseVersion = this.collapseVersion + 1;
  }

  // ───────────────────────── 逐帧取值（build 里直接调）─────────────────────────

  /** @returns 当前进度下飞行封面的左边界（vp，窗口坐标）。 */
  public coverX(): number {
    return this.lerp(this.miniX, this.bigX, this.progress);
  }

  /** @returns 当前进度下飞行封面的上边界（vp，窗口坐标）。 */
  public coverY(): number {
    return this.lerp(this.miniY, this.bigY, this.progress);
  }

  /** @returns 当前进度下飞行封面的边长（vp）。 */
  public coverSize(): number {
    return this.lerp(this.miniSize, this.bigSize, this.progress);
  }

  /** @returns 当前进度下飞行封面的圆角（vp）。 */
  public coverRadius(): number {
    return this.lerp(this.miniRadius, this.bigRadius, this.progress);
  }

  /** @returns 飞行封面不透明度：只在动画期间可见。 */
  public coverOpacity(): number {
    return this.animating ? 1 : 0;
  }

  /** @returns 迷你条封面不透明度：动画期间隐藏，避免与飞行封面重影。 */
  public miniCoverOpacity(): number {
    return this.animating ? 0 : 1;
  }

  /** @returns 播放页大封面不透明度：动画期间隐藏（飞行封面顶替它）。 */
  public innerCoverOpacity(): number {
    return this.animating ? 0 : 1;
  }

  /**
   * @returns 播放页整页不透明度。
   *
   * - `preparing`：0 —— 页面已挂载但绝不能露出来（这就是防闪的那一相位）；
   * - `animating`：前 45% 淡入 —— 否则动画开头迷你条那一小块里会糊着播放页底部控件；
   * - 其余：1。
   */
  public pageOpacity(): number {
    if (this.preparing) {
      return 0;
    }
    if (!this.animating) {
      return 1;
    }
    return Math.min(1, this.progress / 0.45);
  }

  /**
   * @returns 现在是否需要给播放页套 clip 窗口。
   *
   * **静止态返回 false**，这一点很重要：此时播放页完全不裁剪，与"没有这个动画"时的
   * 布局逐字节一致 —— 万一这套 path 裁剪在某些 SDK/设备上表现异常（比如把整页裁没），
   * 影响范围也只有动画那 0.5 秒，绝不会导致"播放器打不开"。
   */
  public clipActive(): boolean {
    return this.preparing || this.animating;
  }

  /**
   * @returns clip 窗口的 SVG path 命令（单位 vp，作用在播放页宿主自己的坐标系上）。
   *
   * 静止态直接给一个远大于窗口的矩形：只要有一个尺寸算错就会把播放页裁掉一块，
   * 宁可不裁。动画期间才逐帧做圆角矩形插值。
   */
  public clipCommands(): string {
    if (this.progress >= 1) {
      return PlayerExpandState.roundedRectPath(-4000, -4000, 8000, 8000, 0);
    }
    const t: number = this.progress;
    const m: number = CLIP_IDLE_MARGIN_VP;
    const x: number = this.lerp(this.miniX, -m, t);
    const y: number = this.lerp(this.miniY, -m, t);
    const w: number = Math.max(1, this.lerp(this.miniSize, this.windowWidthVp + m * 2, t));
    const h: number = Math.max(1, this.lerp(this.miniSize, this.windowHeightVp + m * 2, t));
    return PlayerExpandState.roundedRectPath(x, y, w, h, this.coverRadius());
  }

  /** @returns 线性插值。 */
  private lerp(from: number, to: number, t: number): number {
    return from + (to - from) * t;
  }

  /**
   * 圆角矩形的 SVG path 命令。
   * @param x 左上角 x
   * @param y 左上角 y
   * @param w 宽
   * @param h 高
   * @param r 圆角（会自动夹到短边的一半以内，否则 path 自交会画歪）
   * @returns path 命令字符串
   */
  private static roundedRectPath(x: number, y: number, w: number, h: number, r: number): string {
    const x1: number = x + w;
    const y1: number = y + h;
    const safeR: number = Math.max(0, Math.min(r, Math.min(w, h) / 2));
    if (safeR <= 0.01) {
      return `M${x} ${y} H${x1} V${y1} H${x} Z`;
    }
    return `M${x + safeR} ${y} H${x1 - safeR} A${safeR} ${safeR} 0 0 1 ${x1} ${y + safeR} ` +
      `V${y1 - safeR} A${safeR} ${safeR} 0 0 1 ${x1 - safeR} ${y1} H${x + safeR} ` +
      `A${safeR} ${safeR} 0 0 1 ${x} ${y1 - safeR} V${y + safeR} A${safeR} ${safeR} 0 0 1 ${x + safeR} ${y} Z`;
  }
}
