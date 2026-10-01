import { AppStorageV2 } from '@kit.ArkUI';
import { HdsListItemCard } from '@kit.UIDesignKit';
import { AppStorageKeys, MusicAppState, PlaybackIntentState, SongItem, ThemeState } from 'musicbasic';
import { LXSearchResult, LXSearchSong, lxSearch } from '../source/LXMusicSDK';
import { lxEngineIsReady } from '../source/LXSourceEngine';
import { OnlinePlayUtil } from '../util/OnlinePlayUtil';

class VersionResultRow {
  key: string = '';
  label: string = '';
  song: LXSearchSong | undefined = undefined;
}

class VersionResultSource implements IDataSource {
  private rows: VersionResultRow[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.rows.length;
  }

  getData(index: number): VersionResultRow {
    return this.rows[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((item: DataChangeListener) => item !== listener);
  }

  replace(rows: VersionResultRow[]): void {
    this.rows = rows;
    for (const listener of this.listeners) {
      listener.onDataReloaded();
    }
  }
}

/** Independent half-modal: no search route and no competing playback state. */
@ComponentV2
export struct OtherVersionsSheet {
  @Param isShow: boolean = false;
  @Param initialKeyword: string = '';
  @Event onDismiss: () => void = (): void => {};
  @Local visible: boolean = false;
  @Local keyword: string = '';
  @Local loading: boolean = false;
  @Local status: string = '';
  @Local resultCount: number = 0;
  @Local listWidthVp: number = 0;
  @Local dataSource: VersionResultSource = new VersionResultSource();
  @Local appState: MusicAppState = AppStorageV2.connect(MusicAppState,
    AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState,
    AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  private generation: number = 0;
  private closing: boolean = false;
  private targetIndex: number = -1;
  private targetIdentity: string = '';
  private targetOnline: SongItem | undefined = undefined;
  private queueSnapshot: SongItem[] = [];
  private idsSnapshot: number[] = [];
  private queueItemsSnapshot: SongItem[] = [];
  private idsValueSnapshot: string = '';
  private intentVersion: number = 0;
  private readonly sources: string[] = ['kw', 'kg', 'tx', 'wy', 'mg'];
  private readonly sourceNames: string[] = ['酷我', '酷狗', 'QQ', '网易', '咪咕'];

  private intent(): PlaybackIntentState {
    return AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE,
      () => new PlaybackIntentState())!;
  }

  private identity(song: SongItem | undefined): string {
    return song === undefined ? '' : JSON.stringify([song.source, song.songId, song.id, song.src]);
  }

  private targetValid(): boolean {
    if (this.queueItemsSnapshot.length !== this.appState.playQueue.length ||
      this.idsValueSnapshot !== JSON.stringify(this.appState.playQueueIds)) {
      return false;
    }
    for (let i: number = 0; i < this.queueItemsSnapshot.length; i++) {
      if (this.queueItemsSnapshot[i] !== this.appState.playQueue[i]) {
        return false;
      }
    }
    return this.visible && !this.closing && this.appState.selectIndex === this.targetIndex &&
      this.appState.playQueue === this.queueSnapshot && this.appState.playQueueIds === this.idsSnapshot &&
      this.intent().requestVersion === this.intentVersion &&
      this.identity(this.appState.getCurrentSongItem()) === this.targetIdentity &&
      (this.targetOnline === undefined || this.appState.getCurrentSongItem() === this.targetOnline);
  }

  @Monitor('isShow')
  onVisibilityChanged(): void {
    if (this.isShow) {
      this.open();
    } else {
      this.cancel();
    }
  }

  @Monitor('appState.selectIndex', 'appState.playQueue', 'appState.playQueueIds')
  onQueueChanged(): void {
    if (this.visible && !this.targetValid()) {
      console.info('[RzdOtherVersionSearch] target changed; dismiss');
      this.cancel();
    }
  }

  aboutToAppear(): void {
    if (this.isShow) {
      this.open();
    }
  }

  aboutToDisappear(): void {
    this.generation++;
    this.visible = false;
  }

