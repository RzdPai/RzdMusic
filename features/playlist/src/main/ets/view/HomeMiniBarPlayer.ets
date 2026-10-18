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

import { AppStorageV2 } from '@kit.ArkUI';
import {
  AmbientState, AppStorageKeys, areaLengthToVp, getWindowInfoState, ImmersiveType, Logger, MINI_BAR_ID,
  PlayerExpandState, StyleConstants, WindowInfo
} from 'musicbasic';
import { MusicAppState, PlayerViewModel } from 'player';
import { HomeMiniBarAlbumCover } from './HomeMiniBarAlbumCover';
import { HomeMiniBarPlayerAside } from './HomeMiniBarPlayerAside';

/**
 * 迷你播放条**内容**：无界 `design/components/MiniPlayer.ets` 的 V2 移植版（第六轮整块照搬）。
 *
 * ══════════════════════ 一、照搬的是哪一段字节码 ══════════════════════
 *
 * 组件树 = `wujie.pa:65971-66144`（`MiniPlayer.#~@0>#bar`），属性 = `:69039-69522`：
 *
 * ```
 * Row({ space: 4 })                                    ★ 胶囊本体 Row          :69044
 *   .animation(BAR_ANIM)                                                       :69053
 *   .width("100%")                                                             :69062
 *   .height(capsuleH > 0 ? capsuleH : undefined)                               :69070-69085
 *   .padding({ left: sidePad(), right: actionsTrail() })                       :69090-69103  ← 只有左右
 *   .id(barNodeId)                                                             :69108
 *   │
 *   ├─ Row({ space: 0 }).layoutWeight(1).onClick(...)   左段                  :69128-69153
 *   │    ├─ Stack().scale({x:s,y:s}).id(coverNodeId)   ① 封面外层             :69159-69210
 *   │    └─ Stack({alignContent:TopStart}).layoutWeight(1)…  ② meta 容器      :69317-69393
 *   │
 *   └─ Row({ space: MINI_ACT_GAP }).id(actionsNodeId)  ③ 操作区（**无** weight） :69451-69474
 *        ├─ Stack().width(40).height(40).clickEffect(LIGHT) → SymbolGlyph(24)  :69480-69573
 *        ├─ Stack() …                                                          :69579-…
 *        └─ Stack() …                                                          :69667-…
 * ```
 *
 * ══════════════════════ 二、本仓的三条落地约定（每条都有依据，不是简化） ══════════════════════
 *
 * ① **胶囊高度是入参常量，不是量测值**。
 *    无界 `capsuleH` 是 `@Local` 实测（`:66149` setter）；本仓两条宿主都由
 *    `Index.FLOATING_MINI_BAR_HEIGHT_VP`(56) 给定 ⇒ `capsuleH > 0` 恒成立。
 *    推论（`MiniPlayer胶囊布局与宽度约束.md` §三 那条恒等式的严格版）：
 *    **`actionsTrail() ≡ sidePad()`** —— 无界 `actionsTrail` 多出的 `MINI_EDGE_PAD(10)`
 *    只在 `capsuleH <= 0`（还没量到高度）时给，本仓前提不成立 ⇒ 左右必须**逐字相等**。
 *    旧的"左 12 / 右 34"（右 = `sidePad + MINI_EDGE_PAD` 再叠一份 `sidePad`）就是"内容偏右"。
 *
 * ② **`sidePad = 胶囊高/2 − 封面盒/2`**（无界 `sidePad`，`:67490-67531`；
 *    封面盒 `coverEdge() = 40 × MINI_COVER_RATIO(0.8) = 32`，`:66221-66230`）。
 *    `capsuleH = 56` ⇒ `28 − 16 = 12`，与无界同一个数、同一个算式。
 *    未钉高度（自绘胶囊宿主）时退回 `CONTENT_PAD + MINI_BAR_INNER_PAD = 12`，
 *    **逐字等于改动前**（`HomeFloatingMiniBar` / `PlaylistFloatingMiniBar` 不受影响）。
 *
 * ②′ **无界的 12 是"未缩放盒 32"的左内距，视觉留白只有 5.6**（第七轮新增，用户：
 *    「**封面离左侧太远**」）。上游把 32 的封面 `.scale(1.4)` 成 44.8（`:66289-66327`），
 *    所以它的**视觉**左边距 = `capsuleH/2 − 44.8/2 = 5.6`，与上下留白相等（封面"内接"于胶囊）。
 *    本仓没有 `.scale` 那一层（封面边长由 `HomeMiniBarAlbumCover.coverSideLengthVp()` 直接给，
 *    本轮禁改），所以**同一个算式的输入必须换成"真实的封面盒"**：
 *    `sidePad = (胶囊高 − 封面盒)/2` ⇒ 封面 44 时 **6**、40 时 **8**、30 时 **13** ——
 *    与上游同一个公式（只是 `coverEdge` 不再写死 32）；封面盒由宿主经 {@link coverSideVp} 传入。
 *    ⇒ 恒等式：**视觉左边距 ≡ 视觉上/下留白 = (胶囊高 − 封面盒)/2**（"内接"就是"不再偏右"）。
 *    封面盒未知（旧调用方不传）= 退回上游常量 32 ⇒ 逐字等于改动前。
 *
 * ③ **钉住高度时没有上下内距**。无界 `#bar` 只有 `left/right` 两个 padding 键（`:69090`），
 *    内容在给定高度的胶囊里由 `.alignItems(VerticalAlign.Center)` 竖直居中。
 *    旧实现的 `top: 8 / bottom: 8` 让行自然高 = 封面 + 16（60）> 胶囊 56 ⇒
 *    "子件比容器大"，排布交给引擎兜底 = 2~4vp 的上下漂移来源。
 *
 * ══════════════════════ 三、右侧内容为什么不可能被切 ══════════════════════
 *
 * `Row` 的右内距 = `actionsTrailVp()` = `sidePadVp()`（钉高度时 6~13，随封面盒变；见类注释 ②′）；
 * 操作区按固有宽度（3×40+2×2=124，见 `HomeMiniBarPlayerAside`）**先占位**（那里 meta 吃
 * `layoutWeight(1)`、actions 不吃）⇒ 被压缩的永远是歌名/歌手，按钮永远留在胶囊内。胶囊的横向几何见
 * `MiniBarMaterialCapsule` 类注释第三节（内容 ⊂ 实测槽 ⊂ 胶囊）与 `RzdMiniBarRect` / `RzdMiniBarFit` 日志。
 */
