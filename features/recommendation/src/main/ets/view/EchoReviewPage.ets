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
 * 「回响」月度听歌报告（用户 2026-10-12 要求「来波大的」，参照另一个音乐软件的"回响"界面）。
 *
 * 位置：**底栏中间**（首页 ↔ 我的 之间），所以本页是 TabContent 的直挂页，不是路由页。
 *
 * 数据来源只有一个：`MusicStoreService.getHistory()`（`PlayedSongRecord[]`，每条 = 播过一次）。
 * 由此聚合出：总时长 / 次数 / 歌曲数 / 歌手数、最常听的歌 / 歌手 / 专辑、听歌时段、听歌日历、
 * 本月新发现、完播率（口径见下）。**没有的数据不编**：
 *   · 「完整听完几次」在播放链路里没有落库（`PlayedSongRecord` 只有 `interval` 时长和 `time` 时间），
 *     所以完播率按**曲目占比**给出（本月听过的歌里，播过 ≥2 次的比例）。
 *     该口径**只留在这里**，页面上不再写（用户 2026-10-14：那行说明没必要）。
 *
 * 动态背景（用户描述）：滑到「最常听的歌手」那一段的过程中，背景从纯黑**渐变为该歌手图片的取色**，
 * 离开该段再渐变回黑。这里的"取色"用的是**同一张图的高斯模糊 + 低透明度**（等效取色的观感，
 * 且不依赖 PixelMap 解码链路，稳）；`backdropOpacity` 由 `onVisibleAreaChange` 驱动。
 */

import { AppStorageKeys, BarScrollHelper, MusicAppState, MusicStoreService, PageTopInsetHelper, PlayedSongRecord } from 'musicbasic';
import { AppStorageV2, matrix4, uiObserver } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';

/** 回响页日志域/标签：`hdc shell hilog | findstr RzdEcho` 可捞侧卡量测与矩阵构造。 */
const ECHO_DOMAIN: number = 0x0001;
const ECHO_TAG: string = 'RzdEcho';

/** 一段统计结果（整体重建后一次性赋给 @Local，避免深层可变状态）。 */
export class EchoStats {
  totalMinutes: number = 0;
  playCount: number = 0;
  songCount: number = 0;
  singerCount: number = 0;
  topSongs: EchoTopSong[] = [];
  topArtists: EchoTopArtist[] = [];
  topAlbums: EchoTopAlbum[] = [];
  hourBuckets: number[] = [];
  dayBuckets: number[] = [];
  listenDays: number = 0;
  newSongCount: number = 0;
  newSongTotal: number = 0;
  completeRate: number = 0;
  completeCount: number = 0;
  halfCount: number = 0;
  perDayMinutes: number = 0;
  /** 上个月的总分钟数（用来显示「是上个月的 X 倍」，官方那句）。 */
  prevMinutes: number = 0;
  /** 最长连续听歌天数（官方日历下面那三行的第一行）。 */
  longestStreak: number = 0;
  /** 当月听得最多的那一天（1-31）与次数（官方第三行「10 月 11 日听得最多 —— 2 次」）。 */
  bestDay: number = 0;
  bestDayCount: number = 0;
}

class EchoTopSong {
  name: string = '';
  singer: string = '';
  img: string = '';
  count: number = 0;
  share: number = 0;
}

class EchoTopArtist {
  name: string = '';
  img: string = '';
  count: number = 0;
  share: number = 0;
}

class EchoTopAlbum {
  name: string = '';
  img: string = '';
  count: number = 0;
}

const HOURS_IN_DAY: number = 24;
const DAYS_MAX: number = 31;
const TOP_SONGS: number = 3;
const TOP_ARTISTS: number = 4;
const TOP_ALBUMS: number = 3;
/**
 * 【2026-10-13 第四轮：按参考软件截图**逐像素量**出来的四个数】
 *
 * 量法：`_recover\tools\card-profile.ps1`（按饱和度找封面色块）+ `crop-grid.ps1`（裁图叠 20px 网格）
 * 量参考软件 `com.yonminma.wanting` 的回响页封面（截图 1224×2776，密度 ≈3.4px/vp）：
 *   · 中间 1st 封面 531px 宽；两侧封面**外边**高 488px ⇒ 侧/中 = 488/531 ≈ 0.92；
 *   · 侧卡可见宽 414px（由它下方三行文字的居中点反推：文字中心在离外边 207px ≈ 可见宽的一半）；
 *   · 侧卡上边斜率 dy/dx = 0.168、下边 −0.087（按**可见宽**算）；
 *   · 外高 488 → 内高 355（=488×(1−0.168−0.087)，与 `侧翼.txt` 的 0.80 对得上）。
 */
/** 侧卡封面边长（vp）：中间 150 × 0.92 ≈ 138（**变换盒就是它**，不含下面三行文字）。 */
const SIDE_CARD_VP: number = 138;
/** 中间那张（1st）的封面边长（vp）—— 与参考软件的 1st 封面一致（150vp = 510px）。 */
const MAIN_CARD_VP: number = 150;
/** 横向透视收缩：可见宽 / 封面边长 = 414/488 ≈ 0.848（绕竖轴转的余弦缩短）。 */
const SIDE_SQUEEZE: number = 0.848;
/** 上边斜率（按**收缩后**的可见宽算）：参考实测 0.168。 */
const SIDE_TOP_SLOPE: number = 0.168;
/** 下边斜率：实测 −0.087（即下边往内**抬** 0.087×可见宽）。 */
const SIDE_BOTTOM_SLOPE: number = 0.087;

/** 把 `mm:ss` 解析成秒；解析不出来算 0（不猜）。 */
function intervalSeconds(interval: string): number {
  const parts: string[] = interval.split(':');
  if (parts.length !== 2) {
    return 0;
  }
  const mm: number = Number.parseInt(parts[0], 10);
  const ss: number = Number.parseInt(parts[1], 10);
  if (Number.isNaN(mm) || Number.isNaN(ss)) {
    return 0;
  }
  return mm * 60 + ss;
}

