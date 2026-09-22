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
 * TTML 歌词解析与生成（对应原仓库 packages/ttml 的忠实移植，基于自研轻量 XML 解析器）。
 */
import {
  AmllAgent,
  AmllLyricLine,
  AmllLyricWord,
  AmllRubyTag,
  AmllSubLyricContent,
  AmllSyllable,
  AmllTtmlLine,
  AmllTtmlMetadata,
  AmllTtmlResult,
  AmllLyricBase,
  AmllBackgroundVocal
} from '../model/AmllTypes';
import {
  amllParseXml,
  amllXmlChildNodes,
  amllXmlGetAttr,
  amllXmlGetAttrNS,
  amllXmlGetElementsByTagName,
  amllXmlGetElementsByTagNameNS,
  amllXmlTextContent,
  AmllXmlElement,
  AmllXmlText
} from './AmllXml';
const TT_PREFIX: string = 'tt';
const TTM_PREFIX: string = 'ttm';
const ITUNES_PREFIX: string = 'itunes';
const AMLL_PREFIX: string = 'amll';
const XML_PREFIX: string = 'xml';
const TTS_PREFIX: string = 'tts';

const E_HEAD: string = 'head';
const E_BODY: string = 'body';
const E_DIV: string = 'div';
const E_P: string = 'p';
const E_TITLE: string = 'title';
const E_NAME: string = 'name';
const E_META: string = 'meta';
const E_ITUNES_METADATA: string = 'iTunesMetadata';
const E_SONGWRITERS: string = 'songwriters';
const E_SONGWRITER: string = 'songwriter';
const E_TRANSLATION: string = 'translation';
const E_TRANSLATIONS: string = 'translations';
const E_TRANSLITERATION: string = 'transliteration';
const E_TRANSLITERATIONS: string = 'transliterations';
const E_TEXT: string = 'text';
const E_AGENT: string = 'agent';

const A_TIMING: string = 'timing';
const A_ID: string = 'id';
const A_KEY: string = 'key';
const A_VALUE: string = 'value';
const A_LANG: string = 'lang';
const A_FOR: string = 'for';
const A_SONG_PART: string = 'songPart';
const A_SONG_PART_KEBAB: string = 'song-part';
const A_BEGIN: string = 'begin';
const A_END: string = 'end';
const A_ROLE: string = 'role';
const A_TYPE: string = 'type';
const A_RUBY: string = 'ruby';
const A_OBSCENE: string = 'obscene';
const A_EMPTY_BEAT: string = 'empty-beat';

const V_WORD: string = 'Word';
const V_LINE: string = 'Line';
const V_MUSIC_NAME: string = 'musicName';
const V_ARTISTS: string = 'artists';
const V_ALBUM: string = 'album';
const V_ISRC: string = 'isrc';
const V_TTML_AUTHOR_GITHUB: string = 'ttmlAuthorGithub';
const V_TTML_AUTHOR_GITHUB_LOGIN: string = 'ttmlAuthorGithubLogin';
const V_NCM_MUSIC_ID: string = 'ncmMusicId';
const V_QQ_MUSIC_ID: string = 'qqMusicId';
const V_SPOTIFY_ID: string = 'spotifyId';
const V_APPLE_MUSIC_ID: string = 'appleMusicId';
const V_ROLE_BG: string = 'x-bg';
const V_ROLE_TRANSLATION: string = 'x-translation';
const V_ROLE_ROMAN: string = 'x-roman';
const V_GROUP: string = 'group';
const V_AGENT_DEFAULT: string = 'v1';
const V_RUBY_CONTAINER: string = 'container';
const V_RUBY_BASE: string = 'base';
const V_RUBY_TEXT_CONTAINER: string = 'textContainer';
const V_RUBY_TEXT: string = 'text';

const PLATFORM_ORDER: string[] = [
  'ncmMusicId',
  'qqMusicId',
  'spotifyId',
  'appleMusicId'
];

interface IParsedState {
  fullText: string;
  words: AmllSyllable[];
  translations: AmllSubLyricContent[];
  romanizations: AmllSubLyricContent[];
  bgTranslations: AmllSubLyricContent[];
  bgRomanizations: AmllSubLyricContent[];
  backgroundVocal?: AmllBackgroundVocal;
}

/** 侧载（sidecar）条目 */
interface AmllSidecarEntry {
  translations?: AmllSubLyricContent[];
  romanizations?: AmllSubLyricContent[];
  bgTranslations?: AmllSubLyricContent[];
  bgRomanizations?: AmllSubLyricContent[];
}
/** 翻译/音译内容对 */
interface AmllSubContentPair {
  main?: AmllSubLyricContent;
  bg?: AmllSubLyricContent;
}

/** head 解析结果 */
interface AmllHeadResult {
  metadata: AmllTtmlMetadata;
  sidecar: Map<string, AmllSidecarEntry>;
}

const TIME_REGEX: RegExp = new RegExp('^(?:(?:(\\d+):)?(\\d+):)?(\\d+(?:\\.\\d+)?)$');

