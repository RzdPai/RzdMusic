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


import { PlaylistRow } from '../data/PlaylistRow';
import { RecommendFeedKind, RecommendFeedRow } from '../data/RecommendFeedRow';
import { SongRow } from '../data/SongRow';

/**
 * In-memory singleton backing demo catalog: songs, one playlist, and home recommend feed rows.
 */
export class MusicMemoryStore {
  /** Process-wide singleton instance. */
  private static instance: MusicMemoryStore | undefined = undefined;

  /** All seeded song rows. */
  public songs: SongRow[] = [];
  /** Playlist headers and member id lists. */
  public playlists: PlaylistRow[] = [];
  /** Home feed rows (hero, cards, tabs), unsorted until read via API. */
  public recommendFeed: RecommendFeedRow[] = [];

  /**
   * @returns Shared {@link MusicMemoryStore} instance.
   */
  public static getInstance(): MusicMemoryStore {
    if (MusicMemoryStore.instance === undefined) {
      MusicMemoryStore.instance = new MusicMemoryStore();
    }
    return MusicMemoryStore.instance;
  }

  /** Builds initial tables via {@link seedTables}. */
  private constructor() {
    this.seedTables();
  }

  /** Fills songs, playlists, and recommend feed from built-in demo data. */
  private seedTables(): void {
    this.songs = this.buildSongs();
    this.playlists = this.buildPlaylists();
    this.recommendFeed = this.buildRecommendFeed();
  }

  /** Rotating cover art resources for demo tracks (excluding id 1 special case). */

  /** Constructs the full demo song catalog. */
  private buildSongs(): SongRow[] {
    return [];
  }

  /** Seeds a default playlist containing demo song ids 1–34. */
  private buildPlaylists(): PlaylistRow[] {
    return [];
  }

  /** Builds hero banners, recommend cards, and category tab rows for the home feed. */
  private buildRecommendFeed(): RecommendFeedRow[] {
    const rows: RecommendFeedRow[] = [];
    let nextFeedId = 0;
    let nextSortOrder = 0;

    const appendHeroRow = (
      badge: Resource,
      title: Resource,
      subLine: Resource,
      coverImage: Resource,
      gradientStart: string,
      gradientEnd: string
    ): void => {
      const feedRow = new RecommendFeedRow();
      feedRow.feedId = nextFeedId++;
      feedRow.sortOrder = nextSortOrder++;
      feedRow.kind = RecommendFeedKind.HERO_BANNER;
      feedRow.heroBadge = badge;
      feedRow.heroTitle = title;
      feedRow.heroSubLine = subLine;
      feedRow.heroCoverImage = coverImage;
      feedRow.heroGradientStart = gradientStart;
      feedRow.heroGradientEnd = gradientEnd;
      rows.push(feedRow);
    };

    const heroSub: Resource = $r('app.string.hero_banner_subline_brand');

    appendHeroRow($r('app.string.hero_1_badge'), $r('app.string.hero_1_title'), heroSub,
      $r('app.media.ic_recommend1'), '#152238', '#2E4A78');
    appendHeroRow($r('app.string.hero_2_badge'), $r('app.string.hero_2_title'), heroSub,
      $r('app.media.ic_recommend2'), '#2B3F5C', '#5A7A9E');
    appendHeroRow($r('app.string.hero_3_badge'), $r('app.string.hero_3_title'), heroSub,
      $r('app.media.ic_recommend3'), '#3D2F55', '#6B5A8C');
    appendHeroRow($r('app.string.hero_4_badge'), $r('app.string.hero_4_title'), heroSub,
      $r('app.media.ic_recommend4'), '#5C2D2D', '#9A5C4A');
    appendHeroRow($r('app.string.hero_5_badge'), $r('app.string.hero_5_title'), heroSub,
      $r('app.media.ic_recommend5'), '#1A2F4A', '#3D5C82');

    const appendRecommendCardRow = (
      title: Resource,
      playLabel: Resource,
      palette: number,
      backgroundResource: Resource
    ): void => {
      const feedRow = new RecommendFeedRow();
      feedRow.feedId = nextFeedId++;
      feedRow.sortOrder = nextSortOrder++;
      feedRow.kind = RecommendFeedKind.RECOMMEND_CARD;
      feedRow.cardTitle = title;
      feedRow.cardPlayCountLabel = playLabel;
      feedRow.cardPaletteIndex = palette;
      feedRow.cardBackgroundImage = backgroundResource;
      rows.push(feedRow);
    };

    appendRecommendCardRow($r('app.string.rec_1_title'), $r('app.string.rec_1_play'), 0,
      $r('app.media.ic_recommend_you1'));
    appendRecommendCardRow($r('app.string.rec_2_title'), $r('app.string.rec_2_play'), 1,
      $r('app.media.ic_recommend_you2'));
    appendRecommendCardRow($r('app.string.rec_3_title'), $r('app.string.rec_3_play'), 2,
      $r('app.media.ic_recommend_you3'));
    appendRecommendCardRow($r('app.string.rec_4_title'), $r('app.string.rec_4_play'), 3,
      $r('app.media.ic_recommend_you4'));
    appendRecommendCardRow($r('app.string.rec_5_title'), $r('app.string.rec_5_play'), 4,
      $r('app.media.ic_recommend_you5'));
    appendRecommendCardRow($r('app.string.rec_6_title'), $r('app.string.rec_6_play'), 0,
      $r('app.media.ic_recommend_you6'));

    const appendCategoryTabRow = (
      title: Resource,
      iconSelected: Resource,
      iconUnselected: Resource
    ): void => {
      const feedRow = new RecommendFeedRow();
      feedRow.feedId = nextFeedId++;
      feedRow.sortOrder = nextSortOrder++;
      feedRow.kind = RecommendFeedKind.CATEGORY_TAB;
      feedRow.tabTitle = title;
      feedRow.tabIconSelected = iconSelected;
      feedRow.tabIconUnselected = iconUnselected;
      rows.push(feedRow);
    };

    appendCategoryTabRow($r('app.string.home_tab_featured'), $r('app.media.ic_home_chip_featured_sel'),
      $r('app.media.ic_home_chip_featured_unsel'));
    appendCategoryTabRow($r('app.string.home_tab_artist'), $r('app.media.ic_home_chip_artist_sel'),
      $r('app.media.ic_home_chip_artist_unsel'));
    appendCategoryTabRow($r('app.string.home_tab_charts'), $r('app.media.ic_home_chip_charts_sel'),
      $r('app.media.ic_home_chip_charts_unsel'));
    appendCategoryTabRow($r('app.string.home_tab_categories'), $r('app.media.ic_home_chip_categories_sel'),
      $r('app.media.ic_home_chip_categories_unsel'));

    return rows;
  }
}
