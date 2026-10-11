/*
 * WebDAV 云端曲库（照搬参考工程 lxmusic-harmony 的 core/webdav/WebDavClient.ets
 * + core/webdav/WebDavLibrary.ets，按 RzdMusic 的既有能力收口）
 *
 * ## 它是什么
 *
 * 「我的 → 云端音乐」那一页的数据层：`PROPFIND` 递归列我们**自己那台 WebDAV 服务器**
 * 上的音乐目录 → 按音频后缀过滤 → 组装成可直接播的条目 → 暴露给界面。
 * 与「洛雪同步」无关（那是另一个人家的服务端），与「本地音乐」的区别是**音频在服务器上**。
 *
 * ## 凭据 / 基址从哪来（**没有第二份配置，也没有硬编码口令**）
 *
 * 全部复用 `features/sync` 既有的那条备份链：
 *   `WebDavBackupService.readConfig()`
 *     → `MusicStoreService.getInstance().getWebDavConfig()`   （preferences `webdav_config`）
 * 也就是说：**用户在「设置 → 同步 → WebDAV 备份」里填的那套地址/账号/口令**就是云端曲库的配置，
 * 一个字段都不重复填。口令只在这条链上流动，不写进任何常量、不进日志。
 *
 * ## 播放怎么走（一条明确的取舍，改之前先读完）
 *
 * 官方**是**支持「带请求头的网络播放」的：`media.createMediaSourceWithUrl(url, headers)`
 * + `avPlayer.setMediaSource(...)`（官方《播放URL设置方式》原文，headers 可设
 * `User-Agent` / `Cookie` / `Referer` 等，Basic 认证头同理）。但本工程的播放器
 * （`features/player` 的 `SongItemBuilder.build` → `MediaService.loadCurrentIntoPlayer`）
 * **只设 `avPlayer.url`，没有 mediaSource 这条路**，也就是**无处可塞 `Authorization`**。
 *
 * 三个选项：
 *   a) 改播放器加 mediaSource 分支 —— 那要动 `features/player`，本模块不许改（越界）；
 *   b) 把 `用户名:口令@` 塞进 URL（`https://user:pass@host/...`）—— 口令会进日志/历史/备份，
 *      且 `WebDavBackupService.validate()` 明确禁止内嵌凭据的地址，**不做**；
 *   c) **先下载到应用沙箱，再按本地文件播** —— 就是本文件的做法。
 *
 * c) 的代价与收益（写清楚，别当成"没实现"）：
 *   - 代价：**首播要等整首下完**（没有边下边播；进度通过 `onProgress` 报到界面）；
 *     本地会占一份音频空间（在「缓存占用」里如实显示，**支持单条与全部清空**）。
 *   - 收益：播完第一次之后**离线可播、秒起**；不碰音源脚本、不依赖 LX 引擎；
 *     与「本地音乐」共用同一条**已经上机验证过的**沙箱 fd 播放直路（`source = 'local'`）。
 *
 * ## 与我们既有实现的复用（不另起一套鉴权）
 *
 * HTTP、Basic 头、超时、错误码翻译全部自己写在这一个文件里，但**取配置走既有链**
 * （见上），Base64 编码口径与 `WebDavBackupService.request` 逐字相同
 * （`new util.TextEncoder().encodeInto(user + ':' + password)` + `Base64Helper`）。
 */

import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { media } from '@kit.MediaKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { MusicAppState, PlaybackIntentState, SongItem, appendError, getAppRuntime } from 'musicbasic';
import { WebDavBackupService } from './WebDavBackupService';
import { PROPFIND_BODY, buildEntries, parsePropfind, withTrailingSlash } from './WebDavXml';
import {
  WEBDAV_PLAY_SOURCE,
  WebDavCollectResult,
  WebDavConfig,
  WebDavEntry,
  WebDavProbeResult,
  WebDavScanResult,
  WebDavTags,
  emptyCollectResult,
  emptyScanResult,
  emptyTags,
  extOf,
  isImageFile,
  isLyricFile,
  isSupportedAudioFile,
  isUnsupportedAudioFile,
  parseTrackName,
  stripExt
} from './WebDavTypes';

// 曲库的对外面：协议层那三个文件只在模块内部用，界面统一从本文件取
// （`WebDavXml.PROPFIND_BODY` 之类协议细节不该泄漏到视图层）。
// ⚠️ 一条 import 只对应一条 export 再导出：名字多写/少写都会当场报错。
export {
  emptyTags,
  extOf,
  isSupportedAudioFile,
  isUnsupportedAudioFile,
  parseTrackName
} from './WebDavTypes';
export type {
  WebDavCollectResult,
  WebDavConfig,
  WebDavEntry,
  WebDavProbeResult,
  WebDavScanResult,
  WebDavTags
} from './WebDavTypes';

const DOMAIN: number = 0x0001;
const TAG: string = 'RzdWebDavCloud';

/** 所有日志统一走这个 tag，真机一眼过滤：`hdc shell hilog | findstr RzdWebDavCloud` */
const LOG_TAG: string = 'RzdWebDavCloud';

/** PROPFIND / GET 的超时（毫秒）：目录大时服务器要现场遍历，给得比普通请求宽一些 */
const LIST_TIMEOUT_MS: number = 20000;
/** 读远端标签的超时：只是取文件头，超过这个时间就当这台服务器不支持 */
const TAG_TIMEOUT_MS: number = 12000;
/** 下载单首音频的超时：整首下完，给得足够宽 */
const AUDIO_TIMEOUT_MS: number = 60000;
/** 递归收集时的上限，防止手滑选了「根目录」把整个网盘扫一遍 */
const MAX_FOLDERS: number = 300;
const MAX_AUDIO_ENTRIES: number = 5000;
/** 不落盘的单个音频上限（字节）：超过就当「远端太大，不在本机缓存」 */
const MAX_CACHE_FILE_BYTES: number = 200 * 1024 * 1024;

/** 沙箱目录（都在 filesDir 下；下载的音频在 cache 子目录，清缓存就是删它） */
const LIB_DIR: string = 'webdav_cloud';
const AUDIO_DIR: string = 'audio';
const INDEX_FILE: string = 'index.json';
const INDEX_VERSION: number = 1;

/**
 * 扫描时往下走几层
 *
 * 音乐库的组织方式基本都是 `歌手/专辑/歌`（3 层），给到 5 层足够；再深多半是网盘里
 * 乱七八糟的目录，扫下去只会又慢又乱。与 MAX_FOLDERS / MAX_AUDIO_ENTRIES 配套。
 */
const SCAN_DEPTH: number = 5;