function two(n: number): string {
  return n < 10 ? '0' + n : String(n);
}

/** 本月起止（本地时区）。 */
class MonthRange {
  year: number = 0;
  month: number = 0;
  start: number = 0;
  end: number = 0;
  label: string = '';
}

function monthRangeOf(offsetMonths: number): MonthRange {
  const now: Date = new Date();
  const d: Date = new Date(now.getFullYear(), now.getMonth() + offsetMonths, 1, 0, 0, 0, 0);
  const range: MonthRange = new MonthRange();
  range.year = d.getFullYear();
  range.month = d.getMonth() + 1;
  range.start = d.getTime();
  const next: Date = new Date(d.getFullYear(), d.getMonth() + 1, 1, 0, 0, 0, 0);
  range.end = next.getTime();
  range.label = range.month + ' 月';
  return range;
}

@ComponentV2
export struct EchoReviewPage {
  /** 壳层页签"再点一次回到顶部"的下发信号。 */
  @Param scrollTopCommand: number = 0;
  /** 当前统计（整体替换，见文件头）。 */
  @Local stats: EchoStats = new EchoStats();
  /** 背景图（= 第一名歌手的那张图），为空时背景保持纯黑。 */
  @Local backdropImg: string = '';
  /** 背景不透明度：滑到歌手段时 1，离开时 0（用 animateTo 过渡）。 */
  @Local backdropOpacity: number = 0;
  /** 月份偏移：0 = 本月，-1 = 上月 …（点标题切换）。 */
  @Local monthOffset: number = 0;
  @Local yearLabel: string = '';
  @Local monthLabel: string = '';
  private scroller: Scroller = new Scroller();
  /** 共享播放状态（底栏联动要读它）。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** 窗口断点（底栏联动的 notifyScrollDelta 需要）。 */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;

  aboutToAppear(): void {
    this.reload();
  }

  /** 历史变化（播放器、歌曲菜单…都会 +1 `historyVersion`）后重算。 */
  @Monitor('store.historyVersion')
  onHistoryChanged(): void {
    this.reload();
  }

  /** 壳层点了当前页签：滚回顶部。 */
  @Monitor('scrollTopCommand')
  onScrollTopCommand(): void {
    this.scroller.scrollEdge(Edge.Top);
  }

  /** 重算整页统计（含背景图选择）。 */
  private reload(): void {
    const store: MusicStoreService = MusicStoreService.getInstance();
    const all: PlayedSongRecord[] = store.getHistory();
    const range: MonthRange = monthRangeOf(this.monthOffset);
    const prev: MonthRange = monthRangeOf(this.monthOffset - 1);
    this.yearLabel = String(range.year) + ' 年';
    this.monthLabel = range.label;
    const stats: EchoStats = EchoReviewPage.buildStats(all, range, prev);
    this.stats = stats;
  }

  /** 上个月对比文案（官方那句「是上个月的 X 倍」）。 */
  private ratioText(): string {
    const prev: number = this.stats.prevMinutes;
    if (prev <= 0) {
      return this.stats.totalMinutes > 0 ? '上个月还没有听歌记录' : '';
    }
    const ratio: number = this.stats.totalMinutes / prev;
    return '是上个月的 ' + ratio.toFixed(1) + ' 倍';
  }

