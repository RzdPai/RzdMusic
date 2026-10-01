/*
 * 原生个人云空间备份（CoreFileKit cloudSync.FileSync + context.cloudFileDir）。
 *
 * 与 `HuaweiCloudSync`（旧网页 Drive 那套 OAuth）是**两个独立空间**：
 *   系统云同步：须在系统「设置→云空间」打开本应用的同步开关；系统 6.0.0.115+、云空间 6.0.0.300+。
 *   旧网页云盘：单独授权、单独凭据，与这里的文件互不可见。
 *
 * ★ 只有**确认文件确实上云**才允许提示成功（用户明确要求）：
 *   - `FileSync.on('progress')` 的**首次** COMPLETED 只是「注册回调成功」（官方原文），
 *     不能当作上传完成；`FileSync.start()` 的 Promise 成功也仅表示「已启动」。
 *   - 真实判据是 `cloudSync.getCoreFileSyncState(uri)`：
 *     `UPLOAD_SUCCESS` = 已上云；`UPLOADING` / `TO_BE_UPLOADED` / `STOPPED` = 还在处理 ⇒ 只能提示「处理中/未确认」。
 *
 * 日志关键字：RzdHuaweiCloud（grep 这个就能看到每一步的判定与理由）。
 */

import { cloudSync, fileIo, fileUri } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DataBackupService, getAppRuntime } from 'musicbasic';

const TAG: string = 'RzdHuaweiCloud';
const MAX_BYTES: number = 16 * 1024 * 1024;
const WAIT_MS: number = 60000;
const FILE_NAME: string = 'rzdmusic-native-backup-v1.json';

/** 个人云空间应用沙箱；不使用网页 OAuth 客户端或 Drive REST 凭据。 */
export class HuaweiNativeCloudBackup {
  private static instance: HuaweiNativeCloudBackup = new HuaweiNativeCloudBackup();
  private busy: boolean = false;

  public static getInstance(): HuaweiNativeCloudBackup {
    return HuaweiNativeCloudBackup.instance;
  }

  private path(): string {
    const context = getAppRuntime().context;
    if (context === undefined || context.cloudFileDir.length === 0) {
      throw new Error('系统云空间目录不可用，请检查系统版本与应用云同步配置');
    }
    return context.cloudFileDir + '/' + FILE_NAME;
  }

  /**
   * 读一个文件的端云同步状态；读不到时返回 `undefined`（**不要**当成成功）。
   * 官方 `getCoreFileSyncState` 会抛 13900010(Try again)/13900002/13900012 等瞬时错误，
   * 抛异常时按「状态不明」处理并打日志，绝不当作「已上云」。
   */
  private syncStateOf(uri: string): cloudSync.FileState | undefined {
    try {
      return cloudSync.getCoreFileSyncState(uri);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(0, TAG, 'getCoreFileSyncState failed code=%{public}d msg=%{public}s',
        error.code ?? 0, error.message ?? '');
      return undefined;
    }
  }

  /** 该状态是否算「确实已经上云」。 */
  private static isUploaded(state: cloudSync.FileState | undefined): boolean {
    return state === cloudSync.FileState.UPLOAD_SUCCESS;
  }

  /** 该状态是否算「任务还在处理中」（⇒ 只能提示处理中，不能报成功）。 */
  private static isProcessing(state: cloudSync.FileState | undefined): boolean {
    return state === cloudSync.FileState.UPLOADING ||
      state === cloudSync.FileState.TO_BE_UPLOADED ||
      state === cloudSync.FileState.STOPPED;
  }

  public async backup(): Promise<string> {
    if (this.busy) {
      // 明确「处理中」，不报成功
      return '处理中，请稍候';
    }
    this.busy = true;
    try {
      // 不覆盖last-good：新备份使用唯一文件名，完整fsync后同cloud目录rename发布。
      const path: string = this.path() + '.' + Date.now() + '.' + util.generateRandomUUID() + '.json';
      const staging: string = path + '.partial';
      const bytes: Uint8Array = new util.TextEncoder().encodeInto(
        DataBackupService.getInstance().exportSnapshotText());
      if (bytes.length === 0 || bytes.length > MAX_BYTES) {
        throw new Error('备份大小超出限制');
      }
      const file = fileIo.openSync(staging,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        const written: number = fileIo.writeSync(file.fd, bytes.buffer as ArrayBuffer);
        if (written !== bytes.length) {
          throw new Error('备份文件未完整写入');
        }
        fileIo.fsyncSync(file.fd);
      } finally {
        fileIo.closeSync(file);
      }
      // partial文件即使同步也不会被恢复发现；rename目标不存在，不删除旧版本。
      fileIo.renameSync(staging, path);
      hilog.info(0, TAG, 'backup wrote local file bytes=%{public}d; waiting for confirmed upload',
        bytes.length);
      // 只有这里返回（即 getCoreFileSyncState === UPLOAD_SUCCESS）才允许提示「已备份」
      await this.synchronize(fileUri.getUriFromPath(path));
      hilog.info(0, TAG, 'backup upload confirmed, reporting success to user');
      return '备份成功';
    } catch (err) {
      return this.failure('备份', err as BusinessError);
    } finally {
      this.busy = false;
    }
  }