/** Base64Helper 是类，要实例化（`WebDavBackupService` 里也是这么用的） */
const BASE64 = new util.Base64Helper();

// ─────────────────────────────────────────────────────────── 数据类型

/**
 * 一条云端歌曲（= 服务器上的一个音频文件 + 它在本地的一点点缓存状态）
 *
 * 字段取名对齐我们的口径：展示要的（name/singer/album）在 `SongItem` 里一一对应，
 * `id` 用 `key` 换算（见 `songItemOf`）。
 */
export interface WebDavSong {
  /**
   * 稳定标识（由 URL 派生的哈希，见 `stableKeyOf`）
   *
   * 「同一个 URL 永远得到同一个 key」是必须保住的性质：它同时是
   * ① 本地音频缓存的文件名前缀 ② 入队条目的 `songId` ③ 列表 `LazyForEach` 的 key。
   * 重新扫描后只要 URL 没变，缓存就一直命中。
   */
  key: string;
  /** 服务器上的绝对 URL（列目录、下载都用它） */
  url: string;
  /** 父目录 URL（界面分组显示用） */
  folder: string;
  /** 文件名（含后缀） */
  file: string;
  /** 歌名（远端标签优先，读不到时按 `歌手 - 歌名` 惯例从文件名拆） */
  name: string;
  singer: string;
  album: string;
  /** 毫秒；读不到远端标签时为 0（播放时以播放器报的时长为准） */
  durationMs: number;
  /** 服务器上的字节数（-1 = 服务器没给） */
  sizeBytes: number;
  /** 最近一次扫描见到它的时刻 */
  seenAt: number;
  /** 最近一次扫描有没有见到它（列表只显示这次见到的） */
  seen: boolean;
  /** 远端标签读过了（读不到也算读过），避免每次扫描都重问 */
  tagsDone: boolean;
  /** 本地缓存的文件名（在 audio 子目录里）；空串 = 还没下到本机 */
  local: string;
  /** 本地缓存的大小（字节，0 = 没缓存）；给「缓存占用」用 */
  localBytes: number;
}

/** 一次下载的进度（界面据此显示"正在缓存 42%"） */
export interface WebDavDownloadProgress {
  /** 0..1；未知总长时为 -1 */
  ratio: number;
  received: number;
  total: number;
}

interface WebDavIndex {
  version: number;
  /** 上次扫描的根地址（换了服务器地址就要重扫） */
  root: string;
  scannedAt: number;
  truncated: boolean;
  songs: WebDavSong[];
}

// ─────────────────────────────────────────────────────────── 协议层（原 WebDavClient）

/**
 * WebDAV 客户端（只做协议：列目录、GET）
 *
 * 三个关键点（照搬参考的结论）：
 *  1. **PROPFIND 不是标准方法**，`@ohos.net.http` 的 `RequestMethod` 枚举里没有它。
 *     `RequestOptions.customMethod` 就是为这种扩展协议开的（官方注释里直接写了
 *     "when the WebDAV extension protocol is implemented"），比伪造枚举值可靠。
 *  2. **认证只做 HTTP Basic**。自建服务（Nextcloud / Alist / 群晖 / Apache mod_dav）
 *     基本都支持 Basic；服务器只提供 Digest 时给一句明确的话，不做半吊子实现。
 *  3. **失败原因要翻译成人话**（见 `assertOk`）：401 是账号密码、403 是权限、
 *     404 是路径、405/501 是服务器不支持 PROPFIND。
 */
export class WebDavClient {
  private static instance: WebDavClient | null = null;

  static getInstance(): WebDavClient {
    if (WebDavClient.instance === null) {
      WebDavClient.instance = new WebDavClient();
    }
    return WebDavClient.instance;
  }

  /**
   * 请求头
   *
   * 用户名与口令都为空时不带 Authorization：Alist 之类默认匿名可读，
   * 带上空凭据反而会被拒。
   */
  authHeaders(config: WebDavConfig): Record<string, string> {
    const out: Record<string, string> = {};
    if (config.user.length === 0 && config.password.length === 0) {
      return out;
    }
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(config.user + ':' + config.password);
    out['Authorization'] = 'Basic ' + BASE64.encodeToStringSync(bytes);
    return out;
  }

