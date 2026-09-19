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

/*
 * Moved from common/mediacommon/src/main/ets/utils/MediaService.ets
 */

import { AppStorageV2 } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { smartMobilityCommon } from '@kit.CarKit';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { common, wantAgent } from '@kit.AbilityKit';
import { avSession } from '@kit.AVSessionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { resourceManager } from '@kit.LocalizationKit';
import { AppStorageKeys, getAppRuntime, Logger, MusicAppState, MusicCardBridge, MusicStoreService, PlayedSongRecord, SongItem, StringResourceUtil, appendPlayLog } from 'musicbasic';
import SongItemBuilder from '../util/SongItemBuilder';
import { AudioPlayerState, MusicPlayMode } from './MusicData';
import { BackgroundUtil } from '../util/BackgroundUtil';
import { MediaTools } from '../util/MediaTools';
import { lxGetLyricFull, lxGetPicFallback, lxGetTTMLLyric,
  LyricFullResult } from '../source/LXMusicSDK';
import { lxEngineIsReady } from '../source/LXSourceEngine';
import { FallbackOptions, QUALITY_TIER_COOLDOWN_MS, QUALITY_TIER_FAIL_THRESHOLD, UrlResolveOutcome, qualityTierKey, resolveMusicUrlWithFallback } from '../util/SourceFallbackUtil';
import { SwitchBannerState } from '../model/SwitchBannerState';
import { amllGetCachedLyric, amllParseLyricCached } from '../amll/parse/AmllAutoDetect';
import { AmllLyricLine } from '../amll/model/AmllTypes';
import { buildPlainLrc, truncateLrc } from '../util/LrcUtils';
import { LyricLiveViewController } from '../util/LyricLiveViewController';

const TAG = 'MediaService';

/** Persisted play queue snapshot: online records, local db ids, and current index. */
interface QueueSnapshot {
  online: PlayedSongRecord[];
  localIds: number[];
  index: number;
}

/**
 * Coordinates local audio playback (AVPlayer), shared UI state (MusicAppState), and system AVSession.
 */
export class MediaService {
  /** UIAbility context from application runtime; used for resources, want agent, and background task. */
  private get abilityContext(): common.UIAbilityContext | undefined {
    return getAppRuntime().context;
  }
  /** Underlying Harmony AVPlayer; undefined until createAVPlayer succeeds. */
  public avPlayer?: media.AVPlayer;
  /** Active AV session for lock screen / headset / system media controls. */
  private session?: avSession.AVSession;
  private audioManager: audio.AudioManager | undefined = undefined;
  private routingCallback: ((action: audio.DeviceChangeAction) => void) | undefined = undefined;
  /** Audio session manager for cross-app concurrency policy (play alongside other apps). */
  private sessionManager?: audio.AudioSessionManager;
  /** Builds SongItem and fd/url descriptor for AVPlayer.fdSrc. */
  private songItemBuilder: SongItemBuilder = new SongItemBuilder();
  /** Resolved current track metadata for internal use. */
  private songItem: SongItem = new SongItem();
  /** Current repeat / shuffle mode. */
  private playMode: MusicPlayMode = MusicPlayMode.ORDER;
  /** True when the last-played song has been restored on startup. */
  private lastSongRestored: boolean = false;
  /** True when the full play queue snapshot has been restored on startup. */
  private lastQueueRestored: boolean = false;
  /** AVPlayer high-level lifecycle state mirror. */
  private state: AudioPlayerState = AudioPlayerState.IDLE;
  /** True until the first fdSrc has been applied on this player instance. */
  private isFirst: boolean = true;
  /** True after successful prepare() for the current fdSrc. */
  private isPrepared: boolean = false;
  /** Current index within the play queue (aligned with MusicAppState.selectIndex after update). */
  private musicIndex: number = 0;
  /** True when displayed progress should track AVPlayer time updates (false during seek). */
  private isCurrent: boolean = true;
  /** When false, prepared state will not auto-start play (e.g. load-only). */
  private isNeedPlay: boolean = true;
  /** Queue index to load once AVPlayer is ready; -1 means none. */
  private pendingLoadIndex: number = -1;
  /** Whether the pending load should skip starting playback. */
  private pendingLoadOnly: boolean = false;
  /** True while playback was paused by a temporary audio interruption and should auto-resume. */
  private pausedByInterrupt: boolean = false;
  /** True after we've already attempted one cross-source fallback for the current track; prevents
   *  an infinite loop when the fallback source also fails AVPlayer. */
  private hasFallbackOnce: boolean = false;
  /** Playback URL that failed last; the fallback must never hand it back. */
  private failedUrl: string = '';
  /** Quality id that failed last; skipped when rebuilding the retry chain. */
  private failedQuality: string = '';
  /**
   * True while a playback error is waiting for its deferred (500ms) fallback
   * retry. Must NOT be derived from this.state: avPlayer.reset() asynchronously
   * lands in 'idle' and overwrites ERROR before the timer fires, which used to
   * silently swallow the whole fallback chain.
   */
  private errorRecoveryPending: boolean = false;
  /** Last known HiCar status: -1 unknown, 0 idle, 1 running. */
  private lastHiCarStatus: number = -1;
  /** Owns the system live view (实况窗) lifecycle and lock screen lyric sync. */
  private liveViewController: LyricLiveViewController = new LyricLiveViewController();

  /** AVPlayer seekDone: marks seek finished and updates AVSession position. */
  private seekCall: (seekDoneTime: number) => void = (seekDoneTime: number) => {
    this.isCurrent = true;
    Logger.info(TAG, `AVPlayer seek succeeded, seek time is ${seekDoneTime}`);
    // 立即同步进度到 UI（暂停时无 timeUpdate 事件，不更新则歌词/进度条不跟随）
    const appState = this.getAppState();
    appState.progress = seekDoneTime;
    appState.currentTime = MediaTools.msToCountdownTime(seekDoneTime);
    this.liveViewController.update(seekDoneTime, appState.isPlay);
    this.setPlayState({
      position: {
        elapsedTime: seekDoneTime,
        updateTime: new Date().getTime()
      }
    });
  };
  /** AVPlayer error: logs and resets the player. */
  private errorCall: (err: BusinessError) => void = (err: BusinessError) => {
    Logger.error(TAG, `Invoke avPlayer failed, code is ${err.code}, message is ${err.message}`);
    appendPlayLog('[播放] AVPlayer 报错 code=' + err.code + ' msg=' + err.message);
    // 记录本次失败的 url / 音质，后续 fallback 不得再把同一条地址返回（否则会对同一条
    // 死链无限重试，这正是播放页被卡住的根因）。
    const failedUrlNow: string = this.avPlayer?.url ?? '';
    if (failedUrlNow.length > 0) {
      this.failedUrl = failedUrlNow;
    }
    const failedQualityNow: string = this.getAppState().currentQuality;
    if (failedQualityNow.length > 0) {
      this.failedQuality = failedQualityNow;
    }
    // 关键：立即清空当前歌曲的 url。avPlayer.reset() 会异步回到 idle 态，此时
    // stateCall('idle') 会把同一条死链再次灌回播放器，形成
    // error→reset→reload→error 的紧密循环并饿死 UI 主线程（播放按钮点不动）。
    // 清空 url 后 idle 处理器无地址可灌，循环从源头断开。
    const failing: SongItem | undefined = this.getSongItemAtQueueIndex(this.musicIndex);
    if (failing !== undefined) {
      failing.url = '';
      // 音质档位健康度：仅在 AVPlayer 真正报错（而非解析无地址）时记失败，
      // 连败到阈值后该「脚本+平台+音质」组合进冷却，后续歌曲直接跳过该档位
      if (failedQualityNow.length > 0 && failing.source.length > 0) {
        const scriptId: string = AppStorage.get<string>('lxActiveSource') ?? '';
        MusicStoreService.getInstance().recordFailure(
          qualityTierKey(failedQualityNow, failing.source, scriptId),
          QUALITY_TIER_FAIL_THRESHOLD, QUALITY_TIER_COOLDOWN_MS);
        appendPlayLog('[播放] 记录档位失败 ' + failing.source + '/' + failedQualityNow);
      }
    }
    // 关键：reset 后 avPlayer 内部已释放 url 资源，必须同步把 isPrepared 置 false，
    // 否则 play() 走「isPrepared=true → 直接 avPlayer.play()」分支对一个空 url 静默失败，
    // 用户表现为「播放按钮点不动」。
    this.state = AudioPlayerState.ERROR;
    this.isPrepared = false;
    this.updateIsPlay(false);
    this.errorRecoveryPending = true;
    appendPlayLog('[播放] 错误恢复已挂起 failedUrl=' + failedUrlNow.substring(0, 60) +
      ' failedQuality=' + failedQualityNow + ' 排队歌曲url已清空=' + (failing !== undefined));
    this.avPlayer?.reset();
    // 跨源 fallback：reset 是异步完成，500ms 后等状态稳定再清空 url 触发 loadAsset 内部的
    // resolveOnlineUrl（它会走 resolveMusicUrlWithFallback 自动跨源/跨脚本）。
    // 重试放在 setTimeout 而不是错误回调里，避免和 reset 流程抢 avPlayer。
    // 注意：这里只能用 errorRecoveryPending 判断，不能用 state===ERROR——
    // reset 回 idle 后 state 已被覆盖成 IDLE，state 检查会让 fallback 被静默跳过。
    setTimeout((): void => {
      if (!this.errorRecoveryPending) {
        appendPlayLog('[播放] 错误恢复定时器触发，但恢复已被取消（新加载/已成功恢复）');
        return;
      }
      appendPlayLog('[播放] 错误恢复定时器触发，开始跨源重试 hasFallbackOnce=' + this.hasFallbackOnce);
      if (this.hasFallbackOnce) {
        // 已经跨源重试过一次仍失败，跳到列表下一首，避免死循环
        appendPlayLog('[播放] 跨源 fallback 已用尽，跳到下一首');
        this.errorRecoveryPending = false;
        this.hasFallbackOnce = false;
        this.playNextAuto(true);
        return;
      }
      this.hasFallbackOnce = true;
      this.retryCurrentSongWithFallback().catch((err: Object): void => {
        // 兜底：恢复链路任何未捕获异常都不能让播放器卡死
        appendPlayLog('[播放] 错误恢复链路异常: ' + JSON.stringify(err).substring(0, 120));
        this.errorRecoveryPending = false;
        this.hasFallbackOnce = false;
        this.playNextAuto(true);
      });
    }, 500);
  };

