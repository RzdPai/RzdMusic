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
 *     所以完播率按**曲目占比**给出（本月听过的歌里，播过 ≥2 次的比例），并在页面上写明口径。
 *
 * 动态背景（用户描述）：滑到「最常听的歌手」那一段的过程中，背景从纯黑**渐变为该歌手图片的取色**，
 * 离开该段再渐变回黑。这里的"取色"用的是**同一张图的高斯模糊 + 低透明度**（等效取色的观感，
 * 且不依赖 PixelMap 解码链路，稳）；`backdropOpacity` 由 `onVisibleAreaChange` 驱动。
 */

import { AppStorageKeys, BarScrollHelper, MusicAppState, MusicStoreService, PageTopInsetHelper, PlayedSongRecord } from 'musicbasic';
import { AppStorageV2, uiObserver } from '@kit.ArkUI';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';

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
    let prevSeconds: number = 0;
    for (let i: number = 0; i < all.length; i++) {
      const r: PlayedSongRecord = all[i];
      const key: string = r.source + '|' + r.songId;
      const prevSeen: number | undefined = firstSeen.get(key);
      if (prevSeen === undefined || r.time < prevSeen) {
        firstSeen.set(key, r.time);
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
      const key: string = r.source + '|' + r.songId;
      if ((firstSeen.get(key) ?? 0) >= range.start) {
        brandNew++;
      }
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
        // ★ 用户 2026-10-12：「常听的歌参考首页现在就听的**侧翼**，你这就光旋转了图片」
        //   ⇒ 照搬首页 `NowPlayingCard` 的构造：封面两侧各一片 `CoverWing`（等腰梯形），
        //     用**负 margin** 让封面压住侧翼内缘，层次靠 `zIndex`（不靠声明顺序）。
        Row() {
          if (this.stats.topSongs.length > 1) {
            this.SongCover(this.stats.topSongs[1], '2nd')
          }
          this.SongCover(this.stats.topSongs[0], '1st')
          if (this.stats.topSongs.length > 2) {
            this.SongCover(this.stats.topSongs[2], '3rd')
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 一个名次：封面 + 名次/歌名/次数三段文字。
   *
   * 第 1 名：方卡、不形变，`zIndex(2)` 压住两侧；第 2/3 名：Y 轴 3D 倾斜（`rotate({y:1})`）
   * 成透视梯形，并由中间那张盖住一部分（负 margin 加在中间那张上，加两侧会把它们顶出屏）。
   * @param item 名次数据
   * @param rank `1st` / `2nd` / `3rd`
   */

  @Builder
  private SongCover(item: EchoTopSong, rank: string) {
    Column({ space: 6 }) {
      Row() {

        if (item.img.length > 0) {
          Image(item.img)
            .width(rank === '1st' ? 150 : 110)
            .height(rank === '1st' ? 150 : 110)
            .borderRadius(rank === '1st' ? 13 : 9)
            .objectFit(ImageFit.Cover)
            .zIndex(rank === '1st' ? 2 : 1)
        } else {
          Column()
            .width(rank === '1st' ? 150 : 110)
            .height(rank === '1st' ? 150 : 110)
            .borderRadius(rank === '1st' ? 13 : 9)
            .backgroundColor('#22FFFFFF')
            .zIndex(1)
        }

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
    .layoutWeight(rank === '1st' ? 2 : 1)
    .alignItems(HorizontalAlign.Center)
    // ★★ 2026-10-13（另一软件作者给的官方做法）：「把**文字和图片放到一个 Column 里，然后对 Column 做旋转**，
    //   文字就自动跟着旋转了」⇒ 旋转加在**整个 Column** 上（图片 + 名次/歌名/次数三段文字一起斜）。
    // GLM5.3 补充的两条关键参数（我此前完全没设，所以怎么也调不对）：
    //   ① `centerX` 锚在**外侧边**（左侧卡锚 0、右侧卡锚 '100%'）⇒ 外侧竖边保持满高且竖直；
    //   ② `centerY: '120%'` 把**透视中心压到卡片下方** ⇒ 上边斜得多、下边斜得少（实测 70/30）；
    //      不设的话透视中心居中，上下边对称各 50%。
    // `perspective` ≈ 观察距离（越小透视越强）：110vp 的卡片取 90（200 弱到看不出、55 会过头）。
    .rotate({
      y: 1,
      angle: rank === '1st' ? 0 : (rank === '2nd' ? 24 : -24),
      perspective: 90,
      centerX: rank === '1st' ? '50%' : (rank === '2nd' ? 0 : '100%'),
      centerY: '120%'
    })
    // ★★ 2026-10-13：负 margin 要加在**中间那张**上（左右各 -46），由它去盖住两侧。
    //   加在两侧会把它们顶出屏幕（左卡被屏幕左缘裁掉、右卡超出）⇒ 看着就像被裁一半的平行四边形。
    .margin({ left: rank === '1st' ? -46 : 0, right: rank === '1st' ? -46 : 0 })
    // 中间那张要在最上层，才能压住左右两侧的内边（zIndex 必须给容器，不只给 Image）
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
        .fontColor('#99FFFFFF')
        .width('100%')
        .textAlign(TextAlign.Start)
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

  /** 完播率（口径写在页面上，见文件头）。 */
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
          Text('重复播放 ' + this.stats.completeCount + ' 首 · 只听一次 ' + this.stats.halfCount + ' 首')
            .fontSize(12)
            .fontColor('#99FFFFFF')
            .width('100%')
            .textAlign(TextAlign.Start)
          Text('（口径：本月听过的歌里播过 ≥2 次的占比）')
            .fontSize(11)
            .fontColor('#77FFFFFF')
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
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
        '其中 ' + this.stats.newSongCount + ' 首是这个月才第一次听的' : '这个月还没有听得上的歌')
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