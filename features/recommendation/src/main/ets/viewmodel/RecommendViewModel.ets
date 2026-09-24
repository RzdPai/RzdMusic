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


import { AppStorageV2, UIContext } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { AppStorageKeys, HomeSourceState, Logger, MusicAppState, MusicStoreService, PlaybackIntentState, getAppRuntime } from 'musicbasic';
import { AccountService, ColorConversion, LXSearchSong, OnlinePlayUtil } from 'player';
import { RecommendSongUiDataSource } from '../model/RecommendSongUiDataSource';import {
  RecommendBoardUi,
  RecommendCardUi,
  RecommendCategoryTabUi,
  RecommendChartUi,
  RecommendHeroCardUi,
  RecommendPlazaPlaylistUi,
  RecommendPrivateSongUi,
  RecommendSingerUi
} from '../model/RecommendUiModels';
import { RecommendDataUtil } from '../util/RecommendDataUtil';
import { BoardData, CategoryGroup, MusicDataService, PlaylistData, PlaylistPage } from '../util/MusicDataService';

/** 歌单广场排障统一 TAG：`hdc shell hilog | findstr RzdPlazaNet` 一把抓完。 */
const PLAZA_DOMAIN: number = 0x0000;
const PLAZA_TAG: string = 'RzdPlazaNet';

/**
 * View model for the recommendation home: hero banners, playlists, private songs, and category chips.
 * State is observable via ArkUI {@code @ObservedV2} for UI binding.
 */
@ObservedV2
export class RecommendViewModel {
  private playbackIntent: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!;
  private appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /**
   * 最近一次创建实例的静态交点。
   *
   * 首页（RecommendPage）持有自己的实例，而「每日30首」列表页是另一个页面 ——
   * 它要显示的就是首页这份推荐列表，所以通过这个交点复用同一个实例，
   * 避免为了传一个 VM 去改路由参数类型。
   */
  private static latest: RecommendViewModel | undefined = undefined;

  /** @returns 当前是否有在播曲目（首页「现在就听」卡用）。 */
  public hasCurrentSong(): boolean {
    return this.appState.getCurrentSongItem() !== undefined;
  }

  /** 打开全屏播放页（首页「现在就听」卡用）。 */
  public openPlayer(): void {
    this.appState.isShowPlay = true;
  }

  /** @returns 首页正在使用的那份实例（尚未创建时返回 undefined）。 */
  public static current(): RecommendViewModel | undefined {
    return RecommendViewModel.latest;
  }

  /**
   * 「每日30首」的四宫格是否可以显示真实封面。
   *
   * 首页列表封面是异步补进来的，**补完之前不渲染四宫格** —— 否则会先闪四张纯色块。
   * 补完（或确认拿不到）后置 true。
   */
  @Trace public dailySongsReady: boolean = false;

  constructor() {
    RecommendViewModel.latest = this;
  }
  /** Home recommendation source selected in settings ('qq'|'kg'|'wy'). */
  private homeSourceState: HomeSourceState =
    AppStorageV2.connect(HomeSourceState, AppStorageKeys.HOME_SOURCE_STATE, () => new HomeSourceState())!;

  /** Hero banner cards shown in the horizontal carousel. */
  @Trace public heroCards: RecommendHeroCardUi[] = [];
  /** “For you�?recommendation playlist cards. */
  @Trace public recommendItems: RecommendCardUi[] = [];
  /** Private-songs section list items (display model). */
  @Trace public privateSongDisplayList: RecommendPrivateSongUi[] = [];
  /** Lazy list data source backed by the private song display list. */
  @Trace public privateSongDataSource: RecommendSongUiDataSource = new RecommendSongUiDataSource([]);
  /** Category chip tabs (title and selected/unselected icons). */
  @Trace public categoryTabItems: RecommendCategoryTabUi[] = [];
  /** Index of the selected category chip in the category tab items array. */
  @Trace public selectedCategoryIndex: number = 0;
  /** Search query string reserved for future search integration. */
  @Trace public searchQuery: string = '';
  /**
   * 「现在就听」卡的背景色（由当前封面异步取色，空串表示用兜底色）。
   *
   * **只在首页装配时算一次**，之后不随换歌自动变（用户要求「不要每次自动刷新」）。
   */
  @Trace public nowPlayingTint: string = '';
  /**
   * 「现在就听」卡是否已定稿。
   *
   * 定稿后封面与背景色**不再随换歌变化**（用户要求「不要每次自动刷新」）。
   */
  private nowPlayingTrap: boolean = false;

