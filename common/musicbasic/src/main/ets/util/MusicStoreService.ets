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

import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { FavoriteEntry } from '../model/FavoriteEntry';
import { PlayedSongRecord } from '../model/PlayedSongRecord';
import { PlaylistDto } from '../model/PlaylistDto';
import { SongItem } from '../model/SongData';
import { getAppRuntime } from '../model/AppRuntimeStorage';

const STORE_NAME: string = 'music_store';
const KEY_HISTORY: string = 'history_list';
const KEY_FAVORITES: string = 'favorite_list';
const KEY_FAVORITE_ARTISTS: string = 'favorite_artists';
const KEY_FAVORITE_ALBUMS: string = 'favorite_albums';
const KEY_SEARCH_HISTORY: string = 'search_history';
const KEY_AMBIENT_LEVEL: string = 'ambient_level';
const KEY_THEME_COLOR: string = 'theme_color';
const KEY_HOME_SOURCE: string = 'home_source';
const KEY_SHOW_MINI_LYRIC: string = 'show_mini_lyric';
const KEY_SHOW_SUB_LYRIC: string = 'show_sub_lyric';
const KEY_PLAY_QUALITY: string = 'play_quality';
const KEY_AUDIO_MIX: string = 'audio_mix';
const KEY_DOWNLOAD_SAVE_MODE: string = 'download_save_mode';
const KEY_DOWNLOAD_NAME_FORMAT: string = 'download_name_format';
const KEY_LYRIC_FPS: string = 'lyric_fps';
const KEY_LYRIC_CENTER: string = 'lyric_center';
const KEY_LYRIC_BLUR: string = 'lyric_blur';
const KEY_CROSS_SCRIPT_FALLBACK: string = 'cross_script_fallback';
const KEY_QUALITY_TIER_HEALTH: string = 'quality_tier_health';
const KEY_SHOW_HOME_PLAZA: string = 'show_home_plaza';
const KEY_SHOW_HOME_RANKING: string = 'show_home_ranking';
const KEY_LYRIC_FONT_SIZE: string = 'lyric_font_size';
const KEY_PLAYLIST_ADD_POSITION: string = 'playlist_add_position';
const KEY_PLAYLISTS: string = 'playlists';
const KEY_SEARCH_SOURCE: string = 'search_source';
const KEY_SEARCH_CACHE: string = 'search_cache';
const KEY_PLAY_MODE: string = 'play_mode';
const KEY_LAST_SONG: string = 'last_song';
const KEY_CARD_FORM_IDS: string = 'music_card_form_ids';
const KEY_CARD_PLAYING: string = 'music_card_playing';
const KEY_CARD_LYRIC: string = 'music_card_lyric';
const KEY_CARD_PENDING_ACTION: string = 'music_card_pending_action';
const KEY_LAST_QUEUE: string = 'last_queue';
const KEY_COLOR_MODE: string = 'color_mode';
const KEY_KEEP_SCREEN_ON: string = 'keep_screen_on';
const KEY_DOWNLOAD_QUALITY_TAG: string = 'download_quality_tag';
const KEY_COVER_CORNER_RADIUS: string = 'cover_corner_radius';
const KEY_PLAYBACK_FULLSCREEN: string = 'playback_fullscreen';
const KEY_DOWNLOAD_LRC: string = 'download_lrc';
const KEY_DOWNLOAD_LRC_ENCODING: string = 'download_lrc_encoding';
const KEY_PLAY_EXTENDED_QUALITY: string = 'play_extended_quality';
const KEY_PLAY_EXTENDED_ENABLED: string = 'play_extended_enabled';
const KEY_DOWNLOAD_TASKS: string = 'download_tasks';
const KEY_USE_ACCOUNT_REC: string = 'use_account_rec';
const ACTIVE_SOURCE_FILE: string = 'lx_active_source.txt';

/** Persisted health record for one (script | platform | quality) tier. */
interface QualityTierHealth {
  fails: number;
  cooldownUntil: number;
}

/** Kept intentionally blank: tier health constants live in SourceFallbackUtil. */
const MAX_HISTORY: number = 200;
const MAX_SEARCH_HISTORY: number = 15;

/**
 * Persists play history and favorite songs as JSON via preferences.
 */
@ObservedV2
export class MusicStoreService {
  private static instance: MusicStoreService | undefined = undefined;
  private store: preferences.Preferences | undefined = undefined;
  /** Bumped on every history mutation; observable for UI refresh. */
  @Trace public historyVersion: number = 0;
  /** Bumped on every favorite mutation; observable for UI refresh. */
  @Trace public favoriteVersion: number = 0;
  @Trace public favoriteArtistVersion: number = 0;
  @Trace public favoriteAlbumVersion: number = 0;
  /** Bumped on every search history mutation; observable for UI refresh. */
  @Trace public searchHistoryVersion: number = 0;
  /** Bumped on every playlist mutation; observable for UI refresh. */
  @Trace public playlistVersion: number = 0;

  /** Process-wide singleton. */
  public static getInstance(): MusicStoreService {
    if (MusicStoreService.instance === undefined) {
      MusicStoreService.instance = new MusicStoreService();
    }
    return MusicStoreService.instance;
  }

  private getStore(): preferences.Preferences | undefined {
    if (this.store !== undefined) {
      return this.store;
    }
    const ctx = getAppRuntime().context;
    if (ctx === undefined) {
      return undefined;
    }
    this.store = preferences.getPreferencesSync(ctx, { name: STORE_NAME });
    return this.store;
  }

  private readList(key: string): PlayedSongRecord[] {
    const store = this.getStore();
    if (store === undefined) {
      return [];
    }
    const text: string = store.getSync(key, '[]') as string;
    try {
      const list: PlayedSongRecord[] = JSON.parse(text) as PlayedSongRecord[];
      return list !== undefined ? list : [];
    } catch (_err) {
      return [];
    }
  }

