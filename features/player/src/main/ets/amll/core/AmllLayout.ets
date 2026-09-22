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
 * 排版计算器（对应原仓库 packages/core/src/lyric-player/base/layout.ts 的忠实移植）
 */
import { AmllLayoutAlignAnchor } from './AmllConsts';
import { AmllPlayerInterlude } from './AmllTimeline';

/** 布局对齐的静态配置项 */
export interface AmllLayoutConfig {
  alignAnchor: AmllLayoutAlignAnchor;
  /** 0.0 - 1.0 的视口相对位置 */
  alignPosition: number;
  /** 视口上下额外保留的预渲染距离，单位为像素 */
  overscanPx: number;
}

/** 滚动边界 */
export interface AmllScrollBounds {
  min: number;
  max: number;
}

/** beginFrame 返回结果 */
export interface AmllFrameResult {
  bounds: AmllScrollBounds;
  session: AmllLayoutFrameSession;
}

/** 每一帧都可能变化的排版上下文状态 */
export interface AmllLayoutFrameContext {
  containerHeight: number;
  scrollOffset: number;
  target: AmllFocalTarget;
  bottomLineHeight: number;
  interlude?: AmllFrameInterlude;
}

/** 间奏点排版信息 */
export interface AmllFrameInterlude {
  totalHeight: number;
  anchorIndex: number;
}

/** 单行歌词的渲染几何指令 */
export interface AmllRenderInstruction {
  y: number;
  height: number;
  isInViewport: boolean;
}

/** 排版计算返回的复合结果 */
export interface AmllLayoutResult {
  lineCount: number;
  lineInstructions: AmllRenderInstruction[];
  hasInterlude: boolean;
  interludeY: number;
  bottomLineY: number;
  isBottomLineInViewport: boolean;
}

/** 当前对齐的目标类型 */
export type AmllFocalTargetType = 'line' | 'interlude' | 'bottom';

/** 决定排版原点焦点的目标 */
export type AmllFocalTarget =
  | AmllLineTarget
  | AmllInterludeTarget
  | AmllBottomTarget;

export interface AmllLineTarget {
  type: 'line';
  index: number;
}

export interface AmllInterludeTarget {
  type: 'interlude';
  anchorIndex: number;
}

export interface AmllBottomTarget {
  type: 'bottom';
}

interface AmllResolvedLayoutMetrics {
  isValid: boolean;
  focalTopY: number;
  anchorOffset: number;
  interludeTotalHeight: number;
  activeInterludeAnchor: number | undefined;
}

export interface AmllLayoutFrameSession extends AmllResolvedLayoutMetrics {
  containerHeight: number;
  alignPosition: number;
  overscanPx: number;
  bottomLineHeight: number;
}

export class AmllLayoutCalculator {
  private prefixSums: Float64Array = new Float64Array(0);
  private heights: Float64Array = new Float64Array(0);
  private isMeasured: Uint8Array = new Uint8Array(0);
  private instructionPool: AmllRenderInstruction[] = [];
  private isPrefixSumDirty: boolean = true;

  private resolvedMetrics: AmllResolvedLayoutMetrics = {
    isValid: false,
    focalTopY: 0,
    anchorOffset: 0,
    interludeTotalHeight: 0,
    activeInterludeAnchor: undefined
  };

  private layoutResult: AmllLayoutResult = {
    lineCount: 0,
    lineInstructions: this.instructionPool,
    bottomLineY: 0,
    isBottomLineInViewport: false,
    hasInterlude: false,
    interludeY: 0
  };

  private lyricCount: number = 0;
  private totalLyricHeight: number = 0;

  public initHeights(count: number, defaultHeight: number): void {
    this.lyricCount = count;
    this.resetLayoutResult();
    if (this.prefixSums.length < count + 1) {
      this.prefixSums = new Float64Array(count + 1);
      this.heights = new Float64Array(count);
      this.isMeasured = new Uint8Array(count);
    } else {
      this.prefixSums.fill(0);
    }
    for (let i = 0; i < count; i++) {
      this.heights[i] = defaultHeight;
      this.isMeasured[i] = 0;
    }
    this.isPrefixSumDirty = true;
    const currentPoolSize = this.instructionPool.length;
    if (count > currentPoolSize) {
      for (let i = currentPoolSize; i < count; i++) {
        this.instructionPool.push({ y: 0, height: 0, isInViewport: false });
      }
    }
  }

  public getLineHeight(index: number): number {
    if (index < 0 || index >= this.lyricCount) {
      return 0;
    }
    this.ensurePrefixSums();
    return this.prefixSums[index + 1] - this.prefixSums[index];
  }

