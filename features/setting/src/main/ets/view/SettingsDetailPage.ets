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

import { appendPlayLog, setScreenOrientation, UsbAudioService, UsbAudioState, TabBarConfigModel } from 'musicbasic';
import { bundleManager } from '@kit.AbilityKit';
import { DrawableDescriptor, LayeredDrawableDescriptor } from '@kit.ArkUI';
import { guardPlayerBack } from 'musicbasic';
import { AppStorageV2, CapsuleSegmentButtonV2, ColorMetrics, SegmentButtonV2Items } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, ConfigurationConstant, Want } from '@kit.AbilityKit';

import { http } from '@kit.NetworkKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { CoverCacheSettingsCard, AmbientState, AppStorageKeys, RouterUrlConstants, HomeSourceState, LyricCenterState, LyricFontSizeState, LyricFpsState, MotionCoverState, MusicStoreService, notifyHomeSourceRefresh, PageTopInsetHelper, ShowMiniLyricState, ThemeState, TitleBarConstants, UseAccountRecState, buildTitleMaterial, immersiveFromLevel } from 'musicbasic';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';
import { DownloadService, LXUserApiInfo, LXSourcePlatformInfo, lxDeclaredPlatforms, lxDeclaredPlatformsOf, lxSourceManager, MediaService, lxSourceLabel, LX_PLATFORM_ORDER, normalizePlatformId, musicFreeSubscriptionLabel, quickJsSelfTest, runScriptInQuickJs, QuickJsRunResult, runScriptAndInvoke, QuickJsInvokeResult, lxLastRequestData, runQuickJsOneClickCheck } from 'player';
import type { LXApiImportResult } from 'player';
import { importMusicFreeSubscriptionText, importSourceScriptAuto, parseMusicFreeSubscription, updateSubscription, backfillMusicFreePlatforms } from 'player';
import type { MfImportReport, MfSubscriptionEntry, MfSubscriptionInfo } from 'player';
import { probeBySample, QUALITY_CHAIN } from 'player';
import type { LXUserApiSourceInfo } from 'player';
import { SyncSettingsPanel } from 'sync';
import { AccountManageSheet } from '../account/AccountManageSheet';
import { PlatformMusicPage } from '../account/PlatformMusicPage';
import { DownloadManagerSection } from './DownloadManagerSection';
import { importSourceFiles } from '../util/SourceFileImport';

import { CustomColorSheetContent } from './CustomColorSheetContent';
import { CapsuleSegmentedSelector } from './CapsuleSegmentedSelector';

import { SourceManagerList } from './SourceManagerList';
import { PlatformManagerSheet } from './PlatformManagerSheet';
import { readOfficialUpdateAlert, SourceUpdateInfo } from '../util/SourceUpdate';
import { probeScriptUpdate, SourceUpdateProbeResult } from 'player';
import { LengthMetrics } from '@kit.ArkUI';

/** 单次「测试音源」对每个平台最多试几档（从最高往下，命中即停）。 */
const PROBE_MAX_TIERS: number = 5;
const LX_ONLINE_IMPORT_MAX_BYTES: number = 9 * 1024 * 1024;
const LX_ONLINE_IMPORT_TIMEOUT: number = 15000;