/** 解析 TTML 时间字符串为毫秒 */
function parseTtmlTime(timeStr: string | undefined): number {
  if (timeStr === undefined) {
    return 0;
  }
  const cleanStr = timeStr.trim();
  if (cleanStr.length === 0) {
    return 0;
  }
  if (cleanStr.endsWith('s')) {
    const seconds = Number(cleanStr.slice(0, -1));
    if (Number.isNaN(seconds)) {
      return 0;
    }
    return Math.round(seconds * 1000);
  }
  const match: RegExpMatchArray | null = cleanStr.match(TIME_REGEX);
  if (match !== null) {
    const secNum = Number(match[3]);
    const minNum = match[2] !== undefined ? Number.parseInt(match[2], 10) : 0;
    const hrNum = match[1] !== undefined ? Number.parseInt(match[1], 10) : 0;
    if (!Number.isNaN(secNum) && !Number.isNaN(minNum) && !Number.isNaN(hrNum)) {
      const totalSeconds = hrNum * 3600 + minNum * 60 + secNum;
      return Math.round(totalSeconds * 1000);
    }
  }
  return 0;
}

function normalizeText(text: string | undefined, trim: boolean = true): string {
  if (text === undefined || text.length === 0) {
    return '';
  }
  const normalized = text.replace(/\s+/g, ' ');
  return trim ? normalized.trim() : normalized;
}

/** 解析 TTML 字符串 */
export function amllParseTtml(xmlStr: string): AmllTtmlResult {
  const doc = amllParseXml(xmlStr);
  const headResult = parseHead(doc.root);
  const metadata = headResult.metadata;
  const sidecar = headResult.sidecar;
  const result: AmllTtmlResult = {
    metadata: metadata,
    lines: []
  };

  const root = doc.root;
  const lang = amllXmlGetAttrNS(root, XML_PREFIX, A_LANG);
  if (lang !== undefined) {
    result.metadata.language = lang;
  }
  const timing = amllXmlGetAttrNS(root, ITUNES_PREFIX, A_TIMING);
  if (timing === V_WORD || timing === V_LINE) {
    result.metadata.timingMode = timing;
  }

  parseBody(doc.root, result, sidecar);

  if (result.metadata.timingMode === undefined) {
    result.metadata.timingMode = inferTimingMode(result.lines);
  }
  if (result.metadata.platformIds !== undefined && result.metadata.platformIds.size > 0) {
    result.metadata.platformIds = sortPlatformIds(result.metadata.platformIds);
  }
  return result;
}

function inferTimingMode(lines: AmllTtmlLine[]): string {
  let hasWordTiming = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if ((line.words !== undefined && line.words.length > 1) ||
      (line.backgroundVocal !== undefined && line.backgroundVocal.words !== undefined &&
        line.backgroundVocal.words.length > 1)) {
      hasWordTiming = true;
      break;
    }
  }
  return hasWordTiming ? V_WORD : V_LINE;
}

function sortPlatformIds(
  platformIds: Map<string, string[]>
): Map<string, string[]> {
  const ordered: Map<string, string[]> = new Map<string, string[]>();
  for (let i = 0; i < PLATFORM_ORDER.length; i++) {
    const key = PLATFORM_ORDER[i];
    if (platformIds.has(key)) {
      ordered.set(key, platformIds.get(key) as string[]);
    }
  }
  platformIds.forEach((value: string[], key: string) => {
    if (!ordered.has(key)) {
      ordered.set(key, value);
    }
  });
  return ordered;
}

function parseHead(headEl: AmllXmlElement): AmllHeadResult {
  const resultMeta: AmllTtmlMetadata = {
    title: [],
    artist: [],
    album: [],
    isrc: [],
    authorIds: [],
    authorNames: [],
    songwriters: [],
    agents: new Map<string, AmllAgent>(),
    rawProperties: new Map<string, string[]>()
  };
  const sidecar: Map<string, AmllSidecarEntry> = new Map<string, AmllSidecarEntry>();

  const heads = amllXmlGetElementsByTagName(headEl, E_HEAD);
  const head = heads.length > 0 ? heads[0] : undefined;
  if (head === undefined) {
    return { metadata: resultMeta, sidecar: sidecar };
  }
  parseTTMElements(head, resultMeta);
  parseAMLLMeta(head, resultMeta);
  parseiTunesExtensions(head, resultMeta, sidecar);
  deduplicateMetadata(resultMeta);
  return { metadata: resultMeta, sidecar: sidecar };
}

function deduplicateMetadata(meta: AmllTtmlMetadata): void {
  const dedupe = (arr?: string[]): string[] => {
    if (arr === undefined) {
      return [];
    }
    const set = new Set<string>();
    const result: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      if (!set.has(arr[i])) {
        set.add(arr[i]);
        result.push(arr[i]);
      }
    }
    return result;
  };
  meta.title = dedupe(meta.title);
  meta.artist = dedupe(meta.artist);
  meta.album = dedupe(meta.album);
  meta.isrc = dedupe(meta.isrc);
  meta.authorIds = dedupe(meta.authorIds);
  meta.authorNames = dedupe(meta.authorNames);
  meta.songwriters = dedupe(meta.songwriters);
  if (meta.platformIds !== undefined) {
    meta.platformIds.forEach((value: string[], key: string) => {
      meta.platformIds?.set(key, dedupe(value));
    });
  }
  if (meta.rawProperties !== undefined) {
    meta.rawProperties.forEach((value: string[], key: string) => {
      meta.rawProperties?.set(key, dedupe(value));
    });
  }
}

