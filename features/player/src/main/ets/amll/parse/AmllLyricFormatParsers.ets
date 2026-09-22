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
 * 歌词格式解析器合集（对应原仓库 packages/lyric/src/formats/ 下各文件）
 *
 * 包含：LRC、LRC A2、ESLyric、YRC、QRC、Lyricify Syllable (LYS)、Lyricify Lines (LYL)、
 * Lyricify Quick Export (LQE)、ASS 导出、KRC。
 */
import {
  AmllLyricLine,
  AmllLyricWord
} from '../model/AmllTypes';
import { util } from '@kit.ArkTS';
import {
  AMLL_MAX_LRC_TIMESTAMP,
  amllClampTimestamp,
  amllCreateLine,
  amllCreateWord,
  amllFormatTime,
  amllNormalizeTimestamp,
  amllPairwise,
  amllParseTime
} from '../model/AmllMath';
/** 解析后的时间戳前缀 */
interface AmllTimestampPrefix {
  time: number;
  length: number;
}
/** LQE 属性行 */
interface AmllAttrLine {
  time: number;
  text: string;
}

/** KRC 词段 */
interface AmllKrcSpan {
  start: number;
  dur: number;
  text: string;
}

// ==================== LRC ====================

const LRC_TAG_REGEX: RegExp = new RegExp('^\\[([a-z]+):([^\\]]+)\\]$');
const LRC_TIME_REGEX: RegExp = new RegExp('^\\[((?:\\d+:)*\\d+(?:\\.\\d+)?)\\](.*)$');
const LRC_BG_REGEX: RegExp = new RegExp('^[(（](.+)[)）]$');

/**
 * 解析 LyRiC 格式的歌词字符串
 */
export function amllParseLrc(lrc: string): AmllLyricLine[] {
  const rawLines: string[] = lrc
    .split(/\r?\n/)
    .map((l: string) => l.trim())
    .filter((l: string) => l.length > 0);
  const lyricLines: AmllLyricLine[] = [];
  for (let li = 0; li < rawLines.length; li++) {
    let lineStr = rawLines[li];
    if (LRC_TAG_REGEX.test(lineStr)) {
      continue;
    }
    const timeStamps: number[] = [];
    while (true) {
      const match: RegExpMatchArray | null = lineStr.match(LRC_TIME_REGEX);
      if (match === null) {
        break;
      }
      const timeStr: string = match[1];
      const text: string = match[2];
      const timeStamp = amllParseTime(timeStr);
      if (Number.isNaN(timeStamp)) {
        break;
      }
      timeStamps.push(timeStamp);
      lineStr = text;
    }
    if (timeStamps.length === 0) {
      continue;
    }
    lineStr = lineStr.trim();
    const backgroundMatch: RegExpMatchArray | null = lineStr.match(LRC_BG_REGEX);
    const isBG = backgroundMatch !== null;
    if (backgroundMatch !== null) {
      lineStr = backgroundMatch[1];
    }
    for (let t = 0; t < timeStamps.length; t++) {
      const time = timeStamps[t];
      const word: AmllLyricWord = amllCreateWord({ word: lineStr, startTime: time, endTime: time });
      lyricLines.push(
        amllCreateLine({
          startTime: time,
          endTime: AMLL_MAX_LRC_TIMESTAMP,
          words: [word],
          isBG: isBG
        })
      );
    }
  }
  lyricLines.sort((a: AmllLyricLine, b: AmllLyricLine): number => a.startTime - b.startTime);
  const pairs = amllPairwise(lyricLines);
  for (let i = 0; i < pairs.length; i++) {
    const prev = pairs[i][0];
    const curr = pairs[i][1];
    prev.endTime = curr.startTime;
    prev.words[0].endTime = curr.startTime;
  }
  return lyricLines.filter((line: AmllLyricLine) => line.words[0].word.length > 0);
}

/** 将歌词数组转换为 LRC 格式的字符串 */
export function amllStringifyLrc(lines: AmllLyricLine[]): string {
  const result: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    let text = '';
    for (let w = 0; w < line.words.length; w++) {
      text += line.words[w].word;
    }
    const printText: string = line.isBG ? `(${text})` : text;
    result.push(`[${amllFormatTime(amllNormalizeTimestamp(line.startTime))}]${printText}`);
  }
  return result.join('\n');
}

// ==================== LRC A2 ====================

const LRC_A2_LINE_TIME_REGEX: RegExp = new RegExp('^\\[((?:\\d+:)*\\d+(?:\\.\\d+)?)\\]');
const LRC_A2_WORD_TIME_REGEX: RegExp = new RegExp('<((?:\\d+:)*\\d+(?:\\.\\d+)?)>');
const LRC_A2_WORD_PREFIX_REGEX: RegExp = new RegExp('^<((?:\\d+:)*\\d+(?:\\.\\d+)?)>');

