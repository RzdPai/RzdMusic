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
 * 歌词播放器核心引擎（对应原仓库 packages/core/src/lyric-player/base/index.ts 的忠实移植）。
 *
 * 负责：时间线同步、排版计算、弹簧动画状态、间奏点状态、歌词组视觉状态。
 * 渲染层（Canvas）每帧读取本引擎的输出进行绘制。
 */
import { AmllLyricLine, AmllLyricWord } from '../model/AmllTypes';
import {
  amllIsCJK,
  amllSplitGraphemes
} from '../model/AmllMath';
import { AmllSpring, amllGetPosYSpringPolicy, amllMergeSpringParams } from './AmllSpring';
import {
  AmllLayoutAlignAnchor,
  AmllLayoutReason,
  amllLayoutStrategyFor,
  AmllMaskObsceneWordsMode
} from './AmllConsts';
import {
  AmllLayoutCalculator,
  AmllFocalTarget,
  AmllLayoutConfig,
  AmllLayoutFrameContext,
  AmllFrameInterlude
} from './AmllLayout';
import { AmllLyricDataManager } from './AmllLyricDataManager';
import { AmllTimelineController, AmllTimelineSnapshot } from './AmllTimeline';
import { amllChunkAndSplitLyricWords } from './AmllLineBreak';

/** 时间轴条目 */
interface AmllTimeBoundEntry {
  startTime: number;
  endTime: number;
}

/** 歌词数据配置（对外） */
export interface AmllEngineConfig {
  enableBlur?: boolean;
  enableScale?: boolean;
  hidePassedLines?: boolean;
  enableSpring?: boolean;
  wordFadeWidth?: number;
  alignAnchor?: AmllLayoutAlignAnchor;
  alignPosition?: number;
  overscanPx?: number;
  maskMode?: AmllMaskObsceneWordsMode;
  maskChar?: string;
}

/** 一个强调动画字符 */
export class AmllEmpChar {
  char: string;
  /** 全局字符序号（跨 chunk 内所有词） */
  index: number;
  count: number;
  /** 字符的延迟时间（毫秒，相对行开始） */
  charDelay: number;

  constructor(char: string, index: number, count: number, charDelay: number) {
    this.char = char;
    this.index = index;
    this.count = count;
    this.charDelay = charDelay;
  }
}

/** 一个渲染原子（单词） */
export class AmllWordAtom {
  text: string;
  startTime: number;
  endTime: number;
  isPureSpace: boolean;
  /** 所属 chunk（强调动画分组） */
  chunkId: number;
  /** 测量宽度（由渲染层填充） */
  width: number = 0;

  constructor(text: string, startTime: number, endTime: number, isPureSpace: boolean, chunkId: number) {
    this.text = text;
    this.startTime = startTime;
    this.endTime = endTime;
    this.isPureSpace = isPureSpace;
    this.chunkId = chunkId;
  }
}

/** 一个强调 chunk（对应 AMLL 的 buildWord chunk） */
export class AmllChunk {
  id: number;
  /** 合并后的起止时间与文本 */
  mergedStart: number;
  mergedEnd: number;
  mergedText: string;
  /** 是否应用强调效果 */
  emp: boolean;
  /** 强调动画参数 */
  du: number;
  amount: number;
  blur: number;
  anchorCharCount: number;
  /** 强调字符（含全局序号） */
  chars: AmllEmpChar[] = [];

  constructor(id: number, mergedStart: number, mergedEnd: number, mergedText: string, emp: boolean) {
    this.id = id;
    this.mergedStart = mergedStart;
    this.mergedEnd = mergedEnd;
    this.mergedText = mergedText;
    this.emp = emp;
    this.du = 0;
    this.amount = 0;
    this.blur = 0;
    this.anchorCharCount = 1;
  }
}

/** 一行歌词的渲染状态（主行或背景行） */
export class AmllLineRenderState {
  line: AmllLyricLine;
  isBg: boolean;
  /** 缩放弹簧（100 = 原始大小） */
  scale: AmllSpring = new AmllSpring(100);
  /** 是否处于启用（高亮）状态 */
  enabled: boolean = false;
  /** 渲染原子 */
  atoms: AmllWordAtom[] = [];
  /** chunk 列表 */
  chunks: AmllChunk[] = [];
  /** chunk 快速查找表（chunkId → AmllChunk） */
  chunkMap: Map<number, AmllChunk> = new Map<number, AmllChunk>();
  /** 测量出的行高（主行文本块高度） */
  blockHeight: number = 0;
  /** 换行断点（子节点索引，升序） */
  wrapBreaks: number[] = [];
  /** 是否已换行（影响高度） */
  hasWraps: boolean = false;
  /** 背景行滑动高度（组内背景行文本高度） */
  bgHeight: number = 0;

  constructor(line: AmllLyricLine, isBg: boolean) {
    this.line = line;
    this.isBg = isBg;
  }
}

/** 一个歌词组（主行 + 可选背景行）的渲染状态 */
export class AmllGroupState {
  index: number;
  mainLine: AmllLineRenderState;
  bgLine: AmllLineRenderState | undefined = undefined;
  /** 纵向位置弹簧（秒为时间单位） */
  posY: AmllSpring = new AmllSpring(0);
  /** 背景人声行显示弹簧：0=隐藏，1=显示（驱动淡入淡出/滑入滑出与行高过渡） */
  bgShow: AmllSpring = new AmllSpring(0);
  top: number = 0;
  delay: number = 0;
  isActive: boolean = false;
  opacity: number = 1;
  /** 当前模糊值（渲染用，随时间平滑逼近 blurTarget） */
  blur: number = 0;
  /** 目标模糊值 */
  blurTarget: number = 0;
  isBgFirst: boolean = false;
  isInSight: boolean = false;
  /** 弹簧更新的内部标记 */
  posMoving: boolean = false;

  constructor(index: number, mainLine: AmllLineRenderState) {
    this.index = index;
    this.mainLine = mainLine;
  }

  get startTime(): number {
    return this.mainLine.line.startTime;
  }

  get endTime(): number {
    return this.mainLine.line.endTime;
  }
}

/** 间奏点渲染状态 */
export class AmllInterludeState {
  left: number = 0;
  /** 当前纵向位置（弹簧推进，与歌词行滚动同步） */
  top: number = 0;
  /** 纵向位置弹簧（与歌词行 posY 同参数，保证滚动时严格同步） */
  topSpring: AmllSpring = new AmllSpring(0);
  /** 整体透明度（暂停/拖动时渐隐到 0，恢复后渐入回 1） */
  alpha: number = 1;
  /** 透明度目标（暂停/拖动开始置 0，恢复置 1，alpha 平滑逼近） */
  alphaTarget: number = 1;
  playing: boolean = true;
  /** [动画起点, 结束时间] */
  currentInterlude: [number, number] | undefined = undefined;
  currentTime: number = 0;
  /** 当前是否显示 */
  enabled: boolean = false;

