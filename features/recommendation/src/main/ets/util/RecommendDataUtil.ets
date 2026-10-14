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
  Logger,
  MusicDbApi,
  PlaybackIntentState,
  RecommendCardApiDto,
  SongApiDto,
  TabApiDto,
  getAppRuntime
} from 'musicbasic';
import { AccountService, getLeaderboardEntries, lxGetPicFallback, lxKgSingerList, lxTxSingerList, lxWySingerList, lxKwSingerList, lxMgSingerList, lxLeaderboard, lxTxToplist, lxTxToplistInfo, lxTxToplistList, LXLeaderboardEntry, LXSearchSong, PlatformAccount, PlatformTrackInfo, TxSinger } from 'player';
import { BoardData, MusicDataService, pickDedicatedBoardId, pickDedicatedBoardName, TrackData } from './MusicDataService';
import {
  RecommendCardUi,
  RecommendCategoryTabUi,
  RecommendChartUi,
  RecommendHeroCardUi,
  RecommendPrivateSongUi,
  RecommendSingerUi
} from '../model/RecommendUiModels';

/** 「新歌推荐」卡的取值标识（= 所在平台**新歌榜**）。 */
const HERO_FEATURE_NEW_SONGS: string = 'newSongs';
/** 「精选推荐」卡的取值标识（= 所在平台**热歌榜**）。 */
const HERO_FEATURE_PICKED: string = 'picked';

/**
 * 首页「新歌推荐 / 精选推荐」两张卡各自取哪张榜单。
 *
 * 需求（用户原话）：「新歌推荐和精选推荐改成对应榜单（比如当前设置首页推荐为 QQ，
 * 就用 QQ 的新歌榜和热歌榜）」⇒ **二者都跟着「首页来源平台」走**：
 *   - `newSongs` → 该平台的**新歌榜**；`picked` → 该平台的**热歌榜**。
 *
 * ★ 榜单 id 用的是工程里**现成的那张表** —— `player` 的 `getLeaderboardEntries()`
 *   （`LXMusicSDK.ets` 里 `{ id: 'tx_27', name: 'QQ音乐新歌榜' }` 那一份），
 *   它同时被 `lxLeaderboard()`（卡片四宫格取歌）与 `fetchBoardSongs()`
 *   （榜单详情页取歌）消费 ⇒ 卡片上看到的和点进去的是**同一份数据**，不需要新造接口。
 *   返回的是**带平台前缀的完整 id**（`tx_27`），正是 `fetchBoardSongs` 需要的形态。
 */
// ⚠️ ArkTS 禁止**嵌套的无类型对象字面量**（`arkts-no-untyped-obj-literals`，实测报在这里）⇒
//    用「`feature|source` 复合键」的**扁平表**，一层字面量、类型明确，编译才过。
// ⚠️ 每一个 id 都**必须在工程现成的榜单表里查得到**（`features/player/src/main/ets/source/LXMusicSDK.ets`
//    的 `getLeaderboardEntries()`，实测行 159~167）。上一版有人写了 `kg_51341`（工程里根本没有）
//    和把 `kg_6666`（酷狗**飙升榜**）当热歌榜 ⇒ 已改正：
//      新歌榜：tx_27(QQ) / kw_17(酷我) / wy_1(网易云) / mg_1(咪咕)
//      热歌榜：tx_26(QQ) / kw_16(酷我) / wy_0(网易云) / mg_2(咪咕)
//    ⚠️ **酷狗在这张表里没有"新歌榜/热歌榜"**：只有 `kg_8888`(TOP500) 与 `kg_6666`(飙升榜)。
//       这里按"性质最接近"降级（新歌→飙升榜、热歌→TOP500），**并在注释里标明这是降级**，
//       而不是伪造一个不存在的榜单 id（伪造的 id 会让卡片取歌失败、点进去是空页）。
const FEATURE_BOARD_IDS: Record<string, string> = {
  'newSongs|tx': 'tx_27',
  'newSongs|kg': 'kg_6666', // 降级：酷狗无新歌榜，用飙升榜（新歌性质最接近）
  'newSongs|kw': 'kw_17',
  'newSongs|wy': 'wy_1',
  'newSongs|mg': 'mg_1',
  'picked|tx': 'tx_26',
  'picked|kg': 'kg_8888', // 降级：酷狗无热歌榜，用 TOP500（热门性质最接近）
  'picked|kw': 'kw_16',
  'picked|wy': 'wy_0',
  'picked|mg': 'mg_2'
};

/**
 * 取「某张卡在某平台」要用的榜单 id（带平台前缀）。
 *
 * ⚠️ 返回**空串**表示这个平台没有对应榜单 ⇒ 调用方必须自己能兜住（不伪造数据）。
 * @param feature 卡片标识（`newSongs` / `picked`）。
 * @param svcSource 平台代号（tx / kg / kw / wy / mg）。
 * @returns 榜单 id；无对应榜单返回空串。
 */
export function pickFeatureBoardId(feature: string, svcSource: string): string {
  const id: string | undefined = FEATURE_BOARD_IDS[feature + '|' + svcSource];
  return id === undefined ? '' : id;
}

