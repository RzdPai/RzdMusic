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

/** 四边形路径的一个顶点（vp，原点在组件左上角）。 */
interface WingPoint {
  x: number;
  y: number;
}

/** path 数值格式化：保留两位小数足够，太长会让指令串变胖。 */
function fmt(v: number): string {
  return v.toFixed(2);
}

/**
 * 生成「带圆角的四边形」路径指令（SVG path，单位 vp，原点在组件左上角）。
 *
 * 圆角在这条路径里一次画完，**不要**再给节点设 `borderRadius`：侧翼是梯形，
 * 内缘那两个顶点已经不在矩形框的角上了，`borderRadius` 只能切矩形角，对斜角无效。
 *
 * @param pts 顺时针 4 个顶点。
 * @param radii 与 `pts` 一一对应的圆角半径（内部会自动限幅，防止路径自交）。
 * @returns path 指令串。
 */
function buildQuadPath(pts: WingPoint[], radii: number[]): string {
  const n: number = pts.length;
  let d: string = '';
  for (let i: number = 0; i < n; i++) {
    const prev: WingPoint = pts[(i - 1 + n) % n];
    const cur: WingPoint = pts[i];
    const next: WingPoint = pts[(i + 1) % n];
    const dlx: number = cur.x - prev.x;
    const dly: number = cur.y - prev.y;
    const drx: number = next.x - cur.x;
    const dry: number = next.y - cur.y;
    const l1: number = Math.sqrt(dlx * dlx + dly * dly);
    const l2: number = Math.sqrt(drx * drx + dry * dry);
    // 圆角不能超过相邻边长的一半，否则路径会自交、形状会翻出去
    const r: number = Math.min(radii[i], Math.min(l1, l2) * 0.48);
    if (l1 <= 0 || l2 <= 0) {
      d += (i === 0 ? 'M' : 'L') + fmt(cur.x) + ' ' + fmt(cur.y);
      continue;
    }
    if (r > 0.5) {
      const sx: number = cur.x - dlx / l1 * r;
      const sy: number = cur.y - dly / l1 * r;
      const ex: number = cur.x + drx / l2 * r;
      const ey: number = cur.y + dry / l2 * r;
      d += (i === 0 ? 'M' : 'L') + fmt(sx) + ' ' + fmt(sy);
      d += ' Q' + fmt(cur.x) + ' ' + fmt(cur.y) + ' ' + fmt(ex) + ' ' + fmt(ey);
    } else {
      d += (i === 0 ? 'M' : 'L') + fmt(cur.x) + ' ' + fmt(cur.y);
    }
  }
  return d + ' Z';
}

/**
 * 一片侧翼：**竖着的等腰梯形** —— 外侧边满高，靠近封面那侧（内缘）上下各收进 `inset`。
 *
 * ```
 *         左翼                          右翼
 *  外缘(高)     内缘(矮)        内缘(矮)     外缘(高)
 *  ┌──────────┐                  ┌──────────┐
 *  │           ╲                ╱           │
 *  │            │              │            │
 *  │            │              │            │
 *  │           ╱                ╲           │
 *  └──────────┘                  └──────────┘
 * ```
 *
 * ⚠️ 收进量加在**内缘**（靠封面那侧），不是外缘。
 *
 * ## 为什么用 `Path` 组件「画出来」而不是 `clipShape` 去裁一张图
 *
 * 前一版是「内层矩形窗口切出封面边缘的一条 → 外层 `clipShape(new PathShape(...))` 削成梯形」，
 * 结果梯形又小又贴着左上角，而且**把 `wingWidth/wingHeight` 调大完全没效果**。
 * 根因是 `PathShape` 这个新形状类**没有任何设置尺寸的 API**：
 *   - `PathShapeOptions` 只声明了 `commands`；
 *   - `CommonShapeMethod` 只声明了 `offset / fill / position`，**没有 `width` / `height`**
 *     （`width()` / `height()` 是 `RectShape` / `CircleShape` 那一支的成员，试过，编译直接报
 *      `Property 'width' does not exist on type 'PathShape'`）。
 * 也就是说 `PathShape` 的 viewport 由框架自己定，我们改不了组件盒也改不了它 —— 不可控。
 *
 * 换成 `Path` 组件之后一切都确定了：`Path({ width, height, commands })` 的
 * `width/height` 就是画布尺寸，`commands` 里的 `0..w / 0..h` 就是这块画布的坐标，
 * 1:1 映射，改尺寸立刻生效。
 *
 * 顺带一提：参考图里那两条侧翼**本来也不是封面的模糊切片**，逐像素量下来是一层
 * 均匀的半透明提亮（约 4.6% 白），所以这里用纯色填充反而更接近参考图。
 */
