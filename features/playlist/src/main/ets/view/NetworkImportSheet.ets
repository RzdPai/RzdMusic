/*
 * 「网络导入歌单」表单（**唯一一份实现**）。
 *
 * 为什么单独一个文件：
 *   这份表单原来只长在「全部歌单」页（`PlaylistsPage.OnlineImportSheet()`）里。2026-10-11 用户要求
 *   「我的」页歌单卡上的「歌单导入」**直接进从网络导入**（不要再弹一句提示、也不要先跳整页），
 *   所以把它抽成组件：两处（全部歌单页 / 我的页）共用同一套逻辑与版式，**不许出现第二份**。
 *
 * 它只管"选来源 + 粘贴链接 + 导入"，导入成功后：
 *   · 发 `onImported(name, count)` 给宿主（宿主自己决定 toast / 关弹窗 / 刷新列表）；
 *   · 发 `onClose()` 给宿主（取消）。
 * 数据落库仍走 `MusicStoreService.importPlaylist()`（唯一真源），拉取走
 * `SharePlaylistService.fetchPlaylist()`（features/player）。
 */

import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys, MusicStoreService, PlayedSongRecord, ThemeState } from 'musicbasic';
import { SharePlaylistService, SharePlaylistSource } from 'player';

/** 来源下拉的可选值（做成模块级常量：宿主页面若还要用，直接引用同一份）。 */
export const ONLINE_SOURCE_OPTIONS: string[] = ['网易云', 'QQ', '酷我', '酷狗', '咪咕'];
/** 与 {@link ONLINE_SOURCE_OPTIONS} 一一对应的枚举值。 */
export const ONLINE_SOURCE_VALUES: SharePlaylistSource[] =
  [SharePlaylistSource.Wy, SharePlaylistSource.Tx, SharePlaylistSource.Kw, SharePlaylistSource.Kg,
    SharePlaylistSource.Mg];

@ComponentV2
export struct NetworkImportSheet {
  /** 取消 / 关闭（宿主负责把 `bindSheet` 的开关置 false）。 */
  @Event onClose: () => void = (): void => {
  };
  /** 导入成功（宿主负责提示与刷新）。 */
  @Event onImported: (name: string, count: number) => void = (_name: string, _count: number): void => {
  };
  /** 取消时是否需要自己清空已粘贴的链接（宿主复用同一实例时保持 true）。 */
  @Param clearLinkOnClose: boolean = true;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** 网络导入选中的来源（网易云/QQ/酷我/酷狗/咪咕）。 */
  @Local onlineSource: string = 'wy';
  /** 网络导入粘贴的分享链接/ID。 */
  @Local onlineLink: string = '';
  /** 网络导入进行中。 */
  @Local onlineImporting: boolean = false;
  private store: MusicStoreService = MusicStoreService.getInstance();

  /** 从分享链接/ID 拉取歌单并导入（与原来那套逐字一致，只是把 toast 交回宿主）。 */
  private async importOnlinePlaylist(): Promise<void> {
    const link: string = this.onlineLink.trim();
    if (link.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请粘贴歌单分享链接或ID', duration: 2000 });
      return;
    }
    this.onlineImporting = true;
    try {
      const info = await SharePlaylistService.fetchPlaylist(link, this.onlineSource as SharePlaylistSource);
      if (info.songs.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '歌单为空或解析失败', duration: 2000 });
        return;
      }
      const songs: PlayedSongRecord[] = [];
      for (let i = 0; i < info.songs.length; i++) {
        const s = info.songs[i];
        const record = new PlayedSongRecord();
        record.songId = s.id;
        record.name = s.name;
        record.singer = s.artist;
        record.albumName = s.album;
        record.albumId = '';
        record.source = info.source;
        record.interval = this.fmtDuration(s.duration);
        record.img = info.coverUrl;
        record.time = Date.now();
        songs.push(record);
      }
      const name: string = info.name.length > 0 ? info.name : '导入的歌单';
      this.store.importPlaylist(name, songs);
      this.onlineLink = '';
      this.onImported(name, songs.length);
    } catch (e) {
      const err = e as Error;
      this.getUIContext().getPromptAction().showToast(
        { message: err.message ?? '导入失败，请检查链接', duration: 2500 });
    } finally {
      this.onlineImporting = false;
    }
  }

  /** 把秒数格式化为 "mm:ss"。 */
  private fmtDuration(seconds: number): string {
    const s: number = Math.max(0, Math.floor(seconds));
    const mm: number = Math.floor(s / 60);
    const ss: number = s % 60;
    return `${mm.toString().padStart(2, '0')}:${ss.toString().padStart(2, '0')}`;
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 8 }) {
        Text('来源')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
        Select(ONLINE_SOURCE_OPTIONS.map((v: string): SelectOption => {
          return { value: v };
        }))
          .selected(ONLINE_SOURCE_VALUES.indexOf(this.onlineSource as SharePlaylistSource))
          .value(ONLINE_SOURCE_OPTIONS[ONLINE_SOURCE_VALUES.indexOf(this.onlineSource as SharePlaylistSource)])
          .layoutWeight(1)
          .height(44)
          .fontColor($r('sys.color.font_primary'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor($r('sys.color.background_secondary'))
          .onSelect((index: number) => {
            this.onlineSource = ONLINE_SOURCE_VALUES[index];
          })
      }
      .width('100%')

      TextArea({ text: this.onlineLink, placeholder: '粘贴歌单分享链接或ID' })
        .width('100%')
        .height(96)
        .borderRadius($r('sys.float.corner_radius_level6'))
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.background_secondary'))
        .onChange((value: string) => {
          this.onlineLink = value;
        })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(44)
          .fontSize($r('sys.float.Body_L'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor($r('sys.color.background_secondary'))
          .fontColor($r('sys.color.font_tertiary'))
          .onClick(() => {
            if (this.clearLinkOnClose) {
              this.onlineLink = '';
            }
            this.onClose();
          })
        Button(this.onlineImporting ? '导入中…' : '导入')
          .layoutWeight(1)
          .height(44)
          .fontSize($r('sys.float.Body_L'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor(this.themeState.color)
          .fontColor($r('sys.color.font_on_primary'))
          .enabled(!this.onlineImporting)
          .onClick(() => {
            void this.importOnlinePlaylist();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 24 })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
