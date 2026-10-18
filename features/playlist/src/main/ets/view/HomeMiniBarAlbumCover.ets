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
  AppStorageKeys,
  BarLayoutModes,
  ImmersiveType,
  Logger,
  MINI_BAR_COVER_ID,
  MusicAppState,
  PlayerExpandState,
  SdkApiUtil,
  SdkConstants,
  areaLengthToVp,
  getWindowInfoState,
  WindowInfo
} from 'musicbasic';
import { PlayerConstants, PlayerViewModel } from 'player';

/** 迷你条封面的组件 id（常量定义已提到 common 层，见 PlayerExpandState.ets）。 */
export { MINI_BAR_COVER_ID } from 'musicbasic';

/**
 * 迷你播放条的封面（专辑图 + 进度环 + 播放节奏图标）。
 *
 * ══════════════════ 一、封面尺寸：照搬无界的「32 盒 + scale」机制 ══════════════════
 *
 * 无界 `MiniPlayer` 的封面**不是**直接给 44.8，而是（`wujie.pa:66221-66330`）：
 * ```
 *   coverEdge()   = 40 × MINI_COVER_RATIO(0.8) = 32      // 未缩放的封面盒
 *   coverScale2() = (capsuleH × 0.8) / 32                // capsuleH = 56 ⇒ 1.4
 *   视觉封面       = 32 × 1.4 = 44.8 = capsuleH × 0.8
 * ```
 * ⇒ 本章的落地（{@link capsuleHeightVp} > 0 时）：**布局盒 = 32、`.scale(1.4)`、外层按视觉尺寸 44.8 参与排布**。
 *
 * ⚠️ 为什么外层（参与 `Row` 排布的那一层）要用**视觉尺寸**而不是 32（这一条是本仓与上游的唯一结构差异）：
 *   上游把 `.id(coverNodeId)` 挂在**被 scale 的 32 节点**上，并用 `getRectById` 里那条
 *   `halfW = size.width × (1 − scale.x) / 2` 修正把"位置"和"尺寸"拉回同一个坐标口径
 *   （`ComponentRect.ets`，见 `PlayerExpandState.measureNode()` 的注释 (a)）。
 *   本仓 `common/musicbasic/**` **禁改**（形变起点只能吃 `getMeasuredSize()` 的**布局**尺寸，没有 scale 修正路径）
 *   ⇒ 若照搬"32 布局盒"，`miniSize` 会从 44.8 掉到 32（−12.8vp）：播放页形变起手那一帧
 *   「续飞封面」会比真封面小一圈（`reportMini` / `PlayerExpandState.miniSize` 是它的唯一来源）。
 *   ⇒ 把 32 盒 `scale(1.4)` 画在**等视觉尺寸的外层**里：**可见像素与上游逐像素相同**，
 *     而布局盒 = 视觉盒 ⇒ 形变起点尺寸不变。恒等式不变：
 *     `视觉左边距 = capsuleH/2 − 视觉封面/2 = 28 − 22.4 = 5.6 = 上/下留白`。
 *
 * ══════════════════ 二、`capsuleHeightVp`（宿主口径） ══════════════════
 * · `> 0`（首页 miniBar 槽那条 / 二级页悬浮胶囊那条）：走上面的上游机制，**不再有 30/40/44 三个写死的档位**；
 * · `= 0`（没有 HDS 底栏可接的自绘条：推荐页 `HomeFloatingMiniBar`、歌单页 `PlaylistFloatingMiniBar`）：
 *   保持旧的"按窗口装饰/展开态选一档"逻辑，**逐字不变**（那两处不受本轮改动影响）。
 */