  /** 把「现在就听」卡定稿（之后不再自动刷新）。 */
  public lockNowPlayingCard(): void {
    this.nowPlayingTrap = true;
  }

  /**
   * 「现在就听」卡显示的封面。
   *
   * 与 `nowPlayingTint` 同一次装配定下来，**不再跟着在播歌曲实时变**。
   * 之前封面用 `currentSongCover()` 实时读，而取色是装配时算的 ——
   * 于是换歌后卡片会变成"上一次的封面配旧的背景色"，看着就是"显示的还不是当前这首"。
   */
  @Trace public nowPlayingCoverUrl: string = '';
  /** 已经取过色的封面地址（避免同一张封面反复下载解码）。 */
  private tintedCoverUrl: string = '';
  /** Singer chart rows for the singer category content (empty until loaded). */
  @Trace public singerList: RecommendSingerUi[] = [];
  /** Full toplist rows for the chart category content (empty until loaded). */
  @Trace public chartList: RecommendChartUi[] = [];
  /** True while the category content list is being fetched. */
  @Trace public categoryLoading: boolean = false;
  /** True once the initial home data (banners, cards, private songs) has finished loading. */
  @Trace public homeLoaded: boolean = false;
  /** True when no music-platform account is signed in; guest sections (plaza, rankings) show. */
  @Trace public isGuestMode: boolean = false;
  /** Index of the selected playlist-plaza source in {@link MusicDataService.sourceList}. */
  @Trace public plazaSourceIndex: number = 0;
  /** Index of the selected playlist-plaza sort option for the current source. */
  @Trace public plazaSortIndex: number = 0;
  /** Playlist-plaza category groups for the current source. */
  @Trace public plazaCategoryGroups: CategoryGroup[] = [];
  /** Display name of the selected playlist-plaza category; empty = default. */
  @Trace public plazaCategoryName: string = '';
  /** Source-specific category id of the selected playlist-plaza category; empty = default. */
  @Trace public plazaCategoryId: string = '';
  /** Playlist-plaza card list (accumulates pages). */
  @Trace public plazaPlaylists: RecommendPlazaPlaylistUi[] = [];
  /** True while the first plaza page is loading. */
  @Trace public plazaLoading: boolean = false;
  /** True while a subsequent plaza page is loading. */
  @Trace public plazaLoadingMore: boolean = false;
  /** Non-empty plaza error message from the last first-page load. */
  @Trace public plazaErrorText: string = '';
  /** True when the plaza source reports more pages. */
  @Trace public plazaHasNext: boolean = false;
  /** Index of the selected ranking source in {@link MusicDataService.sourceList}. */
  @Trace public rankingSourceIndex: number = 0;
  /** Ranking board entries for the selected ranking source. */
  @Trace public rankingBoards: RecommendBoardUi[] = [];
  private plazaPage: number = 1;
  private guestSectionsRequested: boolean = false;
  private accountServiceReady: boolean = false;

  /**
   * Loads all recommendation UI data: QQ music toplists for banners, cards and
   * private songs; falls back to demo data when the network fails.
   */
  public load(): void {
    this.homeLoaded = false;
    this.categoryTabItems = RecommendDataUtil.getCategoryTabs();
    this.chartList = [];
    this.refreshGuestMode();
    void this.loadHomeData();
  }

  /** Refreshes the guest flag from the account store; kicks off guest sections when guest. */
  public refreshGuestMode(): void {
    let guest: boolean = this.isGuestMode;
    try {
      const runtime = getAppRuntime();
      if (!this.accountServiceReady) {
        AccountService.init(runtime.context);
        this.accountServiceReady = true;
      }
      guest = AccountService.listAccounts().length === 0;
    } catch (_err) {
      guest = this.isGuestMode;
    }
    this.isGuestMode = guest;
    this.ensureGuestSections();
  }

  /** Loads plaza/ranking sections once per session regardless of account state. */
  private ensureGuestSections(): void {
    if (this.guestSectionsRequested) {
      return;
    }
    this.retryGuestSections();
  }