  /** 列一个目录（Depth: 1，只要下一层） */
  async list(config: WebDavConfig, folderUrl: string): Promise<WebDavEntry[]> {
    const target: string = withTrailingSlash(folderUrl);
    const headers: Record<string, string> = this.authHeaders(config);
    headers['Depth'] = '1';
    headers['Content-Type'] = 'application/xml; charset=utf-8';
    headers['Accept'] = 'application/xml, text/xml, */*';
    const request = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        customMethod: 'PROPFIND',
        header: headers,
        extraData: PROPFIND_BODY,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: LIST_TIMEOUT_MS,
        readTimeout: LIST_TIMEOUT_MS
      };
      const response: http.HttpResponse = await request.request(target, options);
      assertOk(response, config);
      const text: string = typeof response.result === 'string' ? response.result : '';
      return buildEntries(config.url, target, parsePropfind(text));
    } finally {
      request.destroy();
    }
  }

  /**
   * 递归收集一个目录下的音频（含子目录）
   *
   * 广度优先一层层走，每层发一次 PROPFIND；目录数与条目数都有上限，
   * 达到上限就停下并如实报告 `truncated`，**不假装扫完了**。
   *
   * @param maxDepth 目录层级上限（0 = 只看这一层）。`音乐/<歌手>/<专辑>/<歌>` 是 3 层
   * @param onProgress 进度文案回调（界面显示"正在读第 N 个目录"）
   */
  async collectAudio(config: WebDavConfig, startUrl: string, maxDepth: number,
    onProgress: (text: string) => void): Promise<WebDavCollectResult> {
    const result: WebDavCollectResult = emptyCollectResult();
    const visited: Set<string> = new Set<string>();
    let pending: string[] = [withTrailingSlash(startUrl)];
    let depth: number = 0;
    while (pending.length > 0) {
      const next: string[] = [];
      for (const folder of pending) {
        if (visited.has(folder) || visited.size >= MAX_FOLDERS) {
          if (visited.size >= MAX_FOLDERS) {
            result.truncated = true;
          }
          continue;
        }
        visited.add(folder);
        result.folders++;
        onProgress(`正在读取第 ${result.folders} 个目录（已找到 ${result.entries.length} 首）`);
        let entries: WebDavEntry[] = [];
        try {
          entries = await this.list(config, folder);
        } catch (e) {
          result.failedFolders++;
          hilog.warn(DOMAIN, TAG, 'list folder failed: %{public}s', (e as Error).message);
          continue;
        }
        for (const entry of entries) {
          if (entry.isCollection) {
            if (depth < maxDepth && !visited.has(withTrailingSlash(entry.url))) {
              next.push(withTrailingSlash(entry.url));
            }
            continue;
          }
          // 歌词、封面图这些不是歌曲，静默跳过（由曲库那一层单独取封面）
          if (isLyricFile(entry.name) || isImageFile(entry.name)) {
            continue;
          }
          result.entries.push(entry);
          if (result.entries.length >= MAX_AUDIO_ENTRIES) {
            result.truncated = true;
            return result;
          }
        }
      }
      if (next.length === 0) {
        break;
      }
      pending = next;
      depth++;
    }
    return result;
  }

  /** 连接自检：列一次根目录，把失败原因翻译成一句人话 */
  async probe(config: WebDavConfig): Promise<WebDavProbeResult> {
    if (config.url.length === 0) {
      return { ok: false, message: '还没有填服务器地址（设置 → 同步 → WebDAV 备份）', entryCount: 0 };
    }
    try {
      const entries: WebDavEntry[] = await this.list(config, config.url);
      let folders: number = 0;
      for (const entry of entries) {
        if (entry.isCollection) {
          folders++;
        }
      }
      return {
        ok: true,
        message: `连上了：根目录下 ${folders} 个文件夹、${entries.length - folders} 个文件`,
        entryCount: entries.length
      };
    } catch (e) {
      return { ok: false, message: (e as Error).message, entryCount: 0 };
    }
  }

  /** 读远端音频文件的标签（`setUrlSource(url, headers)`：官方唯一的带请求头读网络元数据那条路） */
  async readTags(config: WebDavConfig, url: string): Promise<WebDavTags> {
    let extractor: media.AVMetadataExtractor | null = null;
    try {
      extractor = await media.createAVMetadataExtractor();
      const target: media.AVMetadataExtractor = extractor;
      target.setUrlSource(url, this.authHeaders(config));
      const meta: media.AVMetadata | null = await withTimeout(target.fetchMetadata(), TAG_TIMEOUT_MS);
      if (meta === null) {
        return emptyTags();
      }
      return {
        title: asText(meta.title),
        artist: asText(meta.artist),
        album: asText(meta.album),
        durationMs: asNumber(meta.duration)
      };
    } catch (e) {
      hilog.info(DOMAIN, TAG, 'read remote tags failed: %{public}s', (e as Error).message);
      return emptyTags();
    } finally {
      if (extractor !== null) {
        try {
          await extractor.release();
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'release extractor failed: %{public}s', JSON.stringify(e));
        }
      }
    }
  }

  /**
   * 把远端文件**下载到应用沙箱**（云端歌播放走的取舍，见文件头）
   *
   * @param destPath 沙箱里的目标绝对路径
   * @param onProgress 进度回调（未知总长时 ratio = -1）
   * @returns 落盘字节数
   */
  async downloadToFile(config: WebDavConfig, url: string, destPath: string,
    onProgress: (progress: WebDavDownloadProgress) => void): Promise<number> {
    const request = http.createHttp();
    // 先落到 `.part` 再改名：中途失败/被杀不会留下一个"看起来下好了"的半截文件
    const tempPath: string = `${destPath}.part`;
    let handle: fs.File | null = null;
    try {
      const headers: Record<string, string> = this.authHeaders(config);
      headers['Accept'] = 'audio/*, application/octet-stream, */*';
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: LIST_TIMEOUT_MS,
        readTimeout: AUDIO_TIMEOUT_MS,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      };
      let received: number = 0;
      let total: number = -1;
      handle = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const opened: fs.File = handle;
      // 分块落盘：整首音频（十几 MB）先读进内存再写，低端机上很容易被系统掐掉
      request.on('dataReceive', (data: ArrayBuffer) => {
        if (data.byteLength === 0) {
          return;
        }
        fs.writeSync(opened.fd, data);
      });
      // 进度**只信 dataReceiveProgress**：`dataReceive` 的回调时机与 order 不保证，
      // 用它的字节数累加会与实际写入量对不上（官方给了专用事件就别自己数）。
      request.on('dataReceiveProgress', (info: http.DataReceiveProgressInfo) => {
        received = info.receiveSize;
        total = info.totalSize;
        onProgress({ ratio: total > 0 ? received / total : -1, received: received, total: total });
      });
      const response: http.HttpResponse = await request.request(url, options);
      assertOk(response, config);
      if (received === 0 && response.result instanceof ArrayBuffer) {
        // 兜底：这个端上没派发进度事件时，把整块写一次
        const buffer: ArrayBuffer = response.result as ArrayBuffer;
        fs.writeSync(opened.fd, buffer);
        received = buffer.byteLength;
        onProgress({ ratio: 1, received: received, total: received });
      }
      fs.closeSync(opened);
      handle = null;
      if (received <= 0) {
        throw new Error('服务器返回了空文件');
      }
      if (received > MAX_CACHE_FILE_BYTES) {
        throw new Error(`文件太大（${formatBytes(received)}），不在本机缓存`);
      }
      // 原子换名：rename 在同一目录内是原子的
      unlinkQuietly(destPath);
      fs.renameSync(tempPath, destPath);
      return received;
    } catch (e) {
      if (handle !== null) {
        try {
          fs.closeSync(handle);
        } catch (closeError) {
          // 关不上也不能让它盖住真正的失败原因
        }
      }
      unlinkQuietly(tempPath);
      throw new Error(`下载失败：${(e as Error).message}`);
    } finally {
      request.destroy();
    }
  }
}

// ─────────────────────────────────────────────────────────── 曲库（原 WebDavLibrary）

/**
 * 云端曲库（自建 WebDAV 服务器上的音乐）
 *
 * **没有「导入」这一步**：配置好服务器之后，进页面就把那个目录（含子目录）扫一遍，
 * 扫到的音频就是这个曲库 —— 点一下就能放，用户不需要先「添加」什么。
 *
 * 单例 + 结果缓存（照搬参考）：扫描结果落 `filesDir/webdav_cloud/index.json`，
 * **重进页面直接用缓存**（只有服务器地址变了或用户点刷新才重扫）。
 */
export class WebDavLibrary {
  private static instance: WebDavLibrary | null = null;

  static getInstance(): WebDavLibrary {
    if (WebDavLibrary.instance === null) {
      WebDavLibrary.instance = new WebDavLibrary();
    }
    return WebDavLibrary.instance;
  }

