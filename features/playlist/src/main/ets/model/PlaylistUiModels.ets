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
 * UI-facing song row model for playlist lists (title, artist, cover resource).
 */
export class PlaylistSongUi {
  /** Stable song identifier from the backing store. */
  public id: number = 0;
  /** Display title for the track row. */
  public title: string | Resource = '';
  /** Display artist or subtitle line. */
  public singer: string | Resource = '';
  /** Cover art or placeholder image resource for list thumbnails. */
  public label: Resource = $r('app.media.ic_list_cover');
  /** Music source id for online songs; empty for local rows. */
  public source: string = '';
  /** Song id within the music source for online songs. */
  public songId: string = '';
  /** Online cover image url; empty when unavailable. */
  public coverUrl: string = '';
  /** Album name carried over from the store record (batch add-to-playlist / download need it). */
  public albumName: string = '';
  /** Album id within the music source; used for cover fallback. */
  public albumId: string = '';
  /** Formatted duration carried over from the store record, e.g. "03:55". */
  public interval: string = '';

  /**
   * 批量选择用的业务稳定键：`source_songId`。
   * 本地行（无源信息）退化为 `local_<行序号>`，与 `id` 语义一致。
   * @returns Stable per-row key for multi-select, deletion and reorder.
   */
  public selectionKey(): string {
    if (this.source.length > 0 && this.songId.length > 0) {
      return this.source + '_' + this.songId;
    }
    return 'local_' + this.id;
  }
}
