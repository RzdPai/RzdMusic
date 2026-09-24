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

import { AppStorageV2, ComponentContent, uiObserver } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { AppStorageKeys, BarScrollHelper, BreakpointType, MusicAppState, ThemeState } from 'musicbasic';
import { AmbientState, MusicStoreService, PlayedSongRecord, PlaylistDto, RouterUrlConstants, TitleBarConstants, ToplistRouteParam, buildTitleMaterial, getStatusBarTopVpFromWindowUtil, LocalCoverImage } from 'musicbasic';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';
import { lxSearch, SharePlaylistService, SharePlaylistSource } from 'player';
import { localMusic, LocalMusicImportState, localMusicImportState } from 'localmusic';
import { gunzipBytes } from '../util/GunzipUtil';
import { registerPlaylistRefresh, unregisterPlaylistRefresh } from '../util/PlaylistRefreshBus';
import { pickPlaylistCover } from '../util/PlaylistCoverUtil';
import type { CoverPickResult } from '../util/PlaylistCoverUtil';

/**
 * LXMusic playlist export JSON shape (one song entry).
 */
interface LxSongJsonMeta {
  songId: string;
  songmid: string;
  picUrl: string;
  albumName: string;
  albumId: string;
}

interface LxSongJson {
  name: string;
  singer: string;
  source: string;
  songId: string;
  songmid: string;
  albumName: string;
  albumId: string;
  interval: string;
  img: string;
  meta: LxSongJsonMeta;
}

/**
 * LXMusic playlist export JSON root shape.
 */
interface LxPlaylistJson {
  type: string;
  name: string;
  songs: LxSongJson[];
}

/**
 * Standalone playlist management page: create / rename / delete / reorder
 * playlists, local file and online link import, LXMusic export.
 */

/** 标题栏下拉菜单回调容器：全局 @Builder 无法访问组件实例，通过模块级回调中转。 */
let playlistsMenuAction: ((action: string) => void) | null = null;

/** 加号菜单内容：创建歌单 / 本地导入 / 网络导入。 */
@Builder
function playlistsAddMenuComponent() {
  Menu() {
    MenuItem({ content: '创建歌单' })
      .onClick(() => {
        if (playlistsMenuAction !== null) {
          playlistsMenuAction('create');
        }
      })
    MenuItem({ content: '本地导入' })
      .onClick(() => {
        if (playlistsMenuAction !== null) {
          playlistsMenuAction('local');
        }
      })
    MenuItem({ content: '网络导入' })
      .onClick(() => {
        if (playlistsMenuAction !== null) {
          playlistsMenuAction('online');
        }
      })
  }
  .width(220)
}

@ComponentV2
export struct PlaylistsPage {
  /** 「回到顶部」指令：壳层点了当前页签时递增（底部页签设计规范）。 */
  @Param scrollTopCommand: number = 0;
  /** Window breakpoint for the HDS home-style responsive title. */
  @Env(SystemProperties.BREAK_POINT) breakpointEnv: uiObserver.WindowSizeLayoutBreakpointInfo;
  /** Nav stack for opening history / favorites list pages. */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  @Local store: MusicStoreService = MusicStoreService.getInstance();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  @Local playlists: PlaylistDto[] = [];
  @Local listVisible: boolean = true;
  @Local showSheet: boolean = false;
  /** 当前弹窗类型：0=新建/重命名歌单，1=导入方式选择，2=网络导入表单。 */
  @Local activeSheet: number = 0;
  /** True when playlist reordering mode is active (drag rows to reorder). */
  @Local playlistSortMode: boolean = false;
  @Local newPlaylistName: string = '';
  @Local selectedPlaylist: PlaylistDto | undefined = undefined;
  @Local selectedPlaylistId: string = '';
  /** True while a playlist file is being imported. */
  @Local importing: boolean = false;
  /** Import progress text shown in the loading sheet. */
  @Local importProgress: string = '';
  /** 网络导入选中的来源（网易云/QQ/酷我/酷狗/咪咕）。 */
  @Local onlineSource: string = 'wy';
  /** 网络导入粘贴的分享链接/ID。 */
  @Local onlineLink: string = '';
  /** 网络导入进行中。 */
  @Local onlineImporting: boolean = false;
  /** 标题栏加号菜单图标 componentId（openMenu 锚点）。 */
  private readonly addMenuTargetId: string = 'playlists_add_menu_icon';
  /** 缓存菜单内容节点，避免每次点击重复创建。 */
  private addMenuNode: ComponentContent<Object> | null = null;
  /** Scroller bound to the HDS title bar so the scroll effect (gradient blur) can fire. */
  private pageScroller: Scroller = new Scroller();
  /** 全局播控状态：滚动联动双层底栏需要写 miniBarExpanded / hdsBarLayoutMode。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** 「本地音乐」入口要显示曲库首数：订阅它的导入状态，导入/删除后自动刷新。 */
  @Local localMusicState: LocalMusicImportState = localMusicImportState();
  /** 「本地音乐」路由名（与 features/localmusic 的 router_map.json 一致）。 */
  private static readonly LOCAL_MUSIC_ROUTE: string = 'LocalMusicPage';

