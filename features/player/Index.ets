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

export { Player } from './src/main/ets/view/Player';
export { QueuePlaylistSheet } from './src/main/ets/view/QueuePlaylistSheet';
export { PlayerConstants } from './src/main/ets/constant/PlayerConstants';
export { AccountChangedState } from './src/main/ets/account/AccountChangedState';
export { SwitchBannerState, SWITCH_BANNER_STORAGE_KEY } from './src/main/ets/model/SwitchBannerState';
export { PlaybackPage, PlaybackPageCoverContent, PlaybackPagePanelCoverContent } from './src/main/ets/view/PlaybackPage';
export { MediaService, setLocalLyricResolver } from './src/main/ets/model/MediaService';
export type { LocalLyricResolver } from './src/main/ets/model/MediaService';
// 华为账号（系统 Account Kit）登录：登录态 + 资料
export { HuaweiAccountService, HuaweiAccountState, HuaweiAuthError } from './src/main/ets/account/HuaweiAccountService';
export type { HuaweiAccountProfile } from './src/main/ets/account/HuaweiAccountService';
// 华为云空间直存（设置 + 歌单备份/恢复，走云盘 OpenAPI，不经 WebDAV 网关）
export { HuaweiCloudSync } from './src/main/ets/account/HuaweiCloudSync';
export type { HuaweiDriveUser } from './src/main/ets/account/HuaweiCloudSync';
export { MusicAppState } from './src/main/ets/model/PlayerModels';
export { PlayerViewModel } from './src/main/ets/viewmodel/PlayerViewModel';
export { MusicPlayMode, AudioPlayerState } from './src/main/ets/model/MusicData';
export { ColorConversion } from './src/main/ets/util/ColorConversion';
export { dispatchShellPlaybackIntent } from './src/main/ets/util/PlaybackIntentShell';
export { SongPageBuilder } from './src/main/ets/view/SongPage';
export { MusicRecognitionPageBuilder } from './src/main/ets/view/MusicRecognitionPage';
export { VolumeSlider } from './src/main/ets/view/VolumeSlider';
export { OnlinePlayUtil } from './src/main/ets/util/OnlinePlayUtil';
export { LXSourceHost } from './src/main/ets/source/LXSourceHost';
export { LXSourceEngine, lxEngineIsReady } from './src/main/ets/source/LXSourceEngine';
export { lxSourceManager } from './src/main/ets/source/LXSourceManager';
export type { LXApiImportResult } from './src/main/ets/source/LXSourceManager';
export { getLXMusicUrl, getLXLyric, getLXPic, logError, fetchBoardSongs } from './src/main/ets/source/LXPlayHelper';
export type { BoardSongEntry } from './src/main/ets/source/LXPlayHelper';
export { lxGetQualityOptions, lxGetQualityOptionsForSongs, LXQualityOption } from './src/main/ets/source/LXQualityApi';
export type { LXBatchQualityResult } from './src/main/ets/source/LXQualityApi';
// 平台中文名（kw→酷我、wy→网易云…），批量下载的失败提示里要带上它
export { sourceDisplayName } from './src/main/ets/util/SourceFallbackUtil';
export { lxSearch, lxLeaderboard, getLeaderboardEntries, lxGetPicFallback, lxGetLyricFallback,
  lxTxToplist, lxTxToplistInfo, lxTxSingerList, lxKgSingerList, lxTxToplistList, lxTxHotSearch,
  lxGetWyLyricAll, lxGetTTMLLyric, lxGetLyricFull } from './src/main/ets/source/LXMusicSDK';
export { buildSongShareText, showSystemShare } from './src/main/ets/util/ShareUtil';
export { LyricLiveViewController } from './src/main/ets/util/LyricLiveViewController';
export type { LiveViewLyricPayload } from './src/main/ets/util/LyricLiveViewController';
export { DownloadUtil } from './src/main/ets/util/DownloadUtil';
export { DownloadService, DownloadStatus, DownloadTask } from './src/main/ets/util/DownloadService';
export type { TxToplistInfo } from './src/main/ets/source/LXMusicSDK';
export type { LXSearchSong, LXSearchResult, LXQualityType, LXLeaderboardEntry, WyLyricResult, LyricFullResult } from './src/main/ets/source/LXMusicSDK';
export type { LXUserApiInfo, LXUserApiInfoFull, LXUserApiSourceInfo, LXSource, LXQuality } from './src/main/ets/source/Interface';
export { AmllLyricFormat } from './src/main/ets/amll/model/AmllTypes';
export { amllProbeLyricText, amllProbeToString, amllFormatName } from './src/main/ets/amll/util/AmllParserProbe';
export type { AmllProbeResult } from './src/main/ets/amll/util/AmllParserProbe';
export { SharePlaylistService } from './src/main/ets/shareplaylist/SharePlaylistService';
export { SharePlaylistSource } from './src/main/ets/shareplaylist/SharePlaylistTypes';
export type { SharePlaylistInfo, SharePlaylistSong, SharePlaylistSourceOption } from './src/main/ets/shareplaylist/SharePlaylistTypes';
export { PlaylistSearchApi } from './src/main/ets/shareplaylistsearch/PlaylistSearchApi';
export type { SearchPlaylistInfo, SearchPlaylistSong } from './src/main/ets/shareplaylistsearch/PlaylistSearchTypes';
export { AccountService } from './src/main/ets/account/AccountService';
export { sourceName, QrLoginStatus, PlatformAccount, PlaylistInfo, PlaylistTrackInfo, PlatformTrackInfo, PlaylistMutationTrack } from './src/main/ets/account/AccountModels';
export type {
  LoginSession, QrCodeLoginState, QrCodeLoginResult, AccountLoginResult
} from './src/main/ets/account/AccountModels';
export { SingerInfo, AlbumInfo, SongInfo, ArtistInfo, SearchPageResult, SongPageResult, ArtistAlbumPageResult,
  AlbumDetailResult } from './src/main/ets/geuz/index';
export type { ArtistDetailParams, AlbumDetailParams } from './src/main/ets/geuz/index';
export { searchSingers, searchAlbums, sourceToCode, codeToSource, getArtistDetail, getArtistSongs,
  getArtistAlbums, getAlbumDetail } from './src/main/ets/geuz/index';
export { PLAYER_BIG_COVER_ID } from './src/main/ets/view/MusicPlayInfoBlock';
