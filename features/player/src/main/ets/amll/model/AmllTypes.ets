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
 * AMLL (applemusic-like-lyrics) 数据结构在 ArkTS 中的忠实移植。
 *
 * 对应原仓库 packages/core/src/interfaces.ts 与 packages/lyric/src/types.ts、
 * packages/ttml/src/types 中的核心数据结构。
 */

/** 一个歌词单词（含注音等扩展信息） */
export interface AmllLyricWord {
  /** 单词的起始时间，单位为毫秒 */
  startTime: number;
  /** 单词的结束时间，单位为毫秒 */
  endTime: number;
  /** 单词内容 */
  word: string;
  /** 单词的音译内容 */
  romanWord?: string;
  /** 单词内容是否包含冒犯性的不雅用语 */
  obscene?: boolean;
  /** 单词的注音内容 */
  ruby?: AmllRubyTag[];
}

/** 注音音节（Ruby） */
export interface AmllRubyTag {
  startTime: number;
  endTime: number;
  word: string;
}

/** 一行歌词，存储多个单词 */
export interface AmllLyricLine {
  /** 该行的所有单词；逐行格式只有一个单词且其始末时间通常与行的 startTime/endTime 相同 */
  words: AmllLyricWord[];
  /** 该行的翻译歌词，显示在主歌词行下方 */
  translatedLyric: string;
  /** 该行的音译歌词，显示在翻译歌词行下方 */
  romanLyric: string;
  /** 音译歌词的逐字时间戳（带字级 startTime/endTime，用于逐字高亮） */
  romanWords?: AmllLyricWord[];
  /** 句子的起始时间，单位为毫秒 */
  startTime: number;
  /** 句子的结束时间，单位为毫秒 */
  endTime: number;
  /** 是否为背景歌词行 */
  isBG: boolean;
  /** 是否为对唱歌词行（歌词行靠右对齐） */
  isDuet: boolean;
}

/** 优化歌词行的配置选项 */
export interface AmllOptimizeLyricOptions {
  /** 规范化歌词中的空格，将多个连续空格替换为一个空格，默认 true */
  normalizeSpaces?: boolean;
  /** 是否将行级时间戳强行设为字级时间戳，默认 true */
  resetLineTimestamps?: boolean;
  /** 把多行背景人声转换为单行背景人声 + 主歌词行的形式，默认 true */
  convertExcessiveBackgroundLines?: boolean;
  /** 是否同步主歌词与背景人声的时间，默认 true */
  syncMainAndBackgroundLines?: boolean;
  /** 清洗非刻意的重叠，默认 true */
  cleanUnintentionalOverlaps?: boolean;
  /** 尝试让歌词提前最多 1 秒开始，默认 true */
  tryAdvanceStartTime?: boolean;
}

/** 翻译/音译的内容（TTML） */
export interface AmllSubLyricContent {
  /** BCP-47 语言代码 */
  language?: string;
  /** 完整文本 */
  text: string;
  /** 逐字音节信息 */
  words?: AmllSyllable[];
}

/** 背景人声内容（TTML） */
export interface AmllBackgroundVocal extends AmllLyricBase {
}

/** 基础歌词内容（TTML） */
export interface AmllLyricBase {
  text: string;
  startTime: number;
  endTime: number;
  words?: AmllSyllable[];
  translations?: AmllSubLyricContent[];
  romanizations?: AmllSubLyricContent[];
  backgroundVocal?: AmllBackgroundVocal;
}

/** TTML 解析出的歌词行 */
export interface AmllTtmlLine extends AmllLyricBase {
  id?: string;
  agentId?: string;
  songPart?: string;
  blockIndex?: number;
}

/** 一个歌词音节（TTML） */
export interface AmllSyllable {
  text: string;
  startTime: number;
  endTime: number;
  endsWithSpace?: boolean;
  ruby?: AmllRubyTag[];
  obscene?: boolean;
  emptyBeat?: number;
}

/** 演唱者信息（TTML） */
export interface AmllAgent {
  id: string;
  name?: string;
  type?: string;
}

/** TTML 元数据 */
export interface AmllTtmlMetadata {
  language?: string;
  timingMode?: string;
  songwriters?: string[];
  title?: string[];
  artist?: string[];
  album?: string[];
  isrc?: string[];
  authorIds?: string[];
  authorNames?: string[];
  agents?: Map<string, AmllAgent>;
  platformIds?: Map<string, string[]>;
  rawProperties?: Map<string, string[]>;
}

/** TTML 解析结果 */
export interface AmllTtmlResult {
  metadata: AmllTtmlMetadata;
  lines: AmllTtmlLine[];
}

/** TTML 歌词对象（含元数据表） */
export interface AmllTTMLLyric {
  lines: AmllLyricLine[];
  metadata: [string, string[]][];
}

/** 歌词解析结果 */
export interface AmllParsedLyric {
  /** 转换后的 AMLL 歌词行 */
  lines: AmllLyricLine[];
  /** 原始歌词字符串 */
  rawText: string;
}

/** 歌词格式类型 */
export enum AmllLyricFormat {
  LRC = 0,
  LRC_A2 = 1,
  ESLRC = 2,
  YRC = 3,
  QRC = 4,
  LYS = 5,
  LYL = 6,
  LQE = 7,
  TTML = 8,
  KRC = 9,
  KWLRX = 10
}
