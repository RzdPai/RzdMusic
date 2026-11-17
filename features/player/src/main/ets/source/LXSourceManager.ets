import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {AppStorageKeys,  MusicStoreService, appendPlayLog } from 'musicbasic';
import { LXUserApiInfo, LXUserApiInfoFull, LXUserApiSourceInfo, MfSubscriptionInfo } from './Interface';

import { normalizePlatformId, platformIdFromLabel } from '../util/SourceDeclaredInfo';
import { scanMfCaps } from '../util/MfCapability';

import { Logger } from 'musicbasic';
const DOMAIN: number = 0x0000;
/** 插件 manifest 里不是「音源名」的 platform 取值（客户端类型）。 */
const MF_NON_PLATFORM_VALUES: string[] = ['pc', 'web', 'h5', 'mobile', 'android', 'ios'];
const TAG: string = 'RzdLxSource';

const LX_API_LIST_FILE: string = 'lx_api_list.json';
const LX_API_SCRIPT_PREFIX: string = 'lx_api_script_';
const MF_SUB_FILE: string = 'mf_subscriptions.json';

interface MfSubStore {
  subs: MfSubscriptionInfo[];
}

interface LXApiListStore {
  apis: LXUserApiInfo[];
}

/**
 * 导入结果。
 *
 * 为什么要带 ok/message：`importApi` 以前是 void —— 「用派音打开 .js」导完只说
 * 「已导入」，哪怕因为存储目录没初始化**一个字都没落盘**也照样报成功。现在失败能
 * 如实提示，而不是骗用户。
 */
export interface LXApiImportResult {
  ok: boolean;
  /** 成功时是音源名，失败时是原因。 */
  message: string;
  /** 成功时的音源；失败为 null。 */
  info: LXUserApiInfo | null;
}

/**
 * 跨设备搬运一个音源所需的全部内容（同步下载侧使用）。
 *
 * id 必须是**远端那一份**，不能重新生成：脚本文件名就是 `lx_api_script_<id>.js`，
 * 两台设备用同一个 id 才谈得上"同一份音源"，也才谈得上冲突比对新旧。
 */
export interface LXApiSeed {
  id: string;
  /** 脚本原文（同步载荷里一律用解压后的明文）。 */
  script: string;
  name?: string;
  description?: string;
  author?: string;
  homepage?: string;
  version?: string;
  allowShowUpdateAlert?: boolean;
  /** `lx` / `mf`；缺省按 `lx` 处理（旧同步载荷没有这个字段）。 */
  kind?: string;
  /** MusicFree 插件的 `platform` 名。 */
  platform?: string;
}

/** 按给定 id 落盘的结果；outcome 三态比 ok 布尔量更好排障 */
export interface LXApiUpsertResult {
  /** 'added' = 新落盘；'exists' = 本机已有同 id（未改动）；'failed' = 失败 */
  outcome: string;
  message: string;
}

/** 音源 id 的合法字符集：它会被拼进脚本文件名，必须挡住路径穿越一类的注入 */
const API_ID_PATTERN: RegExp = /^[A-Za-z0-9_-]{1,64}$/;

class LXSourceManager {
  private apiList: LXUserApiInfo[] | null = null;
  private filesDir: string = '';

  setFilesDir(dir: string): void {
    this.filesDir = dir;
  }

  /**
   * 用 Ability 上下文初始化存储目录。**必须在任何 import/读取之前调用**。
   *
   * 为什么要显式初始化：`filesDir` 原来只由 `LXSourceHost.aboutToAppear()` 赋值，
   * 而「用派音打开 .js」是在 `onCreate` 里导入的 —— 那时 UI 还没起来、filesDir 还是
   * 空串，脚本和列表就被写到 `"/lx_api_list.json"` 这种无效路径上（静默失败）。
   * 结果就是用户看到的：**音源管理里只剩刚导入的那个，重启后连它也没了**
   * （重启后从真正的 `filesDir/lx_api_list.json` 读到了老列表）。
   *
   * @param context UIAbility 上下文（`this.context`）。
   */
  init(context: common.Context): void {
    if (context !== undefined && context.filesDir.length > 0) {
      this.setFilesDir(context.filesDir);
      hilog.info(DOMAIN, TAG, 'filesDir ready: %{public}s', context.filesDir);
    }
  }

  /** 存储目录是否就绪（未就绪时读写一律不做，也不缓存空列表）。 */
  ready(): boolean {
    return this.filesDir.length > 0;
  }

  private getListFilePath(): string {
    return this.filesDir + '/' + LX_API_LIST_FILE;
  }

  private getScriptFilePath(apiId: string): string {
    return this.filesDir + '/' + LX_API_SCRIPT_PREFIX + apiId + '.js';
  }

  /**
   * 音源列表。
   *
   * 返回的是**副本**：以前直接返回内部数组，调用方 push/splice 会绕过
   * `saveApiListToFile()`，改动只在内存里、重启就丢。
   */
  getApiList(): LXUserApiInfo[] {
    if (this.apiList !== null) {
      return this.apiList.slice();
    }
    // filesDir 未初始化时读出来必然是空，而这里会把空结果永久缓存下来
    // （setFilesDir 全仓库只有 LXSourceHost 一处调用，早于它读取的消费者会看到
    // 「暂无导入的音源」并且再也恢复不了）。所以这种情况下不缓存。
    if (this.filesDir.length === 0) {
      hilog.warn(DOMAIN, TAG, 'filesDir not ready, skip read');
      return [];
    }
    this.apiList = this.loadApiListFromFile();
    return this.apiList.slice();
  }