@ComponentV2
export struct HomeMiniBarAlbumCover {
  /** Player VM providing cover URI, progress, and play/expand state. */
  @Param playerViewModel: PlayerViewModel = new PlayerViewModel();
  /**
   * Home HDS: cover image 56vp when bar collapsed, 44vp when expanded.
   * Embedded (`false`): cover image always 44vp.
   *
   * ⚠️ 只在 {@link capsuleHeightVp} 为 0（自绘条）时生效；走上游 scale 机制时两个迷你条都传 `true`/`false` 无关。
   */
  @Param followAppMiniBarExpanded: boolean = true;
  /**
   * 锁定封面为「双层底栏 · 上下两排 · 折叠态」的尺寸（30vp）。
   *
   * 二级页面的悬浮胶囊要和**首页底栏双层时上面那条**长得一模一样，那一条在
   * 上下两排时封面就是 30vp；但这个尺寸正常是靠 `isTwoRowBarLayout()` 读 HDS 栏排布
   * 算出来的，而二级页面根本没有底栏，读到的值不可靠 —— 所以由调用方直接锁定。
   *
   * ⚠️ 同样只在 {@link capsuleHeightVp} 为 0 时生效（走上游机制时封面由胶囊高推出来）。
   */
  @Param lockTwoRowCoverSize: boolean = false;
  /**
   * **宿主给的胶囊高**（vp）—— 上游 `MiniPlayer.capsuleH` 的等价物（`wujie.pa:67492`）。
   *
   * · `> 0`：封面走 {@link coverScale} 的上游机制（32 盒 × scale，视觉 = 胶囊高 × 0.8）；
   * · `= 0`（缺省）：宿主没有给高度（自绘条）⇒ 退回旧档位逻辑。
   */
  @Param capsuleHeightVp: number = 0;
  /** Window info for immersive vs standard mini bar layout. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** 全局播控状态：双层底栏「上下两排」时封面收缩到 30vp（仅自绘条那条路用）。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** 共享展开几何：迷你条封面要把自己的窗口矩形上报进去（展开动画的起点端点）。 */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /** 上游 `coverEdge() = 40 × MINI_COVER_RATIO(0.8) = 32`（`wujie.pa:66221-66230`）：**未缩放**的封面盒。 */
  private static readonly MINI_COVER_EDGE_VP: number = 32;
  /** 上游 `MINI_COVER_RATIO = 0.8`（theme/Tokens）：视觉封面边长 / 胶囊高。 */
  private static readonly MINI_COVER_RATIO: number = 0.8;
  /** 尺寸过渡（上下两排 <-> 单排、或胶囊高档位切换）时长，沿用旧值。 */
  /** 上游 BAR_ANIM：封面 scale(coverScale2) 也挂这条动画（wujie.pa:69167-69209，值 :70120）。 */
  private static readonly COVER_SIZE_ANIM_MS: number = 350;

  /**
   * @returns Progress denominator for the ring; at least 1 to avoid division issues.
   */
  private progressTotal(): number {
    const max = this.playerViewModel.appState.progressMax;
    return max > 0 ? max : 1;
  }

  /**
   * @returns True when window uses immersive decor (compact title-area treatment).
   */
  private isImmersiveFreeWindowCover(): boolean {
    return this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE;
  }

  private effectiveMiniBarExpanded(): boolean {
    return this.followAppMiniBarExpanded && this.playerViewModel.appState.miniBarExpanded;
  }

  /** Cover image side / radius only (ring matches): list/embedded 44vp; home 56vp iff collapsed. */
  private isCompactMiniBarCover(): boolean {
    return !this.followAppMiniBarExpanded || this.playerViewModel.appState.miniBarExpanded;
  }

  /**
   * 双层底栏是否处于「上下两排」：此时迷你条只占半排，封面需要收缩到 30vp，
   * 否则会把页签那一排挤出去（musicfreeOH 的同款处理）。
   * @returns True when the HDS bar is in two-row (VERTICAL) layout.
   */
  private isTwoRowBarLayout(): boolean {
    if (!this.followAppMiniBarExpanded) {
      return false;
    }
    if (!SdkApiUtil.isDistributionOsApiAtLeast(SdkConstants.DISTRIBUTION_OS_6_1_1_CODE)) {
      return false;
    }
    return this.appState.hdsBarLayoutMode === BarLayoutModes.VERTICAL;
  }

  /**
   * @returns True = 走上游「32 盒 + `scale`」机制（宿主把胶囊高告诉了我们）。
   *
   * 判据与无界 `coverScale2()` 的 `capsuleH > 0` 分支逐字同义（`wujie.pa:66289-66327`：
   * 量到胶囊高就用它推封面，否则才退回"折叠/展开"的估算档）。
   */
  private usesUpstreamCoverScale(): boolean {
    return this.capsuleHeightVp > 0;
  }

  /**
   * @returns 无界 `coverScale2()`（`wujie.pa:66289-66327`）：`(capsuleH × 0.8) / 32`。
   *
   * `capsuleH = 56` ⇒ **1.4**；返回 1 就是"没有 scale"（自绘条那条老路）。
   */
  private coverScale(): number {
    if (!this.usesUpstreamCoverScale()) {
      return 1;
    }
    return (this.capsuleHeightVp * HomeMiniBarAlbumCover.MINI_COVER_RATIO) /
      HomeMiniBarAlbumCover.MINI_COVER_EDGE_VP;
  }

