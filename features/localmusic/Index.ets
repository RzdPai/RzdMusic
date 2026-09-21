// 本地音乐（导入设备音频到应用沙箱）
//
// 对外导出分三层：
//   core/LocalMusic   —— 库本体（导入 / 索引 / 封面 / 去重 / 删除 / 歌单收藏侧表 / 歌词匹配）
//   core/LyricMatch   —— 在线歌词匹配的打分与「宁缺勿错」的接受条件
//   view/*            —— 页面与面板（路由页 LocalMusicPage / 手动匹配面板 LyricMatchSheet）

export {
  LocalMusic,
  localMusic,
  LocalMusicImportState,
  localMusicImportState,
  LOCAL_MUSIC_IMPORT_STATE_KEY,
  LOCAL_SOURCE,
  LOCAL_ID_PREFIX,
  LOVE_LIST_ID,
  isLocalSong,
  isSupportedAudioFile,
  isUnsupportedAudioFile,
  isIgnorableFile,
  titleFromFileName,
  singerFromFileName
} from './src/main/ets/core/LocalMusic';
export type { LocalSongEntry, ImportResult } from './src/main/ets/core/LocalMusic';

export {
  MATCH_PLATFORMS,
  platformLabel,
  normalizeForMatch,
  singerTokens,
  parseIntervalMs,
  scoreCandidate,
  pickAutoMatch,
  searchCandidates,
  autoMatchLyric,
  fromSearchSong,
  toSearchSong,
  infoToJson,
  infoFromJson
} from './src/main/ets/core/LyricMatch';
export type { MatchSongInfo, LyricCandidate, LyricMatch, AutoMatchResult } from './src/main/ets/core/LyricMatch';

export { LyricMatchSheet, applyPickedMatch } from './src/main/ets/view/LyricMatchSheet';
export {
  LocalMusicPage,
  LocalMusicPageBuilder,
  removeLocalSongs,
  describeImport,
  formatBytes
} from './src/main/ets/view/LocalMusicView';
