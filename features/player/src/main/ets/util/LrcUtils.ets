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

import { Logger } from 'musicbasic';
import { LrcEntry } from '../model/LrcEntry';
import { AmllLyricLine } from '../amll/model/AmllTypes';

/** Matches LRC timestamp tags like [00:21.98] on each line. */
const lrcLineRegex: RegExp = new RegExp('\\[\\d{2,}:\\d{2}((\\.|:)\\d{2,})\\]', 'g');
/** Extracts minutes portion from an LRC timestamp bracket. */
const lrcTimeRegex1: RegExp = new RegExp('\\[\\d{2,}', 'i');
/** Extracts seconds.fraction portion from an LRC timestamp bracket. */
const lrcTimeRegex2: RegExp = new RegExp('\\d{2}\\.\\d{2,}', 'i');

/**
 * Parses standard LRC text into timed LrcEntry lines (no per-character words).
 *
 * @param text Full .lrc file contents.
 * @returns Sorted lines with inferred lineDuration from the following line.
 */
export function parseLrcLyric(text: string): Array<LrcEntry> {
  if (!text) {
    return [];
  }
  const normalizedText: string = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  let lyric: string[] = normalizedText.split('\n');
  let lrc: LrcEntry[] = [];
  for (let lineIndex = 0; lineIndex < lyric.length; lineIndex++) {
    let lineTime = lyric[lineIndex].match(lrcLineRegex);
    let lineText = lyric[lineIndex].replace(lrcLineRegex, '');
    if (lineTime && lineText) {
      for (let timeIndex = 0; timeIndex < lineTime.length; timeIndex++) {
        const tag: string = lineTime[timeIndex];
        const minMatch: RegExpMatchArray | null = tag.match(lrcTimeRegex1);
        const secMatch: RegExpMatchArray | null = tag.match(lrcTimeRegex2);
        if (!minMatch || minMatch.length === 0 || !secMatch || secMatch.length === 0) {
          continue;
        }
        const min: number = Number(minMatch[0].slice(1));
        const sec: number = Number.parseFloat(secMatch[0]);
        if (!Number.isFinite(min) || !Number.isFinite(sec)) {
          continue;
        }
        let timeInSeconds = (min * 60 + sec) * 1000;
        lrc.push({
          lineStartTime: timeInSeconds,
          lineDuration: 0,
          lineWords: lineText
        });
      }
    }
  }
  if (lrc && lrc.length > 0) {
    lrc.sort((left, right) => {
      return left.lineStartTime - right.lineStartTime;
    });
    for (let entryIndex = 0; entryIndex < lrc.length; entryIndex++) {
      if (entryIndex === lrc.length - 1) {
        lrc[entryIndex].lineDuration = Number.MAX_VALUE;
      } else {
        lrc[entryIndex].lineDuration = lrc[entryIndex + 1].lineStartTime - lrc[entryIndex].lineStartTime;
      }
    }
  } else {
    Logger.error('Failed to parse the lyrics.');
  }
  return lrc;
}

/** Default byte budget for AVMetadata.lyric (the system limit is 128 KB). */
const LRC_MAX_CHARS: number = 128 * 1024;

/**
 * Builds a plain LRC text (standard `[mm:ss.xx]lyric` lines with CRLF endings) from
 * parsed AMLL lines. Any lyric format can be normalized this way so the system
 * control center / lock screen can always parse it.
 * @param lines Parsed lyric lines (may come from LRC/AMLL/KRC/TTML sources).
 * @returns Standard LRC text; empty string when there is no lyric content.
 */
export function buildPlainLrc(lines: AmllLyricLine[]): string {
  let lrc: string = '';
  for (let i = 0; i < lines.length; i++) {
    const words = lines[i].words;
    let text: string = '';
    for (let w = 0; w < words.length; w++) {
      text += words[w].word;
    }
    if (text.length === 0) {
      continue;
    }
    const total: number = lines[i].startTime;
    const minutes: number = Math.floor(total / 60000);
    const seconds: number = (total % 60000) / 1000;
    const minuteTag: string = String(minutes).padStart(2, '0');
    const secondTag: string = seconds.toFixed(2).padStart(5, '0');
    lrc += '[' + minuteTag + ':' + secondTag + ']' + text + '\r\n';
  }
  return lrc;
}

/**
 * Truncates LRC text to the given budget, cutting at the last CRLF boundary so no
 * time-tag line is split in half.
 * @param lrc Full LRC text.
 * @param maxChars Maximum allowed characters (defaults to the 128 KB system limit).
 * @returns Truncated LRC text.
 */
export function truncateLrc(lrc: string, maxChars: number = LRC_MAX_CHARS): string {
  if (lrc.length <= maxChars) {
    return lrc;
  }
  const cut: string = lrc.substring(0, maxChars);
  const lastBreak: number = cut.lastIndexOf('\r\n');
  return lastBreak > 0 ? cut.substring(0, lastBreak) : cut;
}
