/*
 * 平台搜索路由（2026-11-09）。
 *
 * ★ 平台模型（用户 2026-11-09 定稿）：
 *   **一个来源 = 一个平台条目**。洛雪六平台是内置接口；每个 MusicFree 插件
 *   自己也是一行（名字跟随源名：小蜗 / 元力KW）。所以「酷我」可能同时有两行，
 *   用户勾哪行就搜哪行，两个都勾就是共存（结果里各自带自己的平台 id）。
 *
 * 这一层是**唯一的分派点**：
 *   platformId → 洛雪内置接口 / MusicFree 插件。
 * 搜索页、歌单广场、批量下载都只调这里，不再各自判断「这个平台该谁去搜」。
 */

import { LXUserApiInfo } from './Interface';
import { LXSearchResult, LXSearchSong, lxSearch } from './LXMusicSDK';
import { PlaylistSearchApi } from '../shareplaylistsearch/PlaylistSearchApi';
import { SearchPlaylistInfo } from '../shareplaylistsearch/PlaylistSearchTypes';
import { mfRecommendGroups, mfSearch, mfSearchSheets, MfTopListGroup, mfTopLists, musicFreeApisForPlatform } from './MusicFreeAdapter';
import { platformRegistry } from '../util/PlatformRegistry';
import { lxSourceManager } from './LXSourceManager';
import { isMfPlatformId } from '../util/SourceDeclaredInfo';

/** 搜索/广场可用的平台清单：用户在「平台管理」里勾选的平台，按用户拖动顺序。 */
export function enabledPlatformIds(): string[] {
  const apis: LXUserApiInfo[] = lxSourceManager.getApiList();
  return platformRegistry.enabledIds(apis);
}

/** 该平台是 MusicFree 来源时，取出对应的插件（一插件一平台）。 */
function mfApiOf(platformId: string): LXUserApiInfo | undefined {
  if (!isMfPlatformId(platformId)) {
    return undefined;
  }
  const matched: LXUserApiInfo[] =
    musicFreeApisForPlatform(platformId, lxSourceManager.getApiList());
  return matched.length > 0 ? matched[0] : undefined;
}

/**
 * 搜一个平台。
 *
 * - 洛雪六平台：走内置 HTTP 接口（与以前完全一致）；
 * - MusicFree 平台：只问它对应的那一个插件，不再向 LX 引擎发无意义请求。
 */
export async function searchPlatformSongs(platformId: string, query: string, page: number,
  limit: number): Promise<LXSearchResult> {
  const empty: LXSearchResult = { list: [], total: 0, limit: limit, source: platformId };
  if (isMfPlatformId(platformId)) {
    const api: LXUserApiInfo | undefined = mfApiOf(platformId);
    if (api === undefined) {
      return empty;
    }
    return await mfSearch(api, query, page, limit);
  }
  if (!platformRegistry.isBuiltin(platformId)) {
    return empty;
  }
  return await lxSearch(platformId, query, page, limit);
}

/** 搜一个平台的歌单（洛雪内置 `PlaylistSearchApi` / MusicFree `searchSheet`）。 */
export async function searchPlatformSheets(platformId: string, query: string,
  page: number): Promise<SearchPlaylistInfo[]> {
  if (isMfPlatformId(platformId)) {
    const api: LXUserApiInfo | undefined = mfApiOf(platformId);
    if (api === undefined) {
      return [];
    }
    return await mfSearchSheets(api, query, page);
  }
  if (!platformRegistry.isBuiltin(platformId)) {
    return [];
  }
  return await PlaylistSearchApi.searchPlaylists(platformId, query, page);
}

/**
 * 歌单广场：MusicFree 平台的内容。
 *
 * ★ 2026-11-09（用户：「歌单广场没获取到就提示没获取到，现在显示一个榜单」）：
 *   广场 = 插件的**推荐歌单**（`getRecommendSheetTags` + `getRecommendSheetsByTag`）。
 *   插件没实现推荐接口时返回空 —— 由 UI 显示「没获取到」，
 *   **绝不能**拿榜单（`getTopLists`）顶替，那是排行榜的内容。
 */
export async function platformPlazaFeed(platformId: string): Promise<SearchPlaylistInfo[]> {
  const groups: SearchPlaylistInfo[][] = await platformPlazaGroups(platformId);
  const out: SearchPlaylistInfo[] = [];
  for (let g: number = 0; g < groups.length; g++) {
    for (let i: number = 0; i < groups[g].length; i++) {
      out.push(groups[g][i]);
    }
  }
  return out;
}

/** 歌单广场：按插件的推荐标签分组返回（推荐歌单，不是榜单）。 */
export async function platformPlazaGroups(platformId: string): Promise<SearchPlaylistInfo[][]> {
  const out: SearchPlaylistInfo[][] = [];
  const api: LXUserApiInfo | undefined = mfApiOf(platformId);
  if (api === undefined) {
    return out;
  }
  try {
    const groups: MfTopListGroup[] = await mfRecommendGroups(api);
    for (let g: number = 0; g < groups.length; g++) {
      out.push(groups[g].items);
    }
  } catch (_err) {
    // 插件没有推荐接口 / 请求失败 → 空态
  }
  return out;
}

/** 排行榜：插件的榜单分组（`getTopLists`）。与广场的推荐歌单是两套东西。 */
export async function platformRankingGroups(platformId: string): Promise<SearchPlaylistInfo[][]> {
  const out: SearchPlaylistInfo[][] = [];
  const api: LXUserApiInfo | undefined = mfApiOf(platformId);
  if (api === undefined) {
    return out;
  }
  try {
    const groups: MfTopListGroup[] = await mfTopLists(api);
    for (let g: number = 0; g < groups.length; g++) {
      out.push(groups[g].items);
    }
  } catch (_err) {
    // 插件没有榜单 / 请求失败 → 空态
  }
  return out;
}