  /**
   * 滚动联动双层底栏（上滑收起 / 下滑展开）。
   *
   * 用户要求「全都自动收起展开」—— 底栏是所有 Tab 共用的一个控件，
   * 只要有一个页面不接回调，就会出现"有的页面收、有的不收"。
   * @param offset 本帧滚动增量（vp）。
   */
  private onPageScrollFrame(offset: number): void {
    if (!BarScrollHelper.isEnabled()) {
      return;
    }
    BarScrollHelper.notifyScrollDelta(this.getUIContext(), this.appState, offset,
      this.breakpointEnv.widthBreakpoint as number);
  }


  aboutToAppear(): void {
    this.refresh();
    playlistsMenuAction = (action: string): void => {
      this.handleMenuAction(action);
    };
    // 注册显式刷新通道：歌单详情页增删歌曲后由弹层直接回调，不依赖 @Monitor
    registerPlaylistRefresh((): void => {
      this.refresh();
    });
  }

  aboutToDisappear(): void {
    playlistsMenuAction = null;
    unregisterPlaylistRefresh();
    if (this.addMenuNode !== null) {
      this.addMenuNode.dispose();
      this.addMenuNode = null;
    }
  }

  /** 加号按钮：锚定标题栏图标弹出菜单。 */
  private openAddMenu(): void {
    if (this.addMenuNode === null) {
      this.addMenuNode = new ComponentContent(this.getUIContext(), wrapBuilder(playlistsAddMenuComponent));
    }
    this.getUIContext().getPromptAction().openMenu(this.addMenuNode, { id: this.addMenuTargetId })
      .catch((err: BusinessError): void => {
        console.error('openMenu add failed: ' + err.code + ' ' + err.message);
      });
  }

  /** 标题栏菜单项回调分发。 */
  private handleMenuAction(action: string): void {
    if (action === 'create') {
      setTimeout((): void => {
        this.selectedPlaylistId = '';
        this.activeSheet = 0;
        this.showSheet = true;
      }, 400);
    } else if (action === 'local') {
      setTimeout((): void => {
        this.importPlaylistFile();
      }, 400);
    } else if (action === 'online') {
      setTimeout((): void => {
        this.onlineLink = '';
        this.activeSheet = 2;
        this.showSheet = true;
      }, 400);
    }
  }

  /** 壳层点了当前页签：滚回顶部（底部页签设计规范）。 */
  @Monitor('scrollTopCommand')
  onScrollTopCommand(): void {
    this.pageScroller.scrollEdge(Edge.Top);
  }

  @Monitor('store.playlistVersion')
  refresh(): void {
    const list: PlaylistDto[] = this.store.getPlaylists();
    let detail: string = '';
    for (let i: number = 0; i < list.length; i++) {
      detail += '[' + list[i].name + '=' + list[i].songs.length + ']';
    }
    this.appendImportLog('[列表刷新] v=' + this.store.playlistVersion + ' ' + detail);
    // 检测行内容是否变化（数量/名称/顺序）。Repeat 复用节点时 @Builder 参数可能停留在
    // 旧值（v30 实测：refresh 已执行、playlists 已更新，列表数量仍显示旧值），所以内容
    // 有变化时短暂摘除列表再挂回，强制整棵子树重建（与重命名路径同一手法）。
    const firstLoad: boolean = this.playlists.length === 0;
    let changed: boolean = list.length !== this.playlists.length;
    if (!changed) {
      for (let i: number = 0; i < list.length; i++) {
        // ⚠️ cover 必须参与比较：只换了封面的那次刷新，别的字段一模一样，
        //    少了这一条就会「store 已更新、界面不动」（用户反馈的「设置封面未生效」）。
        if (list[i].id !== this.playlists[i].id || list[i].name !== this.playlists[i].name ||
          list[i].songs.length !== this.playlists[i].songs.length ||
          list[i].cover !== this.playlists[i].cover) {
          changed = true;
          break;
        }
      }
    }
    this.playlists = list;
    if (changed && !firstLoad && this.listVisible) {
      this.listVisible = false;
      setTimeout((): void => {
        this.listVisible = true;
      }, 50);
    }
  }