/**
 * 解析 LRC A2（增强 LRC）格式的歌词字符串
 */
export function amllParseLrcA2(lrc: string): AmllLyricLine[] {
  const rawLines: string[] = lrc
    .split(/\r?\n/)
    .map((l: string) => l.trim())
    .filter((l: string) => l.length > 0);
  const lyricLines: AmllLyricLine[] = [];
  for (let li = 0; li < rawLines.length; li++) {
    let lineStr = rawLines[li];
    const tagMatch: RegExpMatchArray | null = lineStr.match(/^\[([a-z]):(.+)\]$/i);
    if (tagMatch !== null) {
      continue;
    }
    const lineTimeStampMatch: RegExpMatchArray | null = lineStr.match(LRC_A2_LINE_TIME_REGEX);
    if (lineTimeStampMatch === null) {
      continue;
    }
    const lineStartTime = amllParseTime(lineTimeStampMatch[1]);
    if (Number.isNaN(lineStartTime)) {
      continue;
    }
    lineStr = lineStr.slice(lineTimeStampMatch[0].length).trim();
    if (lineStr.length === 0) {
      continue;
    }

    const lineItems: (number | string)[] = [];
    while (lineStr.length > 0) {
      const prefixedMatch = lineStr.match(LRC_A2_WORD_PREFIX_REGEX);
      if (prefixedMatch !== null) {
        const parsedWordTime = amllParseTime(prefixedMatch[1]);
        if (!Number.isNaN(parsedWordTime)) {
          lineItems.push(parsedWordTime);
        }
        lineStr = lineStr.slice(prefixedMatch[0].length);
        continue;
      }
      const nextIndex = lineStr.search(LRC_A2_WORD_TIME_REGEX);
      const text: string = nextIndex === -1 ? lineStr : lineStr.slice(0, nextIndex);
      lineItems.push(text);
      lineStr = lineStr.slice(text.length);
    }

    const words: AmllLyricWord[] = [];
    for (let i = 0; i < lineItems.length; i++) {
      const item = lineItems[i];
      if (typeof item === 'number') {
        continue;
      }
      const prevItem = i > 0 ? lineItems[i - 1] : undefined;
      const nextItem = i + 1 < lineItems.length ? lineItems[i + 1] : undefined;
      const realStart: number = typeof prevItem === 'number' ? prevItem : lineStartTime;
      const realEnd: number = typeof nextItem === 'number' ? nextItem : realStart;
      if (item.startsWith(' ') && words.length > 0 &&
        words[words.length - 1].word.trim().length > 0) {
        words.push(amllCreateWord({ word: ' ' }));
      }
      words.push(amllCreateWord({ word: item.trim(), startTime: realStart, endTime: realEnd }));
      if (item.endsWith(' ')) {
        words.push(amllCreateWord({ word: ' ' }));
      }
    }

    const lineEndTime: number = words.length > 0 ? words[words.length - 1].endTime : lineStartTime;
    lyricLines.push(
      amllCreateLine({
        startTime: lineStartTime,
        endTime: lineEndTime,
        words: words
      })
    );
  }
  return lyricLines;
}
// ==================== ESLyric ====================

const ESLRC_TIME_REGEX: RegExp = new RegExp('^\\[((?:\\d+:)*\\d+(?:\\.\\d+)?)\\]');

function parseTimestampPrefix(src: string): AmllTimestampPrefix | undefined {
  const match: RegExpMatchArray | null = src.match(ESLRC_TIME_REGEX);
  if (match === null) {
    return undefined;
  }
  const prefix: AmllTimestampPrefix = {
    time: amllParseTime(match[1]),
    length: match[0].length
  };
  return prefix;
}

function parseEslrcLine(rawLine: string): AmllLyricLine | undefined {
  let src = rawLine.trim();
  const first = parseTimestampPrefix(src);
  if (first === undefined) {
    return undefined;
  }
  src = src.slice(first.length);
  let startTime = first.time;
  if (src.trim().length === 0) {
    return undefined;
  }
  const words: AmllLyricWord[] = [];
  while (src.trim().length > 0) {
    const nextTimePos = src.indexOf('[');
    if (nextTimePos <= 0) {
      return undefined;
    }
    const word = src.slice(0, nextTimePos);
    const nextTime = parseTimestampPrefix(src.slice(nextTimePos));
    if (nextTime === undefined) {
      return undefined;
    }
    words.push(amllCreateWord({ word: word, startTime: startTime, endTime: nextTime.time }));
    src = src.slice(nextTimePos + nextTime.length);
    startTime = nextTime.time;
  }
  return amllCreateLine({ words: words });
}

