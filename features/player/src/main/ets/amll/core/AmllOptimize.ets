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
 * 歌词优化管线（对应原仓库 packages/core/src/utils/optimize-lyric.ts 的忠实移植）
 */
import { AmllLyricLine, AmllLyricWord, AmllOptimizeLyricOptions } from '../model/AmllTypes';

const DEFAULT_OPTIMIZE_OPTIONS: AmllOptimizeLyricOptions = {
  normalizeSpaces: true,
  resetLineTimestamps: true,
  convertExcessiveBackgroundLines: true,
  syncMainAndBackgroundLines: true,
  cleanUnintentionalOverlaps: true,
  tryAdvanceStartTime: true
};

/** 规范化歌词中的空格，将多个连续空格替换为一个空格 */
function normalizeSpaces(lines: AmllLyricLine[]): void {
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    for (let w = 0; w < line.words.length; w++) {
      line.words[w].word = line.words[w].word.replace(/\s+/g, ' ');
    }
  }
}

/** 将行级时间戳强行设为字级时间戳 */
function resetLineTimestamps(lines: AmllLyricLine[]): void {
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (
      line.words.length === 1 &&
      line.words[0].startTime === 0 &&
      line.words[0].endTime === 0 &&
      (line.startTime !== 0 || line.endTime !== 0)
    ) {
      line.words[0].startTime = line.startTime;
      line.words[0].endTime = line.endTime;
    } else if (line.words.length > 0) {
      const firstWord = line.words[0];
      const lastWord = line.words[line.words.length - 1];
      line.startTime = firstWord.startTime;
      line.endTime = lastWord.endTime;
    }
  }
}

/** 把多行背景人声转换为单行背景人声 + 主歌词行的形式 */
function convertExcessiveBackgroundLines(lines: AmllLyricLine[]): void {
  let consecutiveBgCount = 0;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.isBG) {
      consecutiveBgCount++;
      if (consecutiveBgCount > 1) {
        line.isBG = false;
      }
    } else {
      consecutiveBgCount = 0;
    }
  }
}

/** 同步主歌词与背景人声的时间：取两者中最早的开始时间和最晚的结束时间 */
function syncMainAndBackgroundLines(lines: AmllLyricLine[]): void {
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i];
    if (line.isBG) {
      continue;
    }
    const nextLine = lines[i + 1];
    if (nextLine !== undefined && nextLine.isBG) {
      const allWords: AmllLyricWord[] = [];
      for (let w = 0; w < line.words.length; w++) {
        if (line.words[w].word.trim().length > 0) {
          allWords.push(line.words[w]);
        }
      }
      for (let w = 0; w < nextLine.words.length; w++) {
        if (nextLine.words[w].word.trim().length > 0) {
          allWords.push(nextLine.words[w]);
        }
      }
      if (allWords.length > 0) {
        let minStart = Number.POSITIVE_INFINITY;
        let maxEnd = Number.NEGATIVE_INFINITY;
        for (let w = 0; w < allWords.length; w++) {
          if (allWords[w].startTime < minStart) {
            minStart = allWords[w].startTime;
          }
          if (allWords[w].endTime > maxEnd) {
            maxEnd = allWords[w].endTime;
          }
        }
        const finalStart = Math.min(minStart, line.startTime, nextLine.startTime);
        const finalEnd = Math.max(maxEnd, line.endTime, nextLine.endTime);
        line.startTime = finalStart;
        line.endTime = finalEnd;
        nextLine.startTime = finalStart;
        nextLine.endTime = finalEnd;
      }
    }
  }
}

/** 清洗非刻意的重叠 */
function cleanUnintentionalOverlaps(lines: AmllLyricLine[]): void {
  for (let i = 0; i < lines.length - 1; i++) {
    const line = lines[i];
    if (line.isBG) {
      continue;
    }
    let nextMainIndex = i + 1;
    while (nextMainIndex < lines.length && lines[nextMainIndex].isBG) {
      nextMainIndex++;
    }
    if (nextMainIndex < lines.length) {
      const nextLine = lines[nextMainIndex];
      const overlap = line.endTime - nextLine.startTime;
      if (overlap > 0) {
        const nextDuration = nextLine.endTime - nextLine.startTime;
        const percentageThreshold = nextDuration * 0.1;
        const isIntentionalOverlap = overlap > 100 && overlap > percentageThreshold;
        if (!isIntentionalOverlap) {
          line.endTime = nextLine.startTime;
          const attachedBgLine = lines[i + 1];
          if (attachedBgLine !== undefined && attachedBgLine.isBG) {
            attachedBgLine.endTime = nextLine.startTime;
          }
        }
      }
    }
  }
}