  /** Serializes a playlist into the LXMusic export JSON format. */
  private toLxMusicJson(p: PlaylistDto): string {
    const songs: LxSongJson[] = [];
    for (let i: number = 0; i < p.songs.length; i++) {
      const s = p.songs[i];
      const songJson: LxSongJson = {
        name: s.name, singer: s.singer, source: s.source, songId: s.songId, songmid: s.songId,
        albumName: s.albumName, albumId: s.albumId, interval: s.interval, img: s.img,
        meta: {
          songId: s.songId, songmid: s.songId, picUrl: s.img,
          albumName: s.albumName, albumId: s.albumId
        }
      };
      songs.push(songJson);
    }
    const payload: LxPlaylistJson = {
      type: 'musicList',
      name: p.name,
      songs: songs
    };
    return JSON.stringify(payload);
  }

  /**
   * Converts a legacy playlist id to the id the current source expects.
   * Kugou needs a 32-char hex hash (old exports carry a numeric id or none);
   * Netease accepts its numeric id (empty ids are refilled via search).
   * Runs once at import time so playback never needs network lookups.
   * @returns The converted id (unchanged when conversion is not needed or fails).
   */
  private async convertLegacyId(source: string, songId: string, name: string, singer: string): Promise<string> {
    if (source === 'kw' && songId.startsWith('MUSIC_')) {
      return songId.substring(6);
    }
    if (source === 'kg' && !/^[0-9A-Fa-f]{32}$/.test(songId)) {
      try {
        const res = await lxSearch('kg', (name + ' ' + singer).trim(), 1, 10);
        for (let i: number = 0; i < res.list.length; i++) {
          if (res.list[i].name.trim() === name.trim() && res.list[i].songId.length === 32) {
            return res.list[i].songId;
          }
        }
        if (res.list.length > 0 && res.list[0].songId.length === 32) {
          return res.list[0].songId;
        }
        return songId;
      } catch (_err) {
        return songId;
      }
    }
    if (source === 'wy' && songId.length === 0) {
      try {
        const res = await lxSearch('wy', (name + ' ' + singer).trim(), 1, 10);
        if (res.list.length > 0 && res.list[0].songId.length > 0) {
          return res.list[0].songId;
        }
        return songId;
      } catch (_err) {
        return songId;
      }
    }
    return songId;
  }

  /** Parses an LXMusic playlist export JSON into a playlist (legacy ids converted). */
  private async parseLxMusicJson(text: string,
    onProgress?: (done: number, total: number) => void): Promise<PlaylistDto | undefined> {
    try {
      const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const type: string = root.type as string ?? '';
      let name: string = '';
      let songsArr: Object[] = [];
      if (type === 'playListPart' || type === 'playListPart_v2') {
        // LXMusic list part export: { type, data: { name, list: [...] } }
        const data = root.data as Record<string, Object> | undefined;
        if (data !== undefined) {
          name = (data.name as string ?? '').trim();
          songsArr = data.list as Object[] ?? [];
        }
      } else {
        // musicList export: { type, name, songs: [...] }
        name = (root.name as string ?? '').trim();
        songsArr = root.songs as Object[] ?? [];
      }
      const songs: PlayedSongRecord[] = [];
      for (let i: number = 0; i < songsArr.length; i++) {
        const o = songsArr[i] as Record<string, Object>;
        const meta = o.meta as Record<string, Object> | undefined;
        const record = new PlayedSongRecord();
        // New LXMusic song shape keeps id fields inside meta; older exports have them at top level.
        let songId: string = o.songId as string ?? '';
        if (songId.length === 0) {
          songId = o.songmid as string ?? '';
        }
        if (songId.length === 0 && meta !== undefined) {
          songId = meta.songId as string ?? '';
        }
        if (songId.length === 0 && meta !== undefined) {
          songId = meta.songmid as string ?? '';
        }
        let img: string = o.img as string ?? '';
        if (img.length === 0 && meta !== undefined) {
          img = meta.picUrl as string ?? '';
        }
        let albumName: string = o.albumName as string ?? '';
        if (albumName.length === 0 && meta !== undefined) {
          albumName = meta.albumName as string ?? '';
        }
        let albumId: string = o.albumId as string ?? '';
        if (albumId.length === 0 && meta !== undefined) {
          albumId = meta.albumId as string ?? '';
        }
        // Fallback: top-level id like "kw_3226362" encodes source_songId.
        if (songId.length === 0) {
          const topId: string = o.id as string ?? '';
          const sep: number = topId.indexOf('_');
          if (sep > 0 && sep < topId.length - 1) {
            songId = topId.substring(sep + 1);
          }
        }
        record.songId = songId;
        record.name = o.name as string ?? '';
        record.singer = o.singer as string ?? '';
        record.albumName = albumName;
        record.albumId = albumId;
        record.source = o.source as string ?? '';
        record.interval = o.interval as string ?? '';
        record.img = img;
        record.time = Date.now();
        // Keep songs even when the id field is missing from legacy exports;
        // convert kg/wy legacy ids once so playback needs no network lookups.
        if (record.source.length > 0) {
          const nameText: string = typeof record.name === 'string' ? record.name : '';
          const singerText: string = typeof record.singer === 'string' ? record.singer : '';
          record.songId = await this.convertLegacyId(record.source, record.songId, nameText, singerText);
          songs.push(record);
        }
        if (onProgress !== undefined) {
          onProgress(i + 1, songsArr.length);
        }
      }
      const p = new PlaylistDto();
      p.id = String(Date.now());
      p.name = name.length > 0 ? name : '导入的歌单';
      p.createTime = Date.now();
      p.songs = songs;
      return p;
    } catch (_err) {
      return undefined;
    }
  }

