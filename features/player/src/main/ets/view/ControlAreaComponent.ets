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
import { AVCastPicker } from '@kit.AVSessionKit';
import { AppStorageKeys, ArtistRouteParam, BreakpointType, isWidthBreakpointLgOrXl, MusicStoreService, PlayedSongRecord, PlaylistDto, RouterUrlConstants, SongItem, StyleConstants, ThemeState } from 'musicbasic';
import { PlayerConstants } from '../constant/PlayerConstants';
import { MusicPlayMode } from '../model/MusicData';
import { PlayerDataUtil } from '../util/PlayerDataUtil';
import { PlayerViewModel } from '../viewmodel/PlayerViewModel';
import { DownloadUtil } from '../util/DownloadUtil';
import { buildSongShareText, showSystemShare } from '../util/ShareUtil';
import { sourceToCode } from '../geuz/index';
import { QueuePlaylistSheet } from './QueuePlaylistSheet';
import { EXTENDED_QUALITIES } from '../util/SourceFallbackUtil';

/** Full-screen transport: progress, main controls, and auxiliary icon row inside a single bottom panel. */
@ComponentV2
export struct ControlAreaComponent {
  /** Navigation stack from shell for opening playlist / song list routes. */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Window breakpoint for responsive control sizing. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** View model for seek and transport delegation. */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** Mirrors MediaService play mode for SymbolGlyph (order / single cycle / shuffle). */
  @Local playMode: MusicPlayMode = MusicPlayMode.ORDER;
  /** When false, hides the bottom “other actions�?placeholder row (e.g. album-gradient full-screen layout). */
  @Param showBottomOtherRow: boolean = true;
  /** Controls the song menu bottom sheet (quality / singer / album / share). */
  @Local showMenuSheet: boolean = false;
  /** When true, shows the current play queue as a bottom sheet. */
  @Local showPlaylistSheet: boolean = false;
  /** When true the menu sheet shows the quality sub-list instead of the main menu. */
  @Local showMenuQuality: boolean = false;
  /** Quality sub-list mode: 'download' picks a quality to download, 'switch' sets playback quality. */
  @Local menuQualityMode: string = 'switch';
  /** 添加到歌单选择器显示状态。 */
  @Local showMenuPlaylist: boolean = false;
  /** 选择器中的歌单列表。 */
  @Local playlistOptions: PlaylistDto[] = [];
  /** 新建歌单名称输入。 */
  @Local newPlaylistName: string = '';
  /** 本地歌单存储（添加到歌单复用 MusicStoreService 现成接口）。 */
  private store: MusicStoreService = MusicStoreService.getInstance();
  /** App accent color for menu highlights. */
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;

  /** Opens the song menu main list. */
  private openMenuSheet(): void {
    this.menuQualityMode = 'switch';
    this.showMenuQuality = false;
    this.showMenuSheet = true;
  }

  /** Opens the quality sub-list in download mode. */
  private openDownloadQuality(): void {
    this.menuQualityMode = 'download';
    this.showMenuQuality = true;
    this.showMenuSheet = true;
  }

  /** Closes the whole menu sheet and resets the sub-list. */
  /** 打开添加到歌单选择器。 */
  private openPlaylistPicker(): void {
    this.playlistOptions = this.store.getPlaylists();
    this.newPlaylistName = '';
    this.showMenuPlaylist = true;
  }

  /** 当前歌曲加入指定歌单。 */
  private addToPlaylist(p: PlaylistDto): void {
    const song = this.currentSong();
    if (song === undefined) {
      return;
    }
    const record = new PlayedSongRecord();
    record.songId = song.songId;
    record.name = typeof song.title === 'string' ? song.title : '';
    record.singer = typeof song.singer === 'string' ? song.singer : '';
    record.source = song.source;
    record.img = song.cover;
    record.time = Date.now();
    const added: boolean = this.store.addSongToPlaylist(p.id, record);
    this.getUIContext().getPromptAction().showToast({
      message: added ? '已添加到「' + p.name + '」' : '歌单中已有该歌曲',
      duration: 2000
    });
    this.showMenuPlaylist = false;
  }

  /** 新建歌单并加入当前歌曲。 */
  private createPlaylistWithSong(): void {
    const name: string = this.newPlaylistName.trim();
    if (name.length === 0) {
      return;
    }
    const p = this.store.createPlaylist(name);
    this.addToPlaylist(p);
  }

