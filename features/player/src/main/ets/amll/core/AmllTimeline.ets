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
 * 播放时间线控制器（对应原仓库 packages/core/src/lyric-player/base/timeline.ts 的忠实移植）
 */

/** 用于进度计算的最小歌词数据 */
export interface AmllTimeBounds {
  readonly startTime: number;
  readonly endTime: number;
}

/** 当前命中的间奏区间信息 */
export interface AmllPlayerInterlude {
  readonly startTime: number;
  readonly endTime: number;
  /** 间奏点应插入的位置基准（间奏前最后一句歌词的索引，-1 表示第一句之前） */
  readonly anchorLineIndex: number;
}

/** 当前播放时间线状态的只读快照 */
export interface AmllTimelineSnapshot {
  currentTime: number;
  isSeeking: boolean;
  playingGroups: Set<number>;
  highlightedGroups: Set<number>;
  scrollToIndex: number;
  latestHighlightedIndex: number | undefined;
  isTimelineEmpty: boolean;
  isEndOfSong: boolean;
  activeInterlude: AmllPlayerInterlude | undefined;
  isFocusOnInterlude: boolean;
}

/** 时间线增量变化 */
export interface AmllTimelineDiff {
  hasChanged: boolean;
  addedPlaying: number[];
  removedPlaying: number[];
  addedHighlighted: number[];
  removedHighlighted: number[];
  isInterludeChanged: boolean;
  isScrollToChanged: boolean;
  isTimeJumped: boolean;
}

export class AmllTimelineController {
  private lyricBounds: AmllTimeBounds[] = [];
  private isManualSeeking: boolean = false;
  private precalculatedInterludes: AmllPlayerInterlude[] = [];

  private playbackCursor: number = 0;
  private interludeCursor: number = 0;
  private isFocusOnInterludeState: boolean = false;

  private playingGroupsSet: Set<number> = new Set<number>();
  private highlightedGroupsSet: Set<number> = new Set<number>();

  private addedPlayingIds: number[] = [];
  private removedPlayingIds: number[] = [];
  private addedHighlightedIds: number[] = [];
  private removedHighlightedIds: number[] = [];
  private expiredHighlightedIds: number[] = [];

  private snapshot: AmllTimelineSnapshot = {
    currentTime: 0,
    isSeeking: false,
    playingGroups: this.playingGroupsSet,
    highlightedGroups: this.highlightedGroupsSet,
    scrollToIndex: 0,
    latestHighlightedIndex: undefined,
    isTimelineEmpty: true,
    isEndOfSong: false,
    activeInterlude: undefined,
    isFocusOnInterlude: false
  };

  private diff: AmllTimelineDiff = {
    hasChanged: false,
    addedPlaying: this.addedPlayingIds,
    removedPlaying: this.removedPlayingIds,
    addedHighlighted: this.addedHighlightedIds,
    removedHighlighted: this.removedHighlightedIds,
    isInterludeChanged: false,
    isScrollToChanged: false,
    isTimeJumped: false
  };

  public setTimeBounds(bounds: AmllTimeBounds[]): void {
    this.lyricBounds = bounds;
    this.precalculatedInterludes = this.calculateInterludes(bounds);
    this.reset();
  }

  public getSnapshot(): AmllTimelineSnapshot {
    return this.snapshot;
  }