function parseTTMElements(head: AmllXmlElement, meta: AmllTtmlMetadata): void {
  const titles = amllXmlGetElementsByTagNameNS(head, TTM_PREFIX, E_TITLE);
  if (titles.length > 0 && amllXmlTextContent(titles[0]).trim().length > 0) {
    meta.title?.push(amllXmlTextContent(titles[0]).trim());
  }
  const agents = amllXmlGetElementsByTagNameNS(head, TTM_PREFIX, E_AGENT);
  for (let i = 0; i < agents.length; i++) {
    const agent = agents[i];
    const id = amllXmlGetAttrNS(agent, XML_PREFIX, A_ID);
    if (id === undefined) {
      continue;
    }
    const type = amllXmlGetAttrNS(agent, TTM_PREFIX, A_TYPE);
    const names = amllXmlGetElementsByTagNameNS(agent, TTM_PREFIX, E_NAME);
    const agentObj: AmllAgent = { id: id };
    if (type !== undefined) {
      agentObj.type = type;
    }
    if (names.length > 0 && amllXmlTextContent(names[0]).trim().length > 0) {
      agentObj.name = amllXmlTextContent(names[0]).trim();
    }
    if (meta.agents === undefined) {
      meta.agents = new Map<string, AmllAgent>();
    }
    meta.agents.set(id, agentObj);
  }
}

function parseAMLLMeta(head: AmllXmlElement, meta: AmllTtmlMetadata): void {
  const metas = amllXmlGetElementsByTagNameNS(head, AMLL_PREFIX, E_META);
  for (let i = 0; i < metas.length; i++) {
    const el = metas[i];
    const key = amllXmlGetAttrNS(el, AMLL_PREFIX, A_KEY);
    const valueRaw = amllXmlGetAttrNS(el, AMLL_PREFIX, A_VALUE);
    if (key === undefined || valueRaw === undefined) {
      continue;
    }
    const value = valueRaw.trim();
    if (value.length === 0) {
      continue;
    }
    switch (key) {
      case V_MUSIC_NAME:
        meta.title?.push(value);
        break;
      case V_ARTISTS:
        meta.artist?.push(value);
        break;
      case V_ALBUM:
        meta.album?.push(value);
        break;
      case V_ISRC:
        meta.isrc?.push(value);
        break;
      case V_TTML_AUTHOR_GITHUB:
        meta.authorIds?.push(value);
        break;
      case V_TTML_AUTHOR_GITHUB_LOGIN:
        meta.authorNames?.push(value);
        break;
      case V_NCM_MUSIC_ID:
      case V_QQ_MUSIC_ID:
      case V_SPOTIFY_ID:
      case V_APPLE_MUSIC_ID: {
        if (meta.platformIds === undefined) {
          meta.platformIds = new Map<string, string[]>();
        }
        let arr = meta.platformIds.get(key);
        if (arr === undefined) {
          arr = [];
          meta.platformIds.set(key, arr);
        }
        arr.push(value);
        break;
      }
      default: {
        if (meta.rawProperties === undefined) {
          meta.rawProperties = new Map<string, string[]>();
        }
        let arr = meta.rawProperties.get(key);
        if (arr === undefined) {
          arr = [];
          meta.rawProperties.set(key, arr);
        }
        arr.push(value);
        break;
      }
    }
  }
}

