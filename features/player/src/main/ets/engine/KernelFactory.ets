/*
 * Copyright (c) 2026 RzdPai
 *
 * 内核工厂：把「用哪个第三方内核」收敛到一处。
 *
 * 现状（2026-10-31）：第三方内核只有 **mpv**（`libmpv.so` + `libmpvnative` 已打进包）。
 * AVPlayer 是系统内置、不经过本工厂。
 *
 * 历史：早期用 `@ohos/ijkplayer`（FFmpeg audio-only）作为过渡内核，mpv 跑通后已整体移除。
 * 若某天 mpv 不可用（例如换机型漏打包 so），`MpvAudioEngine` 会在 create 时回调 onError，
 * MediaService 的自愈逻辑会回落到 AVPlayer。
 */

import { AudioKernel, PlaybackKernelKind } from './AudioKernel';
import { MpvAudioEngine } from './MpvAudioEngine';

/**
 * @returns 当前进程内优先使用的第三方内核（现在恒为 mpv）。
 */
export function preferredKernel(): PlaybackKernelKind {
  return PlaybackKernelKind.MPV;
}

/**
 * 按种类创建内核实例。
 * @param kind 内核种类；`AVPLAYER` 属于错误用法（统一回落 mpv 实例）。
 */
export function createKernel(kind: PlaybackKernelKind): AudioKernel {
  switch (kind) {
    case PlaybackKernelKind.MPV:
      return new MpvAudioEngine();
    default:
      // AVPlayer 由 MediaService 自己管理；这里统一返回 mpv
      return new MpvAudioEngine();
  }
}

/** @returns mpv 内核是否可用（供 UI 显示与开关判断）。 */
export function isMpvAvailable(): boolean {
  return MpvAudioEngine.isAvailable();
}
