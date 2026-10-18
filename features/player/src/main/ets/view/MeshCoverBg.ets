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
import { SRC_EDGE, boxBlurRgba, fillFallback, hueOfSeed } from '../util/MeshSource';
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
/** 兜底网格的盒式模糊半径 / 轮数（无界 `MeshCoverBg` 的 `BLUR_RADIUS` / `BLUR_PASSES`）。 */
const FALLBACK_BLUR_RADIUS: number = 9;
const FALLBACK_BLUR_PASSES: number = 3;

/**
 * ★★★★ 2026-10-20（第三轮「点击展开动画过程背景颜色还是不对」）：
 * **起手「真源优先窗口」**（ms）—— 挂载后这段时间内，如果真源还没到，**先不画兜底网格**，
 * 让画布保持空（= 无界 `node.src === null` 时 `draw()` 直接 return 的形态）。
 *
 * ## 为什么需要（逐帧算出来的）
 * `__Common__.opacity = pullBgOpacity = 0.04 + clamp01(effT/0.30)·0.96`，而 `effT` 是
 * **560ms + `cubic-bezier(0.23,1,0.32,1)`** 的内容时间线 ⇒
 * ```
 *   t=0ms   p=0.000 → opacity 0.04     ← 只有这一帧是"96% 透明"
 *   t=25ms  p=0.188 → opacity 0.64
 *   t=50ms  p=0.360 → opacity 1.00     ← 之后屏上 100% 是网格自己的颜色
 * ```
 * ⇒ 形变的 550/600ms 里，用户看到的"背景颜色"**就是网格源的颜色**。
 *   若这一拍网格源还是「`hueOfSeed(seed)` 兜底」（哈希色，与封面主色平均差 ~90°），
 *   屏上就会是一片**与封面无关的饱和色**（实测例子见 `MeshSource.fillFallback` 注释），
 *   而真源一旦到达又硬切一次 ⇒ 用户的原话"颜色还是不对"。
 *
 * ## 无界为什么没有这一段
 * 它的源身份是**本地文件**：`PlaybackService.updateCover` 在换歌那一刻就把封面
 * `coverCache.ensure(...)` 固化成本地文件、并把 `"file://" + path` 写进 `K_IMG_LOCAL`
 * （`wujie.pa:292406-292448`）⇒ 点开播放页时 `decodeCover()` 是 `fs.openSync` + 本地解码，
 * **1 帧内**就能拿到真封面；拿不到时 `node.src` 是 `null` ⇒ 画布空着（透出下层），
 * **绝不会先亮一张哈希色**。
 *
 * ⇒ 我们的等价物：
 *   ① 挂载后 96ms 内不画兜底（等 `adoptWarmMesh` / 解码这 1~3 帧）；
 *   ② 真源到手后把它的字节记进 {@link MeshSeedCache}，同一首**下次打开第 1 帧就是真封面**。
 * 96ms ≈ 6 帧@60Hz：够覆盖"预热命中 + `image.createPixelMap`"这条 1~3 帧的链，
 * 又短到即使没命中也不会让下层（首页）长时间外露。
 */
const FIRST_SOURCE_GRACE_MS: number = 96;

/** 真源字节缓存容量（首）。16KB/首 ⇒ 最多 64KB 常驻内存。 */
const SEED_CACHE_CAP: number = 4;

/**
 * ★★★★ 2026-10-20：**按 `seed`（= `title + artist`）缓存"已加工好的真源字节"**（模块级，跨挂载存活）。
 *
 * 这是无界「封面固化成本地文件」（`PlaybackService.updateCover` 的 `coverCache`）在本仓的**内存版**等价物：
 * 无界靠它做到"点开那一刻就有真封面"，我们原来的 `src` 只由页面给、页面一退就没了
 * ⇒ 每次点开都从"兜底哈希色"开始。缓存住之后，同一首再点开是**第 1 帧就真封面**。
 *
 * ⚠️ 只存**字节**、不存 `PixelMap`（跨页面持有 PixelMap 会双重释放）；
 *    每次取用都 `createPixelMapSync` 一张新的，所有权归组件。
 */
class MeshSeedCache {
  private keys: string[] = [];
  private items: Uint8Array[] = [];

  get(seed: string): Uint8Array | undefined {
    if (seed.length === 0) {
      return undefined;
    }
    const i: number = this.keys.indexOf(seed);
    return i < 0 ? undefined : this.items[i];
  }

  /** 写入并把它挪到"最新"位置（`keys[0]` = 最近一次用过）。 */
  put(seed: string, bytes: Uint8Array): void {
    if (seed.length === 0 || bytes.length === 0) {
      return;
    }
    const i: number = this.keys.indexOf(seed);
    if (i >= 0) {
      this.keys.splice(i, 1);
      this.items.splice(i, 1);
    }
    this.keys.unshift(seed);
    this.items.unshift(bytes);
    while (this.keys.length > SEED_CACHE_CAP) {
      this.keys.pop();
      this.items.pop();
    }
  }
}

/** 全局唯一的真源字节缓存（模块级；跨组件挂载/卸载存活）。 */
const seedCache: MeshSeedCache = new MeshSeedCache();

const TAG: string = 'RzdMeshCoverBg';
const DOMAIN: number = 0x0000;

/** 读回 64×64 缓冲里 `(x, y)` 的 `R,G,B` 文本（**只给日志用**，判读四角顺序）。 */
function rgbAt(u8: Uint8Array, x: number, y: number): string {
  const off: number = (y * SRC_EDGE + x) * 4;
  return `${u8[off]},${u8[off + 1]},${u8[off + 2]}`;
}

/** 两位十六进制（**只给日志用**）。 */
function hex2(v: number): string {
  const c: number = v < 0 ? 0 : (v > 255 ? 255 : Math.round(v));
  const s: string = c.toString(16);
  return s.length < 2 ? `0${s}` : s;
}

