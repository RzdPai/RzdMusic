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
  private pendingInitData: string = '';
  private reloadCount: number = 0;
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
    LXSourceEngine.appendLog('引擎 加载源 id=' + sourceId);
    let fullInfo: LXUserApiInfoFull | null = await lxSourceManager.getFullApiInfo(sourceId);
    if (fullInfo !== null) {
      LXSourceEngine.appendLog('引擎 读取脚本成功 name=' + fullInfo.name + ' len=' + fullInfo.script.length);
      this.initScript(fullInfo);
    } else {
      LXSourceEngine.appendLog('引擎 读取脚本失败（源不存在）');
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
    lxEngineSendRequest = null;
    lxEngineRegisterPromise = null;
    lxEngineIsReady = false;
    AppStorage.setOrCreate('lxEngineReady', false);
    this.clearAllRequests();
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
    this.pendingInitData = initDataJson;
    if (this.webviewReady) {
      this.injectScript(initDataJson);
    }
  }

  sendRequest(requestKey: string, data: LXSourceRequestData): void {
    let reqJson: string = JSON.stringify(data) || '';
    let b64: string = this.toBase64(reqJson);
    this.runJs(`window._lx_handleRequest('${requestKey}', atob('${b64}'))`);
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
    this.clearAllRequests();
    this.isReady = false;
    this.sources = {};
    this.currentApiInfo = null;
    lxEngineIsReady = false;
    AppStorage.setOrCreate('lxEngineReady', false);
    AppStorage.setOrCreate('lxEngineSources', '{}');
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
    const b64: string = this.toBase64(initDataJson);
    const partSize: number = 20000;
    const codes: string[] = [];
    codes.push(`window._lx_init_parts = [];`);
    for (let i: number = 0; i < b64.length; i += partSize) {
      codes.push(`window._lx_init_parts.push('${b64.substring(i, i + partSize)}');`);
    }
    codes.push(`window._lx_init(JSON.parse(decodeURIComponent(escape(atob(window._lx_init_parts.join(''))))));`);
    LXSourceEngine.appendLog('引擎 注入分片数=' + (codes.length - 2));
    this.runJsSequential(codes);
    const retryJson: string = initDataJson;
    const engineRef: LXSourceEngine = this;
    setTimeout((): void => {
      if (engineRef.isReady) {
        return;
      }
      if (engineRef.reloadCount < 3) {
        // 未就绪：刷新 WebView 重连宿主桥后可多次重试（重启场景更稳）。
        engineRef.reloadCount++;
        engineRef.webviewReady = false;
        engineRef.pendingInitData = retryJson;
        LXSourceEngine.appendLog('引擎 注入后未就绪(' + engineRef.reloadCount + '/3)，刷新 WebView');
        try {
          engineRef.controller.refresh();
        } catch (e) {
          LXSourceEngine.appendLog('引擎 refresh 失败: ' + JSON.stringify(e).substring(0, 100));
        }
      } else {
        LXSourceEngine.appendLog('引擎 多次刷新后仍未就绪，请重启应用');
      }
    }, 8000);
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
          LXSourceEngine.appendLog('引擎 init 事件 status=' + status +
            (errorMsg.length > 0 ? ' msg=' + errorMsg.substring(0, 80) : ''));
          if (status && srcs !== undefined) {
            this.isReady = true;
            this.sources = srcs;
            lxEngineIsReady = true;
            AppStorage.setOrCreate('lxEngineReady', true);
            AppStorage.setOrCreate('lxEngineSources', JSON.stringify(srcs) || '{}');
            LXSourceEngine.appendLog('引擎 就绪 ✓ sources=' + Object.keys(srcs).length);
          } else {
            this.isReady = false;
            this.sources = {};
            AppStorage.setOrCreate('lxEngineReady', false);
            AppStorage.setOrCreate('lxEngineSources', '{}');
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
        this.webviewReady = true;
        LXSourceEngine.appendLog('引擎 webview onPageEnd，待注入=' + (this.pendingInitData.length > 0));
        if (this.pendingInitData.length > 0) {
          this.injectScript(this.pendingInitData);
          this.pendingInitData = '';
        }
      })
      .width(1)
      .height(1)
      .opacity(0)
  }
}