function extractSubContent(
  base: AmllSubLyricContent | AmllLyricBase,
  lang: string | undefined,
  ignoreWords: boolean = false
): AmllSubContentPair {
  const result: AmllSubContentPair = {};
  const mainText = normalizeText(base.text);
  const hasMainWords = !ignoreWords && base.words !== undefined && base.words.length > 0;
  if (mainText.length > 0 || hasMainWords) {
    const main: AmllSubLyricContent = { text: mainText };
    if (lang !== undefined) {
      main.language = lang;
    }
    if (hasMainWords) {
      const isZeroFallback =
        base.words !== undefined && base.words.length === 1 &&
        base.words[0].startTime === 0 && base.words[0].endTime === 0;
      if (!isZeroFallback) {
        main.words = base.words;
      }
    }
    result.main = main;
  }
  if ((base as AmllLyricBase).backgroundVocal !== undefined) {
    const bgVocal = (base as AmllLyricBase).backgroundVocal;
    if (bgVocal !== undefined) {
      const bgText = normalizeText(bgVocal.text);
      const hasBgWords = !ignoreWords && bgVocal.words !== undefined && bgVocal.words.length > 0;
      if (bgText.length > 0 || hasBgWords) {
        const bg: AmllSubLyricContent = { text: bgText };
        if (lang !== undefined) {
          bg.language = lang;
        }
        if (hasBgWords) {
          const isZeroFallback = bgVocal.words !== undefined && bgVocal.words.length === 1 &&
            bgVocal.words[0].startTime === 0 && bgVocal.words[0].endTime === 0;
          if (!isZeroFallback) {
            bg.words = bgVocal.words;
          }
        }
        result.bg = bg;
      }
    }
  }
  return result;
}
function parseiTunesExtensions(
  head: AmllXmlElement,
  meta: AmllTtmlMetadata,
  sidecar: Map<string, AmllSidecarEntry>
): void {
  const iTunesMetas = amllXmlGetElementsByTagName(head, E_ITUNES_METADATA);
  if (iTunesMetas.length === 0) {
    return;
  }
  for (let m = 0; m < iTunesMetas.length; m++) {
    const iTunesMeta = iTunesMetas[m];
    const songwritersContainer = amllXmlGetElementsByTagName(iTunesMeta, E_SONGWRITERS);
    if (songwritersContainer.length > 0) {
      const writers = amllXmlGetElementsByTagName(songwritersContainer[0], E_SONGWRITER);
      for (let w = 0; w < writers.length; w++) {
        const name = amllXmlTextContent(writers[w]).trim();
        if (name.length > 0) {
          meta.songwriters?.push(name);
        }
      }
    }

    const processEntries = (
      containerTagName: string,
      itemTagName: string,
      type: 'translations' | 'romanizations'
    ): void => {
      const containers = amllXmlGetElementsByTagName(iTunesMeta, containerTagName);
      if (containers.length === 0) {
        return;
      }
      const items = amllXmlGetElementsByTagName(containers[0], itemTagName);
      for (let it = 0; it < items.length; it++) {
        const item = items[it];
        const lang = amllXmlGetAttrNS(item, XML_PREFIX, A_LANG);
        const textNodes = amllXmlGetElementsByTagName(item, E_TEXT);
        for (let t = 0; t < textNodes.length; t++) {
          const textNode = textNodes[t];
          const forId = amllXmlGetAttr(textNode, A_FOR);
          const parsedContent = parseCommonContent(textNode);
          if (forId !== undefined) {
            const subContents = extractSubContent(parsedContent, lang, false);
            let entry = sidecar.get(forId);
            if (entry === undefined) {
              entry = {};
              sidecar.set(forId, entry);
            }
            if (subContents.main !== undefined) {
              if (type === 'translations') {
                if (entry.translations === undefined) {
                  entry.translations = [];
                }
                entry.translations.push(subContents.main);
              } else {
                if (entry.romanizations === undefined) {
                  entry.romanizations = [];
                }
                entry.romanizations.push(subContents.main);
              }
            }
            if (subContents.bg !== undefined) {
              if (type === 'translations') {
                if (entry.bgTranslations === undefined) {
                  entry.bgTranslations = [];
                }
                entry.bgTranslations.push(subContents.bg);
              } else {
                if (entry.bgRomanizations === undefined) {
                  entry.bgRomanizations = [];
                }
                entry.bgRomanizations.push(subContents.bg);
              }
            }
          }
        }
      }
    };

    processEntries(E_TRANSLATIONS, E_TRANSLATION, 'translations');
    processEntries(E_TRANSLITERATIONS, E_TRANSLITERATION, 'romanizations');
  }
}

function parseBody(
  root: AmllXmlElement,
  result: AmllTtmlResult,
  sidecar: Map<string, AmllSidecarEntry>
): void {
  const bodies = amllXmlGetElementsByTagName(root, E_BODY);
  if (bodies.length === 0) {
    return;
  }
  const body = bodies[0];
  const childNodes = amllXmlChildNodes(body);
  let currentBlockIndex = 0;

  for (let i = 0; i < childNodes.length; i++) {
    const node = childNodes[i];
    const el = node as AmllXmlElement;
    if (el.tagName === undefined) {
      continue;
    }
    if (el.localName === E_DIV) {
      currentBlockIndex++;
      const songPart: string | undefined =
        amllXmlGetAttrNS(el, ITUNES_PREFIX, A_SONG_PART_KEBAB) !== undefined
          ? amllXmlGetAttrNS(el, ITUNES_PREFIX, A_SONG_PART_KEBAB)
          : amllXmlGetAttrNS(el, ITUNES_PREFIX, A_SONG_PART);
      const pNodes = amllXmlGetElementsByTagNameNS(el, TT_PREFIX, E_P);
      const pList = pNodes.length > 0 ? pNodes : amllXmlGetElementsByTagName(el, E_P);
      for (let p = 0; p < pList.length; p++) {
        processLineElement(pList[p], result.lines, sidecar, songPart, currentBlockIndex);
      }
    } else if (el.localName === E_P) {
      currentBlockIndex++;
      processLineElement(el, result.lines, sidecar, undefined, currentBlockIndex);
    }
  }
}

