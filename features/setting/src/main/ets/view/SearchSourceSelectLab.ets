/*
 * Copyright (c) 2026 RzdPai
 *
 * ⚠️⚠️ **临时实验组件**（2026-11-22 起，验证完立刻删除）⚠️⚠️
 *
 * 目的：把"平台切换（官方 `Select`）到底是被哪一项改灰的"**单变量**测出来。
 *
 * 背景（`git show d0cd2d1`）：那一版同时改了三件事，事后 `Select` 变灰：
 *   ① `.systemMaterial()` 从 `.backgroundColor()/.borderRadius()` **之前**挪到了**之后**；
 *   ② 材质 `applyShadow` 由 true 改成 false；
 *   ③ 搜索页根节点转场由「双向 OPACITY」改成「进 IDENTITY / 退 OPACITY」。
 * 之后所有"白纱/赋色/透明底"的修法都没通过真机验证，因此不能再靠观感猜。
 *
 * 本组件提供 3 个**只差一项**的变体，长按胶囊循环切换（存 `AppStorage`，返回再进仍然有效）：
 *   A 原版      ：材质在前 + 材质自带投影      ← 对照（历史证据：A 不灰）
 *   B 只改顺序  ：材质在后 + 材质自带投影
 *   C 只改投影  ：材质在前 + 材质无投影
 * 页面转场（③）不在这里测 —— 它需要整页重建，单独一轮。
 *
 * 判据：切换变体后**返回首页再进入搜索页**，看进入瞬间这颗胶囊是否变灰。
 *
 * 用法：`SearchSourceSelectLab({ options, selected, value, level, onSelectIndex })`
 */
import { rdzToast } from 'musicbasic';
import { immersiveFromLevel, immersiveFromLevelNoShadow } from 'musicbasic';
import { RzdSelectMenuMaterial } from 'musicbasic';
import { appendPlayLog } from 'musicbasic';

/** 实验变体在 AppStorage 里的键（跨页面进出保持）。 */
const LAB_VARIANT_KEY: string = 'rzdSelectLabVariant';

/** 变体说明（提示文案 + 日志用）。 */
const LAB_LABELS: string[] = [
  'A 原版：材质在前 + 自带投影',
  'B 只改顺序：材质在后 + 自带投影',
  'C 只改投影：材质在前 + 无投影'
];

@ComponentV2
export struct SearchSourceSelectLab {
  /** 选项（与生产一致） */
  @Param options: SelectOption[] = [];
  /** 当前选中项 */
  @Param selected: number = 0;
  /** 当前显示文案 */
  @Param value: string = '';
  /** 光感强度档位（0~3） */
  @Param level: number = 0;
  /** 选中回调（语义下标，生产侧自己加偏移） */
  @Event onSelectIndex: (index: number) => void = (_index: number): void => {};
  /** 当前变体（0/1/2） */
  @Local variant: number = 0;

  aboutToAppear(): void {
    const saved: number | undefined = AppStorage.get<number>(LAB_VARIANT_KEY);
    if (saved !== undefined && saved >= 0 && saved < LAB_LABELS.length) {
      this.variant = saved;
    }
    appendPlayLog('[RzdMaterialLab] variant=' + this.variant + ' ' + LAB_LABELS[this.variant]);
  }

  private cycleVariant(): void {
    this.variant = (this.variant + 1) % LAB_LABELS.length;
    AppStorage.setOrCreate<number>(LAB_VARIANT_KEY, this.variant);
    appendPlayLog('[RzdMaterialLab] variant=' + this.variant + ' ' + LAB_LABELS[this.variant]);
    rdzToast(this.getUIContext(), '光感实验 ' + LAB_LABELS[this.variant] + '（返回再进看是否发灰）', 3000);
  }

  /** A：材质在背景之前 + 材质自带投影（= d0cd2d1 之前的生产写法）。 */
  @Builder
  private variantA() {
    Select(this.options)
      .selected(this.selected)
      .value(this.value)
      .height(40)
      .font({ size: 13 })
      .fontColor($r('app.color.font_primary'))
      .systemMaterial(immersiveFromLevel(this.level))
      .backgroundColor($r('app.color.immersive_glass_overlay'))
      .borderRadius(20)
      .attributeModifier(new RzdSelectMenuMaterial())
      .onSelect((index: number): void => {
        this.onSelectIndex(index);
      })
  }

  /** B：只把材质挪到背景之后（其余与 A 逐字相同）。 */
  @Builder
  private variantB() {
    Select(this.options)
      .selected(this.selected)
      .value(this.value)
      .height(40)
      .font({ size: 13 })
      .fontColor($r('app.color.font_primary'))
      .backgroundColor($r('app.color.immersive_glass_overlay'))
      .borderRadius(20)
      .systemMaterial(immersiveFromLevel(this.level))
      .attributeModifier(new RzdSelectMenuMaterial())
      .onSelect((index: number): void => {
        this.onSelectIndex(index);
      })
  }

  /** C：只把材质自带投影关掉（顺序与 A 相同）。 */
  @Builder
  private variantC() {
    Select(this.options)
      .selected(this.selected)
      .value(this.value)
      .height(40)
      .font({ size: 13 })
      .fontColor($r('app.color.font_primary'))
      .systemMaterial(immersiveFromLevelNoShadow(this.level))
      .backgroundColor($r('app.color.immersive_glass_overlay'))
      .borderRadius(20)
      .attributeModifier(new RzdSelectMenuMaterial())
      .onSelect((index: number): void => {
        this.onSelectIndex(index);
      })
  }

  build() {
    Column() {
      if (this.variant === 0) {
        this.variantA()
      } else if (this.variant === 1) {
        this.variantB()
      } else {
        this.variantC()
      }
    }
    .height(40)
    // 长按切换变体：临时入口，实验结束随本文件一起删。
    .gesture(LongPressGesture().onAction((): void => {
      this.cycleVariant();
    }))
  }
}
