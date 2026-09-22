/**
 * 对应 listen 的 entry/src/main/ets/core/sync/LocalLibrary.ets（音乐库适配层）
 *
 * 为什么不是照搬（逐条讲清与 listen 的差异）：
 *
 * 1) 数据主人换成 MusicStoreService。
 *    listen 里 LocalLibrary 自己持有 loveList / defaultList / userList 并按洛雪线上格式落盘。
 *    RzdMusic 里「收藏 / 歌单 / 播放队列」的真实数据都在 musicbasic 的 MusicStoreService
 *    （收藏 = preferences 的 favorite_list，歌单 = playlists，试听列表 = last_queue 快照）。
 *    所以本文件变成「适配器」：
 *      - ingest()  ：把 MusicStoreService 的最新内容并进协议镜像 this.data（读方向）；
 *      - project() ：把协议镜像写回 MusicStoreService（远端数据到达后的写方向）。
 *    对外接口与 listen 一致，SyncClient 一行都不用改。
 *
 * 2) 为什么仍保留一份「协议镜像」（this.data，落盘 list.json，与 listen 相同）。
 *    MusicStoreService 的 PlaylistDto 只有 id/name/createTime/songs，**存不下**洛雪列表的
 *    lx id / source / sourceListId / locationUpdateTime；而服务端的快照 key 是「列表 JSON 的
 *    md5」，这些字段必须原样回写，否则每次重连都会被判成「不一致」、反复弹合并框。
 *    因此分工是：内容（歌曲、歌单成员、顺序、收藏内容、队列内容）以 MusicStoreService 为准，
 *    协议字段（列表 id 与元数据）以本文件的镜像为准，两侧靠 ingest()/project() 对账。
 *
 * 3) 歌单 id 映射（playlist_meta.json）。
 *    MusicStoreService.createPlaylist/importPlaylist 的歌单 id 是 `String(Date.now())`，没法指定；
 *    而远端歌单（其它设备 / 官方客户端建的）的 lx id 必须原样保留（理由同上：md5）。
 *    所以用 SyncStore 新增的 loadPlaylistMeta()/savePlaylistMeta() 记一份
 *    「本机歌单 id -> { lxId, source, sourceListId, locationUpdateTime }」。
 *    这是相对 listen 唯一的结构性新增（listen 的歌单 id 就是洛雪 id，不需要映射）。
 *
 * 4) round-trip 归一。
 *    远端歌曲先过一次 fromLxMusicInfo -> toLxMusicInfo 才进镜像。这样镜像里的每首歌都与
 *    PlayedSongRecord 能无损互转，ingest() 反复对账不会产生 md5 漂移（listen 直接原样保存远端
 *    meta，因为它内部形态保留了 musicInfo；RzdMusic 的 PlayedSongRecord 只剩 songId 字符串）。
 *
 * 5) mirrorToSession()。
 *    listen 用它把库数据镜像进 PlaySession（会话）。RzdMusic 没有会话类、也不允许同步模块依赖
 *    player，所以改成 project() + 递增 @Trace libraryVersion：界面观察 libraryVersion 重新读数据。
 *    远端对「试听列表（= 播放队列）」的改动只落到 last_queue 快照上；正在播放的队列由 player
 *    自己恢复 / 持久化，同步侧不去改运行中的播放状态（listen 会直接替换会话队列）。这是本移植版
 *    与 listen 的行为差异之一。
 *
 * 6) 上行入口。
 *    listen 由 PlaySession 通过 LibrarySink 回调 onLocalListsChanged()。RzdMusic 侧提供
 *    onLocalListsChanged() / notifyPlaylistChanged(listId) / notifyFavoritesChanged() /
 *    notifyQueueChanged()（后三个是**主动上报入口**，由界面或服务在改完 MusicStoreService 后调用）。
 *    它们都走同一条路：ingest() + 与改动前的镜像做差分，只把真正变了的列表上行。
 *
 * 7) 删掉的部分（features/playlist / features/setting 直接操作 MusicStoreService，不走这里）：
 *    createPlaylist / renamePlaylist / removePlaylists / addMusicToPlaylist / removeMusicFromPlaylist /
 *    overwritePlaylistMusic / importPlaylist / playlistBySourceListId / playlistSongs(id) 的写侧 /
 *    isBuiltinPlaylist / hasPlaylist。它们在 listen 里是界面用来改歌单的，RzdMusic 里界面直接改
 *    MusicStoreService 再调 notify*，留着就是第二条写路径，容易和 store 分叉。
 *    唯一保留的展示读取是 playlistSummaries() / playlistSongs() / favoriteSongs()（把本地歌侧表
 *    合并在最前面）。
 *
 * 8) 本地歌（source === 'local'）依旧不参与同步。
 *    上行前由 SyncConvert.isSyncable/toLxMusicInfo 过滤（parseOldMusicInfo 对 'local' 返回 null），
 *    因此本地歌只会出现在「展示读取」的合并里（本地歌排在前面，与「新加的歌排最前」一致），
 *    绝不会进协议镜像 —— 否则会改掉 md5、破坏与服务端的快照比对。
 *
 * 9) 不喜欢的歌曲规则（dislikeList）是纯文本，RzdMusic 没有对应存储，继续用 SyncStore 落盘
 *    （dislike.json），与 listen 完全一致。
 *
 * 10) 日志：listen 的 hilog 换成 musicbasic 的 appendPlayLog / appendError。
 */

import { common } from '@kit.AbilityKit';
import { appendError, appendPlayLog, getAppRuntime, MusicStoreService, PlayedSongRecord, PlaylistDto,
  SongItem } from 'musicbasic';
import { localMusic, LOCAL_SOURCE, LOVE_LIST_ID } from 'localmusic';
import { fromLxMusicInfo, isSyncable, toLxMusicInfo } from './SyncConvert';
import { defaultListData, SyncStore } from './SyncStore';
import { DISLIKE_NAME_ALIAS, DISLIKE_NAME_SEP, LIST_ID_LOVE, LxDislikeMusicInfo, LxListCreateData,
  LxListData, LxListMusicAddData, LxListMusicMoveData, LxListMusicOverwriteData, LxListMusicRemoveData,
  LxListMusicUpdatePositionData, LxListUpdatePositionData, LxMusicInfoNew, LxMusicUpdateItem, LxSyncAction,
  LxUserListInfo, LxUserListInfoFull } from './SyncTypes';
import { toMD5 } from './SyncCrypto';

const TAG: string = 'LocalLibrary';

/** 上行出口：把本地改动的动作发给服务端 */
export type SyncActionSink = (action: LxSyncAction, kind: string) => void;

/** 音乐库规模（设置页展示用） */
export interface LibrarySummary {
  playlists: number;
  songs: number;
}

/** 歌单摘要：id = 本机歌单 id（侧表 / 界面用），lxId = 洛雪协议里的列表 id */
export interface LxPlaylistSummary {
  id: string;
  lxId: string;
  name: string;
  count: number;
}

/**
 * 歌单的协议元数据
 *
 * MusicStoreService 的 PlaylistDto 只有 id/name/createTime/songs，下列字段只能存在这里。
 * 它们全都参与「列表 JSON 的 md5」（服务端快照 key），丢一个就会每次重连都被判成不一致。
 */
interface LxPlaylistMeta {
  /** 洛雪列表 id（远端歌单的 id 与本机歌单 id 不同，必须原样保留） */
  lxId: string;
  /** 洛雪列表的 locationUpdateTime（服务端合并冲突时按它比新旧） */
  locationUpdateTime: number | null;
  source?: string;
  sourceListId?: string;
}