  /**
   * @returns 封面**布局盒**的边长（vp）。
   *
   * 上游机制下恒为 **32**（`coverEdge()`）；否则退回旧档位（40 / 30 / 44 / 56）。
   * 旧档位只服务"宿主不给胶囊高"的两条自绘迷你条，**逐字未改**。
   */
  private coverBoxEdgeVp(): number {
    if (this.usesUpstreamCoverScale()) {
      return HomeMiniBarAlbumCover.MINI_COVER_EDGE_VP;
    }
    return this.legacyCoverSideVp();
  }

  /**
   * @returns 封面**视觉**边长（vp）= 布局盒 × scale（56 ⇒ 32 × 1.4 = **44.8** = 胶囊高 × 0.8）。
   *
   * ★ 这一层（{@link coverVisualEdgeVp}）就是参与 `Row` 排布、也参与形变起点测量的盒子，
   *   证据与理由见类注释第一节那条 ⚠️。
   */
  private coverVisualEdgeVp(): number {
    return this.coverBoxEdgeVp() * this.coverScale();
  }

  /**
   * @returns 旧档位（`capsuleHeightVp === 0` 时的封面边长，vp）。
   *
   * 四个档位：
   *   · 沉浸式自由窗口 → **40**；
   *   · 双层底栏 · 上下两排（`hdsBarLayoutMode === VERTICAL` 且发行版 ≥ 6.1.1(24)）→ **30**；
   *   · 单排（`HORIZONTAL`，= 用户说的"单层"）→ **44**；
   *   · 其余（首页未展开）→ **56**。
   */
  private legacyCoverSideVp(): number {
    if (this.isImmersiveFreeWindowCover()) {
      return 40;
    }
    if (this.lockTwoRowCoverSize || this.isTwoRowBarLayout()) {
      return 30;
    }
    return this.isCompactMiniBarCover() ? 44 : 56;
  }

  /**
   * @returns 封面圆角（vp）—— 恒为"盒子的一半"=
   *
   * 旧实现返回的是**边长**（40/30/44/56），靠 `borderRadius > size/2` 被裁成圆；
   * 本轮统一成 `边长/2`：视觉不变，但"圆角 = 半径"从此是恒等式（不再依赖裁剪）。
   */
  private coverBorderRadiusVp(): number {
    return this.coverBoxEdgeVp() / 2;
  }

  /** Only the short two-row cover shifts; the tall single-row cover keeps its original position. */
  private coverOffsetXVp(): number {
    if (this.usesUpstreamCoverScale()) {
      // 上游机制下"视觉左边距"由 `sidePad = 胶囊高/2 − 视觉封面/2` 保证（`HomeMiniBarPlayer`），
      // 这里**不再**做任何横向微调 —— 那 6vp 是给旧档位 30 的矮封面补偿用的。
      return 0;
    }
    // 用户反馈（双层底栏的矮播放条）：-4vp 还是略微偏右，再往左挪一点点（-6vp 合计）。
    return !this.isImmersiveFreeWindowCover() && (this.lockTwoRowCoverSize || this.isTwoRowBarLayout()) ? -6 : 0;
  }

