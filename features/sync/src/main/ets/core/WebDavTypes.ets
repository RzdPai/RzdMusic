/*
 * WebDAV 云端曲库的类型与常量（照搬参考工程 lxmusic-harmony 的 core/webdav/WebDavTypes.ets）
 *
 * 与参考的差异：
 *  - 参考用 `WEBDAV_SOURCE = 'webdav'` 当曲库标记、靠它做「侧表 / 云缓存」；我们这条链路
 *    只做**浏览 + 播放**（不做歌单侧表、不做歌词匹配），播放走的是「下载到沙箱 + 按本地歌播」
 *    那条既有直路（原因见 WebDavLibrary 文件头），所以这里只保留协议层需要的类型。
 *  - 这一层**刻意不 import 任何东西**（连 musicbasic 都不引），这样协议解析、曲库、界面
 *    都能安全地引它而不会绕出循环依赖。
 */

/**
 * 云端歌播放入队时用的 `SongItem.source`
 *
 * ★ **必须与 `features/player` 的 `MediaService.LOCAL_SOURCE` 逐字相同（`'local'`）**，
 * 这是 AppStorage 之外的隐式契约：`MediaService.loadAsset` 只在 `source === 'local'`
 * 时走「沙箱文件直路」（自己开 fd → `avPlayer.fdSrc`，完全不碰音源脚本）。
 *
 * 为什么云端歌要挂到这条路上（而不是把 WebDAV 直链塞进 `SongItem.url`）：
 *   - 播放器只设 `avPlayer.url`（`SongItemBuilder.build`：`songItem.url.startsWith('http')`），
 *     **没有任何地方能塞请求头**，而 WebDAV 需要 `Authorization: Basic …`；
 *   - `features/player` 不在本次允许改动的文件面内（本模块不能改播放器）。
 * 所以取「先下到应用沙箱缓存，再按本地文件播」这条取舍，详见 WebDavLibrary.download。
 */
export const WEBDAV_PLAY_SOURCE: string = 'local';

/** WebDAV 的一条连接配置（与 `WebDavBackupService.WebDavConfig` 的字段一一对应） */
export interface WebDavConfig {
  /**
   * 服务器上的一个**目录**地址（可以是服务器根，也可以直接指到音乐目录，
   * 例如 `https://dav.example.com/remote.php/dav/files/me/Music`），末尾斜杠可有可无。
   */
  url: string;
  /** HTTP Basic 用户名；留空则不带 Authorization 头（Alist 之类默认匿名可读） */
  user: string;
  /** HTTP Basic 口令；**只从 SyncStore / MusicStoreService 的既有配置里读，不许硬编码** */
  password: string;
}

/** 一个 PROPFIND 响应条目（服务器上的一个文件或目录） */
export interface WebDavEntry {
  /**
   * 绝对 URL（服务器返回的 href 已按配置里的 origin 补全、特殊字符已转义）
   *
   * 列目录、下载封面、下载音频都用它，所以它必须是一个能直接请求的完整地址。
   */
  url: string;
  /** 解码后的显示名（路径最后一段） */
  name: string;
  /** 父目录 URL（以 `/` 结尾）；根目录的条目就是配置里那个地址 */
  folder: string;
  /** 是不是目录（resourcetype 里有 collection） */
  isCollection: boolean;
  /** 字节数（-1 = 服务器没给 getcontentlength；目录一般不给） */
  size: number;
  /** 最后修改时间（毫秒；-1 = 没给或解析不了） */
  modifiedMs: number;
}

/** 从远端音频文件里读出来的标签（AVMetadataExtractor 的 setUrlSource 网络源模式） */
export interface WebDavTags {
  title: string;
  artist: string;
  album: string;
  durationMs: number;
}

/** 空标签（读不到时的兜底，不抛错：标签不是播放的必需品） */
export function emptyTags(): WebDavTags {
  return { title: '', artist: '', album: '', durationMs: 0 };
}

/** 递归收集的结果（含「撞到上限提前停」的如实报告） */
export interface WebDavCollectResult {
  /** 找到的音频条目（含「格式不支持」的，由曲库去报数） */
  entries: WebDavEntry[];
  /** 扫过的目录数 */
  folders: number;
  /** 因为超过上限提前停了（界面要说明「只扫了一部分」） */
  truncated: boolean;
  /** 没读成功的目录（权限不够 / 超时），界面提示用 */
  failedFolders: number;
}

