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

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, ConfigurationConstant, Want } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AmbientState, AppStorageKeys, BarScrollHelper, RouterUrlConstants, BreakpointType, HomeSourceState, LyricBlurState, LyricFontSizeState, MusicAppState, MusicStoreService, PlaybackFlowLightState, ShowMiniLyricState, ThemeState, TitleBarConstants, UseAccountRecState, WindowInfo, buildTitleMaterial, getStatusBarTopVpFromWindowUtil, getWindowInfoState } from 'musicbasic';
import { BlurStrategy, HdsNavigation, HdsNavigationTitleMode, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';
import { LXUserApiInfo, lxSourceManager, MediaService } from 'player';
import { AccountManageSheet } from '../account/AccountManageSheet';
import { PlatformMusicPage } from '../account/PlatformMusicPage';

import { CustomColorSheetContent } from './CustomColorSheetContent';
import { SettingsDetailPage, SettingsDetailRouteParam } from './SettingsDetailPage';
import { CapsuleSegmentedSelector } from './CapsuleSegmentedSelector';
import { OptionChoiceSheet } from './OptionChoiceSheet';
import { DownloadManagerSection } from './DownloadManagerSection';
const LX_ONLINE_IMPORT_MAX_BYTES: number = 9 * 1024 * 1024;
const LX_ONLINE_IMPORT_TIMEOUT: number = 15000;
const DEFAULT_SETTING_INDEX: number = 4;

/** 设置页大卡片内的一行设置入口。 */
class SettingsEntry {
  icon: Resource = $r('app.media.ic_system');
  title: Resource | string = '';
  subtitle: string = '';
  onClick: () => void = (): void => {};
  id: number = -1;
  /** 搜索用中文标签（配合顶部搜索框过滤设置项）。 */
  searchText: string = '';
}

/**
 * Settings tab: music source (LX user API) management with file import and
 * online import by URL, plus playback quality selection.
 */
@ComponentV2
export struct SettingPage {
  /** Window breakpoint for the HDS home-style responsive title. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local lxApiList: LXUserApiInfo[] = [];
  @Local activeSource: string = '';
  @Local engineReady: boolean = false;
  @Local engineSources: string = '{}';
  @Local lastError: string = '';
  @Local playLog: string = '';
  /** 设置页统一底部弹窗开关（在线导入 / 自定义颜色 / 平台账号 / 平台音乐，避免同组件多 bindSheet 冲突） */
  @Local showSettingSheet: boolean = false;
  @Consumer('pageIndexInfos') pageStack: NavPathStack = new NavPathStack();
  @Local settingStack: NavPathStack = new NavPathStack();
  @Local selectedIndex: number = -1;
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** 当前弹窗类型：0=在线导入，1=自定义颜色，2=平台账号，3=平台音乐，4=播放，5=音源，6=下载，7=主题，8=其它，9=关于，10=下载管理。 */
  @Local activeSettingSheet: number = -1;
  /** 搜索关键词（顶部搜索栏过滤设置项）。 */
  @Local searchKeyword: string = '';
  /** sheet 关闭动画进行中标识，用于把 "关闭期间点开下一个" 排队到关闭完成后。 */
  private sheetClosing: boolean = false;
  /** 关闭动画期间排队等待打开的 sheet 类型，-1 表示无排队。 */
  private pendingSheetIndex: number = -1;
  @Local onlineUrl: string = '';
  @Local importing: boolean = false;
  @Local playQuality: string = '';
  private readonly qualityOptions: string[] =
    ['128k', '320k', 'flac', 'flac24bit', 'hires', 'atmos', 'atmos_plus', 'master'];
  @Local ambientLevel: number = 0;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local customColor: string = '';
  @Local colorMode: number = 2;
  private readonly presetColors: string[] = [
    '#E60012', '#FF6B35', '#FFC107', '#31C27C',
    '#4A90D9', '#7C4DFF', '#FF4081', '#00BCD4', '#607D8B'
  ];
  /** Scroller bound to the HDS title bar so the scroll effect (gradient blur) can fire. */
  private pageScroller: Scroller = new Scroller();
  /** 全局播控状态：滚动联动双层底栏需要写 miniBarExpanded / hdsBarLayoutMode。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;

  /** Applies a theme color (hex) and persists it. */
  private applyThemeColor(color: string): void {
    if (!/^#[0-9a-fA-F]{6}$/.test(color)) {
      return;
    }
    this.themeState.color = color;
    MusicStoreService.getInstance().setThemeColor(color);
  }
  private readonly ambientOptions: string[] = ['跟随系统', '弱', '均衡', '强'];
  /** Download file name format options (labels), values: title/artist_title/title_artist. */
  private readonly nameFormatOptions: string[] = ['歌曲名', '艺术家-标题', '标题-艺术家'];
  private readonly nameFormatValues: string[] = ['title', 'artist_title', 'title_artist'];
  /** Add-to-playlist position options (labels), values: top/bottom. */
  private readonly addPositionOptions: string[] = ['顶部', '底部'];
  private readonly addPositionValues: string[] = ['top', 'bottom'];
  private readonly homeSourceOptions: string[] = ['QQ', '酷狗', '网易'];
  private readonly homeSourceValues: string[] = ['qq', 'kg', 'wy'];
  /** On/off toggle options for segment-button style switches. */
  private readonly onOffOptions: string[] = ['开', '关'];
  /** Save location options for the download save-mode selector. */
  private readonly saveLocationOptions: string[] = ['手动选择', 'Download目录'];
  /** Day/night/system color-mode options. */
  private readonly colorModeOptions: string[] = ['日间', '夜间', '跟随系统'];
  /** Whether downloads save to the app Download dir instead of asking for a folder. */
  @Local saveToDownloadDir: boolean = false;
  /** Selected download file name format key. */
  @Local downloadNameFormat: string = 'title';
  /** Selected add-to-playlist position key. */
  @Local playlistAddPosition: string = 'bottom';
  /** Whether the playback page shows mini lyric lines below the cover. */
  @Local showMiniLyric: boolean = false;
  /** 播放页是否启用流光背景（颜色随封面动态取色）。 */
  @Local playbackFlowLight: boolean = false;
  /** Whether playback shares audio focus with other apps. */
  @Local audioMix: boolean = false;
  @Local crossScriptFallback: boolean = true;
  /** Whether the lyrics page applies blur to non-active lines. */
  @Local lyricBlurEnabled: boolean = true;
  /** 歌词页当前行高亮字号（滑块可调，持久化）。 */
  @Local lyricFontSize: number = 28;
  /** Whether the lyrics/playback page keeps the screen on. */
  @Local keepScreenOn: boolean = false;
  /** Whether downloaded file names include the quality tag. */
  @Local downloadQualityTag: boolean = false;
  /** Home recommendation source ('qq'|'kg'|'wy'|'mg'). */
  @Local homeSource: string = 'qq';
  /** Whether the home recommendation uses the logged-in QQ account's daily picks. */
  @Local useAccountRec: boolean = false;

  aboutToAppear(): void {
    this.refresh();
    this.syncWideSettingLayout();
  }

  private isWideSettingLayout(): boolean {
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD ||
      this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
      this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_XL;
  }

  private navBarWidthValue(): string {
    if (!this.isWideSettingLayout()) {
      return '100%';
    }
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD ? '50%' : '36%';
  }

  private syncWideSettingLayout(): void {
    if (this.isWideSettingLayout() && this.settingStack.size() === 0) {
      this.settingStack.disableAnimation(true);
      this.openSettingSheet(DEFAULT_SETTING_INDEX);
    }
  }

  @Monitor('windowInfo.widthBp')
  onWindowWidthBpChanged(): void {
    this.syncWideSettingLayout();
  }

  private refresh(): void {
    this.lxApiList = lxSourceManager.getApiList();
    this.activeSource = AppStorage.get<string>('lxActiveSource') ?? '';
    if (this.activeSource.length === 0) {
      this.engineReady = false;
    } else {
      this.engineReady = AppStorage.get<boolean>('lxEngineReady') === true;
    }
    this.engineSources = AppStorage.get<string>('lxEngineSources') ?? '{}';
    this.playQuality = AppStorage.get<string>('lxPlayQuality') ?? '128k';
    this.ambientLevel = MusicStoreService.getInstance().getAmbientLevel();
    this.showMiniLyric = MusicStoreService.getInstance().getShowMiniLyric();
    this.playbackFlowLight = MusicStoreService.getInstance().getPlaybackFlowLight();
    this.crossScriptFallback = MusicStoreService.getInstance().getCrossScriptFallback();
    this.audioMix = MusicStoreService.getInstance().getAudioMix();
    this.lyricBlurEnabled = MusicStoreService.getInstance().getLyricBlurEnabled();
    this.saveToDownloadDir = MusicStoreService.getInstance().getDownloadSaveMode() === 'download';
    this.downloadNameFormat = MusicStoreService.getInstance().getDownloadNameFormat();
    this.playlistAddPosition = MusicStoreService.getInstance().getPlaylistAddPosition();
    this.keepScreenOn = MusicStoreService.getInstance().getKeepScreenOn();
    this.downloadQualityTag = MusicStoreService.getInstance().getDownloadQualityTag();
    this.homeSource = MusicStoreService.getInstance().getHomeSource();
    this.useAccountRec = MusicStoreService.getInstance().getUseAccountRec();
    this.lyricFontSize = MusicStoreService.getInstance().getLyricFontSize();
    this.lastError = AppStorage.get<string>('lxLastError') ?? '';
    this.playLog = AppStorage.get<string>('lxPlayLog') ?? '';
    this.colorMode = MusicStoreService.getInstance().getColorMode();
  }

  private copyPlayLog(): void {
    const log: string = this.playLog.length > 0 ? this.playLog : this.lastError;
    if (log.length === 0) {
      this.toast('暂无日志');
      return;
    }
    const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, log);
    const sysPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    sysPasteboard.setData(pasteData);
    this.toast('日志已复制');
  }

  private openSettingSheet(index: number): void {
    this.selectedIndex = index;
    if (this.isWideSettingLayout()) {
      return;
    }
    const param = new SettingsDetailRouteParam();
    param.index = index;
    this.pageStack.pushPathByName(RouterUrlConstants.SETTINGS_DETAIL, param);
    this.selectedIndex = -1;
  }

  /** 关闭设置弹窗；标记动画进行中，防止立刻重开被吞。 */
  private closeSettingSheet(): void {
    this.sheetClosing = true;
    this.showSettingSheet = false;
  }

  /** bindSheet onWillDismiss：点击遮罩/下滑关闭时同步状态并放行关闭。 */
  private onSheetWillDismiss(action: DismissSheetAction): void {
    if (this.showSettingSheet) {
      this.sheetClosing = true;
      this.showSettingSheet = false;
    }
    action.dismiss();
  }

  /** bindSheet onDisappear：关闭动画完全结束后，把排队中的下一个弹窗打开。 */
  private onSheetDisappear(): void {
    this.sheetClosing = false;
    if (this.pendingSheetIndex >= 0) {
      const next: number = this.pendingSheetIndex;
      this.pendingSheetIndex = -1;
      this.activeSettingSheet = next;
      this.showSettingSheet = true;
    }
  }

  private activeSourceLabel(): string {
    if (this.activeSource.length === 0) {
      return '未选择';
    }
    for (let i = 0; i < this.lxApiList.length; i++) {
      if (this.lxApiList[i].id === this.activeSource) {
        return this.lxApiList[i].name;
      }
    }
    return this.activeSource;
  }

  private nameFormatLabel(): string {
    const idx = this.nameFormatValues.indexOf(this.downloadNameFormat);
    return idx >= 0 ? this.nameFormatOptions[idx] : this.downloadNameFormat;
  }

  private colorModeLabel(): string {
    if (this.colorMode === 0) return '日间';
    if (this.colorMode === 1) return '夜间';
    return '跟随系统';
  }

  private homeSourceLabel(): string {
    const idx = this.homeSourceValues.indexOf(this.homeSource);
    return idx >= 0 ? this.homeSourceOptions[idx] : this.homeSource;
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  /** Opens the donation page in the system browser. */
  private openDonate(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (ctx === undefined) {
      return;
    }
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: 'https://donate.rzdpai.com'
      };
      ctx.startAbility(want);
    } catch (_err) {
      this.toast('无法打开捐赠页面');
    }
  }

  /** Copies the QQ group number to the system clipboard. */
  private copyQqGroup(): void {
    const groupNumber: string = '1050543607';
    const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, groupNumber);
    const sysPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    sysPasteboard.setData(pasteData);
    this.toast('已复制群号 ' + groupNumber);
  }

  private engineTimer: number = 0;

  /** Polls the LX engine ready state until it becomes ready (or the page leaves). */
  private startEnginePolling(): void {
    this.stopEnginePolling();
    this.engineTimer = setInterval(() => {
      this.refresh();
      if (this.activeSource.length === 0 || AppStorage.get<boolean>('lxEngineReady') === true) {
        this.stopEnginePolling();
      }
    }, 1000);
  }

  private stopEnginePolling(): void {
    if (this.engineTimer > 0) {
      clearInterval(this.engineTimer);
      this.engineTimer = 0;
    }
  }

  aboutToDisappear(): void {
    this.stopEnginePolling();
  }

  private selectLXSource(apiId: string): void {
    const next: string = this.activeSource === apiId ? '' : apiId;
    AppStorage.setOrCreate('lxActiveSource', next);
    MusicStoreService.getInstance().setActiveSource(next);
    this.activeSource = next;
    this.engineReady = false;
    this.startEnginePolling();
  }

  private deleteLXSource(apiId: string): void {
    if (this.activeSource === apiId) {
      AppStorage.setOrCreate('lxActiveSource', '');
      MusicStoreService.getInstance().setActiveSource('');
      this.activeSource = '';
    }
    lxSourceManager.removeApi(apiId);
    this.refresh();
  }

  /** Imports a source script from a local file via the system document picker. */
  private async importLXSource(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const docOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    docOptions.maxSelectNumber = 1;
    try {
      const result: string[] = await docPicker.select(docOptions);
      if (result.length === 0) {
        return;
      }
      const fileUri: string = result[0];
      const file: fs.File = fs.openSync(fileUri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(fileUri);
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf, { offset: 0, length: stat.size });
      fs.closeSync(file);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const script: string = decoder.decodeToString(new Uint8Array(buf));
      try {
        lxSourceManager.importApi(script);
        this.refresh();
        this.toast('源导入成功');
      } catch (_parseErr) {
        this.toast('导入失败: 无效的脚本文件');
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      if (err.code !== undefined && err.code === 1) {
        return;
      }
      this.toast('导入失败');
    }
  }

  /** Imports a source script fetched from a URL (online import). */
  private async importOnline(): Promise<void> {
    const url: string = this.onlineUrl.trim();
    if (url.length === 0 || !/^https?:\/\//.test(url)) {
      this.toast('请输入以 http:// 或 https:// 开头的链接');
      return;
    }
    this.importing = true;
    const httpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: LX_ONLINE_IMPORT_TIMEOUT,
        readTimeout: LX_ONLINE_IMPORT_TIMEOUT,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200 || typeof resp.result !== 'string') {
        this.toast('拉取失败，请检查链接');
        return;
      }
      const script: string = resp.result as string;
      if (script.length > LX_ONLINE_IMPORT_MAX_BYTES) {
        this.toast('脚本过大（超过 9MB）');
        return;
      }
      try {
        lxSourceManager.importApi(script);
        this.refresh();
        this.closeSettingSheet();
        this.onlineUrl = '';
        this.toast('源导入成功');
      } catch (_parseErr) {
        this.toast('导入失败: 无效的脚本文件');
      }
    } catch (_err) {
      this.toast('拉取失败，请检查网络');
    } finally {
      httpRequest.destroy();
      this.importing = false;
    }
  }

  private selectQuality(q: string): void {
    this.playQuality = q;
    AppStorage.setOrCreate('lxPlayQuality', q);
    MusicStoreService.getInstance().setPlayQuality(q);
  }

  private selectColorMode(mode: number): void {
    this.colorMode = mode;
    MusicStoreService.getInstance().setColorMode(mode);
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (ctx === undefined) {
      return;
    }
    if (mode === 0) {
      ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } else if (mode === 1) {
      ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } else {
      ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    }
  }

  private selectSaveLocation(download: boolean): void {
    this.saveToDownloadDir = download;
    MusicStoreService.getInstance().setDownloadSaveMode(download ? 'download' : 'ask');
  }

  @Builder
  private OnlineImportSheet() {
    Column({ space: 16 }) {
      Text($r('app.string.setting_online_import_title'))
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      TextInput({ text: this.onlineUrl, placeholder: $r('app.string.setting_online_import_placeholder') })
        .width('100%')
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level6'))
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.onlineUrl = value;
        })

      Row({ space: 12 }) {
        Button($r('app.string.setting_online_import_cancel'))
          .layoutWeight(1)
          .height(44)
          .fontSize($r('sys.float.Body_L'))
          .backgroundColor($r('app.color.background_secondary'))
          .onClick(() => {
            this.closeSettingSheet();
          })
        Button(this.importing ? $r('app.string.setting_online_import_loading') : $r('app.string.setting_online_import_confirm'))
          .layoutWeight(1)
          .height(44)
          .fontSize($r('sys.float.Body_L'))
          .backgroundColor(this.themeState.color)
          .enabled(!this.importing)
          .onClick(() => {
            void this.importOnline();
          })
      }
      .width('100%')
    }
    .padding({ left: 20, right: 20, top: 24, bottom: 24 })
  }

  /** 平台账号管理弹窗：账号管理。 */
  @Builder
  private AccountSheetBuilder() {
    Column() {
      AccountManageSheet({
        onClose: (): void => {
          this.closeSettingSheet();
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  /** 平台音乐弹窗。 */
  @Builder
  private PlatformMusicSheetBuilder() {
    Column() {
      PlatformMusicPage({
        onClose: (): void => {
          this.closeSettingSheet();
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  /** Cached title bar options so scrolling rebuilds do not recreate material params. */
  private cachedTitleBarOptions: HdsNavigationTitleBarOptions | undefined = undefined;

  /** 光感等级变化时丢弃标题栏缓存，使设置页自身标题栏的沉浸材质实时跟随设置变化。 */
  @Monitor('ambientLevel')
  onAmbientLevelChanged(): void {
    this.cachedTitleBarOptions = undefined;
  }

  /** HDS title bar with system material and gradient blur. */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    if (this.cachedTitleBarOptions !== undefined) {
      return this.cachedTitleBarOptions;
    }
    this.cachedTitleBarOptions = {
      avoidLayoutSafeArea: true,
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            }
          }
        },
        systemMaterialEffect: buildTitleMaterial(this.ambientLevel)
      },
      content: {
        title: {
          mainTitle: $r('app.string.setting_title'),
          mainTitleSize: TitleSize.TITLE_ML
        }
      }
    };
    return this.cachedTitleBarOptions;
  }

  @Builder
  private CardTitle(title: Resource | string) {
    Text(title)
      .fontSize($r('sys.float.Subtitle_L'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
      .margin({ bottom: 4 })
  }

  @Builder
  private SubTitle(title: Resource | string) {
    Text(title)
      .fontSize($r('sys.float.Body_S'))
      .fontColor($r('sys.color.font_tertiary'))
      .width('100%')
      .margin({ top: 8, bottom: 4 })
  }

  @Builder
  private CapsuleSelector(labels: string[], selectedIndex: number, onSelect: (index: number) => void) {
    CapsuleSegmentedSelector({
      labels: labels,
      selectedIndex: selectedIndex,
      accentColor: this.themeState.color,
      onSelect: onSelect
    })
  }

  @Builder
  private ColorDotRow() {
    Scroll() {
      Row({ space: 12 }) {
        Stack() {
          if (this.customColor.length > 0 && /^#[0-9a-fA-F]{6}$/.test(this.customColor) &&
            this.themeState.color.toLowerCase() === this.customColor.toLowerCase()) {
            Row() {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(12)
                .fontColor([$r('sys.color.font_on_primary')])
            }
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor(this.customColor)
            .justifyContent(FlexAlign.Center)
            .border({ width: 2, color: $r('sys.color.font_primary') })
          } else {
            Row() {
              SymbolGlyph($r('sys.symbol.plus'))
                .fontSize(14)
                .fontColor([$r('sys.color.font_primary')])
            }
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor($r('app.color.card_background'))
            .justifyContent(FlexAlign.Center)
            .border({ width: 2, color: $r('sys.color.font_tertiary') })
          }
        }
        .width(32)
        .height(32)
        .onClick(() => {
          this.openSettingSheet(1);
        })

        ForEach(this.presetColors, (color: string) => {
          Row() {
            if (this.themeState.color.toLowerCase() === color.toLowerCase()) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(14)
                .fontColor([$r('sys.color.font_on_primary')])
            }
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor(color)
          .justifyContent(FlexAlign.Center)
          .border({ width: 2, color: this.themeState.color.toLowerCase() === color.toLowerCase() ?
            $r('sys.color.font_primary') : Color.Transparent })
          .onClick(() => {
            this.applyThemeColor(color);
          })
        }, (color: string) => color)
      }
      .height(40)
      .padding({ left: 2, right: 2 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .margin({ top: 8 })
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
  }

  @Builder
  private CustomColorSheet() {
    CustomColorSheetContent({
      customColor: this.customColor,
      accentColor: this.themeState.color,
      presetColors: this.presetColors,
      onColorSelected: (color: string): void => { this.customColor = color; },
      onTextChange: (value: string): void => { this.customColor = value; },
      onApply: (): void => { this.applyCustomColor(); },
      onCancel: (): void => { this.closeSettingSheet(); }
    })
  }

  /** 统一底部弹窗：按 activeSettingSheet 渲染对应分组内容。 */
  @Builder
  private SettingSheetBuilder() {
    if (this.activeSettingSheet === 0) {
      this.OnlineImportSheet()
    } else if (this.activeSettingSheet === 1) {
      this.CustomColorSheet()
    } else if (this.activeSettingSheet === 2) {
      this.AccountSheetBuilder()
    } else if (this.activeSettingSheet === 3) {
      this.PlatformMusicSheetBuilder()
    } else if (this.activeSettingSheet === 4) {
      this.PlaybackSheet()
    } else if (this.activeSettingSheet === 5) {
      this.SourceManagerSheet()
    } else if (this.activeSettingSheet === 6) {
      this.DownloadSheet()
    } else if (this.activeSettingSheet === 7) {
      this.ThemeSheet()
    } else if (this.activeSettingSheet === 8) {
      this.OtherSheet()
    } else if (this.activeSettingSheet === 9) {
      this.AboutSheet()
    } else if (this.activeSettingSheet === 10) {
      this.DownloadManagerSheet()
    }
  }

  /** 下载管理弹窗：任务队列与进度。 */
  @Builder
  private DownloadManagerSheet() {
    Column() {
      DownloadManagerSection()
    }
    .width('100%')
    .height('100%')
  }

  /** 播放设置弹窗：音质+混音 / 其余，拆为两张卡片。 */
  @Builder
  private PlaybackSheet() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          this.SubTitle($r('app.string.setting_sub_quality'))
          this.CapsuleSelector(this.qualityOptions, this.qualityOptions.indexOf(this.playQuality),
            (index: number) => {
              this.selectQuality(this.qualityOptions[index]);
            })

          this.SubTitle($r('app.string.setting_sub_audio_mix'))
          this.CapsuleSelector(this.onOffOptions, this.audioMix ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.audioMix = isOn;
              MusicStoreService.getInstance().setAudioMix(isOn);
              MediaService.getInstance().applyAudioSession(isOn);
            })

          this.SubTitle('播放失败自动跨音源脚本')
          this.CapsuleSelector(this.onOffOptions, this.crossScriptFallback ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.crossScriptFallback = isOn;
              MusicStoreService.getInstance().setCrossScriptFallback(isOn);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))

        Column() {
          this.SubTitle($r('app.string.setting_sub_mini_lyric'))
          this.CapsuleSelector(this.onOffOptions, this.showMiniLyric ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.showMiniLyric = isOn;
              MusicStoreService.getInstance().setShowMiniLyric(isOn);
              const state = AppStorageV2.connect(ShowMiniLyricState, AppStorageKeys.SHOW_MINI_LYRIC_STATE,
                () => new ShowMiniLyricState());
              if (state !== undefined) {
                state.enabled = isOn;
              }
            })

          this.SubTitle($r('app.string.setting_sub_playback_flow_light'))
          this.CapsuleSelector(this.onOffOptions, this.playbackFlowLight ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.playbackFlowLight = isOn;
              MusicStoreService.getInstance().setPlaybackFlowLight(isOn);
              const state = AppStorageV2.connect(PlaybackFlowLightState,
                AppStorageKeys.PLAYBACK_FLOW_LIGHT_STATE, () => new PlaybackFlowLightState());
              if (state !== undefined) {
                state.enabled = isOn;
              }
            })

          this.SubTitle($r('app.string.setting_sub_lyric_blur'))
          this.CapsuleSelector(this.onOffOptions, this.lyricBlurEnabled ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.lyricBlurEnabled = isOn;
              MusicStoreService.getInstance().setLyricBlurEnabled(isOn);
              const state = AppStorageV2.connect(LyricBlurState, AppStorageKeys.LYRIC_BLUR_STATE,
                () => new LyricBlurState());
              if (state !== undefined) {
                state.enabled = isOn;
              }
            })

          this.SubTitle($r('app.string.setting_sub_lyric_font_size'))
          Slider({
            value: this.lyricFontSize,
            min: 18,
            max: 44,
            step: 1,
            style: SliderStyle.InSet
          })
            .width('100%')
            .selectedColor(this.themeState.color)
            .showSteps(false)
            .showTips(true)
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click) {
                this.lyricFontSize = value;
                MusicStoreService.getInstance().setLyricFontSize(value);
                const state = AppStorageV2.connect(LyricFontSizeState, AppStorageKeys.LYRIC_FONT_SIZE_STATE,
                  () => new LyricFontSizeState());
                if (state !== undefined) {
                  state.size = value;
                }
              }
            })

          this.SubTitle($r('app.string.setting_sub_keep_screen_on'))
          this.CapsuleSelector(this.onOffOptions, this.keepScreenOn ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.keepScreenOn = isOn;
              MusicStoreService.getInstance().setKeepScreenOn(isOn);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  /** 下载设置弹窗：命名格式 / 质量标签 / 保存位置。 */
  @Builder
  private DownloadSheet() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          this.SubTitle($r('app.string.setting_sub_name_format'))
          this.CapsuleSelector(this.nameFormatOptions,
            this.nameFormatValues.indexOf(this.downloadNameFormat),
            (index: number) => {
              this.downloadNameFormat = this.nameFormatValues[index];
              MusicStoreService.getInstance().setDownloadNameFormat(this.downloadNameFormat);
            })

          this.SubTitle($r('app.string.setting_sub_quality_tag'))
          this.CapsuleSelector(this.onOffOptions, this.downloadQualityTag ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.downloadQualityTag = isOn;
              MusicStoreService.getInstance().setDownloadQualityTag(isOn);
            })

          this.SubTitle($r('app.string.setting_sub_save_location'))
          this.CapsuleSelector(this.saveLocationOptions,
            this.saveToDownloadDir ? 1 : 0,
            (index: number) => {
              this.selectSaveLocation(index === 1);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  /** 主题设置弹窗：主题色 / 日夜模式 / 光感，拆为两张卡片。 */
  @Builder
  private ThemeSheet() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          this.SubTitle($r('app.string.setting_sub_theme_color'))
          this.ColorDotRow()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))

        Column() {
          this.SubTitle($r('app.string.setting_sub_color_mode'))
          this.CapsuleSelector(this.colorModeOptions, this.colorMode,
            (index: number) => {
              this.selectColorMode(index);
            })

          this.SubTitle($r('app.string.setting_sub_ambient'))
          this.CapsuleSelector(this.ambientOptions, this.ambientLevel,
            (index: number) => {
              this.ambientLevel = index;
              MusicStoreService.getInstance().setAmbientLevel(index);
              const ambient = AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE,
                () => new AmbientState());
              if (ambient !== undefined) {
                ambient.level = index;
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  /** 其它设置弹窗：添加位置 / 首页来源+登录推荐，拆为两张卡片。 */
  @Builder
  private OtherSheet() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          this.SubTitle($r('app.string.setting_sub_add_position'))
          this.CapsuleSelector(this.addPositionOptions,
            this.addPositionValues.indexOf(this.playlistAddPosition),
            (index: number) => {
              this.playlistAddPosition = this.addPositionValues[index];
              MusicStoreService.getInstance().setPlaylistAddPosition(this.playlistAddPosition);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))

        Column() {
          this.SubTitle($r('app.string.setting_sub_home_source'))
          this.CapsuleSelector(this.homeSourceOptions,
            this.homeSourceValues.indexOf(this.homeSource),
            (index: number) => {
              this.homeSource = this.homeSourceValues[index];
              MusicStoreService.getInstance().setHomeSource(this.homeSource);
              const state = AppStorageV2.connect(HomeSourceState, AppStorageKeys.HOME_SOURCE_STATE,
                () => new HomeSourceState());
              if (state !== undefined) {
                state.source = this.homeSource;
              }
            })

          this.SubTitle($r('app.string.setting_sub_use_account_rec'))
          this.CapsuleSelector(this.onOffOptions, this.useAccountRec ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.useAccountRec = isOn;
              MusicStoreService.getInstance().setUseAccountRec(isOn);
              const state = AppStorageV2.connect(UseAccountRecState, AppStorageKeys.USE_ACCOUNT_REC_STATE,
                () => new UseAccountRecState());
              if (state !== undefined) {
                state.enabled = isOn;
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  /** 关于弹窗：应用信息 / 捐赠 / QQ 群 / 日志。 */
  @Builder
  private AboutSheet() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          this.CardTitle($r('app.string.mine_about_title'))

          Row() {
            Text($r('app.string.mine_about_app_name'))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Text($r('app.string.app_name'))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .height(36)
          Row() {
            Text($r('app.string.mine_about_version'))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Text($r('app.string.mine_version'))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .height(36)
          Row() {
            Text($r('app.string.mine_about_bundle'))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Text($r('app.string.mine_bundle_name'))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .height(36)
          Row() {
            Text($r('app.string.mine_about_qq_group'))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Text($r('app.string.mine_qq_group'))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .height(36)
          .onClick(() => {
            this.copyQqGroup();
          })

          Button($r('app.string.mine_donate'))
            .width('100%')
            .height(40)
            .fontSize($r('sys.float.Body_M'))
            .borderRadius($r('sys.float.corner_radius_level6'))
            .backgroundColor(this.themeState.color)
            .fontColor($r('sys.color.font_on_primary'))
            .margin({ top: 6 })
            .onClick(() => {
              this.openDonate();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))

        Column() {
          Row() {
            Text($r('app.string.setting_log_title'))
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Text($r('app.string.setting_log_copy'))
              .fontSize($r('sys.float.Caption_L'))
              .fontColor($r('sys.color.font_tertiary'))
              .onClick(() => {
                this.copyPlayLog();
              })
            Text($r('app.string.setting_log_refresh'))
              .fontSize($r('sys.float.Caption_L'))
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ left: 12 })
              .onClick(() => {
                this.refresh();
              })
          }
          .width('100%')

          if (this.lastError.length > 0) {
            Text($r('app.string.setting_last_error_title'))
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_primary'))
              .width('100%')
              .alignSelf(ItemAlign.Start)
            Text(this.lastError)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .width('100%')
              .maxLines(4)
              .alignSelf(ItemAlign.Start)
          }

          if (this.playLog.length > 0) {
            Text(this.playLog.length > 6000 ? this.playLog.slice(-6000) : this.playLog)
              .fontSize($r('sys.float.Caption_S'))
              .fontFamily('monospace')
              .fontColor($r('sys.color.font_primary'))
              .width('100%')
              .padding(8)
              .borderRadius($r('sys.float.corner_radius_level4'))
              .backgroundColor($r('app.color.background_secondary'))
          } else {
            Text($r('app.string.setting_log_empty'))
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
              .width('100%')
              .padding({ top: 8, bottom: 8 })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 24, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  /** 音源管理弹窗：源列表 + 导入按钮。 */
  @Builder
  private SourceManagerSheet() {
    Column({ space: 12 }) {
      Text($r('app.string.setting_group_source'))
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      if (this.lxApiList.length === 0) {
        Text($r('app.string.setting_lx_empty'))
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
      }

      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.lxApiList, (api: LXUserApiInfo) => {
            Row({ space: 8 }) {
              Radio({ value: api.id, group: 'lxSource', indicatorType: RadioIndicatorType.TICK })
                .width(20)
                .height(20)
                .checked(this.activeSource === api.id)
                .radioStyle({
                  checkedBackgroundColor: this.themeState.color,
                  indicatorColor: $r('sys.color.font_on_primary')
                })
                .onClick(() => {
                  this.selectLXSource(api.id);
                })
              Column({ space: 2 }) {
                Text(api.name)
                  .fontSize($r('sys.float.Body_L'))
                  .fontColor($r('sys.color.font_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if ((api.author ?? '').length > 0 || (api.version ?? '').length > 0) {
                  Text(((api.author ?? '').length > 0 ? api.author : '') +
                    ((api.version ?? '').length > 0 ? ' v' + api.version : ''))
                    .fontSize($r('sys.float.Caption_S'))
                    .fontColor($r('sys.color.font_tertiary'))
                    .maxLines(1)
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .onClick(() => {
                this.selectLXSource(api.id);
              })

              if (this.activeSource === api.id && this.engineReady) {
                Text($r('app.string.setting_lx_ready'))
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor(this.themeState.color)
              }

              SymbolGlyph($r('sys.symbol.trash'))
                .fontSize(20)
                .fontColor([$r('sys.color.font_tertiary')])
                .onClick(() => {
                  this.deleteLXSource(api.id);
                })
            }
            .width('100%')
            .padding(10)
            .borderRadius($r('sys.float.corner_radius_level6'))
            .backgroundColor($r('app.color.card_background'))
          }, (api: LXUserApiInfo) => api.id)

          Row({ space: 10 }) {
            Button($r('app.string.setting_lx_import_file'))
              .layoutWeight(1)
              .height(42)
              .fontSize($r('sys.float.Body_M'))
              .backgroundColor(this.themeState.color)
              .fontColor($r('sys.color.font_on_primary'))
              .onClick(() => {
                void this.importLXSource();
              })
            Button($r('app.string.setting_lx_import_online'))
              .layoutWeight(1)
              .height(42)
              .fontSize($r('sys.float.Body_M'))
              .backgroundColor(this.themeState.color)
              .fontColor($r('sys.color.font_on_primary'))
              .onClick(() => {
                this.openSettingSheet(0);
              })
          }
          .width('100%')
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 24, bottom: 24 })
  }

  private applyCustomColor(): void {
    this.applyThemeColor(this.customColor.trim());
    this.closeSettingSheet();
  }

  @Builder
  private GroupDivider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.comp_divider'))
      .margin({ left: 16, right: 12 })
  }

  @Builder
  private SettingsNavBarContent() {
    Scroll(this.pageScroller) {
      Column({ space: 12 }) {
        Search({ value: this.searchKeyword, placeholder: $r('app.string.setting_search_placeholder') })
          .id('setting_search_input')
          .width('100%')
          .height(40)
          .borderWidth(1)
          .borderColor($r('app.color.comp_background_list_card'))
          .borderRadius(24)
          .backgroundColor($r('app.color.comp_background_list_card'))
          .onChange((value: string) => {
            this.searchKeyword = value;
          })
        this.LoginAccountCard()
        this.SourceEntry()
        this.PlaybackDownloadEntry()
        this.ThemeEntry()
        this.OtherAboutEntry()
        Blank()
      }
      .width('100%')
      .padding({
        top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP,
        left: new BreakpointType(12, 16, 24, 24).getValue(this.breakpointEnv.widthBreakpoint),
        right: new BreakpointType(12, 16, 24, 24).getValue(this.breakpointEnv.widthBreakpoint),
        bottom: 72
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
    // 滚动联动双层底栏：上滑收起、下滑展开（与首页/歌单/我的一致）
    .onScrollFrameBegin((offset: number): OnScrollFrameBeginHandlerResult => {
      if (BarScrollHelper.isEnabled()) {
        BarScrollHelper.notifyScrollDelta(this.getUIContext(), this.appState, offset,
          this.breakpointEnv.widthBreakpoint as number);
      }
      return { offsetRemain: offset };
    })
  }

  build() {
    HdsNavDestination() {
      if (this.isWideSettingLayout()) {
        Row() {
          Column() {
            this.SettingsNavBarContent()
          }
          .width(this.navBarWidthValue())
          .height('100%')

          SettingsDetailPage({
            embedded: true,
            sheetIndex: this.selectedIndex >= 0 ? this.selectedIndex : 4
          })
          .layoutWeight(1)
          .height('100%')
        }
        .width('100%')
        .height('100%')
      } else {
        this.SettingsNavBarContent()
      }
    }
    .hideTitleBar(false)
    .hideBackButton(true)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    .backgroundColor($r('app.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .bindSheet(this.showSettingSheet, this.SettingSheetBuilder(), {
      height: this.activeSettingSheet === 0 ? 280 :
        (this.activeSettingSheet === 1 ? 340 :
          (this.activeSettingSheet === 2 ? 620 :
            (this.activeSettingSheet === 3 ? 640 :
              (this.activeSettingSheet === 4 ? 620 :
                (this.activeSettingSheet === 5 ? 480 :
                  (this.activeSettingSheet === 6 ? 360 :
                    (this.activeSettingSheet === 7 ? 520 :
                      (this.activeSettingSheet === 8 ? 400 :
                    (this.activeSettingSheet === 10 ? 560 : 480))))))))),
      dragBar: true,
      showClose: false,
      backgroundColor: $r('app.color.background_secondary'),
      onWillDismiss: (action: DismissSheetAction) => {
        this.onSheetWillDismiss(action);
      },
      onDisappear: (): void => {
        this.onSheetDisappear();
      }
    })
  }

  @Builder
  private SettingsGroupCard(entries: Array<SettingsEntry>) {
    Column() {
      ForEach(entries, (entry: SettingsEntry, index?: number) => {
        Row({ space: 12 }) {
          Image(entry.icon)
            .width(32)
            .height(32)
          Column({ space: 2 }) {
            Text(entry.title)
              .fontSize(16)
              .fontWeight(this.selectedIndex === entry.id ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.selectedIndex === entry.id ? '#0A59F7' : $r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (entry.subtitle.length > 0) {
              Text(entry.subtitle)
                .fontSize(11)
                .fontColor($r('sys.color.font_tertiary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(20)
            .fontWeight(FontWeight.Regular)
            .height(20)
            .fontColor([$r('sys.color.icon_tertiary')])
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 12 })
        .borderRadius(12)
        .backgroundColor(this.selectedIndex === entry.id ? $r('app.color.background_secondary') : Color.Transparent)
        .onClick(() => {
          entry.onClick();
        })

        if (index !== undefined && index < entries.length - 1) {
          this.GroupDivider()
        }
      }, (entry: SettingsEntry, index?: number) => 'entry-' + index)
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .borderRadius($r('sys.float.corner_radius_level16'))
    .backgroundColor($r('app.color.comp_background_list_card'))
  }

  /** 搜索过滤：返回与当前关键词匹配的设置项（空关键词返回全部）。 */
  private filterEntries(entries: SettingsEntry[]): SettingsEntry[] {
    const kw: string = this.searchKeyword.trim().toLowerCase();
    if (kw.length === 0) {
      return entries;
    }
    const result: SettingsEntry[] = [];
    for (const entry of entries) {
      const text: string = (entry.searchText + ' ' + entry.subtitle).toLowerCase();
      if (text.indexOf(kw) >= 0) {
        result.push(entry);
      }
    }
    return result;
  }

  /** 判断登录音乐/平台音乐整行是否匹配搜索关键词。 */
  private rowVisible(title: string, subtitle: string): boolean {
    const kw: string = this.searchKeyword.trim().toLowerCase();
    if (kw.length === 0) {
      return true;
    }
    return (title + ' ' + subtitle).toLowerCase().indexOf(kw) >= 0;
  }

  @Builder
  private SourceEntry() {
    if (this.filterEntries(this.sourceEntries()).length > 0) {
      this.SettingsGroupCard(this.filterEntries(this.sourceEntries()))
    }
  }

  @Builder
  private PlaybackDownloadEntry() {
    if (this.filterEntries(this.playbackDownloadEntries()).length > 0) {
      this.SettingsGroupCard(this.filterEntries(this.playbackDownloadEntries()))
    }
  }

  @Builder
  private ThemeEntry() {
    if (this.filterEntries(this.themeEntries()).length > 0) {
      this.SettingsGroupCard(this.filterEntries(this.themeEntries()))
    }
  }

  @Builder
  private OtherAboutEntry() {
    if (this.filterEntries(this.otherAboutEntries()).length > 0) {
      this.SettingsGroupCard(this.filterEntries(this.otherAboutEntries()))
    }
  }

  /** 设置数据：音源设置（超级终端图标）。 */
  private sourceEntries(): SettingsEntry[] {
    const source = new SettingsEntry();
    source.icon = $r('app.media.ic_super_device');
    source.title = $r('app.string.setting_group_source');
    source.subtitle = '';
    source.id = 5;
    source.searchText = '音源设置 音源 引擎';
    source.onClick = (): void => {
      this.openSettingSheet(5);
    };
    return [source];
  }

  /** 设置数据：播放设置（声音和震动图标）+ 下载设置。 */
  private playbackDownloadEntries(): SettingsEntry[] {
    const playback = new SettingsEntry();
    playback.icon = $r('app.media.ic_voice');
    playback.title = $r('app.string.setting_group_playback');
    playback.subtitle = '';
    playback.id = 4;
    playback.searchText = '播放设置 播放 音质 歌词 声音';
    playback.onClick = (): void => {
      this.openSettingSheet(4);
    };
    const download = new SettingsEntry();
    download.icon = $r('app.media.ic_store');
    download.title = $r('app.string.setting_group_download');
    download.subtitle = '';
    download.id = 6;
    download.searchText = '下载设置 下载 保存 命名';
    download.onClick = (): void => {
      this.openSettingSheet(6);
    };
    return [playback, download];
  }

  /** 设置数据：主题设置（桌面和个性化图标）。 */
  private themeEntries(): SettingsEntry[] {
    const theme = new SettingsEntry();
    theme.icon = $r('app.media.ic_desktop');
    theme.title = $r('app.string.setting_group_theme');
    theme.subtitle = '';
    theme.id = 7;
    theme.searchText = '主题设置 主题 颜色 日夜';
    theme.onClick = (): void => {
      this.openSettingSheet(7);
    };
    return [theme];
  }

  /** 设置数据：其它设置（辅助功能图标）+ 关于（系统图标）。 */
  private otherAboutEntries(): SettingsEntry[] {
    const other = new SettingsEntry();
    other.icon = $r('app.media.ic_accessibility');
    other.title = $r('app.string.setting_group_other');
    other.subtitle = '';
    other.id = 8;
    other.searchText = '其它设置 其他 歌单 首页 推荐';
    other.onClick = (): void => {
      this.openSettingSheet(8);
    };
    const about = new SettingsEntry();
    about.icon = $r('app.media.ic_system');
    about.title = $r('app.string.mine_about_title');
    about.subtitle = '';
    about.id = 9;
    about.searchText = '关于 版本 捐赠 日志 群';
    about.onClick = (): void => {
      this.openSettingSheet(9);
    };
    return [other, about];
  }

  /** 登录音乐 大卡片（按顶部搜索词过滤行）。 */
  @Builder
  private LoginAccountCard() {
    if (this.rowVisible('登录音乐', '网易云 / QQ / 酷狗账号，扫码或 Cookie 登录')) {
      Column({ space: 8 }) {
      if (this.rowVisible('登录音乐', '网易云 / QQ / 酷狗账号，扫码或 Cookie 登录')) {
        Row({ space: 12 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
              .fontSize(64)
              .fontWeight(FontWeight.Regular)
              .height(64)
              .fontColor([$r('sys.color.font_tertiary')])
          }
          .width(64)
          .height(64)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Column({ space: 2 }) {
            Text('登录音乐')
              .fontSize(20)
              .fontWeight(this.selectedIndex === 2 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.selectedIndex === 2 ? '#0A59F7' : $r('sys.color.font_primary'))
            Text('网易云 / QQ / 酷狗账号，扫码或 Cookie 登录')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(20)
            .fontWeight(FontWeight.Regular)
            .height(20)
            .fontColor([$r('sys.color.icon_tertiary')])
        }
        .width('100%')
        .height(80)
        .borderRadius(16)
        .padding({ left: 8, right: 12 })
        .backgroundColor(this.selectedIndex === 2 ? $r('app.color.background_secondary') : Color.Transparent)
        .onClick(() => {
          this.openSettingSheet(2);
        })
      }
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .borderRadius($r('sys.float.corner_radius_level16'))
    .backgroundColor($r('app.color.comp_background_list_card'))
      }
  }
}