/** playlist_meta.json 的文件形态 */
interface PlaylistMetaFile {
  version: number;
  /** 本机歌单 id -> 协议元数据 */
  playlists: Record<string, LxPlaylistMeta>;
}

/** 播放队列落盘快照（与 features/player 的 MediaService.QueueSnapshot 同构，只读其中在线歌） */
interface QueueSnapshot {
  /** 队列里的在线歌（本地歌在 localIds 里） */
  online: PlayedSongRecord[];
  /** 队列里本地歌的条目 id（player 的 appState.playQueueIds），同步侧只负责原样保留 */
  localIds: number[];
  /** 当前播放位置在整条队列里的下标 */
  index: number;
}

/** 队列读取结果：hasSnapshot 用来区分「没有快照」与「快照是空的」 */
interface QueueReadResult {
  hasSnapshot: boolean;
  online: PlayedSongRecord[];
}

/**
 * 本地音乐库（适配层）
 *
 * 协议镜像 this.data 的内容按洛雪的线上格式（LxListData）保存：
 *   defaultList —— 试听列表（本移植版里就是播放队列）
 *   loveList    —— 我的收藏
 *   userList    —— 自建歌单（含歌曲）
 * 而真实数据（MusicStoreService 里的收藏 / 歌单 / last_queue 快照）通过 ingest()/project() 双向对账。
 */
@ObservedV2
export class LocalLibrary {
  private static instance: LocalLibrary | null = null;

  static getInstance(): LocalLibrary {
    if (LocalLibrary.instance === null) {
      LocalLibrary.instance = new LocalLibrary();
    }
    return LocalLibrary.instance;
  }

  /**
   * 音乐库版本号（代替 listen 的 K_LIBRARY_VERSION / mirrorToSession）
   *
   * 远端数据到达（applyRemoteListData/applyRemoteListAction）或本地改动后 +1，
   * 界面观察它重新读一次数据。
   */
  @Trace public libraryVersion: number = 0;

  private store: SyncStore = new SyncStore();
  private data: LxListData = defaultListData();
  private dislike: string = '';
  /** 本机歌单 id -> 协议元数据（见文件头第 3 条） */
  private metas: Record<string, LxPlaylistMeta> = {};
  /** 本地是否已经有一份库（没有则说明是首次安装） */
  private initialized: boolean = false;
  /** 正在应用远端数据时抑制上行，避免自己发的动作绕回来 */
  private applying: boolean = false;
  /**
   * 存储与 MusicStoreService 是否可用
   *
   * ingest() 是「读 store 并覆盖镜像」，一旦 store 还不可用（没有 context，
   * getFavorites()/getPlaylists() 只会返回空数组），把它当成「用户清空了收藏」就会把镜像清掉、
   * 还会把空数据上行。所以只有确实拿到 context 时才允许对账。
   */
  private ready: boolean = false;
  /** 上一次为远端歌单新建本机歌单的毫秒时刻（避开 MusicStoreService 的 id 碰撞，见 awaitIdSlot） */
  private lastPlaylistCreatedAt: number = 0;
  /** 上行出口：连接并完成列表同步后由 SyncClient 装上，断开时清掉 */
  private actionSink: SyncActionSink | null = null;

  /**
   * 初始化
   *
   * listen 的签名是 init(context: common.Context)；这里 context 可选（与 SyncStore/SyncGzip 一致），
   * 不传时取 getAppRuntime().context。
   */
  init(context?: common.Context): void {
    const ctx: common.Context | undefined = context !== undefined ? context : getAppRuntime().context;
    if (ctx === undefined) {
      appendError(`[${TAG}] init without ability context: store not ready, sync library disabled`);
      this.ready = false;
      this.store.init(undefined);
      this.load();
      return;
    }
    this.store.init(ctx);
    this.ready = true;
    this.load();
  }

  load(): void {
    this.data = this.store.loadListData();
    this.dislike = normalizeDislikeRules(this.store.loadDislikeRules());
    this.metas = loadPlaylistMeta(this.store);
    this.initialized = this.store.hasListData();
  }

  isInitialized(): boolean {
    return this.initialized;
  }

  setActionSink(sink: SyncActionSink | null): void {
    this.actionSink = sink;
  }

  private emit(action: LxSyncAction, kind: string): void {
    const sink = this.actionSink;
    if (sink === null) {
      return;
    }
    try {
      sink(action, kind);
    } catch (e) {
      appendError(`[${TAG}] emit ${action.action} failed: ${JSON.stringify(e)}`);
    }
  }

  private emitOverwrite(listId: string, musicInfos: LxMusicInfoNew[]): void {
    const data: LxListMusicOverwriteData = { listId: listId, musicInfos: musicInfos };
    this.emit({ action: 'list_music_overwrite', data: data }, 'list');
  }

  // ------------------------------------------------------------ 对外数据

  /**
   * 当前同步数据（字段顺序与洛雪一致，md5 依赖它）
   *
   * 取之前先 ingest()：把 MusicStoreService 的最新内容并进镜像，这样「界面直接改 store
   * 但没调 notify*」的改动也会被如实上报，而不是发一份过期数据出去。
   */
  listData(): LxListData {
    if (this.ingest()) {
      this.persist();
    }
    return this.payload();
  }

  listDataMd5(): string {
    return toMD5(JSON.stringify(this.listData()));
  }

  dislikeRules(): string {
    return this.dislike;
  }

  dislikeMd5(): string {
    return toMD5(this.dislike.trim());
  }

  summary(): LibrarySummary {
    const playlists: number = this.data.userList.length;
    const songs: number = this.data.defaultList.length + this.data.loveList.length + localMusic.count();
    return { playlists: playlists, songs: songs };
  }

  /** 构建对外/落盘的 payload（不做 ingest，供内部使用） */
  private payload(): LxListData {
    const out: LxListData = {
      defaultList: this.data.defaultList,
      loveList: this.data.loveList,
      userList: buildUserLists(this.data.userList),
    };
    return out;
  }

  // ------------------------------------------------------------ 本地改动上报（界面/服务调用）

  /**
   * 本地歌单 / 收藏 / 播放队列改了：重新对账并上行
   *
   * listen 里这个方法由 PlaySession 通过 LibrarySink 回调；RzdMusic 里由改动方主动调用
   * （界面改完 MusicStoreService，或 notifyPlaylistChanged / notifyFavoritesChanged /
   * notifyQueueChanged 三个语义入口转进来）。只把真正变了的列表上行。
   */
  onLocalListsChanged(): void {
    if (this.applying) {
      return;
    }
    const before: LxListData = cloneListData(this.data);
    const beforeMetas: Record<string, LxPlaylistMeta> = this.metas;
    this.metas = cloneMetas(this.metas);
    this.ingest();
    // 界面订阅 libraryVersion 重新读数据；本地改动不走远端那条路，这里也要递增
    this.bumpLibraryVersion();
    if (!this.ready) {
      return;
    }
    const changedDefault: boolean = JSON.stringify(before.defaultList) !== JSON.stringify(this.data.defaultList);
    const changedLove: boolean = JSON.stringify(before.loveList) !== JSON.stringify(this.data.loveList);
    const listsChanged: boolean = JSON.stringify(before.userList) !== JSON.stringify(this.data.userList);
    if (!changedDefault && !changedLove && !listsChanged) {
      this.metas = beforeMetas;
      return;
    }
    this.persist();
    if (changedDefault) {
      this.emitOverwrite('default', this.data.defaultList);
    }
    if (changedLove) {
      this.emitOverwrite(LIST_ID_LOVE, this.data.loveList);
    }
    if (listsChanged) {
      this.emitUserListOps(before.userList, this.data.userList);
    }
  }

