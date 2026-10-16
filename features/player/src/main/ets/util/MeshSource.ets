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
 * 网格背景的**取图流水线** —— **照搬自无界音乐 1.2.4 的 `design/logic/MeshSource.ets`**。
 *
 * 序列（与无界组件侧一致）：
 * ```
 * 封面 PixelMap（解到 SRC_EDGE × SRC_EDGE）
 *   ├─ 真封面：enhanceColors(u8)                    ← 「低对比 / 高饱和 / 偏暗」，当背景不抢前景
 *   └─ 解不出：fillFallback(u8, E, E, hueOfSeed(seed))  ← 四角 HSL 双线性渐变兜底
 *   └─ 统一 boxBlurRgba(u8, E, E, 9, 3)             ← 盒式模糊，无 gamma
 * ```
 *
 * 来源与依据：`_recover/logic-src/播放页背景-MeshGradient与MeshSource定稿.md` §3
 * （字节码级逐条解出）。**本模块零外部依赖**。
 *
 * ⚠️ **别把这里的常量与 `CoverStrip` 那套混用**：那边是 `radius=10 / passes=2`，
 * 且 `BLUR_CURVE_GAMMA=0.5` 是 `CoverStrip` 自己的**外部混合式**，与 `boxBlurRgba` 无关
 * （`boxBlurRgba` 里**完全没有 gamma**）。
 */

/** 背景源图边长（`MeshSource.func_main_0` L91973 `ldai 0x40` → `stmodulevar 0x0`）。 */
export const SRC_EDGE: number = 64;

/** 夹到 `[0,255]`。**不取整**（调用方自己 `Math.round`）。 */
function clamp255(x: number): number {
  if (x < 0) {
    return 0;
  }
  if (x > 255) {
    return 255;
  }
  return x;
}

/**
 * 把字符串种子折成一个**色相角**（度）—— Java `String.hashCode()` 后 `% 360`。
 * 返回值恒在 `[0, 360)`；空串 ⇒ `0`。
 */
export function hueOfSeed(seed: string): number {
  let h: number = 0;
  for (let i = 0; i < seed.length; i++) {
    h = h * 31;
    h = h + seed.charCodeAt(i);
    h = h | 0;
  }
  return ((h % 360) + 360) % 360;
}

/** 标准 HSL→RGB，写进 `out[off … off+3]`（α 恒 255）。`h` 先归一到 `[0,360)` 再 /60 ⇒ `H ∈ [0,6)`。 */
function hslToRgb(h: number, s: number, l: number, out: Uint8Array, off: number): void {
  const H: number = (((h % 360) + 360) % 360) / 60;
  const C: number = s * (1 - Math.abs(2 * l - 1));
  const X: number = C * (1 - Math.abs((H % 2) - 1));
  const m: number = l - C / 2;
  let r: number = 0;
  let g: number = 0;
  let b: number = 0;
  if (H < 1) {
    r = C; g = X; b = 0;
  } else if (H < 2) {
    r = X; g = C; b = 0;
  } else if (H < 3) {
    r = 0; g = C; b = X;
  } else if (H < 4) {
    r = 0; g = X; b = C;
  } else if (H < 5) {
    r = X; g = 0; b = C;
  } else {
    r = C; g = 0; b = X;
  }
  out[off + 0] = clamp255(Math.round((r + m) * 255));
  out[off + 1] = clamp255(Math.round((g + m) * 255));
  out[off + 2] = clamp255(Math.round((b + m) * 255));
  out[off + 3] = 255;
}

/**
 * 解不出封面时的兜底：往 `u8` 里填一张**四角 HSL 双线性渐变**（α 恒 255，**轴对齐不旋转**）。
 *
 * 四角 `(相对 hue 的偏角, S, L)`：
 * `(0, .60, .40)` / `(+28, .55, .52)` / `(−20, .68, .33)` / `(+46, .50, .46)`。
 */