  /** Forces a guest sections reload (used for retry after a network failure). */
  public retryGuestSections(): void {
    this.guestSectionsRequested = true;
    // 首页排行榜关闭时不再请求榜单数据，省掉无用网络开销
    if (MusicStoreService.getInstance().getShowHomeRanking()) {
      this.loadRankingBoards();
    }
    // 歌单广场关闭时不再请求其数据，省掉无用网络开销
    if (MusicStoreService.getInstance().getShowHomePlaza()) {
      void this.loadPlazaCategories();
      void this.loadPlazaPlaylists(1);
    }
  }

  /** Source id of the currently selected playlist-plaza source. */
  public plazaSourceCode(): string {
    return MusicDataService.sourceList[this.plazaSourceIndex];
  }

  /** Source id of the currently selected ranking source. */
  public rankingSourceCode(): string {
    return MusicDataService.sourceList[this.rankingSourceIndex];
  }

  /** Switches the plaza source and reloads sort/category/playlists. */
  public async selectPlazaSource(index: number): Promise<void> {
    if (index === this.plazaSourceIndex && this.plazaPlaylists.length > 0) {
      return;
    }
    this.plazaSourceIndex = index;
    this.plazaSortIndex = 0;
    this.plazaCategoryName = '';
    this.plazaCategoryId = '';
    void this.loadPlazaCategories();
    await this.loadPlazaPlaylists(1);
  }

  /** Switches the plaza sort option and reloads the first page. */
  public async selectPlazaSort(index: number): Promise<void> {
    if (index === this.plazaSortIndex) {
      return;
    }
    this.plazaSortIndex = index;
    await this.loadPlazaPlaylists(1);
  }

  /** Switches the plaza category and reloads the first page. */
  public async selectPlazaCategory(id: string, name: string): Promise<void> {
    if (id === this.plazaCategoryId) {
      return;
    }
    this.plazaCategoryName = name;
    this.plazaCategoryId = id;
    await this.loadPlazaPlaylists(1);
  }

  /** Loads playlist-plaza category groups for the current source. */
  public async loadPlazaCategories(): Promise<void> {
    const groups = await MusicDataService.categories(this.plazaSourceCode());
    this.plazaCategoryGroups = groups;
  }

  /**
   * Loads one plaza page; page 1 resets the list, later pages append.
   * @param page 1-based page number.
   */
  public async loadPlazaPlaylists(page: number): Promise<void> {
    if (page > 1 && (this.plazaLoadingMore || !this.plazaHasNext)) {
      return;
    }
    if (page === 1) {
      this.plazaLoading = true;
    } else {
      this.plazaLoadingMore = true;
    }
    this.plazaErrorText = '';
    try {
      const sorts = MusicDataService.sortOptions(this.plazaSourceCode());
      const sortId: string = sorts.length > 0
        ? (this.plazaSortIndex < sorts.length ? sorts[this.plazaSortIndex].id : sorts[0].id)
        : '';
      const result: PlaylistPage = await MusicDataService.playlists(this.plazaSourceCode(), sortId,
        this.plazaCategoryId.length > 0 ? this.plazaCategoryId : undefined, page);
      const mapped: RecommendPlazaPlaylistUi[] = result.list.map((item: PlaylistData): RecommendPlazaPlaylistUi => {
        const ui = new RecommendPlazaPlaylistUi();
        ui.id = item.id;
        ui.name = item.name;
        ui.author = item.author;
        ui.image = item.image;
        ui.count = item.count;
        ui.listenCount = item.listenCount;
        ui.source = item.source;
        return ui;
      });
      if (page === 1) {
        this.plazaPlaylists = mapped;
      } else {
        this.plazaPlaylists = this.plazaPlaylists.concat(mapped);
      }
      this.plazaPage = result.page;
      this.plazaHasNext = result.hasNext;
      if (page === 1) {
        hilog.info(PLAZA_DOMAIN, PLAZA_TAG,
          'plaza loaded: source=%{public}s items=%{public}d total=%{public}d hasNext=%{public}s',
          this.plazaSourceCode(), mapped.length, result.total, String(result.hasNext));
      }
    } catch (err) {
      const e: Error = err as Error;
      if (page === 1) {
        this.plazaPlaylists = [];
        this.plazaHasNext = false;
        this.plazaErrorText = `加载${MusicDataService.sourceName(this.plazaSourceCode())}歌单失败，请检查网络`;
        hilog.error(PLAZA_DOMAIN, PLAZA_TAG, 'plaza load FAILED: source=%{public}s msg=%{public}s',
          this.plazaSourceCode(), e.message ?? '');
      }
    }    this.plazaLoading = false;
    this.plazaLoadingMore = false;
  }

