/*
 * Copyright (c) 2026 RzdPai
 *
 * 弹层"光感"（系统沉浸材质）与降级策略。
 *
 * 事实（逐条用 SDK d.ts 核过，2026-10-31）：
 * - `SystemUiMaterial` = `@kit.ArkUI` 的 `uiMaterial.Material`（`common.d.ts:16964` 的类型别名）；
 * - `uiMaterial.ImmersiveMaterial extends Material`，构造：`new uiMaterial.ImmersiveMaterial(options?)`
 *   （`options` 默认 `{style:ImmersiveStyle.REGULAR, materialColor:Transparent, colorInvert:false, applyShadow:true, interactive:false}`），
 *   能力探测：`uiMaterial.isImmersiveMaterialSupported()`（API 26+）；
 * - **哪些弹层能挂 systemMaterial**：`SheetOptions`、`PopupCommonOptions`、`TipsOptions`；
 *   **`ContextMenuOptions`（= bindMenu 的 options）没有 systemMaterial** ⇒ 那类只能用 `backgroundColor + backgroundBlurStyle` 降级。
 *
 * 结论：想上"光感"，弹层必须走 `bindPopup` / `bindSheet`；`bindMenu` 一律走模糊降级。
 * 排查日志关键字：`RzdMaterial`。
 */

import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { appendPlayLog } from './LxLogger';

/** 光感材质工厂 + 降级判定。 */
export class RzdMaterial {
  /** 只探测一次，避免每次弹层都问系统。 */
  private static probe: boolean | undefined = undefined;

  /**
   * @returns 本机是否支持沉浸式系统材质（API 26+ 且设备支持）。
   */
  static immersiveSupported(): boolean {
    if (RzdMaterial.probe !== undefined) {
      return RzdMaterial.probe;
    }
    let ok: boolean = false;
    if (deviceInfo.sdkApiVersion >= 26) {
      try {
        ok = uiMaterial.isImmersiveMaterialSupported();
      } catch (err) {
        ok = false;
      }
    }
    RzdMaterial.probe = ok;
    appendPlayLog('[RzdMaterial] 光感可用=' + ok + ' sdk=' + deviceInfo.sdkApiVersion);
    return ok;
  }

  /**
   * 构造弹层用的系统材质。
   * @returns 材质对象；不支持时返回 undefined（调用方应退回模糊 + 面板色）。
   */
  static immersive(): uiMaterial.Material | undefined {
    if (!RzdMaterial.immersiveSupported()) {
      return undefined;
    }
    try {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR,
        applyShadow: true,
        interactive: false
      });
    } catch (err) {
      appendPlayLog('[RzdMaterial] 构造材质失败，退回模糊');
      return undefined;
    }
  }

  /**
   * `bindMenu`（ContextMenuOptions）的降级样式：没有 systemMaterial，只能用模糊 + 面板色。
   * @returns 直接展开到 options 里的字段。
   */
  static menuFallbackBlur(): BlurStyle {
    return RzdMaterial.immersiveSupported() ? BlurStyle.COMPONENT_THICK : BlurStyle.COMPONENT_ULTRA_THICK;
  }
}