  private dir: string = '';
  private audioDir: string = '';
  private ready: boolean = false;
  private songs: WebDavSong[] = [];
  private byKey: Map<string, WebDavSong> = new Map<string, WebDavSong>();
  private byUrl: Map<string, WebDavSong> = new Map<string, WebDavSong>();
  private root: string = '';
  private scannedAt: number = 0;
  private truncated: boolean = false;
  private scanning: boolean = false;
  private cancelled: boolean = false;
  private progressText: string = '';
  /** 正在缓存的那首（key）；界面据此显示进度。空串 = 没有在缓存 */
  private cachingKeyValue: string = '';
  private cacheRatioValue: number = -1;

  /**
   * 初始化沙箱目录并读回上次的索引
   *
   * 不传 context 时自己从 `getAppRuntime().context` 取（与 `SyncStore.init()` 同一口径）；
   * 应用刚起来、context 还没灌进 AppStorage 时会返回 false，由调用方稍后重试。
   */
  init(context?: common.Context): boolean {
    if (this.ready) {
      return true;
    }
    const ctx: common.Context | undefined = context !== undefined ? context : getAppRuntime().context;
    if (ctx === undefined) {
      return false;
    }
    this.dir = `${ctx.filesDir}/${LIB_DIR}`;
    this.audioDir = `${this.dir}/${AUDIO_DIR}`;
    try {
      if (!fs.accessSync(this.dir)) {
        fs.mkdirSync(this.dir);
      }
      if (!fs.accessSync(this.audioDir)) {
        fs.mkdirSync(this.audioDir);
      }
      this.ready = true;
    } catch (e) {
      appendError(`[${TAG}] create dir failed: ${JSON.stringify(e)}`);
      this.ready = false;
      return false;
    }
    this.load();
    return true;
  }

  isReady(): boolean {
    return this.ready;
  }

  // ---------------------------------------------------------- 读取（界面用）

  /** 列表里那些歌（这次扫描见到的，按「目录 + 文件名」排：同一张专辑的歌挨在一起） */
  songsForUi(): WebDavSong[] {
    const out: WebDavSong[] = [];
    for (const song of this.songs) {
      if (song.seen) {
        out.push(song);
      }
    }
    return out;
  }

  count(): number {
    return this.songsForUi().length;
  }

  /** 列表里那些歌一共多大（服务器上的大小，不是本地占用） */
  totalBytes(): number {
    let sum: number = 0;
    for (const song of this.songs) {
      if (song.seen && song.sizeBytes > 0) {
        sum += song.sizeBytes;
      }
    }
    return sum;
  }

  /** 已缓存在本机的总字节数（「缓存占用」那一行用） */
  cachedBytes(): number {
    let sum: number = 0;
    for (const song of this.songs) {
      sum += song.localBytes;
    }
    return sum;
  }

  /** 上次扫描的根地址（与配置里的地址不一致就说明该重扫了） */
  scanRoot(): string {
    return this.root;
  }

  scanTime(): number {
    return this.scannedAt;
  }

  lastScanTruncated(): boolean {
    return this.truncated;
  }

  isScanning(): boolean {
    return this.scanning;
  }

  /** 扫描/缓存进度文案（空闲时是空串） */
  progress(): string {
    return this.progressText;
  }

  /** 正在缓存的 key（空串 = 没有在缓存）；配合 `cacheRatio()` 显示进度条 */
  cachingKey(): string {
    return this.cachingKeyValue;
  }

  cacheRatio(): number {
    return this.cacheRatioValue;
  }

  /** 这条歌本地缓存的文件绝对路径；没缓存返回空串 */
  localPathOf(key: string): string {
    const song: WebDavSong | undefined = this.byKey.get(key);
    if (song === undefined || song.local.length === 0) {
      return '';
    }
    return `${this.audioDir}/${song.local}`;
  }

  /** 这条歌是不是已经在本机（列表行给个「已缓存」标记，点播放就不用等下载） */
  isCached(key: string): boolean {
    const song: WebDavSong | undefined = this.byKey.get(key);
    return song !== undefined && song.local.length > 0;
  }

  byKeyOf(key: string): WebDavSong | undefined {
    return this.byKey.get(key);
  }

  // ---------------------------------------------------------- 扫描

  /**
   * 扫描配置里那个目录，把结果变成曲库
   *
   * 两步，先快后慢：
   *   1. **列目录**（递归到 SCAN_DEPTH 层）：拿到全部音频，按 URL 与已有条目对齐
   *      —— 还是同一首就把本地缓存（音频/标签）接过去；新的一首也不问任何东西，
   *      先按 `歌手 - 歌名` 的文件名惯例拆，所以列表**立刻就能用**；
   *   2. **补标签**（可选，`readTags=false` 时跳过）：远端标签（歌名/歌手/专辑/时长），
   *      让列表显示的是真名字而不是文件名。失败只是记日志，不影响播放。
   *
   * 任何一步失败都留下已完成的部分（与参考一致：一次扫描不全不该把列表掏空）。
   */
  async refresh(config: WebDavConfig, readTags: boolean,
    onProgress: (text: string) => void): Promise<WebDavScanResult> {
    const result: WebDavScanResult = emptyScanResult();
    if (!this.ready || config.url.length === 0) {
      return result;
    }
    if (this.scanning) {
      // 并发扫描只会互相覆盖：直接把上一次的结果回报给调用方
      result.total = this.count();
      result.truncated = this.truncated;
      return result;
    }
    this.scanning = true;
    this.cancelled = false;
    try {
      const collected: WebDavCollectResult = await WebDavClient.getInstance()
        .collectAudio(config, config.url, SCAN_DEPTH, (text: string) => {
          this.progressText = text;
          onProgress(text);
        });
      if (this.cancelled) {
        return result;
      }
      result.truncated = collected.truncated;
      result.failedFolders = collected.failedFolders;

      // 1) 对齐已有条目：按 URL 认出「还是同一首」，把本地缓存接过去
      const previous: WebDavSong[] = this.songs;
      const seenUrls: Set<string> = new Set<string>();
      const usedKeys: Set<string> = new Set<string>();
      const next: WebDavSong[] = [];
      const pending: WebDavSong[] = [];
      for (const entry of sortEntriesByUrl(collected.entries)) {
        if (!isSupportedAudioFile(entry.name)) {
          // wma / dsf 这些 AVPlayer 放不了，要报出来（否则看起来像「少了几首」）
          if (isUnsupportedAudioFile(entry.name)) {
            result.unsupported++;
          }
          continue;
        }
        if (seenUrls.has(entry.url)) {
          continue;
        }
        seenUrls.add(entry.url);
        const old: WebDavSong | undefined = this.byUrl.get(entry.url);
        if (old !== undefined) {
          usedKeys.add(old.key);
          old.seen = true;
          old.seenAt = Date.now();
          old.folder = entry.folder;
          old.file = entry.name;
          if (entry.size > 0) {
            old.sizeBytes = entry.size;
          }
          next.push(old);
          if (!old.tagsDone) {
            pending.push(old);
          }
          continue;
        }
        const key: string = this.freeKey(entry.url, usedKeys);
        usedKeys.add(key);
        const parsed: WebDavTags = parseTrackName(entry.name);
        const song: WebDavSong = {
          key: key,
          url: entry.url,
          folder: entry.folder,
          file: entry.name,
          name: parsed.title,
          singer: parsed.artist,
          album: parsed.album,
          durationMs: 0,
          sizeBytes: entry.size > 0 ? entry.size : -1,
          seenAt: Date.now(),
          seen: true,
          tagsDone: false,
          local: '',
          localBytes: 0
        };
        next.push(song);
        pending.push(song);
        result.added++;
      }
      // 这次没见到的先标记出来（服务器上真删了的下一次扫描清掉）
      for (const song of previous) {
        if (!seenUrls.has(song.url)) {
          song.seen = false;
        }
      }
      this.root = config.url;
      this.scannedAt = Date.now();
      this.truncated = collected.truncated;
      this.replaceAll(this.sortSongs(next));
      this.persist();
      hilog.info(DOMAIN, LOG_TAG, 'scan done total=%{public}d added=%{public}d folders=%{public}d',
        this.count(), result.added, collected.folders);

      // 2) 补标签（可选）
      if (readTags && pending.length > 0) {
        await this.enrichTags(config, pending, onProgress);
      }
      // 3) 清掉「这次没扫到」的条目（连同它的本地缓存）
      result.dropped = this.pruneUnseen();
      result.total = this.count();
      return result;
    } finally {
      this.scanning = false;
      this.progressText = '';
      this.persist();
    }
  }

