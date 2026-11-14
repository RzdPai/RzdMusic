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


import { MusicDbApi, PlaybackIntentState, SongApiDto } from 'musicbasic';
import { PlaylistSongUi } from '../model/PlaylistUiModels';

/**
 * Static helpers to load playlist rows from the DB API and apply playback intents by list index.
 */
export class PlaylistDataUtil {
  /** Default playlist identifier used when none is supplied. */
  public static readonly defaultPlaylistId: number = 1;

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