function processLineElement(
  p: AmllXmlElement,
  lines: AmllTtmlLine[],
  sidecar: Map<string, AmllSidecarEntry>,
  songPart?: string,
  blockIndex?: number
): void {
  const id = amllXmlGetAttrNS(p, ITUNES_PREFIX, A_KEY);
  if (id === undefined) {
    return;
  }
  const baseContent = parseCommonContent(p);
  const line: AmllTtmlLine = {
    id: id,
    text: baseContent.text,
    startTime: baseContent.startTime,
    endTime: baseContent.endTime,
    words: baseContent.words,
    translations: baseContent.translations,
    romanizations: baseContent.romanizations,
    backgroundVocal: baseContent.backgroundVocal
  };
  if (songPart !== undefined) {
    line.songPart = songPart;
  }
  if (blockIndex !== undefined) {
    line.blockIndex = blockIndex;
  }
  const agentId = amllXmlGetAttrNS(p, TTM_PREFIX, E_AGENT);
  if (agentId !== undefined) {
    line.agentId = agentId;
  }

  const externalData = sidecar.get(id);
  if (externalData !== undefined) {
    if (externalData.translations !== undefined) {
      if (line.translations === undefined) {
        line.translations = [];
      }
      for (let i = 0; i < externalData.translations.length; i++) {
        line.translations.push(externalData.translations[i]);
      }
    }
    if (externalData.romanizations !== undefined) {
      if (line.romanizations === undefined) {
        line.romanizations = [];
      }
      for (let i = 0; i < externalData.romanizations.length; i++) {
        line.romanizations.push(externalData.romanizations[i]);
      }
    }
    if (externalData.bgTranslations !== undefined && line.backgroundVocal !== undefined) {
      if (line.backgroundVocal.translations === undefined) {
        line.backgroundVocal.translations = [];
      }
      for (let i = 0; i < externalData.bgTranslations.length; i++) {
        line.backgroundVocal.translations.push(externalData.bgTranslations[i]);
      }
    }
    if (externalData.bgRomanizations !== undefined && line.backgroundVocal !== undefined) {
      if (line.backgroundVocal.romanizations === undefined) {
        line.backgroundVocal.romanizations = [];
      }
      for (let i = 0; i < externalData.bgRomanizations.length; i++) {
        line.backgroundVocal.romanizations.push(externalData.bgRomanizations[i]);
      }
    }
  }
  lines.push(line);
}

function parseCommonContent(element: AmllXmlElement): AmllLyricBase {
  const beginAttr = amllXmlGetAttrNS(element, XML_PREFIX, A_BEGIN);
  const endAttr = amllXmlGetAttrNS(element, XML_PREFIX, A_END);
  const originalStartTime = parseTtmlTime(beginAttr);
  const originalEndTime = parseTtmlTime(endAttr);

  const state = extractNodeState(element);

  if (state.backgroundVocal !== undefined) {
    if (state.bgTranslations.length > 0) {
      if (state.backgroundVocal.translations === undefined) {
        state.backgroundVocal.translations = [];
      }
      for (let i = 0; i < state.bgTranslations.length; i++) {
        state.backgroundVocal.translations.push(state.bgTranslations[i]);
      }
    }
    if (state.bgRomanizations.length > 0) {
      if (state.backgroundVocal.romanizations === undefined) {
        state.backgroundVocal.romanizations = [];
      }
      for (let i = 0; i < state.bgRomanizations.length; i++) {
        state.backgroundVocal.romanizations.push(state.bgRomanizations[i]);
      }
    }
  }

  finalizeWords(state.words);

  const range = calculateTimeRange(originalStartTime, originalEndTime, state.words,
    state.backgroundVocal);
  const cleanFullText = normalizeText(state.fullText);
  const hasTimeAttrs = beginAttr !== undefined || endAttr !== undefined;
  applyFallbackWord(state.words, cleanFullText, hasTimeAttrs, originalStartTime,
    originalEndTime, range.startTime, range.endTime);

  const result: AmllLyricBase = {
    text: cleanFullText,
    startTime: range.startTime,
    endTime: range.endTime,
    words: state.words.length > 0 ? state.words : undefined,
    translations: state.translations.length > 0 ? state.translations : undefined,
    romanizations: state.romanizations.length > 0 ? state.romanizations : undefined,
    backgroundVocal: state.backgroundVocal
  };
  return result;
}

function extractNodeState(element: AmllXmlElement): IParsedState {
  const state: IParsedState = {
    fullText: '',
    words: [],
    translations: [],
    romanizations: [],
    bgTranslations: [],
    bgRomanizations: [],
    backgroundVocal: undefined
  };
  const childNodes = amllXmlChildNodes(element);
  for (let i = 0; i < childNodes.length; i++) {
    const node = childNodes[i];
    const el = node as AmllXmlElement;
    if (el.tagName === undefined) {
      const textNode = node as AmllXmlText;
      processTextNode(state, textNode.text);
    } else {
      processElementNode(state, el);
    }
  }
  return state;
}

/** 时间范围 */
interface AmllTimeRange {
  startTime: number;
  endTime: number;
}

function calculateTimeRange(
  originalStart: number,
  originalEnd: number,
  words: AmllSyllable[],
  bgVocal?: AmllBackgroundVocal
): AmllTimeRange {
  let startTime = originalStart;
  let endTime = originalEnd;
  let minChildStart = Number.POSITIVE_INFINITY;
  let maxChildEnd = 0;
  for (let i = 0; i < words.length; i++) {
    if (words[i].startTime < minChildStart) {
      minChildStart = words[i].startTime;
    }
    if (words[i].endTime > maxChildEnd) {
      maxChildEnd = words[i].endTime;
    }
  }
  if (bgVocal !== undefined) {
    if (bgVocal.startTime < minChildStart) {
      minChildStart = bgVocal.startTime;
    }
    if (bgVocal.endTime > maxChildEnd) {
      maxChildEnd = bgVocal.endTime;
    }
  }
  if (startTime === 0 || (minChildStart > 0 && minChildStart < startTime)) {
    startTime = minChildStart === Number.POSITIVE_INFINITY ? 0 : minChildStart;
  }
  if (endTime === 0 || maxChildEnd > endTime) {
    endTime = maxChildEnd;
  }
  const range: AmllTimeRange = { startTime: startTime, endTime: endTime };
  return range;
}

