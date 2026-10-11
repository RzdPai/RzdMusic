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

import { AppStorageV2, LengthMetrics, uiObserver } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { BusinessError } from '@kit.BasicServicesKit';
import { guardPlayerBack } from 'musicbasic';
import { AlbumRouteParam, AmbientState, AppStorageKeys, ArtistRouteParam, BreakpointType, MusicAppState, MusicStoreService, PlayedSongRecord, RouterUrlConstants, ThemeState, TitleBarConstants, buildTitleMaterial, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AlbumInfo, AlbumDetailResult, ArtistInfo, ColorConversion, LXSearchSong, OnlinePlayUtil, SearchPageResult,
  SingerInfo, SongInfo, SongPageResult, ArtistAlbumPageResult, searchSingers, getArtistDetail, getArtistSongs,
  getArtistAlbums, getAlbumDetail, codeToSource, showSystemShare, buildSongShareText
} from 'player';
import { FavoriteEntry } from 'musicbasic';
import { SongMoreMenu } from 'playlist';
import { CapsuleSegmentedSelector } from './CapsuleSegmentedSelector';
import { DetailImmersiveBackdrop } from './DetailImmersiveBackdrop';
import { WindowInfo, getWindowInfoState } from 'musicbasic';
import { ArtistDetailDataSource } from './ArtistDetailDataSource';

const DANGER_COLOR: string = '#E64545';
const SONG_PAGE_LIMIT: number = 50;
const ALBUM_PAGE_LIMIT: number = 50;

/**
 * ★ 双胞胎常量：`DetailImmersiveBackdrop` 的 `heroHeightVp` / `rowHeightVp` 默认值
 * （本页没有覆写这两个 `@Param`，所以照片画框 = 320 + 56 + 状态栏避让）。
 * 只有算「状态栏那一条在照片里对应哪一块」时才用得到；改那两处默认值时必须同步这里。
 */
const BACKDROP_HERO_VP: number = 320;
const BACKDROP_ROW_VP: number = 56;

/** 秒数 → mm:ss 时长文本。 */
function formatInterval(seconds: number): string {
  let s: number = Math.max(0, Math.floor(seconds));
  const m: number = Math.floor(s / 60);
  s = s % 60;
  const ss: string = s < 10 ? '0' + s : String(s);
  return m + ':' + ss;
}

/**
 * 取色器给的通道值（0–255）→ `rgb(r, g, b)`。
 *
 * ⚠️ **不经过 `ColorConversion.dealColor`**：那个函数是给"深底白字"页面底色设计的，
 * 亮度上限锁死在 0.3（约 RGB 76）⇒ 结果永远是深色，拿它判"背景亮不亮"必然判成"暗"。
 * 判状态栏前景色必须用**照片本身的原始亮度**（状态栏那一条压的就是原始照片）。
 */
function toRgbString(red: number, green: number, blue: number): string {
  const r: number = Math.max(0, Math.min(255, Math.round(red)));
  const g: number = Math.max(0, Math.min(255, Math.round(green)));
  const b: number = Math.max(0, Math.min(255, Math.round(blue)));
  return `rgb(${r}, ${g}, ${b})`;
}

/**
 * 歌手详情页：顶部大图 + 取色背景 + 渐变没入背景；标题栏仅三枚按钮（返回/分享/更多）；
 * 图片底部上方为大播放按钮（播放全部）、左侧关于（占位）、右侧收藏（添加到以歌手名命名的歌单）；
 * 播放按钮上方以较大字体显示歌手名；图片下方为歌曲/专辑列表。
 */
@ComponentV2
export struct ArtistDetailPage {
  /** Window breakpoint for responsive paddings. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Param source: number = 2;
  @Param artistId: string = '';
  @Param artistMid: string = '';
  @Param artistName: string = '';
  @Param artistPicUrl: string = '';
  @Param albumSize: number = 0;
  @Param songNum: number = 0;
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  @Local songs: SongInfo[] = [];
  @Local albums: AlbumInfo[] = [];
  @Local activeTab: number = 1;
  @Local segmentIndex: number = 0;
  @Local loading: boolean = false;
  @Local loadingMore: boolean = false;
  @Local songsHasMore: boolean = true;
  @Local albumsHasMore: boolean = true;
  @Local songPage: number = 1;
  @Local albumPage: number = 1;
  @Local songSort: number = 0;
  @Local artistNameText: string = '';
  @Local artistPicUrlText: string = '';
  @Local effectiveArtistId: string = '';
  @Local effectiveArtistMid: string = '';
  @Local errorMsg: string = '';
  @Local avgColor: string = '#1f1f22';
  /**
   * ★ 状态栏判据用的**原始色**（不压暗），只在取色回调里写：
   *  * `photoTopColor`：照片里**真正压在状态栏那一条下面**的那块区域的平均色 —— 滚动前的判据；
   *  * `photoRawAvgColor`：整张照片的原始平均色 —— 区域取色失败时的兜底判据。
   * 空串 = 还没有照片像素（首帧 / 没图 / 失败），此时判据退回 `avgColor`。
   */
  @Local photoTopColor: string = '';
  @Local photoRawAvgColor: string = '';
  /** 上一次打过的状态栏判据日志（内容相同就不再刷）。 */
  private lastStatusBarLog: string = '';
  @Local imageFailed: boolean = false;
  @Local isFavoriteArtist: boolean = false;
  @Local artistDesc: string = '';
  @Local showAboutPopup: boolean = false;
  @Local windowInfo: WindowInfo = getWindowInfoState();
  @Local detailScrollVp: number = 0;
  private lastScrollBand: number = -1;
  private scroller: Scroller = new Scroller();

  private updateImmersiveScroll(): void {
    this.detailScrollVp = Math.max(0, this.scroller.currentOffset().yOffset);
    const band: number = Math.floor(this.detailScrollVp / 56);
    if (band !== this.lastScrollBand) {
      this.lastScrollBand = band;
      hilog.info(0, 'RzdDetailImmersive', 'artist scrollVp=%{public}f thresholdVp=264 avoidTopVp=%{public}f',
        this.detailScrollVp, this.windowInfo.statusBarTopVp);
    }
  }

