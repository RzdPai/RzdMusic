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

import { IjkMediaPlayer } from '@ohos/ijkplayer';
import { BusinessError } from '@kit.BasicServicesKit';
import { appendPlayLog } from 'musicbasic';

/** 一次播放的回调集合（全部由 MediaService 提供，保持单一状态源）。 */
export interface IjkAudioCallbacks {
  /** 时长就绪（毫秒）。 */
  onDuration?: (durationMs: number) => void;
  /** 首帧/首包就绪，可以真正 start 了。 */
  onPrepared?: () => void;
  /** 播放完成（自然结束）。 */
  onCompleted?: () => void;
  /** 出错：调用方通常回退到 AVPlayer 或跨源重试。 */
  onError?: (code: number, message: string) => void;
}

/**
 * 纯音频 IJK 引擎封装。
 * 用法：`create()` → `load(url)` → `start()` → `seekTo(ms)` … → `release()`。
 */
export class IjkAudioEngine {
  private player: IjkMediaPlayer | undefined = undefined;
  private callbacks: IjkAudioCallbacks = {};
  private readonly tag: string = '[RzdIjk]';
  private prepared: boolean = false;
  private released: boolean = false;

  /** @returns 单例 id（IJK 的 native 句柄以字符串 id 区分）。 */
  private static nextId(): string {
    return 'rzd-' + Date.now().toString();
  }

  /**
   * 创建引擎实例。
   * @param callbacks 进度/完成/错误回调。
   */
  create(callbacks: IjkAudioCallbacks): void {
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

  /** @returns 是否已就绪。 */
  isPrepared(): boolean {
    return this.prepared;
  }
}