function applyFallbackWord(
  words: AmllSyllable[],
  cleanText: string,
  hasTimeAttrs: boolean,
  origStart: number,
  origEnd: number,
  calcStart: number,
  calcEnd: number
): void {
  if (words.length === 0 && cleanText.length > 0 && hasTimeAttrs) {
    const fallbackWord: AmllSyllable = {
      text: cleanText,
      startTime: origStart > 0 ? origStart : calcStart,
      endTime: origEnd > 0 ? origEnd : calcEnd,
      endsWithSpace: false
    };
    words.push(fallbackWord);
  }
}

function processTextNode(state: IParsedState, rawText: string): void {
  const isFormatting = rawText.includes('\n');
  if (isFormatting && rawText.trim().length === 0) {
    return;
  }
  const normalizedText = normalizeText(rawText, false);
  state.fullText += normalizedText;
  if (!isFormatting && normalizedText.length > 0 && normalizedText.trim().length === 0) {
    if (state.words.length > 0) {
      const lastWord = state.words[state.words.length - 1];
      lastWord.endsWithSpace = true;
    }
  }
}

function processElementNode(state: IParsedState, el: AmllXmlElement): void {
  const role = amllXmlGetAttrNS(el, TTM_PREFIX, A_ROLE);
  const rubyAttr = amllXmlGetAttrNS(el, TTS_PREFIX, A_RUBY);
  if (rubyAttr === V_RUBY_CONTAINER) {
    processRubyElement(state, el);
    return;
  }
  switch (role) {
    case V_ROLE_BG:
      state.backgroundVocal = parseBackgroundVocal(el);
      break;
    case V_ROLE_TRANSLATION: {
      const translation = parseInlineSubContent(el);
      if (translation !== undefined) {
        if (translation.main !== undefined) {
          state.translations.push(translation.main);
        }
        if (translation.bg !== undefined) {
          state.bgTranslations.push(translation.bg);
        }
      }
      break;
    }
    case V_ROLE_ROMAN: {
      const romanization = parseInlineSubContent(el);
      if (romanization !== undefined) {
        if (romanization.main !== undefined) {
          state.romanizations.push(romanization.main);
        }
        if (romanization.bg !== undefined) {
          state.bgRomanizations.push(romanization.bg);
        }
      }
      break;
    }
    default:
      processWordElement(state, el);
      break;
  }
}

function processRubyElement(state: IParsedState, containerEl: AmllXmlElement): void {
  const obsceneAttr = amllXmlGetAttrNS(containerEl, AMLL_PREFIX, A_OBSCENE);
  const isObscene = obsceneAttr === 'true';
  const emptyBeatAttr = amllXmlGetAttrNS(containerEl, AMLL_PREFIX, A_EMPTY_BEAT);
  let emptyBeat: number | undefined = undefined;
  if (emptyBeatAttr !== undefined) {
    const parsedBeat = Number.parseInt(emptyBeatAttr, 10);
    if (!Number.isNaN(parsedBeat)) {
      emptyBeat = parsedBeat;
    }
  }

  let baseText = '';
  const rubyTags: AmllRubyTag[] = [];
  const childNodes = amllXmlChildNodes(containerEl);
  for (let i = 0; i < childNodes.length; i++) {
    const node = childNodes[i];
    const childEl = node as AmllXmlElement;
    if (childEl.tagName === undefined) {
      continue;
    }
    const childRubyAttr = amllXmlGetAttrNS(childEl, TTS_PREFIX, A_RUBY);
    if (childRubyAttr === V_RUBY_BASE) {
      baseText = normalizeText(amllXmlTextContent(childEl), false);
    } else if (childRubyAttr === V_RUBY_TEXT_CONTAINER) {
      const textNodes = amllXmlChildNodes(childEl);
      for (let t = 0; t < textNodes.length; t++) {
        const tNode = textNodes[t] as AmllXmlElement;
        if (tNode.tagName === undefined) {
          continue;
        }
        const tAttr = amllXmlGetAttrNS(tNode, TTS_PREFIX, A_RUBY);
        if (tAttr === V_RUBY_TEXT) {
          const begin = amllXmlGetAttrNS(tNode, XML_PREFIX, A_BEGIN);
          const end = amllXmlGetAttrNS(tNode, XML_PREFIX, A_END);
          const text = normalizeText(amllXmlTextContent(tNode), false).trim();
          if (text.length > 0 && begin !== undefined && end !== undefined) {
            const rubyTag: AmllRubyTag = {
              word: text,
              startTime: parseTtmlTime(begin),
              endTime: parseTtmlTime(end)
            };
            rubyTags.push(rubyTag);
          }
        }
      }
    }
  }
  if (baseText.length === 0) {
    return;
  }
  state.fullText += baseText;

  let startTime = 0;
  let endTime = 0;
  if (rubyTags.length > 0) {
    startTime = rubyTags[0].startTime;
    endTime = rubyTags[0].endTime;
    for (let r = 1; r < rubyTags.length; r++) {
      startTime = Math.min(startTime, rubyTags[r].startTime);
      endTime = Math.max(endTime, rubyTags[r].endTime);
    }
  }

  const cleanBaseText = baseText.trim();
  if (cleanBaseText.length > 0) {
    const endsWithSpace = /\s$/.test(baseText);
    const startsWithSpace = /^\s/.test(baseText);
    if (startsWithSpace && state.words.length > 0) {
      const lastWord = state.words[state.words.length - 1];
      lastWord.endsWithSpace = true;
    }
    const word: AmllSyllable = {
      text: cleanBaseText,
      startTime: startTime,
      endTime: endTime,
      ruby: rubyTags.length > 0 ? rubyTags : undefined,
      endsWithSpace: endsWithSpace,
      obscene: isObscene ? true : undefined,
      emptyBeat: emptyBeat
    };
    state.words.push(word);
  }
}

