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

import { PlayerConstants, PlayerViewModel, QueuePlaylistSheet } from 'player';
import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys, MINI_BAR_ASIDE_ID, MINI_META_TITLE_ID, MINI_META_SINGER_ID,
  MorphMetaEndpoint, PlayerExpandState } from 'musicbasic';


/**
 * Mini player row: title, artist, transport controls, and playlist affordance beside the cover.
 */
@ComponentV2
export struct HomeMiniBarPlayerAside {
  /** Shared player state and actions (play/pause, next, open full screen). */
  @Param playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** When true, shows the previous-track control before play/pause. */
  @Param showPreviousTrack: boolean = false;
  /**
   * 元信息（歌名/歌手）那一块的不透明度。
   *
   * 真实迷你条上恒为 1；**形变克隆层**（壳层的 `MorphMiniBarClone`）按反编译的
   * `MiniMorph.metaOpacityAt = clamp(1 - t/0.35)` 传进来 —— 比操作区（0.20）**晚**消失，
   * 于是观感是"右侧按钮先没、歌名后没"。
   */
  @Param metaOpacity: number = 1;
  @Param isMorphClone: boolean = false;
  @Param floatingMeta: boolean = false;
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  private titleController: TextController = new TextController();
  private singerController: TextController = new TextController();

  @Monitor('playerViewModel.appState.selectIndex')
  onMetaChanged(): void {
    this.publishMeta(false);
    this.publishMeta(true);
  }

  aboutToAppear(): void {
    this.publishMeta(false);
    this.publishMeta(true);
  }

  private publishMeta(singer: boolean): void {
    if (this.isMorphClone) {
      return;
    }
    const endpoint = new MorphMetaEndpoint();
    endpoint.id = (singer ? MINI_META_SINGER_ID : MINI_META_TITLE_ID) + (this.floatingMeta ? '_floating' : '');
    endpoint.controller = singer ? this.singerController : this.titleController;
    const content = singer ? this.playerViewModel.songSinger() : this.playerViewModel.songTitle();
    endpoint.content = typeof content === 'string' ? content :
      this.getUIContext().getHostContext()!.resourceManager.getStringSync(content.id);
    endpoint.fontFp = singer ? 10 : 12;
    endpoint.lineHeightFp = singer ? 13 : 16;
    endpoint.weight = singer ? 400 : 600;
    endpoint.color = singer ? $r('app.color.primary60') : $r('app.color.mini_bar_primary');
    this.expandState.registerMorphMeta(true, singer, endpoint, this.floatingMeta);
  }
  /**
   * 元信息那一块的横向位移（vp）：反编译 `MiniMorph.coverRightShiftAt(t)` —— 封面长大后
   * 把歌名/歌手**往右推**（`coverRightAt(t) - coverRightAt(0)`）。真实迷你条上恒为 0。
   */
  @Param metaShiftX: number = 0;
  /** When true, shows the play-queue bottom sheet. */
  @Local showPlaylistSheet: boolean = false;

  /**
   * 操作按钮簇**右侧**的留白（vp）。
   *
   * 胶囊的右内边距在 `HomeMiniBarPlayer` 里是 `actionsTrail`（折叠态 ≈22vp），
   * 按观感还嫌按钮贴边，这里再让出几 vp。取 6（落在用户给的 4~8 区间中值）。
   */
  private static readonly ACTIONS_TRAIL_GAP_VP: number = 6;

  /**
   * Lays out metadata column, optional previous track, play/pause, next, and queue buttons.
   *
   * ★ 宽度约束（照抄逆向规格 `MiniPlayer胶囊布局与宽度约束.md` §四）：
   *   **只有元信息那一列吃 `layoutWeight(1)`；右侧按钮簇按固有宽度先占位、不参与压缩。**
   *   这样"空间不够"时被挤扁的永远是歌名/歌手，按钮留在胶囊内 ——
   *   靠 `displayPriority` 让系统去隐藏按钮是**错的**（它只在 Row/Column 空间不足时生效，
   *   而且"某个优先级被隐藏则更低的全部隐藏"，用户看到的就是"列表按钮不见了"）。
   */
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        Column() {
          Text(this.playerViewModel.songTitle(), { controller: this.titleController })
            .id(this.isMorphClone ? 'rzd_clone_meta_title_unused' :
              MINI_META_TITLE_ID + (this.floatingMeta ? '_floating' : ''))
            .onAreaChange((): void => { this.publishMeta(false); })
            .fontColor($r('app.color.mini_bar_primary'))
            .fontSize(12)
            .fontWeight(600)
            .lineHeight(16)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.playerViewModel.songSinger(), { controller: this.singerController })
            .id(this.isMorphClone ? 'rzd_clone_meta_singer_unused' :
              MINI_META_SINGER_ID + (this.floatingMeta ? '_floating' : ''))
            .onAreaChange((): void => { this.publishMeta(true); })
            .fontColor($r('app.color.primary60'))
            .fontSize(10)
            .lineHeight(13)
            .fontWeight(FontWeight.Regular)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        // ★ 全场**唯一**吃权重的一段：空间不足时先挤歌名（鸿蒙的异型屏/折叠屏/宽屏下
        //   条宽差别很大，不能靠写死宽度），按钮簇必须留在条内。
        .layoutWeight(PlayerConstants.LAYOUT_WEIGHT_PLAYER_CONTROL)
        // ⚠️ 允许被压缩到 0（默认的 minWidth 会把权重让不出去）
        .constraintSize({ minWidth: 0 })
        // 元信息那一档的透明度（真实迷你条恒 1，克隆层按 metaOpacityAt 传值）
        .opacity(this.isMorphClone ? this.metaOpacity :
          (this.expandState.sourceBarHidden ? 0 : this.metaOpacity))
        // 被封面"推着往右走"（反编译 λ1e 的 `coverRightShiftAt`）；真实迷你条恒 0
        .translate({ x: this.metaShiftX })
        .onClick(() => {
          this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
        })

