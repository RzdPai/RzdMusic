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
import { CommentPanel } from 'comment';
import type { CommentSongRef } from 'comment';

/**
 * 半模态「重新打开」的冷却时间（ms）。
 *
 * 弹层关闭是带动画的（约 300ms），动画没走完就把 isShow 置回 true，
 * 框架会把它当成同一次关闭处理 —— 表现是「刚弹出来立刻又收回去」。
 * 取略大于动画时长，用户几乎感知不到（只有「刚关完马上再点」才会等这几十毫秒）。
 */
const SHEET_REOPEN_GUARD_MS: number = 360;

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
  /**
   * 歌曲菜单里的「查看评论」子页。
   *
   * 一个组件只能挂一个 bindSheet（菜单弹层已经占用了），所以评论和「切换音质」
   * 「添加到歌单」一样是**同一个弹层里的一个子页**，靠这个标志切换。
   */
  @Local showMenuComment: boolean = false;
  /** 上一次弹层关闭动画结束的时间戳（见 {@link openSheetFor} 的冷却逻辑）。 */
  private sheetClosedAtMs: number = 0;
  /** 选择器中的歌单列表。 */
  @Local playlistOptions: PlaylistDto[] = [];
  /** 新建歌单名称输入。 */
  @Local newPlaylistName: string = '';
  /** 本地歌单存储（添加到歌单复用 MusicStoreService 现成接口）。 */
  private store: MusicStoreService = MusicStoreService.getInstance();
  /** App accent color for menu highlights. */
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;

  /**
   * 打开菜单弹层里的某个子页前，先把**其它**子页标志清掉。
   *
   * ⚠️ 这是踩过的 bug：只置位、不清位时，`MenuSheet()` 里排在最前面的
   *    `showMenuComment` 还是 true —— 于是「打开过一次评论之后，再点下载按钮
   *    弹出来的还是评论」。所有子页入口都必须先过这里。
   */
  private resetMenuSubPages(): void {
    this.showMenuComment = false;
    this.showMenuPlaylist = false;
    this.showMenuQuality = false;
    this.menuQualityMode = 'switch';
  }

  /**
   * 打开菜单弹层并切到指定子页（'menu' / 'quality' / 'qualityDownload' / 'playlist' / 'comment'）。
   *
   * ⚠️ 不能在关闭动画还没走完时把 isShow 置回 true：框架内部还在收，
   *    表现就是「弹层刚弹出来立刻又收回去」。用户实际踩到过：
   *    评论 → 关闭 → 下载 → 关闭 → 评论，第三次会闪一下就没。
   *    所以这里用 `onDisappear` 记下的时间戳做一次冷却（关着的时候点，几乎无感；
   *    刚关完就点，就多等那几十毫秒把关闭动画让过去）。
   */
  private openSheetFor(page: string): void {
    this.resetMenuSubPages();
    if (page === 'quality') {
      this.showMenuQuality = true;
    } else if (page === 'qualityDownload') {
      this.menuQualityMode = 'download';
      this.showMenuQuality = true;
    } else if (page === 'playlist') {
      this.playlistOptions = this.store.getPlaylists();
      this.newPlaylistName = '';
      this.showMenuPlaylist = true;
    } else if (page === 'comment') {
      this.showMenuComment = true;
    }
    if (this.showMenuSheet) {
      return;   // 已经开着：只切子页
    }
    const since: number = Date.now() - this.sheetClosedAtMs;
    if (since >= SHEET_REOPEN_GUARD_MS) {
      this.showMenuSheet = true;
      return;
    }
    setTimeout((): void => {
      this.showMenuSheet = true;
    }, SHEET_REOPEN_GUARD_MS - since);
  }

  /** Opens the song menu main list. */
  private openMenuSheet(): void {
    this.openSheetFor('menu');
  }

  /** Opens the quality sub-list in download mode. */
  private openDownloadQuality(): void {
    this.openSheetFor('qualityDownload');
  }

  /** 打开评论子页（播放页底部那颗「评论」按钮用它）。 */
  private openCommentSheet(): void {
    this.openSheetFor('comment');
  }

  /** 打开添加到歌单选择器。 */
  private openPlaylistPicker(): void {
    this.openSheetFor('playlist');
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
    this.showMenuComment = false;
  }

  /**
   * 当前歌的平台身份（评论面板用）。
   *
   * 在线歌直接把 source + songId 交给评论面板；本地音乐（source = 'local'）交给
   * 面板内部的解析器去查匹配记录（解析器由产品壳层注册，见 `features/comment`）。
   */
  private currentSongRef(): CommentSongRef {
    const song = this.currentSong();
    const ref: CommentSongRef = {
      source: song !== undefined && typeof song.source === 'string' ? song.source : '',
      songId: song !== undefined ? song.songId : '',
      name: song !== undefined && typeof song.title === 'string' ? song.title : '',
      singer: song !== undefined && typeof song.singer === 'string' ? song.singer : ''
    };
    return ref;
  }

  /** 评论面板的换歌标识：值变了面板会重新拉评论。 */
  private currentSongKey(): string {
    const ref: CommentSongRef = this.currentSongRef();
    return ref.source + '_' + ref.songId;
  }

  /** Current song for menu info rows (singer / album). */
  private currentSong(): SongItem | undefined {
    return this.playerViewModel.appState.getCurrentSongItem();
  }

  /**
   * 音质徽标文案。
   *
   * ⚠️ 本地歌必须**按歌曲本身**判断，不能只看 `appState.currentQuality`：
   *    那个字段是播放时写的，重启后恢复上次播放的本地歌、或从歌单/队列播本地歌时
   *    以前可能还是空的，于是徽标掉到 '128k' 兜底 —— 用户看到的就是
   *    「本地歌的音质重启后变成 128K」。
   */
  private currentQualityLabel(): string {
    const song = this.currentSong();
    if (song !== undefined && (song.source === 'local' || song.quality === 'local')) {
      return 'local';
    }
    const live: string = this.playerViewModel.appState.currentQuality;
    if (live.length > 0) {
      return live;
    }
    if (song !== undefined && song.quality.length > 0) {
      return song.quality;
    }
    return '128k';
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

  /**
   * 自定义投播图标。
   *
   * 尺寸/字重/颜色**必须**与 {@link bottomOtherGlyph} 完全一致，否则这一排里
   * 投播会明显比另外三个大一圈（用户反馈的就是这个）。
   * 这里和旁边三个一样只给 fontSize，不额外加 padding、也不包容器。
   */
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
          // 当前音质徽标：本地歌显示「本地」，在线歌显示实际播放音质（含自动降级）
          Text(this.currentQualityLabel())
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
          // 投播：AVCastPicker 会自己画一个容器，不给尺寸时它比旁边 22vp 的 SymbolGlyph
          // 大一圈。这里把宽高钉成 24（图标 22 + 各 1vp 余量），并让 customPicker
          // 只负责画图标本体，这样四个按钮的视觉大小才一致。
          AVCastPicker({
            normalColor: '#99FFFFFF',
            activeColor: '#99FFFFFF',
            customPicker: (): void => {
              this.castPickerIcon()
            }
          })
            .width(24)
            .height(24)
          // 这一排现在是「投播 / 下载 / 评论 / 更多」四个真入口。
          // 原来第二颗铃铛（通知）是没接功能的占位，用户要求把它换掉：铃铛去掉，
          // 下载左移一位，空出来的位置放「评论」——比藏在「更多」里少点两下。
          this.bottomOtherGlyph($r('sys.symbol.arrow_down_circle'), '下载', (): void => {
            this.openDownloadQuality();
          })
          this.bottomOtherGlyph($r('sys.symbol.text_bubble_left_2'), '评论', (): void => {
            this.openCommentSheet();
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
      if (this.showMenuComment) {
        // 评论子页：面板根节点是 height('100%')，所以外面这层容器也必须是**确定高度**
        // （弹层内容区的高度就是弹层高度，用 height('100%') 才对；用 layoutWeight
        //  在这里会拿到 0 —— 弹层内容根节点是按内容包高度的，不是弹性容器）。
        Column() {
          CommentPanel({
            song: this.currentSongRef(),
            songKey: this.currentSongKey(),
            showHeader: true,
            onClose: (): void => {
              // 评论已经是底部工具行的一级入口，返回箭头直接收起弹层
              this.closeMenuSheet();
            }
          })
        }
        .width('100%')
        .height('100%')
      } else if (this.showMenuPlaylist) {
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
            this.openSheetFor('quality');
          })
        this.MenuRow($r('app.string.player_menu_share'), $r('sys.symbol.share'),
          (): void => {
            this.closeMenuSheet();
            this.shareCurrentSong();
          })
        // 「查看评论」已经从菜单里**移除**：播放页底部工具行新增了「评论」按钮，
        // 一级入口比藏在这里少点两下（用户明确要求）。
      }

      // 评论子页自带标题栏与关闭，不再叠一个「取消」，否则底部被吃掉一大块
      if (!this.showMenuComment) {
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
    }
    .width('100%')
    // 评论子页要**铺满弹层**：左右/下方留内边距的话，大图层四周会露出一圈弹层底色
    // （用户反馈的「屏幕左右以及下方的黑边」就是这层内边距）。菜单本身仍然留白。
    .padding(this.showMenuComment ?
      { left: 0, right: 0, bottom: 0 } : { left: 16, right: 16, bottom: 24 })
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
      // 评论子页要整屏高度才够看（列表 + 两个页签）；菜单本身保持固定 360
      height: this.showMenuComment ? SheetSize.LARGE : 360,
      dragBar: true,
      showClose: false,
      backgroundColor: $r('app.color.background_secondary'),
      onDisappear: (): void => {
        // 记下关闭动画结束的时刻（重新打开的冷却用），顺手把子页状态清干净
        this.sheetClosedAtMs = Date.now();
        this.resetMenuSubPages();
      }
    })
  }
}

@Extend(Image)
function controlImageBuilder() {
  .aspectRatio(1)
  .opacity(0.86)
  .objectFit(ImageFit.Contain)
}
