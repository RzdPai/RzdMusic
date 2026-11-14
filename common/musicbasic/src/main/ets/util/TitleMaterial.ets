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

import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';

/**
 * Builds the HDS title bar immersive material params following the ambient light level.
 * @param level Ambient light level (0 = follow system, 1 = weak, 2 = balanced, 3 = strong).
 * @returns Material params for the HDS title bar systemMaterialEffect.
 */
export function buildTitleMaterial(level: number): SystemMaterialParams {
  switch (level) {
    case 1:
      return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.SMOOTH };
    case 2:
      return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.GENTLE };
    case 3:
      return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.EXQUISITE };
    default:
      return { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE };
  }
}
