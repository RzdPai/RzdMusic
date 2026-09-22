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


/**
 * UI row model for a song in the private-songs recommendation list.
 */
/**
 * UI model for a home "private song" row (online or local).
 *
 * 「用登录状态获取推荐」关掉时，首页歌曲来自各平台榜单接口，**接口不带封面**，
 * 封面是异步补进来的 —— 所以这个类必须是 `@ObservedV2` + `@Trace`，
 * 否则补完封面改 `coverUrl` 时界面不会重绘（表现就是整排空图标、怎么刷新都没图）。
 */
@ObservedV2
export class RecommendPrivateSongUi {
  /** Stable song id used for playback requests. */
  public id: number = 0;
  /** Song title text or resource. */
  @Trace public title: string | Resource = '';
  /** Artist or singer line. */
  @Trace public singer: string | Resource = '';
  /** Cover artwork resource (mapped from API label in util). */
  public cover: Resource = $r('app.string.page_show');
  /** Music source id ('kw'|'kg'|'tx'|'wy'|'mg') for online songs; empty for local. */
  @Trace public source: string = '';
  /** Song id within the music source for online songs. */
  @Trace public songId: string = '';
  /** Online cover image url; empty when unavailable. */
  @Trace public coverUrl: string = '';
}


/**
 * UI model for a hero banner card (badge, copy, cover, gradient hints).
 */
export class RecommendHeroCardUi {
  /** Small badge label above the title. */
  public badge: string | Resource = $r('app.string.page_show');
  /** Primary headline. */
  public title: string | Resource = $r('app.string.page_show');
  /** Secondary subtitle line. */
  public subLine: string | Resource = $r('app.string.page_show');
  /** Main hero image. */
  public coverImage: Resource = $r('app.media.ic_good');
  /** Online hero image url; used before the local resource when set. */
  public coverUrl: string = '';
  /** QQ music toplist id for routing; empty for demo cards. */
  public topid: string = '';
  /** Board id within the banner source for board-detail routing; empty otherwise. */
  public boardId: string = '';
  /** Song id for account daily-recommendation banners; empty for toplist banners. */
  public songId: string = '';
  /** Music source id ('kw'|'kg'|'tx'|'wy'|'mg') for daily-recommendation banners. */
  public source: string = '';
  /**
   * 功能入口卡的点击去向。
   *
   * 首页顶部那几张是 MusicHome 同款**功能入口**（现在就听 / 每日30首 / 新歌推荐 /
   * 心动模式 / 精选推荐），不是歌曲也不是榜单，所以既没有 songId 也没有 boardId，
   * 用这个字段决定点下去做什么。空串表示走原来的歌曲/榜单分发逻辑。
   */
  public feature: string = '';
  /**
   * 「每日30首」卡的背景拼图：该列表前 4 首的封面地址（2×2 拼贴）。
   * 其它卡为空数组。
   */
  public dailyCovers: string[] = [];
  /** 「每日30首」卡背景拼图取不到封面时的占位歌名（同样 4 个）。 */
  public dailyTitles: string[] = [];
  /** Gradient start color (hex string). */
  public gradientStart: string = '#1E3A5F';
  /** Gradient end color (hex string). */
  public gradientEnd: string = '#4A6FA5';
}


/**
 * UI model for a “For you” style recommendation playlist card.
 */
export class RecommendCardUi {
  /** Card title. */
  public title: string | Resource = $r('app.string.page_show');
  /** Human-readable play count label. */
  public playCountLabel: string | Resource = $r('app.string.page_show');
  /** Palette index for themed styling. */
  public paletteIndex: number = 0;
  /** Background / cover image for the card. */
  public backgroundImage: Resource = $r('app.media.ic_avatar1');
  /** Online background image url; used before the local resource when set. */
  public backgroundUrl: string = '';
  /** QQ music toplist id for routing; empty for demo cards. */
  public topid: string = '';
  /** Board id within the card source for board-detail routing; empty otherwise. */
  public boardId: string = '';
  /** Song id for account daily-recommendation cards; empty for playlist cards. */
  public songId: string = '';
  /** Music source id ('kw'|'kg'|'tx'|'wy'|'mg') for song cards. */
  public source: string = '';
  /** Singer line for account daily-recommendation song cards. */
  public singer: string | Resource = '';
}


/**
 * UI model for a single category chip tab (icons for selected vs unselected).
 */
export class RecommendCategoryTabUi {
  /** Tab label. */
  public title: Resource = $r('app.string.page_show');
  /** Icon when this tab is selected. */
  public iconSelected: Resource = $r('app.media.ic_home_chip_featured_sel');
  /** Icon when this tab is not selected. */
  public iconUnselected: Resource = $r('app.media.ic_home_chip_featured_unsel');
}


/**
 * UI model for a singer row in the home singer chart list.
 */
export class RecommendSingerUi {
  /** QQ singer id for future routing. */
  public singerId: string = '';
  /** Display name. */
  public name: string = '';
  /** Singer photo url. */
  public picUrl: string = '';
}


/**
 * UI model for a toplist row in the home chart list.
 */
export class RecommendChartUi {
  /** Toplist id for routing to the playlist detail page (QQ source only). */
  public topid: string = '';
  /** Toplist display name. */
  public name: string = '';
  /** Toplist banner pic url. */
  public picUrl: string = '';
  /** Music source id ('kw'|'kg'|'tx'|'wy'|'mg'); empty for QQ toplist entries. */
  public source: string = '';
  /** Board id within the source; empty for QQ toplist entries. */
  public boardId: string = '';
}


/**
 * UI model for a guest-mode playlist plaza card (multi-source online playlist).
 */
export class RecommendPlazaPlaylistUi {
  /** Playlist id within its music source. */
  public id: string = '';
  /** Playlist title. */
  public name: string = '';
  /** Creator / author name. */
  public author: string = '';
  /** Cover image url. */
  public image: string = '';
  /** Track count label (may be empty). */
  public count: string = '';
  /** Play / listen count label (may be empty). */
  public listenCount: string = '';
  /** Music source id ('kw'|'kg'|'tx'|'wy'|'mg'). */
  public source: string = '';
}


/**
 * UI model for a guest-mode ranking board entry.
 */
export class RecommendBoardUi {
  /** Board id within its music source. */
  public id: string = '';
  /** Board display name. */
  public name: string = '';
  /** Music source id ('kw'|'kg'|'tx'|'wy'|'mg'). */
  public source: string = '';
  /** Board cover image url; empty when unavailable. */
  public cover: string = '';
}


/**
 * UI model for one song row inside a ranking board detail page.
 */
export class RecommendBoardTrackUi {
  /** Song id within its music source (used for playback). */
  public songId: string = '';
  /** Song title. */
  public name: string = '';
  /** Artist line. */
  public singer: string = '';
  /** Album name. */
  public album: string = '';
  /** Cover image url. */
  public coverUrl: string = '';
  /** Duration label (mm:ss). */
  public duration: string = '';
  /** Music source id ('kw'|'kg'|'tx'|'wy'|'mg'). */
  public source: string = '';
}
