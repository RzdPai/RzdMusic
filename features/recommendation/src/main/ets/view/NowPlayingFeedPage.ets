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
 * 底栏页签「**现在就听**」：一屏一首歌、上下滑换歌，**可以无限刷**。
 *
 * ## 一、这一页做什么
 *
 *   · 滑动机制 = **竖向 `Swiper`**（`.vertical(true)`）：它天生就是"整页吸附 +
 *     前后各缓存一屏"的语义，比拿 `List`/`Scroll` 拼吸附可靠（见 {@link build} 注释）。
 *   · 推荐来源两条通道**都是首页现成的**（见 {@link loadChart} / {@link loadDaily}）：
 *     未登录 → 当前平台的新歌榜（`pickFeatureBoardId('newSongs', svcSource)` → `lxLeaderboard`）；
 *     已登录 → 该平台账号的每日推荐（`AccountService.getDailyTrackIds/getTrackDetails`）。
 *   · 点歌走 `OnlinePlayUtil.playList(整份队列, 下标)`：组队列、起播、打开播放页都由它做，
 *     本页**不 push 路由、不另起播控状态**（全局播控唯一真源仍是 `MusicAppState`）。
 *
 * ## 二、无限刷（**页码/游标怎么走、依据是什么**，全部读实现得来，不猜）
 *
 * 详见 {@link loadMore} 的长注释。一句话版：
 *   · **榜单（未登录）**：`lxLeaderboard(boardId, page, limit)` 里**只有 kg 真用了 `page`**，
 *     另外四个平台的实现把 page 丢掉 ⇒ kg 走"页码递增 + 固定页大小"，
 *     其余平台走"**窗口随页数变大 + 去重切前缀**"（不伪造任何一首歌）；
 *     {@link FEED_MAX_PAGES} / {@link FEED_EMPTY_STREAK} 两道收尾保护兜住"不许死循环打接口"。
 *   · **每日推荐（已登录）**：provider 侧**没有任何分页/游标**（一次给全）⇒
 *     按任务口径"**到末尾后回到开头循环**"，实现 = `Swiper.loop(true)`，不重复插入、key 不变。
 *   · **触发时机**：滑到**倒数第 {@link FEED_PREFETCH_REMAIN} 首**时在 `onChange` 里预取
 *     （见 {@link onFeedChanged}），另有 `feedFetching` 并发闸。
 *   · **到底不出现空白**：`loop` 打开后永远滑得到下一屏；`loop` 没开时也只会停在最后一屏
 *     （`edgeEffect(EdgeEffect.Spring)` 回弹），**不会出现空屏**。
 *
 * ## 三、界面（照用户给的参考图：华为音乐全屏播放页）
 *
 * 自上而下：顶栏（左汉堡 / 右刷新，无标题文字）→ 大气泡封面 →
 * 歌词两行（当前行亮白较大 + 上一行更暗更小）→ 左对齐歌名 + 歌手/平台胶囊 →
 * 一行音质标签（描边胶囊）→ 动作行（红心+数字 / 不感兴趣 / 更多 ←→ 大号白色圆形播放键）→
 * 细进度条 + 两端时间。底部那条浮动胶囊底栏**是壳层的**，本页只让位（`bottomReserveVp`）。
 *
 * ★★ **配色一律走 token、不写死 hex**，而且这里用的是**播放页那一族"压在图上"的 token**
 *   （`app.color.player_text_primary` / `play_text_color` / `play_singer_color` /
 *    `slider_track` / `slider_select` / `info_scrim_*`）—— 它们在 `resources/base` 里有值、
 *    `resources/dark` 里**没有覆盖**，即"两个主题同值"。
 *    这正是官方/本工程对"压在照片/大图上的蒙层 + 它的文字必须成对且两主题同值"那条口径的做法
 *    （照片内容不可控，跟着主题翻就会出现"深字压深蒙层"不可读）。跨 HAR 引用 `app.color.*` 有先例：
 *    `features/recommendation/.../WearableHome.ets:42` 就在用 player 的 `app.color.font_color`。
 *
 * ## 四、几条"别再踩"的硬约束（写在这里免得下一轮又撞上）
 *
 * 1. **`buildTitleMaterial` 从 `musicbasic` 导**（`common/musicbasic/src/main/ets/util/TitleMaterial.ets:23`），
 *    **不是** `@kit.UIDesignKit` 的导出成员 —— 写成后者直接编译不过。
 * 2. **`pickFeatureBoardId` 是 `RecommendDataUtil.ets` 里导出的【函数】**，直接 import 调用；
 *    它不是 `RecommendDataUtil` 的静态方法（挂上去会报 `Property does not exist on type`）。
 * 3. **页根/HDS 标题栏/让位**：`HdsNavDestination` + `titleMode(MINI)` + 空标题 +
 *    `ignoreLayoutSafeArea([SYSTEM], [TOP, BOTTOM])`；HDS 的 `titleBar.style.avoidLayoutSafeArea`
 *    **恒为 `true`**（真机定论，见 `PageTopInsetHelper` 注释）。
 *    ⚠️ 本轮把顶栏改成"左 `backIcon` 汉堡 + 右 `menu` 刷新、`mainTitle: ''`"，
 *    且 `hideBackButton(false)`（HDS 文档原文：**true 才隐藏返回键**，默认 false；
 *    要用自定义返回图标就必须让它显示，官方 `HdsNavDestination` 示例里就是
 *    `.titleBar({...}).hideBackButton(false)` 的写法）。
 * 4. **没有 `bindToScrollable`**：那个接口只收 `Array<Scroller>`
 *    （`component/nav_destination.d.ts:1213`），本页的控制器是 `SwiperController`，类型对不上 ⇒
 *    本页顶栏**没有**"滑过才渐变模糊"，只有 `systemMaterialEffect`。别硬塞。
 * 5. **`@Param` 的默认值不能引用私有成员**：所以主题色 token 写成模块级常量。
 * 6. **歌词两行只用了"当前行 + 上一行"**：工程里**没有任何可从别的 HAR 拿到的"下一行"** ——
 *    `MiniLyricLinesComponent`（`features/player/.../view/MiniLyricLinesComponent.ets`，正是
 *    "当前行 + 下一行"那个组件）**不在 `features/player/Index.ets` 的导出面里**，
 *    而 HAR 只能按导出面引用、不能深链到内部文件；
 *    `LyricLiveViewController` 虽然导出了，但它的 `curLineText/nextLineText` 是 **private**，
 *    且在 `!isActive`（实况窗没起来）时 `update()` 直接 return，拿不到值。
 *    ⇒ 本页只复用**已有的那一条真源** `MusicStoreService.getCardLyric()`
 *    （播放链路 `MediaService.syncCardLyric()` 在每个进度回调里写进去的**当前行**），
 *    "上一行"是自己观察到的历史值 —— **都是真实数据，不新写解析、不伪造歌词**。
 *    ⚠️ 要真做出"当前行 + 下一行"，正确的改法是**在 `features/player/Index.ets` 里加一行**
 *    `export { MiniLyricLinesComponent } from './src/main/ets/view/MiniLyricLinesComponent';`
 *    然后这里换成 `MiniLyricLinesComponent()`（本轮不许动 player，故未做）。
 *
 * 诊断关键字：`grep RzdNowPlaying`（hilog 标签；load / page request / page result /
 * exhausted / dislike / favorite / play 各有独立字样，判读表见任务报告）。
 */

import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import {
  AmbientState,
  AppStorageKeys,
  buildTitleMaterial,
  HomeSourceState,
  Logger,
  MusicAppState,
  MusicStoreService,
  PageTopInsetHelper,
  PlayedSongRecord,
  StyleConstants,
  WindowInfo,
  getWindowInfoState
} from 'musicbasic';
import {
  BlurStrategy,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions,
  ScrollEffectType,
  TitleSize
} from '@kit.UIDesignKit';
import {
  AccountChangedState,
  AccountService,
  lxGetQualityOptions,
  lxLeaderboard,
  LXQualityOption,
  OnlinePlayUtil,
  PlatformAccount,
  PlatformTrackInfo,
  PlayerConstants
} from 'player';
import type { LXSearchSong, LXSearchResult } from 'player';
import { SongMoreMenu } from 'playlist';
import { RecommendPrivateSongUi } from '../model/RecommendUiModels';
import { pickFeatureBoardId } from '../util/RecommendDataUtil';

/** hilog 标签：`hdc shell hilog | grep RzdNowPlaying` 可捞本页整条链路。 */
const RZD_TAG: string = 'RzdNowPlaying';

/**
 * 未登录通道的**单页条数**（第 1 页就是它 —— 与上一版口径一致，首页那两张卡的行为不受影响）。
 */
const FEED_BOARD_LIMIT: number = 20;

/**
 * 非 kg 平台"窗口开大"时的**上界**（首）。
 *
 * 那四个平台的实现忽略 `page`（见 {@link loadMore}），只能把 `limit` 开大再切前缀；
 * 再大也只是把同一批歌反复取回来（还白等网络）⇒ 到顶之后新歌自然为 0，收尾保护接手。
 */
const FEED_BOARD_WINDOW_MAX: number = 100;

/** **收尾保护①**：页码硬上界。 */
const FEED_MAX_PAGES: number = 8;

/**
 * **收尾保护②**：连续这么多次"0 首新歌 / 请求失败"就停手。
 *
 * 必须 ≥ 2：非 kg 平台在窗口开大后**第一次**可能整批都是已见过的
 * （正好卡在窗口边界上），一次就判死会把还能翻的通道误杀。
 */
const FEED_EMPTY_STREAK: number = 2;

/** 滑到"**剩余几首**"时预取下一页（见 {@link onFeedChanged}）。 */
const FEED_PREFETCH_REMAIN: number = 3;

/**
 * 一屏卡片给底部让出的默认值（vp）。
 *
 * ⚠️ 真正的值由**壳层**按 `distributionOSApiVersion` 传进来（HDS 浮动胶囊底栏
 * 在 60100 起才存在：`56 + 16`，否则 `56`）—— 与壳层里 `shellProvidesFloatingMiniBar`
 * 那一句同源。留在这里的只是"组件被单独使用时"的兜底。
 *
 * ⚠️ 它必须加在**滑动卡片自己**的 `padding.bottom` 上，**不能**加在外层容器：
 * 加在外层会让整页少一块，滑动的每一屏都对不齐底栏。
 */
const FEED_DEFAULT_BOTTOM_RESERVE_VP: number = 56;

/** 封面边长上限（vp）：窄屏取"宽度 − 48"，宽屏（平板/展开态）不要无限放大。 */
const FEED_COVER_MAX_VP: number = 320;

/** 封面圆角（vp）——参考图是"大气泡"圆角方形。 */
const FEED_COVER_RADIUS_VP: number = 24;

