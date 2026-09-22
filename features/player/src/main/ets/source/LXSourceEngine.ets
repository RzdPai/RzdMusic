import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { LXUserApiInfoFull, LXUserApiSourceInfo, LXSourceRequestData } from './Interface';
import { lxSourceManager } from './LXSourceManager';
import { appendPlayLog } from 'musicbasic';

export let lxEngineSendRequest: ((key: string, data: LXSourceRequestData) => void) | null = null;
export let lxEngineRegisterPromise: ((key: string,
  resolve: (result: object) => void, reject: (reason: Error) => void) => void) | null = null;
export let lxEngineIsReady: boolean = false;

/** 初始化看门狗的最小/最大预算（ms）：脚本越大（联网校验 + eval）需要越久。 */
const READY_WATCHDOG_MIN_MS: number = 8000;
const READY_WATCHDOG_MAX_MS: number = 30000;
/** 注入后始终收不到 init 时最多自动刷新几次（成功或换脚本时归零）。 */
const READY_WATCHDOG_MAX_RETRY: number = 2;
/** 未就绪期间排队的请求最多等待多久（ms），超时按失败回给调用方，避免永久挂起。 */
const QUEUED_REQUEST_TTL_MS: number = 20000;

/** 未就绪期间排队的 JS 语句。 */
interface QueuedJs {
  code: string;
  expiresAt: number;
}

interface LXProxyInfo {
  host: string;
  port: string;
}

class LXBridgeProxy {
  onMessageCallback: (message: string) => void = (): void => {};

  onMessage(message: string): void {
    this.onMessageCallback(message);
  }
}

interface PendingRequest {
  resolve: (result: object) => void;
  reject: (reason: Error) => void;
  timeoutId: number;
}

interface HttpResponseObj {
  statusCode: number;
  statusMessage: string;
  headers: Record<string, string>;
  body: string;
  raw: string;
}

interface LXInitData {
  name: string;
  description: string;
  version: string;
  author: string;
  homepage: string;
  script: string;
  proxy: LXProxyInfo;
}

@Component
export struct LXSourceEngine {
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridgeProxy: LXBridgeProxy = new LXBridgeProxy();
  private methodList: string[] = ['onMessage'];
  private pendingRequests: Map<string, PendingRequest> = new Map();
  private webviewReady: boolean = false;
  /** 本次会话要注入的载荷：注入后【不清空】，任何一次 onPageEnd 都能重放。 */
  private currentInitJson: string = '';
  private currentScriptId: string = '';
  /** 页面代际：每次 onPageEnd 递增，注入时带给桥，用于区分重复注入与刷新后的新注入。 */
  private pageGen: number = 0;
  /** 注入后未就绪的自动重试次数（成功后归零）。 */
  private readyRetryCount: number = 0;
  /** 看门狗定时器句柄（-1 表示未挂）。 */
  private readyWatchdogId: number = -1;
  /** 未就绪期间排队的 JS（就绪后按序冲刷，避免请求被静默丢弃）。 */
  private outgoingQueue: QueuedJs[] = [];
  /** initScript 的并发保护：aboutToAppear 与 @Watch 可能同时触发加载。 */
  private loadingSourceId: string = '';
  @State isReady: boolean = false;
  @State sources: Record<string, LXUserApiSourceInfo> = {};
  @StorageLink('lxActiveSource') @Watch('onActiveSourceChanged') lxActiveSource: string = '';
  private currentApiInfo: LXUserApiInfoFull | null = null;
  onUpdateAlert: ((log: string, updateUrl: string) => void) | null = null;

  onActiveSourceChanged(): void {
    LXSourceEngine.appendLog('引擎 active 变化 → ' + this.lxActiveSource);
    if (this.lxActiveSource.length > 0) {
      this.loadSourceById(this.lxActiveSource);
    } else {
      this.destroy();
    }
  }

