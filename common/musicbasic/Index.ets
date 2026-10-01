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
 * Barrel file for musicbasic (common HAR). All public exports are listed here.
 */

import { AppRuntimeStorage, getAppRuntime as getAppRuntimeFromModel } from './src/main/ets/model/AppRuntimeStorage';

// Constants (single Constants.ets file; class names unchanged)
export {
  AppStorageKeys,
  BarLayoutModes,
  BreakpointConstants,
  GridConstants,
  PlaybackIntentLogEvent,
  PlaybackShellConstants,
  RouterUrlConstants,
  SdkConstants,
  SongConstants,
  StyleConstants,
  TitleBarConstants,
  WatchNavRouteConstants
} from './src/main/ets/constants/Constants';
export { LiveViewConst } from './src/main/ets/constants/LiveViewConst';

export { TabItem } from './src/main/ets/model/TabItem';

// Data and in-memory DB mocks
export { SongRow } from './src/main/ets/data/SongRow';
export { PlaylistRow } from './src/main/ets/data/PlaylistRow';
export { RecommendFeedKind, RecommendFeedRow } from './src/main/ets/data/RecommendFeedRow';
export { MusicMemoryStore } from './src/main/ets/db/MusicMemoryStore';
export { MusicDbApi } from './src/main/ets/util/MusicDbApi';

// API DTOs for MusicDbApi (separate from row types in data/*)
export {
  SongApiDto,
  HeroCardApiDto,
  RecommendCardApiDto,
  TabApiDto
} from './src/main/ets/api/MusicApiDtos';
export { SongDtoMapper } from './src/main/ets/api/SongDtoMapper';

// Model: bind getAppRuntime via export const so runtimes that skip re-exported functions still resolve.
export { CoverCacheService, CoverCacheState } from './src/main/ets/services/CoverCacheService';
export { CoverCacheSettingsCard } from './src/main/ets/components/CoverCacheSettingsCard';
export { AppRuntimeStorage };
export const getAppRuntime = getAppRuntimeFromModel;
export { MenuData } from './src/main/ets/model/MenuData';
export { SongItem, QualityInfo } from './src/main/ets/model/SongData';
export { OptionItem } from './src/main/ets/model/OptionItem';
export { MusicAppState } from './src/main/ets/model/MusicAppState';
export { PlaybackIntentState } from './src/main/ets/model/PlaybackIntentState';
export { SongDataSource } from './src/main/ets/model/SongDataSource';
export { PlayedSongRecord } from './src/main/ets/model/PlayedSongRecord';
export { TabSwitchState } from './src/main/ets/model/TabSwitchState';
export { AmbientState } from './src/main/ets/model/AmbientState';
export { ThemeState } from './src/main/ets/model/ThemeState';
export { HomeSourceState } from './src/main/ets/model/HomeSourceState';
export { ShowMiniLyricState } from './src/main/ets/model/ShowMiniLyricState';
export { PlaybackFlowLightState } from './src/main/ets/model/PlaybackFlowLightState';
export { CoverTintState } from './src/main/ets/model/CoverTintState';
export { ShowSubLyricState } from './src/main/ets/model/ShowSubLyricState';
export { LyricFpsState } from './src/main/ets/model/LyricFpsState';
export { LyricCenterState } from './src/main/ets/model/LyricCenterState';
export { CoverRadiusState } from './src/main/ets/model/CoverRadiusState';
export { FavoriteEntry } from './src/main/ets/model/FavoriteEntry';
export { PlaylistTransitionState, PlaylistTransitionRect, getPlaylistTransitionState,
  PLAYLIST_HERO_COVER_ID, PLAYLIST_TRANSITION_HOST_ID } from './src/main/ets/model/PlaylistTransitionState';
export { DataBackupService } from './src/main/ets/util/DataBackupService';
export { PlaybackPreferenceService } from './src/main/ets/util/PlaybackPreferenceService';
export { MusicCardBridge } from './src/main/ets/model/MusicCardBridge';
export type { MusicCardSnapshot } from './src/main/ets/model/MusicCardBridge';
export { PlaybackFullscreenState } from './src/main/ets/model/PlaybackFullscreenState';
export { LyricBlurState } from './src/main/ets/model/LyricBlurState';
export { LyricFontSizeState } from './src/main/ets/model/LyricFontSizeState';
export { UseAccountRecState } from './src/main/ets/model/UseAccountRecState';
export { HomePlazaState } from './src/main/ets/model/HomePlazaState';
export { HomeRankingState } from './src/main/ets/model/HomeRankingState';
export { ToplistRouteParam, BoardSongParam } from './src/main/ets/model/ToplistRouteParam';
export { RankingRouteParam } from './src/main/ets/model/RankingRouteParam';
export { ArtistRouteParam, AlbumRouteParam } from './src/main/ets/model/ArtistRouteParam';
export { PlaylistDto } from './src/main/ets/model/PlaylistDto';

// util
export { BreakpointType, isWidthBreakpointLgOrXl } from './src/main/ets/util/BreakpointSystem';
export { Logger } from './src/main/ets/util/Logger';
export { StringResourceUtil } from './src/main/ets/util/StringResourceUtil';
export { ImmersiveType } from './src/main/ets/util/ImmersiveType';
export {
  WindowUtil,
  WindowInfo,
  WINDOW_INFO_STORAGE_KEY,
  getWindowInfoState
} from './src/main/ets/util/WindowUtil';
export { getStatusBarTopVpFromWindowUtil } from './src/main/ets/util/StatusBarInsetUtil';
export { buildTitleMaterial } from './src/main/ets/util/TitleMaterial';
export { SdkApiUtil } from './src/main/ets/util/SdkApiUtil';
export { BarScrollHelper, BarScrollDeltaTracker } from './src/main/ets/util/BarScrollHelper';
export { guardPlayerBack } from './src/main/ets/util/PlayerBackGuard';
export { ColorConversion } from './src/main/ets/util/ColorConversion';
export { MusicStoreService } from './src/main/ets/util/MusicStoreService';
export { appendPlayLog, appendError } from './src/main/ets/util/LxLogger';

export { MusicEmptyComponent } from './src/main/ets/components/MusicEmptyComponent';
export { MusicTextIcon } from './src/main/ets/components/MusicTextIcon';
// 封面图：本地沙箱文件自己解码成 PixelMap 再显示（绕开 file:// URI 的解析差异）
export { LocalCoverImage } from './src/main/ets/components/LocalCoverImage';
export {
  PlayerExpandState,
  MINI_BAR_COVER_ID,
  PLAYER_BIG_COVER_ID,
  areaLengthToVp
} from './src/main/ets/model/PlayerExpandState';
export type { LyricMorphRect } from './src/main/ets/model/PlayerExpandState';
// 裁剪容器形变（对标无界 ExpandAnimation）：阶段机 + 容器几何
export { MorphMetaBridge } from './src/main/ets/components/MorphMetaBridge';
export { MorphMetaEndpoint, MINI_META_TITLE_ID, MINI_META_SINGER_ID,
  PLAYER_META_TITLE_ID, PLAYER_META_SINGER_ID } from './src/main/ets/model/MorphMetaGeometry';
export { MorphStage, MorphDrive } from './src/main/ets/model/PlayerExpandState';
export {
  MINI_BAR_ID,
  MINI_BAR_FLOATING_ID,
  MINI_BAR_COVER_FLOATING_ID,
  MINI_BAR_ASIDE_ID,
  MINI_BAR_ASIDE_FLOATING_ID,
  MORPH_HOST_ID
} from './src/main/ets/model/PlayerExpandState';
