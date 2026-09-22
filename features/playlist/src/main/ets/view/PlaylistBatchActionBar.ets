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
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AppStorageKeys,
  BreakpointType,
  MusicAppState,
  MusicStoreService,
  PlayedSongRecord,
  PlaylistDto,
  SongItem,
  StyleConstants,
  ThemeState,
  getWindowInfoState,
  WindowInfo
} from 'musicbasic';
import { DownloadUtil, LXQualityOption, LXSearchSong, lxGetQualityOptions } from 'player';
import { PlaylistBatchSelectionStore } from '../model/PlaylistBatchSelectionStore';
import { PlaylistSongUi } from '../model/PlaylistUiModels';
import { notifyPlaylistChanged } from '../util/PlaylistRefreshBus';

const BATCH_LOG_DOMAIN: number = 0x0000;
const BATCH_LOG_TAG: string = 'RzdPlaylistBatchBar';

/**
 * 批量操作条（MusicFree 同款）。
 *
 * **必须由宿主页面放在屏幕底部的固定位置**（页面 `Column` 中与 `Scroll` 同级的下方），
 * 不要放进列表/滚动内容里 —— 那样它会跟着内容滚，看起来像"贴在列表底部"。
 *
 * 形态（照抄 musicfreeOH 的歌曲级批量底栏）：
 *   第一行：`已选 N 首歌曲` + 右侧 `取消`
 *   第二行：等宽胶囊按钮 `全选/取消全选` · `下一首播放` · `收藏`
 *   第三行：等宽胶囊按钮 `添加到歌单` · `下载`（本地歌单追加 `删除`）
 * 按钮尺寸：高 36、圆角 10、字号 11、`layoutWeight(1)`。
 */
@ComponentV2
export struct PlaylistBatchActionBar {
  /** 当前窗口断点，用于左右内边距。 */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** 多选共享状态（与歌曲列表同一个实例）。 */
  @Param batch: PlaylistBatchSelectionStore = new PlaylistBatchSelectionStore();
  /** 当前可见（已过滤/已排序）的歌曲，用于全选与"按列表顺序取已选"。 */
  @Param displaySongs: PlaylistSongUi[] = [];
  /** 歌单 id；非空时才能批量删除。 */
  @Param playlistId: string = '';
  /** 是否允许批量删除（本地歌单为 true）。 */
  @Param allowBatchDelete: boolean = false;
  /** 退出多选回调（宿主据此隐藏迷你条等）。 */
  @Param onExit: () => void = (): void => {};
  /** 批量删除完成回调（宿主重新加载列表）。 */
  @Param onDeleted: () => void = (): void => {};

  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** 窗口信息：底部安全区（导航条/小白条）用于模糊层与内边距避让。 */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** 「添加到歌单」弹层。 */
  @Local showPlaylistPicker: boolean = false;
  @Local playlists: PlaylistDto[] = [];
  @Local newPlaylistName: string = '';
  /** 「下载」音质弹层。 */
  @Local showQualityPicker: boolean = false;
  @Local qualityLoading: boolean = false;
  @Local qualityOptions: LXQualityOption[] = [];

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  /** 是否已全选当前可见行。 */
  private isAllSelected(): boolean {
    return this.displaySongs.length > 0 && this.batch.keys.length >= this.displaySongs.length;
  }

  /** 全选 / 取消全选。 */
  private toggleSelectAll(): void {
    if (this.isAllSelected()) {
      this.batch.keys = [];
      return;
    }
    const keys: string[] = [];
    for (let i: number = 0; i < this.displaySongs.length; i++) {
      keys.push(this.displaySongs[i].selectionKey());
    }
    this.batch.keys = keys;
  }

  /** 按列表顺序取出已选中的行（批量操作与用户视觉顺序一致）。 */
  private selectedSongs(): PlaylistSongUi[] {
    const result: PlaylistSongUi[] = [];
    for (let i: number = 0; i < this.displaySongs.length; i++) {
      const row: PlaylistSongUi = this.displaySongs[i];
      if (this.batch.has(row.selectionKey())) {
        result.push(row);
      }
    }
    return result;
  }