  public async restore(): Promise<string> {
    if (this.busy) {
      return '处理中，请稍候';
    }
    this.busy = true;
    try {
      const base: string = this.path();
      // 先同步元数据，等待本次真实同步完成后才发现其他设备的备份。
      await this.synchronize('');
      const directory: string = base.substring(0, base.lastIndexOf('/'));
      const candidates: string[] = fileIo.listFileSync(directory).filter((name: string): boolean => {
        return name.startsWith(FILE_NAME + '.') && name.endsWith('.json');
      });
      candidates.sort();
      hilog.info(0, TAG, 'restore scan candidates=%{public}d', candidates.length);
      let path: string = '';
      for (let i: number = candidates.length - 1; i >= 0; i--) {
        const candidate: string = directory + '/' + candidates[i];
        const location: number = fileIo.statSync(candidate).location;
        const state: cloudSync.FileState | undefined = this.syncStateOf(fileUri.getUriFromPath(candidate));
        // location: 1=仅本机 2=仅云端 3=本机+云端（LocationType 位标志）
        // 只有「文件在云端」且「确实上云成功 / 刚从云端下载」的候选才算已上云备份
        if (location === 2 || (location === 3 &&
          (HuaweiNativeCloudBackup.isUploaded(state) ||
            state === cloudSync.FileState.INITIAL_AFTER_DOWNLOAD))) {
          path = candidate;
          hilog.info(0, TAG, 'restore picked uploaded backup location=%{public}d state=%{public}d',
            location, state ?? -1);
          break;
        }
        hilog.info(0, TAG, 'restore skip candidate location=%{public}d state=%{public}d (not uploaded)',
          location, state ?? -1);
      }
      if (path.length === 0 && fileIo.accessSync(base)) {
        // 老版本写的固定名备份：是否算「已上云」交给下面的 location/state 检查判定
        path = base;
        hilog.info(0, TAG, 'restore fallback to legacy fixed-name file');
      }
      if (path.length === 0) {
        hilog.warn(0, TAG, 'restore aborted: no uploaded backup in system cloud space');
        return '没有可恢复的备份';
      }
      const location: number = fileIo.statSync(path).location;
      if (location === 1) {
        // 文件只在本地（同步开关没开 / 还没轮到上传）⇒ 明确拒绝，绝不当成云备份恢复
        hilog.warn(0, TAG, 'restore refused: local-only file, cloud version unconfirmed');
        throw new Error('备份仅在本机，尚未确认云端版本，拒绝作为云备份恢复');
      }
      if (location === 2) {
        // 只有云端有：先缓存到本地再读
        await this.cacheFile(fileUri.getUriFromPath(path));
      } else if (location !== 3) {
        throw new Error('无法确认备份的云端状态');
      }
      const fileState: cloudSync.FileState | undefined = this.syncStateOf(fileUri.getUriFromPath(path));
      if (fileState !== cloudSync.FileState.INITIAL_AFTER_DOWNLOAD &&
        fileState !== cloudSync.FileState.UPLOAD_SUCCESS) {
        hilog.warn(0, TAG, 'restore refused: local file has unsynced changes state=%{public}d',
          fileState ?? -1);
        throw new Error('本地备份有未完成上云的修改，拒绝恢复为云端备份');
      }
      const size: number = fileIo.statSync(path).size;
      if (size <= 0 || size > MAX_BYTES) {
        throw new Error('备份大小无效');
      }
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const buffer: ArrayBuffer = new ArrayBuffer(size);
      let offset: number = 0;
      try {
        while (offset < size) {
          const part: ArrayBuffer = new ArrayBuffer(size - offset);
          const count: number = fileIo.readSync(file.fd, part);
          if (count <= 0) {
            throw new Error('备份文件读取不完整');
          }
          new Uint8Array(buffer).set(new Uint8Array(part, 0, count), offset);
          offset += count;
        }
      } finally {
        fileIo.closeSync(file);
      }
      hilog.info(0, TAG, 'restore read confirmed-cloud backup bytes=%{public}d', offset);
      return await DataBackupService.getInstance().restoreSnapshotText(
        util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buffer)));
    } catch (err) {
      return this.failure('恢复', err as BusinessError);
    } finally {
      this.busy = false;
    }
  }

  /**
   * 等一次真实的端云同步完成。
   *
   * `uploadUri` 非空 ⇒ 等这个文件**确实上云**（`UPLOAD_SUCCESS`）；
   * 空串 ⇒ 只等元数据同步（用于恢复前先把别的设备写的备份拉下来）。
   *
   * ⚠️ `progress` 回调的首次 COMPLETED 只是回调注册成功（官方原文），
   * 所以必须用 `active` 门把「注册成功那次」排除掉，并且最终还要用
   * `getCoreFileSyncState` 复核 —— 两者都过了才返回。
   */
  private async synchronize(uploadUri: string): Promise<void> {
    const sync: cloudSync.FileSync = new cloudSync.FileSync();
    let active: boolean = false;
    let started: boolean = false;
    let completed: boolean = false;
    let failure: string = '';
    const callback = (progress: cloudSync.SyncProgress): void => {
      hilog.info(0, TAG, 'sync progress state=%{public}d error=%{public}d', progress.state, progress.error);
      if (!started) {
        return;
      }
      if (progress.state === cloudSync.SyncState.UPLOADING ||
        progress.state === cloudSync.SyncState.DOWNLOADING) {
        active = true;
      }
      if (active && progress.state === cloudSync.SyncState.COMPLETED &&
        progress.error === cloudSync.ErrorType.NO_ERROR) {
        completed = true;
      }
      if (progress.state === cloudSync.SyncState.UPLOAD_FAILED ||
        progress.state === cloudSync.SyncState.DOWNLOAD_FAILED ||
        progress.error !== cloudSync.ErrorType.NO_ERROR) {
        failure = '同步失败，状态 ' + progress.state + '，错误 ' + progress.error;
      }
    };
    sync.on('progress', callback);
    try {
      const lastTime: number = await sync.getLastSyncTime();
      started = true;
      await sync.start();
      hilog.info(0, TAG, 'sync started uploadUri=%{public}d', uploadUri.length > 0 ? 1 : 0);
      const deadline: number = Date.now() + WAIT_MS;
      while (Date.now() < deadline) {
        if (failure.length > 0) {
          throw new Error(failure);
        }
        if (uploadUri.length > 0) {
          const state: cloudSync.FileState | undefined = this.syncStateOf(uploadUri);
          if (HuaweiNativeCloudBackup.isUploaded(state)) {
            hilog.info(0, TAG, 'per-file upload confirmed: UPLOAD_SUCCESS');
            return;
          }
          if (state === cloudSync.FileState.UPLOAD_FAILURE) {
            throw new Error('备份文件上云失败');
          }
          if (HuaweiNativeCloudBackup.isProcessing(state)) {
            // 任务仍在处理中 —— 继续等，绝不提前返回成功
            hilog.info(0, TAG, 'upload still in progress state=%{public}d', state ?? -1);
          }
        } else if (completed || await sync.getLastSyncTime() > lastTime) {
          hilog.info(0, TAG, 'metadata sync confirmed (no upload uri)');
          return;
        }
        await new Promise<void>((resolve) => { setTimeout(resolve, 500); });
      }
      hilog.warn(0, TAG, 'sync not confirmed within %{public}d ms, reporting as unfinished', WAIT_MS);
      // 未在时限内确认：界面只报「备份失败/恢复失败」，具体原因（未确认上云 / 未确认同步）留在日志
      throw new Error(uploadUri.length > 0 ? 'upload not confirmed within deadline' :
        'metadata sync not confirmed within deadline');
    } finally {
      sync.off('progress', callback);
    }
  }

  private async cacheFile(uri: string): Promise<void> {
    const cache: cloudSync.CloudFileCache = new cloudSync.CloudFileCache();
    let finished: boolean = false;
    let failure: string = '';
    const callback = (progress: cloudSync.DownloadProgress): void => {
      if (progress.uri !== uri) {
        return;
      }
      hilog.info(0, TAG, 'cache progress state=%{public}d error=%{public}d', progress.state, progress.error);
      if (progress.state === cloudSync.State.COMPLETED) {
        finished = true;
      } else if (progress.state === cloudSync.State.FAILED || progress.state === cloudSync.State.STOPPED) {
        failure = '云端备份下载失败，错误 ' + progress.error;
      }
    };
    cache.on('progress', callback);
    try {
      await cache.start(uri);
      const deadline: number = Date.now() + WAIT_MS;
      while (!finished && Date.now() < deadline) {
        if (failure.length > 0) {
          throw new Error(failure);
        }
        await new Promise<void>((resolve) => { setTimeout(resolve, 500); });
      }
      if (!finished) {
        await cache.stop(uri);
        throw new Error('云端备份下载超时');
      }
    } finally {
      cache.off('progress', callback);
    }
  }

  private failure(action: string, error: BusinessError): string {
    // 详细原因只进日志（RzdHuaweiCloud）；界面上只给一句结论，不做多余说明（用户要求）
    hilog.warn(0, TAG, 'task failed action=%{public}s code=%{public}d msg=%{public}s',
      action, error.code ?? 0, error.message ?? '');
    return action + '失败';
  }
}
