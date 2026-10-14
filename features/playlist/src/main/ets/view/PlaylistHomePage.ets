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
import { guardPlayerBack, AmbientState, BreakpointType, ThemeState } from 'musicbasic';
import { AppStorageKeys, MusicAppState, MusicStoreService, PlayedSongRecord, TabSwitchState, TitleBarConstants, buildTitleMaterial, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { OnlinePlayUtil } from 'player';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType } from '@kit.UIDesignKit';
import { SongMoreMenu } from './SongMoreMenu';

@ComponentV2
export struct PlaylistHomePage {
  /** Window breakpoint for the HDS home-style responsive title. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Local tabState: TabSwitchState =
    AppStorageV2.connect(TabSwitchState, AppStorageKeys.TAB_SWITCH_STATE, () => new TabSwitchState())!;
  @Local currentSection: number = 0;
  @Local historyList: PlayedSongRecord[] = [];
  @Local favoriteList: PlayedSongRecord[] = [];
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /** True when history multi-select mode is active. */
  @Local selectionMode: boolean = false;
  /** Selected history entries keyed by source_songId. */
  @Local selectedMap: Record<string, boolean> = {};
  /** Scroller bound to the HDS title bar so the scroll effect (gradient blur) can fire. */
  private pageScroller: Scroller = new Scroller();
  /**
   * 列表重建版本号：只用于「切换平台」后强制重建所有行（key 里带上它）。
   * 见 {@link forceReload}。
   */
  @Local listVersion: number = 0;

  aboutToAppear(): void {
    this.refresh();
    this.currentSection = this.tabState.playlistSection;
  }

  @Monitor('store.historyVersion', 'store.favoriteVersion')
  refresh(): void {
    this.historyList = this.store.getHistory();
    this.favoriteList = this.store.getFavorites();
  }

  /**
   * 「切换平台」后强制刷新（照搬「重命名歌单」那套显式刷新做法）。
   *
   * 换源改了库里的 source/songId，理论上 `@Monitor` 会来刷新，但
   * `ForEach` 的 key 是 `source_songId` 且列表可能正在复用节点 —— 实测会出现
   * 「库改了、列表还是旧的」。这里重读数据后再抬一次 `listVersion`，
   * key 全变 → 强制整表重建，平台标签与封面立刻跟着变。
   */
  private forceReload(): void {
    this.refresh();
    this.listVersion++;
  }

  @Monitor('tabState.playlistSection')
  onPlaylistSectionChanged(): void {
    this.currentSection = this.tabState.playlistSection;
  }

  private selectSection(section: number): void {
    this.currentSection = section;
    this.tabState.playlistSection = section;
    this.exitSelectionMode();
  }

  /** Key for history selection tracking. */
  private songKeyOf(record: PlayedSongRecord): string {
    return record.source + '_' + record.songId;
  }

  /** Active list for the current section: 0 = history, 1 = favorites. */
  private activeList(): PlayedSongRecord[] {
    return this.currentSection === 0 ? this.historyList : this.favoriteList;
  }

  /** Whether the given record is selected in multi-select mode. */
  private isSelected(record: PlayedSongRecord): boolean {
    return this.selectedMap[this.songKeyOf(record)] === true;
  }

  /** Toggles selection of one history entry. */
  private toggleSelect(record: PlayedSongRecord, on: boolean): void {
    const key: string = this.songKeyOf(record);
    const next: Record<string, boolean> = {};
    const keys: string[] = Object.keys(this.selectedMap);
    for (let i: number = 0; i < keys.length; i++) {
      next[keys[i]] = this.selectedMap[keys[i]];
    }
    next[key] = on;
    this.selectedMap = next;
  }

  /** Selected history keys. */
  private selectedIds(): string[] {
    const ids: string[] = [];
    const keys: string[] = Object.keys(this.selectedMap);
    for (let i: number = 0; i < keys.length; i++) {
      if (this.selectedMap[keys[i]] === true) {
        ids.push(keys[i]);
      }
    }
    return ids;
  }

  /** Count of selected history entries. */
  private selectedCount(): number {
    return this.selectedIds().length;
  }

  /** Enters multi-select mode for history. */
  private enterSelectionMode(): void {
    this.selectionMode = true;
    this.selectedMap = {};
  }

  /** Exits multi-select mode and clears the selection. */
  private exitSelectionMode(): void {
    this.selectionMode = false;
    this.selectedMap = {};
  }

  /** Selects or clears all entries of the active section. */
  private toggleSelectAll(): void {
    const next: Record<string, boolean> = {};
    const list: PlayedSongRecord[] = this.activeList();
    const selectAll: boolean = this.selectedCount() < list.length;
    if (selectAll) {
      for (let i: number = 0; i < list.length; i++) {
        next[this.songKeyOf(list[i])] = true;
      }
    }
    this.selectedMap = next;
  }