  reset(): void {
    this.currentInterlude = undefined;
    this.enabled = false;
  }
}
  /** 歌词播放器引擎 */
export class AmllLyricPlayerEngine {
  /** 渲染状态（由渲染层持有引用） */
  groups: AmllGroupState[] = [];
  interlude: AmllInterludeState = new AmllInterludeState();
  readonly size: [number, number] = [0, 0];
  baseFontSize: number = 24;

  isPlaying: boolean = false;
  isPageVisible: boolean = true;

  private dataManager: AmllLyricDataManager = new AmllLyricDataManager();
  private timelineController: AmllTimelineController = new AmllTimelineController();
  private layoutCalculator: AmllLayoutCalculator = new AmllLayoutCalculator();

  private layoutConfig: AmllLayoutConfig = {
    alignAnchor: AmllLayoutAlignAnchor.Center,
    alignPosition: 0.5,
    overscanPx: 150
  };

  private enableBlur: boolean = true;
  private enableScale: boolean = true;
  private hidePassedLines: boolean = false;
  private disableSpring: boolean = false;
  private wordFadeWidth: number = 0.5;
  private alwaysPostpositionBackground: boolean = false;

  private posYSpringParams: Partial<AmllSpringParamsLike> = {
    mass: 0.9,
    damping: 15,
    stiffness: 90
  };
  private scaleSpringParams: Partial<AmllSpringParamsLike> = {
    mass: 2,
    damping: 25,
    stiffness: 100
  };
  private scaleForBGSpringParams: Partial<AmllSpringParamsLike> = {
    mass: 1,
    damping: 20,
    stiffness: 50
  };

  /** 滚动状态 */
  isAutoAlignSuspended: boolean = false;
  isTouchScrolled: boolean = false;
  private scrollOffset: number = 0;
  private scrollMin: number = 0;
  private scrollMax: number = 0;

  private alignTarget: AmllFocalTarget = { type: 'line', index: 0 };
  private frameContext: AmllLayoutFrameContext = {
    containerHeight: 0,
    scrollOffset: 0,
    target: { type: 'line', index: 0 },
    bottomLineHeight: 0,
    interlude: undefined
  };

  private measuredMainHeights: number[] = [];
  private measuredSubHeights: number[] = [];
  private measuredBgHeights: number[] = [];

  /**
   * 子行（翻译/罗马音）收起/展开过渡：两个参数相同的弹簧错峰启动，两方向完全对称——
   * 展开：行高弹簧先行（主行铺开），副行弹簧延迟 SUB_SPRING_DELAY_S 后淡入；
   * 收起：副行弹簧先行（副行淡出），行高弹簧延迟后收拢（主行后动）。
   */
  private subHeightSpring: AmllSpring = new AmllSpring(1);
  private subFadeSpring: AmllSpring = new AmllSpring(1);
  private subShowTarget: number = 1;
  /** 副行弹簧相对行高弹簧的启动延迟（秒） */
  private static readonly SUB_SPRING_DELAY_S: number = 0.1;

  /** 最近一帧排版产生的视口起始 Y（内容坐标 → 视口坐标的偏移基准） */
  private viewportStartY: number = 0;

  /**
   * 首次拿到真实尺寸前的布局：size 为 0 时行高全 0，所有行重叠在同一位置；
   * 首次真实尺寸布局直接瞬移到位，避免弹簧从重叠位置展开（"堆到一行"再散开的闪烁）。
   */
  private pendingInitialLayout: boolean = true;

  /** 歌词数据重建（换歌等）后的布局直接瞬移，避免所有新行从同一位置弹簧展开 */
  private pendingRebuildSnap: boolean = false;

  /** 是否需要渲染层重绘（时间变化/弹簧运动） */
  needsRender: boolean = false;

  /** 间奏点透明度渐变是否仍在进行（暂停/拖动渐隐、恢复渐入期间帧循环需保持） */
  needsInterludeFade(): boolean {
    return this.interlude.enabled && this.interlude.alpha !== this.interlude.alphaTarget;
  }

  /** 用户主动跳转（点击歌词/拖动进度条）进入间奏：立即恢复不透明 */
  restoreInterlude(): void {
    this.interlude.alpha = 1;
    this.interlude.alphaTarget = 1;
  }

  /** 上次推进间奏点透明度的时刻（时间戳驱动，draw/update 均可推进） */
  private interludeFadeLastNow: number = 0;

  /** 按真实时间推进间奏点透明度（渐隐/渐入），拖动时由渲染层每帧调用 */
  advanceInterludeFade(nowMs: number): void {
    if (!this.interlude.enabled) {
      this.interludeFadeLastNow = nowMs;
      return;
    }
    let dt = nowMs - this.interludeFadeLastNow;
    this.interludeFadeLastNow = nowMs;
    if (dt <= 0 || dt > 100) {
      dt = 33;
    }
    if (this.interlude.alpha !== this.interlude.alphaTarget) {
      const fadeFactor = Math.min(1, dt / 300);
      this.interlude.alpha += (this.interlude.alphaTarget - this.interlude.alpha) * fadeFactor;
      if (Math.abs(this.interlude.alphaTarget - this.interlude.alpha) < 0.01) {
        this.interlude.alpha = this.interlude.alphaTarget;
      }
    }
  }

  getScrollOffset(): number {
    return this.scrollOffset;
  }

  getAlignPosition(): number {
    return this.layoutConfig.alignPosition;
  }

  /** 计算第 index 行在视口内的顶部 Y 坐标（用于点击定位） */
  getLineTopInViewport(index: number): number {
    if (index < 0 || index >= this.groups.length) {
      return 0;
    }
    let top = this.viewportStartY;
    for (let i = 0; i < index; i++) {
      top += this.layoutCalculator.getLineHeight(i);
    }
    return top;
  }

  getLineHeightAt(index: number): number {
    return this.layoutCalculator.getLineHeight(index);
  }

  /** 歌词是否非动态（逐行歌词） */
  get isNonDynamic(): boolean {
    return this.dataManager.getIsNonDynamic();
  }

  get hasDuetLine(): boolean {
    return this.dataManager.getHasDuetLine();
  }

  get processedLines(): AmllLyricLine[] {
    return this.dataManager.getProcessedLines();
  }

  get defaultLineHeight(): number {
    return this.size[1] / 5;
  }

  getCurrentTime(): number {
    return this.timelineController.getSnapshot().currentTime;
  }

  getTimelineSnapshot(): AmllTimelineSnapshot {
    return this.timelineController.getSnapshot();
  }

  // ==================== 配置 ====================

