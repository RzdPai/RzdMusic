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

import { Logger } from '../util/Logger';
import { curves, UIContext } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { MorphMetaEndpoint, MorphMetaFrame } from './MorphMetaGeometry';

/**
 * 迷你条封面的组件 id。
 *
 * ⚠️ 常量必须放在公共层：迷你条在 `features/playlist`、动画宿主在 `features/player`，
 * 两边要用同一个字符串，而 features 之间**禁止互相 import**（三层架构硬约束）。
 */
export const MINI_BAR_COVER_ID: string = 'rzd_mini_bar_cover';

/** 播放页大封面的组件 id（同上，放公共层避免 features 横向依赖）。 */
export const PLAYER_BIG_COVER_ID: string = 'rzd_player_big_cover';

/**
 * ★★★ 2026-10-17（照搬无界 `PLAYER_ROOT_ID`）：**形变容器**（带 `.scale/.translate/.clip` 那个节点）的 id。
 *
 * 用途只有一个：非手势关闭（关闭按钮 / 系统返回）时
 * `componentSnapshot.get(PLAYER_ROOT_ID, …)` **拍的就是这个节点**，
 * 拍到的图交给 `MorphShrinkState`（照搬 `ShrinkOverlay`）缩到迷你条胶囊。
 * 出处：`wujie.pa:191470-191478` 的 `.id(PLAYER_ROOT_ID)`
 *   （挂在 `.scale` 191400-191415 / `.translate` 191416-191431 / `.clip` 191462-191469 之后）。
 *
 * ⚠️ 与 `PLAYER_BIG_COVER_ID` / `MESH_BG_ID` 等**不是同一个节点**（id 按节点唯一，几个互不影响）。
 * ⚠️ 快照**必须**在形变开始之前拍（静止态下这个节点就是满屏的播放页）。
 */
export const PLAYER_ROOT_ID: string = 'rzd_player_root';

/**
 * 形变阶段（对标无界 `MorphState.MorphStage`）。
 *
 * ```
 *   NONE → ENTERING（展开中，可跟手）→ OPEN（已展开）→ LEAVING（收起中）→ LANDING（落回迷你条）
 * ```
 */
export enum MorphStage {
  NONE = 0,
  ENTERING = 1,
  OPEN = 2,
  LEAVING = 3,
  LANDING = 4
}

/** 谁在驱动形变（对标 `MorphState.MorphDrive`）。 */
export enum MorphDrive {
  NONE = 0,
  /** 手指驱动：此期间**不能**跑任何给同一批属性做补间的 animateTo。 */
  FINGER = 1,
  ANIM = 2
}

/** clip 窗口在静止态向外扩张的余量（vp）：保证任何窗口尺寸都不会裁到内容。 */
const CLIP_IDLE_MARGIN_VP: number = 120;

/** 迷你条那条胶囊的组件 id（展开动画的起点矩形由它量出来）。 */
export const MINI_BAR_ID: string = 'rzd_mini_bar';

/** 二级页面悬浮迷你条的组件 id（与首页那条区分，避免 id 重名量错）。 */
export const MINI_BAR_FLOATING_ID: string = 'rzd_mini_bar_floating';

/** 二级页面悬浮迷你条封面的组件 id（首页那条用 {@link MINI_BAR_COVER_ID}）。 */
export const MINI_BAR_COVER_FLOATING_ID: string = 'rzd_mini_bar_cover_floating';

/** 宿主容器（恒为满屏的那层）的组件 id：它的窗口矩形就是"铺满"的目标与坐标原点。 */
export const MORPH_HOST_ID: string = 'rzd_morph_host';

/**
 * 可视矩形"下边先贴底"的进度点（0…1）。
 *
 * 迷你条离宿主底边还有几十 vp（HDS 浮动底栏的下边距 + 系统导航栏那一条），
 * 这个空档不能跟着线性走：否则整段动画底部都是空的（用户实测）。
 */
/**
 * 迷你条的**元信息 + 操作区**（歌名/歌手 + 播放按钮那一块）的组件 id。
 *
 * 反编译侧 `MainPage` 上有三个克隆层：封面克隆、元信息克隆、操作区克隆 ——
 * 它们都围着这一块画（`miniMeta` / `morphActionsRect`），所以要能量到它的矩形。
 */
export const MINI_BAR_ASIDE_ID: string = 'rzd_mini_bar_aside';

/** 二级页面悬浮迷你条的那一块（与首页区分，避免 id 重名量错）。 */
export const MINI_BAR_ASIDE_FLOATING_ID: string = 'rzd_mini_bar_aside_floating';

/**
 * 续飞封面（反编译侧的 `snap*`）两端点的量取入口 id。
 * 播放页封面已经用 `PLAYER_BIG_COVER_ID`，这里只需要迷你条那一侧。
 */
const MINI_COVER_MEASURE_FALLBACK: number = 0.79;

/**
 * 一个组件在窗口里的矩形（vp）。`x/y` 来自 FrameNode 的窗口坐标，`w/h` 已从 px 换算。
 * 反编译侧对应 `ComponentRect.getRectByFrameNode`：位置用
 * `getPositionToWindowWithTransform()`（vp），尺寸用 `getMeasuredSize()`（px→vp）。
 */
interface NodeRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

/**
 * 反编译侧 `initParams` 的三个 lerp 起点值（这里单独存，和它的字段一一对应）。
 * `applyPullProgress` 只在这三个值 + `t` 上做线性插值。
 */
interface MorphInitParams {
  /** `initScale = box.width / 盒宽`。 */
  scale: number;
  /** `initClipHeight = box.height / initScale`。 */
  clipHeight: number;
  /** `initTranslateX = box.left - (盒宽 - box.width) / 2`。 */
  translateX: number;
  /** `initTranslateY = box.top - scaledH * (1 - initScale) / 2`。 */
  translateY: number;
  /** 起点**可视**圆角 = `initClipHeight * initScale / 2`（= 胶囊高度的一半）。 */
  radius: number;
}

/** 「展开页 ⇄ 歌词页」续飞时封面的一帧矩形（vp，窗口坐标）。 */
export interface LyricMorphRect {
  x: number;
  y: number;
  size: number;
  /**
   * 高度（vp）。
   *
   * ⚠️ 必须与 `size` 分开存：播放页封面的容器是 `layoutWeight(1)` + `constraintSize(maxWidth/maxHeight)`
   *    + `aspectRatio(1)`，**排布上不保证量到的矩形是正方形**。按 `h = w` 画出来的续飞封面
   *    会在 p=1 交棒给真实封面的那一刻跳一下（位置与大小都对不上）。
   */
  height: number;
  radius: number;
}

/**
 * 宽屏 / 面板那种"左右两栏"布局里，两栏的目标宽度（vp）。
 *
 * ★ 2026-10-15（目标 ④ 的 S2 步）：**只装宽度，不装间距** —— 间距（`gutter` / `space`）
 * 由接线的同一处常量给出，不在这里猜（依据见 `PlayerExpandState.columnWidths()` 的注释）。
 */
export interface WideColumns {
  /** 左栏（封面 + 歌名）目标宽度（vp）。 */
  left: number;
  /** 右栏（歌词 + 控制区）目标宽度（vp）。 */
  right: number;
}

/**
 * 宿主盒内的一个点（vp）。见 `PlayerExpandState.toHostPoint()`。
 *
 * ★ 2026-10-15（目标 ④ 的 S3 前置件）：`.position()` 是**相对父组件内容盒**的绝对定位，
 * 而我们的浮层几何源（`lyricMorph` / `widePlayerRects`）给的是**窗口坐标** ⇒
 * 换宿主时必须减掉宿主自己的左上角。手机宿主左上角 = 窗口原点 ⇒ 本结构恒为 `{0, 0}`。
 */
export interface HostPoint {
  x: number;
  y: number;
}

/**
 * 无界 `PlayerChrome` 的一档控制区尺寸表（**逐字段照抄** `wujie.pa:93534 / 93554 / 93574`）。
 *
 * 字段顺序与反汇编里 `createobjectwithbuffer` 的书写顺序一致（`total` 除外 —— 它是算出来的，
 * 而且**不是**"前面几项相加"：`wujie.pa:93547-93551` 里 `v2 = 58` 是三档共用的第五项）。
 *
 * ⚠️ 不要给任何字段"补一个合理值"：表里没有的语义（例如"统一的按钮间距"）说明**无界没有它**，
 *   历史上我们往这类缺口里塞过 `18/24/30`，后来整族删除（见 `PlayerExpandState` 里
 *   `chromeGapVp` / `chromePaddingVp` 的删除记录）。
 */
export class PlayerChromeSpec {
  /** 顶栏那一行的高度（vp）。 */
  public readonly topBarH: number;
  /** Swiper 与控制区之间的**占位条**高度（vp）。⚠️ 表里这一份**只有在没有实测 `usableH` 时才用** —— 实际布局走 `playerSwiperGapOf(h)` 的连续公式。 */
  public readonly gapSwiper: number;
  /** 进度条那一行与传输条之间的**占位条**高度（vp）。这一段**没有**连续公式，就是查表。 */
  public readonly gapScrub: number;
  /** 播放/暂停主按钮的块尺寸（vp）。 */
  public readonly playSize: number;
  /** 进度条那一行的**块尺寸**（vp）。⚠️ 是触控块、不是轨道粗细（轨道粗细由 `trackThickness(12)` 管）。 */
  public readonly seekSize: number;
  /** 侧键（循环 / 播放列表）图标字号（fp）。 */
  public readonly sideSize: number;
  /** 歌名字号（fp）。 */
  public readonly titleSize: number;
  /** 歌手名字号（fp）。 */
  public readonly artistSize: number;
  /** 收藏 / 更多图标字号（fp）。 */
  public readonly favSize: number;
  /** 歌名行与封面之间的间距（vp）。 */
  public readonly metaGap: number;
  /** 底部安全边距（vp）。 */
  public readonly bottomGap: number;
  /** 歌词页整体的缩放比。 */
  public readonly lyricScale: number;
  /** 该档控制区**总高**（vp）= `topBarH + gapSwiper + gapScrub + playSize + 58`。 */
  public readonly total: number;

  constructor(topBarH: number, gapSwiper: number, gapScrub: number, playSize: number,
    seekSize: number, sideSize: number, titleSize: number, artistSize: number,
    favSize: number, metaGap: number, bottomGap: number, lyricScale: number, total: number) {
    this.topBarH = topBarH;
    this.gapSwiper = gapSwiper;
    this.gapScrub = gapScrub;
    this.playSize = playSize;
    this.seekSize = seekSize;
    this.sideSize = sideSize;
    this.titleSize = titleSize;
    this.artistSize = artistSize;
    this.favSize = favSize;
    this.metaGap = metaGap;
    this.bottomGap = bottomGap;
    this.lyricScale = lyricScale;
    this.total = total;
  }
}

/**
 * 把 `Area` 里的 `Length` 取成 vp 数值。
 *
 * `Area.width` / `Area.globalPosition.x` 的静态类型是 `Length = string | number | Resource`，
 * 直接 `Number()` 在 ArkTS 下过不了类型检查（Resource 分支没法转），所以显式收窄。
 * @param value Length 值
 * @returns vp 数值；无法解析时返回 0
 */
export function areaLengthToVp(value: Length | undefined): number {
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') {
    const parsed: number = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

/**
 * 播放页「一镜到底」展开动画的**共享几何 + 相位**。
 *
 * 为什么放在 common：迷你条在 `features/playlist`、播放页/动画宿主在 `features/player`、
 * 触发点在 products 的壳层 —— 三方都要读写同一份数据，只能放公共层
 * （只含 number / boolean / string，不引入任何 UI 组件类型，不会造成循环依赖）。
 *
 * ## 观感（参考 musicfreeOH 的 `PlayerExpandAnim`）
 *
 * 播放页**彻底不动**（始终铺在窗口原位），只做两件事：
 *   1. **clip 窗口**从「迷你条封面那个小方块」长到整屏 —— 这就是「向上下延伸铺满」；
 *   2. 另画一张**飞行封面**（见宿主里的 `Image`），从迷你条封面的矩形逐帧插值到
 *      播放页大封面的矩形 —— 这就是「封面慢慢变大并移动到整个大封面」。
 *
 * 这样做的关键好处：整页不做缩放/位移，文字与控件**全程不变形**；
 * 而且迷你条封面与播放页大封面在动画期间都被隐藏，画面上只有一张封面在飞，
 * 不会出现两张封面同时可见的重影。
 *
 * ## 相位
 *
 * ```
 *   空闲         preparing            animating             空闲
 *  progress=1 → progress=0 ────────→ progress 0→1 ────────→ progress=1
 *  （未挂载）   页面透明、量两端矩形    飞行封面可见、迷你条封面隐藏
 * ```
 *
 * `preparing` 相位是**防闪的关键**：播放页已经挂载（能测量、能布局），但整页不透明度为 0，
 * 所以看不到「播放页先整个弹出来、封面再飞过去」的断层。
 */
@ObservedV2
export class PlayerExpandState {
  /**
   * 日志 tag 的**对外副本**。
   *
   * 为什么要有它：手势提交判定那条日志写在 `PlaybackPage.onDismissDrag` 里，
   * 而那里需要的是**同一个** tag —— `hilog | grep RzdMorph` 一条命令要能同时拉到
   * 「形变几何」与「提交判定」两条链。原来的 `logTag` 是 `private`，别的类读不到。
   */
  public static readonly LOG_TAG: string = 'RzdMorph';
  /** 日志 tag：排查展开形变时 `hilog | grep RzdMorph`。 */
  private static readonly logTag: string = PlayerExpandState.LOG_TAG;

  // ───────────────────────── 相位 ─────────────────────────

  /** 播放页已挂载、正在测量两端矩形（此期间整页不透明度为 0）。 */
  @Trace public preparing: boolean = false;
  /** 一镜到底动画进行中（飞行封面可见、迷你条封面与播放页大封面隐藏）。 */
  @Trace public animating: boolean = false;
  /** 动画进度：0 = 收在迷你条位置，1 = 完全展开。 */
  @Trace public progress: number = 1;

  // ─────────────────── 起点：迷你条封面（窗口坐标 vp）───────────────────

  /** 迷你条封面在窗口中的左边界（vp）。 */
  @Trace public miniX: number = 0;
  /** 迷你条封面在窗口中的上边界（vp）。 */
  @Trace public miniY: number = 0;
  /** 迷你条封面边长（vp）。 */
  @Trace public miniSize: number = 0;
  /** 迷你条封面圆角（vp）。 */
  @Trace public miniRadius: number = 12;

  // ─────────────────── 终点：播放页大封面（窗口坐标 vp）───────────────────

  /** 播放页大封面在窗口中的左边界（vp）。 */
  @Trace public bigX: number = 0;
  /** 播放页大封面在窗口中的上边界（vp）。 */
  @Trace public bigY: number = 0;
  /** 播放页大封面边长（vp）。 */
  @Trace public bigSize: number = 0;
  /** 播放页大封面圆角（vp）。 */
  @Trace public bigRadius: number = 12;

  // ───────────────────────── 窗口与时长 ─────────────────────────

  /** 窗口宽度（vp）：clip 窗口展开的终点。 */
  @Trace public windowWidthVp: number = 360;
  /** 窗口高度（vp）：clip 窗口展开的终点。 */
  @Trace public windowHeightVp: number = 780;
  /**
   * 状态栏避让区高度（vp，真实值）—— 对标无界 `padTop()` 里的 `avoidTop`。
   * ⚠️ 由壳层在 `reportWindow()` 里喂进来；**0 表示"还没量到"**，此时 `topInsetVp()`
   *   退回比例估算（见那里的说明）。
   */
  @Trace public statusBarTopVp: number = 0;
  /**
   * 底部导航条避让区高度（vp，真实值）—— 对标无界 `padBottom()` 里的 `avoidBottom`。
   * ⚠️ 目前**只做登记与上报**，还没有消费者（`padBottom()` 那一半见 §56.24 待办）。
   */
  @Trace public navigationBarBottomVp: number = 0;
  /** 一镜到底动画时长（ms）。 */
  @Trace public durationMs: number = 460;

  /**
   * 收起请求版本号。
   *
   * 播放页的返回按钮只负责 `collapseVersion + 1`；真正的反向动画由动画宿主
   * （`PlaybackPageCoverHost`）在 `@Monitor` 里播 —— 因为只有宿主同时拥有
   * 「整页 clip」和「飞行封面」这两个需要一起动的节点。
   */
  @Trace public collapseVersion: number = 0;

  // ───────────────────────── 上报 ─────────────────────────

  /**
   * 迷你条封面上报自己在窗口中的矩形（由 `onAreaChange` 的 `globalPosition` + `width` 得来）。
   *
   * ⚠️ 用 `onAreaChange` 而不是 `getRectangleById`：后者的文档没有写单位（实测口径为 px），
   * 前者明确是 vp。动画的位移与尺寸都直接当 vp 用，单位错了会整体错位一整个密度倍。
   * @param x 左边界（vp，窗口坐标）
   * @param y 上边界（vp，窗口坐标）
   * @param size 边长（vp）
   * @param radius 圆角（vp）
   */
  public reportMini(x: number, y: number, size: number, radius: number): void {
    if (size <= 0) {
      return;
    }
    this.miniX = x;
    this.miniY = y;
    this.miniSize = size;
    this.miniRadius = radius;
  }

  /**
   * 播放页大封面上报自己在窗口中的矩形。动画宿主靠它判断「终点量到了没有」。
   * @param x 左边界（vp，窗口坐标）
   * @param y 上边界（vp，窗口坐标）
   * @param size 边长（vp）
   * @param radius 圆角（vp）
   */
  public reportBig(x: number, y: number, size: number, radius: number): void {
    if (size <= 0) {
      return;
    }
    this.bigX = x;
    this.bigY = y;
    this.bigSize = size;
    this.bigRadius = radius;
    if (radius > 0) {
      this.bigCoverRadius = radius;
    }
  }

  /**
   * 记录窗口尺寸（vp），作为 clip 窗口展开的终点。
   *
   * ★ 2026-10-15：**扩了两个可选参数**（真实避让区高度），对标无界 `padTop()`/`padBottom()`
   *   的输入。用**默认值**而不是"新增必填参数"是为了让既有调用点（`products/default`、
   *   `products/pc` 各一处）**不改也能编译**；随后逐个补传即可（"同一形状 N 处"那个老毛病
   *   的防法：先让签名兼容，再数调用点）。
   * @param widthVp 窗口宽（vp）
   * @param heightVp 窗口高（vp）
   * @param statusBarTopVp 状态栏避让高度（vp，0 = 未量到）—— 喂给 `topInsetVp()`
   * @param navigationBarBottomVp 底部导航条避让高度（vp，0 = 未量到）
   */
  public reportWindow(widthVp: number, heightVp: number,
    statusBarTopVp: number = 0, navigationBarBottomVp: number = 0): void {
    if (widthVp > 0 && heightVp > 0) {
      // ★★★ 2026-10-17（**照搬无界的 `transitionAborted`** —— 见下面那段）
      //   先判定"这一次是真的变了"（`reportWindow` 会在每次布局时被调，尺寸没变就不该做任何事）。
      const sizeChanged: boolean = this.windowWidthVp > 0 && this.windowHeightVp > 0 &&
        (Math.abs(this.windowWidthVp - widthVp) > 1 || Math.abs(this.windowHeightVp - heightVp) > 1);
      this.windowWidthVp = widthVp;
      this.windowHeightVp = heightVp;
      this.statusBarTopVp = statusBarTopVp > 0 ? statusBarTopVp : 0;
      this.navigationBarBottomVp = navigationBarBottomVp > 0 ? navigationBarBottomVp : 0;
      if (sizeChanged) {
        this.abortTransitionOnResize();
      }
    }
  }

  /**
   * ★★★ 2026-10-17（**照搬无界 `PlayerPage.transitionAborted` + `expand.setFinalStatus()`**）
   *
   * ## 无界原文（`wujie.pa:174998-175011`，在窗口尺寸变化那条链上）
   * ```ts
   *   this.swiperBoxH = …;
   *   this.refitOverlay();
   *   this.settleWideLayout();
   *   this.transitionAborted = true;      // ★ 转场作废
   *   this.expand.setFinalStatus();       // ★ 直接落到最终态（无动画）
   * ```
   * 而 `setFinalStatus()`（`ExpandAnimation.ets:346-358`）逐条是：
   * ```ts
   *   overlayColor = "#00000000"; scaleValue = 1;
   *   translateX = 0; translateY = 0;
   *   clipWidth = "100%"; clipHeight = "100%";
   *   snapOpacity = 0; contentOpacity = 1; radius = 0;
   * ```
   * ⇒ **它落的是"完全展开"那一态**（不看当时在往哪个方向走）。
   * 语义很直白：**窗口尺寸刚变过 ⇒ 之前量到的几何全作废 ⇒ 别再演动画了，把播放页直接摊开。**
   * （`λ@37*#^2` 那条注册在 `NavTransition` 上的内容转场里，`transitionAborted` 为真时走的也是这一对：
   *   `expand.setFinalStatus(); proxy.finishTransition();`）
   *
   * ## 本仓的等价物
   * `morphReset()` + `morphSettleOpen()` 就是本仓的"无动画落位到展开态"
   * （`morphSettleOpen` 会 `applyMorphProgress(1)` ⇒ `scale=1/translate=0/裁剪满`，
   *  `morphReset` 负责把浮层与本轮几何一起作废）—— 与 `setFinalStatus` 那一串逐条对应。
   *
   * ## ⚠️ 与无界的**一处刻意收窄**（记在案，别再当成漏搬）
   * 无界**不分方向**，任何相位被这次尺寸变化撞上都会 `setFinalStatus()`。
   * 本仓**只在 `ENTERING`（正在展开）时做**，理由：
   * · 本仓的关闭链路有**自己的收尾定时器**（`closeSettleTimer`，`morphCloseMs + 20`），
   *   它一定会把页面落位并卸载 ⇒ 尺寸变化时**不需要**别人插手；
   * · 若那时把页面强行摊成"完全展开"，而几百毫秒后它就要被 pop，
   *   屏上会出现**满屏播放页闪一下**（正是用户报过的第 ③ 类形状）⇒ 反而更糟。
   * ⇒ 收窄到"正在展开"这一支：那一支**没有**收尾定时器兜底（靠 `settlePullOpen` 的补量链），
   *   几何作废时最容易卡在半路 —— 而"直接摊开"正是最安全的落点。
   */
  private abortTransitionOnResize(): void {
    if (this.morphStage !== MorphStage.ENTERING) {
      return;
    }
    Logger.warn(PlayerExpandState.logTag,
      `RzdMorphAbort window resized during ENTERING (w=${this.windowWidthVp.toFixed(0)} ` +
      `h=${this.windowHeightVp.toFixed(0)}) ⇒ setFinalStatus (land fully open, no animation)`);
    this.morphReset();
    this.morphSettleOpen();
  }

  // ═════════════════════════ 一、逐元素 morph（对标 无界 MiniMorph / CoverMorph）═════════════════════════
  //
  // 无界那套的做法（从函数清单读出来的）：所有量都是 `xxxAt(progress)`，
  // 也就是**一个 progress 驱动全部插值**，而不是给每个元素各配一条 animation。
  // 好处：任意时刻打断都自洽，跟手拖动时不会出现"某个元素还在飘"。
  // 这里把它的分层补上（原来我们只有"整页 45% 淡入"一层）。

  /** 文字层（歌名/歌手）淡入区间起点。 */
  private static readonly META_FADE_FROM: number = 0.15;
  /** 文字层淡入区间终点。 */
  private static readonly META_FADE_TO: number = 0.60;
  /** 按钮层（底部控制区）淡入区间起点 —— 比文字晚，形成错落。 */
  private static readonly ACTIONS_FADE_FROM: number = 0.40;
  /** 按钮层淡入区间终点。 */
  private static readonly ACTIONS_FADE_TO: number = 1.0;

  /**
   * 把 `progress` 在 `[from, to]` 区间内归一化到 `0…1`（区间外夹紧）。
   *
   * ★★ 2026-10-15（**已判定为死代码**，`RzdMusic记忆.md` §59）：**零调用者**。
   *   它是"按进度开一个子窗口"那类公式的通用件（`clamp((p-a)/(b-a))`），
   *   而本类现在的每一条窗口都**内联展开**了（例如 `pullChromeOpacity`：
   *   `clamp((effT-0.18)/0.44)`）—— 提取成函数反而更难和反编译逐字对照，所以没接。
   * ⚠️ 留着是为了**下一处**要用时别再手写一遍（手写就有写错区间的风险）；
   *    它是 `private static` 且是**纯函数**，不会被误当成状态入口。
   * @param value 进度
   * @param from 区间起点
   * @param to 区间终点
   * @returns 归一化值
   * 复核命令：`grep -rn 'window01' RzdMusic --include=*.ets`（期望：只有本处定义）
   */
  private static window01(value: number, from: number, to: number): number {
    if (to <= from) {
      return value >= to ? 1 : 0;
    }
    const t: number = (value - from) / (to - from);
    return t < 0 ? 0 : (t > 1 ? 1 : t);
  }

  /**
   * @returns 歌名/歌手层的淡出系数（对标 `MiniMorph.metaOpacityAt = clamp(1 - t/0.35)`）。
   *
   * ⚠️ 这一版按反编译改成**淡出**语义（原来是我按"淡入窗口 0.15→0.60"猜的，错了）：
   *    它是**迷你条那一侧**的元信息随进度淡出，不是播放页内容的淡入；
   *    播放页内容由 `contentOpacity`（落位才置 1）与 `pullChromeOpacity/pullBottomIn` 负责。
   * @param progress 展开进度 0…1
   * @returns 透明度
   */
  public static metaOpacityAt(progress: number): number {
    const v: number = 1 - progress / 0.35;
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  /**
   * 操作区（播放/下一首等按钮）的淡出系数
   * （对标 `MiniMorph.actionsOpacityAt = clamp(1 - t/0.20)`，比歌名更早消失）。
   *
   * ★ 2026-10-17（`MiniMorph` 逐条复核 —— 本文件是**最后一个**没审过的播放器上游模块）：
   * ```
   *   MiniMorph.actionsOpacityAt(t)      = clamp(1 − t / 0.2 , 0, 1)   ✓ 与本函数逐字一致
   *   MiniMorph.metaOpacityAt(t)         = clamp(1 − t / 0.35, 0, 1)   ✓ 与上面那个逐字一致
   *   MiniMorph.coverVisualRadiusAt(t)   = lerp(vp(miniCover.width)/2, targetCoverRadius, t)
   *        ⇒ 这是**胶囊那一侧**的圆角插值（与 `CoverMorph.radiusAt` 不是一回事，别混）
   *   MiniMorph.coverBoxEdge/Left/Top/Right/Scale/VisualEdge/CenterX/CenterY/Rise/RightShift
   *        ⇒ 胶囊端点的逐项几何，本仓对应 `miniX` / `miniY` / `miniSize` / `barWin…` /
   *          `cover…ShiftAt` / `coverRiseAt`（⚠️ 写注释时别把星号和斜杠连着写，会提前结束注释块）
   * ```
   * ⇒ **本仓这三条都与上游一致** ✓（记在这里，免得下一轮再从头核 `MiniMorph`）。
   */
  public static actionsOpacityAt(progress: number): number {
    const v: number = 1 - progress / 0.20;
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  // ─────────── 三层淡入窗口（反编译 `entry/pages/PlayerPage.ets` 的三个 @Computed）───────────
  //
  //   pullBgIn          = clamp(effT / 0.30, 0, 1)                 背景：0 → 0.30 淡入
  //   pullChromeOpacity = paintable ? clamp((effT-0.18)/0.44) : 0  顶栏：0.18 → 0.62
  //   pullBottomIn      = clamp((effT - 0.45) / 0.55, 0, 1)        底栏：0.45 → 1.00
  //
  // 三者都作用在 `effT` 上，而 `effT = 会话中 ? pullT : 1` —— 所以**不在形变会话时全部为 1**
  // （静止态逐像素不变，这是硬要求）。

  // ═══════════════ 元素时间窗表（★ 唯一一份；p 的纯函数 ⇒ 展开/收起天然互逆）═══════════════
  //
  // ★★ 2026-10-15 用户定调：「不要淡入淡出」+「效果最好」，并**亲口给定了分组与顺序**：
  //     「**进度条和下面的那堆按钮一起飞入，先飞入的是小歌词和收藏按钮**（把进度条换成这两个）」
  //      ⇒ 只有**两组**要"从下升起"，且顺序是：
  //        ① 小歌词 + 收藏按钮（先）
  //        ② 进度条 + 下面那一堆按钮 = **整片控制区**（后，作为一组，内部不再分先后）
  //      ⇒ 时间窗只写在这里一份，**所有取值都是 `p` 的纯函数**（不含方向判断、不含驱动源判断）：
  //         展开 = p 从 0 走到 1；收起 = p 从 1 走回 0 ⇒ **同一张表天然互逆**，
  //         既满足"下拉收起一直是对的"，又不需要为收起再写一套。
  //
  // ⚠️ 为什么两组都要**靠后**：续飞封面画在整页内容**之上**（§47 的教训：挪到内容层之下会被页面挡），
  //    而且它**必须一直飞到 p=1**（它的矩形是窗口坐标，只有 p=1 的恒等变换下才落得准）。
  //    所以"不被封面盖住"只能靠**错峰**：等封面飞到上半屏之后，底下这两组再依次升上来。

  /**
   * 歌名/歌手那一行（+ 收藏/更多两个图标）的时间窗 —— **照抄无界 `pullChromeOpacity`**。
   *
   * ★★★ 2026-10-16（用户实测：「**无界的收藏和歌曲菜单是跟着标题歌手一起飞上来的**」）：
   *   无界那一层的公式（`MiniMorph渲染方与顶底栏淡入公式.md` §2，字节码）：`clamp((t − 0.18) / 0.44)`
   *   ⇒ 窗口 = **0.18 → 0.62**。
   *   ⚠️ 我们原来**没有**给这一行"升起"位移（只有 `pullChromeOpacity` 淡入），
   *      而收藏/更多两个图标也在同一行里 ⇒ 它们**只能淡入、不会跟着飞上来**。
   *   ⇒ 现在给整行加同窗位移（见 `metaRiseVp()`），并保留既有的 `pullChromeOpacity` 淡入
   *     （淡入窗口与它**同一个区间**，两者同起同落）。
   */
  public static readonly WIN_META_START: number = 0.18;
  public static readonly WIN_META_END: number = 0.62;

  /**
   * 第一组（小歌词）的时间窗。
   *
   * ⚠️ 顺序依据（用户 2026-10-15 原话）：「**先飞入的是小歌词和收藏按钮**」。
   * ★ 2026-10-16 修订：收藏/更多已按无界归到**歌名那一行**（比小歌词**更早**），
   *   所以这一组现在只剩小歌词 —— 它落在顶栏(0.18–0.62)与底栏(0.45–1.00)之间。
   */
  public static readonly WIN_A_START: number = 0.30;
  public static readonly WIN_A_END: number = 0.52;
  /**
   * 第二组（进度条 + 底部按钮 = 整片控制区）的时间窗 —— **照抄无界 `pullBottomIn`**。
   *
   * ★★★ 2026-10-16（用户实测：「**下面那堆按钮，无界是整个动画结束后飞完，
   *   派音现在是快结束的时候就飞完了，然后最后一点就会有个放大的过程**」）：
   *   无界那一层的公式（同文档 §3，字节码）：`clamp((t − 0.45) / 0.55)`
   *   ⇒ 窗口 = **0.45 → 1.00** —— **正好在落位那一刻才飞完**。
   *   ⚠️ 我们原来是 `0.60 → 0.90` ⇒ 控制区在 90% 就到位，最后 10% 只剩"整页放大"
   *     ⇒ 观感就是用户说的"最后一点有个放大的过程"。
   */
  public static readonly WIN_B_START: number = 0.45;
  public static readonly WIN_B_END: number = 1.00;
  /** "从下升起"的幅度（屏幕 vp，形变期间按 `1/scale` 反算成页内位移）。 */
  public static readonly RISE_VP: number = 180;

  // ═══════════════ 壳层浮层这一层的**独立时长/曲线**（对标无界 `animateMorphT`）═══════════════
  //
  // 无界是**两层**：播放页内快照 350ms `Curve.EaseInOut`（`doEnter`）+ 浮层拷贝的 `morphT`
  //  560ms `cubic-bezier(0.23, 1.0, 0.32, 1.0)`（`animateMorphT`）。
  // RzdMusic 现在也分成两层：**播放页那层的 350ms 一个字都不动**（`PlaybackPage.MORPH_OPEN_DURATION_MS`），
  // 壳层浮层这一层单独走下面这套 560ms + 快出慢收的贝塞尔。
  //
  // ⚠️ 只有**浮层拷贝**吃这一套；`morphP`（= 播放页几何）继续由原调用方按 350ms 补间。

  /** 浮层拷贝的补间时长（ms，对标无界 `ENTER_MS = 560`）。 */
  public static readonly MORPH_OVERLAY_DURATION_MS: number = 560;
  /** 浮层拷贝**收起**方向的基础时长（ms）—— 对标无界 `MainPage.REVERSE_MS = 460`。 */
  public static readonly MORPH_OVERLAY_REVERSE_MS: number = 460;
  /** 浮层拷贝收起时长的下限比例 —— 对标无界 `MainPage.REVERSE_MIN_RATIO = 0.4`。 */
  public static readonly MORPH_OVERLAY_REVERSE_MIN_RATIO: number = 0.4;

  // ★★★ 2026-10-15（Round 27）：**收起方向改成与播放页"同一条公式 + 同一条曲线"**。
  //
  // 无界 `MainPage` 那一层有一对常量（`开关播放器-手势路径定稿.md` §0 速查 L27/L29 +
  // §八 常量表 L620-631；出处交叉见 `ExpandAnimation驱动与补间定稿.md` §三
  // 「两套时长表的真实关系」——`ENTER_MS`/`REVERSE_MS` **同属 MainPage 那一层**）：
  //   · 进入：`ENTER_MS = 560` + `EASE_OUT_STR (0.23,1,0.32,1)`
  //   · 收起：`animateMorphT(reverseMs, t=0, REVERSE_EASING)`，其中
  //     `reverseMs = round(REVERSE_MS(460) × max(REVERSE_MIN_RATIO(0.4), morphT))`、
  //     `REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`
  //
  // ⚠️ 本文件早先记过一条"**有意不落地**"的决定，理由是量化过的"12% 尾跳"：
  //   浮层只活到 `morphLand()`，而那时播放页那层是 `MORPH_CLOSE_DURATION_MS = 350` + 20
  //   ⇒ 浮层只有 ~370ms 可画；若浮层改用 460 + `(0.85,0,0.5,0.88)`，在 370/460 = 80% 处
  //   只走到 ≈87% ⇒ 撤掉瞬间跳 ~12% 行程。
  //   ★ **该前提已经不存在**：§56.20 把播放页关闭改成了
  //     `round(460 × max(0.4, morphT))` + `REVERSE_EASING`（`MORPH_CLOSE_DURATION_MS` 已删）。
  //   ⇒ 让浮层用**同一条公式 + 同一条曲线**之后：
  //     · 两层**同起同落**（同一帧起、同一时长、同一曲线、起点都是各自的当前进度）
  //       ⇒ **结构上不可能不同步**，"尾跳"这个问题**从根上消失**（不是"跳得更小"）；
  //     · 这也正是无界 `MainPage` 层的原写法（`animateMorphT(reverseMs, 0, REVERSE_EASING)`）。
  //
  // ⚠️ 方向判定用形参 `progress`（true = 展开到 1；false = 收回 0），**不要**写成
  //   `to > from`：补间中被打断时 `from` 已经动过，用它判方向会误判。
  //
  // ⚠️ 这里**没有** `morphOverlayCurve()` 这类返回 `ICurve`/`UIShape` 的包装函数 —— 故意的：
  //   本机 SDK 里 `ICurve`（`component/common.d.ts:4154`）**唯独它没写 `declare`**
  //   （同文件其它接口都是 `declare interface`）⇒ 它不是全局可见的；`@kit.ArkUI` 也**没有**
  //   导出 `UIShape`（编译实测：`Module '"@kit.ArkUI"' has no exported member 'UIShape'`）。
  //   ⇒ 曲线**就在唯一那个 `animateTo` 的调用点上内联写**（本次改成按 `progress` 走两分支的三元），
  //   与工程里既有的两处同款（`products/default .../Index.ets`、`PlaybackPage.ets`）：
  //       curve: curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)
  //   改曲线只改那**一处**（`morphOverlayTweenTo` 里），不要另起包装。

  /** @returns 窗口 [start, end] 内的线性进度 0…1（窗口外夹紧）。 */
  public static ramp01(p: number, start: number, end: number): number {
    if (end <= start) {
      return p >= end ? 1 : 0;
    }
    const v: number = (p - start) / (end - start);
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  /**
   * @returns 第一组「小歌词 + 收藏按钮」的纵向位移（**页内** vp）。
   *
   * 窗内从 180vp 升到位（屏幕量），静止态/非形变期恒 0。
   * ⚠️ 除以 `morphScale`：这一层会被外层形变容器缩放，反算后屏上位移才恒定。
   */
  public earlyRiseVp(): number {
    if (!this.morphClipping()) {
      return 0;
    }
    const w: number = PlayerExpandState.ramp01(this.morphP,
      PlayerExpandState.WIN_A_START, PlayerExpandState.WIN_A_END);
    const scale: number = Math.max(0.05, this.morphScale);
    return (1 - w) * PlayerExpandState.RISE_VP / scale;
  }

  /**
   * @returns 第二组「整片控制区（进度条 + 底部按钮）」的纵向位移（**页内** vp）。
   *
   * ★ 2026-10-16：窗口已按无界 `pullBottomIn` 改成 **0.45 → 1.00**（见 `WIN_B_*` 的注释）
   *   ⇒ 展开时控制区**到落位那一刻才飞完**，最后不再有"只剩放大"的那一段。
   */
  public contentRiseVp(): number {
    if (!this.morphClipping()) {
      return 0;
    }
    const w: number = PlayerExpandState.ramp01(this.morphP,
      PlayerExpandState.WIN_B_START, PlayerExpandState.WIN_B_END);
    const scale: number = Math.max(0.05, this.morphScale);
    return (1 - w) * PlayerExpandState.RISE_VP / scale;
  }

  /**
   * @returns 「歌名/歌手 + 收藏/更多」那一行的纵向位移（**页内** vp）。
   *
   * ★★★ 2026-10-16（修用户实测：「**无界的收藏和歌曲菜单是跟着标题歌手一起飞上来的**」）：
   *   这一行原来**只有 `pullChromeOpacity` 淡入、没有任何位移** ⇒ 收藏/更多两个图标
   *   只能"淡出来"，不会"跟着飞上来"。
   *   ⇒ 按无界 `pullChromeOpacity` 的窗口（**0.18 → 0.62**，同一区间也是它的淡入区间）
   *     给整行加同窗位移，两个图标与文字因此**同一组、同时飞上来**。
   */
  public metaRiseVp(): number {
    if (!this.morphClipping()) {
      return 0;
    }
    const w: number = PlayerExpandState.ramp01(this.morphP,
      PlayerExpandState.WIN_META_START, PlayerExpandState.WIN_META_END);
    const scale: number = Math.max(0.05, this.morphScale);
    return (1 - w) * PlayerExpandState.RISE_VP / scale;
  }

  /**
   * @returns 播放页**真封面**是否该画。
   *
   * ★★★ 2026-10-16（用户实测两条，本处是它们**共同的根**）：
   *   「**下拉的时候封面在动画结束才收起**」+「**点击打开播放器封面直接就到结束位置了**」
   *
   * ## 原来为什么两条都坏
   *
   * 原判据是 `!morphContainerActive()` —— 只要**相位**一进 ENTERING/LEAVING/LANDING
   * 就立刻把真封面藏起来，改由**壳层克隆层**（`MorphCoverClone`）代表封面飞。
   * 但克隆层的显隐门是 `morphOverlayBridging()`（= 浮层进度 `morphOverlayP` 在 (0,1) 之间），
   * **两者不是互补关系** ⇒ 只要浮层那条补间没跑起来（或已跑到 0），就会掉进
   * **"真封面不画 + 克隆层不画"的空档**：
   *   · 下拉关闭：空档里屏上**没有封面**，一直等到播放页落位（`morphLand()` 之后
   *     `morphContainerActive()` 转假）真封面才冒出来 ⇒ 观感"封面**到动画结束才收起**"；
   *   · 点击打开：同理，起手那一段没有封面，而页面已经铺开 ⇒ 观感"封面**直接就到结束位置**"。
   *
   * ## 现在的判据：**与克隆层严格互补**
   *
   * ```
   *   克隆层在画（覆盖层那一棒）⇒ 真封面不画（避免两份）
   *   克隆层不在画              ⇒ 真封面画（页面自己带它一起缩放/裁剪，永远不空档）
   * ```
   * ⇒ 无论浮层补间起没起来，**屏上永远恰好有一张封面**，且它跟着页面一起缩小/放大。
   * ⚠️ 这条同时消掉了原注释担心的"两份封面"：两份只在"克隆层在画"时可能重合，
   *    而那时真封面被这条挡住。
   */
  public realCoverVisible(): boolean {
    // ★★★ 2026-10-16（**恢复**；我中间两版把它改坏过两次）
    //
    // ## 判据 = 与壳层浮层**严格互补**（浮层在画 ⇒ 真封面让位）
    //
    // ```
    //   浮层在画这一棒（`morphOverlayBridging()`）⇒ 真封面不画（避免两份）
    //   浮层不在画                              ⇒ 真封面画（静止态就靠它）
    // ```
    //
    // ## 我这几版分别错在哪（都别再犯）
    //
    // | 版本 | 我写的判据 | 用户实测 |
    // | --- | --- | --- |
    // | ① | `!morphContainerActive()` | 「下拉时封面到动画结束才收起」／「点击打开直接就到结束位置」 |
    // | ② | `!morphOverlayBridging()` + **同时把浮层关掉** | 「关/开播放器**没有封面动画**」 |
    // | ③ | 恒 `true`（取消交棒、真封面独担） | 「封面**从下方飞上来**」（容器变换把基准位搬到了屏幕顶部） |
    // | ④ | `!morphOverlayBridging()`（恢复） | 正确方向 |
    //
    // ⇒ **①那条注释里担心的"两者不是互补"是真的**，但正解是**把浮层那份补间修好**
    //   （它已经修好了：见 `morphOverlayBridging()` 的三条判据），**不是**把真封面改成恒画。
    // ⚠️ 关键事实（从容器几何读出来的，别再用"推导"推翻它）：
    //   形变中容器贴在**屏幕顶部那一条**（`morphTy ≈ +844`、`scale ≈ 0.082`）
    //   而迷你条在**屏幕底部** ⇒ 基准位的封面在容器里会被搬到顶部去 ⇒
    //   **真封面在形变期不能代表"一镜到底"**，那是浮层的职责。
    //
    // ★★★ 2026-10-16（**加固：与"浮层实际在画"互补，而不是与"门为真"互补**）：
    //   上面那版是 `!morphOverlayBridging()`。但"门为真"与"真的画出来了"是两件事：
    //   浮层可能因为**别的原因**画不出来（`morphCoverRectAt` 两端几何为 0 ⇒ 0×0、
    //   宿主 `hostsMorphOverlay()` 在运行期返回假、浮层节点还没挂上…）。
    //   那就会出现用户报过的那个形状：**`real=0 clone=0` ⇒ 两边都不画 ⇒ 屏上没有封面**。
    //   ⇒ 现在把判据收紧到"**浮层确实在画**"：
    //     `morphOverlayBridging() && morphOverlayBridgeOpacity() > 0 && 两端几何非零`
    //   ⇒ 只要浮层这一棒**任何一环不成立**，真封面就顶上（宁可位置不完美，也绝不留空洞）。
    //   ⚠️ 静止态浮层门恒假 ⇒ 本函数恒真 ⇒ 与改动前**逐像素一致**（回归红线）。
    if (!this.morphOverlayBridging()) {
      return true;
    }
    if (this.morphOverlayBridgeOpacity() <= 0) {
      return true;
    }
    // 浮层这一棒能不能真的画出来：两端几何必须非零（否则画的是 0×0）
    const rect: LyricMorphRect = this.morphOverlayCoverBridge();
    if (rect.size <= 0 || rect.height <= 0) {
      return true;
    }
    return false;
  }
  // ⚠️ 2026-10-15 教训（别再犯）：**不要**把歌名/歌手这一行改成"p 的独立窗口"
  //    （我试过 `ramp01(p, 0.18, 0.34)` 让它在播放页里早出现、并让壳层克隆层在 0.38 前淡完）。
  //    那样做的结果是：克隆层淡出时，播放页自己那一行还压在**缩小布局**里看不见 ⇒
  //    用户实测「歌曲名和歌手到中间就消失了」。这一段**保持原来的"所有权交接"语义**，
  //    见 `targetMetaOpacity()`：克隆层接管期间该行为 0，交回给播放页时才显示。

  /** 背景最低不透明度兜底（反编译 `PlayerPage.PULL_BG_FLOOR`）。 */
  private static readonly PULL_BG_FLOOR: number = 0.04;

  /**
   * @returns 背景层不透明度：0 → 0.30 淡入到满（下限 {@link PULL_BG_FLOOR}）。
   *
   * ⚠️ 这一层**不是**"容器整体不透明度"：容器本身不淡，淡的是背景层。
   *    起点之所以看起来"有东西"，靠的是续飞封面那几个克隆层（见 shell 的形变克隆层）。
   *
   * ⚠️⚠️ **2026-10-15 补充：本函数【故意没有调用点】，不要去"接上它"。**
   *   逆向结论确实是它（`pullBgIn = clamp(effT / 0.30)`，`effT = 形变中 ? morphT : 1`），
   *   但播放页背景层用的是 `PlaybackPage.backgroundRevealOpacity()`：
   *   ```
   *   morphContainerActive() ? 0.25 + 0.75 * morphP : 1        // 线性、从 25% 起、到落位才满
   *   ```
   *   **为什么换掉**：这条曲线是**用户明确要求**"整个效果就是半透明过渡到不透明"时定的。
   *   而 `pullBgIn` 在 `p = 0.30` 就**满不透明**，可那时形变裁剪窗口还只有一小块"可视矩形"
   *   ⇒ 窗口里从第 30% 起就是**一整块不透明底色**，用户实测报过的
   *   「**展开中背景是黑色的**」正是这个形状（记录见 `踩坑总表-RzdMusic形变动画.md` 3.4）。
   *   ⇒ **保持 `backgroundRevealOpacity()`**；本函数留作"逆向对照物"与"若哪天要回到逐帧 effT 口径"的参考。
   *   网格背景（`MeshCoverBg`）也**同样**用 `backgroundRevealOpacity()`，没有例外。
   */
  public pullBgIn(): number {
    if (!this.morphLive()) {
      return 1;
    }
    const p: number = this.morphP < 0 ? 0 : (this.morphP > 1 ? 1 : this.morphP);
    const v: number = p / 0.30;
    const clamped: number = v > 1 ? 1 : v;
    return clamped < PlayerExpandState.PULL_BG_FLOOR ? PlayerExpandState.PULL_BG_FLOOR : clamped;
  }

  /** @returns 顶栏（TopArea）不透明度：0.18 → 0.62 淡入到满（未就绪时为 0）。 */
  public pullChromeOpacity(): number {
    if (!this.morphLive()) {
      return 1;
    }
    const p: number = this.morphP < 0 ? 0 : (this.morphP > 1 ? 1 : this.morphP);
    const v: number = (p - 0.18) / (0.62 - 0.18);
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  /** @returns 底栏（控制区）不透明度：0.45 → 1.00 淡入到满。 */
  public pullBottomIn(): number {
    if (!this.morphLive()) {
      return 1;
    }
    const p: number = this.morphP < 0 ? 0 : (this.morphP > 1 ? 1 : this.morphP);
    const v: number = (p - 0.45) / (1 - 0.45);
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  /** 文字层向上偏移（vp）：从 +8 滑到位，收尾时看起来是"浮上来"。 */
  public static metaOffsetYAt(progress: number): number {
    return (1 - PlayerExpandState.metaOpacityAt(progress)) * 8;
  }

  /** @returns 歌名/歌手层透明度（基于内部 `progress`，仅在与内部相位同源时使用）。 */
  public metaOpacity(): number {
    if (this.preparing) {
      return 0;
    }
    if (!this.animating) {
      return 1;
    }
    return PlayerExpandState.metaOpacityAt(this.progress);
  }

  /**
   * 视觉圆角：封面被等比缩放时，圆角也要跟着缩放，否则小尺寸下圆角显得过大、
   * 大尺寸下显得过小（这就是无界 `visualRadiusAt` / `coverVisualRadiusAt` 的作用）。
   *
   * ⚠️ **D3：与无界算法不同，此处刻意保留，只标注差异**（依据
   *    `docs\无界形变手感-落实到RzdMusic清单.md` §四 D3「建议：保留现算法，只在文档里标注差异」）。
   *   · 无界：`visualRadius = lerp(vp(miniCover.width) / 2, 目标圆角绝对值 34, t)`，
   *     再 `radius = visualRadius / scale` —— **两端点线性插值**；
   *   · 本实现：`base * (size / miniSize)` 再封顶 `base * 1.6` —— **按尺寸比例放大 + 上限**。
   *   两者在中间态的曲率不同，但本实现**不依赖 `onAreaChange` 的时序**（见下面那两条注释），
   *   改成两端点 lerp 会把时序敏感重新引进来 ⇒ 保留。
   *
   * ★★ 复核（2026-10-15，判据行 `git grep -n coverVisualRadius -- "*.ets"`）：
   *    **本函数全仓零调用点**（只有这一处定义 + 两处注释），所以 D3 记的这条差异
   *    **并不在活的渲染路径上**。活的圆角是这两条：
   *    · **形变容器**：`applyMorphProgress()` 里 `morphRadius = visualRadius / scale`，
   *      而 `visualRadius = initRadiusVisual * (1 - t)`（`initRadiusVisual = 胶囊高 / 2`）
   *      —— 这**已经就是无界的形状**：两端点线性插值 + **除以 scale**
   *      （清单 §一 1.4 的 `coverRadiusAt = coverVisualRadiusAt / coverScaleAt`）；
   *      差的只是终点值（我们 0、无界 34，且口径不同：我们算**整页容器**，无界算**封面本身**）；
   *    · **封面本身**：展开页封面的圆角来自**用户设置** `CoverRadiusState`
   *      （`MusicPlayInfoBlock` → `AppStorageV2.connect(CoverRadiusState …)`）
   *      ⇒ 无界那个"绝对值 34"**绝不能照抄**，照抄会覆盖用户在设置里的选择。
   *    ⇒ 结论与清单 §四 D3 一致（保留现算法、只标差异），但差异的落点是**死代码**：
   *      本函数只为"记录无界口径"而留，**不要**为了对齐它去改圆角。
   * @returns 补偿后的圆角（vp）。⚠️ 无调用点（见上）。
   */
  public coverVisualRadius(): number {
    const base: number = this.coverRadius();
    const mini: number = this.miniSize;
    const size: number = this.coverSize();
    if (mini <= 0 || size <= 0) {
      return base;
    }
    // 以迷你条那一端为基准等比缩放；展开端的圆角本身就是设计值，不需要补偿
    const scaled: number = base * (size / mini);
    const cap: number = base * 1.6;
    return Math.min(scaled, cap);
  }

  // ═════════════════════════ 二、封面续飞到歌词页（对标 CoverMorph 双端点）═════════════════════════
  //
  // 无界那套的 CoverMorph 有**两套端点**：`topYAtPlayer/tyAt/scaleAt/radiusAt`（播放页）
  // 与 `topYAtLyric/bottomYAtLyric/tyLyric/lyricVisualEdge`（歌词页）——
  // 说明歌词页的封面不是"另一页的元素"，而是**同一张封面继续飞过去的**。
  //
  // 我们这边**刻意不靠运行时测量**：歌词页封面的位置直接由窗口尺寸算出来
  // （`LYRIC_COVER_EDGE_VP` + 几个比例），这样：
  //   1. 不依赖 `onAreaChange` 的时序（那个在切页动画里很容易拿到中间态）；
  //   2. 任意时刻打断都自洽；
  //   3. 窄屏/宽屏都跟着窗口走，不用为每种断点各配一套。

  /**
   * 歌词页小封面的**绝对边长**（vp）。
   *
   * ★ 对标无界 `PlayerPage.CoverMorph` 的 `LYRIC_COVER_EDGE = 48.72`
   *   （`func_main_0` 闭包槽 `0x05`，`wujie.pa:197901` 起；同一处还有 `0x04 = -40` 的
   *   `tyPlayer`、`0x14 = 0.32` 的 `COMMIT_T`）。
   *
   * **无界这里是个硬不变量**：`lyricScale = 48.72 / edge` ⇒
   * **`edge × lyricScale ≡ 48.72`** —— 歌词页那枚小封面与「本页大封面多宽」**无关**，
   * 恒定 48.72vp。`edge` 的常态值是 328（= `coverEdgeMaxOf` 的产物，**不是默认的 348**），
   * ⇒ `lyricScale ≈ 0.1485`；构造器那个兜底 `0.14` 正好 = `48.72 / 348`，即默认 `edge` 那一档
   * （两条路自洽，可作交叉验证）。
   *
   * ⚠️ 本轮之前这里是一个**比例**（`LYRIC_COVER_SCALE_RATIO = 0.52`，随大封面一起变大）——
   *   本轮两份新文档都点名"量纲不同、不可对号"、并**直接给了改法**：
   *   · `_recover\logic-src\无界vs派音-差异分析.md` §〇「根因已确认（本轮新解，直接可抄）」
   *     ——"歌词页封面：无界小、派音居中大"的根因；
   *   · `_recover\logic-src\歌词页浮层封面与歌名定稿.md` §7.2 / §7.4「最短改动建议」第 1 条
   *     ——"把 `lyricCoverSizeOf()` 从比例改成常量 `48.72`（1 行）"。
   *   验收判据（同文档 §6）：`edge × lyricScale === 48.72`（浮点 ±0.01）。
   *
   * ⚠️ **单源**：`_recover\logic-src\交付物交叉核对记录.md` §9.9 把"歌词页浮层整族"
   *   列为单源未复核 ⇒ 本轮**只落了这一个数**；同一份文档 §7.4 建议的另两条
   *   （`lyricMetaYOf()` 锚点改成"封面顶边 − 26"、补 OFF/AUTO/始终开启 用户档位）**没落**，
   *   理由见该文 §8 的 U1（坐标系歧义）与"属新增功能、非数值对齐"。
   *
   * ★★ 2026-10-15（Round 23 对着定稿逐条复核，**结论：锚点这一半已经对了，`−26` 不许按绝对 Y 用**）：
   *   · **锚点已对、不要改**：定稿 L1417 的原文是
   *     「歌名的终点锚在"**小封面顶边**"上，不是"盒顶"」，而 `lyricMetaYOf()` 现在正是
   *     `return this.lyricCoverYOf()`（与封面**同顶边**、并排摆放）⇒ 与 L1417 一致。
   *   · **`−26` 不能直接用**：定稿 L870 / L1100 给出的是
   *     `metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)`
   *     —— `−26` 是**这个 lerp 终点的"位移量"**（`metaTopFixLyric`），**不是绝对 Y**；
   *     而另一端 `metaYPlayer` 出自 `fitPlayerOverlay` 的
   *     `metaY = curMetaY + edge/2 + gap + metaH/2`（带 `+ metaH/2` ⇒ 那是**中心**）。
   *     把"封面顶边 − 26"当成**顶边**塞进我们的**绝对定位**（`.position({ y })`）体系，
   *     会让歌名整块再上移约 `26 + 行高/2 ≈ 43vp`（跑到小封面上方）。
   *   · 定稿 §8 的 **U1 至今未确认**（`META_Y_PLAYER_MAX(-214)` 与 `fitPlayerOverlay`
   *     的结果是否同一坐标系）⇒ **坐标系没定之前不许动这个数**。
   *   ⇒ 要动它，先拿一次**上机观测定坐标**：让用户看"歌词页歌名相对小封面偏高还是偏低"，
   *     再据此给偏移量。完整推理见 `RzdMusic记忆.md` §56.18。
   */
  private static readonly LYRIC_COVER_EDGE_VP: number = 48.72;
  /** 歌词页封面顶部相对展开页封面顶部的下移比例（占展开页封面高度）。 */
  private static readonly LYRIC_COVER_TOP_RATIO: number = 0.06;
  /** 歌词页那一横行的顶边 = 窗口高度的这个比例（状态栏估算）**加上**顶栏高度。 */
  private static readonly LYRIC_COVER_TOP_RATIO_STATUS: number = 0.07;
  /** 顶栏高度（vp）——与 `TopAreaComponent.height(56)` / 无界 `Tokens.BAR_H = 56` 同值。 */
  private static readonly LYRIC_ROW_TOPBAR_H_VP: number = 56;
  /**
   * 顶部让位的**下限**（vp）—— 对标无界 `PlayerPage.PLAYER_TOP_FALLBACK = 56`
   * （`歌词页浮层封面与歌名定稿.md` L1295；`padTop()` 里当"下限"用，见 `topInsetVp()`）。
   */
  private static readonly PLAYER_TOP_FALLBACK_VP: number = 56;
  /**
   * 歌词页小封面的**左边界**（vp）。
   *
   * ★ 2026-10-15（照搬无界）：歌词页是 `[小封面][歌名/歌手][收藏][更多]` 一横行，
   *   封面贴行首。取值与 `PlaybackPage.LYRIC_META_SIDE_VP`（那一行的左右留白）**必须一致**，
   *   否则封面与歌名会错开一条缝。
   */
  private static readonly LYRIC_COVER_LEFT_VP: number = 16;
  /** 兜底封面边长上限（无界 `CoverMorph` 模块常量 `COVER_EDGE_CAP = 480`）。 */
  private static readonly COVER_EDGE_CAP_VP: number = 480;
  /** 兜底封面边长下限（无界 `COVER_EDGE_MIN = 200`）。 */
  private static readonly COVER_EDGE_MIN_VP: number = 200;
  /** 兜底封面边长 = 窗口短边的这个比例（无实测时的量级估计；仅兜底，正常路径用不到）。 */
  private static readonly COVER_EDGE_FALLBACK_RATIO: number = 0.62;
  /** `fitPlayerOverlay` 的高度预算扣减项（无界：`availH − 2·(gap + metaH + 8)`）。 */
  private static readonly COVER_FIT_META_H_VP: number = 60;
  /**
   * ⚠️ 2026-10-16（**已不再使用**）：这是 `fitPlayerOverlay` 里那个"硬编码 8"的**旧估称**，
   *   我原来还多编了一个 `COVER_FIT_GAP_VP = 20`（**无界没有这个值**，它的 gap 默认是 50）。
   *   现在 `playerCoverGeomRect()` 已逐字照抄无界 ⇒ 用 `COVER_FIT_META_GAP_VP(50)`
   *   与 `COVER_FIT_BOUND_INSET_VP(8)`，本常量与 `COVER_FIT_INSET_VP` 一起**下线**。
   *   保留声明是为了不牵动别处；下一次清理时可一并删除。
   */
  private static readonly COVER_FIT_GAP_VP: number = 20;
  /** ⚠️ 已不再使用（改用 {@link COVER_FIT_BOUND_INSET_VP}），理由同上。 */
  private static readonly COVER_FIT_INSET_VP: number = 8;
  /**
   * 封面圆角占其短边的比例（展开页那一端）。
   *
   * ★★ 2026-10-15（照搬无界：修用户实测「**无界展开播放器时圆角更大**」）：
   *   无界那一端的圆角是 `CoverMorph.radiusPlayer = 8`（vp，**绝对值**；
   *   `_recover/logic-src/歌词页浮层封面与歌名定稿.md` §五 的类字段表 + `85481 ldai 0x8`），
   *   而其 `edge` 默认 348（`ldai 0x15c`）⇒ **比例 = 8 / 348 ≈ 0.02299**。
   *   ⇒ 这里用**同一个比例**而不是拍一个数：`edge` 变（不同机型）时圆角同比走，
   *     与无界"绝对值恒定、比例随 edge 浮动"只在默认 edge 上等价 —— 但对我们这种
   *     `edge` 由 fitPlayerOverlay 算出来的实现，比例写法更稳（不会在小屏上把圆角压成 0）。
   *   ⚠️ 改前是 0.06（≈ 22vp @edge 369）—— 比无界大 2.6 倍，观感就是"圆角明显更大/更方圆"。
   *      原值按"无界那 348 / 8"一算即可复现：`8 / 348`。
   */
  private static readonly COVER_RADIUS_RATIO: number = 8 / 348;

  /**
   * 封面在「展开页（封面页）」那一端的圆角（vp，**绝对值**）—— 照抄无界 `CoverMorph.radiusPlayer`。
   *
   * 出处：`wujie.pa:85471`（读默认值）→ `85481 ldai 0x8` ⇒ **8**；
   *   类字段表见 `_recover/logic-src/歌词页浮层封面与歌名定稿.md`（`radiusPlayer = 8`）。
   */
  private static readonly COVER_RADIUS_PLAYER_VP: number = 8;

  /**
   * 封面在「歌词页」那一端的圆角（**视觉值**，vp）—— 照抄无界 `CoverMorph.radiusLyricVisual`。
   *
   * 出处：`wujie.pa:85486`（读默认值）→ `85494-85496` 的 `mov`/兜底 ⇒ 默认 **12**。
   *
   * ★★★ 2026-10-16（用户实测：「**歌词页面的封面圆角太小了**」）：
   *   无界的两端圆角是 **`lerp(radiusPlayer 8, radiusLyricVisual 12, t)`**
   *   （`wujie.pa:85731-85743` 的 `visualRadiusAt`，调的是本文件的 `lerp`），
   *   然后 `radiusAt = visualRadiusAt / scaleAt`（`85604-85613`）。
   *
   *   ⚠️ 我们改前用的是 `radius = lerp(fromRect.radius, toSize × COVER_RADIUS_RATIO 8/348, t)`：
   *     `toSize` 是歌词页那张小封面的边长（≈244vp）⇒ 终点圆角只有 **≈5.6vp**，
   *     而无界是 **12vp** ⇒ 差一倍多，这就是"圆角太小"。
   *   ⚠️ 那个 `8/348` 比例是**展开页**那一端的口径（`edge` 大），把它套到**歌词页小封面**
   *     上是把两个端点用错了同一个公式 —— 典型"同一形状两处口径混用"。
   *   ⇒ 现在两端各自取**自己的绝对值**再插值，与无界逐字一致。
   *   ⚠️ 用户设置里的 `CoverRadiusState`（见 `MusicPlayInfoBlock`）**不受影响**：
   *     它管的是"展开页静止态用户选的圆角"，本函数只在 `t > 0`（歌词页那一趟）参与。
   */
  private static readonly COVER_RADIUS_LYRIC_VISUAL_VP: number = 12;

  /** 歌词页封面矩形是否有效（窗口尺寸拿到了才算得出来）。 */
  public lyricGeometryReady(): boolean {
    return this.bigSize > 0 || (this.windowWidthVp > 0 && this.windowHeightVp > 0);
  }

  /** @returns 展开页封面的宽度（vp）：优先用实测的 `bigSize`。 */
  private playerCoverWidth(): number {
    if (this.bigSize > 0) {
      return this.bigSize;
    }
    return 0;
  }

  /**
   * @returns 歌词页封面边长（vp）—— 恒定的 {@link PlayerExpandState.LYRIC_COVER_EDGE_VP}。
   *
   * ⚠️ **"大封面还没量到就返回 0"这条门必须保留**：{@link lyricFloat} 用它当"几何就绪"的
   *    第二问（`lyricCoverSizeOf() > 0`）—— 大封面未上报时若还返回常量，浮层会提前启用、
   *    让歌词凭空多出一段顶部留白。
   */
  public lyricCoverSizeOf(): number {
    if (this.playerCoverWidth() <= 0) {
      return 0;
    }
    return PlayerExpandState.LYRIC_COVER_EDGE_VP;
  }

  /**
   * @returns 歌词页封面左边界。
   *
   * ★★ 2026-10-15（照搬无界）：**靠左**，不再是水平居中。
   *   无界的歌词页是**一横行** `[小封面][歌名/歌手][收藏][更多]`（`metaRow`，见
   *   `PlayerPage完整UI定稿.md` §6.2），封面在行的最左端、与歌名并排 ——
   *   原来这里返回 `(winW - size) / 2`（居中），所以派音看起来是"居中小封面 + 歌名在它下面"，
   *   而歌名那块又被排到封面**下方**（见 `lyricMetaYOf`）⇒ 与无界完全不同。
   */
  public lyricCoverXOf(): number {
    return PlayerExpandState.LYRIC_COVER_LEFT_VP;
  }

  /**
   * @returns 歌词页封面上边界（= 那一横行的顶边）。
   *
   * ★★ 2026-10-15（照搬无界）：**贴在顶栏之下**。
   *
   * 原来是"展开页封面顶边 + 封面高度的 6%" ⇒ 在 780 高机型上 ≈ **246vp**，
   * 落在屏幕约 1/3 处；而无界截图里小封面的顶边与顶栏的 `⌄` **大致齐平**（≈ 110vp）。
   * 现在＝状态栏估算值 + 顶栏高度（`topBarH = 56`，与派音 `TopAreaComponent.height(56)` 同值）。
   *
   * ⚠️ 这条同时决定 `lyricMetaYOf()`（并排 ⇒ 同顶边）与 `lyricPadTop()`（歌词让位高度），
   *    所以改它会整体上移——三处口径都跟着走，不会打架。
   */
  public lyricCoverYOf(): number {
    // ★★ 2026-10-15（照搬无界；修用户实测「**内容没延伸进状态栏**」）：
    //   这里原来是 `windowHeightVp × LYRIC_COVER_TOP_RATIO_STATUS(0.07)` ——
    //   一个**状态栏估算比例**（925vp 高的屏上算成 ≈65vp，而真机状态栏通常只有 30~40vp）
    //   ⇒ 顶部凭空多让位 ~25~35vp。现在改走 `topInsetVp()`（= 无界的 `padTop()`）。
    const topInset: number = this.topInsetVp();
    return topInset + PlayerExpandState.LYRIC_ROW_TOPBAR_H_VP;
  }

  /**
   * 播放页内容相对窗口顶边的**顶部让位**（vp）—— 对标无界 `PlayerPage.padTop()`。
   *
   * ★★ 2026-10-15（照搬无界）：无界那两个函数
   *   （`wujie.pa:175250-175353`，转写见 `_recover/logic-src/歌词页浮层封面与歌名定稿.md`
   *   L506 / L509 / L790 / L791）是：
   * ```
   *   padTop()    = max(avoidTop,    PLAYER_TOP_FALLBACK = 56)   // 真实状态栏避让区，下限 56
   *   padBottom() = max(avoidBottom, FULL.bottomGap      = 65)   // 真实导航条避让区，下限 65
   *   usableH()   = winHVp() - padTop() - padBottom()
   * ```
   *   ⇒ **用"真实避让区 + 下限"**，不是比例估算。
   *   ⚠️ 我们的**面板分支早就在用真实值**（`PlaybackPage` 那条
   *      `.padding({ top: windowInfo.statusBarTopVp, bottom: windowInfo.navigationBarBottomVp })`），
   *      只有手机这一支还在用比例 ⇒ 属**内部分叉**，本轮统一到"真实值 + 下限"。
   *
   * ⚠️ 量不到（`statusBarTopVp <= 0`：窗口信息还没回调 / 某些窗口形态）时**退回原来的比例估算**，
   *   保证与改前行为一致 —— 不会因为"量不到"就把内容顶进状态栏里。
   * ⚠️ `padBottom()` 那一半（下限 65）**本轮没接**：它要改的是底部/控制区的让位，
   *   与"顶部"是两件事，登记为待办（见 `RzdMusic记忆.md` §56.24）。
   * @returns 顶部让位（vp）
   */
  /**
   * 播放页**页盒顶边**在窗口里的 y（vp，实测；0 = 还没量到）—— 喂给 {@link topInsetVp}。
   *
   * ★★ 2026-10-15（`RzdMusic记忆.md` §56.50）：**这是"双重让位"的解药，而且本仓早有先例** ——
   *   `common/musicbasic/.../PageTopInsetHelper.ets` 的类注释就是为**同一个 bug** 写的
   *   （2026-10-11 那轮真机截图量到 `+48vp`，并明确写「让位量是**相对盒顶**的：
   *   `盒顶 = 0` 时要让 `状态栏 + 56`，而 `盒顶 = 状态栏` 时只该让 `56`」）。
   *
   * ⚠️ 我们原来的 `topInsetVp()` **正是那句注释点名的错法**（按"盒顶 = 0"写）——
   *   在"框架把页盒顶到安全区内"的机器上就会**多让一个状态栏** ✓
   *   （本机实测深色带 47/45vp、顶栏 112 ≈ 47 + 56，完全对应）。
   *
   * ★ 为什么把它做成"**自适应修正**"而不是直接改成盒内换算：
   *   `topInsetVp()` 的目标是让**内容顶边落在窗口的 `max(状态栏,56)` 那条线上**，
   *   而"内容顶边 = 盒顶 + 让位" ⇒ `让位 = target − 盒顶` ⇒ **对盒顶取 0 或 47 都给出同一个结果**：
   *     · 盒顶 0（页根扩展生效）⇒ 让位 56 ⇒ 顶边 56 ✓
   *     · 盒顶 47（扩展没生效）⇒ 让位 9  ⇒ 顶边 56 ✓
   *   ⇒ **不会双重扣减**，只让结果对"扩展到底有没有生效"免疫 ✓
   *   （这正是 §56.50 里留的兜底 (b)，本轮的接线就是它。）
   */
  /**
   * ★★★ 2026-10-17（**照搬无界 `MorphGuard`：形变期间不许改配色的"安静窗口"**）
   *
   * ## 无界那两条（`design/src/main/ets/logic/MorphGuard.ets`，`wujie.pa:92721-92815`）
   * ```ts
   *   // 模块级状态（初值都是 0）：
   *   MorphGuard.morphQuietUntil = 0;
   *   MorphGuard.colorSettleUntil = 0;
   *
   *   function animateMorph(ui, …, quietMs, onBlocked): boolean {
   *     const now = Date.now();
   *     MorphGuard.morphQuietUntil = now + quietMs;            // ★ 起补间时把"安静窗口"推到未来
   *     if (!(now >= MorphGuard.colorSettleUntil)) {           // 配色还没安定
   *       onBlocked(); return false;                           // ★ 这次形变**不起**
   *     }
   *     ui.animateTo({ curve }, …); return true;
   *   }
   *   colorApplyAllowed(now, until) = now >= until;
   *   colorApplyWaitMs(now, until) = until - now;
   * ```
   * 而**配色应用侧**（`MainPage`，`wujie.pa:145945-145989`）：
   * ```ts
   *   const wait = colorApplyWaitMs(Date.now(), MorphGuard.morphQuietUntil);
   *   if (wait > 0) {                                   // ★ 还在安静窗口里
   *     if (!this.colorModeRetryQueued) {
   *       this.colorModeRetryQueued = true;
   *       setTimeout(λ, wait + 32);                     // ★ 0x20 = 32ms 余量，稍后重试一次
   *     }
   *     return;                                         // ★ 本次不上色
   *   }
   *   …正常上色…
   *   // 重试 λ（wujie.pa:157930-157939）：colorModeRetryQueued = false; syncReportChrome();
   * ```
   * ⇒ 语义：**形变动画跑着的时候，配色一律往后挪**（改色会打断/污染正在跑的补间，
   *   观感就是"动画中途背景色突然跳一下"），窗口一过自动补一次。
   *
   * ## 本仓的映射
   * · 写侧：{@link markMorphQuiet}，在各处**起形变补间**的那一刻调，
   *   `quietMs` **就用那条补间自己的时长**（无界那侧也是按调用点传的，
   *   例如 `closeSearchMorph` 传 `SP_SEARCH_SETTLE_MS`）⇒ **没有任何新造常量**；
   * · 读侧：{@link colorApplyAllowed} / {@link colorApplyWaitMs}，
   *   由 `PlaybackPage` 的两处"上色点"（流光 shader 参数 / 网格背景源）查询。
   *
   * ⚠️ 与 `colorSettleUntil`（"配色还没安定就别起形变"那半条）**本轮没接** ——
   *   本仓没有"配色安定时刻"这个概念（取色是异步的，没有 settled 回调），
   *   要接得先定义"什么算安定"。记在 `RzdMusic记忆.md` §140 的待办里。
   */
  private morphQuietUntilMs: number = 0;

  /**
   * 把"配色安静窗口"推到 `durationMs` 之后 —— 照搬 `MorphGuard.animateMorph` 的第一句。
   * @param durationMs **正在起的这条形变补间的时长**（不要另造常数）
   */
  public markMorphQuiet(durationMs: number): void {
    if (durationMs <= 0) {
      return;
    }
    this.morphQuietUntilMs = Date.now() + durationMs;
  }

  /** @returns 现在能不能上色（= 安静窗口已过）—— 照搬 `MorphGuard.colorApplyAllowed`。 */
  public colorApplyAllowed(): boolean {
    return Date.now() >= this.morphQuietUntilMs;
  }

  /** @returns 还要等多久才能上色（ms；0 = 现在就能）—— 照搬 `MorphGuard.colorApplyWaitMs`。 */
  public colorApplyWaitMs(): number {
    const wait: number = this.morphQuietUntilMs - Date.now();
    return wait > 0 ? wait : 0;
  }

  @Trace public pageBoxTopVp: number = 0;

  /**
   * ★★★ 2026-10-17（**为"`lyricPadTop()` 换无界式子"补的最后一块测量**）：
   * **歌词页那一棵 `Column`（Swiper 页 1 的内容盒）的窗口顶边**（vp，实测；0 = 还没量到）。
   *
   * ## 为什么要它
   * 无界 `lyricPadTop() = overlayBoxH()/2 + morph.bottomYAtLyric() + 23`
   * （`wujie.pa:172855-172890`，逐条已解）。把归档笔记那组实测值代进去
   * （`700/2 + (−175.28) + 23 = 197.72`）反解：
   * ```
   *   bottomYAtLyric = −175.28  ⇒  它**不是**窗口坐标（否则浮层跑到屏幕外）
   *   boxH/2 + bottomYAtLyric = 350 − 175.28 = 174.72
   *   ⇒ 即"**浮层底边相对盒顶**" —— 也就是那一项度量的是**以盒中心为原点**的 y，
   *     再靠 `boxH/2` 换算成"从盒顶量起"
   * ```
   * ⇒ 那个式子的**本体**就是「浮层底边（相对盒顶） + 23」，与 `.padding({top})` 的口径一致
   *   （`padding` 本来就是**盒内相对量**）。
   *
   * ## 本仓现在差什么
   * 我们用 `lyricCoverYOf() + lyricCoverSizeOf() + LYRIC_PAD_GAP_VP(23)`，
   * 即"浮层底边（**窗口**坐标） + 23" ⇒ 两者**只在 `lyricBoxTopVp ≈ 0` 时等价**。
   * ⇒ 本字段就是判据：**量到 0 就说明我们的式子已经是对的**；
   *   量到明显非 0 ⇒ 要改成 `(浮层底边 − lyricBoxTopVp) + 23`（一行）。
   * ⚠️ 这一点与本仓 §56.50 那条"让位量是**相对盒顶**的"是**同一个形状**，
   *   而 `topInsetVp()` 早就吃过这个亏（当时多让了一个状态栏）⇒ 先量再改。
   */
  @Trace public lyricBoxTopVp: number = 0;

  /**
   * 歌词页内容盒顶边上报（由歌词页那棵 `Column` 的 `onAreaChange` 喂，`globalPosition.y`）。
   * @param topVp 盒顶（vp，窗口坐标）
   */
  public reportLyricBoxTop(topVp: number): void {
    const v: number = topVp > 0 ? topVp : 0;
    if (Math.abs(v - this.lyricBoxTopVp) > 0.5) {
      this.lyricBoxTopVp = v;
      Logger.info(PlayerExpandState.LOG_TAG,
        `RzdLyricBoxTop top=${v.toFixed(1)} ⇒ lyricPadTop=${this.lyricPadTop().toFixed(1)} ` +
        `(overlayBottom=${(this.lyricCoverYOf() + this.lyricCoverSizeOf()).toFixed(1)})`);
    }
  }

  /**
   * 播放页页盒顶边上报（由路由壳的 `onAreaChange` 喂，`area.position.y`）。
   * @param boxTopVp 页盒顶（vp，窗口坐标）
   */
  public reportPageBoxTop(boxTopVp: number): void {
    const v: number = boxTopVp > 0 ? boxTopVp : 0;
    if (Math.abs(v - this.pageBoxTopVp) > 0.5) {
      this.pageBoxTopVp = v;
      Logger.info(PlayerExpandState.LOG_TAG,
        `RzdPageBoxTop boxTop=${v.toFixed(1)} ⇒ topInset=${this.topInsetVp().toFixed(1)} ` +
        `(target=${Math.max(this.statusBarTopVp, PlayerExpandState.PLAYER_TOP_FALLBACK_VP).toFixed(1)})`);
    }
  }

  public topInsetVp(): number {
    // 目标：**内容顶边**落在窗口的 `max(状态栏, 56)` 那条线上（= 无界 `padTop()` 的口径）。
    const target: number = this.statusBarTopVp > 0
      ? Math.max(this.statusBarTopVp, PlayerExpandState.PLAYER_TOP_FALLBACK_VP)
      : this.windowHeightVp * PlayerExpandState.LYRIC_COVER_TOP_RATIO_STATUS;
    // ★ 自适应：让位是"**相对盒顶**"的 ⇒ 减去实测盒顶（量不到时按 0，与改前完全一致）。
    const boxTop: number = this.pageBoxTopVp > 0 ? this.pageBoxTopVp : 0;
    const off: number = target - boxTop;
    return off > 0 ? off : 0;
  }

  /**
   * 展开页 ⇄ 歌词页两套端点之间插值。
   * @param t 0 = 展开页（用实测的 `big*`），1 = 歌词页（用算出来的位置）
   * @returns 封面的一帧矩形（vp，窗口坐标）
   */
  public lyricMorph(t: number): LyricMorphRect {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    const fromRect: LyricMorphRect = this.bigEndpointRect();
    const fromSize: number = fromRect.size;
    const toSize: number = this.lyricCoverSizeOf();
    const size: number = this.lerp(fromSize, toSize, p);
    const height: number = this.lerp(fromRect.height, toSize, p);
    return {
      x: this.lerp(fromRect.x, this.lyricCoverXOf(), p),
      y: this.lerp(fromRect.y, this.lyricCoverYOf(), p),
      size: size,
      // 歌词页那一端是算出来的正方形；展开页那一端沿用实测的落点矩形（可能不是正方形）
      height: height,
      // ★★★ 2026-10-16（照抄无界 `CoverMorph.visualRadiusAt`）：**两端点 lerp**
      radius: this.lerp(PlayerExpandState.COVER_RADIUS_PLAYER_VP,
        PlayerExpandState.COVER_RADIUS_LYRIC_VISUAL_VP, p)
    };
  }

  /**
   * @returns 「展开页那一端」的封面矩形（vp，窗口坐标）。
   *
   * ⚠️ **必须与「续飞封面 p = 1 的落点」逐像素相同**（`morphCoverRectAt(1)` 用的就是同一段算式）：
   *    歌词页浮层在回来的那一趟终点会**卸载自己并把真封面放出来**，两端不一致就会在交棒那一帧
   *    跳一下（5% 的视觉缩放差就够看见了 —— 真封面播放态被弹簧放大 1.05 / 暂停态 0.95）。
   *    所以这里**不直接用** `bigX/bigY/bigSize`（那是布局矩形、不含视觉缩放），
   *    而是复用同一段端点几何；几何还没就绪时才退回 `reportBig` 的上报值。
   */
  private bigEndpointRect(): LyricMorphRect {
    if (this.endCoverSize > 0 && this.snapStartW > 0) {
      return this.morphCoverRectAt(1);
    }
    const fallbackSize: number = this.playerCoverWidth();
    if (fallbackSize > 0) {
      return {
        x: this.bigX,
        y: this.bigY,
        size: fallbackSize,
        height: fallbackSize,
        radius: this.bigRadius > 0
          ? this.bigRadius
          : fallbackSize * PlayerExpandState.COVER_RADIUS_RATIO
      };
    }
    // ★★ 2026-10-15（照搬无界 `CoverMorph`）：实测缺失时给**纯几何兜底**，
    //   绝不让端点变成 0×0。
    //   无界的封面端点本来就是**算出来的**（`CoverMorph` 由 `fitPlayerOverlay` 的
    //   `edge / metaY` 构造，全程不查节点）；派音这边靠 `MusicPlayInfoBlock` 的
    //   `onAreaChange → reportBig` 上报，**上报没来**（换歌瞬间、组件被替换、
    //   量测时序错开）时 `bigSize = 0` ⇒ `lyricMorph()` 起点成零矩形
    //   ⇒ **封面缩成一点、展开动画没有端点**（2026-10-15 那次"封面消失 + 动画全废"
    //   就是这个形状的极端版）。
    //   ⚠️ 只在实测缺失时生效（`bigSize > 0` / `bigX/bigY` 有效时一字不改）
    //      ⇒ 正常路径与静止态**逐像素不变**。
    return this.fallbackBigRect();
  }

  /**
   * @returns 播放页封面**布局基准矩形**（vp，窗口坐标）—— **纯几何、不查任何节点**。
   *
   * ★★ 2026-10-15（照搬无界的 `CoverMorph`）：这是"变换式覆盖层"的**基准尺寸**。
   *
   * 为什么必须有它：无界的 `floatingCover` 是一个**满屏居中布局**的容器，
   * 封面在里面**按布局尺寸排**，只有 `scale / translate` 会把它挪走 ⇒
   * `t = 0`（封面页）时变换是恒等、位置由**布局**决定。派音原来的覆盖层是
   * `.width(lyricMorph(t).size).position(lyricMorph(t).x…)` —— **位置和尺寸都由形变给**
   * ⇒ 一旦让它当唯一渲染者，就变成"宽度依赖上报、上报依赖宽度"，
   * 初始上报 0 时**不动点退化在 0**（2026-10-15 那次"封面消失 + 动画全废"的机制）。
   *
   * 尺寸口径照抄无界 `fitPlayerOverlay`：
   * ```
   * edge = clamp(min(winW − 2·sidePad, winH − 2·(gap + metaH + 8)), COVER_EDGE_MIN 200, CAP 480)
   * ```
   * （`winW − 2·sidePad` 就是无界 `coverEdgeMaxOf(swiperBoxW, pageSide, winWVp)` 的产物 ——
   *   360 宽机型上 ≈ 328，与 `播放页背景-*.md` 记录的"`edge` 常态 ≈ 328"一致。）
   * 水平/竖直都居中（无界的 `floatingCover` 是 `Column(center, center)`）。
   */
  /** `fitPlayerOverlay` 的 `META_GAP_BELOW_COVER`（字节码默认值 50）。 */
  private static readonly COVER_FIT_META_GAP_VP: number = 50;
  /** `fitPlayerOverlay` 里那个"硬编码 +8"（上界夹紧用）。 */
  private static readonly COVER_FIT_BOUND_INSET_VP: number = 8;
  /**
   * `CoverMorph.metaTopFixLyric` 的默认值（vp）—— **元信息块歌词页端锚点的修正量**。
   *
   * ★★★ 2026-10-17（**回原始字节码重读，订正上一版**）：
   *
   * ```
   *   85527  ldai 0x1c        ← 0x1c = **28**
   *   85528  sta v0
   *   85531  ldobjbyname 0x55, "metaTopFixLyric"      ; acc = a3.metaTopFixLyric
   *   85534  ldnull / stricteq → jnez L19             ; 传 null ⇒ 用默认
   *   85537  ldundefined / stricteq → jnez L19        ; 传 undefined ⇒ 用默认
   *   85540  mov v0, v1                               ; 否则用调用方给的
   *   85542  lda v0 / 85543 stobjbyname "metaTopFixLyric"
   * ```
   *   ⇒ **默认值 = `+28`，而且 `85527` 之后【没有 `neg`】。**
   *
   * ⚠️ **本仓上一版写的是 `−26`**，出处是归档笔记
   *   `_recover/logic-src/歌词页浮层封面与歌名定稿.md:858`「默认 -26（`ldai 0x1a / neg`）」
   *   与同文件 `:1356`「**-26** ← `85527 ldai 0x1c`」——
   *   这两行**互相矛盾**（一处说 `0x1a`+`neg`，一处说 `0x1c`），**都不能用**。
   *
   * ★ 负号在本文件所依赖的那份反汇编里**一定写成 `ldai <绝对值> / neg`**（可复现的两处铁证）：
   * ```
   *   txLyric 默认 −151：85462 ldai 0x97 + 85463 neg        （0x97 = 151）
   *   tyPlayer 默认 −40 ：（同族，CoverMorph 构造函数里 `v0 = (-(40))`）
   * ```
   *   ⇒ `85527 ldai 0x1c` 无 `neg` ⇒ **+28**，不是 −28 也不是 −26。
   *
   * ★ **语义（这一条比数值更容易搞错）**：`metaOffsetYAt(t)` 返回的是元信息块的**中心 Y**，
   *   不是顶边 —— 见 `CoverMorph.metaOffsetYAt` 的两个端点：
   * ```
   *   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
   *   · metaYPlayer —— `fitPlayerOverlay` 给的 `coverBottom + gap + metaH/2` **（中心）**
   *   · topYAtLyric() + 28 —— `coverTop + 28`；小封面可视边 ≈ 48.72 ⇒ 其中心 = coverTop + 24.36
   *     ⇒ **`coverTop + 28` ≈ 小封面的竖直中心** ✓ 两端点**同为"中心"**，自洽。
   * ```
   *   ⇒ 本仓在用值（顶边）要与它对比，必须先 `− rowH/2` 换成顶边（见 `metaTopGeomY`）。
   */
  public static readonly META_TOP_FIX_LYRIC_VP: number = 28;
  /**
   * `CoverMorph.tyPlayer` 的默认值（= 播放页端封面中心的基准偏移）。
   *
   * ⚠️ 它相对**谁**我**始终没读准**：按 `topYAtPlayer() = tyPlayer − edge/2` 会算出
   *   `−40 − 164 = −204`（在屏幕外），与无界截图（封面在屏幕上部）矛盾。
   * ⇒ **本实现不用它**，改用"从内容顶边往下推"的等价式（见 `playerCoverGeomRect()` 的注释）。
   *   本常量保留只为记录逆向值、并给下一轮留线索。
   *
   * ★★ 2026-10-16（**订正符号：实为 `+40`，不是 `−40`**）：
   *   归档笔记 `_recover/logic-src/歌词页浮层封面与歌名定稿.md:581` 原文写的是
   *   @@COVER_TY_PLAYER,                    // = 40   ← ★ 第五个参数，不是 metaGap！@@
   *   而 `topYAtPlayer() = tyPlayer − edge/2`（`wujie.pa:85656-85667`）⇒ `40 − 164 = −124`
   *   仍然在屏外，说明 **`tyPlayer` 的基准不是窗口顶边**（这条推断与本函数头注释一致）。
   *   ⇒ 值改成 **+40** 以免下一个人按 −40 复算；**本实现仍然不用它**（用等价式）。
   */
  private static readonly COVER_TY_PLAYER_VP: number = 40;

  /**
   * @returns 元信息块**顶边**的**无界算式值**（vp，窗口坐标）。
   *
   * ★★★ 2026-10-16（goal 第 1 条「元信息行照搬 `floatingMeta`」的**可核对化** —— 第二版）
   *
   * ## ⚠️ 第一版绕远了（自记）
   * 我第一版写成 `lyricMorph(1).y + metaTopFixLyric` —— 那是"从**封面端点**反推"，
   * 绕过了 `fitPlayerOverlay` 自己算出来的 `metaY`。**正确做法是从算式直接推**（如下）。
   *
   * ## 无界的算式链（逐字）
   * ```ts
   *   // ① CoverMorph 的起点（wujie.pa:177459-177464）
   *   metaYPlayer = fit.metaY          // 由 refitOverlay 写入
   *   // ② 封面中心（playerCoverGeomRect 的 ⑤ 步已经算出来）
   *   centerY = contentTop + metaY     其中 metaY = curMetaY(0) + edge/2 + gap + metaH/2
   *   // ③ 歌词页那一端的元信息块顶边（wujie.pa:85582-85599）
   *   metaOffsetYAt(1) = topYAtLyric + metaTopFixLyric
   *   // ④ 元信息块**中心**随 t 走的那条线
   *   //    t=0 时其中心 = centerY − edge/2 − META_GAP_BELOW_COVER
   *   metaCenterY(t) = lerp(centerY(t) − edge(t)/2 − gap, topYAtLyric(t) + metaTopFixLyric(), t)
   * ```
   *
   * ## ★ 关键恒等式（本轮静态核出来的，两端都成立）
   * ```
   *   t = 0：metaTop(0) = centerY − edge/2 − gap + metaH/2 − metaH/2 = 封面底边 + gap(50)
   *   t = 1：metaTop(1) = topYAtLyric + metaTopFixLyric
   *                     = (topInset + 48.72) + (−26) = topInset + 22.72
   *          我们的：     = lyricCoverYOf() = topInset + LYRIC_ROW_TOPBAR_H_VP(56)
   *          两者差 26 是**设计差**，不是量测差 —— 见下面"那 26vp 到底是什么"。
   * ```
   *
   * ## 那 26vp 到底是什么（别再用"K 比卡片矮"去解释它）
   * 这 26 是**两种锚法在同一个卡片高度下的必然差**：
   * ```
   *   我们的端点在"封面**顶边**"（并排布局：文字与封面竖直居中，行高 = 封面边长）
   *   无界的端点在"封面顶边 − 26"（`metaTopFixLyric`）
   *   ⇒ 只要封面边长 = 48.72，两者就**恒差 26**，与卡片真实高度无关。
   * ```
   * ⚠️ 所以"该不该减掉这 26"**不能靠算式判**（算式给了两条同样自洽的路），
   *    只能靠**观感**：它决定"歌词页那一行文字与左边小封面是**顶对齐**还是**居中**"。
   *    ⇒ 这正是 goal 里那句「⚠️ 拆 `LyricFloatLayer` 时不要碰已验证好的那部分」的适用场合。
   *    ⇒ 本轮把它**量出来**（徽标 `metaD`），**不改**。
   *
   * @param t 形变进度（0 = 封面页端 / 1 = 歌词页端）
   * @param rowH 元信息行自身高度（`PlaybackPage.LYRIC_META_ROW_H_VP`）——
   *        用来把无界的**中心**换算成本仓对账用的**顶边**（见下面那段订正）
   * @returns 元信息块**顶边**（vp，窗口坐标）—— 与本仓在用值**同口径**，可直接相减
   *
   * ★★★ 2026-10-17（**订正：无界那两端是"中心"，本函数原来是拿它当"顶边"用的**）
   *
   * `CoverMorph.metaOffsetYAt`（`design__src__main__ets__logic__CoverMorph.ets:205-211`）：
   * ```
   *   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
   * ```
   * 而 `metaYPlayer` 出自 `fitPlayerOverlay`：`coverBottom + gap + metaH/2` **（中心）**；
   * 另一端 `topYAtLyric() + 28` ≈ 小封面的竖直中心（见 `META_TOP_FIX_LYRIC_VP` 的推导）
   * ⇒ **两端点都是"元信息块的中心 Y"**，所以：
   * ```
   *   fromTop = coverBottom + gap                    （= 中心 − rowH/2）
   *   toTop   = lyricCoverTop + 28 − rowH/2          （= 中心 − rowH/2）
   * ```
   * 本函数返回**顶边**（在用的那条 `.position().y` 就是顶边）⇒ 直接可比。
   *
   * ⚠️ 上一版写的是 `toTop = lyric.y − 26` —— **数值错（−26 应为 +28）、口径也错（把中心当顶边）**，
   *   于是徽标第六行的 `metaD` 一直在报一个**并不存在**的偏差。
   *   订正后：`metaD = metaTop − metaExp` 在 **t=0 与 t=1 两端都应 ≈ 0**
   *   （两端式子现在逐字同源）；**中段**若不为 0，那是"位置 lerp 的进度源不同"
   *   （我们用 `lyricMorphT`，无界用 `swiperProgress`），那才是真正要看的东西。
   */
  public metaTopGeomY(t: number, rowH: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    // ★ 2026-10-17：`from` 那一端改用 `bigEndpointRect()`（= 与**续飞封面落点**同一个矩形，
    //   和 `lyricMorph()` 起点同源 ⇒ 歌名与封面在封面页那一端**逐像素对齐**，
    //   不会出现"封面按 A 矩形落、歌名按 B 矩形摆"）。它内部已经带纯几何兜底。
    const fromRect: LyricMorphRect = this.bigEndpointRect();
    if (fromRect.size <= 0) {
      return 0;
    }
    const gap: number = PlayerExpandState.COVER_FIT_META_GAP_VP;      // 50（无界默认）
    const halfRow: number = rowH > 0 ? rowH / 2 : 0;
    // ① t = 0 那一端：封面底边 + gap（= `fitPlayerOverlay` 的 metaY − metaH/2）
    const fromTop: number = fromRect.y + fromRect.height + gap;
    // ② t = 1 那一端：小封面顶边 + metaTopFixLyric(+28) − rowH/2
    const lyric: LyricMorphRect = this.lyricMorph(1);
    const toTop: number = lyric.y + PlayerExpandState.META_TOP_FIX_LYRIC_VP - halfRow;
    return this.lerp(fromTop, toTop, p);
  }

  /** @returns 元信息块顶边的**在用值**（= 我们在 `.position()` 里真正用的那个）—— 给徽标对账用。 */
  public metaTopInUseY(): number {
    return this.lyricMetaYOf();
  }

  /**
   * @returns 元信息块顶边的**在用值（带 t）** —— 与 `PlaybackPage` 里那条 `.position()` 表达式
   *          **逐字同一份**（含那里那个"竖直居中补偿"项），供徽标逐帧对账。
   *
   * 出处：`PlaybackPage.LyricFloatLayer()` 里 meta 那一行的
   * ```ts
   *   y: lyricMetaMorphY(t) + t × (lyricFloatRect().size − LYRIC_META_ROW_H_VP) / 2
   * ```
   * ⚠️ 两者**必须同步改**（这里是唯一允许复制那条表达式的地方，复制目的是对账）。
   * @param t 形变进度
   * @param rowH 元信息行自身高度（`PlaybackPage.LYRIC_META_ROW_H_VP`）
   */
  public metaTopInUseYAt(t: number, rowH: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    return this.lyricMetaMorphY(p) + p * (this.lyricMorph(p).size - rowH) / 2;
  }

  /**
   * @returns 播放页封面**锚定矩形**（vp，窗口坐标）。
   *
   * ★★★ 2026-10-16（**照用户指示「直接照搬无界」，把算式换成无界的纯几何**）
   *
   * ## 无界的算式（逐字，`歌词页浮层封面与歌名定稿.md` §4.2 / §4.1）
   *
   * ```ts
   * // ① 边长上限：coverEdgeMaxOf(swiperBoxW, pageSide) —— "Swiper 宽 − 2×页面留白"
   * const curEdgeMax = clamp(swiperBoxW - 2*pageSide, 200, 480);
   * // ② fitPlayerOverlay(availH, metaH=60, curEdgeMax, _unused, curMetaY, gap=50)
   * const maxForBox = availH - 2*(gap + metaH + 8);
   * let edge = curEdgeMax;  if (!(curEdgeMax < maxForBox)) edge = maxForBox;
   * if (edge < 200) edge = 200;
   * const metaY = curMetaY + edge/2 + gap + metaH/2;
   * const bound = (availH/2 - metaH/2) - 8;
   * metaY = metaY > bound ? bound : metaY;
   * // ③ 封面中心 = 内容顶边 + metaY
   * ```
   * 其中 `availH = 窗口高 − padTop(56) − padBottom(65)`、`curMetaY = 0`
   * （= "从内容顶边往下推"，依据：`META_Y_PLAYER_MAX` 那类**负值**常量说明 `curMetaY` 的基准是"内容顶边"）。
   *
   * ## 手机上逐位核对（360×780 窗口）
   *
   * ```
   *   availH = 780 − 56 − 65 = 659              （⚠️ 这一步是关键：**不能**把整窗高当 availH）
   *   swiperBoxW − 2×16 = 328  ⇒ curEdgeMax = 328
   *   maxForBox = 659 − 2×(50+60+8) = 423 ≥ 328 ⇒ edge = 328
   *   metaY = 0 + 164 + 50 + 30 = 244 ≤ bound(291) ⇒ 244
   *   封面中心 = 56 + 244 = **300**，顶边 = 300 − 164 = **136vp**
   * ```
   * ★★ 2026-10-16（**订正一处算式**）：上面 `metaY` 那行原来写 `= 244`，但
   *   `0 + 164 + 50 + 30 = **234**`（164+50+30=244 是把 `edge/2` 与 `metaH/2` 相加时算错了）。
   *   ⚠️ **代码本身一直是对的**（代码就是 `edge/2 + gap + metaH/2`），错的只是这行注释。
   *   ⚠️ 用 234 代入后：封面中心 = `56 + 234 = **290**`、顶边 = `290 − 164 = **126vp**`。
   *   我**不据此改代码** —— 用户已在真机验收封面位置"现在正常了"，静止态位置以**实测为准**；
   *   而 `+10` 这个差与 `bounds`/`estBoxH` 的口径有关，**需要实测才能定**（见
   *   `estBoxHVp()` 那段"为什么只用诊断"的说明）。
   *   复核入口：徽标**第六行**的 `metaTop` / `metaExp` / `metaD`（见 {@link metaTopGeomY}）。
   * ⇒ 相对"在窗口里居中"（中心 390、顶边 226）**上移 90vp** —— 这就是用户要的"高一些"。
   *
   * ## 为什么这次能定住（与 §72 那次失败的区别）
   *
   * §72 我改的也是这个函数，但**同时**把"宽预算"换成了 `swiperBoxW` 并配上了一个
   * `COVER_FIT_GAP_VP = 20`（我自己编的 gap）⇒ 两个改动叠在一起、且 gap 是错的。
   * 这次**只照抄算式**：`gap = 50`（无界默认）、`metaH = 60`（无界兜底）、
   * `availH = 高 − 上下让位`（无界的 `availH` 定义）—— 三处都有字节码出处。
   *
   * ⚠️ 仍然**没有**用 `tyPlayer`（见上面那个常量的注释）；`curMetaY = 0` 是等价替代。
   * ⚠️ `x` 仍然是"水平居中"（无界 `floatingCover` 是 `Column(center)`）⇒ 未改行为。
   */
  public playerCoverGeomRect(): LyricMorphRect {
    const w: number = this.windowWidthVp;
    const h: number = this.windowHeightVp;
    if (w <= 0 || h <= 0) {
      return { x: 0, y: 0, size: 0, height: 0, radius: 0 };
    }
    // ① `availH` = 无界的可用高度（**扣掉上下让位**，不是整窗高）
    const availH: number = Math.max(1, h - this.topInsetVp() - this.navigationBarBottomVp);
    // ② `coverEdgeMaxOf(swiperBoxW, pageSide)`
    const pageSide: number = PlayerExpandState.LYRIC_COVER_LEFT_VP;
    const swiperBoxW: number = Math.max(1, Math.min(w, availH));
    let curEdgeMax: number = swiperBoxW - 2 * pageSide;
    if (curEdgeMax > PlayerExpandState.COVER_EDGE_CAP_VP) {
      curEdgeMax = PlayerExpandState.COVER_EDGE_CAP_VP;
    }
    if (curEdgeMax < PlayerExpandState.COVER_EDGE_MIN_VP) {
      curEdgeMax = PlayerExpandState.COVER_EDGE_MIN_VP;
    }
    // ③ `fitPlayerOverlay`
    const metaH: number = PlayerExpandState.COVER_FIT_META_H_VP;      // 60（无界兜底）
    const gap: number = PlayerExpandState.COVER_FIT_META_GAP_VP;      // 50（无界默认）
    const inset: number = PlayerExpandState.COVER_FIT_BOUND_INSET_VP; // 8（无界硬编码）
    const maxForBox: number = availH - 2 * (gap + metaH + inset);
    let edge: number = curEdgeMax;
    if (!(curEdgeMax < maxForBox)) {
      edge = maxForBox;
    }
    if (edge < PlayerExpandState.COVER_EDGE_MIN_VP) {
      edge = PlayerExpandState.COVER_EDGE_MIN_VP;
    }
    if (edge > curEdgeMax) {
      edge = curEdgeMax;
    }
    if (edge < 0) {
      edge = 0;
    }
    // ④ `metaY`（`curMetaY = 0` ⇒ "从内容顶边往下推"）再被上界夹住
    const metaYRaw: number = edge / 2 + gap + metaH / 2;
    const bound: number = (availH / 2 - metaH / 2) - inset;
    const metaY: number = metaYRaw > bound ? bound : metaYRaw;
    // ⑤ 封面中心 = 内容顶边 + metaY
    const centerY: number = this.topInsetVp() + metaY;
    return {
      x: (w - edge) / 2,
      y: centerY - edge / 2,
      size: edge,
      height: edge,
      radius: edge * PlayerExpandState.COVER_RADIUS_RATIO
    };
  }

  /**
   * @returns 播放页封面端点的**纯几何兜底**：直接复用 {@link playerCoverGeomRect}
   *          （口径统一在一处，避免"两个几何值"打架）。
   */
  private fallbackBigRect(): LyricMorphRect {
    return this.playerCoverGeomRect();
  }

  // ─────────────── 二·补（A2）：歌词页顶部的「封面 + 歌名」浮层 ───────────────
  //
  // 对标无界 `PlayerPage`：封面与歌名**挂在 Swiper 之外的浮层**上，切到歌词页时
  // 「同一个元素」缩小并移到顶部；歌词正文靠 `lyricPadTop()` 按浮层高度让位。
  // 这里只提供**几何**，怎么画由 `PlaybackPage.LyricFloatLayer()` 决定。

  /**
   * 歌词页浮层里「封面底边 → 歌名块顶边」的间距（vp）。⚠️ 本项目估定值，非逆向值。
   *
   * ★ 2026-10-17：**它现在只剩一个用途** —— 徽标第六行 `metaOld=` 那条**旧式子**
   *   （`lyricMetaFromYOf()` → `lyricMetaMorphY()` → `metaTopInUseYAt()`）的对账。
   *   歌名块的**真实渲染位置**在 §131 已改成 `metaTopGeomY(t, rowH)`，那里用的是
   *   无界的 `COVER_FIT_META_GAP_VP(50)`（**不是这个 10** —— 见 §131.2：
   *   这个 10 是把"被丢弃的档位 `metaGap`"当成了真值）。
   *   ⚠️ 因此**不要**再拿它去参与任何渲染计算。
   */
  private static readonly LYRIC_META_GAP_VP: number = 10;
  /** 歌词页浮层里「歌名 + 歌手」两行所占高度（vp）。⚠️ 本项目估定值，非逆向值。 */
  private static readonly LYRIC_META_BLOCK_H_VP: number = 44;
  /** 歌词页浮层底边与歌词正文之间的呼吸间距（vp）。⚠️ 本项目估定值，非逆向值。 */
  /**
   * 歌词页正文让位的**呼吸间距**（vp）—— 无界 `lyricPadTop()` 里那个字面量 **`+23`**。
   *
   * ★★★ 2026-10-17（照搬无界，`wujie.pa:172888`）：`ldai 0x17` = **23**。
   *   ```ts
   *     lyricPadTop() {
   *       if (!this.lyricFloat) return 0;
   *       const boxH = this.overlayBoxH();
   *       if (boxH <= 0) return LYRIC_PAD_TOP_FALLBACK;      // 96
   *       return boxH / 2 + this.morph.bottomYAtLyric() + 23;
   *     }
   *   ```
   * ⚠️ 本仓原来写的是 **10**（自定值）。
   * ⚠️ 见 `lyricBoxTopVp` 的注释：**这个常量与"盒内相对量"是同一件事的两半** ——
   *   无界那个 `boxH/2 + bottomYAtLyric()` 合起来就是"**浮层底边相对盒顶**"（推导见那里），
   *   本仓目前直接给"浮层底边（窗口坐标）+ 本常量"，两者**只在 `lyricBoxTopVp ≈ 0` 时等价**。
   *   测量已接上（徽标第六行 `lBox=`）⇒ 拿到读数再决定要不要换成盒内相对量。
   */
  private static readonly LYRIC_PAD_GAP_VP: number = 23;
  /**
   * 歌词页浮层几何拿不到时的**兜底顶部留白**（vp）。
   *
   * ★★★ 2026-10-17（照搬无界 `LYRIC_PAD_TOP_FALLBACK`）：**96**（本仓原来是 **150**，自定值）。
   *
   * 出处：`PlayerPage.lyricPadTop()` 的兜底支走的是文件级 lexenv 槽 **`0x06`**
   * （`wujie.pa:172872-172874`：`ldlexvar 0x1, 0x6` + `throw.undefinedifholewithname
   * "LYRIC_PAD_TOP_FALLBACK"`），而槽位表与取值在归档笔记里已经核过：
   * `_recover/logic-src/歌词页浮层封面与歌名定稿.md:1299`
   * 「`0x06` | `LYRIC_PAD_TOP_FALLBACK` | **96** | `lyricPadTop()` 兜底」。
   * 同一份笔记的差异表 `:1448` 也早已标出「派音 150 vs 无界 96 —— 不一致但影响小」。
   *
   * ⚠️ 这条兜底一旦命中，观感就是"**歌词顶上多一块空白**"（笔记 `:1434` 的原话）
   *   ⇒ 150 比 96 多 54vp 的空白，属于**该修的自定值**。
   */
  private static readonly LYRIC_PAD_TOP_FALLBACK: number = 96;

  /**
   * @returns 歌词页浮层（封面 + 歌名/歌手）是否启用。
   *
   * 与无界的 `lyricFloat` 同义：**不开浮层 ⇒ `lyricPadTop()` 必须返回 0**（不预留空间，
   * 版面与没有这套东西时逐像素一致）。
   *
   * ⚠️ 除了"几何就绪"，还要求**封面尺寸已经上报**（`lyricCoverSizeOf() > 0`）：
   *    播放页大封面还没量到时，歌词页封面算出来是 0 × 0 —— 那时若还按浮层让位，
   *    就会凭空多出一段顶部留白。此时整套浮层**整体不启用**，退回"原生 Swiper 滑动"的老样子。
   */
  public lyricFloat(): boolean {
    return this.lyricGeometryReady() && this.lyricCoverSizeOf() > 0;
  }

  /**
   * @returns 歌词页歌名块的顶边（vp，窗口坐标）。
   *
   * ★★ 2026-10-15（照搬无界）：**与封面同一个顶边**（并排），不再是"封面底边 + 间距"。
   *   无界 `metaRow` 与 `floatingCover` 在歌词页占同一条水平带：封面在左、文字在右，
   *   文字与封面**竖直居中**对齐（`PlaybackPage` 那边把行高设成封面边长来保证这一点）。
   *   ⚠️ 所以歌名块的 y 与封面 y 相同，横向由**行的左内边距**（封面右缘 + 12）让开。
   */
  public lyricMetaYOf(): number {
    return this.lyricCoverYOf();
  }

  /** @returns **展开页那一端**歌名块的顶边（vp，窗口坐标）= 落点矩形底边 + 间距。 */
  public lyricMetaFromYOf(): number {
    const r: LyricMorphRect = this.bigEndpointRect();
    return r.y + r.height + PlayerExpandState.LYRIC_META_GAP_VP;
  }

  /**
   * @returns 歌名块顶边的一帧位置（vp，窗口坐标）。
   *
   * 与封面用**同一个进度**插值 ⇒ 封面与歌名是"同一个元素在动"（对标无界
   * `floatingCover` + `floatingMeta` 同属一层浮层、一起缩小移到顶部），
   * 而不是"切换的两页各画一份"。
   * @param t 0 = 展开页位置，1 = 歌词页顶部
   */
  public lyricMetaMorphY(t: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    return this.lerp(this.lyricMetaFromYOf(), this.lyricMetaYOf(), p);
  }

  /**
   * @returns 歌词页浮层（封面 + 歌名块）的**底边**（vp，从窗口顶边量起）。
   *
   * 歌名与封面在歌词页是**并排**的 ⇒ 浮层的底边就是**封面底边**
   * （不能用 `lyricMetaYOf() + LYRIC_META_BLOCK_H_VP` —— 那是"歌名排在封面下方"时的算法，
   *  并排之后会把留白算多一整块）。
   *
   * ★★★ 2026-10-17（**订正：这里原来多叠了一个 `+ LYRIC_META_GAP_VP(10)`**）：
   *   它唯一的消费者是 {@link lyricPadTop}，而 `lyricPadTop` 自己又会加一个呼吸间距
   *   （`LYRIC_PAD_GAP_VP`）⇒ **同一个"浮层底边之后的间距"被加了两次**（33 = 10 + 23）。
   *   而反解出来的无界式子只有**一次**（见 `lyricPadTop` 的注释）：
   * ```
   *   lyricPadTop = boxH/2 + bottomYAtLyric() + 23
   *                 └──────┬──────┘
   *              这两项合起来 = "浮层底边（相对盒顶）"，**不含任何额外间距**
   * ```
   *   ⇒ 本函数只返回**浮层底边**，"呼吸间距"一律由 {@link lyricPadTop} 那一层加。
   */
  public lyricOverlayHeight(): number {
    if (!this.lyricFloat()) {
      return 0;
    }
    const size: number = this.lyricCoverSizeOf();
    if (size <= 0) {
      return 0;
    }
    return this.lyricCoverYOf() + size;
  }

  /**
   * @returns 歌词页正文必须让位的**顶部内边距**（vp）—— 等价无界的 `lyricPadTop()`
   *          （`wujie.pa:172855-172890`，逐条已解）。
   *
   * ```ts
   *   lyricPadTop() {
   *     if (!this.lyricFloat) return 0;
   *     const boxH = this.overlayBoxH();                    // = swiperBoxH > 0 ? swiperBoxH : estBoxH()
   *     if (boxH <= 0) return LYRIC_PAD_TOP_FALLBACK;        // 96
   *     return boxH / 2 + this.morph.bottomYAtLyric() + 23;  // 0x17 = 23
   *   }
   * ```
   * ★ 前两项**合起来就是"浮层底边（相对盒顶）"**（把归档实测值 `700/2 + (−175.28) + 23 = 197.72`
   *   代进去反解得 `boxH/2 + bottomYAtLyric = 174.72`，见 `lyricBoxTopVp` 的注释）
   *   ⇒ 本仓写成"浮层底边 + `LYRIC_PAD_GAP_VP`"，**只差一个坐标系问题**：
   *
   * ⚠️ **仍未闭合的一步**：本仓 `lyricOverlayHeight()` 是**窗口**坐标，而无界那一项是
   *   **相对盒顶** ⇒ 两者只在 `lyricBoxTopVp ≈ 0` 时等价。判据已量出来（徽标第六行 `lBox=`），
   *   拿到读数后若明显非 0，改成 `(lyricOverlayHeight() − lyricBoxTopVp) + 23` 即可（一行）。
   *   ⚠️ 为什么不猜：这与 §56.50「让位量是**相对盒顶**的」同一个形状，
   *     `topInsetVp()` 当年就按"盒顶 = 0"写而**多让了一个状态栏**。
   * ⚠️ 中间的 `boxH <= 0` 是**防御分支**，按无界那份结构保留
   *   （`lyricFloat()` 已要求封面尺寸 > 0，正常流程走不到）。
   */
  public lyricPadTop(): number {
    if (!this.lyricFloat()) {
      return 0;
    }
    const overlayBottom: number = this.lyricOverlayHeight();
    if (overlayBottom <= 0) {
      return PlayerExpandState.LYRIC_PAD_TOP_FALLBACK;
    }
    return overlayBottom + PlayerExpandState.LYRIC_PAD_GAP_VP;
  }

  // ═════════════════════════ 三点五、整页形变放大（对标无界 ExpandAnimation 的"逐渐形变放大填满"）═════════════════════════
  //
  // 无界的展开不是"从底部弹上来一块"，而是**播放页从迷你条那个位置逐渐放大铺满整屏**。
  // 我们这边按下述方式等价实现（只用 `scale` 的 `centerX/centerY`，不碰任何形状裁剪 ——
  // 这是本文件里反复强调的红线：播放页的 path 裁剪历史上把页面搞坏过两次）：
  //
  //   1. **起点尺寸**：迷你条封面边长 / 窗口短边 —— 缩放从这么小开始；
  //   2. **锚点**：迷你条封面的中心在**本页坐标系**里的百分比位置 —— 缩放围绕它发生，
  //      视觉上就是"从迷你条那一小块长出来"，而不是从屏幕中心或底部弹出。
  //
  // 之所以能算：`reportMini()`（迷你条封面）和 `reportWindow()`（本页尺寸）都已经接上了。

  /** 起点缩放的下限：迷你条封面再小也不会小于窗口短边的这个比例（防止算成 0 完全看不见）。 */
  private static readonly MORPH_MIN_SCALE: number = 0.14;

  /** @returns 形变放大所需的几何是否齐了（迷你条封面已上报 + 本页尺寸已知）。 */
  public morphGeometryReady(): boolean {
    return this.miniSize > 0 && this.windowWidthVp > 0 && this.windowHeightVp > 0;
  }

  /**
   * @returns 起点缩放比例（整页从这么大开始放大，最后到 1）。
   *
   * 用窗口**短边**做分母：迷你条封面在两个方向上占的比例不同，取短边能得到
   * "不会小到看不见、也不至于大到看不出动画"的那一档。
   *
   * ★★ 2026-10-15（**已判定为死代码**，`RzdMusic记忆.md` §59）：零调用者。
   *   它和紧邻的 {@link morphCenterXPercent} / {@link morphCenterYPercent} 是**同一族**：
   *   "整页 `scale` + 绕迷你条中心缩放"那套**早期形变**的残留。活的形变走
   *   `applyMorphProgress()` 的"缩放 + 竖直裁剪窗口"（`morphScale/morphTx/morphTy/morphClipHeight`）
   *   ⇒ 这一族**从来没被接线**（`MORPH_MIN_SCALE` 也只被它读）。
   * @deprecated 零调用者。活的形变起点见 {@link applyMorphProgress} 与 `morphInitParams()`。
   * 复核命令：`grep -rn 'morphStartScale\|morphCenterXPercent\|MORPH_MIN_SCALE' RzdMusic --include=*.ets`
   */
  public morphStartScale(): number {
    if (!this.morphGeometryReady()) {
      return 1;
    }
    const shortSide: number = Math.min(this.windowWidthVp, this.windowHeightVp);
    const raw: number = this.miniSize / shortSide;
    return Math.max(PlayerExpandState.MORPH_MIN_SCALE, Math.min(1, raw));
  }

  /**
   * @returns 缩放锚点 X，**本页坐标系**下的百分比字符串（如 `'12%'`）。
   * @param progress 展开进度 0…1（终点时锚点回到居中，避免静止态偏心）
   * @deprecated 零调用者；与 {@link morphStartScale} 同属"早期绕锚点缩放"那一族残留。
   * 复核命令：`grep -rn 'morphCenterXPercent' RzdMusic --include=*.ets`（期望：只有本处定义）
   */
  public morphCenterXPercent(progress: number): string {
    const target: number = this.windowWidthVp > 0 ? (this.miniX + this.miniSize / 2) / this.windowWidthVp : 0.5;
    const p: number = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
    // 起点用迷你条的位置，终点回到 50%（静止态不偏心）
    const percent: number = (target + (0.5 - target) * p) * 100;
    return percent.toFixed(2) + '%';
  }

  /**
   * @returns 缩放锚点 Y，本页坐标系下的百分比字符串。
   * @param progress 展开进度 0…1
   */
  public morphCenterYPercent(progress: number): string {
    const target: number = this.windowHeightVp > 0
      ? (this.miniY + this.miniSize / 2) / this.windowHeightVp
      : 0.5;
    const p: number = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
    const percent: number = (target + (0.5 - target) * p) * 100;
    return percent.toFixed(2) + '%';
  }

  /**
   * ★★ 2026-10-15（**已判定为死代码**，`RzdMusic记忆.md` §59）：注释里那个 `setDragUpdate`
   * **全仓不存在**（`grep -rn 'setDragUpdate' RzdMusic --include=*.ets` 无命中）⇒ 本字段
   * 既没有写者也没有读者。它属于上一版"把跟手回调塞进共享状态"的尝试，
   * 而活的那条路是**壳层/迷你条各自持手势、直接调 `applyMorphProgress()`**（见下面 §五点五 那段）。
   *
   * @deprecated 零读者零写者。跟手进度请走 {@link applyMorphProgress}。
   * 复核命令：`grep -rn 'dragUpdateToken\|setDragUpdate' RzdMusic --include=*.ets`
   */
  @Trace public dragUpdateToken: number = 0;

  // ═════════════════════════ 五点五、上拉打开（对标无界 ExpandAnimation.applyPullProgress）═════════════════════════
  //
  // 无界那套是**手势驱动**的：`onDown / onMove(205 条) / onUp` 把手指位移映射成一个进度，
  // 松手后按阈值 `doEnter`（完成展开）或 `doBack`（回弹），跟手阶段进度**可以停在中间**。
  // 这里等价实现：壳层（products）负责手势，本类只存进度与相位。
  //
  // ⚠️ 活的入口是 **`pullOpenBegin()`**（起手：量几何 + 压到起点）与
  //    `morphBeginLeaving()` / `applyMorphProgress()` / `morphSettleOpen()`。
  //    下面这三个字段是它们的状态；同段里原来那套 `beginPullOpen/updatePull/endPullOpen/
  //    pullProgressFrom/pullShouldCommit` 已按 D5 删除（零调用点）。

  /**
   * 上拉进度：**0 = 完全展开，100 = 还在迷你条那一小块**（与 `collapseProgress` 同向）。
   *
   * 壳层在跟手时直接改它，播放页把它镜像进自己的 `collapseProgress`，
   * 于是"高度 / 缩放 / 位置 / 圆角 / 透明度"全部跟着手指走。
   */
  @Trace public transitionProgress: number = 0;
  /** 是否正在跟手上拉（拖动期间不跑任何补间，进度完全由手指决定）。 */
  @Trace public pullDragging: boolean = false;
  /**
   * 本次跟手会话的起手时间（ms，`Date.now()`）。
   *
   * 存在的意义：`pullDragging` 一旦残留（某轮手势没走到收尾），点击打开就会**跳过形变
   * 初始化**、退化成老动画。有了起手时间就能判定"这个标记是否已经过期"——
   * 一次跟手不可能持续几秒，超过阈值一定是残留。
   */
  @Trace public pullStartedAtMs: number = 0;

  // ⚠️ **D5：这里原来还有一套「上拉打开」的遗留 API，已删**（2026-10-15 复核，见
  //    `docs\无界形变手感-落实到RzdMusic清单.md` §二 待办第 0 项 / §四 D5）：
  //      `PULL_COMMIT_PROGRESS (=55)` / `pullProgressFrom()` / `pullShouldCommit()` /
  //      `beginPullOpen()` / `updatePull()` / `endPullOpen()`
  //    全仓（`git grep -n … -- "*.ets" "*.ts"`，含 features / common / products）**零调用点**，
  //    只在定义处出现。活的驱动链是 `morphUsable` / `morphBeginLeaving()` / `applyMorphProgress()` /
  //    `morphSettleOpen()` / `morphDrive` / `morphGen` / `morphGenAlive()` / `morphSessionDriving()`。
  //    ⇒ 两套并存会让后来的人改错地方，故一并删除；上面三个**仍在用**的字段
  //    （`transitionProgress` / `pullDragging` / `pullStartedAtMs`）保留。
  //
  // ⚠️ **D5 续查（2026-10-15，同一口径：`git grep -n "<名字>" -- "*.ets"`，
  //    命中全部落在本文件自己的定义/注释里 = 零调用点）**：下面这些 public 成员
  //    **仍是零调用点，但本轮「保留 + 登记」而不是删除**，两条理由：
  //      ① 清单 §三 把其中的**公式**（`pullBottomIn`）列为「已经对了、别动」——
  //         它是与无界对账的参考公式，删掉就没有对照物了（§47.2 当初也是这么定的）；
  //      ② 其余是"整页缩放 / 压扁内容层"那一版（现行第 5 版之前）的旧 API。
  //         统一登记在这里，**后来的人别再照它写** —— D5 要防的就是"改错地方"。
  //      · 圆角 / 封面旧口径：`coverVisualRadius()`、`coverX()`、`coverY()`、
  //        `coverSize()`、`coverRadius()`、`coverOpacity()`
  //      · 封面两档透明度的旧口径：`miniCoverOpacity()`、`innerCoverOpacity()`
  //      · 旧整页透明度 / 裁剪路径：`pageOpacity()`、`clipCommands()`
  //      · 旧相位门：`hasGeometry()`、`armExpand()`、`beginAnimating()`、`finishAnimating()`
  //      · 旧"控制区自动收起"：`chromeShouldAutoHide()`、`collapseChrome()`、
  //        `revealChrome()`、以及**本类**的 `touchChrome()`
  //        （⚠️ `PlaybackPage` 里另有一个**同名的私有方法**，那个是**活的** ——
  //         它挂在 `onTouch` 上重置自动收起计时器，别混）
  //        ★★★ 2026-10-16：**这四个已按本条执行删除**（含 `lastChromeTouchMs` 与
  //        `CHROME_AUTO_HIDE_MS(3000)`）。留下 `revealChrome()` / `touchChrome()` 的**简化版**
  //        （只翻 `chromeCollapsed`，不再记时间戳），因为 `PlaybackPage` 会调它们。
  //        ⚠️ 之所以必须删：那对 3000ms 与活的那条 `PlaybackPage.CHROME_AUTO_HIDE_MS(5000)` 是
  //        **同一个功能的两套值** ⇒ 后来人按 3000 核对会得出"与无界不一致"的错误结论。
  //      · 旧淡入淡出：实例方法 `metaOpacity()`（⚠️ 与此同名的
  //        `miniBarMetaOpacity()` 是**活的**，别混）、`pullBottomIn()`
  //    ⚠️ **两个"有调用点但等于常量"的别误判**：`chromeOpacity()` / `chromeOffsetY()`
  //      确实被 `PlaybackPage` 的控制区读到，但**写入方**（上面那组 `chrome*`）零调用点
  //      ⇒ 它们恒为 1 / 0，读到不产生任何效果（§47.4 / §48.6 记的就是这件事）。

  // ═════════════════════════ 五点六、裁剪容器形变（对标无界 ExpandAnimation.applyPullProgress）═════════════════════════
  //
  // 这是无界那套的核心手法，也是我前面几版**没做到位**的根本原因：
  //
  //   它不用「逐元素算坐标」，而是——
  //     1. 把整个播放页当成**一个大容器**，按 `initScale` 缩小、平移到迷你条位置；
  //     2. 同时用一个**竖直裁剪窗口**只露出上面一小截（`clipHeight`），
  //        那一截正好落在迷你条封面上。
  //   3. progress 推进时：容器放大回 1、位移回 0、裁剪窗口长到满屏、圆角从 16 到 0。
  //
  // 于是"播放器从迷你条那一小块逐渐长满全屏"是**一个缩放 + 一层裁剪**的结果，
  // 不需要给每个子元素单独算起止点，也不会因为子元素布局差异而错位。
  //
  // 反编译出的公式（`applyPullProgress`，progress 0…1）：
  //   scale      = initScale + (1 - initScale) * p
  //   translateX = initTranslateX * (1 - p)
  //   translateY = initTranslateY * (1 - p)
  //   clipHeight = initClipHeight + (fullClipHeight - initClipHeight) * p
  //   radius     = (initClipHeight*initScale/2 + (半径增量)*p) / scale   ← 注意除以 scale
  //
  // 以及 `initParams` 的推导（全是**实测**，见 reportMini / reportWindow）：
  //   initScale      = 迷你条封面宽 / 窗口宽
  //   initClipHeight = px2vp(迷你条封面高 / initScale)
  //   initTranslateX = px2vp(capsuleLeft - (窗口宽 - 封面宽) / 2)
  //   initTranslateY = px2vp(capsuleTop - (封面高 - 封面高*initScale) / 2)

  // ═════════════════ 形变窗口（起点 = 迷你条那条胶囊，终点 = 整屏）═════════════════
  //
  // 模型（这是第四版，前三版的教训写在文件末尾）：
  //
  //   1. **窗口**：一个贴底的容器，尺寸从"迷你条那条胶囊"长到"整屏"，圆角从胶囊圆角收到 0。
  //      它**永远底边对齐**，所以屏幕底部不可能出现空档 —— 这是"底部空白"的结构性解法
  //      （之前靠算位移去补，总是差着迷你条离底边那几十 vp）。
  //   2. **内容层**：尺寸恒为 `宿主尺寸`（从不随窗口变化 → **全程零重排**），按
  //      `min(窗口宽/宿主宽, 窗口高/宿主高)` 等比缩放后居中。窗口早期又宽又扁，
  //      此时内容层完全透明（见 `MORPH_CONTENT_FADE_FROM_SCALE`），等页面够大了才浮现。
  //   3. **桥接封面**：一张脱离布局的封面，从迷你条封面矩形走到播放页封面矩形，
  //      **p = 1 时才落位**；播放页自己那张封面在形变期间不画（否则会出现两张封面）。
  //
  // 全部状态都是**基础类型**的 `@Trace` 字段：跟手时每一帧都要重绘，
  // 对象字段（`@Trace morph: SomeInterface`）在某些版本上不会触发刷新，踩过。

  /** Source stays mounted for measurement; only paint ownership changes. */
  @Trace public sourceBarHidden: boolean = false;
  @Trace public metaBridgeActive: boolean = false;
  @Trace public metaBridgeGeneration: number = 0;
  private sourceTitle: MorphMetaEndpoint | undefined = undefined;
  private sourceSinger: MorphMetaEndpoint | undefined = undefined;
  private floatingTitle: MorphMetaEndpoint | undefined = undefined;
  private floatingSinger: MorphMetaEndpoint | undefined = undefined;
  private metaSourceFloating: boolean = false;
  private targetTitle: MorphMetaEndpoint | undefined = undefined;
  private targetSinger: MorphMetaEndpoint | undefined = undefined;
  public metaStartTitle: MorphMetaEndpoint = new MorphMetaEndpoint();
  public metaStartSinger: MorphMetaEndpoint = new MorphMetaEndpoint();
  public metaEndTitle: MorphMetaEndpoint = new MorphMetaEndpoint();
  public metaEndSinger: MorphMetaEndpoint = new MorphMetaEndpoint();

  public registerMorphMeta(source: boolean, singer: boolean, endpoint: MorphMetaEndpoint,
    floating: boolean = false): void {
    if (source && floating) {
      if (singer) {
        this.floatingSinger = endpoint;
      } else {
        this.floatingTitle = endpoint;
      }
    } else if (source) {
      if (singer) {
        this.sourceSinger = endpoint;
      } else {
        this.sourceTitle = endpoint;
      }
    } else if (singer) {
      this.targetSinger = endpoint;
    } else {
      this.targetTitle = endpoint;
    }
  }

  public invalidateMorphMetaTarget(title: TextController, singer: TextController): void {
    // A disappearing old subtree must not unregister the replacement Text endpoints.
    if (this.targetTitle?.controller === title) {
      this.targetTitle = undefined;
    }
    if (this.targetSinger?.controller === singer) {
      this.targetSinger = undefined;
    }
    this.logMorphOwnership('target-subtree-disappear');
  }

  public cancelMetaForTrackChange(): void {
    if (!this.metaBridgeActive) {
      return;
    }
    // Preserve container/lyric animation; only the stale frozen text relinquishes ownership.
    this.metaBridgeActive = false;
    Logger.info('RzdMetaMorph', `track changed: release stale text gen=${this.morphGen}`);
  }

  /** Freeze both real Text nodes before any container transform or ownership change. */
  public freezeMorphMeta(ui: UIContext): boolean {
    if (this.metaBridgeActive) {
      return true;
    }
    // Never replace frozen endpoints using a partially translated/scaled live frame.
    if (this.morphStage === MorphStage.LEAVING ||
      (this.morphLive() && this.morphDrive === MorphDrive.ANIM)) {
      return false;
    }
    const st = (this.metaSourceFloating ? this.floatingTitle : this.sourceTitle)?.measure(ui);
    const ss = (this.metaSourceFloating ? this.floatingSinger : this.sourceSinger)?.measure(ui);
    const et = this.targetTitle?.measure(ui, true);
    const es = this.targetSinger?.measure(ui, true);
    if (st === undefined || ss === undefined || et === undefined || es === undefined ||
      st.content !== et.content || ss.content !== es.content) {
      Logger.info('RzdMetaMorph', `pending real endpoints gen=${this.morphGen}`);
      return false;
    }
    this.metaStartTitle = st;
    this.metaStartSinger = ss;
    this.metaEndTitle = et;
    this.metaEndSinger = es;
    this.metaBridgeGeneration = this.morphGen;
    this.metaBridgeActive = true;
    this.sourceBarHidden = true;
    this.logMorphOwnership('freeze-natural-endpoints');
    Logger.info('RzdMorphOwnership', `acquire gen=${this.morphGen} sourceHidden=1 targetHidden=1`);
    Logger.info('RzdMetaMorph', `endpointdimensions gen=${this.morphGen} trueendnatural=1 ` +
      `title=${et.width}x${et.height} endbaseline=${et.baselineVp} endWindowBaseline=${et.y + et.baselineVp} ` +
      `singer=${es.width}x${es.height} endbaseline=${es.baselineVp} endWindowBaseline=${es.y + es.baselineVp} ` +
      `targetLineHeightFp=${et.lineHeightFp},${es.lineHeightFp} baselineSpace=paragraph-local`);
    Logger.info('RzdMetaMorph', `freeze gen=${this.morphGen} title=(${st.x},${st.y},${st.width},${st.height},${st.fontFp}fp,b=${st.baselineVp})->(${et.x},${et.y},${et.width},${et.height},${et.fontFp}fp,b=${et.baselineVp}) singer=(${ss.x},${ss.y},${ss.width},${ss.height},${ss.fontFp}fp,b=${ss.baselineVp})->(${es.x},${es.y},${es.width},${es.height},${es.fontFp}fp,b=${es.baselineVp})`);
    return true;
  }

  public morphMetaFrame(singer: boolean): MorphMetaFrame {
    const start = singer ? this.metaStartSinger : this.metaStartTitle;
    const end = singer ? this.metaEndSinger : this.metaEndTitle;
    const p = this.morphP;
    const frame = new MorphMetaFrame();
    frame.x = start.x + (end.x - start.x) * p;
    frame.y = start.y + (end.y - start.y) * p;
    frame.width = start.width + (end.width - start.width) * p;
    frame.height = start.height + (end.height - start.height) * p;
    // Keep target typography/layout fixed; only paint scale interpolates with cover P.
    // This avoids per-frame font reflow and guarantees the genuine p=1 text endpoint.
    frame.fontFp = end.fontFp;
    // Interpolate start/end ratio, not resolved Resource px. At p=1 scale is exactly 1.
    frame.scale = end.fontFp > 0 ? start.fontFp / end.fontFp +
      (1 - start.fontFp / end.fontFp) * p : 1;
    // Clone keeps the real target's default line-height policy; do not synthesize it
    // from glyph metrics. Full target layout space is independent of the paint frame.
    frame.baselineVp = start.baselineVp + (end.baselineVp - start.baselineVp) * p;
    frame.opacity = start.opacity + (end.opacity - start.opacity) * p;
    return frame;
  }

  private logMetaFont(singer: boolean, event: string): void {
    const declared = singer ? this.targetSinger : this.targetTitle;
    const end = singer ? this.metaEndSinger : this.metaEndTitle;
    const frame = this.morphMetaFrame(singer);
    const renderRatio = declared !== undefined && declared.fontFp > 0 ?
      frame.fontFp * frame.scale / declared.fontFp : 0;
    Logger.info('RzdMetaFont', `event=${event} gen=${this.morphGen} singer=${singer} ` +
      `p=${this.morphP} declaredFp=${declared?.fontFp ?? 0} endFp=${end.fontFp} ` +
      `bridgefontFp=${frame.fontFp} paintScale=${frame.scale} renderRatio=${renderRatio} ` +
      `fontScaleAppliedByTextOnly=1`);
  }

  /**
   * @returns **壳层歌名克隆层**（`MorphMetaBridge`）现在要不要接管绘制。
   *
   * ★★★ 2026-10-16（用户实测：「**那个歌曲名和歌手名现在怎么还是之前的一镜到底的飞入，
   *   改成无界一样的**」）⇒ **本方法改成恒 `false`**。
   *
   * ## 为什么原来那套是"一镜到底的飞入"（而它不是无界的做法）
   *
   * 原来 `metaBridgeOwnsPaint()` 为真时：
   * ```
   *   · 壳层 MorphMetaBridge 在【窗口坐标】画一份歌名/歌手克隆，
   *     用 morphMetaFrame() 的 x/y + 字号×scale 从"迷你条那一行"一路插值飞到"落点那一行"；
   *   · 播放页自己那一行同时被 targetMetaOpacity() 压成 0（交棒）。
   * ```
   * ⇒ 观感就是**一个歌名从迷你条位置长途飞到落点**（用户说的"一镜到底的飞入"）。
   *
   * ## 无界那边是什么样
   *
   * `floatingMeta` 里**只有一行** `metaRow`（`PlayerPage完整UI定稿.md` §6.1/§6.2）：
   * ```
   *   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)   // 位移插值
   *   字号 = lerp(chrome().titleSize × sizeK, 15 × sizeK, metaProgress)          // 字号插值
   *   opacity = pullChromeOpacity = clamp((t − 0.18) / 0.44)                     // 0.18→0.62 淡入
   * ```
   * ⇒ **没有第二个元素在飞**：那一行就是"原地淡入 + 跟着形变进度微调位置"。
   *
   * ## 所以本处怎么改
   *
   * 恒返回 `false` ⇒ 克隆层**不再画**，绘制权一直留在**播放页自己那一行**（`targetMetaOpacity()`
   * 随之恒走 `pullChromeOpacity()` 分支）。那一行现在的动画是：
   * ```
   *   · 不透明度 = pullChromeOpacity = clamp((p − 0.18) / 0.44)   ← 与无界同一个窗口
   *   · 位移     = metaRiseVp() = (1 − ramp01(p, 0.18, 0.62)) × 180vp / scale
   *                ← 从下升起 180vp（用户 10-15 定调「不要淡入淡出，用位移出场」）
   * ```
   * ⇒ 与无界同构：**一行、原地、淡入 + 升起**，没有长途飞行。
   *
   * ⚠️ 关闭它的**代价**（如实登记）：形变期间那一行在**被缩放的容器里**，字会被一起缩小。
   *   在早期（p < 0.4）它很小，但因为 `pullChromeOpacity` 在 p = 0.18 才起步、0.62 才满，
   *   观感是"随着页面长大而淡入" —— 与无界的"跟着形变进度淡入"同族。
   *   ⚠️ 若真机上显得"字一开始太小"，那说明该把这一行**也搬到形变容器之外**
   *   （= 无界 `floatingMeta` 的位置：与 `playerPane` 同级），那是一次独立的结构改动。
   */
  public metaBridgeOwnsPaint(): boolean {
    return false;
  }

  public targetMetaOpacity(): number {
    // Stable OPEN is unconditional TARGET ownership, even after a stale callback.
    if (this.morphStage === MorphStage.OPEN) {
      return 1;
    }
    // ★★ 2026-10-15 **恢复原样**：用户明确「歌曲名和歌手咋还中间消失了，**还用原来的飞入动画不用改**」——
    //   我上一版把这一行改成"0.18→0.34 淡入的纯函数"，它与克隆层的淡出交叉时，
    //   播放页自己那一行还被压在缩小布局里（屏幕上看不见）⇒ 观感就是"飞入到一半突然没了"。
    //   原来的写法是"克隆层接管期间这一行为 0，交回给播放页时才显示" —— 保持不动。
    return this.metaBridgeOwnsPaint() ? 0 : this.pullChromeOpacity();
  }

  public logMorphOwnership(event: string): void {
    Logger.info('RzdMorphOwnership', JSON.stringify({ event: event, gen: this.morphGen,
      metaGen: this.metaBridgeGeneration, stage: this.morphStage, drive: this.morphDrive,
      p: this.morphP, driving: this.morphSessionDriving(), metaActive: this.metaBridgeActive,
      bridgePaint: this.metaBridgeOwnsPaint(), sourceHidden: this.sourceBarHidden,
      targetOpacity: this.targetMetaOpacity(), contentOpacity: this.morphContentOpacity }));
  }

  private releaseMorphOwnership(toMini: boolean): void {
    this.metaBridgeActive = false;
    this.sourceBarHidden = !toMini;
    Logger.info('RzdMorphOwnership', `release gen=${this.morphGen} toMini=${toMini} sourceHidden=${this.sourceBarHidden}`);
  }

  /** 形变阶段。 */
  @Trace public morphStage: MorphStage = MorphStage.NONE;
  /** 形变驱动者（手指 / 动画）。 */
  @Trace public morphDrive: MorphDrive = MorphDrive.NONE;
  /** 跟手进度 0…1（0 = 还是迷你条那条胶囊）。 */
  @Trace public morphP: number = 1;
  /**
   * 形变**世代号**（对标反编译里的 `animGen`）。
   *
   * 每次进入/离开形变都 +1；所有延时回调（补间收尾、卸载、LANDING）都要先比对它，
   * 不相等就丢弃。反编译那边专门强调了这条："快速连续切换（连续点开/收起）时，
   * 旧动画的回调不会污染新状态，不带这个机制快速拖动会状态错乱"。
   */
  @Trace public morphGen: number = 0;

  /** 形变窗口（= 整页缩放后的可视矩形）的缩放。 */
  @Trace public morphScale: number = 1;
  /** 形变容器的位移 x（vp）：让"可视左上角"落在算出来的位置上。 */
  @Trace public morphTx: number = 0;
  /** 形变容器的位移 y（vp）。 */
  @Trace public morphTy: number = 0;
  /** 形变容器的裁剪高度（vp，布局单位）：可视高度 / 缩放。 */
  @Trace public morphClipHeight: number = 0;
  /** 形变容器圆角（vp，布局单位）：**已经除以缩放**，屏上的可视圆角才是设计值。 */
  @Trace public morphRadius: number = 0;
  /** 内容层不透明度（可视矩形接近整屏才浮现）。 */
  @Trace public morphContentOpacity: number = 1;

  /**
   * **壳层浮层拷贝**的独立进度 0…1（只有浮层那一份封面克隆吃它）。
   *
   * 为什么要与 `morphP` 分开：对标无界的**两层结构** —— 播放页内快照 350ms、
   * 浮层拷贝 560ms 且曲线不同（快出慢收）。两者同起、各自到点。
   * **播放页的几何仍然只由 `morphP` 驱动**，本字段不参与任何页内摆放。
   *
   * 写入点（只有这三个，别再加）：
   *   ① 手指跟手：`syncMorphOverlayFromPage()`（与 `morphP` 一比一同步，不跑补间）；
   *   ② 补间：`morphOverlayTweenTo()`（唯一一处 animateTo，560ms + 快出慢收）；
   *   ③ 复位：`morphOverlayReset()`（`morphReset` / 会话开始）。
   */
  @Trace public morphOverlayP: number = 1;
  /** 浮层拷贝补间的世代号（新补间/复位后旧回调直接丢弃）。 */
  private morphOverlayGen: number = 0;
  /** 浮层拷贝此刻是否有补间在跑（防止同一段动画被重复起一遍）。 */
  private morphOverlayAnimating: boolean = false;
  /**
   * 本轮收起是不是**已经有人**把浮层那一棒起过了（唯一清零点 = {@link morphOverlayReset}）。
   * 见 `focusMorphOverlayForPageCollapse()` 里的幂等护栏说明。
   */
  private morphOverlayCollapseOwned: boolean = false;

  /** @returns 浮层拷贝的补间是否正在跑（只读，给播放页的日志与护栏用）。 */
  public overlayTweenAnimating(): boolean {
    return this.morphOverlayAnimating;
  }
  /** `hostsMorphOverlay()` 的缓存：-1 = 还没判过，0 = 否，1 = 是（见该函数的说明）。 */
  private morphOverlayHostCached: number = -1;

  /**
   * 形变几何是否可用（`morphInitParams()` 的结论）。
   *
   * ⚠️ 必须显式记下来：几何没齐时沿用默认值会把播放页弄成一条细缝
   *    —— 那就是"上拉打开播放器，屏幕上看不到东西"。
   */
  @Trace public morphUsable: boolean = false;
  /**
   * ★★★ 2026-10-16（**照搬无界 `PlayerPage.__pullGeomReady`**）：
   * 本轮形变的**终点几何**是否已经量到（= 可以按公式给容器落非恒等的 `scale/translate/clip`）。
   *
   * ## 为什么必须有这一条（它是「点击打开 / 点击关闭 / 系统返回 没有动画」的最后一把锁）
   *
   * 无界侧（`wujie.pa` 原文，逐条对应）：
   * ```
   *   PlayerPage.__pullGeomReady                          // 168236（初值 false）
   *   ExpandAnimation.applyPullProgress:                  // 50930-50946
   *       if (!pullReady) { this.initParams(ui); pullReady = true; }   // ← 只有这一种进法
   *       ...scale/translate/clip 的插值...
   *   PlayerPage.publishMorphTargets:                     // 175872-176232
   *       if (swiperProgress > 0.02) return;               // 只有**封面页**才上报
   *       if (!isMorphTarget()) return;
   *       ...量 playerCoverRect / playerMetaRect，越界或量不到 → schedulePublishRetry()...
   *       ExpandSnapshot.playerCoverRect = cover; playerMetaRect = meta;
   *       if (!pullMode) {                                 // 点击打开：pullMode === false
   *         if (!pullGeomReady) { pullGeomReady = true;    // ← 置位
   *                               expand.applyPullProgress(ui, pullT); } }
   *   PlayerPage.onPullTChanged:                          // 174826-174850
   *       if (!pullMode) return;
   *       if (!pullGeomReady) return;                      // ← **几何没齐就不落属性**
   *       expand.applyPullProgress(ui, effT());
   * ```
   * 三条都在说同一件事：**`applyPullProgress` 只在终点几何量到之后才允许改容器几何**。
   *
   * 我们这边的断点（本轮读出来的）：`applyMorphProgress()` 在 `!morphUsable` 时
   * **把容器写回恒等**（`PlaybackPage:morphClipping()` 随之为假 ⇒ 高度 `'100%'`、
   * 不裁剪），而点击/返回这条路上「播放页那一刻还没挂载」⇒ `pullOpenBegin` 里
   * `prepareMorphEntry` 的终点锚点必然量不到 ⇒ `morphUsable === false`
   * ⇒ 容器**整段停在恒等** ⇒ 用户看到的正是「没有封面/背景动画」。
   * 跟手那条路之所以好，是因为上拉时播放页已经挂载、第一拍就量到了。
   *
   * ⇒ 修法 = 把「几何没齐」的语义从"写回恒等"改成**无界那样的"什么都不做"**：
   *   容器保持当前值（初次 = 恒等，与"没有这套动画"逐像素一致），
   *   等终点锚点补量成功那一帧再第一次落非恒等几何。
   */
  @Trace public morphGeomReady: boolean = false;
  /** 形变用的宿主尺寸（vp）：内容层的固定尺寸，也是"铺满"的目标。 */
  private morphBoxW: number = 0;
  private morphBoxH: number = 0;
  /**
   * `initParams` 算出来的三个 lerp 起点（**逐条对应**反编译的字段名）。
   * `applyPullProgress` 只在这些值与 `t` 上做线性插值，所以它们是形变的全部输入。
   */
  private initScale: number = 1;
  private initClipHeight: number = 0;
  private initTranslateX: number = 0;
  private initTranslateY: number = 0;
  /** 起点的**可视**圆角 = `initClipHeight * initScale / 2`（= 胶囊高度的一半）。 */
  private initRadiusVisual: number = 0;
  /** 迷你条胶囊的原始上报值（vp，**窗口坐标**；宽高为 0 表示没量到）。 */
  @Trace public barWinX: number = 0;
  @Trace public barWinY: number = 0;
  @Trace public barWinW: number = 0;
  @Trace public barWinH: number = 0;
  @Trace public barWinRadius: number = 0;
  /** 起点：迷你条那条胶囊的矩形（vp，**宿主坐标**，由 `morphInitParams` 换算）。 */
  private barX: number = 0;
  private barY: number = 0;
  private barW: number = 0;
  private barH: number = 0;
  private barRadius: number = 12;
  /** 起点：迷你条封面矩形（vp，宿主坐标）—— 桥接封面的起点。 */
  private miniCoverX: number = 0;
  private miniCoverY: number = 0;
  private miniCoverSize: number = 0;
  private miniCoverRadius: number = 12;

  // ───────────── 续飞封面（反编译侧的 `snap*` 一整套端点）─────────────
  //
  // `initParams` 里另有一对端点（`snapStart*` / `snapEnd*`）：
  //   · 起点 = 迷你条封面（`srcRect`：left/top/width → px2vp）
  //   · 终点 = 播放页封面的 FrameNode：`getPositionToWindowWithTransform()`（vp）
  //            + `getMeasuredSize().width`（px → px2vp）
  // 展开过程中屏上"封面"这一棒就是它，**线性**从起点插到终点（`doEnter` 里直接
  // animateTo 这两个字段；拖动路径由 `applyPullProgress` 之外的地方驱动）。
  /** 续飞封面起点（vp，宿主坐标）与起点圆角（反编译侧的 `snapStart*`）。 */
  private snapStartX: number = 0;
  private snapStartY: number = 0;
  private snapStartW: number = 0;
  private snapStartRadius: number = 12;
  /**
   * 播放页封面**节点**的窗口矩形（vp）：反编译侧 `initParams` 用
   * `getFrameNodeById(targetId).getPositionToWindowWithTransform()` + `getMeasuredSize()`
   * 量它当续飞封面的终点。`snapEnd*` 优先用它，量不到才退回 `onAreaChange` 的 `big*`。
   */
  private bigNodeX: number = 0;
  private bigNodeY: number = 0;
  private bigNodeW: number = 0;
  /**
   * 播放页封面节点的**实际高度**（vp）。
   *
   * ⚠️ 不能再假设"封面是正方形"（`h = w`）：封面外面套着 `constraintSize(maxWidth/maxHeight 100%)`
   *    + `layoutWeight(1)` 的容器，实际量到的矩形不保证 1:1。桥接封面按 `h = w` 落位，
   *    真实封面按布局落位 —— 两者差多少，p=1 交棒那一刻就"跳"多少（用户实测的
   *    「结束时封面位置/大小跳一下」）。
   */
  private bigNodeH: number = 0;
  /**
   * 播放页封面当前的**视觉缩放**（`MusicPlayInfoBlock` 的播放态弹簧：播放 1.05 / 暂停 0.95）。
   *
   * ⚠️ `getPositionToWindowWithTransform()` 量到的是**含该 transform** 的矩形。如果只把它当
   *    "布局矩形 × 1.0"存下来，p=1 交棒给真实封面（真实封面是 1.05）就会跳 5%。
   *    所以量测时先把 transform 除掉存"布局矩形"，绘制桥接封面时再把当前缩放乘回去 ——
   *    两端用的都是**实时值**，弹簧正在动的时候也跟着动。
   */
  private bigNodeScaleX: number = 1;
  private bigNodeScaleY: number = 1;
  private bigNodeKnown: boolean = false;
  /** 播放页封面圆角（vp，来自 `reportBig`）。 */
  private bigCoverRadius: number = 0;
  /**
   * 迷你条"元信息 + 操作区"那一块的窗口矩形（vp）——克隆层的宿主矩形。
   * 反编译侧对应 `miniMeta` + `morphActionsRect` 的来源。
   */
  @Trace public asideWinX: number = 0;
  @Trace public asideWinY: number = 0;
  @Trace public asideWinW: number = 0;
  @Trace public asideWinH: number = 0;
  /** 续飞封面的**终点**（vp，宿主坐标）：播放页封面节点量到的矩形，量不到就退回 `big*`。 */
  private endCoverX: number = 0;
  private endCoverY: number = 0;
  private endCoverSize: number = 0;
  /** 续飞封面终点的**高度**（vp）：与 `endCoverSize` 一起构成落点矩形，非正方形时不能再当方的。 */
  private endCoverH: number = 0;

  /**
   * ★★★ 2026-10-16 新增：给**现场自证徽标**（`PlaybackPage.DiagBadge()`）用的只读读数。
   *
   * 为什么走方法而不是把字段改 public：本仓既有的做法就是"私有字段 + 公开只读入口"
   * （同 `morphContainerActive()` / `morphClipping()` 那一族，见 §59 的清理记录）。
   * ⚠️ 纯只读：这些方法**不写任何状态**，不要在里面加副作用。
   * @returns 续飞封面**起点宽度**（vp，迷你条封面）
   */
  public snapStartWVp(): number {
    return this.snapStartW;
  }

  /** @returns 续飞封面**终点宽度**（vp，播放页封面）—— 为 0 表示终点锚点没量到。 */
  public endCoverSizeVp(): number {
    return this.endCoverSize;
  }

  /** @returns 续飞封面**终点高度**（vp）—— 非正方形封面不能当方的用。 */
  public endCoverHVp(): number {
    return this.endCoverH;
  }

  /** @returns 当前档位的 `bottomGap`（vp）—— 给自证徽标核"底部让位下限"用。 */
  public chromeBottomGapVp(): number {
    return this.chromeOf().bottomGap;
  }

  // ═══════════ ★★★ 现场自证：**动作轨迹**（不依赖 hdc 也能看出"谁先谁后"）═══════════
  //
  // ## 为什么需要它
  //
  // 「点击打开 / 点击关闭 / 系统返回没有动画」这条链上，**顺序**本身就是自变量的最大值：
  // 同一个函数先调还是后调，结果完全不同（§93 的 `onAppear` 误判、§103 的 `onDisappear`
  // 误杀，都是"顺序"问题）。而徽标原来只显示**当前值**，看不出**顺序**。
  //
  // ⇒ 在共享状态上留一条**最近 6 个动作**的轨迹，壳层与播放页两边都往里写，
  //   徽标直接显示 ⇒ 一次就能看出"谁先谁后、谁没来"。
  //
  // ⚠️ **绝不影响行为**：只在 `pushMorphTrace()` 里拼字符串；不参与任何判断。
  // ⚠️ 上限 6 段（每段最多十几字符）⇒ 字符串长度可控。
  @Trace public morphTrace: string = '';

  /**
   * 记录一个形变动作（只给自证徽标用）。
   * @param tag 短标签（**保持 6 字符以内**，便于一眼扫过）
   */
  public pushMorphTrace(tag: string): void {
    const parts: string[] = this.morphTrace.length > 0 ? this.morphTrace.split('>') : [];
    parts.push(tag);
    while (parts.length > 6) {
      parts.shift();
    }
    this.morphTrace = parts.join('>');
  }

  /**
   * 清空轨迹（在一次**新的打开动作开始**时调，避免与上一次的轨迹混在一起）。
   * ⚠️ 只在"用户发起了新的打开/关闭"这类**会话边界**上调，不要在渲染路径上调。
   */
  public resetMorphTrace(tag: string): void {
    this.morphTrace = tag;
  }

  /**
   * 记录迷你条那条**胶囊**的窗口矩形。
   *
   * 用**实测**（`measureMini`，走 `getRectangleById`）而不是 `onAreaChange` 的
   * `globalPosition`：后者给的是**布局**位置，HDS 浮动底栏如果对胶囊做过平移/偏置，
   * 量出来的起点就会整体偏（用户实测到的"从封面偏左下角开始"就是这个）。
   * @param x 左边界（vp，窗口坐标）
   * @param y 上边界（vp，窗口坐标）
   * @param w 宽度（vp）
   * @param h 高度（vp）
   * @param radius 圆角（vp）
   */
  public reportMiniBar(x: number, y: number, w: number, h: number, radius: number): void {
    if (w <= 0 || h <= 0) {
      return;
    }
    this.barWinX = x;
    this.barWinY = y;
    this.barWinW = w;
    this.barWinH = h;
    this.barWinRadius = radius > 0 ? radius : h / 2;
  }

  /**
   * 用 `getRectangleById` 量一次迷你条（胶囊 + 封面）与宿主，换成 vp 存起来。
   *
   * 为什么不用 `onAreaChange`：它给的是布局几何，**不含祖先的 transform**；而 HDS 浮动
   * 底栏的胶囊位置/圆角不是我们能完全掌握的，量错一点整段动画的起点就偏。
   * `getRectangleById` 给的是**渲染后**的窗口矩形（口径 px），换算成 vp 就是所见即所得。
   * @param ui UIContext（取自触发动画的那一层）
   * @param preferFloating true = 优先量二级页面那条悬浮迷你条（它只在二级页面才存在，
   *                       所以"优先 + 找不到就退回"这一条规则在两种页面上都成立）
   * @returns 是否量到了迷你条（没量到就退回 `onAreaChange` 的值）
   */
  public measureGeometry(ui: UIContext, preferFloating: boolean, force: boolean = false): boolean {
    let ok: boolean = false;
    // ⚠️ 宿主只用来**核对**（日志里打出来），尺寸的唯一权威是 `reportWindow`（窗口尺寸）。
    //    踩过的坑：在形变中的宿主节点上量尺寸喂回去 = 让"铺满目标"追着自己的中间态跑
    //    （裁剪窗口高度 → 目标高度，越跑越短，屏上就是"一块黑底、播放页展不开"）。
    // 迷你条胶囊（优先那条按参数决定，找不到就换另一条）
    const barIds: string[] = preferFloating ? [MINI_BAR_FLOATING_ID, MINI_BAR_ID] : [MINI_BAR_ID, MINI_BAR_FLOATING_ID];
    for (const id of barIds) {
      const bar: NodeRect | undefined = this.measureNode(ui, id);
      if (bar !== undefined) {
        this.metaSourceFloating = id === MINI_BAR_FLOATING_ID;
        this.reportMiniBar(bar.x, bar.y, bar.w, bar.h, bar.h / 2);
        ok = true;
        break;
      }
    }
    // 迷你条封面（与胶囊同一套优先顺序）
    const coverIds: string[] = preferFloating ?
      [MINI_BAR_COVER_FLOATING_ID, MINI_BAR_COVER_ID] : [MINI_BAR_COVER_ID, MINI_BAR_COVER_FLOATING_ID];
    for (const id of coverIds) {
      const cover: NodeRect | undefined = this.measureNode(ui, id);
      if (cover !== undefined) {
        this.reportMini(cover.x, cover.y, cover.w, cover.w / 2);
        ok = true;
        break;
      }
    }
    // 迷你条"元信息 + 操作区"那一块（克隆层要用它的矩形）
    // ⚠️ 每轮起手都**重量一次**：这个宽度是 HDS 浮动底栏按排布算出来的，
    //    收起/换手/断点变化都会变；用上一轮的冻结宽度会让克隆层相对真身横向偏移。
    const asideIds: string[] = preferFloating ?
      [MINI_BAR_ASIDE_FLOATING_ID, MINI_BAR_ASIDE_ID] : [MINI_BAR_ASIDE_ID, MINI_BAR_ASIDE_FLOATING_ID];
    for (const id of asideIds) {
      const aside: NodeRect | undefined = this.measureNode(ui, id);
      if (aside !== undefined) {
        this.asideWinX = aside.x;
        this.asideWinY = aside.y;
        this.asideWinW = aside.w;
        this.asideWinH = aside.h;
        break;
      }
    }
    // 播放页封面**节点**（续飞封面的终点）
    // ⚠️ **默认只在"没在形变中"时才量**：形变期间播放页是被缩放/裁剪的，量到的是
    //    "被压扁的那一帧"（可能只有几十 vp），写进终点就会"大小不变只移动位置"。
    //    `force = true` 是给**点击展开的重试窗口**用的：那时 `morphStage` 虽然已是 ENTERING，
    //    但页面还没被压到起点（`applyMorphProgress(0)` 只写状态，裁剪窗口要下一帧才生效），
    //    此刻量到的仍是原尺寸 —— 这正是无界"先量后缩"要的那个值。
    //    上一版没有这个入口，重试期永远补不到终点 ⇒ 点击路径必然退化成无动画落位。
    if (force || !this.morphLive()) {
      this.measureEndAnchor(ui);
    }
    // Measurement never acquires paint ownership. OPEN must remain TARGET-owned.
    // Closing explicitly freezes while OPEN, before beginLeaving changes any transform.
    // 宿主矩形只进日志。
    // ★★ 2026-10-15 订正（**原先这里写的是"`MORPH_HOST_ID` 在手机壳里就是播放页自己的根 Stack"，
    //    那句是错的，而且它误导过一轮改动** —— 见下）：
    //   `.id(MORPH_HOST_ID)` 的实际绑定点**只有两个，都在 products 壳层的根 Stack 上**
    //   （`products/default/.../Index.ets:1796`、`products/pc/.../Index.ets:345`），
    //   两者都**常驻**；而手机路由模式下播放页是壳层里 `HdsNavigation` 的**子节点**
    //   ⇒ 量到的是**壳层那一层**（满屏），**不是**播放页那个裁剪窗口。
    // ⇒ 所以这里量到的 `hostNode=` 是"壳层满屏盒"：**它仍然绝不能当铺满目标**
    //   （手机侧铺满目标走 `reportWindow()`，见 `contentWidthVp/HeightVp` 那段），
    //   但"它的高度就是裁剪窗口高度"这个理由**不成立**（真正的原因是别拿任何**参与形变**的层当目标）。
    // ⚠️ **不要在播放页那一层再补 `.id(MORPH_HOST_ID)`** —— 那会造出"同 id 两份节点"，
    //   而本仓对这件事有明确记录（`MINI_BAR_ID` 那两处注释："量到哪一份不确定，起点就抖"）。
    const host: NodeRect | undefined = this.measureNode(ui, MORPH_HOST_ID);
    const hostText: string = host !== undefined
      ? `${host.w.toFixed(1)}x${host.h.toFixed(1)}@(${host.x.toFixed(1)},${host.y.toFixed(1)})`
      : 'none';
    Logger.info(PlayerExpandState.logTag,
      `measure floating=${preferFloating} force=${force} ok=${ok} bar=(${this.barWinX.toFixed(1)},` +
      `${this.barWinY.toFixed(1)},${this.barWinW.toFixed(1)}x${this.barWinH.toFixed(1)}) cover=(${this.miniX.toFixed(1)},` +
      `${this.miniY.toFixed(1)},${this.miniSize.toFixed(1)}) bigNode=(${this.bigNodeX.toFixed(1)},` +
      `${this.bigNodeY.toFixed(1)},${this.bigNodeW.toFixed(1)}x${this.bigNodeH.toFixed(1)},` +
      `s=${this.bigNodeScaleX.toFixed(3)},known=${this.bigNodeKnown}) bigFallback=${this.bigSize.toFixed(1)} ` +
      `aside=(${this.asideWinX.toFixed(1)},${this.asideWinY.toFixed(1)},` +
      `${this.asideWinW.toFixed(1)}x${this.asideWinH.toFixed(1)}) hostNode=${hostText} ` +
      `box=${this.morphBoxWidth().toFixed(1)}x${this.morphBoxHeight().toFixed(1)}`);
    return ok;
  }

  /**
   * 播放页封面当前的**视觉缩放**（`MusicPlayInfoBlock` 的播放态弹簧：播放 1.05 / 暂停 0.95）。
   *
   * 由 `MusicPlayInfoBlock` 写进来（与封面同源，改一处两边都变）；没写进来时按 1 处理
   * —— 那样最差只是落位时差弹簧那 5%，不会把端点算飞。
   *
   * ⚠️ 必须是 `@Trace`：弹簧在动画期间还在动，桥接封面的终点要跟着它逐帧走，
   *    否则 p=1 交棒给真实封面的那一刻就会跳一下（用户实测"结束时封面大小跳一下"）。
   */
  @Trace public coverScaleRaw: number = 1;

  /**
   * @returns 施加在播放页封面上的**视觉缩放**。
   *
   * `bigNodeScaleX` 是量测那一刻的缩放（`getPositionToWindowWithTransform()` 已经含它），
   * 这里把"当前 / 量测时"的比值乘回去 —— 于是"存的是布局矩形、画的是当前视觉矩形"。
   */
  private coverVisualScale(): number {
    return this.coverScaleLive();
  }

  /** 供 `MusicPlayInfoBlock` 把封面上当前生效的缩放写回来。 */
  public setCoverScaleLive(scale: number): void {
    const s: number = scale > 0.01 ? scale : 1;
    if (Math.abs(s - this.coverScaleRaw) > 0.0005) {
      this.coverScaleRaw = s;
    }
  }

  /** @returns 封面当前视觉缩放（默认为 1）。 */
  public coverScaleLive(): number {
    return this.coverScaleRaw > 0.01 ? this.coverScaleRaw : 1;
  }

  /**
   * 形变用的**内容区尺寸**（vp）—— 也就是"铺满"的目标与缩放分母。
   *
   * ⚠️ 这是踩过的最大的坑，五个用户可见的 bug 都出自这里（自噬，已踩五次）：
   *   1. 把 `onAreaChange` 挂在**被形变的那层容器**上（那层的高度就是裁剪窗口高度，
   *      形变期间从"迷你条封面那么高"长到满屏）。于是上报回来的"内容区高度"其实是
   *      **裁剪高度**，一次上拉之后它就被写成 ~360（≈一个屏宽），而它同时又是
   *      `clipHeight` 的目标与缩放分母 —— 自噬：目标高度被自己的中间态覆盖，
   *      之后所有展开都只能长到 360vp（"底部缺一块"/"一块近正方形的背景"）。
   *   2. 手机侧 `PlaybackPage` 自己的根 Stack 上也有 `.height(morphClipHeight())`
   *      —— **同一个坑换了个位置又踩一次**（「一块黑底 + 播放页展不开」）。
   *      ★ 2026-10-15 订正：这里原来写的是"手机侧 `PlaybackPage` 自己的根 Stack **就是**
   *      `MORPH_HOST_ID`" —— **那句是错的**：`MORPH_HOST_ID` 的实际绑定点只有两个，
   *      都在 products 壳层的根 Stack 上（常驻），播放页那一层**从来没有挂过**它。
   *      但**教训不变、而且更贴切**：真正的问题不是"它叫什么 id"，而是
   *      **任何参与形变的层都不能当"铺满目标"** —— 播放页根 Stack 的高度是**裁剪窗口高度**，
   *      不管它挂不挂那个 id，把它喂回 `reportHost()` 都会自噬。
   *   ⇒ **唯一权威 = 窗口尺寸**：由 {@link reportWindow} 从 `windowSize` 写入。
   *     参与形变的任何节点都不许写这两个字段。
   */
  @Trace public contentWidthVp: number = 0;
  @Trace public contentHeightVp: number = 0;

  /**
   * 记录宿主的**尺寸**（PC 壳层用：那层的根容器恒为满屏、不参与形变）。
   *
   * ⚠️ 手机壳层不要调它 —— 手机侧的 `MORPH_HOST_ID` 就是播放页自己的根容器，
   *    它的高度是**裁剪窗口高度**，喂回来会自噬（第五次）。手机侧的尺寸来源是
   *    {@link reportWindow}（窗口尺寸）。
   * @param widthVp 宽度（vp）
   * @param heightVp 高度（vp）
   */
  public reportHost(widthVp: number, heightVp: number): void {
    if (widthVp > 0) {
      this.contentWidthVp = widthVp;
    }
    if (heightVp > 0) {
      this.contentHeightVp = heightVp;
    }
    // ★ 跟手阶段宿主才量到尺寸（播放页是上拉起手之后才挂载的，`morphBeginEntering()`
    //   当时只能拿上一次的尺寸/窗口默认值算）：这里立刻重算一遍几何并按当前进度重落属性，
    //   免得"铺满"的目标高度差着状态栏那几十 vp，收尾时看得出来跳一下。
    //   只在**手指驱动**时做：动画驱动中改目标会让补间中途改道。
    if (this.morphStage === MorphStage.ENTERING && this.morphDrive === MorphDrive.FINGER &&
      this.bigNodeKnown) {
      if (this.morphInitParams()) {
        this.applyMorphProgress(this.morphP);
      }
    }
  }

  /** @returns 形变用的内容区尺寸：优先实测，兜底用窗口尺寸。 */
  private morphBoxWidth(): number {
    return this.contentWidthVp > 0 ? this.contentWidthVp : this.windowWidthVp;
  }

  private morphBoxHeight(): number {
    return this.contentHeightVp > 0 ? this.contentHeightVp : this.windowHeightVp;
  }

  /**
   * 用实测几何算形变的两个端点。
   *
   * ## ★ 坐标口径：全链**统一窗口坐标**（2026-09-25 二次修正）
   *
   * 起点的 `barWin*` / `mini*`、终点的 `bigNode*` / `big*` 全部来自
   * `getPositionToWindowWithTransform()` 或 `Area.globalPosition`，**都是窗口坐标**；
   * 而壳层克隆层用的是 `.position({ x: asideWinX, y: asideWinY })` —— 直接落在
   * 播放页那个满屏 Stack 里，**也是窗口坐标**。
   *
   * 所以这里**不再做任何"减宿主原点"的换算**。原来那套（先减 origin、克隆层却不减）
   * 是"起点/按钮整体偏一个 origin"的根因：只要 `originY ≠ 0`（页面避让状态栏时就不是 0），
   * 克隆层就相对真身整体错位，而形变容器按扣掉原点的坐标走 —— 两边对不上。
   * 坐标口径**只允许有一个**：窗口坐标。
   *
   * 起点 = 迷你条那条**胶囊**（`barWin*`）+ 胶囊里的**封面**（`mini*`）；
   * 终点 = 播放页封面（`bigNode*`，量不到退回 `big*`）。
   * 没有实测值时返回 false，调用方应放弃形变、直接铺满（宁可没动画也不能错位）。
   * @returns 几何是否齐备
   */
  public morphInitParams(): boolean {
    const boxW: number = this.morphBoxWidth();
    const boxH: number = this.morphBoxHeight();
    if (boxW <= 0 || boxH <= 0) {
      this.morphUsable = false;
      Logger.error(PlayerExpandState.logTag,
        `morph init FAIL: box ${boxW.toFixed(1)}x${boxH.toFixed(1)} ` +
        `(contentW=${this.contentWidthVp.toFixed(1)} winW=${this.windowWidthVp.toFixed(1)})`);
      return false;
    }
    // 起点矩形：优先用迷你条胶囊的实测值；没量到就按"封面 + 一圈内边距"估算，
    // 保证任何情况下都有一条"从迷你条那里长出来"的动画，而不是干脆没有动画。
    // 下面所有值都是**窗口坐标**（与量测、与克隆层的 `.position()` 同一口径）。
    const fallbackBarW: number = this.miniSize > 0 ? this.miniSize * 7.6 : boxW * 0.9;
    const fallbackBarH: number = this.miniSize > 0 ? this.miniSize + 12 : 56;
    const barW: number = this.barWinW > 0 ? this.barWinW : fallbackBarW;
    const barH: number = this.barWinH > 0 ? this.barWinH : fallbackBarH;
    if (barW <= 0 || barH <= 0 || boxH <= barH) {
      this.morphUsable = false;
      Logger.error(PlayerExpandState.logTag,
        `morph init FAIL: bar ${barW.toFixed(1)}x${barH.toFixed(1)} boxH=${boxH.toFixed(1)}`);
      return false;
    }
    if (this.barWinW > 0) {
      this.barX = this.barWinX;
      this.barY = this.barWinY;
      this.barRadius = this.barWinRadius > 0 ? this.barWinRadius : barH / 2;
    } else {
      // 只量到封面：胶囊按"封面左边留 12、上下居中"推出来
      this.barX = this.miniX - 12;
      this.barY = this.miniY - (barH - this.miniSize) / 2;
      this.barRadius = barH / 2;
    }
    this.barW = barW;
    this.barH = barH;
    // 封面矩形（续飞封面的起点）
    if (this.miniSize > 0) {
      this.miniCoverX = this.miniX;
      this.miniCoverY = this.miniY;
      this.miniCoverSize = this.miniSize;
      this.miniCoverRadius = this.miniRadius > 0 ? this.miniRadius : this.miniSize / 2;
    } else {
      // 连封面都没量到：退回胶囊左侧的一小块（至少动画的起点还在迷你条上）
      const side: number = barH * 0.79;
      this.miniCoverX = this.barX + (barH - side) / 2;
      this.miniCoverY = this.barY + (barH - side) / 2;
      this.miniCoverSize = side;
      this.miniCoverRadius = side / 2;
    }
    // 续飞封面的**起点**（反编译侧的 snapStart）：迷你条封面，已经算好了
    this.snapStartX = this.miniCoverX;
    this.snapStartY = this.miniCoverY;
    this.snapStartW = this.miniCoverSize;
    this.snapStartRadius = this.miniCoverRadius;
    // 续飞封面的**终点**：优先用 FrameNode 量到的播放页封面（反编译 `snapEnd*`），
    // 量不到就退回 `onAreaChange` 上报的 `big*`（第一次展开时只能靠它）
    this.endCoverX = this.bigNodeKnown ? this.bigNodeX : this.bigX;
    this.endCoverY = this.bigNodeKnown ? this.bigNodeY : this.bigY;
    this.endCoverSize = this.bigNodeKnown && this.bigNodeW > 0 ? this.bigNodeW : this.bigSize;
    // ⚠️ 高度**不能**再当正方形（`h = size`）：真实封面外有 `layoutWeight` + `constraintSize`，
    //    量到的矩形未必 1:1。量不到就退回正方形（旧行为），量到了就用真实高度。
    this.endCoverH = this.bigNodeKnown && this.bigNodeH > 0
      ? this.bigNodeH
      : this.endCoverSize;
    this.morphBoxW = boxW;
    this.morphBoxH = boxH;
    // ─────────── `initParams` 的三个 lerp 起点（逐条照抄反编译）───────────
    //   initScale      = box.width / 盒宽
    //   scaledH        = box.height / initScale
    //   initClipHeight = scaledH
    //   initTranslateX = box.left - (盒宽 - box.width) / 2
    //   initTranslateY = box.top  - scaledH * (1 - initScale) / 2
    //   initRadiusVisual = initClipHeight * initScale / 2  （= 胶囊高度的一半）
    // 注：反编译里 `fullClipHeight = px2vp(windowHeight_px)`（整窗高）；我们这里是
    //     `boxH`（宿主高度），因为播放页是**嵌在页面里**的浮层而不是窗口级浮层，
    //     用整窗高会在 t=1 时比宿主高出一截、被父层裁掉。
    this.initScale = barW / boxW;
    const scaledH: number = barH / this.initScale;
    this.initClipHeight = scaledH;
    this.initTranslateX = this.barX - (boxW - barW) / 2;
    this.initTranslateY = this.barY - scaledH * (1 - this.initScale) / 2;
    this.initRadiusVisual = scaledH * this.initScale / 2;
    this.morphUsable = true;
    // 形变几何是"看不见但错了就全错"的那类参数：把这一份打到日志里，
    // 出问题时 `hdc shell hilog | grep RzdMorph` 一眼就能看出是哪一项量歪了。
    Logger.info(PlayerExpandState.logTag,
      `morph init box=${boxW.toFixed(1)}x${boxH.toFixed(1)} bar=(${this.barX.toFixed(1)},` +
      `${this.barY.toFixed(1)},${barW.toFixed(1)}x${barH.toFixed(1)}) r=${this.barRadius.toFixed(1)} ` +
      `cover=(${this.miniCoverX.toFixed(1)},${this.miniCoverY.toFixed(1)},` +
      `${this.miniCoverSize.toFixed(1)}) end=(${this.endCoverX.toFixed(1)},${this.endCoverY.toFixed(1)},` +
      `${this.endCoverSize.toFixed(1)}x${this.endCoverH.toFixed(1)},src=${this.endAnchorSource()}) ` +
      `initScale=${this.initScale.toFixed(4)} ` +
      `initClipH=${this.initClipHeight.toFixed(1)} initTx=${this.initTranslateX.toFixed(1)} ` +
      `initTy=${this.initTranslateY.toFixed(1)} initR=${this.initRadiusVisual.toFixed(1)}`);
    return true;
  }

  /** @returns 终点锚点（播放页大封面）是否有一份可用值（FrameNode 量到，或 onAreaChange 兜底）。 */
  private endAnchorKnown(): boolean {
    return (this.bigNodeKnown && this.bigNodeW > 0) || this.bigSize > 0;
  }

  /**
   * @returns 终点锚点是否已就绪（给调用方判"还要不要继续补量"用）。
   *
   * ⚠️ **不要**用 `morphUsable` 代替它：`morphUsable` 会因为"退回 `onAreaChange` 兜底值"
   * （甚至"上一轮留下的值"）而为真，用它当"还要不要补量"的判据会让补量链**提前收工**
   * —— 那正是点击打开时 `morphGeomReady` 永远是假的原因之一。
   * 真正的"可以落位"判据是 {@link morphGeomReadyNow}。
   */
  public morphEndAnchorReady(): boolean {
    return this.endAnchorKnown();
  }

  /** @returns 终点的来源（只给日志用：区分 FrameNode 量到 / onAreaChange 兜底 / 都没有）。 */
  private endAnchorSource(): string {
    if (this.bigNodeKnown && this.bigNodeW > 0) {
      return 'frameNode';
    }
    if (this.bigSize > 0) {
      return 'areaChange';
    }
    return 'none';
  }

  /**
   * @returns 两端的几何是否都量到了（可以走形变路径）。
   *
   * ★★ 2026-10-15（**已判定为死代码**，`RzdMusic记忆.md` §60）：**零调用者**。
   *   它要求 `bigSize > 0`（那是 `reportBig` **上报值**），而活的判据是
   *   {@link morphIntroAnchorsReady}：**同时接受** `bigNodeKnown`（FrameNode 量到的，最准）
   *   与 `bigSize`（上报兜底），并且还要求 `morphUsable && endCoverSize > 0`。
   *   ⇒ 本函数是那条判据**更早、更弱**的版本：真接上它会让"FrameNode 量到了但 areaChange
   *     还没上报"那一帧被误判成"几何没齐" ⇒ 点击打开退化成无动画落位（§56.15 修过的那个坑）。
   * @deprecated 零调用者。判据请用 {@link morphIntroAnchorsReady}。
   * 复核命令：`grep -rn 'morphReady(' RzdMusic --include=*.ets`（期望：只有本处定义）
   */
  public morphReady(): boolean {
    return this.miniSize > 0 && this.bigSize > 0 && this.morphBoxWidth() > 0 && this.morphBoxHeight() > 0;
  }

  /** @returns 形变窗口当前是否有效（静止态 false，调用方该用 `'100%'`）。 */
  public morphClipping(): boolean {
    return this.morphUsable && this.morphContainerActive();
  }

  /**
   * @returns 宿主（= 内容层固定尺寸）宽度（vp）。
   * @deprecated 零调用者（`RzdMusic记忆.md` §59）。宿主尺寸在**内部**由 `morphBoxWidth()`
   *   直取；对外没有消费者。复核：`grep -rn 'morphHostW' RzdMusic --include=*.ets`
   */
  public morphHostW(): number {
    return this.morphBoxW > 0 ? this.morphBoxW : this.morphBoxWidth();
  }

  /**
   * @returns 宿主（= 内容层固定尺寸）高度（vp）。
   * @deprecated 零调用者（同 {@link morphHostW}）。
   */
  public morphHostH(): number {
    return this.morphBoxH > 0 ? this.morphBoxH : this.morphBoxHeight();
  }

  // ───────────────────── 跟手打开：两条手势共用同一套驱动/收尾 ─────────────────────
  //
  // 触摸可能落在**迷你条自己**（它的手势）或**壳层根节点**（另一条手势）上，
  // 谁接到谁驱动；但几何只有一份、收尾补间只有一处（壳层，因为它拥有 `isShowPlay`）。

  /**
   * ★ **形变起手的唯一正确顺序**（点击与跟手两条路都走它）：
   * ```
   *   1. invalidateEndAnchor()  —— 把上一轮的终点作废（终点是"当前"矩形，不能沿用）
   *   2. measureGeometry()      —— **此刻播放页还是原尺寸**，量到的是干净的原尺寸矩形
   *   3. morphBeginEntering()   —— 再把窗口压到起点（p = 0）
   * ```
   * 顺序反了就是上一版的 bug：先压起点再量 → 量到压扁帧；或者量完又被
   * `morphBeginEntering` 抹掉 → 终点永远补不回来 → 点击路径退化成无动画落位。
   *
   * ⚠️ 已经在本轮会话里（`morphSessionStarted`）就不要重复第 1 步：
   *    重试期间要保住已经量到的终点。
   * @param ui UIContext
   * @param preferFloating 见 {@link measureGeometry}
   * @returns 形变几何是否可用
   */
  public prepareMorphEntry(ui: UIContext, preferFloating: boolean): boolean {
    if (!this.morphSessionStarted) {
      this.invalidateEndAnchor();
      // ★★★ 2026-10-16（**新会话必须把"锚点用量"也清零**）：
      //   `bigSize` 是 `MusicPlayInfoBlock.reportBig()`（`onAreaChange`）上报的**跨会话残留字段**
      //   —— `morphReset()` 不清它。于是"终点锚点是否量到"（`morphEndAnchorReady()`）在
      //   新一轮的**第一拍**就会读到**上一轮**的值 ⇒ 补量链以为已经就绪 ⇒ 提前收工
      //   ⇒ `morphGeomReady` 永远是假 ⇒ 容器恒等 ⇒ 点击打开没有动画。
      //   无界侧没有这个问题（它的 `ExpandSnapshot.playerCoverRect` 每轮由播放页**重新上报**），
      //   所以这里只需在会话边界把"这一次量到的"清零即可。
      this.bigSize = 0;
      this.morphSessionStarted = true;
    }
    // 等待布局期间保持原尺寸。不能先压到 p=0 再跨帧补量：下一帧已经是缩小布局。
    this.measureGeometry(ui, preferFloating, true);
    this.morphInitParams();
    if (!this.bigNodeKnown || !this.morphIntroAnchorsReady()) {
      Logger.info(PlayerExpandState.logTag, 'entry pending: keep full-size layout until end anchor ready');
      return false;
    }
    this.freezeMorphMeta(ui);
    return this.morphBeginEntering();
  }

  /** 本次形变会话是否已经开始过（见 {@link prepareMorphEntry} 的第 1 步）。 */
  @Trace public morphSessionStarted: boolean = false;

  /**
   * 手指跟手打开：起手 —— 量几何 + 把窗口压到起点，并标记"手指正在驱动"。
   *
   * ⚠️ `pullDragging` **必须在量测之前**置位：重试期间播放页那边要靠它放行绘制
   *    （见 `PlaybackPage.morphOpacityValue`）—— 顺序反了会出现"手指已经按住、
   *    播放页还是全透明"的那一两帧。
   * @param ui UIContext（取自接到手势的那一层）
   * @param preferFloating 见 {@link measureGeometry}
   * @returns 几何是否可用（false 时调用方应直接铺满，别硬做形变）
   */
  public pullOpenBegin(ui: UIContext, preferFloating: boolean): boolean {
    this.pullDragging = true;
    // 记下起手时刻：残留标记靠它判定过期（见 `pullStartedAtMs` 的说明）
    this.pullStartedAtMs = Date.now();
    const ready: boolean = this.prepareMorphEntry(ui, preferFloating);
    if (!ready) {
      this.morphGen = this.morphGen + 1;
      this.morphStage = MorphStage.ENTERING;
      this.morphDrive = MorphDrive.FINGER;
      this.morphUsable = false;
      this.morphP = 0;
      // ★★★ 2026-10-16（**照搬无界"进相位时就落起点几何"** —— 修"点击打开首帧闪一整屏"）：
      //
      // ## 无界是怎么做的
      // ```
      //   beginMorphEnter(src)                              wujie.pa 146495
      //       setMorph(ENTERING, FINGER)                    // ① 进相位
      //       pushPath({name, param:{pull:true}})           // ② 推路由
      //   …播放页挂载、publishMorphTargets 量到终点…
      //       pullGeomReady = true
      //       expand.applyPullProgress(ui, pullT)           // ③ 第一次就落 **pullT = 0** 的几何
      //                                                     //    （= 迷你条那一小块，不是恒等！）
      // ```
      //   ⇒ 无界的 `pullVisibleRect` **从第一帧起就永远是那个小矩形**，从不等于恒等。
      //
      // ## 我们原来的样子（这就是"点了会闪一下全屏"的来源）
      //   `prepareMorphEntry` 在终点锚点缺失时**提前 return false**，于是
      //   `morphBeginEntering()` → `applyMorphProgress(0)` **根本没跑到**
      //   ⇒ 容器停在**恒等**（整屏）⇒ 播放页挂载那一刻就是"一整屏播放页"，
      //     要等 32ms 后补量成功才"啪"地缩到迷你条再往前长 —— 观感是**闪一帧全屏再收回去**。
      //
      // ## 改法（判据取自更早的事实）
      //   起点几何（迷你条胶囊 + 宿主尺寸）在**这一刻是量得到的**（`morphInitParams()` 已经成功过），
      //   只有**终点**量不到 ⇒ 那就先按终点缺失把**起点几何**落下去：
      //   `applyMorphProgress(0)` 只需要 `initScale/initTranslate*/initClipHeight`，
      //   它们全部由 `morphInitParams()` 填好 —— **不需要终点**。
      //   ⚠️ `morphUsable` 仍保持 false：更新它的是真正的补量（`measureMiniDuringPull`），
      //      它是下游一堆门的判据，这里**不动它**（第一轮纪律：不要用一个布尔承担两种语义）。
      //   ⚠️ 落几何要临时开门（`morphGeomReady`），落完**必须原样关回去** —— 否则
      //      "最后一次量到的 initScale" 会被无界的门放行去画一串过期几何。
      const startGeomOk: boolean = this.morphInitParams();
      if (startGeomOk) {
        // ⚠️ `applyMorphProgress` 现在有一道 `morphGeomReady` 门（见那个字段），
        //    而这一刻"终点还没量到"⇒ 门上写着"不许落位"。
        //    起点几何是**另一件事**：它只需要胶囊与宿主尺寸（都已经量到了）。
        //    ⇒ 临时开门落一次，落完**原样关回去**（绝不能让"最后一次量到的 initScale"
        //      被当成"本轮已就绪"而放行一串过期几何）。
        const prevReady: boolean = this.morphGeomReady;
        this.morphGeomReady = true;
        this.applyMorphProgress(0);
        this.morphGeomReady = prevReady;
      }
      Logger.info(PlayerExpandState.logTag,
        `RzdMorphStart bake start geometry: initOk=${startGeomOk} geomReady=${this.morphGeomReady} ` +
        `initScale=${this.initScale.toFixed(4)} clipH=${this.initClipHeight.toFixed(1)} ` +
        `tx=${this.initTranslateX.toFixed(1)} ty=${this.initTranslateY.toFixed(1)}`);
    }
    // 已有起点就继续等待目标挂载，调用方不能把首次上拉直接落位。
    // ★★ 2026-10-15 诊断锚点（`hdc shell hilog -x | Select-String 'RzdMorphStart'`）——
    //   一次打出**形变起点**的全部量，用来判定用户报的「**动画起始位置偏下**」属于哪一种：
    //     · `bar`  = 量到的迷你条**胶囊**渲染矩形（`getRectangleById`，**窗口坐标**、含祖先 transform）
    //     · `mini` = 量到的迷你条**封面**矩形 —— **形变严格用的就是它**（`miniY/miniSize`）
    //     · `win`  = 窗口尺寸；`pad` = 真实避让区（上 / 下）；`usable` = 两端锚点是否齐
    //   **判据（配合壳层的 `RzdPlayerViewport` 那条一起看）**：
    //     · 若 `RzdPlayerViewport` 的 `overlay` 高度 **小于** `window` 高度（差 ≈ pad 之和）
    //       ⇒ **内容盒没铺满窗口** ⇒ 形变全走窗口坐标时就整体偏下 ⇒ 归页根那条
    //         `expandSafeArea + ignoreLayoutSafeArea`（#4 那处修复）管；
    //     · 若 `overlay == window` 而这里的 `mini.y` 与迷你条在屏上的**实际**位置不一致
    //       ⇒ **量测口径**问题（该用渲染位而不是布局位）。
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdMorphStart ready=${ready} preferFloating=${preferFloating} ` +
      `bar=(${this.barWinX.toFixed(1)},${this.barWinY.toFixed(1)},` +
      `${this.barWinW.toFixed(1)},${this.barWinH.toFixed(1)}) ` +
      `mini=(${this.miniX.toFixed(1)},${this.miniY.toFixed(1)},${this.miniSize.toFixed(1)}) ` +
      `win=${this.windowWidthVp.toFixed(0)}x${this.windowHeightVp.toFixed(0)} ` +
      `pad=${this.topInsetVp().toFixed(1)}/${this.navigationBarBottomVp.toFixed(1)} ` +
      `usable=${this.morphUsable} bigKnown=${this.bigNodeKnown} ` +
      `endKnown=${this.endAnchorKnown()} geomReady=${this.morphGeomReady}`);
    // ★★★ 2026-10-16（**返回值语义订正：`false` 只代表"起点几何也没有"**）：
    //   原来是 `ready || (barWinW > 0 && miniSize > 0)` —— 单看没问题，但它与调用方
    //   `Index.beginOpenMorphOnClick` 的"`false` ⇒ 立刻 `morphReset()` + 无形变落位"
    //   合起来就是那个坑：点击打开时**终点**（播放页大封面）必然还没挂载，
    //   而调用方会把"终点没量到"当成"这套动画做不了"⇒ **补量链被整段跳过**
    //   ⇒ `morphGeomReady` 永远为假 ⇒ 容器恒等 ⇒
    //   用户实测「点击打开 / 点击关闭 / 系统返回 都没有动画」。
    //   无界的形状（`MainPage.beginMorphEnter` 146495 起 + `openPlayerMorph` 149679）：
    //   **量到起点就 `true` 并推路由**，终点由**播放页挂载后自己上报**
    //   （`publishMorphTargets` → `pullGeomReady = true` → `onPullReady` 回调接着跑）。
    //   ⇒ 所以这里保持"起点就绪即 true"；终点缺失由补量链负责（调用方**不再**因
    //     `false` 而放弃会话，见那边 `isFreshSession` 那一段）。
    //   `false` 现在只对应"连迷你条胶囊都没量到"这一种真正没救的情况。
    return ready || (this.barWinW > 0 && this.miniSize > 0);
  }

  /**
   * 跟手起手**之后**的补量：播放页是上拉起手那一刻才挂载的，第一帧量不到它的封面节点。
   *
   * 反编译侧也是这个顺序（`onPullReady` 回调里补量一次）；我们这里由迷你条/壳层的
   * 定时器调。只在手指驱动期间生效，避免把已经开跑的补间中途改道。
   * @param ui UIContext
   * @param preferFloating 见 {@link measureGeometry}
   * @returns 终点锚点是否补量成功
   */
  public measureMiniDuringPull(ui: UIContext, preferFloating: boolean): boolean {
    if (this.morphStage !== MorphStage.ENTERING || this.morphDrive !== MorphDrive.FINGER) {
      return false;
    }
    if (this.bigNodeKnown && this.morphUsable) {
      return true;
    }
    if (!this.measureEndAnchor(ui)) {
      return false;
    }
    // 目标首次挂载时保持原尺寸量测；量齐后再用已经累计的手势进度驱动裁剪。
    const pendingProgress: number = this.morphP;
    this.freezeMorphMeta(ui);
    this.sourceBarHidden = true;
    this.morphInitParams();
    // ★★★ 2026-10-16（**照搬无界 `publishMorphTargets` 最后那三行**，`wujie.pa` 176216-176233）：
    //   终点几何刚刚量到 ⇒ 这就是"几何就绪"那一刻，**在这一拍**把容器几何第一次落到
    //   `applyMorphProgress(pendingProgress)`。在此之前 `applyMorphProgress` 会主动什么都不做
    //   （见那边的 `morphGeomReady` 门）⇒ 容器一直保持恒等，不会出现"提前按半份几何落位"。
    if (!this.morphGeomReady) {
      this.morphGeomReady = true;
      this.pushMorphTrace('geomReady');
      Logger.info(PlayerExpandState.logTag,
        `morph geom ready: end=(${this.endCoverX.toFixed(1)},${this.endCoverY.toFixed(1)},` +
        `${this.endCoverSize.toFixed(1)}x${this.endCoverH.toFixed(1)},src=${this.endAnchorSource()}) ` +
        `start=(${this.miniCoverX.toFixed(1)},${this.miniCoverY.toFixed(1)},${this.miniCoverSize.toFixed(1)}) ` +
        `initScale=${this.initScale.toFixed(4)} p=${pendingProgress.toFixed(3)}`);
    }
    this.applyMorphProgress(pendingProgress);
    return true;
  }

  /**
   * @returns 跟手进度 0…1（竖向位移，上拉为正）。
   *
   * **逐条照抄反编译的主算式**（`MainPage.pullUpdate`）：
   * ```
   *   morphT = clamp(-vp2px(dy) / pullRangePx, 0, 1)
   *   pullRangePx = rect.top > 0 ? rect.top : windowHeight * PULL_RANGE_RATIO
   * ```
   * 也就是"**绝对映射**：位移的纯函数，没有累加、没有阻尼、没有惯性"——
   * 归一化分母是**胶囊的 top**（从上拉到迷你条位置需要的行程）。
   * 我这里用 vp 统一口径（分子分母同时是 vp，比值等价），所以不用 `vp2px`。
   */
  public pullOpenFraction(offsetY: number): number {
    const ratio: number = (-offsetY) / this.pullSpanVp();
    return ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
  }

  /**
   * @returns 跟手位移的归一化行程（vp）：**优先实测**胶囊 top（= 无界的 `coverRect.top`），
   *   量不到才退回窗口高度的 0.55。
   *
   * ⚠️ **兜底比例 0.55 ≠ 无界的 `PULL_RANGE_RATIO = 0.32`，有意保留、只标注**
   *   （依据 `docs\无界形变手感-落实到RzdMusic清单.md` §八 第 6 条：比例值"改了要实测手感再定"，
   *   不许按无界的值直接覆盖）：
   *   · 主路径**恒为实测 `barY`**（`morphInitParams()` 成功时 `barY > 0`），
   *     兜底分支只在"几何全没量到"时走 —— 那种情况下手势本来就退化（起手即 `!ok` 落位），
   *     0.55 与 0.32 都不参与真实手感；
   *   · 判据行：真机上若看到 `morph init FAIL: bar …` 或 `morph init box=… bar=(0,0,…)`，
   *     说明走的是兜底 —— 那时再谈要不要把它对齐到 0.32。
   */
  public pullSpanVp(): number {
    if (this.barY > 0 && this.barH > 0) {
      return this.barY;
    }
    const h: number = this.windowHeightVp > 0 ? this.windowHeightVp : 800;
    return Math.max(1, h * 0.55);
  }

  /**
   * @returns 跟手行程是否**走的是实测那一支**（`barY`/`barH` 都有值）。
   *
   * 只给日志用：`RzdMorph dismiss commit` / `RzdMorph pull commit` 两条判据日志里都要带
   * "这个分母是量的还是兜底的"。**为什么非要它**：`派音动画Bug清单.md` §6.5 立过一条——
   * 只打"比值 vs 阈值"会把「两个方向的分母不是同一个长度」这件事继续藏起来，
   * 于是下一个人又会把收起的 `38%` 换算成 `1 − 0.38 = 0.62` 去和打开的 `0.45` 比。
   * 两个分母（`pullSpanVp()` / `PlaybackPage.dismissSpanVp()`）必须与两个阈值**同行打印**。
   */
  public pullSpanIsMeasured(): boolean {
    return this.barY > 0 && this.barH > 0;
  }

  /**
   * **提交阈值 `COMMIT_T`**（0…1）—— 对标无界 `MainPage.COMMIT_T = 0.32`。
   *
   * ★★ 2026-10-15（用户指示「**手感对齐无界**」后落地）：值从 `0.45` 改成 **`0.32`**。
   *   ⚠️ 这条**推翻了**本文件此前的一条指令（原文："无界是 `COMMIT_T = 0.32`，这里保持
   *   0.42 / 0.45，标注『待实测』…**不许按无界的值直接覆盖**"）—— 那条的顾虑是"没上机实测
   *   就不动手感"，而现在**用户明确要求手感对齐无界**，该顾虑的条件不再成立 ⇒ 按无界落地。
   *
   * ★ **两个方向共用同一个 `T`**（无界就是这样）：
   *   · 打开：`morphT >= COMMIT_T`（本文件 `pullOpenShouldCommit()`）；
   *   · 关闭：**相对量** `delta >= max(baseT/2, COMMIT_T)`（`PlaybackPage.onDismissDrag`，
   *     对标无界 `reverseQuitDelta()`）—— **不是**"缩到某个百分比就关"。
   *   ⇒ 满展开起手关闭时阈值 = `max(0.5, 0.32) = 0.5`（要拉回去 50% 才关）。
   */
  public static readonly PULL_OPEN_COMMIT_FRACTION: number = 0.32;
  /**
   * 上拉打开的**速度**提交阈值（vp/s）。
   *
   * 出处与 `PlaybackPage.DISMISS_COMMIT_VELOCITY` 是**同一个数**：
   *   `docs\无界形变手感-落实到RzdMusic清单.md` §一 1.2「提交判定 —— 进度 OR 速度」
   *   ⇒ `commit = (morphT >= COMMIT_T 0.32) || (velocity <= COMMIT_VELOCITY 900)`
   *   ⇒ 无界的 `COMMIT_VELOCITY = 900`。
   * 而且那一条本来就是**打开方向**的判据：`morphT` 正是无界
   *   `MainPage.pullUpdate` 算出来的**上拉打开**进度（`clamp(-vp2px(dy)/pullRangePx)`）。
   *   收起方向那条（`PlaybackPage.onDismissDrag`，D1）是 RzdMusic 的反向手势，
   *   已经按同一数额落地；这里把**打开**方向也补齐 ⇒ 两条手势的提交判据同源同额。
   *
   * ⚠️ **不照抄符号**（清单 §八 第 3 条）：SDK 的 `GestureEvent.velocityY` 没承诺方向。
   *   这里与 D1 同款绕开：**方向由位移判（上拉 ⇒ `offsetY < 0`）、大小取 `Math.abs(velocityY)`**
   *   ⇒ 无论系统给的是 +900 还是 −900，判定结果都一样。
   */
  private static readonly PULL_OPEN_COMMIT_VELOCITY: number = 900;

  // ══════════ 开 / 关两向的提交判据：**只在这里定义一份**（本轮收敛） ══════════
  //
  // 收敛的由来（`_recover\logic-src\派音动画Bug清单.md` P0-1 + §6.5）：
  //   原来这两个数**分居两个文件**（打开在 `PlayerExpandState`、收在 `PlaybackPage`），
  //   没有任何交叉校验 —— 而它们是**互逆的两条手势**，改一个不改另一个就会在临界位置打架
  //   （手感上是"甩不上去，一松手又掉下来"）。
  //   §6.5 的处置结论：**性质是"两处各写一遍 + 从未定案"**（不是"方向反了"，
  //   那句"收起方向的门比打开方向高 39%"是把两把不同的尺子（`barY` / `miniY`）换算错了）。
  //
  // ⚠️⚠️ **历史记录（已被 2026-10-15 的"手感对齐无界"取代，留档不再执行）**：
  //   这里原来写着"这两个数与 `PULL_OPEN_COMMIT_FRACTION` 只能一起改，而且**必须先上机实测**；
  //   无界是 0.32，这里保持 0.42 / 0.45…**不许按无界的值直接覆盖**"，并给出当时的量级：
  //     打开提交 ≈ `0.45 × barY`；收起提交 ≈ `0.38 × miniY`（`barY ≈ miniY`）
  //   ⇒ 当时的结论是「收起其实比打开更容易（约 −16%），不是"收起更难"」。
  //   **用户 2026-10-15 明确指示"手感对齐无界"** ⇒ 那条顾虑（"没实测就不许覆盖手感"）的前提消失：
  //     打开阈值 → `0.32`；关闭 → 相对量 `max(baseT/2, 0.32)`（满展开起手 ⇒ 要拉回 50% 才关）。
  //   ⇒ **方向反过来了**：现在是"打开更容易、关闭更不易误关"，与无界一致。

  /**
   * 下拉松手时的**进度**提交阈值（0…100）—— ⚠️ **只给"退化路径"用**。
   *
   * ★★ 2026-10-15（手感对齐无界）：**形变路径已经不用它了** —— 那条路改成无界的
   *   **相对量**判据 `delta >= max(baseT/2, COMMIT_T)`（见 `PlaybackPage.onDismissDrag`
   *   与 `PULL_OPEN_COMMIT_FRACTION` 的注释）。
   *   本常量现在只服务"**量不到几何**（`morphUsable === false`）那条退化分支"：
   *   那里没有 `morphT` 可算 `delta`，只能仍旧按"缩到多少"判。
   *   ⇒ 它是**降级路径的兜底**、不是主判据；无界没有对应分支（它总能量到几何）。
   */
  public static readonly DISMISS_COMMIT_PROGRESS: number = 38;

  /**
   * 下拉收起：拖拽多少距离算"拉到底"（相对窗口高度）。
   *
   * ⚠️ **无界是 0.32，这里保持 0.42，标注"待实测"** —— 依据
   *   `docs\无界形变手感-落实到RzdMusic清单.md` §八 第 6 条
   *   （"改了要实测手感再定"，不许按无界的值直接覆盖）。
   *   它现在只是**兜底**：`PlaybackPage.dismissSpanVp()` 优先用实测的收起行程（`miniY`），
   *   只有量不到（`miniY <= 0`）时才退回这个比例。
   */
  public static readonly DISMISS_DRAG_SPAN_RATIO: number = 0.42;

  /**
   * 上拉松手：**是否提交**（= 展开到底而不是回弹卸载）。
   *
   * ★ 这是**唯一**的提交判据（清单 §一 1.2 的「进度 OR 速度」+ §四 D1）。
   *   两条理由，缺一条都不该把它做成函数：
   *   1. **补速度项**：原来 `>= 0.45` 只看进度 —— "位移不大、但甩得很快"不提交，
   *      手感上就是"**轻甩打不开**"（D1 在收起方向修掉的是同一个毛病）；
   *   2. **判据只有一份**：原来这条 `>= 0.45` 在**三个文件里各写一遍**
   *      （`Index.onPullOpenEnd` / `HomeMiniBarPlayer` / `MiniBarPlayer`），
   *      而本工程的既有教训是「**同一个量在两处各算一遍，就会在临界值上打架**」
   *      （歌单页黑白字那次）⇒ 收敛到这里，三处只传参、不再各自判。
   *
   * ⚠️ 判据全部是**入参的纯函数**：不读上一帧、不做累加（清单 §一 1.1 的同一条要求）。
   * @param progress 当前上拉进度 0…1（传 `morphP` —— **屏上真正在用的那个值**，
   *   而不是拿 `offsetY` 重算一遍：起手中途补量过锚点时 `pullSpanVp()` 会变，
   *   重算出的值与画面不一致）
   * @param offsetY 松手时的竖直位移（vp，**上拉为负**）
   * @param velocityY 松手时的竖直速度（`GestureEvent.velocityY`，vp/s）
   * @returns true = 展开到底；false = 回弹并卸载
   */
  public pullOpenShouldCommit(progress: number, offsetY: number, velocityY: number): boolean {
    const reached: boolean = progress >= PlayerExpandState.PULL_OPEN_COMMIT_FRACTION;
    const opening: boolean = offsetY < 0;
    const speed: number = Math.abs(velocityY);
    const fastFlick: boolean = opening && speed >= PlayerExpandState.PULL_OPEN_COMMIT_VELOCITY;
    const commit: boolean = reached || fastFlick;
    // 上机排查：`hdc shell hilog -x | Select-String 'RzdMorph pull commit'`
    // ⚠️ 这一行**与 `PlaybackPage.onDismissDrag` 那条同构**：都把**两个方向的阈值 + 两个分母**
    //    打在同一行（见 `pullSpanIsMeasured()` 的注释）—— 只打"比值 vs 阈值"会继续藏住
    //    "两个分母不是同一个长度"这件事，下次还会有人把收起的 38% 换算成 0.62 去和 0.45 比。
    Logger.info(PlayerExpandState.logTag,
      `RzdMorph pull commit progress=${progress.toFixed(3)}/${
        PlayerExpandState.PULL_OPEN_COMMIT_FRACTION} offsetY=${offsetY.toFixed(1)} ` +
      `velocityY=${velocityY.toFixed(1)} absVelocity=${speed.toFixed(1)} ` +
      `dir=${opening ? 'open' : 'close'} fastFlick=${fastFlick} ` +
      `velocityThreshold=${PlayerExpandState.PULL_OPEN_COMMIT_VELOCITY} ` +
      `span=${this.pullSpanVp().toFixed(1)} spanSrc=${
        this.pullSpanIsMeasured() ? 'measured' : 'ratio'} ` +
      `dismissThreshold=${PlayerExpandState.DISMISS_COMMIT_PROGRESS} dismissSpan=${
        this.miniY.toFixed(1)} dismissSpanSrc=${
        this.miniY > 0 ? 'measured' : 'ratio'} commit=${commit}`);
    return commit;
  }

  /** 松手请求版本号（壳层 `@Monitor` 它来播收尾补间）。 */
  @Trace public pullSettleVersion: number = 0;
  /** 本次松手是否提交（true = 展开到底，false = 回弹并卸载）。 */
  @Trace public pullSettleCommit: boolean = false;

  /**
   * 手指跟手打开：松手 —— 只发"请求"，真正的补间由壳层播。
   *
   * 为什么不让手势方自己播：补间要用 `UIContext.animateTo`，而**挂载/卸载播放页浮层**
   * 只有壳层能做（`isShowPlay` 在壳层）。分成"手势驱动 + 壳层收尾"两步，
   * 迷你条那条手势和壳层那条手势就都能用同一套收尾逻辑。
   * @param commit true = 展开到底；false = 回弹回迷你条并卸载
   */
  public requestPullOpenSettle(commit: boolean): void {
    this.pullDragging = false;
    this.pullSettleCommit = commit;
    this.pullSettleVersion = this.pullSettleVersion + 1;
  }

  // ───────────────────── 桥接封面（对标无界 CoverMorph 的"起点∈迷你条"那一半）─────────────────────
  //
  // 为什么需要它：整页形变是"把播放页整体缩放"，缩放后的页面在 p 很小时只露出**页面顶部**
  // 那一小截 —— 那时候能看到的当然不是封面的位置。可用户要的是
  // 「封面从小播放器那张**逐渐放大、改位置、改圆角**，一镜到底成播放页」。
  // 所以形变早期单独画一张"续飞封面"：从迷你条封面的矩形走到**当前帧播放页封面**
  // 在屏幕上的矩形（把播放页封面按容器的变换换算过去），与内容层里那张真封面同位交接。

  /**
   * @returns 是否该画桥接封面。
   *
   * 只在形变进行中（不含 LANDING —— 那一刻封面已经交还给迷你条）且内容层还没显出来时画。
   */
  public morphBridging(): boolean {
    if (!this.morphClipping()) {
      return false;
    }
    // LANDING = 已经交还给迷你条（那一刻迷你条自己那张封面就在原地，别再叠一张）
    if (this.morphStage === MorphStage.LANDING) {
      return false;
    }
    // 起点（迷你条封面）与终点（播放页封面）都量到了才画，否则宁可没有这一棒
    // ⚠️ 终点**必须有值**：终点是"静止态真实矩形"，终点为 0 时会飞向屏幕左上角
    //
    // ★★ 2026-10-15 **回退我自己的"时间窗"改动**：这一棒必须**一直飞到 p=1**。
    //   原因（真机实测）：它的矩形是**窗口坐标**，而被画在**被 scale+translate 变换过的容器里**，
    //   只有 p=1（容器是恒等变换）时窗口坐标才等于它要落的位置；
    //   若在 p=0.55 就把它裁掉/交棒，那一帧它还在半路、真封面在自己的布局位上 ⇒ **会跳**。
    //   我一度试过"逆变换回页内坐标"来提前落位，真机结果是"封面跑到左上角"
    //   （说明 `.scale()` 的枢轴不是我以为的容器中心）⇒ 该方案作废，别再试。
    return this.snapStartW > 0 && this.endCoverSize > 0;
  }

  /**
   * @returns 续飞封面的不透明度。
   *
   * 恒为 1：反编译里克隆层（封面/元信息/操作区）是**画在容器之上**的一层副本，
   * 它不淡 —— 淡的是背景层（`pullBgIn`）与迷你条那侧的两档透明度
   * （`metaOpacityAt` 0.35 / `actionsOpacityAt` 0.20）。
   * 起点之所以不再出现"两个播放器"：克隆的封面与真实迷你条封面**同位置同图**，
   * 而真实的迷你条在浮层之下、随后被不透明起来的背景盖掉。
   */
  public morphBridgeOpacity(): number {
    return this.morphBridging() ? 1 : 0;
  }

  // ───────────── 克隆层的位移量（反编译 `MiniMorph.coverRightShiftAt / coverRiseAt`）─────────────
  //
  //   coverVisualEdgeAt(t) = lerp(迷你封面宽, 目标封面宽, t)
  //   coverCenterXAt(t)    = lerp(迷你封面中心X, 目标封面中心X, t)
  //   coverRightAt(t)      = coverCenterXAt(t) + coverVisualEdgeAt(t) / 2
  //   coverRightShiftAt(t) = coverRightAt(t) - coverRightAt(0)      ← 相对起点的**右移量**
  //   coverRiseAt(t)       = coverCenterYAt(t) - coverCenterYAt(0)  ← 相对起点的**上升量**
  //
  // 元信息层用它做 `translate({x})`（"推挤"右侧内容），操作区层用它做 `translate({y})`。

  /** @returns 封面可视宽度的中心 X（vp，宿主坐标）插值。 */
  private coverCenterXAt(t: number): number {
    const from: number = this.miniCoverX + this.miniCoverSize / 2;
    const to: number = this.endCoverX + this.endCoverSize / 2;
    return from + (to - from) * t;
  }

  /** @returns 封面可视宽度的中心 Y（vp，宿主坐标）插值。 */
  private coverCenterYAt(t: number): number {
    const from: number = this.miniCoverY + this.miniCoverSize / 2;
    const to: number = this.endCoverY + this.endCoverSize / 2;
    return from + (to - from) * t;
  }

  /** @returns 封面可视宽度（vp）插值：`lerp(迷你封面宽, 目标封面宽, t)`。 */
  private coverVisualEdgeAt(t: number): number {
    return this.miniCoverSize + (this.endCoverSize - this.miniCoverSize) * t;
  }

  /** @returns 相对起点的右移量（vp）：给元信息克隆层做 `translate({x})`。 */
  public coverRightShiftAt(p: number): number {
    const t: number = p < 0 ? 0 : (p > 1 ? 1 : p);
    const now: number = this.coverCenterXAt(t) + this.coverVisualEdgeAt(t) / 2;
    const at0: number = this.coverCenterXAt(0) + this.coverVisualEdgeAt(0) / 2;
    return now - at0;
  }

  /** @returns 相对起点的上升量（vp）：给操作区克隆层做 `translate({y})`。 */
  public coverRiseAt(p: number): number {
    const t: number = p < 0 ? 0 : (p > 1 ? 1 : p);
    return this.coverCenterYAt(t) - this.coverCenterYAt(0);
  }

  /**
   * @returns 桥接封面的一帧矩形（vp，**宿主坐标**）。
   *
   * - 起点：迷你条封面（`MiniMorph` 那一半，实测）；
   * - 终点：播放页封面在**当前帧**的屏幕矩形 —— 内容层是"固定宿主尺寸 + 居中等比缩放 s"，
   *   所以页内坐标 (x, y) 映射到 `内容层左上角 + (x, y) * s`，而内容层左上角又由
   *   窗口（贴底居中、尺寸 `morphWinW/H`）与 `s` 决定。t = 1 时窗口 = 宿主、s = 1，
   *   于是终点正好是实测的 (bigX, bigY, bigSize) —— **动画完成那一刻才归位**。
   */
  public morphCoverBridge(): LyricMorphRect {
    return this.morphCoverRectAt(this.morphP);
  }

  /**
   * @returns **任意进度**下的续飞封面矩形（vp，**窗口坐标**）。
   *
   * ⚠️ 两份口径分开、不要混在一个函数里：
   *   · `morphCoverBridge()`          —— 播放页那份，进度 = `morphP`（350ms 那层）；
   *   · `morphOverlayCoverBridge()`   —— **壳层浮层**那份，进度 = `morphOverlayP`（560ms 那层）。
   * 两者共用下面这段纯几何（起点/终点/直线插值），只差一个 `t`。
   *
   * @param progress 0 = 迷你条封面，1 = 播放页封面（静止态实测矩形）
   */
  private morphCoverRectAt(progress: number): LyricMorphRect {
    // ★★ 2026-10-15 **回退"页内坐标逆变换"**：真机实测那样做会把封面画到左上角
    //   （说明 `.scale()` 的枢轴不是容器中心，我的换算前提不成立）。
    //   现在回到"**窗口坐标直线插值**"——淡入淡出版里就是这样，用户实测"封面是正常的"：
    //   两端在 p=0 / p=1 都对（p=1 时窗口坐标 = 页内坐标），中间段是近似但观感正常。
    //   ⚠️ 所以它**必须一直飞到 p=1**（见 `morphBridging()` 里的说明），不要提前交棒。
    const t: number = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
    // ⚠️ **直线插值**（对标反编译 `MiniMorph`：中心/边长各一条 `lerpN`）：
    //    `coverCenterXAt/YAt(t)`、`coverVisualEdgeAt(t)`、`coverVisualRadiusAt(t)`。
    //    ⚠️ 之前我拿"容器变换后的当前帧矩形"当终点，于是起点那一段终点会**往下跑**
    //    （容器缩放中心 + 位移在 p 小时把目标拽到屏幕下方）—— 用户实测的
    //    "封面先往下再往上"就是这个。直线插值两端都是**静止态的真实矩形**，不会拐弯。
    // ★ 终点尺寸要乘上**实时**的封面视觉缩放：存下来的是"布局矩形 × 量测时的缩放"，
    //   而真实封面此刻是 ×(播放 1.05 / 暂停 0.95)。不乘回来，p=1 交棒就跳那 5%
    //   （用户实测的"结束时封面大小跳一下"）。
    // Freeze the visual endpoint once per session, never chase a spring/scale frame.
    const s: number = this.bigNodeKnown ? this.bigNodeScaleX : this.coverVisualScale();
    const endSize: number = this.endCoverSize * s;
    const endH: number = (this.endCoverH > 0 ? this.endCoverH : this.endCoverSize) * s;
    const coverR: number = this.bigCoverRadius > 0 ? this.bigCoverRadius :
      (this.bigRadius > 0 ? this.bigRadius : endSize * 0.06);
    const endRadius: number = Math.min(coverR * s, Math.min(endSize, endH) / 2);
    const startRadius: number = Math.min(this.snapStartRadius, this.snapStartW / 2);
    // 终点是**按尺寸缩放**的：位置随中心不变、边长乘 s —— 与真实封面的
    // `scale({centerX:'50%',centerY:'50%'})` 完全同口径。
    const endX: number = this.endCoverX + (this.endCoverSize - endSize) / 2;
    const endY: number = this.endCoverY + (this.endCoverH - endH) / 2;
    return {
      x: this.snapStartX + (endX - this.snapStartX) * t,
      y: this.snapStartY + (endY - this.snapStartY) * t,
      size: this.snapStartW + (endSize - this.snapStartW) * t,
      height: this.snapStartW + (endH - this.snapStartW) * t,
      radius: startRadius + (endRadius - startRadius) * t
    };
  }

  // ═══════════ 壳层浮层拷贝（对标无界 `MainPage.MorphOverlayHost` 里的 `morphCover`）═══════════
  //
  // 结构（**两层**，两个进度各自到点）：
  //   · 下 层 = 播放页自己：`morphP` 驱动的整页 scale/translate/clip，**350ms `Curve.EaseInOut`**
  //     （调用点没动：`PlaybackPage.MORPH_OPEN_DURATION_MS`）；
  //   · 上 层 = **壳层浮层**（`products/default .../Index.ets` 的 `MorphCoverClone()`）：
  //     `morphOverlayP` 驱动，**560ms + `curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)`**。
  //
  // 为什么浮层那份要单独一个进度：它**不在播放页的形变容器里**（不受 scale/translate/clip 影响，
  // 直接按窗口坐标摆在壳层的满屏 Stack 上），所以它可以是完全不同的一条时间线；
  // 对齐无界之后观感就是"封面横穿屏幕飞过去"而不是"整页从迷你条位置长大"。

  /** @returns 浮层拷贝的进度（夹紧到 0…1）。 */
  public morphOverlayProgress(): number {
    const p: number = this.morphOverlayP;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }

  /**
   * @returns 壳层浮层那份续飞封面的矩形（vp，**窗口坐标**）。
   *
   * 进度 = `morphOverlayP`（560ms 那层），与 `morphCoverBridge()`（播放页那份，进度 = `morphP`）
   * **共用同一段纯几何**（`morphCoverRectAt`），只是插值参数不同。
   * ⚠️ 壳层直接拿它当 `.position()` / `.width()` 用，**不做任何"页内 ↔ 窗口"换算**。
   */
  public morphOverlayCoverBridge(): LyricMorphRect {
    return this.morphCoverRectAt(this.morphOverlayProgress());
  }

  /**
   * @returns 壳层浮层要不要画这份封面拷贝。
   *
   * 两个条件：
   *   1. `morphBridging()` —— 与播放页那一棒**完全同一把门**（相位/两端矩形的既有判据一个字没改）；
   *   2. `hostsMorphOverlay()` —— 宿主壳层这次是不是真的接管了这一棒（PC 壳层还没接 ⇒ 不画，
   *      否则会出现"播放页也不画、浮层也不画"的**无封面**空档）。
   *
   * ⚠️ **2026-10-15 订正**：这里原来写着"浮层这一棒**早于**播放页落位（560 vs 350）"——
   *   **说反了**，560 > 320，浮层是**晚**的那一条。正因为写反了，才漏掉了
   *   "播放页落位时把浮层掐断"这个 bug（见下面第二个判据的注释）。
   */
  public morphOverlayBridging(): boolean {
    // ★★★ 2026-10-16（**恢复**；我上一版把它恒置 `false`，那是个错误）
    //
    // ## 为什么必须恢复：这才叫"照搬无界的封面"
    //
    // 无界的封面是**一镜到底**，而它靠的是**封面画在一个没有额外变换的浮层里**、
    // 用**窗口坐标插值**飞过去（`CoverMorph` 全程不查任何节点、也不受 `playerPane`
    // 那套 scale/translate 影响）。
    // 我们这一侧**本来就有同构的一层**：`products/default/.../Index.ets` 的
    // `MorphCoverClone()` —— 它与播放页形变容器**同级**（在壳层满屏 `Stack` 上），
    // 拿 `morphOverlayCoverBridge()`（= `morphCoverRectAt(morphOverlayP)`，窗口坐标）
    // 直接当 `.position()` 用。**这一层在真机上是好的**（用户此前验收过"封面正常"）。
    //
    // 我上一版关掉它、改让播放页里那张真封面独自承担，结果是：真封面挂在**被 scale 变换过**
    // 的形变容器里，而容器形变中"贴在屏幕顶部那一条"（`morphTy ≈ +844`、`scale ≈ 0.082`）
    // ⇒ 基准位的封面被搬到**屏幕顶部**、而迷你条在**屏幕底部** ⇒ 观感成了
    // 「**封面从下往上飞**」（用户 2026-10-16 实测）。
    //
    // ⇒ 恢复"浮层画、真封面让位"这套交棒。**这才是无界的结构。**
    // ⚠️ 那两条"交棒固有毛病"（两条补间不同钟 / 真封面窗口坐标被变换拉偏）**是真的**，
    //   但它们已经被下面三条判据兜住了（见第二个判据的注释）——**不要**因为那两条就再关一次。
    // ⚠️ `metaBridgeOwnsPaint()` 仍然恒 `false`（歌名/歌手**不**跟着飞，用户明确要求过），
    //   两者不冲突：浮层这一层在本仓**只画封面**（`MorphCoverClone` 里只有一张 `Image`）。
    if (!this.hostsMorphOverlay()) {
      return false;
    }
    if (this.morphBridging()) {
      return true;
    }
    // ★★ 2026-10-15（照搬无界「两层各跑各的、互不打断」）：
    //   播放页落位之后**不要**立刻撤掉浮层。
    //
    //   实测时序（都在这份代码里）：
    //     · 播放页那条 = `Index.settlePullOpen` 的 `PULL_OPEN_SETTLE_MS + 20`
    //       ⇒ **320ms** 就 `morphSettleOpen()`，`morphBridging()` 随之变假；
    //     · 浮层那条   = `MORPH_OVERLAY_DURATION_MS(560)`。
    //   ⇒ 原来浮层在 320/560 ≈ **57% 处被撤掉**，观感就是"落位那一帧封面跳一下"
    //      （无界没有这个毛病：它的内层与浮层是**两条独立补间**，谁先到谁先停，不互相取消）。
    //
    //   判据改成"**浮层自己还在半路就继续画**"：
    //     · 展开跑到 p = 1、收起跑到 p = 0 才停笔；
    //     · 静止态不会多画一张（展开态 p = 1、收起态 p = 0，两端都被排除）；
    //     · 与 `morphBridging()` 是**或**关系，所以起手那一帧（p 恰好为 0）仍由它兜住，
    //       不会出现"两边都不画"的空档。
    const p: number = this.morphOverlayProgress();
    if (p > 0.001 && p < 0.999) {
      return true;
    }
    // ★★ 2026-10-15（修用户实测「**下拉关闭时封面动画变成展开那一套**」/「**系统返回关闭没有封面动画**」）：
    //   上面那条"浮层自己还在半路"的判据有一个**方向性漏洞** —— 它只看 `morphOverlayP`。
    //   而收起路上最容易出现的情况恰恰是"两条补间同起同落、浮层进度在**同一帧**就被
    //   播放页那条落位链路清回 0"（`morphLand()` → `releaseMorphOwnership` → `morphReset()`），
    //   那一刻 `p` 已经等于 0 ⇒ 本函数返回 false ⇒ **封面临到落位前被掐掉**：
    //     · 用户看到的就是"封面没有按收起那一套缩回迷你条"（等于没有封面动画）；
    //     · 而播放页那一层仍在 460ms 里缩放，于是"看起来像展开那一套"。
    //   ⇒ 补一条**与进度无关、只看相位**的兜底：只要形变容器还活着
    //     （ENTERING / LEAVING / LANDING），这一棒就**必须继续画**。
    //     静止态（OPEN / NONE）仍然不画 ⇒ 不会多留一张封面。
    //   ⚠️ 与 `morphBridging()` 仍是"或"关系：几何没量齐（`snapStartW/endCoverSize` 为 0）时
    //      本函数也画不出来（矩形式子全是 0），所以不会画出"0×0 的封面"。
    return this.morphContainerActive() && this.snapStartW > 0 && this.endCoverSize > 0;
  }

  /**
   * @returns 形变容器的**自身尺寸**（vp，窗口坐标口径）—— 只给 {@link coverLocalRectFor} 做反变换用。
   *
   * 容器是"整宽 + 裁剪窗口高"（`PlaybackPage.build()` 里 `.height(morphClipHeight())`）：
   * 形变中高度 = `morphClipHeight`，静止态 = 窗口高。
   * ⚠️ 这两个量与 `applyMorphProgress()` 里算 `morphTx/morphTy` 用的是**同一组输入**
   *   （`morphBoxWidth/Height` 那一档），改一处必须改另一处，否则反变换会差一截。
   */
  private coverHostW(): number {
    // 容器是 `.width('100%')`（= 宿主满屏宽）⇒ 直接取窗口宽。
    // ⚠️ **不要**用 `morphBoxWidth()`：那个是"被量到的内容宽"（`contentWidthVp`），
    //   与容器自己的布局宽不是同一个量，混用会让反变换横向差一截。
    return this.windowWidthVp;
  }

  private coverHostH(): number {
    if (this.morphClipping() && this.morphClipHeight > 0) {
      return this.morphClipHeight;
    }
    return this.windowHeightVp;
  }

  /**
   * 把**屏幕坐标**的封面矩形，换算成形变容器**本地**的 `.position()` / `.width()` 值。
   *
   * @deprecated **零调用者，且方法本身在真机上被证伪过 —— 不要接上它。**
   *
   * ## 为什么留着它（而不是删掉）
   *
   * 它的推导本身是**对的**（就是容器变换 `y_屏 = H/2 + (y_本 − H/2)s + d` 的逆），
   * 但它依赖一个**在本仓不成立的前提**：`.scale()` 绕**容器中心**。
   *
   * 真机反证（本仓有两次独立记录）：
   * · `morphCoverRectAt()` 的注释：逆变换回页内坐标 ⇒ 真机结果"**封面跑到左上角**"
   *   （说明 `.scale()` 的枢轴不是我以为的容器中心）；
   * · 2026-10-16 `PlaybackPage.coverLocalRect()`：我原地重踩一遍，用户实测
   *   「**封面是飞到屏幕外**」⇒ 再次证明该前提不成立。
   *
   * ⇒ 现在的做法是 `PlaybackPage.coverLocalRect()` **直接返回 `lyricFloatRect()`**
   *   （纯几何、零换算）。留这个函数是为了下次有人想"逆变换一下"时，
   *   能先看到**两次真机反证**再决定，而不是第三次重踩。
   */
  public coverLocalRectFor(screen: LyricMorphRect): LyricMorphRect {
    const s: number = Math.max(0.05, this.morphScale);
    const w: number = this.coverHostW();
    const h: number = this.coverHostH();
    const tx: number = this.morphTx;
    const ty: number = this.morphTy;
    return {
      x: w / 2 + (screen.x - w / 2 - tx) / s,
      y: h / 2 + (screen.y - h / 2 - ty) / s,
      size: screen.size / s,
      height: screen.height / s,
      radius: screen.radius / s
    };
  }

  /** @returns 浮层拷贝的不透明度（与播放页那份同口径：画的时候恒 1）。 */
  public morphOverlayBridgeOpacity(): number {
    return this.morphOverlayBridging() ? 1 : 0;
  }

  /**
   * @returns 当前 shell 是否自己重绘了续飞封面（= 播放页应**停用**自己的 `MorphCoverBridge`）。
   *
   * 判据用**设备类型**（`2in1` = PC/平板笔电形态）：本轮的浮层只落在 `products/default`
   * 壳层，PC 壳层（`products/pc/.../Index.ets`）没有 `MorphMiniBarClone`，也没接这份浮层 ⇒
   * 在 PC 上**继续由播放页自己画**（行为与改动前逐字一致），避免"两边都不画"。
   *
   * ⚠️ 这段是**临时脚手架**：等浮层也落到 PC 壳层后，把这里改成常量 `true`
   *   （或直接删掉这个函数与它的调用点）。
   */
  public hostsMorphOverlay(): boolean {
    // ⚠️ 结果要**缓存**：这个函数在渲染门里被逐帧调用（`MorphCoverClone` 那个 `if`），
    //    而 `deviceInfo.deviceType` 是系统属性读取，不该每帧问一次。
    //    设备类型一次运行内不会变，缓存是安全的。
    if (this.morphOverlayHostCached < 0) {
      try {
        this.morphOverlayHostCached = deviceInfo.deviceType !== '2in1' ? 1 : 0;
      } catch (err) {
        // 取不到设备类型时按"播放页自己画"处理：宁可多一层也不要一张都没有
        Logger.warn(PlayerExpandState.logTag, `hostsMorphOverlay: deviceType unavailable ${err}`);
        this.morphOverlayHostCached = 0;
      }
    }
    return this.morphOverlayHostCached === 1;
  }

  /**
   * 会话开始/复位：把浮层进度压回起点并中断它自己的补间。
   *
   * ⚠️ 起手那**一帧**很关键：`morphOverlayP` 的初值是 1（静止态语义），若不压回 0，
   * 浮层的第一帧就会画成大封面（观感是"闪一下大图"）。
   */
  public morphOverlayReset(): void {
    this.morphOverlayGen = this.morphOverlayGen + 1;
    this.morphOverlayAnimating = false;
    // ★ 会话边界：把"本轮收起已被起过"的标记也放掉，否则下一次收起会静默跳过浮层那一棒
    this.morphOverlayCollapseOwned = false;
    this.morphOverlayP = 0;
    Logger.info(PlayerExpandState.logTag,
      `morph overlay reset gen=${this.morphOverlayGen} overlayP=0`);
  }

  /**
   * 跟手期间把浮层进度与播放页进度**一比一同步**（不跑任何补间）。
   *
   * 手指那条路上两层必须是同一个值，否则松手时会"补"一下（一小段瞬移）。
   * 补间路（`morphOverlayTweenTo`）不走这里：那条路上两层刻意不同步（这才是两层的意义）。
   */
  public syncMorphOverlayFromPage(): void {
    if (this.morphOverlayAnimating) {
      return;
    }
    this.morphOverlayP = this.morphP;
  }

  /**
   * 播放页侧开始**展开**补间了 ⇒ 壳层浮层也起自己的 560ms 那一版。
   *
   * ⚠️ 为什么由**壳层**调（`@Monitor('expandState.morphDrive')`）、而不是让播放页调：
   *   浮层与它那份进度整个属于壳层（`products/default .../Index.ets`），
   *   `@Monitor` 是 V2 的**异步监听**，回调发生在播放页那次状态写入的**同一轮**
   *   ⇒ 两层算"同起"，而播放页那 350ms 的代码**一行都不用动**。
   *   排查关键字：`grep RzdMorphOverlay`（`page-intro` / `page-collapse` / `shell-settle` 三行）。
   * @param ui 壳层的 UIContext（补间必须在它上面起）
   */
  public focusMorphOverlayForPageIntro(ui: UIContext): void {
    if (!this.hostsMorphOverlay()) {
      return;
    }
    if (this.morphDrive !== MorphDrive.ANIM || !this.morphContainerActive()) {
      return;
    }
    Logger.info(PlayerExpandState.logTag,
      `morph overlay page-intro from=${this.morphOverlayP.toFixed(3)} gen=${this.morphGen}`);
    // 进入方向一开跑，就把"本轮收起已被起过"的标记放掉：同一轮会话内先后经历
    // "展开 → 收起"时不会被上一次的护栏挡住（护栏的语义是"同一方向只许起一次"）。
    this.morphOverlayCollapseOwned = false;
    this.morphOverlayTweenTo(true, ui);
  }

  /**
   * 播放页侧开始**收起**了 ⇒ 浮层也跟着回起点（走它自己的 460ms）。
   *
   * ⚠️ **幂等护栏**（2026-10-15）：本函数现在有**两个**调用点 ——
   *   · 播放页的 `closeFullScreenPlayback()`（**同步**，起补间之前，这是权威调用点）；
   *   · 壳层的 `@Monitor('expandState.morphStage')`（**异步**，兜住"相位被别人改成 LEAVING"
   *     那种路径，比如迷你条/壳层自己发起的收起）。
   *   两个都跑就会**各起一条** `animateTo`：后起的那条会把先起的那条覆盖掉，
   *   而它的 `from` 已经是"刚走了几毫秒的进度" ⇒ 观感是封面回飞**卡一下**。
   *   ⇒ 用 `morphOverlayCollapseOwned` 做"本轮收起只许起一次"的标记；
   *     它由 {@link morphOverlayReset}（会话结束）唯一清掉。
   * @param ui 壳层的 UIContext
   */
  public focusMorphOverlayForPageCollapse(ui: UIContext): void {
    if (!this.hostsMorphOverlay()) {
      return;
    }
    if (this.morphOverlayCollapseOwned) {
      Logger.info(PlayerExpandState.logTag,
        `morph overlay page-collapse skipped (owned) overlayP=${this.morphOverlayP.toFixed(3)} gen=${this.morphGen}`);
      return;
    }
    if (this.morphOverlayAnimating) {
      // 补间正在跑（例如壳层 `settlePullOpen` 起的那条方向一致的）：不要抢
      Logger.info(PlayerExpandState.logTag,
        `morph overlay page-collapse skipped (animating) overlayP=${this.morphOverlayP.toFixed(3)} gen=${this.morphGen}`);
      return;
    }
    this.morphOverlayCollapseOwned = true;
    Logger.info(PlayerExpandState.logTag,
      `morph overlay page-collapse from=${this.morphOverlayP.toFixed(3)} gen=${this.morphGen}`);
    this.morphOverlayTweenTo(false, ui);
  }

  /**
   * 浮层拷贝的补间（**唯一一处** `animateTo`）。
   *
   * 起点 = 当前浮层进度（可能是手指停在中间、也可能是上一次补间的中间态），
   * 终点 = `progress`；时长 560ms、曲线 `cubic-bezier(0.23, 1.0, 0.32, 1.0)`（快出慢收）。
   * 世代号保证"新补间/复位"之后旧回调直接丢弃。
   *
   * ⚠️ **两个方向共用这一套时长/曲线是刻意的**（无界收起方向另有一说 `460` +
   *   `"cubic-bezier(0.85, 0, 0.5, 0.88)"`）—— 为什么不照搬、以及那个"12% 尾跳"的算式，
   *   见上面 `MORPH_OVERLAY_DURATION_MS` 后面那段说明。**别只改这里的 `duration`。**
   * @param progress true = 展开到 1；false = 收回 0
   * @param ui 起补间用的 UIContext
   */
  public morphOverlayTweenTo(progress: boolean, ui: UIContext): void {
    this.morphOverlayGen = this.morphOverlayGen + 1;
    const gen: number = this.morphOverlayGen;
    const from: number = this.morphOverlayProgress();
    const to: number = progress ? 1 : 0;
    if (Math.abs(to - from) < 0.0001) {
      // 已经在终点：不起补间（避免每次进播放页都白跑一段 560ms 的空动画）
      this.morphOverlayAnimating = false;
      this.morphOverlayP = to;
      return;
    }
    if (ui === undefined) {
      // 拿不到 UIContext：直接落位。**绝不能整段跳过** —— 否则浮层会停在中途不落位。
      Logger.warn(PlayerExpandState.logTag,
        `morph overlay tween no UIContext, jump from=${from.toFixed(3)} to=${to}`);
      this.morphOverlayAnimating = false;
      this.morphOverlayP = to;
      return;
    }
    // 起补间之前先把"起点"同步标脏（与 `PlaybackPage.playMorphOpenIntro` 同一条官方口径：
    // V2 状态是**异步标脏**、而 `animateTo` 会立刻刷新已标脏节点来决定首帧）。
    // 这里不需要 `UIUtils.applySync`：浮层的起点就是字段当前值，animateTo 的闭包只写终点。
    this.morphOverlayAnimating = true;
    // ★★ 2026-10-15（Round 27）：时长/曲线**按方向分开**，收起方向与播放页**同一条公式**。
    //   收起：`round(460 × max(0.4, from))` —— `from` 就是浮层起手时的当前进度，
    //   与播放页 `closeFullScreenPlayback` 里用的 `morphP` 是**同一个量**（两层本就同步推进）
    //   ⇒ 两层同起同落，"尾跳"从根上不可能出现。进入：维持 560（不变）。
    const overlayMs: number = progress ? PlayerExpandState.MORPH_OVERLAY_DURATION_MS
      : Math.round(PlayerExpandState.MORPH_OVERLAY_REVERSE_MS *
        (from < PlayerExpandState.MORPH_OVERLAY_REVERSE_MIN_RATIO
          ? PlayerExpandState.MORPH_OVERLAY_REVERSE_MIN_RATIO : from));
    Logger.info(PlayerExpandState.logTag,
      `morph overlay tween start from=${from.toFixed(3)} to=${to} ` +
        `ms=${overlayMs} dir=${progress ? 'enter(560+EASE_OUT_STR)' : 'reverse(460*max(0.4,from)+REVERSE_EASING)'} ` +
        `gen=${gen}`);
    ui.animateTo({
      duration: overlayMs,
      // ★ 浮层这一层**单独**的时长/曲线：
      //   进入 = 无界 `ENTER_MS(560)` + `EASE_OUT_STR`；
      //   收起 = 无界 `MainPage.animateMorphT(reverseMs, 0, REVERSE_EASING)`
      //          （`reverseMs = 460 × max(0.4, morphT)`、`REVERSE_EASING = (0.85,0,0.5,0.88)`）
      //          —— 与播放页那一层**逐字同源**，所以两层不会不同步。
      //   ⚠️ 曲线内联写在这里，别抽成返回 `ICurve`/`UIShape` 的包装函数（那两个类型在本机 SDK
      //      里都不是全局可见的，见文件顶部 `MORPH_OVERLAY_DURATION_MS` 旁边那段说明）。
      curve: progress
        ? curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)
        : curves.cubicBezierCurve(0.85, 0, 0.5, 0.88)
    }, (): void => {
      // ⚠️ 目标值**直接写字段**，不要走 `syncMorphOverlayFromPage()`：那个会被
      //    `morphOverlayAnimating` 挡掉（此时它为 true），写不进去就等于没动画。
      this.morphOverlayP = to;
    });
    setTimeout((): void => {
      if (gen !== this.morphOverlayGen) {
        // 已被新补间/复位取代：什么都别动
        return;
      }
      this.morphOverlayAnimating = false;
      this.morphOverlayP = to;
      Logger.info(PlayerExpandState.logTag, `morph overlay tween done overlayP=${to} gen=${gen}`);
    }, PlayerExpandState.MORPH_OVERLAY_DURATION_MS + 20);
  }

  /**
   * 量一个组件的窗口矩形（vp）。
   *
   * 这就是反编译侧 `ComponentRect.getRectByFrameNode` 的做法：
   * `getFrameNodeById` → `getPositionToWindowWithTransform()`（vp）+ `getMeasuredSize()`（px→vp）。
   * 用 FrameNode 而不是 `getComponentUtils().getRectangleById`：前者是**渲染后**的位置
   * （含祖先 transform），后者之前在 HDS 浮动底栏上量出来是偏的。
   *
   * ★★★ 2026-10-17（**回原始字节码复核测量这一层** —— 三条结论，别再重复查）
   *
   * **(a) 上游**有**两个**测量助手，语义不同，别混**（`ComponentRect.ets`）：
   * ```
   *   getRectByFrameNode(id)  = getPositionToWindow**WithTransform** + getMeasuredSize   ← 含变换的位置
   *   getRectById(id)         = getRectangleById(...) + **一个 scale 修正**
   * ```
   * 那个修正是这一份（`wujie.pa:50532` 起，逐条解出来）：
   * ```ts
   *   const halfW = info.size.width  * (1 - info.scale.x) / 2;   // ★ 绕中心缩放 ⇒ 左边界往里收半个差
   *   const halfH = info.size.height * (1 - info.scale.y) / 2;
   *   rect.left   = info.translate.x + info.screenOffset.x + halfW;
   *   rect.top    = info.translate.y + info.screenOffset.y + halfH;
   *   rect.right  = info.translate.x + info.screenOffset.x + info.size.width  - halfW;
   *   rect.bottom = info.translate.y + info.screenOffset.y + info.size.height - halfH;
   * ```
   *   ⇒ **因为 `getMeasuredSize()` 给的是"布局尺寸"（不含 scale），而含变换的位置把 scale 算进去了**
   *     ⇒ 不做这个修正，"位置"与"尺寸"就**不是同一个坐标系**。
   *
   * **(b) 本仓的对应关系**：本函数就是 (a) 里的 `getRectByFrameNode`
   *   （`naturalLayout=false` ⇒ 含变换的位置 + 布局尺寸），
   *   **并且**我们给可缩放的那个消费者（播放页大封面）走了 `naturalLayout=true`
   *   （`measureEndAnchor` 用 `getPositionToWindow()` = 不含变换 ⇒ 与"布局尺寸"自洽 ✓），
   *   另把缩放**单独存**（`bigNodeScaleX/Y`）在绘制时乘回去 —— 与上游"把 scale 除掉再乘回来"同源。
   *   ⚠️ 所以**没有**照搬 (a) 那个 `halfW/halfH` 是**有意的**：我们的调用点要么不带 scale，
   *     要么已经换成 `naturalLayout=true` 这条自洽路径。
   *
   * **(c) 唯一可能踩到的地方（记下来，别当不知道）**：**迷你条胶囊**（`measureGeometry` 里
   *   `measureNode(ui, MINI_BAR_*)`，走的是含变换的默认路径）在
   *   **落位挤压弹簧**（迷你条的 `.scale({y: morphSquashY})`，0.86→1 共 430ms）**正在跑**时被量到，
   *   它的 `y` 会带上 `h×(1−0.86)/2 ≈ 3.9vp` 的偏移，而 `h` 仍是未缩放的布局高 ⇒ 差 ~4vp。
   *   实测上**基本踩不到**：胶囊只在"打开起手 / 关闭起手"被量，而那两刻弹簧早已归位
   *   （挤压只在关闭落位后 430ms 内偏离 1）。
   *   ⇒ 若将来出现"某次打开时封面/背景起点整体偏几 vp"，**先查这里**（读数：徽标第二行
   *     `snap=`/`end=`、第十三行的 `CLO:… bar=WxH`）。
   *
   * **(d) 上游 `MainPage.visualRect(…, baseRect)`（"视觉矩形修正"）—— 结论：本仓**无法照搬**，
   * 不写是**有意的**，别再当前置任务挂在那儿。** 原始字节码
   * （`_recover/disasm/wujie.pa:143042`，94~95 条指令，逐条解完）逻辑是：
   * ```ts
   *   const vis = getRectById(…);                  // ← 需要**另一个**测量来源（含 scale 修正那条）
   *   if (vis === undefined)                       { return baseRect; }   // 量不到 ⇒ 原样返回
   *   if (baseRect.width <= 0)                     { return baseRect; }
   *   const k = vis.width / baseRect.width;
   *   if (k <= 0)                                  { return baseRect; }
   *   if (Math.abs(k - 1) < 0.01)                  { return baseRect; }   // ★ 自带"分歧 <1% 就不修"护栏
   *   const out = new RectInPx();                  // 注意：位置取 base、尺寸取 k 倍
   *   out.left = baseRect.left;  out.top = baseRect.top;
   *   out.width  = baseRect.width  * k;            // = vis.width
   *   out.height = baseRect.height * k;
   *   out.right = out.left + out.width;  out.bottom = out.top + out.height;
   *   return out;
   * ```
   * ⇒ **要照搬就必须在"同一次测量里"同时拿到 `getRectById(...)`**，而
   * `getRectangleById` 在 HDS 浮动底栏上量出来的值本身是偏的（见本函数开头）
   * ⇒ 我们没有可信的同轮次第二来源；**硬凑一个只会是自创数值**（违反"照搬"红线）。
   * ⇒ 我们真正的等价物是 (b) 那条：`naturalLayout` + 单独保存的 `bigNodeScaleX/Y`
   * —— 用**自洽的口径**代替"两个来源互相校正"，比照搬更稳。
   * ⇒ ★ 顺带确证：**上游自己认为"两个来源差 <1% 就不必修"**（那条 `1e-2` 护栏）
   * ⇒ 我们测量链上 `<1%` 的出入**不是 bug**，不要为它改公式。
   * @param ui UIContext
   * @param id 组件 id
   * @param naturalLayout true = 用**不含变换**的 `getPositionToWindow()`（与"布局尺寸"自洽；
   *        给**带 scale 的节点**用；上游对应 `getRectByFrameNode`）
   * @returns 窗口矩形；量不到返回 undefined
   */
  private measureNode(ui: UIContext, id: string, naturalLayout: boolean = false): NodeRect | undefined {
    if (id.length === 0) {
      return undefined;
    }
    try {
      const node = ui.getFrameNodeById(id);
      if (node === null) {
        return undefined;
      }
      const pos: Position = naturalLayout ? node.getPositionToWindow() : node.getPositionToWindowWithTransform();
      const size: Size = node.getMeasuredSize();
      const w: number = ui.px2vp(size.width);
      const h: number = ui.px2vp(size.height);
      if (w <= 0 || h <= 0) {
        return undefined;
      }
      // `Position.x/y` 的静态类型是 `Length`，用现成的收窄函数取成 vp
      return { x: areaLengthToVp(pos.x), y: areaLengthToVp(pos.y), w: w, h: h };
    } catch (err) {
      Logger.warn(PlayerExpandState.logTag, `measureNode('${id}') failed: ${err}`);
      return undefined;
    }
  }

  /**
   * @returns 整页不透明度：0（还在迷你条那一小块、不可见）→ 1（完全铺开）。
   *
   * ★★ 2026-10-15（**已判定为死代码**，`RzdMusic记忆.md` §59）：**零调用者** ——
   *   只有 `products/default/.../Index.ets` 的**注释**里提到它（L837 / L1431），代码里没调。
   * ⚠️ 这一条比同族的其他几个更值得记一笔：**注释把它说成"活的"**，
   *    读注释的人会以为"播放页在形变早期是淡入的"。实际不是 —— 播放页是**半透明画出来**的
   *    （绘制的观感由"整页缩放 + 裁剪窗口 + 背景层 `backgroundRevealOpacity`"三者共同决定），
   *    而整页并没有一个 `.opacity(morphPageOpacity())`。
   * ⇒ 两条出路，都需要真机判观感，所以本轮**只标注、不改**：
   *   （a）接上它（加一次整页淡入）—— 会改变观感，且与"不要淡入淡出"的用户定调可能冲突；
   *   （b）把那段注释改掉（说清"没有整页淡入"）—— 零风险，但属于文档整理。
   * @deprecated 零调用者。
   * 复核命令：`grep -rn 'morphPageOpacity' RzdMusic --include=*.ets`（期望：只有注释命中）
   */
  public morphPageOpacity(): number {
    if (!this.morphUsable) {
      return 1;
    }
    // LANDING = 已经交还给迷你条（对标 `playerPaintsOf = false`）：这一帧起播放页
    // **不再画**，否则会在迷你条封面上留一个同尺寸的深色小方块，直到被卸载。
    if (this.morphStage === MorphStage.LANDING) {
      return 0;
    }
    if (this.morphStage !== MorphStage.ENTERING && this.morphStage !== MorphStage.LEAVING) {
      return 1;
    }
    // ⚠️ 必须**早于**迷你条的淡出（`miniBarOpacity`，0～20%）走完：
    //    两边都在淡的时候中间会出现"半透明的迷你条 + 半透明的播放页"，
    //    叠起来是块发灰的糊斑。这里 12% 就到位，之后由播放页那层接管。
    return Math.min(1, this.morphP / 0.12);
  }

  /**
   * @returns 迷你条的淡出系数（对标 `MiniMorph.actionsOpacityAt = clamp(1 - t/0.20)`）。
   *
   * ⚠️ 反编译里迷你条有**两档**淡出：**操作区（右侧按钮）0.20 先消失**、
   * **元信息（歌名/歌手）0.35 后消失** —— 做出来就是"按钮先没、文字后没"。
   * 这条是操作区那一档，用在 `*Aside`（按钮）上。
   */
  public miniBarOpacity(): number {
    if (!this.morphUsable) {
      return 1;
    }
    if (this.morphStage !== MorphStage.ENTERING && this.morphStage !== MorphStage.LEAVING) {
      return 1;
    }
    const p: number = this.morphP < 0 ? 0 : (this.morphP > 1 ? 1 : this.morphP);
    const a: number = 1 - p / 0.20;
    return a < 0 ? 0 : a;
  }

  /**
   * @returns 迷你条**元信息**（歌名/歌手、以及封面那一块）的淡出系数。
   *
   * 对标 `MiniMorph.metaOpacityAt = clamp(1 - t/0.35)`：比操作区晚消失，
   * 于是观感是"按钮先没、文字后没"（用户实测的描述）。
   */
  public miniBarMetaOpacity(): number {
    if (!this.morphUsable) {
      return 1;
    }
    if (this.morphStage !== MorphStage.ENTERING && this.morphStage !== MorphStage.LEAVING) {
      return 1;
    }
    const p: number = this.morphP < 0 ? 0 : (this.morphP > 1 ? 1 : this.morphP);
    const a: number = 1 - p / 0.35;
    return a < 0 ? 0 : a;
  }

  /**
   * 跟手/动画推进：把 `progress`(0…1) 落到"缩放容器"的几何上。
   *
   * **只有几何运算，不含任何定时** —— 跟手阶段由手指调、收尾由调用方的 animateTo 调。
   *
   * ⚠️ 这一版回到"整页缩放 + 竖直裁剪窗口"（第五版），原因是第五版之前的
   *   "贴底窗口 + 内容等比缩放居中"虽然结构上没有了底部空档，但内容层**比窗口小**，
   *   屏上就是"一块底色窗口 + 中间一个缩小的播放页"（用户实测："黑窗口，中间是播放器"）。
   *   这一版让**可视矩形与内容层严格同尺寸**：内容永远填满可视矩形，不存在留白。
   *
   * 三条不变量：
   *   1. 可视矩形四边各自插值：左/上 → 0、右/下 → 宿主尺寸；**起点 = 迷你条那条胶囊**
   *      （用户要的"整个播放条延伸铺开"），下边在前 25% 先贴到宿主底边（否则底部那
   *      几十 vp 整段动画都空着）；
   *   2. 内容层高度 = 裁剪高度 = 可视高度 / 缩放 ⇒ 可视矩形里**正好**是整页，
   *      没有留白、也没有裁切；
   *   3. 内容层等可视矩形接近整屏（宽高比接近页面）才浮现，避免中段看到被压扁的页面。
   * @param p 0 = 迷你条那条胶囊，1 = 满屏
   */
  public applyMorphProgress(p: number): void {
    const t: number = p < 0 ? 0 : (p > 1 ? 1 : p);
    this.morphP = t;
    // ★★ 2026-10-15（**删除了"非形变期自动复位浮层"那一段**，依据见本条）：
    //   原来是 `if (!morphContainerActive()) { this.morphOverlayReset(); }` ——
    //   本意是兜住"异常路径直接落位/卸载"，但它同时**吃掉了正常收起路上的那一棒**：
    //   `closeFullScreenPlayback()` 的补间目标是 `applyMorphProgress(0)`，而
    //   `morphLand()`（LANDING）与 `morphReset()`（NONE）都会在**同一批任务**里再调一次
    //   `applyMorphProgress(1)` / 直接复位 ⇒ 浮层进度被**瞬间**清回 0，
    //   封面的回飞在最后一段被掐断 —— 用户实测的「关闭时封面动画不对 / 没有封面动画」。
    //   ⚠️ 现在复位只由两处**显式**负责，语义清晰且都在会话边界上：
    //     · `morphReset()`（会话结束 / 卸载）—— 里面已经调了 `morphOverlayReset()`；
    //     · 起手那一帧由壳层/迷你条显式压 0（`onPullOpenStart` / `settlePullOpen`）。
    //   渲染门（`morphOverlayBridging()`）自己保证静止态不画，所以不会残留一张封面。
    // ★★★ 2026-10-16（**照搬无界 `onPullTChanged` / `applyPullProgress` 的那道门**）：
    //   `wujie.pa` 174839-174850：
    // ```ts
    //   if (!pullGeomReady) { return; }        // ← 终点几何没量到 ⇒ 这一帧什么都不做
    //   expand.applyPullProgress(ui, effT());
    // ```
    //   **不是**"写回恒等"，而是**保持容器当前值不动**。
    //   为什么必须这样（本仓的真实断点）：点击打开 / 点击关闭 / 系统返回这三条路上，
    //   播放页在 `pullOpenBegin` 那一刻还没挂载 ⇒ 终点锚点量不到 ⇒ `morphUsable === false`
    //   ⇒ 原来这里把容器写回恒等 ⇒ **整段动画都没有**（用户实测）。
    //   改成"什么都不做"之后，容器一直停在恒等（= 与"没有这套动画"逐像素一致），
    //   直到 `measureMiniDuringPull()` 量到终点那一帧才第一次落非恒等几何 ⇒
    //   补间那一帧起生效（`animateTo` 的闭包会把终点值写进去，ArkUI 自己补间）。
    //   ⚠️ **顺序是硬约束**：这一条必须在下面 `!morphUsable` 那条**之前** ——
    //      `morphUsable === false` 正是"几何没量到"的主场景，排在它后面等于没加门。
    //   ⚠️ 恒等的兜底仍然由 `morphReset()` 承担（它显式把五个几何字段写回恒等）——
    //      那也是"会话结束"的唯一边界，比"每帧写回"精确得多。
    if (!this.morphGeomReady) {
      return;
    }
    if (!this.morphUsable) {
      // 几何没量到：不裁剪、不缩放、不透明 —— 直接当"没有这套动画"
      this.morphScale = 1;
      this.morphTx = 0;
      this.morphTy = 0;
      this.morphClipHeight = 0;
      this.morphRadius = 0;
      this.morphContentOpacity = 1;
      return;
    }
    // ─────────── 以下**逐条照抄**反编译的 `applyPullProgress` ───────────
    //   scaleValue = initScale + (1 - initScale) * t
    //   translateX = initTranslateX * (1 - t)      translateY = initTranslateY * (1 - t)
    //   clipWidth  = "100%"
    //   clipHeight = initClipHeight + (fullClipHeight - initClipHeight) * t
    // 三条都是 t 的线性函数 ⇒ **可视矩形的四条边同时线性走到屏幕四边**
    // （用户实测："整个矩形四个边是同时到达屏幕四边的"）。
    // ⚠️ 上一版我在下边加了"提前贴底"的补丁 —— 那会让下边先到、其余三边后到，
    //    正好破坏这个性质，已经删掉。
    const scale: number = this.initScale + (1 - this.initScale) * t;
    const clipHeight: number = this.initClipHeight + (this.morphBoxH - this.initClipHeight) * t;
    // 圆角：`radius = (initClipHeight*initScale/2 + delta*t) / scaleValue`，
    // 起点可视圆角 = 胶囊高度的一半（= 迷你条胶囊的圆角），终点 0。
    const visualRadius: number = this.initRadiusVisual * (1 - t);
    this.morphScale = scale;
    this.morphClipHeight = Math.max(1, clipHeight);
    this.morphTx = this.initTranslateX * (1 - t);
    this.morphTy = this.initTranslateY * (1 - t);
    this.morphRadius = scale > 0 ? visualRadius / scale : 0;
    // 内容层（封面页里的歌词/小歌词那几处）：
    // ★★ 2026-10-15（回退后重做）改成 **p 的纯函数**。
    //   原来这里是 `LEAVING ? pullBottomIn() : (t >= 1 ? 1 : 0)` —— 带**方向判断**：
    //   展开时全程 0（阶跃到落位才 1）、收起时按 [0.45,1] 线性淡。
    //   同一条 `p` 两端像素完全不同 ⇒ "展开 ≠ 收起倒放"的硬证据，也是收起时
    //   "元素先没、页面再收"的一半来源。现在按用户定调「不要淡入淡出」：
    //   恒为 1，出场完全交给位移（`earlyRiseVp` / `contentRiseVp`）与裁剪窗口。
    //   封面不在这里管：它有 `realCoverVisible()` 与 `morphBridging()` 那一对严格互补的门。
    this.morphContentOpacity = 1;
  }

  /**
   * 进入展开阶段（可跟手）。
   *
   * ⚠️ **它不再自己作废终点锚点**（2026-09-25 二次修正）。
   *
   * 上一版把 `bigNodeKnown = false` 放在这里，直接打断了一条链：
   * ```
   *   measureMini()        → 此刻页面还是原尺寸，bigNode 量到，bigNodeKnown = true
   *   morphBeginEntering() → 立刻 bigNodeKnown = false        ← 刚量到的被扔掉
   *   morphIntroAnchorsReady() → 恒 false（要求 bigNodeKnown）
   *   → 12×32ms 重试；但 morphStage 已是 ENTERING ⇒ morphLive() 为真
   *   → measureMini 里「!morphLive() 才量 bigNode」把补量永久挡死
   *   → 重试用尽 → 无动画落位。**点击打开这条路从来没进过 playMorphOpenIntro()**
   * ```
   * 现在把"作废"提到调用方，顺序由 {@link prepareMorphEntry} 固定为
   * **作废 → 在原尺寸时量 → 再压起点**（`invalidateEndAnchor()` 必须先于 `measureGeometry()`）。
   * @returns 几何是否可用：false 时调用方应改走"不形变"的兜底路径
   *          （否则会把播放页压成 1vp 的一条细缝）。
   */
  public morphBeginEntering(): boolean {
    this.morphStage = MorphStage.ENTERING;
    this.morphDrive = MorphDrive.FINGER;
    this.morphGen = this.morphGen + 1;
    this.metaBridgeGeneration = this.morphGen;
    const ok: boolean = this.morphInitParams();
    this.sourceBarHidden = ok;
    Logger.info('RzdMorphOwnership', `enter gen=${this.morphGen} sourceHidden=${ok} meta=${this.metaBridgeActive}`);
    this.applyMorphProgress(0);
    Logger.info(PlayerExpandState.logTag,
      `morph entering usable=${ok} anchorsReady=${this.morphIntroAnchorsReady()} p=0 gen=${this.morphGen}`);
    return ok;
  }

  /**
   * 作废续飞封面的**终点锚点**（`bigNodeKnown`）。
   *
   * 为什么必须作废：终点是"播放页封面**当前**的窗口矩形"，而窗口尺寸 / 断点 / Swiper 页 /
   * 播放态弹簧都可能变过；沿用几轮之前的旧矩形，就会"飞过去了却没落到封面上"。
   *
   * ⚠️ **调用顺序是硬约束**：本方法必须在 `measureGeometry()` **之前**调，
   *    否则刚量到的终点又会被抹掉（上一版就是这么把点击路径打死的）。
   */
  public invalidateEndAnchor(): void {
    this.bigNodeKnown = false;
    // ★ 2026-10-16（照搬无界）：终点作废 ⇒「几何就绪」也一并作废（`beginMorphEnter` 里
    //   `morphSeq++` 与 `morphGeomReady = false` 是同两行，`wujie.pa` 146581-146589）。
    //   否则上一轮量到的终点会被当成本轮的 ⇒ 容器按过期几何落位（"飞过去了却没落到封面上"）。
    this.morphGeomReady = false;
  }

  /**
   * 量一次"续飞封面的终点锚点"（播放页的大封面）。
   *
   * ⚠️ 与 {@link measureGeometry} 分开、且**不受 `morphLive()` 门限制**：
   *    点击展开时 `morphStage` 已经是 ENTERING（重试窗口里），但那 1~2 帧播放页
   *    **还没被压到起点**（`applyMorphProgress(0)` 只是把状态写好，真正的裁剪窗口
   *    要等下一帧渲染），此刻量到的仍是**原尺寸**的封面矩形 —— 这正是无界
   *    `setupExpandTransition` 里"先量后缩"要的那个值。
   *    重试期间反复调它是安全的：量到就守着（`morphInitParams` 会用它算终点）。
   * @param ui UIContext
   * @returns 是否量到了终点锚点
   */
  public measureEndAnchor(ui: UIContext): boolean {
    const node: NodeRect | undefined = this.measureNode(ui, PLAYER_BIG_COVER_ID, true);
    if (node === undefined || node.w <= 0) {
      return false;
    }
    // 把"布局矩形"与"施加在封面上的视觉缩放"拆开存（见 bigNodeScaleX/Y 的说明）：
    //   `getPositionToWindowWithTransform()` 已经把 scale 算进位置与尺寸了，
    //   这里除掉它，绘制桥接封面时再乘回来 —— 弹簧在动的时候两端也一致。
    const s: number = this.coverScaleLive();
    this.bigNodeScaleX = s;
    this.bigNodeScaleY = s;
    // 官方：getMeasuredSize 是布局大小（px），不含 scale；只有窗口位置含绘制变换。
    this.bigNodeW = node.w;
    this.bigNodeH = node.h;
    // Natural layout coordinates exclude both cover scale and ancestor container/chrome transforms.
    this.bigNodeX = node.x;
    this.bigNodeY = node.y;
    this.bigNodeKnown = true;
    return true;
  }

  /**
   * @returns 形变展开所需的**两个锚点**是否都真的就绪（起点 = 迷你条，终点 = 播放页封面）。
   *
   * 为什么单独判它（这是"第一次展开没有封面飞入 / 点击打开像旧动画"的关键）：
   *   · 只判"迷你条量到了、宿主管有尺寸"就开跑时，**终点锚点**（播放页封面）往往还没布局完
   *     —— `endCoverSize` 为 0 → `morphBridging()` 为 false → 全程没有封面这一棒；
   *   · 播放页那条封面副本又是"落位才现"（`morphContentOpacity`），于是头一两次展开
   *     观感就是"点开→什么都没有→啪一下到位"，和旧动画几乎分不出来。
   * 所以调用方（`PlaybackPage.playExpandIntro`）必须等这个条件成立才开始形变；
   * 等不到就继续 12×32ms 重试，用尽才无动画落位。
   */
  public morphIntroAnchorsReady(): boolean {
    // ⚠️ 判据要**同时接受两条来源**（上一版只认 `bigNodeKnown`，把点击路径判死了）：
    //   · `bigNodeKnown` —— 走 FrameNode 量到的（最准，换算过视觉缩放）；
    //   · `bigSize > 0`   —— `MusicPlayInfoBlock.reportBig()` 由 `onAreaChange` 上报的兜底值。
    //     反编译侧也会退回 `onAreaChange` 的值，而"第一次打开"时页面刚挂载、
    //     FrameNode 可能还拿不到 —— 只认前者的话这一次就必然退化。
    const endKnown: boolean = (this.bigNodeKnown && this.bigNodeW > 0) || this.bigSize > 0;
    return this.morphUsable && endKnown && this.endCoverSize > 0;
  }

  /** @returns 播放页封面（形变终点）这个锚点是否量到过 —— 只给日志用，排查"没有封面飞入"。 */
  public bigCoverAnchored(): boolean {
    return this.bigNodeKnown;
  }

  /** @returns 世代号是否还是捕获时那一个（延时回调用它丢弃过期动作）。 */
  public morphGenAlive(gen: number): boolean {
    return gen === this.morphGen;
  }

  /** 展开收尾完成：进入稳定展开态。 */
  public morphSettleOpen(): void {
    this.morphStage = MorphStage.OPEN;
    this.morphDrive = MorphDrive.NONE;
    this.applyMorphProgress(1);
    if (this.metaBridgeActive) {
      this.logMetaFont(false, 'complete');
      this.logMetaFont(true, 'complete');
    }
    this.releaseMorphOwnership(false);
    this.logMorphOwnership('settled-open');
    Logger.info(PlayerExpandState.logTag, 'morph open (settled)');
  }

  /** 开始收起。 */
  public morphBeginLeaving(): void {
    this.sourceBarHidden = true;
    this.morphStage = MorphStage.LEAVING;
    this.morphDrive = MorphDrive.ANIM;
    this.morphGen = this.morphGen + 1;
    this.metaBridgeGeneration = this.morphGen;
    this.logMorphOwnership('begin-leaving');
    Logger.info(PlayerExpandState.logTag,
      `morph leaving from p=${this.morphP.toFixed(3)} gen=${this.morphGen}`);
  }

  /** 落回迷你条（对标 LANDING：此时**不再重绘播放页内容**，只留迷你条）。 */
  public morphLand(): void {
    this.morphStage = MorphStage.LANDING;
    this.morphDrive = MorphDrive.NONE;
    this.releaseMorphOwnership(true);
    this.logMorphOwnership('land-mini');
    Logger.info(PlayerExpandState.logTag, 'morph land (hand back to mini bar)');
  }

  /** 复位到"没有这套动画"的静止态（几何缺失、卸载、异常时都走这里）。 */
  public morphReset(): void {
    this.releaseMorphOwnership(true);
    this.morphGen = this.morphGen + 1;
    this.morphStage = MorphStage.NONE;
    this.morphDrive = MorphDrive.NONE;
    this.morphP = 1;
    // ★ 浮层那一层（`morphOverlayP`，560ms 那条时间线）**也必须在这里清**：
    //   会话结束/卸载之后它的补间还可能挂在那 560ms 的尾巴上，不清的话
    //   下一轮起手第一帧会按"残留进度"画一次浮层封面（观感是闪一下大图）。
    this.morphOverlayReset();
    // 几何也一起作废：下次展开必须重新量一遍（宿主尺寸/迷你条位置都可能变了）
    this.morphUsable = false;
    // ★ 2026-10-16（照搬无界）：连同"几何就绪"一起作废 —— 下一轮必须重新量到终点才容许
    //   落非恒等几何（`applyMorphProgress` 的那道门）。⚠️ 不清的话，点击打开时
    //   "旧实例卸载的 morphReset"之后，新一轮会在**没有终点**的情况下被放行 ⇒ 又回到旧 bug。
    this.morphGeomReady = false;
    // 会话结束：下一轮展开要从"作废终点 → 在原尺寸时量 → 压起点"重新走一遍
    this.morphSessionStarted = false;
    this.morphScale = 1;
    this.morphTx = 0;
    this.morphTy = 0;
    this.morphClipHeight = 0;
    this.morphRadius = 0;
    this.morphContentOpacity = 1;
    Logger.info(PlayerExpandState.logTag, 'morph reset');
  }

  /**
   * @returns **真的在播形变**（不是"重试窗口里挂着"）。
   *
   * ⚠️ 壳层克隆层用它当渲染门，别用 `morphContainerActive()`：
   *    点击打开时会先进 ENTERING 再重试最多 12×32ms（≈400ms），这段窗口里
   *    形变其实还没开始，但 `morphContainerActive()` 已经是 true、`morphP` 已经是 0
   *    ⇒ `actionsOpacityAt(0) = 1` ⇒ **克隆层在屏上全亮地漂了 400ms**
   *    （用户实测的"三个按钮一直漂移"就是这个"假动画"段）。
   *    只有"手指正在驱动"或"补间动画驱动"才算真在播。
   */
  public morphSessionDriving(): boolean {
    if (!this.morphUsable || !this.morphContainerActive()) {
      return false;
    }
    if (this.morphDrive === MorphDrive.ANIM) {
      return true;
    }
    return this.morphDrive === MorphDrive.FINGER &&
      (this.pullDragging || this.morphStage === MorphStage.LEAVING);
  }

  /** @returns 现在是否需要给播放页套裁剪容器（静止态 false = 完全不裁剪）。 */
  public morphContainerActive(): boolean {
    return this.morphStage === MorphStage.ENTERING || this.morphStage === MorphStage.LEAVING ||
      this.morphStage === MorphStage.LANDING;
  }

  /**
   * @returns 本轮形变的**终点几何**是否已量到（= 容器可以落非恒等 `scale/translate/clip`）。
   *
   * 对标无界 `PlayerPage.pullGeomReady`（`wujie.pa` 168236 / 176221 / 176232）：
   * 那两个调用点（`onPullTChanged` 的门、`publishMorphTargets` 的置位）就是它的全部语义
   * —— **"几何没齐就别动容器"**。
   *
   * ⚠️ 与 {@link morphUsable} 的分工：
   *   · `morphUsable` —— `morphInitParams()` 算出来了（两个端点都有一份值）；
   *   · `morphGeomReady` —— **本会话真的量到了终点锚点**，可以落位。
   *   前者会因为"退回 onAreaChange 兜底值"而为真，后者不会 —— 落位门必须用后者。
   * 排查关键字：`grep morph geom ready`（`hdc shell hilog -x | Select-String 'morph geom ready'`）。
   */
  public morphGeomReadyNow(): boolean {
    return this.morphGeomReady;
  }

  /**
   * 给**收起**那一侧用的兜底：把"几何就绪"这一位放行。
   *
   * 依据：无界的收起是从**已经落位的打开态**反向跑同一条公式
   * （`MainPage.closeWithAnimation` → `animateMorphT(reverseMs, 0, REVERSE_EASING)`），
   * 那时容器本来就是 identity、两端的端点几何早就有了；它**不会**在收起路上再去量一遍终点。
   * 我们这边多一道 `morphGeomReady` 门（为了挡住"点击打开时用半份几何落位"），
   * 所以收起前必须确认这一位是开的 —— 否则 `applyMorphProgress(0)` 会被挡掉 ⇒
   * 收起补间**整段是空转**（用户实测「点击关闭 / 系统返回关闭没有动画」）。
   *
   * ⚠️ 只在"这一位因为异常路径没开、但端点几何其实拿得到"时才由调用方调它；
   *    `morphInitParams()` 返回 false（连盒子/胶囊都没量到）时**不置位**，
   *    让收起落到"无形变"的退化路径上（宁可没动画也不要飞错位置）。
   * @returns 是否已就绪
   */
  public ensureMorphGeomForClose(): boolean {
    if (this.morphGeomReady) {
      return true;
    }
    if (!this.morphInitParams()) {
      return false;
    }
    this.morphGeomReady = true;
    this.pushMorphTrace('geomReadyClose');
    Logger.info(PlayerExpandState.logTag, 'morph geom ready (close path fallback)');
    return true;
  }

  /** @returns 形变是否"活着"（对标 `morphLiveOf`：ENTERING / LEAVING / LANDING）。 */
  public morphLive(): boolean {
    return this.morphStage === MorphStage.ENTERING || this.morphStage === MorphStage.LEAVING ||
      this.morphStage === MorphStage.LANDING;
  }

  // ═════════════════ 关闭落地的**播放条挤压回弹**（对标无界 `squashLand` / `animateSquash`）═════════════════
  //
  // ★★ 2026-10-15（修用户实测「**无界关闭时播放条会弹一下**」）：
  //   无界 1.2.4 的收起落位不是"啪一下交还迷你条"，而是**先压扁、再弹回**：
  //   ```
  //     squashLand()  L153727-153800
  //       setMorph(LANDING, ANIM)                       // 这一帧播放页不再绘制
  //       animateSquash(SQUASH_Y=0.86, SQUASH_MS=110, EASE_OUT_STR)   // ← 压到 0.86
  //         onDone → finishReverse(true)
  //     紧随其后的回弹（L163786-163855，玻璃胶囊"触底弹回"）
  //       animateSquash(→1, SQUASH_BACK_MS=320, SQUASH_BACK_EASING="cubic-bezier(0.34,1.56,0.64,1)")
  //   ```
  //   出处：`_recover/logic-src/开关播放器-手势路径定稿.md` §4 全表（L465-468 那三行）
  //   + `形变引擎-源注册与参数总表.md` L153-156 的常量表。
  //   ⚠️ `SQUASH_Y` 是**纵向比例**，乘在**迷你条胶囊**上（不是播放页）—— 无界那一侧
  //      `PlayerPage` 只把它当"是否还画"的布尔门读（`morphSquashing`，U2 已闭合），
  //      真正的 `× 0.86` 落在 `MainPage` 的胶囊上。所以这里也是加在迷你条上。
  /** 挤压时的纵向比例（无界 `SQUASH_Y = 0.86`）。 */
  public static readonly SQUASH_Y: number = 0.86;
  /** 压下去的时长（ms，无界 `SQUASH_MS = 110`）。 */
  public static readonly SQUASH_MS: number = 110;
  /** 弹回来的时长（ms，无界 `SQUASH_BACK_MS = 320`）。 */
  public static readonly SQUASH_BACK_MS: number = 320;

  /**
   * 迷你条胶囊的**纵向挤压比例**（1 = 原样）。
   *
   * 由播放页在"收起落位"那一刻起两条补间（见 {@link squashLandAnim}）驱动；
   * 静止态恒为 1 ⇒ 不改变任何静态版面。
   */
  @Trace public morphSquashY: number = 1;

  /**
   * 跑一次无界的"落地挤压 → 回弹"（`squashLand` 的那两条补间）。
   *
   * ⚠️ 两条**共用同一个 `animateTo` 闭包写同一个字段**是刻意的：`morphSquashY` 只是一条
   *   竖直线上的标量，先后两段各自由时长与曲线决定形状；分成两个补间是因为无界的
   *   `SQUASH_MS(110)` 与 `SQUASH_BACK_MS(320)` **不是同一段**（压与弹各自计时）。
   * ⚠️ 必须在**播放页已经进入 LANDING 之后**调用（无界 `squashLand` 的顺序就是
   *    `setMorph(LANDING)` → `animateSquash`）—— 否则会看到"播放页还在画、迷你条先弹"。
   * @param ui 起补间用的 UIContext（播放页自己的）
   */
  public squashLandAnim(ui: UIContext): void {
    if (ui === undefined) {
      // 拿不到 UIContext：不弹也不能把胶囊永久压在 0.86 上
      this.morphSquashY = 1;
      return;
    }
    this.morphSquashY = 1;
    // ① 压到 SQUASH_Y（110ms，EASE_OUT_STR）
    ui.animateTo({
      duration: PlayerExpandState.SQUASH_MS,
      curve: curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)
    }, (): void => {
      this.morphSquashY = PlayerExpandState.SQUASH_Y;
    });
    // ② 弹回 1（320ms，`cubic-bezier(0.34, 1.56, 0.64, 1)` —— 那条 >1 的控制点就是"过冲回弹"）
    setTimeout((): void => {
      ui.animateTo({
        duration: PlayerExpandState.SQUASH_BACK_MS,
        curve: curves.cubicBezierCurve(0.34, 1.56, 0.64, 1)
      }, (): void => {
        this.morphSquashY = 1;
      });
    }, PlayerExpandState.SQUASH_MS);
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdSquash land squashY=${PlayerExpandState.SQUASH_Y} down=${PlayerExpandState.SQUASH_MS}ms ` +
      `back=${PlayerExpandState.SQUASH_BACK_MS}ms easing=(0.34,1.56,0.64,1)`);
  }

  /** @returns 是否允许跟手上拉（对标 `pullGestureAliveOf`：**仅 ENTERING**）。 */
  public pullGestureAlive(): boolean {
    return this.morphStage === MorphStage.ENTERING;
  }

  /** @returns 是否还要重绘播放页内容（对标 `playerPaintsOf`：LANDING 时停笔）。 */
  public playerPaints(): boolean {
    return this.morphStage !== MorphStage.LANDING;
  }

  // ═════════════════════════ 三、控制区（对标 PlayerChrome 分档 + BarCollapse 自动收起）═════════════════════════
  //
  // 说明：**下拉跟手收起**派音已经实现（见 `PlaybackPage.collapseProgress` + `PanGesture`），
  // 所以这里只补无界有、我们没有的两件：控制区**按档位取尺寸**、**静止自动收起**。

  /** 控制区档位：0=COMPACT 1=MEDIUM 2=FULL —— **对标无界 `PlayerChrome` 的三档**。 */
  @Trace public chromeTier: number = 2;

  /**
   * ★★★ 2026-10-16（照抄无界 `PlayerPage.padBottom()`，`wujie.pa:175250-175309`）：
   *
   * ```
   *   padBottom = avoidBottom > 0 ? avoidBottom
   *                               : px2vp(WindowInfo.navIndicatorHeight_px)      // 175251-175276
   *   …再抬到：max(padBottom, playerChromeOf(playerChromeTierFor(usableH())).bottomGap)
   *                                                                             // 175277-175308
   * ```
   * ⇒ **底部让位有一个"档位表 `bottomGap`"的下限**（FULL 65 / MEDIUM 48 / COMPACT 36）。
   *
   * ⚠️ 这里有个**循环**：`padBottom → tier → usableH → padBottom`。无界那边它是靠
   *   `playerChromeTierFor` **自己不含 `padBottom`**（只吃 `usableH` 一个参数）解开的；
   *   本仓照同一条路解：先用**只扣实测避让区**的 `u0` 定档，再拿那一档的 `bottomGap` 抬底。
   *   `tier` 是 0/1/2 三值 ⇒ 这个递推**一定收敛**（最多三级）。
   *
   * ⚠️ 改前我们的写法是**只用实测避让区**（注释里写着"不取那个 floor 是为了避免循环依赖"）——
   *   但循环其实是可解的，而无界的下限是**实实在在**的：本机 `avoidBottom`（= 我们量到的
   *   `navigationBarBottomVp`）通常只有 30~50vp，而 FULL 档下限是 **65vp**
   *   ⇒ 我们比无界**少了 15~35vp 的底部让位**，控制区整体偏低、`usableH` 偏大。
   *
   * ⚠️ **不影响封面几何**：`playerCoverGeomRect()` 用的是 raw `navigationBarBottomVp`
   *   （1217 行），而无界的 `fitPlayerOverlay` 收的是 **`overlayBoxH()`**（= 实测 `swiperBoxH`，
   *   `wujie.pa:177265-177268`）—— **两条都不是 `usableH()`** ⇒ 本处改动只动"控制区预算"。
   * @returns 底部让位高度（vp）
   */
  public padBottomVp(): number {
    // 无界的 `avoidBottom` 分支：本仓的等价物就是实测避让区（量不到时按 0）
    const avoid: number = this.navigationBarBottomVp > 0 ? this.navigationBarBottomVp : 0;
    // ⚠️ 用**只扣实测避让区**的 u0 定档（与无界"tier 不含 padBottom"同构）
    const u0: number = Math.max(0, this.windowHeightVp - this.topInsetVp() - avoid);
    const floor: number = this.chromeOf(this.tierForUsableH(u0)).bottomGap;
    return floor > avoid ? floor : avoid;
  }

  /**
   * 可用高度（vp）—— 对标无界 `PlayerPage.usableH()`：
   * `usableH = winHVp() − padTop() − padBottom()`（`wujie.pa:180610-180625`）。
   *
   * ★ 2026-10-16：`padBottom()` 现在按无界取**档位表 `bottomGap` 的下限**（见 {@link padBottomVp}）。
   * @returns 可用高度（vp，≥0）
   */
  public usableHVp(): number {
    const u: number = this.windowHeightVp - this.topInsetVp() - this.padBottomVp();
    return u > 0 ? u : 0;
  }

  /**
   * 无界 `PlayerChrome` 档位表的**基线高度**（vp）—— 照抄 `wujie.pa:93434` 的 `ldai 0x154`。
   *
   * ## 它的含义（这是本轮最反直觉的一条）
   *
   * 无界**不是**拿"各档自己的 `total`"去当分界值的，而是拿**一个固定基线 340** 去减
   * 各档的 `total`（`playerChromeTierFor`，`wujie.pa:93433-93473`）：
   * ```
   *   if (340 >= FULL.total   − usableH) return FULL      // 等价：usableH >= 340 − FULL.total
   *   if (340 >= MEDIUM.total − usableH) return MEDIUM    // 等价：usableH >= 340 − MEDIUM.total
   *   return COMPACT
   * ```
   * ⇒ 阈值 = `340 − total`：
   *
   * | 档 | `total` | 阈值 `usableH >= 340 − total` |
   * | --- | --- | --- |
   * | FULL | 250 | **90** |
   * | MEDIUM | 252 | **88** |
   * | COMPACT | 178 | （兜底，不判） |
   *
   * ⚠️ 这个 340 **故意不在表里**：三档的 `total` 都 ≤ 340，所以 340 = "比最宽松那档还宽"的
   *    参照高度；`usableH` 越接近 340，分档就越严。**不要把它和 `FULL.total` 混为一谈**
   *    （本轮之前的实现与注释就是这么错的，见 `updateChromeTier` 的改动说明）。
   */
  private static readonly CHROME_BASELINE_H_VP: number = 340;

  /**
   * 无界 `PlayerChrome` 档位表（照抄 `wujie.pa:93534 / 93554 / 93574`，一行一档）。
   *
   * ⚠️ 下标与 `chromeTier` **同序**：`0 = COMPACT`、`1 = MEDIUM`、`2 = FULL`
   *   （表在反汇编里的书写顺序是 FULL→MEDIUM→COMPACT，与 `tier` 相反 —— 别照书写序抄）。
   * ⚠️ `total` **不是**「前几项相加」：`v2 = 58` 是 FULL/MEDIUM/COMPACT **三档共用**的第五项
   *   （`wujie.pa:93547-93551`）⇒ `total = topBarH + gapSwiper + gapScrub + playSize + 58`。
   */
  private static readonly CHROME_TABLE: PlayerChromeSpec[] = [
    // 0 = COMPACT（wujie.pa:93574）
    new PlayerChromeSpec(36, 20, 14, 52, 28, 20, 18, 12, 20, 28, 36, 0.86, 178),
    // 1 = MEDIUM（wujie.pa:93554）
    new PlayerChromeSpec(40, 32, 20, 62, 30, 21, 19, 13, 22, 38, 48, 0.92, 252),
    // 2 = FULL（wujie.pa:93534）
    new PlayerChromeSpec(44, 48, 28, 72, 32, 22, 20, 14, 24, 50, 65, 1, 250)
  ];

  /** 按档取表 —— 对标 `playerChromeOf(tier)`（`wujie.pa:93404`，越界一律落 FULL）。 */
  private chromeOf(tier: number = this.chromeTier): PlayerChromeSpec {
    if (tier === 0) {
      return PlayerExpandState.CHROME_TABLE[0];
    }
    if (tier === 1) {
      return PlayerExpandState.CHROME_TABLE[1];
    }
    return PlayerExpandState.CHROME_TABLE[2];
  }

  /**
   * `clamp(0.065 × h, 16, 56)` —— 照抄无界 `playerSwiperGapOf(h)`（`wujie.pa:93497-93519`）。
   *
   * ★ 它是**连续量**，不是档位查表：`SWIPER_GAP_MIN = 0x10 = 16`、`SWIPER_GAP_MAX = 0x38 = 56`。
   * ⚠️ 这一条也是本轮用来**钉死反汇编操作数方向**的那把尺子（见 `全局记忆.md`
   *    「`.pa` 里 `OP dst, src` 的实际语义是 `dst OP acc`」）—— 不要再"顺手改成查表"。
   */
  private static swiperGapOf(hVp: number): number {
    const raw: number = 0.065 * hVp;
    if (16 < raw) {
      return 56 > raw ? raw : 56;
    }
    return 16;
  }

  /** 控制区**三段结构**里"Swiper 与进度条之间"那根占位条的**高度**（vp）：`playerSwiperGapOf(usableH)`。 */
  public swiperGapVp(): number {
    return PlayerExpandState.swiperGapOf(this.usableHVp());
  }

  /** 控制区**三段结构**里"进度条与传输条之间"那根占位条的**高度**（vp）：`chrome().gapScrub`。 */
  public chromeGapScrubVp(): number {
    return this.chromeOf().gapScrub;
  }

  /**
   * 控制区**实际占用高度**（vp）—— 对标无界 `playerChromeTotalOf(tier, h)`（`wujie.pa:93478`）：
   * ```
   *   playerChromeTotalOf = playerChromeOf(tier).total − playerChromeOf(tier).gapSwiper
   *                                                      + playerSwiperGapOf(h)
   * ```
   * 语义：表里的 `total` 用的是**该档固定的** `gapSwiper`，而实际那根占位条走的是**连续**公式
   * ⇒ 把表里那一份换成实际那一份。**这两处必须成对出现**，只改一头就是"控制区高度算错几十 vp"。
   */
  public chromeTotalVp(): number {
    const c: PlayerChromeSpec = this.chromeOf();
    return c.total - c.gapSwiper + PlayerExpandState.swiperGapOf(this.usableHVp());
  }

  /**
   * Swiper 容器（封面页/歌词页那一块）的**应有高度**（vp）—— 对标无界 `PlayerPage.estBoxH()`
   * （`wujie.pa:171554-171589`）：
   * ```
   *   estBoxH = max(0, usableH() − playerChromeTotalOf(playerChromeTierFor(usableH()), usableH()))
   * ```
   *
   * ⚠️ 无界那边它只是**兜底估算**：容器真量到高度（`swiperBoxH`）时一律优先用实测
   *   （`overlayBaseH()`，`wujie.pa:175141`），只有 `chromeHidden || swiperProgress ≤ 0.001`
   *   那一小段时间没量到才用本函数。我们这里**只把它当诊断量**（见 `PlaybackPage` 的
   *   `RzdSwiperBox` 日志），**不参与布局** —— 理由写在下面。
   *
   * ## 为什么我们**不能**像无界那样拿它当硬高度
   *
   * 无界的 Swiper 容器是 `layoutWeight(1)` + `.height(overlayBaseH())` **两条腿**：估算值负责
   * "控制区收起/展开时那一段过渡"，实测值一量到就接管。
   * 我们这一侧的 Swiper 也是 `layoutWeight(1)`，但控制区高度是**由内容撑出来的**
   * （`ControlAreaComponent` 的自然高 + 我们的 `gapSwiper`/`gapScrub` 两根占位条）
   * ⇒ 再叠一个 `estBoxH` 就是**两个源同时决定同一段高度**，正是本轮之前反复踩的
   * "同一形状两条口径"的形状。⇒ 先只放诊断，等真机上量出「实测 Swiper 高 vs `estBoxH`」
   * 差多少，再决定是否照搬那两条腿。
   */
  public estBoxHVp(): number {
    const u: number = this.usableHVp();
    const inner: number = u - this.chromeTotalVp();
    return inner > 0 ? inner : 0;
  }

  /**
   * 按**可用高度**决定控制区档位 —— 对标无界 `playerChromeTierFor(usableH)`（`wujie.pa:93433-93473`）。
   *
   * ★★★ 2026-10-16（**改正一处算错的判据**，字节码逐条复核）：
   *   改前是 `u >= 340 ? 2 : (u >= 252 ? 1 : 0)`。
   *   ⚠️ 两个错：
   *     ① **340 被当成了 `FULL.total`** —— 它其实是**基线高度**（见 `CHROME_BASELINE_H_VP`）；
   *     ② 分界值方向反了 —— 无界是 `usableH >= 340 − tier.total`，不是 `usableH >= tier.total`。
   *   ⇒ 正确阈值 **FULL 90 / MEDIUM 88**（改前是 340 / 252，差了一个量级）。
   *
   *   ⚠️ 为什么改前那版能在手机上"看着没事"：手机竖屏 `usableH ≈ 800`，**两版都落 FULL**
   *     ⇒ 这是个**只在矮窗口/横屏才暴露**的错。反过来说，用户有可能看到的变化是：
   *     极矮窗口（`usableH` 落在 88~252 之间）从"中档/紧凑档"变成"宽松档"（= 控制区变大）。
   *     这正是无界的行为（它那边 `usableH < 88` 才给 COMPACT）。
   *
   *   ★ 操作数方向是怎么钉死的（别凭印象重推）：先用语义已知的 `playerSwiperGapOf`
   *     （`clamp(0.065h,16,56)`）反证，见 `全局记忆.md`
   *     「`.pa` 里 `OP dst, src` 的实际语义是 `dst OP acc`」。**按错的方向读也会得到一组
   *     看起来完全自洽的阈值**，所以那条纪律不能省。
   * @param _widthVp 旧签名保留（调用点传的宽度**不再参与定档**）：宽屏那一支的差异
   *   由 `④ 宽屏/面板统一` 那一块负责，不在这里混进来。
   */
  /**
   * @returns 按**可用高度**定档（纯函数，不读字段）—— 对标 `playerChromeTierFor(usableH)`
   *   （`wujie.pa:93433-93473`）。
   *
   * ⚠️ 抽成纯函数是**必须**的：`padBottomVp()` 要用它来解那个
   *   `padBottom → tier → usableH → padBottom` 的循环（见那边的注释），
   *   而循环里**不能**再调 `usableHVp()`（那就真的成环了）。
   * @param u 可用高度（vp）
   */
  private tierForUsableH(u: number): number {
    const base: number = PlayerExpandState.CHROME_BASELINE_H_VP;
    // ⚠️ 顺序 = 无界的 `if` 顺序（FULL 先判、MEDIUM 次之、否则 COMPACT），不要按 total 大小重排。
    if (base >= this.chromeOf(2).total - u) {
      return 2;
    }
    return base >= this.chromeOf(1).total - u ? 1 : 0;
  }

  public updateChromeTier(_widthVp: number = 0): void {
    const u: number = this.usableHVp();
    const base: number = PlayerExpandState.CHROME_BASELINE_H_VP;
    const tier: number = this.tierForUsableH(u);
    if (tier !== this.chromeTier) {
      Logger.info(PlayerExpandState.LOG_TAG,
        `RzdChrome tier ${this.chromeTier} → ${tier} usableH=${u.toFixed(1)} ` +
        `thr=${(base - this.chromeOf(2).total).toFixed(0)}/${(base - this.chromeOf(1).total).toFixed(0)} ` +
        `(winH=${this.windowHeightVp.toFixed(1)} padTop=${this.topInsetVp().toFixed(1)} ` +
        `padBottom=${this.padBottomVp().toFixed(1)} avoidBottom=${this.navigationBarBottomVp.toFixed(1)})`);
      this.chromeTier = tier;
    }
  }

  // ⚠️ 2026-10-15：`chromePaddingVp()`（曾返回 10 / 14 / 18）**已删除** —— **零读取点**
  //   （全仓 grep 只有它自己的定义），而且这三个值**不在无界档位表里**（表里没有"统一内边距"
  //   这个概念）⇒ 又一条"自己发明 + 没人消费"的死代码。同族已删：`chromeGapVp()`（§56.30）。

  // ⚠️ 2026-10-15：`chromeGapVp()`（曾返回 18 / 24 / 30）**已删除**。
  //   两个原因，缺一个我都会留着它：
  //   ① **它没有任何消费者** —— `PlaybackPage` 把它传给 `ControlAreaComponent` 的 `chromeGap`
  //      `@Param`，而那个参数在组件里**只有声明、从不使用**（grep 全组件只有声明那一处）
  //      ⇒ 它是**死管道**；而且它**曾经误导过我**：我据此以为"把档位从宽度改成高度"
  //      会让手机上的控制区间距从 18 变 30（实际没有任何可见效果）。
  //   ② **它的值不是无界的** —— 档位表里根本没有"统一的按钮间距"这个概念，
  //      只有 `gapSwiper`(48/32/20) 与 `gapScrub`(28/20/14) 两个**语义不同**的间距
  //      （`wujie.pa:93485` / `190510`）⇒ 18/24/30 是**我们自己发明的**。
  //   ⇒ 真正要做的是 `RzdMusic待确认清单.md` 的 **D4**：把控制区按无界的三段结构
  //      （swiper / scrubber / transport）重排，再按档取 `gapSwiper` / `gapScrub`。

  /**
   * 收藏 / 更多图标的字号（fp）—— 对标无界 `chrome().favSize`，**按档取值**。
   *
   * ★★ 2026-10-15（照搬无界；从字节码取到确切值）：`wujie.pa:195193 / 195316` 两处
   *   （收藏与更多**用同一个** `favSize`）；档位表 `wujie.pa:93534/93554/93574`
   *   ⇒ **FULL 24 / MEDIUM 22 / COMPACT 20**。
   *   ⚠️ 我们原来写死 `22`（注释还写着"取与派音一致的一档"）—— 属"取错来源"那一族。
   * @returns 图标字号（fp）
   */
  public chromeFavSize(): number {
    return this.chromeTier === 0 ? 20 : (this.chromeTier === 1 ? 22 : 24);
  }

  /**
   * 控制区**侧键**（循环 / 播放列表）图标的字号（fp）—— 对标无界 `chrome().sideSize`。
   *
   * ★★ 2026-10-15（照搬无界）：`wujie.pa:181333 / 181754` 两处（`.fontSize(chrome().sideSize)`）；
   *   档位表 ⇒ **FULL 22 / MEDIUM 21 / COMPACT 20**。
   *   ⚠️ 我们原来写死 `isWidthBreakpointLgOrXl(bp) ? 26 : 24` —— **按宽度**分档（同 §56.26 那个
   *      反了的判据），且两个数都不是无界的值。现在按无界的档位表取。
   * @returns 侧键图标字号（fp）
   */
  public chromeSideSize(): number {
    return this.chromeTier === 0 ? 20 : (this.chromeTier === 1 ? 21 : 22);
  }

  /**
   * 传输条上**两个方形图标按钮**（上一首 / 下一首）的宽度（vp）—— 对标 `chrome().seekSize`。
   *
   * ★★★ 2026-10-16（**订正一处此前记错的语义**）：
   *   我之前在注释里把 `seekSize` 写成"进度条那一行的**块尺寸**"，所以一直觉得
   *   "我们 16vp 的滑块行高 vs 无界的 32 —— 两者不是同一个量，要等实测"。
   *   **本轮把两处消费点读出来，语义完全不是那样**：
   * ```
   *   wujie.pa:181429   Image().width(chrome().seekSize).aspectRatio(1).objectFit(Contain).opacity(0.86)
   *   wujie.pa:181639   同上（第二处）
   * ```
   *   —— 它是**两个方形图标按钮的宽度**（`aspectRatio(1)` 定成正方形），
   *   与**进度条/Slider 毫无关系**。
   *   ⇒ "我们的 `slider_height = 16vp` 和无界的 32 不是一个量"这句话是对的，
   *     但结论不是"需要实测"，而是**这两个东西根本不是同一个元素、不必对齐**。
   *
   * 本仓的对应物：`ControlAreaComponent` 的传输条里那两个
   * `Image(...).controlImageBuilder().width(...)` ——
   * 而 `controlImageBuilder()`（`@Extend(Image)`）的
   * `{ aspectRatio(1) + opacity(0.86) + objectFit(Contain) }` **与无界那两处逐字相同**
   * ⇒ 对应关系是确定的，就用本档的 `seekSize`。
   *
   * ⚠️ 改前我们用的是 `app.float.control_width`(32vp) / `control_width_lg`(36vp)：
   *   两个数**恰好**是 FULL / 一个别的档的值，但**档位一变它不变**（写死两档）。
   *   现在改为**按档取值**：FULL 32 / MEDIUM 30 / COMPACT 28。
   *
   * ⚠️ **播放/暂停主按钮不在这里**：它用的是 `playSize`（72 / 62 / 52），
   *   而本仓那个位置是 `image_play_width = 72vp`（FULL 档恰好对上；宽屏档的
   *   88 与表里的 62/52 不同源，暂不动 —— 见 `RzdMusic记忆.md` §98）。
   * @returns 方形图标按钮宽度（vp）
   */
  public chromeSeekSize(): number {
    return this.chromeOf().seekSize;
  }

  /** 顶栏那一行的实际行高（vp）。★ 与 `topInsetVp()` 的 56 **不是同一个量**，见 `chromeTopBarH()`。 */
  public static readonly TOP_BAR_ROW_H_VP: number = 56;

  /**
   * ★★★ 2026-10-16：封面基准矩形的**竖向校正量**（vp，负 = 往上）。
   *
   * ## 它为什么存在（这是"封面偏低"的**唯一**可控落点）
   *
   * 本仓的封面是「**量测 + 变换式**」：覆盖层按 `scale = 实测/基准`、`translate = 实测位 − 基准位`
   * 从**基准**补到**实测**位。而**实测位由 `Column` 的排布决定** ——
   * 真封面夹在"顶部无留白 + 下方 metA/控制区"之间被**顶到窗口竖直中部**。
   * 无界那边是**纯几何**（`CoverMorph`，`中心 = padTop + metaY`），所以在屏幕上部。
   *
   * ⇒ 要真正对齐，本该改 `Column` 的排布（给封面上下对称留白）；
   *   但那属结构改动、且**必须在真机上量**。在拿到真机数据之前，
   *   这里用**一个常数**把基准整体上移 —— 三个量（`x/y/height`）是原始值，
   *   只有 `y` 平移，**回归风险最小、且单行可回退**。
   *
   * ## ⚠️⚠️ 2026-10-16 **本条已被证伪两次，现在取值 0（= 完全不起作用）**
   *
   * 我曾经用截图目测校准它：`0 → −103 → −250`，两次**都让封面更偏**（用户实测
   * "现在偏移越来越狠了"）⇒ 说明**"按截图目测的中心"推折算比**这个方法本身不可靠：
   * 封面是**深色海报**，上下边缘与黑色背景融为一体，目测误差 ±30vp 起步，
   * 而折算比分母只有几十 vp ⇒ 误差被放大 4 倍，越调越远。
   *
   * ⇒ **归零，并改走"用真机日志收敛"这条路**。要收敛只需要一条日志里的两个数：
   * ```
   *   hdc shell hilog -x | Select-String 'RzdCoverGeom'
   *   ⇒ 打 `y=… centerY=… expectCenter=…`
   *   设 delta = centerY − expectCenter（正 = 还偏低，负 = 抬过头）
   *   则 本常量应取 ≈ −delta × k，其中 **k 由两次实测标定**：
   *     记本常量 = A 时读到的 centerY = CA，本常量 = B 时读到 CB
   *     则 k = (CA − CB) / (B − A)   ← **这个 k 才是真折算比**，是实测出来的，不是估的
   * ```
   *   目前只有一次有效观测（`0 → centerY 实测待补`），所以**先归零、等一条日志**。
   *
   * ⚠️ 静止态只影响封面 `y`；`x`、`size`、`radius` 一律不动。
   */
  private static readonly COVER_BASE_Y_OFFSET_VP: number = 0;

  // ═══════════ 目标 ④ 的 S1 步：两个「尺寸档位纯函数」（先落公式，暂零消费）═══════════
  //
  // 施工图：`_recover/logic-src/目标④-宽屏面板统一-施工图与验收.md` §4 的 **S1**。
  //
  // ⚠️ 这一条**例外地允许"先有访问器、后接消费者"**，原因是它的值**已由字节码确证**、
  //    不是我们发明的（§56.38）；而已接线的那些"没人用的访问器"（如已删的 `chromeGapVp`）
  //    是我们自己拍的值 ⇒ 那才是死管道。两者的区别就在"值有没有出处"。
  //
  // ⚠️ **现在没有任何消费者**（宽屏/面板形态在本机不可构造）⇒ 加进来**对手机零影响**：
  //    静态函数不参与 build()，不会被渲染登记，也不会改变任何布局。

  /**
   * 无界 `sizeScaleOf(winWVp)`（= `sizeK()`）—— 按**宽度断点**的阶梯缩放。
   *
   * 出处：`wujie.pa:84524-84548`（转写见 `RzdMusic记忆.md` §56.38 / 清单 E5）。
   * ```
   *   宽度断点 bp >= 4 → 1.32 ;  >= 3 → 1.24 ;  >= 2 → 1.12 ;  else → 1   （手机）
   * ```
   * ★ **手机（bp < 2）恒为 `1`** —— 这正是我们全仓用固定 fp/vp 在手机上**逐字正确**的原因；
   *   而平板/PC 会放大 12% / 24% / 32%，我们的固定值在**那里整体偏小** ⇒ 归目标 ④ 的 S4–S6。
   *
   * 断点取值口径：与 `updateChromeTier` 同一个 `bp`（`WidthBreakpoint`：
   * SM=0/1、MD=2、LG=3、XL=4 —— 见本仓 `isWidthBreakpointLgOrXl` 的用法）。
   * @param winWVp 窗口宽度（vp）
   * @param widthBp 宽度断点（`uiObserver.WindowSizeLayoutBreakpointInfo.widthBreakpoint`）
   * @returns 缩放系数（手机 = 1）
   */
  public static sizeScaleOf(winWVp: number, widthBp: number): number {
    // 无界的判据是**宽度断点**，不是宽度数值 —— 所以两参都要（`winWVp` 只用于兜底日志/未来扩展）。
    if (widthBp >= 4) {
      return 1.32;
    }
    if (widthBp >= 3) {
      return 1.24;
    }
    if (widthBp >= 2) {
      return 1.12;
    }
    return 1;
  }

  /**
   * 无界 `topPageSideOf(winWVp)` —— 页面左右留白（vp）。
   *
   * 出处：`wujie.pa:84660-84678`（§56.38 / 清单 E5）。
   * ```
   *   winWVp < 600 → 16 ;  < 840 → 24 ;  else → 32
   * ```
   * ★ 手机（≈360~430vp）恒为 **16** —— 与 `PlaybackPage.LYRIC_META_SIDE_VP = 16`
   *   以及 `PlayerExpandState.LYRIC_COVER_LEFT_VP = 16` **同值** ⇒ 我们已经用对了手机那一档 ✓
   *   （清单 E5 已确认"我们的 16vp 是原值"）。
   * @param winWVp 窗口宽度（vp）
   * @returns 左右留白（vp）
   */
  public static topPageSideOf(winWVp: number): number {
    if (winWVp < 600) {
      return 16;
    }
    if (winWVp < 840) {
      return 24;
    }
    return 32;
  }

  /**
   * S1 的**自证**：把两个纯函数在"本机当前窗口"下的值打出来，用来核对它们在**手机档**上
   * 是否恰好等于我们已经在用的固定值（`sizeK = 1` / `side = 16`）。
   *
   * 排查关键字：`hdc shell hilog -x | Select-String 'RzdSizeTier'`
   * 期望（手机）：`side=16 sizeK=1`，且 `fixedOk=true`（两个固定值与档位值一致）。
   * @param widthBp 宽度断点
   */
  public logSizeTier(widthBp: number): void {
    // 量不到窗口宽时按 360 兜底（只为日志，不写回任何状态）。
    const w: number = this.windowWidthVp > 0 ? this.windowWidthVp : 360;
    const side: number = PlayerExpandState.topPageSideOf(w);
    const sizeK: number = PlayerExpandState.sizeScaleOf(w, widthBp);
    // "固定值是否与档位值一致"：手机档两个都该相等 ⇒ 反过来说明"宽屏要 ×1.12~1.32 / side 24~32"这条差在哪
    const fixedOk: boolean = sizeK === 1 && side === 16;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdSizeTier winW=${w.toFixed(0)} widthBp=${widthBp} side=${side} sizeK=${sizeK.toFixed(2)} ` +
      `fixedOk=${fixedOk} tier=${this.chromeTier} usableH=${this.usableHVp().toFixed(1)}`);
  }

  // ═══════════ 目标 ④ 的 S2 步：宽屏 / 面板的**内容占比档位**（不含任何猜测的间距）═══════════
  //
  // 施工图：`_recover/logic-src/目标④-宽屏面板统一-施工图与验收.md` §4 的 **S2**。
  //
  // ⚠️ **S2 与 S3 的区别**（这里刻意只做 S2 的那一半）：
  //   · 占比（`GridCol` 的 `span`）是**我们自己的布局参数**，而且**就在代码里**（见下）⇒ 能确证；
  //   · `Row({space: …})` / `GridRow({gutter: …})` 那种**间距数值**（56 / 48）**没有出处**
  //     ⇒ 一律**不去猜**（施工图 §6 第 2 条）。真正的间距走 `S3`：把宽屏分支接成**同一个
  //     `Row{ layoutWeight }`** 之后，间距由**同一个常量**给出，那时它才只有一个来源。

  /** 宽屏 `GridRow` 的**列数按档不同**：md/lg = 4 列，xl = 8 列。 */
  private static readonly WIDE_COLS_MD_LG: number = 4;
  private static readonly WIDE_COLS_XL: number = 8;

  /**
   * @returns 宽屏（非面板）左栏占比 —— **逐字取自 `PlaybackPage` 的 `GridCol` span 数组**。
   *
   * 出处（本轮实读，不是回忆）：`PlaybackPage.ets` L2128-2151 那两处：
   * ```
   *   GridRow  columns: { md: COLUMN_MD(8), lg: COLUMN_LG(12), xl: COLUMN_LG(12) }
   *   左（封面 + 歌名）: span { md: 4, lg: 5, xl: 4 }
   *   右（歌词）      : span { md: 4, lg: COLUMN_LYRIC_LG(7), xl: 8 }
   * ```
   * ⚠️ **三档的列数并不一样**（`BreakpointConstants`：`COLUMN_MD = 8`、`COLUMN_LG = 12`）：
   * | 档 | 总列 | 左 span | 右 span | 左占比 |
   * | --- | --- | --- | --- | --- |
   * | md | 8 | 4 | 4 | **1/2** |
   * | lg | 12 | 5 | 7 | **5/12** |
   * | xl | 12 | 4 | 8 | **1/3** |
   * ⇒ 这也是"它**能被等价收敛成一个两列 `Row`**"的依据：每档两栏的 span 都恰好填满总列数
   *   （8=4+4 / 12=5+7 / 12=4+8），**没有第三个占位列**。
   * @param widthBp 宽度断点（3 = LG、4 = XL，见 `WidthBreakpoint`）
   * @returns 左栏占比（0…1）
   */
  public static wideLeftRatio(widthBp: number): number {
    if (widthBp >= 4) {
      // XL：4 / 12（总列数 COLUMN_LG = 12）
      return 4 / 12;
    }
    if (widthBp >= 3) {
      // LG：5 / 12
      return 5 / 12;
    }
    // MD（也含更窄的兜底）：4 / 8
    return 4 / 8;
  }

  /**
   * @returns 宽屏那一档的 `GridRow` 总列数（用于换算与日志，不参与渲染）。
   * @param widthBp 宽度断点
   */
  public static wideColumnCount(widthBp: number): number {
    return widthBp >= 4 ? PlayerExpandState.WIDE_COLS_XL : PlayerExpandState.WIDE_COLS_MD_LG;
  }

  /**
   * 把"窗口坐标的点"换成"**宿主盒内坐标**"—— 即减去宿主盒自己的左上角。
   *
   * ★ 2026-10-15（目标 ④ 的 **S3 前置件**）：等宽屏/面板要复用同一份浮层（`.position()` 是
   *   **相对父组件内容盒**的绝对定位，不是窗口坐标）时，浮层会被挂到**不同的宿主**下：
   * ```
   *   手机：宿主 = 满屏的内容栈（左上角 = 窗口原点）⇒ 偏移 (0, 0)，本函数是恒等变换
   *   面板：宿主 = 左栏那一列        ⇒ 偏移 = (左栏的窗口 x, 内容盒顶)
   *   宽屏：宿主 = 左侧 GridCol 内容盒 ⇒ 偏移 = 该列内容盒的窗口 x
   * ```
   * ⇒ `position = 窗口坐标 − 宿主偏移`。
   *
   * ⚠️ **本函数故意只做这一件事**（一个减法），不参与"偏移量本身怎么来"——
   *    偏移量的唯一来源必须是**实测**（`getPositionToWindowWithTransform()` 减去
   *    该节点自身的布局原点），不许拿 `padding: 56` / `space: 56` 这类字面量去凑
   *    （见 `目标④-宽屏面板统一-施工图与验收.md` §6 第 2 条：那两个数值**没有出处**）。
   * ⚠️ **偏移为 (0,0) 时它与改前逐像素相同**（`x − 0 === x`）⇒ 手机路径接上它也是零风险的。   * @param windowX 窗口坐标 x（vp）
   * @param windowY 窗口坐标 y（vp）
   * @param hostX 宿主盒左上角在窗口里的 x（vp；手机 = 0）
   * @param hostY 宿主盒左上角在窗口里的 y（vp；手机 = 0）
   * @returns `{ x, y }` 宿主盒内坐标（vp）
   */
  public static toHostPoint(windowX: number, windowY: number, hostX: number, hostY: number): HostPoint {
    return {
      x: windowX - (hostX > 0 ? hostX : 0),
      y: windowY - (hostY > 0 ? hostY : 0)
    };
  }

  /**
   * 量一个节点在**窗口坐标**里的左上角（vp）—— 用作 {@link toHostPoint} 的 `hostX/hostY`。
   *
   * ★ 2026-10-15（目标 ④ 的 S3 前置件 · 第二件）：这是"宿主偏移**唯一合法来源**"的取数口。
   *   偏移量**禁止猜**（`padding: 56` / `Row({space:56})` / `GridRow({gutter:48})` 都没有出处），
   *   只允许从这里量（内部走本类已有的 {@link measureNode}，与 `reportMini` / `bigNode` 同一条链）。
   *
   * ⚠️ **只读、不写任何状态**：它不缓存、不上报，量不到就返回 `{x:0, y:0}`（= 恒等偏移）。
   *   ⇒ 未接线前调用它，行为与"写死 (0,0)"**逐像素相同**。
   * ⚠️ 用 `getPositionToWindowWithTransform()`（**渲染后**、含祖先 transform）——
   *   与 `measureNode` 的默认口径一致；这是量"宿主内容盒在窗口里的位置"的正确口径。
   *   （若宿主的祖先里带了 scale/translate，量到的就是**渲染位**；这正是 `.position()` 需要的参考系。）
   * @param ui UIContext
   * @param hostId 宿主的组件 id（宽屏/面板接线时由调用方给出）
   * @returns 宿主左上角（vp，窗口坐标）；量不到 ⇒ `{x:0, y:0}`
   */
  public measureHostOrigin(ui: UIContext, hostId: string): HostPoint {
    const r: NodeRect | undefined = this.measureNode(ui, hostId);
    if (r === undefined) {
      Logger.warn(PlayerExpandState.LOG_TAG,
        `RzdHostOrigin id='${hostId}' not-measured ⇒ (0,0) idempotent`);
      return { x: 0, y: 0 };
    }
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdHostOrigin id='${hostId}' origin=(${r.x.toFixed(1)},${r.y.toFixed(1)}) ` +
      `size=${r.w.toFixed(1)}x${r.h.toFixed(1)} win=${this.windowWidthVp.toFixed(0)}x${this.windowHeightVp.toFixed(0)}`);
    return { x: r.x, y: r.y };
  }

  /**
   * @returns 面板（横屏两栏）左栏占比 —— **逐字取自 `PlaybackPage.panelControlContent()`**。
   *
   * 出处：`panelControlContent()` 里两个 `Column().layoutWeight(1)` ⇒ **各占一半**。
   * ⚠️ 这里**没有**"我们自己的比例"可以搬：`layoutWeight(1)` 的语义就是"平分剩余空间"
   * ⇒ 唯一正确的值就是 `1/2`（写成算式而不是字面量 0.5，是为了让"它来自 layoutWeight"可读）。
   * @returns 左栏占比（0…1）
   */
  public static panelLeftRatio(): number {
    return 1 / (1 + 1);
  }

  /**
   * 把"左右占比"翻译成**两栏的目标宽度**（vp）。
   *
   * ⚠️ **这里不算间距**（`gutter` / `space` 一律不参与）：两个宽度加起来 = `avail`，
   *    也就是说**两栏紧贴**。真正的间距由 S3 之后的**同一处**常量给出 ——
   *    那时两栏宽度会各减去 `space/2`，而不是让这个函数去猜一个数。
   * ⚠️ 手机档**不读本函数**（施工图铁律：S1–S3 对手机逐像素无影响）。
   * @param avail 可用宽度（vp）
   * @param leftRatio 左栏占比（`wideLeftRatio()` / `panelLeftRatio()`）
   * @returns `{ left, right }` 两栏目标宽度（vp）
   */
  public static columnWidths(avail: number, leftRatio: number): WideColumns {
    const a: number = avail > 0 ? avail : 0;
    const r: number = leftRatio < 0 ? 0 : (leftRatio > 1 ? 1 : leftRatio);
    const left: number = a * r;
    return { left: left, right: a - left };
  }

  /**
   * S2 的**自证**：把宽屏/面板两档在本机窗口下的占比与两栏宽度打出来。
   *
   * 排查关键字：`hdc shell hilog -x | Select-String 'RzdWideCols'`
   * 期望（手机，横屏除外）：`isWide=false isPanel=false`（两栏都不参与布局，只是把数算出来备查）。
   * @param widthBp 宽度断点
   * @param isPanel 当前是否走面板布局（`PlaybackPage.usePanelLayout()`）
   * @param ui UIContext（用于 `measureHostOrigin()` 那条探针；拿不到时探针会走"量不到"分支，
   *   仍然打出 `hostZero=true` —— 这条护栏本身也要能被验）
   */
  public logWideColumns(widthBp: number, isPanel: boolean, ui: UIContext): void {
    const w: number = this.windowWidthVp > 0 ? this.windowWidthVp : 360;
    const side: number = PlayerExpandState.topPageSideOf(w);
    const avail: number = w - side * 2;
    const wl: number = PlayerExpandState.wideLeftRatio(widthBp);
    const wc: WideColumns = PlayerExpandState.columnWidths(avail, wl);
    const pc: WideColumns = PlayerExpandState.columnWidths(avail, PlayerExpandState.panelLeftRatio());
    const isWide: boolean = widthBp >= 2;
    // ★ S3 前置件的**自证**：宿主偏移为 (0,0)（= 手机那个满屏内容栈）时必须是**恒等变换**。
    //   期望恒为 `hostId=true` —— 它保证"接上 toHostPoint() 之后手机逐像素不变"。
    const probe: HostPoint = PlayerExpandState.toHostPoint(123.4, 567.8, 0, 0);
    const hostId: boolean = probe.x === 123.4 && probe.y === 567.8;
    // ★ S3 前置件第二件（`measureHostOrigin()`）的**自证**：
    //   探针宿主 id 故意给一个**不存在的** id ⇒ 期望跑进"量不到"分支、打出 `not-measured ⇒ (0,0)`
    //   且 `hostZero=true`。它证明的是"**量不到也绝不会让偏移变成 NaN**"这条护栏。
    //   （真正的宿主 id 等 S4/S5 接线时由调用方给；那时这里的探针换成真 id 即可。）
    const hostProbe: HostPoint = this.measureHostOrigin(ui, 'rzd_host_origin_probe');
    const hostZero: boolean = hostProbe.x === 0 && hostProbe.y === 0;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdWideCols winW=${w.toFixed(0)} widthBp=${widthBp} cols=${PlayerExpandState.wideColumnCount(widthBp)} ` +
      `side=${side} avail=${avail.toFixed(0)} isWide=${isWide} isPanel=${isPanel} hostId=${hostId} ` +
      `hostProbe=(${hostProbe.x.toFixed(1)},${hostProbe.y.toFixed(1)}) hostZero=${hostZero} ` +
      `wide(left=${wc.left.toFixed(0)},right=${wc.right.toFixed(0)},ratio=${wl.toFixed(3)}) ` +
      `panel(left=${pc.left.toFixed(0)},right=${pc.right.toFixed(0)},ratio=${PlayerExpandState.panelLeftRatio().toFixed(3)})`);
  }

  /**
   * 顶栏那一行的高度（vp）—— 对标无界 `chrome().topBarH`。
   *
   * ★★ 2026-10-15（照搬无界档位表）：`wujie.pa:93534/93554/93574`（FULL / MEDIUM / COMPACT）
   *   ⇒ **FULL 44 / MEDIUM 40 / COMPACT 36**。
   *
   * ⚠️ **它现在是"归一化 + 逐字不变"的**，不是把顶栏压到 44：
   *   我们的 `TopAreaComponent` 原来写死 `.height(56)`，而 56 = **让位线本身**
   *   （`PLAYER_TOP_FALLBACK_VP = 56`，也就是无界的 `padTop()` 下限）。
   *   无界的 `topBarH = 44` 是**内容行高**，它外面还有 `padTop()` 那一圈。
   *   两者混在一处时，直接把 56 改成 44 会**同时**动到"内容让位线"和"顶栏自身高度"
   *   —— 而让位线已经被整套形变几何（`topInsetVp()` / `lyricCoverYOf()` /
   *   `morphInitParams()`）依赖 ⇒ 那是"一块独立大活"（见下面「未接线字段」）。
   *   ⇒ 本轮只做**一件事**：把那个写死的 56 换成 `TOP_BAR_ROW_H_VP`，
   *     并让本函数在**手机档（`chromeTier` = 2 / FULL）**下**恰好返回它** ⇒
   *     手机上**逐像素不变**（回归红线），而档位从此有了唯一入口。
   * @returns 顶栏行高（vp）
   */
  public chromeTopBarH(): number {
    // ⚠️ 手机档直接返回 `TOP_BAR_ROW_H_VP`（= 改前的 56）。
    //    MEDIUM / COMPACT 的值已备好（40 / 36），等"内容让位线"与"顶栏行高"解耦后再接。
    return this.chromeTier === 0 ? 36 : (this.chromeTier === 1 ? 40 : PlayerExpandState.TOP_BAR_ROW_H_VP);
  }

  // ─────────────── 无界 `PlayerChrome` 档位表：**尚未接线**的 5 个字段（D4 剩项）───────────────
  //
  // 出处：`wujie.pa:93534/93554/93574`（三档字面量对象），转写见
  //       `RzdMusic记忆.md` §56.26 / §56.29 与 `RzdMusic待确认清单.md` 的 D4。
  // 已接线（6 项）：`topBarH`（本轮，手机档逐字不变） / `sideSize` / `favSize` /
  //               `titleSize`（= 封面页 20，配 `metaProgress` 0.75 → 歌词页 15） /
  //               `artistSize`（= 封面页 14 → 歌词页 12） / `metaGap`（= 10vp 那一档口径）。
  // ⚠️ **下面这 5 项不是"忘了"，是"接不了"** —— 每一项都要先动**结构**，不是改一个数：
  //   · `gapSwiper` 48/32/20：语义是"封面/Swiper 那一块与下方控制块之间"的间距，
  //     而我们的手机支没有这个可配的间距项（Swiper 吃 `layoutWeight(1)`，
  //     间距是"剩余空间的自然结果"）⇒ 要先按无界的三段结构（swiper / scrubber / transport）
  //     重排控制区。
  //   · `gapScrub` 28/20/14：同上，是"进度条那一行与传输条那一行"之间的间距；
  //     我们现在由 `app.float.slider_margin_bottom`(16vp) 给 ⇒ 直接改会移动传输条位置。
  //   · `playSize` 72/62/52：★ **已经等于无界的 FULL 值** ——
  //     `app.float.image_play_width = 72vp`（手机档）。⇒ 这一项**事实上已对齐**，
  //     剩下的只是"MEDIUM/COMPACT 档要缩小"，属宽屏/平板（设备受限）。
  //   · `seekSize` 32/30/28：★ **2026-10-16 订正** —— 它的语义是
  //     **传输条上两个方形图标按钮（上一首/下一首）的宽度**（`wujie.pa:181429` / `181639`：
  //     `Image().width(chrome().seekSize).aspectRatio(1)`），**与进度条无关**
  //     ⇒ 已落地为 `chromeSeekSize()`，消费点 = `ControlAreaComponent` 那两个 `Image`。
  //     旧注释里"我们给的是 `slider_height = 16vp`，两者不是同一个量"这句**结论错了**：
  //     它们**根本不是同一个元素、不需要对齐**。
  //   · `bottomGap` 65/48/36：★ **2026-10-16 已落地**为 `padBottomVp()`
  //     （`= max(avoidBottom, 档位表 bottomGap)`；那个"循环依赖"是可解的，见该方法注释）。
  // ⇒ 结论：这 5 项里 `gapSwiper` / `gapScrub` / `seekSize` / `bottomGap` 都已落地，
  //    只剩 `playSize` 的 MEDIUM/COMPACT 两档（属宽屏/平板，设备受限）。
  //    ⚠️ **不要**再把这些做成"只读档位访问器放那儿没人用" —— 那是 §56.30 那条
  //    `chromeGap` 死管道的翻版（会再次误导后来人）；每一项都必须**同时接上消费点**。

  /** 控制区是否被自动收起（对标 `BarCollapse.isCollapsed`）。 */
  @Trace public chromeCollapsed: boolean = false;

  /**
   * 记录一次控制区交互（点击/滑动）—— 只翻转"是否收起"这一个状态。
   *
   * ★★★ 2026-10-16（**本轮删掉了这条链上另外两个成员**）
   *
   * 原来这里还有 `lastChromeTouchMs` + `CHROME_AUTO_HIDE_MS(3000)` + `chromeShouldAutoHide()` +
   * `collapseChrome()` —— **四个成员全部零消费**（本文件 :1623 早就记过"旧控制区自动收起"是死的，
   * 但一直没删）。它们不只是"没用"，而是**有害**：
   * ```
   *   它们让"自动收起"在本仓看起来有**两套值**：
   *     PlayerExpandState.CHROME_AUTO_HIDE_MS = 3000   ← 零消费（本轮删除）
   *     PlaybackPage.CHROME_AUTO_HIDE_MS      = 5000   ← 活的（= 无界 PlayerPage.IDLE_MS，见 §96）
   *   ⇒ 后来人按 3000 去核对就会得出"与无界不一致"的错误结论。
   * ```
   * ⚠️ 另外 `chromeCollapsed` 这个名字在**两个类里各有一个**（本类 + `PlaybackPage` 自己的
   *    `@Local chromeCollapsed`）—— 后者才是渲染用的那个；本类这个只被 `chromeOffsetY()` /
   *   本方法 / `revealChrome()` 读写（`PlaybackPage` 会调后两个）。
   *    ⇒ **不要**把它当成"播放页那份"，它们是两处状态。
   */
  public touchChrome(): void {
    this.chromeCollapsed = false;
  }

  /** 唤出控制区（`PlaybackPage.touchChrome()` 的模型侧对应物）。 */
  public revealChrome(): void {
    this.chromeCollapsed = false;
  }

  /** @returns 控制区视觉位移（vp）：收起时向下移出。 */
  public chromeOffsetY(): number {
    return this.chromeCollapsed ? 46 : 0;
  }

  /** @returns 控制区透明度：自动收起时淡出；静止态恒 1（不存在残留半透明态）。 */
  public chromeOpacity(): number {
    return this.chromeCollapsed ? 0 : 1;
  }

  // ───────────────────────── 相位切换 ─────────────────────────

  /**
   * @returns 两端的封面矩形是否都量到了（可以开跑动画）。
   */
  public hasGeometry(): boolean {
    return this.miniSize > 0 && this.bigSize > 0;
  }

  /**
   * 进入 `preparing` 相位：进度归零、整页透明、清掉旧的终点矩形逼它重新上报。
   *
   * 起点（迷你条）**不清**：首页的 HDS 迷你条不会随播放页开关重新挂载，
   * 拿不到新的上报，沿用上一次的值即可（它本来就没动过）。
   */
  public armExpand(): void {
    this.progress = 0;
    this.bigSize = 0;
    this.preparing = true;
    this.animating = false;
  }

  /** 进入 `animating` 相位：飞行封面登场，迷你条封面与播放页大封面退场。 */
  public beginAnimating(): void {
    this.preparing = false;
    this.animating = true;
  }

  /** 展开动画播完：交还给静态布局。 */
  public finishAnimating(): void {
    this.animating = false;
    this.progress = 1;
  }

  /** 回到「已展开的静止态」。测量失败、宿主卸载、收起结束时都走这里。 */
  public reset(): void {
    this.preparing = false;
    this.animating = false;
    this.progress = 1;
  }

  /** 请求播放反向（收起）动画。播放页的返回按钮调用它，不要自己置 `isShowPlay`。 */
  public requestCollapse(): void {
    this.collapseVersion = this.collapseVersion + 1;
  }

  // ───────────────────────── 逐帧取值（build 里直接调）─────────────────────────

  /** @returns 当前进度下飞行封面的左边界（vp，窗口坐标）。 */
  public coverX(): number {
    return this.lerp(this.miniX, this.bigX, this.progress);
  }

  /** @returns 当前进度下飞行封面的上边界（vp，窗口坐标）。 */
  public coverY(): number {
    return this.lerp(this.miniY, this.bigY, this.progress);
  }

  /** @returns 当前进度下飞行封面的边长（vp）。 */
  public coverSize(): number {
    return this.lerp(this.miniSize, this.bigSize, this.progress);
  }

  /** @returns 当前进度下飞行封面的圆角（vp）。 */
  public coverRadius(): number {
    return this.lerp(this.miniRadius, this.bigRadius, this.progress);
  }

  /**
   * @returns 飞行封面不透明度：动画期间可见。
   *
   * ★★ 2026-10-15（**已判定为死代码**，`RzdMusic记忆.md` §60）：**零调用者**，
   *   而且它读的 `animating` 属**旧转场**那一族（同 {@link clipActive}）——
   *   活的形变里"封面谁在画"由 `realCoverVisible()`（播放页真封面）
   *   与 `morphOverlayBridging()`（壳层克隆封面）**严格互补的一对门**决定，
   *   没有任何地方用"旧转场的 `animating`"来淡入淡出封面。
   * ⚠️ 同族的 {@link miniCoverOpacity}（读同一个 `animating`）**也是零调用者**。
   * @deprecated 零调用者。封面的显隐请用 {@link realCoverVisible} / {@link morphOverlayBridging}。
   * 复核命令：`grep -rn 'coverOpacity()\|miniCoverOpacity()' RzdMusic --include=*.ets`
   */
  public coverOpacity(): number {
    return this.animating ? 1 : 0;
  }

  /** @returns 迷你条封面不透明度：动画期间隐藏，避免与飞行封面重影。 */
  public miniCoverOpacity(): number {
    return this.animating ? 0 : 1;
  }

  /** @returns 播放页大封面不透明度：动画期间隐藏（飞行封面顶替它）。 */
  public innerCoverOpacity(): number {
    return this.animating ? 0 : 1;
  }

  /**
   * @returns 播放页整页不透明度。
   *
   * - `preparing`：0 —— 页面已挂载但绝不能露出来（这就是防闪的那一相位）；
   * - `animating`：前 45% 淡入 —— 否则动画开头迷你条那一小块里会糊着播放页底部控件；
   * - 其余：1。
   */
  public pageOpacity(): number {
    if (this.preparing) {
      return 0;
    }
    if (!this.animating) {
      return 1;
    }
    return Math.min(1, this.progress / 0.45);
  }

  /**
   * ★★ 2026-10-15（**已判定为死代码**，`RzdMusic记忆.md` §59）：本体是"旧转场"那一族的残留。
   *
   * 本类里 `preparing` / `animating` / `progress` 三个字段（L202-206）属**更早的那套
   * 「整页淡入 + 贴底上滑」转场**；活的形变链走的是 `morphStage` / `morphP` / `applyMorphProgress()`，
   * **完全不读它们**（见 L1164 那段注释）。本方法只在它们之上做了一次或运算 ⇒ 同样没有调用者。
   *
   * ⚠️ **故意保留而不是删除**：它与 `morphClipping()`（活的裁剪门）语义上有重叠，
   *    删除时若有人误把调用点从 `morphClipping()` 换成它、或反过来，就会动到裁剪行为。
   *    留在这里的代价只是几行；把它变成"活的"才是风险。
   * @deprecated 无调用者。要用裁剪门请用 {@link morphClipping}。
   * @returns 旧转场相位是否处于"需要裁剪"。
   * 复核命令：`grep -rn 'clipActive' RzdMusic --include=*.ets`（期望：只有本处定义）
   */
  public clipActive(): boolean {
    return this.preparing || this.animating;
  }

  /**
   * @returns clip 窗口的 SVG path 命令（单位 vp，作用在播放页宿主自己的坐标系上）。
   *
   * 静止态直接给一个远大于窗口的矩形：只要有一个尺寸算错就会把播放页裁掉一块，
   * 宁可不裁。动画期间才逐帧做圆角矩形插值。
   */
  public clipCommands(): string {
    if (this.progress >= 1) {
      return PlayerExpandState.roundedRectPath(-4000, -4000, 8000, 8000, 0);
    }
    const t: number = this.progress;
    const m: number = CLIP_IDLE_MARGIN_VP;
    const x: number = this.lerp(this.miniX, -m, t);
    const y: number = this.lerp(this.miniY, -m, t);
    const w: number = Math.max(1, this.lerp(this.miniSize, this.windowWidthVp + m * 2, t));
    const h: number = Math.max(1, this.lerp(this.miniSize, this.windowHeightVp + m * 2, t));
    return PlayerExpandState.roundedRectPath(x, y, w, h, this.coverRadius());
  }

  /** @returns 线性插值。 */
  private lerp(from: number, to: number, t: number): number {
    return from + (to - from) * t;
  }

  /**
   * 圆角矩形的 SVG path 命令。
   * @param x 左上角 x
   * @param y 左上角 y
   * @param w 宽
   * @param h 高
   * @param r 圆角（会自动夹到短边的一半以内，否则 path 自交会画歪）
   * @returns path 命令字符串
   */
  private static roundedRectPath(x: number, y: number, w: number, h: number, r: number): string {
    const x1: number = x + w;
    const y1: number = y + h;
    const safeR: number = Math.max(0, Math.min(r, Math.min(w, h) / 2));
    if (safeR <= 0.01) {
      return `M${x} ${y} H${x1} V${y1} H${x} Z`;
    }
    return `M${x + safeR} ${y} H${x1 - safeR} A${safeR} ${safeR} 0 0 1 ${x1} ${y + safeR} ` +
      `V${y1 - safeR} A${safeR} ${safeR} 0 0 1 ${x1 - safeR} ${y1} H${x + safeR} ` +
      `A${safeR} ${safeR} 0 0 1 ${x} ${y1 - safeR} V${y + safeR} A${safeR} ${safeR} 0 0 1 ${x + safeR} ${y} Z`;
  }
}