  /**
   * 某个歌单改了（新建 / 改名 / 增删歌 / 删除）
   *
   * listId 是本机歌单 id（MusicStoreService 的 PlaylistDto.id）。这里会重新对账整个库、
   * 只上行真正变了的那些列表，所以调用方不需要告诉我们是哪一种改动。
   */
  notifyPlaylistChanged(listId: string): void {
    appendPlayLog(`[${TAG}] playlist changed: ${listId}`);
    this.onLocalListsChanged();
  }

  /** 收藏变了（收藏 / 取消收藏，含收藏里的本地歌） */
  notifyFavoritesChanged(): void {
    this.onLocalListsChanged();
  }

  /** 播放队列（= 试听列表）变了 */
  notifyQueueChanged(): void {
    this.onLocalListsChanged();
  }

  /**
   * 把协议镜像写回 MusicStoreService，并让界面刷新
   *
   * listen 的 mirrorToSession() 是「镜像到 PlaySession」，RzdMusic 没有会话类，
   * 改成「写 MusicStogeService + 递增 libraryVersion」。
   */
  mirrorToSession(): void {
    if (this.ready) {
      this.ingest();
      this.project();
      this.persist();
    }
    this.bumpLibraryVersion();
  }

  /** 本地改动后让订阅 libraryVersion 的界面重新读一次数据 */
  bumpLibraryVersion(): void {
    this.libraryVersion = this.libraryVersion + 1;
  }

  // ------------------------------------------------------------ 展示读取（本地歌合并在最前面）

  /**
   * 歌单摘要
   *
   * count 把侧表里的本地歌算上，否则「歌单里有 3 首本地歌」外面会显示 0 首。
   */
  playlistSummaries(): LxPlaylistSummary[] {
    const out: LxPlaylistSummary[] = [];
    const store: MusicStoreService = MusicStoreService.getInstance();
    for (const item of this.data.userList) {
      const localId: string = this.localIdOf(item.id);
      const count: number = item.list.length + localMusic.listCount(localId);
      const name: string = playlistNameOf(store, localId, item.name);
      out.push({ id: localId, lxId: item.id, name: name, count: count });
    }
    return out;
  }

  /** 内置收藏歌单的摘要（界面「收藏」那一份） */
  favoriteSummary(): LxPlaylistSummary {
    return {
      id: LOVE_LIST_ID,
      lxId: LIST_ID_LOVE,
      name: '我的收藏',
      count: this.data.loveList.length + localMusic.listCount(LOVE_LIST_ID),
    };
  }

  /**
   * 某个歌单的歌曲（本地歌排在前面）
   *
   * id 传本机歌单 id；内置收藏传 'love'（LOVE_LIST_ID / LIST_ID_LOVE 都是 'love'）。
   * 本地歌排在前面：它们不在同步数据里，没有「和在线歌交错」的顺序可言，
   * 排在前面与「新加的歌排最前」的既有规则一致。
   */
  playlistSongs(id: string): SongItem[] {
    const out: SongItem[] = [];
    const sideKey: string = id;
    for (const song of localMusic.listSongItems(sideKey)) {
      out.push(song);
    }
    const lxId: string = id === LOVE_LIST_ID ? LIST_ID_LOVE : this.lxIdOf(id);
    const musics: LxMusicInfoNew[] | null = this.targetMusics(lxId);
    if (musics === null) {
      return out;
    }
    for (const info of musics) {
      out.push(MusicStoreService.toSongItem(fromLxMusicInfo(info)));
    }
    return out;
  }

  /** 收藏的歌曲（本地歌排在前面） */
  favoriteSongs(): SongItem[] {
    return this.playlistSongs(LOVE_LIST_ID);
  }

  /** 本机歌单 id -> 洛雪列表 id */
  lxIdOf(localId: string): string {
    const meta: LxPlaylistMeta | undefined = this.metas[localId];
    return meta === undefined ? localId : meta.lxId;
  }

  /** 洛雪列表 id -> 本机歌单 id（没有映射时返回原值） */
  localIdOf(lxId: string): string {
    const keys: string[] = Object.keys(this.metas);
    for (const key of keys) {
      const meta: LxPlaylistMeta | undefined = this.metas[key];
      if (meta !== undefined && meta.lxId === lxId) {
        return key;
      }
    }
    return lxId;
  }

  // ------------------------------------------------------------ ingest：store -> 协议镜像

  /**
   * 把 MusicStoreService 的最新内容并进协议镜像
   *
   * @returns 镜像是否发生了变化（调用方据此决定要不要落盘）
   */
  private ingest(): boolean {
    if (!this.ready) {
      return false;
    }
    const beforeDefault: string = JSON.stringify(this.data.defaultList);
    const beforeLove: string = JSON.stringify(this.data.loveList);
    const beforeUser: string = JSON.stringify(this.data.userList);
    const beforeMetas: string = JSON.stringify(this.metas);
    this.ingestFavorites();
    this.ingestQueue();
    this.ingestPlaylists();
    return beforeDefault !== JSON.stringify(this.data.defaultList)
      || beforeLove !== JSON.stringify(this.data.loveList)
      || beforeUser !== JSON.stringify(this.data.userList)
      || beforeMetas !== JSON.stringify(this.metas);
  }

  /** 收藏：取 MusicStoreService 的收藏行里可同步的那一份 */
  private ingestFavorites(): void {
    const records: PlayedSongRecord[] = MusicStoreService.getInstance().getFavorites();
    const musics: LxMusicInfoNew[] = musicsOf(records);
    // 有非本地的收藏行却一首也转不成同步结构（缺 source/songId 的演示数据）：
    // 不能拿空数组去覆盖已有列表，否则会把云端收藏一起清掉。
    if (musics.length === 0 && this.data.loveList.length > 0 && unconvertibleCount(records) > 0) {
      appendError(`[${TAG}] skip unsyncable favorites (${records.length} rows, none convertible)`);
      return;
    }
    this.data.loveList = musics;
  }

  /** 试听列表 = 播放队列（last_queue 快照里的在线歌） */
  private ingestQueue(): void {
    const read: QueueReadResult = this.readQueue();
    // 播放器还没写过队列快照（首次安装 / 被清过）：不能把「没有快照」当成「队列被清空」，
    // 否则镜像里那份远端来的试听列表会被一次误判清掉。
    if (!read.hasSnapshot) {
      return;
    }
    const musics: LxMusicInfoNew[] = musicsOf(read.online);
    if (musics.length === 0 && this.data.defaultList.length > 0 && unconvertibleCount(read.online) > 0) {
      appendError(`[${TAG}] skip unsyncable queue (${read.online.length} rows, none convertible)`);
      return;
    }
    this.data.defaultList = musics;
  }

