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

  /** 记录窗口尺寸（vp），作为 clip 窗口展开的终点。 */
  public reportWindow(widthVp: number, heightVp: number): void {
    if (widthVp > 0 && heightVp > 0) {
      this.windowWidthVp = widthVp;
      this.windowHeightVp = heightVp;
    }
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
   * @param value 进度
   * @param from 区间起点
   * @param to 区间终点
   * @returns 归一化值
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
   * 第一组（小歌词 + 收藏按钮）的时间窗。
   *
   * ⚠️ 顺序依据（用户 2026-10-15 原话）：「**先飞入的是小歌词和收藏按钮**」。
   */
  public static readonly WIN_A_START: number = 0.30;
  public static readonly WIN_A_END: number = 0.52;
  /**
   * 第二组（进度条 + 底部按钮 = 整片控制区）的时间窗。
   *
   * ⚠️ 顺序依据（同一句）：「**进度条和下面的那堆按钮一起飞入**」——它们**是一组**，
   *    所以这里只有一个窗口，不要再给进度条单独错峰（上一版就是那么做错的）。
   */
  public static readonly WIN_B_START: number = 0.60;
  public static readonly WIN_B_END: number = 0.90;
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

  // ⚠️ **收起方向：无界是 `REVERSE_MS = 460` + `REVERSE_EASING = "cubic-bezier(0.85, 0, 0.5, 0.88)"`
  //    （`_recover\logic-src\ExpandAnimation驱动与补间定稿.md` §三「两套时长表的真实关系」：
  //     `ENTER_MS` / `REVERSE_MS` **同属 `MainPage` 那一层**，即与 560 同源；
  //     `_recover\logic-src\pullT写入算式与形变枚举.md` §五 常量全集亦列了这两个值）
  //    —— 本轮**有意不落地，只标注**，理由是**量化过的、且是本架构的硬约束**：
  //      · 浮层这一棒**只活到 `morphLand()`**（`morphBridging()` 在 LANDING 为假）；
  //        收起时播放页那层是 `PlaybackPage.MORPH_CLOSE_DURATION_MS = 350` + 20 ⇒
  //        浮层实际只有 ~370ms 可画；
  //      · 用现有的 560 + `(0.23,1,0.32,1)`：t=0.661 处曲线已到 **≈99%** ⇒ 撤掉时几乎无跳变；
  //      · 换成 460 + `(0.85,0,0.5,0.88)`：同一时刻只到 **≈87%** ⇒ 撤掉瞬间会有
  //        **约 12% 行程的"啪"一下**（封面朝迷你条方向弹一小段）—— 这正是 §48/§51 反复
  //        出问题的那类尾跳。
  //    ⇒ 想真正对齐这两条值，得先让**浮层的存活期跟它自己的时长对齐**（那会破坏 §60.5 ⑤
  //      "同一时刻至多一张封面"的严格互补：浮层多活一帧就与真封面同时在场）。
  //      这一条**留待真机**：先看 `morph overlay tween done` 与收起落位的时间差，再定。
  //      依据行：`docs\无界形变手感-落实到RzdMusic清单.md` §一 1.6 的"收起方向 460"那一行。

  // ⚠️ 这里**没有** `morphOverlayCurve()` 这类返回 `ICurve`/`UIShape` 的包装函数 —— 故意的：
  //   本机 SDK 里 `ICurve`（`component/common.d.ts:4154`）**唯独它没写 `declare`**
  //   （同文件其它接口都是 `declare interface`）⇒ 它不是全局可见的；`@kit.ArkUI` 也**没有**
  //   导出 `UIShape`（编译实测：`Module '"@kit.ArkUI"' has no exported member 'UIShape'`）。
  //   ⇒ 曲线**就在唯一那个 `animateTo` 的调用点上内联写**，与工程里既有的两处同款
  //   （`products/default .../Index.ets:611`、`PlaybackPage.ets:1350`）：
  //       curve: curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)
  //   改这条曲线只改那**一处**（`morphOverlayTweenTo` 里），不要另起包装。

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
   * 与第一组同一套公式、只是窗口更晚 ⇒ 展开时"小歌词+收藏"先上来、"控制区"后上来。
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
   * @returns 播放页**真封面**是否该画。
   *
   * 形变期间由续飞封面代表它；形变容器一撤（相位回到 OPEN/NONE）就地交棒 ——
   * 交棒那一刻容器是恒等变换、续飞封面正好落在真实封面上，所以看不到跳变。
   *
   * ⚠️ 不要再引入"p ≥ 某阈值就提前交棒"：续飞封面的矩形是**窗口坐标**，
   *    容器还没撤时把两者对调一定错位（真机实测过，见 `morphBridging()` 注释）。
   */
  public realCoverVisible(): boolean {
    return !this.morphContainerActive();
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
   */
  private static readonly LYRIC_COVER_EDGE_VP: number = 48.72;
  /** 歌词页封面顶部相对展开页封面顶部的下移比例（占展开页封面高度）。 */
  private static readonly LYRIC_COVER_TOP_RATIO: number = 0.06;
  /** 封面圆角占其短边的比例（展开页那一端）。 */
  private static readonly COVER_RADIUS_RATIO: number = 0.06;

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

  /** @returns 歌词页封面左边界：水平居中。 */
  public lyricCoverXOf(): number {
    return (this.windowWidthVp - this.lyricCoverSizeOf()) / 2;
  }

  /**
   * @returns 歌词页封面上边界。
   *
   * 展开页封面顶部 + 一个下移比例，并且**顶部要避开状态栏**：
   * 直接顶到 0 会被状态栏压住，所以取 `max(状态栏估算值, 计算值)`。
   */
  public lyricCoverYOf(): number {
    const size: number = this.lyricCoverSizeOf();
    const base: number = this.bigY > 0
      ? this.bigY + this.bigSize * PlayerExpandState.LYRIC_COVER_TOP_RATIO
      : this.windowHeightVp * 0.12;
    const statusBarGuard: number = this.windowHeightVp * 0.07;
    return Math.max(base, statusBarGuard);
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
      // 圆角跟着尺寸缩小，避免小尺寸下圆角显得过大（对标 visualRadiusAt）
      radius: this.lerp(fromRect.radius, toSize * PlayerExpandState.COVER_RADIUS_RATIO, p)
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

  // ─────────────── 二·补（A2）：歌词页顶部的「封面 + 歌名」浮层 ───────────────
  //
  // 对标无界 `PlayerPage`：封面与歌名**挂在 Swiper 之外的浮层**上，切到歌词页时
  // 「同一个元素」缩小并移到顶部；歌词正文靠 `lyricPadTop()` 按浮层高度让位。
  // 这里只提供**几何**，怎么画由 `PlaybackPage.LyricFloatLayer()` 决定。

  /** 歌词页浮层里「封面底边 → 歌名块顶边」的间距（vp）。⚠️ 本项目估定值，非逆向值。 */
  private static readonly LYRIC_META_GAP_VP: number = 10;
  /** 歌词页浮层里「歌名 + 歌手」两行所占高度（vp）。⚠️ 本项目估定值，非逆向值。 */
  private static readonly LYRIC_META_BLOCK_H_VP: number = 44;
  /** 歌词页浮层底边与歌词正文之间的呼吸间距（vp）。⚠️ 本项目估定值，非逆向值。 */
  private static readonly LYRIC_PAD_GAP_VP: number = 10;
  /** 浮层几何拿不到时的兜底顶部留白（vp，≈ 一屏的 1/5）。⚠️ 本项目估定值，非逆向值。 */
  private static readonly LYRIC_PAD_TOP_FALLBACK: number = 150;

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

  /** @returns 歌词页歌名块的顶边（vp，窗口坐标）= 封面底边 + 间距。 */
  public lyricMetaYOf(): number {
    return this.lyricCoverYOf() + this.lyricCoverSizeOf() + PlayerExpandState.LYRIC_META_GAP_VP;
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

  /** @returns 歌词页浮层（封面 + 歌名块）整体占用的竖直高度（vp，从窗口顶边量起）。 */
  public lyricOverlayHeight(): number {
    if (!this.lyricFloat()) {
      return 0;
    }
    const size: number = this.lyricCoverSizeOf();
    if (size <= 0) {
      return 0;
    }
    return this.lyricMetaYOf() + PlayerExpandState.LYRIC_META_BLOCK_H_VP;
  }

  /**
   * @returns 歌词页正文必须让位的**顶部内边距**（vp）—— 等价无界的 `lyricPadTop()`。
   *
   * 判据链与无界一致：`!lyricFloat → 0`；浮层高度算不出来 → 兜底常量；
   * 正常 → 浮层高度 + 一点呼吸间距。
   * ⚠️ 中间的 `boxH <= 0` 是**防御分支**（`lyricFloat()` 已经要求封面尺寸 > 0，
   *    正常流程走不到），按无界那份 `lyricPadTop()` 的结构保留。
   */
  public lyricPadTop(): number {
    if (!this.lyricFloat()) {
      return 0;
    }
    const boxH: number = this.lyricOverlayHeight();
    if (boxH <= 0) {
      return PlayerExpandState.LYRIC_PAD_TOP_FALLBACK;
    }
    return boxH + PlayerExpandState.LYRIC_PAD_GAP_VP;
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

  /** 回调更新请求计数（同一时刻只有一个组件挂这个回调，见 `setDragUpdate` 注释）。 */
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

  public metaBridgeOwnsPaint(): boolean {
    return this.metaBridgeActive && this.metaBridgeGeneration === this.morphGen &&
      this.morphSessionDriving();
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
  /** `hostsMorphOverlay()` 的缓存：-1 = 还没判过，0 = 否，1 = 是（见该函数的说明）。 */
  private morphOverlayHostCached: number = -1;

  /**
   * 形变几何是否可用（`morphInitParams()` 的结论）。
   *
   * ⚠️ 必须显式记下来：几何没齐时沿用默认值会把播放页弄成一条细缝
   *    —— 那就是"上拉打开播放器，屏幕上看不到东西"。
   */
  @Trace public morphUsable: boolean = false;
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
    // 宿主矩形只进日志：`MORPH_HOST_ID` 在手机壳里就是播放页自己的根 Stack，
    // 它的高度**就是裁剪窗口高度**，绝不能当"铺满目标"（第五次自噬）。
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
   *   2. 手机侧 `PlaybackPage` 自己的根 Stack 就是 `MORPH_HOST_ID`，它的
   *      `.height(morphClipHeight())` **就是裁剪窗口高度** —— 同一个坑换了个位置又踩一次
   *      （「一块黑底 + 播放页展不开」）。
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

  /** @returns 终点锚点的来源（只给日志用：判断终点是量到的还是退回的 `onAreaChange` 值）。 */
  private endAnchorSource(): string {
    if (this.bigNodeKnown && this.bigNodeW > 0) {
      return 'frameNode';
    }
    if (this.bigSize > 0) {
      return 'areaChange';
    }
    return 'none';
  }

  /** @returns 两端的几何是否都量到了（可以走形变路径）。 */
  public morphReady(): boolean {
    return this.miniSize > 0 && this.bigSize > 0 && this.morphBoxWidth() > 0 && this.morphBoxHeight() > 0;
  }

  /** @returns 形变窗口当前是否有效（静止态 false，调用方该用 `'100%'`）。 */
  public morphClipping(): boolean {
    return this.morphUsable && this.morphContainerActive();
  }

  /** @returns 宿主（= 内容层固定尺寸）宽度（vp）。 */
  public morphHostW(): number {
    return this.morphBoxW > 0 ? this.morphBoxW : this.morphBoxWidth();
  }

  /** @returns 宿主（= 内容层固定尺寸）高度（vp）。 */
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
    }
    // 已有起点就继续等待目标挂载，调用方不能把首次上拉直接落位。
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

  /** 上拉打开的**进度**提交阈值（0…1）：超过它就展开到底。 */
  public static readonly PULL_OPEN_COMMIT_FRACTION: number = 0.45;
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
  // ⚠️⚠️ **这两个数与 `PULL_OPEN_COMMIT_FRACTION` 只能一起改**，而且**必须先上机实测**：
  //   `PlaybackPage` 原注释（现行版本已随本收敛一起搬到这里）明确写着
  //   "无界是 `COMMIT_T = 0.32`，这里保持 0.42 / 0.45，标注『待实测』…**不许按无界的值直接覆盖**"。
  //   两个方向现在的**手指绝对位移**量级（`派音动画Bug清单.md` §6.5 的表）：
  //     打开提交 ≈ `0.45 × barY`；收起提交 ≈ `0.38 × miniY`（`barY ≈ miniY`）
  //   ⇒ 收起其实**比打开更容易**（约 −16%），不是"收起更难"。
  //   二者都**不等于**无界的 0.32；要不要对齐只能靠真机手感，**读代码定不了**。

  /**
   * 下拉松手时的**进度**提交阈值（0…100，占 {@link PlayerExpandState.DISMISS_DRAG_SPAN_RATIO}
   * 或实测 `miniY` 那把尺子的百分比）：超过它就收起，否则弹回完整态。
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
   * ⚠️ 为什么不再另加"进度 ≥ 某阈值就停笔"：浮层这一棒早于播放页落位
   *   （560ms + 20ms 收尾 vs 播放页 350ms + 30ms），末尾那几十毫秒里两端进度都已经是 1、
   *   矩形逐像素相同，停笔时**没有可跳的差**；而多一个阈值就会重新引入"半路消失"那类 bug。
   */
  public morphOverlayBridging(): boolean {
    if (!this.hostsMorphOverlay()) {
      return false;
    }
    return this.morphBridging();
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
    this.morphOverlayTweenTo(true, ui);
  }

  /**
   * 播放页侧开始**收起**了 ⇒ 浮层也跟着回起点（走它自己的 560ms）。
   * @param ui 壳层的 UIContext
   */
  public focusMorphOverlayForPageCollapse(ui: UIContext): void {
    if (!this.hostsMorphOverlay()) {
      return;
    }
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
    Logger.info(PlayerExpandState.logTag,
      `morph overlay tween start from=${from.toFixed(3)} to=${to} ` +
        `ms=${PlayerExpandState.MORPH_OVERLAY_DURATION_MS} gen=${gen}`);
    ui.animateTo({
      duration: PlayerExpandState.MORPH_OVERLAY_DURATION_MS,
      // ★ 浮层这一层**单独**的时长/曲线（对标无界 `animateMorphT` 的 ENTER_MS + EASE_OUT_STR）。
      //   ⚠️ 曲线内联写在这里，别抽成返回 `ICurve`/`UIShape` 的包装函数（那两个类型在本机 SDK
      //      里都不是全局可见的，见文件顶部 `MORPH_OVERLAY_DURATION_MS` 旁边那段说明）。
      curve: curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)
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
   * @param ui UIContext
   * @param id 组件 id
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

  /** @returns 整页不透明度：0（还在迷你条那一小块、不可见）→ 1（完全铺开）。 */
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
    // ★ 浮层那一层在**非形变期**跟着播放页一起复位（避免"残留进度画一帧大封面"）。
    //   ⚠️ 判据是 `!morphContainerActive()` —— **不能在形变期无条件复位**：
    //      · 起手那一刻（`morphBeginEntering` / `pullOpenBegin`）已经进了 ENTERING，
    //        所以这里不复位；浮层的起点由壳层那两处显式压回 0
    //        （`onPullOpenStart` 跟手起手 / `settlePullOpen` 起补间）；
    //      · 而"落位后又被调用一次"（`morphSettleOpen` 里的 `applyMorphProgress(1)`）
    //        发生在相位已经是 OPEN（容器不活跃）时 —— 那时复位也无害：浮层这份本来就不画了
    //        （`morphOverlayBridging()` 已经 false），下一轮起手会重新压 0。
    //      这条复位的真正价值是兜住"异常路径直接落位/卸载"那种没人显式复位的情况。
    if (!this.morphContainerActive()) {
      this.morphOverlayReset();
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

  /** @returns 形变是否"活着"（对标 `morphLiveOf`：ENTERING / LEAVING / LANDING）。 */
  public morphLive(): boolean {
    return this.morphStage === MorphStage.ENTERING || this.morphStage === MorphStage.LEAVING ||
      this.morphStage === MorphStage.LANDING;
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

  /** 控制区档位：0=紧凑(手机) 1=标准(折叠/小平板) 2=宽松(平板/桌面)。 */
  @Trace public chromeTier: number = 0;

  /**
   * 按窗口宽度决定控制区档位（对标 `playerChromeTierFor`）。
   * @param widthVp 窗口宽度（vp）
   */
  public updateChromeTier(widthVp: number): void {
    const tier: number = widthVp >= 840 ? 2 : (widthVp >= 600 ? 1 : 0);
    if (tier !== this.chromeTier) {
      this.chromeTier = tier;
    }
  }

  /** @returns 控制区上下内边距（vp），随档位变。 */
  public chromePaddingVp(): number {
    return this.chromeTier === 0 ? 10 : (this.chromeTier === 1 ? 14 : 18);
  }

  /** @returns 控制区按钮间距（vp）。 */
  public chromeGapVp(): number {
    return this.chromeTier === 0 ? 18 : (this.chromeTier === 1 ? 24 : 30);
  }

  /** 控制区是否被自动收起（对标 `BarCollapse.isCollapsed`）。 */
  @Trace public chromeCollapsed: boolean = false;
  /** 最后一次用户操作控制区的时间戳（ms）。 */
  private lastChromeTouchMs: number = 0;
  /** 静止多久后自动收起（ms）。 */
  private static readonly CHROME_AUTO_HIDE_MS: number = 3000;

  /** 记录一次控制区交互（点击/滑动），重置自动收起计时。 */
  public touchChrome(): void {
    this.lastChromeTouchMs = Date.now();
    this.chromeCollapsed = false;
  }

  /** @returns 现在是否到了该自动收起控制区的时间。 */
  public chromeShouldAutoHide(): boolean {
    if (this.chromeCollapsed || this.lastChromeTouchMs <= 0) {
      return false;
    }
    return Date.now() - this.lastChromeTouchMs >= PlayerExpandState.CHROME_AUTO_HIDE_MS;
  }

  /** 自动收起控制区。 */
  public collapseChrome(): void {
    this.chromeCollapsed = true;
  }

  /** 唤出控制区。 */
  public revealChrome(): void {
    this.lastChromeTouchMs = Date.now();
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

  /** @returns 飞行封面不透明度：动画期间可见。 */
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
   * @returns 现在是否需要给播放页套 clip 窗口。
   *
   * **静止态返回 false**，这一点很重要：此时播放页完全不裁剪，与"没有这个动画"时的
   * 布局逐字节一致 —— 万一这套 path 裁剪在某些 SDK/设备上表现异常（比如把整页裁没），
   * 影响范围也只有动画那 0.5 秒，绝不会导致"播放器打不开"。
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
