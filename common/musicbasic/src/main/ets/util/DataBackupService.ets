import { hilog } from '@kit.PerformanceAnalysisKit';
import { MusicStoreService } from './MusicStoreService';

interface BackupSetting {
  key: string;
  value: Object;
}

interface BackupSnapshot {
  version: number;
  exportedAt: number;
  settings: BackupSetting[];
  playlists: string;
}

/** Transport-independent settings/playlist backup. Never exports accounts, cookies or tokens. */
export class DataBackupService {
  private static instance: DataBackupService = new DataBackupService();

  public static getInstance(): DataBackupService {
    return DataBackupService.instance;
  }

  public exportSnapshotText(): string {
    const s: MusicStoreService = MusicStoreService.getInstance();
    const settings: BackupSetting[] = [
      { key: 'themeColor', value: s.getThemeColor() },
      { key: 'colorMode', value: s.getColorMode() },
      { key: 'ambientLevel', value: s.getAmbientLevel() },
      { key: 'homeSource', value: s.getHomeSource() },
      { key: 'useAccountRec', value: s.getUseAccountRec() },
      { key: 'playQuality', value: s.getPlayQuality() },
      { key: 'playQualityWifi', value: s.getNetworkPlayQuality(true) },
      { key: 'playQualityCellular', value: s.getNetworkPlayQuality(false) },
      { key: 'playQualityWifiBase', value: s.getNetworkBaseQuality(true) },
      { key: 'playQualityWifiExtended', value: s.getNetworkExtendedQuality(true) },
      { key: 'playQualityWifiExtendedEnabled', value: s.getNetworkExtendedEnabled(true) },
      { key: 'playQualityCellularBase', value: s.getNetworkBaseQuality(false) },
      { key: 'playQualityCellularExtended', value: s.getNetworkExtendedQuality(false) },
      { key: 'playQualityCellularExtendedEnabled', value: s.getNetworkExtendedEnabled(false) },
      { key: 'playMode', value: s.getPlayMode() },
      { key: 'lyricBlur', value: s.getLyricBlurEnabled() },
      { key: 'lyricCenter', value: s.getLyricCenterEnabled() },
      { key: 'lyricFontSize', value: s.getLyricFontSize() },
      { key: 'lyricFps', value: s.getLyricFps() },
      { key: 'showMiniLyric', value: s.getShowMiniLyric() },
      { key: 'showSubLyric', value: s.getShowSubLyric() },
      { key: 'desktopLyric', value: s.getDesktopLyric() },
      { key: 'playbackFlowLight', value: s.getPlaybackFlowLight() },
      { key: 'keepScreenOn', value: s.getKeepScreenOn() },
      { key: 'audioMix', value: s.getAudioMix() },
      { key: 'coverCornerRadius', value: s.getCoverCornerRadius() },
      { key: 'playlistAddPosition', value: s.getPlaylistAddPosition() },
      { key: 'downloadQualityMode', value: s.getDownloadQualityMode() },
      { key: 'downloadManualQuality', value: s.getDownloadManualQuality() },
      { key: 'downloadSaveMode', value: s.getDownloadSaveMode() },
      { key: 'downloadNameFormat', value: s.getDownloadNameFormat() },
      { key: 'downloadLrc', value: s.getDownloadLrc() },
      { key: 'showHomePlaza', value: s.getShowHomePlaza() },
      { key: 'showHomeRanking', value: s.getShowHomeRanking() }
    ];
    const snapshot: BackupSnapshot = {
      version: 1, exportedAt: Date.now(), settings: settings, playlists: s.playlistsJson()
    };
    hilog.info(0x0000, 'RzdDataBackup', 'export version=1 settings=%{public}d', settings.length);
    return JSON.stringify(snapshot);
  }

