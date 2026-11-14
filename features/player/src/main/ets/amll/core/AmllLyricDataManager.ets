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
 * 歌词数据管理器（对应原仓库 packages/core/src/lyric-player/base/lyric-data-manager.ts）
 *
 * 负责：存储原始歌词、深拷贝、应用歌词优化、应用歌词掩码，
 * 并计算是否为动态歌词（逐字歌词）和是否有对唱歌词。
 */
import { AmllLyricLine, AmllLyricWord, AmllOptimizeLyricOptions } from '../model/AmllTypes';
import { amllDeepCloneLines } from '../model/AmllMath';
import { amllOptimizeLyricLines } from './AmllOptimize';
import { AmllLyricDataConfig, AmllMaskObsceneWordsMode } from './AmllConsts';

export class AmllLyricDataManager {
  private rawLines: AmllLyricLine[] = [];
  private processedLines: AmllLyricLine[] = [];
  private isDirty: boolean = true;
  private optimizeOpts: AmllOptimizeLyricOptions = {};
  private maskMode: AmllMaskObsceneWordsMode = AmllMaskObsceneWordsMode.Disabled;
  private maskChar: string = '*';
  private isNonDynamic: boolean = false;
  private hasDuetLine: boolean = false;

  public setOriginalLines(lines: AmllLyricLine[]): void {
    this.rawLines = amllDeepCloneLines(lines);
    this.isDirty = true;
  }

  public setConfig(config: AmllLyricDataConfig): void {
    if (config.optimizeOptions !== undefined) {
      const merged: AmllOptimizeLyricOptions = {};
      if (this.optimizeOpts.normalizeSpaces !== undefined) {
        merged.normalizeSpaces = this.optimizeOpts.normalizeSpaces;
      }
      if (this.optimizeOpts.resetLineTimestamps !== undefined) {
        merged.resetLineTimestamps = this.optimizeOpts.resetLineTimestamps;
      }
      if (this.optimizeOpts.convertExcessiveBackgroundLines !== undefined) {
        merged.convertExcessiveBackgroundLines = this.optimizeOpts.convertExcessiveBackgroundLines;
      }
      if (this.optimizeOpts.syncMainAndBackgroundLines !== undefined) {
        merged.syncMainAndBackgroundLines = this.optimizeOpts.syncMainAndBackgroundLines;
      }
      if (this.optimizeOpts.cleanUnintentionalOverlaps !== undefined) {
        merged.cleanUnintentionalOverlaps = this.optimizeOpts.cleanUnintentionalOverlaps;
      }
      if (this.optimizeOpts.tryAdvanceStartTime !== undefined) {
        merged.tryAdvanceStartTime = this.optimizeOpts.tryAdvanceStartTime;
      }
      if (config.optimizeOptions.normalizeSpaces !== undefined) {
        merged.normalizeSpaces = config.optimizeOptions.normalizeSpaces;
      }
      if (config.optimizeOptions.resetLineTimestamps !== undefined) {
        merged.resetLineTimestamps = config.optimizeOptions.resetLineTimestamps;
      }
      if (config.optimizeOptions.convertExcessiveBackgroundLines !== undefined) {
        merged.convertExcessiveBackgroundLines = config.optimizeOptions.convertExcessiveBackgroundLines;
      }
      if (config.optimizeOptions.syncMainAndBackgroundLines !== undefined) {
        merged.syncMainAndBackgroundLines = config.optimizeOptions.syncMainAndBackgroundLines;
      }
      if (config.optimizeOptions.cleanUnintentionalOverlaps !== undefined) {
        merged.cleanUnintentionalOverlaps = config.optimizeOptions.cleanUnintentionalOverlaps;
      }
      if (config.optimizeOptions.tryAdvanceStartTime !== undefined) {
        merged.tryAdvanceStartTime = config.optimizeOptions.tryAdvanceStartTime;
      }
      this.optimizeOpts = merged;
    }
    this.maskMode = config.maskMode !== undefined ? config.maskMode : this.maskMode;
    const ch: string = config.maskChar !== undefined ? config.maskChar : this.maskChar;
    this.maskChar = ch.charAt(0) !== '' ? ch.charAt(0) : this.maskChar;
    this.isDirty = true;
  }

  public getRawLines(): AmllLyricLine[] {
    return this.rawLines;
  }

  public getProcessedLines(): AmllLyricLine[] {
    this.ensurePipeline();
    return this.processedLines;
  }

  public getIsNonDynamic(): boolean {
    this.ensurePipeline();
    return this.isNonDynamic;
  }

  public getHasDuetLine(): boolean {
    this.ensurePipeline();
    return this.hasDuetLine;
  }

  public getOptimizeOptions(): AmllOptimizeLyricOptions {
    return this.optimizeOpts;
  }

  public getMaskMode(): AmllMaskObsceneWordsMode {
    return this.maskMode;
  }

  public getMaskChar(): string {
    return this.maskChar;
  }

  private ensurePipeline(): void {
    if (!this.isDirty) {
      return;
    }
    this.processPipeline();
    this.isDirty = false;
  }

  private processPipeline(): void {
    this.processedLines = amllDeepCloneLines(this.rawLines);
    amllOptimizeLyricLines(this.processedLines, this.optimizeOpts);

    let checkNonDynamic = true;
    let checkDuet = false;
    for (let i = 0; i < this.processedLines.length; i++) {
      const line = this.processedLines[i];
      if (line.words.length > 1) {
        checkNonDynamic = false;
      }
      if (line.isDuet) {
        checkDuet = true;
      }
      for (let w = 0; w < line.words.length; w++) {
        this.applyMask(line.words[w]);
      }
    }
    this.isNonDynamic = checkNonDynamic && this.processedLines.length > 0;
    this.hasDuetLine = checkDuet;
  }

  private applyMask(word: AmllLyricWord): void {
    if (word.obscene !== true || this.maskMode === AmllMaskObsceneWordsMode.Disabled) {
      return;
    }
    const text: string = word.word;
    const maskChar: string = this.maskChar;
    if (this.maskMode === AmllMaskObsceneWordsMode.FullMask) {
      word.word = text.replace(/\S/g, maskChar);
    } else if (this.maskMode === AmllMaskObsceneWordsMode.PartialMask) {
      const trimmed: string = text.trim();
      if (trimmed.length <= 2) {
        word.word = text.replace(/\S/g, maskChar);
      } else {
        const startPos = text.indexOf(trimmed);
        const endPos = startPos + trimmed.length - 1;
        word.word =
          text.slice(0, startPos + 1) +
          text.slice(startPos + 1, endPos).replace(/\S/g, maskChar) +
          text.slice(endPos);
      }
    }
  }
}
