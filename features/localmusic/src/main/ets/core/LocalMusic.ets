/*
 * 本地音乐库（设备里的音频文件，导入进沙箱的那一份）
 *
 * 对应 listen 的文件：entry/src/main/ets/core/local/LocalMusic.ets（逐行移植）
 *
 * 适配点（与 listen 的差异，逐条）：
 *  1) 歌词匹配的在线歌曲类型：LxMusicInfo -> MatchSongInfo（见 ./LyricMatch），
 *     索引里的 matchJson / matchSource 字段与语义不变。
 *  2) 进度与「库版本」：listen 用 ArkUI 状态管理 V1 的 AppStorage（AppStorage.get/setOrCreate，
 *     键 local_version / local_progress）。RzdMusic 是 V2，改用 AppStorageV2 + LocalMusicImportState
 *     （@ObservedV2 + @Trace）。键名内联为 LOCAL_MUSIC_IMPORT_STATE_KEY（'musichome_LocalMusicImportState'）：
 *     常量本该加进 common/musicbasic 的 AppStorageKeys，但本模块不允许改那个文件，
 *     所以先内联在这里并导出（等 Constants.ets 允许改时再搬过去）。
 *  3) 封面：listen 走 CoverStore。这里不再依赖任何封面仓库，直接在
 *     files/local_music/covers/<key>.jpg 落 JPEG（quality 80），读封面用 fileUri 取 URI。
 *  4) 歌单 / 收藏：侧表（index.json 的 lists，收藏用 'love' 键）保留在本地索引里；
 *     同时把本地歌行写成 PlayedSongRecord（source='local'、songId=<本地 key>）交给
 *     MusicStoreService.addSongToPlaylist / addFavorite —— 这样歌单页 / 收藏页能直接显示本地歌。
 *     侧表另有用途：同步（features/sync 依赖本模块）用「远端歌单覆盖本地」时，
 *     侧表能知道哪些本地歌原本挂在哪个歌单里，可以把它们重新合并进去（对应 listen 的
 *     LocalLibrary.mirrorToSession / playlistSongs 合并逻辑，由同步侧按 listKeys() 使用）。
 *  5) 歌词文本解码：listen 用 LxCrypto.bytesToUtf8，这里用 util.TextDecoder（utf-8 / gbk）。
 *  6) Picker 交互从 listen 的 view 搬进本文件（importFiles / importFolder），
 *     UI 只负责按钮与提示，核心只依赖 common.UIAbilityContext（RzdMusic 能从
 *     getUIContext().getHostContext() 拿到）。
 *  7) 删掉了 listen 的 PlaySession / AudioCache / DownloadManager 依赖（RzdMusic 里没有对应类）。
 *
 * 为什么是「导入」而不是「记住文件路径」：Picker 返回的 URI 只有临时权限，
 * 官方文档写明「待退出应用后台后，获取的临时权限就会失效」；要跨重启就得
 * fileShare.persistPermission，那需要受限 ACL 权限（ohos.permission.FILE_ACCESS_PERSIST），
 * 而受限权限只批给「克隆 / 备份 / 同步」场景，音乐播放器申请不下来。所以选中即拷贝一份到
 * files/local_music/：零权限、退后台不掉、重启还在。详见 listen/docs/LOCAL_MUSIC.md。
 *
 * 落盘布局（与 listen 完全一致）：
 *   files/local_music/index.json                  { version, songs, lists, autoMatchLyric }
 *   files/local_music/<key>.<后缀>                 音频副本
 *   files/local_music/<key>.lrc                   同目录同名歌词（有就一起拷）
 *   files/local_music/covers/<key>.jpg            内嵌封面
 * **不要**写进播放缓存目录（player 的下载缓存是 LRU 淘汰目录，用户导入的歌是资产不是缓存）。
 */

import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MusicStoreService, PlayedSongRecord, SongItem, appendError, appendPlayLog } from 'musicbasic';
import { autoMatchLyric, AutoMatchResult, infoFromJson, infoToJson, MatchSongInfo } from './LyricMatch';
import { lxGetLyricFull, LyricFullResult, setLocalLyricResolver } from 'player';

const DOMAIN: number = 0x0001;
const TAG: string = 'LocalMusic';

const DIR_NAME: string = 'local_music';
const COVER_DIR: string = 'covers';
const INDEX_FILE: string = 'index.json';
const INDEX_VERSION: number = 1;

/**
 * AVPlayer / AVMetadataExtractor 官方列出的音频格式。
 * 不在这个列表里的（ape / wma / dsf / dff 等）导入时要明确告诉用户，不能静默丢掉。
 */
const SUPPORTED_EXTS: string[] = ['.mp3', '.flac', '.m4a', '.aac', '.ogg', '.wav', '.amr'];

/**
 * 明知放不了、但确实是音频的后缀
 *
 * 只有这些才会报「格式不支持」。选文件夹时目录里还躺着一堆 `.lrc`、封面图、
 * `desktop.ini` 之类，它们不是歌曲，报成失败只会让用户莫名其妙 —— 那些静默跳过。
 */
const UNSUPPORTED_AUDIO_EXTS: string[] = ['.ape', '.wma', '.dsf', '.dff', '.opus', '.aiff', '.aif',
  '.m4b', '.mpc', '.tak', '.wv'];

/** 封面落盘时的 JPEG 质量（内嵌封面常有 3000×3000，列表里根本用不上） */
const COVER_QUALITY: number = 80;

/** 歌词文件大小上限（正常 .lrc 只有几 KB，防止把奇怪的大文件整份读进内存） */
const LRC_MAX_BYTES: number = 512 * 1024;

/** 单次导入的上限（AudioViewPicker 在 API 20 及以前也是 500） */
const MAX_PICK: number = 500;

/** 本地歌在 SongItem.source / musicInfo 里的标记 */
export const LOCAL_SOURCE: string = 'local';
/** 本地歌的条目 id 前缀（洛雪也用 'local' 表示本地歌曲） */
export const LOCAL_ID_PREFIX: string = 'local_';
/** 收藏在侧表里用的 listId */
export const LOVE_LIST_ID: string = 'love';

/**
 * 本地音乐导入状态 / 库版本（AppStorageV2）
 *
 * 键名本该放进 common/musicbasic 的 AppStorageKeys（前缀约定 musichome_），
 * 但本模块不允许改那个文件，所以内联在这里并导出。
 */
export const LOCAL_MUSIC_IMPORT_STATE_KEY: string = 'musichome_LocalMusicImportState';

/**
 * 本地音乐库的可观察状态（ArkUI 状态管理 V2）
 *
 * version：导入 / 删除 / 歌单侧表变动 / 歌词匹配变化后 +1，界面 @Monitor 它重新读列表
 * progress：导入进度（`3/120 歌名`），空闲时是空串
 */
@ObservedV2
export class LocalMusicImportState {
  @Trace public version: number = 0;
  @Trace public progress: string = '';
  @Trace public importing: boolean = false;
}