  /** 行 -> 队列项（批量「下一首播放」用）。 */
  private toQueueItem(row: PlaylistSongUi): SongItem {
    const item = new SongItem();
    item.id = Date.now() + Math.floor(Math.random() * 1000);
    item.title = typeof row.title === 'string' ? row.title : '';
    item.singer = typeof row.singer === 'string' ? row.singer : '';
    item.source = row.source;
    item.songId = row.songId;
    item.albumId = row.albumId;
    item.albumName = row.albumName;
    item.cover = row.coverUrl;
    item.url = '';
    item.lyricText = '';
    return item;
  }

  /** 行 -> 存储记录（批量添加到歌单 / 收藏用）。 */
  private toRecord(row: PlaylistSongUi): PlayedSongRecord {
    const record = new PlayedSongRecord();
    record.songId = row.songId;
    record.name = typeof row.title === 'string' ? row.title : '';
    record.singer = typeof row.singer === 'string' ? row.singer : '';
    record.albumName = row.albumName;
    record.albumId = row.albumId;
    record.source = row.source;
    record.interval = row.interval;
    record.img = row.coverUrl;
    record.quality = '';
    record.time = Date.now();
    return record;
  }

  /** 行 -> 在线歌曲模型（音质查询用）。 */
  private toSearchSong(row: PlaylistSongUi): LXSearchSong {
    return {
      songId: row.songId,
      name: typeof row.title === 'string' ? row.title : '',
      singer: typeof row.singer === 'string' ? row.singer : '',
      albumName: row.albumName,
      albumId: row.albumId,
      source: row.source,
      interval: row.interval,
      img: row.coverUrl,
      types: []
    };
  }

  /**
   * 批量插入到「下一首」位置（不是追加队尾）：
   * 从当前播放位置之后依次插入，保持用户勾选顺序。
   */
  private batchPlayNext(): void {
    const rows: PlaylistSongUi[] = this.selectedSongs();
    if (rows.length === 0) {
      this.toast('请先勾选歌曲');
      return;
    }
    const queue: SongItem[] = [...this.appState.playQueue];
    let insertAt: number = this.appState.selectIndex + 1;
    if (insertAt < 0 || insertAt > queue.length) {
      insertAt = queue.length;
    }
    let added: number = 0;
    for (let i: number = 0; i < rows.length; i++) {
      const item: SongItem = this.toQueueItem(rows[i]);
      if (item.source.length === 0) {
        continue;
      }
      let duplicated: boolean = false;
      for (let j: number = 0; j < queue.length; j++) {
        if (queue[j].source === item.source && queue[j].songId === item.songId) {
          duplicated = true;
          break;
        }
      }
      if (duplicated) {
        continue;
      }
      queue.splice(insertAt + added, 0, item);
      added++;
    }
    this.appState.playQueue = queue;
    hilog.info(BATCH_LOG_DOMAIN, BATCH_LOG_TAG,
      'batch play-next requested=%{public}d inserted=%{public}d at=%{public}d', rows.length, added, insertAt);
    this.toast(added > 0 ? '已插入 ' + added + ' 首到下一首播放' : '所选歌曲已在播放列表中');
    this.onExit();
  }

  /** 批量添加到收藏。 */
  private batchAddFavorite(): void {
    const rows: PlaylistSongUi[] = this.selectedSongs();
    if (rows.length === 0) {
      this.toast('请先勾选歌曲');
      return;
    }
    const store: MusicStoreService = MusicStoreService.getInstance();
    for (let i: number = 0; i < rows.length; i++) {
      store.addFavorite(this.toRecord(rows[i]));
    }
    hilog.info(BATCH_LOG_DOMAIN, BATCH_LOG_TAG, 'batch favorite count=%{public}d', rows.length);
    this.toast('已收藏 ' + rows.length + ' 首');
    this.onExit();
  }

  /** 打开批量「添加到歌单」弹层。 */
  private openPlaylistPicker(): void {
    if (this.selectedSongs().length === 0) {
      this.toast('请先勾选歌曲');
      return;
    }
    this.playlists = MusicStoreService.getInstance().getPlaylists();
    this.newPlaylistName = '';
    this.showPlaylistPicker = true;
  }

