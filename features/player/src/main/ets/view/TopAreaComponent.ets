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
  getWindowInfoState,
  ImmersiveType,
  PlayerExpandState,
  StyleConstants,
  WindowInfo
} from 'musicbasic';
import { MusicAppState } from '../model/PlayerModels';
import { buildSongShareText, showSystemShare } from '../util/ShareUtil';

/** Full-screen playback top bar: back action and share affordance. */
@ComponentV2
export struct TopAreaComponent {
  /** Window breakpoint (reserved for future responsive tweaks). */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Whether full-screen player chrome is visible (passed from parent). */
  @Param isShowPlay: boolean = false;

  /** Invoked when the back affordance is tapped. */
  @Param onBackClick: () => void = (): void => {
  };
  /** Shared app state (read-only usage in this bar). */
  @Local state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** Window metrics for immersive title padding. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /**
   * 无界 `PlayerChrome` 档位表（只读 `topBarH` 那一项）。
   *
   * ★★ 2026-10-15（照搬无界）：顶栏行高原来在这里**写死 56**，而 56 是**内容让位线**
   *   （= 无界 `padTop()` 下限），不是无界的 `topBarH`（FULL 44）。两者混在一处时
   *   直接换数会同时动到让位线 —— 而让位线被整套形变几何依赖（见
   *   `PlayerExpandState.chromeTopBarH()` 的注释）。
   *   ⇒ 这里只把"写死的 56"换成**唯一入口** `chromeTopBarH()`：手机档它恰好返回 56
   *     （`TOP_BAR_ROW_H_VP`），**逐像素不变**；档位从此只有一处可改。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /** Opens the system share panel with the current song info and its link. */
  private shareCurrentSong(): void {
    const song = this.state.getCurrentSongItem();
    const title: string = song !== undefined && typeof song.title === 'string' ? song.title : '未知歌曲';
    const singer: string = song !== undefined && typeof song.singer === 'string' ? song.singer : '未知歌手';
    const source: string = song !== undefined ? song.source : '';
    const songId: string = song !== undefined ? song.songId : '';
    showSystemShare(this.getUIContext(), buildSongShareText(title, singer, source, songId), '歌曲分享');
  }

  /** Renders back and share row with safe-area aware trailing padding. */
  build() {
    Row() {
      Image($r('app.media.ic_back_down'))
        .width(24)
        .height(24)
        .accessibilityText('返回')
        .accessibilityLevel('yes')
        .onClick((): void => {
          this.onBackClick();
        })
      SymbolGlyph($r('sys.symbol.share'))
        .fontSize(24)
        .fontWeight(FontWeight.Regular)
        .fontColor([$r('app.color.play_text_color')])
        .accessibilityText('分享')
        .accessibilityLevel('yes')
        .onClick((): void => {
          this.shareCurrentSong();
        })
    }
    // ★ 2026-10-15：由 `PlayerExpandState.chromeTopBarH()` 给（档位唯一入口）。
    //   手机档 = `TOP_BAR_ROW_H_VP` = 56 ⇒ **与改前的写死值逐像素相同**。
    .height(this.expandState.chromeTopBarH())
    .width(StyleConstants.FULL_WIDTH)
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({
      right: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
        Math.max(0, this.windowInfo.titleButtonWidthVp - 24) : 0,
    })
  }
}
