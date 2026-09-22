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

import { AppStorageV2, ComponentContent, LengthMetrics, uiObserver } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { BlurStrategy, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, SystemMaterialParams } from '@kit.UIDesignKit';
import {
  AmbientState,
  AppStorageKeys,
  BreakpointConstants,
  BreakpointType,
  buildTitleMaterial,
  getAppRuntime,
  getWindowInfoState,
  GridConstants,
  BoardSongParam,
  ImmersiveType,
  MusicStoreService,
  SdkApiUtil,
  StyleConstants,
  TitleBarConstants,
  ToplistRouteParam,
  WindowInfo,
  WindowUtil
} from 'musicbasic';
import { ColorConversion, fetchBoardSongs } from 'player';
import { BoardSongEntry } from 'player';
import { MusicListPlaybackViewModel } from '../viewmodel/MusicListPlaybackViewModel';
import { PlaylistBatchSelectionStore } from '../model/PlaylistBatchSelectionStore';
import { PlaylistBatchActionBar } from './PlaylistBatchActionBar';
import { PlaylistDetailHeroSection } from './PlaylistDetailHeroSection';
import { PlaylistDetailSongListSection } from './PlaylistDetailSongListSection';

/** One LXMusic export song entry. */
const PLAYLIST_LOG_DOMAIN: number = 0x0000;
const PLAYLIST_LOG_TAG: string = 'RzdPlaylistDetail';

interface LxSongJsonMeta {
  songId: string;
  songmid: string;
  picUrl: string;
  albumName: string;
  albumId: string;
}

interface LxSongJson {
  name: string;
  singer: string;
  source: string;
  songId: string;
  songmid: string;
  albumName: string;
  albumId: string;
  interval: string;
  img: string;
  meta: LxSongJsonMeta;
}

/** LXMusic playlist export JSON root shape. */
interface LxPlaylistJson {
  type: string;
  name: string;
  songs: LxSongJson[];
}

/**
 * Full-screen playlist detail page with hero header, song list, and floating mini player.
 */

/** 排序项：0 默认 / 1 按歌名 / 2 按歌手（已从列表行内按钮移入「四个点」菜单）。 */
const PLAYLIST_SORT_DEFAULT: number = 0;
const PLAYLIST_SORT_TITLE: number = 1;
const PLAYLIST_SORT_SINGER: number = 2;

/** 标题栏「四个点」下拉菜单回调容器：全局 @Builder 通过模块级回调中转。 */
let playlistMoreAction: ((action: string) => void) | null = null;

/** 「四个点」菜单内容（openMenu 用，必须为全局 @Builder + wrapBuilder）。 */
@Builder
function playlistMoreMenuComponent() {
  Menu() {
    MenuItem({ content: '搜索当前歌单' })
      .onClick(() => {
        if (playlistMoreAction !== null) {
          playlistMoreAction('search');
        }
      })
    MenuItem({ content: '默认排序' })
      .onClick(() => {
        if (playlistMoreAction !== null) {
          playlistMoreAction('sortDefault');
        }
      })
    MenuItem({ content: '按歌名排序' })
      .onClick(() => {
        if (playlistMoreAction !== null) {
          playlistMoreAction('sortTitle');
        }
      })
    MenuItem({ content: '按歌手排序' })
      .onClick(() => {
        if (playlistMoreAction !== null) {
          playlistMoreAction('sortSinger');
        }
      })
    MenuItem({ content: '自定义排序顺序' })
      .onClick(() => {
        if (playlistMoreAction !== null) {
          playlistMoreAction('customSort');
        }
      })
    MenuItem({ content: '歌曲去重' })
      .onClick(() => {
        if (playlistMoreAction !== null) {
          playlistMoreAction('dedupe');
        }
      })
  }
  .width(200)
}

