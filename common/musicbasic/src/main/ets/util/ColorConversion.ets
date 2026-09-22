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

/** Adjusts RGB samples for themed background extraction (saturation / brightness remap). */
export class ColorConversion {
  /**
   * Maps input RGB to a tuned RGB triple for UI background tinting.
   *
   * @param rRGB Red channel 0–255.
   * @param gRGB Green channel 0–255.
   * @param bRGB Blue channel 0–255.
   * @returns Tuple [r, g, b] each 0–255 after processing.
   */
  public static dealColor(rRGB: number, gRGB: number, bRGB: number ) {
    let max = Math.max(Math.max(rRGB, gRGB), bRGB);
    let min = Math.min(Math.min(rRGB, gRGB), bRGB);
    
    if (max - min < 1e-3) {
      const v = Math.max(0, Math.min(255, Math.floor(max)));
      return [v, v, v];
    }
    let sHSB = max === 0 ? 0 : (max - min) / max;
    let bHSB = max /255;
    let hHSB = 0;
    if (max === rRGB && gRGB >= bRGB) {
      hHSB = 60 * (gRGB - bRGB) / (max - min) + 0;
    }
    if (max === rRGB && gRGB < bRGB) {
      hHSB = 60 * (gRGB - bRGB) / (max - min) + 360;
    }
    if (max === gRGB) {
      hHSB = 60 * (bRGB - rRGB) / (max - min) + 120;
    }
    if (max === bRGB) {
      hHSB = 60 * (rRGB - gRGB) / (max - min) + 240;
    }

    if (bHSB >= 0.4) {
      bHSB = 0.3;
    } else if (bHSB >= 0.2) {
      bHSB -= 0.1;
    } else {
      bHSB = bHSB + 0.2;
    }

    const hueSectorIndex: number = Math.floor((hHSB / 60) % 6);
    const hueFraction = (hHSB / 60) - hueSectorIndex;
    const minBrightness = bHSB * (1 - sHSB);
    const lowerBlend = bHSB * (1 - hueFraction * sHSB);
    const upperBlend = bHSB * (1 - (1 - hueFraction) * sHSB);
    switch (hueSectorIndex) {
      case 0:
        rRGB = bHSB;
        gRGB = upperBlend;
        bRGB = minBrightness;
        break;
      case 1:
        rRGB = lowerBlend;
        gRGB = bHSB;
        bRGB = minBrightness;
        break;
      case 2:
        rRGB = minBrightness;
        gRGB = bHSB;
        bRGB = upperBlend;
        break;
      case 3:
        rRGB = minBrightness;
        gRGB = lowerBlend;
        bRGB = bHSB;
        break;
      case 4:
        rRGB = upperBlend;
        gRGB = minBrightness;
        bRGB = bHSB;
        break;
      case 5:
        rRGB = bHSB;
        gRGB = minBrightness;
        bRGB = lowerBlend;
        break;
      default:
        break;
    }
    
    const scaleToByte = (c: number): number => {
      if (!Number.isFinite(c)) {
        return 0;
      }
      return c <= 1 ? Math.floor(c * 255.0) : Math.max(0, Math.min(255, Math.floor(c)));
    };
    return [scaleToByte(rRGB), scaleToByte(gRGB), scaleToByte(bRGB)];
  }

