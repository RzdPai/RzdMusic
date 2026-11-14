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

import { AppStorageV2 } from '@kit.ArkUI';
import { AmbientState, AppStorageKeys, MusicAppState, MusicStoreService, PlayedSongRecord, PlaylistDto, SongItem, ThemeState } from 'musicbasic';
import { DownloadUtil, LXQualityOption, LXSearchSong, MediaService, OnlinePlayUtil, lxGetQualityOptions } from 'player';
import { notifyPlaylistChanged } from '../util/PlaylistRefreshBus';

/**
 * Shared "more" button + popup menu for song rows: play, download,
 * add to playlist, and add to favorites.
 */
@ComponentV2
export struct SongMoreMenu {
  /** Song data shown in the menu actions. */
  @Param song: LXSearchSong = {
    songId: '', name: '', singer: '', albumName: '', albumId: '',
    source: '', interval: '', img: '', types: []
  };
  /** Optional icon size override. */
  @Param iconSize: number = 20;
  /** Optional icon color. */
  @Param iconColor: ResourceColor = $r('app.color.font_tertiary');
  /** Playlist id when the song belongs to a user playlist; enables the delete action. */
  @Param playlistId: string = '';
  /** Callback invoked after a song is deleted from the playlist. */
  @Param onSongDeleted: (() => void) | null = null;

  /** Global music app state for playback requests. */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** Local store for playlists and favorites. */
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  /** When true the bottom sheet is shown. */
  @Local showSheet: boolean = false;
  /** Active sheet content: 1 = download quality, 2 = add-to-playlist picker. */
  @Local sheetType: number = 0;
  /** Download quality sheet: loading flag + resolved quality/size options. */
  @Local qualityLoading: boolean = false;
  @Local qualityOptions: LXQualityOption[] = [];
  /** Playlists snapshot shown in the picker sheet. */
  @Local playlists: PlaylistDto[] = [];
  /** New playlist name input. */
  @Local newPlaylistName: string = '';
  /** App accent color for buttons. */
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** Ambient material level driving the popup frosted glass strength. */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  /** Frosted glass strength of the popup, following the ambient light level. */
  private menuBlur(): BlurStyle {
    switch (this.ambientState.level) {
      case 1:
        return BlurStyle.Thin;
      case 2:
        return BlurStyle.Regular;
      case 3:
        return BlurStyle.Thick;
      default:
        return BlurStyle.Regular;
    }
  }

  /** Plays the song via the LX engine. */
  private playSong(): void {
    void OnlinePlayUtil.playSearchSong(this.appState, this.song, this.getUIContext());
  }

  /** 打开下载音质弹层：先实时拉取音质+大小（mg3 同款流程）。 */
  private async openQualitySheet(): Promise<void> {
    this.sheetType = 1;
    this.qualityLoading = true;
    this.qualityOptions = [];
    this.showSheet = true;
    try {
      const opts: LXQualityOption[] = await lxGetQualityOptions(this.song);
      opts.sort((a: LXQualityOption, b: LXQualityOption): number => a.size - b.size);
      this.qualityOptions = opts;
    } catch (_e) {
      this.qualityOptions = [];
    }
    this.qualityLoading = false;
    if (this.qualityOptions.length === 0) {
      this.showSheet = false;
      this.toast('该歌曲暂无可用音质');
    }
  }

  /** Downloads the song at the chosen quality. */
  private downloadSongQuality(quality: string): void {
    this.showSheet = false;
    void DownloadUtil.downloadSong(this.song.source, this.song.songId, this.song.name, this.song.singer,
      quality, this.getUIContext(), this.song.img, this.song.albumName);
  }

  /** 字节 -> x.xMB（MyApplication3 同款）。 */
  private formatSize(bytes: number): string {
    if (bytes <= 0) {
      return '';
    }
    return (bytes / (1024 * 1024)).toFixed(1) + 'MB';
  }

  /** 下载音质弹层：音质/大小/选择 行（标题由 bindSheet 原生 title 提供，与播放详情页一致）。 */
  @Builder
  private QualitySheet() {
    Column() {
      if (this.qualityLoading) {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(20)
            .height(20)
          Text('获取音质信息...')
            .fontSize(13)
            .fontColor($r('app.color.font_tertiary'))
        }
        .width('100%')
        .height(56)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 2 }) {
          ForEach(this.qualityOptions, (q: LXQualityOption) => {
            ListItem() {
              Row() {
                Text(q.type)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.font_primary'))
                Blank()
                if (q.size > 0) {
                  Text(this.formatSize(q.size))
                    .fontSize(13)
                    .fontColor($r('app.color.font_tertiary'))
                }
              }
              .width('100%')
              .padding({ left: 4, right: 4, top: 13, bottom: 13 })
              .onClick(() => {
                this.downloadSongQuality(q.type);
              })
            }
          }, (q: LXQualityOption) => q.type)
        }
        .width('100%')
        .height(this.qualityOptions.length * 50)
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  /**
   * bindSheet 原生标题（X 关闭按钮由系统保证跟标题水平对齐，与播放详情页同款）。
   * sheetType: 1 = 下载音质 → "选择下载音质"; 2 = 添加到歌单 → "添加到歌单"。
   */
  private sheetTitle(): SheetTitleOptions {
    if (this.sheetType === 2) {
      return { title: '添加到歌单' };
    }
    return { title: '选择下载音质' };
  }

  /** 按 sheetType 渲染对应弹层内容（单组件只能挂一个 bindSheet）。 */
  @Builder
  private ActiveSheet() {
    if (this.sheetType === 1) {
      this.QualitySheet()
    } else if (this.sheetType === 2) {
      this.PlaylistPickerSheet()
    }
  }

