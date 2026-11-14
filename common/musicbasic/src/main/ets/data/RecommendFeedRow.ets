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
 * Discriminator for polymorphic home-feed rows in {@link RecommendFeedRow}.
 */
export enum RecommendFeedKind {
  /** Large hero banner with gradient and cover. */
  HERO_BANNER = 0,
  /** Medium card with play count and palette index. */
  RECOMMEND_CARD = 1,
  /** Tab strip entry with paired icons. */
  CATEGORY_TAB = 2
}

/**
 * Single home recommend feed row; fields used depend on {@link kind}.
 */
export class RecommendFeedRow {
  /** Stable row id within the feed. */
  public feedId: number = 0;
  /** Ascending sort key when rendering the combined feed. */
  public sortOrder: number = 0;
  /** Row layout and which optional field groups apply. */
  public kind: RecommendFeedKind = RecommendFeedKind.HERO_BANNER;

  /** Hero: small badge text resource. */
  public heroBadge?: Resource;
  /** Hero: main title resource. */
  public heroTitle?: Resource;
  /** Hero: subtitle line resource. */
  public heroSubLine?: Resource;
  /** Hero: cover image resource. */
  public heroCoverImage?: Resource;
  /** Hero: gradient start color (hex string). */
  public heroGradientStart: string = '#1E3A5F';
  /** Hero: gradient end color (hex string). */
  public heroGradientEnd: string = '#4A6FA5';

  /** Card: title resource. */
  public cardTitle?: Resource;
  /** Card: play count or similar label resource. */
  public cardPlayCountLabel?: Resource;
  /** Card: palette slot for themed backgrounds. */
  public cardPaletteIndex: number = 0;
  /** Card: background image resource. */
  public cardBackgroundImage?: Resource;

  /** Tab: title resource. */
  public tabTitle?: Resource;
  /** Tab: selected-state icon. */
  public tabIconSelected?: Resource;
  /** Tab: unselected-state icon. */
  public tabIconUnselected?: Resource;
}