/** @returns 整张 64×64 的**平均色** `#RRGGBB`（**只给日志用**）。 */
function avgHexOf(u8: Uint8Array): string {
  let sr: number = 0;
  let sg: number = 0;
  let sb: number = 0;
  let n: number = 0;
  for (let i = 0; i + 3 < u8.length; i += 4) {
    sr += u8[i];
    sg += u8[i + 1];
    sb += u8[i + 2];
    n++;
  }
  if (n === 0) {
    return '#000000';
  }
  return `#${hex2(sr / n)}${hex2(sg / n)}${hex2(sb / n)}`;
}

/** @returns 整张 64×64 **平均色**的色相角 `[0,360)`（**只给日志/判据用**）。 */
function hueOfAverage(u8: Uint8Array): number {
  let sr: number = 0;
  let sg: number = 0;
  let sb: number = 0;
  let n: number = 0;
  for (let i = 0; i + 3 < u8.length; i += 4) {
    sr += u8[i];
    sg += u8[i + 1];
    sb += u8[i + 2];
    n++;
  }
  if (n === 0) {
    return 0;
  }
  const r: number = sr / n / 255;
  const g: number = sg / n / 255;
  const b: number = sb / n / 255;
  const max: number = Math.max(r, Math.max(g, b));
  const min: number = Math.min(r, Math.min(g, b));
  const d: number = max - min;
  if (d < 0.0001) {
    return 0;
  }
  let h: number = 0;
  if (max === r) {
    h = 60 * (((g - b) / d) % 6);
  } else if (max === g) {
    h = 60 * (((b - r) / d) + 2);
  } else {
    h = 60 * (((r - g) / d) + 4);
  }
  return ((h % 360) + 360) % 360;
}

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

/** 解析出来的取样色（0..255）。 */
class RgbTriple {
  r: number = 0;
  g: number = 0;
  b: number = 0;
}
/** 十六进制单个字符 → 0..15（非法返回 -1）。 */
function hexNibble(ch: string): number {
  const code: number = ch.charCodeAt(0);
  if (code >= 48 && code <= 57) {
    return code - 48;
  }
  if (code >= 97 && code <= 102) {
    return code - 87;
  }
  if (code >= 65 && code <= 70) {
    return code - 55;
  }
  return -1;
}

/** 两个十六进制字符 → 0..255（非法返回 -1）。 */
function hexByte(a: string, b: string): number {
  const hi: number = hexNibble(a);
  const lo: number = hexNibble(b);
  if (hi < 0 || lo < 0) {
    return -1;
  }
  return hi * 16 + lo;
}

/**
 * 解析"取样色"字符串 → RGB（0..255）。支持本仓两处来源的写法：
 * - `#RRGGBB` / `#AARRGGBB`（`CoverTintState.targetColor` 的口径）；
 * - `rgb(r, g, b)` / `rgba(r, g, b, a)`（`MusicAppState.imageColor` 的口径）。
 * @returns 解析不出时返回 `undefined`（调用方退回 `hueOfSeed(seed)`）。
 */
function parseSampleColor(text: string): RgbTriple | undefined {
  const s: string = text.trim();
  if (s.length === 0) {
    return undefined;
  }
  const out: RgbTriple = new RgbTriple();
  if (s.charAt(0) === '#') {
    const hex: string = s.substring(1);
    if (hex.length === 3) {
      const r: number = hexNibble(hex.charAt(0));
      const g: number = hexNibble(hex.charAt(1));
      const b: number = hexNibble(hex.charAt(2));
      if (r < 0 || g < 0 || b < 0) {
        return undefined;
      }
      out.r = r * 17;
      out.g = g * 17;
      out.b = b * 17;
      return out;
    }
    if (hex.length === 6 || hex.length === 8) {
      // 8 位按 #AARRGGBB 解释 ⇒ 取后 6 位
      const body: string = hex.length === 8 ? hex.substring(2) : hex;
      const r: number = hexByte(body.charAt(0), body.charAt(1));
      const g: number = hexByte(body.charAt(2), body.charAt(3));
      const b: number = hexByte(body.charAt(4), body.charAt(5));
      if (r < 0 || g < 0 || b < 0) {
        return undefined;
      }
      out.r = r;
      out.g = g;
      out.b = b;
      return out;
    }
    return undefined;
  }
  const open: number = s.indexOf('(');
  const close: number = s.indexOf(')');
  if (open <= 0 || close < open) {
    return undefined;
  }
  const head: string = s.substring(0, open).trim().toLowerCase();
  if (head !== 'rgb' && head !== 'rgba') {
    return undefined;
  }
  const parts: string[] = s.substring(open + 1, close).split(',');
  if (parts.length < 3) {
    return undefined;
  }
  const r: number = Number(parts[0].trim());
  const g: number = Number(parts[1].trim());
  const b: number = Number(parts[2].trim());
  if (!Number.isFinite(r) || !Number.isFinite(g) || !Number.isFinite(b)) {
    return undefined;
  }
  out.r = Math.max(0, Math.min(255, Math.round(r)));
  out.g = Math.max(0, Math.min(255, Math.round(g)));
  out.b = Math.max(0, Math.min(255, Math.round(b)));
  return out;
}

