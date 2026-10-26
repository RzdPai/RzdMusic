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

function registerSamples(): void {
  const kw: ProbeSample = new ProbeSample();
  kw.songId = '228908';
  kw.name = '七里香';
  kw.singer = '周杰伦';
  kw.interval = '04:59';
  SAMPLES.set('kw', kw);
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
  try {
    const res: LXSearchResult = await lxSearch(source, SAMPLE_QUERY, 1, 5);
    for (let i: number = 0; i < res.list.length; i++) {
      const song: LXSearchSong = res.list[i];
      if (song.songId.length === 0 || song.interval.length === 0) {
        continue;
      }
      const s: ProbeSample = new ProbeSample();
      s.songId = song.songId;
      s.name = song.name;
      s.singer = song.singer;
      s.interval = song.interval;
      resolvedSamples.set(source, s);
      appendPlayLog('[RzdQualityProbe] 样曲 ' + source + ' → ' + s.name + '/' + s.singer + ' (' + s.interval + ')');
      return s;
    }
    appendPlayLog('[RzdQualityProbe] 样曲解析失败（无可用结果）' + source);
  } catch (err) {
    appendPlayLog('[RzdQualityProbe] 样曲解析异常 ' + source);
  }
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
  const header: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await header.request(url, {
      method: http.RequestMethod.GET,
      header: { 'Range': 'bytes=0-1' },
      connectTimeout: PROBE_TIMEOUT_MS,
      readTimeout: PROBE_TIMEOUT_MS
    });
    const ct: string = String(resp.header['content-type'] ?? '');
    const lenRaw: string = String(resp.header['content-length'] ?? '');
    result.contentType = ct;
    if (!isAudioType(ct)) {
      result.detail = '非音频类型 ' + ct;
      appendPlayLog('[RzdQualityProbe] ' + source + '/' + quality + ' 失败：' + result.detail);
      sessionCache.set(key, result);
      return result;
    }
    const expectSeconds: number = parseIntervalSeconds(interval);
    const bytes: number = Number(lenRaw);
    if (expectSeconds > 0 && !Number.isNaN(bytes) && bytes > 0) {
      // 最保守码率（320kbps）估算最短应有长度，明显短于歌曲时长即判为错误提示
      const minSeconds: number = bytes / (320 * 1024 / 8);
      result.seconds = Math.round(minSeconds);
      if (minSeconds < expectSeconds * (1 - DURATION_TOLERANCE)) {
        result.detail = '时长偏差过大（' + result.seconds + 's vs ' + expectSeconds + 's）';
        appendPlayLog('[RzdQualityProbe] ' + source + '/' + quality + ' 失败：' + result.detail);
        sessionCache.set(key, result);
        return result;
      }
    }
    result.ok = true;
    result.detail = '已验证';
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

export function cachedProbe(source: string, quality: string): ProbeResult | undefined {
  return sessionCache.get(cacheKey(source, quality));
}

export function clearProbeCache(): void {
  sessionCache.clear();
}