  /** 用户取消扫描 / 补标签（当前这一批会做完，从下一批开始停） */
  cancelScan(): void {
    this.cancelled = true;
  }

  /**
   * 上一次扫描是不是**被用户取消**的
   *
   * 界面必须能区分「取消」与「真的没扫到」：取消时 `total` 也会是 0，
   * 直接按「失败/空」提示会冤枉服务器（用户自己按的取消，却被报成读不到）。
   */
  lastScanCancelled(): boolean {
    return this.cancelled;
  }

  /** 逐首补远端标签（串行：读标签要起 AVMetadataExtractor，并发只会互相抢资源） */
  private async enrichTags(config: WebDavConfig, pending: WebDavSong[],
    onProgress: (text: string) => void): Promise<void> {
    const total: number = pending.length;
    let done: number = 0;
    for (const song of pending) {
      if (this.cancelled) {
        break;
      }
      // 先记「问过了」再发请求：读不到标签的服务器不该每次扫描都重问一遍
      song.tagsDone = true;
      const tags: WebDavTags = await WebDavClient.getInstance().readTags(config, song.url);
      if (tags.title.length > 0) {
        song.name = tags.title;
      }
      if (tags.artist.length > 0) {
        song.singer = tags.artist;
      }
      if (tags.album.length > 0) {
        song.album = tags.album;
      }
      if (tags.durationMs > 0) {
        song.durationMs = tags.durationMs;
      }
      done++;
      const text: string = `正在读取云端信息 ${done}/${total} ${song.name}`;
      this.progressText = text;
      onProgress(text);
    }
    this.persist();
  }

  // ---------------------------------------------------------- 下载（播放前的取舍）

  /**
   * 把这首云端歌取到本机沙箱（已缓存则直接返回路径）
   *
   * @returns 沙箱里的绝对路径
   */
  async download(key: string, config: WebDavConfig,
    onProgress: (progress: WebDavDownloadProgress) => void): Promise<string> {
    const song: WebDavSong | undefined = this.byKey.get(key);
    if (song === undefined) {
      throw new Error('这首歌已经不在云端列表里了，刷新一下');
    }
    const existing: string = this.localPathOf(key);
    if (existing.length > 0 && fs.accessSync(existing)) {
      return existing;
    }
    if (this.cachingKeyValue.length > 0 && this.cachingKeyValue !== key) {
      throw new Error('正在缓存另一首，请稍候');
    }
    const name: string = this.localFileNameOf(song);
    const dest: string = `${this.audioDir}/${name}`;
    this.cachingKeyValue = key;
    this.cacheRatioValue = -1;
    try {
      const bytes: number = await WebDavClient.getInstance().downloadToFile(config, song.url, dest,
        (progress: WebDavDownloadProgress) => {
          this.cacheRatioValue = progress.ratio;
          onProgress(progress);
        });
      song.local = name;
      song.localBytes = bytes;
      this.persist();
      hilog.info(DOMAIN, LOG_TAG, 'cached key=%{public}s bytes=%{public}d', key, bytes);
      return dest;
    } finally {
      this.cachingKeyValue = '';
      this.cacheRatioValue = -1;
    }
  }

  /** 删掉一条的本地缓存（服务器上的文件不动） */
  dropLocal(key: string): boolean {
    const song: WebDavSong | undefined = this.byKey.get(key);
    if (song === undefined || song.local.length === 0) {
      return false;
    }
    unlinkQuietly(`${this.audioDir}/${song.local}`);
    song.local = '';
    song.localBytes = 0;
    this.persist();
    return true;
  }