/**
 * 封面之外的固定占位（vp）：歌词两行 + 歌名/歌手 + 音质标签 + 动作行 + 进度行 + 各处间距 + 呼吸留白。
 *
 * 用它把封面边长反算出来（见 {@link coverSizeVp}）—— 写死尺寸在矮窗口
 * （平板横屏 / 折叠展开）会把动作行顶出屏幕，这是本页最容易出问题的一处。
 *
 * 320 ≈ 歌词 44 + 歌名/歌手 60 + 音质 26 + 动作 56 + 进度 20 + 5 处 `space` ≈ 70 + 呼吸留白 ≈ 44。
 */
const FEED_CHROME_VP: number = 320;

/** 歌词区固定高度（vp）：**每一屏都占同样高**，否则滑动时封面会上下跳。 */
const FEED_LYRIC_BLOCK_VP: number = 44;

/**
 * 背景模糊半径（vp）。
 *
 * ★ 与播放页 {@link PlaybackPage} 的 `backdropBlurRadiusVp()` **同一口径**：`blur()` 的入参单位是
 *   **px**（官方《图像效果》），11 vp ≈ 33 px，观感与播放页那张模糊大图一致。
 */
const FEED_BACKDROP_BLUR_VP: number = 11;

/** 背景模糊封面层的透明度（与播放页同款 0.55）。 */
const FEED_BACKDROP_ALPHA: number = 0.55;

/** 音质标签在一张表值里的分隔符（`Map<string, string>` 存多枚标签，`Map` 不能直接存数组比较省事）。 */
const FEED_QUALITY_SEP: string = '|';

/** 一屏最多画几枚音质胶囊（参考图是三枚，多了这行会溢出）。 */
const FEED_QUALITY_PILL_MAX: number = 3;

/**
 * 主题色 token（**压在模糊大图上的那一族**，base/dark 同值，见文件头 §三）。
 *
 * ⚠️ 写成**模块级常量**而不是 `@Param` 默认值：`@Param` 的默认值表达式不能引用
 *  `this` 的私有方法，写成成员方法调用会编译不过。
 */
const FEED_TITLE_COLOR: Resource = $r('app.color.player_text_primary');
const FEED_SINGER_COLOR: Resource = $r('app.color.play_text_color');
const FEED_SOFT_COLOR: Resource = $r('app.color.play_singer_color');
const FEED_PAGE_BG: Resource = $r('app.color.page_background');
const FEED_PILL_BG: Resource = $r('app.color.slider_track');
const FEED_FAVORITE: Resource = $r('app.color.playlist_play_all_icon');
const FEED_TRACK: Resource = $r('app.color.slider_track');
const FEED_TRACK_PLAYED: Resource = $r('app.color.slider_select');
/** 整页深色底（同时也是"白圆按钮上的图标色"）——`#E61C1C1E`，两主题同值。 */
const FEED_DARK_SURFACE: Resource = $r('app.color.info_scrim_bottom');
/** 全透明档：同一枚 `1C1C1E` 的 α=0 值（`info_scrim_top`），用于"要透明背板"的地方。 */
const FEED_TRANSPARENT: Resource = $r('app.color.info_scrim_top');

/**
 * 数据来源（决定卡片脚注写什么、以及"没有通道"时空态说什么）。
 */
enum FeedOrigin {
  /** 还没加载 / 正在加载。 */
  NONE = 0,
  /** 当前平台的**榜单**（未登录）。 */
  BOARD = 1,
  /** 当前平台的**每日推荐**（已登录）。 */
  DAILY = 2,
  /** 加载失败或该平台没有通道（空态，写明原因）。 */
  EMPTY = 3
}

/**
 * 本页 `LazyForEach` 的数据源。
 *
 * ⚠️ 为什么要自己写一个、而不是用现成的 {@link RecommendSongUiDataSource}：
 *    `Swiper` 的 `LazyForEach` 项生成器里拿不到下标（签名只有 `item`），
 *    而点歌/补音质都需要"这一屏在队列里的下标" ⇒ 数据源必须能**按对象反查下标**。
 *    现成那个类只有 `getData/totalCount`，本页不为了自己改公共文件（它有别的引用方）。
 */
class FeedDataSource implements IDataSource {
  private rows: RecommendPrivateSongUi[] = [];
  private listeners: DataChangeListener[] = [];

  public constructor(rows: RecommendPrivateSongUi[]) {
    this.rows = rows;
  }

  public totalCount(): number {
    return this.rows.length;
  }

  public getData(index: number): RecommendPrivateSongUi {
    return this.rows[index];
  }

  /**
   * 按引用反查下标（`LazyForEach` 项生成器里拿不到下标的兜底）。
   * @param row 目标行。
   * @returns 下标；找不到返回 0（调用方点歌时 `playList` 自己会夹取）。
   */
  public indexOf(row: RecommendPrivateSongUi): number {
    const index: number = this.rows.indexOf(row);
    return index >= 0 ? index : 0;
  }

  public registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  public unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos: number = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  /**
   * 追加一批行（翻页预取用）。
   *
   * ⚠️ 必须**逐行**发 `onDataAdd(index)`：`LazyForEach` 只认数据源发出来的通知，
   *    直接改内部数组**不会**渲染（表现就是"翻页请求成功了，屏幕上却没有新歌"）。
   * @param rows 新行（调用方已去重）。
   */
  public append(rows: RecommendPrivateSongUi[]): void {
    for (let i: number = 0; i < rows.length; i++) {
      this.rows.push(rows[i]);
      const index: number = this.rows.length - 1;
      for (let l: number = 0; l < this.listeners.length; l++) {
        this.listeners[l].onDataAdd(index);
      }
    }
  }

  /**
   * 删掉一行（「不感兴趣」用）。
   * @param index 行下标。
   */
  public deleteAt(index: number): void {
    if (index < 0 || index >= this.rows.length) {
      return;
    }
    this.rows.splice(index, 1);
    for (let l: number = 0; l < this.listeners.length; l++) {
      this.listeners[l].onDataDelete(index);
    }
  }
}

/**
 * 底栏页签「现在就听」。
 */
@ComponentV2
export struct NowPlayingFeedPage {
  /**
   * 一屏卡片底部要给壳层悬浮底栏让出的高度（vp）。
   *
   * 壳层按 `deviceInfo.distributionOSApiVersion >= 60100` 传 `56 + 16` / `56`
   * （与 `Index.ets` 里 `shellProvidesFloatingMiniBar` 同一判据）。
   */
  @Param bottomReserveVp: number = FEED_DEFAULT_BOTTOM_RESERVE_VP;
  /**
   * 壳层页签「再点一次」的下发信号。
   *
   * 竖向 `Swiper` 的"顶部"就是第 0 屏 ⇒ 收到信号切回下标 0
   * （与 `RecommendPage` / `EchoReviewPage` 的 `scrollEdge(Edge.Top)` 同语义）。
   */
  @Param scrollTopCommand: number = 0;

  /** 当前平台（首页「来源平台」设置）——本页的"对应平台"就取它。 */
  @Local homeSourceState: HomeSourceState =
    AppStorageV2.connect(HomeSourceState, AppStorageKeys.HOME_SOURCE_STATE, () => new HomeSourceState())!;
  /** 全局播控唯一真源：点歌只写它（经 `OnlinePlayUtil.playList`）。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** 收藏门的真源；它的 `@Trace favoriteVersion` 让收藏状态变化能驱动本页重绘。 */
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  /** 底栏/标题栏沉浸光感档位（标题栏材质要用它，与首页同一套档位）。 */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /**
   * 账号变化信号（登录 / 退出 / 改账号）。
   *
   * ★ 本页"登录态"决定走**榜单**还是**每日推荐**两条完全不同的通道，
   *   所以账号一变就必须整页重载 —— 这里复用播放模块那个单调递增的版本号
   *   （与首页 `RecommendPage.@Monitor('accountChangedState.version')` 同一真源）。
   */
  @Local accountChangedState: AccountChangedState =
    AppStorageV2.connect(AccountChangedState, PlayerConstants.ACCOUNT_CHANGED_STATE,
      () => new AccountChangedState())!;
  /** 窗口信息（算封面边长、顶部让位用）。 */
  @Local windowInfo: WindowInfo = getWindowInfoState();
  /** 窗口断点（只为让封面边长在旋转/折叠展开时重算）。 */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;

  /** 竖向 Swiper 的控制器（"点当前页签回顶部" = `changeIndex(0)`）。 */
  private feedController: SwiperController = new SwiperController();
  /** 懒加载数据源（`LazyForEach` 直挂 `Swiper`）。 */
  @Local feedSource: FeedDataSource = new FeedDataSource([]);
  /** 当前这一屏的下标（`onChange` 写入，用于点歌时定位）。 */
  @Local currentIndex: number = 0;
  /** 加载中（空态/加载态的二选一）。 */
  @Local feedLoading: boolean = true;
  /** 已经加载的是哪条通道。 */
  @Local feedOrigin: FeedOrigin = FeedOrigin.NONE;
  /** 空态/脚注文案（**写明原因，不伪造数据**）。 */
  @Local feedHint: string = '';
  /** 已经按它加载过的平台值（去重，避免 `@Monitor` 与首次加载重复打网络）。 */
  private loadedSource: string = '';
  /**
   * 各首歌查到的音质档位标签（key = `source_songId`，值 = 多枚标签用 `|` 连起来，高档在前）。
   *
   * 音质是**按需异步查**的（`lxGetQualityOptions` 会打网络），所以只给"当前屏附近"
   * 那几首查，查到就写进这张表并通过 `qualityVersion` 触发重绘；查不到就空着，
   * 卡片上那一行**整块不显示** —— **不编一个假档位**（参考图上那三枚
   * `AUDIO Vivid / 超高清音频 / 空间音频` 是厂商品牌标签，本工程接口给不出，不冒充）。
   */
  @Local qualityLabels: Map<string, string> = new Map<string, string>();
  /** 音质表的版本号：`Map` 本身不是可观察的，靠它推动卡片重绘。 */
  @Local qualityVersion: number = 0;
  /** 已经发起过音质查询的 key（去重，避免来回滑反复打网络）。 */
  private qualityRequested: string[] = [];

  // ───────────────────── 无限刷（翻页累积）的状态 ─────────────────────

