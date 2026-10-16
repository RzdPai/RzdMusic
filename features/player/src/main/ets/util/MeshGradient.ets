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
 * 网格形变场（`MeshField`）—— **照搬自无界音乐 1.2.4 的 `design/logic/MeshGradient.ets`**。
 *
 * 播放页背景「网格流动」的全部算法都在这里：9×9 控制点 → 每格 4×4 双三次 Hermite 细分
 * → 33×33 个像素顶点，交给 `drawPixelMapMesh` 画。
 *
 * 来源与依据：`_recover/logic-src/播放页背景-MeshGradient与MeshSource定稿.md` §2
 * （字节码级逐条解出，行号为 `wujie.pa` 绝对行号）。**本模块零外部依赖**
 * （`@ohos.*` 一个都没用到）⇒ 整文件搬过来即可。
 *
 * ⚠️ 三处**照抄时不能"顺手改"**的地方（原定稿 §2 明确标了）：
 * 1. `vertices` 是**普通 `Array`**（长度 2178），不是 `Float32Array`
 *    —— `drawPixelMapMesh` 要的就是 `Array<number>`；
 * 2. `build()` 里**最后一格要多走一步**（`uSteps/vSteps` 用 `sub` 而不是 `sub - 1`），
 *    否则只出 32 个采样位置、与 `vertCount = meshW + 1 = 33` 对不上；
 * 3. `orbit[o8+0]/[o8+1]`（位置幅度）**乘了 `r`**，而 `orbit[o8+4]/[o8+6]`
 *    （切线角幅度）**不乘 `r`** —— 两处必须区分。
 */

/** 控制点网格列数（`wujie.pa` L90969-90974）。 */
export const CP_W: number = 9;
/** 控制点网格行数。 */
export const CP_H: number = 9;
/** 控制点间距（归一化，`2 / (CP_W - 1)` = 0.25）。 */
const CP_STEP_X: number = 2 / (CP_W - 1);
const CP_STEP_Y: number = 2 / (CP_H - 1);
/** 正弦周期区间（秒）：81 个控制点各自取不同周期 ⇒ 永不整体同步。 */
const PERIOD_MIN: number = 4;
const PERIOD_MAX: number = 11;
/** 位置摆动半径：内点 / 边框（`CP_STEP × 0.45` / `× 0.27`）。 */
const ORBIT_R_INNER: number = CP_STEP_X * 0.45;
const ORBIT_R_BORDER: number = CP_STEP_X * 0.27;

/** 一个控制点。`x/y` 是**归一化位置**（−1..1），`ur/vr` 是**切线角偏置（度）**，`up/vp` 是切线幅度倍率。 */
export interface MeshCP {
  cx: number;
  cy: number;
  x: number;
  y: number;
  ur: number;
  vr: number;
  up: number;
  vp: number;
}

/**
 * 构造一个控制点（`wujie.pa` L88032-88083）。
 * 默认值与原实现一致：`ur = vr = 0`、`up = vp = 1`。
 */
export function cp(cx: number, cy: number, x: number, y: number,
                   ur: number = 0, vr: number = 0,
                   up: number = 1, vp: number = 1): MeshCP {
  const out: MeshCP = { cx: cx, cy: cy, x: x, y: y, ur: ur, vr: vr, up: up, vp: vp };
  return out;
}

/**
 * 「完全平坦的 9×9 规则网格，切线幅度 1、角偏置 0」（`wujie.pa` L88088-88157）。
 * ⚠️ 原实现的入参**被完全忽略**（函数体里 `a3` 出现 0 次）—— 这里保留形参以对齐签名。
 */
export function defaultConf(_seed: number): MeshCP[] {
  const out: MeshCP[] = [];
  for (let row = 0; row < CP_H; row++) {
    for (let col = 0; col < CP_W; col++) {
      out.push(cp(col, row, 2 * (col / (CP_W - 1)) - 1, 2 * (row / (CP_H - 1)) - 1));
    }
  }
  return out;
}