  /** Deletes the selected entries: history ids batch; favorites one by one. */
  private deleteSelected(): void {
    const ids: string[] = this.selectedIds();
    if (ids.length > 0) {
      if (this.currentSection === 0) {
        this.store.removeHistoryByIds(ids);
      } else {
        const list: PlayedSongRecord[] = this.favoriteList;
        for (let i: number = 0; i < list.length; i++) {
          if (this.isSelected(list[i])) {
            this.store.removeFavorite(list[i].source, list[i].songId);
          }
        }
      }
    }
    this.exitSelectionMode();
  }

  private sourceColor(source: string): string {
    switch (source) {
      case 'kw': return '#FF6B35';
      case 'kg': return '#4A90D9';
      case 'tx': return '#31C27C';
      case 'wy': return '#C62F2F';
      case 'mg': return '#FF4081';
    }
    return '#6B6B6B';
  }

  private sourceLabel(source: string): string {
    switch (source) {
      case 'kw': return '酷我';
      case 'kg': return '酷狗';
      case 'tx': return 'QQ';
      case 'wy': return '网易云';
      case 'mg': return '咪咕';
    }
    return source;
  }

  private formatTime(ts: number): string {
    if (ts <= 0) {
      return '';
    }
    const d = new Date(ts);
    const now = new Date();
    const hh = d.getHours().toString().padStart(2, '0');
    const mm = d.getMinutes().toString().padStart(2, '0');
    const sameDay = d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() &&
      d.getDate() === now.getDate();
    if (sameDay) {
      return hh + ':' + mm;
    }
    return (d.getMonth() + 1) + '-' + d.getDate() + ' ' + hh + ':' + mm;
  }

