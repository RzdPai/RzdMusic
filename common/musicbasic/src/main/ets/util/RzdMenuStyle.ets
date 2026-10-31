

/**
 * 弹出菜单「光感」样式（照 qingye-reader 设置页菜单的做法）：
 * 半透明底 + 高斯模糊 + 16vp 圆角 + 0.5vp 细描边。
 *
 * 用法（ArkTS 里 `@Styles` 不能跨文件，所以这里给的是**属性值常量**，调用点写成链式修饰）：
 * ```ts
 * Menu() { … }
 *   .padding({ top: 6, bottom: 6 })
 *   .borderRadius($r('sys.float.corner_radius_level16'))
 *   .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK,
 *     { colorMode: ThemeColorMode.SYSTEM, adaptiveColor: AdaptiveColor.DEFAULT, scale: 1.0 })
 *   .backgroundColor($r('app.color.menu_surface'))
 *   .border({ width: 0.5, color: $r('app.color.menu_surface_border') })
 * ```
 *
 * ⚠️ 本 SDK 的 `MenuOptions` / `ContextMenuOptions` **只有** `offset / placement / enableArrow`，
 * 没有 `backgroundColor` / `backgroundBlurStyle` ⇒ 材质只能加在**菜单内容**上。
 */
export const MENU_PAD_TOP: number = 6;
export const MENU_PAD_BOTTOM: number = 6;
export const MENU_BORDER_WIDTH: number = 0.5;
/** 模糊档位（与系统弹层一致的超厚材质）。 */
export const MENU_BLUR_STYLE: string = 'COMPONENT_ULTRA_THICK';
