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
 * AMLL 歌词视图组件（ArkUI 版）。
 *
 * 忠实复刻 applemusic-like-lyrics 的核心组件：
 * - Canvas 渲染逐词扫描高亮、强调动画、距离模糊、间奏点
 * - 物理弹簧滚动 + 触摸拖动 + 惯性 + 5 秒自动对齐回归
 * - 点击歌词行跳转
 */
import { AmllLyricLine } from '../model/AmllTypes';
import { AmllLyricPlayerEngine, AmllGroupState } from '../core/AmllLyricPlayerEngine';
import { AmllCanvasLyricRenderer, AmllRenderStyle } from './AmllCanvasLyricRenderer';
import { AmllLayoutAlignAnchor } from '../core/AmllConsts';
import { AppStorageKeys, Logger, LyricCenterState, LyricFpsState, MusicStoreService, ShowSubLyricState, WindowUtil } from 'musicbasic';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { AppStorageV2, FrameCallback, window } from '@kit.ArkUI';

/** 触摸拖动意图阈值（对应 AMLL 的 10px） */
const TOUCH_INTENT_PX: number = 10;
/** 惯性停止速度阈值 */
const INERTIA_STOP_SPEED: number = 0.05;
/** 惯性速度衰减（对应 0.95^(dt/16)） */
const INERTIA_DECAY: number = 0.95;
/** 松手后自动对齐回归延迟（毫秒） */
const AUTO_ALIGN_DELAY_MS: number = 3000;
/** 帧间隔兜底值（毫秒，120Hz 设备 vsync 间隔 ≈8.3ms）；实际帧率由 postFrameCallback 跟随屏幕刷新率 */
const FRAME_INTERVAL_MS: number = 8;
/** 本地时钟与外部进度的最大偏差（毫秒），超过则视为跳转 */
const CLOCK_DRIFT_LIMIT_MS: number = 250;

/**
 * VSync 帧回调（由 UIContext.postFrameCallback 驱动，跟随屏幕刷新率：
 * 60Hz 设备 60FPS、120Hz 设备 120FPS；窗口不可见时系统自动暂停回调）。
 */
class FrameTicker extends FrameCallback {
  private onTick: () => void = (): void => {
  };

  public setTick(callback: () => void): void {
    this.onTick = callback;
  }

  onFrame(frameTimeInNano: number): void {
    this.onTick();
  }
}

@ComponentV2
export struct AmllLyricView {
  /** 歌词行（AMLL 数据模型） */
  @Param @Require lyricLines: AmllLyricLine[] = [];
  /** 外部播放进度（毫秒） */
  @Param @Require currentTime: number = 0;
  /** 是否正在播放 */
  @Param @Require isPlay: boolean = false;
  /** 点击歌词行回调（毫秒） */
  @Param onSeekTime: (ms: number) => void = (ms: number): void => {};
  /** 主歌词字号（vp） */
  @Param fontSize: number = 28;
  /** 字体粗细 */
  @Param fontWeight: string = 'Medium';
  /** 歌词文本颜色（hex） */
  @Param textColor: string = '#FFFFFF';
  /** 强调辉光颜色（hex） */
  @Param glowColor: string = '#FFFFFF';
  /** 歌词列宽度比例 */
  @Param lineWidthAspect: number = 0.8;
  /** 是否启用距离模糊 */
  @Param enableBlur: boolean = true;
  /** 是否启用非当前行缩放 */
  @Param enableScale: boolean = true;
  /** 是否隐藏已播放的行 */
  @Param hidePassedLines: boolean = false;
  /** 是否显示翻译/罗马音子行（由翻译按钮控制） */
  @Param showSubLyric: boolean = true;
  @Local showSubLyricState: ShowSubLyricState =
    AppStorageV2.connect(ShowSubLyricState, AppStorageKeys.SHOW_SUB_LYRIC_STATE, () => new ShowSubLyricState())!;
  /** 是否启用物理弹簧 */
  @Param enableSpring: boolean = true;
  /** 文字动画渐变宽度（主文字字体大小倍数） */
  @Param wordFadeWidth: number = 0.5;
  /** 内容起始偏移（上方留白） */
  @Param contentStartOffset: number = 40;
  /** 内容结束偏移（下方留白） */
  @Param contentEndOffset: number = 200;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private engine: AmllLyricPlayerEngine = new AmllLyricPlayerEngine();
  private renderer: AmllCanvasLyricRenderer | undefined = undefined;
  private frameTicker: FrameTicker = new FrameTicker();
  private lastFrameTime: number = 0;
  private isFrameLoopRunning: boolean = false;
  /** 本地播放时钟（毫秒） */
  private localTime: number = 0;
  private lastExternalTime: number = 0;
  /** 点击歌词跳转后，等待音频真正 seek 到目标行期间暂停本地时钟推进，避免高亮抢跑又跳回。 */
  private isSeeking: boolean = false;
  private seekTarget: number = 0;
  private viewWidth: number = 0;
  private viewHeight: number = 0;
  private engineInited: boolean = false;
  private rendererInited: boolean = false;

