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

/**
 * 播放页背景底座：**网格形变背景**（照搬无界音乐 1.2.4 的 `design/components/MeshCoverBg.ets`）。
 *
 * 结构（与无界逐项对应）：
 * ```
 * Stack(alignContent: TopStart) .w/.h 100% .transition(entryFade ? OPACITY.animation(400) : IDENTITY)
 *   ├─ NodeContainer(controller) .w/.h 100% .onAreaChange(→ controller.resize)
 *   │    └─ 自定义 RenderNode.draw(context):
 *   │         field.update(tSec, w, h, flow)            ← MeshField（算法层已照搬）
 *   │         canvas.drawPixelMapMesh(src, meshW, meshH, vertices, 0, null, 0)
 *   └─ if (scrim) Column .radialGradient(center 50%/50%, radius 70%,
 *                                        #26000000@0 → @0.45 → #66000000@1)
 * ```
 *
 * 帧驱动：`displaySync`，`{ expected: 20, min: 12, max: 24 }`；闸门 = `playing && active`
 * （**暂停即停帧**，无界也是这么做的）。
 *
 * ★★ 与无界的一处**有意不同**：无界的 `coverPath` 必须是**本地文件路径**（它内部 `fs.openSync` 解码），
 *   本实现直接收**已经解码好的 `PixelMap`** ⇒ 不必落盘、不必管 URL/资源之分。
 *   `PixelMap` 的**生命周期归调用方**（本组件只引用、不 `release()`），避免双重释放。
 *
 * 依据：`_recover/logic-src/播放页背景-MeshGradient与MeshSource定稿.md`（§2 算法、§3 取图）
 * 与 `Cover族与次级UI定稿.md` §3（组件面）。
 */

import { DrawContext, FrameNode, NodeController, RenderNode, UIContext } from '@kit.ArkUI';
import { drawing, displaySync } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MeshField } from '../util/MeshGradient';

/** 每格细分数（无界 `MESH_SUB`）。 */
const MESH_SUB: number = 4;
/** 入场淡入时长（无界 `FADE_MS`）。 */
const FADE_MS: number = 400;
/** 帧率区间（无界 `FPS_EXPECTED / FPS_MIN / FPS_MAX`）。 */
const FPS_EXPECTED: number = 20;
const FPS_MIN: number = 12;
const FPS_MAX: number = 24;
/** 径向暗角两端色（无界 `SCRIM_CENTER` / `SCRIM_EDGE`）。 */
const SCRIM_CENTER: string = '#26000000';
const SCRIM_EDGE: string = '#66000000';
const HIT_FULL: string = '100%';

const TAG: string = 'RzdMeshCoverBg';
const DOMAIN: number = 0x0000;

/** 真正画网格的渲染节点（对标无界 `MeshRenderNode extends RenderNode`）。 */
class MeshRenderNode extends RenderNode {
  field: MeshField = new MeshField(MESH_SUB);
  src: image.PixelMap | null = null;
  /** 秒（组件侧用 `(Date.now() - startMs) / 1000`）。 */
  tSec: number = 0;
  /** 形变幅度 0..1（`MeshField.update` 内部会夹取）。 */
  flow: number = 1;
  private brush: drawing.Brush = new drawing.Brush();

  draw(context: DrawContext): void {
    const w: number = context.sizeInPixel.width;
    const h: number = context.sizeInPixel.height;
    if (this.src === null || w <= 0 || h <= 0) {
      return;
    }
    this.field.update(this.tSec, w, h, this.flow);
    context.canvas.attachBrush(this.brush);
    try {
      // 7 个实参顺序已核：drawPixelMapMesh(pixelMap, meshW, meshH, vertices, 0, null, 0)
      context.canvas.drawPixelMapMesh(this.src, this.field.meshW, this.field.meshH,
        this.field.vertices, 0, null, 0);
    } catch (err) {
      const e = err as BusinessErrorLike;
      hilog.error(DOMAIN, TAG, 'drawPixelMapMesh failed code=%{public}d msg=%{public}s', e.code, e.message);
    } finally {
      context.canvas.detachBrush();
    }
  }
}

/** 只给日志用的最小错误形状（避免依赖具体异常类）。 */
interface BusinessErrorLike {
  code: number;
  message: string;
}