  /** Popup menu items for the song actions. */
  private menuItems(): MenuElement[] {
    const items: MenuElement[] = [
      {
        value: '播放',
        action: (): void => {
          this.playSong();
        }
      },
      {
        value: '下载',
        action: (): void => {
          this.openQualitySheet();
        }
      },
      {
        value: '添加到歌单',
        action: (): void => {
          this.openPlaylistPicker();
        }
      },
      {
        value: '添加到收藏',
        action: (): void => {
          this.addFavorite();
        }
      },
      {
        value: '添加到播放列表',
        action: (): void => {
          this.addToPlayQueue();
        }
      }
    ];
    if (this.playlistId.length > 0) {
      items.push({
        value: '从歌单中删除',
        action: (): void => {
          this.deleteFromPlaylist();
        }
      });
    }
    return items;
  }

  /** Adds the song to favorites. */
  private addFavorite(): void {
    const record = new PlayedSongRecord();
    record.songId = this.song.songId;
    record.name = this.song.name;
    record.singer = this.song.singer;
    record.albumName = this.song.albumName;
    record.albumId = this.song.albumId;
    record.source = this.song.source;
    record.interval = this.song.interval;
    record.img = this.song.img;
    // 搜歌结果未播放就收藏,quality 留空;后续播放时 refreshFavoriteQuality 自动回填。
    record.quality = '';
    record.time = Date.now();
    this.store.addFavorite(record);
    this.toast('已添加到收藏');
  }

  /** Removes the song from the playlist it belongs to. */
  private deleteFromPlaylist(): void {
    if (this.playlistId.length === 0) {
      return;
    }
    this.store.removeSongFromPlaylist(this.playlistId, this.song.source, this.song.songId);
    notifyPlaylistChanged();
    this.toast('已从歌单中删除');
    if (this.onSongDeleted !== null) {
      this.onSongDeleted();
    }
  }

  /** Appends the song to the current play queue without starting playback. */
  private addToPlayQueue(): void {
    if (this.song.source.length === 0) {
      this.toast('无法添加本地歌曲');
      return;
    }
    const item = new SongItem();
    item.id = Date.now();
    item.title = this.song.name;
    item.singer = this.song.singer;
    item.source = this.song.source;
    item.songId = this.song.songId;
    item.albumId = this.song.albumId;
    item.albumName = this.song.albumName;
    item.cover = this.song.img;
    item.url = '';
    item.lyricText = '';
    const queue = this.appState.playQueue;
    for (let i = 0; i < queue.length; i++) {
      if (queue[i].source === item.source && queue[i].songId === item.songId) {
        this.toast('已在播放列表中');
        return;
      }
    }
    this.appState.playQueue = [...queue, item];
    this.toast('已添加到播放列表');
  }

  /** Opens the add-to-playlist picker sheet. */
  private openPlaylistPicker(): void {
    this.playlists = this.store.getPlaylists();
    this.newPlaylistName = '';
    this.sheetType = 2;
    this.showSheet = true;
  }

  /** Adds the song to a playlist. */
  private addToPlaylist(p: PlaylistDto): void {
    const record = new PlayedSongRecord();
    record.songId = this.song.songId;
    record.name = this.song.name;
    record.singer = this.song.singer;
    record.albumName = this.song.albumName;
    record.albumId = this.song.albumId;
    record.source = this.song.source;
    record.interval = this.song.interval;
    record.img = this.song.img;
    record.time = Date.now();
    const added: boolean = this.store.addSongToPlaylist(p.id, record);
    if (added) {
      // 显式通知列表页重读：仅靠 @Monitor('store.playlistVersion') 时列表数量不刷新
      notifyPlaylistChanged();
    }
    this.toast(added ? '已添加到「' + p.name + '」' : '歌单中已有该歌曲');
    this.showSheet = false;
  }

  /** Creates a playlist and adds the song. */
  private createPlaylistWithSong(): void {
    const name: string = this.newPlaylistName.trim();
    if (name.length === 0) {
      return;
    }
    const p = this.store.createPlaylist(name);
    this.addToPlaylist(p);
    this.newPlaylistName = '';
  }

  /** Add-to-playlist picker sheet content（布局与播放详情页 PlaylistPickerRows 完全一致，标题由 bindSheet 原生 title 提供）. */
  @Builder
  private PlaylistPickerSheet() {
    Column() {
      TextInput({ text: this.newPlaylistName, placeholder: '请输入歌单名称' })
        .width('100%')
        .height(44)
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .margin({ top: 4, bottom: 12 })
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

      if (this.playlists.length > 0) {
        Blank().height(12)

        Scroll() {
          Column({ space: 2 }) {
            ForEach(this.playlists, (p: PlaylistDto) => {
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
      }

      // 底部返回按钮：关闭弹层（与播放详情页同款文字样式）
      Row() {
        Text('返回')
          .fontSize(15)
          .fontColor($r('app.color.font_tertiary'))
      }
      .width('100%')
      .height(44)
      .margin({ top: 16 })
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.showSheet = false;
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 24 })
    .backgroundColor($r('app.color.background_secondary'))
  }

  /** More button + popup menu. */
  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.dot_grid_1x2_circle'))
        .fontSize(this.iconSize)
        .fontColor([this.iconColor])
    }
    .bindMenu(this.menuItems(), {
      backgroundBlurStyle: this.menuBlur()
    })
    .bindSheet($$this.showSheet, this.ActiveSheet(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: false,
      // 用 bindSheet 原生 title 区域显示标题，X 关闭按钮由系统保证跟标题水平对齐（与播放详情页一致）
      title: this.sheetTitle(),
      backgroundColor: $r('app.color.background_secondary'),
      onWillDismiss: (action: DismissSheetAction) => {
        action.dismiss();
        this.showSheet = false;
      }
    })
  }
}
