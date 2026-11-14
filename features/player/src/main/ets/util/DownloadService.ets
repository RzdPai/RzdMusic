import { UIContext } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { MusicStoreService, appendPlayLog } from 'musicbasic';
import { getLXMusicUrl } from '../source/LXPlayHelper';
import { lxEngineIsReady } from '../source/LXSourceEngine';
import { lxGetLyricFull, lxGetPicFallback, LyricFullResult } from '../source/LXMusicSDK';
import { getQualityChain } from './SourceFallbackUtil';
import { AmllLyricLine } from '../amll/model/AmllTypes';
import { amllParseLyricText } from '../amll/parse/AmllAutoDetect';
import { amllStringifyLrc } from '../amll/parse/AmllLyricFormatParsers';
import { writeAudioMetadata, AudioMetadataWriter } from '@dabing/taglib_harmony';

/** lx-music 风格的下载任务状态机：排队 / 下载中 / 暂停 / 已完成 / 失败。 */
export class DownloadStatus {
  static readonly WAITING: string = 'waiting';
  static readonly RUNNING: string = 'running';
  static readonly PAUSED: string = 'paused';
  static readonly COMPLETED: string = 'completed';
  static readonly FAILED: string = 'failed';
}

/** 单个下载任务（队列项）。 */
export class DownloadTask {
  id: string = '';
  source: string = '';
  songId: string = '';
  name: string = '';
  singer: string = '';
  albumName: string = '';
  imgUrl: string = '';
  quality: string = '';
  fileName: string = '';
  status: string = DownloadStatus.WAITING;
  progress: number = 0;
  downloaded: number = 0;
  total: number = 0;
  speed: string = '';
  message: string = '';
  tempPath: string = '';

  clone(): DownloadTask {
    const t: DownloadTask = new DownloadTask();
    t.id = this.id;
    t.source = this.source;
    t.songId = this.songId;
    t.name = this.name;
    t.singer = this.singer;
    t.albumName = this.albumName;
    t.imgUrl = this.imgUrl;
    t.quality = this.quality;
    t.fileName = this.fileName;
    t.status = this.status;
    t.progress = this.progress;
    t.downloaded = this.downloaded;
    t.total = this.total;
    t.speed = this.speed;
    t.message = this.message;
    t.tempPath = this.tempPath;
    return t;
  }
}

const MAX_CONCURRENT_DOWNLOADS: number = 3;
const MAX_URL_RETRY: number = 2;
const NOTIFY_INTERVAL_MS: number = 500;
const MAX_PERSISTED_TASKS: number = 100;
/** 断点续传时用作校验的文件末尾字节数（对齐 lx-music Downloader）。 */
const RESUME_TAIL_BYTES: number = 10;

/**
 * lx-music 桌面版风格的下载管理器：
 * 任务队列（并发上限 3）+ 流式下载（不整读进内存）+ 实时进度/速度 + 失败自动重试
 * + 完成后写元信息（标题/歌手/专辑/封面/歌词）+ 可选同目录导出 .lrc。
 */
export class DownloadService {
  private static instance: DownloadService | undefined;

  static getInstance(): DownloadService {
    if (DownloadService.instance === undefined) {
      DownloadService.instance = new DownloadService();
    }
    return DownloadService.instance;
  }

  private tasks: DownloadTask[] = [];
  private activeRequests: Map<string, http.HttpRequest> = new Map();
  private retryCounts: Map<string, number> = new Map();
  private listeners: ((tasks: DownloadTask[]) => void)[] = [];
  private downloadDirUri: string = '';
  private uiContext: UIContext | undefined = undefined;
  private appContext: common.Context | undefined = undefined;
  private lastNotifyAt: number = 0;
  private lastSpeedBytes: number = 0;
  private lastSpeedAt: number = 0;
  private pumping: boolean = false;
  /** 通知栏进度通知固定 id（复用同一 id 更新/取消）。 */
  private notifyId: number = 202611;
  /** 是否已发布过进度通知（用于无任务时取消）。 */
  private notifActive: boolean = false;
  /** 是否已请求过通知权限。 */
  private notifRequested: boolean = false;

  private constructor() {
    this.loadPersistedTasks();
  }

