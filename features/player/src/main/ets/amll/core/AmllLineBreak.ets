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
 * 歌词换行平衡与单词分组（对应原仓库 packages/core/src/utils/lyric-line-break.ts 与 lyric-split-words.ts）
 */
import { AmllLyricWord } from '../model/AmllTypes';
import { amllIsCJK } from '../model/AmllMath';

/** 子节点信息 */
export interface AmllChildNodeInfo {
  width: number;
  text: string;
  isSpace: boolean;
}

/** 单个词超过容器宽度时的大惩罚倍数 */
const OVERFLOW_PENALTY_MULTIPLIER = 1000;
/** 截断 CJK 词组边界的惩罚比例 */
const CJK_BREAK_PENALTY_RATIO = 0.15;
/** 截断普通文本的惩罚比例 */
const NORMAL_BREAK_PENALTY_RATIO = 0.5;
/** 在空格处断开的奖励比例 */
const SPACE_BREAK_REWARD_RATIO = 0.4;
/** 在标点符号处断开的奖励比例 */
const PUNCTUATION_BREAK_REWARD_RATIO = 0.6;
const PUNCTUATION_REGEX: RegExp = new RegExp('[,.;:!?，。；：！？、）】》」』’”)\\]}>~…]$');

interface AmllSegmentEntry {
  segment: string;
  isWordLike: boolean;
}

/** 简易分词（模拟 Intl.Segmenter word 粒度） */
function segmentWords(fullText: string): AmllSegmentEntry[] {
  const result: AmllSegmentEntry[] = [];
  let current = '';
  let currentIsWord = false;
  const flush = (): void => {
    if (current.length > 0) {
      result.push({ segment: current, isWordLike: currentIsWord });
      current = '';
    }
  };
  for (let i = 0; i < fullText.length; i++) {
    const ch = fullText.charAt(i);
    const isLetter: boolean = /[A-Za-z0-9\u00C0-\u024F\u0400-\u04FF\u3040-\u30FF\uAC00-\uD7AF]/.test(ch);
    const isCJKChar: boolean = /[\u4E00-\u9FFF\u3400-\u4DBF]/.test(ch);
    const isSpace: boolean = /\s/.test(ch);
    const isWordLike: boolean = isLetter || isCJKChar;
    if (current.length === 0) {
      current = ch;
      currentIsWord = isWordLike;
    } else if (!isSpace && currentIsWord === isWordLike) {
      current += ch;
    } else if (isSpace) {
      flush();
      current = ch;
      currentIsWord = false;
    } else {
      flush();
      current = ch;
      currentIsWord = isWordLike;
    }
  }
  flush();
  return result;
}

/**
 * 计算平均行长度的断点位置（对应原仓库 calcBalancedBreaks）
 * @returns 需要在其前面插入换行的子节点索引数组，升序
 */
