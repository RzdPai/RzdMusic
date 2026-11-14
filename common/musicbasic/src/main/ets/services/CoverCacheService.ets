import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LIMIT: number = 100 * 1024 * 1024;
const IMAGE_LIMIT: number = 4 * 1024 * 1024;
const TTL_MS: number = 7 * 24 * 60 * 60 * 1000;
const ENTRY_LIMIT: number = 1024;

@ObservedV2
export class CoverCacheState {
  @Trace generation: number = 0;
  @Trace bytes: number = 0;
  @Trace clearing: boolean = false;
}

class CoverEntry {
  name: string = '';
  size: number = 0;
  time: number = 0;
}

class CoverJob {
  url: string = '';
  generation: number = 0;
  resolve: (path: string) => void = (_path: string): void => {};
}

/** Only owns cacheDir/rzd-http-covers-v1; never touches music, accounts or playlists. */
export class CoverCacheService {
  private static instance: CoverCacheService = new CoverCacheService();
  readonly state: CoverCacheState = new CoverCacheState();
  private directory: string = '';
  private initialized: boolean = false;
  private active: number = 0;
  private queue: CoverJob[] = [];
  private pending: Map<string, Promise<string>> = new Map<string, Promise<string>>();
  private diskTail: Promise<void> = Promise.resolve();

  static getInstance(): CoverCacheService {
    return CoverCacheService.instance;
  }

  private configure(context: common.Context): void {
    if (this.directory.length === 0) {
      this.directory = context.cacheDir + '/rzd-http-covers-v1';
    }
  }

  private async disk<T>(action: () => Promise<T>): Promise<T> {
    const previous: Promise<void> = this.diskTail;
    let unlock: () => void = (): void => {};
    this.diskTail = new Promise<void>((resolve) => { unlock = resolve; });
    await previous;
    try {
      return await action();
    } finally {
      unlock();
    }
  }

  private async ensureDirectory(): Promise<void> {
    if (!await fs.access(this.directory)) {
      await fs.mkdir(this.directory);
    }
  }

  private async key(url: string): Promise<string> {
    const digest = cryptoFramework.createMd('SHA256');
    await digest.update({ data: new Uint8Array(buffer.from(url, 'utf-8').buffer) });
    const result = await digest.digest();
    let key: string = '';
    for (let i: number = 0; i < result.data.length; i++) {
      key += result.data[i].toString(16).padStart(2, '0');
    }
    return key;
  }

  /** Bounded demand queue, no playlist-wide prefetch; overflow stays placeholder. */
  resolve(context: common.Context, url: string): Promise<string> {
    this.configure(context);
    if (!/^https?:\/\//i.test(url) || url.length > 8192 || this.state.clearing) {
      return Promise.resolve('');
    }
    const existing = this.pending.get(url);
    if (existing !== undefined) {
      return existing;
    }
    if (this.queue.length >= 64) {
      return Promise.resolve('');
    }
    const job = new CoverJob();
    job.url = url;
    job.generation = this.state.generation;
    const promise = new Promise<string>((resolve) => { job.resolve = resolve; });
    this.pending.set(url, promise);
    this.queue.push(job);
    this.pump();
    return promise;
  }

  private pump(): void {
    while (!this.state.clearing && this.active < 2 && this.queue.length > 0) {
      const job: CoverJob = this.queue.shift()!;
      this.active++;
      void this.run(job).then((path: string): void => {
        this.pending.delete(job.url);
        job.resolve(path);
        this.active--;
        this.pump();
      });
    }
  }

  private valid(job: CoverJob): boolean {
    return !this.state.clearing && job.generation === this.state.generation;
  }