  setConfig(config: AmllEngineConfig): void {
    // 子行收起/展开过渡弹簧参数：轻过冲（约 8%），两弹簧相同保证对称
    this.subHeightSpring.updateParams({ mass: 1, damping: 15, stiffness: 200 });
    this.subFadeSpring.updateParams({ mass: 1, damping: 15, stiffness: 200 });
    // 点击圆角框弹性参数：低阻尼产生明显的弹出过冲
    this.focusSpring.updateParams({ mass: 1, damping: 9, stiffness: 150 });
    if (config.enableBlur !== undefined) {
      this.enableBlur = config.enableBlur;
    }
    if (config.enableScale !== undefined) {
      this.enableScale = config.enableScale;
    }
    if (config.hidePassedLines !== undefined) {
      this.hidePassedLines = config.hidePassedLines;
    }
    if (config.enableSpring !== undefined) {
      this.disableSpring = !config.enableSpring;
    }
    if (config.wordFadeWidth !== undefined) {
      this.wordFadeWidth = Math.max(0.0001, config.wordFadeWidth);
    }
    if (config.alignAnchor !== undefined) {
      this.layoutConfig.alignAnchor = config.alignAnchor;
    }
    if (config.alignPosition !== undefined) {
      this.layoutConfig.alignPosition = config.alignPosition;
    }
    if (config.overscanPx !== undefined) {
      this.layoutConfig.overscanPx = Math.max(0, config.overscanPx | 0);
    }
    if (config.maskMode !== undefined || config.maskChar !== undefined) {
      const maskMode = config.maskMode !== undefined ? config.maskMode : this.dataManager.getMaskMode();
      const maskChar = config.maskChar !== undefined ? config.maskChar : this.dataManager.getMaskChar();
      if (maskMode !== this.dataManager.getMaskMode() || maskChar !== this.dataManager.getMaskChar()) {
        this.dataManager.setConfig({
          maskMode: maskMode,
          maskChar: maskChar
        });
        if (this.dataManager.getRawLines().length > 0) {
          this.rebuildLyricView(this.getCurrentTime());
        }
      }
    }
    this.calcLayout(AmllLayoutReason.ConfigChange);
  }

  getEnableSpring(): boolean {
    return !this.disableSpring;
  }

  getEnableScale(): boolean {
    return this.enableScale;
  }

  getWordFadeWidth(): number {
    return this.wordFadeWidth;
  }

  setSeeking(isSeeking: boolean): void {
    this.timelineController.setSeekingState(isSeeking);
    this.updateSpringParams(this.timelineController.getSnapshot().activeInterlude !== undefined);
  }

  setAlwaysPostpositionBackground(enable: boolean): void {
    this.alwaysPostpositionBackground = enable;
    this.rebuildLyricView(this.getCurrentTime());
  }

  getAlwaysPostpositionBackground(): boolean {
    return this.alwaysPostpositionBackground;
  }

  // ==================== 歌词装载 ====================

  setLyricLines(lines: AmllLyricLine[], initialTime: number = 0): void {
    this.dataManager.setOriginalLines(lines);
    this.rebuildLyricView(initialTime);
  }

  getRawLines(): AmllLyricLine[] {
    return this.dataManager.getRawLines();
  }

  rebuildLyricView(initialTime: number): void {
    this.resetScroll();
    this.pendingRebuildSnap = true;
    this.alignTarget = { type: 'line', index: 0 };
    this.groups = [];
    this.interlude.reset();
    this.buildLyricGroups();
    this.groups.sort((a: AmllGroupState, b: AmllGroupState): number => a.startTime - b.startTime);
    for (let i = 0; i < this.groups.length; i++) {
      this.groups[i].index = i;
    }

    const bounds: AmllTimeBoundEntry[] = [];
    for (let i = 0; i < this.groups.length; i++) {
      const bound: AmllTimeBoundEntry = {
        startTime: this.groups[i].startTime,
        endTime: this.groups[i].endTime
      };
      bounds.push(bound);
    }
    this.timelineController.setTimeBounds(bounds);
    this.layoutCalculator.initHeights(this.groups.length, this.defaultLineHeight);

    this.measuredMainHeights = new Array<number>(this.groups.length).fill(0);
    this.measuredSubHeights = new Array<number>(this.groups.length).fill(0);
    this.measuredBgHeights = new Array<number>(this.groups.length).fill(0);
    // 换歌后子行进度直接对齐目标，不做过渡
    // 换歌后子行弹簧直接对齐目标，不做过渡
    this.subHeightSpring.setPosition(this.subShowTarget);
    this.subFadeSpring.setPosition(this.subShowTarget);
    // 清除可能残留的延迟启动队列
    this.subHeightSpring.setTargetPosition(this.subShowTarget, 0);
    this.subFadeSpring.setTargetPosition(this.subShowTarget, 0);
    // 换歌清除点击定位框
    this.focusIndex = -1;
    this.focusSpring.setPosition(0);

    this.setCurrentTime(initialTime, true);
    this.calcLayout(AmllLayoutReason.RebuildView);
    this.needsRender = true;
  }

  private buildLyricGroups(): void {
    const processed = this.dataManager.getProcessedLines();
    let currentGroup: AmllGroupState | undefined = undefined;
    for (let i = 0; i < processed.length; i++) {
      const line = processed[i];
      const lineState = new AmllLineRenderState(line, line.isBG);
      this.buildLineAtoms(lineState, line);
      if (!line.isBG || currentGroup === undefined) {
        currentGroup = new AmllGroupState(this.groups.length, lineState);
        // 背景行显示弹簧参数（与子行过渡一致：轻过冲，0.5s 内稳定）
        currentGroup.bgShow.updateParams({ mass: 1, damping: 15, stiffness: 200 });
        this.groups.push(currentGroup);
      } else {
        this.addBgLine(currentGroup, lineState);
      }
    }
  }

  private addBgLine(group: AmllGroupState, bgLine: AmllLineRenderState): void {
    group.bgLine = bgLine;
    // 用行级开始时间判断伴唱在上/在下：syncMainAndBackgroundLines 会把主行与伴唱
    // 时间同步为相等，此时若用词级时间判断，词的时序抖动会误判 isBgFirst，
    // 导致伴唱与预留空间出现在主行上方（"空错位置"）
    group.isBgFirst = bgLine.line.startTime < group.mainLine.line.startTime;
    group.bgShow.setPosition(0);
  }