  /**
   * 由封面取色算出一组**足够鲜艳、能当背景**的颜色。
   *
   * 与 {@link dealColor} 的区别：那个是给"深底白字"的页面底色设计的 ——
   * 它把亮度**上限锁死在 0.3**（约 RGB 76），所以封面再亮出来的也是接近黑的深色。
   * 需要"看得见的颜色"（卡片背景、流光）时必须用这个：饱和度提上去、亮度给到中高区间。
   *
   * @param rRGB 封面主色红通道 0–255。
   * @param gRGB 封面主色绿通道 0–255。
   * @param bRGB 封面主色蓝通道 0–255。
   * @returns `[鲜艳色 #RRGGBB, 同色系暗色 #RRGGBB]`；近灰度封面返回中性蓝紫色。
   */
  public static vividFlowColors(rRGB: number, gRGB: number, bRGB: number): string[] {
    const max: number = Math.max(Math.max(rRGB, gRGB), bRGB);
    const min: number = Math.min(Math.min(rRGB, gRGB), bRGB);
    // 近灰度（黑白封面）：用中性蓝紫，纯灰做流光会看不出流动感
    if (max - min < 12) {
      return ['#5B5B78', '#141418'];
    }
    let hHSB: number = 0;
    if (max === rRGB) {
      hHSB = 60 * (gRGB - bRGB) / (max - min) + (gRGB >= bRGB ? 0 : 360);
    } else if (max === gRGB) {
      hHSB = 60 * (bRGB - rRGB) / (max - min) + 120;
    } else {
      hHSB = 60 * (rRGB - gRGB) / (max - min) + 240;
    }
    const sHSB: number = max === 0 ? 0 : (max - min) / max;
    // 饱和度提亮但留一点余地；亮度锁在 0.62～0.86，太暗看不出流光、太亮会盖住封面文字
    const vividS: number = Math.min(1, sHSB * 1.35 + 0.18);
    const vividB: number = Math.max(0.62, Math.min(0.86, max / 255 * 1.15 + 0.22));
    // 底色 = 同色相、更饱和、更暗，形成「流光扫过留一层同色暗底」的层次
    const deepS: number = Math.min(1, sHSB * 1.5 + 0.12);
    const deepB: number = 0.16;
    return [ColorConversion.hsbToHex(hHSB, vividS, vividB), ColorConversion.hsbToHex(hHSB, deepS, deepB)];
  }

  /** HSB → `#RRGGBB`。h 为 0–360，s / v 为 0–1。 */
  private static hsbToHex(h: number, s: number, v: number): string {
    const sector: number = Math.floor((h / 60) % 6);
    const f: number = (h / 60) - sector;
    const p: number = v * (1 - s);
    const q: number = v * (1 - f * s);
    const t: number = v * (1 - (1 - f) * s);
    let r: number = 0;
    let g: number = 0;
    let b: number = 0;
    switch (sector) {
      case 0:
        r = v;
        g = t;
        b = p;
        break;
      case 1:
        r = q;
        g = v;
        b = p;
        break;
      case 2:
        r = p;
        g = v;
        b = t;
        break;
      case 3:
        r = p;
        g = q;
        b = v;
        break;
      case 4:
        r = t;
        g = p;
        b = v;
        break;
      default:
        r = v;
        g = p;
        b = q;
        break;
    }
    return '#' + ColorConversion.toHexByte(r) + ColorConversion.toHexByte(g) + ColorConversion.toHexByte(b);
  }

  /** 0–1 通道值 → 两位大写十六进制。 */
  private static toHexByte(value: number): string {
    const byte: number = Math.max(0, Math.min(255, Math.round(value * 255)));
    const hex: string = byte.toString(16).toUpperCase();
    return hex.length === 1 ? '0' + hex : hex;
  }