/** 3D 空间哈希（73856093 / 19349663 / 83492791 = 经典 Teschner 三元组）+ xorshift 收尾 → [0,1)。 */
function hash01(a: number, b: number, c: number): number {
  let h: number = (a * 0x466f45d) ^ (b * 0x127409f) ^ (c * 0x4f9ffb7);
  h = h | 0;
  h ^= h << 13;
  h = h | 0;
  // ⚠️ shr2 是逻辑右移 `>>>`（原定稿 §2.3 给了三条旁证），**不是** `>>`
  h ^= h >>> 17;
  h = h | 0;
  h ^= h << 5;
  h = h | 0;
  h = h >>> 0;
  return (h % 1000003) / 1000003;
}

/** `lo + (hi − lo) × hash01(a, b, c)`。 */
function hashRange(a: number, b: number, c: number, lo: number, hi: number): number {
  return lo + (hi - lo) * hash01(a, b, c);
}

/** GLSL 经典 sin-hash：`fract(sin(x·12.9898 + y·78.233) · 43758.55)`。 */
function vnoise(x: number, y: number): number {
  const s: number = Math.sin(x * 12.9898 + y * 78.233);
  const v: number = s * 43758.55;
  return v - Math.floor(v);
}

/** 值噪声：4 角 sin-hash + smoothstep 双线性插值。 */
function snoise(x: number, y: number): number {
  const x0: number = Math.floor(x);
  const y0: number = Math.floor(y);
  const fx: number = x - x0;
  const fy: number = y - y0;
  const sx: number = fx * fx * (3 - 2 * fx);
  const sy: number = fy * fy * (3 - 2 * fy);
  const n00: number = vnoise(x0, y0);
  const n10: number = vnoise(x0 + 1, y0);
  const n01: number = vnoise(x0, y0 + 1);
  const n11: number = vnoise(x0 + 1, y0 + 1);
  const top: number = n00 * (1 - sx) + n10 * sx;
  const bottom: number = n01 * (1 - sx) + n11 * sx;
  return top * (1 - sy) + bottom * sy;
}

/**
 * 三次 Hermite 基函数，写进 `out[off … off+3]`（**不返回**）。
 * 顺序：`[h00, h10, h01, h11] = [2t³−3t²+1, −2t³+3t², t³−2t²+t, t³−t²]`。
 */
function hermiteBasis(t: number, out: Float64Array, off: number): void {
  const t2: number = t * t;
  const t3: number = t2 * t;
  out[off + 0] = 2 * t3 - 3 * t2 + 1;
  out[off + 1] = -2 * t3 + 3 * t2;
  out[off + 2] = t3 - 2 * t2 + t;
  out[off + 3] = t3 - t2;
}

/**
 * 9×9 加权平滑（3×3 核 `[1,2,1; 2,4,2; 1,2,1]`，权重和 16）：
 * `out = (1−k)·旧 + k·(核平均)`，**就地写回入参数组**，跑 `iter` 轮。边框点原样拷贝。
 */
function smoothConf(conf: MeshCP[], iter: number, k: number): void {
  const K: number[] = [1, 2, 1, 2, 4, 2, 1, 2, 1];
  for (let it = 0; it < iter; it++) {
    const out: MeshCP[] = [];
    for (let row = 0; row < CP_H; row++) {
      for (let col = 0; col < CP_W; col++) {
        const c: MeshCP = conf[row * CP_W + col];
        if (col === 0 || col === CP_W - 1 || row === 0 || row === CP_H - 1) {
          out.push(c);
          continue;
        }
        let sx: number = 0;
        let sy: number = 0;
        let sur: number = 0;
        let svr: number = 0;
        let sup: number = 0;
        let svp: number = 0;
        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            const w: number = K[(dy + 1) * 3 + (dx + 1)];
            const n: MeshCP = conf[(row + dy) * CP_W + (col + dx)];
            sx += w * n.x;
            sy += w * n.y;
            sur += w * n.ur;
            svr += w * n.vr;
            sup += w * n.up;
            svp += w * n.vp;
          }
        }
        out.push(cp(col, row,
          (1 - k) * c.x + k * (sx / 16),
          (1 - k) * c.y + k * (sy / 16),
          (1 - k) * c.ur + k * (sur / 16),
          (1 - k) * c.vr + k * (svr / 16),
          (1 - k) * c.up + k * (sup / 16),
          (1 - k) * c.vp + k * (svp / 16)));
      }
    }
    for (let i = 0; i < conf.length; i++) {
      conf[i] = out[i];
    }
  }
}