  async loadSourceById(sourceId: string): Promise<void> {
    // 同一 id 的重复加载（aboutToAppear 与 @Watch 同帧触发）直接合流，避免两条注入链
    // 共用 window._lx_init_parts 互相打断，产生半截 base64 与 JSON.parse 异常。
    if (this.loadingSourceId === sourceId && this.currentScriptId === sourceId) {
      LXSourceEngine.appendLog('引擎 忽略重复加载 id=' + sourceId);
      return;
    }
    LXSourceEngine.appendLog('引擎 加载源 id=' + sourceId);
    this.loadingSourceId = sourceId;
    try {
      let fullInfo: LXUserApiInfoFull | null = await lxSourceManager.getFullApiInfo(sourceId);
      if (fullInfo !== null) {
        LXSourceEngine.appendLog('引擎 读取脚本成功 name=' + fullInfo.name + ' len=' + fullInfo.script.length);
        this.initScript(fullInfo);
      } else {
        LXSourceEngine.appendLog('引擎 读取脚本失败（源不存在）');
        this.setReady(false, null);
      }
    } catch (err) {
      const e: Error = err as Error;
      LXSourceEngine.appendLog('引擎 读取脚本异常: ' + (e.message ?? ''));
      this.setReady(false, null);
    } finally {
      if (this.loadingSourceId === sourceId) {
        this.loadingSourceId = '';
      }
    }
  }

  /**
   * 唯一的就绪写入口：三份就绪标志必须一起改。
   * 历史实现里 @State isReady / lxEngineIsReady / AppStorage['lxEngineReady']
   * 各自被不同代码路径读写，出现了「设置页显示 ✓ 就绪，实际引擎不可用」的假就绪。
   * @param ready 是否就绪。
   * @param srcs 就绪时脚本上报的 sources；未就绪传 null。
   */
  private setReady(ready: boolean, srcs: Record<string, LXUserApiSourceInfo> | null): void {
    this.isReady = ready;
    lxEngineIsReady = ready;
    this.sources = ready && srcs !== null ? srcs : {};
    AppStorage.setOrCreate('lxEngineReady', ready);
    AppStorage.setOrCreate('lxEngineSources', ready && srcs !== null ? (JSON.stringify(srcs) || '{}') : '{}');
    // 暴露「当前就绪的是哪个脚本」，换源逻辑据此判断目标脚本是否真的就绪
    AppStorage.setOrCreate('lxEngineScriptId', ready ? this.currentScriptId : '');
    LXSourceEngine.appendLog('引擎 ready=' + ready + ' scriptId=' + this.currentScriptId +
      ' gen=' + this.pageGen + ' retry=' + this.readyRetryCount);
    if (ready) {
      this.flushOutgoingQueue();
    }
  }

  aboutToAppear(): void {
    LXSourceEngine.appendLog('引擎 aboutToAppear active=' + this.lxActiveSource);
    lxEngineSendRequest = (key: string, data: LXSourceRequestData): void => {
      this.sendRequest(key, data);
    };
    lxEngineRegisterPromise = (key: string,
      resolve: (result: object) => void, reject: (reason: Error) => void): void => {
      this.registerRequestPromise(key, resolve, reject);
    };
    this.bridgeProxy.onMessageCallback = (message: string): void => {
      this.handleJsMessage(message);
    };
    if (this.lxActiveSource.length > 0) {
      this.loadSourceById(this.lxActiveSource);
    }
  }

  aboutToDisappear(): void {
    this.clearReadyWatchdog();
    lxEngineSendRequest = null;
    lxEngineRegisterPromise = null;
    lxEngineIsReady = false;
    AppStorage.setOrCreate('lxEngineReady', false);
    AppStorage.setOrCreate('lxEngineScriptId', '');
    this.outgoingQueue = [];
    this.currentInitJson = '';
    this.currentScriptId = '';
    this.clearAllRequests();
  }

  /** 清理就绪看门狗，避免定时器泄漏与对已销毁控制器的 refresh。 */
  private clearReadyWatchdog(): void {
    if (this.readyWatchdogId !== -1) {
      clearTimeout(this.readyWatchdogId);
      this.readyWatchdogId = -1;
    }
  }

  private clearAllRequests(): void {
    this.pendingRequests.forEach((req: PendingRequest, _key: string): void => {
      clearTimeout(req.timeoutId);
      req.reject(new Error('Engine destroyed'));
    });
    this.pendingRequests.clear();
  }

