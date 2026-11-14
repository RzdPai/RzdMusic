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
 * Route parameters for opening the playlist detail page: an online QQ music
 * toplist, or a local store section (history / favorites).
 */
export class ToplistRouteParam {
  /** QQ music toplist id when showing an online toplist; empty for local lists. */
  topid: string = '';
  /** Display title shown in the title bar. */
  listTitle: string = '';
  /** 'history' or 'favorites' to load local store lists instead of an online toplist. */
  sectionType: string = '';
  /** Playlist id when sectionType is 'playlist'. */
  playlistId: string = '';
  /** Music source id when sectionType is 'onlinePlaylist'. */
  onlineSource: string = '';
  /** Board music source when opening a multi-source ranking board. */
  boardSource: string = '';
  /** Board id within the board source. */
  boardId: string = '';
  /** Prefetched board songs (filled by the caller before navigation). */
  boardSongs: BoardSongParam[] = [];
}

/**
 * Plain song entry handed over through the route param when opening a
 * multi-source ranking board with the shared playlist detail page.
 */
export interface BoardSongParam {
  /** Song name. */
  title: string;
  /** Singer line. */
  singer: string;
  /** Music source id ('kw'|'kg'|'tx'|'wy'|'mg'). */
  source: string;
  /** Source-local song id used for playback. */
  songId: string;
  /** Cover image url. */
  coverUrl: string;
}