/**
 * @param feature 卡片标识（`newSongs` / `picked`）。
 * @returns true = 这张卡是「跟着首页平台走的榜单卡」。
 */
export function isFeatureBoardCard(feature: string): boolean {
  return feature === HERO_FEATURE_NEW_SONGS || feature === HERO_FEATURE_PICKED;
}

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
 * 首页歌曲列表的加载结果。
 *
 * 为什么要把「榜单名 / 是否降级」一起带出来：首页必须在区块里**写清数据来源**，
 * 否则用户切了「首页来源平台」却看不出首页到底变没变（用户反馈："首页似乎都没变"）。
 */
export class HomeSongLoadResult {
  /** 歌曲行（可能为空）。 */
  public songs: RecommendPrivateSongUi[] = [];
  /** 实际命中的**指定榜单**名（如「新歌榜」）；空串表示没走到指定榜单。 */
  public boardName: string = '';
  /** true = 指定榜单取不到、用该平台其它榜单兜底（内容是真的，只是不是首选榜单）。 */
  public degraded: boolean = false;
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
    const result: HomeSongLoadResult = await RecommendDataUtil.loadHomeSongsAsync(source, targetCount);
    return result.songs;
  }

  /**
   * 首页歌曲 + **这次到底用了哪个榜单 / 有没有降级**。
   *
   * 首页要在「精选推荐」标题下把数据来源写出来（`来自 酷狗音乐 · 飙升榜`），
   * 否则用户切了平台却看不出首页到底变没变（用户反馈的原话就是"首页似乎都没变"）。
   * 拿不到内容时也要说清楚原因，**不伪造数据**。
   *
   * @param source Home source id ('qq'|'kg'|'wy')。
   * @param targetCount 需要的行数。
   * @returns 歌曲行 + 榜单名 + 是否降级。
   */
  public static async loadHomeSongsAsync(source: string, targetCount: number = 12): Promise<HomeSongLoadResult> {
    const svcSource: string = RecommendDataUtil.mapHomeSource(source);
    const merged: RecommendPrivateSongUi[] = [];
    const seen: string[] = [];
    let boards: BoardData[] = [];
    const dedicatedName: string = pickDedicatedBoardName(svcSource);
    let usedDedicatedBoard: boolean = false;

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
        usedDedicatedBoard = merged.length > 0;
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
    const result = new HomeSongLoadResult();
    result.songs = merged;
    result.boardName = usedDedicatedBoard ? dedicatedName : '';
    result.degraded = !usedDedicatedBoard && merged.length > 0;
    return result;
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
   * 「新歌推荐 / 精选推荐」两张卡所在平台的榜单**名**（卡上不显示，只用于日志与详情页标题）。
   *
   * 名字取自 `player` 那张现成的榜单表（`getLeaderboardEntries()`），**不自己拼字符串** ——
   * 详情页标题与榜单列表里的名字必须逐字一致，否则用户会以为点错了榜。
   * @param feature 卡片标识（`newSongs` / `picked`）。
   * @param svcSource 平台代号（tx / kg / kw / wy / mg）。
   * @returns 榜单名；找不到返回空串。
   */
  public static pickFeatureBoardName(feature: string, svcSource: string): string {
    const id: string = pickFeatureBoardId(feature, svcSource);
    if (id.length === 0) {
      return '';
    }
    const entries: LXLeaderboardEntry[] = getLeaderboardEntries();
    for (let i: number = 0; i < entries.length; i++) {
      if (entries[i].id === id) {
        return entries[i].name;
      }
    }
    return '';
  }

  /**
   * 「新歌推荐 / 精选推荐」两张卡各自取所属平台的榜单歌曲（只取前几首，给四宫格拼图用）。
   *
   * 数据通道**完全复用现有那条**：
   *   - 卡片拼图 → `lxLeaderboard(source_boardId, 1, limit)`（= `fetchBoardSongs` 用的同一个函数）；
   *   - 点进去的详情页 → `ToplistRouteParam.boardSource/boardId` → `PlaylistDetailPage`
   *     → `player.fetchBoardSongs` ⇒ **卡片与详情页同源**，不需要新增接口、也不需要
   *     `AppStorage['dailyThirtySongs']` 那条 `sectionType='daily30'` 中转。
   *
   * ⚠️ 取不到（网络失败 / 该平台没有这张榜）时**返回空数组**，由调用方决定回落 ——
   *    这里绝不伪造歌单内容。
   * @param feature 卡片标识（`newSongs` / `picked`）。
   * @param svcSource 平台代号（tx / kg / kw / wy / mg）。
   * @param limit 需要的条数（拼四宫格只需 4）。
   * @returns 歌曲行；失败或平台无此榜返回空数组。
   */
  public static async loadFeatureBoardSongsAsync(feature: string, svcSource: string,
    limit: number = 4): Promise<RecommendPrivateSongUi[]> {
    const boardId: string = pickFeatureBoardId(feature, svcSource);
    if (boardId.length === 0) {
      Logger.info('RzdHomeBoard', `feature board missing feature=${feature} source=${svcSource}`);
      return [];
    }
    const rows: RecommendPrivateSongUi[] = [];
    try {
      const res = await lxLeaderboard(boardId, 1, limit);
      const seen: string[] = [];
      for (let i: number = 0; i < res.list.length && rows.length < limit; i++) {
        rows.push(RecommendDataUtil.mapSearchSongToPrivateUi(res.list[i], i, seen));
      }
    } catch (_err) {
      Logger.warn('RzdHomeBoard', `feature board load failed feature=${feature} board=${boardId}`);
      return [];
    }
    await RecommendDataUtil.fillSongCovers(rows);
    Logger.info('RzdHomeBoard', `feature board loaded feature=${feature} board=${boardId} songs=${rows.length}`);
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
   * @param dailyCovers **拼图卡**（每日30首 / 新歌推荐 / 精选推荐）背景用的 4 张封面（可为空）。
   * @param dailyTitles 同上 4 张封面取不到时的占位歌名（可为空）。
   * @param listenNowTitle 「现在就听」卡固定显示的歌名（空则用池里第一首）。
   * @param listenNowCover 「现在就听」卡固定使用的封面（空则用列表首张可用封面）。
   * @param boardCovers **榜单拼图卡**（新歌推荐 / 精选推荐）各自的 4 张封面，键是卡片标识
   *   （`newSongs` / `picked`）。★ 这两张卡自 2026-10-15 起**不再是"首页推荐列表"**，
   *   而是**各自所属平台的榜单**（新歌榜 / 热歌榜）—— 封面必须来自**各自的榜单**，
   *   不能再拿首页列表前 4 首去拼（那样卡面与点进去的内容对不上）。
   *   取不到时**回落**成首页列表那 4 张（旧观感），不空着。
   * @returns 5 张功能入口卡片。
   */
  public static getFeatureHeroCards(songNames: string[], songCovers: string[] = [], dailyCovers: string[] = [],
    dailyTitles: string[] = [], listenNowTitle: string = '',
    listenNowCover: string = '',
    boardCovers: Record<string, string[]> = {}): RecommendHeroCardUi[] {
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
      // ★ 2026-10-15（用户纠正）：「新歌推荐」「精选推荐」两张卡**和「每日30首」同款** ——
      //   四张封面拼一块 + 点开进歌单，**只改文字** ⇒ 它们也要拿到那 4 张封面。
      //   （原来只有 `daily30` 拿得到，另两张的卡面因此只有一首歌的封面。）
      // ★ 2026-10-15（第二次纠正）：这两张卡改成**各自平台的榜单**（新歌榜 / 热歌榜）
      //   ⇒ 拼图封面优先取**各自榜单**的那 4 张（`boardCovers[spec.route]`），
      //     取不到（接口失败 / 该平台没有这张榜）才回落成首页列表那 4 张。
      const isCollageRoute: boolean =
        spec.route === 'daily30' || spec.route === 'newSongs' || spec.route === 'picked';
      const featureCovers: string[] | undefined = boardCovers[spec.route];
      if (isCollageRoute && featureCovers !== undefined && featureCovers.length > 0) {
        banner.dailyCovers = featureCovers;
        banner.dailyTitles = [];
      } else {
        banner.dailyCovers = isCollageRoute ? dailyCovers : [];
        banner.dailyTitles = isCollageRoute ? dailyTitles : [];
      }
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
  public static async loadSingerListAsync(count: number = 30,
    homeSource: string = ''): Promise<RecommendSingerUi[]> {
    const svc: string = RecommendDataUtil.mapHomeSource(homeSource.length > 0 ? homeSource : 'kg');
    const label: string = MusicDataService.sourceName(svc) + '歌手榜';
    let singers: TxSinger[] = [];
    try {
      if (svc === 'tx') {
        singers = await lxTxSingerList(count);
      } else if (svc === 'wy') {
        singers = await lxWySingerList(count);
      } else if (svc === 'kw') {
        singers = await lxKwSingerList(count);
      } else if (svc === 'mg') {
        singers = await lxMgSingerList(count);
      } else {
        singers = await lxKgSingerList(count);
      }
    } catch (_e) {
      singers = [];
    }
    // 主平台失败时逐个回退，避免空白
    if (singers.length === 0) {
      try {
        if (svc !== 'kg') {
          singers = await lxKgSingerList(count);
        }
      } catch (_e2) {
      }
    }
    if (singers.length === 0 && svc !== 'tx') {
      try {
        singers = await lxTxSingerList(count);
      } catch (_e3) {
      }
    }
    if (singers.length > 0) {
      const uiList: RecommendSingerUi[] = [];
      for (let i: number = 0; i < singers.length; i++) {
        const ui = new RecommendSingerUi();
        ui.singerId = singers[i].singerId;
        ui.name = singers[i].name;
        ui.picUrl = singers[i].pic;
        ui.sourceLabel = label;
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
      ui.sourceLabel = label;
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