  /** 自建歌单：内容是 store 的，协议元数据（id/source/sourceListId/locationUpdateTime）是本文件的 */
  private ingestPlaylists(): void {
    const playlists: PlaylistDto[] = MusicStoreService.getInstance().getPlaylists();
    const next: LxUserListInfoFull[] = [];
    const keptMetas: Record<string, LxPlaylistMeta> = {};
    const seenLx: Set<string> = new Set<string>();
    for (const item of playlists) {
      let meta: LxPlaylistMeta | undefined = this.metas[item.id];
      if (meta === undefined) {
        // 界面刚建、还没登记过的歌单：lx id 就用自己的本机 id，locationUpdateTime 用创建时间
        meta = {
          lxId: item.id,
          locationUpdateTime: item.createTime > 0 ? item.createTime : Date.now(),
        };
      }
      if (seenLx.has(meta.lxId)) {
        // 两个本机歌单映射到同一个洛雪 id（只可能来自 MusicStoreService 的 id 碰撞）：
        // 后一个无法参与同步，跳过并记一条错误，避免把协议数据搅乱。
        appendError(`[${TAG}] duplicate lx list id ${meta.lxId} for playlist ${item.id}, skipped`);
        continue;
      }
      seenLx.add(meta.lxId);
      const prev: LxUserListInfoFull | null = findUserList(this.data.userList, meta.lxId);
      if (prev !== null && prev.name !== item.name) {
        // 本机改了名字：刷新 locationUpdateTime，让服务端判定这次改动更新
        meta.locationUpdateTime = Date.now();
      }
      const musics: LxMusicInfoNew[] = musicsOf(item.songs);
      const entry: LxUserListInfoFull = {
        id: meta.lxId,
        name: item.name,
        locationUpdateTime: meta.locationUpdateTime,
        list: musics,
      };
      if (meta.source !== undefined) {
        entry.source = meta.source;
      }
      if (meta.sourceListId !== undefined) {
        entry.sourceListId = meta.sourceListId;
      }
      // 有歌行却一首也转不出来：保留上一份，别把歌单清空
      if (musics.length === 0 && item.songs.length > 0 && prev !== null && prev.list.length > 0) {
        entry.list = prev.list;
        appendError(`[${TAG}] skip unsyncable songs of playlist ${item.id} (${item.songs.length} rows)`);
      }
      next.push(entry);
      keptMetas[item.id] = meta;
    }
    // 歌单没了：元数据一起清掉（留着就是永远读不到的垃圾）
    this.metas = keptMetas;
    this.data.userList = next;
  }

  // ------------------------------------------------------------ project：协议镜像 -> store

  /**
   * 把协议镜像写回 MusicStoreService（远端数据到达后调用）
   *
   * 本地歌是各写各的：store 里 source === 'local' 的行一律不动，只替换在线那部分。
   */
  private project(): void {
    this.projectFavorites();
    this.projectPlaylists();
    this.projectQueue();
  }

  private projectFavorites(): void {
    const store: MusicStoreService = MusicStoreService.getInstance();
    const current: PlayedSongRecord[] = store.getFavorites();
    const onlineRows: PlayedSongRecord[] = [];
    for (const row of current) {
      if (row.source !== LOCAL_SOURCE) {
        onlineRows.push(row);
      }
    }
    const desired: PlayedSongRecord[] = recordsOf(this.data.loveList);
    if (sameRecordOrder(onlineRows, desired)) {
      return;
    }
    for (const row of onlineRows) {
      store.removeFavorite(row.source, row.songId);
    }
    // addFavorite 是头插：倒着加，最终顺序才能和 loveList 一致；本地歌那几行不动
    for (let i = desired.length - 1; i >= 0; i--) {
      store.addFavorite(desired[i]);
    }
  }

  private projectPlaylists(): void {
    const store: MusicStoreService = MusicStoreService.getInstance();
    const current: PlaylistDto[] = store.getPlaylists();
    const byLxId: Record<string, string> = {};
    for (const localId of Object.keys(this.metas)) {
      const meta: LxPlaylistMeta | undefined = this.metas[localId];
      if (meta !== undefined) {
        byLxId[meta.lxId] = localId;
      }
    }
    const existingIds: Set<string> = new Set<string>();
    for (const item of current) {
      existingIds.add(item.id);
    }
    const desiredOrder: string[] = [];
    for (const entry of this.data.userList) {
      let localId: string | undefined = byLxId[entry.id];
      if (localId === undefined || !existingIds.has(localId)) {
        localId = this.createStorePlaylist(entry, existingIds);
        if (localId.length === 0) {
          appendError(`[${TAG}] materialize remote playlist ${entry.id} failed, skipped`);
          continue;
        }
      }
      const meta: LxPlaylistMeta = { lxId: entry.id, locationUpdateTime: entry.locationUpdateTime };
      if (entry.source !== undefined) {
        meta.source = entry.source;
      }
      if (entry.sourceListId !== undefined) {
        meta.sourceListId = entry.sourceListId;
      }
      this.metas[localId] = meta;
      desiredOrder.push(localId);
      this.reconcilePlaylistSongs(localId, entry.list);
      const existing: PlaylistDto | undefined = store.getPlaylistById(localId);
      if (existing !== undefined && existing.name !== entry.name) {
        store.renamePlaylist(localId, entry.name);
      }
    }
    // 协议镜像里已经没有的本机歌单：删掉（全量覆盖时服务端就是这么要求的）
    const desired: Set<string> = new Set<string>();
    for (const localId of desiredOrder) {
      desired.add(localId);
    }
    for (const item of current) {
      if (!desired.has(item.id)) {
        store.deletePlaylist(item.id);
      }
    }
    // 顺序也以协议镜像为准
    const currentOrder: string[] = [];
    for (const item of store.getPlaylists()) {
      if (desired.has(item.id)) {
        currentOrder.push(item.id);
      }
    }
    if (!sameStringOrder(currentOrder, desiredOrder)) {
      store.reorderPlaylists(desiredOrder);
    }
  }

  /**
   * 用远端歌单在 store 里建一个本机歌单
   *
   * MusicStoreService 的歌单 id 是 `String(Date.now())`，没法指定，所以这里：
   *   1) 先等时钟跨过上一次新建的那一毫秒（否则同一毫秒内的两次新建会撞出重复 id）；
   *   2) 用 importPlaylist(name, songs) 连歌一起建出来（listen 的 createPlaylist 只给空歌单）。
   * @returns 新建的本机歌单 id；失败返回空串
   */
  private createStorePlaylist(entry: LxUserListInfoFull, existingIds: Set<string>): string {
    const store: MusicStoreService = MusicStoreService.getInstance();
    const songs: PlayedSongRecord[] = recordsOf(entry.list);
    this.awaitIdSlot();
    this.lastPlaylistCreatedAt = Date.now();
    const created: PlaylistDto = store.importPlaylist(entry.name, songs);
    if (created.id.length === 0) {
      return '';
    }
    if (existingIds.has(created.id)) {
      // 理论上到不了这里（awaitIdSlot 已经避开）；真撞上就明确报错，别静默弄出两个同 id 歌单
      appendError(`[${TAG}] playlist id collision: ${created.id}, sync of ${entry.id} may be unstable`);
    }
    existingIds.add(created.id);
    return created.id;
  }

  /**
   * 让时钟跨过上一次新建本机歌单的那一毫秒
   *
   * MusicStoreService 的歌单 id 就是 Date.now()，没法指定；远端一次可能带来多个歌单，
   * 同一毫秒里连续新建就会撞车 —— 两份歌单共用一个 id，之后所有按 id 的读写都指向第一份。
   * 自旋上限 2 万次（实测远小于 1 毫秒），正常情况一次都不会转。
   */
  private awaitIdSlot(): void {
    let guard: number = 0;
    while (Date.now() <= this.lastPlaylistCreatedAt && guard < 20000) {
      guard++;
    }
  }

