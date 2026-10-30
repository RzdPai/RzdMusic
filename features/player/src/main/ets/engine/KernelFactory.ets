/*
 * Copyright (c) 2026 RzdPai
 *
 * 内核工厂：把「用哪个第三方内核」收敛到一处。
 *
 * 现在的规则：
 * - 有 mpv（`MpvAudioEngine.isAvailable()` 为真，即 `libmpv.so` + `libmpvnative` 已打进包）→ 用 mpv；
 * - 否则用 FFmpeg（`@ohos/ijkplayer` 的纯音频通道）。
 *
 * 等到 mpv 可用时，**这里改都不用改**（`preferredKernel()` 会自动选 mpv），
 * `MediaService` 与 UI 也无需改动。
 */

import { AudioKernel, PlaybackKernelKind } from './AudioKernel';
import { IjkAudioEngine } from './IjkAudioEngine';
import { MpvAudioEngine } from './MpvAudioEngine';

/**
 * @returns 当前进程内优先使用的第三方内核。
 * AVPlayer 不在这里（它是系统内置、不走工厂）。
 */
export function preferredKernel(): PlaybackKernelKind {
  if (MpvAudioEngine.isAvailable()) {
    return PlaybackKernelKind.MPV;
  }
  return PlaybackKernelKind.FFMPEG;
}

/**
 * 按种类创建内核实例。
 * @param kind 内核种类；`AVPLAYER` 属于错误用法（返回 FFmpeg 兜底）。
 */
export function createKernel(kind: PlaybackKernelKind): AudioKernel {
  switch (kind) {
    case PlaybackKernelKind.MPV:
      return new MpvAudioEngine();
    case PlaybackKernelKind.FFMPEG:
      return new IjkAudioEngine();
    default:
      // AVPlayer 由 MediaService 自己管理，工厂里给一个 FFmpeg 兜底避免返回 undefined
      return new IjkAudioEngine();
  }
}

/** @returns mpv 内核是否可用（供 UI 显示与开关判断）。 */
export function isMpvAvailable(): boolean {
  return MpvAudioEngine.isAvailable();
}
