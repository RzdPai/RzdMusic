import { qualityDisplayName } from '../util/SourceFallbackUtil';
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

import { AppStorageV2, curves, uiObserver } from '@kit.ArkUI';
import { AVCastPicker } from '@kit.AVSessionKit';
import { appendPlayLog, AppStorageKeys, ArtistRouteParam, BreakpointType, isWidthBreakpointLgOrXl, Logger, MusicStoreService, PlaybackPreferenceService, PlaybackIntentState, PlayedSongRecord, PlaylistDto, PlayerExpandState, RouterUrlConstants, SongItem, StyleConstants, ThemeState } from 'musicbasic';
import { PlayerConstants } from '../constant/PlayerConstants';
import { MusicPlayMode } from '../model/MusicData';
import { PlayerDataUtil } from '../util/PlayerDataUtil';
import { PlayerViewModel } from '../viewmodel/PlayerViewModel';
import { DownloadUtil } from '../util/DownloadUtil';
import { LXSearchSong } from '../source/LXMusicSDK';
import { LXQualityOption, lxGetQualityOptions } from '../source/LXQualityApi';
import { buildSongShareText, showSystemShare } from '../util/ShareUtil';
import { sourceToCode } from '../geuz/index';
import { QueuePlaylistSheet } from './QueuePlaylistSheet';
import { OtherVersionsSheet } from './OtherVersionsSheet';
import { CommentPanel } from 'comment';
import type { CommentSongRef } from 'comment';

/**
 * 半模态「重新打开」的冷却时间（ms）。
 *
 * 弹层关闭是带动画的（约 300ms），动画没走完就把 isShow 置回 true，
 * 框架会把它当成同一次关闭处理 —— 表现是「刚弹出来立刻又收回去」。
 * 取略大于动画时长，用户几乎感知不到（只有「刚关完马上再点」才会等这几十毫秒）。
 */
const SHEET_REOPEN_GUARD_MS: number = 360;

/** Full-screen transport: progress, main controls, and auxiliary icon row inside a single bottom panel. */
@ComponentV2
export struct ControlAreaComponent {
  /** 本组件的日志 tag（`hdc shell hilog | grep RzdControlArea`）。 */
  private static readonly logTag: string = 'RzdControlArea';
  /** Navigation stack from shell for opening playlist / song list routes. */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Window breakpoint for responsive control sizing. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** View model for seek and transport delegation. */
  @Local playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** Mirrors MediaService play mode for SymbolGlyph (order / single cycle / shuffle). */
  @Local playMode: MusicPlayMode = MusicPlayMode.ORDER;
  /** When false, hides the bottom “other actions�?placeholder row (e.g. album-gradient full-screen layout). */
  @Param showBottomOtherRow: boolean = true;
  /**
   * 时间行中间是否画「平台 / 音质」两枚徽标。
   *
   * ★★ 2026-10-15（照搬无界）：默认 **false** —— 无界 `scrubber` 的时间行只有
   *   `[当前] Blank [总时长]`（`PlayerPage完整UI定稿.md` §8.2），音质在**菜单 sheet** 里选。
   *   派音菜单里也有音质子列表 ⇒ 这里关掉不会丢功能。
   *   ⚠️ 要恢复成派音原来的样子：改成 `true`。
   */
  private static readonly SHOW_SCRUBBER_BADGES: boolean = false;

  // RzdScrubberV19: scale only the decorative rail; keep native input/block geometry fixed.
  @Local scrubberPressed: boolean = false;
  @Local scrubberPreviewValue: number = 0;

  private setScrubberPressed(pressed: boolean): void {
    if (this.scrubberPressed === pressed) {
      return;
    }
    if (pressed) {
      this.scrubberPreviewValue = this.playerViewModel.appState.progress;
    }
    const scaleY: number = pressed ? 24 / 14 : 1;
    appendPlayLog(`[RzdScrubberV19] pressed=${pressed} scaleY=${scaleY.toFixed(4)} idleVp=14 pressedVp=24`);
    this.getUIContext().animateTo({ curve: curves.springMotion(0.4, 0.8) }, (): void => {
      this.scrubberPressed = pressed;
    });
  }

  // ─────────── 控制区动效（由播放页驱动，对标无界音乐 PlayerChrome + BarCollapse）───────────

  /**
   * 控制区竖直偏移（vp）：自动收起时整体向下移出。
   *
   * 默认 0 = 不偏移，所以其它使用点（面板布局、平板分栏）行为完全不变。
   */
  @Param chromeOffsetY: number = 0;
  /** 控制区透明度：自动收起时淡出；默认 1。 */
  @Param chromeOpacity: number = 1;
  /** 控制区按钮间距（vp）：由宿主按窗口档位给（手机 18 / 折叠 24 / 平板 30）；0 = 用组件默认值。 */
  // ⚠️ 2026-10-15：`@Param chromeGap` **已删除** —— 它自始至终**只有声明、没有使用**
  //   （grep 全组件只有声明那一处），是条**死管道**；而 `PlaybackPage` 一直在往里传
  //   `expandState.chromeGapVp()`（那组 18/24/30 **不是无界的值**）⇒ 两边一起删。
  //   控制区真正的间距要从无界档位表的 `gapSwiper` / `gapScrub` 来，
  //   但那要先按三段结构重排（见 `RzdMusic待确认清单.md` D4）。
  // ⚠️ 2026-10-15 已**删除** `progressRiseVp` 参数：用户定调「进度条和下面的那堆按钮**一起**飞入」，
  //    它们是一组，整片控制区的位移由宿主挂在**外层**（`PlaybackPage` 的 `.translate({y: contentRiseVp()})`），
  //    组件内部不再做任何错峰。以后要再拆组，先问清楚顺序。
  /**
   * Controls the song menu bottom sheet (quality / singer / album / share).
   *
   * ★★ 2026-10-15（照搬无界）：从 `@Local` 提升成 **`@Param` + `@Event`**。
   *   无界的菜单入口是 `metaRow` 右侧的第二个 `SymbolGlyph`（「更多」），
   *   而 `metaRow` 画在 `PlaybackPage` 的那一覆盖层里 ⇒ **状态必须由宿主持有**，
   *   本组件只负责画 sheet。宿主把 `showMenuSheet` 传进来、并在 `onMenuSheetChange` 里改它。
   *   （无界 `PlayerPage完整UI定稿.md` §6.2：`SymbolGlyph 收藏` + `SymbolGlyph 更多`。）
   */
  @Param showMenuSheet: boolean | undefined = undefined;
  /** 宿主侧改变菜单开关（子组件不再自己写状态）。 */
  @Event onMenuSheetChange: (open: boolean) => void = (_open: boolean): void => {};
  /**
   * ★★★ 2026-10-17（照搬无界 `PlayerPage.hideChrome()` 的"**面板开着就不收**"守卫）：
   * 本组件里那两个**不属于菜单 sheet** 的弹层（播放队列 / 其他版本）状态变化时，向上报一个布尔。
   *
   * ## 无界那一条守卫的原文（`_recover/logic-src/PlayerPage.abc.txt:4124-4225`）
   * ```ts
   *   hideChrome() {
   *     if (chromeHidden) return;
   *     if (queueOpen || settingsOpen || addplaylistOpen || lyricmatchOpen || qualityOpen ||
   *         lyricsetOpen || sleepOpen || customSleepOpen || lyricoffsetOpen || versionOpen) return;
   *     getUIContext().animateTo({ duration: CHROME_ANIM_MS, curve: Curve.EaseInOut },
   *                              () => { chromeHidden = true; });
   *   }
   * ```
   * ⇒ **任何面板开着就不收控制区**（10 个 flag 的短路或链）。
   *
   * ## 本仓怎么映射（**不是**逐 flag 对齐，而是"按可达性 + 不漏形状"）
   * | 无界的 flag | 本仓 | 谁能看见 |
   * | --- | --- | --- |
   * | `settingsOpen` / `qualityOpen` / `lyricsetOpen` / `sleepOpen` / `addplaylistOpen` / `lyricmatchOpen` / `customSleepOpen` / `lyricoffsetOpen` | 都落在那**一个** `bindSheet` 菜单里（`menuSheetOpen()`；`showMenuQuality` / `showMenuPlaylist` / `showMenuComment` 是它的子面板） | 宿主已通过 `showMenuSheet` / `onMenuSheetChange` 看得见 ✓ |
   * | `queueOpen`（播放队列弹层） | `showPlaylistSheet` | 宿主**看不见** ⇒ 本回调补上 |
   * | `versionOpen`（其他版本） | `showOtherVersionsSheet` | 同上 |
   * ⇒ 加了本回调之后，宿主能看见"**任何**面板是否开着"，语义与无界那条守卫一致。
   *
   * ⚠️ 一个组件只能挂一个 `bindSheet`，所以本组件里不会再有第三个弹层；
   *   若将来新增，**必须**并进下面那个 `@Monitor` 的表达式（否则又是一处"漏改"）。
   * @param open true = 有弹层开着 ⇒ 宿主**不许**收控制区
   */
  @Event onAuxSheetOpenChange: (open: boolean) => void = (_open: boolean): void => {};

