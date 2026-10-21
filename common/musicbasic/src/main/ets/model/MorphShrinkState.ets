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

import { image } from '@kit.ImageKit';
import { UIContext } from '@kit.ArkUI';
import { Logger } from '../util/Logger';

/**
 * ★★★★ 2026-10-17（照搬无界 `design/src/main/ets/animation/ShrinkOverlay.ets`）：
 * **非手势关闭**（左上角关闭按钮 / 系统返回）的那一棒 —— 缩的不是活页面，而是**一张满窗快照**。
 *
 * ## 为什么必须照搬它（用户第 ② 条「有背景但是高度特低」的真正机制）
 *
 * 无界的两条关闭路**完全不是一回事**（`_recover/logic-src/交付物交叉核对记录.md` §9.8 已逐字节核对）：
 * ```
 *   MainPage.closeWithAnimation()                      （wujie.pa:171054-171095）
 *     if (pullMode && ExpandSnapshot.onReverseMorph(myMorphSnap)) return;   // ① 下拉那条路：自己处理
 *     getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, λ@1*#);     // ② 否则：拍快照
 *   λ@1*#（wujie.pa:181020-181077）：
 *     失败 ⇒ hilog.warn('root snapshot failed, fallback: …') + nav.pop()   （无参 = 不带转场）
 *     成功 ⇒ ExpandSnapshot.onShrinkBack(pixmap, mySrcBox) + nav.pop(false)
 *   onShrinkBack → ShrinkOverlay.start(...)   ← 就是本文件
 * ```
 * 而**活页面在那一刻已经 `nav.pop` 走了** ⇒ 缩的是一张**图**，
 * 图里的背景与封面**同比例一起缩** ⇒ **不可能**出现"背景被裁成一条"这种形状。
 *
 * 我们这一侧一直是"**动活的播放页**"（改裁剪窗口 + 缩放），于是只要
 * "裁剪窗口高度"与"缩放"有一点不同步，屏上就是「有背景、但只剩很矮的一条」。
 * ⇒ 这就是用户第 ② 条的机制，也是本文件存在的理由。
 *
 * ## 逐条对照（★ 常量与公式都是**回原始 abc 逐条重读**的，不是照抄那份语句级反编译）
 *
 * 反编译（`_recover/logic-src/design__src__main__ets__animation__ShrinkOverlay.ets`）
 * 会把"数值槽"与"字符串槽"混起来打印（出现 `"WantingMusic-Shrink".toFixed(3)`、
 * `clipH=90.toFixed(2)` 这种形状）⇒ 本轮回 `disasm/wujie.pa` 重读了 `func_main_0`
 * （`53094-53111`）、`start`（`52716-53001`）、`λ1`（`53006-53040`）、
 * `λ1^1`（`53045-53051`）、`onFinish`（`53056-53089`）：
 *
 * ```
 *   模块常量（func_main_0）：D_SHRINK=0x15e=350 / START_RADIUS=0x22=34 /
 *                            FADE_DELAY=0x104=260 / FADE_DURATION=0x5a=90
 *   λ1 末尾：radius = 0x10 = 16                       ← END_RADIUS
 *   两条补间：① duration=D_SHRINK, curve=Curve.EaseInOut, onFinish=λonFinish
 *             ② delay=FADE_DELAY, duration=FADE_DURATION, curve=Curve.Sharp
 * ```
 *
 * `start` 的几何（原始字节码 `52748-52818`，按 `acc = vN OP acc` 逐条解）：
 * ```
 *   winW = WindowInfo.windowWidth_px                （px）
 *   winH = WindowInfo.windowHeight_px               （px）
 *   endScale = capsule.width / winW
 *   endClipH = px2vp(capsule.height / endScale)
 *   endTx    = px2vp(capsule.left − (winW − capsule.width) / 2)
 *   endTy    = px2vp(capsule.top  − (capsule.height / endScale − capsule.height) / 2)
 * ```
 * ★ **本处直接收 vp（不是 px），四个式子的结果逐位相同** —— 证明（设 `k = px/vp`，即 `px2vp(x)=x/k`）：
 * ```
 *   endScale' = (k·w_vp)/(k·W_vp) = w_vp/W_vp                        （比值，与 k 无关）
 *   endClipH' = px2vp(k·h_vp/endScale) = (k·h_vp/endScale)/k = h_vp/endScale
 *   endTx'    = px2vp(k·x_vp − (k·W_vp − k·w_vp)/2) = x_vp − (W_vp − w_vp)/2
 *   endTy'    = y_vp − (h_vp/endScale − h_vp)/2
 * ```
 * ⇒ 单位统一成 vp 只是**省掉两次 px↔vp 往返**，不是"改算法"。
 * ⚠️ 本仓的量测（`PlayerExpandState.barWin*`）本来就是 vp，`vp2px` 再 `px2vp` 纯属浪费。
 *
 * 起始态（`52819-52852`）：
 * ```
 *   scale=1 / translate=(0,0) / clipHeight=px2vp(winH)=winH_vp / radius=34 / opacity=1 / visible=true
 * ```
 * ⇒ **起始态与"满屏播放页"逐像素对齐**（这一条是这套动画成立的前提：
 *   快照就是满屏那一张，不需要任何"起点对齐"补偿）。
 *
 * 宿主节点长什么样（`wujie.pa:162465-162707`，`MainPage` 里那个 `If`）：
 * ```
 *   If (shrink.visible && shrinkPixmap !== undefined) {
 *     Column()
 *       .width('100%')                       // = 整窗宽（父 Stack 左上角对齐）
 *       .clip(true)                          // ← 裁剪窗口：宽恒为整窗、高随动画变
 *       .height(shrink.clipHeight)
 *       .borderRadius(shrink.radius)
 *       .scale({ x: shrink.scaleValue, y: shrink.scaleValue })
 *       .translate({ x: shrink.translateX, y: shrink.translateY })
 *       .opacity(shrink.opacity)
 *       .hitTestBehavior(HitTestMode.None)
 *       { Image(shrinkPixmap)
 *           .width(px2vp(windowWidth_px)).height(px2vp(windowHeight_px))   // ← 图恒为整窗
 *           .objectFit(ImageFit.Cover).syncLoad(true) }
 *   }
 * ```
 * ★ 终点几何的正确性可以对账（这也是为什么 `endTx/endTy` 长那个样子）：
 *   `Column` 未缩放时占 `x∈[0,W], y∈[0,C]`（`C = endClipH = h/s`），
 *   `scale` 默认**绕自身中心**：
 * ```
 *   缩放后宽 = W·s = w        ✓ 等于胶囊宽
 *   缩放后高 = C·s = h        ✓ 等于胶囊高
 *   左边界 = W/2 − W·s/2 = (W − w)/2  ⇒ 要落在 x_vp 需 translateX = x_vp − (W − w)/2  ✓ = endTx
 *   上边界 = C/2 − C·s/2 = (h/s − h)/2 ⇒ 需 translateY = y_vp − (h/s − h)/2        ✓ = endTy
 * ```
 *
 * ⚠️ **本文件目前还没接线**（没有调用者）—— 见 `RzdMusic记忆.md` §127 的施工图。
 *    写实现与接线**分两步**，是为了让"有回归风险的那一半"单独一轮做。
 *    `/!\` 在接线之前，本文件对运行期**零影响**。
 */

