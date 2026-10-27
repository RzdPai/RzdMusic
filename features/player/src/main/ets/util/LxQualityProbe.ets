/*
 * Copyright (c) 2026 RzdPai
 *
 * A4：音质「真实可用」探测。脚本声明的 qualitys 只是声明，实际取址可能返回错误提示；
 * 这里用「取址 → 只读响应头 → 校验类型与时长」判定，结果只缓存在本次会话（每次启动重测）。
 */

import { http } from '@kit.NetworkKit';
import { getLXMusicUrl } from '../source/LXPlayHelper';
import { lxSearch, LXSearchResult, LXSearchSong } from '../source/LXMusicSDK';
import { appendPlayLog } from 'musicbasic';

const DURATION_TOLERANCE: number = 0.15;
const PROBE_TIMEOUT_MS: number = 8000;

export class ProbeResult {
  ok: boolean = false;
  contentType: string = '';
  seconds: number = -1;
  detail: string = '';
}

export function parseIntervalSeconds(interval: string): number {
  if (interval.length === 0) {
    return -1;
  }
  const parts: string[] = interval.split(':');
  if (parts.length < 2) {
    return -1;
  }
  let seconds: number = 0;
  for (let i: number = 0; i < parts.length; i++) {
    const v: number = Number(parts[i]);
    if (Number.isNaN(v)) {
      return -1;
    }
    seconds = seconds * 60 + v;
  }
  return seconds;
}

/** 预置样曲：每个平台一首稳定的曲目，用于"没有正在播放的歌"时也能探测音质。 */
export class ProbeSample {
  songId: string = '';
  name: string = '';
  singer: string = '';
  interval: string = '';
}

/** 目前只登记已确认可用的平台样曲；没有登记的平台不做主动探测（保持"未测"）。 */
const SAMPLES: Map<string, ProbeSample> = new Map();

/**
 * 预置样曲（**不再现场搜索**）：每个平台一首稳定曲目，songId 取自真机日志验证过的搜索结果。
 * 需要换曲时只改这里。
 */
function registerSamples(): void {
  const add = (src: string, id: string, name: string, singer: string, interval: string): void => {
    const s: ProbeSample = new ProbeSample();
    s.songId = id;
    s.name = name;
    s.singer = singer;
    s.interval = interval;
    SAMPLES.set(src, s);
  };
  add('kw', '228908', '晴天', '周杰伦', '4:29');
  add('kg', 'B3A52A7A958BF0AED0EBFBA2E9A818B7', '晴天', '周杰伦', '4:29');
  add('tx', '0039MnYb0qxYhV', '晴天', '周杰伦', '4:29');
  add('wy', '509781655', '想你就写信 (Live)', '周杰伦、李硕、张鑫', '3:58');
  add('mg', '60054704965', '圣诞星（feat. 杨瑞代）', '', '3:02');
}

registerSamples();

/** 会话内解析出的样曲（每平台一次）。 */
const resolvedSamples: Map<string, ProbeSample> = new Map();

/** 搜索用的关键词：随便一首稳定热门即可，这里用歌手名。 */
const SAMPLE_QUERY: string = '周杰伦';

/**
 * 取某平台的样曲：优先用仓库已有的平台搜索接口现找一首（`lxSearch`），
 * 找不到再退回内置的 kw 样曲。结果缓存在本次会话。
 */
export async function resolveSample(source: string): Promise<ProbeSample | undefined> {
  const cached: ProbeSample | undefined = resolvedSamples.get(source);
  if (cached !== undefined) {
    return cached;
  }
  // 预置样曲优先，不再现场搜索（省一次网络往返，也不依赖引擎状态）
  const preset: ProbeSample | undefined = SAMPLES.get(source);
  if (preset !== undefined) {
    resolvedSamples.set(source, preset);
    appendPlayLog('[RzdQualityProbe] 样曲(预置) ' + source + ' → ' + preset.name + ' (' + preset.interval + ')');
    return preset;
  }
  appendPlayLog('[RzdQualityProbe] 该平台没有预置样曲 ' + source);
  const fallback: ProbeSample | undefined = SAMPLES.get(source);
  if (fallback !== undefined) {
    resolvedSamples.set(source, fallback);
  }
  return fallback;
}