  /** Loads the next plaza page when available. */
  public loadMorePlazaPlaylists(): void {
    if (this.plazaLoading || this.plazaLoadingMore || !this.plazaHasNext) {
      return;
    }
    void this.loadPlazaPlaylists(this.plazaPage + 1);
  }

  /** Switches the ranking source and reloads the board entries. */
  public selectRankingSource(index: number): void {
    if (index === this.rankingSourceIndex) {
      return;
    }
    this.rankingSourceIndex = index;
    // 首页排行榜关闭时不再请求榜单数据，省掉无用网络开销
    if (MusicStoreService.getInstance().getShowHomeRanking()) {
      this.loadRankingBoards();
    }
  }

  /**
   * 重建当前平台的榜单列表。
   *
   * **只用 `boardsWithCovers` 这一个真源**：以前先按写死的 id/名字表铺一版、拿到封面后再
   * 按 id 合并回去，酷我改成实时列表后两边对不上（实时列表里有写死表里没有的 id），
   * 合并结果就会缺项 / 错位。现在直接把接口结果当列表。
   */
  private loadRankingBoards(): void {
    const source: string = this.rankingSourceCode();
    void MusicDataService.boardsWithCovers(source).then((boardData: BoardData[]) => {
      const filled: RecommendBoardUi[] = [];
      for (let i: number = 0; i < boardData.length; i++) {
        const ui = new RecommendBoardUi();
        ui.id = boardData[i].id;
        ui.name = boardData[i].name;
        ui.source = boardData[i].source;
        ui.cover = boardData[i].cover;
        filled.push(ui);
      }
      this.rankingBoards = filled;
    }, (err: Object): void => {
      Logger.warn('RzdRecommend', 'loadRankingBoards failed: ' + JSON.stringify(err).substring(0, 120));
    });
  }

  /** Loads QQ music driven home sections; falls back to demo content on failure. */
  private async loadHomeData(): Promise<void> {
    let useAccountRec: boolean = false;
    try {
      useAccountRec = MusicStoreService.getInstance().getUseAccountRec();
    } catch (_err) {
      useAccountRec = false;
    }
    let banners: RecommendHeroCardUi[] = [];
    let cards: RecommendCardUi[] = [];
    let songs: RecommendPrivateSongUi[] = [];
    const homeSource: string = this.homeSourceState.source;
    if (useAccountRec) {
      songs = await RecommendDataUtil.loadTxAccountDailyTracksAsync();
    }
    if (songs.length === 0) {
      // 未登录 / 账号推荐拿不到内容：走平台榜单歌曲，卡片样式与登录态**完全一致**
      songs = await RecommendDataUtil.loadSourceSongsAsync(homeSource, 12);
    }
    if (homeSource === 'qq' && songs.length === 0) {
      songs = await RecommendDataUtil.loadPrivateSongListAsync(12, 'qq');
    }
    // 顶部大卡片 == MusicHome 的 5 张**功能入口卡**（现在就听 / 每日30首 / 新歌推荐 /
    // 心动模式 / 精选推荐），不是歌曲卡片。登录与否都是这一套。
    // ⚠️ 顺序很重要：必须**先把列表赋值**再生成卡片 —— 卡片要拿列表前 4 首的封面
    //    拼「每日30首」的四宫格，列表还没赋值时拿到的是空数组（就是那四张纯色块）。
    this.recommendItems = cards.length > 0 ? cards : RecommendDataUtil.getRecommendPlaylists();
    if (songs.length > 0) {
      this.privateSongDisplayList = songs;
      this.privateSongDataSource = new RecommendSongUiDataSource(songs);
    } else {
      const list = RecommendDataUtil.getPrivateSongDisplayList();
      this.privateSongDisplayList = list;
      this.privateSongDataSource = new RecommendSongUiDataSource(list);
    }
    if (songs.length === 0 && this.privateSongDisplayList.length === 0) {
      // 一首歌都没有：不卡在骨架屏，直接放行（卡片显示占位）
      this.dailySongsReady = true;
    }
    this.refreshFeatureHeroCards();
    this.homeLoaded = true;
    // 「现在就听」卡背景取色：也放在**放行之前**完成，
    // 否则卡片会先用兜底色画出来、取色回来再变一次（用户看到的"加载后刷新"）。
    await this.refreshNowPlayingTintAsync();
    // 最后补封面并放行：补完会重算功能卡（四宫格＋歌名），
    // 然后 `dailySongsReady` 置位，整块轮播一次性出现。
    await this.refillHomeCovers();
  }

