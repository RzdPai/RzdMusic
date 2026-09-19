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
 * 歌词格式自动识别与统一入口。
 * 将任意支持的歌词文本解析为 AMLL LyricLine[]。
 */
import { AmllLyricFormat, AmllLyricLine } from '../model/AmllTypes';
import {
  amllParseEslrc,
  amllParseKrc,
  amllParseKwLrcx,
  amllParseLrc,
  amllParseLrcA2,
  amllParseLyl,
  amllParseLqe,
  amllParseLys,
  amllParseQrc,
  amllParseYrc
} from './AmllLyricFormatParsers';
import { amllParseTtmlLyric } from './AmllTtml';
import { amllDecryptQrcHex } from './AmllQrcCodec';

/** 识别歌词格式 */
export function amllDetectLyricFormat(text: string): AmllLyricFormat {
  if (text === undefined || text.length === 0) {
    return AmllLyricFormat.LRC;
  }
  const trimmed = text.trim();
  if ((trimmed.startsWith('<tt') || trimmed.startsWith('<?xml')) &&
    (trimmed.includes('itunes:timing') || trimmed.includes('</tt>') || trimmed.includes('xmlns'))) {
    return AmllLyricFormat.TTML;
  }
  if (trimmed.includes('[Lyricify Quick Export]')) {
    return AmllLyricFormat.LQE;
  }
  if (trimmed.includes('[type:LyricifyLines]')) {
    return AmllLyricFormat.LYL;
  }

  const lines: string[] = trimmed.split(/\r?\n/).map((l: string) => l.trim())
    .filter((l: string) => l.length > 0);
  if (lines.length === 0) {
    return AmllLyricFormat.LRC;
  }

  let hasWordSpans = false;
  let hasKrcSpans = false;
  let hasLysHeader = false;
  let hasYrcWords = false;
  let hasQrcWords = false;
  let hasEslrcWordTimes = false;
  let hasLrcA2Times = false;
  let hasLrcx = false;
  let lrcLike = false;

  const lysPropRe: RegExp = new RegExp('^\\[(\\d)\\]');
  const lineTimeRe: RegExp = new RegExp('^\\[(\\d+),(\\d+)\\]');
  const yrcWordRe: RegExp = new RegExp('\\((\\d+),(\\d+),0\\)');
  const qrcWordRe: RegExp = new RegExp('\\((\\d+),(\\d+)\\)');
  const krcSpanRe: RegExp = new RegExp('<\\d+,\\d+,\\d+>');
  const lrcTimeRe: RegExp = new RegExp('^\\[\\d{1,2}:\\d{2}[.:]\\d{1,3}\\]');
  const wordAngleRe: RegExp = new RegExp('<\\d{1,2}:\\d{2}');
  const wordSpanRe: RegExp = new RegExp('\\(\\d+,\\d+\\)');
  const multiBracketRe: RegExp = new RegExp('\\]\\S+\\[');
  const lrcxRe: RegExp = new RegExp('^\\[\\d{2}:\\d{2}\\.\\d{3}\\]<(-?\\d+),(-?\\d+)>');
  const kuwoTagRe: RegExp = new RegExp('\\[kuwo:');

  for (let i = 0; i < lines.length && i < 40; i++) {
    const line = lines[i];
    if (kuwoTagRe.test(line)) {
      hasLrcx = true;
      continue;
    }
    if (lrcxRe.test(line)) {
      hasLrcx = true;
      continue;
    }
    if (lysPropRe.test(line) && line.includes('(') && line.includes(')')) {
      hasLysHeader = true;
      continue;
    }
    const lineTimeMatch = line.match(lineTimeRe);
    if (lineTimeMatch !== null) {
      const rest = line.substring(lineTimeMatch[0].length);
      if (krcSpanRe.test(rest)) {
        hasKrcSpans = true;
      } else if (yrcWordRe.test(rest)) {
        hasYrcWords = true;
      } else if (qrcWordRe.test(rest)) {
        hasQrcWords = true;
      }
      continue;
    }
    if (lrcTimeRe.test(line)) {
      lrcLike = true;
      if (wordAngleRe.test(line)) {
        hasLrcA2Times = true;
      } else if (multiBracketRe.test(line)) {
        hasEslrcWordTimes = true;
      }
      continue;
    }
    if (line.includes('(') && line.includes(')') && line.includes('[') && wordSpanRe.test(line)) {
      hasWordSpans = true;
    }
  }

  if (hasKrcSpans) {
    return AmllLyricFormat.KRC;
  }
  if (hasLrcx) {
    return AmllLyricFormat.KWLRX;
  }
  if (hasYrcWords) {
    return AmllLyricFormat.YRC;
  }
  if (hasQrcWords) {
    return AmllLyricFormat.QRC;
  }
  if (hasLysHeader || hasWordSpans) {
    return AmllLyricFormat.LYS;
  }
  if (hasLrcA2Times) {
    return AmllLyricFormat.LRC_A2;
  }
  if (hasEslrcWordTimes) {
    return AmllLyricFormat.ESLRC;
  }
  void lrcLike;
  return AmllLyricFormat.LRC;
}

