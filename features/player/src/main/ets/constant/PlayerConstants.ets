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
 * Constants for player area.
 */
export class PlayerConstants {
  /**
   * The font size of the singer is smaller.
   */
  public static readonly FONT_REDUCE: number = 4;

  /**
   * The layout weight of player control.
   */
  public static readonly LAYOUT_WEIGHT_PLAYER_CONTROL: number = 1;

  /**
   * Mini bar: playlist / queue entry icon (lowest displayPriority in the transport row).
   */
  public static readonly DISPLAY_PRIORITY_PLAYLIST_ENTRY: number = 1;

  /**
   * Mini bar: previous / next track controls (middle stacking order).
   */
  public static readonly DISPLAY_PRIORITY_TRACK_SKIP: number = 2;

  /**
   * Mini bar: center play / pause control (highest stacking order).
   */
  public static readonly DISPLAY_PRIORITY_PLAY_PAUSE: number = 3;

  /**
   * The rotate is 360.
   */
  public static readonly ROTATE: number = 360;

  /**
   * The animation duration is 3000 ms.
   */
  public static readonly ANIMATION_DURATION: number = 3000;

  /**
   * The value of iterations.
   */
  public static readonly ITERATIONS: number = -1;

  /**
   * The value of font family.
   */
  public static readonly FONT_FAMILY_BLACK: string = 'HarmonyHeiTi';

  /**
   * The value of font family.
   */
  public static readonly FONT_FAMILY_BOLD: string = 'HarmonyHeiTi-Bold';

  /**
   * The value of font family.
   */
  public static readonly FONT_FAMILY_MEDIUM: string = 'HarmonyHeiTi-Medium';

  /**
   * The value of encoding.
   */
  public static readonly ENCODING: string = 'utf-8';

  /**
   * The value of back ground image width and height.
   */
  public static readonly BACK_IMAGE: string = '120%';

  /**
   * Set the image blur level.
   */
  public static readonly IMAGE_BLUR: number = 15;

  /**
   * Shared element transition id for the album cover (mini bar <-> full-screen player).
   */
  public static readonly SHARED_TRANSITION_COVER: string = 'player_cover';

  /**
   * Shared element transition id for the track title.
   */
  public static readonly SHARED_TRANSITION_TITLE: string = 'player_title';

  /**
   * Shared element transition id for the track singer.
   */
  public static readonly SHARED_TRANSITION_SINGER: string = 'player_singer';

  /**
   * Duration (ms) of the shared element open animation; matches PlaybackShellConstants.OPEN_PLAYER_UI_ANIMATION_MS.
   */
  public static readonly SHARED_TRANSITION_DURATION: number = 380;

  /**
   * AppStorageV2 key for {@link AccountChangedState} (home reloads when a platform account mutates).
   */
  public static readonly ACCOUNT_CHANGED_STATE: string = 'player_AccountChangedState';
}