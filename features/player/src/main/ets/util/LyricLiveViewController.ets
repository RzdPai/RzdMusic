/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { commonEventManager, BusinessError } from '@kit.BasicServicesKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { appendPlayLog, getAppRuntime, LiveViewConst, Logger } from 'musicbasic';
import { AmllLyricLine } from '../amll/model/AmllTypes';
import { amllGetCachedLyric, amllParseLyricCached } from '../amll/parse/AmllAutoDetect';

const TAG = 'LyricLiveViewController';

/** Capsule / card / lock screen text length limits of the live view templates. */
const CAPSULE_TEXT_MAX: number = 120;
const RICH_TEXT_MAX: number = 120;
const PRIMARY_TITLE_MAX: number = 200;
/** Minimum interval between two live view pushes (throttles word-level lyric updates). */
const MIN_PUSH_INTERVAL_MS: number = 500;
/** Icon in resources/rawfile shown by the live view pickup layout (mandatory). */
const LIVE_VIEW_ICON: string = 'liveview_icon.png';
/** Delay before parsing an uncached (large) lyric off the UI thread hot path. */
const LYRIC_PARSE_DELAY_MS: number = 250;

/**
 * Payload pushed to the lock screen immersive live view (initial parameters and
 * common event updates share this shape).
 */
export interface LiveViewLyricPayload {
  title: string;
  artist: string;
  curLine: string;
  nextLine: string;
  isPlaying: boolean;
}

/**
 * Owns the system live view (实况窗) of the music app:
 * creates the capsule + card, updates them on lyric line changes, ends the live
 * view when playback stops, and broadcasts lyric updates to the lock screen
 * immersive live view process via common events.
 *
 * Notes:
 * - Local live views can only be created while the app is in the foreground; all
 *   calls are best-effort and never affect playback.
 * - The lock screen extension runs in an independent process, so updates are
 *   pushed with common events; the initial payload travels in
 *   liveViewLockScreenAbilityParameters.
 */
export class LyricLiveViewController {
  /** True after startLiveView succeeds; gates updates and stop. */
  private isActive: boolean = false;
  /** True while an async start is in flight (prevents duplicate creation). */
  private isStarting: boolean = false;
  /** Parsed lyric lines of the current track. */
  private lines: AmllLyricLine[] = [];
  /** Last lyric line index pushed; -1 means nothing pushed yet. */
  private lastLineIndex: number = -1;
  /** Current song title (fallback text for capsule). */
  private curTitle: string = '';
  /** Current song artist. */
  private curSinger: string = '';
  /** Text of the current lyric line (empty when no lyric). */
  private curLineText: string = '';
  /** Text of the next lyric line (empty when none). */
  private nextLineText: string = '';
  /** Whether audio is currently playing. */
  private isPlaying: boolean = false;
  /** Cached want agent used as the click action of the live view. */
  private wantAgentInstance?: WantAgent = undefined;
  /** Timestamp of the last push; throttles word-level lyric updates. */
  private lastPushTime: number = 0;

  /**
   * Creates the live view for the given track. No-op when the live view is
   * already active/starting or the system live view switch is off.
   * @param title Resolved song title.
   * @param singer Resolved artist name.
   * @param lyricText Raw lyric text (LRC/AMLL/...) of the track.
   */
  public start(title: string, singer: string, lyricText: string): void {
    if (this.isActive || this.isStarting) {
      return;
    }
    this.isStarting = true;
    this.curTitle = title.length > 0 ? title : '正在播放';
    this.curSinger = singer;
    this.parseLines(lyricText);
    this.lastLineIndex = -1;
    void this.doStart();
  }