  /**
   * 补首页歌曲封面，**补到为止**（最多 3 轮）。
   *
   * 首轮补图走的 `lxGetPicFallback` 是"平台图片接口 + 音源引擎兜底"的组合，
   * 偶发整批拿不到（网络抖动、引擎未就绪），所以还有空缺就再补几轮。
   *
   * ⚠️ **全部补完才放行首页卡片**（`dailySongsReady` 只在 3 轮跑完或没有缺失时才置位）。
   *    之前是首轮结束就放行、后面几轮在后台继续补 —— 用户看到的就是
   *    「卡片先按旧数据画出来，过一会儿封面/歌名又变一次」。
   *    现在整块轮播（含四宫格、歌名、取色背景）在数据完全定稿后一次性出现。
   */
  private async refillHomeCovers(): Promise<void> {
    const maxRounds: number = 3;
    for (let round: number = 0; round < maxRounds; round++) {
      const rows: RecommendPrivateSongUi[] = this.privateSongDisplayList;
      let missing: number = 0;
      for (let i: number = 0; i < rows.length; i++) {
        if (rows[i].coverUrl.length === 0 && rows[i].songId.length > 0) {
          missing = missing + 1;
        }
      }
      if (missing === 0) {
        break;
      }
      const filled: RecommendPrivateSongUi[] = await RecommendDataUtil.fillCovers(rows);
      if (filled.length > 0) {
        this.privateSongDisplayList = filled;
        this.privateSongDataSource = new RecommendSongUiDataSource(filled);
        // 封面补完之后重算功能卡：「每日30首」的 2×2 背景用的是前 4 首的封面。
        this.refreshFeatureHeroCards();
        // ★ 「现在就听」的背景取色必须在这里**再算一次**。
        //
        //   装配早期那次 `refreshNowPlayingTintAsync()` 是在封面补完**之前**跑的，
        //   那时 `nowPlayingCoverUrl` 还是空串（`refreshFeatureHeroCards` 拿到的
        //   列表封面全空），函数直接 return 了 —— 于是 `nowPlayingTint` 永远为空，
        //   卡片一直用兜底色 `#2E4A78`，用户看到的就是「背景像固定的、不跟随封面」。
        //   封面到这里才是真 URL，重新取色一次才算真正"跟随封面"。
        await this.refreshNowPlayingTintAsync();
      }
    }
    this.dailySongsReady = true;
    // 首页卡片全部定稿：封面、取色、歌名都不再自动变（用户要求「不要每次自动刷新」）
    this.lockNowPlayingCard();
  }

  /**
   * 在播歌曲变化时的兜底取色。
   *
   * ⚠️ **只在卡片还没定稿时生效**（`nowPlayingTrap` 为 false）。
   *    定稿之后首页卡片就不再自己变 —— 用户明确要求「不要每次自动刷新」。
   *    这次监听的意义只在于：首页装配完但取色还没回来时换歌，能立刻按新歌取一次色。
   */
  @Monitor('appState.selectIndex', 'appState.playQueueIds')
  onNowPlayingChanged(): void {
    if (!this.nowPlayingTrap) {
      this.refreshNowPlayingTint();
    }
  }