  private writeList(key: string, list: PlayedSongRecord[]): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(key, JSON.stringify(list));
    store.flush();
  }

  /** @returns Play history, most recent first. */
  public getHistory(): PlayedSongRecord[] {
    return this.readList(KEY_HISTORY);
  }

  /** Records a played song: dedupe by source+songId and move to front, capped at MAX_HISTORY. */
  public addHistory(record: PlayedSongRecord): void {
    const list: PlayedSongRecord[] = this.getHistory();
    const id: string = record.source + '_' + record.songId;
    const kept: PlayedSongRecord[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].source + '_' + list[i].songId !== id) {
        kept.push(list[i]);
      }
    }
    kept.unshift(record);
    if (kept.length > MAX_HISTORY) {
      kept.splice(MAX_HISTORY, kept.length - MAX_HISTORY);
    }
    this.writeList(KEY_HISTORY, kept);
    this.historyVersion++;
  }

  /** Clears all play history. */
  public clearHistory(): void {
    this.writeList(KEY_HISTORY, []);
    this.historyVersion++;
  }

  /** Removes the given history entries (ids are source_songId keys). */
  public removeHistoryByIds(ids: string[]): void {
    const list: PlayedSongRecord[] = this.getHistory();
    const removeSet: Set<string> = new Set(ids);
    const kept: PlayedSongRecord[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (!removeSet.has(list[i].source + '_' + list[i].songId)) {
        kept.push(list[i]);
      }
    }
    this.writeList(KEY_HISTORY, kept);
    this.historyVersion++;
  }

  /** @returns Favorite songs, most recently added first. */
  public getFavorites(): PlayedSongRecord[] {
    return this.readList(KEY_FAVORITES);
  }

  /**
   * In-place updates the quality field of an existing history entry (keeps the row in its
   * current position). No-op when the entry is not found.
   */
  public refreshHistoryQuality(source: string, songId: string, quality: string): void {
    const list: PlayedSongRecord[] = this.getHistory();
    let changed: boolean = false;
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].source === source && list[i].songId === songId) {
        if (list[i].quality !== quality) {
          list[i].quality = quality;
          changed = true;
        }
        break;
      }
    }
    if (changed) {
      this.writeList(KEY_HISTORY, list);
      this.historyVersion++;
    }
  }

  /**
   * In-place updates the quality field of an existing favorite entry (keeps the row in its
   * current position). No-op when the entry is not found.
   */
  public refreshFavoriteQuality(source: string, songId: string, quality: string): void {
    const list: PlayedSongRecord[] = this.getFavorites();
    let changed: boolean = false;
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].source === source && list[i].songId === songId) {
        if (list[i].quality !== quality) {
          list[i].quality = quality;
          changed = true;
        }
        break;
      }
    }
    if (changed) {
      this.writeList(KEY_FAVORITES, list);
      this.favoriteVersion++;
    }
  }

  /** Adds a song to favorites (dedupe by source+songId). */
  public addFavorite(record: PlayedSongRecord): void {
    const list: PlayedSongRecord[] = this.getFavorites();
    const id: string = record.source + '_' + record.songId;
    const kept: PlayedSongRecord[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].source + '_' + list[i].songId !== id) {
        kept.push(list[i]);
      }
    }
    kept.unshift(record);
    this.writeList(KEY_FAVORITES, kept);
    this.favoriteVersion++;
  }

  /** Removes a song from favorites by source and songId. */
  public removeFavorite(source: string, songId: string): void {
    const id: string = source + '_' + songId;
    const list: PlayedSongRecord[] = this.getFavorites();
    const kept: PlayedSongRecord[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].source + '_' + list[i].songId !== id) {
        kept.push(list[i]);
      }
    }
    this.writeList(KEY_FAVORITES, kept);
    this.favoriteVersion++;
  }

  /** @returns The persisted ambient level (0=follow system, 1=weak, 2=balanced, 3=strong). */
  public getAmbientLevel(): number {
    const store = this.getStore();
    if (store === undefined) {
      return 0;
    }
    const v = store.getSync(KEY_AMBIENT_LEVEL, 0) as number;
    if (v >= 0 && v <= 3) {
      return v;
    }
    return 0;
  }

  /** Persists the ambient level (0-3). */
  public setAmbientLevel(level: number): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_AMBIENT_LEVEL, level);
    store.flush();
  }

  /** @returns The persisted lyrics page render frame rate; default 60 FPS. */
  public getLyricFps(): number {
    const store = this.getStore();
    if (store === undefined) {
      return 60;
    }
    const v = store.getSync(KEY_LYRIC_FPS, 60) as number;
    return (v === 60 || v === 90 || v === 120 || v === 144) ? v : 60;
  }

  /** Persists the lyrics page render frame rate (60/90/120/144/165). */
  public setLyricFps(fps: number): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_LYRIC_FPS, fps);
    store.flush();
  }

  /** @returns Whether lyric lines render center-aligned; duet lines always keep left/right. */
  public getLyricCenterEnabled(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_LYRIC_CENTER, false) as boolean;
  }

  /** Persists whether lyric lines render center-aligned. */
  public setLyricCenterEnabled(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_LYRIC_CENTER, enabled);
    store.flush();
  }

  /**
   * @returns Whether a failed playback may automatically switch to another user
   * source script to find the song. Enabled by default to keep the historical
   * cross-script recovery behaviour.
   */
  public getCrossScriptFallback(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return true;
    }
    return store.getSync(KEY_CROSS_SCRIPT_FALLBACK, true) as boolean;
  }

  /** Persists whether a failed playback may automatically switch user source script. */
  public setCrossScriptFallback(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_CROSS_SCRIPT_FALLBACK, enabled);
    store.flush();
  }

  /**
   * Reads the quality-tier health map. Tiers are keyed by
   * "scriptId|source|quality" so a broken tier only affects the script/platform
   * combination that actually failed (e.g. tx/24bit can be broken while wy/24bit works).
   */
  private getQualityTierMap(): Record<string, QualityTierHealth> {
    const store = this.getStore();
    if (store === undefined) {
      return {};
    }
    const raw: string = store.getSync(KEY_QUALITY_TIER_HEALTH, '') as string;
    if (raw.length === 0) {
      return {};
    }
    try {
      return JSON.parse(raw) as Record<string, QualityTierHealth>;
    } catch (_err) {
      return {};
    }
  }

  private saveQualityTierMap(map: Record<string, QualityTierHealth>): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_QUALITY_TIER_HEALTH, JSON.stringify(map));
    store.flush();
  }

  /** @returns Whether the home page shows the playlist plaza section; off by default. */
  public getShowHomePlaza(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_SHOW_HOME_PLAZA, true) as boolean;
  }

  /** Persists whether the home page shows the playlist plaza section. */
  public setShowHomePlaza(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_SHOW_HOME_PLAZA, enabled);
    store.flush();
  }

  /** @returns Whether the home page shows the ranking boards section; off by default. */
  public getShowHomeRanking(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_SHOW_HOME_RANKING, true) as boolean;
  }

  /** Persists whether the home page shows the ranking boards section. */
  public setShowHomeRanking(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_SHOW_HOME_RANKING, enabled);
    store.flush();
  }

  /** @returns True when the given health key is currently cooling down (known broken). */
  public isCooling(key: string): boolean {
    const entry: QualityTierHealth | undefined = this.getQualityTierMap()[key];
    if (entry === undefined) {
      return false;
    }
    return entry.cooldownUntil > Date.now();
  }

  /**
   * Records a failure for a health key.
   * @param key Health key (quality tier or platform-wide).
   * @param threshold Consecutive failures that trigger cooldown.
   * @param cooldownMs Cooldown duration once the threshold is reached.
   */
  public recordFailure(key: string, threshold: number, cooldownMs: number): void {
    const map: Record<string, QualityTierHealth> = this.getQualityTierMap();
    let entry: QualityTierHealth | undefined = map[key];
    if (entry === undefined) {
      entry = { fails: 0, cooldownUntil: 0 };
    }
    entry.fails += 1;
    if (entry.fails >= threshold) {
      entry.cooldownUntil = Date.now() + cooldownMs;
    }
    map[key] = entry;
    this.saveQualityTierMap(map);
  }

  /** Records a success: clears the key so the tier/platform can be used again. */
  public recordSuccess(key: string): void {
    const map: Record<string, QualityTierHealth> = this.getQualityTierMap();
    const entry: QualityTierHealth | undefined = map[key];
    if (entry === undefined || (entry.fails === 0 && entry.cooldownUntil === 0)) {
      return;
    }
    map[key] = { fails: 0, cooldownUntil: 0 };
    this.saveQualityTierMap(map);
  }

  /** Clears every learned tier. */
  public resetQualityTierHealth(): void {
    this.saveQualityTierMap({});
  }

  /** @returns Whether the lyrics page applies blur to non-active lines; default false. */
  public getLyricBlurEnabled(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_LYRIC_BLUR, false) as boolean;
  }

  /** Persists the lyrics page blur-effect toggle. */
  public setLyricBlurEnabled(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_LYRIC_BLUR, enabled);
    store.flush();
  }

  /** @returns The persisted lyrics font size (active line); default 28, clamped 18..44. */
  public getLyricFontSize(): number {
    const store = this.getStore();
    if (store === undefined) {
      return 28;
    }
    const size = store.getSync(KEY_LYRIC_FONT_SIZE, 28) as number;
    if (typeof size !== 'number' || isNaN(size) || size < 18 || size > 44) {
      return 28;
    }
    return size;
  }

  /** Persists the lyrics font size (active line), clamped 18..44. */
  public setLyricFontSize(size: number): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    const clamped: number = Math.max(18, Math.min(44, size));
    store.putSync(KEY_LYRIC_FONT_SIZE, clamped);
    store.flush();
  }

  /** @returns The persisted theme color; default red #E60012. */
  public getThemeColor(): string {
    const store = this.getStore();
    if (store === undefined) {
      return '#E60012';
    }
    const c = store.getSync(KEY_THEME_COLOR, '#E60012') as string;
    return /^#[0-9a-fA-F]{6}$/.test(c) ? c : '#E60012';
  }

  /** Persists the theme color (hex string). */
  public setThemeColor(color: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_THEME_COLOR, color);
    store.flush();
  }

  /** @returns The persisted home recommendation source id; default 'qq'. */
  public getHomeSource(): string {
    const store = this.getStore();
    if (store === undefined) {
      return 'qq';
    }
    const s = store.getSync(KEY_HOME_SOURCE, 'qq') as string;
    return s.length > 0 ? s : 'qq';
  }

  /** Persists the home recommendation source id ('qq'|'kg'|'wy'|'mg'). */
  public setHomeSource(source: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_HOME_SOURCE, source);
    store.flush();
  }

  /** @returns Whether the playback page shows mini lyric lines below the cover. */
  public getShowMiniLyric(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }

    return store.getSync(KEY_SHOW_MINI_LYRIC, false) as boolean;
  }

  /** Whether the lyrics/playback page keeps the screen on. */
  public getKeepScreenOn(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_KEEP_SCREEN_ON, false) as boolean;
  }

  /** Persists the keep-screen-on switch. */
  public setKeepScreenOn(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_KEEP_SCREEN_ON, enabled);
    store.flush();
  }

  /** Whether downloaded file names include the quality tag. */
  public getDownloadQualityTag(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_DOWNLOAD_QUALITY_TAG, false) as boolean;
  }

  /** Persists the download quality-tag switch. */
  public setDownloadQualityTag(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_DOWNLOAD_QUALITY_TAG, enabled);
    store.flush();
  }

  /** @returns Persisted download task queue JSON (survives restarts). */
  public getDownloadTasks(): string {
    const store = this.getStore();
    if (store === undefined) {
      return '[]';
    }
    return store.getSync(KEY_DOWNLOAD_TASKS, '[]') as string;
  }

  /** Persists the download task queue JSON. */
  public setDownloadTasks(json: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_DOWNLOAD_TASKS, json);
    store.flush();
  }

  /** @returns Whether the home recommendation uses the logged-in account's daily picks; default false. */
  public getUseAccountRec(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_USE_ACCOUNT_REC, false) as boolean;
  }

  /** Persists the use-login-account-recommendation switch. */
  public setUseAccountRec(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_USE_ACCOUNT_REC, enabled);
    store.flush();
  }

  /** Persists the playback-page mini lyric switch. */
  public setShowMiniLyric(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_SHOW_MINI_LYRIC, enabled);
    store.flush();
  }

  /** @returns Playback page cover corner radius in vp; default 8. */
  public getCoverCornerRadius(): number {
    const store = this.getStore();
    if (store === undefined) {
      return 8;
    }
    const v: number = store.getSync(KEY_COVER_CORNER_RADIUS, 8) as number;
    return v >= 0 && v <= 48 ? v : 8;
  }

  /** Persists the playback page cover corner radius (vp). */
  public setCoverCornerRadius(radius: number): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_COVER_CORNER_RADIUS, radius);
    store.flush();
  }

  /** @returns Whether the playback page extends into the status bar (full screen); default false. */
  public getPlaybackFullscreen(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_PLAYBACK_FULLSCREEN, false) as boolean;
  }

  /** Persists the playback page full-screen (status-bar immersive) switch. */
  public setPlaybackFullscreen(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_PLAYBACK_FULLSCREEN, enabled);
    store.flush();
  }

  /** @returns Whether downloads write a standalone .lrc next to the audio; default true. */
  public getDownloadLrc(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return true;
    }
    return store.getSync(KEY_DOWNLOAD_LRC, true) as boolean;
  }

  /** Persists the standalone .lrc download switch. */
  public setDownloadLrc(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_DOWNLOAD_LRC, enabled);
    store.flush();
  }

  /** @returns The .lrc text encoding for downloads: 'utf8' or 'gbk'; default 'utf8'. */
  public getDownloadLrcEncoding(): string {
    const store = this.getStore();
    if (store === undefined) {
      return 'utf8';
    }
    const v: string = store.getSync(KEY_DOWNLOAD_LRC_ENCODING, 'utf8') as string;
    return v === 'gbk' ? 'gbk' : 'utf8';
  }

  /** Persists the .lrc text encoding for downloads. */
  public setDownloadLrcEncoding(encoding: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_DOWNLOAD_LRC_ENCODING, encoding === 'gbk' ? 'gbk' : 'utf8');
    store.flush();
  }

  /** @returns Whether the lyrics page shows translation/romanization sub-lines. */
  public getShowSubLyric(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return true;
    }
    return store.getSync(KEY_SHOW_SUB_LYRIC, true) as boolean;
  }

  /** Persists the lyrics-page translation/romanization switch. */
  public setShowSubLyric(show: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_SHOW_SUB_LYRIC, show);
    store.flush();
  }

  /** @returns The persisted playback quality; default '128k'. */
  public getPlayQuality(): string {
    const store = this.getStore();
    if (store === undefined) {
      return '128k';
    }
    const q = store.getSync(KEY_PLAY_QUALITY, '128k') as string;
    return q.length > 0 ? q : '128k';
  }

  /** Persists the playback quality ('128k'|'320k'|'flac'|'flac24bit'). */
  public setPlayQuality(quality: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_PLAY_QUALITY, quality);
    store.flush();
  }

  /** 拓展音质档位（hires/atmos/atmos_plus/master），空 = 未选择。 */
  public getPlayExtendedQuality(): string {
    const store = this.getStore();
    if (store === undefined) {
      return '';
    }
    return store.getSync(KEY_PLAY_EXTENDED_QUALITY, '') as string;
  }

  public setPlayExtendedQuality(quality: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_PLAY_EXTENDED_QUALITY, quality);
    store.flush();
  }

  /** 拓展音质开关：开启时优先尝试所选拓展音质。 */
  public getPlayExtendedEnabled(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_PLAY_EXTENDED_ENABLED, false) as boolean;
  }

  public setPlayExtendedEnabled(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_PLAY_EXTENDED_ENABLED, enabled);
    store.flush();
  }

  /** @returns The persisted play mode (0=SINGLE_CYCLE, 1=ORDER, 2=RANDOM); default 1. */
  public getPlayMode(): number {
    const store = this.getStore();
    if (store === undefined) {
      return 1;
    }
    return store.getSync(KEY_PLAY_MODE, 1) as number;
  }

  /** Persists the play mode so it survives app restarts. */
  public setPlayMode(mode: number): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_PLAY_MODE, mode);
    store.flush();
  }

  /** @returns The serialized last played song record, or '' when none saved. */
  /**
   * Lets another process (the desktop-card form ability) open the same preferences
   * file, so cards can read the playback snapshot and register their form ids.
   */
  public attachContext(ctx: Context): void {
    try {
      this.store = preferences.getPreferencesSync(ctx, { name: STORE_NAME });
    } catch (_err) {
      this.store = undefined;
    }
  }

  /**
   * Drops the in-memory preferences cache and re-reads the file, so values written by
   * the other process (form ability / UI ability) become visible.
   */
  public refreshStoreCache(ctx: Context): void {
    try {
      preferences.removePreferencesFromCacheSync(ctx, { name: STORE_NAME });
    } catch (_err) {
    }
    this.attachContext(ctx);
  }

  /** Registers a desktop-card form id so the app can push updates to it. */
  public addCardFormId(formId: string): void {
    const list: string[] = this.getCardFormIds();
    if (list.indexOf(formId) >= 0) {
      return;
    }
    list.push(formId);
    this.putStringList(KEY_CARD_FORM_IDS, list);
  }

  /** Removes a desktop-card form id. */
  public removeCardFormId(formId: string): void {
    const list: string[] = this.getCardFormIds();
    const kept: string[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i] !== formId) {
        kept.push(list[i]);
      }
    }
    this.putStringList(KEY_CARD_FORM_IDS, kept);
  }

  /** @returns All live desktop-card form ids. */
  public getCardFormIds(): string[] {
    const store = this.getStore();
    if (store === undefined) {
      return [];
    }
    const text: string = store.getSync(KEY_CARD_FORM_IDS, '[]') as string;
    try {
      return JSON.parse(text) as string[];
    } catch (_err) {
      return [];
    }
  }

  private putStringList(key: string, list: string[]): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(key, JSON.stringify(list));
    store.flush();
  }

  /** @returns The last known playback state for the desktop card. */
  public getCardPlaying(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_CARD_PLAYING, false) as boolean;
  }

  /** Persists the playback state shown on the desktop card. */
  public setCardPlaying(playing: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_CARD_PLAYING, playing);
    store.flush();
  }

  /** @returns The lyric line currently shown on the desktop card. */
  public getCardLyric(): string {
    const store = this.getStore();
    if (store === undefined) {
      return '';
    }
    return store.getSync(KEY_CARD_LYRIC, '') as string;
  }

  /** Persists the lyric line shown on the desktop card. */
  public setCardLyric(lyric: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_CARD_LYRIC, lyric);
  }

  /** Queues a desktop-card action (playPause/next/previous) for the app to run on resume. */
  public setPendingCardAction(action: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_CARD_PENDING_ACTION, action);
    store.flush();
  }

  /** Reads and clears the queued desktop-card action. */
  public consumePendingCardAction(): string {
    const store = this.getStore();
    if (store === undefined) {
      return '';
    }
    const action: string = store.getSync(KEY_CARD_PENDING_ACTION, '') as string;
    if (action.length > 0) {
      store.putSync(KEY_CARD_PENDING_ACTION, '');
      store.flush();
    }
    return action;
  }

  /** @returns The last played record (used by the desktop card snapshot). */
  public getLastRecord(): PlayedSongRecord | undefined {
    const json: string = this.getLastSong();
    if (json.length === 0) {
      return undefined;
    }
    try {
      return JSON.parse(json) as PlayedSongRecord;
    } catch (_err) {
      return undefined;
    }
  }

  public getLastSong(): string {
    const store = this.getStore();
    if (store === undefined) {
      return '';
    }
    return store.getSync(KEY_LAST_SONG, '') as string;
  }

  /** Persists the last played song record as JSON for restore-on-startup. */
  public setLastSong(json: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_LAST_SONG, json);
    store.flush();
  }

  /** @returns The serialized play queue snapshot, or '' when none saved. */
  public getLastQueue(): string {
    const store = this.getStore();
    if (store === undefined) {
      return '';
    }
    return store.getSync(KEY_LAST_QUEUE, '') as string;
  }

  /** Persists the full play queue snapshot (online items + local ids + index) for restore-on-startup. */
  public setLastQueue(json: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_LAST_QUEUE, json);
    store.flush();
  }

  /** @returns Color mode: 0=light, 1=dark, 2=follow system; default 2. */
  public getColorMode(): number {
    const store = this.getStore();
    if (store === undefined) {
      return 2;
    }
    return store.getSync(KEY_COLOR_MODE, 2) as number;
  }

  /** Persists the color mode (0=light, 1=dark, 2=follow system). */
  public setColorMode(mode: number): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_COLOR_MODE, mode);
    store.flush();
  }

  /** @returns Whether playback mixes with other apps (shared audio focus). */
  public getAudioMix(): boolean {
    const store = this.getStore();
    if (store === undefined) {
      return false;
    }
    return store.getSync(KEY_AUDIO_MIX, false) as boolean;
  }

  /** Persists the "play alongside other apps" switch. */
  public setAudioMix(enabled: boolean): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_AUDIO_MIX, enabled);
    store.flush();
  }

  /** @returns Download save mode: 'ask' (manual folder picker) or 'download' (app Download dir). */
  public getDownloadSaveMode(): string {
    const store = this.getStore();
    if (store === undefined) {
      return 'ask';
    }
    const mode = store.getSync(KEY_DOWNLOAD_SAVE_MODE, 'ask') as string;
    return mode.length > 0 ? mode : 'ask';
  }

  /** Persists the download save mode ('ask'|'download'). */
  public setDownloadSaveMode(mode: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_DOWNLOAD_SAVE_MODE, mode);
    store.flush();
  }

  /** @returns Download file name format: 'title'|'artist_title'|'title_artist'. */
  public getDownloadNameFormat(): string {
    const store = this.getStore();
    if (store === undefined) {
      return 'title';
    }
    const format = store.getSync(KEY_DOWNLOAD_NAME_FORMAT, 'title') as string;
    return format.length > 0 ? format : 'title';
  }

  /** Persists the download file name format. */
  public setDownloadNameFormat(format: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_DOWNLOAD_NAME_FORMAT, format);
    store.flush();
  }

  /** @returns Where new songs are inserted into a playlist: 'top' or 'bottom'. */
  public getPlaylistAddPosition(): string {
    const store = this.getStore();
    if (store === undefined) {
      return 'bottom';
    }
    const position = store.getSync(KEY_PLAYLIST_ADD_POSITION, 'bottom') as string;
    return position.length > 0 ? position : 'bottom';
  }

  /** Persists the add-to-playlist position ('top'|'bottom'). */
  public setPlaylistAddPosition(position: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_PLAYLIST_ADD_POSITION, position);
    store.flush();
  }

  /** @returns True when the song is in favorites. */
  /** @returns Saved favorite artists (ordered, newest first). */
  public getFavoriteArtists(): FavoriteEntry[] {
    const store = this.getStore();
    if (store === undefined) {
      return [];
    }
    const text: string = store.getSync(KEY_FAVORITE_ARTISTS, '[]') as string;
    try {
      return JSON.parse(text) as FavoriteEntry[];
    } catch (_err) {
      return [];
    }
  }

  /** Adds or refreshes a favorite artist entry. */
  public addFavoriteArtist(entry: FavoriteEntry): void {
    const list: FavoriteEntry[] = this.getFavoriteArtists();
    const kept: FavoriteEntry[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== entry.id || list[i].source !== entry.source) {
        kept.push(list[i]);
      }
    }
    kept.unshift(entry);
    this.saveFavoriteEntries(KEY_FAVORITE_ARTISTS, kept);
    this.favoriteArtistVersion++;
  }

  /** Removes a favorite artist entry. */
  public removeFavoriteArtist(source: string, id: string): void {
    const list: FavoriteEntry[] = this.getFavoriteArtists();
    const kept: FavoriteEntry[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== id || list[i].source !== source) {
        kept.push(list[i]);
      }
    }
    this.saveFavoriteEntries(KEY_FAVORITE_ARTISTS, kept);
    this.favoriteArtistVersion++;
  }

  /** @returns Whether the artist is in favorites. */
  public isFavoriteArtist(source: string, id: string): boolean {
    const list: FavoriteEntry[] = this.getFavoriteArtists();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === id && list[i].source === source) {
        return true;
      }
    }
    return false;
  }

  /** @returns Saved favorite albums (ordered, newest first). */
  public getFavoriteAlbums(): FavoriteEntry[] {
    const store = this.getStore();
    if (store === undefined) {
      return [];
    }
    const text: string = store.getSync(KEY_FAVORITE_ALBUMS, '[]') as string;
    try {
      return JSON.parse(text) as FavoriteEntry[];
    } catch (_err) {
      return [];
    }
  }

  /** Adds or refreshes a favorite album entry. */
  public addFavoriteAlbum(entry: FavoriteEntry): void {
    const list: FavoriteEntry[] = this.getFavoriteAlbums();
    const kept: FavoriteEntry[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== entry.id || list[i].source !== entry.source) {
        kept.push(list[i]);
      }
    }
    kept.unshift(entry);
    this.saveFavoriteEntries(KEY_FAVORITE_ALBUMS, kept);
    this.favoriteAlbumVersion++;
  }

  /** Removes a favorite album entry. */
  public removeFavoriteAlbum(source: string, id: string): void {
    const list: FavoriteEntry[] = this.getFavoriteAlbums();
    const kept: FavoriteEntry[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== id || list[i].source !== source) {
        kept.push(list[i]);
      }
    }
    this.saveFavoriteEntries(KEY_FAVORITE_ALBUMS, kept);
    this.favoriteAlbumVersion++;
  }

  /** @returns Whether the album is in favorites. */
  public isFavoriteAlbum(source: string, id: string): boolean {
    const list: FavoriteEntry[] = this.getFavoriteAlbums();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === id && list[i].source === source) {
        return true;
      }
    }
    return false;
  }

  private saveFavoriteEntries(key: string, list: FavoriteEntry[]): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(key, JSON.stringify(list));
    store.flush();
  }

  public isFavorite(source: string, songId: string): boolean {
    const id: string = source + '_' + songId;
    const list: PlayedSongRecord[] = this.getFavorites();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].source + '_' + list[i].songId === id) {
        return true;
      }
    }
    return false;
  }

  /** @returns Search keywords, most recent first. */
  public getSearchHistory(): string[] {
    const store = this.getStore();
    if (store === undefined) {
      return [];
    }
    const text: string = store.getSync(KEY_SEARCH_HISTORY, '[]') as string;
    try {
      const list: string[] = JSON.parse(text) as string[];
      return list !== undefined ? list : [];
    } catch (_err) {
      return [];
    }
  }

  /** Records a search keyword: dedupe and move to front, capped at MAX_SEARCH_HISTORY. */
  public addSearchHistory(keyword: string): void {
    const text: string = keyword.trim();
    if (text.length === 0) {
      return;
    }
    const list: string[] = this.getSearchHistory();
    const kept: string[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i] !== text) {
        kept.push(list[i]);
      }
    }
    kept.unshift(text);
    if (kept.length > MAX_SEARCH_HISTORY) {
      kept.splice(MAX_SEARCH_HISTORY, kept.length - MAX_SEARCH_HISTORY);
    }
    const store = this.getStore();
    if (store !== undefined) {
      store.putSync(KEY_SEARCH_HISTORY, JSON.stringify(kept));
      store.flush();
    }
    this.searchHistoryVersion++;
  }

  /** Clears all search history. */
  public clearSearchHistory(): void {
    const store = this.getStore();
    if (store !== undefined) {
      store.putSync(KEY_SEARCH_HISTORY, '[]');
      store.flush();
    }
    this.searchHistoryVersion++;
  }

  /** @returns The persisted search source selection; 'all' when every source is enabled. */
  public getSearchSource(): string {
    const store = this.getStore();
    if (store === undefined) {
      return 'all';
    }
    const id: string = store.getSync(KEY_SEARCH_SOURCE, 'all') as string;
    return id.length > 0 ? id : 'all';
  }

  /** Persists the search source selection ('all' or a source id like 'kw'). */
  public setSearchSource(sourceId: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_SEARCH_SOURCE, sourceId);
    store.flush();
  }

  /** @returns The raw cached search result JSON for a key; '' when absent. */
  public getSearchResultCache(key: string): string {
    const store = this.getStore();
    if (store === undefined) {
      return '';
    }
    const text: string = store.getSync(KEY_SEARCH_CACHE, '{}') as string;
    try {
      const map: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      if (map !== undefined && map[key] !== undefined) {
        return map[key] as string;
      }
    } catch (_err) {
      // corrupt cache: ignore
    }
    return '';
  }

  /** Caches raw search result JSON by key without a size limit. */
  public setSearchResultCache(key: string, json: string): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    const text: string = store.getSync(KEY_SEARCH_CACHE, '{}') as string;
    let map: Record<string, Object> = {};
    try {
      const parsed: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      if (parsed !== undefined) {
        map = parsed;
      }
    } catch (_err) {
      // corrupt cache: reset
    }
    map[key] = json;
    store.putSync(KEY_SEARCH_CACHE, JSON.stringify(map));
    store.flush();
  }

  /** @returns The persisted active LX source id; empty when none. */
  public getActiveSource(): string {
    const ctx = getAppRuntime().context;
    if (ctx === undefined) {
      return '';
    }
    const path: string = ctx.filesDir + '/' + ACTIVE_SOURCE_FILE;
    try {
      if (!fs.accessSync(path)) {
        return '';
      }
      const stat: fs.Stat = fs.statSync(path);
      if (stat.size <= 0) {
        return '';
      }
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      fs.readSync(file.fd, buf, { offset: 0, length: stat.size });
      fs.closeSync(file);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(buf)).trim();
    } catch (_err) {
      return '';
    }
  }

  /** Persists the active LX source id synchronously (empty clears it). */
  public setActiveSource(sourceId: string): void {
    const ctx = getAppRuntime().context;
    if (ctx === undefined) {
      return;
    }
    const path: string = ctx.filesDir + '/' + ACTIVE_SOURCE_FILE;
    try {
      const encoder: util.TextEncoder = new util.TextEncoder();
      const data: Uint8Array = encoder.encodeInto(sourceId);
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, data.buffer as ArrayBuffer);
      fs.closeSync(file);
    } catch (_err) {
      // ignore
    }
  }

  /** Maps a JSON object back into a PlayedSongRecord. */
  private static recordFromJson(obj: Record<string, Object>): PlayedSongRecord {
    const record = new PlayedSongRecord();
    record.songId = obj.songId as string ?? '';
    record.name = obj.name as string ?? '';
    record.singer = obj.singer as string ?? '';
    record.albumName = obj.albumName as string ?? '';
    record.albumId = obj.albumId as string ?? '';
    record.source = obj.source as string ?? '';
    record.interval = obj.interval as string ?? '';
    record.img = obj.img as string ?? '';
    record.url = obj.url as string ?? '';
    record.lyric = obj.lyric as string ?? '';
    record.time = obj.time as number ?? 0;
    return record;
  }

  /** @returns All user playlists (newest first). */
  public getPlaylists(): PlaylistDto[] {
    const store = this.getStore();
    if (store === undefined) {
      return [];
    }
    const text: string = store.getSync(KEY_PLAYLISTS, '[]') as string;
    try {
      const arr: Object[] = JSON.parse(text) as Object[];
      const list: PlaylistDto[] = [];
      for (let i: number = 0; i < arr.length; i++) {
        const o = arr[i] as Record<string, Object>;
        const p = new PlaylistDto();
        p.id = o.id as string ?? '';
        p.name = o.name as string ?? '';
        p.createTime = o.createTime as number ?? 0;
        const songs: Object[] = o.songs as Object[] ?? [];
        p.songs = [];
        for (let j: number = 0; j < songs.length; j++) {
          p.songs.push(MusicStoreService.recordFromJson(songs[j] as Record<string, Object>));
        }
        list.push(p);
      }
      return list;
    } catch (_err) {
      return [];
    }
  }

  /** Persists the playlist list. */
  private persistPlaylists(list: PlaylistDto[]): void {
    const store = this.getStore();
    if (store === undefined) {
      return;
    }
    store.putSync(KEY_PLAYLISTS, JSON.stringify(list));
    store.flush();
  }

  /** Reorders the saved playlists to the given id sequence and persists. */
  public reorderPlaylists(orderedIds: string[]): void {
    const current: PlaylistDto[] = this.getPlaylists();
    const byId: Map<string, PlaylistDto> = new Map<string, PlaylistDto>();
    for (let i = 0; i < current.length; i++) {
      byId.set(current[i].id, current[i]);
    }
    const reordered: PlaylistDto[] = [];
    for (let i = 0; i < orderedIds.length; i++) {
      const p = byId.get(orderedIds[i]);
      if (p !== undefined) {
        reordered.push(p);
        byId.delete(orderedIds[i]);
      }
    }
    const remaining: PlaylistDto[] = [];
    byId.forEach((p: PlaylistDto): void => {
      remaining.push(p);
    });
    for (let i = 0; i < remaining.length; i++) {
      reordered.push(remaining[i]);
    }
    this.persistPlaylists(reordered);
    this.playlistVersion++;
  }

  /** @returns The playlist with the given id, or undefined. */
  public getPlaylistById(id: string): PlaylistDto | undefined {
    const list: PlaylistDto[] = this.getPlaylists();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i];
      }
    }
    return undefined;
  }

  /** Creates a playlist with the given name. */
  public createPlaylist(name: string): PlaylistDto {
    const p = new PlaylistDto();
    p.id = String(Date.now());
    p.name = name;
    p.createTime = Date.now();
    p.songs = [];
    const list: PlaylistDto[] = this.getPlaylists();
    list.unshift(p);
    this.persistPlaylists(list);
    this.playlistVersion++;
    return p;
  }

  /** Renames a playlist by id. */
  public renamePlaylist(id: string, name: string): void {
    const list: PlaylistDto[] = this.getPlaylists();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === id) {
        list[i].name = name;
        this.persistPlaylists(list);
        this.playlistVersion++;
        return;
      }
    }
  }

  /** Deletes a playlist by id. */
  public deletePlaylist(id: string): void {
    const list: PlaylistDto[] = this.getPlaylists();
    const kept: PlaylistDto[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== id) {
        kept.push(list[i]);
      }
    }
    this.persistPlaylists(kept);
    this.playlistVersion++;
  }

  /** Adds a song to a playlist (dedupe by source+songId). @returns True when added. */
  public addSongToPlaylist(playlistId: string, record: PlayedSongRecord): boolean {
    const list: PlaylistDto[] = this.getPlaylists();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === playlistId) {
        const id: string = record.source + '_' + record.songId;
        for (let j: number = 0; j < list[i].songs.length; j++) {
          if (list[i].songs[j].source + '_' + list[i].songs[j].songId === id) {
            return false;
          }
        }
        if (this.getPlaylistAddPosition() === 'top') {
          list[i].songs.unshift(record);
        } else {
          list[i].songs.push(record);
        }
        this.persistPlaylists(list);
        this.playlistVersion++;
        return true;
      }
    }
    return false;
  }

  /** Removes a song from a playlist by source and songId. */
  public removeSongFromPlaylist(playlistId: string, source: string, songId: string): void {
    const list: PlaylistDto[] = this.getPlaylists();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === playlistId) {
        const id: string = source + '_' + songId;
        const kept: PlayedSongRecord[] = [];
        for (let j: number = 0; j < list[i].songs.length; j++) {
          if (list[i].songs[j].source + '_' + list[i].songs[j].songId !== id) {
            kept.push(list[i].songs[j]);
          }
        }
        list[i].songs = kept;
        this.persistPlaylists(list);
        this.playlistVersion++;
        return;
      }
    }
  }

  /** Reorders the songs inside a playlist to the given key sequence (source_songId). */
  public reorderPlaylistSongs(playlistId: string, orderedKeys: string[]): void {
    const list: PlaylistDto[] = this.getPlaylists();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === playlistId) {
        const byKey: Map<string, PlayedSongRecord> = new Map<string, PlayedSongRecord>();
        for (let j: number = 0; j < list[i].songs.length; j++) {
          const s = list[i].songs[j];
          byKey.set(s.source + '_' + s.songId, s);
        }
        const reordered: PlayedSongRecord[] = [];
        for (let k: number = 0; k < orderedKeys.length; k++) {
          const song = byKey.get(orderedKeys[k]);
          if (song !== undefined) {
            reordered.push(song);
            byKey.delete(orderedKeys[k]);
          }
        }
        byKey.forEach((song: PlayedSongRecord): void => {
          reordered.push(song);
        });
        list[i].songs = reordered;
        this.persistPlaylists(list);
        this.playlistVersion++;
        return;
      }
    }
  }

  /**
   * Dedupes a playlist by (title + singer): keeps the copy with the highest
   * retention priority and removes duplicates lower in the priority chain
   * (mg < kw < kg < wy < tx; tx / QQ is kept first).
   * @param playlistId Playlist id to dedupe.
   * @returns Number of songs removed.
   */
  public dedupePlaylistSongs(playlistId: string): number {
    const list: PlaylistDto[] = this.getPlaylists();
    const priorityOrder: string[] = ['mg', 'kw', 'kg', 'wy', 'tx'];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== playlistId) {
        continue;
      }
      const songPriority: Map<string, number> = new Map<string, number>();
      for (let p: number = 0; p < priorityOrder.length; p++) {
        songPriority.set(priorityOrder[p], p);
      }
      const bestByKey: Map<string, number> = new Map<string, number>();
      for (let j: number = 0; j < list[i].songs.length; j++) {
        const s = list[i].songs[j];
        const nameKey: string = (s.name ?? '').trim().toLowerCase();
        const singerKey: string = (s.singer ?? '').trim().toLowerCase();
        if (nameKey.length === 0) {
          continue;
        }
        const key: string = nameKey + '|' + singerKey;
        const idx = bestByKey.get(key);
        if (idx === undefined) {
          bestByKey.set(key, j);
          continue;
        }
        const kept = list[i].songs[idx];
        const curPrio: number = songPriority.get(s.source) ?? -1;
        const keptPrio: number = songPriority.get(kept.source) ?? -1;
        if (curPrio > keptPrio) {
          bestByKey.set(key, j);
        }
      }
      const deduped: PlayedSongRecord[] = [];
      const chosen: Set<number> = new Set<number>();
      bestByKey.forEach((songIndex: number): void => {
        chosen.add(songIndex);
      });
      for (let j: number = 0; j < list[i].songs.length; j++) {
        const s = list[i].songs[j];
        const nameKey: string = (s.name ?? '').trim().toLowerCase();
        const singerKey: string = (s.singer ?? '').trim().toLowerCase();
        const key: string = (nameKey.length === 0 ? '' : nameKey + '|' + singerKey);
        if (chosen.has(j) || key.length === 0) {
          deduped.push(s);
        }
      }
      const removed: number = list[i].songs.length - deduped.length;
      list[i].songs = deduped;
      this.persistPlaylists(list);
      this.playlistVersion++;
      return removed;
    }
    return 0;
  }

  /** Imports a playlist (used for LXMusic import and restore). */
  public importPlaylist(name: string, songs: PlayedSongRecord[]): PlaylistDto {
    const p = new PlaylistDto();
    p.id = String(Date.now());
    p.name = name;
    p.createTime = Date.now();
    p.songs = songs;
    const list: PlaylistDto[] = this.getPlaylists();
    list.unshift(p);
    this.persistPlaylists(list);
    this.playlistVersion++;
    return p;
  }

  /** Maps a SongItem into a serializable record. */
  public static fromSongItem(item: SongItem): PlayedSongRecord {
    const record = new PlayedSongRecord();
    record.songId = item.songId;
    record.name = typeof item.title === 'string' ? item.title : '';
    record.singer = typeof item.singer === 'string' ? item.singer : '';
    record.albumName = item.albumName;
    record.albumId = item.albumId;
    record.source = item.source;
    record.interval = item.interval;
    record.img = item.cover;
    record.url = item.url;
    record.lyric = item.lyricText;
    record.quality = item.quality;
    record.playScript = item.playScript;
    record.time = Date.now();
    return record;
  }

  /** Rebuilds a SongItem from a stored record; url is pre-filled when available. */
  public static toSongItem(record: PlayedSongRecord): SongItem {
    const item = new SongItem();
    item.id = record.time;
    item.title = record.name;
    item.singer = record.singer;
    item.src = '';
    item.url = record.url;
    item.lyricText = record.lyric;
    item.cover = record.img;
    item.source = record.source;
    item.songId = record.songId;
    item.albumId = record.albumId;
    item.albumName = record.albumName;
    item.interval = record.interval;
    item.quality = record.quality;
    item.playScript = record.playScript;
    return item;
  }
}