  // 触摸状态
  private panStartOffset: number = 0;
  private panStartY: number = 0;
  private panLastY: number = 0;
  private panStartTime: number = 0;
  private panSpeed: number = 0;
  private isIntentConfirmed: boolean = false;
  private isInteracting: boolean = false;
  /** 惯性进行中 */
  private inertiaActive: boolean = false;
  private inertiaTimer: number = 0;
  /** 应用是否处于后台（隐藏）：后台停掉帧循环，避免 30FPS 全量 Canvas 重绘空转 */
  private isWindowHidden: boolean = false;
  /** WindowStage 句柄（windowStageEvent 监听用） */
  private windowStageHandle: window.WindowStage | undefined = undefined;
  /** 歌词渲染帧率上限（设置页可调）：0=不限制（跟随屏幕刷新率） */
  private fpsLimit: number = 120;
  /** 设置页共享的帧率状态（60/90/120/144/165） */
  @Local lyricFpsState: LyricFpsState =
    AppStorageV2.connect(LyricFpsState, AppStorageKeys.LYRIC_FPS_STATE, () => new LyricFpsState())!;
  /** 设置页共享的歌词居中开关（对唱行保持左右布局） */
  @Local lyricCenterState: LyricCenterState =
    AppStorageV2.connect(LyricCenterState, AppStorageKeys.LYRIC_CENTER_STATE, () => new LyricCenterState())!;

  @Monitor('lyricFpsState.fps')
  onLyricFpsChanged(): void {
    this.fpsLimit = this.lyricFpsState.fps;
  }

  @Monitor('lyricCenterState.enabled')
  onLyricCenterChanged(): void {
    if (this.renderer !== undefined) {
      this.renderer.setLyricCenterEnabled(this.lyricCenterState.enabled);
    }
  }

  /** windowStageEvent 回调：SHOWN=回前台，HIDDEN=退后台 */
  private windowStageCallback: (event: window.WindowStageEventType) => void =
    (event: window.WindowStageEventType): void => {
      if (event === window.WindowStageEventType.HIDDEN) {
        this.onWindowHidden();
      } else if (event === window.WindowStageEventType.SHOWN) {
        this.onWindowShown();
      }
    };