/** 尝试让歌词提前最多 600ms 开始，有重叠则最多提前 400ms 或上一行时长的 30% */
function tryAdvanceStartTime(lines: AmllLyricLine[]): void {
  const defaultAdvanceAmount = 600;
  const fallbackAdvanceAmount = 400;
  const fallbackAdvanceRatio = 0.3;

  let prevLineStartTime = 0;
  let prevLineEndTime = 0;
  let prevMainGroupStartTime = 0;
  let prevMainGroupEndTime = 0;
  let hasPrevLine = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.isBG) {
      continue;
    }
    const originalStartTime = line.startTime;
    const originalEndTime = line.endTime;

    let targetAdvanceAmount = 0;
    let safeBoundary = 0;

    if (hasPrevLine) {
      const originallyHadGap = originalStartTime >= prevLineEndTime;
      if (originallyHadGap) {
        targetAdvanceAmount = defaultAdvanceAmount;
        safeBoundary = prevMainGroupEndTime;
      } else {
        targetAdvanceAmount = fallbackAdvanceAmount;
        const prevDuration = prevLineEndTime - prevLineStartTime;
        safeBoundary = prevLineStartTime + prevDuration * fallbackAdvanceRatio;
      }
    } else {
      targetAdvanceAmount = defaultAdvanceAmount;
      safeBoundary = 0;
    }

    const targetTime = line.startTime - targetAdvanceAmount;
    const newStartTime = Math.max(safeBoundary, targetTime);
    if (newStartTime < line.startTime) {
      line.startTime = newStartTime;
    }

    const nextLine = lines[i + 1];
    if (nextLine !== undefined && nextLine.isBG) {
      nextLine.startTime = line.startTime;
    }

    if (hasPrevLine) {
      const overlapsPrevGroup =
        originalStartTime < prevMainGroupEndTime && originalEndTime > prevMainGroupStartTime;
      if (overlapsPrevGroup) {
        prevMainGroupStartTime = Math.min(prevMainGroupStartTime, originalStartTime);
        prevMainGroupEndTime = Math.max(prevMainGroupEndTime, originalEndTime);
      } else {
        prevMainGroupStartTime = originalStartTime;
        prevMainGroupEndTime = originalEndTime;
      }
    } else {
      prevMainGroupStartTime = originalStartTime;
      prevMainGroupEndTime = originalEndTime;
    }

    prevLineStartTime = originalStartTime;
    prevLineEndTime = originalEndTime;
    hasPrevLine = true;
  }
}

/** 合并优化配置（b 优先） */
function mergeOptimizeOptions(
  a: AmllOptimizeLyricOptions,
  b: AmllOptimizeLyricOptions | undefined
): AmllOptimizeLyricOptions {
  const result: AmllOptimizeLyricOptions = {};
  if (a.normalizeSpaces !== undefined) {
    result.normalizeSpaces = a.normalizeSpaces;
  }
  if (a.resetLineTimestamps !== undefined) {
    result.resetLineTimestamps = a.resetLineTimestamps;
  }
  if (a.convertExcessiveBackgroundLines !== undefined) {
    result.convertExcessiveBackgroundLines = a.convertExcessiveBackgroundLines;
  }
  if (a.syncMainAndBackgroundLines !== undefined) {
    result.syncMainAndBackgroundLines = a.syncMainAndBackgroundLines;
  }
  if (a.cleanUnintentionalOverlaps !== undefined) {
    result.cleanUnintentionalOverlaps = a.cleanUnintentionalOverlaps;
  }
  if (a.tryAdvanceStartTime !== undefined) {
    result.tryAdvanceStartTime = a.tryAdvanceStartTime;
  }
  if (b !== undefined) {
    if (b.normalizeSpaces !== undefined) {
      result.normalizeSpaces = b.normalizeSpaces;
    }
    if (b.resetLineTimestamps !== undefined) {
      result.resetLineTimestamps = b.resetLineTimestamps;
    }
    if (b.convertExcessiveBackgroundLines !== undefined) {
      result.convertExcessiveBackgroundLines = b.convertExcessiveBackgroundLines;
    }
    if (b.syncMainAndBackgroundLines !== undefined) {
      result.syncMainAndBackgroundLines = b.syncMainAndBackgroundLines;
    }
    if (b.cleanUnintentionalOverlaps !== undefined) {
      result.cleanUnintentionalOverlaps = b.cleanUnintentionalOverlaps;
    }
    if (b.tryAdvanceStartTime !== undefined) {
      result.tryAdvanceStartTime = b.tryAdvanceStartTime;
    }
  }
  return result;
}

/**
 * 优化歌词行的展示效果（原地修改入参，须先深克隆歌词行数组）
 */
export function amllOptimizeLyricLines(
  lines: AmllLyricLine[],
  options?: AmllOptimizeLyricOptions
): void {
  const config: AmllOptimizeLyricOptions = mergeOptimizeOptions(DEFAULT_OPTIMIZE_OPTIONS, options);
  if (config.normalizeSpaces !== false) {
    normalizeSpaces(lines);
  }
  if (config.resetLineTimestamps !== false) {
    resetLineTimestamps(lines);
  }
  if (config.convertExcessiveBackgroundLines !== false) {
    convertExcessiveBackgroundLines(lines);
  }
  if (config.syncMainAndBackgroundLines !== false) {
    syncMainAndBackgroundLines(lines);
  }
  if (config.cleanUnintentionalOverlaps !== false) {
    cleanUnintentionalOverlaps(lines);
  }
  if (config.tryAdvanceStartTime !== false) {
    tryAdvanceStartTime(lines);
  }
}
