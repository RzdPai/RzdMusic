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
 * 底栏页签「**现在就听**」：一屏一首歌、**上下滑换歌**。
 *
 * ## 这一页做什么
 *
 * 用户原话（2026-10-15）：「Tab 的推荐和回响中间加个**现在就听**，像参考图那样
 * **上下滑动切换歌曲**。先用首页同款推荐方式（**没登录用对应平台的榜单**，
 * **登录了用对应平台的每日三十首**）。」
 *
 *   · 滑动机制 = **竖向 `Swiper`**（`.vertical(true)`）：它天生就是"整页吸附 +
 *     前后各缓存一屏"的语义，比拿 `List`/`Scroll` 拼吸附可靠（见 {@link build} 注释）。
 *   · 推荐来源两条通道**都是首页现成的**（见 {@link loadChart} / {@link loadDaily}）：
 *     未登录 → 当前平台的新歌榜（`pickFeatureBoardId('newSongs', svcSource)` → `lxLeaderboard`）；
 *     已登录 → 该平台账号的每日推荐（`AccountService.getDailyTrackIds/getTrackDetails`）。
 *   · 点歌走 `OnlinePlayUtil.playList(整份队列, 下标)`：组队列、起播、打开播放页都由它做，
 *     本页**不 push 路由、不另起播控状态**（全局播控唯一真源仍是 `MusicAppState`）。
 *
 * ## 几条"别再踩"的硬约束（写在这里免得下一轮又撞上）
 *
 * 1. **`buildTitleMaterial` 从 `musicbasic` 导**（`common/musicbasic/src/main/ets/util/TitleMaterial.ets:23`），
 *    **不是** `@kit.UIDesignKit` 的导出成员 —— 写成后者直接编译不过
 *    （`Module '"@kit.UIDesignKit"' has no exported member 'buildTitleMaterial'`）。
 * 2. **`pickFeatureBoardId` 是 `RecommendDataUtil.ets` 里导出的【函数】**，
 *    直接 `import { pickFeatureBoardId } from '../util/RecommendDataUtil'` 调用；
 *    它不是 `RecommendDataUtil` 的静态方法（挂上去会报 `Property does not exist on type`）。
 * 3. **页根/HDS 标题栏/让位**：与 `RecommendPage`（946 行那版）/`EchoReviewPage` 逐字同款 ——
 *    `HdsNavDestination` + `titleMode(MINI)` + `hideBackButton(true)` +
 *    `ignoreLayoutSafeArea([SYSTEM], [TOP, BOTTOM])` + 内容让位 `PageTopInsetHelper.targetContentTopVp()`。
 *    另外 HDS 的 `titleBar.style.avoidLayoutSafeArea` **恒为 `true`**（真机定论，见 `PageTopInsetHelper` 注释）。
 * 4. **没有 `bindToScrollable`**：那个接口只收 `Array<Scroller>`
 *    （`component/nav_destination.d.ts:1213`），本页的控制器是 `SwiperController`，类型对不上 ⇒
 *    本页顶栏**没有**"滑过才渐变模糊"，只有 `systemMaterialEffect`。别硬塞。
 * 5. **`@Param` 的默认值不能引用私有成员**：所以那 5 个主题色 token 写成模块级常量。
 *
 * 诊断关键字：`grep RzdListenNow`（hilog 标签；加载/换歌/点歌各有一条）。
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
import type { LXSearchSong } from 'player';
import { SongMoreMenu } from 'playlist';
import { RecommendPrivateSongUi } from '../model/RecommendUiModels';
import { pickFeatureBoardId } from '../util/RecommendDataUtil';

/** hilog 标签：`hdc shell hilog | grep RzdListenNow` 可捞本页整条链路。 */
const RZD_TAG: string = 'RzdListenNow';

/**
 * 未登录时榜单取多少首。
 *
 * 20 首 ≈ 用户滑十几屏就有尽头，再多也没人翻到底；同时把 `lxLeaderboard` 的单次
 * 返回量压在常规页大小内（首页那两张卡只要 4 首拼图，本页需要"够滑"）。
 */
const FEED_BOARD_LIMIT: number = 20;

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
const FEED_COVER_MAX_VP: number = 360;

/**
 * 封面之外的固定占位（vp）：标题栏 + 歌名/歌手两行 + 操作按钮行 + 来源脚注 + 上下呼吸留白。
 *
 * 用它把封面边长反算出来（见 {@link coverSizeVp}）—— 写死尺寸在矮窗口
 * （平板横屏 / 折叠展开）会把操作按钮顶出屏幕，这是本页最容易出问题的一处。
 *
 * 240 = 歌名/歌手/音质 ≈ 80 + 动作行 ≈ 40 + 脚注 ≈ 20 + 三处 `space` ≈ 32 + 呼吸留白 ≈ 68。
 */
