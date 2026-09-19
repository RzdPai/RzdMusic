import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const SOURCE_SAMPLE_RATE = 48000;
const TARGET_SAMPLE_RATE = 16000;
const TARGET_SECONDS = 12;
const TARGET_SAMPLES = TARGET_SECONDS * TARGET_SAMPLE_RATE;
const DOWNSAMPLE_STEP = SOURCE_SAMPLE_RATE / TARGET_SAMPLE_RATE;
const DOMAIN = 0x0000;
const TAG = 'MicRecorder';

export class MicCancelledError extends Error {
  constructor() {
    super('mic capture cancelled');
    this.name = 'MicCancelledError';
  }
}

export class MicPermissionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MicPermissionError';
  }
}

// 麦克风采集：48kHz S16LE 单声道 -> 16kHz Float32 -> Int16 PCM（与 LX Music 识别链路一致）
export class MicRecorder {
  private capturer: audio.AudioCapturer | undefined = undefined;
  private chunks: Array<number> = [];
  private cancelled: boolean = false;
  private targetReached: boolean = false;
  private onProgressCb: ((progress: number) => void) | undefined = undefined;
  private finishResolve: ((samples: Int16Array) => void) | undefined = undefined;
  private finishReject: ((reason: Object) => void) | undefined = undefined;
  private watchdogTimer: number = -1;

  async capture(onProgress: (progress: number) => void): Promise<Int16Array> {
    this.chunks = [];
    this.cancelled = false;
    this.targetReached = false;
    this.onProgressCb = onProgress;
    this.finishResolve = undefined;
    this.finishReject = undefined;

    const options: audio.AudioCapturerOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW,
      },
      capturerInfo: {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0,
      },
    };

    let capturer: audio.AudioCapturer;
    try {
      capturer = await audio.createAudioCapturer(options);
    } catch (err) {
      const businessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'createAudioCapturer failed, code=%{public}d', businessError.code);
      if (businessError.code === 201) {
        throw new MicPermissionError('未获得麦克风权限');
      }
      throw new Error(`麦克风不可用（${businessError.code}）`);
    }
    this.capturer = capturer;
    hilog.info(DOMAIN, TAG, 'capturer created, state=%{public}d', capturer.state);

    return new Promise<Int16Array>((resolve: (value: Int16Array) => void, reject: (reason: Object) => void): void => {
      this.finishResolve = resolve;
      this.finishReject = reject;
      capturer.on('readData', (buffer: ArrayBuffer): void => {
        this.handleBuffer(buffer);
      });
      capturer.start().then((): void => {
        hilog.info(DOMAIN, TAG, 'capturer started, state=%{public}d', capturer.state);
        this.watchdogTimer = setTimeout((): void => {
          if (!this.targetReached && !this.cancelled && this.chunks.length === 0) {
            hilog.warn(DOMAIN, TAG, 'no audio data within watchdog window');
            this.forceFinishWithError('麦克风未产生音频数据，请检查模拟器/设备麦克风是否可用');
          }
        }, 4000);
      }).catch((err: BusinessError): void => {
        hilog.error(DOMAIN, TAG, 'capturer start failed, code=%{public}d', err.code);
        reject(new Error('麦克风启动失败'));
      });
    });
  }

  stop(): void {
    this.cancelled = true;
    clearTimeout(this.watchdogTimer);
    const capturer = this.capturer;
    if (capturer !== undefined) {
      try {
        capturer.off('readData');
      } catch (err) {
      }
      void capturer.stop().catch(() => {
      });
    }
    void this.finish();
  }

  static computeRms(samples: Int16Array): number {
    if (samples.length === 0) {
      return 0;
    }
    let sum = 0;
    for (let i = 0; i < samples.length; i++) {
      const v: number = samples[i] / 32768;
      sum += v * v;
    }
    return Math.sqrt(sum / samples.length);
  }

  private handleBuffer(buffer: ArrayBuffer): void {
    if (this.targetReached || this.cancelled) {
      return;
    }
    const dataView = new DataView(buffer);
    const sampleCount: number = buffer.byteLength / 2;
    for (let i = 0; i < sampleCount; i += DOWNSAMPLE_STEP) {
      this.chunks.push(dataView.getInt16(i * 2, true) / 32768);
    }
    if (this.onProgressCb !== undefined) {
      this.onProgressCb(Math.min(this.chunks.length / TARGET_SAMPLES, 1));
    }
    if (this.chunks.length >= TARGET_SAMPLES) {
      this.targetReached = true;
      hilog.info(DOMAIN, TAG, '采集完成 样本数=%{public}d（目标%{public}d）', this.chunks.length, TARGET_SAMPLES);
      void this.finish();
    }
  }

  private forceFinishWithError(message: string): void {
    clearTimeout(this.watchdogTimer);
    const reject = this.finishReject;
    this.finishReject = undefined;
    this.finishResolve = undefined;
    if (reject !== undefined) {
      reject(new Error(message));
    }
    this.cancelled = true;
    void this.finish();
  }

  private async finish(): Promise<void> {
    clearTimeout(this.watchdogTimer);
    const capturer = this.capturer;
    if (capturer !== undefined) {
      try {
        capturer.off('readData');
      } catch (err) {
      }
      try {
        await capturer.stop();
      } catch (err) {
      }
      try {
        await capturer.release();
      } catch (err) {
      }
      this.capturer = undefined;
    }
    const resolve = this.finishResolve;
    const reject = this.finishReject;
    if (this.cancelled) {
      if (reject !== undefined) {
        reject(new MicCancelledError());
      }
      return;
    }
    if (resolve !== undefined) {
      resolve(this.buildSamples());
    }
  }

  private buildSamples(): Int16Array {
    const total: number = Math.min(this.chunks.length, TARGET_SAMPLES);
    const out = new Int16Array(total);
    for (let i = 0; i < total; i++) {
      const value: number = this.chunks[i] * 32768;
      out[i] = Math.max(-32768, Math.min(32767, Math.round(value)));
    }
    hilog.info(DOMAIN, TAG, '输出PCM 样本数=%{public}d 时长=%{public}fs', out.length, out.length / TARGET_SAMPLE_RATE);
    return out;
  }
}