/** 解析 ESLyric 逐词歌词格式字符串 */
export function amllParseEslrc(eslrc: string): AmllLyricLine[] {
  const result: AmllLyricLine[] = [];
  const rawLines: string[] = eslrc.split(/\r?\n/);
  for (let i = 0; i < rawLines.length; i++) {
    const line = parseEslrcLine(rawLines[i]);
    if (line !== undefined) {
      result.push(line);
    }
  }
  result.sort((a: AmllLyricLine, b: AmllLyricLine): number => {
    const at: number = a.words.length > 0 ? a.words[0].startTime : Number.MAX_SAFE_INTEGER;
    const bt: number = b.words.length > 0 ? b.words[0].startTime : Number.MAX_SAFE_INTEGER;
    return at - bt;
  });
  for (let i = 0; i < result.length; i++) {
    const line = result[i];
    for (let w = 0; w < line.words.length; w++) {
      line.words[w].startTime = amllClampTimestamp(line.words[w].startTime);
      line.words[w].endTime = amllClampTimestamp(line.words[w].endTime);
    }
    line.startTime = amllClampTimestamp(line.words.length > 0 ? line.words[0].startTime : 0);
    line.endTime = amllClampTimestamp(
      line.words.length > 0 ? line.words[line.words.length - 1].endTime : 0
    );
  }
  return result;
}
// ==================== YRC ====================

const YRC_WORD_PATTERN: RegExp = new RegExp(/^(.*?)\((\d+),(\d+),0\)/);
const YRC_LINE_PATTERN: RegExp = new RegExp(/^\[(\d+),(\d+)\]/);
const YRC_BEGIN_PAREN: RegExp = new RegExp(/^[（(]/);
const YRC_END_PAREN: RegExp = new RegExp(/[）)]$/);

function checkIsBG(words: AmllLyricWord[]): boolean {
  return (
    words.length > 0 &&
    YRC_BEGIN_PAREN.test(words[0].word) &&
    YRC_END_PAREN.test(words[words.length - 1].word)
  );
}

function trimBGParentheses(words: AmllLyricWord[]): void {
  words[0].word = words[0].word.slice(1);
  words[words.length - 1].word = words[words.length - 1].word.slice(0, -1);
}

/** 解析 YRC（网易云音乐逐词歌词）格式的歌词字符串 */
export function amllParseYrc(yrc: string): AmllLyricLine[] {
  const rawLines: string[] = yrc
    .split(/\r?\n/)
    .map((l: string) => l.trim())
    .filter((l: string) => l.length > 0);
  const result: AmllLyricLine[] = [];
  for (let li = 0; li < rawLines.length; li++) {
    const lineStr = rawLines[li];
    const lineMatch: RegExpMatchArray | null = lineStr.match(YRC_LINE_PATTERN);
    if (lineMatch === null) {
      continue;
    }
    const linePrefix: string = lineMatch[0];
    const lineStart: number = Number(lineMatch[1]);
    const lineDuration: number = Number(lineMatch[2]);

    const words: AmllLyricWord[] = [];
    let lineContent = lineStr.slice(linePrefix.length).trim();
    if (lineContent.length === 0) {
      continue;
    }

    let lastStart = -1;
    let lastEnd = -1;
    while (true) {
      const wordMatch: RegExpMatchArray | null = lineContent.match(YRC_WORD_PATTERN);
      if (wordMatch === null) {
        break;
      }
      const fullMatch: string = wordMatch[0];
      const lastText: string = wordMatch[1];
      const wordStart: number = Number(wordMatch[2]);
      const wordDur: number = Number(wordMatch[3]);
      const wordEnd: number = wordStart + wordDur;
      if (lastText.length > 0 && lastStart !== -1) {
        words.push(
          amllCreateWord({ word: lastText, startTime: lastStart, endTime: lastEnd })
        );
      }
      lastStart = wordStart;
      lastEnd = wordEnd;
      lineContent = lineContent.slice(fullMatch.length);
    }
    if (lastStart !== -1 && lineContent.length > 0) {
      words.push(
        amllCreateWord({ word: lineContent, startTime: lastStart, endTime: lastEnd })
      );
    }
    if (words.length === 0) {
      continue;
    }

    const isBG = checkIsBG(words);
    if (isBG) {
      trimBGParentheses(words);
    }
    result.push(
      amllCreateLine({
        startTime: lineStart,
        endTime: lineStart + lineDuration,
        words: words,
        isBG: isBG
      })
    );
  }
  return result;
}
// ==================== QRC ====================