  /** 构建一行的渲染原子与强调 chunk（对应 AMLL 的 chunkAndSplitLyricWords + buildWord） */
  private buildLineAtoms(lineState: AmllLineRenderState, line: AmllLyricLine): void {
    const atoms: AmllWordAtom[] = [];
    const chunks: AmllChunk[] = [];
    const chunked = amllChunkAndSplitLyricWords(line.words);
    let chunkId = 0;

    for (let c = 0; c < chunked.length; c++) {
      const item = chunked[c];
      const chunk: AmllLyricWord[] = Array.isArray(item) ? item : [item];
      const chunkAtoms: AmllWordAtom[] = [];
      let mergedStart = Number.POSITIVE_INFINITY;
      let mergedEnd = Number.NEGATIVE_INFINITY;
      let mergedText = '';
      let isPureSpace = true;
      for (let w = 0; w < chunk.length; w++) {
        const word = chunk[w];
        mergedStart = Math.min(mergedStart, word.startTime);
        mergedEnd = Math.max(mergedEnd, word.endTime);
        mergedText += word.word;
        if (word.word.trim().length > 0) {
          isPureSpace = false;
        }
      }
      if (isPureSpace) {
        const atom = new AmllWordAtom(
          mergedText, mergedStart, mergedEnd, true, chunkId
        );
        atoms.push(atom);
        chunkAtoms.push(atom);
      } else {
        let emp = false;
        for (let w = 0; w < chunk.length; w++) {
          if (this.shouldEmphasize(chunk[w])) {
            emp = true;
            break;
          }
        }
        if (!amllIsCJK(mergedText)) {
          const mergedWord: AmllLyricWord = {
            startTime: mergedStart,
            endTime: mergedEnd,
            word: mergedText
          };
          emp = emp || this.shouldEmphasize(mergedWord);
        }

        for (let w = 0; w < chunk.length; w++) {
          const word = chunk[w];
          const atom = new AmllWordAtom(
            word.word, word.startTime, word.endTime, false, chunkId
          );
          atoms.push(atom);
          chunkAtoms.push(atom);
        }

        if (emp) {
          const chunkObj = new AmllChunk(chunkId, mergedStart, mergedEnd, mergedText, true);
          // 强调动画参数（对应 initEmphasizeAnimation）
          let du = Math.max(1000, mergedEnd - mergedStart);
          let rubyCharCount = 0;
          for (let w = 0; w < chunk.length; w++) {
            const ruby = chunk[w].ruby;
            if (ruby !== undefined) {
              for (let r = 0; r < ruby.length; r++) {
                rubyCharCount += ruby[r].word.length;
              }
            }
          }
          let amount = du / 2000;
          amount = amount > 1 ? Math.sqrt(amount) : amount ** 3;
          let blur = du / 3000;
          blur = blur > 1 ? Math.sqrt(blur) : blur ** 3;
          amount *= 0.6;
          blur *= 0.5;
          if (line.words.length > 0 && mergedText.includes(line.words[line.words.length - 1].word)) {
            amount *= 1.6;
            blur *= 1.5;
            du *= 1.2;
          }
          amount = Math.min(1.2, amount);
          blur = Math.min(0.8, blur);
          chunkObj.du = du;
          chunkObj.amount = amount;
          chunkObj.blur = blur;

          // 每个单词的字符列表（先收集，后计算延迟，anchor 为全 chunk 字符数）
          const charGroups: string[][] = [];
          let totalChars = 0;
          for (let w = 0; w < chunkAtoms.length; w++) {
            const atom = chunkAtoms[w];
            if (atom.isPureSpace) {
              charGroups.push([]);
              continue;
            }
            const trimmed = atom.text.trim();
            const graphemes = amllSplitGraphemes(trimmed);
            charGroups.push(graphemes);
            totalChars += graphemes.length;
          }
          const anchorCharCount = rubyCharCount > 0 ? rubyCharCount : Math.max(1, totalChars);
          chunkObj.anchorCharCount = anchorCharCount;

          const allChars: AmllEmpChar[] = [];
          let charIndex = 0;
          // 强调动画的基准延迟是 chunk 级（对应原版 initEmphasizeAnimation 的 de = clampPositive(delay)）
          const wordDe = Math.max(0, mergedStart - line.startTime);
          for (let w = 0; w < chunkAtoms.length; w++) {
            const atom = chunkAtoms[w];
            const graphemes = charGroups[w];
            if (graphemes.length === 0) {
              continue;
            }
            for (let g = 0; g < graphemes.length; g++) {
              const charDelay = wordDe + (du / 2.5 / anchorCharCount) * charIndex;
              allChars.push(new AmllEmpChar(graphemes[g], charIndex, 0, charDelay));
              charIndex++;
            }
          }
          for (let i = 0; i < allChars.length; i++) {
            allChars[i].count = allChars.length;
          }
          chunkObj.chars = allChars;
          chunks.push(chunkObj);
        }
      }
      chunkId++;
    }
    lineState.atoms = atoms;
    lineState.chunks = chunks;
    for (let c = 0; c < chunks.length; c++) {
      lineState.chunkMap.set(chunks[c].id, chunks[c]);
    }
  }

  /** 判定歌词是否可以应用强调辉光效果（对应 AMLL LyricLineBase.shouldEmphasize） */
  private shouldEmphasize(word: AmllLyricWord): boolean {
    if (amllIsCJK(word.word)) {
      return word.endTime - word.startTime >= 1000;
    }
    return (
      word.endTime - word.startTime >= 1000 &&
      word.word.trim().length <= 7 &&
      word.word.trim().length > 1
    );
  }

  // ==================== 时间同步 ====================

  setCurrentTime(time: number, isSeek: boolean = false): void {
    time = Math.round(time);
    const diff = this.timelineController.sync(time, isSeek);
    if (!diff.hasChanged) {
      return;
    }
    for (let i = 0; i < diff.removedHighlighted.length; i++) {
      const g = this.groups[diff.removedHighlighted[i]];
      if (g !== undefined) {
        this.disableGroup(g);
      }
    }
    for (let i = 0; i < diff.addedHighlighted.length; i++) {
      const g = this.groups[diff.addedHighlighted[i]];
      if (g !== undefined) {
        this.enableGroup(g);
      }
    }
    if (diff.isTimeJumped) {
      if (!this.isTouchScrolled) {
        this.resetScroll();
      }
    }
    if (diff.isInterludeChanged || diff.isScrollToChanged || diff.isTimeJumped) {
      const isInterludeActive = this.timelineController.getSnapshot().activeInterlude !== undefined;
      this.updateSpringParams(isInterludeActive);
    }
    this.calcLayout(isSeek ? AmllLayoutReason.Seek : AmllLayoutReason.PlaybackTick);
    this.needsRender = true;
  }

  private enableGroup(group: AmllGroupState): void {
    group.mainLine.enabled = true;
    if (group.bgLine !== undefined) {
      group.bgLine.enabled = true;
    }
  }

  private disableGroup(group: AmllGroupState): void {
    group.mainLine.enabled = false;
    if (group.bgLine !== undefined) {
      group.bgLine.enabled = false;
    }
  }

  pause(): void {
    this.interlude.playing = false;
    if (this.isPlaying) {
      this.isPlaying = false;
      // 暂停：时间轴与画面定格，间奏点渐隐消失（不重排布局）
      this.interlude.alphaTarget = 0;
      this.needsRender = true;
    }
  }

  resume(): void {
    this.interlude.playing = true;
    this.interlude.alphaTarget = 1;
    if (!this.isPlaying) {
      this.isPlaying = true;
      // 恢复播放不重排布局：时间未跳变，布局与暂停前一致；
      // 重排可能因残留交互状态把间奏点判定为不可见（闪/消失）
      this.needsRender = true;
    }
  }

  setPlaying(isPlaying: boolean): void {
    if (isPlaying) {
      this.resume();
    } else {
      this.pause();
    }
  }

  // ==================== 弹簧参数 ====================

