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


import { AppStorageV2, UIContext } from '@kit.ArkUI';
import { AppStorageKeys, BoardSongParam, MusicStoreService, PlayedSongRecord } from 'musicbasic';
import { LXSearchSong, lxGetPicFallback, lxTxToplist, OnlinePlayUtil, PlaylistSearchApi } from 'player';
import { MusicAppState, PlaybackIntentState } from '../model/PlaylistModels';
import { PlaylistSongUiDataSource } from '../model/PlaylistSongUiDataSource';
import { PlaylistSongUi } from '../model/PlaylistUiModels';
import { PlaylistDataUtil } from '../util/PlaylistDataUtil';

/**
 * 在线封面补全的最大行数。
 *
 * 酷我榜单一次返回 100 首、且接口不带封面，所以上限要够大才能把列表铺满；
 * 但**必须配合下面的并发上限** —— 之前无条件串行发 100 个引擎请求，
 * 把引擎打满导致所有平台都取不到数据、列表一直转圈。
 */
const COVER_FILL_LIMIT: number = 120;

/** 在线封面补全的并发上限：不能把所有请求一次压给音源引擎。 */
const COVER_FILL_CONCURRENCY: number = 3;

/** 「每日30首」列表在 AppStorage 里的中转结构（由首页写入）。 */
interface DailyThirtyRow {
  title: string;
  singer: string;
  source: string;
  songId: string;
  coverUrl: string;
}

/**
 * Observable view model: playlist rows, lazy list data source, and play requests via global intent.
 */
@ObservedV2
export class MusicListPlaybackViewModel {
  /** Connected global music app state (current song, play flag, etc.). */
  public appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** Connected global playback intent used to request the player and next track. */
  private playbackIntent: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!;

  /** LazyForEach data source mirroring {@link playlistSongUis}. */
  @Trace public songListDataSource: PlaylistSongUiDataSource = new PlaylistSongUiDataSource([]);
  /** Materialized playlist song rows after sync from API/DB. */
  @Trace public playlistSongUis: PlaylistSongUi[] = [];
  @Trace public songListVersion: number = 0;
  /** Loading flag for online toplist fetches. */
  @Trace public loadingOnline: boolean = false;

  /**
   * Reloads playlist songs and rebuilds the list data source.
   * @param playlistId Playlist id to load; defaults to {@link PlaylistDataUtil.defaultPlaylistId}.
   */
  public syncPlaylistFromApi(playlistId: number = PlaylistDataUtil.defaultPlaylistId): void {
    this.playlistSongUis = PlaylistDataUtil.loadPlaylistSongUis(playlistId);
    this.songListDataSource.reloadData(this.playlistSongUis);
  }

  /** Loads the play history from the local store into the playlist rows. */
  public loadHistorySongs(): void {
    this.applyStoreRecords(MusicStoreService.getInstance().getHistory());
  }

  /** Loads the favorites from the local store into the playlist rows. */
  public loadFavoriteSongs(): void {
    this.applyStoreRecords(MusicStoreService.getInstance().getFavorites());
  }

  /** Loads a user playlist by id into the playlist rows. */
  public loadPlaylistSongs(playlistId: string): void {
    const p = MusicStoreService.getInstance().getPlaylistById(playlistId);
    if (p !== undefined) {
      this.appendListLog('[歌单] 加载 id=' + playlistId + ' 名称=' + p.name + ' 歌曲数=' + p.songs.length +
        ' 首曲=' + (p.songs.length > 0 ? p.songs[0].name + ' src=' + p.songs[0].source + ' id=' + p.songs[0].songId : '空'));
      this.applyStoreRecords(p.songs);
    } else {
      this.appendListLog('[歌单] 未找到 id=' + playlistId);
      this.applyStoreRecords([]);
    }
  }

  /** Appends a marker line to the shared run log (visible in settings). */
  private appendListLog(message: string): void {
    const log: string = AppStorage.get<string>('lxPlayLog') ?? '';
    const now: Date = new Date();
    const time: string = now.getHours().toString().padStart(2, '0') + ':' +
      now.getMinutes().toString().padStart(2, '0') + ':' +
      now.getSeconds().toString().padStart(2, '0');
    AppStorage.setOrCreate('lxPlayLog', (log + '[' + time + '] ' + message + '\n').slice(-20000));
  }