/** 胶囊（迷你条）的**渲染矩形**，px、窗口坐标 —— 无界的 `srcBox`。 */
export interface MorphShrinkRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

/**
 * 无界 `ShrinkOverlay` 的状态与驱动。
 *
 * ⚠️ 无界那一侧是 `@Observed`（V1）+ `ObservedPropertyObjectPU`；本仓**只用 V2**
 *    ⇒ 这里用 `@ObservedV2` + `@Trace`。字段名与无界逐字一致，便于对照。
 */
@ObservedV2
export class MorphShrinkState {
  /** 无界 `D_SHRINK = 0x15e`（`wujie.pa:53104`）—— 缩小那一棒的时长。 */
  public static readonly D_SHRINK: number = 350;
  /** 无界 `START_RADIUS = 0x22`（`wujie.pa:53106`）—— 起始圆角（= 满屏播放页那一份）。 */
  public static readonly START_RADIUS: number = 34;
  /** 结束圆角 `0x10`（`λ1` 末尾，`wujie.pa:53037`）= 迷你条胶囊那一份。 */
  public static readonly END_RADIUS: number = 16;
  /** 无界 `FADE_DELAY = 0x104`（`wujie.pa:53108`）—— 淡出**延迟**。 */
  public static readonly FADE_DELAY: number = 260;
  /** 无界 `FADE_DURATION = 0x5a`（`wujie.pa:53110`）—— 淡出**时长**。 */
  public static readonly FADE_DURATION: number = 90;