  private updateSpringParams(isInterludeActive: boolean): void {
    if (!this.getEnableSpring() || this.groups.length === 0) {
      return;
    }
    const snapshot = this.timelineController.getSnapshot();
    const currentGroup = this.groups[snapshot.scrollToIndex];
    const prevGroup = this.groups[snapshot.scrollToIndex - 1];
    let interval: number | undefined = undefined;
    if (currentGroup !== undefined && prevGroup !== undefined) {
      interval = currentGroup.startTime - prevGroup.startTime;
    }
    const policy = amllGetPosYSpringPolicy(snapshot.isSeeking, isInterludeActive, interval);
    this.setLinePosYSpringParams(policy);
  }

  private setLinePosYSpringParams(params: Partial<AmllSpringParamsLike>): void {
    this.posYSpringParams = amllMergeSpringParams(this.posYSpringParams, params);
    this.interlude.topSpring.updateParams(this.posYSpringParams);
    for (let i = 0; i < this.groups.length; i++) {
      this.groups[i].posY.updateParams(this.posYSpringParams);
    }
  }

  setLineScaleSpringParams(params: Partial<AmllSpringParamsLike>): void {
    this.scaleSpringParams = amllMergeSpringParams(this.scaleSpringParams, params);
    this.scaleForBGSpringParams = amllMergeSpringParams(this.scaleForBGSpringParams, params);
    for (let i = 0; i < this.groups.length; i++) {
      const group = this.groups[i];
      group.mainLine.scale.updateParams(this.scaleSpringParams);
      if (group.bgLine !== undefined) {
        group.bgLine.scale.updateParams(this.scaleForBGSpringParams);
      }
    }
  }

  // ==================== 滚动 ====================

  /** 由视图手势驱动 */
  onScrollInteractionStart(): void {
    this.isAutoAlignSuspended = true;
    this.isTouchScrolled = true;
    // 拖动期间间奏点渐隐
    this.interlude.alphaTarget = 0;
    // 拖动开始立即清空残留模糊（快滑时远处高模糊行进入视口不至于长时间模糊）
    for (let i = 0; i < this.groups.length; i++) {
      this.groups[i].blur = 0;
      this.groups[i].blurTarget = 0;
    }
    this.calcLayout(AmllLayoutReason.InteractionStart);
    this.needsRender = true;
  }

  /** 由视图手势驱动；返回钳制后的滚动偏移 */
  setScrollOffset(offset: number, isContinuous: boolean): number {
    this.scrollOffset = this.clampOffset(offset);
    this.calcLayout(isContinuous ? AmllLayoutReason.ContinuousScroll : AmllLayoutReason.DiscreteScroll);
    this.needsRender = true;
    return this.scrollOffset;
  }

  onScrollInteractionEnd(): void {
    // 拖动结束：间奏点渐入恢复
    this.interlude.alphaTarget = 1;
    this.calcLayout(AmllLayoutReason.InteractionEnd);
    this.needsRender = true;
  }

  onAutoAlignResume(): void {
    this.isAutoAlignSuspended = false;
    this.isTouchScrolled = false;
    this.interlude.alphaTarget = 1;
    this.resetScroll();
    this.calcLayout(AmllLayoutReason.InteractionEnd);
    this.needsRender = true;
  }

  resetScroll(): void {
    this.scrollOffset = this.clampOffset(0);
    this.isAutoAlignSuspended = false;
    this.isTouchScrolled = false;
  }

  private clampOffset(val: number): number {
    const min = Math.min(this.scrollMin, this.scrollMax);
    const max = Math.max(this.scrollMin, this.scrollMax);
    return Math.min(Math.max(val, min), max);
  }

  // ==================== 尺寸 ====================

  onResize(width: number, height: number): void {
    this.size[0] = width;
    this.size[1] = height;
    this.layoutCalculator.updateUnmeasuredHeights(this.defaultLineHeight);
    this.calcLayout(AmllLayoutReason.Resize);
    this.needsRender = true;
  }

  /** 渲染层上报测量的主行块高度 */
  setMeasuredMainHeight(index: number, height: number): void {
    if (index < 0 || index >= this.groups.length) {
      return;
    }
    if (this.measuredMainHeights[index] !== height) {
      this.measuredMainHeights[index] = height;
      this.updateGroupHeight(index);
    }
  }

  /** 渲染层上报测量的子行（翻译/罗马音）高度 */
  setMeasuredSubHeight(index: number, height: number): void {
    if (index < 0 || index >= this.groups.length) {
      return;
    }
    if (this.measuredSubHeights[index] !== height) {
      this.measuredSubHeights[index] = height;
      this.updateGroupHeight(index);
    }
  }

  setMeasuredBgHeight(index: number, height: number): void {
    if (index < 0 || index >= this.groups.length) {
      return;
    }
    if (this.measuredBgHeights[index] !== height) {
      this.measuredBgHeights[index] = height;
      this.updateGroupHeight(index);
    }
  }

  /** 组激活状态变化后需要重新计算组高度（背景行在激活时进入文档流） */
  updateGroupHeightsForActive(): void {
    for (let i = 0; i < this.groups.length; i++) {
      this.updateGroupHeight(i);
    }
  }

  private updateGroupHeight(index: number): void {
    const group = this.groups[index];
    // 行高随行高弹簧插值；收起方向由触底吸收处理（见 update），此处只需钳制非负
    const progress = Math.max(0, this.subHeightSpring.getCurrentPosition());
    let h = this.measuredMainHeights[index] + this.measuredSubHeights[index] * progress;
    const bgH = this.measuredBgHeights[index];
    // 背景人声行高度随显示弹簧插值，过渡平滑不瞬跳
    if (group.bgLine !== undefined && bgH > 0) {
      h += bgH * Math.max(0, group.bgShow.getCurrentPosition());
    }
    if (h > 0) {
      this.layoutCalculator.setLineHeight(index, h);
    }
  }

  /** 设置子行（翻译/罗马音）显示状态，触发收起/展开过渡（双弹簧错峰，完全对称） */
  setSubLineVisibility(show: boolean): void {
    this.subShowTarget = show ? 1 : 0;
    if (show) {
      // 展开：主行行高先行，副行稍后淡入
      this.subHeightSpring.setTargetPosition(1, 0);
      this.subFadeSpring.setTargetPosition(1, AmllLyricPlayerEngine.SUB_SPRING_DELAY_S);
    } else {
      // 收起：副行先行淡出，主行行高稍后收拢
      this.subFadeSpring.setTargetPosition(0, 0);
      this.subHeightSpring.setTargetPosition(0, AmllLyricPlayerEngine.SUB_SPRING_DELAY_S);
    }
    this.needsRender = true;
  }

  /** 子行显示进度（渲染层用于淡入淡出，直接取副行弹簧位置） */
  getSubShowProgress(): number {
    return this.subFadeSpring.getCurrentPosition();
  }

