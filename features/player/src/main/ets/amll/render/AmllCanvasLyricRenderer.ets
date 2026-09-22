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
 * AMLL Canvas 渲染器。
 *
 * 每帧读取 AmllLyricPlayerEngine 的状态，用 Canvas 2D 还原 AMLL 的 DOM 渲染效果：
 * - 逐词渐变扫描高亮（对应 CSS mask-image 渐变遮罩的 calc 后备方案）
 * - 强调效果（逐字符缩放/位移/辉光，对应 Web Animation API 的关键帧）
 * - 漂浮动画（对应 composite: add 的 float 动画）
 * - 距离模糊（对应 filter: blur）
 * - 背景人声行滑动（对应 bgWrapper 的 slideY/scale）
 * - 间奏点呼吸动画
 */
import {
  AmllEmpChar,
  AmllGroupState,
  AmllLineRenderState,
  AmllLyricPlayerEngine,
  AmllWordAtom
} from '../core/AmllLyricPlayerEngine';
import {
  amllClamp,
  amllClamp01,
  amllSplitGraphemes
} from '../model/AmllMath';
import { AmllLyricWord } from '../model/AmllTypes';
import { AmllChildNodeInfo, amllCalcBalancedBreaks } from '../core/AmllLineBreak';

/** 渲染样式配置 */
export interface AmllRenderStyle {
  /** 主歌词字号（vp） */
  fontSize: number;
  /** 字体族 */
  fontFamily: string;
  /** 主歌词字体粗细（canvas 格式，如 'Medium' 或 'Bold'） */
  fontWeight: string;
  /** 翻译/音译行字体粗细（比主行细） */
  subLineWeight: string;
  /** 文本颜色（hex） */
  textColor: string;
  /** 强调辉光颜色（hex） */
  glowColor: string;
  /** 歌词列宽度比例（对应 --amll-lp-line-width-aspect，默认 0.8） */
  lineWidthAspect: number;
  /** 左右内边距（em 倍数，对应 --lyric-line-padding-x） */
  paddingXEm: number;
  /** 背景人声行字号比例 */
  bgLineScale: number;
  /** 翻译/音译行字号比例 */
  subLineScale: number;
  /** 是否显示翻译/罗马音子行（关闭时子行不参与测量与绘制，行高收缩） */
  showSubLyric: boolean;
  /** 歌词行水平居中（对唱行保持左右布局） */
  lyricCenter: boolean;
}

interface AmllMeasuredChar {
  char: string;
  width: number;
}

interface AmllMeasuredWord {
  atom: AmllWordAtom;
  width: number;
  chars: AmllMeasuredChar[];
  /** 该词在所属 chunk 中的全局字符起始序号 */
  charStartIndex: number;
  /** 超宽单词拆分后的片段文本（未拆分为 undefined） */
  clipText?: string;
  /** 是否属于强调 chunk（测量时确定，绘制直接使用，避免每帧查 chunkMap） */
  isEmpChunk: boolean;
}

/** 逐字罗马音单词（含测量宽度与折行标记） */
interface AmllSubWord {
  word: AmllLyricWord;
  width: number;
  isNewRow: boolean;
}

/** 一行测量结果 */
interface AmllMeasuredLine {
  words: AmllMeasuredWord[];
  breaks: number[];
  mainHeight: number;
  totalHeight: number;
  bgHeight: number;
  cachedTranslationLines?: string[];
  cachedRomanSubWords?: AmllSubWord[][];
  /** 罗马音无逐字词时的整行折行缓存（独立于翻译缓存，防止误显示成翻译） */
  cachedRomanPlainLines?: string[];
  /** 每个词的绘制位置（测量时缓存，避免每帧重算布局） */
  positions: AmllWordPos[];
  /** 罗马音各行宽度（测量时缓存） */
  romanRowWidths?: number[];
}

interface AmllMeasuredGroup {
  main: AmllMeasuredLine;
  bg?: AmllMeasuredLine;
}

/** 单词布局位置 */
interface AmllWordPos {
  x: number;
  row: number;
}

const RGBA_RE: RegExp = new RegExp('^#([0-9a-fA-F]{6})$');