/** 把 `MeshRenderNode` 挂进视图树（对标无界 `MeshBgController extends NodeController`）。 */
class MeshBgController extends NodeController {
  node: MeshRenderNode = new MeshRenderNode();
  private root: FrameNode | null = null;
  private rootRender: RenderNode | null = null;
  private w: number = 0;
  private h: number = 0;
  /** 上一次打日志的画布尺寸（只给 `RzdBgPhaseMesh resize` 去重用）。 */
  private logW: number = -1;
  private logH: number = -1;

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
    // ★ 2026-10-18（**只加日志、不改行为**）：画布尺寸就是 `field.update(tSec, w, h, flow)` 的 w/h，
    //   也是 `drawPixelMapMesh` 的像素口径（`context.sizeInPixel`）。真机判读"两色位置"时先看这两行数。
    // ★★★ 2026-10-19 **订正上一版这句错的判据**（原话是"形变期间应当是**窄**画布"）：
    //   上游那条链是 `MeshCoverBg(100%×100%) → __Common__(只有 opacity，无尺寸) → 内层 Stack`
    //   `.width(winWVp()).height(winHVp())`（`wujie.pa:191547 / 191558`）
    //   ⇒ 百分比解析到**最近的定尺寸祖先 = 整窗** ⇒ `onAreaChange` 报的 `(w,h)` **形变全程不变**，
    //     被"从小长大"的是外面那个 `.height(expand.clipHeight)` + `.clip(true)` 的**裁剪容器**，
    //     网格本身**不重建也不拉伸**（=`一张恒定整窗网格被一个长大的圆角窗口揭开`）。
    //   ⇒ **判据反过来**：形变期与结束后 `w/h` **相同**才是对的；若形变期变小，说明宿主被裁剪容器
    //     带矮了（那才是**布局**问题）。
    if (Math.abs(w - this.logW) >= 1 || Math.abs(h - this.logH) >= 1) {
      this.logW = w;
      this.logH = h;
      hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh resize w=%{public}d h=%{public}d',
        Math.round(w), Math.round(h));
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
    //
    // ⚠️ **与上游的已知分歧（保留，并给依据）**：上游 `MeshBgController.resize()`
    //   （`wujie.pa:62886-62940`）只写 `node.frame` / `rootRender.frame`，**没有** `invalidate()`。
    //   上游不需要它是因为：它每次 `rebuildSource()` 结束时都会 `node.src = pm; node.invalidate();`
    //   （`:64206`），而封面是从本地文件同步解出来的，`src` 一定在"尺寸之后"到齐。
    //   本仓的 `src` 由页面（可能要先 HTTP 下载）给、且 `NodeContainer` 在 `if (meshSrc)` 分支里，
    //   挂载时机可能晚于那一帧 ⇒ 少这一次 invalidate 就会重现"暂停态一片黑"。
    //   ⇒ 保留（只影响"暂停态补画一帧"，不改变任何像素内容），并在 `backgroundRevealOpacity()` 一侧
    //     严格照搬上游的取值链。
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
  /**
   * 已解码好的封面位图（64×64 最佳；**生命周期归调用方**，本组件不 release）。
   *
   * ★★★★ 2026-10-19（**调用方契约，务必照做**）：`src` 必须**与 `seed` 同源**。
   * ```
   *   换歌时：① meshSrc = undefined（并 release 旧那张）   ② meshSrcVersion++   ③ seed 跟着歌变
   *   新封面到手：meshSrc = 新 pm                          ④ meshSrcVersion++
   * ```
   * 上游的 `coverPath` 天然满足这条（换歌先写 `""`）。我们这一侧如果**只换 seed 不换版本**，
   * 组件会把这当成"上一首的残留"作废并改画新 seed 的兜底（见 {@link isSrcForCurrentSeed}），
   * 屏上不会出现上一首的颜色；但"新封面到底哪一版"组件是判不出来的，
   * 所以页面那边**必须**在换源时 `++meshSrcVersion`。
   */
  @Param src: image.PixelMap | undefined = undefined;
  /**
   * ★★★ 2026-10-17（照搬无界 `MeshCoverBg.seed` + `makeFallback()`）：
   * 取不到封面时按这个种子造**兜底网格**（`hueOfSeed(seed)` → `fillFallback` 四角 HSL 渐变
   * → `enhanceColors` → `boxBlurRgba`）。上游是 `seedOfParts(title, artist)`。
   *
   * ⇒ 网格源**永远存在**，屏上不会出现"背景一片黑"（上游从不会黑，就是因为有这一步）。
   */
  @Param seed: string = '';
  /**
   * ⛔ 2026-10-17 二次更正（用户原话：「背景也照着无界的改」）：**上一轮新增的 `fallbackColor` 参数已删除**。
   *
   * 上游 `MeshCoverBg` 根本没有"取样色兜底"这条路 —— `makeFallback()` 的色相只有一个来源：
   * ```
   *   fillFallback(u8, SRC_EDGE, SRC_EDGE, hueOfSeed(this.seed))
   *   // wujie.pa:63687-63839：`ldexternalmodulevar "hueOfSeed"` + `lda a2; ldobjbyname 0x8, "seed"`
   * ```
   * 上一轮按"封面取样色"定兜底色相 ⇒ 兜底网格的色相与上游完全不同 ⇒ 点击打开那 350~400ms
   * 里屏上的背景必然"对不上"。现在恒走 `hueOfSeed(seed)`，`seed` 在调用侧按上游
   * `seedOfParts(title, artist)` 拼（`contract...Identity&1.0.0.#*#seedOfParts` = `title + artist`，无分隔符）。
   */
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
  /**
   * 网格源的**代际号**（照搬无界 `MeshCoverBg.srcGen`，`wujie.pa:63996-63999`）。
   * 每次 `applySource()` 自增；`await` 回来以后若代际已变，结果作废并释放。
   */
  private srcGen: number = 0;
  /**
   * ★★★★ 2026-10-19（**「点开播放页背景是上一首歌的颜色」的组件侧收口**）：
   * 当前 `node.src` 上那份源**属于哪一首 / 哪一版**。
   *
   * ## 上游为什么"换歌那一刻绝不残留旧图"
   * 它的源身份是**可判定的**：`coverPath` 是本地文件路径，而 `PlaybackService.updateCover`
   * 换歌时先把 `K_IMG_LOCAL` 写成 `""` ⇒ `decodeCover()` 见到空串**立即** `return null`
   * （`wujie.pa:63391-63614` 的头三行）⇒ `rebuildSource()` 直接走 `makeFallback()`
   * （新 `seed` 的色相）⇒ 旧图那一份 `pm` 连"再被采用"的机会都没有。
   *
   * ## 我们这一侧的问题
   * `src` 是页面给的 `PixelMap`（在线歌还要先下载 + 解码，实测 200~2000ms），
   * 而页面**没有**"换歌先把源清掉"这一步（`PlaybackPage.onCurrentTrackForBackground()`
   * 只调 `getImageColor()`，不动 `meshSrc`/`meshSrcVersion`）。于是：
   * ```
   *   换歌 → seed 变（本组件 @Monitor('seed') 触发）→ applySource()
   *        → this.src 还是**上一首**那张（版本也没变）→ 被**再采用一次**
   *        → 屏上是上一首的网格，直到新封面下载完（封面为空/失败 ⇒ 永久停留）。
   * ```
   * ⇒ 本组件自己造一个源身份判据：`(srcVersion, seed)` 二元组。
   *   - `srcVersion` 与上次那版**不同** ⇒ 页面发布了新源 ⇒ 采用；
   *   - `srcVersion` **没变**而 `seed` 变了 ⇒ 页面手里还是那张旧图 ⇒ **作废**，
   *     并**同步**改画新 `seed` 的兜底（见 {@link paintFallbackSync}）。
   */
  private srcVer: number = -1;
  /** 上次采用/丢弃那一版源时的 `seed`（配合 {@link srcVer} 判"是不是同一首"）。 */
  private srcSeed: string = '';