  aboutToAppear(): void {
    this.engine.setConfig({
      enableBlur: this.enableBlur,
      enableScale: this.enableScale,
      hidePassedLines: this.hidePassedLines,
      enableSpring: this.enableSpring,
      wordFadeWidth: this.wordFadeWidth,
      alignAnchor: AmllLayoutAlignAnchor.Center,
      alignPosition: 0.5
    });
    this.localTime = this.currentTime;
    this.lastExternalTime = this.currentTime;
    this.engine.setPlaying(this.isPlay);
    this.engine.setLyricLines(this.lyricLines, this.currentTime);
    const store = MusicStoreService.getInstance();
    this.lyricFpsState.fps = store.getLyricFps();
    this.showSubLyricState.enabled = store.getShowSubLyric();
    this.lyricCenterState.enabled = store.getLyricCenterEnabled();
    this.fpsLimit = this.lyricFpsState.fps;
    this.registerWindowStageListener();
    this.startFrameLoop();
  }

  aboutToDisappear(): void {
    this.stopFrameLoop();
    this.clearAutoAlignTimer();
    this.unregisterWindowStageListener();
  }

  /** 注册 WindowStage 前后台监听（退后台停帧，回前台恢复并对齐进度）。 */
  private registerWindowStageListener(): void {
    const stage: window.WindowStage | undefined = WindowUtil.getInstance().windowStage;
    if (stage === undefined) {
      return;
    }
    this.windowStageHandle = stage;
    stage.on('windowStageEvent', this.windowStageCallback);
  }

  /** 注销 WindowStage 前后台监听。 */
  private unregisterWindowStageListener(): void {
    const stage: window.WindowStage | undefined = this.windowStageHandle;
    this.windowStageHandle = undefined;
    if (stage !== undefined) {
      stage.off('windowStageEvent', this.windowStageCallback);
    }
  }

  /** 退后台：停掉帧循环与定时器，不再重绘（后台继续播放也不消耗 UI 线程）。 */
  private onWindowHidden(): void {
    if (this.isWindowHidden) {
      return;
    }
    this.isWindowHidden = true;
    this.stopFrameLoop();
    this.clearAutoAlignTimer();
    this.inertiaActive = false;
    this.panSpeed = 0;
  }

  /** 回前台：用外部进度一次性对齐时间轴并恢复帧循环。 */
  private onWindowShown(): void {
    if (!this.isWindowHidden) {
      return;
    }
    this.isWindowHidden = false;
    this.localTime = this.currentTime;
    this.lastExternalTime = this.currentTime;
    this.engine.setCurrentTime(this.currentTime, true);
    this.drawFrame(this.localTime);
    this.scheduleFrame();
  }

  /**
   * 启动帧循环（UIContext.postFrameCallback 驱动，跟随屏幕刷新率：
   * 60Hz 设备 60FPS、120Hz 设备 120FPS；窗口不可见时系统自动暂停回调）。
   */
  private startFrameLoop(): void {
    this.lastFrameTime = Date.now();
    this.isFrameLoopRunning = true;
    this.frameTicker.setTick((): void => {
      this.onFrame();
    });
    this.requestNextFrame();
  }

  private stopFrameLoop(): void {
    this.isFrameLoopRunning = false;
  }

  /** 请求下一帧回调（仅在帧循环运行时生效）。 */
  private requestNextFrame(): void {
    if (!this.isFrameLoopRunning) {
      return;
    }
    this.getUIContext().postFrameCallback(this.frameTicker);
  }

  private scheduleFrame(): void {
    if (!this.isFrameLoopRunning) {
      this.lastFrameTime = Date.now();
      this.isFrameLoopRunning = true;
      this.frameTicker.setTick((): void => {
        this.onFrame();
      });
      this.requestNextFrame();
    }
  }

  private clearAutoAlignTimer(): void {
    if (this.inertiaTimer > 0) {
      clearTimeout(this.inertiaTimer);
      this.inertiaTimer = 0;
    }
  }

  private ensureEngineSize(): void {
    if (this.viewWidth > 0 && this.viewHeight > 0 && !this.engineInited) {
      this.engine.onResize(this.viewWidth, this.viewHeight);
      this.engineInited = true;
    }
  }