@ComponentV2
export struct PlaylistDetailPage {
  /** Current window width/height breakpoint from the design system environment. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** View model driving playlist songs and play actions for this page. */
  @Local listVm: MusicListPlaybackViewModel = new MusicListPlaybackViewModel();
  /** QQ music toplist id when this page shows an online toplist; empty for local playlists. */
  @Param topid: string = '';
  /** Display title for the online toplist (used in the title bar). */
  @Param listTitle: string = '';
  /** 榜单/歌单自身封面（由跳转方传入；为空时 Hero 显示内置占位图）。 */
  @Param listCover: string = '';
  /** 'history' or 'favorites' to load local store lists instead of an online toplist. */
  @Param sectionType: string = '';
  /** Playlist id when sectionType is 'playlist'. */
  @Param playlistId: string = '';
  /** Music source id when sectionType is 'onlinePlaylist'. */
  @Param onlineSource: string = '';
  /** Board music source when opening a multi-source ranking board. */
  @Param boardSource: string = '';
  /** Board id within the board source. */
  @Param boardId: string = '';
  /** Prefetched board songs handed over through the route param. */
  @Param boardSongs: BoardSongParam[] = [];
  /**
   * 榜单歌曲的异步加载器。
   *
   * 默认实现**直接调 player 的 `fetchBoardSongs`**：榜单页在 playlist 层，
   * 而 playlist 不能依赖 recommendation（那是上层），所以取数只能靠底层的 player。
   *
   * ⚠️ 曾经试过"把取数函数随路由参数传进来"（`ToplistRouteParam.boardSongLoader`）：
   * **走不通** —— 导航参数经框架传递后，挂在对象上的回调函数会丢失，页面拿到的一直是
   * 默认空实现，表现就是"榜单打开后一首歌都没有"。取数必须自带，不能靠回调传递。
   */
  @Param boardSongLoader: () => Promise<BoardSongEntry[]> = (): Promise<BoardSongEntry[]> => {
    return fetchBoardSongs(this.boardSource, this.boardId);
  };
  /** Window chrome and immersive layout information shared app-wide. */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** Ambient material level (0 = follow system) for title bar button styling. */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /** Vertical scroller for the main playlist content. */
  private pageScrollScroller: Scroller = new Scroller();
  /** Whether the in-playlist search sheet is visible. */
  @Local showSearchSheet: boolean = false;
  /** Live search keyword filtering the playlist songs. */
  @Local searchKeyword: string = '';
  /** Sort mode command forwarded to the song list (0 default / 1 title / 2 singer). */
  @Local externalSortMode: number = -1;
  /** 自定义排序顺序指令（递增触发，转发给歌曲列表进入排序模式）。 */
  @Local customSortCommand: number = 0;
  /** 歌曲去重指令（递增触发，转发给歌曲列表执行去重）。 */
  @Local dedupeCommand: number = 0;
  /** 强制退出多选模式指令（递增触发）。 */
  @Local batchExitCommand: number = 0;
  /** 多选（批量操作）模式：为真时隐藏浮动迷你条，并在屏幕底部显示批量操作条。 */
  @Local batchMode: boolean = false;
  /**
   * 多选共享状态（页面级唯一实例）。
   *
   * 歌曲列表（勾选）与批量操作条（全选/取已选）必须读同一份，否则"已选 N 首"
   * 和实际勾选会对不上。
   */
  @Local batchSelection: PlaylistBatchSelectionStore = new PlaylistBatchSelectionStore();
  /** 大图 Hero 取色背景（与歌手/专辑详情页同款：封面主色）。 */
  @Local avgColor: string = '#1f1f22';
  /** 取色后用于渐变没入的底色（跟随封面明暗，亮封面出浅底）。 */
  @Local backdropColor: string = '#1f1f22';
  /**
   * 当前底色是否为浅色。
   *
   * **必须和 `backdropColor` 同一次计算得出**：它决定标题栏文字/图标、Hero 标题、
   * 状态栏文字用深色还是白色。以前是从颜色字符串反推（另一套阈值），
   * 两套阈值不一致就会出现「深底配深字」。
   */
  @Local lightBackdrop: boolean = false;
  /** 封面加载失败时回退到占位图标。 */
  @Local heroImageFailed: boolean = false;
  /** 已取色的封面地址，避免同一张图重复取色。 */
  private colorizedCoverUrl: string = '';
  /** 标题栏「四个点」菜单图标 componentId（openMenu 锚点）。 */
  private readonly moreMenuTargetId: string = 'playlist_more_menu_icon';
  /** 缓存菜单内容节点，避免每次点击重复创建。 */
  private moreMenuNode: ComponentContent<Object> | null = null;

  /**
   * Whether the current width breakpoint is small or medium.
   * @returns True when layout is SM or MD.
   */
  private isWidthBreakpointSmOrMd(): boolean {
    const w: WidthBreakpoint = this.breakpointEnv.widthBreakpoint;
    return w === WidthBreakpoint.WIDTH_SM || w === WidthBreakpoint.WIDTH_MD;
  }

  /**
   * Whether this page uses the mainline playlist detail layout (large width, immersive, or legacy SDK).
   * @returns True when hero and list follow the mainline composition rules.
   */
  private isPlaylistDetailMainline(): boolean {
    const w: WidthBreakpoint = this.breakpointEnv.widthBreakpoint;
    return SdkApiUtil.isSdkApiAtMost(22) ||
      this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ||
      w === WidthBreakpoint.WIDTH_LG ||
      w === WidthBreakpoint.WIDTH_XL;
  }

  /**
   * Whether the PC immersive bottom bar should participate in normal column flow.
   * @returns True when immersive decoration is active.
   */
  private isPcImmersiveBottomBarInFlow(): boolean {
    return this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE;
  }

  // ---------------------------------------------------------------------------
  // 大图 Hero：与歌手/专辑详情页同款（封面取色 + 居中大标题 + 圆形播放按钮）
  // ---------------------------------------------------------------------------

  /**
   * 歌单 / 榜单封面。
   *
   * 只用「这个歌单/榜单自己的封面」：
   *   1. 路由参数 `listCover`（榜单封面、在线歌单封面、横幅大图）；
   *   2. 本地歌单的 `PlaylistDto.cover`（导入/收藏时带过来的源歌单封面）。
   *
   * 明确**不**退回「第一首歌的封面」——那会让歌单/榜单页看起来像专辑页。
   * 取不到就返回空串，由 Hero 显示内置占位图。
   * @returns 封面地址，可能为空。
   */
  private heroCoverUrl(): string {
    if (this.listCover.length > 0) {
      return this.listCover;
    }
    if (this.resolvedPlaylistCover().length > 0) {
      return this.resolvedPlaylistCover();
    }
    return '';
  }

  /** 本地歌单自身封面（带缓存，避免 build 期间反复读存储）。 */
  private cachedCoverPlaylistId: string = '';
  private cachedCoverValue: string = '';

  private resolvedPlaylistCover(): string {
    if (this.sectionType !== 'playlist' || this.playlistId.length === 0) {
      return '';
    }
    if (this.cachedCoverPlaylistId === this.playlistId) {
      return this.cachedCoverValue;
    }
    const p = MusicStoreService.getInstance().getPlaylistById(this.playlistId);
    this.cachedCoverPlaylistId = this.playlistId;
    this.cachedCoverValue = p !== undefined ? p.cover : '';
    return this.cachedCoverValue;
  }

