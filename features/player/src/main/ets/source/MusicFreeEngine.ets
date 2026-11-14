import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { lxSourceManager } from './LXSourceManager';
import { appendPlayLog } from 'musicbasic';

/**
 * MusicFree 插件引擎（隐藏 WebView）。
 *
 * 与 {@link LXSourceEngine} 是**两套独立运行时**：
 *   · LX 脚本要求 `window.lx` + `init/on(event)`，是「事件式」；
 *   · MusicFree 插件是 CommonJS 模块（`module.exports = { search, getMediaSource, ... }`），
 *     依赖 axios / crypto-js / cheerio 等七个库，是「函数式」。
 * 两者的 JS 兼容层完全不同，硬塞进一个页面只会互相污染，所以分开。
 *
 * 插件在 `rawfile/mf_env.js` 里跑：那套 shim 提供 CommonJS 加载器 + 七个库的原生实现
 * （axios 走原生 http 桥，cheerio 建在原生 DOM 上），已在 Node 侧用真实插件对齐验证。
 */

/** 插件是否已就绪（页面已注入且 `module.exports` 解析成功）。 */
export let mfEngineReady: boolean = false;
/** 当前就绪插件所属的音源 id。 */
export let mfEngineApiId: string = '';
/** 当前就绪插件声明的平台名（`platform` 字段，如「元力WY」）。 */
export let mfEnginePlatform: string = '';
/** 当前插件支持的方法名。 */
export let mfEngineMethods: string[] = [];

/** 宿主 → 引擎：请求加载某个音源对应的插件（从已落库的脚本读）。 */
export let mfEngineLoadPlugin: ((apiId: string) => void) | null = null;
/**
 * 宿主 → 引擎：直接注入一段插件脚本（不落库）。
 * 用于「导入前探测 platform」：那时脚本还没存，但必须先跑一次才知道平台名。
 */
export let mfEngineLoadScript: ((apiId: string, script: string) => void) | null = null;
/** 宿主 → 引擎：发起一次插件方法调用。 */
export let mfEngineSendCall: ((callId: string, method: string, argsJson: string) => void) | null = null;

interface MfPendingCall {
  resolve: (json: string) => void;
  reject: (reason: Error) => void;
  timeoutId: number;
}

interface MfProxy {
  onMessage(message: string): void;
}

/** 调用超时：插件内部可能串多个请求（搜索时常有二次请求），给足 25s。 */
const MF_CALL_TIMEOUT_MS: number = 25000;
/** 注入后等 `mfReady` 的预算。 */
const MF_READY_TIMEOUT_MS: number = 20000;
/** JS 分片大小（与 LX 引擎同一口径：API 26 单次注入过长会截断）。 */
const MF_CHUNK_SIZE: number = 20000;

class MfBridgeProxy implements MfProxy {
  callback: (message: string) => void = (): void => {};

  onMessage(message: string): void {
    this.callback(message);
  }
}

@Component
export struct MusicFreeEngine {
  private controller: webview.WebviewController = new webview.WebviewController();
  private proxy: MfBridgeProxy = new MfBridgeProxy();
  private methods: string[] = ['onMessage'];
  private pageGen: number = 0;
  private webReady: boolean = false;
  private pendingCalls: Map<string, MfPendingCall> = new Map();
  private currentApiId: string = '';
  private currentScriptB64: string = '';
  private loadingApiId: string = '';
  private readyTimerId: number = -1;

  aboutToAppear(): void {
    mfEngineLoadPlugin = (apiId: string): void => {
      this.loadPlugin(apiId);
    };
    mfEngineSendCall = (callId: string, method: string, argsJson: string): void => {
      this.sendCall(callId, method, argsJson);
    };
    mfEngineLoadScript = (apiId: string, script: string): void => {
      this.loadScript(apiId, script);
    };
    mfEngineRegisterCall = (callId: string, resolve: (json: string) => void,
      reject: (reason: Error) => void): void => {
      this.registerCall(callId, resolve, reject);
    };
    this.proxy.callback = (message: string): void => {
      this.handleJsMessage(message);
    };
  }

