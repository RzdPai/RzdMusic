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


import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import {
  AppStorageKeys,
  BreakpointConstants,
  CoverRadiusState,
  MusicStoreService,
  PLAYER_BIG_COVER_ID,
  PlayedSongRecord,
  StyleConstants,
  ThemeState
} from 'musicbasic';
import { MusicAppState } from '../model/PlayerModels';
import { PlayerConstants } from '../constant/PlayerConstants';
import { ControlAreaComponent } from './ControlAreaComponent';
import { amllParseLyricCached } from '../amll/parse/AmllAutoDetect';

/** 播放页大封面的组件 id（常量定义已提到 common 层，见 PlayerExpandState.ets）。 */
export { PLAYER_BIG_COVER_ID } from 'musicbasic';

/** Album art, title/artist block, and control area for full-screen playback layouts. */
@ComponentV2
export struct MusicPlayInfoBlock {
  /** Window breakpoint for typography and grid layout. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Shared playback and queue state. */
  @Param state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** When true, uses album art as a large background layer behind text. */
  @Param useAlbumCoverBackground: boolean = false;
  /** Vertical translation (vp) applied to meta block during dismiss gesture. */
  @Param metaBlockTranslateYvp: number = 0;
  /** True while dismissing past phase-1 threshold (hides some meta chrome). */
  @Param isDismissing: boolean = false;
  /** Linear scale factor (0�?) applied to cover during vertical dismiss. */
  @Param coverLinearScale: number = 1;
  /** When true, use compact panel stacking and hide the auxiliary 4-icon control row. */
  @Param panelLayout: boolean = false;
  /** When false, omits the embedded ControlAreaComponent (external shared control area used instead). */
  @Param showControlArea: boolean = true;

  /** True on MD width + MD height fold inner layout for compact title sizing. */
  private isMdCompactInfoTypography(): boolean {
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD;
  }

  @Local store: MusicStoreService = MusicStoreService.getInstance();
  @Local isCurrentFavorite: boolean = false;
  @Local coverRadiusState: CoverRadiusState =
    AppStorageV2.connect(CoverRadiusState, AppStorageKeys.COVER_RADIUS_STATE, () => new CoverRadiusState())!;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;

  /** Refreshes the favorite state when the track or store changes. */
  @Monitor('state.selectIndex', 'store.favoriteVersion')
  refreshFavorite(): void {
    const song = this.state.getCurrentSongItem();
    if (song !== undefined && song.source.length > 0) {
      this.isCurrentFavorite = this.store.isFavorite(song.source, song.songId);
    } else {
      this.isCurrentFavorite = false;
    }
  }

  /** Warms the lyric parse cache so the lyrics page never blocks on first parse. */
  @Monitor('state.selectIndex', 'state.playQueueIds', 'state.lyricVersion')
  prewarmLyricCache(): void {
    const song = this.state.getCurrentSongItem();
    if (song !== undefined && song.lyricText.length > 0) {
      amllParseLyricCached(song.lyricText);
    }
  }

  aboutToAppear(): void {
    this.coverRadiusState.radius = MusicStoreService.getInstance().getCoverCornerRadius();
    this.coverSpringScale = this.state.isPlay ? 1.05 : 0.95;
    this.coverSpringTarget = this.coverSpringScale;
    this.prewarmLyricCache();
    this.refreshFavorite();
  }

  aboutToDisappear(): void {
    if (this.coverSpringTimer > 0) {
      clearInterval(this.coverSpringTimer);
      this.coverSpringTimer = 0;
    }
  }

