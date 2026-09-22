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
 * Playlist list refresh bus.
 *
 * 歌单列表页 (PlaylistsPage) 是常驻 Tab，从歌单详情页添加/删除歌曲返回后不会重新
 * aboutToAppear，仅靠 @Monitor('store.playlistVersion') 刷新不可靠。这里提供一个
 * 模块内的显式回调通道：弹层写库成功后直接通知列表页重新读库，不依赖响应式机制。
 */

let refreshAction: (() => void) | null = null;

/** 由歌单列表页在 aboutToAppear 注册，页面销毁时注销。 */
export function registerPlaylistRefresh(action: () => void): void {
  refreshAction = action;
}

/** 由歌单列表页在 aboutToDisappear 注销，避免持有已销毁组件的引用。 */
export function unregisterPlaylistRefresh(): void {
  refreshAction = null;
}

/** 歌单内容发生增删后调用，触发列表页重新读库刷新数量。 */
export function notifyPlaylistChanged(): void {
  if (refreshAction !== null) {
    refreshAction();
  }
}