  /** 无界 `ov.visible`：浮层是否在画（`onFinish` 里清）。 */
  @Trace public visible: boolean = false;
  /** 无界 `ov.scaleValue`。 */
  @Trace public scaleValue: number = 1;
  /** 无界 `ov.translateX`（vp）。 */
  @Trace public translateX: number = 0;
  /** 无界 `ov.translateY`（vp）。 */
  @Trace public translateY: number = 0;
  /** 无界 `ov.clipHeight`（vp）—— 浮层的裁剪窗口高（起始 = 整窗）。 */
  @Trace public clipHeight: number = 0;
  /** 无界 `ov.radius`。 */
  @Trace public radius: number = MorphShrinkState.START_RADIUS;
  /** 无界 `ov.opacity`。 */
  @Trace public opacity: number = 1;
  /**
   * 要缩的那张图（无界的 `MainPage.shrinkPixmap`，`wujie.pa:144006`）。
   * ⚠️ 无界放在 `MainPage` 上（浮层宿主在壳层）；本仓同样由**壳层**持有与渲染。
   */
  @Trace public pixmap: image.PixelMap | undefined = undefined;

  /** 无界 `ov.gen` —— 世代号，用来丢弃过期的 `onFinish`。 */
  private gen: number = 0;

  /**
   * 无界 `reset()`（`wujie.pa:52691-52715`）：
   * `gen++` / `visible=false` / `opacity=1` / `scale=1` / `translate=(0,0)`。
   * ⚠️ 它**不清 `clipHeight` 与 `radius`**（与无界逐字一致：那两项只由 `start` 写）。
   */
  public reset(): void {
    this.gen = this.gen + 1;
    this.visible = false;
    this.opacity = 1;
    this.scaleValue = 1;
    this.translateX = 0;
    this.translateY = 0;
    this.pixmap = undefined;
  }