const QRC_WORD_PATTERN: RegExp = new RegExp('(.*?)\\((\\d+),(\\d+)\\)', 'g');
const QRC_LINE_PATTERN: RegExp = new RegExp('^\\[(\\d+),(\\d+)\\]');

/** 解析 QRC（QQ 音乐逐词歌词）格式的歌词字符串 */
export function amllParseQrc(qrc: string): AmllLyricLine[] {
  const rawLines: string[] = qrc
    .split(/\r?\n/)
    .map((l: string) => l.trim())
    .filter((l: string) => l.length > 0);
  const result: AmllLyricLine[] = [];
  for (let li = 0; li < rawLines.length; li++) {
    const lineStr = rawLines[li];
    const lineMatch: RegExpMatchArray | null = lineStr.match(QRC_LINE_PATTERN);
    if (lineMatch === null) {
      continue;
    }
    const linePrefix: string = lineMatch[0];
    const lineStart: number = Number(lineMatch[1]);
    const lineDuration: number = Number(lineMatch[2]);
    const lineContent = lineStr.slice(linePrefix.length).trim();
    if (lineContent.length === 0) {
      continue;
    }

    const words: AmllLyricWord[] = [];
    QRC_WORD_PATTERN.lastIndex = 0;
    let wordMatch: RegExpExecArray | null = QRC_WORD_PATTERN.exec(lineContent);
    while (wordMatch !== null) {
      const wordText: string = wordMatch[1];
      const wordStart: number = Number(wordMatch[2]);
      const wordDur: number = Number(wordMatch[3]);
      words.push(
        amllCreateWord({
          word: wordText,
          startTime: wordStart,
          endTime: wordStart + wordDur
        })
      );
      wordMatch = QRC_WORD_PATTERN.exec(lineContent);
    }
    if (words.length === 0) {
      continue;
    }

    const isBG =
      /^[(（]/.test(words[0].word) && /[）)]$/.test(words[words.length - 1].word);
    if (isBG) {
      words[0].word = words[0].word.replace(/^[(（]/, '');
      words[words.length - 1].word = words[words.length - 1].word.replace(/[）)]$/, '');
    }

    result.push(
      amllCreateLine({
        startTime: lineStart,
        endTime: lineStart + lineDuration,
        words: words,
        isBG: isBG
      })
    );
  }
  return result;
}
// ==================== Lyricify Syllable (LYS) ====================

/** LYS 属性位解析结果 */
interface AmllLysProp {
  isDuet: boolean | undefined;
  isBG: boolean | undefined;
}

/** 解析 LYS 格式中的属性值 */
function parseLysProp(prop: number): AmllLysProp {
  if (prop < 0 || prop > 8) {
    prop = 0;
  }
  const result: AmllLysProp = {
    isDuet: prop % 3 === 0 ? undefined : prop % 3 === 2,
    isBG: prop <= 2 ? undefined : prop >= 6
  };
  return result;
}

/** 解析 Lyricify Syllable（LYS）格式的歌词字符串 */
export function amllParseLys(lys: string): AmllLyricLine[] {
  const rawLines: string[] = lys
    .split(/\r?\n/)
    .map((l: string) => l.trim())
    .filter((l: string) => l.length > 0);
  const lyricLines: AmllLyricLine[] = [];
  const propRegex: RegExp = new RegExp('^\\[(\\d+)\\]');
  const wordRegex: RegExp = new RegExp('(.*?)\\((\\d+),(\\d+)\\)', 'g');

  for (let li = 0; li < rawLines.length; li++) {
    const lineStr = rawLines[li];
    const propMatch: RegExpMatchArray | null = lineStr.match(propRegex);
    if (propMatch === null) {
      continue;
    }
    const content = lineStr.slice(propMatch[0].length);
    const words: AmllLyricWord[] = [];
    const props = parseLysProp(Number(propMatch[1]));

    wordRegex.lastIndex = 0;
    let wordMatch: RegExpExecArray | null = wordRegex.exec(content);
    while (wordMatch !== null) {
      const rawWord: string = wordMatch[1];
      const startTime: number = Number(wordMatch[2]);
      const duration: number = Number(wordMatch[3]);
      const endTime: number = startTime + duration;
      words.push(amllCreateWord({ word: rawWord, startTime: startTime, endTime: endTime }));
      wordMatch = wordRegex.exec(content);
    }
    if (words.length === 0) {
      continue;
    }

    const lineStartTime: number = words[0].startTime;
    const lineEndTime: number = words[words.length - 1].endTime;

    let isBG: boolean | undefined = props.isBG;
    if (isBG === undefined) {
      isBG = /^[(（]/.test(words[0].word) && /[）)]$/.test(words[words.length - 1].word);
    }
    if (isBG) {
      words[0].word = words[0].word.replace(/^[(（]/, '');
      words[words.length - 1].word = words[words.length - 1].word.replace(/[）)]$/, '');
    }

    lyricLines.push(
      amllCreateLine({
        startTime: lineStartTime,
        endTime: lineEndTime,
        isDuet: props.isDuet === true,
        isBG: isBG,
        words: words
      })
    );
  }
  return lyricLines;
}
// ==================== Lyricify Lines (LYL) ====================

