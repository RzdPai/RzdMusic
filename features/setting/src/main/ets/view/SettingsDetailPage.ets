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
import { AmbientState, AppStorageKeys, RouterUrlConstants, BreakpointType, HomeSourceState, CoverRadiusState, LyricBlurState, LyricCenterState, LyricFontSizeState, LyricFpsState, MusicStoreService, PlaybackFlowLightState, ShowMiniLyricState, ThemeState, TitleBarConstants, UseAccountRecState, buildTitleMaterial, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';
import { LXUserApiInfo, lxSourceManager, MediaService } from 'player';
import { SyncSettingsPanel } from 'sync';
import { AccountManageSheet } from '../account/AccountManageSheet';
import { PlatformMusicPage } from '../account/PlatformMusicPage';
import { DownloadManagerSection } from './DownloadManagerSection';

import { CustomColorSheetContent } from './CustomColorSheetContent';
import { CapsuleSegmentedSelector } from './CapsuleSegmentedSelector';
import { LengthMetrics } from '@kit.ArkUI';
const LX_ONLINE_IMPORT_MAX_BYTES: number = 9 * 1024 * 1024;
const LX_ONLINE_IMPORT_TIMEOUT: number = 15000;

export class SettingsDetailRouteParam {
  index: number = 4;
}

@ComponentV2
export struct SettingsDetailPage {
  @Param sheetIndex: number = 4;
  @Param embedded: boolean = false;
  @Local pathStack: NavPathStack = new NavPathStack();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local lxApiList: LXUserApiInfo[] = [];
  @Local activeSource: string = '';
  @Local engineReady: boolean = false;
  @Local engineSources: string = '{}';
  @Local lastError: string = '';
  @Local playLog: string = '';
  @Local onlineUrl: string = '';
  @Local importing: boolean = false;
  @Local playQuality: string = '';
  @Local extendedQuality: string = '';
  @Local extendedEnabled: boolean = false;
  @Local ambientLevel: number = 0;
  @Local customColor: string = '';
  @Local colorMode: number = 2;
  @Local saveToDownloadDir: boolean = false;
  @Local downloadNameFormat: string = 'title';
  @Local playlistAddPosition: string = 'bottom';
  @Local showMiniLyric: boolean = false;
  /** 播放页是否启用流光背景（颜色随封面动态取色）。 */
  @Local playbackFlowLight: boolean = false;
  @Local audioMix: boolean = false;
  @Local lyricBlurEnabled: boolean = true;
  @Local lyricFontSize: number = 28;
  @Local lyricFps: number = 60;
  @Local coverRadius: number = 8;
  @Local downloadLrc: boolean = true;
  @Local coverRadiusOptions: string[] = ['直角', '小', '中', '大', '超大'];
  @Local coverRadiusValues: number[] = [0, 8, 16, 24, 32];
  @Local lyricCenter: boolean = false;
  @Local lyricFpsOptions: string[] = ['60', '90', '120', '144'];
  @Local lyricFpsValues: number[] = [60, 90, 120, 144];
  @Local keepScreenOn: boolean = false;
  @Local downloadQualityTag: boolean = false;
  @Local homeSource: string = 'qq';
  @Local useAccountRec: boolean = false;
  private readonly qualityRowLabels: string[][] = [
    ['128K', '320K', 'FLAC', '24Bit'],
    ['Hi-Res', '全景声', '全景声+', '母带']
  ];
  private readonly qualityRowValues: string[][] = [
    ['128k', '320k', 'flac', 'flac24bit'],
    ['hires', 'atmos', 'atmos_plus', 'master']
  ];
  private readonly presetColors: string[] = [
    '#E60012', '#FF6B35', '#FFC107', '#31C27C',
    '#4A90D9', '#7C4DFF', '#FF4081', '#00BCD4', '#607D8B'
  ];
  private readonly ambientOptions: string[] = ['跟随系统', '弱', '均衡', '强'];
  private readonly nameFormatOptions: string[] = ['歌曲名', '艺术家-标题', '标题-艺术家'];
  private readonly nameFormatValues: string[] = ['title', 'artist_title', 'title_artist'];
  private readonly addPositionOptions: string[] = ['顶部', '底部'];
  private readonly addPositionValues: string[] = ['top', 'bottom'];
  private readonly homeSourceOptions: string[] = ['QQ', '酷狗', '网易'];
  private readonly homeSourceValues: string[] = ['qq', 'kg', 'wy'];
  private readonly onOffOptions: string[] = ['开', '关'];
  private readonly saveLocationOptions: string[] = ['手动选择', 'Download目录'];
  private readonly colorModeOptions: string[] = ['日间', '夜间', '跟随系统'];
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.refresh();
    this.startEnginePolling();
  }

  private detailTitle(): string {
    switch (this.sheetIndex) {
      case 0: return '在线导入';
      case 1: return '自定义主题色';
      case 2: return '平台账号';
      case 3: return '平台音乐';
      case 4: return '播放设置';
      case 5: return '音源管理';
      case 6: return '下载设置';
      case 10: return '下载管理';
      case 7: return '主题外观';
      case 8: return '其它设置';
      case 9: return '关于';
      // 11 = 同步设置（洛雪同步；入口在「其它设置」里）
      case 11: return '同步设置';
      default: return '设置';
    }
  }

  private cachedTitleBar: HdsNavigationTitleBarOptions | undefined = undefined;

  private getDetailTitleBar(): HdsNavigationTitleBarOptions {
    return {
      padding: { start: LengthMetrics.vp(16), end: LengthMetrics.vp(16) },
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: Color.Transparent
          },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            backIconStyle: { iconColor: $r('sys.color.font_primary'), backgroundColor: '#1AFFFFFF' }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            backIconStyle: { iconColor: $r('sys.color.font_primary'), backgroundColor: '#1AFFFFFF' }
          }
        },
        systemMaterialEffect: buildTitleMaterial(this.ambientLevel)
      },
      content: {
        title: { mainTitle: this.detailTitle(), mainTitleSize: TitleSize.TITLE_ML },
        backIcon: {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true,
          action: (): void => {
            this.pathStack.pop();
          }
        }
      }
    };
  }





















  /** Applies a theme color (hex) and persists it. */
  private applyThemeColor(color: string): void {
    if (!/^#[0-9a-fA-F]{6}$/.test(color)) {
      return;
    }
    this.themeState.color = color;
    MusicStoreService.getInstance().setThemeColor(color);

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
    this.playQuality = MusicStoreService.getInstance().getPlayQuality();
    this.extendedQuality = MusicStoreService.getInstance().getPlayExtendedQuality();
    this.extendedEnabled = MusicStoreService.getInstance().getPlayExtendedEnabled();
    AppStorage.setOrCreate('lxPlayQuality', this.playQuality);
    AppStorage.setOrCreate('lxExtendedQuality', this.extendedQuality);
    AppStorage.setOrCreate('lxExtendedEnabled', this.extendedEnabled);
    this.ambientLevel = MusicStoreService.getInstance().getAmbientLevel();
    this.showMiniLyric = MusicStoreService.getInstance().getShowMiniLyric();
    this.playbackFlowLight = MusicStoreService.getInstance().getPlaybackFlowLight();
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
    this.coverRadius = MusicStoreService.getInstance().getCoverCornerRadius();
    this.downloadLrc = MusicStoreService.getInstance().getDownloadLrc();
    AppStorage.setOrCreate('lxCoverRadius', this.coverRadius);
    this.lyricFps = MusicStoreService.getInstance().getLyricFps();
    this.lyricCenter = MusicStoreService.getInstance().getLyricCenterEnabled();
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

  /** 面板内跳转到另一个设置子页。 */
  private pushSubSheet(index: number): void {
    const param = new SettingsDetailRouteParam();
    param.index = index;
    this.pathStack.pushPathByName(RouterUrlConstants.SETTINGS_DETAIL, param);
  }

  /**
   * @returns 子面板顶部要避让的高度：内嵌（宽屏右栏）时为 0，二级页时让出状态栏 + 标题栏。
   */
  private contentTopOffset(): number {
    return this.embedded ? 0 : getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP;
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

  private isDarkTheme(): boolean {
    const mode: number = this.colorMode;
    if (mode === 0) {
      return false;
    }
    if (mode === 1) {
      return true;
    }
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined || ctx.config === undefined) {
      return false;
    }
    return ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
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
        this.pathStack.pop();
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

  private selectExtendedQuality(q: string): void {
    this.extendedQuality = q;
    AppStorage.setOrCreate('lxExtendedQuality', q);
    MusicStoreService.getInstance().setPlayExtendedQuality(q);
  }

  private toggleExtended(on: boolean): void {
    this.extendedEnabled = on;
    AppStorage.setOrCreate('lxExtendedEnabled', on);
    MusicStoreService.getInstance().setPlayExtendedEnabled(on);
    if (!on) {
      // 关闭扩展时，若当前播放音质残留为扩展档，降级到普通最高档，
      // 避免播放链 getQualityChain 继续尝试 hires 及以上音质。
      const q: string = AppStorage.get<string>('lxPlayQuality') ?? '128k';
      if (this.qualityRowValues[1].indexOf(q) >= 0) {
        this.playQuality = 'flac24bit';
        AppStorage.setOrCreate('lxPlayQuality', 'flac24bit');
        MusicStoreService.getInstance().setPlayQuality('flac24bit');
      }
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
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
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
    .width('100%')
    .padding({ left: 20, right: 20, top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP + 8, bottom: 24 })
  }

  /** 平台账号管理弹窗：账号管理。整页导航时内容需避开标题栏（AccountManageSheet 自身仅按弹窗场景留 12vp）。 */
  @Builder
  private AccountSheetBuilder() {
    Column() {
      AccountManageSheet({
        onClose: (): void => {
              }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP + 8 })
  }

  /** 平台音乐弹窗。 */
  @Builder
  private PlatformMusicSheetBuilder() {
    Column() {
      PlatformMusicPage({
        onClose: (): void => {
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
        }
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
          this.pushSubSheet(1);
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
      onCancel: (): void => { this.pathStack.pop(); }
    })
  }


  /** 播放设置弹窗：音质+混音 / 其余，拆为两张卡片。 */
  @Builder
  private PlaybackSheet() {
    Scroll(this.pageScroller) {
      Column({ space: 12 }) {
        Column() {
          this.SubTitle($r('app.string.setting_sub_quality'))
          this.CapsuleSelector(this.qualityRowLabels[0], this.qualityRowValues[0].indexOf(this.playQuality),
            (index: number) => {
              this.selectQuality(this.qualityRowValues[0][index]);
            })
          this.SubTitle('拓展音质')
          this.CapsuleSelector(this.onOffOptions, this.extendedEnabled ? 0 : 1,
            (index: number) => {
              this.toggleExtended(index === 0);
            })
          Column() {
            this.CapsuleSelector(this.qualityRowLabels[1], this.qualityRowValues[1].indexOf(this.extendedQuality),
              (index: number) => {
                this.selectExtendedQuality(this.qualityRowValues[1][index]);
              })
          }
          .width('100%')
          .opacity(this.extendedEnabled ? 1 : 0.35)
          .enabled(this.extendedEnabled)

          this.SubTitle('封面圆角')
          this.CapsuleSelector(this.coverRadiusOptions, this.coverRadiusValues.indexOf(this.coverRadius),
            (index: number) => {
              const radius: number = this.coverRadiusValues[index];
              this.coverRadius = radius;
              MusicStoreService.getInstance().setCoverCornerRadius(radius);
              AppStorage.setOrCreate('lxCoverRadius', radius);
              const state = AppStorageV2.connect(CoverRadiusState, AppStorageKeys.COVER_RADIUS_STATE,
                () => new CoverRadiusState());
              if (state !== undefined) {
                state.radius = radius;
              }
            })

          this.SubTitle($r('app.string.setting_sub_audio_mix'))
          this.CapsuleSelector(this.onOffOptions, this.audioMix ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.audioMix = isOn;
              MusicStoreService.getInstance().setAudioMix(isOn);
              MediaService.getInstance().applyAudioSession(isOn);
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

          // 播放页流光背景：颜色不是写死的，由 PlaybackPage 从封面动态取色
          // （见 features/player 的 PlaybackPage.FlowLightBackground）
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

          this.SubTitle('歌词帧率')
          this.CapsuleSelector(this.lyricFpsOptions, this.lyricFpsValues.indexOf(this.lyricFps),
            (index: number) => {
              const fps: number = this.lyricFpsValues[index];
              this.lyricFps = fps;
              MusicStoreService.getInstance().setLyricFps(fps);
              const state = AppStorageV2.connect(LyricFpsState, AppStorageKeys.LYRIC_FPS_STATE,
                () => new LyricFpsState());
              if (state !== undefined) {
                state.fps = fps;
              }
            })

          this.SubTitle('歌词居中显示')
          this.CapsuleSelector(this.onOffOptions, this.lyricCenter ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.lyricCenter = isOn;
              MusicStoreService.getInstance().setLyricCenterEnabled(isOn);
              const state = AppStorageV2.connect(LyricCenterState, AppStorageKeys.LYRIC_CENTER_STATE,
                () => new LyricCenterState());
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
    .padding({ top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP })
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  /** 下载设置弹窗：命名格式 / 质量标签 / 保存位置。 */
  @Builder
  private DownloadSheet() {
    Scroll(this.pageScroller) {
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

          this.SubTitle('单独下载歌词')
          this.CapsuleSelector(this.onOffOptions, this.downloadLrc ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.downloadLrc = isOn;
              MusicStoreService.getInstance().setDownloadLrc(isOn);
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
    .padding({ top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP })
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  /** 下载管理页：任务队列与进度。 */
  @Builder
  private DownloadManagerSheet() {
    Column() {
      DownloadManagerSection()
    }
    .width('100%')
    .height('100%')
    .padding({ top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP })
  }

  /** 主题设置弹窗：主题色 / 日夜模式 / 光感，拆为两张卡片。 */
  @Builder
  private ThemeSheet() {
    Scroll(this.pageScroller) {
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
    .padding({ top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP })
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  /** 其它设置弹窗：添加位置 / 首页来源+登录推荐 / 同步设置入口，拆为三张卡片。 */
  @Builder
  private OtherSheet() {    Scroll(this.pageScroller) {
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

        // 同步设置（洛雪同步协议客户端）入口：按需求放在「其它设置」里。
        // 具体界面由 features/sync 提供（SyncSettingsPanel），这里只负责跳子页。
        Column() {
          Row() {
            Column({ space: 2 }) {
              Text('同步设置')
                .fontSize($r('sys.float.Body_L'))
                .fontColor($r('sys.color.font_primary'))
              Text('与洛雪音乐服务端同步歌单 / 收藏')
                .fontSize($r('sys.float.Caption_M'))
                .fontColor($r('sys.color.font_tertiary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(18)
              .fontColor([$r('sys.color.font_tertiary')])
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .onClick(() => {
            this.pushSubSheet(11);
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 4 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP })
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  /**
   * 同步设置页：洛雪同步协议客户端（服务器地址 / 认证码 / 设备名 / 连接状态 / 不喜欢规则）。
   *
   * 界面由 `features/sync` 的 `SyncSettingsPanel` 提供 —— setting 只做"入口 + 容器"，
   * 同步协议、加密、离线队列都在 sync 模块里，符合三层架构（features 之间通过依赖声明协作）。
   */
  @Builder
  private SyncSettingsSheet() {
    SyncSettingsPanel({
      topOffset: this.contentTopOffset()
    })
  }
  /** 关于弹窗：应用信息 / 捐赠 / QQ 群 / 日志。 */
  @Builder
  private AboutSheet() {    Scroll(this.pageScroller) {
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
    .padding({ top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP })
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  /** 音源管理弹窗：导入按钮 + 源列表。 */
  @Builder
  private SourceManagerSheet() {
    Column({ space: 12 }) {
      if (this.lxApiList.length === 0) {
        Text($r('app.string.setting_lx_empty'))
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
      }

      Scroll(this.pageScroller) {
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
                if (api.author.length > 0 || api.version.length > 0) {
                  Text((api.author.length > 0 ? api.author : '') +
                    (api.version.length > 0 ? ' v' + api.version : ''))
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
                this.pushSubSheet(0);
              })
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .padding({ left: 20, right: 20, top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP + 8, bottom: 24 })
  }

  private applyCustomColor(): void {
    this.applyThemeColor(this.customColor.trim());
  }

  @Builder
  private GroupDivider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.comp_divider'))
      .margin({ left: 16, right: 12 })
  }


  build() {
    if (this.embedded) {
      this.detailBody()
    } else {
      HdsNavDestination() {
        this.detailBody()
      }
      .hideTitleBar(false)
      .titleBar(this.getDetailTitleBar())
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .onReady((context: NavDestinationContext) => {
        this.pathStack = context.pathStack;
      })
      .bindToScrollable([this.pageScroller])
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .systemBarStyle(
        { statusBarContentColor: this.isDarkTheme() ? '#FFFFFF' : '#000000' },
        { statusBarContentColor: this.isDarkTheme() ? '#FFFFFF' : '#000000' })
      .backgroundColor($r('app.color.background_secondary'))
    }
  }

  @Builder
  private detailBody() {
      Column() {
        if (this.sheetIndex === 0) {
          this.OnlineImportSheet()
        } else if (this.sheetIndex === 1) {
          this.CustomColorSheet()
        } else if (this.sheetIndex === 2) {
          this.AccountSheetBuilder()
        } else if (this.sheetIndex === 3) {
          this.PlatformMusicSheetBuilder()
        } else if (this.sheetIndex === 4) {
          this.PlaybackSheet()
        } else if (this.sheetIndex === 5) {
          this.SourceManagerSheet()
        } else if (this.sheetIndex === 6) {
          this.DownloadSheet()
        } else if (this.sheetIndex === 7) {
          this.ThemeSheet()
        } else if (this.sheetIndex === 8) {
          this.OtherSheet()
        } else if (this.sheetIndex === 9) {
          this.AboutSheet()
        } else if (this.sheetIndex === 10) {
          this.DownloadManagerSheet()
        } else if (this.sheetIndex === 11) {
          // 同步设置（洛雪同步协议）：入口在「其它设置」里
          this.SyncSettingsSheet()
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 4, right: 4 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

}

@Builder
export function SettingsDetailPageBuilder(name: string, param: Object) {
  SettingsDetailPage({
    sheetIndex: (param as SettingsDetailRouteParam | undefined)?.index ?? 4
  })
}