  private ensureRenderer(): void {
    if (this.renderer === undefined) {
      const style: AmllRenderStyle = {
        fontSize: this.fontSize,
        fontFamily: 'HarmonyHeiTi',
        fontWeight: this.fontWeight,
        subLineWeight: '400',
        textColor: this.textColor,
        glowColor: this.glowColor,
        lineWidthAspect: this.lineWidthAspect,
        paddingXEm: 0.6,
        bgLineScale: 0.7,
        subLineScale: 0.5,
        showSubLyric: this.showSubLyricState.enabled,
        lyricCenter: this.lyricCenterState.enabled
      };
      this.renderer = new AmllCanvasLyricRenderer(this.ctx, this.engine, style);
      this.renderer.onResize(this.viewWidth, this.viewHeight);
      this.rendererInited = true;
    }
  }

  @Monitor('lyricLines')
  onLyricLinesChanged(): void {
    if (this.isWindowHidden) {
      // 后台切歌：只更新引擎数据与失效测量缓存，不重绘、不重启帧循环
      this.localTime = this.currentTime;
      this.lastExternalTime = this.currentTime;
      this.engine.setLyricLines(this.lyricLines, this.currentTime);
      if (this.renderer !== undefined) {
        this.renderer.invalidateMeasured();
      }
      return;
    }
    this.localTime = this.currentTime;
    this.lastExternalTime = this.currentTime;
    this.engine.setLyricLines(this.lyricLines, this.currentTime);
    if (this.renderer !== undefined) {
      this.renderer.invalidateMeasured();
    }
    this.ensureRenderer();
    this.drawFrame(this.localTime);
    this.scheduleFrame();
  }

  @Monitor('currentTime')
  onCurrentTimeChanged(): void {
    if (this.isWindowHidden) {
      // 后台：外部进度继续推进但无需渲染，回前台时统一对齐
      return;
    }
    const external = this.currentTime;
    if (!this.isPlay) {
      // 暂停时：仅大跳（用户拖动进度条）才 seek；外部进度的滞后小漂移不打扰定格画面
      const drift = Math.abs(external - this.engine.getCurrentTime());
      if (drift > 500) {
        this.localTime = external;
        this.lastExternalTime = external;
        this.engine.setCurrentTime(external, true);
        this.engine.restoreInterlude();
        this.drawFrame(external);
        this.scheduleFrame();
      } else {
        this.localTime = external;
        this.lastExternalTime = external;
      }
      return;
    }
    const drift = Math.abs(external - this.localTime);
    if (this.isSeeking) {
      // 等待音频真正跳到目标之后（外部时间越过目标）再恢复本地时钟推进
      if (external > this.seekTarget) {
        this.isSeeking = false;
      } else {
        this.localTime = this.seekTarget;
        this.lastExternalTime = external;
        this.drawFrame(this.localTime);
        this.scheduleFrame();
        return;
      }
    }
    if (drift > CLOCK_DRIFT_LIMIT_MS) {
      // 时钟漂移校正：只向前对齐、不强制 seek（seek 重排会破坏间奏/歌词状态）
      if (external > this.localTime) {
        this.localTime = external;
        this.engine.setCurrentTime(external, false);
      }
      this.lastExternalTime = external;
      this.drawFrame(this.localTime);
      this.scheduleFrame();
    } else {
      this.localTime = Math.max(this.localTime, external);
      this.lastExternalTime = external;
    }
  }

  @Monitor('isPlay')
  onPlayChanged(): void {
    this.engine.setPlaying(this.isPlay);
    if (this.isWindowHidden) {
      // 后台：仅同步引擎播放状态，回前台时统一重绘
      return;
    }
    if (!this.isPlay) {
      // 暂停：画面完全定格——用引擎当前时间渲染，不以外界滞后进度覆盖时间轴
      // （外部 progress 滞后几百 ms，回退会导致间奏点退出/状态跳变）
      this.localTime = this.engine.getCurrentTime();
      this.lastExternalTime = this.localTime;
      this.drawFrame(this.localTime);
    }
    this.scheduleFrame();
  }