  /** 挂载时刻（ms）—— {@link FIRST_SOURCE_GRACE_MS} 的起点。 */
  private mountMs: number = 0;
  /** 起手窗口是否已经用掉（一旦画过任何一张图、或真源已到，就永久置真）。 */
  private graceSpent: boolean = false;
  /** 起手窗口的定时器 id（-1 = 没在跑）。 */
  private graceTimer: number = -1;
  /** 按 `seed` 命中真源缓存后解码出来的位图（**所有权归本组件**）。 */
  private cachedPm: image.PixelMap | undefined = undefined;
  /** 当前 `cachedPm` 属于哪个 `seed`。 */
  private cachedSeed: string = '';

  aboutToAppear(): void {
    // ★ 起手窗口的起点（见 FIRST_SOURCE_GRACE_MS）。
    this.mountMs = Date.now();
    // ★ 只加日志（真机判读 ②）：**挂载一次就归零一次**。若一次打开播放页出现两条 `mount`，
    //   说明组件被卸载重挂了（`tSec` 会从 0 重新走、`reseed` 会重跑 ⇒ 网格花纹整片重排）。
    hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh mount seedLen=%{public}d t=%{public}d',
      this.seed.length, Math.round(this.accMs));
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
    this.clearGraceTimer();
    this.stopFrames();
    this.controller.node.src = null;
    this.releaseFallback();
    this.releaseCachedCover();
  }

  // ★★★ 2026-10-17（照搬无界 `@Watch`：`coverPath→onSourceChanged`、`seed→onSourceChanged`）
  //   上游 `seed` 变化也要**重做兜底网格**（它决定兜底网格的色相）。
  //   ⚠️ 我们原来只监听 `srcVersion` ⇒ 换歌时 `src` 还没到手、`seed` 已经变了，
  //     屏上会**继续显示上一首的兜底色**（用户看到的"展开时是蓝色"就是这个：
  //     播放的那首还没解出封面，兜底网格按旧 seed 的色相画出来了）。
  @Monitor('srcVersion', 'seed')
  onSourceChanged(): void {
    this.applySource();
  }

  @Monitor('playing', 'active')
  onGateChanged(): void {
    this.applyGate();
  }

  private applySource(): void {
    // ★★★★ 2026-10-17（照搬无界 `MeshCoverBg.onSourceChanged()`，`wujie.pa:63901-63927`）：
    // ```
    //   this.controller.node.field.reseed(hueOfSeed(this.seed));   // ← 63906-63922（本仓原来漏了这一句）
    //   void this.rebuildSource();
    // ```
    // `field.reseed(hue)` 决定**网格流动的调色/轨道相位**（`MeshField.reseed`：
    // `applyConf(generateConf(floor(|hue|)))` + `initOrbits(seed)` + `applyBorderRules()`，
    // `wujie.pa:90867-90920`）⇒ 少这一句，屏上网格的"流动花纹"就与上游不是同一套。
    // ★★★ 2026-10-18（照搬无界 `rebuildSource()` 的**代际校验**，`wujie.pa:63994-63999 / 64151-64166`）：
    // ```
    //   const gen = ++this.srcGen;                                          // 63996-63999
    //   ...
    //   if (this.disposed || this.srcGen !== gen) { pm.release(); return; }  // 64151-64166
    // ```
    // 兜底/解码都要 `await`（`image.createPixelMap`），**换歌很快时旧结果会晚到** ⇒
    // 没有代际校验时，旧那张会把新那张盖掉（屏上表现为"颜色/花纹突然回到上一首"）。
    const hue: number = hueOfSeed(this.seed);
    const gen: number = this.srcGen + 1;
    this.srcGen = gen;
    this.controller.node.field.reseed(hue);
    hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh reseed gen=%{public}d hue=%{public}d seedLen=%{public}d',
      gen, Math.round(hue), this.seed.length);
    // ★★★★ 2026-10-17（照搬无界 `decodeCover()` 失败 ⇒ `makeFallback()` 那条链）
    // ```
    //   无界：coverPath 解不出图 ⇒ makeFallback()：按 seed 的色相造一张 64×64 的
    //         四角 HSL 渐变 →（rebuildSource 里）**只做 boxBlurRgba**、**不做 enhanceColors** → 当网格源
    //   ⇒ **网格源永远存在**，屏上不会出现"背景一片黑"
    // ```
    // ⚠️ 2026-10-18 订正：上一版注释写"rebuildSource 里统一 enhanceColors"是**错的** ——
    //   上游对兜底**不做** `enhanceColors`（`wujie.pa:64074-64081`，只有 `decoded` 为真才做）。
    // 我们这一侧的 `src` 由页面给（在线封面要下载），拿不到时就在**组件内**造兜底网格
    // ——与上游同一个位置、同一个算法（`fillFallback` / `hueOfSeed` 已在 `MeshSource` 里）。
    if (this.src !== undefined) {
      if (this.isSrcForCurrentSeed()) {
        this.srcVer = this.srcVersion;
        this.srcSeed = this.seed;
        this.controller.node.src = this.src;
        // 真源来了，兜底那张没用了（本组件持有它的所有权）
        this.releaseFallback();
        // ★ 2026-10-20：真源已到 ⇒ 起手窗口作废，并把它的字节记进模块级缓存
        //   （= 无界「封面固化成本地文件」，见 MeshSeedCache 的注释）。
        this.graceSpent = true;
        this.clearGraceTimer();
        this.releaseCachedCover();
        this.rememberSourceBytes(this.src);
        this.controller.node.invalidate();
        this.onFrameNow();
        // ★ 只加日志：**形变期间会不会换源**由这一行判定 ——
        //   若 `source=cover` 出现在 `RzdBgLayer` 的 `p=1.000` 之前，就是"形变里换过一次源"
        //   （屏上会从兜底的四角渐变切到封面取色的那两团，观感 = 两色位置突然变了）。
        hilog.info(DOMAIN, TAG,
          'RzdBgPhaseMesh source=cover gen=%{public}d ver=%{public}d seedLen=%{public}d t=%{public}d',
          gen, this.srcVersion, this.seed.length, Math.round(this.accMs));
        return;
      }
      // ★★★★ 2026-10-19：换歌了，而页面手里还是**上一首**那张（`srcVersion` 没变）⇒ 绝不采用。
      hilog.info(DOMAIN, TAG,
        'RzdBgPhaseMesh source=stale-drop gen=%{public}d ver=%{public}d ' +
          'seedLen=%{public}d oldSeedLen=%{public}d t=%{public}d',
        gen, this.srcVersion, this.seed.length, this.srcSeed.length, Math.round(this.accMs));
    }
    // ★ 2026-10-20：**先查"这一首的真源字节缓存"**（无界靠本地封面文件做到的那一步）。
    //   命中 ⇒ 立刻画真封面（不画哈希兜底，屏上不会有"先错后对"的那一跳）。
    if (this.paintCachedCoverSync(gen)) {
      return;
    }
    this.paintFallbackDeferred(gen);
  }

  /**
   * @returns `this.src` 是否是**当前这一首**的网格源（判据见 {@link srcVer} / {@link srcSeed}）。
   *
   * 1. `src === undefined` ⇒ `false`（调用方去画兜底）；
   * 2. 从没记录过源身份（`srcVer === -1`，首次挂载）⇒ `true`
   *    —— 上游"挂载时 `coverPath` 是什么就用什么"同义；那时页面还没发布过任何源，
   *    `src` 非空只可能是它想让我们画的**第一张**；
   * 3. `srcVersion` 与上次那版不同 ⇒ 页面发布了新源 ⇒ `true`；
   * 4. `srcVersion` 相同 ⇒ 只能是**同一张图** ⇒ 只有 `seed` 也相同才算当前这一首。
   */
  private isSrcForCurrentSeed(): boolean {
    if (this.src === undefined) {
      return false;
    }
    if (this.srcVer < 0) {
      return true;
    }
    if (this.srcVersion !== this.srcVer) {
      return true;
    }
    return this.seed === this.srcSeed;
  }

  // ── 2026-10-20 新增：真源字节缓存 + 起手「真源优先窗口」────────────────────────────

  /** 清掉起手窗口的定时器（换源/退场时都要清，否则旧回调会把兜底画到新歌上）。 */
  private clearGraceTimer(): void {
    const id: number = this.graceTimer;
    if (id < 0) {
      return;
    }
    this.graceTimer = -1;
    clearTimeout(id);
  }

  /**
   * 把真源（**已经 enhance + blur 过的** 64×64）的字节记进模块级缓存，键 = 当前 `seed`。
   *
   * 为什么存字节而不是 PixelMap：见 {@link MeshSeedCache}。
   * 为什么是"已经加工过"的：`this.src` 本来就是页面/预热那条链加工完的成品，
   * 存它 = 下次取用时 1:1 复现同一张图（不会二次 enhance、不会二次模糊）。
   */
  private rememberSourceBytes(pm: image.PixelMap): void {
    if (this.seed.length === 0) {
      return;
    }
    if (seedCache.get(this.seed) !== undefined) {
      return;
    }
    try {
      const bytes: number = pm.getPixelBytesNumber();
      if (bytes !== SRC_EDGE * SRC_EDGE * 4) {
        // 尺寸/通道口径不对就不缓存（例如设备返回 BGRA 或带 stride）——
        // 下次仍走"等真源 / 兜底"两条老路，不会画错。
        hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh seed-cache skip bytes=%{public}d', bytes);
        return;
      }
      const buf: ArrayBuffer = new ArrayBuffer(bytes);
      pm.readPixelsToBufferSync(buf);
      const u8: Uint8Array = new Uint8Array(buf);
      seedCache.put(this.seed, u8);
      // ★ 真机判据（对齐任务书 §3.2）：把**真封面主色**的色相打出来，
      //   和 `fallback hue=…` 那一行一比就知道"兜底色相离封面有多远"。
      //   `hdc shell hilog -x | Select-String 'RzdBgPhaseMesh (fallback|source-color)'`
      hilog.info(DOMAIN, TAG,
        'RzdBgPhaseMesh source-color avg=%{public}s hue=%{public}d seedLen=%{public}d',
        avgHexOf(u8), Math.round(hueOfAverage(u8)), this.seed.length);
      hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh seed-cache put seedLen=%{public}d bytes=%{public}d',
        this.seed.length, bytes);
    } catch (err) {
      const e = err as BusinessErrorLike;
      hilog.warn(DOMAIN, TAG, 'seed-cache read failed code=%{public}d msg=%{public}s',
        e.code, e.message);
    }
  }

  /**
   * 若模块级缓存里已有**这一首**的真源字节 ⇒ 同步画出来并返回 `true`。
   *
   * 这是"点击打开第 1 帧就该是真封面"的实现路径（无界靠本地封面文件，我们靠这份缓存）。
   * @param gen 发起这次绘制时的代际号（同拍内又换了歌 ⇒ 这张作废）
   */
  private paintCachedCoverSync(gen: number): boolean {
    if (this.disposed) {
      return false;
    }
    const bytes: Uint8Array | undefined = seedCache.get(this.seed);
    if (bytes === undefined || bytes.length !== SRC_EDGE * SRC_EDGE * 4) {
      return false;
    }
    // 同一 seed 的缓存图已经解码过 ⇒ 直接确保它在画
    const cached: image.PixelMap | undefined = this.cachedPm;
    if (cached !== undefined && this.cachedSeed === this.seed) {
      this.graceSpent = true;
      this.clearGraceTimer();
      if (this.controller.node.src !== cached) {
        // ⚠️ 顺序：**先换绑定、再释放旧图**（与上游 `node.src = pm; old.release()` 一致）
        this.controller.node.src = cached;
        this.releaseFallback();
        this.controller.node.invalidate();
        this.onFrameNow();
      }
      return true;
    }
    let pm: image.PixelMap | undefined = undefined;
    try {
      pm = image.createPixelMapSync(bytes.buffer, {
        size: { width: SRC_EDGE, height: SRC_EDGE },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      });
    } catch (err) {
      const e = err as BusinessErrorLike;
      hilog.warn(DOMAIN, TAG, 'cached cover createPixelMapSync failed code=%{public}d msg=%{public}s',
        e.code, e.message);
      return false;
    }
    if (pm === undefined) {
      return false;
    }
    if (this.disposed || gen !== this.srcGen) {
      pm.release();
      return false;
    }
    const oldCached: image.PixelMap | undefined = this.cachedPm;
    this.cachedPm = pm;
    this.cachedSeed = this.seed;
    this.graceSpent = true;
    this.clearGraceTimer();
    // ⚠️ 顺序：**先换绑定、再释放旧图**（与上游 `node.src = pm; old.release()` 一致）
    this.controller.node.src = pm;
    this.releaseFallback();
    if (oldCached !== undefined) {
      this.releasePixelMapQuiet(oldCached);
    }
    this.controller.node.invalidate();
    this.onFrameNow();
    hilog.info(DOMAIN, TAG,
      'RzdBgPhaseMesh source=seed-cache gen=%{public}d seedLen=%{public}d t=%{public}d',
      gen, this.seed.length, Math.round(this.accMs));
    return true;
  }

  /** 静默释放（已从渲染节点上解绑的图才可调用）。 */
  private releasePixelMapQuiet(pm: image.PixelMap): void {
    try {
      pm.release();
    } catch (err) {
      const e = err as BusinessErrorLike;
      hilog.warn(DOMAIN, TAG, 'pixelmap release failed code=%{public}d', e.code);
    }
  }

  /** 释放缓存图（本组件持有其所有权）。 */
  private releaseCachedCover(): void {
    const pm: image.PixelMap | undefined = this.cachedPm;
    this.cachedPm = undefined;
    this.cachedSeed = '';
    if (pm !== undefined) {
      try {
        pm.release();
      } catch (err) {
        const e = err as BusinessErrorLike;
        hilog.warn(DOMAIN, TAG, 'cached cover release failed code=%{public}d', e.code);
      }
    }
  }

  /**
   * 走"兜底"之前的最后一关：**画布还空着、且仍处在挂载后的起手窗口内 ⇒ 先空着**。
   *
   * 空着 = 无界 `node.src === null` 时 `draw()` 直接 `return` 的形态（透出下层、不亮任何颜色），
   * 比"先亮一张与封面无关的哈希色、1~3 帧后再硬切成真封面"更接近无界。
   * 窗口到点还没真源 ⇒ 老老实实画兜底（绝不长时间空着）。
   */
  private paintFallbackDeferred(gen: number): void {
    const blank: boolean = this.controller.node.src === null;
    const elapsed: number = Date.now() - this.mountMs;
    const withinGrace: boolean = !this.graceSpent && elapsed < FIRST_SOURCE_GRACE_MS;
    if (blank && withinGrace) {
      this.controller.node.src = null;
      this.controller.node.invalidate();
      this.onFrameNow();
      hilog.info(DOMAIN, TAG,
        'RzdBgPhaseMesh fallback hold-blank gen=%{public}d elapsed=%{public}d seedLen=%{public}d',
        gen, Math.round(elapsed), this.seed.length);
      this.scheduleGracePaint();
      return;
    }
    this.graceSpent = true;
    this.clearGraceTimer();
    this.paintFallbackSync(gen);
  }

  /** 起手窗口到点：重走一遍 `applySource()`（有真源就上真源，没有才画兜底）。 */
  private scheduleGracePaint(): void {
    if (this.graceTimer >= 0) {
      return;
    }
    let wait: number = FIRST_SOURCE_GRACE_MS - (Date.now() - this.mountMs);
    if (wait < 16) {
      wait = 16;
    }
    this.graceTimer = setTimeout((): void => {
      this.graceTimer = -1;
      this.graceSpent = true;
      if (this.disposed) {
        return;
      }
      // 真空着才需要补：真源已经到了就什么都不用做
      if (this.controller.node.src !== null) {
        hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh grace done src=cover');
        return;
      }
      hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh grace done src=none (repaint fallback)');
      this.applySource();
    }, wait);
  }

  /**
   * ★★★★ 2026-10-19：**同步**画兜底网格（换歌 / 无真源时的唯一出口）。
   *
   * ## 为什么必须同步（这就是「上一首颜色」的直接成因之一）
   * 上一版是 `void this.makeFallback(gen)`，里面 `await image.createPixelMap(...)`。
   * `await` 期间 `node.src` **还是上一首那张**，而 `RenderNode` 只要没有新的 `invalidate()`
   * 就**一直保留上次画出来的像素** ⇒ 屏上继续是上一首的颜色
   * （暂停态更明显：`playing && active` 为假 ⇒ 根本没有帧回调来刷新，能停到下一次换源为止）。
   *
   * 现在改用 `image.createPixelMapSync()`（`@since 12`；本机 SDK
   * `default/openharmony/ets/api/@ohos.multimedia.image.d.ts:4481` 有声明）
   * ⇒ **"决定换源"与"给 node.src 赋值"在同一拍** ⇒ 换歌那一帧屏上就是新 `seed` 的四角渐变，
   * **一帧旧图都不留**。
   *
   * `fillFallback` + `boxBlurRgba` 本来就是同步纯 ArkTS 计算（64×64，与上游同一个量级），
   * ⇒ 这里**没有**额外引入耗时；只是把原来 `await` 前后的两拍压成一拍。
   *
   * @param gen 发起这次绘制时的代际号（同拍内又换了歌 ⇒ 这张作废）
   */
  private paintFallbackSync(gen: number): void {
    if (this.disposed) {
      return;
    }
    // 同一 seed 的兜底已经造好 ⇒ 直接确保它在画（`applySource` 连触几次是免费的）
    const cached: image.PixelMap | undefined = this.fallbackPm;
    if (cached !== undefined && this.fallbackSeed === this.seed) {
      if (this.controller.node.src !== cached) {
        this.controller.node.src = cached;
        this.controller.node.invalidate();
        this.onFrameNow();
      }
      return;
    }
    const hue: number = hueOfSeed(this.seed);
    const buf: ArrayBuffer = new ArrayBuffer(SRC_EDGE * SRC_EDGE * 4);
    const u8: Uint8Array = new Uint8Array(buf);
    // ★ 与上游一致：兜底**只做 boxBlur，不做 enhanceColors**（`wujie.pa:64074-64081`）。
    fillFallback(u8, SRC_EDGE, SRC_EDGE, hue);
    boxBlurRgba(u8, SRC_EDGE, SRC_EDGE, FALLBACK_BLUR_RADIUS, FALLBACK_BLUR_PASSES);
    // ★ 只加日志（真机判读用）：四角的**颜色顺序**必须与上游一致
    //   A=TL(`hue`,.62,.40) / B=TR(`hue+28`) / C=BL(`hue−20`) / D=BR(`hue+46`)（`wujie.pa:91528-91611`）。
    hilog.info(DOMAIN, TAG,
      'RzdBgPhaseMesh fallback hue=%{public}d TL=%{public}s TR=%{public}s BL=%{public}s BR=%{public}s',
      Math.round(hue), rgbAt(u8, 0, 0), rgbAt(u8, SRC_EDGE - 1, 0),
      rgbAt(u8, 0, SRC_EDGE - 1), rgbAt(u8, SRC_EDGE - 1, SRC_EDGE - 1));
    let pm: image.PixelMap | undefined = undefined;
    try {
      pm = image.createPixelMapSync(buf, {
        size: { width: SRC_EDGE, height: SRC_EDGE },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      });
    } catch (err) {
      const e = err as BusinessErrorLike;
      hilog.warn(DOMAIN, TAG, 'createPixelMapSync failed code=%{public}d msg=%{public}s (turn-async)',
        e.code, e.message);
      // 同步那条万一不可用（老设备 / 内存不足）⇒ 退回原来的异步链路
      void this.makeFallback(gen);
      return;
    }
    if (pm === undefined) {
      return;
    }
    if (this.disposed || gen !== this.srcGen) {
      pm.release();
      hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh fallback skip-stale gen=%{public}d now=%{public}d',
        gen, this.srcGen);
      return;
    }
    // ⚠️ 顺序：**先换绑定、再释放旧图**（上游 `node.src = pm; old.release()`，`wujie.pa:64177-64184`）
    const oldFallback: image.PixelMap | undefined = this.fallbackPm;
    const oldCached: image.PixelMap | undefined = this.cachedPm;
    this.fallbackPm = pm;
    this.fallbackSeed = this.seed;
    this.cachedPm = undefined;
    this.cachedSeed = '';
    this.controller.node.src = pm;
    if (oldFallback !== undefined) {
      this.releasePixelMapQuiet(oldFallback);
    }
    if (oldCached !== undefined) {
      this.releasePixelMapQuiet(oldCached);
    }
    this.controller.node.invalidate();
    this.onFrameNow();
    hilog.info(DOMAIN, TAG,
      'RzdBgPhaseMesh fallback adopted sync gen=%{public}d hue=%{public}d ' +
        'seedLen=%{public}d t=%{public}d',
      gen, Math.round(hue), this.seed.length, Math.round(this.accMs));
  }

  /** 兜底网格（本组件持有其所有权；换源/退场时释放）。 */
  private fallbackPm: image.PixelMap | undefined = undefined;
  /** 当前 `fallbackPm` 是按哪个 `seed` 造的（`=== seed` 时可复用，见 {@link paintFallbackSync}）。 */
  private fallbackSeed: string = '';

  private releaseFallback(): void {
    const pm: image.PixelMap | undefined = this.fallbackPm;
    this.fallbackPm = undefined;
    if (pm !== undefined) {
      try {
        pm.release();
      } catch (err) {
        const e = err as BusinessErrorLike;
        hilog.warn(DOMAIN, TAG, 'fallback release failed code=%{public}d', e.code);
      }
    }
  }

  /**
   * ★ 2026-10-19：这条异步链路现在**只是保底**（`createPixelMapSync` 抛异常时才走），
   * 正常路径是 {@link paintFallbackSync}（同步：决定与赋值同一拍 ⇒ 一帧旧图都不留）。
   *
   * 造兜底网格（照搬无界 `makeFallback()` / `MeshSource.fillFallback`）。
   *
   * ① `hueOfSeed(seed)` → 色相；② `fillFallback` 铺一张**四角 HSL 双线性渐变**；
   * ③ `boxBlurRgba(64,64,9,3)`；④ `image.createPixelMap` 交给渲染节点。
   * ⚠️ **没有 `enhanceColors`** —— 上游只对真封面做（见下方注释与 `wujie.pa:64074-64081`）。
   * ⚠️ 与上游另一处差别：上游从 `fs` 读封面文件，我们的 `src` 是页面给的 PixelMap
   *   ⇒ 只在 `src` 缺席时走这一步。
   * @param gen 发起这次构造时的代际号（`await` 回来后与 `srcGen` 比对）
   */
  private async makeFallback(gen: number): Promise<void> {
    if (this.disposed) {
      return;
    }
    try {
      const buf: ArrayBuffer = new ArrayBuffer(SRC_EDGE * SRC_EDGE * 4);
      const u8: Uint8Array = new Uint8Array(buf);
      // ★★★ 2026-10-18（照搬无界，**订正上一版的错**）：兜底网格**只做 boxBlur，不做 enhanceColors**。
      //
      // 上游 `makeFallback()`（`wujie.pa:63687-63840`）只有一步：
      //   `fillFallback(new Uint8Array(buf), SRC_EDGE, SRC_EDGE, hueOfSeed(this.seed))`
      // 后处理在 `rebuildSource()`（`:63990-64207`）里，而且是**有条件**的：
      //   64025-64026  v7 = (decodeCover() 返回非 null)      ← 只有真封面才为真
      //   64074-64081  `lda v7; callruntime.isfalse; jnez jump_label_8`
      //                ⇒ `if (decoded) { enhanceColors(u8); }`   ← **兜底不做**
      //   64083-64104  `boxBlurRgba(u8, SRC_EDGE, SRC_EDGE, 9, 3)`  ← **两条路都做**
      // ⇒ 上一版注释写"效果等价"是错的：`enhanceColors` 是 对比×0.4 → 饱和×5 → 对比×0.9 → ×0.75，
      //   作用在 `fillFallback` 那四角（S=.50~.68 / L=.33~.52）上会把它们**推到接近纯色**
      //   （实测 A→(6,116,171) / B→(46,83,228) / C→(0,136,136) / D→(75,60,218)），
      //   兜底就从"柔和四角渐变"变成"几块硬色" —— 与上游观感不同。此处按字节码改回来。
      const hue: number = hueOfSeed(this.seed);
      fillFallback(u8, SRC_EDGE, SRC_EDGE, hue);
      boxBlurRgba(u8, SRC_EDGE, SRC_EDGE, FALLBACK_BLUR_RADIUS, FALLBACK_BLUR_PASSES);
      // ★ 只加日志（真机判读用）：四角的**颜色顺序**必须与上游一致
      //   A=TL(`hue`,.62,.40) / B=TR(`hue+28`) / C=BL(`hue−20`) / D=BR(`hue+46`)（`wujie.pa:91528-91611`）。
      //   若 TL/BR 与屏幕上的两团色位置对不上，问题就在"哪一路在画"，不在这张图。
      hilog.info(DOMAIN, TAG,
        'RzdBgPhaseMesh fallback hue=%{public}d TL=%{public}s TR=%{public}s BL=%{public}s BR=%{public}s',
        Math.round(hue), rgbAt(u8, 0, 0), rgbAt(u8, SRC_EDGE - 1, 0),
        rgbAt(u8, 0, SRC_EDGE - 1), rgbAt(u8, SRC_EDGE - 1, SRC_EDGE - 1));
      const pm: image.PixelMap = await image.createPixelMap(buf, {
        size: { width: SRC_EDGE, height: SRC_EDGE },
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      });
      if (this.disposed) {
        pm.release();
        return;
      }
      // 真源在这期间到了 ⇒ 兜底作废（不要把它盖上去）。
      // ★ 2026-10-19：只认"**属于当前 seed** 的真源"—— 上一首残留那张不算（否则兜底永远画不上，
      //   屏上就停在上一次那张旧图，正是本 bug 的形态）。
      if (this.src !== undefined && this.isSrcForCurrentSeed()) {
        pm.release();
        hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh fallback skip-stale gen=%{public}d reason=src', gen);
        return;
      }
      // 代际校验（照搬无界 `rebuildSource()`）：换过歌 ⇒ 这张兜底作废
      if (gen !== this.srcGen) {
        pm.release();
        hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh fallback skip-stale gen=%{public}d now=%{public}d',
          gen, this.srcGen);
        return;
      }
      // ⚠️ 顺序：**先换绑定、再释放旧图**（上游 `node.src = pm; old.release()`）
      const oldFallback: image.PixelMap | undefined = this.fallbackPm;
      const oldCached: image.PixelMap | undefined = this.cachedPm;
      this.fallbackPm = pm;
      this.fallbackSeed = this.seed;
      this.cachedPm = undefined;
      this.cachedSeed = '';
      this.controller.node.src = pm;
      if (oldFallback !== undefined) {
        this.releasePixelMapQuiet(oldFallback);
      }
      if (oldCached !== undefined) {
        this.releasePixelMapQuiet(oldCached);
      }
      this.controller.node.invalidate();
      this.onFrameNow();
      hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh fallback adopted gen=%{public}d t=%{public}d',
        gen, Math.round(this.accMs));
    } catch (err) {
      const e = err as BusinessErrorLike;
      hilog.warn(DOMAIN, TAG, 'makeFallback failed code=%{public}d msg=%{public}s', e.code, e.message);
    }
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
    // ★ 只加日志（真机判读 ②）：`accMs` 不会被清零 ⇒ 若每次 `frames=start` 的 `accMs` 都递增，
    //   则"两色位置变化"与 `tSec` 归零无关（网格几何的时间基是连续的）。
    hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh frames=start accMs=%{public}d', Math.round(this.accMs));
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
    hilog.info(DOMAIN, TAG, 'RzdBgPhaseMesh frames=stop accMs=%{public}d', Math.round(this.accMs));
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
          // ★★★★ 2026-10-17（**改回上游：vp 直传，不做 vp2px** —— 上一轮的 `vp2px` 是错的）
          //
          // 上游 `MeshCoverBg`（`wujie.pa:64796-64824`，λ `@4*^1*#`）：
          // ```
          //   onAreaChange((_o, n) => this.controller.resize(Number(n.width), Number(n.height)))
          // ```
          // 而 `RenderNode.frame` 的单位**就是 vp** —— 本机 SDK 声明（`arkui/Graphics.d.ts`，
          // `interface Frame`）里四个字段逐条写着 `Unit: vp`；`Number` 直传与
          // `LengthMetricsUnit.DEFAULT = 0`（注释原文 "The default length metrics unit, in vp"）一致。
          // ⇒ 上一轮把它改成 `ui.vp2px(...)` 属于**自造修法**（当时依据的是"第三方说 frame 是 px"），
          //   在 3x 屏上等于把画布放大 3 倍 ⇒ 网格顶点按错误画布生成，与真机观感对不上。
          // 本函数内 `draw()` 用的仍然是 `context.sizeInPixel`（px，绘制画布口径），两者不冲突。
          const wVp: number = Number(newArea.width);
          const hVp: number = this.fixedHVp > 0 ? this.fixedHVp : Number(newArea.height);
          this.controller.resize(wVp, hVp);
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
