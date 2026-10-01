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

export { MiniBarPlayer } from './src/main/ets/view/MiniBarPlayer';
export { HomeMiniBarPlayer } from './src/main/ets/view/HomeMiniBarPlayer';
// 形变克隆层（挂在壳层）要复用迷你条右侧那一块的**副本**（歌名/歌手 + 播放按钮）——
// 反编译里 `MainPage` 的元信息克隆/操作区克隆就是这么画的，所以 Aside 也要导出。
export { HomeMiniBarPlayerAside } from './src/main/ets/view/HomeMiniBarPlayerAside';
export { PlaylistFloatingMiniBar } from './src/main/ets/view/PlaylistFloatingMiniBar';
export { SongMoreMenu } from './src/main/ets/view/SongMoreMenu';
export { PlaylistDetailPage, PlaylistDetailPageBuilder } from './src/main/ets/view/PlaylistDetailPage';
export { ToplistRouteParam } from 'musicbasic';
export { PlaylistHomePage } from './src/main/ets/view/PlaylistHomePage';
export { PlaylistsPage } from './src/main/ets/view/PlaylistsPage';
export { SplitColumnPlaylistPage, SplitColumnPlaylistPageBuilder } from './src/main/ets/view/SplitColumnPlaylistPage';
export { PlaylistHub, PlayListBuilder } from './src/main/ets/view/PlaylistHubPage';
export { SongListBuilder } from './src/main/ets/view/SongQueueListPage';
export { getWatchNavContext, WatchNavContext } from './src/main/ets/model/WatchNavContext';
export { MINI_BAR_COVER_ID } from './src/main/ets/view/HomeMiniBarAlbumCover';
export { PlaylistTransitionOverlay } from './src/main/ets/view/PlaylistTransitionOverlay';