  /** 已经成功取到的页码（0 = 还没取过；第 1 页成功后 = 1，预取就是 2、3…）。 */
  private feedPage: number = 0;
  /** 并发闸：同一时刻只允许一个翻页请求在飞（滑动很快时会连续触发预取）。 */
  private feedFetching: boolean = false;
  /** 连续"0 首新歌 / 请求失败"的次数 —— 收尾保护②的计数（见 {@link loadMore}）。 */
  private feedEmptyStreak: number = 0;
  /** 这条通道还能不能往后取：true 之后**一律不再打接口**（收尾保护的总闸）。 */
  @Local feedExhausted: boolean = false;
  /** 是否让 `Swiper` 循环：到底之后打开 ⇒ 永远滑不到空白（"回到开头循环"）。 */
  @Local feedLoop: boolean = false;
  /** 已经插入过的 `source|songId`（**去重真源**，也是"同一首歌不重复插入"的判据）。 */
  private feedSeen: string[] = [];
  /** 本页点过「不感兴趣」的 key（只在**本页**隐藏，不落盘、不动播放队列）。 */
  private feedDisliked: string[] = [];
  /**
   * 数据源增删的版本号。
   *
   * ⚠️ `LazyForEach` 的数据源变了**不会**让外层 `if (totalCount() > 0)` 重算
   * （`totalCount()` 不是可观察的）⇒ 靠读这个 `@Local` 把外层订阅上，
   * 否则"删到一首不剩"时页面会停在空的 `Swiper` 上（一片空白）。
   */
  @Local feedRevision: number = 0;
  /**
   * 每首歌的总时长标签（key = `source|songId`，值 = 源数据自带的 `interval`）。
   *
   * 进度条右端的"总时长"取它（真实数据，取不到就显示 `--:--`）；
   * 正在播的那一屏改用 `MusicAppState.totalTime`（同一个真源给播放页用的那个值）。
   */
  private feedDurations: Map<string, string> = new Map<string, string>();

  // ───────────────────── 歌词两行（当前行 / 上一行）─────────────────────

  /** 当前歌词行（真源 = `MusicStoreService.getCardLyric()`，见文件头 §四.6）。 */
  @Local lyricCurrent: string = '';
  /** 上一行歌词（自己观察到的历史值，同样是真实数据）。 */
  @Local lyricPrevious: string = '';
  /** 上一次看到的是哪首歌（换歌就把两行清空，避免把上一首的残留行显示在新歌上）。 */
  private lyricSongKey: string = '';
  /** 换歌后"等一个新鲜值"：这期间收进来的值直接采纳，不写进"上一行"。 */
  private lyricAwaitingFresh: boolean = false;

  /** 本机收藏总数（红心旁边那个数字）。 */
  @Local favoriteTotal: number = 0;

  aboutToAppear(): void {
    // ⚠️ 收藏数**缓存**在这里，不要在 `build()` 里现算：`store.getFavorites()` 会
    //   `readList(KEY_FAVORITES)`（反序列化整份收藏），而进度一 tick 每张卡都会重绘
    //   ⇒ 每帧 2~3 次 JSON 解析，白白卡滑动。
    this.favoriteTotal = this.store.getFavorites().length;
    this.load();
  }

  /** 收藏变化（`@Trace favoriteVersion`）⇒ 只更新那个数字，不做别的。 */
  @Monitor('store.favoriteVersion')
  onFavoriteChanged(): void {
    this.favoriteTotal = this.store.getFavorites().length;
  }

  /** 当前平台代号（tx / kg / kw / wy / mg）—— 与首页 `mapHomeSource` 同源口径。 */
  private svcSource(): string {
    const raw: string = this.homeSourceState.source;
    return raw === 'qq' ? 'tx' : raw;
  }

  /** 当前平台的展示名（脚注/空态里写出来，用户才知道"对应平台"到底是哪个）。 */
  private sourceLabel(): string {
    switch (this.svcSource()) {
      case 'tx':
        return 'QQ音乐';
      case 'wy':
        return '网易云音乐';
      case 'kg':
        return '酷狗音乐';
      case 'kw':
        return '酷我音乐';
      case 'mg':
        return '咪咕音乐';
      default:
        return this.svcSource();
    }
  }

  // ─────────────────────────── 数据加载（两条通道）───────────────────────────

  /**
   * 加载本页内容：有账号走"每日推荐"，没账号走"榜单"。
   *
   * ★ **"是否登录"只有一个真源** = `AccountService.listAccounts()`
   *   （`features/player/src/main/ets/account/AccountService.ets:117`），
   *   与首页 `RecommendViewModel.refreshGuestMode()` 同一口径。
   *   ⚠️ `AccountService` 需要 `init(context)` 才能读 preferences，
   *     所以在读之前必须先把宿主 context 交进去（`init` 是幂等的）。
   */
  public load(): void {
    this.feedLoading = true;
    this.feedOrigin = FeedOrigin.NONE;
    this.feedHint = '';
    // ★ 换通道 / 刷新 = **一切翻页状态归零**：否则会把上一条通道的页码、去重表、
    //   "已到底"结论带过来（表现就是"切了平台以后滑两下就再也刷不出新歌"）。
    this.resetPaging();
    const src: string = this.svcSource();
    this.loadedSource = this.homeSourceState.source;
    AccountService.init(this.abilityContext());
    const accounts: PlatformAccount[] = AccountService.listAccounts();
    const acc: PlatformAccount | undefined = this.pickAccount(accounts, src);
    Logger.info(RZD_TAG, `load platform=${src} accounts=${accounts.length} matched=${acc !== undefined}`);
    if (acc === undefined) {
      // 未登录（或该平台没登录）：走**当前平台的榜单**。
      void this.loadChart(src);
      return;
    }
    void this.loadDaily(src, acc);
  }

  /** 翻页状态归零（`load()` 与"刷新"共用）。 */
  private resetPaging(): void {
    this.feedPage = 0;
    this.feedFetching = false;
    this.feedEmptyStreak = 0;
    this.feedExhausted = false;
    this.feedLoop = false;
    this.feedSeen = [];
    this.feedDurations = new Map<string, string>();
  }

  /**
   * 从账号表里挑"当前这个平台"的账号。
   *
   * ⚠️ 不能只认第一个账号：工程可能同时登录了多个平台，而用户切了「来源平台」
   * 之后要的正是**那个平台**的每日推荐（用户原话"登录了用**对应平台**的每日三十首"）。
   * @param accounts 已登录账号。
   * @param svcSource 当前平台代号。
   * @returns 该平台的账号；没有返回 undefined（调用方据此走榜单通道）。
   */
  private pickAccount(accounts: PlatformAccount[], svcSource: string): PlatformAccount | undefined {
    for (let i: number = 0; i < accounts.length; i++) {
      if (accounts[i].source === svcSource) {
        return accounts[i];
      }
    }
    return undefined;
  }

  /**
   * 未登录通道：当前平台的**新歌榜**（与首页「新歌推荐」卡同一张榜、同一个取数函数）。
   *
   * 榜单 id 全程走 `pickFeatureBoardId()`（`RecommendDataUtil.ets:87`）那张表，
   * **不手拼 `xx_数字`**；表里没有该平台时它返回**空串** ⇒ 这里直接给空态并写明原因。
   * @param src 平台代号。
   */
  private async loadChart(src: string): Promise<void> {
    const boardId: string = pickFeatureBoardId('newSongs', src);
    if (boardId.length === 0) {
      Logger.warn(RZD_TAG, `load no-board platform=${src}`);
      this.applyEmpty(`「${this.sourceLabel()}」暂无可用榜单`);
      return;
    }
    try {
      // 第 1 页与上一版逐字同口径（limit = FEED_BOARD_LIMIT）—— 只多了一个"这一页取多少"的函数。
      const limit: number = this.boardFetchLimit(1);
      const res: LXSearchResult = await lxLeaderboard(boardId, 1, limit);
      const rows: RecommendPrivateSongUi[] = [];
      for (let i: number = 0; i < res.list.length; i++) {
        rows.push(this.toRow(res.list[i], i));
      }
      Logger.info(RZD_TAG, `load board=${boardId} page=1 limit=${limit} raw=${res.list.length} songs=${rows.length}`);
      this.applyRows(rows, FeedOrigin.BOARD);
    } catch (err) {
      const e = err as BusinessError;
      Logger.error(RZD_TAG, `load failed board=${boardId} code=${e.code} msg=${e.message}`);
      this.applyEmpty(`「${this.sourceLabel()}」榜单暂时取不到`);
    }
  }

  /**
   * 已登录通道：**该平台账号的每日推荐**。
   *
   * 与首页登录态同源：`AccountService.getDailyTrackIds()`（:286）+
   * `getTrackDetails()`（:292），由该账号的 provider 取（tx / wy / kg 三个 provider 有实现）。
   * ⚠️ 没有对应 provider 的平台（kw / mg）会走到 catch ⇒ **空态并写明原因，不伪造**。
   *
   * ★★ 这条通道**没有下一页**（读 provider 实现得来，见 {@link loadMore} 的注释）⇒
   *    `applyRows` 会直接把 `feedExhausted` 置 true 并打开 `Swiper.loop`，
   *    "到末尾后回到开头循环"，不再试着往后取。
   * @param src 平台代号。
   * @param acc 该平台的账号。
   */
  private async loadDaily(src: string, acc: PlatformAccount): Promise<void> {
    try {
      const ids: string[] = await AccountService.getDailyTrackIds(acc.id);
      if (ids.length === 0) {
        Logger.warn(RZD_TAG, `daily empty platform=${src} account=${acc.id}`);
        this.applyEmpty(`「${this.sourceLabel()}」每日推荐暂时取不到`);
        return;
      }
      const tracks: PlatformTrackInfo[] = await AccountService.getTrackDetails(acc.id, ids);
      const rows: RecommendPrivateSongUi[] = [];
      for (let i: number = 0; i < tracks.length; i++) {
        rows.push(this.toRowFromTrack(tracks[i], i));
      }
      Logger.info(RZD_TAG, `load daily platform=${src} ids=${ids.length} songs=${rows.length}`);
      this.applyRows(rows, FeedOrigin.DAILY);
    } catch (err) {
      const e = err as BusinessError;
      Logger.error(RZD_TAG, `load daily failed platform=${src} code=${e.code} msg=${e.message}`);
      // kw / mg 在本工程**没有 provider 实现**（`features/player/.../account/providers` 只有
      // tx / wy / kg）⇒ 这两个平台的"每日推荐"拿不到是真实现状，如实写清楚。
      this.applyEmpty(`「${this.sourceLabel()}」未接入每日推荐，请切换到 QQ / 网易云 / 酷狗`);
    }
  }

  /** 把榜单歌转成本页的行模型（顺带记下它自带的时长，进度条右端要用）。 */
  private toRow(song: LXSearchSong, index: number): RecommendPrivateSongUi {
    const ui = new RecommendPrivateSongUi();
    ui.id = index;
    ui.title = song.name;
    ui.singer = song.singer;
    ui.source = song.source;
    ui.songId = song.songId;
    ui.coverUrl = song.img;
    this.feedDurations.set(this.songKey(ui), song.interval);
    return ui;
  }

