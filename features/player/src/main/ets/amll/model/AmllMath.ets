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
 * AMLL 基础数学与字符串工具函数（对应原仓库 packages/core/src/utils/ 下各文件）。
 */
import { AmllLyricLine, AmllLyricWord, AmllRubyTag } from './AmllTypes';

/** clamp(x, min, max) */
export function amllClamp(x: number, min: number, max: number): number {
  return Math.min(Math.max(x, min), max);
}

/** clamp01(x) */
export function amllClamp01(x: number): number {
  return amllClamp(x, 0, 1);
}

const CJK_RE: RegExp = new RegExp('^[\\u4e00-\\u9fff\\u0800-\\u9ffc]+$');

/**
 * 判定字符串是否为 CJK 字符（对应原仓库 is-cjk.ts 的 isCJK）
 */
export function amllIsCJK(char: string): boolean {
  return CJK_RE.test(char);
}

/** 全局 Grapheme 分割器（模拟 Intl.Segmenter granularity=grapheme 的简易实现） */
export function amllSplitGraphemes(text: string): string[] {
  const result: string[] = [];
  let current: string = '';
  for (let i = 0; i < text.length; i++) {
    const code: number = text.charCodeAt(i);
    const isSurrogate: boolean = code >= 0xd800 && code <= 0xdbff;
    if (i + 1 < text.length && isSurrogate) {
      const low: number = text.charCodeAt(i + 1);
      if (low >= 0xdc00 && low <= 0xdfff) {
        current += text.charAt(i) + text.charAt(i + 1);
        i++;
        result.push(current);
        current = '';
        continue;
      }
    }
    // 组合字符附加到前一个字符（模拟 grapheme 行为）
    if (current.length > 0 && (code >= 0x0300 && code <= 0x036f)) {
      current += text.charAt(i);
      continue;
    }
    if (current.length > 0) {
      result.push(current);
    }
    current = text.charAt(i);
  }
  if (current.length > 0) {
    result.push(current);
  }
  return result;
}

/** 导函数（对应原仓库 utils/derivative.ts） */
export function amllDerivative(f: (x: number) => number): (x: number) => number {
  const h = 0.001;
  return (x: number): number => (f(x + h) - f(x - h)) / (2 * h);
}

/** 歌词解析通用工具（对应原仓库 packages/lyric/src/utils.ts） */
export function amllCreateLine(line: Partial<AmllLyricLine>): AmllLyricLine {
  const result: AmllLyricLine = {
    words: [],
    translatedLyric: '',
    romanLyric: '',
    isBG: false,
    isDuet: false,
    startTime: 0,
    endTime: 0
  };
  if (line.words !== undefined) {
    result.words = line.words;
  }
  if (line.translatedLyric !== undefined) {
    result.translatedLyric = line.translatedLyric;
  }
  if (line.romanLyric !== undefined) {
    result.romanLyric = line.romanLyric;
  }
  if (line.romanWords !== undefined) {
    result.romanWords = line.romanWords;
  }
  if (line.isBG !== undefined) {
    result.isBG = line.isBG;
  }
  if (line.isDuet !== undefined) {
    result.isDuet = line.isDuet;
  }
  if (line.startTime !== undefined) {
    result.startTime = line.startTime;
  }
  if (line.endTime !== undefined) {
    result.endTime = line.endTime;
  }
  return result;
}

export function amllCreateWord(word: Partial<AmllLyricWord>): AmllLyricWord {
  const result: AmllLyricWord = {
    startTime: 0,
    endTime: 0,
    word: ''
  };
  if (word.startTime !== undefined) {
    result.startTime = word.startTime;
  }
  if (word.endTime !== undefined) {
    result.endTime = word.endTime;
  }
  if (word.word !== undefined) {
    result.word = word.word;
  }
  if (word.romanWord !== undefined) {
    result.romanWord = word.romanWord;
  }
  if (word.obscene !== undefined) {
    result.obscene = word.obscene;
  }
  if (word.ruby !== undefined) {
    result.ruby = word.ruby;
  }
  return result;
}

