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
   * 迷你条右侧"操作按钮簇"整体的显示优先级（**必须高于所有单个按钮**）。
   *
   * ArkUI 官方的 `displayPriority` 语义（`ts-universal-attributes-layout-constraints`）：
   * "若父容器空间不足，隐藏低优先级子组件。**若某一优先级级别的子组件被隐藏，
   * 则所有更低优先级的子组件也都会被隐藏**"，且"不大于 1 的所有值优先级相同"。
   *
   * ⚠️ 这就是"播放列表按钮被挤出播放条 / 消失"的根因：
   *    原来四个按钮各自设 3/4/5/6，**按钮簇本身没有优先级**，于是容器空间不足时
   *    系统可以按整数优先级把播放列表（4）连同更低的一起隐藏 —— 用户看到的正是
   *    "列表按钮不见了"。改成"先按固有尺寸占位、只在容器的整数优先级上兜底"之后，
   *    被压缩的永远是左侧元信息（它带 `layoutWeight(1)`），按钮簇最后才让位。
   */
  public static readonly DISPLAY_PRIORITY_MINI_ACTIONS: number = 6;

  /**
   * 迷你条右侧操作按钮的点击热区边长（vp）。设计常量 `MINI_ACT_SIZE = 40`。
   *
   * ⚠️ 不是"图标尺寸"：图标仍由 `fontSize(24)` 决定，这里是**布局占位宽度**。
   *    原先只给 `SymbolGlyph.fontSize(24)`，占位宽度究竟是多少没有保证 ——
   *    按 24 算的话一排按钮只需 ~100vp，按 40 算要 166vp，差出来的那 60vp
   *    正好能让"列表按钮"被挤出可见胶囊（用户实测）。
   */
  public static readonly MINI_ACT_SIZE: number = 40;

  /**
   * 迷你条右侧操作图标尺寸（vp）。设计常量 `MINI_ACT_ICON = 24`。
   */
  public static readonly MINI_ACT_ICON: number = 24;

  /**
   * 迷你条右侧操作按钮间距（vp）。设计常量 `MINI_ACT_GAP = 2`。
   */
  public static readonly MINI_ACT_GAP: number = 2;

  /**
   * 迷你条胶囊的**内容高度**（vp）。设计常量 `BAR_CONTENT_H = 40`。
   */
  public static readonly MINI_BAR_CONTENT_H: number = 40;

  /**
   * 迷你条折叠态高度相对内容高度的系数（`40 × 1.4 = 56`）。
   */
  public static readonly MINI_BAR_COLLAPSED_RATIO: number = 1.4;

  /**
   * 迷你条封面相对内容高度的比例（设计常量 `MINI_COVER_RATIO = 0.8`）。
   */
  public static readonly MINI_COVER_RATIO: number = 0.8;

  /**
   * 迷你条未量到高度时右侧额外内边距（vp）。设计常量 `MINI_EDGE_PAD = 10`。
   */
  public static readonly MINI_EDGE_PAD: number = 10;

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

  /**
   * AppStorageV2 key for {@link HuaweiAccountState}（华为账号系统登录的登录态）。
   */
  public static readonly HUAWEI_ACCOUNT_STATE: string = 'player_HuaweiAccountState';
}