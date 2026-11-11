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

import { appendPlayLog , setScreenOrientation , UsbAudioService, UsbAudioState , TabBarConfigModel } from 'musicbasic';
import { bundleManager } from '@kit.AbilityKit';
import { DrawableDescriptor, LayeredDrawableDescriptor } from '@kit.ArkUI';
import { guardPlayerBack, PlaybackPreferenceService } from 'musicbasic';
import { AppStorageV2, CapsuleSegmentButtonV2, ColorMetrics, SegmentButtonV2Items, uiObserver } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, ConfigurationConstant, Want } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { CoverCacheSettingsCard, AmbientState, AppStorageKeys, RouterUrlConstants, BreakpointType, HomeSourceState, LyricBlurState, LyricCenterState, LyricFontSizeState, LyricFpsState, MotionCoverState, MusicStoreService, notifyHomeSourceRefresh, PageTopInsetHelper, ShowMiniLyricState, ThemeState, TitleBarConstants, UseAccountRecState, buildTitleMaterial, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';
import {
  DownloadService,
   LXUserApiInfo, LXSourcePlatformInfo, lxDeclaredPlatforms, lxDeclaredPlatformsOf, lxSourceManager, MediaService
, PlaybackTuningPanel } from 'player';
import type { LXApiImportResult } from 'player';
import { pickPlaybackQuality, probeBySample, qualityRank, QUALITY_CHAIN } from 'player';
import type { LXUserApiSourceInfo } from 'player';
import { SyncSettingsPanel } from 'sync';
import { AccountManageSheet } from '../account/AccountManageSheet';
import { PlatformMusicPage } from '../account/PlatformMusicPage';
import { DownloadManagerSection } from './DownloadManagerSection';
import { importSourceFiles } from '../util/SourceFileImport';

import { CustomColorSheetContent } from './CustomColorSheetContent';
import { CapsuleSegmentedSelector } from './CapsuleSegmentedSelector';
import { LxSourceDeclaredBlock } from './LxSourceTags';
import { SourceManagerList } from './SourceManagerList';
import { readOfficialUpdateAlert, SourceUpdateInfo } from '../util/SourceUpdate';
import { LengthMetrics } from '@kit.ArkUI';

/** 单次「测试音源」对每个平台最多试几档（从最高往下，命中即停）。 */
const PROBE_MAX_TIERS: number = 5;
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

/** 软件图标变体（设置页横向卡片用）。 */
interface IconVariant {
  value: string;
  label: string;
  /** 预览用前景（艺术图标直接用整图） */
  foreground: Resource;
  /** 预览底色 */
  background: ResourceColor;
  /** 分层图标的前景资源 */
  fgRes: Resource;
  /** 分层图标的背景资源 */
  bgRes: Resource;
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
  /** 长按拖动排序：当前被拖动的音源 id。 */
  @Local dragSourceId: string = '';
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
  /** 当前选中的软件图标变体（素材见 AppScope/resources/base/media/foreground_*.png）。 */
  @Local iconVariant: string = 'default';
  /** 当前即时合成的分层图标（LayeredDrawableDescriptor，无需重启）。 */
  @Local appliedIcon: LayeredDrawableDescriptor | undefined = undefined;
  /** 图标变体清单。 */
  private readonly iconVariants: IconVariant[] = [
    { value: 'default', label: '原版', foreground: $r('app.media.icon_alt_std'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_std'), bgRes: $r('app.media.icon_alt_std') },
    { value: 'big', label: '放大', foreground: $r('app.media.icon_alt_big'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_big'), bgRes: $r('app.media.icon_alt_big') },
    { value: 'blue', label: '蓝', foreground: $r('app.media.icon_alt_blue'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_blue'), bgRes: $r('app.media.icon_alt_blue') },
    { value: 'green', label: '绿', foreground: $r('app.media.icon_alt_green'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_green'), bgRes: $r('app.media.icon_alt_green') },
    { value: 'purple', label: '紫', foreground: $r('app.media.icon_alt_purple'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_purple'), bgRes: $r('app.media.icon_alt_purple') },
    { value: 'orange', label: '橙', foreground: $r('app.media.icon_alt_orange'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_orange'), bgRes: $r('app.media.icon_alt_orange') },
    { value: 'red', label: '红', foreground: $r('app.media.icon_alt_red'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_red'), bgRes: $r('app.media.icon_alt_red') },
    { value: 'art1', label: '墨韵', foreground: $r('app.media.icon_alt_art1'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_art1'), bgRes: $r('app.media.icon_alt_art1') },
    { value: 'art2', label: '竹影', foreground: $r('app.media.icon_alt_art2'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_art2'), bgRes: $r('app.media.icon_alt_art2') },
    { value: 'art3', label: '云笺', foreground: $r('app.media.icon_alt_art3'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_art3'), bgRes: $r('app.media.icon_alt_art3') },
    { value: 'wujie', label: '无界', foreground: $r('app.media.icon_alt_wujie'), background: '#FFFFFF', fgRes: $r('app.media.icon_alt_wujie'), bgRes: $r('app.media.icon_alt_wujie') }
  ];
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
  /** 桌面歌词悬浮窗是否被用户锁定（锁定后只能从这里解锁）。 */
  @Local desktopLyricLocked: boolean = false;
  /** MediaService 锁状态回调（aboutToAppear 注册、aboutToDisappear 摘除，注册/摘除必须是同一引用）。 */
  private readonly onDesktopLyricLockChange: (locked: boolean) => void = (locked: boolean): void => {
    this.desktopLyricLocked = locked;
  };
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
  /** 屏幕方向：auto / portrait / landscape。 */
  /** USB 独占输出（需外接 USB DAC）。 */
  @Local usbExclusive: boolean = false;
  @Local tabShowNow: boolean = true;
  @Local tabShowEcho: boolean = true;
  @Local tabNowFirst: boolean = true;
  @Local screenOrientation: string = 'auto';
  /** 启动应用自动开始播放（默认关）。 */
  @Local autoPlayOnLaunch: boolean = false;
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
  /** 动态封面（歌手 / 专辑 / 歌单页）：默认开。 */
  @Local motionCover: boolean = true;
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
  /**
   * 首页 / 现在就听的来源平台。
   * ★ 2026-10-24（甲方第 ⑥ 条：「给首页推荐加上另外两个平台」）：补上酷我（kw）与咪咕（mg），
   *   这两个平台的歌单广场接口可用，自建推荐在它们上面也能取到"分类 → 歌单 → 歌"。
   *   ⚠️ 值域与 `RecommendDataUtil.mapHomeSource()` 一致：qq 是 tx 的别名，其余直接用 source id。
   */
  private readonly homeSourceOptions: string[] = ['QQ', '酷狗', '网易', '酷我', '咪咕', '汽水'];
  private readonly homeSourceValues: string[] = ['qq', 'kg', 'wy', 'kw', 'mg', 'qs'];
  /** USB 独占状态文案（来自 UsbAudioService 的实时状态）。 */
  /** 读取 Tab 栏配置（缺省：两个都显示、现在就听在前）。 */
  private loadTabBarConfig(): void {
    const raw: string = MusicStoreService.getInstance().getTabBarConfig();
    if (raw.length === 0) {
      return;
    }
    try {
      const obj: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      this.tabShowNow = obj.now !== false;
      this.tabShowEcho = obj.echo !== false;
      this.tabNowFirst = obj.nowFirst !== false;
    } catch (err) {
    }
  }

  /** 保存并广播 Tab 栏配置（壳层监听 rzd_tab_bar_config 重排）。 */
  private saveTabBarConfig(): void {
    const payload: Record<string, Object> = {};
    payload.now = this.tabShowNow;
    payload.echo = this.tabShowEcho;
    payload.nowFirst = this.tabNowFirst;
    const json: string = JSON.stringify(payload);
    MusicStoreService.getInstance().setTabBarConfig(json);
    AppStorage.setOrCreate('rzd_tab_bar_config', json);
    appendPlayLog('[RzdTabConfig] save ' + json);
  }

  /** 当前底栏顺序预览（首页/我的固定，中间两项按配置）。 */
  private tabOrderPreview(): string {
    const cfg: TabBarConfigModel = TabBarConfigModel.parse(
      MusicStoreService.getInstance().getTabBarConfig());
    const names: string[] = ['首页'];
    if (cfg.now && cfg.echo) {
      names.push(cfg.nowFirst ? '现在就听' : '回响');
      names.push(cfg.nowFirst ? '回响' : '现在就听');
    } else if (cfg.now) {
      names.push('现在就听');
    } else {
      names.push('回响');
    }
    names.push('我的');
    return '当前顺序：' + names.join(' → ');
  }
  /** 主题设置最下面的「自定义 Tab 栏」（只允许调整「现在就听」「回响」）。 */
  /** 主题设置最下面的「自定义 Tab 栏」：只保留标题、两行开关、顺序三块。 */
  /** 主题设置最下面的「自定义 Tab 栏」。 */
  @Builder
  private TabBarCustomSection() {
    Column() {
      this.SubTitle('自定义 Tab 栏')
      // 先回响、再现在就听（与用户给的顺序一致）；标签独占一行，避免被开关挤没
      this.SubTitle('回响')
      this.CapsuleSelector(this.onOffOptions, this.tabShowEcho ? 0 : 1,
        (index: number) => {
          this.tabShowEcho = index === 0;
          this.saveTabBarConfig();
        })
      this.SubTitle('现在就听')
      this.CapsuleSelector(this.onOffOptions, this.tabShowNow ? 0 : 1,
        (index: number) => {
          this.tabShowNow = index === 0;
          this.saveTabBarConfig();
        })
      // ⏸ 2026-10-31（用户：暂时不需要换序）：先注释，等后面再做（方案见记忆 §191）
      // this.SubTitle('两个页签的顺序')
      // this.CapsuleSelector(['现在就听在前', '回响在前'], this.tabNowFirst ? 0 : 1,
      //   (index: number) => {
      //     this.tabNowFirst = index === 0;
      //     this.saveTabBarConfig();
      //   })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 8 })
    .borderRadius($r('sys.float.corner_radius_level12'))
    .backgroundColor($r('app.color.card_background'))
  }




  private usbStatusText(): string {
    const st: UsbAudioState = UsbAudioService.getInstance().state;
    if (st.connected) {
      const outParams: string = AppStorage.get<string>('rzd_usb_out_params') ?? '';
      const extra: string = outParams.length > 0 ? ' · 输出 ' + outParams : '';
      return '已连接：' + st.productName + '（' + st.vidPid + '，fd=' + st.fd + '）· ' +
        st.capabilityText + extra;
    }
    if (st.present) {
      return st.productName + '（' + st.vidPid + '）· ' + st.statusText;
    }
    return st.statusText;
  }

  private readonly onOffOptions: string[] = ['开', '关'];
  private readonly saveLocationOptions: string[] = ['手动选择', 'Download目录', '自定义目录'];
  private readonly colorModeOptions: string[] = ['日间', '夜间', '跟随系统'];
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // USB 独占：设置页打开时轮询设备（本 SDK 无 attach/detach 事件）
    UsbAudioService.getInstance().startPolling();
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
            backIconStyle: { iconColor: $r('app.color.font_primary'), backgroundColor: '#1A808080' }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            backIconStyle: { iconColor: $r('app.color.font_primary'), backgroundColor: '#1A808080' }
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
      // ★★★ 2026-11-05（真机日志实证：`[回退链] 没有勾选任何音源，直接返回`）：
      //   这里以前只是**在 UI 上**把"全部已导入"当成已勾选、**从不落盘**，
      //   而播放链路只认这份持久化配置 ⇒ 空候选链 ⇒ 0 次请求秒失败；
      //   用户看到"全都勾着"，自然以为已经配置好了。
      //   ⇒ 首次进来就把这份默认全选**写实**，UI 与播放链路从此一致。
      if (ids.length > 0) {
        MusicStoreService.getInstance().setSourceScriptOrder(ids);
        appendPlayLog('[音源顺序] init ' + ids.length);
      }
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
      // 探测回调落地时再对一次锁定态：进场那一刻可能还没有会话，这里拿到的是最新值。
      this.desktopLyricLocked = MediaService.getInstance().isDesktopLyricLocked();
    });
    // 锁定态先同步一次（悬浮窗可能在本页没开着时就被锁上了，监听只覆盖"之后"的变化）
    this.desktopLyricLocked = MediaService.getInstance().isDesktopLyricLocked();
    // 用户从悬浮窗上点「锁定」时实时刷新本页按钮态（aboutToDisappear 里摘除）
    MediaService.getInstance().addDesktopLyricLockListener(this.onDesktopLyricLockChange);
    // 锁屏继续播放：缺省（没有这条记录）= 开
    this.lockScreenPlay = MusicStoreService.getInstance().getLockScreenPlay();
    this.audioMix = MusicStoreService.getInstance().getAudioMix();
    this.screenOrientation = MusicStoreService.getInstance().getScreenOrientation();
    this.usbExclusive = MusicStoreService.getInstance().getUsbExclusive();
    this.loadTabBarConfig();
    this.autoPlayOnLaunch = MusicStoreService.getInstance().getAutoPlayOnLaunch();
    this.lyricBlurEnabled = MusicStoreService.getInstance().getLyricBlurEnabled();
    this.saveToDownloadDir = MusicStoreService.getInstance().getDownloadSaveMode() === 'download';
    this.downloadNameFormat = MusicStoreService.getInstance().getDownloadNameFormat();
    this.playlistAddPosition = MusicStoreService.getInstance().getPlaylistAddPosition();
    this.keepScreenOn = MusicStoreService.getInstance().getKeepScreenOn();
    this.downloadQualityTag = MusicStoreService.getInstance().getDownloadQualityTag();
    this.homeSource = MusicStoreService.getInstance().getHomeSource();
    this.useAccountRec = MusicStoreService.getInstance().getUseAccountRec();
    // 动态封面：缺省（没有这条记录）= 开
    this.motionCover = MusicStoreService.getInstance().getMotionCoverEnabled();
    this.lyricFontSize = MusicStoreService.getInstance().getLyricFontSize();
    // ⛔ 2026-10-17：`coverRadius` 设置项已删除（见 `PlaybackSheet`），这里不再读、也不再写
    //   `AppStorage 'lxCoverRadius'`。
    this.downloadLrc = MusicStoreService.getInstance().getDownloadLrc();
    this.lyricFps = MusicStoreService.getInstance().getLyricFps();
    this.lyricCenter = MusicStoreService.getInstance().getLyricCenterEnabled();
    this.lastError = AppStorage.get<string>('lxLastError') ?? '';
    const persistentLog: string = MusicStoreService.getInstance().getRuntimeDiagnostics();
    this.playLog = (AppStorage.get<string>('lxPlayLog') ?? '') +
      (persistentLog.length > 0 ? '\n──── 持久诊断（重启保留）────\n' + persistentLog : '');
    this.colorMode = MusicStoreService.getInstance().getColorMode();
    this.iconVariant = MusicStoreService.getInstance().getAppIconVariant();
    for (let i: number = 0; i < this.iconVariants.length; i++) {
      if (this.iconVariants[i].value === this.iconVariant) {
        this.buildLayeredIcon(this.iconVariants[i]);
        break;
      }
    }
    this.iconVariant = MusicStoreService.getInstance().getAppIconVariant();
    for (let i: number = 0; i < this.iconVariants.length; i++) {
      if (this.iconVariants[i].value === this.iconVariant) {
        this.buildLayeredIcon(this.iconVariants[i]);
        break;
      }
    }
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
  /**
   * A4：用**预置样曲**对已勾选源的每个平台跑一遍音质探测（只测该平台最高与次高两档）。
   * 结果进会话缓存，平台 ToolTip 会显示「已验证 / 未通过 / 未测」。
   */
  /**
   * 测试音质。
   * ★ 用户 2026-10-29：只测"点了测试的那个音源"，不再遍历全部。
   * @param onlyApiId 传了 apiId 就只测这一个源；不传则保持旧行为（全部已启用源）。
   */
  private async runQualityProbe(onlyApiId?: string): Promise<void> {
    let passed: number = 0;
    let total: number = 0;
    const ordered: LXUserApiInfo[] = this.orderedApiListForUi();
        // ★ 2026-10-29（用户：测试音质要测"我选的那些音源"）：不再只看前 3 个，
    //   遍历所有已启用音源（顺序仍按用户排序）。
    for (let i: number = 0; i < ordered.length; i++) {
      if (onlyApiId !== undefined && onlyApiId.length > 0 && ordered[i].id !== onlyApiId) {
        continue;
      }
      const api: LXUserApiInfo = ordered[i];
      // ★ 点对某个源点「测试」时，即使它没勾选也要测（用户 2026-10-29）
      const testingThisOne: boolean = onlyApiId !== undefined && onlyApiId.length > 0;
      if (!testingThisOne && !this.isSourceInOrder(api.id)) {
        continue;
      }
      const platforms: LXSourcePlatformInfo[] = this.lxPlatformsOf(api);
      for (let p: number = 0; p < platforms.length; p++) {
        const info: LXSourcePlatformInfo = platforms[p];
        const src: LXUserApiSourceInfo | undefined = api.sources[info.source];
        if (src === undefined || src.qualitys.length === 0) {
          continue;
        }
        // ② 从**标注的最高音质**开始逐级往下测，命中一档就停（这就是"实际可用最高音质"）
        // ★ 用户 2026-10-28：测试**从全局最高音质开始**往下测，不再以脚本声明为准
        //   （拓展音质不是原版洛雪定义，声明值常偏低，按声明测会把本来能播的高档位漏掉）。
        //   顺序：QUALITY_CHAIN 原序（master → atmos_plus → atmos → hires → flac24bit → flac → 320k → 128k），
        //   命中一档即停；最多试 PROBE_MAX_TIERS 档，避免一次点按发太多请求。
        const qualities: string[] = [];
        for (let qi: number = 0; qi < QUALITY_CHAIN.length && qualities.length < PROBE_MAX_TIERS; qi++) {
          if (QUALITY_CHAIN[qi].length > 0) {
            qualities.push(QUALITY_CHAIN[qi]);
          }
        }
        for (let q: number = 0; q < qualities.length; q++) {
          try {
            total++;
            const r = await probeBySample(info.source, qualities[q], api.id);
            if (r !== undefined && r.ok) {
              passed++;
              // 命中最高可用档即停，避免继续往下测
              break;
            }
            if (r !== undefined) {
              console.info('[RzdQualityProbe] ' + api.name + ' ' + info.source + '/' + qualities[q] +
                ' → ' + (r.ok ? '已验证' : ('未通过:' + r.detail)));
            }
          } catch (err) {
            console.info('[RzdQualityProbe] probe threw for ' + info.source);
          }
        }
      }
    }
    // ③ 探完刷新一次列表（换数组引用）⇒ 平台 ToolTip 立刻能读到「已验证 / 未通过」
    this.lxApiList = lxSourceManager.getApiList().slice();
    console.info('[RzdQualityProbe] probe round finished, list refreshed');
    this.toast('测试完成：' + passed + '/' + total + ' 通过');
  }

  private lxPlatformsOf(api: LXUserApiInfo): LXSourcePlatformInfo[] {
    const declared: LXSourcePlatformInfo[] = lxDeclaredPlatformsOf(api);
    // ★ 2026-10-30：音源管理二级页原来只用持久化快照（可能少平台，例如 5 个而引擎上报 6 个）。
    //   当前引擎脚本改为「引擎实时 sources 优先」，与 SourceManagerList 同一套口径。
    if (api.id === (AppStorage.get<string>('lxEngineScriptId') ?? '')) {
      const json: string = AppStorage.get<string>('lxEngineSources') ?? '';
      // ★ 2026-10-30：把引擎上报的**原始 key**打出来（判断第 6 个平台到底叫什么）
      if (json.length > 2) {
        try {
          const live: LXSourcePlatformInfo[] =
            lxDeclaredPlatforms(JSON.parse(json) as Record<string, LXUserApiSourceInfo>);
          appendPlayLog('[RzdSource] persisted=' + declared.length + ' engine=' + live.length +
            ' labels=' + live.map((it: LXSourcePlatformInfo) => it.source).join(','));
          if (live.length > declared.length) {
            return live;
          }
        } catch (err) {
          appendPlayLog('[RzdSource] live parse failed');
        }
      }
    }
    
    return declared;
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

  /** @returns 当前平台是否支持"用登录状态获取推荐"（只有 QQ / 酷狗 / 网易 有 provider 实现）。 */
  private accountRecSupported(): boolean {
    return this.homeSource === 'qq' || this.homeSource === 'kg' || this.homeSource === 'wy';
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
    // 摘除锁定态监听（传注册时的同一引用，见 onDesktopLyricLockChange 的说明）。
    MediaService.getInstance().removeDesktopLyricLockListener(this.onDesktopLyricLockChange);
  }

  private selectLXSource(apiId: string): void {
    // ★ 2026-10-29（用户：选中汽水音源后平台仍显示「未检测」）：选择后重新读一次音源列表，
    //   让它带上引擎 init 回写的 sources（getApiList 有缓存，不重读就一直是旧快照）。
    this.lxApiList = lxSourceManager.getApiList().slice();
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

  /** 版本比对：脚本自带 version 与已保存版本一致即视为最新（真正的远端比对在 A4 之后接）。 */
  private async checkSourceUpdateRemote(api: LXUserApiInfo): Promise<void> {
    // ① 只走官方：读引擎上报的 updateAlert，不再自研请求
    const info: SourceUpdateInfo = readOfficialUpdateAlert();
    // ★ 2026-10-29（用户：引擎日志有"更新提示"，点检查更新没反应）：把卡片与 alert 一次打全
    appendPlayLog('[RzdSourceUpdate] card=' + api.name + ' ver=' + api.version +
      ' hasUpdate=' + info.hasUpdate + ' msg=' + info.message +
      ' url=' + info.updateUrl + ' err=' + info.error);
    if (info.hasUpdate) {
      this.getUIContext().getPromptAction().showDialog({
        title: '发现新版本',
        message: (info.message.length > 0 ? info.message : '有新版本可用') +
          (info.updateUrl.length > 0 ? ('\n' + info.updateUrl) : ''),
        buttons: [
          { text: '取消', color: '#666666' },
          { text: '前往更新', color: this.themeState.color }
        ]
      }).then((result) => {
        if (result.index === 1 && info.updateUrl.length > 0) {
          // ★ 2026-10-30（用户）：更新链接是网页（kdocs），不下载、直接跳浏览器
          this.openInBrowser(info.updateUrl, '音源更新');
        }
      });
      return;
    }
    // ① 没有更新就**静默**（只在日志里留痕）
    appendPlayLog('[RzdSourceUpdate] ' + api.name + ' no update: ' + info.error);
  }

  /** 用系统浏览器打开外部链接（更新页/主页这类非脚本链接走这里，避免把网页当脚本导入）。 */
  private openInBrowser(url: string, label: string): void {
    if (url.length === 0 || !/^https?:\/\//.test(url)) {
      this.toast('链接无效');
      return;
    }
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      };
      ctx.startAbility(want);
      appendPlayLog('[RzdUpdate] open browser url=' + url.substring(0, 80));
    } catch (err) {
      this.toast('无法打开浏览器：' + ((err as Error).message ?? ''));
    }
  }

  private checkSourceUpdate(api: LXUserApiInfo): void {
    const current: string = api.version.length > 0 ? api.version : '未知';
    this.getUIContext().getPromptAction().showToast({
      message: '当前版本 ' + current + '（最新）',
      duration: 2000
    });
    appendPlayLog('[RzdSourceUpdate] ' + api.name + ' version=' + current);
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
      // ★ 2026-10-30（按用户要求回退内容校验）：这里恢复原行为，不再因"像网页"而拦截。
      //   「立即更新」已改为跳浏览器，「下载并导入」这条路只服务真正的脚本链接。
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

  /** 检查更新命中后用它的 updateUrl 直接替换该音源。 */
  private async importLXSourceFromUrl(url: string): Promise<void> {
    if (url.length === 0 || !/^https?:\/\//.test(url)) {
      this.toast('更新链接无效');
      return;
    }
    const httpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: LX_ONLINE_IMPORT_TIMEOUT,
        readTimeout: LX_ONLINE_IMPORT_TIMEOUT,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200 || typeof resp.result !== 'string') {
        this.toast('新版本下载失败');
        return;
      }
      const imported: LXApiImportResult = lxSourceManager.importApi(resp.result as string);
      this.refresh();
      this.toast(imported.ok ? '已更新：' + imported.message : '更新失败：' + imported.message);
      appendPlayLog('[RzdSourceUpdate] import from ' + url + ' ok=' + imported.ok);
    } catch (err) {
      this.toast('更新失败，请检查网络');
    } finally {
      httpRequest.destroy();
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

  /** 保存位置选中项：0 手动选择 / 1 Download 目录 / 2 自定义目录（已授权即选中）。 */
  /**
   * 选图标：用 `LayeredDrawableDescriptor` 现场合成（前景+背景），**立即生效、无需重启**。
   * 参照官方《分层图标》+ `js-apis-arkui-drawabledescriptor`：
   *   `new LayeredDrawableDescriptor(foreground, background)` → 直接给 `Image()` 用。
   * 说明：桌面图标由包内 `AppScope/resources/base/media/app_layered_image.json` 决定，
   *   改它需要重新打包；应用内展示（这里）是运行时生效的。
   */
  private pickIconVariant(v: IconVariant): void {
    this.iconVariant = v.value;
    MusicStoreService.getInstance().setAppIconVariant(v.value);
    this.buildLayeredIcon(v);
    // ★ API 26：真正切换**桌面图标** —— bundleManager.setAlternateIcon(name)；
    //   name 必须命中 app.json5 的 alternateIcons[].name；传空串 = 恢复默认图标。
    //   日志关键字：`RzdAltIcon`
    try {
      bundleManager.setAlternateIcon(v.value === 'default' ? '' : v.value)
        .then((): void => {
          console.info('[RzdAltIcon] set ok name=' + v.value);
        })
        .catch((err: BusinessError): void => {
          console.info('[RzdAltIcon] set failed name=' + v.value + ' code=' + err.code + ' msg=' + err.message);
        });
    } catch (error) {
      console.info('[RzdAltIcon] set threw: ' + JSON.stringify(error).substring(0, 80));
    }
    this.getUIContext().getPromptAction().showToast({
      message: '已应用图标：' + v.label,
      duration: 1500
    });
  }

  /** 用资源 id 取 DrawableDescriptor 并合成分层图标。 */
  private buildLayeredIcon(v: IconVariant): void {
    try {
      const ctx = this.getUIContext().getHostContext();
      const res = ctx?.resourceManager;
      if (res === undefined) {
        return;
      }
      const fg = res.getDrawableDescriptor(v.foreground.id) as DrawableDescriptor;
      const bg = res.getDrawableDescriptor(v.bgRes.id) as DrawableDescriptor;
      if (fg === undefined || bg === undefined) {
        return;
      }
      this.appliedIcon = new LayeredDrawableDescriptor(fg, bg);
    } catch (error) {
      console.info('[RzdIcon] layered descriptor failed: ' + JSON.stringify(error).substring(0, 80));
    }
  }

  private saveLocationIndex(): number {
    if (MusicStoreService.getInstance().getDownloadDirUri().length > 0) {
      return 2;
    }
    return this.saveToDownloadDir ? 1 : 0;
  }

  /** 点了「自定义目录」：弹一次目录选择器，授权后所有下载都用它。 */
  private async pickCustomDir(): Promise<void> {
    const uri: string = await DownloadService.getInstance().pickCustomDownloadDir();
    if (uri.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '未选择目录', duration: 1500 });
      return;
    }
    this.saveToDownloadDir = false;
    MusicStoreService.getInstance().setDownloadSaveMode('download');
    this.getUIContext().getPromptAction().showToast({ message: '已授权下载目录，之后下载都存这里', duration: 2000 });
  }

  private selectSaveLocationIndex(index: number): void {
    if (index === 2) {
      void this.pickCustomDir();
      return;
    }
    this.selectSaveLocation(index === 1);
  }
  private selectSaveLocation(download: boolean): void {
    this.saveToDownloadDir = download;
    // ★ 2026-10-20：开关关掉 = 存**应用私有目录**（默认，下载完直接出现在本地音乐里），sk 不再用
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
      // ★ 2026-10-29（用户）：二级设置页滚动要有回弹
      .edgeEffect(EdgeEffect.Spring)
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

          this.SubTitle('启动应用自动开始播放')
          this.CapsuleSelector(this.onOffOptions, this.autoPlayOnLaunch ? 0 : 1,
            (index: number) => {
              const autoPlay: boolean = index === 0;
              this.autoPlayOnLaunch = autoPlay;
              MusicStoreService.getInstance().setAutoPlayOnLaunch(autoPlay);
            })

          this.SubTitle('USB 独占输出')
          // ★ 开关常显（无 DAC 也能看到）；下面的状态行与两个按钮只在"开启"时出现
          this.CapsuleSelector(this.onOffOptions, this.usbExclusive ? 0 : 1,
            (index: number) => {
              const enabled: boolean = index === 0;
              this.usbExclusive = enabled;
              void MediaService.getInstance().applyUsbExclusive(enabled);
            })
          if (this.usbExclusive) {
            Text(this.usbStatusText())
              .fontSize(12)
              .fontColor($r('app.color.font_tertiary'))
              .width('100%')
              .margin({ top: 6 })
            Row({ space: 10 }) {
              Button('重新扫描')
                .height(34)
                .fontSize(13)
                .backgroundColor($r('app.color.card_background'))
                .fontColor($r('app.color.font_primary'))
                .onClick((): void => {
                  void UsbAudioService.getInstance().refresh();
                })
              Button('USB 诊断')
                .height(34)
                .fontSize(13)
                .backgroundColor($r('app.color.card_background'))
                .fontColor($r('app.color.font_primary'))
                .onClick((): void => {
                  void MediaService.getInstance().diagnoseUsb();
                })
            }
            .margin({ top: 6 })
          }
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

          // ④ 2026-10-31（用户：以后都不走模糊）：「歌词页模糊效果」设置项已移除


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
      // ★ 2026-10-29（用户）：二级设置页滚动要有回弹
      .edgeEffect(EdgeEffect.Spring)
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
            this.saveLocationIndex(),
            (index: number) => {
              this.selectSaveLocationIndex(index);
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
      // ★ 2026-10-29（用户）：二级设置页滚动要有回弹
      .edgeEffect(EdgeEffect.Spring)
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
        // ★ 自定义软件图标：横向卡片，左右滑动选图标（与上面的颜色卡同款）
        Column() {
          this.SubTitle('应用图标')

          Scroll() {
            Row({ space: 14 }) {
              ForEach(this.iconVariants, (v: IconVariant) => {
                Column({ space: 6 }) {
                  Image(v.foreground)
                    .width(56)
                    .height(56)
                    .borderRadius(14)
                    .backgroundColor(v.background)
                    .border({
                      width: this.iconVariant === v.value ? 2 : 0,
                      color: this.themeState.color,
                      radius: 16
                    })
                  Text(v.label)
                    .fontSize(11)
                    .fontColor(this.iconVariant === v.value ? this.themeState.color : $r('sys.color.font_tertiary'))
                }
                .onClick((): void => {
                  this.pickIconVariant(v);
                })
              }, (v: IconVariant) => v.value)
            }
            .padding({ left: 2, right: 2 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
      // ★ 2026-10-29（用户）：二级设置页滚动要有回弹
      .edgeEffect(EdgeEffect.Spring)
          .width('100%')
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
        // ★ 自定义 Tab 栏（放最下面）
        this.TabBarCustomSection()
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
      // ★ 2026-10-29（用户）：二级设置页滚动要有回弹
      .edgeEffect(EdgeEffect.Spring)
      // ★ 2026-10-31：自定义 Tab 栏（放最下面，只允许调整「现在就听」「回响」）
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
      return '';
    }
    if (this.desktopLyricLocked) {
      // 锁定时悬浮窗自身不再响应，用户只能靠这个提示找到下方的解锁按钮（或播放页顶栏入口）。
      return '桌面歌词已锁定：位置固定、不再响应拖动和设置。需要调整时点下方「解锁桌面歌词」。';
    }
    return '';
  }

  /** 其它设置弹窗：添加位置 / 首页来源+登录推荐 / 同步设置入口，拆为三张卡片。 */
  @Builder
  private OtherSheet() {    Scroll(this.pageScroller) {
      Column({ space: 12 }) {
        Blank().height(this.panelTopInset())
        CoverCacheSettingsCard()
        // 动态封面：歌手 / 专辑 / 歌单页的大封面在联网时播放 Apple Music 的 motion artwork
        // （规格见 docs/apple-motion-cover.md；解析与缓存都在 MotionCoverService，默认开）。
        Column() {
          this.SubTitle('屏幕方向')
          this.CapsuleSelector(['自动', '竖屏', '横屏'],
            this.screenOrientation === 'portrait' ? 1 : (this.screenOrientation === 'landscape' ? 2 : 0),
            (index: number) => {
              const mode: string = index === 1 ? 'portrait' : (index === 2 ? 'landscape' : 'auto');
              this.screenOrientation = mode;
              const ctx = getContext(this) as common.UIAbilityContext;
              void setScreenOrientation(ctx, mode);
            })
          this.SubTitle('动态封面')
          this.CapsuleSelector(this.onOffOptions, this.motionCover ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.motionCover = isOn;
              MusicStoreService.getInstance().setMotionCoverEnabled(isOn);
              const state = AppStorageV2.connect(MotionCoverState, AppStorageKeys.MOTION_COVER_STATE,
                () => new MotionCoverState());
              if (state !== undefined) {
                state.enabled = isOn;
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.card_background'))
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

          // ★ 2026-10-24（甲方第 ⑥ 条）：「如果选择的不是 QQ 酷狗网易，就不显示使用登录状态获取推荐的选项」。
          //   酷我 / 咪咕没有 provider 实现 ⇒ 整项隐藏，并留一行说明，免得用户以为设置丢了。
          if (this.accountRecSupported()) {
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
          } else {
            Text('通过登录状态获取推荐暂时仅支持QQ、酷狗、网易')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
              .width('100%')
              .margin({ top: 8 })
              .maxLines(2)
          }
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
              if (isOn) {
                // ▼ 开桌面歌词顺带申请通知授权（用户手势时机，系统弹授权框；已授权则静默）：
                //   悬浮窗被锁定后应用会在通知栏发一条带「解锁歌词」按钮的通知
                //   （见 MediaService.publishUnlockNotification），没授权这条通知发不出来。
                const notifCtx = getContext(this) as common.UIAbilityContext;
                void notificationManager.requestEnableNotification(notifCtx).catch((): void => {});
              }
            })
          Text(this.desktopLyricHint())
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .padding({ top: 6 })
          // ▼ 桌面歌词被锁定时的第二入口（第一入口在播放页顶栏）：悬浮窗自身已不响应，
          //   只有应用侧调 setDesktopLyricState({isLocked:false}) 能解开。
          //   显隐 = 开关开着 && 处于锁定态；解锁失败（无会话等）按钮保持原状。
          if (this.desktopLyric && this.desktopLyricLocked) {
            Button('解锁桌面歌词')
              .height(34)
              .fontSize(13)
              .backgroundColor($r('app.color.card_background'))
              .fontColor($r('app.color.font_primary'))
              .margin({ top: 6 })
              .onClick((): void => {
                // 成功才收按钮；失败留在原地等用户重试（Toast/日志由 MediaService 打）。
                void MediaService.getInstance().unlockDesktopLyric().then((ok: boolean): void => {
                  if (ok) {
                    this.desktopLyricLocked = false;
                  }
                });
              })
          }
        // 车载蓝牙歌词（移植自 lxmusic-harmony）：AVMetadata.singleLyricText 推当前句
          this.SubTitle('车载蓝牙歌词')
          this.CapsuleSelector(this.onOffOptions, this.bluetoothLyric ? 0 : 1,
            (index: number) => {
              const isOn: boolean = index === 0;
              this.bluetoothLyric = isOn;
              MusicStoreService.getInstance().setBluetoothLyric(isOn);
              MediaService.getInstance().refreshBluetoothLyric();
            })
          Text('')
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
      // ★ 2026-10-29（用户）：二级设置页滚动要有回弹
      .edgeEffect(EdgeEffect.Spring)
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
      // ★ 2026-10-29（用户）：二级设置页滚动要有回弹
      .edgeEffect(EdgeEffect.Spring)
  }


  private isSourceInOrder(apiId: string): boolean {
    return this.sourceOrderIds.indexOf(apiId) >= 0;
  }

  private persistSourceOrder(): void {
    MusicStoreService.getInstance().setSourceScriptOrder(this.sourceOrderIds);
  }

  /** 长按拖动排序：把 dragId 移到 targetId 的位置（用于 `onDrop`）。 */
  private moveSourceTo(dragId: string, targetId: string): void {
    if (dragId.length === 0 || dragId === targetId) {
      return;
    }
    const from: number = this.sourceOrderIds.indexOf(dragId);
    const to: number = this.sourceOrderIds.indexOf(targetId);
    if (from < 0 || to < 0) {
      return;
    }
    const next: string[] = [];
    for (let i: number = 0; i < this.sourceOrderIds.length; i++) {
      next.push(this.sourceOrderIds[i]);
    }
    next.splice(from, 1);
    next.splice(to, 0, dragId);
    this.sourceOrderIds = next;
    this.persistSourceOrder();
    this.dragSourceId = '';
    appendPlayLog('[RzdSourceOrder] move ' + dragId + ' -> ' + targetId + ' = ' + next.join(' > '));
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

          // 统一实现：单列勾选 + 整卡拖动 + 左滑（检查更新 / 删除）
          SourceManagerList({
            apis: this.orderedApiListForUi(),
            orderIds: this.sourceOrderIds,
            activeId: this.activeSource,
            accentColor: this.themeState.color,
            draggableEnabled: this.engineReady,
            onToggle: (apiId: string): void => {
              this.toggleSourceInOrder(apiId);
            },
            onSelect: (apiId: string): void => {
              this.selectLXSource(apiId);
            },
            onDelete: (apiId: string): void => {
              this.deleteLXSource(apiId);
            },
            onCheckUpdate: (api: LXUserApiInfo): void => {
              void this.checkSourceUpdateRemote(api);
            },
            onProbe: (apiId: string): void => {
              void this.runQualityProbe(apiId);
            },
            onMove: (dragId: string, targetId: string): void => {
              this.moveSourceTo(dragId, targetId);
            }
          })

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
      // ★ 2026-10-29（用户）：二级设置页滚动要有回弹
      .edgeEffect(EdgeEffect.Spring)
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
