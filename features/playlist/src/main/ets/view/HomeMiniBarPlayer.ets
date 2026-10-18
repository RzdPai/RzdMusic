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
  AmbientState, AppStorageKeys, areaLengthToVp, BarLayoutModes, getWindowInfoState, ImmersiveType, Logger,
  MINI_BAR_ID, PlayerExpandState, SdkApiUtil, SdkConstants, StyleConstants, WindowInfo
} from 'musicbasic';
import { MusicAppState, PlayerViewModel } from 'player';
import { HomeMiniBarAlbumCover } from './HomeMiniBarAlbumCover';
import { HomeMiniBarPlayerAside } from './HomeMiniBarPlayerAside';
import { MiniBarActions } from './MiniBarActions';

/**
 * 迷你播放条**内容**：无界 `design/components/MiniPlayer.ets` 的 V2 移植版。
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
 * ```
 *
 * ══════════════════════ 二、四条落地约定（每条都有依据，不是简化） ══════════════════════
 *
 * ① **胶囊高度是入参常量，不是量测值**。
 *    无界 `capsuleH` 是 `@Local` 实测（`:66149` setter）；本仓两条宿主都由
 *    `Index.FLOATING_MINI_BAR_HEIGHT_VP`(56) 给定 ⇒ `capsuleH > 0` 恒成立。
 *    推论：**`actionsTrail() ≡ sidePad()`** —— 无界 `actionsTrail` 多出的 `MINI_EDGE_PAD(10)`
 *    只在 `capsuleH <= 0`（还没量到高度）时给，本仓前提不成立 ⇒ 左右必须**逐字相等**。
 *
 * ② **`sidePad = 胶囊高/2 − 视觉封面/2`**（无界 `sidePad`，`:67490-67531`）。
 *    无界那里写的是 `h/2 − coverEdge/2`（`coverEdge = 32`）后再把封面 `.scale(1.4)` 放大成 44.8，
 *    视觉左边距 = `12 − coverOverflow(6.4)` = **5.6**；本仓的封面组件把 32 盒
 *    `scale(1.4)` 画在**等视觉尺寸的外层**里（理由见 `HomeMiniBarAlbumCover` 类注释第一节 ⚠️），
 *    参与排布的盒就是 44.8 ⇒ 同一个恒等式直接写成视觉口径：
 *    ```
 *    sidePad = (胶囊高 − 视觉封面)/2 = (56 − 44.8)/2 = 5.6 = 上/下留白
 *    ```
 *    ⇒ **封面内接于胶囊**（用户第七轮「封面离左侧太远」的修法），且
 *      `sidePad + 视觉封面 + sidePad ≡ 胶囊高`（横纵两个方向同一个留白）。
 *    未钉高度（自绘胶囊宿主）时退回 `CONTENT_PAD + MINI_BAR_INNER_PAD = 12`，
 *    **逐字等于改动前**（`HomeFloatingMiniBar` / `PlaylistFloatingMiniBar` 不受影响）。
 *
 * ③ **钉住高度时没有上下内距**。无界 `#bar` 只有 `left/right` 两个 padding 键（`:69090`），
 *    内容在给定高度的胶囊里由 `.alignItems(VerticalAlign.Center)` 竖直居中。
 *    旧实现的 `top: 8 / bottom: 8` 让行自然高 = 封面 + 16（60）> 胶囊 56 ⇒
 *    "子件比容器大"，排布交给引擎兜底 = 2~4vp 的上下漂移来源。
 *
 * ④ **胶囊 `Row` 的子节点间距 = 0**（本轮从 4 改成 0）。
 *    上游那个 4（`:69044`）落在"左段（封面 + meta）"与"操作区 `Row`"之间，
 *    而本仓的操作区在 `HomeMiniBarPlayerAside` 内部 ⇒ 4 必须搬到那里
 *    （`HomeMiniBarPlayerAside.META_ACTIONS_GAP_VP`），这里再留 4 就成了
 *    "封面→meta 也 4vp"（上游没有这一段缝：meta 的左缘就是封面的**视觉**右缘）。
 *
 * ══════════════════════ 三、右侧内容为什么不可能被切 ══════════════════════
 *
 * `Row` 的右内距 = `actionsTrailVp()` = `sidePadVp()`（钉高度时 5.6；见 ②）；
 * 操作区按固有宽度（3×40+2×2=124，见 `HomeMiniBarPlayerAside`）**先占位**（那里 meta 吃
 * `layoutWeight(1)`、actions 不吃）⇒ 被压缩的永远是歌名/歌手，按钮永远留在胶囊内。
 * 胶囊的横向几何见 `MiniBarMaterialCapsule` 类注释第三节（二级页）与
 * 首页那条的 HDS `miniBar` 槽（`Index.ets` 的 `miniBar()`）。
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
  /** 未钉高度时内容再收进来的左右呼吸（vp）；钉高度时由 `sidePadVp()` 的上游算式接管。 */
  private static readonly MINI_BAR_INNER_PAD_VP: number = 4;
  /**
   * 胶囊本体 `Row` 的子节点间距（vp）。
   *
   * ★ 2026-10-21（第八轮）：**0**。上游那个 `space: 4`（`wujie.pa:69044`）是
   *   "左段（封面 + meta）↔ 操作区"之间的缝，本仓操作区在 Aside 内部 ⇒ 4 归
   *   `HomeMiniBarPlayerAside.META_ACTIONS_GAP_VP`；这里再留 4 会让"封面→meta"多出一道
   *   上游没有的缝（上游 meta 左缘 ≡ 封面视觉右缘）。见类注释第二节 ④。
   */
  private static readonly CAPSULE_SPACE_VP: number = 0;
  /**
   * 无界 `coverEdge() = 40 × MINI_COVER_RATIO(0.8)` 的**解出来的值**（`wujie.pa:66221-66230`）。
   * 只在"宿主没给胶囊高"（`contentHeightVp === 0`）时用于诊断日志。
   */
  private static readonly COVER_EDGE_DESIGN_VP: number = 32;
  /**
   * 无界 `BAR_CONTENT_H = 40`（`MiniPlayer` 模块 lexvar `0x2`）—— **低矮档**的胶囊内容高。
   * 出处是 `sidePad` 字节码的折叠支（`wujie.pa:67515-67517`：`h = BAR_CONTENT_H`）。
   */
  private static readonly BAR_CONTENT_H_VP: number = 40;
  /** 上游 `MINI_COVER_RATIO = 0.8`（theme/Tokens）：视觉封面边长 / 胶囊高。 */
  private static readonly MINI_COVER_RATIO: number = 0.8;
  /**
   * `contentHeightVp === 0`（不钉高度）时喂给 `constraintSize.maxHeight` 的"无上限"。
   * ArkTS 里没有 `undefined`/`Infinity` 这种"不约束"的写法（`height()` 只吃 `Length`），
   * 而 `maxHeight` 只要**大于自然高度**就等于没约束。
   */
  private static readonly CONTENT_HEIGHT_UNBOUNDED_VP: number = 4096;
  /** 上游 BAR_ANIM = { duration: 350, curve: Curve.Friction }（wujie.pa:70120-70126）。 */
  private static readonly BAR_ANIM: AnimateParam = { duration: 350, curve: Curve.Friction };
  /** 上拉起点锚点补量的次数 / 间隔（ms）——与 `PlaybackPage` 的 12×32ms 同一个窗口。 */
  private static readonly PULL_ANCHOR_RETRY_MAX: number = 12;
  private static readonly PULL_ANCHOR_RETRY_MS: number = 32;

  /** Player VM shared with cover and aside. */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /**
   * ★ 2026-10-18（用户第十轮）：**这一行自己的实测高度**（0 = 还没量到）。
   * 封面与内距一律以它为准（= 上游「封面内接于胶囊」），不再吃宿主钉的那个数——
   * 宿主钉 56 而真机双行态只有 40 时，按 56 算出来的封面（44.8）会比条还高。
   */
  @Local measuredRowHVp: number = 0;
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
   * 只有"宿主没给胶囊高"的自绘条才有意义（见 `HomeMiniBarAlbumCover.legacyCoverSideVp()`）。
   */
  @Param lockTwoRowCoverSize: boolean = false;
  /**
   * 是否由本组件自绘背板（{@link MiniBarBackplate}）。
   *
   * - `false`：**首页那条 / 二级页那条**（背板 + 材质由宿主画：首页是壳层 `HdsTabs` 的
   *   `miniBar` 槽——`enableMiniBarBackground` 缺省 true；二级页是 `MiniBarMaterialCapsule`
   *   里的 `HdsTabs` 浮动栏）。这里再自绘一层 =「官方材质 + 半透明蒙版 + 模糊」叠两层，材质被洗白。
   * - `true`（缺省）：**没有 HDS 底栏可接**的宿主（推荐页 `HomeFloatingMiniBar` /
   *   歌单页 `PlaylistFloatingMiniBar`），背板必须自己画，否则整条透明。
   */
  @Param showSelfDrawnBackplate: boolean = true;
  /**
   * 本组件根 `Stack` 是否**自己**承担挤压（`.scale({y: morphSquashY})`）。
   *
   * - `true`：**首页那条**（住在壳层 `HdsTabs` 的 `miniBar` 槽里）与自绘胶囊宿主 ——
   *   上游对首页那条的挤压正挂在 `miniBar` 槽的**内容**上（也就是 `MiniPlayer` 根），
   *   所以本组件根 `Stack` 就是那个落点（`wujie.pa:157082-157228` 的 `__Common__` 包 `MiniPlayer`）。
   * - `false`（住进 {@link MiniBarMaterialCapsule} 的**二级页**那条**必须**传）：
   *   挤压由胶囊那层统一负责，这里再压一次就是 0.86² = 0.74（弹过头）。
   */
  @Param contentOwnsSquash: boolean = true;
  /**
   * 把本组件**钉**成宿主给的高度（vp）；`0`（缺省）= 不钉，按自然高度排。
   *
   * 钉住之后（首页 / 二级页都传 `FLOATING_MINI_BAR_HEIGHT_VP` = 56）：
   * · 内容行不再有上下内距（类注释第二节 ③）；
   * · 行高 / 根 `Stack` 高 / 胶囊高**三者相等** ⇒ 封面在胶囊里几何居中；
   * · `sidePad` 改走上游算式 `(胶囊高 − 视觉封面)/2`（类注释第二节 ②）。
   */
  @Param contentHeightVp: number = 0;
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

  // ─────────────────────────── 几何（全部集中在这三个函数，别处不许再算） ───────────────────────────

  /**
   * @returns 封面的**视觉边长**（vp）—— 上游 `coverScale2 = (capsuleH × 0.8)/32` 的分子。
   *
   * 钉住高度（胶囊高已知）时：`胶囊高 × MINI_COVER_RATIO(0.8)` = **44.8**（56 时），
   *   与 `HomeMiniBarAlbumCover.coverVisualEdgeVp()` **逐值相等**（那里也是 32 × 1.4）。
   * 未钉高度（自绘胶囊宿主）时：返回上游 `coverEdge`(32)，只用于日志
   *   （那种宿主不传 `sidePad` 的这条分支，见 {@link sidePadVp}）。
   */
  private coverVisualEdgeVp(): number {
    // ★ 2026-10-18（用户第十轮）：基准优先用**实测行高**（= 真实胶囊高），实测不到才用宿主钉的值。
    const base: number = this.capsuleBaseHVp();
    if (base > 0) {
      return base * HomeMiniBarPlayer.MINI_COVER_RATIO;
    }
    return HomeMiniBarPlayer.COVER_EDGE_DESIGN_VP;
  }

  /** @returns 封面/内距的**基准高度**（vp）：低矮档优先，其次是宿主钉的高度，最后是实测行高。 */
  private capsuleBaseHVp(): number {
    if (this.contentHeightVp > 0) {
      return this.isLowProfileBar() ? HomeMiniBarPlayer.BAR_CONTENT_H_VP : this.contentHeightVp;
    }
    return this.measuredRowHVp > 0 ? this.measuredRowHVp : 0;
  }

  /**
   * @returns 是否处于**低矮档**（无界 `collapsed === true` 那一档，`h = BAR_CONTENT_H = 40`）。
   *
   * 本仓把无界的 `MiniPlayer.collapsed` 映射到 **HDS 栏排布 = 上下两排（VERTICAL）**：
   * 无界那个 `collapsed` 由 `design/logic/BarCollapse`（`wujie.pa:83856` `isCollapsed()`）驱动，
   * 语义就是"迷你条处于**矮**那一档"；本仓能与它一一对应的可见状态只有 HDS 的
   * `hdsBarLayoutMode === VERTICAL`（迷你条独占一排、与页签栏上下叠放，用户口中的"双行"）。
   * 判据的 SDK 门槛与 `HomeMiniBarAlbumCover.isTwoRowBarLayout()` 逐字相同（同一份 HDS 字段）。
   */
  private isLowProfileBar(): boolean {
    if (!this.followAppMiniBarExpanded) {
      return false;
    }
    if (!SdkApiUtil.isDistributionOsApiAtLeast(SdkConstants.DISTRIBUTION_OS_6_1_1_CODE)) {
      return false;
    }
    return this.appState.hdsBarLayoutMode === BarLayoutModes.VERTICAL;
  }

  /**
   * @returns 内容行的**左**内距（vp）。
   *
   * 两档都落在上游那一条恒等式里 —— `视觉左边距 = 基准高/2 − 视觉封面/2`：
   * ```
   * 基准 56（单排）：(56 − 44.8)/2 = 5.6   ← 与上/下留白逐字相等（封面内接于胶囊）
   * 基准 40（低矮）：(40 − 32.0)/2 = 4.0
   * ```
   * ⚠️ 上游写的是 `h/2 − coverEdge/2`（`coverEdge` 恒 32，`wujie.pa:66221-66230`）：
   *   56 时上游得 12 —— 但上游参与排布的封面盒**是 32**，`scale(1.4)` 只放大像素不放大布局，
   *   所以上游"视觉左边距"同样是 `12 − coverOverflow(6.4) = 5.6`。本仓封面外层**就是视觉盒**
   *   （`HomeMiniBarAlbumCover` 类注释第一节 ⚠️）⇒ 同一个视觉口径直接写在这里，
   *   可见像素与上游逐像素相同、meta 左缘仍与封面视觉右缘相接。
   */
  private sidePadVp(): number {
    if (this.contentHeightVp <= 0 && this.measuredRowHVp <= 0) {
      return HomeMiniBarPlayer.CONTENT_PAD_VP + HomeMiniBarPlayer.MINI_BAR_INNER_PAD_VP;
    }
    const pad: number = (this.capsuleBaseHVp() - this.coverVisualEdgeVp()) / 2;
    return pad > 0 ? pad : 0;
  }

  /**
   * @returns 内容行的**右**内距（vp）= 无界 `actionsTrail()`。
   *
   * 上游 `actionsTrail() = sidePad() + (capsuleH > 0 ? 0 : MINI_EDGE_PAD)`（`wujie.pa:65922-65942`），
   * 而 `sidePad` 是**未放大的 32 盒**口径 ⇒ 本仓按同口径落地：
   * ```
   * (基准高 − 32)/2      56 → 12（= 上游 12）   40 → 4（= 上游 4）
   * ```
   * ⚠️ 与左内距**不相等**是有依据的：左右不等的 6.4 正是上游"封面视觉溢出"那一段
   *   （`coverOverflow = 32×(s−1)/2`，`wujie.pa:66259-66288`）—— 上游把它加在 meta 的
   *   `margin.left` 上，本仓把它并进左内距（封面外层即视觉盒，不需要再补 margin）。
   *   若把右内距也写成 5.6，操作区会比上游**往右**多跑 6.4vp。
   */
  private actionsTrailVp(): number {
    if (this.contentHeightVp <= 0 && this.measuredRowHVp <= 0) {
      return HomeMiniBarPlayer.CONTENT_PAD_VP + HomeMiniBarPlayer.MINI_BAR_INNER_PAD_VP;
    }
    const pad: number = (this.capsuleBaseHVp() - HomeMiniBarPlayer.COVER_EDGE_DESIGN_VP) / 2;
    return pad > 0 ? pad : 0;
  }

  /**
   * @returns 内容行的**上下**内距（vp）。
   * 钉住高度时 = **0**（无界 `#bar` 只有 left/right 两个 padding 键，`:69090`）；
   * 未钉高度时 = {@link CONTENT_PAD_VP}（那时它才是自然高的唯一来源）。
   */
  private rowPadVp(): number {
    return this.contentHeightVp > 0 ? 0 : HomeMiniBarPlayer.CONTENT_PAD_VP;
  }

  /** @returns 根 `Stack` / 内容行的**高度上限**（vp）：钉住时 = 基准高（低矮档会缩到 40），否则"不约束"。 */
  private contentMaxHeightVp(): number {
    if (this.contentHeightVp > 0) {
      return this.capsuleBaseHVp();
    }
    return HomeMiniBarPlayer.CONTENT_HEIGHT_UNBOUNDED_VP;
  }

  /**
   * @returns 根 `Stack` / 内容行的**高度下限**（vp）。
   * 钉住时 = 基准高（`min == max` ⇒ 行盒 ≡ 胶囊盒，封面在其中几何居中）；
   * 未钉时 = 0（纯新增约束，行为与改动前逐字一致）。
   */
  private contentMinHeightVp(): number {
    return this.contentHeightVp > 0 ? this.capsuleBaseHVp() : 0;
  }

  build() {
    // 外层 `Stack`：自绘背板与内容在**同一个变换域**里（`.contentOwnsSquash` 决定 `.scale` 挂不挂这里）。
    // ★ 住在壳层 `HdsTabs` 的 `miniBar` 槽里时，这一层就是上游 `MiniPlayer` 的根，
    //   也就是"首页那条被 `MainPage` 压一下"的落点（类注释 {@link contentOwnsSquash}）。
    Stack({ alignContent: Alignment.Center }) {
      // 背板在下、内容在上（`Stack` 后写者在上面）
      if (this.showSelfDrawnBackplate) {
        this.MiniBarBackplate()
      }
      // ★ 胶囊本体 Row —— 逐条照搬无界 `MiniPlayer.#~@0>#bar`（`wujie.pa:69039-69122`）：
      //   `space: 0`（类注释 ④）/ `width: 100%` / `padding: { left: sidePad, right: actionsTrail }`。
      Row({ space: HomeMiniBarPlayer.CAPSULE_SPACE_VP }) {
        // ★★★ 2026-10-18（照搬上游胶囊 Row 的两个直接子节点，`wujie.pa:69128-69474`）：
        //   ① 左段 `Row(space:0).layoutWeight(1)` = 封面 + meta；
        //   ② 操作区 `Row`（**无 layoutWeight**，按固有宽先占位）。
        //   原来操作区套在 `Aside(layoutWeight(1))` 里面 ⇒ 跟着 Aside 的盒子走、不受胶囊右内距约束，
        //   右端那颗「播放列表」按钮就压到胶囊圆角外。
        Row({ space: 0 }) {
          HomeMiniBarAlbumCover({
            playerViewModel: this.playerViewModel,
            followAppMiniBarExpanded: this.followAppMiniBarExpanded,
            lockTwoRowCoverSize: this.lockTwoRowCoverSize,
            // ★ 上游 `MiniPlayer.capsuleH` 的等价物：封面据此算 `coverScale2 = (capsuleH × 0.8)/32`
            //   （56 ⇒ 1.4 ⇒ 视觉 44.8）。`0`（自绘条）时封面组件退回旧档位，逐字不变。
            capsuleHeightVp: this.capsuleBaseHVp()
          })
          HomeMiniBarPlayerAside({
            playerViewModel: this.playerViewModel,
            showPreviousTrack: this.showPreviousTrack,
            floatingMeta: !this.followAppMiniBarExpanded,
            actionsOutside: true
          })
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
        MiniBarActions({
          playerViewModel: this.playerViewModel,
          showPreviousTrack: this.showPreviousTrack,
          // 操作区：`MiniMorph.actionsOpacityAt = clamp(1 - t/0.20)`，比封面那一档更早消失
          actionsOpacity: this.expandState.miniBarOpacity()
        })
      }
      // ★★★ 2026-10-18（照搬上游 `.animation(BAR_ANIM)`，`wujie.pa:69053-69057` / `:69118-69121`）：
      //   上游把 `BAR_ANIM = { duration: 350, curve: Curve.Friction }`（`wujie.pa:70120-70126`）
      //   挂在**胶囊 Row** 上，被它带的是 `height(capsuleH)` 与 `padding(left: sidePad, right: actionsTrail)`；
      //   封面的 `scale(coverScale2)` 另挂一份同名动画（见 `HomeMiniBarAlbumCover`）。
      //   ⇒ 单层↔双层切换时，格子内的高度/内距/封面缩放按 350ms Friction 补间，而不是硬切。
      //   ⚠️ 顺序照抄上游：`animation(BAR_ANIM) → 属性 → animation(null)`。
      .animation(HomeMiniBarPlayer.BAR_ANIM)
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
      .animation(null)
    }
    .alignContent(Alignment.Center)
    .width(StyleConstants.FULL_WIDTH)
    .constraintSize({ minHeight: this.contentMinHeightVp(), maxHeight: this.contentMaxHeightVp() })
    // 只加**横向**内距（缺省 0 ⇒ 无变化）；上下由上面的约束负责。
    .padding({ left: HomeMiniBarPlayer.MINI_BAR_SIDE_VP, right: HomeMiniBarPlayer.MINI_BAR_SIDE_VP })
    // 展开形变的**起点矩形**就是这一层：给个 id 让 `getFrameNodeById` 量它
    // （`onAreaChange` 给的是布局几何、不含 transform，量出来的起点会偏）。
    .id(MINI_BAR_ID)
    .visibility((this.expandState.sourceBarHidden || this.expandState.shrinkHidesBar ||
      this.expandState.miniOut) ? Visibility.Hidden : Visibility.Visible)
    // 诊断（`hdc shell hilog | grep RzdMiniBarGeom`）：本行**实测**矩形 + 左右内距。
    // 判据（钉住高度的两条迷你条）：
    //   `padL == padR`（内容中心 ≡ 胶囊中心）、`h == cap`（行盒 ≡ 胶囊盒）、
    //   `padL == opticalGap == (cap − coverVisual)/2`（封面**内接**：视觉左边距 ≡ 上/下留白）。
    .onAreaChange((_oldArea: Area, area: Area): void => {
      // ★★★ 2026-10-18（用户第十轮：「双行低高度态**封面还是偏大的大封面**」）：
      //   把**这一行自己的实测高度**记下来 —— 封面/内距要以"真实条高"为基准，
      //   不能吃宿主编给我们的那个数（宿主钉 56，而真机双行态可能只有 40 ⇒ 封面 44.8 比条还高）。
      const measuredH: number = areaLengthToVp(area.height);
      if (measuredH > 0 && Math.abs(measuredH - this.measuredRowHVp) > 0.5) {
        this.measuredRowHVp = measuredH;
      }
      const opticalGap: number = this.contentHeightVp > 0 ?
        (this.capsuleBaseHVp() - this.coverVisualEdgeVp()) / 2 : -1;
      Logger.info('RzdMiniBarGeom',
        `content h=${areaLengthToVp(area.height)} y=${areaLengthToVp(area.globalPosition.y)} ` +
          `x=${areaLengthToVp(area.globalPosition.x)} ` +
          `w=${areaLengthToVp(area.width)} pinned=${this.contentHeightVp} ` +
          `cap=${this.contentMaxHeightVp()} lowProfile=${this.isLowProfileBar()} pad=${this.rowPadVp()} ` +
          `padL=${this.sidePadVp()} padR=${this.actionsTrailVp()} ` +
          `coverVisual=${this.coverVisualEdgeVp()} ` +
          `coverScale=${this.coverVisualEdgeVp() / HomeMiniBarPlayer.COVER_EDGE_DESIGN_VP} ` +
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