  @Monitor('fontSize', 'textColor', 'glowColor', 'lineWidthAspect', 'showSubLyricState.enabled')
  onStyleChanged(): void {
    if (this.isWindowHidden) {
      // 后台：样式已更新，回前台统一重绘
      return;
    }
    if (this.renderer !== undefined) {
      this.renderer.updateStyle({
        fontSize: this.fontSize,
        fontFamily: 'HarmonyHeiTi',
        fontWeight: this.fontWeight,
        subLineWeight: '400',
        textColor: this.textColor,
        glowColor: this.glowColor,
        lyricCenter: this.lyricCenterState.enabled,
        lineWidthAspect: this.lineWidthAspect,
        paddingXEm: 0.6,
        bgLineScale: 0.7,
        subLineScale: 0.5,
        showSubLyric: this.showSubLyricState.enabled
      });
      // 不调用 onResize：避免触发全量重测（首帧清空测量缓存导致整屏闪烁）
      this.drawFrame(this.localTime);
      this.scheduleFrame();
    }
  }

  /** 帧循环回调 */
  private onFrame(): void {
    if (this.isWindowHidden || !this.isFrameLoopRunning) {
      // 防御：后台期间或已停止时不推进/不重绘（正常路径已 stopFrameLoop）
      return;
    }
    const now = Date.now();
    const elapsed = now - this.lastFrameTime;
    // 帧率上限（设置页 60/90/120/144/165）：未到渲染间隔时跳过本帧。
    // 跳过的 vsync 不推进时间轴，下一帧 elapsed 自然累计到目标间隔，进度不失真
    if (this.fpsLimit > 0) {
      const intervalMs: number = 1000 / this.fpsLimit;
      if (elapsed < intervalMs - 0.5) {
        this.requestNextFrame();
        return;
      }
    }
    let dt = elapsed;
    this.lastFrameTime = now;
    if (dt <= 0 || dt > 100) {
      dt = FRAME_INTERVAL_MS;
    }

    if (this.isPlay) {
      if (!this.isSeeking) {
        this.localTime += dt;
        const external = this.currentTime;
        if (Math.abs(external - this.localTime) > CLOCK_DRIFT_LIMIT_MS) {
          this.localTime = external;
        }
      }
      this.engine.setCurrentTime(this.localTime, false);
    } else {
      // 暂停：保持引擎时间轴不变（外部进度可能滞后，回退会导致间奏点退出），
      // 仅在用户拖动进度条时通过 onCurrentTimeChanged(seek) 更新时间
    }

    if (this.inertiaActive) {
      if (Math.abs(this.panSpeed) > INERTIA_STOP_SPEED) {
        this.engine.setScrollOffset(
          this.engine.getScrollOffset() - this.panSpeed * dt,
          true
        );
        this.panSpeed *= Math.pow(INERTIA_DECAY, dt / 16);
      } else {
        this.inertiaActive = false;
        this.panSpeed = 0;
        this.engine.onScrollInteractionEnd();
        this.scheduleAutoAlign();
      }
    }

    this.engine.update(dt);
    // 暂停时也要推进测量/首帧布局：否则歌词按未测量高度绘制（看起来“没展开”），
    // 要拖动或点播放才继续测量。测量未完成时每帧都绘制以驱动 ensureMeasured。
    if (this.isPlay || this.engine.needsRender ||
      (this.renderer !== undefined && !this.renderer.isMeasureComplete())) {
      this.drawFrame(this.localTime);
      this.engine.needsRender = false;
    }

    if (this.isPlay || this.inertiaActive || this.engine.needsRender || this.engine.needsInterludeFade() ||
      this.engine.isSubTransitionActive() || this.engine.hasMovingSprings() ||
      (this.renderer !== undefined && !this.renderer.isMeasureComplete())) {
      this.requestNextFrame();
    } else {
      this.stopFrameLoop();
    }
  }

