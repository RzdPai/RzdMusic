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

import { ConfigurationConstant } from '@kit.AbilityKit';
import { AppStorageV2, UIContext, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppStorageKeys } from '../constants/Constants';
import { ImmersiveType } from './ImmersiveType';
import { Logger } from './Logger';

/** AppStorageV2 key for window snapshot; use with {@link getWindowInfoState}. */
export const WINDOW_INFO_STORAGE_KEY: string = AppStorageKeys.WINDOW_INFO;

/**
 * Observable main-window metrics (V2) for layout and insets.
 */
@ObservedV2
export class WindowInfo {
  /** Current window status from the system. */
  @Trace public windowStatusType: window.WindowStatusType = window.WindowStatusType.UNDEFINED;
  /** True when the window uses layout full-screen. */
  @Trace public isFullScreen: boolean = false;
  /** Requested or last reported orientation. */
  @Trace public orientation: window.Orientation = window.Orientation.UNSPECIFIED;
  /** Last known window size in px. */
  @Trace public windowSize: window.Size = { width: 0, height: 0 };
  /** Current width breakpoint of the host window. */
  @Trace public widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_XS;
  /** Current height breakpoint of the host window. */
  @Trace public heightBp: HeightBreakpoint = HeightBreakpoint.HEIGHT_MD;
  /** System status bar avoid area (top). */
  @Trace public avoidSystem?: window.AvoidArea;
  /** Home indicator / navigation bar avoid area (bottom). */
  @Trace public avoidNavigationIndicator?: window.AvoidArea;
  /** Display cutout / notch avoid area. */
  @Trace public avoidCutout?: window.AvoidArea;
  /** System back-gesture avoid area. */
  @Trace public avoidSystemGesture?: window.AvoidArea;
  /** Keyboard avoid area when visible. */
  @Trace public avoidKeyboard?: window.AvoidArea;
  /** Status bar top inset in vp, derived from {@link avoidSystem} top rect. */
  @Trace public statusBarTopVp: number = 0;
  /** Home indicator / nav bar bottom inset in vp from navigation avoid area. */
  @Trace public navigationBarBottomVp: number = 0;
  /** PC free-window title immersive mode; set when title bar is hidden for PC layout. */
  @Trace public immersiveDecor: ImmersiveType = ImmersiveType.NONE;
  /** Window control region width in vp from title-button rect callback. */
  @Trace public titleButtonWidthVp: number = 0;
}

/**
 * Returns the shared {@link WindowInfo} from AppStorageV2, creating the default on first use.
 * @returns Connected observable window state.
 */
export function getWindowInfoState(): WindowInfo {
  return AppStorageV2.connect(WindowInfo, WINDOW_INFO_STORAGE_KEY, () => new WindowInfo())!;
}

/**
 * Singleton that wraps the main window, UIContext, and listeners for the current UIAbility.
 */
export class WindowUtil {
  /** Lazily created process-wide singleton. */
  private static instance: WindowUtil | undefined = undefined;

  /**
   * @returns The shared {@link WindowUtil} instance.
   */
  public static getInstance(): WindowUtil {
    if (WindowUtil.instance === undefined) {
      WindowUtil.instance = new WindowUtil();
    }
    return WindowUtil.instance;
  }

  private constructor() {
  }

  /** Window stage of the current ability, when set. */
  public windowStage?: window.WindowStage;
  /** UIContext of the main window, when set. */
  public uiContext?: UIContext;
  /** Whether the app currently follows system dark color mode (drives navigation bar color). */
  public isDarkMode: boolean = false;
  /** Synchronous main window handle from the window stage. */
  public mainWindow?: window.Window;
  /** Shared observable mirror of window metrics; same reference as AppStorageV2. */
  public mainWindowInfo: WindowInfo = getWindowInfoState();
  /** True when windowTitleButtonRectChange has been registered on mainWindow. */
  private titleButtonRectListenerRegistered: boolean = false;
  /** Snapshot of decor style before full-screen playback on PC; restored when leaving. */
  private playbackSavedDecorButtonStyle: window.DecorButtonStyle | undefined = undefined;
  /** Status bar inset (vp) captured at startup while the window is not yet full-screen. */
  private startupStatusBarTopVp: number = 0;
  /** Navigation bar inset (vp) captured at startup while the window is not yet full-screen. */
  private startupNavigationBarBottomVp: number = 0;

