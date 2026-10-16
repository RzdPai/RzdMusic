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
// 华为账号（系统 Account Kit + 网页授权双路径）登录：登录态 + 资料 + 回退判据
export {
  HuaweiAccountService, HuaweiAccountState, HuaweiAuthError, HuaweiLoginMode, HuaweiLoginOutcome
} from './src/main/ets/account/HuaweiAccountService';
export type { HuaweiAccountProfile } from './src/main/ets/account/HuaweiAccountService';
export {
  HuaweiAccountCode, huaweiNeedsWebFallback, huaweiFallbackReason, huaweiIsCapabilityUnavailable
} from './src/main/ets/account/HuaweiAccountCode';
// 华为云空间直存（设置 + 歌单备份/恢复，走云盘 OpenAPI，不经 WebDAV 网关）
export { HuaweiCloudSync } from './src/main/ets/account/HuaweiCloudSync';
export { HuaweiNativeCloudBackup } from './src/main/ets/account/HuaweiNativeCloudBackup';
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
// 自定义音源的跨设备搬运载荷（**全仓唯一实现**）：WebDAV / 系统华为云空间 / 旧网页云盘
// 三条备份通道都以它为挂载点。放在 player 是因为 sync → player 是单向依赖，
// player 反向 import sync 会成环（详见该文件头部说明）。
export {
  SOURCE_SYNC_KEY, MAX_SOURCES, MAX_SCRIPT_CHARS,
  collectSourcePayload, applySourcePayload, describeSourceMerge,
  attachSourcesToSnapshot, mergeSourcesFromSnapshot, mergeSourcesIntoRestoreResult
} from './src/main/ets/source/SourceBackupPayload';
export type { SourcePayload, SourcePayloadEntry, SourceMergeReport } from './src/main/ets/source/SourceBackupPayload';
export { getLXMusicUrl, getLXLyric, getLXPic, logError, fetchBoardSongs } from './src/main/ets/source/LXPlayHelper';
export type { BoardSongEntry } from './src/main/ets/source/LXPlayHelper';
export { lxGetQualityOptions, lxGetQualityOptionsForSongs, LXQualityOption } from './src/main/ets/source/LXQualityApi';
export type { LXBatchQualityResult } from './src/main/ets/source/LXQualityApi';
// 平台中文名（kw→酷我、wy→网易云…），批量下载的失败提示里要带上它
// 音源脚本「声明了哪些平台 / 什么音质 / 能做什么」的只读摘要（「音源管理」用）
export { lxDeclaredPlatforms, lxDeclaredPlatformsOf, lxSourceLabel, lxQualityLabel, lxActionLabel }
  from './src/main/ets/util/SourceDeclaredInfo';
export type { LXSourcePlatformInfo } from './src/main/ets/util/SourceDeclaredInfo';
export { sourceDisplayName, qualityDisplayName } from './src/main/ets/util/SourceFallbackUtil';
export { lxSearch, lxLeaderboard, getLeaderboardEntries, lxGetPicFallback, lxGetLyricFallback,
  lxTxToplist, lxTxToplistInfo, lxTxSingerList, lxKgSingerList, lxWySingerList, lxKwSingerList, lxMgSingerList, lxTxToplistList, lxTxHotSearch, lxSearchSuggest,
  lxGetWyLyricAll, lxGetTTMLLyric, lxGetLyricFull } from './src/main/ets/source/LXMusicSDK';
export { buildSongShareText, showSystemShare } from './src/main/ets/util/ShareUtil';
export { LyricLiveViewController } from './src/main/ets/util/LyricLiveViewController';
export type { LiveViewLyricPayload } from './src/main/ets/util/LyricLiveViewController';
export { DownloadUtil } from './src/main/ets/util/DownloadUtil';
export { DownloadService, DownloadStatus, DownloadTask } from './src/main/ets/util/DownloadService';
export type { TxToplistInfo, TxSinger } from './src/main/ets/source/LXMusicSDK';
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
// 播放页的「小歌词」两行（当前行 + 下一行），渲染在播放条插槽里。
// ⚠️ 底栏页签「现在就听」要在**歌名上方**画同样的两行歌词，而 HAR 只能按导出面引用
//   （不能深链到 `src/main/ets/view/` 内部文件）⇒ 这里补一行导出，**组件本身一行未改**
//   （用户明确"歌词渲染不在范围"）。用法见 `recommendation/.../NowPlayingFeedPage` 的 `FeedLyric`。
export { MiniLyricLinesComponent } from './src/main/ets/view/MiniLyricLinesComponent';
// ★★ 2026-10-15：**网格流动背景**的算法层 —— 照搬无界 1.2.4 的
//   `design/logic/MeshGradient.ets` + `design/logic/MeshSource.ets`（两个模块**零外部依赖**）。
//   依据：`_recover/logic-src/播放页背景-MeshGradient与MeshSource定稿.md` §2/§3。
//   导出是为了让它们**进编译图**（本仓 hvigor 对 HAR 按引用编译：没被 import 的文件不参与编译，
//   构建照样绿 ⇒ 必须先挂上导出面才验证得到）。下一步的 `MeshCoverBg` 组件会消费它们。
export { MeshField, MeshCP, CP_W, CP_H, cp, defaultConf, generateConf } from './src/main/ets/util/MeshGradient';
export { SRC_EDGE, hueOfSeed, fillFallback, enhanceColors, boxBlurRgba } from './src/main/ets/util/MeshSource';
// ★★ 2026-10-15：**网格形变背景的组件层**（`NodeContainer` + 自定义 `RenderNode.draw`
//   + `drawPixelMapMesh` + `displaySync` 20fps + 径向暗角），照搬无界 `MeshCoverBg`。
export { MeshCoverBg } from './src/main/ets/view/MeshCoverBg';