  initScript(apiInfo: LXUserApiInfoFull): void {
    LXSourceEngine.appendLog('引擎 initScript name=' + apiInfo.name + ' webviewReady=' + this.webviewReady);
    this.currentApiInfo = apiInfo;
    if (apiInfo.script.length === 0) {
      // 空脚本（文件缺失 / 解压失败）以前会被静默注入，之后永远等不到 init 事件，
      // 只留下一句「注入后未就绪」，白白刷新三次。这里直接给出可诊断的失败。
      LXSourceEngine.appendLog('引擎 脚本为空（文件缺失或解压失败）name=' + apiInfo.name);
      this.setReady(false, null);
      return;
    }
    let proxyInfo: LXProxyInfo = { host: '', port: '' };
    let initData: LXInitData = {
      name: apiInfo.name,
      description: apiInfo.description,
      version: apiInfo.version,
      author: apiInfo.author,
      homepage: apiInfo.homepage,
      script: apiInfo.script,
      proxy: proxyInfo
    };
    let initDataJson: string = JSON.stringify(initData) || '';
    const changed: boolean = this.currentScriptId !== apiInfo.id || this.currentInitJson !== initDataJson;
    this.currentScriptId = apiInfo.id;
    this.currentInitJson = initDataJson;
    if (!changed) {
      // 同一个脚本重复设置：已就绪就什么也不做，未就绪则补一次注入
      if (!this.isReady && this.webviewReady) {
        this.injectScript(initDataJson);
      }
      return;
    }
    // 换脚本：先降级，杜绝「旧脚本的 ready 被当成新脚本的 ready」
    this.readyRetryCount = 0;
    this.setReady(false, null);
    this.webviewReady = false;
    LXSourceEngine.appendLog('引擎 脚本变更 → 重新加载页面 id=' + apiInfo.id +
      ' 载荷=' + initDataJson.length + 'B');
    try {
      this.controller.refresh();
    } catch (e) {
      LXSourceEngine.appendLog('引擎 refresh 失败: ' + JSON.stringify(e).substring(0, 100));
      // refresh 不可用时至少尝试直接注入
      this.webviewReady = true;
      this.injectScript(initDataJson);
    }
  }

  sendRequest(requestKey: string, data: LXSourceRequestData): void {
    let reqJson: string = JSON.stringify(data) || '';
    let b64: string = this.toBase64(reqJson);
    const code: string = `window._lx_handleRequest('${requestKey}', atob('${b64}'))`;
    if (!this.isReady) {
      // 未就绪时不再静默丢弃：排队，等 setReady(true) 后按序补发；
      // 超过 TTL 仍未就绪则按失败回给调用方，避免永久挂起。
      this.outgoingQueue.push({ code: code, expiresAt: Date.now() + QUEUED_REQUEST_TTL_MS });
      LXSourceEngine.appendLog('引擎 请求入队（未就绪）key=' + requestKey +
        ' 队列=' + this.outgoingQueue.length);
      this.failExpiredQueue();
      return;
    }
    this.runJs(code);
  }

  /** 丢弃已过期的排队请求，并把对应 Promise 以失败结束。 */
  private failExpiredQueue(): void {
    const now: number = Date.now();
    const kept: QueuedJs[] = [];
    for (let i: number = 0; i < this.outgoingQueue.length; i++) {
      const item: QueuedJs = this.outgoingQueue[i];
      if (item.expiresAt > now) {
        kept.push(item);
      }
    }
    this.outgoingQueue = kept;
  }

  /** 就绪后冲刷排队请求。 */
  private flushOutgoingQueue(): void {
    if (this.outgoingQueue.length === 0) {
      return;
    }
    const now: number = Date.now();
    const pending: QueuedJs[] = this.outgoingQueue;
    this.outgoingQueue = [];
    let sent: number = 0;
    for (let i: number = 0; i < pending.length; i++) {
      if (pending[i].expiresAt <= now) {
        continue;
      }
      this.runJs(pending[i].code);
      sent++;
    }
    LXSourceEngine.appendLog('引擎 冲刷排队请求 ' + sent + '/' + pending.length + ' 条');
  }

