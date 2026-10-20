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
 * 自绘「底部操作条 / 悬浮胶囊 / 搜索框」的**沉浸光感材质**。
 *
 * ## ★★★ 2026-10-20 第二轮（用户：「接入的是**沉浸光感**，不是发光，把这堆发光删了」）
 * 上一版这里还有 `hdsEffect` 的**点光**（`pressLightEffect` / `illuminatedEffect`：按下那一格发亮、
 * 相邻格子受光）。用户明确否掉 —— 那不是光感，是"发光"。**已全部删除**（连带所有
 * `.visualEffect(...)` 调用点），不要再加回来。
 *
 * ## 三方自绘控件怎么拿"沉浸光感"
 * SDK 里 `SystemMaterialParams`（沉浸材质）只挂在 **HDS 组件**上：
 * `HdsNavigationTitleBarOptions.systemMaterialEffect` 与 `HdsTabsFloatingStyle.systemMaterialEffect`
 * （@since 23）。普通 `Row/Column/Search` **没有**这个属性（写了编译不过）。
 *
 * 所以自绘控件用**同源的材质背板**来表达光感：
 * `backgroundBlurStyle(档位, { colorMode: SYSTEM, adaptiveColor: AVERAGE })`。
 * - `adaptiveColor.DEFAULT` = 一层固定色蒙版（死板、看着像普通半透明）；
 * - `adaptiveColor.AVERAGE` = 取**背后画面平均色**再叠加 ⇒ 底下的画面换色，条子跟着变，这才是"光感"。
 * - `colorMode = SYSTEM` ⇒ 深/浅色跟随系统，不写死黑/白蒙版。
 *
 * 排查日志关键字：无（纯静态样式，无状态）。
 */

/**
 * 按"光感强度"取材质档位。
 *
 * 与标题栏 `buildTitleMaterial` 用**同一张档位表**（0 = 跟随系统），保证一屏里
 * 标题栏与自绘浮层的材质**同档**，不会一浓一淡。
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
 * `colorMode = SYSTEM` ⇒ 深/浅色跟随系统。
 */
export function barBlurOptions(): BackgroundBlurStyleOptions {
  return {
    colorMode: ThemeColorMode.SYSTEM,
    adaptiveColor: AdaptiveColor.AVERAGE,
    scale: 1
  };
}

/**
 * 给「浮层背板」用的完整外观参数（一条调用拿到同一套观感）。
 * 现在只剩材质模糊一项 —— 点光（发光）按用户要求已删除。
 */
export function barMaterial(level: number): BlurStyle {
  return buildBarBlurStyle(level);
}