/**
 * 由数值种子生成 81 个控制点（`wujie.pa` L88162-88572）。
 *
 * 手法：内点先用噪声梯度沿**等值线法向**推开（越靠中心推得越狠），
 * 再给切线角 ±60° 偏置、切线幅度 [0.8,1.2) 倍率，最后做 **3 轮** `k=0.25` 的 9×9 平滑。
 */
export function generateConf(seed: number): MeshCP[] {
  const ROT_BASE: number = hashRange(0, 0, seed + 1, 0.4, 0.6);
  const STEP: number = CP_STEP_X * hashRange(0, 0, seed + 2, 0.6, 1.2);

  const out: MeshCP[] = [];
  for (let row = 0; row < CP_H; row++) {
    for (let col = 0; col < CP_W; col++) {
      const u01: number = 2 * (col / (CP_W - 1)) - 1;
      const v01: number = 2 * (row / (CP_H - 1)) - 1;

      if (col === 0 || col === CP_W - 1 || row === 0 || row === CP_H - 1) {
        out.push(cp(col, row, u01, v01));
        continue;
      }

      const phaseU: number = hashRange(col, row, seed + 3, -ROT_BASE, ROT_BASE);
      const phaseV: number = hashRange(col, row, seed + 4, -ROT_BASE, ROT_BASE);
      let x: number = u01 + CP_STEP_X * phaseU;
      let y: number = v01 + CP_STEP_Y * phaseV;

      const u: number = (u01 + 1) / 2;
      const v: number = (v01 + 1) / 2;
      const E: number = 1e-3;
      const dsdu: number = (snoise(u + E, v) - snoise(u - E, v)) / (2 * E);
      const dsdv: number = (snoise(u, v + E) - snoise(u, v - E)) / (2 * E);
      const g: number = Math.sqrt(dsdu * dsdu + dsdv * dsdv);
      const inv: number = g > 0 ? 1 / g : 1;
      const d: number = Math.min(Math.min(u, 1 - u), Math.min(v, 1 - v));
      const e: number = d * d * (3 - 2 * d);
      x += e * (inv * dsdu) * STEP;
      y += e * (inv * dsdv) * STEP;

      out.push(cp(col, row, x, y,
        hashRange(col, row, seed + 5, -60, 60),
        hashRange(col, row, seed + 6, -60, 60),
        hashRange(col, row, seed + 7, 0.8, 1.2),
        hashRange(col, row, seed + 8, 0.8, 1.2)));
    }
  }
  smoothConf(out, 3, 0.25);
  return out;
}

/**
 * 网格形变场：把封面铺成一张会"呼吸/流动"的网格（照搬无界 `MeshField`）。
 *
 * 用法（与无界组件侧一致）：
 * ```ts
 * const field = new MeshField(4);
 * field.reseed(seed);                    // 换歌时一次
 * // 每帧：
 * field.update(tSec, wPx, hPx, 1);       // tSec 单位秒；flow = 形变幅度 0..1
 * canvas.drawPixelMapMesh(src, field.meshW, field.meshH, field.vertices, 0, null, 0);
 * ```
 */
export class MeshField {
  /** 每格细分数（无界传 `MESH_SUB = 4`）。 */
  sub: number;
  /** 网格**格数**（不是顶点数）= `(CP_W - 1) × sub` = 32。 */
  meshW: number;
  meshH: number;
  /** 顶点数 = `(meshW + 1) × (meshH + 1)` = 33 × 33 = 1089。 */
  vertCount: number;

  /** ⚠️ **普通 Array**（长度 `vertCount × 2` = 2178）—— `drawPixelMapMesh` 要的就是它。 */
  vertices: number[];
  /** 每控制点 6 个基准量：`x, y, ur(弧度), U 切线幅度, vr(弧度), V 切线幅度`。 */
  base: Float64Array;
  /** 每控制点 4 个切向量分量。 */
  tan: Float64Array;
  /** 每控制点 2 个当前位置。 */
  loc: Float64Array;
  /** 每控制点 8 个轨道参数：位置幅度 x/y、位置角速度、位置初相位、U 角幅度/角速度、V 角幅度/角速度。 */
  orbit: Float64Array;
  /** Hermite 基函数在 `t = 0, 1/sub, …, 1` 处的值（`(sub + 1) × 4`）。 */
  basis: Float64Array;

