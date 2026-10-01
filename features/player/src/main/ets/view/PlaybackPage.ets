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

import { AppStorageV2, curves, uiObserver, window } from '@kit.ArkUI';
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
  MorphDrive,
  MorphStage,
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
  /**
   * 容器形变展开的时长（ms）。
   *
   * 无界 Tokens 的主转场档位是 300ms / 420ms；这里取 420ms 那档的观感（整页在缩放，
   * 比局部元素换位需要更多时间），曲线用它的 `cubic-bezier(0.23, 1.0, 0.32, 1.0)`（快出缓入）。
   */
  private static readonly MORPH_OPEN_DURATION_MS: number = 350;
  /**
   * 容器形变收起（反向）的时长（ms）：比展开略快，收起来要干脆。
   */
  /**
   * 容器形变收起（反向）的时长（ms）。
   *
   * 反编译 `doBack` 段1 与展开**对称**，也是 350ms / `Curve.EaseInOut`
   * （它另有两段 50ms 的 `Curve.Friction` 快闪，delay 150/200 —— 那两段动的是
   * 迷你条那侧的内容透明度，我们这边由 `miniBarMetaOpacity/miniBarOpacity` 按进度算，
   * 不需要额外的补间）。
   */
  private static readonly MORPH_CLOSE_DURATION_MS: number = 350;
  /**
   * 点击/起播意图打开时，补间**延后两帧**再起（ms）。
   *
   * 页面这一帧才刚挂载、还没画过第一帧；同帧起补间的话，等第一帧真的画出来时
   * 动画已经走了几十毫秒 —— 用户看到的就是"直接点开是从中间开始的"。
   */
  private static readonly MORPH_INTRO_DELAY_MS: number = 50;
  /**
   * 一次跟手会话的最长合理时长（ms）。
   *
   * `pullDragging` 残留时点击打开会跳过形变初始化（退化成老动画），这条阈值用来
   * 判定"这个标记已经过期"：一次上拉/下拉不可能持续 2 秒以上。
   */
  private static readonly PULL_DRAG_MAX_MS: number = 2000;
  /**
   * 锚点还没量到时的重试间隔（ms）。
   *
   * "点击打开"那一刻迷你条/播放页常常还没布局完（`getFrameNodeById` 拿不到节点），
   * 无界的做法是**注册就绪回调等着**、而不是退化成老动画；我们这里用几帧重试等价实现。
   */
  private static readonly MORPH_RETRY_MS: number = 32;
  /**
   * 剩余重试次数（每次打开重置）—— **照抄反编译的 `PlayerPage.schedulePublishRetry`**：
   *
   *   最多重试 12 次、每次间隔 32ms（总窗口约 384ms），用来等"刚挂载、还没布局完"的
   *   目标节点变成可量测。反编译结论：无界的播放页**也不常驻**（同样是 push 出来的），
   *   它之所以"第一次就有封面飞入"，靠的就是这个重试窗口 + `setFinalStatus()` 兜底。
   */
  private morphRetryLeft: number = 12;
  /**
   * 「可以开始画了」的门：形变真正开始（几何量到并压到起点）之前，整页保持**全透明**。
   *
   * 为什么需要它：为了先量到"原尺寸的封面矩形"，挂载后到形变开始之间会有 1~2 帧
   * 播放页处于**未缩小**状态 —— 那几帧若照常绘制就会闪一下完整播放页。
   * 关掉绘制不影响布局（`opacity` 不参与布局），所以量测照常进行。
   */
  @Local introPaintReady: boolean = false;
  /**
   * 形变早期"底面颜色"淡入的终点进度（0…1）。
   *
   * 迷你条也是在这个进度淡完的（`PlayerExpandState.miniBarOpacity` 用 0.20），
   * 两边必须对齐：底面（底色 + 取色层）到这里正好是播放页真正的背景色，
   * 迷你条到这里正好消失 —— 观感就是"播放条的颜色化成了页面背景、并跟着长大"。
   */
  private static readonly MORPH_BG_FADE_TO: number = 0.20;
  /** 封面「续飞到歌词页」的时长（ms）。比展开略短，因为它只是局部元素换位。 */
  private static readonly LYRIC_MORPH_DURATION_MS: number = 360;
  /** 控制区静止多久后自动收起（ms）。 */
  private static readonly CHROME_AUTO_HIDE_MS: number = 3000;
  /** 手机端 Swiper 里「歌词页」的下标（0 = 封面页）。 */
  private static readonly SWIPER_INDEX_LYRIC: number = 1;
  /** 展开看门狗（ms）：超时还没回到完整态就强制回到完整态。 */
  private static readonly COLLAPSE_WATCHDOG_MS: number = 900;
  /** 展开看门狗定时器句柄。 */
  private collapseWatchdogTimer: number = -1;
  /** 正在播收起动画（防止连点返回播两遍）。 */
  private isClosing: boolean = false;
  /**
   * 本次下拉跟手是否已经把形变相位切到 LEAVING（对标无界的 `drive = FINGER`）。
   *
   * 有了它，松手时才能分清"这次下拉真的跟手过"和"只是极短的一次拖拽"：
   * 后者不能去动形变相位，否则会把静止的 OPEN 态改成 LEAVING。
   */
  private dismissMorphActive: boolean = false;
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
    const progress: number = this.dismissProgressFromDrag(offsetY);
    // ★ 形变那套：下拉收起就是**反向跑同一套几何**（无界也是同一个 progress 正反两用）
    //   —— 整页缩回迷你条那一小块、裁剪窗口收回去、迷你条同时淡回来。
    if (this.expandState.morphUsable) {
      if (!ended) {
        if (!this.dismissMorphActive) {
          this.refreshCollapseGeometry();
          this.dismissMorphActive = true;
          this.expandState.morphBeginLeaving();
        }
        this.expandState.morphDrive = MorphDrive.FINGER;
        this.expandState.applyMorphProgress(1 - progress / 100);
        return;
      }
      if (!this.dismissMorphActive) {
        return;
      }
      this.dismissMorphActive = false;
      if (progress >= PlaybackPage.DISMISS_COMMIT_PROGRESS) {
        // 交给 closeFullScreenPlayback：它会接着把形变补间到 0 再卸载
        this.closeFullScreenPlayback();
        return;
      }
      // 没过阈值：弹回完整态，并把相位收回 OPEN
      this.expandState.morphDrive = MorphDrive.ANIM;
      const gen: number = this.expandState.morphGen;
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, (): void => {
        this.expandState.applyMorphProgress(1);
      });
      setTimeout((): void => {
        if (this.isAlive && !this.isClosing && this.expandState.morphGenAlive(gen)) {
          this.expandState.morphSettleOpen();
        }
      }, 240);
      return;
    }
    // 无有效锚点不运行旧压扁布局，松手满足阈值才直接关闭。
    if (!ended) {
      return;
    }
    if (progress >= PlaybackPage.DISMISS_COMMIT_PROGRESS) {
      this.closeFullScreenPlayback();
      return;
    }
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, (): void => {
      this.collapseProgress = 0;
    });
  }

  // ─────────────────────── 封面续飞到歌词页 ───────────────────────

  /**
   * 播放页 ⇄ 歌词页切换时，让**同一张封面**飞过去（对标无界音乐 `CoverMorph`）。
   *
   * 为什么另画一张而不是动页面里那张：歌词页是 Swiper 的一页，它的封面由布局决定，
   * 而"飞过去"要求封面**脱离布局**在窗口坐标里走。所以只在切换的那段时间里画一张
   * 浮层（`LyricCoverOverlay`），两端位置由 `PlayerExpandState.lyricMorph()` 算。
   *
   * ⚠️ 静止态一定是"不画"（`lyricMorphVisible = false`）：这样即使这套算错了，
   * 也只在切页那 0.36 秒里出问题，不会把播放页搞坏。
   * @param toLyric true = 去歌词页，false = 回封面页
   */
  private animateLyricMorph(toLyric: boolean): void {
    // Lyrics has no cover destination. Do not fabricate a floating thumbnail above its header.
    // The real cover remains in Swiper and uses its native slide; all lyric animations stay intact.
    this.lyricMorphGen++;
    this.lyricMorphVisible = false;
    this.lyricMorphOpacity = 0;
    this.lyricMorphTarget = toLyric;
    this.lyricSwiperSettled = false;
    this.lyricFlightSettled = true;
    Logger.info('RzdLyricMorph', `native swiper only toLyric=${toLyric} overlayNodes=0`);

  }

  private finishLyricMorph(gen: number): void {
    if (gen !== this.lyricMorphGen || !this.lyricSwiperSettled || !this.lyricFlightSettled) {
      return;
    }
    if (!this.lyricMorphTarget) {
      this.lyricMorphVisible = false;
      Logger.info('RzdLyricMorph', `handoff cover gen=${gen}`);
      return;
    }
    this.lyricMorphVisible = false;
    Logger.info('RzdLyricMorph', `handoff lyrics gen=${gen} overlayNodes=0`);
  }

  // ─────────────────────── 控制区自动收起 ───────────────────────

  /** 记录一次控制区交互：唤出并重置自动收起计时。 */
  private touchChrome(): void {
    this.chromeTouchedAtMs = Date.now();
    if (this.chromeCollapsed) {
      this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseOut }, (): void => {
        this.chromeCollapsed = false;
        this.lyricChromeProgress = 1;
      });
      Logger.info('RzdLyricChrome', `show naturalHeight=${this.lyricChromeHeight}`);
    }
    this.scheduleChromeAutoHide();
  }

  // ─────────────────────── 裁剪容器形变（对标无界 ExpandAnimation）───────────────────────

  /**
   * @returns 整页不透明度：**恒为 1**（容器本身不淡）。
   *
   * ⚠️ 这里原来按 `p/0.12` 淡入整个容器，是**我自己的发明**，反编译里
   *    `applyPullProgress` 不碰任何透明度、`overlayColor` 也恒为 `#00000000`。
   *    对应的"起点不空"由背景层的 `pullBgIn`（0→0.30）与叠在最上面的续飞封面/克隆层负责。
   *    用户实测也确认过这一点："无界动画开始不是透明的"。
   */
  private morphOpacityValue(): number {
    // ★ 绘制门（见 `introPaintReady`）：形变开始之前整页不画，避免那 1~2 帧闪出完整播放页。
    // ⚠️ 两条**必须放行**的情况（否则就是"播放界面打不开"）：
    //   1. 已经落位（相位 OPEN）—— 无论门是什么状态，静止态一律要画；
    //   2. 手指正在驱动（上拉/下拉跟手）—— 那条路不进 `tryStartMorphIntro` 的开门分支，
    //      门会一直关着（这正是上一版"打不开播放界面"的根因）。
    if (this.expandState.morphStage === MorphStage.OPEN || this.introPaintReady ||
      (this.expandState.morphUsable && this.expandState.morphSessionDriving())) {
      return 1;
    }
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER &&
      this.expandState.morphUsable) {
      return 1;
    }
    return 0;
  }

  /** 背景全程共用同一张底图，从 25% 半透明连续到落位时不透明。 */
  private backgroundRevealOpacity(): number {
    return this.expandState.morphContainerActive() ?
      0.25 + 0.75 * this.expandState.morphP : 1;
  }

  /**
   * 排定自动收起。
   *
   * 用 `setTimeout` 而不是 `setInterval`：只要每次交互重新排一次就够了，
   * 常驻定时器会在页面不可见时空转（播放页经常长时间挂着）。
   */
  private scheduleChromeAutoHide(): void {
    if (this.chromeTimerId >= 0) {
      clearTimeout(this.chromeTimerId);
      this.chromeTimerId = -1;
    }
    this.chromeTimerId = setTimeout((): void => {
      this.chromeTimerId = -1;
      if (!this.isAlive || this.chromeCollapsed || !this.canHideLyricChrome() || !this.state.isPlay) {
        return;
      }
      // 正在收起/展开播放器时不打扰
      if (this.isCollapsing()) {
        return;
      }
      this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseIn }, (): void => {
        this.chromeCollapsed = true;
        this.lyricChromeProgress = 0;
        Logger.info('RzdLyricChrome', `hide auto naturalHeight=${this.lyricChromeHeight}`);
      });
    }, PlaybackPage.CHROME_AUTO_HIDE_MS);
  }

  private canHideLyricChrome(): boolean {
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
      this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC;
  }

  private hideLyricChrome(): void {
    if (!this.canHideLyricChrome() || this.chromeCollapsed) {
      return;
    }
    this.stopChromeAutoHide();
    this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseOut }, (): void => {
      this.chromeCollapsed = true;
      this.lyricChromeProgress = 0;
    });
    Logger.info(PlaybackPage.logTag, 'lyric chrome hidden: upward gesture');
  }

  /** 停掉自动收起计时（页面卸载、开始收起播放器时调用）。 */
  private stopChromeAutoHide(): void {
    if (this.chromeTimerId >= 0) {
      clearTimeout(this.chromeTimerId);
      this.chromeTimerId = -1;
    }
  }

  /**
   * 壳层拦到系统返回（要求关闭播放页）→ 播收起动画，不要直接消失。
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
      .opacity(FLOW_LIGHT_OPACITY * this.backgroundRevealOpacity())
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

  /**
   * 封面「续飞到歌词页」的浮层（对标无界音乐 CoverMorph）。
   *
   * ## 定位推导（这段值得看，不然看不出那些减法在干嘛）
   *
   * 浮层挂在一个铺满窗口、`alignContent: Center` 的 Stack 里，所以子节点的**自然位置**
   * 是"在窗口里居中"。`position({x, y})` 是在自然位置上再加偏移，不是绝对坐标，
   * 于是要落到窗口坐标 (X, Y) 需要：
   *
   * ```
   *   margin = 自然位置修正 + 目标坐标
   *          = -(窗口尺寸 - 自己尺寸) / 2 + (X, Y)
   * ```
   *
   * 这里把浮层尺寸**取成窗口尺寸**，于是修正项 = (-0, -0)，代码里那些减法就都不需要了：
   * `margin` 直接等于目标坐标。内部那张图再按目标矩形用 `position` + `margin` 放进去，
   * 因为此时外层原点已经与窗口原点重合，内层的推导退化成一个纯减法。
   *
   * 只在切页那 ~0.36 秒里可见；静止态 `lyricMorphVisible = false`，**不产生任何节点**。
   */
  /** @returns 浮层参考用的窗口宽度（vp）。 */
  private morphWindowWidthVp(): number {
    return this.expandState.windowWidthVp;
  }

  /** @returns 浮层参考用的窗口高度（vp）。 */
  private morphWindowHeightVp(): number {
    return this.expandState.windowHeightVp;
  }

  /** 收起进度 0..100：**0 = 完整播放页（静止态）**，100 = 收起成贴底的一条。 */
  @Local collapseProgress: number = 0;

  /**
   * 共享的展开/形变几何（与壳层、迷你条、大封面共用同一个实例）。
   *
   * 里面的 `morph` 容器字段（scale / translate / clipHeight / radius）就是
   * 无界 `ExpandAnimation` 那套"整页缩放 + 竖直裁剪窗口"的状态；
   * 壳层在跟手时改它，本页直接读来渲染。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /**
   * 跟手上拉时把共享进度镜像进来。
   *
   * 壳层（products）在迷你条上做上拉手势、改 `expandState.morph`，
   * 这里只负责在**非容器形变**的老路径（点击打开）下保持 `collapseProgress` 同步。
   */
  @Monitor('expandState.transitionProgress')
  onTransitionProgressChanged(): void {
    if (this.expandState.morphContainerActive()) {
      // 容器形变那条路不用 collapseProgress（高度恒 100%，见 sheetHeightPercent）
      return;
    }
    this.collapseProgress = this.expandState.transitionProgress;
  }

  /** 下拉收起手势（竖直方向）。 */
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  // ═══════════ 封面「续飞到歌词页」（对标 无界音乐 CoverMorph 双端点）═══════════

  /**
   * 封面续飞进度：0 = 停在展开页位置，1 = 已到歌词页位置。
   *
   * 静止在播放页时是 0（**不画飞行封面**，与没有这套动画时逐像素一致）；
   * 只有切到歌词页/切回封面页的那 360ms 里才 0⇄1 过渡。
   */
  @Local lyricMorphT: number = 0;
  /** 飞行封面是否可见（静止态一律 false，保证不影响静态布局）。 */
  @Local lyricMorphVisible: boolean = false;
  @Local lyricMorphOpacity: number = 1;
  private lyricMorphGen: number = 0;
  private lyricMorphTarget: boolean = false;
  private lyricSwiperSettled: boolean = false;
  private lyricFlightSettled: boolean = false;
  @Local lyricChromeProgress: number = 1;
  @Local lyricChromeHeight: number = 0;
  @Local lyricChromeMeasurePending: boolean = true;
  private lyricChromeWidth: number = 0;

  // ═══════════ 控制区静止自动收起（对标 无界音乐 BarCollapse）═══════════

  /** 控制区是否已自动收起（收起后点任意处唤出）。 */
  @Local chromeCollapsed: boolean = false;
  /** 自动收起计时器。 */
  private chromeTimerId: number = -1;
  /** 最后一次控制区交互时间（ms）。 */
  private chromeTouchedAtMs: number = 0;

  // ═══════════ 展开时的逐元素淡入（自持进度，不复用共享相位）═══════════

  /**
   * 展开补间是否在跑。
   *
   * ⚠️ 这是**本地**标志，且只用来决定"要不要用动画值"；只要它是 false，
   * 所有淡入取值一律返回静止态（1 / 0）。这样不存在"标志残留导致内容透明"的可能
   * —— 那是曾经的真实 bug（用户：封面淡淡出现后整页空白）。
   //  形变进度不另存变量：直接复用 `collapseProgress`（见 `morphProgress()`），
   //  避免"高度到了但缩放没到"的两套计时错位。
   */
  @Local expandIntroRunning: boolean = false;

  /** Seeds cover Resource from the current queue item. */
  aboutToAppear(): void {
    // 先记一条"这一页挂载时走的是哪条路"：点击打开 vs 上拉打开的区别就在 `pullDragging`，
    // 排查"点击打开还是旧动画"时这一行最关键（`hdc shell hilog | grep "expand intro"`）。
    Logger.info(PlaybackPage.logTag,
      `aboutToAppear: pullDragging=${this.expandState.pullDragging} ` +
      `usable=${this.expandState.morphUsable} stage=${this.expandState.morphStage}`);
    // ★ **自愈**：见 `onDisAppear` 里那段说明 —— 这两个标记一旦残留，点击打开就永远
    //   跳过形变初始化，只播老动画。这里再兜一层：只有"确实在看手势"（drive=FINGER）
    //   才认为手指在驱动；而且即使如此，只要已经过了 2 秒还没收尾，就一定是残留
    //   （一次跟手不可能持续那么久），直接清掉。
    const dragAgeMs: number = Date.now() - this.expandState.pullStartedAtMs;
    const dragGenuine: boolean = this.expandState.pullDragging &&
      this.expandState.morphDrive === MorphDrive.FINGER && dragAgeMs >= 0 &&
      dragAgeMs < PlaybackPage.PULL_DRAG_MAX_MS;
    if (this.expandState.pullDragging && !dragGenuine) {
      Logger.warn(PlaybackPage.logTag,
        `aboutToAppear: clearing stale pull session (drive=${this.expandState.morphDrive} age=${dragAgeMs}ms)`);
      this.expandState.pullDragging = false;
      this.expandState.morphDrive = MorphDrive.NONE;
    }
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
    this.dismissMorphActive = false;
    // 每次打开都重置重试额度（照抄 `schedulePublishRetry` 的 12×32ms）
    this.morphRetryLeft = 12;
    // ★ 容器形变那条路（对标无界 ExpandAnimation）：不是上拉拉进来的（点击 / 起播意图打开）
    //   就**就地**起一次形变 —— 几何压到起点（p = 0 = 迷你条封面那一小块），
    //   于是第一帧画出来就是"迷你条那里的一小块"，补间在 `onAppear` 里跑。
    //   ⚠️ 返回 false 说明几何没量齐（迷你条封面没上报 / 宿主没尺寸）：必须把相位退回去，
    //      否则 `sheetHeightPercent()` 会一直返回 100%，老路径的"贴底一条长上来"也被卡掉，
    //      用户看到的就是"点开播放器没有任何动画"。
    // ★ **不要在挂载时就把几何压到起点**（这一条是无界 `expand.init` 的顺序，之前的做法反了）：
    //   反编译里 `setupExpandTransition` 是"**先量目标节点矩形**（此刻播放页还没缩、是原尺寸）
    //   → 再 start 形变"。我原来在 `aboutToAppear` 就 `morphBeginEntering()`（= 立刻缩到起点），
    //   于是等到能量的时候，量到的是**被压扁那一帧**的封面 —— 终点就被写坏了：
    //   "第一次没有封面飞入"、"结束时大小不对"、"只移动不缩放"全是这一条引起的。
    //   现在改成：挂载阶段什么都不做，由 `playExpandIntro()`（onAppear 起，带 12×32ms 重试）
    //   在**首次量到**的那一刻才 `measureMini` + `morphBeginEntering()` —— 量的是原尺寸矩形，
    //   紧接着同一帧压到起点（配合下面的 `introPaintReady` 门，不会闪出完整播放页）。
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
    // Hard exits (such as opening another feature) also return the paint owner to the mini bar.
    this.expandState.morphReset();
    ++this.lyricMorphGen;
    this.lyricMorphVisible = false;
    this.lyricChromeProgress = 1;
    this.applyKeepScreenOn(false);
    if (this.bannerClearTimer !== -1) {
      clearTimeout(this.bannerClearTimer);
      this.bannerClearTimer = -1;
    }
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    // 控制区自动收起的计时也要停：页面都走了，别再让定时器空转
    this.stopChromeAutoHide();
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
    // ★ **统一入口 + 无界式兜底**：所有打开方式（点击、起播意图、上拉松手）都从这里进。
    //   · 手指正在驱动 → 让给手势；
    //   · 两端锚点（迷你条封面 + 播放页封面）都量到了 → 走形变（`tryStartMorphIntro`）；
    //   · 还没齐（点击那一刻播放页刚挂载、封面还没布局完）→ **重试若干帧**，
    //     对标无界 `beginMorphEnter` 失败时"注册 onPullReady 等就绪"的做法。
    //
    // ⚠️ 判据必须是**两端**锚点（`morphIntroAnchorsReady`），不能只判"迷你条量到了"：
    //    终点（播放页封面）没就绪时 `endCoverSize = 0`，续飞封面根本不会画
    //    （`morphBridging()` 为 false），而播放页自己那张封面是"落位才现"——
    //    于是头一两次展开的观感就是"点开→什么都没有→啪一下到位"，
    //    和用户投诉的"点击打开还是旧动画"几乎分不出来。
    if (this.tryStartMorphIntro()) {
      return;
    }
    if (this.morphRetryLeft > 0) {
      this.morphRetryLeft--;
      Logger.warn(PlaybackPage.logTag,
        `expand intro: anchors not ready, retry (left=${this.morphRetryLeft}) ` +
        `usable=${this.expandState.morphUsable} bigKnown=${this.expandState.bigCoverAnchored()}`);
      setTimeout((): void => {
        if (this.isAlive && !this.isClosing) {
          this.playExpandIntro();
        }
      }, PlaybackPage.MORPH_RETRY_MS);
      return;
    }
    // ★ 重试用尽 → **直接落位，绝不播老动画**（对标反编译的 `setFinalStatus()`）：
    //   反编译 `setupExpandTransition` 里 `expand.init(...)` 返回 false 的兜底就是
    //   "放弃动画、直接落位"。退回去播"压扁内容层高度"那套老动画是**我的发明**，
    //   也正是用户反复反馈的"点击/返回用的是旧动画"的来源。
    Logger.error(PlaybackPage.logTag,
      'expand intro: anchors never became ready, landing without animation (setFinalStatus)');
    this.expandState.morphReset();
    this.expandState.morphSettleOpen();
    // 无动画落位也必须开门，否则整页会一直停在"不画"的状态（打不开播放页）
    this.introPaintReady = true;
    this.collapseProgress = 0;
    this.expandIntroRunning = false;
  }

  /**
   * 尝试走形变展开路径：量锚点 → 进相位 → 起补间。
   * @returns true = 已经按形变路径开始（调用方不要再走老路径）
   */
  private tryStartMorphIntro(): boolean {
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER) {
      // 手指正在驱动：谁也别抢；绘制门也一并放行（这条路不进下面的开门分支）
      // 首次上拉的目标尚未布局时仍保持透明全尺寸，补量成功再放行。
      this.introPaintReady = this.expandState.morphUsable;
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
      return true;
    }
    this.expandState.pullDragging = false;
    // ★ 判据是**两端锚点都齐**（`morphIntroAnchorsReady`），不是"迷你条量到了"：
    //   终点（播放页封面）没就绪时 `endCoverSize = 0`，续飞封面根本不会画
    //   （`morphBridging()` 为 false），而播放页自己那张封面是"落位才现"——
    //   于是头一两次展开就是"点开→什么都没有→啪一下到位"（用户实测的"第一次没有封面飞入"）。
    //
    // ★ 顺序由 `prepareMorphEntry` 固定：**作废终点 → 在原尺寸时量 → 再压到起点**。
    //   ⚠️ 这里**故意不做 `alreadyRunning` 之类的短路**：一旦短路，就会在
    //      "终点已有、但本轮还没进过形变"的中间态下跳过压起点，
    //      于是 `collapseProgress`/门状态与相位对不上。幂等重入是安全的。
    //   上一版的 bug 正在这里：作废动作被放在 `morphBeginEntering()` 内部，
    //   正好把刚量到的终点抹掉 → 重试期又补不回来（`morphLive()` 挡着）
    //   → 重试用尽无动画落位 ⇒ **点击路径从来没进过 `playMorphOpenIntro()`**。
    if (!this.expandState.prepareMorphEntry(this.getUIContext(), true)) {
      // 保留本轮就绪状态，等待下一次原尺寸布局，不在重试间压缩/复位布局。
      return false;
    }
    if (!this.expandState.morphIntroAnchorsReady()) {
      Logger.warn(PlaybackPage.logTag,
        `expand intro: anchors not ready ` +
        `(usable=${this.expandState.morphUsable} bigKnown=${this.expandState.bigCoverAnchored()})`);
      return false;
    }
    // 几何就绪：开门，允许绘制（此时已经是"迷你条那一小块"的起点态）
    this.introPaintReady = true;
    this.expandIntroRunning = false;
    this.collapseProgress = 0;
    this.playMorphOpenIntro();
    return true;
  }

  /**
   * 老路径（几何没量到时的兜底）：内容层贴着底边，高度从"贴底一条"长到 100%。
   *
   * 只在 `morphUsable === false` 时才会走到这里 —— 正常情况（迷你条在、宿主已量到）
   * 一律走形变那条路。
   */
  private playLegacyExpandIntro(): void {
    try {
      // 逐元素淡入用**本页自持**的进度（1 = 贴底收起 → 0 = 完全展开），与高度补间同起同落。
      // ⚠️ 刻意不复用共享 `PlayerExpandState` 的 preparing/animating 相位：
      //    那套相位的置位点在重构中全丢了，接上去只会得到两种坏结果 ——
      //    「恒走非动画分支 → 淡入等于没写」或「标志残留 → 整块内容算成透明（封面先淡后消失、整页空白）」。
      //    本页自持 + 静止态恒返回 1，就不存在残留态。
      this.expandIntroRunning = true;
      this.getUIContext().animateTo({
        duration: PlaybackPage.EXPAND_DURATION_MS,
        curve: Curve.EaseInOut
      }, (): void => {
        this.collapseProgress = 0;
      });
      setTimeout((): void => {
        if (!this.isAlive) {
          return;
        }
        this.expandIntroRunning = false;
      }, PlaybackPage.EXPAND_DURATION_MS + 30);
    } catch (err) {
      // 补间起不来就立刻回到完整态；看门狗此时还没到点，别让页面停在"收起"那一条上
      const e = err as BusinessError;
      Logger.error(PlaybackPage.logTag, `expand animateTo failed code=${e.code} msg=${e.message}`);
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
    }
  }

  /**
   * 容器形变路径的展开补间：几何在 `aboutToAppear` 已经压到起点（p = 0，
   * 也就是"迷你条那条胶囊"），这里只把它推到 1（铺满）。
   *
   * ⚠️ `animateTo` 补的是**属性值**（scale / translate / height / borderRadius / opacity），
   *    不是 `morphP` 本身 —— 所以闭包里只要把状态落到终点即可，中间帧由框架插值，
   *    所有绑在同一份状态上的属性会一起走同一条曲线。
   */
  private playMorphOpenIntro(): void {
    this.expandIntroRunning = true;
    this.expandState.morphDrive = MorphDrive.ANIM;
    // ⚠️ 补间**延后 50ms** 再起（反编译 `doEnter` 就是 `delay: 50`）：页面这一帧才刚挂载、
    //    还没画过，同帧起补间的话等第一帧真的画出来时动画已经走了几十毫秒 ——
    //    用户看到的就是"直接点开是从中间开始的"。
    // ⚠️ 世代号：收尾回调必须比对 `morphGen`（反编译里 `animGen++` + onFinish 校验），
    //    否则快速连点/收起会串状态。
    const gen: number = this.expandState.morphGen;
    setTimeout((): void => {
      if (!this.expandState.morphGenAlive(gen) || this.isClosing) {
        return;
      }
      try {
        // 主段：反编译 `doEnter` 段1 = 350ms / Curve.EaseInOut
        this.getUIContext().animateTo({
          duration: PlaybackPage.MORPH_OPEN_DURATION_MS,
          curve: Curve.EaseInOut
        }, (): void => {
          this.expandState.applyMorphProgress(1);
        });
      } catch (err) {
        // 补间起不来也要落到完整态，绝不能把播放页留在"迷你条那一小块"
        const e = err as BusinessError;
        Logger.error(PlaybackPage.logTag, `morph open animateTo failed code=${e.code} msg=${e.message}`);
        this.expandIntroRunning = false;
        this.expandState.morphSettleOpen();
        return;
      }
      setTimeout((): void => {
        if (!this.expandState.morphGenAlive(gen) || this.isClosing || !this.isAlive) {
          this.expandState.logMorphOwnership('open-finish-expired');
          return;
        }
        this.expandIntroRunning = false;
        this.expandState.morphSettleOpen();
        // ★ 落位后**重量一次**几何：这一刻页面已经是原尺寸（scale=1、位移=0），
        //   量到的是干净的终点矩形；同时把 aside 的宽度刷新一遍（HDS 底栏排布可能变过）。
        //   ⚠️ 这一量只影响**下一轮**展开（不动本轮终点），所以它是"下一轮更准"的保险，
        //      不是本轮落位对不对的依据。
        this.expandState.measureGeometry(this.getUIContext(), true);
      }, PlaybackPage.MORPH_OPEN_DURATION_MS + 30);
    }, PlaybackPage.MORPH_INTRO_DELAY_MS);
  }

  /**
   * @returns 内容层高度百分比字符串。
   *
   * 进度 0 → `'100%'`（与没有动画时逐像素一致，这是最重要的性质）；
   * 进度 100 → `COLLAPSED_HEIGHT_PERCENT`（贴底一条，大致就是迷你条那一条的高度）。
   */
  private sheetHeightPercent(): string {
    // ⚠️ 容器形变（无界那套）期间**必须恒为 100%**：那套只靠"外层容器缩放 + 裁剪"完成展开，
    //    若这里同时按 collapseProgress 压缩内容层高度，就有两套动画在改同一片布局，
    //    表现为内容被压扁、封面错位。
    if (this.expandState.morphContainerActive()) {
      return '100%';
    }
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
    // Morph dismiss keeps natural layout mounted; opacity/clip handles chrome continuously.
    return !this.expandState.morphContainerActive() && this.collapseProgress > 45;
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

  /** Cover source for the current track: online url when available, else the local cover, else default. */
  private currentCoverSource(): string | Resource {
    const song = this.state.getCurrentSongItem();
    if (song !== undefined) {
      if (song.cover.length > 0) {
        // 在线封面 URL —— 与播放页封面（`PlayerViewModel.songCoverUrl()`）**同一来源**，
        // 续飞封面才不会出现"条形码里是封面、飞过来这张是默认头像"
        return song.cover;
      }
      // 本地/沙箱封面：`label` 是真正的封面 Resource（不是 `ic_avatar1`）
      return song.label;
    }
    return $r('app.media.ic_avatar1');
  }

  /** Blurred backdrop source: online cover url when available, else the local pixel-map / resource. */
  private backgroundImageSource(): string | image.PixelMap | Resource {
    const song = this.state.getCurrentSongItem();
    if (this.isPixelMapCover(this.imageLabel)) {
      return this.imageLabel;
    }
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
  private refreshCollapseGeometry(): void {
    if (this.expandState.morphStage !== MorphStage.OPEN) {
      return;
    }
    this.expandState.measureGeometry(this.getUIContext(), true, true);
    this.expandState.morphInitParams();
    this.expandState.freezeMorphMeta(this.getUIContext());
    this.expandState.logMorphOwnership('close-freeze-natural-open');
    Logger.info(PlaybackPage.logTag, 'collapse geometry refreshed while OPEN');
  }

  private closeFullScreenPlayback(): void {
    if (this.isClosing) {
      return;
    }
    this.refreshCollapseGeometry();
    this.isClosing = true;
    // 正在收起播放器时不要再自动收控制区（两个动画叠一起会很乱）
    this.stopChromeAutoHide();
    // 关闭期间进度会停在"收起"几百毫秒，别让展开看门狗把它抢回完整态
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    // ★ 走的是形变路径就**反向跑同一套几何**：整页缩回迷你条那一小块、裁剪窗口收回去，
    //   最后落回迷你条（LANDING）。展开/收起就是同一套参数的正反两遍，任意时刻都自洽。
    //   ⚠️ 判定用 `morphUsable` 而**不是** `morphContainerActive()`：稳定展开态的相位是
    //      OPEN（不是 ENTERING/LEAVING），用后者判定会掉回"压扁内容层高度"的老动画 ——
    //      用户实测到的「用系统返回关闭还是旧动画」就是这里。
    if (this.expandState.morphUsable) {
      this.expandState.morphBeginLeaving();
      const morphCloseMs: number = PlaybackPage.MORPH_CLOSE_DURATION_MS;
      // 主段：反编译 `doBack` 段1 = 350ms / Curve.EaseInOut（与展开**对称**）
      const gen: number = this.expandState.morphGen;
      this.getUIContext().animateTo({
        duration: morphCloseMs,
        curve: Curve.EaseInOut
      }, (): void => {
        this.expandState.applyMorphProgress(0);
      });
      setTimeout((): void => {
        if (!this.expandState.morphGenAlive(gen)) {
          // 这一轮收起已经被新的形变会话取代（世代号变了）：什么都别动
          return;
        }
        this.isClosing = false;
        this.restorePlaybackWindowChrome();
        // LANDING：此刻播放页已经缩成透明的一小块，把迷你条交还给它
        // （`miniBarOpacity()` 在非 ENTERING/LEAVING 时恒为 1），再卸载。
        this.expandState.morphLand();
        this.state.isShowPlay = false;
        this.expandState.morphReset();
      }, morphCloseMs + 20);
      return;
    }
    // 没有可靠几何时直接关闭，绝不回退到压扁内容层的旧转场。
    Logger.warn(PlaybackPage.logTag, 'collapse without geometry: immediate landing');
    this.isClosing = false;
    this.restorePlaybackWindowChrome();
    this.state.isShowPlay = false;
    this.expandState.morphReset();
  }

  /** True for small-width + medium-height window (phone landscape-ish). */
  private isSmHeightMdLayout(): boolean {
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD;
  }

  /** True when the wide split panel layout should be used (param or wide window). */
  private usePanelLayout(): boolean {
    const size = this.windowInfo.windowSize;
    const landscape: boolean = size.width > size.height && size.height > 0;
    return this.panelLayout || (landscape &&
      this.breakpointEnv.widthBreakpoint !== WidthBreakpoint.WIDTH_SM);
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
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .opacity(0.5)
  }

  /** Main Stack: background art, breakpoint-specific controls and lyrics grid. */
  @Builder
  buildControlStack() {
    Stack() {
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
                  // One visible cover owner during flight; steady cover page stays unchanged.
                  .opacity(this.lyricMorphVisible ? 0 : 1)
                  MiniLyricLinesComponent()
                    .width(StyleConstants.FULL_WIDTH)
                    .margin({
                      left: 4,
                      right: 4
                    })
                    // 小歌词属于"内容"：反编译里 `contentOpacity` 落位才置 1
                    .opacity(this.expandState.morphContentOpacity)
                    // 收起过程中内容被压扁，小歌词会和控制区互相盖住
                    .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
                }
                .width(StyleConstants.FULL_WIDTH)
                // ★ 歌名/歌手那一行**只走顶栏那一档**（`pullChromeOpacity = clamp((effT-0.18)/0.44)`，
                //   0.18 → 0.62），动画过程中就该淡入 —— 与用户拍板的第 2 条一致。
                //
                // ⚠️ 这里原来还叠了一层 `metaOpacityValue() = clamp(1 - morphP/0.35)`：
                //   那**是迷你条那一侧的淡出**公式（t=0.35 就归零），套在播放页这一行上
                //   = 用两个门夹同一块内容 —— `pullChromeOpacity` 明明已经到 1，
                //   却被 `metaOpacityValue` 按到 0，于是歌名/歌手**全程不可见、落位才冒出来**
                //   （用户实测的「展开中文字直到结束才出现」）。
                //   删掉这一层：`MusicPlayInfoBlock.MusicInfoTexts` 自己已经带 `pullChromeOpacity`。
                .opacity(this.expandState.pullChromeOpacity())
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
                .parallelGesture(PanGesture({ direction: PanDirection.Vertical })
                  .onActionUpdate((event: GestureEvent): void => {
                    if (event.offsetY < -12) {
                      this.hideLyricChrome();
                    } else if (event.offsetY > 12) {
                      this.touchChrome();
                    }
                  }))
                .margin({
                  top: this.isSmHeightMdLayout() ? 0 : $r('app.float.margin_lyric')
                })
                .padding({
                  left: $r('app.float.common_padding'),
                  right: $r('app.float.common_padding')
                })
                // 歌词属于"内容"：`contentOpacity`（落位才置 1）
                .opacity(this.expandState.morphContentOpacity)
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
              // ⚠️ 这里**不再**给整个 Swiper 加 `contentOpacity`：按反编译，只有
              //    **封面/歌词**是"落位才出现"的内容，而**歌名/歌手那一行**属于顶栏那一档
              //    （`pullChromeOpacity` 0.18→0.62），要在动画过程里就淡入。
              //    所以分级下移：封面 → MusicPlayInfoBlock 自己带；
              //    歌词 → 各自那两份 LyricsComponent；小歌词 → MiniLyricLinesComponent。
              .onAnimationStart((index: number, targetIndex: number, _event: SwiperAnimationEvent): void => {
                if (index === targetIndex && !this.lyricMorphVisible) {
                  return;
                }
                this.animateLyricMorph(targetIndex === PlaybackPage.SWIPER_INDEX_LYRIC);
              })
              .onAnimationEnd((index: number, _event: SwiperAnimationEvent): void => {
                Logger.info('RzdLyricMorph', `native swiper end index=${index} overlayNodes=0`);
              })
              .onChange((index: number): void => {
                this.playbackSwiperIndex = index;
                this.touchChrome();
                if (index !== PlaybackPage.SWIPER_INDEX_LYRIC) {
                  this.stopChromeAutoHide();
                }
              })

              // 控制区：静止 3 秒自动收起，点/碰任意处唤出（对标无界音乐 BarCollapse）
              Column() {
                Column() {
                  ControlAreaComponent({
                    showBottomOtherRow: true,
                    chromeOffsetY: this.expandState.chromeOffsetY(),
                    chromeOpacity: this.expandState.chromeOpacity(),
                    chromeGap: this.expandState.chromeGapVp()
                  })
                    .width(StyleConstants.FULL_WIDTH)
                }
                .width(StyleConstants.FULL_WIDTH)
                .flexShrink(0)
                .height(this.canHideLyricChrome() && !this.lyricChromeMeasurePending &&
                  this.lyricChromeHeight > 0 ? this.lyricChromeHeight : undefined)
                .padding({
                  left: $r('app.float.common_padding'),
                  right: $r('app.float.common_padding'),
                  bottom: 10
                })
                .onAreaChange((_oldArea: Area, newArea: Area): void => {
                  // Measure natural inner content only while fully expanded, never the clipping shell.
                  const width: number = Number.parseFloat(newArea.width.toString());
                  const height: number = Number.parseFloat(newArea.height.toString());
                  if (Math.abs(width - this.lyricChromeWidth) > 0.5) {
                    this.lyricChromeWidth = width;
                    // Release only inner constraint; outer retains last height during the measuring frame.
                    const wasConstrained: boolean = !this.lyricChromeMeasurePending;
                    this.lyricChromeMeasurePending = true;
                    Logger.info('RzdLyricChrome', `invalidate naturalHeight width=${width}`);
                    if (wasConstrained) {
                      return;
                    }
                  }
                  if (!this.chromeCollapsed && this.lyricChromeProgress === 1 && !this.isCollapsing() &&
                    height > 0 && (this.lyricChromeMeasurePending ||
                    Math.abs(height - this.lyricChromeHeight) > 0.5)) {
                    this.lyricChromeHeight = height;
                    this.lyricChromeMeasurePending = false;
                    Logger.info('RzdLyricChrome', `measure naturalHeight=${height}`);
                  }
                })
                .opacity(this.canHideLyricChrome() ? this.lyricChromeProgress : 1)
                .translate({ y: this.canHideLyricChrome() ? (1 - this.lyricChromeProgress) * 24 : 0 })
              }
              .width(StyleConstants.FULL_WIDTH)
              .height(this.canHideLyricChrome() && this.lyricChromeHeight > 0 ?
                this.lyricChromeHeight * this.lyricChromeProgress : undefined)
              .clip(true)
              .margin({ bottom: this.expandState.chromeOffsetY() })
              .opacity(this.expandState.pullBottomIn())
              .onTouch((_event: TouchEvent): void => {
                this.touchChrome();
              })
              // Full player collapse retains its existing path; lyric hide reclaims layout continuously.
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
            // 顶栏：反编译 `pullChromeOpacity = clamp((effT-0.18)/0.44)`，0.18 → 0.62 淡入
            //（"按钮也是在动画过程就出现了"就是这一层比底栏早得多）
            .opacity(this.expandState.pullChromeOpacity())
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
    // ⚠️ 这里（`buildControlStack` 的根）**不要**再给 `backgroundColor(imageColor)`：
    //    它是一层**恒不透明**的取色底（`imageColor` 的 alpha 是 0.4，但底色本身）
    //    —— 形变期间裁剪窗口只有一小块，它会连同窗口一起把下面的首页糊掉，
    //    再加内部那层近黑底色，观感就是"展开中背景是黑的"。
    //    背景色一律由上面**带淡入窗口**的两层负责（底色 + 取色层），这里保持透明。
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
        // 歌词属于"内容"：`contentOpacity`（落位才置 1）
        .opacity(this.expandState.morphContentOpacity)
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
    wu.applyPlaybackWindowChrome(true, false);
    if (this.isPcFreeWindowDecor()) {
      wu.applyPcPlaybackDecorButtonStyle(true);
    }
  }

  /** Applies playback window chrome: system-bar colors only, window layout stays non-full-screen. */
  private applyPlaybackWindowChromeImmediately(): void {
    const wu = WindowUtil.getInstance();
    wu.applyPlaybackNavigationBarColor(true);
    // Player is an overlay, not a new window. Switching window layout here also relayouts
    // the retained destination underneath and moves its HDS title into the status bar.
    // Keep layout policy owned by EntryAbility; only recolor system chrome.
    wu.applyPlaybackWindowChrome(true, false);
    Logger.info('RzdPlayerRoute', 'enter overlay: window layout unchanged');
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

  /**
   * @returns 形变容器的**高度**：形变期间是"竖直裁剪窗口"（只露出上面这一条），
   *          其余时间恒为 `'100%'`（= 与没有这套动画时逐像素一致）。
   *
   * ⚠️ 静止态**必须**给 `'100%'` 而不是任何算出来的数字：之前用实测的
   *    `contentHeightVp` 当静止高度，而上报源恰好是**这层自己被裁剪时的高度**，
   *    一次上拉之后这个值就被写成 ~360vp，于是每次打开播放页底部都缺一块
   *    （用户实测反馈）。百分比高度由父容器（满屏宿主）决定，不可能算错。
   */
  /**
   * @returns 形变容器的**高度**（= 竖直裁剪窗口）：静止态 `'100%'`（等价于不裁剪）。
   *
   * 不变量：裁剪高度 = 可视高度 / 缩放 ⇒ 屏上那块可视矩形里**正好**是整页，
   * 既没有留白（第四版"黑窗口，中间一个小播放页"就是留白），也没有裁切。
   * ⚠️ 静止态必须给 `'100%'` 而不是任何算出来的数字：百分比由满屏宿主决定，
   *    不会被某次形变的中间态写脏（"底部缺一块"就是这么来的）。
   */
  private morphClipHeight(): Length {
    if (!this.expandState.morphClipping()) {
      return '100%';
    }
    return Math.max(1, this.expandState.morphClipHeight);
  }

  /** Root: 整页缩放 + 竖直裁剪窗口（可视矩形里正好是整页）+ 桥接封面。 */
  build() {
    // ★ 第五版：**整页缩放 + 竖直裁剪窗口**。
    //   可视矩形从**迷你条那条胶囊**长到整屏（"整个播放条延伸铺开"），
    //   下边在前 25% 就贴到宿主底边（否则底部那几十 vp 整段动画都空着）；
    //   内容层高度 = 裁剪高度 = 可视高度 / 缩放，所以可视矩形里**永远填满整页**，
    //   没有留白、也不会被裁；内容层等可视矩形宽高比接近页面时才浮现，
    //   避免中段看到一张被压扁的页面（那正是"从中间开始、看不出展开过程"的来源）。
    //   封面由 `MorphCoverBridge` 单独续飞，**p = 1 才落位**。
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Stack() {
          // ★ 背景 = **半透明 → 不透明**：底色与取色层一起走反编译的
          //   `pullBgIn = clamp(effT / 0.30)`（0 → 0.30 淡入）。
          //   用户要求"整个效果就是半透明过渡到不透明"——所以底色**不能恒为不透明**，
          //   两层一起淡；起点透出来的正是下面那条迷你条（克隆层也画着它）。
          //
          // ⚠️ 但**底色（近黑 #1c1c1e）那一层必须比 `pullBgIn` 更晚到位**
          //   （见 `backgroundRevealOpacity()`）：形变中裁剪窗口是一小块"可视矩形"，
          //   `pullBgIn` 到 0.30 就满不透明时，窗口里从第 30% 起就是**一整块黑**
          //   —— 用户实测的「展开中背景是黑色的」就是这个。首页底色本身是浅色
          //   （`home_page_background` 亮色 #F1F3F5），所以那块黑只能是这里画出来的。
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#1c1c1e')
            .opacity(this.backgroundRevealOpacity())
            // 圆角由每个"铺满"的图层自己带一份：容器自身没有背景色时，
            // `.clip(true)` 不会把圆角作用到子节点上（"第二段圆角突然消失"就是这个）
            .borderRadius(this.expandState.morphRadius)

          // ★ 「颜色逐渐变成背景」那一层：`state.imageColor`（从封面取样）按
          //   `backgroundRevealOpacity()` 淡入 —— 底色之上再加这层取样色，
          //   才是播放页静止态真正的背景。
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.state.imageColor)
            .borderRadius(this.expandState.morphRadius)
            .opacity(this.backgroundRevealOpacity())

          // 背景与控件分离：全程同一张封面底图，任意宽高铺满，不在落位帧才换彩色。
          Image(this.backgroundImageSource())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .blur(this.isPixelMapCover(this.backgroundImageSource()) ? 0 : 80)
            .opacity(0.55 * this.backgroundRevealOpacity())
            .hitTestBehavior(HitTestMode.None)

          // 流光背景（设置项开关）：必须在内容层之前绘制，否则会盖住封面和歌词
          if (this.flowLightState.enabled) {
            this.FlowLightBackground()
          }

          // 封面续飞浮层：夹在背景与内容之间，切页那 0.36 秒里顶替两张静态封面
          // No cover overlay: the lyric page has no matching image destination.

          // ★ 内容层：尺寸恒为 100%（= 裁剪窗口 = 可视矩形 / 缩放），所以永远填满可视矩形
          Column() {        Column() {
              this.buildControlStack()
            }
            // ★ 老路径（几何没量到时的兜底）：内容层贴着底边，高度从"贴底一条"长到 100%
            .height(this.sheetHeightPercent())
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .justifyContent(FlexAlign.End)
          .clip(true)
          // ⚠️ 这里**不再**给整层加透明度/底色：透明度已按反编译拆成三层窗口
          //   （背景 `pullBgIn` / 顶栏 `pullChromeOpacity` / 底栏 `pullBottomIn`），
          //   底色由形变容器里那个取色层负责，否则静止态会少一层颜色。
          // ⚠️ 上拉打开**不在这里做**：它必须挂在壳层（products）。
          //    播放页在 `isShowPlay=false` 时还没挂载，页面收不到手指事件。
          //    职责划分：**上拉=壳层/迷你条（→ morphP 0→1），下拉收起=本页（→ morphP 1→0）**。
          //
          // ⚠️ 这里**什么都不上报**（既不上报尺寸，也不再上报原点）。
          //    本层就是手机侧的 `MORPH_HOST_ID`，而它的高度是**裁剪窗口高度**
          //    （形变期间 ~60vp → 满屏），`globalPosition` 也跟着 translate 走 ——
          //    拿它当"铺满目标"就是第五次自噬（一块黑底 + 播放页展不开），
          //    拿它当"坐标原点"就是让原点追着自己的中间态跑（起点/克隆层整体错位）。
          //    **坐标口径全链统一窗口坐标**（量测本来就是窗口坐标，克隆层的
          //    `.position()` 也落在满屏 Stack 上，同口径），所以根本不需要原点换算。
          //    形变尺寸的唯一权威是壳层按 `windowSize` 上报的 `reportWindow`。
          .onAppear(() => {
            this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            this.isAlive = true;
            this.getImageColor();
            this.applyPlaybackWindowChromeImmediately();
            // 页面首次出现时同步一次开关状态（设置页可能刚改过）
            this.applyFlowLightColors();
            this.playbackSwiperIndex = 0;
            // 封面续飞复位到"展开页端点"（浮层不可见，所以只是状态归零）
            this.lyricMorphT = 0;
            this.lyricMorphVisible = false;
            // 控制区：进来先唤出，3 秒没动自动收起
            this.chromeCollapsed = false;
            this.touchChrome();
            // ⚠️ 上拉打开时进度已经在拖动中走了一部分，这里不能重置；
            //    点击/起播意图打开时进度是 0（见 aboutToAppear）。
            this.collapseProgress = 0;
            // ★ 第一帧已经按"起点"渲染过了（见 aboutToAppear），这里再补间回完整态
            this.playExpandIntro();
          })
          .onDisAppear(() => {
            this.isAlive = false;
            this.state.isShowPlay = false;
            // 下一次打开重新走"先量再缩"的顺序：把绘制门也关回去
            this.introPaintReady = false;
            // ★ 页面卸载时**无条件**复位"跟手会话"的两个标记。
            //   `pullDragging` / `morphDrive` 决定点击打开时要不要做形变初始化；
            //   只要有一轮手势没走到收尾（被系统抢走、中途卸载、硬关闭…）它就会残留，
            //   残留成 (true, FINGER) 时点击打开会**永远跳过形变**，
            //   退化成 `collapseProgress` 那套老动画（用户实测："点击/返回用的还是之前的动画"）。
            this.expandState.pullDragging = false;
            this.expandState.morphDrive = MorphDrive.NONE;
            this.expandState.morphReset();
            this.stopChromeAutoHide();
            this.imageColorJobSeq++;
            this.releaseBackgroundCoverIfPixelMap();
            this.imageLabel = $r('app.media.ic_avatar1');
            // 页面退场停掉着色器动画：整屏流光是持续的 GPU 开销，后台不该白耗电
            try {
              this.flowLightController.stop();
            } catch (_err) {
            }
            const wu = WindowUtil.getInstance();
            wu.applyPlaybackWindowChrome(false, false);
            Logger.info('RzdPlayerRoute', 'leave overlay: window layout unchanged');
            wu.applyPcPlaybackDecorButtonStyle(false);
          })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      }
      .width(StyleConstants.FULL_WIDTH)
      // 裁剪窗口高度 = 可视高度 / 缩放 ⇒ 缩放后正好是那块可视矩形
      .height(this.morphClipHeight())
      // 边界裁剪（圆角由各图层自带；不用 clipShape：它会覆盖 borderRadius，
      // 而且它的形状对齐语义在无设备时没法验证）
      .clip(this.expandState.morphClipping())
      // 整页缩放 + 位移：静止态 scale=1 / translate=0，与没有这套动画时逐像素一致
      .scale({ x: this.expandState.morphScale, y: this.expandState.morphScale, z: 1 })
      .translate({ x: this.expandState.morphTx, y: this.expandState.morphTy })
      .borderRadius(this.expandState.morphRadius)
      .opacity(this.morphOpacityValue())

      // 跨脚本换源醒目提示横幅（悬浮在最上面）
      if (this.switchBanner.text.length > 0) {
        Stack() { this.SwitchBanner() }.zIndex(10)
      }

      // ★ 桥接封面（一镜到底里"封面"那一棒，对标无界 CoverMorph）：
      //   在**宿主坐标**里从迷你条封面飞到播放页封面，**p = 1 时恰好落位**，
      //   之后由播放页自己那张封面接手（形变期间它不画）。
      if (this.expandState.morphBridging()) {
        this.MorphCoverBridge()
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // ★ 下拉收起播放器（MusicHome 同款交互）：竖直拖拽跟手收起，松手按阈值决定去留。
    //   挂在最外层；歌词那种可滚动子节点会先接到竖直手势，
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
  }

  /**
   * 形变期间"续飞封面"浮层：一张脱离布局、按宿主坐标摆放的封面。
   *
   * 静止态**不产生任何节点**（`morphBridging()` 为 false），所以它不可能影响静态布局。
   * `HitTestMode.None` 是必须的：整层铺满屏幕，默认命中的话会把播放页所有点击吃掉。
   */
  @Builder
  MorphCoverBridge() {
    Stack() {
      Image(this.currentCoverSource())
        .width(this.expandState.morphCoverBridge().size)
        // ⚠️ 高度**单独取**（不再写死成 `size`）：播放页封面外有 `layoutWeight(1)` +
        //    `constraintSize(maxWidth/maxHeight)`，量到的矩形不保证是正方形。
        //    按正方形画出来的续飞封面，p=1 交棒给真实封面的那一刻就会跳一下
        //    （用户实测的「结束时封面位置/大小跳一下」）。
        .height(this.expandState.morphCoverBridge().height)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.expandState.morphCoverBridge().radius)
        .clip(true)
        .position({
          x: this.expandState.morphCoverBridge().x,
          y: this.expandState.morphCoverBridge().y
        })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .opacity(this.expandState.morphBridgeOpacity())
    .hitTestBehavior(HitTestMode.None)
  }
}

/*
 * ⚠️ 播放页「一镜到底」展开动画的历史（2026-09-22 / 09-25）——再动手前先读完。
 *
 * 第一版（已废弃）用 path 裁剪把整页裁成迷你条那么大的小窗口再逐帧长大，两个 API 都坏：
 *   1. `clipShape(new PathShape({ commands }))` —— 播放页整个不显示（表现为打不开）；
 *   2. `clip(new Path({ commands }))` —— 点击播放器直接卡死。
 *
 * 现在这版（对标无界音乐 `ExpandAnimation` + `CoverMorph`，**可用**）：
 *   1. **整页缩放 + 竖直裁剪窗口**：`height / scale / translate / clipShape / opacity`
 *      五个属性，形状只用**圆角矩形**（`RectShape`，不是 path）——
 *      见 `PlayerExpandState.applyMorphProgress`；
 *   2. **桥接封面**：形变早期单独画一张封面，从迷你条封面续到播放页封面
 *      （见 `MorphCoverBridge` / `PlayerExpandState.morphCoverBridge`）。
 *
 * 它的四个必要条件（缺一个就会退化成"黑底 + 下方空白 + 一块近正方形"）：
 *   1. **播放页与首页必须在同一棵视图树里**：形变早期可视矩形只有迷你条封面那么大，
 *      其余部分是透明的，要透出下面的首页与迷你条 —— 用 `bindContentCover` 模态不行，
 *      模态宿主是不透明的一层，把首页和迷你条全盖住了。
 *   2. **"铺满"的目标高度必须是恒为满屏的宿主容器实测出来的**：挂在被形变的那层上会自噬
 *      （那层高度就是裁剪窗口），见 `PlayerExpandState.reportHost`。
 *   3. **可视矩形的四条边各自插值**，且**下边要提前贴底**（迷你条离屏幕底边还有几十 vp，
 *      跟着线性走的话整段动画底部都是空的）；位移= 可视左上角 − (布局−可视)/2，
 *      不能照抄无界的"初始位移 × (1-p)"（缩放中心是容器中心，常量补偿中段会顶出屏幕）。
 *   4. **圆角必须用 `clipShape` 裁**：只写 `.borderRadius + .clip(true)` 时，
 *      容器自身没有背景色 → 圆角不作用到子节点 → 内容层一浮出来就变方块。
 *
 * 已经保留的东西（都在 common/musicbasic）：
 *   - `PlayerExpandState`（两端封面的窗口矩形 + 相位 + 容器形变几何）；
 *   - `MINI_BAR_COVER_ID` / `PLAYER_BIG_COVER_ID` 两个组件 id；
 *   - 迷你条封面与播放页大封面各自 `onAreaChange` 上报窗口矩形的能力。
 */

/** Player content builder mounted by product shells as a full-screen overlay above the shell Stack. */
@Builder
export function PlaybackPageCoverContent() {
  Column() {
    PlaybackPage()
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
  // **不碰安全区**：铺满交给壳层给的浮层容器，底部留白由 PlaybackPage 内部按
  // navigationBarBottomVp 自己加 padding。在这里写 expandSafeArea / ignoreLayoutSafeArea
  // 会和外壳容器冲突，留白反而变大。
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