  public setLineHeight(index: number, height: number): void {
    if (index < 0 || index >= this.lyricCount) {
      return;
    }
    if (this.heights[index] !== height || this.isMeasured[index] === 0) {
      this.heights[index] = height;
      this.isMeasured[index] = 1;
      this.isPrefixSumDirty = true;
    }
  }

  public updateUnmeasuredHeights(defaultHeight: number): void {
    let changed = false;
    for (let i = 0; i < this.lyricCount; i++) {
      if (this.isMeasured[i] === 0 && this.heights[i] !== defaultHeight) {
        this.heights[i] = defaultHeight;
        changed = true;
      }
    }
    if (changed) {
      this.isPrefixSumDirty = true;
    }
  }

  public beginFrame(
    ctx: AmllLayoutFrameContext,
    config: AmllLayoutConfig
  ): AmllFrameResult {
    this.ensurePrefixSums();
    const metrics = this.resolveLayoutMetrics(ctx, config);
    const session: AmllLayoutFrameSession = {
      isValid: metrics.isValid,
      focalTopY: metrics.focalTopY,
      anchorOffset: metrics.anchorOffset,
      interludeTotalHeight: metrics.interludeTotalHeight,
      activeInterludeAnchor: metrics.activeInterludeAnchor,
      containerHeight: ctx.containerHeight,
      alignPosition: config.alignPosition,
      overscanPx: config.overscanPx,
      bottomLineHeight: ctx.bottomLineHeight
    };
    if (!metrics.isValid) {
      const emptyBounds: AmllScrollBounds = { min: 0, max: 0 };
      const result: AmllFrameResult = { bounds: emptyBounds, session: session };
      return result;
    }
    const focalTopY = metrics.focalTopY;
    const anchorOffset = metrics.anchorOffset;
    const interludeTotalHeight = metrics.interludeTotalHeight;
    const activeInterludeAnchor = metrics.activeInterludeAnchor;

    const minOffset = Math.min(0, -focalTopY);
    const basePosWithoutScroll =
      -focalTopY + ctx.containerHeight * config.alignPosition - anchorOffset;

    let totalContentHeight = this.totalLyricHeight;
    if (activeInterludeAnchor !== undefined) {
      totalContentHeight += interludeTotalHeight;
    }
    const rawMaxOffset = basePosWithoutScroll + totalContentHeight - ctx.containerHeight / 2;
    const maxOffset = Math.max(0, rawMaxOffset);

    const bounds: AmllScrollBounds = { min: minOffset, max: maxOffset };
    const result: AmllFrameResult = { bounds: bounds, session: session };
    return result;
  }

  public commit(
    session: AmllLayoutFrameSession,
    scrollOffset: number
  ): AmllLayoutResult {
    this.ensurePrefixSums();
    if (!session.isValid) {
      return this.resetLayoutResult();
    }
    this.layoutResult.lineCount = this.lyricCount;

    const focalTopY = session.focalTopY;
    const anchorOffset = session.anchorOffset;
    const interludeTotalHeight = session.interludeTotalHeight;
    const activeInterludeAnchor = session.activeInterludeAnchor;
    const containerHeight = session.containerHeight;
    const alignPosition = session.alignPosition;
    const overscanPx = session.overscanPx;
    const bottomLineHeight = session.bottomLineHeight;

    const viewportStartY =
      containerHeight * alignPosition - anchorOffset - scrollOffset - focalTopY;
    const motionBuffer = containerHeight * 0.4;
    const viewportTopBound = -overscanPx - motionBuffer;
    const viewportBottomBound = containerHeight + overscanPx + motionBuffer;

    for (let i = 0; i < this.lyricCount; i++) {
      const instruction = this.instructionPool[i];
      let lineY = viewportStartY + this.prefixSums[i];
      const lineH = this.prefixSums[i + 1] - this.prefixSums[i];
      if (activeInterludeAnchor !== undefined && i > activeInterludeAnchor) {
        lineY += interludeTotalHeight;
      }
      instruction.y = lineY;
      instruction.height = lineH;
      instruction.isInViewport =
        lineY <= viewportBottomBound && lineY + lineH >= viewportTopBound;
    }

    if (activeInterludeAnchor !== undefined) {
      this.layoutResult.hasInterlude = true;
      this.layoutResult.interludeY =
        viewportStartY + this.prefixSums[activeInterludeAnchor + 1];
    } else {
      this.layoutResult.hasInterlude = false;
      this.layoutResult.interludeY = 0;
    }

    let bottomY = viewportStartY + this.totalLyricHeight;
    if (activeInterludeAnchor !== undefined) {
      bottomY += interludeTotalHeight;
    }
    this.layoutResult.bottomLineY = bottomY;
    this.layoutResult.isBottomLineInViewport =
      bottomY <= viewportBottomBound && bottomY + bottomLineHeight >= viewportTopBound;

    return this.layoutResult;
  }

