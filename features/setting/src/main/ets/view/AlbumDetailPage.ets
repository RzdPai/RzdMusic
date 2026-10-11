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
import { guardPlayerBack } from 'musicbasic';
import { AlbumRouteParam, AmbientState, AppStorageKeys, BreakpointType, FavoriteEntry, MusicAppState, MusicStoreService, PlayedSongRecord, RouterUrlConstants, ThemeState, TitleBarConstants, buildTitleMaterial, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { AlbumDetailResult, AlbumInfo, ColorConversion, LXSearchSong, OnlinePlayUtil, SongInfo, getAlbumDetail, codeToSource, showSystemShare, buildSongShareText } from 'player';
import { SongMoreMenu } from 'playlist';
import { DetailImmersiveBackdrop } from './DetailImmersiveBackdrop';
import { ArtistDetailDataSource } from './ArtistDetailDataSource';
import { WindowInfo, getWindowInfoState } from 'musicbasic';

const ALBUM_PAGE_LIMIT: number = 100;

/**
 * ★ 双胞胎常量：`DetailImmersiveBackdrop` 的 `heroHeightVp` / `rowHeightVp` 默认值
 * （本页没有覆写这两个 `@Param`，所以照片画框 = 320 + 56 + 状态栏避让）。
 * 只有算「状态栏那一条在照片里对应哪一块」时才用得到；改那两处默认值时必须同步这里。
 * 与 `ArtistDetailPage` 的同名常量**必须逐字一致**（两页是双胞胎实现）。
 */
const BACKDROP_HERO_VP: number = 320;
const BACKDROP_ROW_VP: number = 56;

/** 秒数 → mm:ss 时长文本。 */
function formatAlbumInterval(seconds: number): string {
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
 * 专辑详情页：歌手页同款大图 Hero（取色背景 + 居中专辑名 + 播放按钮）+ 歌曲列表。
 */
@ComponentV2
export struct AlbumDetailPage {
  /** Window breakpoint for responsive paddings. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Param source: number = 2;
  @Param albumId: string = '';
  @Param albumMid: string = '';
  @Param albumName: string = '';
  @Param albumPicUrl: string = '';
  @Param artistName: string = '';
  @Param albumSize: number = 0;
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  @Local songs: SongInfo[] = [];
  @Local infoName: string = '';
  @Local isFavoriteAlbum: boolean = false;
  @Local infoArtist: string = '';
  @Local infoPicUrl: string = '';
  @Local infoSize: number = 0;
  @Local loading: boolean = false;
  @Local coverFailed: boolean = false;
  @Local errorMsg: string = '';
  @Local avgColor: string = '#1f1f22';
  /**
   * ★ 状态栏判据用的**原始色**（不压暗），只在取色回调里写：
   *  * `photoTopColor`：封面照里**真正压在状态栏那一条下面**的那块区域的平均色 —— 滚动前的判据；
   *  * `photoRawAvgColor`：整张封面照的原始平均色 —— 区域取色失败时的兜底判据。
   * 空串 = 还没有照片像素（首帧 / 没图 / 失败），此时判据退回 `avgColor`。
   * 与 `ArtistDetailPage` 的同名状态**语义必须逐字一致**（两页是双胞胎实现）。
   */
  @Local photoTopColor: string = '';
  @Local photoRawAvgColor: string = '';
  /** 上一次打过的状态栏判据日志（内容相同就不再刷）。 */
  private lastStatusBarLog: string = '';
  @Local imageFailed: boolean = false;
  @Local windowInfo: WindowInfo = getWindowInfoState();
  @Local detailScrollVp: number = 0;
  private lastScrollBand: number = -1;
  private songData: ArtistDetailDataSource<SongInfo> = new ArtistDetailDataSource<SongInfo>();
  private scroller: Scroller = new Scroller();

  @Monitor('songs')
  onSongsChanged(): void {
    this.songData.reload(this.songs);
  }

  private updateImmersiveScroll(): void {
    this.detailScrollVp = Math.max(0, this.scroller.currentOffset().yOffset);
    const band: number = Math.floor(this.detailScrollVp / 56);
    if (band !== this.lastScrollBand) {
      this.lastScrollBand = band;
      hilog.info(0, 'RzdDetailImmersive', 'album scrollVp=%{public}f thresholdVp=264 avoidTopVp=%{public}f',
        this.detailScrollVp, this.windowInfo.statusBarTopVp);
    }
  }

  /**
   * 页内可用高度（vp）= 窗口高 − 状态栏避让。
   *
   * 与 `ArtistDetailPage.pageContentHeightVp` 同款：照片层挂在内容驱动的 Stack 里，
   * 百分比 / `LayoutPolicy.matchParent` 会量成 0 ⇒ 照片整张不画（"顶部是纯色不是照片"）。
   * @returns 高度（vp）；窗口尺寸未就绪时返回 0。
   */
  private pageContentHeightVp(): number {
    const hPx: number = this.windowInfo.windowSize.height;
    if (hPx <= 0) {
      return 0;
    }
    return Math.max(0, this.getUIContext().px2vp(hPx) - this.windowInfo.statusBarTopVp);
  }

  /**
   * 歌曲列表视口要避让的顶部高度 = **状态栏 + HDS 标题栏**（≈38 + 56 = 94）。
   *
   * ★ 2026-10-11 定稿（用户第三次纠正）：页根 `HdsNavDestination` 的 `ignoreLayoutSafeArea`
   *   **必须带 TOP** —— HDS 标题栏自己会按"状态栏高度"往下让位，所以页面盒子要从屏幕 y=0 起排
   *   （只写 BOTTOM = "盒子让一次 + 标题栏再让一次" ⇒ 整条标题掉到状态栏下面约一个状态栏高度，
   *   用户原话「整个标题移到了状态栏下面」，内容也多顶 38vp「上方留的空距有点大了」）。
   *   盒子从 0 起排后：标题栏 = 38..94，所以这里**必须**给「状态栏 + 56」= 94
   *   （改前那个 `TitleBarConstants.ROW_HEIGHT_VP`（56）是"盒子从状态栏下沿起排"时代的旧口径，
   *   会让首屏顶到标题栏底下）。与 `ArtistDetailPage.titleTopInset` 逐字同款。
   *   本页是整页大图形态，状态栏那一条仍然归**照片**（`DetailImmersiveBackdrop` 自己那层带
   *   `ignoreLayoutSafeArea(TOP)`，不受这里影响），所以**不需要** `clipContent`。
   */
  private titleTopInset(): number {
    return getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP;
  }

  aboutToAppear(): void {
    // ★ 状态栏前景色**不再**在这里用 window 接口预下发（原来的 preapplyStatusBarColor 已删）：
    //   官方《HdsNavigation》systemBarStyle 说明：「不建议混合使用 systemBarStyle 属性和 window 设置
    //   状态栏样式的相关接口，例如：setWindowSystemBarProperties。」且「当页面设置不同样式时，在页面
    //   转场开始时生效」⇒ 声明式的 `.systemBarStyle` 就是唯一真源，转场开始那一刻框架就该换色。
    //   这里只打一条进页判据（触发点 = entry），真机 grep RzdAlbumStatusBar 就能对上。
    this.logStatusBarDecision('entry');
    const favSource: string = codeToSource(this.source);
    const favId: string = this.albumId.length > 0 ? this.albumId : this.albumMid;
    this.isFavoriteAlbum = favId.length > 0 &&
      MusicStoreService.getInstance().isFavoriteAlbum(favSource, favId);
    hilog.info(0x0000, 'RzdAlbumDetail', 'aboutToAppear: name=%{public}s source=%{public}d id=%{public}s',
      this.albumName, this.source, this.albumId);
    this.infoName = this.albumName;
    this.infoArtist = this.artistName;
    this.infoPicUrl = this.albumPicUrl;
    this.infoSize = this.albumSize;
    if (this.infoPicUrl.length > 0) {
      void this.loadBackdropColor();
    }
    void this.loadDetail();
  }

  private async loadDetail(): Promise<void> {
    this.loading = true;
    try {
      const result: AlbumDetailResult = await getAlbumDetail(this.source, this.albumId, this.albumMid,
        this.infoName, this.infoArtist);
      this.infoName = result.info.name.length > 0 ? result.info.name : this.infoName;
      this.infoPicUrl = result.info.picUrl.length > 0 ? result.info.picUrl : this.infoPicUrl;
      this.infoArtist = result.info.artistName.length > 0 ? result.info.artistName : this.infoArtist;
      this.infoSize = result.info.size > 0 ? result.info.size :
        (result.list.length > 0 ? result.list.length : this.infoSize);
    if (this.infoPicUrl.length > 0) {
      void this.loadBackdropColor();
    }
      this.songs = result.list;
    } catch (err) {
      const e: Error = err as Error;
      this.errorMsg = e.message ?? '加载失败';
    } finally {
      this.loading = false;
    }
  }

  private async loadAllSongs(): Promise<SongInfo[]> {
    const total: SongInfo[] = [];
    let page: number = 1;
    let hasMore: boolean = true;
    while (hasMore && total.length < 1000 && page <= 10) {
      try {
        const offset: number = (page - 1) * ALBUM_PAGE_LIMIT;
        const result: AlbumDetailResult = await getAlbumDetail(this.source, this.albumId, this.albumMid,
          this.infoName, this.infoArtist);
        if (result.list.length === 0) {
          hasMore = false;
          break;
        }
        for (let i: number = 0; i < result.list.length; i++) {
          total.push(result.list[i]);
        }
        hasMore = false;
        page++;
      } catch (_err) {
        hasMore = false;
      }
    }
    return total;
  }

  private toPlayable(song: SongInfo): LXSearchSong {
    return {
      songId: song.id,
      name: song.name,
      singer: song.singer,
      albumName: song.albumName,
      albumId: '',
      source: codeToSource(this.source),
      interval: formatAlbumInterval(song.interval),
      img: this.infoPicUrl,
      types: []
    };
  }

  private playSong(song: SongInfo): void {
    void OnlinePlayUtil.playSearchSong(this.appState, this.toPlayable(song), this.getUIContext());
  }

  private playAll(): void {
    if (this.songs.length === 0) {
      return;
    }
    const list: LXSearchSong[] = [];
    for (let i: number = 0; i < this.songs.length; i++) {
      list.push(this.toPlayable(this.songs[i]));
    }
    void OnlinePlayUtil.playList(this.appState, list, 0, this.getUIContext());
  }

  /**
   * 下载专辑封面，取两个颜色：
   *  * `avgColor`：全图主色经 `ColorConversion.dealColor` 压暗 —— 页面渐变底、文字、标题栏底色都用它（行为不变）；
   *  * `photoRawAvgColor` + `photoTopColor`：**原始**（不压暗）平均色，只给状态栏判据用（见 {@link statusBarOriginalColor}）。
   */
  private async loadBackdropColor(): Promise<void> {
    if (this.infoPicUrl.length === 0) {
      return;
    }
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(this.infoPicUrl, {
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
      // ignore
    } finally {
      req.destroy();
    }
  }

  /**
   * 只解出「状态栏那一条压在封面照上的区域」并取它的平均色 → `photoTopColor`。
   *
   * 与 `ArtistDetailPage.loadStatusBarStripColor` **逐字同款**（两页是双胞胎实现）。
   * 为什么必须按区域取：状态栏是半透明图标压在照片最上面一条上，判"图标该黑还是该白"只能看
   * **那一条**的亮度；全图主色表达的是"占比最大的颜色"，跟顶部那一条可以完全不搭。
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
      hilog.info(0x0000, 'RzdAlbumStatusBar',
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
      hilog.warn(0x0000, 'RzdAlbumStatusBar', 'strip sample failed, fallback to whole-image average');
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
   * ★ 但**不能拿它当状态栏的判据** —— 状态栏那一条压的是**原始封面照**，不是这块压暗底色。
   */
  private isLightBackdrop(): boolean {
    return this.isLightColor(this.avgColor);
  }

  /**
   * 滚动前压在状态栏那一条下面的颜色 = 封面照顶部那一条的原始平均色。
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
   *   ② 照片就位（未滚动，滚动 < 264vp）：那一条压的是**封面照顶部**⇒ 由照片顶部原始亮度算，浅色照片给黑图标；
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
   * ⚠️ 官方说的是"**最终**"：动态档的终点是封面照完全上移出状态栏（照片画框 376vp+避让，滚动超过它就没照片了），
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
   * 状态栏判据日志：打出**下发值 + 判据来源 + 触发点**（真机 `grep RzdAlbumStatusBar`）。
   * 内容没变就不打，避免 build 每帧刷屏。
   * @param trigger 触发点：entry（进页）/ avg-sample（主色回来）/ strip-sample（顶部条回来）/ pic-url（封面地址变化）
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
    hilog.info(0x0000, 'RzdAlbumStatusBar',
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
   * 封面地址到手（详情接口返回 / 路由带进来晚了一拍）时更新判据。
   *
   * 理由：`photoTopColor` 只在**取到色**之后才有值，而取色的输入是封面地址；地址本身可能是异步才有的。
   * ⚠️ 这里**只**更新判据状态（`@Local`）让 `.systemBarStyle` 重新求值，不再走
   * `WindowUtil.setWindowSystemBarProperties`（官方明确不建议两套混用，见 aboutToAppear 的注释）。
   */
  @Monitor('infoPicUrl')
  onPicUrlChanged(): void {
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

  /** 按钮毛玻璃强度，跟随环境光等级。 */
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

  /** 分享专辑信息。 */
  private shareAlbum(): void {
    showSystemShare(this.getUIContext(),
      buildSongShareText(this.infoName, this.infoArtist.length > 0 ? this.infoArtist : '专辑', '', ''), '分享专辑');
  }

  /** Toggles the album favorite entry (no playlist is created). */
  private toggleFavoriteAlbum(): void {
    const sourceId: string = codeToSource(this.source);
    const id: string = this.albumId.length > 0 ? this.albumId : this.albumMid;
    if (id.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '专辑信息不完整，无法收藏', duration: 2000 });
      return;
    }
    const store: MusicStoreService = MusicStoreService.getInstance();
    if (store.isFavoriteAlbum(sourceId, id)) {
      store.removeFavoriteAlbum(sourceId, id);
      this.isFavoriteAlbum = false;
      this.getUIContext().getPromptAction().showToast({ message: '已取消收藏', duration: 1800 });
      return;
    }
    const entry: FavoriteEntry = new FavoriteEntry();
    entry.id = id;
    entry.source = sourceId;
    entry.name = this.infoName.length > 0 ? this.infoName : this.albumName;
    entry.sub = this.artistName;
    entry.img = this.infoPicUrl.length > 0 ? this.infoPicUrl : this.albumPicUrl;
    entry.time = Date.now();
    store.addFavoriteAlbum(entry);
    this.isFavoriteAlbum = true;
    this.getUIContext().getPromptAction().showToast({ message: '已收藏专辑', duration: 1800 });
  }

  private goBack(): void {
    this.pageIndexInfos.pop();
  }

  @Builder
  private SongRowView(item: SongInfo, index: number) {
    Row({ space: 10 }) {
      if (item.picUrl.length > 0) {
        Image(item.picUrl)
          .width(42)
          .height(42)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
      } else if (this.infoPicUrl.length > 0 && !this.coverFailed) {
        Image(this.infoPicUrl)
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
        Text(formatAlbumInterval(item.interval))
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

  /**
   * HDS 标题栏：返回按钮 + 收藏/分享，无标题文字。
   *
   * ★ 沉浸光感与歌手页**完全同款**（同一份写法，别两边各写一套）：
   *   官方《沉浸光感功耗优化》—— 「其他组件仅在 Navigation/NavDestination 标题栏或横向
   *   Tabs 中 barPosition 为 BarPosition.End 的底部 TabBar 中生效。在其他区域中设置沉浸光感
   *   效果不生效。」⇒ 标题栏是允许区域；`TitleBarStyleOptions.systemMaterialEffect`
   *   （`@since 6.1.0(23)`）就是官方的真实材质入口。
   *   官方 FAQ《材质效果的显示层级问题》——「沉浸光感的视觉层级位于组件的 backgroundColor、
   *   backgroundBlurStyle 等属性之下」，所以：① 不滚动时背景必须 `Color.Transparent`；
   *   ② 标题栏上不再叠 `backgroundBlurStyle` / `backgroundEffect`。
   *   本页 `originalStyle.backgroundStyle.backgroundColor` 本来就是透明，保持即可。
   */
  private cachedTitleBar: HdsNavigationTitleBarOptions | undefined = undefined;

  private getAlbumTitleBar(): HdsNavigationTitleBarOptions {
    hilog.info(0x0000, 'RzdAlbumDetail', 'getAlbumTitleBar called level=%{public}d', this.ambientState.level);
    let bar = this.cachedTitleBar;
    if (bar === undefined) {
      bar = {
        padding: {
          start: LengthMetrics.vp(16),
          end: LengthMetrics.vp(16)
        },
        style: {
          // ENABLE：滚动渐变那一档也要走模糊档（原来被改成 DISABLE，等于把材质链断掉）。
          blurStrategy: BlurStrategy.ENABLE,
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(264)
          },
          originalStyle: {
            // ① 不滚动时**必须透明**，否则不透明底把材质整个盖住（"一块纯色"）。
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
                  label: 'favorite',
                  icon: this.isFavoriteAlbum ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'),
                  isEnabled: true,
                  action: (): void => {
                    this.toggleFavoriteAlbum();
                  }
                }
              },
              {
                content: {
                  label: 'share',
                  icon: $r('sys.symbol.share'),
                  isEnabled: true,
                  action: (): void => {
                    this.shareAlbum();
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
      // ★ 官方沉浸光感材质（与歌手页同一份写法）。
      //   ⚠️ 不要再写回 `{ materialType: hdsMaterial.MaterialType.NONE }` —— 那等于关掉光感。
      const material = buildTitleMaterial(this.ambientState.level);
      style.systemMaterialEffect = material;
      hilog.info(0x0000, 'RzdAlbumDetail',
        'titleBar material type=%{public}d level=%{public}d avgColor=%{public}s',
        material.materialType ?? -1, material.materialLevel ?? -1, this.avgColor);
    }
    return bar;
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        DetailImmersiveBackdrop({
          photo: this.infoPicUrl,
          color: this.avgColor,
          topAvoidVp: this.windowInfo.statusBarTopVp,
          // ★ 页内可用高度（vp）：照片层必须拿到**显式数值**才画得出来。
          pageHeightVp: this.pageContentHeightVp(),
          scrollVp: this.detailScrollVp,
          page: 'album'
        })
        List({ scroller: this.scroller }) {
          ListItem() {
        Stack({ alignContent: Alignment.Bottom }) {

          Column() {
            Text(this.infoName.length > 0 ? this.infoName : '专辑')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.fgPrimary())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ left: 20, right: 20 })

            Row() {
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
              .onClick(() => {
                this.playAll();
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 12 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .width('100%')
        .height(320)
          }
            if (this.loading) {
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
            } else if (this.errorMsg.length > 0 && this.songs.length === 0) {
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
              .justifyContent(FlexAlign.Center)
              }
            } else {
              LazyForEach(this.songData, (item: SongInfo, index: number) => {
                ListItem() { this.SongRowView(item, index) }
              }, (item: SongInfo) => this.source + ':' + item.id + ':' + item.name + ':' + item.singer)
            }
        }
        .width('100%')
        // MINI 标题栏是**浮在内容之上的窄条**（`titleMode(MINI)`）⇒ 视口要给它让位。
        // ★ 2026-10-11：值从 56 改成 `titleTopInset()` = 「状态栏 + 56」= 94（盒子从屏幕 y=0 起排、
        //   HDS 标题栏落在 38..94 之后，视口上边界必须落在 94 才等于是"标题栏下沿"）；
        //   高度跟着减同一个量，视口底边不会因此跑出屏幕。
        .height('calc(100% - ' + this.titleTopInset() + 'vp)')
        .margin({ top: this.titleTopInset() })
        .contentEndOffset(96)
        .cachedCount(4)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .onDidScroll((): void => { this.updateImmersiveScroll(); })
      }
      .width(LayoutPolicy.matchParent)
      .height(LayoutPolicy.matchParent)
    }
    .onBackPressed((): boolean => guardPlayerBack('AlbumDetailPage'))
    .hideTitleBar(false)
    .titleBar(this.getAlbumTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.scroller])
    // ★★ 状态栏三件套（2026-10-11 定稿，用户第三次纠正后）：
    //   ① `expandSafeArea(TOP,BOTTOM)` —— 只扩**绘制**区（官方《安全区域》：「expandSafeArea 属性
    //      支持组件在不改变布局情况下扩展其绘制区域至安全区外」「仅作用于当前组件，不会向父组件或
    //      子组件传递」）⇒ NavDestination 自己的 `backgroundColor(avgColor)` 也铺到状态栏那一条 ⇒
    //      首帧 / 没图 / 图加载失败时，那一条就是页面自己的底色，和判据（statusBarOriginalColor 的
    //      ① 档）一致，不会出现"壳层背景色的一条接缝"。与 ArtistDetailPage 同款。
    //   ② `ignoreLayoutSafeArea(...[TOP, BOTTOM])` —— **TOP 必须给**：HDS 标题栏自己会按
    //      "状态栏高度"往下让位，所以页面盒子必须从屏幕 y=0 起排；只写 BOTTOM 就是"盒子让一次 +
    //      标题栏再让一次" ⇒ 整条标题掉到状态栏下面约一个状态栏高度（用户原话「整个标题移到了
    //      状态栏下面」），首屏内容也多顶 38vp（「上方留的空距有点大了」）。
    //      盒子从 0 起排后：标题栏 = 38..94，列表视口的 `titleTopInset()`（= 94）正好落在 94 ✔。
    //      ⚠️ 旧注释里"ignoreLayoutSafeArea 会改布局、标题栏/返回键会一起顶进状态栏，所以只让它管
    //      BOTTOM"那句**是错的**（把"盒子让位"与"标题栏让位"算成了同一次），已作废。
    //   照片层要压到状态栏底下仍由它自己那层负责：`DetailImmersiveBackdrop` 内部单独写了
    //   `ignoreLayoutSafeArea([SYSTEM], [TOP])`（见该文件 :82），只作用于它自己 —— 这一句不动。
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    // ★ 状态栏样式的**唯一真源**（不再叠加 window 级 setWindowSystemBarProperties，官方：
    //   「不建议混合使用 systemBarStyle 属性和 window 设置状态栏样式的相关接口」；
    //   「初次设置 Navigation/NavDestination 的 systemBarStyle 属性时，会备份当前状态栏样式用于后续的
    //    恢复场景」—— 由框架负责备份/恢复，手动下发反而会把这个模型打乱）。
    //   两个参数按官方语义分开算：第一个 = 进页/未滚动的那一刻（封面照顶部那一条），
    //   第二个 = 滚动动态档生效后的最终态（压暗底色本身）。
    .systemBarStyle(
      { statusBarContentColor: this.statusBarOriginalColor() },
      { statusBarContentColor: this.statusBarScrollEffectColor() })
    .backgroundColor(this.avgColor)
  }
}

/**
 * 全局路由构建器入口：pushPathByName(RouterUrlConstants.ALBUM_DETAIL, param)。
 * @param name 路由名（与 ALBUM_DETAIL 一致）。
 * @param param AlbumRouteParam 参数对象。
 */
@Builder
export function AlbumDetailPageBuilder(name: string, param: Object) {
  AlbumDetailPage({
    source: (param as AlbumRouteParam | undefined)?.source ?? 2,
    albumId: (param as AlbumRouteParam | undefined)?.id ?? '',
    albumMid: (param as AlbumRouteParam | undefined)?.mid ?? '',
    albumName: (param as AlbumRouteParam | undefined)?.name ?? '',
    albumPicUrl: (param as AlbumRouteParam | undefined)?.picUrl ?? '',
    artistName: (param as AlbumRouteParam | undefined)?.artistName ?? '',
    albumSize: (param as AlbumRouteParam | undefined)?.size ?? 0
  })
}