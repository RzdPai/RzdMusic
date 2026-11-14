/*
 * 「现在就听」/首页的自建推荐引擎（未登录也能用）。
 *
 * ## 甲方 2026-10-24 的口径
 * 「自己做未登录状态下的推荐算法…就是歌单广场那一堆歌单，分类我试了都能用：
 *   纯随机选几个分类，分类里面随机几个歌单，每个歌单里面随机选几首歌。
 *   然后根据用户点的歌曲，增加这首歌所在分类被推荐的概率。」
 * 另外 ⑦ 的三个模式（常规 / 熟悉 / 探索）影响"听过的分类"的权重。
 *
 * ## 取数（**全是仓库现成接口**，不新增网络层）
 * - 分类：`MusicDataService.categories(source)` → `CategoryGroup[]`
 * - 分类下歌单：`MusicDataService.playlists(source, sortId?, categoryId, page)` → `PlaylistPage.list`
 * - 歌单里的歌：`PlaylistSearchApi.getPlaylistDetail(source, id)` → `SearchPlaylistSong[]`
 *
 * ## 算法
 * 1. 把分类摊平；按**播放权重**算每个分类的抽样概率：
 *    - 常规：`1 + plays * 0.5`
 *    - 熟悉：`1 + plays * 1.5`（偏向听过的分类）
 *    - 探索：`1 / (1 + plays * 0.8)`（听过的少给，逼出新口味）
 * 2. 加权随机抽 N 个**不重复**分类；
 * 3. 每个分类取第 1 页歌单，随机挑 2 张；
 * 4. 每张歌单随机挑 2 首；
 * 5. 打乱后取前 `want` 首。
 *
 * 每一步都 `try/catch` 单点降级：某个分类/歌单挂了就跳过，不影响整体出歌。
 *
 * 排查日志：`hdc shell hilog | findstr RzdFeedRec`。
 */

import { MusicDataService } from './MusicDataService';
import type { CategoryGroup, CategoryOption, PlaylistData } from './MusicDataService';
import { PlaylistSearchApi } from 'player';
import { SearchPlaylistSong } from 'player/src/main/ets/shareplaylistsearch/PlaylistSearchTypes';
import { Logger } from 'musicbasic';

const LOG_TAG: string = 'RzdFeedRec';

/** 一条推荐结果：歌 + 它来自哪个分类（分类用于回写权重）。 */
export class FeedRecommendPick {
  song: SearchPlaylistSong = new SearchPlaylistSong();
  /** 分类 id（歌单广场的 tag id）。 */
  categoryId: string = '';
  /** 分类名（落库/日志用，便于人工核对）。 */
  categoryName: string = '';
}

/** 一次取样的配置。 */
const REC_PICK_CATEGORIES: number = 4;
/** 每个分类挑几张歌单。 */
const REC_PLAYLISTS_PER_CATEGORY: number = 2;
/** 每张歌单挑几首歌。 */
const REC_SONGS_PER_PLAYLIST: number = 2;

/** `Math.random()` 版 Fisher–Yates（不改原数组）。 */
function shuffled<T>(list: T[]): T[] {
  const copy: T[] = list.slice();
  for (let i: number = copy.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const tmp: T = copy[i];
    copy[i] = copy[j];
    copy[j] = tmp;
  }
  return copy;
}

export class FeedRecommendEngine {
  /**
   * 按分类权重挑一个（加权随机）。权重全 0 时退化成等概率。
   * @param items 候选分类
   * @param weightOf 取权重的函数（调用方给，避免这里关心模式）
   * @returns 选中的分类下标；空数组返回 -1。
   */
  private static pickWeighted(items: CategoryOption[], weightOf: (c: CategoryOption) => number): number {
    if (items.length === 0) {
      return -1;
    }
    let total: number = 0;
    const weights: number[] = [];
    for (let i: number = 0; i < items.length; i++) {
      const w: number = Math.max(0, weightOf(items[i]));
      weights.push(w);
      total += w;
    }
    if (!(total > 0)) {
      return Math.floor(Math.random() * items.length);
    }
    let r: number = Math.random() * total;
    for (let i: number = 0; i < items.length; i++) {
      r -= weights[i];
      if (r <= 0) {
        return i;
      }
    }
    return items.length - 1;
  }

