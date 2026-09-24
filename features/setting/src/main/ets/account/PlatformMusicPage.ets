import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, TitleSize } from '@kit.UIDesignKit';
import { AppStorageKeys, MusicAppState, ThemeState } from 'musicbasic';
import { LXSearchSong, OnlinePlayUtil } from 'player';
import { AccountService } from 'player';
import { PlatformAccount, PlaylistInfo, PlaylistTrackInfo, PlatformTrackInfo, PlaylistMutationTrack, sourceName } from 'player';

const DANGER_COLOR: string = '#E64545';

const songCache: Map<string, PlatformTrackInfo[]> = new Map();

class AccountGroup {
  account: PlatformAccount = new PlatformAccount();
  playlists: PlaylistInfo[] = [];
  error: string = '';
}

class PlaylistDestination {
  accountId: string = '';
  playlistId: string = '';
  dirId: string = '';
  isEditable: boolean = false;
}

@ComponentV2
export struct PlatformMusicPage {
  @Param contentTopOffset: number = 0;
  @Param pageScroller: Scroller = new Scroller();
  @Local groups: AccountGroup[] = [];
  @Local currentAccountId: string = '';
  @Local currentPlaylists: PlaylistInfo[] = [];
  @Local selectedKey: string = '';
  @Local selectedTitle: string = '';
  @Local selectedSource: string = '';
  @Local selectedDestination: PlaylistDestination | null = null;
  @Local songs: PlatformTrackInfo[] = [];
  @Local isLoading: boolean = false;
  @Local error: string = '';
  @Local loadingPlaylists: boolean = false;
  @Local avatarFailed: Set<string> = new Set();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local coverFailed: Set<string> = new Set();
  /** 关闭回调（父组件控制返回）。 */
  @Param onClose: () => void = () => {};
  /** 刷新信号：父组件（标题栏刷新按钮）递增触发重新加载。 */
  @Param refreshSignal: number = 0;

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (context !== undefined) {
      AccountService.init(context);
    }
    this.loadAll(false);
  }

  @Monitor('refreshSignal')
  onRefreshSignalChanged(): void {
    this.loadAll(true);
  }

  private async loadAll(forceRefresh: boolean): Promise<void> {
    if (forceRefresh) songCache.clear();
    this.loadingPlaylists = true;
    try {
      await AccountService.loadAccounts();
      await AccountService.refreshKgAvatars();
    } catch (err) {
      // 忽略
    }
    const accounts: PlatformAccount[] = AccountService.listAccounts();
    const groups: AccountGroup[] = [];
    for (const account of accounts) {
      const group: AccountGroup = new AccountGroup();
      group.account = account;
      try {
        group.playlists = await AccountService.getUserPlaylists(account.id);
      } catch (err) {
        const error: Error = err as Error;
        group.error = error.message ?? '获取歌单失败';
      }
      groups.push(group);
    }
    this.groups = groups;
    this.loadingPlaylists = false;
    if (groups.length === 0) {
      this.clearSelected();
      return;
    }
    if (this.findGroup(this.selectedKey) === undefined) {
      await this.selectDefault(groups[0]);
    } else {
      await this.reloadSelected();
    }
  }

  private async selectDefault(group: AccountGroup): Promise<void> {
    if (group.playlists.length === 0 && group.error.length > 0) {
      try {
        group.playlists = await AccountService.getUserPlaylists(group.account.id);
        group.error = '';
      } catch (err) {
        const error: Error = err as Error;
        group.error = error.message ?? '获取歌单失败';
      }
      this.groups = this.groups.slice();
    }
    if (group.account.source.length > 0) {
      await this.selectDaily(group.account);
    } else if (group.playlists.length > 0) {
      await this.selectPlaylist(group.account, group.playlists[0]);
    } else {
      this.clearSelected();
    }
  }

  private findGroup(key: string): AccountGroup | undefined {
    for (const group of this.groups) {
      if (key.startsWith(`${group.account.id}:`)) return group;
    }
    return undefined;
  }

  private currentGroupError(): string {
    const group: AccountGroup | undefined = this.findGroup(this.selectedKey);
    if (group === undefined) return '';
    return group.error;
  }

  private dailyTitle(source: string): string {
    if (source === 'tx') return '每日30首';
    return '每日推荐';
  }

  private clearSelected(): void {
    this.selectedKey = '';
    this.currentAccountId = '';
    this.currentPlaylists = [];
    this.selectedTitle = '';
    this.selectedSource = '';
    this.selectedDestination = null;
    this.songs = [];
    this.error = '';
    this.isLoading = false;
  }

  private applyCurrentGroup(key: string): void {
    const group: AccountGroup | undefined = this.findGroup(key);
    this.currentAccountId = group === undefined ? '' : group.account.id;
    this.currentPlaylists = group === undefined ? [] : group.playlists;
  }

  private async selectDaily(account: PlatformAccount): Promise<void> {
    const key: string = `${account.id}:daily`;
    this.selectedKey = key;
    this.applyCurrentGroup(key);
    this.selectedTitle = this.dailyTitle(account.source);
    this.selectedSource = account.source;
    this.selectedDestination = null;
    this.error = '';
    const cached: PlatformTrackInfo[] | undefined = songCache.get(key);
    if (cached !== undefined) {
      this.songs = cached;
      this.isLoading = false;
      return;
    }
    this.songs = [];
    this.isLoading = true;
    try {
      const ids: string[] = await AccountService.getDailyTrackIds(account.id);
      if (this.selectedKey !== key) return;
      let infos: PlatformTrackInfo[] = [];
      if (ids.length > 0) infos = await AccountService.getTrackDetails(account.id, ids);
      if (this.selectedKey !== key) return;
      this.songs = infos;
      songCache.set(key, infos);
    } catch (err) {
      const error: Error = err as Error;
      if (this.selectedKey !== key) return;
      this.error = error.message ?? '加载失败';
    } finally {
      if (this.selectedKey === key) this.isLoading = false;
    }
  }

  private async selectPlaylist(account: PlatformAccount, playlist: PlaylistInfo): Promise<void> {
    const key: string = `${account.id}:${playlist.id}`;
    this.selectedKey = key;
    this.applyCurrentGroup(key);
    this.selectedTitle = playlist.name;
    this.selectedSource = account.source;
    const destination: PlaylistDestination = new PlaylistDestination();
    destination.accountId = account.id;
    destination.playlistId = playlist.id;
    destination.dirId = playlist.dirId;
    destination.isEditable = playlist.isEditable;
    this.selectedDestination = destination;
    this.error = '';
    const cached: PlatformTrackInfo[] | undefined = songCache.get(key);
    if (cached !== undefined) {
      this.songs = cached;
      this.isLoading = false;
      return;
    }
    this.songs = [];
    this.isLoading = true;
    try {
      const tracks: PlaylistTrackInfo[] = await AccountService.getPlaylistTrackIds(account.id, playlist.id, playlist.dirId);
      if (this.selectedKey !== key) return;
      const removeMap: Map<string, string> = new Map();
      for (const track of tracks) removeMap.set(track.id, track.removeId);
      const ids: string[] = tracks.map((track: PlaylistTrackInfo) => track.id);
      let infos: PlatformTrackInfo[] = [];
      if (ids.length > 0) {
        infos = await AccountService.getTrackDetails(account.id, ids);
        for (const info of infos) info.removeId = removeMap.get(info.id) ?? '';
      }
      if (this.selectedKey !== key) return;
      this.songs = infos;
      songCache.set(key, infos);
    } catch (err) {
      const error: Error = err as Error;
      if (this.selectedKey !== key) return;
      this.error = error.message ?? '加载失败';
    } finally {
      if (this.selectedKey === key) this.isLoading = false;
    }
  }

  private async reloadSelected(): Promise<void> {
    const key: string = this.selectedKey;
    if (key.length === 0) return;
    const group: AccountGroup | undefined = this.findGroup(key);
    if (group === undefined) return;
    if (key.endsWith(':daily')) {
      await this.selectDaily(group.account);
      return;
    }
    const playlistId: string = key.substring(key.indexOf(':') + 1);
    for (const playlist of group.playlists) {
      if (playlist.id === playlistId) {
        await this.selectPlaylist(group.account, playlist);
        return;
      }
    }
  }

  private handleRemoveTrack(song: PlatformTrackInfo): void {
    const destination: PlaylistDestination | null = this.selectedDestination;
    if (destination === null || !destination.isEditable) return;
    this.getUIContext().showAlertDialog({
      title: '移除歌曲',
      message: `确定将「${song.name}」从歌单移除吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        },
      },
      secondaryButton: {
        value: '移除',
        fontColor: DANGER_COLOR,
        action: () => {
          this.doRemoveTrack(destination, song);
        },
      },
    });
  }

  private async doRemoveTrack(destination: PlaylistDestination, song: PlatformTrackInfo): Promise<void> {
    const mutation: PlaylistMutationTrack = new PlaylistMutationTrack();
    mutation.songId = song.id;
    mutation.platformId = song.removeId;
    mutation.name = song.name;
    mutation.source = song.source;
    this.isLoading = true;
    try {
      await AccountService.removePlaylistTracks(destination.accountId, destination.playlistId, destination.dirId, [mutation]);
      songCache.delete(`${destination.accountId}:${destination.playlistId}`);
      await this.reloadSelected();
    } catch (err) {
      const error: Error = err as Error;
      this.error = error.message ?? '移除失败';
      this.isLoading = false;
    }
  }

  private statusText(): string {
    if (this.isLoading) return '加载中...';
    if (this.error.length > 0) return this.error;
    if (this.songs.length > 0) return '';
    if (this.selectedKey.endsWith(':daily')) return '暂无每日推荐';
    if (this.selectedKey.length > 0) return '暂无歌曲';
    return '请先在平台账号管理中登录平台账号';
  }

  private markAvatarFailed(id: string): void {
    const failed: Set<string> = new Set(this.avatarFailed);
    failed.add(id);
    this.avatarFailed = failed;
  }

  private markCoverFailed(id: string): void {
    const failed: Set<string> = new Set(this.coverFailed);
    failed.add(id);
    this.coverFailed = failed;
  }

  @Builder
  songRow(song: PlatformTrackInfo) {
    Row() {
      if (song.picUrl.length > 0 && !this.coverFailed.has(song.id)) {
        Image(song.picUrl)
          .width(42)
          .height(42)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .backgroundColor($r('sys.color.background_tertiary'))
          .onError(() => {
            this.markCoverFailed(song.id);
          })
      } else {
        Text('♪')
          .width(42)
          .height(42)
          .borderRadius(8)
          .textAlign(TextAlign.Center)
          .fontSize(18)
          .fontColor(this.themeState.color)
          .backgroundColor($r('sys.color.background_tertiary'))
      }
      Column() {
        Text(song.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(song.singer.length > 0 ? `${song.singer}${song.album.length > 0 ? ` · ${song.album}` : ''}` : song.album)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      if (song.interval.length > 0) {
        Text(song.interval)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .margin({ left: 6 })
      }

      if (this.selectedDestination !== null && this.selectedDestination.isEditable) {
        Button('移除')
          .type(ButtonType.Normal)
          .fontSize(11)
          .fontColor(DANGER_COLOR)
          .backgroundColor($r('sys.color.background_tertiary'))
          .height(26)
          .margin({ left: 8 })
          .onClick(() => {
            this.handleRemoveTrack(song);
          })
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .onClick(() => {
      this.playPlatformSong(song);
    })
  }

  /** 用 LX 引擎播放平台账号歌曲：整张歌单入列并从点击的歌曲开始。 */
  private playPlatformSong(song: PlatformTrackInfo): void {
    const songs: LXSearchSong[] = [];
    let startIndex: number = 0;
    for (let i: number = 0; i < this.songs.length; i++) {
      const track: PlatformTrackInfo = this.songs[i];
      songs.push({
        songId: track.id,
        name: track.name,
        singer: track.singer,
        albumName: track.album,
        albumId: '',
        source: track.source,
        interval: track.interval,
        img: track.picUrl,
        types: []
      });
      if (track.id === song.id && track.source === song.source) {
        startIndex = i;
      }
    }
    if (songs.length === 0) {
      return;
    }
    const appState: MusicAppState =
      AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
    void OnlinePlayUtil.playList(appState, songs, startIndex, this.getUIContext());
  }

  /**
   * 华为账号卡片在本页面**不渲染**：它属于「登录平台音乐」那个面板
   * （`AccountManageSheet`，见 `HuaweiAccountCard`）。本页面是「用平台账号听歌」的
   * 歌单浏览页，混进来会让两件事看起来是一回事。
   */

  build() {
    Column() {
      if (this.groups.length === 0) {
        Column() {
          Text(this.loadingPlaylists ? '加载中...' : '请先在平台账号管理中登录平台账号')
            .fontSize(13)
            .fontColor($r('sys.color.font_tertiary'))
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll(this.pageScroller) {
          Column() {
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.groups, (group: AccountGroup) => {
                  Row() {
                    if (group.account.avatar.length > 0 && !this.avatarFailed.has(group.account.id)) {
                      Image(group.account.avatar)
                        .width(26)
                        .height(26)
                        .borderRadius(13)
                        .objectFit(ImageFit.Cover)
                        .backgroundColor(Color.White)
                        .onError(() => {
                          this.markAvatarFailed(group.account.id);
                        })
                    } else {
                      Text(group.account.nickname.length > 0 ? group.account.nickname.substring(0, 1) : '?')
                        .width(26)
                        .height(26)
                        .borderRadius(13)
                        .textAlign(TextAlign.Center)
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Color.White)
                        .backgroundColor(Color.White)
                    }
                    Text(sourceName(group.account.source))
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.selectedKey.startsWith(`${group.account.id}:`) ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ left: 6 })
                  }
                  .height(38)
                  .padding({ left: 8, right: 14 })
                  .borderRadius(19)
                  .backgroundColor(this.selectedKey.startsWith(`${group.account.id}:`) ? this.themeState.color : $r('sys.color.background_tertiary'))
                  .onClick(() => {
                    this.selectDefault(group);
                  })
                }, (group: AccountGroup) => group.account.id)
              }
              .padding({ left: 20, right: 20, top: 14, bottom: 8 })
            }
            .width('100%')
            .height(62)
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)

            Scroll() {
              Row({ space: 8 }) {
                if (this.currentAccountId.length > 0) {
                  Row() {
                    Text(this.dailyTitle(this.selectedSource))
                      .fontSize(12)
                      .fontWeight(this.selectedKey === `${this.currentAccountId}:daily` ? FontWeight.Medium : FontWeight.Normal)
                      .fontColor(this.selectedKey === `${this.currentAccountId}:daily` ? this.themeState.color : $r('sys.color.font_tertiary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .height(32)
                  .padding({ left: 14, right: 14 })
                  .borderRadius(16)
                  .backgroundColor(this.selectedKey === `${this.currentAccountId}:daily` ? $r('sys.color.background_tertiary') : $r('sys.color.background_tertiary'))
                  .onClick(() => {
                    const group: AccountGroup | undefined = this.findGroup(`${this.currentAccountId}:daily`);
                    if (group !== undefined) {
                      this.selectDaily(group.account);
                    }
                  })
                }
                ForEach(this.currentPlaylists, (playlist: PlaylistInfo) => {
                  Row() {
                    Text(playlist.name)
                      .fontSize(12)
                      .fontWeight(this.selectedKey === `${this.currentAccountId}:${playlist.id}` ? FontWeight.Medium : FontWeight.Normal)
                      .fontColor(this.selectedKey === `${this.currentAccountId}:${playlist.id}` ? this.themeState.color : $r('sys.color.font_tertiary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (playlist.total.length > 0) {
                      Text(playlist.total)
                        .fontSize(10)
                        .fontColor(this.selectedKey === `${this.currentAccountId}:${playlist.id}` ? this.themeState.color : $r('sys.color.font_tertiary'))
                        .margin({ left: 5 })
                    }
                  }
                  .height(32)
                  .padding({ left: 14, right: 14 })
                  .borderRadius(16)
                  .backgroundColor(this.selectedKey === `${this.currentAccountId}:${playlist.id}` ? $r('sys.color.background_tertiary') : $r('sys.color.background_tertiary'))
                  .onClick(() => {
                    const group: AccountGroup | undefined = this.findGroup(`${this.currentAccountId}:daily`);
                    if (group !== undefined) {
                      this.selectPlaylist(group.account, playlist);
                    }
                  })
                }, (playlist: PlaylistInfo) => `${this.currentAccountId}:${playlist.id}`)
              }
              .padding({ left: 20, right: 20, top: 6, bottom: 10 })
            }
            .width('100%')
            .height(54)
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)

            Row() {
              Column() {
                Text(this.selectedTitle.length > 0 ? this.selectedTitle : '平台音乐')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.selectedSource.length > 0 ? sourceName(this.selectedSource) : '')
                  .fontSize(11)
                  .fontColor($r('sys.color.font_tertiary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 6, bottom: 8 })

            if (this.currentGroupError().length > 0) {
              Text(this.currentGroupError())
                .width('100%')
                .fontSize(11)
                .fontColor(DANGER_COLOR)
                .padding({ left: 20, right: 20, bottom: 8 })
            }

            if (this.isLoading) {
              Column() {
                Text('加载中...')
                  .fontSize(12)
                  .fontColor($r('sys.color.font_tertiary'))
              }
              .width('100%')
              .padding({ top: 40, bottom: 40 })
            } else if (this.songs.length > 0) {
              ForEach(this.songs, (song: PlatformTrackInfo, index: number) => {
                Column() {
                  this.songRow(song)
                  if (index < this.songs.length - 1) {
                    Divider()
                      .strokeWidth(0.5)
                      .color($r('sys.color.comp_divider'))
                      .margin({ left: 66, right: 14 })
                  }
                }
                .width('100%')
              }, (song: PlatformTrackInfo) => `${song.id}_${song.removeId}`)
            } else {
              Column() {
                Text(this.statusText())
                  .fontSize(12)
                  .fontColor($r('sys.color.font_tertiary'))
                  .textAlign(TextAlign.Center)
                  .padding({ left: 16, right: 16 })
              }
              .width('100%')
              .padding({ top: 40, bottom: 40 })
            }
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: this.contentTopOffset })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
  }
}

@Builder
export function PlatformMusicPageBuilder(name: string, param: Object) {
  PlatformMusicPage({})
}