  private open(): void {
    const current: SongItem | undefined = this.appState.getCurrentSongItem();
    if (current === undefined) {
      this.onDismiss();
      return;
    }
    this.targetIndex = this.appState.selectIndex;
    this.targetIdentity = this.identity(current);
    this.queueSnapshot = this.appState.playQueue;
    this.idsSnapshot = this.appState.playQueueIds;
    this.queueItemsSnapshot = [...this.queueSnapshot];
    this.idsValueSnapshot = JSON.stringify(this.idsSnapshot);
    this.targetOnline = this.targetIndex < this.queueSnapshot.length ? current : undefined;
    this.intentVersion = this.intent().requestVersion;
    this.keyword = this.initialKeyword;
    this.closing = false;
    this.visible = true;
    void this.search();
  }

  private cancel(): void {
    this.generation++;
    this.visible = false;
    this.loading = false;
    this.onDismiss();
  }

  private async search(): Promise<void> {
    const query: string = this.keyword.trim();
    const gen: number = ++this.generation;
    this.dataSource.replace([]);
    this.resultCount = 0;
    this.status = '';
    this.loading = false;
    if (query.length === 0) {
      this.status = '请输入歌名或歌手';
      return;
    }
    if (!this.targetValid()) {
      this.cancel();
      return;
    }
    this.loading = true;
    console.info('[RzdOtherVersionSearch] start gen=' + gen + ' keywordLength=' + query.length);
    const tasks: Promise<LXSearchResult>[] = [];
    for (const source of this.sources) {
      tasks.push(lxSearch(source, query, 1, 20));
    }
    const results: PromiseSettledResult<LXSearchResult>[] = await Promise.allSettled(tasks);
    if (gen !== this.generation || !this.targetValid()) {
      console.info('[RzdOtherVersionSearch] discard late gen=' + gen);
      if (gen === this.generation) {
        this.cancel();
      }
      return;
    }
    const rows: VersionResultRow[] = [];
    let failed: number = 0;
    let count: number = 0;
    for (let i: number = 0; i < results.length; i++) {
      const result: PromiseSettledResult<LXSearchResult> = results[i];
      const header: VersionResultRow = new VersionResultRow();
      header.key = 'source:' + this.sources[i];
      header.label = this.sourceNames[i];
      rows.push(header);
      if (result.status === 'fulfilled') {
        const seen: Set<string> = new Set<string>();
        for (const song of result.value.list) {
          const key: string = song.source + ':' + song.songId;
          if (seen.has(key) || song.songId.length === 0) {
            continue;
          }
          seen.add(key);
          const row: VersionResultRow = new VersionResultRow();
          row.key = 'song:' + this.sources[i] + ':' + key;
          row.song = song;
          rows.push(row);
          count++;
        }
        if (seen.size === 0) {
          header.label += ' · 暂无结果';
        }
      } else {
        failed++;
        header.label += ' · 搜索失败，请重试';
      }
    }
    this.resultCount = count;
    this.dataSource.replace(rows);
    this.loading = false;
    this.status = failed === this.sources.length ? '搜索失败，请检查网络后重试' :
      (count === 0 ? '未找到其它版本，可修改关键词重试' :
        (failed > 0 ? '部分来源搜索失败，可重新搜索' : '点击歌曲替换当前队列位置并播放'));
    console.info('[RzdOtherVersionSearch] finish gen=' + gen + ' count=' + count + ' failed=' + failed);
  }