  /** 子行高度进度（行高弹簧位置，渲染层用于把伴唱定位到副行下方） */
  getSubHeightProgress(): number {
    return this.subHeightSpring.getCurrentPosition();
  }

  /** 子行收起/展开过渡是否进行中（帧循环需保持运行，暂停时也要推进动画） */
  isSubTransitionActive(): boolean {
    return !this.subHeightSpring.arrived() || !this.subFadeSpring.arrived();
  }

  // ==================== 点击定位圆角框 ====================

  /** 点击定位的目标行索引（-1 = 无） */
  private focusIndex: number = -1;
  /** 圆角框显示弹簧：0=隐藏，1=完全显示（弹性弹出，轻微过冲） */
  private focusSpring: AmllSpring = new AmllSpring(0);

  /** 点击歌词行：显示弹性圆角框包住该行（主行+副行） */
  setFocusLine(index: number): void {
    if (index < 0 || index >= this.groups.length) {
      return;
    }
    this.focusIndex = index;
    this.focusSpring.setTargetPosition(1);
    this.needsRender = true;
  }

  /** 隐藏圆角框（淡出） */
  clearFocus(): void {
    this.focusSpring.setTargetPosition(0);
    this.needsRender = true;
  }

  /** 点击定位的目标行索引 */
  getFocusIndex(): number {
    return this.focusIndex;
  }

  /** 圆角框显示进度（0~1，含弹性过冲） */
  getFocusShowProgress(): number {
    return this.focusSpring.getCurrentPosition();
  }

  /** 是否有行/弹簧仍在运动中（帧循环需保持运行直到完全静止，暂停时也要走完） */
  hasMovingSprings(): boolean {
    if (!this.focusSpring.arrived()) {
      return true;
    }
    for (let i = 0; i < this.groups.length; i++) {
      const group = this.groups[i];
      if (group.posMoving || !group.posY.arrived() || !group.bgShow.arrived() ||
        !group.mainLine.scale.arrived() ||
        (group.bgLine !== undefined && !group.bgLine.scale.arrived())) {
        return true;
      }
    }
    return false;
  }

  /** 是否有伴唱的显示弹簧仍在动画中（排版需保持瞬移跟随，防止弹簧队列冻结） */
  hasAnimatingBg(): boolean {
    for (let i = 0; i < this.groups.length; i++) {
      const group = this.groups[i];
      if (group.bgLine !== undefined && !group.bgShow.arrived()) {
        return true;
      }
    }
    return false;
  }

  getLineHeight(index: number): number {
    return this.layoutCalculator.getLineHeight(index);
  }

  getOverscanPx(): number {
    return this.layoutConfig.overscanPx;
  }

  // ==================== 排版 ====================

