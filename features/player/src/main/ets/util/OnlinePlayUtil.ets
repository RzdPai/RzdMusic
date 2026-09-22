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

import { UIContext } from '@kit.ArkUI';
import { MusicAppState, MusicStoreService, PlayedSongRecord, PlaybackShellConstants, QualityInfo, SongItem, appendPlayLog } from 'musicbasic';
import { LXSearchSong, LXQualityType, lxGetLyricFull, lxSearch, WyLyricResult } from '../source/LXMusicSDK';
import { lxEngineIsReady } from '../source/LXSourceEngine';
import { LXSource } from '../source/Interface';
import { MediaService } from '../model/MediaService';

/**
 * Play orchestration for online (music-source) songs: resolve url/lyric, queue the
 * track(s), start playback, and open the full-screen player with the shared-element
 * animation (mini bar cover / title morph into the full-screen layout).
 */
export class OnlinePlayUtil {
  private static toast(uiContext: UIContext | undefined, message: string): void {
    if (uiContext !== undefined) {
      uiContext.getPromptAction().showToast({ message: message, duration: 2000 });
    }
  }

  /** Appends a marker line to the shared run log (visible in settings). */
  private static appendPlayLog(message: string): void {
    appendPlayLog(message);
  }

  /** Builds a SongItem from an LX search/leaderboard song. */
  private static buildSongItem(song: LXSearchSong): SongItem {
    const item = new SongItem();
    item.id = Date.now();
    item.title = song.name;
    item.singer = song.singer;
    item.src = '';
    item.cover = song.img;
    item.source = song.source;
    item.songId = song.songId;
    item.albumId = song.albumId;
    item.albumName = song.albumName;
    item.url = '';
    item.lyricText = '';
    item.interval = song.interval;
    item.qualityList = OnlinePlayUtil.toQualityList(song.types);
    return item;
  }

  /** Converts LX quality types to the shared QualityInfo list (public for pickers). */
  public static toQualityList(types: LXQualityType[]): QualityInfo[] {
    const list: QualityInfo[] = [];
    for (let i = 0; i < types.length; i++) {
      list.push({ type: types[i].type, size: types[i].size });
    }
    return list;
  }

  /** Resolves the full lyric (main + translation + romanization) for a song. */
  private static async resolveLyricFull(song: LXSearchSong): Promise<WyLyricResult> {
    try {
      return await lxGetLyricFull(song.source, song.songId, song.name, song.singer);
    } catch (_err) {
      const empty: WyLyricResult = { main: '', translation: '', romanLyric: '' };
      return empty;
    }
  }

  /** Opens the full-screen player inside an animateTo so shared elements morph smoothly. */
  private static openFullScreen(appState: MusicAppState, uiContext: UIContext | undefined): void {
    if (uiContext !== undefined) {
      uiContext.animateTo({
        duration: PlaybackShellConstants.OPEN_PLAYER_UI_ANIMATION_MS,
        curve: Curve.EaseInOut
      }, () => {
        appState.isShowPlay = true;
      });
    } else {
      appState.isShowPlay = true;
    }
  }

  /**
   * Plays a single online song: resolves url, replaces the queue, starts playback and
   * opens the full-screen player. Lyric is fetched in background and refreshes via
   * MusicAppState.lyricVersion.
   * @param appState Shared playback state.
   * @param song Search / leaderboard song.
   * @param uiContext Used for toast prompts and the open animation.
   * @returns True when the song was queued and playback started.
   */
  public static async playSearchSong(appState: MusicAppState, song: LXSearchSong,
    uiContext: UIContext | undefined): Promise<boolean> {
    if (!lxEngineIsReady) {
      OnlinePlayUtil.toast(uiContext, '音源未就绪，请在设置中导入并选中源');
      return false;
    }
    // 秒开播放页：搜索结果已含标题/歌手/封面，先建条目入队并打开页面，
    // 播放地址交给 loadAsset 在后台解析（换源/降级可能耗时数秒），页面不再干等。
    // 解析完成后 MediaService.resolveOnlineUrl 会把 url/音质/音源脚本回填到该条目。
    const item = OnlinePlayUtil.buildSongItem(song);
    appState.currentQuality = '';
    appState.isResolving = true;
    appState.replaceQueue([item], 0);
    MediaService.getInstance().loadAsset(0);
    OnlinePlayUtil.openFullScreen(appState, uiContext);
    OnlinePlayUtil.appendPlayLog('[播放] playSearchSong 秒开，后台解析 ' +
      song.source + '/' + song.songId);
    const lyricItem: SongItem = item;
    const lyricState: MusicAppState = appState;
    void OnlinePlayUtil.resolveLyricFull(song).then((all: WyLyricResult): void => {
      if (all.main.length > 0) {
        lyricItem.lyricText = all.main;
      }
      if (all.translation.length > 0) {
        lyricItem.lyricTranslation = all.translation;
      }
      if (all.romanLyric.length > 0) {
        lyricItem.lyricRoman = all.romanLyric;
      }
      if (all.main.length > 0 || all.translation.length > 0 || all.romanLyric.length > 0) {
        lyricState.lyricVersion++;
      }
    });
    return true;
  }