  aboutToDisappear(): void {
    mfEngineLoadPlugin = null;
    mfEngineSendCall = null;
    mfEngineLoadScript = null;
    this.clearReadyTimer();
    this.pendingCalls.forEach((req: MfPendingCall, _key: string): void => {
      clearTimeout(req.timeoutId);
      req.reject(new Error('MusicFree engine destroyed'));
    });
    this.pendingCalls.clear();
    mfEngineReady = false;
    mfEngineApiId = '';
    mfEnginePlatform = '';
    mfEngineMethods = [];
  }

  private static log(msg: string): void {
    appendPlayLog('[mf] ' + msg);
  }

  private clearReadyTimer(): void {
    if (this.readyTimerId !== -1) {
      clearTimeout(this.readyTimerId);
      this.readyTimerId = -1;
    }
  }

  /** 登记一次待完成调用：超时按失败回，避免 Promise 永久挂起。 */
  private registerCall(callId: string, resolve: (json: string) => void,
    reject: (reason: Error) => void): void {
    const existing: MfPendingCall | undefined = this.pendingCalls.get(callId);
    if (existing !== undefined) {
      clearTimeout(existing.timeoutId);
    }
    const timeoutId: number = setTimeout((): void => {
      this.pendingCalls.delete(callId);
      reject(new Error('插件调用超时'));
    }, MF_CALL_TIMEOUT_MS);
    this.pendingCalls.set(callId, { resolve: resolve, reject: reject, timeoutId: timeoutId });
  }

  /** 加载（或复用）某个音源的插件脚本。 */
  private loadPlugin(apiId: string): void {
    if (apiId.length === 0) {
      return;
    }
    if (this.currentApiId === apiId && mfEngineReady) {
      return;
    }
    if (this.loadingApiId === apiId) {
      return;
    }
    this.loadingApiId = apiId;
    MusicFreeEngine.log('加载插件 id=' + apiId);
    lxSourceManager.getScript(apiId).then((script: string): void => {
      this.loadingApiId = '';
      if (script.length === 0) {
        MusicFreeEngine.log('脚本为空 id=' + apiId);
        this.failPending(new Error('插件脚本为空'));
        return;
      }
      this.loadScript(apiId, script);
    }).catch((err: Error): void => {
      this.loadingApiId = '';
      MusicFreeEngine.log('读取脚本异常: ' + (err.message ?? ''));
      this.failPending(err);
    });
  }

  /**
   * 注入一段插件脚本（不经过存储）。
   * @param apiId 逻辑 id（探测时可用 `__probe__`）
   * @param script 脚本原文
   */
  private loadScript(apiId: string, script: string): void {
    const b64: string = this.toBase64(script);
    const changed: boolean = this.currentApiId !== apiId || this.currentScriptB64 !== b64;
    this.currentApiId = apiId;
    this.currentScriptB64 = b64;
    mfEngineApiId = apiId;
    mfEngineReady = false;
    mfEnginePlatform = '';
    AppStorage.setOrCreate('mfEngineReady', false);
    if (!changed && this.webReady) {
      this.injectPlugin();
      return;
    }
    if (!this.webReady) {
      // 页面还没加载完：onPageEnd 会拿 currentScriptB64 注入
      MusicFreeEngine.log('页面未就绪，等 onPageEnd 注入 id=' + apiId);
      this.currentApiId = apiId;
      return;
    }
    // 换插件：重载页面，确保上一份插件的全局状态（模块缓存 / 闭包变量）不残留
    this.webReady = false;
    try {
      this.controller.refresh();
    } catch (e) {
      MusicFreeEngine.log('refresh 失败，直接注入');
      this.webReady = true;
      this.injectPlugin();
    }
  }

  private injectPlugin(): void {
    if (this.currentScriptB64.length === 0) {
      return;
    }
    const gen: number = this.pageGen;
    const b64: string = this.currentScriptB64;
    const codes: string[] = [];
    codes.push(`window._mf_begin(${gen});`);
    for (let i: number = 0; i < b64.length; i += MF_CHUNK_SIZE) {
      codes.push(`window._mf_chunk(${gen}, '${b64.substring(i, i + MF_CHUNK_SIZE)}');`);
    }
    codes.push(`window._mf_end(${gen});`);
    MusicFreeEngine.log('注入插件 gen=' + gen + ' 分片=' + (codes.length - 2) + ' 长度=' + b64.length);
    this.runSequential(codes);
    this.armReadyTimer(gen);
  }