  /** 把平台账号歌转成本页的行模型（与 `RecommendDataUtil` 那张私有映射同字段口径）。 */
  private toRowFromTrack(track: PlatformTrackInfo, index: number): RecommendPrivateSongUi {
    const ui = new RecommendPrivateSongUi();
    ui.id = index;
    ui.title = track.name;
    ui.singer = track.singer;
    ui.source = track.source;
    ui.songId = track.id;
    ui.coverUrl = track.picUrl;
    this.feedDurations.set(this.songKey(ui), track.interval);
    return ui;
  }

  /**
   * 装载成功：换数据源（**去重后**）+ 清音质表 + 回到第一屏 + 结算"这条通道还能不能翻"。
   * @param rows 原始行（可能含重复与空 songId）。
   * @param origin 这条通道。
   */
  private applyRows(rows: RecommendPrivateSongUi[], origin: FeedOrigin): void {
    this.feedSeen = [];
    const fresh: RecommendPrivateSongUi[] = this.filterFresh(rows);
    this.feedSource = new FeedDataSource(fresh);
    this.feedPage = 1;
    this.feedEmptyStreak = fresh.length === 0 ? 1 : 0;
    this.feedOrigin = origin;
    this.feedHint = origin === FeedOrigin.BOARD ?
      `来自 ${this.sourceLabel()} · 榜单` : `来自 ${this.sourceLabel()} · 每日推荐`;
    this.feedLoading = false;
    this.currentIndex = 0;
    this.qualityLabels = new Map<string, string>();
    this.qualityRequested = [];
    this.qualityVersion++;
    this.feedRevision++;
    // ★ 每日推荐**结构上没有下一页**（见 loadDaily / loadMore）⇒ 一开始就按"到底"处理，
    //   让循环直接生效。这样避免"用户滑到最后一首那一刻才切模式"（那一下会跳）。
    if (origin === FeedOrigin.DAILY) {
      this.feedExhausted = true;
      Logger.info(RZD_TAG, `daily has no paging -> loop total=${fresh.length}`);
    }
    this.syncLoop();
    // ⚠️ `Swiper.onChange` 在**切换到位**时才回调，而"首帧是否回调"没有保证 ⇒
    //    第 0 屏的音质**主动查一次**（见文件头 §四 的同一处坑）。
    if (fresh.length > 0) {
      this.requestQualityAround(0);
      // 首批就少到"已经落进预取区"（例如每日推荐只有两三首）：立刻补一页/开循环，
      // 否则要等用户先滑一下才会触发。
      if (fresh.length <= FEED_PREFETCH_REMAIN + 1) {
        void this.loadMore();
      }
    }
  }

  /** 装载失败/无通道：空态，文案里写明原因。 */
  private applyEmpty(hint: string): void {
    this.feedSource = new FeedDataSource([]);
    this.feedOrigin = FeedOrigin.EMPTY;
    this.feedHint = hint;
    this.feedLoading = false;
    this.currentIndex = 0;
    this.feedExhausted = true;
    this.feedLoop = false;
    this.feedRevision++;
  }

