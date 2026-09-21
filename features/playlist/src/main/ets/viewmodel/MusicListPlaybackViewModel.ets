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
import { AppStorageKeys, BoardSongParam, MusicStoreService, PlayedSongRecord, SongItem } from 'musicbasic';
import { LXSearchSong, lxGetPicFallback, lxTxToplist, MediaService, OnlinePlayUtil, PlaylistSearchApi } from 'player';
import { localMusic, LOCAL_SOURCE } from 'localmusic';
import { MusicAppState, PlaybackIntentState } from '../model/PlaylistModels';
import { PlaylistSongUiDataSource } from '../model/PlaylistSongUiDataSource';
import { PlaylistSongUi } from '../model/PlaylistUiModels';
import { PlaylistDataUtil } from '../util/PlaylistDataUtil';

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

  /** Loads a user playlist by id into the playlist rows (local songs merged in front). */
  public loadPlaylistSongs(playlistId: string): void {
    const p = MusicStoreService.getInstance().getPlaylistById(playlistId);
    const records: PlayedSongRecord[] = p !== undefined ? p.songs : [];
    if (p !== undefined) {
      this.appendListLog('[歌单] 加载 id=' + playlistId + ' 名称=' + p.name + ' 歌曲数=' + p.songs.length +
        ' 首曲=' + (p.songs.length > 0 ? p.songs[0].name + ' src=' + p.songs[0].source + ' id=' + p.songs[0].songId : '空'));
    } else {
      this.appendListLog('[歌单] 未找到 id=' + playlistId);
    }
    // 本地歌由 localmusic 侧表提供并排在最前（store 里可能已被同步覆盖掉本地行）
    this.applyRows(PlaylistDataUtil.mergeLocalFirst(playlistId, records));
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
      uis.push(ui);
    }
    this.applyRows(uis);
  }

  /** Publishes already-built rows to the list state and lazy data source. */
  private applyRows(uis: PlaylistSongUi[]): void {
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
   * Loads a prefetched multi-source ranking board into the playlist rows.
   * @param songs Board songs handed over through the route param.
   */
  public loadBoardSongs(songs: BoardSongParam[]): void {
    this.loadingOnline = true;
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
    this.loadingOnline = false;
    void this.fillOnlineCovers();
  }

  /** 在线歌单封面补全：异步取各源封面并更新行数据。 */
  private async fillOnlineCovers(): Promise<void> {
    for (let i = 0; i < this.playlistSongUis.length; i++) {
      const ui = this.playlistSongUis[i];
      if (ui.source.length === 0 || ui.songId.length === 0 || ui.coverUrl.length > 0) {
        continue;
      }
      try {
        const pic: string = await lxGetPicFallback(ui.source, ui.songId, '',
          typeof ui.title === 'string' ? ui.title : '', typeof ui.singer === 'string' ? ui.singer : '');
        if (pic.length > 0 && this.playlistSongUis[i] !== undefined) {
          this.playlistSongUis[i].coverUrl = pic;
          this.songListDataSource.reloadData(this.playlistSongUis);
          this.songListVersion++;
        }
      } catch (_err) {
        // keep placeholder
      }
    }
  }

  /**
   * Requests playback for the row at the given index, or opens the player if it is already the current song.
   * Local rows play from the sandbox (queue of the playlist's local songs); online rows play through the LX engine.
   * @param index Zero-based playlist index (index into {@link playlistSongUis}).
   * @param uiContext Used for toast prompts when playing online.
   */
  public requestPlayByListIndex(index: number, uiContext: UIContext | undefined): void {
    if (index < 0 || index >= this.playlistSongUis.length) {
      return;
    }
    const item = this.playlistSongUis[index];
    if (item.source === LOCAL_SOURCE) {
      this.playLocalRow(index);
      return;
    }
    if (item.source.length > 0) {
      const songs: LXSearchSong[] = [];
      let startIndex: number = 0;
      for (let i: number = 0; i < this.playlistSongUis.length; i++) {
        const row = this.playlistSongUis[i];
        // 本地歌不交给在线引擎（会把 source:'local' 当成未知音源去解析）
        if (row.source === LOCAL_SOURCE) {
          continue;
        }
        if (i === index) {
          startIndex = songs.length;
        }
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
      if (songs.length === 0) {
        return;
      }
      void OnlinePlayUtil.playList(this.appState, songs, startIndex, uiContext);
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
   * Plays a local row: the queue is the playlist's local songs in list order, the tapped one starts.
   * 播放侧按 `source === 'local'` 直路用沙箱绝对路径起播（见 LocalMusicView.playAt 的接线说明）。
   */
  private playLocalRow(index: number): void {
    const keys: string[] = [];
    let startLocal: number = 0;
    for (let i: number = 0; i < this.playlistSongUis.length; i++) {
      const row = this.playlistSongUis[i];
      if (row.source !== LOCAL_SOURCE) {
        continue;
      }
      if (i === index) {
        startLocal = keys.length;
      }
      keys.push(row.songId);
    }
    const queue: SongItem[] = localMusic.songsByKeys(keys);
    if (queue.length === 0 || startLocal >= queue.length) {
      return;
    }
    this.appState.replaceQueue(queue, startLocal);
    this.appState.currentQuality = 'local';
    this.appState.isResolving = false;
    void MediaService.getInstance().loadAsset(startLocal);
    this.appState.isShowPlay = true;
    this.playbackIntent.pendingPlaySongId = -1;
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