  /** Loads the current play queue (online items plus local ids) into the playlist rows. */
  public loadQueueSongs(): void {
    const uis: PlaylistSongUi[] = [];
    const total: number = this.appState.getQueueLength();
    for (let i: number = 0; i < total; i++) {
      const song = this.appState.resolveSongAtQueueIndex(i);
      if (song === undefined) {
        continue;
      }
      const ui = new PlaylistSongUi();
      ui.id = i + 1;
      ui.title = song.title;
      ui.singer = song.singer;
      ui.source = song.source;
      ui.songId = song.songId;
      if (song.cover.length > 0) {
        ui.coverUrl = song.cover;
      }
      uis.push(ui);
    }
    this.playlistSongUis = uis;
    this.songListDataSource.reloadData(uis);
    this.songListVersion++;
  }

  /**
   * 载入「每日30首」列表（首页推荐曲目）。
   *
   * 数据由首页（recommendation 层）在跳转前写进 `AppStorage` 的
   * `dailyThirtySongs`；playlist 不能反向依赖 recommendation，所以用共享状态中转。
   */
  public loadDailyThirtySongs(): void {
    const raw: string = AppStorage.get<string>('dailyThirtySongs') ?? '';
    const uis: PlaylistSongUi[] = [];
    if (raw.length > 0) {
      try {
        const rows: DailyThirtyRow[] = JSON.parse(raw) as DailyThirtyRow[];
        for (let i: number = 0; i < rows.length; i++) {
          const row = rows[i];
          const ui = new PlaylistSongUi();
          ui.id = i + 1;
          ui.title = row.title;
          ui.singer = row.singer;
          ui.source = row.source;
          ui.songId = row.songId;
          ui.coverUrl = row.coverUrl;
          uis.push(ui);
        }
      } catch (_err) {
        // 解析失败就落空态
      }
    }
    this.loadingOnline = true;
    this.playlistSongUis = uis;
    this.songListDataSource.reloadData(uis);
    this.songListVersion++;
    this.loadingOnline = false;
    if (uis.length > 0) {
      void this.fillOnlineCovers();
    }
  }

  /** Maps store records to playlist UI rows and rebuilds the list source. */
  private applyStoreRecords(records: PlayedSongRecord[]): void {
    const uis: PlaylistSongUi[] = [];
    for (let i: number = 0; i < records.length; i++) {
      const record = records[i];
      const ui = new PlaylistSongUi();
      ui.id = i + 1;
      ui.title = record.name;
      ui.singer = record.singer;
      ui.source = record.source;
      ui.songId = record.songId;
      ui.coverUrl = record.img;
      // 专辑 / 时长随行携带：批量「添加到歌单」「下载」需要它们，丢了就只能写空值
      ui.albumName = record.albumName;
      ui.albumId = record.albumId;
      ui.interval = record.interval;
      uis.push(ui);
    }
    this.playlistSongUis = uis;
    this.songListDataSource.reloadData(uis);
    this.songListVersion++;
  }

