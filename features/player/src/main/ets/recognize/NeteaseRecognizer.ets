import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RecognitionResult } from './RecognitionTypes';
import { RecognitionNetworkError } from './errors';

const LOG_DOMAIN = 0x0000;
const LOG_TAG = 'RzdNeteaseRecognizer';
const REQUEST_TIMEOUT_MS = 15000;
const MAX_FP_SECONDS = 15;
const TARGET_RATE = 8000;
const AF_TIMEOUT_MS = 60000;

// 网易云 AFP 指纹 WASM 在隐藏 ArkWeb 页面中运行（afp_worker.html），
// 输入 8kHz Float32 PCM（base64），输出 AFP 指纹（base64）。
export class NeteaseRecognizer {
  private controller: webview.WebviewController;
  private webReady: boolean = false;
  private pendingResolve: ((fp: string) => void) | undefined = undefined;
  private pendingReject: ((reason: Error) => void) | undefined = undefined;
  private timeoutTimer: number = -1;
  private running: boolean = false;
  private static readonly base64Helper: util.Base64Helper = new util.Base64Helper();

  constructor(controller: webview.WebviewController) {
    this.controller = controller;
  }

  markReady(): void {
    this.webReady = true;
  }

  // 8kHz Float32 PCM -> base64
  private encodePcm(samples: Float32Array): string {
    const bytes = new Uint8Array(samples.buffer);
    return NeteaseRecognizer.base64Helper.encodeToStringSync(bytes);
  }

