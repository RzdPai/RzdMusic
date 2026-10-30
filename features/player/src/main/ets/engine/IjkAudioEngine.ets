/*
 * Copyright (c) 2026 RzdPai
 *
 * 汽水专用音频引擎（FFmpeg 内核，audio-only）。
 *
 * 为什么需要它：汽水脚本给的是 douyinvod 的**分片 mp4**（`mime_type=audio_mp4`，浏览器 MSE 用），
 * ArkUI `AVPlayer` 能 prepared 拿到总时长，但边下边播解不出分片索引 ⇒ 进度恒 0、无声音。
 * `@ohos/ijkplayer`（ohpm，LGPLv2.1+，基于 FFmpeg）走的是 libavformat + SoundTouch，
 * 这类流可以正常播放，而且它的 `setAudioId()` 就是**纯音频**通道（不需要 Surface）。
 *
 * 本类只做三件事：装载、播放控制、把进度/时长回吐给调用方（MediaService）。
 * 真正的状态机仍由 MediaService 持有，避免出现第二套播放状态。
 */

import { IjkMediaPlayer, InterruptEvent, InterruptForceType, InterruptHintType } from '@ohos/ijkplayer';
import { BusinessError } from '@kit.BasicServicesKit';
import { appendPlayLog } from 'musicbasic';
import {
  AudioKernel,
  AudioKernelCallbacks,
  AudioInterruptKind,
  PlaybackKernelKind
} from './AudioKernel';



/**
 * 纯音频 IJK 引擎封装。
 * 用法：`create()` → `load(url)` → `start()` → `seekTo(ms)` … → `release()`。
 */
export class IjkAudioEngine implements AudioKernel {
  private player: IjkMediaPlayer | undefined = undefined;
  private callbacks: AudioKernelCallbacks = {};
  private readonly tag: string = '[RzdIjk]';
  private prepared: boolean = false;
  private released: boolean = false;
  /** 上一次下发的 af 链：相同则跳过。 */
  private lastAf: string = '';

  /** @returns 单例 id（IJK 的 native 句柄以字符串 id 区分）。 */
  private static nextId(): string {
    return 'rzd-' + Date.now().toString();
  }

  /**
   * 创建引擎实例。
   * @param callbacks 进度/完成/错误回调。
   */
  create(callbacks: AudioKernelCallbacks): void {
    this.callbacks = callbacks;
    const id: string = IjkAudioEngine.nextId();
    const player: IjkMediaPlayer = new IjkMediaPlayer(id);
    // ★ setAudioId 走 libijkplayer_audio_napi（纯音频，不创建 Surface）
    player.setAudioId(id);
    player.setDebug(false);
    player.setOnPreparedListener({
      onPrepared: (): void => {
        this.prepared = true;
        appendPlayLog(this.tag + ' prepared id=' + id);
        if (this.callbacks.onPrepared !== undefined) {
          this.callbacks.onPrepared();
        }
        const duration: number = player.getDuration();
        if (this.callbacks.onDuration !== undefined && duration > 0) {
          this.callbacks.onDuration(duration);
        }
      }
    });
    player.setOnCompletionListener({
      onCompletion: (): void => {
        appendPlayLog(this.tag + ' completed');
        if (this.callbacks.onCompleted !== undefined) {
          this.callbacks.onCompleted();
        }
      }
    });
    player.setOnErrorListener({
      onError: (_what: number, _extra: number): void => {
        appendPlayLog(this.tag + ' error what=' + _what + ' extra=' + _extra);
        if (this.callbacks.onError !== undefined) {
          this.callbacks.onError(_what, 'ijk error ' + _extra);
        }
      }
    });
    this.player = player;
    appendPlayLog(this.tag + ' create id=' + id);
  }

  /** @returns 内核种类。 */
  kind(): PlaybackKernelKind {
    return PlaybackKernelKind.FFMPEG;
  }

  /** AudioKernel 接口名（等价于 load）。 */
  prepare(url: string): void {
    this.load(url);
  }
  /** 装载地址（http/https/file）。 */
  load(url: string): void {
    if (this.player === undefined) {
      return;
    }
    this.prepared = false;
    appendPlayLog(this.tag + ' load url=' + url.substring(0, Math.min(url.length, 90)));
    this.player.setDataSource(url);
    this.player.prepareAsync();
  }

  /**
   * 订阅系统音频焦点中断（来电/语音输入/其它 App 抢占）。
   * @param handler PAUSE=被抢占需暂停；RESUME=可以恢复；STOP=永久失去焦点。
   */
  onInterrupt(handler: (kind: AudioInterruptKind) => void): void {
    if (this.player === undefined) {
      return;
    }
    try {
      this.player.on('audioInterrupt', (event: InterruptEvent): void => {
        const forced: boolean = event.forceType === InterruptForceType.INTERRUPT_FORCE;
        const hint: InterruptHintType = event.hintType ?? InterruptHintType.INTERRUPT_HINT_NONE;
        appendPlayLog(this.tag + ' audioInterrupt force=' + forced + ' hint=' + hint);
        if (hint === InterruptHintType.INTERRUPT_HINT_PAUSE) {
          this.pause();
          handler(AudioInterruptKind.PAUSE);
        } else if (hint === InterruptHintType.INTERRUPT_HINT_STOP) {
          this.pause();
          handler(AudioInterruptKind.STOP);
        } else if (hint === InterruptHintType.INTERRUPT_HINT_RESUME) {
          handler(AudioInterruptKind.RESUME);
        }
      });
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      appendPlayLog(this.tag + ' 订阅 audioInterrupt 失败 code=' + e.code);
    }
  }
  /** 开始/恢复播放。 */
  start(): void {
    if (this.player === undefined) {
      return;
    }
    try {
      this.player.start();
      appendPlayLog(this.tag + ' start');
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      appendPlayLog(this.tag + ' start 失败 code=' + e.code);
    }
  }