  public sync(time: number, forceSeek: boolean = false): AmllTimelineDiff {
    this.addedPlayingIds.length = 0;
    this.removedPlayingIds.length = 0;
    this.addedHighlightedIds.length = 0;
    this.removedHighlightedIds.length = 0;
    this.expiredHighlightedIds.length = 0;

    const prevInterlude = this.snapshot.activeInterlude;
    const prevFocusOnInterlude = this.snapshot.isFocusOnInterlude;
    const prevScrollToIndex = this.snapshot.scrollToIndex;

    const isTimeRegression: boolean = time < this.snapshot.currentTime;
    const isJump: boolean = forceSeek || isTimeRegression;

    this.snapshot.isSeeking = this.isManualSeeking || isJump;
    if (this.snapshot.isSeeking) {
      this.performSeek(time);
    } else {
      this.performPlayback(time);
    }

    this.updateInterludeState(time, isJump);

    const isInterludeChanged: boolean = prevInterlude !== this.snapshot.activeInterlude;
    const isFocusChanged: boolean = prevFocusOnInterlude !== this.snapshot.isFocusOnInterlude;
    const isScrollToChanged: boolean = prevScrollToIndex !== this.snapshot.scrollToIndex;

    const hasChanged: boolean =
      isJump ||
      this.addedPlayingIds.length > 0 ||
      this.removedPlayingIds.length > 0 ||
      this.addedHighlightedIds.length > 0 ||
      this.removedHighlightedIds.length > 0 ||
      isInterludeChanged ||
      isFocusChanged ||
      isScrollToChanged;

    this.snapshot.currentTime = time;
    this.snapshot.isTimelineEmpty = this.highlightedGroupsSet.size === 0;

    if (this.highlightedGroupsSet.size > 0) {
      let maxIndex = -1;
      this.highlightedGroupsSet.forEach((id: number) => {
        if (id > maxIndex) {
          maxIndex = id;
        }
      });
      this.snapshot.latestHighlightedIndex = maxIndex;
    } else {
      this.snapshot.latestHighlightedIndex = undefined;
    }

    this.snapshot.isEndOfSong = false;
    if (this.highlightedGroupsSet.size === 0 && this.lyricBounds.length > 0) {
      const lastLine = this.lyricBounds[this.lyricBounds.length - 1];
      if (time >= lastLine.endTime) {
        this.snapshot.isEndOfSong = true;
      }
    }

    const d = this.diff;
    d.hasChanged = hasChanged;
    d.isInterludeChanged = isInterludeChanged;
    d.isScrollToChanged = isScrollToChanged;
    d.isTimeJumped = isJump;

    return this.diff;
  }

  public setSeekingState(isSeeking: boolean): void {
    this.isManualSeeking = isSeeking;
    this.snapshot.isSeeking = isSeeking;
  }

  /** 处理正常播放时的时间线推导 */
  private performPlayback(time: number): void {
    const finished: number[] = [];
    this.playingGroupsSet.forEach((id: number) => {
      const bound = this.lyricBounds[id];
      if (bound === undefined || time < bound.startTime || bound.endTime <= time) {
        finished.push(id);
      }
    });
    for (let i = 0; i < finished.length; i++) {
      this.playingGroupsSet.delete(finished[i]);
      this.removedPlayingIds.push(finished[i]);
    }

    let cursor = Math.max(0, this.playbackCursor);
    const len = this.lyricBounds.length;
    while (cursor < len) {
      const bound = this.lyricBounds[cursor];
      if (bound.startTime > time) {
        break;
      }
      if (
        bound.startTime <= time &&
        bound.endTime > time &&
        !this.playingGroupsSet.has(cursor)
      ) {
        this.playingGroupsSet.add(cursor);
        this.addedPlayingIds.push(cursor);
      }
      cursor++;
    }

    if (this.playingGroupsSet.size > 0) {
      let minPlaying = Number.POSITIVE_INFINITY;
      this.playingGroupsSet.forEach((id: number) => {
        if (id < minPlaying) {
          minPlaying = id;
        }
      });
      this.playbackCursor = minPlaying;
    } else {
      this.playbackCursor = cursor;
    }

    this.expiredHighlightedIds.length = 0;
    this.highlightedGroupsSet.forEach((id: number) => {
      if (!this.playingGroupsSet.has(id)) {
        this.expiredHighlightedIds.push(id);
      }
    });

    const addedPlayingCount = this.addedPlayingIds.length;
    const expiredCount = this.expiredHighlightedIds.length;

    if (addedPlayingCount > 0) {
      for (let i = 0; i < addedPlayingCount; i++) {
        const id = this.addedPlayingIds[i];
        this.highlightedGroupsSet.add(id);
        this.addedHighlightedIds.push(id);
      }
    }

    const shouldTransitionToNext = addedPlayingCount > 0;
    const isCurrentGroupAllFinished =
      expiredCount > 0 && expiredCount === this.highlightedGroupsSet.size;
    const shouldFlushExpiredLines = shouldTransitionToNext || isCurrentGroupAllFinished;

    if (shouldFlushExpiredLines && expiredCount > 0) {
      for (let i = 0; i < expiredCount; i++) {
        const id = this.expiredHighlightedIds[i];
        this.highlightedGroupsSet.delete(id);
        this.removedHighlightedIds.push(id);
      }
    }

    if (
      (addedPlayingCount > 0 || shouldFlushExpiredLines) &&
      this.highlightedGroupsSet.size > 0
    ) {
      let minHighlighted = Number.POSITIVE_INFINITY;
      this.highlightedGroupsSet.forEach((id: number) => {
        if (id < minHighlighted) {
          minHighlighted = id;
        }
      });
      this.snapshot.scrollToIndex = minHighlighted;
    }
  }