  /** 把已选歌曲添加到某个歌单。 */
  private addSelectedToPlaylist(p: PlaylistDto): void {
    const rows: PlaylistSongUi[] = this.selectedSongs();
    const store: MusicStoreService = MusicStoreService.getInstance();
    let added: number = 0;
    for (let i: number = 0; i < rows.length; i++) {
      if (store.addSongToPlaylist(p.id, this.toRecord(rows[i]))) {
        added++;
      }
    }
    notifyPlaylistChanged();
    hilog.info(BATCH_LOG_DOMAIN, BATCH_LOG_TAG, 'batch add to playlist name=%{public}s added=%{public}d',
      p.name, added);
    this.showPlaylistPicker = false;
    this.toast(added > 0 ? '已添加 ' + added + ' 首到「' + p.name + '」' : '「' + p.name + '」中已有这些歌曲');
    this.onExit();
  }

  /** 新建歌单并把已选歌曲加入。 */
  private createPlaylistWithSelected(): void {
    const name: string = this.newPlaylistName.trim();
    if (name.length === 0) {
      return;
    }
    const p: PlaylistDto = MusicStoreService.getInstance().createPlaylist(name);
    this.newPlaylistName = '';
    this.addSelectedToPlaylist(p);
  }

  /** 打开批量下载音质弹层（实时拉取音质与大小）。 */
  private async openBatchQualitySheet(): Promise<void> {
    const rows: PlaylistSongUi[] = this.selectedSongs();
    if (rows.length === 0) {
      this.toast('请先勾选歌曲');
      return;
    }
    this.qualityLoading = true;
    this.qualityOptions = [];
    this.showQualityPicker = true;
    try {
      const opts: LXQualityOption[] = await lxGetQualityOptions(this.toSearchSong(rows[0]));
      opts.sort((a: LXQualityOption, b: LXQualityOption): number => a.size - b.size);
      this.qualityOptions = opts;
    } catch (_err) {
      this.qualityOptions = [];
    }
    this.qualityLoading = false;
    if (this.qualityOptions.length === 0) {
      this.showQualityPicker = false;
      this.toast('该歌曲暂无可用音质');
    }
  }

  /** 按选定音质批量下载已选歌曲。 */
  private batchDownload(quality: string): void {
    const rows: PlaylistSongUi[] = this.selectedSongs();
    this.showQualityPicker = false;
    let started: number = 0;
    for (let i: number = 0; i < rows.length; i++) {
      const row: PlaylistSongUi = rows[i];
      if (row.source.length === 0 || row.songId.length === 0) {
        continue;
      }
      void DownloadUtil.downloadSong(row.source, row.songId,
        typeof row.title === 'string' ? row.title : '',
        typeof row.singer === 'string' ? row.singer : '',
        quality, this.getUIContext(), row.coverUrl, row.albumName);
      started++;
    }
    hilog.info(BATCH_LOG_DOMAIN, BATCH_LOG_TAG, 'batch download quality=%{public}s started=%{public}d',
      quality, started);
    this.toast('已开始下载 ' + started + ' 首');
    this.onExit();
  }

  /** 批量从歌单中删除已选歌曲。 */
  private batchDelete(): void {
    if (this.playlistId.length === 0) {
      this.toast('该列表不支持删除');
      return;
    }
    const rows: PlaylistSongUi[] = this.selectedSongs();
    if (rows.length === 0) {
      this.toast('请先勾选歌曲');
      return;
    }
    const store: MusicStoreService = MusicStoreService.getInstance();
    for (let i: number = 0; i < rows.length; i++) {
      store.removeSongFromPlaylist(this.playlistId, rows[i].source, rows[i].songId);
    }
    hilog.info(BATCH_LOG_DOMAIN, BATCH_LOG_TAG, 'batch delete count=%{public}d', rows.length);
    notifyPlaylistChanged();
    this.batch.keys = [];
    this.toast('已删除 ' + rows.length + ' 首');
    this.onDeleted();
    this.onExit();
  }

  /** 批量下载时展示的字节格式化。 */
  private formatSize(bytes: number): string {
    if (bytes <= 0) {
      return '';
    }
    return (bytes / (1024 * 1024)).toFixed(1) + 'MB';
  }