  /**
   * Decompresses a gzip payload (.lxmc files) using the built-in RFC1951
   * inflater (the SDK exposes no native gunzip).
   */
  private gunzipData(gz: Uint8Array): Uint8Array {
    return gunzipBytes(gz);
  }

  /** Appends a marker line to the shared run log (visible in settings). */
  private appendImportLog(message: string): void {
    const log: string = AppStorage.get<string>('lxPlayLog') ?? '';
    const now: Date = new Date();
    const time: string = now.getHours().toString().padStart(2, '0') + ':' +
      now.getMinutes().toString().padStart(2, '0') + ':' +
      now.getSeconds().toString().padStart(2, '0');
    AppStorage.setOrCreate('lxPlayLog', (log + '[' + time + '] ' + message + '\n').slice(-20000));
  }

  /** Parses an imported file: plain JSON or gzip-compressed .lxmc. */
  private async parseImportFile(bytes: Uint8Array,
    onProgress?: (done: number, total: number) => void): Promise<PlaylistDto | undefined> {
    this.appendImportLog('[导入] 文件大小=' + bytes.length +
      ' 头字节=' + bytes[0].toString(16) + ' ' + bytes[1].toString(16) + ' ' + bytes[2].toString(16));
    // Try plain JSON first.
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    const plain: string = decoder.decodeToString(bytes);
    let p = await this.parseLxMusicJson(plain, onProgress);
    if (p !== undefined) {
      this.appendImportLog('[导入] 明文 JSON 解析成功 歌曲数=' + p.songs.length);
      return p;
    }
    this.appendImportLog('[导入] 明文 JSON 失败，尝试 gzip');
    // Fall back to gzip (.lxmc) and retry.
    try {
      const inflate: Uint8Array = this.gunzipData(bytes);
      this.appendImportLog('[导入] gzip 解压成功 大小=' + inflate.length);
      const text: string = decoder.decodeToString(inflate);
      p = await this.parseLxMusicJson(text, onProgress);
      this.appendImportLog('[导入] gzip JSON 解析 ' + (p !== undefined ? '成功 歌曲数=' + p.songs.length : '失败'));
      return p;
    } catch (e) {
      this.appendImportLog('[导入] gzip 解压异常: ' + JSON.stringify(e).substring(0, 200));
      return undefined;
    }
  }

