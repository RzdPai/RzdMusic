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

import { uiMaterial } from '@kit.ArkUI';

/**
 * **API 26 的沉浸光感材质**（`uiMaterial.ImmersiveMaterial` + 通用属性 `systemMaterial`）。
 *
 * ## 与 API 23 那套（`hdsMaterial` / `buildTitleMaterial` / `backgroundBlurStyle`）的关系
 *
 * | | API 23 | API 26（本文件） |
 * | --- | --- | --- |
 * | 入口 | `SystemMaterialParams` 挂在 **HDS 组件**上（`HdsNavigation.titleBar.style.systemMaterialEffect`、`HdsTabs.barFloatingStyle.systemMaterialEffect`） | 通用属性 `.systemMaterial(material)`，**普通组件也能写** |
 * | 自绘控件 | 只能靠 `backgroundBlurStyle(档位, AVERAGE)` 近似 | 直接给材质对象 |
 * | 分档 | 软件里手选（`AmbientState.level` 0~3） | **系统按设备算力自适应** + 系统设置的强弱 |
 *
 * ⚠️ 用户 2026-11-19 的要求：**"已有使用 API 23 的地方不要动"** ——
 * 所以本文件只用于**新增接入**的位置，不替换任何已存在的 `buildTitleMaterial` / `backgroundBlurStyle`。
 *
 * ## 生效范围（官方约束，别指望它到处都亮）
 *
 * - 弹窗类（Dialog / HalfModal / 菜单 / Popup / Tips）⇒ **全页面生效**；
 * - 弹窗类组件（AlertDialog / ActionSheet / bindSheet …）⇒ 全页面生效；
 * - `Slider` / `Toggle` / `Select` ⇒ 全页面生效；
 * - **其它组件** ⇒ 只在 `Navigation/NavDestination` 的**标题栏**、
 *   或横向 `Tabs` 且 `barPosition=End` 的**底部 TabBar** 里生效。
 *
 * 也就是说：给一个普通 `Row`（例如搜索框）写 `.systemMaterial()` **不会有任何效果**，
 * 那种位置仍然要用 API 23 的 `backgroundBlurStyle` 那一套（已有实现，不动）。
 */

/** 材质档位：默认 REGULAR（系统三档里的中间那档，观感最稳）。 */
const DEFAULT_STYLE: uiMaterial.ImmersiveStyle = uiMaterial.ImmersiveStyle.REGULAR;

/**
 * 设备是否支持沉浸光感材质（不支持时写 `.systemMaterial()` 也不会报错，只是没效果）。
 * @returns true = 支持
 */
export function immersiveMaterialSupported(): boolean {
  try {
    return uiMaterial.isImmersiveMaterialSupported();
  } catch (_e) {
    return false;
  }
}

/**
 * 取一个**沉浸光感材质对象**给 `.systemMaterial()` 用。
 *
 * 不支持该能力的设备返回 `undefined` —— 调用方写成
 * `.systemMaterial(buildImmersiveMaterial())` 即可，`undefined` 等价于"不设材质"，
 * 此时组件自己的 `backgroundColor` / `backgroundBlurStyle` 仍然生效（自动降级，不用写分支）。
 *
 * @param style 材质厚薄；不传用 REGULAR
 * @param interactive 交互形变（按下时材质轻微形变）；默认开，观感更"实"
 * @param lightEffect 光感交互反馈（触摸时表面有光扫过）；默认开（仅高中算力设备生效）
 * @returns 材质对象；设备不支持时 undefined
 */
export function buildImmersiveMaterial(style?: uiMaterial.ImmersiveStyle,
  interactive: boolean = true, lightEffect: boolean = true): uiMaterial.ImmersiveMaterial | undefined {
  if (!immersiveMaterialSupported()) {
    return undefined;
  }
  try {
    return new uiMaterial.ImmersiveMaterial({
      style: style !== undefined ? style : DEFAULT_STYLE,
      interactive: interactive,
      lightEffect: lightEffect ? {} : undefined
    });
  } catch (_e) {
    return undefined;
  }
}