  /** 首次下载时申请通知授权（已授权则静默成功）。 */
  private async ensureNotificationPermission(): Promise<void> {
    if (this.notifRequested || this.appContext === undefined) {
      return;
    }
    this.notifRequested = true;
    try {
      await notificationManager.requestEnableNotification(this.appContext as common.UIAbilityContext);
    } catch (_e) {
      // 用户撤销或未开放系统下拉栏权限，忽略（发布将静默失败）
    }
  }

  /** 同步通知栏进度：有下载中则发布/更新，否则取消。 */
  private syncNotification(): void {
    const running: DownloadTask[] = [];
    for (let i: number = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status === DownloadStatus.RUNNING) {
        running.push(this.tasks[i]);
      }
    }
    if (running.length === 0) {
      if (this.notifActive || this.tasks.length === 0) {
        this.notifActive = false;
        notificationManager.cancel(this.notifyId).catch((_e: Object): void => {});
      }
      return;
    }
    let fileName: string = running[0].fileName;
    let progress: number = running[0].progress;
    if (running.length > 1) {
      let sum: number = 0;
      for (let i: number = 0; i < running.length; i++) {
        sum += running[i].progress;
      }
      progress = Math.round(sum / running.length);
      fileName = running.length + ' 个任务下载中';
    }
    const progressInt: number = Math.max(0, Math.min(99, progress));
    this.publishNotification(fileName, progressInt);
  }

  /** 发布/更新带进度环与百分比的通知。 */
  private publishNotification(fileName: string, progress: number): void {
    const percentText: string = progress >= 0 ? progress + '%' : '';
    const request: notificationManager.NotificationRequest = {
      id: this.notifyId,
      notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: '音乐下载',
          text: fileName,
          additionalText: percentText
        }
      },
      template: {
        name: 'downloadTemplate',
        data: {
          'title': '下载音乐',
          'fileName': fileName.length > 0 ? fileName + ' · ' + percentText : percentText,
          'progressValue': progress
        }
      }
    };
    this.notifActive = true;
    notificationManager.publish(request).catch((_e: Object): void => {
      this.notifActive = false;
    });
  }

  /** 当前任务快照（克隆，供 UI 渲染）。 */
  getTasksSnapshot(): DownloadTask[] {
    const out: DownloadTask[] = [];
    for (let i: number = 0; i < this.tasks.length; i++) {
      out.push(this.tasks[i].clone());
    }
    return out;
  }

  addListener(listener: (tasks: DownloadTask[]) => void): void {
    this.listeners.push(listener);
  }

  removeListener(listener: (tasks: DownloadTask[]) => void): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  /**
   * 入队一个下载任务（同源同曲同音质去重）。
   * @returns 是否成功入队。
   */
  enqueue(source: string, songId: string, name: string, singer: string, quality: string,
    uiContext: UIContext | undefined, imgUrl: string = '', albumName: string = '',
    silent: boolean = false): boolean {
    if (!lxEngineIsReady) {
      this.toast(uiContext, '音源未就绪，请先在设置中导入并选中源');
      return false;
    }
    if (uiContext !== undefined) {
      this.uiContext = uiContext;
      try {
        this.appContext = uiContext.getHostContext();
      } catch (_e) {
        this.appContext = undefined;
      }
    }
    void this.ensureNotificationPermission();
    const id: string = source + '_' + songId + '_' + quality;
    for (let i: number = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id === id && this.tasks[i].status !== DownloadStatus.FAILED) {
        if (!silent) {
          this.toast(uiContext, '已在下载队列中');
        }
        return false;
      }
    }
    const task: DownloadTask = new DownloadTask();
    task.id = id;
    task.source = source;
    task.songId = songId;
    task.name = name;
    task.singer = singer;
    task.albumName = albumName;
    task.imgUrl = imgUrl;
    task.quality = quality;
    task.fileName = this.buildFileName(name, singer, quality);
    this.tasks.push(task);
    this.retryCounts.delete(id);
    appendPlayLog('[下载] 入队 ' + task.fileName);
    if (!silent) {
      this.toast(uiContext, '已加入下载队列');
    }
    this.notify(true);
    this.pump();
    return true;
  }

  /** 重试失败任务（从头开始）。 */
  retry(taskId: string): void {
    const task: DownloadTask | undefined = this.findTask(taskId);
    if (task === undefined || task.status !== DownloadStatus.FAILED) {
      return;
    }
    this.retryCounts.delete(taskId);
    task.status = DownloadStatus.WAITING;
    task.progress = 0;
    task.message = '';
    this.notify(true);
    this.pump();
  }

  /** 删除任务；运行中的会取消请求并清理半截临时文件。 */
  remove(taskId: string): void {
    const idx: number = this.findIndex(taskId);
    if (idx < 0) {
      return;
    }
    const task: DownloadTask = this.tasks[idx];
    const req: http.HttpRequest | undefined = this.activeRequests.get(taskId);
    if (req !== undefined) {
      this.activeRequests.delete(taskId);
      try {
        req.destroy();
      } catch (_e) {
        // already destroyed
      }
    }
    this.tasks.splice(idx, 1);
    this.retryCounts.delete(taskId);
    this.cleanupTemp(task);
    this.notify(true);
  }

  /** 清除已完成的任务。 */
  clearCompleted(): void {
    const kept: DownloadTask[] = [];
    for (let i: number = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status !== DownloadStatus.COMPLETED) {
        kept.push(this.tasks[i]);
      }
    }
    this.tasks = kept;
    this.notify(true);
  }

  /** 暂停任务：运行中的取消当前请求，保留半截文件用于断点续传。 */
  pause(taskId: string): void {
    const task: DownloadTask | undefined = this.findTask(taskId);
    if (task === undefined) {
      return;
    }
    if (task.status === DownloadStatus.RUNNING) {
      // 先改状态，让 runTask 的异常分支识别为主动暂停而不是失败
      task.status = DownloadStatus.PAUSED;
      task.message = '已暂停';
      task.speed = '';
      const req: http.HttpRequest | undefined = this.activeRequests.get(taskId);
      if (req !== undefined) {
        this.activeRequests.delete(taskId);
        try {
          req.destroy();
        } catch (_e) {
          // already destroyed
        }
      }
      this.notify(true);
    } else if (task.status === DownloadStatus.WAITING) {
      task.status = DownloadStatus.PAUSED;
      task.message = '已暂停';
      this.notify(true);
    }
  }

  /** 继续已暂停的任务（从半截文件断点续传）。 */
  resume(taskId: string): void {
    const task: DownloadTask | undefined = this.findTask(taskId);
    if (task === undefined || task.status !== DownloadStatus.PAUSED) {
      return;
    }
    task.status = DownloadStatus.WAITING;
    task.message = '';
    this.notify(true);
    this.pump();
  }

  /** 暂停全部运行/排队中的任务。 */
  pauseAll(): void {
    let changed: boolean = false;
    for (let i: number = 0; i < this.tasks.length; i++) {
      const task: DownloadTask = this.tasks[i];
      if (task.status === DownloadStatus.WAITING) {
        task.status = DownloadStatus.PAUSED;
        task.message = '已暂停';
        changed = true;
      } else if (task.status === DownloadStatus.RUNNING) {
        task.status = DownloadStatus.PAUSED;
        task.message = '已暂停';
        task.speed = '';
        const req: http.HttpRequest | undefined = this.activeRequests.get(task.id);
        if (req !== undefined) {
          this.activeRequests.delete(task.id);
          try {
            req.destroy();
          } catch (_e) {
            // already destroyed
          }
        }
        changed = true;
      }
    }
    if (changed) {
      this.notify(true);
    }
  }

  /** 继续全部已暂停的任务。 */
  resumeAll(): void {
    let changed: boolean = false;
    for (let i: number = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status === DownloadStatus.PAUSED) {
        this.tasks[i].status = DownloadStatus.WAITING;
        this.tasks[i].message = '';
        changed = true;
      }
    }
    if (changed) {
      this.notify(true);
      this.pump();
    }
  }

  /** 启动时恢复持久化的任务队列；未完成任务降级为暂停（对齐 lx-music 重启策略）。 */
  private loadPersistedTasks(): void {
    try {
      const text: string = MusicStoreService.getInstance().getDownloadTasks();
      if (text.length === 0 || text === '[]') {
        return;
      }
      const parsed: DownloadTask[] = JSON.parse(text) as DownloadTask[];
      if (parsed === undefined || parsed.length === 0) {
        return;
      }
      const loaded: DownloadTask[] = [];
      for (let i: number = 0; i < parsed.length && i < MAX_PERSISTED_TASKS; i++) {
        const row: DownloadTask = parsed[i];
        const t: DownloadTask = new DownloadTask();
        t.id = row.id ?? '';
        t.source = row.source ?? '';
        t.songId = row.songId ?? '';
        t.name = row.name ?? '';
        t.singer = row.singer ?? '';
        t.albumName = row.albumName ?? '';
        t.imgUrl = row.imgUrl ?? '';
        t.quality = row.quality ?? '';
        t.fileName = row.fileName ?? '';
        t.status = row.status ?? DownloadStatus.PAUSED;
        t.message = row.message ?? '';
        if (t.id.length === 0 || t.source.length === 0 || t.songId.length === 0) {
          continue;
        }
        if (t.status === DownloadStatus.RUNNING || t.status === DownloadStatus.WAITING) {
          t.status = DownloadStatus.PAUSED;
          t.message = '已暂停';
        }
        if (t.status === DownloadStatus.COMPLETED || t.status === DownloadStatus.FAILED) {
          t.tempPath = '';
          t.downloaded = 0;
          t.total = 0;
        }
        loaded.push(t);
      }
      this.tasks = loaded;
    } catch (_err) {
      // corrupt persisted queue: start empty
    }
  }

  private findTask(taskId: string): DownloadTask | undefined {
    for (let i: number = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id === taskId) {
        return this.tasks[i];
      }
    }
    return undefined;
  }

  private findIndex(taskId: string): number {
    for (let i: number = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id === taskId) {
        return i;
      }
    }
    return -1;
  }

  private cleanupTemp(task: DownloadTask): void {
    if (task.tempPath.length === 0) {
      return;
    }
    try {
      fs.unlinkSync(task.tempPath);
    } catch (_e) {
      // ignore cleanup failure
    }
    task.tempPath = '';
  }

  private toast(uiContext: UIContext | undefined, message: string): void {
    if (uiContext !== undefined) {
      uiContext.getPromptAction().showToast({ message: message, duration: 2000 });
    }
  }

  private toastLatest(message: string): void {
    this.toast(this.uiContext, message);
  }

  private notify(force: boolean): void {
    const now: number = Date.now();
    if (!force && now - this.lastNotifyAt < NOTIFY_INTERVAL_MS) {
      return;
    }
    this.lastNotifyAt = now;
    const text: string = JSON.stringify(this.tasks) ?? '[]';
    AppStorage.setOrCreate('lxDownloadTasks', text);
    try {
      MusicStoreService.getInstance().setDownloadTasks(text);
    } catch (_e) {
      // persistence is best-effort
    }
    const ver: number = AppStorage.get<number>('lxDownloadTasksVersion') ?? 0;
    AppStorage.setOrCreate('lxDownloadTasksVersion', ver + 1);
    const snapshot: DownloadTask[] = this.getTasksSnapshot();
    for (let i: number = 0; i < this.listeners.length; i++) {
      try {
        this.listeners[i](snapshot);
      } catch (_e) {
        // listener errors must not break the queue
      }
    }
    this.syncNotification();
  }

  /** 按并发上限从等待队列补位启动。 */
  private pump(): void {
    if (this.pumping) {
      return;
    }
    this.pumping = true;
    try {
      let running: number = this.countRunning();
      const waitList: DownloadTask[] = [];
      for (let i: number = 0; i < this.tasks.length; i++) {
        if (this.tasks[i].status === DownloadStatus.WAITING) {
          waitList.push(this.tasks[i]);
        }
      }
      while (running < MAX_CONCURRENT_DOWNLOADS && waitList.length > 0) {
        const task: DownloadTask | undefined = waitList.shift();
        if (task === undefined) {
          break;
        }
        this.startTask(task);
        running++;
      }
    } finally {
      this.pumping = false;
    }
  }

  private countRunning(): number {
    let count: number = 0;
    for (let i: number = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status === DownloadStatus.RUNNING) {
        count++;
      }
    }
    return count;
  }

  private startTask(task: DownloadTask): void {
    task.status = DownloadStatus.RUNNING;
    task.message = '解析地址';
    task.progress = 0;
    task.speed = '';
    this.notify(true);
    void this.runTask(task);
  }

  private async runTask(task: DownloadTask): Promise<void> {
    const context: common.Context | undefined = this.appContext;
    if (context === undefined) {
      this.failTask(task, '应用上下文不可用');
      return;
    }
    try {
      // 1) 解析下载地址：按所选音质起、逐档向下兜底
      const chain: string[] = getQualityChain(task.quality, task.source);
      let url: string = '';
      for (let i: number = 0; i < chain.length; i++) {
        try {
          const u: string = await getLXMusicUrl(task.source, task.songId, chain[i], task.name, task.singer);
          if (u.length > 0) {
            url = u;
            task.quality = chain[i];
            break;
          }
        } catch (_err) {
          // try next quality
        }
      }
      if (url.length === 0) {
        this.failTask(task, '获取下载地址失败');
        return;
      }
      if (this.findIndex(task.id) < 0) {
        return;
      }
      // 2) 流式下载到缓存临时文件
      task.status = DownloadStatus.RUNNING;
      task.message = '下载中';
      task.downloaded = 0;
      task.total = 0;
      this.lastSpeedBytes = 0;
      this.lastSpeedAt = Date.now();
      this.notify(true);
      const safeId: string = task.id.replace(/[^A-Za-z0-9_-]/g, '_');
      const tmpPath: string = context.cacheDir + '/dl_' + safeId + '.tmp';
      task.tempPath = tmpPath;
      await this.downloadToFile(task, url, tmpPath);
      if (this.findIndex(task.id) < 0) {
        return;
      }
      const stat: fs.Stat = fs.statSync(tmpPath);
      if (stat.size < 1024) {
        throw new Error('文件内容异常');
      }
      // 3) 元信息（标题/歌手/专辑/封面/歌词）
      task.message = '写入元信息';
      this.notify(true);
      const all: LyricFullResult = await this.fetchLyric(task);
      let coverUrl: string = task.imgUrl;
      if (coverUrl.length === 0) {
        try {
          coverUrl = await lxGetPicFallback(task.source, task.songId, '', task.name, task.singer);
        } catch (_err) {
          coverUrl = '';
        }
      }
      await this.embedMetadata(tmpPath, task, coverUrl, all);
      // 4) 保存到目标位置 + 同目录 .lrc
      task.message = '保存文件';
      this.notify(true);
      const lrcText: string = this.buildLrcText(all);
      await this.saveToDestination(task, tmpPath, lrcText);
      this.cleanupTemp(task);
      task.status = DownloadStatus.COMPLETED;
      task.progress = 100;
      task.message = '已完成';
      task.speed = '';
      appendPlayLog('[下载] 完成 ' + task.fileName);
      this.notify(true);
      this.toastLatest('下载完成: ' + task.name);
    } catch (err) {
      if (this.findIndex(task.id) < 0) {
        return;
      }
      if (task.status === DownloadStatus.PAUSED) {
        // 用户主动暂停：保留半截文件等待续传，不计失败
        return;
      }
      const msg: string = err instanceof Error ? err.message : JSON.stringify(err);
      this.failTask(task, msg.substring(0, 60));
    }
  }

  /** 失败自动重试（间隔 1s，最多 2 次），超限标记失败。 */
  private failTask(task: DownloadTask, reason: string): void {
    this.cleanupTemp(task);
    appendPlayLog('[下载] 失败(' + reason + ') ' + task.fileName);
    if (reason.indexOf('Resume') === 0) {
      // 续传校验失败重下不算消耗重试次数（对齐 lx-music）
      this.retryCounts.delete(task.id);
    }
    const count: number = (this.retryCounts.get(task.id) ?? 0) + 1;
    this.retryCounts.set(task.id, count);
    if (count <= MAX_URL_RETRY) {
      task.message = '重试 ' + count + '/' + MAX_URL_RETRY;
      this.notify(true);
      const ref: DownloadTask = task;
      const service: DownloadService = this;
      setTimeout((): void => {
        if (service.findIndex(ref.id) < 0) {
          return;
        }
        ref.status = DownloadStatus.WAITING;
        service.notify(true);
        service.pump();
      }, 1000);
      return;
    }
    task.status = DownloadStatus.FAILED;
    task.message = reason;
    task.speed = '';
    this.notify(true);
    this.toastLatest('下载失败: ' + task.name);
    this.pump();
  }

  /** 流式下载：分块写文件，实时回调进度/速度；支持 Range 断点续传（末尾校验块）。 */
  private downloadToFile(task: DownloadTask, url: string, tmpPath: string): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (e: Error) => void): void => {
      // 断点续传：检查半截文件，读取末尾 N 字节作为校验块
      let baseSize: number = 0;
      let tail: Uint8Array | null = null;
      try {
        const stat: fs.Stat = fs.statSync(tmpPath);
        if (stat.size > RESUME_TAIL_BYTES * 2) {
          baseSize = stat.size;
          const buf: ArrayBuffer = new ArrayBuffer(RESUME_TAIL_BYTES);
          const rf: fs.File = fs.openSync(tmpPath, fs.OpenMode.READ_ONLY);
          try {
            fs.readSync(rf.fd, buf, { offset: baseSize - RESUME_TAIL_BYTES, length: RESUME_TAIL_BYTES });
          } finally {
            fs.closeSync(rf);
          }
          tail = new Uint8Array(buf);
        }
      } catch (_e) {
        baseSize = 0;
        tail = null;
      }
      const resume: boolean = tail !== null;
      const baseOffset: number = resume ? baseSize - RESUME_TAIL_BYTES : 0;

      let file: fs.File;
      try {
        file = fs.openSync(tmpPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE |
          (resume ? 0 : fs.OpenMode.TRUNC));
      } catch (e) {
        reject(new Error('创建临时文件失败'));
        return;
      }
      const req: http.HttpRequest = http.createHttp();
      this.activeRequests.set(task.id, req);
      let settled: boolean = false;
      let writePos: number = baseOffset;
      let tailVerified: boolean = !resume;
      const service: DownloadService = this;
      const finish = (ok: boolean, errMsg: string): void => {
        if (settled) {
          return;
        }
        settled = true;
        service.activeRequests.delete(task.id);
        try {
          fs.closeSync(file);
        } catch (_e) {
          // ignore
        }
        try {
          req.off('dataReceive');
          req.off('dataReceiveProgress');
          req.off('dataEnd');
        } catch (_e) {
          // ignore
        }
        try {
          req.destroy();
        } catch (_e) {
          // ignore
        }
        if (ok) {
          resolve();
        } else {
          reject(new Error(errMsg));
        }
      };
      req.on('dataReceive', (chunk: ArrayBuffer): void => {
        if (settled) {
          return;
        }
        if (!tailVerified) {
          // 校验续传起点：新数据开头必须与旧文件末尾一致，否则删档重下
          const checkLen: number = Math.min(RESUME_TAIL_BYTES, chunk.byteLength);
          const incoming: Uint8Array = new Uint8Array(chunk.slice(0, checkLen));
          if (tail !== null) {
            for (let i: number = 0; i < checkLen; i++) {
              if (incoming[i] !== tail[i]) {
                finish(false, 'Resume failed');
                return;
              }
            }
          }
          tailVerified = true;
        }
        try {
          fs.writeSync(file.fd, chunk, { offset: writePos });
          writePos += chunk.byteLength;
        } catch (_e) {
          finish(false, '写入失败');
        }
      });
      req.on('dataReceiveProgress', (data: http.DataReceiveProgressInfo): void => {
        task.downloaded = baseOffset + data.receiveSize;
        task.total = data.totalSize > 0 ? baseOffset + data.totalSize : 0;
        if (task.total > 0) {
          task.progress = Math.min(99, Math.floor(task.downloaded * 100 / task.total));
        }
        const now: number = Date.now();
        const dt: number = now - service.lastSpeedAt;
        if (dt >= 1000) {
          const bps: number = (data.receiveSize - service.lastSpeedBytes) * 1000 / Math.max(1, dt);
          service.lastSpeedBytes = data.receiveSize;
          service.lastSpeedAt = now;
          task.speed = bps > 0 ? (bps / 1024 / 1024).toFixed(1) + 'MB/s' : '';
        }
        service.notify(false);
      });
      req.on('dataEnd', (): void => {
        if (resume && !tailVerified) {
          finish(false, 'Resume failed');
          return;
        }
        finish(true, '');
      });
      const headers: Record<string, string> = { 'User-Agent': 'lx-music request' };
      if (resume) {
        headers['Range'] = 'bytes=' + baseOffset + '-';
      }
      req.requestInStream(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 15000,
        readTimeout: 60000
      }).then((responseCode: number): void => {
        if (resume && responseCode === 200) {
          // 服务器忽略 Range 返回全量内容：续传位置已失效，删档重下
          finish(false, 'Resume failed');
          return;
        }
        if (responseCode !== 200 && responseCode !== 206) {
          finish(false, 'HTTP ' + responseCode);
        }
      }).catch((_e: Object): void => {
        finish(false, '网络请求失败');
      });
    });
  }

  private async fetchLyric(task: DownloadTask): Promise<LyricFullResult> {
    try {
      return await lxGetLyricFull(task.source, task.songId, task.name, task.singer);
    } catch (_err) {
      const empty: LyricFullResult = { main: '', translation: '', romanLyric: '' };
      return empty;
    }
  }

  /** 就地写入音频标签：标题/歌手/专辑/封面/内嵌歌词。 */
  private async embedMetadata(filePath: string, task: DownloadTask, coverUrl: string,
    all: LyricFullResult): Promise<void> {
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      if (coverUrl.length > 0) {
        pixelMap = await this.loadCoverPixelMap(coverUrl);
      }
      const writer: AudioMetadataWriter = {
        title: task.name,
        artist: task.singer
      };
      if (task.albumName.length > 0) {
        writer.album = task.albumName;
      }
      if (pixelMap !== undefined) {
        writer.coverImage = pixelMap;
      }
      let embedLyric: string = '';
      if (all.main.length > 0) {
        const lines: AmllLyricLine[] = amllParseLyricText(all.main);
        embedLyric = lines.length > 0 ? amllStringifyLrc(lines) : all.main;
      }
      if (embedLyric.length > 0) {
        writer.lyrics = embedLyric;
      }
      try {
        await writeAudioMetadata(filePath, writer);
        appendPlayLog('[下载] 元信息嵌入完成 封面=' + (pixelMap !== undefined) +
          ' 歌词=' + (embedLyric.length > 0));
      } catch (e) {
        appendPlayLog('[下载] 元信息写入失败: ' + JSON.stringify(e).substring(0, 200));
      } finally {
        if (pixelMap !== undefined) {
          pixelMap.release();
          pixelMap = undefined;
        }
      }
    } catch (_err) {
      if (pixelMap !== undefined) {
        try {
          pixelMap.release();
        } catch (_e) {
          // ignore
        }
      }
      appendPlayLog('[下载] 元信息嵌入异常，使用原始文件');
    }
  }

  /** 构建外置 .lrc 内容：主歌词 + 按时间对齐合并的翻译行。 */
  private buildLrcText(all: LyricFullResult): string {
    if (all.main.length === 0) {
      return '';
    }
    let lines: AmllLyricLine[] = [];
    try {
      lines = amllParseLyricText(all.main);
    } catch (_e) {
      lines = [];
    }
    if (lines.length === 0) {
      return all.main;
    }
    let tLines: AmllLyricLine[] = [];
    if (all.translation.length > 0) {
      try {
        tLines = amllParseLyricText(all.translation);
      } catch (_e) {
        tLines = [];
      }
    }
    const out: string[] = [];
    for (let i: number = 0; i < lines.length; i++) {
      const line: AmllLyricLine = lines[i];
      const text: string = this.lineText(line);
      if (text.length === 0) {
        continue;
      }
      const ts: string = this.formatLrcTime(line.startTime);
      out.push('[' + ts + ']' + text);
      for (let j: number = 0; j < tLines.length; j++) {
        if (Math.abs(tLines[j].startTime - line.startTime) <= 120) {
          const tr: string = this.lineText(tLines[j]);
          if (tr.length > 0) {
            out.push('[' + ts + ']' + tr);
          }
          break;
        }
      }
    }
    return out.join('\n');
  }

  private lineText(line: AmllLyricLine): string {
    let text: string = '';
    for (let i: number = 0; i < line.words.length; i++) {
      text += line.words[i].word;
    }
    return text.trim();
  }

  private pad2(n: number): string {
    return n < 10 ? '0' + n : '' + n;
  }

  private formatLrcTime(ms: number): string {
    const totalSec: number = Math.max(0, Math.floor(ms / 1000));
    const milli: number = Math.max(0, Math.floor(ms % 1000));
    const m3: string = milli < 10 ? '00' + milli : (milli < 100 ? '0' + milli : '' + milli);
    return this.pad2(Math.floor(totalSec / 60)) + ':' + this.pad2(totalSec % 60) + '.' + m3;
  }

  /** 保存到目标位置：Download 目录（授权一次复用）或系统保存对话框。 */
  private async saveToDestination(task: DownloadTask, tmpPath: string, lrcText: string): Promise<void> {
    const saveMode: string = MusicStoreService.getInstance().getDownloadSaveMode();
    let finalPath: string = '';
    if (saveMode === 'download') {
      await this.ensureDownloadDir();
      if (this.downloadDirUri.length === 0) {
        throw new Error('未授权下载目录');
      }
      const destPath: string = new fileUri.FileUri(this.downloadDirUri + '/' + task.fileName).path;
      await this.copyTo(tmpPath, destPath);
      finalPath = destPath;
    } else {
      const hostContext: common.Context | undefined =
        this.uiContext !== undefined ? this.uiContext.getHostContext() : undefined;
      if (hostContext === undefined) {
        throw new Error('无法打开保存窗口');
      }
      const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(hostContext);
      const saveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [task.fileName];
      const uris: string[] = await docPicker.save(saveOptions);
      if (uris.length === 0) {
        throw new Error('已取消保存');
      }
      await this.copyTo(tmpPath, uris[0]);
      finalPath = new fileUri.FileUri(uris[0]).path;
    }
    appendPlayLog('[下载] 已保存 ' + finalPath);
    const wantLrc: boolean = MusicStoreService.getInstance().getDownloadLrc();
    if (lrcText.length > 0 && wantLrc) {
      try {
        const lrcPath: string = finalPath.replace(/\.[^.]+$/, '') + '.lrc';
        const lrcFile: fs.File = fs.openSync(lrcPath,
          fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
        fs.writeSync(lrcFile.fd, lrcText);
        fs.closeSync(lrcFile);
        appendPlayLog('[下载] 已导出歌词 ' + lrcPath);
      } catch (_e) {
        // lrc is optional
      }
    }
  }

  private async copyTo(srcPath: string, destPathOrUri: string): Promise<void> {
    const destFile: fs.File = fs.openSync(destPathOrUri,
      fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      await fs.copyFile(srcPath, destFile.fd);
    } finally {
      fs.closeSync(destFile);
    }
  }

  /** Download 目录 uri 只在首次请求授权，之后复用。 */
  private async ensureDownloadDir(): Promise<void> {
    if (this.downloadDirUri.length > 0) {
      return;
    }
    const context: common.Context | undefined =
      this.uiContext !== undefined ? this.uiContext.getHostContext() : undefined;
    if (context === undefined) {
      return;
    }
    const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    opt.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
    const documentViewPicker = new picker.DocumentViewPicker(context);
    const result: string[] = await documentViewPicker.save(opt);
    if (result.length > 0) {
      this.downloadDirUri = result[0];
      appendPlayLog('[下载] 目录 uri=' + this.downloadDirUri);
    }
  }

  /** 下载封面图片并解码为 PixelMap。 */
  private async loadCoverPixelMap(imgUrl: string): Promise<image.PixelMap | undefined> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(imgUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 30000
      });
      if (resp.responseCode !== 200 || resp.result === undefined) {
        return undefined;
      }
      const src: image.ImageSource = image.createImageSource(resp.result as ArrayBuffer);
      try {
        const pm: image.PixelMap = await src.createPixelMap();
        return pm;
      } finally {
        src.release();
      }
    } catch (_err) {
      return undefined;
    } finally {
      req.destroy();
    }
  }

  /** 构建下载文件名（命名模板 + 可选音质标签），与原 DownloadUtil 规则一致。 */
  private buildFileName(name: string, singer: string, quality: string): string {
    const safeName: string = name.replace(/[\\/:*?"<>|]/g, '_');
    const safeSinger: string = singer.replace(/[\\/:*?"<>|]/g, '_');
    const flacLike: boolean = quality === 'flac' || quality === 'flac24bit' ||
      quality === 'hires' || quality === 'atmos' || quality === 'atmos_plus' || quality === 'master';
    const ext: string = flacLike ? '.flac' :
      (quality === 'ape' ? '.ape' : (quality === 'wav' ? '.wav' : '.mp3'));
    const format: string = MusicStoreService.getInstance().getDownloadNameFormat();
    let base: string = safeName;
    if (format === 'artist_title') {
      base = safeSinger.length > 0 ? safeSinger + '-' + safeName : safeName;
    } else if (format === 'title_artist') {
      base = safeName + (safeSinger.length > 0 ? '-' + safeSinger : '');
    }
    const tagQuality: boolean = MusicStoreService.getInstance().getDownloadQualityTag();
    return tagQuality ? base + '-' + quality + ext : base + ext;
  }
}