  private closeMenuSheet(): void {
    this.showMenuPlaylist = false;
    this.showMenuSheet = false;
    this.showMenuQuality = false;
  }

  /** Current song for menu info rows (singer / album). */
  private currentSong(): SongItem | undefined {
    return this.playerViewModel.appState.getCurrentSongItem();
  }

  /** File size text of the current song for the given quality; empty when unknown. */
  private currentQualitySize(quality: string): string {
    const song = this.currentSong();
    if (song === undefined) {
      return '';
    }
    const list = song.qualityList;
    for (let i = 0; i < list.length; i++) {
      if (list[i].type === quality) {
        const n: number = Number(list[i].size) || 0;
        if (n > 0) {
          return (n / (1024 * 1024)).toFixed(1) + 'MB';
        }
        return '';
      }
    }
    return '';
  }

  /** Opens the system share panel with the current song info and its link. */
  private shareCurrentSong(): void {
    const song = this.currentSong();
    const title: string = song !== undefined && typeof song.title === 'string' ? song.title : '未知歌曲';
    const singer: string = song !== undefined && typeof song.singer === 'string' ? song.singer : '未知歌手';
    const source: string = song !== undefined ? song.source : '';
    const songId: string = song !== undefined ? song.songId : '';
    showSystemShare(this.getUIContext(), buildSongShareText(title, singer, source, songId), '歌曲分享');
  }

  /** Current song singer text for the menu info rows. */
  private currentSinger(): string {
    const song = this.currentSong();
    return song !== undefined && typeof song.singer === 'string' ? song.singer : '未知歌手';
  }

  /** Current song album text for the menu info rows. */
  private currentAlbum(): string {
    const song = this.currentSong();
    if (song !== undefined && song.albumName.length > 0) {
      return song.albumName;
    }
    return '未知专辑';
  }

  /** Opens the artist detail page with the current singer name and song source. */
  private searchCurrentSinger(): void {
    const singer: string = this.currentSinger();
    if (singer.length > 0 && singer !== '未知歌手') {
      const song = this.currentSong();
      const param = new ArtistRouteParam();
      param.source = sourceToCode(song !== undefined && typeof song.source === 'string' ? song.source : '');
      param.name = singer;
      this.playerViewModel.appState.isShowPlay = false;
      this.pageIndexInfos.pushPathByName(RouterUrlConstants.ARTIST_DETAIL, param);
    }
  }

  /** Opens the online search page with the current album name. */
  private searchCurrentAlbum(): void {
    const song = this.currentSong();
    const album: string = song !== undefined ? song.albumName : '';
    if (album.length > 0) {
      this.playerViewModel.appState.isShowPlay = false;
      this.pageIndexInfos.pushPathByName(RouterUrlConstants.ONLINE_SEARCH, album);
    }
  }

  private activeQ(): string {
    const live: string = AppStorage.get<string>('lxPlayQuality') ?? '';
    return live.length > 0 ? live : MusicStoreService.getInstance().getPlayQuality();
  }

  private extendedOn(): boolean {
    return (AppStorage.get<boolean>('lxExtendedEnabled') ?? false) ||
      MusicStoreService.getInstance().getPlayExtendedEnabled();
  }

  private extendedQ(): string {
    const live: string = AppStorage.get<string>('lxExtendedQuality') ?? '';
    return live.length > 0 ? live : MusicStoreService.getInstance().getPlayExtendedQuality();
  }

  aboutToAppear(): void {
    const store: MusicStoreService = MusicStoreService.getInstance();
    AppStorage.setOrCreate('lxPlayQuality', this.activeQ());
    AppStorage.setOrCreate('lxExtendedEnabled', this.extendedOn());
    AppStorage.setOrCreate('lxExtendedQuality', this.extendedQ());
    if (this.extendedQ().length === 0) {
      AppStorage.setOrCreate('lxExtendedQuality', store.getPlayExtendedQuality());
    }
  }

  /** Sets the playback quality and persists it (extended tiers routed separately). */
  private setPlayQuality(q: string): void {
    if (EXTENDED_QUALITIES.indexOf(q) >= 0) {
      AppStorage.setOrCreate('lxExtendedQuality', q);
      AppStorage.setOrCreate('lxExtendedEnabled', true);
      MusicStoreService.getInstance().setPlayExtendedQuality(q);
      MusicStoreService.getInstance().setPlayExtendedEnabled(true);
    } else {
      AppStorage.setOrCreate('lxPlayQuality', q);
      MusicStoreService.getInstance().setPlayQuality(q);
    }
    this.showMenuQuality = false;
    this.showMenuSheet = false;
    this.getUIContext().getPromptAction().showToast({ message: '已切换音质 ' + q, duration: 2000 });
  }

