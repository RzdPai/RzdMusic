/*
 * Copyright (c) 2026 RzdPai
 *
 * 屏幕方向控制（官方 window API）。
 *
 * 三种模式（持久化在 `MusicStoreService.getScreenOrientation()`）：
 * - `auto`（默认）：跟随系统/陀螺仪，即 `window.Orientation.AUTO_ROTATION`
 *   （系统"旋转锁定"打开时不会转，与我们不改设置前行为一致）；
 * - `portrait`：锁定竖屏 `USER_PORTRAIT`；
 * - `landscape`：锁定横屏 `USER_LANDSCAPE`。
 *
 * 注意：`AUTO_ROTATION` 才是"跟随陀螺仪"；`UNSPECIFIED` 只是不主动设置方向。
 * 排查日志关键字：`RzdOrientation`。
 */

import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { appendPlayLog } from './LxLogger';
import { MusicStoreService } from './MusicStoreService';

/** 方向模式常量。 */
export const ORIENTATION_AUTO: string = 'auto';
export const ORIENTATION_PORTRAIT: string = 'portrait';
export const ORIENTATION_LANDSCAPE: string = 'landscape';

/** 模式 → 文案。 */
export function orientationLabel(mode: string): string {
  if (mode === ORIENTATION_PORTRAIT) {
    return '竖屏';
  }
  if (mode === ORIENTATION_LANDSCAPE) {
    return '横屏';
  }
  return '自动';
}

/** 模式 → window.Orientation。 */
function toWindowOrientation(mode: string): window.Orientation {
  if (mode === ORIENTATION_PORTRAIT) {
    return window.Orientation.PORTRAIT;
  }
  if (mode === ORIENTATION_LANDSCAPE) {
    return window.Orientation.LANDSCAPE;
  }
  return window.Orientation.AUTO_ROTATION;
}

/**
 * 把当前设置应用到窗口。
 * @param context UIAbility 上下文（EntryAbility 里传 this.context）。
 * @returns 是否成功。
 */
export async function applyScreenOrientation(context: common.UIAbilityContext): Promise<boolean> {
  const mode: string = MusicStoreService.getInstance().getScreenOrientation();
  try {
    const win: window.Window = await window.getLastWindow(context);
    const target: window.Orientation = toWindowOrientation(mode);
    await win.setPreferredOrientation(target);
    appendPlayLog('[RzdOrientation] applied ' + mode + ' -> ' + target);
    return true;
  } catch (err) {
    const e: BusinessError = err as BusinessError;
    appendPlayLog('[RzdOrientation] apply failed code=' + e.code + ' mode=' + mode);
    return false;
  }
}

/**
 * 保存设置并立即应用。
 * @param context UIAbility 上下文。
 * @param mode auto / portrait / landscape。
 */
export async function setScreenOrientation(context: common.UIAbilityContext, mode: string): Promise<void> {
  MusicStoreService.getInstance().setScreenOrientation(mode);
  appendPlayLog('[RzdOrientation] switch ' + mode);
  await applyScreenOrientation(context);
}