function processWordElement(state: IParsedState, el: AmllXmlElement): void {
  const wBegin = amllXmlGetAttrNS(el, XML_PREFIX, A_BEGIN);
  const wEnd = amllXmlGetAttrNS(el, XML_PREFIX, A_END);
  const obsceneAttr = amllXmlGetAttrNS(el, AMLL_PREFIX, A_OBSCENE);
  const isObscene = obsceneAttr === 'true';
  const emptyBeatAttr = amllXmlGetAttrNS(el, AMLL_PREFIX, A_EMPTY_BEAT);
  let emptyBeat: number | undefined = undefined;
  if (emptyBeatAttr !== undefined) {
    const parsedBeat = Number.parseInt(emptyBeatAttr, 10);
    if (!Number.isNaN(parsedBeat)) {
      emptyBeat = parsedBeat;
    }
  }

  const rawWText = amllXmlTextContent(el);
  const normalizedWText = normalizeText(rawWText, false);
  state.fullText += normalizedWText;

  if (wBegin !== undefined && wEnd !== undefined) {
    const isFormatting = rawWText.includes('\n');
    let startsWithSpace = false;
    let endsWithSpace = false;
    if (!isFormatting) {
      startsWithSpace = /^\s/.test(normalizedWText);
      endsWithSpace = /\s$/.test(normalizedWText);
    }
    const cleanText = normalizedWText.trim();
    if (startsWithSpace && state.words.length > 0) {
      const lastWord = state.words[state.words.length - 1];
      lastWord.endsWithSpace = true;
    }
    if (cleanText.length > 0) {
      const word: AmllSyllable = {
        text: cleanText,
        startTime: parseTtmlTime(wBegin),
        endTime: parseTtmlTime(wEnd),
        endsWithSpace: endsWithSpace,
        obscene: isObscene ? true : undefined,
        emptyBeat: emptyBeat
      };
      state.words.push(word);
    }
  }
}

function parseBackgroundVocal(el: AmllXmlElement): AmllBackgroundVocal {
  const parsed = parseCommonContent(el);
  const bgVocal: AmllBackgroundVocal = {
    text: parsed.text.replace(/^[(（]+/, '').replace(/[)）]+$/, ''),
    startTime: parsed.startTime,
    endTime: parsed.endTime,
    words: parsed.words,
    translations: parsed.translations,
    romanizations: parsed.romanizations
  };
  if (bgVocal.words !== undefined && bgVocal.words.length > 0) {
    bgVocal.words[0].text = bgVocal.words[0].text.replace(/^[(（]+/, '').trimStart();
    const lastIdx = bgVocal.words.length - 1;
    bgVocal.words[lastIdx].text = bgVocal.words[lastIdx].text.replace(/[)）]+$/, '').trimEnd();
  }
  return bgVocal;
}

function parseInlineSubContent(
  el: AmllXmlElement
): AmllSubContentPair | undefined {
  const lang = amllXmlGetAttrNS(el, XML_PREFIX, A_LANG);
  const parsed = parseCommonContent(el);
  const content = extractSubContent(parsed, lang, true);
  if (content.main !== undefined || content.bg !== undefined) {
    return content;
  }
  return undefined;
}

function finalizeWords(words: AmllSyllable[]): AmllSyllable[] {
  if (words.length === 0) {
    return [];
  }
  words[0].text = words[0].text.trimStart();
  const lastIdx = words.length - 1;
  words[lastIdx].text = words[lastIdx].text.trimEnd();
  words[lastIdx].endsWithSpace = false;
  return words;
}

// ==================== TTML → AMLL 转换 ====================

function toAmllWord(syllable: AmllSyllable): AmllLyricWord {
  const amllWord: AmllLyricWord = {
    startTime: syllable.startTime,
    endTime: syllable.endTime,
    word: syllable.text + (syllable.endsWithSpace === true ? ' ' : ''),
    romanWord: '',
    obscene: syllable.obscene
  };
  if (syllable.ruby !== undefined && syllable.ruby.length > 0) {
    const rubies: AmllRubyTag[] = [];
    for (let r = 0; r < syllable.ruby.length; r++) {
      const ruby = syllable.ruby[r];
      rubies.push({ startTime: ruby.startTime, endTime: ruby.endTime, word: ruby.word });
    }
    amllWord.ruby = rubies;
  }
  return amllWord;
}