  /**
   * AVPlayer 播放失败时调用：调 resolveOnlineUrl 让它自动跨源重试同一首歌的播放
   * （resolveOnlineUrl → resolveMusicUrlWithFallback 会自动跨源/跨脚本）。
   * 跨源也失败时直接跳到列表下一首，避免依赖 loadAsset 内部的副作用判断。
   */
  private async retryCurrentSongWithFallback(): Promise<void> {
    if (!this.errorRecoveryPending) {
      return;
    }
    const appState = this.getAppState();
    const current: SongItem | undefined = appState.getCurrentSongItem();
    if (current === undefined || current.source.length === 0) {
      this.errorRecoveryPending = false;
      this.hasFallbackOnce = false;
      this.playNextAuto(true);
      return;
    }
    appendPlayLog('[播放] 跨源 fallback 触发 ' + current.source + '/' +
      (typeof current.title === 'string' ? current.title : ''));
    // 清空 url：让 resolveOnlineUrl 走 fallback 而不是直接走缓存
    current.url = '';
    this.isNeedPlay = true;
    const resolved: boolean = await this.resolveOnlineUrl(current);
    appendPlayLog('[播放] 跨源重试解析结果=' + resolved + ' 新url=' +
      (current.url.length > 0 ? '已获得' : '空'));
    if (!resolved) {
      // 跨源/跨脚本 fallback 全部失败，直接跳到下一首
      appendPlayLog('[播放] 跨源 fallback 仍失败，跳到下一首');
      this.errorRecoveryPending = false;
      this.hasFallbackOnce = false;
      this.playNextAuto(true);
      return;
    }
    // resolveOnlineUrl 已填好新 url/source/songId，加载播放
    this.errorRecoveryPending = false;
    this.loadAsset(this.musicIndex);
  }
  /** AVPlayer timeUpdate: refreshes countdown label and progress in MusicAppState when active. */
  private updateTimeCall: (updateTime: number) => void = (updateTime: number) => {
    const appState = this.getAppState();
    this.liveViewController.update(updateTime, appState.isPlay);
    if (this.isCurrent) {
      appState.currentTime = MediaTools.msToCountdownTime(updateTime);
      appState.progress = updateTime;
      this.syncCardLyric(updateTime);
    }
  };

  /** Joins a lyric line's words into plain text. */
  private static lineText(line: AmllLyricLine): string {
    let text: string = '';
    for (let i: number = 0; i < line.words.length; i++) {
      text += line.words[i].word;
    }
    return text.trim();
  }

  /** Pushes the lyric line matching the playback position to the desktop card. */
  private syncCardLyric(positionMs: number): void {
    const song: SongItem | undefined = this.getSongItemAtQueueIndex(this.musicIndex);
    if (song === undefined || song.lyricText.length === 0) {
      return;
    }
    const lines: AmllLyricLine[] | undefined = amllGetCachedLyric(song.lyricText);
    if (lines === undefined || lines.length === 0) {
      return;
    }
    let current: string = '';
    for (let i: number = 0; i < lines.length; i++) {
      const start: number = lines[i].startTime;
      if (start > positionMs) {
        break;
      }
      const text: string = MediaService.lineText(lines[i]);
      if (text.length > 0) {
        current = text;
      }
    }
    const store: MusicStoreService = MusicStoreService.getInstance();
    if (store.getCardLyric() === current) {
      return;
    }
    store.setCardLyric(current);
  }
  /**
   * Loads the current queue item into the AVPlayer (http url or local fd).
   * Called from the 'idle' state callback, and directly from loadAsset when the
   * player is already idle: calling reset() on an idle AVPlayer produces no
   * state transition, so the 'idle' callback never fires and the track would
   * never load — the silent "stuck playback / play button dead" bug.
   */
  private async loadCurrentIntoPlayer(): Promise<void> {
    const idleSong: SongItem | undefined = this.getSongItemAtQueueIndex(this.musicIndex);
    if (!idleSong || !this.avPlayer) {
      return;
    }
    this.songItem = await this.songItemBuilder.build(idleSong);
    const httpUrl: string = this.songItemBuilder.getHttpUrl();
    if (httpUrl.length > 0) {
      this.avPlayer.url = httpUrl;
      Logger.info(TAG, 'loadAsset avPlayer.url:' + this.avPlayer.url);
      this.appendPlayLog('[播放] 装载网络曲目 url=' + httpUrl.substring(0, 60));
    } else {
      const url = this.songItemBuilder.getRealUrl();
      if (url) {
        const avFileDescriptor: media.AVFileDescriptor = { fd: url.fd, offset: url.offset, length: url.length };
        this.avPlayer.fdSrc = avFileDescriptor;
        Logger.info(TAG, 'loadAsset avPlayer.fdSrc:' + this.avPlayer.fdSrc);
        this.appendPlayLog('[播放] 装载本地曲目 fd');
      } else {
        this.appendPlayLog('[播放] idle 无可播地址（url 已清空，等待错误恢复或手动重试）');
      }
    }
  }