  constructor(sub: number) {
    this.sub = sub;
    this.meshW = (CP_W - 1) * sub;
    this.meshH = (CP_H - 1) * sub;
    this.vertCount = (this.meshW + 1) * (this.meshH + 1);
    this.vertices = new Array<number>(this.vertCount * 2).fill(0);
    this.base = new Float64Array(CP_W * CP_H * 6);
    this.tan = new Float64Array(CP_W * CP_H * 4);
    this.loc = new Float64Array(CP_W * CP_H * 2);
    this.orbit = new Float64Array(CP_W * CP_H * 8);
    this.basis = new Float64Array((sub + 1) * 4);
    for (let i = 0; i <= sub; i++) {
      hermiteBasis(i / sub, this.basis, 4 * i);
    }
    this.reseed(0);
  }

  /** 顶点下标（未 ×2 前的"顶点序号"）。 */
  vertexIndex(i: number, j: number): number {
    return (j * (this.meshW + 1) + i) * 2;
  }

  /**
   * ★ 注意：**它改的是网格几何，不是配色**。
   * `hue` 只当**数值种子**：重算 81 个控制点 → 重算轨道 → 再钉一次边框。
   */
  reseed(hue: number): void {
    const seed: number = Math.floor(Math.abs(hue));
    this.applyConf(generateConf(seed));
    this.initOrbits(seed);
    this.applyBorderRules();
  }

  applyConf(conf: MeshCP[]): void {
    this.loadConf(conf);
    this.applyBorderRules();
  }

  /** 先用"完全平坦的规则网格"铺底，再用 `conf` 逐格覆盖（`ur/vr` 是**度**，这里转弧度）。 */
  loadConf(conf: MeshCP[]): void {
    for (let row = 0; row < CP_H; row++) {
      for (let col = 0; col < CP_W; col++) {
        const i6: number = (row * CP_W + col) * 6;
        this.base[i6 + 0] = 2 * (col / (CP_W - 1)) - 1;
        this.base[i6 + 1] = 2 * (row / (CP_H - 1)) - 1;
        this.base[i6 + 2] = 0;
        this.base[i6 + 3] = CP_STEP_X;
        this.base[i6 + 4] = 0;
        this.base[i6 + 5] = CP_STEP_Y;
      }
    }
    for (let k = 0; k < conf.length; k++) {
      const c: MeshCP = conf[k];
      if (c.cx < 0 || c.cx >= CP_W || c.cy < 0 || c.cy >= CP_H) {
        continue;
      }
      const i6: number = (c.cy * CP_W + c.cx) * 6;
      this.base[i6 + 0] = c.x;
      this.base[i6 + 1] = c.y;
      this.base[i6 + 2] = (c.ur * Math.PI) / 180;
      this.base[i6 + 4] = (c.vr * Math.PI) / 180;
      this.base[i6 + 3] = CP_STEP_X * c.up;
      this.base[i6 + 5] = CP_STEP_Y * c.vp;
    }
  }