  /**
   * 页内可用高度（vp）= 窗口高 − 状态栏避让。
   *
   * 为什么照片层要这个数值而不是自己写 `'100%'` / `LayoutPolicy.matchParent`：
   * 它挂在内容驱动的 Stack 里，百分比 / matchParent 会在首帧量成 0 高 ⇒ 照片整张不画
   * （用户报的"歌手页顶部是纯色不是照片"）。这里由页面把确定值传下去。
   * @returns 高度（vp）；窗口尺寸还没量到时返回 0，调用方按"不画照片"处理。
   */
  private pageContentHeightVp(): number {
    const hPx: number = this.windowInfo.windowSize.height;
    if (hPx <= 0) {
      return 0;
    }
    return Math.max(0, this.getUIContext().px2vp(hPx) - this.windowInfo.statusBarTopVp);
  }
  private songData: ArtistDetailDataSource<SongInfo> = new ArtistDetailDataSource<SongInfo>();
  private albumData: ArtistDetailDataSource<AlbumInfo> = new ArtistDetailDataSource<AlbumInfo>();
  private songGeneration: number = 0;
  private albumGeneration: number = 0;
  private pageAlive: boolean = false;
  @Local albumsLoading: boolean = false;

  @Monitor('songs')
  onSongsChanged(): void {
    this.songData.reload(this.songs);
  }

  @Monitor('albums')
  onAlbumsChanged(): void {
    this.albumData.reload(this.albums);
  }

  aboutToDisappear(): void {
    this.pageAlive = false;
    this.songGeneration++;
    this.albumGeneration++;
    hilog.info(0, 'RzdArtistSticky', 'cancel page requests gen=%{public}d', this.songGeneration);
  }

  aboutToAppear(): void {
    this.pageAlive = true;
    // ★ 状态栏前景色**不再**在这里用 window 接口预下发（原来的 preapplyStatusBarColor 已删）：
    //   官方《HdsNavigation》systemBarStyle 说明：「不建议混合使用 systemBarStyle 属性和 window 设置
    //   状态栏样式的相关接口，例如：setWindowSystemBarProperties。」且「当页面设置不同样式时，在页面
    //   转场开始时生效」⇒ 声明式的 `.systemBarStyle` 就是唯一真源，转场开始那一刻框架就该换色。
    //   这里只打一条进页判据（触发点 = entry），真机 grep RzdArtistStatusBar 就能对上。
    this.logStatusBarDecision('entry');
    const favSource: string = codeToSource(this.source);
    const favId: string = this.effectiveArtistId.length > 0 ? this.effectiveArtistId : this.effectiveArtistMid;
    this.isFavoriteArtist = favId.length > 0 && this.store.isFavoriteArtist(favSource, favId);
    hilog.info(0x0000, 'RzdArtistDetail', 'aboutToAppear: name=%{public}s source=%{public}d id=%{public}s',
      this.artistName, this.source, this.artistId);
    this.artistNameText = this.artistName;
    this.artistPicUrlText = this.artistPicUrl;
    this.effectiveArtistId = this.artistId;
    this.effectiveArtistMid = this.artistMid;
    void this.init();
  }

  private async init(): Promise<void> {
    if (this.effectiveArtistId.length === 0 && this.artistNameText.length > 0) {
      await this.resolveSingerBySearch();
    }
    if (this.artistPicUrlText.length > 0) {
      void this.loadBackdropColor();
    }
    await this.loadAlbums(1);
    void this.loadArtistDesc();
  }

  private async loadArtistDesc(): Promise<void> {
    try {
      const info: ArtistInfo = await getArtistDetail(this.source, this.effectiveArtistId, this.effectiveArtistMid);
      if (info.briefDesc.length > 0) {
        this.artistDesc = info.briefDesc;
      }
    } catch (_err) {
      // ignore
    }
  }