  /** 宿主 UIAbilityContext（`AccountService.init` 需要；拿不到就返回 undefined，由它自己兜）。 */
  private abilityContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
  }

  // ─────────────────────── 无限刷：翻页累积 + 去重 + 收尾保护 ───────────────────────

  /** 行模型 ↔ 首页那两份 ID 口径的**去重键**：`source|songId`（任务口径，不含下标、不含封面）。 */
  private songKey(row: RecommendPrivateSongUi): string {
    return row.source + '|' + row.songId;
  }

  /**
   * 把一批行里"没见过的"挑出来。
   *
   * ★ 去重真源 = {@link feedSeen}（`source|songId`）。它还有第二个作用：
   *   非 kg 平台靠"把窗口开大"往前推（见 {@link boardFetchLimit}），
   *   那次请求会把**已经插入过的前缀**原样带回来 —— 这里正好把它们切掉。
   * ★ `songId` 为空的行直接丢：点歌/收藏/音质查询全都要它，插进来只会是一张点不动的卡。
   * @param rows 原始行。
   * @returns 可以插入的新行（顺序保持）。
   */
  private filterFresh(rows: RecommendPrivateSongUi[]): RecommendPrivateSongUi[] {
    const fresh: RecommendPrivateSongUi[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const key: string = this.songKey(rows[i]);
      if (key.length <= 1) {
        continue;
      }
      if (this.feedSeen.indexOf(key) >= 0 || this.feedDisliked.indexOf(key) >= 0) {
        continue;
      }
      this.feedSeen.push(key);
      fresh.push(rows[i]);
    }
    return fresh;
  }

  /**
   * 第 `page` 页要请求的 limit。
   *
   * · **kg = 真分页**（`kgLeaderboard` 把 `page` 当页号用，`LXMusicSDK.ets:3088`）
   *   ⇒ 页大小固定，零浪费、**不会漏歌**；
   * · 其余四个平台的实现忽略 `page`（见 {@link loadMore}）⇒ 只能"把窗口开大"再切前缀。
   *   上界 {@link FEED_BOARD_WINDOW_MAX}：再大也只是把同一批歌反复取回来（还白等网络）。
   * @param page 页码（1 起）。
   * @returns 本次请求的 limit。
   */
  private boardFetchLimit(page: number): number {
    if (this.svcSource() === 'kg') {
      return FEED_BOARD_LIMIT;
    }
    return Math.min(FEED_BOARD_LIMIT * page, FEED_BOARD_WINDOW_MAX);
  }

  /**
   * 预取下一页（滑到倒数第 {@link FEED_PREFETCH_REMAIN} 首时由 {@link onFeedChanged} 触发）。
   *
   * ## 两条通道"能不能翻页"，都是**读实现**得来的（不是猜 API 文档）
   *
   * ### 1、未登录 = 榜单 · `lxLeaderboard(boardId, page, limit)`
   *     （`features/player/src/main/ets/source/LXMusicSDK.ets:169`）
   *   它内部按平台前缀分发，**只有 kg 真用了 `page`**：
   *     · `kg` → `kgLeaderboard(id, page, limit)`：URL 里真的带 `&page=` + `&pagesize=`
   *       （`:3081`，`:3088`）⇒ **真分页**；
   *     · `kw` → `kwLeaderboard(id, page, limit)`：`page` **没用**，URL 写死 `pn=0&rn=limit`
   *       （`:3031`，`:3034`）⇒ 只能加大 `rn`；
   *     · `tx` → `lxTxToplist(id, limit)`：**签名里就没有 page**（`:179`，`:2065`），
   *       它自己按 `song_begin` 循环取到 `songNum` 为止 ⇒ 加大 `songNum` 才多给；
   *     · `wy` → `wyLeaderboard(id, limit)`：**签名里就没有 page**（`:198`）；
   *     · `mg` → `mgLeaderboard(id, page, limit)`：收下了 page 但**没用**（`:3153`）。
   *   ⇒ **能翻就翻**：kg 走"页码递增 + 固定页大小"；那四个平台走
   *     "**窗口随页数变大**（`limit = 单页 × 页数`，有上界）+ {@link filterFresh} 切前缀"。
   *     两条路都**只把接口真实返回的歌插进来**（`raw` / `added` 都打日志），**不伪造数据**。
   *
   * ### 2、已登录 = 每日推荐 · `AccountService.getDailyTrackIds()`
   *     （`features/player/src/main/ets/account/AccountService.ets:286`）
   *   provider 侧**没有任何分页 / 游标**：
   *     · `TxProvider.ets:1225`：内部固定翻 `Page = 1..3` 再 `Array.from(new Set(ids))`，
   *       返回的是**一份定长的列表**，没有"下一页"的参数可传；
   *     · `WyProvider.ets:427`：`POST /weapi/v3/discovery/recommend/songs`（`{}` 空体）单次返回；
   *     · `KgProvider.ets:522`：`everyday_song_recommend` 单次返回。
   *   ⇒ **不能翻**。按任务口径改成"**到末尾后回到开头循环**"，实现 = `Swiper.loop(true)`
   *     （`applyRows` 里对 DAILY 直接置 `feedExhausted` 并 {@link syncLoop}）：
   *     不重复插入同一首歌、`LazyForEach` 的 key 不变，滑到头也**不会出现空白**。
   *
   * ## 收尾保护（两道，避免死循环打接口）
   *   ① 连续 {@link FEED_EMPTY_STREAK} 次"0 首新歌 / 请求失败" ⇒ {@link markExhausted}，
   *      此后**一律不再打接口**（`feedExhausted` 是总闸）；
   *   ② 页码硬上界 {@link FEED_MAX_PAGES}。
   *   两者都会落一行 `RzdNowPlaying exhausted reason=…`（上机判读见任务报告）。
   */
  private async loadMore(): Promise<void> {
    if (this.feedFetching || this.feedExhausted) {
      return;
    }
    if (this.feedOrigin !== FeedOrigin.BOARD) {
      // 每日推荐 / 空态 / 还没加载完：没有下一页（依据见方法注释）。
      this.markExhausted('no-board-channel');
      return;
    }
    this.feedFetching = true;
    const page: number = this.feedPage + 1;
    try {
      const src: string = this.svcSource();
      const boardId: string = pickFeatureBoardId('newSongs', src);
      if (boardId.length === 0) {
        this.markExhausted('board-missing');
        return;
      }
      const limit: number = this.boardFetchLimit(page);
      Logger.info(RZD_TAG,
        `page request board=${boardId} platform=${src} page=${page} limit=${limit} prev=${this.feedSource.totalCount()}`);
      const res: LXSearchResult = await lxLeaderboard(boardId, page, limit);
      const rows: RecommendPrivateSongUi[] = [];
      for (let i: number = 0; i < res.list.length; i++) {
        rows.push(this.toRow(res.list[i], i));
      }
      this.feedPage = page;
      const added: number = this.appendRows(rows);
      Logger.info(RZD_TAG,
        `page result board=${boardId} page=${page} raw=${res.list.length} added=${added} ` +
          `total=${this.feedSource.totalCount()} streak=${this.feedEmptyStreak}`);
      if (added === 0) {
        this.feedEmptyStreak++;
      } else {
        this.feedEmptyStreak = 0;
      }
      if (this.feedEmptyStreak >= FEED_EMPTY_STREAK) {
        this.markExhausted('empty-page');
      } else if (page >= FEED_MAX_PAGES) {
        this.markExhausted('max-page');
      }
    } catch (err) {
      const e = err as BusinessError;
      this.feedEmptyStreak++;
      Logger.error(RZD_TAG,
        `page failed page=${page} streak=${this.feedEmptyStreak} code=${e.code} msg=${e.message}`);
      if (this.feedEmptyStreak >= FEED_EMPTY_STREAK) {
        this.markExhausted('page-error');
      }
    } finally {
      // ⚠️ `finally` 一定要有：失败路径上不放闸的话，这条通道就再也不会有下一次预取了。
      this.feedFetching = false;
    }
  }

  /**
   * 追加（**去重后**）并通知 `LazyForEach`。
   * @param rows 原始行。
   * @returns 真正插进去多少首（0 = 这一页全是已见过的 ⇒ 交给收尾保护计数）。
   */
  private appendRows(rows: RecommendPrivateSongUi[]): number {
    const fresh: RecommendPrivateSongUi[] = this.filterFresh(rows);
    if (fresh.length === 0) {
      return 0;
    }
    this.feedSource.append(fresh);
    this.feedRevision++;
    return fresh.length;
  }

  /**
   * 收尾：标记这条通道取不动了（此后不再打接口），并把"循环"接上。
   * @param reason 判读用的短原因（会打进日志）。
   */
  private markExhausted(reason: string): void {
    if (!this.feedExhausted) {
      this.feedExhausted = true;
      Logger.info(RZD_TAG,
        `exhausted reason=${reason} page=${this.feedPage} total=${this.feedSource.totalCount()}`);
    }
    this.syncLoop();
  }

  /**
   * 把 `Swiper.loop` 同步成"这条通道还能不能长大"。
   *
   * ⚠️ **只在取不动了之后才开循环**：还在翻页时开循环的话，"滑到最后一首"会立刻跳回第一首，
   *    用户就永远看不到刚预取进来的那几首（表现是"底部总是那几首在前面转"）。
   * ⚠️ 少于 2 首不开（循环 1 首等于原地不动，`Swiper` 也没意义）。
   */
  private syncLoop(): void {
    const enable: boolean = this.feedExhausted && this.feedSource.totalCount() >= 2;
    if (this.feedLoop === enable) {
      return;
    }
    this.feedLoop = enable;
    Logger.info(RZD_TAG,
      `loop -> ${enable} total=${this.feedSource.totalCount()} exhausted=${this.feedExhausted}`);
  }

  /**
   * 顶栏右侧「换一换 / 刷新」：**丢掉翻页进度**，重新走一次本通道的第一页。
   *
   * ⚠️ 不伪造"换一批"：榜单接口给的就是那张榜（每日推荐就是那天的推荐），
   *    所以这里老老实实重取第一页；`feedDisliked` 不清（用户点过"不感兴趣"的歌不该被刷新带回来）。
   */
  private refreshFeed(): void {
    Logger.info(RZD_TAG,
      `refresh platform=${this.svcSource()} origin=${this.feedOrigin} total=${this.feedSource.totalCount()}`);
    this.load();
  }

  /**
   * 「不感兴趣」：**只在本页**把这首歌摘掉。
   *
   * · 记进 {@link feedDisliked}（本页会话内生效，不落盘、不动 `MusicStoreService`、不动播放队列）；
   * · 走数据源的 `deleteAt` ⇒ 真的从 `LazyForEach` 里删掉（不是画个灰条）；
   * · ⚠️ `songId` 为空 / 只剩一首时不删：见 {@link deleteRowAt}。
   * @param row 这一屏的歌。
   * @param index 这一屏的下标。
   */
  private dislike(row: RecommendPrivateSongUi, index: number): void {
    const key: string = this.songKey(row);
    if (key.length <= 1) {
      this.toast('这首没法标记不感兴趣');
      return;
    }
    if (this.feedSource.totalCount() <= 1) {
      this.toast('至少留一首吧');
      return;
    }
    if (this.feedDisliked.indexOf(key) < 0) {
      this.feedDisliked.push(key);
    }
    this.deleteRowAt(index);
    Logger.info(RZD_TAG,
      `dislike ${key} at=${index} total=${this.feedSource.totalCount()}`);
    this.toast('已减少这类推荐');
    // 摘掉一首之后"剩余"又少了一格 ⇒ 立刻看看要不要补一页
    if (this.feedSource.totalCount() - 1 - this.currentIndex <= FEED_PREFETCH_REMAIN) {
      void this.loadMore();
    }
  }

  /**
   * 从数据源里删掉一行，并把 `currentIndex` 收进合法范围。
   *
   * ⚠️ 删完可能只剩 1 首甚至 0 首：前者由 {@link dislike} 提前挡住，
   *    后者在空态分支兜住（外层 `if` 读 `feedRevision` 订阅，见那个字段的注释）。
   * @param index 行下标。
   */
  private deleteRowAt(index: number): void {
    this.feedSource.deleteAt(index);
    this.feedRevision++;
    const total: number = this.feedSource.totalCount();
    if (index < this.currentIndex) {
      this.currentIndex = this.currentIndex - 1;
    }
    if (this.currentIndex > total - 1) {
      this.currentIndex = Math.max(total - 1, 0);
    }
    this.syncLoop();
  }

  // ─────────────────────────── 音质标签（按需、异步）───────────────────────────

  /** 音质表的 key。 */
  private qualityKey(row: RecommendPrivateSongUi): string {
    return row.source + '_' + row.songId;
  }

  /** 给"当前屏前后各一屏"那几首查音质（`cachedCount(1)` ⇒ 前后各缓存一屏）。 */
  private requestQualityAround(index: number): void {
    const total: number = this.feedSource.totalCount();
    for (let offset: number = -1; offset <= 1; offset++) {
      const i: number = index + offset;
      if (i < 0 || i >= total) {
        continue;
      }
      this.requestQuality(this.feedSource.getData(i));
    }
  }

  /**
   * 查一首歌的可用档位标签（**全部**档位，不只最高那一档 —— 卡片上那一行要画成一排胶囊）。
   *
   * 用的是工程现成的 `lxGetQualityOptions(song)`（`features/player/.../source/LXQualityApi.ets`
   * —— 实时接口 → 脚本声明档位四级降级）；查不到就**不显示**，不编假档位。
   * @param row 目标歌曲。
   */
  private requestQuality(row: RecommendPrivateSongUi): void {
    if (row.songId.length === 0 || row.source.length === 0) {
      return;
    }
    const key: string = this.qualityKey(row);
    if (this.qualityRequested.indexOf(key) >= 0 || this.qualityLabels.has(key)) {
      return;
    }
    this.qualityRequested.push(key);
    const song: LXSearchSong = this.toLxSong(row);
    lxGetQualityOptions(song).then((options: LXQualityOption[]): void => {
      if (options.length === 0) {
        return;
      }
      // 音质表按低→高排 ⇒ 倒着走，最高档排在最前面（与参考图上那排胶囊的读法一致）。
      const labels: string[] = [];
      for (let i: number = options.length - 1; i >= 0; i--) {
        const label: string = this.qualityLabel(options[i].type);
        if (label.length > 0 && labels.indexOf(label) < 0) {
          labels.push(label);
        }
      }
      if (labels.length === 0) {
        return;
      }
      const next: Map<string, string> = new Map<string, string>();
      this.qualityLabels.forEach((value: string, mapKey: string): void => {
        next.set(mapKey, value);
      });
      next.set(key, labels.join(FEED_QUALITY_SEP));
      // 换新的 Map 引用 + 抬版本号：`Map` 本身不是可观察对象，只有这样卡片才会重绘。
      this.qualityLabels = next;
      this.qualityVersion++;
    }).catch((): void => {
      // 查不到就空着 —— 卡片上那一行整块不显示，不伪造。
    });
  }

  /**
   * 这一屏要画成胶囊的档位标签（最多 {@link FEED_QUALITY_PILL_MAX} 枚，查不到就返回空数组）。
   * ⚠️ 函数里必须先读一下 `qualityVersion`：`Map` 不是可观察的，读版本号才能让卡片订阅上重绘。
   * @param row 这一屏的歌。
   * @returns 标签数组（可能是空数组 ⇒ 那一行整块不显示）。
   */
  private qualityPills(row: RecommendPrivateSongUi): string[] {
    if (this.qualityVersion < 0) {
      return [];
    }
    const joined: string | undefined = this.qualityLabels.get(this.qualityKey(row));
    if (joined === undefined || joined.length === 0) {
      return [];
    }
    const all: string[] = joined.split(FEED_QUALITY_SEP);
    const pills: string[] = [];
    for (let i: number = 0; i < all.length && pills.length < FEED_QUALITY_PILL_MAX; i++) {
      if (all[i].length > 0) {
        pills.push(all[i]);
      }
    }
    return pills;
  }

  /** LX 音质 id → 卡片上的短标签（与 `RecordListPage.qualityLabel` 同一张对照表）。 */
  private qualityLabel(quality: string): string {
    switch (quality) {
      case '128k':
        return '128k';
      case '320k':
        return '320k';
      case 'flac':
        return 'FLAC';
      case 'flac24bit':
        return 'Hi-Res';
      default:
        return quality;
    }
  }

  // ─────────────────────────── 播放 ───────────────────────────

  /** 行模型 → LX 搜索歌（`OnlinePlayUtil.playList` 入参类型）。 */
  private toLxSong(row: RecommendPrivateSongUi): LXSearchSong {
    return {
      songId: row.songId,
      name: typeof row.title === 'string' ? row.title : '',
      singer: typeof row.singer === 'string' ? row.singer : '',
      albumName: '',
      albumId: '',
      source: row.source,
      interval: '',
      img: row.coverUrl,
      types: []
    };
  }

  /** 整份队列（顺序与屏幕上从上到下一致 —— 上下滑换歌与播放队列必须是同一个顺序）。 */
  private buildQueue(): LXSearchSong[] {
    const songs: LXSearchSong[] = [];
    const total: number = this.feedSource.totalCount();
    for (let i: number = 0; i < total; i++) {
      songs.push(this.toLxSong(this.feedSource.getData(i)));
    }
    return songs;
  }

  /**
   * 播放第 `index` 首。
   *
   * ★ 唯一入口：`OnlinePlayUtil.playList(appState, 整份队列, index, uiContext)`
   *   （`features/player/.../util/OnlinePlayUtil.ets:211`）—— 组队列 / `MediaService.loadAsset`
   *   / 打开播放页都由它做；本页**不 push 路由、不另起播控状态**。
   * @param index 队列下标。
   */
  private playAt(index: number): void {
    const songs: LXSearchSong[] = this.buildQueue();
    if (songs.length === 0) {
      return;
    }
    const target: number = index < 0 || index >= songs.length ? 0 : index;
    Logger.info(RZD_TAG, `play index=${target} songs=${songs.length}`);
    void OnlinePlayUtil.playList(this.appState, songs, target, this.getUIContext());
  }

  /** 当前这一屏是否就是全局在播的那首（决定播放按钮画"播放"还是"暂停"）。 */
  private isCurrentSong(row: RecommendPrivateSongUi): boolean {
    const item = this.appState.getCurrentSongItem();
    if (item === undefined) {
      return false;
    }
    return item.source === row.source && item.songId === row.songId;
  }

  /**
   * 卡片上的播放/暂停按钮。
   *
   *  · 就是当前这首 ⇒ 只翻 `MusicAppState.isPlay`（**不重开队列**，否则进度会被重置）；
   *  · 不是 ⇒ 走 {@link playAt} 从这首开始放。
   * @param row 这一屏的歌。
   * @param index 这一屏的下标。
   */
  private onPlayButton(row: RecommendPrivateSongUi, index: number): void {
    if (this.isCurrentSong(row)) {
      this.appState.isPlay = !this.appState.isPlay;
      Logger.info(RZD_TAG, `toggle play -> ${this.appState.isPlay}`);
      return;
    }
    this.playAt(index);
  }

  // ─────────────────────────── 收藏 ───────────────────────────

  /**
   * 收藏门：按 `store.isFavorite(source, songId)` 现算（`@Trace favoriteVersion` 会驱动重绘）。
   * @param row 这一屏的歌。
   * @returns true = 已收藏。
   */
  private isFavorited(row: RecommendPrivateSongUi): boolean {
    if (row.source.length === 0 || row.songId.length === 0) {
      return false;
    }
    // 读一下版本号，确保收藏状态变化被这个组件观察到（`favoriteVersion` 是 `@Trace`）。
    const version: number = this.store.favoriteVersion;
    return version >= 0 && this.store.isFavorite(row.source, row.songId);
  }

  /**
   * 收藏/取消收藏。
   *
   * 走的是工程**现成的那一条**（与 `MusicPlayInfoBlock.toggleFavorite()` 逐字同款口径，
   * 见 `features/player/src/main/ets/view/MusicPlayInfoBlock.ets:170`）：
   * `MusicStoreService.removeFavorite` / `addFavorite(PlayedSongRecord)` ——
   * 不新造收藏通道，也不写别的存储。
   * @param row 这一屏的歌。
   */
  private toggleFavorite(row: RecommendPrivateSongUi): void {
    if (row.source.length === 0 || row.songId.length === 0) {
      this.toast('本地歌曲暂不支持收藏');
      return;
    }
    if (this.store.isFavorite(row.source, row.songId)) {
      this.store.removeFavorite(row.source, row.songId);
      Logger.info(RZD_TAG, `favorite off ${row.source}_${row.songId}`);
      return;
    }
    const record = new PlayedSongRecord();
    record.songId = row.songId;
    record.name = typeof row.title === 'string' ? row.title : '';
    record.singer = typeof row.singer === 'string' ? row.singer : '';
    record.source = row.source;
    record.img = row.coverUrl;
    record.url = '';
    record.lyric = '';
    record.time = Date.now();
    this.store.addFavorite(record);
    Logger.info(RZD_TAG, `favorite on ${row.source}_${row.songId}`);
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  // ─────────────────────────── 交互信号 ───────────────────────────

  /**
   * 换歌到位：记下标 + 补音质标签 + **预取下一页**。
   *
   * ★ 触发时机就是这里（`Swiper.onChange`，`component/swiper.d.ts` 的 `Callback<number>` 档）：
   *   滑到**倒数第 {@link FEED_PREFETCH_REMAIN} 首**时请求下一页，让用户滑到底之前
   *   新歌已经进来了 —— 页面永远不会出现"滑不动了才知道没数据"。
   *   并发由 {@link loadMore} 里的 `feedFetching` 闸住（快速连滑只会有一个请求在飞）。
   */
  private onFeedChanged(index: number): void {
    this.currentIndex = index;
    const total: number = this.feedSource.totalCount();
    Logger.info(RZD_TAG,
      `swiper -> index=${index} total=${total} page=${this.feedPage} exhausted=${this.feedExhausted} loop=${this.feedLoop}`);
    this.requestQualityAround(index);
    if (total - 1 - index <= FEED_PREFETCH_REMAIN) {
      void this.loadMore();
    }
    // ★ 页内**不播**：上下滑只是翻卡片，点播放按钮/点封面才真正起播 ——
    //   参考图的语义也是"滑到一个位置，再决定听哪首"。
    //   （若将来要"滑到哪就播哪"，只在这里调 `playAt(index)` 即可。）
  }

  /**
   * 顶栏左侧「汉堡」：展开**完整播放器**（壳层那层浮层）。
   *
   * ★ 走的就是壳层/首页现成的动作：`appState.isShowPlay = true`
   *   （首页「现在就听」卡 `RecommendViewModel.openPlayer():67`、
   *     迷你条 `MiniBarPlayer.ets:111` 都是这一句），不 push 路由、不新造入口。
   * ⚠️ 参考图那一枚在华为音乐里是"收起"，本页是**底栏页签**、没有可收起的上层，
   *   所以这里取"展开完整播放器"——**有真实动作，不是画个图标**。
   * ⚠️ 没有在播的歌时不开（否则会打开一个空播放页），改成给一句提示。
   */
  private openFullPlayer(): void {
    if (this.appState.getCurrentSongItem() === undefined) {
      Logger.info(RZD_TAG, 'open player skipped: no current song');
      this.toast('还没有在播的歌');
      return;
    }
    Logger.info(RZD_TAG, `open full player from feed index=${this.currentIndex}`);
    this.appState.isShowPlay = true;
  }

  /**
   * 播放进度 / 当前曲目变化 ⇒ 刷新"歌词两行"。
   *
   * ★ 歌词真源 = `MusicStoreService.getCardLyric()`
   *   （`common/musicbasic/.../MusicStoreService.ets:1393`）：播放链路的
   *   `MediaService.syncCardLyric()` 在**每个进度回调**里把"当前行"写进去
   *   （`features/player/.../MediaService.ets:326/350`），是这个页面能拿到的**唯一**真源。
   * ★ 为什么盯 `progress`：它 500ms 一跳（`MediaService` 的 updateTime 回调），
   *   正好够"换行就换字"；`selectIndex` 用来发现换歌。
   * ⚠️ `getCardLyric()` 不是可观察对象 ⇒ 必须靠这个 `@Monitor` 主动读、写进 `@Local` 才会重绘。
   * ⚠️ 换歌后先"等一个新鲜值"（`lyricAwaitingFresh`）：`syncCardLyric` 在新歌歌词还没加载时
   *   会**直接 return、保留上一首的残留值**（那是播放链路的行为，本页改不了）——
   *   不等一下就会把上一首的最后一行显示在新歌上。
   */
  @Monitor('appState.progress', 'appState.selectIndex')
  onPlaybackTick(): void {
    const song = this.appState.getCurrentSongItem();
    const key: string = song === undefined ? '' : song.source + '|' + song.songId;
    if (key !== this.lyricSongKey) {
      this.lyricSongKey = key;
      this.lyricCurrent = '';
      this.lyricPrevious = '';
      this.lyricAwaitingFresh = true;
      return;
    }
    const line: string = this.store.getCardLyric();
    if (this.lyricAwaitingFresh) {
      if (line.length === 0) {
        return;
      }
      this.lyricAwaitingFresh = false;
      this.lyricPrevious = '';
      this.lyricCurrent = line;
      return;
    }
    if (line === this.lyricCurrent) {
      return;
    }
    this.lyricPrevious = this.lyricCurrent;
    this.lyricCurrent = line;
  }

  /** 平台变了（用户在设置里切了「来源平台」）⇒ 整页换内容。 */
  @Monitor('homeSourceState.source')
  onHomeSourceChanged(): void {
    if (this.loadedSource === this.homeSourceState.source) {
      return;
    }
    Logger.info(RZD_TAG, `source changed -> reload ${this.homeSourceState.source}`);
    this.load();
  }

  /** 账号变了（登录/退出）⇒ 两条通道可能要互换，整页重载。 */
  @Monitor('accountChangedState.version')
  onAccountChanged(): void {
    Logger.info(RZD_TAG, `account changed (v=${this.accountChangedState.version}) -> reload`);
    this.load();
  }

  /** 壳层点了当前页签：回到第一屏。 */
  @Monitor('scrollTopCommand')
  onScrollTopCommand(): void {
    this.feedController.changeIndex(0);
  }

  // ─────────────────────────── 版式 ───────────────────────────

  /**
   * 封面边长（vp）。
   *
   * 算式：`min(窗口宽 − 48, 窗口高 − 顶部让位 − chrome, FEED_COVER_MAX_VP)`，
   * 再保证不小于 140（极矮窗口下宁可让内容可滚，也不要把封面压成一条）。
   * @returns 封面边长（vp）。
   */
  private coverSizeVp(): number {
    const widthVp: number = this.windowInfo.windowSize.width > 0 ?
      this.getUIContext().px2vp(this.windowInfo.windowSize.width) : 360;
    const heightVp: number = this.windowInfo.windowSize.height > 0 ?
      this.getUIContext().px2vp(this.windowInfo.windowSize.height) : 780;
    const byWidth: number = widthVp - 48;
    const byHeight: number = heightVp - PageTopInsetHelper.targetContentTopVp() - FEED_CHROME_VP -
      this.bottomReserveVp;
    const size: number = Math.min(Math.min(byWidth, byHeight), FEED_COVER_MAX_VP);
    return Math.max(size, 140);
  }

  /**
   * HDS 标题栏 —— 参考图那一行：**左汉堡 + 右刷新、没有标题文字**。
   *
   * ★ 做法是"用 HDS 自己的两个槽位"，不是另起一条自绘 Row：
   *   · 左侧 = `content.backIcon`（返回图标区域），配 `hideBackButton(false)`
   *     —— HDS 文档原文（`ui-design-hdsnavdestination`）：「**true：隐藏返回键；false：显示返回键**，
   *       默认 false」，官方 `HdsNavDestination` 示例也是 `.titleBar({...}).hideBackButton(false)`；
   *       要用自定义图标就必须让它显示，否则那个槽位整个不渲染。
   *     `HdsNavigationIconOptions.action` 会把默认的"返回上一页"替换成我们的动作（{@link openFullPlayer}）。
   *   · 右侧 = `content.menu.value`（与 `RecommendPage.ets:707` 的写法逐字同款）。
   *   · `mainTitle` 给空串：参考图**没有标题文字**，但保留这一项可以让标题区域仍然占位、
   *     两个图标仍然分居两端（完全省略 `title` 的话布局由 HDS 内部决定，观感不可控）。
   *
   * ⚠️ 图标/标题**一律不给 `sys.color.*`**：本页整屏压在模糊封面上，
   *   而 `sys.color.*` 跟着系统深浅色翻（日间变近黑 ⇒ 黑图标压深蒙层看不见）。
   *   用播放页那一族"压在图上、两主题同值"的 token，并用 `info_scrim_top`（α=0）把背板抹透明。
   * ⚠️ 没有 `bindToScrollable`：那个接口只收 `Array<Scroller>`（`component/nav_destination.d.ts:1213`），
   *   本页控制器是 `SwiperController`，类型对不上 ⇒ 顶栏**没有**"滑过才渐变模糊"，别硬塞。
   */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    // ⚠️ 不能先写一个 `const onImageIcon = {…}` 再复用：ArkTS 禁止无类型对象字面量
    //   （`arkts-no-untyped-obj-literals`）。四个槽位只能各写一份内联字面量
    //   —— 内联时它由接口上下文定型，才合法（`RecommendPage.ets:676-697` 就是这么写的）。
    return {
      // ★ 真机定论（见 `PageTopInsetHelper.avoidLayoutSafeArea` 的注释）：HDS 标题栏容器
      //   本来就在状态栏下沿，true 会让它**再退一个状态栏** ⇒ 标题跑到 76..132。恒为 true 是本工程
      //   `RecommendPage` / `EchoReviewPage` 的现行口径，照抄。
      avoidLayoutSafeArea: true,
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        // 顶栏背板透明（α=0 的同色 token）——否则会有一条实底压在模糊封面上
        originalStyle: {
          backgroundStyle: {
            backgroundColor: FEED_TRANSPARENT
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: FEED_TITLE_COLOR
            },
            menuStyle: {
              backgroundColor: FEED_TRANSPARENT,
              iconColor: FEED_TITLE_COLOR
            },
            backIconStyle: {
              backgroundColor: FEED_TRANSPARENT,
              iconColor: FEED_TITLE_COLOR
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: FEED_TRANSPARENT
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: FEED_TITLE_COLOR
            },
            menuStyle: {
              backgroundColor: FEED_TRANSPARENT,
              iconColor: FEED_TITLE_COLOR
            },
            backIconStyle: {
              backgroundColor: FEED_TRANSPARENT,
              iconColor: FEED_TITLE_COLOR
            }
          }
        },
        // ★ `buildTitleMaterial` 来自 **musicbasic**（`TitleMaterial.ets:23`），
        //   不是 `@kit.UIDesignKit` —— 见文件头 §四.1。
        //   档位与首页共用 `AmbientState.level`（0=跟随系统 / 1 / 2 / 3）。
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        title: {
          // 参考图顶栏没有标题文字（只占位，保证左右两个图标分居两端）
          mainTitle: '',
          mainTitleSize: TitleSize.TITLE_ML
        },
        backIcon: {
          label: 'collapse',
          icon: $r('sys.symbol.hamburgers'),
          isEnabled: true,
          action: (): void => {
            this.openFullPlayer();
          }
        },
        menu: {
          value: [
            {
              content: {
                label: 'refresh',
                icon: $r('sys.symbol.arrow_clockwise'),
                isEnabled: true,
                action: (): void => {
                  this.refreshFeed();
                }
              }
            }
          ]
        }
      }
    };
  }

  /** 空态/加载态。 */
  @Builder
  private FeedStatus() {
    Column({ space: 12 }) {
      if (this.feedLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color(FEED_TITLE_COLOR)
      } else {
        SymbolGlyph($r('sys.symbol.music_note_circle_fill'))
          .fontSize(40)
          .fontColor([FEED_SINGER_COLOR])
        Text(this.feedHint.length > 0 ? this.feedHint : '暂时没有可以听的歌')
          .fontSize(14)
          .fontColor(FEED_SINGER_COLOR)
          .textAlign(TextAlign.Center)
          .maxLines(3)
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 32, right: 32 })
  }

  /**
   * ② 大气泡封面（整块可点 = 从这首开始放，与首页卡片"点封面就播"的直觉一致）。
   * @param row 这一屏的歌。
   * @param index 这一屏的下标。
   */
  @Builder
  private FeedCover(row: RecommendPrivateSongUi, index: number) {
    Image(row.coverUrl.length > 0 ? row.coverUrl : $r('app.media.ic_avatar1'))
      .width(this.coverSizeVp())
      .height(this.coverSizeVp())
      .borderRadius(FEED_COVER_RADIUS_VP)
      .objectFit(ImageFit.Cover)
      .alt($r('app.media.ic_avatar1'))
      .draggable(false)
      .onClick((): void => {
        this.playAt(index);
      })
  }

  /**
   * ③ 歌词两行：**当前行（亮白、较大）+ 上一行（更暗、更小）**。
   *
   * ⚠️ 每一屏都占**同样高度**（{@link FEED_LYRIC_BLOCK_VP}）：不是当前在播的那一屏时只占位、不写字 ——
   *    否则各屏高度不同，上下滑的时候封面会一跳一跳。
   * ⚠️ 参考图是"上行几乎透明 / 当前行亮 / 下行更暗"三层，本页只有两层：见文件头 §四.6
   *    （"下一行"在本工程没有任何可公开导入的来源，不许为此新写一套解析）。
   * @param row 这一屏的歌。
   */
  @Builder
  private FeedLyric(row: RecommendPrivateSongUi) {
    Column({ space: 2 }) {
      Text(this.lyricLineFor(row, true))
        .fontSize(13)
        .fontColor(FEED_SOFT_COLOR)
        .opacity(0.45)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(StyleConstants.FULL_WIDTH)
        .textAlign(TextAlign.Center)
      Text(this.lyricLineFor(row, false))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(FEED_TITLE_COLOR)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(StyleConstants.FULL_WIDTH)
        .textAlign(TextAlign.Center)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(FEED_LYRIC_BLOCK_VP)
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 这一屏要显示的歌词行。
   *
   * ★ 只有**正在播的那一屏**才有歌词：歌词真源是全局播控的"当前行"，
   *   把它画在别的歌的卡上就是错的内容。
   * @param row 这一屏的歌。
   * @param previous true = 上一行，false = 当前行。
   * @returns 歌词文本；不适用时返回空串（占位仍在）。
   */
  private lyricLineFor(row: RecommendPrivateSongUi, previous: boolean): string {
    if (!this.isCurrentSong(row)) {
      return '';
    }
    return previous ? this.lyricPrevious : this.lyricCurrent;
  }

  /**
   * ④ 歌手 + 一枚描边胶囊。
   *
   * ⚠️ 参考图那一枚是 **VIP**，但本工程**没有任何"这首歌需要会员"的真实字段**
   *   （`LXSearchSong` / `PlatformTrackInfo` / `LXQualityOption` 都没有 pay/vip 成员；
   *    `grep privilege` 只命中 kg 音质网关里当"可用档位"用的那个字段）——
   *   给每首歌挂一枚 VIP 就是伪造。所以同一个位置放**来源平台**（真实数据，`row.source`）。
   * @param row 这一屏的歌。
   */
  @Builder
  private FeedArtist(row: RecommendPrivateSongUi) {
    Row({ space: 8 }) {
      Text(row.singer)
        .fontSize(14)
        .fontColor(FEED_SINGER_COLOR)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(this.sourceTagOf(row))
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor(FEED_SOFT_COLOR)
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .borderRadius(4)
        .borderWidth(1)
        .borderColor(FEED_SOFT_COLOR)
        .backgroundColor(FEED_PILL_BG)
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(VerticalAlign.Center)
  }

  /** 行里的来源平台代号 → 展示名（`row.source` 为空时返回空串 ⇒ 不画那枚胶囊）。 */
  private sourceTagOf(row: RecommendPrivateSongUi): string {
    switch (row.source) {
      case 'tx':
        return 'QQ音乐';
      case 'wy':
        return '网易云';
      case 'kg':
        return '酷狗';
      case 'kw':
        return '酷我';
      case 'mg':
        return '咪咕';
      default:
        return '';
    }
  }

  /**
   * ⑤ 音质标签行（左对齐、描边胶囊）：**查到几枚画几枚**，一枚都没有就整块不显示。
   * ⚠️ 参考图那三枚（`AUDIO Vivid` / `超高清音频` / `空间音频`）是厂商品牌标签，
   *   本工程接口只给得出编码档位（128k / 320k / FLAC / Hi-Res）⇒ 画真实档位，不冒充品牌名。
   * @param row 这一屏的歌。
   */
  @Builder
  private FeedQualityRow(row: RecommendPrivateSongUi) {
    Row({ space: 8 }) {
      ForEach(this.qualityPills(row), (label: string) => {
        Text(label)
          .fontSize(10)
          .fontColor(FEED_SOFT_COLOR)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(9)
          .borderWidth(1)
          .borderColor(FEED_SOFT_COLOR)
          .backgroundColor(FEED_PILL_BG)
      }, (label: string): string => 'qp-' + this.songKey(row) + '-' + label)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(22)
    .alignItems(VerticalAlign.Center)
  }

  /**
   * ⑥ 动作行：**左** = 红心（+ 收藏数）/ 不感兴趣 / 更多；**最右** = 大号白色圆形播放键。
   *
   * · 红心走本页已接好的 {@link toggleFavorite}（`MusicStoreService` 那一条）；
   *   旁边的数字是**本机收藏总数**（`getFavorites().length`，真实数据）——
   *   参考图那个 `370w+` 是全网热度，工程里没有，不编。
   * · 「不感兴趣」= {@link dislike}（真的把这首从本页摘掉，不是画个图标）；
   * · 「更多」= 工程现成的 `SongMoreMenu`（上一轮已接好，**不许改回没动作**）；
   * · 最右那个大圆键 = {@link onPlayButton}（当前这首只翻 `MusicAppState.isPlay`，
   *   否则从这首起播）。
   * ⚠️ 白圆底在**两个主题下都必须是白的** ⇒ 底用 `player_text_primary`（#FFFFFF，两主题同值）、
   *   图标用 `info_scrim_bottom`（#1C1C1E 系，两主题同值）。**不能**用 `font_primary`
   *   （它在夜间是白 ⇒ 白图标压白圆，直接看不见）。
   * @param row 这一屏的歌。
   * @param index 这一屏的下标。
   */
  @Builder
  private FeedActions(row: RecommendPrivateSongUi, index: number) {
    Row() {
      Row({ space: 18 }) {
        Row({ space: 4 }) {
          SymbolGlyph(this.isFavorited(row) ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(24)
            .fontColor([this.isFavorited(row) ? FEED_FAVORITE : FEED_SINGER_COLOR])
            .onClick((): void => {
              this.toggleFavorite(row);
            })
          Text(String(this.favoriteCount()))
            .fontSize(12)
            .fontColor(FEED_SINGER_COLOR)
            .maxLines(1)
        }
        .alignItems(VerticalAlign.Center)

        SymbolGlyph($r('sys.symbol.heart_slash'))
          .fontSize(24)
          .fontColor([FEED_SINGER_COLOR])
          .onClick((): void => {
            this.dislike(row, index);
          })

        // 「更多」= 工程现成的歌曲菜单（播放/下载/加歌单/加收藏/加队列/查看评论）
        SongMoreMenu({
          song: this.toLxSong(row),
          iconSize: 24,
          iconColor: FEED_SINGER_COLOR
        })
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      // 最右：大号白色圆形播放/暂停（比其它图标明显大）
      Stack() {
        Circle()
          .width(56)
          .height(56)
          .fill(FEED_TITLE_COLOR)
        SymbolGlyph(this.isCurrentSong(row) && this.appState.isPlay ?
          $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
          .fontSize(28)
          .fontColor([FEED_DARK_SURFACE])
      }
      .width(56)
      .height(56)
      .onClick((): void => {
        this.onPlayButton(row, index);
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 本机收藏总数（红心旁边那个数字；真实数据，不是全网热度）。
   * ⚠️ 只读缓存字段 —— 缓存怎么维护见 `favoriteTotal` 与 {@link onFavoriteChanged}。
   */
  private favoriteCount(): number {
    return this.favoriteTotal;
  }

  /**
   * ⑦ 细进度条 + 两端时间。
   *
   * · 正在播的那一屏：左端 = `MusicAppState.currentTime`，右端 = `totalTime`，
   *   已播比例 = `progress / progressMax`（**同一个真源**给播放页用的那两个值）；
   * · 其它屏：左端 `00:00`，右端 = 这首歌源数据自带的 `interval`（取不到就 `--:--`），
   *   已播比例为 0 —— 不是"进度丢了"，而是"这首没在播"。
   * @param row 这一屏的歌。
   */
  @Builder
  private FeedProgress(row: RecommendPrivateSongUi) {
    Row({ space: 8 }) {
      Text(this.isCurrentSong(row) ? this.appState.currentTime : '00:00')
        .fontSize(11)
        .fontColor(FEED_SOFT_COLOR)

      Row() {
        Column()
          .width(this.playedPercentOf(row))
          .height(3)
          .borderRadius(2)
          .backgroundColor(FEED_TRACK_PLAYED)
      }
      .layoutWeight(1)
      .height(3)
      .borderRadius(2)
      .backgroundColor(FEED_TRACK)

      Text(this.durationOf(row))
        .fontSize(11)
        .fontColor(FEED_SOFT_COLOR)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(20)
    .alignItems(VerticalAlign.Center)
  }

  /** 这一屏右端的"总时长"文案。 */
  private durationOf(row: RecommendPrivateSongUi): string {
    if (this.isCurrentSong(row) && this.appState.totalTime.length > 0) {
      return this.appState.totalTime;
    }
    const interval: string | undefined = this.feedDurations.get(this.songKey(row));
    return interval !== undefined && interval.length > 0 ? interval : '--:--';
  }

  /** 这一屏已播部分的宽度（百分比字符串；只有正在播的那一屏会 > 0）。 */
  private playedPercentOf(row: RecommendPrivateSongUi): string {
    if (!this.isCurrentSong(row)) {
      return '0%';
    }
    const max: number = this.appState.progressMax;
    const current: number = this.appState.progress;
    if (max <= 0 || current <= 0) {
      return '0%';
    }
    const ratio: number = current >= max ? 1 : current / max;
    return Math.round(ratio * 100) + '%';
  }

  /**
   * 一屏卡片 = 参考图自上而下的那一整列。
   *
   * ⚠️ 整块自己带 `padding.bottom = bottomReserveVp`（给壳层那套浮动胶囊底栏让位）——
   *    **不能**把它加在外层容器上，否则滑动的每一屏都对不齐底栏。
   * ⚠️ 卡片自己**不画背景**：整页的底色/模糊封面由 {@link build} 那一层负责，
   *    卡片一上底色，模糊大图就被切成一块一块的了。
   * @param row 这一屏的歌。
   * @param index 这一屏在队列里的下标。
   */
  @Builder
  private FeedCard(row: RecommendPrivateSongUi, index: number) {
    Column({ space: 0 }) {
      Column({ space: 14 }) {
        // ② 大气泡封面
        this.FeedCover(row, index)
        // ③ 歌词两行（居中，等高占位）
        this.FeedLyric(row)
        // ④ 歌名（左对齐、粗体）+ 歌手 / 平台胶囊
        Column({ space: 6 }) {
          Text(row.title)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(FEED_TITLE_COLOR)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(StyleConstants.FULL_WIDTH)
            .textAlign(TextAlign.Start)
          this.FeedArtist(row)
        }
        .width(StyleConstants.FULL_WIDTH)
        .alignItems(HorizontalAlign.Start)
        // ⑤ 音质标签行
        this.FeedQualityRow(row)
        // ⑥ 动作行
        this.FeedActions(row, index)
      }
      .width(StyleConstants.FULL_WIDTH)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // ⑦ 细进度条 + 两端时间
      this.FeedProgress(row)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // ★ 给壳层浮动底栏让位：加在**卡片自己**身上（见文件头与常量注释）
    .padding({ bottom: this.bottomReserveVp, left: 24, right: 24 })
  }

  build() {
    // 页根与 `RecommendPage` / `EchoReviewPage` 同款：HdsNavDestination + MINI 标题栏 +
    // ignoreLayoutSafeArea(TOP, BOTTOM)（页盒从 y=0 起排 ⇒ 背景层可以一直铺到状态栏后面）。
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        // ── 层 1：模糊封面大图铺满整屏（跟随**当前这一屏**的歌）──────────────
        // 配方与播放页一致（`PlaybackPage.ets:2316-2321`）：`objectFit(Cover)` + 组件级 `.blur()`
        // + `opacity 0.55`，叠在深色底之上；模糊半径口径见 FEED_BACKDROP_BLUR_VP。
        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .backgroundColor(FEED_DARK_SURFACE)
        if (this.currentCoverUrl().length > 0) {
          Image(this.currentCoverUrl())
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .objectFit(ImageFit.Cover)
            .blur(FEED_BACKDROP_BLUR_VP)
            .opacity(FEED_BACKDROP_ALPHA)
            .draggable(false)
            .hitTestBehavior(HitTestMode.None)
        }
        // ── 层 2：柔和渐隐（封面上方与四周压得更实，白字才一直读得清）──────
        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              [FEED_TRANSPARENT, 0],
              [FEED_DARK_SURFACE, 1]
            ]
          })
          .hitTestBehavior(HitTestMode.None)

        // ── 层 3：内容 ────────────────────────────────────────────────
        Column() {
          if (this.feedRevision >= 0 && this.feedSource.totalCount() > 0) {
            // ★ 竖向 Swiper = "一屏一首、上下滑换歌"：
            //   · `.vertical(true)`（`component/swiper.d.ts:1790`）—— 竖向整页吸附；
            //   · `.indicator(false)`（:1666，`boolean` 档）—— 不要圆点（一屏一首时圆点没意义）；
            //   · `.cachedCount(1, true)`（:1910）—— 前后各缓存一屏，滑动不掉帧；
            //   · `.loop(this.feedLoop)`（:1731）—— **到底之后**打开 ⇒ 滑不到空白（见 syncLoop）；
            //   · `.nestedScroll(SELF_ONLY)`（:2412 / enum :1384）—— 竖向滚动自己消费，
            //     不把壳层那条"上拉打开播放页"的手势搅进来；
            //   · `.onChange((i: number) => …)`（:2132，`Callback<number>` 档）。
            //   ⚠️ 不用 `List` + 吸附：`List` 的吸附接口叫 `scrollSnapAlign(ScrollSnapAlign)`
            //     （`component/list.d.ts:1925`），而工程里见过的 `scrollSnap({…})` 是 **`Scroll`** 的
            //     属性（`component/scroll.d.ts:1875`）—— 照抄到 `List` 上直接编译错。
            Swiper(this.feedController) {
              // `LazyForEach` **直挂** `Swiper`（中间不套容器），key 稳定 ⇒ 复用正确。
              // ⚠️ key **不含下标**（翻页追加时下标会变，key 一变就要重建节点、丢掉滑动位置）。
              LazyForEach(this.feedSource, (row: RecommendPrivateSongUi) => {
                this.FeedCard(row, this.feedSource.indexOf(row))
              }, (row: RecommendPrivateSongUi): string => this.feedKey(row))
            }
            .vertical(true)
            .indicator(false)
            .cachedCount(1, true)
            .loop(this.feedLoop)
            .duration(280)
            .effectMode(EdgeEffect.Spring)
            .nestedScroll(SwiperNestedScrollMode.SELF_ONLY)
            .width(StyleConstants.FULL_WIDTH)
            .layoutWeight(1)
            .onChange((index: number): void => {
              this.onFeedChanged(index);
            })
          } else {
            this.FeedStatus()
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .hideTitleBar(false)
    // ★ 参考图的左汉堡就挂在 HDS 的"返回图标区域"上 ⇒ 必须显示返回键（HDS 文档原文：
    //   true 才隐藏）。见 getTitleBar() 的注释。
    .hideBackButton(false)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    // 内容让位靠每张卡片自己算（`FeedCard` 里 coverSizeVp 已经减掉 `targetContentTopVp()`），
    // 所以这里不再额外 padding —— 一屏一首的页，留白加在外层会让"整屏"对不齐。
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor(FEED_PAGE_BG)
  }

  /** 背景层要用的封面（= **当前这一屏**那张；空串表示没有可用封面，只留深色底）。 */
  private currentCoverUrl(): string {
    const total: number = this.feedSource.totalCount();
    if (total <= 0) {
      return '';
    }
    const index: number = this.currentIndex >= 0 && this.currentIndex < total ? this.currentIndex : 0;
    return this.feedSource.getData(index).coverUrl;
  }

  /**
   * 列表项稳定 key。
   *
   * ⚠️ 必须**不含下标**（用下标当 key 会让"翻页追加 / 删掉一首"之后的复用整体错位，
   *    用户手上的滑动位置也会跟着跳）；`source_songId` 是天然唯一键；
   *    `coverUrl` 拼在末尾是为了"封面异步补进来之后这一屏重绘一次"
   *    （同 `HeroSongListCard.rowKey` 的口径）。**去重也用同一个 `source|songId` 口径**。
   * @param row 这一屏的歌。
   * @returns 稳定 key。
   */
  private feedKey(row: RecommendPrivateSongUi): string {
    return 'feed-' + row.source + '_' + row.songId + '-' + row.coverUrl;
  }
}