/** 空收集结果 */
export function emptyCollectResult(): WebDavCollectResult {
  return { entries: [], folders: 0, truncated: false, failedFolders: 0 };
}

/**
 * 一次扫描的结果（界面据此说明这次扫到了什么）
 *
 * 「如实报告」是照搬参考的一条原则：触到上限、有目录读不到、有格式不支持，
 * 都要报出来，否则看起来就是「莫名少了几首」。
 */
export interface WebDavScanResult {
  /** 扫描后列表里的条数 */
  total: number;
  /** 这次新见到的 */
  added: number;
  /** 这次没见到、被清掉的 */
  dropped: number;
  /** 因为超过上限提前停了 */
  truncated: boolean;
  /** 没读成功的目录数 */
  failedFolders: number;
  /** 扫到但格式不支持（ape/wma 之类），报出来才不会被当成「少了歌」 */
  unsupported: number;
}

/** 空扫描结果 */
export function emptyScanResult(): WebDavScanResult {
  return { total: 0, added: 0, dropped: 0, truncated: false, failedFolders: 0, unsupported: 0 };
}

/**
 * 连接自检结果
 *
 * `ok=false` 时 `message` 必须是一句**能读懂的失败原因**（见 WebDavLibrary.assertOk），
 * 这是「失败态要给出可读错误文案」那条要求的落点。
 */
export interface WebDavProbeResult {
  ok: boolean;
  /** 一句话结论（成功是「连上了：根目录下 N 个文件夹、M 个文件」） */
  message: string;
  /** 根目录下的条目数（失败时为 0） */
  entryCount: number;
}

/**
 * AVPlayer / AVMetadataExtractor 官方支持的音频后缀（小写，含点）
 *
 * 与工程里既有的格式白名单口径一致：`features/player` 的 MediaService 用 AVPlayer，
 * 远端标签用 AVMetadataExtractor；两者支持面基本重合，取交集。
 * 参考工程的 `isSupportedAudioFile` 用的是同一套后缀。
 */
export const SUPPORTED_AUDIO_EXTS: string[] = [
  '.mp3', '.flac', '.m4a', '.aac', '.wav', '.ogg', '.oga', '.amr', '.ape', '.mp4', '.mka'
];

/**
 * 一眼能认出「本来是音频、但放不了」的后缀
 *
 * 报出来（而不是静默跳过）才不会让用户以为「少了歌」：wma / dsf / dff / wv / tak / opus
 * 都是常见的无损/私有格式，AVPlayer 打不开。
 */
export const UNSUPPORTED_AUDIO_EXTS: string[] = [
  '.wma', '.dsf', '.dff', '.wv', '.tak', '.opus', '.aiff', '.aif', '.m4b', '.cue'
];

/** 后缀（小写，含点）；没有后缀返回空串 */
export function extOf(name: string): string {
  const dot: number = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot).toLowerCase();
}

/** 去掉后缀的文件名 */
export function stripExt(name: string): string {
  const dot: number = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/** 这个后缀是不是能播的音频 */
export function isSupportedAudioFile(name: string): boolean {
  return SUPPORTED_AUDIO_EXTS.includes(extOf(name));
}

/** 这个后缀是不是「本来是音频但放不了」（用来报「N 首格式不支持」） */
export function isUnsupportedAudioFile(name: string): boolean {
  return UNSUPPORTED_AUDIO_EXTS.includes(extOf(name));
}

/** 这个文件是不是歌词（`*.lrc`），列目录时要跳过 */
export function isLyricFile(name: string): boolean {
  return extOf(name) === '.lrc';
}

/** 这个文件是不是图片（封面），列目录时要跳过 */
export function isImageFile(name: string): boolean {
  return ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif'].includes(extOf(name));
}

/**
 * 文件名按 `<歌手> - <歌名>` 惯例拆
 *
 * 音乐库落盘基本都这么命名（参考工程用的同一口径），远端标签读不到时至少名字是对的。
 * 拆不出来就整体当歌名（歌名里带 `-` 的比歌手名带 `-` 的常见得多，所以只切**第一处**）。
 */
export function parseTrackName(fileName: string): WebDavTags {
  const base: string = stripExt(fileName).trim();
  const at: number = base.indexOf(' - ');
  if (at <= 0 || at >= base.length - 3) {
    return { title: base, artist: '', album: '', durationMs: 0 };
  }
  return {
    title: base.substring(at + 3).trim(),
    artist: base.substring(0, at).trim(),
    album: '',
    durationMs: 0
  };
}
