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
import { AlbumRouteParam, AmbientState, AppStorageKeys, ArtistRouteParam, BreakpointType, FavoriteEntry, MusicAppState, MusicStoreService, PlayedSongRecord, RouterUrlConstants, ThemeState, TitleBarConstants, buildTitleMaterial, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';
import { OnlinePlayUtil, sourceToCode } from 'player';
import { PlatformMusicPage } from '../account/PlatformMusicPage';
import { DownloadManagerSection } from './DownloadManagerSection';
import { CapsuleSegmentedSelector } from './CapsuleSegmentedSelector';

/**
 * Mine tab: the "我的" page with history / favorites (multi-select delete),
 * platform music and download manager segments.
 */

@ComponentV2
export struct MinePage {
  /** Window breakpoint for the HDS home-style responsive title. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /** 共享播放状态（记录行播放用）。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** 我的分段：0=播放历史，1=收藏，2=平台音乐，3=下载管理。 */
  @Local recordSection: number = 0;
  /** 标题栏分段按钮选项（SegmentButtonV2）。 */
  @Local segmentLabels: string[] = ['播放历史', '收藏', '平台音乐', '下载管理'];
  /** 当前分段的播放记录快照。 */
  @Local records: PlayedSongRecord[] = [];
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  @Local favoriteArtists: FavoriteEntry[] = [];
  @Local favoriteAlbums: FavoriteEntry[] = [];
  /** 多选删除模式。 */
  @Local selectionMode: boolean = false;
  /** 多选勾选表（key = source_songId）。 */
  @Local selectedMap: Record<string, boolean> = {};
  /** 平台音乐刷新信号（标题栏刷新按钮触发）。 */
  @Local platformRefreshSignal: number = 0;
  /** Scroller bound to the HDS title bar so the scroll effect (gradient blur) can fire. */
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.refreshRecords();
  }

  /** 历史/收藏版本变化时刷新当前分段列表。 */
  @Monitor('store.historyVersion', 'store.favoriteVersion')
  refreshRecords(): void {
    if (this.recordSection === 0) {
      this.records = this.normalizeRecords(this.store.getHistory());
      this.favoriteArtists = [];
      this.favoriteAlbums = [];
    } else {
      this.records = this.normalizeRecords(this.store.getFavorites());
      this.favoriteArtists = this.store.getFavoriteArtists();
      this.favoriteAlbums = this.store.getFavoriteAlbums();
    }
  }

  /** 播放一条历史/收藏记录（复用在线播放编排）。 */
  private playRecord(record: PlayedSongRecord): void {
    void OnlinePlayUtil.playRecord(this.appState, record, this.getUIContext());
  }

  /** 多选 key。 */
  private songKeyOf(record: PlayedSongRecord): string {
    return record.source + '_' + record.songId;
  }

  private isSelected(record: PlayedSongRecord): boolean {
    return this.selectedMap[this.songKeyOf(record)] === true;
  }

  /** Toggles selection of one entry. */
  private toggleSelect(record: PlayedSongRecord, on: boolean): void {
    const next: Record<string, boolean> = {};
    const keys: string[] = Object.keys(this.selectedMap);
    for (let i: number = 0; i < keys.length; i++) {
      next[keys[i]] = this.selectedMap[keys[i]];
    }
    next[this.songKeyOf(record)] = on;
    this.selectedMap = next;
  }

  /** Selected keys. */
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

  /** Count of selected entries. */
  private selectedCount(): number {
    return this.selectedIds().length;
  }

  /** Enters multi-select mode. */
  private enterSelectionMode(): void {
    this.selectionMode = true;
    this.selectedMap = {};
  }

  /** Exits multi-select mode and clears the selection. */
  private exitSelectionMode(): void {
    this.selectionMode = false;
    this.selectedMap = {};
  }

  /** Selects or clears all entries of the current segment. */
  private toggleSelectAll(): void {
    const next: Record<string, boolean> = {};
    const selectAll: boolean = this.selectedCount() < this.records.length;
    if (selectAll) {
      for (let i: number = 0; i < this.records.length; i++) {
        next[this.songKeyOf(this.records[i])] = true;
      }
    }
    this.selectedMap = next;
  }

  /** Deletes selected entries: history ids batch; favorites one by one. */
  private deleteSelected(): void {
    const ids: string[] = this.selectedIds();
    if (ids.length > 0) {
      if (this.recordSection === 0) {
        this.store.removeHistoryByIds(ids);
      } else {
        for (let i: number = 0; i < this.records.length; i++) {
          if (this.isSelected(this.records[i])) {
            this.store.removeFavorite(this.records[i].source, this.records[i].songId);
          }
        }
      }
    }
    this.exitSelectionMode();
  }

  /** 多选模式操作条：全选 / 删除(n) / 取消。 */
  @Builder
  private SelectionBar() {
    Row({ space: 12 }) {
      Text(this.selectedCount() === this.records.length && this.records.length > 0 ? '取消全选' : '全选')
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
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
        .backgroundColor(this.selectedCount() > 0 ? this.themeState.color : '#1A000000')
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
      Blank()
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  /** 单条播放记录行（多选模式下带勾选框）。 */
  @Builder
  private RecordRow(record: PlayedSongRecord) {
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
      if ((record.img ?? '').length > 0) {
        Image(record.img)
          .width(40)
          .height(40)
          .borderRadius($r('sys.float.corner_radius_level3'))
          .objectFit(ImageFit.Cover)
      } else {
        Row() {
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(16)
            .fontColor([$r('sys.color.font_tertiary')])
        }
        .width(40)
        .height(40)
        .borderRadius($r('sys.float.corner_radius_level3'))
        .backgroundColor($r('sys.color.background_tertiary'))
        .justifyContent(FlexAlign.Center)
      }
      Column({ space: 2 }) {
        Text(record.name)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(((record.singer ?? '').length > 0 ? record.singer : ''))
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (!this.selectionMode) {
        Column({ space: 4 }) {
          // 音质（与时长同色同字号；无 quality 时显示 "—"）
          Text(this.qualityLabel(record.quality))
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
          // 平台标签（与搜索 SongRowItem 位置/样式/颜色一致）
          Text(this.platformLabel(record.source))
            .fontSize($r('sys.float.Caption_S'))
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius($r('sys.float.corner_radius_level2'))
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor(this.platformColor(record.source))
        }
        .alignItems(HorizontalAlign.Center)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_tertiary')])
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      if (this.selectionMode) {
        this.toggleSelect(record, !this.isSelected(record));
        return;
      }
      this.playRecord(record);
    })
  }

  /** Maps an LX source id to a short Chinese platform label for the history / favorite row. */
  private platformLabel(source: string | undefined): string {
    const src: string = source ?? '';
    switch (src) {
      case 'kw': return '酷我';
      case 'kg': return '酷狗';
      case 'tx': return 'QQ';
      case 'wy': return '网易';
      case 'mg': return '咪咕';
      default: return src.length > 0 ? src : '其他';
    }
  }

  /** Returns a brand color per platform so the tag is recognizable.
 *  Matches the OnlineSearchPage SongRowItem sourceColor mapping exactly. */
  private platformColor(source: string | undefined): string {
    switch (source ?? '') {
      case 'kw': return '#FF6B35';
      case 'kg': return '#4A90D9';
      case 'tx': return '#31C27C';
      case 'wy': return '#C62F2F';
      case 'mg': return '#FF4081';
      default: return '#8C9095';
    }
  }

  /** Maps a LX quality id to a short Chinese label. */
  private normalizeRecords(list: PlayedSongRecord[]): PlayedSongRecord[] {
    for (let i: number = 0; i < list.length; i++) {
      const r: PlayedSongRecord = list[i];
      r.name = r.name ?? '';
      r.singer = r.singer ?? '';
      r.source = r.source ?? '';
      r.songId = r.songId ?? '';
      r.img = r.img ?? '';
      r.albumName = r.albumName ?? '';
      r.url = r.url ?? '';
      r.quality = r.quality ?? '';
      r.playScript = r.playScript ?? '';
    }
    return list;
  }

  /** Section header used by the three favorite groups (歌手 / 专辑 / 歌曲). */
  @Builder
  private FavoriteGroupHeader(title: string, count: number) {
    Row({ space: 8 }) {
      Text(title)
        .fontSize($r('sys.float.Subtitle_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(count > 0 ? String(count) : '')
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_tertiary'))
      Blank()
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 12, bottom: 6 })
  }

  /** One favorite artist / album row: cover, name, subtitle and a remove action. */
  @Builder
  private FavoriteEntryRow(entry: FavoriteEntry, isAlbum: boolean) {
    Row({ space: 12 }) {
      Image(entry.img.length > 0 ? entry.img : $r('app.media.ic_avatar1'))
        .width(52)
        .height(52)
        .borderRadius(isAlbum ? $r('sys.float.corner_radius_level3') : 26)
        .objectFit(ImageFit.Cover)
        .backgroundColor($r('app.color.card_background'))
      Column({ space: 4 }) {
        Text(entry.name)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(entry.sub.length > 0 ? entry.sub : (isAlbum ? '专辑' : '歌手'))
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .height(18)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .width('100%')
    .height(68)
    .padding({ left: 4, right: 4 })
    .onClick(() => {
      this.openFavoriteDetail(entry, isAlbum);
    })
  }

  /** Opens the artist / album detail page for a favorite entry. */
  private openFavoriteDetail(entry: FavoriteEntry, isAlbum: boolean): void {
    const code: number = sourceToCode(entry.source);
    if (isAlbum) {
      const param: AlbumRouteParam = new AlbumRouteParam();
      param.source = code;
      param.id = entry.id;
      param.name = entry.name;
      param.picUrl = entry.img;
      param.artistName = entry.sub;
      this.pageScroller.scrollEdge(Edge.Top);
      this.pageIndexInfos.pushPathByName(RouterUrlConstants.ALBUM_DETAIL, param);
      return;
    }
    const param: ArtistRouteParam = new ArtistRouteParam();
    param.source = code;
    param.id = entry.id;
    param.name = entry.name;
    param.picUrl = entry.img;
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.ARTIST_DETAIL, param);
  }

  private qualityLabel(quality: string | undefined): string {
    const q: string = quality ?? '';
    switch (q) {
      case '128k': return '128k';
      case '320k': return '320k';
      case 'flac': return 'FLAC';
      case 'flac24bit': return 'Hi-Res';
      default: return q.length > 0 ? q : '—';
    }
  }

  /** HDS 标题栏第二行分段按钮：与设置页同款胶囊选择器。 */
  @Builder
  private SegmentBarBuilder() {
    Column() {
      CapsuleSegmentedSelector({
        labels: this.segmentLabels,
        selectedIndex: this.recordSection,
        accentColor: this.themeState.color,
        onSelect: (index: number): void => {
          this.recordSection = index;
          this.refreshRecords();
        }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
  }

  /** HDS title bar: same style as the playlists page; menu buttons follow the active segment. */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    const menus: HdsNavigationMenuItemOptions[] = [];
    if (this.recordSection === 2) {
      menus.push({
        content: {
          label: 'refresh',
          icon: $r('sys.symbol.arrow_clockwise'),
          isEnabled: true,
          action: (): void => {
            this.platformRefreshSignal++;
          }
        }
      });
    }
    if ((this.recordSection === 0 || this.recordSection === 1) && this.records.length > 0 && !this.selectionMode) {
      menus.push({
        content: {
          label: 'delete',
          icon: $r('sys.symbol.trash'),
          isEnabled: true,
          action: (): void => {
            this.enterSelectionMode();
          }
        }
      });
    }
    const bar: HdsNavigationTitleBarOptions = {
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
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        title: {
          mainTitle: $r('app.string.mine_title'),
          mainTitleSize: TitleSize.TITLE_ML
        },
        menu: {
          value: menus
        },
        bottomBuilder: {
          builder: (): void => {
            this.SegmentBarBuilder()
          }
        }
      }
    };
    return bar;
  }

  private sectionTopOffset(): number {
    return getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP + 48;
  }

  build() {
    HdsNavDestination() {
      Stack() {
        if (this.recordSection === 2) {
          Column() {
            PlatformMusicPage({
              onClose: (): void => {},
              refreshSignal: this.platformRefreshSignal,
              contentTopOffset: this.sectionTopOffset(),
              pageScroller: this.pageScroller
            })
          }
          .width('100%')
          .layoutWeight(1)
          .padding({
            left: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
            right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
            bottom: 56 + 16 + 16
          })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        } else if (this.recordSection === 3) {
          Column() {
            DownloadManagerSection({ contentTopOffset: this.sectionTopOffset(), pageScroller: this.pageScroller })
          }
          .width('100%')
          .layoutWeight(1)
          .padding({
            left: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
            right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
            bottom: 56 + 16 + 16
          })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        } else {
          // 与平台音乐/下载管理分段同结构：内容视口从标题栏下方开始，
          // 滑动/回弹时列表行不会穿到标题栏后面（顶部不遮挡）。
          Column() {
            List({ space: 2, scroller: this.pageScroller }) {
              if (this.selectionMode) {
                ListItem() {
                  this.SelectionBar()
                }
              }
            if (this.recordSection === 1 && this.favoriteArtists.length > 0) {
              ListItem() {
                this.FavoriteGroupHeader('歌手', this.favoriteArtists.length)
              }
              ForEach(this.favoriteArtists, (entry: FavoriteEntry) => {
                ListItem() {
                  this.FavoriteEntryRow(entry, false)
                }
              }, (entry: FavoriteEntry) => 'fa_' + entry.source + '_' + entry.id)
            }
            if (this.recordSection === 1 && this.favoriteAlbums.length > 0) {
              ListItem() {
                this.FavoriteGroupHeader('专辑', this.favoriteAlbums.length)
              }
              ForEach(this.favoriteAlbums, (entry: FavoriteEntry) => {
                ListItem() {
                  this.FavoriteEntryRow(entry, true)
                }
              }, (entry: FavoriteEntry) => 'fb_' + entry.source + '_' + entry.id)
            }
            if (this.recordSection === 1) {
              ListItem() {
                this.FavoriteGroupHeader('歌曲', this.records.length)
              }
            }
            Repeat<PlayedSongRecord>(this.records)
              .each((obj: RepeatItem<PlayedSongRecord>) => {
                ListItem() {
                  this.RecordRow(obj.item)
                }
              })
              .key((item: PlayedSongRecord) => (this.recordSection === 0 ? 'h_' : 'f_') + item.source + '_' + item.songId)
            if (this.records.length === 0) {
              ListItem() {
                Text(this.recordSection === 0 ? '暂无播放历史' : '暂无收藏歌曲')
                  .fontSize($r('sys.float.Caption_L'))
                  .fontColor($r('sys.color.font_tertiary'))
                  .width('100%')
                  .padding({ top: 16, bottom: 16 })
              }
            }
            ListItem() {
              Column()
                // 底部预留：悬浮 Tab 条(barHeight 56 + 底部间距 16)叠在内容上，再多留 16 呼吸空间
                .height(56 + 16 + 16)
                .width('100%')
            }
          }
          .width('100%')
          .layoutWeight(1)
          .contentStartOffset(this.sectionTopOffset())
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .clip(true)
          .divider({
            strokeWidth: 0.5,
            color: $r('sys.color.comp_divider'),
            startMargin: 16,
            endMargin: 16
          })
          .padding({
            left: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
            right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint)
            })
          }
          .width('100%')
          .height('100%')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        }
      }
      .width('100%')
      .height('100%')
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
