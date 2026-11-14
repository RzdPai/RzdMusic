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
}