  /** 那两个弹层任一开关变化 ⇒ 上报（见 {@link onAuxSheetOpenChange}）。 */
  @Monitor('showPlaylistSheet', 'showOtherVersionsSheet')
  onAuxSheetsChanged(): void {
    this.onAuxSheetOpenChange(this.showPlaylistSheet || this.showOtherVersionsSheet);
  }
  /**
   * 组件**自己那份**菜单开关 —— 仅当宿主**没有**接管时使用。
   *
   * ⚠️⚠️ 2026-10-15（补漏，必须读）：本组件的调用点一共 **5 处**，其中 **4 处并没有传
   *   `showMenuSheet` / `onMenuSheetChange`**（`MusicPlayInfoBlock` 3 处 + `LyricsComponent` 1 处）。
   *   如果这里只留 `@Param` + 默认空回调，那 4 处的「歌曲菜单」会**永远打不开**
   *   （内部那句 `= true` 已经改成回调，回调是空的）——
   *   这就是"把 `@Local` 提升成 `@Param` 时配套没跟上"的典型形状。
   *   所以：`@Param` 的默认值取 **`undefined`**（而不是 `false`）用来区分"宿主没传"，
   *   没传就退回组件内部状态 ⇒ **5 个调用点行为全部正确**。
   */
  @Local menuSheetLocal: boolean = false;

  /** @returns 菜单当前是否展开（宿主接管则读宿主的值，否则读组件自己的）。 */
  private menuSheetOpen(): boolean {
    return this.showMenuSheet !== undefined ? this.showMenuSheet : this.menuSheetLocal;
  }

  /** 请求改变菜单开关（投给宿主；宿主没接管就自己改）。 */
  private requestMenuSheet(open: boolean): void {
    if (this.showMenuSheet !== undefined) {
      this.onMenuSheetChange(open);
    } else {
      this.menuSheetLocal = open;
    }
  }
  /** When true, shows the current play queue as a bottom sheet. */
  @Local showPlaylistSheet: boolean = false;
  @Local showOtherVersionsSheet: boolean = false;
  @Local otherVersionsKeyword: string = '';
  private otherVersionsOpenGeneration: number = 0;
  /** When true the menu sheet shows the quality sub-list instead of the main menu. */
  @Local showMenuQuality: boolean = false;
  /** Quality sub-list mode: 'download' picks a quality to download, 'switch' sets playback quality. */
  @Local menuQualityMode: string = 'switch';
  @Local currentNetworkWifi: boolean = false;
  private networkLookupGeneration: number = 0;