  /** 纯函数：把记录聚合成一段统计。 */
  private static buildStats(all: PlayedSongRecord[], range: MonthRange, prev: MonthRange): EchoStats {
    const out: EchoStats = new EchoStats();
    out.hourBuckets = [];
    for (let i: number = 0; i < HOURS_IN_DAY; i++) {
      out.hourBuckets.push(0);
    }
    out.dayBuckets = [];
    for (let i: number = 0; i < DAYS_MAX; i++) {
      out.dayBuckets.push(0);
    }
    const inMonth: PlayedSongRecord[] = [];
    const firstSeen: Map<string, number> = new Map();
    // ★ 2026-10-14：「新发现」要按**歌**（name+singer）算"是不是这个月才第一次听"，
    //   所以这里按**同一口径**再记一份每首歌的首次出现时间（`firstSeen` 是按 source|songId 记的，对不上）。
    const songFirstSeen: Map<string, number> = new Map();
    let prevSeconds: number = 0;
    for (let i: number = 0; i < all.length; i++) {
      const r: PlayedSongRecord = all[i];
      const key: string = r.source + '|' + r.songId;
      const prevSeen: number | undefined = firstSeen.get(key);
      if (prevSeen === undefined || r.time < prevSeen) {
        firstSeen.set(key, r.time);
      }
      const songKeyAll: string = r.name + '\u0001' + r.singer;
      const prevSongSeen: number | undefined = songFirstSeen.get(songKeyAll);
      if (prevSongSeen === undefined || r.time < prevSongSeen) {
        songFirstSeen.set(songKeyAll, r.time);
      }
      if (r.time >= range.start && r.time < range.end) {
        inMonth.push(r);
      } else if (r.time >= prev.start && r.time < prev.end) {
        prevSeconds += intervalSeconds(r.interval);
      }
    }
    out.prevMinutes = Math.round(prevSeconds / 60);
    out.playCount = inMonth.length;
    let seconds: number = 0;
    const songCount: Map<string, number> = new Map();
    const songImg: Map<string, string> = new Map();
    const artistCount: Map<string, number> = new Map();
    const artistImg: Map<string, string> = new Map();
    const albumCount: Map<string, number> = new Map();
    const albumImg: Map<string, string> = new Map();
    const days: Set<number> = new Set();
    let newest: number = 0;
    let brandNew: number = 0;
    for (let i: number = 0; i < inMonth.length; i++) {
      const r: PlayedSongRecord = inMonth[i];
      seconds += intervalSeconds(r.interval);
      const songKey: string = r.name + '\u0001' + r.singer;
      songCount.set(songKey, (songCount.get(songKey) ?? 0) + 1);
      if (r.img.length > 0 && songImg.get(songKey) === undefined) {
        songImg.set(songKey, r.img);
      }
      artistCount.set(r.singer, (artistCount.get(r.singer) ?? 0) + 1);
      if (r.img.length > 0 && artistImg.get(r.singer) === undefined) {
        artistImg.set(r.singer, r.img);
      }
      if (r.albumName.length > 0) {
        albumCount.set(r.albumName, (albumCount.get(r.albumName) ?? 0) + 1);
        if (r.img.length > 0 && albumImg.get(r.albumName) === undefined) {
          albumImg.set(r.albumName, r.img);
        }
      }
      const d: Date = new Date(r.time);
      out.hourBuckets[d.getHours()] = out.hourBuckets[d.getHours()] + 1;
      const dayIndex: number = d.getDate() - 1;
      if (dayIndex >= 0 && dayIndex < DAYS_MAX) {
        out.dayBuckets[dayIndex] = out.dayBuckets[dayIndex] + 1;
      }
      days.add(d.getDate());
      if (r.time > newest) {
        newest = r.time;
      }
    }
    out.totalMinutes = Math.round(seconds / 60);
    out.songCount = songCount.size;
    out.singerCount = artistCount.size;
    out.listenDays = days.size;
    let streak: number = 0;
    for (let i: number = 0; i < DAYS_MAX; i++) {
      // ★ 2026-10-14：顺手把「听得最多的那一天」算出来（原来 bestDay/bestDayCount 只声明没赋值 ⇒
      //   日历那行永远显示"还没有哪一天听得特别多"，用户报的 bug）
      if (out.dayBuckets[i] > out.bestDayCount) {
        out.bestDayCount = out.dayBuckets[i];
        out.bestDay = i + 1;
      }
      if (out.dayBuckets[i] > 0) {
        streak++;
        if (streak > out.longestStreak) {
          out.longestStreak = streak;
        }
      } else {
        streak = 0;
      }
    }
    out.perDayMinutes = out.listenDays > 0 ? Math.round(out.totalMinutes / out.listenDays) : 0;
    // ★ 2026-10-14：「新发现」原来在**播放记录**上累加 brandNew ⇒ 31 条记录 / 28 首歌，分子比还分母大（用户报的怪值）。
    //   改成按**歌**算：本月听过的歌里，首次出现时间落在本月的才算"新发现"。
    songCount.forEach((count: number, songKey: string): void => {
      if ((songFirstSeen.get(songKey) ?? 0) >= range.start) {
        brandNew++;
      }
    });
    out.newSongCount = brandNew;
    out.newSongTotal = songCount.size;
    // 完播率（口径：本月听过的歌里播过 ≥2 次的占比 —— 播放链路没有"是否听完"的落库，见文件头）
    let repeated: number = 0;
    songCount.forEach((count: number): void => {
      if (count >= 2) {
        repeated++;
      }
    });
    out.completeCount = repeated;
    out.halfCount = Math.max(0, songCount.size - repeated);
    out.completeRate = songCount.size > 0 ? Math.round(repeated * 100 / songCount.size) : 0;
    // Top 榜（简单选择排序，榜单只要前几个，规模很小）
    out.topSongs = EchoReviewPage.pickSongs(songCount, songImg, out.playCount);
    out.topArtists = EchoReviewPage.pickArtists(artistCount, artistImg, out.playCount);
    out.topAlbums = EchoReviewPage.pickAlbums(albumCount, albumImg);
    return out;
  }

  private static pickSongs(counts: Map<string, number>, imgs: Map<string, string>,
    total: number): EchoTopSong[] {
    const out: EchoTopSong[] = [];
    const used: Set<string> = new Set();
    for (let n: number = 0; n < TOP_SONGS; n++) {
      let bestKey: string = '';
      let best: number = -1;
      counts.forEach((value: number, key: string): void => {
        if (!used.has(key) && value > best) {
          best = value;
          bestKey = key;
        }
      });
      if (bestKey.length === 0) {
        break;
      }
      used.add(bestKey);
      const parts: string[] = bestKey.split('\u0001');
      const item: EchoTopSong = new EchoTopSong();
      item.name = parts[0];
      item.singer = parts.length > 1 ? parts[1] : '';
      item.img = imgs.get(bestKey) ?? '';
      item.count = best;
      item.share = total > 0 ? Math.round(best * 100 / total) : 0;
      out.push(item);
    }
    return out;
  }

  private static pickArtists(counts: Map<string, number>, imgs: Map<string, string>,
    total: number): EchoTopArtist[] {
    const out: EchoTopArtist[] = [];
    const used: Set<string> = new Set();
    for (let n: number = 0; n < TOP_ARTISTS; n++) {
      let bestKey: string = '';
      let best: number = -1;
      counts.forEach((value: number, key: string): void => {
        if (!used.has(key) && value > best) {
          best = value;
          bestKey = key;
        }
      });
      if (bestKey.length === 0) {
        break;
      }
      used.add(bestKey);
      const item: EchoTopArtist = new EchoTopArtist();
      item.name = bestKey;
      item.img = imgs.get(bestKey) ?? '';
      item.count = best;
      item.share = total > 0 ? Math.round(best * 100 / total) : 0;
      out.push(item);
    }
    return out;
  }

  private static pickAlbums(counts: Map<string, number>, imgs: Map<string, string>): EchoTopAlbum[] {
    const out: EchoTopAlbum[] = [];
    const used: Set<string> = new Set();
    for (let n: number = 0; n < TOP_ALBUMS; n++) {
      let bestKey: string = '';
      let best: number = -1;
      counts.forEach((value: number, key: string): void => {
        if (!used.has(key) && value > best) {
          best = value;
          bestKey = key;
        }
      });
      if (bestKey.length === 0) {
        break;
      }
      used.add(bestKey);
      const item: EchoTopAlbum = new EchoTopAlbum();
      item.name = bestKey;
      item.img = imgs.get(bestKey) ?? '';
      item.count = best;
      out.push(item);
    }
    return out;
  }