  /** 81×8 个轨道参数（幅度 / 角速度 / 初相位）。周期 ∈ [4,11] 秒 ⇒ 各点永远不同步。 */
  initOrbits(seed: number): void {
    const PI2: number = Math.PI * 2;
    for (let row = 0; row < CP_H; row++) {
      for (let col = 0; col < CP_W; col++) {
        const o8: number = (row * CP_W + col) * 8;
        const isBorder: boolean = col === 0 || col === CP_W - 1 || row === 0 || row === CP_H - 1;
        const r: number = isBorder ? ORBIT_R_BORDER : ORBIT_R_INNER;
        // ⚠️ 位置幅度**乘 r**
        this.orbit[o8 + 0] = r * hashRange(col, row, seed + 11, 0.6, 1.0);
        this.orbit[o8 + 1] = r * hashRange(col, row, seed + 12, 0.6, 1.0);
        this.orbit[o8 + 2] = PI2 / hashRange(col, row, seed + 13, PERIOD_MIN, PERIOD_MAX);
        this.orbit[o8 + 3] = hashRange(col, row, seed + 14, 0, PI2);
        // ⚠️ 切线角幅度**不乘 r**（原实现里 `r` 没被乘进来）
        this.orbit[o8 + 4] = 0.3 * hashRange(col, row, seed + 15, 0.5, 1.0);
        this.orbit[o8 + 5] = PI2 / hashRange(col, row, seed + 16, PERIOD_MIN, PERIOD_MAX);
        this.orbit[o8 + 6] = 0.3 * hashRange(col, row, seed + 17, 0.5, 1.0);
        this.orbit[o8 + 7] = PI2 / hashRange(col, row, seed + 18, PERIOD_MIN, PERIOD_MAX);
      }
    }
  }

  /**
   * 把最外圈控制点钉死在归一化方框 `[−1,1]²` 上，并杀掉它们两个方向的摆动
   * ⇒ **无论网格怎么变形，画面四边永远铺满、不露空白**。整个效果唯一的"安全阀"。
   * ⚠️ 对 `initOrbits` 的结果**必须重跑一次**（它刚把 `orbit` 写满）。
   */
  applyBorderRules(): void {
    for (let row = 0; row < CP_H; row++) {
      for (let col = 0; col < CP_W; col++) {
        const i6: number = (row * CP_W + col) * 6;
        const o8: number = (row * CP_W + col) * 8;
        if (row === 0 || row === CP_H - 1) {
          this.base[i6 + 1] = (row === 0) ? -1 : 1;
          this.base[i6 + 2] = 0;
          this.orbit[o8 + 1] = 0;
          this.orbit[o8 + 4] = 0;
        }
        if (col === 0 || col === CP_W - 1) {
          this.base[i6 + 0] = (col === 0) ? -1 : 1;
          this.base[i6 + 4] = 0;
          this.orbit[o8 + 0] = 0;
          this.orbit[o8 + 6] = 0;
        }
      }
    }
  }

  /**
   * 「呼吸/流动」的唯一来源：每控制点 **3 条独立正弦**。
   * - 位置：`ph1 = orbit[+3] + orbit[+2]·t`，x 用 `cos`、y 用 `sin`；
   * - U 切线角：`sin(orbit[+3] + orbit[+5]·t)`；
   * - V 切线角：`sin(orbit[+7]·t − orbit[+3])` ← **减号**就是"反向流动"的来源。
   * `amp` 是纯幅度；`t` 单位**秒**。
   */
  animate(t: number, amp: number): void {
    const n: number = CP_W * CP_H;
    for (let i = 0; i < n; i++) {
      const o8: number = i * 8;
      const b6: number = i * 6;

      const ph1: number = this.orbit[o8 + 3] + this.orbit[o8 + 2] * t;
      this.loc[i * 2 + 0] = this.base[b6 + 0] + Math.cos(ph1) * this.orbit[o8 + 0] * amp;
      this.loc[i * 2 + 1] = this.base[b6 + 1] + Math.sin(ph1) * this.orbit[o8 + 1] * amp;

      const angU: number = this.base[b6 + 2]
        + Math.sin(this.orbit[o8 + 3] + this.orbit[o8 + 5] * t) * this.orbit[o8 + 4] * amp;
      const angV: number = this.base[b6 + 4]
        + Math.sin(this.orbit[o8 + 7] * t - this.orbit[o8 + 3]) * this.orbit[o8 + 6] * amp;

      const magU: number = this.base[b6 + 3];
      const magV: number = this.base[b6 + 5];
      this.tan[i * 4 + 0] = magU * Math.cos(angU);
      this.tan[i * 4 + 1] = magU * Math.sin(angU);
      this.tan[i * 4 + 2] = -magV * Math.sin(angV);
      this.tan[i * 4 + 3] = magV * Math.cos(angV);
    }
  }