  @Builder
  private SongRow(record: PlayedSongRecord, isHistory: boolean) {
    Row({ space: 12 }) {
      if (this.selectionMode) {
        Toggle({ type: ToggleType.Checkbox, isOn: this.isSelected(record) })
          .width(24)
          .height(24)
          .selectedColor(this.themeState.color)
          .onChange((isOn: boolean) => {
            this.toggleSelect(record, isOn);
          })
      }
      Image(record.img.length > 0 ? record.img : $r('app.media.ic_avatar1'))
        .width(48)
        .height(48)
        .borderRadius($r('sys.float.corner_radius_level3'))
        .objectFit(ImageFit.Cover)
      Column({ space: 4 }) {
        Text(record.name)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Regular)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          Text(record.singer)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.sourceLabel(record.source))
            .fontSize($r('sys.float.Caption_S'))
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius($r('sys.float.corner_radius_level2'))
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor(this.sourceColor(record.source))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (isHistory) {
        Text(this.formatTime(record.time))
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }

      if (!this.selectionMode) {
        SongMoreMenu({
          song: {
            songId: record.songId, name: record.name, singer: record.singer,
            albumName: record.albumName, albumId: record.albumId, source: record.source,
            interval: record.interval, img: record.img, types: []
          },
          iconSize: 18,
          // 换源后立刻重建列表，保证平台标签/封面实时更新
          onSongSwitched: (): void => {
            this.forceReload();
          }
        })
      }
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 4, right: 4 })
    .onClick(() => {
      if (this.selectionMode) {
        this.toggleSelect(record, !this.isSelected(record));
        return;
      }
      void OnlinePlayUtil.playRecord(this.appState, record, this.getUIContext());
    })
  }

  /** 删除/全选等标题栏按钮的磨砂强度，跟随软件内沉浸光感设置（与浮层迷你播放器一致）。 */
  private titleButtonBlur(): BlurStyle {
    switch (this.ambientState.level) {
      case 1:
        return BlurStyle.Thin;
      case 2:
        return BlurStyle.Regular;
      case 3:
        return BlurStyle.Thick;
      default:
        return BlurStyle.Thin;
    }
  }

  @Builder
  private TitleStackBuilder() {
    Row({ space: 10 }) {
      Text($r('app.string.playlist_home_title'))
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .margin({ right: 6 })

      if (this.selectionMode) {
        Blank()
        Text(this.selectedCount() === this.activeList().length && this.activeList().length > 0 ?
          '取消全选' : '全选')
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius($r('sys.float.corner_radius_level12'))
          .backgroundColor($r('sys.color.background_primary'))
          .onClick(() => {
            this.toggleSelectAll();
          })
        Text(this.selectedCount() > 0 ? '删除(' + this.selectedCount() + ')' : '删除')
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedCount() > 0 ? $r('sys.color.font_on_primary') : $r('sys.color.font_tertiary'))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius($r('sys.float.corner_radius_level12'))
          .backgroundColor(this.selectedCount() > 0 ? this.themeState.color : $r('app.color.floating_mini_bar_background'))
          .backgroundBlurStyle(this.selectedCount() > 0 ? BlurStyle.NONE : this.titleButtonBlur())
          .onClick(() => {
            this.deleteSelected();
          })
        Text('取消')
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 4, right: 4 })
          .onClick(() => {
            this.exitSelectionMode();
          })
      } else {
        Text($r('app.string.playlist_home_history'))
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(this.currentSection === 0 ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.currentSection === 0 ? $r('sys.color.font_on_primary') : $r('sys.color.font_secondary'))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius($r('sys.float.corner_radius_level12'))
          .backgroundColor(this.currentSection === 0 ? this.themeState.color : $r('sys.color.background_primary'))
          .onClick(() => {
            this.selectSection(0);
          })

        Text($r('app.string.playlist_home_favorites'))
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(this.currentSection === 1 ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.currentSection === 1 ? $r('sys.color.font_on_primary') : $r('sys.color.font_secondary'))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius($r('sys.float.corner_radius_level12'))
          .backgroundColor(this.currentSection === 1 ? this.themeState.color : $r('sys.color.background_primary'))
          .onClick(() => {
            this.selectSection(1);
          })

        Blank()

        if (this.activeList().length > 0) {
          Row() {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(20)
              .fontWeight(FontWeight.Regular)
              .height(20)
              .fontColor([$r('sys.color.font_primary')])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.floating_mini_bar_background'))
          .backgroundBlurStyle(this.titleButtonBlur())
          .borderWidth(1)
          .borderColor('#33FFFFFF')
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.enterSelectionMode();
          })
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  /** HDS title bar with system material and gradient blur. */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    return {
      // ★ 2026-10-11 真机定论（设置页截图量出来的）：HDS 标题栏容器本来就在状态栏下沿，
      //   voidLayoutSafeArea: true 会让它**再退一个状态栏**（标题 76..132）⇒ 恒为 false（标题 38..94）。
      avoidLayoutSafeArea: false,
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        stackBuilder: (): void => {
          this.TitleStackBuilder()
        }
      }
    };
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.currentSection === 0) {
          if (this.historyList.length === 0) {
            Column({ space: 8 }) {
              Text($r('app.string.playlist_home_history_empty'))
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_tertiary'))
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else {
            List({ space: 2, scroller: this.pageScroller }) {
              ForEach(this.historyList, (record: PlayedSongRecord) => {
                ListItem() {
                  this.SongRow(record, true)
                }
              }, (record: PlayedSongRecord) => this.listVersion + '_' + record.source + '_' + record.songId)
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            // ★★ 让内容能画进状态栏的**官方正解**（官方《开发应用沉浸式效果》→「滚动类场景」）：
            //   「设置父组件滚动容器和子组件相同的背景色，设置滚动容器的内容裁剪属性
            //    `clipContent(ContentClipMode.SAFE_AREA)`，**将内容层裁剪区域扩展至避让区**。」
            //   原来写 `.clip(true)`（List 默认 `CONTENT_ONLY`，按内容区裁）⇒ 行滚到状态栏就被裁掉。
            //   ⚠️ 链上任何祖先都**不能**再写 `clip(true)`（官方："需要确保父组件未设置 clip 等裁剪属性"）。
            .clipContent(ContentClipMode.SAFE_AREA)
            .divider({
              strokeWidth: 0.5,
              color: $r('sys.color.comp_divider'),
              startMargin: 16,
              endMargin: 16
            })
            // ★ 定稿（用户：「我想让它延伸进状态栏」）："状态栏 + HDS 标题栏"（≈38 + 56 = 94）
            //   这一整段留白**放进滚动内容里**（页根带 `ignoreLayoutSafeArea(TOP,BOTTOM)` ⇒ 盒子从
            //   屏幕 y=0 起排，标题栏自己让位到 38..94）⇒ 偏移 = 状态栏 + 56 = 94。
            //   静止时第一行正好落在标题栏下沿，上滑则整行从标题栏底下再穿进状态栏。
            .contentStartOffset(getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP)
            // ★ 底部"给悬浮播放条让位"的留白留在**列表里**（`contentEndOffset`，@since 22，
            //   List/Scroll 通用）：随内容一起滚走。原来写的是**列表末尾一个 64vp 的 ListItem**，
            //   效果一样，这里换成与 `RecordListPage` / `SettingsDetailPage` 同一口径。
            //   反面做法（禁）：写在外层容器的 `padding({ bottom })` 上 = 屏幕底部一条死带。
            .contentEndOffset(64)
          }
        } else {
          if (this.favoriteList.length === 0) {
            Column({ space: 8 }) {
              Text($r('app.string.playlist_home_favorites_empty'))
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_tertiary'))
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else {
            List({ space: 2, scroller: this.pageScroller }) {
              ForEach(this.favoriteList, (record: PlayedSongRecord) => {
                ListItem() {
                  this.SongRow(record, false)
                }
              }, (record: PlayedSongRecord) => this.listVersion + '_' + record.source + '_' + record.songId)
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            // ★ 同上一支：`clip(true)` → `clipContent(ContentClipMode.SAFE_AREA)`，理由见上面的注释。
            .clipContent(ContentClipMode.SAFE_AREA)
            .divider({
              strokeWidth: 0.5,
              color: $r('sys.color.comp_divider'),
              startMargin: 16,
              endMargin: 16
            })
            // ★ 同一支的偏移算式（= 状态栏 + 56 = 94），理由见上面那处 contentStartOffset。
            .contentStartOffset(getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP)
            // ★ 同一支的底部留白，理由见上面那处 contentEndOffset（必须留在列表里，随内容滚走）。
            .contentEndOffset(64)
          }
        }
      }
      .width('100%')
      .height('100%')
      // ⚠️ 这里原来写 `.clip(true)`（上一轮"要挡住内容"的错误口径下加的）**已删除** ——
      //   官方《开发应用沉浸式效果》：「子节点可以单独设置该属性……**需要确保父组件未设置 clip
      //   等裁剪属性**」⇒ 祖先有一层 `clip(true)`，上面两支 List 的
      //   `clipContent(ContentClipMode.SAFE_AREA)` 就白设了。
      //   （两支 `List` 自己默认的裁剪语义保持不变，别再动。）
      .padding({
        // ★ 状态栏那一条归页面（2026-10-11 第二十轮，用户：「我想让它延伸进状态栏」）：
        //   这里是**内容容器**，顶部 padding 已删 —— 容器从屏幕 y=0 起排、List 拿整屏视口，
        //   "状态栏 + 标题栏"那段留白改由上面两处 `contentStartOffset(状态栏 + 56)` 提供。
        left: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
        right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint)
      })
    }
    .onBackPressed((): boolean => guardPlayerBack('PlaylistHomePage'))
    .hideTitleBar(false)
    .hideBackButton(true)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    // ★★ 状态栏三件套（2026-10-11 定稿，用户第三次纠正后）：
    //   ① `expandSafeArea(TOP,BOTTOM)`：把**页面底色**铺到状态栏/导航条那两条（只扩绘制区）；
    //   ② `ignoreLayoutSafeArea(...[TOP, BOTTOM])` —— **TOP 必须给**：HDS 的标题栏自己会按"状态栏高度"
    //      往下让位，所以**页面盒子必须从屏幕 y=0 起排**；只写 BOTTOM 变成"盒子让一次 + 标题栏再让一次"
    //      ⇒ 整条标题掉到状态栏下面约一个状态栏高度（用户原话「整个标题移到了状态栏下面」），
    //      内容也跟着多顶 38vp（「上方留的空距有点大了」）。
    //      盒子从 0 起排后：标题栏 = 38..94 ✔，上面两处 `contentStartOffset` 的 94 正好落在 94 ✔
    //      （这就是它们**必须**写「状态栏 + 56」而不是只写 56 的原因；顶部那段留白**不要**改回容器 padding）。
    //      ⚠️ 旧注释里"根节点带 TOP 会把 HDS 标题栏顶进状态栏 / 只能留 BOTTOM"那句**是错的**，已作废。
    //   ③ 滚动容器 `clipContent(ContentClipMode.SAFE_AREA)` + 祖先链零 `clip(true)`：行能**画进**状态栏。
    // ★★ 用户 2026-10-11：「顶栏标题错位的问题还在，你应该参考一下其他显示正常的页面是怎么写的」。
    //   逐页对比后：显示正常的 MinePage / RecommendPage **都没有** expandSafeArea，
    //   而所有标题偏低的页面都有 ⇒ 照正常页面去掉它（官方语义：expandSafeArea 只延伸**绘制区**，
    //   「子组件相对屏幕位置不变」，但它会让 HDS 标题栏的定位多让一次）。
    //   页面底色由页盒自身 ackgroundColor 铺满（盒顶 = 0，实测见 RzdPageTopInset），不需要它补状态栏那一条。
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'))
  }
}