/** 源显示名（与音源列表同一口径）：备注 > 插件自报平台名 > 导入时的名称。 */
function displayNameOfApi(api: LXUserApiInfo): string {
  const rawRemark: string | undefined = api.remark;
  const remark: string = rawRemark !== undefined ? rawRemark.trim() : '';
  if (remark.length > 0) {
    return remark;
  }
  const platform: string = api.platform !== undefined ? api.platform.trim() : '';
  if (platform.length > 0) {
    return platform;
  }
  return api.name;
}

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
  /** 已导入的 MusicFree 订阅（源管理按它分组，整包可更新）。 */
  @Local subscriptions: MfSubscriptionInfo[] = [];
  @Local sourceOrderIds: string[] = [];
  /** 音源管理列表的行顺序（`sub:<订阅id>` / `api:<源id>`），拖动排序后持久化。 */
  @Local sourceRowOrder: string[] = [];
  /**
   * 音源数据的版本号：每次 `refresh()` 自增。
   *
   * ★ 2026-11-09（用户：「修改备注后列表中名称没刷新，得重进页面」）：
   *   备注改的是**对象字段**，`apis` / `subscriptions` 数组里装的还是同一批对象引用，
   *   V2 对这些 @Param 可能判定"没变"而不下发。显式传一个版本号，子列表无条件重建。
   */
  @Local sourceDataVersion: number = 0;
  /** 备注编辑弹层的目标（空 = 未打开）。 */
  @Local remarkTargetId: string = '';
  @Local remarkTargetName: string = '';
  @Local remarkDraft: string = '';
  /** 订阅「编辑」时先选的订阅 id（空 = 没打开选择面板）。 */
  @Local remarkPickSubId: string = '';
  /** 订阅（= 音源本身）备注编辑的目标与草稿。 */
  @Local subRemarkTargetId: string = '';
  @Local subRemarkTargetName: string = '';
  @Local subRemarkDraft: string = '';
  /** 「修改支持的平台」弹层的目标与草稿（LX 脚本用）。 */
  @Local platformTargetId: string = '';
  @Local platformDraft: string[] = [];
  /** 音源管理右上角菜单（导入 / 平台管理）的展开态。 */
  @Local showSourceMenu: boolean = false;
  /**
   * 音源管理相关弹层：0 = 不显示，1 = 平台管理，3 = 在线导入，
   * 4 = MusicFree 源备注，5 = LX 脚本支持平台。
   * 一个组件只能挂一个 `bindSheet`，所以用枚举分工（与 PlaylistBatchActionBar 同一写法）。
   */
  @Local sourceSheet: number = 0;
  /** 长按拖动排序：当前被拖动的音源 id。 */
  @Local activeSource: string = '';
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
  /** 桌面歌词悬浮窗是否被用户锁定（解锁入口只保留通知栏，这里只用于提示文案）。 */
  @Local desktopLyricLocked: boolean = false;
  /** QuickJS 自检结果（设置页「音源引擎」卡片显示；空串 = 本次会话还没跑过）。 */
  @Local quickJsState: string = '';
  /** 音源运行时引擎：auto（按能力探测，默认，等同 WebView）/ webview / quickjs */
  @Local lxEngineMode: string = 'auto';
  /** QuickJS 跑真脚本的结果（同上） */
  @Local quickJsScriptState: string = '';
  /** 是否正在跑（防重复点） */
  @Local quickJsRunning: boolean = false;
  /**
   * MediaService 锁状态回调（aboutToAppear 注册、aboutToDisappear 摘除，两者必须传同一引用）。
   *
   * ★ 2026-11-15：移植自 GitHub 已合并的 PR #9 / #11 的净效果 ——
   *   锁定后悬浮窗自身不再响应，解锁入口**只有通知栏那条通知**（用户 2026-11-12 定调），
   *   所以这里只做提示，不再放应用内解锁按钮。
   */
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
  /**
   * 首页来源的**显示标签**，与下面的 `homeSourceValues` 一一对应（存的是 id，不是标签）。
   * ⚠️ 不要用 `platformLabel()` 生成：这里的 QQ 用的是 `'qq'`（历史值），
   *   而平台 id 表里 QQ 是 `'tx'`，套用会显示成 "qq"。
   */
  private readonly homeSourceOptions: string[] = ['QQ', '酷狗', '网易云', '酷我', '咪咕', '汽水'];
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
      // 持久化配置解析失败：退回默认值（不影响启动）
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
    AppStorage.setOrCreate(AppStorageKeys.TAB_BAR_CONFIG, json);
    appendPlayLog('[RzdTabConfig] save ' + json);
  }

  /** 当前底栏顺序预览（首页/我的固定，中间两项按配置）。 */
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
      const outParams: string = AppStorage.get<string>(AppStorageKeys.USB_OUT_PARAMS) ?? '';
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
    // 音源运行时引擎（auto / webview / quickjs）
    this.lxEngineMode = MusicStoreService.getInstance().getLxEngineMode();
    // 桌面歌词锁定态：先同步一次（可能在别处已经锁了），再注册变化监听
    this.desktopLyricLocked = MediaService.getInstance().isDesktopLyricLocked();
    MediaService.getInstance().addDesktopLyricLockListener(this.onDesktopLyricLockChange);
    // USB 独占：设置页打开时轮询设备（本 SDK 无 attach/detach 事件）
    UsbAudioService.getInstance().startPolling();
    this.refresh();
    this.startEnginePolling();
    // 音源管理：元力系插件平台名要跑一遍才知道（旧数据还是「元力音源」），后台补一轮
    if (this.sheetIndex === 5) {
      void backfillMusicFreePlatforms(this.lxApiList).then((count: number): void => {
        if (count > 0) {
          this.refresh();
        }
      });
    }
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

  private getDetailTitleBar(): HdsNavigationTitleBarOptions {
    /**
     * ★ 2026-11-08（用户：「不要两个页面啊…直接放进音源管理页的右上角，
     *   顺带把导入音源也放进那里」）：
     *   音源管理页的「导入音源 / 平台管理」收进标题栏右上角**一个菜单**。
     *   HDS 顶栏图标槽位只能给 action，不能挂 bindMenu —— 所以这里只负责把菜单打开，
     *   菜单本体绑在内容区右上角的锚点上（与 NowPlayingFeedPage 的 FeedModeMenu 同一写法）。
     */
    const menus: HdsNavigationMenuItemOptions[] = [];
    if (this.sheetIndex === 5) {
      menus.push({
        content: {
          label: '音源管理操作',
          icon: $r('sys.symbol.more'),
          isEnabled: true,
          action: (): void => {
            this.showSourceMenu = !this.showSourceMenu;
          }
        }
      });
    }
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
        menu: { value: menus },
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

  /**
   * MusicFree 插件的平台名是**异步**回填的（要等隐藏 WebView 把插件跑起来），
   * 导入那一刻列表里还是订阅给的名字。这里补两次延时刷新，让名字/平台标签自动变准。
   * （组件是 `@ComponentV2`，没有 `@StorageLink`/`@Watch`，所以不用数据监听而用定时刷新。）
   */
  private schedulePlatformRefresh(): void {
    setTimeout((): void => {
      this.refresh();
    }, 3000);
    setTimeout((): void => {
      this.refresh();
    }, 9000);
  }

  private refresh(): void {
    this.lxApiList = lxSourceManager.getApiList();
    this.subscriptions = lxSourceManager.getSubscriptions();
    // 备注只改对象字段（数组引用不变），显式递增版本号让列表无条件重建
    this.sourceDataVersion++;
    // 先把「订阅只启用一半」的脏数据修掉，再读启用列表 —— 否则勾选态与平台管理
    // 的「源已停用」会各说各话（用户 2026-11-09：「我源启用了啊」）。
    lxSourceManager.repairSourceEnableState();
    this.sourceOrderIds = MusicStoreService.getInstance().getSourceScriptOrder();
    this.sourceRowOrder = MusicStoreService.getInstance().getSourceRowOrder();
    if (this.sourceOrderIds.length === 0 && !MusicStoreService.getInstance().hasSourceScriptOrderConfig()) {
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
    this.activeSource = AppStorage.get<string>(AppStorageKeys.LX_ACTIVE_SOURCE) ?? '';
    this.engineSources = AppStorage.get<string>(AppStorageKeys.LX_ENGINE_SOURCES) ?? '{}';
    this.ambientLevel = MusicStoreService.getInstance().getAmbientLevel();
    this.showMiniLyric = MusicStoreService.getInstance().getShowMiniLyric();
    this.desktopLyric = MusicStoreService.getInstance().getDesktopLyric();
    this.bluetoothLyric = MusicStoreService.getInstance().getBluetoothLyric();
    // 会话是「第一次推歌」时才建的，所以这里主动探一次支持性（否则设置页只能说「未知」）
    void MediaService.getInstance().probeDesktopLyricSupport().then((supported: boolean): void => {
      this.desktopLyricSupport = supported;
    });
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
    this.lastError = AppStorage.get<string>(AppStorageKeys.LX_LAST_ERROR) ?? '';
    const persistentLog: string = MusicStoreService.getInstance().getRuntimeDiagnostics();
    this.playLog = (AppStorage.get<string>(AppStorageKeys.LX_PLAY_LOG) ?? '') +
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
    if (api.id === (AppStorage.get<string>(AppStorageKeys.LX_ENGINE_SCRIPT_ID) ?? '')) {
      const json: string = AppStorage.get<string>(AppStorageKeys.LX_ENGINE_SOURCES) ?? '';
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
      if (this.activeSource.length === 0 || AppStorage.get<boolean>(AppStorageKeys.LX_ENGINE_READY) === true) {
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
    // 摘除锁状态监听（传注册时的同一引用，见 onDesktopLyricLockChange）
    MediaService.getInstance().removeDesktopLyricLockListener(this.onDesktopLyricLockChange);
  }

  /**
   * 「用 QuickJS 跑一遍当前音源脚本」——双引擎 Phase 4 的比较入口。
   *
   * 为什么放这儿：用户 2026-11-15 明确「关键是追求效率，不是完全独立」。
   * 要判断该不该把某个脚本切到 QuickJS，就得先量出**同一支脚本在两种引擎下的耗时**。
   * 这条路径不碰 WebView，也不影响正在播的歌。
   */
  private async runQuickJsScriptProbe(): Promise<void> {
    if (this.quickJsRunning) {
      return;
    }
    this.quickJsRunning = true;
    this.quickJsScriptState = '正在跑…';
    try {
      const activeId: string = this.activeSource;
      if (activeId.length === 0 || activeId.indexOf('mfplat:') === 0) {
        this.quickJsScriptState = '当前音源不是 LX 脚本（MusicFree 插件走另一条引擎）';
        return;
      }
      const script: string = await lxSourceManager.getScript(activeId);
      if (script.length === 0) {
        this.quickJsScriptState = '读不到脚本原文（可能被 gz 压缩或未下载完整）';
        return;
      }
      const r: QuickJsRunResult = await runScriptInQuickJs(script, 4000);
      this.quickJsScriptState = r.ok ?
        ('成功 · 平台 ' + r.platforms.join('/') + ' · 宿主调用 ' + r.hostCalls + ' 次 · ' + r.elapsedMs + 'ms') :
        ('失败 · ' + r.error + '（' + r.elapsedMs + 'ms）');
    } catch (e) {
      this.quickJsScriptState = '异常：' + JSON.stringify(e).substring(0, 120);
    } finally {
      this.quickJsRunning = false;
    }
  }

  /**
   * 「用 QuickJS 重放上一次取址请求」—— 双引擎最关键的比较。
   *
   * 为什么是"重放"：脚本初始化（`inited`）只是热身；真正决定播放快慢的是
   * `lx.on('request', …)` 里那条取址逻辑。这里把 WebView 侧**最近一次真跑过**的
   * `{source, action, info}` 原样丢给 QuickJS，输入完全一致，耗时才有可比性。
   */
  /** 一键测：自检 + 脚本初始化 + 重放取址 + 与 WebView 对照（见 player 侧实现） */
  private async runOneClickCheck(): Promise<void> {
    if (this.quickJsRunning) {
      return;
    }
    this.quickJsRunning = true;
    this.quickJsScriptState = '正在测…（约 1~2 秒）';
    try {
      this.quickJsScriptState = await runQuickJsOneClickCheck();
    } catch (e) {
      this.quickJsScriptState = '一键测异常：' + JSON.stringify(e).substring(0, 140);
    } finally {
      this.quickJsRunning = false;
    }
  }

  private async replayLastRequestInQuickJs(): Promise<void> {
    if (this.quickJsRunning) {
      return;
    }
    this.quickJsRunning = true;
    this.quickJsScriptState = '正在重放…';
    try {
      if (lxLastRequestData === undefined) {
        this.quickJsScriptState = '还没有可取址的请求 —— 先在 WebView 下播一首（或等它预热完）再回来';
        return;
      }
      const payload: string = JSON.stringify(lxLastRequestData);
      const activeId: string = this.activeSource;
      const script: string = await lxSourceManager.getScript(activeId);
      if (script.length === 0) {
        this.quickJsScriptState = '读不到脚本原文';
        return;
      }
      const r: QuickJsInvokeResult = await runScriptAndInvoke(script, 'request', payload, 6000);
      this.quickJsScriptState = r.ok ?
        ('重放成功 · ' + r.elapsedMs + 'ms · 宿主调用 ' + r.hostCalls + ' 次 · ' +
          r.valueJson.substring(0, 80)) :
        ('重放失败 · ' + (r.error.length > 0 ? r.error : '未知') +
          (r.elapsedMs > 0 ? '（' + r.elapsedMs + 'ms）' : ''));
    } catch (e) {
      this.quickJsScriptState = '异常：' + JSON.stringify(e).substring(0, 120);
    } finally {
      this.quickJsRunning = false;
    }
  }

  private selectLXSource(apiId: string): void {
    // ★ 2026-10-29（用户：选中汽水音源后平台仍显示「未检测」）：选择后重新读一次音源列表，
    //   让它带上引擎 init 回写的 sources（getApiList 有缓存，不重读就一直是旧快照）。
    this.lxApiList = lxSourceManager.getApiList().slice();
    // ★ 用户 2026-10-11「音源勾选是不是有点问题」：圆点是「当前默认音源」而不是开关 ——
    //   原来点当前默认那一行会把它清成空字符串（`? ' : apiId`）⇒ 一圈圆点全是空心，看着像没选中。
    //   现在点击恒为「设为默认」，不再有「点一下取消默认」这种状态。
    const next: string = apiId;
    AppStorage.setOrCreate(AppStorageKeys.LX_ACTIVE_SOURCE, next);
    MusicStoreService.getInstance().setActiveSource(next);
    this.activeSource = next;
    this.startEnginePolling();
  }

  /** 版本比对：脚本自带 version 与已保存版本一致即视为最新（真正的远端比对在 A4 之后接）。 */
  private async checkSourceUpdateRemote(api: LXUserApiInfo): Promise<void> {
    // ① 只走官方：读引擎上报的 updateAlert，不再自研请求。
    //    ★ 2026-11-14：**必须按脚本 id 读**。以前读的是全局键，本次启动里第一个上报过
    //    告警的源会把对话框劫持给之后检查的所有源（甲方：「检查其它音源还是这个源的提示」）。
    const info: SourceUpdateInfo = readOfficialUpdateAlert(api.id);
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
    // ② 更新检查被应用拦截过：**如实说"查不了"**（不能假装已是最新，也不能借别的源的告警）。
    //    这是「有的源走的官方渠道，却不提示」的主因：星海那类脚本的版本检查 URL 命中
    //    `UPDATE_MANIFEST_PATTERNS`（如 `versionh2.php`），被应用强制置为失败以保住可用性，
    //    脚本的 checkUpdate 进 catch ⇒ 永远不上报 ⇒ 检查更新过去只能静默。
    if (info.blocked) {
      // ★ 2026-11-14：脚本的版本检查被拦了（为了"未更新也能用"），脚本因此不会上报告警。
      //   这里由应用**原样重放**那条被拦的 URL 拿真实结论 —— URL 是从脚本自己的请求里
      //   抓的（含 ?ver=…），不需要猜任何规则；且只在用户主动点「检查更新」时发。
      const probe: SourceUpdateProbeResult = await probeScriptUpdate(info.blockedUrl, api.version);
      appendPlayLog('[RzdSourceUpdate] ' + api.name + ' blocked probe ok=' + probe.ok +
        ' hasUpdate=' + probe.hasUpdate + ' err=' + probe.error);
      if (probe.hasUpdate) {
        this.getUIContext().getPromptAction().showDialog({
          title: '发现新版本',
          message: (probe.message.length > 0 ? probe.message : '有新版本可用') +
            (probe.updateUrl.length > 0 ? ('\n' + probe.updateUrl) : ''),
          buttons: [
            { text: '取消', color: '#666666' },
            { text: '前往更新', color: this.themeState.color }
          ]
        }).then((result) => {
          if (result.index === 1 && probe.updateUrl.length > 0) {
            this.openInBrowser(probe.updateUrl, '音源更新');
          }
        });
        return;
      }
      if (probe.ok) {
        // 接口有正常响应但没有更新地址：如实体贴服务端原话（星海这类返回「你已是最新版本」），
        // 没有原话就只说"未给出更新地址" —— 都不自称"已是最新"（那是我们的推断）。
        this.toast(probe.message.length > 0
          ? ('「' + api.name + '」' + probe.message)
          : ('「' + api.name + '」的更新接口未返回更新地址'));
        return;
      }
      // 连代打都失败：说清"查不了"以及原因，并留一个可手动打开的线索
      const canOpen: boolean = /^https?:\/\//.test(info.blockedUrl);
      this.getUIContext().getPromptAction().showDialog({
        title: '无法检查该音源的更新',
        message: '「' + api.name + '」的版本检查已被应用拦截（为了"未更新也能用"），' +
          '代办查询也没有成功。\n' +
          (probe.error.length > 0 ? ('原因：' + probe.error + '\n') : '') +
          (canOpen ? ('可手动打开它的检查地址：\n' + info.blockedUrl) : '请到音源作者的发布页确认。'),
        buttons: canOpen
          ? [{ text: '取消', color: '#666666' },
             { text: '打开检查地址', color: this.themeState.color }]
          : [{ text: '知道了', color: this.themeState.color }]
      }).then((result) => {
        if (canOpen && result.index === 1) {
          this.openInBrowser(info.blockedUrl, '音源更新检查');
        }
      });
      return;
    }
    // ③ 该源确实没有任何更新线索：静默（只在日志里留痕）
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

  private deleteLXSource(apiId: string): void {
    if (this.activeSource === apiId) {
      AppStorage.setOrCreate(AppStorageKeys.LX_ACTIVE_SOURCE, '');
      MusicStoreService.getInstance().setActiveSource('');
      this.activeSource = '';
    }
    if (this.sourceOrderIds.indexOf(apiId) >= 0) {
      this.toggleSourceInOrder(apiId);
    }
    lxSourceManager.removeApi(apiId);
    this.refresh();
  }

  /** 订阅地址 → 列表里显示的名字（主机名，避免全是「MusicFree 订阅」）。 */
  private subscriptionNameOf(url: string): string {
    const m: RegExpExecArray | null = /^https?:\/\/([^/]+)/i.exec(url.trim());
    if (m !== null && m[1].length > 0) {
      return m[1];
    }
    return 'MusicFree 订阅';
  }

  /** 订阅（音源本身）的展示名（备注 > 人类可读名 > 中性兜底，绝不显示裸域名）。 */
  private subLabelOf(sub: MfSubscriptionInfo): string {
    let ordinal: number = 1;
    for (let i: number = 0; i < this.subscriptions.length; i++) {
      if (this.subscriptions[i].id === sub.id) {
        ordinal = i + 1;
        break;
      }
    }
    return musicFreeSubscriptionLabel(sub, ordinal, this.subscriptions.length);
  }

  /** 更新整份 MusicFree 订阅（重新拉 url，逐个覆盖插件）。 */
  private async updateSubscriptionPack(sub: MfSubscriptionInfo): Promise<void> {
    if (sub.url.length === 0) {
      this.toast('这份订阅来自文件，请重新选择文件导入');
      return;
    }
    this.toast('正在更新「' + this.subLabelOf(sub) + '」…');
    try {
      const report: MfImportReport = await updateSubscription(sub.id);
      this.refresh();
      this.schedulePlatformRefresh();
      this.toast(report.ok ? ('已更新：' + report.message) : ('更新失败：' + report.message));
    } catch (err) {
      this.toast('更新失败：' + ((err as Error).message ?? '网络异常'));
    }
  }

  /** 删除整份订阅（含其下所有插件）。 */
  private confirmDeleteSubscription(sub: MfSubscriptionInfo): void {
    this.getUIContext().showAlertDialog({
      title: '删除订阅',
      message: '确定删除「' + this.subLabelOf(sub) + '」及其 ' + sub.apiIds.length.toString() + ' 个音源吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('sys.color.warning'),
        action: (): void => {
          const removed: number = lxSourceManager.removeSubscription(sub.id);
          // 被删插件可能还在播放默认源 / 备选链里：按**删除后**的真实列表清掉悬空 id
          const liveIds: string[] = [];
          const live: LXUserApiInfo[] = lxSourceManager.getApiList();
          for (let a: number = 0; a < live.length; a++) {
            liveIds.push(live[a].id);
          }
          const nextOrder: string[] = [];
          for (let i: number = 0; i < this.sourceOrderIds.length; i++) {
            if (liveIds.indexOf(this.sourceOrderIds[i]) >= 0) {
              nextOrder.push(this.sourceOrderIds[i]);
            }
          }
          if (nextOrder.length !== this.sourceOrderIds.length) {
            MusicStoreService.getInstance().setSourceScriptOrder(nextOrder);
          }
          if (this.activeSource.length > 0 && liveIds.indexOf(this.activeSource) < 0) {
            AppStorage.setOrCreate(AppStorageKeys.LX_ACTIVE_SOURCE, '');
            MusicStoreService.getInstance().setActiveSource('');
            this.activeSource = '';
          }
          this.refresh();
          this.schedulePlatformRefresh();
          this.toast('已删除 ' + removed.toString() + ' 个音源');
        }
      }
    });
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
        // ① 订阅 JSON（MusicFree 生态常见写法）：一次导一整包插件
        const entries: MfSubscriptionEntry[] = script.trimStart().startsWith('{')
          ? parseMusicFreeSubscription(script) : [];
        if (entries.length > 0) {
          this.toast('发现 ' + entries.length + ' 个插件，正在逐个加载…');
          const report: MfImportReport =
            await importMusicFreeSubscriptionText(script, url, this.subscriptionNameOf(url));
          this.refresh();
          this.onlineUrl = '';
          if (report.ok) {
            AppStorage.setOrCreate(AppStorageKeys.MF_ENGINE_NEEDED, true);
            this.toast('订阅导入完成：' + report.message);
            this.pathStack.pop();
            this.schedulePlatformRefresh();
          } else {
            this.toast('订阅导入失败：' + report.message);
          }
          return;
        }
        // ② 单脚本：LX 脚本 / MusicFree 插件自动分派
        const message: string = await importSourceScriptAuto(script, '');
        this.refresh();
        this.pathStack.pop();
        this.onlineUrl = '';
        AppStorage.setOrCreate(AppStorageKeys.MF_ENGINE_NEEDED, true);
        this.toast('已导入「' + message + '」');
        this.schedulePlatformRefresh();
      } catch (err) {
        this.toast('导入失败：' + ((err as Error).message ?? '无效的脚本文件'));
      }
    } catch (_err) {
      this.toast('拉取失败，请检查网络');
    } finally {
      httpRequest.destroy();
      this.importing = false;
    }
  }

  /** 检查更新命中后用它的 updateUrl 直接替换该音源。 */

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

  /** 在线导入（整页 / 半模态共用同一个输入区，只保留一份实现）。 */
  @Builder
  private OnlineImportSheet() {
    Column() {
      this.OnlineImportContent()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: this.panelTopInset() + 8, bottom: SETTINGS_PANEL_BOTTOM_VP })
  }

  /** 在线导入的输入区。 */
  @Builder
  private OnlineImportContent() {
    Column({ space: 16 }) {
      TextInput({ text: this.onlineUrl, placeholder: $r('app.string.setting_online_import_placeholder') })
        .width('100%')
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level16'))
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
            if (this.sourceSheet === 3) {
              this.sourceSheet = 0;
              return;
            }
            this.pathStack.pop();
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

  /**
   * 页根（`HdsNavDestination`）在**窗口坐标**里的顶边 y（vp），由 `onAreaChange` 实测。
   * 默认 0 = "页盒贴屏幕顶"。量到非 0 后，子面板让位（`panelTopInset` / `contentTopOffset`）
   * 与标题栏 `avoidLayoutSafeArea` 一起按它换算。见 `PageTopInsetHelper`。
   */
  @Local boxTopVp: number = 0;

  /** HDS title bar with system material and gradient blur. */

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
    // ★ 2026-11-15（合并 PR #14）：修正「自定义颜色二级页内容与标题栏/状态栏重叠」。
    //   本文件其它子面板都有 `Blank().height(this.panelTopInset())`（避让状态栏 + HDS 标题栏）
    //   和 `SETTINGS_PANEL_BOTTOM_VP`（避让底部悬浮播放条），只有这一页漏了两个 ⇒
    //   内容标题「自定义主题颜色」顶进返回按钮那一行，「取消」贴着播放条。
    //   ⚠️ `CustomColorSheetContent` 自身没有滚动容器，这里包一层 Scroll 不会嵌套滚动。
    Scroll() {
      Column() {
        Blank().height(this.panelTopInset())
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
      .width('100%')
      .padding({ bottom: SETTINGS_PANEL_BOTTOM_VP })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    // ★ 2026-10-29（用户）：二级设置页滚动要有回弹
    .edgeEffect(EdgeEffect.Spring)
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
      // 锁定时悬浮窗自身不再响应；解锁入口只保留通知栏，这里只提示用户去哪儿找
      return '桌面歌词已锁定：位置固定、不再响应拖动和设置。需要调整时展开通知栏，' +
        '点「桌面歌词已锁定」通知里的「解锁歌词」按钮。';
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
        // ★ 2026-11-15（用户：「QuickJS 如果真能完全走，就在其它设置里加个引擎设置的选项」）：
        //   现在只给**状态 + 自检入口**，不给切换开关 —— 原因是宿主能力（XHR / crypto / DOM 桩 /
        //   定时器）还没补，切过去会让每个音源都不可用。等 Phase 3 落地后，把这里换成
        //   `CapsuleSelector(['WebView','QuickJS'], …)` 并接到 LXSourceEngine 上即可。
        Column() {
          this.SubTitle($r('app.string.setting_sub_engine'))
          // ★ 2026-11-15：从「只显示状态」升级成**可选**。
          //   QuickJS 现在能跑真实脚本、能重放取址请求并拿到与 WebView **完全一致**的地址，
          //   所以可以给开关了；任何时候 QuickJS 失败都会自动回落 WebView（混合，不是二选一）。
          this.CapsuleSelector(['自动', 'WebView', 'QuickJS'],
            this.lxEngineMode === 'webview' ? 1 : (this.lxEngineMode === 'quickjs' ? 2 : 0),
            (index: number) => {
              const mode: string = index === 1 ? 'webview' : (index === 2 ? 'quickjs' : 'auto');
              this.lxEngineMode = mode;
              MusicStoreService.getInstance().setLxEngineMode(mode);
            })
          // ★ 2026-11-15（用户：「能不能一键测」）：三项合成一键 —— 逐项点会得到三行散日志，
          //   还要人工判断"两个引擎给的是不是同一个地址"。这里一次跑完、一次判定。
          Button(this.quickJsRunning ? '正在测…' : '一键测（QuickJS 引擎）')
            .height(34)
            .fontSize(13)
            .backgroundColor($r('app.color.card_background'))
            .fontColor($r('app.color.font_primary'))
            .enabled(!this.quickJsRunning)
            .margin({ top: 8 })
            .onClick((): void => {
              void this.runOneClickCheck();
            })
          Text(this.quickJsScriptState.length > 0 ? this.quickJsScriptState : '还没测过')
            .fontSize(12)
            .fontColor($r('app.color.font_tertiary'))
            .width('100%')
            .lineHeight(18)
            .margin({ top: 6 })
          Text(this.quickJsState.length > 0 ? ('自检：' + this.quickJsState) :
            $r('app.string.setting_engine_selftest_empty'))
            .fontSize(12)
            .fontColor($r('app.color.font_tertiary'))
            .width('100%')
            .margin({ top: 6 })
          Text('QuickJS 走本地自建引擎（不创建 WebView，冷启动更快）；任何一步失败都会自动回落 WebView。' +
            '先点下面的按钮确认这支脚本在 QuickJS 里能跑通，再切过去。')
            .fontSize(12)
            .fontColor($r('app.color.font_tertiary'))
            .width('100%')
            .margin({ top: 6 })
          Text($r('app.string.setting_engine_hint'))
            .fontSize(12)
            .fontColor($r('app.color.font_tertiary'))
            .width('100%')
            .margin({ top: 6 })
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
                // ★ 2026-11-15（PR #11）：解锁悬浮窗**只有**通知栏那条带按钮的通知，
                //   没授权通知就发不出来 ⇒ 锁定后用户再也解不开。所以开开关时（用户手势时机）
                //   顺手申请一次通知授权；已授权则静默。
                const notifCtx = getContext(this) as common.UIAbilityContext;
                void notificationManager.requestEnableNotification(notifCtx).catch((): void => {});
              }
            })
          Text(this.desktopLyricHint())
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .padding({ top: 6 })
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

  /** 订阅整包启用 / 停用：一次性改完所有成员，只落盘一次。 */
  private toggleSubscription(sub: MfSubscriptionInfo, enabled: boolean): void {
    const members: string[] = [];
    for (let i: number = 0; i < this.lxApiList.length; i++) {
      if (this.lxApiList[i].subId === sub.id) {
        members.push(this.lxApiList[i].id);
      }
    }
    if (members.length === 0) {
      return;
    }
    const next: string[] = [];
    if (enabled) {
      for (let i: number = 0; i < this.sourceOrderIds.length; i++) {
        next.push(this.sourceOrderIds[i]);
      }
      for (let i: number = 0; i < members.length; i++) {
        if (next.indexOf(members[i]) < 0) {
          next.push(members[i]);
        }
      }
    } else {
      for (let i: number = 0; i < this.sourceOrderIds.length; i++) {
        if (members.indexOf(this.sourceOrderIds[i]) < 0) {
          next.push(this.sourceOrderIds[i]);
        }
      }
    }
    this.sourceOrderIds = next;
    this.persistSourceOrder();
    // 停用的源不能继续当「当前使用」，否则 UI 会出现「当前使用 + 未启用」的矛盾状态
    if (!enabled && this.activeSource.length > 0 && members.indexOf(this.activeSource) >= 0) {
      AppStorage.setOrCreate(AppStorageKeys.LX_ACTIVE_SOURCE, '');
      MusicStoreService.getInstance().setActiveSource('');
      this.activeSource = '';
    }
    // 平台清单按「已启用源」派生，启用状态变了要重建一次
    this.schedulePlatformRefresh();
  }

  private toggleSourceInOrder(apiId: string): void {
    const idx: number = this.sourceOrderIds.indexOf(apiId);
    if (idx >= 0 && this.activeSource === apiId) {
      AppStorage.setOrCreate(AppStorageKeys.LX_ACTIVE_SOURCE, '');
      MusicStoreService.getInstance().setActiveSource('');
      this.activeSource = '';
    }
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
    // 关掉某个源后它的平台要从「平台管理 / 搜索 / 广场」消失；重新打开要回来
    this.schedulePlatformRefresh();
  }

  /**
   * 音源列表拖动后的行顺序落地。
   *
   * ★ 2026-11-09（用户：「现在音源没法拖动排序了」）：
   *   列表一行是「订阅整包 / 独立脚本」，行顺序单独存（`source_row_order`）；
   *   同时把它换算成播放兜底的源优先级 —— 订阅整包按**块**移动，
   *   块内成员相对顺序不变（用户拖的是整包，不是包里的某一个插件）。
   * @param keys 新行顺序
   */
  private applySourceRowOrder(keys: string[]): void {
    this.sourceRowOrder = keys;
    MusicStoreService.getInstance().setSourceRowOrder(keys);

    const current: string[] = this.sourceOrderIds;
    const next: string[] = [];
    for (let k: number = 0; k < keys.length; k++) {
      const key: string = keys[k];
      if (key.startsWith('api:')) {
        const id: string = key.substring(4);
        if (current.indexOf(id) >= 0 && next.indexOf(id) < 0) {
          next.push(id);
        }
      } else if (key.startsWith('sub:')) {
        const members: string[] = this.memberIdsOfSub(key.substring(4));
        for (let m: number = 0; m < members.length; m++) {
          if (current.indexOf(members[m]) >= 0 && next.indexOf(members[m]) < 0) {
            next.push(members[m]);
          }
        }
      }
    }
    // 没出现在行顺序里的启用源（理论上不该有）追加在末尾，避免被排序"丢掉"
    for (let i: number = 0; i < current.length; i++) {
      if (next.indexOf(current[i]) < 0) {
        next.push(current[i]);
      }
    }
    this.sourceOrderIds = next;
    this.persistSourceOrder();
    appendPlayLog('[音源顺序] drag rows=' + keys.length);
  }

  /** 订阅下的成员 id（插件侧 `subId` 与订阅侧 `apiIds` 双向兜底，兼容老数据）。 */
  private memberIdsOfSub(subId: string): string[] {
    const out: string[] = [];
    for (let i: number = 0; i < this.lxApiList.length; i++) {
      if (this.lxApiList[i].subId === subId && out.indexOf(this.lxApiList[i].id) < 0) {
        out.push(this.lxApiList[i].id);
      }
    }
    for (let s: number = 0; s < this.subscriptions.length; s++) {
      if (this.subscriptions[s].id !== subId) {
        continue;
      }
      const ids: string[] = this.subscriptions[s].apiIds;
      for (let k: number = 0; k < ids.length; k++) {
        if (out.indexOf(ids[k]) < 0) {
          out.push(ids[k]);
        }
      }
    }
    return out;
  }

  /** 打开 MusicFree 源的备注编辑器（预填当前备注；没备注就填原名）。 */
  private openRemarkEditor(api: LXUserApiInfo): void {
    this.remarkTargetId = api.id;
    const rawRemark: string | undefined = api.remark;
    const remark: string = rawRemark !== undefined ? rawRemark.trim() : '';
    this.remarkTargetName = remark.length > 0 ? remark : displayNameOfApi(api);
    this.remarkDraft = this.remarkTargetName;
    this.sourceSheet = 4;
  }

  /** 保存备注：只改 `remark`，不动 `name` / `platform`（后者参与订阅更新去重）。 */
  private submitRemark(): void {
    if (this.remarkTargetId.length === 0) {
      this.sourceSheet = 0;
      return;
    }
    lxSourceManager.setApiRemark(this.remarkTargetId, this.remarkDraft);
    this.sourceSheet = 0;
    this.remarkTargetId = '';
    this.refresh();
    this.toast('已保存');
  }

  /**
   * 订阅（音源本身）的「编辑」：直接改这份订阅的备注。
   *
   * ★ 2026-11-09（用户：「那个修改备注是修改音源本身的备注，只显示域名太难看了」）：
   *   之前这里先进「选成员」再改插件备注 —— 语义错了。订阅 = 音源，成员 = 平台来源；
   *   左滑改的是音源自己的名字。成员备注仍可在「关于」气泡里单独改。
   */
  private openSubscriptionEditor(sub: MfSubscriptionInfo): void {
    this.remarkPickSubId = sub.id;
    this.subRemarkTargetId = sub.id;
    let ordinal: number = 1;
    for (let i: number = 0; i < this.subscriptions.length; i++) {
      if (this.subscriptions[i].id === sub.id) {
        ordinal = i + 1;
        break;
      }
    }
    this.subRemarkTargetName = musicFreeSubscriptionLabel(sub, ordinal, this.subscriptions.length);
    const rawRemark: string | undefined = sub.remark;
    this.subRemarkDraft = rawRemark !== undefined ? rawRemark.trim() : '';
    this.sourceSheet = 6;
  }

  /**
   * 保存订阅备注（空串 = 清除，回退到订阅自带名）。
   *
   * ★ 2026-11-09（用户：「修改备注后弹窗不会自动关闭」）：保存即关闭半模态，
   *   列表靠 `sourceDataVersion` 立刻换名，不必退出页面再进来。
   */
  private submitSubscriptionRemark(): void {
    if (this.subRemarkTargetId.length === 0) {
      this.sourceSheet = 0;
      return;
    }
    lxSourceManager.setSubscriptionRemark(this.subRemarkTargetId, this.subRemarkDraft);
    this.subRemarkTargetId = '';
    this.subRemarkDraft = '';
    this.remarkPickSubId = '';
    this.sourceSheet = 0;
    this.refresh();
    this.toast('已保存');
  }

  /** 订阅下的成员（插件侧 subId 与订阅侧 apiIds 双向兜底）。 */
  private subMembersOf(subId: string): LXUserApiInfo[] {
    const out: LXUserApiInfo[] = [];
    for (let i: number = 0; i < this.lxApiList.length; i++) {
      const api: LXUserApiInfo = this.lxApiList[i];
      if (api.subId === subId && out.indexOf(api) < 0) {
        out.push(api);
      }
    }
    if (out.length > 0) {
      return out;
    }
    // 老数据：插件侧 subId 为空，订阅侧记着 apiIds
    for (let s: number = 0; s < this.subscriptions.length; s++) {
      if (this.subscriptions[s].id !== subId) {
        continue;
      }
      const ids: string[] = this.subscriptions[s].apiIds;
      for (let k: number = 0; k < ids.length; k++) {
        for (let j: number = 0; j < this.lxApiList.length; j++) {
          if (this.lxApiList[j].id === ids[k] && out.indexOf(this.lxApiList[j]) < 0) {
            out.push(this.lxApiList[j]);
          }
        }
      }
    }
    return out;
  }

  /**
   * 打开「修改支持的平台」（仅 LX 脚本）。
   *
   * 预填的是**当前生效**的平台（用户裁过就是裁过的，没裁过就是脚本声明的）。
   */
  private openPlatformEditor(api: LXUserApiInfo): void {
    this.platformTargetId = api.id;
    const effective: LXSourcePlatformInfo[] = lxDeclaredPlatformsOf(api);
    const ids: string[] = [];
    for (let i: number = 0; i < effective.length; i++) {
      const id: string = normalizePlatformId(effective[i].source);
      if (ids.indexOf(id) < 0 && LX_PLATFORM_ORDER.indexOf(id) >= 0) {
        ids.push(id);
      }
    }
    this.platformDraft = ids;
    this.sourceSheet = 5;
  }

  /** 保存「支持的平台」：空数组 = 恢复跟随脚本声明。 */
  private submitPlatforms(): void {
    if (this.platformTargetId.length === 0) {
      this.sourceSheet = 0;
      return;
    }
    lxSourceManager.setApiPlatforms(this.platformTargetId, this.platformDraft);
    this.sourceSheet = 0;
    this.platformTargetId = '';
    this.refresh();
  }

  /** 勾 / 取消一个平台（草稿）。 */
  private toggleDraftPlatform(id: string, checked: boolean): void {
    const next: string[] = [];
    for (let i: number = 0; i < this.platformDraft.length; i++) {
      if (this.platformDraft[i] !== id) {
        next.push(this.platformDraft[i]);
      }
    }
    if (checked) {
      next.push(id);
    }
    this.platformDraft = next;
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

  /**
   * 音源管理（唯一实现，2026-11-08 第二版）。
   *
   * ★ 用户：「不要两个页面啊，这不又成屎山了吗。你直接放进音源管理页的右上角，
   *   顺带把导入音源也放进那里」：
   *   - 平台管理不再是一个子页面，改成半模态（`sourceSheet === 1`，标题走 HDS 的
   *     `bindSheet.title`，不再自绘第二根标题栏）；
   *   - 导入（文件 / 链接）与平台管理收进右上角**一个菜单**（`SourceActionsMenu`，
   *   popup 的 `systemMaterial` 吃用户设置的光感档（与标题栏同一份 `immersiveFromLevel`）。
   *
   * ★ 2026-11-09（用户：「源和平台都分开」）：源列表只显示订阅 / 独立脚本，
   *   平台勾选全部归「平台管理」（`sourceSheet === 1`），这里不再有「编辑平台」入口。
   */
  @Builder
  private SourceManagerPanel() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll(this.pageScroller) {
        Column({ space: 8 }) {
          /**
           * ★ 顶部这段留白放在**滚动内容里面**（不是外层 padding），目的是让卡片能**滑到 HDS
           *   标题栏底下**（沉浸式）：静止时第一张卡正好在标题栏下沿，
           *   一往上滑就从标题栏（渐变模糊材质）底下穿过去。
           *   用户 2026-10-11：「音源管理页面上方下方都一大块空白，能不能去掉」。
           */
          Blank().height(PageTopInsetHelper.contentOffsetVp(this.boxTopVp))

          if (this.lxApiList.length === 0) {
            Text($r('app.string.setting_lx_empty'))
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_tertiary'))
              .width('100%')
          }

          // 统一实现：一行一个源（订阅整包 / 独立脚本）+ 勾选启用 + 左滑操作
          SourceManagerList({
            apis: this.orderedApiListForUi(),
            subscriptions: this.subscriptions,
            rowOrder: this.sourceRowOrder,
            orderIds: this.sourceOrderIds,
            activeId: this.activeSource,
            accentColor: this.themeState.color,
            dataVersion: this.sourceDataVersion,
            onToggle: (apiId: string): void => {
              this.toggleSourceInOrder(apiId);
            },
            onReorderRows: (keys: string[]): void => {
              this.applySourceRowOrder(keys);
            },
            onEditRemark: (api: LXUserApiInfo): void => {
              this.openRemarkEditor(api);
            },
            onEditPlatforms: (api: LXUserApiInfo): void => {
              this.openPlatformEditor(api);
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
            onToggleSubscription: (sub: MfSubscriptionInfo, enabled: boolean): void => {
              this.toggleSubscription(sub, enabled);
            },
            onUpdateSubscription: (sub: MfSubscriptionInfo): void => {
              void this.updateSubscriptionPack(sub);
            },
            onEditSubscription: (sub: MfSubscriptionInfo): void => {
              this.openSubscriptionEditor(sub);
            },
            onDeleteSubscription: (sub: MfSubscriptionInfo): void => {
              this.confirmDeleteSubscription(sub);
            }
          })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .clipContent(ContentClipMode.SAFE_AREA)
      .scrollBar(BarState.Off)
      // ★ 2026-10-29（用户）：二级设置页滚动要有回弹
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
      // ★ 底部"给悬浮播放条让位"的留白留在**列表里**（`contentEndOffset`），随内容一起滚走。
      .contentEndOffset(SETTINGS_PANEL_BOTTOM_VP)

      // 菜单锚点：1×1 透明节点，只负责给 popup 定位（点击由标题栏图标触发）
      this.SourceMenuAnchor()
    }
    .width('100%')
    .height('100%')
    // 两侧间距与设置页主列表同一口径（用户报「怎么两侧间距都这么大」：
    // 原来是本面板 20 + 平台管理再 16 = 36，现在只在这里给一次）
    .padding({ left: 16, right: 16 })
  }

  /**
   * 音源管理右上角菜单的**锚点**。
   *
   * HDS 标题栏的图标槽位只能给 `action`（不能挂 bindMenu），所以菜单绑在这个 1×1 节点上，
   * `placement: BottomRight` + 右上角对齐 ⇒ 视觉上从标题栏图标正下方展开。
   * 1×1 且 `HitTestMode.None`，不遮挡、不拦截列表点击。
   * （同一写法见 `NowPlayingFeedPage.FeedModeMenuAnchor`。）
   */
  @Builder
  private SourceMenuAnchor() {
    Row()
      .width(1)
      .height(1)
      .margin({ top: PageTopInsetHelper.contentOffsetVp(this.boxTopVp), right: 24 })
      .hitTestBehavior(HitTestMode.None)
      .bindPopup(this.showSourceMenu, {
        builder: (): void => {
          this.SourceActionsMenu();
        },
        placement: Placement.BottomRight,
        enableArrow: false,
        radius: 16,
        // ★ 光感档跟随用户的「沉浸光感」设置（不是写死中等），与标题栏/胶囊同一口径
        systemMaterial: immersiveFromLevel(this.ambientLevel),
        onStateChange: (event): void => {
          if (!event.isVisible) {
            this.showSourceMenu = false;
          }
        }
      })
  }

  /** 音源管理的两个操作（导入 / 平台管理），收纳在标题栏菜单里。 */
  @Builder
  private SourceActionsMenu() {
    Menu() {
      MenuItem({ content: '从文件导入音源 / 订阅' })
        .onClick((): void => {
          this.showSourceMenu = false;
          void this.importLXSource();
        })
      MenuItem({ content: '从链接导入音源 / 订阅' })
        .onClick((): void => {
          this.showSourceMenu = false;
          this.sourceSheet = 3;
        })
      MenuItem({ content: '平台管理' })
        .onClick((): void => {
          this.showSourceMenu = false;
          this.sourceSheet = 1;
        })
    }
  }

  /** 音源管理相关弹层的统一内容（一个组件只能挂一个 bindSheet，用 `sourceSheet` 分工）。 */
  @Builder
  private SourceSheetContent() {
    Column() {
      if (this.sourceSheet === 1) {
        PlatformManagerSheet({
          apis: this.lxApiList,
          subscriptions: this.subscriptions,
          accentColor: this.themeState.color,
          onPlatformsChanged: (): void => {
            this.refresh();
          }
        })
      } else if (this.sourceSheet === 3) {
        this.OnlineImportContent()
      } else if (this.sourceSheet === 4) {
        this.RemarkSheetContent()
      } else if (this.sourceSheet === 5) {
        this.PlatformSheetContent()
      } else if (this.sourceSheet === 6) {
        this.SubscriptionEditContent()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
  }

  /**
   * MusicFree 源备注编辑。
   *
   * ★ 2026-11-09（用户：「MusicFree 的源支持一下修改备注」）：订阅里常有两个同名插件
   *   （都叫「元力WY」），源列表 / 平台管理靠这个备注区分。
   */
  @Builder
  private RemarkSheetContent() {
    Column({ space: 12 }) {
      Text('备注「' + this.remarkTargetName + '」')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      TextInput({ text: this.remarkDraft, placeholder: '留空则恢复插件原名' })
        .width('100%')
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level6'))
        .padding({ left: 12, right: 12 })
        .maxLength(24)
        .onChange((value: string): void => {
          this.remarkDraft = value;
        })
        .onSubmit((): void => {
          this.submitRemark();
        })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .fontSize($r('sys.float.Body_M'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor($r('sys.color.background_tertiary'))
          .fontColor($r('sys.color.font_secondary'))
          .onClick((): void => {
            this.sourceSheet = 0;
          })
        Button('保存')
          .layoutWeight(1)
          .height(40)
          .fontSize($r('sys.float.Body_M'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor(this.themeState.color)
          .fontColor($r('sys.color.font_on_primary'))
          .onClick((): void => {
            this.submitRemark();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * LX 脚本「实际支持平台」编辑。
   *
   * ★ 2026-11-09（用户：「LX 是修改支持的平台，因为源不稳定，平台可能失效」）：
   *   脚本 init 上报的是**声明**，接口失效后用户要能把它从兜底链里摘掉，
   *   否则每次播放都会先在这个平台上白等一轮再换源。
   */
  @Builder
  private PlatformSheetContent() {
    Column({ space: 0 }) {
      List({ space: 6 }) {
        ForEach(LX_PLATFORM_ORDER, (id: string) => {
          ListItem() {
            Row({ space: 10 }) {
              Checkbox()
                .select(this.platformDraft.indexOf(id) >= 0)
                .selectedColor(this.themeState.color)
                .width(20)
                .height(20)
                .onChange((checked: boolean): void => {
                  this.toggleDraftPlatform(id, checked);
                })
              Text(lxSourceLabel(id))
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .borderRadius($r('sys.float.corner_radius_level6'))
            .backgroundColor($r('app.color.comp_background_list_card'))
          }
        }, (id: string) => 'platform_edit_' + id)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .fontSize($r('sys.float.Body_M'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor($r('sys.color.background_tertiary'))
          .fontColor($r('sys.color.font_secondary'))
          .onClick((): void => {
            this.sourceSheet = 0;
          })
        Button('保存')
          .layoutWeight(1)
          .height(40)
          .fontSize($r('sys.float.Body_M'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor(this.themeState.color)
          .fontColor($r('sys.color.font_on_primary'))
          .onClick((): void => {
            this.submitPlatforms();
          })
      }
      .width('100%')
      .padding({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 订阅「编辑」：改音源本身的备注 + 成员备注入口。
   *
   * ★ 2026-11-09（用户：「那个修改备注是修改音源本身的备注，只显示域名太难看了」）：
   *   顶部第一件事就是给这份音源起名（默认值不会再是 `13413.kstore.vip` 这种主机名）；
   *   下面的成员列表只是「里面有什么 + 想单独改哪个插件的备注」。
   */
  @Builder
  private SubscriptionEditContent() {
    Column({ space: 12 }) {
      TextInput({ text: this.subRemarkDraft, placeholder: this.subRemarkTargetName })
        .width('100%')
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level6'))
        .padding({ left: 12, right: 12 })
        .maxLength(24)
        .onChange((value: string): void => {
          this.subRemarkDraft = value;
        })
        .onSubmit((): void => {
          this.submitSubscriptionRemark();
        })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .fontSize($r('sys.float.Body_M'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor($r('sys.color.background_tertiary'))
          .fontColor($r('sys.color.font_secondary'))
          .onClick((): void => {
            this.sourceSheet = 0;
          })
        Button('保存')
          .layoutWeight(1)
          .height(40)
          .fontSize($r('sys.float.Body_M'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor(this.themeState.color)
          .fontColor($r('sys.color.font_on_primary'))
          .onClick((): void => {
            this.submitSubscriptionRemark();
          })
      }
      .width('100%')

      List({ space: 6 }) {
        ForEach(this.subMembersOf(this.remarkPickSubId), (api: LXUserApiInfo) => {
          ListItem() {
            Row({ space: 8 }) {
              Column({ space: 2 }) {
                Text(displayNameOfApi(api))
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Text('MusicFree' + (api.platform.length > 0 ? ' · ' + api.platform : ''))
                  .fontSize($r('sys.float.Caption_S'))
                  .fontColor($r('sys.color.font_tertiary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              SymbolGlyph($r('sys.symbol.square_and_pencil'))
                .fontSize(18)
                .fontColor([$r('sys.color.icon_secondary')])
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .borderRadius($r('sys.float.corner_radius_level6'))
            .backgroundColor($r('app.color.comp_background_list_card'))
            .onClick((): void => {
              this.openRemarkEditor(api);
            })
          }
        }, (api: LXUserApiInfo) => 'sub_edit_' + api.id)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  /** 弹层标题（HDS 半模态规范：标题由系统画，内容不再自绘标题栏）。 */
  private sourceSheetTitle(): string {
    if (this.sourceSheet === 1) {
      return '平台管理';
    }
    if (this.sourceSheet === 4) {
      return '修改备注';
    }
    if (this.sourceSheet === 5) {
      return '支持的平台';
    }
    if (this.sourceSheet === 6) {
      return '音源备注';
    }
    return '从链接导入';
  }

  /** 弹层高度：平台管理要容纳拖动排序，编辑与在线导入矮一些。 */
  private sourceSheetHeight(): number {
    if (this.sourceSheet === 1) {
      return 640;
    }
    if (this.sourceSheet === 4) {
      return 260;
    }
    if (this.sourceSheet === 5) {
      return 520;
    }
    if (this.sourceSheet === 6) {
      return 600;
    }
    return 300;
  }

  private applyCustomColor(): void {
    this.applyThemeColor(this.customColor.trim());
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
      /**
       * ★ 2026-11-08（用户：「进入音源管理页面更是直接就变了，连最基础的切页动画都没有」）：
       *   HDS 的 `HdsNavDestination` 默认不套系统转场（外层 `HdsNavigation` 挂了
       *   `customNavContentTransition`，非歌单页返回 undefined ⇒ 没有动画）。
       *   这里显式声明系统默认转场（右侧滑入 + 淡入），二级设置页恢复"正常的翻页感"。
       */
      .systemTransition(NavigationSystemTransitionType.DEFAULT)
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
          this.SourceManagerPanel()
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
      // ★ 2026-11-08：音源管理的弹层（平台管理 / 实际支持平台 / 在线导入）挂在**根容器**上。
      //   一个组件只能挂一个 bindSheet，用 `sourceSheet` 枚举分工（见 SourceSheetContent）。
      //   标题交给 HDS 半模态画（`title`），内容不再自绘标题栏 —— 这正是上一版「两个页面」的来源。
      .bindSheet(this.sourceSheet > 0, this.SourceSheetContent(), {
        height: this.sourceSheetHeight(),
        title: { title: this.sourceSheetTitle() },
        dragBar: true,
        showClose: false,
        backgroundColor: $r('app.color.background_secondary'),
        onWillDismiss: (action: DismissSheetAction): void => {
          this.sourceSheet = 0;
          action.dismiss();
        },
        onDisappear: (): void => {
          this.sourceSheet = 0;
        }
      })
  }

}

@Builder
export function SettingsDetailPageBuilder(name: string, param: Object) {
  SettingsDetailPage({
    sheetIndex: (param as SettingsDetailRouteParam | undefined)?.index ?? 4
  })
}