  /** 处理 Seek 时的时间线推导 */
  private performSeek(time: number): void {
    this.playingGroupsSet.forEach((id: number) => {
      this.removedPlayingIds.push(id);
    });
    this.highlightedGroupsSet.forEach((id: number) => {
      this.removedHighlightedIds.push(id);
    });
    this.playingGroupsSet.clear();
    this.highlightedGroupsSet.clear();

    let left = 0;
    let right = this.lyricBounds.length - 1;
    let firstGreaterOrEqual = this.lyricBounds.length;
    while (left <= right) {
      const mid = (left + right) >> 1;
      if (this.lyricBounds[mid].startTime >= time) {
        firstGreaterOrEqual = mid;
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    let minPlayingIndex = Number.POSITIVE_INFINITY;
    const startIndex = Math.min(firstGreaterOrEqual, this.lyricBounds.length - 1);
    for (let i = startIndex; i >= 0; i--) {
      const bound = this.lyricBounds[i];
      if (bound !== undefined && bound.startTime <= time && bound.endTime > time) {
        this.playingGroupsSet.add(i);
        this.highlightedGroupsSet.add(i);
        this.addedPlayingIds.push(i);
        this.addedHighlightedIds.push(i);
        if (i < minPlayingIndex) {
          minPlayingIndex = i;
        }
      }
    }

    if (this.highlightedGroupsSet.size > 0) {
      this.snapshot.scrollToIndex = minPlayingIndex;
      this.playbackCursor = minPlayingIndex;
    } else {
      this.snapshot.scrollToIndex = firstGreaterOrEqual;
      this.playbackCursor = firstGreaterOrEqual;
    }
  }

  /** 预计算间奏区域：与下一行间隔 >= 4000ms */
  private calculateInterludes(bounds: AmllTimeBounds[]): AmllPlayerInterlude[] {
    const interludes: AmllPlayerInterlude[] = [];
    for (let i = -1; i < bounds.length - 1; i++) {
      const prevGroup: AmllTimeBounds | undefined = i === -1 ? undefined : bounds[i];
      const nextGroup = bounds[i + 1];
      const gapStart: number = prevGroup !== undefined ? prevGroup.endTime : 0;
      const gapEnd: number = Math.max(gapStart, nextGroup.startTime);
      if (gapEnd - gapStart >= 4000) {
        interludes.push({
          startTime: gapStart,
          endTime: gapEnd,
          anchorLineIndex: i
        });
      }
    }
    return interludes;
  }

  private updateInterludeState(time: number, isSeek: boolean): void {
    let activeInterlude: AmllPlayerInterlude | undefined = undefined;
    if (this.precalculatedInterludes.length > 0) {
      if (isSeek) {
        let cursor = this.precalculatedInterludes.length;
        let left = 0;
        let right = this.precalculatedInterludes.length - 1;
        while (left <= right) {
          const mid = (left + right) >> 1;
          const inter = this.precalculatedInterludes[mid];
          if (inter.endTime > time) {
            cursor = mid;
            right = mid - 1;
          } else {
            left = mid + 1;
          }
        }
        this.interludeCursor = cursor;
        if (cursor < this.precalculatedInterludes.length) {
          const inter = this.precalculatedInterludes[cursor];
          if (time >= inter.startTime && time < inter.endTime) {
            activeInterlude = inter;
          }
        }
      } else {
        while (this.interludeCursor < this.precalculatedInterludes.length) {
          const inter = this.precalculatedInterludes[this.interludeCursor];
          if (time >= inter.startTime && time < inter.endTime) {
            activeInterlude = inter;
            break;
          } else if (time >= inter.endTime) {
            this.interludeCursor++;
          } else {
            break;
          }
        }
      }
    }

    this.snapshot.activeInterlude = activeInterlude;
    if (activeInterlude !== undefined && this.highlightedGroupsSet.size === 0) {
      this.isFocusOnInterludeState = true;
    } else if (this.highlightedGroupsSet.size > 0 || activeInterlude === undefined) {
      this.isFocusOnInterludeState = false;
    }
    this.snapshot.isFocusOnInterlude = this.isFocusOnInterludeState;
  }

  private reset(): void {
    this.playbackCursor = 0;
    this.interludeCursor = 0;
    this.isFocusOnInterludeState = false;
    this.playingGroupsSet.clear();
    this.highlightedGroupsSet.clear();
    const s = this.snapshot;
    s.currentTime = 0;
    s.isSeeking = false;
    s.scrollToIndex = 0;
    s.latestHighlightedIndex = undefined;
    s.isTimelineEmpty = true;
    s.isEndOfSong = false;
    s.activeInterlude = undefined;
    s.isFocusOnInterlude = false;
  }
}