/** 取全局共享的导入状态（AppStorageV2 单例） */
export function localMusicImportState(): LocalMusicImportState {
  return AppStorageV2.connect(LocalMusicImportState, LOCAL_MUSIC_IMPORT_STATE_KEY,
    () => new LocalMusicImportState())!;
}

/** 一条本地歌曲（落盘索引里的一行） */
export interface LocalSongEntry {
  /** 稳定标识（不含 local_ 前缀），同时作为 SongItem.songId */
  key: string;
  /** 沙箱里的文件名（含后缀） */
  file: string;
  /** 封面文件名（covers/ 下），没有内嵌封面时为空串 */
  cover: string;
  /**
   * 一起导入的同名歌词文件名（`.lrc`），没有就是空串
   *
   * 同一个目录里的歌词是**精确匹配**：不联网、不会配错，所以播放时优先用它。
   */
  lrc: string;
  /** 在线匹配到的平台歌曲（MatchSongInfo 的 JSON），空串 = 还没匹配到 */
  matchJson: string;
  /** 匹配结果来自哪个平台（kw / kg / tx / mg / wy） */
  matchSource: string;
  /**
   * 上次自动匹配的时刻（0 = 从没试过）
   *
   * 用来避免「每放一次就搜一次、每次都搜不到」：搜过一次（哪怕是没搜到）就记下来，
   * 之后只有用户手动纠正时才会再搜。
   */
  matchAt: number;
  name: string;
  singer: string;
  album: string;
  /** 毫秒；读不到标签时为 0（播放时以播放器报的时长为准） */
  durationMs: number;
  sizeBytes: number;
  addedAt: number;
  /** 去重指纹：大小 + 文件名（小写）。同一份文件重复导入时命中 */
  fingerprint: string;
}

/** 导入结果统计 */
export interface ImportResult {
  added: number;
  /** 已经导入过（指纹命中） */
  skipped: number;
  /** 格式不支持 */
  unsupported: number;
  /** 打开/拷贝/读标签失败 */
  failed: number;
  /**
   * 选择器层面的提示（用户取消 / 打开选择器失败 / 目录里没找到文件），空串 = 无
   *
   * listen 里这些提示散在 view 的 toast 里；这里并进返回值，UI 一句话就能说清。
   */
  message: string;
}

/** 落盘索引 */
interface LocalIndex {
  version: number;
  songs: LocalSongEntry[];
  /** 非同步侧表：歌单 id -> 该歌单里的本地歌 key 列表（收藏用 'love' 键） */
  lists: Record<string, string[]>;
  /** 「设置 - 播放设置 - 本地音乐自动匹配歌词」开关，默认开 */
  autoMatchLyric: boolean;
}

/** 读标签的结果（内部用） */
interface LocalMeta {
  name: string;
  singer: string;
  album: string;
  durationMs: number;
  coverFile: string;
}

/**
 * 本地音乐库（单例）
 *
 * 本模块不依赖播放与同步模块（只借 musicbasic 的 MusicStoreService 写歌单 / 收藏行），
 * 是本地歌的唯一持有者：
 *   - 音频副本与索引：files/local_music/index.json
 *   - 封面：files/local_music/covers/
 *   - 非同步侧表：index.json 的 lists（本地歌进了哪些歌单 / 收藏）
 */
export class LocalMusic {
  private static instance: LocalMusic | null = null;

  static getInstance(): LocalMusic {
    if (LocalMusic.instance === null) {
      LocalMusic.instance = new LocalMusic();
    }
    return LocalMusic.instance;
  }

  private dir: string = '';
  private coverDir: string = '';
  private ready: boolean = false;
  /** 导入顺序（旧 -> 新）；界面用 getSongs() / getSongItems() 取倒序 */
  private songs: LocalSongEntry[] = [];
  /** 歌单 id -> 本地歌 key 列表。用 Map 而不是 Record：ArkTS 不允许 delete 运算符 */
  private lists: Map<string, string[]> = new Map<string, string[]>();
  private byKey: Map<string, LocalSongEntry> = new Map();
  private byFingerprint: Set<string> = new Set();
  private seq: number = 0;
  /** 自动匹配歌词开关（落盘在索引里） */
  private autoMatch: boolean = true;
  /** 用户点了取消：导入循环在下一个文件前退出 */
  private cancelled: boolean = false;