/** 解析 "mm:ss.xx" 或 "m:ss.xxx" 类时间为毫秒 */
export function amllParseTime(time: string): number {
  const parts: string[] = time.split(':');
  let total = 0;
  for (let i = 0; i < parts.length; i++) {
    const v = Number(parts[i]);
    if (!Number.isFinite(v)) {
      return Number.NaN;
    }
    total = total * 60 + v;
  }
  return Math.round(total * 1000);
}

/** 将毫秒格式化为 "mm:ss.xxx" */
export function amllFormatTime(ms: number): string {
  const min = Math.floor(ms / 60000).toString().padStart(2, '0');
  const sec = Math.floor((ms % 60000) / 1000).toString().padStart(2, '0');
  const msPart = Math.round(ms % 1000).toString().padStart(3, '0');
  return `${min}:${sec}.${msPart}`;
}

export function amllNormalizeTimestamp(ms: number): number {
  if (!Number.isFinite(ms) || ms < 0) {
    return 0;
  }
  return ms;
}

export function amllNormalizeDuration(duration: number): number {
  if (!Number.isFinite(duration) || duration < 0) {
    return 0;
  }
  return duration;
}

/** LRC 最大时间戳 999:99.999 */
export const AMLL_MAX_LRC_TIMESTAMP: number = 60039999;

export function amllClampTimestamp(ms: number, max: number = AMLL_MAX_LRC_TIMESTAMP): number {
  return Math.min(max, amllNormalizeTimestamp(ms));
}

/** 相邻元素两两配对 */
export function amllPairwise<T>(arr: T[]): [T, T][] {
  const result: [T, T][] = [];
  for (let i = 0; i < arr.length - 1; i++) {
    result.push([arr[i], arr[i + 1]]);
  }
  return result;
}

/** 简易深拷贝（用于歌词数组，替代 structuredClone） */
export function amllDeepCloneLines(lines: AmllLyricLine[]): AmllLyricLine[] {
  const result: AmllLyricLine[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const newWords: AmllLyricWord[] = [];
    for (let w = 0; w < line.words.length; w++) {
      const word = line.words[w];
      const newWord: AmllLyricWord = {
        startTime: word.startTime,
        endTime: word.endTime,
        word: word.word,
        romanWord: word.romanWord,
        obscene: word.obscene
      };
      if (word.ruby !== undefined && word.ruby.length > 0) {
        const rubies: AmllRubyTag[] = [];
        for (let r = 0; r < word.ruby.length; r++) {
          const ruby = word.ruby[r];
          rubies.push({ startTime: ruby.startTime, endTime: ruby.endTime, word: ruby.word });
        }
        newWord.ruby = rubies;
      }
      newWords.push(newWord);
    }
    const newLine: AmllLyricLine = {
      words: newWords,
      translatedLyric: line.translatedLyric,
      romanLyric: line.romanLyric,
      romanWords: line.romanWords,
      startTime: line.startTime,
      endTime: line.endTime,
      isBG: line.isBG,
      isDuet: line.isDuet
    };
    result.push(newLine);
  }
  return result;
}

/** 格式化 ASS 时间戳 h:mm:ss.cc */
export function amllWriteASSTimestamp(ms: number): string {
  const normalized = amllNormalizeTimestamp(ms);
  const milli = Math.round(normalized) % 1000;
  const secTotal = Math.floor(Math.round(normalized) / 1000);
  const sec = secTotal % 60;
  const minTotal = Math.floor(secTotal / 60);
  const hour = Math.floor(minTotal / 60);
  return `${hour}:${String(minTotal % 60).padStart(2, '0')}:${String(sec).padStart(2, '0')}.${String(Math.floor(milli / 10)).padStart(2, '0')}`;
}