  /**
   * 按模式给出某分类的抽样权重。
   * @param plays 该分类被点过的次数（来自 `MusicStoreService.getFeedCategoryPlays()`）
   * @param mode 0 = 常规 / 1 = 熟悉 / 2 = 探索
   */
  static categoryWeight(plays: number, mode: number): number {
    const p: number = Math.max(0, plays);
    if (mode === 1) {
      return 1 + p * 1.5;
    }
    if (mode === 2) {
      return 1 / (1 + p * 0.8);
    }
    return 1 + p * 0.5;
  }

  /**
   * 组一份推荐列表。
   * @param source 音源（'tx' / 'wy' / 'kw' / 'kg' / 'mg'）
   * @param mode 0 = 常规 / 1 = 熟悉 / 2 = 探索
   * @param want 想要几首（不足就返回实际取到的）
   * @param playsByCategory 分类 id → 点过的次数
   * @returns 推荐结果（可能为空：该音源不支持广场 / 网络失败）
   */
  static async build(source: string, mode: number, want: number,
    playsByCategory: Record<string, number>): Promise<FeedRecommendPick[]> {
    if (!MusicDataService.plazaSupported(source) || want <= 0) {
      Logger.info(LOG_TAG, `skip src=${source} plaza=${MusicDataService.plazaSupported(source)}`);
      return [];
    }

    // ① 分类摊平
    let groups: CategoryGroup[] = [];
    try {
      groups = await MusicDataService.categories(source);
    } catch (err) {
      Logger.warn(LOG_TAG, `categories fail err=${(err as Error).message ?? ''}`);
      return [];
    }
    const categories: CategoryOption[] = [];
    for (let i: number = 0; i < groups.length; i++) {
      for (let k: number = 0; k < groups[i].items.length; k++) {
        const item: CategoryOption = groups[i].items[k];
        // 跳过"全部/推荐"这类聚合分类：它下面的歌单太杂，不利于按分类加权
        if (item.id.length > 0 && item.name !== '全部' && item.name !== '推荐') {
          categories.push(item);
        }
      }
    }
    if (categories.length === 0) {
      Logger.warn(LOG_TAG, `no categories src=${source}`);
      return [];
    }

    // ② 加权随机抽不重复分类
    const pool: CategoryOption[] = categories.slice();
    const picked: CategoryOption[] = [];
    const wantCategories: number = Math.min(REC_PICK_CATEGORIES, pool.length);
    while (picked.length < wantCategories && pool.length > 0) {
      const idx: number = FeedRecommendEngine.pickWeighted(pool,
        (c: CategoryOption): number => FeedRecommendEngine.categoryWeight(playsByCategory[c.id] ?? 0, mode));
      if (idx < 0) {
        break;
      }
      picked.push(pool[idx]);
      pool.splice(idx, 1);
    }
    Logger.info(LOG_TAG, `picked cats=${picked.map((c: CategoryOption): string => c.name).join('/')}`);

    // ③④ 分类 → 歌单 → 歌
    const out: FeedRecommendPick[] = [];
    for (let i: number = 0; i < picked.length && out.length < want; i++) {
      const category: CategoryOption = picked[i];
      let playlistList: PlaylistData[] = [];
      try {
        const page = await MusicDataService.playlists(source, undefined, category.id, 1);
        playlistList = page.list;
      } catch (err) {
        Logger.warn(LOG_TAG, `playlists fail cat=${category.name} err=${(err as Error).message ?? ''}`);
        continue;
      }
      if (playlistList.length === 0) {
        continue;
      }
      const playlists: PlaylistData[] = shuffled(playlistList).slice(0, REC_PLAYLISTS_PER_CATEGORY);
      for (let k: number = 0; k < playlists.length && out.length < want; k++) {
        const pl: PlaylistData = playlists[k];
        let songs: SearchPlaylistSong[] = [];
        try {
          songs = await PlaylistSearchApi.getPlaylistDetail(source, pl.id);
        } catch (err) {
          Logger.warn(LOG_TAG, `songs fail pl=${pl.id} err=${(err as Error).message ?? ''}`);
          continue;
        }
        if (songs.length === 0) {
          continue;
        }
        const take: SearchPlaylistSong[] = shuffled(songs).slice(0, REC_SONGS_PER_PLAYLIST);
        for (let s: number = 0; s < take.length && out.length < want; s++) {
          const pick = new FeedRecommendPick();
          pick.song = take[s];
          pick.categoryId = category.id;
          pick.categoryName = category.name;
          out.push(pick);
        }
      }
    }
    const finalList: FeedRecommendPick[] = shuffled(out);
    Logger.info(LOG_TAG, `built src=${source} mode=${mode} want=${want} got=${finalList.length}`);
    return finalList;
  }
}