  /** sys.symbol.repeat | repeat_1 | shuffle per MusicPlayMode. */
  private playModeSymbol(): Resource {
    switch (this.playMode) {
      case MusicPlayMode.ORDER:
        return $r('sys.symbol.repeat');
      case MusicPlayMode.SINGLE_CYCLE:
        return $r('sys.symbol.repeat_1');
      case MusicPlayMode.RANDOM:
        return $r('sys.symbol.shuffle');
      default:
        return $r('sys.symbol.repeat');
    }
  }

  @Builder
  private bottomOtherGlyph(symbol: Resource, label: string, action: () => void = (): void => {}) {
    SymbolGlyph(symbol)
      .fontSize(22)
      .fontWeight(FontWeight.Regular)
      .fontColor([$r('app.color.play_text_color')])
      .accessibilityText(label)
      .accessibilityLevel('yes')
      .onClick(() => {
        action();
      })
  }

  /** Custom cast picker icon, sized to match the other bottom-row glyphs. */
  @Builder
  private castPickerIcon() {
    SymbolGlyph($r('sys.symbol.shareplay'))
      .fontSize(22)
      .fontWeight(FontWeight.Regular)
      .fontColor([$r('app.color.play_text_color')])
      .accessibilityText('投播')
      .accessibilityLevel('yes')
  }

  /** Progress, transport, and optional auxiliary icons grouped per playback-page layout spec. */
  @Builder
  bottomPanel() {
    Column() {
      Column() {
        Slider({
          min: 0,
          max: this.playerViewModel.appState.progressMax,
          step: 1,
          value: this.playerViewModel.appState.progress
        })
          .blockColor($r('app.color.slider_block'))
          .selectedColor($r('app.color.slider_select'))
          .trackColor($r('app.color.slider_track'))
          .blockSize({
            width: $r('app.float.slider_block'),
            height: $r('app.float.slider_block')
          })
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Begin ||
              mode === SliderChangeMode.Click) {
              this.playerViewModel.seek(value);
            }
            this.playerViewModel.appState.pageShowTime = 0;
          })
          .height($r('app.float.slider_height'))
          .margin({
            left: new BreakpointType(
              $r('app.float.slider_margin_sm'),
              $r('app.float.slider_margin_md'),
              $r('app.float.slider_margin_lg'),
              $r('app.float.slider_margin_lg')
            ).getValue(this.breakpointEnv.widthBreakpoint),
            right: new BreakpointType(
              $r('app.float.slider_margin_sm'),
              $r('app.float.slider_margin_md'),
              $r('app.float.slider_margin_lg'),
              $r('app.float.slider_margin_lg')
            ).getValue(this.breakpointEnv.widthBreakpoint)
          })
          .hitTestBehavior(HitTestMode.Block)
        Row() {
          Text(this.playerViewModel.appState.currentTime)
            .fontColor($r('app.color.play_text_color'))
            .fontSize($r('app.float.singer_title_sm'))
            .fontFamily(PlayerConstants.FONT_FAMILY_BLACK)
            .lineHeight('14vp')
          Blank()
          // 当前音质徽标：显示实际播放音质（含自动降级），位于两个时长中央
          Text(this.playerViewModel.appState.currentQuality.length > 0 ?
            this.playerViewModel.appState.currentQuality : '128k')
            .fontSize(11)
            .fontColor($r('app.color.play_text_color'))
            .lineHeight(16)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(10)
            .backgroundColor('rgba(255, 255, 255, 0.12)')
          Blank()
          Text(this.playerViewModel.appState.totalTime)
            .fontColor($r('app.color.play_text_color'))
            .fontSize($r('app.float.singer_title_sm'))
            .fontFamily(PlayerConstants.FONT_FAMILY_BLACK)
            .lineHeight('14vp')
        }
        .width(StyleConstants.FULL_WIDTH)
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .margin({
        top: this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
          this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD ? 0 : $r('app.float.slider_margin_top'),
        bottom: isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ?
          $r('app.float.slider_margin_bottom_lg') : this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
            this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD ? 8 : $r('app.float.slider_margin_bottom')
      })

