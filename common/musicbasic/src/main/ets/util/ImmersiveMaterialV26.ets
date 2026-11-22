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
import { deviceInfo } from '@kit.BasicServicesKit';

import { Logger } from './Logger';
/** 材质厚度（与 uiMaterial.ImmersiveStyle 对应，这里只留常用几档）。 */
export enum RzdMaterialStyle {
  THIN = 0,
  REGULAR = 1,
  THICK = 2
}

/**
 * 一次性探测日志（排查"没有光感"用）。
 *
 * 为什么要它：`systemMaterial` **能编译 ≠ 能渲染** —— 设备不支持时返回的对象会被忽略，
 * 宿主槽位不合格时框架打 `Material inactive: out of scope`，两种都在屏上表现成"没有玻璃"。
 * 这一行把**设备能力 + 实际档位**固定下来，下次只要 grep 一条日志就能判断是哪种：
 * ```
 * hdc shell hilog -x | Select-String 'RzdMaterial'
 * ```
 * 期望（会渲染）：`api=26 built=true`；`built=false` ⇒ 设备不支持 ImmersiveMaterial。
 */
let supportLogged: boolean = false;

function logSupportOnce(built: boolean, style: RzdMaterialStyle): void {
  if (supportLogged) {
    return;
  }
  supportLogged = true;
  Logger.info(`[RzdMaterial] api=${deviceInfo.sdkApiVersion} style=${style} built=${built}`);
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
 * @param applyShadow 是否带材质自带投影（默认 true）。官方 FAQ：`applyShadow` 为 true 时材质阴影
 *   **固定生效**并**优先于**通用属性 `shadow`；为 false 时材质不出阴影，自定义 `shadow` 才生效。
 *   什么时候要关掉它：材质不是画在"胶囊自己身上"时（如本仓借 `Tabs` 悬浮栏托底的壳），
 *   系统按**节点矩形**投影 ⇒ 屏上是"四个角"的方影子，和官方 `Select` 的胶囊投影对不上。
 *   这时关掉材质投影，改用 {@link immersiveCapsuleShadow}（胶囊形状的投影）才对齐。
 */
export function immersiveMaterial(style: RzdMaterialStyle = RzdMaterialStyle.REGULAR,
  applyShadow: boolean = true): SystemUiMaterial | undefined {
  try {
    // ★ 2026-11-20：**不再因 `isImmersiveMaterialSupported()===false` 就直接返回 undefined**。
    //   设备/算力不支持时，系统会自行忽略这个可选参数；直接不给材质反而会掉到"系统灰表面"。
    //   ⇒ 一律先构造，再交给系统。
    // ★★★ 2026-11-19（用户："还是不好看，我还是希望用官方的"；参考工程 `AdaptiveIconButton`）：
    //   官方那套质感 = **交互形变 + 光感反馈 + 材质底色**三件一起给，缺一个就显得"只是块玻璃"：
    //     · `interactive: true`      —— 按下有形变（官方手感）
    //     · `lightEffect: {…}`       —— 跟随触点的光效（**我们之前完全没给，所以一直是死的**）
    //     · `materialColor`          —— 材质底色（半透明白，深色下自动反相）
    const built: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial({
      style: styleOf(style),
      applyShadow: applyShadow,
      interactive: true,
      // ★ 2026-11-20（用户："日间发白 / 夜间不够透"）：
      //   材质底色用**深浅色自适应资源**（日间 20% 白纱、夜间 20% 黑纱），
      //   不再留系统默认（默认偏白 ⇒ 日间发白、夜间发灰）。
      materialColor: $r('app.color.immersive_glass_overlay'),
      lightEffect: {
        color: '#66FFFFFF'
      }
    });
    logSupportOnce(true, style);
    return built;
  } catch (error) {
    logSupportOnce(false, style);
    Logger.info('[RzdMaterial] build material failed: ' + JSON.stringify(error).substring(0, 80));
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
  try {
    const built: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      applyShadow: false,
      interactive: false
    });
    logSupportOnce(true, RzdMaterialStyle.THIN);
    return built;
  } catch (error) {
    logSupportOnce(false, RzdMaterialStyle.THIN);
    Logger.info('[RzdMaterial] build flat material failed: ' + JSON.stringify(error).substring(0, 80));
    return undefined;
  }
}

/**
 * ★ 2026-11-02：按「其它设置 → 光感强度」的 0/1/2/3 档取材质。
 *
 * 与 `buildTitleMaterial(level)`（HDS 标题栏用的 `SystemMaterialParams`）**同一张档位表**，
 * 但这里是通用属性 `systemMaterial` 要的 `SystemUiMaterial`：
 * ```
 *   0 跟随系统 → REGULAR（交给系统自适应）
 *   1 弱       → THIN
 *   2 均衡     → REGULAR
 *   3 强       → THICK
 * ```
 * 为什么要有它：搜索行那三颗胶囊（返回 / 搜索框 / 切换平台）的注释一直写着"档位跟着光感强度走"，
 * 但实现里全写死 `immersiveMedium()` ⇒ 用户把光感调到"强"时，标题栏变了、胶囊没变。
 * @param level 光感强度档位（0~3，越界按 0 处理）
 */
export function immersiveFromLevel(level: number): SystemUiMaterial | undefined {
  switch (level) {
    case 1:
      return immersiveMaterial(RzdMaterialStyle.THIN);
    case 3:
      return immersiveMaterial(RzdMaterialStyle.THICK);
    default:
      return immersiveMaterial(RzdMaterialStyle.REGULAR);
  }
}

/**
 * 胶囊投影（**自绘壳 `ImmersiveSurface` 专用**）。
 *
 * 用途不变：壳的材质托在 `Tabs` 悬浮栏上，材质自带投影会被算成"方影子"，
 * 所以壳里把 `applyShadow` 置 false，改由这个方法投一份胶囊形的影
 * （官方 FAQ：要让自定义 `shadow` 生效，必须先把材质 `applyShadow` 置 false）。
 *
 * ⚠️ **组件级材质（`Select`/`Toggle`/`Slider`）不要用这个** ——
 * 它们的材质画在胶囊自己身上，投影天然跟着圆角走，再叠一层就成了双层影。
 * 搜索页顶栏与类型栏都已经是组件级材质，因此都不再引用本方法。
 *
 * 数值取"官方材质阴影"那一档的量级（很淡、略微下移）：日间 12% 黑、夜间 25% 黑，
 * 颜色走深浅色自适应资源 `immersive_glass_shadow`。
 * @returns 直接传给 `.shadow(...)` 的对象
 */
export function immersiveCapsuleShadow(): ShadowOptions {
  return {
    radius: 12,
    color: $r('app.color.immersive_glass_shadow'),
    offsetX: 0,
    offsetY: 3
  };
}
