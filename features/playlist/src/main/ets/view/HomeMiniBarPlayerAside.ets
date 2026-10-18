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
import { AppStorageKeys, MINI_META_TITLE_ID, MINI_META_SINGER_ID,
  MorphMetaEndpoint, PlayerExpandState } from 'musicbasic';


/**
 * Mini player row: title, artist, transport controls, and playlist affordance beside the cover.
 *
 * ══════════════════ 本文件照搬的三段上游结构（`wujie.pa`） ══════════════════
 *
 * ① **操作区按钮 = 40 × 40 的 `Stack` 包一颗 `SymbolGlyph(fontSize 24)`**（`:69480-69573`）：
 *    `Stack().width(MINI_ACT_SIZE).height(MINI_ACT_SIZE).clickEffect({level:LIGHT}).onClick(...)`，
 *    而 `SymbolGlyph` **只有** `.fontSize(MINI_ACT_ICON)` + `.fontColor([…])`，**没有 width/height**。
 *    旧实现是 `SymbolGlyph.width(40).height(24)` ⇒ 热区只有 24 高（点不中）+ 图标被当盒量。
 *
 * ② **meta 容器 = `Stack(TopStart)` + `layoutWeight(1)` + `clip(true)` +
 *    `blendMode(SRC_OVER, OFFSCREEN)` + 渐变遮罩 `overlay`**（`:69317-69393`）。
 *    旧实现是 `Column + minWidth:0 + maxLines(1) + Ellipsis`（看不到"渐隐"）⇒ 本轮换成上游结构，
 *    文字溢出时靠右侧渐隐收口（`Ellipsis` 作为降级保留，见 {@link MetaFadeMask} 的注释）。
 *
 * ③ **meta ↔ 操作区 间距 = 4**（`:69044` 的胶囊 `Row({space:4})`；上游那 4vp 正好落在
 *    "左段（封面 + meta）"与"操作区 Row"之间）⇒ 本仓的等价落点就是这一层的 `Row space`。
 *
 * ★ 宽度约束（照抄逆向规格 `MiniPlayer胶囊布局与宽度约束.md` §四）：
 *   **只有 meta 那一列吃 `layoutWeight(1)`；右侧按钮簇按固有宽度先占位、不参与压缩。**
 *   这样"空间不够"时被挤扁的永远是歌名/歌手，按钮留在胶囊内 ——
 *   靠 `displayPriority` 让系统去隐藏按钮是**错的**（它只在 Row/Column 空间不足时生效，
 *   而且"某个优先级被隐藏则更低的全部隐藏"，用户看到的就是"列表按钮不见了"）。
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
  /**
   * 	rue = **只画 meta**（歌名/歌手），操作区由父组件按上游结构另行摆放。
   *
   * 上游胶囊 Row 的两个直接子节点是「左段(封面+meta，layoutWeight(1)）」与
   * 「操作区 Row（无 weight）」（wujie.pa:69128-69474）。本仓 HomeMiniBarPlayer 传 	rue，
   * 把操作区换成同级兄弟 {@link MiniBarActions}；克隆层不传（保持整块渲染）。
   */
  @Param actionsOutside: boolean = false;
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  private titleController: TextController = new TextController();
  private singerController: TextController = new TextController();

  /**
   * meta 与操作区之间的间距（vp）—— 上游 `Row({ space: 4 })`（`wujie.pa:69044`）。
   *
   * ⚠️ 这个 4 **属于** meta↔actions 这一段（上游胶囊 `Row` 的两个直接子节点是
   *   "左段 `Row(封面+meta)`" 与 "操作区 `Row`"）⇒ 搬进本仓的分层后，落点是本文件的
   *   `Row({ space: META_ACTIONS_GAP_VP })`，而 `HomeMiniBarPlayer` 里那层胶囊 `Row`
   *   的 `space` 必须是 **0**（上游封面与 meta 之间没有缝，靠 `coverOverflow` 的
   *   `margin.left` 补偿；本仓那个补偿已经被"视觉盒"吸收，见 `HomeMiniBarPlayer` 的注释）。
   */
  private static readonly META_ACTIONS_GAP_VP: number = 4;

  /**
   * 操作按钮簇**右侧**的留白（vp）。
   *
   * 上游没有这一项（胶囊 `Row` 的右内距就是 `actionsTrail`）。这里的 6vp 是用户
   * 2026-10-12「右边三个按钮往左移动一点」的**自定需求**，本轮**有意保留**并记在交付报告里；
   * 去掉它只需把本常量改成 0（不影响"右侧不出框"的恒等式，只会让按钮再右移 6vp）。
   */
  private static readonly ACTIONS_TRAIL_GAP_VP: number = 6;

  /** 渐隐遮罩的"实心"段终点（比例）：0 → 0.78 完全不透明，0.78 → 1 渐隐到全透明。 */
  private static readonly META_FADE_START_RATIO: number = 0.78;

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
   * meta 右侧的渐隐遮罩（上游 `metaFadeMask`，`wujie.pa:69372-69384` 的 `overlay` 参数）。
   *
   * 上游的做法是 `overlay(metaFadeMask, {align: TopStart})` + 容器
   * `blendMode(SRC_OVER, OFFSCREEN)`：容器先整体画到离屏画布，遮罩再用 `DST_IN`
   * 与"下方的文字"相乘 ⇒ 右边一段被**擦成透明**（透出胶囊材质），而不是画一条遮挡色
   * （材质是半透明光感，任何实色都盖不干净）。
   *
   * ⚠️ 传参形式（本机 SDK 已核）：`CustomBuilder = (() => any) | void`（`common.d.ts:28415`），
   *   所以 `.overlay(箭头函数, ...)` 与 `.overlay(@Builder 调用, ...)` 两种**类型上都合法**；
   *   这里用箭头（`this` 词法绑定、且是 `CustomBuilder` 的规范形态）。
   *   **若真机上"文字整段消失"**（`DST_IN` 没有按离屏合成分解）⇒ 删掉 `.overlay(...)`，
   *   退化路径有两个：① 把 {@link MetaFadeMask} 当"meta 容器 `Stack` 的最后一个子节点"
   *   （`Stack` 后写者在上层；用 `LayoutPolicy.matchParent` 铺满，不贡献固有尺寸 ⇒ 布局等价）；
   *   ② 只用下面那两个 `Text` 的 `Ellipsis`（保留它的原因就是这条降级路径）。
   * @returns 遮罩 Builder
   */
  @Builder
  private MetaFadeMask() {
    Row()
      .width('100%')
      .height('100%')
      .linearGradient({
        // 从左到右：`META_FADE_START_RATIO` 之前完全不透明（保留文字）、之后渐隐到全透明（擦掉）。
        direction: GradientDirection.Right,
        colors: [
          ['#FF000000', 0.0],
          ['#FF000000', HomeMiniBarPlayerAside.META_FADE_START_RATIO],
          ['#00000000', 1.0]
        ]
      })
      // `DST_IN`：结果 = 下方内容 × 本节点的 alpha ⇒ 只是"擦"，不引入任何颜色。
      .blendMode(BlendMode.DST_IN)
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 一颗操作按钮（上游 `wujie.pa:69480-69522` + `:69528-69573`）：
   * **40 × 40 的 `Stack`**（点击热区）包一颗 `SymbolGlyph`（只有 `fontSize` / `fontColor`）。
   * @param icon 符号资源
   * @param color 图标颜色
   * @param action 点击回调
   * @returns 按钮 Builder
   */
  @Builder
  private ActionButton(icon: Resource, color: ResourceColor, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph(icon)
        .fontSize(PlayerConstants.MINI_ACT_ICON)
        .fontWeight(FontWeight.Regular)
        .fontColor([color])
    }
    .width(PlayerConstants.MINI_ACT_SIZE)
    .height(PlayerConstants.MINI_ACT_SIZE)
    // 上游 `clickEffect({ level: ClickEffectLevel.LIGHT })`（`wujie.pa:69510`）。
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(() => {
      action();
    })
  }

  /**
   * Lays out metadata column, optional previous track, play/pause, next, and queue buttons.
   */
  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ★ 上游那 4vp（`:69044`）落在"meta ↔ 操作区"之间 ⇒ 本仓的落点就是这里。
      Row({ space: HomeMiniBarPlayerAside.META_ACTIONS_GAP_VP }) {
        // ══════════ ② meta 容器：上游 `:69317-69393` 逐条 ══════════
        //   Stack(TopStart) + layoutWeight(1) + clip(true) + blendMode(SRC_OVER, OFFSCREEN) + overlay(渐变)
        Stack({ alignContent: Alignment.TopStart }) {
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
              // 降级路径：遮罩失效时至少还是"省略号"，不会变成硬切（见 MetaFadeMask 的注释）。
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
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        // ★ 全场**唯一**吃权重的一段：空间不足时先挤歌名（鸿蒙的异型屏/折叠屏/宽屏下
        //   条宽差别很大，不能靠写死宽度），按钮簇必须留在条内。
        .layoutWeight(PlayerConstants.LAYOUT_WEIGHT_PLAYER_CONTROL)
        // ⚠️ 允许被压缩到 0（默认的 minWidth 会把权重让不出去）
        .constraintSize({ minWidth: 0 })
        // 上游 `.clip(true)`（`:69353-69357`）：文字超出这一块就裁掉（再由遮罩擦成透明）。
        .clip(true)
        // 上游 `.blendMode(SRC_OVER, BlendApplyType.OFFSCREEN)`（`:69360-69369`）：
        // 把"文字 + 遮罩"先画到离屏画布，遮罩的 `DST_IN` 才不会擦到胶囊背景上。
        .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
        // 上游 `.overlay({ builder: metaFadeMask }, { align: Alignment.TopStart })`（`:69372-69384`）。
        // ⚠️ 这里写成箭头函数形式：`overlay(value: string | CustomBuilder | ComponentContent, ...)` 的
        //   `CustomBuilder = () => any` ⇒ 箭头把 `this` 词法绑住、类型上必然成立；
        //   而"直接调用式"（`.overlay(this.MetaFadeMask(), ...)`）要靠编译器把 @Builder 调用
        //   改写成 builder 槽，`overlay` 是否在改写名单里无法在无编译环境下确认。
        .overlay((): void => { this.MetaFadeMask(); }, { align: Alignment.TopStart })
        // 元信息那一档的透明度（真实迷你条恒 1，克隆层按 metaOpacityAt 传值）
        .opacity(this.isMorphClone ? this.metaOpacity :
          (this.expandState.sourceBarHidden ? 0 : this.metaOpacity))
        // 被封面"推着往右走"（反编译 λ1e 的 `coverRightShiftAt`）；真实迷你条恒 0
        .translate({ x: this.metaShiftX })
        .onClick(() => {
          this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
        })

        if (!this.actionsOutside) {
        // ══════════ ③ 操作按钮簇：**不给 layoutWeight**，每颗按钮 40 × 40 先占位 ══════════
        Row({ space: PlayerConstants.MINI_ACT_GAP }) {
          if (this.showPreviousTrack) {
            this.ActionButton($r('sys.symbol.backward_end_fill'), $r('app.color.mini_bar_primary'), () => {
              this.playerViewModel.playPrevious();
            })
          }
          // ★★★ 2026-10-18（用户：「点暂停/播放，歌会停/放，但按钮样式不刷新」）：
          //   与 `MiniBarActions` 同一处根因：`@Builder` **按值传参**不登记依赖（官方
          //   《@Builder 参数传递》），三目在调用点就求值成 `Resource` 传进去 ⇒ 图标永不刷新。
          //   改成在 `build()` 里**直接**读 `appState.isPlay`。
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph(this.playerViewModel.appState.isPlay ?
              $r('sys.symbol.pause_round_triangle_fill') :
              $r('sys.symbol.play_round_triangle_fill'))
              .fontSize(PlayerConstants.MINI_ACT_ICON)
              .fontWeight(FontWeight.Regular)
              .fontColor([$r('app.color.icon_primary')])
          }
          .width(PlayerConstants.MINI_ACT_SIZE)
          .height(PlayerConstants.MINI_ACT_SIZE)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .onClick(() => {
            this.playerViewModel.togglePlayPause();
          })
          this.ActionButton($r('sys.symbol.forward_end_fill'), $r('app.color.mini_bar_primary'), () => {
            this.playerViewModel.playNext();
          })
          this.ActionButton($r('sys.symbol.music_note_list'), $r('app.color.icon_primary'), () => {
            this.showPlaylistSheet = true;
          })
        }
        // 每个按钮固定占位（含点击热区），保证"列表按钮"永远有位置
        .height(PlayerConstants.MINI_ACT_SIZE)
        .alignItems(VerticalAlign.Center)
        // ★ 尾部留白：让最右边的"播放列表"按钮**再往左一点**（用户按观感要求的 4~8vp）。
        //   ⚠️ 只加在这里 —— 克隆层复用同一个组件，所以这一处改完，
        //      真身与克隆**同时**跟着走，不会出现两者不一致。
        //   ⚠️ 不要用右 padding 去压：那会把 `MINI_ACT_SIZE` 的点击热区一起压掉。
        .margin({ right: HomeMiniBarPlayerAside.ACTIONS_TRAIL_GAP_VP })
        .displayPriority(PlayerConstants.DISPLAY_PRIORITY_MINI_ACTIONS)
        .flexShrink(0)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
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
    // ★ 量的是**整块 aside**（歌名/歌手 + 右侧按钮），不是里面那个 meta 容器：
    //   克隆层要按这个宽度还原排布 —— 只给 meta 那一列的宽度会让克隆挤成一条，
    //   右侧三个按钮被推到左边（用户实测两次都是这个症状）。
    // 形变锚点 MINI_BAR_ASIDE_ID 已随重构搬到 {@link MiniBarActions} 的根节点（上游挂在操作区上）。
  }
}