const LYL_TIME_REGEX: RegExp = new RegExp('^\\[(\\d+),(\\d+)\\](.*)$');
const LYL_BG_REGEX: RegExp = new RegExp('^[(（](.+)[)）]$');

/** 解析 LYL（Lyricify Lines）格式的歌词字符串 */
export function amllParseLyl(lyl: string): AmllLyricLine[] {
  const rawLines: string[] = lyl
    .split(/\r?\n/)
    .map((l: string) => l.trim())
    .filter((l: string) => l.length > 0);
  const lyricLines: AmllLyricLine[] = [];
  for (let li = 0; li < rawLines.length; li++) {
    const lineStr = rawLines[li];
    if (lineStr === '[type:LyricifyLines]') {
      continue;
    }
    const timeMatch: RegExpMatchArray | null = lineStr.match(LYL_TIME_REGEX);
    if (timeMatch === null) {
      continue;
    }
    const startTime: number = Number(timeMatch[1]);
    const endTime: number = Number(timeMatch[2]);
    const text: string = timeMatch[3];
    const backgroundMatch: RegExpMatchArray | null = text.match(LYL_BG_REGEX);
    const isBG = backgroundMatch !== null;
    const textContent: string = (backgroundMatch !== null ? backgroundMatch[1] : text).trim();
    if (textContent.length === 0) {
      continue;
    }
    const word: AmllLyricWord = amllCreateWord({
      word: textContent,
      startTime: startTime,
      endTime: endTime
    });
    lyricLines.push(
      amllCreateLine({
        startTime: startTime,
        endTime: endTime,
        isBG: isBG,
        words: [word]
      })
    );
  }
  return lyricLines;
}
// ==================== Lyricify Quick Export (LQE) ====================

type AttrType = 'translatedLyric' | 'romanLyric';

interface LqeHeaderMatch {
  index: number;
  type: 'lyric' | 'translation' | 'romanization' | 'unknown';
}

function parseLqeAttr(
  attr: AttrType,
  headerMatches: LqeHeaderMatch[],
  rawLines: string[],
  lines: AmllLyricLine[]
): void {
  let headerIndex = -1;
  for (let i = 0; i < headerMatches.length; i++) {
    if (attr === 'translatedLyric' && headerMatches[i].type === 'translation') {
      headerIndex = i;
      break;
    }
    if (attr === 'romanLyric' && headerMatches[i].type === 'romanization') {
      headerIndex = i;
      break;
    }
  }
  if (headerIndex === -1) {
    return;
  }
  const timeRegex: RegExp = new RegExp('^\\[((?:\\d+:)*\\d+(?:\\.\\d+)?)\\](.*)$');
  const attrLines: AmllAttrLine[] = [];
  const startIdx = headerMatches[headerIndex].index + 1;
  const endIdx = headerMatches[headerIndex + 1].index;
  for (let i = startIdx; i < endIdx && i < rawLines.length; i++) {
    const line = rawLines[i].trim();
    if (line.length === 0) {
      continue;
    }
    const match: RegExpMatchArray | null = line.match(timeRegex);
    if (match === null) {
      continue;
    }
    const time = amllParseTime(match[1]);
    if (Number.isNaN(time)) {
      continue;
    }
    const attrLine: AmllAttrLine = { time: time, text: match[2] };
    attrLines.push(attrLine);
  }

  let attrLineIndex = 0;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (attrLineIndex >= attrLines.length) {
      break;
    }
    if (attrLines[attrLineIndex].time !== line.startTime) {
      continue;
    }
    if (attr === 'translatedLyric') {
      line.translatedLyric = attrLines[attrLineIndex].text;
    } else {
      line.romanLyric = attrLines[attrLineIndex].text;
    }
    attrLineIndex++;
  }
}

