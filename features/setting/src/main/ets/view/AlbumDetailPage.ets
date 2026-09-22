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
import { AlbumRouteParam, AmbientState, AppStorageKeys, BreakpointType, FavoriteEntry, MusicAppState, MusicStoreService, PlayedSongRecord, RouterUrlConstants, ThemeState, buildTitleMaterial } from 'musicbasic';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { AlbumDetailResult, AlbumInfo, ColorConversion, LXSearchSong, OnlinePlayUtil, SongInfo, getAlbumDetail, codeToSource, showSystemShare, buildSongShareText } from 'player';
import { SongMoreMenu } from 'playlist';

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
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
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

  /** HDS 标题栏：返回按钮 + 专辑名，沉浸渐变模糊。 */
  private cachedTitleBar: HdsNavigationTitleBarOptions | undefined = undefined;

  private getAlbumTitleBar(): HdsNavigationTitleBarOptions {
    hilog.info(0x0000, 'RzdAlbumDetail', 'getAlbumTitleBar called');
    let bar = this.cachedTitleBar;
    if (bar === undefined) {
      bar = {
        padding: {
          start: LengthMetrics.vp(16),
          end: LengthMetrics.vp(16)
        },
        style: {
          blurStrategy: BlurStrategy.ENABLE,
          scrollEffectOpts: {
            scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
          },
          originalStyle: {
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
      style.systemMaterialEffect = buildTitleMaterial(this.ambientState.level);
    }
    return bar;
  }

  build() {
    HdsNavDestination() {
      Column() {
        Stack({ alignContent: Alignment.Bottom }) {
          if (this.infoPicUrl.length > 0 && !this.imageFailed) {
            Image(this.infoPicUrl)
              .width('100%')
              .height(320)
              .objectFit(ImageFit.Cover)
              .onError(() => {
                this.imageFailed = true;
              })
          } else {
            Column()
              .width('100%')
              .height(320)
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#1f2328')
          }

          Column()
            .width('100%')
            .height(150)
            .position({ y: 170 })
            .linearGradient({
              colors: [[Color.Transparent, 0], [this.avgColor, 1]],
              angle: 180,
              direction: GradientDirection.Bottom
            })

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

        Scroll(this.scroller) {
          Column({ space: 0 }) {
            if (this.loading) {
              Column() {
                LoadingProgress()
                  .width(32)
                  .height(32)
                  .color(this.fgPrimary())
              }
              .width('100%')
              .padding({ top: 60, bottom: 60 })
              .justifyContent(FlexAlign.Center)
            } else if (this.errorMsg.length > 0 && this.songs.length === 0) {
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
            } else {
              ForEach(this.songs, (item: SongInfo, index: number) => {
                this.SongRowView(item, index)
                if (index < this.songs.length - 1) {
                  Divider()
                    .strokeWidth(0.5)
                    .color(this.fgDivider())
                    .margin({ left: 68, right: 16 })
                }
              }, (item: SongInfo) => item.id + '_' + item.name + '_' + item.singer)
            }
            Column()
              .height(48)
              .width('100%')
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(false)
    .titleBar(this.getAlbumTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.scroller])
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .systemBarStyle(
      { statusBarContentColor: this.isLightBackdrop() ? '#000000' : '#FFFFFF' },
      { statusBarContentColor: this.isLightBackdrop() ? '#000000' : '#FFFFFF' })
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