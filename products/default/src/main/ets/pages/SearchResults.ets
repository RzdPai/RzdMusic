import { AppStorageV2 } from '@kit.ArkUI';
import { HdsListItemCard } from '@kit.UIDesignKit';
import { AppStorageKeys, HomeSourceState, MusicAppState, ThemeState } from 'musicbasic';
import { lxSearch, OnlinePlayUtil } from 'player';
import type { LXSearchResult, LXSearchSong } from 'player';

class SearchResultDataSource implements IDataSource {
  private songs: LXSearchSong[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.songs.length;
  }

  getData(index: number): LXSearchSong {
    return this.songs[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((item: DataChangeListener) => item !== listener);
  }

  replace(songs: LXSearchSong[]): void {
    this.songs = songs;
    for (const listener of this.listeners) {
      listener.onDataReloaded();
    }
  }
}

/** Content only: the parent owns the search field, header and navigation destination. */
@ComponentV2
export struct SearchResults {
  @Param query: string = '';
  @Param requestRevision: number = 0;
  @Param interactive: boolean = true;
  @Local private phase: string = 'initial';
  @Local private listWidthVp: number = 0;
  @Local private playingKey: string = '';
  @Local private dataSource: SearchResultDataSource = new SearchResultDataSource();
  @Local private homeSourceState: HomeSourceState = AppStorageV2.connect(HomeSourceState,
    AppStorageKeys.HOME_SOURCE_STATE, () => new HomeSourceState())!;
  @Local private appState: MusicAppState = AppStorageV2.connect(MusicAppState,
    AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Local private themeState: ThemeState = AppStorageV2.connect(ThemeState,
    AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  private generation: number = 0;
  private active: boolean = false;
  private submittedQuery: string = '';
  private submittedSource: string = '';

  aboutToAppear(): void {
    this.active = true;
    if (this.requestRevision > 0) {
      this.submit();
    }
  }

  aboutToDisappear(): void {
    this.active = false;
    this.generation++;
    this.playingKey = '';
    console.info('[RzdSearchResults] disappear invalidate generation=' + this.generation);
  }

  @Monitor('requestRevision')
  private onRequestRevisionChanged(): void {
    if (this.active) {
      this.submit();
    }
  }

  private sourceCode(): string {
    const source: string = this.homeSourceState.source;
    return source === 'qq' ? 'tx' : source;
  }

  private submit(): void {
    this.submittedQuery = this.query.trim();
    this.submittedSource = this.sourceCode();
    void this.search(this.submittedQuery, this.submittedSource);
  }

  private retry(): void {
    void this.search(this.submittedQuery, this.submittedSource);
  }

  private async search(keyword: string, source: string): Promise<void> {
    const generation: number = ++this.generation;
    this.dataSource.replace([]);
    this.playingKey = '';
    if (keyword.length === 0) {
      this.phase = 'initial';
      return;
    }
    if (['kw', 'kg', 'tx', 'wy', 'mg'].indexOf(source) < 0) {
      this.phase = 'error';
      console.error('[RzdSearchResults] unsupported source=' + source);
      return;
    }
    this.phase = 'loading';
    console.info('[RzdSearchResults] start generation=' + generation + ' source=' + source +
      ' revision=' + this.requestRevision + ' queryLength=' + keyword.length);
    try {
      const result: LXSearchResult = await lxSearch(source, keyword, 1, 50, true);
      if (!this.active || generation !== this.generation) {
        console.info('[RzdSearchResults] stale generation=' + generation);
        return;
      }
      const seen: Set<string> = new Set<string>();
      const songs: LXSearchSong[] = [];
      for (const song of result.list) {
        const key: string = song.source + ':' + song.songId;
        if (song.songId.length > 0 && !seen.has(key)) {
          seen.add(key);
          songs.push(song);
        }
      }
      this.dataSource.replace(songs);
      // Opt in to SDK rejection so transport failures render the retryable error state.
      this.phase = songs.length > 0 ? 'results' : 'empty';
      console.info('[RzdSearchResults] complete generation=' + generation + ' phase=' + this.phase +
        ' raw=' + result.list.length + ' unique=' + songs.length);
    } catch (_error) {
      if (!this.active || generation !== this.generation) {
        return;
      }
      this.phase = 'error';
      console.error('[RzdSearchResults] failed generation=' + generation + ' source=' + source);
    }
  }

  private async play(song: LXSearchSong): Promise<void> {
    if (!this.interactive || this.playingKey.length > 0) {
      return;
    }
    const key: string = song.source + ':' + song.songId;
    this.playingKey = key;
    console.info('[RzdSearchResults] play start key=' + key);
    try {
      const started: boolean = await OnlinePlayUtil.playSearchSong(this.appState, song, this.getUIContext());
      console.info('[RzdSearchResults] play complete key=' + key + ' started=' + started);
    } catch (_error) {
      console.error('[RzdSearchResults] play failed key=' + key);
      if (this.active) {
        this.getUIContext().getPromptAction().showToast({ message: '暂时无法播放，请稍后重试' });
      }
    } finally {
      if (this.playingKey === key) {
        this.playingKey = '';
      }
    }
  }

  @Builder
  private statusContent() {
    Column({ space: 12 }) {
      if (this.phase === 'loading') {
        LoadingProgress()
          .width('32vp')
          .height('32vp')
          .color(this.themeState.color)
        Text('正在搜索歌曲…')
          .fontSize('16fp')
          .fontColor($r('sys.color.font_secondary'))
      } else {
        Text(this.phase === 'initial' ? '搜索喜欢的音乐' :
          (this.phase === 'empty' ? '暂未找到歌曲' : '搜索暂不可用'))
          .fontSize('18fp')
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.phase === 'initial' ? '输入歌名或歌手，提交后查看结果' :
          (this.phase === 'empty' ? '试试其他关键词；也可能是当前来源暂不可用' :
            '请检查网络或在设置中切换来源后重新搜索'))
          .fontSize('14fp')
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
        if (this.phase === 'empty' || this.phase === 'error') {
          Button('重试')
            .fontSize('14fp')
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor(this.themeState.color)
            .margin({ top: '8vp' })
            .onClick((): void => {
              this.retry();
            })
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding('24vp')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.phase === 'results') {
        List({ space: 8 }) {
          LazyForEach(this.dataSource, (song: LXSearchSong) => {
            ListItem() {
              HdsListItemCard({
                cardWidth: this.listWidthVp > 0 ? this.listWidthVp : undefined,
                cardPrefixMargin: 0,
                cardSuffixMargin: 0,
                textItem: {
                  primaryText: { text: song.name },
                  secondaryText: { text: song.singer + (song.albumName.length > 0 ? ' · ' + song.albumName : '') }
                },
                onClick: (): void => {
                  void this.play(song);
                }
              })
            }
          }, (song: LXSearchSong): string => song.source + ':' + song.songId)
        }
        .width('100%')
        .layoutWeight(1)
        .cachedCount(5)
        .scrollBar(BarState.Auto)
        .onAreaChange((_oldArea: Area, area: Area): void => {
          const width: number = typeof area.width === 'number' ? area.width : parseFloat(area.width.toString());
          if (width > 0 && Math.abs(width - this.listWidthVp) > 0.5) {
            this.listWidthVp = width;
            console.info('[RzdSearchResults] list widthVp=' + width);
          }
        })
      } else {
        this.statusContent()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: '16vp', right: '16vp', top: '8vp', bottom: '16vp' })
  }
}
