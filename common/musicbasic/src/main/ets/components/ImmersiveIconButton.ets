/*
 * 沉浸光感圆形图标按钮 —— **逐行照抄**参考工程 `qingye-reader`
 * `entry/src/main/ets/components/AdaptiveIconButton.ets`（用户 2026-11-19："你抄代码都不会抄吗"）。
 *
 * 关键点（之前全错在这几处）：
 * 1. 宿主是 **`Button({ type: ButtonType.Circle, stateEffect: false })`** —— Button 属 A 档，
 *    页面 body 里任意位置挂 `.systemMaterial()` 都能渲染；
 * 2. `systemMaterial` 的材质必须带 **`interactive` + `lightEffect` + `materialColor`**（见 `immersiveMedium()`），
 *    只给 style 就是一块死玻璃；
 * 3. `backgroundColor` 必须是**透明**，否则把材质整块盖住；
 * 4. 不支持材质的设备走 else 分支（`stateEffect: true` + 实色），保证按钮还在。
 */
import { uiMaterial } from '@kit.ArkUI';
import { immersiveMedium } from '../util/ImmersiveMaterialV26';

@Component
export struct ImmersiveIconButton {
  /** 图标 */
  @Prop icon: Resource = $r('sys.symbol.circle');
  /** 无障碍文案 */
  @Prop accessibilityLabel: string = '';
  @Prop buttonEnabled: boolean = true;
  /** 直径（vp） */
  @Prop buttonSize: number = 40;
  /** 图标字号 */
  @Prop iconSize: number = 18;
  @Prop iconColor: ResourceColor = $r('sys.color.font_primary');
  /** 不支持材质时的兜底底色 */
  @Prop fallbackColor: ResourceColor = '#33000000';
  /** 点击 */
  onTap?: () => void;

  @Builder
  iconContent() {
    SymbolGlyph(this.icon)
      .fontSize(this.iconSize)
      .fontWeight(FontWeight.Regular)
      .height(this.iconSize)
      .fontColor([this.iconColor])
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (immersiveMedium() !== undefined) {
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          this.iconContent()
        }
        .width(this.buttonSize)
        .height(this.buttonSize)
        .padding(0)
        .enabled(this.buttonEnabled)
        .systemMaterial(immersiveMedium())
        .backgroundColor(Color.Transparent)
        .focusable(false)
        .accessibilityText(this.accessibilityLabel)
        .onClick(() => {
          if (this.onTap !== undefined) {
            this.onTap();
          }
        })
      } else {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          this.iconContent()
        }
        .width(this.buttonSize)
        .height(this.buttonSize)
        .padding(0)
        .enabled(this.buttonEnabled)
        .backgroundColor(this.fallbackColor)
        .focusable(false)
        .accessibilityText(this.accessibilityLabel)
        .onClick(() => {
          if (this.onTap !== undefined) {
            this.onTap();
          }
        })
      }
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .borderRadius(this.buttonSize / 2)
  }
}
