/*
 * Copyright (c) 2026 RzdPai
 *
 * 弹层「光感」材质（系统沉浸材质）。
 *
 * 用户拍板（2026-10-31）：**不做降级判断，直接用系统材质**（"现在 api 已经全面推了"）。
 * SDK 事实：`SystemUiMaterial` = `@kit.ArkUI` 的 `uiMaterial.Material`；
 * `systemMaterial` 只存在于 `SheetOptions` / `PopupCommonOptions` / `TipsOptions`
 * ⇒ 要光感就把弹层走 `bindPopup` / `bindSheet`（`ContextMenuOptions` 没有这个字段）。
 *
 * 排查日志关键字：`RzdMaterial`。
 */

import { uiMaterial } from '@kit.ArkUI';

/** 光感材质工厂。 */
export class RzdMaterial {
  /**
   * 弹层用的系统沉浸材质（每处弹层现造一个即可，开销可忽略）。
   * @returns uiMaterial.Material
   */
  static immersive(): uiMaterial.Material {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      interactive: false
    });
  }
}