import { barBlurOptions, barMaterial } from '../util/BarMaterial';

/**
 * 搜索胶囊（返回键 / 音源切换 / 识别歌曲）的**沉浸光感**背板。
 *
 * ## 为什么不是 HDS 的 `systemMaterialEffect`
 * `SystemMaterialParams` 在 SDK 里只挂在 HDS 组件上
 * （`HdsNavigationTitleBarOptions.systemMaterialEffect` / `HdsTabsFloatingStyle.systemMaterialEffect`，@since 23），
 * 普通 `Row/Column/Stack` 写了编译不过；而 API 26 才有的通用属性 `.systemMaterial(...)`
 * **本机 SDK（6.1.1 / API 24）里没有**（已在 `sdk\default\openharmony\ets\component\*.d.ts`
 * 里 grep 过 `systemMaterial(`，0 命中）。
 *
 * ⇒ 自绘控件用**同源材质背板**表达光感（见 `BarMaterial.ets` 的长注释）：
 * `backgroundBlurStyle(档位, { colorMode: SYSTEM, adaptiveColor: AVERAGE })`
 * —— `AVERAGE` 会取**背后画面平均色**再叠加：底下的画面换色，胶囊跟着变，这才是"光感"。
 *
 * ⚠️ 不要再叠 `#1AFFFFFF` 那层白：材质本身就是背板，叠白在深色主题下会发灰
 *    （甲方 2026-10-24：「现在半透明的不是很好看」）。
 */
export class SearchGlassModifier implements AttributeModifier<StackAttribute> {
  /** 光感档位（0 = 跟随系统 / 1 弱 / 2 均衡 / 3 强），与标题栏 `buildTitleMaterial` 同一张档位表。 */
  private level: number = 0;

  constructor(level: number = 0) {
    this.level = level;
  }

  applyNormalAttribute(instance: StackAttribute): void {
    instance.height(40)
      .backgroundBlurStyle(barMaterial(this.level), barBlurOptions())
      .backgroundColor(Color.Transparent)
      .borderRadius(20);
  }
}