function toAmllLine(
  source: AmllLyricBase,
  isBG: boolean,
  isDuet: boolean
): AmllLyricLine {
  let amllWords: AmllLyricWord[] = [];
  if (source.words !== undefined && source.words.length > 0) {
    amllWords = source.words.map((w: AmllSyllable): AmllLyricWord => toAmllWord(w));
  } else {
    amllWords = [
      {
        startTime: source.startTime,
        endTime: source.endTime,
        word: source.text,
        romanWord: ''
      }
    ];
  }

  let transText = '';
  const translations = (source as AmllLyricBase).translations;
  if (translations !== undefined && translations.length > 0) {
    transText = translations[0].text;
  }
  let romanText = '';
  const romanizations = (source as AmllLyricBase).romanizations;
  if (romanizations !== undefined && romanizations.length > 0) {
    const targetRoman = romanizations[0];
    const romanWords = targetRoman.words;
    if (romanWords === undefined || romanWords.length === 0) {
      romanText = targetRoman.text;
    } else if (amllWords.length > 0) {
      // 对齐逐字音译到主词
      for (let w = 0; w < amllWords.length && w < romanWords.length; w++) {
        amllWords[w].romanWord = romanWords[w].text;
      }
    }
  }

  return {
    words: amllWords,
    translatedLyric: transText,
    romanLyric: romanText,
    isBG: isBG,
    isDuet: isDuet,
    startTime: source.startTime,
    endTime: source.endTime
  };
}

/**
 * 将 TTML 解析结果转换为 AMLL 歌词行数组（对应原仓库 amll-converter.ts）
 */
export function amllTtmlToLyricLines(result: AmllTtmlResult): AmllLyricLine[] {
  // 多声部（对唱/多人）检测：记录出现过的 agent 顺序，第一个为主唱声部，其余视为对唱/伴唱声部
  const agentIds: string[] = [];
  for (let i = 0; i < result.lines.length; i++) {
    const line0 = result.lines[i];
    const lineId = line0.agentId !== undefined ? line0.agentId : V_AGENT_DEFAULT;
    if (agentIds.indexOf(lineId) === -1) {
      agentIds.push(lineId);
    }
  }
  const duetSong: boolean = agentIds.length > 1;
  const primaryId: string = agentIds.length > 0 ? agentIds[0] : V_AGENT_DEFAULT;

  const amllLines: AmllLyricLine[] = [];
  for (let i = 0; i < result.lines.length; i++) {
    const line = result.lines[i];
    const agentId = line.agentId !== undefined ? line.agentId : V_AGENT_DEFAULT;
    const agent = result.metadata.agents !== undefined ? result.metadata.agents.get(agentId) : undefined;
    // 对唱判定：agent 类型为合唱(group)，或多声部歌曲里的非主唱声部
    const isDuet = (agent !== undefined && agent.type === V_GROUP) || (duetSong && agentId !== primaryId);

    const mainLine: AmllLyricLine = toAmllLine(line, false, isDuet);
    amllLines.push(mainLine);

    if (line.backgroundVocal !== undefined) {
      const bgLine: AmllLyricLine = toAmllLine(line.backgroundVocal, true, isDuet);
      bgLine.startTime = line.backgroundVocal.startTime;
      bgLine.endTime = line.backgroundVocal.endTime;
      amllLines.push(bgLine);
    }
  }
  return amllLines;
}

// ==================== TTML 生成 ====================
/**
 * 将 AMLL 歌词行数组 + 元数据导出为 TTML 字符串
 */
/** TTML 歌词解析结果（含元数据表） */
export interface AmllTtmlLyricResult {
  lines: AmllLyricLine[];
  metadata: [string, string[]][];
}

/** 解析 TTML 字符串为 AMLL 歌词对象（含元数据表） */
export function amllParseTtmlLyric(ttmlText: string): AmllTtmlLyricResult {
  const result = amllParseTtml(ttmlText);
  const lines = amllTtmlToLyricLines(result);
  const metadata: [string, string[]][] = [];
  const meta = result.metadata;
  if (meta.timingMode !== undefined) {
    const pair: [string, string[]] = ['timingMode', [meta.timingMode]];
    metadata.push(pair);
  }
  if (meta.language !== undefined) {
    const pair: [string, string[]] = ['language', [meta.language]];
    metadata.push(pair);
  }
  const pushArr = (key: string, arr?: string[]): void => {
    if (arr !== undefined && arr.length > 0) {
      const pair: [string, string[]] = [key, arr];
      metadata.push(pair);
    }
  };
  pushArr(V_MUSIC_NAME, meta.title);
  pushArr(V_ARTISTS, meta.artist);
  pushArr(V_ALBUM, meta.album);
  pushArr(V_ISRC, meta.isrc);
  pushArr(V_TTML_AUTHOR_GITHUB, meta.authorIds);
  pushArr(V_TTML_AUTHOR_GITHUB_LOGIN, meta.authorNames);
  if (meta.platformIds !== undefined) {
    meta.platformIds.forEach((value: string[], key: string) => {
      const pair: [string, string[]] = [key, value];
      metadata.push(pair);
    });
  }
  if (meta.rawProperties !== undefined) {
    meta.rawProperties.forEach((value: string[], key: string) => {
      const pair: [string, string[]] = [key, value];
      metadata.push(pair);
    });
  }
  const out: AmllTtmlLyricResult = { lines: lines, metadata: metadata };
  return out;
}


















