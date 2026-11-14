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
  Logger,
  PlaybackIntentState,
  PlayerExpandState,
  StyleConstants,
  WindowInfo
} from 'musicbasic';
import { MusicAppState } from '../model/PlayerModels';

/** Full-screen playback top bar: back action and song-menu affordance. */
@ComponentV2
export struct TopAreaComponent {
  /** 本组件的日志 tag（`hdc shell hilog | grep RzdTopArea`）。 */
  private static readonly logTag: string = 'RzdTopArea';
  /** Window breakpoint (reserved for future responsive tweaks). */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Whether full-screen player chrome is visible (passed from parent). */
  @Param isShowPlay: boolean = false;

  /** Invoked when the back affordance is tapped. */
  @Param onBackClick: () => void = (): void => {
  };
  /**
   * 共享播放意图（`AppStorageV2`）—— 右上角这颗按钮靠它把「打开歌曲菜单」传给
   * 真正挂弹层的 `ControlAreaComponent`（本组件被挂两处，不做父子参数链）。
   *
   * ★★★ 2026-10-18（用户：「把右上角的分享改成歌曲菜单」）：
   *   右上角原来是**分享**（`shareCurrentSong()`），现在改成**歌曲菜单**的第二个入口
   *   —— 分享没有丢，它还在歌曲菜单里（`ControlAreaComponent` 的「分享」行）。
   *   图标沿用底部那排「更多」的 `sys.symbol.dot_grid_1x2_circle`（= 同一个菜单）。
   */
  @Local intent: PlaybackIntentState = AppStorageV2.connect(PlaybackIntentState,
    AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!;
  /** Shared app state (read-only usage in this bar). */
  @Local state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** Window metrics for immersive title padding. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /**
   * 无界 `PlayerChrome` 档位表（顶栏行高那一项）。
   *
   * ★★ 2026-10-15：顶栏行高原来在这里**写死 56**。当时只把"写死的 56"换成唯一入口
   *   `chromeTopBarH()`（手机档恰好仍返回 56 ⇒ 逐像素不变），理由是"56 同时是内容让位线"。
   *
   * ★★★ 2026-10-17（**收尾复核：那个理由被推翻，行高已换成档位表的值**）：
   *   · 让位线那一路走的是 `PLAYER_TOP_FALLBACK_VP`（`topInsetVp()`），**从不读**行高常量；
   *   · 行高常量的唯一消费者就是 `chromeTopBarH()`，而本组件的 `.height()` 是它的唯一出口；
   *   ⇒ 两者只是**数值撞了**（都是 56）的**两个独立量** ⇒ 可以直接照搬上游：
   *     无界顶栏 Row 就是 `.height(this.chrome().topBarH)`（`wujie.pa:196068-196079`）
   *     ⇒ 手机档（FULL）**44**。
   *   ⇒ 视觉影响：本行内容（返回键 / 分享键）**居中** ⇒ 会整体上移 6vp；行本身也变矮 12vp。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /** Renders back and song-menu row with safe-area aware trailing padding. */
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
      SymbolGlyph($r('sys.symbol.dot_grid_1x2_circle'))
        .fontSize(24)
        .fontWeight(FontWeight.Regular)
        .fontColor([$r('app.color.play_text_color')])
        .accessibilityText('歌曲菜单')
        .accessibilityLevel('yes')
        .onClick((): void => {
          // bump 序号 ⇒ `ControlAreaComponent` 的 `@Monitor` 打开歌曲菜单。
          this.intent.menuRequestSeq = this.intent.menuRequestSeq + 1;
          Logger.info(TopAreaComponent.logTag, `top area song menu tap seq=${this.intent.menuRequestSeq}`);
        })
    }
    // ★ 2026-10-17：由 `PlayerExpandState.chromeTopBarH()` 给，而它现在**直接取档位表**
    //   （= 无界 `chrome().topBarH`：FULL 44 / MEDIUM 40 / COMPACT 36）。
    //   ⇒ 手机档 = **44**（改前是自编的 56 —— 那是 `design/Index.BAR_H`「底栏高度」，借错了）。
    .height(this.expandState.chromeTopBarH())
    .width(StyleConstants.FULL_WIDTH)
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({
      right: this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
        Math.max(0, this.windowInfo.titleButtonWidthVp - 24) : 0,
    })
  }
}
