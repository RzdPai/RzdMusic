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
 * 歌词解析自测工具：解析任意歌词文本并输出统计与时间戳校验结果。
 * 用于验证不同平台（网易/QQ/酷狗/酷我/咪咕/TTML）歌词的解析正确性。
 */
import { AmllLyricFormat, AmllLyricLine } from '../model/AmllTypes';
import { amllDetectLyricFormat, amllParseLyricText } from '../parse/AmllAutoDetect';

/** 探测结果 */
export interface AmllProbeResult {
  /** 识别出的格式名 */
  format: string;
  /** 原始文本长度 */
  rawLen: number;
  /** 解析出的歌词行数 */
  lineCount: number;
  /** 词级时间戳行数（逐字歌词行） */
  dynamicLineCount: number;
  /** 单词总数 */
  wordCount: number;
  /** 首个时间戳 */
  firstStart: number;
  firstEnd: number;
  /** 末个时间戳 */
  lastStart: number;
  lastEnd: number;
  /** 时间戳校验问题列表（空 = 通过） */
  issues: string[];
  /** 前几行抽样 */
  samples: string[];
  /** 原文预览（前 200 字符） */
  rawPreview: string;
  /** 是否通过校验 */
  pass: boolean;
}

function fmtTime(ms: number): string {
  const min = Math.floor(ms / 60000);
  const sec = Math.floor((ms % 60000) / 1000);
  const msPart = Math.round(ms % 1000);
  return `${min}:${String(sec).padStart(2, '0')}.${String(msPart).padStart(3, '0')}`;
}

/**
 * 解析歌词文本并生成统计/校验结果。
 * @param text 歌词文本
 * @param title 描述（用于日志）
 * @param expectFormat 期望格式（可选，不匹配时记入 issues）
 */
export function amllProbeLyricText(
  text: string,
  title: string,
  expectFormat?: AmllLyricFormat
): AmllProbeResult {
  const result: AmllProbeResult = {
    format: '',
    rawLen: 0,
    lineCount: 0,
    dynamicLineCount: 0,
    wordCount: 0,
    firstStart: 0,
    firstEnd: 0,
    lastStart: 0,
    lastEnd: 0,
    issues: [],
    samples: [],
    rawPreview: '',
    pass: true
  };
  result.rawLen = text.length;
  result.rawPreview = text.substring(0, 200);
  const fmt = amllDetectLyricFormat(text);
  result.format = amllFormatName(fmt);
  if (expectFormat !== undefined && fmt !== expectFormat) {
    result.issues.push(`格式识别不符: 期望 ${amllFormatName(expectFormat)}，实际 ${amllFormatName(fmt)}`);
  }
  const lines: AmllLyricLine[] = amllParseLyricText(text);
  result.lineCount = lines.length;
  if (lines.length === 0) {
    // 解析为空：若原文仅含时间戳（如接口返回的空翻译），视为数据问题而非解析错误
    const onlyTimestamps: boolean = /^(\s*\[\d{1,3}:\d{2}[.:]\d{1,3}\]\s*)+$/.test(text.trim());
    if (onlyTimestamps) {
      result.issues.push('原文仅含时间戳标签（无歌词文本，接口空翻译），解析器正确返回空');
      result.pass = true;
    } else {
      result.issues.push('解析结果为空');
      result.pass = false;
    }
    return result;
  }

  // 统计
  let dynamicCount = 0;
  let wordTotal = 0;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.words.length > 1) {
      dynamicCount++;
    }
    wordTotal += line.words.length;
  }
  result.dynamicLineCount = dynamicCount;
  result.wordCount = wordTotal;

  // 时间戳校验
  result.firstStart = lines[0].startTime;
  result.firstEnd = lines[0].endTime;
  const lastLine = lines[lines.length - 1];
  result.lastStart = lastLine.startTime;
  result.lastEnd = lastLine.endTime;

  let prevEnd = Number.NEGATIVE_INFINITY;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startTime < 0 || line.endTime < line.startTime) {
      result.issues.push(`行${i} 时间戳非法: [${line.startTime}, ${line.endTime}]`);
    }
    if (line.startTime < prevEnd) {
      result.issues.push(`行${i} 起始时间早于上一行结束 (上一行结束 ${prevEnd}, 本行开始 ${line.startTime})`);
    }
    if (line.endTime > prevEnd) {
      prevEnd = line.endTime;
    }
    for (let w = 0; w < line.words.length; w++) {
      const word = line.words[w];
      if (word.endTime < word.startTime) {
        result.issues.push(`行${i} 词${w} 时长非法: [${word.startTime}, ${word.endTime}] "${word.word}"`);
      }
    }
  }

  // 抽样
  const sampleCount = Math.min(3, lines.length);
  for (let i = 0; i < sampleCount; i++) {
    const line = lines[i];
    let text = '';
    for (let w = 0; w < line.words.length; w++) {
      text += line.words[w].word;
    }
    const isDynamic = line.words.length > 1 ? ' [逐字]' : '';
    result.samples.push(`[${fmtTime(line.startTime)}-${fmtTime(line.endTime)}]${isDynamic} ${text}`);
  }

  result.pass = result.issues.length === 0;
  return result;
}

/** 格式枚举转名称 */
export function amllFormatName(fmt: AmllLyricFormat): string {
  switch (fmt) {
    case AmllLyricFormat.LRC:
      return 'LRC';
    case AmllLyricFormat.LRC_A2:
      return 'LRC-A2';
    case AmllLyricFormat.ESLRC:
      return 'ESLRC';
    case AmllLyricFormat.YRC:
      return 'YRC';
    case AmllLyricFormat.QRC:
      return 'QRC';
    case AmllLyricFormat.LYS:
      return 'LYS';
    case AmllLyricFormat.LYL:
      return 'LYL';
    case AmllLyricFormat.LQE:
      return 'LQE';
    case AmllLyricFormat.TTML:
      return 'TTML';
    case AmllLyricFormat.KRC:
      return 'KRC';
    case AmllLyricFormat.KWLRX:
      return 'KWLRX';
    default:
      return 'UNKNOWN';
  }
}

/** 生成一行结果描述文本（用于页面展示与日志） */
export function amllProbeToString(title: string, r: AmllProbeResult): string {
  let s = `${title}\n`;
  s += `  格式: ${r.format} | 原文长度: ${r.rawLen}\n`;
  s += `  行数: ${r.lineCount} | 逐字行: ${r.dynamicLineCount} | 总词数: ${r.wordCount}\n`;
  s += `  时间范围: [${fmtTime(r.firstStart)} ~ ${fmtTime(r.lastEnd)}]\n`;
  for (let i = 0; i < r.samples.length; i++) {
    s += `  ${r.samples[i]}\n`;
  }
  if (r.issues.length > 0) {
    s += `  ⚠ ${r.issues.length} 个问题:\n`;
    for (let i = 0; i < r.issues.length; i++) {
      s += `    - ${r.issues[i]}\n`;
    }
  } else {
    s += '  ✓ 校验通过\n';
  }
  s += `  原文预览: ${r.rawPreview.replace(/\n/g, '\\n')}\n`;
  return s;
}
