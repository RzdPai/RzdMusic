/*
 * Copyright (c) 2026 RzdPai
 *
 * libmpv 内核（NAPI 直连）。
 *
 * 结构：
 *   ArkTS（本文件） ⇄ libmpvnative.so（src/main/cpp/mpv_bridge.cpp） ⇄ libmpv.so（预编译，src/main/libs/arm64-v8a）
 *
 * 说明：
 * - 桥是**同步**的，因此这里不用事件循环：`prepare()` 里起一个 250ms 轮询，
 *   等 `duration > 0` 就回调 `onPrepared`；位置/时长由 MediaService 自己的轮询读取。
 * - 音效走 mpv 的 `af` 属性（`equalizer=…` + `rubberband=pitch=…`），与 FFmpeg 通道语义一致。
 * - USB 独占（未启用）：`setProperty('ao', 'usb-exclusive')` + `usb-exclusive-fd`，需要 USBManager 授权 fd。
 *
 * 排查日志关键字：`RzdMpv`。
 */

import mpvNative from 'libmpvnative.so';
import { appendPlayLog } from 'musicbasic';
import {
  AudioKernel,
  AudioKernelCallbacks,
  AudioInterruptKind,
  PlaybackKernelKind
} from './AudioKernel';

/** EQ 频段（Hz），与播放设置面板一致。 */
const EQ_BANDS: number[] = [60, 230, 910, 3600, 14000];

export class MpvAudioEngine implements AudioKernel {
  private callbacks: AudioKernelCallbacks = {};
  private readonly tag: string = '[RzdMpv]';
  private created: boolean = false;
  private prepared: boolean = false;
  private reportedPrepared: boolean = false;
  private readyTimer: number = -1;
  private released: boolean = false;

  /**
   * @returns 内核是否可用（真正探测：建一次 mpv 实例）。
   */
  static isAvailable(): boolean {
    try {
      const ok: boolean = mpvNative.isAvailable();
      appendPlayLog('[RzdKernel] mpv 探测=' + ok);
      return ok;
    } catch (err) {
      appendPlayLog('[RzdKernel] mpv 探测失败（未打包 libmpvnative/libmpv）');
      return false;
    }
  }

  kind(): PlaybackKernelKind {
    return PlaybackKernelKind.MPV;
  }

  create(callbacks: AudioKernelCallbacks): void {
    this.callbacks = callbacks;
    this.released = false;
    this.prepared = false;
    this.reportedPrepared = false;
    try {
      this.created = mpvNative.create();
      if (!this.created) {
        appendPlayLog(this.tag + ' create 失败');
        this.fail(-1, 'mpv_create failed');
        return;
      }
      // 音频播放的默认参数（桥里也设了一份，这里显式再写一次便于日志追溯）
      mpvNative.setProperty('pause', 'yes');
      mpvNative.setProperty('volume', '100');
      appendPlayLog(this.tag + ' create ok');
    } catch (err) {
      appendPlayLog(this.tag + ' create 异常（libmpvnative 未就绪）');
      this.fail(-1, 'mpv module missing');
    }
  }

  prepare(url: string): void {
    if (!this.created) {
      this.fail(-1, 'mpv not created');
      return;
    }
    this.prepared = false;
    this.reportedPrepared = false;
    appendPlayLog(this.tag + ' prepare url=' + url.substring(0, Math.min(url.length, 90)));
    const ok: boolean = mpvNative.command(['loadfile', url]);
    if (!ok) {
      appendPlayLog(this.tag + ' loadfile 失败');
      this.fail(-1, 'loadfile failed');
      return;
    }
    // mpv 没有 prepared 回调，用轮询探测 duration
    this.stopReadyTimer();
    this.readyTimer = setInterval((): void => {
      if (this.released) {
        this.stopReadyTimer();
        return;
      }
      const duration: number = this.duration();
      if (duration > 0) {
        this.prepared = true;
        this.stopReadyTimer();
        appendPlayLog(this.tag + ' prepared duration=' + duration);
        if (this.callbacks.onDuration !== undefined) {
          this.callbacks.onDuration(duration);
        }
        if (!this.reportedPrepared) {
          this.reportedPrepared = true;
          if (this.callbacks.onPrepared !== undefined) {
            this.callbacks.onPrepared();
          }
        }
      }
    }, 250);
  }

