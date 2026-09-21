/**
 * 对应 listen 的 entry/src/main/ets/core/sync/SyncStore.ets
 *
 * 适配改动：
 *   - 目录来源：listen 的 init(context) 必须传 context；RzdMusic 里 context 参数变成可选，
 *     不传时用 `getAppRuntime().context.filesDir` 自己拼（仍然落在 `filesDir/lx_sync/`，
 *     与 listen 的文件布局完全一致：config.json / keys.json / list.json / dislike.json）。
 *   - 日志：listen 的 hilog 换成 musicbasic 的 appendError。
 *   - 落盘写法对齐 RzdMusic 既有的 `MusicStoreService.getActiveSource()/setActiveSource()`
 *     （直接用 @kit.CoreFileKit 的 fileIo 操作 filesDir 下的文件）。
 *   - 新增一项 `playlist_meta.json`（loadPlaylistMeta/savePlaylistMeta，透明存取 JSON 原文）：
 *     LocalLibrary 适配 MusicStoreService 后，需要单独记住「本机歌单 id -> 洛雪列表元数据」
 *     （lx id / source / sourceListId / locationUpdateTime），listen 不需要这个文件。
 *   - 其余（配置项、按 serverId 存密钥、列表数据的规范化、不喜欢规则）与 listen 一致。
 *
 * 同步相关的本地存储
 *
 * 对应洛雪 utils/data.ts 里 syncHost / syncAuthKey 那几项，外加音乐库本身。
 * HarmonyOS 的 preferences 不适合存可能很大的列表数据，因此统一落到应用沙箱文件。
 * 列表数据按洛雪的线上格式保存，这样：
 *   1) 重连时计算 md5 的 JSON 与收到的报文同构，能与服务端的快照 key 对上；
 *   2) 文件本身就是「同步数据」的可读副本，排查问题直接看它即可。
 */

import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { appendError, getAppRuntime } from 'musicbasic';
import { LxListData, LxMusicInfoNew, LxUserListInfoFull, SyncKeyInfo } from './SyncTypes';

const TAG: string = 'SyncStore';

const STORE_DIR: string = 'lx_sync';
const CONFIG_FILE: string = 'config.json';
const KEYS_FILE: string = 'keys.json';
const LIST_FILE: string = 'list.json';
const DISLIKE_FILE: string = 'dislike.json';
/** 歌单协议元数据（RzdMusic 新增，见 loadPlaylistMeta 的说明） */
const PLAYLIST_META_FILE: string = 'playlist_meta.json';

/** 同步开关 / 服务器地址 / 设备名 */
export interface SyncConfig {
  enable: boolean;
  host: string;
  deviceName: string;
  hostHistory: string[];
}

/** dislike.json 的文件形态 */
interface DislikeFile {
  rules: string;
}

function defaultConfig(): SyncConfig {
  return { enable: false, host: '', deviceName: '', hostHistory: [] };
}

export function defaultListData(): LxListData {
  return { defaultList: [], loveList: [], userList: [] };
}

export class SyncStore {
  private dir: string = '';
  private ready: boolean = false;

  /**
   * 初始化存储目录。
   * @param context 可选的 context；不传时取 getAppRuntime().context（沙箱 filesDir）
   */
  init(context?: common.Context): void {
    const ctx: common.Context | undefined = context !== undefined ? context : getAppRuntime().context;
    if (ctx === undefined) {
      appendError(`[${TAG}] init failed: no ability context`);
      this.ready = false;
      return;
    }
    this.dir = `${ctx.filesDir}/${STORE_DIR}`;
    try {
      if (!fs.accessSync(this.dir)) {
        fs.mkdirSync(this.dir);
      }
      this.ready = true;
    } catch (e) {
      appendError(`[${TAG}] create store dir failed: ${JSON.stringify(e)}`);
      this.ready = false;
    }
  }

  isReady(): boolean {
    return this.ready;
  }

  private path(file: string): string {
    return `${this.dir}/${file}`;
  }