  @Computed
  get currentNetworkQuality(): string {
    return this.store.getNetworkPlayQuality(this.currentNetworkWifi);
  }
  /** 添加到歌单选择器显示状态。 */
  @Local showMenuPlaylist: boolean = false;
  /**
   * 歌曲菜单里的「查看评论」子页。
   *
   * 一个组件只能挂一个 bindSheet（菜单弹层已经占用了），所以评论和「切换音质」
   * 「添加到歌单」一样是**同一个弹层里的一个子页**，靠这个标志切换。
   */
  @Local showMenuComment: boolean = false;
  /**
   * 共享播放意图（`AppStorageV2`）。
   *
   * ★★★ 2026-10-18（用户：右上角分享→歌曲菜单 / 收藏旁歌曲菜单→评论）：
   *   两个新入口的**按钮**分别住在 `TopAreaComponent`（右上角）和播放页 meta 行，
   *   而弹层只有本组件能挂（一个组件只能挂一个 `bindSheet`）。
   *   它们与本组件之间没有父子参数链（本组件被挂 4 处以上），所以统一走这条既有共享状态：
   *   点方 bump 序号（`menuRequestSeq` / `commentRequestSeq`），这里 `@Monitor` 响应。
   */
  @Local intent: PlaybackIntentState = AppStorageV2.connect(PlaybackIntentState,
    AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!;

  /**
   * 宿主请求「打开歌曲菜单」（右上角那颗按钮）。
   *
   * ⚠️ 只认**外部持有弹层状态的那个实例**（`showMenuSheet !== undefined`，即播放页直挂的那一份）：
   *   本组件在 `MusicPlayInfoBlock` / `LyricsComponent` 里还有几份自带 `bindSheet` 的实例，
   *   不设这道闸，一次点击会同时弹出多个同样的弹层。
   */
  @Monitor('intent.menuRequestSeq')
  onHostMenuRequest(): void {
    if (this.intent.menuRequestSeq <= 0 || this.showMenuSheet === undefined) {
      return;
    }
    Logger.info(ControlAreaComponent.logTag, `host request song menu seq=${this.intent.menuRequestSeq}`);
    this.openMenuSheet();
  }

  /**
   * 宿主请求「打开评论」（播放页 meta 行那颗新评论按钮）。闸门同 {@link onHostMenuRequest}。
   */
  @Monitor('intent.commentRequestSeq')
  onHostCommentRequest(): void {
    if (this.intent.commentRequestSeq <= 0 || this.showMenuSheet === undefined) {
      return;
    }
    Logger.info(ControlAreaComponent.logTag,
      `host request comment seq=${this.intent.commentRequestSeq}`);
    this.openCommentSheet();
  }

  /** 上一次弹层关闭动画结束的时间戳（见 {@link openSheetFor} 的冷却逻辑）。 */
  private sheetClosedAtMs: number = 0;
  /** 选择器中的歌单列表。 */
  @Local playlistOptions: PlaylistDto[] = [];
  /** 新建歌单名称输入。 */
  @Local newPlaylistName: string = '';
  /** 本地歌单存储（添加到歌单复用 MusicStoreService 现成接口）。 */
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  /** App accent color for menu highlights. */
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /**
   * 形变状态（用来取**控制区档位尺寸**）。
   *
   * ★ 2026-10-15：本文件原来**没有**它 —— 控制区的所有尺寸都是**写死的字面量**
   *   （`isWidthBreakpointLgOrXl(bp) ? 26 : 24` 这类），而无界是**按档位表取值**
   *   （`chrome().sideSize` / `favSize` / `playSize` …，见 `RzdMusic记忆.md` §56.26）。
   *   这里按本文件**既有的套路**（`themeState` / `intent` 都是 `AppStorageV2.connect`）接进来，
   *   就不再需要从宿主传 `@Param`（那要改 5 个调用点 —— "同一形状 N 处"的老毛病）。
   */
  private expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;

  /**
   * 打开菜单弹层里的某个子页前，先把**其它**子页标志清掉。
   *
   * ⚠️ 这是踩过的 bug：只置位、不清位时，`MenuSheet()` 里排在最前面的
   *    `showMenuComment` 还是 true —— 于是「打开过一次评论之后，再点下载按钮
   *    弹出来的还是评论」。所有子页入口都必须先过这里。
   */
  private resetMenuSubPages(): void {
    this.showMenuComment = false;
    this.showMenuPlaylist = false;
    this.showMenuQuality = false;
    this.menuQualityMode = 'switch';
  }

  /**
   * 打开菜单弹层并切到指定子页（'menu' / 'quality' / 'qualityDownload' / 'playlist' / 'comment'）。
   *
   * ⚠️ 不能在关闭动画还没走完时把 isShow 置回 true：框架内部还在收，
   *    表现就是「弹层刚弹出来立刻又收回去」。用户实际踩到过：
   *    评论 → 关闭 → 下载 → 关闭 → 评论，第三次会闪一下就没。
   *    所以这里用 `onDisappear` 记下的时间戳做一次冷却（关着的时候点，几乎无感；
   *    刚关完就点，就多等那几十毫秒把关闭动画让过去）。
   */
  private openSheetFor(page: string): void {
    void this.refreshNetworkQuality();
    this.resetMenuSubPages();
    if (page === 'quality') {
      this.showMenuQuality = true;
    } else if (page === 'qualityDownload') {
      this.menuQualityMode = 'download';
      this.showMenuQuality = true;
    } else if (page === 'playlist') {
      this.playlistOptions = this.store.getPlaylists();
      this.newPlaylistName = '';
      this.showMenuPlaylist = true;
    } else if (page === 'comment') {
      this.showMenuComment = true;
    }
    if (this.menuSheetOpen()) {
      return;   // 已经开着：只切子页
    }
    const since: number = Date.now() - this.sheetClosedAtMs;
    if (since >= SHEET_REOPEN_GUARD_MS) {
      this.requestMenuSheet(true);
      return;
    }
    setTimeout((): void => {
      this.requestMenuSheet(true);
    }, SHEET_REOPEN_GUARD_MS - since);
  }

  /** Opens the song menu main list. */
  private openMenuSheet(): void {
    this.openSheetFor('menu');
  }

  /** Opens the quality sub-list in download mode. */
  private downloadSongSnapshot: LXSearchSong | undefined = undefined;
  private downloadProbeGeneration: number = 0;
  @Local downloadQualityOptions: LXQualityOption[] = [];

  private async openDownloadQuality(): Promise<void> {
    const current: SongItem | undefined = this.currentSong();
    if (current === undefined || current.source.length === 0 || current.source === 'local') {
      return;
    }
    const song: LXSearchSong = {
      source: current.source, songId: current.songId,
      name: typeof current.title === 'string' ? current.title : '',
      singer: typeof current.singer === 'string' ? current.singer : '',
      albumName: current.albumName, albumId: current.albumId, interval: current.interval, img: current.cover,
      types: []
    };
    this.downloadSongSnapshot = song;
    const generation: number = ++this.downloadProbeGeneration;
    if (this.store.getDownloadQualityMode() === 'follow') {
      console.info('[RzdDownloadQuality] mode=follow direct entry=control');
      this.closeMenuSheet();
      await DownloadUtil.downloadSong(song.source, song.songId, song.name, song.singer, '',
        this.getUIContext(), song.img, song.albumName);
      return;
    }
    console.info('[RzdDownloadQuality] mode=manual picker-open entry=control');
    this.downloadQualityOptions = [];
    this.openSheetFor('qualityDownload');
    try {
      const options: LXQualityOption[] = await lxGetQualityOptions(song);
      if (generation !== this.downloadProbeGeneration || !this.showMenuQuality ||
        this.menuQualityMode !== 'download') {
        return;
      }
      this.downloadQualityOptions = options;
    } catch (_e) {
      if (generation === this.downloadProbeGeneration) {
        this.downloadQualityOptions = [];
      }
    }
  }

  private downloadPickedQuality(q: string): void {
    const song: LXSearchSong | undefined = this.downloadSongSnapshot;
    if (song === undefined || !this.showMenuQuality || q.length === 0) {
      return;
    }
    this.closeMenuSheet();
    void DownloadUtil.downloadSong(song.source, song.songId, song.name, song.singer, q,
      this.getUIContext(), song.img, song.albumName);
  }

  private menuQualityChoices(): string[] {
    return this.menuQualityMode === 'download' ?
      this.downloadQualityOptions.map((option: LXQualityOption): string => option.type) :
      ['128k', '320k', 'flac', 'flac24bit', 'hires', 'atmos', 'atmos_plus', 'master'];
  }

  /** 打开评论子页（播放页底部那颗「评论」按钮用它）。 */
  private openCommentSheet(): void {
    this.openSheetFor('comment');
  }

  /** 打开添加到歌单选择器。 */
  private openPlaylistPicker(): void {
    this.openSheetFor('playlist');
  }

  /** 当前歌曲加入指定歌单。 */
  private addToPlaylist(p: PlaylistDto): void {
    const song = this.currentSong();
    if (song === undefined) {
      return;
    }
    const record = new PlayedSongRecord();
    record.songId = song.songId;
    record.name = typeof song.title === 'string' ? song.title : '';
    record.singer = typeof song.singer === 'string' ? song.singer : '';
    record.source = song.source;
    record.img = song.cover;
    record.time = Date.now();
    const added: boolean = this.store.addSongToPlaylist(p.id, record);
    this.getUIContext().getPromptAction().showToast({
      message: added ? '已添加到「' + p.name + '」' : '歌单中已有该歌曲',
      duration: 2000
    });
    this.showMenuPlaylist = false;
  }

  /** 新建歌单并加入当前歌曲。 */
  private createPlaylistWithSong(): void {
    const name: string = this.newPlaylistName.trim();
    if (name.length === 0) {
      return;
    }
    const p = this.store.createPlaylist(name);
    this.addToPlaylist(p);
  }

  private closeMenuSheet(): void {
    this.showMenuPlaylist = false;
    this.requestMenuSheet(false);
    this.showMenuQuality = false;
    this.showMenuComment = false;
  }

  /**
   * 当前歌的平台身份（评论面板用）。
   *
   * 在线歌直接把 source + songId 交给评论面板；本地音乐（source = 'local'）交给
   * 面板内部的解析器去查匹配记录（解析器由产品壳层注册，见 `features/comment`）。
   */
  private currentSongRef(): CommentSongRef {
    const song = this.currentSong();
    const ref: CommentSongRef = {
      source: song !== undefined && typeof song.source === 'string' ? song.source : '',
      songId: song !== undefined ? song.songId : '',
      name: song !== undefined && typeof song.title === 'string' ? song.title : '',
      singer: song !== undefined && typeof song.singer === 'string' ? song.singer : ''
    };
    return ref;
  }

  /** 评论面板的换歌标识：值变了面板会重新拉评论。 */
  private currentSongKey(): string {
    const ref: CommentSongRef = this.currentSongRef();
    return ref.source + '_' + ref.songId;
  }

  /** Current song for menu info rows (singer / album). */
  private currentSong(): SongItem | undefined {
    return this.playerViewModel.appState.getCurrentSongItem();
  }

  /**
   * 音质徽标文案。
   *
   * ⚠️ 本地歌必须**按歌曲本身**判断，不能只看 `appState.currentQuality`：
   *    那个字段是播放时写的，重启后恢复上次播放的本地歌、或从歌单/队列播本地歌时
   *    以前可能还是空的，于是徽标掉到 '128k' 兜底 —— 用户看到的就是
   *    「本地歌的音质重启后变成 128K」。
   */
  private currentQualityLabel(): string {
    const song = this.currentSong();
    if (song !== undefined && (song.source === 'local' || song.quality === 'local')) {
      return '本地';
    }
    let q: string = this.playerViewModel.appState.currentQuality;
    if (q.length === 0 && song !== undefined && song.quality.length > 0) {
      q = song.quality;
    }
    if (q.length === 0) {
      q = '128k';
    }
    return qualityDisplayName(q);
  }

  /** File size text of the current song for the given quality; empty when unknown. */
  private currentPlatformLabel(): string {
    const song = this.currentSong();
    if (song === undefined) {
      return '';
    }
    const src: string = typeof song.source === 'string' ? song.source : '';
    if (src.length === 0 || src === 'local') {
      return src === 'local' ? '本地' : '';
    }
    const map: Record<string, string> = {
      'tx': 'QQ', 'wy': '网易', 'kg': '酷狗', 'kw': '酷我', 'mg': '咪咕'
    };
    const name: string | undefined = map[src];
    return name !== undefined ? name : src;
  }


  private currentQualitySize(quality: string): string {
    if (this.menuQualityMode === 'download') {
      const option: LXQualityOption | undefined = this.downloadQualityOptions.find(
        (item: LXQualityOption): boolean => item.type === quality);
      return option !== undefined && option.size > 0 ? (option.size / 1048576).toFixed(1) + 'MB' : '';
    }
    const song = this.currentSong();
    if (song === undefined) {
      return '';
    }
    const list = song.qualityList;
    for (let i = 0; i < list.length; i++) {
      if (list[i].type === quality) {
        const n: number = Number(list[i].size) || 0;
        if (n > 0) {
          return (n / (1024 * 1024)).toFixed(1) + 'MB';
        }
        return '';
      }
    }
    return '';
  }

  /** Opens the system share panel with the current song info and its link. */
  private shareCurrentSong(): void {
    const song = this.currentSong();
    const title: string = song !== undefined && typeof song.title === 'string' ? song.title : '未知歌曲';
    const singer: string = song !== undefined && typeof song.singer === 'string' ? song.singer : '未知歌手';
    const source: string = song !== undefined ? song.source : '';
    const songId: string = song !== undefined ? song.songId : '';
    showSystemShare(this.getUIContext(), buildSongShareText(title, singer, source, songId), '歌曲分享');
  }

  /** Current song singer text for the menu info rows. */
  private currentSinger(): string {
    const song = this.currentSong();
    return song !== undefined && typeof song.singer === 'string' ? song.singer : '未知歌手';
  }

  /** Current song album text for the menu info rows. */
  private currentAlbum(): string {
    const song = this.currentSong();
    if (song !== undefined && song.albumName.length > 0) {
      return song.albumName;
    }
    return '未知专辑';
  }

  /** Opens the artist detail page with the current singer name and song source. */
  private searchCurrentSinger(): void {
    const singer: string = this.currentSinger();
    if (singer.length > 0 && singer !== '未知歌手') {
      const song = this.currentSong();
      const param = new ArtistRouteParam();
      param.source = sourceToCode(song !== undefined && typeof song.source === 'string' ? song.source : '');
      param.name = singer;
      this.playerViewModel.appState.isShowPlay = false;
      this.pageIndexInfos.pushPathByName(RouterUrlConstants.ARTIST_DETAIL, param);
    }
  }

  /** Opens the online search page with the current album name. */
  private searchCurrentAlbum(): void {
    const song = this.currentSong();
    const album: string = song !== undefined ? song.albumName : '';
    if (album.length > 0) {
      this.playerViewModel.appState.isShowPlay = false;
      this.pageIndexInfos.pushPathByName(RouterUrlConstants.ONLINE_SEARCH, album);
    }
  }

  private searchOtherVersions(): void {
    const song: SongItem | undefined = this.currentSong();
    const title: string = song !== undefined && typeof song.title === 'string' ? song.title.trim() : '';
    if (song === undefined || title.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '暂无可搜索的歌曲' });
      return;
    }
    const singer: string = this.currentSinger().trim();
    this.otherVersionsKeyword = title +
      (singer.length > 0 && singer !== '未知歌手' ? ' ' + singer : '');
    const index: number = this.playerViewModel.appState.selectIndex;
    const key: string = JSON.stringify([song.source, song.songId, song.id, song.src]);
    const queue: SongItem[] = this.playerViewModel.appState.playQueue;
    const ids: number[] = this.playerViewModel.appState.playQueueIds;
    const intent: PlaybackIntentState = AppStorageV2.connect(PlaybackIntentState,
      AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!;
    const version: number = intent.requestVersion;
    const gen: number = ++this.otherVersionsOpenGeneration;
    this.closeMenuSheet();
    // Let the menu closing animation finish before presenting the independent sheet.
    setTimeout((): void => {
      const current: SongItem | undefined = this.currentSong();
      const currentKey: string = current === undefined ? '' :
        JSON.stringify([current.source, current.songId, current.id, current.src]);
      if (gen !== this.otherVersionsOpenGeneration || intent.requestVersion !== version ||
        queue !== this.playerViewModel.appState.playQueue || ids !== this.playerViewModel.appState.playQueueIds ||
        index !== this.playerViewModel.appState.selectIndex || key !== currentKey ||
        (index < queue.length && current !== song)) {
        console.info('[RzdOtherVersionSearch] discard delayed open gen=' + gen);
        return;
      }
      this.showOtherVersionsSheet = true;
      console.info('[RzdOtherVersionSearch] open sheet keywordLength=' + this.otherVersionsKeyword.length);
    }, SHEET_REOPEN_GUARD_MS);
  }