  handleAfpResult(result: string): void {
    clearTimeout(this.timeoutTimer);
    this.running = false;
    const resolve = this.pendingResolve;
    const reject = this.pendingReject;
    this.pendingResolve = undefined;
    this.pendingReject = undefined;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AFP结果 长度=%{public}d 前缀=%{public}s',
      result.length, result.substring(0, 40));
    if (result.startsWith('ERROR:')) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'AFP引擎错误: %{public}s', result.substring(6));
      if (reject !== undefined) {
        reject(new Error(result.substring(6)));
      }
      return;
    }
    if (resolve !== undefined) {
      resolve(result);
    }
  }

  private generateFingerprint(samples: Float32Array): Promise<string> {
    return new Promise<string>((resolve: (value: string) => void, reject: (reason: Error) => void): void => {
      if (!this.webReady) {
        hilog.error(LOG_DOMAIN, LOG_TAG, '指纹引擎未就绪（WebView 未加载完成）');
        reject(new Error('网易云指纹引擎未就绪'));
        return;
      }
      if (this.running) {
        reject(new Error('网易云指纹引擎正忙'));
        return;
      }
      this.running = true;
      this.pendingResolve = resolve;
      this.pendingReject = reject;
      const base64Pcm: string = this.encodePcm(samples);
      hilog.info(LOG_DOMAIN, LOG_TAG, '提交AFP 输入样本=%{public}d base64长度=%{public}d', samples.length, base64Pcm.length);
      const script: string = `window.afpStart("${base64Pcm}")`;
      void this.controller.runJavaScript(script).catch((err: Object): void => {
        clearTimeout(this.timeoutTimer);
        this.running = false;
        const rejectFn = this.pendingReject;
        this.pendingResolve = undefined;
        this.pendingReject = undefined;
        hilog.error(LOG_DOMAIN, LOG_TAG, 'runJavaScript失败: %{public}s', JSON.stringify(err));
        if (rejectFn !== undefined) {
          rejectFn(new Error('调用网易云指纹引擎失败'));
        }
      });
      this.timeoutTimer = setTimeout((): void => {
        this.running = false;
        const rejectFn = this.pendingReject;
        this.pendingResolve = undefined;
        this.pendingReject = undefined;
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'AFP计算超时（%{public}d ms）', AF_TIMEOUT_MS);
        if (rejectFn !== undefined) {
          rejectFn(new Error('网易云指纹计算超时'));
        }
      }, AF_TIMEOUT_MS);
    });
  }

  private mapItem(item: Record<string, Object>): RecognitionResult | undefined {
    const song: Object = item['song'];
    if (song === undefined) {
      return undefined;
    }
    const songRecord: Record<string, Object> = song as Record<string, Object>;
    const id: Object = songRecord['id'];
    const name: Object = songRecord['name'];
    if (id === undefined || name === undefined) {
      return undefined;
    }
    const artistsRaw: Object = songRecord['artists'];
    let artists: Array<Object> = artistsRaw as Array<Object>;
    if (artists === undefined) {
      artists = songRecord['ar'] as Array<Object>;
    }
    const names: Array<string> = [];
    if (artists !== undefined) {
      for (const artist of artists) {
        const artistRecord: Record<string, Object> = artist as Record<string, Object>;
        const artistName: Object = artistRecord['name'];
        if (artistName !== undefined) {
          names.push(artistName as string);
        }
      }
    }
    const albumRaw: Object = songRecord['album'];
    let albumName = '';
    let picUrl = '';
    if (albumRaw !== undefined && albumRaw !== null) {
      const albumRecord: Record<string, Object> = albumRaw as Record<string, Object>;
      const albumNameRaw: Object = albumRecord['name'];
      if (albumNameRaw !== undefined) {
        albumName = albumNameRaw as string;
      }
      const picRaw: Object = albumRecord['picUrl'];
      if (picRaw !== undefined) {
        picUrl = picRaw as string;
      }
    } else {
      const alRaw: Object = songRecord['al'];
      if (alRaw !== undefined && alRaw !== null) {
        const al: Record<string, Object> = alRaw as Record<string, Object>;
        const albumNameRaw: Object = al['name'];
        if (albumNameRaw !== undefined) {
          albumName = albumNameRaw as string;
        }
        const picRaw: Object = al['picUrl'];
        if (picRaw !== undefined) {
          picUrl = picRaw as string;
        }
      }
    }
    return RecognitionResult.create(name as string, names.join('、'), albumName, picUrl,
      `wy:${String(id)}`, Date.now());
  }

  // 生成 AFP 指纹并请求网易云识曲接口，返回最多 5 条候选
  async recognize(pcm: Int16Array): Promise<Array<RecognitionResult>> {
    const samples: Float32Array = this.resampleToFloat32(pcm);
    const limited: Float32Array = samples.slice(0, MAX_FP_SECONDS * TARGET_RATE);
    if (limited.length === 0) {
      return [];
    }
    const audioFP: string = await this.generateFingerprint(limited);
    const duration: string = (limited.length / TARGET_RATE).toFixed(3);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'AFP指纹长度=%{public}d duration=%{public}s', audioFP.length, duration);
    const url: string =
      `https://interface.music.163.com/api/music/audio/match?sessionId=0123456789abcdef` +
      `&algorithmCode=shazam_v2&duration=${duration}&rawdata=${encodeURIComponent(audioFP)}` +
      `&times=1&decrypt=1`;

    const httpRequest = http.createHttp();
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://music.163.com/',
      },
      connectTimeout: REQUEST_TIMEOUT_MS,
      readTimeout: REQUEST_TIMEOUT_MS,
      expectDataType: http.HttpDataType.STRING,
    };
    let response: http.HttpResponse;
    try {
      response = await httpRequest.request(url, options);
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, '网络请求异常: %{public}s', JSON.stringify(err));
      throw new RecognitionNetworkError('网易云听歌识曲网络请求失败');
    } finally {
      httpRequest.destroy();
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'HTTP status=%{public}d', response.responseCode);
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new RecognitionNetworkError(`网易云听歌识曲服务请求失败（${response.responseCode}）`);
    }
    const resultStr: string = response.result as string;
    hilog.info(LOG_DOMAIN, LOG_TAG, '响应原文(前200): %{public}s', resultStr.substring(0, 200));
    let parsed: Record<string, Object>;
    try {
      parsed = JSON.parse(resultStr) as Record<string, Object>;
    } catch (err) {
      throw new RecognitionNetworkError('网易云听歌识曲服务返回数据异常');
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'code=%{public}s', String(parsed['code']));
    if (parsed['code'] !== 200) {
      return [];
    }
    const dataRecord: Record<string, Object> = parsed['data'] as Record<string, Object>;
    if (dataRecord === undefined || dataRecord === null) {
      return [];
    }
    let items: Array<Object> = dataRecord['result'] as Array<Object>;
    if (items === undefined || items === null) {
      const nested: Record<string, Object> = dataRecord['data'] as Record<string, Object>;
      if (nested !== undefined && nested !== null) {
        items = nested['result'] as Array<Object>;
      }
    }
    if (items === undefined || items === null) {
      return [];
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, '候选条目数=%{public}d', items.length);
    const results: Array<RecognitionResult> = [];
    for (const item of items) {
      const mapped: RecognitionResult | undefined = this.mapItem(item as Record<string, Object>);
      if (mapped !== undefined) {
        results.push(mapped);
        hilog.info(LOG_DOMAIN, LOG_TAG, '命中候选: %{public}s - %{public}s id=%{public}s',
          mapped.title, mapped.artist, mapped.providerTrackId);
        if (results.length >= 5) {
          break;
        }
      }
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, '识别完成 结果数=%{public}d', results.length);
    return results;
  }

  private resampleToFloat32(pcm: Int16Array): Float32Array {
    const outSamples: number = Math.floor(pcm.length / 2);
    const out = new Float32Array(outSamples);
    for (let i = 0; i < outSamples; i++) {
      const a: number = pcm[i * 2];
      const b: number = i * 2 + 1 < pcm.length ? pcm[i * 2 + 1] : a;
      out[i] = (a + b) / 2 / 32768;
    }
    return out;
  }
}
