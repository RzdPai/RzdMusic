/*
 * Copyright (c) 2026 RzdPai
 *
 * 「定时关闭」服务（用户 2026-11-28：「播放页的歌曲菜单里面加个定时关闭」）。
 *
 * 为什么单独一个服务而不是塞进 MediaService：
 *   · 倒计时是**跨页面/跨曲目**的（播放页关掉、切到别的页签也要继续走），
 *     放进某个组件的 @Local 会随组件销毁丢失；
 *   · 到点时只需要"暂停播放 + 提示一句"，用回调注入，避免与 MediaService 互相 import
 *     形成环（本文件不 import MediaService）。
 *
 * 两种模式：
 *   · 定时 N 分钟：到点暂停；
 *   · 播完当前歌曲：本曲自然播完、换下一首的那一刻暂停（不等下一首真正开播）。
 *
 * 排查关键字：`RzdSleepTimer`。
 */

import { Logger } from 'musicbasic';

/** 定时关闭的当前状态（给 UI 读，纯值对象）。 */
export class SleepTimerStatus {
  /** 是否有定时在跑。 */
  public active: boolean = false;
  /** 剩余毫秒（播完当前歌曲模式下为 0）。 */
  public remainMs: number = 0;
  /** 是否为"播完当前歌曲"模式。 */
  public afterTrack: boolean = false;
}

/** 可选的定时时长（分钟）。 */
export const SLEEP_TIMER_MINUTES: number[] = [15, 30, 45, 60, 90];

/** 服务单例（进程内唯一）。 */
export class SleepTimerService {
  private static instance: SleepTimerService | null = null;
  private static readonly tag: string = 'RzdSleepTimer';

  /** 到点执行的动作（由 MediaService 注册：暂停 + 提示）。 */
  public fireHandler: ((reason: string) => void) | null = null;

  /** 到点时间戳（0 = 没有定时）。 */
  private deadlineMs: number = 0;
  private timerId: number = -1;
  /** "播完当前歌曲"模式。 */
  private afterTrack: boolean = false;
  /** 布防时的曲目序号（用来识别"换曲了"）。 */
  private armedIndex: number = -1;

  public static getInstance(): SleepTimerService {
    if (SleepTimerService.instance === null) {
      SleepTimerService.instance = new SleepTimerService();
    }
    return SleepTimerService.instance;
  }

  /**
   * 注册到点动作（只装一次；已装过就忽略）。
   * @param fire 到点要做的事（MediaService 注入：暂停 + 提示）
   */
  public ensureHooked(fire: () => void): void {
    if (this.fireHandler !== null) {
      return;
    }
    this.fireHandler = (reason: string): void => {
      Logger.info(SleepTimerService.tag, 'fire ' + reason);
      fire();
    };
  }

  /** @returns 当前状态（给菜单行显示用）。 */
  public status(): SleepTimerStatus {
    const s: SleepTimerStatus = new SleepTimerStatus();
    s.afterTrack = this.afterTrack;
    if (this.afterTrack) {
      s.active = true;
      return s;
    }
    if (this.deadlineMs > 0) {
      s.active = true;
      s.remainMs = Math.max(0, this.deadlineMs - Date.now());
    }
    return s;
  }

  /** 剩余时间文案（`12:34`），没有定时时返回空串。 */
  public remainText(): string {
    const s: SleepTimerStatus = this.status();
    if (!s.active) {
      return '';
    }
    if (s.afterTrack) {
      return '播完本曲';
    }
    const total: number = Math.floor(s.remainMs / 1000);
    const mm: number = Math.floor(total / 60);
    const ss: number = total % 60;
    return (mm < 10 ? '0' : '') + mm + ':' + (ss < 10 ? '0' : '') + ss;
  }

  /**
   * 定时 N 分钟后暂停播放。
   * @param minutes 分钟数（<=0 视为取消）
   */
  public startMinutes(minutes: number): void {
    this.clearTimer();
    if (minutes <= 0) {
      return;
    }
    this.afterTrack = false;
    this.armedIndex = -1;
    this.deadlineMs = Date.now() + minutes * 60 * 1000;
    const ms: number = minutes * 60 * 1000;
    this.timerId = setTimeout((): void => {
      this.fire(minutes + ' 分钟定时到点，已暂停播放');
    }, ms);
    Logger.info(SleepTimerService.tag, 'arm minutes=' + minutes + ' deadline=' + this.deadlineMs);
  }

  /**
   * 播完当前歌曲后暂停。
   * @param currentIndex 当前曲目在队列里的序号（换到别的序号即视为本曲结束）
   */
  public startAfterCurrentTrack(currentIndex: number): void {
    this.clearTimer();
    this.afterTrack = true;
    this.armedIndex = currentIndex;
    this.deadlineMs = 0;
    Logger.info(SleepTimerService.tag, 'arm afterTrack index=' + currentIndex);
  }

  /** 取消定时（菜单里选「关闭定时」或用户手动取消）。 */
  public cancel(): void {
    const wasActive: boolean = this.status().active;
    this.clearTimer();
    if (wasActive) {
      Logger.info(SleepTimerService.tag, 'cancel');
    }
  }

  /**
   * 换曲通知（由 `MediaService.updateMusicIndex()` 调用）。
   *
   * "播完当前歌曲"模式就是靠这里判定：序号变了 = 上一首已经播完。
   * @param index 新的曲目序号
   */
  public onTrackChanged(index: number): void {
    if (!this.afterTrack) {
      return;
    }
    if (this.armedIndex >= 0 && index === this.armedIndex) {
      return;   // 同一个序号（例如只重载了地址）不算换曲
    }
    this.fire('已播完当前歌曲，定时关闭已生效');
  }

  private clearTimer(): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    this.deadlineMs = 0;
    this.afterTrack = false;
    this.armedIndex = -1;
  }

  /** 到点：先复位状态再执行动作（避免动作里再读到"还在定时"）。 */
  private fire(reason: string): void {
    this.clearTimer();
    Logger.info(SleepTimerService.tag, 'fire reason=' + reason);
    const handler: ((reason: string) => void) | null = this.fireHandler;
    if (handler !== null) {
      handler(reason);
    }
  }
}
