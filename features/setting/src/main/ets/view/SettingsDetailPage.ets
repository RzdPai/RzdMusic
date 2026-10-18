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

import { guardPlayerBack } from 'musicbasic';
import { AppStorageV2, CapsuleSegmentButtonV2, ColorMetrics, SegmentButtonV2Items, uiObserver } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, ConfigurationConstant, Want } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { CoverCacheSettingsCard, AmbientState, AppStorageKeys, RouterUrlConstants, BreakpointType, HomeSourceState, LyricBlurState, LyricCenterState, LyricFontSizeState, LyricFpsState, MusicStoreService, notifyHomeSourceRefresh, PageTopInsetHelper, PlaybackFlowLightState, ShowMiniLyricState, ThemeState, TitleBarConstants, UseAccountRecState, buildTitleMaterial, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';
import { LXUserApiInfo, LXSourcePlatformInfo, lxDeclaredPlatformsOf, lxSourceManager, MediaService } from 'player';
import type { LXApiImportResult } from 'player';
import { SyncSettingsPanel } from 'sync';
import { AccountManageSheet } from '../account/AccountManageSheet';
import { PlatformMusicPage } from '../account/PlatformMusicPage';
import { DownloadManagerSection } from './DownloadManagerSection';
import { importSourceFiles } from '../util/SourceFileImport';

import { CustomColorSheetContent } from './CustomColorSheetContent';
import { CapsuleSegmentedSelector } from './CapsuleSegmentedSelector';
import { LxSourceDeclaredBlock } from './LxSourceTags';
import { LengthMetrics } from '@kit.ArkUI';
const LX_ONLINE_IMPORT_MAX_BYTES: number = 9 * 1024 * 1024;
const LX_ONLINE_IMPORT_TIMEOUT: number = 15000;

/**
 * 各子面板**底部**要留的高度（vp）—— 让最后一行不被二级页底部那条官方浮动播放条压住。
 *
 * 为什么从 160 收到 88（用户 2026-10-11：「音源管理页面上方下方都一大块空白，能不能去掉」）：
 *   160 是"旧壳层自绘胶囊 + 两排底栏"时代按最大占用拍的，滚到底会露出一大段空白。
 *   现在二级页底部只有一条 56vp 的官方浮动栏（`floatingMiniBar()`），离底间距 ≈ 手势条 + 8，
 *   所以 56 + 24(手势条) + 8(余量) = 88 就够；再多就是纯空白。
 */
const SETTINGS_PANEL_BOTTOM_VP: number = 88;

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
  @Local sourceOrderIds: string[] = [];
  @Local activeSource: string = '';
  @Local engineReady: boolean = false;
  @Local engineSources: string = '{}';
  @Local lastError: string = '';
  @Local playLog: string = '';
  @Local onlineUrl: string = '';
  @Local importing: boolean = false;
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  @Local ambientLevel: number = 0;
  @Local customColor: string = '';
  @Local colorMode: number = 2;
  @Local saveToDownloadDir: boolean = false;
  @Local downloadNameFormat: string = 'title';
  @Local playlistAddPosition: string = 'bottom';
  @Local showMiniLyric: boolean = false;
  /** 桌面歌词（系统 AVSession 悬浮窗歌词）开关，默认关（见 MusicStoreService.getDesktopLyric）。 */
  @Local desktopLyric: boolean = false;
  /** 车载蓝牙歌词：推送当前句到蓝牙车机/音箱。 */
  @Local bluetoothLyric: boolean = false;
  /** 系统是否支持桌面歌词：undefined = 还没探测过。 */
  @Local desktopLyricSupport: boolean | undefined = undefined;
  /** 播放页是否启用流光背景（颜色随封面动态取色）。 */
  @Local playbackFlowLight: boolean = false;
  /**
   * 锁屏继续播放（默认 **开**）。
   *
   * ★ 2026-10-18（用户：「现在似乎不能锁屏播放，你在播放设置里加一下，默认开」）：
   *   开 = 播放时申请"音频后台长时任务"（`backgroundModes: ["audioPlayback"]` +
   *   `KEEP_BACKGROUND_RUNNING`），息屏/锁屏/切后台都继续放；关 = 不申请（锁屏就停）。
   *   存储口径见 `MusicStoreService.getLockScreenPlay()`（读不到一律按"开"）。
   */
  @Local lockScreenPlay: boolean = true;
  @Local audioMix: boolean = false;
  @Local lyricBlurEnabled: boolean = true;
  @Local lyricFontSize: number = 28;
  @Local lyricFps: number = 60;
  // ★★★ 2026-10-17（用户：「我们的软件里面有个**自定义封面圆角**也删了吧」）
  //   设置项已整块删除（见 `PlaybackSheet`）。封面圆角现在只有**一个来源**：
  //   无界 `CoverMorph.radiusPlayer = 8`（`PlayerExpandState.COVER_RADIUS_PLAYER_VP`）。
  //   ⚠️ `MusicStoreService.get/setCoverCornerRadius` 与云同步那条键**保留**（历史数据兼容），
  //      但**不再有任何渲染读它** —— 不要再把它接回界面。
  @Local downloadLrc: boolean = true;
  @Local lyricCenter: boolean = false;
  @Local lyricFpsOptions: string[] = ['60', '90', '120', '144'];
  @Local lyricFpsValues: number[] = [60, 90, 120, 144];
  @Local keepScreenOn: boolean = false;
  @Local downloadQualityTag: boolean = false;
  @Local homeSource: string = 'qq';
  @Local useAccountRec: boolean = false;
  /** 仅保存静态选项；选中态由分网 store 唯一真源派生。 */
  private readonly networkQualityModeItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '关' },
    { text: '开' }
  ]);
  private readonly downloadQualityModeItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '关' },
    { text: '开' }
  ]);
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
    this.sourceOrderIds = MusicStoreService.getInstance().getSourceScriptOrder();
    if (this.sourceOrderIds.length === 0) {
      const ids: string[] = [];
      for (let i: number = 0; i < this.lxApiList.length; i++) {
        if (this.lxApiList[i].id.length > 0) { ids.push(this.lxApiList[i].id); }
      }
      this.sourceOrderIds = ids;
    }
    this.activeSource = AppStorage.get<string>('lxActiveSource') ?? '';
    if (this.activeSource.length === 0) {
      this.engineReady = false;
    } else {
      this.engineReady = AppStorage.get<boolean>('lxEngineReady') === true;
    }
    this.engineSources = AppStorage.get<string>('lxEngineSources') ?? '{}';
    this.ambientLevel = MusicStoreService.getInstance().getAmbientLevel();
    this.showMiniLyric = MusicStoreService.getInstance().getShowMiniLyric();
    this.desktopLyric = MusicStoreService.getInstance().getDesktopLyric();
    this.bluetoothLyric = MusicStoreService.getInstance().getBluetoothLyric();
    // 会话是「第一次推歌」时才建的，所以这里主动探一次支持性（否则设置页只能说「未知」）
    void MediaService.getInstance().probeDesktopLyricSupport().then((supported: boolean): void => {
      this.desktopLyricSupport = supported;
    });
    this.playbackFlowLight = MusicStoreService.getInstance().getPlaybackFlowLight();
    // 锁屏继续播放：缺省（没有这条记录）= 开
    this.lockScreenPlay = MusicStoreService.getInstance().getLockScreenPlay();
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
    // ⛔ 2026-10-17：`coverRadius` 设置项已删除（见 `PlaybackSheet`），这里不再读、也不再写
    //   `AppStorage 'lxCoverRadius'`。
    this.downloadLrc = MusicStoreService.getInstance().getDownloadLrc();
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
   * 子面板顶部要避让的高度。
   *
   * ★ 2026-10-11 口径（用户明确两次）：二级页要**延伸进状态栏** ——
   *   内容（列表）往上滚要能一直画到屏幕最顶端，状态栏那一条也归页面。
   *   所以**不能**把状态栏高度加到"内容容器"的 padding 上（那样视口从状态栏下沿起排，
   *   状态栏那一条就成了一段死背景），而应该把"状态栏 + 标题栏"加在**子面板自己**的顶部留白上：
   *   静止时第一项正好落在标题栏下沿，往上滚则整项从标题栏底下穿到状态栏里。
   *
   * @returns 内嵌（宽屏右栏）时只补 HDS 标题栏；二级页时补"状态栏 + HDS 标题栏"。
   */
  private panelTopInset(): number {
    // ⚠️ 二级页不再假设页盒从窗口 y=0 起排：由 `boxTopVp`（页根 `onAreaChange` 实测）换算，
    //    盒顶 0 → 94、盒顶 38 → 56，两种情形内容都落在窗口的 94 那条线上（`PageTopInsetHelper`）。
    return this.embedded ? TitleBarConstants.ROW_HEIGHT_VP :
      PageTopInsetHelper.contentOffsetVp(this.boxTopVp);
  }

  /**
   * 交给**自带滚动容器的子页面**（`PlatformMusicPage` 那种）的顶部偏移。
   *
   * 内嵌（宽屏右栏）时为 0：右栏里没有 HDS 标题栏，也不归它避让状态栏（外层大设置页负责）。
   * 二级页时 = "状态栏 + HDS 标题栏"（理由同 {@link panelTopInset}）。
   *
   * @returns 顶部偏移（vp）。
   */
  private contentTopOffset(): number {
    return this.embedded ? 0 :
      PageTopInsetHelper.contentOffsetVp(this.boxTopVp);
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

  /**
   * 一条音源脚本声明了哪些平台 / 什么音质 / 能做什么。
   *
   * 数据链：脚本 init 上报 `sources` → `LXSourceManager.saveApiSources()` 落进
   * `lx_api_list.json` 的 `apis[].sources` → 这里按音源 id 取出来收敛成标签。
   * 引擎就绪后 `refresh()` 会重读列表，所以「选中一次该音源」之后标签就出现了。
   * 没声明过就是空数组 ⇒ 界面给中性提示，**不猜**。
   */
  private lxPlatformsOf(api: LXUserApiInfo): LXSourcePlatformInfo[] {
    return lxDeclaredPlatformsOf(api);
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
    // ★ 用户 2026-10-11「音源勾选是不是有点问题」：圆点是「当前默认音源」而不是开关 ——
    //   原来点当前默认那一行会把它清成空字符串（`? ' : apiId`）⇒ 一圈圆点全是空心，看着像没选中。
    //   现在点击恒为「设为默认」，不再有「点一下取消默认」这种状态。
    const next: string = apiId;
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
    if (this.sourceOrderIds.indexOf(apiId) >= 0) {
      this.toggleSourceInOrder(apiId);
    }
    lxSourceManager.removeApi(apiId);
    this.refresh();
  }

  /** Imports source scripts from multiple local files, retaining per-file failures. */
  private async importLXSource(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const message: string = await importSourceFiles(context);
      this.refresh();
      if (message.length > 0) {
        this.toast(message);
      }
    } catch (_error) {
      this.toast('选择音源文件失败或已取消');
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
        const imported: LXApiImportResult = lxSourceManager.importApi(script);
        if (!imported.ok) {
          this.toast('导入失败：' + imported.message);
          return;
        }
        this.refresh();
        this.pathStack.pop();
        this.onlineUrl = '';
        this.toast('已导入「' + imported.message + '」');
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
    .padding({ left: 20, right: 20, top: this.panelTopInset() + 8, bottom: SETTINGS_PANEL_BOTTOM_VP })
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
    .padding({ top: this.panelTopInset() + 8 })
  }

  /** 平台音乐弹窗。 */
  @Builder
  private PlatformMusicSheetBuilder() {
    Column() {
      /**
       * ★ 必须把它自己的 `Scroll` 用的 scroller 交出去（用户 2026-10-11：「平台音乐页面没模糊效果」）。
       *
       * 原因：本页标题栏的渐变模糊是"标题栏 ← 滚动容器"的绑定驱动的
       * （根节点 `.bindToScrollable([this.pageScroller])`）。原来这里只传了 `onClose`，
       * 于是 `PlatformMusicPage` 用它**自己默认 new 出来的** `Scroller` 去包 `Scroll`
       * ⇒ 它滚它的、标题栏收不到滚动量 ⇒ **永远不模糊**（材质在，但没有"滑过才渐变模糊"的那一段）。
       * 传同一个 scroller 之后，滚动量才会喂给标题栏。
       */
      PlatformMusicPage({
        pageScroller: this.pageScroller,
        contentTopOffset: this.contentTopOffset(),
        onClose: (): void => {
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  /** Cached title bar options so scrolling rebuilds do not recreate material params. */
  private cachedTitleBarOptions: HdsNavigationTitleBarOptions | undefined = undefined;

  /**
   * 页根（`HdsNavDestination`）在**窗口坐标**里的顶边 y（vp），由 `onAreaChange` 实测。
   * 默认 0 = "页盒贴屏幕顶"。量到非 0 后，子面板让位（`panelTopInset` / `contentTopOffset`）
   * 与标题栏 `avoidLayoutSafeArea` 一起按它换算。见 `PageTopInsetHelper`。
   */
  @Local boxTopVp: number = 0;

  /** 盒顶量出来（或变化）后丢弃标题栏缓存，让 `avoidLayoutSafeArea` 跟着改。 */
  @Monitor('boxTopVp')
  onBoxTopChanged(): void {
    this.cachedTitleBarOptions = undefined;
  }

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
      // ★ 盒顶实测贴屏幕顶（0）时才让 HDS 标题栏自己退回状态栏下方（否则标题会掉 38+38）。
      avoidLayoutSafeArea: PageTopInsetHelper.avoidLayoutSafeArea(this.boxTopVp),
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
    .clipContent(ContentClipMode.SAFE_AREA)
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


  /** 显式读取版本号，让共享 store 的异步恢复和其它入口修改驱动刷新。 */
  private networkBaseQuality(wifi: boolean): string {
    const version: number = this.store.networkQualityVersion;
    return this.store.getNetworkBaseQuality(wifi);
  }

  private networkExtendedQuality(wifi: boolean): string {
    const version: number = this.store.networkQualityVersion;
    return this.store.getNetworkExtendedQuality(wifi);
  }

  private networkExtendedEnabled(wifi: boolean): boolean {
    const version: number = this.store.networkQualityVersion;
    return this.store.getNetworkExtendedEnabled(wifi);
  }

  private networkEffectiveQualityLabel(wifi: boolean): string {
    const version: number = this.store.networkQualityVersion;
    const quality: string = this.store.getNetworkPlayQuality(wifi);
    for (let row: number = 0; row < this.qualityRowValues.length; row++) {
      const index: number = this.qualityRowValues[row].indexOf(quality);
      if (index >= 0) {
        return this.qualityRowLabels[row][index];
      }
    }
    return quality;
  }

  private logNetworkQuality(wifi: boolean, action: string): void {
    console.info(`[RzdQualitySettings] network=${wifi ? 'wifi-ethernet' : 'cellular'} action=${action} ` +
      `enabled=${this.store.getNetworkExtendedEnabled(wifi)} base=${this.store.getNetworkBaseQuality(wifi)} ` +
      `extended=${this.store.getNetworkExtendedQuality(wifi)} effective=${this.store.getNetworkPlayQuality(wifi)}`);
  }

  @Builder
  private NetworkQualitySettings(wifi: boolean, title: string) {
    this.SubTitle(title)
    this.SubTitle('基础音质')
    this.CapsuleSelector(this.qualityRowLabels[0],
      this.qualityRowValues[0].indexOf(this.networkBaseQuality(wifi)), (index: number) => {
        this.store.setNetworkBaseQuality(wifi, this.qualityRowValues[0][index]);
        this.logNetworkQuality(wifi, 'base');
      })
    this.SubTitle('拓展音质')
    Column() {
      CapsuleSegmentButtonV2({
        items: this.networkQualityModeItems,
        selectedIndex: this.networkExtendedEnabled(wifi) ? 1 : 0,
        $selectedIndex: (index: number): void => {
          this.store.setNetworkExtendedEnabled(wifi, index === 1);
          this.logNetworkQuality(wifi, 'segment-mode');
        },
        buttonBackgroundColor: ColorMetrics.resourceColor($r('app.color.capsule_background')),
        buttonMinHeight: LengthMetrics.vp(40),
        buttonBorderRadius: LengthMetrics.vp(20),
        itemMinHeight: LengthMetrics.vp(40),
        itemBorderRadius: LengthMetrics.vp(20),
        itemFontColor: ColorMetrics.resourceColor($r('sys.color.font_primary')),
        itemSelectedFontColor: ColorMetrics.resourceColor($r('sys.color.font_on_primary')),
        itemSelectedBackgroundColor: ColorMetrics.resourceColor(this.themeState.color)
      })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    if (this.networkExtendedEnabled(wifi)) {
      this.CapsuleSelector(this.qualityRowLabels[1],
        this.qualityRowValues[1].indexOf(this.networkExtendedQuality(wifi)), (index: number) => {
          this.store.setNetworkExtendedQuality(wifi, this.qualityRowValues[1][index]);
          this.logNetworkQuality(wifi, 'extended');
        })
    }
    Text('当前生效音质：' + this.networkEffectiveQualityLabel(wifi))
      .fontSize($r('sys.float.Caption_M'))
      .fontColor(this.themeState.color)
      .width('100%')
      .padding({ top: 8, bottom: 8 })
  }

  /** 播放设置弹窗：音质+混音 / 其余，拆为两张卡片。 */
  @Builder
  private PlaybackSheet() {
    Scroll(this.pageScroller) {
      Column({ space: 12 }) {
        Blank().height(this.panelTopInset())
        Column() {
          this.NetworkQualitySettings(true, 'Wi-Fi / 以太网默认播放/下载音质')
          this.NetworkQualitySettings(false, '蜂窝默认播放/下载音质')
          // ⛔ 2026-10-17 删除：「封面圆角」设置项（直角/小/中/大/超大）。
          //   用户明确要求删掉；圆角改回无界那一个绝对值（`radiusPlayer = 8`）。
          //   删掉的不只是这一行 UI：`getCoverCornerRadius()` 的两个消费点
          //   （`PlaybackPage.aboutToAppear` / `MusicPlayInfoBlock.aboutToAppear`）也都已改成常量。

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

          // ★★★ 2026-10-18（用户：「现在似乎不能锁屏播放，你在播放设置里加一下，默认开」）：
          //   这一项控制"音频后台长时任务"（息屏/锁屏/切后台是否继续放）。
          //   切换后**立刻**通知播放器（`MediaService.applyLockScreenPlay`）：
          //     开 ⇒ 正在播就马上补上长时任务；关 ⇒ 立刻停掉长时任务。
          //   不这样做的话，用户以为"已经关了"，实际要等下一首才生效。
          this.SubTitle($r('app.string.setting_sub_lock_screen_play'))
          this.CapsuleSelector(this.onOffOptions, this.lockScreenPlay ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.lockScreenPlay = isOn;
              MusicStoreService.getInstance().setLockScreenPlay(isOn);
              MediaService.getInstance().applyLockScreenPlay(isOn);
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
      .padding({ left: 20, right: 20, top: 12, bottom: SETTINGS_PANEL_BOTTOM_VP })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 0 })
    .align(Alignment.Top)
    .clipContent(ContentClipMode.SAFE_AREA)
    .scrollBar(BarState.Off)
  }

  /** 下载设置弹窗：命名格式 / 质量标签 / 保存位置。 */
  private downloadQualityMode(): string {
    const version: number = this.store.downloadQualityVersion;
    return this.store.getDownloadQualityMode();
  }

  @Builder
  private DownloadQualitySettings() {
    this.SubTitle('下载时选择音质')
    CapsuleSegmentButtonV2({
      items: this.downloadQualityModeItems,
      selectedIndex: this.downloadQualityMode() === 'manual' ? 1 : 0,
      $selectedIndex: (index: number): void => {
        this.store.setDownloadQualityMode(index === 1 ? 'manual' : 'follow');
        console.info('[RzdDownloadQuality] settings mode=' + this.store.getDownloadQualityMode());
      },
      buttonBackgroundColor: ColorMetrics.resourceColor($r('app.color.capsule_background')),
      buttonMinHeight: LengthMetrics.vp(40),
      buttonBorderRadius: LengthMetrics.vp(20),
      itemMinHeight: LengthMetrics.vp(40),
      itemBorderRadius: LengthMetrics.vp(20),
      itemFontColor: ColorMetrics.resourceColor($r('sys.color.font_primary')),
      itemSelectedFontColor: ColorMetrics.resourceColor($r('sys.color.font_on_primary')),
      itemSelectedBackgroundColor: ColorMetrics.resourceColor(this.themeState.color)
    })
  }

  @Builder
  private DownloadSheet() {
    Scroll(this.pageScroller) {
      Column({ space: 12 }) {
        Blank().height(this.panelTopInset())
        Column() {
          this.DownloadQualitySettings()
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
      .padding({ left: 20, right: 20, top: 12, bottom: SETTINGS_PANEL_BOTTOM_VP })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 0 })
    .align(Alignment.Top)
    .clipContent(ContentClipMode.SAFE_AREA)
    .scrollBar(BarState.Off)
  }

  /** 下载管理页：任务队列与进度。 */
  @Builder
  private DownloadManagerSheet() {
    Column() {
      // ★ 同「平台音乐」那条：把本页的 scroller 传下去，否则它自己 new 一个 ⇒
      //   它滚它的、标题栏收不到滚动量 ⇒ 滑过标题栏时**不会渐变模糊**。
      DownloadManagerSection({ pageScroller: this.pageScroller })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.panelTopInset() })
  }

  /** 主题设置弹窗：主题色 / 日夜模式 / 光感，拆为两张卡片。 */
  @Builder
  private ThemeSheet() {
    Scroll(this.pageScroller) {
      Column({ space: 12 }) {
        Blank().height(this.panelTopInset())
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
      .padding({ left: 20, right: 20, top: 12, bottom: SETTINGS_PANEL_BOTTOM_VP })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 0 })
    .align(Alignment.Top)
    .clipContent(ContentClipMode.SAFE_AREA)
    .scrollBar(BarState.Off)
  }

  /**
   * 桌面歌词开关下面那行说明。
   *
   * 把「设备支不支持」和「什么时候显示」讲清楚：设备不支持时开关是没用的，
   * 不说明白用户只会以为功能坏了（lxmusic 同样写了这层提示）。
   */
  private desktopLyricHint(): string {
    if (this.desktopLyricSupport === false) {
      return '当前设备/系统不支持桌面歌词，这个开关不会有实际效果（播控中心里的歌词不受影响）。';
    }
    if (!this.desktopLyric) {
      return '关闭后不显示系统悬浮歌词；歌词仍会提供给播控中心 / 锁屏。';
    }
    return '播放中且有歌词时，系统会在桌面显示悬浮歌词；暂停不收起，停播、换到没有歌词的歌或关掉开关时收起。';
  }

  /** 其它设置弹窗：添加位置 / 首页来源+登录推荐 / 同步设置入口，拆为三张卡片。 */
  @Builder
  private OtherSheet() {    Scroll(this.pageScroller) {
      Column({ space: 12 }) {
        Blank().height(this.panelTopInset())
        CoverCacheSettingsCard()
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
              // 首页这时在另一个 Tab 里：显式通知一次，别只靠 @Monitor（见 HomeSourceBus 注释）
              notifyHomeSourceRefresh();
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

        // 桌面歌词（系统 AVSession 提供的悬浮窗歌词）：窗口由系统绘制，
        // 应用只把标准 LRC 写进 AVMetadata.lyric 并控制显隐（见 features/player 的 MediaService）。
        Column() {
          this.SubTitle('桌面歌词')
          this.CapsuleSelector(this.onOffOptions, this.desktopLyric ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.desktopLyric = isOn;
              MusicStoreService.getInstance().setDesktopLyric(isOn);
              // 立刻生效：开 → 需要时先 enable 再显示；关 → 收起悬浮窗
              MediaService.getInstance().refreshDesktopLyric();
            })
          Text(this.desktopLyricHint())
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .padding({ top: 6 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))

        // 车载蓝牙歌词（移植自 lxmusic-harmony）：AVMetadata.singleLyricText 推当前句
        Column() {
          this.SubTitle('车载蓝牙歌词')
          this.CapsuleSelector(this.onOffOptions, this.bluetoothLyric ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.bluetoothLyric = isOn;
              MusicStoreService.getInstance().setBluetoothLyric(isOn);
              MediaService.getInstance().refreshBluetoothLyric();
            })
          Text('向蓝牙车机/音箱推送当前歌词句（API 17+）。部分设备开启后可能略有卡顿，默认关闭。')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .padding({ top: 6 })
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
      .padding({ left: 20, right: 20, top: 12, bottom: SETTINGS_PANEL_BOTTOM_VP })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 0 })
    .align(Alignment.Top)
    .clipContent(ContentClipMode.SAFE_AREA)
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
        Blank().height(this.panelTopInset())
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
      .padding({ left: 20, right: 20, top: 24, bottom: SETTINGS_PANEL_BOTTOM_VP })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 0 })
    .align(Alignment.Top)
    .clipContent(ContentClipMode.SAFE_AREA)
    .scrollBar(BarState.Off)
  }


  private isSourceInOrder(apiId: string): boolean {
    return this.sourceOrderIds.indexOf(apiId) >= 0;
  }

  private persistSourceOrder(): void {
    MusicStoreService.getInstance().setSourceScriptOrder(this.sourceOrderIds);
  }

  private toggleSourceInOrder(apiId: string): void {
    const idx: number = this.sourceOrderIds.indexOf(apiId);
    if (idx >= 0) {
      const next: string[] = [];
      for (let i: number = 0; i < this.sourceOrderIds.length; i++) {
        if (i !== idx) {
          next.push(this.sourceOrderIds[i]);
        }
      }
      this.sourceOrderIds = next;
    } else {
      const next: string[] = [];
      for (let i: number = 0; i < this.sourceOrderIds.length; i++) {
        next.push(this.sourceOrderIds[i]);
      }
      next.push(apiId);
      this.sourceOrderIds = next;
    }
    this.persistSourceOrder();
  }

  private moveSourceOrderUp(apiId: string): void {
    const idx: number = this.sourceOrderIds.indexOf(apiId);
    if (idx <= 0) {
      return;
    }
    const next: string[] = [];
    for (let i: number = 0; i < this.sourceOrderIds.length; i++) {
      next.push(this.sourceOrderIds[i]);
    }
    const tmp: string = next[idx - 1];
    next[idx - 1] = next[idx];
    next[idx] = tmp;
    this.sourceOrderIds = next;
    this.persistSourceOrder();
  }

  private moveSourceOrderDown(apiId: string): void {
    const idx: number = this.sourceOrderIds.indexOf(apiId);
    if (idx < 0 || idx >= this.sourceOrderIds.length - 1) {
      return;
    }
    const next: string[] = [];
    for (let i: number = 0; i < this.sourceOrderIds.length; i++) {
      next.push(this.sourceOrderIds[i]);
    }
    const tmp: string = next[idx + 1];
    next[idx + 1] = next[idx];
    next[idx] = tmp;
    this.sourceOrderIds = next;
    this.persistSourceOrder();
  }

  private orderedApiListForUi(): LXUserApiInfo[] {
    const byId: Map<string, LXUserApiInfo> = new Map();
    for (let i: number = 0; i < this.lxApiList.length; i++) {
      byId.set(this.lxApiList[i].id, this.lxApiList[i]);
    }
    const out: LXUserApiInfo[] = [];
    const seen: Record<string, boolean> = {};
    for (let i: number = 0; i < this.sourceOrderIds.length; i++) {
      const id: string = this.sourceOrderIds[i];
      const api: LXUserApiInfo | undefined = byId.get(id);
      if (api !== undefined) {
        out.push(api);
        seen[id] = true;
      }
    }
    for (let i: number = 0; i < this.lxApiList.length; i++) {
      if (!seen[this.lxApiList[i].id]) {
        out.push(this.lxApiList[i]);
      }
    }
    return out;
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
          /**
           * ★ 顶部这段留白放在**滚动内容里面**（不是外层 padding），目的是让卡片能**滑到 HDS
           *   标题栏底下**（沉浸式）：静止时与原来一样、第一张卡正好在标题栏下沿，
           *   一往上滑就从标题栏（渐变模糊材质）底下穿过去，顶上那 56vp 不再是一段"死空白"。
           *   用户 2026-10-11：「音源管理页面上方下方都一大块空白，能不能去掉」。
           */
          Blank().height(PageTopInsetHelper.contentOffsetVp(this.boxTopVp))
          Text('勾选参与依次调用，上下键调整优先级；圆点为当前默认音源')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')

          ForEach(this.orderedApiListForUi(), (api: LXUserApiInfo) => {
            Row({ space: 6 }) {
              Checkbox()
                .select(this.isSourceInOrder(api.id))
                .selectedColor(this.themeState.color)
                .width(20)
                .height(20)
                .onChange((checked: boolean) => {
                  const on: boolean = this.isSourceInOrder(api.id);
                  if (checked !== on) {
                    this.toggleSourceInOrder(api.id);
                  }
                })

              Radio({ value: api.id, group: 'lxSourceDetail', indicatorType: RadioIndicatorType.TICK })
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
                Row({ space: 4 }) {
                  if (this.isSourceInOrder(api.id)) {
                    Text('顺序 ' + (this.sourceOrderIds.indexOf(api.id) + 1))
                      .fontSize($r('sys.float.Caption_S'))
                      .fontColor(this.themeState.color)
                  }
                  if (api.author.length > 0 || api.version.length > 0) {
                    Text((api.author.length > 0 ? api.author : '') +
                      (api.version.length > 0 ? ' v' + api.version : ''))
                      .fontSize($r('sys.float.Caption_S'))
                      .fontColor($r('sys.color.font_tertiary'))
                      .maxLines(1)
                  }
                }
                // ★「支持的平台」标签：来源是脚本 init 上报并已持久化的 sources，
                //   没检测到就给中性提示（详见 LxSourceTags.ets 的文件头）。
                LxSourceDeclaredBlock({
                  items: this.lxPlatformsOf(api),
                  accentColor: this.themeState.color,
                  active: this.activeSource === api.id
                })
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

              if (this.isSourceInOrder(api.id)) {
                SymbolGlyph($r('sys.symbol.chevron_up'))
                  .fontSize(18)
                  .fontColor([$r('sys.color.font_tertiary')])
                  .onClick(() => {
                    this.moveSourceOrderUp(api.id);
                  })
                SymbolGlyph($r('sys.symbol.chevron_down'))
                  .fontSize(18)
                  .fontColor([$r('sys.color.font_tertiary')])
                  .onClick(() => {
                    this.moveSourceOrderDown(api.id);
                  })
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
          }, (api: LXUserApiInfo) => api.id + '|' + (this.isSourceInOrder(api.id) ? '1' : '0') + '|' + this.sourceOrderIds.indexOf(api.id))

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
      .clipContent(ContentClipMode.SAFE_AREA)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      // ★ 底部那段"给悬浮播放条让位"的留白**必须留在列表里**（`contentEndOffset` = 内容末端到显示区
      //   边界的距离，官方 @since 22，List/Scroll 通用）—— 它随内容一起滚走。
      //   用户 2026-10-11 报「音源管理页面底部还是空白，我感觉是你又把底部留白写死在屏幕底部而不是列表底部」
      //   —— 原来这段写在外层容器的 `padding({ bottom })` 上：那是**固定在屏幕底部的一条死带**，
      //   列表永远用不到它，滚到底就露一块空白。现在改成内容末端的偏移，滚到底刚好停在播放条上方。
      .contentEndOffset(SETTINGS_PANEL_BOTTOM_VP)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    // 顶部的 56vp 已经挪进 Scroll 内容里（见上面那个 `Blank()`），这里**不再补**顶部留白 ——
    // 否则就是"标题栏 56 + 外层 56"两份，顶上白白多一段（用户报的"上方一大块空白"）。
    // 底部留白同理：已改成 Scroll 的 `contentEndOffset`，外层**不再占位**。
    .padding({ left: 20, right: 20 })
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
      .onBackPressed((): boolean => guardPlayerBack('SettingsDetailPage'))
      .hideTitleBar(false)
      .titleBar(this.getDetailTitleBar())
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .onReady((context: NavDestinationContext) => {
        this.pathStack = context.pathStack;
      })
      .bindToScrollable([this.pageScroller])
      // ★★ 用户 2026-10-11：「顶栏标题错位的问题还在，你应该参考一下其他显示正常的页面是怎么写的」。
    //   逐页对比后：显示正常的 MinePage / RecommendPage **都没有** expandSafeArea，
    //   而所有标题偏低的页面都有 ⇒ 照正常页面去掉它（官方语义：expandSafeArea 只延伸**绘制区**，
    //   「子组件相对屏幕位置不变」，但它会让 HDS 标题栏的定位多让一次）。
    //   页面底色由页盒自身 ackgroundColor 铺满（盒顶 = 0，实测见 RzdPageTopInset），不需要它补状态栏那一条。
      // ★ 状态栏三件套（2026-10-11 定稿，用户第三次纠正后）：这里的 `ignoreLayoutSafeArea` **必须带 TOP** ——
      //   HDS 标题栏自己会按"状态栏高度"往下让位，所以页面盒子必须从屏幕 y=0 起排；
      //   只写 BOTTOM（盒子从状态栏下沿起排）会变成"盒子让一次 + 标题栏再让一次" ⇒
      //   整条标题掉到状态栏下面约一个状态栏高度（用户原话「整个标题移到了状态栏下面」），
      //   内容也跟着多顶 38vp（「上方留的空距有点大了」）。
      //   （另一处口径：滚动容器用 `clipContent(ContentClipMode.SAFE_AREA)` 让内容能画进状态栏。）
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      // ★ 实测页盒顶边（窗口坐标 vp）：子面板让位与标题栏 `avoidLayoutSafeArea` 都由它推出来。
      //   只在变化超过 0.5vp 时写状态，避免与布局互相追。
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const top: number = newArea.globalPosition.y as number;
        if (Math.abs(top - this.boxTopVp) > 0.5) {
          this.boxTopVp = top;
          hilog.info(0x0000, 'RzdSettingsDetail',
            'RzdPageTopInset boxTopVp=%{public}f page=settingsDetail offset=%{public}f avoid=%{public}s',
            top, PageTopInsetHelper.contentOffsetVp(top),
            String(PageTopInsetHelper.avoidLayoutSafeArea(top)));
        }
      })
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
      // ★ 内容容器**不加**顶部 padding：用户要"延伸进状态栏"（见 `panelTopInset()` 的说明），
      //   让开状态栏 + 标题栏的那一段加在各子面板自己的顶部留白上，
      //   这样列表往上滚时能一直画到屏幕最顶端（状态栏那一条也归页面）。
      //   ⚠️ 宽屏内嵌（`embedded`，右栏那一支）不参与状态栏避让（外层大设置页负责）。
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