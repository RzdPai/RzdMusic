/*
 * Copyright (c) 2026 RzdPai
 *
 * 播放内核抽象层。
 *
 * 目的：让「系统播放器（AVPlayer）」与「第三方解码内核（FFmpeg/ijk，未来 mpv）」在 MediaService
 * 眼里是同一套接口 —— MediaService 只持有唯一状态机，内核只负责「出声 + 报进度」。
 *
 * 现状：
 * - `IjkAudioEngine`（@ohos/ijkplayer，FFmpeg audio-only）已实现本接口，用于汽水分片 mp4 / 开启音效的曲目；
 * - `MpvAudioEngine` 是**占位实现**：接口齐全但不可用（缺 `libmpv.so` 与 `libmpvnative` NAPI 包装），
 *   等拿到 arm64 的 `libmpv.so` 后只需把它的方法接到 NAPI，MediaService 一行不用改。
 *
 * 排查日志关键字：`RzdKernel`。
 */

import { appendPlayLog } from 'musicbasic';
import { AudioEffects } from './AudioEffects';

/** 内核种类。 */
export enum PlaybackKernelKind {
  /** 系统 AVPlayer（默认，万能但不支持分片 mp4 边下边播/音效）。 */
  AVPLAYER = 0,
  /** FFmpeg（通过 @ohos/ijkplayer 的纯音频通道）。 */
  /** libmpv（待接入）。 */
  MPV = 2
}

/** 音频焦点中断归一化结果。 */
export enum AudioInterruptKind {
  PAUSE = 0,
  RESUME = 1,
  STOP = 2
}

/** 内核回调：全部由 MediaService 提供，保证状态单一真源。 */
export interface AudioKernelCallbacks {
  /** 时长就绪（毫秒）。 */
  onDuration?: (durationMs: number) => void;
  /** 可播放（可以 start）。 */
  onPrepared?: () => void;
  /** 自然播放结束。 */
  onCompleted?: () => void;
  /** 出错（调用方回退或降级）。 */
  onError?: (code: number, message: string) => void;
}

/**
 * 播放内核接口。
 * 所有方法都必须**幂等且不抛异常**（内部自行 try/catch 并写日志）。
 */
export interface AudioKernel {
  /** 内核种类。 */
  kind(): PlaybackKernelKind;
  /** 创建并绑定回调。 */
  create(callbacks: AudioKernelCallbacks): void;
  /** 装载地址（http/https/file）。 */
  prepare(url: string): void;
  /** 开始/恢复。 */
  start(): void;
  /** 暂停。 */
  pause(): void;
  /** 跳转（毫秒）。 */
  seekTo(positionMs: number): void;
  /** 当前位置（毫秒）。 */
  position(): number;
  /** 总时长（毫秒）。 */
  duration(): number;
  /** 是否正在播放。 */
  isPlaying(): boolean;
  /** 音量 0~1。 */
  setVolume(volume: number): void;
  /** 变速。 */
  setSpeed(rate: number): void;
  /** 音效：5 段 EQ（dB）+ 升降调（半音）。 */
  applyTuning(eqGains: number[], pitchSemitones: number, effects: AudioEffects): void;
  /** 订阅音频焦点中断。 */
  onInterrupt(handler: (kind: AudioInterruptKind) => void): void;
  /** 是否已就绪。 */
  isPrepared(): boolean;
  /** 一句话描述当前流（排查用）。 */
  describeStream(): string;
  /** 释放（可重复调用）。 */
  release(): void;
  /** 音频输出后端：true=USB 独占（需外接 DAC），false=系统输出。 */
  applyUsbOutput?(enabled: boolean): void;
  /** @returns 当前实际生效的音频输出后端名（用于验证独占是否真的生效）。 */
  currentAo?(): string;
  /** @returns 实际输出参数（采样率/格式/声道），用于展示 bit-perfect 证据。 */
  audioOutParams?(): string;
  /** 起播前设置 UA/Referer/超时/重连等网络参数。 */
  prepareNetworkOptions?(): void;
  /** @returns 起播失败时的关键状态（诊断用）。 */
  probeState?(): string;
  /** 设置独占后端：usb / ohaudio / off。 */
  setUsbMode?(mode: string): void;
  /** @returns 可用音频输出驱动列表（诊断用）。 */
  listAoDrivers?(): string;
  /** @returns 当前 AO 的设备列表 JSON（诊断用）。 */
  listAudioDevices?(): string;
  /** 显式指定音频设备（空串=自动）。 */
  setAudioDevice?(name: string): void;
}

/** 内核种类 → 文案。 */
export function kernelName(kind: PlaybackKernelKind): string {
  switch (kind) {
    case PlaybackKernelKind.MPV:
      return 'mpv';
    default:
      return '系统播放器（AVPlayer）';
  }
}

/**
 * 记录一次内核切换（统一日志格式，便于 grep `RzdKernel`）。
 * @param from 原内核。
 * @param to 新内核。
 * @param reason 切换原因。
 */
export function logKernelSwitch(from: PlaybackKernelKind, to: PlaybackKernelKind, reason: string): void {
  appendPlayLog('[RzdKernel] ' + kernelName(from) + ' → ' + kernelName(to) + ' reason=' + reason);
}