  /** 清掉全部本地音频缓存（列表与标签保留；返回释放的字节数） */
  clearLocalCache(): number {
    let freed: number = 0;
    for (const song of this.songs) {
      if (song.local.length > 0) {
        freed += song.localBytes;
        unlinkQuietly(`${this.audioDir}/${song.local}`);
        song.local = '';
        song.localBytes = 0;
      }
    }
    try {
      for (const name of fs.listFileSync(this.audioDir)) {
        unlinkQuietly(`${this.audioDir}/${name}`);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clear cache dir failed: %{public}s', JSON.stringify(e));
    }
    this.persist();
    return freed;
  }

  // ---------------------------------------------------------- 组装播放条目

  /**
   * 一条云端歌 -> 可以入队的 `SongItem`
   *
   * ★ 关键取舍（见文件头）：`url` 给的是**沙箱里的本地路径**、`source` 给 `'local'`，
   * 这样 `MediaService.loadAsset` 走「沙箱文件直路」（自己开 fd → `avPlayer.fdSrc`），
   * 完全不碰音源脚本、也不需要有 LX 源。
   *
   * `songId` 保留云端 key（`'webdav_'` 前缀），`albumName` 保留云端目录名，
   * 所以历史/收藏里还能认出这是哪一首云端歌。歌名里带 `[云端]` 是为了让
   * 「本地文件播放」这条路上也能一眼看出它的来源（播放页不会显示 source）。
   */
  songItemOf(song: WebDavSong, localPath: string): SongItem {
    const item = new SongItem();
    // id 用稳定 key 的哈希（数字），同一首每次入队都一样，方便去重
    item.id = hashNumber(song.key);
    item.title = `[云端] ${song.name}`;
    item.singer = song.singer.length > 0 ? song.singer : '未知歌手';
    item.src = '';
    item.url = localPath;
    item.cover = '';
    item.source = WEBDAV_PLAY_SOURCE;
    item.songId = `webdav_${song.key}`;
    item.albumId = '';
    item.albumName = song.album.length > 0 ? song.album : folderNameOf(song.folder);
    item.interval = formatDuration(song.durationMs);
    item.qualityList = [];
    item.quality = WEBDAV_PLAY_SOURCE;
    item.playScript = 'WebDAV 云端';
    item.playCached = true;
    item.lyricText = '';
    return item;
  }

  /** 把一批云端歌入队到队尾（保留当前播放位置不动），返回真正入队的条数 */
  appendToQueue(songs: WebDavSong[], appState: MusicAppState): number {
    const queue: SongItem[] = [...appState.playQueue];
    let added: number = 0;
    for (const song of songs) {
      const path: string = this.localPathOf(song.key);
      if (path.length === 0) {
        continue;
      }
      const item: SongItem = this.songItemOf(song, path);
      let duplicated: boolean = false;
      for (const existing of queue) {
        if (existing.source === item.source && existing.songId === item.songId) {
          duplicated = true;
          break;
        }
      }
      if (duplicated) {
        continue;
      }
      queue.push(item);
      added++;
    }
    if (added > 0) {
      appState.playQueue = queue;
    }
    return added;
  }

  /**
   * 把一条云端歌插到「下一首播放」的位置
   *
   * 与 `features/playlist` 的批量「下一首播放」同一口径（`selectIndex + 1` 起依次插入）：
   * 那条路的实现在 `PlaylistBatchActionBar.batchPlayNext`，本模块不能 import playlist
   * （`playlist → sync` 已存在，反向会成环），所以这里按同一口径自己写一遍，
   * 逻辑只有十来行、没有第二份"业务规则"。
   */
  insertNext(song: WebDavSong, appState: MusicAppState): boolean {
    const path: string = this.localPathOf(song.key);
    if (path.length === 0) {
      return false;
    }
    const item: SongItem = this.songItemOf(song, path);
    const queue: SongItem[] = [...appState.playQueue];
    for (const existing of queue) {
      if (existing.source === item.source && existing.songId === item.songId) {
        // 已经在队列里：不重复插，但把它挪到下一首位置更符合"下一首播放"的语义
        const at: number = queue.indexOf(existing);
        queue.splice(at, 1);
        break;
      }
    }
    let insertAt: number = appState.selectIndex + 1;
    if (insertAt < 0 || insertAt > queue.length) {
      insertAt = queue.length;
    }
    queue.splice(insertAt, 0, item);
    appState.playQueue = queue;
    return true;
  }

  // ---------------------------------------------------------- 内部

  /** 本地缓存的文件名：`<key>_<清洗过的原名>.<后缀>` */
  private localFileNameOf(song: WebDavSong): string {
    const ext: string = extOf(song.file);
    const base: string = sanitize(stripExt(song.file));
    const short: string = base.length > 40 ? base.substring(0, 40) : base;
    return `${song.key}_${short}${ext.length > 0 ? ext : '.bin'}`;
  }

  /** 取一个没被占用的 key（同一份数据每次扫出来的结果都一样） */
  private freeKey(url: string, used: Set<string>): string {
    const base: string = stableKeyOf(url);
    if (!used.has(base)) {
      return base;
    }
    let seq: number = 2;
    while (used.has(`${base}_${seq}`)) {
      seq++;
    }
    return `${base}_${seq}`;
  }

  /** 按「目录 + 文件名」排（同一张专辑的歌挨在一起） */
  private sortSongs(songs: WebDavSong[]): WebDavSong[] {
    const out: WebDavSong[] = songs.slice();
    out.sort((a: WebDavSong, b: WebDavSong): number => {
      const left: string = `${a.folder}\u0000${a.file}`.toLowerCase();
      const right: string = `${b.folder}\u0000${b.file}`.toLowerCase();
      if (left < right) {
        return -1;
      }
      return left > right ? 1 : 0;
    });
    return out;
  }

  /**
   * 清掉「这次没扫到」的条目（连同它的本地缓存）
   *
   * 与参考那边的差别：参考会**留一段**（因为它的歌单/收藏引用了这些 key），
   * 我们的云端曲库不参与歌单/收藏（那条侧表在这个工程里没有对应物），
   * 所以没扫到就是真的没了，直接清 —— 但**如实报数**（`dropped`）。
   */
  private pruneUnseen(): number {
    const remains: WebDavSong[] = [];
    let dropped: number = 0;
    for (const song of this.songs) {
      if (song.seen) {
        remains.push(song);
        continue;
      }
      if (song.local.length > 0) {
        unlinkQuietly(`${this.audioDir}/${song.local}`);
      }
      dropped++;
    }
    if (dropped > 0) {
      hilog.info(DOMAIN, LOG_TAG, 'drop %{public}d unseen cloud songs', dropped);
      this.replaceAll(remains);
    }
    return dropped;
  }

  /** 重建索引里的三张表（songs / byKey / byUrl） */
  private replaceAll(songs: WebDavSong[]): void {
    this.songs = songs;
    this.byKey.clear();
    this.byUrl.clear();
    for (const song of songs) {
      this.byKey.set(song.key, song);
      this.byUrl.set(song.url, song);
    }
  }

  // ---------------------------------------------------------- 落盘

  private load(): void {
    const text: string | null = this.readText(`${this.dir}/${INDEX_FILE}`);
    if (text !== null) {
      try {
        const raw = JSON.parse(text) as WebDavIndex;
        this.root = typeof raw.root === 'string' ? raw.root : '';
        this.scannedAt = typeof raw.scannedAt === 'number' ? raw.scannedAt : 0;
        this.truncated = raw.truncated === true;
        this.replaceAll(this.sortSongs(normalizeSongs(raw.songs)));
      } catch (e) {
        appendError(`[${TAG}] parse index failed: ${JSON.stringify(e)}`);
      }
    }
    this.sweepOrphans();
  }

  /** 清掉没被任何歌引用的音频缓存文件 */
  private sweepOrphans(): void {
    if (!this.ready) {
      return;
    }
    const known: Set<string> = new Set<string>();
    for (const song of this.songs) {
      if (song.local.length > 0) {
        known.add(song.local);
      }
    }
    try {
      for (const name of fs.listFileSync(this.audioDir)) {
        if (!known.has(name)) {
          unlinkQuietly(`${this.audioDir}/${name}`);
        }
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'sweep dir failed: %{public}s', JSON.stringify(e));
    }
  }

  private persist(): void {
    if (!this.ready) {
      return;
    }
    const index: WebDavIndex = {
      version: INDEX_VERSION,
      root: this.root,
      scannedAt: this.scannedAt,
      truncated: this.truncated,
      songs: this.songs
    };
    writeText(`${this.dir}/${INDEX_FILE}`, JSON.stringify(index));
  }

  private readText(path: string): string | null {
    try {
      if (!fs.accessSync(path)) {
        return null;
      }
      return fs.readTextSync(path);
    } catch (e) {
      appendError(`[${TAG}] readText failed: ${JSON.stringify(e)}`);
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────── 读配置（唯一真源）

/**
 * 云端曲库的配置 = 「WebDAV 备份」那套配置（**没有第二份，也没有环境变量兜底**）
 *
 * 取值链：`WebDavBackupService.readConfig()`
 *   → `MusicStoreService.getInstance().getWebDavConfig()`（preferences `webdav_config`）
 * 口令只在这条链上，不进日志、不进常量。
 */
export function webDavCloudConfig(): WebDavConfig {
  // 返回类型由 `WebDavBackupService.readConfig()` 推出（它就是那条链上的类型），
  // 这里不再另写一份同名字段表 —— 少一份就少一处会发散的东西。
  const backup = WebDavBackupService.readConfig();
  const config: WebDavConfig = {
    url: typeof backup.url === 'string' ? backup.url.trim() : '',
    user: typeof backup.user === 'string' ? backup.user : '',
    password: typeof backup.password === 'string' ? backup.password : ''
  };
  return config;
}

/** 是否已经填过服务器地址（界面据此决定空态文案与「去配置」入口） */
export function webDavCloudConfigured(): boolean {
  return webDavCloudConfig().url.length > 0;
}

// ─────────────────────────────────────────────────────────── 纯工具

/**
 * 由 URL 派生稳定 key
 *
 * 关键性质是**同一个 URL 永远得到同一个 key**：它是本地缓存的文件名前缀、
 * 入队条目的 songId、列表的 LazyForEach key。
 *
 * 用两个 FNV-1a（不同种子）拼起来，凑到 64 位量级 —— 单个 32 位哈希在几千首规模上
 * 撞车概率已经不能忽略，而 key 撞车意味着两首歌互相认错（缓存串味），属于
 * 「不报错但很怪」的故障。真撞了还有 freeKey 兜底加后缀。
 */
export function stableKeyOf(url: string): string {
  return `${shortHash(url)}${shortHash(`\u0001${url}`)}`;
}

/** FNV-1a 32 位，输出 base36（够短、够稳，只用来当文件名 / key 的一半） */
export function shortHash(text: string): string {
  let hash: number = 0x811c9dc5;
  for (let i: number = 0; i < text.length; i++) {
    hash = hash ^ text.charCodeAt(i);
    // 用 Math.imul 做 32 位乘法：直接乘会超出 2^53 丢精度
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(36);
}

/** 稳定 key -> 数字 id（`SongItem.id` 是 number） */
function hashNumber(key: string): number {
  let hash: number = 0x811c9dc5;
  for (let i: number = 0; i < key.length; i++) {
    hash = hash ^ key.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  // 抹掉符号位，避免负数 id（工程里 id 一律当正数用）
  return hash & 0x7fffffff;
}

/** 扫描结果按 URL 排（保证 key 冲突时的后缀是确定的，两次扫出来一样） */
function sortEntriesByUrl(entries: WebDavEntry[]): WebDavEntry[] {
  const out: WebDavEntry[] = entries.slice();
  out.sort((a: WebDavEntry, b: WebDavEntry): number => {
    if (a.url < b.url) {
      return -1;
    }
    return a.url > b.url ? 1 : 0;
  });
  return out;
}

/** 目录 URL -> 目录显示名（`/dav/music/周杰伦/` -> `周杰伦`） */
export function folderNameOf(folderUrl: string): string {
  const trimmed: string = folderUrl.endsWith('/') ? folderUrl.substring(0, folderUrl.length - 1) : folderUrl;
  const at: number = trimmed.lastIndexOf('/');
  const raw: string = at >= 0 ? trimmed.substring(at + 1) : trimmed;
  try {
    return decodeURIComponent(raw);
  } catch (e) {
    return raw;
  }
}

/** 文件名里不能出现的字符换成 `_`（缓存文件名不能带 `/` `\` 之类） */
function sanitize(name: string): string {
  let out: string = '';
  for (let i: number = 0; i < name.length; i++) {
    const ch: string = name.charAt(i);
    out += ('/\\:*?"<>|\u0000'.includes(ch) ? '_' : ch);
  }
  return out.length > 0 ? out : 'audio';
}

/** 毫秒 -> `mm:ss`（`SongItem.interval` 的口径，与在线歌曲一致） */
export function formatDuration(ms: number): string {
  if (ms <= 0) {
    return '';
  }
  const total: number = Math.floor(ms / 1000);
  const minutes: number = Math.floor(total / 60);
  const seconds: number = total % 60;
  return `${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
}

/** 字节 -> 人话（列表行右侧与「缓存占用」用） */
export function formatBytes(bytes: number): string {
  if (bytes <= 0) {
    return '';
  }
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  const kb: number = bytes / 1024;
  if (kb < 1024) {
    return `${Math.round(kb)} KB`;
  }
  const mb: number = kb / 1024;
  if (mb < 1024) {
    return `${mb.toFixed(1)} MB`;
  }
  return `${(mb / 1024).toFixed(2)} GB`;
}

/** 「刚刚 / 5 分钟前 / 3 小时前 / 2 天前」 */
export function describeAgo(at: number): string {
  if (at <= 0) {
    return '还没扫过';
  }
  const diff: number = Date.now() - at;
  if (diff < 60 * 1000) {
    return '刚刚';
  }
  const minutes: number = Math.floor(diff / (60 * 1000));
  if (minutes < 60) {
    return `${minutes} 分钟前`;
  }
  const hours: number = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours} 小时前`;
  }
  return `${Math.floor(hours / 24)} 天前`;
}

/** 扫描结果的一句话说明（如实报「只扫了一部分」/「格式不支持」/「目录读不到」） */
export function describeScan(result: WebDavScanResult): string {
  if (result.total === 0 && result.unsupported === 0) {
    return result.failedFolders > 0
      ? `有 ${result.failedFolders} 个目录读不到，没有找到可播放的音频`
      : '这个目录里没有找到音频文件';
  }
  const parts: string[] = [`共 ${result.total} 首`];
  if (result.added > 0) {
    parts.push(`新增 ${result.added} 首`);
  }
  if (result.dropped > 0) {
    parts.push(`移除 ${result.dropped} 首`);
  }
  if (result.unsupported > 0) {
    parts.push(`${result.unsupported} 首格式不支持`);
  }
  if (result.truncated) {
    parts.push('目录太多，只扫了一部分');
  }
  if (result.failedFolders > 0) {
    parts.push(`${result.failedFolders} 个目录读不到`);
  }
  return parts.join('，');
}

// ─────────────────────────────────────────────────────────── 文件 / 网络小工具

/** 状态码不是 2xx 就抛一句能看懂的话（WebDAV 的失败码挺集中，翻译成人话更有用） */
function assertOk(response: http.HttpResponse, config: WebDavConfig): void {
  // 207 Multi-Status 落在 2xx 里，PROPFIND 的成功码就是它
  const code: number = response.responseCode;
  if (code >= 200 && code < 300) {
    return;
  }
  if (code === 401) {
    const scheme: string = headerValue(response.header, 'www-authenticate').toLowerCase();
    if (scheme.includes('digest')) {
      throw new Error('服务器只支持 Digest 认证，本应用目前只支持 HTTP Basic'
        + '（Nextcloud / Alist / 群晖一般都能用 Basic）');
    }
    throw new Error(config.user.length === 0
      ? '服务器要求登录：请在「设置 → 同步 → WebDAV 备份」填用户名和密码'
      : '用户名或密码不对（同「设置 → 同步 → WebDAV 备份」里那一套）');
  }
  if (code === 403) {
    throw new Error('这个账号没有读取该目录的权限');
  }
  if (code === 404) {
    throw new Error('服务器上说这个地址不存在，检查一下路径（注意大小写）');
  }
  if (code === 405 || code === 501) {
    throw new Error(`服务器不支持 WebDAV 的 PROPFIND（HTTP ${code}），确认地址指向的是 WebDAV 服务`);
  }
  if (code >= 500) {
    throw new Error(`服务器出错（HTTP ${code}）`);
  }
  throw new Error(`服务器返回了 HTTP ${code}`);
}

/** 不区分大小写地取一个响应头 */
function headerValue(header: Object | undefined, name: string): string {
  if (header === undefined || header === null) {
    return '';
  }
  const record = header as Record<string, Object>;
  const wanted: string = name.toLowerCase();
  for (const key of Object.keys(record)) {
    if (key.toLowerCase() === wanted) {
      const value = record[key];
      return typeof value === 'string' ? value : '';
    }
  }
  return '';
}

/**
 * 给一个 promise 加超时
 *
 * `AVMetadataExtractor.fetchMetadata()` 在网络源上没有超时参数，服务器半死不活时
 * 会一直挂着 —— 补标签时不能让它挂住整条队列。超时返回 null，调用方按「读不到标签」
 * 处理；那个还挂着的 promise 后面自己 reject 也不会变成未处理异常。
 */
function withTimeout<T>(pending: Promise<T>, ms: number): Promise<T | null> {
  return new Promise<T | null>((resolve: (value: T | null) => void) => {
    let settled: boolean = false;
    const timer: number = setTimeout(() => {
      if (settled) {
        return;
      }
      settled = true;
      resolve(null);
    }, ms);
    pending.then((value: T) => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timer);
      resolve(value);
    }).catch((err: BusinessError) => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timer);
      hilog.info(DOMAIN, TAG, 'metadata pending rejected: %{public}s', err.message);
      resolve(null);
    });
  });
}

function asText(value: string | undefined): string {
  return typeof value === 'string' ? value : '';
}

function asNumber(value: string | undefined): number {
  if (typeof value !== 'string') {
    return 0;
  }
  const parsed: number = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? 0 : parsed;
}

/** 落盘 JSON 的规范化：旧数据/半截数据一律按默认值兜底（**不抛异常**） */
function normalizeSongs(input: WebDavSong[] | undefined): WebDavSong[] {
  if (!Array.isArray(input)) {
    return [];
  }
  const out: WebDavSong[] = [];
  for (const item of input) {
    if (item === null || item === undefined) {
      continue;
    }
    if (typeof item.url !== 'string' || item.url.length === 0) {
      continue;
    }
    // key 缺失 / 空白的旧数据：按 URL 重算一个
    const key: string = typeof item.key === 'string' && item.key.length > 0
      ? item.key : stableKeyOf(item.url);
    out.push({
      key: key,
      url: item.url,
      folder: typeof item.folder === 'string' ? item.folder : '',
      file: typeof item.file === 'string' ? item.file : item.url,
      name: typeof item.name === 'string' ? item.name : '',
      singer: typeof item.singer === 'string' ? item.singer : '',
      album: typeof item.album === 'string' ? item.album : '',
      durationMs: typeof item.durationMs === 'number' ? item.durationMs : 0,
      sizeBytes: typeof item.sizeBytes === 'number' ? item.sizeBytes : -1,
      seenAt: typeof item.seenAt === 'number' ? item.seenAt : 0,
      // 没扫过就当作「还没见过」：列表先空着，等一次扫描把它点亮
      seen: item.seen === true,
      tagsDone: item.tagsDone === true,
      local: typeof item.local === 'string' ? item.local : '',
      localBytes: typeof item.localBytes === 'number' ? item.localBytes : 0
    });
  }
  return out;
}

function writeText(path: string, text: string): void {
  try {
    const handle: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(handle.fd, text);
    } finally {
      fs.closeSync(handle);
    }
  } catch (e) {
    appendError(`[${TAG}] write text failed: ${JSON.stringify(e)}`);
  }
}

function unlinkQuietly(path: string): void {
  try {
    if (fs.accessSync(path)) {
      fs.unlinkSync(path);
    }
  } catch (e) {
    // 文件不在了就当删好了
  }
}
