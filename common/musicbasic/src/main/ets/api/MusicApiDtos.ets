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
 * Song payload returned by {@link MusicDbApi}; mirrors {@link SongRow} for API boundaries.
 */
export class SongApiDto {
  /** Primary key id. */
  public id: number = 0;
  /** Track title (string or resource). */
  public title: string | Resource = '';
  /** Artist label. */
  public singer: string | Resource = '';
  /** Badge or quality icon resource. */
  public mark: Resource = $r('app.string.page_show');
  /** Cover or list art resource. */
  public label: Resource = $r('app.string.page_show');
  /** Asset file name or path for playback. */
  public src: string = '';
  /** Display or list index. */
  public index: number = 0;
  /** Lyric asset path, if any. */
  public lyric: string = '';
}

/**
 * Hero banner card for the home feed (badge, title, gradient, cover).
 */
export class HeroCardApiDto {
  /** Small badge or tag line resource. */
  public badge: Resource = $r('app.string.page_show');
  /** Main headline resource. */
  public title: Resource = $r('app.string.page_show');
  /** Subtitle or supporting line resource. */
  public subLine: Resource = $r('app.string.page_show');
  /** Optional brand line (reserved for future use). */
  public brandLine: Resource = $r('app.string.page_show');
  /** Gradient background start color (hex). */
  public gradientStart: string = '#1E3A5F';
  /** Gradient background end color (hex). */
  public gradientEnd: string = '#4A6FA5';
  /** Hero cover image resource. */
  public coverImage: Resource = $r('app.media.ic_good');
}

/**
 * Recommend playlist card: title, play label, palette, and background art.
 */
export class RecommendCardApiDto {
  /** Card title resource. */
  public title: Resource = $r('app.string.page_show');
  /** Play count or similar caption resource. */
  public playCountLabel: Resource = $r('app.string.page_show');
  /** Index into a fixed color or style palette. */
  public paletteIndex: number = 0;
  /** Card background image resource. */
  public backgroundImage: Resource = $r('app.media.ic_avatar1');
}

/**
 * Category tab descriptor for HdsTabs-style home navigation.
 */
export class TabApiDto {
  /** Tab label resource. */
  public title: Resource = $r('app.string.page_show');
  /** Icon when the tab is selected. */
  public iconSelected: Resource = $r('app.media.ic_home_chip_featured_sel');
  /** Icon when the tab is unselected. */
  public iconUnselected: Resource = $r('app.media.ic_home_chip_featured_unsel');
}
