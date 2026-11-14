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


import {
  HeroCardApiDto,
  MusicDbApi,
  PlaybackIntentState,
  RecommendCardApiDto,
  SongApiDto,
  TabApiDto,
  getAppRuntime
} from 'musicbasic';
import { AccountService, getLeaderboardEntries, lxKgSingerList, lxLeaderboard, lxTxToplist, lxTxToplistInfo, lxTxToplistList, LXSearchSong, PlatformAccount, PlatformTrackInfo } from 'player';
import { BoardData, MusicDataService, TrackData } from './MusicDataService';
import {
  RecommendCardUi,
  RecommendCategoryTabUi,
  RecommendChartUi,
  RecommendHeroCardUi,
  RecommendPrivateSongUi,
  RecommendSingerUi
} from '../model/RecommendUiModels';

/**
 * Maps {@link MusicDbApi} DTOs to recommendation UI models and applies playback intents.
 */
export class RecommendDataUtil {
  /**
   * Fetches hero cards from the music DB and maps them to UI models.
   *
   * @returns Hero card UI list for banners.
   */
  public static getHeroCards(): RecommendHeroCardUi[] {
    return MusicDbApi.getInstance().getHeroCards().map((dto) => RecommendDataUtil.mapHeroDtoToUi(dto));
  }

  /**
   * Fetches recommendation playlists from the music DB and maps them to UI models.
   *
   * @returns Playlist card UI list for “For you” and similar strips.
   */
  public static getRecommendPlaylists(): RecommendCardUi[] {
    return MusicDbApi.getInstance().getRecommendPlaylists()
      .map((dto) => RecommendDataUtil.mapRecommendCardDtoToUi(dto));
  }

  /**
   * Fetches the private-songs display list from the music DB and maps it to UI models.
   *
   * @returns Private song rows for the home list.
   */
  public static getPrivateSongDisplayList(): RecommendPrivateSongUi[] {
    return MusicDbApi.getInstance()
      .getPrivateSongDisplayList()
      .map((dto) => RecommendDataUtil.mapSongDtoToPrivateUi(dto));
  }

  /**
   * Loads real leaderboard songs from the configured home recommendation source
   * (QQ default) and merges them into the home private-songs list.
   *
   * @param targetCount Desired number of rows (default 12).
   * @param source Home recommendation source id ('qq'|'kg'|'wy'|'mg'; 'qq' is default).
   * @returns Merged online song rows.
   */
  public static async loadPrivateSongListAsync(targetCount: number = 12,
    source: string = 'qq'): Promise<RecommendPrivateSongUi[]> {
    const merged: RecommendPrivateSongUi[] = [];
    const seen: string[] = [];
    if (source === 'qq') {
      const topids: string[] = ['6'];
      for (let i: number = 0; i < topids.length && merged.length < targetCount; i++) {
        let result: LXSearchSong[] = [];
        try {
          const res = await lxTxToplist(topids[i], 30);
          result = res.list;
        } catch (_err) {
          result = [];
        }
        for (let j: number = 0; j < result.length && merged.length < targetCount; j++) {
          merged.push(RecommendDataUtil.mapSearchSongToPrivateUi(result[j], j, seen));
        }
      }
      return merged;
    }
    const boards: string[] = [];
    if (source === 'kg') {
      boards.push('kg_8888', 'kg_52000', 'kg_28627');
    } else if (source === 'wy') {
      boards.push('wy_0', 'wy_1', 'wy_3');
    } else {
      boards.push('mg_1', 'mg_2', 'mg_3');
    }
    for (let i: number = 0; i < boards.length && merged.length < targetCount; i++) {
      let result: LXSearchSong[] = [];
      try {
        const res = await lxLeaderboard(boards[i], 1, 20);
        result = res.list;
      } catch (_err) {
        result = [];
      }
      for (let j: number = 0; j < result.length && merged.length < targetCount; j++) {
        merged.push(RecommendDataUtil.mapSearchSongToPrivateUi(result[j], j, seen));
      }
    }
    return merged;
  }

  /** Maps the home-source setting value ('qq'|'kg'|'wy') to the MusicDataService source id. */
  public static mapHomeSource(source: string): string {
    return source === 'qq' ? 'tx' : source;
  }

