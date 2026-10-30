/*
 * Copyright (c) 2026 RzdPai
 *
 * 音频音效模型 + FFmpeg `af` 链构建（mpv 与内核共用一份实现）。
 *
 * 为什么集中在这里：`af` 链既要在播放开始前下发（内核 `applyTuning`），
 * 又要在"播放中改设置"时判断是否变化（`MediaService.refreshTuning`）。
 * 两处必须用**完全相同的字符串**，否则去重失效、还会重复下发。
 *
 * 当前支持的音效（全部是 FFmpeg 自带滤镜，libmpv 里可用）：
 * - 5 段均衡器：`equalizer=f=<hz>:t=o:w=1:g=<dB>`
 * - 升降调：`rubberband=pitch=<2^(n/12)>`（没编 rubberband 时退回 asetrate+atempo）
 * - 低音增强：`bass=g=<dB>:f=110:w=0.6`
 * - 立体声增强：`extrastereo=m=<1.0~2.0>`
 * - 人声消除：`pan=stereo|c0=c0-c1|c1=c1-c0`
 * - 夜间模式（动态压缩）：`dynaudnorm=f=200:g=15`
 * - 混响：`aecho=0.8:0.88:60:0.4`
 *
 * 排查日志关键字：`RzdAf`。
 */

/** 音效开关集合（全部为可选，默认全关）。 */
export class AudioEffects {
  /** 低音增强（dB，0=关）。 */
  bassDb: number = 0;
  /** 立体声增强倍数（1.0=关，1.0~2.0）。 */
  stereoWiden: number = 1.0;
  /** 人声消除。 */
  vocalRemove: boolean = false;
  /** 夜间模式（动态压缩，音量起伏变小）。 */
  nightMode: boolean = false;
  /** 混响。 */
  reverb: boolean = false;

  /** @returns 是否有任何音效开启。 */
  anyOn(): boolean {
    return this.bassDb !== 0 || this.stereoWiden !== 1.0 || this.vocalRemove ||
      this.nightMode || this.reverb;
  }
}

/** EQ 频段（Hz），与播放设置面板一致。 */
export const AF_EQ_BANDS: number[] = [60, 230, 910, 3600, 14000];

/**
 * 组出完整的 `af` 链。
 * @param eqGains 5 段 EQ 增益（dB）。
 * @param pitchSemitones 升降调（半音）。
 * @param effects 音效开关。
 * @returns 逗号分隔的滤镜链；全默认时返回空串（表示"清空滤镜"）。
 */
export function buildAfChain(eqGains: number[], pitchSemitones: number, effects: AudioEffects): string {
  const out: string[] = [];
  for (let i: number = 0; i < AF_EQ_BANDS.length && i < eqGains.length; i++) {
    if (eqGains[i] === 0) {
      continue;
    }
    out.push('equalizer=f=' + AF_EQ_BANDS[i].toString() + ':t=o:w=1:g=' + eqGains[i].toFixed(1));
  }
  if (effects.bassDb !== 0) {
    out.push('bass=g=' + effects.bassDb.toFixed(1) + ':f=110:w=0.6');
  }
  if (pitchSemitones !== 0) {
    out.push('rubberband=pitch=' + Math.pow(2, pitchSemitones / 12).toFixed(4));
  }
  if (effects.stereoWiden !== 1.0) {
    out.push('extrastereo=m=' + effects.stereoWiden.toFixed(2));
  }
  if (effects.vocalRemove) {
    out.push('pan=stereo|c0=c0-c1|c1=c1-c0');
  }
  if (effects.nightMode) {
    out.push('dynaudnorm=f=200:g=15');
  }
  if (effects.reverb) {
    out.push('aecho=0.8:0.88:60:0.4');
  }
  return out.join(',');
}

/** 音效 → JSON（持久化用）。 */
export function effectsToJson(effects: AudioEffects): string {
  return JSON.stringify({
    bassDb: effects.bassDb,
    stereoWiden: effects.stereoWiden,
    vocalRemove: effects.vocalRemove,
    nightMode: effects.nightMode,
    reverb: effects.reverb
  });
}

/**
 * JSON → 音效（容错：字段缺失/类型不对一律回默认）。
 * @param raw 持久化字符串。
 */
export function effectsFromJson(raw: string): AudioEffects {
  const out: AudioEffects = new AudioEffects();
  if (raw === undefined || raw === null || raw.length === 0) {
    return out;
  }
  try {
    const obj: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
    const bass: number = Number(obj['bassDb']);
    if (!Number.isNaN(bass)) {
      out.bassDb = Math.max(-12, Math.min(12, bass));
    }
    const widen: number = Number(obj['stereoWiden']);
    if (!Number.isNaN(widen) && widen >= 1.0) {
      out.stereoWiden = Math.min(2.0, widen);
    }
    out.vocalRemove = obj['vocalRemove'] === true;
    out.nightMode = obj['nightMode'] === true;
    out.reverb = obj['reverb'] === true;
  } catch (err) {
  }
  return out;
}