  start(): void {
    this.write('pause', 'no');
  }

  pause(): void {
    this.write('pause', 'yes');
  }

  seekTo(positionMs: number): void {
    const seconds: string = (Math.max(0, positionMs) / 1000).toFixed(3);
    try {
      mpvNative.command(['seek', seconds, 'absolute']);
      appendPlayLog(this.tag + ' seek=' + positionMs);
    } catch (err) {
      appendPlayLog(this.tag + ' seek 异常');
    }
  }

  position(): number {
    return this.readNumber('time-pos', 1) ;
  }

  duration(): number {
    return this.readNumber('duration', 1);
  }

  isPlaying(): boolean {
    return this.read('pause') === 'no';
  }

  setVolume(volume: number): void {
    const v: number = Math.max(0, Math.min(1, volume));
    this.write('volume', (v * 100).toFixed(0));
  }

  setSpeed(rate: number): void {
    this.write('speed', Math.max(0.25, Math.min(4, rate)).toFixed(3));
  }

  applyTuning(eqGains: number[], pitchSemitones: number): void {
    const filters: string[] = [];
    for (let i: number = 0; i < EQ_BANDS.length && i < eqGains.length; i++) {
      if (eqGains[i] === 0) {
        continue;
      }
      filters.push('equalizer=f=' + EQ_BANDS[i].toString() + ':t=o:w=1:g=' + eqGains[i].toFixed(1));
    }
    if (pitchSemitones !== 0) {
      const ratio: number = Math.pow(2, pitchSemitones / 12);
      filters.push('rubberband=pitch=' + ratio.toFixed(4));
    }
    const chain: string = filters.join(',');
    this.write('af', chain);
    appendPlayLog(this.tag + ' af=' + chain);
  }

  onInterrupt(handler: (kind: AudioInterruptKind) => void): void {
    // mpv 的音频焦点由系统 OHAudio 输出层处理；这里保持接口一致（MediaService 的暂停策略仍生效）
    appendPlayLog(this.tag + ' onInterrupt 注册（由 MediaService 的暂停策略兜底）');
  }

  isPrepared(): boolean {
    return this.prepared;
  }

  describeStream(): string {
    return 'codec=' + this.read('audio-codec-name') + ' format=' + this.read('file-format') +
      ' ao=' + this.read('current-ao');
  }

  release(): void {
    this.released = true;
    this.stopReadyTimer();
    try {
      if (this.created) {
        mpvNative.command(['stop']);
        mpvNative.destroy();
      }
    } catch (err) {
    }
    this.created = false;
    this.prepared = false;
    appendPlayLog(this.tag + ' release');
  }

  // ===== 内部工具 =====

  /** 写属性（失败只记日志，不抛）。 */
  private write(name: string, value: string): void {
    if (!this.created) {
      return;
    }
    try {
      mpvNative.setProperty(name, value);
    } catch (err) {
      appendPlayLog(this.tag + ' setProperty ' + name + ' 异常');
    }
  }

  /** 读属性（失败返回空串）。 */
  private read(name: string): string {
    if (!this.created) {
      return '';
    }
    try {
      const value: string = mpvNative.getProperty(name);
      return value !== undefined && value !== null ? value : '';
    } catch (err) {
      return '';
    }
  }

  /** 读数值属性并按倍率换算（标度=1 表示秒→毫秒用 1000）。 */
  private readNumber(name: string, scale: number): number {
    const raw: string = this.read(name);
    if (raw.length === 0) {
      return 0;
    }
    const value: number = Number(raw);
    if (Number.isNaN(value)) {
      return 0;
    }
    return Math.round(value * 1000 * scale) / scale;
  }

  private stopReadyTimer(): void {
    if (this.readyTimer >= 0) {
      clearInterval(this.readyTimer);
      this.readyTimer = -1;
    }
  }

  private fail(code: number, message: string): void {
    if (this.callbacks.onError !== undefined) {
      this.callbacks.onError(code, message);
    }
  }
}