  /**
   * Loads home song rows from the selected platform's boards via MusicDataService.
   *
   * @param source Home source id ('qq'|'kg'|'wy').
   * @param targetCount Desired number of rows.
   * @returns Song rows for the home private-songs section.
   */
  public static async loadSourceSongsAsync(source: string, targetCount: number = 12): Promise<RecommendPrivateSongUi[]> {
    const svcSource: string = RecommendDataUtil.mapHomeSource(source);
    const merged: RecommendPrivateSongUi[] = [];
    const seen: string[] = [];
    let boards: BoardData[] = [];
    try {
      boards = MusicDataService.boards(svcSource);
    } catch (_err) {
      boards = [];
    }
    for (let i: number = 0; i < boards.length && merged.length < targetCount; i++) {
      let tracks: TrackData[] = [];
      try {
        tracks = await MusicDataService.tracks(svcSource, boards[i].id);
      } catch (_err) {
        tracks = [];
      }
      for (let j: number = 0; j < tracks.length && merged.length < targetCount; j++) {
        const track = tracks[j];
        const key: string = track.source + '_' + track.songId;
        if (track.songId.length === 0 || seen.indexOf(key) >= 0) {
          continue;
        }
        seen.push(key);
        const ui = new RecommendPrivateSongUi();
        ui.id = merged.length;
        ui.title = track.name;
        ui.singer = track.artist;
        ui.source = track.source;
        ui.songId = track.songId;
        ui.coverUrl = track.image;
        merged.push(ui);
      }
    }
    return merged;
  }

  /**
   * Builds "For you" cards from the selected platform's board list (no artwork;
   * palette gradients are used instead).
   *
   * @param source Home source id ('qq'|'kg'|'wy').
   * @returns Card UI models.
   */
  public static async loadSourceCardsAsync(source: string): Promise<RecommendCardUi[]> {
    const svcSource: string = RecommendDataUtil.mapHomeSource(source);
    let boards: BoardData[] = [];
    try {
      boards = await MusicDataService.boardsWithCovers(svcSource);
    } catch (_err) {
      boards = [];
    }
    const cards: RecommendCardUi[] = [];
    const label: string = MusicDataService.sourceName(svcSource);
    for (let i: number = 0; i < boards.length && cards.length < 6; i++) {
      if (i === 0) {
        continue;
      }
      const ui = new RecommendCardUi();
      ui.title = boards[i].name;
      ui.playCountLabel = label;
      ui.paletteIndex = i % 5;
      ui.backgroundUrl = boards[i].cover;
      ui.topid = '';
      ui.source = boards[i].source;
      ui.boardId = boards[i].id;
      cards.push(ui);
    }
    return cards;
  }

  /**
   * Builds hero banners from the selected platform's first boards.
   *
   * @param source Home source id ('qq'|'kg'|'wy').
   * @returns Hero banner UI models routing to the source board detail page.
   */
  public static async loadSourceBannersAsync(source: string): Promise<RecommendHeroCardUi[]> {
    const svcSource: string = RecommendDataUtil.mapHomeSource(source);
    let boards: BoardData[] = [];
    try {
      boards = await MusicDataService.boardsWithCovers(svcSource);
    } catch (_err) {
      boards = [];
    }
    const banners: RecommendHeroCardUi[] = [];
    const gradients: string[][] = [
      ['#152238', '#2E4A78'],
      ['#3D2F55', '#6B5A8C'],
      ['#5C2D2D', '#9A5C4A']
    ];
    const label: string = MusicDataService.sourceName(svcSource);
    for (let i: number = 0; i < boards.length && banners.length < 3; i++) {
      const ui = new RecommendHeroCardUi();
      ui.badge = label;
      ui.title = boards[i].name;
      ui.subLine = '在线排行榜';
      ui.coverUrl = boards[i].cover;
      ui.topid = '';
      ui.source = boards[i].source;
      ui.boardId = boards[i].id;
      ui.gradientStart = gradients[banners.length][0];
      ui.gradientEnd = gradients[banners.length][1];
      banners.push(ui);
    }
    return banners;
  }

