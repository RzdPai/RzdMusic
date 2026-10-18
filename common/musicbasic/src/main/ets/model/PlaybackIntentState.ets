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
 * Cross-feature playback request (AppStorageV2: PlaybackIntentState).
 * View models only bump this; the shell listens and writes {@link MusicAppState} and media.
 */
@ObservedV2
export class PlaybackIntentState {
  /** Incremented on each intent so the shell reacts even when the song id is unchanged. */
  @Trace public requestVersion: number = 0;
  /** Song id to play, matching {@link MusicAppState.playQueueIds}; -1 when unset. */
  @Trace public pendingPlaySongId: number = -1;
  /** Index in MusicAppState's existing queue (online/local records); -1 when unset. */
  @Trace public pendingQueueIndex: number = -1;
  /** When true, the shell should present full-screen player UI. */
  @Trace public openPlayerUi: boolean = false;
  /**
   * 播放页 chrome 的「打开歌曲菜单」请求序号（每次点击 +1）。
   *
   * ★ 2026-10-18（用户：「把右上角的分享改成歌曲菜单」）：右上角那颗按钮在
   *   `TopAreaComponent` 里，而菜单弹层只有 `ControlAreaComponent` 能挂（一个组件只能挂一个
   *   `bindSheet`）。两者之间**没有**父子参数链（`TopAreaComponent` 被挂两处、
   *   `ControlAreaComponent` 被挂更多处），所以走这条已经存在的共享状态：点方只 bump 序号，
   *   菜单方 `@Monitor` 响应。序号而非布尔：连点两次也要能重新打开。
   */
  @Trace public menuRequestSeq: number = 0;
  /**
   * 播放页 meta 行「评论」按钮的请求序号（每次点击 +1），语义同 {@link menuRequestSeq}。
   *
   * 评论面板是 `ControlAreaComponent` 那个弹层里的**子页**（复用底部「评论」按钮的
   * `openCommentSheet()`），所以同样只传一个序号，不复制面板。
   */
  @Trace public commentRequestSeq: number = 0;
}
