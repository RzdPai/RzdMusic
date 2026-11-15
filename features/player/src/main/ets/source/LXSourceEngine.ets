import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { LXUserApiInfoFull, LXUserApiSourceInfo, LXSourceRequestData } from './Interface';
import { lxSourceManager } from './LXSourceManager';
import {AppStorageKeys, 
  appendPlayLog, MusicStoreService,
  scriptAlertUrlKey, scriptAlertLogKey, scriptAlertAtKey,
  scriptBlockedAtKey, scriptBlockedUrlKey, scriptAllowKey,
  KEY_ALERT_LOG, KEY_ALERT_URL, KEY_ALERT_AT, KEY_ALERT_OWNER,
  KEY_BLOCKED_LOG, KEY_BLOCKED_URL
} from 'musicbasic';
import { ScriptProfile, probeScript, formatProfile, canRunWithoutWebView } from './ScriptProbe';

export let lxEngineSendRequest: ((key: string, data: LXSourceRequestData) => void) | null = null;
export let lxEngineRegisterPromise: ((key: string,
  resolve: (result: object) => void, reject: (reason: Error) => void) => void) | null = null;
export let lxEngineIsReady: boolean = false;

/**
 * 等待音源引擎就绪（最多 `timeoutMs`）。
 * ★ 用于消掉"刚启动就播 → 引擎还没 ready → 误弹『音源未就绪』"：先等一下，超时才提示。
 */
export async function waitForLxEngineReady(timeoutMs: number = 3000): Promise<boolean> {
  if (lxEngineIsReady) {
    return true;
  }
  const step: number = 100;
  let waited: number = 0;
  while (waited < timeoutMs) {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout((): void => resolve(), step);
    });
    if (lxEngineIsReady) {
      return true;
    }
    waited += step;
  }
  return lxEngineIsReady;
}

/** 初始化看门狗的最小/最大预算（ms）：脚本越大（联网校验 + eval）需要越久。 */
const READY_WATCHDOG_MIN_MS: number = 8000;
const READY_WATCHDOG_MAX_MS: number = 30000;
/** 注入后始终收不到 init 时最多自动刷新几次（成功或换脚本时归零）。 */
const READY_WATCHDOG_MAX_RETRY: number = 2;
/** 未就绪期间排队的请求最多等待多久（ms），超时按失败回给调用方，避免永久挂起。 */
const QUEUED_REQUEST_TTL_MS: number = 20000;

/**
 * 快通道注入的载荷地址。
 * 主机名是刻意不存在的 `.invalid`（RFC 2606 保留顶级域）：请求绝不会真的出网，
 * 一律由 Web 组件的 onInterceptRequest 在应用内应答。
 */
const LX_INIT_URL: string = 'https://rzd-lx-init.invalid/init.json';

/**
 * 快通道「载荷是否到手」的确认预算（ms）。
 * 桥拿到整包后会**先回 `initFetchAck` 再解析**，所以这个计时只覆盖「通道本身通不通」。
 * ★ 绝不能拿它判断「脚本是否初始化完成」：脚本自身的启动期联网校验可能要好几秒，
 *   误判会触发第二次注入（`_lx_init` 同代际重入会重置状态），把正常启动打断
 *   —— 这正是历史遗留的「冷启动脚本双注入」问题的成因。
 */
const INIT_FETCH_ACK_MS: number = 1500;

/**
 * 快通道失败后允许自动回退分片的次数上限。
 * 分片通道是既有可用行为，回退一次就够；不设上限会在通道性故障时反复重灌 1.6 MB。
 */