  private async run(job: CoverJob): Promise<string> {
    let key: string = '';
    let request: http.HttpRequest | undefined = undefined;
    let partial: string = '';
    try {
      key = await this.key(job.url);
      const path: string = this.directory + '/' + key + '.cover';
      const hit: boolean = await this.disk(async (): Promise<boolean> => {
        await this.ensureDirectory();
        if (!this.initialized) {
          await this.prune(0);
          this.initialized = true;
        }
        if (!this.valid(job)) {
          return false;
        }
        if (await fs.access(path)) {
          const stat = await fs.stat(path);
          if (stat.size > 0 && stat.size <= IMAGE_LIMIT && Date.now() - stat.mtime * 1000 < TTL_MS) {
            return true;
          }
          await fs.unlink(path);
        }
        return false;
      });
      if (!this.valid(job)) {
        return '';
      }
      hilog.info(0, 'RzdCoverCache', 'key=%{public}s %{public}s', key.slice(0, 12), hit ? 'hit' : 'miss');
      if (hit) {
        return path;
      }
      request = http.createHttp();
      const response = await request.request(job.url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        maxLimit: IMAGE_LIMIT,
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer)) {
        throw new Error('response rejected');
      }
      const data: ArrayBuffer = response.result as ArrayBuffer;
      if (data.byteLength === 0 || data.byteLength > IMAGE_LIMIT) {
        throw new Error('size rejected');
      }
      // Decode validation is authoritative even if server omits/mislabels MIME.
      const source = image.createImageSource(data);
      try {
        const info = await source.getImageInfo();
        if (info.size.width <= 0 || info.size.height <= 0 || info.size.width > 8192 || info.size.height > 8192) {
          throw new Error('dimensions rejected');
        }
        const decoded = await source.createPixelMap({ desiredSize: { width: 128, height: 128 } });
        await decoded.release();
      } finally {
        await source.release();
      }
      return await this.disk(async (): Promise<string> => {
        if (!this.valid(job)) {
          return '';
        }
        // Reserve capacity before writing; serialized writes/clear prevent races.
        await this.prune(data.byteLength);
        partial = path + '.' + job.generation + '.partial';
        const file = await fs.open(partial, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try {
          let written: number = 0;
          while (written < data.byteLength) {
            const count: number = await fs.write(file.fd, data.slice(written));
            if (count <= 0) {
              throw new Error('short write');
            }
            written += count;
          }
          await fs.fsync(file.fd);
        } finally {
          await fs.close(file);
        }
        if (!this.valid(job)) {
          await fs.unlink(partial);
          partial = '';
          return '';
        }
        await fs.rename(partial, path);
        partial = '';
        this.state.bytes += data.byteLength;
        return this.valid(job) ? path : '';
      });
    } catch (_error) {
      hilog.warn(0, 'RzdCoverCache', 'key=%{public}s load failed', key.slice(0, 12));
      if (partial.length > 0) {
        try {
          await fs.unlink(partial);
        } catch (_ignored) {}
      }
      return '';
    } finally {
      request?.destroy();
    }
  }

  private async prune(reserve: number): Promise<void> {
    const names: string[] = await fs.listFile(this.directory);
    const entries: CoverEntry[] = [];
    let total: number = 0;
    for (let i: number = 0; i < names.length; i++) {
      const name: string = names[i];
      if (!/^[a-f0-9]{64}\.cover(?:\.\d+\.partial)?$/.test(name)) {
        continue;
      }
      const path: string = this.directory + '/' + name;
      const stat = await fs.stat(path);
      if (!stat.isFile()) {
        continue;
      }
      if (name.endsWith('.partial') || stat.size <= 0 || stat.size > IMAGE_LIMIT || Date.now() - stat.mtime * 1000 >= TTL_MS) {
        await fs.unlink(path);
        continue;
      }
      const entry = new CoverEntry();
      entry.name = name;
      entry.size = stat.size;
      entry.time = stat.mtime;
      entries.push(entry);
      total += entry.size;
    }
    entries.sort((a: CoverEntry, b: CoverEntry): number => a.time - b.time);
    let index: number = 0;
    while (index < entries.length && (total + reserve > LIMIT || entries.length - index >= ENTRY_LIMIT)) {
      await fs.unlink(this.directory + '/' + entries[index].name);
      total -= entries[index].size;
      index++;
    }
    this.state.bytes = total;
    hilog.info(0, 'RzdCoverCache', 'size bytes=%{public}d', total);
  }

  async refreshSize(context: common.Context): Promise<number> {
    this.configure(context);
    return this.disk(async (): Promise<number> => {
      await this.ensureDirectory();
      await this.prune(0);
      this.initialized = true;
      return this.state.bytes;
    });
  }

  async clear(context: common.Context): Promise<void> {
    this.configure(context);
    if (this.state.clearing) {
      throw new Error('clear already running');
    }
    this.state.clearing = true;
    this.state.generation++;
    hilog.info(0, 'RzdCoverCache', 'clear begin generation=%{public}d', this.state.generation);
    // Cancel queued work, invalidate active network/decodes, then drain before deletion.
    const queued: CoverJob[] = this.queue.splice(0);
    for (let i: number = 0; i < queued.length; i++) {
      this.pending.delete(queued[i].url);
      queued[i].resolve('');
    }
    const active: Promise<string>[] = Array.from(this.pending.values());
    try {
      await Promise.all(active);
      await this.disk(async (): Promise<void> => {
        await this.ensureDirectory();
        const names = await fs.listFile(this.directory);
        for (let i: number = 0; i < names.length; i++) {
          if (/^[a-f0-9]{64}\.cover(?:\.\d+\.partial)?$/.test(names[i])) {
            await fs.unlink(this.directory + '/' + names[i]);
          }
        }
        await this.prune(0);
        if (this.state.bytes !== 0) {
          throw new Error('clear incomplete');
        }
        this.initialized = true;
      });
      hilog.info(0, 'RzdCoverCache', 'clear complete size=0');
    } catch (error) {
      hilog.warn(0, 'RzdCoverCache', 'clear failed');
      throw new Error('cover cache clear failed');
    } finally {
      this.state.clearing = false;
    }
  }
}