  /** 点标题切换月份（本月 → 上月 → … 最多回溯 11 个月）。 */
  private shiftMonth(delta: number): void {
    const next: number = this.monthOffset + delta;
    if (next > 0 || next < -11) {
      return;
    }
    this.monthOffset = next;
    this.reload();
  }

  /** HDS 标题栏：标题就是「月份 · 回响」（官方把这句话放在标题栏里）。 */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    return {
      // ★★ 用户 2026-10-13：「标题还是没正常，参考推荐页（首页）或我的页」⇒ 与那两页**逐字一致**：
      //   页根 ignoreLayoutSafeArea(TOP,BOTTOM) 让盒子从 y=0 起排 + avoidLayoutSafeArea: true
      //   让 HDS 标题栏自己退到状态栏下方 ⇒ 标题落在 38..94（这就是那两页的口径）。
      avoidLayoutSafeArea: true,
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        }
      },
      content: {
        title: {
          mainTitle: this.monthLabel + ' · 回响',
          mainTitleSize: TitleSize.TITLE_ML
        }
      }
    };
  }

  /** 页面主体（原 build 的内容；2026-10-12 标题交给 HDS 标题栏后原样搬进来）。 */
  @Builder
  private EchoBody() {
    Stack({ alignContent: Alignment.Top }) {
      // ① 动态背景：第一名歌手那张图的高斯模糊（= 它的取色观感），滑到歌手段时淡入
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.86)

      // ② 内容
      Scroll(this.scroller) {
        Column({ space: 18 }) {
          this.Header()
          this.OverviewCard()
          this.TopSongsSection()
          this.TopArtistSection()
          this.TopAlbumsSection()
          this.AudienceSection()
          this.CompletionSection()
          this.NewDiscoverySection()
          Column().width('100%').height(120)
        }
        .width('100%')
      // 盒子从 y=0 起排（页根 ignore TOP）⇒ 内容让位 = 状态栏 + 标题栏 = 94（公共 helper 同一口径）
      .padding({ left: 16, right: 16, top: PageTopInsetHelper.targetContentTopVp() + 8 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      // ★ 用户 2026-10-13：「回想页上滑底栏不会收起，首页和我的页是正常的」⇒ 补上同一套底栏联动
      .onScrollFrameBegin((offset: number): OnScrollFrameBeginHandlerResult => {
        if (BarScrollHelper.isEnabled()) {
          BarScrollHelper.notifyScrollDelta(this.getUIContext(), this.appState, offset,
            this.breakpointEnv.widthBreakpoint as number);
        }
        return { offsetRemain: offset };
      })
      .clipContent(ContentClipMode.SAFE_AREA)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }

  build() {
    // ★ 用户 2026-10-12：「10 月 · 回响 是 HDS 标题栏里面的」⇒ 与首页/历史页同款：
    //   页根用 HdsNavDestination + titleBar，标题交给 HDS（滚动联动渐变模糊也一起有了）。
    HdsNavDestination() {
      this.EchoBody()
    }
    .hideTitleBar(false)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.scroller])
    // ★★ 照 `RecommendPage` 的根属性链补齐（用户 2026-10-12：「标题栏跑顶部了」）：
    //   页签页的 HdsNavDestination 必须给 ignoreLayoutSafeArea(TOP,BOTTOM)，
    //   否则盒子被压在安全区内、HDS 标题栏再自己让一次 ⇒ 标题跑到状态栏里。
    // ★★ GLM5.3（zai/glm-5.3）诊断 2026-10-12：「标题跑屏幕顶」的根因 —— 页根写了 ignoreLayoutSafeArea(TOP)
    //   把布局区扩到 y=0，而 avoidLayoutSafeArea=false 的语义是「宿主已避让，标题栏不再避让」⇒ 标题锚在 0..56。
    //   页签页没人替我们避让（入栈页是 Navigation 保证页根从状态栏下开始），所以这里**只留 BOTTOM**：
    //   页根回到状态栏之下，标题自然落在 statusBar..statusBar+56。
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .hideBackButton(true)
    .backgroundColor('#000000')
  }

  /** 标题：`10 月 · 回响` + 分钟数 + 与上月的倍数（官方版式）。 */
  @Builder
  private Header() {
    Column({ space: 6 }) {

      Text(this.stats.totalMinutes + ' 分钟')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .width('100%')
        .textAlign(TextAlign.Start)

      if (this.ratioText().length > 0) {
        Text(this.ratioText())
          .fontSize(13)
          .fontColor('#B3FFFFFF')
          .width('100%')
          .textAlign(TextAlign.Start)
      }

      // 年 / 月两枚胶囊（官方是带下拉箭头的胶囊按钮；这里左右箭头切月，形态一致）
      Row({ space: 8 }) {
        Row({ space: 4 }) {
          Text(this.yearLabel)
            .fontSize(13)
            .fontColor('#E6FFFFFF')
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(11)
            .fontColor(['#99FFFFFF'])
        }
        .height(30)
        .padding({ left: 12, right: 12 })
        .borderRadius(15)
        .backgroundColor('#1FFFFFFF')

        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(12)
            .fontColor(['#E6FFFFFF'])
            .onClick(() => {
              this.shiftMonth(-1);
            })
          Text(this.monthLabel)
            .fontSize(13)
            .fontColor('#E6FFFFFF')
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(12)
            .fontColor(['#E6FFFFFF'])
            .onClick(() => {
              this.shiftMonth(1);
            })
        }
        .height(30)
        .padding({ left: 12, right: 12 })
        .borderRadius(15)
        .backgroundColor('#1FFFFFFF')
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 三格统计：次播放 / 首歌 / 位歌手。 */
  @Builder
  private OverviewCard() {
    Row() {
      this.StatCell(String(this.stats.playCount), '次播放')
      this.StatCell(String(this.stats.songCount), '首歌')
      this.StatCell(String(this.stats.singerCount), '位歌手')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  private StatCell(value: string, label: string) {
    // ★ 用户 2026-10-13：「三个文字颜色都不一样」⇒ 数字恒纯白、单位恒灰（与官方一致，不再混主题色）
    Column({ space: 4 }) {
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
      Text(label)
        .fontSize(12)
        .fontColor('#8CFFFFFF')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private SectionTitle(text: string) {
    Text(text)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .width('100%')
      .textAlign(TextAlign.Start)
  }

  /** 最常听的歌：第 1 名大图居中、2/3 名两侧。 */
  @Builder
  private TopSongsSection() {
    Column({ space: 10 }) {
      this.SectionTitle('你听了什么')
      Text('最常听的歌')
        .fontSize(13)
        .fontColor('#99FFFFFF')
        .width('100%')
        .textAlign(TextAlign.Start)
      if (this.stats.topSongs.length === 0) {
        this.EmptyHint()
      } else {
        // ★★★ 用户 2026-10-13：**左右顺序跟官方是反的** —— 官方是「3rd 在左、1st 居中、2nd 在右」
        //   （不是常见的 2nd 左 / 3rd 右 领奖台顺序），所以这里 topSongs[2] 放左、topSongs[1] 放右。
        // ★★★ 2026-10-14 第五轮：**改用 Stack + 满宽 Row 显式贴边**，不再用 Row 的 layoutWeight 余量算术。
        //   真机实测（本版之前）：两侧 `.width(138)` + 中间 `layoutWeight(1)` 时，中间那条列实际拿到 ≈61.7vp
        //   而不是算出来的 52vp ⇒ 三张卡整体右移 ≈9.7vp，于是**左边留白 16vp、右边只剩 6.5vp**
        //   （用户报的"左右不对称"）。现在左右各用一个满宽 Row 把卡顶到 Row 的两端，
        //   两端都等于页面内边距 16vp；中间那张由 Stack 居中。三张的压叠关系不变（中间的 zIndex 最高）。
        Stack({ alignContent: Alignment.Bottom }) {
          if (this.stats.topSongs.length > 2) {
            Row() {
              this.SongCover(this.stats.topSongs[2], '3rd')
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
          }

          if (this.stats.topSongs.length > 1) {
            Row() {
              this.SongCover(this.stats.topSongs[1], '2nd')
            }
            .width('100%')
            .justifyContent(FlexAlign.End)
          }

          this.SongCover(this.stats.topSongs[0], '1st')
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 封面边长（vp）：`1st` 用 `MAIN_CARD_VP`(150)，两侧用 `SIDE_CARD_VP`(138)。
   * 也**就是**四点投影的变换盒尺寸（盒 = 封面，见 `sideQuadFor()`）。
   * @param rank `1st` / `2nd` / `3rd`
   * @returns 边长 vp
   */
  private coverVpOf(rank: string): number {
    return rank === '1st' ? MAIN_CARD_VP : SIDE_CARD_VP;
  }

  /**
   * 封面圆角（vp）。按边长等比缩放（150 ⇒ 13vp 是原本的观感，138 ⇒ 12vp）。
   * @param rank `1st` / `2nd` / `3rd`
   * @returns 圆角 vp
   */
  private coverRadiusOf(rank: string): number {
    return rank === '1st' ? 13 : 12;
  }

  /**
   * 一个名次：封面 + 名次/歌名/次数三段文字。
   *
   * 三张卡在 `Row` 里**不靠负 margin 叠**：两侧各占一个**定宽列**（`SIDE_CARD_VP`），
   * 中间那张 `layoutWeight(1)` 吃掉剩下的全部宽度 —— 它为了居中会**溢出**自己那条窄列，
   * 于是自然压住两侧的内边（`zIndex(2)`）。这样在窄屏上两侧不会被顶出屏幕。
   * @param item 名次数据
   * @param rank `1st` / `2nd` / `3rd`
   */

  /**
   * 侧卡封面的**四点投影矩阵**（`matrix4.setPolyToPoly(pointCount: 4)` ⇒ 透视变换，不是仿射）。
   *
   * 为什么不用 `rotate({ y: 1, perspective })`：那一套的**实际透视强度**在本机和文档/任何模型推算都对不上
   * （真机记录：18/200 方形、24/90 过强、16/121 与 24/580 又回到方形），参数路线已被证伪；
   * 四点映射直接把参考软件量出来的**梯形四角**钉死，几何 100% 可控。
   *
   * ⚠️ src/dst 只按**封面边长** `side` 给（y 也只用到 [0, side]），但矩阵是加在**整列**上的（见 `SongCover()`）。
   * 为什么这样是对的：这套映射在 y 方向是**线性**的 ——
   *   x' = x·(innerX/side)，y' = y·s(ξ) + ξ·topDrop，其中 ξ = x/side、s(ξ) = 1 − ξ·(topDrop+bottomRise)/side。
   * 所以超出 [0, side] 的 y 会被同一线性关系外推：封面底边（y = side）处的斜率继续往下延伸，
   * 下面三行文字自动拿到**同一个透视**（一起斜、一起横向收窄），并且和封面底边**无缝衔接**（不会有台阶）。
   * 取 [0, side] 作为 src 只是为了把参考软件的实测数直接钉在**封面**上：
   *   · 封面**上边**斜率 = topDrop/可见宽 = 0.168 ✓（参考实测）；
   *   · 封面**下边**斜率 = −bottomRise/可见宽 = −0.087 ✓；
   *   · 封面内/外高比 = 1 − 0.168 − 0.087 = 0.783 ✓（与 `侧翼.txt` 的 0.80 对得上）。
   * 反过来若按"整列高度"去设参数，封面就会被压过头（这一版之前就是这么错的）。
   *
   * 形状（以 3rd 卡为例，外边在左）：
   *   · 外边 TL(0,0) / BL(0,side) **原地不动**（满高、严格竖直）；
   *   · 内边挪到 x = `side × SIDE_SQUEEZE`（0.848，横向缩短 = 绕竖轴旋转的透视收缩）；
   *   · 上边 TR 下沉 `可见宽 × 0.168`、下边 BR 上抬 `可见宽 × 0.087`（两个斜率都是参考实测值）。
   *
   * ⚠️ 口径（查本地 `@ohos.matrix4.d.ts` + 官方文档确认）：
   *   · `Point.x/y` 单位是 **px**，必须 `vp2px` 换算；
   *   · `pointCount: 4` 才是透视矩阵（0/1/2/3 分别是恒等/平移/仿射/含剪切仿射）；
   *   · `dstIndex` 默认值是 `src.length/2`（这里会是 2！），所以**必须显式传 0**；
   *   · 点序照抄官方示例 `TL,TR,BL,BR`（src/dst 用同一顺序即可，映射只认"第 i 个对第 i 个"）。
   *   · 配套的 `.scale({ centerX: 0, centerY: 0, x: 1 })` 见 `SongCover()`：官方明确要求它把变换中心点
   *     从"组件中心"挪到"组件左上角"，否则四点坐标会被当成相对中心的坐标。
   *   · 四个数全是常量 ⇒ 这里**不需要任何测量**（上一版用 `onAreaChange` 量列高喂进来，量到的口径不可控，
   *     真机上出现过"上边斜率对、下边几乎不动"的怪现象）。
   * @param rank `1st` / `2nd` / `3rd`（`1st` 不形变，返回恒等矩阵）
   * @returns 变换矩阵
   */
  private sideQuadFor(rank: string): matrix4.Matrix4Transit {
    if (rank === '1st') {
      return matrix4.identity();
    }
    const ui = this.getUIContext();
    const side: number = ui.vp2px(SIDE_CARD_VP);
    const innerX: number = side * SIDE_SQUEEZE;
    const topDrop: number = innerX * SIDE_TOP_SLOPE;
    const bottomRise: number = innerX * SIDE_BOTTOM_SLOPE;
    hilog.info(ECHO_DOMAIN, ECHO_TAG,
      'sideQuad rank=%{public}s side=%{public}f innerX=%{public}f topDrop=%{public}f bottomRise=%{public}f',
      rank, side, innerX, topDrop, bottomRise);
    // 点序 TL,TR,BL,BR（与官方示例一致）；3rd 渲染在左（外边在左）、2nd 渲染在右（外边在右）
    return matrix4.identity().setPolyToPoly({
      src: [{ x: 0, y: 0 }, { x: side, y: 0 }, { x: 0, y: side }, { x: side, y: side }],
      dst: rank === '2nd'
        ? [{ x: side - innerX, y: topDrop }, { x: side, y: 0 },
           { x: side - innerX, y: side - bottomRise }, { x: side, y: side }]
        : [{ x: 0, y: 0 }, { x: innerX, y: topDrop },
           { x: 0, y: side }, { x: innerX, y: side - bottomRise }],
      srcIndex: 0,
      dstIndex: 0,
      pointCount: 4
    });
  }
  @Builder
  private SongCover(item: EchoTopSong, rank: string) {
    // 一张卡 = 一个 Column（封面 + 名次/歌名/次数），**整列一起做四点投影**（用户 2026-10-14：
    //   「文字没有倾斜」⇒ 文字必须跟着卡片一起斜，所以变换不能再只加在封面上）。
    //   宽度钉死成封面边长（1st = 150vp、两侧 = 138vp）；在 Stack 里由外层 Row 顶到左右两端/居中。
    Column({ space: 6 }) {
      if (item.img.length > 0) {
        Image(item.img)
          .width(this.coverVpOf(rank))
          .height(this.coverVpOf(rank))
          .borderRadius(this.coverRadiusOf(rank))
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width(this.coverVpOf(rank))
          .height(this.coverVpOf(rank))
          .borderRadius(this.coverRadiusOf(rank))
          .backgroundColor('#22FFFFFF')
      }

      Text(rank)
        .fontSize(12)
          // ★ 用户 2026-10-13：「1st/2nd/3rd 颜色不一样」⇒ 三档亮度（1st 最亮）
          // ★★ 用户 2026-10-13：「官方那个 1st 是黄色，另外两个也一样」⇒ **奖牌色**（金/银/铜），不是灰阶
          .fontColor(rank === '1st' ? '#FFD54A' : (rank === '2nd' ? '#D6DEE8' : '#E0A16A'))
      Text(item.name)
        .fontSize(rank === '1st' ? 14 : 12)
        .fontWeight(rank === '1st' ? FontWeight.Bold : FontWeight.Normal)
        .fontColor('#FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(item.count + ' 次 · 占 ' + item.share + '%')
        .fontSize(11)
        .fontColor('#88FFFFFF')
        .maxLines(1)
    }
    .width(this.coverVpOf(rank))
    .alignItems(HorizontalAlign.Center)
    // ★★★ 2026-10-13 第四轮：**rotate 整条路线全退**（参数路线已被真机证伪），
    //   改用**四点投影映射** `matrix4.setPolyToPoly`（见 `sideQuadFor()`）。
    //   · 官方 `setPolyToPoly` 示例明确要求配一句 `.scale({ centerX: 0, centerY: 0, x: 1 })`（**挂在组件上**）：
    //     把变换中心点从"组件中心"挪到"组件左上角"（x:1 是恒等缩放、不改大小）。不挪的话四点坐标
    //     会被当成相对中心的坐标 ⇒ 整个梯形偏出去。`1st` 那张是恒等矩阵，配它也无副作用。
    //   · 用 `.transform()`（官方 `setPolyToPoly` 示例的写法，API 12 起可用）。
    //   · 矩阵的 src/dst 只按**封面边长** `side` 给（y 也只用 [0, side]）——这不影响下面的文字：
    //     这套映射在 y 方向是**线性**的（y' = y·s(ξ) + ξ·topDrop），超出 src 范围的 y 会被同一线性关系外推，
    //     所以文字自动拿到**同一个透视**（跟着一起斜、一起横向收窄），且与封面底边无缝衔接。
    .scale({ centerX: 0, centerY: 0, x: 1 })
    .transform(this.sideQuadFor(rank))
    // 中间那张要在最上层，才能压住左右两侧的内边（zIndex 必须给容器，不只给封面）
    .zIndex(rank === '1st' ? 2 : 1)
  }

  /** 最常听的歌手：大图卡 + 后面几名；这一段可见时背景淡入。 */
  @Builder
  private TopArtistSection() {
    Column({ space: 10 }) {
      this.SectionTitle('最常听的歌手')
      Column({ space: 10 }) {
      if (this.stats.topArtists.length === 0) {
        this.EmptyHint()
      } else {
        Column() {
          if (this.stats.topArtists[0].img.length > 0) {
            Image(this.stats.topArtists[0].img)
              .width('100%')
              .height(220)
              .objectFit(ImageFit.Cover)
          } else {
            Column().width('100%').height(220).backgroundColor('#22FFFFFF')
          }
          Column({ space: 4 }) {
            Text(this.stats.topArtists[0].name)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .width('100%')
              .textAlign(TextAlign.Start)
            Text(this.stats.topArtists[0].count + ' 次播放 · 占了你 ' +
              this.stats.topArtists[0].share + '% 的播放')
              .fontSize(12)
              .fontColor('#CCFFFFFF')
              .width('100%')
              .textAlign(TextAlign.Start)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 14 })
          .backgroundColor('#CC000000')
        }
        .width('100%')
        .borderRadius(14)
        .clip(true)

        if (this.stats.topArtists.length > 1) {
          Column() {
            ForEach(this.stats.topArtists.slice(1), (item: EchoTopArtist, index: number) => {
              Row({ space: 12 }) {
                Text(String(index + 2))
                  .fontSize(15)
                  .fontColor('#FFFFFF')
                  .width(22)
                if (item.img.length > 0) {
                  Image(item.img)
                    .width(40)
                    .height(40)
                    .borderRadius(6)
                    .objectFit(ImageFit.Cover)
                } else {
                  Column().width(40).height(40).borderRadius(6).backgroundColor('#22FFFFFF')
                }
                Text(item.name)
                  .fontSize(15)
                  .fontColor('#FFFFFF')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(item.count + ' 次')
                  .fontSize(12)
                  .fontColor('#99FFFFFF')
              }
              .width('100%')
              .height(60)
            }, (item: EchoTopArtist) => 'artist_' + item.name)
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .backgroundColor('#14FFFFFF')
          .borderRadius(14)
        }
      }
      // ★ 用户 2026-10-13：「文字放卡片外」——官方区块标题是**卡片外的纯文字**，卡片只包数据
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor('#14FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 最常听的专辑。 */
  @Builder
  private TopAlbumsSection() {
    Column({ space: 10 }) {
      this.SectionTitle('最常听的专辑')
      Column({ space: 10 }) {
      if (this.stats.topAlbums.length === 0) {
        this.EmptyHint()
      } else {
        Row({ space: 10 }) {
          ForEach(this.stats.topAlbums, (item: EchoTopAlbum) => {
            Column({ space: 6 }) {
              if (item.img.length > 0) {
                Image(item.img)
                  .width('100%')
                  .aspectRatio(1)
                  .borderRadius(10)
                  .objectFit(ImageFit.Cover)
              } else {
                Column().width('100%').aspectRatio(1).borderRadius(10).backgroundColor('#22FFFFFF')
              }
              Text(item.name)
                .fontSize(12)
                .fontColor('#FFFFFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text(item.count + ' 次')
                .fontSize(11)
                .fontColor('#88FFFFFF')
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }, (item: EchoTopAlbum) => 'album_' + item.name)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      // ★ 用户 2026-10-13：「文字放卡片外」——官方区块标题是**卡片外的纯文字**，卡片只包数据
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor('#14FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 你是怎样的听众：24 小时柱状图。 */
  @Builder
  private AudienceSection() {
    Column({ space: 10 }) {
      this.SectionTitle('你是怎样的听众')
      // ★ 用户 2026-10-13：「听歌时段 / 听歌日历 怎么还在卡片内部」⇒ 这两个小标题也放到**卡外**
      Text('听歌时段')
        .fontSize(13)
        .fontColor('#99FFFFFF')
        .width('100%')
        .textAlign(TextAlign.Start)
      Column({ space: 10 }) {
      Row({ space: 2 }) {
        ForEach(this.stats.hourBuckets, (count: number, hour: number) => {
          Column() {
            Column()
              .width('100%')
              .height(this.barHeightVp(count))
              .borderRadius(3)
              .backgroundColor(hour === this.peakHour() ? '#FF3B6B' : '#66FFFFFF')
          }
          .layoutWeight(1)
          .height(90)
          .justifyContent(FlexAlign.End)
        }, (count: number, hour: number) => 'hour_' + hour)
      }
      .width('100%')
      .height(90)
      .alignItems(VerticalAlign.Bottom)

      Row() {
        Text('0 点').fontSize(11).fontColor('#88FFFFFF')
        Blank()
        Text('12 点').fontSize(11).fontColor('#88FFFFFF')
        Blank()
        Text('23 点').fontSize(11).fontColor('#88FFFFFF')
      }
      .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor('#14FFFFFF')
      .borderRadius(16)

      // ★ 用户 2026-10-13：「官方那里听歌时段和听歌日历是**两张卡片**」⇒ 第二张卡；
      //   小标题「听歌日历」同样放在**卡外**
      Text('听歌日历')
        .fontSize(13)
        .fontColor('#99FFFFFF')
        .width('100%')
        .textAlign(TextAlign.Start)
      Column({ space: 10 }) {
      Grid() {
        ForEach(this.stats.dayBuckets, (count: number, index: number) => {
          GridItem() {
            Column()
              .width('100%')
              .width('100%')
              .aspectRatio(1)
              .borderRadius(3)
              .backgroundColor(this.dayColor(count))
          }
        }, (count: number, index: number) => 'day_' + index)
      }
      // ★ 用户 2026-10-13：官方是**两行**小方块（31 天 ÷ 16 ≈ 2 行）
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      // ★ 用户 2026-10-12：「听歌日历也太大了」⇒ 收紧成官方那种紧凑热力图
      .rowsGap(2)
      .columnsGap(2)
      .width('100%')
      .height(60)

      // ★ 官方是**三行**字（用户 2026-10-12：「下面是三行字」）
      Text('31 天里有 ' + this.stats.listenDays + ' 天在听歌')
        .fontSize(12)
        .fontColor('#CCFFFFFF')
        .width('100%')
        .textAlign(TextAlign.Start)
      Text('最长连续 ' + this.stats.longestStreak + ' 天没断过')
        .fontSize(12)
        .fontColor('#99FFFFFF')
        .width('100%')
        .textAlign(TextAlign.Start)
      Text(this.stats.bestDayCount > 0 ?
        (this.monthLabel.replace(' 月', '') + ' 月 ' + this.stats.bestDay + ' 日听得最多 —— ' + this.stats.bestDayCount + ' 次') : '还没有哪一天听得特别多')
        .fontSize(12)
        .fontColor('#CCFFFFFF')
        .width('100%')
        .textAlign(TextAlign.Start)
      // ★ 用户 2026-10-13：「文字放卡片外」——官方区块标题是**卡片外的纯文字**，卡片只包数据
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor('#14FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 完播率（口径只写在文件头，不在页面上占一行 —— 用户 2026-10-14 让删的）。 */
  @Builder
  private CompletionSection() {
    Column({ space: 8 }) {
      this.SectionTitle('完播率')
      Column({ space: 10 }) {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          Progress({ value: this.stats.completeRate, total: 100, type: ProgressType.Ring })
            .width(78)
            .height(78)
            .color('#FF3B6B')
            .style({ strokeWidth: 8 })
          Text(this.stats.completeRate + '%')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(78)
        .height(78)

        Column({ space: 4 }) {
          Text('的歌被听到了最后')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .width('100%')
            .textAlign(TextAlign.Start)
          // ★★ 用户 2026-10-14：「（口径：本月听过的歌里播过 ≥2 次的占比）这段文字留着干嘛」⇒ 口径说明整行删掉，
          //   改成官方那种**两行明细** + 卡片底部一行「平均每个听歌日 X 分钟」（官方版式）。
          Text('重复播放 ' + this.stats.completeCount + ' 首')
            .fontSize(12)
            .fontColor('#99FFFFFF')
            .width('100%')
            .textAlign(TextAlign.Start)
          Text('只听一次 ' + this.stats.halfCount + ' 首')
            .fontSize(12)
            .fontColor('#99FFFFFF')
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Text('平均每个听歌日 ' + this.stats.perDayMinutes + ' 分钟')
        .fontSize(12)
        .fontColor('#99FFFFFF')
        .width('100%')
        .textAlign(TextAlign.Start)
      // ★ 用户 2026-10-13：「文字放卡片外」——官方区块标题是**卡片外的纯文字**，卡片只包数据
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor('#14FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 新发现。 */
  @Builder
  private NewDiscoverySection() {
    Column({ space: 8 }) {
      this.SectionTitle('新发现')
      Column({ space: 10 }) {
      Row({ space: 6 }) {
        Text(String(this.stats.newSongCount))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FF3B6B')
        Text('/ ' + this.stats.newSongTotal + ' 首')
          .fontSize(14)
          .fontColor('#99FFFFFF')
          .margin({ bottom: 3 })
      }
      .width('100%')

      Progress({
        value: this.stats.newSongTotal > 0 ? this.stats.newSongCount * 100 / this.stats.newSongTotal : 0,
        total: 100,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(6)
        .color('#FF3B6B')
        .backgroundColor('#33FFFFFF')

      Text(this.stats.newSongTotal > 0 ?
        ('其中 ' + this.stats.newSongCount + ' 首是这个月才第一次听的 · 占 ' +
        Math.round(this.stats.newSongCount * 100 / this.stats.newSongTotal) + '%')
        : '这个月还没有听得上的歌')
        .fontSize(12)
        .fontColor('#CCFFFFFF')
        .width('100%')
        .textAlign(TextAlign.Start)
      // ★ 用户 2026-10-13：「文字放卡片外」——官方区块标题是**卡片外的纯文字**，卡片只包数据
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor('#14FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private EmptyHint() {
    Text('这个月还没有听歌记录，去播放几首吧')
      .fontSize(13)
      .fontColor('#99FFFFFF')
      .width('100%')
      .textAlign(TextAlign.Start)
  }

  /** 柱高：按当前最大桶归一（全是 0 时给 2vp 的底座）。 */
  private barHeightVp(count: number): number {
    let max: number = 0;
    for (let i: number = 0; i < this.stats.hourBuckets.length; i++) {
      if (this.stats.hourBuckets[i] > max) {
        max = this.stats.hourBuckets[i];
      }
    }
    if (max <= 0) {
      return 2;
    }
    return Math.max(2, Math.round(count * 86 / max));
  }

  /** 峰值小时（用于给柱子高亮）。 */
  private peakHour(): number {
    let best: number = 0;
    let bestCount: number = -1;
    for (let i: number = 0; i < this.stats.hourBuckets.length; i++) {
      if (this.stats.hourBuckets[i] > bestCount) {
        bestCount = this.stats.hourBuckets[i];
        best = i;
      }
    }
    return best;
  }

  /** 日历格颜色：0 次最深，次数越多越亮。 */
  private dayColor(count: number): string {
    if (count <= 0) {
      return '#14FFFFFF';
    }
    if (count === 1) {
      return '#4DFF3B6B';
    }
    if (count === 2) {
      return '#99FF3B6B';
    }
    return '#FFFF3B6B';
  }
}