  /**
   * Stacks cover image, optional ring progress, and rhythm icon.
   *
   * 结构（照搬无界 `MiniPlayer` 的封面那两节点，`wujie.pa:69159-69216`）：
   * ```
   * Stack(Center)                      外层：布局盒 = 视觉边长（44.8）⇒ 承载 .id(MINI_BAR_COVER_ID) / onAreaChange
   *   └ Stack(Center)                  封面盒：32（上游 coverEdge）
   *       .scale({x: s, y: s})         上游 coverScale2（56 ⇒ 1.4）⇒ 视觉 44.8
   *       └ Image(...)                 只有它跟着 scale 一起放大
   *   + Progress(Ring)                 进度环：按**视觉**边长给（1.8vp 描边不被放大）
   *   + SymbolGlyph(rhythm)            节奏图标：按**视觉**给字号
   * ```
   * ⚠️ 进度环与节奏图标**不进 scale**：无界 `Cover` 组件内部没有还原（见
   *   `上游-MiniPlayer内容组件树全量.ets` §9 未确认清单），而它们乘 1.4 会变成 33.6/19.6 的巨图标
   *   ⇒ 这两个装饰件保持"视觉尺寸不变"，只有专辑图走上游的缩放机制。
   */
  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ① 封面盒：32（上游 `coverEdge()`），`scale` 才是 44.8 的来源。
      Stack({ alignContent: Alignment.Center }) {
        Image(this.playerViewModel.songCoverUrl().length > 0 ?
          this.playerViewModel.songCoverUrl() : this.playerViewModel.songCover())
          .width(this.coverBoxEdgeVp())
          .height(this.coverBoxEdgeVp())
          .borderRadius(this.coverBorderRadiusVp())
      }
      .width(this.coverBoxEdgeVp())
      .height(this.coverBoxEdgeVp())
      // 上游 `Stack().scale({ x: coverScale2(), y: coverScale2() })`（`wujie.pa:69185-69200`）。
      .scale({ x: this.coverScale(), y: this.coverScale() })
      if (!this.isImmersiveFreeWindowCover()) {
        Progress({
          value: this.playerViewModel.appState.progress,
          total: this.progressTotal(),
          type: ProgressType.Ring
        })
          .width(this.coverVisualEdgeVp())
          .height(this.coverVisualEdgeVp())
          .backgroundColor($r('app.color.mini_bar_cover_ring_track'))
          .color($r('app.color.mini_bar_cover_ring_progress'))
          .style({ strokeWidth: '1.8vp' })
          .blendMode(BlendMode.OVERLAY)
      }
      if (this.playerViewModel.appState.isPlay) {
        SymbolGlyph($r('sys.symbol.rhythm'))
          .fontSize(this.isImmersiveFreeWindowCover() ? 14 : 24)
          .fontWeight(FontWeight.Regular)
          .height(this.isImmersiveFreeWindowCover() ? 14 : 24)
          .fontColor([$r('app.color.mini_bar_cover_rhythm_glyph')])
      }
    }
    // ★ 外层 = **视觉**盒：参与 Row 排布、也参与形变起点测量（理由见类注释第一节 ⚠️）。
    .width(this.coverVisualEdgeVp())
    .height(this.coverVisualEdgeVp())
    // 档位切换（上下两排 30 <-> 单排 44；或胶囊高档位变化）时尺寸平滑过渡，不要瞬跳。
    // ⚠️ 只能紧跟 `width/height` —— `.animation()` 只作用于**它前面**那些属性；
    //   放到 `opacity/translate` 之后会把形变期逐帧驱动的透明度也变成 500ms 补间（观感错）。
    .animation({ duration: HomeMiniBarAlbumCover.COVER_SIZE_ANIM_MS, curve: Curve.Friction })
    // 展开形变的起点端点就用这一层：它是"没被 scale 的那一层"，
    // `getMeasuredSize()` 拿到的就是视觉边长（44.8），与 `reportMini` 同一个坐标口径。
    .id(MINI_BAR_COVER_ID)
    // 形变期间按反编译的 `MiniMorph.metaOpacityAt = clamp(1 - t/0.35)` 淡出：
    // 封面这一档比右侧按钮（`actionsOpacityAt = 1 - t/0.20`）**晚**消失，
    // 观感就是用户描述的"按钮先没、文字/封面后没"。
    .opacity(this.expandState.miniBarMetaOpacity())
    .translate({ x: this.coverOffsetXVp() })
    // 把迷你条封面的窗口矩形报给共享状态：它是"展开动画"的起点端点。
    // 与播放页大封面的 reportBig 配对，两个端点齐了以后整页形变才有依据。
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const visual: number = areaLengthToVp(newValue.width);
      this.expandState.reportMini(
        areaLengthToVp(newValue.globalPosition.x) + this.coverOffsetXVp(),
        areaLengthToVp(newValue.globalPosition.y),
        visual,
        visual / 2);
      Logger.info('RzdMiniCoverLayout',
        `visual=${visual} y=${areaLengthToVp(newValue.globalPosition.y)} ` +
          `box=${this.coverBoxEdgeVp()} scale=${this.coverScale()} capsule=${this.capsuleHeightVp} ` +
          `radius=${visual / 2} offsetX=${this.coverOffsetXVp()} ` +
          `twoRow=${this.isTwoRowBarLayout()} lockedShort=${this.lockTwoRowCoverSize} ` +
          `upstreamScale=${this.usesUpstreamCoverScale()}`);
    })
  }
}
