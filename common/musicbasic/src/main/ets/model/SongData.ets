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


/**
 * Music information entity class.
 * @ObservedV2 and @Trace for V2 state management deep observation.
 */
/**
 * One available quality for an online song (type + human-readable size).
 */
export interface QualityInfo {
  /** Quality id: '128k' | '320k' | 'flac' | 'flac24bit'. */
  type: string;
  /** File size in bytes as string; empty when unknown. */
  size: string;
}

@ObservedV2
export class SongItem {
  /**
   * Primary key ID.
   */
  @Trace public id: number = 0;

  /**
   * Music name (plain string or string resource for i18n).
   */
  public title: string | Resource = '';

  /**
   * Music author name (plain string or string resource for i18n).
   */
  public singer: string | Resource = '';

  /**
   * Music logo information.
   * Resource type may not support @Trace - kept as plain field.
   */
  public mark: Resource = $r('app.string.page_show');

  /**
   * Music avatar information.
   * Resource type may not support @Trace - kept as plain field.
   */
  public label: Resource = $r('app.string.page_show');

  /**
   * Music file path information.
   */
  @Trace public src: string = '';

  /**
   * Index of the current music list.
   */
  @Trace public index: number = 0;

  /**
   * Lyric file path information.
   */
  @Trace public lyric: string = '';

  /**
   * Online playback URL (http/https) for network songs; empty for local assets.
   */
  @Trace public url: string = '';

  /**
   * LRC lyric text resolved from the music source; empty when unavailable.
   */
  @Trace public lyricText: string = '';

  /**
   * Translation lyric text (tlyric) for the current track; empty when unavailable.
   */
  @Trace public lyricTranslation: string = '';

  /**
   * Romanization (romaji) lyric text for the current track; empty when unavailable.
   */
  @Trace public lyricRoman: string = '';

  /**
   * Online cover image URL for network songs; empty when unavailable.
   */
  @Trace public cover: string = '';

  /**
   * Music source id ('kw'|'kg'|'tx'|'wy'|'mg') for network songs.
   */
  @Trace public source: string = '';

  /**
   * Song id within the music source for network songs.
   */
  @Trace public songId: string = '';

  /**
   * Available quality list (type + file size string) for network songs.
   */
  @Trace public qualityList: Array<QualityInfo> = [];

  /**
   * Album id within the music source for network songs (used by cover fallback).
   */
  @Trace public albumId: string = '';

  /**
   * Album display name for network songs (used by the player menu and search).
   */
  @Trace public albumName: string = '';

  /**
   * Formatted duration, e.g. "03:55". Carried alongside the song so history /
   * favorite rows can render the duration when the song hasn't been resolved yet.
   */
  @Trace public interval: string = '';

  /**
   * Last-resolved playback quality id ('128k' | '320k' | 'flac' | 'flac24bit');
   * empty when unknown. Mirrored into PlayedSongRecord when persisting to history
   * / favorites so the row can render the quality label without a re-resolve.
   */
  @Trace public quality: string = '';

  /**
   * Display name of the user source script that produced the playback URL.
   * Kept on the song so the player page can show which script actually served it.
   */
  @Trace public playScript: string = '';

  /**
   * True when the track is served from a locally downloaded / cached file
   * instead of being streamed over HTTP.
   */
  @Trace public playCached: boolean = false;
}