/** 将任意歌词文本解析为 AMLL 歌词行（解析异常时返回空数组，避免上层崩溃） */
export function amllParseLyricText(text: string, format?: AmllLyricFormat): AmllLyricLine[] {
  if (text === undefined || text.length === 0) {
    return [];
  }
  const fmt = format !== undefined ? format : amllDetectLyricFormat(text);
  try {
    switch (fmt) {
      case AmllLyricFormat.TTML: {
        const ttml = amllParseTtmlLyric(text);
        return ttml.lines;
      }
      case AmllLyricFormat.LRC_A2:
        return amllParseLrcA2(text);
      case AmllLyricFormat.ESLRC:
        return amllParseEslrc(text);
      case AmllLyricFormat.YRC:
        return amllParseYrc(text);
      case AmllLyricFormat.QRC:
        return amllParseQrc(text);
      case AmllLyricFormat.LYS:
        return amllParseLys(text);
      case AmllLyricFormat.LYL:
        return amllParseLyl(text);
      case AmllLyricFormat.LQE:
        return amllParseLqe(text);
    case AmllLyricFormat.KRC:
      return amllParseKrc(text);
    case AmllLyricFormat.KWLRX:
      return amllParseKwLrcx(text);
    case AmllLyricFormat.LRC:
    default:
      return amllParseLrc(text);
    }
  } catch (_err) {
    // 解析异常（如损坏的 TTML/非法输入）：回退空结果，不向上抛出
    return [];
  }
}

/** 解析缓存（key=格式+歌词文本），避免迷你歌词/歌词页重复解析与切换卡顿 */
const lyricParseCache: Map<string, AmllLyricLine[]> = new Map<string, AmllLyricLine[]>();
const LYRIC_CACHE_MAX: number = 8;

/**
 * 读取已缓存的歌词解析结果（未缓存返回 undefined，缓存过空结果返回 []）。
 */
export function amllGetCachedLyric(text: string, format?: AmllLyricFormat): AmllLyricLine[] | undefined {
  if (text === undefined || text.length === 0) {
    return [];
  }
  const key: string = (format !== undefined ? format.toString() : 'auto') + '|' + text;
  return lyricParseCache.get(key);
}

/**
 * 带缓存的歌词解析：同一文本只解析一次，歌词页/迷你歌词共用。
 */
export function amllParseLyricCached(text: string, format?: AmllLyricFormat): AmllLyricLine[] {
  if (text === undefined || text.length === 0) {
    return [];
  }
  const key: string = (format !== undefined ? format.toString() : 'auto') + '|' + text;
  const hit: AmllLyricLine[] | undefined = lyricParseCache.get(key);
  if (hit !== undefined) {
    return hit;
  }
  const lines: AmllLyricLine[] = amllParseLyricText(text, format);
  if (lyricParseCache.size >= LYRIC_CACHE_MAX) {
    const firstKey: string | undefined = lyricParseCache.keys().next().value as string | undefined;
    if (firstKey !== undefined) {
      lyricParseCache.delete(firstKey);
    }
  }
  lyricParseCache.set(key, lines);
  return lines;
}

/**
 * 解析 QRC 加密歌词：先 3DES+inflate 解密，再去头尾 XML，最后解析歌词行
 */export function amllParseEncryptedQrc(text: string): AmllLyricLine[] {
  let decrypted = '';
  try {
    decrypted = amllDecryptQrcHex(text.trim());
  } catch (e) {
    return [];
  }
  // 去掉 QRC 的 XML 头尾
  const firstBracket = decrypted.indexOf('[');
  const lastBracket = decrypted.lastIndexOf(']');
  if (firstBracket === -1 || lastBracket === -1) {
    return [];
  }
  const lyricPart = decrypted.substring(firstBracket, lastBracket + 1);
  return amllParseQrc(lyricPart);
}
