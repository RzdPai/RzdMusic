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

import { AppStorageV2, uiObserver, window } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { hdsEffect } from '@kit.UIDesignKit';
import {
  AppStorageKeys,
  BreakpointConstants,
  CoverRadiusState,
  CoverTintState,
  getWindowInfoState,
  ImmersiveType,
  isWidthBreakpointLgOrXl,
  Logger,
  MusicStoreService,
  PlaybackFlowLightState,
  PlaybackShellConstants,
  PlayerExpandState,
  ShowMiniLyricState,
  StyleConstants,
  WindowInfo,
  WindowUtil
} from 'musicbasic';
import { MusicAppState } from '../model/PlayerModels';
import { SwitchBannerState } from '../model/SwitchBannerState';
import { MediaService } from '../model/MediaService';
import { ColorConversion } from '../util/ColorConversion';
import { PlayerConstants } from '../constant/PlayerConstants';
import { ControlAreaComponent } from './ControlAreaComponent';
import { LyricsComponent } from './LyricsComponent';
import { MiniLyricLinesComponent } from './MiniLyricLinesComponent';
import { MusicPlayInfoBlock } from './MusicPlayInfoBlock';
import { TopAreaComponent } from './TopAreaComponent';

/** Clamps a numeric RGB channel to an integer byte in [0, 255]. */
function clampRgbByte(n: number): number {
  if (!Number.isFinite(n)) {
    return 0;
  }
  return Math.max(0, Math.min(255, Math.floor(n)));
}

/** Minimal shape for probing {@link image.PixelMap.release}; {@link Resource} does not carry this. */
interface PixelMapReleaseProbe {
  release?: () => void;
}

/** 一圈流光时长（ms）：慢一点才像"呼吸"而不是闪。 */
const FLOW_LIGHT_DURATION_MS: number = 12000;
/** 流光层整体不透明度：太高会盖住封面与歌词。 */
const FLOW_LIGHT_OPACITY: number = 0.55;

/**
 * Full-screen playback page: layered background, breakpoint-specific layout, dismiss gestures,
 * and dynamic tint from album art.
 */
@ComponentV2
export struct PlaybackPage {
  /** Window width/height breakpoint for responsive layout branches. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Global music UI and queue state. */
  @Local state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** Mini lyric switch shared with settings. */
  @Local miniLyricState: ShowMiniLyricState =
    AppStorageV2.connect(ShowMiniLyricState, AppStorageKeys.SHOW_MINI_LYRIC_STATE, () => new ShowMiniLyricState())!;
  /** Status bar / navigation bar metrics for safe padding. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  @Local coverRadiusState: CoverRadiusState =
    AppStorageV2.connect(CoverRadiusState, AppStorageKeys.COVER_RADIUS_STATE, () => new CoverRadiusState())!;
  /** 播放页流光背景开关（设置项，AppStorageV2 共享，改设置立刻生效）。 */
  @Local flowLightState: PlaybackFlowLightState =
    AppStorageV2.connect(PlaybackFlowLightState, AppStorageKeys.PLAYBACK_FLOW_LIGHT_STATE,
      () => new PlaybackFlowLightState())!;
  /** 流光背景的两个颜色（由封面动态取色写入）。 */
  @Local coverTint: CoverTintState =
    AppStorageV2.connect(CoverTintState, AppStorageKeys.COVER_TINT_STATE, () => new CoverTintState())!;
  /** 流光着色器控制器：换歌后按新取到的封面颜色重设 uniform。 */
  private flowLightController: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();
  /** 已应用到着色器的取色版本号，避免同一份颜色重复下发布。 */
  private appliedTintVersion: number = -1;
  /** Background cover image (Resource or blurred PixelMap). */
  @Local imageLabel: image.PixelMap | Resource = $r('app.media.ic_avatar1');
  /** Cross-script source-switch banner state; AppStorageV2-backed for reactive UI. */
  @Local switchBanner: SwitchBannerState = SwitchBannerState.connect();
  /** Last seen banner timestamp for the deferred clear (avoids stale clears). */
  private bannerTs: number = 0;
  /** Pending clear timer id for the banner. */
  private bannerClearTimer: number = -1;
  /** Whether large / grid layout shows transport in the lyric column. */
  @Local isShowControlLg: boolean = false;
  /** Passed to child components that branch on tablet spacing. */
  @Local isTablet: boolean = true;
  /** Inverse tablet flag for lyric column variants. */
  @Local isTabletFalse: boolean = false;
  /** When true, renders the wide split panel layout (no top bar, custom paddings). */
  @Param panelLayout: boolean = false;
  /** Swiper page index (lyrics vs main stack on some layouts). */
  @Local playbackSwiperIndex: number = 0;
  /** False after teardown to ignore async image callbacks. */
  private isAlive: boolean = true;
  /** Bumps on each {@link getImageColorAsync} run so stale async work skips UI updates and releases pixels. */
  private imageColorJobSeq: number = 0;
  /** Cached UIAbility context for resource and color extraction. */
  private context: common.UIAbilityContext | undefined = undefined;
  /** Logger tag for this page. */
  private static readonly logTag: string = 'PlaybackPage';
  /** 收起态内容层占窗口高度的百分比：贴底一条，大致等于迷你条那一条。 */
  private static readonly COLLAPSED_HEIGHT_PERCENT: number = 9;
  /** 展开动画的起点进度（= 完全收起）。 */
  private static readonly EXPAND_START_PROGRESS: number = 100;
  /** 展开/收起动画时长（ms），与参考工程 `OPEN_PLAYER_UI_ANIMATION_MS` 一致。 */
  private static readonly EXPAND_DURATION_MS: number = 380;
  /** 展开看门狗（ms）：超时还没回到完整态就强制回到完整态。 */
  private static readonly COLLAPSE_WATCHDOG_MS: number = 900;
  /** 展开看门狗定时器句柄。 */
  private collapseWatchdogTimer: number = -1;
  /** 正在播收起动画（防止连点返回播两遍）。 */
  private isClosing: boolean = false;
  /** 下拉收起：拖拽多少距离算"拉到底"（相对窗口高度）。 */
  private static readonly DISMISS_DRAG_SPAN_RATIO: number = 0.42;
  /** 下拉松手时的提交阈值：进度超过它就收起，否则弹回完整态。 */
  private static readonly DISMISS_COMMIT_PROGRESS: number = 38;

