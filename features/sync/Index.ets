// 洛雪同步协议客户端
//
// core/SyncManager  —— 对外门面（开关、地址、认证码、状态、同步方式选择回传）
// core/SyncUiState  —— 给视图观察的 V2 状态（AppStorageV2 + @Trace）
// core/LocalLibrary —— 音乐库适配层（数据主人在 MusicStoreService，同步模块只做对账）
export { SyncManager, syncManager, SyncUiState, SYNC_UI_STATE_KEY } from './src/main/ets/core/SyncManager';
export type { SyncModeRequest } from './src/main/ets/core/SyncManager';
export { LocalLibrary, localLibrary } from './src/main/ets/core/LocalLibrary';
export type { SyncActionSink, LibrarySummary, LxPlaylistSummary } from './src/main/ets/core/LocalLibrary';

// 界面层（设置页内嵌面板 + 同步方式选择面板 + 路由页入口）
export { SyncSettingsPanel, SyncSettingsPageBuilder } from './src/main/ets/view/SyncSettingsView';
export { SyncModeSheet } from './src/main/ets/view/SyncModeSheet';
