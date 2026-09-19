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

import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys } from 'musicbasic';

/**
 * Watch-only navigation state: which playlist the user opened so the song list can show the same title.
 */
@ObservedV2
export class WatchNavContext {
  /** Title of the playlist currently selected for the watch song list screen. */
  @Trace public selectedPlaylistTitle: Resource = $r('app.string.watch_song_list_default_playlist');
}

/**
 * Returns the shared WatchNavContext instance from AppStorageV2, creating it if missing.
 */
export function getWatchNavContext(): WatchNavContext {
  return AppStorageV2.connect(WatchNavContext, AppStorageKeys.WATCH_NAV_CONTEXT, () => new WatchNavContext())!;
}