@ComponentV2
export struct HomeMiniBarPlayer {
  /** 本组件**再收进来**的左右让位（vp）。0 = 不让，胶囊宽度由宿主给。 */
  private static readonly MINI_BAR_SIDE_VP: number = 0;
  /**
   * 未钉高度时内容行的**上下内距**（vp）—— 那时本组件的自然高 = 封面边长 + 2 × 本值
   * （自绘胶囊宿主：封面 44 ⇒ 60vp）。钉住高度（`contentHeightVp > 0`）时**该值不生效**，
   * 见类注释第二节 ③。
   */
  private static readonly CONTENT_PAD_VP: number = 8;
  /** 未钉高度时内容再收进来的左右呼吸（vp）；钉高度时由 `sidePadVp()` 的无界算式接管。 */
  private static readonly MINI_BAR_INNER_PAD_VP: number = 4;
  /**
   * 胶囊本体 `Row` 的子节点间距（vp）—— 照抄无界 `Row({ space: 4 })`（`wujie.pa:69044`）。
   * 旧实现是 8（自造），本轮改成 4。
   */
  private static readonly CAPSULE_SPACE_VP: number = 4;
  /**
   * 无界 `coverEdge() = 40 × MINI_COVER_RATIO(0.8)` 的**解出来的值**（`wujie.pa:66221-66230`，
   * `ldai 0x28` = 40）。`sidePad()` 用它算内距，与**本仓封面的实际档位无关**
   * （本仓封面是 30/40/44/56，见 `HomeMiniBarAlbumCover.coverSideLengthVp()`，本轮禁改）。
   */
  private static readonly COVER_EDGE_DESIGN_VP: number = 32;
  /** `sidePad` 的下限（vp）：胶囊再矮也别把封面贴到胶囊圆角上。 */
  private static readonly MINI_PAD_FLOOR_VP: number = 8;
  /**
   * `contentHeightVp === 0`（不钉高度）时喂给 `constraintSize.maxHeight` 的"无上限"。
   * ArkTS 里没有 `undefined`/`Infinity` 这种"不约束"的写法（`height()` 只吃 `Length`），
   * 而 `maxHeight` 只要**大于自然高度**就等于没约束。
   */
  private static readonly CONTENT_HEIGHT_UNBOUNDED_VP: number = 4096;
  /** 上拉起点锚点补量的次数 / 间隔（ms）——与 `PlaybackPage` 的 12×32ms 同一个窗口。 */
  private static readonly PULL_ANCHOR_RETRY_MAX: number = 12;
  private static readonly PULL_ANCHOR_RETRY_MS: number = 32;

