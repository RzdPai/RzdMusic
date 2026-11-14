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
import { AppStorageKeys, HomeSourceState, MusicAppState, MusicStoreService, PlaybackIntentState, getAppRuntime } from 'musicbasic';
import { AccountService, LXSearchSong, OnlinePlayUtil } from 'player';
import { RecommendSongUiDataSource } from '../model/RecommendSongUiDataSource';
import {
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
      const sortId: string = this.plazaSortIndex < sorts.length ? sorts[this.plazaSortIndex].id : sorts[0].id;
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
    } catch (_err) {
      if (page === 1) {
        this.plazaPlaylists = [];
        this.plazaHasNext = false;
        this.plazaErrorText = `加载${MusicDataService.sourceName(this.plazaSourceCode())}歌单失败，请检查网络`;
      }
    }
    this.plazaLoading = false;
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

  /** Rebuilds the ranking board list for the current ranking source, then fills covers. */
  private loadRankingBoards(): void {
    const source: string = this.rankingSourceCode();
    const boards: RecommendBoardUi[] = MusicDataService.boards(source)
      .map((item: BoardData): RecommendBoardUi => {
        const ui = new RecommendBoardUi();
        ui.id = item.id;
        ui.name = item.name;
        ui.source = item.source;
        return ui;
      });
    this.rankingBoards = boards;
    void MusicDataService.boardsWithCovers(source).then((boardData: BoardData[]) => {
      const coverMap: Record<string, string> = {};
      for (let i: number = 0; i < boardData.length; i++) {
        if (boardData[i].cover.length > 0) {
          coverMap[boardData[i].id] = boardData[i].cover;
        }
      }
      const filled: RecommendBoardUi[] = [];
      for (let i: number = 0; i < boards.length; i++) {
        const ui = new RecommendBoardUi();
        ui.id = boards[i].id;
        ui.name = boards[i].name;
        ui.source = boards[i].source;
        ui.cover = coverMap[boards[i].id] === undefined ? '' : coverMap[boards[i].id];
        filled.push(ui);
      }
      this.rankingBoards = filled;
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
    if (songs.length > 0) {
      cards = RecommendDataUtil.mapAccountTracksToForYouCards(songs);
      banners = RecommendDataUtil.mapAccountTracksToHeroCards(songs);
    } else if (homeSource === 'qq') {
      banners = await RecommendDataUtil.loadTxBannersAsync();
      cards = await RecommendDataUtil.loadTxForYouAsync();
      songs = await RecommendDataUtil.loadPrivateSongListAsync(12, 'qq');
    } else {
      banners = await RecommendDataUtil.loadSourceBannersAsync(homeSource);
      cards = await RecommendDataUtil.loadSourceCardsAsync(homeSource);
      songs = await RecommendDataUtil.loadSourceSongsAsync(homeSource, 12);
    }
    if (banners.length > 0) {
      this.heroCards = banners;
    } else {
      this.heroCards = RecommendDataUtil.getHeroCards();
    }
    if (cards.length > 0) {
      this.recommendItems = cards;
    } else {
      this.recommendItems = RecommendDataUtil.getRecommendPlaylists();
    }
    if (songs.length > 0) {
      this.privateSongDisplayList = songs;
      this.privateSongDataSource = new RecommendSongUiDataSource(songs);
    } else {
      const list = RecommendDataUtil.getPrivateSongDisplayList();
      this.privateSongDisplayList = list;
      this.privateSongDataSource = new RecommendSongUiDataSource(list);
    }
    this.homeLoaded = true;
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