const FEED_CHROME_VP: number = 240;

/**
 * 主题色 token（与首页「现在就听」那张卡同一套口径）。
 *
 * ⚠️ 写成**模块级常量**而不是 `@Param` 默认值：`@Param` 的默认值表达式不能引用
 *  `this` 的私有方法，写成成员方法调用会编译不过。
 */
const FEED_TITLE_COLOR: Resource = $r('app.color.font_primary');
const FEED_SINGER_COLOR: Resource = $r('app.color.font_tertiary');
const FEED_PAGE_BG: Resource = $r('app.color.page_background');
const FEED_CARD_BG: Resource = $r('app.color.background_secondary');
const FEED_ACCENT: Resource = $r('app.color.mini_bar_primary');

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
   * 各首歌的最高可用音质标签（key = `source_songId`）。
   *
   * 音质是**按需异步查**的（`lxGetQualityOptions` 会打网络），所以只给"当前屏附近"
   * 那几首查，查到就写进这张表并通过 `qualityVersion` 触发重绘；查不到就空着，
   * 卡片上不显示档位 —— **不编一个假档位**。
   */
  @Local qualityLabels: Map<string, string> = new Map<string, string>();
  /** 音质表的版本号：`Map` 本身不是可观察的，靠它推动卡片重绘。 */
  @Local qualityVersion: number = 0;
  /** 已经发起过音质查询的 key（去重，避免来回滑反复打网络）。 */
  private qualityRequested: string[] = [];

  aboutToAppear(): void {
    this.load();
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
      Logger.warn(RZD_TAG, `no board for platform=${src}`);
      this.applyEmpty(`「${this.sourceLabel()}」暂无可用榜单`);
      return;
    }
    try {
      const res = await lxLeaderboard(boardId, 1, FEED_BOARD_LIMIT);
      const rows: RecommendPrivateSongUi[] = [];
      for (let i: number = 0; i < res.list.length; i++) {
        rows.push(this.toRow(res.list[i], i));
      }
      Logger.info(RZD_TAG, `chart loaded board=${boardId} songs=${rows.length}`);
      this.applyRows(rows, FeedOrigin.BOARD);
    } catch (err) {
      const e = err as BusinessError;
      Logger.error(RZD_TAG, `chart failed board=${boardId} code=${e.code} msg=${e.message}`);
      this.applyEmpty(`「${this.sourceLabel()}」榜单暂时取不到`);
    }
  }

  /**
   * 已登录通道：**该平台账号的每日推荐**。
   *
   * 与首页登录态同源：`AccountService.getDailyTrackIds()`（:286）+
   * `getTrackDetails()`（:292），由该账号的 provider 取（tx / wy / kg 三个 provider 有实现）。
   * ⚠️ 没有对应 provider 的平台（kw / mg）会走到 catch ⇒ **空态并写明原因，不伪造**。
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
      Logger.info(RZD_TAG, `daily loaded platform=${src} ids=${ids.length} songs=${rows.length}`);
      this.applyRows(rows, FeedOrigin.DAILY);
    } catch (err) {
      const e = err as BusinessError;
      Logger.error(RZD_TAG, `daily failed platform=${src} code=${e.code} msg=${e.message}`);
      // kw / mg 在本工程**没有 provider 实现**（`features/player/.../account/providers` 只有
      // tx / wy / kg）⇒ 这两个平台的"每日推荐"拿不到是真实现状，如实写清楚。
      this.applyEmpty(`「${this.sourceLabel()}」未接入每日推荐，请切换到 QQ / 网易云 / 酷狗`);
    }
  }

  /** 把榜单歌转成本页的行模型。 */
  private toRow(song: LXSearchSong, index: number): RecommendPrivateSongUi {
    const ui = new RecommendPrivateSongUi();
    ui.id = index;
    ui.title = song.name;
    ui.singer = song.singer;
    ui.source = song.source;
    ui.songId = song.songId;
    ui.coverUrl = song.img;
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
    return ui;
  }

  /** 装载成功：换数据源 + 清音质表 + 回到第一屏。 */
  private applyRows(rows: RecommendPrivateSongUi[], origin: FeedOrigin): void {
    this.feedSource = new FeedDataSource(rows);
    this.feedOrigin = origin;
    this.feedHint = origin === FeedOrigin.BOARD ?
      `来自 ${this.sourceLabel()} · 榜单` : `来自 ${this.sourceLabel()} · 每日推荐`;
    this.feedLoading = false;
    this.currentIndex = 0;
    this.qualityLabels = new Map<string, string>();
    this.qualityRequested = [];
    this.qualityVersion++;
    // ⚠️ `Swiper.onChange` 在**切换到位**时才回调，而"首帧是否回调"没有保证 ⇒
    //    第 0 屏的音质**主动查一次**（见类头第 5 条注释里的同一处坑）。
    if (rows.length > 0) {
      this.requestQualityAround(0);
    }
  }

  /** 装载失败/无通道：空态，文案里写明原因。 */
  private applyEmpty(hint: string): void {
    this.feedSource = new FeedDataSource([]);
    this.feedOrigin = FeedOrigin.EMPTY;
    this.feedHint = hint;
    this.feedLoading = false;
    this.currentIndex = 0;
  }

  /** 宿主 UIAbilityContext（`AccountService.init` 需要；拿不到就返回 undefined，由它自己兜）。 */
  private abilityContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
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
   * 查一首歌的最高可用档位标签。
   *
   * 用的是工程现成的 `lxGetQualityOptions(song)`（`features/player/.../source/LXQualityApi.ets:567`
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
      // 取数组里最后一档（音质表按低→高排）作为"最高可用档位"。
      const label: string = this.qualityLabel(options[options.length - 1].type);
      if (label.length === 0) {
        return;
      }
      const next: Map<string, string> = new Map<string, string>();
      this.qualityLabels.forEach((value: string, mapKey: string): void => {
        next.set(mapKey, value);
      });
      next.set(key, label);
      // 换新的 Map 引用 + 抬版本号：`Map` 本身不是可观察对象，只有这样卡片才会重绘。
      this.qualityLabels = next;
      this.qualityVersion++;
    }).catch((): void => {
      // 查不到就空着 —— 卡片上不显示档位，不伪造。
    });
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

  /** 换歌到位：记下标 + 给新的一屏（及其前后）补音质标签。 */
  private onFeedChanged(index: number): void {
    this.currentIndex = index;
    Logger.info(RZD_TAG, `swiper -> ${index}`);
    this.requestQualityAround(index);
    // ★ 页内**不播**：上下滑只是翻卡片，点播放按钮/点封面才真正起播 ——
    //   参考图的语义也是"滑到一个位置，再决定听哪首"。
    //   （若将来要"滑到哪就播哪"，只在这里调 `playAt(index)` 即可。）
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

  /** HDS 标题栏（与 `RecommendPage` 的 `getTitleBar()` 逐字同款口径）。 */
  private getTitleBar(): HdsNavigationTitleBarOptions {
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
        // ★ `buildTitleMaterial` 来自 **musicbasic**（`TitleMaterial.ets:23`），
        //   不是 `@kit.UIDesignKit` —— 见文件头第 1 条。
        //   档位与首页共用 `AmbientState.level`（0=跟随系统 / 1 / 2 / 3）。
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        title: {
          mainTitle: $r('app.string.tab_now_playing'),
          mainTitleSize: TitleSize.TITLE_ML
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
          .color(FEED_ACCENT)
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
   * 一屏卡片：大封面 + 歌名/歌手 + 音质档位 + 收藏/更多/播放三个动作。
   *
   * ⚠️ 整块自己带 `padding.bottom = bottomReserveVp`（给壳层悬浮底栏让位）——
   *    **不能**把它加在外层容器上，否则滑动的每一屏都对不齐底栏。
   * @param row 这一屏的歌。
   * @param index 这一屏在队列里的下标。
   */
  @Builder
  private FeedCard(row: RecommendPrivateSongUi, index: number) {
    Column({ space: 0 }) {
      Column({ space: 16 }) {
        // 大封面：整块可点 = 从这首开始放（与首页卡片"点封面进歌单"的直觉一致）
        Image(row.coverUrl.length > 0 ? row.coverUrl : $r('app.media.ic_avatar1'))
          .width(this.coverSizeVp())
          .height(this.coverSizeVp())
          .borderRadius(16)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.ic_avatar1'))
          .draggable(false)
          .onClick((): void => {
            this.playAt(index);
          })

        // 歌名 / 歌手（各一行，超长省略）
        Column({ space: 6 }) {
          Text(row.title)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(FEED_TITLE_COLOR)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(StyleConstants.FULL_WIDTH)
            .textAlign(TextAlign.Center)
          Text(row.singer)
            .fontSize(13)
            .fontColor(FEED_SINGER_COLOR)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(StyleConstants.FULL_WIDTH)
            .textAlign(TextAlign.Center)
        }
        .width(StyleConstants.FULL_WIDTH)

        // 音质档位：**查到了才显示**，查不到就整块不占位（不编假档位）
        if (this.qualityLabels.has(this.qualityKey(row))) {
          Text(this.qualityLabels.get(this.qualityKey(row)) ?? '')
            .fontSize(11)
            .fontColor(FEED_SINGER_COLOR)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(6)
            .backgroundColor(FEED_CARD_BG)
        }

        // 三个动作：收藏 / 更多 / 播放（参考图右侧那一组）
        Row({ space: 28 }) {
          SymbolGlyph(this.isFavorited(row) ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(26)
            .fontColor([this.isFavorited(row) ? FEED_ACCENT : FEED_SINGER_COLOR])
            .onClick((): void => {
              this.toggleFavorite(row);
            })
          // 「更多」= 工程现成的歌曲菜单（播放/下载/加歌单/加收藏/加队列/查看评论）
          SongMoreMenu({
            song: this.toLxSong(row),
            iconSize: 24,
            iconColor: FEED_SINGER_COLOR
          })
          SymbolGlyph(this.isCurrentSong(row) && this.appState.isPlay ?
            $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(26)
            .fontColor([FEED_TITLE_COLOR])
            .onClick((): void => {
              this.onPlayButton(row, index);
            })
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .width(StyleConstants.FULL_WIDTH)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 24, right: 24 })

      // 脚注：数据来源（榜单 / 每日推荐）—— 用户切了平台要能看出内容换没换
      Text(this.feedHint)
        .fontSize(11)
        .fontColor(FEED_SINGER_COLOR)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ bottom: 8 })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // ★ 给壳层悬浮底栏让位：加在**卡片自己**身上（见类头与常量注释）
    .padding({ bottom: this.bottomReserveVp })
    .backgroundColor(FEED_PAGE_BG)
  }

  build() {
    // 页根与 `RecommendPage` / `EchoReviewPage` 逐字同款：HdsNavDestination + MINI 标题栏 +
    // ignoreLayoutSafeArea(TOP, BOTTOM)（页盒从 y=0 起排 ⇒ 内容让位 = 状态栏 + 56）。
    HdsNavDestination() {
      Column() {
        if (this.feedSource.totalCount() > 0) {
          // ★ 竖向 Swiper = "一屏一首、上下滑换歌"：
          //   · `.vertical(true)`（`component/swiper.d.ts:1790`）—— 竖向整页吸附；
          //   · `.indicator(false)`（:1666，`boolean` 档）—— 不要圆点（一屏一首时圆点没意义）；
          //   · `.cachedCount(1, true)`（:1910）—— 前后各缓存一屏，滑动不掉帧；
          //   · `.nestedScroll(SELF_ONLY)`（:2412 / enum :1384）—— 竖向滚动自己消费，
          //     不把壳层那条"上拉打开播放页"的手势搅进来；
          //   · `.onChange((i: number) => …)`（:2132，`Callback<number>` 档）。
          //   ⚠️ 不用 `List` + 吸附：`List` 的吸附接口叫 `scrollSnapAlign(ScrollSnapAlign)`
          //     （`component/list.d.ts:1925`），而工程里见过的 `scrollSnap({…})` 是 **`Scroll`** 的
          //     属性（`component/scroll.d.ts:1875`）—— 照抄到 `List` 上直接编译错。
          Swiper(this.feedController) {
            // `LazyForEach` **直挂** `Swiper`（中间不套容器），key 稳定 ⇒ 复用正确。
            LazyForEach(this.feedSource, (row: RecommendPrivateSongUi) => {
              this.FeedCard(row, this.feedSource.indexOf(row))
            }, (row: RecommendPrivateSongUi): string => this.feedKey(row))
          }
          .vertical(true)
          .indicator(false)
          .cachedCount(1, true)
          .loop(false)
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
      .backgroundColor(FEED_PAGE_BG)
    }
    .hideTitleBar(false)
    .hideBackButton(true)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    // 内容让位靠每张卡片自己算（`FeedCard` 里 coverSizeVp 已经减掉 `targetContentTopVp()`），
    // 所以这里不再额外 padding —— 一屏一首的页，留白加在外层会让"整屏"对不齐。
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor(FEED_PAGE_BG)
  }

  /**
   * 列表项稳定 key。
   *
   * ⚠️ 必须**不含下标**（用下标当 key 会在换平台/重载后让复用错位）；
   *    `source_songId` 是天然唯一键；`coverUrl` 拼在末尾是为了"封面异步补进来之后
   *    这一屏重绘一次"（同 `HeroSongListCard.rowKey` 的口径）。
   * @param row 这一屏的歌。
   * @returns 稳定 key。
   */
  private feedKey(row: RecommendPrivateSongUi): string {
    return 'feed-' + row.source + '_' + row.songId + '-' + row.coverUrl;
  }
}