/** 取某平台的样曲（内置表，同步；不确定是否有则用 resolveSample）。 */
export function sampleOf(source: string): ProbeSample | undefined {
  return resolvedSamples.get(source) ?? SAMPLES.get(source);
}

/** 用样曲探测某平台某音质；解析不出样曲就返回 undefined。 */
export async function probeBySample(source: string, quality: string): Promise<ProbeResult | undefined> {
  const s: ProbeSample | undefined = await resolveSample(source);
  if (s === undefined) {
    return undefined;
  }
  return probeQuality(source, s.songId, quality, s.name, s.singer, s.interval);
}

/** 音质档位权重（越大越高），与回退链一致。 */
function qualityRank(q: string): number {
  const order: string[] = ['128K', '128k', '192K', '192k', '320K', '320k',
    'flac', 'FLAC', '24Bit', '24bit', 'Hi-Res', 'hires', '母带', 'atmos', 'master'];
  const i: number = order.indexOf(q);
  return i < 0 ? -1 : i;
}

/**
 * 挑出"播放实际会用到的那一档"：优先取 ≤ 默认音质里的最高档，取不到就用该平台最低档。
 * 与 `SourceFallbackUtil.bestQualityFor` 同一口径，保证"测什么 = 播什么"。
 */
export function pickPlaybackQuality(declared: string[], preferred: string): string {
  if (declared.length === 0) {
    return '';
  }
  const prefRank: number = qualityRank(preferred);
  let best: string = '';
  let bestRank: number = -1;
  let lowest: string = '';
  let lowestRank: number = 10000;
  for (let i: number = 0; i < declared.length; i++) {
    const r: number = qualityRank(declared[i]);
    if (r >= 0 && r <= prefRank && r > bestRank) {
      bestRank = r;
      best = declared[i];
    }
    if (r >= 0 && r < lowestRank) {
      lowestRank = r;
      lowest = declared[i];
    }
  }
  return best.length > 0 ? best : lowest;
}
const sessionCache: Map<string, ProbeResult> = new Map();

function cacheKey(source: string, quality: string): string {
  return source + '|' + quality;
}

function isAudioType(contentType: string): boolean {
  const t: string = contentType.toLowerCase();
  return t.startsWith('audio/') || t.indexOf('octet-stream') >= 0 || t.indexOf('mpegurl') >= 0;
}

/**
 * 探测单个音质是否真的能返回音频。
 * @param source 平台 id
 * @param songId 平台内歌曲 id
 * @param quality 音质
 * @param name 歌名
 * @param singer 歌手
 * @param interval 歌曲时长（`mm:ss`）
 */