  private scheduleAutoAlign(): void {
    this.clearAutoAlignTimer();
    const view = this;
    this.inertiaTimer = setTimeout((): void => {
      view.inertiaTimer = 0;
      view.engine.onAutoAlignResume();
      view.drawFrame(view.localTime);
      view.scheduleFrame();
    }, AUTO_ALIGN_DELAY_MS);
  }

  private drawFrame(time: number): void {
    this.ensureRenderer();
    if (this.renderer !== undefined) {
      this.renderer.draw(time);
    }
  }

  // ==================== 手势 ====================

  private handlePanStart(event: GestureEvent): void {
    this.clearAutoAlignTimer();
    this.inertiaActive = false;
    this.panSpeed = 0;
    this.panStartOffset = this.engine.getScrollOffset();
    this.panStartY = event.offsetY;
    this.panLastY = event.offsetY;
    this.panStartTime = Date.now();
    this.isIntentConfirmed = false;
    this.isInteracting = false;
  }

  private handlePanUpdate(event: GestureEvent): void {
    const currentY = event.offsetY;
    const deltaY = currentY - this.panStartY;
    if (!this.isIntentConfirmed) {
      if (Math.abs(deltaY) > TOUCH_INTENT_PX) {
        this.isIntentConfirmed = true;
        this.isInteracting = true;
        this.engine.onScrollInteractionStart();
      } else {
        return;
      }
    }
    const now = Date.now();
    const dt = now - this.panStartTime;
    if (dt > 0) {
      this.panSpeed = (currentY - this.panLastY) / dt;
    }
    this.panLastY = currentY;
    this.panStartTime = now;
    this.engine.setScrollOffset(this.panStartOffset - deltaY, true);
    this.drawFrame(this.localTime);
    this.scheduleFrame();
  }

  private handlePanEnd(event: GestureEvent): void {
    if (!this.isIntentConfirmed) {
      return;
    }
    this.isIntentConfirmed = false;
    if (Math.abs(this.panSpeed) < 0.1) {
      this.panSpeed = 0;
    }
    if (Math.abs(this.panSpeed) > INERTIA_STOP_SPEED) {
      this.inertiaActive = true;
    } else {
      this.engine.onScrollInteractionEnd();
      this.scheduleAutoAlign();
    }
    void event;
  }

  /** 点击：定位到点击位置最近的歌词行并跳转（圆角框由按压手势驱动） */
  private handleTap(event: GestureEvent): void {
    const loc = event.tapLocation;
    if (loc === undefined) {
      return;
    }
    const best = this.findLineIndexAtY(loc.y);
    if (best < 0) {
      return;
    }
    const line = this.engine.groups[best];
    this.seekToLine(this.linePlayStartTime(line));
  }

  /**
   * 行的真实演唱起始时间：取第一个非空白词的时间戳。
   * AMLL 优化（tryAdvanceStartTime）会把 line.startTime 提前最多 600ms（提前高亮用），
   * 词级时间戳未被提前——用词时间跳转才准确落在该行，而不是上一行的末尾区间。
   */
  private linePlayStartTime(group: AmllGroupState): number {
    const words = group.mainLine.line.words;
    for (let i = 0; i < words.length; i++) {
      if (words[i].word.trim().length > 0) {
        return words[i].startTime;
      }
    }
    return group.startTime;
  }