  /** 等宽胶囊按钮（尺寸与 musicfreeOH 一致：36 高 / 圆角 10 / 字号 11）。 */
  @Builder
  private CapsuleButton(label: string, action: () => void) {
    Button(label)
      .layoutWeight(1)
      .height(36)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .borderRadius(10)
      .padding({ left: 2, right: 2 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .fontColor($r('sys.color.font_primary'))
      .onClick(() => {
        action();
      })
  }

  /** 「添加到歌单」弹层。 */
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
          this.createPlaylistWithSelected();
        })

      if (this.playlists.length > 0) {
        Blank().height(12)
        Scroll() {
          Column({ space: 2 }) {
            ForEach(this.playlists, (p: PlaylistDto) => {
              Row() {
                Text(p.name)
                  .fontSize(15)
                  .fontColor($r('sys.color.font_primary'))
                  .maxLines(1)
                  .layoutWeight(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(p.songs.length + ' 首')
                  .fontSize(12)
                  .fontColor($r('sys.color.font_tertiary'))
              }
              .width('100%')
              .height(44)
              .padding({ left: 14, right: 14 })
              .borderRadius(10)
              .backgroundColor($r('sys.color.background_secondary'))
              .onClick(() => {
                this.addSelectedToPlaylist(p);
              })
            }, (p: PlaylistDto) => p.id)
          }
          .width('100%')
        }
        .height(170)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 24 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /** 批量下载音质弹层。 */
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
            .fontColor($r('sys.color.font_tertiary'))
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
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                if (q.size > 0) {
                  Text(this.formatSize(q.size))
                    .fontSize(13)
                    .fontColor($r('sys.color.font_tertiary'))
                }
              }
              .width('100%')
              .padding({ left: 4, right: 4, top: 13, bottom: 13 })
              .onClick(() => {
                this.batchDownload(q.type);
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

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 10 }) {
        Row() {
          Text('已选 ' + this.batch.keys.length + ' 首歌曲')
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
          Blank()
          Text('取消')
            .fontSize(16)
            .fontColor($r('sys.color.font_secondary'))
            .onClick(() => {
              this.onExit();
            })
        }
        .width('100%')

        Row({ space: 8 }) {
          this.CapsuleButton(this.isAllSelected() ? '取消全选' : '全选', (): void => {
            this.toggleSelectAll();
          })
          this.CapsuleButton('下一首播放', (): void => {
            this.batchPlayNext();
          })
          this.CapsuleButton('收藏', (): void => {
            this.batchAddFavorite();
          })
        }
        .width('100%')

        Row({ space: 8 }) {
          this.CapsuleButton('添加到歌单', (): void => {
            this.openPlaylistPicker();
          })
          this.CapsuleButton('下载', (): void => {
            void this.openBatchQualitySheet();
          })
          if (this.allowBatchDelete) {
            this.CapsuleButton('删除', (): void => {
              this.batchDelete();
            })
          }
        }
        .width('100%')
      }
      .width(StyleConstants.FULL_WIDTH)
      .padding({
        top: 14,
        left: new BreakpointType(16, 24, 24, 24).getValue(this.breakpointEnv.widthBreakpoint),
        right: new BreakpointType(16, 24, 24, 24).getValue(this.breakpointEnv.widthBreakpoint),
        bottom: 12
      })
      // 整条操作条**没有任何背景**：不加 backgroundColor，也不加底部的
      // linearGradientBlur 垫层 —— 两者都会在按钮后面形成一块看得见的"卡片/色带"。
      // 现在按钮直接悬浮在列表之上，最后一行靠列表的 contentEndOffset 预留不被盖住。
    }
    .width(StyleConstants.FULL_WIDTH)
    .bindSheet($$this.showPlaylistPicker, this.PlaylistPickerSheet(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: false,
      title: { title: '添加到歌单' },
      backgroundColor: $r('sys.color.background_secondary'),
      onWillDismiss: (action: DismissSheetAction) => {
        action.dismiss();
        this.showPlaylistPicker = false;
      }
    })
    .bindSheet($$this.showQualityPicker, this.QualitySheet(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: false,
      title: { title: '选择下载音质' },
      backgroundColor: $r('sys.color.background_secondary'),
      onWillDismiss: (action: DismissSheetAction) => {
        this.dismissQuality();
      }
    })
  }

  private dismissQuality(): void {
    this.showQualityPicker = false;
  }
}
