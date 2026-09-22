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

import { PlayedSongRecord } from './PlayedSongRecord';

/**
 * A user-created playlist: display name plus an ordered song list.
 */
export class PlaylistDto {
  /** Stable playlist id (timestamp based). */
  public id: string = '';
  /** Display name of the playlist. */
  public name: string = '';
  /**
   * 歌单封面地址。
   *
   * 本地歌单多来自「收藏/导入别人的歌单」，导入时能取到源歌单封面；
   * 纯手工新建的没有封面，保持为空并由 UI 显示内置占位图。
   * **不要**用第一首歌的封面顶替，否则歌单页看起来会像专辑页。
   */
  public cover: string = '';
  /** Creation timestamp (ms). */
  public createTime: number = 0;
  /** Songs in the playlist (insertion order). */
  public songs: PlayedSongRecord[] = [];
}
