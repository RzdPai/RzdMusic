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

/*
 * Player feature: UI-only track model and re-exports for global state (no raw common data row types).
 */

/**
 * Lightweight view model for mini bar and full-screen player (UI fields only).
 */
export class PlayerTrackUi {
  /** Stable song id from the play queue. */
  public id: number = 0;
  /** Primary title line (string or string resource). */
  public title: string | Resource = '';
  /** Artist or subtitle line (string or string resource). */
  public singer: string | Resource = '';
  /** Album art as a Resource reference (e.g. media id). */
  public cover: Resource = $r('app.string.page_show');
  /** Online cover image url; empty when unavailable. */
  public coverUrl: string = '';
}

export { MusicAppState } from 'musicbasic';
export { RouterUrlConstants } from 'musicbasic';