  /**
   * Loads an online QQ music toplist into the playlist rows.
   * @param topid QQ music toplist id (26=热歌, 27=新歌, 4=流行指数).
   * @param title Display title for the list.
   */
  public async loadOnlineToplist(topid: string): Promise<void> {
    this.loadingOnline = true;
    const uis: PlaylistSongUi[] = [];
    let errInfo: string = '';
    try {
      const res = await lxTxToplist(topid, 30);
      for (let i: number = 0; i < res.list.length; i++) {
        const song = res.list[i];
        const ui = new PlaylistSongUi();
        ui.id = i + 1;
        ui.title = song.name;
        ui.singer = song.singer;
        ui.source = song.source;
        ui.songId = song.songId;
        ui.coverUrl = song.img;
        uis.push(ui);
      }
    } catch (err) {
      errInfo = JSON.stringify(err).substring(0, 120);
    }
    const log: string = AppStorage.get<string>('lxPlayLog') ?? '';
    const now: Date = new Date();
    const time: string = now.getHours().toString().padStart(2, '0') + ':' +
      now.getMinutes().toString().padStart(2, '0') + ':' +
      now.getSeconds().toString().padStart(2, '0');
    AppStorage.setOrCreate('lxPlayLog',
      (log + '[' + time + '] [榜单] topid=' + topid + ' 结果=' + uis.length +
        (errInfo.length > 0 ? ' 异常=' + errInfo : '') + '\n').slice(-20000));
    this.playlistSongUis = uis;
    this.songListDataSource.reloadData(uis);
    this.songListVersion++;
    this.loadingOnline = false;
  }

  /**
   * Loads an online (external source) playlist's songs into the playlist rows.
   * @param source Music source id ('wy'|'tx'|'kw'|'kg'|'mg').
   * @param id Playlist id within the source.
   */
  public async loadOnlinePlaylistSongs(source: string, id: string): Promise<void> {
    this.loadingOnline = true;
    const uis: PlaylistSongUi[] = [];
    try {
      const songs = await PlaylistSearchApi.getPlaylistDetail(source, id);
      for (let i: number = 0; i < songs.length; i++) {
        const s = songs[i];
        const ui = new PlaylistSongUi();
        ui.id = i + 1;
        ui.title = s.name;
        ui.singer = s.singer;
        ui.source = s.source;
        ui.songId = s.songId;
        ui.coverUrl = s.picUrl;
        uis.push(ui);
      }
    } catch (err) {
      const log: string = AppStorage.get<string>('lxPlayLog') ?? '';
      AppStorage.setOrCreate('lxPlayLog',
        (log + '[在线歌单] 加载失败 ' + source + '/' + id + '\n').slice(-20000));
    }
    this.playlistSongUis = uis;
    this.songListDataSource.reloadData(uis);
    this.songListVersion++;
    this.loadingOnline = false;
    this.fillOnlineCovers();
  }

  /**
   * 铺入一批榜单歌曲（**不结束后面的加载态**）。
   *
   * 榜单页打开时会走两步：先用路由参数里预取的结果铺一次（可能为空），
   * 再由 `PlaylistDetailPage.loadBoardSongsAsync` 异步补齐。两步之间要保持
   * `loadingOnline = true`，列表才不会先闪一下空态再出现内容。
   *
   * @param songs 榜单歌曲。
   */
  public loadBoardSongs(songs: BoardSongParam[]): void {
    this.loadingOnline = true;
    this.applyBoardSongs(songs);
  }

  /**
   * 结束榜单加载态。
   *
   * @param songs 最终结果；为空则列表落到空态（「未找到歌曲」）。
   */
  public finishBoardLoading(songs: BoardSongParam[]): void {
    this.applyBoardSongs(songs);
    this.loadingOnline = false;
  }

  /** 把榜单歌曲转成行模型并刷新数据源。 */
  private applyBoardSongs(songs: BoardSongParam[]): void {
    const uis: PlaylistSongUi[] = [];
    for (let i: number = 0; i < songs.length; i++) {
      const s = songs[i];
      const ui = new PlaylistSongUi();
      ui.id = i + 1;
      ui.title = s.title;
      ui.singer = s.singer;
      ui.source = s.source;
      ui.songId = s.songId;
      ui.coverUrl = s.coverUrl;
      uis.push(ui);
    }
    this.playlistSongUis = uis;
    this.songListDataSource.reloadData(uis);
    this.songListVersion++;
    void this.fillOnlineCovers();
  }