/** 解析 LQE（Lyricify Quick Export）格式的歌词字符串 */
export function amllParseLqe(lqe: string): AmllLyricLine[] {
  const rawLines: string[] = lqe
    .split(/\r?\n/)
    .map((line: string) => line.trim())
    .filter((line: string) => line.length > 0);

  const headerRegex: RegExp = new RegExp('^\\[([a-zA-Z]+):.+\\]$');
  const headerMatches: LqeHeaderMatch[] = [];
  for (let i = 0; i < rawLines.length; i++) {
    const match: RegExpMatchArray | null = rawLines[i].match(headerRegex);
    if (match === null) {
      continue;
    }
    const type: string = match[1];
    if (type === 'lyrics') {
      headerMatches.push({ index: i, type: 'lyric' });
    } else if (type === 'translation') {
      headerMatches.push({ index: i, type: 'translation' });
    } else if (type === 'pronunciation') {
      headerMatches.push({ index: i, type: 'romanization' });
    } else {
      headerMatches.push({ index: i, type: 'unknown' });
    }
  }
  headerMatches.push({ index: rawLines.length, type: 'unknown' });

  let lyricHeaderIndex = -1;
  for (let i = 0; i < headerMatches.length; i++) {
    if (headerMatches[i].type === 'lyric') {
      lyricHeaderIndex = i;
      break;
    }
  }
  if (lyricHeaderIndex === -1) {
    return [];
  }
  const lyricLines = rawLines.slice(
    headerMatches[lyricHeaderIndex].index + 1,
    headerMatches[lyricHeaderIndex + 1].index
  );
  const parsedLines: AmllLyricLine[] = amllParseLys(lyricLines.join('\n'));
  parseLqeAttr('translatedLyric', headerMatches, rawLines, parsedLines);
  parseLqeAttr('romanLyric', headerMatches, rawLines, parsedLines);
  return parsedLines;
}
// ==================== 酷我 lrcx（逐字） ====================

/** lrcx 词段 */
interface AmllLrcxWord {
  a: number;
  b: number;
  text: string;
}

const LRCX_LINE_REGEX: RegExp = new RegExp('^\\[(\\d{2}):(\\d{2})\\.(\\d{3})\\](.*)$');
const LRCX_WORD_REGEX: RegExp = new RegExp('<(-?\\d+),(-?\\d+)>([^<]*)', 'g');
const LRCX_KUWO_TAG_REGEX: RegExp = new RegExp('\\[kuwo:(\\d+)\\]');
const LRCX_CJK_REGEX: RegExp = new RegExp('[\\u4e00-\\u9fa5]');
const LRCX_META_REGEX: RegExp = new RegExp('^\\[(ml|ver|ti|ar|al|by|offset):');

/**
 * 解析酷我 lrcx 逐字歌词：
 * [kuwo:137] 八进制偏移 -> offset=trunc(oct/10), offset2=oct%10
 * 词起始 = 行起始 + |(a+b)/(offset*2)|，词时长 = |(a-b)/(offset2*2)|
 * 全部 `<0,0>` 且含中文的行 = 翻译行，配对到上一主行的 translatedLyric
 */