  @Builder
  private AboutPopup() {
    Column() {
      Text(this.artistNameText.length > 0 ? this.artistNameText : '歌手')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.fgPrimary())
        .width('100%')
        .textAlign(TextAlign.Center)
      if (this.artistDesc.length > 0) {
        Scroll() {
          Text(this.artistDesc)
            .fontSize(13)
            .fontColor('#D9FFFFFF')
            .width('100%')
            .lineHeight(20)
        }
        .height(180)
        .margin({ top: 10 })
        .scrollBar(BarState.Off)
      } else {
        Text('暂无歌手简介')
          .fontSize(13)
          .fontColor('#99FFFFFF')
          .margin({ top: 10 })
      }
    }
    .padding(16)
    .width(300)
  }

  private async resolveSingerBySearch(): Promise<void> {
    try {
      const result: SearchPageResult<SingerInfo> = await searchSingers(this.source, this.artistNameText, 1);
      if (result.list.length > 0) {
        const first: SingerInfo = result.list[0];
        this.effectiveArtistId = first.id;
        this.effectiveArtistMid = '';
        this.artistPicUrlText = first.picUrl.length > 0 ? first.picUrl : this.artistPicUrlText;
        if (this.artistPicUrlText.length > 0) {
          void this.loadBackdropColor();
        }
      }
    } catch (_err) {
      // 搜不到时保留空 id：详情/歌曲接口会退化为空结果
    }
  }

  /**
   * 下载歌手图片，取两个颜色：
   *  * `avgColor`：全图主色经 `ColorConversion.dealColor` 压暗 —— 页面渐变底、文字、标题栏底色都用它（行为不变）；
   *  * `photoRawAvgColor` + `photoTopColor`：**原始**（不压暗）平均色，只给状态栏判据用（见 {@link statusBarOriginalColor}）。
   */
  private async loadBackdropColor(): Promise<void> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(this.artistPicUrlText, {
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
                    const arr: number[] = ColorConversion.dealColor(color.red, color.green, color.blue);
                    const r: number = Math.max(0, Math.min(255, arr[0]));
                    const g: number = Math.max(0, Math.min(255, arr[1]));
                    const b: number = Math.max(0, Math.min(255, arr[2]));
                    this.avgColor = `rgb(${r}, ${g}, ${b})`;
                    this.cachedTitleBar = undefined;
                    // ★ 同一个 picker 顺手取「原始平均色」当兜底判据（不压暗，见 toRgbString 的说明）。
                    const raw: effectKit.Color = colorPicker.getAverageColor();
                    this.photoRawAvgColor = toRgbString(raw.red, raw.green, raw.blue);
                  }
                } finally {
                  resolve();
                }
              });
          });
          this.logStatusBarDecision('avg-sample');
        } finally {
          try {
            pixelMap.release();
          } catch (_err) {
            // ignore
          }
        }
        await this.loadStatusBarStripColor(src);
      } finally {
        src.release();
      }
    } catch (_err) {
      // 取色失败保留默认背景
    } finally {
      req.destroy();
    }
  }

  /**
   * 只解出「状态栏那一条压在照片上的区域」并取它的平均色 → `photoTopColor`。
   *
   * 为什么必须按区域取，而不是拿全图主色/全图平均色凑合：
   * 状态栏是**半透明图标压在照片最上面一条**上，判"图标该黑还是该白"只能看**那一条**的亮度。
   * 全图主色（`getLargestProportionColor`）表达的是"照片里占比最大的颜色"，跟顶部那一条可以
   * 完全不搭（例：白天空的歌手照 → 主色是深色衣服 ⇒ 判成白图标 ⇒ 压在浅色天空上什么都看不见）。
   *
   * 区域按照片在屏幕上的**实际显示方式**反推（照片层是 `ImageFit.Cover`、竖向居中裁剪）：
   *   画框 = 宽 × (Hero 320 + 标题栏行 56 + 状态栏避让)vp，状态栏那一条 = 画框顶部 bandVp。
   * 取不到（解码不支持区域 / 尺寸还没量到）就返回，判据退回 `photoRawAvgColor` → `avgColor`。
   * @param src 已经创建好的图片源（本方法内只做一次小区域解码）。
   */
  private async loadStatusBarStripColor(src: image.ImageSource): Promise<void> {
    try {
      const info: image.ImageInfo = await src.getImageInfo();
      const region: image.Region | undefined = this.statusBarStripRegion(info.size.width, info.size.height);
      if (region === undefined) {
        return;
      }
      const stripSize: image.Size = {
        width: Math.max(1, Math.round(region.size.width / 4)),
        height: Math.max(1, Math.round(region.size.height / 4))
      };
      const opts: image.DecodingOptions = {
        desiredRegion: region,
        desiredSize: stripSize,
        cropAndScaleStrategy: image.CropAndScaleStrategy.CROP_FIRST
      };
      hilog.info(0x0000, 'RzdArtistStatusBar',
        'strip region x=%{public}d y=%{public}d w=%{public}d h=%{public}d imgW=%{public}d imgH=%{public}d avoidVp=%{public}f',
        region.x, region.y, region.size.width, region.size.height, info.size.width, info.size.height,
        this.windowInfo.statusBarTopVp);
      const strip: image.PixelMap = await src.createPixelMap(opts);
      try {
        await new Promise<void>((resolve: () => void) => {
          effectKit.createColorPicker(strip,
            (error: Error | undefined, colorPicker: effectKit.ColorPicker | undefined) => {
              try {
                if (error === undefined && colorPicker !== undefined) {
                  const raw: effectKit.Color = colorPicker.getAverageColor();
                  this.photoTopColor = toRgbString(raw.red, raw.green, raw.blue);
                }
              } finally {
                resolve();
              }
            });
        });
      } finally {
        try {
          strip.release();
        } catch (_err) {
          // ignore
        }
      }
      this.logStatusBarDecision('strip-sample');
    } catch (_err) {
      // 区域解码失败：判据退回整图原始平均色（loadBackdropColor 里已经取到）
      hilog.warn(0x0000, 'RzdArtistStatusBar', 'strip sample failed, fallback to whole-image average');
    }
  }

  /**
   * 状态栏那一条在**源图**里对应哪一块（`ImageFit.Cover` + 竖向居中裁剪的逆运算）。
   * @param imgW 源图宽（px）。
   * @param imgH 源图高（px）。
   * @returns 区域；窗口尺寸/避让高度还没量到（=0）时返回 undefined。
   */
  private statusBarStripRegion(imgW: number, imgH: number): image.Region | undefined {
    const bandVp: number = this.windowInfo.statusBarTopVp;
    const boxWvp: number = this.getUIContext().px2vp(this.windowInfo.windowSize.width);
    const boxHvp: number = BACKDROP_HERO_VP + BACKDROP_ROW_VP + bandVp;
    if (bandVp <= 0 || boxWvp <= 0 || boxHvp <= 0 || imgW <= 0 || imgH <= 0) {
      return undefined;
    }
    // vp/px：Cover 取长边比例，画框一定被铺满，多出来的方向居中裁掉
    const scaleVpPerPx: number = Math.max(boxWvp / imgW, boxHvp / imgH);
    if (!Number.isFinite(scaleVpPerPx) || scaleVpPerPx <= 0) {
      return undefined;
    }
    const cropTopVp: number = Math.max(0, (imgH * scaleVpPerPx - boxHvp) / 2);
    const y0: number = Math.max(0, Math.min(imgH - 1, Math.floor(cropTopVp / scaleVpPerPx)));
    const y1: number = Math.max(y0 + 1, Math.min(imgH, Math.ceil((cropTopVp + bandVp) / scaleVpPerPx)));
    const region: image.Region = {
      x: 0,
      y: y0,
      size: { width: imgW, height: y1 - y0 }
    };
    return region;
  }

  private async loadSongs(page: number, reset: boolean): Promise<void> {
    if (!this.pageAlive || (!reset && (this.loading || this.loadingMore))) {
      return;
    }
    const generation: number = reset ? ++this.songGeneration : this.songGeneration;
    const identity: string = this.effectiveArtistId + ':' + this.effectiveArtistMid;
    const sort: number = this.songSort;
    if (reset) {
      this.loadingMore = false;
      this.errorMsg = '';
    }
    hilog.info(0, 'RzdArtistSticky', 'songs start gen=%{public}d sort=%{public}d page=%{public}d',
      generation, sort, page);
    if (reset) {
      this.loading = true;
    } else {
      this.loadingMore = true;
    }
    try {
      const offset: number = (page - 1) * SONG_PAGE_LIMIT;
      const order: string = this.songSort === 0 ? 'hot' : 'time';
      const result: SongPageResult = await getArtistSongs(this.source, this.effectiveArtistId, this.effectiveArtistMid,
        order, SONG_PAGE_LIMIT, offset, this.artistNameText);
      if (!this.pageAlive || generation !== this.songGeneration || sort !== this.songSort ||
        identity !== this.effectiveArtistId + ':' + this.effectiveArtistMid) {
        hilog.info(0, 'RzdArtistSticky', 'songs stale/cancel gen=%{public}d', generation);
        return;
      }
      if (result.list.length === 0) {
        this.songsHasMore = false;
        return;
      }
      this.songs = reset ? result.list : this.songs.concat(result.list);
      this.songsHasMore = result.hasMore;
      this.songPage = page + 1;
      if (this.artistNameText.length === 0 && this.songs.length > 0) {
        this.artistNameText = this.songs[0].singer.length > 0 ? this.songs[0].singer : this.artistNameText;
      }
      hilog.info(0, 'RzdArtistSticky', 'songs ready gen=%{public}d loaded=%{public}d more=%{public}d',
        generation, this.songs.length, this.songsHasMore ? 1 : 0);
    } catch (err) {
      if (this.pageAlive && generation === this.songGeneration) {
        const e: Error = err as Error;
        this.errorMsg = e.message ?? '加载失败';
        this.songsHasMore = false;
      }
    } finally {
      if (this.pageAlive && generation === this.songGeneration) {
        this.loading = false;
        this.loadingMore = false;
      }
    }
  }

  private async loadAlbums(page: number): Promise<void> {
    if (!this.pageAlive || this.albumsLoading) {
      return;
    }
    this.albumsLoading = true;
    const generation: number = ++this.albumGeneration;
    const identity: string = this.effectiveArtistId + ':' + this.effectiveArtistMid;
    try {
      const offset: number = (page - 1) * ALBUM_PAGE_LIMIT;
      const result: ArtistAlbumPageResult = await getArtistAlbums(this.source, this.effectiveArtistId, this.effectiveArtistMid,
        ALBUM_PAGE_LIMIT, offset);
      if (!this.pageAlive || generation !== this.albumGeneration ||
        identity !== this.effectiveArtistId + ':' + this.effectiveArtistMid) {
        hilog.info(0, 'RzdArtistSticky', 'albums stale/cancel gen=%{public}d', generation);
        return;
      }
      if (result.list.length === 0) {
        this.albumsHasMore = false;
        return;
      }
      for (let i: number = 0; i < result.list.length; i++) {
        if (result.list[i].artistName.length === 0) {
          result.list[i].artistName = this.artistNameText;
        }
      }
      this.albums = page === 1 ? result.list : this.albums.concat(result.list);
      this.albumsHasMore = result.hasMore;
      this.albumPage = page + 1;
    } catch (_err) {
      if (this.pageAlive && generation === this.albumGeneration) {
        this.albumsHasMore = false;
      }
    } finally {
      if (this.pageAlive && generation === this.albumGeneration) {
        this.albumsLoading = false;
      }
    }
  }

  private switchTab(tab: number): void {
    if (tab === this.activeTab) {
      return;
    }
    this.activeTab = tab;
    if (tab === 0 && this.songs.length === 0) {
      void this.loadSongs(1, true);
    } else if (tab === 1 && this.albums.length === 0) {
      void this.loadAlbums(1);
    }
  }

  /** 三块分段：0=专辑，1=最新，2=最热。 */
  private onSegmentSelect(index: number): void {
    this.segmentIndex = index;
    if (index === 0) {
      this.activeTab = 1;
      if (this.albums.length === 0) {
        void this.loadAlbums(1);
      }
      return;
    }
    const sort: number = index === 1 ? 1 : 0;
    const needReload: boolean = this.activeTab !== 0 || this.songSort !== sort || this.songs.length === 0;
    this.activeTab = 0;
    this.songSort = sort;
    if (needReload) {
      this.songs = [];
      this.songPage = 1;
      this.songsHasMore = true;
      void this.loadSongs(1, true);
    }
  }

  private switchSort(sort: number): void {
    if (sort === this.songSort) {
      return;
    }
    this.songSort = sort;
    this.songs = [];
    this.songPage = 1;
    this.songsHasMore = true;
    void this.loadSongs(1, true);
  }

  private loadMore(): void {
    if (this.activeTab === 0) {
      if (this.songsHasMore && !this.loading && !this.loadingMore) {
        void this.loadSongs(this.songPage, false);
      }
    } else {
      if (this.albumsHasMore) {
        void this.loadAlbums(this.albumPage);
      }
    }
  }

  /** 歌手歌曲 → 可播放的 LXSearchSong。 */
  private toPlayable(song: SongInfo): LXSearchSong {
    return {
      songId: song.id,
      name: song.name,
      singer: song.singer,
      albumName: song.albumName,
      albumId: '',
      source: codeToSource(this.source),
      interval: formatInterval(song.interval),
      img: this.artistPicUrlText,
      types: []
    };
  }

  /** HDS 光感磨砂强度：跟随环境光等级。 */
  private buttonBlur(): BlurStyle {
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

  /**
   * 颜色亮不亮 —— **全页唯一判据**（`#RRGGBB` 与 `rgb(r, g, b)` 都认；认不出来按"暗"处理）。
   * 页面文字/图标、标题栏图标、状态栏前景色全部走它，谁都不许另写一套。
   */
  private isLightColor(c: string): boolean {
    let r: number = -1;
    let g: number = -1;
    let b: number = -1;
    if (c.startsWith('rgb')) {
      const inner: string = c.substring(c.indexOf('(') + 1, c.indexOf(')'));
      const parts: string[] = inner.split(',');
      if (parts.length >= 3) {
        r = parseInt(parts[0].trim(), 10);
        g = parseInt(parts[1].trim(), 10);
        b = parseInt(parts[2].trim(), 10);
      }
    } else if (c.length === 7 && c.charAt(0) === '#') {
      r = parseInt(c.substring(1, 3), 16);
      g = parseInt(c.substring(3, 5), 16);
      b = parseInt(c.substring(5, 7), 16);
    }
    if (r < 0 || g < 0 || b < 0 || Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
      return false;
    }
    return (0.299 * r + 0.587 * g + 0.114 * b) > 150;
  }

  /**
   * 取色背景是否偏浅 —— 判的是**页面正文的背景**。
   *
   * ⚠️ `avgColor` 是 `ColorConversion.dealColor` 压暗过的（亮度上限 0.3），所以这里几乎恒为 false
   * ⇒ 页面文字/图标恒用白色。**这是对的**：正文压在的就是这块压暗底色本身（见 `HdsNavDestination
   * .backgroundColor(this.avgColor)` + 照片层的渐变遮罩底部色）。
   * ★ 但**不能拿它当状态栏的判据** —— 状态栏那一条压的是**原始照片**，不是这块压暗底色。
   */
  private isLightBackdrop(): boolean {
    return this.isLightColor(this.avgColor);
  }

  /**
   * 滚动前压在状态栏那一条下面的颜色 = 照片顶部那一条的原始平均色。
   * 没有照片像素时（首帧 / 没图 / 取色失败）退回 `photoRawAvgColor` → `avgColor`：
   * 那两个时刻状态栏那一条确实是页面自己的底色（照片层顶部是 `Color.Transparent`，压不出东西来）。
   */
  private statusBarOriginalBackground(): string {
    if (this.photoTopColor.length > 0) {
      return this.photoTopColor;
    }
    if (this.photoRawAvgColor.length > 0) {
      return this.photoRawAvgColor;
    }
    return this.avgColor;
  }

  /**
   * `.systemBarStyle` 的**第一个**参数（官方：`originalStyle` = 「系统状态栏**初始**样式」）。
   *
   * 三种状态分别该是什么色（对应官方 HdsNavDestination.systemBarStyle 的语义）：
   *   ① 首帧 / 没图 / 取色失败：状态栏那一条 = 页面自己的底色 `avgColor`（压暗深色）⇒ 白图标；
   *   ② 照片就位（未滚动，滚动 < 264vp）：那一条压的是**照片顶部**⇒ 由照片顶部原始亮度算，浅色照片给黑图标；
   *   ③ 滚动过 264vp（动态档）：见 {@link statusBarScrollEffectColor}。
   * 官方：「未设置 systemBarStyle 属性时，颜色默认值同主标题栏字体颜色」—— 我们显式给，判据一律由背景算出。
   */
  private statusBarOriginalColor(): string {
    return this.isLightColor(this.statusBarOriginalBackground()) ? '#000000' : '#FFFFFF';
  }

  /**
   * `.systemBarStyle` 的**第二个**参数（官方：`scrollEffectStyle` = 「动态样式生效后，系统状态栏对应的
   * **最终**动态样式」）。
   *
   * ⚠️ 官方说的是"**最终**"：动态档的终点是照片完全上移出状态栏（照片画框 376vp+避让，滚动超过它就没照片了），
   * 那时那一条压的是「页面压暗底色」本身（也正是滚动档标题栏 `scrollEffectStyle.backgroundStyle.backgroundColor`
   * 用的 `avgColor`）⇒ 判据取 `avgColor`。
   * 动态档切换点是 264vp，此时照片还剩一小截 ⇒ 理论上有一小段（264vp ~ 照片画框高）照片与判据不完全同步；
   * **这一点是有意取的保守值**：若改成用照片色，越过照片画框后就会变成"黑图标压深底"（更差）。
   * 与第一个参数**必须分开算**：把同一个值塞给两个参数，等于承认两种状态里必有一种是错的。
   */
  private statusBarScrollEffectColor(): string {
    return this.isLightColor(this.avgColor) ? '#000000' : '#FFFFFF';
  }

  /**
   * 状态栏判据日志：打出**下发值 + 判据来源 + 触发点**（真机 `grep RzdArtistStatusBar`）。
   * 内容没变就不打，避免 build 每帧刷屏。
   * @param trigger 触发点：entry（进页）/ avg-sample（主色回来）/ strip-sample（顶部条回来）/ pic-url（照片地址变化）
   */
  private logStatusBarDecision(trigger: string): void {
    const original: string = this.statusBarOriginalColor();
    const scrolled: string = this.statusBarScrollEffectColor();
    const strip: string = this.photoTopColor.length > 0 ? this.photoTopColor : '(none)';
    const rawAvg: string = this.photoRawAvgColor.length > 0 ? this.photoRawAvgColor : '(none)';
    const line: string = trigger + '|' + original + '|' + scrolled + '|' + strip + '|' + rawAvg + '|' + this.avgColor;
    if (line === this.lastStatusBarLog) {
      return;
    }
    this.lastStatusBarLog = line;
    hilog.info(0x0000, 'RzdArtistStatusBar',
      'trigger=%{public}s original=%{public}s scrollEffect=%{public}s strip=%{public}s rawAvg=%{public}s avgColor=%{public}s',
      trigger, original, scrolled, strip, rawAvg, this.avgColor);
  }

  /** 标题栏返回/菜单按钮的半透明底色。 */
  private fgTitleIconBg(): string {
    return this.isLightBackdrop() ? '#1A000000' : '#1AFFFFFF';
  }

  /** 主文字颜色：浅色背景用深字，深色背景用白字。 */
  private fgPrimary(): string {
    return this.isLightBackdrop() ? '#E6000000' : '#FFFFFF';
  }

  /** 取色回来（avgColor 变化）⇒ 标题栏图标色与滚动档底色都是它推出来的，缓存必须作废。 */
  @Monitor('avgColor')
  onAvgColorChanged(): void {
    this.cachedTitleBar = undefined;
  }

  /**
   * 歌手照片地址到手（`resolveSingerBySearch()` 搜到 / 路由带进来晚了一拍）时重下发一次判据。
   *
   * 理由：`photoTopColor` 只在**取到色**之后才有值，而取色的输入是照片地址；地址本身可能是异步才有的。
   * ⚠️ 这里**只**更新判据状态（`@Local`）让 `.systemBarStyle` 重新求值，不再走
   * `WindowUtil.setWindowSystemBarProperties`（官方明确不建议两套混用，见 aboutToAppear 的注释）。
   */
  @Monitor('artistPicUrlText')
  onArtistPicUrlChanged(): void {
    // 标题栏缓存里存的是构建那一刻的 avgColor 快照，照片换了要让它重建。
    this.cachedTitleBar = undefined;
    this.logStatusBarDecision('pic-url');
  }

  /** 顶部条取色回来：`.systemBarStyle` 的第一个参数会在这次状态变更后重新求值。 */
  @Monitor('photoTopColor')
  onPhotoTopColorChanged(): void {
    this.logStatusBarDecision('strip-applied');
  }

  /** 次要文字颜色。 */
  private fgSecondary(): string {
    return this.isLightBackdrop() ? '#99000000' : '#B3FFFFFF';
  }

  /** 半透明按钮/行背景色。 */
  private fgTint(): string {
    return this.isLightBackdrop() ? '#1A000000' : '#33FFFFFF';
  }

  /** 分隔线颜色。 */
  private fgDivider(): string {
    return this.isLightBackdrop() ? '#1F000000' : '#26FFFFFF';
  }

  private playSong(song: SongInfo): void {
    void OnlinePlayUtil.playSearchSong(this.appState, this.toPlayable(song), this.getUIContext());
  }

  private playAll(): void {
    if (!this.pageAlive || this.activeTab !== 0 || this.loading || this.songs.length === 0) {
      return;
    }
    const list: LXSearchSong[] = [];
    for (let i: number = 0; i < this.songs.length; i++) {
      list.push(this.toPlayable(this.songs[i]));
    }
    const generation: number = this.songGeneration;
    const sort: number = this.songSort;
    hilog.info(0, 'RzdArtistSticky', 'playall dispatch gen=%{public}d sort=%{public}d readyLoaded=%{public}d more=%{public}d',
      generation, sort, list.length, this.songsHasMore ? 1 : 0);
    void OnlinePlayUtil.playList(this.appState, list, 0, this.getUIContext()).then((accepted: boolean): void => {
      if (!this.pageAlive || generation !== this.songGeneration || sort !== this.songSort) {
        hilog.info(0, 'RzdArtistSticky', 'playall completion canceled gen=%{public}d', generation);
        return;
      }
      hilog.info(0, 'RzdArtistSticky', 'playall accepted=%{public}d gen=%{public}d count=%{public}d',
        accepted ? 1 : 0, generation, list.length);
    });
  }

  /** 收藏：把歌手歌曲加入以歌手名命名的歌单（不存在则创建）。 */
  /** Toggles the artist favorite entry (no playlist is created). */
  private toggleFavoriteArtist(): void {
    const sourceId: string = codeToSource(this.source);
    const id: string = this.effectiveArtistId.length > 0 ? this.effectiveArtistId : this.effectiveArtistMid;
    if (id.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '歌手信息不完整，无法收藏', duration: 2000 });
      return;
    }
    if (this.store.isFavoriteArtist(sourceId, id)) {
      this.store.removeFavoriteArtist(sourceId, id);
      this.isFavoriteArtist = false;
      this.getUIContext().getPromptAction().showToast({ message: '已取消收藏', duration: 1800 });
      return;
    }
    const entry: FavoriteEntry = new FavoriteEntry();
    entry.id = id;
    entry.source = sourceId;
    entry.name = this.artistNameText.length > 0 ? this.artistNameText : this.artistName;
    entry.sub = '歌手';
    entry.img = this.artistPicUrl;
    entry.count = this.songs.length;
    entry.time = Date.now();
    this.store.addFavoriteArtist(entry);
    this.isFavoriteArtist = true;
    this.getUIContext().getPromptAction().showToast({ message: '已收藏歌手', duration: 1800 });
  }

  /** 拉取歌手全部歌曲（分页累加，最多 600 首）。 */
  private async collectAllSongs(): Promise<SongInfo[]> {
    const total: SongInfo[] = [];
    let page: number = 1;
    let hasMore: boolean = true;
    while (hasMore && total.length < 600 && page <= 12) {
      try {
        const offset: number = (page - 1) * SONG_PAGE_LIMIT;
        const result: SongPageResult = await getArtistSongs(this.source, this.effectiveArtistId, this.effectiveArtistMid,
          'hot', SONG_PAGE_LIMIT, offset, this.artistNameText);
        if (result.list.length === 0) {
          hasMore = false;
          break;
        }
        for (let i: number = 0; i < result.list.length; i++) {
          total.push(result.list[i]);
        }
        hasMore = result.hasMore;
        page++;
      } catch (_err) {
        hasMore = false;
      }
    }
    return total;
  }

  private shareArtist(): void {
    if (this.artistNameText.length > 0) {
      showSystemShare(this.getUIContext(), buildSongShareText(this.artistNameText, '歌手', '', ''), '分享歌手');
    }
  }

  private goBack(): void {
    this.pageIndexInfos.pop();
  }

  /** 歌曲行：封面 + 歌名/歌手 + 时长 + 更多菜单。 */
  @Builder
  private SongRowView(item: SongInfo, index: number) {
    Row({ space: 10 }) {
      if (item.picUrl.length > 0) {
        Image(item.picUrl)
          .width(42)
          .height(42)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
      } else if (this.artistPicUrlText.length > 0 && !this.imageFailed) {
        Image(this.artistPicUrlText)
          .width(42)
          .height(42)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
      } else {
        Row() {
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(20)
            .fontWeight(FontWeight.Regular)
            .height(20)
            .fontColor(['#B3FFFFFF'])
        }
        .width(42)
        .height(42)
        .borderRadius(8)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#22FFFFFF')
      }
      Column({ space: 2 }) {
        Text(item.name)
          .fontSize(15)
          .fontColor(this.fgPrimary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.singer + (item.albumName.length > 0 ? ' · ' + item.albumName : ''))
          .fontSize(12)
          .fontColor(this.fgSecondary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (item.interval > 0) {
        Text(formatInterval(item.interval))
          .fontSize(12)
          .fontColor(this.fgSecondary())
      }

      SongMoreMenu({
        song: this.toPlayable(item),
        iconSize: 18,
        iconColor: '#B3FFFFFF'
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.playSong(item);
    })
  }

  /** 专辑行。 */
  @Builder
  private AlbumRowView(item: AlbumInfo) {
    Row({ space: 12 }) {
      Image(item.picUrl.length > 0 ? item.picUrl : this.artistPicUrlText.length > 0 ?
        this.artistPicUrlText : $r('app.media.ic_avatar1'))
        .width(56)
        .height(56)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
      Column({ space: 3 }) {
        Text(item.name)
          .fontSize(15)
          .fontColor(this.fgPrimary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.artistName.length > 0 ? item.artistName : this.artistNameText)
          .fontSize(12)
          .fontColor(this.fgSecondary())
          .maxLines(1)
        if (item.size > 0) {
          Text(`${item.size} 首`)
            .fontSize(12)
            .fontColor(this.fgSecondary())
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
        .height(18)
        .fontColor(['#B3FFFFFF'])
    }
    .width('100%')
    .height(72)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openAlbum(item);
    })
  }

  private openAlbum(item: AlbumInfo): void {
    const param = new AlbumRouteParam();
    param.source = this.source;
    param.id = item.id;
    param.mid = item.mid.length > 0 ? item.mid : '';
    param.name = item.name;
    param.picUrl = item.picUrl;
    param.artistName = item.artistName.length > 0 ? item.artistName : this.artistNameText;
    param.size = item.size;
    this.pageIndexInfos.pushPathByName(RouterUrlConstants.ALBUM_DETAIL, param);
  }

  /**
   * HDS 标题栏：返回 + 分享/更多三枚按钮（无标题文字）。
   *
   * ★ 沉浸光感（官方真实材质，不是自绘近似）：
   *   `style.systemMaterialEffect = buildTitleMaterial(ambientState.level)`
   *   走的是 HDS 的 `TitleBarStyleOptions.systemMaterialEffect`（`@since 6.1.0(23)`，
   *   本工程 default/pc 的 compatible 都 ≥ 23，可用）。
   *   为什么必须是它：官方《沉浸光感功耗优化》明确 ——
   *   「其他组件仅在 Navigation/NavDestination 标题栏或横向 Tabs 中 barPosition 为
   *     BarPosition.End 的底部 TabBar 中生效。在其他区域中设置沉浸光感效果不生效。」
   *   标题栏正是允许区域，所以只有挂在这里才是**系统的**光感。
   *
   * ★ 想看到材质，两件事必须同时成立（官方 FAQ《材质效果的显示层级问题》：
   *   「沉浸光感的视觉层级位于组件的 backgroundColor、backgroundBlurStyle 等属性之下」）：
   *   ① 不滚动时 `originalStyle.backgroundStyle.backgroundColor` 必须是 `Color.Transparent`
   *      —— 否则那块不透明底把材质整个盖住，看起来就是"一块纯色"；
   *   ② 标题栏上不要再叠 `backgroundBlurStyle` / `backgroundEffect`
   *      —— 材质自带模糊，叠加既是重复处理也会互相干扰。
   *   两者本页都满足：只有 `scrollEffectStyle`（滚过 264vp 之后那一档）才落 `avgColor`。
   */
  private cachedTitleBar: HdsNavigationTitleBarOptions | undefined = undefined;

  private getArtistTitleBar(): HdsNavigationTitleBarOptions {
    hilog.info(0x0000, 'RzdArtistDetail', 'getArtistTitleBar called level=%{public}d', this.ambientState.level);
    let bar = this.cachedTitleBar;
    if (bar === undefined) {
      bar = {
        padding: {
          start: LengthMetrics.vp(16),
          end: LengthMetrics.vp(16)
        },
        style: {
          // ENABLE：让 HDS 在滚动渐变那一档也走模糊档（原来被改成 DISABLE，等于把材质链断掉）。
          blurStrategy: BlurStrategy.ENABLE,
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(264)
          },
          originalStyle: {
            // ① 不滚动时**必须透明**，否则盖住材质（见上面注释）。
            backgroundStyle: { backgroundColor: Color.Transparent },
            contentStyle: {
              backIconStyle: {
                iconColor: this.fgPrimary(),
                backgroundColor: this.fgTitleIconBg()
              },
              menuStyle: {
                iconColor: this.fgPrimary(),
                backgroundColor: this.fgTitleIconBg()
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: { backgroundColor: this.avgColor },
            contentStyle: {
              backIconStyle: {
                iconColor: this.fgPrimary(),
                backgroundColor: this.fgTitleIconBg()
              },
              menuStyle: {
                iconColor: this.fgPrimary(),
                backgroundColor: this.fgTitleIconBg()
              }
            }
          }
        },
        content: {
          backIcon: {
            label: 'back',
            icon: $r('sys.symbol.chevron_left'),
            isEnabled: true,
            action: (): void => {
              this.goBack();
            }
          },
          menu: {
            value: [
              {
                content: {
                  label: 'share',
                  icon: $r('sys.symbol.share'),
                  isEnabled: true,
                  action: (): void => {
                    this.shareArtist();
                  }
                }
              },
              {
                content: {
                  label: 'more',
                  icon: $r('sys.symbol.line_3_horizontal'),
                  isEnabled: true,
                  action: (): void => {
                  }
                }
              }
            ]
          }
        }
      };
      this.cachedTitleBar = bar;
    }
    const style = bar.style;
    if (style !== undefined) {
      // ★ 官方沉浸光感材质（IMMERSIVE + 档位跟随环境光等级）。
      //   ⚠️ 千万不要再写回 `{ materialType: hdsMaterial.MaterialType.NONE }` ——
      //   那正是用户报的"原本歌手页上面有光感，现在没了"。
      const material = buildTitleMaterial(this.ambientState.level);
      style.systemMaterialEffect = material;
      hilog.info(0x0000, 'RzdArtistDetail',
        'titleBar material type=%{public}d level=%{public}d avgColor=%{public}s',
        material.materialType ?? -1, material.materialLevel ?? -1, this.avgColor);
    }
    return bar;
  }

  @Builder
  private ArtistHero() {
        Stack({ alignContent: Alignment.Bottom }) {

          Column() {
            Text(this.artistNameText.length > 0 ? this.artistNameText : '歌手')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.fgPrimary())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ left: 20, right: 20 })

            Row({ space: 14 }) {
              Row() {
                SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
                  .fontSize(18)
                  .fontWeight(FontWeight.Regular)
                  .height(18)
                  .fontColor([this.fgPrimary()])
              }
              .width(40)
              .height(40)
              .borderRadius(20)
              .backgroundColor(this.fgTint())
              .backgroundBlurStyle(this.buttonBlur())
              .alignItems(VerticalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.showAboutPopup = !this.showAboutPopup;
              })
              .bindPopup($$this.showAboutPopup, {
                builder: this.AboutPopup,
                placement: Placement.Top,
                enableArrow: true,
                backgroundBlurStyle: this.buttonBlur(),
                onStateChange: (event: PopupStateChangeParam): void => {
                  if (!event.isVisible) {
                    this.showAboutPopup = false;
                  }
                }
              })

              if (this.activeTab === 0) {
              Row() {
                SymbolGlyph($r('sys.symbol.play_fill'))
                  .fontSize(26)
                  .fontWeight(FontWeight.Regular)
                  .height(26)
                  .fontColor([this.fgPrimary()])
              }
              .width(60)
              .height(60)
              .borderRadius(30)
              .backgroundColor(this.fgTint())
              .backgroundBlurStyle(this.buttonBlur())
              .alignItems(VerticalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .enabled(!this.loading && this.songs.length > 0)
              .opacity(this.loading || this.songs.length === 0 ? 0.5 : 1)
              .onClick(() => {
                this.playAll();
              })
              }

              Row() {
                SymbolGlyph(this.isFavoriteArtist ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
                  .fontSize(18)
                  .fontWeight(FontWeight.Regular)
                  .height(18)
                  .fontColor([this.fgPrimary()])
              }
              .width(40)
              .height(40)
              .borderRadius(20)
              .backgroundColor(this.fgTint())
              .backgroundBlurStyle(this.buttonBlur())
              .alignItems(VerticalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.toggleFavoriteArtist();
              })
            }
            .justifyContent(FlexAlign.Center)
            .padding({ top: 12 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .width('100%')
        .height(320)

  }

  @Builder
  private ArtistStickyHeader() {
    Column() {
      if (this.activeTab === 0) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
            .fontSize(28)
            .fontColor([this.fgPrimary()])
          Text('播放全部 · 已加载 ' + this.songs.length + ' 首')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.fgPrimary())
        }
        .width('100%')
        .height(52)
        .padding({ left: 16, right: 16 })
        .opacity(this.loading || this.songs.length === 0 ? 0.5 : 1)
        .enabled(!this.loading && this.songs.length > 0)
        .onClick((): void => { this.playAll(); })
      }
        Row({ space: 8 }) {
          Column() {
            CapsuleSegmentedSelector({
              labels: ['专辑', '最新', '最热'],
              selectedIndex: this.segmentIndex,
              accentColor: this.themeState.color,
              compact: true,
              onSelect: (index: number): void => {
                this.onSegmentSelect(index);
              }
            })
          }
          .width(216)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 16, right: 16, top: 6, bottom: 4 })

    }
    .width('100%')
    .backgroundColor(this.avgColor)
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        DetailImmersiveBackdrop({
          photo: this.artistPicUrlText,
          color: this.avgColor,
          topAvoidVp: this.windowInfo.statusBarTopVp,
          // ★ 页内可用高度（vp）：照片层必须拿到**显式数值**才画得出来（见该组件类注释）。
          pageHeightVp: this.pageContentHeightVp(),
          scrollVp: this.detailScrollVp,
          page: 'artist'
        })
      List({ scroller: this.scroller }) {
        ListItem() { this.ArtistHero() }
        ListItemGroup({ header: this.ArtistStickyHeader() }) {
            if (this.activeTab === 0 && this.loading && this.songs.length === 0) {
              ListItem() {
              Column() {
                LoadingProgress()
                  .width(32)
                  .height(32)
                  .color(this.fgPrimary())
              }
              .width('100%')
              .padding({ top: 60, bottom: 60 })
              .justifyContent(FlexAlign.Center)
              }
            } else if (this.activeTab === 0 && this.errorMsg.length > 0 && this.songs.length === 0) {
              ListItem() {
              Column({ space: 8 }) {
                Text(this.errorMsg)
                  .fontSize(13)
                  .fontColor(this.fgSecondary())
                  .textAlign(TextAlign.Center)
                  .padding({ left: 24, right: 24 })
              }
              .width('100%')
              .padding({ top: 60, bottom: 60 })
              }
            } else {
              if (this.activeTab === 0) {
                LazyForEach(this.songData, (item: SongInfo, index: number) => {
                  ListItem() { this.SongRowView(item, index) }
                }, (item: SongInfo) => this.source + ':' + item.id)
                if (this.songsHasMore) {
                  ListItem() {
                  Row() {
                    Text(this.loadingMore ? '加载中…' : '上拉加载更多')
                      .fontSize(12)
                      .fontColor(this.fgSecondary())
                      .padding({ top: 12, bottom: 12 })
                      .onClick(() => {
                        this.loadMore();
                      })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  }
                }
              } else {
                LazyForEach(this.albumData, (item: AlbumInfo) => {
                  ListItem() { this.AlbumRowView(item) }
                }, (item: AlbumInfo) => this.source + ':' + item.id + ':' + item.mid)
                if (this.albumsHasMore) {
                  ListItem() {
                  Row() {
                    Text('上拉加载更多')
                      .fontSize(12)
                      .fontColor(this.fgSecondary())
                      .padding({ top: 12, bottom: 12 })
                      .onClick(() => {
                        this.loadMore();
                      })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  }
                }
              }
            }
        }
      }
      .width('100%')
      // 56vp 与 `TitleBarConstants.ROW_HEIGHT_VP` 同值：这里写常量，别再出现魔数。
      .height('calc(100% - ' + TitleBarConstants.ROW_HEIGHT_VP + 'vp)')
      .margin({ top: TitleBarConstants.ROW_HEIGHT_VP })
      .contentEndOffset(96)
      .sticky(StickyStyle.Header)
      .cachedCount(4)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd((): void => { this.loadMore(); })
      .onDidScroll((): void => { this.updateImmersiveScroll(); })
      }
      .width(LayoutPolicy.matchParent)
      .height(LayoutPolicy.matchParent)
    }
    .onBackPressed((): boolean => guardPlayerBack('ArtistDetailPage'))
    .hideTitleBar(false)
    .titleBar(this.getArtistTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.scroller])
    // ★ 只扩**绘制**区到顶部（官方《安全区域》：「expandSafeArea 属性支持组件在不改变布局情况下扩展
    //   其绘制区域至安全区外」「expandSafeArea 属性仅作用于当前组件，不会向父组件或子组件传递」）。
    //   为什么必须是 expandSafeArea 而不是把 TOP 塞进下面的 ignoreLayoutSafeArea：
    //   官方同页给出的用法就是这一条 ——「页面中有标题栏等文字不希望和避让区重叠时，建议对组件设置
    //   expandSafeArea 属性实现沉浸式效果」。ignoreLayoutSafeArea 会**改布局**（标题栏、返回键会一起
    //   顶进状态栏里，用户确认过的那版观感就毁了），所以只让它管 BOTTOM。
    //   这一条换来的效果：NavDestination 自己的 `backgroundColor(avgColor)` 也铺到状态栏那一条 ⇒
    //   首帧 / 没图 / 图加载失败时，那一条就是页面自己的底色，和判据（statusBarOriginalColor 的 ① 档）
    //   一致，不会出现"壳层背景色的一条接缝"。
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
    // ★ 状态栏样式的**唯一真源**（不再叠加 window 级 setWindowSystemBarProperties，官方：
    //   「不建议混合使用 systemBarStyle 属性和 window 设置状态栏样式的相关接口」；
    //   「初次设置 Navigation/NavDestination 的 systemBarStyle 属性时，会备份当前状态栏样式用于后续的
    //    恢复场景」—— 由框架负责备份/恢复，手动下发反而会把这个模型打乱）。
    //   两个参数按官方语义分开算：第一个 = 进页/未滚动的那一刻（照片顶部那一条），
    //   第二个 = 滚动动态档生效后的最终态（压暗底色本身）。
    .systemBarStyle(
      { statusBarContentColor: this.statusBarOriginalColor() },
      { statusBarContentColor: this.statusBarScrollEffectColor() })
    .backgroundColor(this.avgColor)
  }
}

/** 全局路由构建器入口：pushPathByName(RouterUrlConstants.ARTIST_DETAIL, param)。
 * @param name 路由名（与 ARTIST_DETAIL 一致）。
 * @param param ArtistRouteParam 参数对象。
 */
@Builder
export function ArtistDetailPageBuilder(name: string, param: Object) {
  ArtistDetailPage({
    source: (param as ArtistRouteParam | undefined)?.source ?? 2,
    artistId: (param as ArtistRouteParam | undefined)?.id ?? '',
    artistMid: (param as ArtistRouteParam | undefined)?.mid ?? '',
    artistName: (param as ArtistRouteParam | undefined)?.name ?? '',
    artistPicUrl: (param as ArtistRouteParam | undefined)?.picUrl ?? '',
    albumSize: (param as ArtistRouteParam | undefined)?.albumSize ?? 0,
    songNum: (param as ArtistRouteParam | undefined)?.songNum ?? 0
  })
}