function hexToRgba(hex: string, alpha: number): string {
  const m = hex.match(RGBA_RE);
  if (m === null) {
    return `rgba(255, 255, 255, ${alpha})`;
  }
  const r = Number.parseInt(m[1].substring(0, 2), 16);
  const g = Number.parseInt(m[1].substring(2, 4), 16);
  const b = Number.parseInt(m[1].substring(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}
export class AmllCanvasLyricRenderer {
  private ctx: CanvasRenderingContext2D;
  private engine: AmllLyricPlayerEngine;
  private style: AmllRenderStyle;
  private measured: AmllMeasuredGroup[] = [];
  private containerWidth: number = 0;
  private containerHeight: number = 0;
  private contentWidth: number = 0;
  private padX: number = 0;
  private hasDuet: boolean = false;
  private needsMeasure: boolean = true;
  private measureInited: boolean = false;
  private measureCursor: number = 0;
  private measureOrder: number[] = [];
  private static readonly MEASURE_BATCH: number = 40;
  private lastFontSize: number = -1;
  private lastContentWidth: number = -1;
  private rgbaCache: Map<string, string> = new Map<string, string>();
  private mainFontStr: string = '';
  private subFontStr: string = '';
  private bgFontStr: string = '';
  private fadeGradTop: CanvasGradient | undefined = undefined;
  private fadeGradBottom: CanvasGradient | undefined = undefined;
  private fadeGradW: number = 0;
  private fadeGradH: number = 0;
  /** 平滑渲染时间：正常播放紧跟外部时间，跳转/seek 时沿时间轴平滑逼近，
   *  使亮度/扫描等时间驱动的状态平滑过渡（跳转渐变，不闪） */
  private smoothTime: number = 0;
  private smoothTimeInited: boolean = false;

  constructor(ctx: CanvasRenderingContext2D, engine: AmllLyricPlayerEngine, style: AmllRenderStyle) {
    this.ctx = ctx;
    this.engine = engine;
    this.style = style;
    this.rebuildFontStrings();
  }

  getStyle(): AmllRenderStyle {
    return this.style;
  }

  /** Updates center alignment at runtime (setting page toggle). */
  setLyricCenterEnabled(enabled: boolean): void {
    this.style.lyricCenter = enabled;
  }

  /** 歌词更换后使测量缓存失效 */
  invalidateMeasured(): void {
    this.needsMeasure = true;
    this.measureInited = false;
    this.measureCursor = 0;
    this.measureOrder = [];
    this.measured = [];
    this.rgbaCache.clear();
  }

  updateStyle(style: AmllRenderStyle): void {
    const fontSizeChanged = this.style.fontSize !== style.fontSize;
    const aspectChanged = this.style.lineWidthAspect !== style.lineWidthAspect;
    if (this.style.showSubLyric !== style.showSubLyric) {
      // 翻译/罗马音开关变化：触发引擎侧收起/展开过渡（行高插值 + 淡入淡出）
      this.engine.setSubLineVisibility(style.showSubLyric);
    }
    const oldContentWidth = this.contentWidth;
    this.style = style;
    this.rebuildFontStrings();
    this.updateContentWidth();
    if (fontSizeChanged || aspectChanged || this.contentWidth !== oldContentWidth) {
      this.needsMeasure = true;
      this.measureInited = false;
      this.measureCursor = 0;
      this.measureOrder = [];
    }
  }

  private rebuildFontStrings(): void {
    this.mainFontStr = this.fontString(this.style.fontSize);
    this.subFontStr = this.fontString(this.style.fontSize * this.style.subLineScale, this.style.subLineWeight);
    this.bgFontStr = this.fontString(this.style.fontSize * this.style.bgLineScale);
  }

  onResize(width: number, height: number): void {
    this.containerWidth = width;
    this.containerHeight = height;
    this.updateContentWidth();
    this.needsMeasure = true;
    this.measureInited = false;
    this.measureCursor = 0;
    this.measureOrder = [];
  }

  private updateContentWidth(): void {
    this.padX = this.style.paddingXEm * this.style.fontSize;
    const avail = Math.max(0, this.containerWidth - this.padX * 2);
    this.contentWidth = avail * this.style.lineWidthAspect;
    this.hasDuet = this.engine.hasDuetLine;
  }

  private fontString(size: number, weight?: string): string {
    return `${weight !== undefined ? weight : this.style.fontWeight} ${size}vp ${this.style.fontFamily}`;
  }

  /** 非对唱行内容宽度（padding-right 15%） */
  private normalMaxW(): number {
    return this.hasDuet ? this.contentWidth * 0.85 : this.contentWidth;
  }

  /** 对唱行内容起点（padding-left 15%） */
  private duetStartX(): number {
    return this.padX + this.contentWidth * 0.15;
  }

  private duetMaxW(): number {
    return this.contentWidth * 0.85;
  }

  /**
   * 渐进测量：每次调用最多测量一批行，当前播放行优先。
   * 首次调用只建立测量顺序（跳过测量，让页面切换动画先落地）。
   */
  ensureMeasured(): void {
    if (!this.needsMeasure && this.lastFontSize === this.style.fontSize &&
      this.lastContentWidth === this.contentWidth) {
      return;
    }
    if (!this.measureInited) {
      this.measured = [];
      this.measureCursor = 0;
      this.measureOrder = [];
      const groups = this.engine.groups;
      const n = groups.length;
      if (n > 0) {
        const cur = Math.min(Math.max(0, this.engine.getTimelineSnapshot().scrollToIndex), n - 1);
        for (let d = 0; d < n; d++) {
          this.measureOrder.push((cur + d) % n);
        }
      }
      this.measureInited = true;
      if (n > 0) {
        return;
      }
    }
    const groups = this.engine.groups;
    const end = Math.min(this.measureCursor + AmllCanvasLyricRenderer.MEASURE_BATCH, this.measureOrder.length);
    for (let k = this.measureCursor; k < end; k++) {
      const i = this.measureOrder[k];
      const group = groups[i];
      const main = this.measureLine(group.mainLine, false);
      const entry: AmllMeasuredGroup = { main: main };
      this.measured[i] = entry;
      this.engine.setMeasuredMainHeight(i, main.mainHeight);
      this.engine.setMeasuredSubHeight(i, main.totalHeight - main.mainHeight);
      if (group.bgLine !== undefined) {
        const bg = this.measureLine(group.bgLine, true);
        entry.bg = bg;
        this.engine.setMeasuredBgHeight(i, bg.bgHeight);
      } else {
        this.engine.setMeasuredBgHeight(i, 0);
      }
    }
    this.measureCursor = end;
    if (end < this.measureOrder.length) {
      return;
    }
    // 间奏点尺寸
    const fontSize = this.style.fontSize;
    const dotSize = amllClamp(0.5 * fontSize, 0.01 * this.containerHeight, 3 * fontSize);
    const dotW = dotSize * 3 + fontSize * 0.25 * 2 + 4 * 3;
    const dotH = dotSize + fontSize * 0.05 * 2;
    this.engine.setInterludeDotsSize(dotW, dotH);

    this.lastFontSize = this.style.fontSize;
    this.lastContentWidth = this.contentWidth;
    this.needsMeasure = false;
    this.measureInited = false;
    this.measureCursor = 0;
    this.measureOrder = [];
  }

  /** 测量是否全部完成（帧循环据此决定是否继续运行） */
  isMeasureComplete(): boolean {
    return !this.needsMeasure && this.lastFontSize === this.style.fontSize &&
      this.lastContentWidth === this.contentWidth;
  }

  /** 构造超宽单词的一个片段（含片段文本与字符映射） */
  private makeSegmentedWord(
    atom: AmllWordAtom,
    graphemes: string[],
    widths: number[],
    start: number,
    end: number,
    charStartIndex: number,
    isEmpChunk: boolean
  ): AmllMeasuredWord {
    let text = '';
    let segWidth = 0;
    const segChars: AmllMeasuredChar[] = [];
    for (let g = start; g < end; g++) {
      text += graphemes[g];
      segWidth += widths[g];
      segChars.push({ char: graphemes[g], width: widths[g] });
    }
    const mw: AmllMeasuredWord = {
      atom: atom,
      width: segWidth,
      chars: segChars,
      charStartIndex: charStartIndex + start,
      clipText: text,
      isEmpChunk: isEmpChunk
    };
    return mw;
  }

  private measureLine(line: AmllLineRenderState, isBg: boolean): AmllMeasuredLine {
    const size = isBg ? this.style.fontSize * this.style.bgLineScale : this.style.fontSize;
    const isDuet = line.line.isDuet;
    const contentW = isBg ? this.duetMaxW() : this.normalMaxW();
    this.ctx.font = isBg ? this.bgFontStr : this.mainFontStr;
    const words: AmllMeasuredWord[] = [];
    const atoms = line.atoms;
    let totalWidth = 0;
    // chunk 内全局字符序号跟踪
    const chunkCharIndex: Map<number, number> = new Map<number, number>();

    for (let i = 0; i < atoms.length; i++) {
      const atom = atoms[i];
      const w = this.ctx.measureText(atom.text).width;
      atom.width = w;
      const chunk = this.findChunk(line, atom);
      const isEmpChunk = chunk !== undefined && chunk.emp && !atom.isPureSpace;
      const chunkId: number = chunk !== undefined ? chunk.id : -1;

      // 超宽单词按字符折行（对应原版 DOM 中 white-space: pre-wrap 的单词内换行）
      if (!atom.isPureSpace && w > contentW) {
        let charStartIndex = 0;
        const charGraphemes: string[] = isEmpChunk
          ? amllSplitGraphemes(atom.text.trim())
          : amllSplitGraphemes(atom.text);
        if (isEmpChunk) {
          charStartIndex = chunkCharIndex.get(chunkId) ?? 0;
          chunkCharIndex.set(chunkId, charStartIndex + charGraphemes.length);
        }
        const charWidths: number[] = [];
        for (let g = 0; g < charGraphemes.length; g++) {
          charWidths.push(this.ctx.measureText(charGraphemes[g]).width);
        }
        let segStart = 0;
        let segWidth = 0;
        for (let g = 0; g < charGraphemes.length; g++) {
          const cw = charWidths[g];
          if (segWidth + cw > contentW && segWidth > 0) {
            const mw = this.makeSegmentedWord(atom, charGraphemes, charWidths, segStart, g,
              charStartIndex, isEmpChunk);
            words.push(mw);
            totalWidth += segWidth;
            segStart = g;
            segWidth = 0;
          }
          segWidth += cw;
        }
        if (segWidth > 0 || segStart < charGraphemes.length) {
          const mw = this.makeSegmentedWord(atom, charGraphemes, charWidths, segStart,
            charGraphemes.length, charStartIndex, isEmpChunk);
          words.push(mw);
          totalWidth += segWidth;
        }
        continue;
      }

      const chars: AmllMeasuredChar[] = [];
      let charStartIndex = 0;
      if (isEmpChunk) {
        charStartIndex = chunkCharIndex.get(chunkId) ?? 0;
        const graphemes = amllSplitGraphemes(atom.text.trim());
        for (let g = 0; g < graphemes.length; g++) {
          const cw = this.ctx.measureText(graphemes[g]).width;
          chars.push({ char: graphemes[g], width: cw });
        }
        chunkCharIndex.set(chunkId, charStartIndex + graphemes.length);
      }
      words.push({
        atom: atom,
        width: w,
        chars: chars,
        charStartIndex: charStartIndex,
        isEmpChunk: isEmpChunk
      });
      totalWidth += w;
    }

    let breaks: number[] = [];
    if (totalWidth > contentW && words.length > 0) {
      const infos: AmllChildNodeInfo[] = [];
      let fullText = '';
      for (let i = 0; i < words.length; i++) {
        infos.push({
          width: words[i].width,
          text: words[i].atom.text,
          isSpace: words[i].atom.isPureSpace
        });
        fullText += words[i].atom.text;
      }
      breaks = amllCalcBalancedBreaks(infos, Math.max(1, contentW), fullText);
    }

    const rows = breaks.length + 1;
    const textH = size * 1.2;
    const mainHeight = rows * textH + this.style.fontSize * 0.8;
    let subHeight = 0;
    let cachedTranslationLines: string[] | undefined = undefined;
    let cachedRomanSubWords: AmllSubWord[][] | undefined = undefined;
    let cachedRomanPlainLines: string[] | undefined = undefined;
    let romanRowWidths: number[] | undefined = undefined;
    if (!isBg) {
      const subSize = this.style.fontSize * this.style.subLineScale;
      const subMaxW = isDuet ? this.duetMaxW() : this.normalMaxW();
      let subRows = 0;
      if (line.line.translatedLyric.length > 0) {
        cachedTranslationLines = this.wrapPlainText(line.line.translatedLyric, subMaxW, subSize);
        subRows += cachedTranslationLines.length;
      }
      if (line.line.romanLyric.length > 0) {
        const rWords = line.line.romanWords;
        if (rWords !== undefined && rWords.length > 0) {
          cachedRomanSubWords = this.buildRomanSubWords(rWords, subMaxW, subSize);
          const rowWidths: number[] = [];
          for (let r = 0; r < cachedRomanSubWords.length; r++) {
            rowWidths.push(this.rowWidth(cachedRomanSubWords[r]));
          }
          romanRowWidths = rowWidths;
          subRows += cachedRomanSubWords.length;
        } else {
          const romanLines = this.wrapPlainText(line.line.romanLyric, subMaxW, subSize);
          cachedRomanPlainLines = romanLines;
          subRows += romanLines.length;
        }
      }
      if (subRows > 0) {
        subHeight = this.style.fontSize * this.style.subLineScale * 1.5 * subRows +
          this.style.fontSize * 0.3;
      }
    }
    const totalHeight = mainHeight + subHeight;
    // 背景人声行块高度：按实际折行行数计算（单行公式在伴唱折行时会溢出重叠下一行）
    const bgH = isBg ? rows * textH + this.style.fontSize * 0.8 : 0;

    // 预计算单词绘制位置（布局只依赖测量结果，绘制阶段直接复用）
    const positions: AmllWordPos[] = [];
    const breaksSet = new Set<number>(breaks);
    // 每行累计宽度：对唱行按行整体右对齐（行末贴右边缘），普通行保持左对齐
    const rowWidths: number[] = [0];
    let rowIdx = 0;
    for (let i = 0; i < words.length; i++) {
      rowWidths[rowIdx] += words[i].width;
      if (breaksSet.has(i + 1)) {
        rowIdx++;
        rowWidths.push(0);
      }
    }
    const duetRightEdge: number = this.duetStartX() + this.duetMaxW();
    let cursorX = isDuet ? (duetRightEdge - rowWidths[0]) : this.centeredStartX(rowWidths[0]);
    let row = 0;
    for (let i = 0; i < words.length; i++) {
      positions.push({ x: cursorX, row: row });
      cursorX += words[i].width;
      if (breaksSet.has(i + 1)) {
        row++;
        cursorX = isDuet ? (duetRightEdge - rowWidths[row]) : this.centeredStartX(rowWidths[row]);
      }
    }

    line.blockHeight = totalHeight;
    line.wrapBreaks = breaks;
    line.hasWraps = breaks.length > 0;
    line.bgHeight = bgH;

    return {
      words: words,
      breaks: breaks,
      mainHeight: mainHeight,
      totalHeight: totalHeight,
      bgHeight: bgH,
      cachedTranslationLines: cachedTranslationLines,
      cachedRomanSubWords: cachedRomanSubWords,
      cachedRomanPlainLines: cachedRomanPlainLines,
      romanRowWidths: romanRowWidths,
      positions: positions
    };
  }

  private findChunk(line: AmllLineRenderState, atom: AmllWordAtom): AmllChunkLike | undefined {
    const chunk = line.chunkMap.get(atom.chunkId);
    if (chunk !== undefined) {
      return chunk as AmllChunkLike;
    }
    return undefined;
  }

  // ==================== 绘制 ====================

  draw(renderTime: number): void {
    this.advanceSmoothTime(renderTime);
    // 间奏点透明度按真实时间推进（拖动时 draw 高频调用，渐隐实时生效）
    this.engine.advanceInterludeFade(Date.now());
    const w = this.containerWidth;
    const h = this.containerHeight;
    if (w <= 0 || h <= 0) {
      return;
    }
    // 先确认容器有真实尺寸再测量：0 宽度下测量会生成病态行高（每字符一行），
    // 且首帧测量顺序建立后行高迟迟无法被真实值替换
    this.ensureMeasured();
    this.ctx.reset();
    this.ctx.save();
    this.ctx.globalCompositeOperation = 'source-over';
    this.ctx.filter = 'none';
    this.ctx.shadowBlur = 0;

    // 点击定位圆角框（画在歌词文本之下，随行滚动）
    this.drawFocusFrame();

    const groups = this.engine.groups;
    for (let i = 0; i < groups.length; i++) {
      this.drawGroup(groups[i], this.smoothTime);
    }
    this.ctx.restore();

    this.drawInterludeDots();

    // 上下边缘渐隐遮罩：避免歌词被视口直接裁切的割裂感
    this.drawEdgeFade(w, h);
  }

  /** 点击定位行的圆角框：包住整个主行+副行块，弹性弹出/淡出 */
  private drawFocusFrame(): void {
    const index = this.engine.getFocusIndex();
    if (index < 0 || index >= this.engine.groups.length) {
      return;
    }
    const pos = this.engine.getFocusShowProgress();
    if (pos <= 0.01) {
      return;
    }
    const group = this.engine.groups[index];
    if (!group.isInSight) {
      return;
    }
    const entry = this.measured[index];
    if (entry === undefined) {
      return;
    }
    const h = this.engine.getLineHeight(index);
    if (h <= 0) {
      return;
    }
    const ctx = this.ctx;
    const x = this.padX;
    const w = this.contentWidth;
    const top = group.posY.getCurrentPosition();
    // 框与行块完全等高、不随弹簧过冲放大、无外扩：相邻行块直接相接，
    // 任何放大/外扩都会让框侵入相邻行（行块内已有 0.4em padding，文本不会贴边）
    const radius = this.style.fontSize * 0.4;
    ctx.save();
    ctx.globalAlpha = amllClamp01(pos);
    ctx.beginPath();
    ctx.roundRect(x, top, w, h, radius);
    ctx.fillStyle = 'rgba(255, 255, 255, 0.08)';
    ctx.fill();
    ctx.restore();
  }

  /** 推进平滑时间：正常播放（差值小）直接同步；跳转/seek（差值大）平滑逼近 */
  private advanceSmoothTime(renderTime: number): void {
    if (!this.smoothTimeInited) {
      this.smoothTime = renderTime;
      this.smoothTimeInited = true;
      return;
    }
    const delta = renderTime - this.smoothTime;
    if (Math.abs(delta) <= 400) {
      this.smoothTime = renderTime;
      return;
    }
    this.smoothTime += delta * 0.25;
  }

  /** 上下边缘渐隐（destination-out 擦除，歌词接近容器边缘时平滑淡出） */
  private drawEdgeFade(w: number, h: number): void {
    const ctx = this.ctx;
    const fade = Math.max(40, h * 0.1);
    if (this.fadeGradTop === undefined || this.fadeGradBottom === undefined ||
      this.fadeGradW !== w || this.fadeGradH !== h) {
      this.fadeGradW = w;
      this.fadeGradH = h;
      const topGrad = ctx.createLinearGradient(0, 0, 0, fade);
      topGrad.addColorStop(0, 'rgba(0, 0, 0, 1)');
      topGrad.addColorStop(1, 'rgba(0, 0, 0, 0)');
      this.fadeGradTop = topGrad;
      const bottomGrad = ctx.createLinearGradient(0, h - fade, 0, h);
      bottomGrad.addColorStop(0, 'rgba(0, 0, 0, 0)');
      bottomGrad.addColorStop(1, 'rgba(0, 0, 0, 1)');
      this.fadeGradBottom = bottomGrad;
    }
    ctx.save();
    ctx.globalCompositeOperation = 'destination-out';
    const top = this.fadeGradTop;
    if (top !== undefined) {
      ctx.fillStyle = top;
      ctx.fillRect(0, 0, w, fade);
    }
    const bottom = this.fadeGradBottom;
    if (bottom !== undefined) {
      ctx.fillStyle = bottom;
      ctx.fillRect(0, h - fade, w, fade);
    }
    ctx.restore();
  }

  private drawGroup(group: AmllGroupState, renderTime: number): void {
    if (!group.isInSight) {
      return;
    }
    const entry = this.measured[group.index];
    if (entry === undefined) {
      return;
    }
    const posY = group.posY.getCurrentPosition();
    const ctx = this.ctx;

    ctx.save();
    ctx.globalAlpha = amllClamp01(group.opacity);
    // 拖动/滚动交互期间（含松手后自动对齐回归前）不模糊任何行：
    // 视口边缘进出与 overscan 区域的行在 calcLayout 中仍会拿到模糊目标，绘制层直接跳过
    const blurVal = this.engine.isTouchScrolled ? 0 : Math.min(16, group.blur);
    if (blurVal > 0.01) {
      ctx.filter = `blur(${blurVal.toFixed(2)}px)`;
    } else {
      ctx.filter = 'none';
    }
    ctx.shadowBlur = 0;

    // 主行缩放（transform-origin: left；对唱行 transform-origin: right）
    const mainScale = group.mainLine.scale.getCurrentPosition() / 100;
    const blockH = entry.main.totalHeight;
    const isDuetLine = group.mainLine.line.isDuet;
    const scaleOriginX: number = isDuetLine ? this.padX + this.contentWidth : this.padX;
    // 伴唱在上的对唱：主行随伴唱显示进度下移，缩放原点同步跟随
    let mainTop = posY;
    let bgAlpha = 0;
    const bgMeasured = entry.bg;
    if (group.bgLine !== undefined && bgMeasured !== undefined) {
      bgAlpha = amllClamp01(group.bgShow.getCurrentPosition());
      if (group.isBgFirst) {
        mainTop = posY + bgMeasured.bgHeight * bgAlpha;
      }
    }
    if (Math.abs(mainScale - 1) > 0.0001) {
      ctx.translate(scaleOriginX, mainTop + blockH / 2);
      ctx.scale(mainScale, mainScale);
      ctx.translate(-scaleOriginX, -(mainTop + blockH / 2));
    }

    // 背景人声行（显示进度由引擎 bgShow 弹簧驱动，含淡入淡出与滑入滑出）
    if (bgAlpha > 0.01 && bgMeasured !== undefined) {
      this.drawBgLine(group, bgMeasured, renderTime, bgAlpha);
    }

    // 主行（伴唱在上的对唱：主行随伴唱展开同步下移，避免重叠）
    this.drawLineContent(group, group.mainLine, entry.main, mainTop, renderTime, false);

    ctx.restore();
  }

  private drawBgLine(
    group: AmllGroupState,
    bgMeasured: AmllMeasuredLine,
    renderTime: number,
    alpha: number
  ): void {
    const ctx = this.ctx;
    const fontSize = this.style.fontSize;
    const scale = 0.8 + alpha * 0.2;
    const posY = group.posY.getCurrentPosition();
    const entry = this.measured[group.index];
    const mainHeight = entry !== undefined ? entry.main.mainHeight : 0;
    const subShown = entry !== undefined
      ? (entry.main.totalHeight - entry.main.mainHeight) *
        Math.max(0, this.engine.getSubHeightProgress())
      : 0;
    // 伴唱空间：随显示进度从 0 生长到 bgH——伴唱在下时位于主行+副行之下，
    // 伴唱在上时位于组顶（主行随之下移）；文本裁剪在空间内，与其他行互不重叠，
    // 其他行随行高弹簧平滑展开/收起（与间奏呼吸点同理）
    const spaceTop = group.isBgFirst ? posY : posY + mainHeight + subShown;
    const spaceH = bgMeasured.bgHeight * alpha;
    if (spaceH <= 0.5) {
      return;
    }
    const bgOriginX: number = group.isBgFirst ? 0 : this.padX;
    ctx.save();
    ctx.globalAlpha *= 0.4 * alpha;
    // 出现/消失过渡：随显示进度模糊淡出——出现时从强模糊渐变到清晰，收起时反向
    // （数值取大：过渡初期透明度低，弱模糊肉眼不可见）
    const transitionBlur = (1 - alpha) * 20;
    if (transitionBlur > 0.1) {
      ctx.filter = `blur(${transitionBlur.toFixed(2)}px)`;
    } else {
      ctx.filter = 'none';
    }
    ctx.beginPath();
    ctx.rect(this.padX, spaceTop, this.contentWidth, spaceH);
    ctx.clip();
    ctx.translate(bgOriginX, spaceTop);
    ctx.scale(scale, scale);
    ctx.translate(-bgOriginX, -spaceTop);
    this.drawLineContent(group, group.bgLine as AmllLineRenderState, bgMeasured, spaceTop, renderTime, true);
    ctx.restore();

    // 底部边缘柔化：空间生长揭示时裁剪边是硬切，用渐变擦除让底部渐隐，消除锐利感
    const edgeFadeH = Math.min(spaceH * 0.5, fontSize * 1.2);
    if (edgeFadeH > 1) {
      ctx.save();
      ctx.filter = 'none';
      ctx.beginPath();
      ctx.rect(this.padX, spaceTop, this.contentWidth, spaceH);
      ctx.clip();
      ctx.globalCompositeOperation = 'destination-out';
      const edgeGrad = ctx.createLinearGradient(0, spaceTop + spaceH - edgeFadeH, 0, spaceTop + spaceH);
      edgeGrad.addColorStop(0, 'rgba(0, 0, 0, 0)');
      edgeGrad.addColorStop(1, 'rgba(0, 0, 0, 1)');
      ctx.fillStyle = edgeGrad;
      ctx.fillRect(this.padX, spaceTop + spaceH - edgeFadeH, this.contentWidth, edgeFadeH);
      ctx.restore();
    }
  }

  private drawLineContent(
    group: AmllGroupState,
    line: AmllLineRenderState,
    measured: AmllMeasuredLine,
    top: number,
    renderTime: number,
    isBg: boolean
  ): void {
    const ctx = this.ctx;
    const fontSize = this.style.fontSize;
    const size = isBg ? fontSize * this.style.bgLineScale : fontSize;
    const textH = size * 1.2;

    ctx.font = isBg ? this.bgFontStr : this.mainFontStr;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';

    const words = measured.words;
    if (words.length === 0) {
      return;
    }

    // 布局位置在测量阶段已缓存（positions/totalRows）
    const positions = measured.positions;

    const isNonDynamic = this.engine.isNonDynamic;
    const lineStart = line.line.startTime;
    const lineEnd = line.line.endTime;
    // 与翻译/罗马音行一致的渐亮渐暗节奏：未唱 0.4，唱时亮 1.0，唱过渐暗
    const dimAlpha = 0.4;
    const brightAlpha = 1;
    const fadeMs = 400;
    // 非动态行的整行亮度曲线（每词共用同一 alpha，提前算一次）；
    // 最亮值 0.85 与动态行激活亮度（opacity 0.85 × alpha 1.0）一致
    const nonDynamicAlpha = isNonDynamic
      ? this.computeMainLineAlpha(line, renderTime, dimAlpha, 0.85)
      : 0;
    const isActive = renderTime >= lineStart - 500 && renderTime <= lineEnd + 500;
    const isPassed = renderTime > lineEnd + 500;

    for (let i = 0; i < words.length; i++) {
      const mw = words[i];
      const atom = mw.atom;
      if (atom.isPureSpace) {
        continue;
      }
      const x = positions[i].x;
      // 行 r 的文本盒顶部 = top + 0.4em padding + r * textH（r=0 为最顶行）；
      // 基线取文本盒顶部 + 0.85 * textH（多行时保证文本整体位于块内，不向上溢出）
      const y = top + fontSize * 0.4 + positions[i].row * textH + textH * 0.85;

      if (isNonDynamic) {
        // 非动态歌词：整行纯文本（无遮罩），亮度曲线与翻译/罗马音行一致
        ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, nonDynamicAlpha);
        const text: string = mw.clipText !== undefined ? mw.clipText : atom.text;
        this.fillText(text, x, y);
        continue;
      }

      const emp = mw.isEmpChunk;

      // 扫描参数（仅激活行计算）
      const fadeW = size * 1.2 * this.engine.getWordFadeWidth();
      const w = mw.width;
      const isBefore = renderTime < atom.startTime;
      const isAfter = renderTime >= atom.endTime;
      let brightEdge = x + w;
      if (isActive && !isBefore) {
        const dur = atom.endTime - atom.startTime;
        let maskPos: number;
        if (dur > 0) {
          const p = amllClamp01((renderTime - atom.startTime) / dur);
          maskPos = amllClamp(-w - fadeW, -w - fadeW + p * (w + fadeW), 0);
        } else {
          maskPos = 0;
        }
        brightEdge = x + maskPos + w;
      }

      if (emp && mw.chars.length > 0) {
        // 逐字符绘制：强调变换/强调漂浮始终由时间驱动（禁用行也保持，对应原版动画行为），
        // 扫描仅在激活行应用，其他状态用暗色/亮色/渐暗（与罗马音行一致）
        let charX = x;
        for (let c = 0; c < mw.chars.length; c++) {
          const mc = mw.chars[c];
          const charCenterX = charX + mc.width / 2;
          let wordAlpha = dimAlpha;
          if (isPassed) {
            const t = amllClamp01((renderTime - (lineEnd + 500)) / fadeMs);
            wordAlpha = brightAlpha - (brightAlpha - dimAlpha) * t;
          } else if (isActive && !isBefore) {
            wordAlpha = isAfter ? brightAlpha : this.sweepAlpha(charCenterX, brightEdge, fadeW);
          }
          ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, wordAlpha);
          this.fillText(mc.char, charX, y);
          charX += mc.width;
        }
      } else {
        // 整词绘制：启用时扫描渐变，禁用时均匀暗色
        const text: string = mw.clipText !== undefined ? mw.clipText : atom.text;
        if (isPassed) {
          // 行已唱过：从亮渐暗回暗色（与罗马音行一致）
          const t = amllClamp01((renderTime - (lineEnd + 500)) / fadeMs);
          ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, brightAlpha - (brightAlpha - dimAlpha) * t);
          this.fillText(text, x, y);
          continue;
        }
        if (!isActive || isBefore) {
          // 未唱（含非当前行）：整词暗色，与罗马音行一致
          ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, dimAlpha);
          this.fillText(text, x, y);
          continue;
        }
        if (isAfter) {
          // 已唱完：整词亮色，与罗马音行一致
          ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, brightAlpha);
          this.fillText(text, x, y);
          continue;
        }
        // 正在唱：扫描渐变，亮区从词左端推进到词右端
        const grad = ctx.createLinearGradient(x, 0, x + w, 0);
        const fadeStart = brightEdge;
        const fadeEnd = brightEdge + fadeW;
        const pFadeStart = amllClamp01((fadeStart - x) / Math.max(1, w));
        const pFadeEnd = amllClamp01((fadeEnd - x) / Math.max(1, w));
        const brightColor = this.hexToRgbaCached(this.style.textColor, brightAlpha);
        const dimColor = this.hexToRgbaCached(this.style.textColor, dimAlpha);
        if (pFadeStart >= pFadeEnd) {
          grad.addColorStop(0, pFadeStart >= 1 ? brightColor : dimColor);
          grad.addColorStop(1, pFadeStart >= 1 ? brightColor : dimColor);
        } else {
          grad.addColorStop(0, brightColor);
          grad.addColorStop(pFadeStart, brightColor);
          grad.addColorStop(pFadeEnd, dimColor);
          grad.addColorStop(1, dimColor);
        }
        ctx.fillStyle = grad;
        this.fillText(text, x, y);
      }
    }

    // 子行（翻译/音译）
    this.drawSubLines(line, top, measured, renderTime);
  }

  private sweepAlpha(charCenterX: number, brightEdge: number, fadeW: number): number {
    if (charCenterX <= brightEdge) {
      return 1;
    }
    if (charCenterX >= brightEdge + fadeW) {
      return 0.4;
    }
    const t = (charCenterX - brightEdge) / Math.max(0.001, fadeW);
    return 1 - t * 0.6;
  }

  /** 子行（翻译/音译） */
  private drawSubLines(
    line: AmllLineRenderState,
    top: number,
    measured: AmllMeasuredLine,
    renderTime: number
  ): void {
    if (!this.style.showSubLyric) {
      return;
    }
    const trans = line.line.translatedLyric;
    const roman = line.line.romanLyric;
    if (trans.length === 0 && roman.length === 0) {
      return;
    }
    const ctx = this.ctx;
    const fontSize = this.style.fontSize;
    const subSize = fontSize * this.style.subLineScale;
    const textH = subSize * 1.5;
    const isDuet = line.line.isDuet;
    const startX = isDuet ? this.duetStartX() : this.padX;
    const maxW = isDuet ? this.duetMaxW() : this.normalMaxW();

    // 收起/展开过渡：副行淡入淡出直接由副行弹簧驱动（引擎双弹簧错峰启动——
    // 展开时行高弹簧先行、副行弹簧延迟后淡入；收起时副行弹簧先行、行高弹簧延迟后收拢），
    // 两方向完全对称
    const progress = this.engine.getSubShowProgress();
    const fade: number = amllClamp01(progress);
    if (fade <= 0.01) {
      return;
    }

    ctx.save();
    ctx.font = this.subFontStr;
    ctx.textBaseline = 'alphabetic';

    // 子行亮度随激活态平滑过渡：未唱 0.4 → 唱时 0.85 → 唱过渐暗回 0.4；再乘显示进度
    const subAlpha = this.computeSubLineAlpha(line, renderTime, 0.4, 0.85) * fade;

    // 子行块起点 = 主行块底部；文本整体位于子块内（r=0 为最顶行）
    let subTop = top + measured.mainHeight;
    if (trans.length > 0) {
      ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, subAlpha);
      const lines = measured.cachedTranslationLines !== undefined
        ? measured.cachedTranslationLines
        : this.wrapPlainText(trans, maxW, subSize);
      for (let r = 0; r < lines.length; r++) {
        const y = subTop + r * textH + textH * 0.85;
        this.drawTextAligned(lines[r], startX, maxW, y, isDuet);
      }
      subTop += lines.length * textH;
    }
    ctx.restore();
    if (roman.length > 0) {
      const romanWords = line.line.romanWords;
      if (romanWords !== undefined && romanWords.length > 0) {
        if (measured.cachedRomanSubWords !== undefined) {
          this.drawSubRomanWordsCached(measured.cachedRomanSubWords, measured.romanRowWidths, subTop, subSize, textH, startX, maxW, isDuet, renderTime, line, fade);
        } else {
          this.drawSubRomanWords(romanWords, subTop, subSize, textH, startX, maxW, isDuet, renderTime, line, fade);
        }
      } else {
        ctx.save();
        ctx.font = this.subFontStr;
        ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, subAlpha);
        ctx.textBaseline = 'alphabetic';
        const lines = measured.cachedRomanPlainLines !== undefined
          ? measured.cachedRomanPlainLines
          : this.wrapPlainText(roman, maxW, subSize);
        for (let r = 0; r < lines.length; r++) {
          const y = subTop + r * textH + textH * 0.85;
          this.drawTextAligned(lines[r], startX, maxW, y, isDuet);
        }
        ctx.restore();
      }
    }
  }

  /**
   * 非动态主行亮度：只有最暗（dim）与最亮（bright）两档，
   * 行开始后 fadeMs 内渐亮到最亮，行结束后 fadeMs 内渐暗回最暗。
   */
  private computeMainLineAlpha(
    line: AmllLineRenderState,
    renderTime: number,
    dim: number,
    bright: number
  ): number {
    const fadeMs = 300;
    const lineStart = line.line.startTime;
    const lineEnd = line.line.endTime;
    if (renderTime < lineStart) {
      return dim;
    }
    if (renderTime < lineStart + fadeMs) {
      const t = amllClamp01((renderTime - lineStart) / fadeMs);
      return dim + (bright - dim) * t;
    }
    if (renderTime <= lineEnd) {
      return bright;
    }
    if (renderTime < lineEnd + fadeMs) {
      const t = amllClamp01((renderTime - lineEnd) / fadeMs);
      return bright - (bright - dim) * t;
    }
    return dim;
  }

  /**
   * 子行亮度平滑过渡：行未到 0.4，行开始前 fadeMs 内渐亮到 bright，
   * 行激活期间保持 bright，行结束后 fadeMs 内渐暗回 0.4。
   */
  private computeSubLineAlpha(line: AmllLineRenderState, renderTime: number, dim: number, bright: number): number {
    const fadeMs = 400;
    const lineStart = line.line.startTime;
    const lineEnd = line.line.endTime;
    const arriveAt = lineStart;
    const leaveAt = lineEnd;
    if (renderTime < arriveAt - fadeMs) {
      return dim;
    }
    if (renderTime < arriveAt) {
      // 渐亮
      const t = amllClamp01((renderTime - (arriveAt - fadeMs)) / fadeMs);
      return dim + (bright - dim) * t;
    }
    if (renderTime <= leaveAt) {
      return bright;
    }
    // 渐暗
    const t = amllClamp01((renderTime - leaveAt) / fadeMs);
    return bright - (bright - dim) * t;
  }

  /** 逐字罗马音（使用预缓存的折行数据，避免每帧 measureText） */
  private drawSubRomanWordsCached(
    rows: AmllSubWord[][],
    rowWidths: number[] | undefined,
    subTop: number,
    subSize: number,
    textH: number,
    startX: number,
    maxW: number,
    isDuet: boolean,
    renderTime: number,
    line: AmllLineRenderState,
    showProgress: number
  ): void {
    const ctx = this.ctx;
    const lineStart = line.line.startTime;
    const lineEnd = line.line.endTime;
    const isActive = renderTime >= lineStart && renderTime <= lineEnd;
    const dimAlpha = 0.4 * showProgress;
    const brightAlpha = 0.85 * showProgress;
    const fadeMs = 400;

    ctx.save();
    ctx.font = this.subFontStr;
    ctx.textBaseline = 'alphabetic';

    for (let r = 0; r < rows.length; r++) {
      const rowWords = rows[r];
      const y = subTop + r * textH + textH * 0.85;
      const rowW = rowWidths !== undefined ? rowWidths[r] : this.rowWidth(rowWords);
      const rowX = isDuet ? startX + maxW - rowW : startX;
      let x = rowX;
      for (let i = 0; i < rowWords.length; i++) {
        const m = rowWords[i];
        const w = m.width;
        const wordStart = m.word.startTime;
        const wordEnd = m.word.endTime;
        const isBefore = renderTime < wordStart;
        const isAfter = renderTime >= wordEnd;
        const isPassed = renderTime > lineEnd;
        if (isPassed) {
          const fadeOutT = amllClamp01((renderTime - lineEnd) / fadeMs);
          const alpha = brightAlpha - (brightAlpha - dimAlpha) * fadeOutT;
          ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, alpha);
          this.fillText(m.word.word, x, y);
        } else if (!isActive || isBefore) {
          ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, dimAlpha);
          this.fillText(m.word.word, x, y);
        } else if (isAfter) {
          ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, brightAlpha);
          this.fillText(m.word.word, x, y);
        } else {
          const dur = wordEnd - wordStart;
          let maskPos: number;
          const fadeW = w * 0.4;
          if (dur > 0) {
            const p = amllClamp01((renderTime - wordStart) / dur);
            maskPos = amllClamp(-w - fadeW, -w - fadeW + p * (w + fadeW), 0);
          } else {
            maskPos = 0;
          }
          const brightEdge = x + maskPos + w;
          const grad = ctx.createLinearGradient(x, 0, x + w, 0);
          const fadeStart = brightEdge;
          const fadeEnd = brightEdge + fadeW;
          const pFadeStart = amllClamp01((fadeStart - x) / Math.max(1, w));
          const pFadeEnd = amllClamp01((fadeEnd - x) / Math.max(1, w));
          const brightColor = this.hexToRgbaCached(this.style.textColor, brightAlpha);
          const dimColor = this.hexToRgbaCached(this.style.textColor, dimAlpha);
          if (pFadeStart >= pFadeEnd) {
            grad.addColorStop(0, pFadeStart >= 1 ? brightColor : dimColor);
            grad.addColorStop(1, pFadeStart >= 1 ? brightColor : dimColor);
          } else {
            grad.addColorStop(0, brightColor);
            grad.addColorStop(pFadeStart, brightColor);
            grad.addColorStop(pFadeEnd, dimColor);
            grad.addColorStop(1, dimColor);
          }
          ctx.fillStyle = grad;
          this.fillText(m.word.word, x, y);
        }
        x += w;
      }
    }
    ctx.restore();
  }

  /** 逐字罗马音：按字级时间戳扫描高亮（已唱亮、未唱暗） */
  private drawSubRomanWords(
    romanWords: AmllLyricWord[],
    subTop: number,
    subSize: number,
    textH: number,
    startX: number,
    maxW: number,
    isDuet: boolean,
    renderTime: number,
    line: AmllLineRenderState,
    showProgress: number
  ): void {
    const ctx = this.ctx;
    const lineStart = line.line.startTime;
    const lineEnd = line.line.endTime;
    const isActive = renderTime >= lineStart && renderTime <= lineEnd;
    // 未唱时与原文未唱同色（0.4），唱时已唱词亮（0.85）；再乘显示进度
    const dimAlpha = 0.4 * showProgress;
    const brightAlpha = 0.85 * showProgress;
    // 已唱完的词从暗渐亮到亮的时间（ms）
    const fadeMs = 400;

    ctx.save();
    ctx.font = this.subFontStr;
    ctx.textBaseline = 'alphabetic';

    const measuredWords: AmllSubWord[] = [];
    let cursorX = 0;
    for (let i = 0; i < romanWords.length; i++) {
      const w = romanWords[i];
      const tw = ctx.measureText(w.word).width;
      if (i > 0 && cursorX + tw > maxW) {
        measuredWords.push({ word: w, width: tw, isNewRow: true });
        cursorX = tw;
      } else {
        measuredWords.push({ word: w, width: tw, isNewRow: false });
        cursorX += tw;
      }
    }

    // 先按 isNewRow 标记拆出行
    const rows: AmllSubWord[][] = [];
    let curRow: AmllSubWord[] = [];
    for (let i = 0; i < measuredWords.length; i++) {
      const m = measuredWords[i];
      if (m.isNewRow && curRow.length > 0) {
        rows.push(curRow);
        curRow = [];
      }
      curRow.push(m);
    }
    if (curRow.length > 0) {
      rows.push(curRow);
    }

    for (let r = 0; r < rows.length; r++) {
      const rowWords = rows[r];
      const y = subTop + r * textH + textH * 0.85;
      const rowX = isDuet ? startX + maxW - this.rowWidth(rowWords) : startX;
      let x = rowX;
      for (let i = 0; i < rowWords.length; i++) {
        const m = rowWords[i];
        const w = m.width;
        const wordStart = m.word.startTime;
        const wordEnd = m.word.endTime;
        const isBefore = renderTime < wordStart;
        const isAfter = renderTime >= wordEnd;
        const isPassed = renderTime > lineEnd;
        if (isPassed) {
          // 行已唱过：从亮渐暗回到暗色（与原文已过行一致）
          const fadeOutT = amllClamp01((renderTime - lineEnd) / fadeMs);
          const alpha = brightAlpha - (brightAlpha - dimAlpha) * fadeOutT;
          ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, alpha);
          this.fillText(m.word.word, x, y);
        } else if (!isActive || isBefore) {
          // 未唱（含非当前行）：整词暗色，与原文未唱一致
          ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, dimAlpha);
          this.fillText(m.word.word, x, y);
        } else if (isAfter) {
          // 已唱完：保持亮色（扫描渐变已提供渐亮过程，避免亮度跳变闪烁）
          ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, brightAlpha);
          this.fillText(m.word.word, x, y);
        } else {
          // 正在唱：扫描渐变，亮区从词左端推进到词右端
          const dur = wordEnd - wordStart;
          let maskPos: number;
          const fadeW = w * 0.4;
          if (dur > 0) {
            const p = amllClamp01((renderTime - wordStart) / dur);
            maskPos = amllClamp(-w - fadeW, -w - fadeW + p * (w + fadeW), 0);
          } else {
            maskPos = 0;
          }
          const brightEdge = x + maskPos + w;
          const grad = ctx.createLinearGradient(x, 0, x + w, 0);
          const fadeStart = brightEdge;
          const fadeEnd = brightEdge + fadeW;
          const pFadeStart = amllClamp01((fadeStart - x) / Math.max(1, w));
          const pFadeEnd = amllClamp01((fadeEnd - x) / Math.max(1, w));
          const brightColor = this.hexToRgbaCached(this.style.textColor, brightAlpha);
          const dimColor = this.hexToRgbaCached(this.style.textColor, dimAlpha);
          if (pFadeStart >= pFadeEnd) {
            grad.addColorStop(0, pFadeStart >= 1 ? brightColor : dimColor);
            grad.addColorStop(1, pFadeStart >= 1 ? brightColor : dimColor);
          } else {
            grad.addColorStop(0, brightColor);
            grad.addColorStop(pFadeStart, brightColor);
            grad.addColorStop(pFadeEnd, dimColor);
            grad.addColorStop(1, dimColor);
          }
          ctx.fillStyle = grad;
          this.fillText(m.word.word, x, y);
        }
        x += w;
      }
    }
    ctx.restore();
  }

  private rowWidth(words: AmllSubWord[]): number {
    let total = 0;
    for (let i = 0; i < words.length; i++) {
      total += words[i].width;
    }
    return total;
  }

  /** 构建罗马音逐字折行数据（测量阶段缓存，绘制阶段直接使用） */
  private buildRomanSubWords(romanWords: AmllLyricWord[], maxW: number, subSize: number): AmllSubWord[][] {
    this.ctx.font = this.subFontStr;
    const measuredWords: AmllSubWord[] = [];
    let cursorX = 0;
    for (let i = 0; i < romanWords.length; i++) {
      const w = romanWords[i];
      const tw = this.ctx.measureText(w.word).width;
      if (i > 0 && cursorX + tw > maxW) {
        measuredWords.push({ word: w, width: tw, isNewRow: true });
        cursorX = tw;
      } else {
        measuredWords.push({ word: w, width: tw, isNewRow: false });
        cursorX += tw;
      }
    }
    const rows: AmllSubWord[][] = [];
    let curRow: AmllSubWord[] = [];
    for (let i = 0; i < measuredWords.length; i++) {
      const m = measuredWords[i];
      if (m.isNewRow && curRow.length > 0) {
        rows.push(curRow);
        curRow = [];
      }
      curRow.push(m);
    }
    if (curRow.length > 0) {
      rows.push(curRow);
    }
    return rows;
  }

  /** 简易按字符宽度的折行（子行专用，使用子行字重） */
  private wrapPlainText(text: string, maxW: number, size: number): string[] {
    if (maxW <= 0) {
      return [text];
    }
    this.ctx.font = this.subFontStr;
    const width = this.ctx.measureText(text).width;
    if (width <= maxW) {
      return [text];
    }
    const result: string[] = [];
    let line = '';
    let lineW = 0;
    const graphemes = amllSplitGraphemes(text);
    for (let i = 0; i < graphemes.length; i++) {
      const g = graphemes[i];
      const gw = this.ctx.measureText(g).width;
      if (lineW + gw > maxW && line.length > 0) {
        result.push(line);
        line = g;
        lineW = gw;
      } else {
        line += g;
        lineW += gw;
      }
    }
    if (line.length > 0) {
      result.push(line);
    }
    return result;
  }

  private drawTextAligned(text: string, startX: number, maxW: number, y: number, isDuet: boolean): void {
    const ctx = this.ctx;
    if (isDuet) {
      ctx.textAlign = 'right';
      ctx.fillText(text, startX + maxW, y);
      ctx.textAlign = 'left';
    } else if (this.style.lyricCenter) {
      const textW = ctx.measureText(text).width;
      ctx.fillText(text, startX + Math.max(0, (maxW - textW) / 2), y);
    } else {
      ctx.fillText(text, startX, y);
    }
  }

  /** 非对唱行按内容宽度居中（未开启居中时靠左）。 */
  private centeredStartX(rowWidth: number): number {
    if (this.style.lyricCenter) {
      return this.padX + Math.max(0, (this.normalMaxW() - rowWidth) / 2);
    }
    return this.padX;
  }

  private hexToRgbaCached(hex: string, alpha: number): string {
    const key = `${hex}_${alpha.toFixed(2)}`;
    const cached = this.rgbaCache.get(key);
    if (cached !== undefined) {
      return cached;
    }
    const result = hexToRgba(hex, alpha);
    this.rgbaCache.set(key, result);
    return result;
  }

  private fillText(text: string, x: number, y: number): void {
    this.ctx.fillText(text, x, y);
  }

  // ==================== 间奏点 ====================

  private drawInterludeDots(): void {
    const interlude = this.engine.interlude;
    if (!interlude.enabled || interlude.currentInterlude === undefined) {
      return;
    }
    if (interlude.alpha <= 0) {
      return;
    }
    const ctx = this.ctx;
    const fontSize = this.style.fontSize;
    const dotSize = amllClamp(0.5 * fontSize, 0.01 * this.containerHeight, 3 * fontSize);
    const gap = fontSize * 0.25;

    const interludeDuration = interlude.currentInterlude[1] - interlude.currentInterlude[0];
    const currentDuration = interlude.currentTime - interlude.currentInterlude[0];

    ctx.save();
    ctx.globalCompositeOperation = 'source-over';
    ctx.fillStyle = this.hexToRgbaCached(this.style.textColor, 1);

    if (currentDuration <= interludeDuration) {
      const breatheDuration = interludeDuration / Math.ceil(interludeDuration / 1500);
      let scale = Math.sin(1.5 * Math.PI - (currentDuration / breatheDuration) * 2) / 20 + 1;
      if (currentDuration < 2000) {
        scale *= this.easeOutExpo(currentDuration / 2000);
      }
      let globalOpacity = 1;
      if (currentDuration < 500) {
        globalOpacity = 0;
      } else if (currentDuration < 1000) {
        globalOpacity *= (currentDuration - 500) / 500;
      }
      if (interludeDuration - currentDuration < 750) {
        scale *= 1 - this.easeInOutBack(
          (750 - (interludeDuration - currentDuration)) / 750 / 2
        );
      }
      if (interludeDuration - currentDuration < 375) {
        globalOpacity *= amllClamp01((interludeDuration - currentDuration) / 375);
      }
      const dotsDuration = Math.max(0, interludeDuration - 750);
      scale = Math.max(0, scale) * 0.7;
      // 暂停渐隐：整体透明度乘 interlude.alpha
      globalOpacity *= interlude.alpha;

      const dot0Opacity = amllClamp(0.25, ((currentDuration * 3) / dotsDuration) * 0.75, 1);
      const dot1Opacity = amllClamp(
        0.25,
        (((currentDuration - dotsDuration / 3) * 3) / dotsDuration) * 0.75,
        1
      );
      const dot2Opacity = amllClamp(
        0.25,
        (((currentDuration - (dotsDuration / 3) * 2) * 3) / dotsDuration) * 0.75,
        1
      );

      const size = dotSize * scale;
      const totalW = size * 3 + gap * 2 + 4 * 3;
      const centerX = interlude.left + totalW / 2;
      const centerY = interlude.top + size / 2 + fontSize * 0.025;

      const opacities: number[] = [
        amllClamp01(globalOpacity * dot0Opacity),
        amllClamp01(globalOpacity * dot1Opacity),
        amllClamp01(globalOpacity * dot2Opacity)
      ];
      for (let i = 0; i < 3; i++) {
        ctx.globalAlpha = opacities[i];
        const x = centerX + (i - 1) * (size + gap);
        ctx.beginPath();
        ctx.arc(x, centerY, size / 2, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.restore();
  }

  private easeInOutBack(x: number): number {
    const c1 = 1.70158;
    const c2 = c1 * 1.525;
    const v = amllClamp01(x);
    if (v < 0.5) {
      return ((2 * v) ** 2 * ((c2 + 1) * 2 * v - c2)) / 2;
    }
    return ((2 * v - 2) ** 2 * ((c2 + 1) * (v * 2 - 2) + c2) + 2) / 2;
  }

  private easeOutExpo(x: number): number {
    const v = amllClamp01(x);
    return v === 1 ? 1 : 1 - 2 ** (-10 * v);
  }
}

interface AmllChunkLike {
  id: number;
  du: number;
  amount: number;
  blur: number;
  chars: AmllEmpChar[];
  emp: boolean;
}


