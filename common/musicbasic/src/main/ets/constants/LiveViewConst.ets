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
 * Shared constants for the music live view (实况窗) feature:
 * ids, scenario event, common-event name, and lock screen extension parameters.
 * Shared by the player feature (publisher) and the entry module (lock screen subscriber).
 */
export class LiveViewConst {
  /** Fixed live view id for the single music live view of this app (developer generated). */
  public static readonly LIVE_VIEW_ID: number = 1001;
  /**
   * Live view application scenario. The Live View Kit has no dedicated music scenario,
   * so the generic TIMER (计时) scenario is used.
   */
  public static readonly LIVE_VIEW_EVENT: string = 'TIMER';
  /** Name of the LiveViewLockScreenExtensionAbility registered in module.json5. */
  public static readonly LIVE_VIEW_LOCK_ABILITY: string = 'LiveViewExtAbility';
  /** Key of the initial data passed into the lock screen ability via want.parameters. */
  public static readonly LIVE_VIEW_PARAM_KEY: string = 'liveViewParameters';
  /** Common event name used to push lyric updates from the app process to the lock screen process. */
  public static readonly LIVE_VIEW_LYRIC_EVENT: string = 'com.rzdpai.music.LIVE_VIEW_LYRIC_UPDATE';
  /** LocalStorage key holding the initial payload for the lock screen page. */
  public static readonly LS_INIT_DATA_KEY: string = 'liveViewInitData';
}