        // ★ 操作按钮簇：**不给 layoutWeight**，每个按钮给**固定宽度**（点击热区 40vp）——
        //   "按固有宽度先占位"必须是**确定的**宽度，不能依赖 SymbolGlyph 的隐含测量值。
        //   父容器空间不足时，整数 `displayPriority` 仍可整簇兜底（见常量的说明）。
        Row({ space: PlayerConstants.MINI_ACT_GAP }) {
          if (this.showPreviousTrack) {
            SymbolGlyph($r('sys.symbol.backward_end_fill'))
              .fontSize(PlayerConstants.MINI_ACT_ICON)
              .fontWeight(FontWeight.Regular)
              .width(PlayerConstants.MINI_ACT_SIZE)
              .height(PlayerConstants.MINI_ACT_ICON)
              .fontColor([$r('app.color.mini_bar_primary')])
              .onClick(() => {
                this.playerViewModel.playPrevious();
              })
          }

          SymbolGlyph(this.playerViewModel.appState.isPlay ?
            $r('sys.symbol.pause_round_triangle_fill') :
            $r('sys.symbol.play_round_triangle_fill'))
            .fontSize(PlayerConstants.MINI_ACT_ICON)
            .fontWeight(FontWeight.Regular)
            .width(PlayerConstants.MINI_ACT_SIZE)
            .height(PlayerConstants.MINI_ACT_ICON)
            .fontColor([$r('app.color.icon_primary')])
            .onClick(() => {
              this.playerViewModel.togglePlayPause();
            })

          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(PlayerConstants.MINI_ACT_ICON)
            .fontWeight(FontWeight.Regular)
            .width(PlayerConstants.MINI_ACT_SIZE)
            .height(PlayerConstants.MINI_ACT_ICON)
            .fontColor([$r('app.color.mini_bar_primary')])
            .onClick(() => this.playerViewModel.playNext())

          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(PlayerConstants.MINI_ACT_ICON)
            .fontWeight(FontWeight.Regular)
            .width(PlayerConstants.MINI_ACT_SIZE)
            .height(PlayerConstants.MINI_ACT_ICON)
            .fontColor([$r('app.color.icon_primary')])
            .onClick(() => {
              this.showPlaylistSheet = true;
            })
        }
        // 每个按钮固定占位（含点击热区），保证"列表按钮"永远有位置
        .height(PlayerConstants.MINI_ACT_SIZE)
        // ★ 尾部留白：让最右边的"播放列表"按钮**再往左一点**（用户按观感要求的 4~8vp）。
        //   ⚠️ 只加在这里 —— 克隆层复用同一个组件，所以这一处改完，
        //      真身与克隆**同时**跟着走，不会出现两者不一致。
        //   ⚠️ 不要用右 padding 去压：那会把 `MINI_ACT_SIZE` 的点击热区一起压掉。
        .margin({ right: HomeMiniBarPlayerAside.ACTIONS_TRAIL_GAP_VP })
        .displayPriority(PlayerConstants.DISPLAY_PRIORITY_MINI_ACTIONS)
        .flexShrink(0)
      }
      .width('100%')
      .onClick(() => {
        this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
      })

      QueuePlaylistSheet({
        isShow: this.showPlaylistSheet,
        onDismiss: (): void => {
          this.showPlaylistSheet = false;
        }
      })
    }
    .layoutWeight(1)
    // ★ 量的是**整块 aside**（歌名/歌手 + 右侧按钮），不是里面那个元信息 Column：
    //   克隆层要按这个宽度还原排布 —— 只给元信息那一列的宽度会让克隆挤成一条，
    //   右侧三个按钮被推到左边（用户实测两次都是这个症状）。
    .id(this.isMorphClone ? 'rzd_morph_actions_clone' : MINI_BAR_ASIDE_ID)
  }
}
