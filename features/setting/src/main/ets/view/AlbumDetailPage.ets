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
import { AlbumRouteParam, AmbientState, AppStorageKeys, BreakpointType, FavoriteEntry, MusicAppState, MusicStoreService, PlayedSongRecord, RouterUrlConstants, ThemeState, TitleBarConstants, WindowUtil, buildTitleMaterial } from 'musicbasic';
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

/** 秒数 → mm:ss 时长文本。 */
function formatAlbumInterval(seconds: number): string {
  let s: number = Math.max(0, Math.floor(seconds));
  const m: number = Math.floor(s / 60);
  s = s % 60;
  const ss: string = s < 10 ? '0' + s : String(s);
  return m + ':' + ss;
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

  aboutToAppear(): void {
    // 进页第一件事就把状态栏前景色按本页背景下发（与 ArtistDetailPage 同款修法，
    // 详见那里 preapplyStatusBarColor 的注释）。
    this.preapplyStatusBarColor();
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

  /** 下载专辑封面并取主色作为页面背景渐变底色。 */
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
    } catch (_err) {
      // ignore
    } finally {
      req.destroy();
    }
  }

  /** 取色背景是否偏浅（决定前景文字/图标用深色还是白色）。 */
  private isLightBackdrop(): boolean {
    const c: string = this.avgColor;
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

  /** 标题栏返回/菜单按钮的半透明底色。 */
  private fgTitleIconBg(): string {
    return this.isLightBackdrop() ? '#1A000000' : '#1AFFFFFF';
  }

  /** 主文字颜色：浅色背景用深字，深色背景用白字。 */
  private fgPrimary(): string {
    return this.isLightBackdrop() ? '#E6000000' : '#FFFFFF';
  }

  /** 状态栏前景（图标/时间）颜色：与页面背景判据同源。 */
  private statusBarContentColor(): string {
    return this.isLightBackdrop() ? '#000000' : '#FFFFFF';
  }

  /**
   * 把当前该有的状态栏前景色立刻下发到窗口（窗口级 setWindowSystemBarProperties）。
   * 理由与三段"颜色何时确定/何时下发"的说明见 ArtistDetailPage.preapplyStatusBarColor。
   */
  private preapplyStatusBarColor(): void {
    const color: string = this.statusBarContentColor();
    WindowUtil.getInstance().setWindowSystemBarProperties({ statusBarContentColor: color });
    hilog.info(0, 'RzdDetailImmersive',
      'album statusBar preapply avgColor=%{public}s light=%{public}d color=%{public}s',
      this.avgColor, this.isLightBackdrop() ? 1 : 0, color);
  }

  /** 取色回来（avgColor 变化）就是背景色真正确定的时刻：立刻重下发一次状态栏颜色。 */
  @Monitor('avgColor')
  onAvgColorChanged(): void {
    this.preapplyStatusBarColor();
  }

  /**
   * 封面地址到手（详情接口返回 / 路由带进来晚了一拍）时也要重下发一次。
   *
   * 理由：`avgColor` 只有在**取到色**之后才变，而取色的输入是封面地址；封面地址本身
   * 可能就是异步才有的（`loadDetail()` 回包）。这一档不补，首帧那一次下发就停在
   * `#1f1f22` 推出的白字判据上，一旦封面是浅色图，状态栏会与顶部照片不符。
   */
  @Monitor('infoPicUrl')
  onPicUrlChanged(): void {
    this.preapplyStatusBarColor();
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
        // 与 `TitleBarConstants.ROW_HEIGHT_VP`（56vp）同值：别写魔数。
        .height('calc(100% - ' + TitleBarConstants.ROW_HEIGHT_VP + 'vp)')
        .margin({ top: TitleBarConstants.ROW_HEIGHT_VP })
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
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
    .systemBarStyle(
      { statusBarContentColor: this.statusBarContentColor() },
      { statusBarContentColor: this.statusBarContentColor() })
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