      Row() {
        SymbolGlyph(this.playModeSymbol())
          .fontSize(isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ? 26 : 24)
          .fontWeight(FontWeight.Regular)
          .fontColor([$r('app.color.play_text_color')])
          .accessibilityText('播放模式')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.playMode = PlayerDataUtil.cyclePlayMode();
            this.playerViewModel.appState.pageShowTime = 0;
          })
        Image($r('app.media.ic_public_forward'))
          .controlImageBuilder()
          .width(isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ?
            $r('app.float.control_width_lg') : $r('app.float.control_width'))
          .accessibilityText('上一首')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.playerViewModel.playPrevious();
            this.playerViewModel.appState.pageShowTime = 0;
          })
        Image(this.playerViewModel.appState.isPlay ? $r('app.media.ic_public_play') : $r('app.media.ic_public_pause'))
          .controlImageBuilder()
          .width(new BreakpointType(
            $r('app.float.image_play_width'),
            $r('app.float.image_play_width'),
            $r('app.float.image_play_width_lg'),
            $r('app.float.image_play_width_lg')
          ).getValue(this.breakpointEnv.widthBreakpoint))
          .accessibilityText(this.playerViewModel.appState.isPlay ? '播放' : '暂停')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.playerViewModel.togglePlayPause();
            this.playerViewModel.appState.pageShowTime = 0;
          })
        Image($r('app.media.ic_public_next'))
          .controlImageBuilder()
          .width(isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ?
            $r('app.float.control_width_lg') : $r('app.float.control_width'))
          .accessibilityText('下一首')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.playerViewModel.playNext();
            this.playerViewModel.appState.pageShowTime = 0;
          })
        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize(isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ? 26 : 24)
          .fontWeight(FontWeight.Regular)
          .fontColor([$r('app.color.play_text_color')])
          .accessibilityText('播放列表')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.showPlaylistSheet = true;
            this.playerViewModel.appState.pageShowTime = 0;
          })
      }
      .width(StyleConstants.FULL_WIDTH)
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.showBottomOtherRow) {
        Row({ space: 0 }) {
          AVCastPicker({
            normalColor: '#99FFFFFF',
            activeColor: '#99FFFFFF',
            customPicker: (): void => {
              this.castPickerIcon()
            }
          })
            .width(40)
            .height(40)
          this.bottomOtherGlyph($r('sys.symbol.bell'), '通知')
          this.bottomOtherGlyph($r('sys.symbol.arrow_down_circle'), '下载', (): void => {
            this.openDownloadQuality();
          })
          this.bottomOtherGlyph($r('sys.symbol.dot_grid_1x2_circle'), '更多', (): void => {
            this.openMenuSheet();
          })
        }
        .width(StyleConstants.FULL_WIDTH)
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({
          top: 32
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .borderRadius(16)
    .padding({
      top: 8,
      left: 4,
      right: 4
    })
  }

  /** Song menu sheet: main menu (quality / singer / album / share) and quality sub-list. */
  @Builder
  private MenuSheet() {
    Column({ space: 4 }) {
      if (this.showMenuPlaylist) {
        this.PlaylistPickerRows()
      } else if (this.showMenuQuality) {
        Text(this.menuQualityMode === 'download' ? '选择下载音质' : '切换音质')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .margin({ top: 8, bottom: 12 })

        ForEach(['128k', '320k', 'flac', 'flac24bit', 'hires', 'atmos', 'atmos_plus', 'master'], (q: string) => {
          Row() {
            Text(q)
              .fontSize(16)
              .fontColor($r('app.color.font_primary'))
            Blank()
            if (this.menuQualityMode === 'download' && this.currentQualitySize(q).length > 0) {
              Text(this.currentQualitySize(q))
                .fontSize(13)
                .fontColor($r('app.color.font_tertiary'))
                .margin({ right: 10 })
            }
            if (this.activeQ() === q ||
              (EXTENDED_QUALITIES.indexOf(q) >= 0 && this.extendedOn() &&
                this.extendedQ() === q)) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(18)
                .fontColor([this.themeState.color])
            }
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .borderRadius(10)
          .backgroundColor($r('app.color.background_secondary'))
          .onClick(() => {
            if (this.menuQualityMode === 'download') {
              this.closeMenuSheet();
              void DownloadUtil.downloadCurrentSong(this.playerViewModel.appState, q, this.getUIContext());
            } else {
              this.setPlayQuality(q);
            }
          })
        }, (q: string) => 'menuq-' + q)

        if (this.menuQualityMode === 'switch') {
          Row() {
            Text('返回')
              .fontSize(15)
              .fontColor($r('app.color.font_tertiary'))
          }
          .width('100%')
          .height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showMenuQuality = false;
          })
        }
      } else {
        Text('歌曲菜单')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .margin({ top: 8, bottom: 12 })

        this.MenuRow(this.currentSinger(), $r('sys.symbol.person_crop_circle_fill_1'), (): void => {
          this.closeMenuSheet();
          this.searchCurrentSinger();
        })
        this.MenuRow(this.currentAlbum(), $r('sys.symbol.music_note_list'), (): void => {
          this.closeMenuSheet();
          this.searchCurrentAlbum();
        })
        this.MenuRow('添加到歌单', $r('sys.symbol.plus'), (): void => {
          this.openPlaylistPicker();
        })
        this.MenuRow($r('app.string.player_menu_quality'), $r('sys.symbol.gearshape_fill'),
          (): void => {
            this.menuQualityMode = 'switch';
            this.showMenuQuality = true;
          })
        this.MenuRow($r('app.string.player_menu_share'), $r('sys.symbol.share'),
          (): void => {
            this.closeMenuSheet();
            this.shareCurrentSong();
          })
      }

      Button('取消')
        .width('100%')
        .height(44)
        .fontSize(15)
        .borderRadius(10)
        .backgroundColor($r('app.color.background_secondary'))
        .fontColor($r('app.color.font_tertiary'))
        .margin({ top: 8 })
        .onClick(() => {
          this.closeMenuSheet();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 24 })
    .backgroundColor($r('app.color.background_secondary'))
  }

  /** 添加到歌单选择器内容：新建歌单输入 + 歌单列表。 */
  @Builder
  private PlaylistPickerRows() {
    TextInput({ text: this.newPlaylistName, placeholder: '请输入歌单名称' })
      .width('100%')
      .height(44)
      .borderRadius(10)
      .padding({ left: 12, right: 12 })
      .margin({ top: 8 })
      .onChange((value: string) => {
        this.newPlaylistName = value;
      })

    Button('新建并添加')
      .width('100%')
      .height(40)
      .fontSize(14)
      .borderRadius(10)
      .backgroundColor(this.themeState.color)
      .fontColor(Color.White)
      .onClick(() => {
        this.createPlaylistWithSong();
      })

    if (this.playlistOptions.length > 0) {
      Scroll() {
        Column({ space: 2 }) {
          ForEach(this.playlistOptions, (p: PlaylistDto) => {
            Row() {
              Text(p.name)
                .fontSize(15)
                .fontColor($r('app.color.font_primary'))
                .maxLines(1)
                .layoutWeight(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(p.songs.length + ' 首')
                .fontSize(12)
                .fontColor($r('app.color.font_tertiary'))
            }
            .width('100%')
            .height(44)
            .padding({ left: 14, right: 14 })
            .borderRadius(10)
            .backgroundColor($r('app.color.background_secondary'))
            .onClick(() => {
              this.addToPlaylist(p);
            })
          }, (p: PlaylistDto) => p.id)
        }
        .width('100%')
      }
      .height(170)
      .scrollBar(BarState.Off)
      .margin({ top: 8 })
    }
  }

  /** One menu row: icon + label, tap triggers the given action. */
  @Builder
  private MenuRow(label: string | Resource, icon: Resource, action: () => void) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontWeight(FontWeight.Regular)
        .fontColor([$r('app.color.font_primary')])
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.font_primary'))
      Blank()
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('app.color.font_tertiary')])
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .borderRadius(10)
    .backgroundColor($r('app.color.background_secondary'))
    .onClick(() => {
      action();
    })
  }

  build() {
    Column() {
      this.bottomPanel()
      QueuePlaylistSheet({
        isShow: this.showPlaylistSheet,
        onDismiss: (): void => {
          this.showPlaylistSheet = false;
        }
      })
    }
    .onAppear(() => {
      this.playMode = PlayerDataUtil.getPlayMode();
    })
    .bindSheet($$this.showMenuSheet, this.MenuSheet(), {
      height: 360,
      dragBar: true,
      showClose: false,
      backgroundColor: $r('app.color.background_secondary')
    })
  }
}

@Extend(Image)
function controlImageBuilder() {
  .aspectRatio(1)
  .opacity(0.86)
  .objectFit(ImageFit.Contain)
}