  /**
   * Hero / 标题栏标题：优先用路由传入的 `listTitle`；
   * 从「我的歌单」进入时路由可能不带标题，此时回落到本地歌单名。
   */
  private heroTitle(): string {
    if (this.listTitle.length > 0) {
      return this.listTitle;
    }
    if (this.sectionType === 'playlist' && this.playlistId.length > 0) {
      const p = MusicStoreService.getInstance().getPlaylistById(this.playlistId);
      if (p !== undefined && p.name.length > 0) {
        return p.name;
      }
    }
    return '歌单';
  }

  /** 副标题：曲目数 + 内容类型（收藏 / 历史 / 播放列表 / 歌单）。 */
  private heroSubtitle(): string {
    const count: number = this.listVm.playlistSongUis.length;
    let kind: string = '歌单';
    if (this.sectionType === 'favorites') {
      kind = '收藏';
    } else if (this.sectionType === 'history') {
      kind = '历史';
    } else if (this.sectionType === 'queue') {
      kind = '播放列表';
    } else if (this.topid.length > 0 || this.boardId.length > 0) {
      kind = '榜单';
    } else if (this.sectionType === 'onlinePlaylist') {
      kind = '在线歌单';
    }
    return count > 0 ? count + ' 首 · ' + kind : kind;
  }