  pause(): void {
    if (this.player === undefined) {
      return;
    }
    try {
      this.player.pause();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      appendPlayLog(this.tag + ' pause 失败 code=' + e.code);
    }
  }

  /** 跳转（毫秒）。 */
  seekTo(positionMs: number): void {
    if (this.player === undefined) {
      return;
    }
    try {
      this.player.seekTo(Math.max(0, Math.round(positionMs)).toString());
      appendPlayLog(this.tag + ' seek=' + positionMs);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      appendPlayLog(this.tag + ' seek 失败 code=' + e.code);
    }
  }

  /** @returns 当前位置（毫秒）；未就绪返回 0。 */
  position(): number {
    if (this.player === undefined || !this.prepared) {
      return 0;
    }
    try {
      return this.player.getCurrentPosition();
    } catch (err) {
      return 0;
    }
  }

  /** @returns 总时长（毫秒）；未知返回 0。 */
  duration(): number {
    if (this.player === undefined) {
      return 0;
    }
    try {
      return this.player.getDuration();
    } catch (err) {
      return 0;
    }
  }

  /** @returns 是否正在播放。 */
  isPlaying(): boolean {
    if (this.player === undefined) {
      return false;
    }
    try {
      return this.player.isPlaying();
    } catch (err) {
      return false;
    }
  }

  /** 音量（0~1）。 */
  setVolume(volume: number): void {
    if (this.player === undefined) {
      return;
    }
    const v: number = Math.max(0, Math.min(1, volume));
    try {
      this.player.setVolume(v.toString(), v.toString());
    } catch (err) {
    }
  }

  /**
   * 尽力而为地把「升降调 + 5 段 EQ」下发给 FFmpeg（ijk 的 player 选项 `af`）。
   *
   * 说明：这是**实验性**能力 —— ijkplayer 的 `af` 选项是否编进本 HAR 的 FFmpeg 里，
   * 取决于它的构建配置；不支持时 FFmpeg 一般只打一条 "Option af not found" 警告，
   * 不影响播放。全部参数非默认时才下发，避免给普通播放增加开销。
   * @param eqGains 5 段增益（dB），对应 60/230/910/3.6k/14k。
   * @param pitchSemitones 升降调半音数（0=原调）。
   */
  applyTuning(eqGains: number[], pitchSemitones: number): void {
    if (this.player === undefined) {
      return;
    }
    const bands: number[] = [60, 230, 910, 3600, 14000];
    const filters: string[] = [];
    for (let i: number = 0; i < bands.length && i < eqGains.length; i++) {
      const gain: number = eqGains[i];
      if (gain === 0) {
        continue;
      }
      filters.push('equalizer=f=' + bands[i].toString() + ':t=o:w=1:g=' + gain.toFixed(1));
    }
    if (pitchSemitones !== 0) {
      const ratio: number = Math.pow(2, pitchSemitones / 12);
      // rubberband 最准；没编进去就退回 asetrate 变速 + atempo 修正时长
      filters.push('rubberband=pitch=' + ratio.toFixed(4));
    }
    if (filters.length === 0) {
      return;
    }
    const chain: string = filters.join(',');
    if (chain === this.lastAf) {
      return;
    }
    this.lastAf = chain;
    try {
      this.player.setOption('4', 'af', chain);
      appendPlayLog(this.tag + ' af=' + chain);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      appendPlayLog(this.tag + ' af 下发失败 code=' + e.code);
    }
  }
  /** 变速（1.0 = 原速）。 */
  setSpeed(rate: number): void {
    if (this.player === undefined) {
      return;
    }
    try {
      this.player.setSpeed(Math.max(0.25, Math.min(4, rate)).toString());
      appendPlayLog(this.tag + ' speed=' + rate);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      appendPlayLog(this.tag + ' setSpeed 失败 code=' + e.code);
    }
  }
  /** 释放（可重复调用）。 */
  release(): void {
    if (this.player === undefined || this.released) {
      return;
    }
    this.released = true;
    try {
      this.player.stop();
    } catch (err) {
    }
    try {
      this.player.release();
    } catch (err) {
    }
    this.player = undefined;
    this.prepared = false;
    appendPlayLog(this.tag + ' release');
  }

  /**
   * @returns 一句可读的流信息（音频解码器 + 媒体元数据），用于排查
   * 「ijk 到底拿到没拿到音频轨」：如果 audioDecoder 为空，说明根本没解出音频流。
   */
  describeStream(): string {
    if (this.player === undefined) {
      return 'no-player';
    }
    try {
      const info: object = this.player.getMediaInfo();
      const audio: string = (info as Record<string, string>)['audioDecoder'] ?? '';
      const meta: string = (info as Record<string, string>)['meta'] ?? '';
      return 'audioDecoder=' + (audio.length > 0 ? audio : '(空)') +
        ' meta=' + meta.substring(0, Math.min(meta.length, 120));
    } catch (err) {
      return 'describe-failed';
    }
  }
  /** @returns 是否已就绪。 */
  isPrepared(): boolean {
    return this.prepared;
  }
}