  /**
   * 初始化：建目录 + 读索引
   *
   * 由宿主在拿到 UIAbilityContext 后调一次（RzdMusic 里是 getAppRuntime().context，
   * 页面侧也可用 this.getUIContext().getHostContext()）；重复调用是安全的。
   */
  init(context: common.UIAbilityContext): void {
    if (this.ready) {
      return;
    }
    this.dir = `${context.filesDir}/${DIR_NAME}`;
    this.coverDir = `${this.dir}/${COVER_DIR}`;
    try {
      if (!fs.accessSync(this.dir)) {
        fs.mkdirSync(this.dir);
      }
      if (!fs.accessSync(this.coverDir)) {
        fs.mkdirSync(this.coverDir);
      }
      this.ready = true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'create dir failed: %{public}s', JSON.stringify(e));
      this.ready = false;
      return;
    }
    this.load();
    // 播放侧不能反向依赖本模块（本模块依赖 player），所以由这里把「本地歌取词」
    // 注册进播放链路：MediaService 遇到 source === 'local' 时回调它。
    setLocalLyricResolver((song: SongItem): Promise<string> => this.resolveLyricForPlayback(song));
  }

  /**
   * 播放本地歌时取歌词（播放链路通过 setLocalLyricResolver 回调到这里）
   *
   * 顺序与 listen 一致：同名 `.lrc`（精确、离线）→ 之前匹配好的平台歌词 →
   * 设置允许时自动匹配一次 → 都没有就返回空串（宁可不显示，也不显示错的）。
   * @param song 播放队列里的本地歌条目（songId 即本地 key）
   * @returns 歌词文本，取不到时为空串
   */
  private async resolveLyricForPlayback(song: SongItem): Promise<string> {
    const key: string = song.songId;
    if (key.length === 0) {
      return '';
    }
    if (this.hasLocalLyric(key)) {
      return this.lrcTextOf(key);
    }
    const matched: MatchSongInfo | null = this.matchOf(key);
    if (matched !== null) {
      return this.fetchMatchedLyric(matched);
    }
    if (!this.getAutoMatchLyric()) {
      return '';
    }
    const auto: MatchSongInfo | null = await this.matchLyric(key);
    if (auto === null) {
      return '';
    }
    return this.fetchMatchedLyric(auto);
  }

  /** 按已匹配到的平台歌曲取词；平台不应答时返回空串 */
  private async fetchMatchedLyric(info: MatchSongInfo): Promise<string> {
    try {
      const full: LyricFullResult = await lxGetLyricFull(info.source, info.songId, info.name, info.singer);
      return full.main;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'fetch matched lyric failed: %{public}s', JSON.stringify(e));
      return '';
    }
  }

  isReady(): boolean {
    return this.ready;
  }

  // ------------------------------------------------------------ 读取

  /**
   * 全部本地歌条目（按导入时间倒序：新导入的在最前面）
   *
   * 这是给界面 / 歌单合并用的顺序；内部落盘顺序仍是导入顺序（旧 -> 新）。
   */
  getSongs(): LocalSongEntry[] {
    const out: LocalSongEntry[] = [];
    for (let i = this.songs.length - 1; i >= 0; i--) {
      out.push(this.songs[i]);
    }
    return out;
  }

  /** 全部本地歌的播放条目（倒序，新导入在最前） */
  getSongItems(): SongItem[] {
    const out: SongItem[] = [];
    for (let i = this.songs.length - 1; i >= 0; i--) {
      out.push(this.toSongItem(this.songs[i]));
    }
    return out;
  }

  count(): number {
    return this.songs.length;
  }

  totalBytes(): number {
    let sum: number = 0;
    for (const song of this.songs) {
      sum += song.sizeBytes;
    }
    return sum;
  }

  /** 按 key 取一条条目（没有返回 undefined） */
  entryOf(key: string): LocalSongEntry | undefined {
    return this.byKey.get(key);
  }

  /** 沙箱里的绝对音频路径；文件不在了返回空串（用户清过数据 / 文件被误删） */
  getPlayPath(key: string): string {
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    if (song === undefined) {
      return '';
    }
    const path: string = `${this.dir}/${song.file}`;
    try {
      return fs.accessSync(path) ? path : '';
    } catch (e) {
      return '';
    }
  }

  /** 沙箱里的绝对封面路径（file:// URI），没有封面返回空串 */
  getCoverUri(key: string): string {
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    if (song === undefined || song.cover.length === 0) {
      return '';
    }
    try {
      return fileUri.getUriFromPath(`${this.coverDir}/${song.cover}`);
    } catch (e) {
      // 取不到 URI 就不给封面（列表退回占位图），不要让一行图把整页带崩
      hilog.warn(DOMAIN, TAG, 'cover uri failed: %{public}s', JSON.stringify(e));
      return '';
    }
  }

  hasKey(key: string): boolean {
    return this.byKey.has(key);
  }

  /** 条目 id（`local_<key>`）是否还在库里（界面按它隐藏音质 / 下载入口） */
  hasId(id: string): boolean {
    const key: string = this.keyOfId(id);
    return key.length > 0 && this.byKey.has(key);
  }

  /** 本地 key -> 条目 id（`local_<key>`） */
  idOfKey(key: string): string {
    return `${LOCAL_ID_PREFIX}${key}`;
  }

  /** 从条目 id（`local_<key>`）取 key */
  keyOfId(id: string): string {
    return id.startsWith(LOCAL_ID_PREFIX) ? id.substring(LOCAL_ID_PREFIX.length) : '';
  }

  /** 一批 key 对应的条目（按传入顺序，跳过已经不存在的） */
  songsByKeys(keys: string[]): SongItem[] {
    const out: SongItem[] = [];
    for (const key of keys) {
      const song: LocalSongEntry | undefined = this.byKey.get(key);
      if (song !== undefined) {
        out.push(this.toSongItem(song));
      }
    }
    return out;
  }

  /**
   * 一条本地歌的播放条目
   *
   * 播放链路的约定（**主 agent 接线要点**）：
   *   - source = 'local'、songId = <本地 key>（稳定标识，重启后不变）；
   *   - url = 沙箱内音频绝对路径（不是 http），播放侧要在 source === 'local' 时直路处理：
   *     用 fs.openSync(url) 拿 fd 交给 AVPlayer.fdSrc，**不要**走 resolveOnlineUrl，
   *     也不要预取 / 入下载队列 / 问平台要封面或歌词；
   *   - src 留空（它不是 rawfile，交给 SongItemBuilder 会因为 getRawFd('') 白报一条错）；
   *   - quality = 'local'（界面显示「本地」）；
   *   - lyricText 留空：本地歌词按 lrcTextOf() / matchOf() 取（同名 .lrc 优先，其次平台歌词）。
   */
  toSongItem(entry: LocalSongEntry): SongItem {
    const name: string = entry.name.length > 0 ? entry.name : stripExt(entry.file);
    const item = new SongItem();
    item.id = entry.addedAt;
    item.title = name;
    item.singer = entry.singer;
    item.src = '';
    item.url = this.getPlayPath(entry.key);
    item.cover = this.getCoverUri(entry.key);
    item.source = LOCAL_SOURCE;
    item.songId = entry.key;
    item.albumId = '';
    item.albumName = entry.album;
    item.interval = formatInterval(entry.durationMs);
    // 本地歌没有音质协商；界面把 'local' 显示成「本地」
    item.quality = 'local';
    item.playCached = true;
    return item;
  }

  /** 一条本地歌的持久化记录（歌单 / 收藏 / 播放历史用） */
  toRecord(entry: LocalSongEntry): PlayedSongRecord {
    const name: string = entry.name.length > 0 ? entry.name : stripExt(entry.file);
    const record = new PlayedSongRecord();
    record.songId = entry.key;
    record.name = name;
    record.singer = entry.singer;
    record.albumName = entry.album;
    record.albumId = '';
    record.source = LOCAL_SOURCE;
    record.interval = formatInterval(entry.durationMs);
    record.img = this.getCoverUri(entry.key);
    // url 落盘写沙箱绝对路径：历史 / 收藏里点播时播放侧可直接用；文件不在时为空串
    record.url = this.getPlayPath(entry.key);
    record.lyric = this.lrcTextOf(entry.key);
    record.quality = 'local';
    record.playScript = '';
    record.time = entry.addedAt;
    return record;
  }

  // ------------------------------------------------------------ 歌词

  /** 这条本地歌有没有一起导入的 `.lrc` */
  hasLocalLyric(key: string): boolean {
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    return song !== undefined && song.lrc.length > 0;
  }

  /**
   * 读同名 `.lrc` 的文本；没有或读不出来返回空串
   *
   * 中文歌词文件有相当一部分是 GBK 编码，而 `fs.readTextSync` 只支持 utf-8，
   * 所以这里读原始字节：先用 UTF-8 解，解出替换字符（U+FFFD）说明编码不对，
   * 再用 GBK 解一遍。
   */
  lrcTextOf(key: string): string {
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    if (song === undefined || song.lrc.length === 0) {
      return '';
    }
    const bytes: Uint8Array | null = readBytes(`${this.dir}/${song.lrc}`);
    if (bytes === null || bytes.length === 0) {
      return '';
    }
    const utf8: string = decodeText(bytes, 'utf-8');
    if (utf8.indexOf('\uFFFD') < 0) {
      return utf8;
    }
    const gbk: string = decodeText(bytes, 'gbk');
    if (gbk.length > 0 && gbk.indexOf('\uFFFD') < 0) {
      return gbk;
    }
    return utf8;
  }

  /** 匹配到的平台歌曲（没匹配到返回 null） */
  matchOf(key: string): MatchSongInfo | null {
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    if (song === undefined || song.matchJson.length === 0) {
      return null;
    }
    return infoFromJson(song.matchJson);
  }

  /** 记下匹配结果（自动匹配成功，或用户手动选的那一条） */
  saveMatch(key: string, source: string, infoJson: string): void {
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    if (song === undefined || infoJson.length === 0) {
      return;
    }
    song.matchSource = source;
    song.matchJson = infoJson;
    song.matchAt = Date.now();
    this.persist();
    this.bumpVersion();
  }

  /** 清掉匹配结果（用户想重新匹配时用） */
  clearMatch(key: string): void {
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    if (song === undefined) {
      return;
    }
    song.matchJson = '';
    song.matchSource = '';
    // 留着 matchAt：自动匹配不会再自己重试，只有用户手动匹配才会
    this.persist();
    this.bumpVersion();
  }

  /** 自动匹配是不是已经试过了（成功与否都算试过） */
  matchTried(key: string): boolean {
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    return song !== undefined && song.matchAt > 0;
  }

  /** 记下「自动匹配试过一次了」，避免每放一次就联网搜一次 */
  markMatchTried(key: string): void {
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    if (song === undefined || song.matchAt > 0) {
      return;
    }
    song.matchAt = Date.now();
    this.persist();
  }

  /** 标签里的时长（毫秒，0 = 没读到）；匹配时用它排除同名不同版本 */
  durationMsOf(key: string): number {
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    return song === undefined ? 0 : song.durationMs;
  }

  /** 「设置 - 播放设置 - 本地音乐自动匹配歌词」开关（默认开） */
  getAutoMatchLyric(): boolean {
    return this.autoMatch;
  }

  /** 持久化自动匹配开关（关掉后仍可手动匹配，见 LyricMatchSheet） */
  setAutoMatchLyric(enabled: boolean): void {
    if (this.autoMatch === enabled) {
      return;
    }
    this.autoMatch = enabled;
    this.persist();
  }

  /**
   * 按需在线匹配一次（播放链路取词的入口）
   *
   * 顺序与 listen 的 PlaySession.loadLocalLyric 一致：
   *   1) 已经匹配过 -> 直接返回记下的那条；
   *   2) 开关关掉 / 自动匹配已经试过（matchAt > 0）-> 返回 null（交给用户手动匹配）；
   *   3) 逐平台搜索：够格就落盘并返回，不够格且平台确实应答过就记下 matchAt（只搜一次）。
   * @returns 匹配到的平台歌曲；null = 没有可用歌词（不是错误）
   */
  async matchLyric(key: string): Promise<MatchSongInfo | null> {
    const existing: MatchSongInfo | null = this.matchOf(key);
    if (existing !== null) {
      return existing;
    }
    const song: LocalSongEntry | undefined = this.byKey.get(key);
    if (song === undefined || !this.autoMatch || song.matchAt > 0) {
      return null;
    }
    const name: string = song.name.length > 0 ? song.name : stripExt(song.file);
    const result: AutoMatchResult = await autoMatchLyric(name, song.singer, song.durationMs);
    if (result.match !== null) {
      this.saveMatch(key, result.match.source, infoToJson(result.match.info));
      appendPlayLog(`[本地音乐] 歌词匹配成功：${result.match.source}/${result.match.info.songId}`);
      return result.match.info;
    }
    if (result.searched) {
      // 只有平台真的应答过才算「搜过了」：断网时不能记，否则以后有网也不会再匹配
      this.markMatchTried(key);
    }
    return null;
  }

  // ------------------------------------------------------------ 导入

  /**
   * 让用户选音频文件（AudioViewPicker，可多选）并导入
   *
   * 这是官方为「应用要读用户音频」指定的正路：**无需任何权限**
   * （READ_AUDIO / READ_MEDIA 都是受限权限，只批克隆 / 备份 / 同步场景）。
   */
  async importFiles(context: common.UIAbilityContext): Promise<ImportResult> {
    try {
      const options: picker.AudioSelectOptions = new picker.AudioSelectOptions();
      options.maxSelectNumber = MAX_PICK;
      const audioPicker: picker.AudioViewPicker = new picker.AudioViewPicker(context);
      const uris: string[] = await audioPicker.select(options);
      return await this.importUris(uris);
    } catch (e) {
      // 用户取消也会走到这里（错误码里带 cancel），不当成失败提示
      hilog.info(DOMAIN, TAG, 'pick files ended: %{public}s', JSON.stringify(e));
      return emptyResult('没有选择文件');
    }
  }

  /**
   * 让用户选一个音乐目录（DocumentViewPicker 的 FOLDER 模式）并导入目录里的文件
   *
   * 手机端一次只能选一个目录（allowsMulFolderSelection 在 Phone 上无效）。
   * 目录 URI 能不能用 fs.listFileSync 枚举，官方文档没有明说 —— 失败时明确告诉
   * 用户改用「选择音乐文件」，不要静默什么都不发生（真机验证项，见 LOCAL_MUSIC.md）。
   */
  async importFolder(context: common.UIAbilityContext): Promise<ImportResult> {
    let results: string[] = [];
    try {
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.selectMode = picker.DocumentSelectMode.FOLDER;
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      results = await documentPicker.select(options);
    } catch (e) {
      hilog.info(DOMAIN, TAG, 'pick folder ended: %{public}s', JSON.stringify(e));
      return emptyResult('没有选择文件夹');
    }
    if (results.length === 0) {
      return emptyResult('没有选择文件夹');
    }
    const uris: string[] = listFolderFiles(results[0]);
    if (uris.length === 0) {
      return emptyResult('这个目录里没有找到文件，请改用「选择音乐文件」');
    }
    return await this.importUris(uris);
  }

  /**
   * 导入一批 Picker 选中的音频文件
   *
   * 逐个串行处理（拷贝是同步的，中间要让出事件循环，否则大库导入会把界面卡住），
   * 每个文件的进度写进 LocalMusicImportState.progress，界面据此显示「正在导入 x/y」。
   */
  async importUris(uris: string[]): Promise<ImportResult> {
    const result: ImportResult = emptyResult('');
    if (!this.ready || uris.length === 0) {
      return result;
    }
    // 先摘掉「不是歌曲」的文件（.lrc / 封面图 / 说明文本…）：选文件夹时目录里全是这些，
    // 把它们算进「格式不支持」或者让进度条念一遍它们的名字都只会让人困惑
    const candidates: string[] = [];
    for (const uri of uris) {
      if (!isIgnorableFile(fileNameOf(uri))) {
        candidates.push(uri);
      }
    }
    this.cancelled = false;
    const state: LocalMusicImportState = localMusicImportState();
    const total: number = candidates.length;
    state.importing = true;
    try {
      for (let i = 0; i < total; i++) {
        if (this.cancelled) {
          hilog.info(DOMAIN, TAG, 'import cancelled at %{public}d/%{public}d', i, total);
          break;
        }
        const uri: string = candidates[i];
        const label: string = fileNameOf(uri);
        state.progress = `${i + 1}/${total} ${label}`;
        const outcome: string = await this.importOne(uri, label);
        if (outcome === 'added') {
          result.added++;
        } else if (outcome === 'skipped') {
          result.skipped++;
        } else if (outcome === 'unsupported') {
          result.unsupported++;
        } else {
          result.failed++;
        }
      }
    } finally {
      state.progress = '';
      state.importing = false;
    }
    if (result.added > 0) {
      this.persist();
      this.bumpVersion();
    }
    appendPlayLog(`[本地音乐] 导入结束：新增 ${result.added}，已存在 ${result.skipped}，` +
      `格式不支持 ${result.unsupported}，失败 ${result.failed}`);
    return result;
  }

  /** 用户取消导入（当前这个文件会做完，从下一个开始停） */
  cancelImport(): void {
    this.cancelled = true;
  }

  isImporting(): boolean {
    return localMusicImportState().importing;
  }

  /** @returns added / skipped / unsupported / failed */
  private async importOne(uri: string, label: string): Promise<string> {
    const ext: string = extOf(label);
    if (!isSupportedAudioFile(label)) {
      hilog.info(DOMAIN, TAG, 'skip unsupported file: %{public}s', label);
      return 'unsupported';
    }
    let src: fs.File | null = null;
    try {
      src = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(src.fd);
      const size: number = stat.size;
      if (size <= 0) {
        return 'failed';
      }
      const fingerprint: string = `${size}_${label.toLowerCase()}`;
      if (this.byFingerprint.has(fingerprint)) {
        return 'skipped';
      }
      const key: string = this.nextKey();
      const file: string = `${key}${ext}`;
      const dest: string = `${this.dir}/${file}`;
      fs.copyFileSync(src.fd, dest);
      closeQuietly(src);
      src = null;

      // 读标签要用**另一个**句柄：官方文档明确说同一个 fd 同时给播放器和提取器
      // 会「存在竞争关系，将导致音视频元数据获取异常」
      const meta: LocalMeta = await this.readMetadata(dest, size, key);
      // 同目录下的同名 .lrc 一并拷进来：这是**精确匹配**的歌词，播放时优先用它。
      // 「选文件夹」这条路一定拿得到；「选文件」那条路只授权了选中的文件，
      // 兄弟文件多半读不到 —— 读不到就算了，之后还有在线匹配兜底。
      const lrc: string = this.copySiblingLrc(uri, key);
      const entry: LocalSongEntry = {
        key: key,
        file: file,
        cover: meta.coverFile,
        lrc: lrc,
        matchJson: '',
        matchSource: '',
        matchAt: 0,
        name: meta.name.length > 0 ? meta.name : titleFromFileName(label),
        singer: meta.singer.length > 0 ? meta.singer : singerFromFileName(label),
        album: meta.album,
        durationMs: meta.durationMs,
        sizeBytes: size,
        addedAt: Date.now(),
        fingerprint: fingerprint
      };
      this.songs.push(entry);
      this.byKey.set(key, entry);
      this.byFingerprint.add(fingerprint);
      return 'added';
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'import failed (%{public}s): %{public}s', label, JSON.stringify(e));
      appendError(`[本地音乐] 导入失败：${label}`);
      return 'failed';
    } finally {
      closeQuietly(src);
    }
  }

  /**
   * 把同名 `.lrc` 一起拷进来（没有就返回空串）
   *
   * 只在音频文件旁边找一个同名歌词：`song.mp3` → `song.lrc` / `song.LRC`。
   * 读不到是常态（用户是用「选文件」进来的，只授权了那一个文件），所以这里不报错。
   */
  private copySiblingLrc(audioUri: string, key: string): string {
    const bases: string[] = siblingLrcBases(audioUri);
    for (const base of bases) {
      let src: fs.File | null = null;
      try {
        src = fs.openSync(base, fs.OpenMode.READ_ONLY);
        const file: string = `${key}.lrc`;
        fs.copyFileSync(src.fd, `${this.dir}/${file}`);
        return file;
      } catch (e) {
        // 没有同名词就试下一个写法
      } finally {
        closeQuietly(src);
      }
    }
    return '';
  }

  /** 读元数据与内嵌封面；失败不抛错，退回文件名（标签不是必需的） */
  private async readMetadata(path: string, size: number, key: string): Promise<LocalMeta> {
    const out: LocalMeta = { name: '', singer: '', album: '', durationMs: 0, coverFile: '' };
    let file: fs.File | null = null;
    let extractor: media.AVMetadataExtractor | null = null;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      extractor = await media.createAVMetadataExtractor();
      const source: media.AVFileDescriptor = { fd: file.fd, offset: 0, length: size };
      extractor.fdSrc = source;
      const meta: media.AVMetadata = await extractor.fetchMetadata();
      out.name = asText(meta.title);
      out.singer = asText(meta.artist);
      out.album = asText(meta.album);
      out.durationMs = asNumber(meta.duration);
      out.coverFile = await this.saveCover(extractor, key);
    } catch (e) {
      // 不支持的编码 / 没有标签都会走到这里，属于常态，不报错只记日志
      hilog.info(DOMAIN, TAG, 'read metadata failed: %{public}s', JSON.stringify(e));
    } finally {
      if (extractor !== null) {
        try {
          await extractor.release();
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'release extractor failed: %{public}s', JSON.stringify(e));
        }
      }
      closeQuietly(file);
    }
    return out;
  }

  /** 内嵌封面 -> JPEG 落盘到 covers/；没有封面返回空串 */
  private async saveCover(extractor: media.AVMetadataExtractor, key: string): Promise<string> {
    let pixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    try {
      pixelMap = await extractor.fetchAlbumCover();
      packer = image.createImagePacker();
      const option: image.PackingOption = { format: 'image/jpeg', quality: COVER_QUALITY };
      const buffer: ArrayBuffer = await packer.packToData(pixelMap, option);
      const file: string = `${key}.jpg`;
      const handle: fs.File = fs.openSync(`${this.coverDir}/${file}`,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(handle.fd, buffer);
      } finally {
        fs.closeSync(handle);
      }
      return file;
    } catch (e) {
      // 大多数没有内嵌封面的文件会走到这里
      return '';
    } finally {
      if (packer !== null) {
        try {
          await packer.release();
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'release packer failed: %{public}s', JSON.stringify(e));
        }
      }
      if (pixelMap !== null) {
        try {
          await pixelMap.release();
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'release pixelmap failed: %{public}s', JSON.stringify(e));
        }
      }
    }
  }

  private nextKey(): string {
    this.seq = (this.seq + 1) % 1296;
    return `${Date.now().toString(36)}${this.seq.toString(36)}`;
  }

  // ------------------------------------------------------------ 删除

  /**
   * 删掉一批本地歌（只删沙箱里的副本，用户原文件不动）
   *
   * 同时做三件清理，避免留下点一下就报错的幽灵条目：
   *   - 歌单 / 收藏侧表里的引用（本文件）；
   *   - MusicStoreService 里的收藏行与各歌单里的本地行；
   *   - 播放队列（getSongItems 已经不在里面了，队列由调用方按 key 摘，见 view 的 removeLocalSongs）。
   * @returns 真正删掉的条数
   */
  removeKeys(keys: string[]): number {
    if (keys.length === 0) {
      return 0;
    }
    const remains: LocalSongEntry[] = [];
    let removed: number = 0;
    for (const song of this.songs) {
      if (keys.includes(song.key)) {
        unlinkQuietly(`${this.dir}/${song.file}`);
        if (song.cover.length > 0) {
          unlinkQuietly(`${this.coverDir}/${song.cover}`);
        }
        if (song.lrc.length > 0) {
          unlinkQuietly(`${this.dir}/${song.lrc}`);
        }
        this.byKey.delete(song.key);
        this.byFingerprint.delete(song.fingerprint);
        removed++;
        continue;
      }
      remains.push(song);
    }
    if (removed === 0) {
      return 0;
    }
    this.songs = remains;
    for (const listId of Array.from(this.lists.keys())) {
      const kept: string[] = this.listKeys(listId).filter((key: string) => !keys.includes(key));
      if (kept.length === 0) {
        this.lists.delete(listId);
      } else {
        this.lists.set(listId, kept);
      }
    }
    this.dropStoreRows(keys);
    this.persist();
    this.bumpVersion();
    appendPlayLog(`[本地音乐] 删除 ${removed} 首（副本 + 歌单收藏引用一起清）`);
    return removed;
  }

  /** 清空全部（歌单侧表与 store 里的本地行一起清） */
  clear(): void {
    const keys: string[] = [];
    for (const song of this.songs) {
      keys.push(song.key);
    }
    this.removeKeys(keys);
  }

  /** 把本地行从收藏与所有歌单里摘掉（MusicStoreService 那份数据） */
  private dropStoreRows(keys: string[]): void {
    if (keys.length === 0) {
      return;
    }
    try {
      const store: MusicStoreService = MusicStoreService.getInstance();
      for (const key of keys) {
        store.removeFavorite(LOCAL_SOURCE, key);
      }
      const playlists: Record<string, string[]> = this.snapshot();
      for (const playlistId of Object.keys(playlists)) {
        // 侧表里记过这个歌单，就把这几首本地歌从 store 的歌单里摘掉
        for (const key of keys) {
          store.removeSongFromPlaylist(playlistId, LOCAL_SOURCE, key);
        }
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'drop store rows failed: %{public}s', JSON.stringify(e));
    }
  }

  // ------------------------------------------------------------ 歌单 / 收藏侧表

  /** 某个歌单里的本地歌 key（按加入顺序，最新的在最前） */
  listKeys(listId: string): string[] {
    const keys: string[] | undefined = this.lists.get(listId);
    return keys === undefined ? [] : keys;
  }

  listCount(listId: string): number {
    return this.listKeys(listId).length;
  }

  /** 某个歌单里的本地歌条目（给歌单页合并用：本地歌排在前面） */
  listSongItems(listId: string): SongItem[] {
    return this.songsByKeys(this.listKeys(listId));
  }

  /** 写入某个歌单的本地歌 key（顺序即展示顺序） */
  setListKeys(listId: string, keys: string[]): void {
    const current: string[] = this.listKeys(listId);
    if (current.length === keys.length && current.every((key: string, i: number) => key === keys[i])) {
      return;
    }
    if (keys.length === 0) {
      this.lists.delete(listId);
    } else {
      this.lists.set(listId, keys.slice());
    }
    this.persist();
    this.bumpVersion();
  }

  /** 往歌单里加（新的排最前，与在线歌曲「新加的排最前」一致）；返回真正加进去的数量 */
  addToList(listId: string, keys: string[]): number {
    const fresh: string[] = [];
    const current: string[] = this.listKeys(listId);
    for (const key of keys) {
      if (current.includes(key) || fresh.includes(key)) {
        continue;
      }
      fresh.push(key);
    }
    if (fresh.length === 0) {
      return 0;
    }
    this.setListKeys(listId, fresh.concat(current));
    return fresh.length;
  }

  /** @returns 真正被摘掉的条数 */
  removeFromList(listId: string, keys: string[]): number {
    if (keys.length === 0) {
      return 0;
    }
    const current: string[] = this.listKeys(listId);
    const kept: string[] = current.filter((key: string) => !keys.includes(key));
    if (kept.length === current.length) {
      return 0;
    }
    this.setListKeys(listId, kept);
    return current.length - kept.length;
  }

  /** 歌单被删掉了：侧表一起清 */
  dropLists(listIds: string[]): void {
    let changed: boolean = false;
    for (const listId of listIds) {
      if (this.lists.has(listId)) {
        this.lists.delete(listId);
        changed = true;
      }
    }
    if (changed) {
      this.persist();
      this.bumpVersion();
    }
  }

  /**
   * 把本地歌加进某个歌单：侧表 + MusicStoreService 的行一起写
   *
   * 两处都写的原因见文件头第 4 条：store 那份让歌单页立刻能显示，
   * 侧表那份记住「这些行是本地歌」，同步覆盖歌单后能重新合并回来。
   * @returns 侧表里真正新增的数量
   */
  addKeysToPlaylist(playlistId: string, keys: string[]): number {
    const fresh: number = this.addToList(playlistId, keys);
    const store: MusicStoreService = MusicStoreService.getInstance();
    for (const key of keys) {
      const entry: LocalSongEntry | undefined = this.byKey.get(key);
      if (entry !== undefined) {
        store.addSongToPlaylist(playlistId, this.toRecord(entry));
      }
    }
    return fresh;
  }

  /** 从某个歌单里摘掉本地歌：侧表 + store 一起删 */
  removeKeysFromPlaylist(playlistId: string, keys: string[]): number {
    const removed: number = this.removeFromList(playlistId, keys);
    const store: MusicStoreService = MusicStoreService.getInstance();
    for (const key of keys) {
      store.removeSongFromPlaylist(playlistId, LOCAL_SOURCE, key);
    }
    return removed;
  }

  /** 收藏一批本地歌：侧表（'love'）+ store 的收藏列表一起写 */
  addKeysToFavorites(keys: string[]): number {
    const fresh: number = this.addToList(LOVE_LIST_ID, keys);
    const store: MusicStoreService = MusicStoreService.getInstance();
    for (const key of keys) {
      const entry: LocalSongEntry | undefined = this.byKey.get(key);
      if (entry !== undefined) {
        store.addFavorite(this.toRecord(entry));
      }
    }
    return fresh;
  }

  /** 取消收藏一批本地歌 */
  removeKeysFromFavorites(keys: string[]): number {
    const removed: number = this.removeFromList(LOVE_LIST_ID, keys);
    const store: MusicStoreService = MusicStoreService.getInstance();
    for (const key of keys) {
      store.removeFavorite(LOCAL_SOURCE, key);
    }
    return removed;
  }

  /** 这条本地歌在不在收藏里（侧表为准，兜底问一下 store） */
  isFavorite(key: string): boolean {
    if (this.listKeys(LOVE_LIST_ID).includes(key)) {
      return true;
    }
    return MusicStoreService.getInstance().isFavorite(LOCAL_SOURCE, key);
  }

  /** 收藏的本地歌条目 */
  favoriteSongItems(): SongItem[] {
    return this.songsByKeys(this.listKeys(LOVE_LIST_ID));
  }

  // ------------------------------------------------------------ 落盘

  private load(): void {
    this.songs = [];
    this.lists = new Map<string, string[]>();
    this.byKey.clear();
    this.byFingerprint.clear();
    this.autoMatch = true;
    const text: string | null = this.readText(`${this.dir}/${INDEX_FILE}`);
    if (text !== null) {
      try {
        const raw: LocalIndex = JSON.parse(text) as LocalIndex;
        this.songs = normalizeSongs(raw.songs);
        this.lists = normalizeLists(raw.lists);
        if (typeof raw.autoMatchLyric === 'boolean') {
          this.autoMatch = raw.autoMatchLyric;
        }
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'parse index failed: %{public}s', JSON.stringify(e));
      }
    }
    for (const song of this.songs) {
      this.byKey.set(song.key, song);
      this.byFingerprint.add(song.fingerprint);
    }
    this.sweepOrphans();
  }

  /**
   * 清掉索引里没有的文件，以及索引里有、文件却不在的条目
   *
   * 导入是「先拷文件、后写索引」：中途被杀进程（或取消）会留下没有索引的副本，
   * 这些文件谁也播不了、还白占空间。反过来索引里有、文件不在的条目也顺手清掉
   * （用户在文件管理器里删过、或者清了应用数据）。
   */
  sweepOrphans(): void {
    if (!this.ready) {
      return;
    }
    const known: Set<string> = new Set<string>();
    const missing: string[] = [];
    for (const song of this.songs) {
      known.add(song.file);
      if (song.cover.length > 0) {
        known.add(`${COVER_DIR}/${song.cover}`);
      }
      if (song.lrc.length > 0) {
        known.add(song.lrc);
      }
      try {
        if (!fs.accessSync(`${this.dir}/${song.file}`)) {
          missing.push(song.key);
        }
      } catch (e) {
        missing.push(song.key);
      }
    }
    let changed: boolean = missing.length > 0;
    if (missing.length > 0) {
      hilog.warn(DOMAIN, TAG, 'drop %{public}d missing local songs', missing.length);
      this.songs = this.songs.filter((song: LocalSongEntry) => !missing.includes(song.key));
      for (const key of missing) {
        const song: LocalSongEntry | undefined = this.byKey.get(key);
        if (song !== undefined) {
          this.byFingerprint.delete(song.fingerprint);
        }
        this.byKey.delete(key);
      }
      for (const listId of Array.from(this.lists.keys())) {
        const kept: string[] = this.listKeys(listId).filter((key: string) => !missing.includes(key));
        if (kept.length === 0) {
          this.lists.delete(listId);
        } else {
          this.lists.set(listId, kept);
        }
      }
    }
    try {
      for (const name of fs.listFileSync(this.dir)) {
        if (name === INDEX_FILE || name === COVER_DIR || known.has(name)) {
          continue;
        }
        // 导入是「先拷文件、后写索引」：这里剩下的都是没有索引的副本（拷到一半被杀进程），
        // 谁也播不了，清掉。这个目录只有本模块在写，所以不在索引里就是垃圾。
        hilog.warn(DOMAIN, TAG, 'remove orphan file: %{public}s', name);
        unlinkQuietly(`${this.dir}/${name}`);
        changed = true;
      }
      for (const name of fs.listFileSync(this.coverDir)) {
        if (known.has(`${COVER_DIR}/${name}`)) {
          continue;
        }
        unlinkQuietly(`${this.coverDir}/${name}`);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'sweep dir failed: %{public}s', JSON.stringify(e));
    }
    if (changed) {
      this.persist();
    }
  }

  private persist(): void {
    if (!this.ready) {
      return;
    }
    const index: LocalIndex = {
      version: INDEX_VERSION,
      songs: this.songs,
      lists: this.snapshot(),
      autoMatchLyric: this.autoMatch
    };
    try {
      const handle: fs.File = fs.openSync(`${this.dir}/${INDEX_FILE}`,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(handle.fd, JSON.stringify(index));
      } finally {
        fs.closeSync(handle);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save index failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 内存侧表（Map）-> 落盘形态（Record）；ArkTS 不允许 delete，所以内存里一律用 Map */
  private snapshot(): Record<string, string[]> {
    const out: Record<string, string[]> = {};
    for (const listId of Array.from(this.lists.keys())) {
      out[listId] = this.lists.get(listId) ?? [];
    }
    return out;
  }

  private readText(path: string): string | null {
    try {
      if (!fs.accessSync(path)) {
        return null;
      }
      return fs.readTextSync(path);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'readText failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  private bumpVersion(): void {
    const state: LocalMusicImportState = localMusicImportState();
    state.version = state.version + 1;
  }
}

/** 进程内单例（'localmusic' 包对外导出它，主 agent 直接用它接线） */
export let localMusic: LocalMusic = LocalMusic.getInstance();

// ------------------------------------------------------------ 工具

/**
 * 这条是不是本地歌（设备里导入进来的音频）
 *
 * 界面上要按它来隐藏「下载 / 音质」这些对本地文件没有意义的入口。
 * 放成函数而不是各处写 `source === 'local'`：拼错字符串是静默失效，很难查。
 */
export function isLocalSong(item: SongItem): boolean {
  return item.source === LOCAL_SOURCE;
}

/**
 * 这个文件名的后缀是不是 AVPlayer 能播的音频格式
 *
 * 不在列表里的（ape / wma / dsf / dff…）导入时要明确告诉用户「格式不支持」，
 * 不能静默跳过 —— 用户会以为导入成功了。
 */
export function isSupportedAudioFile(name: string): boolean {
  return SUPPORTED_EXTS.includes(extOf(name));
}

/** 明知放不了、但确实是音频的后缀（只有这些才报「格式不支持」） */
export function isUnsupportedAudioFile(name: string): boolean {
  return UNSUPPORTED_AUDIO_EXTS.includes(extOf(name));
}

/**
 * 完全不该参与导入的文件：歌词、封面图、说明文本等等
 *
 * 选文件夹时它们会一起进来（`listFileSync` 返回目录下的所有名字），
 * 静默跳过即可，既不算失败也不出现在进度里。
 */
export function isIgnorableFile(name: string): boolean {
  return !isSupportedAudioFile(name) && !isUnsupportedAudioFile(name);
}

/** 空的导入统计（带一句提示） */
function emptyResult(message: string): ImportResult {
  return { added: 0, skipped: 0, unsupported: 0, failed: 0, message: message };
}

/** 目录 URI -> 目录里的文件 URI（不含子目录） */
function listFolderFiles(dirUri: string): string[] {
  const out: string[] = [];
  try {
    const names: string[] = fs.listFileSync(dirUri);
    for (const name of names) {
      out.push(`${dirUri}/${name}`);
    }
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'list folder failed: %{public}s', JSON.stringify(e));
    return [];
  }
  return out;
}

function asText(value: string | undefined): string {
  return typeof value === 'string' ? value : '';
}

/** AVMetadata 的 duration 是字符串（毫秒） */
function asNumber(value: string | undefined): number {
  if (typeof value !== 'string') {
    return 0;
  }
  const parsed: number = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? 0 : parsed;
}

/** 从 URI 里取出文件名（Picker 会把中文与特殊字符编码进 URI） */
function fileNameOf(uri: string): string {
  const cut: number = uri.lastIndexOf('/');
  const raw: string = cut >= 0 ? uri.substring(cut + 1) : uri;
  try {
    return decodeURIComponent(raw);
  } catch (e) {
    return raw;
  }
}

function extOf(name: string): string {
  const dot: number = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot).toLowerCase();
}

/**
 * 音频 URI -> 可能的同名歌词 URI（大小写两种写法）
 *
 * URI 里的中文与特殊字符是百分号编码的，所以只做后缀替换、不碰文件名本身。
 */
function siblingLrcBases(audioUri: string): string[] {
  const slash: number = audioUri.lastIndexOf('/');
  const dot: number = audioUri.lastIndexOf('.');
  // 点在最后一段里才算后缀（否则可能是目录名里的点）
  if (dot <= slash + 1) {
    return [];
  }
  const base: string = audioUri.substring(0, dot);
  return [`${base}.lrc`, `${base}.LRC`];
}

function stripExt(name: string): string {
  const dot: number = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/**
 * 没有标签时用文件名兜底
 * 常见命名是「歌手 - 歌名」（下载设置里也有这个格式），只在文件名单一时才拆。
 */
export function titleFromFileName(label: string): string {
  const base: string = stripExt(label);
  const sep: number = base.indexOf(' - ');
  if (sep <= 0 || sep >= base.length - 3) {
    return base;
  }
  return base.substring(sep + 3);
}

/** 文件名的「歌手」那一半（与 titleFromFileName 配套） */
export function singerFromFileName(label: string): string {
  const base: string = stripExt(label);
  const sep: number = base.indexOf(' - ');
  return sep > 0 ? base.substring(0, sep) : '';
}

/** 毫秒 -> mm:ss（SongItem.interval 的口径，与在线歌曲一致） */
function formatInterval(ms: number): string {
  if (ms <= 0) {
    return '';
  }
  const total: number = Math.floor(ms / 1000);
  const minutes: number = Math.floor(total / 60);
  const seconds: number = total % 60;
  return `${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
}

function normalizeSongs(input: LocalSongEntry[] | undefined): LocalSongEntry[] {
  if (!Array.isArray(input)) {
    return [];
  }
  const out: LocalSongEntry[] = [];
  for (const item of input) {
    if (item === null || item === undefined) {
      continue;
    }
    if (typeof item.key !== 'string' || item.key.length === 0) {
      continue;
    }
    if (typeof item.file !== 'string' || item.file.length === 0) {
      continue;
    }
    out.push({
      key: item.key,
      file: item.file,
      cover: typeof item.cover === 'string' ? item.cover : '',
      lrc: typeof item.lrc === 'string' ? item.lrc : '',
      matchJson: typeof item.matchJson === 'string' ? item.matchJson : '',
      matchSource: typeof item.matchSource === 'string' ? item.matchSource : '',
      matchAt: typeof item.matchAt === 'number' ? item.matchAt : 0,
      name: typeof item.name === 'string' ? item.name : '',
      singer: typeof item.singer === 'string' ? item.singer : '',
      album: typeof item.album === 'string' ? item.album : '',
      durationMs: typeof item.durationMs === 'number' ? item.durationMs : 0,
      sizeBytes: typeof item.sizeBytes === 'number' ? item.sizeBytes : 0,
      addedAt: typeof item.addedAt === 'number' ? item.addedAt : 0,
      fingerprint: typeof item.fingerprint === 'string' ? item.fingerprint : ''
    });
  }
  return out;
}

function normalizeLists(input: Record<string, string[]> | undefined): Map<string, string[]> {
  const out: Map<string, string[]> = new Map<string, string[]>();
  if (input === undefined || input === null) {
    return out;
  }
  for (const listId of Object.keys(input)) {
    const keys: string[] = input[listId];
    if (!Array.isArray(keys)) {
      continue;
    }
    const kept: string[] = [];
    for (const key of keys) {
      if (typeof key === 'string' && key.length > 0 && !kept.includes(key)) {
        kept.push(key);
      }
    }
    if (kept.length > 0) {
      out.set(listId, kept);
    }
  }
  return out;
}

/** 整份读出一个小文件（歌词用）；读不到或超过上限返回 null */
function readBytes(path: string): Uint8Array | null {
  let file: fs.File | null = null;
  try {
    file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    const size: number = fs.statSync(file.fd).size;
    if (size <= 0 || size > LRC_MAX_BYTES) {
      return null;
    }
    const buffer: ArrayBuffer = new ArrayBuffer(size);
    const read: number = fs.readSync(file.fd, buffer, { offset: 0, length: size });
    return new Uint8Array(buffer, 0, read);
  } catch (e) {
    return null;
  } finally {
    closeQuietly(file);
  }
}

/** 按指定编码解文本；编码不支持就返回空串（调用方自己有兜底） */
function decodeText(bytes: Uint8Array, encoding: string): string {
  try {
    const decoder: util.TextDecoder = util.TextDecoder.create(encoding);
    return decoder.decodeToString(bytes);
  } catch (e) {
    return '';
  }
}

function closeQuietly(file: fs.File | null): void {
  if (file === null) {
    return;
  }
  try {
    fs.closeSync(file);
  } catch (e) {
    // 已经关掉了，不处理
  }
}

function unlinkQuietly(path: string): void {
  try {
    fs.unlinkSync(path);
  } catch (e) {
    // 文件不在了就当删好了
  }
}