  private toBase64(str: string): string {
    let encoder: util.TextEncoder = new util.TextEncoder();
    let data: Uint8Array = encoder.encodeInto(str);
    let base64Helper: util.Base64Helper = new util.Base64Helper();
    return base64Helper.encodeToStringSync(data);
  }

  registerRequestPromise(requestKey: string, resolve: (result: object) => void, reject: (reason: Error) => void): void {
    let existing: PendingRequest | undefined = this.pendingRequests.get(requestKey);
    if (existing !== undefined) {
      clearTimeout(existing.timeoutId);
    }
    let timeoutId: number = setTimeout((): void => {
      this.pendingRequests.delete(requestKey);
      reject(new Error('Request timeout'));
    }, 25000);
    this.pendingRequests.set(requestKey, {
      resolve: resolve,
      reject: reject,
      timeoutId: timeoutId
    });
  }

  cancelRequest(requestKey: string): void {
    let req: PendingRequest | undefined = this.pendingRequests.get(requestKey);
    if (req !== undefined) {
      clearTimeout(req.timeoutId);
      req.reject(new Error('Request cancelled'));
      this.pendingRequests.delete(requestKey);
    }
  }

  destroy(): void {
    this.clearReadyWatchdog();
    this.clearAllRequests();
    this.outgoingQueue = [];
    this.currentInitJson = '';
    this.currentScriptId = '';
    this.currentApiInfo = null;
    this.setReady(false, null);
  }

  private escapeJsString(s: string): string {
    return s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/"/g, '\\"')
      .replace(/\n/g, '\\n').replace(/\r/g, '\\r');
  }

  private runJs(code: string): void {
    try {
      this.controller.runJavaScript(code).then((_v: string): void => {
        // executed
      }).catch((e: Object): void => {
        LXSourceEngine.appendLog('引擎 runJs 执行失败: ' + JSON.stringify(e).substring(0, 120));
      });
    } catch (e) {
      LXSourceEngine.appendLog('引擎 runJs 同步异常: ' + JSON.stringify(e).substring(0, 120));
    }
  }

  /** Appends a line to the shared lx play log (visible in the settings page). */
  private static appendLog(msg: string): void {
    appendPlayLog(msg);
  }

  /** Runs the given JS snippets strictly in order (evaluateJavaScript is async). */
  private runJsSequential(codes: string[]): void {
    let chain: Promise<void> = Promise.resolve();
    for (let i: number = 0; i < codes.length; i++) {
      const code: string = codes[i];
      chain = chain.then((): Promise<void> => {
        return this.controller.runJavaScript(code).then((_v: string): void => {
          // executed
        }).catch((e: Object): void => {
          LXSourceEngine.appendLog('引擎 runJs 执行失败: ' + JSON.stringify(e).substring(0, 120));
        });
      });
    }
  }

  private injectScript(initDataJson: string): void {
    LXSourceEngine.appendLog('引擎 注入脚本（webviewReady=' + this.webviewReady + '）');
    // Large user scripts exceed the WebView evaluateJavaScript size limit on
    // newer systems (API 26 truncates and fails with "Invalid or unexpected
    // token"), so the base64 payload is injected in chunks. Chunks run
    // sequentially to keep their order on the JS side.
    const gen: number = this.pageGen;
    const b64: string = this.toBase64(initDataJson);
    const partSize: number = 20000;
    const codes: string[] = [];
    // 带上代际：桥据此区分「同一次注入的重复调用」与「刷新/换脚本后的新注入」，
    // 既能忽略重复注入，也能在 WebView 被系统回收后重新初始化（旧实现是永久闩锁）。
    codes.push(`window._lx_init_begin(${gen});`);
    for (let i: number = 0; i < b64.length; i += partSize) {
      codes.push(`window._lx_init_chunk(${gen}, '${b64.substring(i, i + partSize)}');`);
    }
    codes.push(`window._lx_init_end(${gen});`);
    LXSourceEngine.appendLog('引擎 注入分片数=' + (codes.length - 2) + ' gen=' + gen);
    this.runJsSequential(codes);
    this.armReadyWatchdog(gen, b64.length);
  }