  /** Validate the entire document before writing anything. Unknown settings are skipped. */
  public async restoreSnapshotText(text: string): Promise<string> {
    if (text.length === 0 || text.length > 16 * 1024 * 1024) {
      throw new Error('备份为空或超过 16MB 限制');
    }
    let snapshot: BackupSnapshot;
    try {
      snapshot = JSON.parse(text) as BackupSnapshot;
    } catch (_err) {
      throw new Error('备份不是有效 JSON');
    }
    if (snapshot === null || typeof snapshot !== 'object' || snapshot.version !== 1 ||
      !Number.isFinite(snapshot.exportedAt) || !Array.isArray(snapshot.settings) ||
      snapshot.settings.length > 100 || typeof snapshot.playlists !== 'string') {
      throw new Error('不支持的备份版本或结构');
    }
    let playlists: Object[];
    try {
      playlists = JSON.parse(snapshot.playlists) as Object[];
    } catch (_err) {
      throw new Error('歌单备份结构无效');
    }
    if (!Array.isArray(playlists) || playlists.length > 10000) {
      throw new Error('歌单备份结构无效');
    }
    this.validatePlaylists(playlists);
    const seen: Set<string> = new Set();
    for (const entry of snapshot.settings) {
      if (entry === null || typeof entry !== 'object' || typeof entry.key !== 'string' || seen.has(entry.key)) {
        throw new Error('设置备份包含无效或重复条目');
      }
      seen.add(entry.key);
      this.validateSetting(entry);
    }
    const store: MusicStoreService = MusicStoreService.getInstance();
    if (!store.replacePlaylistsJson(snapshot.playlists)) {
      throw new Error('歌单恢复失败，设置未写入');
    }
    // Old version-1 backups have no download policy: explicitly migrate to follow.
    if (!seen.has('downloadQualityMode')) {
      store.setDownloadQualityMode('follow');
    }
    if (!seen.has('downloadManualQuality')) {
      store.setDownloadManualQuality('320k');
    }
    let count: number = 0;
    // Fixed precedence, never JSON order: global legacy, old effective, new tiers, then switches.
    // setPlayQuality persists only the legacy global field; it must not mutate either network.
    const qualityKeys: string[] = ['playQuality', 'playQualityWifi', 'playQualityCellular',
      'playQualityWifiBase', 'playQualityWifiExtended', 'playQualityCellularBase', 'playQualityCellularExtended',
      'playQualityWifiExtendedEnabled', 'playQualityCellularExtendedEnabled'];
    for (const key of qualityKeys) {
      for (const entry of snapshot.settings) {
        if (entry.key === key && this.applySetting(store, entry)) {
          count++;
          hilog.info(0x0000, 'RzdDataBackup', 'restore quality key=%{public}s', key);
        }
      }
    }
    for (const entry of snapshot.settings) {
      if (!qualityKeys.includes(entry.key) && this.applySetting(store, entry)) {
        count++;
      }
    }
    try {
      await store.flushPendingWrites();
    } catch (_err) {
      hilog.error(0x0000, 'RzdDataBackup', 'restore persistence failed');
      throw new Error('备份已写入内存，但持久化失败，请勿退出应用并重试');
    }
    hilog.info(0x0000, 'RzdDataBackup', 'restore persisted version=1 settings=%{public}d playlists=%{public}d', count, playlists.length);
    return '恢复成功';
  }

  private validatePlaylists(playlists: Object[]): void {
    const ids: Set<string> = new Set();
    let songCount: number = 0;
    for (const value of playlists) {
      if (value === null || typeof value !== 'object' || Array.isArray(value)) {
        throw new Error('歌单备份包含无效条目');
      }
      const playlist: Record<string, Object> = value as Record<string, Object>;
      this.validateString(playlist, 'id', 512, true);
      this.validateString(playlist, 'name', 4096, true);
      this.validateString(playlist, 'cover', 8192, false);
      this.validateTimestamp(playlist, 'createTime');
      const id: string = playlist['id'] as string;
      if (ids.has(id)) {
        throw new Error('歌单备份包含重复 ID');
      }
      ids.add(id);
      const songs: Object[] = playlist['songs'] as Object[];
      if (!Array.isArray(songs) || songs.length > 50000) {
        throw new Error('歌单歌曲列表无效或过大');
      }
      songCount += songs.length;
      if (songCount > 100000) {
        throw new Error('备份歌曲数量超过限制');
      }
      for (const song of songs) {
        this.validateSong(song);
      }
    }
  }