  /** Player VM shared with cover and aside. */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** Global music UI state (mini bar expanded, play state). */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /**
   * 整页形变状态：只用来读"迷你条该淡到多少"（对标无界 `MiniMorph.alpha = 1 - p/0.20`）。
   * 静止态恒为 1 ⇒ 不影响任何静置版面。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  /** Passed through to {@link HomeMiniBarPlayerAside} to toggle previous-track visibility. */
  @Param showPreviousTrack: boolean = false;
  /** When false, row padding ignores global expand (list-style inset). */
  @Param followAppMiniBarExpanded: boolean = true;
  /**
   * 锁定封面为 30vp（双层底栏 · 上下两排那一档）。
   * 二级页漂浮胶囊要与首页"上面那条"长得一样，但它读不到可靠的栏排布，只能由调用方锁。
   */
  @Param lockTwoRowCoverSize: boolean = false;
  /**
   * 是否由本组件自绘背板（{@link MiniBarBackplate}）。
   *
   * - `false`：**首页那条 / 二级页那条**（背板 + 材质由 {@link MiniBarMaterialCapsule} 里的
   *   `HdsTabs` 浮动栏画，走 `systemMaterialEffect` 官方材质）。这里再自绘一层
   *   =「官方材质 + 半透明蒙版 + 模糊」叠两层，材质被洗白。
   * - `true`（缺省）：**没有 HDS 底栏可接**的宿主（推荐页 `HomeFloatingMiniBar` /
   *   歌单页 `PlaylistFloatingMiniBar`），背板必须自己画，否则整条透明。
   */
  @Param showSelfDrawnBackplate: boolean = true;
  /**
   * 本组件根 `Stack` 是否**自己**承担挤压（`.scale({y: morphSquashY})`）。
   *
   * - `true`（缺省）：自绘胶囊宿主；背板与内容一起压/弹。
   * - `false`（住进 {@link MiniBarMaterialCapsule} 的宿主**必须**传）：挤压由胶囊那层统一负责，
   *   这里再压一次就是 0.86² = 0.74（弹过头）。
   */
  @Param contentOwnsSquash: boolean = true;
  /**
   * 把本组件**钉**成宿主给的高度（vp）；`0`（缺省）= 不钉，按自然高度排。
   *
   * 钉住之后（首页 / 二级页都传 `FLOATING_MINI_BAR_HEIGHT_VP` = 56）：
   * · 内容行不再有上下内距（类注释第二节 ③）；
   * · 行高 / 根 `Stack` 高 / 胶囊高**三者相等** ⇒ 封面在胶囊里几何居中；
   * · `sidePad` 改走无界的 `胶囊高/2 − 封面盒/2` 算式（封面盒由 {@link coverSideVp} 给，
   *   不给则用上游常量 32）。
   */
  @Param contentHeightVp: number = 0;
  /**
   * **封面实际的布局盒边长**（vp）—— 用来算无界 `sidePad = 胶囊高/2 − 封面盒/2`（类注释第二节 ②′）。
   *
   * 为什么由宿主传：封面边长由 `HomeMiniBarAlbumCover.coverSideLengthVp()`（本轮**禁改**）
   * 按"沉浸式 40 / 上下两排 30 / 单排 44"决定，本组件读不到；宿主侧各有一份同口径的档位函数
   * （`Index.homeMiniBarCoverSideVp()` / `Index.secondaryMiniBarCoverSideVp()`）。
   *
   * `0`（缺省）= 调用方不知道 ⇒ 退回上游常量 {@link COVER_EDGE_DESIGN_VP}（32）
   * ⇒ `sidePad = 12`，**逐字等于改动前**（自绘胶囊的两个宿主不受影响）。
   */
  @Param coverSideVp: number = 0;
  /** 上拉打开播放页（跟手）：驱动共享形变进度，收尾补间交给壳层。 */
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });
  /**
   * 诊断闸：本次手势是否**已经记过一次**"跟手更新被判决拒掉"。
   * 语义与用法见 `PlayerExpandState.pullDropBegin`；`onActionStart` 里清零。
   */
  private pullDropCountedThisGesture: boolean = false;

  /** 窗口装饰状态：决定背板用哪一档底色。 */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** 环境光档位：决定背板的模糊强度。 */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;

  // ─────────────────────────── 自绘背板（只在自绘胶囊宿主上生效） ───────────────────────────

  /** 背板底色 —— 与 {@link PlaylistFloatingMiniBar} 同一套 token（不另造颜色）。 */
  private miniBarBackplateColor(): ResourceColor {
    if (this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE) {
      return $r('app.color.pc_floating_mini_bar_immersive_surface');
    }
    return $r('app.color.floating_mini_bar_sheet_background');
  }

  /** 背板模糊档 —— 与 {@link PlaylistFloatingMiniBar} 同档。 */
  private miniBarBackplateBlur(): BlurStyle {
    switch (this.ambientState.level) {
      case 1:
        return BlurStyle.Thin;
      case 2:
        return BlurStyle.Regular;
      case 3:
        return BlurStyle.Thick;
      default:
        return BlurStyle.Thin;
    }
  }

  /**
   * 自绘背板：与内容在**同一个 `Stack`** 里 ⇒ 根节点上的 `.scale({y: morphSquashY})` 会把它一起压。
   * ⚠️ 与 `showSelfDrawnBackplate` 必须成对：只开不画 = 迷你条底下一块空。
   */
  @Builder
  private MiniBarBackplate() {
    Column()
      .width(LayoutPolicy.matchParent)
      .height(LayoutPolicy.matchParent)
      .backgroundColor(this.miniBarBackplateColor())
      .backgroundBlurStyle(this.miniBarBackplateBlur())
      .borderRadius(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 28)
      .borderWidth(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 1)
      .borderColor($r('app.color.comp_divider'))
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 上拉起手后补量「续飞封面」的终点锚点。
   *
   * 播放页是**起手那一刻**才挂载的，所以第一帧量不到它的大封面（`getFrameNodeById` 返回空）。
   * 反编译侧靠 `onPullReady` 回调补量；这里用同样的窗口（12 × 32ms）轮询，一旦量到就按当前进度重落几何。
   * @param attempt 已经尝试过的次数（默认 0；非有限数一律直接返回）
   */
  private schedulePullAnchorRemeasure(attempt: number = 0): void {
    if (!Number.isFinite(attempt) || attempt >= HomeMiniBarPlayer.PULL_ANCHOR_RETRY_MAX) {
      return;
    }
    setTimeout((): void => {
      // 只判 `pullDragging`（这一轮还没走完），不判"会话编号"：会话编号会被与用户意图无关的事推高。
      if (!this.expandState.pullDragging) {
        return;
      }
      if (this.expandState.measureMiniDuringPull(this.getUIContext(), false)) {
        return;
      }
      this.schedulePullAnchorRemeasure(attempt + 1);
    }, HomeMiniBarPlayer.PULL_ANCHOR_RETRY_MS);
  }

  // ─────────────────────────── 几何（全部集中在这四个函数，别处不许再算） ───────────────────────────

  /**
   * @returns 无界 `coverEdge()` 的**本仓对应量**（vp）：封面真实的布局盒边长。
   *
   * 上游写死 `40 × MINI_COVER_RATIO(0.8) = 32`（`wujie.pa:66221-66230`）—— 那是它"未缩放的 32 盒"，
   * 靠 `.scale(1.4)` 才变成视觉 44.8。本仓封面没有 scale（边长由禁改文件直接给），
   * 所以这里的输入必须是**真实盒**（由 {@link coverSideVp} 传进来）；没传时退回 32（= 逐字照搬上游）。
   */
  private coverEdgeVp(): number {
    return this.coverSideVp > 0 ? this.coverSideVp : HomeMiniBarPlayer.COVER_EDGE_DESIGN_VP;
  }

  /**
   * @returns 内容行的**左**内距（vp）= 无界 `sidePad()`。
   *
   * 钉高度（= 胶囊高已知）时：`胶囊高/2 − 封面盒/2`（`wujie.pa:67490-67531` 逐行还原）。
   *   上游 `capsuleH = 56`、封面盒 32 ⇒ `28 − 16 = 12`（本仓不传 {@link coverSideVp} 时逐字相同）；
   *   本仓封面盒 = 40/44/30 时 ⇒ **8 / 6 / 13** ⇒ 封面**内接**于胶囊
   *   （视觉左边距 ≡ 上/下留白，这就是用户第七轮「封面离左侧太远」的修法）。
   * 未钉高度（自绘胶囊宿主）时：`CONTENT_PAD(8) + MINI_BAR_INNER_PAD(4) = 12`，
   *   **逐字等于改动前**（那两个宿主的外观本轮不动）。
   */
  private sidePadVp(): number {
    if (this.contentHeightVp <= 0) {
      return HomeMiniBarPlayer.CONTENT_PAD_VP + HomeMiniBarPlayer.MINI_BAR_INNER_PAD_VP;
    }
    const pad: number = (this.contentHeightVp - this.coverEdgeVp()) / 2;
    // 封面盒已知 ⇒ 这个差就是"内接留白"，不再叠下限（下限只用于"盒未知"的兜底档）。
    const floor: number = this.coverSideVp > 0 ? 0 : HomeMiniBarPlayer.MINI_PAD_FLOOR_VP;
    return pad > floor ? pad : floor;
  }

  /**
   * @returns 内容行的**右**内距（vp）= 无界 `actionsTrail()`。
   *
   * `actionsTrail = sidePad + (capsuleH > 0 ? 0 : MINI_EDGE_PAD)`（`wujie.pa:65922-65942`）。
   * 本组件的胶囊高**由宿主给定**（`contentHeightVp > 0`）⇒ `capsuleH > 0` 恒成立 ⇒ 增量恒为 0
   * ⇒ **恒等于左内距**。`MINI_EDGE_PAD(10)` 是"还没量到高度"时的余量，本仓前提不成立。
   */
  private actionsTrailVp(): number {
    return this.sidePadVp();
  }

  /**
   * @returns 内容行的**上下**内距（vp）。
   * 钉住高度时 = **0**（无界 `#bar` 只有 left/right 两个 padding 键，`:69090`）；
   * 未钉高度时 = {@link CONTENT_PAD_VP}（那时它才是自然高的唯一来源）。
   */
  private rowPadVp(): number {
    return this.contentHeightVp > 0 ? 0 : HomeMiniBarPlayer.CONTENT_PAD_VP;
  }

  /** @returns 根 `Stack` / 内容行的**高度上限**（vp）：钉住时 = 胶囊高，否则"不约束"。 */
  private contentMaxHeightVp(): number {
    if (this.contentHeightVp > 0) {
      return this.contentHeightVp;
    }
    return HomeMiniBarPlayer.CONTENT_HEIGHT_UNBOUNDED_VP;
  }

  /**
   * @returns 根 `Stack` / 内容行的**高度下限**（vp）。
   * 钉住时 = 胶囊高（`min == max == 胶囊高` ⇒ 行盒 ≡ 胶囊盒，封面在其中几何居中）；
   * 未钉时 = 0（纯新增约束，行为与改动前逐字一致）。
   */
  private contentMinHeightVp(): number {
    return this.contentHeightVp > 0 ? this.contentHeightVp : 0;
  }

  build() {
    // 外层 `Stack`：自绘背板与内容在**同一个变换域**里（`.contentOwnsSquash` 决定 `.scale` 挂不挂这里）。
    Stack({ alignContent: Alignment.Center }) {
      // 背板在下、内容在上（`Stack` 后写者在上面）
      if (this.showSelfDrawnBackplate) {
        this.MiniBarBackplate()
      }
      // ★ 胶囊本体 Row —— 逐条照搬无界 `MiniPlayer.#~@0>#bar`（`wujie.pa:69039-69122`）：
      //   `space: 4` / `width: 100%` / `padding: { left: sidePad, right: actionsTrail }`。
      Row({ space: HomeMiniBarPlayer.CAPSULE_SPACE_VP }) {
        HomeMiniBarAlbumCover({
          playerViewModel: this.playerViewModel,
          followAppMiniBarExpanded: this.followAppMiniBarExpanded,
          lockTwoRowCoverSize: this.lockTwoRowCoverSize
        })
        HomeMiniBarPlayerAside({
          playerViewModel: this.playerViewModel,
          showPreviousTrack: this.showPreviousTrack,
          floatingMeta: !this.followAppMiniBarExpanded
        })
          // 操作区：`MiniMorph.actionsOpacityAt = clamp(1 - t/0.20)`，比封面那一档更早消失
          .opacity(this.expandState.miniBarOpacity())
      }
      .padding({
        left: this.sidePadVp(),
        right: this.actionsTrailVp(),
        top: this.rowPadVp(),
        bottom: this.rowPadVp()
      })
      .alignItems(VerticalAlign.Center)
      .width(StyleConstants.FULL_WIDTH)
      // 钉住时 `min == max` ⇒ 行盒 ≡ 胶囊盒；未钉时 `[0, 4096]` ⇒ 完全等价于不约束。
      .constraintSize({ minHeight: this.contentMinHeightVp(), maxHeight: this.contentMaxHeightVp() })
    }
    .alignContent(Alignment.Center)
    .width(StyleConstants.FULL_WIDTH)
    .constraintSize({ minHeight: this.contentMinHeightVp(), maxHeight: this.contentMaxHeightVp() })
    // 只加**横向**内距（缺省 0 ⇒ 无变化）；上下由上面的约束负责。
    .padding({ left: HomeMiniBarPlayer.MINI_BAR_SIDE_VP, right: HomeMiniBarPlayer.MINI_BAR_SIDE_VP })
    // 展开形变的**起点矩形**就是这一层：给个 id 让 `getFrameNodeById` 量它
    // （`onAreaChange` 给的是布局几何、不含 transform，量出来的起点会偏）。
    .id(MINI_BAR_ID)
    .visibility(this.expandState.sourceBarHidden ? Visibility.Hidden : Visibility.Visible)
    // 诊断（`hdc shell hilog | grep RzdMiniBarGeom`）：本行**实测**矩形 + 左右内距。
    // 判据：`padL == padR`（内容中心 ≡ 胶囊中心）、`cap > 0` 时 `h == cap`（行盒 ≡ 胶囊盒）、
    //       `padL == opticalGap`（封面**内接**：视觉左边距 ≡ 上/下留白 ⇒ 用户说的"离左侧太远"消失）。
    .onAreaChange((_oldArea: Area, area: Area): void => {
      const opticalGap: number = this.contentHeightVp > 0 ?
        (this.contentHeightVp - this.coverEdgeVp()) / 2 : -1;
      Logger.info('RzdMiniBarGeom',
        `content h=${areaLengthToVp(area.height)} y=${areaLengthToVp(area.globalPosition.y)} ` +
          `x=${areaLengthToVp(area.globalPosition.x)} ` +
          `w=${areaLengthToVp(area.width)} pinned=${this.contentHeightVp} ` +
          `cap=${this.contentMaxHeightVp()} pad=${this.rowPadVp()} ` +
          `padL=${this.sidePadVp()} padR=${this.actionsTrailVp()} ` +
          `coverBox=${this.coverSideVp} coverEdge=${this.coverEdgeVp()} ` +
          `opticalGap=${opticalGap} ` +
          `space=${HomeMiniBarPlayer.CAPSULE_SPACE_VP} ` +
          `hosting=${this.followAppMiniBarExpanded ? 'home' : 'floating'} ` +
          `selfPlate=${this.showSelfDrawnBackplate} ownSquash=${this.contentOwnsSquash} ` +
          `squashY=${this.expandState.morphSquashY}`);
    })
    // 挤压：出处 `MainPage.squashLand` / `animateSquash`（0.86 压 110ms，再 320ms 过冲回弹）。
    // 静止态 `morphSquashY` 恒为 1 ⇒ 不改任何静置版面。
    .scale({ x: 1, y: this.contentOwnsSquash ? this.expandState.morphSquashY : 1 })
    .onClick((): void => {
      this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
    })
    .gesture(
      PanGesture(this.panOption)
        .onActionStart((): void => {
          // 诊断闸复位：见 `pullDropCountedThisGesture`（三条跟手链都必须接计数）。
          this.pullDropCountedThisGesture = false;
          if (this.appState.isShowPlay) {
            return;
          }
          const ok: boolean = this.expandState.pullOpenBegin(this.getUIContext(), false);
          if (!this.appState.isShowPlay) {
            this.appState.isShowPlay = true;
          }
          if (!ok) {
            // 与壳层 `onPullOpenStart` 的 `!morphOk` 支同义 ⇒ 记同一个数（`pullDropBegin`）。
            this.expandState.notePullDropBegin();
            this.expandState.pullDragging = false;
            this.expandState.morphReset();
            this.expandState.morphSettleOpen();
            return;
          }
          // 起手这一刻播放页刚挂载，它的大封面还没布局完 ⇒ 补量几次（对标 `onPullReady` 里那次补量）。
          this.schedulePullAnchorRemeasure(0);
          // 壳层浮层那份续飞封面的进度也压回起点，否则浮层第一帧会按"落位的大封面"画一次。
          this.expandState.morphOverlayReset();
        })
        .onActionUpdate((event: GestureEvent): void => {
          if (!this.expandState.pullDragging) {
            // 诊断：一次手势只记一次（理由见 `pullDropCountedThisGesture`）。
            if (!this.pullDropCountedThisGesture) {
              this.pullDropCountedThisGesture = true;
              this.expandState.notePullDropUpdate();
            }
            return;
          }
          this.expandState.applyMorphProgress(this.expandState.pullOpenFraction(event.offsetY));
          // 跟手期两层必须同值（否则松手补间时会先跳一下浮层那个进度）
          this.expandState.syncMorphOverlayFromPage();
        })
        .onActionEnd((event: GestureEvent): void => {
          if (!this.expandState.pullDragging) {
            this.expandState.notePullDropEnd();
            return;
          }
          // 提交判据只有一份：`PlayerExpandState.pullOpenShouldCommit()`（进度 OR 速度）
          this.expandState.requestPullOpenSettle(
            this.expandState.pullOpenShouldCommit(this.expandState.morphP,
              event.offsetY, event.velocityY));
        })
        .onActionCancel((): void => {
          if (!this.expandState.pullDragging) {
            this.expandState.notePullDropEnd();
            return;
          }
          this.expandState.requestPullOpenSettle(false);
        })
    )
  }
}