  /**
   * 在线歌单/榜单封面补全。
   *
   * ⚠️ **必须限流 + 限制数量**。原来是对整个列表无条件 for-await 串行取封面：
   * 酷我榜单一次返回 100 首、且接口不带封面，于是这里会连着发 100 次音源引擎请求
   * （每次失败还会退化成搜索），表现就是「列表里有 100 首但一直转圈」，
   * 而且引擎被这 100 个请求占满后，别的平台（酷狗/QQ/网易）也跟着取不到数据。
   *
   * 现在：只补**前 {@link COVER_FILL_LIMIT} 行**（够首屏用），并且并发不超过
   * {@link COVER_FILL_CONCURRENCY}，剩下的行在用户滚动到附近时由行自己按需取。
   */
  private async fillOnlineCovers(): Promise<void> {
    const total: number = Math.min(this.playlistSongUis.length, COVER_FILL_LIMIT);
    const queue: number[] = [];
    for (let i: number = 0; i < total; i++) {
      const ui = this.playlistSongUis[i];
      if (ui.source.length === 0 || ui.songId.length === 0 || ui.coverUrl.length > 0) {
        continue;
      }
      queue.push(i);
    }
    let cursor: number = 0;
    const worker = async (): Promise<void> => {
      while (cursor < queue.length) {
        const index: number = queue[cursor];
        cursor = cursor + 1;
        if (index >= this.playlistSongUis.length) {
          continue;
        }
        const ui = this.playlistSongUis[index];
        try {
          const pic: string = await lxGetPicFallback(ui.source, ui.songId, '',
            typeof ui.title === 'string' ? ui.title : '', typeof ui.singer === 'string' ? ui.singer : '');
          if (pic.length > 0 && this.playlistSongUis[index] !== undefined) {
            this.playlistSongUis[index].coverUrl = pic;
            this.songListDataSource.reloadData(this.playlistSongUis);
            this.songListVersion++;
          }
        } catch (_err) {
          // keep placeholder
        }
      }
    };
    const slots: number = Math.min(COVER_FILL_CONCURRENCY, Math.max(1, queue.length));
    const tasks: Promise<void>[] = [];
    for (let i: number = 0; i < slots; i++) {
      tasks.push(worker());
    }
    await Promise.all(tasks);
  }

  /**
   * Requests playback for the row at the given index, or opens the player if it is already the current song.
   * Online rows play through the LX engine; local rows use the global intent.
   * @param index Zero-based playlist index.
   * @param uiContext Used for toast prompts when playing online.
   */
  public requestPlayByListIndex(index: number, uiContext: UIContext | undefined): void {
    if (index < 0 || index >= this.playlistSongUis.length) {
      return;
    }
    const item = this.playlistSongUis[index];
    if (item.source.length > 0) {
      const songs: LXSearchSong[] = [];
      for (let i: number = 0; i < this.playlistSongUis.length; i++) {
        const row = this.playlistSongUis[i];
        const song: LXSearchSong = {
          songId: row.songId,
          name: typeof row.title === 'string' ? row.title : '',
          singer: typeof row.singer === 'string' ? row.singer : '',
          albumName: '',
          albumId: '',
          source: row.source,
          interval: '',
          img: row.coverUrl,
          types: []
        };
        songs.push(song);
      }
      void OnlinePlayUtil.playList(this.appState, songs, index, uiContext);
      return;
    }
    if (this.isCurrentSong(item)) {
      this.playbackIntent.pendingPlaySongId = -1;
      this.playbackIntent.openPlayerUi = true;
      this.playbackIntent.requestVersion++;
      return;
    }
    PlaylistDataUtil.applyPlaybackIntentForPlaylistIndex(index, this.playlistSongUis, this.playbackIntent);
  }

  /**
   * Applies a standard play intent for the given list index without the same-song shortcut.
   * @param index Zero-based playlist index.
   */
  public requestPlayFromPlaylistIndex(index: number): void {
    PlaylistDataUtil.applyPlaybackIntentForPlaylistIndex(index, this.playlistSongUis, this.playbackIntent);
  }

  /**
   * Whether the given UI row matches the globally current song.
   * @param item Row model to compare with the active track.
   * @returns True when ids match and a current song exists.
   */
  public isCurrentSong(item: PlaylistSongUi): boolean {
    const cur = this.appState.getCurrentSongItem();
    return cur !== undefined && cur.id === item.id;
  }
}
