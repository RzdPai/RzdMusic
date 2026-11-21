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

import { guardPlayerBack,
  rdzToast
} from 'musicbasic';
import { AppStorageV2, uiObserver } from '@kit.ArkUI';

import { http } from '@kit.NetworkKit';

import { appendPlayLog, AppStorageKeys, BarScrollHelper, RouterUrlConstants, BreakpointType, MusicAppState, MusicStoreService, PageTopInsetHelper, ThemeState, WindowInfo, buildTitleMaterial, getWindowInfoState } from 'musicbasic';
import { BlurStrategy, HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { LXUserApiInfo, lxSourceManager } from 'player';

import { HuaweiAccountService } from 'player';

import { SettingsDetailPage, SettingsDetailRouteParam } from './SettingsDetailPage';

const LX_ONLINE_IMPORT_MAX_BYTES: number = 9 * 1024 * 1024;
const LX_ONLINE_IMPORT_TIMEOUT: number = 15000;
const DEFAULT_SETTING_INDEX: number = 4;

/** 日志域 / 标签：`grep RzdPageTopInset` 看页盒顶边实测与由此算出的让位。 */
const DOMAIN: number = 0x0000;
const TAG: string = 'RzdSettingPage';

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
  /** 「回到顶部」指令：壳层点了当前页签时递增（底部页签设计规范）。 */
  @Param scrollTopCommand: number = 0;
  /** Window breakpoint for the HDS home-style responsive title. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local lxApiList: LXUserApiInfo[] = [];
  /** 参与依次换源的脚本 id 顺序（多选 + 可排序）。 */
  @Local sourceOrderIds: string[] = [];
  @Local activeSource: string = '';
  @Local engineReady: boolean = false;
  @Consumer('pageIndexInfos') pageStack: NavPathStack = new NavPathStack();
  @Local settingStack: NavPathStack = new NavPathStack();
  @Local selectedIndex: number = -1;
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** 搜索关键词（顶部搜索栏过滤设置项）。 */
  @Local searchKeyword: string = '';
  @Local ambientLevel: number = 0;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** Scroller bound to the HDS title bar so the scroll effect (gradient blur) can fire. */
  private pageScroller: Scroller = new Scroller();
  /** 全局播控状态：滚动联动双层底栏需要写 miniBarExpanded / hdsBarLayoutMode。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;

  aboutToAppear(): void {
    this.refresh();
    this.syncWideSettingLayout();
    // 恢复华为账号登录态：登录过之后「登录音乐」那张卡要显示头像与昵称
    HuaweiAccountService.getInstance().restore();
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

  /** 壳层点了当前页签：滚回顶部（底部页签设计规范）。 */
  @Monitor('scrollTopCommand')
  onScrollTopCommand(): void {
    this.pageScroller.scrollEdge(Edge.Top);
  }

  @Monitor('windowInfo.widthBp')
  onWindowWidthBpChanged(): void {
    this.syncWideSettingLayout();
  }

  private refresh(): void {
    this.lxApiList = lxSourceManager.getApiList();
    this.sourceOrderIds = MusicStoreService.getInstance().getSourceScriptOrder();
    // 未配置过顺序时，默认全部勾选并按导入顺序
    if (this.sourceOrderIds.length === 0 && !MusicStoreService.getInstance().hasSourceScriptOrderConfig()) {
      const ids: string[] = [];
      for (let i: number = 0; i < this.lxApiList.length; i++) {
        if (this.lxApiList[i].id.length > 0) {
          ids.push(this.lxApiList[i].id);
        }
      }
      this.sourceOrderIds = ids;
      // ★★★ 2026-11-05（真机日志实证 `[回退链] 没有勾选任何音源，直接返回`）：
      //   只把"全部已导入"填进 UI 变量、**不落盘** ⇒ `getSourceScriptOrder()` 恒为空
      //   ⇒ 播放链路拿到空候选链 ⇒ 0 次请求秒失败（而用户看到的是"全都勾着"）。
      //   首次进来就把这份默认全选写实，UI 与播放链路一致。
      if (ids.length > 0) {
        MusicStoreService.getInstance().setSourceScriptOrder(ids);
        appendPlayLog('[音源顺序] init ' + ids.length);
      }
    }
    this.activeSource = AppStorage.get<string>(AppStorageKeys.LX_ACTIVE_SOURCE) ?? '';
    this.engineReady = this.activeSource.length > 0 && AppStorage.get<boolean>(AppStorageKeys.LX_ENGINE_READY) === true;
    // 设置页自身标题栏的沉浸材质档位（与详情页共用同一个 buildTitleMaterial）
    this.ambientLevel = MusicStoreService.getInstance().getAmbientLevel();
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

  private toast(message: string): void {
    rdzToast(this.getUIContext(), message, 2000);
  }

  private engineTimer: number = 0;

  private stopEnginePolling(): void {
    if (this.engineTimer > 0) {
      clearInterval(this.engineTimer);
      this.engineTimer = 0;
    }
  }

  aboutToDisappear(): void {
    this.stopEnginePolling();
  }

  /** Cached title bar options so scrolling rebuilds do not recreate material params. */
  private cachedTitleBarOptions: HdsNavigationTitleBarOptions | undefined = undefined;

  /**
   * 页根（`HdsNavDestination`）在**窗口坐标**里的顶边 y（vp），由 `onAreaChange` 实测。
   *
   * 默认 0 = "页盒贴屏幕顶"（= 参考工程 lxmusic-harmony 的假设，也是我们此前写死的那套），
   * 量到非 0（框架把页盒压在安全区内）后：内容让位与 HDS 标题栏的 `avoidLayoutSafeArea`
   * 一起换算过来，标题与内容都不会再整体下移一个状态栏。见 `PageTopInsetHelper` 的说明。
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
      // ★ 页盒实测贴屏幕顶（盒顶 = 0）时，才让 HDS 标题栏自己退回状态栏下方；
      //   盒顶本身已在状态栏下沿（38）时不能再退，否则标题栏会掉到 38 + 38（用户报的「标题下移」）。
      avoidLayoutSafeArea: PageTopInsetHelper.avoidLayoutSafeArea(this.boxTopVp),
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('app.color.font_primary')
            },
            menuStyle: { iconColor: $r('sys.color.font_primary') },
            backIconStyle: {
              iconColor: $r('app.color.font_primary'),
              backgroundColor: '#1A808080'
            }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('app.color.font_primary')
            },
            menuStyle: { iconColor: $r('sys.color.font_primary') },
            backIconStyle: {
              iconColor: $r('app.color.font_primary'),
              backgroundColor: '#1A808080'
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
        // ★ 用户 2026-10-11：原来这里那张「登录音乐」大卡片**搬到「我的」页顶部**了
        //   （抽成 `LoginMusicCard.ets`，我的页调它）。设置页里**不再有**这张卡，
        //   所以这里只删掉那一行调用 —— `LoginAccountCard()` 这个 Builder 与其余设置项一律不动。
        this.SourceEntry()
        this.PlaybackDownloadEntry()
        this.ThemeEntry()
        this.OtherAboutEntry()
        Blank()
      }
      .width('100%')
      .padding({
        // ★ 2026-10-11（用户：「我想让它延伸进状态栏」）：这段留白在**滚动内容里**
        //   （`Scroll` 的内容根 `Column` 的 padding），所以必须含状态栏那一段。
        //   ⚠️ 但"该让多少"不能假设页盒从 y=0 起排 —— 框架有可能把页盒限制在安全区内
        //   （实测：用户装机后标题/内容整体下移一个状态栏，说明盒顶不是 0）。
        //   现在由 `boxTopVp`（页根 `onAreaChange` 实测）算：盒顶 0 → 94；盒顶 38 → 56，
        //   两种情形内容都落在窗口的 94 那条线上（详见 `PageTopInsetHelper`）。
        //   上滑时内容从标题栏底下**再穿进状态栏** —— 靠下面 `Scroll` 自己那句
        //   `clipContent(ContentClipMode.SAFE_AREA)`（`Scroll` 默认 `BOUNDARY`，按组件区域裁）。
        top: PageTopInsetHelper.contentOffsetVp(this.boxTopVp),
        left: new BreakpointType(12, 16, 24, 24).getValue(this.breakpointEnv.widthBreakpoint),
        right: new BreakpointType(12, 16, 24, 24).getValue(this.breakpointEnv.widthBreakpoint)
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
    // ★★ 让内容能画进状态栏（"延伸进状态栏"）的**官方正解**：
    //   官方《开发应用沉浸式效果》→「滚动类场景」② —— 设置滚动容器的内容裁剪属性
    //   `clipContent(ContentClipMode.SAFE_AREA)`，**将内容层裁剪区域扩展至避让区**。
    //   `Scroll` 的默认值是 `ContentClipMode.BOUNDARY`（按组件区域裁）⇒ 内容到状态栏那条会被裁掉。
    //   ⚠️ 链上任何祖先都**不能**再写 `clip(true)`（官方："需要确保父组件未设置 clip 等裁剪属性"）——
    //   本页「页根 → 滚动容器」这条链上**没有**内容容器，`Scroll` 就是 HdsNavDestination 的一级子节点。
    .clipContent(ContentClipMode.SAFE_AREA)
    // ★ 底部"给悬浮播放条让位"的留白留在**滚动内容里**（`contentEndOffset` = 内容末端到显示区
    //   边界的距离，官方 `ScrollableCommonMethod` @since 22，List/Scroll 通用）—— 它随内容一起滚走。
    //   原来写的是**内容根 `Column` 的 `padding({ bottom: 72 })`**：作用域也在滚动内容里、效果相同，
    //   这里换成与 `RecordListPage` / `SettingsDetailPage` / 其它页**完全同一口径**。
    //   反面做法（禁）：写在外层容器的 `padding({ bottom })` 上 —— 那是固定在屏幕底部的死带。
    .contentEndOffset(72)
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
    .onBackPressed((): boolean => guardPlayerBack('SettingPage'))
    .hideTitleBar(false)
    // ★ 这一页现在**只作为二级页**存在（原来的「设置」页签已被「我的」页取代，
    //   入口 = 「我的」→ 入口卡「设置」，见 `MinePage.linkRows()` / `onLinkTap()`），
    //   所以必须显示返回箭头 —— 以前它是页签页、没有"上一页"可回，才写的 true。
    .hideBackButton(false)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    .backgroundColor($r('app.color.background_secondary'))
    // ★★ 状态栏三件套（2026-10-11 定稿，用户第三次纠正后）：
    //   ① `expandSafeArea(TOP,BOTTOM)`：把**页面底色**铺到状态栏/导航条那两条（只扩绘制区）；
    //   ② `ignoreLayoutSafeArea(...[TOP, BOTTOM])` —— **TOP 必须给**：HDS 标题栏自己会按"状态栏高度"
    //      往下让位，所以**页面盒子必须从屏幕 y=0 起排**；只写 BOTTOM 变成"盒子让一次 + 标题栏再让一次"
    //      ⇒ 整条标题掉到状态栏下面约一个状态栏高度（用户原话「整个标题移到了状态栏下面」），
    //      内容也跟着多顶 38vp（「上方留的空距有点大了」）。
    //      盒子从 0 起排后：标题栏 = 38..94 ✔，`SettingsNavBarContent` 里那个
    //      `padding top`（状态栏 + 56 = 94）正好落在 94 ✔。
    //      ⚠️ 旧注释里"根节点带 TOP 会把标题顶进状态栏 / 只能留 BOTTOM"那句**是错的**，已作废。
    //   ③ 滚动容器 `clipContent(ContentClipMode.SAFE_AREA)` + 祖先链零 `clip(true)`：
    //      内容能**画进**状态栏那一条。
    // ★★ 用户 2026-10-11：「顶栏标题错位的问题还在，你应该参考一下其他显示正常的页面是怎么写的」。
    //   逐页对比后：显示正常的 MinePage / RecommendPage **都没有** expandSafeArea，
    //   而所有标题偏低的页面都有 ⇒ 照正常页面去掉它（官方语义：expandSafeArea 只延伸**绘制区**，
    //   「子组件相对屏幕位置不变」，但它会让 HDS 标题栏的定位多让一次）。
    //   页面底色由页盒自身 ackgroundColor 铺满（盒顶 = 0，实测见 RzdPageTopInset），不需要它补状态栏那一条。
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    // ★ 实测页盒顶边（窗口坐标 vp）。这是本页两个顶部量的**唯一输入**：
    //   内容让位 `PageTopInsetHelper.contentOffsetVp(boxTopVp)` 与标题栏的
    //   `avoidLayoutSafeArea`。用户装机反复报「标题下移 / 上方留白大」就是因为它此前被写死成 0。
    //   只在变化超过 0.5vp 时才写状态，避免和布局互相追着改。
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const top: number = newArea.globalPosition.y as number;
      if (Math.abs(top - this.boxTopVp) > 0.5) {
        this.boxTopVp = top;
        hilog.info(DOMAIN, TAG, 'RzdPageTopInset boxTopVp=%{public}f page=setting offset=%{public}f avoid=%{public}s',
          top, PageTopInsetHelper.contentOffsetVp(top),
          String(PageTopInsetHelper.avoidLayoutSafeArea(top)));
      }
    })
  }

  /** 分组内行分隔线（HDS 列表卡：左右缩进，1px 语义分割色）。 */
  @Builder
  private GroupDivider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.comp_divider'))
      .margin({ left: 16, right: 12 })
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

}

/**
 * 路由表里注册的 Builder（`features/setting` 的 `router_map.json`）。
 *
 * ★ 用户 2026-10-11：设置页用回**我们原本这个大的设置页本体**（原来它是底栏第 4 个页签；
 *   页签收成「推荐 / 我的」两个之后，改成从「我的」页入口卡的那一行进来）——
 *   **不是副本、也没有重写**，`router_map.json` 里指的就是本文件。
 *
 * 这一页**没有必填 `@Param`**（`scrollTopCommand` 有默认值 0），所以这里直接
 * `SettingPage()`、不传参数；它自己是 `HdsNavDestination` 根节点，被壳层那条共享
 * `HdsNavigation` 推出来就是正常的二级页（页内的 `@Consumer('pageIndexInfos')` 拿到的
 * 就是壳层共享栈，推设置详情页照旧）。
 */
@Builder
export function SettingPageBuilder(name: string, param: Object) {
  SettingPage()
}