export function fillFallback(u8: Uint8Array, w: number, h: number, hue: number): void {
  const pal: Uint8Array = new Uint8Array(16);
  hslToRgb(hue, 0.60, 0.40, pal, 0);
  hslToRgb(hue + 28, 0.55, 0.52, pal, 4);
  hslToRgb(hue - 20, 0.68, 0.33, pal, 8);
  hslToRgb(hue + 46, 0.50, 0.46, pal, 12);

  for (let y = 0; y < h; y++) {
    const fy: number = h > 1 ? y / (h - 1) : 0;
    for (let x = 0; x < w; x++) {
      const fx: number = w > 1 ? x / (w - 1) : 0;
      const off: number = (y * w + x) * 4;
      for (let c = 0; c < 3; c++) {
        const top: number = pal[0 + c] * (1 - fx) + pal[4 + c] * fx;
        const bottom: number = pal[8 + c] * (1 - fx) + pal[12 + c] * fx;
        u8[off + c] = clamp255(Math.round(top * (1 - fy) + bottom * fy));
      }
      u8[off + 3] = 255;
    }
  }
}

/**
 * 把封面像素"做成背景"：**低对比、高饱和、偏暗**（α 不动，无 LUT、无 gamma）。
 *
 * 四步（顺序不能换）：① 对比 ×0.4 向 128 收 → ② 饱和度 ×5（绕 Rec.601 亮度 `0.3/0.59/0.11`）
 * → ③ 对比 ×0.9 → ④ 增益 ×0.75。
 * ⚠️ `0.4` 与 `×5` 是**配套的一对**（单独改一个会过曝或发灰）。
 */
export function enhanceColors(u8: Uint8Array): void {
  const MID: number = 128;
  for (let i = 0; i < u8.length; i += 4) {
    let r: number = u8[i];
    let g: number = u8[i + 1];
    let b: number = u8[i + 2];

    r = MID + (r - MID) * 0.4;
    g = MID + (g - MID) * 0.4;
    b = MID + (b - MID) * 0.4;

    const luma: number = 0.3 * r + 0.59 * g + 0.11 * b;
    const k: number = 1 - 5;
    r = 5 * r + k * luma;
    g = 5 * g + k * luma;
    b = 5 * b + k * luma;

    r = MID + (r - MID) * 0.9;
    g = MID + (g - MID) * 0.9;
    b = MID + (b - MID) * 0.9;

    u8[i] = clamp255(Math.round(0.75 * r));
    u8[i + 1] = clamp255(Math.round(0.75 * g));
    u8[i + 2] = clamp255(Math.round(0.75 * b));
  }
}

/**
 * 盒式模糊（全包通用：`CoverStrip` 也用它）。
 *
 * - **半原地**：H 趟 `u8 → tmp`（α 原文拷贝），V 趟 `tmp → u8`（只写 RGB）；`tmp` 只分配一次、`passes` 轮复用；
 * - **通道独立**，**α 全程不被模糊**；
 * - 边界 **clamp（边缘复制）**；
 * - 除数 `K = 2·radius + 1`，**每趟都除**；
 * - `radius < 1` 或 `passes < 1` ⇒ 直接返回，不动 `u8`；**无 gamma**。
 */
export function boxBlurRgba(u8: Uint8Array, w: number, h: number, radius: number, passes: number): void {
  if (radius < 1 || passes < 1) {
    return;
  }
  const K: number = radius * 2 + 1;
  const tmp: Uint8Array = new Uint8Array(u8.length);

  for (let p = 0; p < passes; p++) {
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        let sr: number = 0;
        let sg: number = 0;
        let sb: number = 0;
        for (let dx = -radius; dx <= radius; dx++) {
          let sx: number = x + dx;
          if (sx < 0) {
            sx = 0;
          } else if (sx >= w) {
            sx = w - 1;
          }
          const o: number = (y * w + sx) * 4;
          sr += u8[o];
          sg += u8[o + 1];
          sb += u8[o + 2];
        }
        const d: number = (y * w + x) * 4;
        tmp[d] = Math.round(sr / K);
        tmp[d + 1] = Math.round(sg / K);
        tmp[d + 2] = Math.round(sb / K);
        tmp[d + 3] = u8[d + 3];
      }
    }
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        let sr: number = 0;
        let sg: number = 0;
        let sb: number = 0;
        for (let dy = -radius; dy <= radius; dy++) {
          let sy: number = y + dy;
          if (sy < 0) {
            sy = 0;
          } else if (sy >= h) {
            sy = h - 1;
          }
          const o: number = (sy * w + x) * 4;
          sr += tmp[o];
          sg += tmp[o + 1];
          sb += tmp[o + 2];
        }
        const d: number = (y * w + x) * 4;
        u8[d] = Math.round(sr / K);
        u8[d + 1] = Math.round(sg / K);
        u8[d + 2] = Math.round(sb / K);
      }
    }
  }
}