  private validateSong(value: Object): void {
    if (value === null || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error('备份包含无效歌曲');
    }
    const song: Record<string, Object> = value as Record<string, Object>;
    this.validateString(song, 'songId', 1024, true);
    this.validateString(song, 'name', 4096, true);
    this.validateString(song, 'source', 32, true);
    // Local songs are legitimate playlist entries; older optional fields may be absent.
    const source: string = song['source'] as string;
    if (!['', 'kw', 'kg', 'tx', 'wy', 'mg', 'local'].includes(source)) {
      throw new Error('备份歌曲来源无效');
    }
    for (const key of ['singer', 'albumName', 'albumId', 'playScript']) {
      this.validateString(song, key, 4096, false);
    }
    for (const key of ['img', 'url']) {
      this.validateString(song, key, 8192, false);
    }
    this.validateString(song, 'interval', 128, false);
    this.validateString(song, 'lyric', 1024 * 1024, false);
    this.validateString(song, 'quality', 64, false);
    const quality: Object | undefined = song['quality'];
    // User scripts and LX synchronization may introduce additional quality IDs.
    if (quality !== undefined && !/^[a-zA-Z0-9_.+-]{0,64}$/.test(quality as string)) {
      throw new Error('备份歌曲音质标识无效');
    }
    this.validateTimestamp(song, 'time');
  }

  private validateString(record: Record<string, Object>, key: string, maxLength: number, required: boolean): void {
    const value: Object | undefined = record[key];
    if (value === undefined && !required) {
      return;
    }
    // Empty strings remain valid defaults in historical exported DTOs.
    if (typeof value !== 'string' || (value as string).length > maxLength) {
      throw new Error('备份字段类型或长度无效：' + key);
    }
  }

  private validateTimestamp(record: Record<string, Object>, key: string): void {
    const value: Object | undefined = record[key];
    if (value === undefined) {
      return;
    }
    if (typeof value !== 'number' || !Number.isFinite(Number(value)) || Number(value) < 0 ||
      Number(value) > 8640000000000000) {
      throw new Error('备份时间字段无效：' + key);
    }
  }

  private validateSetting(entry: BackupSetting): void {
    const booleanKeys: string[] = ['useAccountRec', 'lyricBlur', 'lyricCenter', 'showMiniLyric', 'showSubLyric',
      'desktopLyric', 'playbackFlowLight', 'keepScreenOn', 'audioMix', 'downloadLrc', 'showHomePlaza', 'showHomeRanking',
      'playQualityWifiExtendedEnabled', 'playQualityCellularExtendedEnabled'];
    const numberKeys: string[] = ['colorMode', 'ambientLevel', 'playMode', 'lyricFontSize', 'lyricFps', 'coverCornerRadius'];
    const stringKeys: string[] = ['themeColor', 'homeSource', 'playQuality', 'playQualityWifi', 'playQualityCellular', 'playlistAddPosition',
      'downloadQualityMode', 'downloadManualQuality', 'downloadSaveMode', 'downloadNameFormat', 'playQualityWifiBase', 'playQualityWifiExtended',
      'playQualityCellularBase', 'playQualityCellularExtended'];
    if (booleanKeys.includes(entry.key) && typeof entry.value !== 'boolean') {
      throw new Error('备份设置类型无效：' + entry.key);
    }
    if (numberKeys.includes(entry.key) && (typeof entry.value !== 'number' || !Number.isFinite(Number(entry.value)) ||
      Number(entry.value) < 0 || Number(entry.value) > 1000)) {
      throw new Error('备份设置数值无效：' + entry.key);
    }
    if (stringKeys.includes(entry.key) && (typeof entry.value !== 'string' || String(entry.value).length > 512)) {
      throw new Error('备份设置字符串无效：' + entry.key);
    }
    const baseKeys: string[] = ['playQualityWifiBase', 'playQualityCellularBase'];
    const extendedKeys: string[] = ['playQualityWifiExtended', 'playQualityCellularExtended'];
    const baseQualities: string[] = ['128k', '320k', 'flac', 'flac24bit'];
    const extendedQualities: string[] = ['hires', 'atmos', 'atmos_plus', 'master'];
    if (baseKeys.includes(entry.key) && !baseQualities.includes(String(entry.value))) {
      throw new Error('备份基础音质无效：' + entry.key);
    }
    if (extendedKeys.includes(entry.key) && !extendedQualities.includes(String(entry.value))) {
      throw new Error('备份拓展音质无效：' + entry.key);
    }
    if (entry.key === 'downloadQualityMode' && !['follow', 'manual'].includes(String(entry.value))) {
      throw new Error('备份下载音质模式无效');
    }
    if (entry.key === 'downloadManualQuality' &&
      !baseQualities.concat(extendedQualities).includes(String(entry.value))) {
      throw new Error('备份手动下载音质无效');
    }
    // Legacy global/effective fields retain their original string validation for old version-1 documents.
  }