  /** 长按：复制该行歌词（主行 + 翻译/罗马音）到剪贴板 */
  private handleLongPress(event: GestureEvent): void {
    const fingers = event.fingerList;
    if (fingers === undefined || fingers.length === 0) {
      return;
    }
    const index = this.findLineIndexAtY(fingers[0].localY);
    if (index < 0 || index >= this.engine.groups.length) {
      return;
    }
    const lyricLine = this.engine.groups[index].mainLine.line;
    let text = '';
    for (let w = 0; w < lyricLine.words.length; w++) {
      text += lyricLine.words[w].word;
    }
    if (lyricLine.translatedLyric.length > 0) {
      text += '\n' + lyricLine.translatedLyric;
    }
    if (lyricLine.romanLyric.length > 0) {
      text += '\n' + lyricLine.romanLyric;
    }
    const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const sysPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    sysPasteboard.setData(pasteData).then(() => {
      this.getUIContext().getPromptAction().showToast({ message: '已复制该行歌词', duration: 2000 });
    }).catch((error: BusinessError) => {
      Logger.error('AmllLyricView', `copy lyric failed: ${error.message}`);
    });
  }

  /** 按压/拖动期间圆角框跟随手指：按下与移动时高亮手指所在行，抬起/取消时消失 */
  private handleCanvasTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down || event.type === TouchType.Move) {
      const touches = event.touches;
      if (touches.length === 0) {
        return;
      }
      const index = this.findLineIndexAtY(touches[0].y);
      if (index >= 0) {
        this.engine.setFocusLine(index);
      }
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.engine.clearFocus();
    }
  }

  /** 找 Y 坐标命中的歌词行：命中区域为行的可视块（框的范围），避免中心到中心的偏移 */
  private findLineIndexAtY(tapY: number): number {
    const count = this.engine.groups.length;
    if (count === 0) {
      return -1;
    }
    let best = -1;
    for (let i = 0; i < count; i++) {
      const top = this.engine.getLineTopInViewport(i);
      const h = this.engine.getLineHeightAt(i);
      if (tapY >= top && tapY < top + h) {
        best = i;
        break;
      }
    }
    if (best === -1) {
      // 兜底：找最近的行
      let minDist = Number.MAX_VALUE;
      for (let i = 0; i < count; i++) {
        const center = this.engine.getLineTopInViewport(i) + this.engine.getLineHeightAt(i) / 2;
        const d = Math.abs(tapY - center);
        if (d < minDist) {
          minDist = d;
          best = i;
        }
      }
    }
    return best;
  }

  private seekToLine(startTime: number): void {
    this.inertiaActive = false;
    this.panSpeed = 0;
    this.isInteracting = false;
    this.engine.resetScroll();
    this.localTime = startTime;
    this.lastExternalTime = startTime;
    this.isSeeking = true;
    this.seekTarget = startTime;
    this.engine.setCurrentTime(startTime, true);
    this.engine.restoreInterlude();
    this.drawFrame(startTime);
    this.onSeekTime(startTime);
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .blendMode(BlendMode.PLUS, BlendApplyType.OFFSCREEN)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const w = Number.parseFloat(newArea.width.toString());
        const h = Number.parseFloat(newArea.height.toString());
        if (Math.abs(w - this.viewWidth) > 0.5 || Math.abs(h - this.viewHeight) > 0.5) {
          this.viewWidth = w;
          this.viewHeight = h;
          this.engine.onResize(w, h);
          if (this.renderer !== undefined) {
            this.renderer.onResize(w, h);
          }
          this.drawFrame(this.localTime);
        }
      })
      .onTouch((event: TouchEvent) => {
        this.handleCanvasTouch(event);
      })
      .gesture(
        PanGesture(new PanGestureOptions({ direction: PanDirection.Vertical }))
          .onActionStart((event: GestureEvent) => {
            this.handlePanStart(event);
          })
          .onActionUpdate((event: GestureEvent) => {
            this.handlePanUpdate(event);
          })
          .onActionEnd((event: GestureEvent) => {
            this.handlePanEnd(event);
          })
          .onActionCancel((event: GestureEvent) => {
            this.handlePanEnd(event);
          })
      )
      .gesture(
        TapGesture()
          .onAction((event: GestureEvent) => {
            this.handleTap(event);
          })
      )
      .gesture(
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction((event: GestureEvent) => {
            this.handleLongPress(event);
          })
      )
  }
}