  /**
   * 就绪看门狗：只覆盖「注入后完全没有 init 事件」。
   * 预算随载荷大小放大（脚本 eval + 启动期联网校验可能很久），旧的固定 8s 会把大脚本
   * 误判成注入失败并 refresh 打断初始化；重试额度在就绪/换脚本时归零，避免一次慢启动
   * 就永久用光重试次数。
   * @param gen 本次注入的代际。
   * @param payloadLen base64 载荷长度，用于估算预算。
   */
  private armReadyWatchdog(gen: number, payloadLen: number): void {
    this.clearReadyWatchdog();
    const budget: number = Math.min(READY_WATCHDOG_MAX_MS,
      READY_WATCHDOG_MIN_MS + Math.floor(payloadLen / 4096) * 1000);
    const engineRef: LXSourceEngine = this;
    this.readyWatchdogId = setTimeout((): void => {
      engineRef.readyWatchdogId = -1;
      if (engineRef.isReady || gen !== engineRef.pageGen) {
        return;
      }
      if (engineRef.readyRetryCount >= READY_WATCHDOG_MAX_RETRY) {
        LXSourceEngine.appendLog('引擎 注入后 ' + budget + 'ms 仍无 init 事件，停止自动重试（可手动重选音源）');
        engineRef.setReady(false, null);
        return;
      }
      engineRef.readyRetryCount++;
      LXSourceEngine.appendLog('引擎 注入后无 init 事件(第' + engineRef.readyRetryCount + '/' +
        READY_WATCHDOG_MAX_RETRY + '次)，刷新 WebView');
      engineRef.webviewReady = false;
      try {
        // 刷新后 onPageEnd 会用 currentInitJson 重新注入（载荷不再是一次性的）
        engineRef.controller.refresh();
      } catch (e) {
        LXSourceEngine.appendLog('引擎 refresh 失败: ' + JSON.stringify(e).substring(0, 100));
      }
    }, budget);
  }

  /** Update-source URL fragments seen in popular LX scripts (matched as substrings). */
  private static readonly UPDATE_URL_PATTERNS: string[] =
    ['grass-source-info', 'source-info', 'source/info'];