export function amllCalcBalancedBreaks(
  children: AmllChildNodeInfo[],
  containerWidth: number,
  fullText: string
): number[] {
  const n = children.length;
  if (n === 0 || containerWidth <= 0) {
    return [];
  }

  const cjkBoundaries = new Set<number>();
  let offset = 0;
  const segments = segmentWords(fullText);
  for (let s = 0; s < segments.length; s++) {
    const seg = segments[s];
    if (offset > 0 && seg.isWordLike) {
      let hasCJK = false;
      const chars = seg.segment.split('');
      for (let c = 0; c < chars.length; c++) {
        if (amllIsCJK(chars[c])) {
          hasCJK = true;
          break;
        }
      }
      if (hasCJK) {
        cjkBoundaries.add(offset);
      }
    }
    offset += seg.segment.length;
  }

  const charOffsets = new Int32Array(n + 1);
  const prefixWidth = new Float64Array(n + 1);
  for (let i = 0; i < n; i++) {
    charOffsets[i + 1] = charOffsets[i] + children[i].text.length;
    prefixWidth[i + 1] = prefixWidth[i] + children[i].width;
  }

  if (prefixWidth[n] <= containerWidth) {
    return [];
  }

  const dp = new Float64Array(n + 1);
  dp.fill(Number.POSITIVE_INFINITY);
  const nextBreak = new Int32Array(n + 1);
  nextBreak.fill(-1);
  dp[n] = 0;

  const PENALTY_CJK = (containerWidth * CJK_BREAK_PENALTY_RATIO) ** 2;
  const PENALTY_NORMAL = (containerWidth * NORMAL_BREAK_PENALTY_RATIO) ** 2;
  const PUNCT_REWARD = (containerWidth * PUNCTUATION_BREAK_REWARD_RATIO) ** 2;
  const SPACE_REWARD = (containerWidth * SPACE_BREAK_REWARD_RATIO) ** 2;

  for (let i = n - 1; i >= 0; i--) {
    for (let j = i + 1; j <= n; j++) {
      const w = prefixWidth[j] - prefixWidth[i];
      let lineCost = 0;
      if (w > containerWidth) {
        if (j === i + 1) {
          lineCost = (w - containerWidth) ** 2 * OVERFLOW_PENALTY_MULTIPLIER;
        } else {
          continue;
        }
      } else {
        lineCost = (containerWidth - w) ** 2;
      }

      let breakPenalty = 0;
      if (j < n) {
        const prevChild = children[j - 1];
        if (PUNCTUATION_REGEX.test(prevChild.text)) {
          breakPenalty = -PUNCT_REWARD;
        } else if (prevChild.isSpace) {
          breakPenalty = -SPACE_REWARD;
        } else if (cjkBoundaries.has(charOffsets[j])) {
          breakPenalty = PENALTY_CJK;
        } else {
          breakPenalty = PENALTY_NORMAL;
        }
      }

      const totalCost = lineCost + breakPenalty + dp[j];
      if (totalCost < dp[i]) {
        dp[i] = totalCost;
        nextBreak[i] = j;
      }
    }
  }

  const breaks: number[] = [];
  let curr = 0;
  while (curr < n) {
    curr = nextBreak[curr];
    if (curr > 0 && curr < n) {
      breaks.push(curr);
    }
  }
  return breaks;
}

const SPLIT_WHITESPACE_RE: RegExp = new RegExp('(\\s+)');
const WHITESPACE_RE: RegExp = new RegExp('\\s', 'g');

/**
 * 将输入的单词重新分组，之间没有空格的单词将会组合成一个单词数组
 * （对应原仓库 chunkAndSplitLyricWords）
 */