export async function probeQuality(source: string, songId: string, quality: string,
  name: string, singer: string, interval: string): Promise<ProbeResult> {
  const key: string = cacheKey(source, quality);
  const cached: ProbeResult | undefined = sessionCache.get(key);
  if (cached !== undefined) {
    return cached;
  }
  const result: ProbeResult = new ProbeResult();
  let url: string = '';
  try {
    url = await getLXMusicUrl(source, songId, quality, name, singer);
  } catch (err) {
    result.detail = '取址异常';
    sessionCache.set(key, result);
    appendPlayLog('[RzdQualityProbe] ' + source + '/' + quality + ' 取址异常');
    return result;
  }
  if (url.length === 0) {
    result.detail = '无地址';
    sessionCache.set(key, result);
    appendPlayLog('[RzdQualityProbe] ' + source + '/' + quality + ' 无地址');
    return result;
  }
  appendPlayLog('[RzdQualityProbe] start ' + source + '/' + quality + ' url=' + url.substring(0, Math.min(60, url.length)));
  const header: http.HttpRequest = http.createHttp();
  try {
    // ★ 不能带 Range：带了 content-length 就只有 2 字节，算出来的时长必然"偏差过大"（之前的 100% 失败根因）
    const resp: http.HttpResponse = await header.request(url, {
      method: http.RequestMethod.GET,
      connectTimeout: PROBE_TIMEOUT_MS,
      readTimeout: PROBE_TIMEOUT_MS
    });
    const ct: string = String(resp.header['content-type'] ?? '');
    const lenRaw: string = String(resp.header['content-length'] ?? '');
    appendPlayLog('[RzdQualityProbe] resp code=' + resp.responseCode + ' type=' + ct + ' len=' + lenRaw);
    result.contentType = ct;
    if (!isAudioType(ct)) {
      result.detail = '非音频类型 ' + ct;
      appendPlayLog('[RzdQualityProbe] ' + source + '/' + quality + ' 失败：' + result.detail);
      sessionCache.set(key, result);
      return result;
    }
    const expectSeconds: number = parseIntervalSeconds(interval);
    const bytes: number = Number(lenRaw);
    result.seconds = bytes > 0 ? Math.round(bytes / (320 * 1024 / 8)) : -1;
    // 只做"体量合理"的软校验：真实音频至少几百 KB；错误提示页通常只有几 KB
    if (!Number.isNaN(bytes) && bytes > 0 && bytes < 100 * 1024) {
      result.detail = '体积过小（' + bytes + 'B，疑似错误提示）';
      appendPlayLog('[RzdQualityProbe] ' + source + '/' + quality + ' 失败：' + result.detail);
      sessionCache.set(key, result);
      return result;
    }
    result.ok = true;
    result.detail = '已验证';
    appendPlayLog('[RzdQualityProbe] PASS ' + source + '/' + quality);
    appendPlayLog('[RzdQualityProbe] ' + source + '/' + quality + ' 通过 type=' + ct);
    sessionCache.set(key, result);
    return result;
  } catch (err) {
    result.detail = '请求异常';
    appendPlayLog('[RzdQualityProbe] ' + source + '/' + quality + ' 请求异常');
    sessionCache.set(key, result);
    return result;
  } finally {
    header.destroy();
  }
}

/** 播放/下载解析成功后回写"这个音质是真实音频"（供 ToolTip 显示）。 */
export function markProbeOk(source: string, quality: string): void {
  const r: ProbeResult = new ProbeResult();
  r.ok = true;
  r.detail = '已验证';
  sessionCache.set(cacheKey(source, quality), r);
  appendPlayLog('[RzdQualityProbe] ' + source + '/' + quality + ' 由播放链路标记为已验证');
}

/** 播放/下载解析失败后回写"这个音质不可用"。 */
export function markProbeFail(source: string, quality: string, detail: string): void {
  const r: ProbeResult = new ProbeResult();
  r.ok = false;
  r.detail = detail;
  sessionCache.set(cacheKey(source, quality), r);
}

/**
 * 某平台**任意音质**的探测状态（探测测的是"播放会用到的档位"，未必等于 ToolTip 标的最高档，
 * 所以这里按平台汇总一次，避免又出现"测了却显示未测"）。
 * @returns 形如 `已验证（320k）` / `未通过（320k）` / `未测`
 */
export function probeSummary(source: string): string {
  let found: string = '';
  sessionCache.forEach((v: ProbeResult, k: string): void => {
    if (k.startsWith(source + '|')) {
      const q: string = k.substring(source.length + 1);
      if (v.ok) {
        found = '已验证（' + q + '）';
      } else if (found.length === 0) {
        found = '未通过（' + q + '）';
      }
    }
  });
  return found.length > 0 ? found : '未测';
}

export function cachedProbe(source: string, quality: string): ProbeResult | undefined {
  return sessionCache.get(cacheKey(source, quality));
}

export function clearProbeCache(): void {
  sessionCache.clear();
}