  /**
   * 歌单/榜单/专辑详情页的**页面底色**：由封面动态取色，且**亮封面出浅底、暗封面出深底**。
   *
   * ⚠️ 不能用 {@link dealColor} 做这件事：那个函数是为「深色主题底 + 白字」设计的，
   * 它把亮度**上限锁死在 0.3**（约 RGB 76），所以封面再亮出来的底色也是深的 ——
   * 表现就是「日间模式下选到一张亮封面，页面底色还是深色，配上一身浅色文字」。
   *
   * 这里按封面自身明暗分两条支路，色相都跟着封面走（切换歌单时页面整体换色调）：
   *   - 亮封面（通道最大值 > 158）→ 同色相浅底 + 深色文字；
   *   - 暗封面 → 同色相深底 + 浅色文字。
   *
   * @param rRGB 封面主色红通道 0–255。
   * @param gRGB 封面主色绿通道 0–255。
   * @param bRGB 封面主色蓝通道 0–255。
   * @returns `[页面底色 #RRGGBB, 是否浅底('1'/'0')]`；近灰度封面按明暗给中性底。
   */
  public static coverBackdrop(rRGB: number, gRGB: number, bRGB: number): string[] {
    const max: number = Math.max(Math.max(rRGB, gRGB), bRGB);
    const min: number = Math.min(Math.min(rRGB, gRGB), bRGB);
    if (max - min < 8) {
      // 近灰度封面（黑白照片/纯色封面）：没有可用色相，按明暗直接给中性底
      return max > 158 ? ['#EDEDF0', '1'] : ['#1f1f22', '0'];
    }
    let hHSB: number = 0;
    if (max === rRGB) {
      hHSB = 60 * (gRGB - bRGB) / (max - min) + (gRGB >= bRGB ? 0 : 360);
    } else if (max === gRGB) {
      hHSB = 60 * (bRGB - rRGB) / (max - min) + 120;
    } else {
      hHSB = 60 * (rRGB - gRGB) / (max - min) + 240;
    }
    const sHSB: number = max === 0 ? 0 : (max - min) / max;
    if (max > 158) {
      // 亮封面 → 浅底：保留一点色相，亮度拉高但不给纯白（纯白会显得发灰）
      const lightS: number = Math.min(0.22, sHSB * 0.45);
      return [ColorConversion.hsbToHex(hHSB, lightS, 0.94), '1'];
    }
    // 暗封面 → 深底：保留色相，亮度压到 0.16（接近原来 #1f1f22 的观感）
    const darkS: number = Math.min(0.5, sHSB * 0.55);
    return [ColorConversion.hsbToHex(hHSB, darkS, 0.16), '0'];
  }

  /**
   * 在一个底色上挑一个**一定看得见**的半透明叠加色（白或黑）。
   *
   * 为什么需要：卡片两侧那种装饰小方块原来是写死的 `#26FFFFFF`（15% 白）。
   * 底色一旦变成中高亮度（比如 {@link vividFlowColors} 给的那种），
   * 15% 白叠上去和底色几乎没差别 —— 表现就是「方块根本没画出来 / 看不出角度」。
   * 这里按底色的感知亮度选方向：底暗叠白、底亮叠黑，任何底色都有对比。
   *
   * @param hex 底色 `#RRGGBB` 或 `#AARRGGBB`。
   * @param alphaByte 叠加色的透明度字节（`0x00`–`0xFF`），如 `0x38` 表示约 22%。
   * @returns `#AARRGGBB` 形式的叠加色。
   */
  public static contrastOverlay(hex: string, alphaByte: number): string {
    const a: number = Math.max(0, Math.min(255, Math.round(alphaByte)));
    const aHex: string = a.toString(16).toUpperCase();
    const alphaHex: string = aHex.length === 1 ? '0' + aHex : aHex;
    const rgb: string = ColorConversion.luminanceOf(hex) > 140 ? '000000' : 'FFFFFF';
    return '#' + alphaHex + rgb;
  }

  /**
   * @param hex `#RRGGBB` 或 `#AARRGGBB`。
   * @returns 感知亮度 0–255（解析失败按 0，当作深色处理）。
   */
  public static luminanceOf(hex: string): number {
    const rgb: number[] = ColorConversion.parseRgbChannels(hex);
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2];
  }

  /**
   * @param hex `#RRGGBB` 或 `#AARRGGBB`。
   * @returns `[r, g, b]`，每项 0–255；解析失败返回 `[0, 0, 0]`。
   */
  private static parseRgbChannels(hex: string): number[] {
    let body: string = hex.startsWith('#') ? hex.substring(1) : hex;
    if (body.length === 8) {
      // 丢掉 alpha 前缀
      body = body.substring(2);
    }
    if (body.length !== 6) {
      return [0, 0, 0];
    }
    const r: number = Number.parseInt(body.substring(0, 2), 16);
    const g: number = Number.parseInt(body.substring(2, 4), 16);
    const b: number = Number.parseInt(body.substring(4, 6), 16);
    if (!Number.isFinite(r) || !Number.isFinite(g) || !Number.isFinite(b)) {
      return [0, 0, 0];
    }
    return [r, g, b];
  }
}