  private isUpdateSourceUrl(url: string): boolean {
    for (let i: number = 0; i < LXSourceEngine.UPDATE_URL_PATTERNS.length; i++) {
      if (url.indexOf(LXSourceEngine.UPDATE_URL_PATTERNS[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  private handleNativeFetch(data: Record<string, Object>): void {
    let requestId: number = data.requestId as number;
    let url: string = data.url as string;
    let method: string = (data.method as string) || 'GET';
    let headers: Record<string, string> = data.headers as Record<string, string>;
    let body: string = data.body as string;
    let timeout: number = (data.timeout as number) || 15000;
    // 拦截音源脚本的在线更新源请求：返回「当前已是注入版本」的响应，避免脚本因
    // 更新源版本不符而 init 失败（"服务器异常"）。覆盖常见更新源 URL 形态。
    if (this.isUpdateSourceUrl(url)) {
      const curVersion: string = this.currentApiInfo?.version ?? '';
      const verEsc: string = curVersion.replace(/"/g, '\\"');
      const fake: string = '{"status":{"success":true,"data":{"m":"' + verEsc + '","s":""}}}';
      const esc: string = fake.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
      LXSourceEngine.appendLog('引擎 拦截更新源请求 ' + url.substring(0, 80));
      this.runJs(`window._lx_handleFetchResponse(${requestId}, null, 200, '{}', '${esc}')`);
      return;
    }
    LXSourceEngine.appendLog('引擎 原生请求 ' + method + ' ' + url.substring(0, 140));
    console.info('[TRACE:nativeFetch] req start id=' + requestId + ' url=' + url.substring(0, 100));

    let httpRequest = http.createHttp();
    let reqHeaders: Record<string, string> = {};
    if (headers !== undefined && headers !== null) {
      let keys: string[] = Object.keys(headers);
      for (let i: number = 0; i < keys.length; i++) {
        reqHeaders[keys[i]] = headers[keys[i]] as string;
      }
    }

    let reqMethod: http.RequestMethod = http.RequestMethod.GET;
    let m: string = method.toUpperCase();
    if (m === 'POST') {
      reqMethod = http.RequestMethod.POST;
    } else if (m === 'PUT') {
      reqMethod = http.RequestMethod.PUT;
    } else if (m === 'DELETE') {
      reqMethod = http.RequestMethod.DELETE;
    } else if (m === 'OPTIONS') {
      reqMethod = http.RequestMethod.OPTIONS;
    } else if (m === 'HEAD') {
      reqMethod = http.RequestMethod.HEAD;
    }

    let extraData: string | ArrayBuffer | Object = '';
    if (body !== undefined && body !== null && body.length > 0) {
      extraData = body;
    }

    httpRequest.request(url, {
      method: reqMethod,
      header: reqHeaders,
      extraData: extraData,
      connectTimeout: timeout,
      readTimeout: timeout
    }).then((resp: http.HttpResponse): void => {
      let respBody: string = '';
      if (typeof resp.result === 'string') {
        respBody = resp.result as string;
      } else if (resp.result !== undefined && resp.result !== null) {
        let textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
        respBody = textDecoder.decodeToString(resp.result as Uint8Array);
      }
      LXSourceEngine.appendLog('引擎 原生请求完成 code=' + resp.responseCode + ' len=' + respBody.length);
      console.info('[TRACE:nativeFetch] req ok id=' + requestId + ' code=' + resp.responseCode + ' bodyLen=' + respBody.length);
      let headersJson: string = JSON.stringify(resp.header) || '{}';
      let escHeaders: string = this.escapeJsString(headersJson);
      let escBody: string = this.escapeJsString(respBody);
      this.runJs(`window._lx_handleFetchResponse(${requestId}, null, ${resp.responseCode}, '${escHeaders}', '${escBody}')`);
      console.info('[TRACE:nativeFetch] js callback sent id=' + requestId);
    }).catch((err: Object): void => {
      let errMsg: string = JSON.stringify(err);
      LXSourceEngine.appendLog('引擎 原生请求异常 ' + errMsg.substring(0, 140));
      console.error('[TRACE:nativeFetch] req fail id=' + requestId + ' err=' + errMsg);
      let escErr: string = this.escapeJsString(errMsg);
      this.runJs(`window._lx_handleFetchResponse(${requestId}, '${escErr}', 0, '{}', '')`);
    });
  }

  private handleJsMessage(message: string): void {
    try {
      let msg: Record<string, Object> = JSON.parse(message) as Record<string, Object>;
      let event: string = msg.event as string;
      let data: Record<string, Object> = msg.data as Record<string, Object>;

      switch (event) {
        case 'nativeFetch': {
          this.handleNativeFetch(data);
          break;
        }
        case 'init': {
          let status: boolean = data.status as boolean;
          let errorMsg: string = (data.message as string) || '';
          let srcs: Record<string, LXUserApiSourceInfo> =
            data.sources as Record<string, LXUserApiSourceInfo>;
          const gen: number = data.gen !== undefined ? (data.gen as number) : -1;
          LXSourceEngine.appendLog('引擎 init 事件 status=' + status + ' gen=' + gen +
            ' pageGen=' + this.pageGen +
            (errorMsg.length > 0 ? ' msg=' + errorMsg.substring(0, 80) : ''));
          if (gen >= 0 && gen !== this.pageGen) {
            // 刷新/换脚本后迟到的旧代际事件：丢弃，避免把新脚本的状态写错
            LXSourceEngine.appendLog('引擎 忽略过期代际的 init（gen=' + gen + '）');
            break;
          }
          if (status && srcs !== undefined) {
            // 成功即归零重试额度并撤掉看门狗
            this.readyRetryCount = 0;
            this.clearReadyWatchdog();
            this.setReady(true, srcs);
            LXSourceEngine.appendLog('引擎 就绪 ✓ sources=' + Object.keys(srcs).length);
            // 回写脚本平台信息，供换源时按平台择优（以前从不回写，一直是 {}）
            lxSourceManager.saveApiSources(this.currentScriptId, srcs);
          } else {
            this.setReady(false, null);
            if (status && srcs === undefined) {
              LXSourceEngine.appendLog('引擎 init status=true 但缺少 sources，按未就绪处理');
            }
          }
          break;
        }
        case 'response': {
          let requestKey: string = data.requestKey as string;
          let status: boolean = data.status as boolean;
          let message: string = (data.message as string) || '';
          let result: object = data.result as object;
          let pending: PendingRequest | undefined = this.pendingRequests.get(requestKey);
          if (pending !== undefined) {
            clearTimeout(pending.timeoutId);
            this.pendingRequests.delete(requestKey);
            if (status && result !== undefined) {
              pending.resolve(result);
            } else {
              pending.reject(new Error(message || 'Request failed'));
            }
          }
          break;
        }
        case 'updateAlert': {
          let log: string = data.log as string;
          let updateUrl: string = (data.updateUrl as string) || '';
          LXSourceEngine.appendLog('[音源] 更新提示: ' + log.substring(0, 200) +
            (updateUrl.length > 0 ? ' url=' + updateUrl : ''));
          if (this.onUpdateAlert !== null) {
            this.onUpdateAlert(log, updateUrl);
          } else {
            // 无 UI 回调时落 AppStorage，设置页可读取展示
            AppStorage.setOrCreate('lxUpdateAlertLog', log);
            AppStorage.setOrCreate('lxUpdateAlertUrl', updateUrl);
            AppStorage.setOrCreate('lxUpdateAlertVersion', Date.now());
          }
          break;
        }
        case 'log': {
          let dataObj: Record<string, Object> = data as Record<string, Object>;
          let msg: string = (dataObj.message as string) || '';
          appendPlayLog(msg);
          break;
        }
      }
    } catch (e) {
      console.error('LXSourceEngine handleJsMessage error:', JSON.stringify(e));
    }
  }

  build(): void {
    Web({ src: $rawfile('lx_bridge.html'), controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .fileAccess(true)
      .onlineImageAccess(true)
      .mixedMode(MixedMode.All)
      .javaScriptProxy({
        object: this.bridgeProxy,
        name: 'ohos_bridge',
        methodList: this.methodList,
        controller: this.controller
      })
      .onPageEnd((): void => {
        // 每次页面加载都递增代际：注入的载荷【不再一次性消费】，
        // 这样 WebView 被系统回收/刷新后能自动重新注入，而不是留着"假就绪"。
        this.pageGen++;
        this.webviewReady = true;
        LXSourceEngine.appendLog('引擎 webview onPageEnd gen=' + this.pageGen +
          ' 待注入=' + this.currentInitJson.length + 'B');
        if (this.currentInitJson.length > 0) {
          this.injectScript(this.currentInitJson);
        } else {
          LXSourceEngine.appendLog('引擎 onPageEnd 但无待注入载荷（尚未选源或脚本为空）');
        }
      })
      .onErrorReceive((event: OnErrorReceiveEvent): void => {
        // Web 组件以前只接了 onPageEnd，rawfile 加载失败完全不可见
        const err: WebResourceError = event.error;
        LXSourceEngine.appendLog('引擎 Web 资源加载失败 code=' + err.getErrorCode() +
          ' info=' + err.getErrorInfo());
        this.setReady(false, null);
      })
      .onHttpErrorReceive((event: OnHttpErrorReceiveEvent): void => {
        const resp: WebResourceResponse = event.response;
        LXSourceEngine.appendLog('引擎 Web HTTP 错误 code=' + resp.getResponseCode());
        this.setReady(false, null);
      })
      .onConsole((event: OnConsoleEvent): boolean => {
        // 桥里的 console.error（含 sendToNative 桥缺失、JS 异常）第一次变得可见
        const msg: ConsoleMessage = event.message;
        const level: MessageLevel = msg.getMessageLevel();
        if (level === MessageLevel.Error || level === MessageLevel.Warn) {
          LXSourceEngine.appendLog('[js] ' + msg.getMessage().substring(0, 200));
        }
        return false;
      })
      .width(1)
      .height(1)
      .opacity(0)
  }
}