  /** Exports the selected playlist to a user-chosen file (LXMusic format). */
  private exportPlaylist(): void {
    const p = this.selectedPlaylist;
    if (p === undefined) {
      return;
    }
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (ctx === undefined) {
      return;
    }
    try {
      const safeName: string = p.name.replace(/[\\/:*?"<>|]/g, '_');
      const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const saveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = ['lx_' + safeName + '_' + p.id + '.json'];
      docPicker.save(saveOptions).then((uris: string[]): void => {
        if (uris.length === 0) {
          return;
        }
        try {
          const encoder: util.TextEncoder = new util.TextEncoder();
          const data: Uint8Array = encoder.encodeInto(this.toLxMusicJson(p));
          const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
          fs.writeSync(file.fd, data.buffer as ArrayBuffer);
          fs.closeSync(file);
          this.getUIContext().getPromptAction().showToast({ message: '已导出歌单', duration: 2000 });
        } catch (_err) {
          this.getUIContext().getPromptAction().showToast({ message: '导出失败', duration: 2000 });
        }
      }).catch((_err: Object): void => {
        // user cancelled
      });
    } catch (_err) {
      this.getUIContext().getPromptAction().showToast({ message: '无法打开保存选择器', duration: 2000 });
    }
  }

  private readonly onlineSourceOptions: string[] = ['网易云', 'QQ', '酷我', '酷狗', '咪咕'];
  private readonly onlineSourceValues: SharePlaylistSource[] =
    [SharePlaylistSource.Wy, SharePlaylistSource.Tx, SharePlaylistSource.Kw, SharePlaylistSource.Kg, SharePlaylistSource.Mg];

  /** 把秒数格式化为 "mm:ss"。 */
  private fmtDuration(seconds: number): string {
    const s: number = Math.max(0, Math.floor(seconds));
    const mm: number = Math.floor(s / 60);
    const ss: number = s % 60;
    return `${mm.toString().padStart(2, '0')}:${ss.toString().padStart(2, '0')}`;
  }

  /** 从分享链接/ID 拉取歌单并导入。 */
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
      this.showSheet = false;
      this.onlineLink = '';
      this.getUIContext().getPromptAction().showToast(
        { message: '已导入歌单「' + name + '」(' + songs.length + ' 首)', duration: 2500 });
    } catch (e) {
      const err = e as Error;
      this.getUIContext().getPromptAction().showToast(
        { message: err.message ?? '导入失败，请检查链接', duration: 2500 });
    } finally {
      this.onlineImporting = false;
    }
  }

  /** Imports an LXMusic playlist JSON file chosen by the user. */
  private importPlaylistFile(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (ctx === undefined) {
      return;
    }
    try {
      const documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.select({ maxSelectNumber: 1 }).then(async (uris: string[]) => {
        if (uris.length === 0) {
          return;
        }
        try {
          const file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
          const stat = fs.statSync(uris[0]);
          const buf: ArrayBuffer = new ArrayBuffer(stat.size);
          fs.readSync(file.fd, buf);
          fs.closeSync(file);
          this.importing = true;
          this.importProgress = '正在解析文件…';
          const p = await this.parseImportFile(new Uint8Array(buf), (done: number, total: number): void => {
            this.importProgress = '正在导入 ' + done + '/' + total;
          });
          this.importing = false;
          if (p !== undefined) {
            this.store.importPlaylist(p.name, p.songs);
            this.getUIContext().getPromptAction().showToast(
              { message: '已导入歌单「' + p.name + '」(' + p.songs.length + ' 首)', duration: 2500 });
          } else {
            this.getUIContext().getPromptAction().showToast({ message: '无法解析该歌单文件', duration: 2000 });
          }
        } catch (_err) {
          this.importing = false;
          this.getUIContext().getPromptAction().showToast({ message: '导入失败', duration: 2000 });
        }
      }).catch((_err: Object): void => {
        // user cancelled
      });
    } catch (_err) {
      this.getUIContext().getPromptAction().showToast({ message: '无法打开文件选择器', duration: 2000 });
    }
  }

  /** Renames the selected playlist. */
  private renamePlaylist(): void {
    const p = this.selectedPlaylist;
    if (p === undefined) {
      return;
    }
    this.newPlaylistName = p.name;
    this.selectedPlaylistId = p.id;
    this.activeSheet = 0;
    this.showSheet = true;
  }

  /** Deletes the selected playlist. */
  private deletePlaylist(): void {
    const p = this.selectedPlaylist;
    if (p !== undefined) {
      this.store.deletePlaylist(p.id);
    }
  }

  /** Enters playlist reordering mode (drag to reorder). */
  private enterPlaylistSortMode(): void {
    this.playlistSortMode = true;
  }

  /** Exits playlist reordering mode and persists the new order. */
  private exitPlaylistSortMode(): void {
    this.playlistSortMode = false;
  }

  /** Persists the current playlist order after a drag reorder. */
  private persistPlaylistOrder(): void {
    const ids: string[] = [];
    for (let i = 0; i < this.playlists.length; i++) {
      ids.push(this.playlists[i].id);
    }
    this.store.reorderPlaylists(ids);
  }

  /** 拖动排序回调：仅排序模式下应用新顺序。 */
  private movePlaylist(from: number, to: number): void {
    if (!this.playlistSortMode) {
      return;
    }
    if (from === to || from < 0 || to < 0 || from >= this.playlists.length || to >= this.playlists.length) {
      return;
    }
    const moved: PlaylistDto[] = this.playlists.splice(from, 1);
    this.playlists.splice(to, 0, moved[0]);
    this.playlists = [...this.playlists];
  }