  private readText(file: string): string | null {
    if (!this.ready) {
      return null;
    }
    try {
      const target: string = this.path(file);
      if (!fs.accessSync(target)) {
        return null;
      }
      return fs.readTextSync(target);
    } catch (e) {
      appendError(`[${TAG}] read ${file} failed: ${JSON.stringify(e)}`);
      return null;
    }
  }

  private writeText(file: string, text: string): void {
    if (!this.ready) {
      throw new Error('同步存储未初始化');
    }
    const target: string = this.path(file);
    const handle: fs.File = fs.openSync(target, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(handle.fd, text);
    } finally {
      fs.closeSync(handle);
    }
  }

  // ------------------------------------------------------------ 配置

  loadConfig(): SyncConfig {
    const text: string | null = this.readText(CONFIG_FILE);
    const config: SyncConfig = defaultConfig();
    if (text === null) {
      config.deviceName = defaultDeviceName();
      return config;
    }
    try {
      const raw: SyncConfig = JSON.parse(text) as SyncConfig;
      config.enable = raw.enable === true;
      config.host = typeof raw.host === 'string' ? raw.host : '';
      config.deviceName = (typeof raw.deviceName === 'string' && raw.deviceName.length > 0)
        ? raw.deviceName : defaultDeviceName();
      config.hostHistory = Array.isArray(raw.hostHistory) ? raw.hostHistory : [];
      return config;
    } catch (e) {
      appendError(`[${TAG}] parse config failed: ${JSON.stringify(e)}`);
      config.deviceName = defaultDeviceName();
      return config;
    }
  }

  saveConfig(config: SyncConfig): void {
    try {
      this.writeText(CONFIG_FILE, JSON.stringify(config));
    } catch (e) {
      appendError(`[${TAG}] save config failed: ${JSON.stringify(e)}`);
    }
  }

  // ------------------------------------------------------------ 身份密钥（按 serverId 存）

  loadKey(serverId: string): SyncKeyInfo | null {
    const text: string | null = this.readText(KEYS_FILE);
    if (text === null) {
      return null;
    }
    try {
      const keys: Record<string, SyncKeyInfo> = JSON.parse(text) as Record<string, SyncKeyInfo>;
      const info: SyncKeyInfo | undefined = keys[serverId];
      return info === undefined ? null : info;
    } catch (e) {
      appendError(`[${TAG}] parse keys failed: ${JSON.stringify(e)}`);
      return null;
    }
  }

  saveKey(serverId: string, info: SyncKeyInfo): void {
    let keys: Record<string, SyncKeyInfo> = {};
    const text: string | null = this.readText(KEYS_FILE);
    if (text !== null) {
      try {
        keys = JSON.parse(text) as Record<string, SyncKeyInfo>;
      } catch (e) {
        keys = {};
      }
    }
    keys[serverId] = info;
    try {
      this.writeText(KEYS_FILE, JSON.stringify(keys));
    } catch (e) {
      appendError(`[${TAG}] save keys failed: ${JSON.stringify(e)}`);
    }
  }

  // ------------------------------------------------------------ 音乐库（洛雪线上格式）

  /** 是否已经落过一份音乐库：用来区分「首次安装（界面上的演示数据先留着）」 */
  hasListData(): boolean {
    if (!this.ready) {
      return false;
    }
    try {
      return fs.accessSync(this.path(LIST_FILE));
    } catch (e) {
      return false;
    }
  }

  loadListData(): LxListData {
    const data: LxListData = defaultListData();
    const text: string | null = this.readText(LIST_FILE);
    if (text === null) {
      return data;
    }
    try {
      const raw: LxListData = JSON.parse(text) as LxListData;
      data.defaultList = normalizeMusics(raw.defaultList);
      data.loveList = normalizeMusics(raw.loveList);
      data.userList = normalizeUserList(raw.userList);
      return data;
    } catch (e) {
      appendError(`[${TAG}] parse list data failed: ${JSON.stringify(e)}`);
      return data;
    }
  }

