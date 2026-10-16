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
  AmbientState, AppStorageKeys, getWindowInfoState, ImmersiveType, MINI_BAR_ID, PlayerExpandState,
  StyleConstants, WindowInfo
} from 'musicbasic';
import { MusicAppState, PlayerConstants, PlayerViewModel } from 'player';
import { HomeMiniBarAlbumCover } from './HomeMiniBarAlbumCover';
import { HomeMiniBarPlayerAside } from './HomeMiniBarPlayerAside';

/**
 * Mini player shell: album cover with shared-element id, aside controls, padding by expand state,
 * vertical pan to full screen.
 */
@ComponentV2
export struct HomeMiniBarPlayer {
  /** Player VM shared with cover and aside. */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** Global music UI state (mini bar expanded, play state). */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /**
   * 整页形变状态：只用来读"迷你条该淡到多少"（对标无界 `MiniMorph.alpha = 1 - p/0.20`）。
   *
   * 为什么迷你条要让位：播放页那条可视矩形是从**迷你条封面**的位置长出来的，
   * 前 20% 只有封面的一两倍宽，而整条迷你条（封面 + 歌名 + 按钮）有 300 多 vp ——
   * 不让位就是"一条迷你条右边窜出个方块"，不是无界那种"播放条逐渐变大"。
   * 静止态它恒返回 1，所以不展开时逐像素不变。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  /** Passed through to {@link HomeMiniBarPlayerAside} to toggle previous-track visibility. */
  @Param showPreviousTrack: boolean = false;
  /**
   * When false, row padding ignores global expand (list-style inset).
   * Cover image sizing is adjusted in HomeMiniBarAlbumCover.
   */
  @Param followAppMiniBarExpanded: boolean = true;
  /**
   * 锁定封面为 44vp（单排折叠态）。二级页面悬浮胶囊在外层固定了 56vp 高度，
   * 封面必须跟着固定，否则 HDS 栏排布变化会把封面缩到 30vp。
   */
  @Param lockTwoRowCoverSize: boolean = false;
  /** 上拉打开播放页（跟手）：驱动共享形变进度，收尾补间交给壳层。 */
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });

  /** 窗口装饰状态：决定背板用哪一档底色（与 {@link PlaylistFloatingMiniBar} 同一套 token）。 */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** 环境光档位：决定背板的模糊强度（与首页底栏材质同档）。 */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;

  /**
   * 上拉起手后补量终点锚点的重试次数 / 间隔（ms）。
   *
   * 与 `PlaybackPage` 的 12 × 32ms 是同一个窗口（对标反编译 `schedulePublishRetry`）：
   * 播放页是起手那一刻才挂载的，"它的大封面什么时候可量"取决于布局帧数。
   */
  private static readonly PULL_ANCHOR_RETRY_MAX: number = 12;
  private static readonly PULL_ANCHOR_RETRY_MS: number = 32;

  private effectiveMiniBarExpanded(): boolean {
    return this.followAppMiniBarExpanded && this.playerViewModel.appState.miniBarExpanded;
  }

  // ─────────────────────── ★ 自绘背板（修用户实测「播放条背景不弹」）───────────────────────

  /**
   * 背板底色 —— 与 {@link PlaylistFloatingMiniBar.miniBarBackground} **同一套 token**（不另造颜色）。
   */
  private miniBarBackplateColor(): ResourceColor {
    if (this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE) {
      return $r('app.color.floating_mini_bar_immersive_background');
    }
    return $r('app.color.floating_mini_bar_background');
  }

  /** 背板模糊档 —— 与 {@link PlaylistFloatingMiniBar.miniBarBlur} 同档。 */
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
   * ★★★ 2026-10-16（用户实测「**关闭播放器只有内容会弹，播放条背景不弹**」+ 用户拍板方案 A）：
   * **迷你条改成自绘背板**，这样它与内容在同一棵子树里 ⇒ `morphSquashY` 一起压、一起弹。
   *
   * ## 为什么非要自绘
   *
   * 原来这条迷你条的背板是 **HDS 底栏自己画的**（我们根 `Row` 的 `backgroundColor` 从来没设过，
   * 是透明的）⇒ `Row.scale({y: morphSquashY})` 只能压到内容，**背板压不到**
   * —— 这正是"光文字弹一下"的机制。我们在原生 HDS 里也没法给那块背板单独加变换。
   *
   * ## 现在怎么接（两侧各一处开关）
   *
   * | 位置 | 改动 |
   * | --- | --- |
   * | 首页（`Index.ets` 的 `barFloatingStyle.miniBar`） | `enableMiniBarBackground: false` ⇒ HDS **不再给迷你条画背板**（页签胶囊那块背板不受影响，它是另一块） |
   * | 二级页（`Index.floatingMiniBar` 的 HdsTabs） | `barBackgroundColor(Color.Transparent)` + `barBackgroundBlurStyle(BlurStyle.NONE)` |
   * | 本组件 | 背板由这一层自绘，挂在**与内容同一个 `Stack`** 里 ⇒ 跟着一起压 |
   *
   * ⚠️ **两侧必须一起改**：只关 HDS 那份而这里不画 ⇒ 迷你条底下会空一块（能看到首页内容透上来）。
   * ⚠️ 颜色/模糊/圆角**全部复用既有 token**（`floating_mini_bar_*` + `comp_divider` + 28vp），
   *   与 {@link PlaylistFloatingMiniBar} 逐字一致 —— 不新增任何自编颜色。
   */
  @Builder
  private MiniBarBackplate() {
    Column()
      .width(LayoutPolicy.matchParent)
      .height(LayoutPolicy.matchParent)
      .backgroundColor(this.miniBarBackplateColor())
      .backgroundBlurStyle(this.miniBarBackplateBlur())
      // 圆角/描边口径与 `PlaylistFloatingMiniBar` 一致（沉浸态不描边、不圆角）
      .borderRadius(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 28)
      .borderWidth(this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 0 : 1)
      .borderColor($r('app.color.comp_divider'))
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 上拉起手后补量"续飞封面"的终点锚点。
   *
   * 播放页是**起手那一刻**才挂载的，所以第一帧量不到它的大封面（`getFrameNodeById` 返回空）。
   * 反编译侧靠 `onPullReady` 回调补量；这里用同样的窗口（12 × 32ms）轮询，
   * 一旦量到就按当前进度重落几何（`measureMiniDuringPull` 内部做），
   * 于是"手指已经拖到一半、封面才出现"也能立刻接上，不会一直缺这一棒。
   *
   * ★★ 2026-10-15（`派音动画Bug清单.md` **P1-10**）：形参补上**默认值 `= 0`**，
   *    并把守卫从 `attempt >= MAX` 加宽成 `!Number.isFinite(attempt) || attempt >= MAX`。
   *    为什么：同一份逻辑本仓有**三个副本**（本文件 / `MiniBarPlayer.ets` / 壳层
   *    `products/default/.../Index.ets` 的 `schedulePullAnchorRemeasure`），
   *    原来**只有 `MiniBarPlayer` 带默认值**。一旦哪条路径写成无参调用：
   *    `undefined >= 12` 在 JS 语义下是 **false** ⇒ **不早退、照跑**；
   *    而递归那一句传的是 `attempt + 1` = **NaN**，`NaN >= 12` 同样是 false
   *    ⇒ 每 32ms 一个定时器，**永远停不下来**。当前唯一的调用点传了 `0`，
   *    所以线上没触发 —— 这是"下次改就会踩"的护栏，不是修现状。
   *    ⚠️ 壳层那第三个副本属禁区文件（`products/default/src/main/ets/pages/Index.ets`
   *    `:565`），**本轮没动**，需要壳层配合（见本轮报告"需要壳层配合的条目"）。
   * @param attempt 已经尝试过的次数（默认 0；非有限数一律直接返回）
   */
  private schedulePullAnchorRemeasure(attempt: number = 0): void {
    if (!Number.isFinite(attempt) || attempt >= HomeMiniBarPlayer.PULL_ANCHOR_RETRY_MAX) {
      return;
    }
    const gen: number = this.expandState.morphGen;
    setTimeout((): void => {
      // 手势已经收尾 / 页面已卸载 / 换了一轮形变：不再补量
      if (!this.expandState.pullDragging || !this.expandState.morphGenAlive(gen)) {
        return;
      }
      if (this.expandState.measureMiniDuringPull(this.getUIContext(), false)) {
        return;
      }
      this.schedulePullAnchorRemeasure(attempt + 1);
    }, HomeMiniBarPlayer.PULL_ANCHOR_RETRY_MS);
  }

  /**
   * @returns 胶囊的**左**内边距（vp）：`高度/2 − 封面边长/2`。
   *
   * 这是逆向规格里 `MiniPlayer.sidePad` 的原式（`MiniPlayer胶囊布局与宽度约束.md` §三）：
   * 语义是"让封面在胶囊里垂直居中、且封面左边缘与内边距左边缘对齐"。
   * 折叠态高度 `40 × 1.4 = 56`、封面 `40 × 0.8 = 32` ⇒ `sidePad = 12`。
   *
   * ★★ 2026-10-15（配套"播放条更粗"那条）：本仓的迷你条封面走
   *   `HomeMiniBarAlbumCover.coverSideLengthVp()`，而**沉浸式自由窗口**那一档正好也是
   *   `40 × MINI_COVER_RATIO` 的**视觉**尺寸（见那个方法的注释）——
   *   所以"封面边长"这一项在这里**直接用 40**（= 无界的 `coverEdge()` 值），
   *   而不是再乘一次 `MINI_COVER_RATIO`（那会算出 32，内边距偏大 4vp/边，
   *   把这轮刚加厚的 8vp 又吃回去一半）。
   *   `h/2 − cover/2 = 56/2 − 40/2 = 8` ⇒ 封面上下各贴 8vp、水平左缘贴 8vp。
   */
  private sidePadVp(): number {
    const h: number = this.effectiveMiniBarExpanded()
      ? PlayerConstants.MINI_BAR_CONTENT_H
      : PlayerConstants.MINI_BAR_CONTENT_H * PlayerConstants.MINI_BAR_COLLAPSED_RATIO;
    const cover: number = PlayerConstants.MINI_BAR_CONTENT_H;
    return h / 2 - cover / 2;
  }

  /**
   * @returns 胶囊的**右**内边距（vp）：`sidePad() + （未量到高度时的 MINI_EDGE_PAD）`。
   *
   * ⚠️ 左右**不对称**是规格里就有的（反编译 `actionsTrail()`；`capsuleH` 已量到时为 0 增量
   *    = 左右相等，未量到时右侧多 10vp）。这里我们没有"capsuleH 已量到"这个信号，
   *    一律按折叠态那一档给（这也是首页迷你条的常态）。
   *    **绝不能在右侧额外加 16 之类的大值** —— 之前右侧给 16、左侧给 6，
   *    右侧那 16vp 会和按钮簇抢宽度，把"播放列表"按钮挤出可见胶囊。
   */
  private actionsTrailVp(): number {
    const expanded: boolean = this.effectiveMiniBarExpanded();
    const extra: number = expanded ? 0 : PlayerConstants.MINI_EDGE_PAD;
    return this.sidePadVp() + extra;
  }

  /**
   * Composes cover and aside in a row with gesture to open the full player on upward pan.
   */
  build() {
    // ★★★ 2026-10-16（方案 A）：外层换成 `Stack`，**背板与内容在同一个变换域里** ——
    //   所以下面那一记 `morphSquashY`（挂在根节点的 `.scale` 上）会**连背板一起压**，
    //   观感就是用户要的「关闭时整条播放条一起弹」。
    //   ⚠️ 这两层必须在**同一个** `Stack` 内、且 `.scale` 挂在 `Stack` 上：
    //     挂到内层 `Row` 上就又变成"只压内容"（那正是改前的形状）。
    Stack({ alignContent: Alignment.Center }) {
      // 背板在下、内容在上（`Stack` 后写者在上）
      this.MiniBarBackplate()
      Row({ space: 8 }) {
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
        // 操作区：`MiniMorph.actionsOpacityAt = clamp(1 - t/0.20)`，比封面那档更早消失
        .opacity(this.expandState.miniBarOpacity())
    }
    // ★ 非对称内边距（照抄逆向规格 `MiniPlayer.sidePad / actionsTrail`）：
    //   左 = 高度/2 − 封面/2（让封面贴住内容左边缘、垂直居中），右 = 左 + 折叠态 10vp。
    //   ⚠️ 原来折叠态给的是 `BreakpointType(16,24,32,32)`（左右**完全对称**且大到 32vp），
    //      横向净宽被吃掉 64vp，右边那 32vp 正好压在按钮簇上 —— 这是"列表按钮被挤出播放条"
    //      的另一半原因（见 `MiniPlayer胶囊布局与宽度约束.md` 第六节第 2、3 条）。
    .padding({
      left: this.sidePadVp(),
      // ★ 用户 2026-10-12：「右边三个按钮往左移动一点」——二级页面这条胶囊里，内容宽 = 胶囊宽，
      //   而 `actionsTrailVp()` 是照**首页那条**（内容比胶囊宽）定的 ⇒ 按钮簇贴着胶囊右缘。
      //   折叠态（= 二级页面，`followAppMiniBarExpanded === false`）再收一份 `sidePadVp()`，
      //   与左侧封面到胶囊左缘的距离同一个口径，不放新的魔法数；首页那条完全不变。
      right: this.actionsTrailVp() + (this.followAppMiniBarExpanded ? 0 : this.sidePadVp()),
      top: 8,
      bottom: 8,
    })
    .alignItems(VerticalAlign.Center)
    .width(StyleConstants.FULL_WIDTH)
    }
    // ⚠️ `Stack` **没有** `alignItems`（那是 `Row`/`Column` 的）—— 用 `.alignContent(Alignment.Center)`
    //   给背板与内容同一个居中基准（本轮编译期实测：`Property 'alignItems' does not exist on type
    //   'StackAttribute'`，ArkTS 报错码 10505001）。
    .alignContent(Alignment.Center)
    .width(StyleConstants.FULL_WIDTH)
    // ★ 展开形变的**起点矩形**就是这条胶囊：给个 id 让 `getFrameNodeById` 量它
    // （`onAreaChange` 给的是布局几何、不含祖先 transform，量出来的起点会偏）
    .id(MINI_BAR_ID)
    .visibility(this.expandState.sourceBarHidden ? Visibility.Hidden : Visibility.Visible)
    // ★★ 挤压（`morphSquashY`）挂在**Stack**上 ⇒ 背板与内容**同一个变换域**、一起压。
    //   出处：无界 `squashLand` / `animateSquash`（`SQUASH_Y = 0.86` 压 110ms，
    //   再 320ms `cubic-bezier(0.34,1.56,0.64,1)` 过冲回弹）。
    //   ⚠️ 静止态 `morphSquashY` 恒为 1 ⇒ **不改变任何静态版面**（回归红线）。
    //   补间由 `PlayerExpandState.squashLandAnim` 用 `animateTo` 起 ⇒ 这里**不要**再加
    //   `.animation(...)`（两套一起上会互相覆盖）。
    .scale({ x: 1, y: this.expandState.morphSquashY })
    // ⚠️ 这里**不要**给整条 Row 加透明度：反编译里迷你条是**两档**淡出 ——
    //    右侧操作区 `1 - t/0.20` 先没、封面/元信息 `1 - t/0.35` 后没。
    //    两档分别在 `HomeMiniBarPlayerAside` 与 `HomeMiniBarAlbumCover` 上生效，
    //    在 Row 上加一份会把封面也按 0.20 提前淡掉（就分不出先后了）。
    .onClick((): void => {
      this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
    })
    .gesture(
      PanGesture(this.panOption)
        .onActionStart((): void => {
          if (this.appState.isShowPlay) {
            return;
          }
          const ok: boolean = this.expandState.pullOpenBegin(this.getUIContext(), false);
          if (!this.appState.isShowPlay) {
            this.appState.isShowPlay = true;
          }
          if (!ok) {
            this.expandState.pullDragging = false;
            this.expandState.morphReset();
            this.expandState.morphSettleOpen();
            return;
          }
          // ★ 起手这一刻播放页**刚挂载**，它的封面节点还没布局完（量不到）——
          //   而"续飞封面"的终点正是它。补量几次（对标反编译 `onPullReady` 回调里那次补量），
          //   免得手指一路往上拖、屏上却只有底色窗口在长大、一张封面都看不到。
          //   补量成功后就按当前进度重落一次几何，收尾时不会跳。
          this.schedulePullAnchorRemeasure(0);
          // ★ 壳层浮层那份续飞封面（`Index.MorphCoverClone`）也压回起点：
          //   它有自己的进度 `morphOverlayP`（静止态初值是 1），不压回 0 的话
          //   浮层的第一帧会按"落位的大封面"画一次。
          this.expandState.morphOverlayReset();
        })
        .onActionUpdate((event: GestureEvent): void => {
          if (!this.expandState.pullDragging) {
            return;
          }
          this.expandState.applyMorphProgress(this.expandState.pullOpenFraction(event.offsetY));
          // 跟手期两层必须同值（否则松手补间时会先跳一下浮层那个进度）
          this.expandState.syncMorphOverlayFromPage();
        })
        .onActionEnd((event: GestureEvent): void => {
          if (!this.expandState.pullDragging) {
            return;
          }
          // ★ 提交判据**只有一份**：`PlayerExpandState.pullOpenShouldCommit()`
          //   （清单 §一 1.2「进度 OR 速度」）—— 原来这里只判 `>= 0.45`，
          //   "位移不大但甩得很快"打不开。判据收敛后，两条迷你条 + 壳层三处一致。
          this.expandState.requestPullOpenSettle(
            this.expandState.pullOpenShouldCommit(this.expandState.morphP,
              event.offsetY, event.velocityY));
        })
        .onActionCancel((): void => {
          if (!this.expandState.pullDragging) {
            return;
          }
          this.expandState.requestPullOpenSettle(false);
        })
    )
  }
}