export function amllParseKwLrcx(text: string): AmllLyricLine[] {
  const rawLines: string[] = text.replace(/\r\n/g, '\n').split('\n');
  // 解析 [kuwo:NNN]（八进制）
  let kuwoOffset = 1;
  let kuwoOffset2 = 1;
  const kuwoTag: RegExpMatchArray | null = text.match(LRCX_KUWO_TAG_REGEX);
  if (kuwoTag !== null) {
    const kuwoValue = Number.parseInt(kuwoTag[1], 8);
    if (!Number.isNaN(kuwoValue)) {
      const off = Math.trunc(kuwoValue / 10);
      const off2 = kuwoValue % 10;
      if (off > 0 && off2 > 0) {
        kuwoOffset = off;
        kuwoOffset2 = off2;
      }
    }
  }

  const result: AmllLyricLine[] = [];
  let lastMainLine: AmllLyricLine | undefined = undefined;

  for (let li = 0; li < rawLines.length; li++) {
    const lineStr = rawLines[li].trim();
    if (lineStr.length === 0 || LRCX_META_REGEX.test(lineStr) || LRCX_KUWO_TAG_REGEX.test(lineStr)) {
      continue;
    }
    const lineMatch: RegExpMatchArray | null = lineStr.match(LRCX_LINE_REGEX);
    if (lineMatch === null) {
      continue;
    }
    const lineStart: number =
      Number.parseInt(lineMatch[1]) * 60000 +
      Number.parseInt(lineMatch[2]) * 1000 +
      Number.parseInt(lineMatch[3]);
    const content: string = lineMatch[4];

    // 解析词段
    const words: AmllLrcxWord[] = [];
    LRCX_WORD_REGEX.lastIndex = 0;
    let wm: RegExpExecArray | null = LRCX_WORD_REGEX.exec(content);
    while (wm !== null) {
      const word: AmllLrcxWord = {
        a: Number.parseInt(wm[1]),
        b: Number.parseInt(wm[2]),
        text: wm[3]
      };
      words.push(word);
      wm = LRCX_WORD_REGEX.exec(content);
    }
    if (words.length === 0) {
      continue;
    }

    // 判断是否翻译行：全部 <0,0> 且含 CJK
    let allZero = true;
    let hasCjk = false;
    for (let w = 0; w < words.length; w++) {
      if (words[w].a !== 0 || words[w].b !== 0) {
        allZero = false;
      }
      if (LRCX_CJK_REGEX.test(words[w].text)) {
        hasCjk = true;
      }
    }
    const isTranslation = allZero && hasCjk;

    if (isTranslation) {
      // 配对到上一主行
      let transText = '';
      for (let w = 0; w < words.length; w++) {
        transText += words[w].text;
      }
      transText = transText.trim();
      if (transText.length > 0 && lastMainLine !== undefined) {
        lastMainLine.translatedLyric = transText;
      }
      continue;
    }

    // 纯空白行（如 <0,0> <0,0>）跳过
    let hasRealText = false;
    for (let w = 0; w < words.length; w++) {
      if (words[w].text.trim().length > 0) {
        hasRealText = true;
        break;
      }
    }
    if (!hasRealText) {
      continue;
    }

    // 主行：词级时间戳
    const lyricWords: AmllLyricWord[] = [];
    let lineEnd = lineStart;
    for (let w = 0; w < words.length; w++) {
      const seg = words[w];
      if (seg.text.trim().length === 0) {
        lyricWords.push(amllCreateWord({ word: seg.text, startTime: lineStart, endTime: lineStart }));
        continue;
      }
      const wordStart: number = lineStart + Math.abs((seg.a + seg.b) / (kuwoOffset * 2));
      const wordDuration: number = Math.abs((seg.a - seg.b) / (kuwoOffset2 * 2));
      const wordEnd: number = wordStart + wordDuration;
      lyricWords.push(amllCreateWord({ word: seg.text, startTime: wordStart, endTime: wordEnd }));
      if (wordEnd > lineEnd) {
        lineEnd = wordEnd;
      }
    }
    const line: AmllLyricLine = amllCreateLine({
      startTime: lineStart,
      endTime: lineEnd,
      words: lyricWords
    });
    result.push(line);
    lastMainLine = line;
  }
  return result;
}

// ==================== ASS 导出 ====================
// ==================== KRC ====================

/** KRC [language:] 标签内解析出的翻译/音译内容（按主歌词行索引对应） */
interface AmllKrcLanguage {
  translation: string[];
  transliteration: string[][];
}

/**
 * 解析 KRC 的 [language:...] 标签（base64 JSON）：
 * content 数组内 type==1 为翻译歌词、type==0 为音译（逐字 token），均按主歌词行索引一一对应。
 * 解析失败返回 undefined。
 */
function amllParseKrcLanguage(lyricText: string): AmllKrcLanguage | undefined {
  const langRe: RegExp = new RegExp('^\\[language:([^\\]]*)\\]', 'm');
  const langMatch: RegExpMatchArray | null = lyricText.match(langRe);
  if (langMatch === null || langMatch.length < 2) {
    return undefined;
  }
  try {
    const base64Helper: util.Base64Helper = new util.Base64Helper();
    const raw: Uint8Array = base64Helper.decodeSync(langMatch[1]);
    const textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    const jsonStr: string = textDecoder.decodeToString(raw);
    const root: Record<string, Object> = JSON.parse(jsonStr) as Record<string, Object>;
    const content: Object[] = root['content'] as Object[] || [];
    const translation: string[] = [];
    const transliteration: string[][] = [];
    for (let i = 0; i < content.length; i++) {
      const item: Record<string, Object> = content[i] as Record<string, Object>;
      const type: number = item['type'] as number;
      const lyricContent: Object[] = item['lyricContent'] as Object[] || [];
      if (type === 1) {
        // 翻译：每行一个数组，取首元素作为该行翻译文本
        for (let r = 0; r < lyricContent.length; r++) {
          const row: Object[] = lyricContent[r] as Object[] || [];
          translation.push(row.length > 0 ? String(row[0]) : '');
        }
      } else if (type === 0) {
        // 音译：每行是逐字 token 数组
        for (let r = 0; r < lyricContent.length; r++) {
          const row: Object[] = lyricContent[r] as Object[] || [];
          const tokens: string[] = [];
          for (let t = 0; t < row.length; t++) {
            tokens.push(String(row[t]));
          }
          transliteration.push(tokens);
        }
      }
    }
    if (translation.length === 0 && transliteration.length === 0) {
      return undefined;
    }
    return { translation: translation, transliteration: transliteration };
  } catch (_err) {
    return undefined;
  }
}