  /**
   * Loads the chart list for the selected home source: QQ toplists keep their
   * banner pics; other platforms use their board lists (routing to the board
   * detail page).
   *
   * @param source Home source id ('qq'|'kg'|'wy').
   * @returns Chart UI rows.
   */
  public static async loadChartListForSourceAsync(source: string): Promise<RecommendChartUi[]> {
    if (source === 'qq') {
      return RecommendDataUtil.loadChartListAsync();
    }
    const svcSource: string = RecommendDataUtil.mapHomeSource(source);
    let boards: BoardData[] = [];
    try {
      boards = await MusicDataService.boardsWithCovers(svcSource);
    } catch (_err) {
      boards = [];
    }
    const uiList: RecommendChartUi[] = [];
    for (let i: number = 0; i < boards.length; i++) {
      const ui = new RecommendChartUi();
      ui.topid = '';
      ui.name = boards[i].name;
      ui.picUrl = boards[i].cover;
      ui.source = boards[i].source;
      ui.boardId = boards[i].id;
      uiList.push(ui);
    }
    return uiList;
  }

  /**
   * Loads the signed-in QQ account daily recommendations when the
   * "use login recommendations" switch is on.
   *
   * @returns Private song rows from the account daily track list; empty when
   *   no QQ account exists, the switch is off, or any network step fails.
   */
  public static async loadTxAccountDailyTracksAsync(): Promise<RecommendPrivateSongUi[]> {
    const runtime = getAppRuntime();
    if (runtime.context === undefined) {
      return [];
    }
    try {
      AccountService.init(runtime.context);
      const accounts: PlatformAccount[] = AccountService.listAccounts();
      let txId: string = '';
      for (let i = 0; i < accounts.length; i++) {
        if (accounts[i].source === 'tx') {
          txId = accounts[i].id;
          break;
        }
      }
      if (txId.length === 0) {
        return [];
      }
      const trackIds: string[] = await AccountService.getDailyTrackIds(txId);
      if (trackIds.length === 0) {
        return [];
      }
      const tracks: PlatformTrackInfo[] = await AccountService.getTrackDetails(txId, trackIds);
      return RecommendDataUtil.mapAccountTracksToPrivateUi(tracks);
    } catch (_err) {
      return [];
    }
  }

  /**
   * Maps account daily tracks into private-song UI rows.
   *
   * @param tracks Daily track details from the account provider.
   * @returns Song rows for the home private-songs section.
   */
  private static mapAccountTracksToPrivateUi(tracks: PlatformTrackInfo[]): RecommendPrivateSongUi[] {
    const rows: RecommendPrivateSongUi[] = [];
    for (let i = 0; i < tracks.length; i++) {
      const track: PlatformTrackInfo = tracks[i];
      if (track.id.length === 0) {
        continue;
      }
      const ui = new RecommendPrivateSongUi();
      ui.id = i;
      ui.title = track.name;
      ui.singer = track.singer;
      ui.source = track.source;
      ui.songId = track.id;
      ui.coverUrl = track.picUrl;
      rows.push(ui);
    }
    return rows;
  }

  /**
   * Maps the first daily track rows into “For you” song cards (max 8).
   *
   * @param songRows Daily track rows from the account provider.
   * @returns Song cards for the “For you” horizontal strip.
   */
  public static mapAccountTracksToForYouCards(songRows: RecommendPrivateSongUi[]): RecommendCardUi[] {
    const cards: RecommendCardUi[] = [];
    const count: number = Math.min(songRows.length, 8);
    for (let i = 0; i < count; i++) {
      const song = songRows[i];
      const card = new RecommendCardUi();
      card.title = song.title;
      card.playCountLabel = '每日推荐';
      card.paletteIndex = i % 5;
      card.backgroundUrl = song.coverUrl;
      card.songId = song.songId;
      card.source = song.source;
      card.singer = song.singer;
      cards.push(card);
    }
    return cards;
  }

  /**
   * Maps the first daily track rows into hero banner cards (max 3), used when
   * the “use login recommendations” switch replaces the toplist banners.
   *
   * @param songRows Daily track rows from the account provider.
   * @returns Hero banner cards backed by the daily track covers.
   */
  public static mapAccountTracksToHeroCards(songRows: RecommendPrivateSongUi[]): RecommendHeroCardUi[] {
    const banners: RecommendHeroCardUi[] = [];
    const count: number = Math.min(songRows.length, 3);
    for (let i = 0; i < count; i++) {
      const song = songRows[i];
      const banner = new RecommendHeroCardUi();
      banner.badge = '每日推荐';
      banner.title = song.title;
      banner.subLine = typeof song.singer === 'string' ? song.singer : '';
      banner.coverUrl = song.coverUrl;
      banner.songId = song.songId;
      banner.source = song.source;
      banners.push(banner);
    }
    return banners;
  }

