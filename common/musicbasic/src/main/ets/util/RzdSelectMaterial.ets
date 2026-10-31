/*
 * Copyright (c) 2026 RzdPai
 *
 * 弹出菜单的"光感"材质（照 qingye-reader 的做法，不自绘）。
 *
 * 来源核对（2026-10-31）：
 * `entry/src/main/ets/pages/Settings.ets` 的 14 处单选菜单用的都是 **`Select` 组件**，
 * 材质挂在 Select 的 menu 专属属性上；`ImmersiveMaterialRuntime.selectMenuModifier()` 负责按 API 版本降级：
 * - `menuOutline`（API 20+）：0.5vp 细描边；
 * - `menuSystemMaterial`（API 26+）：系统材质（真正的"光感"）；
 * - `menuBackgroundColor` + `menuBackgroundBlurStyle`：材质不可用时的厚模糊 + 面板底色。
 *
 * 我们这版 SDK 已确认具备：
 * `component/select.d.ts` → `menuBackgroundColor`(11+, :784) / `menuBackgroundBlurStyle`(11+, :816) /
 * `menuOutline(MenuOutlineOptions)`(20+, :1045) / `menuSystemMaterial(Optional<SystemUiMaterial>)`(26+, :1131)。
 *
 * 用法：
 * ```ts
 * Select(options)
 *   .attributeModifier(new RzdSelectMenuMaterial())
 * ```
 */

import { deviceInfo } from '@kit.BasicServicesKit';

/** Select 下拉菜单的光感材质（通过 attributeModifier 挂载）。 */
export class RzdSelectMenuMaterial implements AttributeModifier<SelectAttribute> {
  applyNormalAttribute(instance: SelectAttribute): void {
    // 选项：透明底、去分隔线、选中用主色浅底（与系统下拉菜单一致）
    instance.optionBgColor(Color.Transparent);
    instance.divider(null);
    instance.selectedOptionBgColor($r('sys.color.comp_background_emphasize'));
    // 菜单底板：半透明面板色；均衡档用厚模糊，弱档关掉（贴系统观感）
    instance.menuBackgroundColor($r('app.color.menu_surface'));
    instance.menuBackgroundBlurStyle(BlurStyle.COMPONENT_THICK);
    // API 20+ 才支持菜单描边（本工程 compileSdk 已满足；低版本 SDK 会在运行时忽略）
    if (deviceInfo.sdkApiVersion >= 20) {
      instance.menuOutline({ width: 0.5, color: $r('app.color.menu_surface_border') });
    }
  }
}
