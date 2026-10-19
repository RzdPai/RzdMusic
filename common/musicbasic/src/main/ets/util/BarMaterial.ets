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

import { hdsEffect } from '@kit.UIDesignKit';

/**
 * 自绘「底部操作条 / 悬浮胶囊」的**光感 + 材质**三件套。
 *
 * ## 为什么自绘条不能用 `systemMaterialEffect`
 * 本机 SDK（`D:\command-line-tools\sdk`）里 `SystemMaterialParams` 只挂在**HDS 组件**上：
 * `HdsNavigationTitleBarOptions.systemMaterialEffect`（@since 23）与
 * `HdsTabsFloatingStyle.systemMaterialEffect`（@since 23）。
 * 普通 `Row/Column` **没有**这个属性（写了编译不过）。所以自绘条走官方另一条路：
 *
 * - **材质背板** = `backgroundBlurStyle(档位, { adaptiveColor: AdaptiveColor.AVERAGE })`。
 *   `adaptiveColor.DEFAULT` 是"固定色蒙版"（= 死板、没有光感）；`AVERAGE` 才表示
 *   "取背后画面平均色"⇒ 底下的画面换色，条子跟着换 ⇒ 这就是三方布局下的"光感"。
 * - **点光** = `hdsEffect` 的 `PointLight`（`@kit.UIDesignKit`，API 20+），
 *   按在某一格上时那一格亮，相邻格子"等着被照亮"（`BORDER_CONTENT`）。
 *
 * ## 两条实测教训（照 RzdSchool `CommonUi.ets` 的结论，别自己改）
 * 1. `pointLight` 里 **`sourceType` 优先于其它选项**；同时给别的东西会让组件**常亮**。
 *    所以只在 `sourceType` 上做开关：没按 = `NONE`，按下 = `BRIGHT`。
 * 2. 点光宿主只支持 `Button / Toggle / Row / Column / Image / Flex / Stack / Select /
 *    Menu / MenuItem`，`Text` **不支持** ⇒ 每一格必须是 `Column`（图标和文字都在里面）。
 *
 * 排查日志关键字：无（纯静态样式，无状态）。
 */

/**
 * 按"光感强度"取底部悬浮条要用的模糊档位。
 *
 * 与标题栏 `buildTitleMaterial` 同一个档位表（0 = 跟随系统），保证一屏里
 * 标题栏和底部条的光感**同档**，不会一浓一淡。
 * @param level 光感强度（0 = 跟随系统 / 1 = 弱 / 2 = 均衡 / 3 = 强）
 * @returns `BlurStyle`（ArkUI 全局枚举，不需要 import）
 */
export function buildBarBlurStyle(level: number): BlurStyle {
  switch (level) {
    case 1:
      return BlurStyle.COMPONENT_ULTRA_THIN;
    case 2:
      return BlurStyle.COMPONENT_THIN;
    case 3:
      return BlurStyle.COMPONENT_REGULAR;
    default:
      return BlurStyle.COMPONENT_REGULAR;
  }
}

/**
 * 材质背板的选项：**必须** `adaptiveColor = AVERAGE` 才有"随背后画面变色"的光感。
 * `colorMode = SYSTEM` ⇒ 深/浅色跟随系统，不在代码里写死黑/白蒙版。
 */
export function barBlurOptions(): BackgroundBlurStyleOptions {
  return {
    colorMode: ThemeColorMode.SYSTEM,
    adaptiveColor: AdaptiveColor.AVERAGE,
    scale: 1
  };
}

/**
 * 「按下才亮」的点光（给操作条的每一格）。
 * @param pressed 当前是否按下
 */
export function pressLightEffect(pressed: boolean): VisualEffect {
  return new hdsEffect.HdsEffectBuilder()
    .pointLight({
      sourceType: pressed ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE,
      illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
    })
    .buildEffect();
}

/** 「只受光不发光」：给条子本体用（旁边有格子按下时，条子边缘被照亮）。 */
export function illuminatedEffect(): VisualEffect {
  return new hdsEffect.HdsEffectBuilder()
    .pointLight({ illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT })
    .buildEffect();
}