  /** Maps a search song into a private-song UI row (dedupe via seen ids). */
  private static mapSearchSongToPrivateUi(song: LXSearchSong, index: number, seen: string[]): RecommendPrivateSongUi {
    const key: string = song.source + '_' + song.songId;
    const ui = new RecommendPrivateSongUi();
    ui.id = index;
    ui.title = song.name;
    ui.singer = song.singer;
    ui.source = song.source;
    ui.songId = song.songId;
    ui.coverUrl = song.img;
    if (seen.indexOf(key) < 0) {
      seen.push(key);
    }
    return ui;
  }

  /**
   * Loads QQ music toplist banners for the hero carousel.
   * @returns Hero banner UI models (badge/title = toplist name, image = toplist pic).
   */
  public static async loadTxBannersAsync(): Promise<RecommendHeroCardUi[]> {
    const topids: string[] = ['26', '27', '4'];
    const banners: RecommendHeroCardUi[] = [];
    const gradients: string[][] = [
      ['#152238', '#2E4A78'],
      ['#3D2F55', '#6B5A8C'],
      ['#5C2D2D', '#9A5C4A']
    ];
    for (let i: number = 0; i < topids.length; i++) {
      try {
        const info = await lxTxToplistInfo(topids[i]);
        if (info !== undefined && info.name.length > 0) {
          const ui = new RecommendHeroCardUi();
          ui.badge = info.name;
          ui.title = info.name;
          ui.subLine = 'QQ音乐每日更新';
          ui.coverUrl = info.pic;
          ui.topid = topids[i];
          ui.gradientStart = gradients[i][0];
          ui.gradientEnd = gradients[i][1];
          banners.push(ui);
        }
      } catch (_err) {
        // skip failed toplist
      }
    }
    return banners;
  }

  /**
   * Loads QQ music toplist cards for the "For you" strip.
   * @returns Card UI models.
   */
  public static async loadTxForYouAsync(): Promise<RecommendCardUi[]> {
    const topids: string[] = ['26', '27', '4', '5', '6', '16'];
    const cards: RecommendCardUi[] = [];
    for (let i: number = 0; i < topids.length; i++) {
      try {
        const info = await lxTxToplistInfo(topids[i]);
        if (info !== undefined && info.name.length > 0) {
          const ui = new RecommendCardUi();
          ui.title = info.name;
          ui.playCountLabel = 'QQ音乐';
          ui.paletteIndex = i % 5;
          ui.backgroundUrl = info.pic;
          ui.topid = topids[i];
          cards.push(ui);
        }
      } catch (_err) {
        // skip failed toplist
      }
    }
    return cards;
  }

  /**
   * Loads the Kugou top singer chart for the home singer list (QQ singer APIs are
   * offline); falls back to a static demo list when the network fails.
   * @param count How many singers to fetch.
   * @returns Singer UI rows.
   */
  public static async loadSingerListAsync(count: number = 30): Promise<RecommendSingerUi[]> {
    const singers = await lxKgSingerList(count);
    if (singers.length > 0) {
      const uiList: RecommendSingerUi[] = [];
      for (let i: number = 0; i < singers.length; i++) {
        const ui = new RecommendSingerUi();
        ui.singerId = singers[i].singerId;
        ui.name = singers[i].name;
        ui.picUrl = singers[i].pic;
        uiList.push(ui);
      }
      return uiList;
    }
    const demo: string[] = ['周杰伦', '林俊杰', '邓紫棋', '陈奕迅', '薛之谦', '李荣浩', '王菲', '张学友',
      '许嵩', '毛不易', '周深', '张杰'];
    const uiList: RecommendSingerUi[] = [];
    for (let i: number = 0; i < demo.length; i++) {
      const ui = new RecommendSingerUi();
      ui.singerId = '';
      ui.name = demo[i];
      ui.picUrl = '';
      uiList.push(ui);
    }
    return uiList;
  }