@ComponentV2
export struct CoverWing {
  /** True = 左翼（外缘在左），false = 右翼（外缘在右）。 */
  @Param isStart: boolean = true;
  /** 侧翼宽度（vp）。 */
  @Param wingWidth: number = 34;
  /** 外缘高度（vp），也是画布高度。 */
  @Param wingHeight: number = 210;
  /** 内缘上端收进量（vp）。与 `insetBottom` 相等时是等腰梯形。 */
  @Param insetTop: number = 21;
  /** 内缘下端收进量（vp）。 */
  @Param insetBottom: number = 21;
  /** 整体纵向微调（vp）：想让两片错开时用。 */
  @Param offsetY: number = 0;
  /** 外缘圆角（vp，大）。 */
  @Param outerRadius: number = 20;
  /** 内缘圆角（vp，小）。 */
  @Param innerRadius: number = 6;
  /** 填充色（`#AARRGGBB`）。由调用方按卡片底色算对比色传进来。 */
  @Param fill: string = '#33FFFFFF';

  /**
   * @returns 等腰梯形路径：外缘满高（0→h），内缘收进（insetTop→h−insetBottom）。
   *
   * ⚠️ **坐标必须换算成 px**，这是这个组件唯一容易踩死的坑。
   *
   * 官方文档对 `Path` 组件的 `commands` 写得很明确：
   *   「路径绘制的命令字符串，符合 SVG 路径描述规范，**单位为 px**」
   *   （`ts-drawing-components-path`）
   * 而组件的 `.width()/.height()` 是 vp。之前把 **vp 数值直接写进 commands**，
   * 在 3 倍密度的手机上实际画出来只有三分之一大、还贴着盒子左上角 ——
   * 这就是"侧翼又小又偏左上、而且怎么改 wingWidth/wingHeight 都没反应"的根因。
   * 这里统一走 `vp2px()`，path 坐标与组件盒才是 1:1。
   */
  private buildCommands(): string {
    const ui = this.getUIContext();
    const w: number = ui.vp2px(this.wingWidth);
    const h: number = ui.vp2px(this.wingHeight);
    const it: number = ui.vp2px(this.insetTop);
    const ib: number = ui.vp2px(this.insetBottom);
    const ro: number = ui.vp2px(this.outerRadius);
    const ri: number = ui.vp2px(this.innerRadius);
    if (this.isStart) {
      // 左翼：外缘在左(x=0, 0→h)，内缘在右(x=w, it→h−ib)
      const pts: WingPoint[] = [
        { x: 0, y: 0 },
        { x: w, y: it },
        { x: w, y: h - ib },
        { x: 0, y: h }
      ];
      return buildQuadPath(pts, [ro, ri, ri, ro]);
    }
    // 右翼：外缘在右(x=w, 0→h)，内缘在左(x=0, it→h−ib)
    const pts: WingPoint[] = [
      { x: w, y: 0 },
      { x: 0, y: it },
      { x: 0, y: h - ib },
      { x: w, y: h }
    ];
    return buildQuadPath(pts, [ro, ri, ri, ro]);
  }

  build() {
    Path({ width: this.wingWidth, height: this.wingHeight, commands: this.buildCommands() })
      .width(this.wingWidth)
      .height(this.wingHeight)
      .fill(this.fill)
      // 形状组件默认带 1px 黑色描边（用户看到的"多了一圈黑边"就是它），显式关掉
      .stroke(Color.Transparent)
      .strokeWidth(0)
      .offset({ y: this.offsetY })
  }
}