  /** Frosted glass strength of the playlist row popup, following the ambient light level. */
  private playlistMenuBlur(): BlurStyle {
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

  /** 我的歌单 section header：排序 + 新增（仅收藏栏显示）。 */
  @Builder
  private PlaylistsHeader() {
    Row() {
      Blank()
      if (this.playlistSortMode) {
        Text('完成')
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeState.color)
          .onClick(() => {
            this.persistPlaylistOrder();
            this.exitPlaylistSortMode();
          })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 12 })
  }

  /**
   * 「本地音乐」入口行（放在歌单页面里，按需求：本地音乐归歌单页面）。
   *
   * 本地音乐是一个独立 HAR（`features/localmusic`），它自带路由页 `LocalMusicPage`
   * （见该模块的 `router_map.json`），所以这里只需要一个入口把路由推出去，
   * **不**在本文件里写导入/列表逻辑。
   *
   * 副标题显示曲库首数：读 `localMusicImportState().version` 让它跟着
   * "导入 / 删除 / 歌词匹配"一起刷新（那个字段就是为这种订阅准备的）。
   */
  @Builder
  private LocalMusicEntry() {
    Row({ space: 12 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize(18)
          .fontColor([this.themeState.color])
      }
      .width(44)
      .height(44)
      .borderRadius($r('sys.float.corner_radius_level3'))
      .backgroundColor($r('sys.color.background_tertiary'))
      .justifyContent(FlexAlign.Center)

      Column({ space: 2 }) {
        Text('本地音乐')
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.localMusicSubtitle())
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      // 路由名与 localmusic 模块 router_map.json 里的 name 一致
      this.pageIndexInfos.pushPathByName(PlaylistsPage.LOCAL_MUSIC_ROUTE, null);
    })
  }

  /**
   * 给某个歌单设置自定义封面（相册选图 → 拷进沙箱 → 写进歌单）。
   *
   * 写库会 +playlistVersion，`@Monitor('store.playlistVersion')` 里的 refresh() 会重读列表，
   * 封面立刻就能看到；详情页大图也用同一个字段。
   */
  private async pickCoverFor(p: PlaylistDto): Promise<void> {
    const result: CoverPickResult = await pickPlaylistCover(p.id);
    if (!result.ok) {
      this.getUIContext().getPromptAction().showToast({ message: result.message, duration: 2000 });
      return;
    }
    MusicStoreService.getInstance().setPlaylistCover(p.id, result.uri);
    this.appendImportLog('[封面] 歌单 ' + p.name + ' -> ' + result.uri);
    this.getUIContext().getPromptAction().showToast({ message: result.message, duration: 2000 });
    // 显式重建列表：只换封面时行 key 之外的东西没变，靠 @Monitor 里的 changed 判断有时
    // 不够稳（Repeat 复用节点），这里照「重命名」那套手法把列表短暂摘掉再挂回。
    if (this.listVisible) {
      this.listVisible = false;
      setTimeout((): void => {
        this.listVisible = true;
      }, 50);
    }
  }

  /** @returns 「本地音乐」入口的副标题：有歌显示首数，没有就提示导入。 */  private localMusicSubtitle(): string {
    // 读一下 version：导入/删除/匹配后自动重算
    const version: number = this.localMusicState.version;
    const count: number = localMusic.count();
    if (count > 0) {
      return `${count} 首` + (version >= 0 ? '' : '');
    }
    return '导入设备音频（选文件 / 选文件夹）';
  }

  /** One playlist row: cover (custom/source cover first, else first song's album art), name, count, chevron. */
  @Builder
  private PlaylistRow(p: PlaylistDto) {
    Row({ space: 12 }) {
      // 歌单封面优先级：歌单自己的封面（自定义 / 在线导入时带过来的）> 第一首歌的专辑图 > 灰底音符占位
      // 自定义封面是沙箱文件 → 交给 LocalCoverImage 自己解码成 PixelMap 显示
      if (p.cover.length > 0) {
        LocalCoverImage({ src: p.cover, imageWidth: 44, imageHeight: 44, radius: 8 })
      } else if (p.songs.length > 0 && p.songs[0].img.length > 0) {
        Image(p.songs[0].img)
          .width(44)
          .height(44)
          .borderRadius($r('sys.float.corner_radius_level3'))
          .objectFit(ImageFit.Cover)
      } else {
        Row() {
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(16)
            .fontColor([$r('sys.color.font_tertiary')])
        }
        .width(44)
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level3'))
        .backgroundColor($r('sys.color.background_tertiary'))
        .justifyContent(FlexAlign.Center)
      }
      Column({ space: 4 }) {
        Text(p.name)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Regular)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(p.songs.length + ' 首')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.playlistSortMode) {
        SymbolGlyph($r('sys.symbol.line_3_horizontal'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_tertiary')])
          .margin({ right: 4 })
      } else {
        SymbolGlyph($r('sys.symbol.dot_grid_1x2_circle'))
          .fontSize(18)
          .fontColor([$r('sys.color.font_tertiary')])
          .margin({ right: 4 })
          .bindMenu([
            {
              value: $r('app.string.mine_playlist_export'),
              action: (): void => {
                this.selectedPlaylist = p;
                this.exportPlaylist();
              }
            },
            {
              // 自定义封面：相册选图 → 拷进沙箱 → 写进歌单（详情页大图与这里都会用它）
              value: '设置歌单封面',
              action: (): void => {
                void this.pickCoverFor(p);
              }
            },
            {
              value: '移除自定义封面',
              action: (): void => {
                MusicStoreService.getInstance().setPlaylistCover(p.id, '');
                this.getUIContext().getPromptAction().showToast({ message: '已移除自定义封面', duration: 2000 });
              }
            },
            {
              value: $r('app.string.mine_playlist_rename'),
              action: (): void => {
                this.selectedPlaylist = p;
                this.renamePlaylist();
              }
            },
            {
              value: $r('app.string.mine_playlist_delete'),
              action: (): void => {
                this.selectedPlaylist = p;
                this.deletePlaylist();
              }
            }
          ], {
            backgroundBlurStyle: this.playlistMenuBlur()
          })
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([$r('sys.color.font_tertiary')])
      }
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(() => {
      if (this.playlistSortMode) {
        return;
      }
      const param = new ToplistRouteParam();
      param.sectionType = 'playlist';
      param.playlistId = p.id;
      param.listTitle = p.name;
      // 本地歌单自身封面（新建的为空，详情页显示占位图；不用第一首歌的封面顶替）
      param.listCover = p.cover;
      this.pageIndexInfos.pushPathByName(RouterUrlConstants.PLAYLIST_DETAIL, param);
    })
  }

  /** 网络导入表单弹窗：选来源 + 粘贴链接。 */
  @Builder
  private OnlineImportSheet() {
    Column({ space: 16 }) {
      Row({ space: 8 }) {
        Text('来源')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
        Select(this.onlineSourceOptions.map((v: string): SelectOption => { return { value: v }; }))
          .selected(this.onlineSourceValues.indexOf(this.onlineSource as SharePlaylistSource))
          .value(this.onlineSourceOptions[this.onlineSourceValues.indexOf(this.onlineSource as SharePlaylistSource)])
          .layoutWeight(1)
          .height(44)
          .fontColor($r('sys.color.font_primary'))
          .borderRadius($r('sys.float.corner_radius_level6'))
          .backgroundColor($r('sys.color.background_secondary'))
          .onSelect((index: number) => {
            this.onlineSource = this.onlineSourceValues[index];
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
            this.showSheet = false;
            this.onlineLink = '';
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

  /**
   * bindSheet 原生标题（X 关闭按钮由系统保证跟标题水平对齐，与「添加到歌单」弹层同款）。
   * activeSheet 2 = 网络导入；0 = 新建/重命名（按 selectedPlaylistId 区分）。
   */
  private mainSheetTitle(): SheetTitleOptions {
    if (this.activeSheet === 2) {
      return { title: '网络导入歌单' };
    }
    if (this.selectedPlaylistId.length > 0) {
      return { title: $r('app.string.mine_playlist_rename') };
    }
    return { title: $r('app.string.mine_playlist_new') };
  }

  /** 统一底部弹窗：按 activeSheet 渲染对应内容（新建/重命名、网络导入表单）。 */
  @Builder
  private MainSheet() {
    if (this.activeSheet === 0) {
      this.NewPlaylistSheet()
    } else if (this.activeSheet === 2) {
      this.OnlineImportSheet()
    }
  }

  /** Import progress sheet shown while a large playlist is being imported. */
  @Builder
  private ImportProgressSheet() {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(this.themeState.color)
      Text(this.importProgress)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
      Text('正在导入歌单，请稍候…')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .padding({ top: 24, bottom: 24 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /** New-playlist name input sheet (also used for rename when selectedPlaylistId is set). 标题由 bindSheet 原生 title 提供。 */
  @Builder
  private NewPlaylistSheet() {
    Column({ space: 12 }) {
      TextInput({ text: this.newPlaylistName, placeholder: $r('app.string.mine_playlist_name_placeholder') })
        .width('100%')
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level6'))
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.newPlaylistName = value;
        })
      Button($r('app.string.mine_playlist_confirm'))
        .width('100%')
        .height(44)
        .fontSize($r('sys.float.Body_M'))
        .borderRadius($r('sys.float.corner_radius_level6'))
        .backgroundColor(this.themeState.color)
        .fontColor($r('sys.color.font_on_primary'))
        .onClick(() => {
          const name: string = this.newPlaylistName.trim();
          if (name.length === 0) {
            return;
          }
          if (this.selectedPlaylistId.length > 0) {
            const targetId: string = this.selectedPlaylistId;
            this.store.renamePlaylist(targetId, name);
            for (let i = 0; i < this.playlists.length; i++) {
              if (this.playlists[i].id === targetId) {
                this.playlists[i].name = name;
                break;
              }
            }
            this.selectedPlaylistId = '';
            this.newPlaylistName = '';
            this.showSheet = false;
            this.listVisible = false;
            setTimeout((): void => {
              this.listVisible = true;
            }, 60);
          } else {
            MusicStoreService.getInstance().createPlaylist(name);
            this.newPlaylistName = '';
            this.showSheet = false;
            this.playlists = this.store.getPlaylists();
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 24 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /** HDS title bar with system material and gradient blur. */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        title: {
          mainTitle: '歌单',
          mainTitleSize: TitleSize.TITLE_ML
        },
        menu: {
          value: [
            {
              content: {
                label: 'sort',
                icon: $r('sys.symbol.list_checkmask'),
                isEnabled: true,
                action: (): void => {
                  this.enterPlaylistSortMode();
                }
              }
            },
            {
              content: {
                label: 'add',
                icon: $r('sys.symbol.plus'),
                isEnabled: true,
                componentId: this.addMenuTargetId,
                action: (): void => {
                  this.openAddMenu();
                }
              }
            }
          ]
        }
      }
    };
  }

  build() {
    HdsNavDestination() {
      Stack() {
        if (this.listVisible) {
          List({ space: 2, scroller: this.pageScroller }) {
            ListItem() {
              this.PlaylistsHeader()
            }
            // 「本地音乐」入口：放在歌单列表最上面（需求：本地音乐放歌单页面）
            ListItem() {
              this.LocalMusicEntry()
            }
            Repeat<PlaylistDto>(this.playlists)
              .each((obj: RepeatItem<PlaylistDto>) => {
                ListItem() {
                  this.PlaylistRow(obj.item)
                }
              })
              // key 必须含 songs.length、首曲封面**与歌单自己的封面**：添加/删除歌曲、
              // 首曲封面变化、或换了自定义封面时都要强制重建行，数量/封面才会刷新。
              // （漏掉 p.cover 就是「设置封面之后列表不生效」的原因：Repeat 复用旧节点，
              //   属性停在旧值，重启前一直看着旧封面。）
              .key((item: PlaylistDto) => item.id + '_' + item.name + '_' + item.songs.length + '_' +
              item.cover + '_' + (item.songs.length > 0 ? item.songs[0].img : ''))
              .onMove((from: number, to: number): void => {
                this.movePlaylist(from, to);
              })
            if (this.playlists.length === 0) {
              ListItem() {
                Text($r('app.string.mine_playlist_empty'))
                  .fontSize($r('sys.float.Caption_L'))
                  .fontColor($r('sys.color.font_tertiary'))
                  .width('100%')
                  .padding({ top: 16, bottom: 16 })
              }
            }
            ListItem() {
              Column()
                .height(48)
                .width('100%')
            }
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .clip(false)
          // 滚动联动双层底栏：上滑收起、下滑展开（与首页/我的/设置一致）
          .onScrollFrameBegin((offset: number): OnScrollFrameBeginHandlerResult => {
            this.onPageScrollFrame(offset);
            return { offsetRemain: offset };
          })
          .contentStartOffset(getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP)
          .divider({
            strokeWidth: 0.5,
            color: $r('sys.color.comp_divider'),
            startMargin: 16,
            endMargin: 16
          })
          .padding({
            left: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint),
            right: new BreakpointType(16, 24, 32, 32).getValue(this.breakpointEnv.widthBreakpoint)
          })
          .bindSheet($$this.importing, this.ImportProgressSheet(), {
            height: 180,
            dragBar: false,
            showClose: false,
            backgroundColor: $r('sys.color.background_secondary')
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(false)
    .hideBackButton(true)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
    .bindSheet($$this.showSheet, this.MainSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: false,
      showClose: true,
      // 原生 title：标题左对齐 + 右上角 X 关闭，与「添加到歌单」弹层同款
      title: this.mainSheetTitle(),
      backgroundColor: $r('sys.color.background_secondary'),
      onWillDismiss: (action: DismissSheetAction) => {
        action.dismiss();
        this.showSheet = false;
        this.selectedPlaylistId = '';
        this.newPlaylistName = '';
      }
    })
  }
}