  /**
   * Plays a stored history / favorite record; reuses a cached url when available.
   * @param appState Shared playback state.
   * @param record Stored song record.
   * @param uiContext Used for toast prompts and the open animation.
   * @returns True when the song was queued and playback started.
   */
  public static async playRecord(appState: MusicAppState, record: PlayedSongRecord,
    uiContext: UIContext | undefined): Promise<boolean> {
    const needResolve: boolean = record.url.length === 0;
    if (needResolve && !lxEngineIsReady) {
      OnlinePlayUtil.toast(uiContext, '音源未就绪，请在设置中导入并选中源');
      return false;
    }
    // kw 老记录可能带 MUSIC_ 前缀，去掉才能正确解析
    if (record.source === 'kw' && record.songId.startsWith('MUSIC_')) {
      record.songId = record.songId.substring(6);
    }
    // 秒开播放页：记录先变队列条目并打开页面；地址缺失时由 loadAsset 后台解析（含跨源降级）
    const item: SongItem = MusicStoreService.toSongItem(record);
    // 复用已缓存 url 时打缓存标记，播放页音质显示「XX（缓存）」
    item.playCached = !needResolve;
    appState.playQueueIds = [];
    appState.playQueue = [item];
    appState.selectIndex = 0;
    appState.currentQuality = needResolve ? '' : record.quality;
    appState.isResolving = needResolve;
    MediaService.getInstance().loadAsset(0);
    OnlinePlayUtil.openFullScreen(appState, uiContext);
    OnlinePlayUtil.appendPlayLog('[播放] playRecord 秒开 needResolve=' + needResolve +
      ' source=' + record.source + ' id=' + record.songId);
    if (!needResolve) {
      const storeCached: MusicStoreService = MusicStoreService.getInstance();
      storeCached.refreshHistoryQuality(record.source, record.songId, record.quality);
      storeCached.refreshFavoriteQuality(record.source, record.songId, record.quality);
    }
    // 每次播放都刷新歌词（老缓存可能是旧的逐行 LRC，新链路会拿到逐字）
    const song: LXSearchSong = {
      songId: record.songId,
      name: record.name,
      singer: record.singer,
      albumName: record.albumName,
      albumId: '',
      source: record.source,
      interval: record.interval,
      img: record.img,
      types: []
    };
    void OnlinePlayUtil.resolveLyricFull(song).then((all: WyLyricResult): void => {
      if (all.main.length > 0) {
        item.lyricText = all.main;
      }
      if (all.translation.length > 0) {
        item.lyricTranslation = all.translation;
      }
      if (all.romanLyric.length > 0) {
        item.lyricRoman = all.romanLyric;
      }
      if (all.main.length > 0 || all.translation.length > 0 || all.romanLyric.length > 0) {
        appState.lyricVersion++;
      }
    });
    return true;
  }

  /**
   * Plays a list of online songs starting at startIndex; the first track is resolved
   * eagerly, remaining tracks resolve their urls lazily on load.
   * @param appState Shared playback state.
   * @param songs Search / leaderboard songs.
   * @param startIndex Index to start playback at.
   * @param uiContext Used for toast prompts and the open animation.
   * @returns True when the queue was built and playback started.
   */
  public static async playList(appState: MusicAppState, songs: LXSearchSong[], startIndex: number,
    uiContext: UIContext | undefined): Promise<boolean> {
    if (!lxEngineIsReady) {
      OnlinePlayUtil.toast(uiContext, '音源未就绪，请在设置中导入并选中源');
      return false;
    }
    if (songs.length === 0) {
      return false;
    }
    const playIndex = startIndex < 0 || startIndex >= songs.length ? 0 : startIndex;
    const first = songs[playIndex];
    OnlinePlayUtil.appendPlayLog('[播放] playList index=' + playIndex + ' 歌数=' + songs.length +
      ' 歌曲=' + first.name + ' src=' + first.source + ' id=' + first.songId);
    // 秒开播放页：整队先入列并打开页面，仅当前这首由 loadAsset 后台解析地址
    const items: SongItem[] = [];
    for (let i: number = 0; i < songs.length; i++) {
      items.push(OnlinePlayUtil.buildSongItem(songs[i]));
    }
    appState.playQueueIds = [];
    appState.playQueue = items;
    appState.selectIndex = playIndex;
    appState.currentQuality = '';
    appState.isResolving = true;
    MediaService.getInstance().loadAsset(playIndex);
    OnlinePlayUtil.openFullScreen(appState, uiContext);
    OnlinePlayUtil.appendPlayLog('[播放] playList 秒开，后台解析 index=' + playIndex +
      ' 歌数=' + songs.length);
    // 仅预解析当前及邻近歌曲的歌词（切歌时其余歌曲会自动按需补全），
    // 避免长歌单数百首并发请求导致卡死。
    const preloadCount: number = 8;
    const start: number = Math.max(0, playIndex - preloadCount);
    const end: number = Math.min(items.length - 1, playIndex + preloadCount);
    for (let i: number = start; i <= end; i++) {
      const item: SongItem = items[i];
      const lxSong: LXSearchSong = songs[i];
      void OnlinePlayUtil.resolveLyricFull(lxSong).then((all: WyLyricResult): void => {
        if (all.main.length > 0) {
          item.lyricText = all.main;
        }
        if (all.translation.length > 0) {
          item.lyricTranslation = all.translation;
        }
        if (all.romanLyric.length > 0) {
          item.lyricRoman = all.romanLyric;
        }
        if (all.main.length > 0 || all.translation.length > 0 || all.romanLyric.length > 0) {
          if (i === playIndex) {
            appState.lyricVersion++;
          }
        }
      });
    }
    return true;
  }
}