  /**
   * 把 init 事件上报的 sources 回写到音源列表，供换源时按平台择优。
   * 历史实现从不回写，导致 lxEngineSources 一直是 {}，换源候选排序退化成
   * 「按导入顺序硬试」，更早触发「已尝试全部可用音源」。
   * @param apiId 音源 id。
   * @param sources 脚本上报的 sources（平台 -> 支持的动作/音质）。
   */
  saveApiSources(apiId: string, sources: Record<string, LXUserApiSourceInfo>): void {
    if (apiId.length === 0) {
      return;
    }
    // ★ 2026-10-29：以前 `filesDir` 还没设好就直接 return，导致 init 上报的 sources 被**静默丢弃**
    //   （引擎很快就绪、filesDir 稍后才注入的时序）。现在无论如何先更新内存列表，
    //   落盘由 saveApiListToFile() 自己判断 filesDir 是否可用。
    if (this.filesDir.length === 0) {
      hilog.warn(DOMAIN, TAG, 'saveApiSources: filesDir not ready, memory only');
    }
    const list: LXUserApiInfo[] = this.getApiList();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === apiId) {
        list[i].sources = sources;
        this.apiList = list;
        this.saveApiListToFile();
        return;
      }
    }
  }

  private loadApiListFromFile(): LXUserApiInfo[] {
    let path: string = this.getListFilePath();
    try {
      if (!fs.accessSync(path)) {
        return [];
      }
      let stat: fs.Stat = fs.statSync(path);
      let buf: ArrayBuffer = new ArrayBuffer(stat.size);
      let file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      fs.readSync(file.fd, buf, { offset: 0, length: stat.size });
      fs.closeSync(file);
      let decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      let text: string = decoder.decodeToString(new Uint8Array(buf));
      let store: LXApiListStore = JSON.parse(text) as LXApiListStore;
      if (store.apis !== undefined) {
        // 旧数据没有 kind / platform：补默认值，避免下游到处判 undefined
        for (let i: number = 0; i < store.apis.length; i++) {
          const item: LXUserApiInfo = store.apis[i];
          if (item.kind === undefined || item.kind === null || item.kind.length === 0) {
            item.kind = 'lx';
          }
          if (item.platform === undefined || item.platform === null) {
            item.platform = '';
          }
          if (item.subId === undefined || item.subId === null) {
            item.subId = '';
          }
          // ★ 2026-11-09（用户：「MusicFree 原版名称和我们现在显示的不一样」）：
          //   老数据的名字是订阅项里的「网易 / qq」，原版显示的是插件自报的 platform
          //   （「元力WY」）。读盘时就地按脚本 manifest 校正，不必让用户重导一遍订阅。
          //   只改内存、不在这里落盘：下次任何一次保存会把这批字段一起写回去。
          if (item.kind === 'mf' && item.id.length > 0) {
            const script: string = this.readScriptSync(item.id);
            if (script.length > 0) {
              const manifestPlatform: string = this.parseMusicFreePlatform(script);
              if (manifestPlatform.length > 0) {
                item.platform = manifestPlatform;
              } else if (this.isBrandNamePolluted(item.platform, this.musicFreeBrandName(script))) {
                // 旧版把 `@name`（「元力音源」）当平台名写进了 platform，同一订阅里
                // 6 个插件全一样。清空后由异步探测回填插件真正的 platform。
                item.platform = '';
              }
              if (item.version === undefined || item.version.length === 0) {
                item.version = this.parseMusicFreeVersion(script);
              }
              if (item.author === undefined || item.author.length === 0) {
                item.author = this.parseMusicFreeAuthor(script);
              }
              if (item.description === undefined || item.description.length === 0) {
                item.description = this.parseMusicFreeDescription(script);
              }
              // 能力标记：老数据没有，就地补（只写内存，下次保存一并落盘）。
              // 只在扫描出结果时覆盖 —— `gz_` 压缩脚本读不到原文，不能把已知能力清空。
              const caps: string[] = scanMfCaps(script);
              if (caps.length > 0) {
                item.caps = caps;
              }
            }
          }
        }
        return store.apis;
      }
      return [];
    } catch (_err) {
      return [];
    }
  }

  private saveApiListToFile(): void {
    let path: string = this.getListFilePath();
    let list: LXUserApiInfo[] = this.apiList !== null ? this.apiList : [];
    let store: LXApiListStore = { apis: list };
    let text: string = JSON.stringify(store) || '';
    let encoder: util.TextEncoder = new util.TextEncoder();
    let data: Uint8Array = encoder.encodeInto(text);
    try {
      let file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, data.buffer as ArrayBuffer);
      fs.closeSync(file);
      hilog.info(DOMAIN, TAG, 'api list saved: %{public}s count=%{public}d', path, list.length);
    } catch (err) {
      const e: Error = err as Error;
      hilog.error(DOMAIN, TAG, 'saveApiListToFile FAILED path=%{public}s : %{public}s', path, e.message ?? '');
    }
  }

  /**
   * 同步读脚本原文（只给「导入去重」用；gz_ 压缩格式返回空串表示"无法比较"）。
   * @param apiId 音源 id
   * @returns 脚本原文或空串
   */
  private readScriptSync(apiId: string): string {
    try {
      const p: string = this.getScriptFilePath(apiId);
      if (!fs.accessSync(p)) {
        return '';
      }
      const st: fs.Stat = fs.statSync(p);
      const buf: ArrayBuffer = new ArrayBuffer(st.size);
      const file: fs.File = fs.openSync(p, fs.OpenMode.READ_ONLY);
      fs.readSync(file.fd, buf, { offset: 0, length: st.size });
      fs.closeSync(file);
      const raw: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
      return raw.startsWith('gz_') ? '' : raw;
    } catch (e) {
      return '';
    }
  }

  async getScript(apiId: string): Promise<string> {
    let scriptPath: string = this.getScriptFilePath(apiId);
    try {
      if (!fs.accessSync(scriptPath)) {
        return '';
      }
      let stat: fs.Stat = fs.statSync(scriptPath);
      let buf: ArrayBuffer = new ArrayBuffer(stat.size);
      let file: fs.File = fs.openSync(scriptPath, fs.OpenMode.READ_ONLY);
      fs.readSync(file.fd, buf, { offset: 0, length: stat.size });
      fs.closeSync(file);
      let decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      let raw: string = decoder.decodeToString(new Uint8Array(buf));
      if (raw.startsWith('gz_')) {
        return await this.inflateBase64(raw.substring(3));
      }
      return raw;
    } catch (_err) {
      return '';
    }
  }

  private async inflateBuffer(compressedBuffer: ArrayBuffer): Promise<string> {
    let zipObj: zlib.Zip = zlib.createZipSync();
    try {
      // compressBound() bounds compressed size only; decompressed content can be much larger.
      const outBufSize: number = Math.max(compressedBuffer.byteLength * 8 + 1024, 64 * 1024);
      let outBuf: ArrayBuffer = new ArrayBuffer(outBufSize);
      let result: zlib.ZipOutputInfo = await zipObj.uncompress(outBuf, compressedBuffer, compressedBuffer.byteLength);
      if (result !== undefined && result.destLen > 0) {
        let data: Uint8Array = new Uint8Array(outBuf, 0, result.destLen);
        let decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
        return decoder.decodeToString(data);
      }
      return '';
    }
    catch (_err) {
      return '';
    }
  }

  private async inflateBase64(base64: string): Promise<string> {
    try {
      let compressed: Uint8Array = this.base64ToUint8Array(base64);
      if (compressed.length === 0) {
        return '';
      }
      return await this.inflateBuffer(compressed.buffer as ArrayBuffer);
    } catch (_err) {
      return '';
    }
  }

  private base64ToUint8Array(base64: string): Uint8Array {
    try {
      let clean: string = base64.replace(/-/g, '+').replace(/_/g, '/');
      let remainder: number = clean.length % 4;
      if (remainder > 0) {
        for (let i: number = 0; i < 4 - remainder; i++) {
          clean += '=';
        }
      }
      let bytes: number[] = [];
      let chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
      let i: number = 0;
      while (i < clean.length) {
        let enc1: number = chars.indexOf(clean.charAt(i));
        i++;
        let enc2: number = chars.indexOf(clean.charAt(i));
        i++;
        if (enc1 === -1 || enc2 === -1) {
          break;
        }
        bytes.push((enc1 << 2) | (enc2 >> 4));
        let enc3: number = chars.indexOf(clean.charAt(i));
        i++;
        if (enc3 !== -1) {
          bytes.push(((enc2 & 15) << 4) | (enc3 >> 2));
        } else {
          break;
        }
        let enc4: number = chars.indexOf(clean.charAt(i));
        i++;
        if (enc4 !== -1) {
          bytes.push(((enc3 & 3) << 6) | enc4);
        }
      }
      return new Uint8Array(bytes);
    } catch (_err) {
      return new Uint8Array(0);
    }
  }

  saveScript(apiId: string, script: string): void {
    let scriptPath: string = this.getScriptFilePath(apiId);
    let encoder: util.TextEncoder = new util.TextEncoder();
    let data: Uint8Array = encoder.encodeInto(script);
    try {
      let file: fs.File = fs.openSync(scriptPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, data.buffer as ArrayBuffer);
      fs.closeSync(file);
      hilog.info(DOMAIN, TAG, 'script saved: %{public}s bytes=%{public}d', scriptPath, data.length);
    } catch (err) {
      const e: Error = err as Error;
      // 这里以前是 Logger.error：落盘失败只进控制台，用户和日志都看不到
      hilog.error(DOMAIN, TAG, 'saveScript FAILED path=%{public}s : %{public}s', scriptPath, e.message ?? '');
    }
  }

  /**
   * 导入音源脚本。
   *
   * 成功后注意：脚本与列表都写进 `filesDir`，**重启依然在**；失败会如实返回原因，
   * 不会再出现「提示已导入、实际没落盘、重启就没了」。
   * @param scriptRaw 脚本原文。
   * @returns 导入结果（ok / message / info）。
   */
  importApi(scriptRaw: string): LXApiImportResult {
    if (!this.ready()) {
      hilog.error(DOMAIN, TAG, 'importApi aborted: filesDir not ready');
      return { ok: false, message: '存储目录未就绪，导入失败', info: null };
    }
    let parsed: ApiScriptInfo;
    try {
      parsed = this.parseScriptInfo(scriptRaw);
    } catch (err) {
      const e: Error = err as Error;
      return { ok: false, message: e.message ?? '脚本格式不正确', info: null };
    }
    // ★ 2026-10-30（用户：重复导入/更新会多出第二条音源）：
    //   按 @name 去重 —— 同版本直接跳过；不同版本**原地替换**（保留原 id 与选中状态）。
    {
      const existing: LXUserApiInfo[] = this.getApiList();
      // ★ 2026-11-01（用户：重复识别不该看文件名，应按脚本内容）：
      //   先按**内容**判重（忽略空白差异），同内容一律视为已存在；再回落到 name+version。
      const normalizedNew: string = scriptRaw.replace(/\s+/g, '');
      for (let i: number = 0; i < existing.length; i++) {
        const oldRaw: string = this.readScriptSync(existing[i].id);
        if (oldRaw.length > 0 && oldRaw.replace(/\s+/g, '') === normalizedNew) {
          hilog.info(DOMAIN, TAG, 'import skipped (same content) id=%{public}s', existing[i].id);
          return { ok: true, message: existing[i].name + ' 已存在（内容相同），未重复导入', info: existing[i] };
        }
      }
      for (let i: number = 0; i < existing.length; i++) {
        if (existing[i].name.trim() !== parsed.name.trim()) {
          continue;
        }
        if (existing[i].version.trim() === parsed.version.trim()) {
          hilog.info(DOMAIN, TAG, 'import skipped (same version) id=%{public}s name=%{public}s',
            existing[i].id, parsed.name);
          return { ok: true, message: parsed.name + ' 已存在（v' + parsed.version + '），未重复导入',
            info: existing[i] };
        }
        this.saveScript(existing[i].id, scriptRaw);
        existing[i].version = parsed.version;
        existing[i].author = parsed.author;
        existing[i].description = parsed.description;
        existing[i].homepage = parsed.homepage;
        this.apiList = existing;
        this.saveApiListToFile();
        hilog.info(DOMAIN, TAG, 'import replaced id=%{public}s name=%{public}s ver=%{public}s',
          existing[i].id, parsed.name, parsed.version);
        return { ok: true, message: parsed.name + ' 已更新到 v' + parsed.version, info: existing[i] };
      }
    }
    let apiId: string = 'user_api_' + Math.random().toString().substring(2, 5) + '_' + Date.now().toString();
    let apiInfo: LXUserApiInfo = {
      id: apiId,
      name: parsed.name,
      description: parsed.description,
      allowShowUpdateAlert: true,
      author: parsed.author,
      homepage: parsed.homepage,
      version: parsed.version,
      kind: 'lx',
      platform: '',
      subId: '',
      sources: {}
    };
    // 先落脚本再改列表：任何一步失败都不要往列表里塞半成品
    this.saveScript(apiId, scriptRaw);
    if (!fs.accessSync(this.getScriptFilePath(apiId))) {
      hilog.error(DOMAIN, TAG, 'importApi aborted: script save verify failed id=%{public}s', apiId);
      return { ok: false, message: '脚本写入失败，请重试', info: null };
    }
    // 关键：先把已存在的列表读进内存，再 push —— 否则会把老音源整表覆盖掉
    let list: LXUserApiInfo[] = this.getApiList();
    if (this.apiList === null) {
      hilog.error(DOMAIN, TAG, 'importApi aborted: list not loaded');
      return { ok: false, message: '存储目录未就绪，导入失败', info: null };
    }
    list.push(apiInfo);
    this.apiList = list;
    this.saveApiListToFile();
    this.enableSourceAfterImport(apiInfo.id);
    hilog.info(DOMAIN, TAG, 'imported id=%{public}s name=%{public}s total=%{public}d',
      apiInfo.id, apiInfo.name, list.length);
    return { ok: true, message: apiInfo.name, info: apiInfo };
  }

  /**
   * 新导入的音源默认「启用」。
   *
   * 只在用户**已经配置过**音源勾选时追加；从未配置过时空数组就代表全部启用，
   * 不能再往里写一条（否则会把其它源全关掉）。
   */
  private enableSourceAfterImport(apiId: string): void {
    if (apiId.length === 0) {
      return;
    }
    try {
      const store: MusicStoreService = MusicStoreService.getInstance();
      if (!store.hasSourceScriptOrderConfig()) {
        return;
      }
      const order: string[] = store.getSourceScriptOrder();
      if (order.indexOf(apiId) >= 0) {
        return;
      }
      order.push(apiId);
      store.setSourceScriptOrder(order);
    } catch (_e) {
      // 存储未就绪：刷新时 UI 会按「全部启用」兜底
    }
  }

  /**
   * 导入一个 **MusicFree 插件**。
   *
   * 与 {@link importApi} 的三点差别：
   *  1. MusicFree 插件不保证有 `@version` 头部，但一定有 `platform`（运行时才知道，
   *     由调用方在沙箱里读出来传进来）；
   *  2. 元力系四个插件**名字全都叫「元力音源」**，按 name 去重会互相覆盖 ⇒ 按 `platform` 去重；
   *  3. 落库时打 `kind='mf'`，播放链路据此决定交给哪个引擎。
   *
   * @param script 插件脚本原文
   * @param platform 插件声明的平台名（运行时读到的 `platform`）
   * @param fallbackName 读不到 platform 时的名字（通常取订阅里的 name）
   * @param subId 归属的订阅 id（独立导入传空串）；去重只在**同一订阅内**做，
   *              不同订阅里的同名插件是**两个源 / 两个平台**（用户要的共存）
   */
  importMusicFreePlugin(script: string, platform: string, fallbackName: string,
    subId: string = ''): LXApiImportResult {
    if (!this.ready()) {
      return { ok: false, message: '存储目录未就绪，导入失败', info: null };
    }
    if (script.length === 0) {
      return { ok: false, message: '插件脚本为空', info: null };
    }
    // ★ 2026-11-09（用户：「现在平台全都显示元力音源」）：
    //   `name` = 导入时的来源名（订阅项名「网易」/ 文件名），**不写平台名**。
    //   平台名单独放 `platform`（静态 manifest 或运行时探测），显示时 platform 优先。
    //   两者混用会让「订阅名/插件名」互相覆盖（元力 6 个插件曾全叫「元力音源」）。
    const displayName: string = fallbackName.trim().length > 0 ? fallbackName.trim() : 'MusicFree 插件';
    const normalizedNew: string = script.replace(/\s+/g, '');
    const existing: LXUserApiInfo[] = this.getApiList();
    for (let i: number = 0; i < existing.length; i++) {
      if (existing[i].kind !== 'mf') {
        continue;
      }
      // 不同订阅里的同名插件不能互相覆盖 —— 一插件一平台，共存是产品语义
      if (existing[i].subId !== subId) {
        continue;
      }
      const oldRaw: string = this.readScriptSync(existing[i].id);
      if (oldRaw.length > 0 && oldRaw.replace(/\s+/g, '') === normalizedNew) {
        return { ok: true, message: existing[i].name + ' 已存在（内容相同），未重复导入', info: existing[i] };
      }
      // 匹配同一订阅里的旧条目：平台名（含旧版把订阅名写进 platform 的情况）/ 订阅名
      // / 「名字 → 平台」识别结果，任一命中都算同一个插件。
      const incomingPid: string = platformIdFromLabel(platform.length > 0 ? platform : displayName);
      const existingPid: string = platformIdFromLabel(
        existing[i].platform.length > 0 ? existing[i].platform : existing[i].name);
      const samePlatform: boolean = platform.length > 0 && existing[i].platform === platform;
      const sameName: boolean = existing[i].name === displayName;
      const sameLogicalPlatform: boolean = incomingPid.length > 0 && existingPid === incomingPid;
      if (samePlatform || sameName || sameLogicalPlatform) {
        this.saveScript(existing[i].id, script);
        // 名字只在原先为空时补：订阅项名才是稳定的去重依据
        if (existing[i].name.length === 0) {
          existing[i].name = displayName;
        }
        // ★ 只有探测到平台时才覆盖：platform 为空表示"这次还没跑起来"，
        //   不能把上次已经识别出来的平台又清掉（否则每次重导都退回未识别状态）。
        if (platform.length > 0) {
          existing[i].platform = platform;
        }
        existing[i].version = this.parseMusicFreeVersion(script);
        // 能力标记随插件升级刷新（新版可能补了 getRecommendSheetTags / getTopLists）
        const newCaps: string[] = scanMfCaps(script);
        if (newCaps.length > 0) {
          existing[i].caps = newCaps;
        }
        // 说明 / 作者也随插件升级刷新（截图里的「版本号 / 作者 / 说明」口径）
        existing[i].author = this.parseMusicFreeAuthor(script);
        const newDesc: string = this.parseMusicFreeDescription(script);
        if (newDesc.length > 0) {
          existing[i].description = newDesc;
        }
        this.apiList = existing;
        this.saveApiListToFile();
        hilog.info(DOMAIN, TAG, 'musicfree replaced id=%{public}s platform=%{public}s',
          existing[i].id, platform);
        return { ok: true, message: displayName + ' 已更新', info: existing[i] };
      }
    }
    const apiId: string = 'mf_api_' + Math.random().toString().substring(2, 5) + '_' + Date.now().toString();
    this.saveScript(apiId, script);
    if (!fs.accessSync(this.getScriptFilePath(apiId))) {
      return { ok: false, message: '插件写入失败，请重试', info: null };
    }
    const info: LXUserApiInfo = {
      id: apiId,
      name: displayName,
      description: this.parseMusicFreeDescription(script),
      allowShowUpdateAlert: false,
      author: this.parseMusicFreeAuthor(script),
      homepage: '',
      version: this.parseMusicFreeVersion(script),
      kind: 'mf',
      platform: platform,
      caps: scanMfCaps(script),
      subId: subId,
      sources: {}
    };
    const list: LXUserApiInfo[] = this.getApiList();
    list.push(info);
    this.apiList = list;
    this.saveApiListToFile();
    this.enableSourceAfterImport(info.id);
    hilog.info(DOMAIN, TAG, 'musicfree imported id=%{public}s platform=%{public}s total=%{public}d',
      apiId, platform, list.length);
    return { ok: true, message: info.name, info: info };
  }

  /**
   * 回填 MusicFree 插件的平台名（导入后异步探测用）。
   *
   * 为什么不在导入时同步等：平台名只有把插件真跑起来才知道，而插件引擎是页面里
   * 的隐藏 WebView —— 导入动作发生时它可能还没挂载。先落库让条目立刻出现，
   * 探测成功后再把名字/平台补上，用户体验是"先看到，随后自动变准"。
   *
   * @param apiId 音源 id
   * @param platform 运行时读到的 platform
   * @returns 是否更新成功
   */
  updateMusicFreePlatform(apiId: string, platform: string): boolean {
    if (platform.length === 0) {
      return false;
    }
    const list: LXUserApiInfo[] = this.getApiList();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== apiId || list[i].kind !== 'mf') {
        continue;
      }
      list[i].platform = platform;
      this.apiList = list;
      this.saveApiListToFile();
      // 通知界面：异步探测回填完成（设置页监听后 refresh，不然要重进页面才看到）
      try {
        AppStorage.setOrCreate(AppStorageKeys.MF_PLATFORM_VERSION, Date.now());
      } catch (e) {
        // AppStorage 不可用（极早期）时忽略
      }
      hilog.info(DOMAIN, TAG, 'musicfree platform backfilled id=%{public}s platform=%{public}s',
        apiId, platform);
      return true;
    }
    return false;
  }

  /**
   * 取 `module.exports = {...}` / `export default {...}` 之后的那一段（插件 manifest）。
   *
   * ★ 2026-11-09：不能在整个脚本里盲搜 `platform: "..."` —— 插件内部对象也有
   *   同名字段（bilibili 插件里就有 `platform: "pc"` / `"web"`），盲搜会把音源名
   *   读成 "pc"。manifest 一定在文件末尾的导出对象里，先切出这一段再找。
   * @param script 插件原文
   * @returns manifest 片段；没有导出语句时返回空串
   */
  private musicFreeManifestTail(script: string): string {
    const a: number = script.lastIndexOf('module.exports');
    const b: number = script.lastIndexOf('export default');
    const idx: number = Math.max(a, b);
    return idx >= 0 ? script.substring(idx) : '';
  }

  /** 从 manifest 片段里取一个字符串字段（`key: "value"`）。 */
  private manifestString(tail: string, key: string): string {
    if (tail.length === 0) {
      return '';
    }
    // 用**反向引用**匹配同一对引号：description 是 Markdown，正文里可能含 " 或 '
    // （以前用「三选一引号」做结束符，遇到正文里的引号就截断）
    // ⚠️ 这里不用模板字符串 / 反引号：ArkTS 的 ets-loader 解析带反引号的字符串会报
    //    "Unexpected token"，整个类都会跟着解析失败。
    const re: RegExp = new RegExp("\\b" + key + "\\s*:\\s*([\"'])([\\s\\S]{1,2000}?)\\1");
    const m: RegExpExecArray | null = re.exec(tail);
    return m !== null ? m[2].trim() : '';
  }

  /** 从插件头部注释里取 @version（没有就空串）。 */
  private parseMusicFreeVersion(script: string): string {
    const m: RegExpExecArray | null = /@version\s+([^\r\n*]{1,36})/.exec(script);
    if (m !== null) {
      return m[1].trim();
    }
    // 编译型插件没有头部注释，版本号在 manifest 里（MusicFree 原版「版本号」同一来源）
    return this.manifestString(this.musicFreeManifestTail(script), 'version');
  }

  /** 从插件头部注释里取 @description；新插件写在 manifest.description（Markdown）。 */
  private parseMusicFreeDescription(script: string): string {
    const m: RegExpExecArray | null = /@description\s+([^\r\n*]{1,60})/.exec(script);
    if (m !== null) {
      return m[1].trim();
    }
    return this.manifestString(this.musicFreeManifestTail(script), 'description');
  }

  /** 从插件头部注释里取 @author；新插件写在 manifest.author。 */
  private parseMusicFreeAuthor(script: string): string {
    const m: RegExpExecArray | null = /@author\s+([^\r\n*]{1,40})/.exec(script);
    if (m !== null) {
      return m[1].trim();
    }
    return this.manifestString(this.musicFreeManifestTail(script), 'author');
  }

  /**
   * 从插件脚本里**静态**读平台名（MusicFree 原版卡片上显示的那个名字）。
   *
   * ★ 2026-11-09（用户：「MusicFree 原版名称和我们现在显示的不一样」）：
   *   我们之前直接拿订阅里的 `name`（「网易」「qq」）当显示名，而 MusicFree 原版
   *   用的是 `plugin.instance.platform`（「元力WY」）。读这个不用把插件跑起来，
   *   导入时立刻就能落对名字，也省掉一次 WebView 探测。
   *
   * 取值顺序：manifest.platform → 头部 `@name` → 全文**最后**一个 platform 字面量
   * （最后一个是导出的 manifest，前面的多为请求参数）。
   * @param script 插件脚本原文
   * @returns 平台名；都没读到返回空串（调用方回退订阅名）
   */
  parseMusicFreePlatform(script: string): string {
    const fromManifest: string = this.manifestString(this.musicFreeManifestTail(script), 'platform');
    // 少数插件把 `platform` 当「客户端类型」写（pc / web / android），不是音源名
    if (fromManifest.length === 0 || MF_NON_PLATFORM_VALUES.indexOf(fromManifest.toLowerCase()) >= 0) {
      return '';
    }
    return fromManifest;
  }

  /**
   * 插件头部的 `@name`（多数插件写的是**品牌名**，不是平台名）。
   *
   * ★ 2026-11-09（用户：「现在平台全都显示元力音源」）：
   *   元力系插件的 `@name` 一律是「元力音源」，而真正的平台名（元力WY / 元力KG）
   *   是运行时才解密出来的 `module.exports.platform`。旧版把 `@name` 当平台名兜底，
   *   同一订阅 6 个插件的名字全变成「元力音源」，平台管理里根本分不出谁是谁。
   *   现在 `@name` 只用来判断「旧数据是不是被这个兜底污染过」。
   */
  private musicFreeBrandName(script: string): string {
    const m: RegExpExecArray | null = /@name\s+([^\r\n*]{1,40})/.exec(script);
    return m !== null ? m[1].trim() : '';
  }

  /**
   * 旧数据里的 `platform` 是否就是插件品牌名（`@name`）而不是真平台。
   *
   * 判据：和 `@name` 相同 **且** 识别不出是哪个平台（「元力音源」→ 空，
   * 「元力WY」→ wy）。后者说明它本来就是可用的平台名，不能清。
   */
  private isBrandNamePolluted(platform: string, brand: string): boolean {
    const p: string = platform !== undefined && platform !== null ? platform.trim() : '';
    if (p.length === 0 || brand.length === 0 || p !== brand) {
      return false;
    }
    return platformIdFromLabel(p).length === 0;
  }

  /**
   * 修改 MusicFree 源的备注（用户可读名）。
   *
   * 只动 `remark`，**不碰 `name` / `platform`** —— 后者参与订阅更新时的去重匹配，
   * 被备注覆盖会导致下次更新多出一条重复音源。
   * @param apiId 音源 id
   * @param remark 新备注；空串 = 清除备注，回到插件原名
   * @returns 是否找到并保存
   */
  setApiRemark(apiId: string, remark: string): boolean {
    if (apiId.length === 0) {
      return false;
    }
    const list: LXUserApiInfo[] = this.getApiList();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== apiId) {
        continue;
      }
      list[i].remark = remark.trim();
      this.apiList = list;
      this.saveApiListToFile();
      hilog.info(DOMAIN, TAG, 'remark updated id=%{public}s', apiId);
      return true;
    }
    return false;
  }

  /**
   * 修改 LX 脚本「实际支持的平台」（用户裁掉已经失效的平台）。
   *
   * @param apiId 音源 id
   * @param platforms 规范平台 id（kw/kg/tx/wy/mg/qs）；
   *                  **空数组 = 清除覆盖，回到脚本声明**
   * @returns 是否找到并保存
   */
  setApiPlatforms(apiId: string, platforms: string[]): boolean {
    if (apiId.length === 0) {
      return false;
    }
    const cleaned: string[] = [];
    for (let i: number = 0; i < platforms.length; i++) {
      const id: string = normalizePlatformId(platforms[i]);
      if (id.length > 0 && cleaned.indexOf(id) < 0) {
        cleaned.push(id);
      }
    }
    const list: LXUserApiInfo[] = this.getApiList();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== apiId) {
        continue;
      }
      // 空 = 取消覆盖（不要把「一个都不支持」落成状态，那等于把这个源废掉）
      list[i].platformOverride = cleaned.length > 0 ? cleaned : undefined;
      this.apiList = list;
      this.saveApiListToFile();
      hilog.info(DOMAIN, TAG, 'source platforms updated id=%{public}s n=%{public}d',
        apiId, cleaned.length);
      return true;
    }
    return false;
  }

  private parseScriptInfo(script: string): ApiScriptInfo {
    let result: RegExpExecArray | null = /\/\*[\S\s]+?\*\//.exec(script);
    if (result === null) {
      throw new Error('Invalid source file: no header comment found');
    }
    let header: string = result[0];
    let infoResult: ApiScriptInfo = this.matchInfo(header);
    if (infoResult.name.length === 0) {
      // ★ 2026-10-30：不再用「user_api_<时间>」兜底（会产出脏条目）。
      //   依次尝试 `// @name`、`@name`（任意位置），再不行判定为"不是音源脚本"。
      const lineName: RegExpExecArray | null = /\/\/\s*@name\s+(.+)/.exec(script);
      if (lineName !== null && lineName[1].trim().length > 0) {
        infoResult.name = lineName[1].trim().substring(0, 24);
      }
    }
    const looksLikeSource: boolean =
      script.indexOf('lx.send') >= 0 || script.indexOf('EVENT_NAMES') >= 0 ||
      script.indexOf('musicUrl') >= 0 || script.indexOf("@name") >= 0;
    if (!looksLikeSource) {
      throw new Error('不是洛雪音源脚本（内容不像 JS 脚本）');
    }
    if (infoResult.name.length === 0) {
      infoResult.name = '未命名音源';
    }
    return infoResult;
  }

  private matchInfo(scriptInfo: string): ApiScriptInfo {
    let infoArr: string[] = scriptInfo.split(/\r?\n/);
    let rxp: RegExp = /^\s?\*\s?@(\w+)\s(.+)$/;
    let infos: ApiScriptInfo = { name: '', description: '', author: '', homepage: '', version: '' };
    for (let i: number = 0; i < infoArr.length; i++) {
      let result: RegExpExecArray | null = rxp.exec(infoArr[i]);
      if (result === null) {
        continue;
      }
      let key: string = result[1];
      let value: string = result[2].trim();
      switch (key) {
        case 'name':
          infos.name = value.substring(0, Math.min(value.length, 24));
          break;
        case 'description':
          infos.description = value.substring(0, Math.min(value.length, 36));
          break;
        case 'author':
          infos.author = value.substring(0, Math.min(value.length, 56));
          break;
        case 'homepage':
          infos.homepage = value.substring(0, Math.min(value.length, 1024));
          break;
        case 'version':
          infos.version = value.substring(0, Math.min(value.length, 36));
          break;
      }
    }
    return infos;
  }

  removeApi(apiId: string): void {
    let list: LXUserApiInfo[] = this.getApiList();
    let newList: LXUserApiInfo[] = [];
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id !== apiId) {
        newList.push(list[i]);
      }
    }
    this.apiList = newList;
    this.saveApiListToFile();
    let scriptPath: string = this.getScriptFilePath(apiId);
    try {
      if (fs.accessSync(scriptPath)) {
        fs.unlinkSync(scriptPath);
      }
    } catch (_err) {
      // ignore
    }
  }

  // ------------------------------------------------------------------
  // MusicFree 订阅（用户视角的「源」）
  // ------------------------------------------------------------------

  private subs: MfSubscriptionInfo[] | null = null;
  /** 「订阅成员启用状态」脏数据是否已经修过（一次会话一次就够，修完即幂等）。 */
  private orderRepaired: boolean = false;

  private getSubFilePath(): string {
    return this.filesDir + '/' + MF_SUB_FILE;
  }

  private loadSubsFromFile(): MfSubscriptionInfo[] {
    if (this.filesDir.length === 0) {
      return [];
    }
    try {
      const path: string = this.getSubFilePath();
      if (!fs.accessSync(path)) {
        return [];
      }
      const stat: fs.Stat = fs.statSync(path);
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      fs.readSync(file.fd, buf, { offset: 0, length: stat.size });
      fs.closeSync(file);
      const text: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
      const store: MfSubStore = JSON.parse(text) as MfSubStore;
      const rows: MfSubscriptionInfo[] = store.subs !== undefined && store.subs !== null ? store.subs : [];
      const out: MfSubscriptionInfo[] = [];
      for (let i: number = 0; i < rows.length; i++) {
        if (rows[i].id === undefined || rows[i].id.length === 0) {
          continue;
        }
        out.push({
          id: rows[i].id,
          name: rows[i].name !== undefined ? rows[i].name : '',
          remark: rows[i].remark !== undefined ? rows[i].remark : '',
          url: rows[i].url !== undefined ? rows[i].url : '',
          apiIds: rows[i].apiIds !== undefined && rows[i].apiIds !== null ? rows[i].apiIds : [],
          updatedAt: rows[i].updatedAt !== undefined ? rows[i].updatedAt : 0
        });
      }
      return out;
    } catch (_err) {
      return [];
    }
  }

  private saveSubsToFile(): void {
    if (this.filesDir.length === 0) {
      return;
    }
    const list: MfSubscriptionInfo[] = this.subs !== null ? this.subs : [];
    const store: MfSubStore = { subs: list };
    try {
      const encoder: util.TextEncoder = new util.TextEncoder();
      const data: Uint8Array = encoder.encodeInto(JSON.stringify(store) || '');
      const path: string = this.getSubFilePath();
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, data.buffer as ArrayBuffer);
      fs.closeSync(file);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'saveSubsToFile FAILED: %{public}s', (err as Error).message ?? '');
    }
  }

  /** 全部订阅（返回副本）。 */
  getSubscriptions(): MfSubscriptionInfo[] {
    if (this.subs === null) {
      this.subs = this.loadSubsFromFile();
    }
    const out: MfSubscriptionInfo[] = [];
    for (let i: number = 0; i < this.subs.length; i++) {
      out.push({
        id: this.subs[i].id,
        name: this.subs[i].name,
        remark: this.subs[i].remark !== undefined ? this.subs[i].remark : '',
        url: this.subs[i].url,
        apiIds: this.subs[i].apiIds.slice(),
        updatedAt: this.subs[i].updatedAt
      });
    }
    return out;
  }

  /**
   * 改这份订阅（音源本身）的备注。
   *
   * ★ 用户口轻：订阅 = 音源，插件 = 平台来源。左滑「编辑」改的是音源的名字，
   *   不是某个成员插件的名字（成员备注仍可在「关于」气泡里单独改）。
   * @param subId 订阅 id
   * @param remark 新备注（空串 = 清除，回退到导入时的来源名）
   */
  setSubscriptionRemark(subId: string, remark: string): void {
    if (this.subs === null) {
      this.subs = this.loadSubsFromFile();
    }
    for (let i: number = 0; i < this.subs.length; i++) {
      if (this.subs[i].id !== subId) {
        continue;
      }
      this.subs[i].remark = remark.trim();
      this.saveSubsToFile();
      return;
    }
  }

  /**
   * 开始一次订阅导入：同 url 的订阅**复用原记录**（更新语义），否则新建。
   * @param name 用户可见名字
   * @param url 订阅地址（文件导入传空串）
   * @returns 订阅 id
   */
  beginSubscription(name: string, url: string): string {
    if (this.subs === null) {
      this.subs = this.loadSubsFromFile();
    }
    const trimmed: string = url.trim();
    if (trimmed.length > 0) {
      for (let i: number = 0; i < this.subs.length; i++) {
        if (this.subs[i].url === trimmed) {
          if (name.length > 0) {
            this.subs[i].name = name;
          }
          this.saveSubsToFile();
          return this.subs[i].id;
        }
      }
    }
    const id: string = 'mf_sub_' + Date.now().toString() + '_' + Math.floor(Math.random() * 1000);
    this.subs.push({
      id: id,
      name: name.length > 0 ? name : 'MusicFree 订阅',
      url: trimmed,
      apiIds: [],
      updatedAt: Date.now()
    });
    this.saveSubsToFile();
    return id;
  }

  /** 插件导入成功后挂到订阅下（幂等）。 */
  attachApiToSubscription(subId: string, apiId: string): void {
    if (subId.length === 0 || apiId.length === 0) {
      return;
    }
    if (this.subs === null) {
      this.subs = this.loadSubsFromFile();
    }
    for (let i: number = 0; i < this.subs.length; i++) {
      if (this.subs[i].id !== subId) {
        continue;
      }
      if (this.subs[i].apiIds.indexOf(apiId) < 0) {
        this.subs[i].apiIds.push(apiId);
      }
      this.subs[i].updatedAt = Date.now();
      this.saveSubsToFile();
      // 插件侧也记住归属（源管理按 subId 分组）
      const list: LXUserApiInfo[] = this.getApiList();
      for (let a: number = 0; a < list.length; a++) {
        if (list[a].id === apiId) {
          list[a].subId = subId;
          this.apiList = list;
          this.saveApiListToFile();
          break;
        }
      }
      return;
    }
  }

  /** 订阅导入结束后调用：清掉已经不存在的插件、刷新时间。 */
  finishSubscription(subId: string): void {
    if (this.subs === null) {
      this.subs = this.loadSubsFromFile();
    }
    const live: string[] = [];
    const all: LXUserApiInfo[] = this.getApiList();
    for (let a: number = 0; a < all.length; a++) {
      live.push(all[a].id);
    }
    for (let i: number = 0; i < this.subs.length; i++) {
      if (this.subs[i].id !== subId) {
        continue;
      }
      const kept: string[] = [];
      for (let k: number = 0; k < this.subs[i].apiIds.length; k++) {
        if (live.indexOf(this.subs[i].apiIds[k]) >= 0) {
          kept.push(this.subs[i].apiIds[k]);
        }
      }
      this.subs[i].apiIds = kept;
      this.subs[i].updatedAt = Date.now();
      this.saveSubsToFile();
      break;
    }
    // ★ 2026-11-09（用户：「源已停用是啥玩意，我源启用了啊」）：
    //   订阅是整包对象，UI 只提供整包勾选。历史数据里却出现过「六个成员只启用三个」
    //   —— 平台管理据此把另外三个标成「源已停用」，而且勾选框禁用，从平台页根本救不回来。
    //   每次导入 / 更新结束后按整包口径修一次。
    this.orderRepaired = false;
    this.repairSourceEnableState();
  }

  /**
   * 修「订阅只有部分成员启用」的脏数据（幂等，一次会话只跑一次）。
   *
   * 判定规则（不猜用户意图）：
   *   - 整包全关 / 全开：尊重现状，不动；
   *   - 部分开：**只可能是历史数据冲突**（源管理根本没有成员级开关），按整包启用补齐；
   *   - 同时清掉已经不在列表里的悬空 id（删插件后残留）。
   *
   * @returns 被修正的 id 数量（0 = 数据本来就是干净的）
   */
  repairSourceEnableState(): number {
    if (this.orderRepaired) {
      return 0;
    }
    const store: MusicStoreService = MusicStoreService.getInstance();
    if (!store.hasSourceScriptOrderConfig()) {
      // 从未配置过 = 全部启用，没有可修的东西
      this.orderRepaired = true;
      return 0;
    }
    const order: string[] = store.getSourceScriptOrder();
    if (order.length === 0) {
      // 用户把源全关了，这是明确意图
      this.orderRepaired = true;
      return 0;
    }
    const apis: LXUserApiInfo[] = this.getApiList();
    if (apis.length === 0) {
      // 列表还没读出来，先别下结论，下次调用再修
      return 0;
    }
    const live: string[] = [];
    for (let i: number = 0; i < apis.length; i++) {
      live.push(apis[i].id);
    }
    let next: string[] = [];
    let fixed: number = 0;
    for (let i: number = 0; i < order.length; i++) {
      if (live.indexOf(order[i]) >= 0) {
        next.push(order[i]);
      } else {
        fixed++;
      }
    }
    // 订阅整包口径
    const subs: MfSubscriptionInfo[] = this.getSubscriptions();
    for (let s: number = 0; s < subs.length; s++) {
      const members: string[] = [];
      for (let a: number = 0; a < apis.length; a++) {
        const owned: boolean = apis[a].subId === subs[s].id ||
          (apis[a].subId.length === 0 && subs[s].apiIds.indexOf(apis[a].id) >= 0);
        if (owned) {
          members.push(apis[a].id);
        }
      }
      if (members.length === 0) {
        continue;
      }
      let on: number = 0;
      for (let m: number = 0; m < members.length; m++) {
        if (next.indexOf(members[m]) >= 0) {
          on++;
        }
      }
      if (on === 0 || on === members.length) {
        continue;
      }
      for (let m: number = 0; m < members.length; m++) {
        if (next.indexOf(members[m]) < 0) {
          next.push(members[m]);
          fixed++;
        }
      }
    }
    if (fixed > 0) {
      store.setSourceScriptOrder(next);
      appendPlayLog('[音源顺序] repair 补齐/清理 ' + fixed + ' 项');
    }
    this.orderRepaired = true;
    return fixed;
  }

  /**
   * 用本次导入的成员集合**替换**订阅成员（更新语义）。
   *
   * 只有本次没有失败（`allowRemove`）时才删旧成员：某个插件临时下载失败，
   * 不能把它在本地的那份也删掉 —— 用户下次还能用，等恢复网络再更新。
   *
   * @param subId 订阅 id
   * @param keepIds 本次成功导入的插件 id
   * @param allowRemove 是否允许删除不在 keepIds 里的旧成员
   * @returns 被移除的插件数量
   */
  syncSubscriptionMembers(subId: string, keepIds: string[], allowRemove: boolean): number {
    if (this.subs === null) {
      this.subs = this.loadSubsFromFile();
    }
    let removed: number = 0;
    for (let i: number = 0; i < this.subs.length; i++) {
      if (this.subs[i].id !== subId) {
        continue;
      }
      const olds: string[] = this.subs[i].apiIds.slice();
      for (let k: number = 0; k < olds.length; k++) {
        if (keepIds.indexOf(olds[k]) >= 0) {
          continue;
        }
        if (allowRemove) {
          this.removeApi(olds[k]);
          removed++;
        } else {
          keepIds.push(olds[k]);
        }
      }
      this.subs[i].apiIds = keepIds.slice();
      this.subs[i].updatedAt = Date.now();
      this.saveSubsToFile();
      break;
    }
    return removed;
  }

  /** 删除整份订阅：其下所有插件（脚本 + 列表项）+ 订阅记录。 */
  removeSubscription(subId: string): number {
    if (this.subs === null) {
      this.subs = this.loadSubsFromFile();
    }
    let removed: number = 0;
    for (let i: number = 0; i < this.subs.length; i++) {
      if (this.subs[i].id !== subId) {
        continue;
      }
      const ids: string[] = this.subs[i].apiIds.slice();
      for (let k: number = 0; k < ids.length; k++) {
        this.removeApi(ids[k]);
        removed++;
      }
      this.subs.splice(i, 1);
      this.saveSubsToFile();
      break;
    }
    // 兜底：插件自身记着 subId 但订阅表里漏了（老数据 / 上次中断）也一并清掉
    const remaining: LXUserApiInfo[] = this.getApiList();
    for (let a: number = 0; a < remaining.length; a++) {
      if (remaining[a].subId === subId) {
        this.removeApi(remaining[a].id);
        removed++;
      }
    }
    return removed;
  }

  /** 该插件归属的订阅；独立导入返回 null。 */
  subscriptionOf(apiId: string): MfSubscriptionInfo | null {
    const list: MfSubscriptionInfo[] = this.getSubscriptions();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].apiIds.indexOf(apiId) >= 0) {
        return list[i];
      }
    }
    return null;
  }

  async getFullApiInfo(apiId: string): Promise<LXUserApiInfoFull | null> {
    let list: LXUserApiInfo[] = this.getApiList();
    let apiInfo: LXUserApiInfo | undefined;
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === apiId) {
        apiInfo = list[i];
        break;
      }
    }
    if (apiInfo === undefined) {
      return null;
    }
    let script: string = await this.getScript(apiId);
    let fullInfo: LXUserApiInfoFull = {
      id: apiInfo.id,
      name: apiInfo.name,
      description: apiInfo.description,
      script: script,
      allowShowUpdateAlert: apiInfo.allowShowUpdateAlert,
      author: apiInfo.author,
      homepage: apiInfo.homepage,
      version: apiInfo.version,
      kind: apiInfo.kind,
      platform: apiInfo.platform,
      sources: apiInfo.sources
    };
    return fullInfo;
  }

  // ------------------------------------------------------------ 跨设备搬运（同步载荷）

  /**
   * 音源 id 是否可用作文件名。
   *
   * ★ 这是同步下载侧的**必做校验**：id 来自远端 JSON，会拼成 `lx_api_script_<id>.js`，
   * 不校验就等于把沙箱文件路径交给远端数据（`../` 之类）。本机自动生成的 id
   * （`user_api_<3位>_<时间戳>`）天然满足这个字符集。
   */
  isValidApiId(apiId: string): boolean {
    return typeof apiId === 'string' && API_ID_PATTERN.test(apiId);
  }

  /** 本机是否已有这个 id 的音源 */
  hasApi(apiId: string): boolean {
    if (apiId.length === 0) {
      return false;
    }
    const list: LXUserApiInfo[] = this.getApiList();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === apiId) {
        return true;
      }
    }
    return false;
  }

  /**
   * 列出全部音源（含脚本原文），供同步上行打包。
   *
   * 读不到脚本的条目照旧返回（script 为空串）：调用方据此决定是跳过还是照发元数据，
   * 这里不替它做决定。
   */
  async listFullApis(): Promise<LXUserApiInfoFull[]> {
    const out: LXUserApiInfoFull[] = [];
    const list: LXUserApiInfo[] = this.getApiList();
    for (let i: number = 0; i < list.length; i++) {
      const item: LXUserApiInfo = list[i];
      const script: string = await this.getScript(item.id);
      const fullInfo: LXUserApiInfoFull = {
        id: item.id,
        name: item.name,
        description: item.description,
        script: script,
        allowShowUpdateAlert: item.allowShowUpdateAlert,
        author: item.author,
        homepage: item.homepage,
        version: item.version,
        kind: item.kind,
        platform: item.platform,
        sources: item.sources
      };
      out.push(fullInfo);
    }
    return out;
  }

  /**
   * 按「给定 id」落盘一个音源（同步下载用）。
   *
   * 与 importApi 的区别只有一个：**id 由调用方给**（远端那一份），不重新生成 ——
   * 生成新 id 会让同一份音源在两台设备上变成两个音源，永远无法比对/去重。
   *
   * 保守约定（与本文件 importApi 相同的那条：先落脚本、再改列表，任一步失败都不留半成品）：
   *   - 本机已有同 id ⇒ 返回 'exists'，**一个字节都不改**（冲突判定交给调用方，
   *     它手上才有两边的脚本文本可以比）；
   *   - id 非法 / 脚本为空 / 目录未就绪 ⇒ 'failed'，不落盘。
   */
  importApiWithId(seed: LXApiSeed): LXApiUpsertResult {
    if (!this.ready()) {
      hilog.error(DOMAIN, TAG, 'importApiWithId aborted: filesDir not ready');
      return { outcome: 'failed', message: '存储目录未就绪' };
    }
    if (!this.isValidApiId(seed.id)) {
      hilog.error(DOMAIN, TAG, 'importApiWithId aborted: bad id=%{public}s', seed.id);
      return { outcome: 'failed', message: '音源 id 非法' };
    }
    if (seed.script.length === 0) {
      return { outcome: 'failed', message: '脚本为空' };
    }
    // 先读列表（getApiList 顺带把列表读进内存），后面 push 才不会把已有音源整表覆盖掉
    const list: LXUserApiInfo[] = this.getApiList();
    if (this.apiList === null) {
      hilog.error(DOMAIN, TAG, 'importApiWithId aborted: list not loaded');
      return { outcome: 'failed', message: '存储目录未就绪' };
    }
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === seed.id) {
        return { outcome: 'exists', message: list[i].name };
      }
    }
    this.saveScript(seed.id, seed.script);
    if (!fs.accessSync(this.getScriptFilePath(seed.id))) {
      hilog.error(DOMAIN, TAG, 'importApiWithId aborted: script save verify failed id=%{public}s', seed.id);
      return { outcome: 'failed', message: '脚本写入失败' };
    }
    const info: LXUserApiInfo = {
      id: seed.id,
      name: seed.name !== undefined && seed.name.length > 0 ? seed.name : seed.id,
      description: seed.description !== undefined ? seed.description : '',
      allowShowUpdateAlert: seed.allowShowUpdateAlert !== undefined ? seed.allowShowUpdateAlert : true,
      author: seed.author !== undefined ? seed.author : '',
      homepage: seed.homepage !== undefined ? seed.homepage : '',
      version: seed.version !== undefined ? seed.version : '',
      kind: seed.kind !== undefined && seed.kind.length > 0 ? seed.kind : 'lx',
      platform: seed.platform !== undefined ? seed.platform : '',
      subId: '',
      sources: {}
    };
    list.push(info);
    this.apiList = list;
    this.saveApiListToFile();
    this.enableSourceAfterImport(info.id);
    hilog.info(DOMAIN, TAG, 'imported(from sync) id=%{public}s name=%{public}s total=%{public}d',
      info.id, info.name, list.length);
    return { outcome: 'added', message: info.name };
  }
}

interface ApiScriptInfo {
  name: string;
  description: string;
  author: string;
  homepage: string;
  version: string;
}

export let lxSourceManager: LXSourceManager = new LXSourceManager();