  /** Async body of {@link start}. */
  private async doStart(): Promise<void> {
    try {
      if (!await liveViewManager.isLiveViewEnabled()) {
        appendPlayLog('[实况窗] 系统实况窗开关未开启，跳过创建');
        return;
      }
      const agent: WantAgent | undefined = await this.getWantAgent();
      const liveView: liveViewManager.LiveView = this.buildLiveView(agent);
      const result: liveViewManager.LiveViewResult = await liveViewManager.startLiveView(liveView);
      if (result.resultCode === 0) {
        this.isActive = true;
        appendPlayLog('[实况窗] 创建成功');
        this.pushUpdate(liveView);
      } else {
        appendPlayLog('[实况窗] 创建失败 resultCode=' + result.resultCode + ' msg=' + result.message);
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      appendPlayLog('[实况窗] 创建异常 code=' + err.code + ' msg=' + err.message);
      Logger.warn(TAG, 'startLiveView failed: ' + err.code + ' ' + err.message);
    } finally {
      this.isStarting = false;
    }
  }

  /**
   * Re-parses lyric after an async lyric fill. Keeps the live view in sync even
   * when it was created before the lyric text arrived.
   * @param lyricText Updated raw lyric text.
   */
  public reloadLyric(lyricText: string): void {
    this.parseLines(lyricText);
    this.lastLineIndex = -1;
    if (this.isActive) {
      this.pushUpdate(this.buildLiveView(this.wantAgentInstance));
    }
  }

  /**
   * Switches the live view to another track (called on every queue index change).
   * Works whether the live view is already active or not yet created.
   * @param title Resolved song title.
   * @param singer Resolved artist name.
   * @param lyricText Raw lyric text of the new track.
   */
  public switchTrack(title: string, singer: string, lyricText: string): void {
    this.curTitle = title.length > 0 ? title : '正在播放';
    this.curSinger = singer;
    this.parseLines(lyricText);
    this.lastLineIndex = -1;
    this.curLineText = '';
    this.nextLineText = '';
    if (this.isActive) {
      this.pushUpdate(this.buildLiveView(this.wantAgentInstance));
    }
  }

  /**
   * Called on every playback time tick. Pushes an update only when the current
   * lyric line changed (natural throttle) or the play state changed.
   * @param progressMs Current playback position in ms.
   * @param playing Whether audio is playing.
   */
  public update(progressMs: number, playing: boolean): void {
    if (!this.isActive) {
      return;
    }
    const stateChanged: boolean = playing !== this.isPlaying;
    this.isPlaying = playing;
    const idx: number = this.findCurrentLineIndex(progressMs);
    if (idx !== this.lastLineIndex) {
      this.lastLineIndex = idx;
      this.curLineText = idx >= 0 ? this.joinLineWords(this.lines[idx]) : '';
      this.nextLineText = idx + 1 < this.lines.length ? this.joinLineWords(this.lines[idx + 1]) : '';
      this.pushUpdate(this.buildLiveView(this.wantAgentInstance));
    } else if (stateChanged) {
      this.pushUpdate(this.buildLiveView(this.wantAgentInstance));
    }
  }

  /**
   * Pushes a state update (play/pause) without waiting for the next lyric change.
   * @param playing Whether audio is playing.
   */
  public setPlaying(playing: boolean): void {
    if (!this.isActive || playing === this.isPlaying) {
      return;
    }
    this.isPlaying = playing;
    this.pushUpdate(this.buildLiveView(this.wantAgentInstance));
  }

  /** Ends the live view and resets all state. Best-effort. */
  public stop(): void {
    if (!this.isActive) {
      return;
    }
    const liveView: liveViewManager.LiveView = this.buildLiveView(this.wantAgentInstance);
    void liveViewManager.stopLiveView(liveView).then((result: liveViewManager.LiveViewResult) => {
      appendPlayLog('[实况窗] 结束 resultCode=' + result.resultCode);
    }).catch((err: BusinessError) => {
      appendPlayLog('[实况窗] 结束异常 code=' + err.code + ' msg=' + err.message);
      Logger.warn(TAG, 'stopLiveView failed: ' + err.code + ' ' + err.message);
    });
    this.isActive = false;
    this.lines = [];
    this.lastLineIndex = -1;
    this.curLineText = '';
    this.nextLineText = '';
  }

  /**
   * Parses lyric text into cached lines without blocking the UI thread.
   * A cache hit applies immediately; an uncached (large) lyric is parsed after a
   * short delay so switching tracks or returning to the foreground never stalls
   * the UI (same strategy as the lyric page).
   */
  private parseLines(lyricText: string): void {
    if (lyricText.length === 0) {
      this.lines = [];
      return;
    }
    const cached: AmllLyricLine[] | undefined = amllGetCachedLyric(lyricText);
    if (cached !== undefined) {
      this.lines = cached;
      return;
    }
    this.lines = [];
    const pendingText: string = lyricText;
    setTimeout((): void => {
      this.lines = amllParseLyricCached(pendingText);
      this.lastLineIndex = -1;
      if (this.isActive) {
        this.pushUpdate(this.buildLiveView(this.wantAgentInstance));
      }
    }, LYRIC_PARSE_DELAY_MS);
  }

  /** Joins the words of a lyric line into plain text. */
  private joinLineWords(line: AmllLyricLine): string {
    let text: string = '';
    for (let i = 0; i < line.words.length; i++) {
      text += line.words[i].word;
    }
    return text;
  }

  /** Locates the current lyric line at the given position (binary search, same semantics as the mini lyric). */
  private findCurrentLineIndex(progressMs: number): number {
    const len: number = this.lines.length;
    if (len === 0) {
      return -1;
    }
    let lo: number = 0;
    let hi: number = len - 1;
    let ans: number = -1;
    while (lo <= hi) {
      const mid: number = (lo + hi) >> 1;
      if (this.lines[mid].startTime <= progressMs) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  /** Truncates text to the capsule/card length limit (empty allowed). */
  private fitText(text: string, max: number): string {
    return text.length > max ? text.substring(0, max) : text;
  }

  /** Capsule title: current lyric line when available, otherwise the song title. */
  private capsuleText(): string {
    if (this.curLineText.trim().length === 0) {
      return this.fitText(this.curTitle, CAPSULE_TEXT_MAX);
    }
    return this.fitText(this.curLineText, CAPSULE_TEXT_MAX);
  }

  /** Card content lines: current lyric (with fallback) plus optional next line. */
  private primaryContent(): liveViewManager.RichText[] {
    const content: liveViewManager.RichText[] = [];
    const current: string = this.curLineText.trim().length > 0 ?
      this.fitText(this.curLineText, RICH_TEXT_MAX) : '暂无歌词';
    content.push({ text: current });
    if (this.nextLineText.trim().length > 0) {
      content.push({ text: this.fitText(this.nextLineText, RICH_TEXT_MAX) });
    }
    return content;
  }

  /**
   * Extension-area layout required by the TIMER event type. Without it
   * startLiveView rejects the request with 401 and the whole live view
   * (capsule / card / lock screen) fails.
   * LAYOUT_TYPE_PICKUP (emphasized text) is used to show the current lyric
   * line: the PROGRESS template additionally demands nodeIcons, which a music
   * player has no meaningful nodes for.
   */
  private progressLayoutData(): liveViewManager.PickupLayout {
    const line: string = this.curLineText.trim().length > 0 ? this.curLineText : '正在播放';
    const layout: liveViewManager.PickupLayout = {
      layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PICKUP,
      title: this.fitText(this.curTitle, 120),
      content: this.fitText(line, 120),
      descPic: LIVE_VIEW_ICON
    };
    return layout;
  }

  /** Builds the LiveView request body from the current state. */
  private buildLiveView(agent: WantAgent | undefined): liveViewManager.LiveView {
    const payload: LiveViewLyricPayload = {
      title: this.curTitle,
      artist: this.curSinger,
      curLine: this.curLineText,
      nextLine: this.nextLineText,
      isPlaying: this.isPlaying
    };
    const lockScreenParams: Record<string, string> = {};
    lockScreenParams[LiveViewConst.LIVE_VIEW_PARAM_KEY] = JSON.stringify(payload);
    const liveView: liveViewManager.LiveView = {
      id: LiveViewConst.LIVE_VIEW_ID,
      event: LiveViewConst.LIVE_VIEW_EVENT,
      isMute: true,
      liveViewData: {
        primary: {
          title: this.fitText(this.curTitle, PRIMARY_TITLE_MAX),
          content: this.primaryContent(),
          keepTime: 0,
          layoutData: this.progressLayoutData(),
          liveViewLockScreenAbilityName: LiveViewConst.LIVE_VIEW_LOCK_ABILITY,
          liveViewLockScreenAbilityParameters: lockScreenParams
        },
        capsule: {
          type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
          status: 1,
          title: this.capsuleText(),
          content: this.fitText(this.curSinger, CAPSULE_TEXT_MAX)
        }
      }
    };
    if (agent !== undefined) {
      liveView.liveViewData.primary.clickAction = agent;
    }
    return liveView;
  }

  /** Updates the live view card/capsule and broadcasts the payload to the lock screen. Throttled. */
  private pushUpdate(liveView: liveViewManager.LiveView): void {
    const now: number = Date.now();
    if (now - this.lastPushTime < MIN_PUSH_INTERVAL_MS) {
      return;
    }
    this.lastPushTime = now;
    void liveViewManager.updateLiveView(liveView).then((result: liveViewManager.LiveViewResult) => {
      if (result.resultCode !== 0) {
        Logger.warn(TAG, 'updateLiveView resultCode=' + result.resultCode + ' msg=' + result.message);
      }
    }).catch((err: BusinessError) => {
      Logger.warn(TAG, 'updateLiveView failed: ' + err.code + ' ' + err.message);
    });
    const payload: LiveViewLyricPayload = {
      title: this.curTitle,
      artist: this.curSinger,
      curLine: this.curLineText,
      nextLine: this.nextLineText,
      isPlaying: this.isPlaying
    };
    this.publishCommonEvent(JSON.stringify(payload));
  }

  /** Publishes the lyric payload so the lock screen process can refresh its UI. */
  private publishCommonEvent(payloadJson: string): void {
    try {
      const options: commonEventManager.CommonEventPublishData = {
        data: payloadJson
      };
      commonEventManager.publish(LiveViewConst.LIVE_VIEW_LYRIC_EVENT, options, (err: BusinessError) => {
        if (err) {
          Logger.warn(TAG, 'publish lyric event failed: ' + err.code + ' ' + err.message);
        }
      });
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      Logger.warn(TAG, 'publish lyric event error: ' + err.code + ' ' + err.message);
    }
  }

  /** Lazily builds and caches the want agent that opens the app from the live view. */
  private async getWantAgent(): Promise<WantAgent | undefined> {
    if (this.wantAgentInstance !== undefined) {
      return this.wantAgentInstance;
    }
    const ctx = getAppRuntime().context;
    if (ctx === undefined) {
      return undefined;
    }
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: ctx.abilityInfo.bundleName,
          abilityName: ctx.abilityInfo.name
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITIES,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      this.wantAgentInstance = await wantAgent.getWantAgent(wantAgentInfo);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      Logger.warn(TAG, 'getWantAgent failed: ' + err.code + ' ' + err.message);
    }
    return this.wantAgentInstance;
  }
}
