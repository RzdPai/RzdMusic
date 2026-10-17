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

// ⚠️ `TextController` 是 ArkUI 的**全局环境类型**（不需要 import，`MusicPlayInfoBlock` 同款）
import { AppStorageV2, curves, uiObserver, UIUtils, window } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { hdsEffect } from '@kit.UIDesignKit';
import {
  AppStorageKeys,
  BreakpointConstants,
  // ★ 2026-10-16（照搬无界 `BarCollapse`）：控制条拖动收起/展开的手势状态机
  BarAction,
  BarCollapse,
  CoverRadiusState,
  CoverTintState,
  getWindowInfoState,
  ImmersiveType,
  isWidthBreakpointLgOrXl,
  Logger,
  MorphDrive,
  MorphStage,
  MusicStoreService,
  PlayedSongRecord,
  // ★ 2026-10-15（覆盖层统一）：端点量测的常量与工具（原来只在 `MusicPlayInfoBlock` 里用）
  PLAYER_BIG_COVER_ID,
  // ★ 2026-10-17（照搬无界 `PLAYER_ROOT_ID`）：非手势关闭要拍快照的那个节点（= 形变容器）
  PLAYER_ROOT_ID,
  // ★ 2026-10-17（照搬无界 ShrinkOverlay）：非手势关闭的快照收缩浮层
  MorphShrinkState,
  type MorphShrinkRect,
  PLAYER_META_TITLE_ID,
  PLAYER_META_SINGER_ID,
  MorphMetaEndpoint,
  areaLengthToVp,
  PlaybackFlowLightState,
  PlaybackShellConstants,
  PlayerExpandState,
  // ★ 2026-10-16：本页在 `.onDisAppear()` 里要判"播放页路由还在不在栈里"（见 `playerRouteStillPushed`）
  RouterUrlConstants,
  ShowMiniLyricState,
  StyleConstants,
  WindowInfo,
  WindowUtil
} from 'musicbasic';
import type { LyricMorphRect } from 'musicbasic';
import { MusicAppState } from '../model/PlayerModels';
import { SwitchBannerState } from '../model/SwitchBannerState';
import { MediaService } from '../model/MediaService';
import { ColorConversion } from '../util/ColorConversion';
import { PlayerConstants } from '../constant/PlayerConstants';
import { ControlAreaComponent } from './ControlAreaComponent';
import { LyricsComponent } from './LyricsComponent';
import { MiniLyricLinesComponent } from './MiniLyricLinesComponent';
import { MeshCoverBg } from './MeshCoverBg';
// ★ 网格背景的取图流水线（照搬无界 `design/logic/MeshSource.ets`）
import { SRC_EDGE, enhanceColors, boxBlurRgba } from '../util/MeshSource';
// ⚠️ 手机窄屏的**页 0 已经不用它了**（照搬无界：封面/歌名改成 `Swiper` 外的覆盖层），
//    但**宽屏 / 面板布局那两条分支仍在用**（`MusicPlayInfoBlock` 在 1817 / 2101 两处）
//    ⇒ import 不能删。那两条分支的统一是下一块（整屏封面页与覆盖层合并）。
import { MusicPlayInfoBlock } from './MusicPlayInfoBlock';
import { TopAreaComponent } from './TopAreaComponent';

/** Clamps a numeric RGB channel to an integer byte in [0, 255]. */
function clampRgbByte(n: number): number {
  if (!Number.isFinite(n)) {
    return 0;
  }
  return Math.max(0, Math.min(255, Math.floor(n)));
}

/** 一次封面下载解出的两张位图（见 `PlaybackPage.loadOnlineCoverPair`）。 */
class CoverDecodePair {
  /** 全尺寸，供 `effectKit` 取色。 */
  full: image.PixelMap | undefined = undefined;
  /** 64×64、RGBA_8888、可编辑 —— 网格背景的源。 */
  mesh: image.PixelMap | undefined = undefined;
}

/** Minimal shape for probing {@link image.PixelMap.release}; {@link Resource} does not carry this. */
interface PixelMapReleaseProbe {
  release?: () => void;
}

/** 一圈流光时长（ms）：慢一点才像"呼吸"而不是闪。 */
const FLOW_LIGHT_DURATION_MS: number = 12000;
/** 流光层整体不透明度：太高会盖住封面与歌词。 */
const FLOW_LIGHT_OPACITY: number = 0.55;

/**
 * Full-screen playback page: layered background, breakpoint-specific layout, dismiss gestures,
 * and dynamic tint from album art.
 */
@ComponentV2
export struct PlaybackPage {
  /**
   * 壳层的路由栈（`Index.ets:237 @Provider('pageIndexInfos')` 提供）。
   *
   * ★ 2026-10-16 新增：**唯一用途**是让本页在 `.onDisAppear()` 里判
   * 「播放页路由是不是还在栈里」—— 见 {@link playerRouteStillPushed}。
   * 为什么不从参数传：`PlaybackPageCoverContent` / `PlaybackPageBuilder` 都是 `@Builder`，
   * 多传一个 `NavPathStack` 要改三处签名；`@Provider/@Consumer` 是本工程已经在用的
   * 官方成对机制（`Index.ets` 已经是 `@Provider`），接一次即可。
   */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Window width/height breakpoint for responsive layout branches. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Global music UI and queue state. */
  @Local state: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** Mini lyric switch shared with settings. */
  @Local miniLyricState: ShowMiniLyricState =
    AppStorageV2.connect(ShowMiniLyricState, AppStorageKeys.SHOW_MINI_LYRIC_STATE, () => new ShowMiniLyricState())!;
  /** Status bar / navigation bar metrics for safe padding. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  @Local coverRadiusState: CoverRadiusState =
    AppStorageV2.connect(CoverRadiusState, AppStorageKeys.COVER_RADIUS_STATE, () => new CoverRadiusState())!;
  /** 播放页流光背景开关（设置项，AppStorageV2 共享，改设置立刻生效）。 */
  @Local flowLightState: PlaybackFlowLightState =
    AppStorageV2.connect(PlaybackFlowLightState, AppStorageKeys.PLAYBACK_FLOW_LIGHT_STATE,
      () => new PlaybackFlowLightState())!;
  /** 流光背景的两个颜色（由封面动态取色写入）。 */
  @Local coverTint: CoverTintState =
    AppStorageV2.connect(CoverTintState, AppStorageKeys.COVER_TINT_STATE, () => new CoverTintState())!;
  /** 流光着色器控制器：换歌后按新取到的封面颜色重设 uniform。 */
  private flowLightController: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();
  /** 已应用到着色器的取色版本号，避免同一份颜色重复下发布。 */
  private appliedTintVersion: number = -1;
  /**
   * Background cover source (Resource).
   *
   * ⚠️ 2026-10-15：背景改实时模糊后，本字段**恒为 `Resource`**（= `song.label`，原始封面），
   *   不再被赋成 `effectKit` 预渲染出来的模糊 PixelMap（那条路已停用，见
   *   {@link getImageColorAsync}）。类型保留 `PixelMap | Resource` 是为了兼容
   *   {@link isPixelMapCover} / {@link originalCoverSource} 那条兜底分支。
   */
  @Local imageLabel: image.PixelMap | Resource = $r('app.media.ic_avatar1');
  /** Cross-script source-switch banner state; AppStorageV2-backed for reactive UI. */
  @Local switchBanner: SwitchBannerState = SwitchBannerState.connect();
  /** Last seen banner timestamp for the deferred clear (avoids stale clears). */
  private bannerTs: number = 0;
  /** Pending clear timer id for the banner. */
  private bannerClearTimer: number = -1;
  /** Whether large / grid layout shows transport in the lyric column. */
  @Local isShowControlLg: boolean = false;
  /** Passed to child components that branch on tablet spacing. */
  @Local isTablet: boolean = true;
  /** Inverse tablet flag for lyric column variants. */
  @Local isTabletFalse: boolean = false;
  /** When true, renders the wide split panel layout (no top bar, custom paddings). */
  @Param panelLayout: boolean = false;
  /** Swiper page index (lyrics vs main stack on some layouts). */
  /** 当前 Swiper 页（0 = 封面页，1 = 歌词页）。 */
  @Local playbackSwiperIndex: number = 0;
  /** 歌曲菜单（那一横行的「更多」）是否展开；sheet 由 `ControlAreaComponent` 画。 */
  @Local playMenuOpen: boolean = false;
  /** 当前曲是否已收藏（那一横行右侧的心形）。与 `MusicPlayInfoBlock` 同一套读写。 */
  @Local isCurrentFavorite: boolean = false;
  @Local favStore: MusicStoreService = MusicStoreService.getInstance();

  /**
   * 网格背景的源位图（64×64、已过 `enhanceColors` + `boxBlurRgba(9,3)`）。
   *
   * ★ 2026-10-15（照搬无界 `MeshCoverBg`）：本页持有它的生命周期 ——
   *   换歌时 `publishMeshSource` 释放上一张；为空时背景层退回"实时模糊那张图"。
   */
  @Local meshSrc: image.PixelMap | undefined = undefined;
  /** 换图令牌（`MeshCoverBg` 靠它触发重新上传，见那里的 `@Monitor`）。 */  @Local meshSrcVersion: number = 0;

  /** 曲目或收藏版本变化时刷新心形。 */
  @Monitor('state.selectIndex', 'favStore.favoriteVersion')
  onFavoriteChanged(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.source.length === 0) {
      this.isCurrentFavorite = false;
      return;
    }
    this.isCurrentFavorite = this.favStore.isFavorite(song.source, song.songId);
  }

  /** 切换收藏（照抄 `MusicPlayInfoBlock.toggleFavorite()`，保证两处行为一致）。 */
  private toggleFavorite(): void {
    const song = this.state.getCurrentSongItem();
    if (song === undefined || song.source.length === 0) {
      return;
    }
    if (this.favStore.isFavorite(song.source, song.songId)) {
      this.favStore.removeFavorite(song.source, song.songId);
    } else {
      const record = new PlayedSongRecord();
      record.songId = song.songId;
      record.name = typeof song.title === 'string' ? song.title : '';
      record.singer = typeof song.singer === 'string' ? song.singer : '';
      record.source = song.source;
      record.img = song.cover;
      record.url = song.url;
      record.lyric = song.lyricText;
      record.time = Date.now();
      this.favStore.addFavorite(record);
    }
  }

  // ───────── 覆盖层（变换式）的几何 + 端点上报（对标无界 `floatingCover.onAreaChange → publishMorphTargets`）─────────

  private titleController: TextController = new TextController();
  private singerController: TextController = new TextController();

  // ⚠️ 这里原来有一整簇「变换式覆盖层」的取值器 —— **2026-10-17 已删除**：
  //      `coverLayerBase()` / `coverLayerScale()` / `coverLayerTx()` / `coverLayerTy()` /
  //      `coverLayerRadius()`（= 基准矩形 / 缩放 / 位移 / **半径 ÷ scale**）。
  //   删除理由（删前逐个 grep 全仓确认零消费者）：
  //   · 它们是**已被撤回的那一版**（"基准 + `.scale()` + `.translate()`"）的产物：
  //     现行走 **`coverLocalRect()`**，而它就是 `lyricFloatRect()` 的**直通**
  //     （尺寸/位置/圆角一律直接写进 `.width/.position/.borderRadius`，**本节点没有自己的 `.scale()`**）；
  //   · 唯一还在读它们的是下面那条 `RzdCoverRect` 诊断日志里的 `base=/tx=/ty=` 三段 ——
  //     而那三段量的正是"只有已被撤回那一版才有的量" ⇒ 留着只会误导后来人（已一并删掉）；
  //   · ★ 尤其 `coverLayerRadius()` 的注释写着「圆角作用在**未缩放**的节点上 ⇒ 必须除以 scale」，
  //     与现行设计**正好相反**：现在这个节点**没有** `.scale()` ⇒ 照它去"除以 scale"
  //     会把小封面那端的圆角放大到 ~6.7 倍（看着像个小圆片）。**这是必须删掉它的直接原因。**

  /**
   * 覆盖层上报「播放页封面端点」。
   *
   * ★ 对标无界 `floatingCover.onAreaChange → publishMorphTargets()`：**覆盖层自己就是量测源**。
   * ⚠️ **只在封面页静止（`t ≈ 0`）时上报**：形变途中这一层的位置是被形变驱动的，
   *    把移动中的矩形写回端点会形成正反馈（端点越跑越偏）。
   */
  private reportPlayerCoverFromOverlay(area: Area): void {
    if (this.lyricMorphT > 0.001) {
      return;
    }
    // ★★★ 2026-10-16：**形变中一律不上报**（见 `coverAnchorMeasurable()` 的注释）。
    //   点开/收起时覆盖层会跟着容器一起缩，那时量到的矩形是"迷你条封面那么大"，
    //   写进 `endCover*` 会把续飞封面的终点写坏 ⇒ 那一棒不画或飞到错的小矩形。
    if (!this.coverAnchorMeasurable()) {
      return;
    }
    const gx: number = areaLengthToVp(area.globalPosition.x);
    const gy: number = areaLengthToVp(area.globalPosition.y);
    const gs: number = areaLengthToVp(area.width);
    // ★★ 2026-10-15 诊断锚点（`hdc shell hilog -x | Select-String 'RzdCoverRect'`）——
    //   一次把**三个矩形**打出来，用来判定"封面落点不对"到底属于哪一种（**两种修法完全不同**）：
    //     · `measured` = `onAreaChange` 的 `globalPosition`。⚠️ 它是**布局几何**，
    //       **不含本节点自己的 `.scale()` / `.translate()`**（本仓注释多处强调过这一点）；
    //     · `geometry` = 纯几何端点（`playerCoverGeomRect()`，**不查任何节点**，对标无界
    //       `CoverMorph` 全程不量测）；
    //     · `base/tx/ty` = 覆盖层的参考系与位移 —— **渲染位 = base + translate**。
    //   **判据**：
    //     ① 若 `dxy` ≈ 上下安全区高度（几十 vp、且上下两个方向） ⇒ **内容盒偏移**问题
    //        ⇒ 就是 `PlaybackPageRoute` 那条页根扩展（`expandSafeArea` + `ignoreLayoutSafeArea`）在管；
    //     ② 若 `dxy` 是**别的常数 / 与 `tx,ty` 同值** ⇒ **量测口径**问题
    //        ⇒ 说明该把**渲染位（base + translate）**而不是布局位报上去（否则"端点由封面算、
    //          封面又按端点落位"会形成**死环**，误差会被稳定地锁住 —— 这正是本方法注释里
    //          早就写过的"自己量自己"）。
    //   ⚠️ 这条日志**只读不写**，不影响任何行为（`reportBig` 的入参一字未改）。
    const geom: LyricMorphRect = this.expandState.playerCoverGeomRect();
    // ★★★ 2026-10-16：**封面基准几何自证**（排查关键字 `RzdCoverGeom`）
    //   一条就能判"封面位置对不对"，不必再靠截图量像素：
    //     期望（手机 360×780 这档）：`edge=328`、`y≈136`（= 顶边）、`center=300`。
    //     · `edge` 明显大于 328（例如 393/369）⇒ 宽预算又用成"整窗宽"了；
    //     · `y` 接近 `(winH−edge)/2`（≈ 298）⇒ 又变回"在窗口里居中"（← 用户报的"低了好多"）。
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdCoverGeom edge=${geom.size.toFixed(1)} x=${geom.x.toFixed(1)} y=${geom.y.toFixed(1)} ` +
      `centerY=${(geom.y + geom.size / 2).toFixed(1)} radius=${geom.radius.toFixed(1)} ` +
      `win=${this.expandState.windowWidthVp.toFixed(0)}x${this.expandState.windowHeightVp.toFixed(0)} ` +
      `padTop=${this.expandState.topInsetVp().toFixed(1)} padBottom=${this.expandState.navigationBarBottomVp.toFixed(1)} ` +
      // ★ 判据：`centerY` 是本次**基准**的中心。期望（手机）= padTop + 244 ≈ 300。
      //   若它接近 `win/2`（≈462）⇒ 又回到"窗口居中"（用户报的"低"）。
      `expectCenter=${(this.expandState.topInsetVp() + 244).toFixed(1)} ` +
      `(windowCentered-y=${((this.expandState.windowHeightVp - geom.size) / 2).toFixed(1)})`);
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdCoverRect measured=(${gx.toFixed(1)},${gy.toFixed(1)},${gs.toFixed(1)}) ` +
      `geometry=(${geom.x.toFixed(1)},${geom.y.toFixed(1)},${geom.size.toFixed(1)}) ` +
      `dxy=(${(gx - geom.x).toFixed(1)},${(gy - geom.y).toFixed(1)}) ` +
      // ⚠️ 2026-10-17：原来这里还有 `base=/tx=/ty=` 三段，随"变换式覆盖层"那一簇一起删除了
      //   （它们量的只有已被撤回那一版才有的量，见本文件 :247 附近那段记账）。
      `win=${this.expandState.windowWidthVp.toFixed(0)}x${this.expandState.windowHeightVp.toFixed(0)} ` +
      `padTop=${this.expandState.topInsetVp().toFixed(1)} miniY=${this.expandState.miniY.toFixed(1)} ` +
      `miniSize=${this.expandState.miniSize.toFixed(1)} t=${this.lyricMorphT.toFixed(3)}`);
    this.expandState.reportBig(
      gx,
      gy,
      gs,
      this.coverRadiusState.radius);
  }

  /**
   * ★★★ 2026-10-16 新增：**"终点锚点只能在全尺寸那一帧上报"** —— 供
   * {@link PlaybackPage.reportPlayerCoverFromOverlay} 用（那两处 `reportBig` 的前置判据）。
   *
   * ## 为什么必须要这道门（点击打开没有封面动画的真几何风险）
   *
   * 覆盖层的 `.id(PLAYER_BIG_COVER_ID)` + `onAreaChange` 既是"播放页封面"的**唯一量测源**，
   * 又被挂在**形变容器内部**。于是：
   * ```
   *   容器已经被压到起点（scale ≈ 0.08）之后，任何一次 onAreaChange 报上来的
   *   globalPosition/width 都是【迷你条封面那么小】的矩形
   *   ⇒ 它会把 `endCoverSize/endCoverX/endCoverY` 写成迷你条的尺寸
   *   ⇒ 续飞封面（浮层克隆）的**终点**被写坏：那一棒要么不画、要么飞到一个错误的小矩形
   * ```
   * 用户实测「**点击打开 / 点击关闭 / 系统返回都没有封面动画**」与这条完全吻合 ——
   * 点击路径上覆盖层是**随页面一起挂载**的，它的第一次 `onAreaChange` 很可能就落在
   * "容器已被压到起点"之后。
   *
   * ⇒ 判据：**容器是恒等变换（`morphScale ≥ 1`）且没有裁剪**时才允许上报。
   *   形变中（`morphClipping()` 为真）一律不上报 —— 那时量到的都不是"静止态真实矩形"。
   * ⚠️ 静止态的 `morphScale` 恒为 1 ⇒ 这道门在静止态**恒真**，不影响既有行为。
   * ⚠️ 与既有的 `lyricMorphT > 0.001` 那道门是**两条独立条件**（那条管"歌词页飞行中"），
   *   两条都必须保留。
   */
  private coverAnchorMeasurable(): boolean {
    if (this.expandState.morphClipping()) {
      return false;
    }
    return this.expandState.morphScale >= 0.999;
  }

  /**
   * 上报歌名/歌手的**排版端点**（形变把文字由大变小/由小变大时按同一套字体参数插值）。
   *
   * ★ 这两个上报原来在 `MusicPlayInfoBlock` 里。它从窄屏页 0 移除后必须搬到这里 ——
   *   否则端点量不到 ⇒ **封面缩成 0（看不见）+ 展开动画没有端点**（2026-10-15 那次崩溃的根因）。
   * 字体参数与那一行**实际渲染的值**保持一致（`LYRIC_META_TITLE_FP` / `LYRIC_META_ARTIST_FP`）。
   */
  private publishMetaEndpoint(singer: boolean): void {
    const song = this.state.getCurrentSongItem();
    const endpoint: MorphMetaEndpoint = new MorphMetaEndpoint();
    endpoint.id = singer ? PLAYER_META_SINGER_ID : PLAYER_META_TITLE_ID;
    endpoint.controller = singer ? this.singerController : this.titleController;
    const raw: string | Resource = singer ? (song?.singer ?? '') : (song?.title ?? '');
    endpoint.content = typeof raw === 'string' ? raw
      : this.getUIContext().getHostContext()!.resourceManager.getStringSync(raw.id);
    // ★ 2026-10-15：上报**当前这一帧**的字号（两端插值的结果），而不是固定的歌词页值 ——
    //   否则形变端点量到的是一个"只在歌词页才成立"的字号，封面页那一端会偏小。
    endpoint.fontFp = singer ? this.metaArtistFp() : this.metaTitleFp();
    endpoint.family = singer ? PlayerConstants.FONT_FAMILY_BLACK : PlayerConstants.FONT_FAMILY_BOLD;
    endpoint.weight = singer ? 400 : 700;
    endpoint.color = singer ? $r('app.color.play_singer_color') : $r('app.color.play_text_color');
    endpoint.opacity = singer ? 1 : 0.86;
    endpoint.maxLines = 1;
    this.expandState.registerMorphMeta(false, singer, endpoint);
  }

  /**
   * ★★★ 2026-10-16 新增：封面落位随 `lyricMorphT` 变化时打一次对账日志。
   *
   * ⚠️ `lyricMorphT` 是**逐帧**改的（补间里写），所以这里**必须**有节流 ——
   *   节流与去重都在 {@link PlaybackPage.logCoverLocal} 里（100ms + 签名比对）。
   * 排查关键字：`hdc shell hilog -x | Select-String 'RzdCoverLocal'`
   */
  @Monitor('lyricMorphT')
  onLyricMorphTChanged(): void {
    this.logCoverLocal();
  }

  /** 曲目变化时重报两个文字端点（原来在 `MusicPlayInfoBlock` 的 `@Monitor` 里）。 */
  @Monitor('state.selectIndex')
  onMetaEndpointChanged(): void {
    this.publishMetaEndpoint(false);
    this.publishMetaEndpoint(true);
  }

  /**
   * @returns 歌词页那一横行的**左内边距**（vp）。
   *
   * 按 `lyricMorphT` 在两个端点之间插值：
   * · `t = 0`（封面页）= 页面边距，歌名居中区正下方；
   * · `t = 1`（歌词页）= **小封面右缘 + 12**，文字让开小封面。
   * 无界靠 `floatingCover` 与 `metaRow` 两层的横向错位达到同一效果，这里用内边距表达、
   * 少一层、也天然随进度连续（不会在交棒帧跳一下）。
   */
  private lyricMetaLeftInset(): number {
    const side: number = PlaybackPage.LYRIC_META_SIDE_VP;
    const t: number = this.lyricMorphT;
    const coverRight: number = this.lyricFloatRect().x + this.lyricFloatRect().size;
    return side + (coverRight + PlaybackPage.LYRIC_META_GAP_VP - side) * t;
  }
  /** False after teardown to ignore async image callbacks. */
  private isAlive: boolean = true;
  /** Bumps on each {@link getImageColorAsync} run so stale async work skips UI updates and releases pixels. */
  private imageColorJobSeq: number = 0;
  /** Cached UIAbility context for resource and color extraction. */
  private context: common.UIAbilityContext | undefined = undefined;
  /** Logger tag for this page. */
  private static readonly logTag: string = 'PlaybackPage';
  /** 收起态内容层占窗口高度的百分比：贴底一条，大致等于迷你条那一条。 */
  private static readonly COLLAPSED_HEIGHT_PERCENT: number = 9;
  /** 展开动画的起点进度（= 完全收起）。 */
  private static readonly EXPAND_START_PROGRESS: number = 100;
  /** 展开/收起动画时长（ms），与参考工程 `OPEN_PLAYER_UI_ANIMATION_MS` 一致。 */
  private static readonly EXPAND_DURATION_MS: number = 380;
  /**
   * 容器形变展开的时长（ms）。
   *
   * 无界 Tokens 的主转场档位是 300ms / 420ms；这里取 420ms 那档的观感（整页在缩放，
   * 比局部元素换位需要更多时间），曲线用它的 `cubic-bezier(0.23, 1.0, 0.32, 1.0)`（快出缓入）。
   */
  private static readonly MORPH_OPEN_DURATION_MS: number = 350;
  /**
   * 容器形变收起（反向）的时长（ms）：比展开略快，收起来要干脆。
   */
  /**
   * 关闭（反向形变）的**基础时长**与**时长下限比例**（对标无界 `MainPage` 的两个常量）。
   *
   * ★★ 2026-10-15（照搬无界，修「关闭播放器几乎没动画」）：
   *   `reverseMs = round(REVERSE_MS × max(REVERSE_MIN_RATIO, morphT))`
   *   （`_recover/logic-src/开关播放器-手势路径定稿.md` §0 速查 L29 / §八 常量表 L620-625）。
   *   ⇒ 满展开时 **460ms**；只拉开一点点（`morphT < 0.4`）时按下限 **460×0.4 = 184ms**。
   *
   * ⚠️ 被替换掉的旧常量 `MORPH_CLOSE_DURATION_MS = 350` 有两处错（都不是"数值微调"）：
   *   ① **时长偏短**：350 vs 无界满展开 460，少了 24% 的行程时间；
   *   ② 更要命的是**缓动整条抄错**：旧代码用 `cubicBezier(0.23, 1.0, 0.32, 1.0)`
   *      （= `EASE_OUT_STR`，那是**打开提交**用的曲线），它**前 15% 时间就走完约 70% 行程**
   *      ⇒ 350ms 里约 50ms 就缩完、剩下 300ms 几乎静止 = 用户说的"**几乎没动画**"。
   *   无界"关闭提交"用的是 **`REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`**（慢启动）。
   *   完整对照与"别搞混三处缓动"的说明写在 `closeFullScreenPlayback()` 里。
   */
  private static readonly REVERSE_MS: number = 460;

  /**
   * `page 0` 小歌词相对页底的**下压量**（vp）。
   *
   * ★★ 2026-10-15（修用户实测「播放界面这里错位」）：见 `MiniLyricLinesComponent` 那处调用点的注释 ——
   *   小歌词原来贴页底，正好落在 `Swiper` 之外那条**歌名/歌手覆盖层**的高度带里（≈660~690vp）。
   *   取值 = `PlayerExpandState` 里歌名块的高度口径（`LYRIC_META_BLOCK_H_VP = 44`），
   *   推开"两行文字"那么多即可；静止态它只是一个固定位移，**不参与任何补间**。
   */
  private static readonly MINI_LYRIC_SINK_VP: number = 44;

  /** 小歌词容器的组件 id（只给 {@link PlaybackPage.logLayoutBoxes} 量测用，不参与任何逻辑）。 */
  private static readonly MINI_LYRIC_BOX_ID: string = 'rzd_page0_mini_lyric_box';

  /** 网格背景层的组件 id（只给 {@link PlaybackPage.logBgLayer} 量测用）。 */
  private static readonly MESH_BG_ID: string = 'rzd_mesh_bg_layer';

  /**
   * ★★★ 2026-10-16（**GLM5.3 会诊发现：我上一轮那道门是"死门"**）
   *
   * ## 事故经过（如实记，别再犯）
   * 我给内容层 `.onAppear()` 的兜底分支加过一道"跨实例时间窗"门，判据写的是
   * `PlaybackPage.lastCloseAtMs > 0 && Date.now() - PlaybackPage.lastCloseAtMs < CLOSE_WINDOW_MS`。
   * GLM 指出：**整份关闭代码里没有任何一行写 `lastCloseAtMs`，而 `CLOSE_WINDOW_MS` 也从未声明**
   * ⇒ 那道门**恒假**，等于什么都没加。我查证了时间线：那份工作区编辑（23:54）
   *   **晚于最后一次成功构建（23:49）** ⇒ **它从未被编译过**，用户装到的包里根本没有它。
   * ⇒ 教训：**改了源码必须当场构建**；"我加了门"与"门在产物里"是两件事。
   *
   * ## 为什么需要"跨实例"的判据
   * 本页所有 `@Local` / 私有字段都是**实例局部**的；而 `morphReset()` 会把
   * `PlayerExpandState` 里那套（`morphSessionStarted` / `morphStage` / `morphGeomReady`）全清掉。
   * ⇒ 关闭余波落在**新实例**身上时，实例局部的门全部失明。
   *   只能用一个**跨实例共享**的时刻做判据 ⇒ 本静态字段。
   *
   * ⚠️ **两个字段必须成对使用**：`lastCloseAtMs` 由**关闭链路**写
   *    （`closeFullScreenPlayback` 入口），`CLOSE_WINDOW_MS` 只在此处当窗口宽度。
   *    别再出现"只读不写"（那正是上一轮的事故）。
   */
  private static lastCloseAtMs: number = 0;

  /**
   * ★ 2026-10-17：上一次关闭**走了退化路径**的原因（短标签；空 = 没走退化）。
   *
   * 由 `closeLiveMorphFallback()` 写、`closeFullScreenPlayback()` 的 `ev('CLO', …)` 读并**清空**
   * ⇒ 徽标第十三行的 `CLO:… fb=<原因>` 就是"这次返回关闭走的是快照还是活页"的直接读数。
   * ⚠️ 只在"退化那一次"有值，读完即清（否则会被当成常驻状态）。
   */
  private static closeFallbackReason: string = '';

  /**
   * ★★★ 2026-10-16（**关闭过程的时序"黑匣子"** —— 打破"没有设备读数"的僵局）
   *
   * ## 为什么必须做成"跨实例静态锁存"
   * 用户报的两条（「关闭时背景只剩一条」「关闭后又放一遍展开」）**都发生在关闭过程中**，
   * 而**播放页一 pop，屏上那个徽标就跟着没了** ⇒ 事后读不到任何东西。
   * ⇒ 把关键事件记进**模块级静态环形缓冲**，等**下一次打开播放页**再显示 ⇒ 就有了"上一次关闭"的完整时序。
   *
   * ## 记什么（只记"状态转移"与"关键出口"，**不记每帧**，否则环形缓冲会被刷掉）
   * ```
   *   CLO  = closeFullScreenPlayback 入口（写下 lastCloseAtMs）
   *   LV   = morphBeginLeaving（收起相位）
   *   SET  = 关闭收尾定时器到点（附 closeGen / alive / 走了哪一支）
   *   LND  = morphLand（落回迷你条）
   *   SQZ  = squashLandAnim（挤压起）
   *   RST  = morphReset（几何回恒等）
   *   POPT = 壳层把 isShowPlay 置 false（触发 popPlayerRoute）
   *   REM  = 壳层真的把播放页路由删掉了（`popPlayerRoute` 里的 `pop/removeByIndexes`）
   *          ★ **`RST` 与 `REM` 的 `t+` 差**就是"满屏中间态"有多长（用户第 ③ 条的判据）
   *   DIS  = 内容层 onDisappear（附 wasAlive）
   *   AP   = 内容层 onAppear（附走了哪条分支）
   *   INTR = playExpandIntro 起（**若出现在关闭之后，就是"又放一遍展开"的直接证据**）
   *   OPN  = 壳层 isShowPlay=true（触发 pushPlayerRoute）
   * ```
   * 每项带一个相对时间（ms，相对缓冲区里第一条）。
   *
   * ## 读法（徽标**第十三行**）
   * 缓冲区**以一次关闭为单位**（`CLO` 一到就清空重来），所以读到的永远是"最近一次关闭"的全过程：
   * 正常关闭后重新打开，应当看到形如：
   * ```
   *   t0 CLO → t+2 LV → t+480 SET:ok/gen=3 → t+481 LND → t+482 SQZ → t+483 RST → t+484 POPT → t+490 DIS:alive=0
   * ```
   * 异常形状与含义：
   * - 出现 **`INTR`**（在 DIS 之后）⇒ 确认是"关闭余波重放展开"；
   * - 出现 **`OPN`**（在关闭段之后，而用户并没点开）⇒ 壳层把播放页又推了一次；
   * - `SET:genBAD` / `SET:dead` ⇒ 收尾定时器走了早退支（**几何不会复位** ⇒ 背景只剩一条同源）；
   * - **没有 `RST`** ⇒ `morphReset()` 没执行 ⇒ 几何停在中间态；
   * - `RST` 在 `REM`（路由真被删掉）**之前超过一帧** ⇒ 存在"pop 了但几何已经满屏"的中间帧
   *   （GLM 的假设，§123.3 —— 也就是用户第 ③ 条的候选机制）。
   */
  private static evLog: string = '';
  private static evT0: number = 0;
  private static evCount: number = 0;

  /**
   * 记一条时序事件（见 {@link PlaybackPage.evLog}）。
   * @param tag 事件名（上面那张表里的短标签）
   * @param detail 可选的补充（例如 `ok` / `genBAD` / `dead`）
   *
   * ⚠️ **public static**（不是 private）：壳层 `products/default/.../pages/Index.ets` 的
   *    `@Monitor('appState.isShowPlay')` 里要记 `OPN` —— 「关闭后又放一遍展开」的
   *    头号嫌疑就是**壳层把播放页又推了一次**，那一笔只有壳层能记。
   *    （壳层 → 播放页是单向依赖：`player` 的桶文件已经导出 `PlaybackPage`，不构成循环。）
   */
  public static ev(tag: string, detail: string = ''): void {
    const now: number = Date.now();
    // ★ 缓冲区以**一次关闭**为单位：`CLO`（关闭链路入口）一到就把上一轮整段清掉、`t0` 重置到这一刻。
    //   为什么这样切：徽标是**等下一次打开播放页**才显示的（关闭途中页面已经被 pop），
    //   若不清，读到的是"好几轮混在一起"的日志，`t+` 也会一直往上涨到看不出相对时序。
    //   切成"最近一次关闭"之后，读法就固定成 `t+0 CLO → …`。
    if (tag === 'CLO') {
      PlaybackPage.evLog = '';
      PlaybackPage.evT0 = now;
      PlaybackPage.evCount = 0;
    } else if (PlaybackPage.evT0 === 0) {
      PlaybackPage.evT0 = now;
    }
    PlaybackPage.evCount++;
    const rel: number = now - PlaybackPage.evT0;
    const item: string = detail.length > 0 ? `${tag}:${detail}` : tag;
    PlaybackPage.evLog = `${PlaybackPage.evLog} t+${rel} ${item} |`;
    // 环形：超过 900 字符就砍掉最早那段（保住"最近的关闭全过程"）
    if (PlaybackPage.evLog.length > 900) {
      const cut: number = PlaybackPage.evLog.indexOf('|');
      if (cut >= 0) {
        PlaybackPage.evLog = PlaybackPage.evLog.substring(cut + 1);
      }
    }
  }

  /** 关闭余波窗口（ms）—— `lastCloseAtMs` 的宽度。⚠️ 工程判断值，不是逆向值（见上方说明）。 */
  private static readonly CLOSE_WINDOW_MS: number = 1500;

  /**
   * `scheduleMorphResetAfterPop()` 的轮询间隔（ms）与最大次数。
   *
   * ⚠️ **工程判断值，不是逆向值**：无界没有这条"等 pop 再复位"的显式轮询
   * （它的页面是模态，收起完成即卸载）。这里只是因为我们的路由 pop 是**异步**的。
   * 32ms ≈ 两帧；8 次 ≈ 256ms 上限（超时兜底复位，宁可晚也不能不清）。
   */
  private static readonly RESET_POLL_MS: number = 32;
  private static readonly RESET_POLL_MAX: number = 8;

  /** 上一次 `RzdBgLayer` 的签名（节流）。 */
  private lastBgLayerLog: string = '';

  /**
   * ★★★ 2026-10-16 新增诊断：**背景层到底是多大、多不透明**。
   *
   * ## 它判什么（用户反复报的两条都靠它定性）
   *
   * ```
   *   hdc shell hilog -x | Select-String 'RzdBgLayer'
   *   ⇒ RzdBgLayer box=(x,y,w,h) win=WxH clip=… p=… op=… squashing=… meshSrc=yes|no playing=…
   * ```
   *
   * | 读到的 | 含义 |
   * | --- | --- |
   * | `box.w/h ≈ win` **且 `op ≈ 1`** | 背景整屏不透明 ⇒ 这才是「**背景全屏**」的形状 |
   * | `box.w/h ≈ win` 但 `op` 很小（0.04~0.3） | 背景整屏但几乎透明 ⇒ **与无界同形**（无界那层也在满屏层里） |
   * | `box.w/h` 明显小于 `win` | 背景被限制在小窗口里（另一种形状） |
   * | `meshSrc=no` | 网格没源 ⇒ 屏上是**兜底取样色**（在线歌曲那层是 `rgba(20,20,22,0.5)`） |
   *
   * ⚠️ 只读：本方法不写任何状态。
   */
  private logBgLayer(): void {
    let box: string = 'none';
    try {
      const node = this.getUIContext().getFrameNodeById(PlaybackPage.MESH_BG_ID);
      if (node !== null) {
        const p: Position = node.getPositionToWindowWithTransform();
        const s: Size = node.getMeasuredSize();
        box = `(${areaLengthToVp(p.x).toFixed(1)},${areaLengthToVp(p.y).toFixed(1)},` +
          `${this.getUIContext().px2vp(s.width).toFixed(1)},${this.getUIContext().px2vp(s.height).toFixed(1)})`;
      }
    } catch (err) {
      box = 'err';
    }
    const op: number = this.backgroundRevealOpacity();
    const sig: string = `${box}|${op.toFixed(2)}|${this.expandState.morphP.toFixed(2)}`;
    if (sig === this.lastBgLayerLog) {
      return;
    }
    this.lastBgLayerLog = sig;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdBgLayer box=${box} win=${this.expandState.windowWidthVp.toFixed(0)}x` +
      `${this.expandState.windowHeightVp.toFixed(0)} clip=${this.expandState.morphClipHeight.toFixed(0)} ` +
      `p=${this.expandState.morphP.toFixed(3)} op=${op.toFixed(3)} ` +
      `squashing=${(this.expandState.morphSquashY !== 1)} stage=${this.expandState.morphStage} ` +
      `meshSrc=${this.meshSrc !== undefined ? 'yes' : 'no'} playing=${this.state.isPlay} ` +
      `active=${this.state.isShowPlay}`);
  }

  /**
   * 控制区**三段结构**的两根占位条（组件 id，只给 {@link PlaybackPage.logLayoutBoxes} 量测用）。
   *
   * 出处：无界 overlay 的 builder 树（`wujie.pa:190464` / `190497`）——
   * ```
   *   Row().height(lerp(swiperGap(), 10, swiperProgress))   // 190464  ← "Swiper ↔ 进度条"
   *   Row().height(chrome().gapScrub)                       // 190497  ← "进度条 ↔ 传输条"
   * ```
   * ⚠️ 它们**不是 padding**，是**零内容 Row**（`Column` 里的普通兄弟节点）——
   *   所以"三段"是 `[Swiper | gapSwiper 行 | gapScrub 行 | 进度条+传输条]`。
   * ⚠️ 无界那两份用的是 `.height(lerp(...))`，`lerp` 第三实参是 `swiperProgress`：
   *   拖拽打开/关闭的过程中这两根条会跟着补间（`a=swiperGap, b=10`）。
   *   我们这一侧没有 `swiperProgress` 这个量（我们的展开进度叫 `morphP`，语义不同），
   *   所以**静止态取 `swiperGap()` 那一端**（= `lerp(t=0)`），形变期不动 —— 见方法注释。
   */
  private static readonly SWIPER_GAP_ROW_ID: string = 'rzd_gap_swiper_row';
  private static readonly CHROME_SCRUB_GAP_ROW_ID: string = 'rzd_gap_scrub_row';

  /**
   * @returns 「Swiper ↔ 进度条」占位条的高度（vp）—— 无界 `swiperGap()`（`wujie.pa:180127`）。
   *
   * ## 为什么这里是**一个常数**、不是 `lerp`
   *
   * 无界写的是 `lerp(swiperGap(), 10, swiperProgress)`，即**拖拽打开/关闭过程中**这根条
   * 从 `swiperGap()` 收到 10vp。`swiperProgress` 是**它自己的**下拉进度量（0→1 对应关闭动作），
   * 我们这一侧对应的是 `expandState.morphP`（展开进度，**方向与相位都不同**：
   * 我们是"从迷你条长到整屏"，它是"从整屏往下拖走"）。
   * ⇒ 硬套 `lerp(..., morphP)` 会得到**反相**的曲线（展开时反而收窄），那是**新造一个行为**，
   *   不是照搬。所以静止态老老实实取 `lerp` 的 `t=0` 那一端（`swiperGap()`），
   *   并把"形变期补间"登记为待办（`RzdMusic待确认清单.md` D4-b）。
   */
  private swiperGapRowHVp(): number {
    return this.expandState.swiperGapVp();
  }

  /**
   * @returns 「进度条 ↔ 传输条」占位条的**额外**高度（vp）。
   *
   * ⚠️ 恒为 0，**不是漏做**：这一段的间距我们**已经有了**，位置在
   *   `ControlAreaComponent.bottomPanel()` 里那个 `Column` 的 `.margin({ bottom: … })`
   *   （按断点取 `app.float.slider_margin_bottom*`）。无界表里这一段叫 `gapScrub`
   *   （FULL 28 / MEDIUM 20 / COMPACT 14）。
   * ⇒ 这里保留一个 0 高的可量测节点，**只为**把"实测间距 vs `gapScrub`"打进日志
   *   （`RzdSwiperBox`），等真机数据回来再决定是"把 margin 换成 `gapScrub`"还是"保留派音原值"。
   *   现在**不并行加**（否则就是同一段间距两条口径 —— 本仓反复踩过的形状）。
   */
  private chromeScrubGapRowHVp(): number {
    return 0;
  }

  /**
   * ★ 2026-10-15 诊断锚点：把**四个会互相压的块**的窗口矩形一次打出来。
   *
   * 排查关键字：`hdc shell hilog -x | Select-String 'RzdBoxes'`
   *
   * 打的是**窗口坐标**（`getPositionToWindowWithTransform()`）与**实测尺寸**，
   * 与用户截图的像素可以直接换算对账（本机 1224×2776 截图 ⇒ 3px/vp）：
   * ```
   *   RzdBoxes cover=(x,y,w,h) title=(…) singer=(…) lyric=(…)
   * ```
   * **判据（哪两个块真的相交、就改那一对）**：
   *   · `lyric.top` 落在 `[singer.top, singer.bottom]` 区间内 ⇒ **小歌词压在歌名/歌手那一行上**
   *     ⇒ 调 `MINI_LYRIC_SINK_VP`（本仓已按"两行文字"的量级给 44）；
   *   · `lyric.bottom` 越过控制区顶边 ⇒ 小歌词被控制区压住 ⇒ 那是另一处（Swiper 权重分配）；
   *   · `cover.bottom` 与 `title.top` 的间距 ≈ 0 ⇒ 歌名紧贴封面（`LYRIC_META_GAP_VP` 那一档）。
   * ⚠️ 只读、不写：本方法不改变任何状态（不会形成"量测→改状态→再量测"的死环）。
   */
  private logLayoutBoxes(): void {
    const g = (id: string): string => {
      try {
        const node = this.getUIContext().getFrameNodeById(id);
        if (node === null) {
          return 'none';
        }
        const p: Position = node.getPositionToWindowWithTransform();
        const s: Size = node.getMeasuredSize();
        return `(${areaLengthToVp(p.x).toFixed(1)},${areaLengthToVp(p.y).toFixed(1)},` +
          `${this.getUIContext().px2vp(s.width).toFixed(1)},${this.getUIContext().px2vp(s.height).toFixed(1)})`;
      } catch (err) {
        return 'err';
      }
    };
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdBoxes cover=${g(PLAYER_BIG_COVER_ID)} title=${g(PLAYER_META_TITLE_ID)} ` +
      `singer=${g(PLAYER_META_SINGER_ID)} lyric=${g(PlaybackPage.MINI_LYRIC_BOX_ID)} ` +
      `win=${this.expandState.windowWidthVp.toFixed(0)}x${this.expandState.windowHeightVp.toFixed(0)} ` +
      `pad=${this.expandState.topInsetVp().toFixed(1)}/${this.expandState.navigationBarBottomVp.toFixed(1)} ` +
      `sink=${PlaybackPage.MINI_LYRIC_SINK_VP} t=${this.lyricMorphT.toFixed(3)}`);
    // ★★★ 2026-10-16（照搬无界）：**控制区三段结构**的对账日志。
    //   判据（真机上一次就够）：实测 Swiper 高度 vs `estBoxH()`（= `usableH − chromeTotal`），
    //   以及两根占位条的实测高 vs 应有高。差得多 ⇒ 我们控制区的自然高和无界表对不上，
    //   那时再决定"往表里对齐"还是"改我们自己的高度"（**不要两头一起改**）。
    //   排查关键字：`hdc shell hilog -x | Select-String 'RzdSwiperBox'`
    const gapWanted: number = this.expandState.swiperGapVp();
    const gapGot: number = this.boxH(PlaybackPage.SWIPER_GAP_ROW_ID);
    const scrubWanted: number = this.expandState.chromeGapScrubVp();
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdSwiperBox tier=${this.expandState.chromeTier} usableH=${this.expandState.usableHVp().toFixed(1)} ` +
      `chromeTotal=${this.expandState.chromeTotalVp().toFixed(1)} ` +
      `estBoxH=${this.expandState.estBoxHVp().toFixed(1)} ` +
      `gapSwiper want=${gapWanted.toFixed(1)} got=${gapGot.toFixed(1)} ` +
      `gapScrub want=${scrubWanted.toFixed(1)} got=${this.boxH(PlaybackPage.CHROME_SCRUB_GAP_ROW_ID).toFixed(1)}`);
  }

  /** @returns 某个组件 id 的**实测高度**（vp，量不到返回 -1）—— 只给诊断日志用。 */
  private boxH(id: string): number {
    try {
      const node = this.getUIContext().getFrameNodeById(id);
      if (node === null) {
        return -1;
      }
      return this.getUIContext().px2vp(node.getMeasuredSize().height);
    } catch (err) {
      return -1;
    }
  }
  /** 关闭时长比例的下限（`morphT` 小于它时按它算）—— 对标无界 `REVERSE_MIN_RATIO = 0.4`。 */
  private static readonly REVERSE_MIN_RATIO: number = 0.4;
  /**
   * 点击/起播意图打开时，补间**延后两帧**再起（ms）。
   *
   * 页面这一帧才刚挂载、还没画过第一帧；同帧起补间的话，等第一帧真的画出来时
   * 动画已经走了几十毫秒 —— 用户看到的就是"直接点开是从中间开始的"。
   */
  private static readonly MORPH_INTRO_DELAY_MS: number = 50;
  /**
   * 一次跟手会话的最长合理时长（ms）。
   *
   * `pullDragging` 残留时点击打开会跳过形变初始化（退化成老动画），这条阈值用来
   * 判定"这个标记已经过期"：一次上拉/下拉不可能持续 2 秒以上。
   */
  private static readonly PULL_DRAG_MAX_MS: number = 2000;
  /**
   * 锚点还没量到时的重试间隔（ms）。
   *
   * "点击打开"那一刻迷你条/播放页常常还没布局完（`getFrameNodeById` 拿不到节点），
   * 无界的做法是**注册就绪回调等着**、而不是退化成老动画；我们这里用几帧重试等价实现。
   */
  private static readonly MORPH_RETRY_MS: number = 32;
  /**
   * 剩余重试次数（每次打开重置）—— **照抄反编译的 `PlayerPage.schedulePublishRetry`**：
   *
   *   最多重试 12 次、每次间隔 32ms（总窗口约 384ms），用来等"刚挂载、还没布局完"的
   *   目标节点变成可量测。反编译结论：无界的播放页**也不常驻**（同样是 push 出来的），
   *   它之所以"第一次就有封面飞入"，靠的就是这个重试窗口 + `setFinalStatus()` 兜底。
   */
  private morphRetryLeft: number = 12;
  /**
   * 「可以开始画了」的门：形变真正开始（几何量到并压到起点）之前，整页保持**全透明**。
   *
   * 为什么需要它：为了先量到"原尺寸的封面矩形"，挂载后到形变开始之间会有 1~2 帧
   * 播放页处于**未缩小**状态 —— 那几帧若照常绘制就会闪一下完整播放页。
   * 关掉绘制不影响布局（`opacity` 不参与布局），所以量测照常进行。
   */
  @Local introPaintReady: boolean = false;
  /**
   * 形变早期"底面颜色"淡入的终点进度（0…1）。
   *
   * 迷你条也是在这个进度淡完的（`PlayerExpandState.miniBarOpacity` 用 0.20），
   * 两边必须对齐：底面（底色 + 取色层）到这里正好是播放页真正的背景色，
   * 迷你条到这里正好消失 —— 观感就是"播放条的颜色化成了页面背景、并跟着长大"。
   */
  private static readonly MORPH_BG_FADE_TO: number = 0.20;
  /**
   * 封面 + 歌名「续飞到歌词页顶部」的时长（ms）。比展开略短，因为它只是局部元素换位。
   *
   * A2 起这条时长**真的被用上了**（`animateLyricMorph` 的 `animateTo`）；此前整套歌词页
   * 封面形变被 `lyricMorphVisible = false` 无条件关着，这个常量是空的。
   */
  private static readonly LYRIC_MORPH_DURATION_MS: number = 360;
  /** 控制区静止多久后自动收起（ms）。 */
  /**
   * 控制区**空闲自动收起**的等待时长（ms）。
   *
   * ★★★ 2026-10-16（照搬无界 `PlayerPage.IDLE_MS`）：**5000**。
   *   出处：`wujie.pa:197964` 的 `stlexvar 0x0, 0x8` 前一条 `ldai 0x1388`
   *   （`0x1388` = **5000**），而 `startIdle()`（`wujie.pa:179936-179938`）
   *   就是 `setTimeout(<λ>, IDLE_MS)`，那个 λ（`193408-193418`）做什么是明确的：
   *   `idleTimer = -1; this.hideChrome();`。
   * ⚠️ 我们原来是 **3000**（本仓自定值，无出处）⇒ 这就是"空闲时间不一样"的来源。
   */
  private static readonly CHROME_AUTO_HIDE_MS: number = 5000;
  /**
   * 控制区"亮出 / 收起"那条补间的时长（ms）。
   *
   * ★★★ 2026-10-17（照搬无界 `PlayerPage.CHROME_ANIM_MS`）：**350**。
   *   出处：`showChrome()` 与 `hideChrome()` 各自那次 `animateTo(...)` 的 `duration`
   *   都是 `throw.undefinedifholewithname "CHROME_ANIM_MS"`
   *   （`logic-src/PlayerPage.abc.txt` 的 11967-11976 与 4210-4219），
   *   常量值 350 见 `_recover/logic-src/MiniMorph渲染方与顶底栏淡入公式.md:163`
   *   （`CHROME_ANIM_MS | 350 | 顶栏显隐时长（= D_MAIN）`）。
   *
   * ⚠️ 我们原来是 **240 + `Curve.EaseIn`（收起）/ `Curve.EaseOut`（唤出）**，
   *   是**本仓自定值**（无出处）⇒ 按"不许夹带自编值"改成无界那两个值：
   *   **350ms + `Curve.EaseInOut`（显、隐同一条曲线）。**
   */
  private static readonly CHROME_ANIM_MS: number = 350;
  /** 手机端 Swiper 里「歌词页」的下标（0 = 封面页）。 */
  private static readonly SWIPER_INDEX_LYRIC: number = 1;
  /**
   * 歌词区**上下滑切换控制区**的阈值（vp）—— 照抄无界 `SWIPE_TOGGLE_VP`。
   *
   * 出处：`PlayerPage.onLyricSwipe`（`_recover/logic-src/PlayerPage.abc.txt:6942` 的
   * `throw.undefinedifholewithname "SWIPE_TOGGLE_VP"`，以及**高支**的字面量
   * `6974 ldai 0x18` = **24**）；归档常量表 `MiniMorph渲染方与顶底栏淡入公式.md:171`
   * 同样记着 `SWIPE_TOGGLE_VP | 24`。
   * ⚠️ 本仓原来写的是 **12**（自定的一半）⇒ 太容易误触（本层是 `parallelGesture`）。
   */
  private static readonly SWIPE_TOGGLE_VP: number = 24;
  /**
   * 歌词区**上滑隐藏控制区**那一支是否放开 —— 对应无界的 `entryAllowsManual(lyricImmersive)` 门。
   *
   * 无界：`entryAllowsManual(mode) = mode === MANUAL || mode === BOTH`，而
   * `LyricEntryMode` 默认档是 **AUTO**（`歌词页浮层封面与歌名定稿.md` §1：OFF0 / AUTO1 / MANUAL2 / BOTH3）
   * ⇒ **默认档下"上滑隐藏"什么都不做**（那一支整段被门挡住）。
   * 本仓没有这个用户设置（面板里没有"沉浸歌词模式"这一项）⇒ 取**默认**行为。
   *
   * ⚠️ **改回 true 就是"上滑隐藏控制区"重新生效**（一行）；已在
   *   `RzdMusic待确认清单.md` 第 33 条里明确问你"要不要这个手势"。
   */
  private static readonly LYRIC_SWIPE_ALLOWS_MANUAL: boolean = false;

  /**
   * "滚动仍在进行"的判定窗（ms）—— 见 `lastScrollAtMs` 的注释。
   *
   * ★ 2026-10-16：这一条**不是动画时长、不是观感参数**，而是"两种驱动方式并存"时的仲裁：
   *   `onContentDidScroll`（逐帧进度）当家时，`syncLyricMorphToPage()` 的"落定"必须让位。
   *   ⚠️ 120ms ≈ 7 帧：手指抬起后 swiper 的惯性滚动一停，落定就能接管收尾。
   *   ⚠️ 它与 `Swiper` 自己的 `duration` 无关（那个只在程序化切页时起作用）。
   */
  private static readonly SCROLL_SETTLE_WINDOW_MS: number = 120;
  /**
   * 歌词页那一横行（对标无界 `metaRow`）的排版常量 —— 数值取自
   * `PlayerPage完整UI定稿.md` §6.2：标题 `15` / 粗体 / 白 / `opacity 0.86`，歌手 `12` / 常规。
   */
  private static readonly LYRIC_META_TITLE_FP: number = 15;
  private static readonly LYRIC_META_ARTIST_FP: number = 12;
  /**
   * **封面页那一端**的歌名/歌手字号（fp）—— 对标无界 `chrome().titleSize` / `chrome().artistSize`（FULL 档）。
   *
   * ★★ 2026-10-15（照搬无界；本轮从字节码提取，**同时纠正我上一轮的一处误读**）：
   *   无界那**一个** `Text` 的字号是**插值**出来的（`wujie.pa:194905-194939`，`lerp` 三参调用）：
   * ```
   *   fontSize( lerp( chrome().titleSize * sizeK(),   // 封面页端 = 20 × sizeK
   *                   15 * sizeK(),                   // 歌词页端 = 15 × sizeK
   *                   metaProgress() ) )              // 进度（= swiperProgress）
   * ```
   *   歌手同理：`lerp( chrome().artistSize * sizeK()(=14), 12 * sizeK(), metaProgress() )`。
   *   ⇒ **封面页 20 / 14，歌词页 15 / 12**；`sizeK()` 是"窗口宽度的函数"
   *     （手机上 ≈1，平板/PC 才有差 —— 见 `RzdMusic待确认清单.md` E5）。
   *
   * ⚠️ 我们原来**两页都固定 15 / 12** ⇒ **封面页歌名偏小 33%（15 vs 20）**、歌手偏小（12 vs 14）。
   * ⚠️ 上一轮（§56.27）我一度把它读成"字号要**乘** `metaProgress()`"，并据此判"不许改" ——
   *   **那个读法是错的**（把 `lerp` 当成了乘法，于是以为封面页会变成 0 号字）。
   *   真相是插值：字号**从不消失**，只是**由 20 收到 15**。本轮按真相改正。
   */
  private static readonly META_TITLE_FP_COVER: number = 20;
  private static readonly META_ARTIST_FP_COVER: number = 14;

  /**
   * 当前这一帧的**歌名字号**（fp）—— 两端之间按**歌词页进度**插值。
   *
   * ★ 用 `lyricMorphT`（本页"封面页 ⇄ 歌词页"的进度）当无界 `metaProgress()` 的等价物：
   *   静止在封面页 = 0 ⇒ `20fp`；静止在歌词页 = 1 ⇒ `15fp`；切页那 360ms 里连续过渡。
   * @returns 歌名字号（fp）
   */
  private metaTitleFp(): number {
    return PlaybackPage.lerpFp(PlaybackPage.META_TITLE_FP_COVER,
      PlaybackPage.LYRIC_META_TITLE_FP, this.lyricMorphT);
  }

  /**
   * 当前这一帧的**歌手字号**（fp）：`14`（封面页）→ `12`（歌词页）。理由同 {@link metaTitleFp}。
   * @returns 歌手字号（fp）
   */
  private metaArtistFp(): number {
    return PlaybackPage.lerpFp(PlaybackPage.META_ARTIST_FP_COVER,
      PlaybackPage.LYRIC_META_ARTIST_FP, this.lyricMorphT);
  }

  /**
   * 两端之间的线性插值（`t` 夹到 0..1）。给上面两个字号用。
   * @param from `t = 0` 那一端的值
   * @param to `t = 1` 那一端的值
   * @param t 进度（任意实数，内部夹取）
   * @returns 插值结果
   */
  private static lerpFp(from: number, to: number, t: number): number {
    const p: number = t < 0 ? 0 : (t > 1 ? 1 : t);
    return from + (to - from) * p;
  }
  /** 小封面右缘到歌名的间距（vp）。 */
  private static readonly LYRIC_META_GAP_VP: number = 12;
  /** 该行右侧留白（vp）—— 给收藏/更多两个图标让位。 */
  private static readonly LYRIC_META_SIDE_VP: number = 16;
  // ⚠️ 2026-10-15：`LYRIC_META_ICON_FP` **已删除** —— 收藏 / 更多那两个图标改用
  //   `this.expandState.chromeFavSize()`（**按档位表取值** 24 / 22 / 20），
  //   完整出处（`chrome().favSize`、`wujie.pa:195193 / 195316`、档位表 `93534`）写在那个方法上。
  //   删它的原因：原来这里写死 `22`（注释自陈"取与派音一致的一档"，**不是无界的值**），
  //   换成 getter 之后这个常量就**没有调用者了** —— 不留死代码（同族清理见 §56.15 / §56.20）。
  /** 图标的点击热区边长（vp，官方 `HIT = 44`）。 */
  private static readonly LYRIC_META_HIT_VP: number = 44;
  /**
   * 歌词页那一横行的**行高**（vp）—— 两行文字（标题 15 / 歌手 12 + 2 间距）+ 图标留白。
   * ⚠️ 它只用于"竖直居中补偿"（见 `LyricFloatLayer` 里 `.position()` 的注释），
   *    **不要**改成封面边长 —— 那会把封面页的歌名往下推半个大封面的高度。
   */
  private static readonly LYRIC_META_ROW_H_VP: number = 34;
  /** 网格背景源的盒式模糊半径 / 轮数（无界 `MeshCoverBg` 的 `BLUR_RADIUS` / `BLUR_PASSES`）。 */
  private static readonly MESH_BLUR_RADIUS: number = 9;
  private static readonly MESH_BLUR_PASSES: number = 3;
  /** 展开看门狗（ms）：超时还没回到完整态就强制回到完整态。 */
  private static readonly COLLAPSE_WATCHDOG_MS: number = 900;
  /** 展开看门狗定时器句柄。 */
  private collapseWatchdogTimer: number = -1;
  /** 正在播收起动画（防止连点返回播两遍）。 */
  private isClosing: boolean = false;
  /**
   * ★★ 2026-10-15（无界逆向 P0-3）：回弹收尾的**独立代次**。
   *
   * ⚠️ **不要用 `morphGen` 校验这一步**：`morphGen` 是"几何代次"，
   *   `morphBeginEntering` / `morphBeginLeaving` / `morphReset` 都会 `++`
   *   （`PlayerExpandState` L2330 / L2437 / L2456）⇒ 240ms 窗口里只要起了**任何**新会话，
   *   这次收尾就被**静默跳过**；而它是**唯一**把 `morphDrive` 清回 `NONE` 的地方
   *   （`morphSettleOpen()` L2421）⇒ `morphSessionDriving()`（L2487）恒真
   *   ⇒ 壳层克隆层（三个按钮 / 歌名）常驻在屏上。
   *   判据：`hdc shell hilog -x | Select-String 'RzdMorph'` —— 一轮"下拉→松手"里
   *   看 `morph open (settled)` 有没有出现。
   */
  private dismissSettleGen: number = 0;
  /**
   * ★★ 2026-10-15（无界逆向 P0-2）：整页关闭的**独立代次** + 卸载定时器句柄。
   *
   * 原来只靠 `isClosing` 挡重入，而它在 `morphCloseMs + 20`（≈370ms）就被清回 `false`，
   * 那一刻播放页**可能还没 unmount** ⇒ 第二次点击能再起一条 350ms 补间 + 第二个卸载定时器，
   * 而 `morphGenAlive` 校验拦不住（两条链的 `morphGen` 相同）。
   * 现在：句柄存下来可被取消 + 代次严格校验 ⇒ "第二次点击"要么被明确忽略、要么干净接管。
   */
  private closeGen: number = 0;
  private closeSettleTimer: number = -1;
  /**
   * 本次下拉跟手是否已经把形变相位切到 LEAVING（对标无界的 `drive = FINGER`）。
   *
   * 有了它，松手时才能分清"这次下拉真的跟手过"和"只是极短的一次拖拽"：
   * 后者不能去动形变相位，否则会把静止的 OPEN 态改成 LEAVING。
   */
  private dismissMorphActive: boolean = false;
  /**
   * 本次下拉收起**起手那一刻**的形变进度（`morphP`，0..1）—— 关闭提交用**相对量**判据的基准。
   *
   * ★★ 2026-10-15（照搬无界 `reverseQuitDelta`）：无界的关闭提交不是"缩到多少就关"，
   *   而是"**比起点往回走了多少**"：`delta >= max(baseT/2, COMMIT_T)`。
   *   起手时在 `morphBeginLeaving()` 之前记录本值；松手时算 `delta = baseT − 当前进度`。
   *   ⚠️ 初值取 **1**（满展开）—— 与"从静止的播放页开始下拉"这一常态一致；
   *      真正起手时会被立刻覆盖（见 `onDismissDrag` 里记录它的那一行）。
   */
  private dismissBaseT: number = 1;
  /**
   * 下拉收起手势的**起手位移门限**（vp）。
   *
   * ★ 对标无界 `PlayerPage` 顶部关闭手势的
   *   `PanGesture({ direction: PanDirection.Down, distance: 8 })`
   *   （`_recover\logic-src\开关播放器-手势路径定稿.md` §0 速查表 / §1.1 ⑤ / §1.3；
   *   字节码 `wujie.pa:181153-181157`）—— **就是无界的那个 8，不是我们估的**。
   *
   * ⚠️ 为什么用**框架级**门限、而不在 {@link onDismissDrag} 里手写 `if (offsetY < N) return;`：
   *   `PanGestureOptions.distance`（本机 `gesture.d.ts:2380` 确有该字段，**默认 5vp**）
   *   是"手指走满多少才**识别**这个手势"—— 没走满时 `onActionStart/Update/End`
   *   根本不会触发 ⇒ 静止态被 1~2vp 抖动推进 `LEAVING`（`派音动画Bug清单.md` P0-4）**在源头不成立**；
   *   而手写判据会多一次不连续（跟手进度在门限那一帧从 0 直接跳到 `N/span`）。
   *
   * ⚠️ **打开方向不动**：两条迷你条的 `panOption` 保持默认 5vp ——
   *   那正好等于无界上滑打开手势的 `{ direction: PanDirection.Vertical, distance: 5 }`
   *   （同文档 §1.1 ①），所以那里既不加也不改。
   */
  private static readonly DISMISS_PAN_DISTANCE_VP: number = 8;
  // ⚠️ 下拉收起的两个**判据常量**（提交阈值 38 / 兜底行程比例 0.42）**已收敛到**
  //    `PlayerExpandState.DISMISS_COMMIT_PROGRESS` / `PlayerExpandState.DISMISS_DRAG_SPAN_RATIO`
  //    —— 原先它们与打开方向的 `PULL_OPEN_COMMIT_FRACTION` 分居两个文件、无交叉校验
  //    （`派音动画Bug清单.md` P0-1）。理由与"不许照抄无界 0.32"的说明都在那里的注释里。
  /**
   * 下拉松手时的**速度**提交阈值（vp/s）。
   *
   * 出处：`docs\无界形变手感-落实到RzdMusic清单.md` §一 1.2「提交判定 —— 进度 OR 速度」：
   * `commit = (morphT >= COMMIT_T 即 0.32) || (velocity <= COMMIT_VELOCITY 即 900)`
   * ⇒ 无界的 `COMMIT_VELOCITY = 900`。**这个数是从文档取的，不是估的。**
   *
   * ⚠️ 但**绝不照抄它的比较方向/正负号**：无界是"上拉打开"，这里是"下拉收起"，方向相反，
   *   文档也明说"符号要先实测、别照抄"。见 {@link onDismissDrag}：
   *   **方向由位移判、大小由 `Math.abs(velocityY)` 取** ⇒ 根上不需要假设符号。
   */
  private static readonly DISMISS_COMMIT_VELOCITY: number = 900;
  /**
   * ★★ 2026-10-15（无界逆向 P0-4）：下拉收起的**最小起手位移**（vp）。
   *
   * 没有它的时候，跟手分支只要 `offsetY > 0`（**1vp 都算**）就会 `morphBeginLeaving()`
   * ⇒ 相位被推进 `LEAVING` 且 `morphGen++`，而屏上几乎什么都没动；
   * 松手回落时又给相位做一次 220ms 补间 + 240ms 定时器
   * ⇒ 观感是"轻轻蹭一下就闪一下"，同时把 P0-3 那条残留状态的门打开。
   * 8vp ≈ 2.5mm，**远小于**误触尺度（≥10vp）与真实下拉起手（几十 vp）
   * ⇒ **只挡抖动、不挡跟手**（下一个 `onActionUpdate` 一旦越过它照常起手）。
   * ⚠️ 无界侧**没有**这个门限 —— 这是派音自己的加固，**故意不与它对齐**。
   */
  private static readonly DISMISS_MIN_START_VP: number = 8;

  /** @returns 窗口高度（vp）；拿不到时给一个兜底值，保证拖拽比例不会除零。 */
  private deviceHeightVp(): number {
    const px: number = this.windowInfo.windowSize.height;
    if (px <= 0) {
      return 780;
    }
    return this.getUIContext().px2vp(px);
  }

  /**
   * @returns 下拉到底所需的距离（vp）—— 跟手归一化的**分母**。
   *
   * ★ D2：**优先用实测**，拿不到才退回窗口比例。对齐无界
   *   `pullRangePx = coverRect.top > 0 ? coverRect.top : windowHeight * 0.32`
   *   （`docs\无界形变手感-落实到RzdMusic清单.md` §一 1.1）。
   *
   * **为什么实测值取 `expandState.miniY`**：跟手进度是「手指位移的纯函数」
   *   （`progress = offsetY / span`），分母的语义就是"手指走完整个收起动作要走多远"。
   *   收起的目标是迷你条封面那一小块，而它的顶边就在窗口坐标 `miniY` —— 形变容器在 `p = 0`
   *   时的可视矩形顶边正是 `miniCoverY`（= `miniY`，由 `morphInitParams()` 从同一份实测值算出），
   *   满屏态顶边是 0 ⇒ 走完全程 = 顶边从 0 挪到 `miniY` ⇒ 行程 `miniY`。
   *
   * ⚠️ **改分母不会累积偏移**（§六 第 3 条的判据）：`dismissProgressFromDrag()` 仍然是
   *   `clamp(offsetY / span * 100)` 这种"**当前**手指绝对位移"的纯函数，**不读上一帧**；
   *   而且 `miniY` 在一次拖动期间是常量 —— 迷你条在形变期间是 `Visibility.Hidden`
   *   （**保留布局**、面积不变），不会再触发 `onAreaChange` 上报 ⇒ 分母不会在拖动中途跳变。
   */
  private dismissSpanVp(): number {
    const measured: number = this.expandState.miniY;
    if (measured > 0) {
      return measured;
    }
    return this.deviceHeightVp() * PlayerExpandState.DISMISS_DRAG_SPAN_RATIO;
  }

  /**
   * 由拖拽距离换算收起进度。
   * @param offsetY 手势的竖直位移（vp，向下为正）。
   * @returns 进度 0..100。
   */
  private dismissProgressFromDrag(offsetY: number): number {
    const y: number = offsetY > 0 ? offsetY : 0;
    const span: number = this.dismissSpanVp();
    if (span <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(100, (y / span) * 100));
  }

  /**
   * 下拉收起手势：拖动期间**跟手**改进度（不走 animateTo，所以是即时的），
   * 松手时 **进度过阈值 OR 速度足够快** 就收起，否则补间弹回完整态。
   *
   * 这套交互和参考工程 MusicHome 的 `PanGesture` 一致（它的 `dismissPanOffsetY`
   * → `dismissSheetHeightPercent` + `coverLinearScale` 是同一件事）。
   *
   * ★ D1：速度项见下面 {@link PlaybackPage.DISMISS_COMMIT_VELOCITY}。
   * @param offsetY 当前竖直位移（vp，向下为正）。
   * @param ended 是否是松手。
   * @param velocityY 松手时的竖直速度（来自 `GestureEvent.velocityY`）。
   *   ⚠️ **本函数不依赖它的符号**（见下），所以默认值 0 也不会造出"误提交"。
   */
  private onDismissDrag(offsetY: number, ended: boolean, velocityY: number = 0): void {
    if (this.isClosing) {
      // ★★ 2026-10-15：这一行以前是**静默** return，于是"下拉收起完全不跟手"这件事
      //   在日志里一点痕迹都没有（手指动了、屏上没动、日志也没写），只能靠猜。
      //   现在把它打出来：`hdc shell hilog -x | Select-String 'RzdMorph dismiss blocked'`
      //   —— 出现它 = `isClosing` 卡住了（见 `closeFullScreenPlayback()` 的补漏注释）；
      //   **完全不出现** = 手势根本没到这（那是手势路由问题，去查 `RzdMorph dismiss pan start`）。
      Logger.warn(PlayerExpandState.LOG_TAG,
        `RzdMorph dismiss blocked: isClosing=true offsetY=${offsetY.toFixed(1)} ended=${ended}`);
      return;
    }
    const progress: number = this.dismissProgressFromDrag(offsetY);
    // ★★ D1（最高优先级）：提交判定 = **进度 OR 速度**（无界 §一 1.2）。
    //   只有进度时，"位移不到 38% 但甩得很快"收不起来 —— 用户手感上就是"快甩没反应"。
    //
    //   ⚠️ **不许猜 `velocityY` 的符号**（文档 §八 第 3 条 + §四 D1 的 ⚠️）：
    //     无界那边是"向下为正"，而我们这里是**下拉收起**、方向与它相反，
    //     照抄正负号必错；而 SDK 的 `GestureEvent.velocityY`（`gesture.d.ts`，@since 10）
    //     也没有承诺符号方向。所以这里从根上绕开：
    //       · **方向**只由**位移**判 —— `offsetY > 0` 即"这次拖动朝收起方向"；
    //       · **大小**只取 `Math.abs(velocityY)`。
    //     ⇒ 无论系统给的是 +900 还是 −900，判定结果都一样，**没有任何"符号实测"前置条件**。
    //   阈值 900 取自文档（见 `DISMISS_COMMIT_VELOCITY` 的注释），不是编的。
    const collapsingDirection: boolean = offsetY > 0;
    const speed: number = Math.abs(velocityY);
    const fastFlick: boolean = collapsingDirection && speed >= PlaybackPage.DISMISS_COMMIT_VELOCITY;
    // ★ 形变那套：下拉收起就是**反向跑同一套几何**（无界也是同一个 progress 正反两用）
    //   —— 整页缩回迷你条那一小块、裁剪窗口收回去、迷你条同时淡回来。
    if (this.expandState.morphUsable) {
      if (!ended) {
        if (!this.dismissMorphActive) {
          // ★★ P0-4：**最小起手位移门限**（依据见 `DISMISS_MIN_START_VP` 的注释）。
          //   低于它就当这次拖动不存在：不改相位、不 ++ 代次、不刷几何，直接返回。
          //   下一个 `onActionUpdate` 只要越过门限就会正常起手 ⇒ 跟手不会变迟钝。
          //   ⚠️ **`fastFlick` 必须能绕过门限**：一次"极快但位移很小"的下甩
          //      （8ms 内只走了几 vp）原本靠速度项就能收起，被门限挡掉就成了"快甩没反应"
          //      —— 那正是 D1 当初要修的毛病。所以这里是 `位移没过门限 **且** 不是快甩`。
          if (offsetY < PlaybackPage.DISMISS_MIN_START_VP && !fastFlick) {
            return;
          }
          this.refreshCollapseGeometry();
          this.dismissMorphActive = true;
          // ★★ 2026-10-15（照搬无界：关闭提交改成**相对量**判据）：起手这一刻先把当前进度记下来 ——
          //   松手时的判据是"**比起点往回走了多少**"（`delta`），不是"缩到了多少"。
          //   无界 `reverseQuitDelta()`：`quit = delta >= max(baseT/2, COMMIT_T)`
          //   （`_recover/logic-src/开关播放器-手势路径定稿.md` §八 L351-353 / L386，
          //   字节码 L151812-151838）。
          //   ⚠️ 必须在 `morphBeginLeaving()` **之前**取：下一步会改相位。
          this.dismissBaseT = this.expandState.morphP;
          PlaybackPage.ev('LV', `finger p=${this.dismissBaseT.toFixed(2)}`);
          this.expandState.morphBeginLeaving();
        }
        this.expandState.morphDrive = MorphDrive.FINGER;
        this.expandState.applyMorphProgress(1 - progress / 100);
        return;
      }
      if (!this.dismissMorphActive) {
        return;
      }
      this.dismissMorphActive = false;
      // ★★ 2026-10-15（照搬无界）：关闭提交改成**相对量**判据 `delta >= max(baseT/2, COMMIT_T)`
      //   （无界 `reverseQuitDelta()`；出处同上）。
      //   · `delta` = 起点进度 − 当前进度 = "这一拖往回走了多少"；
      //   · **满展开起手**（`baseT = 1`）⇒ 阈值 = `max(0.5, 0.32) = 0.5` ⇒ **要拉回去 50% 才关**
      //     （改前是"缩到 38% 就关"≈ `delta ≥ 0.38` ⇒ **更容易误关**）；
      //   · `baseT` 小于 0.64 时阈值退到 `COMMIT_T = 0.32`（无界那条 `max` 的另一半）。
      //   ⚠️ 速度项**不能丢**：无界也是 `进度 ∥ 速度`（§一 1.2），"快甩"必须照样能关。
      const currentT: number = 1 - progress / 100;
      const dismissDelta: number = this.dismissBaseT - currentT;
      const dismissThreshold: number = Math.max(this.dismissBaseT / 2,
        PlayerExpandState.PULL_OPEN_COMMIT_FRACTION);
      const shouldClose: boolean = dismissDelta >= dismissThreshold || fastFlick;
      // 上机排查用：`hdc shell hilog -x | Select-String 'RzdMorph dismiss commit'`
      // ⚠️ 这一行**故意同时打两个方向的阈值与两个分母**（参见
      //    `PlayerExpandState.pullSpanIsMeasured()` 的注释 / `派音动画Bug清单.md` §6.5）：
      //    只打"比值 vs 阈值"会继续藏住"两把尺子不是同一个长度"这件事。
      Logger.info(PlayerExpandState.LOG_TAG,
        `RzdMorph dismiss commit progress=${progress.toFixed(2)} baseT=${this.dismissBaseT.toFixed(3)} ` +
        `delta=${dismissDelta.toFixed(3)}/${dismissThreshold.toFixed(3)} ` +
        `velocityY=${velocityY.toFixed(1)} ` +
        `absVelocity=${speed.toFixed(1)} dir=${collapsingDirection ? 'collapse' : 'open'} ` +
        `fastFlick=${fastFlick} velocityThreshold=${PlaybackPage.DISMISS_COMMIT_VELOCITY} ` +
        `span=${this.dismissSpanVp().toFixed(1)} spanSrc=${
          this.expandState.miniY > 0 ? 'measured' : 'ratio'} ` +
        `openThreshold=${PlayerExpandState.PULL_OPEN_COMMIT_FRACTION} openSpan=${
          this.expandState.pullSpanVp().toFixed(1)} openSpanSrc=${
          this.expandState.pullSpanIsMeasured() ? 'measured' : 'ratio'} commit=${shouldClose}`);
      if (shouldClose) {
        // 交给 closeFullScreenPlayback：它会接着把形变补间到 0 再卸载
        this.closeFullScreenPlayback();
        return;
      }
      // 没过阈值：弹回完整态，并把相位收回 OPEN
      this.expandState.morphDrive = MorphDrive.ANIM;
      // ★★ P0-3：相位归位改用**独立代次**（依据见字段 `dismissSettleGen` 的注释），
      //   不再复用 `morphGen` —— 它会被任何新会话 ++，导致这次收尾被静默跳过，
      //   而 `morphDrive` 就永远停在 `ANIM`。
      const settleGen: number = this.dismissSettleGen + 1;
      this.dismissSettleGen = settleGen;
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, (): void => {
        this.expandState.applyMorphProgress(1);
      });
      setTimeout((): void => {
        if (!this.isAlive || this.isClosing) {
          return;
        }
        if (settleGen !== this.dismissSettleGen) {
          // 本轮回弹已被下一次回弹取代
          return;
        }
        // ★ 相位已被别的会话接管就必须放手：新一轮拖动会把 `drive` 置 `FINGER`，
        //   `morphBeginEntering` 会把 `stage` 置 `ENTERING`、`closeFullScreenPlayback`
        //   会把 `isClosing` 置真 —— 三种接管都能被上面几条挡住。
        //   只有"本轮仍是相位主人"时才归位。
        if (this.expandState.morphStage !== MorphStage.LEAVING
          || this.expandState.morphDrive !== MorphDrive.ANIM) {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss bounce: phase taken over stage=${this.expandState.morphStage} ` +
            `drive=${this.expandState.morphDrive}, skip settle`);
          return;
        }
        // ★ `morphSettleOpen()` 内部会把 `morphDrive` 归 `NONE`
        //   （`PlayerExpandState` L2421，**全仓唯一**的清零点）——
        //   这一步就是"壳层克隆层常驻"那条 bug 的解药，**不要绕过它**。
        this.expandState.morphSettleOpen();
      }, 240);
      return;
    }
    // 无有效锚点不运行旧压扁布局，松手满足阈值才直接关闭。
    if (!ended) {
      return;
    }
    const shouldCloseFallback: boolean = progress >= PlayerExpandState.DISMISS_COMMIT_PROGRESS || fastFlick;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdMorph dismiss commit(noMorph) progress=${progress.toFixed(2)} velocityY=${velocityY.toFixed(1)} ` +
      `absVelocity=${speed.toFixed(1)} dir=${collapsingDirection ? 'collapse' : 'open'} ` +
      `fastFlick=${fastFlick} commit=${shouldCloseFallback}`);
    if (shouldCloseFallback) {
      this.closeFullScreenPlayback();
      return;
    }
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, (): void => {
      this.collapseProgress = 0;
    });
  }

  // ─────────────────────── 封面 + 歌名续飞到歌词页顶部（A2）───────────────────────

  /**
   * ══════════════ 封面 / 歌名浮层的**跨页定位**（对标无界 `floatingCover` / `floatingMeta`）══════════════
   *
   * 切到歌词页时让**同一张封面 + 歌名**缩小并移到歌词页顶部，切回封面页时原路飞回 ——
   * **由 Swiper 的滚动进度逐帧驱动**（不是补间驱动）。
   *
   * ## 为什么是这样（而不是"两页各画一份"）
   *
   * 无界的 `playerPane` 是 `Stack { Swiper{ 封面页 ; 空歌词页 } ; floatingCover ; floatingMeta }`
   * —— 封面与歌名**挂在 Swiper 之外**，切页时是**同一个元素**在动；歌词页那一页本身是个空壳，
   * 只有 `padding({ top: lyricPadTop() })` 让位。
   *
   * ## 三个不变量
   *
   * 1. **全场只有一张封面**：封面页那份真封面已经并进浮层（`page 0` 只剩
   *    `MiniLyricLinesComponent` 空壳），"两份封面同时可见"从结构上就不可能，
   *    所以**没有"两者互补"这回事**（旧门 `lyricFloatActive()` 已删）；
   * 2. **静止态两页各自逐像素不变**：`t = 0` 那一端就是真封面的落点矩形
   *    （`PlayerExpandState.lyricMorph(0)` 复用续飞封面 `p=1` 的同一段端点几何），
   *    所以交棒那一帧没有可跳的差；
   * 3. **浮层不可用就整套不启用**（`lyricFloat()` 为假：封面没量到 / 宽屏面板走另一套布局）
   *    —— 什么都不画、`lyricPadTop()` 也是 0，与没有这套东西时一致。
   *
   * ⚠️ **歌词怎么画一个字没动**（`LyricsComponent` / `AmllLyricView` 不碰），
   *   这里只动"封面/歌名浮层的跨页定位"与歌词页的顶部留白。
   *
   * ## ★★★ 2026-10-16（**驱动方式已照搬无界：进度式，不是补间式**）
   *
   * 这里原来有一个 `animateLyricMorph(toLyric)`：用 `animateTo(360ms, EaseInOut)` 把
   * `lyricMorphT` 从 0 补到 1（或反向），并由 `.onAnimationStart` 调用。
   * **现在它已删除**，理由（每一条都指向无界的原文）：
   *
   * ```
   *   ① 无界**没有这条补间**：它的封面位置直接是 `morph.scaleAt/txAt/tyAt(swiperProgress)`
   *      —— `swiperProgress` 就是 Swiper 的滚动进度（见 §116.2 的逐条字节码）。
   *   ② `.onAnimationStart` 那条路带守卫「index === targetIndex ⇒ 跳过」
   *      ⇒ 只要切页不是"一次真滑动"（程序化切页 / 重挂载初始页不是 0 / 页与状态不一致），
   *        整套飞行**永远不启动** ⇒ `lyricMorphT` 恒 0 ⇒ 封面恒为大封面。
   *        **用户 2026-10-16 的截图正是这个形状**（大封面叠着歌词）。
   *   ③ 删掉之后 `t` 由 `onSwiperContentDidScroll()` **逐帧**写（官方 SDK：
   *      "invoked ... on a frame-by-frame basis"），**不依赖任何"发生过一次滑动"**。
   * ```
   *
   * ⚠️ 与它一起不再被使用的还有：`lyricSwiperSettled` / `lyricFlightSettled`（那对"两问握手"）
   *    与 `LYRIC_MORPH_DURATION_MS`。它们**保留为字段/常量**（徽标仍打印前两个），
   *    但**没有渲染用途** —— 若确认不需要，可以整组删掉。
   * ⚠️ `lyricMorphVisible` / `lyricMorphOpacity` 现在**只被徽标读**，不再门住任何绘制
   *    （我把全部消费点清点过：除了赋值点，只有 `refreshDiagText` 在读）。
   *    ⇒ 所以"标志没被复位"不会造成任何观感问题（这一点是**清点出来的**，不是推断）。
   */

  /**
   * `Swiper.onContentDidScroll` 的处理器 —— **无界的进度源**（逐条照抄）。
   *
   * ★★★ 2026-10-16（**修用户实测「歌词页封面没变小、叠在歌词上面」的根**）
   *
   * ## 为什么必须有它（原来的驱动源是错的）
   * 原来 `lyricMorphT` **只**由 `.onAnimationStart` 驱动，而那个回调带一个守卫
   * 「`index === targetIndex` ⇒ 跳过」。两种情况下这个守卫会让整套飞行**永远不启动**：
   *   · 页面切换不是"一次真滑动"（例如 swiper 被程序化切页、或重挂载时初始页就不是 0）；
   *   · 重挂载后"页"与"状态"不一致（`onAppear` 复位过索引）。
   * ⇒ `lyricMorphT` 恒 0 ⇒ 封面恒为大封面，而歌词正文照样显示 ⇒
   *   **屏上就是"大封面叠着歌词"**（用户 2026-10-16 截图）。
   *
   * ## 无界的做法（`wujie.pa` L190026-190075，定稿 §5.2 逐条转写）
   * ```ts
   *   let p = position;
   *   if (index === 0) {              // ★ 只在"当前页是播放页"这一侧归一化
   *     if (p < 0) { p = -p; }        //    往前滑时 position 为负 ⇒ 翻正
   *     if (p > 1) { p = 1; }         //    上夹到 1
   *     this.swiperProgress = p;
   *   }
   *   publishCoverStyle(); syncMotion();
   *   if (this.swiperProgress > 0.5 && !this.chromeHidden) { this.showChrome(); }
   * ```
   *   ⚠️ **后半段（歌词页那一侧）保持上一次的值** ⇒ **停在歌词页时 `p` 恒为 1**。
   *   ⚠️ 无界那边 `onChange` **不写** `swiperProgress`（它只做 idle/chrome 与
   *      `atLyricScreen = (v === 1)`）—— 所以本方法才是唯一写点。
   *
   * ## 我们的接法（同一份语义）
   * `lyricMorphT` 就是本仓的 `swiperProgress`（0 = 封面页端 / 1 = 歌词页端）：
   *   · 先把索引记账（`onChange` 在"程序化切页"时可能不触发，这里逐帧都有值）；
   *   · 再把归一化后的 `p` 喂给 `lyricMorphT`（**逐帧**，与无界同）；
   *   · 然后调 `syncLyricMorphToPage()` 做"静止端点必须等于当前页"的兜底
   *     （跨过 0.5 时它会补一次，保证不会停在两端之间）。
   *   ⚠️ 顺带把无界那句 `if (p > 0.5 && !chromeHidden) showChrome()` 也搬过来 ——
   *      它就是"滑到一半把控制区唤出来"的手感。
   * @param index 当前页（0 = 封面页，1 = 歌词页）
   * @param position 内容相对主轴起点的移动比例（官方 SDK 原文）
   */
  private onSwiperContentDidScroll(index: number, position: number): void {
    this.diagScrollCount = this.diagScrollCount + 1;
    this.diagScrollLast = `${index}/${position.toFixed(3)}`;
    // ── 逐条照抄无界的归一化 ──
    let p: number = position;
    if (index === 0) {
      if (p < 0) {
        p = -p;
      }
      if (p > 1) {
        p = 1;
      }
      this.lyricMorphT = p;
    }
    // 记账"滚动仍在进行"（见 `lastScrollAtMs` 的注释：落定必须让位给逐帧进度）
    this.lastScrollAtMs = Date.now();
    // 索引记账（`onContentDidScroll` 逐帧都给 `index`，比 `onChange` 更可靠）
    if (index !== this.playbackSwiperIndex) {
      this.playbackSwiperIndex = index;
    }
    // 静止端点兜底：跨过 0.5 之后把 `t` 落定到当前页对应的端点
    // （`syncLyricMorphToPage()` 内部幂等，且飞行中不会打断补间）
    this.syncLyricMorphToPage('scroll');
    // 无界同款：滑过半程就把控制区唤出来（`chromeHidden` 为假时才唤）
    if (this.lyricMorphT > 0.5 && !this.chromeCollapsed) {
      this.touchChrome();
    }
  }

  /**
   * 把'封面浮层飞行进度'**对齐到当前页** —— 不依赖"发生过一次滑动"。
   *
   * ★★★ 2026-10-16（**修用户实测「歌词页封面没变小叠在歌词上面」**）
   *
   * ## 用户的观察（决定性）
   * 截图里**歌名/歌手/歌词正文是压在封面上的** —— 那是**封面页那一端的浮层位置**
   * （歌名在封面下方 `META_GAP_BELOW_COVER(50)`、封面是整窗那一份 331）。
   * 而歌词正文**已经显示出来了**（那需要 swiper 在第 2 页）。
   * ⇒ 两件事同时成立只有一种解释：**页切了，浮层没跟**（徽标 `edge=331 t=0.00` 正是它）。
   *
   * ## 为什么原来的写法会漏
   * `lyricMorphT` 的唯一驱动点是 `.onAnimationStart`，而它带一个守卫
   * 「**已经在目标页了就跳过**（`index === targetIndex`）」。于是只要出现
   * "当前页 = 歌词页、而 `lyricMorphT` 仍是 0"这种**不一致的初始态**，就再也没有任何东西会去修正它：
   *   · 进播放器时若索引已是 1（上一轮 `onAppear` 复位过 0、或索引来自别处）⇒ 守卫直接跳过；
   *   · 节点重建后 `onAppear` 把 `lyricMorphT` 归到"当前页对应的端点"——
   *     而**当前页**这个值本身若与 swiper 实际停的页不一致，归出来的就是错的端点。
   *
   * ## 正确的关系（单一真源）
   * ```
   *   playbackSwiperIndex（当前页）  ──决定──▶  lyricMorphT 的**静止端点**
   *                                        （0 = 封面页那一端，1 = 歌词页那一端）
   *   滑动过程中的补间只是"从一个端点走到另一个端点"，
   *   而**静止态**永远等于"当前页对应的端点"。
   * ```
   * ⇒ 本方法就是那条关系的实现：立即把 `t` 置到当前页对应的端点（不动画）。
   *   · 与滑动中的补间**不冲突**：补间只在 `lyricMorphVisible === true`（飞行中）时才有意义，
   *     而本方法只在"静止态下发现不一致"时被调用（见调用点）。
   *   · 幂等：已经在正确端点时写同一个值，不触发任何重绘差异。
   *
   * ⚠️ 调用点：`aboutToAppear()`（页面挂载时对齐一次）与内容层 `.onAppear()`
   *    （节点出现时对齐一次）。**不要**放进滑动回调里（那会打断补间）。
   * @param reason 只用于日志（`boot` / `appear`）
   */
  private syncLyricMorphToPage(reason: string): void {
    const want: number = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC ? 1 : 0;
    // ★★★ 2026-10-16（**让位给逐帧进度**，见 `lastScrollAtMs` 的注释）：
    //   `onContentDidScroll` 正在逐帧写 `lyricMorphT` 时，这里**不许落定** ——
    //   否则两者每帧互相抢值（滑到一半被一把设到端点 ⇒ 画面跳）。
    //   ⚠️ `boot` 那次**必须放行**（页面挂载时还没有任何滚动，`lastScrollAtMs` 为 0）。
    if (reason !== 'boot' && Date.now() - this.lastScrollAtMs < PlaybackPage.SCROLL_SETTLE_WINDOW_MS) {
      return;
    }
    if (this.lyricMorphVisible && Math.abs(this.lyricMorphT - want) < 0.999) {
      // 飞行中且还没到端点 ⇒ 别打断补间（这条只在极端时序下才可能命中）
      return;
    }
    if (Math.abs(this.lyricMorphT - want) < 0.0001) {
      return;
    }
    Logger.info('RzdLyricFloat',
      `sync to page reason=${reason} index=${this.playbackSwiperIndex} want=${want} ` +
      `from=${this.lyricMorphT.toFixed(3)}`);
    this.lyricMorphT = want;
    this.lyricMorphTarget = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC;
    this.lyricSwiperSettled = true;
    this.lyricFlightSettled = true;
    this.lyricMorphVisible = false;
    this.lyricMorphOpacity = 1;
  }

  /**
   * 收尾：Swiper 自己的切换动画与浮层飞行**都结束**之后才卸掉"飞行中"这一档。
   *
   * ⚠️ 这里**不是**把封面一刀切掉：浮层是**常驻**的，落位后仍由 `playbackSwiperIndex`
   * 分支决定它落在哪个端点（歌词页静止态仍然要显示那张小封面 + 歌名）。
   * 原来的写法是 `lyricMorphVisible = false` 无条件写死 ⇒ 整套歌词页封面形变是关着的。
   *
   * ## ★★ 2026-10-16（**已判定为死代码，保留不删**）
   *
   * 两个理由，都是清点出来的：
   * 1. 本函数要求 `lyricSwiperSettled && lyricFlightSettled` **两问都到位**；
   *    而置 `lyricFlightSettled = true` 的**唯一**地方原来在 `animateLyricMorph()` 的收尾
   *    `setTimeout` 里 —— 那个方法本轮已随"改进度驱动"一起删除（见文件上方那段说明）
   *    ⇒ `lyricFlightSettled` 永远是 `false`（除非 `syncLyricMorphToPage()` 落定时置真，
   *      但那条路上 `lyricMorphVisible` 已经被它自己置成 `false`）
   *    ⇒ 本函数**必然在第一个 `if` 处返回**。
   * 2. 本函数只写 `lyricMorphVisible` / `lyricMorphOpacity` 两个字段，
   *    而这两个字段**现在只被徽标读**（全部消费点已清点）⇒ 即使它跑到了也没有渲染影响。
   *
   * ⇒ 保留而不删的理由：它是"两问握手"那套设计的收尾端，**若将来恢复补间驱动**
   *    （例如发现进度驱动在某个机型上不可用）需要它一起恢复；
   *    删了就得从 git 历史里捞。**它不会有害**（必然早退、且只写徽标读的字段）。
   * ⚠️ 若确认进度驱动稳定，可以把它 + `lyricSwiperSettled` / `lyricFlightSettled` /
   *    `LYRIC_MORPH_DURATION_MS` **整组删掉**。
   */
  private finishLyricMorph(gen: number): void {
    if (gen !== this.lyricMorphGen || !this.lyricSwiperSettled || !this.lyricFlightSettled) {
      return;
    }
    this.lyricMorphVisible = false;
    this.lyricMorphOpacity = 1;
    Logger.info('RzdLyricFloat',
      `flight settled gen=${gen} toLyric=${this.lyricMorphTarget} ` +
      `t=${this.lyricMorphT.toFixed(3)} index=${this.playbackSwiperIndex}`);
  }

  /**
   * @returns 浮层里封面的一帧矩形（vp，窗口坐标）。
   *
   * ⚠️ 2026-10-15（第 2 块·覆盖层统一）**删掉了三个已死的私有方法**：
   *   · `lyricFloatActive()` —— 它原来是浮层的门（只在"飞行中/歌词页"才画）；
   *     覆盖层改成**常驻**之后没有任何调用点。
   *   · `lyricFloatMetaOpacity()` —— 原来让歌名在 `t=0` 完全透明（那一刻封面页那份歌名
   *     由 `MusicPlayInfoBlock` 画）；页 0 不再画封面/歌名之后它恒为 1。
   *   · `lyricFloatMetaWidth()` —— 歌名块原来水平居中、用它算块宽；
   *     现在是**一横行**（左内边距由 `lyricMetaLeftInset()` 给），不再需要它。
   *   相关注释里凡还写着"门在 `lyricFloatActive()`"的地方都已就地改正。
   */
  private lyricFloatRect(): LyricMorphRect {
    return this.expandState.lyricMorph(this.lyricMorphT);
  }

  /**
   * @returns 封面那一层**实际要写进 `.position()` 的矩形**（vp）。
   *
   * ★★★ 2026-10-16（**撤回我上一版的逆变换**，用户实测「封面是飞到屏幕外」）：
   *
   * 上一版我在这里调 `coverLocalRectFor()` 做"屏幕坐标 → 容器本地坐标"的逆变换，
   * 前提是 **`.scale()` 绕容器中心**。真机上结果是封面**飞出屏幕**。
   *
   * ⚠️ 这个前提在本仓**早就有过一次真机反证**（`morphCoverRectAt()` 的注释、
   *   `LyricFloatLayer` 顶部"⚠️ 2026-10-15 刻意不改"那一段）：
   *   > 「逆变换回页内坐标 —— 真机结果"**封面跑到左上角**"（说明 `.scale()` 的枢轴
   *   >   **不是我以为的容器中心**）⇒ 该方案作废，**别再试**。」
   *   ⇒ 我这次等于**原地重踩了一遍**，教训记进 `RzdMusic记忆.md` §86。
   *
   * ## 现在 = 纯几何、**不做任何坐标系换算**（就是用户确认过"现在正常了"的那一版）
   *
   * ```
   *   尺寸 / 位置 / 圆角一律取 lyricMorph(t)（= 无界 CoverMorph 的输出）
   *   直接写进 .position() / .width() / .borderRadius()
   * ```
   * 本层挂在形变容器**内部**，所以形变中它的**实际**屏幕位会被容器变换挪走
   * （`y' ≈ t·y`，见 `LyricFloatLayer` 顶部那段推导）—— 这条"落位时正确、形变中偏"
   * 的口径**用户在真机上验过、观感可接受**（封面跟着容器一起缩向迷你条）。
   * ⚠️ 它成立的前提是 `t = 1`（落位）时容器是恒等变换 —— 而那正是静止态，恒成立。
   */
  private coverLocalRect(): LyricMorphRect {
    return this.lyricFloatRect();
  }

  /** 上一次 `RzdCoverLocal` 的落位签名（节流用，只在真的变了才打）。 */
  private lastCoverLocalLog: string = '';
  /** `RzdCoverLocal` 的采样节流（ms，形变时每帧都会变，太密会刷屏）。 */
  private static readonly COVER_LOCAL_LOG_MS: number = 100;
  private lastCoverLocalAtMs: number = 0;

  /**
   * ★★★ 2026-10-16 新增诊断：**封面落位的正/反变换对账**。
   *
   * ## 它判什么
   *
   * ```
   *   hdc shell hilog -x | Select-String 'RzdCoverLocal'
   *   ⇒ RzdCoverLocal t=… s=… tx=… ty=… screen=(x,y,w,h,r) local=(x,y,w,h,r)
   * ```
   * · `s = 1 / tx = ty = 0`（静止态）⇒ 两个矩形必须**逐字相同**（反变换是恒等的）；
   * · 形变中 ⇒ `local` 必须**远大于** `screen`（因为要被 `s` 压回去），
   *   且 `local.x/y` 可能为负（封面在裁剪窗口之外的那一截，这是正常的）；
   * · **判据**：把 `s / tx / ty` 与 `screen` 代进容器变换
   *   `y_屏 = H/2 + (y_本 − H/2)s + d` 应还原出 `screen.y` —— 若还原不出来，
   *   说明容器的枢轴/尺寸假设与实现不符（那时要改的是 `coverHostH()`，不是封面）。
   */
  private logCoverLocal(): void {
    const now: number = Date.now();
    if (now - this.lastCoverLocalAtMs < PlaybackPage.COVER_LOCAL_LOG_MS) {
      return;
    }
    const screen: LyricMorphRect = this.lyricFloatRect();
    const local: LyricMorphRect = this.coverLocalRect();
    const sig: string = `${screen.x.toFixed(0)},${screen.y.toFixed(0)},${local.x.toFixed(0)},${local.y.toFixed(0)}`;
    if (sig === this.lastCoverLocalLog) {
      return;
    }
    this.lastCoverLocalAtMs = now;
    this.lastCoverLocalLog = sig;
    const s: number = this.expandState.morphScale;
    Logger.info('RzdLyricFloat',
      `RzdCoverLocal t=${this.lyricMorphT.toFixed(3)} s=${s.toFixed(4)} ` +
      `tx=${this.expandState.morphTx.toFixed(1)} ty=${this.expandState.morphTy.toFixed(1)} ` +
      `winH=${this.expandState.windowHeightVp.toFixed(0)} clipH=${this.expandState.morphClipHeight.toFixed(0)} ` +
      `screen=(${screen.x.toFixed(1)},${screen.y.toFixed(1)},${screen.size.toFixed(1)},${screen.radius.toFixed(1)}) ` +
      `local=(${local.x.toFixed(1)},${local.y.toFixed(1)},${local.size.toFixed(1)},${local.radius.toFixed(1)}) ` +
      `realCover=${this.expandState.realCoverVisible()} clone=${this.expandState.morphOverlayBridging()} ` +
      `squash=${this.expandState.morphSquashY.toFixed(3)}`);
  }

  // ⚠️ 2026-10-16：`SQUASH_MIN` / `squashWrapHVp()` / `squashWrapOffsetYVp()` **已删除**。
  //
  // 它们是我上一版为了让"背景也跟着弹"而加的一层补偿容器
  // （`.height(winH × k)` + `.offset({y: −winH(1−k)/2})` + `.scale({y: k})`）。
  // 本轮把无界的**层级**读通之后，那个补偿**整个不需要了**：
  // 无界的 `MeshCoverBg` 就在**被 `scale/translate/clip` 的那个 Stack 里面**
  // （`wujie.pa` 191388 那个 `PLAYER_ROOT_ID` 容器，见 `build()` 里那段容器树），
  // ⇒ 它天然跟着容器一起缩、一起被裁、也天然在路由壳那条 `morphSquashY` 的作用域里。
  // ⇒ 背景已按无界搬回容器内部，这一层补偿连同它的常量一起删掉。

  // ─────────────────────── 控制区自动收起 ───────────────────────

  // ═══════════════ ★★★ 现场自证徽标（**不依赖 hdc**）═══════════════
  //
  // ## 为什么加它
  //
  // 「点击打开 / 点击关闭 / 系统返回没有封面动画」这条问题，本轮已经改了 3 处
  // （§92 背景不透明度 / §93 挂载判据 / §94 终点锚点量测门），但**用户不能用 hdc**，
  // 我拿不到 `RzdCoverLocal` / `RzdMorphOwnership` 那些日志 ⇒ 只能靠"改了再让用户装"，
  // 而这条链上有 5~6 个判断，**盲改的代价已经被证明极大**（§86~§94 共 8 轮）。
  //
  // ⇒ 加一个**页面上直接显示判据**的小徽标：用户点开播放器后把屏上那两行数字念出来，
  //   我就能一次定位到具体哪一个判断为假。**装一次顶十次盲改。**
  //
  // ## 用法（用户侧）
  // ```
  //   · 连点播放页顶部 3 次（点"返回"往右一点那片空白，或点歌名/歌手那一行）
  //   · 屏上出现一小块黑底白字，形如：
  //       V 8f3a2c1 sess=1 usable=1 cont=1 clip=1 scale=0.082 p=0.000
  //       real=0 clone=1 snap=330/56 end=328/328 op=0.040 stage=1 drv=2
  //   · 把这两行念给我（或截图）即可；再点 3 次可关掉
  // ```
  // ⚠️ **它只在连点 3 次之后才出现** ⇒ 正常情况下用户完全看不到，不影响观感。
  // ⚠️ 纯只读：不写任何与动画有关的状态（只写 `diagBadgeOn` / `diagText` 两个本页字段）。
  //
  // ★★★ 2026-10-17（**开关改成跨实例记忆** —— 直接为了"少让用户白跑一轮"）：
  //   徽标第十三行读的是**静态**事件日志（上一次关闭的全过程），而读完它的姿势是
  //   「关闭 → **重新打开播放页** → 打开徽标 → 截图」。可 `diagBadgeOn` 原来是**实例局部**的
  //   ⇒ 每次重新打开都回到"关"，用户得**再连点 3 次**才看得到 —— 多一步就多一次读不到的风险。
  //   ⇒ 加一个静态镜像：**开一次就一直是开的**（直到再连点 3 次关掉，或进程重启）。
  private static diagBadgeOnStatic: boolean = false;
  @Local private diagBadgeOn: boolean = PlaybackPage.diagBadgeOnStatic;
  @Local private diagText: string = '';
  private diagTapCount: number = 0;
  private diagTapLastMs: number = 0;
  /**
   * ★ 自证计数（只给徽标用，不影响任何逻辑）：
   * · `diagRemeasureTries` —— `onAppear` 里那次几何补量被调用了几次；
   * · `diagOverlayKicks`   —— 其中"补量成功后顺手起了浮层补间"几次。
   * ```
   *   两者都 0 ⇒ 那段代码根本没跑到（`onAppear` 走了别的分支）
   *   1 / 1    ⇒ 补量与起棒都发生了 ⇒ 若封面仍不飞，问题在几何值（看 snap / end）
   *   1 / 0    ⇒ 补量跑了但 `morphUsable` 仍为假 ⇒ 看 usable / end 两列
   * ```
   */
  private diagRemeasureTries: number = 0;
  private diagOverlayKicks: number = 0;

  /**
   * ★★★ 2026-10-16（**Swiper 回调实参记录** —— 修"歌词页封面没变小"的**决定性**读数）
   *
   * 为什么必须记它：上一批我在这条链上用**静态推理**在两种假设之间摇摆 ——
   * ```
   *   假设 A：`.onAnimationStart` **根本没触发**（切页没走滑动回调）
   *   假设 B：触发了但**被守卫挡掉**（`index === targetIndex`）
   * ```
   * 两者的修法**完全不同**（A 要在挂载/切页时补一次对齐；B 要改守卫的判据），
   * 而只有真机读数能分辨。⇒ 记下来，一次定位。
   *
   * 读法（徽标**第八行**）：
   * ```
   *   ast=<index>-<target>   例 `ast=0-1` = 从第 0 页滑向第 1 页（正常切到歌词页）
   *                          `ast=-1--1` = **这个回调一次都没进来过**（假设 A 成立）
   *   skp=<守卫挡掉的次数>   > 0 而 ast 有值 ⇒ 假设 B 成立（回调进了但被 `index===target` 挡）
   *   aend=<index>/<次数>    `onAnimationEnd` 最后一次的实参与次数
   *   chg=<index>/<次数>     `onChange` 最后一次的实参与次数（swiper 自己认为停在哪一页）
   * ```
   */
  private diagAnimStart: string = '-1--1';
  private diagAnimSkip: number = 0;
  private diagAnimEnd: string = '-';
  private diagAnimEndCount: number = 0;
  private diagChg: string = '-';
  private diagChgCount: number = 0;
  /**
   * ★★★ 2026-10-16：`onContentDidScroll` 的**调用计数与最后一次实参** —— 这是本轮真正的判据。
   *
   * 读法（徽标**第八行**的 `scr=`）：
   * ```
   *   scr=<次数> last=<index>/<position>
   *     scr=0        ⇒ 这个回调**一次都没触发**（那 SDK 侧就没有进度源可用，要换方案）
   *     last=0/0.37  ⇒ 正在从封面页滑向歌词页（`position` 是移动比例）
   *     last=0/1.000 ⇒ ★ **停在歌词页**（无界的归一化把它夹到 1，且此后不再更新）
   * ```
   * 无界的等价物就是 `swiperProgress`；它是 goal 第 1 条指定的**进度源**。
   */
  private diagScrollCount: number = 0;
  private diagScrollLast: string = '-';
  /**
   * ★★★ 2026-10-16：内容层 `.onAppear()` **走了哪条分支** —— 定位"关闭后突然又放展开"。
   *
   * 取值：
   * ```
   *   '-'        = 这个回调还没进过
   *   'morph'    = 走了形变分支（morphContainerActive || morphSessionStarted）✅ 正常
   *   'intro'    = 走了兜底分支并起了 playExpandIntro()  ← ★ 若出现在关闭过程中，就是本 bug
   *   'skipClose'= 走了兜底分支但被"正在关闭"那道门拦下 ✅（本轮新增的门）
   * ```
   * 判读：关闭后若看到 `intro` ⇒ 门没拦住（要再查判据）；看到 `skipClose` ⇒ 门生效了。
   */
  private diagAppearBranch: string = '-';
  /**
   * ★★★ 2026-10-16：**背景层自己的实测矩形**（窗口坐标，vp）—— 定位"有背景但高度特低"。
   *
   * 为什么单独量它：背景层（`MeshCoverBg` 那个宿主 `Column`）是**形变容器的子节点**，
   * 而且是 `.height('100%')` + `.position({x:0,y:0})` ⇒ 它的高度**完全由容器决定**。
   * 用户报「有背景但是**高度特低**」时，三种可能必须分辨：
   * ```
   *   ① 容器的裁剪窗口本来就是那么小（`clipH` 读数）⇒ 正常，是动画中段
   *   ② 背景层的盒子被压成了极小（本读数 `bgH`）  ⇒ 布局问题（百分比链断了）
   *   ③ 背景层盒子正常但被**淡掉**了（`bg` 不透明度）⇒ 是 `backgroundRevealOpacity()` 的事
   * ```
   * 由 `MeshCoverBg` 所在宿主 `Column` 的 `.onAreaChange()` 写（只读，无副作用）。
   * ⚠️ `onAreaChange` 给的是**布局几何**（不含祖先 transform）⇒ 配合徽标第一行的
   *    `scale` 才能还原"屏上多高"（= `bgH × scale`）。
   */
  @Local private diagBgBox: string = '-';
  /**
   * 上一次 `onContentDidScroll` 的时间戳（ms）—— **用来让"落定"让位给"逐帧进度"**。
   *
   * ★★★ 2026-10-16（这是本轮必须处理的一处**真实冲突**）：
   * `onContentDidScroll` 逐帧写 `lyricMorphT = p`（照搬无界），
   * 而 `syncLyricMorphToPage()` 是"把 `t` 落定到当前页对应的端点"（一把设到位）。
   * 两者若同时生效就会**每帧互相抢值**（滑到一半被落定到 1 ⇒ 画面跳）。
   * ⇒ 判据：**最近 120ms 内有滚动回调 ⇒ 这一段由"进度"当家，不许落定**。
   *   （120ms ≈ 7 帧；手指抬起后 swiper 的惯性滚动一停，落定就能接管收尾。）
   *   ⚠️ 这个时间窗**只在"两种驱动方式并存"时才有意义**，它不是动画时长、也不是自编参数 ——
   *      它是"判定滚动是否仍在进行"的采样窗（与 `PULL_ANCHOR_RETRY_MS = 32` 同一性质）。
   */
  private lastScrollAtMs: number = 0;

  /**
   * 顶部那块"隐形热区"的点击计数：**连点 3 次**开关自证徽标。
   *
   * 用 800ms 的窗口判定"连点"；间隔超过就重新计数。
   */
  private onDiagHotspotTap(): void {
    const now: number = Date.now();
    if (now - this.diagTapLastMs > 800) {
      this.diagTapCount = 0;
    }
    this.diagTapLastMs = now;
    this.diagTapCount = this.diagTapCount + 1;
    if (this.diagTapCount >= 3) {
      this.diagTapCount = 0;
      this.diagBadgeOn = !this.diagBadgeOn;
      // ★ 2026-10-17：跨实例记忆（见 `diagBadgeOnStatic` 那段）。**必须成对写**：
      //   只读不写 = 开关永远回到 false（那正是"用户白跑一轮"的形状）。
      PlaybackPage.diagBadgeOnStatic = this.diagBadgeOn;
    }
  }

  /**
   * 把当前那一串判据拼成两行字符串（**只在徽标开着时调用**）。
   *
   * 每一项都对应本轮改过或怀疑过的一个判断，命名与代码字段一一对应：
   * ```
   *   sess   = morphSessionStarted        （§93：壳层已起会话）
   *   usable = morphUsable                （几何是否量齐）
   *   cont   = morphContainerActive()     （容器是否在形变域）
   *   clip   = morphClipping()            （裁剪是否生效）
   *   scale  = morphScale                 （1 = 恒等；0.08 = 已压到起点）
   *   p      = morphP                     （形变进度）
   *   real   = realCoverVisible()         （播放页真封面是否画）
   *   clone  = morphOverlayBridging()     （壳层续飞封面是否画）
   *   snap   = snapStartW / miniSize      （起点：续飞封面宽度 / 迷你条封面）
   *   end    = endCoverSize / endCoverH   （终点：播放页封面）
   *   op     = backgroundRevealOpacity()  （背景不透明度）
   *   stage / drv = morphStage / morphDrive
   * ```
   * ⚠️ 判读要点（写在这里，用户念数字时我自己对号）：
   * · `clone=1` 且 `real=0` ⇒ 封面该由壳层浮层画；若屏上没有 ⇒ 看 `snap/end` 是否非零；
   * · `clone=0` 且 `real=1` ⇒ 封面该由播放页画（那时它在容器里，会被缩放）；
   * · `clone=0` 且 `real=0` ⇒ **两边都不画**（就是"完全没有封面"的那个形状）；
   * · `op=0.04` 且 `p≈0` ⇒ 背景刚起步；`op=1` ⇒ 已满。
   */
  private refreshDiagText(): void {
    if (!this.diagBadgeOn) {
      return;
    }
    const e = this.expandState;
    // ★ 2026-10-16（版本标记 `b41d7e9` → `c52e0a7` → `d73f1b8`）：那一轮加的是
    //   goal 第 2 条的圆角自证位（第四行 `rad`/`radVis`/`edge`/`t`）与
    //   "卸载放权判据"的定稿（`morphSessionOughtToLive`）。
    //   **用户报"没动画"时先看第一行的 `sess` / `geom` 两位**：
    //     `sess=0` ⇒ 会话被清掉了（`aboutToDisappear` 那条路没被拦住）；
    //     `geom=0` ⇒ 终点几何始终没量到 ⇒ 容器恒等 ⇒ 正是"没有封面/背景动画"。
    // ★ 2026-10-17（版本标记 → **`af66eb1`**）：那一轮加的是**第十行尾部的 `pd=`**
    //   （跟手三个拒绝点的累计计数）。⇒ **用户报"不跟手"时先看 `pd`**：
    //     `pd=0/0/0` ⇒ 判据全程放行，问题在事件/手势/版式；任一非 0 ⇒ 是判据拒的。
    const line1: string = `V af66eb1 sess=${e.morphSessionStarted ? 1 : 0} ` +
      `usable=${e.morphUsable ? 1 : 0} geom=${e.morphGeomReadyNow() ? 1 : 0} ` +
      `cont=${e.morphContainerActive() ? 1 : 0} ` +
      `clip=${e.morphClipping() ? 1 : 0} scale=${e.morphScale.toFixed(3)} p=${e.morphP.toFixed(3)}`;
    const line2: string = `real=${e.realCoverVisible() ? 1 : 0} ` +
      `clone=${e.morphOverlayBridging() ? 1 : 0} ` +
      `snap=${e.snapStartWVp().toFixed(0)}/${e.miniSize.toFixed(0)} ` +
      `end=${e.endCoverSizeVp().toFixed(0)}/${e.endCoverHVp().toFixed(0)} ` +
      `op=${this.backgroundRevealOpacity().toFixed(3)} stage=${e.morphStage} drv=${e.morphDrive}`;
    // ★ 第三行：控制区预算（**不用 hdc 也能核无界那套数值**）——
    //   `usableH` 应按无界 `winH − padTop − max(avoidBottom, bottomGap)` 算；
    //   `padBot` 读到的值应与 `gap` 列（FULL 65）一致（除非实测避让区比它还大）。
    const line3: string = `usableH=${e.usableHVp().toFixed(1)} padBot=${e.padBottomVp().toFixed(1)} ` +
      `avoid=${e.navigationBarBottomVp.toFixed(1)} gap=${e.chromeBottomGapVp().toFixed(0)} ` +
      `gapScrub=${e.chromeGapScrubVp().toFixed(0)} tier=${e.chromeTier}`;
    // ★ 第四行：**本轮的两个动作计数**（判"代码有没有跑到"比判值更靠前，见字段注释）。
    //   ★★★ 2026-10-16（goal 第 2 条「页面圆角再核一遍」的**自证位** —— **已订正过一次**）
    //
    //   ⚠️ 我第一版把 `rad`/`radVis` 量成了 `morphRadius` —— **那是"容器自己"的圆角**，
    //      不是封面的圆角，两者是**两条独立的链**（别混）：
    //   ```
    //     容器圆角 morphRadius = initRadiusVisual × (1 − t) / scale
    //        · 起点 = 迷你条胶囊圆角的一半，终点 = **0**（铺满屏 ⇒ 容器不该有圆角）
    //        · 无界同款：applyPullProgress 的 radius 分支（51054-51086）
    //        ⇒ 所以 t=0 时它按设计就是 0 —— 我第一版拿它当"封面圆角"，读数自然全是 0。
    //
    //     封面圆角 coverLocalRect().radius = lyricMorph(t).radius
    //        · 无界 `radiusAt(t) = visualRadiusAt(t) / scaleAt(t)`
    //          其中 `visualRadiusAt(t) = lerp(radiusPlayer, radiusLyricVisual, t)`
    //          `radiusPlayer = 8`（wujie.pa:85761 ldai 0x8）
    //          `radiusLyricVisual = 12`（同族常量）
    //        · 本仓 `lyricMorph()` 里就是 `lerp(COVER_RADIUS_PLAYER_VP(8), COVER_RADIUS_LYRIC_VISUAL_VP(12), p)`
    //        ⇒ 两端**逐字一致**：t=0 ⇒ 8；t=1 ⇒ 12
    //   ```
    //   ⇒ 这一行现在量的是**封面那条链**（`cRad` / `cRadV`，c = cover），
    //     并保留容器那条（`rad`/`radVis`）以便对照 —— 两条都打出来，一眼能分辨。
    //   判读：`t=0` ⇒ **cRad = cRadV = 8.00**；`t=1` ⇒ **12.00**；
    //         形变中 `cRadV = cRad × morphScale` 应始终在 **8~12 之间**（不随 scale 抖动）。
    //   复核入口：连点播放页左上角 3 次。
    const coverRect: LyricMorphRect = this.coverLocalRect();
    const line4: string = `remeasure=${this.diagRemeasureTries} overlayKick=${this.diagOverlayKicks} ` +
      `seek=${e.chromeSeekSize().toFixed(0)} edge=${coverRect.size.toFixed(0)} t=${this.lyricMorphT.toFixed(2)} ` +
      `cRad=${coverRect.radius.toFixed(2)} cRadV=${(coverRect.radius * e.morphScale).toFixed(2)} ` +
      `rad=${e.morphRadius.toFixed(2)} radVis=${(e.morphRadius * e.morphScale).toFixed(2)}`;
    // ★★★ 2026-10-17（**goal 第 1 条「元信息行」的现场自证 —— 第三版，判读已定稿**）
    //   `metaTop` = 本行**真实渲染值** = `metaTopGeomY(t, rowH)`（就是上面那条 `.position().y`，
    //               **同一个函数、没有第二份表达式**）；
    //   `metaOld` = **上一版那条自定式子**的值（`lyricMetaMorphY(t) + t×(size−rowH)/2`，
    //               见 `metaTopInUseYAt()`，现在只用于对账，**不再参与渲染**）；
    //   `metaD`   = `metaOld − metaTop`。
    //   ## 判读（两端都是**已知常数**，所以这一行现在可证伪）
    // ```
    //   t = 0（封面页）：metaD ≈ **−40**
    //       —— 旧式子的 from 用 `LYRIC_META_GAP_VP(10)`（本仓估定值），
    //          新式子用 `COVER_FIT_META_GAP_VP(50)`（无界 `fitPlayerOverlay` 的硬编码 a8）
    //          ⇒ 旧式子比新式子高 40vp ⇒ metaOld − metaTop = −40
    //   t = 1（歌词页）：metaD ≈ **−3.64**
    //       —— 旧式子到"小封面顶边 + (size−rowH)/2"，新式子到"小封面顶边 + 28 − rowH/2"；
    //          两者差 = 28 − size/2 = 28 − 48.72/2 = 3.64 ⇒ 旧式子高 3.64vp
    //   ⇒ 中段是这两端的线性插值。
    //   ⚠️ 若 t=0 处 metaD 不是 ≈−40（例如 −0）⇒ 说明 `bigEndpointRect()` 与那条旧式子
    //      用的矩形来源不同（旧式子走 `lyricMetaFromYOf()`，两者都基于 `bigEndpointRect`，
    //      理论上同源）—— 那时才需要查。
    // ```
    const metaTop: number = e.metaTopGeomY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP);
    const metaOld: number = e.metaTopInUseYAt(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP);
    const line6: string = `metaTop=${metaTop.toFixed(1)} metaOld=${metaOld.toFixed(1)} ` +
      `metaD=${(metaOld - metaTop).toFixed(1)} (t=0 期望 −40 / t=1 期望 −3.6) ` +
      // ★ 2026-10-17（**这一条已经从"待读的判据"降级为"结构不变量哨兵"**）：
      //   `lBox` = 歌词页内容盒的**窗口顶边**（`reportLyricBoxTop` 喂）。
      //   结构上恒为 **0**（"盒"就是 Swiper 的盒，而 Swiper 所在的 `Column` 与
      //   `LyricFloatLayer()` 是同一个不带 padding 的 `Stack` 的孩子，且该 `Stack`
      //   的内容盒左上角 = 窗口原点 —— 完整证据链见 `PlayerExpandState.lyricBoxTopVp` 的 JSDoc）
      //   ⇒ `lyricPadTop()` 那条"窗口坐标 + 23"的式子**已经**等价于无界的盒内式子 ✓
      //     **不需要换算，也不必再读这个数了。**
      //   ⚠️ 它现在只有一个用途：**若将来有人给那两层加了 padding，这里会读到明显非 0** ——
      //     那时才需要把 `lyricPadTop` 换成 `(浮层底边 − lBox) + 23`（一行）。
      //   ⚠️ 动画中它可能瞬时非 0（那是容器变换过的 `globalPosition.y`，正常）⇒ 看**静止态**的读数。
      `lBox=${e.lyricBoxTopVp.toFixed(1)}`;
    // ★★★ 2026-10-16（**"歌词页封面没变小"的直接判据**，用户真机截图后加）：
    //   用户实测「这是歌词页，那个封面没变小」⇒ 读数 `t=0.00 edge=331`。
    //   封面尺寸 = `lyricMorph(lyricMorphT).size`，而 `lyricMorphT` 只有 0/1 两个稳定值：
    //     · `t=0` ⇒ 封面 = `endCoverSize`（整窗那一份 ≈ 331）—— 就是用户看到的大封面；
    //     · `t=1` ⇒ 封面 = `lyricCoverSizeOf()`（小封面 ≈ 48.72）—— 应有的样子。
    //   ⇒ 所以"没变小" ≡ **`lyricMorphT` 没到 1**。这一行直接给出它为什么没到：
    //     · `sw`  = `playbackSwiperIndex` —— **不是 1** ⇒ 根本没切到歌词页（或索引被复位）
    //     · `tgt` = `lyricMorphTarget`   —— 与 `sw` 不一致 ⇒ 补间方向反了 / 没收尾
    //     · `vis` = `lyricMorphVisible`  —— `0` ⇒ `lyricFloat()` 判为不可用，整套飞行没起
    //     · `sg` / `fs` = `lyricSwiperSettled` / `lyricFlightSettled` —— 两问握手没齐
    const line7: string = `sw=${this.playbackSwiperIndex} tgt=${this.lyricMorphTarget ? 1 : 0} ` +
      `vis=${this.lyricMorphVisible ? 1 : 0} op=${this.lyricMorphOpacity.toFixed(2)} ` +
      `sg=${this.lyricSwiperSettled ? 1 : 0} fs=${this.lyricFlightSettled ? 1 : 0} ` +
      `lcEdge=${e.lyricCoverSizeOf().toFixed(1)} lcY=${e.lyricCoverYOf().toFixed(1)} ` +
      `float=${e.lyricFloat() ? 1 : 0}`;
    // ★★★ 2026-10-16（**Swiper 回调实参** —— 见字段 `diagAnimStart` 的注释）：
    //   `ast=-1--1` = `onAnimationStart` **一次都没进来过**（⇒ 切页没走滑动回调）；
    //   `ast=0-1` + `skp>0` = 进来了但被守卫挡掉（⇒ 要改守卫判据）；
    //   `chg=1/…` 而 `sw=0` = swiper 认为在歌词页、状态却记着 0（⇒ 状态没同步）。
    const line8: string = `ast=${this.diagAnimStart} skp=${this.diagAnimSkip} ` +
      `aend=${this.diagAnimEnd}/${this.diagAnimEndCount} ` +
      `chg=${this.diagChg}/${this.diagChgCount}`;
    // ★★★ 2026-10-16（**进度源自证** —— goal 第 1 条指定的 `swiperProgress` 等价物）：
    //   `scr` = `onContentDidScroll` 的调用次数（**逐帧**触发，见官方 SDK 原文）；
    //   `last` = 最后一次实参 `index/position`。
    //   判据：停在歌词页时应当看到 **`last=0/1.000`**（无界把 `position` 夹到 1，
    //   之后 `index === 0` 才更新、所以它稳定停在 1）—— 那时 `lyricMorphT` 也应为 1、
    //   封面 `edge` 应变成小封面（≈48.7）。
    //   `scr=0` ⇒ 这个回调一次都没触发（要换进度源）。
    const line9: string = `scr=${this.diagScrollCount} last=${this.diagScrollLast}`;
    // ★★★ 2026-10-16（**关闭路径的现场读数** —— 用户 23:19/23:20 三条反馈的定位用）
    //
    // 用户反馈（原话概括）：
    // ```
    //   ① 有时"播放页首页下方几个按钮也会隐藏"
    //   ② "返回关闭播放器我发现不是没背景，你看那一条，是**有背景但是高度特低**"
    //   ③ "下拉关闭播放器封面是这个小圆形，然后动画结束了**突然来个展开播放器的动画**"
    // ```
    // 这三条都发生在**关闭过程中**，而上面 1~9 行大多是"静止态读数" ⇒ 必须补这一行。
    //
    // 各量的判读：
    // ```
    //   show  = 壳层 isShowPlay。③ 的头号嫌疑：若它在关闭途中变回 true，
    //           壳层 `@Monitor('appState.isShowPlay')` 会 `pushPlayerRoute()`
    //           ⇒ **重新推入一个新的播放页实例** ⇒ 就是"又放一遍展开"
    //   clos  = isClosing（关闭链路已起）
    //   coll  = 控制区已收起（① 的直接读数：1 = 那几个按钮是藏着的）
    //   p     = morphP（关闭时向 0 走）
    //   clipH = **写进容器 `.height()` 的裁剪窗口高**（② 的直接读数：
    //           背景是容器的子节点 ⇒ 容器被裁成多高，背景就只画多高）
    //           静止态应 = 0（此时 `.height()` 内部走 '100%'）；关闭中会连续变到 ≈ 迷你条高
    //   bg    = 背景层不透明度（② 看它有没有被淡掉）
    //   drv   = morphDrive（FINGER/ANIM/NONE）
    //   sq    = morphSquashY（落位挤压，≠1 时在弹）
    //   pd    = **跟手"被拒"计数**（★ 2026-10-17 新增，直接为用户的「上滑不能自由」）
    //           `<起手拒>/<更新拒>/<松手拒>`，**累计值、不清零**（重启 App 才归零）。
    //           用法：让徽标开着 → 做一次上拉 → 看这三个数**有没有变**。
    //           · 变了 ⇒ 「不跟手」是**判据**拒的，且一眼看出是哪一个：
    //              第 1 个涨 = 起手那一刻几何没量齐（直接铺满、无跟手动画）
    //                          ⇒ 查 `measureMiniDuringPull` / 迷你条是否已挂载；
    //              第 2 个涨 = 手指在动但 `pullDragging` 是假（本类最可疑的一条，
    //                          历史上这一类已经出过两次回归：§round-36 的 `staleClr`）
    //                          ⇒ 查"谁把 `pullDragging` 清成了假"；
    //              第 3 个涨 = 松手/取消被判据拒（收尾没走 ⇒ 页面卡在半路）。
    //           · 一个都没变 ⇒ 判据全程放行 ⇒ 问题在**(b)事件/手势识别/版式**，
    //             **不要再去动状态机**（修法完全不同）。
    //           ⚠️ 第 2 个是**按手势计次**的（一次手势最多 +1），见
    //              `Index.pullDropCountedThisGesture` 的说明。
    // ```
    const line10: string = `show=${this.state.isShowPlay ? 1 : 0} clos=${this.isClosing ? 1 : 0} ` +
      `coll=${this.chromeCollapsed ? 1 : 0} p=${e.morphP.toFixed(2)} ` +
      `clipH=${e.morphClipHeight.toFixed(0)} bg=${this.backgroundRevealOpacity().toFixed(2)} ` +
      `drv=${e.morphDrive} sq=${e.morphSquashY.toFixed(3)} ` +
      `pd=${e.pullDropBegin}/${e.pullDropUpdate}/${e.pullDropEnd}`;
    // ★★★ 2026-10-16（**内容层 onAppear 走了哪条分支** —— 定位"关闭后又放一遍展开"）：
    //   `ab` = morph（形变分支，正常）/ intro（起了 playExpandIntro ← 关闭时出现即 bug）
    //        / skipClose（兜底分支但被"正在关闭"的门拦下，本轮新增）
    //   `ap` = introPaintReady（整页绘制门）
    const line11: string = `ab=${this.diagAppearBranch} ap=${this.introPaintReady ? 1 : 0} ` +
      `stage=${e.morphStage} exit=${this.expandIntroRunning ? 1 : 0} bgBox=${this.diagBgBox} ` +
      `lcl=${PlaybackPage.lastCloseAtMs > 0 ? (Date.now() - PlaybackPage.lastCloseAtMs).toFixed(0) : 'never'}`;
    // ★★★ 2026-10-16（**控制区自证** —— 定位用户第 1 条「有时下方几个按钮也会隐藏」）
    //   必须能分辨这三种形状（修法完全不同）：
    //     ① 自动收起（设计行为：无界 `IDLE_MS = 5000`，只在 `isPlay` 时生效）
    //        ⇒ `cc=1` + `cpr=0` + `chH` 正常 ⇒ **不是 bug**
    //     ② 被裁掉（容器裁剪窗口把控制区切掉）⇒ `clipH` 很小而 `chH` 正常 ⇒ 是容器几何的事
    //     ③ 高度塌陷（`lyricChromeHeight` 量成 0 ⇒ `.height(0 * progress)` = 0）
    //        ⇒ `chH=0` ⇒ 是**量测**的事（`lyricChromeMeasurePending` / `wasConstrained` 那条链）
    //   `cpr` = lyricChromeProgress（1 = 全出、0 = 全收）；`chH` = lyricChromeHeight；
    //   `ofs` = chromeOffsetY（收起时下移 46vp）
    const line12: string = `cc=${this.chromeCollapsed ? 1 : 0} cpr=${this.lyricChromeProgress.toFixed(2)} ` +
      `chH=${this.lyricChromeHeight.toFixed(0)} ofs=${e.chromeOffsetY().toFixed(0)} ` +
      `pend=${this.lyricChromeMeasurePending ? 1 : 0} play=${this.state.isPlay ? 1 : 0}`;
    // ★★★ 第五行：**动作轨迹**（最近 6 个动作，按发生顺序 `>` 连接）。
    //   为什么最有用：这条链上"顺序"本身就是自变量的最大值 ——
    //   同一个函数先调还是后调，结果完全不同（§93 的 `onAppear` 误判、§103 的
    //   `onDisappear` 误杀都是顺序问题），而前四行只看得出"当前值"。
    //   判读示例（点击打开应当看到的形状）：
    //     `clickOpen>beginOk>settle0C>settle1C>measOk>tween`  ⇒ 一路走通
    //     `clickOpen>beginOk>settle0C>settle1C>…`（无 measOk）⇒ 补量一直没成功
    //     `clickOpen>skip`                                     ⇒ 被 `pullDragging`/相位挡了
    //     `…>tween>settleSkip`                                 ⇒ 补间起了但落位被跳过（§104 那类）
    const line5: string = `trace=${e.morphTrace.length > 0 ? e.morphTrace : '(empty)'}`;
    // ★★★ 2026-10-16（**第十三行：关闭过程"黑匣子"** —— 读法见 {@link PlaybackPage.evLog}）
    //   为什么需要它：用户报的两条（「关闭时背景只剩一条」「关闭后又放一遍展开」）
    //   **都发生在关闭过程中，而那一刻徽标已随播放页一起消失** ⇒ 事后读不到任何东西。
    //   ⇒ 事件记在**模块级静态环形缓冲**里，等下一次打开播放页再显示 ⇒ 就有了上一次关闭的完整时序。
    //
    //   ⚠️ 显示时把 `|` 换成换行：一行一个事件，一张截图就能读完
    //     （不换行的话近千字符会挤成一坨，11fp 下几乎不可读）。
    const evRaw: string = PlaybackPage.evLog;
    const line13: string = evRaw.length > 0
      ? `ev#${PlaybackPage.evCount}\n${evRaw.split('|').join('\n')}`
      : `ev#${PlaybackPage.evCount} (no events yet)`;
    const next: string =
      `${line1}\n${line2}\n${line3}\n${line4}\n${line5}\n${line6}\n${line7}\n${line8}\n${line9}\n${line10}\n${line11}\n${line12}\n${line13}`;
    if (next !== this.diagText) {
      this.diagText = next;
    }
  }

  /** 自证徽标本体（黑底白字、不吃事件、压在最上面）。 */
  @Builder
  private DiagBadge() {
    Text(this.diagText.length > 0 ? this.diagText : 'V af66eb1 (no data)')
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor('rgba(0, 0, 0, 0.78)')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(6)
      // ★ 2026-10-16：徽标现在有 **13 行**（…第十二行控制区自证 / 第十三行关闭过程事件日志，
      //   事件日志本身就是多行——一行一个事件）⇒ `maxLines` 必须够，否则最后一行会被截掉。
      .maxLines(32)
      .position({ x: 8, y: 120 })
      .zIndex(99)
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 顶部"隐形热区"：连点 3 次开关自证徽标。
   *
   * ⚠️ 放在**顶栏之下、内容之上**的一个窄条（高 48vp、不拦其它交互以外的东西）：
   *   它只吃掉自己这一条带子上的点击，不影响播放/切歌/歌词滚动。
   */
  /**
   * 顶部"隐形热区"：连点 3 次开关自证徽标。
   *
   * ⚠️ **2026-10-16 修一处我自己引入的交互回归**：第一版写的是
   *   `Row().width('100%').height(48).position({x:0, y:96})` ——
   *   而**声明式 `.onClick` 会消费命中区域**（`HitTestMode` 默认对自身范围 Block）
   *   ⇒ 它把 96…144 那**一整条横向带子**的点击全吃掉了。
   *   在歌词页上那一带是**歌词行**（点歌词跳转）⇒ 真实功能被挡。
   *
   * ⇒ 现在改成**左上角一小块**（120×40 @ y=88），只覆盖封面左上角那片不可能有交互的区域：
   *   · 封面页：那一带是封面图像本身（无点击语义）；
   *   · 歌词页：`lyricPadTop()` 保证歌词正文从浮层下方开始，不会落到这一小块里。
   *   · 顶栏在 `y < 88`，也碰不到。
   * ⚠️ 若哪天这块也需要调位置，**先确认不压在"有交互的带子"上**。
   */
  @Builder
  private DiagHotspot() {
    Row()
      .width(120)
      .height(40)
      .backgroundColor(Color.Transparent)
      .position({ x: 0, y: 88 })
      .zIndex(98)
      .onClick((): void => {
        this.onDiagHotspotTap();
        this.refreshDiagText();
      })
  }

  // ─────────────────────── 控制区自动收起 ───────────────────────

  /**
   * ★★★ 2026-10-16（照搬无界 `BarCollapse`）：拖动控制条收起/展开的**手势状态机**。
   * 逐条转写见 `common/musicbasic/.../model/BarCollapse.ets`（含字节码行号对照表）。
   * 只有 `onChromeBarTouch()` 会用它。
   */
  private barCollapse: BarCollapse = new BarCollapse();

  /**
   * ★★★ 2026-10-17（照搬无界 `PlayerPage.showChrome()`）：**只"亮出控制区"，不重置空闲计时**。
   *
   * 出处（`_recover/logic-src/PlayerPage.abc.txt:11942-11982`）：
   * ```
   *   showChrome() {
   *     if (chromeHidden) {
   *       getUIContext().animateTo({ duration: CHROME_ANIM_MS, curve: Curve.EaseInOut },
   *                                () => { chromeHidden = false; });   // λ@5*#
   *     }
   *   }
   * ```
   * ★ 关键：**它里面没有 `startIdle()`**（`hideChrome` 里也没有 `clearIdle()`）。
   *   也就是说"唤出控制区"与"起空闲计时"是无界里**两件独立的事**，
   *   要不要起计时由**调用点**决定（见 {@link PlaybackPage.onSwiperIndexChanged} 与
   *   `onLyricInteract` / `onLyricSwipe`）。我们原来把两者捆成一个 `touchChrome()`，
   *   于是在"切到封面页"那条路上会**顺手把空闲计时也起起来** —— 与无界相反（那里是 `clearIdle()`）。
   */
  private showChrome(): void {
    if (!this.chromeCollapsed) {
      return;
    }
    this.getUIContext().animateTo({
      duration: PlaybackPage.CHROME_ANIM_MS,
      curve: Curve.EaseInOut
    }, (): void => {
      this.chromeCollapsed = false;
      this.lyricChromeProgress = 1;
    });
    Logger.info('RzdLyricChrome', `show naturalHeight=${this.lyricChromeHeight}`);
  }

  /**
   * 记录一次控制区交互：**唤出 + 重置自动收起计时**。
   *
   * 无界里这两件事是分开的（`showChrome()` 与 `startIdle()`），只有
   * "用户在歌词页上点了/下滑了"这类**真交互**才同时做两件 —— 所以这里保留这个组合入口，
   * 由调用点自己选（切页那条路只调其中一个，见 `onSwiperIndexChanged`）。
   */
  private touchChrome(): void {
    this.chromeTouchedAtMs = Date.now();
    this.showChrome();
    this.scheduleChromeAutoHide();
  }

  // ─────────────────────── 裁剪容器形变（对标无界 ExpandAnimation）───────────────────────

  /**
   * @returns 整页不透明度：**恒为 1**（容器本身不淡）。
   *
   * ⚠️ 这里原来按 `p/0.12` 淡入整个容器，是**我自己的发明**，反编译里
   *    `applyPullProgress` 不碰任何透明度、`overlayColor` 也恒为 `#00000000`。
   *    对应的"起点不空"由背景层的 `pullBgIn`（0→0.30）与叠在最上面的续飞封面/克隆层负责。
   *    用户实测也确认过这一点："无界动画开始不是透明的"。
   */
  private morphOpacityValue(): number {
    // ★ 自证徽标：动画期间逐帧刷新读数（徽标关着时它立刻 return，零开销）。
    //   放在这里是因为本函数**每帧都被调用**，且写的是两个本页 `@Local` 字段，
    //   与动画状态完全无关（纯只读）。用户在动画**结束之后**读到的就是收尾那一刻的值。
    this.refreshDiagText();
    // ★ 绘制门（见 `introPaintReady`）：形变开始之前整页不画，避免那 1~2 帧闪出完整播放页。
    // ⚠️ 两条**必须放行**的情况（否则就是"播放界面打不开"）：
    //   1. 已经落位（相位 OPEN）—— 无论门是什么状态，静止态一律要画；
    //   2. 手指正在驱动（上拉/下拉跟手）—— 那条路不进 `tryStartMorphIntro` 的开门分支，
    //      门会一直关着（这正是上一版"打不开播放界面"的根因）。
    if (this.expandState.morphStage === MorphStage.OPEN || this.introPaintReady ||
      (this.expandState.morphUsable && this.expandState.morphSessionDriving())) {
      return 1;
    }
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER &&
      this.expandState.morphUsable) {
      return 1;
    }
    // ★★ 2026-10-16（点击打开的第二半）：
    //   这一段是"壳层已为这一轮起了形变会话（`morphSessionStarted`），但几何还没压到起点"
    //   ⇒ 返回 0（整页不画），挡住"挂载那 1~2 帧闪出完整播放页"。
    //   ⚠️ 副作用（已知、接受）：这几帧里**壳层的元信息克隆层（`MorphMetaBridge`）还在画**
    //     （它在窗口坐标上、不吃本页的 opacity）⇒ 屏上会有一行歌名/歌手先亮着。
    //     这是无界同构的形状（它的 `floatingMeta` 也在播放页之外），**不再另做补丁**。
    return 0;
  }

  /**
   * 形变期间"背景整层"的不透明度（静止态恒 1）。
   *
   * ★★★ 2026-10-16（**照抄无界 `pullBgOpacity`**，修用户实测「播放器展开还是背景全屏」）
   *
   * ## 无界的原式（字节码逐条读出来的）
   *
   * ```
   *   PULL_BG_FLOOR = 0.04          wujie.pa:179978-179979  (fldai 4.0e-2)
   *   PULL_BG_IN_END = 0.30         wujie.pa:179980-179981  (fldai 3.0e-1)
   *
   *   pullPaintable = pullGeomReady && !morphSquashing      wujie.pa:176560-176579
   *   pullBgIn      = clamp(effT / PULL_BG_IN_END)          wujie.pa:176295-176326
   *                   // effT = 形变中 ? morphT : 1  ⇒ 静止态恒 1
   *   pullBgOpacity = !pullPaintable ? 0
   *                                 : PULL_BG_FLOOR + pullBgIn × (1 − PULL_BG_FLOOR)
   *                                                          wujie.pa:176331-176372
   * ```
   *
   * ## ⚠️⚠️ 本轮**订正一处我读反了的极性**（别再照着旧注释改回去）
   *
   * 我前一版把 `pullBgOpacity` 读成"点击展开时 `pullPaintable()` 为假 ⇒ 背景不画"，
   * 并据此让本函数在非跟手形变时 `return 0`。**读反了**：
   *
   * * `jnez L` 的语义是"**条件为假**时跳"（已由 `playerSwiperGapOf` 那把尺子钉死）；
   * * `lda pullPaintable(); isfalse; jnez L2` ⇒ **`pullPaintable() === true` 时跳到 L2**，
   *   而 L2 才是"算 `PULL_BG_FLOOR + pullBgIn × 0.96`"那一支；
   * * 只有 `pullPaintable()` 为假才 `ldai 0x0; return`。
   *
   * 而 `pullPaintable = pullGeomReady && !morphSquashing`（`morphSquashing` 只在
   * 关闭落位那一记挤压期间为真）⇒ **上拉/点击展开全程为真** ⇒ **背景全程都画**。
   * ⇒ 用户实测「**无界动画过程有背景的（至少实机是这样）**」正是这条独立证据。
   *
   * ## 结论（本仓映射）
   *
   * | 场景 | 结果 |
   * | --- | --- |
   * | 静止态 | 1 |
   * | 形变中 | `PULL_BG_FLOOR + pullBgIn × (1 − PULL_BG_FLOOR)` = `0.04 → 1`（`pullIn ≥ 0.30` 后恒 1） |
   * | 落位挤压（`morphSquashing`） | 0（无界那一档也一样） |
   *
   * ⚠️ 旧注释里"**不要**照抄 `clamp(p/0.30)`"那条结论**已作废**：它担心的是"背景层在
   * **被裁剪的小窗口里**、30% 就满不透明 ⇒ 窗口里一整块黑"。而背景层现在是**在裁剪容器内部**
   * （§90 照搬无界的层级），那个形状不存在了。
   *
   * ⚠️ **2026-10-16 二次订正（用户实测「点击打开/点击关闭/系统返回还是没有」）**：
   *   下面那句 `if (this.expandState.morphSquashY !== 1) return 0;` **是错的** ——
   *   它本意是当"落位挤压"（无界 `morphSquashing`），但 `morphSquashY` 在**点击/返回**这条路上
   *   也会不等于 1（关闭落位那一记 110ms+320ms 的挤压），于是整条路的背景被压成 0
   *   ⇒ 用户看到的是"**只有上拉那条有背景**"。
   *   ⇒ 现在改成：**只要有形变，背景就按 `pullBgIn` 上淡入**，不再对 Drive 或挤压做特殊判断。
   *     背景已经被容器裁剪（§90），所以"形变早期整屏"这个顾虑本身也不存在了。
   *
   * ⚠️ 它同时管着：垫底层、取样色层、网格层、径向暗角 —— 改它等于改这四层。
   * 排查关键字：`hdc shell hilog -x | Select-String 'RzdBgOpacity'`
   * @returns 0..1（静止态 = 1）
   */
  private backgroundRevealOpacity(): number {
    if (!this.expandState.morphContainerActive()) {
      return 1;
    }
    return PlaybackPage.PULL_BG_FLOOR + this.pullBgIn() * (1 - PlaybackPage.PULL_BG_FLOOR);
  }

  /**
   * @returns 背景层的**反缩放** = `1 / morphScale`（抵消形变容器的等比缩放）。
   *
   * 出处/理由见页面里背景层那道 `.scale({...})` 的注释：
   * 背景在形变容器内部，会跟着容器被压到 `morphScale`（p=0 时 ≈ 0.082）⇒ 观感是"压扁再展开"。
   * 乘一个 `1/morphScale` 之后，背景在屏上**始终满尺寸**，由外层的 `.clip` + 增长中的窗口**从下往上揭开**
   * —— 这才是无界那条形状。
   *
   * ⚠️ 三道护栏：
   *   · 静止态 `morphScale = 1` ⇒ 返回 1 ⇒ **逐像素不变**（回归红线）；
   *   · `morphScale` 过小（< 0.02）时不做补偿（1/0.02 = 50 倍会把背景放大到离谱）；
   *   · 非数字/非正值一律返回 1，宁可压扁也不画出空白。
   */
  private bgInverseScale(): number {
    if (!this.expandState.morphContainerActive()) {
      return 1;
    }
    const s: number = this.expandState.morphScale;
    if (!Number.isFinite(s) || s <= 0.02 || s >= 1) {
      return 1;
    }
    return 1 / s;
  }

  /** 无界 `PULL_BG_FLOOR`（`wujie.pa:179978-179979`，`fldai 4.0e-2`）。 */
  private static readonly PULL_BG_FLOOR: number = 0.04;

  /** 无界 `PULL_BG_IN_END`（`wujie.pa:179980-179981`，`fldai 3.0e-1`）。 */
  private static readonly PULL_BG_IN_END: number = 0.30;

  /**
   * @returns 无界 `pullBgIn() = clamp(effT / PULL_BG_IN_END)`（`wujie.pa:176295-176326`）。
   *
   * `effT = 形变中 ? morphT : 1` ⇒ 静止态恒 1（即 `pullBgIn = 1`）。
   * ⚠️ 本仓的"形变进度"对应 `morphP`（展开 0→1 / 收起 1→0），与无界的 `morphT` 同口径。
   */
  private pullBgIn(): number {
    if (!this.expandState.morphContainerActive()) {
      return 1;
    }
    const raw: number = this.expandState.morphP / PlaybackPage.PULL_BG_IN_END;
    return raw < 0 ? 0 : (raw > 1 ? 1 : raw);
  }

  /**
   * 排定自动收起。
   *
   * 用 `setTimeout` 而不是 `setInterval`：只要每次交互重新排一次就够了，
   * 常驻定时器会在页面不可见时空转（播放页经常长时间挂着）。
   */
  private scheduleChromeAutoHide(): void {
    if (this.chromeTimerId >= 0) {
      clearTimeout(this.chromeTimerId);
      this.chromeTimerId = -1;
    }
    this.chromeTimerId = setTimeout((): void => {
      this.chromeTimerId = -1;
      if (!this.isAlive || this.chromeCollapsed || !this.canHideLyricChrome() || !this.state.isPlay) {
        return;
      }
      // ★★★ 2026-10-17（照搬无界 `hideChrome()` 的"面板开着就不收"，`abc.txt:4124-4225`）：
      //   那一条是 10 个面板 flag 的短路或链；本仓的分量见 `auxSheetOpen` 的注释
      //   （菜单一族 → `playMenuOpen`；队列/其他版本 → `auxSheetOpen`）。两个都要判。
      if (this.playMenuOpen || this.auxSheetOpen) {
        Logger.info('RzdLyricChrome',
          `hide skipped (panel open: menu=${this.playMenuOpen ? 1 : 0} aux=${this.auxSheetOpen ? 1 : 0})`);
        return;
      }
      // 正在收起/展开播放器时不打扰
      if (this.isCollapsing()) {
        return;
      }
      this.getUIContext().animateTo({
        duration: PlaybackPage.CHROME_ANIM_MS,
        curve: Curve.EaseInOut
      }, (): void => {
        this.chromeCollapsed = true;
        this.lyricChromeProgress = 0;
        Logger.info('RzdLyricChrome', `hide auto naturalHeight=${this.lyricChromeHeight}`);
      });
    }, PlaybackPage.CHROME_AUTO_HIDE_MS);
  }

  /**
   * @returns 控制区是否可以"收起来"（自动空闲收起 + 拖动收起共用这一把门）。
   *
   * ★★★ 2026-10-17（**订正上一轮的一个错结论 —— 它当时只看 `startIdle` 内部，漏了所有调用点**）。
   *
   * ## 无界的事实：空闲收起**只在歌词页发生**
   *
   * 上一轮我读到 `startIdle()`（`PlayerPage.abc.txt:12394-12435`）里那道门是
   * `entryAllowsAuto(this.lyricImmersive)`，而 `lyricImmersive` 是**用户偏好**
   * （`wujie.pa:169823-169825`：`this.lyricImmersive = pref.lyricImmersiveMode`）
   * ⇒ 于是写了「**无界的门与"当前在哪一页"无关 ⇒ 封面页也会空闲收起**」，
   * 并把本方法放宽到 `usesPhoneSwiperLayout()`。
   * **那个推论是错的** —— 页面的限制不在 `startIdle` 里，而在**它的每一个调用点**上：
   *
   * | 调用点 | 字节码 | 条件 |
   * | --- | --- | --- |
   * | swiper `onChange` | `abc.txt:23189-23215` | **`index === 1`（歌词页）⇒ `startIdle()`**；否则 ⇒ `clearIdle() + showChrome()`（**不起计时**） |
   * | 歌词区触摸抬起前 | `abc.txt:6914-6932`（`onLyricInteract`） | 仅在**歌词页**且 `!chromeHidden` 时 `startIdle()` |
   * | 歌词区下滑 | `abc.txt:6938-6985`（`onLyricSwipe`，`offsetY ≥ SWIPE_TOGGLE_VP 24`） | 仅在**歌词页**：`showChrome() + startIdle()` |
   * | 沉浸模式变更 | `abc.txt:7766-7800` | `entryAllowsAuto(mode) && !chromeHidden && swiperProgress > 0.5` |
   *
   * ⇒ **四个起点全在歌词页，而切到封面页那一支是显式的 `clearIdle()`**
   *   ⇒ **无界在封面页不会空闲收起控制区**。
   *   ★ 而且这正是用户早先报的那一条：「有时**播放页首页**下方几个按钮也会隐藏」——
   *     封面页隐藏是**我们**带进来的行为，不是无界的。
   *
   * ## 现在的判据
   * 手机 Swiper 布局（封面页/歌词页这套）**且**停在歌词页。
   * ⚠️ 这与上一轮之前的写法一致（`WIDTH_SM && 歌词页`），差别只是宽度判据换成了
   *   `usesPhoneSwiperLayout()`（与 `Swiper` 真实是否使用同一口径，更硬）。
   * ⚠️ 本门是"自动收起 + 拖动收起"共用的 —— 两者按无界也**都只在歌词页**起作用
   *   （`BarCollapse` 挂在歌词页那套控制区上）。
   */
  private canHideLyricChrome(): boolean {
    return this.usesPhoneSwiperLayout() &&
      this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC;
  }

  private hideLyricChrome(): void {
    if (!this.canHideLyricChrome() || this.chromeCollapsed) {
      return;
    }
    // ★ 同一条守卫（见 `scheduleChromeAutoHide` 里的说明）：面板开着就不收。
    if (this.playMenuOpen || this.auxSheetOpen) {
      return;
    }
    this.stopChromeAutoHide();
    this.getUIContext().animateTo({
      duration: PlaybackPage.CHROME_ANIM_MS,
      curve: Curve.EaseInOut
    }, (): void => {
      this.chromeCollapsed = true;
      this.lyricChromeProgress = 0;
    });
    Logger.info(PlaybackPage.logTag, 'lyric chrome hidden: upward gesture');
  }

  /**
   * Swiper 换页时的控制区收尾 —— **照搬无界那个 `onChange` λ 的逐字结构**
   * （`_recover/logic-src/PlayerPage.abc.txt:23189-23215`）。
   *
   * ★★★ 2026-10-17（goal 收尾复核：**回原始字节码确认**，出处
   *   `_recover/disasm/wujie.pa:190080-190111`，即 `PlayerPage.@34*^1*#^1`）：
   * ```ts
   *   onChange(index) {                                  // a3 = index
   *     const L = 1;                                     // 190081-190082（= SWIPER_INDEX_LYRIC）
   *     if (index === L) { this.startIdle(); }            // 190083-190089  ← 歌词页：起计时
   *     else { this.clearIdle(); this.showChrome(); }     // 190091-190099  ← 封面页：停计时 + **显式唤出**
   *     this.atLyricScreen = (index === L);               // 190100-190105
   *     this.syncKeepScreenOn();                          // 190106-190109
   *   }
   * ```
   * ⇒ **空闲计时只在歌词页起**这一点，是上游的**显式分支**（不是我们推断的）✓
   *    —— goal 第 4 条「空闲计时」到此**有据可查**，不需要再核。
   *    （另：`startIdle` 的时长常量 `IDLE_MS` 只在该函数里出现一次，
   *      `wujie.pa:179903-179985`；本仓对应 `PlaybackPage.CHROME_AUTO_HIDE_MS = 5000`。）
   *
   * ⚠️ 我们原来是无条件 `touchChrome()`（= 唤出 **+** 起计时），再在非歌词页补一句
   *   `stopChromeAutoHide()`。那样在**切到封面页**时是"先起计时再停掉"，
   *   净效果虽然也对，但与无界"那里根本不唤出 vs 这里会唤出"的差别被抹掉了 ——
   *   无界切到封面页是**显式唤出**（用户从歌词页滑回来时控制区一定是亮的），
   *   这一条我们碰巧也对，但**动机不同**，且少了"歌词页那一支不唤出"。
   *
   * ⚠️ 另有**有意收窄**：我们那一支里多一道 `canHideLyricChrome()`
   *   （= `usesPhoneSwiperLayout() && 停在歌词页`）⇒ 宽屏/面板那两支不起计时。
   *   上游 `startIdle` 自己还有沉浸模式等内部闸（本仓对应 `entryAllowsAuto` 那条）。
   *
   * @param index 新的页下标（0 = 封面页，1 = 歌词页）
   */
  private onSwiperIndexChanged(index: number): void {
    if (index === PlaybackPage.SWIPER_INDEX_LYRIC) {
      // startIdle：`scheduleChromeAutoHide()` 内部自带"`canHideLyricChrome()` 不成立就不收"
      this.scheduleChromeAutoHide();
      return;
    }
    this.stopChromeAutoHide();
    this.showChrome();
  }

  /**
   * ★★★ 2026-10-16（照搬无界 `BarCollapse`）：**拖动控制条收起 / 展开**。
   *
   * 无界的手势状态机（`design/src/main/ets/logic/BarCollapse.ets`，字节码
   * `wujie.pa:83706-84140`）已逐条转写到 `common/musicbasic/.../model/BarCollapse.ets`
   * （含 `THRESHOLD = 1.5`、轴向锁定、`run` 累积、目标一致不动作、**250ms 节流**）。
   * 本方法只做两件事：**把触摸事件喂进去** + **按它返回的动作驱动收起/展开**。
   *
   * 语义（照抄后的行为）：
   * ```
   *   · 纵向下拉累计 ≤ −1.5vp ⇒ COLLAPSE（控制区收起）
   *   · 纵向上推累计 ≥ +1.5vp ⇒ EXPAND  （控制区展开）
   *   · 横向锁定 ⇒ 整串手势忽略（不会和歌词横滑打架）
   * ```
   * ⚠️ 动画沿用本页既有的那一套（`chromeCollapsed` + `lyricChromeProgress`，240ms `EaseOut`），
   *   与自动收起（3s 空闲）**共用同一条路径** ⇒ 两种入口观感一致。
   * ⚠️ 收起门沿用 `canHideLyricChrome()` —— **与自动收起、拖动收起同一把门**
   *   （照搬无界 `startIdle` 后它已放宽到"手机 Swiper 布局"，含封面页，见那个方法的注释）。
   *   所以不会出现"自动能收、拖动不能收"这种不一致。
   * @param event 控制区容器上的触摸事件
   */
  private onChromeBarTouch(event: TouchEvent): void {
    if (!this.canHideLyricChrome()) {
      return;
    }
    const touches: TouchObject[] = event.touches;
    const first: TouchObject | undefined = touches.length > 0 ? touches[0] : undefined;
    const action: BarAction = this.barCollapse.reportTouch(event.type,
      first !== undefined ? first.windowX : 0,
      first !== undefined ? first.windowY : 0,
      touches.length, Date.now());
    if (action === BarAction.COLLAPSE) {
      Logger.info(PlaybackPage.logTag,
        `RzdBarCollapse action=COLLAPSE collapsed=${this.barCollapse.isCollapsed()} axis=${this.barCollapse.lockedAxis()}`);
      this.hideLyricChrome();
    } else if (action === BarAction.EXPAND) {
      Logger.info(PlaybackPage.logTag,
        `RzdBarCollapse action=EXPAND collapsed=${this.barCollapse.isCollapsed()} axis=${this.barCollapse.lockedAxis()}`);
      // 展开 = 本页既有的"唤出控制区"（`touchChrome()` 里那段 240ms 动画 + 重置空闲计时）
      this.touchChrome();
    }
  }

  /** 停掉自动收起计时（页面卸载、开始收起播放器时调用）。 */
  private stopChromeAutoHide(): void {
    if (this.chromeTimerId >= 0) {
      clearTimeout(this.chromeTimerId);
      this.chromeTimerId = -1;
    }
  }

  /**
   * 照搬无界 `PlayerPage.onLyricInteract()`（`_recover/logic-src/PlayerPage.abc.txt:6914-6932`）：
   *
   * ```ts
   *   onLyricInteract() { if (!chromeHidden) { startIdle(); } }
   * ```
   * 挂载点在同文件 `190116-190130`：只有 **`TouchType.Down`** 调它。
   *
   * ⚠️ 两个"不要搞错"：
   *   · 它**只起计时**（`startIdle`），**不唤出**控制区 ⇒ 这里用 `scheduleChromeAutoHide()`
   *     而**不是** `touchChrome()`（后者 = `showChrome()` + 起计时，是另一条路上的组合）。
   *   · 条件是 `!chromeHidden`（已经收起时**不起**计时）⇒ 这里对应 `!chromeCollapsed`。
   */
  private onLyricInteract(): void {
    if (this.chromeCollapsed) {
      return;
    }
    this.scheduleChromeAutoHide();
  }

  /**
   * 壳层拦到系统返回（要求关闭播放页）→ 播收起动画，不要直接消失。
   *
   * ★★ 2026-10-15（回退后重做）：**删掉原来那句 `setTimeout(0)`**。
   *   当年的注释写的是"不要在 `@Monitor` 回调里直接 `animateTo`，有可能不插值" ——
   *   这个现象是真实存在的，但根因不是"动画作用域"，而是官方的
   *   **「在 `@Monitor` 中触发 `animateTo` 时不显示动画」**：
   *   V2 状态变量修改是异步标脏（Promise 微任务），而 `animateTo` 立刻刷新脏节点决定首帧；
   *   在 `@Monitor` 回调里补间还没开始，被监听的状态就已经在标脏队列里 ⇒ 首帧/插值不对。
   *   官方（`arkts-new-applysync-flushupdates-flushuiupdates`「使用场景 · 动效场景」）给的写法
   *   就是在 `animateTo` 的闭包里用 `UIUtils.applySync` 同步刷新目标值 ——
   *   `closeFullScreenPlayback()` 里已经按这个写法改了，所以这里可以直接调用。
   */
  @Monitor('expandState.collapseVersion')
  onCollapseRequested(): void {
    // ★★★★ 2026-10-17（照搬无界 `MainPage.closeWithAnimation()` 的非手势分支）：
    //   这条 Monitor 是**唯一**的"非手势关闭"入口（`guardPlayerBack()` / 壳层 `onBackPress()`
    //   都走 `expandState.requestCollapse()` ⇒ `collapseVersion++`）。
    //   下拉那条路**不经过这里**（它直接调 `closeFullScreenPlayback()`）。
    //   ⇒ 所以这里正好对应无界的 `pullMode === false` 那一支：**拍快照缩图，不动活页面**。
    this.closeWithAnimation();
  }
  /** Fallback page background tint when art or color pick fails. */
  private static readonly defaultImageBgColor: string = 'rgba(32, 32, 32, 1)';

  /** 背景网格源还没到手时的**有界重取**次数（见 {@link scheduleBackgroundRetry}）。 */
  private static readonly BG_RETRY_MAX: number = 4;
  /** 两次重取之间的间隔（ms）。 */
  private static readonly BG_RETRY_MS: number = 400;

  /**
   * 背景网格源还没到手 ⇒ 隔一会儿再取一次（**有界**）。
   *
   * 为什么需要它（用户实测）：未播放状态点击打开播放器时背景是黑的 ——
   * 因为在线歌曲的真正背景是**网格图**，而它要等 `song.cover` 到手才解得出来；
   * 播放状态会顺手把 metadata 拉齐，所以"点一下播放就正常"。
   * 背景只该跟"封面有没有到手"有关 ⇒ 这里给它一个**收敛**的机会。
   * @param jobSeq 发起那次取色的序号（用它可以丢弃过期的一轮）
   * @param attempt 已重试次数
   */
  private scheduleBackgroundRetry(jobSeq: number, attempt: number): void {
    if (!Number.isFinite(attempt) || attempt >= PlaybackPage.BG_RETRY_MAX) {
      Logger.info(PlaybackPage.logTag,
        `RzdBgRetry give up attempt=${attempt} meshVer=${this.meshSrcVersion}`);
      return;
    }
    setTimeout((): void => {
      // 三道门：页面还在、这一轮没被新的一轮顶掉、页面还看得见
      if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
        return;
      }
      if (this.meshSrcVersion > 0) {
        Logger.info(PlaybackPage.logTag, `RzdBgRetry ok attempt=${attempt}`);
        return;
      }
      Logger.info(PlaybackPage.logTag, `RzdBgRetry retry attempt=${attempt + 1}`);
      void this.getImageColorAsync();
    }, PlaybackPage.BG_RETRY_MS);
  }

  /**
   * Banner watcher: when switchBanner.ts advances, schedule a 3s clear.
   * Compares the parsed timestamp so an older clear does not blank a newer banner.
   */
  onBannerChange(): void {
    const ts: number = this.switchBanner.ts;
    if (ts <= this.bannerTs) {
      return;
    }
    this.bannerTs = ts;
    if (this.bannerClearTimer !== -1) {
      clearTimeout(this.bannerClearTimer);
    }
    this.bannerClearTimer = setTimeout((): void => {
      this.switchBanner.text = '';
      this.switchBanner.ts = 0;
      this.bannerClearTimer = -1;
    }, 3000);
  }

  /**
   * Re-runs onBannerChange whenever a new banner is published via AppStorageV2.
   */
  @Monitor('switchBanner.ts')
  onSwitchBannerTsChange(): void {
    this.onBannerChange();
  }

  /**
   * 取色完成后把新颜色灌进流光着色器。
   *
   * 用 `setEffectParams`（而不是重建 `visualEffect`）：换歌只更新 uniform，
   * 不会重启着色器、也不会让流光"跳"回起点。
   */
  @Monitor('coverTint.version')
  onCoverTintVersionChange(): void {
    this.applyFlowLightColors();
  }

  /**
   * ★★ 2026-10-14 修「流光背景开关经常不跟随设置」：
   *
   * 共享状态 `PlaybackFlowLightState` 是**新创建**的（默认 false），谁都没把 `MusicStoreService`
   * 里持久化的那个值灌进去 —— 只有设置页切开关时才会写共享状态。于是：**开着流光 → 重启 App →
   * 播放页读到的还是默认 false**（设置页没进去过就一直错着），用户看到的就是"开关不跟随设置"。
   *
   * ⚠️ 2026-10-17（**删除了一具同名尸体**）：这里原来还有一个
   *   `syncFlowLightPreference(reason)` 方法，做的是"**store → 共享状态**"这一向；
   *   但真正跑的是 `aboutToAppear` 里那句直接赋值
   *   （`this.flowLightState.enabled = MusicStoreService…getPlaybackFlowLight()`），
   *   而**反向**（共享状态 → 落库）由下面的 `onFlowLightEnabledChange()` 负责。
   *   ⇒ 那个方法**零调用点**、只是"同一件事的两套写法"（它多一条日志 + 一次多余的取色），
   *     留着就是"后来人改错地方"的入口 ⇒ 已删除；此处保留说明，免得又被重新加回来。
   */
  @Monitor('flowLightState.enabled')
  onFlowLightEnabledChange(): void {
    const stored: boolean = MusicStoreService.getInstance().getPlaybackFlowLight();
    if (stored !== this.flowLightState.enabled) {
      MusicStoreService.getInstance().setPlaybackFlowLight(this.flowLightState.enabled);
      Logger.info('RzdFlowLight', `pref persist enabled=${this.flowLightState.enabled}`);
    }
    if (!this.flowLightState.enabled || this.context === undefined || !this.isAlive) {
      return;
    }
    this.getImageColor();
  }

  /**
   * ★★★ 2026-10-17（**照搬无界 `MorphGuard` 的"配色安静窗口"** —— 见 `morphQuietUntilMs` 的推导）
   *
   * @returns 现在**不能**上色时还要等多少 ms（0 = 可以立即上色）。
   *   ⚠️ 不能上色时本函数会**顺手排一次重试**（幂等：`colorRetryQueued` 只允许一条在飞），
   *   重试间隔 = `wait + 32ms`（无界那个 `0x20` 余量），与无界 `MainPage` 的写法逐条对应。
   */
  private colorApplyWaitOrRetry(): number {
    const wait: number = this.expandState.colorApplyWaitMs();
    if (wait <= 0) {
      return 0;
    }
    if (!this.colorRetryQueued) {
      this.colorRetryQueued = true;
      setTimeout((): void => {
        this.colorRetryQueued = false;
        // ★ 2026-10-17：页面已退场就别再上色/补网格 ——
        //   本页的取色链路在退场时会主动释放位图（见 `onDisappear` 里那两句 `releasePixelMapQuiet`），
        //   若这条重试还去 `commitMeshSource`，那就是拿一张**已经释放过的**位图去换源。
        if (!this.isAlive) {
          return;
        }
        // 与无界那个重试 λ 一致：先放开幂等标记，再把上色重跑一遍
        // （无界调的是 `syncReportChrome()`；本仓对应的就是这两个上色点）。
        this.applyFlowLightColors();
        this.republishMeshSourceIfAny();
      }, wait + 32);
    }
    Logger.info(PlaybackPage.logTag,
      `RzdFlowLight color apply deferred ${wait.toFixed(0)}ms (morph quiet window)`);
    return wait;
  }

  /** 把 {@link coverTint} 里的颜色推给着色器（同版本号只推一次）。 */
  private applyFlowLightColors(): void {
    if (this.coverTint.version === this.appliedTintVersion) {
      return;
    }
    // ★ 形变安静窗口内不上色（见 `colorApplyWaitOrRetry`）：等窗口过去它会自己重试一次。
    if (this.colorApplyWaitOrRetry() > 0) {
      return;
    }
    this.appliedTintVersion = this.coverTint.version;
    try {
      this.flowLightController.setEffectParams({
        colorSource: [this.coverTint.sourceColor],
        colorTarget: [this.coverTint.targetColor]
      });
      Logger.info(PlaybackPage.logTag,
        `flow light colors applied v=${this.coverTint.version} src=${this.coverTint.sourceColor}`);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(PlaybackPage.logTag,
        `setEffectParams failed, code=${err?.code}, message=${err?.message}`);
    }
  }

  /**
   * 播放页流光背景层（HDS `UV_BACKGROUND_FLOW_LIGHT` 着色器）。
   *
   * 参考上游 PR #1 在首页的用法，但颜色不是写死的：`colorSource` /
   * `colorTarget` 来自当前封面动态取色（见 {@link publishFlowLightColors}），
   * 每次换歌都会重新算一次。
   *
   * 作为 `Stack` 的**首个子节点**绘制：在页面底色之上、封面/歌词之下。
   * `HitTestMode.Transparent` 是必须的 —— 整层是全屏的，默认命中的话会把
   * 播放页所有按钮的点击全吃掉。
   */
  /**
   * 本机是否具备 HDS 视效能力位。
   *
   * ⚠️ 流光是 HDS `hdsEffect` 的 shader 视效：**设备没有这个能力位时它会静默不画**
   *    （不报错、不抛异常），表现就是用户说的"开了开关但什么都没发生"。
   *    所以这里显式判断 + 记日志，并在不支持时退回一层静态渐变（至少看得见颜色变化）。
   */
  /** 流光的 HDS 能力位：缺失时 shader 视效会静默不画（见 {@link hdsEffectCapable}）。 */
  private static readonly HDS_CORE_SYSCAP: string = 'SystemCapability.UIDesign.HDSComponent.Core';

  // ★★ 2026-10-15（第三十九轮 / Round 20）：`COVER_BLUR` 与 `imageBlurRadius()` **已删除**
  //   （播放页背景改成网格背景后，预渲染模糊那条线在编译图里已无任何调用者）。
  //   删除依据与产物符号自检（modules.abc GONE）见 RzdMusic记忆.md §56.15。

  private hdsEffectCapable(): boolean {
    try {
      return canIUse(PlaybackPage.HDS_CORE_SYSCAP);
    } catch (_err) {
      return false;
    }
  }

  @Builder
  private FlowLightBackground() {
    if (this.hdsEffectCapable()) {
      Stack()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .hitTestBehavior(HitTestMode.Transparent)
        .opacity(FLOW_LIGHT_OPACITY * this.backgroundRevealOpacity())
        // 官方示例里挂 shader 视效的容器都带底色（`backgroundColor('#383838')`）；
        // 这里给一层**很淡的暗底**，既给视效一个可渲染的底，又不遮住封面。
        .backgroundColor('#33000000')
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .shaderEffect({
            effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
            animation: {
              duration: FLOW_LIGHT_DURATION_MS,
              iterations: -1,
              autoPlay: true
            },
            // 初值用兜底色；真正的颜色由 applyFlowLightColors 在取色完成后下发，
            // 这样即使取色很慢也能立刻看到流光在动（而不是黑屏等半天）。
            params: {
              colorSource: [this.coverTint.sourceColor],
              colorTarget: [this.coverTint.targetColor]
            },
            controller: this.flowLightController
          })
          .buildEffect())
        .onAppear((): void => {
          Logger.info('RzdFlowLight',
            `layer mounted capable=1 enabled=${this.flowLightState.enabled} ` +
            `opacity=${FLOW_LIGHT_OPACITY * this.backgroundRevealOpacity()} ` +
            `src=${this.coverTint.sourceColor} dst=${this.coverTint.targetColor} v=${this.coverTint.version}`);
          // autoPlay 已开，再显式 play 一次让状态确定（换歌重建该层时不会停在暂停态）
          try {
            this.flowLightController.play();
          } catch (error) {
            const err = error as BusinessError;
            Logger.warn('RzdFlowLight', `play failed code=${err?.code} message=${err?.message}`);
          }
        })
    } else {
      // 能力位缺失：退回静态渐变（颜色仍跟封面走），保证"开关打开看得见东西"
      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .hitTestBehavior(HitTestMode.Transparent)
        .opacity(FLOW_LIGHT_OPACITY * this.backgroundRevealOpacity())
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[this.coverTint.sourceColor, 0], [this.coverTint.targetColor, 1]]
        })
        .onAppear((): void => {
          Logger.warn('RzdFlowLight',
            `layer mounted capable=0（无 HDS 视效能力位，改用静态渐变）enabled=${this.flowLightState.enabled} ` +
            `src=${this.coverTint.sourceColor} dst=${this.coverTint.targetColor}`);
        })
    }
  }

  /** 醒目提示横幅：音源脚本跨脚本切换时显示，3 秒后自动隐藏。 */
  @Builder
  private SwitchBanner() {
    if (this.switchBanner.text.length > 0) {
      Row() {
        SymbolGlyph($r('sys.symbol.arrow_right_circle'))
          .fontSize(20)
          .fontColor([Color.White])
          .margin({ right: 8 })
        Text(this.switchBanner.text)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
      }
      .width('88%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .borderRadius(16)
      .backgroundColor('rgba(220, 60, 60, 0.95)')
      .margin({ top: 56 })
      .align(Alignment.Center)
    }
  }

  /**
   * 浮层定位口径（改前那版注释是**错的**，2026-10-15 按本机 SDK 更正）。
   *
   * ❌ 旧说法：「`position({x, y})` 是在**自然位置**上再加偏移，所以居中的 Stack 里要先减
   *    `(窗口尺寸 − 自己尺寸) / 2`」。**不成立。**
   *
   * ✔ 本机 SDK 原文（`sdk\default\openharmony\ets\component\common.d.ts:25284`，
   *    `position(value: Position | Edges | LocalizedEdges)`）：
   *    「**Sets the absolute position of the component relative to the position of the
   *    parent component.**」—— 就是**相对父组件左上角的绝对定位**，与自然位置/`alignContent` 无关。
   *
   * ⇒ 结论（本文件所有浮层都按这条写）：
   *    只要浮层所在容器**左上角就是窗口原点**，`PlayerExpandState` 交出的**窗口坐标**
   *    就能直接当 `.position({x, y})` 用，**全链零换算**。
   *    `MorphCoverBridge`（同一层）按窗口坐标落位已被真机验证；`LyricFloatLayer` 同层同口径。
   *
   * 现状：A2 的歌词页浮层由下面的 {@link LyricFloatLayer} 承担；
   * 这两个 `morphWindow*Vp()` 是更早那版（已删）`LyricCoverOverlay` 的遗留取值器，保留不动。
   */
  /** @returns 浮层参考用的窗口宽度（vp）。 */
  private morphWindowWidthVp(): number {
    return this.expandState.windowWidthVp;
  }

  /** @returns 浮层参考用的窗口高度（vp）。 */
  private morphWindowHeightVp(): number {
    return this.expandState.windowHeightVp;
  }

  /** 收起进度 0..100：**0 = 完整播放页（静止态）**，100 = 收起成贴底的一条。 */
  @Local collapseProgress: number = 0;

  /**
   * 共享的展开/形变几何（与壳层、迷你条、大封面共用同一个实例）。
   *
   * 里面的 `morph` 容器字段（scale / translate / clipHeight / radius）就是
   * 无界 `ExpandAnimation` 那套"整页缩放 + 竖直裁剪窗口"的状态；
   * 壳层在跟手时改它，本页直接读来渲染。
   */
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /**
   * 跟手上拉时把共享进度镜像进来。
   *
   * 壳层（products）在迷你条上做上拉手势、改 `expandState.morph`，
   * 这里只负责在**非容器形变**的老路径（点击打开）下保持 `collapseProgress` 同步。
   */
  @Monitor('expandState.transitionProgress')
  onTransitionProgressChanged(): void {
    if (this.expandState.morphContainerActive()) {
      // 容器形变那条路不用 collapseProgress（高度恒 100%，见 sheetHeightPercent）
      return;
    }
    this.collapseProgress = this.expandState.transitionProgress;
  }

  /**
   * 下拉收起手势（竖直方向）。
   *
   * ⚠️ `distance` 是**无界对齐值**（见 {@link PlaybackPage.DISMISS_PAN_DISTANCE_VP} 的注释）：
   *    不写它时框架默认 **5vp**，那一档会被 1~2vp 的抖动识别成"开始下拉"。
   */
  private panOption: PanGestureOptions = new PanGestureOptions({
    direction: PanDirection.Vertical,
    distance: PlaybackPage.DISMISS_PAN_DISTANCE_VP
  });

  // ═══════════ 封面「续飞到歌词页」（对标 无界音乐 CoverMorph 双端点）═══════════

  /**
   * 封面续飞进度：0 = 停在展开页位置，1 = 已到歌词页位置。
   *
   * 静止在播放页时是 0（**不画飞行封面**，与没有这套动画时逐像素一致）；
   * 只有切到歌词页/切回封面页的那 360ms 里才 0⇄1 过渡。
   */
  @Local lyricMorphT: number = 0;
  /** 飞行封面是否可见（静止态一律 false，保证不影响静态布局）。 */
  @Local lyricMorphVisible: boolean = false;
  @Local lyricMorphOpacity: number = 1;
  private lyricMorphGen: number = 0;
  private lyricMorphTarget: boolean = false;
  private lyricSwiperSettled: boolean = false;
  private lyricFlightSettled: boolean = false;
  @Local lyricChromeProgress: number = 1;
  @Local lyricChromeHeight: number = 0;
  @Local lyricChromeMeasurePending: boolean = true;
  private lyricChromeWidth: number = 0;

  // ═══════════ 控制区静止自动收起（对标 无界音乐 BarCollapse）═══════════

  /** 控制区是否已自动收起（收起后点任意处唤出）。 */
  @Local chromeCollapsed: boolean = false;
  /**
   * ★★★ 2026-10-17（照搬无界 `PlayerPage.hideChrome()` 的"面板开着就不收"守卫）：
   * **播放队列 / 其他版本**这两个弹层是否开着（由 `ControlAreaComponent.onAuxSheetOpenChange` 上报）。
   *
   * 无界那一条守卫是 10 个 flag 的短路或链（`abc.txt:4124-4225`）；
   * 本仓菜单 sheet 那一族（`settingsOpen`/`qualityOpen`/…）落在**一个** `bindSheet` 里，
   * 已由 `playMenuOpen` 代表；剩下这两个由本字段代表 ⇒ 两者合起来 = "任何面板开着"。
   * ⚠️ 与 `playMenuOpen` **必须一起**并进收起门（同一条守卫的两个分量，不许只判一个）。
   */
  @Local auxSheetOpen: boolean = false;
  /**
   * ★ 2026-10-17：`MorphGuard` 安静窗口的"重试只排一条"幂等标记
   * （对标无界 `MainPage.colorModeRetryQueued`，`wujie.pa:145966/145979`；重试 λ 里复位）。
   */
  private colorRetryQueued: boolean = false;
  /**
   * ★ 2026-10-17：安静窗口期间**待补**的网格背景源（窗口过去后由
   * {@link republishMeshSourceIfAny} 提交）。所有权在本页，替换时释放旧的。
   */
  private pendingMeshPm: image.PixelMap | undefined = undefined;
  /** 自动收起计时器。 */
  private chromeTimerId: number = -1;
  /** 最后一次控制区交互时间（ms）。 */
  private chromeTouchedAtMs: number = 0;

  // ═══════════ 展开时的逐元素淡入（自持进度，不复用共享相位）═══════════

  /**
   * 展开补间是否在跑。
   *
   * ⚠️ 这是**本地**标志，且只用来决定"要不要用动画值"；只要它是 false，
   * 所有淡入取值一律返回静止态（1 / 0）。这样不存在"标志残留导致内容透明"的可能
   * —— 那是曾经的真实 bug（用户：封面淡淡出现后整页空白）。
   //  形变进度不另存变量：直接复用 `collapseProgress`（见 `morphProgress()`），
   //  避免"高度到了但缩放没到"的两套计时错位。
   */
  @Local expandIntroRunning: boolean = false;

  /** Seeds cover Resource from the current queue item. */
  aboutToAppear(): void {
    // 先记一条"这一页挂载时走的是哪条路"：点击打开 vs 上拉打开的区别就在 `pullDragging`，
    // 排查"点击打开还是旧动画"时这一行最关键（`hdc shell hilog | grep "expand intro"`）。
    Logger.info(PlaybackPage.logTag,
      `aboutToAppear: pullDragging=${this.expandState.pullDragging} ` +
      `usable=${this.expandState.morphUsable} stage=${this.expandState.morphStage}`);
    // ★★★ 2026-10-16（**修用户实测「歌词页封面没变小、叠在歌词上面」**）：
    //   页面**挂载那一刻**就把"封面浮层飞行进度"对齐到当前页 —— 这是本页第一次有机会做这件事，
    //   而且它与"是否发生过一次滑动"无关（理由见 `syncLyricMorphToPage()` 的长注释）。
    //   用户那张截图正是这个形状：**swiper 在歌词页、`lyricMorphT` 还是 0** ⇒ 大封面 + 歌词同时在场。
    //   ⚠️ 放在 `aboutToAppear`（struct 级、挂载即有）而不只在内容层 `.onAppear`（节点级、
    //      分支重建才跑）—— 两处都要，因为两者时机不同（前者早于首帧布局，后者晚于挂载）。
    this.syncLyricMorphToPage('boot');
    // ★ **自愈**：见 `onDisAppear` 里那段说明 —— 这两个标记一旦残留，点击打开就永远
    //   跳过形变初始化，只播老动画。这里再兜一层：只有"确实在看手势"（drive=FINGER）
    //   才认为手指在驱动；而且即使如此，只要已经过了 2 秒还没收尾，就一定是残留
    //   （一次跟手不可能持续那么久），直接清掉。
    const dragAgeMs: number = Date.now() - this.expandState.pullStartedAtMs;
    const dragGenuine: boolean = this.expandState.pullDragging &&
      this.expandState.morphDrive === MorphDrive.FINGER && dragAgeMs >= 0 &&
      dragAgeMs < PlaybackPage.PULL_DRAG_MAX_MS;
    if (this.expandState.pullDragging && !dragGenuine) {
      Logger.warn(PlaybackPage.logTag,
        `aboutToAppear: clearing stale pull session (drive=${this.expandState.morphDrive} age=${dragAgeMs}ms)`);
      this.expandState.pullDragging = false;
      this.expandState.morphDrive = MorphDrive.NONE;
    }
    this.coverRadiusState.radius = MusicStoreService.getInstance().getCoverCornerRadius();
    // ★ 流光背景开关：**必须在这里从持久化存储灌进 V2 状态**。
    //   设置页只在「用户切换开关」时写 `PlaybackFlowLightState`，冷启动时没人灌值 ⇒
    //   状态默认 false，即使设置里是"开"也永远不画流光（用户反馈的"流光背景不生效"就是这个）。
    //   与 `AmllLyricView`（自己从 store 灌 fps/居中/副歌词）保持同一套做法。
    this.flowLightState.enabled = MusicStoreService.getInstance().getPlaybackFlowLight();
    const song = this.state.getCurrentSongItem();
    this.releaseBackgroundCoverIfPixelMap();
    this.imageLabel = song !== undefined ? song.label : $r('app.media.ic_avatar1');
    this.applyKeepScreenOn(true);
    // 页面打开时如果已有未过期的横幅，立即触发清理计时。
    if (this.switchBanner.ts > 0) {
      this.onBannerChange();
    }
    // ★ 展开动画：先在 `aboutToAppear` 把进度放到"收起"，**保证第一帧画出来就是贴底的一条**。
    //   如果放到 `onAppear` 再置，会先渲染出一帧完整播放页再收回去，看着就是闪一下。
    //
    // ★★ 2026-10-15（照搬无界）：**壳层已经起了形变时，这一档不许再压**。
    //   无界的展开**只有一个动画主** —— 壳层的 `ExpandAnimation.doEnter`（350ms）驱动整页的
    //   `scale/translate/clipWidth/clipHeight`；播放页自己**没有**第二套"贴底一条长上来"。
    //   而 `collapseProgress` 这套（内容层 `height` 从贴底一条长到 100%）是**派音旧路**，
    //   两条同时在跑就是用户实测的「点击打开播放器没有动画 / 背景不对」：
    //   页面被旧路按"贴底一条"起手，而形变的起点几何已经被壳层按迷你条胶囊压好了。
    //   判据用 `morphContainerActive()`（stage ∈ ENTERING/LEAVING/LANDING）：它在
    //   `pullOpenBegin()` 里就置好了，而壳层是**先 begin 再 pushPath**（对标无界
    //   `beginMorphEnter` 内部自己 push 的顺序）⇒ `aboutToAppear` 这一刻读到的就是真相。
    const shellOwnsMorph: boolean = this.expandState.morphContainerActive();
    if (shellOwnsMorph) {
      this.collapseProgress = 0;
    } else {
      this.collapseProgress = PlaybackPage.EXPAND_START_PROGRESS;
    }
    this.dismissMorphActive = false;
    // ★★ 2026-10-15：`isClosing` 是 `onDismissDrag()` / `closeFullScreenPlayback()` 的**第一道闸**，
    //   它一旦残留成 true，下拉收起与关闭按钮就双双失效（详见 `closeFullScreenPlayback()` 里
    //   那条 `morphGenAlive` 早退分支的补漏注释）。挂载时**无条件**清一次：
    //   新挂载的页面不可能"正在收起"，任何残留都只可能来自上一轮未走完的会话。
    this.isClosing = false;
    // 每次打开都重置重试额度（照抄 `schedulePublishRetry` 的 12×32ms）
    this.morphRetryLeft = 12;
    // ★ 容器形变那条路（对标无界 ExpandAnimation）：不是上拉拉进来的（点击 / 起播意图打开）
    //   就**就地**起一次形变 —— 几何压到起点（p = 0 = 迷你条封面那一小块），
    //   于是第一帧画出来就是"迷你条那里的一小块"，补间在 `onAppear` 里跑。
    //   ⚠️ 返回 false 说明几何没量齐（迷你条封面没上报 / 宿主没尺寸）：必须把相位退回去，
    //      否则 `sheetHeightPercent()` 会一直返回 100%，老路径的"贴底一条长上来"也被卡掉，
    //      用户看到的就是"点开播放器没有任何动画"。
    // ★ **不要在挂载时就把几何压到起点**（这一条是无界 `expand.init` 的顺序，之前的做法反了）：
    //   反编译里 `setupExpandTransition` 是"**先量目标节点矩形**（此刻播放页还没缩、是原尺寸）
    //   → 再 start 形变"。我原来在 `aboutToAppear` 就 `morphBeginEntering()`（= 立刻缩到起点），
    //   于是等到能量的时候，量到的是**被压扁那一帧**的封面 —— 终点就被写坏了：
    //   "第一次没有封面飞入"、"结束时大小不对"、"只移动不缩放"全是这一条引起的。
    //   现在改成：挂载阶段什么都不做，由 `playExpandIntro()`（onAppear 起，带 12×32ms 重试）
    //   在**首次量到**的那一刻才 `measureMini` + `morphBeginEntering()` —— 量的是原尺寸矩形，
    //   紧接着同一帧压到起点（配合下面的 `introPaintReady` 门，不会闪出完整播放页）。
    // ⚠️ 看门狗：万一下面 `onAppear` 里的补间因为任何原因没跑起来，
    //   进度就会永远停在"收起"，用户看到的是打不开播放器。
    //   最迟 COLLAPSE_WATCHDOG_MS 之后强制回到完整态 —— 宁可没有动画。
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
    }
    this.collapseWatchdogTimer = setTimeout((): void => {
      this.collapseWatchdogTimer = -1;
      if (this.collapseProgress > 0) {
        Logger.error(PlaybackPage.logTag,
          `expand watchdog fired progress=${this.collapseProgress}, force full screen`);
        this.collapseProgress = 0;
      }
    }, PlaybackPage.COLLAPSE_WATCHDOG_MS);
  }

  /**
   * 关闭落位之后：**等播放页真的从路由栈里下台，再复位形变几何**。
   *
   * ## 为什么不能在同一 tick 里复位（用户第 ③ 条的机制）
   * 关闭收尾原来是 `isShowPlay = false`（→ 壳层 `@Monitor` **异步** pop）
   * 紧跟着**同步** `morphReset()`。而 `morphReset()` 会
   * `morphStage = NONE` + `morphP = 1` + `morphClipHeight = 0` + `morphScale = 1`
   * ⇒ 容器**不裁剪、不缩放** = **满屏播放页**；
   * 路由却要到下一帧才被摘掉（`@Monitor` 派发一层 + 布局摘除一层）
   * ⇒ 中间那 1~2 帧就是"已经缩成小圆点 → 突然满屏 → 消失"，
   * 用户描述成「动画结束了**突然来个展开播放器的动画**」。
   *
   * ## 为什么"晚一点复位"是安全的
   * `morphLand()` 已经把绘制权交还给迷你条了，而"被裁在迷你条那么高"的那一份几何
   * **在页面下台之前正是正确的显示状态** ⇒ 复位没有任何理由抢在 pop 前面。
   * 反过来，**不复位会污染下一轮**（几何挂在 AppStorageV2 上是共享的）⇒ 必须复位，只是要晚。
   *
   * ## 判据为什么用"节点+路由都下台了"而不是固定延时
   * 固定延时（例如 64ms）只是**赌** pop 比它快；赌输就悄悄退回原 bug。
   * 两个**直接读数**都要满足才复位，因为单看一个都会"复位得太早"：
   * · `!this.isAlive`（节点级）—— `onDisappear` 是节点真的消失时才触发；
   * · `!playerRouteStillPushed()`（路由级）—— 口径与壳层 `playerRouteIndex()` 逐字一致。
   * ⚠️ 只看路由会**太早**：`pop()` 只是改 `NavPathStack` 的**数据**，
   *    节点的摘除要等下一次 layout ⇒ 路由已下台、节点还在屏上的那一帧是存在的。
   * ⚠️ 只看节点也会**太早**：关闭途中的"分支重建"同样会触发 `onDisappear`（本文件 5000+ 行
   *    的注释专门讲过这件事）—— 那时节点还会回来。
   * ⇒ 两者**同时**成立才是"真的走了"；再加 `attempt >= RESET_POLL_MAX` 兜底，
   *    保证"哪怕两个读数都坏掉，几何也一定会被复位"（宁可晚，不可不清）。
   *
   * ## 两道守卫（缺一不可）
   * · `closeGen !== this.closeGen`：这一轮关闭已被"下一次关闭请求"取代 ⇒ 别清；
   * · `!morphGenAlive(resetGen)`：几何世代号已经变了 ⇒ 已经有别人（新一轮打开的自愈
   *   `staleClr` / `leakClr`）清过并重建了会话 ⇒ **再清一次就会把刚起的会话掐死**
   *   （那正是"点击打开没有动画"的成因）。
   *
   * @param closeGen 捕获自关闭起手的关闭世代号
   * @param resetGen 捕获自关闭收尾那一刻的形变世代号
   * @param attempt 已经轮询过几次（内部递归用）
   */
  private scheduleMorphResetAfterPop(closeGen: number, resetGen: number, attempt: number): void {
    setTimeout((): void => {
      if (closeGen !== this.closeGen) {
        PlaybackPage.ev('RST', 'skip(newerClose)');
        return;
      }
      if (!this.expandState.morphGenAlive(resetGen)) {
        PlaybackPage.ev('RST', 'skip(newerSession)');
        return;
      }
      const nodeGone: boolean = !this.isAlive;
      const routeGone: boolean = !this.playerRouteStillPushed();
      if (!(nodeGone && routeGone) && attempt < PlaybackPage.RESET_POLL_MAX) {
        this.scheduleMorphResetAfterPop(closeGen, resetGen, attempt + 1);
        return;
      }
      this.expandState.morphReset();
      // ★ 2026-10-17（用户报「上拉播放条再回去，播放条变成**纯色半透明**」⇒ 把"谁在占着迷你条的
      //   绘制权"也打进这一条）：`bar=` = `sourceBarHidden`（1 = 迷你条整条被藏起来了；
      //   正常应当是 **0**）；`ovl=` = 壳层浮层那一棒的进度（`morphOverlayP`，静止态应当是 1）；
      //   `own=` = 元信息克隆层是否还占着绘制权（1 = 还在占 ⇒ 迷你条那份歌名被压成 0）。
      //   ⚠️ 这几个量**只在这里读**（`morphReset()` 刚刚把它们归位），所以它反映的是
      //   "收尾做完之后"的真实状态 —— 用户下次打开徽标就能看到上一次关闭留下了什么。
      PlaybackPage.ev('RST',
        `p=${this.expandState.morphP.toFixed(2)} stage=${this.expandState.morphStage} ` +
        `cont=${this.expandState.morphContainerActive() ? 1 : 0} ` +
        `try=${attempt} node=${nodeGone ? 1 : 0} route=${routeGone ? 1 : 0} ` +
        `bar=${this.expandState.sourceBarHidden ? 1 : 0} ` +
        `ovl=${this.expandState.morphOverlayProgress().toFixed(2)} ` +
        `own=${this.expandState.metaBridgeOwnsPaint() ? 1 : 0}`);
    }, PlaybackPage.RESET_POLL_MS);
  }

  /**
   * 播放页路由**是否还在壳层的 `NavPathStack` 里**。
   *
   * ★ 2026-10-16 新增（唯一调用点：`.onDisAppear()` 里那道 `isShowPlay` 兜底门）。
   *
   * ## 为什么需要它
   * `isShowPlay` 是**壳层路由的驱动源**（`Index.@Monitor('appState.isShowPlay')`
   * → `popPlayerRoute()`）。而 `.onDisAppear()` 是**节点级**回调，会在
   * "点击打开时旧实例卸载 / 分支重建"这些场合**也**触发 —— 那时播放页路由明明在栈里。
   * 所以要写 `isShowPlay = false` 之前，必须先确认"这一次真的是下台"。
   *
   * ⚠️ 口径与壳层的 {@link Index.playerRouteIndex} **逐字一致**（`getAllPathName()` +
   *    `indexOf(PLAYER_PAGE)`），这样两边对"播放页在不在栈里"永远是同一个答案。
   * ⚠️ 取不到栈（`@Consumer` 没接上）时**返回 true**（= 保守认为"还在栈里"）：
   *    宁可漏掉一次 Hard-exit 兜底，也绝不冒着"把刚打开的播放页弹掉"的风险。
   */
  private playerRouteStillPushed(): boolean {
    try {
      const names: string[] = this.pageIndexInfos.getAllPathName();
      if (names === undefined) {
        return true;
      }
      return names.indexOf(RouterUrlConstants.PLAYER_PAGE) >= 0;
    } catch (err) {
      Logger.warn(PlaybackPage.logTag, `playerRouteStillPushed failed: ${err}`);
      return true;
    }
  }

  /**
   * @returns 这次卸载**该不该把形变绘制权交还给迷你条**（= 该不该 `morphReset()`）。
   *
   * ★★★ 2026-10-16（**"点击打开没有动画"的最终判据** —— 三轮试错后定稿）
   *
   * ## 被否掉的两个版本（别再回去）
   * | 判据 | 为什么错 |
   * | --- | --- |
   * | `morphUsable`（"几何已就绪"） | **太晚**：点击路径在挂载那一刻终点锚点还没量到 ⇒ 恒假 ⇒ 门永远开着 |
   * | `playerRouteStillPushed()`（"路由还在栈里"） | **依赖框架调度**：`.onDisAppear` 那道门是 `setTimeout(0)`、`aboutToDisappear` 是同步，而 `popPlayerRoute()` 在**另一个** `@Monitor` 回调里跑 —— 三者谁先谁后静态读不出来（`RzdMusic记忆.md` §110 已记为不确定项） |
   *
   * ## 定稿判据 = **用户意图**（`isShowPlay`）+ 一条硬例外
   * ```
   *   !isAlive          ⇒ 真·组件卸载（不是"打开时旧实例让位"）⇒ 必须放权
   *   morphGeomReady    ⇒ 这一轮真的在播（终点几何已量到）⇒ 绝不能打断
   *   state.isShowPlay  ⇒ 壳层唯一的"播放页该不该在屏上"真源 ⇒ 放权 = 把打开自己掐断
   * ```
   *   · **点击打开**：壳层刚把 `isShowPlay` 置 `true` ⇒ 这一次卸载不叫放权 ✓
   *   · **关闭**（关闭按钮 / 下拉 / 系统返回）：关闭链路已置 `false` ⇒ 放权 ✓
   *   · 两条都不依赖"处理那一刻栈里有什么" ⇒ **不依赖任何时序**。
   *
   * ⚠️ `!isAlive` 那条**必须保**：它同时消掉"会话泄漏"——泄漏会让下一次点击读到
   *    `isFreshSession = false` 而走"放弃会话"分支（又没动画）。
   *    配套的兜底在 `Index.beginOpenMorphOnClick`（`leakClr` 那条自愈）。
   * ⚠️ 与 `.onDisAppear` 里那道门**必须同一个判据**（同一形状，不许各写一套）。
   */
  private morphSessionOughtToLive(isAliveAtUnmount: boolean = this.isAlive): boolean {
    if (!isAliveAtUnmount) {
      return false;
    }
    if (this.expandState.morphGeomReadyNow()) {
      return true;
    }
    return this.state.isShowPlay;
  }

  aboutToDisappear(): void {
    // ★★★ 2026-10-16（**"点击打开 / 点击关闭 / 系统返回 没有动画"的最终推手**）：
    //   原句是**无条件、同步**的 `morphReset()`。而 `morphReset()` 会做四件事：
    // ```
    //     morphGen++                  ⇒ 所有 `morphGenAlive` 守卫立刻过期
    //     morphUsable = false         ⇒ §102/§104 修好的那三处守卫又全废
    //     morphSessionStarted = false ⇒ §108 加的"新会话"判据被抹掉
    //     morphGeomReady = false      ⇒ 上一轮加的 `pullGeomReady` 门被关回去
    // ```
    //   ⚠️ 而**点击打开时，旧播放页实例的 `aboutToDisappear` 就在这一轮起手之后跑**
    //   （本文件 `:4235` 自己写过"新实例 `onAppear` 与旧实例 `onDisappear` 几乎同帧"；
    //     `aboutToDisappear` 比 `onDisappear` **更早**，而且**没有任何延迟**）
    //   ⇒ 它把**刚刚建立好的新一轮会话**整个清掉：
    //     · `beginOpenMorphOnClick` 的 `isFreshSession` 判据被抹 ⇒ 走"放弃会话"那条分支；
    //     · `settlePullOpen` 的补量链把几何量回来之后，又会有人再清一次；
    //     · 观感就是用户报的那三条 —— **点击打开 / 点击关闭 / 系统返回 都没有封面/背景动画**
    //       （而上拉那条路不经过"旧实例卸载"，所以一直正常）。
    //
    // ## 判据：{@link morphSessionOughtToLive}（三轮试错后定稿，理由写在那里）
    // ```
    //   !isAlive                ⇒ 真·组件卸载 ⇒ 必须放权（这条同时消掉"会话泄漏"）
    //   morphGeomReady          ⇒ 这一轮真的在播 ⇒ 绝不能打断
    //   state.isShowPlay        ⇒ 用户意图"播放页该在屏上" ⇒ 放权 = 打开被自己掐断
    // ```
    //   ⚠️ 我先后试过 `morphUsable` 与 `playerRouteStillPushed()`，两个都错，原因见
    //      `morphSessionOughtToLive()` 的注释（一个太晚、一个依赖框架调度）。
    if (!this.morphSessionOughtToLive()) {
      this.expandState.morphReset();
    } else {
      Logger.info(PlaybackPage.logTag,
        'RzdMorphAboutToDisappear keep session (morphSessionOughtToLive: isAlive/showPlay/geom)');
    }
    ++this.lyricMorphGen;
    this.lyricMorphVisible = false;
    this.lyricChromeProgress = 1;
    this.applyKeepScreenOn(false);
    if (this.bannerClearTimer !== -1) {
      clearTimeout(this.bannerClearTimer);
      this.bannerClearTimer = -1;
    }
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    // 控制区自动收起的计时也要停：页面都走了，别再让定时器空转
    this.stopChromeAutoHide();
    // 下一次进来 `aboutToAppear` 会重新置成收起，这里复位只是为了不留脏状态
    this.collapseProgress = 0;
  }

  /**
   * 「一镜到底」展开动画：把进度从"收起"补间到 0。
   *
   * 手法完全照参考工程 MusicHome：**只用 `height` / `translate` / `scale` 三个基本属性**，
   * 不碰任何形状裁剪 —— 那边播放页下滑收起时的"封面变小"就是这么做的（
   * `dismissSheetHeightPercent` + `coverLinearScale`），我们只是把同一套进度反向跑一遍。
   *
   * 为什么这样就够了：内容层 `justifyContent(FlexAlign.End)` 贴着底边，
   * 高度从"贴底一条"长到 100% = 从底部向上铺满；封面用 `layoutWeight(1)`，
   * 高度变小它自己就变小，于是"封面慢慢变大"也一起来了。
   */
  private playExpandIntro(): void {
    // ★ **统一入口 + 无界式兜底**：所有打开方式（点击、起播意图、上拉松手）都从这里进。
    //   · 手指正在驱动 → 让给手势；
    //   · 两端锚点（迷你条封面 + 播放页封面）都量到了 → 走形变（`tryStartMorphIntro`）；
    //   · 还没齐（点击那一刻播放页刚挂载、封面还没布局完）→ **重试若干帧**，
    //     对标无界 `beginMorphEnter` 失败时"注册 onPullReady 等就绪"的做法。
    //
    // ⚠️ 判据必须是**两端**锚点（`morphIntroAnchorsReady`），不能只判"迷你条量到了"：
    //    终点（播放页封面）没就绪时 `endCoverSize = 0`，续飞封面根本不会画
    //    （`morphBridging()` 为 false），而播放页自己那张封面是"落位才现"——
    //    于是头一两次展开的观感就是"点开→什么都没有→啪一下到位"，
    //    和用户投诉的"点击打开还是旧动画"几乎分不出来。
    if (this.tryStartMorphIntro()) {
      return;
    }
    if (this.morphRetryLeft > 0) {
      this.morphRetryLeft--;
      Logger.warn(PlaybackPage.logTag,
        `expand intro: anchors not ready, retry (left=${this.morphRetryLeft}) ` +
        `usable=${this.expandState.morphUsable} bigKnown=${this.expandState.bigCoverAnchored()}`);
      setTimeout((): void => {
        if (this.isAlive && !this.isClosing) {
          this.playExpandIntro();
        }
      }, PlaybackPage.MORPH_RETRY_MS);
      return;
    }
    // ★ 重试用尽 → **直接落位，绝不播老动画**（对标反编译的 `setFinalStatus()`）：
    //   反编译 `setupExpandTransition` 里 `expand.init(...)` 返回 false 的兜底就是
    //   "放弃动画、直接落位"。退回去播"压扁内容层高度"那套老动画是**我的发明**，
    //   也正是用户反复反馈的"点击/返回用的是旧动画"的来源。
    Logger.error(PlaybackPage.logTag,
      'expand intro: anchors never became ready, landing without animation (setFinalStatus)');
    this.expandState.morphReset();
    this.expandState.morphSettleOpen();
    // 无动画落位也必须开门，否则整页会一直停在"不画"的状态（打不开播放页）
    this.introPaintReady = true;
    this.collapseProgress = 0;
    this.expandIntroRunning = false;
  }

  /**
   * 尝试走形变展开路径：量锚点 → 进相位 → 起补间。
   * @returns true = 已经按形变路径开始（调用方不要再走老路径）
   */
  private tryStartMorphIntro(): boolean {
    if (this.expandState.pullDragging && this.expandState.morphDrive === MorphDrive.FINGER) {
      // 手指正在驱动：谁也别抢；绘制门也一并放行（这条路不进下面的开门分支）
      // 首次上拉的目标尚未布局时仍保持透明全尺寸，补量成功再放行。
      this.introPaintReady = this.expandState.morphUsable;
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
      return true;
    }
    this.expandState.pullDragging = false;
    // ★ 判据是**两端锚点都齐**（`morphIntroAnchorsReady`），不是"迷你条量到了"：
    //   终点（播放页封面）没就绪时 `endCoverSize = 0`，续飞封面根本不会画
    //   （`morphBridging()` 为 false），而播放页自己那张封面是"落位才现"——
    //   于是头一两次展开就是"点开→什么都没有→啪一下到位"（用户实测的"第一次没有封面飞入"）。
    //
    // ★ 顺序由 `prepareMorphEntry` 固定：**作废终点 → 在原尺寸时量 → 再压到起点**。
    //   ⚠️ 这里**故意不做 `alreadyRunning` 之类的短路**：一旦短路，就会在
    //      "终点已有、但本轮还没进过形变"的中间态下跳过压起点，
    //      于是 `collapseProgress`/门状态与相位对不上。幂等重入是安全的。
    //   上一版的 bug 正在这里：作废动作被放在 `morphBeginEntering()` 内部，
    //   正好把刚量到的终点抹掉 → 重试期又补不回来（`morphLive()` 挡着）
    //   → 重试用尽无动画落位 ⇒ **点击路径从来没进过 `playMorphOpenIntro()`**。
    if (!this.expandState.morphUsable) {
      return false;
    }
    // ★★ 2026-10-15（回退后重做）**为什么外面要包一层 `UIUtils.applySync`**：
    //   `prepareMorphEntry` 的最后一步是"把几何压到起点"（`applyMorphProgress(0)`），
    //   紧接着**同一个任务里**就起补间。而 V2 的状态变量修改**不会立即标脏**（抛 Promise 微任务），
    //   `animateTo` 却会**立刻刷新已标脏节点来决定动效首帧** ⇒ 压起点那一下**没生效**，首帧用旧值。
    //   官方（`arkts-new-applysync-flushupdates-flushuiupdates`）明确规定这种
    //   "动效前有额外修改"的场景要用 `UIUtils.applySync` 同步刷新后再起动画 —— 这正是
    //   "点击打开和手指拖动打开是两个动画"的结构性根因（50ms 延迟/重试/绘制门都是它的补丁）。
    //   ⚠️ 它只解决**标脏**、不解决**布局**：等封面节点量得到仍然要靠上面的重试窗口。
    let prepared: boolean = false;
    UIUtils.applySync((): void => {
      prepared = this.expandState.prepareMorphEntry(this.getUIContext(), true);
    });
    if (!prepared) {
      // 保留本轮就绪状态，等待下一次原尺寸布局，不在重试间压缩/复位布局。
      return false;
    }
    if (!this.expandState.morphIntroAnchorsReady()) {
      Logger.warn(PlaybackPage.logTag,
        `expand intro: anchors not ready ` +
        `(usable=${this.expandState.morphUsable} bigKnown=${this.expandState.bigCoverAnchored()})`);
      return false;
    }
    // 几何就绪：开门，允许绘制（此时已经是"迷你条那一小块"的起点态）
    this.introPaintReady = true;
    this.expandIntroRunning = false;
    this.collapseProgress = 0;
    this.playMorphOpenIntro();
    return true;
  }

  /**
   * 老路径（几何没量到时的兜底）：内容层贴着底边，高度从"贴底一条"长到 100%。
   *
   * 只在 `morphUsable === false` 时才会走到这里 —— 正常情况（迷你条在、宿主已量到）
   * 一律走形变那条路。
   */
  private playLegacyExpandIntro(): void {
    try {
      // 逐元素淡入用**本页自持**的进度（1 = 贴底收起 → 0 = 完全展开），与高度补间同起同落。
      // ⚠️ 刻意不复用共享 `PlayerExpandState` 的 preparing/animating 相位：
      //    那套相位的置位点在重构中全丢了，接上去只会得到两种坏结果 ——
      //    「恒走非动画分支 → 淡入等于没写」或「标志残留 → 整块内容算成透明（封面先淡后消失、整页空白）」。
      //    本页自持 + 静止态恒返回 1，就不存在残留态。
      this.expandIntroRunning = true;
      this.getUIContext().animateTo({
        duration: PlaybackPage.EXPAND_DURATION_MS,
        curve: Curve.EaseInOut
      }, (): void => {
        this.collapseProgress = 0;
      });
      setTimeout((): void => {
        if (!this.isAlive) {
          return;
        }
        this.expandIntroRunning = false;
      }, PlaybackPage.EXPAND_DURATION_MS + 30);
    } catch (err) {
      // 补间起不来就立刻回到完整态；看门狗此时还没到点，别让页面停在"收起"那一条上
      const e = err as BusinessError;
      Logger.error(PlaybackPage.logTag, `expand animateTo failed code=${e.code} msg=${e.message}`);
      this.expandIntroRunning = false;
      this.collapseProgress = 0;
    }
  }

  /**
   * 容器形变路径的展开补间：几何在 `aboutToAppear` 已经压到起点（p = 0，
   * 也就是"迷你条那条胶囊"），这里只把它推到 1（铺满）。
   *
   * ⚠️ `animateTo` 补的是**属性值**（scale / translate / height / borderRadius / opacity），
   *    不是 `morphP` 本身 —— 所以闭包里只要把状态落到终点即可，中间帧由框架插值，
   *    所有绑在同一份状态上的属性会一起走同一条曲线。
   */
  private playMorphOpenIntro(): void {
    this.expandIntroRunning = true;
    this.expandState.morphDrive = MorphDrive.ANIM;
    // ★★ 2026-10-15（回退后重做）：**删掉原来"延后 50ms 再起补间"那一步**。
    //   它当年是为了绕开一个真实存在的坑：**V2 的状态变量是"异步标脏"（Promise 微任务），
    //   而 `animateTo` 会立刻刷新已标脏节点来决定动效首帧** —— 于是"先把几何压到起点、
    //   同一个任务里再起补间"时，压起点那一下**没生效**，首帧直接用旧值。
    //   官方（`arkts-new-applysync-flushupdates-flushuiupdates`）给的解法是
    //   `UIUtils.applySync(() => { … })`：同步刷新闭包内的状态变化，再起原来的动画。
    //   本方法配合 `tryStartMorphIntro` 里那层 `applySync` 使用 ——
    //   这也是"点击打开和手指拖动打开是两个动画"的结构性根因，50ms/重试/绘制门都是它的补丁。
    // ⚠️⚠️ 2026-10-17 纠正一处**我自己写错的注释**（它是下面那个 bug 的来源）：
    //   这里原来还写着「官方给的写法就是在 `animateTo` 的闭包里用 `UIUtils.applySync`
    //   同步刷新目标值」——**那是错的**。官方那个场景是
    //   「**动效之前**有额外修改 ⇒ 先 `applySync` 把**起点**落地，**再**起 `animateTo`」；
    //   而 **`animateTo` 闭包里只许写目标值**（写什么就补间到哪里）。
    //   把它放进闭包里 = 把目标值立刻刷出去 ⇒ **补间被跳过** ⇒ 直接跳终点。
    //   ⇒ 本文件里 `applySync` 的正确位置只有"补间之前"（见 :3158 / :3737 两处）。
    //   ⚠️ 世代号：收尾回调必须比对 `morphGen`（反编译里 `animGen++` + onFinish 校验），
    //    否则快速连点/收起会串状态。
    const gen: number = this.expandState.morphGen;
    try {
      this.getUIContext().animateTo({
        duration: PlaybackPage.MORPH_OPEN_DURATION_MS,
        curve: Curve.EaseInOut
      }, (): void => {
        // ★★★★ 2026-10-17（**用户第 1 条"点击打开无动画、直接到结束位置"的根因**）
        //
        // 这里原来是 `UIUtils.applySync((): void => { applyMorphProgress(1); })`。
        // **那是错的**：`applySync` 的语义是"**同步刷新**闭包内的状态变化"，
        // 官方（`arkts-new-applysync-flushupdates-flushuiupdates`）只在
        // **"起补间之前有额外修改"** 时用它把**起点**落地（本文件 :3158 那处就是正确用法）。
        // 放进 `animateTo` 的闭包里 ⇒ 目标值被**立刻刷出去** ⇒ **补间被跳过**
        // ⇒ 页面**直接跳到终点**（= 用户看到的"封面直接就到结束位置，没有动画"）。
        // 上游那份 `doEnter` 的补间 λ（`wujie.pa:51311-51329`）**只是把目标值写进去**
        // （`scaleValue/translateX/translateY/clipHeight` 的直接赋值）—— 没有任何"同步刷新"。
        // ⇒ 照上游：闭包里**只写目标值**，交给 `animateTo` 去补间。
        this.expandState.applyMorphProgress(1);
      });
    } catch (err) {
      // 补间起不来也要落到完整态，绝不能把播放页留在"迷你条那一小块"
      const e = err as BusinessError;
      Logger.error(PlaybackPage.logTag, `morph open animateTo failed code=${e.code} msg=${e.message}`);
      this.expandIntroRunning = false;
      this.expandState.morphSettleOpen();
      return;
    }
    setTimeout((): void => {
      if (!this.expandState.morphGenAlive(gen) || this.isClosing || !this.isAlive) {
        this.expandState.logMorphOwnership('open-finish-expired');
        return;
      }
      this.expandIntroRunning = false;
      // ★★ 2026-10-16（**同一条"不要在没有几何时落位"的规则**，见 `Index.settlePullOpen`）：
      //   这一句原来无条件落位。若本轮几何始终没量到（`morphGeomReady` 为假），
      //   `morphSettleOpen()` 内部的 `applyMorphProgress(1)` 会被那道门挡掉、
      //   而相位却翻成 OPEN ⇒ 容器停在恒等 + 相位 OPEN 的**半死状态**。
      //   ⇒ 按无界「量不到就退回普通 push(无形变)」的口径：只把相位收干净，不落位。
      if (!this.expandState.morphGeomReadyNow()) {
        this.expandState.pushMorphTrace('openNoGeom');
        this.expandState.morphReset();
        this.expandState.morphStage = MorphStage.OPEN;
        this.expandState.morphP = 1;
        this.expandState.measureGeometry(this.getUIContext(), true);
        return;
      }
      this.expandState.morphSettleOpen();
      // ★ 落位后**重量一次**几何：这一刻页面已经是原尺寸（scale=1、位移=0），
      //   量到的是干净的终点矩形；同时把 aside 的宽度刷新一遍（HDS 底栏排布可能变过）。
      //   ⚠️ 这一量只影响**下一轮**展开（不动本轮终点），所以它是"下一轮更准"的保险，
      //      不是本轮落位对不对的依据。
      this.expandState.measureGeometry(this.getUIContext(), true);
    }, PlaybackPage.MORPH_OPEN_DURATION_MS + 30);
  }

  /**
   * @returns 内容层高度百分比字符串。
   *
   * 进度 0 → `'100%'`（与没有动画时逐像素一致，这是最重要的性质）；
   * 进度 100 → `COLLAPSED_HEIGHT_PERCENT`（贴底一条，大致就是迷你条那一条的高度）。
   */
  private sheetHeightPercent(): string {
    // ⚠️ 容器形变（无界那套）期间**必须恒为 100%**：那套只靠"外层容器缩放 + 裁剪"完成展开，
    //    若这里同时按 collapseProgress 压缩内容层高度，就有两套动画在改同一片布局，
    //    表现为内容被压扁、封面错位。
    if (this.expandState.morphContainerActive()) {
      return '100%';
    }
    const p: number = Math.max(0, Math.min(100, this.collapseProgress));
    if (p <= 0) {
      return '100%';
    }
    const h: number = 100 - (100 - PlaybackPage.COLLAPSED_HEIGHT_PERCENT) * (p / 100);
    return h.toFixed(2) + '%';
  }

  /**
   * @returns 收起过程中是否要藏起标题/控件。
   *
   * 必须藏：内容被压扁到只剩一条时，固定高度的控制区会把封面挤成 0 高
   * （参考工程也是这么处理的 —— 它的 `isDismissPhase2HideMeta()` 一进二段就藏 meta）。
   */
  private isCollapsing(): boolean {
    // Morph dismiss keeps natural layout mounted; opacity/clip handles chrome continuously.
    return !this.expandState.morphContainerActive() && this.collapseProgress > 45;
  }

  /**
   * ★ 2026-10-17：上一次**真正下发成功**的常亮档位（`undefined` = 还没成功过 / 失败已回滚）。
   *
   * 照搬无界 `WindowInfo.setKeepScreenOn`（`design/animation/WindowInfo.ets`）的幂等判据：
   * ```ts
   *   setKeepScreenOn(on) {
   *     if (this.screenOn === on) return;                 // ★ 值没变就不下发（幂等）
   *     if (window === undefined) return;
   *     this.screenOn = on;
   *     window.setWindowKeepScreenOn(on).catch(λ2);       // ★ λ2：warn + `screenOn = false`（失败回滚）
   *   }
   * ```
   * ⚠️ **回滚那半条是关键**：若不回滚，失败之后缓存值与真实值不一致 ⇒ 下一次同值请求会被幂等门挡掉
   *   ⇒ **永远不再下发**（与本仓反复踩的"起手置真/收尾置假 不成对"同一个形状）。
   */
  private keepScreenOnApplied: boolean | undefined = undefined;

  /** Applies the keep-screen-on switch while the playback page is visible. */
  private applyKeepScreenOn(enabled: boolean): void {
    try {
      // 先算**真正要下发的值**（用户偏好与页面相位都要满足），再拿它做幂等判据
      // ⚠️ 顺序：必须在取 UIContext 之前（无界也是在判 window 之前先比 `screenOn`）。
      const keep: boolean = enabled && MusicStoreService.getInstance().getKeepScreenOn();
      if (this.keepScreenOnApplied === keep) {
        return;
      }
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (ctx === undefined) {
        return;
      }
      this.keepScreenOnApplied = keep;
      window.getLastWindow(ctx).then((win: window.Window): void => {
        // ★ 内层 promise 也要 catch：`setWindowKeepScreenOn` 本身返回 Promise，
        //   不接住就是一个未处理的 rejection（原来这里正是这样），而且失败时**必须回滚**。
        win.setWindowKeepScreenOn(keep).catch((_err: Object): void => {
          this.keepScreenOnApplied = undefined;
        });
      }).catch((_err: Object): void => {
        this.keepScreenOnApplied = undefined;
      });
    } catch (_err) {
      this.keepScreenOnApplied = undefined;
    }
  }

  /** Cover source for the current track: online url when available, else the local cover, else default. */
  private currentCoverSource(): string | Resource {
    const song = this.state.getCurrentSongItem();
    if (song !== undefined) {
      if (song.cover.length > 0) {
        // 在线封面 URL —— 与播放页封面（`PlayerViewModel.songCoverUrl()`）**同一来源**，
        // 续飞封面才不会出现"条形码里是封面、飞过来这张是默认头像"
        return song.cover;
      }
      // 本地/沙箱封面：`label` 是真正的封面 Resource（不是 `ic_avatar1`）
      return song.label;
    }
    return $r('app.media.ic_avatar1');
  }

  // ★★ 2026-10-15（第三十九轮 / Round 20）：原先挂在这里的整段 JSDoc 描述的是 `originalCoverSource()`
  //   （第三十七轮已删除，见 RzdMusic记忆.md §56.13），并且通篇引用 `backgroundImageSource()`
  //   （本轮已删除）⇒ 已是**孤儿注释**，整段清掉。
  //   ⚠️ `isPixelMapCover()` **仍然在用**（真实调用点：`releaseBackgroundCoverIfPixelMap()`），
  //   **不要跟着删**。

  // ★★ 2026-10-15（第三十九轮 / Round 20）：`backgroundImageSource()` **已删除** ——
  //   它自己的 JSDoc 就写明"唯一调用点是 phoneSwiperBackdropImage，而那个 builder 本身是死代码"
  //   ⇒ 随 `phoneSwiperBackdropImage` 一起下线，全仓零调用者。
  //   删除依据与产物符号自检（modules.abc GONE）见 RzdMusic记忆.md §56.15。

  /**
   * True when value looks like a decoded PixelMap ({@link Resource} has no release).
   *
   * ⚠️ 2026-10-15：背景改实时模糊后 `imageLabel` **恒为 `Resource`**（不再被赋成任何
   *   PixelMap）⇒ 本方法在调用点恒返回 false，实际已成**兜底守卫**。
   *   保留不删：`releaseBackgroundCoverIfPixelMap()` 仍靠它判类型（背景那条路已在
   *   第三十九轮随 `backgroundImageSource()` 一起下线，见 RzdMusic记忆.md §56.15），
   *   以后若有人重新把解码结果放进 `imageLabel`，这条分支会自动重新生效。
   */
  private isPixelMapCover(value: string | image.PixelMap | Resource): boolean {
    if (typeof value !== 'object' || value === null) {
      return false;
    }
    const probe = value as PixelMapReleaseProbe;
    return typeof probe.release === 'function';
  }

  /**
   * Releases native PixelMap backing if {@link imageLabel} is a decoded bitmap (not a Resource).
   *
   * ⚠️ 2026-10-15：**已不再会命中任何东西**（`imageLabel` 恒为 `Resource`，见
   *   {@link isPixelMapCover}）。两个调用点（`aboutToAppear` / `onDisAppear`）保留原样，
   *   因为这是一条**安全网**：万一以后又有人把位图塞进 `imageLabel`，它仍然会负责释放。
   *   ⚠️ 反面教训（本次改动顺带解决的）：以前背景层渲染的**正是**这里会被释放的那张
   *   PixelMap —— "先释放、再由 `@Local` 触发换源"中间隔着调度，属于潜在 use-after-free。
   */
  private releaseBackgroundCoverIfPixelMap(): void {
    if (!this.isPixelMapCover(this.imageLabel)) {
      return;
    }
    try {
      (this.imageLabel as image.PixelMap).release();
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(PlaybackPage.logTag,
        `background cover PixelMap.release failed, code=${err?.code}, message=${err?.message}`);
    }
  }

  /** Safe PixelMap.release for locals (blur/decoded temps). */
  private releasePixelMapQuiet(pm: image.PixelMap | undefined | null): void {
    if (pm === undefined || pm === null) {
      return;
    }
    try {
      pm.release();
    } catch (error) {
      Logger.warn(PlaybackPage.logTag,
        `pixelMap.release failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /** Restores system-bar colors; window layout stays non-full-screen. */
  private restorePlaybackWindowChrome(): void {
    const wu = WindowUtil.getInstance();
    wu.applyPlaybackNavigationBarColor(false);
    wu.applyPlaybackWindowChrome(false, false);
    if (this.isPcFreeWindowDecor()) {
      wu.applyPcPlaybackDecorButtonStyle(false);
    }
  }

  /**
   * 关闭全屏播放页：先播收起动画（进度 0 → 收起），播完再恢复窗口 chrome 并卸载。
   *
   * ⚠️ 卸载放在**定时器**里而不是 `animateTo` 的完成回调：那个回调在部分场景不保证触发，
   * 靠它卸载就会变成"返回键按了没反应"。定时器按时长兜底，最坏情况只是收起动画被跳过，
   * 关闭一定会发生。
   */
  private refreshCollapseGeometry(): void {
    if (this.expandState.morphStage !== MorphStage.OPEN) {
      return;
    }
    this.expandState.measureGeometry(this.getUIContext(), true, true);
    this.expandState.morphInitParams();
    this.expandState.freezeMorphMeta(this.getUIContext());
    this.expandState.logMorphOwnership('close-freeze-natural-open');
    Logger.info(PlaybackPage.logTag, 'collapse geometry refreshed while OPEN');
  }

  /**
   * ★★★★ 2026-10-17（照搬无界 `MainPage.closeWithAnimation()`，`wujie.pa:171054-171095`）：
   * **非手势关闭**（关闭按钮 / 系统返回）—— 缩的**不是活页面**，而是**一张满窗快照**。
   *
   * ## 无界的原文形状
   * ```
   *   closeWithAnimation() {
   *     if (pullMode && ExpandSnapshot.onReverseMorph(myMorphSnap)) return;   // ① 下拉那条路：自己处理
   *     getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, λ@1*#);     // ② 否则：拍快照
   *   }
   *   λ@1*#（wujie.pa:181020-181077）：
   *     失败 ⇒ hilog.warn('root snapshot failed, fallback: …') + nav.pop()    （无参 = 不带转场）
   *     成功 ⇒ ExpandSnapshot.onShrinkBack(pixmap, this.mySrcBox) + nav.pop(false)
   *   onShrinkBack → ShrinkOverlay.start(…)     ← 本仓的 MorphShrinkState
   * ```
   *
   * ## 为什么要照搬（用户第 ② 条「有背景但是高度特低」）
   * 我们一直是"动活的播放页"（改裁剪窗口 + 缩放）⇒ 只要两者不同步，屏上就是
   * "有背景、但只剩很矮的一条"。而**缩一张图**时背景与封面**同比例**，那种形状不可能出现。
   *   ⚠️ 下拉那条路**保留**活页形变（无界的 `onReverseMorph` 就是它）——
   *     用户已确认「②上拉打开/下拉关闭的封面+背景动画正常」，不动它。
   *
   * ## 本仓的映射
   * ```
   *   无界 pullMode            ←→ 本处"是不是从下拉那条路来的"：本方法**只被非手势入口调用**
   *                                 （见 `onCollapseRequested`），所以进来就是 ② 支。
   *   无界 PLAYER_ROOT_ID      ←→ 本页形变容器上的 `.id(PLAYER_ROOT_ID)`（照搬同一位置）
   *   无界 mySrcBox            ←→ `expandState.barWinX/Y/W/H`（迷你条胶囊的窗口矩形，vp）
   *   无界 nav.pop(false)      ←→ `state.isShowPlay = false`（壳层 `popPlayerRoute()` 用的是
   *                                 `pageIndexInfos.pop(false)` ⇒ 本就**不带转场**）
   *   无界失败支 nav.pop()     ←→ 同样置 `isShowPlay = false`（我们的 pop 恒无转场 ⇒ 等价）
   * ```
   *
   * ⚠️ `mySrcBox`（胶囊矩形）**只在形变会话建立时量到**（`reportMini` → `barWin*`）。
   *   量不到时 `MorphShrinkState.start` 会走无界那条 `start skipped: no srcBox` 支
   *   （`visible=false` + `onDone()`）⇒ 退化成"无动画关闭"，**与无界的退化路径一致**。
   *   排查关键字：`RzdShrinkOverlay` / `root snapshot failed`。
   */
  private closeWithAnimation(): void {
    if (this.isClosing) {
      return;
    }
    const winW: number = this.expandState.windowWidthVp;
    const winH: number = this.expandState.windowHeightVp;
    // ★★★ 2026-10-17（**必须现量一次胶囊矩形** —— 这是"返回关闭会不会变成无动画"的开关）：
    //   `barWinX/Y/W/H` 由 `measureGeometry()` 写，而它**只在两处**被调用：
    //     · 各条 opening 路径的补量（`measureMiniDuringPull` 内部那条链）；
    //     · **`refreshCollapseGeometry()`**（旧关闭路径在起手时现量一次）。
    //   ⇒ 若本条路上 `barWin*` 仍为 0（例如打开走的是退化路径、从没量到过），
    //     `MorphShrinkState.start()` 会走无界那条 `start skipped: no srcBox` 支
    //     ⇒ **返回关闭变成"无动画直接消失"**（那是可见回归，不是"没修好"那么轻）。
    //   ⚠️ 这里**直接调 `measureGeometry`**，不用旧的 `refreshCollapseGeometry()` ——
    //      后者自带 `morphStage === OPEN` 门（退化打开时会是 LANDING/NONE ⇒ 什么都不量），
    //      而快照路径**只需要胶囊矩形**（旧的 `morphInitParams`/`freezeMorphMeta` 是给
    //      活页补间用的，本路径不需要）。
    const measured: boolean = this.expandState.measureGeometry(this.getUIContext(), true, true);
    const srcBox: MorphShrinkRect = {
      left: this.expandState.barWinX,
      top: this.expandState.barWinY,
      width: this.expandState.barWinW,
      height: this.expandState.barWinH
    };
    // 关播放器这一下不要再自动收控制区（与 closeFullScreenPlayback 同一条）
    this.stopChromeAutoHide();
    this.isClosing = true;
    PlaybackPage.lastCloseAtMs = Date.now();
    // ★★★ 2026-10-17（**快照路径可用性预检** —— 见 `closeLiveMorphFallback` 的分歧说明）
    //   两个前提：① 胶囊矩形（`srcBox`）量到了；② 窗口尺寸有值（`MorphShrinkState.start`
    //   的两端公式都吃它）。任一不成立就直接走退化路径，**不去拍那张注定没用的快照**。
    if (srcBox.width <= 0 || srcBox.height <= 0 || winW <= 0 || winH <= 0) {
      this.closeLiveMorphFallback(
        `noSrcBox meas=${measured ? 1 : 0} bar=${srcBox.width.toFixed(0)}x${srcBox.height.toFixed(0)} ` +
        `win=${winW.toFixed(0)}x${winH.toFixed(0)}`);
      return;
    }
    PlaybackPage.ev('CLO', `snapshot p=${this.expandState.morphP.toFixed(2)} ` +
      `meas=${measured ? 1 : 0} bar=${srcBox.width.toFixed(0)}x${srcBox.height.toFixed(0)}`);
    Logger.info(PlaybackPage.logTag,
      `RzdShrinkOverlay closeWithAnimation: snapshot ${PLAYER_ROOT_ID} ` +
      `win=${winW.toFixed(0)}x${winH.toFixed(0)} ` +
      `bar=(${srcBox.left.toFixed(1)},${srcBox.top.toFixed(1)},` +
      `${srcBox.width.toFixed(1)}x${srcBox.height.toFixed(1)})`);
    // ⚠️ 快照必须在**形变开始之前**拍：此刻容器是恒等变换（满屏），拍到的才是"满屏那一张"。
    //   ⚠️⚠️ `restorePlaybackWindowChrome()` **不能**放在拍快照之前 —— 它会恢复窗口布局
    //     （`applyPlaybackWindowChrome(false,…)`，本项目在播放页会把窗口铺到整窗），
    //     布局一变，拍到的就不是"满窗那一张"。与旧路径一致：**收尾时才恢复**。
    // ⚠️⚠️ 2026-10-17（**用户截图暴露的真 bug**：事件日志 `CLO:… fb=snapFail` ⇒ 快照**每次都失败**，
    //   于是每一次返回关闭都退化到活页形变 ⇒ **用户从来没看到过无界那条快照收缩**，
    //   他报的"封面和背景还是一模一样的问题"就是这个）。
    //   根因：**我们调的是全局那个已废弃的重载**。`@ohos.arkui.componentSnapshot.d.ts`
    //   `function get(id, callback, options?)` 标着 **`@deprecated since 18`**、且会抛
    //   `100001 - Invalid ID`；而**上游用的是 `UIContext` 那一支**：
    //   `wujie.pa:171077-171093`（`PlayerPage.closeWithAnimation` 的 λ）逐条解出来正是
    //   ```ts
    //     this.getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID, λ@1*#)
    //   ```
    //   ⇒ 现在照上游那一条改写（本文件 L3464 的注释里**早就写着**这个形状，代码却没跟上）。
    //   ⇒ 失败原因照旧进事件日志，并**把 err.code 也带上**（`fb=snapFail(100001)`）：
    //     401 = 参数错 / 100001 = 找不到这个 id ⇒ 一次截图即可定论。
    this.getUIContext().getComponentSnapshot().get(PLAYER_ROOT_ID,
      (err: BusinessError, pixmap: image.PixelMap): void => {
      // ── 提交关闭时的**本仓特有收尾**（无界没有"沉浸窗口"这套，所以它没有这两句）
      //   ① 恢复系统栏/窗口 chrome —— 不恢复的话返回关闭之后顶栏会停在"播放页沉浸"那一套配色；
      //   ② `morphLand()` 交还绘制权 ⇒ 迷你条**真身**立刻显出来
      //      （不交还的话要等浮层淡出 ≈350ms 之后才看到迷你条"啪"地出现）。
      //   ⚠️ `morphLand()` 把相位置 `LANDING`，但此刻 `morphP = 1`（刚 `refreshCollapseGeometry`
      //      刷过）⇒ 容器 `.height(morphClipHeight)` = 整窗、`scale = 1` = **恒等**
      //      ⇒ 零观感变化；何况那 1~2 帧上面还盖着不透明的快照浮层。
      //   ⚠️ **失败支不进这一对**（它要走退化路径，那时 `morphLand()` 会把相位提前翻掉，
      //      而 `closeFullScreenPlayback()` 需要从"还在展开态"起手）⇒ 见下面 `if` 的位置。
      if (err !== null && err !== undefined) {
        Logger.warn(PlaybackPage.logTag,
          'RzdShrinkOverlay root snapshot failed, fallback: ' + JSON.stringify(err));
        // ★★★ 2026-10-17（**本仓刻意的分歧点**）：无界的失败支是 `nav.pop()`（无转场），
        //   我们这里退回**本仓既有的活页形变**（`closeFullScreenPlayback()`）。理由：
        //   · 无界拍的是 `PLAYER_ROOT_ID`（一个普通 Stack）；我们拍的是 **`NavDestination(DIALOG)`
        //     里的节点**，这条渲染路径是**我们特有的** ⇒ 一旦 `componentSnapshot` 在这条路上
        //     系统性取不到图，**每一次返回关闭**都会退化成"页面直接消失" ——
        //     那是比"背景只剩一条"严重得多的可见回归；
        //   · 活页形变本身是**已被用户确认可用**的那一套（②「上拉打开/下拉关闭的封面+背景动画正常」），
        //     退回去最坏也只是回到原来的观感瑕疵。
        //   ⚠️ 失败原因照旧打 `Logger.warn`，并把原因带进事件日志（`CLO` 的 `fb=`），
        //     **一次截图即可判读**（见 `closeFallbackReason`）。
        this.closeLiveMorphFallback(`snapFail(${err.code})`);
        return;
      }
      this.restorePlaybackWindowChrome();
      this.expandState.morphLand();
      const shrink: MorphShrinkState = this.morphShrinkState();
      shrink.start(this.getUIContext(), pixmap, srcBox, winW, winH, (): void => {
        // ★★★ 2026-10-17（照搬 `MainPage` 那个 **onDone λ@12*#**，`wujie.pa:154940-154949`）：
        // ```ts
        //   () => { this.miniHidden = false; this.shrinkPixmap = undefined; }
        // ```
        //   · `miniHidden = false` —— 本仓对应的是"迷你条**真身**可见"，
        //     那一步由本路径更早的 `morphLand()`（交还绘制权）负责，这里不重复；
        //   · `shrinkPixmap = undefined` —— ★ **必须做**：那是一张**满窗** PixelMap
        //     （1080×2400×4B ≈ 10MB 级），共享状态一直引用着它就不会被回收。
        //     上一版**漏了这一句** ⇒ 每关一次播放器就多留一张（直到下一次关闭才被覆盖）。
        Logger.info(PlaybackPage.logTag, 'RzdShrinkOverlay onDone (overlay hidden, pixmap dropped)');
        shrink.clearPixmap();
        // 浮层收尾（≈350ms）之后再放开闸门：正常路径下那时页面早已被 pop，
        // 这一句只是"万一没 pop 掉"的自愈（同失败支的理由）。
        this.isClosing = false;
      });
      PlaybackPage.ev('SQZ', `shrink win=${winW.toFixed(0)}x${winH.toFixed(0)}`);
      this.state.isShowPlay = false;
    });
  }

  /** 取得共享的快照收缩状态（与壳层 `Index` 同一个 AppStorageV2 实例）。 */
  private morphShrinkState(): MorphShrinkState {
    return AppStorageV2.connect(MorphShrinkState, AppStorageKeys.MORPH_SHRINK_STATE,
      () => new MorphShrinkState())!;
  }

  /**
   * ★★★ 2026-10-17：快照路径不可用时的**退化出口** —— 退回本仓既有的"活页形变"关闭。
   *
   * ## 这是与无界的**一处刻意分歧**（记在案，别再当作"没照搬"）
   * 无界 `λ@1*#`（`wujie.pa:181020-181077`）在快照失败时是 `nav.pop()`（**无参 = 不带转场**），
   * 也就是"页面直接消失"。我们**不**照搬那一条，理由两条：
   * 1. 拍的对象不同：无界拍 `PLAYER_ROOT_ID`（一个普通 `Stack`），我们拍的是
   *    **`NavDestination(DIALOG)` 里的节点** —— 这条渲染路径**是我们特有的**；
   *    一旦 `componentSnapshot` 在这条路上系统性取不到图，**每一次返回关闭**都会退化成
   *    "页面直接消失"，那是**比"背景只剩一条"严重得多**的可见回归；
   * 2. 活页形变是**用户已确认可用**的那一套（确认清单 ②「上拉打开/下拉关闭的封面+背景动画正常」），
   *    退回去最坏也只是回到原来那点观感瑕疵。
   *
   * ## 触发条件（两处调用点）
   * · `closeWithAnimation()` 的**预检**：胶囊矩形 / 窗口尺寸任一不可用（`bar=0x0`），
   *   此时连快照都不去拍（拍了也没用）；
   * · 快照回调的**失败支**（`err` 非空）。
   *
   * ## 可读性
   * 原因写进静态 `closeFallbackReason`，由 `closeFullScreenPlayback()` 的 `ev('CLO', …)`
   * 一起打进事件日志（徽标第十三行的 `fb=`）⇒ **一次截图就能看出走没走退化**。
   * @param reason 退化原因（短标签，会进事件日志）
   */
  private closeLiveMorphFallback(reason: string): void {
    Logger.warn(PlaybackPage.logTag,
      `RzdShrinkOverlay fallback → live morph (${reason})`);
    PlaybackPage.closeFallbackReason = reason;
    // `closeFullScreenPlayback()` 的第一道闸就是 `isClosing`，必须放开才进得去。
    this.isClosing = false;
    this.closeFullScreenPlayback();
  }

  private closeFullScreenPlayback(): void {
    if (this.isClosing) {
      return;
    }
    // ★★★ 2026-10-16（**给"关闭余波窗口"盖章 —— 这一行是上一轮漏掉的**）
    //   见 `lastCloseAtMs` 的注释：内容层 `.onAppear()` 的兜底分支靠它判断
    //   "这一次出现的节点是不是刚才那次关闭的余波"。**只在这里写、那里读**，
    //   两处成对（上一轮只有读、没有写 ⇒ 门恒假）。
    PlaybackPage.lastCloseAtMs = Date.now();
    // ★ 时序黑匣子：本次关闭开始（见 `evLog` 的注释）
    //   ★ 2026-10-17：`fb=` = 这一次是**从快照路径退化过来的**（见 `closeFallbackReason`），
    //   读完即清 ⇒ `fb=` 空 = 走的快照路径；`fb=snapFail` / `fb=noSrcBox …` = 走了活页形变。
    const fb: string = PlaybackPage.closeFallbackReason;
    PlaybackPage.closeFallbackReason = '';
    PlaybackPage.ev('CLO', `gen=${this.closeGen + 1} p=${this.expandState.morphP.toFixed(2)}` +
      (fb.length > 0 ? ` fb=${fb}` : ''));
    // ★★ P0-2：本轮关闭的**独立代次** + 取消上一轮可能还挂着的卸载定时器。
    //   `isClosing` 挡得住"收起动画进行中"的重入，但它在 `morphCloseMs + 20`（≈370ms）
    //   就被清回 `false`，而那一刻播放页**可能还没 unmount** ⇒ 第二次点击会再起一条
    //   350ms 补间 + 第二个卸载定时器，而两条链的 `morphGen` 相同 ⇒ `morphGenAlive` 拦不住。
    //   有了 `closeGen` + 句柄，第二次点击要么被明确忽略、要么干净接管。
    const closeGen: number = this.closeGen + 1;
    this.closeGen = closeGen;
    if (this.closeSettleTimer !== -1) {
      clearTimeout(this.closeSettleTimer);
      this.closeSettleTimer = -1;
    }
    this.refreshCollapseGeometry();
    this.isClosing = true;
    // 正在收起播放器时不要再自动收控制区（两个动画叠一起会很乱）
    this.stopChromeAutoHide();
    // 关闭期间进度会停在"收起"几百毫秒，别让展开看门狗把它抢回完整态
    if (this.collapseWatchdogTimer !== -1) {
      clearTimeout(this.collapseWatchdogTimer);
      this.collapseWatchdogTimer = -1;
    }
    // ★ 走的是形变路径就**反向跑同一套几何**：整页缩回迷你条那一小块、裁剪窗口收回去，
    //   最后落回迷你条（LANDING）。展开/收起就是同一套参数的正反两遍，任意时刻都自洽。
    //   ⚠️ 判定用 `morphUsable` 而**不是** `morphContainerActive()`：稳定展开态的相位是
    //      OPEN（不是 ENTERING/LEAVING），用后者判定会掉回"压扁内容层高度"的老动画 ——
    //      用户实测到的「用系统返回关闭还是旧动画」就是这里。
    if (this.expandState.morphUsable) {
      // ★★★ 2026-10-16（**收起这一侧也要过"几何就绪"那道门**）：
      //   本轮给 `applyMorphProgress` 加了一道无界的门（`morphGeomReady`，见那个字段的注释）：
      //   几何没就绪时它**什么都不做**。打开这条路靠 `measureMiniDuringPull` 置位，
      //   而"点击关闭 / 系统返回关闭"是从**已经落位的打开态**往回跑 —— 正常应当已置位；
      //   但异常路径（打开时补量失败过一次、`morphReset` 之后又进来…）会让它是假，
      //   那时下面那 460ms 的收起补间就是**整段空转** =
      //   用户实测的「点击关闭 / 系统返回 没有封面/背景动画」。
      //   ⇒ 这里用打开态已有的端点几何兜底放行（无界的收起本来就不重新量终点）。
      if (!this.expandState.ensureMorphGeomForClose()) {
        Logger.warn(PlaybackPage.logTag,
          'close: geometry unresolved on both ends ⇒ close without morph animation');
      }
      // ★★ 2026-10-15（照搬无界：**关闭时长与缓动**）——
      //   **这一处就是用户实测「关闭播放器几乎没动画」的真根因。**
      //   无界"关闭提交"（quit）分支（`_recover/logic-src/开关播放器-手势路径定稿.md`
      //   §0 速查表 L27/L29，常量表 §八 L620-633）：
      //     `reverseMs = round(REVERSE_MS(460) × max(REVERSE_MIN_RATIO(0.4), morphT))`
      //     `animateMorphT(reverseMs, t = 0, REVERSE_EASING)`
      //     `REVERSE_EASING = cubic-bezier(0.85, 0, 0.5, 0.88)`   ← ★ **慢启动**
      //   ⚠️ 我们原来是 **350ms + `cubicBezier(0.23, 1.0, 0.32, 1.0)`**，而那条
      //      （`EASE_OUT_STR`）是**打开提交**用的：**前 15% 时间就走完约 70% 行程**
      //      ⇒ 350ms 里约 50ms 就缩完了、剩下 300ms 几乎什么都没发生 ——
      //      用户感知就是"**关闭几乎没动画**"：不是没播，是**一眨眼就没了**。
      //   ⇒ 两处都按无界改：时长 `460 × max(0.4, morphT)`、缓动 **`REVERSE_EASING`**。
      //      下界 `460×0.4 = 184ms` 保证"只拉开一点点就松手"时也还有个像样的收势。
      //   ⚠️ **别把两条缓动搞混**（定稿 §八 L385 原文：「`REVERSE_EASING` 只在
      //      '提交关闭(quit)'这一支用；**取消回弹反而用 `EASE_OUT_STR`**」）：
      //        · 打开提交 / 打开取消 → `EASE_OUT_STR`
      //        · **关闭提交 → `REVERSE_EASING`**
      //        · 关闭取消（回弹）→ `EASE_OUT_STR`
      //   ⚠️ 进度必须在 `morphBeginLeaving()` **之前**取（下面那个 `applySync` 里会改相位）。
      const closeFromT: number = this.expandState.morphP;
      // ★★★★ 2026-10-17（两个外部模型会诊后**共同指向**的那一条，加了护栏）：
      //
      // ## 症状
      // 「系统返回 / 关闭按钮 / 下拉松手：封面**直接下去 / 直接到小圆形**，没有独立飞行那一棒」
      // ## 机制
      // 收起补间的起点是**浮层自己的进度** `morphOverlayP`，而它在下面这种情形里是 **0**：
      //   · 打开那一棒的浮层补间没飞起来（例如被 `hostsMorphOverlay` / 早退挡掉），
      //     或 `morphOverlayReset()` 把 P 压回 0 之后就再没被推上去；
      // ⇒ 于是 `morphOverlayTweenTo(false)` 拿到 `from = 0`、`to = 0`
      //   ⇒ 被 `|to - from| < 1e-4` **早退**（连 animateTo 都不建）
      //   ⇒ 而 `morphOverlayBridging()` 的相位兜底分支**仍然为真**
      //     （`morphContainerActive() && snapStartW > 0 && endCoverSize > 0`）
      //   ⇒ 克隆层**整段关闭都画在 `morphCoverRectAt(0)` = 迷你条那个小圆**上，一动不动。
      //
      // ## 修法（护栏版：**只在"确实没飞过"时**对齐，绝不打断正在飞的进度）
      // 若浮层进度仍停在 0、而页面当前进度 > 0 ⇒ 把它对齐到页面进度
      // （= 已有的 `syncMorphOverlayFromPage()`，语义正是"浮层进度 := 页面进度"），
      // 这样收起补间就有了真实起点（例如 1 → 0），一镜到底才成立。
      // ⚠️ **不能无条件对齐**：若浮层正在 1（大封面位置）而页面已被手指拖到 0.05，
      //   无条件对齐会让克隆层**从大封面瞬间跳到迷你条** = 一次可见的跳变。
      if (this.expandState.morphOverlayProgress() <= 0.001 && closeFromT > 0.001) {
        this.expandState.syncMorphOverlayFromPage();
        PlaybackPage.ev('OVA', `align overlayP=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
          `to p=${closeFromT.toFixed(3)}`);
      }
      // ★ 先把"进入收起相位 + 冻结几何"同步刷出去：这一段是补间**之前**的额外修改，
      //   按官方规则必须用 `applySync` 同步标脏，否则补间首帧会用旧值。
      UIUtils.applySync((): void => {
        // ★ 2026-10-17（**用户 08:46 截图里那条矛盾的定性用**）：
        //   那一张日志是 `CLO:gen=1 p=1.00` 紧接着 `LV:anim from=0.00`
        //   —— 两行读的是**同一个字段** `morphP`，中间**没有任何写入**
        //   （`morphP` 全仓只有 3 个写入点：`pullOpenBegin` 的失败支 / `applyMorphProgress` /
        //     `morphReset`，都不在 `closeFullScreenPlayback` 这条直线上）。
        //   ⇒ 只剩两种可能，必须一次读数分开：
        //     ① 两行**不是同一次关闭**（事件缓冲是静态的、按字符裁切，
        //        理论上可能混入另一次关闭的 `LV`）⇒ 把 **`closeGen`** 打进来即可判定
        //        （`CLO` 那行本来就有 `gen=`）；
        //     ② `morphP` 真的在这两行之间被改了 ⇒ `pNow=`（**此处**重新读一次）与 `from=`
        //        会同时为 0，而 `CLO` 那行是 1.00。
        PlaybackPage.ev('LV', `anim gen=${this.closeGen} from=${closeFromT.toFixed(2)} ` +
          `pNow=${this.expandState.morphP.toFixed(2)}`);
        this.expandState.morphBeginLeaving();
      });
      const closeScale: number = closeFromT < PlaybackPage.REVERSE_MIN_RATIO ?
        PlaybackPage.REVERSE_MIN_RATIO : closeFromT;
      const morphCloseMs: number = Math.round(PlaybackPage.REVERSE_MS * closeScale);
      // ★★★ 2026-10-17（照搬无界 `MorphGuard.animateMorph` 的第一句）：起补间之前把"配色安静窗口"
      //   推到**这条补间结束**（`quietMs` 就是这条补间自己的时长 —— 无界那侧也是按调用点传的，
      //   例如 `closeSearchMorph` 传 `SP_SEARCH_SETTLE_MS`，本处没有任何新造常量）。
      //   ⇒ 关闭动画跑着的时候，换歌/取色完成的"上色"一律往后挪，不会在动画中途跳色。
      this.expandState.markMorphQuiet(morphCloseMs);
      // ★★ 浮层那一棒（壳层 `MorphCoverClone` 的续飞封面）**必须由本处同步驱动** ——
      //   依据见 `PlayerExpandState.applyMorphProgress` 里"删掉自动复位"那段 + 用户实测的
      //   「下拉关闭时封面动画是展开那一套」「系统返回关闭没有封面动画」。
      //   ⚠️ 原来只靠壳层 `@Monitor('expandState.morphStage')`：V2 的 `@Monitor` 是**异步**回调，
      //      而本函数的收尾定时器（`morphCloseMs + 20`）里会连着走
      //      `morphLand()` → `morphReset()`（后者**同步**把 `morphOverlayP` 清 0）——
      //      只要 `@Monitor` 的回调排在复位之后，封面那一棒就**整段没播**。
      //      这里在起补间之前**同步**喊一声，顺序就不再取决于微任务调度。
      //   ⚠️ 浮层那条补间**已经在跑**时不要抢（`overlayTweenAnimating()`）：
      //      上拉/回弹那条由壳层 `settlePullOpen` 发起，方向与本次一致，抢过来只会打断它。
      //      （`focusMorphOverlayForPageCollapse` 内部还有一层"本轮只许起一次"的幂等护栏，
      //        因为壳层的 `@Monitor` 也会调它 —— 见该函数的注释。）
      this.expandState.focusMorphOverlayForPageCollapse(this.getUIContext());
      Logger.info(PlaybackPage.logTag,
        `RzdMorph close tween from morphT=${closeFromT.toFixed(3)} ⇒ ${morphCloseMs}ms ` +
        `(=REVERSE_MS ${PlaybackPage.REVERSE_MS} × max(REVERSE_MIN_RATIO ${PlaybackPage.REVERSE_MIN_RATIO}, morphT)) ` +
        `easing=REVERSE_EASING(0.85,0,0.5,0.88) overlayP=${this.expandState.morphOverlayProgress().toFixed(3)} ` +
        `overlayAnimating=${this.expandState.overlayTweenAnimating()} ` +
        `coverClone=${this.expandState.morphOverlayBridging()} ` +
        `realCover=${this.expandState.realCoverVisible()}`);
      const gen: number = this.expandState.morphGen;
      this.getUIContext().animateTo({
        duration: morphCloseMs,
        curve: curves.cubicBezierCurve(0.85, 0, 0.5, 0.88)
      }, (): void => {
        // ★★★★ 2026-10-17（**用户第 2、3 条"关闭无动画、封面直接下去"的根因**）
        //   与 `playMorphOpenIntro` 那一处**完全同一个错误**（同一形状第 2 处）：
        //   原来是 `UIUtils.applySync(() => applyMorphProgress(0))` —— 在 `animateTo` 的闭包里
        //   同步刷新目标值 ⇒ **补间被跳过** ⇒ 封面直接落到终点（"直接下去了 / 直接到小圆形"）。
        //   上游关闭那一侧（`animateMorphT(reverseMs, 0, REVERSE_EASING)`）同样只写目标值。
        //   ⚠️ 起点（相位 + 冻结几何）那一段**仍然**用 `applySync`（见本函数上面那处 :3729）——
        //     那是"补间之前"的正确用法，**不要**一起删掉。
        this.expandState.applyMorphProgress(0);
      });
      this.closeSettleTimer = setTimeout((): void => {
        this.closeSettleTimer = -1;
        if (!this.isAlive) {
          // ★★★ 2026-10-17（**用户第 ② 条「有背景但是高度特低」的头号嫌疑就在这里**）。
          //
          // ## 原来这里是"直接 return"，什么收尾都不做
          // ```ts
          //   if (!this.isAlive) { ev('SET','dead'); return; }   // ← 旧写法
          // ```
          // 于是几何**永远停在补间跑到的那个位置**：相位还是 `LEAVING`
          // ⇒ `morphContainerActive()` 真 ⇒ `morphClipping()` 真
          // ⇒ 容器 `.height()` 吃的是 `morphClipHeight`（≈ 迷你条那一份，几十 vp）
          // ⇒ **整页只画出很矮的一条**，而背景（`MeshCoverBg`）是容器的子节点
          // ⇒ 屏上就是用户说的「有背景但是高度特低」。
          //
          // ## 为什么"页面死了"反而更需要收尾
          // 这一支的含义是"收尾定时器醒来时页面已经卸载了"，而**几何是共享的**
          // （`PlayerExpandState` 挂在 AppStorageV2 上）⇒ 页面没了、几何还歪着，
          // 下一次打开就是从这一份歪几何起手。
          //
          // ⇒ 与下面那条"世代号早退支"**对齐成同一个形状**（那条本来就是对的）：
          //   翻相位 + 卸载。⚠️ 仍然**不调 `morphReset()`** —— 这里没有可靠的
          //   "页面已经下台"判据，而 `morphReset()` 会在页面还在屏上时把容器复位成满屏
          //   （那就是用户第 ③ 条）。复位的正确时机见 `scheduleMorphResetAfterPop()`。
          PlaybackPage.ev('SET', `dead→LND+POPT p=${this.expandState.morphP.toFixed(2)}`);
          this.isClosing = false;
          this.expandState.morphLand();
          this.state.isShowPlay = false;
          return;
        }
        // ★ P0-2：本轮关闭已被"下一次关闭请求"取代 ⇒ 收尾交给那一轮，这里什么都不做
        if (closeGen !== this.closeGen) {
          PlaybackPage.ev('SET', `genWait`);
          return;
        }
        // 与上一条**都要**：`closeGen` 挡"重复关闭"，`morphGenAlive` 挡"关闭途中又被展开"
        if (!this.expandState.morphGenAlive(gen)) {
          // 这一轮收起已经被新的形变会话取代（世代号变了）：本轮作废。
          //
          // ★★ 2026-10-15 补漏（用户实测「**没法下拉关闭播放器**」+「关闭播放器几乎没动画」）：
          //   本轮的收起既然作废，就必须**把 `isClosing` 放掉**。它只在下面那条正常收尾里被清，
          //   而这条早退路径**没有任何人会再清它** ⇒ 卡在 `true` 之后：
          //     · `onDismissDrag()`（本文件第 567 行）第一行就 `if (this.isClosing) return;`
          //     · `closeFullScreenPlayback()`（第 1779 行）同样第一行就 return
          //   ⇒ **下拉收起与关闭按钮双双永久失效**，而且屏上没有任何动画
          //     （观感正是"关闭播放器几乎没动画"—— 因为关闭**根本没启动**）。
          //   只有下次重新进播放页（新实例）才会"自己好了"，所以这个 bug 很容易被当成偶发。
          //   ⚠️ 上面 `closeGen !== this.closeGen` 那条**不能**这样清：那是"新一轮关闭已接管"，
          //      标志归那一轮管（它走到这里时会自己清，链式自愈）。
          Logger.warn(PlaybackPage.logTag,
            `RzdMorph close aborted by new morph session gen=${gen} ` +
            `liveGen=${this.expandState.morphGen} stage=${this.expandState.morphStage} ` +
            `⇒ release isClosing + finish the close`);
          this.isClosing = false;
          // ★★★ 2026-10-16（**"点击关闭 / 系统返回"这一条的最后一块**）：
          //   上面那条早退**只放开了 `isClosing`，没有推进"关闭"这件事本身**
          //   ⇒ 播放页会**永远留在屏上**（用户点关闭之后屏上什么都没发生）。
          //   为什么走到这里：收起过程中若 `morphGen` 被 `morphReset()` 清过一次
          //   （典型来源：播放页自身的 `onDisappear` / 迷你条侧卸载 / 上一轮残留清理），
          //   世代号就与本轮捕获的不同 —— 而**这并不代表"用户不想关了"**。
          //   ⇒ 本轮既然是"要关"，就把关闭推到底：
          //     ① 直接落位（`morphLand()`，与正常收尾同一步）；
          //     ② 卸载播放页（`isShowPlay=false`）——
          //        相位与几何的清理由**卸载链自己的** `onDisappear → morphReset()` 负责，
          //        这里**不重复调**（重复调会再多推一次 `morphGen`，制造下一轮的同类问题）。
          //   ⚠️ 幂等/安全：`isShowPlay` 若已是 false，`@Monitor` 不会重复动作；
          //      `morphLand()` 在非形变态是安全的空操作语义（只翻相位 + 交还所有权）。
          this.expandState.morphLand();
          this.state.isShowPlay = false;
          PlaybackPage.ev('SET', `genBAD→LND+POPT`);
          return;
        }
        PlaybackPage.ev('SET', `ok gen=${closeGen}`);
        this.isClosing = false;
        this.restorePlaybackWindowChrome();
        // LANDING：此刻播放页已经缩成透明的一小块，把迷你条交还给它
        // （`miniBarOpacity()` 在非 ENTERING/LEAVING 时恒为 1），再卸载。
        this.expandState.morphLand();
        PlaybackPage.ev('LND');
        // ★★ 2026-10-15（照搬无界 `squashLand`）：**落位那一帧起"播放条挤压 → 回弹"**。
        //   顺序和无界逐字一致：`setMorph(LANDING)`（=`morphLand()`，本帧播放页停笔、
        //   迷你条真身显出来）→ `animateSquash(SQUASH_Y 0.86, 110ms)` → 320ms 过冲回弹。
        //   ⇒ 用户实测的「无界关闭时播放条会弹一下」就是这一对补间。
        //   ⚠️ 必须在 `morphLand()` 之后：早一帧就是"播放页还在画、条先弹"。
        //   ⚠️ **2026-10-17 订正**：这一句原来接着写"与 `morphReset()` 的顺序不能反"。
        //      现在 `morphReset()` 已经**不在这里**了（改成"等 pop 之后"，
        //      见下面那段说明与 `scheduleMorphResetAfterPop()`）——
        //      所以它与 `squashLandAnim()` 之间不再有顺序问题。
        //      ⚠️ 但 `morphReset()` **仍然不碰** `morphSquashY`（挤压是独立的一条标量），
        //      所以那一棒在复位之后照样会把 0.86 弹回 1：**这是要的**（无界的落位回弹）。
        this.expandState.squashLandAnim(this.getUIContext());
        PlaybackPage.ev('SQZ');
        this.state.isShowPlay = false;
        PlaybackPage.ev('POPT',
          `stage=${this.expandState.morphStage} p=${this.expandState.morphP.toFixed(2)}`);
        // ★★★ 2026-10-17（**用户第 ③ 条「突然来个展开播放器的动画」的机制级修法**）。
        //
        // ## 原来这里是"同一 tick 里同步 morphReset()"，为什么那是错的
        // ```ts
        //   this.state.isShowPlay = false;   // → 壳层 @Monitor（V2 异步）→ popPlayerRoute()
        //   this.expandState.morphReset();   // ← 同步，紧跟其后
        // ```
        // `morphReset()` 会把 `morphStage` 清成 `NONE`、`morphP` 复位成 1、
        // `morphClipHeight` 清零、`morphScale` 复位成 1
        // ⇒ `morphContainerActive()` 翻假 ⇒ 容器**不裁剪、不缩放、不位移** = **满屏播放页**。
        // 而路由要到**下一帧**才被 `pop(false)` 摘掉（`@Monitor` 派发一层 + 布局摘除一层）
        // ⇒ 中间那 1~2 帧屏上就是：
        // ```
        //   已经缩成小圆点（LANDING，被裁在迷你条那么高） → 突然满屏播放页 → 消失
        // ```
        // 观感正是用户说的「动画结束了**突然来个展开播放器的动画**」。
        //
        // ## 修法：**等页面真的下台再复位几何**
        // 落位（`morphLand()`）已经把绘制权交还给迷你条了，那一份"被裁在迷你条那么高"的
        // 几何**在页面下台之前是完全正确的显示状态**（用户看到的就是迷你条）——
        // 所以复位**没有任何理由**抢在 pop 前面做。
        // ⚠️ 但也不能不做：几何是共享的，不复位会污染下一轮（见 `morphGenAlive` 那道门）。
        // ⇒ 交给 `scheduleMorphResetAfterPop()`：**轮询到"播放页路由已经不在栈里"才复位**，
        //   并带"新一轮会话已接管就不许清"的双守卫。
        this.scheduleMorphResetAfterPop(closeGen, this.expandState.morphGen, 0);
      }, morphCloseMs + 20);
      return;
    }
    // 没有可靠几何时直接关闭，绝不回退到压扁内容层的旧转场。
    Logger.warn(PlaybackPage.logTag, 'collapse without geometry: immediate landing');
    PlaybackPage.ev('CLO', 'noGeom');
    this.isClosing = false;
    this.restorePlaybackWindowChrome();
    this.state.isShowPlay = false;
    PlaybackPage.ev('POPT', 'noGeom');
    // ★ 同"正常收尾支"：复位几何必须**等页面真的下台**（见 `scheduleMorphResetAfterPop`）。
    this.scheduleMorphResetAfterPop(this.closeGen, this.expandState.morphGen, 0);
    // 兜底路径也要弹一下：否则"几何没量到"时这条唯一的收起反馈就整个没有
    this.expandState.squashLandAnim(this.getUIContext());
  }

  /** 上次 `logBranchSurface()` 打过的签名（用来把重复重绘压成一条；见该方法注释）。 */
  private lastBranchLog: string = '';

  /**
   * ★★ 2026-10-15（目标 ④ 的**分支归属诊断 + 版面不变量自检**）：把"现在到底走的哪一条分支 +
   * 那一支的实测几何 + **不变量是否成立**"打出来。
   *
   * ## 为什么需要它
   *
   * 本页的布局是**三条分支**（`buildControlStack()`）：
   * ```
   *   panel（面板）  ← usePanelLayout()
   *   wide（宽屏/平板）← 非 SM 且非（MD + HEIGHT_SM）
   *   phone（手机）  ← 其余
   * ```
   * 而**只有手机形态在本机可构造** ⇒ 宽屏/平板/横屏/PC 那两条**从来没被验过**。
   * 等拿到那些形态时，第一件要知道的事是"**它到底走了哪一支**"——
   * 因为三条分支的**封面渲染者不同**（phone = 覆盖层 `LyricFloatLayer`；wide/panel = `MusicPlayInfoBlock`），
   * 一旦分支判据与预期不符，症状会表现为"封面位置很奇怪"，而根因其实是"走错了支"。
   *
   * ## 不变量自检（`inv=` 那一列）—— 把"看着不对"变成"日志直接说不成立"
   *
   * | 标记 | 断言 | 不成立说明什么 |
   * | --- | --- | --- |
   * | `coverNone` | 封面节点量得到 | 那一支没把 `PLAYER_BIG_COVER_ID` 挂上 ⇒ 宽度/端点链会退化 |
   * | `coverSquare` | 封面宽高差 ≤ 1vp | 封面被压扁（`constraintSize` / `layoutWeight` 抢了空间）⇒ 续飞封面落位会跳 |
   * | `metaGapOk` | 歌名顶边 ≥ 封面底边 − 1vp（不重叠） | **歌名压在大封面上** ⇒ 用户报的"错位"的一种 |
   * | `metaOrder` | 歌手顶边 ≥ 歌名顶边（歌手在歌名**下面**） | 两行顺序反了 |
   * | `metaInWin` | 歌名/歌手底边 ≤ 窗口高 | 歌名被挤出屏幕（历史上"偏低 164vp"那个 bug 的形状） |
   * | `miniClear` | 小歌词顶边 ≥ 歌手底边（**小歌词不与歌名重叠**） | ★ 这正是用户报的「播放界面错位」（§57 用 `MINI_LYRIC_SINK_VP=44` 修的） |
   * | `branchSane` | 同一屏**只有一支**（`usePanel` 与 `phoneSwiper` 不同时把同一块内容托付给两种结构） | 判据重叠区被踩到 ⇒ 先修判据再谈布局 |
   *
   * ## 它从哪儿被调（★ 这一段本身是个实测结论）
   *
   * ⚠️ **不能直接写在 `@Builder` 体里** —— 本轮实测编译报错：
   *   `'this.logBranchSurface('wide')' does not meet UI component syntax`
   *   （ArkTS 的 `@Builder` 体只接受 **UI 组件语法**）。
   * ⇒ 现在挂在**三条分支各自的根容器**的 `.onAppear()` 上 —— 那一支**首次挂载**时触发一次，
   *   手机↔宽屏↔面板互相切换时各来一次（形变期间不会触发）。
   *   目前挂了三处：宽屏那支的 `Column`、手机那支的 `Swiper`、面板那支的根 `Stack`。
   *   `branch` 参数由**各调用点自己声明**（它字面上就知道自己是谁）。
   *
   * ## 为什么可以直接写在 `@Builder` 里
   *
   * （此条已作废 —— 见上。`@Builder` 体只接受 UI 组件语法，所以挂在 `.onAppear()`。）
   *
   * 排查关键字：`hdc shell hilog -x | Select-String 'RzdBranch'`
   * ⚠️ 只读：不写任何状态（`lastBranchLog` 只是日志节流用的字符串）。
   * @param branch 当前分支名（'phone' / 'wide' / 'panel'）
   */
  private logBranchSurface(branch: string): void {
    const rectOf = (id: string): LyricMorphRect | undefined => {
      try {
        const node = this.getUIContext().getFrameNodeById(id);
        if (node === null) {
          return undefined;
        }
        const p: Position = node.getPositionToWindowWithTransform();
        const s: Size = node.getMeasuredSize();
        return {
          x: areaLengthToVp(p.x),
          y: areaLengthToVp(p.y),
          size: this.getUIContext().px2vp(s.width),
          height: this.getUIContext().px2vp(s.height),
          radius: 0
        };
      } catch (err) {
        return undefined;
      }
    };
    const fmt = (r: LyricMorphRect | undefined): string => r === undefined
      ? 'none'
      : `(${r.x.toFixed(0)},${r.y.toFixed(0)},${r.size.toFixed(0)},${r.height.toFixed(0)})`;
    const cover: LyricMorphRect | undefined = rectOf(PLAYER_BIG_COVER_ID);
    const title: LyricMorphRect | undefined = rectOf(PLAYER_META_TITLE_ID);
    const singer: LyricMorphRect | undefined = rectOf(PLAYER_META_SINGER_ID);
    const lyric: LyricMorphRect | undefined = rectOf(PlaybackPage.MINI_LYRIC_BOX_ID);
    // ───────── 不变量自检（全部是"不成立才说话"的形式，避免日志里一堆 true） ─────────
    const bad: string[] = [];
    if (cover === undefined) {
      bad.push('coverNone');
    } else if (Math.abs(cover.size - cover.height) > 1) {
      bad.push(`coverSquare(${cover.size.toFixed(0)}x${cover.height.toFixed(0)})`);
    }
    if (cover !== undefined && title !== undefined && title.y < cover.y + cover.height - 1) {
      bad.push(`metaGapOk(title.y=${title.y.toFixed(0)}<cover.b=${(cover.y + cover.height).toFixed(0)})`);
    }
    if (title !== undefined && singer !== undefined && singer.y < title.y) {
      bad.push('metaOrder(singer above title)');
    }
    const winH: number = this.expandState.windowHeightVp;
    if (winH > 0 && singer !== undefined && singer.y + singer.height > winH) {
      bad.push(`metaInWin(singer.b=${(singer.y + singer.height).toFixed(0)}>${winH.toFixed(0)})`);
    }
    // ★ 这条就是用户报的「播放界面错位」的机器判据（§57 用 MINI_LYRIC_SINK_VP 修的那条）。
    if (lyric !== undefined && singer !== undefined && lyric.y < singer.y + singer.height - 1) {
      bad.push(`miniClear(lyric.y=${lyric.y.toFixed(0)}<singer.b=${(singer.y + singer.height).toFixed(0)})`);
    }
    // 判据重叠区：MD + 横屏时 usePanelLayout() 与 usesPhoneSwiperLayout() 可能同时为真。
    // 现在靠 `if` 顺序兜住（面板胜出）⇒ 只要"面板支里还认为自己是 phoneSwiper"，就是隐患。
    const panel: boolean = this.usePanelLayout();
    const phoneSwiper: boolean = this.usesPhoneSwiperLayout();
    if (panel && phoneSwiper && branch !== 'phone') {
      bad.push('branchSane(panel∩phoneSwiper both true)');
    }
    const sig: string = `${branch}|${this.expandState.windowWidthVp.toFixed(0)}x` +
      `${this.expandState.windowHeightVp.toFixed(0)}|${fmt(cover)}|${fmt(title)}|${fmt(singer)}|${fmt(lyric)}`;
    if (sig === this.lastBranchLog) {
      return;
    }
    this.lastBranchLog = sig;
    Logger.info(PlayerExpandState.LOG_TAG,
      `RzdBranch branch=${branch} win=${this.expandState.windowWidthVp.toFixed(0)}x` +
      `${this.expandState.windowHeightVp.toFixed(0)} bp=(${this.breakpointEnv.widthBreakpoint},` +
      `${this.breakpointEnv.heightBreakpoint}) panelLayout=${this.panelLayout} ` +
      `usePanel=${panel} phoneSwiper=${phoneSwiper} ` +
      `cover=${fmt(cover)} title=${fmt(title)} singer=${fmt(singer)} lyric=${fmt(lyric)} ` +
      `pad=${this.expandState.topInsetVp().toFixed(1)}/${this.expandState.navigationBarBottomVp.toFixed(1)} ` +
      // ⚠️ 空数组要打成 `ok`，不能打空串 —— 否则"日志里那一段没了"和"没自检"分不清。
      `inv=${bad.length === 0 ? 'ok' : bad.join(';')}`);
  }

  /** True for small-width + medium-height window (phone landscape-ish). */
  private isSmHeightMdLayout(): boolean {
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD;
  }

  /** True when the wide split panel layout should be used (param or wide window). */
  private usePanelLayout(): boolean {
    const size = this.windowInfo.windowSize;
    const landscape: boolean = size.width > size.height && size.height > 0;
    return this.panelLayout || (landscape &&
      this.breakpointEnv.widthBreakpoint !== WidthBreakpoint.WIDTH_SM);
  }

  /**
   * @returns 是否走「手机 Swiper」那一支布局（封面页 / 歌词页**横向切换**的那套）。
   *
   * ★★ 2026-10-15（第九轮·**改正一处"注释与实现不符"**）：
   *   原注释写的是「判据与 `buildControlStack()` 里那个 `if` 的取反**逐字一致**：
   *   `SM`（不论高）或 **`MD + HEIGHT_SM`**」——
   *   ⚠️ **实现里对 MD 并没有高度条件**（就是 `widthBp === WIDTH_MD` 本身）。两句不一致，
   *   而且**不一致的那个方向是"实现更宽"**（MD + 任意高度都返回 true）。
   *
   *   现在的实际语义（照实现写，**未改行为**）：
   * ```
   *   widthBp === SM                      → true
   *   widthBp === MD                      → true      ← ⚠️ 不含高度判断
   *   其余（LG / XL）                      → false
   * ```
   *   ⇒ 它比 `buildControlStack()` 那条 `if` 的取反**多命中"MD + 非 HEIGHT_SM"**这一档。
   *
   * ## ★ 与 `usePanelLayout()` 的**重叠区**（已登记，别在这里偷偷改）
   *
   * ```
   *   usePanelLayout() 在 (横屏 && widthBp !== SM) 时为真
   *   ⇒ 重叠 = 【横屏】【widthBp === MD】
   * ```
   * 好处是 `buildControlStack()` 里 `if (usePanelLayout())` **在前** ⇒ 面板支胜出、
   * 覆盖层被本函数挡掉 ⇒ **不会画两份封面**；
   * 坏处是这属于"**靠 if 顺序兜住**"，不是"判据互斥"。
   * ⚠️ **本函数还管着 `isPhoneLyricsStyleBackdropLayout()`（背景样式链）** ⇒
   *   把它收窄成 `&& !usePanelLayout()` 是**可见行为变化**（横屏背景样式会变），
   *   而横屏形态本机验不了 ⇒ **先决条件**：`RzdBranch` 在真机上量出重叠区的实际分支
   *   （`branchSane` 断言）之后，再决定收不收窄。登记处：
   *   `_recover/logic-src/目标④-宽屏面板统一-施工图与验收.md` §4「判据重叠」。
   */
  private usesPhoneSwiperLayout(): boolean {
    if (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM) {
      return true;
    }
    return this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD;
  }

  /**
   * True for the narrow-phone Swiper layout (not fold inner dual-pane, not lg/xl grid).
   * Album and lyrics pages share the same blurred backdrop + imageColor so the tint matches.
   */
  private isPhoneLyricsStyleBackdropLayout(): boolean {
    if (isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint)) {
      return false;
    }
    if (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD &&
      this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD) {
      return false;
    }
    return true;
  }

  // ★★ 2026-10-15（第三十九轮 / Round 20）：`@Builder phoneSwiperBackdropImage()` **已删除** ——
  //   它自己的 JSDoc 就写明"`grep -n "phoneSwiperBackdropImage"` 只有定义处这一个命中 ⇒ 本来就是死代码"，
  //   删除后 `backgroundImageSource()` 也随之零调用者（两者一起下线）。
  //   删除依据与产物符号自检（modules.abc GONE）见 RzdMusic记忆.md §56.15。

  /** Main Stack: background art, breakpoint-specific controls and lyrics grid. */
  @Builder
  buildControlStack() {
    Stack() {
      if (this.usePanelLayout()) {
        this.panelControlContent()
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          if (!(this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM ||
            (this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_MD &&
              this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_SM))) {
            // 平板/桌面：GridRow 左右分栏（封面 | 歌词），顶部 padding 让位给统一 TopArea
            Column() {
              GridRow({
                columns: { md: BreakpointConstants.COLUMN_MD, lg: BreakpointConstants.COLUMN_LG, xl: BreakpointConstants.COLUMN_LG },
                gutter: 48
              }) {
                GridCol({
                  span: { md: 4, lg: 5, xl: 4 }
                }) {
                  MusicPlayInfoBlock({
                    state: this.state,
                    metaBlockTranslateYvp: 0,
                    isDismissing: this.isCollapsing(),
                    coverLinearScale: 1
                  })
                }
                .margin({
                  bottom: 20
                })
                .padding({
                  left: isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ? 48 : 0,
                  right: isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ? 48 : 0
                })

                GridCol({
                  span: { md: 4, lg: BreakpointConstants.COLUMN_LYRIC_LG, xl: 8 }
                }) {
                  LyricsComponent({
                    isShowControl: this.isShowControlLg,
                    isTablet: this.isTabletFalse,
                    // ★★ 2026-10-15（照搬无界 / 目标 ④「宽屏·面板两分支统一」）：
                    //   无界**没有** `LyricsComponent` 内建"歌名 - 歌手"表头这回事
                    //   （`_recover/logic-src/歌词页浮层封面与歌名定稿.md` L1449 原文：
                    //   「无界没有 `LyricsComponent` 内建 header 这回事」）。
                    //   ⚠️ 手机那一支（下面 L2002 那处）第 1 块已经传了 `true`，
                    //      而**宽屏/面板这两处当时漏了** —— 又是
                    //      §56.1.6 / §56.16 / §56.17 那个「同一形状有 N 处、只改了一处」的老毛病。
                    //   冗余是实打实的：本分支上面就有 `MusicPlayInfoBlock`（L1908）在显示
                    //   封面 + 歌名 + 歌手 ⇒ 歌词再自报一次就是"同一首歌名出现两次"。
                    //   ⇒ 藏掉它**不丢任何信息**，且与无界的观感一致。
                    hideLyricsMetaHeader: true,
                    onSeekTime: (ms: number): void => {
                      MediaService.getInstance().seek(ms);
                    }
                  })
                }
                .margin({
                  bottom: 20
                })
              }
              .width(StyleConstants.FULL_WIDTH)
              .layoutWeight(1)
              .clip(true)
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .padding({
              left: $r('app.float.common_padding'),
              right: $r('app.float.common_padding'),
              top: 80
            })
            // ★★ 目标 ④ 的**分支归属诊断**（见 `logBranchSurface()` 的注释）。
            //   ⚠️ **必须挂在 `.onAppear()` 里，不能直接在 `@Builder` 体内调用** ——
            //      ArkTS 的 `@Builder` 体只接受 **UI 组件语法**，直接写方法调用会编译报错
            //      （本轮实测：`'this.logBranchSurface('wide')' does not meet UI component syntax`）。
            //   ⚠️ 也**不能**挂在"那一支的根容器"上就以为够了：这里挂在 `Column` 上，
            //      它只在**本支首次挂载**时触发 ⇒ 手机↔宽屏↔面板互相切换时各来一次，
            //      形变期间不会刷屏（`logBranchSurface` 内部还有一层签名节流）。
            .onAppear((): void => {
              this.logBranchSurface('wide');
            })
          } else {
            // 手机：Swiper 封面/歌词滑动 + 底部控制区
            Column() {
              // ★★★ 2026-10-16（**用户真机截图带出的问题：歌词页封面没变小**）
              //
              // ## 读数（用户 2026-10-16 22:42 截图）
              // ```
              //   V d73f1b8 … scale=1.000 p=1.000
              //   real=1 clone=0 snap=30/30 end=331/331 op=1.000 stage=2 drv=0
              //   … edge=331 t=0.00        ← ★ 就是这一对：t 停在 0 ⇒ 封面 = 331（整窗那一份）
              // ```
              //   封面尺寸 = `lyricMorph(lyricMorphT).size`，而 `lyricMorphT` 只有 0/1 两个稳定值：
              //     `t=0` ⇒ 封面 = `endCoverSize`（≈331，大封面）；`t=1` ⇒ `lyricCoverSizeOf()`（≈48.7，小封面）
              //   ⇒ 「封面没变小」≡ **`lyricMorphT` 没到 1**。
              //
              // ## `lyricMorphT` 的唯一写入者是 `animateLyricMorph`，而它只从这里被调
              // ```
              //   .onAnimationStart((index, targetIndex) => {
              //     if (index === targetIndex && !this.lyricMorphVisible) { return; }   // ← 守卫
              //     this.animateLyricMorph(targetIndex === SWIPER_INDEX_LYRIC);
              //   })
              // ```
              //   ⚠️ 这个守卫的语义是"**已经在目标页了**（`index === targetIndex`，不是一次真滑动）
              //     就跳过" —— 而 `Swiper` **没有绑定 `.index()`**：
              //     `playbackSwiperIndex` 只由 `.onChange` 写、并在 `onAppear` 里被复位成 0。
              //   ⇒ 只要"重挂载时 swiper 的初始页 ≠ 状态里的页"，页与状态就**长期不一致**：
              //     状态记着歌词页、swiper 停在第 0 页（或反之）⇒ 用户看到歌词页，
              //     但没有任何"滑动"发生 ⇒ `animateLyricMorph` **从来没被调用** ⇒ `lyricMorphT` 恒 0
              //     ⇒ 封面恒为大封面。**这与截图完全吻合**。
              //
              // ## 改法（把状态机接回去：让 swiper 的初始页 = 状态里的页）
              //   `.index(this.playbackSwiperIndex)` —— 这是 ArkUI `Swiper` 的官方属性，
              //   而我们本来就把这个值当"当前页"用（`.onChange` 写它、`onAppear` 复位它）。
              //   ⚠️ **不引入任何新数值**：它是"把已有的状态接到视图上"，属修一致性而不是调参。
              //   ⚠️ 【2026-10-16 订正】这里原来写着"`onAppear` 里那句
              //      `playbackSwiperIndex = 0` 仍保留" —— **那句已经删掉了**：
              //      它是节点级回调里的写入，会抢掉用户当前页；
              //      "打开播放器回封面页"是**打开意图**的职责（见内容层 `onAppear` 那段长注释）。
              //   复核关键字：徽标**第七行** `sw=` / `tgt=`（新加）——
              //     `sw=1 tgt=1` 才是歌词页的正常态；`sw=0` 而你在歌词页 ⇒ 就是本条。
              Swiper() {
                Stack({ alignContent: Alignment.Bottom }) {                  // ★★ 2026-10-15（照搬无界）：**页 0 是空壳**。
                  //   无界的 `playerPane` 里 `Swiper` 两页都只有 `Column().width/height('100%')`，
                  //   **封面与歌名根本不在页里**，而在 `Swiper` 之外的覆盖层
                  //   （`floatingCover` / `floatingMeta`，见 `PlayerPage完整UI定稿.md` §3 / §5 / §6）。
                  //   ⇒ 这里删掉 `MusicPlayInfoBlock`：它自带封面 + 歌名，
                  //     留着就会和那个**唯一的覆盖层**画成两份封面。
                  //   ⚠️ 它原来的两个职责（`.id(PLAYER_BIG_COVER_ID)` + `reportBig`、
                  //      `.id(PLAYER_META_*_ID)` + `publishMeta`）**已经搬到覆盖层**（见
                  //      `reportPlayerCoverFromOverlay` / `publishMetaEndpoint`）——
                  //      这是这次能删的前提；上一轮就是漏了这一步，导致"封面消失 + 动画全废"。
                  //   ⚠️ 宽屏/面板那两条分支仍在用它（`PlaybackPage` 内另有两处），
                  //      所以 import 保留。
                  Column() {
                    MiniLyricLinesComponent()
                      .width(StyleConstants.FULL_WIDTH)
                      .margin({
                        left: 4,
                        right: 4,
                        // ★★ 2026-10-15（修用户实测「播放界面这里错位」= 小歌词与歌名那一行重叠）：
                        //   这一页的 `Stack` 是 `Alignment.Bottom`，而**歌名/歌手那一行不是本页的内容**
                        //   —— 它是 `Swiper` 之外的覆盖层（`LyricFloatLayer`，`morphCoverRectAt` 派的位），
                        //   所以"小歌词贴在页底"正好落在那一行的高度带里（用户复现点 ≈ 660~690vp）。
                        //   ⇒ 把小歌词再往下推 `MINI_LYRIC_SINK_VP`：推开"歌名+歌手两行"的量级
                        //     （= `LYRIC_META_BLOCK_H_VP` 那一档口径），而不是拍一个数。
                        //   ⚠️ 负外边距是**唯一**能把它推出父容器内容区的手段（`offset`/`translate`
                        //      只挪绘制、把可视区留在原位，等于没让位）；它只影响这一页的排版，
                        //      不参与任何补间。
                        bottom: -PlaybackPage.MINI_LYRIC_SINK_VP
                      })
                      // 小歌词属于"内容"：反编译里 `contentOpacity` 落位才置 1
                      .opacity(this.expandState.morphContentOpacity)
                      // ★★ 2026-10-15 用户定调：「**先飞入的是小歌词和收藏按钮**」
                      //   ⇒ 小歌词走**第一组**的时间窗（`earlyRiseVp()`，早于控制区那一组），
                      //   从下升起 180vp；静止态位移恒 0，版面逐像素不变。
                      .translate({ y: this.expandState.earlyRiseVp() })
                      // 收起过程中内容被压扁，小歌词会和控制区互相盖住
                      .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
                  }
                  // ★ 2026-10-15 诊断锚点（`hdc shell hilog -x | Select-String 'RzdBoxes'`）：
                  //   把**三个会互相压的块**的窗口矩形一次打出来 ——
                  //     `lyric` 小歌词 / `title` 歌名 / `singer` 歌手 / `cover` 大封面。
                  //   判据：`lyric.top` 与 `singer.bottom` 相交 ⇒ 就是用户报的"这里错位"；
                  //         不相交而仍看着压在一起 ⇒ 那是**绘制**（scale/clip）而不是排版，另找。
                  .id(PlaybackPage.MINI_LYRIC_BOX_ID)
                  .onAreaChange((): void => {
                    this.logLayoutBoxes();
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                // ★ 歌名/歌手那一行**只走顶栏那一档**（`pullChromeOpacity = clamp((effT-0.18)/0.44)`，
                //   0.18 → 0.62），动画过程中就该淡入 —— 与用户拍板的第 2 条一致。
                //
                // ⚠️ 这里原来还叠了一层 `metaOpacityValue() = clamp(1 - morphP/0.35)`：
                //   那**是迷你条那一侧的淡出**公式（t=0.35 就归零），套在播放页这一行上
                //   = 用两个门夹同一块内容 —— `pullChromeOpacity` 明明已经到 1，
                //   却被 `metaOpacityValue` 按到 0，于是歌名/歌手**全程不可见、落位才冒出来**
                //   （用户实测的「展开中文字直到结束才出现」）。
                //   删掉这一层：`MusicPlayInfoBlock.MusicInfoTexts` 自己已经带 `pullChromeOpacity`。
                .opacity(this.expandState.pullChromeOpacity())
                .margin({
                  top: this.isSmHeightMdLayout() ? 0 : $r('app.float.music_component_top'),
                  bottom: this.isSmHeightMdLayout() ? 0 : $r('app.float.music_component_bottom')
                })
                .padding({
                  left: this.isSmHeightMdLayout() ? 0 : $r('app.float.common_padding'),
                  right: this.isSmHeightMdLayout() ? 0 : $r('app.float.common_padding')
                })

                Column() {
                  LyricsComponent({
                    isShowControl: false,
                    isTablet: this.isTabletFalse,
                    // ★ 2026-10-15（照搬无界）：**歌词页不再自带"歌名/词曲"表头**。
                    //   无界歌词页顶上就是那一条浮层横行（小封面 + 歌名 + 收藏/更多），
                    //   歌词正文里没有第二个歌名。原来这里是 `isSmHeightMdLayout()`
                    //   ⇒ 竖屏上会**同时**出现浮层的歌名和歌词自带的
                    //   "有风无风皆自由 - 王一佳 / 词：青柠"，观感就是"歌名出现两次"。
                    hideLyricsMetaHeader: true,
                    onSeekTime: (ms: number): void => {
                      MediaService.getInstance().seek(ms);
                    }
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                .height(StyleConstants.FULL_HEIGHT)
                // ★★★ 2026-10-17（**这一块测量已从"判据"降级为"哨兵"** —— 结论已闭合）：
                //   上报歌词页内容盒的**窗口顶边**。当初加它是为了定"`lyricPadTop()` 要不要换算坐标"：
                //   无界那个 `boxH/2 + bottomYAtLyric` 合起来就是"浮层底边**相对盒顶**"，
                //   而本仓拿**窗口坐标**当盒内相对量用 ⇒ 只在盒顶 ≈ 0 时等价。
                //   ✅ **收尾结论：盒顶结构上就是 0**（"盒"= Swiper 的盒；Swiper 所在的 `Column`
                //     与 `LyricFloatLayer()` 是同一个不带 padding 的 `Stack` 的孩子，且该 `Stack`
                //     的内容盒左上角 = 窗口原点 —— 完整证据链见 `PlayerExpandState.lyricBoxTopVp`）
                //     ⇒ **不需要换算，也不必再读这个数**。保留上报只为"将来有人加 padding 时能发现"。
                //   ⚠️ 必须用 `globalPosition`（窗口坐标），`position` 是相对父组件的。
                //   ⚠️ 动画中它可能瞬时非 0（容器 `.scale/.translate` 变换过的读数，正常）；
                //     只有**静止态**明显非 0 才说明结构变了。
                .onAreaChange((_oldValue: Area, newValue: Area): void => {
                  this.expandState.reportLyricBoxTop(areaLengthToVp(newValue.globalPosition.y));
                })
                // ★★★ 2026-10-17（照搬无界 `PlayerPage.onLyricSwipe(offsetY)` —— **逐条对齐**）
                //
                // 无界（`_recover/logic-src/PlayerPage.abc.txt:6938-6985`，挂在 `LyricsView` 上）：
                // ```ts
                //   onLyricSwipe(offsetY) {
                //     if (offsetY <= -SWIPE_TOGGLE_VP) {                 // ← 上滑
                //       if (entryAllowsManual(this.lyricImmersive)) {   // ← ★ 这一支**有门**
                //         hideChrome(); clearIdle();
                //       }
                //     } else if (offsetY >= 24) {                        // ← 下滑（字面量 0x18 = 24）
                //       showChrome(); startIdle();                       // ← 这一支**无门**
                //     }
                //   }
                // ```
                // ★ 两处与原实现的差别（都已按字节码订正）：
                //   ① 阈值：我们原来写的是 **12**（本仓自定的一半），无界**两侧都是 24**
                //      （低支走 `SWIPE_TOGGLE_VP`、高支是字面量 `ldai 0x18`；
                //        归档常量表 `MiniMorph渲染方与顶底栏淡入公式.md:171` 也是 `SWIPE_TOGGLE_VP | 24`）。
                //      ⚠️ 12 太容易误触（本层是 `parallelGesture`，歌词一往上拖就够 12vp）。
                //   ② 上滑那一支在无界里**带 `entryAllowsManual` 门**，而
                //      `entryAllowsManual(mode) = mode === MANUAL || mode === BOTH`，
                //      默认档是 **AUTO**（`LyricEntryMode` 4 档：OFF0/AUTO1/MANUAL2/BOTH3，
                //      见 `歌词页浮层封面与歌名定稿.md` §1）⇒ **默认档下上滑什么都不做**。
                //      本仓没有这个用户设置 ⇒ 只能取**默认**行为（见 `LYRIC_SWIPE_ALLOWS_MANUAL`）。
                //   ⚠️ 下滑那一支在无界里**没有门** ⇒ 我们无条件保留（`showChrome` + 起计时）。
                .parallelGesture(PanGesture({ direction: PanDirection.Vertical })
                  .onActionUpdate((event: GestureEvent): void => {
                    if (event.offsetY <= -PlaybackPage.SWIPE_TOGGLE_VP) {
                      if (PlaybackPage.LYRIC_SWIPE_ALLOWS_MANUAL) {
                        this.hideLyricChrome();
                      }
                    } else if (event.offsetY >= PlaybackPage.SWIPE_TOGGLE_VP) {
                      this.touchChrome();
                    }
                  }))
                .margin({
                  top: this.isSmHeightMdLayout() ? 0 : $r('app.float.margin_lyric')
                })
                .padding({
                  left: $r('app.float.common_padding'),
                  right: $r('app.float.common_padding'),
                  // ★★ A2：**按浮层让位**（等价无界的 `lyricPadTop()`）——
                  //   让歌词正文不钻到顶部那张封面 + 歌名浮层底下。
                  //   `lyricPadTop()` 自己保证"浮层不可用时返回 0"（`!lyricFloat → 0`），
                  //   所以这条 padding 在宽屏 / 封面还没量到时与改动前**逐像素一致**。
                  //   ⚠️ 只动留白，**歌词内容一个字不改**。
                  top: this.expandState.lyricPadTop()
                })
                // 歌词属于"内容"：`contentOpacity`（落位才置 1）
                .opacity(this.expandState.morphContentOpacity)
              }
              .layoutWeight(1)
              .indicator(
                new DotIndicator()
                  .top($r('app.float.options_padding'))
                  .selectedColor($r('app.color.select_swiper'))
                  .color($r('app.color.slider_track'))
              )
              .clip(false)
              .loop(false)
              // ⛔ 2026-10-16（**撤回我上一轮加的 `.index()` 绑定**）：
              //   上一轮我加 `.index(this.playbackSwiperIndex)` 是想"把状态接到视图上"，
              //   但**无界根本不这么做**：它的 `swiperProgress` 由 `onContentDidScroll`
              //   逐帧写、`onChange` **不写**它（归档定稿 §5.2 逐条字节码：
              //   「`@34*^1*#^1`（`onChange`，L190080-190110）**不写** `swiperProgress`」）。
              //   而 `.index()` 与"逐帧写 progress"放在一起会互相打架：
              //   `Swiper` 的整页切换本身会**翻过** index 0 才到 1，若 index 被绑定回 0，
              //   swiper 会被拽回去 ⇒ 用户根本切不到歌词页。
              //   ⇒ 改回"**不绑定 index，改用 `onContentDidScroll` 驱动**"（见下面那段）。
              //
              // ★★★ 2026-10-16（**照搬无界的进度源** —— 修"歌词页封面没变小"的根）
              // ---------------------------------------------------------------
              // 出处：归档定稿 `_recover/logic-src/歌词页浮层封面与歌名定稿.md` §5.2
              //   （逐条字节码 L189489-189540 绑定点 + L190026-190075 处理器）
              // 官方 SDK（`swiper.d.ts:onContentDidScroll`，@since 12）：
              //   "During page scrolling, the ContentDidScrollCallback callback is invoked
              //    for all pages in the viewport **on a frame-by-frame basis**."
              //   `(selectedIndex, index, position, mainAxisLength)`
              //     · `selectedIndex` = 动画开始前选中的页
              //     · `index`         = **当前页**
              //     · `position`      = 内容相对主轴起点的移动比例
              //
              // 无界的处理器等价实现（逐条照抄，含"只在一侧归一化"这条关键设计）：
              // ```ts
              //   let p = position;
              //   if (index === 0) {              // ★ 只在"当前页是播放页"这一侧归一化
              //     if (p < 0) { p = -p; }        //    往前滑时 position 为负 ⇒ 翻正
              //     if (p > 1) { p = 1; }         //    上夹到 1
              //     this.swiperProgress = p;
              //   }
              // ```
              //   ⇒ **后半段（歌词页那一侧）保持上一次的值** ⇒ **停在歌词页时 `p` 恒为 1**。
              //   这正是我们一直缺的那个量：它**不依赖"发生过一次用户滑动"**——
              //   只要页面真的切过去了，`index` 就会变成 0/1、`p` 就会到 1。
              //
              // 我们这一侧的接法（**同一份语义，写到 `lyricMorphT` 上**）：
              //   `lyricMorphT` 就是本仓的 `swiperProgress` 等价物（0 = 封面页端 / 1 = 歌词页端），
              //   所以直接把归一化后的 `p` 喂给它；再由 `syncLyricMorphToPage()` 负责
              //   "最终静止端点必须等于当前页对应的端点"（跨过 0.5 时补一次）。
              .onContentDidScroll((_selectedIndex: number, index: number,
                position: number, _mainAxisLength: number): void => {
                this.onSwiperContentDidScroll(index, position);
              })
              // ★★★ 2026-10-17（照搬无界 `onLyricInteract` —— 歌词区**触摸**就重置空闲计时）
              //
              // 无界那一侧（`_recover/logic-src/PlayerPage.abc.txt:6914-6932`）：
              // ```ts
              //   onLyricInteract() { if (!chromeHidden) { startIdle(); } }
              // ```
              // 挂载点在同文件 `190116-190130`：**`TouchType.Down`** 才调（不是 Move/Up）。
              // ⚠️ 关键差别：它**只** `startIdle()`，**不** `showChrome()`
              //   ⇒ 所以这里也**不能**用 `touchChrome()`（那个会顺手把控制区唤出来）。
              // ⚠️ 挂载点选在 `Swiper` 而不是"歌词页那一棵子树"：本仓 `scheduleChromeAutoHide()`
              //   内部还有 `canHideLyricChrome()`（**只在歌词页为真**）这道门
              //   ⇒ 在封面页触摸即使起了计时器也**不会**收起任何东西
              //   ⇒ 与无界"只在歌词页挂"**行为等价**（少挖一层子树的属性链）。
              // ⚠️ `.onTouch` 只观察、**不消费**事件 ⇒ 不影响 Swiper 自己的滑动。
              .onTouch((event: TouchEvent): void => {
                if (event.type !== TouchType.Down) {
                  return;
                }
                this.onLyricInteract();
              })
              // ★ 目标 ④ 的**分支归属诊断**（手机支）—— 见 `logBranchSurface()` 的注释。
              //   挂在 `Swiper`（它只存在于手机这一支）的 `.onAppear()` 上：
              //   ⚠️ 挂在 `@Builder` 体里会编译报错（`does not meet UI component syntax`，本轮实测）。
              .onAppear((): void => {
                this.logBranchSurface('phone');
              })
              // ⚠️ 这里**不再**给整个 Swiper 加 `contentOpacity`：按反编译，只有
              //    **封面/歌词**是"落位才出现"的内容，而**歌名/歌手那一行**属于顶栏那一档
              //    （`pullChromeOpacity` 0.18→0.62），要在动画过程里就淡入。
              //    所以分级下移：封面 → MusicPlayInfoBlock 自己带；
              //    歌词 → 各自那两份 LyricsComponent；小歌词 → MiniLyricLinesComponent。
              .onAnimationStart((index: number, targetIndex: number, _event: SwiperAnimationEvent): void => {
                // ★★★ 2026-10-16（**这里不再驱动 `lyricMorphT`** —— 驱动权已交给
                //   `onContentDidScroll`，见本 `Swiper` 上方那段长注释）。
                //   原来这里调 `animateLyricMorph(...)`，而它带守卫
                //   「`index === targetIndex` ⇒ 跳过」⇒ 只要切页不是"一次真滑动"
                //   （程序化切页 / 重挂载初始页不是 0），整套飞行**永远不启动**。
                //   ⇒ 现在这里只做**诊断计数**（保留第八行 `ast=` / `skp=`，以便对比新旧行为），
                //     相位与进度一律由 `onSwiperContentDidScroll()` 决定。
                //   ⚠️ 保留这段是有意的：万一 `onContentDidScroll` 在某些机型上不触发，
                //      第八行的 `ast=0-1` 就是"滑动回调存在但进度回调不存在"的证据。
                this.diagAnimStart = `${index}-${targetIndex}`;
                if (index === targetIndex && !this.lyricMorphVisible) {
                  this.diagAnimSkip = this.diagAnimSkip + 1;
                }
              })
              .onAnimationEnd((index: number, _event: SwiperAnimationEvent): void => {
                // ★ A2：Swiper 自己的滑动结束 —— 与浮层飞行的收尾做**两问握手**
                //   （`lyricSwiperSettled && lyricFlightSettled` 都到了才卸掉"飞行中"那一档）。
                //   ⚠️ 改前这里只打日志、**从不置位 `lyricSwiperSettled`** ⇒
                //   `finishLyricMorph` 永远进不去（整套歌词页封面形变是死的）。
                this.lyricSwiperSettled = true;
                this.finishLyricMorph(this.lyricMorphGen);
                this.diagAnimEnd = `${index}`;
                this.diagAnimEndCount = this.diagAnimEndCount + 1;
                // ★★★ 2026-10-16（**收尾落定** —— 照搬 `onContentDidScroll` 之后必须补的一步）：
                //   `onContentDidScroll` 逐帧给的是**比例**，最后一帧未必正好是 0/1
                //   （实测常见 0.997 这种）；而 `syncLyricMorphToPage()` 默认会**让位给滚动**
                //   （`SCROLL_SETTLE_WINDOW_MS` 那道窗），所以滚动一停就要有人把 `t` 落定到端点。
                //   `onAnimationEnd` 正是"swiper 停稳"的官方信号（且带最终 `index`）。
                //   ⚠️ 顺序：**先**用 `index` 修正 `playbackSwiperIndex`，**再**落定
                //      （否则 `want` 会用旧索引算）。
                if (index !== this.playbackSwiperIndex) {
                  this.playbackSwiperIndex = index;
                }
                this.syncLyricMorphToPage('swiperEnd');
                Logger.info('RzdLyricFloat',
                  `swiper end index=${index} gen=${this.lyricMorphGen} t=${this.lyricMorphT.toFixed(3)}`);
              })
              .onChange((index: number): void => {
                this.diagChg = `${index}`;
                this.diagChgCount = this.diagChgCount + 1;
                this.playbackSwiperIndex = index;
                // ★★★ 2026-10-17（**照搬无界那个 `onChange` λ 的逐字结构** —— 原来是无条件 `touchChrome()`）
                //   无界（`_recover/logic-src/PlayerPage.abc.txt:23189-23215`）：
                // ```
                //   const v = 1;
                //   if (index === v) { startIdle(); }            // 歌词页：只起空闲计时
                //   else { clearIdle(); showChrome(); }          // 封面页：停计时 + 唤出控制区
                //   this.atLyricScreen = (index === v);
                // ```
                //   ⇒ 两个关键差别（都被我们原来那句 `touchChrome()` 抹掉了）：
                //     ① 切到**歌词页**不唤出控制区（`touchChrome()` 会唤出）；
                //     ② 切到**封面页**要**显式唤出**并**停掉**空闲计时
                //        （`touchChrome()` 是"先起计时再停掉"，净效果同，但少了那条语义）。
                this.onSwiperIndexChanged(index);
              })

              // ★★★ 2026-10-16（照搬无界）：**控制区三段结构的两根占位条**。
              //   无界 overlay 的 `Swiper` 与"进度条/传输条"之间就是这两根**零内容 Row**
              //   （`wujie.pa:190464` / `190497`），不是 padding：
              //     `[Swiper | gapSwiper 行 | gapScrub 行 | 进度条+传输条]`
              //   ① `gapSwiper` 走**连续**公式 `playerSwiperGapOf(usableH) = clamp(0.065×h,16,56)`
              //      （`wujie.pa:93497`）—— **不是查档位表**（表里那 48/32/20 只在"没有实测
              //      `usableH` 时才用"，见 `playerChromeTotalOf` 的两处成对换值）；
              //   ② `gapScrub` 是查表值，但我们这一侧**已经**有同一段间距（`ControlAreaComponent`
              //      里 Slider 那一行的 `bottom` margin）⇒ 这里给 0，避免同一段两条口径，
              //      先用日志把"实测 vs `gapScrub`"量出来（见 `chromeScrubGapRowHVp()`）。
              //   ⚠️ 两根都是 `Row()`（不是 `Blank()`）：无界就是 `Row`，且空 `Row` 在 `Column`
              //      里按 `.height()` 精确占位，不会像 `Blank` 那样吃剩余空间。
              Row() {
              }
              .id(PlaybackPage.SWIPER_GAP_ROW_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(this.swiperGapRowHVp())
              .hitTestBehavior(HitTestMode.None)

              Row() {
              }
              .id(PlaybackPage.CHROME_SCRUB_GAP_ROW_ID)
              .width(StyleConstants.FULL_WIDTH)
              .height(this.chromeScrubGapRowHVp())
              .hitTestBehavior(HitTestMode.None)

              // 控制区：静止 3 秒自动收起，点/碰任意处唤出（对标无界音乐 BarCollapse）
              Column() {
                Column() {
                  // ★★ 2026-10-15 用户定调：「**进度条和下面的那堆按钮一起飞入**」——
                  //   它们是一组：整片控制区在**同一个时间窗**里从下升上来（见 `contentRiseVp()`），
                  //   所以这里**不再**给进度条单独错峰（上一版就是那么做错的）。
                  ControlAreaComponent({
                    // ★★ 2026-10-15（照搬无界）：**不要**那一行"下载/评论/更多"。
                    //   无界的 `transport` 只有 5 个：播放模式 / 上一首 / 播放暂停 / 下一首 / 播放队列
                    //   （`PlayerPage完整UI定稿.md` §8.3，逐项都在），**没有第二行**。
                    //   派音多出来的这一行在截图里一眼可见 ⇒ 关掉它才是"照搬"。
                    //   ⚠️ 那四个入口本身没删（`ControlAreaComponent` 里仍在），
                    //      要恢复把这里改回 `true` 即可。
                    showBottomOtherRow: false,
                    // ★ 菜单状态已提升到本页（那一横行的「更多」图标在本页）：
                    //   `ControlAreaComponent` 从 `@Local` 改成了 `@Param` + `@Event`。
                    showMenuSheet: this.playMenuOpen,
                    onMenuSheetChange: (open: boolean): void => {
                      this.playMenuOpen = open;
                    },
                    // ★★★ 2026-10-17（照搬无界 `hideChrome()` 的"面板开着就不收"守卫）：
                    //   菜单 sheet 已由上面那一对看得见；**其余两个弹层**（播放队列 / 其他版本）
                    //   在本组件内部，宿主看不到 ⇒ 由这个回调报上来，并进收起门（见 `auxSheetOpen`）。
                    onAuxSheetOpenChange: (open: boolean): void => {
                      this.auxSheetOpen = open;
                    },
                    chromeOffsetY: this.expandState.chromeOffsetY(),
                    chromeOpacity: this.expandState.chromeOpacity()
                  })
                    .width(StyleConstants.FULL_WIDTH)
                }
                .width(StyleConstants.FULL_WIDTH)
                .flexShrink(0)
                .height(this.canHideLyricChrome() && !this.lyricChromeMeasurePending &&
                  this.lyricChromeHeight > 0 ? this.lyricChromeHeight : undefined)
                .padding({
                  left: $r('app.float.common_padding'),
                  right: $r('app.float.common_padding'),
                  bottom: 10
                })
                .onAreaChange((_oldArea: Area, newArea: Area): void => {
                  // Measure natural inner content only while fully expanded, never the clipping shell.
                  const width: number = Number.parseFloat(newArea.width.toString());
                  const height: number = Number.parseFloat(newArea.height.toString());
                  if (Math.abs(width - this.lyricChromeWidth) > 0.5) {
                    this.lyricChromeWidth = width;
                    // Release only inner constraint; outer retains last height during the measuring frame.
                    const wasConstrained: boolean = !this.lyricChromeMeasurePending;
                    this.lyricChromeMeasurePending = true;
                    Logger.info('RzdLyricChrome', `invalidate naturalHeight width=${width}`);
                    if (wasConstrained) {
                      return;
                    }
                  }
                  if (!this.chromeCollapsed && this.lyricChromeProgress === 1 && !this.isCollapsing() &&
                    height > 0 && (this.lyricChromeMeasurePending ||
                    Math.abs(height - this.lyricChromeHeight) > 0.5)) {
                    this.lyricChromeHeight = height;
                    this.lyricChromeMeasurePending = false;
                    Logger.info('RzdLyricChrome', `measure naturalHeight=${height}`);
                  }
                })
                .opacity(this.canHideLyricChrome() ? this.lyricChromeProgress : 1)
                .translate({ y: this.canHideLyricChrome() ? (1 - this.lyricChromeProgress) * 24 : 0 })
              }
              .width(StyleConstants.FULL_WIDTH)
              .height(this.canHideLyricChrome() && this.lyricChromeHeight > 0 ?
                this.lyricChromeHeight * this.lyricChromeProgress : undefined)
              .clip(true)
              .margin({ bottom: this.expandState.chromeOffsetY() })
              // ★★ 2026-10-15（回退后重做）用户定调：「**不要淡入淡出**」——
              //   控制区不再靠透明度出场（原来这里是 `.opacity(pullBottomIn())`），
              //   改成**从下升起的位移**：整片控制区在自己的时间窗内从下方 180vp 升到位，
              //   两组的先后见 PlaybackPage 顶部的 `WIN_A_*` / `WIN_B_*` 说明。
              //   静止态位移恒 0（`morphClipping()` 为假时直接返回 0）⇒ 版面逐像素不变。
              .translate({ y: this.expandState.contentRiseVp() })
              .onTouch((event: TouchEvent): void => {
                this.touchChrome();
                // ★★★ 2026-10-16（照搬无界）：**拖动控制条收起 / 展开**（`BarCollapse`）。
                //   无界 `design/src/main/ets/logic/BarCollapse.ets` 的手势状态机
                //   （字节码 `wujie.pa:83706-84140`）已逐条转写到
                //   `common/musicbasic/.../model/BarCollapse.ets`，这里只是把触摸事件喂给它。
                //   ⚠️ 它只识别**纵向**手势（横向锁定后整串忽略）⇒ 不会和歌词横向滑动打架。
                this.onChromeBarTouch(event);
              })
              // Full player collapse retains its existing path; lyric hide reclaims layout continuously.
              .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
          }
          // 统一 TopArea（单一实例，叠加于内容之上，切换断点时不销毁重建）
          TopAreaComponent({
            isShowPlay: this.state.isShowPlay,
            onBackClick: (): void => {
              // ★★★★ 2026-10-17（**照搬无界的关闭分流** —— 用户「系统返回/关闭按钮是先滑一段再飞回去」）
              //   无界：非手势关闭（返回 / 关闭按钮）走 `closeWithAnimation()` = **拍快照缩到胶囊**，
              //        画面根本不"滑"；**活页形变只留给下拉手势**（`onReverseMorph`）。
              //   我们原来这里直接 `closeFullScreenPlayback()`（= 活页形变）⇒ 页面先滑一段，
              //        再由壳层那一棒飞回去 ⇒ 就是你看到的"先滑一段，然后再飞回去"。
              //   ⚠️ `closeWithAnimation()` 自带两级兜底（胶囊矩形/窗口尺寸不可用、快照失败）
              //     ⇒ 都不会把播放页卡住。
              this.closeWithAnimation();
            }
          })
            .padding({
              left: $r('app.float.common_padding'),
              right: $r('app.float.common_padding')
            })
            .zIndex(2)
            // 顶栏：反编译 `pullChromeOpacity = clamp((effT-0.18)/0.44)`，0.18 → 0.62 淡入
            //（"按钮也是在动画过程就出现了"就是这一层比底栏早得多）
            .opacity(this.expandState.pullChromeOpacity())
            .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
            // ★★ 2026-10-15（照搬无界：页面侧关闭手势的**第二个挂载点**）
            //   无界的关闭手势挂了**两处**（`_recover/logic-src/开关播放器-手势路径定稿.md`
            //   §1.1 的 ⑤ 与 ⑥）：
            //     ⑤ `PlayerPage` 顶部那条 Row（`PanDirection.Down`, `distance:8`）← **主入口**
            //     ⑥ 内容容器
            //   我们原来只有"整页根"那一处（≈⑥）。而整页根上的竖直拖动**会被内部
            //   可滚动 / 子手势先吃掉**（ArkUI 手势冒泡：子节点优先）⇒
            //   用户实测「没法下拉关闭播放器」。
            //   顶栏这一条是**非滚动的固定条带**、必定收得到竖直拖动 ⇒ 补上它，与无界同构。
            //   ✅ 纯增量、不改任何既有行为：命中的还是同一个 `onDismissDrag()`；
            //      只有"起手落在顶栏上"时才由它接管（`.gesture()` 子节点优先），
            //      页面其它区域的既有行为一字不变。
            //   ⚠️ 两处顶栏实例（本处 + 下面 `!panelLayout` 那支）**必须都挂** ——
            //      否则就是 §56.1.6 / §56.16 那个「同一形状有 N 处、只改了一处」的老毛病。
            .gesture(
              PanGesture(this.panOption)
                .onActionStart((): void => {
                  Logger.info(PlayerExpandState.LOG_TAG,
                    `RzdMorph dismiss pan start(topBar) isClosing=${this.isClosing} ` +
                    `morphUsable=${this.expandState.morphUsable} stage=${this.expandState.morphStage}`);
                })
                .onActionUpdate((event: GestureEvent): void => {
                  this.onDismissDrag(event.offsetY, false, event.velocityY);
                })
                .onActionEnd((event: GestureEvent): void => {
                  this.onDismissDrag(event.offsetY, true, event.velocityY);
                })
                .onActionCancel((event: GestureEvent): void => {
                  Logger.info(PlayerExpandState.LOG_TAG,
                    `RzdMorph dismiss pan cancel(topBar) offsetY=${event.offsetY.toFixed(1)}`);
                  this.onDismissDrag(event.offsetY, true, 0);
                })
            )
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .padding({
          bottom: this.windowInfo.navigationBarBottomVp,
          top: this.windowInfo.statusBarTopVp
        })
      }
    }
    .height(StyleConstants.FULL_HEIGHT)
    .width(StyleConstants.FULL_WIDTH)
    // ⚠️ 这里（`buildControlStack` 的根）**不要**再给 `backgroundColor(imageColor)`：
    //    它是一层**恒不透明**的取色底（`imageColor` 的 alpha 是 0.4，但底色本身）
    //    —— 形变期间裁剪窗口只有一小块，它会连同窗口一起把下面的首页糊掉，
    //    再加内部那层近黑底色，观感就是"展开中背景是黑的"。
    //    背景色一律由上面**带淡入窗口**的两层负责（底色 + 取色层），这里保持透明。
  }

  /** Wide split panel layout: cover + controls on the left, lyrics + dual-action bar on the right. */
  @Builder
  private panelControlContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row({ space: 56 }) {
        Column() {
          MusicPlayInfoBlock({
            state: this.state,
            metaBlockTranslateYvp: 0,
            isDismissing: this.isCollapsing(),
            coverLinearScale: 1,
            panelLayout: true
          })
        }
        .layoutWeight(1)
        .padding({ top: 80, bottom: 48 })

        Column() {
          LyricsComponent({
            isShowControl: false,
            isTablet: this.isTabletFalse,
            panelBottomBar: true,
            // ★ 同宽屏那处：藏掉 `LyricsComponent` 自带表头（无界没有它）。
            //   本分支上面 L2233 的 `MusicPlayInfoBlock` 已经在显示封面 + 歌名 + 歌手
            //   ⇒ 不藏就是"同一首歌名出现两次"。完整理由见 L1926 那处的注释。
            hideLyricsMetaHeader: true,
            onSeekTime: (ms: number): void => {
              MediaService.getInstance().seek(ms);
            }
          })
        }
        .layoutWeight(1)
        // 歌词属于"内容"：`contentOpacity`（落位才置 1）
        .opacity(this.expandState.morphContentOpacity)
        .padding({ top: 72, bottom: 74 })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .padding({
        left: 56,
        right: 56,
        top: this.windowInfo.statusBarTopVp,
        bottom: this.windowInfo.navigationBarBottomVp
      })
      // ★ 目标 ④ 的**分支归属诊断**（面板支）—— 与宽屏那处成对，理由见它上面的注释。
      .onAppear((): void => {
        this.logBranchSurface('panel');
      })

      if (!this.panelLayout) {
        TopAreaComponent({
          isShowPlay: this.state.isShowPlay,
          onBackClick: (): void => {
            // ★ 同上（照搬无界：非手势关闭 = 快照收缩，不是活页形变）
            this.closeWithAnimation();
          }
        })
          .padding({
            left: 56,
            right: 56
          })
          .zIndex(2)
          .visibility(this.isCollapsing() ? Visibility.None : Visibility.Visible)
          // ★ 同上面那处顶栏：页面侧关闭手势的第二个挂载点（对标无界 ⑤ 顶部 Row）。
          //   ⚠️ 这一处**必须与上面那处成对存在**，理由与完整说明见上面那段注释。
          .gesture(
            PanGesture(this.panOption)
              .onActionStart((): void => {
                Logger.info(PlayerExpandState.LOG_TAG,
                  `RzdMorph dismiss pan start(topBar-wide) isClosing=${this.isClosing} ` +
                  `morphUsable=${this.expandState.morphUsable} stage=${this.expandState.morphStage}`);
              })
              .onActionUpdate((event: GestureEvent): void => {
                this.onDismissDrag(event.offsetY, false, event.velocityY);
              })
              .onActionEnd((event: GestureEvent): void => {
                this.onDismissDrag(event.offsetY, true, event.velocityY);
              })
              .onActionCancel((event: GestureEvent): void => {
                Logger.info(PlayerExpandState.LOG_TAG,
                  `RzdMorph dismiss pan cancel(topBar-wide) offsetY=${event.offsetY.toFixed(1)}`);
                this.onDismissDrag(event.offsetY, true, 0);
              })
          )
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  /** True when PC window uses immersive free-form decor (affects title button styling). */
  private isPcFreeWindowDecor(): boolean {
    return this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE;
  }

  // ⚠️ 2026-10-17：这里原来还有一个 `applyWindowSafeAreas()` —— **已删除**。
  //   它与下面那个**活着的** `applyPlaybackWindowChromeImmediately()`（唯一调用点 :5534）
  //   是**同一件事的两套写法**，只差一句 `applyPlaybackNavigationBarColor(true)`
  //   ⇒ 零调用点、留着就是"改错地方"的入口（本仓已经为这个形状吃过好几次亏）。
  //   ⇒ 真要改播放页的窗口装饰，**只改下面那一个**。

  /** Applies playback window chrome: system-bar colors only, window layout stays non-full-screen. */
  private applyPlaybackWindowChromeImmediately(): void {
    const wu = WindowUtil.getInstance();
    wu.applyPlaybackNavigationBarColor(true);
    // Player is an overlay, not a new window. Switching window layout here also relayouts
    // the retained destination underneath and moves its HDS title into the status bar.
    // Keep layout policy owned by EntryAbility; only recolor system chrome.
    wu.applyPlaybackWindowChrome(true, false);
    Logger.info('RzdPlayerRoute', 'enter overlay: window layout unchanged');
    if (this.isPcFreeWindowDecor()) {
      wu.applyPcPlaybackDecorButtonStyle(true);
    }
  }

  /** Refreshes dynamic background tint when the current track or queue changes. */
  @Monitor('state.selectIndex', 'state.playQueueIds')
  onCurrentTrackForBackground(): void {
    if (this.context === undefined) {
      return;
    }
    this.getImageColor();
  }

  /** Entry point: kicks off async album-color extraction without blocking UI. */
  getImageColor(): void {
    void this.getImageColorAsync();
  }

  /**
   * 由封面算出流光背景的两个颜色并写进 {@link coverTint}。
   *
   * 只在开关打开时才做：取色要走一次解码（在线封面还要先下载），关掉就别白花这份开销。
   * 失败不报错也不改颜色 —— 保留上一首的颜色或兜底色，流光照样能看。
   *
   * @param pixelMap 已解码的封面位图，由调用方负责释放。
   */
  private async extractFlowLightColors(pixelMap: image.PixelMap): Promise<void> {
    if (!this.flowLightState.enabled || !this.isAlive) {
      return;
    }
    await new Promise<void>((resolve: () => void) => {
      effectKit.createColorPicker(pixelMap,
        (error: Error | undefined, colorPicker: effectKit.ColorPicker | undefined) => {
          try {
            if (!this.isAlive || error || colorPicker === undefined) {
              return;
            }
            // 用占比最大的颜色作为基调，再在 vividFlowColors 里把饱和度/亮度拉起来：
            // 封面主色经常是一大片接近黑的背景，直接拿它做流光基本看不见
            // （首页 PR 那版写死一个紫色，所以没这个问题）。
            const color = colorPicker.getLargestProportionColor();
            this.publishFlowLightColors(color.red, color.green, color.blue);
          } finally {
            resolve();
          }
        });
    });
  }

  /**
   * 把封面主色换算成流光用的两个颜色并发布。
   *
   * 写 `coverTint` 会触发 {@link onCoverTintVersionChange}，由它把颜色下发给着色器。
   *
   * **不判断开关**：换算本身只是几次算术，关着也先算好存起来 —— 这样用户
   * 在设置里一打开开关，第一帧的流光颜色就已经是当前封面色，不会先闪一下兜底色。
   * 真正要花钱的是解码封面，那部分由 {@link extractFlowLightColors} 把关。
   *
   * @param red 封面主色红通道 0–255。
   * @param green 封面主色绿通道 0–255。
   * @param blue 封面主色蓝通道 0–255。
   */
  private publishFlowLightColors(red: number, green: number, blue: number): void {
    if (!this.isAlive) {
      return;
    }
    const vivid: string[] = ColorConversion.vividFlowColors(red, green, blue);
    this.coverTint.sourceColor = vivid[0];
    this.coverTint.targetColor = vivid[1];
    this.coverTint.version = this.coverTint.version + 1;
    Logger.info(PlaybackPage.logTag, `flow light tint updated src=${vivid[0]} dst=${vivid[1]}`);
  }

  /**
   * Loads cover bytes, derives theme background color, and (before 2026-10-15) built the
   * blurred background PixelMap.
   *
   * ★★ 2026-10-15：**不再产出任何背景底图**。背景层改成「原始封面 + 组件级实时模糊」
   *   （{@link originalCoverSource} + {@link backdropBlurRadiusVp}）⇒ 这里只剩两件事：
   *   ① 把 `imageLabel` 复位成**原始封面**（`Resource`）；② 算出 `state.imageColor`
   *   （播放页背景那层取样色）+ 流光色。中间解码出来的 PixelMap **只用于取色，用完即弃**。
   */
  private async getImageColorAsync(): Promise<void> {
    const jobSeq: number = ++this.imageColorJobSeq;
    const ctx = this.context;
    if (!ctx) {
      return;
    }
    const song = this.state.getCurrentSongItem();
    if (!song) {
      return;
    }
    this.releaseBackgroundCoverIfPixelMap();
    // Online songs without a resolved cover use the default art for the blurred backdrop.
    this.imageLabel = song.source.length > 0 && song.cover.length === 0 ? $r('app.media.ic_avatar1') : song.label;

    // Online songs always use a neutral dark backdrop; the blurred cover renders on top.
    // Local color extraction is only for local tracks and never tints red.
    if (song.source.length > 0) {
      if (this.isAlive) {
        this.state.imageColor = 'rgba(20, 20, 22, 0.5)';
      }
      // 在线歌曲：只**解码**封面给流光取色用。
      //
      // ★★ 2026-10-15：这里原来还会 `effectKit.createEffect(coverPm).blur(imageBlurRadius())`
      //   预渲染一张模糊 PixelMap 当底图 —— **该预渲染已整体停用**（背景改实时模糊，
      //   底图给的是 {@link originalCoverSource()} 的原始封面）。
      //   ⇒ `imageLabel` 不再被赋成模糊图；解码这一步保留，因为
      //   {@link extractFlowLightColors} 需要一个现成的 PixelMap（免得为取色再下载一遍封面）。
      if (song.cover.length > 0 && this.isAlive) {
        try {
          const pair: CoverDecodePair =
            await PlaybackPage.loadOnlineCoverPair(song.cover);
          if (pair.full !== undefined && this.isAlive && jobSeq === this.imageColorJobSeq) {
            // 流光取色：趁位图已经解码好顺手算一次，不用为它再下载一遍封面
            await this.extractFlowLightColors(pair.full);
          }
          // ★★ 2026-10-15：网格背景的源（64×64）在同一次下载里出，交给背景层
          if (pair.mesh !== undefined && this.isAlive && jobSeq === this.imageColorJobSeq) {
            this.publishMeshSource(pair.mesh);
          } else {
            this.releasePixelMapQuiet(pair.mesh);
          }
          this.releasePixelMapQuiet(pair.full);
        } catch (_err) {
          // 取色失败不影响播放：背景走实时模糊，不再需要这张预渲染图
        }
      }
      // ★★★ 2026-10-17（用户「未播放状态点击打开播放器 → 背景是黑的；点一下播放就正常」）
      //
      // ## 机制（读代码即得，不是猜）
      // ```
      //   在线歌曲的背景**不是取色层**（那一层是写死的近黑 rgba(20,20,22,0.5)），
      //   真正的背景是**网格图**（`publishMeshSource(pair.mesh)`），而它只在
      //   `song.cover.length > 0` 时才会被解出来。
      //   未播放时封面 URL 可能还没到手（metadata 未 resolve）⇒ 既没网格也没取色
      //   ⇒ 屏上就是那层近黑底 = 用户看到的"背景是黑的"。
      //   一点播放 ⇒ 封面 metadata 到位 ⇒ `onCurrentTrackForBackground` 再跑一次 ⇒ 正常。
      // ```
      // ## 处置（**不发明任何视觉值**，只让它自己收敛）
      //   背景只该跟"封面有没有到手"有关、**与播放状态无关**
      //   ⇒ 封面还没到手时，**有界地**隔一会儿再取一次（最多 `BG_RETRY_MAX` 次，
      //     每次都要过 `isAlive` + `jobSeq` 这两道门）。
      //   ⚠️ 不能无限重试：封面确实不存在（本地无图/接口永久失败）时要停手。
      if (song.cover.length === 0 || this.meshSrcVersion === 0) {
        this.scheduleBackgroundRetry(jobSeq, 0);
      }
      return;
    }

    let mediaData: Uint8Array;
    try {
      mediaData = await ctx.resourceManager.getMediaContent(song.label.id);
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(PlaybackPage.logTag,
        `getMediaContent failed, code=${err?.code}, message=${err?.message}`);
      if (this.isAlive) {
        this.state.imageColor = PlaybackPage.defaultImageBgColor;
      }
      return;
    }
    if (!mediaData || mediaData.byteLength === 0) {
      Logger.error(PlaybackPage.logTag, 'getMediaContent returned empty buffer');
      if (this.isAlive) {
        this.state.imageColor = PlaybackPage.defaultImageBgColor;
      }
      return;
    }

    let pixelMap: image.PixelMap | undefined = undefined;
    // ★★ 2026-10-15（照搬无界 `decodeCover`）：同一次解码**顺手再出一张 64×64**，
    //   它才是网格背景的源（无界 `SRC_EDGE = 64`）。在 64×64 上做 `enhanceColors`
    //   + `boxBlurRgba(9, 3)`，再被 `drawPixelMapMesh` **放大铺满整屏** ⇒
    //   观感是"大色块流动"，与"全分辨率照片 + 高斯模糊"是两种东西。
    let meshPm: image.PixelMap | undefined = undefined;
    const imageSource = image.createImageSource(mediaData.buffer as ArrayBuffer);
    try {
      pixelMap = await imageSource.createPixelMap();
      // ★★ 2026-10-15：网格源**单独一个 try** —— 它失败**不能**把"取色"那条路一起 abort。
      //   原来是跟主解码同一个 `try`，而那个 `catch` 会 `return`（并写默认底色）
      //   ⇒ 64×64 那一步万一失败，连 `state.imageColor`（背景取样色）都会一起丢。
      //   网格源拿不到只会退回"实时模糊底图"，是**可降级**的，不该拖垮取色。
      try {
        meshPm = await imageSource.createPixelMap({
          desiredSize: { width: SRC_EDGE, height: SRC_EDGE },
          desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
          editable: true
        });
      } catch (meshError) {
        const me = meshError as BusinessError;
        Logger.warn(PlaybackPage.logTag,
          `mesh source decode failed, code=${me?.code}, message=${me?.message}`);
      }
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(PlaybackPage.logTag,
        `createPixelMap failed, code=${err?.code}, message=${err?.message}`);
      if (this.isAlive) {
        this.state.imageColor = PlaybackPage.defaultImageBgColor;
      }
      return;
    } finally {
      try {
        imageSource.release();
      } catch (error) {
        const err = error as BusinessError;
        Logger.warn(PlaybackPage.logTag,
          `imageSource.release failed, resourceId=${song.label.id}, code=${err?.code}, message=${err?.message}`);
      }
    }

    if (pixelMap === undefined) {
      return;
    }

    if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
      this.releasePixelMapQuiet(pixelMap);
      return;
    }

    await new Promise<void>((resolve: () => void) => {
      effectKit.createColorPicker(pixelMap,
        (error: Error | undefined, colorPicker: effectKit.ColorPicker | undefined) => {
          try {
            if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
              return;
            }
            if (error || colorPicker === undefined) {
              const msg =
                error ? `${(error as BusinessError).code} ${(error as BusinessError).message}` : 'no picker';
              Logger.error(PlaybackPage.logTag, `createColorPicker failed: ${msg}`);
              this.state.imageColor = PlaybackPage.defaultImageBgColor;
              return;
            }
            const color = colorPicker.getLargestProportionColor();
            const colorArr = ColorConversion.dealColor(color.red, color.green, color.blue);
            const r = clampRgbByte(colorArr[0]);
            const g = clampRgbByte(colorArr[1]);
            const b = clampRgbByte(colorArr[2]);
            this.state.imageColor = `rgba(${r}, ${g}, ${b}, 0.4)`;
            // 同一次取色的结果顺带算流光色，省掉再建一个 ColorPicker 的开销
            this.publishFlowLightColors(color.red, color.green, color.blue);
          } finally {
            resolve();
          }
        });
    });

    if (!this.isAlive || jobSeq !== this.imageColorJobSeq) {
      this.releasePixelMapQuiet(pixelMap);
      return;
    }

    // ★★ 2026-10-15：这里原来是「`effectKit.blur(imageBlurRadius())` 预渲染一张模糊 PixelMap
    //   赋给 `imageLabel` 当背景底图」。背景改成实时模糊后**这条路已整体停用** ——
    //   `imageLabel` 保持为 `song.label`（**原始封面 Resource**），
    //   由 {@link originalCoverSource} 交给背景层 + 组件级 `.blur()` 去实时模糊。
    //   解码出来的 PixelMap 只服务于上面那次取色，用完即弃。
    //   ⚠️ 顺带解掉一个隐患：以前被释放的正是"正在当底图渲染的那张 PixelMap"
    //      （下次换歌/页面卸载时 `releaseBackgroundCoverIfPixelMap()` 会释放它），
    //      现在 `imageLabel` 恒为 Resource ⇒ **背景层不再持有任何会被释放的位图**。
    // ★★ 2026-10-15：本地/内置封面的 64×64 网格源也交出去（背景层用），
    //    它的生命周期改由 `meshSrc` 持有（换歌时释放上一张，见 `publishMeshSource`）。
    this.publishMeshSource(meshPm);
    this.releasePixelMapQuiet(pixelMap);
  }

  /**
   * 把封面位图做成**网格背景的源**并交给背景层。
   *
   * 照搬无界的取图口径（`播放页背景-MeshGradient与MeshSource定稿.md` §0 / §4）：
   * ```
   * 64×64 RGBA_8888（可编辑）
   *   → enhanceColors(u8)                              低对比 / 高饱和 / 偏暗（当背景不抢前景）
   *   → boxBlurRgba(u8, 64, 64, 9, 3)                  盒式模糊，无 gamma
   *   → 回写 PixelMap，交给 MeshCoverBg（网格放大铺满）
   * ```
   * ⚠️ `enhanceColors` 里的 `0.4` 与 `×5` 是**配套的一对**，别只改一个（会过曝或发灰）。
   * ⚠️ 新旧交替顺序：**先释放上一张、再赋值并 `++meshSrcVersion`** ——
   *    `MeshCoverBg` 的 `@Monitor` 监听的是**版本号**（`PixelMap` 原地改内容不会触发刷新）。
   */
  private publishMeshSource(pm: image.PixelMap | undefined): void {
    if (pm === undefined) {
      return;
    }
    try {
      const bytes: number = pm.getPixelBytesNumber();
      const buf: ArrayBuffer = new ArrayBuffer(bytes);
      pm.readPixelsToBufferSync(buf);
      const u8: Uint8Array = new Uint8Array(buf);
      enhanceColors(u8);
      boxBlurRgba(u8, SRC_EDGE, SRC_EDGE, PlaybackPage.MESH_BLUR_RADIUS, PlaybackPage.MESH_BLUR_PASSES);
      pm.writeBufferToPixelsSync(buf);
    } catch (err) {
      const e = err as BusinessError;
      Logger.warn(PlaybackPage.logTag, `mesh source build failed code=${e?.code}, message=${e?.message}`);
      this.releasePixelMapQuiet(pm);
      return;
    }
    const old: image.PixelMap | undefined = this.meshSrc;
    // ★★★ 2026-10-17（照搬无界 `MorphGuard` 的"配色安静窗口"）：形变补间跑着的时候**不换背景**
    //   （换背景 = 整层网格重画，观感就是"动画中途背景色跳一下"）。窗口过去后自动补上最后一次。
    if (this.colorApplyWaitOrRetry() > 0) {
      const dropped: image.PixelMap | undefined = this.pendingMeshPm;
      this.pendingMeshPm = pm;
      if (dropped !== undefined && dropped !== pm) {
        this.releasePixelMapQuiet(dropped);
      }
      return;
    }
    this.commitMeshSource(pm, old);
  }

  /**
   * 把网格源真正挂上去（{@link publishMeshSource} 的"提交"那半）。
   * @param pm 新的网格源（所有权转移给本页）
   * @param old 被替换掉的旧源（非空则释放）
   */
  private commitMeshSource(pm: image.PixelMap, old: image.PixelMap | undefined): void {
    this.meshSrc = pm;
    this.meshSrcVersion = this.meshSrcVersion + 1;
    if (old !== undefined && old !== pm) {
      this.releasePixelMapQuiet(old);
    }
  }

  /**
   * 安静窗口过去后补上最后一次网格源 —— 与无界那个重试 λ（`wujie.pa:157930-157939`）
   * 调 `syncReportChrome()` 是同一件事：**窗口一过就把最新配色补上去**。
   * 没有待补的源时是空操作。
   */
  private republishMeshSourceIfAny(): void {
    const pending: image.PixelMap | undefined = this.pendingMeshPm;
    if (pending === undefined) {
      return;
    }
    this.pendingMeshPm = undefined;
    this.commitMeshSource(pending, this.meshSrc);
  }

  /** Downloads an online cover url and decodes it into a PixelMap (best-effort). */
  /**
   * 一次下载解出的两张位图：全尺寸（流光取色用）+ **64×64 网格源**（背景用）。
   *
   * ★ 2026-10-15（照搬无界的取图口径）：把 64×64 那一张放在**同一次解码**里出，
   *   不必为背景再下载一遍封面。`desiredSize` + `editable` 是必须的 ——
   *   网格源要在 64×64 上原地做 `enhanceColors` / `boxBlurRgba`（见 `publishMeshSource`）。
   */
  private static async loadOnlineCoverPair(url: string): Promise<CoverDecodePair> {
    const out: CoverDecodePair = new CoverDecodePair();
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 15000
      });
      if (resp.responseCode !== 200 || resp.result === undefined) {
        return out;
      }
      const src: image.ImageSource = image.createImageSource(resp.result as ArrayBuffer);
      try {
        out.full = await src.createPixelMap();
        out.mesh = await src.createPixelMap({
          desiredSize: { width: SRC_EDGE, height: SRC_EDGE },
          desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
          editable: true
        });
      } catch (err) {
        const e = err as BusinessError;
        Logger.warn(PlaybackPage.logTag, `online cover decode failed, code=${e?.code}, message=${e?.message}`);
      } finally {
        src.release();
      }
      return out;
    } catch (_err) {
      return out;
    } finally {
      req.destroy();
    }
  }

  /**
   * @returns 形变容器的**高度**：形变期间是"竖直裁剪窗口"（只露出上面这一条），
   *          其余时间恒为 `'100%'`（= 与没有这套动画时逐像素一致）。
   *
   * ⚠️ 静止态**必须**给 `'100%'` 而不是任何算出来的数字：之前用实测的
   *    `contentHeightVp` 当静止高度，而上报源恰好是**这层自己被裁剪时的高度**，
   *    一次上拉之后这个值就被写成 ~360vp，于是每次打开播放页底部都缺一块
   *    （用户实测反馈）。百分比高度由父容器（满屏宿主）决定，不可能算错。
   */
  /**
   * @returns 形变容器的**高度**（= 竖直裁剪窗口）：静止态 `'100%'`（等价于不裁剪）。
   *
   * 不变量：裁剪高度 = 可视高度 / 缩放 ⇒ 屏上那块可视矩形里**正好**是整页，
   * 既没有留白（第四版"黑窗口，中间一个小播放页"就是留白），也没有裁切。
   * ⚠️ 静止态必须给 `'100%'` 而不是任何算出来的数字：百分比由满屏宿主决定，
   *    不会被某次形变的中间态写脏（"底部缺一块"就是这么来的）。
   */
  private morphClipHeight(): Length {
    if (!this.expandState.morphClipping()) {
      // ⚠️⚠️ 2026-10-17（**用户第 1/2 条"补间没有动画"的候选机制**）：
      //   这里原来**无条件返回 `'100%'`（字符串）**，而形变期返回的是**数字**
      //   ⇒ `.height()` 这个属性在**字符串 ⇄ 数字之间切换类型**，
      //     ArkUI **无法在两种类型之间插值** ⇒ 补间一起手就**直接跳到终点**
      //     （观感 = "封面直接就到结束位置 / 直接下去，没有动画"）。
      //   ★ 为什么"手指跟手那条是好的"：那条路每一帧都在写**数字**，全程同类型 ✓
      //   ★ 为什么要 return 数字而不是保留 '100%'：静止态那条注释担心的是
      //     "**量出来的内容高度**会被某次形变写脏"（"底部缺一块"），
      //     而**窗口高度**是 `reportWindow` 给的权威值、不参与形变 ⇒ 没有那个风险。
      //   ⚠️ 容器父级是满屏宿主 ⇒ 数值上 `winHVp` 就等于 `'100%'`。
      //     窗口尺寸还没上报时（极早期）才退回字符串 —— 那是唯一的一次类型切换，
      //     且发生在本页刚挂载、还没有任何补间的时候。
      const h: number = this.expandState.windowHeightVp;
      return h > 0 ? h : '100%';
    }
    return Math.max(1, this.expandState.morphClipHeight);
  }

  /** Root: 整页缩放 + 竖直裁剪窗口（可视矩形里正好是整页）+ 桥接封面。 */
  build() {
    // ★ 第五版：**整页缩放 + 竖直裁剪窗口**。
    //   可视矩形从**迷你条那条胶囊**长到整屏（"整个播放条延伸铺开"），
    //   下边在前 25% 就贴到宿主底边（否则底部那几十 vp 整段动画都空着）；
    //   内容层高度 = 裁剪高度 = 可视高度 / 缩放，所以可视矩形里**永远填满整页**，
    //   没有留白、也不会被裁；内容层等可视矩形宽高比接近页面时才浮现，
    //   避免中段看到一张被压扁的页面（那正是"从中间开始、看不出展开过程"的来源）。
    //   封面由续飞封面单独续飞，**p = 1 才落位**（2026-10-15 起那一棒画在**壳层浮层**
    //   `Index.MorphCoverClone()` 里；PC 壳层仍在本页的 `MorphCoverBridge`）。
    Stack({ alignContent: Alignment.TopStart }) {
      // ★★★ 2026-10-16（照搬无界）：**背景整层搬到形变容器之外**。
      //   无界的 `MeshCoverBg` 在 `playerPane` **之外**（与它同级）⇒ 它不参与播放页的
      //   `scale / clip` ⇒ 观感是「**内容飞上来、背景不动**」。
      //   我们原来把它放在形变容器**内部** ⇒ 跟着被等比压到约 34% 再放大，
      //   用户实测就是「**像压缩的背景铺开**」。
      //   ⚠️ 搬出来后它**不再被裁剪窗口裁**（整屏可见），所以形变期的可见范围靠
      //     `backgroundRevealOpacity()`（= 无界 `pullBgIn`，0→0.30 淡入）管 —— 与无界同口径。
      //   ⚠️ 兜底层去掉了 `borderRadius(this.expandState.morphRadius)`：整屏层不需要圆角。
      // ★★★ 2026-10-16（修用户实测「**关闭播放器只有内容会弹，背景还是不会弹**」）：
      //   把背景整层套进一个**与内容同一条挤压**的容器里。
      //
      // ## 原来为什么不弹
      //
      // 关播放器时那一记"弹"是 `morphSquashY`（竖向压扁）驱动的，它挂在**路由壳**
      //   （`PlaybackPageRoute.ets` 的 `.scale({y: morphSquashY})`）与迷你条上。
      //   而上一批我把背景**搬出了形变容器**、挂到本页根 `Stack` —— 根 `Stack` **不在路由壳那个
      //   scale 的作用域里**（路由壳的 scale 只压它自己那棵子树里的东西）⇒ 内容弹、背景纹丝不动。
      //
      // ## 现在怎么弹（且形状正确）
      //
      // 外面套一层容器，给它 `.height(H × k)` + `.offset({y: −H(1−k)/2})` + `.scale({y: k})`，
      // 使它的**视觉矩形恒等于 `0 … H·k²`**、且**绕窗口中心**压扁：
      // ```
      //   布局矩形 y ∈ [−H(1−k)/2 , −H(1−k)/2 + Hk]
      //   （`.offset` 只挪绘制盒，`Alignment.TopStart` 下未偏移时应为 [0, Hk]
      //     ⇒ 减去 H(1−k)/2 得到上面这个区间）
      //   布局中心 y_c = (−H(1−k)/2 + (−H(1−k)/2 + Hk))/2 = H(2k−1)/2 = Hk − H/2
      //   `.scale` 绕**自身中心**缩放 ⇒ 中心不动、高度 ×k
      //   视觉高度 = Hk² 、视觉中心 = Hk − H/2
      //   ⇒ 视觉 top = (Hk − H/2) − Hk²/2 = H(2k − 1 − k²)/2 = −H(1−k)²/2
      //   ⇒ 视觉 bottom = 视觉 top + Hk² = H(2k − 1 + k²)/2 = H(1+k)²/2 − H
      // ```
      // **两端都严格正确**：`k = 1` ⇒ `[0, H]`（= 整屏，逐像素等价）；
      // `k = SQUASH_Y` ⇒ 视觉矩形恰好是"绕窗口中心把满屏压到 k"的结果：
      //   `(H − Hk)/2 = H(1−k)/2`…… 代入 `k` 化简得 `视觉 top = H(1−k)²/2`，
      //   而"绕中心压到 k"的 top 是 `H(1−k)/2` ⇒ 两者在 `k = 1` 与 `k → 0` 处一致、
      //   中间态最多差 `H(1−k)(k)/2`。
      //   ⚠️ **这是本次唯一一处"近似"**，如实登记：静止态（`k = 1`）**逐像素不变**是红线，
      //     形变中间态那几 vp 的偏差要上机看 —— 若真机上"压缩时背景上下露边"，
      //     就把 `.scale` 换成 `.scale({centerY: '50%'})` 之外的另一条路（用两层裁剪补偿），
      //     那时再改，**不要现在凭猜加常数**。
      // ★★★ 2026-10-16（**照搬无界的层级**：背景回到形变容器**内部**）
      //
      // ## 我之前错在哪（连错三轮，用户四次实测打回）
      //
      // 我一直以为无界的 `MeshCoverBg` 在 `playerPane` **之外**，于是把它搬到本页根 `Stack`
      // ⇒ 它**从第一帧就整屏**、而且**裁不到**。用户实测「**播放器展开还是背景全屏**」。
      //
      // 本轮把无界的**容器树**一路读通了（`wujie.pa`）：
      // ```
      //   @36**#  (190941)  observeComponentCreation2(Stack, @36***#)   ← 根 Stack
      //   @36***# (191388)  Stack(TopStart)
      //                       .scale({x: expand.scaleValue, y: …})      191400-191415
      //                       .translate({x: expand.translateX, …})     191416-191431
      //                       .width(expand.clipWidth)                  191432-191441
      //                       .height(expand.clipHeight)                191442-191451
      //                       .borderRadius(expand.radius)              191452-191461
      //                       .clip(true)                               191462-191469
      //                       .id(PLAYER_ROOT_ID)                       191470-191478
      //                     ├─ If (191716 @36***#^4 → @36***^4*#/^1)
      //                     │    └─ Column (191756 @36***#^5)
      //                     │         ├─ If (191972 @36***#^7 → @36***^7*#)  = **playerPane**（Row）
      //                     │         └─ If → **MeshCoverBg**              192105 / 192191
      //                     └─ …
      // ```
      // ⇒ **`MeshCoverBg` 在 `PLAYER_ROOT_ID` 那个 Stack 的里面**
      //   ⇒ 它**跟着容器一起 scale、一起被 clip**。
      //   这就是"展开时背景不会整屏、而是从小窗口里长出来"的机制。
      //
      // ⚠️ 我上一版那句"无界的 MeshCoverBg 在 playerPane 之外（与它同级）"**是错的**，
      //   来源是只看了片段、没把 `PLAYER_ROOT_ID` 那个 Stack 的**闭合范围**读出来。
      //   （`RzdMusic记忆.md` §56.50 里也是这么写的 —— 一并作废。）
      //
      // ## 搬回去之后同时解决的两件事
      //
      // 1. **展开不再"背景全屏"**：形变期容器只有迷你条那么大 ⇒ 背景也只在那一小块里，
      //    随容器长大而铺开（这才是"飞上来"的观感）；
      // 2. **关闭时背景跟着一起压**：容器本来就在路由壳那条 `morphSquashY` 的作用域里
      //    （`PlaybackPageRoute.ets` 的 `.scale({y})` 压整个播放页）⇒ **不再需要我上一版
      //    加的那个 `.scale + height + offset` 补偿容器**（已删除，见 `squashWrapHVp` 的删除记录）。
      Column() {
        Stack() {
          // ★ 背景 = **半透明 → 不透明**：底色与取色层一起走反编译的
          //   `pullBgIn = clamp(effT / 0.30)`（0 → 0.30 淡入）。
          // ⚠️ 上面那两句（"底色与取色层一起走 `pullBgIn`"）★ **已作废**：
          //   自 2026-10-15 起，那两层**整屏纯色层已经整层删除**（下面就是删除后的现场）。
          //
          // ★★ 2026-10-15（照搬无界）：**无界没有纯色垫底，网格本身就是底**。
          //   依据 `_recover/logic-src/无界vs派音-差异分析.md` L303-304：
          //     ① 「`Column().backgroundColor('#1c1c1e').opacity(...)` 近黑垫底层」→ 无界侧 **无**；
          //     ② 「`Column().backgroundColor(state.imageColor)` 封面取样色层」→ **没有对应物**。
          //   两层都是派音旧路；它们叠在网格之下，只会让"展开开始那一刻"多出一块灰暗罩子
          //   （见 `backgroundRevealOpacity()` 的注释）。
          //
          //   ★ 那层"静止态不透明底"现在搬到了**路由壳**上（这是无界的位置：
          //     `wujie.pa:190867-190884` 的 `.backgroundColor(pullMode && effT()>=1 ?
          //     PULL_REST_BG : expand.overlayColor)`），落点见
          //     `PlaybackPageRoute.ets` 的 `PlaybackPageRouteShell`：
          //       · 形变期透明 ⇒ 窗口外透出首页与迷你条（形变的前提）；
          //       · 静止态不透明 ⇒ 播放页自己的底，顺带盖住状态栏与底部那两条
          //         （用户实测「内容没延伸进状态栏」「底部一条空白漏出后面内容」）。
          //     ⇒ 所以**页面内不再需要**任何整屏纯色层，删掉它不会出现"背景空一块"。
          //
          //   ⚠️ 下面网格那层的 `backgroundRevealOpacity()` **保留**：它就是无界的 `pullBgIn`
          //      （起点 0、跟着形变进度到 1），静止态恒为 1。

          // ⚠️ 紧随其后的那段"实时模糊底图"说法★ **也已作废**：那张 `Image(封面).blur(11)`
          //   已整层删除 —— 它原先只作"网格源缺席时的兜底"，而兜底现在改成了**纯取样色**
          //   （见下面 `else` 分支）。删它的原因：它等于**在网格之外又画了一张封面**，
          //   换来用户实测的「那个两张封面只会在动画过程中出现」。
          //   ⇒ `backdropBlurRadiusVp()` / `LIVE_BACKDROP_BLUR_VP` / `originalCoverSource()`
          //     现在**已无调用者**（留在文件里是为了不牵动 `isPixelMapCover` 那条类型分支；
          //     它们的整体清理归入"删派音遗留"那一块，见 `RzdMusic记忆.md` §56.6）。
          // ★★ 2026-10-15（照搬无界）：背景底座换成 **网格形变背景**（`MeshCoverBg`）。
          //   规格：`_recover/logic-src/播放页背景-MeshGradient与MeshSource定稿.md`
          //   （`MESH_SUB=4`、`SRC_EDGE=64`、`boxBlur(9,3)`、`displaySync` 20fps、闸门 = `playing && active`）。
          //   它自带**径向暗角**（`scrim` 默认 true），所以下面那层独立的 `radialGradient`
          //   在网格生效时必须关掉，否则会叠两份暗角。
          //   ⚠️ 网格源还没建好（换歌那一瞬）时**退回实时模糊那张图**，不会出现"背景空一块"。
          // 流光背景（设置项开关）：必须在内容层之前绘制，否则会盖住封面和歌词
          if (this.flowLightState.enabled) {
            this.FlowLightBackground()
          }

          // ★★ 2026-10-15：**径向暗角**（`无界vs派音-差异分析.md` §3.4「对齐建议 · ④ 只加径向暗角」）。
          //   这一条是那份文档给的**最小路线**：纯声明式、零新依赖、立刻可感
          //   —— 与"网格流动背景"（`MeshCoverBg`：`NodeContainer` + 自定义 `RenderNode.drawPixelMapMesh`
          //   + `displaySync` 逐帧顶点，见 `播放页背景-MeshGradient与MeshSource定稿.md` §4）**分开**：
          //   那套本轮**不做**，这里只叠一层径向压暗。
          //
          //   逐项数值都取自文档（`[单源]`，出处写明以便复核）：
          //   `无界vs派音-差异分析.md` §3.4 组件树末行与「④」那一段 —— 无界
          //   `MeshCoverBg` 的 `Stack` **最上面**就是这一层 `Column().radialGradient(...)`，
          //   而我们的 `Stack` 里"内容层"（`buildControlStack`）也是最后画的。
          //   ⇒ 为了不吃到内容层，这里放在**封面底图层之后** —— 它在栈里的绘制位置
          //      与无界"压在整个背景之上、内容之下"的语义等价（无界那一层之下是网格背景，
          //      我们的内容层是**不透明**的独立层，不受它影响）。
          //   · `center: ['50%', '50%']` —— 圆心在正中（文档同处）；
          //   · `radius: '70%'` —— 文档同处；官方 `ts-universal-attributes-gradient-color`
          //     （2026-10-15 取的原文）：「径向渐变的半径，number 类型时单位为 vp，
          //     设置的值为 undefined 时系统按组件尺寸自动算」⇒ 这里给**百分比字符串**，
          //     随容器（= 整屏）走，不是固定 vp；
          //   · `colors: [['#26000000', 0], ['#26000000', 0.45], ['#66000000', 1]]`
          //     —— 文档 §3.4 常量表：`SCRIM_CENTER = "#26000000"`（α≈15%）、
          //     `SCRIM_EDGE = "#66000000"`（α=40%），中心色一直铺到半径的 45% 才开始压暗；
          //     （实现里写成等值的十六进制字面量 `0x26/0x66`，与同文件其余渐变/底色写法一致。）
          //   · 色标的第二个元素是**比例 [0,1.0]**，不是 vp —— 这三处 0 / 0.45 / 1 本来就是
          //     比例写法（同 §71.1 那条单位坑；官方原文「取值范围为 [0, 1.0]」）。
          //
          //   ⚠️ 与无界的一处**已知差别**：无界那一层是**恒开**（只由 `scrim` 布尔门控），
          //      我们这里在**形变/转场期间关掉**（复用 `backgroundRevealOpacity()` 同款的
          //      `morphContainerActive()` 判据）—— 否则形变中那个被 scale+clip 的小窗口里
          //      会多一层压暗，与"半透明 → 不透明"那条既有口径打架。
          //      观感是否要改成恒开，**只能上机看**（见本轮报告的"只能上机确认"清单）。
          // ★ 网格背景自带暗角 ⇒ 只有**退回模糊底图**那条路才需要这一层
          //   （否则会叠两份暗角，中心被压两遍）。
          if (this.meshSrc === undefined) {
            Column()
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
              .radialGradient({
                center: ['50%', '50%'],
                radius: '70%',
                colors: [[0x26000000, 0.0], [0x26000000, 0.45], [0x66000000, 1.0]]
              })
              // ★★★ 2026-10-17（用户：「上拉打开有背景，**点击展开 / 关闭 / 系统返回没有背景**」）
              //
              // ## 机制（读代码 + 两个读数即得）
              // ```
              //   网格层是 `if (meshSrc === undefined) { 兜底 } else { MeshCoverBg(...) }`
              //   点击展开 / 关闭发生得早，此时 `song.cover` 还没到手 ⇒ meshSrc === undefined
              //   ⇒ 网格不挂载；而兜底这两层的暗角层原来写着
              //        .opacity(morphContainerActive() ? 0 : 1)
              //     ⇒ **形变期正好把它关掉** ⇒ 屏上只剩近黑取样色 = "没有背景"
              //   上拉打开总是发生在封面加载完之后 ⇒ 网格在 ⇒ 正常 ✓
              // ```
              // ## 改法
              //   兜底层的暗角**不许在形变期消失** —— 它此刻是**唯一的背景**。
              //   （网格存在时这条分支根本不进，所以不会和网格自带的暗角叠两份。）
              .opacity(1)
              .hitTestBehavior(HitTestMode.None)
          }

          // 封面续飞浮层：夹在背景与内容之间，切页那 0.36 秒里顶替两张静态封面
          // No cover overlay: the lyric page has no matching image destination.

          // ★★ 2026-10-15 用户实测两条，这一处是共同的根：
          //   「**小歌词是从我封面背后出现**，不是从下方飞上来」+「进度条会被挡住（像是封面挡的）」
          //   ⇒ 续飞封面原来画在**整页内容之上**（根 Stack 的最后一个孩子），于是
          //     · 从下升起的**小歌词**先被它挡着 ⇒ 看起来是"从封面背后冒出来"；
          //     · 同样从下升起的**控制区**（进度条+按钮）也会被它压住。
          //   现在把它挪到**内容层之前**：形变期间播放页自己那张真封面是隐藏的
          //   （`realCoverVisible()` 为假 ⇒ 封面槽位是空的、透明的），所以续飞封面照样透得出来、
          //   位置与大小一模一样（它本来就是按"迷你条封面 → 播放页封面"插值画的）；
          //   而**所有升上来的内容都在它之上** ⇒ 两组飞入都能被看见，也不再互相遮挡 ——
          //   这是结构上的保证，与"量得准不准"无关。
          //   ⚠️ 不要再挪回去（§47 那次"看不见"是我同一轮加的 `barOpacity` 把迷你条真身也藏了造成的，
          //      那个门已经删除；本节这版没有它）。
          // ★★ 2026-10-15（壳层浮层那一轮）：**播放页不再画这张续飞封面** ——
          //   `hostsMorphOverlay()` 为真（手机/平板形态）时，那一棒已经**搬到壳层浮层**
          //   （`products/default/src/main/ets/pages/Index.ets` 的 `MorphCoverClone()`），
          //   并且由**它自己的进度** `morphOverlayP` 驱动（560ms，
          //   `curves.cubicBezierCurve(0.23, 1.0, 0.32, 1.0)`）。
          //   留在播放页里画的那一版有一个结构性毛病：它在这个**被 scale+translate 变换过、
          //   还带 `.clip()` 与动态 `.height(morphClipHeight())` 的容器**里，矩形却是窗口坐标
          //   ⇒ 只有 p=1（恒等变换）才严格正确，中途只能"近似"，历史上反复出"前半段看不见 /
          //   被别的东西挡住"。浮层那份不在这个容器里，没有这个问题。
          //   ⚠️ 判断条件不是"p 到没到"，而是**宿主有没有接管**（见 `hostsMorphOverlay()`）：
          //     PC 壳层（`products/pc`）还没接这份浮层，那边**继续由播放页自己画**
          //     —— 否则会出现"两边都不画"的**无封面**空档。
          //   ⚠️ 播放页自己那张**真封面**在形变期间仍然不画（`realCoverVisible()` 那把门没动），
          //     否则会出现两个封面；两者严格互补。
          if (this.expandState.morphBridging() && !this.expandState.hostsMorphOverlay()) {
            this.MorphCoverBridge()
          }

          // ★★★ 2026-10-16（**照搬无界的层级**：背景在形变容器**内部**）
          //
          // ## 我之前错在哪（连错三轮，用户四次实测打回「播放器展开还是背景全屏」）
          //
          // 我一直以为无界的 `MeshCoverBg` 在 `playerPane` **之外**，于是把它搬到本页根
          // `Stack` ⇒ 它**从第一帧就整屏**、而且**裁不到**。
          //
          // 本轮把无界的**容器树**一路读通了（`wujie.pa`）：
          // ```
          //   @36**#  (190941)  observeComponentCreation2(Stack, @36***#)   ← 根 Stack
          //   @36***# (191388)  Stack(TopStart)
          //                       .scale({x: expand.scaleValue, y: …})      191400-191415
          //                       .translate({x: expand.translateX, …})     191416-191431
          //                       .width(expand.clipWidth)                  191432-191441
          //                       .height(expand.clipHeight)                191442-191451
          //                       .borderRadius(expand.radius)              191452-191461
          //                       .clip(true)                               191462-191469
          //                       .id(PLAYER_ROOT_ID)                       191470-191478
          //                     ├─ If (191716 @36***#^4)
          //                     │    └─ Column (191756 @36***#^5)  ← 满窗宽 + winHVp + padTop/padBottom
          //                     │         ├─ If (191972 @36***#^7 → @36***^7*#) = **playerPane**（Row）
          //                     │         └─ If → **MeshCoverBg**             192105 / 192191
          //                     └─ …
          // ```
          // ⇒ **`MeshCoverBg` 在 `PLAYER_ROOT_ID` 那个 Stack 的里面** ⇒ 它**跟着容器一起
          //   `scale`、一起被 `clip`**。这才是"展开时背景不会整屏、而是从小窗口里长出来"的机制。
          //
          // ⚠️ 我此前那句"无界的 `MeshCoverBg` 在 `playerPane` 之外（与它同级）"**是错的** ——
          //   来源是只看了片段、没把 `PLAYER_ROOT_ID` 那个 Stack 的**闭合范围**读出来。
          //   （历史注释里凡这么写的一并作废。）
          //
          // ## 放在容器里同时解决两件事
          //
          // 1. **展开不再"背景全屏"**：形变期容器只有迷你条那么大 ⇒ 背景也只在那一小块里，
          //    随容器长大而铺开；
          // 2. **关闭时背景跟着一起压**：容器本来就在路由壳那条 `morphSquashY` 的作用域里
          //    ⇒ 不再需要我上一版加的 `.scale + height + offset` 补偿容器（已删）。
          //
          // ⚠️ 位置：容器 `Column` 的**第一个孩子**（背景在下、内容在上），
          //   `.position({x:0,y:0})` 覆盖整个容器 ⇒ 不参与纵向排布（否则会把内容挤下去）。
          Column() {
            if (this.meshSrc !== undefined) {
              MeshCoverBg({
                src: this.meshSrc,
                srcVersion: this.meshSrcVersion,
                playing: this.state.isPlay,
                active: this.state.isShowPlay,
                // ★ 照搬无界：`entryFade = !pullMode || effT() >= 1` —— 形变进入时不淡入
                //   （那一刻整层的不透明度已由 `backgroundRevealOpacity()` 管着）。
                entryFade: !this.expandState.morphContainerActive()
              })
                .id(PlaybackPage.MESH_BG_ID)
                .width(StyleConstants.FULL_WIDTH)
                .height(StyleConstants.FULL_HEIGHT)
                .opacity(this.backgroundRevealOpacity())
                .hitTestBehavior(HitTestMode.None)
                .onAreaChange((): void => {
                  this.logBgLayer();
                })
            } else {
              // 网格源缺席（换歌那一瞬 / 取图失败）时的兜底：**纯取样色**，不再退成一张封面图
              //（否则会出现"同一张封面在屏上两次"，见历史记录）。
              Column()
                .width(StyleConstants.FULL_WIDTH)
                .height(StyleConstants.FULL_HEIGHT)
                .backgroundColor(this.state.imageColor)
                .opacity(this.backgroundRevealOpacity())
                .hitTestBehavior(HitTestMode.None)
            }
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .position({ x: 0, y: 0 })
          .hitTestBehavior(HitTestMode.None)
          // ★★★★ 2026-10-17（用户：「现在背景是**从压扁的状态展开**」—— 修成无界那样"从下往上揭开"）
          //
          // ## 为什么会压扁
          //   背景层在**形变容器内部**，而容器的 `.scale(morphScale)` 在 p=0 时约 **0.082**
          //   ⇒ 背景（网格）被等比压到 8% 再撑开 ⇒ 观感就是"压扁 → 展开"。
          //   无界不是这样：它的背景是**满尺寸**的，只是被**裁剪窗口**从下往上揭开。
          //
          // ## 照搬做法
          //   给背景这一层乘一个**反缩放** `1 / morphScale` ⇒ 与容器的 `morphScale` 抵消
          //   ⇒ 背景在屏上**始终是满尺寸**，再由外层容器的 `.clip` + 增长的窗口去"揭开"它。
          //   · `centerY: '100%'`：反缩放**以底边为锚** ⇒ 背景的底边始终贴着容器底边
          //     ⇒ 窗口从迷你条往上长时，是**从下往上**露出背景（= 用户要的"从下面上来"）；
          //   · 静止态 `morphScale = 1` ⇒ 反缩放 = 1 ⇒ **逐像素不变**（回归红线）；
          //   · 窗口尺寸/缩放异常时返回 1（不做补偿），宁可压扁也不画出空白。
          .scale({
            x: this.bgInverseScale(),
            y: this.bgInverseScale(),
            z: 1,
            centerX: '50%',
            centerY: '100%'
          })
          // ★★★ 2026-10-16（**背景层自证** —— 见 `diagBgBox` 的注释）：
          //   量的是**本层（背景宿主）**的布局矩形。用户报"有背景但高度特低"时：
          //     · `bgH` 很小而 `clipH` 也小 ⇒ 正常（动画中段，容器就只有那么大）
          //     · `bgH` 很小而 `clipH` 不小 ⇒ **百分比链断了**（背景没铺满容器）
          //     · `bgH` 正常 ⇒ 问题在**不透明度**（看 `bg`）或**绘制**（不是布局）
          .onAreaChange((_oldArea: Area, area: Area): void => {
            const w: number = areaLengthToVp(area.width);
            const h: number = areaLengthToVp(area.height);
            this.diagBgBox = `${w.toFixed(0)}x${h.toFixed(0)}`;
          })

          // ★ 内容层：尺寸恒为 100%（= 裁剪窗口 = 可视矩形 / 缩放），所以永远填满可视矩形
          Column() {        Column() {
              this.buildControlStack()
            }
            // ★ 老路径（几何没量到时的兜底）：内容层贴着底边，高度从"贴底一条"长到 100%
            .height(this.sheetHeightPercent())
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .justifyContent(FlexAlign.End)
          .clip(true)
          // ⚠️ 这里**不再**给整层加透明度/底色：透明度已按反编译拆成三层窗口
          //   （背景 `pullBgIn` / 顶栏 `pullChromeOpacity` / 底栏 `pullBottomIn`），
          //   底色由形变容器里那个取色层负责，否则静止态会少一层颜色。
          // ⚠️ 上拉打开**不在这里做**：它必须挂在壳层（products）。
          //    播放页在 `isShowPlay=false` 时还没挂载，页面收不到手指事件。
          //    职责划分：**上拉=壳层/迷你条（→ morphP 0→1），下拉收起=本页（→ morphP 1→0）**。
          //
          // ⚠️ 这里**什么都不上报**（既不上报尺寸，也不再上报原点）。
          //    本层就是手机侧的 `MORPH_HOST_ID`，而它的高度是**裁剪窗口高度**
          //    （形变期间 ~60vp → 满屏），`globalPosition` 也跟着 translate 走 ——
          //    拿它当"铺满目标"就是第五次自噬（一块黑底 + 播放页展不开），
          //    拿它当"坐标原点"就是让原点追着自己的中间态跑（起点/克隆层整体错位）。
          //    **坐标口径全链统一窗口坐标**（量测本来就是窗口坐标，克隆层的
          //    `.position()` 也落在满屏 Stack 上，同口径），所以根本不需要原点换算。
          //    形变尺寸的唯一权威是壳层按 `windowSize` 上报的 `reportWindow`。
          .onAppear(() => {
            this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            this.isAlive = true;
            this.getImageColor();
            this.applyPlaybackWindowChromeImmediately();
            // 页面首次出现时同步一次开关状态（设置页可能刚改过）
            this.applyFlowLightColors();
            // ★★★ 2026-10-16（**删掉 `playbackSwiperIndex = 0`；索引归"打开意图"管**）
            //
            // ## 原来那句为什么有害
            //   它是**节点级回调**（本 `Column` 的 `.onAppear`，分支重建也会跑）里的写入，
            //   而 `playbackSwiperIndex` 是"Swiper 当前页"的唯一状态，且现在
            //   **绑到了 `Swiper.index()`**（见 `Swiper()` 上方那段长注释）。
            //   两者放一起就是这个形状：
            // ```
            //   用户从底部状态栏"正在播放"进播放器 → 打开意图把索引置 0（设计如此，见
            //     PlaybackIntentShell）→ 用户滑到歌词页（索引 = 1，`lyricMorphT` = 1）
            //   某个节点重建 ⇒ 本 `onAppear` 又跑一次 ⇒ 索引被写回 0
            //   ⇒ `Swiper` 跳回封面页 + `lyricMorphT` 与新页不一致
            //   ⇒ 观感：**在歌词页，封面却不变小**（用户 2026-10-16 真机截图实测）
            // ```
            //   ⚠️ 而且这个"复位"对**冷启动那条路本来就多余**：打开播放器时
            //      `PlaybackIntentShell` / `ProductViewModel` 那一条已经把索引置 0 了
            //      （它是"打开意图"的一部分）。节点级回调再抢一次只会把用户**当前页**打掉。
            //
            // ## 现在的分工（单一真源，别再混合）
            //   · **打开播放器** ⇒ 由打开意图置 `playbackSwiperIndex = 0`（本页不参与）；
            //   · **用户滑动**   ⇒ `.onChange` 写索引 + `.onAnimationStart` 驱动 `lyricMorphT`；
            //   · **节点出现**   ⇒ 只同步"本页自己的视觉状态"，**不碰用户在哪一页**。
            //
            // ## 与"封面续飞"那一对的关系（这里的复位**必须留**）
            //   下面两句是**本页自己的派生状态**，不是"用户在哪一页"：
            //   `lyricMorphT` / `lyricMorphVisible` 描述的是"封面飞行动画进行到哪"，
            //   节点重建后必须回到静止态（否则会停在一个补间中间态）。
            //   ⚠️ 但**索引为 1 时不能盲目把 `lyricMorphT` 归 0** —— 那会让"在歌词页"这一帧
            //      的封面变回大封面（正是本次要修的现象）。⇒ 按索引决定静止态：
            // ```ts
            //   this.lyricMorphT = this.playbackSwiperIndex === PlaybackPage.SWIPER_INDEX_LYRIC ? 1 : 0;
            // ```
            //   即"静止态 = 当前页对应的端点"，这也是 `lyricMorphT` 两个稳定值的定义。
            //   ★ 2026-10-16（第二版）：这里原来是一句内联三元。现在收敛进
            //     `syncLyricMorphToPage()` —— 因为**同一个对齐动作在挂载时也要做一次**
            //     （`aboutToAppear`），两处必须同一口径（见那个方法的注释）。
            this.syncLyricMorphToPage('appear');
            // ⚠️ 这一句**必须留在外面**：`syncLyricMorphToPage()` 在"已经对齐"时会**早退**，
            //   而"节点重建后不许停在补间中间态"这条要求每次 `onAppear` 都要满足。
            this.lyricMorphVisible = false;
            // 控制区：进来先唤出，3 秒没动自动收起
            this.chromeCollapsed = false;
            this.touchChrome();
            // ★ 2026-10-15 诊断：落位之后再量一次四个块的窗口矩形（见 `logLayoutBoxes()`）。
            //   480ms 取"展开补间（最长 560ms 的浮层那条 + 20ms 收尾）基本走完"的量级；
            //   排查关键字 `RzdBoxes`。⚠️ 只读，不影响任何状态。
            setTimeout((): void => {
              if (this.isAlive) {
                this.logLayoutBoxes();
                // ★ 目标 ④ 的 S1 步自证（排查关键字 `RzdSizeTier`）：
                //   核对 `sizeScaleOf` / `topPageSideOf` 在**手机档**上是否恰好等于我们
                //   已经在用的固定值（`sizeK = 1` / `side = 16`）—— 期望 `fixedOk=true`。
                this.expandState.logSizeTier(this.breakpointEnv.widthBreakpoint);
                // ★ 目标 ④ 的 S2 步自证（排查关键字 `RzdWideCols`）：
                //   把宽屏 / 面板两档的**占比与两栏宽度**打出来（手机上它们不参与布局，
                //   只是把数算出来备查）。间距（gutter/space）**不在其中** —— 见 S2 的注释。
                this.expandState.logWideColumns(this.breakpointEnv.widthBreakpoint, this.usePanelLayout(),
                  this.getUIContext());
              }
            }, 480);
            // ⚠️ 上拉打开时进度已经在拖动中走了一部分，这里不能重置；
            //    点击/起播意图打开时进度是 0（见 aboutToAppear）。
            this.collapseProgress = 0;
            // ★★ 2026-10-15（照搬无界）：**形变会话归壳层时，本页不起任何展开补间**。
            //   无界那边播放页自己不播展开 —— 它只是被壳层的 `ExpandAnimation`
            //   按 `scale/translate/clip` 推着变，补间在壳层（`settlePullOpen`）。
            //   本页此刻只做一件事：**把绘制门打开**（几何已经是壳层压好的起点）。
            //   ⚠️ 这里**不许**再无条件调 `playExpandIntro()`：它会走 `tryStartMorphIntro()`，
            //      而那条路要"量到终点锚点"才肯起补间、量不到就退化成
            //      `playLegacyExpandIntro()`（贴底一条长上来 = 派音旧动画）
            //      ⇒ 同一个入口有时是新动画、有时是旧动画，正是「新旧打架」的形状。
            //
            // ★★★ 2026-10-16（**点击打开没有封面/背景动画的真根因**）：
            //   判据原来只有 `morphContainerActive()`，**点击路径在挂载那一刻它还是假**：
            //   ```
            //     点击：壳层 beginOpenMorphOnClick → pullOpenBegin
            //            → prepareMorphEntry 发现"播放页还没挂载、封面量不到"
            //            → 走 !ready 分支：morphStage = ENTERING、morphDrive = FINGER
            //            → 但（同上）**morphUsable = false、morphP = 0** ⇒ morphContainerActive() 为假
            //            → pushPlayerRoute → 本页 onAppear ⇒ 掉进 else 分支 ⇒ **播派音旧动画**！
            //     上拉：壳层 onPullOpenStart → pullOpenBegin，**在页面挂载之前**就
            //            morphBeginEntering()（那时迷你条量得到）⇒ 挂载时 stage = ENTERING ⇒ 走对分支
            //   ```
            //   ⇒ 补一条判据：**壳层已经为这一轮起过形变会话**（`morphSessionStarted`
            //     由 `prepareMorphEntry` 第一步置位，三条入口都会经过它）。
            //     它成立 ⇒ 这一页的第一帧就该"不画"（等壳层把几何压到起点），
            //     而不是自己开始播那套 `collapseProgress` 旧动画。
            if (this.expandState.morphContainerActive() || this.expandState.morphSessionStarted) {
              this.diagAppearBranch = 'morph';
              this.introPaintReady = true;
              this.expandIntroRunning = false;
              // ★★ 2026-10-16（点击路径的**几何补量**）：
              //   点击打开时 `pullOpenBegin` 是在"播放页还没挂载"那一刻跑的 ⇒ 它很可能
              //   拿不到终点锚点（播放页封面节点还不存在）⇒ `morphUsable = false`。
              //   壳层那边有 12×32ms 的补量窗口（`schedulePullAnchorRemeasure`），
              //   但那是**壳层**的节奏；本页挂载那一刻是"封面节点**刚刚存在**"的**最早**时机，
              //   在这里补量一次，比等壳层下一拍（最多 32ms 之后）更准。
              //   ⚠️ 三步走，缺一步就会"补量成功但相位还停在旧态"：
              //     ① `prepareMorphEntry` —— 量几何 + `morphInitParams` + 压到起点；
              //     ② `morphBeginEntering` 已经由它内部调过（ready 时）；
              //     ③ 补量成功后**必须**把浮层那一棒的补间也起起来（否则封面仍然不飞）。
              setTimeout((): void => {
                if (!this.isAlive || this.isClosing) {
                  return;
                }
                this.diagRemeasureTries = this.diagRemeasureTries + 1;
                // ★★★ 2026-10-16（**同一形状的第 3 处**：又是"算出来了"当成"量到了"）：
                //   这句原来是 `if (morphUsable) { return; }` —— 而 `morphUsable` 是
                //   `morphInitParams()` 的结论：**只要 barW/boxW 量到了它就为真**，
                //   **根本不管终点锚点有没有**。于是点击打开这条路上：
                // ```
                //   pullOpenBegin → morphInitParams() 成功（迷你条有几何）⇒ morphUsable = true
                //   挂载 → 这里读到 morphUsable === true ⇒ **直接 return**
                //        ⇒ 本页这次"最早的补量时机"被白白丢掉
                // ```
                //   而终点锚点在**本页挂载之前**是绝对量不到的（节点还不存在）
                //   ⇒ 就只剩壳层那条 12×32ms 兜底，两条并行的补量**一条都没跑**。
                //   ⇒ 判据换成 {@link PlayerExpandState.morphGeomReadyNow}（= 无界 `pullGeomReady`，
                //     只有真的量到终点那一拍才为真）。**本页挂载这一刻正是"终点节点刚存在"的最早时机**。
                //   ⚠️ 与 `morphUsable` 的分工见那个字段的注释，别再混用。
                if (this.expandState.morphGeomReadyNow()) {
                  return;
                }
                this.expandState.pushMorphTrace('appearRem');
                UIUtils.applySync((): void => {
                  this.expandState.prepareMorphEntry(this.getUIContext(), true);
                });
                if (this.expandState.morphGeomReadyNow()) {
                  this.diagOverlayKicks = this.diagOverlayKicks + 1;
                  this.expandState.focusMorphOverlayForPageIntro(this.getUIContext());
                  Logger.info(PlaybackPage.logTag,
                    `RzdMorphOnAppear remeasured usable=${this.expandState.morphUsable} ` +
                    `stage=${this.expandState.morphStage} drive=${this.expandState.morphDrive} ` +
                    `overlayP=${this.expandState.morphOverlayProgress().toFixed(3)}`);
                }
              }, 0);
            } else {
              // 兜底：形变没起来（几何没量齐的退化路径）仍旧走老那套，别让页面打不开。
              //
              // ★★★ 2026-10-16（**修用户实测「下拉关闭后，动画结束了突然又放一遍展开」**）
              //
              // ## 这条分支为什么会在"关闭"时被走到
              // 本 `.onAppear()` 是**节点级**回调 —— 它会在**分支重建**时也触发，
              // 不只是"页面被打开"那一次。而关闭链路里 `morphReset()` 会把
              // `morphSessionStarted` 清回 false（`morphStage` 变成 NONE）⇒
              // 上面那个 `if` 的两个判据**同时变假** ⇒ 落到这里 ⇒ **重放一遍展开动画**。
              //
              // ## 判据（三道，**第三条是跨实例的**）
              //   ① `isClosing` 由关闭链路置真（`closeFullScreenPlayback()` 首部）；
              //   ② `morphStage === LANDING` —— `morphLand()` **只在关闭路径**被调
              //      （全工程清点：`PlaybackPage` 两处 + `Index:1088`）⇒ 是"已交还迷你条"的相位；
              //   ③ ★ `lastCloseAtMs` 时间窗 —— **跨实例**共享（见那个静态字段的注释）。
              //      ⚠️ ①② 都是**实例局部**的：新实例的 `aboutToAppear` 会把 `isClosing`
              //         **无条件清回 false**，`morphReset()` 又把 `morphStage` 归 NONE
              //         ⇒ 关闭余波落在新实例上时**两条全瞎** ⇒ 必须靠 ③。
              //      ⚠️ ③ 的写点**只有** `closeFullScreenPlayback()` 首部一处（两处成对，
              //         上一轮就是漏了那个写点、门恒假 ⇒ 白改一轮）。
              const sinceCloseMs: number =
                PlaybackPage.lastCloseAtMs > 0 ? Date.now() - PlaybackPage.lastCloseAtMs : -1;
              if (this.isClosing || this.expandState.morphStage === MorphStage.LANDING ||
                (sinceCloseMs >= 0 && sinceCloseMs < PlaybackPage.CLOSE_WINDOW_MS)) {
                this.diagAppearBranch = 'skipClose';
                PlaybackPage.ev('AP', `skipClose since=${sinceCloseMs}`);
                Logger.info(PlaybackPage.logTag,
                  `RzdMorphOnAppear skip intro: closing. isClosing=${this.isClosing} ` +
                  `stage=${this.expandState.morphStage} sinceClose=${sinceCloseMs}ms ` +
                  `p=${this.expandState.morphP.toFixed(3)}`);
                // ★ 除"不播动画"之外还必须**把几何落定**：
                //   否则容器可能停在被中断的中间 scale（用户报的"背景只剩一条"同源）。
                this.expandState.morphSettleOpen();
                this.introPaintReady = true;
              } else {
                this.diagAppearBranch = 'intro';
                PlaybackPage.ev('INTR', `sinceClose=${sinceCloseMs}`);
                this.playExpandIntro();
              }
            }
          })
          .onDisAppear(() => {
            // ★★ 2026-10-16：**先取"卸载那一刻"的 isAlive 快照**。
            //   下面那行会把 `isAlive` 同步置 false，而本回调里的判据是**延时一拍**跑的 ——
            //   直接读字段的话永远读到 false ⇒ 判据里 `!isAlive` 那条恒真
            //   ⇒ 延时那道门等于没加（这正是上一版 `morphUsable` 那道门的同类错误：
            //     **判据读到的是"被自己改过之后"的值**）。
            const wasAlive: boolean = this.isAlive;
            this.isAlive = false;
            PlaybackPage.ev('DIS', `wasAlive=${wasAlive ? 1 : 0} show=${this.state.isShowPlay ? 1 : 0}`);
            // ★★★ 2026-10-16（**删掉这里那句同步的 `state.isShowPlay = false`**）：
            //   原来这里写着 `this.state.isShowPlay = false;`。它是一个**节点级**回调里的写入，
            //   而 `isShowPlay` 是**壳层路由的驱动源**（`Index.@Monitor('appState.isShowPlay')`
            //   → `popPlayerRoute()`）。两者搭在一起的后果是这个形状：
            // ```
            //   点击打开：壳层把 isShowPlay 置 true ⇒ 推入播放页路由
            //   同一帧/下一帧，**旧播放页实例**（或分支重建的那个节点）触发 onDisAppear
            //   ⇒ 它把 isShowPlay 写回 false
            //   ⇒ 壳层立刻 popPlayerRoute() ⇒ **刚打开的播放页被弹掉 / 动画被掐断**
            // ```
            //   ⚠️ 而且这是**幂等性反了的**一处：注释 `:2709` 自己写着
            //     「`isShowPlay` 若已是 false，`@Monitor` 不会重复动作」——那是"关闭链路"的语义。
            //     关闭链路上 `isShowPlay = false` 有**三处权威设置点**，都在
            //     `closeFullScreenPlayback()` 里、都在正确的时刻：
            //       · `:2712` 无锚点早退支
            //       · `:2729` 正常收起补间收尾支
            //       · `:2738` "没有可靠几何直接关闭"退化支
            //   ⇒ 本处**不需要**再写一次；留着只会让"打开"被自己误判成"关闭"。
            //   ⚠️ 若哪天真需要兜底（例如 Hard exit 走不到上面三处），
            //      **必须**先判"播放页路由确实已经不在栈里"再写 —— 否则又是这个形状。
            //      排查关键字：`route: push player` 与 `route: remove player at index=` 的时序。
            //
            // ★★★ 2026-10-16（**折中做法：留下安全网，但给它一个"只在下台时触发"的条件**）：
            //   直接删掉它有风险 —— `Hard exit`（例如系统把模态整个收掉、或别的模块直接
            //   `popPath`）时**没有任何人**会把迷你条交还回来。所以不删，改成"**只在确认
            //   播放页已经不在路由栈里**时才写"，并且**推迟一拍**（让同帧内可能发生的
            //   push 先落栈）：
            //     · 点击打开：那一拍栈里**已有**播放页 ⇒ 不写 ⇒ 不会被误判成关闭 ✓
            //     · 系统返回 / 关闭按钮：那三处权威点已经写过（`isShowPlay` 已是 false，
            //       重复写是幂等的空操作）✓
            //     · Hard exit 且没人写：那一拍栈里没有播放页 ⇒ 写 false ⇒ 壳层收尾 ✓
            setTimeout((): void => {
              if (this.playerRouteStillPushed()) {
                Logger.info(PlaybackPage.logTag,
                  'RzdMorphOnDisappear keep isShowPlay (player route still on the stack)');
                return;
              }
              if (!this.state.isShowPlay) {
                return;
              }
              Logger.warn(PlaybackPage.logTag,
                'RzdMorphOnDisappear fallback: player route gone but isShowPlay still true ⇒ release it');
              this.state.isShowPlay = false;
            }, 0);
            // 下一次打开重新走"先量再缩"的顺序：把绘制门也关回去
            this.introPaintReady = false;
            // ★ 页面卸载时复位"跟手会话"的两个标记。
            //   `pullDragging` / `morphDrive` 决定点击打开时要不要做形变初始化；
            //   只要有一轮手势没走到收尾（被系统抢走、中途卸载、硬关闭…）它就会残留，
            //   残留成 (true, FINGER) 时点击打开会**永远跳过形变**，
            //   退化成 `collapseProgress` 那套老动画（用户实测："点击/返回用的还是之前的动画"）。
            this.expandState.pullDragging = false;
            this.expandState.morphDrive = MorphDrive.NONE;
            // ★★★ 2026-10-16（**"点击打开没有动画"的源头就在这里**）：
            //   下面那句原来是**无条件**的 `morphReset()`。而 `morphReset()` 会
            //   **`morphGen++` 且 `morphUsable = false` 且 `morphSessionStarted = false`**。
            //   问题在于：**点击打开时，"新播放页的 `onAppear`"与"旧页面实例的 `onDisappear`"
            //   几乎同帧发生** ⇒ 这一句会把**刚刚由壳层建立好的新一轮形变会话**一起清掉
            //   ⇒ `morphUsable` 永远为假 ⇒ 容器停在恒等 ⇒ **背景整屏、没有动画**。
            //
            //   ⇒ 加一道门：**推迟一拍再清，并且"若那一拍已经有活着的会话就跳过"**。
            //     ★★★ 2026-10-16（**判据订正：`morphUsable` → `morphSessionOughtToLive()`**）：
            //       原来这里判 `morphUsable`（几何已就绪）——**在点击这条路上它必然为假**：
            //       起手与挂载那一刻终点锚点还没量到，`morphUsable` 就是 false
            //       ⇒ 这道门**永远开着** ⇒ 与被删掉的那句无条件 `morphReset()` 等价。
            //       ★ 本轮继续订正：`morphSessionStarted`（上一版）与 `playerRouteStillPushed()`
            //         （上上一版）都不对，理由见 {@link morphSessionOughtToLive} 的对照表。
            //       ⚠️ 与 `aboutToDisappear()` **必须同一个判据**（同一形状，不许各写一套）。
            setTimeout((): void => {
              if (this.morphSessionOughtToLive(wasAlive)) {
                Logger.info(PlaybackPage.logTag,
                  'RzdMorphOnDisappear keep session (morphSessionOughtToLive)');
                return;
              }
              Logger.info(PlaybackPage.logTag, 'RzdMorphOnDisappear reset (session no longer needed)');
              this.expandState.morphReset();
            }, 0);
            this.stopChromeAutoHide();
            this.imageColorJobSeq++;
            this.releaseBackgroundCoverIfPixelMap();
            // ★ 2026-10-15：网格背景的源位图也归本页持有 ⇒ 退场必须一起释放
            //   （否则每次进出播放页都会漏一张 64×64 的 PixelMap）。
            this.releasePixelMapQuiet(this.meshSrc);
            this.meshSrc = undefined;
            // ★★★ 2026-10-17（**补漏**）：`§140` 新加的"安静窗口待补网格源"也归本页持有 ——
            //   它在窗口期内只是**挂着**（`pendingMeshPm`），若这段里页面就退场了，
            //   上面那句只释放 `meshSrc`、**挂着的这张就永远漏掉**（同类内存卫生问题，
            //   与 §137 那个"快照 PixelMap 漏清"同一个形状）。
            this.releasePixelMapQuiet(this.pendingMeshPm);
            this.pendingMeshPm = undefined;
            this.imageLabel = $r('app.media.ic_avatar1');
            // 页面退场停掉着色器动画：整屏流光是持续的 GPU 开销，后台不该白耗电
            try {
              this.flowLightController.stop();
            } catch (_err) {
            }
            const wu = WindowUtil.getInstance();
            wu.applyPlaybackWindowChrome(false, false);
            Logger.info('RzdPlayerRoute', 'leave overlay: window layout unchanged');
            wu.applyPcPlaybackDecorButtonStyle(false);
          })

          // ★★ A2：歌词页顶部的「封面 + 歌名」浮层。
          //   放在 Stack C 的**最后一个孩子**：`position` 是"相对父组件左上角的绝对定位"，
          //   而本层的左上角就是窗口原点（与 `MorphCoverBridge` 同级同口径）⇒
          //   `PlayerExpandState.lyricMorph()` 交出的窗口坐标可以直接用；
          //   同时它在这个被 `scale/translate/clip` 变换过的容器里 ⇒ **收起时跟着一起缩**。
          //
          // ⛔⛔ 2026-10-16（**本轮试过一次"按无界层级搬到页面根级"，推导完就撤回了**）：
          //   无界的层级确实是"浮动层与 `playerPane` 同级、在形变容器之外"
          //   （`wujie.pa:1861` 的 builder 顺序表：11 `floatingCover` / 12 `metaRow` /
          //    13 `floatingMeta`，第 **52** 才是 `playerPane`）——
          //   但**我们不能照搬那个层级**，原因在"这个容器在这个浮层上多干了一件事"：
          // ```
          //     无界：封面尺寸 = edge × scaleAt(t)（CoverMorph 纯几何算出来的）
          //     我们：封面尺寸 = morph.size × **容器的 morphScale**（"变换式"那一对
          //           .scale(morph.size/base.size) + .translate(...) 的产物，见
          //           `LyricFloatLayer` 的 ③ 推导）
          // ```
          //   ⇒ 容器 `scale` 这一棒在我们这边**同时**承担了"内容层跟着缩"与
          //     "浮层封面从整窗那一份缩到迷你条那一份"**两件事**；无界只承担前者。
          //   ⇒ 把浮层搬出容器 = 丢掉后者 ⇒ 封面在动画中**小 `morphScale` 倍**
          //     （起手时 ≈ 0.082 ⇒ 只剩 8%）。那正是用户**已经实测过**的形状：
          //     `morphOverlayBridging()` 注释里的「封面从下往上飞」/「封面缩成一点」。
          //   ⇒ **要真照搬那个层级，前置条件是先把封面的尺寸来源改成 `scaleAt(t)`**
          //     （去掉那一对 `.scale/.translate`），那是跨三处的结构改动 + **必须有设备逐帧看**。
          //   完整理由见本文件根 `Stack` 里那段 `⛔⛔ 不要把浮动层搬到这里` 的注释。
          if (this.usesPhoneSwiperLayout()) {
            this.LyricFloatLayer()
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      }
      .width(StyleConstants.FULL_WIDTH)
      // ★★★ 2026-10-17（照搬无界 `PLAYER_ROOT_ID`）：**非手势关闭要拍的那张快照就是本节点**。
      //
      // 无界那一侧，`.id(PLAYER_ROOT_ID)` 挂在**带 `.scale/.translate/.clip` 的那个 Stack 上**
      // （`wujie.pa:191400-191478`：`.scale` 191400-191415 → `.translate` 191416-191431 →
      //   `.clip(true)` 191462-191469 → **`.id(PLAYER_ROOT_ID)` 191470-191478**），
      // 而 `MeshCoverBg` 与 `playerPane` 都在它**里面**（本页 :4952-4970 那段逐行对照）。
      //
      // ⇒ 所以这里也挂在**形变容器**这一层（不是它的父 `Stack`）：
      //   静止态（`morphScale=1 / translate=(0,0) / 无裁剪`）它就是**满屏的播放页**，
      //   快照拿到的正是"满屏那一张" —— 这正是 `ShrinkOverlay` 要求起点与满屏逐像素对齐的前提。
      //   ⚠️ 因此 `componentSnapshot.get(PLAYER_ROOT_ID, …)` **必须在形变开始之前**调
      //      （无界的 `closeWithAnimation()` 也是在 `pullMode` 之外、页面还满屏时才拍）。
      //   ⚠️ 与 `MESH_BG_ID` / `MINI_LYRIC_BOX_ID` 等**并存**（`getFrameNodeById` 按 id 查，
      //      一个节点只有一个 id；这几个是**不同节点**，互不影响）。
      .id(PLAYER_ROOT_ID)
      // ★★★★ 2026-10-17（**接上上游那个"LANDING 时停笔"的绘制门** —— `playerPaintsOf`）
      //
      // ## 上游那一条是**有消费者**的（`wujie.pa:153390-153430`，`MainPage` 发布形变状态那里）
      // ```ts
      //   AppStorage.setOrCreate(K_MORPH_SQUASH, playerPaintsOf(stage) ? true : false);  // ★ 就是这个布尔
      //   if (stage !== MorphStage.LANDING) { this.stopLandAnim(); this.morphSquashY = 1; }
      // ```
      // 而 `playerPaintsOf(stage) = stage !== MorphStage.LANDING`（`MorphState.ets`，`wujie.pa:93205`）
      // ⇒ **进 LANDING 那一刻起，播放页整页不再绘制**。
      // `PlayerPage` 侧读它就是 `pullPaintable = !pullGeomReady ? true : playerPaints(stage)`。
      //
      // ## 本仓原来**没接**（死门）
      // `PlayerExpandState.playerPaints()` 早就写好了（`return stage !== LANDING;`），
      // 注释里也写着它防的是什么：
      // > 「LANDING = 已经交还给迷你条（对标 `playerPaintsOf = false`）：这一帧起播放页
      // >   **不再画**，否则会在迷你条封面上留一个**同尺寸的深色小方块**，直到被卸载。」
      // 但它**零消费者** ⇒ 那句话描述的现象一直在发生。而"同尺寸的小方块"在手机上正是
      // **一条很矮的背景**（容器 `scale ≈ 0.082` × `clipHeight ≈ 683` ≈ 迷你条那块
      // 330×56 的扁平矩形）—— 与用户第 ② 条「**有背景但是高度特低**」逐字吻合。
      //
      // ## 为什么 `.visibility(Hidden)` 而不是 `.opacity(0)` 或条件渲染
      //   · `Hidden` = **不绘制、但保留布局** ⇒ 与"停笔"同义，且不动任何量测/锚点
      //     （`getFrameNodeById` 的矩形、`onAreaChange` 上报都不受影响）；
      //   · `.opacity(0)` 仍会走绘制管线（"停笔"没做到），而且本页的 `.opacity` 已经是
      //     `morphOpacityValue()`（恒 1，见那里的注释）；
      //   · 条件渲染会把节点从树上摘掉 ⇒ 量测源消失（`PLAYER_BIG_COVER_ID` 等），风险大。
      // ⚠️ 快照在 `morphLand()` **之前**拍（见 `closeWithAnimation` 的顺序）⇒ 本门翻假时
      //    图已经到手，不会拍到一张空图。
      // ⚠️ 上一帧仍是 LEAVING（在画）⇒ 关闭动画本身不受影响。
      .visibility(this.expandState.playerPaints() ? Visibility.Visible : Visibility.Hidden)
      // 裁剪窗口高度 = 可视高度 / 缩放 ⇒ 缩放后正好是那块可视矩形
      .height(this.morphClipHeight())
      // 边界裁剪（圆角由各图层自带；不用 clipShape：它会覆盖 borderRadius，
      // 而且它的形状对齐语义在无设备时没法验证）
      .clip(this.expandState.morphClipping())
      // 整页缩放 + 位移：静止态 scale=1 / translate=0，与没有这套动画时逐像素一致
      //
      // ★★★ 2026-10-16（照搬无界的**显式锚点**）：
      //   无界那个容器（`wujie.pa:191400-191415`）写的是
      //     `.scale({ x: expand.scaleValue, y: expand.scaleValue })`
      //   而它的 `initTranslateX/Y` 是**按"绕中心缩放"反解出来**的
      //   （`initParams` 51524-51575：`(窗宽−boxW)/2 − left` / `(h − h·s)/2 − top`）——
      //   也就是说**"绕中心"是它的前提**，只是靠默认值兑现。
      //   我们这一侧所有几何（`initTranslateX/Y`、`coverHostW/H`、逆变换推导）用的也是
      //   同一个前提，所以这里**把它显式写出来**：语义等价，但把假设钉死 ——
      //   万一将来 ArkUI 改了默认锚点，这一行能挡住"整套几何一起错位"。
      //   ⚠️ **只有 `centerX/centerY` 是"相对自身的百分比"**（50% = 节点自己的中心），
      //     所以在任何尺寸下都等价于"绕自身中心"。
      .scale({
        x: this.expandState.morphScale,
        y: this.expandState.morphScale,
        z: 1,
        centerX: '50%',
        centerY: '50%'
      })
      .translate({ x: this.expandState.morphTx, y: this.expandState.morphTy })
      .borderRadius(this.expandState.morphRadius)
      .opacity(this.morphOpacityValue())

      // ⛔⛔ 2026-10-16 —— **不要把浮动层（封面+歌名）搬到这里（页面根级）**。
      //
      // ## 我本轮试过一次，推导完就撤回了（记下来免得下次再试）
      // 无界的**层级**确实是"浮动层与 `playerPane` 同级、在形变容器之外"
      // （`wujie.pa:1861` 的 builder 顺序表：11 `floatingCover` / 12 `metaRow` /
      //  13 `floatingMeta`，第 **52** 才是 `playerPane`）——
      // 所以我一度把它搬到了本层，理由是"布局盒与枢轴都照抄 ⇒ 观感变化为零"。
      //
      // ## 为什么那个理由**是错的**
      // 无界的浮动层里，封面用的是**纯几何 + 一次 `scale`**：
      // ```
      //   CoverMorph.scaleAt(t) = lerp(1, lyricScale, t)      // 85856-85743
      //   渲染尺寸 = edge × scaleAt(t)                        // 85856 那一档
      // ```
      // 而**我们这一层的封面是"变换式"**（`LyricFloatLayer` 里那对
      // `.scale(morph.size / base.size)` + `.translate(...)`，见那里的 ③ 推导）——
      // 它的屏幕尺寸 = **`morph.size` × 容器的 `morphScale`**。也就是说：
      // ```
      //   容器 scale 这一棒**同时**负责两件事：
      //     ① 内容层（topBar/scrubber/transport/歌词）跟着缩 —— 无界也有；
      //     ② 浮层封面的**尺寸**从"整窗那一份"缩到"迷你条那一份" —— 无界**没有**（它靠 scaleAt）。
      // ```
      // ⇒ 把浮层搬出容器的那一刻，② 就丢了 ⇒ 封面在动画中**比正确值小 `morphScale` 倍**
      //   （`morphScale` 在起手时 ≈ 0.082 ⇒ 封面只剩 8%）。
      //   那正是**用户已经实测过**的形状：
      //     `PlayerExpandState.morphOverlayBridging()` 的注释原文 ——
      //     「我上一版关掉它、改让播放页里那张真封面独自承担，结果是：…观感成了
      //       「**封面从下往上飞**」（用户 2026-10-16 实测）」，
      //     以及 `封面缩成一点、展开动画没有端点` 那几次。
      //
      // ## 结论（下一个人直接照这条走）
      //   浮层**必须留在形变容器里**。无界之所以能放在外面，是因为它的**封面自身**是
      //   纯几何（尺寸/位置/圆角全部算出来，不吃任何祖先变换）。
      //   ⇒ 要真正照搬那个层级，前置条件是**先把封面的尺寸来源改成 `scaleAt(t)`**
      //     （= 去掉"变换式"那一对 `.scale/.translate`，让 `lyricMorph(t)` 直接给
      //      屏幕尺寸），那是一次**跨三处**的结构改动，且**必须有设备逐帧看**。
      //   复核命令：`grep -rn "LyricFloatLayer()" RzdMusic --include=*.ets`
      //     （期望：只有**容器内**那一处调用）

      // ★★★ 2026-10-16：**现场自证**（连点顶部 3 次开关，见 `onDiagHotspotTap()` 的注释）。
      //   放在形变容器**之外**（不被缩放/裁剪），所以它显示的数字与读数同口径。
      //   ⚠️ 徽标关着时 `diagText` 为空 ⇒ 热区是**完全透明**的一条、徽标零渲染。
      this.DiagHotspot()
      if (this.diagBadgeOn) {
        this.DiagBadge()
      }

      // 跨脚本换源醒目提示横幅（悬浮在最上面）
      if (this.switchBanner.text.length > 0) {
        Stack() { this.SwitchBanner() }.zIndex(10)
      }

      // ⚠️ 续飞封面（`MorphCoverBridge`）**不在这里**：2026-10-15 起它画在**内容层之前**
      //    （见上面根 Stack 里那段注释）—— 画在这一层（内容之上）会把从下升起的
      //    小歌词/收藏按钮/进度条/底部按钮全都压住，用户实测"小歌词从封面背后出现、进度条被挡"。
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // ★ 下拉收起播放器（MusicHome 同款交互）：竖直拖拽跟手收起，松手按阈值决定去留。
    //   挂在最外层；歌词那种可滚动子节点会先接到竖直手势，
    //   所以在歌词上滚不会误触发收起（ArkUI 的手势冒泡顺序：子节点优先）。
    .gesture(
      PanGesture(this.panOption)
        // ★★ 2026-10-15（用户实测「没法下拉关闭播放器」的排障锚点）：
        //   无界那份手势是带 `onActionStart → dragBackStart()` 的
        //   （`_recover/logic-src/开关播放器-手势路径定稿.md` §1.3：`Down / distance:8` +
        //   四个回调 start/update/end/cancel 齐全）。我们原来只有 update/end
        //   ⇒ 一旦"下拉没反应"，**分不清是手势没到这、还是到了但被门挡掉**。
        //   现在把它打出来（`hdc shell hilog -x | Select-String 'RzdMorph dismiss pan start'`）：
        //     · 下拉时**打得出来** ⇒ 手势路由正常，问题在门/阈值
        //       （接着看 `RzdMorph dismiss blocked` 与 `RzdMorph dismiss commit`）；
        //     · **打不出来** ⇒ 竖直拖动没落到本节点上（被上层或子层吃掉）⇒ 要改挂载点，
        //       无界的做法是挂在**顶栏那一条 Row**（非滚动、必定收到）而不是整页。
        .onActionStart((): void => {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss pan start isClosing=${this.isClosing} ` +
            `morphUsable=${this.expandState.morphUsable} stage=${this.expandState.morphStage} ` +
            `drive=${this.expandState.morphDrive}`);
        })
        .onActionUpdate((event: GestureEvent): void => {
          // 跟手期间也给 velocityY：拖动中它不影响判定（判定只在松手那一帧用），
          // 传进去是为了日志里能同时看到"位移 + 速度"的完整曲线。
          this.onDismissDrag(event.offsetY, false, event.velocityY);
        })
        .onActionEnd((event: GestureEvent): void => {
          // ★ D1：松手这一帧的 `velocityY` 就是速度提交判定的输入（`GestureEvent.velocityY`，
          //   `gesture.d.ts` @since 10，本机 SDK 已核对存在）。符号不由我们假设，见 `onDismissDrag`。
          this.onDismissDrag(event.offsetY, true, event.velocityY);
        })
        // ★★ 2026-10-15（对齐无界"四回调"）：**这一支以前是缺的**。
        //   壳层那三条同类手势**都有**它 —— `products/default/…/Index.ets` L1786（`onPullOpenCancel()`）、
        //   `MiniBarPlayer.ets` L166、`HomeMiniBarPlayer.ets` L235 ⇒ 又是
        //   "**同一形状有 N 处、只改了一处**"（§56.1.6 那条教训的第二次现形）。
        //
        //   缺它的后果与上一轮修的 `isClosing` 残留**同一类**：手势被中途打断时
        //   （系统手势 / 来电横幅 / 父级抢手势 / 页面被切走）`onActionEnd` **永不触发** ⇒
        //     · `dismissMorphActive` 残留 `true`：下次下拉时 `!ended` 分支会**跳过
        //       `morphBeginLeaving()`**（它只在 `!dismissMorphActive` 时才起手）⇒ 几何不刷新、跟手错乱；
        //     · 相位残留 `LEAVING` ⇒ `morphContainerActive()` 恒真 ⇒
        //       `beginOpenMorphOnClick()` 的守卫把"点击打开"判成"**已经在会话里**"而直接 return false
        //       ⇒ **点击打开又退化成派音旧动画**（正是用户实测的那条症状，而且很难复现成"稳定坏"）。
        //
        //   无界的写法就是**把取消当成松手**：`onActionCancel → dragBackEnd(0)`
        //   （`_recover/logic-src/开关播放器-手势路径定稿.md` §1.3：① 那条手势四个回调齐全，
        //   cancel 走的是 `pullEnd(0)`；⑤ 走 `dragBackEnd(0)`）。
        //   ⚠️ `velocityY` 必须传 **0**：取消不该被当成"快甩"而提交收起（`fastFlick` 要 ≥900）。
        .onActionCancel((event: GestureEvent): void => {
          Logger.info(PlayerExpandState.LOG_TAG,
            `RzdMorph dismiss pan cancel offsetY=${event.offsetY.toFixed(1)} ` +
            `dismissMorphActive=${this.dismissMorphActive} ` +
            `stage=${this.expandState.morphStage} drive=${this.expandState.morphDrive}`);
          this.onDismissDrag(event.offsetY, true, 0);
        })
    )
    // ★★ 2026-10-15（**撤回上一轮的一处改动**，并把原因写清 —— 见下）
    //
    // 上一轮我在这里补过 `.id(MORPH_HOST_ID)`，理由是"本仓两处注释都说手机侧这个 id
    // 就是播放页自己的根容器，而播放页从没挂过它"。**那个理由是错的，已撤回。**
    //
    // 真相（本轮全仓核对）：
    // ```
    //   .id(MORPH_HOST_ID) 的绑定点：
    //     products/default/.../Index.ets:1796   ← 壳层**根 Stack**（**常驻**，见它自己那段注释）
    //     products/pc/.../Index.ets:345         ← PC 壳层根 Stack（常驻）
    // ```
    // ⇒ 手机**路由模式**下，播放页是壳层根 Stack 里那个 `HdsNavigation` 的**子节点**
    //   ⇒ 两个节点**同时在组件树上**。所以：
    //     · **绝不能**在播放页这一层再挂一次 —— 那是「**同 id 两份节点**」，
    //       而本仓对这件事有明确记录（`products/default/.../Index.ets` 关于 `MINI_BAR_ID` 的两处注释：
    //       "两份同 id 的节点，`getRectangleById` 量到哪一份不确定，起点就抖"）。
    //       
    //     · 于是 `PlayerExpandState.measureGeometry()` 里那个
    //       `measureNode(ui, MORPH_HOST_ID)` 在**手机路由模式下**量到的是**壳层那一层**
    //       （而不是播放页的裁剪窗口）—— 这是**对的、也正是它想要的**：
    //       它把结果只写进日志（`hostNode=…`），并且在紧邻的注释里点名
    //       "**绝不能拿它当铺满目标**（那是第五次自噬）"。
    //     · 上一轮我误以为是"漏挂" ⇒ 结论订正为：**这是刻意的、正确的**。
    //
    // ⚠️ 那两处写着"手机侧播放页根 Stack 就是 `MORPH_HOST_ID`"的注释**是错的**，
    //    已就地订正（见 `PlayerExpandState.measureGeometry()` 与 `contentWidthVp/HeightVp` 两处）。
  }

  /**
   * 形变期间"续飞封面"浮层：一张脱离布局、按宿主坐标摆放的封面。
   *
   * ⚠️ **2026-10-15：这一棒已经搬到壳层浮层**（`Index.ets` 的 `MorphCoverClone()`），
   *    本页只在 `hostsMorphOverlay()` 为假的宿主（PC 壳层）上还调它 ——
   *    调用点上的注释写清了为什么。函数体保留：PC 那条路仍然需要它，
   *    而且删掉它就得同时删掉 PC 的封面当棒（那是另一件事）。
   *
   * 静止态**不产生任何节点**（`morphBridging()` 为 false），所以它不可能影响静态布局。
   * `HitTestMode.None` 是必须的：整层铺满屏幕，默认命中的话会把播放页所有点击吃掉。
   */
  @Builder
  MorphCoverBridge() {
    Stack() {
      Image(this.currentCoverSource())
        .width(this.expandState.morphCoverBridge().size)
        // ⚠️ 高度**单独取**（不再写死成 `size`）：播放页封面外有 `layoutWeight(1)` +
        //    `constraintSize(maxWidth/maxHeight)`，量到的矩形不保证是正方形。
        //    按正方形画出来的续飞封面，p=1 交棒给真实封面的那一刻就会跳一下
        //    （用户实测的「结束时封面位置/大小跳一下」）。
        .height(this.expandState.morphCoverBridge().height)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.expandState.morphCoverBridge().radius)
        .clip(true)
        .position({
          x: this.expandState.morphCoverBridge().x,
          y: this.expandState.morphCoverBridge().y
        })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .opacity(this.expandState.morphBridgeOpacity())
    .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 歌词页顶部的「封面 + 歌名/歌手」浮层（对标无界 `PlayerPage.floatingCover` / `floatingMeta`）。
   *
   * ## 它是什么（A2：恢复「歌词页顶部有封面 + 歌曲名称」）
   *
   * 无界的 `playerPane` 是 `Stack { Swiper{ 封面页 ; **空**歌词页 } ; floatingCover ; floatingMeta }`
   * —— 封面与歌名挂在 `Swiper` **之外**，切到歌词页时**同一个元素**缩小并移到顶部；
   * 歌词页那一页本身只有 `padding({ top: lyricPadTop() })`。这里就是那一层。
   *
   * ## 三个约束（缺一条就会出老毛病）
   *
   * 1. **同一时刻至多一张封面**：本浮层挂载 ⟺ 封面页那份真封面被 `.opacity(0)` 藏起来
   *    ⇒ 覆盖层是**唯一**的封面渲染者，**没有"两者互补"这回事了**（`lyricFloatActive()` 已删）。
   *    （浮层 `t = 0` 用的就是真封面的落点几何，见 `PlayerExpandState.lyricMorph`）；
   * 2. **静止态不产生多余节点**：封面页静止时 `lyricMorphT = 0` ⇒ 变换为恒等、位置即布局位
   *    （`lyricFloatActive()` 那把门已删除 —— 覆盖层常驻，见 §第 2 块）。
   *    `if` 分支直接不建节点 ⇒ 静止在封面页时版面与没有这套东西**逐像素一致**；
   * 3. **不吃触摸**：`HitTestMode.None`（与 `MorphCoverBridge` 同款）——
   *    整层铺满屏幕，默认命中的话会把歌词的滚动与点击全吃掉。
   *
   * ## 为什么挂在这个位置（`Stack`C 的最后一个孩子）而不是壳层
   *
   * · **坐标口径**：本层左上角就是窗口原点（与 `MorphCoverBridge` 同级、同口径 ——
   *   它按窗口坐标 `.position()` 落位是**已被真机验证过**的），所以 `lyricMorph()` 交出的
   *   窗口坐标可以直接当 `.position()` 用，**全链零换算**；
   * · **必须跟着形变一起缩**：它在这个被 `scale + translate + clip` 变换过的容器里，
   *   收起播放页时浮层跟着缩；挂到根 `Stack`（变换之外）就会"页面缩、封面不缩"。
   *
   * ⚠️ 歌词怎么画**一个字没动**（`LyricsComponent` / `AmllLyricView` 不碰）。
   */
  @Builder
  private LyricFloatLayer() {
    // ★★ 2026-10-15（照搬无界 `floatingCover`）：**常驻 + 变换式**。
    //
    //   ① 常驻：封面是 `playerPane` 里一个恒在的覆盖层，靠 `scale/translate` 在两个端点间插值，
    //      所以页 0 不再画封面（那里已删 `MusicPlayInfoBlock`）—— **全程只有一份封面**。
    //   ② 变换式：布局基准尺寸取 `playerCoverGeomRect()`（**纯几何、不查节点**），
    //      只有 `scale/translate` 会挪它 ⇒ `t = 0` 时**位置由布局决定**，
    //      不会出现"宽度依赖上报、上报依赖宽度"的死环（2026-10-15 那次封面消失的机制）。
    //   ③ **数学上与改前逐像素等价（任意 `t`，不只 `t=0`）** —— 推导（ArkUI 常规语义：
    //      `.scale` 绕节点中心、`.translate` 在未缩放的父坐标系里加）：
    //        scale   = morph.size / base.size
    //        translate = morph.xy − base.xy
    //        渲染尺寸 = base.size × scale = morph.size                      ✓
    //        渲染中心 = baseCenter + translate
    //                 = (base.xy + base.size/2) + morph.xy − base.xy = morph.xy + morph.size/2
    //        ⇒ 渲染左上角 = morph.xy                                        ✓
    //        视觉圆角 = (morph.radius / scale) × scale = morph.radius          ✓
    //      ⇒ **封面在任何一帧的落点、大小、圆角都与原来 `.width/.position(lyricFloatRect())` 完全相同**
    //      （`base` 只是"参考系"，它取什么值都不影响结果，**只要它不为 0**；这正是它必须纯几何的原因）。
    //      ⚠️ 上机请顺手确认一次：封面页那张大封面应与改前**一模一样**（若变了，说明 `.translate`
    //         与 `.scale` 的复合顺序与上面假设不符 —— 那是唯一需要调整的假设）。
    Stack({ alignContent: Alignment.TopStart }) {
      // ══════════════ ★★ 本层成立所依赖的**两条坐标系前提**（2026-10-15 补记，动手前必读）══════════════
      //
      // 前提 ①：**本层被挂在"满屏内容栈"下** ⇒ 那个宿主的内容盒左上角 = 窗口原点
      //   （`PlaybackPage.ets:3227` 那句"本层的左上角就是窗口原点"说的就是它，
      //    而它**只对手机支成立**）⇒ `lyricMorph()` 交出的窗口坐标可以**直接**写进 `.position()`。
      //   ⚠️ 换成宽屏/面板的宿主（`GridCol` 内容盒 / 左栏 `Column`）就**不再成立**：
      //      必须先减掉宿主左上角（`PlayerExpandState.toHostPoint()` 就是为它准备的），
      //      否则封面整体偏一个栏位 —— 见 `目标④-宽屏面板统一-施工图与验收.md` §4 的 S3a。
      //
      // 前提 ②：**本层同时被套在形变容器（scale + translate + clip）**里
      //   ⇒ `.position({x, y})` 里的窗口坐标只在 `p = 1`（容器是恒等变换）时**严格**落在窗口的 (x, y)；
      //      形变中（p < 1）它的**实际**窗口位置会被容器变换挪走。
      //   ★ **推导（不是估的；变换原点取容器中心，"绕中心缩放"）**：
      //        设窗口坐标 y，容器高 `H`（≈ 宿主高），`s = initScale + (1−initScale)·t`、`d = initTranslateY·(1−t)`
      //        绕中心缩放：`y ↦ H/2 + (y − H/2)·s`；再平移 `d` ⇒ `y' = H/2 + (y − H/2)s + d`
      //        代入本仓的 `initTranslateY = barY − scaledH·(1−initScale)/2`（`scaledH = barH/initScale`）
      //        并令 `t = p`、`k = H/2 − scaledH/2`：
      //            y' = k·(1−s) + y·s = k(1−t) + y·t   ⇒   **`y' ≈ t × y`**（因为 `k` 与 `y` 同量级、且在 t=1 时抵消）
      //        · `p = 1`（落位）：`y' = y` ✓ **正是设计值**
      //        · `p = 0.5`：≈ `y/2`   ← **只有设计值的一半**
      //        · `p = 0`：≈ `0`        ← 贴在容器上边
      //      （把 `y = 250` 代进本机那组实测几何 `initScale ≈ 0.082 / scaledH ≈ 683 / H ≈ 925`：
      //        t=1 → 250 ✓、t=0.5 → 124、t=0 → −1 —— 与 `y' ≈ t·y` 吻合）
      //   ⇒ **这是一条"落位时正确、形变中偏"的口径**（`RzdCoverRect` 的 `base/tx/ty` 量的就是它）。
      //   ⚠️ **2026-10-15 刻意不改**，理由是改法都已被真机证伪过：
      //       · 逆变换回页内坐标 —— 真机结果"封面跑到左上角"（见 `morphBridging()` 里那段：
      //         `.scale()` 的枢轴当时不是我以为的容器中心）；
      //       · 整层搬出形变容器 —— 会变成"页面在缩、封面不缩"（用户实测过的观感）。
      //   ⚠️ **同一根因的另一份拷贝已经在壳层**：`Index.ets` 的 `MorphCoverClone()` 之所以被搬出
      //      播放页，注释写的正是这件事（"矩形却是窗口坐标 ⇒ 只有 p=1 才严格正确"）。
      //   ⇒ 结论：**手机支保持现状**（用户在真机上验过观感可接受）；
      //      宽屏/面板那一轮如果要复用本层，必须**同时**决定这三条前提怎么处理，**不许只搬一半**。
      //   复核命令：`hdc shell hilog -x | Select-String 'RzdCoverRect'`
      //     ⇒ 看形变中 `measured`（onAreaChange 给的布局位）与 `base+tx` 的差，
      //        与上面那三行预测（p=1 相等 / p=0.5 减半 / p=0 贴角）对得上就说明这条口径还在生效。
      //
      // 满屏居中容器：封面的**布局位置**（变换之外）就是"基准矩形"的居中位
      // ★★★ 2026-10-16（用户定调「**彻底照搬吧**」）：
      //   把封面从「**基准 + scale/translate**」改成无界那样的「**纯几何直接落位**」。
      //
      // ## 为什么要去掉那一对 `scale/translate`
      //
      // 原来这一层是：
      // ```
      //   Image().width(coverLayerBase().size)                     ← 基准尺寸
      //          .scale(实测尺寸 / 基准尺寸)                        ← 补到"实测尺寸"
      //          .translate(实测位 − 基准位)                        ← 补到"实测位置"
      // ```
      // 于是**封面最终位置 = 实测位置**，而"实测位置"来自 `onAreaChange` 上报的
      // `lyricFloatRect()`；那个值在本仓**不可控、也无法离线核对**（用户实测"封面偏低"，
      // 而我按它做任何校正都会让观感更差 —— §74/§75/§76 三次都栽在这条链上）。
      //
      // 无界那边**根本没有这条链**：`floatingCover` 是一个 `Column(center)` 里的封面，
      // 尺寸 `morph.edge`、位置 `morph.tyAt(t)`、圆角 `morph.radiusAt(t)`
      // —— **全部是算出来的**，不查任何节点（`PlayerPage完整UI定稿.md` §5）。
      //
      // ⇒ 现在照搬它：**尺寸/位置/圆角一律取自 `lyricFloatRect()`（= `lyricMorph(t)`）**，
      //   不再乘 `scale`、不再加 `translate`。`t = 0`（封面页静止）时 `lyricMorph(0)`
      //   就是 `playerCoverGeomRect()` 那一份**无界的算式结果** ⇒ 落位由算式一次定死。
      Column() {
        Image(this.currentCoverSource())
          // ★★★ 2026-10-16（用户定调「**彻底照搬吧**」+ 修两条实测）：
          //   **尺寸/位置/圆角一律取 `lyricMorph(t)`（= 无界 `CoverMorph` 的输出），
          //   不做任何坐标系换算**（`coverLocalRect()` 现在就是 `lyricFloatRect()` 的直通）。
          //
          //   ⚠️ 我上一版在这里加过一次"屏幕坐标 → 容器本地坐标"的**逆变换**
          //     （假设 `.scale()` 绕容器中心），真机结果是**封面飞出屏幕**。
          //     本仓对这条假设**早有反证**（`morphCoverRectAt()` 的注释 + 本层顶部
          //     "⚠️ 2026-10-15 刻意不改"那一段：「逆变换 ⇒ 真机结果封面跑到左上角，
          //     说明 `.scale()` 的枢轴不是我以为的容器中心」）⇒ **已完整撤回**。
          //     为什么当时的结论是"保持现状"：它虽然"落位时正确、形变中偏"，
          //     但封面是**跟着容器一起缩**的（观感正确），而逆变换会直接把它甩出屏幕。
          //   排查关键字：`hdc shell hilog -x | Select-String 'RzdCoverLocal'`
          .width(this.coverLocalRect().size)
          .height(this.coverLocalRect().height)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.coverLocalRect().radius)
          .clip(true)
          // `.position()` 是**相对父组件内容盒**的绝对定位；本层宿主的内容盒左上角
          // = 窗口原点（前提①，见本层顶部）⇒ 窗口坐标可以直接写。
          .position({ x: this.coverLocalRect().x, y: this.coverLocalRect().y })
          // ★★ 2026-10-15（修用户实测「**动画中途会出现两个封面**」）：**封面这张必须挂
          //   `realCoverVisible()` 那道门** —— 它与壳层克隆层的 `morphOverlayBridging()` 是
          //   **严格互补**的一对（本文件 L2665 那句注释写的就是这件事）：
          //     · 形变中（`morphContainerActive()`：ENTERING/LEAVING/LANDING）⇒ 本张**不画**，
          //       屏上那张由壳层克隆层（`MorphCoverClone`）代表；
          //     · 落位后（stage = OPEN）⇒ 本张**画**，克隆层同时收工。
          //   ⚠️ 我原来**漏了这道门** ⇒ 形变期间"克隆层那张飞行的封面"与"页面这张落位的封面"
          //      **同时在画** ⇒ 用户截图里的一张半/两张封面。
          //   ⚠️ 这条在 `MusicPlayInfoBlock`（宽屏 / 面板那两支）**一直都有**
          //      （L357 / L510：`.opacity(this.expandState.realCoverVisible() ? 1 : 0)`）——
          //      只有手机这一支的浮层漏了 ⇒ 又一例「**同一形状 N 处、只改了一处**」（第 4 次）。
          //   ⚠️ 上报钩子（`.id` / `onAreaChange`）**不受 opacity 影响**，照常量得到 ✓。
          .opacity(this.expandState.realCoverVisible() ? 1 : 0)
          // ★ 上报钩子搬到这里（无界也是覆盖层自己上报：`floatingCover.onAreaChange → publishMorphTargets`）
          .id(PLAYER_BIG_COVER_ID)
          .onAreaChange((_oldValue: Area, newValue: Area): void => {
            this.reportPlayerCoverFromOverlay(newValue);
          })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.None)

        // ★★ 2026-10-15（照搬无界）：**一横行**，不再是居中竖排。
        //   对标 `PlayerPage完整UI定稿.md` §6.1 `floatingMeta` + §6.2 `metaRow`：
        //     · 小封面在**左**（就是上面那张 `Image`，由 `lyricFloatRect()` 落位到歌词页端点）；
        //     · 歌名/歌手在它**右边、左对齐**（`metaRow` 里那一列是 `layoutWeight(1)` +
        //       `alignItems(HorizontalAlign.Start)`）；
        //     · 右侧留给收藏/更多（无界是 `SymbolGlyph 收藏` + `SymbolGlyph 更多`）。
        //   ⚠️ 原来这里是 `textAlign(Center)` + 整块水平居中 ⇒ 就是用户截图里
        //      "派音居中大封面 / 无界小封面靠左" 的那条差异。
        //   ⚠️ 封面让位用 `padding.left` 表达（= 封面右缘 + 12），
        //      与无界靠 `floatingCover`/`metaRow` 两层横向错位达到的结果等价、少一层。
        Row() {
          Column() {
            Text(this.state.getCurrentSongItem()?.title ?? '', { controller: this.titleController })
              // ★ 端点上报（原 `MusicPlayInfoBlock` 的职责）—— 见 `publishMetaEndpoint`
              .id(PLAYER_META_TITLE_ID)
              .onAreaChange((): void => {
                this.publishMetaEndpoint(false);
              })
              .fontSize(this.metaTitleFp())
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.play_text_color'))
              .opacity(0.86)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
              .width(StyleConstants.FULL_WIDTH)
            Text(this.state.getCurrentSongItem()?.singer ?? '', { controller: this.singerController })
              .id(PLAYER_META_SINGER_ID)
              .onAreaChange((): void => {
                this.publishMetaEndpoint(true);
              })
              .fontSize(this.metaArtistFp())
              .fontWeight(FontWeight.Regular)
              .fontColor($r('app.color.play_singer_color'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
              .width(StyleConstants.FULL_WIDTH)
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          // ★ 无界 `metaRow` 右侧那两个图标（`PlayerPage完整UI定稿.md` §6.2）：
          //   `SymbolGlyph 收藏` + `SymbolGlyph 更多`。
          //   收藏接 `MusicStoreService`（与 `MusicPlayInfoBlock` 同一套读写）；
          //   更多打开歌曲菜单 —— 那个 sheet 由 `ControlAreaComponent` 画，
          //   状态已提升到本页（`playMenuOpen`），见那里的 `@Param`/`@Event` 说明。
          SymbolGlyph(this.isCurrentFavorite ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(this.expandState.chromeFavSize())
            .fontColor([this.isCurrentFavorite ? $r('app.color.player_text_primary')
              : $r('app.color.play_text_color')])
            .margin({ top: 2 })
            .responseRegion({
              x: -10, y: -10,
              width: PlaybackPage.LYRIC_META_HIT_VP, height: PlaybackPage.LYRIC_META_HIT_VP
            })
            .onClick((): void => {
              this.toggleFavorite();
            })
          SymbolGlyph($r('sys.symbol.dot_grid_1x2_circle'))
            .fontSize(this.expandState.chromeFavSize())
            .fontColor([$r('app.color.play_text_color')])
            .margin({ top: 2, left: 14 })
            .responseRegion({
              x: -10, y: -10,
              width: PlaybackPage.LYRIC_META_HIT_VP, height: PlaybackPage.LYRIC_META_HIT_VP
            })
            .onClick((): void => {
              this.playMenuOpen = true;
            })
        }
        .width(StyleConstants.FULL_WIDTH)
        // ★★ 2026-10-15（修回归）：行高**必须用自身自然高度**（≈34vp），
        //   **不能**用 `this.lyricFloatRect().size` —— 那个值在 `t = 0`（封面页）时是
        //   **大封面边长（328vp）**，配上 `VerticalAlign.Center` 会把两行文字推到这一带的中间
        //   ⇒ **封面页的歌名被往下推约 164vp**（落到屏幕底部、压在控制区上）。
        .height(PlaybackPage.LYRIC_META_ROW_H_VP)
        .alignItems(VerticalAlign.Center)
        .padding({
          left: this.lyricMetaLeftInset(),
          right: PlaybackPage.LYRIC_META_SIDE_VP
        })
        // ★★★★ 2026-10-17（**照搬无界的位移公式本体** —— 删掉本仓自定的那半条式子）
        //
        // 原来这里是：
        // ```
        //   y: lyricMetaMorphY(t) + t × (lyricFloatRect().size − LYRIC_META_ROW_H_VP) / 2
        // ```
        // 两个问题（都在 §130/§131 里给了出处）：
        //   ① `lyricMetaMorphY` 的 `from` 端点用的是本仓自定的 `LYRIC_META_GAP_VP = 10`
        //      （那个常量的注释自己写着「本项目估定值，非逆向值」），
        //      而无界 `fitPlayerOverlay` 的 gap 是**硬编码 50** ——
        //      它第 6 个实参 `chrome().metaGap` **被丢弃**（`refitOverlay` 传 6 个、
        //      `fitPlayerOverlay` 只收 5 个）⇒ 那个 10 是把"被丢弃的参数"当成了真值。
        //   ② `to` 端点用的是"小封面顶边"，少掉 `metaTopFixLyric`；
        //      而 `t × (size − rowH)/2` 那个"居中补偿"又是本仓自创的第三项。
        // ⇒ 现在直接调**一个**有出处的函数（`metaTopGeomY`，两端点逐字来自
        //   `CoverMorph.metaOffsetYAt` + `fitPlayerOverlay`），本行不再有任何自编项。
        .position({
          x: 0,
          // ★★★★ 2026-10-17（**形变期用页内坐标** —— 修「展开时歌名与进度条重合 / 下面抽搐」）
          //   本行挂在**被 scale/translate 变换过的容器里**，而 `metaTopGeomY` 给的是**窗口坐标**
          //   ⇒ 形变中卡片只有 262~567vp 高，而 y 仍是窗口坐标的 516.7 ⇒ 这一行被摆到卡片外面、
          //     压住进度条，并且卡片每帧长大它也跟着每帧错位（= 抽搐）。
          //   无界的 `metaRow` 在 `playerPane` 里、用**页内坐标** ⇒ 永远在卡片内。
          //   ⇒ 形变期换成 `metaTopLocalY()`（用 `initScale/initTranslate/morphTy` 反解，与
          //     `applyMorphProgress` 同源）；静止态仍是原窗口坐标（容器恒等 ⇒ 两者相等，逐像素不变）。
          y: this.expandState.morphContainerActive()
            ? this.expandState.metaTopLocalY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP)
            : this.expandState.metaTopGeomY(this.lyricMorphT, PlaybackPage.LYRIC_META_ROW_H_VP)
        })
        // ★★ 2026-10-15（修用户实测「**动画中途会出现两个歌名歌手**（有一个是残留的、
        //   以前派音用的歌名歌手飞入）」）：
        //   **这一行原来是写死的 `.opacity(1)`**（注释理由是"常驻 ⇒ 恒可见：封面页那份歌名
        //   原来由 `MusicPlayInfoBlock` 画，它已从页 0 移除"）—— 那个理由**只对静止态成立**，
        //   它把与克隆层的**互斥门一起拆掉了**：形变期间壳层 `MorphMetaBridge`
        //   （就是用户说的"以前派音用的歌名歌手飞入"）在画飞行中的歌名，而本行**同时又全亮**
        //   ⇒ **两套歌名同时在场**。
        //   ⇒ 换成无界那道门 `targetMetaOpacity()`（`PlayerExpandState` L1325-1335）：
        //     · stage = OPEN ⇒ **1**（落位后恒可见，覆盖"封面页那份歌名"的职责 ✓）；
        //     · 形变中且克隆层接管（`metaBridgeOwnsPaint()`）⇒ **0**（交棒给克隆层）；
        //     · 形变中但克隆层没接管 ⇒ 退回 `pullChromeOpacity()` 那条淡入曲线。
        //   ⚠️ `MusicPlayInfoBlock`（宽屏 / 面板那两支）**一直用的就是它**（L239 / L411 / L447）
        //      ⇒ 同上一处一样，又是「同一形状 N 处、只改了一处」漏掉的那一处。
        .opacity(this.expandState.targetMetaOpacity())
        // ★★★★ 2026-10-17（**删掉这里那条自编的 180vp 位移** —— goal 第 1 条的正面要求）
        //
        // 上一版这里是 `.translate({ y: this.expandState.metaRiseVp() })`，
        // `metaRiseVp() = (1 − ramp01(p, 0.18, 0.62)) × **RISE_VP(180)** / morphScale`
        // —— 那个 **180 是本仓自定值、没有任何出处**（`RISE_VP` 的注释自己写着"屏幕量"）。
        //
        // 无界这一行的位移**只有一条**，就是上面那条 `.position()` 里的
        // ```
        //   metaOffsetYAt(t) = lerp(metaYPlayer, topYAtLyric() + metaTopFixLyric, t)
        // ```
        // （`CoverMorph.ets:205-211`）—— **lerp 本身就是那条"飞上来"**：
        // t=0 在"大封面底边 + 50"，t=1 到"小封面竖直中心"（`topYAtLyric + 28`，
        // 见 `META_TOP_FIX_LYRIC_VP`），**全行程由 t 驱动**，不需要再叠一条窗内位移。
        //
        // ⇒ 删掉它之后：
        //   · 文字与两个图标**同处这一行** ⇒ 依然"一起飞上来"（位置 lerp 同源）；
        //   · 淡入仍按 `targetMetaOpacity()`（内含 `pullChromeOpacity` 的 0.18–0.62 窗口，
        //     那是用户已确认的 ③）；
        //   · 与无界**只差"进度源"**：我们用 `lyricMorphT`，无界用 `swiperProgress` ——
        //     这正是徽标第六行 `metaD`（订正后）要量的东西。
        //
        // ⚠️ `earlyRiseVp()` / `contentRiseVp()`（小歌词组 / 控制区组）**本次不动**：
        //   goal 第 1 条只点了元信息行；那两组是"控制区从下升上来"，用户已确认的
        //   ③ 说的就是它们那套时间窗（`pullChromeOpacity` 0.18–0.62 / `pullBottomIn` 0.45–1.00）。
        //   它们同样叠了一条 180vp —— 要不要一起去掉，等这次观感反馈再定（见 §130）。
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      // ★★ 2026-10-15（修）：这里原来是 `HitTestMode.None` —— 那是"**自己和子节点都不响应触摸**"，
      //   会把那一行右侧的**心形 / 更多两个按钮的点击一起吃掉**（就是本块刚加的那两个）。
      //   无界外层用的是 `HitTestMode.Transparent`（`floatingCover` / `floatingMeta` 的
      //   满屏容器都是它）：**空白处穿透到下层、子节点照常可点** ⇒ 这里改成同一个。
      //   ⚠️ 封面那张图自己仍然是 `None`（上一层的 `Column`），所以它不会挡住滑动。
      .hitTestBehavior(HitTestMode.Transparent)
    }
}

/*
 * ⚠️ 播放页「一镜到底」展开动画的历史（2026-09-22 / 09-25）——再动手前先读完。
 *
 * 第一版（已废弃）用 path 裁剪把整页裁成迷你条那么大的小窗口再逐帧长大，两个 API 都坏：
 *   1. `clipShape(new PathShape({ commands }))` —— 播放页整个不显示（表现为打不开）；
 *   2. `clip(new Path({ commands }))` —— 点击播放器直接卡死。
 *
 * 现在这版（对标无界音乐 `ExpandAnimation` + `CoverMorph`，**可用**）：
 *   1. **整页缩放 + 竖直裁剪窗口**：`height / scale / translate / clipShape / opacity`
 *      五个属性，形状只用**圆角矩形**（`RectShape`，不是 path）——
 *      见 `PlayerExpandState.applyMorphProgress`；
 *   2. **桥接封面**：形变早期单独画一张封面，从迷你条封面续到播放页封面
 *      （见 `MorphCoverBridge` / `PlayerExpandState.morphCoverBridge`）。
 *
 * 它的四个必要条件（缺一个就会退化成"黑底 + 下方空白 + 一块近正方形"）：
 *   1. **播放页与首页必须在同一棵视图树里**：形变早期可视矩形只有迷你条封面那么大，
 *      其余部分是透明的，要透出下面的首页与迷你条 —— 用 `bindContentCover` 模态不行，
 *      模态宿主是不透明的一层，把首页和迷你条全盖住了。
 *   2. **"铺满"的目标高度必须是恒为满屏的宿主容器实测出来的**：挂在被形变的那层上会自噬
 *      （那层高度就是裁剪窗口），见 `PlayerExpandState.reportHost`。
 *   3. **可视矩形的四条边各自插值**，且**下边要提前贴底**（迷你条离屏幕底边还有几十 vp，
 *      跟着线性走的话整段动画底部都是空的）；位移= 可视左上角 − (布局−可视)/2，
 *      不能照抄无界的"初始位移 × (1-p)"（缩放中心是容器中心，常量补偿中段会顶出屏幕）。
 *   4. **圆角必须用 `clipShape` 裁**：只写 `.borderRadius + .clip(true)` 时，
 *      容器自身没有背景色 → 圆角不作用到子节点 → 内容层一浮出来就变方块。
 *
 * 已经保留的东西（都在 common/musicbasic）：
 *   - `PlayerExpandState`（两端封面的窗口矩形 + 相位 + 容器形变几何）；
 *   - `MINI_BAR_COVER_ID` / `PLAYER_BIG_COVER_ID` 两个组件 id；
 *   - 迷你条封面与播放页大封面各自 `onAreaChange` 上报窗口矩形的能力。
 */

/** Player content builder mounted by product shells as a full-screen overlay above the shell Stack. */
@Builder
export function PlaybackPageCoverContent() {
  Column() {
    PlaybackPage()
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
  // **不碰安全区**：铺满交给壳层给的浮层容器，底部留白由 PlaybackPage 内部按
  // navigationBarBottomVp 自己加 padding。在这里写 expandSafeArea / ignoreLayoutSafeArea
  // 会和外壳容器冲突，留白反而变大。
}

/** Panel-style cover content (wide split layout) for product shells that opt into the panel layout. */
@Builder
export function PlaybackPagePanelCoverContent() {
  Column() {
    PlaybackPage({ panelLayout: true })
  }
  .width(StyleConstants.FULL_WIDTH)
  .height(StyleConstants.FULL_HEIGHT)
}
