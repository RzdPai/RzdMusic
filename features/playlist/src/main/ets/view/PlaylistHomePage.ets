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
import { AmbientState, BreakpointType, ThemeState } from 'musicbasic';
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
      avoidLayoutSafeArea: true,
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
              ListItem() {
                Column()
                  .height(64)
                  .width('100%')
              }
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .clip(false)
            .divider({
              strokeWidth: 0.5,
              color: $r('sys.color.comp_divider'),
              startMargin: 16,
              endMargin: 16
            })
            .contentStartOffset(getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP)
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
              ListItem() {
                Column()
                  .height(64)
                  .width('100%')
              }
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .clip(false)
            .divider({
              strokeWidth: 0.5,
              color: $r('sys.color.comp_divider'),
              startMargin: 16,
              endMargin: 16
            })
            .contentStartOffset(getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP)
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding({
        left: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
        right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint)
      })
    }
    .hideTitleBar(false)
    .hideBackButton(true)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