/** 把 `MeshRenderNode` 挂进视图树（对标无界 `MeshBgController extends NodeController`）。 */
class MeshBgController extends NodeController {
  node: MeshRenderNode = new MeshRenderNode();
  private root: FrameNode | null = null;
  private rootRender: RenderNode | null = null;
  private w: number = 0;
  private h: number = 0;

  makeNode(uiContext: UIContext): FrameNode | null {
    const frame: FrameNode = new FrameNode(uiContext);
    const render: RenderNode | null = frame.getRenderNode();
    if (render !== null) {
      render.appendChild(this.node);
      this.rootRender = render;
    }
    this.root = frame;
    this.resize(this.w, this.h);
    return frame;
  }

  /** @returns 节点是否已经挂上（帧回调用它挡掉"还没 makeNode"的那几帧）。 */
  hasRoot(): boolean {
    return this.root !== null;
  }

  resize(w: number, h: number): void {
    this.w = w;
    this.h = h;
    if (w <= 0 || h <= 0) {
      return;
    }
    this.node.frame = { x: 0, y: 0, width: w, height: h };
    if (this.rootRender !== null) {
      this.rootRender.frame = { x: 0, y: 0, width: w, height: h };
    }
    // ★★★★ 2026-10-17（**尺寸一变就补一帧** —— 修用户实测「懒播放时背景始终是黑的」）
    //   `RenderNode` 的内容只在 `invalidate()` 之后才会重画。原来只有 `displaySync` 的帧回调
    //   （闸门 = `playing && active`）会 invalidate ⇒ **暂停态根本没有帧**，而 `aboutToAppear`
    //   那一次 `onFrameNow()` 又可能跑在 `makeNode`/首次布局**之前**（`hasRoot()` 还是假）
    //   ⇒ 那一帧被丢掉 ⇒ 之后没有任何人再叫它 ⇒ 屏上一直是空的（用户看到的就是"黑"）。
    //   ⇒ 只要**尺寸到位**（说明节点已经挂上、布局也出来了）就立刻补一帧，与播放状态无关。
    this.node.invalidate();
  }
}

/**
 * 播放页背景底座（网格形变 + 径向暗角）。
 *
 * 用法（宿主负责把封面解成 64×64 的 `PixelMap`，见 `PlaybackPage` 的取图链）：
 * ```ts
 * MeshCoverBg({ src: this.meshSrc, srcVersion: this.meshSrcVersion, playing: this.state.isPlay, active: this.state.isShowPlay })
 * ```
 * ⚠️ `src` 是 `PixelMap` 对象引用，**原地改内容不会触发刷新** ⇒ 换图必须
 *    （a）换一个新对象，并（b）把 `srcVersion` 加 1（`@Monitor` 监听的是它）。
 */
@ComponentV2
export struct MeshCoverBg {
  /** 已解码好的封面位图（64×64 最佳；**生命周期归调用方**，本组件不 release）。 */
  @Param src: image.PixelMap | undefined = undefined;
  /** 换图令牌：`src` 原地变化时靠它触发重新上传。 */
  @Param srcVersion: number = 0;
  /** 是否在播放（与 `active` 一起构成帧闸门）。 */
  @Param playing: boolean = false;
  /** 页面是否可见（与 `playing` 一起构成帧闸门）。 */
  @Param active: boolean = true;
  /** 是否叠径向暗角（无界 `scrim` 默认 true；播放页未传时也是 true）。 */
  @Param scrim: boolean = true;
  /** 入场是否走 400ms 淡入（无界 `entryFade`）。 */
  @Param entryFade: boolean = true;
  /**
   * ★★★★ 2026-10-17（**固定的网格画布高度**（vp）；0 = 用宿主实测高度）。
   *
   * ## 为什么需要它（播放页「背景被压扁、再拉伸」的真开关）
   * `NodeContainer.onAreaChange` 报的是**宿主当前盒子**，而播放页背景宿主在形变容器里，
   * 容器高度 `morphClipHeight()` **每帧都在变**（30 → 823）⇒
   * ```
   *   onAreaChange → controller.resize(w,h) → RenderNode.frame = (w,h)
   *                → draw(): field.update(tSec, w, h, flow)  ← 按新画布重建整套网格顶点
   *                → drawPixelMapMesh(...)                   ← 按新画布重采样
   * ```
   * ⇒ 小窗口时网格是按"很扁的画布"生成的（用户看到的**压扁**），窗口长大再按新比例重算
   *   （**拉伸**）。
   *
   * ⇒ 宿主**布局**一律保持 `100%`（上一版把宿主改成固定高，用户实测「背景完全不见了」，
   *   见 `PlaybackPage` 背景那段长注释）；只把**画布高度**钉成一个固定数
   *   ⇒ 网格永远按整窗比例生成，卡片长大 = **揭开更多背景**（= 无界「只显示上面那一块内容」）。
   * ⚠️ 静止态：宿主高本来就 = 窗口高 ⇒ 本参数不影响任何像素（回归红线）。
   */
  @Param fixedHVp: number = 0;