  calcLayout(reason: AmllLayoutReason): void {
    const strategy = amllLayoutStrategyFor(reason);
    // 首次真实尺寸 / 歌词重建：直接瞬移，不经过弹簧（避免从 0 高度重叠位置展开）
    const hasRealSize = this.size[0] > 0 && this.size[1] > 0;
    const snapInitial = this.pendingInitialLayout && hasRealSize;
    if (snapInitial) {
      this.pendingInitialLayout = false;
    }
    const snapRebuild = this.pendingRebuildSnap;
    if (snapRebuild) {
      this.pendingRebuildSnap = false;
    }
    // 子行/伴唱收起展开过渡期间：不用瞬移、不走 stagger 延时队列——
    // 目标每帧实时更新（delay=0），弹簧平滑跟随行高插值，
    // 主行保持在中央、其余行随行高自然展开/收起（与间奏呼吸同理）；
    // 若带延时排队，每帧 calcLayout 会重置队列计时器导致弹簧冻结
    const transitionActive = this.isSubTransitionActive() || this.hasAnimatingBg();
    const snapPosYNow = strategy.snapPosY || snapInitial || snapRebuild;
    const snapshot = this.timelineController.getSnapshot();
    const interlude = snapshot.activeInterlude;
    const isInterludeFocused = snapshot.isFocusOnInterlude && interlude !== undefined;
    const count = this.groups.length;
    const maxValidIndex = Math.max(0, count - 1);
    const clampLineIndex = (index: number): number =>
      count > 0 ? Math.min(Math.max(0, index), maxValidIndex) : 0;

    const safeScrollToIndex = clampLineIndex(snapshot.scrollToIndex);

    let focalTarget: AmllFocalTarget = { type: 'line', index: safeScrollToIndex };

    if (this.isAutoAlignSuspended) {
      const target = this.alignTarget;
      if (target.type === 'line') {
        focalTarget = { type: 'line', index: clampLineIndex(target.index) };
      } else if (target.type === 'interlude') {
        if (!isInterludeFocused) {
          focalTarget = {
            type: 'line',
            index: clampLineIndex(target.anchorIndex + 1)
          };
        } else {
          focalTarget = target;
        }
      } else {
        focalTarget = target;
      }
    } else {
      if (isInterludeFocused && interlude !== undefined) {
        focalTarget = {
          type: 'interlude',
          anchorIndex: interlude.anchorLineIndex
        };
      } else if (snapshot.isEndOfSong) {
        if (count > 0) {
          focalTarget = { type: 'line', index: count - 1 };
        }
      }
    }

    this.alignTarget = focalTarget;

    const fontSize = this.baseFontSize || 24;
    const dotMargin = fontSize * 0.4;
    const totalInterludeHeight =
      this.interludeDotsHeight + dotMargin * 2;

    const ctx = this.frameContext;
    ctx.containerHeight = this.size[1];
    ctx.target = focalTarget;
    ctx.bottomLineHeight = 0;

    const interludeAnchorIndex = AmllLayoutCalculator.resolveInterludeAnchorIndex(
      interlude,
      focalTarget
    );
    if (interludeAnchorIndex !== undefined) {
      if (ctx.interlude === undefined) {
        const frame: AmllFrameInterlude = { totalHeight: 0, anchorIndex: 0 };
        ctx.interlude = frame;
      }
      ctx.interlude.totalHeight = totalInterludeHeight;
      ctx.interlude.anchorIndex = interludeAnchorIndex;
    } else {
      ctx.interlude = undefined;
    }

    const frameResult = this.layoutCalculator.beginFrame(ctx, this.layoutConfig);
    this.scrollMin = frameResult.bounds.min;
    this.scrollMax = frameResult.bounds.max;
    this.scrollOffset = this.clampOffset(this.scrollOffset);
    ctx.scrollOffset = this.scrollOffset;
    const result = this.layoutCalculator.commit(frameResult.session, ctx.scrollOffset);
    if (frameResult.session.isValid) {
      this.viewportStartY =
        this.size[1] * this.layoutConfig.alignPosition -
        frameResult.session.anchorOffset -
        this.scrollOffset -
        frameResult.session.focalTopY;
    }

    // 间奏点（进入前的 enabled 状态用于首次定位）
    const wasInterludeEnabled = this.interlude.enabled;
    if (result.hasInterlude && interlude !== undefined) {
      const shouldResetAnimation =
        snapshot.isSeeking || strategy.resetInterlude;
      this.setInterlude(
        [interlude.startTime, interlude.endTime],
        snapshot.currentTime,
        shouldResetAnimation
      );
    } else {
      this.interlude.enabled = false;
      this.interlude.currentInterlude = undefined;
    }

    // 歌词行视觉状态
    const fallbackFocusIndex = snapshot.scrollToIndex;
    const latestIndex = snapshot.latestHighlightedIndex !== undefined
      ? snapshot.latestHighlightedIndex
      : fallbackFocusIndex;
    const activeCount = result.lineCount;

    let delay = 0;
    let baseDelay = strategy.disableStagger ? 0 : 0.05;

    let activeChanged = false;

    for (let i = 0; i < activeCount; i++) {
      const group = this.groups[i];
      const instruction = result.lineInstructions[i];
      const curPos = instruction.y;

      const hasHighlighted = snapshot.highlightedGroups.has(i);
      const isActive = hasHighlighted || (i >= snapshot.scrollToIndex && i < latestIndex);
      const blurFocusIndex = snapshot.isTimelineEmpty ? fallbackFocusIndex : latestIndex;

      let blurLevel = 0;
      let targetOpacity = 1;

      if (!instruction.isInViewport) {
        // 视口外：按超出距离指数延续（不被截断）
        const outDist = i < snapshot.scrollToIndex
          ? snapshot.scrollToIndex - i
          : i - blurFocusIndex;
        blurLevel = this.enableBlur ? 3 * Math.pow(2, outDist) : 0;
        targetOpacity = 0;
      } else {
        if (this.enableBlur && !this.isTouchScrolled && !isActive) {
          // 指数递增：离中心每远一行 ×2
          const dist = i < snapshot.scrollToIndex
            ? snapshot.scrollToIndex - i
            : i - blurFocusIndex;
          blurLevel = 3 * Math.pow(2, dist);
          blurLevel *= 0.8;
        }
        if (this.hidePassedLines) {
          if (
            i < (interlude !== undefined ? interlude.anchorLineIndex + 1 : snapshot.scrollToIndex) &&
            this.isPlaying
          ) {
            targetOpacity = 1e-4;
          } else if (hasHighlighted) {
            // 非动态行的明暗由渲染层 alpha 渐变控制，这里保持不透明度 1，避免两层亮度硬切闪烁
            targetOpacity = this.isNonDynamic ? 1 : 0.85;
      // 主动 seek 进入/停留在间奏：恢复不透明（拖动/暂停等交互状态不在此列）
      if (snapshot.isSeeking) {
        this.interlude.alpha = 1;
        this.interlude.alphaTarget = 1;
      }
    } else {
            targetOpacity = 1;
          }
        } else if (hasHighlighted) {
          // 非动态行的明暗由渲染层 alpha 渐变控制，这里保持不透明度 1，避免两层亮度硬切闪烁
          targetOpacity = this.isNonDynamic ? 1 : 0.85;
        } else {
          targetOpacity = 1;
        }
      }

      // 关闭模糊效果时：上下行用透明度过渡（中心清晰、越远越淡），保持视觉层次
      if (!this.enableBlur && !isActive && targetOpacity > 0) {
        const blurDist = i < snapshot.scrollToIndex
          ? snapshot.scrollToIndex - i
          : i - blurFocusIndex;
        targetOpacity *= 1 - Math.min(0.35, blurDist * 0.08);
      }

      const scaleImmediate = (strategy.snapPosY && !this.isAutoAlignSuspended) || snapInitial || snapRebuild;
      if (group.isActive !== isActive) {
        group.isActive = isActive;
        activeChanged = true;
      }

      // 过渡期间目标实时更新、不走延时队列（否则每帧 calcLayout 重置队列导致冻结）
      const posDelay = transitionActive ? 0 : delay;

      this.applyGroupTransform(
        group,
        curPos,
        snapPosYNow,
        posDelay,
        isActive,
        targetOpacity,
        blurLevel,
        scaleImmediate
      );

      const lineH = instruction.height;
      if (curPos + lineH >= 0 && !snapshot.isSeeking) {
        delay += baseDelay;
        if (i >= snapshot.scrollToIndex) {
          baseDelay /= 1.05;
        }
      }
    }

    if (activeChanged) {
      this.updateGroupHeightsForActive();
    }

    // 可见性
    const ov = this.getOverscanPx();
    const pb = this.size[1];
    for (let i = 0; i < activeCount; i++) {
      const group = this.groups[i];
      const t = group.posY.getCurrentPosition();
      const h = this.layoutCalculator.getLineHeight(i);
      group.isInSight = !(t > pb + h + ov || t < -h - ov);
    }

    // 间奏点弹簧定位（放在行布局之后，可用锚点行本次布局的 top）
    if (result.hasInterlude && interlude !== undefined) {
      const nextLineIndex = interlude.anchorLineIndex + 1;
      const nextGroup = this.groups[nextLineIndex];
      const isNextDuet = nextGroup !== undefined && nextGroup.mainLine.line.isDuet;
      this.interlude.left = isNextDuet
        ? this.size[0] - this.interludeDotsWidth
        : 0;
      const targetTop = result.interludeY + dotMargin;
      if (!wasInterludeEnabled) {
        // 首次进入间奏：从锚点行当前视口位置长出（+固定偏移），与歌词行同步滑动，不瞬跳
        const anchorGroup = this.groups[interlude.anchorLineIndex];
        if (anchorGroup !== undefined) {
          const startTop = anchorGroup.posY.getCurrentPosition() +
            (targetTop - anchorGroup.top);
          this.interlude.topSpring.setPosition(startTop);
          this.interlude.top = startTop;
        }
      }
      this.interlude.topSpring.setTargetPosition(targetTop);
    }
  }

  private applyGroupTransform(
    group: AmllGroupState,
    top: number,
    immediate: boolean,
    delay: number,
    isActive: boolean,
    opacity: number,
    blur: number,
    scaleImmediate: boolean
  ): void {
    group.top = top;
    group.delay = delay;
    group.opacity = opacity;
    group.blurTarget = blur;

    this.applyLineTransforms(group, scaleImmediate, delay);

    const enableSpring = this.getEnableSpring();
    // 背景人声行显示目标：只跟随激活状态展开/收起（拖动回弹/暂停后不再残留显示）
    const bgShowTarget = isActive ? 1 : 0;

    if (immediate || !enableSpring) {
      group.posY.setPosition(top);
    } else {
      group.posY.setTargetPosition(top, delay);
    }
    // 背景人声行显示弹簧：目标不变时不重复设置（每帧 calcLayout 重复排队会把
    // 队列计时器一直重置，弹簧冻结导致歌词"定住"不滚动）；目标变化时立即启动
    if (group.bgShow.getTargetPosition() !== bgShowTarget) {
      if (immediate || !enableSpring) {
        group.bgShow.setPosition(bgShowTarget);
      } else {
        group.bgShow.setTargetPosition(bgShowTarget, 0);
      }
    }
    group.posMoving = true;
  }

