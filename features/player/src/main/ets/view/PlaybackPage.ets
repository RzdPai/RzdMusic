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
import {
  AppStorageKeys,
  BreakpointConstants,
  CoverRadiusState,
  getWindowInfoState,
  ImmersiveType,
  isWidthBreakpointLgOrXl,
  Logger,
  MusicStoreService,
  PlaybackShellConstants,
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
  }

  aboutToDisappear(): void {
    this.applyKeepScreenOn(false);
    if (this.bannerClearTimer !== -1) {
      clearTimeout(this.bannerClearTimer);
      this.bannerClearTimer = -1;
    }
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

  /** Closes the full-screen player: restores window chrome, then the sheet dismisses natively. */
  private closeFullScreenPlayback(): void {
    this.restorePlaybackWindowChrome();
    this.state.isShowPlay = false;
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
                    isDismissing: false,
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
                    isDismissing: false,
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
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .padding({
          bottom: WindowUtil.getInstance().getStartupNavigationBarBottomVp(),
          top: WindowUtil.getInstance().getStartupStatusBarTopVp()
        }).padding({
          bottom: WindowUtil.getInstance().getStartupNavigationBarBottomVp(),
          top: WindowUtil.getInstance().getStartupStatusBarTopVp()
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
            isDismissing: false,
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
        top: WindowUtil.getInstance().getStartupStatusBarTopVp(),
        bottom: WindowUtil.getInstance().getStartupNavigationBarBottomVp()
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
    wu.applyPlaybackWindowChrome(true, false);
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

      Column() {
        Column() {
          this.buildControlStack()
        }
        .height('100%')
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .backgroundColor(this.state.imageColor)
      .justifyContent(FlexAlign.End)
      .onAppear(() => {
        this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        this.isAlive = true;
        this.getImageColor();
        this.applyPlaybackWindowChromeImmediately();
        this.playbackSwiperIndex = 0;
      })
      .onDisAppear(() => {
        this.isAlive = false;
        this.state.isShowPlay = false;
        this.imageColorJobSeq++;
        this.releaseBackgroundCoverIfPixelMap();
        this.imageLabel = $r('app.media.ic_avatar1');
        const wu = WindowUtil.getInstance();
        wu.applyPlaybackWindowChrome(false);
        wu.applyPcPlaybackDecorButtonStyle(false);
      })

      // 跨脚本换源醒目提示横幅（悬浮在最上面）
      if (this.switchBanner.text.length > 0) {
        Stack() { this.SwitchBanner() }.zIndex(10)
      }
    }

  }
}

/** Builder used by product shells to mount PlaybackPage inside a modal content cover. */
@Builder
export function PlaybackPageCoverContent() {
  Column() {
    PlaybackPage()
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
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
