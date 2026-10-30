/*
 * Copyright (c) 2026 RzdPai
 *
 * libmpv 内核（占位实现）。
 *
 * 为什么现在是占位：本机拿不到 arm64 的 `libmpv.so`
 *   ① `Yebingiscn/libmpv-ohos-ErBW_s-5en` 只是构建脚本，二进制在 GitHub Actions 产物里（需认证，且本机 GitHub 不通）；
 *   ② 构建要求 Linux/macOS/WSL（本机未装 WSL/Docker）；
 *   ③ app 侧的 `libmpvnative.so` 包装也不在产物里，需要自己写。
 *
 * 等拿到 `libmpv.so` 后要做的三件事（都已在本文件里留好位置）：
 *   1. 把 `libmpv.so` 放到 `features/player/src/main/libs/arm64-v8a/`（或 products/default 的 libs）；
 *   2. 写 `features/player/src/main/cpp` 的 NAPI 包装（参考 SweetVideo 默认分支的
 *      `entry/src/main/cpp/types/libmpvnative/Index.d.ts`，最小面：create/destroy、command、
 *      setOption、observeProperty、事件回调），产出 `libmpvnative.so`；
 *   3. 把下面每个方法从「日志 + 报错」改成调用 NAPI；`MediaService` 与 UI **不需要任何改动**。
 *
 * USB 独占（将来）：libmpv 的 `ao=usb-exclusive` + `usb-exclusive-fd`（fd 由 USBManager 授权），
 * 另有 `checkUsbFileDescriptor(fd)` 做有效性校验。
 */

import { appendPlayLog } from 'musicbasic';
import {
  AudioKernel,
  AudioKernelCallbacks,
  AudioInterruptKind,
  PlaybackKernelKind
} from './AudioKernel';

/** mpv 内核占位实现：接口齐全，但所有操作都会立刻报「未就绪」。 */
export class MpvAudioEngine implements AudioKernel {
  private callbacks: AudioKernelCallbacks = {};
  private readonly tag: string = '[RzdMpv]';

  /**
   * @returns mpv 内核是否可用。
   * 现在恒为 false；接入 `libmpv.so` + `libmpvnative.so` 后改成真实的探测
   * （例如 `import mpvNative from 'libmpvnative.so'` 成功即 true）。
   */
  static isAvailable(): boolean {
    return false;
  }

  kind(): PlaybackKernelKind {
    return PlaybackKernelKind.MPV;
  }

  create(callbacks: AudioKernelCallbacks): void {
    this.callbacks = callbacks;
    appendPlayLog(this.tag + ' 内核尚未接入（缺 libmpv.so / libmpvnative）');
    if (this.callbacks.onError !== undefined) {
      this.callbacks.onError(-1, 'mpv kernel not bundled');
    }
  }

  prepare(url: string): void {
    appendPlayLog(this.tag + ' prepare 被调用但内核不可用 url=' + url.substring(0, Math.min(url.length, 80)));
  }

  start(): void {
  }

  pause(): void {
  }

  seekTo(positionMs: number): void {
  }

  position(): number {
    return 0;
  }

  duration(): number {
    return 0;
  }

  isPlaying(): boolean {
    return false;
  }

  setVolume(volume: number): void {
  }

  setSpeed(rate: number): void {
  }

  applyTuning(eqGains: number[], pitchSemitones: number): void {
  }

  onInterrupt(handler: (kind: AudioInterruptKind) => void): void {
  }

  isPrepared(): boolean {
    return false;
  }

  describeStream(): string {
    return 'mpv-unavailable';
  }

  release(): void {
  }
}