  private replaceCurrent(song: LXSearchSong): void {
    if (!this.targetValid()) {
      this.getUIContext().getPromptAction().showToast({ message: '当前歌曲已变化，请重新搜索' });
      this.cancel();
      return;
    }
    if (!lxEngineIsReady) {
      this.getUIContext().getPromptAction().showToast({ message: '请先在设置中导入并选中音源' });
      return;
    }
    const item: SongItem = new SongItem();
    item.id = Date.now();
    item.title = song.name;
    item.singer = song.singer;
    item.cover = song.img;
    item.source = song.source;
    item.songId = song.songId;
    item.albumId = song.albumId;
    item.albumName = song.albumName;
    item.interval = song.interval;
    item.qualityList = OnlinePlayUtil.toQualityList(song.types);
    const queue: SongItem[] = [...this.appState.playQueue];
    let remainingIds: number[] = [...this.appState.playQueueIds];
    if (this.targetIndex < queue.length) {
      queue[this.targetIndex] = item;
    } else {
      // Materialize only the local prefix through the target. The common resolver uses
      // SongDtoMapper; leave every remaining id untouched and keep the combined order.
      for (let index: number = queue.length; index <= this.targetIndex; index++) {
        const original: SongItem | undefined = this.appState.resolveSongAtQueueIndex(index);
        if (original === undefined) {
          this.getUIContext().getPromptAction().showToast({ message: '队列歌曲已失效，未替换' });
          return;
        }
        queue.push(index === this.targetIndex ? item : original);
      }
      remainingIds = remainingIds.slice(this.targetIndex - this.appState.playQueue.length + 1);
    }
    const index: number = this.targetIndex;
    const intent: PlaybackIntentState = this.intent();
    this.cancel();
    this.appState.replaceQueue(queue, index);
    this.appState.playQueueIds = remainingIds;
    this.appState.currentQuality = '';
    intent.pendingPlaySongId = -1;
    intent.pendingQueueIndex = index;
    intent.openPlayerUi = false;
    intent.requestVersion++;
    console.info('[RzdOtherVersionSearch] replace index=' + index + ' queueLength=' +
      this.appState.getQueueLength() + ' requestVersion=' + intent.requestVersion);
  }

  @Builder
  private Content() {
    Column({ space: 12 }) {
      Row() {
        Text('搜索其它版本').fontSize('20fp').fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Button('取消').fontSize('14fp').backgroundColor(Color.Transparent)
          .fontColor(this.themeState.color).onClick(() => { this.cancel(); })
      }.width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '歌名 歌手' })
          .layoutWeight(1).fontSize('16fp')
          .onChange((value: string) => { this.keyword = value; })
          .onSubmit(() => { void this.search(); })
        Button('搜索').fontSize('14fp').backgroundColor(this.themeState.color)
          .onClick(() => { void this.search(); })
      }.width('100%')
      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress().width(24).height(24)
          Text('正在搜索五个来源…').fontSize('14fp').fontColor($r('sys.color.font_secondary'))
        }
      }
      if (this.status.length > 0) {
        Text(this.status).width('100%').fontSize('13fp').fontColor($r('sys.color.font_secondary'))
      }
      List({ space: 8 }) {
        LazyForEach(this.dataSource, (row: VersionResultRow) => {
          ListItem() {
            if (row.song === undefined) {
              Text(row.label).fontSize('14fp').fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_secondary')).padding({ top: 8, bottom: 4 })
            } else {
              HdsListItemCard({
                cardWidth: this.listWidthVp > 0 ? this.listWidthVp : undefined,
                cardPrefixMargin: 0,
                cardSuffixMargin: 0,
                textItem: {
                  primaryText: { text: row.song.name },
                  secondaryText: { text: row.song.singer + ' · ' + row.song.albumName }
                },
                onClick: (): void => {
                  if (row.song !== undefined) {
                    this.replaceCurrent(row.song);
                  }
                }
              })
            }
          }
        }, (row: VersionResultRow) => row.key)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Auto)
        .onAreaChange((_oldArea: Area, area: Area): void => {
          const width: number = typeof area.width === 'number' ? area.width : parseFloat(area.width.toString());
          if (width > 0 && Math.abs(width - this.listWidthVp) > 0.5) {
            this.listWidthVp = width;
            console.info('[RzdOtherVersionSearch] list widthVp=' + width + ' outerInset=8 cardInset=0');
          }
        })
    }.width('100%').height('100%').padding({ left: 8, right: 8, bottom: 16 })
  }

  build() {
    Column() {}
      .width(0).height(0)
      .bindSheet($$this.visible, this.Content(), {
        height: SheetSize.MEDIUM,
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        dragBar: true,
        showClose: false,
        backgroundColor: $r('sys.color.background_primary'),
        onWillDismiss: (action: DismissSheetAction): void => {
          // Invalidate work immediately; let dismiss() own the system exit animation.
          this.closing = true;
          this.generation++;
          this.loading = false;
          action.dismiss();
        },
        onDisappear: (): void => {
          this.generation++;
          this.loading = false;
          this.visible = false;
          this.onDismiss();
        }
      })
  }
}
