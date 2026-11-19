/*
 * 带沉浸光感的 Toast（API 26：`ShowToastOptions.systemMaterial`）。
 *
 * 用户 2026-11-20："各个地方（比如弹窗提示）凡是 API 26 能加光感的都加上"。
 * 统一从这里出提示，别各写各的 `showToast({...})`。
 */
import { promptAction } from '@kit.ArkUI';
import { immersiveMedium } from './ImmersiveMaterialV26';

/**
 * 显示一条带系统材质的提示。
 * @param ui UIContext（组件里 `this.getUIContext()`）
 * @param message 文案
 * @param duration 毫秒，默认 2000
 */
export function rdzToast(ui: UIContext | undefined, message: string, duration: number = 2000): void {
  if (ui === undefined) {
    return;
  }
  try {
    const options: promptAction.ShowToastOptions = {
      message: message,
      duration: duration
    };
    const material = immersiveMedium();
    if (material !== undefined) {
      options.systemMaterial = material;
    }
    ui.getPromptAction().showToast(options);
  } catch (_e) {
    // 提示失败不影响主流程
  }
}