  /** @returns 窗口高度（vp）；拿不到时给一个兜底值，保证拖拽比例不会除零。 */
  private deviceHeightVp(): number {
    const px: number = this.windowInfo.windowSize.height;
    if (px <= 0) {
      return 780;
    }
    return this.getUIContext().px2vp(px);
  }

  /** @returns 下拉到底所需的距离（vp）。 */
  private dismissSpanVp(): number {
    return this.deviceHeightVp() * PlaybackPage.DISMISS_DRAG_SPAN_RATIO;
  }

  /**
   * 由拖拽距离换算收起进度。
   * @param offsetY 手势的竖直位移（vp，向下为正）。
   * @returns 进度 0..100。
   */
  private dismissProgressFromDrag(offsetY: number): number {
    const y: number = offsetY > 0 ? offsetY : 0;
    const span: number = this.dismissSpanVp();
    if (span <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(100, (y / span) * 100));
  }

  /**
   * 下拉收起手势：拖动期间**跟手**改进度（不走 animateTo，所以是即时的），
   * 松手时超过阈值就收起、否则补间弹回完整态。
   *
   * 这套交互和参考工程 MusicHome 的 `PanGesture` 一致（它的 `dismissPanOffsetY`
   * → `dismissSheetHeightPercent` + `coverLinearScale` 是同一件事）。
   * @param offsetY 当前竖直位移（vp）。
   * @param ended 是否是松手。
   */
  private onDismissDrag(offsetY: number, ended: boolean): void {
    if (this.isClosing) {
      return;
    }
    if (!ended) {
      this.collapseProgress = this.dismissProgressFromDrag(offsetY);
      return;
    }
    if (this.dismissProgressFromDrag(offsetY) >= PlaybackPage.DISMISS_COMMIT_PROGRESS) {
      this.closeFullScreenPlayback();
      return;
    }
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, (): void => {
      this.collapseProgress = 0;
    });
  }

  /**
   * 壳层拦到系统返回（要求关闭模态）→ 播收起动画，不要直接消失。
   *
   * ⚠️ **不要在 `@Monitor` 回调里直接 `animateTo`**：这个回调不在手势/点击那类
   *    "动画作用域"里，`animateTo` 有可能不插值，`collapseProgress` 会一步到位 ——
   *    用户看到的就是"返回收起只能看到动画的最后，看不到中间过程"
   *    （点收起按钮/下拉走的是点击与手势回调，所以那条路正常）。
   *    挪到下一个任务里再播，就回到和点击一样的上下文。
   */
  @Monitor('expandState.collapseVersion')
  onCollapseRequested(): void {
    setTimeout((): void => {
      this.closeFullScreenPlayback();
    }, 0);
  }
  /** Fallback page background tint when art or color pick fails. */
  private static readonly defaultImageBgColor: string = 'rgba(32, 32, 32, 1)';

  /**
   * Banner watcher: when switchBanner.ts advances, schedule a 3s clear.
   * Compares the parsed timestamp so an older clear does not blank a newer banner.
   */
  onBannerChange(): void {
    const ts: number = this.switchBanner.ts;
    if (ts <= this.bannerTs) {
      return;
    }
    this.bannerTs = ts;
    if (this.bannerClearTimer !== -1) {
      clearTimeout(this.bannerClearTimer);
    }
    this.bannerClearTimer = setTimeout((): void => {
      this.switchBanner.text = '';
      this.switchBanner.ts = 0;
      this.bannerClearTimer = -1;
    }, 3000);
  }

  /**
   * Re-runs onBannerChange whenever a new banner is published via AppStorageV2.
   */
  @Monitor('switchBanner.ts')
  onSwitchBannerTsChange(): void {
    this.onBannerChange();
  }

  /**
   * 取色完成后把新颜色灌进流光着色器。
   *
   * 用 `setEffectParams`（而不是重建 `visualEffect`）：换歌只更新 uniform，
   * 不会重启着色器、也不会让流光"跳"回起点。
   */
  @Monitor('coverTint.version')
  onCoverTintVersionChange(): void {
    this.applyFlowLightColors();
  }

  /**
   * 流光背景开关被打开时，重新为当前这首曲目取一次色。
   *
   * 关着的时候取色是跳过的（省一次解码），所以刚打开开关时手上没有颜色；
   * 这里补一次，用户不用切歌就能看到效果。
   */
  @Monitor('flowLightState.enabled')
  onFlowLightEnabledChange(): void {
    if (!this.flowLightState.enabled || this.context === undefined || !this.isAlive) {
      return;
    }
    this.getImageColor();
  }

  /** 把 {@link coverTint} 里的颜色推给着色器（同版本号只推一次）。 */
  private applyFlowLightColors(): void {
    if (this.coverTint.version === this.appliedTintVersion) {
      return;
    }
    this.appliedTintVersion = this.coverTint.version;
    try {
      this.flowLightController.setEffectParams({
        colorSource: [this.coverTint.sourceColor],
        colorTarget: [this.coverTint.targetColor]
      });
      Logger.info(PlaybackPage.logTag,
        `flow light colors applied v=${this.coverTint.version} src=${this.coverTint.sourceColor}`);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(PlaybackPage.logTag,
        `setEffectParams failed, code=${err?.code}, message=${err?.message}`);
    }
  }

  /**
   * 播放页流光背景层（HDS `UV_BACKGROUND_FLOW_LIGHT` 着色器）。
   *
   * 参考上游 PR #1 在首页的用法，但颜色不是写死的：`colorSource` /
   * `colorTarget` 来自当前封面动态取色（见 {@link publishFlowLightColors}），
   * 每次换歌都会重新算一次。
   *
   * 作为 `Stack` 的**首个子节点**绘制：在页面底色之上、封面/歌词之下。
   * `HitTestMode.Transparent` 是必须的 —— 整层是全屏的，默认命中的话会把
   * 播放页所有按钮的点击全吃掉。
   */
  @Builder
  private FlowLightBackground() {
    Stack()
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .hitTestBehavior(HitTestMode.Transparent)
      .opacity(FLOW_LIGHT_OPACITY)
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .shaderEffect({
          effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
          animation: {
            duration: FLOW_LIGHT_DURATION_MS,
            iterations: -1,
            autoPlay: true
          },
          // 初值用兜底色；真正的颜色由 applyFlowLightColors 在取色完成后下发，
          // 这样即使取色很慢也能立刻看到流光在动（而不是黑屏等半天）。
          params: {
            colorSource: [this.coverTint.sourceColor],
            colorTarget: [this.coverTint.targetColor]
          },
          controller: this.flowLightController
        })
        .buildEffect())
  }

  /** 醒目提示横幅：音源脚本跨脚本切换时显示，3 秒后自动隐藏。 */
  @Builder
  private SwitchBanner() {
    if (this.switchBanner.text.length > 0) {
      Row() {
        SymbolGlyph($r('sys.symbol.arrow_right_circle'))
          .fontSize(20)
          .fontColor([Color.White])
          .margin({ right: 8 })
        Text(this.switchBanner.text)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
      }
      .width('88%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .borderRadius(16)
      .backgroundColor('rgba(220, 60, 60, 0.95)')
      .margin({ top: 56 })
      .align(Alignment.Center)
    }
  }

  /** 收起进度 0..100：**0 = 完整播放页（静止态）**，100 = 收起成贴底的一条。 */
  @Local collapseProgress: number = 0;
  /**
   * 收起请求通道（与壳层共用）。
   *
   * 壳层拦到**系统返回**（模态被要求关闭）时，只在这里 `requestCollapse()` 一下，
   * 真正的收起动画由本页播 —— 不拦那一下，系统返回就是"啪"地消失、没有动画。
   * 只用到 `collapseVersion` 一个计数，几何字段现在是空的（path 那版动画已移除）。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  /** 下拉收起手势（竖直方向）。 */
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  /** Seeds cover Resource from the current queue item. */
  aboutToAppear(): void {
    this.coverRadiusState.radius = MusicStoreService.getInstance().getCoverCornerRadius();
    const song = this.state.getCurrentSongItem();
    this.releaseBackgroundCoverIfPixelMap();
    this.imageLabel = song !== undefined ? song.label : $r('app.media.ic_avatar1');
    this.applyKeepScreenOn(true);
    // 页面打开时如果已有未过期的横幅，立即触发清理计时。
    if (this.switchBanner.ts > 0) {
      this.onBannerChange();
    }
    // ★ 展开动画：先在 `aboutToAppear` 把进度放到"收起"，**保证第一帧画出来就是贴底的一条**。
    //   如果放到 `onAppear` 再置，会先渲染出一帧完整播放页再收回去，看着就是闪一下。
    this.collapseProgress = PlaybackPage.EXPAND_START_PROGRESS;
    // ⚠️ 看门狗：万一下面 `onAppear` 里的补间因为任何原因没跑起来，
    //   进度就会永远停在"收起"，用户看到的是打不开播放器。
    //   最迟 COLLAPSE_WATCHDOG_MS 之后强制回到完整态 —— 宁可没有动画。
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
    }
    this.collapseWatchdogTimer = setTimeout((): void => {
      this.collapseWatchdogTimer = -1;
      if (this.collapseProgress > 0) {
        Logger.error(PlaybackPage.logTag,
          `expand watchdog fired progress=${this.collapseProgress}, force full screen`);
        this.collapseProgress = 0;
      }
    }, PlaybackPage.COLLAPSE_WATCHDOG_MS);
  }

  aboutToDisappear(): void {
    this.applyKeepScreenOn(false);
    if (this.bannerClearTimer !== -1) {
      clearTimeout(this.bannerClearTimer);
      this.bannerClearTimer = -1;
    }
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    // 下一次进来 `aboutToAppear` 会重新置成收起，这里复位只是为了不留脏状态
    this.collapseProgress = 0;
  }

  /**
   * 「一镜到底」展开动画：把进度从"收起"补间到 0。
   *
   * 手法完全照参考工程 MusicHome：**只用 `height` / `translate` / `scale` 三个基本属性**，
   * 不碰任何形状裁剪 —— 那边播放页下滑收起时的"封面变小"就是这么做的（
   * `dismissSheetHeightPercent` + `coverLinearScale`），我们只是把同一套进度反向跑一遍。
   *
   * 为什么这样就够了：内容层 `justifyContent(FlexAlign.End)` 贴着底边，
   * 高度从"贴底一条"长到 100% = 从底部向上铺满；封面用 `layoutWeight(1)`，
   * 高度变小它自己就变小，于是"封面慢慢变大"也一起来了。
   */
  private playExpandIntro(): void {
    try {
      this.getUIContext().animateTo({
        duration: PlaybackPage.EXPAND_DURATION_MS,
        curve: Curve.EaseInOut
      }, (): void => {
        this.collapseProgress = 0;
      });
    } catch (err) {
      // 补间起不来就立刻回到完整态；看门狗此时还没到点，别让页面停在"收起"那一条上
      const e = err as BusinessError;
      Logger.error(PlaybackPage.logTag, `expand animateTo failed code=${e.code} msg=${e.message}`);
      this.collapseProgress = 0;
    }
  }

  /**
   * @returns 内容层高度百分比字符串。
   *
   * 进度 0 → `'100%'`（与没有动画时逐像素一致，这是最重要的性质）；
   * 进度 100 → `COLLAPSED_HEIGHT_PERCENT`（贴底一条，大致就是迷你条那一条的高度）。
   */
  private sheetHeightPercent(): string {
    const p: number = Math.max(0, Math.min(100, this.collapseProgress));
    if (p <= 0) {
      return '100%';
    }
    const h: number = 100 - (100 - PlaybackPage.COLLAPSED_HEIGHT_PERCENT) * (p / 100);
    return h.toFixed(2) + '%';
  }

  /**
   * @returns 收起过程中是否要藏起标题/控件。
   *
   * 必须藏：内容被压扁到只剩一条时，固定高度的控制区会把封面挤成 0 高
   * （参考工程也是这么处理的 —— 它的 `isDismissPhase2HideMeta()` 一进二段就藏 meta）。
   */
  private isCollapsing(): boolean {
    return this.collapseProgress > 45;
  }

  /** Applies the keep-screen-on switch while the playback page is visible. */
  private applyKeepScreenOn(enabled: boolean): void {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (ctx === undefined) {
        return;
      }
      const keep: boolean = enabled && MusicStoreService.getInstance().getKeepScreenOn();
      window.getLastWindow(ctx).then((win: window.Window): void => {
        win.setWindowKeepScreenOn(keep);
      }).catch((_err: Object): void => {
      });
    } catch (_err) {
    }
  }

  /** Cover source for the current track: online url when available, else a default cover. */
  private currentCoverSource(): string | Resource {
    const song = this.state.getCurrentSongItem();
    if (song !== undefined && song.cover.length > 0) {
      return song.cover;
    }
    return $r('app.media.ic_avatar1');
  }

  /** Blurred backdrop source: online cover url when available, else the local pixel-map / resource. */
  private backgroundImageSource(): string | image.PixelMap | Resource {
    const song = this.state.getCurrentSongItem();
    if (song !== undefined && song.cover.length > 0) {
      return song.cover;
    }
    return this.imageLabel;
  }

  /** True when value looks like a decoded PixelMap ({@link Resource} has no release). */
  private isPixelMapCover(value: string | image.PixelMap | Resource): boolean {
    if (typeof value !== 'object' || value === null) {
      return false;
    }
    const probe = value as PixelMapReleaseProbe;
    return typeof probe.release === 'function';
  }

  /** Releases native PixelMap backing if {@link imageLabel} is a decoded bitmap (not a Resource). */
  private releaseBackgroundCoverIfPixelMap(): void {
    if (!this.isPixelMapCover(this.imageLabel)) {
      return;
    }
    try {
      (this.imageLabel as image.PixelMap).release();
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(PlaybackPage.logTag,
        `background cover PixelMap.release failed, code=${err?.code}, message=${err?.message}`);
    }
  }

  /** Safe PixelMap.release for locals (blur/decoded temps). */
  private releasePixelMapQuiet(pm: image.PixelMap | undefined | null): void {
    if (pm === undefined || pm === null) {
      return;
    }
    try {
      pm.release();
    } catch (error) {
      Logger.warn(PlaybackPage.logTag,
        `pixelMap.release failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /** Restores system-bar colors; window layout stays non-full-screen. */
  private restorePlaybackWindowChrome(): void {
    const wu = WindowUtil.getInstance();
    wu.applyPlaybackNavigationBarColor(false);
    wu.applyPlaybackWindowChrome(false, false);
    if (this.isPcFreeWindowDecor()) {
      wu.applyPcPlaybackDecorButtonStyle(false);
    }
  }

  /**
   * 关闭全屏播放页：先播收起动画（进度 0 → 收起），播完再恢复窗口 chrome 并卸载。
   *
   * ⚠️ 卸载放在**定时器**里而不是 `animateTo` 的完成回调：那个回调在部分场景不保证触发，
   * 靠它卸载就会变成"返回键按了没反应"。定时器按时长兜底，最坏情况只是收起动画被跳过，
   * 关闭一定会发生。
   */
  private closeFullScreenPlayback(): void {
    if (this.isClosing) {
      return;
    }
    this.isClosing = true;
    // 关闭期间进度会停在"收起"几百毫秒，别让展开看门狗把它抢回完整态
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    this.getUIContext().animateTo({
      duration: PlaybackPage.EXPAND_DURATION_MS,
      curve: Curve.EaseInOut
    }, (): void => {
      this.collapseProgress = PlaybackPage.EXPAND_START_PROGRESS;
    });
    setTimeout((): void => {
      this.isClosing = false;
      this.restorePlaybackWindowChrome();
      this.state.isShowPlay = false;
    }, PlaybackPage.EXPAND_DURATION_MS + 20);
  }

  /** True for small-width + medium-height window (phone landscape-ish). */
  private isSmHeightMdLayout(): boolean {
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD;
  }

  /** True when the wide split panel layout should be used (param or wide window). */
  private usePanelLayout(): boolean {
    return this.panelLayout || isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint);
  }

  /**
   * True for the narrow-phone Swiper layout (not fold inner dual-pane, not lg/xl grid).
   * Album and lyrics pages share the same blurred backdrop + imageColor so the tint matches.
   */
  private isPhoneLyricsStyleBackdropLayout(): boolean {
    if (isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint)) {
      return false;
    }
    if (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD) {
      return false;
    }
    return true;
  }

  /** Blurred cover tile + imageColor (phone Swiper); same for album page and lyrics page. */
  @Builder
  phoneSwiperBackdropImage() {
    Image(this.backgroundImageSource())
      .size(isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ?
        {
          width: PlayerConstants.BACK_IMAGE
        } :
        {
          height: PlayerConstants.BACK_IMAGE
        })
      .aspectRatio(1)
      .objectFit(ImageFit.Cover)
      .opacity(0.5)
  }

  /** Main Stack: background art, breakpoint-specific controls and lyrics grid. */
  @Builder
  buildControlStack() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
      if (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
        this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD && this.playbackSwiperIndex === 0) {
        Image(this.currentCoverSource())
          .width('100%')
          .aspectRatio(1)
          .objectFit(ImageFit.Fill)
      } else {
        Image(this.backgroundImageSource())
          .size(isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ?
            {
              width: PlayerConstants.BACK_IMAGE
            } :
            {
              height: PlayerConstants.BACK_IMAGE
            })
          .aspectRatio(1)
          .objectFit(ImageFit.Cover)
          .opacity(0.55)
          .blur(this.isPixelMapCover(this.backgroundImageSource()) ? 0 : 300)
      }
      if (this.usePanelLayout()) {
        this.panelControlContent()
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          if (!(this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM ||
            (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD &&
              this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_SM))) {
            // 平板/桌面：GridRow 左右分栏（封面 | 歌词），顶部 padding 让位给统一 TopArea
            Column() {
              GridRow({
                columns: { md: BreakpointConstants.COLUMN_MD, lg: BreakpointConstants.COLUMN_LG, xl: BreakpointConstants.COLUMN_LG },
                gutter: 48
              }) {
                GridCol({
                  span: { md: 4, lg: 5, xl: 4 }
                }) {
                  MusicPlayInfoBlock({
                    state: this.state,
                    metaBlockTranslateYvp: 0,
                    isDismissing: this.isCollapsing(),
                    coverLinearScale: 1
                  })
                }
                .margin({
                  bottom: 20
                })
                .padding({
                  left: isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ? 48 : 0,
                  right: isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ? 48 : 0
                })

                GridCol({
                  span: { md: 4, lg: BreakpointConstants.COLUMN_LYRIC_LG, xl: 8 }
                }) {
                  LyricsComponent({
                    isShowControl: this.isShowControlLg,
                    isTablet: this.isTabletFalse,
                    onSeekTime: (ms: number): void => {
                      MediaService.getInstance().seek(ms);
                    }
                  })
                }
                .margin({
                  bottom: 20
                })
              }
              .width(StyleConstants.FULL_WIDTH)
              .layoutWeight(1)
              .clip(true)
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .padding({
              left: $r('app.float.common_padding'),
              right: $r('app.float.common_padding'),
              top: 80
            })
          } else {
            // 手机：Swiper 封面/歌词滑动 + 底部控制区
            Column() {
              Swiper() {
                Stack({ alignContent: Alignment.Bottom }) {
                  MusicPlayInfoBlock({
                    state: this.state,
                    useAlbumCoverBackground: this.isSmHeightMdLayout(),
                    metaBlockTranslateYvp: 0,
                    isDismissing: this.isCollapsing(),
                    coverLinearScale: 1,
                    showControlArea: false
                  })
                  // 小歌词并入封面页：开启时底部预留固定空间，随封面页一起横向滑动
                  .padding({ bottom: this.miniLyricState.enabled ? 40 : 0 })
                  MiniLyricLinesComponent()
                    .width(StyleConstants.FULL_WIDTH)
                    .margin({
                      left: 4,
                      right: 4
                    })
                    // 收起过程中内容被压扁，小歌词会和控制区互相盖住
                    .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
                }
                .width(StyleConstants.FULL_WIDTH)
                .margin({
                  top: this.isSmHeightMdLayout() ? 0 : $r('app.float.music_component_top'),
                  bottom: this.isSmHeightMdLayout() ? 0 : $r('app.float.music_component_bottom')
                })
                .padding({
                  left: this.isSmHeightMdLayout() ? 0 : $r('app.float.common_padding'),
                  right: this.isSmHeightMdLayout() ? 0 : $r('app.float.common_padding')
                })

                Column() {
                  LyricsComponent({
                    isShowControl: false,
                    isTablet: this.isTabletFalse,
                    hideLyricsMetaHeader: this.isSmHeightMdLayout(),
                    onSeekTime: (ms: number): void => {
                      MediaService.getInstance().seek(ms);
                    }
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                .height(StyleConstants.FULL_HEIGHT)
                .margin({
                  top: this.isSmHeightMdLayout() ? 0 : $r('app.float.margin_lyric')
                })
                .padding({
                  left: $r('app.float.common_padding'),
                  right: $r('app.float.common_padding')
                })
              }
              .layoutWeight(1)
              .indicator(
                new DotIndicator()
                  .top($r('app.float.options_padding'))
                  .selectedColor($r('app.color.select_swiper'))
                  .color($r('app.color.slider_track'))
              )
              .clip(false)
              .loop(false)
              .onChange((index: number) => {
                this.playbackSwiperIndex = index;
              })

              ControlAreaComponent({ showBottomOtherRow: true })
                .width(StyleConstants.FULL_WIDTH)
                .padding({
                  left: $r('app.float.common_padding'),
                  right: $r('app.float.common_padding'),
                  bottom: 10
                })
                // 它是固定高度的：收起时留着会把封面挤成 0 高，必须整块藏掉
                .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
          }
          // 统一 TopArea（单一实例，叠加于内容之上，切换断点时不销毁重建）
          TopAreaComponent({
            isShowPlay: this.state.isShowPlay,
            onBackClick: (): void => {
              this.closeFullScreenPlayback();
            }
          })
            .padding({
              left: $r('app.float.common_padding'),
              right: $r('app.float.common_padding')
            })
            .zIndex(2)
            .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .padding({
          bottom: this.windowInfo.navigationBarBottomVp,
          top: this.windowInfo.statusBarTopVp
        })
      }
    }
    .height(StyleConstants.FULL_HEIGHT)
    .width(StyleConstants.FULL_WIDTH)
    .backgroundColor(this.state.imageColor)
  }

  /** Wide split panel layout: cover + controls on the left, lyrics + dual-action bar on the right. */
  @Builder
  private panelControlContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row({ space: 56 }) {
        Column() {
          MusicPlayInfoBlock({
            state: this.state,
            metaBlockTranslateYvp: 0,
            isDismissing: this.isCollapsing(),
            coverLinearScale: 1,
            panelLayout: true
          })
        }
        .layoutWeight(1)
        .padding({ top: 80, bottom: 48 })

        Column() {
          LyricsComponent({
            isShowControl: false,
            isTablet: this.isTabletFalse,
            panelBottomBar: true,
            onSeekTime: (ms: number): void => {
              MediaService.getInstance().seek(ms);
            }
          })
        }
        .layoutWeight(1)
        .padding({ top: 72, bottom: 74 })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .padding({
        left: 56,
        right: 56,
        top: this.windowInfo.statusBarTopVp,
        bottom: this.windowInfo.navigationBarBottomVp
      })

      if (!this.panelLayout) {
        TopAreaComponent({
          isShowPlay: this.state.isShowPlay,
          onBackClick: (): void => {
            this.closeFullScreenPlayback();
          }
        })
          .padding({
            left: 56,
            right: 56
          })
          .zIndex(2)
          .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  /** True when PC window uses immersive free-form decor (affects title button styling). */
  private isPcFreeWindowDecor(): boolean {
    return this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE;
  }

  /** Applies playback-specific window chrome and optional PC decor button style. */
  private applyWindowSafeAreas(): void {
    const wu = WindowUtil.getInstance();
    wu.applyPlaybackWindowChrome(true);
    if (this.isPcFreeWindowDecor()) {
      wu.applyPcPlaybackDecorButtonStyle(true);
    }
  }

  /** Applies playback window chrome: system-bar colors only, window layout stays non-full-screen. */
  private applyPlaybackWindowChromeImmediately(): void {
    const wu = WindowUtil.getInstance();
    wu.applyPlaybackNavigationBarColor(true);
    // ⚠️ 第二个参数 fullScreen 必须是 **true**（照参考工程 MusicHome 的
    //    `applyPlaybackWindowChrome(true)`）。
    //
    //    传 false 时窗口不进布局全屏，屏幕最底部那条系统导航栏/手势条区域**不归应用绘制**，
    //    播放页背景铺不到那里 —— 表现就是「底部一直有一条空白」，而且和内容 padding 无关：
    //    前面几轮无论怎么调 padding / expandSafeArea 都只是把空白变小或变大，消不掉。
    //    切到布局全屏后这块区域归应用，背景才能真正铺到屏幕底边。
    //    退场时 `applyPlaybackWindowChrome(false)` 会把布局全屏切回去，不影响其它页面。
    wu.applyPlaybackWindowChrome(true, true);
    if (this.isPcFreeWindowDecor()) {
      wu.applyPcPlaybackDecorButtonStyle(true);
    }
  }

  /** Refreshes dynamic background tint when the current track or queue changes. */
  @Monitor('state.selectIndex', 'state.playQueueIds')
  onCurrentTrackForBackground(): void {
    if (this.context === undefined) {
      return;
    }
    this.getImageColor();
  }

  /** Entry point: kicks off async album-color extraction without blocking UI. */
  getImageColor(): void {
    void this.getImageColorAsync();
  }

  /**
   * 由封面算出流光背景的两个颜色并写进 {@link coverTint}。
   *
   * 只在开关打开时才做：取色要走一次解码（在线封面还要先下载），关掉就别白花这份开销。
   * 失败不报错也不改颜色 —— 保留上一首的颜色或兜底色，流光照样能看。
   *
   * @param pixelMap 已解码的封面位图，由调用方负责释放。
   */
  private async extractFlowLightColors(pixelMap: image.PixelMap): Promise<void> {
    if (!this.flowLightState.enabled || !this.isAlive) {
      return;
    }
    await new Promise<void>((resolve: () => void) => {
      effectKit.createColorPicker(pixelMap,
        (error: Error | undefined, colorPicker: effectKit.ColorPicker | undefined) => {
          try {
            if (!this.isAlive || error || colorPicker === undefined) {
              return;
            }
            // 用占比最大的颜色作为基调，再在 vividFlowColors 里把饱和度/亮度拉起来：
            // 封面主色经常是一大片接近黑的背景，直接拿它做流光基本看不见
            // （首页 PR 那版写死一个紫色，所以没这个问题）。
            const color = colorPicker.getLargestProportionColor();
            this.publishFlowLightColors(color.red, color.green, color.blue);
          } finally {
            resolve();
          }
        });
    });
  }

  /**
   * 把封面主色换算成流光用的两个颜色并发布。
   *
   * 写 `coverTint` 会触发 {@link onCoverTintVersionChange}，由它把颜色下发给着色器。
   *
   * **不判断开关**：换算本身只是几次算术，关着也先算好存起来 —— 这样用户
   * 在设置里一打开开关，第一帧的流光颜色就已经是当前封面色，不会先闪一下兜底色。
   * 真正要花钱的是解码封面，那部分由 {@link extractFlowLightColors} 把关。
   *
   * @param red 封面主色红通道 0–255。
   * @param green 封面主色绿通道 0–255。
   * @param blue 封面主色蓝通道 0–255。
   */
  private publishFlowLightColors(red: number, green: number, blue: number): void {
    if (!this.isAlive) {
      return;
    }
    const vivid: string[] = ColorConversion.vividFlowColors(red, green, blue);
    this.coverTint.sourceColor = vivid[0];
    this.coverTint.targetColor = vivid[1];
    this.coverTint.version = this.coverTint.version + 1;
    Logger.info(PlaybackPage.logTag, `flow light tint updated src=${vivid[0]} dst=${vivid[1]}`);
  }

  /** Loads cover bytes, derives theme background color, and builds blurred background PixelMap. */
  private async getImageColorAsync(): Promise<void> {
    const jobSeq: number = ++this.imageColorJobSeq;
    const ctx = this.context;
    if (!ctx) {
      return;
    }
    const song = this.state.getCurrentSongItem();
    if (!song) {
      return;
    }
    this.releaseBackgroundCoverIfPixelMap();
    // Online songs without a resolved cover use the default art for the blurred backdrop.
    this.imageLabel = song.source.length > 0 && song.cover.length === 0 ? $r('app.media.ic_avatar1') : song.label;

    // Online songs always use a neutral dark backdrop; the blurred cover renders on top.
    // Local color extraction is only for local tracks and never tints red.
    if (song.source.length > 0) {
      if (this.isAlive) {
        this.state.imageColor = 'rgba(20, 20, 22, 0.5)';
      }
      // 在线歌曲：预渲染模糊背景（一次性 blur），避免 buildControlStack 中每帧 blur(300) 实时模糊
      if (song.cover.length > 0 && this.isAlive) {
        try {
          const coverPm: image.PixelMap | undefined =
            await PlaybackPage.loadOnlineCoverPixelMap(song.cover);
          if (coverPm !== undefined && this.isAlive && jobSeq === this.imageColorJobSeq) {
            // 流光取色：趁位图已经解码好顺手算一次，不用为它再下载一遍封面
            await this.extractFlowLightColors(coverPm);
            const headFilter = effectKit.createEffect(coverPm);
            if (headFilter !== null) {
              headFilter.blur(PlayerConstants.IMAGE_BLUR);
              const blurred = await headFilter.getEffectPixelMap();
              if (this.isAlive && jobSeq === this.imageColorJobSeq) {
                this.imageLabel = blurred;
              } else {
                this.releasePixelMapQuiet(blurred);
              }
            }
          }
          if (coverPm !== undefined) {
            this.releasePixelMapQuiet(coverPm);
          }
        } catch (_err) {
          // 预渲染失败则回退默认图，不影响播放
        }
      }
      return;
    }

    let mediaData: Uint8Array;
    try {
      mediaData = await ctx.resourceManager.getMediaContent(song.label.id);
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(PlaybackPage.logTag,
        `getMediaContent failed, code=${err?.code}, message=${err?.message}`);
      if (this.isAlive) {
        this.state.imageColor = PlaybackPage.defaultImageBgColor;
      }
      return;
    }
    if (!mediaData || mediaData.byteLength === 0) {
      Logger.error(PlaybackPage.logTag, 'getMediaContent returned empty buffer');
      if (this.isAlive) {
        this.state.imageColor = PlaybackPage.defaultImageBgColor;
      }
      return;
    }

    let pixelMap: image.PixelMap | undefined = undefined;
    const imageSource = image.createImageSource(mediaData.buffer as ArrayBuffer);
    try {
      pixelMap = await imageSource.createPixelMap();
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(PlaybackPage.logTag,
        `createPixelMap failed, code=${err?.code}, message=${err?.message}`);
      if (this.isAlive) {
        this.state.imageColor = PlaybackPage.defaultImageBgColor;
      }
      return;
    } finally {
      try {
        imageSource.release();
      } catch (error) {
        const err = error as BusinessError;
        Logger.warn(PlaybackPage.logTag,
          `imageSource.release failed, resourceId=${song.label.id}, code=${err?.code}, message=${err?.message}`);
      }
    }

    if (pixelMap === undefined) {
      return;
    }

    if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
      this.releasePixelMapQuiet(pixelMap);
      return;
    }

    await new Promise<void>((resolve: () => void) => {
      effectKit.createColorPicker(pixelMap,
        (error: Error | undefined, colorPicker: effectKit.ColorPicker | undefined) => {
          try {
            if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
              return;
            }
            if (error || colorPicker === undefined) {
              const msg =
                error ? `${(error as BusinessError).code} ${(error as BusinessError).message}` : 'no picker';
              Logger.error(PlaybackPage.logTag, `createColorPicker failed: ${msg}`);
              this.state.imageColor = PlaybackPage.defaultImageBgColor;
              return;
            }
            const color = colorPicker.getLargestProportionColor();
            const colorArr = ColorConversion.dealColor(color.red, color.green, color.blue);
            const r = clampRgbByte(colorArr[0]);
            const g = clampRgbByte(colorArr[1]);
            const b = clampRgbByte(colorArr[2]);
            this.state.imageColor = `rgba(${r}, ${g}, ${b}, 0.4)`;
            // 同一次取色的结果顺带算流光色，省掉再建一个 ColorPicker 的开销
            this.publishFlowLightColors(color.red, color.green, color.blue);
          } finally {
            resolve();
          }
        });
    });

    if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
      this.releasePixelMapQuiet(pixelMap);
      return;
    }

    try {
      const headFilter = effectKit.createEffect(pixelMap);
      if (headFilter !== null) {
        headFilter.blur(PlayerConstants.IMAGE_BLUR);
        const blurred = await headFilter.getEffectPixelMap();
        if (this.isAlive && jobSeq === this.imageColorJobSeq) {
          this.imageLabel = blurred;
        } else {
          this.releasePixelMapQuiet(blurred);
        }
      }
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(PlaybackPage.logTag,
        `blur effect failed, code=${err?.code}, message=${err?.message}`);
    } finally {
      this.releasePixelMapQuiet(pixelMap);
    }
  }

  /** Downloads an online cover url and decodes it into a PixelMap (best-effort). */
  private static async loadOnlineCoverPixelMap(url: string): Promise<image.PixelMap | undefined> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 15000
      });
      if (resp.responseCode !== 200 || resp.result === undefined) {
        return undefined;
      }
      const src: image.ImageSource = image.createImageSource(resp.result as ArrayBuffer);
      try {
        return await src.createPixelMap();
      } finally {
        src.release();
      }
    } catch (_err) {
      return undefined;
    } finally {
      req.destroy();
    }
  }

  /** Root column with layered backdrop and lifecycle hooks. */
  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1c1c1e')

      // 流光背景（设置项开关）：必须在内容层之前绘制，否则会盖住封面和歌词
      if (this.flowLightState.enabled) {
        this.FlowLightBackground()
      }

      Column() {
        Column() {
          this.buildControlStack()
        }
        // ★ 展开/收起：内容层贴着底边（父层 justifyContent(End)），
        //   高度从"贴底一条"长到 100% —— 这就是"向上下延伸铺满"。
        //   进度 0 时是 '100%'，与没有动画时逐像素一致。
        .height(this.sheetHeightPercent())
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .backgroundColor(this.state.imageColor)
      .justifyContent(FlexAlign.End)
      // 内容被压扁时裁掉溢出：静止态内容正好 100%，这条裁剪不产生任何视觉差异
      .clip(true)
      // ★ 下拉收起播放器（MusicHome 同款交互）：竖直拖拽跟手收起，松手按阈值决定去留。
      //   放在最外层容器上；歌词那种可滚动子节点会先接到竖直手势，
      //   所以在歌词上滚不会误触发收起（ArkUI 的手势冒泡顺序：子节点优先）。
      .gesture(
        PanGesture(this.panOption)
          .onActionUpdate((event: GestureEvent): void => {
            this.onDismissDrag(event.offsetY, false);
          })
          .onActionEnd((event: GestureEvent): void => {
            this.onDismissDrag(event.offsetY, true);
          })
      )
      // ⚠️ 整页**不做**任何位移/缩放，也**不要**在这里套形状裁剪（clipShape/path）。
      //    曾经为了「一镜到底」在整页上套过 path 裁剪，两次都把播放页搞坏了
      //    （一次打不开、一次卡死），原因见文件末尾的注释块。
      //    现在这套展开只依赖 height/scale/translate 三个基本属性。
      .onAppear(() => {
        this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        this.isAlive = true;
        this.getImageColor();
        this.applyPlaybackWindowChromeImmediately();
        // 页面首次出现时同步一次开关状态（设置页可能刚改过）
        this.applyFlowLightColors();
        this.playbackSwiperIndex = 0;
        // ★ 第一帧已经按"收起"渲染过了（见 aboutToAppear），这里再补间回完整态
        this.playExpandIntro();
      })
      .onDisAppear(() => {
        this.isAlive = false;
        this.state.isShowPlay = false;
        this.imageColorJobSeq++;
        this.releaseBackgroundCoverIfPixelMap();
        this.imageLabel = $r('app.media.ic_avatar1');
        // 页面退场停掉着色器动画：整屏流光是持续的 GPU 开销，后台不该白耗电
        try {
          this.flowLightController.stop();
        } catch (_err) {
        }
        const wu = WindowUtil.getInstance();
        wu.applyPlaybackWindowChrome(false);
        wu.applyPcPlaybackDecorButtonStyle(false);
      })

      // 跨脚本换源醒目提示横幅（悬浮在最上面）
      if (this.switchBanner.text.length > 0) {
        Stack() { this.SwitchBanner() }.zIndex(10)
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // ⚠️ 这里**不要**写 expandSafeArea / ignoreLayoutSafeArea。
    //
    // 参考工程（MusicHome）的播放页完全正常，它的做法是：
    //   1. 壳层 `bindContentCover($$isShowPlay, PlaybackPageCoverContent(), ModalTransition.NONE)`；
    //   2. `PlaybackPageCoverContent` 只是 width/height 100% 的 Column，**不碰安全区**；
    //   3. 底部留白由内容自己加 `padding({ bottom: navigationBarBottomVp })`（见 buildControlStack）。
    // 我们之前在这里叠了 expandSafeArea，反而和系统给的容器打架 —— 越加留白越大。
  }
}

/*
 * ⚠️ 播放页「一镜到底」展开动画**已整体移除**（2026-09-22）。
 *
 * 试过两版，在这台设备上都不行：
 *   1. `clipShape(new PathShape({ commands }))` —— 播放页整个不显示（表现为打不开）；
 *   2. `clip(new Path({ commands }))` —— 点击播放器直接卡死。
 * 两版都依赖同一个手法：用一条 path 把整页裁成迷你条那么大的小窗口、再逐帧长大。
 * 同一个手法换两个 API 得到两种不同的坏结果，说明这条路在当前 SDK/设备上走不通。
 *
 * 已经保留的东西（都在 common/musicbasic，将来重做不用再搭一遍）：
 *   - `PlayerExpandState`（两端封面的窗口矩形 + 相位 + 裁剪矩形计算）；
 *   - `MINI_BAR_COVER_ID` / `PLAYER_BIG_COVER_ID` 两个组件 id；
 *   - 迷你条封面与播放页大封面各自 `onAreaChange` 上报窗口矩形的能力。
 *
 * ⚠️ 重做时**不要再用 path 裁剪**。要那个"小窗口"就用纯布局属性：
 *    外层容器 `width/height` 从迷你条矩形补间到整屏、`position` 从迷你条位置归零、
 *    `clip(true)` 布尔裁剪守住边界；内层再放一个**固定窗口尺寸**的画布包住 PlaybackPage，
 *    这样页面本身不会因为容器变小而重排。这些都是 API 7 的基本属性，没有形状类语义。
 */

/** Builder used by product shells to mount PlaybackPage inside a modal content cover. */
@Builder
export function PlaybackPageCoverContent() {
  Column() {
    PlaybackPage()
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
  // 与参考工程（MusicHome）一致：**不碰安全区**。整屏铺满交给模态容器，
  // 底部留白由 PlaybackPage 内部按 navigationBarBottomVp 自己加 padding。
  // 在这里写 expandSafeArea / ignoreLayoutSafeArea 会与系统容器冲突，留白反而变大。
}

/** Panel-style cover content (wide split layout) for product shells that opt into the panel layout. */
@Builder
export function PlaybackPagePanelCoverContent() {
  Column() {
    PlaybackPage({ panelLayout: true })
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
}