  /**
   * 下载封面并取主色作为页面背景（与 AlbumDetailPage.loadBackdropColor 同款流程），
   * 使 Hero 下缘的渐变与页面底色无缝衔接。
   */
  private async loadBackdropColor(): Promise<void> {
    const cover: string = this.heroCoverUrl();
    if (cover.length === 0 || !/^https?:/.test(cover) || cover === this.colorizedCoverUrl) {
      return;
    }
    this.colorizedCoverUrl = cover;
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(cover, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 15000
      });
      if (resp.responseCode !== 200 || resp.result === undefined) {
        return;
      }
      const src: image.ImageSource = image.createImageSource(resp.result as ArrayBuffer);
      try {
        const pixelMap: image.PixelMap = await src.createPixelMap();
        try {
          await new Promise<void>((resolve: () => void) => {
            effectKit.createColorPicker(pixelMap,
              (error: Error | undefined, colorPicker: effectKit.ColorPicker | undefined) => {
                try {
                  if (error === undefined && colorPicker !== undefined) {
                    const color = colorPicker.getLargestProportionColor();
                    // 与歌手页（ArtistDetailPage）**完全同款**：直接用 dealColor 的暗淡色当页面底色。
                    // 之前这里换成过 coverBackdrop（亮封面出浅底），结果就是用户看到的
                    // 「日间模式背景动态取色成深色、文字也深」这类矛盾 —— 歌手页看起来没问题，
                    // 所以这里照抄它的取色流程，不再自己发明。
                    const arr: number[] = ColorConversion.dealColor(color.red, color.green, color.blue);
                    const r: number = Math.max(0, Math.min(255, arr[0]));
                    const g: number = Math.max(0, Math.min(255, arr[1]));
                    const b: number = Math.max(0, Math.min(255, arr[2]));
                    this.avgColor = `rgb(${r}, ${g}, ${b})`;
                    this.backdropColor = this.avgColor;
                    // dealColor 的亮度上限是 0.3（深色），所以前景恒定用浅色（与歌手页一致）
                    this.lightBackdrop = (0.299 * r + 0.587 * g + 0.114 * b) > 140;
                    hilog.info(PLAYLIST_LOG_DOMAIN, PLAYLIST_LOG_TAG,
                      'hero backdrop color %{public}s light=%{public}d', this.avgColor, this.lightBackdrop);
                  }
                } finally {
                  resolve();
                }
              });
          });
        } finally {
          try {
            pixelMap.release();
          } catch (_err) {
            // ignore
          }
        }
      } finally {
        src.release();
      }
    } catch (err) {
      const e: Error = err as Error;
      hilog.warn(PLAYLIST_LOG_DOMAIN, PLAYLIST_LOG_TAG, 'hero color pick failed: %{public}s', e.message ?? '');
    } finally {
      req.destroy();
    }
  }

  /**
   * 取色背景是否偏浅（决定前景文字/图标用深色还是白色）。
   *
   * 由 {@link loadBackdropColor} 在取色时一次性算好（{@link lightBackdrop}），
   * 不再从颜色字符串反推 —— **判定和实际铺的底色必须出自同一次计算**，
   * 否则两套阈值不一致就会出现「底色深、文字也深」这种自相矛盾的组合。
   * @returns True 表示背景偏浅，前景应该用深色。
   */
  private isLightBackdrop(): boolean {
    return this.lightBackdrop;
  }

  /** Hero 主文字/图标颜色。 */
  private heroFgPrimary(): ResourceColor {
    return this.isLightBackdrop() ? '#E6000000' : '#FFFFFF';
  }

  /** Hero 次要文字颜色。 */
  private heroFgSecondary(): ResourceColor {
    return this.isLightBackdrop() ? '#99000000' : '#B3FFFFFF';
  }

  /** 圆形播放按钮底色。 */
  private heroButtonTint(): ResourceColor {
    return this.isLightBackdrop() ? '#1A000000' : '#33FFFFFF';
  }

  /** 圆形播放按钮毛玻璃强度，跟随环境光等级。 */
  private heroButtonBlur(): BlurStyle {
    return this.buildAmbientBlur();
  }

  /** 环境光等级 -> 毛玻璃强度（Hero 与浮动迷你条保持一致）。 */
  private buildAmbientBlur(): BlurStyle {
    switch (this.ambientState.level) {
      case 1:
        return BlurStyle.Thin;
      case 2:
        return BlurStyle.Regular;
      case 3:
        return BlurStyle.Thick;
      default:
        return BlurStyle.Regular;
    }
  }

  /** Hero 播放按钮：播放全部（走与列表行一致的播放路径）。 */
  private playAllFromHero(): void {
    if (this.listVm.playlistSongUis.length === 0) {
      return;
    }
    hilog.info(PLAYLIST_LOG_DOMAIN, PLAYLIST_LOG_TAG, 'hero play-all rows=%{public}d',
      this.listVm.playlistSongUis.length);
    this.listVm.requestPlayByListIndex(0, this.getUIContext());
  }

  /**
   * 页面唯一的滚动内容：**大图 Hero + 歌曲列表**（两个分支共用同一份结构）。
   *
   * Hero 必须在 `Scroll` 里（而不是固定在外面），否则上滑时它不会随列表收起 ——
   * 用户明确要求「滑动时上方图片收起」，这是 musicfreeOH / 歌手页的表现。
   * 早期把 Hero 放进 Scroll 出过两个问题，根因都已消除：
   *   ① 顶部空一条 → 当时 `Scroll` 还带着 `expandSafeArea` 与错误的 `padding.top`；
   *   ② 标题栏不随滚动收起 → 当时内层 `List` 是**有界高度**，它把滚动事件吃掉了，
   *      页面级 `Scroll` 收不到 offset。现在 `PlaylistDetailSongListSection` 里的
   *      `List` 不给任何高度、`BarState.Off`、两侧 `NestedScrollMode.PARENT_FIRST`，
   *      页面级 `Scroll` 是唯一滚动容器，`bindToScrollable` 就能正常驱动标题栏收起。
   */
  @Builder
  private PlaylistScrollContentRoot() {
    Column() {
      PlaylistDetailHeroSection({
        coverUrl: this.heroCoverUrl(),
        title: this.heroTitle(),
        subtitle: this.heroSubtitle(),
        backdropColor: this.backdropColor,
        fgColor: this.heroFgPrimary(),
        fgSecondaryColor: this.heroFgSecondary(),
        buttonTint: this.heroButtonTint(),
        buttonBlur: this.heroButtonBlur(),
        onPlayAll: (): void => {
          this.playAllFromHero();
        }
      })

      GridRow({
        columns: {
          sm: BreakpointConstants.COLUMN_LG,
          md: BreakpointConstants.COLUMN_LG,
          lg: BreakpointConstants.COLUMN_LG,
          xl: BreakpointConstants.COLUMN_LG
        }
      }) {
        GridCol({
          span: {
            sm: GridConstants.SPAN_TWELVE,
            md: GridConstants.SPAN_TWELVE,
            lg: GridConstants.SPAN_TWELVE,
            xl: GridConstants.SPAN_TWELVE
          }
        }) {
          PlaylistDetailSongListSection({
            listVm: this.listVm,
            playlistId: this.sectionType === 'playlist' ? this.playlistId : '',
            searchKeyword: this.searchKeyword,
            externalSortMode: this.externalSortMode,
            customSortCommand: this.customSortCommand,
            dedupeCommand: this.dedupeCommand,
            batchExitCommand: this.batchExitCommand,
            allowBatchDelete: this.sectionType === 'playlist' && this.playlistId.length > 0,
            // 「播放全部」吸顶行要用页面底色当不透明背景
            backdropColor: this.backdropColor,
            // 在线榜单/歌单的歌曲是异步拉的，加载中显示骨架而不是空态
            loading: this.listVm.loadingOnline,
            // 与页面底部的批量操作条共用同一份选择状态
            batch: this.batchSelection,
            onBatchModeChange: (active: boolean): void => {
              this.batchMode = active;
            }
          })
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .alignItems(ItemAlign.Start)
    }
    .width(StyleConstants.FULL_WIDTH)
  }

  /**
   * Builds the nav destination body.
   *
   * 迷你播放条**不在这里渲染**：由产品壳层在根 Stack 上常驻一条悬浮迷你条，
   * 二级页面统一复用（见 `products/default` 的 `floatingMiniBar`）。
   * 这里再来一条会叠成两条，也会和壳层那条互相抢点击。
   *
   * 批量操作条在这里渲染，而且是 `Scroll` 的**同级兄弟**（在页面 `Column` 下方）——
   * 只有这样才能固定在**屏幕**底部。放进 `Scroll` 内容里会跟着列表滚，
   * 看起来就是"固定在列表底部"，与 MusicFree 不一致。
   */
  @Builder
  private PlaylistNavDestinationSlot() {
    if (this.isPcImmersiveBottomBarInFlow()) {
      Column() {
        Scroll(this.pageScrollScroller) {
          this.PlaylistScrollContentRoot()
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        // PC 沉浸式：窗口没有系统标题栏，内容顶部固定让出 56vp 给 HDS 标题栏。
        // 不用 paddingTop（那个已经废弃），Hero 在 Scroll 里、以 56 为起点向下滚。
        .padding({ top: this.isPlaylistDetailMainline() &&
          this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ? 56 : 0 })
        .backgroundColor(this.backdropColor)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else {
      // 结构：Column → Scroll（Hero + 「播放全部」行 + 歌曲列表）→ 固定的批量操作条
      //
      // ⚠️ Hero **必须在 Scroll 里**：用户要求「滑动时上方图片收起」。之前把它固定在
      // Scroll 外面（照 ArtistDetailPage 的写法），大图就永远收不起来了 —— 歌手/专辑页
      // 之所以固定 Hero 是因为它们本来就不需要这个交互，歌单/榜单页需要。
      // 「播放全部」行则由 `PlaylistDetailSongListSection` 用 List 的
      // `sticky(StickyStyle.Header)` 吸顶，滚到最下面时也留在屏幕顶部。
      Column() {
        Scroll(this.pageScrollScroller) {
          this.PlaylistScrollContentRoot()
        }
        .width(StyleConstants.FULL_WIDTH)
        .layoutWeight(1)
        // 页面级 Scroll 是唯一的滚动容器（内层 List 不滚、BarState 为 Off）
        .scrollBar(BarState.On)
        .edgeEffect(EdgeEffect.Spring)
        // 顶部**不给 padding**：Hero 要贴着屏幕顶端开始，收起的 MINI 标题栏覆盖在它上面
        // （歌手/专辑页同样如此）。加 padding 就会在 Hero 上方顶出一条空白。
        .backgroundColor(this.backdropColor)

        // 固定屏幕底部的批量操作条（与列表同级，不随滚动移动）
        if (this.batchMode) {
          PlaylistBatchActionBar({
            batch: this.batchSelection,
            displaySongs: this.listVm.playlistSongUis,
            playlistId: this.sectionType === 'playlist' ? this.playlistId : '',
            allowBatchDelete: this.sectionType === 'playlist' && this.playlistId.length > 0,
            onExit: (): void => {
              this.exitBatchMode();
            },
            onDeleted: (): void => {
              this.listVm.loadPlaylistSongs(this.playlistId);
            }
          })
          // 抬高一层：底下还有壳层的悬浮迷你播放条，不留白会把操作条压在里面
          .margin({ bottom: this.batchBarLiftVp() })
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
  }

  /**
   * Title bar button (back / menu) background: frosted translucent white so the
   * buttons match the translucent system material of the floating bar.
   */
  private ambientTitleButtonBackground(): ResourceColor {
    return $r('app.color.floating_mini_bar_background');
  }

  /** 标题栏系统材质：**直接用歌手页同一个函数** `buildTitleMaterial`。 */
  private ambientTitleMaterial(): SystemMaterialParams {
    return buildTitleMaterial(this.ambientState.level);
  }

  /** Exports the current playlist to a user-chosen file in LXMusic JSON format. */
  private exportPlaylist(): void {
    const rt = getAppRuntime();
    const ctx = rt.context;
    const uiContext = rt.uiContext;
    const toast = (message: string): void => {
      if (uiContext !== undefined) {
        uiContext.getPromptAction().showToast({ message: message, duration: 2000 });
      }
    };
    if (ctx === undefined) {
      toast('导出失败');
      return;
    }
    const title: string = this.listTitle.length > 0 ? this.listTitle : '歌单';
    try {
      const safeName: string = title.replace(/[\\/:*?"<>|]/g, '_');
      const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const saveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = ['lx_' + safeName + '_' + Date.now() + '.json'];
      docPicker.save(saveOptions).then((uris: string[]): void => {
        if (uris.length === 0) {
          return;
        }
        try {
          const encoder: util.TextEncoder = new util.TextEncoder();
          const data: Uint8Array = encoder.encodeInto(this.buildExportJson());
          const file: fs.File = fs.openSync(uris[0],
            fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
          fs.writeSync(file.fd, data.buffer as ArrayBuffer);
          fs.closeSync(file);
          toast('已导出歌单');
        } catch (_err) {
          toast('导出失败');
        }
      }).catch((_err: Object): void => {
        // user cancelled
      });
    } catch (_err) {
      toast('无法打开保存选择器');
    }
  }

  /** 标题栏「四个点」：锚定标题栏图标弹出菜单。 */
  private openMoreMenu(): void {
    if (this.moreMenuNode === null) {
      this.moreMenuNode = new ComponentContent(this.getUIContext(), wrapBuilder(playlistMoreMenuComponent));
    }
    this.getUIContext().getPromptAction().openMenu(this.moreMenuNode, { id: this.moreMenuTargetId })
      .catch((err: BusinessError): void => {
        hilog.error(PLAYLIST_LOG_DOMAIN, PLAYLIST_LOG_TAG, 'openMenu more failed: %{public}d %{public}s',
          err.code, err.message);
      });
  }

  /** Builds the LXMusic export JSON from the currently displayed playlist songs. */
  private buildExportJson(): string {
    const songs: LxSongJson[] = [];
    const uis = this.listVm.playlistSongUis;
    for (let i = 0; i < uis.length; i++) {
      const s = uis[i];
      const songJson: LxSongJson = {
        name: typeof s.title === 'string' ? s.title : '',
        singer: typeof s.singer === 'string' ? s.singer : '',
        source: s.source,
        songId: s.songId,
        songmid: s.songId,
        albumName: '',
        albumId: '',
        interval: '',
        img: s.coverUrl,
        meta: {
          songId: s.songId, songmid: s.songId, picUrl: s.coverUrl, albumName: '', albumId: ''
        }
      };
      songs.push(songJson);
    }
    const payload: LxPlaylistJson = {
      type: 'musicList',
      name: this.listTitle.length > 0 ? this.listTitle : '歌单',
      songs: songs
    };
    return JSON.stringify(payload);
  }

  /** 标题栏主标题/图标颜色。 */
  private titleBarFg(): ResourceColor {
    return this.heroFgPrimary();
  }

  /**
   * 标题栏底色。
   *
   * **恒为透明**，不跟 `backdropColor` 走：标题栏下面就是 Hero 大图，
   * 铺一层不透明的页面底色会把大图顶上截掉一条、还多出一条颜色带
   * （用户反馈的「标题颜色不对」里的"颜色不对"主要就是这条带子）。
   * 透明之后标题栏只负责文字/图标，底色由 Hero 自己决定。
   *
   * 注意：这里**不能**返回 `Color.Transparent` 以外的动态值 —— HDS 只在
   * 初始化时读一次 `titleBar` 选项（滚动切换到 scrollEffectStyle 才会重读），
   * 动态底色会在首屏和滚动后表现出两种颜色，正是「滑动一下就恢复」的现象。
   * @returns 透明色。
   */
  private titleBarBackground(): ResourceColor {
    return Color.Transparent;
  }

  /**
   * Builds HDS title bar options for back, menu, padding, and scroll/blur styles for this route.
   * @returns Configured navigation title bar for the current breakpoint and immersive mode.
   */
  private getPlaylistDetailTitleBar(): HdsNavigationTitleBarOptions {
    const startVp: number = new BreakpointType(16, 24, 24, 24, 18).getWidthValueWithHeightSM(
      this.breakpointEnv.widthBreakpoint, this.breakpointEnv.heightBreakpoint);
    const endVp: number = this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE ?
      Math.max(0, this.windowInfo.titleButtonWidthVp) + 8 : startVp;
    if (this.isPlaylistDetailMainline() && this.windowInfo.immersiveDecor === ImmersiveType.IMMERSIVE) {
      return {
        padding: {
          start: LengthMetrics.vp(startVp),
          end: LengthMetrics.vp(endVp)
        },
        style: {
          originalStyle: {
            backgroundStyle: {
              backgroundColor: this.backdropColor
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: this.titleBarFg()
              },
              backIconStyle: {
                iconColor: this.titleBarFg()
              },
              menuStyle: {
                iconColor: this.titleBarFg()
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: this.backdropColor
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: this.titleBarFg()
              },
              backIconStyle: {
                iconColor: this.titleBarFg()
              },
              menuStyle: {
                iconColor: this.titleBarFg()
              }
            }
          }
        },
        content: {
          // PC 沉浸式窗口没有系统标题栏，内容顶到最上面，所以保留标题文字
          title: {
            mainTitle: this.heroTitle()
          },
          backIcon: {
            label: 'back',
            icon: $r('sys.symbol.chevron_left'),
            isEnabled: true
          },
          menu: {
            value: [
              {
                content: {
                  label: 'share',
                  icon: $r('sys.symbol.share'),
                  isEnabled: true,
                  action: (): void => {
                    setTimeout((): void => {
                      this.exportPlaylist();
                    }, 400);
                  }
                }
              },
              {
                content: {
                  label: 'more',
                  icon: $r('sys.symbol.dot_grid_2x2'),
                  isEnabled: true,
                  componentId: this.moreMenuTargetId,
                  action: (): void => {
                    this.openMoreMenu();
                  }
                }
              }
            ]
          }
        }
      };
    }
      // 手机/平板（非沉浸）分支：**照 ArtistDetailPage 的标题栏样式**。
      // 关键点（原来这里偏了，用户反复反馈"标题颜色不对/滑动一下才恢复"）：
      //   1. 背景：originalStyle 透明（大图透上来）、scrollEffectStyle 用页面底色；
      //   2. 滚动效果：IMMERSIVE_GRADIENT_BLUR + BlurStrategy.ENABLE ——
      //      这正是歌手页的"模糊样式"，也是用户这次明确要的那一套；
      //   3. 不放主标题（歌手页也不放，歌名由 Hero 大图承担）；
      //   4. 图标颜色在 originalStyle 用**浅色**、scrollEffectStyle 用 **font_primary**：
      //      顶部时标题栏压在 Hero 大图上（图偏暗，浅色图标才看得见），
      //      滚动后标题栏变成不透明页面底色（用主题主文字色）。这样两段各自都是对的，
      //      不再依赖"异步取色结果"去决定图标颜色（那正是"首屏错、滑动后恢复"的来源）。
      return {
        padding: {
          start: LengthMetrics.vp(startVp),
          end: LengthMetrics.vp(endVp)
        },
        style: {
          blurStrategy: BlurStrategy.ENABLE,
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: '#00000000'
            },
            contentStyle: {
              backIconStyle: {
                iconColor: '#FFFFFF',
                backgroundColor: '#1AFFFFFF'
              },
              menuStyle: {
                iconColor: '#FFFFFF',
                backgroundColor: '#1AFFFFFF'
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: this.backdropColor
            },
            contentStyle: {
              backIconStyle: {
                iconColor: $r('sys.color.font_primary'),
                backgroundColor: this.ambientTitleButtonBackground()
              },
              menuStyle: {
                iconColor: $r('sys.color.font_primary'),
                backgroundColor: this.ambientTitleButtonBackground()
              }
            }
          },
          systemMaterialEffect: this.ambientTitleMaterial()
        },
        content: {
          // 标题栏不放文字（照 ArtistDetailPage）：歌单名由 Hero 大图上的大标题承担
          backIcon: {
            label: 'back',
            icon: $r('sys.symbol.chevron_left'),
            isEnabled: true
          },
          menu: {
            value: [
              {
                content: {
                  label: 'share',
                  icon: $r('sys.symbol.share'),
                  isEnabled: true,
                  action: (): void => {
                    setTimeout((): void => {
                      this.exportPlaylist();
                    }, 400);
                  }
                }
              },
              {
                content: {
                  label: 'more',
                  icon: $r('sys.symbol.dot_grid_2x2'),
                  isEnabled: true,
                  componentId: this.moreMenuTargetId,
                  action: (): void => {
                    this.openMoreMenu();
                  }
                }
              }
            ]
          }
        }
      };
    }

  /**
   * 异步拉取榜单歌曲并填充列表。
   *
   * 页面打开时**不等**它：`loadBoardSongs(boardSongs)` 已经把骨架屏点亮
   * （`loadingOnline = true`），这里拉到结果再替换，拉到空就落回空态。
   *
   * ⚠️ 无论走哪条分支都必须**结束加载态**：`finishBoardLoading` 是唯一把
   * `loadingOnline` 置回 false 的地方，漏掉就会出现「一直加载中」。
   * 这里用 try/catch/finally 兜死，任何异常都不会把骨架屏留在屏幕上。
   */
  private async loadBoardSongsAsync(): Promise<void> {
    let songs: BoardSongParam[] = [];
    try {
      const entries: BoardSongEntry[] = await this.boardSongLoader();
      songs = entries.map((e: BoardSongEntry): BoardSongParam => {
        return {
          title: e.title, singer: e.singer, source: e.source, songId: e.songId, coverUrl: e.coverUrl
        };
      });
      if (songs.length === 0) {
        hilog.warn(PLAYLIST_LOG_DOMAIN, PLAYLIST_LOG_TAG,
          'board songs empty source=%{public}s id=%{public}s', this.boardSource, this.boardId);
      }
    } catch (err) {
      const e: Error = err as Error;
      hilog.warn(PLAYLIST_LOG_DOMAIN, PLAYLIST_LOG_TAG,
        'board songs failed: %{public}s', e.message ?? '');
      songs = [];
    } finally {
      this.listVm.finishBoardLoading(songs);
    }
  }

  /**
   * Runs when the page appears: refreshes playlist data, then samples the cover color
   * so the hero gradient blends into the page background (same as the album/artist pages).
   */
  private onPlaylistDetailPageAppear(): void {
    playlistMoreAction = (action: string): void => {
      this.handleMoreAction(action);
    };
    this.batchMode = false;
    hilog.info(PLAYLIST_LOG_DOMAIN, PLAYLIST_LOG_TAG,
      'page appear sectionType=%{public}s playlistId=%{public}s title=%{public}s',
      this.sectionType, this.playlistId, this.listTitle);
    if (this.boardSource.length > 0 && this.boardId.length > 0) {
      // 打开榜单：先把预取到的（可能为空）铺上，再异步拉真正的歌曲。
      // 骨架屏由 `listVm.loadingOnline` 驱动（loadBoardSongs 设 true，拉到后设 false）。
      this.listVm.loadBoardSongs(this.boardSongs);
      void this.loadBackdropColor();
      void this.loadBoardSongsAsync();
    } else if (this.topid.length > 0) {
      this.listVm.loadOnlineToplist(this.topid).then((): void => {
        void this.loadBackdropColor();
      });
    } else if (this.sectionType === 'history') {
      this.listVm.loadHistorySongs();
      void this.loadBackdropColor();
    } else if (this.sectionType === 'favorites') {
      this.listVm.loadFavoriteSongs();
      void this.loadBackdropColor();
    } else if (this.sectionType === 'queue') {
      this.listVm.loadQueueSongs();
      void this.loadBackdropColor();
    } else if (this.sectionType === 'playlist') {
      this.listVm.loadPlaylistSongs(this.playlistId);
      void this.loadBackdropColor();
    } else if (this.sectionType === 'daily30') {
      // 「每日30首」：歌单来自首页那份推荐列表。
      // 首页（recommendation 层）把歌单写进共享状态，这里读 —— playlist 不能反向依赖
      // recommendation，所以走 common 的共享状态而不是直接引用。
      this.listVm.loadDailyThirtySongs();
      void this.loadBackdropColor();
    } else if (this.sectionType === 'onlinePlaylist' && this.onlineSource.length > 0) {
      this.listVm.loadOnlinePlaylistSongs(this.onlineSource, this.playlistId).then((): void => {
        void this.loadBackdropColor();
      });
    } else {
      this.listVm.syncPlaylistFromApi();
      void this.loadBackdropColor();
    }
  }

  /** 标题栏「四个点」菜单项回调分发。 */
  private handleMoreAction(action: string): void {
    if (action === 'search') {
      this.showSearchSheet = true;
    } else if (action === 'sortDefault') {
      this.applySortMode(PLAYLIST_SORT_DEFAULT);
    } else if (action === 'sortTitle') {
      this.applySortMode(PLAYLIST_SORT_TITLE);
    } else if (action === 'sortSinger') {
      this.applySortMode(PLAYLIST_SORT_SINGER);
    } else if (action === 'customSort') {
      this.batchExitCommand++;
      this.customSortCommand++;
    } else if (action === 'dedupe') {
      this.batchExitCommand++;
      this.dedupeCommand++;
    }
  }

  /**
   * 排序模式下发（排序按钮已从列表行内移入「四个点」菜单）。
   * `@Monitor('externalSortMode')` 只在值变化时触发，因此选中同一项时先归位到 -1 再置值。
   * @param mode 0 默认 / 1 按歌名 / 2 按歌手。
   */
  private applySortMode(mode: number): void {
    hilog.info(PLAYLIST_LOG_DOMAIN, PLAYLIST_LOG_TAG, 'sort mode -> %{public}d', mode);
    this.batchExitCommand++;
    if (this.externalSortMode === mode) {
      this.externalSortMode = -1;
    }
    this.externalSortMode = mode;
  }

  /** 多选模式退出：宿主侧只维护"是否处于多选"用于隐藏迷你条。 */
  private exitBatchMode(): void {
    this.batchMode = false;
  }

  /**
   * 批量操作条需要被抬高多少（vp）。
   *
   * 壳层的悬浮迷你播放条是根 `Stack` 最上层的一条浮层，位置贴近屏幕底部；
   * 批量操作条也在页面底部，两者会叠在一起把操作条挡住。
   * 这里按「迷你条高度 + 它距底的间距」把操作条整体上移，让它在播放器上方。
   * @returns 抬高量（vp）。
   */
  private batchBarLiftVp(): number {
    const miniBarHeight: number = 64;
    const systemInset: number = this.windowInfo.navigationBarBottomVp > 0 ?
      this.windowInfo.navigationBarBottomVp :
      WindowUtil.getInstance().getStartupNavigationBarBottomVp();
    return miniBarHeight + Math.max(12, systemInset + 8) + 8;
  }

  /** In-playlist search sheet: live filter over the current song list. */
  @Builder
  private SearchSheet() {
    Column({ space: 16 }) {
      Text('搜索当前歌单')
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      TextInput({ text: this.searchKeyword, placeholder: '输入歌名或歌手' })
        .width('100%')
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level6'))
        .padding({ left: 12, right: 12 })
        .defaultFocus(true)
        .onChange((value: string) => {
          this.searchKeyword = value;
        })

      Button('完成')
        .width('100%')
        .height(40)
        .fontSize($r('sys.float.Body_M'))
        .borderRadius($r('sys.float.corner_radius_level6'))
        .backgroundColor(MusicStoreService.getInstance().getThemeColor())
        .fontColor($r('sys.color.font_on_primary'))
        .onClick(() => {
          this.showSearchSheet = false;
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 32 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /**
   * Composes the HDS nav destination, title bar, and scrollable playlist content.
   */
  build() {
    HdsNavDestination() {
      this.PlaylistNavDestinationSlot()
    }
    .hideTitleBar(false)
    .titleBar(this.getPlaylistDetailTitleBar())
    // ★ 与 AlbumDetailPage 同款：MINI 模式标题栏是"浮"在内容之上的窄条，
    //   内容可以铺到它下面（Hero 大图直接顶到屏幕最上沿）。
    //   不设这一项时标题栏按默认的大标题模式占位，顶上就会空出一块、
    //   观感上像是有什么东西把图片挡住了 —— 这就是榜单页顶部空白的另一处原因。
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScrollScroller])
    .backgroundColor(this.backdropColor)
    // 与 AlbumDetailPage 完全一致的两件套：expandSafeArea 让内容铺满到屏幕顶端
    // （Hero 大图压在状态栏下），ignoreLayoutSafeArea 让 NavDestination 的**布局**也
    // 忽略系统安全区 —— 少一个，顶上就会空出一条状态栏高度的带子。
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .systemBarStyle(
      { statusBarContentColor: this.isLightBackdrop() ? '#000000' : '#FFFFFF' },
      { statusBarContentColor: this.isLightBackdrop() ? '#000000' : '#FFFFFF' })
    .onAppear((): void => {
      this.onPlaylistDetailPageAppear();
    })
    .onDisAppear((): void => {
      playlistMoreAction = null;
      this.batchMode = false;
      this.colorizedCoverUrl = '';
      if (this.moreMenuNode !== null) {
        this.moreMenuNode.dispose();
        this.moreMenuNode = null;
      }
    })
    .bindSheet($$this.showSearchSheet, this.SearchSheet(), {
      height: 220,
      dragBar: true,
      showClose: false,
      backgroundColor: $r('sys.color.background_secondary')
    });
  }
}

/**
 * Global builder entry for routing to {@link PlaylistDetailPage}.
 * @param name Route or page name (unused placeholder for navigation integration).
 * @param param Optional route parameters object ({topid, listTitle} for online toplists).
 */
@Builder
export function PlaylistDetailPageBuilder(name: string, param: Object) {
  PlaylistDetailPage({
    topid: (param as ToplistRouteParam | undefined)?.topid ?? '',
    listTitle: (param as ToplistRouteParam | undefined)?.listTitle ?? '',
    listCover: (param as ToplistRouteParam | undefined)?.listCover ?? '',
    sectionType: (param as ToplistRouteParam | undefined)?.sectionType ?? '',
    playlistId: (param as ToplistRouteParam | undefined)?.playlistId ?? '',
    onlineSource: (param as ToplistRouteParam | undefined)?.onlineSource ?? '',
    boardSource: (param as ToplistRouteParam | undefined)?.boardSource ?? '',
    boardId: (param as ToplistRouteParam | undefined)?.boardId ?? '',
    boardSongs: (param as ToplistRouteParam | undefined)?.boardSongs ?? []
  })
}