  /** 把某个本机歌单的在线歌对齐成协议镜像里的那份（本地行保持不动） */
  private reconcilePlaylistSongs(localId: string, musics: LxMusicInfoNew[]): void {
    const store: MusicStoreService = MusicStoreService.getInstance();
    const target: PlaylistDto | undefined = store.getPlaylistById(localId);
    if (target === undefined) {
      return;
    }
    const desired: PlayedSongRecord[] = recordsOf(musics);
    const desiredKeys: string[] = [];
    for (const record of desired) {
      desiredKeys.push(recordKey(record));
    }
    const currentOnline: PlayedSongRecord[] = [];
    const localRows: PlayedSongRecord[] = [];
    for (const row of target.songs) {
      if (row.source === LOCAL_SOURCE) {
        localRows.push(row);
      } else {
        currentOnline.push(row);
      }
    }
    const currentKeys: string[] = [];
    for (const record of currentOnline) {
      currentKeys.push(recordKey(record));
    }
    const orderedKeys: string[] = [];
    for (const key of desiredKeys) {
      orderedKeys.push(key);
    }
    for (const row of localRows) {
      orderedKeys.push(recordKey(row));
    }
    if (sameStringOrder(currentKeys, desiredKeys) && sameStringOrder(recordKeys(target.songs), orderedKeys)) {
      return;
    }
    for (const row of currentOnline) {
      if (!desiredKeys.includes(recordKey(row))) {
        store.removeSongFromPlaylist(localId, row.source, row.songId);
      }
    }
    for (const record of desired) {
      if (!currentKeys.includes(recordKey(record))) {
        store.addSongToPlaylist(localId, record);
      }
    }
    store.reorderPlaylistSongs(localId, orderedKeys);
  }

  private projectQueue(): void {
    const read: QueueReadResult = this.readQueue();
    const desired: PlayedSongRecord[] = recordsOf(this.data.defaultList);
    if (read.hasSnapshot && sameRecordOrder(read.online, desired)) {
      return;
    }
    if (!read.hasSnapshot && desired.length === 0) {
      return;
    }
    // 队列里本地歌那份（localIds）不属于同步数据，原样保留；index 越界就归零
    const snapshot: QueueSnapshot = { online: desired, localIds: [], index: 0 };
    if (read.hasSnapshot) {
      const raw: QueueSnapshot | null = this.readQueueSnapshot();
      if (raw !== null) {
        snapshot.localIds = raw.localIds;
        snapshot.index = raw.index;
      }
    }
    const total: number = snapshot.online.length + snapshot.localIds.length;
    if (snapshot.index < 0 || snapshot.index >= total) {
      snapshot.index = 0;
    }
    MusicStoreService.getInstance().setLastQueue(JSON.stringify(snapshot));
  }

  private readQueueSnapshot(): QueueSnapshot | null {
    const json: string = MusicStoreService.getInstance().getLastQueue();
    if (json.length === 0) {
      return null;
    }
    try {
      const raw: QueueSnapshot = JSON.parse(json) as QueueSnapshot;
      if (raw === null || raw === undefined) {
        return null;
      }
      const snapshot: QueueSnapshot = {
        online: Array.isArray(raw.online) ? raw.online : [],
        localIds: Array.isArray(raw.localIds) ? raw.localIds : [],
        index: typeof raw.index === 'number' ? raw.index : 0,
      };
      return snapshot;
    } catch (e) {
      appendError(`[${TAG}] parse last_queue failed: ${JSON.stringify(e)}`);
      return null;
    }
  }

  private readQueue(): QueueReadResult {
    const snapshot: QueueSnapshot | null = this.readQueueSnapshot();
    if (snapshot === null) {
      return { hasSnapshot: false, online: [] };
    }
    return { hasSnapshot: true, online: snapshot.online };
  }

  // ------------------------------------------------------------ 不喜欢规则

  /**
   * 规范化规则文本，逐条对齐洛雪 updateDislikeInfo：
   * 每行「歌名@歌手」，分隔符转义成 #，小写去空白，去掉空条目并按首次出现顺序去重。
   */
  setDislikeRules(raw: string, emitRemote: boolean = true): void {
    const next: string = normalizeDislikeRules(raw);
    if (next === this.dislike) {
      return;
    }
    this.dislike = next;
    this.persistDislike();
    this.bumpLibraryVersion();
    if (emitRemote) {
      this.emit({ action: 'dislike_data_overwrite', data: next }, 'dislike');
    }
  }

  addDislike(name: string, singer: string): void {
    const info: LxDislikeMusicInfo = { name: name, singer: singer };
    const line: string = `${name}${DISLIKE_NAME_SEP}${singer}`;
    this.setDislikeRules(`${this.dislike}\n${line}`, false);
    this.persistDislike();
    this.emit({ action: 'dislike_music_add', data: [info] }, 'dislike');
  }

  removeDislikeRule(rule: string): void {
    const lines: string[] = [];
    for (const line of this.dislike.split('\n')) {
      if (line.length > 0 && line !== rule) {
        lines.push(line);
      }
    }
    this.setDislikeRules(lines.join('\n'));
  }

  clearDislike(): void {
    if (this.dislike.length > 0) {
      this.dislike = '';
      this.persistDislike();
      this.bumpLibraryVersion();
    }
    this.emit({ action: 'dislike_music_clear' }, 'dislike');
  }

  dislikeRuleList(): string[] {
    const out: string[] = [];
    for (const line of this.dislike.split('\n')) {
      if (line.length > 0) {
        out.push(line);
      }
    }
    return out;
  }

