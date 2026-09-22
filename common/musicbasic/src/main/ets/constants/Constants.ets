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
 * Breakpoint / grid layout numbers; used with BreakpointType, Grid, etc.
 */
export class BreakpointConstants {
  /** Column count for the SM width breakpoint. */
  public static readonly COLUMN_SM: number = 4;
  /** Column count for the MD width breakpoint. */
  public static readonly COLUMN_MD: number = 8;
  /** Column count for the LG width breakpoint. */
  public static readonly COLUMN_LG: number = 12;
  /** Column count for the lyric area on large breakpoints. */
  public static readonly COLUMN_LYRIC_LG: number = 7;

  /** Horizontal gutter for the main music area (vp or same unit as layout). */
  public static readonly GUTTER_MUSIC_X: number = 24;

  /** Default span for SM. */
  public static readonly SPAN_SM: number = 4;
  /** Default span for MD. */
  public static readonly SPAN_MD: number = 6;
  /** Span for the lyric area on large breakpoints. */
  public static readonly SPAN_LYRIC_LG: number = 5;

  /** Grid offset for the MD breakpoint. */
  public static readonly OFFSET_MD: number = 1;
}

/**
 * Common full-size width/height strings (e.g. width/height '100%' in ArkUI).
 */
export class StyleConstants {
  /** Full width of the parent. */
  public static readonly FULL_WIDTH: string = '100%';
  /** Full height of the parent. */
  public static readonly FULL_HEIGHT: string = '100%';
  /** Circular clip / capsule radius (e.g. wearable list icons). */
  public static readonly CIRCLE_BORDER_RADIUS: string = '50%';
}

/**
 * Grid item span in a 12-column system.
 */
export class GridConstants {
  /** Spans 4 columns. */
  public static readonly SPAN_FOUR: number = 4;
  /** Spans 6 columns. */
  public static readonly SPAN_SIX: number = 6;
  /** Spans 8 columns. */
  public static readonly SPAN_EIGHT: number = 8;
  /** Spans 12 columns. */
  public static readonly SPAN_TWELVE: number = 12;
}

/**
 * NavPath / navigation stack page names; must match registered route names.
 */
export class RouterUrlConstants {
  /** Playlist detail page. */
  public static readonly PLAYLIST_DETAIL: string = 'PlaylistDetailPage';
  /** 首页「每日30首」入口打开的推荐列表页。 */
  public static readonly DAILY_THIRTY: string = 'DailyThirtyPage';
  public static readonly MUSIC_RECOGNITION: string = 'MusicRecognitionPage';
  /** Split-column playlist (wide) page. */
  public static readonly SPLIT_COLUMN_PLAYLIST: string = 'SplitColumnPlaylistPage';
  /** Online search page (from home top bar search entry). */
  public static readonly ONLINE_SEARCH: string = 'OnlineSearchPage';
  /** Artist detail page (singer profile with full song list). */
  public static readonly ARTIST_DETAIL: string = 'ArtistDetailPage';
  public static readonly SETTINGS_DETAIL: string = 'SettingsDetailPage';
  /** Album detail page (album cover + track list). */
  public static readonly ALBUM_DETAIL: string = 'AlbumDetailPage';
  /** Settings category sub-page (second level of the settings menu). */
  public static readonly SETTING_CATEGORY: string = 'SettingCategoryPage';
  /** Guest ranking boards overview page (multi-source). */
  public static readonly RANKING_BOARDS: string = 'RankingBoardsPage';
  /** Guest ranking board detail page (board track list). */
}

/**
 * Durations (ms) for track transitions, etc. (exact unit depends on the API used).
 */
export class SongConstants {
  /** Cross-fade or transition between tracks; not the same as full-screen player open. */
  public static readonly TRANSITION_DURATION: number = 500;
}

/**
 * App shell: full-screen player open animation, paired with UIContext.animateTo in entry Index.
 */
export class PlaybackShellConstants {
  /** Duration (ms) for animating from mini player to full-screen player. */
  public static readonly OPEN_PLAYER_UI_ANIMATION_MS: number = 380;
}

/**
 * Watch product: page names on the nav stack; must match NavDestination / stack config.
 */
export class WatchNavRouteConstants {
  /** Hot playlists / playlist swiper entry. */
  public static readonly PLAY_LIST: string = 'playList';
  /** Favorites / song list. */
  public static readonly SONG_LIST: string = 'songList';
  /** Now playing screen. */
  public static readonly SONG_PAGE: string = 'songPage';
  /** Settings placeholder; ignore tap until implemented. */
  public static readonly SETTING: string = 'setting';
}

/**
 * HiLog labels for unified playback-intent handling; search or forward to analytics from one place.
 */
export class PlaybackIntentLogEvent {
  /** Shell starts handling a PlaybackIntentState change. */
  public static readonly SHELL_DISPATCH: string = 'shell_playback_intent';
  /** Request to present full-screen player UI. */
  public static readonly OPEN_PLAYER_UI: string = 'open_player_ui';
  /** Resolve index in queue and start load/playback. */
  public static readonly LOAD_QUEUE: string = 'load_queue';
  /** Requested song id is not in the local library. */
  public static readonly SONG_NOT_IN_DB: string = 'pending_song_not_in_db';
}

/**
 * Minimum system API level gates (compare with SdkApiUtil, distributionOSApiVersion, etc.).
 */