const INIT_FALLBACK_MAX: number = 2;

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
  /**
   * Web 控制器是否已绑定到 Web 组件（由 onControllerAttached 置真）。
   * ★ 官方约束：「在此回调之前不要调用 Web 组件相关 API，否则抛 js-error 异常」
   *   —— 冷启动时 aboutToAppear 早于控制器绑定，此时 refresh()/runJavaScript()
   *   会抛 17100001。以前是 catch 住了但顺带白注入一次，现在先判这个标志。
   */
  private controllerAttached: boolean = false;
  /** 本次注入的起始时刻（ms），用于统计 injectMs（冷启动注入耗时的唯一可信指标）。 */
  private injectStartedAt: number = 0;
  /** 已收到快通道 `initFetchAck` 的代际；等于本次注入代际时禁止再回退分片。 */
  private fetchAckGen: number = -1;
  /** 快通道 ack 计时器句柄（-1 表示未挂）。 */
  private fetchAckTimerId: number = -1;
  /** 已回退分片的次数（换脚本时归零）。 */
  private fallbackCount: number = 0;
  /** 已对哪一代际回退过分片（一代际只允许一次，换脚本/刷新后由新代际自然覆盖）。 */
  private fallbackGen: number = -1;
  /** 看门狗判定「注入后完全没有 init」后把本次会话钉在分片通道（换脚本时解除）。 */
  private pinChunked: boolean = false;
  /** 当前脚本的能力画像（Phase 0 只打日志；Phase 1 起据它决定能否离开 WebView）。 */
  private scriptProfile: ScriptProfile = {
    needsDom: false, needsWebCrypto: false, needsCompression: false, reason: ''
  };
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
      if (fullInfo !== null && fullInfo.kind === 'mf') {
        // MusicFree 插件由 MusicFreeEngine 负责，塞进 LX 桥只会 init 失败
        LXSourceEngine.appendLog('引擎 跳过 MusicFree 插件 id=' + sourceId + '（走 mf 运行时）');
        this.setReady(false, null);
        return;
      }
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
    AppStorage.setOrCreate(AppStorageKeys.LX_ENGINE_READY, ready);
    AppStorage.setOrCreate(AppStorageKeys.LX_ENGINE_SOURCES, ready && srcs !== null ? (JSON.stringify(srcs) || '{}') : '{}');
    // 暴露「当前就绪的是哪个脚本」，换源逻辑据此判断目标脚本是否真的就绪
    AppStorage.setOrCreate(AppStorageKeys.LX_ENGINE_SCRIPT_ID, ready ? this.currentScriptId : '');
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
    this.controllerAttached = false;
    this.clearReadyWatchdog();
    this.clearFetchAckWatch();
    lxEngineSendRequest = null;
    lxEngineRegisterPromise = null;
    lxEngineIsReady = false;
    AppStorage.setOrCreate(AppStorageKeys.LX_ENGINE_READY, false);
    AppStorage.setOrCreate(AppStorageKeys.LX_ENGINE_SCRIPT_ID, '');
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
    // Phase 0：只探测并打日志（先收集真实分布，再决定 QuickJS 值不值得做）。
    // 探测是纯文本扫描（十几条 indexOf），1.6 MB 脚本毫秒级，可放在装载路径上；
    // 本阶段三种开关取值的行为仍是同一个 ArkWeb 引擎，探测结果不参与路由。
    this.scriptProfile = probeScript(apiInfo.script);
    const profileText: string = formatProfile(this.scriptProfile);
    const canQuick: boolean = canRunWithoutWebView(this.scriptProfile);
    LXSourceEngine.appendLog('引擎 脚本能力 ' + profileText +
      ' 可无 DOM 运行=' + canQuick + ' lxEngineMode=' + this.lxEngineMode());
    // 落 AppStorage：设置页/诊断可直接显示，也免得以后为了看一眼再探测一遍
    AppStorage.setOrCreate(AppStorageKeys.LX_SCRIPT_PROFILE, profileText);
    AppStorage.setOrCreate(AppStorageKeys.LX_SCRIPT_NEEDS_DOM, this.scriptProfile.needsDom);
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
    // 回退额度按脚本重置：新脚本值得一次完整的快通道尝试
    this.fallbackCount = 0;
    this.pinChunked = false;
    this.clearFetchAckWatch();
    this.setReady(false, null);
    this.webviewReady = false;
    LXSourceEngine.appendLog('引擎 脚本变更 → 重新加载页面 id=' + apiInfo.id +
      ' 载荷=' + initDataJson.length + 'B');
    if (!this.controllerAttached) {
      // 控制器还没绑定（冷启动 aboutToAppear 早于 Web 组件挂载）：
      // 此时调 refresh/runJavaScript 必抛 17100001，注入也必然落空。
      // 载荷已存在 currentInitJson 里，等 onPageEnd 注入即可。
      LXSourceEngine.appendLog('引擎 控制器未绑定 → 等 onPageEnd 注入 id=' + apiInfo.id);
      return;
    }
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
    this.controllerAttached = false;
    this.clearReadyWatchdog();
    this.clearFetchAckWatch();
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

  /**
   * 注入入口：决定走快通道还是分片通道。
   *
   * 快通道（默认）：只发一条极短 JS 让桥自己 fetch，载荷由 {@link handleInterceptRequest}
   * 一次性返回原始 JSON —— 1 次跨进程往返替代 114 次，且不再 base64（省 33% 体积）。
   * 分片通道：今天的既有行为，作为强制回退档与自动兜底，逻辑一字未改。
   *
   * @param initDataJson 注入载荷（JSON 文本）。
   */
  private injectScript(initDataJson: string): void {
    const gen: number = this.pageGen;
    this.injectStartedAt = Date.now();
    this.fetchAckGen = -1;
    this.clearFetchAckWatch();
    if (initDataJson.length === 0) {
      LXSourceEngine.appendLog('引擎 注入跳过（空载荷）gen=' + gen);
      return;
    }
    if (this.isFastInjectEnabled()) {
      this.injectScriptFast(gen, initDataJson);
    } else {
      LXSourceEngine.appendLog('引擎 注入通道=chunked（设置强制回退）gen=' + gen);
      this.injectScriptChunked(gen, initDataJson);
    }
  }

  /**
   * 快通道是否可用。默认可用；设置里把注入通道强制成 `chunked` 时停用
   * —— 这是「快通道在真机上出问题、但不想等新包」时的逃生口。
   * @returns 允许走快通道时为 true。
   */
  private isFastInjectEnabled(): boolean {
    if (this.pinChunked) {
      return false;
    }
    try {
      return MusicStoreService.getInstance().getLxInjectMode() !== 'chunked';
    } catch (e) {
      // 读设置失败按可用处理：快通道自身有自动回退，不必因存储异常降级
      return true;
    }
  }

  /**
   * 读取音源运行时开关（auto / webview / quickjs）。
   * Phase 0 只用于打日志：本阶段三种取值的行为都还是 ArkWeb，QuickJS 未接入。
   * @returns 开关值；读取失败回落 auto。
   */
  private lxEngineMode(): string {
    try {
      return MusicStoreService.getInstance().getLxEngineMode();
    } catch (e) {
      return 'auto';
    }
  }

  /**
   * 快通道：让桥去 fetch 整包载荷。
   * @param gen 本次代际。
   * @param initDataJson 载荷（此处只为了打长度日志与兜底重灌）。
   */
  private injectScriptFast(gen: number, initDataJson: string): void {
    try {
      this.runJs(`window._lx_init_fetch(${gen})`);
      LXSourceEngine.appendLog('引擎 注入(快通道) gen=' + gen + ' 载荷=' + initDataJson.length + 'B');
      this.armFetchAckWatch(gen, initDataJson);
      this.armReadyWatchdog(gen, initDataJson.length);
    } catch (e) {
      LXSourceEngine.appendLog('引擎 快通道发起异常 → 分片: ' + JSON.stringify(e).substring(0, 100));
      this.fallbackToChunks(gen, initDataJson, '发起异常');
    }
  }

  /**
   * 分片通道（原有实现，保持逐字不变）。
   * 大脚本会超过 WebView evaluateJavaScript 的入参上限（API 26 会截断并报
   * "Invalid or unexpected token"），所以 base64 后按 20000 字符切片、串行执行。
   * @param gen 本次代际。
   * @param initDataJson 载荷。
   */
  private injectScriptChunked(gen: number, initDataJson: string): void {
    // 进了分片通道就不再需要「载荷是否到手」的确认：必须撤掉 ack 计时器，
    // 否则它会晚一步再触发一次回退 ⇒ 同一代际灌两遍分片，把桥的装配数组搅乱。
    this.clearFetchAckWatch();
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
   * 挂「载荷是否到手」的计时器。超时前没收到 `initFetchAck` 就认定通道不通，回退分片。
   * 收到 ack 会在 {@link clearFetchAckWatch} 里撤掉，因此正常路径永不回退。
   * @param gen 本次代际。
   * @param initDataJson 载荷（回退时重灌用）。
   */
  private armFetchAckWatch(gen: number, initDataJson: string): void {
    this.clearFetchAckWatch();
    const engineRef: LXSourceEngine = this;
    this.fetchAckTimerId = setTimeout((): void => {
      engineRef.fetchAckTimerId = -1;
      if (engineRef.fetchAckGen === gen) {
        // 载荷已到手：后面慢是脚本自己的事，交给就绪看门狗，绝不在这里二次注入
        return;
      }
      engineRef.fallbackToChunks(gen, initDataJson, 'ack 超时 ' + INIT_FETCH_ACK_MS + 'ms');
    }, INIT_FETCH_ACK_MS);
  }

  /** 撤掉快通道 ack 计时器。 */
  private clearFetchAckWatch(): void {
    if (this.fetchAckTimerId !== -1) {
      clearTimeout(this.fetchAckTimerId);
      this.fetchAckTimerId = -1;
    }
  }

  /**
   * 自动回退到分片通道（快通道失败的兜底）。
   * 三重闸：代际已变则丢弃、载荷已到手则不动、回退次数用光则只记日志。
   * @param gen 失败的那次代际。
   * @param initDataJson 当时的载荷。
   * @param why 失败原因（进日志）。
   */
  private fallbackToChunks(gen: number, initDataJson: string, why: string): void {
    if (gen !== this.pageGen) {
      LXSourceEngine.appendLog('引擎 回退跳过（代际已变 ' + gen + '→' + this.pageGen + '）原因=' + why);
      return;
    }
    if (this.fetchAckGen === gen) {
      LXSourceEngine.appendLog('引擎 回退跳过（载荷已到手）原因=' + why);
      return;
    }
    // 一代际只回退一次：「发起异常 / 桥报错 / ack 超时」三条路可能先后到，
    // 不设这道闸就会对同一份载荷重复灌分片。
    if (this.fallbackGen === gen) {
      LXSourceEngine.appendLog('引擎 回退跳过（本代已回退过）原因=' + why);
      return;
    }
    if (initDataJson.length === 0) {
      LXSourceEngine.appendLog('引擎 回退跳过（无载荷）原因=' + why);
      return;
    }
    if (this.fallbackCount >= INIT_FALLBACK_MAX) {
      LXSourceEngine.appendLog('引擎 回退已达上限(' + INIT_FALLBACK_MAX + ') 放弃原因=' + why);
      return;
    }
    this.fallbackCount++;
    this.fallbackGen = gen;
    LXSourceEngine.appendLog('引擎 快通道回退分片(' + this.fallbackCount + '/' + INIT_FALLBACK_MAX +
      ') 原因=' + why + ' gen=' + gen);
    this.injectScriptChunked(gen, initDataJson);
  }

  /**
   * 拦截快通道载荷请求。
   * 只认 {@link LX_INIT_URL}，其余一律 `return null` 原样放行（页面主文档、mf_env.js、
   * 脚本自己发的真实网络请求都不能被劫持）。
   * @param event 拦截事件。
   * @returns 载荷响应；非目标请求返回 null 表示不拦截。
   */
  private handleInterceptRequest(event: OnInterceptRequestEvent): WebResourceResponse | null {
    try {
      if (event === undefined || event === null || event.request === undefined) {
        return null;
      }
      const url: string = event.request.getRequestUrl();
      if (url.indexOf(LX_INIT_URL) !== 0) {
        return null;
      }
      return this.buildInitResponse();
    } catch (e) {
      LXSourceEngine.appendLog('引擎 拦截载荷异常: ' + JSON.stringify(e).substring(0, 100));
      return null;
    }
  }

  /**
   * 构造载荷响应：整包原始 JSON（ArrayBuffer）。
   *
   * 为什么用 ArrayBuffer 而不是文件句柄：载荷本来就在内存里（`currentInitJson`），
   * 落盘再读回来纯属多一次 I/O 和一份临时文件；ArrayBuffer 只多一次 IPC 拷贝。
   * 也不用 base64：省 33% 体积。
   *
   * ⚠️ 调用顺序按官方要求：先 data / encoding / mimeType / header / code，**最后**
   * `setResponseIsReady(true)` 才触发返回，顺序错了会让同步 XHR 阻塞。
   * 跨域头是必须的：页面源是 `resource://rawfile`，fetch 到 https 属跨域。
   * @returns 已装配好的响应对象。
   */
  private buildInitResponse(): WebResourceResponse {
    const response: WebResourceResponse = new WebResourceResponse();
    const payload: string = this.currentInitJson;
    const encoder: util.TextEncoder = new util.TextEncoder();
    const bytes: Uint8Array = encoder.encodeInto(payload);
    const buffer: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    const headers: Header[] = [
      { headerKey: 'Access-Control-Allow-Origin', headerValue: '*' },
      { headerKey: 'Cache-Control', headerValue: 'no-store' }
    ];
    response.setResponseData(buffer);
    response.setResponseMimeType('application/json');
    response.setResponseEncoding('utf-8');
    response.setResponseHeader(headers);
    response.setResponseCode(200);
    response.setReasonMessage('OK');
    response.setResponseIsReady(true);
    return response;
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
        // ★ 2026-11-04：拦了更新检查却完全没有 init ⇒ 下次放行更新检查，别把脚本锁死
        engineRef.markUpdateCheckAllowAfterFailure('看门狗超时无 init');
        return;
      }
      engineRef.readyRetryCount++;
      // ★ 2026-11-04：只看门狗超时也算"拦了更新检查仍起不来" ⇒ 让下一次加载放行更新检查，
      //   否则"拦截"会把一个真的需要清单才能初始化的脚本永久锁死（重试多少次都一样）。
      engineRef.markUpdateCheckAllowAfterFailure('看门狗超时无 init');
      // ★ Phase 0.5：完全没有 init 也意味着「这次注入没成功」。刷新重试若还走同一条通道，
      //   很可能重复失败 ⇒ 本次会话把注入钉回分片通道（今天的既有行为），换脚本时解除。
      if (!engineRef.pinChunked) {
        engineRef.pinChunked = true;
        LXSourceEngine.appendLog('引擎 注入后无 init → 本次会话固定分片通道（换脚本后解除）');
      }
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

  /**
   * 更新源 URL（**已知 schema**，可以伪造成"已是最新"）。
   *
   * ★ 2026-11-04（甲方：「为啥之前不需要更新也能用（以前好像是会拦截更新）？能不能两个并存，
   *   实现未更新但是能用」）：我们**本来就是**"拦掉更新检查、让脚本以为自己是最新版"，
   *   所以以前不更新也能用。但拦截名单只覆盖了野草系这三条 ⇒
   *   长青/刘阿五 那类（`…/lxmusic/changqing.json`、`/lx/versionh2.php`、`/lx/vers.php`）没命中，
   *   真请求发出去 ⇒ 脚本看到"发现新版本 v1.3.0，请更新后使用" ⇒ 自己拒绝 init ⇒ 8s 超时。
   */
  private static readonly UPDATE_FAKE_PATTERNS: string[] =
    ['grass-source-info', 'source-info', 'source/info'];

  /**
   * 更新清单 URL（**schema 未知**）：不能伪造 body（不知道它要什么字段），
   * 所以让它**请求失败**——脚本的版本检查通常包在 try/catch 里，失败即"不提示、继续初始化"。
   */
  private static readonly UPDATE_MANIFEST_PATTERNS: string[] = [
    'changqing.json', 'versionh2.php', 'vers.php', 'update.json', 'version.json',
    'checkupdate', 'check-update', 'upgrade.json', 'updateinfo', '/lx/version'
  ];

  private matchesAny(url: string, patterns: string[]): boolean {
    for (let i: number = 0; i < patterns.length; i++) {
      if (url.indexOf(patterns[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  /**
   * 该脚本是否"隔离更新检查"（= 应该拦截）。
   * 若它上次被拦之后仍然 init 失败，说明拦错了（脚本确实需要清单才能跑）⇒ 这次放行。
   */
  private shouldBlockUpdateCheck(url: string, scriptId: string): boolean {
    if (scriptId.length > 0) {
      const allow: boolean = (AppStorage.get<boolean>(scriptAllowKey(scriptId)) ?? false) === true;
      if (allow) {
        return false;
      }
    }
    return this.matchesAny(url, LXSourceEngine.UPDATE_FAKE_PATTERNS) ||
      this.matchesAny(url, LXSourceEngine.UPDATE_MANIFEST_PATTERNS);
  }

  /** 拦截后记一笔：给设置页展示"有新版本，已拦截以保持可用"，并标记该脚本。 */
  private noteBlockedUpdateCheck(url: string, scriptId: string, scriptName: string): void {
    const text: string = '音源「' + scriptName + '」的更新检查已被拦截（保持可用）：' + url.substring(0, 80);
    try {
      AppStorage.setOrCreate(KEY_BLOCKED_LOG, text);
      AppStorage.setOrCreate(KEY_BLOCKED_URL, url);
      AppStorage.setOrCreate(AppStorageKeys.LX_UPDATE_BLOCKED_VERSION, Date.now());
      if (scriptId.length > 0) {
        AppStorage.setOrCreate(scriptBlockedAtKey(scriptId), Date.now());
        // 按脚本记下被拦的那条 URL：设置页点「检查更新」时据此说明"为什么查不了"
        AppStorage.setOrCreate(scriptBlockedUrlKey(scriptId), url);
      }
    } catch (e) {
      // AppStorage 不可用时只打日志
    }
    LXSourceEngine.appendLog('[音源] ' + text);
  }

  /**
   * 拦截之后脚本**仍然**没就绪 ⇒ 说明"检查失败"它接受不了 ⇒ 下次放行，优先保证"能跑"。
   * @param reason 触发原因（`init status=false` / `看门狗超时`），只用于日志
   */
  private markUpdateCheckAllowAfterFailure(reason: string): void {
    const scriptId: string = this.currentScriptId;
    if (scriptId.length === 0) {
      return;
    }
    const blockedAt: number = AppStorage.get<number>(scriptBlockedAtKey(scriptId)) ?? 0;
    if (blockedAt <= 0) {
      return;
    }
    AppStorage.setOrCreate(scriptAllowKey(scriptId), true);
    LXSourceEngine.appendLog('[音源] ' + (this.currentApiInfo?.name ?? scriptId) +
      ' 拦截更新检查后仍未就绪（' + reason + '）⇒ 下次放行更新检查');
  }

  private handleNativeFetch(data: Record<string, Object>): void {
    let requestId: number = data.requestId as number;
    let url: string = data.url as string;
    let method: string = (data.method as string) || 'GET';
    let headers: Record<string, string> = data.headers as Record<string, string>;
    let body: string = data.body as string;
    let timeout: number = (data.timeout as number) || 15000;
    // 拦截音源脚本的**在线更新检查**：让脚本以为"已经是最新/检查不成功"，从而继续初始化。
    // （"未更新也能用"就靠这里；详见 UPDATE_FAKE_PATTERNS / UPDATE_MANIFEST_PATTERNS 的注释。）
    const scriptId: string = this.currentScriptId;
    if (this.shouldBlockUpdateCheck(url, scriptId)) {
      const scriptName: string = this.currentApiInfo?.name ?? scriptId;
      this.noteBlockedUpdateCheck(url, scriptId, scriptName);
      if (this.matchesAny(url, LXSourceEngine.UPDATE_FAKE_PATTERNS)) {
        // ① schema 已知（野草系）：伪造"当前已是注入版本"
        const curVersion: string = this.currentApiInfo?.version ?? '';
        const verEsc: string = curVersion.replace(/"/g, '\\"');
        const fake: string = '{"status":{"success":true,"data":{"m":"' + verEsc + '","s":""}}}';
        const esc: string = this.escapeJsString(fake);
        LXSourceEngine.appendLog('引擎 拦截更新检查（伪造已最新）: ' + url.substring(0, 80));
        this.runJs(`window._lx_handleFetchResponse(${requestId}, null, 200, '{}', '${esc}')`);
        return;
      }
      // ② schema 未知（长青/星海那类清单）：让它"请求失败"——
      //    脚本的版本检查基本都包在 try/catch 里，失败即跳过提示、继续 init。
      const blockErr: string = '{"code":2300006,"message":"update check blocked to keep the source usable"}';
      const escErr: string = this.escapeJsString(blockErr);
      LXSourceEngine.appendLog('引擎 拦截更新检查（置为失败以保持可用）: ' + url.substring(0, 80));
      this.runJs(`window._lx_handleFetchResponse(${requestId}, '${escErr}', 0, '{}', '')`);
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
          // injectMs = 从发起注入到桥上报 init 的总耗时：Phase 0.5 的唯一验收指标，
          // 快通道与分片通道都打这一条，便于上机直接对比。
          const injectMs: number = this.injectStartedAt > 0 ? Date.now() - this.injectStartedAt : -1;
          LXSourceEngine.appendLog('引擎 init 事件 status=' + status + ' gen=' + gen +
            ' pageGen=' + this.pageGen + ' injectMs=' + injectMs +
            (errorMsg.length > 0 ? ' msg=' + errorMsg.substring(0, 80) : ''));
          if (gen >= 0 && gen !== this.pageGen) {
            // 刷新/换脚本后迟到的旧代际事件：丢弃，避免把新脚本的状态写错
            LXSourceEngine.appendLog('引擎 忽略过期代际的 init（gen=' + gen + '）');
            break;
          }
          if (status && srcs !== undefined) {
            // 成功即归零重试额度并撤掉看门狗（快通道 ack 计时器也一并撤掉）
            this.readyRetryCount = 0;
            this.clearReadyWatchdog();
            this.clearFetchAckWatch();
            this.setReady(true, srcs);
            LXSourceEngine.appendLog('引擎 就绪 ✓ sources=' + Object.keys(srcs).length);
            // 回写脚本平台信息，供换源时按平台择优（以前从不回写，一直是 {}）
            lxSourceManager.saveApiSources(this.currentScriptId, srcs);
          } else {
            this.setReady(false, null);
            // ★ 2026-11-04：拦了更新检查它还是起不来 ⇒ 下次放行（宁可让它自己判断能不能用）
            this.markUpdateCheckAllowAfterFailure('init status=false');
            if (status && srcs === undefined) {
              LXSourceEngine.appendLog('引擎 init status=true 但缺少 sources，按未就绪处理');
            }
          }
          break;
        }
        case 'initFetchAck': {
          // 桥已拿到整包载荷（**解析之前**就回这条）：到此为止通道是通的，
          // 后面再慢都属于脚本自身启动，不能再回退分片重灌。
          const ackGen: number = data.gen !== undefined ? (data.gen as number) : -1;
          const ackLen: number = data.length !== undefined ? (data.length as number) : 0;
          this.fetchAckGen = ackGen;
          this.clearFetchAckWatch();
          LXSourceEngine.appendLog('引擎 快通道载荷到达 gen=' + ackGen + ' ' + ackLen + 'B');
          break;
        }
        case 'initFetchError': {
          const errGen: number = data.gen !== undefined ? (data.gen as number) : -1;
          const errMsg: string = (data.message as string) || '';
          LXSourceEngine.appendLog('引擎 快通道失败 gen=' + errGen +
            ' msg=' + errMsg.substring(0, 120));
          this.fallbackToChunks(errGen, this.currentInitJson, '桥上报: ' + errMsg);
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
          // ★ 2026-11-14（甲方：「检查出来之后检查其它音源还是这个源的提示」）：
          //   告警**必须按脚本分开存**。以前只有全局 `lxUpdateAlert*`，于是本次启动里
          //   第一个上报过告警的源，会把「发现新版本」对话框劫持给之后检查的所有源。
          AppStorage.setOrCreate(scriptAlertUrlKey(this.currentScriptId), updateUrl);
          AppStorage.setOrCreate(scriptAlertLogKey(this.currentScriptId), log);
          AppStorage.setOrCreate(scriptAlertAtKey(this.currentScriptId), Date.now());
          // 全局键继续写（播放失败的「音源需要更新」提示要用），但**记下归属**，
          // 读的人据此判断这条告警是不是当前这个源的，跨源就不再借用。
          AppStorage.setOrCreate(KEY_ALERT_OWNER, this.currentScriptId);
          AppStorage.setOrCreate(KEY_ALERT_LOG, log);
          AppStorage.setOrCreate(KEY_ALERT_URL, updateUrl);
          AppStorage.setOrCreate(KEY_ALERT_AT, Date.now());
          // 回调是**附加**动作：以前写在 else 里，一旦有人接了这根线，设置页就永远读不到。
          if (this.onUpdateAlert !== null) {
            this.onUpdateAlert(log, updateUrl);
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
      .onControllerAttached((): void => {
        // 官方：此回调之前不得调用 Web 组件相关 API（否则抛 js-error 17100001）
        this.controllerAttached = true;
        LXSourceEngine.appendLog('引擎 控制器已绑定，待注入=' + this.currentInitJson.length + 'B');
      })
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
      .onInterceptRequest((event: OnInterceptRequestEvent) => {
        // 快通道载荷：桥 fetch 的目标地址在这里应答，其余请求返回 null 原样放行
        return this.handleInterceptRequest(event);
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
      // ★ 2026-10-29：脚本只打日志「更新提示: … url=…」，抓到就写进官方 alert（检查更新才读得到）
      try {
        const jsText: string = msg.getMessage();
        if (jsText.indexOf('更新提示') >= 0) {
          const u: RegExpMatchArray | null = jsText.match(/url=(\S+)/);
          const alertUrl: string = u !== null && u.length > 1 ? u[1] : '';
          const alertLog: string = jsText.substring(0, Math.min(jsText.length, 160));
          // ★ 2026-11-14：**同时按脚本分键**。有些脚本只 console 打「更新提示」、不 send
          //   updateAlert；以前这里只写全局 `rzd_update_alert_*`，导致「检查更新」去扫
          //   整段播放日志（`lastIndexOf('更新提示')`）—— 那必然抓到**别的源**的提示。
          if (this.currentScriptId.length > 0) {
            AppStorage.setOrCreate(scriptAlertUrlKey(this.currentScriptId), alertUrl);
            AppStorage.setOrCreate(scriptAlertLogKey(this.currentScriptId), alertLog);
            AppStorage.setOrCreate(scriptAlertAtKey(this.currentScriptId), Date.now());
          }
          AppStorage.setOrCreate(AppStorageKeys.UPDATE_ALERT_URL, alertUrl);
          AppStorage.setOrCreate(AppStorageKeys.UPDATE_ALERT_LOG, alertLog);
        }
      } catch (e) {
      }
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