  private controller: MeshBgController = new MeshBgController();
  private sync: displaySync.DisplaySync | null = null;
  private startMs: number = 0;
  private accMs: number = 0;
  private disposed: boolean = false;

  aboutToAppear(): void {
    this.applySource();
    this.applyGate();
    // ★ 2026-10-16：挂载时补画一帧（`active` 但未播的场景，见 `onFrameNow()` 的注释）。
    this.onFrameNow();
    // ★★★★ 2026-10-17（**补画窗口** —— 修用户实测「未播放时点击打开背景始终是黑色」）
    //   挂载那一刻 `makeNode` / 首次布局还没发生（`hasRoot()` 假、尺寸 0）⇒ 上面那一帧
    //   会被丢掉，而暂停态**没有任何帧回调**再来一次 ⇒ 屏上永远是空的。
    //   ⇒ 挂载后 1 秒内**再补几帧**（不触发动效，只是把同一帧重画），一帧落上就够。
    //   ⚠️ 不用常驻定时器：最多 4 次 × 150ms，窗口一过就彻底安静（保住"暂停即停帧"的功耗口径）。
    this.scheduleWarmUp(0);
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.stopFrames();
    this.controller.node.src = null;
  }

  @Monitor('srcVersion')
  onSourceChanged(): void {
    this.applySource();
  }

  @Monitor('playing', 'active')
  onGateChanged(): void {
    this.applyGate();
  }

  private applySource(): void {
    this.controller.node.src = this.src ?? null;
    this.controller.node.invalidate();
    // ★★★ 2026-10-16（修用户实测「**歌曲不是播放状态，背景就会是一片黑**」）：
    //   见 `onFrameNow()` 的注释 —— 暂停态必须**至少画一帧**，不能只靠帧回调。
    this.onFrameNow();
  }

  /** 闸门 = `playing && active`（**暂停即停帧**）。 */
  private applyGate(): void {
    const on: boolean = this.playing && this.active;
    if (on && !this.disposed) {
      this.startFrames();
    } else {
      this.stopFrames();
    }
  }

  private startFrames(): void {
    if (this.sync !== null) {
      return;
    }
    // ⚠️ 起点要**减掉累计时间**（暂停过的话 `accMs > 0`），否则恢复播放的那一帧会跳。
    this.startMs = Date.now() - this.accMs;
    // ★ 2026-10-16：起帧之前先补画一帧（暂停期间屏上已经有一帧静止网格，
    //   这里保证"点播放"那一刻不用等到 50ms 后的第一个回调才有画面）。
    this.onFrameNow();
    try {
      const sync: displaySync.DisplaySync = displaySync.create();
      sync.setExpectedFrameRateRange({ expected: FPS_EXPECTED, min: FPS_MIN, max: FPS_MAX });
      sync.on('frame', (): void => {
        this.onFrame();
      });
      sync.start();
      this.sync = sync;
    } catch (err) {
      const e = err as BusinessErrorLike;
      hilog.warn(DOMAIN, TAG, 'displaySync start failed code=%{public}d msg=%{public}s', e.code, e.message);
    }
  }

  private stopFrames(): void {
    const sync: displaySync.DisplaySync | null = this.sync;
    if (sync === null) {
      return;
    }
    this.accMs = Date.now() - this.startMs;
    this.sync = null;
    sync.off('frame');
    sync.stop();
  }

