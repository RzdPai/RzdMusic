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

const DANGER_COLOR: string = '#E64545';
const SONG_PAGE_LIMIT: number = 50;
const ALBUM_PAGE_LIMIT: number = 50;

/** 秒数 → mm:ss 时长文本。 */
function formatInterval(seconds: number): string {
  let s: number = Math.max(0, Math.floor(seconds));
  const m: number = Math.floor(s / 60);
  s = s % 60;
  const ss: string = s < 10 ? '0' + s : String(s);
  return m + ':' + ss;
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
  @Local imageFailed: boolean = false;
  @Local isFavoriteArtist: boolean = false;
  @Local artistDesc: string = '';
  @Local showAboutPopup: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
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

  /** 下载歌手图片并取平均主色作为页面背景渐变底色。 */
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
      // 取色失败保留默认背景
    } finally {
      req.destroy();
    }
  }

  private async loadSongs(page: number, reset: boolean): Promise<void> {
    if (this.loading || this.loadingMore) {
      return;
    }
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
      if (result.hasMore && this.songs.length < SONG_PAGE_LIMIT * 2 && page < 3) {
        void this.loadSongs(page + 1, false);
      }
    } catch (err) {
      const e: Error = err as Error;
      this.errorMsg = e.message ?? '加载失败';
      this.songsHasMore = false;
    } finally {
      this.loading = false;
      this.loadingMore = false;
    }
  }

  private async loadAlbums(page: number): Promise<void> {
    try {
      const offset: number = (page - 1) * ALBUM_PAGE_LIMIT;
      const result: ArtistAlbumPageResult = await getArtistAlbums(this.source, this.effectiveArtistId, this.effectiveArtistMid,
        ALBUM_PAGE_LIMIT, offset);
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
      if (result.hasMore && this.albums.length < ALBUM_PAGE_LIMIT * 2 && page < 3) {
        void this.loadAlbums(page + 1);
      }
    } catch (_err) {
      this.albumsHasMore = false;
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

  /** HDS 标题栏：返回 + 分享/更多三枚按钮（无标题文字），沉浸渐变模糊。 */
  private cachedTitleBar: HdsNavigationTitleBarOptions | undefined = undefined;

  private getArtistTitleBar(): HdsNavigationTitleBarOptions {
    hilog.info(0x0000, 'RzdArtistDetail', 'getArtistTitleBar called');
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
      style.systemMaterialEffect = buildTitleMaterial(this.ambientState.level);
    }
    return bar;
  }

  build() {
    HdsNavDestination() {
      Column() {
        Stack({ alignContent: Alignment.Bottom }) {
          if (this.artistPicUrlText.length > 0 && !this.imageFailed) {
            Image(this.artistPicUrlText)
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

        Scroll(this.scroller) {
          Column({ space: 0 }) {
            if (this.loading && this.songs.length === 0) {
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
            } else {
              if (this.activeTab === 0) {
                ForEach(this.songs, (item: SongInfo, index: number) => {
                  this.SongRowView(item, index)
                  if (index < this.songs.length - 1) {
                    Divider()
                      .strokeWidth(0.5)
                      .color(this.fgDivider())
                      .margin({ left: 68, right: 16 })
                  }
                }, (item: SongInfo) => item.id + '_' + item.name)
                if (this.songsHasMore) {
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
              } else {
                ForEach(this.albums, (item: AlbumInfo, index: number) => {
                  this.AlbumRowView(item)
                  if (index < this.albums.length - 1) {
                    Divider()
                      .strokeWidth(0.5)
                      .color(this.fgDivider())
                      .margin({ left: 84, right: 16 })
                  }
                }, (item: AlbumInfo) => item.id + '_' + item.name)
                if (this.albumsHasMore) {
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
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.Top)
        .onReachEnd(() => {
          this.loadMore();
        })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(false)
    .titleBar(this.getArtistTitleBar())
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