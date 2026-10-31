/*
 * Copyright (c) 2026 RzdPai
 *
 * API 26 沉浸光感（systemMaterial）统一入口。
 *
 * 官方：`CommonMethod.systemMaterial(material: SystemUiMaterial | undefined)`（@since 26.0.0）
 * —— 挂在**任意组件**上的系统材质，会接管 backgroundColor / borderColor / borderWidth / shadow
 *   （所以用了它就别再手写这几样）。
 *
 * 本文件只暴露"中等厚度"这一档：用户口径是"厚度用中等"。
 * grep 关键字：`RzdMaterial`
 */

import { uiMaterial } from '@kit.ArkUI';

/** 材质厚度（与 uiMaterial.ImmersiveStyle 对应，这里只留常用几档）。 */
export enum RzdMaterialStyle {
  THIN = 0,
  REGULAR = 1,
  THICK = 2
}

function styleOf(style: RzdMaterialStyle): uiMaterial.ImmersiveStyle {
  switch (style) {
    case RzdMaterialStyle.THIN:
      return uiMaterial.ImmersiveStyle.THIN;
    case RzdMaterialStyle.THICK:
      return uiMaterial.ImmersiveStyle.THICK;
    default:
      return uiMaterial.ImmersiveStyle.REGULAR;
  }
}

/**
 * 取沉浸材质对象；设备不支持时返回 undefined（调用方 `.systemMaterial(undefined)` = 无材质，安全降级）。
 * @param style 厚度，默认中等（REGULAR）
 */
export function immersiveMaterial(style: RzdMaterialStyle = RzdMaterialStyle.REGULAR): SystemUiMaterial | undefined {
  try {
    if (!uiMaterial.isImmersiveMaterialSupported()) {
      console.info('[RzdMaterial] immersive material unsupported, fallback to none');
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: styleOf(style),
      applyShadow: true,
      interactive: true
    });
  } catch (error) {
    console.info('[RzdMaterial] build material failed: ' + JSON.stringify(error).substring(0, 80));
    return undefined;
  }
}

/** 中等厚度（最常用）：`xxx.systemMaterial(immersiveMedium())` */
export function immersiveMedium(): SystemUiMaterial | undefined {
  return immersiveMaterial(RzdMaterialStyle.REGULAR);
}
/**
 * 无阴影的薄材质（无背板托底时用：如浮动操作条、贴在列表上的胶囊）。
 * 与 `immersiveMaterial(THIN)` 的唯一区别是 `applyShadow: false`，避免材质自带的投影糊在内容上。
 * @returns 材质对象；不支持时 undefined。
 */
export function immersiveFlat(): SystemUiMaterial | undefined {
  if (!uiMaterial.isImmersiveMaterialSupported()) {
    return undefined;
  }
  return new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    applyShadow: false,
    interactive: false
  });
}