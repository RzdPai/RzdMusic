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


import { MusicDbApi, PlaybackIntentState, PlayedSongRecord, SongApiDto, SongItem } from 'musicbasic';
import { isLocalSong, LOCAL_SOURCE, localMusic } from 'localmusic';
import { PlaylistSongUi } from '../model/PlaylistUiModels';

/**
 * Static helpers to load playlist rows from the DB API and apply playback intents by list index.
 */
export class PlaylistDataUtil {
  /** Default playlist identifier used when none is supplied. */
  public static readonly defaultPlaylistId: number = 1;

  /** 本地歌在 source 字段里的标记（转发 localmusic 的口径，界面统一用它判定本地行）。 */
  public static readonly localSource: string = LOCAL_SOURCE;

  /**
   * 某一行是不是本地歌（复用 localmusic 的 isLocalSong，避免各处各写一份判断）。
   * @param source 行上的 source 取值。
   * @returns True 表示本地沙箱音频。
   */
  public static isLocalSource(source: string): boolean {
    const probe = new SongItem();
    probe.source = source;
    return isLocalSong(probe);
  }

  /**
   * 歌单侧表里的本地歌行（顺序即侧表顺序：最新加入的在最前）。
   * @param playlistId 歌单 id；为空时返回空数组。
   * @returns 映射好的 {@link PlaylistSongUi} 行（source='local'、songId=本地 key）。
   */
  public static localPlaylistRows(playlistId: string): PlaylistSongUi[] {
    const rows: PlaylistSongUi[] = [];
    if (playlistId.length === 0) {
      return rows;
    }
    const items: SongItem[] = localMusic.listSongItems(playlistId);
    for (let i: number = 0; i < items.length; i++) {
      const item: SongItem = items[i];
      const ui = new PlaylistSongUi();
      ui.title = item.title;
      ui.singer = item.singer;
      ui.source = item.source;
      ui.songId = item.songId;
      ui.coverUrl = item.cover;
      rows.push(ui);
    }
    return rows;
  }

  /**
   * 把歌单里的本地歌合并在最前面（与「新加的歌排最前」一致）。
   *
   * store 里可能同时存在本地歌行（`localMusic.addKeysToPlaylist` 侧表与 store 两处都写），
   * 这里按侧表 key 去重：侧表里有的一律跳过 store 那份，保证一行只出现一次，且顺序以侧表为准。
   * @param playlistId 歌单 id。
   * @param records store 里的歌单歌曲（可能已含本地歌行，也可能被同步覆盖后不含）。
   * @returns 合并后的列表行（本地歌在最前，id 按最终顺序重排）。
   */
  public static mergeLocalFirst(playlistId: string, records: PlayedSongRecord[]): PlaylistSongUi[] {
    const merged: PlaylistSongUi[] = PlaylistDataUtil.localPlaylistRows(playlistId);
    const localKeys: Set<string> = new Set<string>();
    for (let i: number = 0; i < merged.length; i++) {
      localKeys.add(merged[i].songId);
    }
    for (let i: number = 0; i < records.length; i++) {
      const record: PlayedSongRecord = records[i];
      if (record.source === LOCAL_SOURCE && localKeys.has(record.songId)) {
        continue;
      }
      const ui = new PlaylistSongUi();
      ui.title = record.name;
      ui.singer = record.singer;
      ui.source = record.source;
      ui.songId = record.songId;
      ui.coverUrl = record.img;
      merged.push(ui);
    }
    for (let i: number = 0; i < merged.length; i++) {
      merged[i].id = i + 1;
    }
    return merged;
  }

  /**
   * Loads UI song models for a playlist from the local music database API.
   * @param playlistId Playlist primary key to query.
   * @returns Array of {@link PlaylistSongUi} rows for list binding.
   */
  public static loadPlaylistSongUis(playlistId: number): PlaylistSongUi[] {
    return MusicDbApi.getInstance().getPlaylistSongItems(playlistId)
      .map((dto) => PlaylistDataUtil.mapSongDtoToUi(dto));
  }

  /**
   * Maps a network/database DTO into a {@link PlaylistSongUi} instance.
   * @param dto Song payload from the API layer.
   * @returns Populated UI model.
   */
  private static mapSongDtoToUi(dto: SongApiDto): PlaylistSongUi {
    const ui = new PlaylistSongUi();
    ui.id = dto.id;
    ui.title = dto.title;
    ui.singer = dto.singer;
    ui.label = dto.label;
    return ui;
  }

  /**
   * Resolves the backing song id at a playlist row index, if in range.
   * @param listIndex Zero-based index in the UI list.
   * @param playlistUis Current playlist UI rows.
   * @returns Song id when valid; otherwise undefined.
   */
  public static getSongIdAtPlaylistIndex(listIndex: number, playlistUis: PlaylistSongUi[]): number | undefined {
    if (listIndex < 0 || listIndex >= playlistUis.length) {
      return undefined;
    }
    return playlistUis[listIndex].id;
  }

  /**
   * Writes a pending play request into shared playback intent for the song at the given list index.
   * @param listIndex Zero-based playlist index to play.
   * @param playlistUis Current playlist UI rows.
   * @param intent Mutable global playback intent state.
   */
  public static applyPlaybackIntentForPlaylistIndex(
    listIndex: number,
    playlistUis: PlaylistSongUi[],
    intent: PlaybackIntentState
  ): void {
    const songId = PlaylistDataUtil.getSongIdAtPlaylistIndex(listIndex, playlistUis);
    if (songId === undefined) {
      return;
    }
    intent.pendingPlaySongId = songId;
    intent.openPlayerUi = true;
    intent.requestVersion++;
  }
}