  /**
   * Loads the QQ music toplist overview for the home chart list using the same
   * per-toplist info API as the home banner (verified to return banner pics);
   * falls back to a static demo list when the network fails.
   * @returns Chart UI rows.
   */
  public static async loadChartListAsync(): Promise<RecommendChartUi[]> {
    const topids: string[] = ['26', '27', '4', '5', '6', '16', '17', '21'];
    const uiList: RecommendChartUi[] = [];
    for (let i: number = 0; i < topids.length; i++) {
      try {
        const info = await lxTxToplistInfo(topids[i]);
        if (info !== undefined && info.name.length > 0) {
          const ui = new RecommendChartUi();
          ui.topid = topids[i];
          ui.name = info.name;
          ui.picUrl = info.pic;
          uiList.push(ui);
        }
      } catch (_err) {
        // skip failed toplist
      }
    }
    if (uiList.length > 0) {
      return uiList;
    }
    const demo: string[][] = [
      ['26', 'QQ音乐巅峰榜·热歌'],
      ['27', 'QQ音乐巅峰榜·新歌'],
      ['4', '流行指数榜'],
      ['5', '港台地区榜'],
      ['6', '内地榜'],
      ['16', '欧美榜'],
      ['17', '日韩榜'],
      ['21', '韩国榜']
    ];
    for (let i: number = 0; i < demo.length; i++) {
      const ui = new RecommendChartUi();
      ui.topid = demo[i][0];
      ui.name = demo[i][1];
      ui.picUrl = '';
      uiList.push(ui);
    }
    return uiList;
  }

  /**
   * Fetches category tabs from the music DB and maps them to UI models.
   *
   * @returns Category chip tab models.
   */
  public static getCategoryTabs(): RecommendCategoryTabUi[] {
    return MusicDbApi.getInstance().getCategoryTabs().map((dto) => RecommendDataUtil.mapTabDtoToUi(dto));
  }

  /**
   * Sets pending play song id, opens the player UI, and bumps the intent version on {@link PlaybackIntentState}.
   *
   * @param songId - Song to play.
   * @param intent - Global playback intent state to mutate.
   */
  public static applyPlaybackIntentForSongId(songId: number, intent: PlaybackIntentState): void {
    intent.pendingPlaySongId = songId;
    intent.openPlayerUi = true;
    intent.requestVersion++;
  }

  /**
   * Maps a hero card API DTO to {@link RecommendHeroCardUi}.
   *
   * @param dto - Source hero card DTO.
   * @returns Populated UI model.
   */
  private static mapHeroDtoToUi(dto: HeroCardApiDto): RecommendHeroCardUi {
    const ui = new RecommendHeroCardUi();
    ui.badge = dto.badge;
    ui.title = dto.title;
    ui.subLine = dto.subLine;
    ui.coverImage = dto.coverImage;
    ui.gradientStart = dto.gradientStart;
    ui.gradientEnd = dto.gradientEnd;
    return ui;
  }

  /**
   * Maps a recommendation card API DTO to {@link RecommendCardUi}.
   *
   * @param dto - Source playlist/card DTO.
   * @returns Populated UI model.
   */
  private static mapRecommendCardDtoToUi(dto: RecommendCardApiDto): RecommendCardUi {
    const ui = new RecommendCardUi();
    ui.title = dto.title;
    ui.playCountLabel = dto.playCountLabel;
    ui.paletteIndex = dto.paletteIndex;
    ui.backgroundImage = dto.backgroundImage;
    return ui;
  }

  /**
   * Maps a song API DTO to {@link RecommendPrivateSongUi} for the private-songs strip.
   *
   * @param dto - Source song DTO.
   * @returns Populated private-song row model.
   */
  private static mapSongDtoToPrivateUi(dto: SongApiDto): RecommendPrivateSongUi {
    const ui = new RecommendPrivateSongUi();
    ui.id = dto.id;
    ui.title = dto.title;
    ui.singer = dto.singer;
    ui.cover = dto.label;
    return ui;
  }

  /**
   * Maps a tab API DTO to {@link RecommendCategoryTabUi}.
   *
   * @param dto - Source category tab DTO.
   * @returns Populated tab chip model.
   */
  private static mapTabDtoToUi(dto: TabApiDto): RecommendCategoryTabUi {
    const ui = new RecommendCategoryTabUi();
    ui.title = dto.title;
    ui.iconSelected = dto.iconSelected;
    ui.iconUnselected = dto.iconUnselected;
    return ui;
  }
}