  /** @returns Status bar inset (vp) captured at startup; stable across full-screen toggles. */
  public getStartupStatusBarTopVp(): number {
    return this.startupStatusBarTopVp;
  }

  /** @returns Navigation bar inset (vp) captured at startup; stable across full-screen toggles. */
  public getStartupNavigationBarBottomVp(): number {
    return this.startupNavigationBarBottomVp;
  }

  /** Default title decor strip height (vp) when PC free-window title text is hidden but system buttons stay. */
  public static readonly PC_FREE_WINDOW_DECOR_HEIGHT_VP: number = 56;
  /** Default decor button icon size (vp) for minimal PC title-bar chrome in immersive mode. */
  public static readonly PC_FREE_WINDOW_DECOR_BUTTON_ICON_SIZE_VP: number = 24;

  /** Updates title-button region width in vp for layout padding. */
  private readonly onWindowTitleButtonRectChange = (rect: window.TitleButtonRect) => {
    this.mainWindowInfo.titleButtonWidthVp = rect.width;
  };

  /**
   * Recalculates status bar and home-indicator offsets in vp from avoid areas and UIContext.
   */
  private syncWindowInsetsVp(): void {
    const ctx = this.uiContext;
    const info = this.mainWindowInfo;
    if (ctx === undefined) {
      info.statusBarTopVp = 0;
      info.navigationBarBottomVp = 0;
      return;
    }
    const sys = info.avoidSystem;
    if (sys !== undefined) {
      info.statusBarTopVp = ctx.px2vp(sys.topRect.height);
    } else {
      info.statusBarTopVp = 0;
    }
    const nav = info.avoidNavigationIndicator;
    if (nav !== undefined) {
      info.navigationBarBottomVp = ctx.px2vp(nav.bottomRect.height);
    } else {
      info.navigationBarBottomVp = 0;
    }
    if (this.startupStatusBarTopVp === 0 && info.statusBarTopVp > 0) {
      this.startupStatusBarTopVp = info.statusBarTopVp;
    }
    if (this.startupNavigationBarBottomVp === 0 && info.navigationBarBottomVp > 0) {
      this.startupNavigationBarBottomVp = info.navigationBarBottomVp;
    }
  }