  /** 注入后迟迟没有 mfReady：报错而不是静默卡死。 */
  private armReadyTimer(gen: number): void {
    this.clearReadyTimer();
    const self: MusicFreeEngine = this;
    this.readyTimerId = setTimeout((): void => {
      self.readyTimerId = -1;
      if (mfEngineReady || gen !== self.pageGen) {
        return;
      }
      MusicFreeEngine.log('注入后 ' + MF_READY_TIMEOUT_MS + 'ms 未就绪');
      self.failPending(new Error('MusicFree 插件加载超时'));
    }, MF_READY_TIMEOUT_MS);
  }

  private failPending(err: Error): void {
    this.pendingCalls.forEach((req: MfPendingCall, _key: string): void => {
      clearTimeout(req.timeoutId);
      req.reject(err);
    });
    this.pendingCalls.clear();
  }

  private toBase64(str: string): string {
    const encoder: util.TextEncoder = new util.TextEncoder();
    const data: Uint8Array = encoder.encodeInto(str);
    const helper: util.Base64Helper = new util.Base64Helper();
    return helper.encodeToStringSync(data);
  }

  private escapeJs(s: string): string {
    return s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\n/g, '\\n').replace(/\r/g, '\\r');
  }

  private runSequential(codes: string[]): void {
    let chain: Promise<void> = Promise.resolve();
    for (let i: number = 0; i < codes.length; i++) {
      const code: string = codes[i];
      chain = chain.then((): Promise<void> => {
        return this.controller.runJavaScript(code).then((_v: string): void => {
        }).catch((e: Object): void => {
          MusicFreeEngine.log('runJs 失败: ' + JSON.stringify(e).substring(0, 120));
        });
      });
    }
  }

  private sendCall(callId: string, method: string, argsJson: string): void {
    if (!mfEngineReady) {
      const req: MfPendingCall | undefined = this.pendingCalls.get(callId);
      if (req !== undefined) {
        clearTimeout(req.timeoutId);
        this.pendingCalls.delete(callId);
        req.reject(new Error('插件未就绪'));
      }
      return;
    }
    const code: string = `window._mf_call('${callId}', '${this.escapeJs(method)}', '${this.escapeJs(argsJson)}')`;
    try {
      this.controller.runJavaScript(code).catch((e: Object): void => {
        MusicFreeEngine.log('调用失败: ' + JSON.stringify(e).substring(0, 100));
      });
    } catch (e) {
      MusicFreeEngine.log('调用同步异常');
    }
  }

  private handleJsMessage(message: string): void {
    try {
      const msg: Record<string, Object> = JSON.parse(message) as Record<string, Object>;
      const event: string = msg.event as string;
      const data: Record<string, Object> = (msg.data ?? {}) as Record<string, Object>;
      if (event === 'nativeFetch') {
        this.handleNativeFetch(data);
        return;
      }
      if (event === 'log') {
        const text: string = (data.message as string) ?? '';
        if (text.length > 0) {
          appendPlayLog(text);
        }
        return;
      }
      if (event === 'mfReady') {
        const gen: number = data.gen !== undefined ? data.gen as number : -1;
        if (gen >= 0 && gen !== this.pageGen) {
          return;
        }
        const ok: boolean = data.ok as boolean;
        if (!ok) {
          MusicFreeEngine.log('就绪失败: ' + ((data.error as string) ?? ''));
          mfEngineReady = false;
          this.failPending(new Error('插件加载失败'));
          return;
        }
        const meta: Record<string, Object> = (data.meta ?? {}) as Record<string, Object>;
        mfEnginePlatform = (meta.platform as string) ?? '';
        mfEngineReady = true;
        const list: string[] = [];
        const rawMethods: Object = meta.methods;
        if (rawMethods !== undefined && rawMethods !== null && Array.isArray(rawMethods)) {
          const arr: string[] = rawMethods as string[];
          for (let i: number = 0; i < arr.length; i++) {
            list.push(arr[i]);
          }
        }
        mfEngineMethods = list;
        this.clearReadyTimer();
        MusicFreeEngine.log('就绪 ✓ platform=' + mfEnginePlatform + ' 方法=' + list.length);
        AppStorage.setOrCreate('mfEngineReady', true);
        AppStorage.setOrCreate('mfEnginePlatform', mfEnginePlatform);
        return;
      }
      if (event === 'mfResult') {
        const callId: string = data.callId as string;
        const req: MfPendingCall | undefined = this.pendingCalls.get(callId);
        if (req === undefined) {
          return;
        }
        clearTimeout(req.timeoutId);
        this.pendingCalls.delete(callId);
        const ok: boolean = data.ok as boolean;
        if (ok) {
          req.resolve((data.result as string) ?? 'null');
        } else {
          req.reject(new Error((data.error as string) ?? '插件调用失败'));
        }
      }
    } catch (e) {
      MusicFreeEngine.log('消息解析失败');
    }
  }

  /**
   * 插件内的网络请求走原生 http（与 LX 引擎同一套）。
   * WebView 里直接 fetch 会被 CORS 拦，插件也不可能去配跨域头。
   */
  private handleNativeFetch(data: Record<string, Object>): void {
    const requestId: number = data.requestId as number;
    const url: string = data.url as string;
    const method: string = (data.method as string) || 'GET';
    const headers: Record<string, string> = (data.headers ?? {}) as Record<string, string>;
    const body: string = (data.body as string) ?? '';
    const timeout: number = (data.timeout as number) || 15000;
    const reqHeaders: Record<string, string> = {};
    const keys: string[] = Object.keys(headers);
    for (let i: number = 0; i < keys.length; i++) {
      reqHeaders[keys[i]] = headers[keys[i]] as string;
    }
    let reqMethod: http.RequestMethod = http.RequestMethod.GET;
    const m: string = method.toUpperCase();
    if (m === 'POST') {
      reqMethod = http.RequestMethod.POST;
    } else if (m === 'PUT') {
      reqMethod = http.RequestMethod.PUT;
    } else if (m === 'DELETE') {
      reqMethod = http.RequestMethod.DELETE;
    } else if (m === 'HEAD') {
      reqMethod = http.RequestMethod.HEAD;
    }
    const httpRequest: http.HttpRequest = http.createHttp();
    const options: http.HttpRequestOptions = {
      method: reqMethod,
      header: reqHeaders,
      connectTimeout: timeout,
      readTimeout: timeout
    };
    if (body.length > 0) {
      options.extraData = body;
    }
    httpRequest.request(url, options).then((resp: http.HttpResponse): void => {
      let text: string = '';
      if (typeof resp.result === 'string') {
        text = resp.result as string;
      } else if (resp.result !== undefined && resp.result !== null) {
        const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
        text = decoder.decodeToString(resp.result as Uint8Array);
      }
      const headerJson: string = JSON.stringify(resp.header) || '{}';
      this.replyFetch(requestId, '', resp.responseCode, headerJson, text);
      try {
        httpRequest.destroy();
      } catch (e) {
        // ignore
      }
    }).catch((err: Object): void => {
      this.replyFetch(requestId, JSON.stringify(err), 0, '{}', '');
      try {
        httpRequest.destroy();
      } catch (e) {
        // ignore
      }
    });
  }

  private replyFetch(requestId: number, errJson: string, code: number, headersJson: string,
    body: string): void {
    const errArg: string = errJson.length > 0 ? `'${this.escapeJs(errJson)}'` : 'null';
    const code2: string = `window._mf_fetch_response(${requestId}, ${errArg}, ${code}, '${
      this.escapeJs(headersJson)}', '${this.escapeJs(body)}')`;
    try {
      this.controller.runJavaScript(code2).catch((_e: Object): void => {
      });
    } catch (e) {
      // ignore
    }
  }

  build(): void {
    Web({ src: $rawfile('mf_runtime.html'), controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .fileAccess(true)
      .mixedMode(MixedMode.All)
      .javaScriptProxy({
        object: this.proxy,
        name: 'ohos_bridge',
        methodList: this.methods,
        controller: this.controller
      })
      .onPageEnd((): void => {
        this.pageGen++;
        this.webReady = true;
        MusicFreeEngine.log('页面就绪 gen=' + this.pageGen);
        if (this.currentScriptB64.length > 0) {
          this.injectPlugin();
        }
      })
      .onErrorReceive((event: OnErrorReceiveEvent): void => {
        const err: WebResourceError = event.error;
        MusicFreeEngine.log('资源加载失败 code=' + err.getErrorCode());
      })
      .onConsole((event: OnConsoleEvent): boolean => {
        const msg: ConsoleMessage = event.message;
        const level: MessageLevel = msg.getMessageLevel();
        if (level === MessageLevel.Error) {
          appendPlayLog('[mf-js] ' + msg.getMessage().substring(0, 200));
        }
        return false;
      })
      .width(1)
      .height(1)
      .opacity(0)
  }
}

/**
 * 让插件就绪（幂等）。已经就绪的同一插件直接返回 true。
 * @param apiId 音源 id
 * @param timeoutMs 等待上限
 */
export async function ensureMfReady(apiId: string, timeoutMs: number = MF_READY_TIMEOUT_MS): Promise<boolean> {
  if (mfEngineReady && mfEngineApiId === apiId) {
    return true;
  }
  // 引擎宿主（LXSourceHost）可能还没挂载完 —— 启动后立刻搜索 MusicFree 平台时
  // `mfEngineLoadPlugin` 还是 null，直接返回 false 会让用户以为"这个平台没源"。
  // 先等一小会儿（宿主是常驻组件，通常 1~2 帧内就绪）。
  const mountDeadline: number = Date.now() + 4000;
  while (mfEngineLoadPlugin === null && Date.now() < mountDeadline) {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout((): void => resolve(), 120);
    });
  }
  if (mfEngineLoadPlugin === null) {
    return false;
  }
  mfEngineLoadPlugin(apiId);
  return await waitMfReady(apiId, timeoutMs);
}