  aboutToDisappear(): void {
    this.otherVersionsOpenGeneration++;
    this.showOtherVersionsSheet = false;
  }

  private async refreshNetworkQuality(): Promise<void> {
    const generation: number = ++this.networkLookupGeneration;
    const wifi: boolean = await PlaybackPreferenceService.resolveCurrentNetworkWifi();
    if (generation === this.networkLookupGeneration) {
      this.currentNetworkWifi = wifi;
    }
  }

  aboutToAppear(): void {
    void this.refreshNetworkQuality();
  }

  /** Explicit quality updates only the current network, then re-resolves via the shell intent. */
  private async setPlayQuality(q: string): Promise<void> {
    const appState = this.playerViewModel.appState;
    const index: number = appState.selectIndex;
    const song: SongItem | undefined = appState.getCurrentSongItem();
    this.showMenuQuality = false;
    this.requestMenuSheet(false);
    const generation: number = ++this.networkLookupGeneration;
    const wifi: boolean = await PlaybackPreferenceService.resolveCurrentNetworkWifi();
    this.store.setNetworkPlayQuality(wifi, q);
    if (generation === this.networkLookupGeneration) {
      this.currentNetworkWifi = wifi;
    }
    console.info('[RzdQualityPolicy] explicit tier=' + q + ' queueIndex=' + index);
    // Do not reload a different song if the user switched tracks while network lookup was pending.
    if (song !== undefined && song.source.length > 0 && song.source !== 'local' &&
      appState.selectIndex === index && appState.getCurrentSongItem() === song) {
      song.url = '';
      const intent: PlaybackIntentState = AppStorageV2.connect(PlaybackIntentState,
        AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!;
      intent.pendingPlaySongId = -1;
      intent.pendingQueueIndex = index;
      intent.openPlayerUi = false;
      intent.requestVersion++;
      console.info('[RzdQualityPolicy] explicit re-resolve requested tier=' + q);
    }
    this.getUIContext().getPromptAction().showToast({ message: '已选择当前网络音质 ' + qualityDisplayName(q), duration: 2000 });
  }

  /** sys.symbol.repeat | repeat_1 | shuffle per MusicPlayMode. */
  private playModeSymbol(): Resource {
    switch (this.playMode) {
      case MusicPlayMode.ORDER:
        return $r('sys.symbol.repeat');
      case MusicPlayMode.SINGLE_CYCLE:
        return $r('sys.symbol.repeat_1');
      case MusicPlayMode.RANDOM:
        return $r('sys.symbol.shuffle');
      default:
        return $r('sys.symbol.repeat');
    }
  }

  @Builder
  private bottomOtherGlyph(symbol: Resource, label: string, action: () => void = (): void => {}) {
    SymbolGlyph(symbol)
      .fontSize(22)
      .fontWeight(FontWeight.Regular)
      .fontColor([$r('app.color.play_text_color')])
      .accessibilityText(label)
      .accessibilityLevel('yes')
      .onClick(() => {
        action();
      })
  }

  /**
   * 自定义投播图标。
   *
   * 尺寸/字重/颜色**必须**与 {@link bottomOtherGlyph} 完全一致，否则这一排里
   * 投播会明显比另外三个大一圈（用户反馈的就是这个）。
   * 这里和旁边三个一样只给 fontSize，不额外加 padding、也不包容器。
   */
  @Builder
  private castPickerIcon() {
    SymbolGlyph($r('sys.symbol.shareplay'))
      .fontSize(22)
      .fontWeight(FontWeight.Regular)
      .fontColor([$r('app.color.play_text_color')])
      .accessibilityText('投播')
      .accessibilityLevel('yes')
  }

  /** Progress, transport, and optional auxiliary icons grouped per playback-page layout spec. */
  @Builder
  bottomPanel() {
    Column() {
      Column() {
        // RzdScrubberV19: identical OutSet rails share one margin box and live preview value.
        Stack({ alignContent: Alignment.Center }) {
          Slider({
            min: 0,
            max: this.playerViewModel.appState.progressMax,
            step: 1,
            value: this.scrubberPressed ? this.scrubberPreviewValue : this.playerViewModel.appState.progress
          })
            .blockColor(Color.Transparent)
            .selectedColor($r('app.color.slider_select'))
            .trackColor($r('app.color.slider_track'))
            .trackThickness(14)
            .blockSize({
              width: $r('app.float.slider_block'),
              height: $r('app.float.slider_block')
            })
            .height(32)
            .scale({ x: 1, y: this.scrubberPressed ? 24 / 14 : 1, centerY: '50%' })
            .hitTestBehavior(HitTestMode.None)
            .focusable(false)
            .accessibilityLevel('no')
          Slider({
            min: 0,
            max: this.playerViewModel.appState.progressMax,
            step: 1,
            value: this.scrubberPressed ? this.scrubberPreviewValue : this.playerViewModel.appState.progress
          })
            .blockColor($r('app.color.slider_block'))
            .selectedColor(Color.Transparent)
            .trackColor(Color.Transparent)
            .trackThickness(14)
            .blockSize({
              width: $r('app.float.slider_block'),
              height: $r('app.float.slider_block')
            })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.setScrubberPressed(true);
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.setScrubberPressed(false);
              }
            })
            .onChange((value: number, mode: SliderChangeMode) => {
              this.scrubberPreviewValue = value;
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Begin ||
                mode === SliderChangeMode.Click) {
                this.playerViewModel.seek(value);
              }
              this.playerViewModel.appState.pageShowTime = 0;
            })
            .height(32)
            .hitTestBehavior(HitTestMode.Block)
        }
          .height(32)
          .clip(false)
          .margin({
            left: new BreakpointType(
              $r('app.float.slider_margin_sm'),
              $r('app.float.slider_margin_md'),
              $r('app.float.slider_margin_lg'),
              $r('app.float.slider_margin_lg')
            ).getValue(this.breakpointEnv.widthBreakpoint),
            right: new BreakpointType(
              $r('app.float.slider_margin_sm'),
              $r('app.float.slider_margin_md'),
              $r('app.float.slider_margin_lg'),
              $r('app.float.slider_margin_lg')
            ).getValue(this.breakpointEnv.widthBreakpoint)
          })
          .hitTestBehavior(HitTestMode.Default)
        Row() {
          Text(this.playerViewModel.appState.currentTime)
            .fontColor($r('app.color.play_text_color'))
            .fontSize($r('app.float.singer_title_sm'))
            .fontFamily(PlayerConstants.FONT_FAMILY_BLACK)
            .lineHeight('14vp')
          Blank()
          // ★★ 2026-10-15（照搬无界）：**时间行中间不再夹音质/平台徽标**。
          //   无界的 `scrubber` 时间行只有 `Row{ Text(当前) , Blank , Text(总时长) }`
          //   （`PlayerPage完整UI定稿.md` §8.2），音质是在**菜单 sheet** 里选的 ——
          //   派音这里也在菜单里显示了（见本文件下方的音质子列表）。
          //   ⚠️ 那三个取值方法（`currentPlatformLabel` / `currentQualityLabel` /
          //      `currentQualitySize`）**都保留**（菜单还在用），只是不在这里画。
          //      要恢复：把 `SHOW_SCRUBBER_BADGES` 改成 `true`。
          if (ControlAreaComponent.SHOW_SCRUBBER_BADGES) {
            Row({ space: 4 }) {
              if (this.currentPlatformLabel().length > 0) {
                Text(this.currentPlatformLabel())
                  .fontSize(11)
                  .fontColor($r('app.color.play_text_color'))
                  .lineHeight(16)
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .borderRadius(10)
                  .backgroundColor('rgba(255, 255, 255, 0.12)')
              }
              Text(this.currentQualityLabel())
                .fontSize(11)
                .fontColor($r('app.color.play_text_color'))
                .lineHeight(16)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .borderRadius(10)
                .backgroundColor('rgba(255, 255, 255, 0.12)')
            }
          }
          Blank()
          Text(this.playerViewModel.appState.totalTime)
            .fontColor($r('app.color.play_text_color'))
            .fontSize($r('app.float.singer_title_sm'))
            .fontFamily(PlayerConstants.FONT_FAMILY_BLACK)
            .lineHeight('14vp')
        }
        .width(StyleConstants.FULL_WIDTH)
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .margin({
        top: this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
          this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD ? 0 : $r('app.float.slider_margin_top'),
        bottom: isWidthBreakpointLgOrXl(this.breakpointEnv.widthBreakpoint) ?
          $r('app.float.slider_margin_bottom_lg') : this.breakpointEnv.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
            this.breakpointEnv.heightBreakpoint === HeightBreakpoint.HEIGHT_MD ? 8 : $r('app.float.slider_margin_bottom')
      })
      // ★★ 2026-10-15：进度条与下面那堆按钮是**一组**（用户定调"一起飞入"），
      //   整片控制区的位移由宿主（`PlaybackPage`）挂在外层，这里**不再**做内部错峰。