  /**
   * 无界 `start(ui, ov, srcBox, onDone)`（`wujie.pa:52716-53001`）。
   *
   * ⚠️ **单位**：无界传的是 **px**（`WindowInfo.*_px` + 胶囊的 px 渲染矩形），
   *    这里传 **vp** —— 见文件头那段代数证明（四个式子的结果逐位相同）。
   *
   * @param ui UIContext（`animateTo` 用）
   * @param pixmap 已经拍好的**满窗快照**（调用方在 `componentSnapshot.get` 成功回调里传进来）
   * @param srcBoxVp 胶囊的**窗口矩形**（vp）—— 无界的 `srcBox`
   * @param winWVp 窗口宽（vp）
   * @param winHVp 窗口高（vp）
   * @param onDone 无界那个 `a5` 回调：`onFinish` 收尾时调一次
   *
   * ⚠️ `srcBox` 量不到那一支（`52723-52747`）无界也会走到：它
   *   `hilog.warn('start skipped: no srcBox')` + `visible = false` + 调 `onDone()`。
   *   本处用"宽或高 ≤ 0"等价表达（ArkTS 的参数不会真的 `undefined`，但量不到时会是 0）。
   */
  public start(ui: UIContext, pixmap: image.PixelMap, srcBoxVp: MorphShrinkRect,
    winWVp: number, winHVp: number, onDone: () => void): void {
    if (srcBoxVp === undefined || srcBoxVp.width <= 0 || srcBoxVp.height <= 0 ||
      winWVp <= 0 || winHVp <= 0) {
      Logger.warn(MorphShrinkState.logTag, 'shrink start skipped: no srcBox');
      this.visible = false;
      onDone();
      return;
    }
    // ── 终点几何（`52748-52818` 逐条转写，单位 vp）
    const endScale: number = srcBoxVp.width / winWVp;
    const endClipH: number = srcBoxVp.height / endScale;
    const endTx: number = srcBoxVp.left - (winWVp - srcBoxVp.width) / 2;
    const endTy: number = srcBoxVp.top -
      (srcBoxVp.height / endScale - srcBoxVp.height) / 2;
    // ── 起始态（`52819-52852`）：与满屏播放页逐像素对齐
    this.pixmap = pixmap;
    this.scaleValue = 1;
    this.translateX = 0;
    this.translateY = 0;
    this.clipHeight = winHVp;
    this.radius = MorphShrinkState.START_RADIUS;
    this.opacity = 1;
    this.visible = true;
    this.gen = this.gen + 1;
    const genNow: number = this.gen;
    Logger.info(MorphShrinkState.logTag,
      `shrink START → scale=${endScale.toFixed(3)} clipH=${endClipH.toFixed(2)} ` +
      `tx=${endTx.toFixed(2)} ty=${endTy.toFixed(2)} ` +
      `(capsule l=${srcBoxVp.left.toFixed(1)} t=${srcBoxVp.top.toFixed(1)} ` +
      `${srcBoxVp.width.toFixed(1)}x${srcBoxVp.height.toFixed(1)}) win=${winWVp.toFixed(0)}x${winHVp.toFixed(0)}`);
    // ── 两条补间（`52959-52999`）
    //    ① 350ms EaseInOut：缩到胶囊；`onFinish` 收尾（`53056-53089`）
    //    ② delay 260 / 90ms Sharp：淡出（`53045-53051`）
    ui.animateTo({
      duration: MorphShrinkState.D_SHRINK,
      curve: Curve.EaseInOut,
      onFinish: (): void => {
        if (genNow !== this.gen) {
          return;
        }
        this.visible = false;
        Logger.info(MorphShrinkState.logTag, 'shrink FINISH');
        onDone();
      }
    }, (): void => {
      this.scaleValue = endScale;
      this.translateX = endTx;
      this.translateY = endTy;
      this.clipHeight = endClipH;
      this.radius = MorphShrinkState.END_RADIUS;
    });
    ui.animateTo({
      delay: MorphShrinkState.FADE_DELAY,
      duration: MorphShrinkState.FADE_DURATION,
      curve: Curve.Sharp
    }, (): void => {
      this.opacity = 0;
    });
  }

  /** 日志 tag（无界那侧是 `"WantingMusic-Shrink"`，本仓统一 `Rzd` 前缀）。 */
  public static readonly logTag: string = 'RzdShrinkOverlay';

  /**
   * ★ 2026-10-17：丢掉那张满窗快照的引用源 —— 照搬 `MainPage` 的 `λ@12*#`
   * （`wujie.pa:154940-154949`：`miniHidden = false; shrinkPixmap = undefined;`）。
   *
   * ⚠️ **必须在浮层收尾时调**（`start` 的 `onDone` 里），否则那张
   *   **满窗 PixelMap**（1080×2400×4B ≈ 10MB 级）会被共享状态一直引用 ⇒ 不会被回收。
   *   `start` 的 `onFinish` 只把 `visible` 置假（浮层节点因此卸载），
   *   **引用本身要由调用方在 `onDone` 里丢** —— 无界就是这么分工的
   *   （`ShrinkOverlay.onFinish` 只 `visible = false` + 回调；清 `shrinkPixmap` 在 `MainPage` 那侧）。
   * ⚠️ 本仓**只丢引用、不 `release()`** —— 与无界逐字一致，也避开"节点还引用着就被释放"
   *   那一帧的风险（节点卸载后由 GC 回收 native 内存）。
   */
  public clearPixmap(): void {
    this.pixmap = undefined;
  }
}