  /**
   * 刷新首页顶部 5 张功能入口卡的副标题。
   *
   * 每张卡**各自**从首页歌曲列表里随机抽一首作为副标题（用户要求"随机抽一首"，
   * 不是五张都显示同一首）。列表里没有歌时回落到当前在播歌曲，再没有就留品牌行。
   */
  /**
   * 刷新首页顶部 5 张功能入口卡的副标题与「每日30首」的四宫格。
   *
   * 副标题要求：**5 张卡各自的歌名都不重复**（不是每张独立随机 —— 独立随机会出现
   * 五张同名的情况）。做法是把歌名池洗牌后按顺序取，取完一圈再循环。
   */
  private refreshFeatureHeroCards(): void {
    const songs: RecommendPrivateSongUi[] = this.privateSongDisplayList;
    const names: string[] = [];
    const covers: string[] = [];
    const dailyCovers: string[] = [];
    const dailyTitles: string[] = [];
    for (let i: number = 0; i < songs.length; i++) {
      const t = songs[i].title;
      const title: string = typeof t === 'string' ? t : '';
      if (title.length > 0) {
        names.push(title);
        covers.push(songs[i].coverUrl.length > 0 ? songs[i].coverUrl : '');
      }
      if (dailyCovers.length < 4) {
        dailyCovers.push(songs[i].coverUrl.length > 0 ? songs[i].coverUrl : '');
        dailyTitles.push(title);
      }
    }
    if (names.length === 0) {
      const current = this.appState.getCurrentSongItem();
      if (current !== undefined && typeof current.title === 'string' && current.title.length > 0) {
        names.push(current.title);
        covers.push(current.cover.length > 0 ? current.cover : '');
      }
    }
    // 洗牌 → 5 张卡取到的歌名互不相同（池子不足 5 首时才允许重复）
    const order: number[] = RecommendViewModel.shuffledIndexes(names.length);
    const shuffled: string[] = [];
    const shuffledCovers: string[] = [];
    for (let i: number = 0; i < order.length; i++) {
      shuffled.push(names[order[i]]);
      // 封面与歌名**同下标一起洗牌**：卡片下方显示哪首，上面就得是哪首的封面
      shuffledCovers.push(covers[order[i]]);
    }
    // ★「现在就听」的封面与歌名取**同一个随机下标**（不是固定的第一首）：
    //   图与下方歌名必须对得上，且每次进首页都会换一首。
    const pickIndex: number = order.length > 0 ? order[0] : -1;
    const listenNowTitle: string = pickIndex >= 0 ? names[pickIndex] : '';
    const listenNowCover: string = pickIndex >= 0 ? covers[pickIndex] : '';
    // ★ 五张卡现在**全部**用歌曲自己的封面（不再用打包内配图），见 getFeatureHeroCards。
    this.heroCards = RecommendDataUtil.getFeatureHeroCards(shuffled, shuffledCovers, dailyCovers, dailyTitles,
      listenNowTitle, listenNowCover);
    // 「现在就听」卡的封面与背景色一起定稿（背景由这张封面取色）
    this.nowPlayingCoverUrl = listenNowCover;
  }