export class SdkConstants {
  /**
   * API 23 = HarmonyOS 6.1.0(23). Used for HDS tab bar floating, etc. Reuse for any feature
   * that needs the same floor; do not duplicate the magic number 23.
   */
  public static readonly HDS_TABS_BAR_FLOATING_MIN_SDK_API: number = 23;
  /**
   * API 24 = HarmonyOS 6.1.1(24)。自此版本起 `HdsTabs` 的 miniBar 支持
   * `barLayoutMode`（迷你条与页签上下两排 / 单排），低版本必须传 undefined。
   */
  public static readonly HDS_TABS_BAR_TWO_ROW_MIN_SDK_API: number = 24;
  /**
   * `deviceInfo.distributionOSApiVersion` 上 6.1.1(24) 的取值
   * （该字段格式为主版本*10000 + 次版本*100 + 补丁，与 `sdkApiVersion` 不同）。
   */
  public static readonly DISTRIBUTION_OS_6_1_1_CODE: number = 60101;
}

/**
 * 双层底栏排布模式（数值与 HDS 的 `HdsBarLayoutMode` 一致）。
 * 放在 common 层而不是直接引用 HDS 枚举，是为了避免 common 依赖 HDS UI 类型。
 */
export class BarLayoutModes {
  /** 单排：迷你条被拉成整条通栏（"宽"样式 = 展开播放态）。 */
  public static readonly HORIZONTAL: number = 0;
  /** 上下两排：迷你条是一条"窄"胶囊、页签单独一排（**默认**）。 */
  public static readonly VERTICAL: number = 1;
}

/**
 * Shared HDS title bar frost values for IMMERSIVE_GRADIENT_BLUR scroll-effect title bars.
 */
export class TitleBarConstants {
  /** HDS title bar content row height (vp), used to pad content below the floating title bar. */
  public static readonly ROW_HEIGHT_VP: number = 56;
}

/**
 * {@link AppStorageV2.connect} link keys for shared observable state (prefix {@code musichome_}).
 */
export class AppStorageKeys {
  /** {@link MusicAppState} */
  public static readonly MUSIC_APP_STATE: string = 'musichome_MusicAppState';
  /** {@link PlaybackIntentState} */
  public static readonly PLAYBACK_INTENT_STATE: string = 'musichome_PlaybackIntentState';
  /** Watch playlist navigation context ({@link WatchNavContext} in playlist feature). */
  public static readonly WATCH_NAV_CONTEXT: string = 'musichome_WatchNavContextStore';
  /** {@link WindowInfo} */
  public static readonly WINDOW_INFO: string = 'musichome_WindowInfo';
  /** {@link AppRuntimeStorage} */
  public static readonly APP_RUNTIME: string = 'musichome_AppRuntimeStorage';
  /** {@link TabSwitchState} (bottom tab / playlist section switching). */
  public static readonly TAB_SWITCH_STATE: string = 'musichome_TabSwitchState';
  /** {@link AmbientState} (bottom-bar immersive material level). */
  public static readonly AMBIENT_STATE: string = 'musichome_AmbientState';
/** {@link ThemeState} (app accent color). */
public static readonly THEME_STATE: string = 'musichome_ThemeState';
/** {@link HomeSourceState} (home recommendation source id). */
public static readonly HOME_SOURCE_STATE: string = 'musichome_HomeSourceState';
/** {@link ShowMiniLyricState} (playback page mini lyric lines). */
public static readonly SHOW_MINI_LYRIC_STATE: string = 'musichome_ShowMiniLyricState';
/** {@link PlaybackFlowLightState} (playback page flow-light background toggle). */
public static readonly PLAYBACK_FLOW_LIGHT_STATE: string = 'musichome_PlaybackFlowLightState';
/** {@link CoverTintState} (flow-light colors extracted from the current cover). */
public static readonly COVER_TINT_STATE: string = 'musichome_CoverTintState';
  /** {@link PlayerExpandState} (playback page one-shot expand animation). */
  public static readonly PLAYER_EXPAND_STATE: string = 'musichome_PlayerExpandState';
/** {@link ShowSubLyricState} (lyrics page translation/romanization sub-lines). */
public static readonly SHOW_SUB_LYRIC_STATE: string = 'musichome_ShowSubLyricState';
/** {@link LyricFpsState} (lyrics page render frame rate). */
public static readonly LYRIC_FPS_STATE: string = 'musichome_LyricFpsState';
  public static readonly LYRIC_CENTER_STATE: string = 'musichome_LyricCenterState';
  public static readonly COVER_RADIUS_STATE: string = 'musichome_CoverRadiusState';
  public static readonly PLAYBACK_FULLSCREEN_STATE: string = 'musichome_PlaybackFullscreenState';
/** {@link LyricBlurState} (lyrics page blur-effect toggle). */
public static readonly LYRIC_BLUR_STATE: string = 'musichome_LyricBlurState';
/** {@link LyricFontSizeState} (lyrics page active-line font size). */
public static readonly LYRIC_FONT_SIZE_STATE: string = 'musichome_LyricFontSizeState';
/** {@link UseAccountRecState} (home recommendation uses logged-in account daily picks). */
public static readonly USE_ACCOUNT_REC_STATE: string = 'musichome_UseAccountRecState';
/** {@link HomePlazaState} (home page shows the playlist plaza section). */
public static readonly HOME_PLAZA_STATE: string = 'musichome_HomePlazaState';
/** {@link HomeRankingState} (home page shows the ranking boards section). */
public static readonly HOME_RANKING_STATE: string = 'musichome_HomeRankingState';
}