  private applyLineTransforms(group: AmllGroupState, immediate: boolean, delay: number): void {
    const enableScale = this.getEnableScale();
    // 缩放与播放状态无关（暂停时保持同一视觉状态，避免 resume 瞬间画面跳动）
    const SCALE_ASPECT = enableScale ? 97 : 100;
    let mainScale = SCALE_ASPECT;
    if (group.isActive) {
      mainScale = 100;
    }
    this.applyLineScale(group.mainLine, mainScale, immediate, delay);

    let bgScale = 75;
    if (group.isActive) {
      bgScale = 100;
    }
    if (group.bgLine !== undefined) {
      this.applyLineScale(group.bgLine, bgScale, immediate, delay);
    }
  }

  private applyLineScale(line: AmllLineRenderState, scale: number, immediate: boolean, delay: number): void {
    if (immediate || !this.getEnableSpring()) {
      line.scale.setPosition(scale);
    } else {
      line.scale.setTargetPosition(scale);
    }
  }

  // ==================== 间奏点 ====================

  /** 间奏点尺寸（渲染层测量后填入） */
  interludeDotsWidth: number = 0;
  interludeDotsHeight: number = 0;

  setInterludeDotsSize(w: number, h: number): void {
    if (this.interludeDotsWidth !== w || this.interludeDotsHeight !== h) {
      this.interludeDotsWidth = w;
      this.interludeDotsHeight = h;
      this.calcLayout(AmllLayoutReason.Resize);
    }
  }

  /** 设置间奏点动画区间并重新锚定时间 */
  private setInterlude(
    interlude: [number, number],
    currentTime: number,
    forceReset: boolean
  ): void {
    const endTime = interlude[1];
    const now = currentTime !== undefined ? currentTime : interlude[0];
    const isNewInterlude =
      this.interlude.currentInterlude === undefined ||
      this.interlude.currentInterlude[1] !== endTime;
    const shouldReset = forceReset || isNewInterlude;
    if (shouldReset) {
      this.interlude.currentInterlude = [now, endTime];
      this.interlude.currentTime = now;
      // 仅首次进入间奏时恢复不透明；暂停/拖动/resume 中的布局刷新不重置透明度，
      // 保持渐隐/渐入状态（resume 的渐入由 alphaTarget=1 驱动，重置会导致瞬间出现闪烁）
      if (isNewInterlude) {
        this.interlude.alpha = 1;
        this.interlude.alphaTarget = 1;
      }
    }
    this.interlude.enabled = true;
  }

  // ==================== 逐帧更新 ====================

  /**
   * 逐帧更新弹簧与间奏点动画。
   * @param delta 距上一帧的毫秒数
   */
  update(deltaMs: number): void {
    const deltaS = deltaMs / 1000;
    let anyMoving = false;

    if (this.getEnableSpring()) {
      for (let i = 0; i < this.groups.length; i++) {
        const group = this.groups[i];
        const posArrived = group.posY.arrived();
        const bgShowArrived = group.bgShow.arrived();
        const scaleArrived = group.mainLine.scale.arrived();
        const bgScaleArrived = group.bgLine === undefined || group.bgLine.scale.arrived();
        const blurSettled = Math.abs(group.blurTarget - group.blur) < 0.01;
        if (posArrived && bgShowArrived && scaleArrived && bgScaleArrived && blurSettled) {
          group.posMoving = false;
          continue;
        }

        const posMoving = !posArrived;
        const bgShowMoving = !bgShowArrived;
        group.posY.update(deltaS);
        group.bgShow.update(deltaS);
        if (posMoving || bgShowMoving) {
          group.posMoving = true;
          anyMoving = true;
        } else {
          group.posMoving = false;
        }
        const scaleMoving = !scaleArrived;
        if (!scaleArrived) {
          group.mainLine.scale.update(deltaS);
        }
        if (group.bgLine !== undefined && !bgScaleArrived) {
          group.bgLine.scale.update(deltaS);
        }
        if (scaleMoving) {
          anyMoving = true;
        }
        if (!blurSettled) {
          const factor = Math.min(1, deltaMs / 120);
          group.blur += (group.blurTarget - group.blur) * factor;
          if (Math.abs(group.blurTarget - group.blur) < 0.01) {
            group.blur = group.blurTarget;
          }
          anyMoving = true;
        }
      }
    }

    // 背景人声行显示过渡：行高随 bgShow 弹簧插值，过渡期间每帧重排（避免行高瞬跳）
    let bgAnimating = false;
    for (let i = 0; i < this.groups.length; i++) {
      const group = this.groups[i];
      if (group.bgLine !== undefined && !group.bgShow.arrived()) {
        bgAnimating = true;
      }
    }
    if (bgAnimating) {
      this.updateGroupHeightsForActive();
      this.calcLayout(AmllLayoutReason.PlaybackTick);
      this.needsRender = true;
    }

    // 子行收起/展开过渡：双弹簧推进（行高弹簧 + 副行弹簧，错峰启动，完全对称），
    // 位置瞬移跟随行高插值，行高随弹簧进度每帧重排
    if (!this.subHeightSpring.arrived() || !this.subFadeSpring.arrived()) {
      this.subHeightSpring.update(deltaS);
      // 收起方向触底回弹：行高没有低于 0 的显示空间，下探穿过 0 时速度反向并衰减，
      // 弹起一个小幅度后自然回落（仅下探时反射一次，上升过程不重复反射，
      // 否则每帧反转速度会导致弹簧在 0 附近抖动、永远弹不起来）
      if (this.subShowTarget === 0 && this.subHeightSpring.getCurrentPosition() <= 0 &&
        this.subHeightSpring.getCurrentVelocity() < -0.01) {
        this.subHeightSpring.reflectAtCurrentPosition(0.4);
      }
      this.subFadeSpring.update(deltaS);
      this.updateGroupHeightsForActive();
      this.calcLayout(AmllLayoutReason.PlaybackTick);
      this.needsRender = true;
    }

    // 点击定位圆角框弹簧推进（弹性弹出/淡出）
    if (!this.focusSpring.arrived()) {
      this.focusSpring.update(deltaS);
      this.needsRender = true;
    }

    if (this.interlude.playing) {
      this.interlude.currentTime += deltaMs;
    }
    if (this.interlude.enabled) {
      // 间奏点位置弹簧推进（与歌词行 posY 同参数，滚动时严格同步）
      this.interlude.topSpring.update(deltaS);
      this.interlude.top = this.interlude.topSpring.getCurrentPosition();
      anyMoving = true;
    }

    // 间奏点透明度推进（时间戳驱动）
    this.advanceInterludeFade(Date.now());

    if (anyMoving) {
      this.needsRender = true;
    }
  }
}

/** 弹簧参数（与 AmllSpringParams 部分字段） */
interface AmllSpringParamsLike {
  mass: number;
  damping: number;
  stiffness: number;
  soft: boolean;
}