  /**
   * 双三次 Hermite 求值（先 U 后 V），把归一化 `[−1,1]²` 映射成**画布像素坐标**：
   * `vertices[k] = (x + 1) × 0.5 × w`。
   *
   * ⚠️ **最后一格必须走 `sub` 步**（原始实现刻意如此）：8 格 × 4 步 + 收尾 = 33 个采样位置，
   * 与 `meshW + 1 = 33` 自洽。写成"每格都走 `sub - 1` 步"会少一个位置、顶点数对不上。
   */
  build(w: number, h: number): void {
    const sub: number = this.sub;
    const B: Float64Array = this.basis;
    const V: number[] = this.vertices;
    const rowStride: number = (this.meshW + 1) * 2;
    const halfW: number = 0.5 * w;
    const halfH: number = 0.5 * h;

    for (let cy = 0; cy < CP_H - 1; cy++) {
      const vSteps: number = (cy === CP_H - 2) ? sub : sub - 1;
      for (let cx = 0; cx < CP_W - 1; cx++) {
        const uSteps: number = (cx === CP_W - 2) ? sub : sub - 1;

        const p00: number = cy * CP_W + cx;
        const p10: number = p00 + 1;
        const p01: number = p00 + CP_W;
        const p11: number = p01 + 1;

        const lx00: number = this.loc[p00 * 2];
        const ly00: number = this.loc[p00 * 2 + 1];
        const lx10: number = this.loc[p10 * 2];
        const ly10: number = this.loc[p10 * 2 + 1];
        const lx01: number = this.loc[p01 * 2];
        const ly01: number = this.loc[p01 * 2 + 1];
        const lx11: number = this.loc[p11 * 2];
        const ly11: number = this.loc[p11 * 2 + 1];

        for (let i = 0; i <= uSteps; i++) {
          const h00: number = B[i * 4 + 0];
          const h10: number = B[i * 4 + 1];
          const h01: number = B[i * 4 + 2];
          const h11: number = B[i * 4 + 3];

          const r0x: number = h00 * lx00 + h10 * lx10 + h01 * this.tan[p00 * 4 + 0] + h11 * this.tan[p10 * 4 + 0];
          const r1x: number = h00 * lx01 + h10 * lx11 + h01 * this.tan[p01 * 4 + 0] + h11 * this.tan[p11 * 4 + 0];
          const v0x: number = h00 * this.tan[p00 * 4 + 2] + h10 * this.tan[p10 * 4 + 2];
          const v1x: number = h00 * this.tan[p01 * 4 + 2] + h10 * this.tan[p11 * 4 + 2];
          const r0y: number = h00 * ly00 + h10 * ly10 + h01 * this.tan[p00 * 4 + 1] + h11 * this.tan[p10 * 4 + 1];
          const r1y: number = h00 * ly01 + h10 * ly11 + h01 * this.tan[p01 * 4 + 1] + h11 * this.tan[p11 * 4 + 1];
          const v0y: number = h00 * this.tan[p00 * 4 + 3] + h10 * this.tan[p10 * 4 + 3];
          const v1y: number = h00 * this.tan[p01 * 4 + 3] + h10 * this.tan[p11 * 4 + 3];

          const uIdx: number = cx * sub + i;
          for (let j = 0; j <= vSteps; j++) {
            const g00: number = B[j * 4 + 0];
            const g10: number = B[j * 4 + 1];
            const g01: number = B[j * 4 + 2];
            const g11: number = B[j * 4 + 3];
            const nx: number = g00 * r0x + g10 * r1x + g01 * v0x + g11 * v1x;
            const ny: number = g00 * r0y + g10 * r1y + g01 * v0y + g11 * v1y;

            const vIdx: number = cy * sub + j;
            const k: number = vIdx * rowStride + 2 * uIdx;
            V[k] = (nx + 1) * halfW;
            V[k + 1] = (ny + 1) * halfH;
          }
        }
      }
    }
  }

  /** 每帧入口：`animate(tSec, clamp01(flow))` + `build(w, h)`。`flow` = 形变幅度 0..1。 */
  update(tSec: number, w: number, h: number, flow: number): void {
    const amp: number = flow < 0 ? 0 : (flow > 1 ? 1 : flow);
    this.animate(tSec, amp);
    this.build(w, h);
  }
}