/**
 * 只等（不触发加载）。给「自己注入脚本」的调用方用（例如导入前探测 platform）。
 * @param apiId 期望就绪的插件 id
 * @param timeoutMs 等待上限
 */
export async function waitMfReady(apiId: string, timeoutMs: number = MF_READY_TIMEOUT_MS): Promise<boolean> {
  const step: number = 100;
  let waited: number = 0;
  while (waited < timeoutMs) {
    if (mfEngineReady && mfEngineApiId === apiId) {
      return true;
    }
    await new Promise<void>((resolve: () => void): void => {
      setTimeout((): void => resolve(), step);
    });
    waited += step;
  }
  return mfEngineReady && mfEngineApiId === apiId;
}

/**
 * 调用插件方法。
 * @param method `search` / `getMediaSource` / `getLyric` ...
 * @param args 按插件签名顺序的参数
 * @returns 插件返回值的 JSON 字符串（调用方自行反序列化）
 */
export async function mfCall(method: string, args: Object[]): Promise<string> {
  if (!mfEngineReady || mfEngineSendCall === null) {
    throw new Error('MusicFree 插件未就绪');
  }
  if (mfEngineMethods.indexOf(method) < 0) {
    throw new Error('插件不支持 ' + method);
  }
  const callId: string = 'mf_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8);
  const argsJson: string = JSON.stringify(args) ?? '[]';
  return new Promise<string>((resolve: (json: string) => void, reject: (reason: Error) => void): void => {
    const send: (callId: string, method: string, argsJson: string) => void = mfEngineSendCall!;
    mfEngineRegisterCall(callId, resolve, reject);
    send(callId, method, argsJson);
  });
}

/**
 * 注册待完成的调用。真正持有 pendingCalls 的是组件实例，
 * 这里通过全局钩子把「注册」暴露给模块级函数（与 LX 引擎的 lxEngineRegisterPromise 同构）。
 */
export let mfEngineRegisterCall: (callId: string,
  resolve: (json: string) => void, reject: (reason: Error) => void) => void =
  (_callId: string, _resolve: (json: string) => void, _reject: (reason: Error) => void): void => {
    _reject(new Error('MusicFree engine not mounted'));
  };
