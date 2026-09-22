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
import { AccountService, getLeaderboardEntries, lxGetPicFallback, lxKgSingerList, lxLeaderboard, lxTxToplist, lxTxToplistInfo, lxTxToplistList, LXSearchSong, PlatformAccount, PlatformTrackInfo } from 'player';
import { BoardData, MusicDataService, pickDedicatedBoardId, TrackData } from './MusicDataService';
import {
  RecommendCardUi,
  RecommendCategoryTabUi,
  RecommendChartUi,
  RecommendHeroCardUi,
  RecommendPrivateSongUi,
  RecommendSingerUi
} from '../model/RecommendUiModels';

/** 首页顶部功能入口卡的定义（角标 / 标题 / 配图 / 点击去向）。 */
interface RecommendHeroSpec {
  /** 左下角小角标。 */
  badge: string;
  /** 卡片主标题。 */
  title: string;
  /** 卡片配图（打包内资源）。 */
  image: Resource;
  /** 点击去向标识：listenNow / daily30 / newSongs / heartMode / picked。 */
  route: string;
}

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

    // 优先用「指定榜单」：未登录时首页精选推荐固定拉
    // QQ 新歌榜 / 酷狗飙升榜 / 网易飙升榜（见 MusicDataService.pickDedicatedBoardId）。
    // 这样出来的歌内容稳定、封面也齐，不需要靠多榜单轮询去凑。
    const dedicatedId: string = pickDedicatedBoardId(svcSource);
    if (dedicatedId.length > 0) {
      try {
        const tracks: TrackData[] = await MusicDataService.tracks(svcSource, dedicatedId);
        for (let i: number = 0; i < tracks.length && merged.length < targetCount; i++) {
          const track = tracks[i];
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
      } catch (_err) {
        // 失败则落到下面的多榜单兜底
      }
    }

    if (merged.length === 0) {
      try {
        boards = await MusicDataService.boardsWithCovers(svcSource);
      } catch (_err) {
        boards = [];
      }
      if (boards.length === 0) {
        try {
          boards = MusicDataService.boards(svcSource);
        } catch (_err) {
          boards = [];
        }
      }
      // 取前几个榜单的歌曲：**并行**发请求，避免任何一个榜单卡住拖住整块首页。
      const probeCount: number = Math.min(boards.length, 4);
      const tasks: Promise<TrackData[]>[] = [];
      for (let i: number = 0; i < probeCount; i++) {
        const boardId: string = boards[i].id;
        tasks.push(MusicDataService.tracks(svcSource, boardId).catch((): TrackData[] => []));
      }
      const settled: TrackData[][] = await Promise.all(tasks);
      for (let i: number = 0; i < settled.length && merged.length < targetCount; i++) {
        const tracks: TrackData[] = settled[i];
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
    }
    // ⚠️ 补封面：`MusicDataService.tracks` 走的国内接口大多**不返回封面**
    //    （酷我 kbangserver 的 musiclist 里就没有图），所以首页歌曲行会整排空图标。
    //    榜单页有封面是因为 PlaylistDetailSongListSection 自己会补，首页这边原来没有。
    await RecommendDataUtil.fillSongCovers(merged);
    return merged;
  }

  /**
   * 给缺封面的歌曲行补图并**返回新数组**（供 UI 重新绑定）。
   *
   * @param rows 歌曲行（原数组被原地修改，返回的也是同一个数组引用）。
   * @returns 补过封面的行数组。
   */
  public static async fillCovers(rows: RecommendPrivateSongUi[]): Promise<RecommendPrivateSongUi[]> {
    await RecommendDataUtil.fillSongCovers(rows);
    return rows;
  }

  /**
   * 给缺封面的歌曲行补图（并发受限，避免把音源引擎打满）。
   *
   * @param rows 待补的歌曲行（原地修改）。
   */
  private static async fillSongCovers(rows: RecommendPrivateSongUi[]): Promise<void> {
    const pending: RecommendPrivateSongUi[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      if (rows[i].coverUrl.length === 0 && rows[i].songId.length > 0 && rows[i].source.length > 0) {
        pending.push(rows[i]);
      }
    }
    if (pending.length === 0) {
      return;
    }
    let cursor: number = 0;
    const worker = async (): Promise<void> => {
      while (cursor < pending.length) {
        const row: RecommendPrivateSongUi = pending[cursor];
        cursor = cursor + 1;
        try {
          const pic: string = await lxGetPicFallback(row.source, row.songId, '',
            typeof row.title === 'string' ? row.title : '', typeof row.singer === 'string' ? row.singer : '');
          if (pic.length > 0) {
            row.coverUrl = pic;
          }
        } catch (_err) {
          // 补不到就留空，行上会显示占位图标
        }
      }
    };
    const slots: number = Math.min(3, pending.length);
    const tasks: Promise<void>[] = [];
    for (let i: number = 0; i < slots; i++) {
      tasks.push(worker());
    }
    await Promise.all(tasks);
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
   * 首页顶部大卡片：**照 MusicHome 的 5 张功能入口卡**。
   *
   * MusicHome 首页顶部那一排不是歌曲卡片，而是固定的功能入口（见其
   * `MusicMemoryStore.buildRecommendFeed()` 的 `appendHeroRow`）：
   *
   * | 角标 | 标题 | 图 |
   * | --- | --- | --- |
   * | Music FM | 现在就听 | **代码绘制**（取色底 + 梯形侧翼 + 该歌封面） |
   * | 每日推荐 | 每日30首 | **代码绘制**（前 4 首封面拼 2×2 + 当天日期） |
   * | NEW | 新歌推荐 | 该歌封面 |
   * | MODE | 心动模式 | 该歌封面 |
   * | PICK | 精选推荐 | 该歌封面 |
   *
   * ⚠️ **前两张是代码绘制的，不走这里给图**（用户明确要求不要改这两张）；
   *    只有后三张改成用歌曲封面。原来五张各自对应一张打包内配图
   *    `ic_recommend1..5.png`，那 5 张图已删除（源工程两份共约 1.3MB），
   *    删图时记得同步 `common/musicbasic` 里 `MusicMemoryStore` 的引用。
   *
   * 它们没有 `songId` / `boardId`，所以点击行为由 `HeroBannerSection` 分发。
   *
   * 副标题（卡片下方那行）：MusicHome 用的是品牌行，这里按需求**每张卡各自随机抽一首**
   * 列表里的歌名（不是五张都显示同一首）；`songNames` 为空时回落到品牌行。
   *
   * 另外「每日30首」这张卡是**实时**的：
   *   - 大号日期用当天真实的月/日（原来写死成 9月30日）；
   *   - 背景由该列表前 4 首的封面拼成 2×2（见 `HeroBannerSection.DailyCollage`），
   *     所以把前 4 首的封面地址一并带出去。
   *
   * @param songNames 可用于副标题的歌名池（一般就是首页歌曲列表，已洗牌）。
   * @param songCovers 与 `songNames` **同下标**的封面池（卡片封面直接用它们）。
   * @param dailyCovers 每日30首背景用的 4 张封面（可为空）。
   * @param dailyTitles 每日30首背景用的 4 首歌名（可为空，取不到封面时占位用）。
   * @param listenNowTitle 「现在就听」卡固定显示的歌名（空则用池里第一首）。
   * @param listenNowCover 「现在就听」卡固定使用的封面（空则用列表首张可用封面）。
   * @returns 5 张功能入口卡片。
   */
  public static getFeatureHeroCards(songNames: string[], songCovers: string[] = [], dailyCovers: string[] = [],
    dailyTitles: string[] = [], listenNowTitle: string = '',
    listenNowCover: string = ''): RecommendHeroCardUi[] {
    // 只需 badge / title / route —— 图不再走打包资源
    const specs: RecommendHeroSpec[] = [
      { badge: 'Music FM', title: '现在就听', image: $r('app.media.ic_avatar1'), route: 'listenNow' },
      { badge: '每日推荐', title: '每日30首', image: $r('app.media.ic_avatar1'), route: 'daily30' },
      { badge: 'NEW', title: '新歌推荐', image: $r('app.media.ic_avatar1'), route: 'newSongs' },
      { badge: 'MODE', title: '心动模式', image: $r('app.media.ic_avatar1'), route: 'heartMode' },
      { badge: 'PICK', title: '精选推荐', image: $r('app.media.ic_avatar1'), route: 'picked' }
    ];
    const banners: RecommendHeroCardUi[] = [];
    for (let i: number = 0; i < specs.length; i++) {
      const spec: RecommendHeroSpec = specs[i];
      const banner = new RecommendHeroCardUi();
      banner.badge = spec.badge;
      banner.title = spec.title;
      // ★ 按**下标**取歌名，不再每张独立随机。
      //   独立随机会出现"五张卡都抽到同一首"（随机本来就允许重复），
      //   调用方已经把歌名池洗好牌，这里顺序取即可保证 5 张互不相同；
      //   池子不足时才用取模循环。
      const slot: number = songNames.length > 0 ? i % songNames.length : -1;
      const pick: string = slot >= 0 ? songNames[slot] : 'HUAWEI music';
      banner.subLine = pick;
      // ★ **后三张**（新歌推荐 / 心动模式 / 精选推荐）用歌曲封面：它们本来就是"某首歌"
      //   的入口，封面直接用**下方那首歌自己的封面**（与歌名同下标洗过牌）。
      // ★ **前两张在手机版卡面上不动**（用户明确要求）：
      //   - 现在就听 —— 由 `HeroBannerSection.NowPlayingCard` 自己绘制
      //     （取色底 + 两侧梯形侧翼 + 中间封面），封面另由 `listenNowCover` 定稿；
      //   - 每日30首 —— 由 `DailyCollage` 用前 4 首封面拼四宫格 + 大号日期。
      //   这两条渲染路径都**不读** `coverUrl`，所以这里照样填上不影响手机观感；
      //   而平板/手表的简化卡面（`PanelHeroBannerSection` / `WearableHome`）是直接
      //   取 `coverUrl ?? coverImage` 的 —— 填上它们才不会回落成占位图。
      banner.coverUrl = slot >= 0 && slot < songCovers.length ? songCovers[slot] : '';
      banner.coverImage = spec.image;
      banner.source = '';
      banner.songId = '';
      banner.boardId = '';
      banner.topid = '';
      banner.feature = spec.route;
      banner.dailyCovers = spec.route === 'daily30' ? dailyCovers : [];
      banner.dailyTitles = spec.route === 'daily30' ? dailyTitles : [];
      if (spec.route === 'listenNow') {
        // 「现在就听」卡展示的就是它要播的那一首（与下方歌名一致）
        if (listenNowCover.length > 0) {
          banner.coverUrl = listenNowCover;
        }
        if (listenNowTitle.length > 0) {
          banner.subLine = listenNowTitle;
        }
      }
      banners.push(banner);
    }
    return banners;
  }

  /**
   * 由歌曲行生成首页顶部大卡片（旧入口，保留给"用登录账号推荐"的路径）。
   *
   * @param songRows 歌曲行。
   * @returns Hero 卡片 UI 模型。
   */
  public static mapSongsToHeroCards(songRows: RecommendPrivateSongUi[], count: number = 3): RecommendHeroCardUi[] {
    const banners: RecommendHeroCardUi[] = [];
    const limit: number = Math.min(songRows.length, count);
    for (let i: number = 0; i < limit; i++) {
      const song = songRows[i];
      const banner = new RecommendHeroCardUi();
      banner.badge = '每日推荐';
      banner.title = typeof song.title === 'string' ? song.title : '';
      banner.subLine = typeof song.singer === 'string' ? song.singer : '';
      banner.coverUrl = song.coverUrl;
      banner.songId = song.songId;
      banner.source = song.source;
      banners.push(banner);
    }
    return banners;
  }

  /**
   * Maps the first daily track rows into hero banner cards (max 3), used when
   * the “use login recommendations” switch replaces the toplist banners.
   *
   * @param songRows Daily track rows from the account provider.
   * @returns Hero banner cards backed by the daily track covers.
   */
  public static mapAccountTracksToHeroCards(songRows: RecommendPrivateSongUi[]): RecommendHeroCardUi[] {
    return RecommendDataUtil.mapSongsToHeroCards(songRows, 3);
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
