import { barBlurOptions, barMaterial } from '../util/BarMaterial';

/**
 * 搜索胶囊（返回键 / 音源切换 / 识别歌曲）的背板材质。
 *
 * ★ 2026-10-29 修正（依据《新 API26 沉浸光感经验汇总》§1.1 判定表）：
 *   这三颗胶囊是**页面 body 里的自绘浮层**，属 API 26 `systemMaterial` 的
 *   out of scope —— 编译能过、真机不渲染（表现就是"光感失效 / 看不清"）。
 *   官方白名单只有：Navigation/NavDestination 标题栏、`BarPosition.End` 底部 TabBar、
 *   系统弹窗（CustomDialog/Sheet/Menu/Popup…）及其子树里的 Button/Slider 等。
 *
 * ⇒ 自绘控件一律走**真模糊**（见 `BarMaterial.ets` 的长注释）：
 *   `backgroundBlurStyle(档位, { colorMode: SYSTEM, adaptiveColor: AVERAGE })`
 *   —— `AVERAGE` 会取背后画面平均色再叠加：底下画面换色，胶囊跟着变。
 *
 * ⚠️ 不要叠 `#1AFFFFFF` 那层白：材质本身就是背板，叠白在深色主题下会发灰
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