  /** AVPlayer stateChange: drives prepare/play flow, metadata, and auto-next on completion. */
  private stateCall: (state: string) => Promise<void> = async (state: string) => {
    switch (state) {
      case 'idle':
        Logger.info(TAG, 'AVPlayer state idle called.');
        this.state = AudioPlayerState.IDLE;
        await this.loadCurrentIntoPlayer();
        break;
      case 'initialized':
        Logger.info(TAG, 'AVPlayer state initialized called.');
        this.state = AudioPlayerState.INITIALIZED;
        if (this.avPlayer) {
          this.avPlayer.prepare().then(() => {
            Logger.info(TAG, 'AVPlayer prepare succeeded.');
          }, (err: BusinessError) => {
            Logger.error(TAG, `Invoke prepare failed, code is ${err.code}, message is ${err.message}`);
          });
        }
        break;
      case 'prepared':
        Logger.info(TAG, 'AVPlayer state prepared called.');
        this.state = AudioPlayerState.PREPARED;
        this.isPrepared = true;
        // 地址已就绪：结束「解析中」状态
        this.getAppState().isResolving = false;
        const appState = this.getAppState();
        appState.totalTime = MediaTools.msToCountdownTime(this.getDuration());
        appState.progressMax = this.getDuration();
        this.appendPlayLog('[播放] prepared isNeedPlay=' + this.isNeedPlay);
        if (this.avPlayer && this.isNeedPlay) {
          this.ensureBackgroundAudioTask();
          this.avPlayer.play();
        }
        this.setAVMetadata();
        this.isNeedPlay = true;
        Logger.info(TAG, 'AVPlayer prepared succeeded.');
        break;
      case 'playing':
        Logger.info(TAG, 'AVPlayer state playing called.');
        this.state = AudioPlayerState.PLAY;
        // 播放成功：清除跨源 fallback 守门标志与失败记录，下一次播放失败时允许重新跨源
        this.hasFallbackOnce = false;
        this.failedUrl = '';
        this.failedQuality = '';
        this.errorRecoveryPending = false;
        // 播放成功：该音质档位健康，清除冷却/失败计数（冷却到期后自动升回高档位）
        this.recordQualityTierSuccess();
        this.ensureBackgroundAudioTask();
        const playingSong = this.getSongItemAtQueueIndex(this.musicIndex);
        if (playingSong !== undefined) {
          // 实况窗随播放创建（本地实况窗仅前台可建，失败自动降级）
          this.liveViewController.start(this.resolveSongText(playingSong.title),
            this.resolveSongText(playingSong.singer), playingSong.lyricText);
          if (playingSong.source.length > 0) {
            MusicStoreService.getInstance().addHistory(MusicStoreService.fromSongItem(playingSong));
            MusicStoreService.getInstance().setLastSong(
              JSON.stringify(MusicStoreService.fromSongItem(playingSong)) || '');
            MusicCardBridge.notify();
            if (playingSong.lyricText.length === 0 || playingSong.cover.length === 0) {
              await this.enrichOnlineTrack(playingSong);
              this.syncCardSongSnapshot(playingSong);
            }
          } else {
            MusicStoreService.getInstance().setLastSong(
              JSON.stringify(MusicStoreService.fromSongItem(playingSong)) || '');
          }
        }
        break;
      case 'paused':
        Logger.info(TAG, 'AVPlayer state paused called.');
        this.state = AudioPlayerState.PAUSE;
        break;
      case 'completed':
        Logger.info(TAG, 'AVPlayer state completed called.');
        this.state = AudioPlayerState.COMPLETED;
        this.playNextAuto(false);
        break;
      case 'stopped':
        Logger.info(TAG, 'AVPlayer state stopped called.');
        this.state = AudioPlayerState.STOP;
        // 关键：stop 后 avPlayer 会被 reset 回 idle，isPrepared 必须同步置 false，
        // 否则 play() 会误判 isPrepared=true 而直接对无 url 的 avPlayer 调 play()，
        // 表现为播放按钮点了没反应。
        this.isPrepared = false;
        if (this.avPlayer) {
          this.avPlayer.reset();
        }
        break;
      case 'released':
        Logger.info(TAG, 'AVPlayer state released called.');
        this.state = AudioPlayerState.RELEASED;
        break;
      default:
        Logger.info(TAG, 'AVPlayer state unknown called.');
        this.state = AudioPlayerState.UNKNOWN;
        break;
    }
    this.updateIsPlay(this.state === AudioPlayerState.PLAY);
  };
  /** AVSession remote play: loads first asset or resumes local play. */
  private playCall: () =>void = () => {
    Logger.info(TAG, `on play , do play task`);
    if (this.isFirst) {
      this.loadAsset(this.getValidSelectIndex());
    } else {
      this.play();
    }
  };
  /** Registers audio routing listener: losing a wired/Bluetooth output pauses playback. */
  private registerAudioDeviceListener(): void {
    if (this.routingCallback !== undefined) {
      return;
    }
    try {
      const manager: audio.AudioManager = audio.getAudioManager();
      this.audioManager = manager;
      this.routingCallback = (action: audio.DeviceChangeAction): void => {
        if (action.type !== audio.DeviceChangeType.DISCONNECT) {
          return;
        }
        let lostOutput: boolean = false;
        for (let i: number = 0; i < action.deviceDescriptors.length; i++) {
          const type: audio.DeviceType = action.deviceDescriptors[i].deviceType;
          if (type === audio.DeviceType.BLUETOOTH_A2DP || type === audio.DeviceType.BLUETOOTH_SCO ||
            type === audio.DeviceType.WIRED_HEADSET || type === audio.DeviceType.USB_HEADSET) {
            lostOutput = true;
          }
        }
        if (!lostOutput) {
          return;
        }
        appendPlayLog('[播放] 音频输出设备断开，自动暂停');
        if (this.avPlayer !== undefined && !this.isPlayPaused()) {
          this.pause();
        }
      };
      manager.on('deviceChange', this.routingCallback);
    } catch (error) {
      Logger.warn(TAG, `register audio device listener failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /** Releases the audio routing listener. */
  private unregisterAudioDeviceListener(): void {
    const manager = this.audioManager;
    const callback = this.routingCallback;
    this.routingCallback = undefined;
    if (manager === undefined || callback === undefined) {
      return;
    }
    try {
      manager.off('deviceChange', callback);
    } catch (_err) {
    }
  }

  private isPlayPaused(): boolean {
    return this.state === AudioPlayerState.PAUSE || this.state === AudioPlayerState.STOP ||
      this.state === AudioPlayerState.ERROR || this.state === AudioPlayerState.IDLE ||
      this.state === AudioPlayerState.COMPLETED;
  }

  /** AVSession remote pause. */
  private pauseCall: () =>void = () => {
    Logger.info(TAG, `on pause , do pause task`);
    this.pausedByInterrupt = false;
    this.pause();
  };
  /** AVSession remote next track. */
  private playNextCall: () =>void = () => {
    Logger.info(TAG, `on playNext , do playNext task`);
    this.playNextAuto(true);
  };
  /** AVSession remote previous track. */
  private playPreviousCall: () =>void = () => {
    Logger.info(TAG, `on playPrevious , do playPrevious task`);
    this.playPrevious();
  };
  /** AVSession remote seek (progress bar drag / lyric line click in the control center). */
  private sessionSeekCall: (seekToTime: number) => void = (seekToTime: number) => {
    Logger.info(TAG, `on seek, do seek task to ${seekToTime}`);
    this.seek(seekToTime);
  };
  /** AVPlayer volumeChange: mirrors volume into MusicAppState. */
  private volumeChangeCall: (volume: number) => void = (volume: number) => {
    Logger.info(TAG, `on volumeChangeCall, do volumeChange task`);
    this.getAppState().volume = volume;
  };

  /**
   * Records a successful playback for the current tier so a previously broken
   * (script|platform|quality) combination can be used again once it recovers.
   */
  private recordQualityTierSuccess(): void {
    const song: SongItem | undefined = this.getSongItemAtQueueIndex(this.musicIndex);
    const quality: string = this.getAppState().currentQuality;
    if (song === undefined || quality.length === 0 || song.source.length === 0) {
      return;
    }
    const scriptId: string = AppStorage.get<string>('lxActiveSource') ?? '';
    MusicStoreService.getInstance().recordSuccess(qualityTierKey(quality, song.source, scriptId));
  }

  /** Shared observable app state (queue, play flag, progress) bound to AppStorageV2. */
  private getAppState(): MusicAppState {
    return AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  }

  /** Resolves a song title/artist (plain string or string resource) to text for the live view. */
  private resolveSongText(value: string | Resource): string {
    const ctx = this.abilityContext;
    if (ctx === undefined) {
      return typeof value === 'string' ? value : '';
    }
    return StringResourceUtil.resolve(ctx, value);
  }

  /** True while a delayed lyric metadata refresh is pending (deduplicated). */
  private lyricRefreshScheduled: boolean = false;

  /**
   * Re-pushes AVSession metadata shortly after an uncached lyric finished parsing
   * (the lyric page / live view parses it off the UI thread hot path). At most one
   * pending refresh at a time.
   */
  private scheduleLyricMetadataRefresh(): void {
    if (this.lyricRefreshScheduled) {
      return;
    }
    this.lyricRefreshScheduled = true;
    setTimeout((): void => {
      this.lyricRefreshScheduled = false;
      void this.setAVMetadata();
    }, 250);
  }

  /**
   * Re-creates the live view when the app returns to the foreground while audio is
   * playing (local live views can only be created while the app is in the foreground).
   */
  public syncLiveViewOnForeground(): void {
    if (!this.getAppState().isPlay) {
      return;
    }
    const song = this.getSongItemAtQueueIndex(this.musicIndex);
    if (song !== undefined) {
      this.liveViewController.start(this.resolveSongText(song.title),
        this.resolveSongText(song.singer), song.lyricText);
    }
  }

  /** Starts or refreshes continuous background audio task (required after some track-switch paths). */
  private ensureBackgroundAudioTask(): void {
    BackgroundUtil.startContinuousTask(this.abilityContext);
  }

  /** Called when the app goes to background while playing; keeps continuous task if needed. */
  public onApplicationBackground(): void {
    if (this.getAppState().isPlay) {
      this.ensureBackgroundAudioTask();
    }
  }

  /** Resolves SongItem at queue index via MusicAppState. */
  private getSongItemAtQueueIndex(index: number): SongItem | undefined {
    return this.getAppState().resolveSongAtQueueIndex(index);
  }

  /** Shows a toast via the current UIContext when available. */
  private toast(message: string): void {
    const uiContext = getAppRuntime().uiContext;
    if (uiContext !== undefined) {
      uiContext.getPromptAction().showToast({ message: message, duration: 2000 });
    }
  }

  /**
   * Fills lyric text and cover for an online song using built-in interfaces only
   * (never depends on the active user API script).
   * @param songItem Queue item with non-empty source.
   */
  private async enrichOnlineTrack(songItem: SongItem): Promise<void> {
    const name: string = typeof songItem.title === 'string' ? songItem.title : '';
    const singer: string = typeof songItem.singer === 'string' ? songItem.singer : '';
    const log: string = AppStorage.get<string>('lxPlayLog') ?? '';
    const time: string = new Date().getHours().toString().padStart(2, '0') + ':' +
      new Date().getMinutes().toString().padStart(2, '0') + ':' +
      new Date().getSeconds().toString().padStart(2, '0');
    AppStorage.setOrCreate('lxPlayLog', (log + '[' + time + '] [补全] source=' + songItem.source +
      ' lyricLen=' + songItem.lyricText.length + ' coverLen=' + songItem.cover.length + '\n').slice(-20000));
    {
      const itemRef: SongItem = songItem;
      const trackName: string = name;
      const trackSinger: string = singer;
      const src: string = itemRef.source;
      const srcId: string = itemRef.songId;
      const appState: MusicAppState = this.getAppState();
      const applyLyric: (lyric: string, translation: string, roman: string) => void =
        (lyric: string, translation: string, roman: string): void => {
          if (lyric.length > 0) {
            itemRef.lyricText = lyric;
          }
          if (translation.length > 0) {
            itemRef.lyricTranslation = translation;
          }
          if (roman.length > 0) {
            itemRef.lyricRoman = roman;
          }
          if (lyric.length > 0 || translation.length > 0 || roman.length > 0) {
            appState.lyricVersion++;
            // 歌词补全后同步到播控中心元数据与实况窗
            this.liveViewController.reloadLyric(itemRef.lyricText);
            void this.setAVMetadata();
          }
        };
      // TTML 社区数据库歌词优先级最高（逐字 + 翻译/罗马音随原文），失败再回退各平台全量歌词
      const fallbackFullLyric: () => void = (): void => {
        void lxGetLyricFull(src, srcId, trackName, trackSinger).then((full: LyricFullResult): void => {
          applyLyric(full.main, full.translation, full.romanLyric);
        }).catch((_err: Object): void => {
          // lyric is optional
        });
      };
      void lxGetTTMLLyric(srcId).then((ttml: string): void => {
        if (ttml.length > 0) {
          applyLyric(ttml, '', '');
          return;
        }
        fallbackFullLyric();
      }).catch((_err: Object): void => {
        fallbackFullLyric();
      });
    }
    if (songItem.cover.length === 0) {
      try {
        const pic: string = await lxGetPicFallback(songItem.source, songItem.songId, songItem.albumId, name, singer);
        if (pic.length > 0) {
          songItem.cover = pic;
          // Refresh AVSession metadata so the control-center card shows the real cover.
          this.setAVMetadata();
        }
      } catch (_err) {
        // pic is optional
      }
    }
  }

  /**
   * Lazily resolves the play url (and lyric) for an online song via the LX source engine.
   * Includes quality downgrade and cross-source fallback (lx-music style recovery).
   * @param songItem Queue item with non-empty source and empty url.
   * @returns True when the url was resolved.
   */
  private async resolveOnlineUrl(songItem: SongItem): Promise<boolean> {
    if (!lxEngineIsReady) {
      this.toast('音源未就绪，请在设置中导入并选中源');
      return false;
    }
    const name: string = typeof songItem.title === 'string' ? songItem.title : '';
    const singer: string = typeof songItem.singer === 'string' ? songItem.singer : '';
    appendPlayLog('[播放] resolveOnlineUrl 开始 source=' + songItem.source +
      ' id=' + songItem.songId + ' 排除音质=' + this.failedQuality +
      ' 排除失败url=' + (this.failedUrl.length > 0 ? '是' : '否'));
    // 失败重解析时排除刚刚失败的同一条地址与同一档音质，避免重复拿到死链
    const opts: FallbackOptions = new FallbackOptions();
    opts.excludeUrl = this.failedUrl;
    opts.excludeQuality = this.failedQuality;
    opts.allowScriptSwitch = true;
    const outcome: UrlResolveOutcome = await resolveMusicUrlWithFallback(songItem.source,
      songItem.songId, name, singer, '', (msg: string): void => {
        this.toast(msg);
      }, opts);
    if (outcome.url.length === 0) {
      this.toast('获取播放地址失败，已尝试全部可用音源');
      return false;
    }
    // 记录本次真实来源：音乐平台 / 音源脚本 / 实际音质，供播放详情页展示与验证换源是否生效
    songItem.quality = outcome.quality;
    if (outcome.scriptName.length > 0) {
      songItem.playScript = outcome.scriptName;
    }
    songItem.playCached = false;
    if (outcome.switched) {
      // 原源不可用已换源：队列条目改为新源歌曲，后续歌词/封面/下载都走新源
      songItem.source = outcome.source;
      songItem.songId = outcome.songId;
      if (outcome.albumName.length > 0 && songItem.albumName.length === 0) {
        songItem.albumName = outcome.albumName;
      }
      if (outcome.img.length > 0 && songItem.cover.length === 0) {
        songItem.cover = outcome.img;
      }
    }
    songItem.url = outcome.url;
    // 记录实际使用的音质（可能因自动降级低于偏好设置）
    this.getAppState().currentQuality = outcome.quality;
    appendPlayLog('[播放] resolveOnlineUrl 成功 quality=' + outcome.quality +
      ' script=' + outcome.scriptName + ' 换源=' + outcome.switched +
      (outcome.switchedScriptName.length > 0 ? ' 换脚本=' + outcome.switchedScriptName : ''));
    // 触发播放详情页醒目 Banner：跨脚本换源时展示新音源名，3 秒后由 PlaybackPage 自动清除。
    if (outcome.switchedScriptName.length > 0) {
      const banner: SwitchBannerState = SwitchBannerState.connect();
      banner.text = '已切换音源：' + outcome.switchedScriptName;
      banner.ts = Date.now();
    }
    await this.enrichOnlineTrack(songItem);
    return true;
  }

  /** Current play queue length from MusicAppState. */
  private getQueueLength(): number {
    return this.getAppState().getQueueLength();
  }

  /** Clamps MusicAppState.selectIndex to a valid queue index (0 if empty or out of range). */
  private getValidSelectIndex(): number {
    const len = this.getQueueLength();
    const idx = this.getAppState().selectIndex;
    if (len === 0) {
      return 0;
    }
    if (idx < 0 || idx >= len) {
      return 0;
    }
    return idx;
  }

  /** Applies deferred loadAsset request after AVPlayer becomes available. */
  private applyPendingLoadRequest(): void {
    if (this.pendingLoadIndex < 0) {
      return;
    }
    const pendingIndex = this.pendingLoadIndex;
    const pendingLoadOnly = this.pendingLoadOnly;
    this.pendingLoadIndex = -1;
    this.pendingLoadOnly = false;
    void this.loadAsset(pendingIndex, pendingLoadOnly);
  }

  /** Creates service, builds SongItemBuilder, and starts async AVPlayer creation. */
  public constructor() {
    this.songItemBuilder = new SongItemBuilder();
    this.restorePlayMode();
    this.initAudioPlayer();
    this.registerHiCarListener();
  }

  /** Restores the persisted play mode so it survives app restarts. */
  private restorePlayMode(): void {
    const saved: number = MusicStoreService.getInstance().getPlayMode();
    if (saved >= 0 && saved <= 2) {
      this.playMode = saved as MusicPlayMode;
      Logger.info(TAG, 'restorePlayMode: ' + this.playMode);
    }
  }

  /**
   * Restores the last played song into the queue on startup so the mini bar
   * shows it immediately. Does not auto-start playback (loadOnly = true).
   */
  private restoreLastSong(): void {
    if (this.lastSongRestored) {
      return;
    }
    this.lastSongRestored = true;
    const json: string = MusicStoreService.getInstance().getLastSong();
    if (json.length === 0) {
      return;
    }
    try {
      const record: PlayedSongRecord = JSON.parse(json) as PlayedSongRecord;
      if (record === undefined || (record.songId.length === 0 && record.url.length === 0)) {
        return;
      }
      const item: SongItem = MusicStoreService.toSongItem(record);
      const appState = this.getAppState();
      appState.playQueueIds = [];
      appState.playQueue = [item];
      appState.selectIndex = 0;
      void this.loadAsset(0, true);
      this.appendPlayLog('[播放] 恢复上次歌曲: ' + this.resolveSongText(item.title));
    } catch (e) {
      Logger.warn(TAG, 'restoreLastSong failed: ' + JSON.stringify(e).substring(0, 100));
    }
  }

  /**
   * Restores the full play queue (online items + local ids + current index)
   * on startup so the playlist survives app restarts. Does not auto-start
   * playback (loadOnly = true). Falls back to restoreLastSong when no queue
   * snapshot exists.
   */
  private restoreLastQueue(): void {
    if (this.lastQueueRestored) {
      return;
    }
    this.lastQueueRestored = true;
    const json: string = MusicStoreService.getInstance().getLastQueue();
    if (json.length === 0) {
      this.restoreLastSong();
      return;
    }
    try {
      const snapshot: QueueSnapshot = JSON.parse(json) as QueueSnapshot;
      if (snapshot === undefined || (snapshot.online.length === 0 && snapshot.localIds.length === 0)) {
        this.restoreLastSong();
        return;
      }
      const items: SongItem[] = [];
      for (let i = 0; i < snapshot.online.length; i++) {
        items.push(MusicStoreService.toSongItem(snapshot.online[i]));
      }
      const appState = this.getAppState();
      appState.playQueue = items;
      appState.playQueueIds = snapshot.localIds;
      appState.selectIndex = snapshot.index;
      this.musicIndex = snapshot.index;
      const restoreIndex: number = this.getValidSelectIndex();
      appState.selectIndex = restoreIndex;
      this.musicIndex = restoreIndex;
      void this.loadAsset(restoreIndex, true);
      this.appendPlayLog('[播放] 恢复播放列表 ' + snapshot.online.length + ' 首');
    } catch (e) {
      Logger.warn(TAG, 'restoreLastQueue failed: ' + JSON.stringify(e).substring(0, 100));
      this.restoreLastSong();
    }
  }

  /** Snapshots the current queue (online items + local ids + index) to preferences. */
  private persistQueueSnapshot(): void {
    const appState = this.getAppState();
    const online: PlayedSongRecord[] = [];
    for (let i = 0; i < appState.playQueue.length; i++) {
      online.push(MusicStoreService.fromSongItem(appState.playQueue[i]));
    }
    const snapshot: QueueSnapshot = {
      online: online,
      localIds: appState.playQueueIds,
      index: appState.selectIndex
    };
    MusicStoreService.getInstance().setLastQueue(JSON.stringify(snapshot));
  }

  /** Global singleton stored on AppRuntime.mediaServiceRef. */
  public static getInstance(): MediaService {
    const rt = getAppRuntime();
    const ref: object | undefined = rt.mediaServiceRef;
    if (ref !== undefined && ref instanceof MediaService) {
      return ref;
    }
    const instance: MediaService = new MediaService();
    rt.mediaServiceRef = instance;
    return instance;
  }

  /**
   * Activates / deactivates the app audio session so playback can run concurrently
   * with other apps (audioInterruptMode alone only affects streams inside this app).
   * Re-activates on each playback start because the system deactivates the session
   * on timeout when no audio stream is running.
   * @param mix True to allow playing alongside other apps (CONCURRENCY_MIX_WITH_OTHERS).
   */
  public applyAudioSession(mix: boolean): void {
    if (this.sessionManager === undefined) {
      try {
        this.sessionManager = audio.getAudioManager().getSessionManager();
      } catch (e) {
        Logger.warn(TAG, 'getAudioSessionManager failed: ' + JSON.stringify(e).substring(0, 100));
        return;
      }
    }
    try {
      if (!mix) {
        if (this.sessionManager.isAudioSessionActivated()) {
          this.sessionManager.deactivateAudioSession().catch((err: BusinessError): void => {
            Logger.warn(TAG, `deactivateAudioSession failed. Code: ${err.code}, message: ${err.message}`);
          });
        }
        return;
      }
      if (this.sessionManager.isAudioSessionActivated()) {
        return;
      }
      const strategy: audio.AudioSessionStrategy = {
        concurrencyMode: audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS
      };
      this.sessionManager.activateAudioSession(strategy).catch((err: BusinessError): void => {
        Logger.warn(TAG, `activateAudioSession failed. Code: ${err.code}, message: ${err.message}`);
      });
    } catch (e) {
      Logger.warn(TAG, 'applyAudioSession error: ' + JSON.stringify(e).substring(0, 100));
    }
  }

  /** Creates AVPlayer, registers callbacks, creates AVSession, and drains pending load. */
  private initAudioPlayer(): void {
    media.createAVPlayer().then(async avPlayer => {
      if (avPlayer !== null) {
        this.avPlayer = avPlayer;
        this.registerAudioDeviceListener();
        // Shared audio focus lets this app play alongside other apps when enabled.
        try {
          const mixEnabled: boolean = MusicStoreService.getInstance().getAudioMix();
          this.avPlayer.audioInterruptMode = mixEnabled ?
            audio.InterruptMode.SHARE_MODE : audio.InterruptMode.INDEPENDENT_MODE;
          this.appendPlayLog('[播放] 音频焦点模式=' + (mixEnabled ? '共享' : '独占'));
        } catch (e) {
          this.appendPlayLog('[播放] 设置音频焦点失败: ' + JSON.stringify(e).substring(0, 100));
        }
        this.setAVPlayerCallback();
        this.createSession();
        this.applyAudioSession(MusicStoreService.getInstance().getAudioMix());
        this.applyPendingLoadRequest();
        this.restoreLastQueue();
      }
    }) .catch((error: BusinessError) => {
      Logger.error(TAG, 'this avPlayer: ', `catch error happened,error code is ${error.code}`);
    });
  }

  /** Subscribes AVPlayer events (seek, error, time, state, volume, audio interrupt). */
  private setAVPlayerCallback(): void {
    if (!this.avPlayer) {
      return;
    }
    this.avPlayer.on('seekDone', this.seekCall);

    this.avPlayer.on('error', this.errorCall);

    this.avPlayer.on('timeUpdate', this.updateTimeCall);

    this.avPlayer.on('stateChange', this.stateCall);

    this.avPlayer.on('volumeChange', this.volumeChangeCall);

    this.avPlayer.on('audioInterrupt', this.audioInterruptCall);
  }

  /**
   * AVPlayer audioInterrupt: pauses on focus loss and auto-resumes when the focus
   * returns (e.g. after voice input finishes).
   */
  private audioInterruptCall: (interruptEvent: audio.InterruptEvent) => Promise<void> =
    async (interruptEvent: audio.InterruptEvent) => {
      if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
        switch (interruptEvent.hintType) {
          case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
            // 暂时失焦（语音输入场景），后续会收到 RESUME
            if (this.avPlayer !== undefined && this.avPlayer.state === 'playing') {
              try {
                await this.avPlayer.pause();
              } catch (e) {
                Logger.warn(TAG, 'audioInterrupt pause failed: ' + JSON.stringify(e).substring(0, 120));
              }
            }
            this.pausedByInterrupt = true;
            this.updateIsPlay(false);
            this.appendPlayLog('[播放] 音频被打断（暂时失焦），等待恢复');
            break;
          case audio.InterruptHint.INTERRUPT_HINT_STOP:
            // 永久失焦，不会再收到 RESUME
            if (this.avPlayer !== undefined && this.avPlayer.state === 'playing') {
              try {
                await this.avPlayer.pause();
              } catch (e) {
                Logger.warn(TAG, 'audioInterrupt stop pause failed: ' + JSON.stringify(e).substring(0, 120));
              }
            }
            this.pausedByInterrupt = false;
            this.updateIsPlay(false);
            break;
          default:
            break;
        }
      } else if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_SHARE) {
        if (interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME) {
          // 焦点归还，主动恢复播放
          if (this.pausedByInterrupt && this.avPlayer !== undefined && this.avPlayer.state === 'paused') {
            this.pausedByInterrupt = false;
            this.appendPlayLog('[播放] 焦点归还，自动恢复播放');
            this.play();
          }
        }
      }
    };

  /** Pauses playback when the HiCar connection drops. Best-effort on unsupported devices. */
  private registerHiCarListener(): void {
    try {
      const awareness = smartMobilityCommon.getSmartMobilityAwareness();
      const types: smartMobilityCommon.SmartMobilityType[] = [smartMobilityCommon.SmartMobilityType.HICAR];
      awareness.on('smartMobilityStatus', types, (info: smartMobilityCommon.SmartMobilityInfo) => {
        const status: number = info.status;
        if (this.lastHiCarStatus === smartMobilityCommon.SmartMobilityStatus.RUNNING &&
          status === smartMobilityCommon.SmartMobilityStatus.IDLE) {
          this.appendPlayLog('[播放] HiCar 断开，自动暂停');
          this.pause();
        }
        this.lastHiCarStatus = status;
      });
      const currentInfo: smartMobilityCommon.SmartMobilityInfo =
        awareness.getSmartMobilityStatus(smartMobilityCommon.SmartMobilityType.HICAR);
      this.lastHiCarStatus = currentInfo.status;
      this.appendPlayLog('[播放] HiCar 状态监听已注册，当前状态=' + currentInfo.status);
    } catch (e) {
      Logger.warn(TAG, 'registerHiCarListener failed: ' + JSON.stringify(e).substring(0, 120));
    }
  }

  public refreshHiCarStatus(): void {
    try {
      const awareness = smartMobilityCommon.getSmartMobilityAwareness();
      const currentInfo: smartMobilityCommon.SmartMobilityInfo =
        awareness.getSmartMobilityStatus(smartMobilityCommon.SmartMobilityType.HICAR);
      this.lastHiCarStatus = currentInfo.status;
    } catch (_e) {
    }
  }

  /** Creates and activates AVSession, sets launch want agent, and registers controller listeners. */
  private async createSession(): Promise<void> {
    if (!this.abilityContext) {
      return;
    }
    try {
      this.session = await avSession.createAVSession(this.abilityContext, 'SESSION_NAME', 'audio');
      Logger.info(TAG, `session create done : sessionId : ${this.session.sessionId}`);
      this.session.activate();
      void this.enableSystemLyric(this.session);
    } catch (error) {
      Logger.error(TAG, `${error.code} + ${error.message}`);
    }
    this.setAVMetadata();
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: this.abilityContext.abilityInfo.bundleName,
          abilityName: this.abilityContext.abilityInfo.name
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITIES,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    wantAgent.getWantAgent(wantAgentInfo).then((agent) => {
      if (this.session) {
        this.session.setLaunchAbility(agent);
      }
    })
      .catch((err: BusinessError) => {
        Logger.error(TAG, `getWantAgent failed, code: ${JSON.stringify(err.code)}, ` +
        `message: ${JSON.stringify(err.message)}`);
      });
    this.registerSessionControlListeners();
  }

  /** Subscribe to AVSession controller commands (play / pause / next / previous). */
  private async registerSessionControlListeners(): Promise<void> {
    if (!this.session) {
      return;
    }
    try {
      this.session.on('play', this.playCall);
      this.session.on('pause', this.pauseCall);
      this.session.on('playNext', this.playNextCall);
      this.session.on('playPrevious', this.playPreviousCall);
      this.session.on('seek', this.sessionSeekCall);
    } catch (error) {
      Logger.error(TAG, `${error.code} + ${error.message}`);
    }
  }

  /** Unsubscribe AVSession controller command listeners. */
  private async unregisterSessionControlListeners(): Promise<void> {
    if (!this.session) {
      return;
    }
    try {
      this.session.off('play');
      this.session.off('pause');
      this.session.off('playNext');
      this.session.off('playPrevious');
      this.session.off('seek');
    } catch (error) {
      Logger.error(TAG, `${error.code} + ${error.message}`);
    }
  }

  /** Updates AVSession metadata (title, artist, duration, optional cover) for the current track. */
  /**
   * Enables the system/desktop lyric feature for this session so the lyric carried by
   * AVMetadata is rendered outside the app (car head unit, control center, desktop lyric).
   */
  private async enableSystemLyric(session: avSession.AVSession): Promise<void> {
    try {
      const supported: boolean = await avSession.isDesktopLyricSupported();
      if (!supported) {
        Logger.info(TAG, 'system lyric not supported on this device');
        return;
      }
      await session.enableDesktopLyric(true);
      Logger.info(TAG, 'system lyric enabled');
    } catch (error) {
      Logger.warn(TAG, `enable system lyric failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async setAVMetadata(): Promise<void> {
    const id = this.musicIndex;
    try {
      if (!this.abilityContext) {
        return;
      }
      const ctx = this.abilityContext;
      const metaSong = this.getSongItemAtQueueIndex(this.musicIndex);
      if (!metaSong) {
        return;
      }
      let mediaImage: PixelMap | undefined = undefined;
      try {
        if (metaSong.cover.length > 0) {
          // Online cover: fetch bytes then decode into a PixelMap for the control-center card.
          try {
            mediaImage = await this.loadCoverPixelMap(metaSong.cover);
            if (mediaImage !== undefined) {
              Logger.info(TAG, 'online cover pixelMap success');
            }
          } catch (error) {
            Logger.warn(TAG, `setAVMetadata online cover failed: ${error instanceof Error ? error.message : String(error)}`);
          }
        }
        if (mediaImage === undefined) {
          try {
            mediaImage = await MediaTools.getPixelMapFromResource(ctx,
              metaSong.label as resourceManager.Resource);
            Logger.info(TAG, 'getPixelMapFromResource success');
          } catch (error) {
            Logger.warn(TAG, `setAVMetadata cover fallback: ${error instanceof Error ? error.message : String(error)}`);
          }
        }
        const song = metaSong;
        // 播控中心歌词：统一转标准 LRC（系统要求标准歌词格式，总量 ≤128KB）。
        // 歌词未缓存时（大歌词首次解析耗时长）延迟到解析完成后重推，避免阻塞 UI 线程。
        const cachedLyric: AmllLyricLine[] | undefined = amllGetCachedLyric(song.lyricText);
        const metadata: avSession.AVMetadata = {
          assetId: `${id}`,
          title: StringResourceUtil.resolve(ctx, song.title),
          artist: StringResourceUtil.resolve(ctx, song.singer),
          duration: this.getDuration()
        };
        if (cachedLyric !== undefined) {
          const lrcText: string = truncateLrc(buildPlainLrc(cachedLyric));
          if (lrcText.length > 0) {
            metadata.lyric = lrcText;
          }
        } else if (song.lyricText.length > 0) {
          this.scheduleLyricMetadataRefresh();
        }
        if (mediaImage !== undefined) {
          metadata.mediaImage = mediaImage;
        }
        if (this.session) {
          try {
            await this.session.setAVMetadata(metadata);
            Logger.info(TAG, 'SetAVMetadata successfully');
          } catch (err) {
            Logger.error(TAG, `SetAVMetadata failed: ${err instanceof Error ? err.message : String(err)}`);
          }
        }
      } finally {
        if (mediaImage !== undefined) {
          try {
            mediaImage.release();
          } catch (error) {
            Logger.warn(TAG, `mediaImage.release failed: ${error instanceof Error ? error.message : String(error)}`);
          }
        }
      }
    } catch (error) {
      Logger.error(TAG, `SetAVMetadata failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /** Downloads cover bytes and decodes them into a PixelMap for AVSession metadata. */
  private async loadCoverPixelMap(coverUrl: string): Promise<PixelMap | undefined> {
    const httpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await httpRequest.request(coverUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (resp.responseCode !== 200 || resp.result === undefined) {
        return undefined;
      }
      const imageSource = image.createImageSource(resp.result as ArrayBuffer);
      try {
        return await imageSource.createPixelMap();
      } finally {
        imageSource.release();
      }
    } catch (_err) {
      return undefined;
    } finally {
      httpRequest.destroy();
    }
  }

  /** Appends a marker line to the shared run log (visible in settings). */
  private appendPlayLog(message: string): void {
    appendPlayLog(message);
  }

  /**
   * Load media asset for the given queue index (prepare or switch track).
   *
   * @param musicIndex Index in the play queue.
   * @param loadOnly When true, only load without starting playback.
   */
  public async loadAsset(musicIndex: number, loadOnly?: boolean): Promise<void> {
    // 主动加载新歌即取消尚未执行的一次错误恢复，避免旧定时器干扰新播放
    this.errorRecoveryPending = false;
    this.applyAudioSession(MusicStoreService.getInstance().getAudioMix());
    const len = this.getQueueLength();
    if (len === 0) {
      this.appendPlayLog('[播放] loadAsset 队列为空');
      Logger.error(TAG, 'play queue is empty when loadAsset');
      return;
    }
    if (musicIndex < 0 || musicIndex >= len) {
      this.appendPlayLog('[播放] loadAsset 索引越界 ' + musicIndex);
      Logger.error(TAG, `current musicIndex ${musicIndex}`);
      return;
    }
    const queueSong = this.getSongItemAtQueueIndex(musicIndex);
    if (!queueSong) {
      this.appendPlayLog('[播放] loadAsset 歌曲解析失败');
      Logger.error(TAG, `resolve song failed at queue index ${musicIndex}`);
      return;
    }
    if (queueSong.url.length === 0 && queueSong.source.length > 0) {
      const resolved = await this.resolveOnlineUrl(queueSong);
      this.appendPlayLog('[播放] resolveOnlineUrl=' + resolved);
      if (!resolved) {
        this.getAppState().isResolving = false;
        return;
      }
    } else if (queueSong.source.length > 0) {
      await this.enrichOnlineTrack(queueSong);
    }
    this.ensureBackgroundAudioTask();
    this.updateMusicIndex(musicIndex);
    if (!this.avPlayer) {
      // Defer play until initAudioPlayer creates AVPlayer; loadAsset is applied then.
      this.appendPlayLog('[播放] avPlayer 未就绪，挂起等待');
      this.pendingLoadIndex = musicIndex;
      this.pendingLoadOnly = loadOnly === true;
      return;
    }
    if (this.isFirst) {
      this.isFirst = false;
      this.appendPlayLog('[播放] 首次加载 url=' + queueSong.url);
      this.songItem = await this.songItemBuilder.build(queueSong);
      let httpUrl = this.songItemBuilder.getHttpUrl();
      if (this.avPlayer) {
        if (httpUrl.length > 0) {
          if (loadOnly) {
            this.isNeedPlay = false;
          }
          this.avPlayer.url = httpUrl;
          Logger.info(TAG, 'loadAsset avPlayer.url:' + this.avPlayer.url);
        } else {
          let url = this.songItemBuilder.getRealUrl();
          if (url) {
            if (loadOnly) {
              this.isNeedPlay = false;
            }
            let avFileDescriptor: media.AVFileDescriptor = { fd: url.fd, offset: url.offset, length: url.length };
            this.avPlayer.fdSrc = avFileDescriptor;
            Logger.info(TAG, 'loadAsset avPlayer.fdSrc:' + this.avPlayer.fdSrc);
          }
        }
      }
    } else {
      // 非首次切歌：无条件 reset（不依赖 isPrepared）。快速连续切歌时，上一首可能尚未
      // prepared（isPrepared=false），此时 stop() 会因 guard 空转导致新歌不加载。
      // reset 后 avPlayer 回到 idle，idle 状态回调会重新 build 当前歌曲并触发 prepare。
      this.isNeedPlay = loadOnly !== true;
      if (this.state === AudioPlayerState.IDLE) {
        // 关键：错误恢复/上轮 reset 后播放器已在 idle。对 idle 播放器再调 reset()
        // 没有状态变化、不会触发 idle 回调，新 url 永远装不进去（日志表现为
        // 「跨源重试解析结果=true」之后一片安静）。必须直接装载当前曲目。
        this.appendPlayLog('[播放] 播放器已处 idle，跳过 reset 直接装载 index=' + musicIndex);
        await this.loadCurrentIntoPlayer();
      } else {
        await this.reset();
      }
    }
    this.persistQueueSnapshot();
  }

  /**
   * Whether the player has not yet applied the first fdSrc on this AVPlayer instance.
   *
   * @returns True until first asset load completes.
   */
  public getFirst() {
    return this.isFirst;
  }

  /**
   * Set music play mode (order, shuffle, repeat, etc.).
   *
   * @param playMode Target play mode.
   */
  public setPlayMode(playMode: MusicPlayMode) {
    this.playMode = playMode;
    MusicStoreService.getInstance().setPlayMode(playMode as number);
    Logger.info(TAG, 'setPlayMode mode: ' + this.playMode);
  }

  /**
   * Get music play mode.
   *
   * @returns playMode.
   */
  public getPlayMode() {
    return this.playMode;
  }

  /** Executes a desktop-card control action (playPause / next / previous). */
  public handleCardAction(action: string): void {
    appendPlayLog('[播放] 桌面卡片操作: ' + action);
    if (action === 'playPause') {
      if (this.getAppState().isPlay) {
        this.pause();
      } else {
        void this.play();
      }
      return;
    }
    if (action === 'next') {
      this.playNextAuto(false);
      return;
    }
    if (action === 'previous') {
      this.playPrevious();
    }
  }

  /** Re-persists the song snapshot (now with cover/lyrics) and refreshes the desktop card. */
  private syncCardSongSnapshot(song: SongItem): void {
    if (song.source.length === 0) {
      return;
    }
    MusicStoreService.getInstance().setLastSong(
      JSON.stringify(MusicStoreService.fromSongItem(song)) || '');
    MusicCardBridge.notify();
  }

  /** Mirrors the play state into the card store and refreshes the desktop card (cheap IPC). */
  private syncCardPlayingFlag(isPlay: boolean): void {
    const store: MusicStoreService = MusicStoreService.getInstance();
    if (store.getCardPlaying() === isPlay) {
      return;
    }
    store.setCardPlaying(isPlay);
    MusicCardBridge.notify();
  }

  /** @returns Whether audio is currently playing (used by the desktop card bridge). */
  public isPlayingState(): boolean {
    return this.getAppState().isPlay;
  }

  /** Updates MusicAppState.isPlay and AVSession playback state snapshot. */
  private updateIsPlay(isPlay: boolean) {
    this.getAppState().isPlay = isPlay;
    this.syncCardPlayingFlag(isPlay);
    this.liveViewController.setPlaying(isPlay);
    this.setPlayState({
      state: isPlay ? avSession.PlaybackState.PLAYBACK_STATE_PLAY : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: {
        elapsedTime: this.getCurrentTime(),
        updateTime: new Date().getTime()
      }
    });
  }

  /**
   * Seeks the current track to the given position in milliseconds.
   *
   * @param ms Target position in ms, clamped to [0, duration].
   */
  public seek(ms: number) {
    if (this.isPrepared && this.state != AudioPlayerState.ERROR && this.avPlayer) {
      // SeekMode.SEEK_CLOSEST(2)：帧级精确 seek，跳转到距目标最近的帧（不限于关键帧），
      // 保证点击歌词/进度条拖拽准确落在目标时间，不会落到目标前最近的关键帧
      let seekMode: number = 2;
      let realTime = (ms <= 0 ? 0 : (ms >= this.getDuration() ? this.getDuration() : ms));
      this.isCurrent = false;
      this.avPlayer.seek(realTime, seekMode);
    }
  }

  /** Current playback position in ms from AVPlayer, or 0 if not prepared. */
  private getCurrentTime() {
    if (this.isPrepared && this.avPlayer) {
      return this.avPlayer.currentTime;
    }
    return 0;
  }

  /** Total duration in ms from AVPlayer, or 0 if not prepared. */
  private getDuration() {
    if (this.isPrepared && this.avPlayer) {
      return this.avPlayer.duration;
    }
    return 0;
  }

  /**
   * Reloads the current track when play() is requested while the player is not
   * prepared (after an error or stop). Blindly calling prepare() on a reset
   * (idle, url-less) player fails silently, which the user perceives as
   * "the play button does nothing" — a full loadAsset re-resolves the url and
   * runs the fallback chain instead.
   */
  private start(seekMs?: number) {
    Logger.info(TAG, 'AVPlayer start() isPrepared:' + this.isPrepared + ', state:' + this.state +
      '，seek:' + seekMs + ' → 重载当前歌曲 index=' + this.musicIndex);
    this.appendPlayLog('[播放] 播放器未就绪，点播放触发重载当前歌曲 index=' + this.musicIndex);
    this.loadAsset(this.musicIndex).catch((err: Object): void => {
      appendPlayLog('[播放] 重载当前歌曲异常: ' + JSON.stringify(err).substring(0, 120));
    });
  }

  /**
   * Starts or resumes playback; triggers prepare if the player is not prepared yet.
   */
  public async play() {
    Logger.info(TAG, 'AVPlayer play() isPrepared:' + this.isPrepared + ', state:' + this.state);
    this.ensureBackgroundAudioTask();
    if (!this.isPrepared) {
      this.start(0);
    } else if (this.avPlayer) {
      try {
        this.avPlayer.play().then(() => {
          // 恢复播放后无需再 seek 到当前时间：暂停位置原地续播，避免立刻 seek 造成短暂音频毛刺
          // （进度由 timeUpdate 事件自动同步）
          this.updateIsPlay(true);
          this.state = AudioPlayerState.PLAY;
        });
      } catch (error) {
        Logger.error(TAG, `${error.code} + ${error.message}`);
      }
    }
  }

  /**
   * Pauses playback when currently in PLAY state.
   */
  public pause() {
    Logger.info(TAG, 'AVPlayer pause() isPrepared:' + this.isPrepared + ', state:' + this.state);
    if (this.isPrepared && this.state === AudioPlayerState.PLAY && this.avPlayer) {
      this.avPlayer.pause().then(() => {
        this.state = AudioPlayerState.PAUSE;
        this.updateIsPlay(false);
        this.pausedByInterrupt = false;
        if (this.abilityContext) {
          BackgroundUtil.stopContinuousTask(this.abilityContext);
        }
      }).catch((err: BusinessError) => {
        Logger.error(TAG, 'Failed to pause,error message is :' + err.message);
      })
    }
  }

  /**
   * Advances playback according to play mode (order, random, single-cycle).
   *
   * @param isFromControl True when invoked from user/system control (vs track completion).
   */
  public playNextAuto(isFromControl: boolean) {
    Logger.info(TAG, 'playNextAuto mode:' + this.playMode);
    switch (this.playMode) {
      case MusicPlayMode.SINGLE_CYCLE:
        if (isFromControl) {
          this.playNext();
        } else if (this.avPlayer) {
          try {
            this.avPlayer.play();
          } catch (error) {
            Logger.error(TAG, `${error.code} + ${error.message}`);
          }
        }
        break;
      case MusicPlayMode.ORDER:
        this.playNext();
        break;
      case MusicPlayMode.RANDOM:
        this.playRandom();
        break;
      default:
        break;
    }
  }

  /** Loads the next queue index in linear order (wraps to 0 at end). */
  private playNext() {
    const len = this.getQueueLength();
    if (len === 0) {
      return;
    }
    Logger.info(TAG, 'playNext Index:' + this.musicIndex + ', length-1:' + (len - 1));
    if (this.musicIndex === len - 1) {
      this.loadAsset(0);
    } else {
      this.loadAsset(this.musicIndex + 1);
    }
  }

  /**
   * Goes to the previous track for order / single-cycle, or random pick in random mode.
   */
  public playPrevious() {
    const len = this.getQueueLength();
    if (len === 0) {
      return;
    }
    switch (this.playMode) {
      case MusicPlayMode.RANDOM:
        this.playRandom();
        break;
      case MusicPlayMode.ORDER:
      case MusicPlayMode.SINGLE_CYCLE:
        if (this.musicIndex === 0) {
          this.updateMusicIndex(len - 1);
        } else {
          this.updateMusicIndex(this.musicIndex - 1);
        }
        Logger.info(TAG, 'setLastIndex:' + this.musicIndex);
        this.loadAsset(this.musicIndex);
        break;
      default:
        break;
    }
  }

  /** Picks a random queue index different from the current one (when length > 1). */
  private playRandom() {
    const len = this.getQueueLength();
    if (len <= 1) {
      if (len === 1) {
        this.loadAsset(0);
      }
      return;
    }
    // Uniform on {0..len-1} \ {musicIndex}; avoids recursion and stack overflow on repeated collisions.
    const k: number = Math.floor(Math.random() * (len - 1));
    const num: number = k < this.musicIndex ? k : k + 1;
    this.updateMusicIndex(num);
    this.loadAsset(num);
    Logger.info(TAG, 'play Random:' + this.musicIndex);
  }

  /**
   * Stops AVPlayer and clears playing state when prepared.
   */
  public async stop() {
    Logger.info(TAG, 'stop()');
    if (this.isPrepared && this.avPlayer) {
      try {
        await this.avPlayer.stop();
        this.updateIsPlay(false);
        this.state = AudioPlayerState.PAUSE;
        // stop 成功后播放器即将回到 idle，同步 isPrepared=false，
        // 避免后续 play() 走错分支（对已 reset 的空 url 播放器调 play 无效）。
        this.isPrepared = false;
        if (this.abilityContext) {
          BackgroundUtil.stopContinuousTask(this.abilityContext);
        }
      } catch (error) {
        Logger.error(TAG, `${error.code} + ${error.message}`);
      }
    }
  }

  /** Resets AVPlayer and releases SongItemBuilder resources. */
  private async reset() {
    Logger.info(TAG, 'reset()');
    await this.songItemBuilder.release();
    if (this.avPlayer) {
      try {
        await this.avPlayer.reset();
      } catch (error) {
        Logger.error(TAG, `${error.code} + ${error.message}`);
      }
    }
    this.isPrepared = false;
  }

  /**
   * Releases AVPlayer and AVSession; intended for ability teardown (best-effort sync calls).
   */
  public async release(): Promise<void> {
    if (this.avPlayer && this.session && this.abilityContext) {
      try {
        this.updateIsPlay(false);
        this.liveViewController.stop();
        await this.stop();
        await this.reset();
        await this.avPlayer.release();
        this.state = AudioPlayerState.IDLE;
        BackgroundUtil.stopContinuousTask(this.abilityContext);
        this.unregisterSessionControlListeners();
        this.unregisterAudioDeviceListener();
        this.session.destroy((err: BusinessError) => {
          if (err) {
            Logger.error(TAG, `Failed to destroy session. Code: ${err.code}, message: ${err.message}`);
          } else {
            Logger.info(TAG, `Destroy : SUCCESS `);
          }
        });
      } catch (error) {
        const msg: string = error instanceof Error ? error.message : String(error);
        Logger.error(TAG, `release failed: ${msg}`);
      }
    }
  }

  /** Writes selectIndex to MusicAppState and refreshes AVSession metadata when index changes. */
  private updateMusicIndex(musicIndex: number) {
    Logger.info(TAG, 'updateMusicIndex ===> ' + musicIndex);
    this.getAppState().selectIndex = musicIndex;
    if (this.musicIndex !== musicIndex) {
      this.musicIndex = musicIndex;
    }
    // 切歌时同步实况窗内容（在线歌曲的歌词此时已由 enrich/resolve 补全）
    const switchedSong = this.getSongItemAtQueueIndex(musicIndex);
    if (switchedSong !== undefined) {
      this.liveViewController.switchTrack(this.resolveSongText(switchedSong.title),
        this.resolveSongText(switchedSong.singer), switchedSong.lyricText);
    }
    Logger.info(TAG, 'this.session !== undefined ===> ' + (this.session != undefined));
    if (this.session !== undefined) {
      this.setAVMetadata();
    }
  }

  /**
   * Removes the song at the given queue index from the play queue and fixes up
   * the current index: shifting back when removing an earlier track, or loading
   * the following track when the currently playing one was removed.
   * @param index Combined queue index (online items first, then local ids).
   */
  public removeQueueIndex(index: number): void {
    const appState = this.getAppState();
    if (index < 0 || index >= appState.getQueueLength()) {
      return;
    }
    const onlineLen: number = appState.playQueue.length;
    if (index < onlineLen) {
      appState.playQueue.splice(index, 1);
    } else {
      appState.playQueueIds.splice(index - onlineLen, 1);
    }
    if (appState.getQueueLength() === 0) {
      appState.selectIndex = 0;
      this.musicIndex = 0;
      this.updateIsPlay(false);
      this.liveViewController.stop();
      MusicStoreService.getInstance().setLastQueue('');
      void this.stop();
      return;
    }
    if (index < appState.selectIndex) {
      appState.selectIndex--;
      if (this.musicIndex > 0) {
        this.musicIndex--;
      }
    } else if (index === appState.selectIndex) {
      const next: number = Math.min(appState.selectIndex, appState.getQueueLength() - 1);
      appState.selectIndex = next;
      this.isNeedPlay = appState.isPlay;
      void this.loadAsset(next);
    }
    this.persistQueueSnapshot();
  }

  /** Pushes playback state (play/pause and position) to AVSession. */
  private async setPlayState(playbackState: avSession.AVPlaybackState) {
    if (this.session) {
      this.session.setAVPlaybackState(playbackState, (err: BusinessError) => {
        if (err) {
          Logger.info(TAG, `SetAVPlaybackState BusinessError: code: ${err.code}, message: ${err.message}`);
        } else {
          Logger.info(TAG, 'SetAVPlaybackState successfully');
        }
      });
    }
  }
}