export function amllChunkAndSplitLyricWords(
  words: AmllLyricWord[]
): (AmllLyricWord | AmllLyricWord[])[] {
  const result: (AmllLyricWord | AmllLyricWord[])[] = [];
  let currentGroup: AmllLyricWord[] = [];

  const flushGroup = (): void => {
    if (currentGroup.length > 0) {
      if (currentGroup.length === 1) {
        result.push(currentGroup[0]);
      } else {
        result.push([...currentGroup]);
      }
      currentGroup = [];
    }
  };

  const processAtom = (atom: AmllLyricWord): void => {
    const isSpace = atom.word.trim().length === 0;
    const hasRuby = atom.ruby !== undefined && atom.ruby.length > 0;
    const isCJKChar = amllIsCJK(atom.word);
    const isMergeable = !isSpace && !hasRuby && !isCJKChar;
    if (isMergeable) {
      currentGroup.push(atom);
    } else {
      flushGroup();
      result.push(atom);
    }
  };

  for (let wi = 0; wi < words.length; wi++) {
    const w = words[wi];
    const content = w.word.trim();
    const isSpace = content.length === 0;
    const romanWord: string = w.romanWord !== undefined ? w.romanWord : '';
    const obscene: boolean = w.obscene !== undefined ? w.obscene : false;
    const hasRuby = w.ruby !== undefined && w.ruby.length > 0;

    if (isSpace) {
      const atom: AmllLyricWord = {
        word: w.word,
        romanWord: romanWord,
        startTime: w.startTime,
        endTime: w.endTime,
        obscene: obscene
      };
      processAtom(atom);
      continue;
    }

    if (hasRuby) {
      const leadingSpaceMatch: RegExpMatchArray | null = w.word.match(/^\s+/);
      const trailingSpaceMatch: RegExpMatchArray | null = w.word.match(/\s+$/);
      const leadingSpace: string = leadingSpaceMatch !== null ? leadingSpaceMatch[0] : '';
      const trailingSpace: string = trailingSpaceMatch !== null ? trailingSpaceMatch[0] : '';
      if (leadingSpace.length > 0) {
        const atom: AmllLyricWord = {
          word: leadingSpace,
          romanWord: '',
          startTime: w.startTime,
          endTime: w.startTime,
          obscene: obscene
        };
        processAtom(atom);
      }
      const mainAtom: AmllLyricWord = {
        word: content,
        romanWord: romanWord,
        startTime: w.startTime,
        endTime: w.endTime,
        obscene: obscene,
        ruby: w.ruby
      };
      processAtom(mainAtom);
      if (trailingSpace.length > 0) {
        const atom: AmllLyricWord = {
          word: trailingSpace,
          romanWord: '',
          startTime: w.endTime,
          endTime: w.endTime,
          obscene: obscene
        };
        processAtom(atom);
      }
      continue;
    }

    const parts: string[] = w.word.split(SPLIT_WHITESPACE_RE).filter((p: string) => p.length > 0);
    const totalLength: number = w.word.replace(WHITESPACE_RE, '').length || 1;
    const timeSpan: number = w.endTime - w.startTime;
    const timePerUnit: number = timeSpan / totalLength;

    const wordParts: string[] = w.word.trim().split(/\s+/).filter((p: string) => p.length > 0);
    const romanTrimmed: string = romanWord.trim();
    const romanParts: string[] =
      romanTrimmed.length > 0 ? romanTrimmed.split(/\s+/).filter((p: string) => p.length > 0) : [];
    const isMatched: boolean = wordParts.length > 0 && wordParts.length === romanParts.length;

    let currentOffset = 0;
    let nonSpaceIndex = 0;

    for (let p = 0; p < parts.length; p++) {
      const part = parts[p];
      if (part.trim().length === 0) {
        const startTime = w.startTime + currentOffset * timePerUnit;
        const atom: AmllLyricWord = {
          word: part,
          romanWord: '',
          startTime: startTime,
          endTime: startTime,
          obscene: obscene
        };
        processAtom(atom);
        continue;
      }

      let partRomanWord = '';
      if (romanParts.length > 0) {
        if (isMatched) {
          partRomanWord = nonSpaceIndex < romanParts.length ? romanParts[nonSpaceIndex] : '';
        } else if (nonSpaceIndex === 0) {
          partRomanWord = romanWord;
        }
      }
      nonSpaceIndex++;

      if (amllIsCJK(part) && part.length > 1 && romanTrimmed.length === 0) {
        const chars: string[] = part.split('');
        for (let c = 0; c < chars.length; c++) {
          const startTime = w.startTime + currentOffset * timePerUnit;
          const atom: AmllLyricWord = {
            word: chars[c],
            romanWord: '',
            startTime: startTime,
            endTime: startTime + timePerUnit,
            obscene: obscene
          };
          processAtom(atom);
          currentOffset += 1;
        }
      } else {
        const partRealLen = part.length;
        const startTime = w.startTime + currentOffset * timePerUnit;
        const duration = partRealLen * timePerUnit;
        const atom: AmllLyricWord = {
          word: part,
          romanWord: partRomanWord,
          startTime: startTime,
          endTime: startTime + duration,
          obscene: obscene
        };
        processAtom(atom);
        currentOffset += partRealLen;
      }
    }
  }

  flushGroup();
  return result;
}