  /** Toggles the current track in favorites. */
  private toggleFavorite(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.source.length === 0) {
      return;
    }
    if (this.store.isFavorite(song.source, song.songId)) {
      this.store.removeFavorite(song.source, song.songId);
    } else {
      const record = new PlayedSongRecord();
      record.songId = song.songId;
      record.name = typeof song.title === 'string' ? song.title : '';
      record.singer = typeof song.singer === 'string' ? song.singer : '';
      record.source = song.source;
      record.img = song.cover;
      record.url = song.url;
      record.lyric = song.lyricText;
      record.time = Date.now();
      this.store.addFavorite(record);
    }
  }

  /** Title and artist column used beside compact square cover. */
  @Builder
  MusicInfoTextsCompactCover() {
    Column() {
      Text(this.state.getCurrentSongItem()?.title ?? '')
        .fontSize($r('app.float.title_font_play'))
        .fontColor($r('app.color.player_text_primary'))
        .opacity(0.86)
        .fontWeight(FontWeight.Bold)
        .fontFamily(PlayerConstants.FONT_FAMILY_BOLD)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(StyleConstants.FULL_WIDTH)
      Text(this.state.getCurrentSongItem()?.singer ?? '')
        .textAlign(TextAlign.Start)
        .fontSize($r('app.float.font_fourteen'))
        .fontColor($r('app.color.play_text_color'))
        .fontFamily(PlayerConstants.FONT_FAMILY_BLACK)
        .margin({ top: 2 })
        .width(StyleConstants.FULL_WIDTH)
        .fontWeight(FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(StyleConstants.FULL_WIDTH)
  }

  /** Linear scale for dismiss gesture; clamped so the cover never measures/render as zero-size. */
  private coverDisplayScale(): number {
    return Math.min(1, Math.max(0.02, this.coverLinearScale));
  }

  /** 播放/暂停封面弹簧缩放：播放放大、暂停缩小（手写阻尼弹簧，可见回弹） */
  @Local coverSpringScale: number = 1;
  private coverSpringTarget: number = 1;
  private coverSpringVelocity: number = 0;
  private coverSpringTimer: number = 0;
  private coverSpringLast: number = 0;

  @Monitor('state.isPlay')
  onPlayStateChanged(): void {
    this.coverSpringTarget = this.state.isPlay ? 1.05 : 0.95;
    this.ensureCoverSpring();
  }

  private ensureCoverSpring(): void {
    if (this.coverSpringTimer > 0) {
      return;
    }
    this.coverSpringLast = Date.now();
    const self = this;
    this.coverSpringTimer = setInterval((): void => {
      self.advanceCoverSpring();
    }, 16);
  }

  /** 阻尼弹簧数值积分：stiffness 220 / damping 13 → 约 12% 过冲回弹，0.5s 内稳定 */
  private advanceCoverSpring(): void {
    const now = Date.now();
    const dt = Math.min(50, now - this.coverSpringLast);
    this.coverSpringLast = now;
    const STIFFNESS = 220;
    const DAMPING = 13;
    const acc = (this.coverSpringTarget - this.coverSpringScale) * STIFFNESS -
      this.coverSpringVelocity * DAMPING;
    this.coverSpringVelocity += acc * (dt / 1000);
    this.coverSpringScale += this.coverSpringVelocity * (dt / 1000);
    if (Math.abs(this.coverSpringTarget - this.coverSpringScale) < 0.0005 &&
      Math.abs(this.coverSpringVelocity) < 0.0005) {
      this.coverSpringScale = this.coverSpringTarget;
      clearInterval(this.coverSpringTimer);
      this.coverSpringTimer = 0;
    }
  }

  /** Cover source for the current track: online url when available, else a default cover. */
  private currentCoverSource(): string | Resource {
    const song = this.state.getCurrentSongItem();
    if (song !== undefined && song.cover.length > 0) {
      return song.cover;
    }
    return $r('app.media.ic_avatar1');
  }

  /**
   * Square cover in the remaining column height above metadata + controls.
   * Uses layoutWeight so art expands; title/transport stay in the sibling column below.
   */
  @Builder
  CoverInfo() {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.currentCoverSource())
        .id(PLAYER_BIG_COVER_ID)
        .constraintSize({ maxWidth: '100%', maxHeight: '100%' })
        .aspectRatio(1)
        .objectFit(ImageFit.Cover)
        .syncLoad(true)
        .borderRadius(this.coverRadiusState.radius)
    }
    .width(StyleConstants.FULL_WIDTH)
    .layoutWeight(1)
    .borderRadius(this.coverRadiusState.radius)
    .clip(true)
    .scale({
      x: this.coverDisplayScale() * this.coverSpringScale,
      y: this.coverDisplayScale() * this.coverSpringScale,
      z: 1,
      centerX: '50%',
      centerY: '50%'
    })
  }

  /** Title row with like icon and artist line (non-compact layouts). */
  @Builder
  MusicInfoTexts() {
    Column() {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Text(this.state.getCurrentSongItem()?.title ?? '')
          .layoutWeight(1)
          .fontSize(this.panelLayout ? 24 : (this.isMdCompactInfoTypography() ?
            $r('app.float.title_font_play_md') : $r('app.float.title_font_play')))
          .fontColor($r('app.color.player_text_primary'))
          .opacity(0.86)
          .fontWeight(FontWeight.Bold)
          .fontFamily(PlayerConstants.FONT_FAMILY_BOLD)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 4 }) {
          SymbolGlyph(this.isCurrentFavorite ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(20)
            .fontWeight(FontWeight.Regular)
            .fontColor([this.isCurrentFavorite ? this.themeState.color : $r('app.color.player_text_primary')])
            .opacity(0.9)
            .onClick(() => {
              this.toggleFavorite();
            })
        }
      }
      .width(StyleConstants.FULL_WIDTH)

      Text(this.state.getCurrentSongItem()?.singer ?? '')
        .textAlign(TextAlign.Start)
        .fontSize(this.panelLayout ? 22 : (this.isMdCompactInfoTypography() ?
          $r('app.float.title_font_play') : $r('app.float.font_fourteen')))
        .fontColor($r('app.color.play_text_color'))
        .fontFamily(PlayerConstants.FONT_FAMILY_BLACK)
        .margin({ top: 2 })
        .width(StyleConstants.FULL_WIDTH)
        .fontWeight(FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .margin({ top: $r('app.float.music_info_margin_top') })
  }

  /** Responsive grid placing cover, texts, and ControlAreaComponent. */
  build() {
    if (this.useAlbumCoverBackground) {
      Column() {
        Column({ space: 0 }) {
          this.MusicInfoTextsCompactCover()
          if (this.showControlArea) {
            ControlAreaComponent({ showBottomOtherRow: false })
          }
        }
        .justifyContent(FlexAlign.End)
        .alignItems(HorizontalAlign.End)
        .width(StyleConstants.FULL_WIDTH)
        .height(219)
        .padding({
          bottom: $r('app.float.music_component_bottom'),
          left: $r('app.float.common_padding'),
          right: $r('app.float.common_padding')
        })
        .linearGradient({
          angle: 180,
          colors: [
            [$r('app.color.info_scrim_top'), 0.0],
            [$r('app.color.info_scrim_mid'), 0.5],
            [$r('app.color.info_scrim_bottom'), 1.0]
          ]
        })
        .translate({ y: this.metaBlockTranslateYvp })
        .visibility(this.isDismissing ? Visibility.None : Visibility.Visible)
      }
      .height(StyleConstants.FULL_HEIGHT)
      .width(StyleConstants.FULL_WIDTH)
      .justifyContent(FlexAlign.End)
      .clip(true)
    } else {
      if (this.panelLayout) {
        Column() {
          Column() {
            Image(this.currentCoverSource())
              .id(PLAYER_BIG_COVER_ID)
              .width(StyleConstants.FULL_WIDTH)
              .aspectRatio(1)
              .objectFit(ImageFit.Cover)
              .syncLoad(true)
              .constraintSize({
                maxHeight: '100%'
              })
              .borderRadius(this.coverRadiusState.radius)
              .clip(true)
              .scale({
                x: this.coverDisplayScale() * this.coverSpringScale,
                y: this.coverDisplayScale() * this.coverSpringScale,
                z: 1,
                centerX: '50%',
                centerY: '50%'
              })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)

          Column() {
            this.MusicInfoTexts()
            if (this.showControlArea) {
              ControlAreaComponent({ showBottomOtherRow: false })
            }
          }
          .height(276)
          .justifyContent(FlexAlign.End)
        }
        .height(StyleConstants.FULL_HEIGHT)
        .width(StyleConstants.FULL_WIDTH)
        .alignItems(HorizontalAlign.Center)
        .translate({ y: this.metaBlockTranslateYvp })
        .visibility(this.isDismissing ? Visibility.None : Visibility.Visible)
      } else {
        Column() {
          this.CoverInfo()
          Column() {
            this.MusicInfoTexts()
            if (this.showControlArea) {
              ControlAreaComponent({ showBottomOtherRow: true })
            }
          }
          .justifyContent(FlexAlign.SpaceBetween)
          .translate({ y: this.metaBlockTranslateYvp })
          .visibility(this.isDismissing ? Visibility.None : Visibility.Visible)
        }
        .height(StyleConstants.FULL_HEIGHT)
        .width(StyleConstants.FULL_WIDTH)
        .alignItems(HorizontalAlign.Center)
      }
    }
  }
}