      Row() {
        // ★★★ 2026-10-17（用户实测：**关闭/收起动画期间左下「循环」与右下「播放列表」消失**，
        //   活页形变路径与满窗快照路径**都**丢，说明丢在这两个节点的**绘制**上）。
        //   对照无界（`_recover/logic-src/PlayerPage完整UI定稿.md` §8.3，L180503-180573）：
        //   它的传输行 5 颗是 **SymbolGlyph(播放模式) / Image(上一首) / SymbolGlyph(播放·暂停) /
        //   Image(下一首) / SymbolGlyph(播放队列)** —— 这两颗**上游也是 SymbolGlyph**，
        //   所以"换成 Image"不是照搬；上游与本仓的差别只在**尺寸从哪来**：
        //   本仓 `Image` 那两颗有 `.width(chromeSeekSize)`（显式盒子），
        //   而这两颗 `SymbolGlyph` 只有 `fontSize`（盒子 = 符号字形的隐含测量值）。
        //   ⇒ 按"每个图标都给显式尺寸"补盒子 + `flexShrink(0)`，别让 Row 的
        //      `justifyContent(SpaceBetween)` 在形变/快照那一拍把宽度算成 0。
        SymbolGlyph(this.playModeSymbol())
          .fontSize(this.expandState.chromeSideSize())
          .fontWeight(FontWeight.Regular)
          .fontColor([$r('app.color.play_text_color')])
          // ★★★ 2026-10-17（照搬无界 `transport()` 的外框 + 修「关闭时两颗突然下移一点」）：
          //   盒子口径改成**与同排两颗 `Image` 完全一致**的 `chrome().seekSize`（`wujie.pa:181429` / `181639`
          //   的 `Image().width(chrome().seekSize).aspectRatio(1)` ⇒ 本仓 `chromeSeekSize()` = 32/30/28vp），
          //   而**字号仍按上游 `chrome().sideSize`**（`wujie.pa:181333` / `181754` 的
          //   `.fontSize(chrome().sideSize)` ⇒ 22/21/20fp）。
          //   ⚠️ 上一版给的是 `width/height = chromeSideSize()`（22/21/20）—— 与同排 32/30/28 的 `Image`
          //      不是同一个高，形变/快照那一拍整行按最高者排版就把它俩往下推了一点（用户实测"突然下移一点点"）。
          //   ✅ 核对结果：`SymbolGlyphAttribute extends CommonMethod`（SDK `symbolglyph.d.ts:982`）里
          //      **没有 `textAlign`** ⇒ 不能写 `.textAlign(TextAlign.Center)`（编译不过）；
          //      符号在固定方盒内本来就是居中绘制，等大方盒 + 行级 `alignItems(Center)` 即可对齐。
          // ★★★ 2026-10-18（**回退"删盒子"** —— 用户第五/六轮连两次实测「系统返回关闭时这两颗**消失**」）：
          //   上一轮按上游"这两颗只有 fontSize、没有盒子"删了 `.width/.height`，结果**快照里没有字形** ⇒ 一关就消失。
          //   本仓的 `SymbolGlyph` 在 `componentSnapshot` 里必须**有显式方盒**才会被光栅化进截图
          //   （与 `waitUntilRenderFinished` 是同一条历史结论 §178）。⇒ 盒子必须留着。
          //   盒子口径与同排两颗 `Image` 一致（`chrome().seekSize`，`wujie.pa:181429`/`181639`），字号仍按 `sideSize`。
          .width(this.expandState.chromeSeekSize())
          .height(this.expandState.chromeSeekSize())
          .flexShrink(0)
          .accessibilityText('播放模式')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.playMode = PlayerDataUtil.cyclePlayMode();
            this.playerViewModel.appState.pageShowTime = 0;
          })
        Image($r('app.media.ic_public_forward'))
          .controlImageBuilder()
          // ★★★ 2026-10-16（照搬无界 `chrome().seekSize`）：
          //   这两处 `Image` 的属性（`aspectRatio(1)` + `opacity(0.86)` + `objectFit(Contain)`，
          //   见本文件末尾的 `controlImageBuilder()`）**与无界那两处逐字相同**
          //   （`wujie.pa:181429` / `181639`：`Image().width(chrome().seekSize).aspectRatio(1)…`）
          //   ⇒ 对应关系确定：**方形图标按钮的宽度 = 本档的 `seekSize`**（32 / 30 / 28）。
          //   ⚠️ 改前是 `app.float.control_width`(32) / `control_width_lg`(36) —— 写死两档、
          //     不随档位变；FULL 档恰好等于 32 所以看不出问题，中/紧凑档会偏大。
          //   ⚠️ **播放/暂停主按钮不换**：无界那边它用 `playSize`（72/62/52），
          //     而本仓这里是 `image_play_width = 72vp`（FULL 档恰好对上）。
          .width(this.expandState.chromeSeekSize())
          .accessibilityText('上一首')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.playerViewModel.playPrevious();
            this.playerViewModel.appState.pageShowTime = 0;
          })
        Image(this.playerViewModel.appState.isPlay ? $r('app.media.ic_public_play') : $r('app.media.ic_public_pause'))
          .controlImageBuilder()
          .width(new BreakpointType(
            $r('app.float.image_play_width'),
            $r('app.float.image_play_width'),
            $r('app.float.image_play_width_lg'),
            $r('app.float.image_play_width_lg')
          ).getValue(this.breakpointEnv.widthBreakpoint))
          .accessibilityText(this.playerViewModel.appState.isPlay ? '播放' : '暂停')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.playerViewModel.togglePlayPause();
            this.playerViewModel.appState.pageShowTime = 0;
          })
        Image($r('app.media.ic_public_next'))
          .controlImageBuilder()
          // 同上一首：`chrome().seekSize`（无界 `wujie.pa:181639`）
          .width(this.expandState.chromeSeekSize())
          .accessibilityText('下一首')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.playerViewModel.playNext();
            this.playerViewModel.appState.pageShowTime = 0;
          })
        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize(this.expandState.chromeSideSize())
          .fontWeight(FontWeight.Regular)
          .fontColor([$r('app.color.play_text_color')])
          // 同「播放模式」那颗：盒子 = `chrome().seekSize`（与同排 `Image` 同口径），
          // 字号 = `chrome().sideSize`（上游 `wujie.pa:181754`），并 `flexShrink(0)` 不许被压缩
          // （见上方长注释，对照 `PlayerPage完整UI定稿.md` §8.3 L180568-181846 的播放队列 SymbolGlyph）。
          // ★★★ 2026-10-18（**回退"删盒子"**，理由同「播放模式」那颗：快照里 `SymbolGlyph` 必须有显式方盒）
          .width(this.expandState.chromeSeekSize())
          .height(this.expandState.chromeSeekSize())
          .flexShrink(0)
          .accessibilityText('播放列表')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.showPlaylistSheet = true;
            this.playerViewModel.appState.pageShowTime = 0;
          })
      }
      .width(StyleConstants.FULL_WIDTH)
      .justifyContent(FlexAlign.SpaceBetween)
      // ★★★ 2026-10-17（照搬无界 `PlayerPage.transport()` 的行属性，`wujie.pa:180503-180573`
      //   的 λ `@10*#`：`Row.width('100%').justifyContent(SpaceBetween)
      //   .alignItems(VerticalAlign.Center).padding({left/right}).translate().opacity().transition()`）：
      //   上游这一行**明确写了 `.alignItems(VerticalAlign.Center)`**，本仓原来漏了这一条 ——
      //   五颗里两颗 `SymbolGlyph`（有方盒）与三颗 `Image`（`aspectRatio(1)`）在形变期间高度不一致时，
      //   Row 默认按顶对齐 ⇒ 整行看起来往下挪一点。补上就按竖直中心对齐。
      .alignItems(VerticalAlign.Center)

      if (this.showBottomOtherRow) {
        Row({ space: 0 }) {
          // 投播：AVCastPicker 会自己画一个容器，不给尺寸时它比旁边 22vp 的 SymbolGlyph
          // 大一圈。这里把宽高钉成 24（图标 22 + 各 1vp 余量），并让 customPicker
          // 只负责画图标本体，这样四个按钮的视觉大小才一致。
          AVCastPicker({
            normalColor: '#99FFFFFF',
            activeColor: '#99FFFFFF',
            customPicker: (): void => {
              this.castPickerIcon()
            }
          })
            .width(24)
            .height(24)
          // 这一排现在是「投播 / 下载 / 评论 / 更多」四个真入口。
          // 原来第二颗铃铛（通知）是没接功能的占位，用户要求把它换掉：铃铛去掉，
          // 下载左移一位，空出来的位置放「评论」——比藏在「更多」里少点两下。
          this.bottomOtherGlyph($r('sys.symbol.arrow_down_circle'), '下载', (): void => {
            this.openDownloadQuality();
          })
          this.bottomOtherGlyph($r('sys.symbol.text_bubble_left_2'), '评论', (): void => {
            this.openCommentSheet();
          })
          this.bottomOtherGlyph($r('sys.symbol.dot_grid_1x2_circle'), '更多', (): void => {
            this.openMenuSheet();
          })
        }
        .width(StyleConstants.FULL_WIDTH)
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({
          top: 32
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .borderRadius(16)
    .padding({
      top: 8,
      left: 4,
      right: 4
    })
  }

  /** Song menu sheet: main menu (quality / singer / album / share) and quality sub-list. */
  @Builder
  private MenuSheet() {
    Column({ space: 4 }) {
      if (this.showMenuComment) {
        // 评论子页：面板根节点是 height('100%')，所以外面这层容器也必须是**确定高度**
        // （弹层内容区的高度就是弹层高度，用 height('100%') 才对；用 layoutWeight
        //  在这里会拿到 0 —— 弹层内容根节点是按内容包高度的，不是弹性容器）。
        Column() {
          CommentPanel({
            song: this.currentSongRef(),
            songKey: this.currentSongKey(),
            showHeader: true,
            onClose: (): void => {
              // 评论已经是底部工具行的一级入口，返回箭头直接收起弹层
              this.closeMenuSheet();
            }
          })
        }
        .width('100%')
        .height('100%')
      } else if (this.showMenuPlaylist) {
        this.PlaylistPickerRows()
      } else if (this.showMenuQuality) {
        Text(this.menuQualityMode === 'download' ? '选择下载音质' : '切换音质')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .margin({ top: 8, bottom: 12 })

        ForEach(this.menuQualityChoices(), (q: string) => {
          Row() {
            Text(qualityDisplayName(q))
              .fontSize(16)
              .fontColor($r('app.color.font_primary'))
            Blank()
            if (this.menuQualityMode === 'download' && this.currentQualitySize(q).length > 0) {
              Text(this.currentQualitySize(q))
                .fontSize(13)
                .fontColor($r('app.color.font_tertiary'))
                .margin({ right: 10 })
            }
            if (this.currentNetworkQuality === q) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(18)
                .fontColor([this.themeState.color])
            }
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .borderRadius(10)
          .backgroundColor($r('app.color.background_secondary'))
          .onClick(() => {
            if (this.menuQualityMode === 'download') {
              this.downloadPickedQuality(q);
            } else {
              this.setPlayQuality(q);
            }
          })
        }, (q: string) => 'menuq-' + q)

        if (this.menuQualityMode === 'switch') {
          Row() {
            Text('返回')
              .fontSize(15)
              .fontColor($r('app.color.font_tertiary'))
          }
          .width('100%')
          .height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showMenuQuality = false;
          })
        }
      } else {
        Text('歌曲菜单')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .margin({ top: 8, bottom: 12 })

        this.MenuRow(this.currentSinger(), $r('sys.symbol.person_crop_circle_fill_1'), (): void => {
          this.closeMenuSheet();
          this.searchCurrentSinger();
        })
        this.MenuRow(this.currentAlbum(), $r('sys.symbol.music_note_list'), (): void => {
          this.closeMenuSheet();
          this.searchCurrentAlbum();
        })
        this.MenuRow('搜索其它版本', $r('sys.symbol.magnifyingglass'), (): void => {
          this.searchOtherVersions();
        })
        this.MenuRow('添加到歌单', $r('sys.symbol.plus'), (): void => {
          this.openPlaylistPicker();
        })
        this.MenuRow($r('app.string.player_menu_quality'), $r('sys.symbol.gearshape_fill'),
          (): void => {
            this.openSheetFor('quality');
          })
        // ★★★ 2026-10-18（用户：「播放页歌曲菜单里加个投播」）：
        //   投播**没有第二套实现** —— 底部那排那颗就是 `AVCastPicker`（`@kit.AVSessionKit`，
        //   api 10+，`SystemCapability.Multimedia.AVSession.AVCast`），系统自己弹设备列表。
        //   这里把**整行**做成它的 `customPicker`：视觉与 `MenuRow` 逐项一致，
        //   点击热区 = 整个 52vp 行（不挂在 `MenuRow` 的 onClick 上 —— 那会挡住系统设备列表）。
        //   ⚠️ 不给 `normalColor/activeColor` 传 `$r(...)`：SDK 签名是 `Color | number | string`，
        //     `Resource` 不在其中；外观已完全由 customPicker 决定，这里传全透明兜底。
        AVCastPicker({
          normalColor: '#00000000',
          activeColor: '#00000000',
          customPicker: (): void => {
            this.CastMenuRow()
          }
        })
          .width('100%')
          .height(ControlAreaComponent.MENU_ROW_H_VP)
        this.MenuRow($r('app.string.player_menu_share'), $r('sys.symbol.share'),
          (): void => {
            this.closeMenuSheet();
            this.shareCurrentSong();
          })
        // 「查看评论」已经从菜单里**移除**：播放页底部工具行新增了「评论」按钮，
        // 一级入口比藏在这里少点两下（用户明确要求）。
      }

      // 评论子页自带标题栏与关闭，不再叠一个「取消」，否则底部被吃掉一大块
      if (!this.showMenuComment) {
        Button('取消')
          .width('100%')
          .height(44)
          .fontSize(15)
          .borderRadius(10)
          .backgroundColor($r('app.color.background_secondary'))
          .fontColor($r('app.color.font_tertiary'))
          .margin({ top: 8 })
          .onClick(() => {
            this.closeMenuSheet();
          })
      }
    }
    .width('100%')
    // 评论子页要**铺满弹层**：左右/下方留内边距的话，大图层四周会露出一圈弹层底色
    // （用户反馈的「屏幕左右以及下方的黑边」就是这层内边距）。菜单本身仍然留白。
    .padding(this.showMenuComment ?
      { left: 0, right: 0, bottom: 0 } : { left: 16, right: 16, bottom: 24 })
    .backgroundColor($r('app.color.background_secondary'))
  }

  /** 添加到歌单选择器内容：新建歌单输入 + 歌单列表。 */
  @Builder
  private PlaylistPickerRows() {
    TextInput({ text: this.newPlaylistName, placeholder: '请输入歌单名称' })
      .width('100%')
      .height(44)
      .borderRadius(10)
      .padding({ left: 12, right: 12 })
      .margin({ top: 8 })
      .onChange((value: string) => {
        this.newPlaylistName = value;
      })

    Button('新建并添加')
      .width('100%')
      .height(40)
      .fontSize(14)
      .borderRadius(10)
      .backgroundColor(this.themeState.color)
      .fontColor(Color.White)
      .onClick(() => {
        this.createPlaylistWithSong();
      })

    if (this.playlistOptions.length > 0) {
      Scroll() {
        Column({ space: 2 }) {
          ForEach(this.playlistOptions, (p: PlaylistDto) => {
            Row() {
              Text(p.name)
                .fontSize(15)
                .fontColor($r('app.color.font_primary'))
                .maxLines(1)
                .layoutWeight(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(p.songs.length + ' 首')
                .fontSize(12)
                .fontColor($r('app.color.font_tertiary'))
            }
            .width('100%')
            .height(44)
            .padding({ left: 14, right: 14 })
            .borderRadius(10)
            .backgroundColor($r('app.color.background_secondary'))
            .onClick(() => {
              this.addToPlaylist(p);
            })
          }, (p: PlaylistDto) => p.id)
        }
        .width('100%')
      }
      .height(170)
      .scrollBar(BarState.Off)
      .margin({ top: 8 })
    }
  }

  /** 歌曲菜单每一行的高度（vp）。`MenuRow` 与「投播」行共用，保证行高一致。 */
  private static readonly MENU_ROW_H_VP: number = 52;

  /**
   * 歌曲菜单里的「投播」行。
   *
   * 视觉与 {@link MenuRow} **逐项相同**（图标 20 / 文字 16 / 右侧 chevron / 52 行高 / 同样的圆角与底色），
   * 但**不挂 `onClick`**：点击行为由外层的 `AVCastPicker` 接管（它自己弹系统的可投播设备列表）。
   * 图标沿用底部那排投播的 `sys.symbol.shareplay`，两处入口看起来是同一个功能。
   */
  @Builder
  private CastMenuRow() {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.shareplay'))
        .fontSize(20)
        .fontWeight(FontWeight.Regular)
        .fontColor([$r('app.color.font_primary')])
      Text('投播')
        .fontSize(16)
        .fontColor($r('app.color.font_primary'))
      Blank()
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('app.color.font_tertiary')])
    }
    .width('100%')
    .height(ControlAreaComponent.MENU_ROW_H_VP)
    .padding({ left: 16, right: 16 })
    .borderRadius(10)
    .backgroundColor($r('app.color.background_secondary'))
  }

  /** One menu row: icon + label, tap triggers the given action. */
  @Builder
  private MenuRow(label: string | Resource, icon: Resource, action: () => void) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontWeight(FontWeight.Regular)
        .fontColor([$r('app.color.font_primary')])
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.font_primary'))
      Blank()
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('app.color.font_tertiary')])
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .borderRadius(10)
    .backgroundColor($r('app.color.background_secondary'))
    .onClick(() => {
      action();
    })
  }

  build() {
    Column() {
      this.bottomPanel()
      QueuePlaylistSheet({
        isShow: this.showPlaylistSheet,
        onDismiss: (): void => {
          this.showPlaylistSheet = false;
        }
      })
      OtherVersionsSheet({
        isShow: this.showOtherVersionsSheet,
        initialKeyword: this.otherVersionsKeyword,
        onDismiss: (): void => {
          this.showOtherVersionsSheet = false;
        }
      })
    }
    // 自动收起的位移与淡出：宿主（播放页）把 chromeOffsetY / chromeOpacity 传进来驱动，
    // 静止态这两个值是 0 / 1，所以这一层对布局与观感没有任何影响。
    .translate({ y: this.chromeOffsetY })
    .opacity(this.chromeOpacity)
    .onAppear(() => {
      this.playMode = PlayerDataUtil.getPlayMode();
    })
    .bindSheet(this.menuSheetOpen(), this.MenuSheet(), {
      // 评论子页要整屏高度才够看（列表 + 两个页签）；菜单本身保持固定 360
      height: this.showMenuComment ? SheetSize.LARGE : 416,
      dragBar: true,
      showClose: false,
      backgroundColor: $r('app.color.background_secondary'),
      onDisappear: (): void => {
        // 记下关闭动画结束的时刻（重新打开的冷却用），顺手把子页状态清干净
        this.sheetClosedAtMs = Date.now();
        this.resetMenuSubPages();
        // ★ 状态在宿主手里：下拉关闭 / 点遮罩关闭都要通知它，否则宿主以为还开着、
        //   再点一次「更多」会**打不开**（`showMenuSheet` 已经是 true）。
        this.requestMenuSheet(false);
      }
    })
  }
}

@Extend(Image)
function controlImageBuilder() {
  .aspectRatio(1)
  .opacity(0.86)
  .objectFit(ImageFit.Contain)
}
