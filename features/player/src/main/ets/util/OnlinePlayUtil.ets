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
// ⚠️ `PlaybackShellConstants.OPEN_PLAYER_UI_ANIMATION_MS` 已从本文件的 import 里去掉：
//    它是上面 `openFullScreen` 那层 `animateTo` 的时长（P1-9），包装删掉后本文件不再用得到它。
//    常量本体仍留在 `musicbasic`（PC 壳层 `products/pc/.../Index.ets` 还在用，那一条待主线收）。
import { MusicAppState, MusicStoreService, PlayedSongRecord, QualityInfo, SongItem, appendPlayLog } from 'musicbasic';
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

  /**
   * 挂起全屏播放页浮层（**裸置位，外面不许再套 `animateTo`**）。
   *
   * ★★ 2026-10-15：这一段原来是
   * `uiContext.animateTo({ duration: OPEN_PLAYER_UI_ANIMATION_MS, curve: EaseInOut },
   *  () => { appState.isShowPlay = true; })` —— **旧动画时代的写法，已删除**。
   *
   * 为什么必须裸置位（`派音动画Bug清单.md` **P1-9**，交叉核对记录 §6.2 标 `[我核] ✅ 成立`）：
   * 1. `PlayerViewModel.openFullScreenWithSharedElementTransition()`（`viewmodel/PlayerViewModel.ets`）
   *    的注释**明令禁止**这层包装：那会给"挂载播放页浮层 + 形变几何初始化"整段套一层隐式动画，
   *    **形变的起点被这层动画吃掉** ⇒ 用户看到的正是"从搜索结果/播放记录打开播放器时，
   *    播放页从中间某处开始长大 / 先僵一下再展开"，而不是从迷你条长出来。
   * 2. 展开动画由**播放页自己**播（`PlaybackPage.playExpandIntro` → `playMorphOpenIntro`），
   *    它依赖 `UIUtils.applySync` 把"压到起点"同步刷出去；外面再套一层 `animateTo`
   *    等于把那层隐式动画又套回来，两条路（点击打开 / 手指拖动打开）会重新分叉。
   * 3. 同仓的"正确写法"全是裸置位（壳层 `products/default/.../Index.ets` 的
   *    `dispatchShellPlaybackIntent` 回调、`MiniBarPlayer` / `HomeMiniBarPlayer` /
   *    `RecommendViewModel` / `LocalMusicView`）—— **只有这里和 PC 壳层是旧的**。
   *
   * 判据（应为 0 命中）：`grep -rn "animateTo" --include=*.ets | Select-String "isShowPlay"`。
   * @param appState 共享播控状态（壳层 `@Monitor('appState.isShowPlay')` 会用这个字段挂载浮层）
   * @param _uiContext 仅保留形参以不动现有调用点签名；本方法已不再需要 UIContext
   *        （`toast` 那条路仍在用，见各 `play*` 方法）。
   */
  private static openFullScreen(appState: MusicAppState, _uiContext: UIContext | undefined): void {
    appState.isShowPlay = true;
  }

  /**
   * Plays a single online song: resolves url, replaces the queue, starts playback and
   * opens the full-screen player. Lyric is fetched in background and refreshes via
   * MusicAppState.lyricVersion.
   * @param appState Shared playback state.
   * @param song Search / leaderboard song.
   * @param uiContext Used for toast prompts only (the open animation is played by the player page itself).
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
   * @param uiContext Used for toast prompts only (the open animation is played by the player page itself).
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
   * @param uiContext Used for toast prompts only (the open animation is played by the player page itself).
   * @param openPlayer 是否**同时打开全屏播放页**（默认 `true` = 原行为，现有 4 参调用点一行都不用改）。
   *   传 `false` 的只有底栏页签「现在就听」（`NowPlayingFeedPage`）：那一页自己就是"现在在听什么"的
   *   全屏呈现，用户明确要求「打开这个页面**不会打开播放器**」。
   *   ⚠️ 用这个参数、**不要**在调用点事后把 `appState.isShowPlay` 掰回去：
   *   {@link openFullScreen} 一置位，壳层的 `@Monitor('appState.isShowPlay')`（**同步**触发）
   *   就会在 `pushPlayerRoute()` 里读到那个 true（`products/default/.../Index.ets`）
   *   —— 事后回滚等于"请求过又撤销"，监听方**已经读到过中间值**了。
   *   （本节 2026-10-15 订正：`openFullScreen` 原来是在 `uiContext.animateTo()` 的闭包里置位的，
   *    那一层包装已按 `派音动画Bug清单.md` P1-9 删除，但"不能事后回滚"这条理由与包装无关，
   *    照旧成立 —— 差别只在于"读到 true"与"读到 true 并吃掉一层隐式动画"。）
   * @returns True when the queue was built and playback started.
   */
  public static async playList(appState: MusicAppState, songs: LXSearchSong[], startIndex: number,
    uiContext: UIContext | undefined, openPlayer: boolean = true): Promise<boolean> {
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
    // ★ openPlayer = false 时**根本不请求**全屏播放页（见本方法的 @param 说明）。
    if (openPlayer) {
      OnlinePlayUtil.openFullScreen(appState, uiContext);
    }
    OnlinePlayUtil.appendPlayLog('[播放] playList 秒开，后台解析 index=' + playIndex +
      ' 歌数=' + songs.length + ' openPlayer=' + openPlayer);
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

  /**
   * 往**现有**播放队列尾部追加若干在线歌曲（不重开队列、不动 `selectIndex`、不触发任何 UI）。
   *
   * ★「现在就听」（`NowPlayingFeedPage`）到底之后**再拉一批**时用它：
   *   feed 变长了、队列也得跟着变长，否则 `MediaService.playNext()`（`MediaService.ets:1988`，
   *   「Loads the next queue index in linear order (**wraps to 0 at end**)」）读到的是**实时**
   *   `getQueueLength()` —— 队列不长，"播完最后一首"就 wrap 回第 0 首，用户听到的还是旧的那一批。
   *   追加之后，下一个下标自然落在新拉进来的那几首上。
   *
   * ⚠️ 调用方必须自己保证"**只追加真正新增的歌**"（本方法**不去重**）：
   *   队列与 feed 是两份东西，这里没有"已见过"的口径可查 —— 重复追加会让队列里出现重复曲目。
   * ⚠️ `@Trace` 数组必须**整体赋值**才可靠地触发观察（`playQueue` 是 `@Trace`）：
   *   这里用 `concat` 生成新数组再赋回去，**不要**用 `push`（`push` 改的是同一个引用）。
   * ⚠️ **不动 `selectIndex`**：追加只影响"后面还有什么"，当前这首与该下标的位置都没变。
   * @param appState 共享播控状态（`playQueue` 的真源）。
   * @param songs 要追加的在线歌曲（顺序 = 它们在 feed 里的顺序）。
   * @returns 真正追加了几首。
   */
  public static appendQueue(appState: MusicAppState, songs: LXSearchSong[]): number {
    if (songs.length === 0) {
      return 0;
    }
    const items: SongItem[] = [];
    for (let i: number = 0; i < songs.length; i++) {
      items.push(OnlinePlayUtil.buildSongItem(songs[i]));
    }
    // ⚠️ 整体赋值（见上面 @Trace 那条说明）
    appState.playQueue = appState.playQueue.concat(items);
    return items.length;
  }
}
