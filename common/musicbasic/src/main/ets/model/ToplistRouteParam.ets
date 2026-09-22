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
  /**
   * 榜单 / 歌单自身的封面地址（榜单封面、在线歌单封面、横幅大图）。
   *
   * 详情页大图 Hero 只用这个，**不要**退回「第一首歌的封面」——那会让歌单/榜单页
   * 看起来像专辑页。为空时详情页显示内置占位图。
   */
  listCover: string = '';
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
  /**
   * 榜单歌曲（**不再由调用方预取**）。
   *
   * 打开榜单只等封面，不等歌曲：详情页会自己异步拉歌并显示骨架屏。
   * 详情页的取数走 player 的 `fetchBoardSongs`，不依赖调用方。
   *
   * ⚠️ 不要在这里放回调函数：导航参数经框架传递后，挂在对象上的函数会丢失。
   */
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