  /** 这首歌是否命中了不喜欢规则（供界面做灰显/过滤时使用） */
  isDisliked(name: string, singer: string): boolean {
    if (this.dislike.length === 0) {
      return false;
    }
    const song: string = name.toLowerCase().trim();
    const artist: string = singer.toLowerCase().trim();
    for (const line of this.dislike.split('\n')) {
      if (line.length === 0) {
        continue;
      }
      const at: number = line.indexOf(DISLIKE_NAME_SEP);
      if (at < 0) {
        if (line === song) {
          return true;
        }
        continue;
      }
      const ruleName: string = line.substring(0, at);
      const ruleSinger: string = line.substring(at + 1);
      if (ruleName.length === 0) {
        if (ruleSinger === artist) {
          return true;
        }
        continue;
      }
      if (ruleName === song && ruleSinger === artist) {
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------ 应用远端数据

  /** 服务端要求把我们整份列表数据换成 data（list_sync_set_list_data） */
  applyRemoteListData(data: LxListData): void {
    this.applying = true;
    try {
      // 先收编 store 里已有的内容：远端数据里没有的本机歌单，随后会被当作「服务端要求删掉」，
      // 所以必须先让 store 的现状进入镜像，避免误删界面刚建的东西。
      this.ingest();
      this.data = normalizeListData(data);
      this.initialized = true;
      this.project();
    } finally {
      this.applying = false;
    }
    this.persist();
    this.bumpLibraryVersion();
  }

  /** 服务端推来的实时列表动作（list_sync_finished 之后） */
  applyRemoteListAction(action: LxSyncAction): void {
    this.applying = true;
    try {
      this.ingest();
      this.applyRemoteListActionInner(action);
      this.initialized = true;
      this.project();
    } finally {
      this.applying = false;
    }
    this.persist();
    this.bumpLibraryVersion();
  }

  private applyRemoteListActionInner(action: LxSyncAction): void {
    switch (action.action) {
      case 'list_data_overwrite':
        this.data = normalizeListData(action.data as LxListData);
        return;
      case 'list_create': {
        const payload = action.data as LxListCreateData;
        if (payload === undefined || payload === null) {
          return;
        }
        const infos: LxUserListInfo[] = payload.listInfos !== undefined ? payload.listInfos : [];
        let position: number = payload.position !== undefined ? payload.position : this.data.userList.length;
        for (const info of infos) {
          if (findUserList(this.data.userList, info.id) !== null) {
            continue;
          }
          const full: LxUserListInfoFull = {
            id: info.id,
            name: info.name,
            locationUpdateTime: info.locationUpdateTime !== undefined ? info.locationUpdateTime : null,
            list: [],
          };
          if (info.source !== undefined) {
            full.source = info.source;
          }
          if (info.sourceListId !== undefined) {
            full.sourceListId = info.sourceListId;
          }
          if (position < 0 || position > this.data.userList.length) {
            position = this.data.userList.length;
          }
          this.data.userList.splice(position, 0, full);
          position++;
        }
        return;
      }
      case 'list_remove': {
        const ids: string[] = action.data as string[];
        if (ids === undefined || ids === null) {
          return;
        }
        const remains: LxUserListInfoFull[] = [];
        for (const item of this.data.userList) {
          if (!ids.includes(item.id)) {
            remains.push(item);
          }
        }
        this.data.userList = remains;
        return;
      }
      case 'list_update': {
        const infos: LxUserListInfo[] = action.data as LxUserListInfo[];
        if (infos === undefined || infos === null) {
          return;
        }
        for (const info of infos) {
          const target = findUserList(this.data.userList, info.id);
          if (target === null) {
            continue;
          }
          target.name = info.name;
          if (info.source !== undefined) {
            target.source = info.source;
          }
          if (info.sourceListId !== undefined) {
            target.sourceListId = info.sourceListId;
          }
          if (info.locationUpdateTime !== undefined) {
            target.locationUpdateTime = info.locationUpdateTime;
          }
        }
        return;
      }
      case 'list_update_position': {
        const payload = action.data as LxListUpdatePositionData;
        if (payload === undefined || payload === null) {
          return;
        }
        const ids: string[] = payload.ids !== undefined ? payload.ids : [];
        let position: number = payload.position !== undefined ? payload.position : 0;
        const moving: LxUserListInfoFull[] = [];
        for (const id of ids) {
          const target = findUserList(this.data.userList, id);
          if (target !== null) {
            moving.push(target);
          }
        }
        if (moving.length === 0) {
          return;
        }
        const remains: LxUserListInfoFull[] = [];
        for (const item of this.data.userList) {
          if (!ids.includes(item.id)) {
            remains.push(item);
          }
        }
        if (position < 0 || position > remains.length) {
          position = remains.length;
        }
        insertListsAt(remains, position, moving);
        this.data.userList = remains;
        return;
      }
      case 'list_music_add': {
        const payload = action.data as LxListMusicAddData;
        if (payload === undefined || payload === null) {
          return;
        }
        this.addMusicTo(payload.id, payload.musicInfos, payload.addMusicLocationType);
        return;
      }
      case 'list_music_move': {
        const payload = action.data as LxListMusicMoveData;
        if (payload === undefined || payload === null) {
          return;
        }
        this.removeMusicFrom(payload.fromId, idsOf(payload.musicInfos));
        this.addMusicTo(payload.toId, payload.musicInfos, payload.addMusicLocationType);
        return;
      }
      case 'list_music_remove': {
        const payload = action.data as LxListMusicRemoveData;
        if (payload === undefined || payload === null) {
          return;
        }
        this.removeMusicFrom(payload.listId, payload.ids);
        return;
      }
      case 'list_music_update': {
        const updates = action.data as LxMusicUpdateItem[];
        if (updates === undefined || updates === null) {
          return;
        }
        for (const update of updates) {
          this.replaceMusicEverywhere(update.id, update.musicInfo);
        }
        return;
      }
      case 'list_music_update_position': {
        const payload = action.data as LxListMusicUpdatePositionData;
        if (payload === undefined || payload === null) {
          return;
        }
        this.moveMusicToPosition(payload.listId, payload.position, payload.ids);
        return;
      }
      case 'list_music_overwrite': {
        const payload = action.data as LxListMusicOverwriteData;
        if (payload === undefined || payload === null) {
          return;
        }
        this.overwriteMusic(payload.listId, payload.musicInfos);
        return;
      }
      case 'list_music_clear': {
        const listIds: string[] = action.data as string[];
        if (listIds === undefined || listIds === null) {
          return;
        }
        for (const listId of listIds) {
          this.overwriteMusic(listId, []);
        }
        return;
      }
      default:
        appendPlayLog(`[${TAG}] unknown list action: ${action.action}`);
        return;
    }
  }

  private addMusicTo(listId: string, musics: LxMusicInfoNew[], location: string): void {
    const target = this.targetMusics(listId);
    if (target === null) {
      return;
    }
    // 实时动作带来的歌也要过一次 round-trip 归一（见文件头第 4 条），
    // 否则它进不了 MusicStoreService 的等价形态，下一次 ingest 就会改掉镜像、让 md5 漂移。
    const incoming: LxMusicInfoNew[] = normalizeMusics(musics);
    let list: LxMusicInfoNew[] = target;
    for (const info of incoming) {
      list = list.filter((item: LxMusicInfoNew) => item.id !== info.id);
    }
    if (location === 'top') {
      const merged: LxMusicInfoNew[] = [];
      for (const info of incoming) {
        merged.push(info);
      }
      for (const info of list) {
        merged.push(info);
      }
      this.assignMusics(listId, merged);
      return;
    }
    for (const info of incoming) {
      list.push(info);
    }
    this.assignMusics(listId, list);
  }

  private removeMusicFrom(listId: string, ids: string[]): void {
    const target = this.targetMusics(listId);
    if (target === null) {
      return;
    }
    const remains: LxMusicInfoNew[] = [];
    for (const info of target) {
      if (!ids.includes(info.id)) {
        remains.push(info);
      }
    }
    this.assignMusics(listId, remains);
  }

  private overwriteMusic(listId: string, musics: LxMusicInfoNew[]): void {
    if (this.targetMusics(listId) === null) {
      return;
    }
    this.assignMusics(listId, normalizeMusics(musics));
  }

  private moveMusicToPosition(listId: string, position: number, ids: string[]): void {
    const target = this.targetMusics(listId);
    if (target === null) {
      return;
    }
    const moving: LxMusicInfoNew[] = [];
    for (const info of target) {
      if (ids.includes(info.id)) {
        moving.push(info);
      }
    }
    if (moving.length === 0) {
      return;
    }
    const remains: LxMusicInfoNew[] = [];
    for (const info of target) {
      if (!ids.includes(info.id)) {
        remains.push(info);
      }
    }
    let at: number = position;
    if (at < 0 || at > remains.length) {
      at = remains.length;
    }
    insertMusicsAt(remains, at, moving);
    this.assignMusics(listId, remains);
  }

  /** 取某个列表的歌曲数组（返回的是镜像内引用，调用方只能读） */
  private targetMusics(listId: string): LxMusicInfoNew[] | null {
    if (listId === 'default') {
      return this.data.defaultList;
    }
    if (listId === LIST_ID_LOVE) {
      return this.data.loveList;
    }
    const target = findUserList(this.data.userList, listId);
    return target === null ? null : target.list;
  }

  private assignMusics(listId: string, musics: LxMusicInfoNew[]): void {
    if (listId === 'default') {
      this.data.defaultList = musics;
      return;
    }
    if (listId === LIST_ID_LOVE) {
      this.data.loveList = musics;
      return;
    }
    const target = findUserList(this.data.userList, listId);
    if (target !== null) {
      target.list = musics;
    }
  }

  /** 歌曲信息被修订（list_music_update）：列表内、收藏、队列里同 id 的都换掉 */
  private replaceMusicEverywhere(id: string, musicInfo: LxMusicInfoNew): void {
    // 同样先归一（实时动作给的是原始远端 meta）
    const normalized: LxMusicInfoNew[] = normalizeMusics([musicInfo]);
    if (normalized.length === 0) {
      return;
    }
    const info: LxMusicInfoNew = normalized[0];
    this.data.defaultList = replaceInList(this.data.defaultList, id, info);
    this.data.loveList = replaceInList(this.data.loveList, id, info);
    for (const item of this.data.userList) {
      item.list = replaceInList(item.list, id, info);
    }
  }

  /** 服务端要求整份替换不喜欢规则 */
  applyRemoteDislikeData(rules: string): void {
    this.applying = true;
    try {
      this.dislike = normalizeDislikeRules(rules);
    } finally {
      this.applying = false;
    }
    this.persistDislike();
    this.bumpLibraryVersion();
  }

  /** 服务端推来的实时不喜欢动作 */
  applyRemoteDislikeAction(action: LxSyncAction): void {
    switch (action.action) {
      case 'dislike_data_overwrite':
        this.applyRemoteDislikeData(action.data as string);
        return;
      case 'dislike_music_add': {
        const infos: LxDislikeMusicInfo[] = action.data as LxDislikeMusicInfo[];
        if (infos === undefined || infos === null) {
          return;
        }
        let rules: string = this.dislike;
        for (const info of infos) {
          const name: string = info.name !== undefined && info.name !== null ? info.name : '';
          const singer: string = info.singer !== undefined && info.singer !== null ? info.singer : '';
          rules += `\n${name}${DISLIKE_NAME_SEP}${singer}`;
        }
        this.applyRemoteDislikeData(rules);
        return;
      }
      case 'dislike_music_clear':
        this.applyRemoteDislikeData('');
        return;
      default:
        appendPlayLog(`[${TAG}] unknown dislike action: ${action.action}`);
        return;
    }
  }

  // ------------------------------------------------------------ 上行（歌单差分）

  /**
   * 本地歌单的增删改 -> 洛雪动作
   *
   * 界面改的是 MusicStoreService，我们只能看到「改动前后」的镜像，所以按 id 差分：
   *   新增 -> list_create（有歌再补一条 list_music_overwrite）
   *   改名 -> list_update；歌曲变化 -> list_music_overwrite
   *   消失 -> list_remove
   */
  private emitUserListOps(before: LxUserListInfoFull[], after: LxUserListInfoFull[]): void {
    for (let i = 0; i < after.length; i++) {
      const entry: LxUserListInfoFull = after[i];
      if (findUserList(before, entry.id) !== null) {
        continue;
      }
      const data: LxListCreateData = { position: i, listInfos: [buildUserListInfo(entry)] };
      this.emit({ action: 'list_create', data: data }, 'list');
      if (entry.list.length > 0) {
        this.emitOverwrite(entry.id, entry.list);
      }
    }
    const updated: LxUserListInfo[] = [];
    for (const entry of after) {
      const prev: LxUserListInfoFull | null = findUserList(before, entry.id);
      if (prev === null) {
        continue;
      }
      if (prev.name !== entry.name) {
        updated.push(buildUserListInfo(entry));
      }
    }
    if (updated.length > 0) {
      this.emit({ action: 'list_update', data: updated }, 'list');
    }
    for (const entry of after) {
      const prev: LxUserListInfoFull | null = findUserList(before, entry.id);
      if (prev === null) {
        continue;
      }
      if (JSON.stringify(prev.list) !== JSON.stringify(entry.list)) {
        this.emitOverwrite(entry.id, entry.list);
      }
    }
    const removed: string[] = [];
    for (const prev of before) {
      if (findUserList(after, prev.id) === null) {
        removed.push(prev.id);
      }
    }
    if (removed.length > 0) {
      this.emit({ action: 'list_remove', data: removed }, 'list');
    }
  }

  // ------------------------------------------------------------ 落盘

  private persist(): void {
    this.store.saveListData(this.payload());
    this.store.savePlaylistMeta(JSON.stringify(this.metaFile()));
  }

  private metaFile(): PlaylistMetaFile {
    return { version: 1, playlists: this.metas };
  }

  private persistDislike(): void {
    this.store.saveDislikeRules(this.dislike);
  }

  /** 列表同步完成：把当前数据当作「已上行」的基线 */
  onListSynced(): void {
    this.initialized = true;
    this.persist();
  }

  onDislikeSynced(): void {
    this.persistDislike();
  }

  getStore(): SyncStore {
    return this.store;
  }
}

/** 进程内单例（SyncClient / SyncManager 都用它） */
export let localLibrary: LocalLibrary = LocalLibrary.getInstance();

// ------------------------------------------------------------------ 工具

/** 把 MusicStoreService 的歌曲行转成同步用歌曲（丢掉不能同步的演示条目与本地歌） */
function musicsOf(records: PlayedSongRecord[]): LxMusicInfoNew[] {
  const out: LxMusicInfoNew[] = [];
  const seen: Set<string> = new Set<string>();
  for (const item of records) {
    if (!isSyncable(item)) {
      continue;
    }
    const info: LxMusicInfoNew | null = toLxMusicInfo(item);
    if (info === null || seen.has(info.id)) {
      continue;
    }
    seen.add(info.id);
    out.push(info);
  }
  return out;
}

/** 同步用歌曲 -> MusicStoreService 的歌曲行 */
function recordsOf(musics: LxMusicInfoNew[]): PlayedSongRecord[] {
  const out: PlayedSongRecord[] = [];
  for (const info of musics) {
    out.push(fromLxMusicInfo(info));
  }
  return out;
}

/** 有 source 却转不成同步结构的行数（缺 songId 的演示数据之类） */
function unconvertibleCount(records: PlayedSongRecord[]): number {
  let count: number = 0;
  for (const item of records) {
    if (item.source === LOCAL_SOURCE) {
      continue;
    }
    if (item.source === undefined || item.source === null || item.source.length === 0) {
      continue;
    }
    if (toLxMusicInfo(item) === null) {
      count++;
    }
  }
  return count;
}

/** 歌曲行的唯一键（与 MusicStoreService 内部的去重口径一致） */
function recordKey(record: PlayedSongRecord): string {
  return `${record.source}_${record.songId}`;
}

function recordKeys(records: PlayedSongRecord[]): string[] {
  const out: string[] = [];
  for (const record of records) {
    out.push(recordKey(record));
  }
  return out;
}

function sameRecordOrder(left: PlayedSongRecord[], right: PlayedSongRecord[]): boolean {
  return sameStringOrder(recordKeys(left), recordKeys(right));
}

function sameStringOrder(left: string[], right: string[]): boolean {
  if (left.length !== right.length) {
    return false;
  }
  for (let i = 0; i < left.length; i++) {
    if (left[i] !== right[i]) {
      return false;
    }
  }
  return true;
}

function idsOf(musics: LxMusicInfoNew[]): string[] {
  const out: string[] = [];
  if (musics === undefined || musics === null) {
    return out;
  }
  for (const info of musics) {
    out.push(info.id);
  }
  return out;
}

function replaceInList(list: LxMusicInfoNew[], id: string, musicInfo: LxMusicInfoNew): LxMusicInfoNew[] {
  const out: LxMusicInfoNew[] = [];
  for (const info of list) {
    out.push(info.id === id ? musicInfo : info);
  }
  return out;
}

function findUserList(list: LxUserListInfoFull[], lxId: string): LxUserListInfoFull | null {
  for (const item of list) {
    if (item.id === lxId) {
      return item;
    }
  }
  return null;
}

/** 按洛雪 buildUserListInfoFull 的字段顺序重建歌单信息 */
export function buildUserListInfo(item: LxUserListInfoFull): LxUserListInfo {
  const out: LxUserListInfo = {
    id: item.id,
    name: item.name,
    source: item.source,
    sourceListId: item.sourceListId,
    locationUpdateTime: item.locationUpdateTime,
  };
  return out;
}

/** 按洛雪 buildUserListInfoFull 的字段顺序重建整个歌单数组 */
function buildUserLists(list: LxUserListInfoFull[]): LxUserListInfoFull[] {
  const out: LxUserListInfoFull[] = [];
  for (const item of list) {
    const full: LxUserListInfoFull = {
      id: item.id,
      name: item.name,
      source: item.source,
      sourceListId: item.sourceListId,
      locationUpdateTime: item.locationUpdateTime,
      list: item.list,
    };
    out.push(full);
  }
  return out;
}

/**
 * 远端列表数据 -> 完整结构
 *
 * 与 listen 的 normalizeListData 有一处关键差异：歌曲要过一次 round-trip 归一
 * （fromLxMusicInfo -> toLxMusicInfo，见文件头第 4 条），这样进镜像的歌一定能被
 * MusicStoreService 原样表达，ingest() 反复对账不会产生 md5 漂移。
 */
export function normalizeListData(input: LxListData): LxListData {
  const out: LxListData = defaultListData();
  if (input === undefined || input === null) {
    return out;
  }
  out.defaultList = normalizeMusics(input.defaultList);
  out.loveList = normalizeMusics(input.loveList);
  if (Array.isArray(input.userList)) {
    const lists: LxUserListInfoFull[] = [];
    const seen: Set<string> = new Set<string>();
    for (const item of input.userList) {
      if (item === null || item === undefined) {
        continue;
      }
      if (typeof item.id !== 'string' || item.id.length === 0 || seen.has(item.id)) {
        continue;
      }
      seen.add(item.id);
      const full: LxUserListInfoFull = {
        id: item.id,
        name: typeof item.name === 'string' && item.name.length > 0 ? item.name : item.id,
        locationUpdateTime: typeof item.locationUpdateTime === 'number' ? item.locationUpdateTime : null,
        list: normalizeMusics(item.list),
      };
      if (typeof item.source === 'string') {
        full.source = item.source;
      }
      if (typeof item.sourceListId === 'string') {
        full.sourceListId = item.sourceListId;
      }
      lists.push(full);
    }
    out.userList = lists;
  }
  return out;
}

/** 远端歌曲：补齐结构 + round-trip 归一 + 按 id 去重 */
function normalizeMusics(input: LxMusicInfoNew[] | undefined): LxMusicInfoNew[] {
  const out: LxMusicInfoNew[] = [];
  if (!Array.isArray(input)) {
    return out;
  }
  const seen: Set<string> = new Set<string>();
  for (const item of input) {
    if (item === null || item === undefined) {
      continue;
    }
    if (typeof item.id !== 'string' || item.id.length === 0) {
      continue;
    }
    if (typeof item.source !== 'string' || item.source.length === 0) {
      continue;
    }
    if (item.meta === undefined || item.meta === null) {
      continue;
    }
    if (item.meta.songId === undefined || item.meta.songId === null) {
      continue;
    }
    const info: LxMusicInfoNew | null = toLxMusicInfo(fromLxMusicInfo(item));
    if (info === null || seen.has(info.id)) {
      continue;
    }
    seen.add(info.id);
    out.push(info);
  }
  return out;
}

/**
 * 规范化不喜欢规则（逐条对齐洛雪 updateDislikeInfo，保证 md5 与官方一致）
 *
 * 洛雪用 `let [name, singer] = item.split('@')`，只取前两段；这里保持一致。
 * 分隔符转义成 #、小写、去空白、按首次出现顺序去重，都是官方行为。
 */
export function normalizeDislikeRules(rules: string): string {
  if (rules === undefined || rules === null || rules.length === 0) {
    return '';
  }
  const list: string[] = [];
  const seen: Set<string> = new Set<string>();
  for (const item of rules.split('\n')) {
    if (item.length === 0) {
      continue;
    }
    const parts: string[] = item.split(DISLIKE_NAME_SEP);
    let name: string = parts.length > 0 ? parts[0] : '';
    let singer: string = parts.length > 1 ? parts[1] : '';
    if (name.length > 0) {
      name = replaceAll(name, DISLIKE_NAME_SEP, DISLIKE_NAME_ALIAS).toLowerCase().trim();
      if (singer.length > 0) {
        singer = replaceAll(singer, DISLIKE_NAME_SEP, DISLIKE_NAME_ALIAS).toLowerCase().trim();
        pushUnique(list, seen, `${name}${DISLIKE_NAME_SEP}${singer}`);
      } else {
        pushUnique(list, seen, name);
      }
    } else if (singer.length > 0) {
      const value: string = replaceAll(singer, DISLIKE_NAME_SEP, DISLIKE_NAME_ALIAS).toLowerCase().trim();
      pushUnique(list, seen, `${DISLIKE_NAME_SEP}${value}`);
    }
  }
  return list.join('\n');
}

function pushUnique(list: string[], seen: Set<string>, rule: string): void {
  if (rule.length === 0 || seen.has(rule)) {
    return;
  }
  seen.add(rule);
  list.push(rule);
}

function replaceAll(text: string, from: string, to: string): string {
  if (from.length === 0) {
    return text;
  }
  return text.split(from).join(to);
}

/** 在 position 处插入一批歌曲（不用展开运算符，ArkTS 不支持） */
function insertMusicsAt(list: LxMusicInfoNew[], position: number, items: LxMusicInfoNew[]): void {
  let at: number = position;
  for (const item of items) {
    list.splice(at, 0, item);
    at++;
  }
}

/** 在 position 处插入一批歌单 */
function insertListsAt(list: LxUserListInfoFull[], position: number, items: LxUserListInfoFull[]): void {
  let at: number = position;
  for (const item of items) {
    list.splice(at, 0, item);
    at++;
  }
}

/** 深拷贝镜像（做改动前/后的差分） */
function cloneListData(data: LxListData): LxListData {
  return JSON.parse(JSON.stringify(data)) as LxListData;
}

function cloneMetas(metas: Record<string, LxPlaylistMeta>): Record<string, LxPlaylistMeta> {
  return JSON.parse(JSON.stringify(metas)) as Record<string, LxPlaylistMeta>;
}

/** 读 playlist_meta.json 并补齐结构 */
function loadPlaylistMeta(store: SyncStore): Record<string, LxPlaylistMeta> {
  const out: Record<string, LxPlaylistMeta> = {};
  const text: string = store.loadPlaylistMeta();
  if (text.length === 0) {
    return out;
  }
  try {
    const raw: PlaylistMetaFile = JSON.parse(text) as PlaylistMetaFile;
    const source: Record<string, LxPlaylistMeta> | undefined = raw !== null && raw !== undefined
      ? raw.playlists : undefined;
    if (source === undefined || source === null) {
      return out;
    }
    for (const localId of Object.keys(source)) {
      const item: LxPlaylistMeta | undefined = source[localId];
      if (item === undefined || item === null || typeof item.lxId !== 'string' || item.lxId.length === 0) {
        continue;
      }
      const meta: LxPlaylistMeta = {
        lxId: item.lxId,
        locationUpdateTime: typeof item.locationUpdateTime === 'number' ? item.locationUpdateTime : null,
      };
      if (typeof item.source === 'string') {
        meta.source = item.source;
      }
      if (typeof item.sourceListId === 'string') {
        meta.sourceListId = item.sourceListId;
      }
      out[localId] = meta;
    }
  } catch (e) {
    appendError(`[${TAG}] parse playlist meta failed: ${JSON.stringify(e)}`);
  }
  return out;
}

/** 歌单展示名：store 里找不到（已被删）就用协议镜像里的名字兜底 */
function playlistNameOf(store: MusicStoreService, localId: string, fallback: string): string {
  const playlist: PlaylistDto | undefined = store.getPlaylistById(localId);
  return playlist === undefined ? fallback : playlist.name;
}
