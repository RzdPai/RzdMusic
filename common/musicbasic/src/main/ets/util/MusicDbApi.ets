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


import { HeroCardApiDto, RecommendCardApiDto, SongApiDto, TabApiDto } from '../api/MusicApiDtos';
import { RecommendFeedKind, RecommendFeedRow } from '../data/RecommendFeedRow';
import { SongRow } from '../data/SongRow';
import { MusicMemoryStore } from '../db/MusicMemoryStore';

/** Cover resources for the 12-slot private-song carousel UI. */
const PRIVATE_DISPLAY_LABELS: Resource[] = [
  $r('app.media.ic_tv_list1'),
  $r('app.media.ic_tv_list2'),
  $r('app.media.ic_tv_list3'),
  $r('app.media.ic_tv_list4'),
  $r('app.media.ic_tv_list5'),
  $r('app.media.ic_tv_list6'),
  $r('app.media.ic_tv_list7'),
  $r('app.media.ic_tv_list8'),
  $r('app.media.ic_tv_list1'),
  $r('app.media.ic_tv_list2'),
  $r('app.media.ic_tv_list3'),
  $r('app.media.ic_tv_list4')
];

/**
 * Read-only API over {@link MusicMemoryStore}: songs, playlists, home feed, and DTO mapping.
 */
export class MusicDbApi {
  private static instance: MusicDbApi | undefined = undefined;
  private readonly store: MusicMemoryStore;
  private songIndex: Map<number, SongRow> = new Map();

  private constructor() {
    this.store = MusicMemoryStore.getInstance();
    this.rebuildSongIndex();
  }

  private rebuildSongIndex(): void {
    this.songIndex = new Map<number, SongRow>();
    for (let i: number = 0; i < this.store.songs.length; i++) {
      const row: SongRow = this.store.songs[i];
      this.songIndex.set(row.id, row);
    }
  }

  /**
   * @returns Shared {@link MusicDbApi} instance.
   */
  public static getInstance(): MusicDbApi {
    if (MusicDbApi.instance === undefined) {
      MusicDbApi.instance = new MusicDbApi();
    }
    return MusicDbApi.instance;
  }

  /**
   * @returns All songs as {@link SongApiDto} rows.
   */
  public getSongList(): SongApiDto[] {
    return this.store.songs.map((songRow) => this.rowToSongApiDto(songRow));
  }

  /**
   * @param id Song primary key.
   * @returns DTO or undefined if not found.
   */
  public getSongById(id: number): SongApiDto | undefined {
    const row = this.songIndex.get(id);
    return row !== undefined ? this.rowToSongApiDto(row) : undefined;
  }

  /**
   * Resolves songs for a playlist in stored id order.
   * @param playlistId Playlist id.
   * @returns Song DTOs; empty if playlist is unknown.
   */
  public getPlaylistSongItems(playlistId: number): SongApiDto[] {
    const playlist = this.store.playlists.find((playlistRow) => playlistRow.playlistId === playlistId);
    if (playlist === undefined) {
      return [];
    }
    const out: SongApiDto[] = [];
    for (let index = 0; index < playlist.songIds.length; index++) {
      const row = this.songIndex.get(playlist.songIds[index]);
      if (row !== undefined) {
        out.push(this.rowToSongApiDto(row));
      }
    }
    return out;
  }

  /**
   * @returns Hero banner rows sorted by feed sort order.
   */
  public getHeroCards(): HeroCardApiDto[] {
    return this.feedSorted()
      .filter((feedRow) => feedRow.kind === RecommendFeedKind.HERO_BANNER)
      .map((feedRow) => this.rowToHeroCardApiDto(feedRow));
  }

  /**
   * @returns Recommend-card rows sorted by feed sort order.
   */
  public getRecommendPlaylists(): RecommendCardApiDto[] {
    return this.feedSorted()
      .filter((feedRow) => feedRow.kind === RecommendFeedKind.RECOMMEND_CARD)
      .map((feedRow) => this.rowToRecommendCardApiDto(feedRow));
  }