/**
 * 解析 KRC（酷狗逐词歌词）格式的歌词字符串。
 * 同时解析 [language:] 标签中的翻译（type==1）与音译（type==0）：
 * 按主歌词行索引一一对应，附加到行的 translatedLyric / romanLyric / romanWords。
 */
export function amllParseKrc(lyricText: string): AmllLyricLine[] {
  const lang = amllParseKrcLanguage(lyricText);
  const rawLines: string[] = lyricText.split('\n');
  const lyricLines: AmllLyricLine[] = [];
  const krcLineRegex: RegExp = new RegExp('\\[(\\d+),(\\d+)\\](.*)');
  const krcWordRegex: RegExp = new RegExp('<\\d+,\\d+,\\d+>', 'g');

  for (let li = 0; li < rawLines.length; li++) {
    const line = rawLines[li];
    const lineMatch: RegExpMatchArray | null = line.match(krcLineRegex);
    if (lineMatch === null) {
      continue;
    }
    const lineStart: number = Number(lineMatch[1]);
    const lineDuration: number = Number(lineMatch[2]);
    const content: string = lineMatch[3];

    // 解析歌词文本（去时间标签）
    const wordSpans: AmllKrcSpan[] = [];
    const spanRegex: RegExp = new RegExp('<\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*\\d+\\s*>([^<]*)', 'g');
    spanRegex.lastIndex = 0;
    let spanMatch: RegExpExecArray | null = spanRegex.exec(content);
    const plainText = content.replace(krcWordRegex, '');
    while (spanMatch !== null) {
      const span: AmllKrcSpan = {
        start: Number(spanMatch[1]),
        dur: Number(spanMatch[2]),
        text: spanMatch[3]
      };
      wordSpans.push(span);
      spanMatch = spanRegex.exec(content);
    }
    let parsedLine: AmllLyricLine;
    if (wordSpans.length === 0) {
      const word: AmllLyricWord = amllCreateWord({
        word: plainText,
        startTime: lineStart,
        endTime: lineStart + lineDuration
      });
      parsedLine = amllCreateLine({
        startTime: lineStart,
        endTime: lineStart + lineDuration,
        words: [word]
      });
    } else {
      const words: AmllLyricWord[] = [];
      for (let w = 0; w < wordSpans.length; w++) {
        const span = wordSpans[w];
        words.push(
          amllCreateWord({
            word: span.text,
            startTime: lineStart + span.start,
            endTime: lineStart + span.start + span.dur
          })
        );
      }
      parsedLine = amllCreateLine({
        startTime: lineStart,
        endTime: lineStart + lineDuration,
        words: words
      });
    }
    // 附加翻译/音译（按主歌词行索引一一对应）
    if (lang !== undefined) {
      const lineIndex: number = lyricLines.length;
      if (lineIndex < lang.translation.length && lang.translation[lineIndex].length > 0) {
        parsedLine.translatedLyric = lang.translation[lineIndex];
      }
      if (lineIndex < lang.transliteration.length && lang.transliteration[lineIndex].length > 0) {
        const tokens: string[] = lang.transliteration[lineIndex];
        let romanText = '';
        for (let t = 0; t < tokens.length; t++) {
          romanText += tokens[t];
        }
        parsedLine.romanLyric = romanText.trim();
        // 逐字时间：音译 token 与主行字一一对应时，直接借用主行字的时间戳。
        // 注意：token 自带尾随空格（词间分隔），须原样保留以维持词间距；空格 token 也保留。
        const mainWords: AmllLyricWord[] = parsedLine.words;
        if (tokens.length === mainWords.length) {
          const romanWords: AmllLyricWord[] = [];
          for (let t = 0; t < tokens.length; t++) {
            if (tokens[t].length === 0) {
              continue;
            }
            romanWords.push(
              amllCreateWord({
                word: tokens[t],
                startTime: mainWords[t].startTime,
                endTime: mainWords[t].endTime
              })
            );
          }
          parsedLine.romanWords = romanWords;
        }
      }
    }
    lyricLines.push(parsedLine);
  }
  lyricLines.sort((a: AmllLyricLine, b: AmllLyricLine): number => a.startTime - b.startTime);
  return lyricLines;
}














