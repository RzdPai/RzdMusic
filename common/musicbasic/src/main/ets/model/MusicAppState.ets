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

/**
 * Global observable playback state (AppStorageV2 key: MusicAppState).
 * Playback requests use {@link PlaybackIntentState} and are applied by the product shell, then media services.
 */
import { SongDtoMapper } from '../api/SongDtoMapper';
import { SongItem } from './SongData';
import { MusicDbApi } from '../util/MusicDbApi';

@ObservedV2
export class  MusicAppState {
  /** Online play queue: network song items, served before {@link playQueueIds}. */
  @Trace public playQueue: SongItem[] = [];
  /** Current queue: song ids only; rows resolved on demand via {@link MusicDbApi}. */
  @Trace public playQueueIds: number[] = [];
  /** Index in {@link playQueueIds} for the current track. */
  @Trace public selectIndex: number = 0;
  /** Whether audio is currently playing. */
  @Trace public isPlay: boolean = false;
  /** Elapsed position for the progress bar (0..progressMax when known). */
  @Trace public progress: number = 0;
  /** Duration for the current track, or 0/1 when unknown. */
  @Trace public progressMax: number = 0;
  /** Formatted current time string for UI. */
  @Trace public currentTime: string = '00:00';
  /** Formatted total duration string for UI. */
  @Trace public totalTime: string = '00:00';
  /** Whether the full-screen player overlay is visible. */
  @Trace public isShowPlay: boolean = false;
  /** Time spent on the now-playing sub-page (e.g. to auto-hide chrome). */
  @Trace public pageShowTime: number = 0;
  /** UI volume in 0..1; mirrored to the player when applied. */
  @Trace public volume: number = 0.4;
  /** Cold-start hint for first-launch UI behavior. */
  @Trace public isFirstLaunch: boolean = true;
  /** Full-screen player background color sampled from current artwork. */
  @Trace public imageColor: string = 'rgba(0, 0, 2, 1.00)';
  /** HdsTabs mini bar expanded (true) vs compact (false). */
  @Trace public miniBarExpanded: boolean = false;
  /** Bumped whenever the current track's lyric text is refreshed (async fill). */
  @Trace public lyricVersion: number = 0;
  /** 当前实际播放音质（含自动降级后的结果；空表示尚未解析）。 */
  @Trace public currentQuality: string = '';
  /** 正在后台解析播放地址（换源/降级可能耗时数秒），播放页据此显示「解析中」。 */
  @Trace public isResolving: boolean = false;

  /**
   * Resolves a {@link SongItem} for the given queue index without keeping a full table in memory.
   * Online queue items are served first, then local db ids.
   * @param queueIndex Index into the combined queue.
   * @returns A song item, or undefined if the index is out of range.
   */
  public resolveSongAtQueueIndex(queueIndex: number): SongItem | undefined {
    if (queueIndex < 0) {
      return undefined;
    }
    if (queueIndex < this.playQueue.length) {
      return this.playQueue[queueIndex];
    }
    const idIndex = queueIndex - this.playQueue.length;
    const ids = this.playQueueIds;
    if (idIndex < 0 || idIndex >= ids.length) {
      return undefined;
    }
    const dto = MusicDbApi.getInstance().getSongById(ids[idIndex]);
    return dto !== undefined ? SongDtoMapper.toSongItem(dto) : undefined;
  }

  /**
   * @returns The item at {@link selectIndex}, or undefined.
   */
  public getCurrentSongItem(): SongItem | undefined {
    return this.resolveSongAtQueueIndex(this.selectIndex);
  }

  /**
   * @returns The length of the combined queue (online items plus local ids).
   */
  public getQueueLength(): number {
    return this.playQueue.length + this.playQueueIds.length;
  }

  public replaceQueue(queue: SongItem[], index: number): void {
    this.playQueueIds = [];
    this.playQueue = queue;
    this.selectIndex = index;
  }
}