  /** Handler: main window status type changed. */
  public onStatusTypeChange: (statusType: window.WindowStatusType) => void = (statusType: window.WindowStatusType) => {
    this.mainWindowInfo.windowStatusType = statusType;
  };
  /** Handler: main window size or breakpoints changed. */
  public onWindowSizeChange: (windowSize: window.Size) => void = (windowSize: window.Size) => {
    this.mainWindowInfo.windowSize = windowSize;
    try {
      this.mainWindowInfo.widthBp = this.uiContext!.getWindowWidthBreakpoint();
      this.mainWindowInfo.heightBp = this.uiContext!.getWindowHeightBreakpoint();
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`getWindowBreakpoint failed. Code: ${err.code}, message: ${err.message}`);
    }
  };
  /** Handler: an avoid area (status bar, cutout, keyboard, etc.) changed. */
  public onAvoidAreaChange: (avoidOptions: window.AvoidAreaOptions) => void =
    (avoidOptions: window.AvoidAreaOptions) => {
      if (avoidOptions.type === window.AvoidAreaType.TYPE_SYSTEM) {
        this.mainWindowInfo.avoidSystem = avoidOptions.area;
      } else if (avoidOptions.type === window.AvoidAreaType.TYPE_CUTOUT) {
        this.mainWindowInfo.avoidCutout = avoidOptions.area;
      } else if (avoidOptions.type === window.AvoidAreaType.TYPE_SYSTEM_GESTURE) {
        this.mainWindowInfo.avoidSystemGesture = avoidOptions.area;
      } else if (avoidOptions.type === window.AvoidAreaType.TYPE_KEYBOARD) {
        this.mainWindowInfo.avoidKeyboard = avoidOptions.area;
      } else if (avoidOptions.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
        this.mainWindowInfo.avoidNavigationIndicator = avoidOptions.area;
      }
      this.syncWindowInsetsVp();
    };

  /**
   * Caches the window stage and resolves the main window synchronously.
   * @param windowStage The ability's window stage.
   */
  setWindowStage(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    try {
      this.mainWindow = this.windowStage.getMainWindowSync();
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`getMainWindowSync failed. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * Caches {@link UIContext} from the main window; call after {@link setWindowStage}.
   */
  setUIContext(): void {
    try {
      this.uiContext = this.mainWindow!.getUIContext();
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`getUIContext failed. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * Toggles layout full-screen and updates {@link WindowInfo.isFullScreen} on success.
   * @param isFullScreen Whether the window should use layout full-screen.
   */
  setFullScreen(isFullScreen: boolean): void {
    try {
      this.mainWindow!.setWindowLayoutFullScreen(isFullScreen)
        .then(() => {
          Logger.info(`Succeeded in setting full-screen mode.`);
          this.mainWindowInfo.isFullScreen = isFullScreen;
        })
        .catch((err: BusinessError) => {
          Logger.error(`Failed to set full-screen mode. Code: ${err.code}, message: ${err.message}`);
        });
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`setWindowLayoutFullScreen sync error. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * Sets title bar control button look (minimize / maximize / close) for free-window style on PC.
   * @param style Decorator button style; must run on a valid main window.
   */
  setDecorButtonStyle(style: window.DecorButtonStyle): void {
    if (this.mainWindow === undefined) {
      Logger.error('setDecorButtonStyle: mainWindow is undefined');
      return;
    }
    try {
      this.mainWindow.setDecorButtonStyle(style);
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`setDecorButtonStyle failed. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * Sets status / navigation / home-indicator bar color and other system bar properties.
   * @param props System bar property payload per window API.
   */
  setWindowSystemBarProperties(props: window.SystemBarProperties): void {
    if (this.mainWindow === undefined) {
      Logger.error('setWindowSystemBarProperties: mainWindow is undefined');
      return;
    }
    try {
      this.mainWindow.setWindowSystemBarProperties(props).catch((err: BusinessError) => {
        Logger.error(`setWindowSystemBarProperties failed. Code: ${err.code}, message: ${err.message}`);
      });
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`setWindowSystemBarProperties sync error. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * When entering or leaving full-screen playback: optionally toggles full-screen and sets status bar
   * content color. Does not change decor buttons; for that use {@link applyPcPlaybackDecorButtonStyle} on PC.
   * Also paints the navigation bar to match playback (dark) or page background (light/dark).
   * Phone shells pass fullScreen=false so the window layout never changes and the underlying page
   * stays stable while the playback cover slides in/out.
   * @param enter True when opening full-screen player UI, false when closing.
   * @param fullScreen Whether to also switch the window layout full-screen state. Defaults to true.
   */
  applyPlaybackWindowChrome(enter: boolean, fullScreen: boolean = true): void {
    if (fullScreen) {
      this.setFullScreen(enter);
    }
    this.setWindowSystemBarProperties({
      statusBarContentColor: enter ? '#FFFFFF' : (this.isDarkMode ? '#FFFFFF' : '#000000'),
      navigationBarColor: enter ? '#000000' : (this.isDarkMode ? '#000000' : '#F1F3F5')
    });
  }

  /**
   * Paints only the navigation bar for playback (dark) or restores the page color.
   * Used to darken the bottom bar immediately while the full-screen switch is deferred
   * until the slide-in transition finishes.
   * @param enter True when opening full-screen player UI, false when closing.
   */
  applyPlaybackNavigationBarColor(enter: boolean): void {
    this.setWindowSystemBarProperties({
      navigationBarColor: enter ? '#000000' : (this.isDarkMode ? '#000000' : '#F1F3F5')
    });
  }

  /**
   * Paints the system navigation bar with the app page background color so the bar
   * region blends with page content (light #F1F3F5, dark #000000), and remembers the
   * current dark-mode flag for later window chrome updates.
   * @param isDark True when the app currently follows dark color mode.
   */
  applyNavigationBarColor(isDark: boolean): void {
    this.isDarkMode = isDark;
    this.setWindowSystemBarProperties({
      navigationBarColor: isDark ? '#000000' : '#F1F3F5'
    });
  }

  /**
   * For PC free-window + immersive title: dark title-bar control icons in full-screen playback, restore snapshot when
   * leaving. Check {@link WindowInfo.immersiveDecor} to match the home page.
   * @param enter True to apply dark playback style; false to restore the saved style.
   */
  applyPcPlaybackDecorButtonStyle(enter: boolean): void {
    if (this.mainWindow === undefined) {
      return;
    }
    const win = this.mainWindow;
    try {
      if (enter) {
        if (this.playbackSavedDecorButtonStyle === undefined) {
          this.playbackSavedDecorButtonStyle = win.getDecorButtonStyle();
        }
        const base = this.playbackSavedDecorButtonStyle;
        win.setDecorButtonStyle({
          colorMode: ConfigurationConstant.ColorMode.COLOR_MODE_DARK,
          buttonIconSize: base.buttonIconSize,
          buttonBackgroundSize: base.buttonBackgroundSize,
          spacingBetweenButtons: base.spacingBetweenButtons,
          closeButtonRightMargin: base.closeButtonRightMargin,
          buttonBackgroundCornerRadius: base.buttonBackgroundCornerRadius
        });
      } else {
        if (this.playbackSavedDecorButtonStyle !== undefined) {
          win.setDecorButtonStyle(this.playbackSavedDecorButtonStyle);
          this.playbackSavedDecorButtonStyle = undefined;
        }
      }
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`applyPcPlaybackDecorButtonStyle failed. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * PC/2in1: hide the title bar in free window but keep the three system buttons. Call from PC ability only; phone
   * default entry should not use this.
   * @param enabled True to enable immersive title chrome; false to show standard title and unregister listeners.
   * @param decorHeightVp Title decor height in vp when enabling; omit to use PC_FREE_WINDOW_DECOR_HEIGHT_VP.
   * @param decorButtonIconSizeVp System button icon size in vp when enabling; omit to use
   *   PC_FREE_WINDOW_DECOR_BUTTON_ICON_SIZE_VP.
   */
  applyPcFreeWindowTitleImmersive(enabled: boolean, decorHeightVp?: number, decorButtonIconSizeVp?: number): void {
    if (this.mainWindow === undefined) {
      Logger.error('applyPcFreeWindowTitleImmersive: mainWindow is undefined');
      return;
    }
    const win = this.mainWindow;
    if (enabled) {
      const heightVp = decorHeightVp ?? WindowUtil.PC_FREE_WINDOW_DECOR_HEIGHT_VP;
      const iconSizeVp = decorButtonIconSizeVp ?? WindowUtil.PC_FREE_WINDOW_DECOR_BUTTON_ICON_SIZE_VP;
      try {
        win.setWindowDecorVisible(false);
        win.setWindowDecorHeight(heightVp);
        win.setDecorButtonStyle({ buttonIconSize: iconSizeVp });
        if (!this.titleButtonRectListenerRegistered) {
          win.on('windowTitleButtonRectChange', this.onWindowTitleButtonRectChange);
          this.titleButtonRectListenerRegistered = true;
        }
        this.mainWindowInfo.immersiveDecor = ImmersiveType.IMMERSIVE;
        Logger.info('applyPcFreeWindowTitleImmersive enabled');
      } catch (error) {
        let err = error as BusinessError;
        Logger.error(`applyPcFreeWindowTitleImmersive enable ${err.code} ${err.message}`);
      }
    } else {
      try {
        if (this.titleButtonRectListenerRegistered) {
          win.off('windowTitleButtonRectChange', this.onWindowTitleButtonRectChange);
          this.titleButtonRectListenerRegistered = false;
        }
        this.mainWindowInfo.titleButtonWidthVp = 0;
        this.mainWindowInfo.immersiveDecor = ImmersiveType.NONE;
        win.setWindowDecorVisible(true);
        Logger.info('applyPcFreeWindowTitleImmersive disabled');
      } catch (error) {
        let err = error as BusinessError;
        Logger.error(`applyPcFreeWindowTitleImmersive disable ${err.code} ${err.message}`);
      }
    }
  }

  /**
   * Sets preferred window orientation and mirrors it to {@link WindowInfo.orientation} on success.
   * @param orientation Target orientation.
   */
  setWindowOrientation(orientation: window.Orientation): void {
    try {
      this.mainWindow!.setPreferredOrientation(orientation)
        .then(() => {
          Logger.info(`Succeeded in setting window orientation.`);
          this.mainWindowInfo.orientation = orientation;
        })
        .catch((err: BusinessError) => {
          Logger.error(`Failed to set window orientation. Code: ${err.code}, message: ${err.message}`);
        });
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`setPreferredOrientation sync error. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * Binds the main window, registers one-shot listeners, and loads initial size, breakpoints, and avoid areas.
   */
  updateWindowInfo(): void {
    try {
      this.mainWindowInfo.windowStatusType = this.mainWindow!.getWindowStatus();
      this.mainWindow!.on('windowStatusChange', this.onStatusTypeChange);

      let width: number = this.mainWindow!.getWindowProperties().windowRect.width;
      let height: number = this.mainWindow!.getWindowProperties().windowRect.height;
      let windowSize: window.Size = {
        width: width,
        height: height
      };
      this.mainWindowInfo.windowSize = windowSize;
      this.mainWindowInfo.widthBp = this.uiContext!.getWindowWidthBreakpoint();
      this.mainWindowInfo.heightBp = this.uiContext!.getWindowHeightBreakpoint();
      this.mainWindow?.on('windowSizeChange', this.onWindowSizeChange);

      this.mainWindowInfo.avoidSystem = this.mainWindow?.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.mainWindowInfo.avoidNavigationIndicator =
        this.mainWindow?.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.mainWindowInfo.avoidCutout = this.mainWindow?.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      this.mainWindowInfo.avoidSystemGesture =
        this.mainWindow?.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM_GESTURE);
      this.mainWindowInfo.avoidKeyboard = this.mainWindow?.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
      this.mainWindow?.on('avoidAreaChange', this.onAvoidAreaChange);
      this.syncWindowInsetsVp();
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`updateWindowInfo failed. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * Unregisters all listeners; safe if some callbacks were never added.
   */
  release(): void {
    this.playbackSavedDecorButtonStyle = undefined;
    try {
      this.mainWindow!.off('windowStatusChange', this.onStatusTypeChange);
      this.mainWindow!.off('windowSizeChange', this.onWindowSizeChange);
      this.mainWindow!.off('avoidAreaChange', this.onAvoidAreaChange);
      if (this.titleButtonRectListenerRegistered) {
        this.mainWindow!.off('windowTitleButtonRectChange', this.onWindowTitleButtonRectChange);
        this.titleButtonRectListenerRegistered = false;
      }
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`WindowUtil release failed. Code: ${err.code}, message: ${err.message}`);
    }
  }
}