  saveListData(data: LxListData): void {
    try {
      this.writeText(LIST_FILE, JSON.stringify(data));
    } catch (e) {
      appendError(`[${TAG}] save list data failed: ${JSON.stringify(e)}`);
    }
  }

  // ------------------------------------------------------------ 不喜欢规则

  loadDislikeRules(): string {
    const text: string | null = this.readText(DISLIKE_FILE);
    if (text === null) {
      return '';
    }
    try {
      const raw: DislikeFile = JSON.parse(text) as DislikeFile;
      return typeof raw.rules === 'string' ? raw.rules : '';
    } catch (e) {
      return '';
    }
  }

  saveDislikeRules(rules: string): void {
    const payload: DislikeFile = { rules: rules };
    try {
      this.writeText(DISLIKE_FILE, JSON.stringify(payload));
    } catch (e) {
      appendError(`[${TAG}] save dislike rules failed: ${JSON.stringify(e)}`);
    }
  }

  // ------------------------------------------------------------ 歌单协议元数据

  /**
   * 「本机歌单 id -> 洛雪列表元数据」的 JSON 原文（形态由 LocalLibrary 定义）
   *
   * 这是相对 listen **新增**的一项落盘（listen 没有这个文件）：RzdMusic 的歌单真实数据在
   * MusicStoreService（PlaylistDto 只有 id/name/createTime/songs），存不下洛雪列表的
   * lx id / source / sourceListId / locationUpdateTime，而这几项都参与「列表 JSON 的 md5」
   * （服务端快照 key），必须原样保留。另外 MusicStoreService 的歌单 id 是 Date.now()，
   * 没法指定，远端歌单的 lx id 也只能靠这份映射记住。
   *
   * 返回空串 = 还没写过（首次同步）。这里只做透明存取，不解析内容。
   */
  loadPlaylistMeta(): string {
    const text: string | null = this.readText(PLAYLIST_META_FILE);
    return text === null ? '' : text;
  }

  savePlaylistMeta(json: string): void {
    try {
      this.writeText(PLAYLIST_META_FILE, json);
    } catch (e) {
      appendError(`[${TAG}] save playlist meta failed: ${JSON.stringify(e)}`);
    }
  }
}

/** 设备名：优先市场名，其次产品型号，最后落一个可读兜底 */
export function defaultDeviceName(): string {
  try {
    const market: string = deviceInfo.marketName;
    if (market !== undefined && market.length > 0) {
      return market;
    }
    const model: string = deviceInfo.productModel;
    if (model !== undefined && model.length > 0) {
      return model;
    }
    const brand: string = deviceInfo.brand;
    if (brand !== undefined && brand.length > 0) {
      return `${brand} HarmonyOS`;
    }
  } catch (e) {
    // 某些设备上 deviceInfo 取不到，走兜底
  }
  return 'HarmonyOS';
}

function normalizeMusics(input: LxMusicInfoNew[] | undefined): LxMusicInfoNew[] {
  if (!Array.isArray(input)) {
    return [];
  }
  const out: LxMusicInfoNew[] = [];
  for (const item of input) {
    if (item !== null && item !== undefined && typeof item.id === 'string' && item.id.length > 0) {
      out.push(item);
    }
  }
  return out;
}

function normalizeUserList(input: LxUserListInfoFull[] | undefined): LxUserListInfoFull[] {
  if (!Array.isArray(input)) {
    return [];
  }
  const out: LxUserListInfoFull[] = [];
  for (const item of input) {
    if (item === null || item === undefined || typeof item.id !== 'string' || item.id.length === 0) {
      continue;
    }
    const list: LxUserListInfoFull = {
      id: item.id,
      name: typeof item.name === 'string' ? item.name : item.id,
      locationUpdateTime: typeof item.locationUpdateTime === 'number' ? item.locationUpdateTime : null,
      list: normalizeMusics(item.list),
    };
    if (typeof item.source === 'string') {
      list.source = item.source;
    }
    if (typeof item.sourceListId === 'string') {
      list.sourceListId = item.sourceListId;
    }
    out.push(list);
  }
  return out;
}