  private onFrame(): void {
    this.accMs = Date.now() - this.startMs;
    this.onFrameNow();
  }

  /** 补画窗口的剩余次数（见 `aboutToAppear`）。 */
  private warmUpLeft: number = 4;
  /** 补画窗口的间隔（ms）。 */
  private static readonly WARM_UP_MS: number = 150;

  /**
   * 挂载后的一小段"补画窗口"：按固定次数把同一帧重画一遍。
   *
   * 为什么必须有：`RenderNode` 的内容只在 `invalidate()` 后重画，而**暂停态没有任何帧回调**
   * ⇒ 挂载那一帧若跑在 `makeNode`/首次布局之前就被丢掉，屏上就永远空着（用户看到的"黑"）。
   * 补画**不改变时间基**（`accMs` 不动）⇒ 画出来的是同一帧静止网格，不会抖。
   * @param attempt 已补画次数（0 起）
   */
  private scheduleWarmUp(attempt: number): void {
    if (attempt >= this.warmUpLeft) {
      return;
    }
    setTimeout((): void => {
      if (this.disposed) {
        return;
      }
      this.onFrameNow();
      this.scheduleWarmUp(attempt + 1);
    }, MeshCoverBg.WARM_UP_MS);
  }

  /**
   * 立刻按当前累计时间画一帧（**与帧闸门无关**）。
   *
   * ★★★ 2026-10-16（用户实测：「**现在派音如果歌曲不是播放状态，背景就会是一片黑**」）
   *
   * ## 根因
   *
   * `NodeContainer` 的内容是**自绘**的（`RenderNode.draw`）——`invalidate()` 只标脏，
   * 真正让它画出来的**唯一**路径是这个 20fps 的帧回调：
   * ```
   *   applyGate:  on = playing && active
   *               未播（或暂停）⇒ stopFrames() ⇒ 帧回调永不触发
   *   applySource: 只 invalidate() + 把 src 交给 node ⇒ **一帧都没画过**
   * ```
   * ⇒ 打开播放页时若从没播过，`NodeContainer` 是**空的** ⇒ 底下那层深色取样色
   *   （在线歌曲 `rgba(20, 20, 22, 0.5)`）露出来 = 用户看到的"一片黑"。
   *
   * ## 修法（最小、且不破坏"暂停即停帧"那条性能口径）
   *
   * 帧闸门照旧只控**动画**（`startFrames`/`stopFrames` 一个字没改）；
   * 另外在**源到位时**（`applySource`）以及**挂载时**（`aboutToAppear`）**补画一帧**。
   * ⇒ 暂停态屏上就是"那一帧静止的网格"（正确的观感），而不是空节点。
   *
   * ⚠️ 不引定时器、不常驻重绘（那会破坏无界"暂停即停帧"的功耗口径）。
   */
  private onFrameNow(): void {
    if (this.disposed || !this.controller.hasRoot()) {
      return;
    }
    this.controller.node.tSec = this.accMs / 1000;
    this.controller.node.invalidate();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      NodeContainer(this.controller)
        .width(HIT_FULL)
        .height(HIT_FULL)
        .onAreaChange((_oldArea: Area, newArea: Area): void => {
          // ★ 2026-10-17：`fixedHVp > 0` 时**画布高度**用固定值（见 `fixedHVp` 的注释）——
          //   布局尺寸照旧跟着宿主 100%，只有网格的生成尺寸被钉住。
          const h: number = this.fixedHVp > 0 ? this.fixedHVp : Number(newArea.height);
          this.controller.resize(Number(newArea.width), h);
        })

      if (this.scrim) {
        // 径向暗角：中心 15% α 铺到半径 45%，再渐变到边缘 40% α（无界 `SCRIM_CENTER/EDGE`）。
        Column()
          .width(HIT_FULL)
          .height(HIT_FULL)
          .radialGradient({
            center: ['50%', '50%'],
            radius: '70%',
            colors: [[SCRIM_CENTER, 0.0], [SCRIM_CENTER, 0.45], [SCRIM_EDGE, 1.0]]
          })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width(HIT_FULL)
    .height(HIT_FULL)
    .transition(this.entryFade
      ? TransitionEffect.OPACITY.animation({ duration: FADE_MS })
      : TransitionEffect.IDENTITY)
  }
}
