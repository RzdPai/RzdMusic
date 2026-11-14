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
 * Plain-serializable record of an online song used by history and favorites.
 * All fields are JSON-safe (no Resource references).
 */
export class PlayedSongRecord {
  /** Song id within the music source. */
  public songId: string = '';
  /** Song name. */
  public name: string = '';
  /** Artist line. */
  public singer: string = '';
  /** Album name. */
  public albumName: string = '';
/** Album id within the source (used for cover fallback). */
public albumId: string = '';
  /** Music source id ('kw'|'kg'|'tx'|'wy'|'mg'). */
  public source: string = '';
  /** Formatted duration, e.g. "03:55". */
  public interval: string = '';
  /** Cover image url. */
  public img: string = '';
  /** Resolved play url; empty when not resolved yet. */
  public url: string = '';
  /** LRC lyric text; empty when unavailable. */
  public lyric: string = '';
  /** Last played quality id (e.g. '128k' | '320k' | 'flac' | 'flac24bit'); empty when unknown. */
  public quality: string = '';
  /** Name of the user source script that produced the cached url; empty when unknown. */
  public playScript: string = '';
  /** Timestamp (ms) when the record was created / last played. */
  public time: number = 0;
}