  public static resolveInterludeAnchorIndex(
    interlude: AmllPlayerInterlude | undefined,
    focalTarget: AmllFocalTarget
  ): number | undefined {
    if (interlude !== undefined) {
      return interlude.anchorLineIndex;
    }
    if (focalTarget.type === 'interlude') {
      return focalTarget.anchorIndex;
    }
    return undefined;
  }

  private ensurePrefixSums(): void {
    if (!this.isPrefixSumDirty) {
      return;
    }
    let sum = 0;
    this.prefixSums[0] = 0;
    for (let i = 0; i < this.lyricCount; i++) {
      sum += this.heights[i];
      this.prefixSums[i + 1] = sum;
    }
    this.totalLyricHeight = sum;
    this.isPrefixSumDirty = false;
  }

  private resolveLayoutMetrics(
    ctx: AmllLayoutFrameContext,
    config: AmllLayoutConfig
  ): AmllResolvedLayoutMetrics {
    const interludeTotalHeight: number = ctx.interlude !== undefined ? ctx.interlude.totalHeight : 0;
    const activeInterludeAnchor: number | undefined =
      ctx.interlude !== undefined ? ctx.interlude.anchorIndex : undefined;

    this.resolvedMetrics.interludeTotalHeight = interludeTotalHeight;
    this.resolvedMetrics.activeInterludeAnchor = activeInterludeAnchor;

    if (
      this.lyricCount === 0 ||
      (ctx.target.type === 'line' &&
        (ctx.target.index < 0 || ctx.target.index >= this.lyricCount)) ||
      (ctx.target.type === 'interlude' &&
        (ctx.target.anchorIndex < -1 || ctx.target.anchorIndex >= this.lyricCount - 1))
    ) {
      this.resolvedMetrics.isValid = false;
      this.resolvedMetrics.focalTopY = 0;
      this.resolvedMetrics.anchorOffset = 0;
      return this.resolvedMetrics;
    }

    this.updateFocalMetrics(
      ctx.target,
      interludeTotalHeight,
      activeInterludeAnchor,
      ctx.bottomLineHeight,
      config
    );
    this.resolvedMetrics.isValid = true;
    return this.resolvedMetrics;
  }

  private updateFocalMetrics(
    target: AmllFocalTarget,
    interludeTotalHeight: number,
    activeInterludeAnchor: number | undefined,
    bottomLineHeight: number,
    config: AmllLayoutConfig
  ): void {
    let focalTopY = 0;
    let targetHeight = 0;

    if (target.type === 'line') {
      focalTopY = this.prefixSums[target.index];
      if (
        activeInterludeAnchor !== undefined &&
        target.index > activeInterludeAnchor
      ) {
        focalTopY += interludeTotalHeight;
      }
      targetHeight = this.prefixSums[target.index + 1] - this.prefixSums[target.index];
    } else if (target.type === 'interlude') {
      focalTopY = this.prefixSums[target.anchorIndex + 1];
      targetHeight = interludeTotalHeight;
    } else {
      focalTopY = this.totalLyricHeight;
      if (activeInterludeAnchor !== undefined) {
        focalTopY += interludeTotalHeight;
      }
      targetHeight = bottomLineHeight;
    }

    this.resolvedMetrics.focalTopY = focalTopY;
    this.resolvedMetrics.anchorOffset = this.calculateAnchorOffset(
      config.alignAnchor,
      targetHeight
    );
  }

  private calculateAnchorOffset(
    alignAnchor: AmllLayoutAlignAnchor,
    targetHeight: number
  ): number {
    if (targetHeight <= 0) {
      return 0;
    }
    switch (alignAnchor) {
      case AmllLayoutAlignAnchor.Top:
        return 0;
      case AmllLayoutAlignAnchor.Center:
        return targetHeight / 2;
      case AmllLayoutAlignAnchor.Bottom:
        return targetHeight;
      default:
        return targetHeight / 2;
    }
  }

  private resetLayoutResult(): AmllLayoutResult {
    this.layoutResult.lineCount = 0;
    this.layoutResult.hasInterlude = false;
    this.layoutResult.interludeY = 0;
    this.layoutResult.bottomLineY = 0;
    this.layoutResult.isBottomLineInViewport = false;
    for (let i = 0; i < this.instructionPool.length; i++) {
      this.instructionPool[i].isInViewport = false;
      this.instructionPool[i].y = 0;
      this.instructionPool[i].height = 0;
    }
    return this.layoutResult;
  }
}