  /** Fisher-Yates 洗牌，返回下标顺序（不改入参）。 */
  private static shuffledIndexes(count: number): number[] {
    const out: number[] = [];
    for (let i: number = 0; i < count; i++) {
      out.push(i);
    }
    for (let i: number = out.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: number = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }

  /** @returns 当前在播歌曲封面地址（没有则空串）。 */
  public currentSongCover(): string {
    const current = this.appState.getCurrentSongItem();
    if (current === undefined) {
      return '';
    }
    return current.cover.length > 0 ? current.cover : '';
  }

  /**
   * 「现在就听」卡的背景色：**由当前封面异步取主色**。
   *
   * 封面换了就重新算（`@Trace nowPlayingTint` 变更会驱动卡片重建）。
   * 取不到色时留空，卡片回落到固定兜底色。
   */
  public refreshNowPlayingTint(): void {
    void this.refreshNowPlayingTintAsync();
  }

  /**
   * 同步版本：等取色真正完成才返回。
   *
   * 首页首次装配时用它 —— 卡片必须在**首次渲染之前**就拿到最终封面与背景色，
   * 否则会先按兜底色画出来、取色回来再变一次。
   * @returns 取色完成的 Promise。
   */
  public async refreshNowPlayingTintAsync(): Promise<void> {
    // 封面由 refreshFeatureHeroCards() 从首页列表首张可用封面定稿；
    // 这里只负责按它取色（没有封面就跳过，卡片用兜底色）。
    const cover: string = this.nowPlayingCoverUrl;
    if (cover.length === 0) {
      return;
    }
    await this.applyTintFrom(cover);
  }

  /** 下载封面并写入 `nowPlayingTint`（同封面不重复取色）。 */
  private async applyTintFrom(cover: string): Promise<void> {
    // 同一个封面已经取过色就直接用旧值：`refreshFeatureHeroCards()` 会被调用多次
    // （装配早期 + 每轮补封面之后），没有这道闸就会反复下载同一张图取色。
    if (cover === this.tintedCoverUrl && this.nowPlayingTint.length > 0) {
      return;
    }
    this.tintedCoverUrl = cover;
    await RecommendViewModel.pickTint(cover, (tint: string): void => {
      if (tint.length > 0) {
        this.nowPlayingTint = tint;
      }
    });
  }

  /**
   * 下载封面并取主色（与榜单/歌手页同一套：`dealColor` 压暗后当背景）。
   *
   * @param url 封面地址。
   * @param onPicked 取色完成回调（主色 `#RRGGBB`，失败时为空串）。
   */
  private static async pickTint(url: string, onPicked: (tint: string) => void): Promise<void> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 15000
      });
      if (resp.responseCode !== 200 || resp.result === undefined) {
        onPicked('');
        return;
      }
      const src: image.ImageSource = image.createImageSource(resp.result as ArrayBuffer);
      try {
        const pixelMap: image.PixelMap = await src.createPixelMap();
        try {
          const arr: number[] = await new Promise<number[]>((resolve: (v: number[]) => void) => {
            effectKit.createColorPicker(pixelMap,
              (error: Error | undefined, picker: effectKit.ColorPicker | undefined) => {
                if (error !== undefined || picker === undefined) {
                  resolve([]);
                  return;
                }
                const c = picker.getLargestProportionColor();
                resolve([c.red, c.green, c.blue]);
              });
          });
          if (arr.length >= 3) {
            // ★ 用 `vividFlowColors` 而**不是** `dealColor`：
            //   dealColor 把亮度上限锁死在 0.3（约 RGB 76），任何封面出来的都是接近黑的
            //   深色 —— 这就是「背景大部分情况下是黑的」。卡片背景要看得见的颜色，
            //   所以取鲜艳那一个（亮度 0.62~0.86），再按它派生一个更暗的同色系。
            const vivid: string[] = ColorConversion.vividFlowColors(arr[0], arr[1], arr[2]);
            onPicked(vivid.length > 0 ? vivid[0] : '');
            return;
          }
        } finally {
          try {
            pixelMap.release();
          } catch (_err) {
            // ignore
          }
        }
      } finally {
        src.release();
      }
    } catch (_err) {
      // 网络/解码失败：留空，卡片用兜底色
    } finally {
      req.destroy();
    }
    onPicked('');
  }

  /**
   * Requests playback for an online song row via the LX source engine.
   *
   * @param item Online song row.
   * @param uiContext Used for toast prompts.
   */
  public async requestPlayOnlineSong(item: RecommendPrivateSongUi,
    uiContext: UIContext | undefined): Promise<void> {
    const song: LXSearchSong = {
      songId: item.songId,
      name: typeof item.title === 'string' ? item.title : '',
      singer: typeof item.singer === 'string' ? item.singer : '',
      albumName: '',
      albumId: '',
      source: item.source,
      interval: '',
      img: item.coverUrl,
      types: []
    };
    await OnlinePlayUtil.playSearchSong(this.appState, song, uiContext);
  }

  /**
   * Updates the selected category chip index and loads content for the category
   * (singers for index 1, charts for index 2; 0 = featured keeps home content).
   *
   * @param index - Selected index in the category tab items array.
   */
  public selectCategory(index: number): void {
    this.selectedCategoryIndex = index;
    if (index === 1) {
      void this.loadSingers();
    } else if (index === 2) {
      void this.loadCharts();
    }
  }

  /** Loads the QQ singer chart into {@link singerList} (once). */
  private async loadSingers(): Promise<void> {
    if (this.singerList.length > 0 || this.categoryLoading) {
      return;
    }
    this.categoryLoading = true;
    const singers = await RecommendDataUtil.loadSingerListAsync(30);
    this.singerList = singers;
    this.categoryLoading = false;
  }

  /** Loads the chart overview of the selected home source into {@link chartList} (once). */
  private async loadCharts(): Promise<void> {
    if (this.chartList.length > 0 || this.categoryLoading) {
      return;
    }
    this.categoryLoading = true;
    const charts = await RecommendDataUtil.loadChartListForSourceAsync(this.homeSourceState.source);
    this.chartList = charts;
    this.categoryLoading = false;
  }

  /**
   * Requests playback for the given song by updating global PlaybackIntentState.
   *
   * @param songId - Song identifier to play.
   */
  public requestPlayBySongId(songId: number): void {
    RecommendDataUtil.applyPlaybackIntentForSongId(songId, this.playbackIntent);
  }
}