  /**
   * @returns Category tab rows sorted by feed sort order.
   */
  public getCategoryTabs(): TabApiDto[] {
    return this.feedSorted()
      .filter((feedRow) => feedRow.kind === RecommendFeedKind.CATEGORY_TAB)
      .map((feedRow) => this.rowToTabApiDto(feedRow));
  }

  /**
   * First 12 catalog songs with carousel-specific labels and display indices.
   * @returns Song DTOs tailored for the private-song strip UI.
   */
  public getPrivateSongDisplayList(): SongApiDto[] {
    const out: SongApiDto[] = [];
    for (let displayIndex = 0; displayIndex < 12; displayIndex++) {
      const songId = displayIndex + 1;
      const row = this.songIndex.get(songId);
      if (row === undefined) {
        continue;
      }
      const dto = this.rowToSongApiDto(row);
      dto.label = PRIVATE_DISPLAY_LABELS[displayIndex];
      dto.index = displayIndex;
      out.push(dto);
    }
    return out;
  }

  /** Copies and sorts recommend feed rows by {@link RecommendFeedRow.sortOrder}. */
  private feedSorted(): RecommendFeedRow[] {
    const rows = [...this.store.recommendFeed];
    rows.sort((left, right) => left.sortOrder - right.sortOrder);
    return rows;
  }

  /** Maps a {@link SongRow} to {@link SongApiDto}. */
  private rowToSongApiDto(row: SongRow): SongApiDto {
    const dto = new SongApiDto();
    dto.id = row.id;
    dto.title = row.title;
    dto.singer = row.singer;
    dto.mark = row.mark;
    dto.label = row.label;
    dto.src = row.src;
    dto.index = row.index;
    dto.lyric = row.lyric;
    return dto;
  }

  /** Maps a hero {@link RecommendFeedRow} to {@link HeroCardApiDto}. */
  private rowToHeroCardApiDto(feedRow: RecommendFeedRow): HeroCardApiDto {
    const dto = new HeroCardApiDto();
    if (feedRow.heroBadge !== undefined) {
      dto.badge = feedRow.heroBadge;
    }
    if (feedRow.heroTitle !== undefined) {
      dto.title = feedRow.heroTitle;
    }
    if (feedRow.heroSubLine !== undefined) {
      dto.subLine = feedRow.heroSubLine;
    }
    if (feedRow.heroCoverImage !== undefined) {
      dto.coverImage = feedRow.heroCoverImage;
    }
    dto.gradientStart = feedRow.heroGradientStart;
    dto.gradientEnd = feedRow.heroGradientEnd;
    return dto;
  }

  /** Maps a recommend-card feed row to {@link RecommendCardApiDto}. */
  private rowToRecommendCardApiDto(feedRow: RecommendFeedRow): RecommendCardApiDto {
    const dto = new RecommendCardApiDto();
    if (feedRow.cardTitle !== undefined) {
      dto.title = feedRow.cardTitle;
    }
    if (feedRow.cardPlayCountLabel !== undefined) {
      dto.playCountLabel = feedRow.cardPlayCountLabel;
    }
    dto.paletteIndex = feedRow.cardPaletteIndex;
    if (feedRow.cardBackgroundImage !== undefined) {
      dto.backgroundImage = feedRow.cardBackgroundImage;
    }
    return dto;
  }

  /** Maps a category-tab feed row to {@link TabApiDto} with defaults for missing fields. */
  private rowToTabApiDto(feedRow: RecommendFeedRow): TabApiDto {
    const dto = new TabApiDto();
    dto.title = feedRow.tabTitle ?? $r('app.string.page_show');
    dto.iconSelected = feedRow.tabIconSelected ?? $r('app.media.ic_home_chip_featured_sel');
    dto.iconUnselected = feedRow.tabIconUnselected ?? $r('app.media.ic_home_chip_featured_unsel');
    return dto;
  }
}