  private applySetting(s: MusicStoreService, e: BackupSetting): boolean {
    switch (e.key) {
      case 'themeColor': s.setThemeColor(String(e.value)); break;
      case 'colorMode': s.setColorMode(Number(e.value)); break;
      case 'ambientLevel': s.setAmbientLevel(Number(e.value)); break;
      case 'homeSource': s.setHomeSource(String(e.value)); break;
      case 'useAccountRec': s.setUseAccountRec(e.value === true); break;
      case 'playQuality': s.setPlayQuality(String(e.value)); break;
      case 'playQualityWifi': s.setNetworkPlayQuality(true, String(e.value)); break;
      case 'playQualityCellular': s.setNetworkPlayQuality(false, String(e.value)); break;
      case 'playQualityWifiBase': s.setNetworkBaseQuality(true, String(e.value)); break;
      case 'playQualityWifiExtended': s.setNetworkExtendedQuality(true, String(e.value)); break;
      case 'playQualityCellularBase': s.setNetworkBaseQuality(false, String(e.value)); break;
      case 'playQualityCellularExtended': s.setNetworkExtendedQuality(false, String(e.value)); break;
      case 'playQualityWifiExtendedEnabled': s.setNetworkExtendedEnabled(true, e.value === true); break;
      case 'playQualityCellularExtendedEnabled': s.setNetworkExtendedEnabled(false, e.value === true); break;
      case 'playMode': s.setPlayMode(Number(e.value)); break;
      case 'lyricBlur': s.setLyricBlurEnabled(e.value === true); break;
      case 'lyricCenter': s.setLyricCenterEnabled(e.value === true); break;
      case 'lyricFontSize': s.setLyricFontSize(Number(e.value)); break;
      case 'lyricFps': s.setLyricFps(Number(e.value)); break;
      case 'showMiniLyric': s.setShowMiniLyric(e.value === true); break;
      case 'showSubLyric': s.setShowSubLyric(e.value === true); break;
      case 'desktopLyric': s.setDesktopLyric(e.value === true); break;
      case 'playbackFlowLight': s.setPlaybackFlowLight(e.value === true); break;
      case 'keepScreenOn': s.setKeepScreenOn(e.value === true); break;
      case 'audioMix': s.setAudioMix(e.value === true); break;
      case 'coverCornerRadius': s.setCoverCornerRadius(Number(e.value)); break;
      case 'playlistAddPosition': s.setPlaylistAddPosition(String(e.value)); break;
      case 'downloadQualityMode': s.setDownloadQualityMode(String(e.value)); break;
      case 'downloadManualQuality': s.setDownloadManualQuality(String(e.value)); break;
      case 'downloadSaveMode': s.setDownloadSaveMode(String(e.value)); break;
      case 'downloadNameFormat': s.setDownloadNameFormat(String(e.value)); break;
      case 'downloadLrc': s.setDownloadLrc(e.value === true); break;
      case 'showHomePlaza': s.setShowHomePlaza(e.value === true); break;
      case 'showHomeRanking': s.setShowHomeRanking(e.value === true); break;
      default: return false;
    }
    return true;
  }
}
