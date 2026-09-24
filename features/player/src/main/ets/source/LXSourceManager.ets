import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LXUserApiInfo, LXUserApiInfoFull, LXUserApiSourceInfo } from './Interface';

const DOMAIN: number = 0x0000;
const TAG: string = 'RzdLxSource';

const LX_API_LIST_FILE: string = 'lx_api_list.json';
const LX_API_SCRIPT_PREFIX: string = 'lx_api_script_';

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
      hilog.warn(DOMAIN, TAG, 'filesDir 未初始化，跳过读取且不缓存');
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
    if (apiId.length === 0 || this.filesDir.length === 0) {
      return;
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
      // 这里以前是 console.error：落盘失败只进控制台，用户和日志都看不到
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
      hilog.error(DOMAIN, TAG, 'importApi aborted: filesDir 未初始化（脚本没落盘）');
      return { ok: false, message: '存储目录未就绪，导入失败', info: null };
    }
    let parsed: ApiScriptInfo;
    try {
      parsed = this.parseScriptInfo(scriptRaw);
    } catch (err) {
      const e: Error = err as Error;
      return { ok: false, message: e.message ?? '脚本格式不正确', info: null };
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
      sources: {}
    };
    // 先落脚本再改列表：任何一步失败都不要往列表里塞半成品
    this.saveScript(apiId, scriptRaw);
    if (!fs.accessSync(this.getScriptFilePath(apiId))) {
      hilog.error(DOMAIN, TAG, 'importApi aborted: 脚本落盘校验失败 id=%{public}s', apiId);
      return { ok: false, message: '脚本写入失败，请重试', info: null };
    }
    // 关键：先把已存在的列表读进内存，再 push —— 否则会把老音源整表覆盖掉
    let list: LXUserApiInfo[] = this.getApiList();
    if (this.apiList === null) {
      hilog.error(DOMAIN, TAG, 'importApi aborted: 列表未加载（拒绝覆盖已有音源）');
      return { ok: false, message: '存储目录未就绪，导入失败', info: null };
    }
    list.push(apiInfo);
    this.apiList = list;
    this.saveApiListToFile();
    hilog.info(DOMAIN, TAG, 'imported id=%{public}s name=%{public}s total=%{public}d',
      apiInfo.id, apiInfo.name, list.length);
    return { ok: true, message: apiInfo.name, info: apiInfo };
  }

  private parseScriptInfo(script: string): ApiScriptInfo {
    let result: RegExpExecArray | null = /\/\*[\S\s]+?\*\//.exec(script);
    if (result === null) {
      throw new Error('Invalid source file: no header comment found');
    }
    let header: string = result[0];
    let infoResult: ApiScriptInfo = this.matchInfo(header);
    if (infoResult.name.length === 0) {
      infoResult.name = 'user_api_' + new Date().toLocaleString();
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
      sources: apiInfo.sources
    };
    return fullInfo;
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