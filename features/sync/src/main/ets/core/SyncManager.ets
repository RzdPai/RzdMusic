/**
 * 对应 listen 的 entry/src/main/ets/core/sync/SyncManager.ets（对外门面）
 *
 * 适配改动（状态管理 V1 -> V2，以及没有会话类带来的变化）：
 *   1) 状态给 UI 观察的方式。
 *      listen 用 AppStorage（V1）的几个扁平 key（K_SYNC_ENABLE / K_SYNC_STATUS / K_SYNC_MESSAGE /
 *      K_SYNC_PROGRESS / K_SYNC_STAGE）+ 两个监听回调（setModeRequestListener / setMessageListener）。
 *      RzdMusic 是状态管理 V2，改成 AppStorageV2 + @ObservedV2 的 SyncUiState：
 *      视图拿 `syncManager.uiState()`，直接观察它的 @Trace 字段（enabled / serverUrl / authCode /
 *      deviceName / connected / statusText / syncing / pendingMode / summaryText ...）。
 *   2) 「同步方式选择」交互。
 *      listen 是 SyncManager 回调界面弹框、界面再用 answerMode() 回传。
 *      这里改成把请求放进 SyncUiState.pendingMode（含 kind / serverName / 标题 / 各选项），
 *      视图看到非 null 就弹选择框，用户选完调 SyncManager.resolveSyncMode(choice) 回传。
 *      额外的保护：视图没弹出（后台同步）时不能让服务端一直等，超时按「取消」处理。
 *   3) 同步数据版本号 K_SYNC_DATA_VERSION 不再需要：远端数据到达由 LocalLibrary 自己递增
 *      @Trace libraryVersion，界面观察它（见 LocalLibrary 文件头第 5 条）。
 *   4) init(context) 的 context 变可选（不传时取 getAppRuntime().context），与 SyncStore/SyncGzip/
 *      LocalLibrary 一致。
 *   5) SyncStore 实例：listen 里 SyncManager 自己 new 一个、LocalLibrary 内部还有一个（同目录两份）。
 *      这里统一用 LocalLibrary 的那一个（library.getStore()），避免两个实例各自维护 ready/dir 状态。
 *   6) 日志：listen 的 hilog 换成 musicbasic 的 appendPlayLog / appendError。
 */

import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { appendError, appendPlayLog, getAppRuntime } from 'musicbasic';
import { LocalLibrary, LibrarySummary } from './LocalLibrary';
import { SyncClient } from './SyncClient';
import { initGzip } from './SyncGzip';
import { defaultDeviceName, SyncConfig } from './SyncStore';
import { DISLIKE_MODE_OPTIONS, LIST_MODE_OPTIONS, SyncModeOption, SyncStatus, SYNC_MODE_CANCEL } from './SyncTypes';
import { describeStatus, shouldNotifySyncMessage } from './SyncStatusText';

const TAG: string = 'SyncManager';

/**
 * SyncUiState 的 AppStorageV2 键
 *
 * 本该按约定放进 common/musicbasic 的 AppStorageKeys（前缀 musichome_），但本模块不允许改那个文件，
 * 所以内联在这里并导出（与 features/localmusic 的 LOCAL_MUSIC_IMPORT_STATE_KEY 同一做法）。
 */
export const SYNC_UI_STATE_KEY: string = 'musichome_SyncUiState';

/** 同步方式选择的等待上限：视图一直没弹（后台同步）也不能把服务端的等待挂死 */
const MODE_REQUEST_TIMEOUT_MS: number = 120 * 1000;

/**
 * 「选择同步方式」请求（视图据此弹选择框）
 *
 * kind：'list' 表示歌单/收藏/试听列表，'dislike' 表示不喜欢的歌曲规则；
 * serverName：服务端在 /ah 里报的名字（视图拿来提示用户是哪个服务端）。
 */
export interface SyncModeRequest {
  kind: string;
  serverName: string;
  title: string;
  options: SyncModeOption[];
}

/**
 * 同步模块的可观察状态（ArkUI 状态管理 V2）
 *
 * 视图这样接线：
 *   @Local state: SyncUiState = syncManager.uiState();
 * 然后直接读 state.enabled / state.statusText / state.pendingMode ...，改值由 SyncManager 负责。
 */
@ObservedV2
export class SyncUiState {
  /** 同步开关（配置里的 enable） */
  @Trace public enabled: boolean = false;
  /** 服务器地址（配置里的 host，已规范化） */
  @Trace public serverUrl: string = '';
  /** 认证码（只放在内存里，与 listen 的设置页状态一致；服务端身份靠 keys.json 保存的密钥） */
  @Trace public authCode: string = '';
  /** 设备名（认证时上报给服务端的那个） */
  @Trace public deviceName: string = '';
  /** 是否已连接（服务端调 finished() 之后为 true） */
  @Trace public connected: boolean = false;
  /** 状态文案（SyncStatusText 翻译过的人话） */
  @Trace public statusText: string = '';
  /** 是否正在同步（进度在 0-100 之间） */
  @Trace public syncing: boolean = false;
  /** 服务端要求选择同步方式时的请求；null = 没有待处理的选择 */
  @Trace public pendingMode: SyncModeRequest | null = null;
  /** 同步内容摘要（歌单数 / 歌曲数） */
  @Trace public summaryText: string = '';
  /** 同步进度百分比（0-100） */
  @Trace public progress: number = 0;
  /** 当前同步阶段文案 */
  @Trace public stage: string = '';
  /** 服务器地址历史（最近的在前） */
  @Trace public hostHistory: string[] = [];
  /**
   * 最近一条需要用户知道的状态消息（认证失败、被拉黑这类；过程性消息不写进来）
   *
   * 视图可以在它变化时弹一条提示条，判断口径见 SyncStatusText.shouldNotifySyncMessage。
   */
  @Trace public lastMessage: string = '';
}

/**
 * 同步模块的对外门面
 *
 * 界面只跟它打交道：开关同步、改服务器地址（含历史）、认证码、设备名、连接状态、
 * 同步内容摘要、不喜欢规则增删、同步方式选择回传。
 * 它把 SyncStore（持久化）、LocalLibrary（音乐库适配层）、SyncClient（协议）三者接起来。
 */
export class SyncManager {
  private static instance: SyncManager | null = null;

  static getInstance(): SyncManager {
    if (SyncManager.instance === null) {
      SyncManager.instance = new SyncManager();
    }
    return SyncManager.instance;
  }

  private library: LocalLibrary = LocalLibrary.getInstance();
  private client: SyncClient | null = null;
  private config: SyncConfig = { enable: false, host: '', deviceName: '', hostHistory: [] };
  private inited: boolean = false;
  private connectedOnce: boolean = false;
  private progress: number = 0;
  private stage: string = '';
  private authCode: string = '';
  private lastMessage: string = '';
  private state: SyncUiState | null = null;
  private pendingModeResolve: ((mode: string) => void) | null = null;
  private pendingModeTimer: number = 0;

  /**
   * 初始化：准备存储、装上界面出口、按配置自动连接
   *
   * 由宿主在拿到 context 后调用一次（EntryAbility.onCreate 或首个页面）。
   * @param context 可选的 context；不传时取 getAppRuntime().context
   */
  init(context?: common.Context): void {
    if (this.inited) {
      return;
    }
    this.inited = true;
    const ctx: common.Context | undefined = context !== undefined ? context : getAppRuntime().context;
    if (ctx !== undefined) {
      initGzip(ctx.cacheDir);
    }
    this.library.init(ctx);
    this.config = this.library.getStore().loadConfig();

    const client: SyncClient = new SyncClient(this.library.getStore(), this.library);
    this.client = client;
    client.setStatusListener((status: SyncStatus) => {
      this.onStatusChanged(status);
    });
    client.setModeSelector((kind: string, serverName: string) => {
      return this.requestMode(kind, serverName);
    });
    client.setProgressListener((percent: number, label: string) => {
      this.progress = percent;
      this.stage = label;
      this.publishState();
    });

    // 已经落过库就先对一次账（协议镜像 -> MusicStoreService），首次安装不做任何改动
    if (this.library.isInitialized()) {
      this.library.mirrorToSession();
    }
    this.publishState();

    if (this.config.enable && this.config.host.length > 0) {
      void this.connect().catch((err: Error) => {
        appendError(`[${TAG}] auto connect failed: ${err.message}`);
      });
    }
  }

  isInited(): boolean {
    return this.inited;
  }

  /** 音乐库适配层（视图要展示歌单/收藏摘要时用；远端数据到达看它的 @Trace libraryVersion） */
  getLibrary(): LocalLibrary {
    return this.library;
  }

  getConfig(): SyncConfig {
    return this.config;
  }

  /** 取共享的可观察状态（AppStorageV2 单例） */
  uiState(): SyncUiState {
    if (this.state === null) {
      this.state = AppStorageV2.connect(SyncUiState, SYNC_UI_STATE_KEY, () => new SyncUiState())!;
    }
    return this.state;
  }

  deviceName(): string {
    if (this.config.deviceName.length === 0) {
      this.config.deviceName = defaultDeviceName();
    }
    return this.config.deviceName;
  }

  getStatus(): SyncStatus {
    const client = this.client;
    return client === null ? { status: false, message: '' } : client.getStatus();
  }

  getLastMessage(): string {
    return this.lastMessage;
  }

  hostHistory(): string[] {
    return this.config.hostHistory;
  }

  getProgress(): number {
    return this.progress;
  }

  getStage(): string {
    return this.stage;
  }

  /** 同步内容摘要文案（设置页展示） */
  summaryText(): string {
    const summary: LibrarySummary = this.library.summary();
    return `歌单 ${summary.playlists} 个 · 歌曲 ${summary.songs} 首`;
  }

  // ------------------------------------------------------------ 同步方式选择

  /**
   * 界面选完同步方式后回传（传空串或 'cancel' 都表示取消）
   *
   * choice 取值见 SyncTypes.SYNC_LIST_MODES / LIST_MODE_OPTIONS / DISLIKE_MODE_OPTIONS。
   */
  resolveSyncMode(choice: string): void {
    if (this.pendingModeTimer !== 0) {
      clearTimeout(this.pendingModeTimer);
      this.pendingModeTimer = 0;
    }
    const resolve = this.pendingModeResolve;
    this.pendingModeResolve = null;
    const state: SyncUiState = this.uiState();
    if (state.pendingMode !== null) {
      state.pendingMode = null;
    }
    if (resolve !== null) {
      resolve(choice.length > 0 ? choice : 'cancel');
    }
  }

  /** 发起一次「选择同步方式」（SyncClient 的 modeSelector 走这里） */
  private requestMode(kind: string, serverName: string): Promise<string> {
    // 上一个还没答就直接取消，避免悬挂
    this.resolveSyncMode('cancel');
    const state: SyncUiState = this.uiState();
    const request: SyncModeRequest = {
      kind: kind,
      serverName: serverName,
      title: kind === 'dislike'
        ? '「不喜欢的歌曲」本机与远程不一致，请选择同步方式'
        : '列表本机与远程不一致，请选择同步方式',
      options: buildModeOptions(kind),
    };
    return new Promise<string>((resolve: (mode: string) => void) => {
      this.pendingModeResolve = resolve;
      state.pendingMode = request;
      this.pendingModeTimer = setTimeout(() => {
        this.pendingModeTimer = 0;
        appendError(`[${TAG}] sync mode request timed out (no view answered), cancel`);
        this.resolveSyncMode('cancel');
      }, MODE_REQUEST_TIMEOUT_MS);
    });
  }

  // ------------------------------------------------------------ 开关 / 地址

  /** 打开同步并连接 */
  async enable(host: string): Promise<void> {
    const normalized: string = SyncClient.normalizeHost(host);
    if (normalized.length === 0) {
      throw new Error('请先填写同步服务器地址');
    }
    this.updateHost(normalized);
    this.config.enable = true;
    this.config.deviceName = this.deviceName();
    this.library.getStore().saveConfig(this.config);
    this.publishState();
    await this.connect();
  }

  /** 关闭同步并断开 */
  async disable(): Promise<void> {
    this.config.enable = false;
    this.library.getStore().saveConfig(this.config);
    this.publishState();
    const client = this.client;
    if (client !== null) {
      await client.disconnect();
    }
  }

  /**
   * 回到前台时补一次连接
   *
   * 同步要「配置好之后后台自动连接」：连接断了（或被系统回收）时，
   * 前台恢复就自己补上，不用用户手动点重连。
   */
  async ensureConnected(): Promise<void> {
    if (!this.config.enable || this.config.host.length === 0) {
      return;
    }
    const client = this.client;
    if (client === null || client.isConnected() || client.isReconnecting()) {
      return;
    }
    try {
      await this.connect();
    } catch (e) {
      appendError(`[${TAG}] foreground reconnect failed: ${(e as Error).message}`);
    }
  }

  /** 记下用户填的认证码（只放内存；连接时用它走「认证码换密钥」那条路） */
  setAuthCode(authCode: string): void {
    this.authCode = authCode;
    this.uiState().authCode = authCode;
  }

  getAuthCode(): string {
    return this.authCode;
  }

  /** 用认证码连接（认证失败后用户补填认证码再连） */
  async connectWithCode(authCode: string): Promise<void> {
    this.setAuthCode(authCode);
    const client = this.client;
    if (client === null) {
      throw new Error('同步模块未初始化');
    }
    await client.connect(this.config.host, this.deviceName(), authCode);
  }

  /** 用已保存的密钥连接 */
  private async connect(): Promise<void> {
    const client = this.client;
    if (client === null) {
      throw new Error('同步模块未初始化');
    }
    await client.connect(this.config.host, this.deviceName(), '');
  }

  /** 手动重连（设置页的「重新连接」） */
  async reconnect(): Promise<void> {
    await this.connect();
  }

  updateHost(host: string): void {
    const normalized: string = SyncClient.normalizeHost(host);
    if (normalized.length === 0 || normalized === this.config.host) {
      return;
    }
    this.config.host = normalized;
    if (!this.config.hostHistory.includes(normalized)) {
      this.config.hostHistory.unshift(normalized);
      if (this.config.hostHistory.length > 20) {
        this.config.hostHistory = this.config.hostHistory.slice(0, 20);
      }
    }
    this.library.getStore().saveConfig(this.config);
    this.publishState();
  }

  removeHostHistory(host: string): void {
    const remains: string[] = [];
    for (const item of this.config.hostHistory) {
      if (item !== host) {
        remains.push(item);
      }
    }
    this.config.hostHistory = remains;
    this.library.getStore().saveConfig(this.config);
    this.publishState();
  }

  /** 设备名改了（落盘到 config.json） */
  updateDeviceName(name: string): void {
    const value: string = name.trim();
    if (value.length === 0 || value === this.config.deviceName) {
      return;
    }
    this.config.deviceName = value;
    this.library.getStore().saveConfig(this.config);
    this.publishState();
  }

  // ------------------------------------------------------------ 不喜欢的歌曲规则（转发给音乐库）

  /** 当前规则（每行「歌名@歌手」） */
  dislikeRuleList(): string[] {
    return this.library.dislikeRuleList();
  }

  addDislike(name: string, singer: string): void {
    this.library.addDislike(name, singer);
    this.bumpSummary();
  }

  removeDislike(rule: string): void {
    this.library.removeDislikeRule(rule);
    this.bumpSummary();
  }

  clearDislike(): void {
    this.library.clearDislike();
    this.bumpSummary();
  }

  // ------------------------------------------------------------ 状态发布

  private onStatusChanged(status: SyncStatus): void {
    if (status.message.length > 0 && status.message !== this.lastMessage) {
      this.lastMessage = status.message;
      if (shouldNotifySyncMessage(status.message)) {
        appendPlayLog(`[${TAG}] ${describeStatus(status.status, status.message)}`);
      }
    }
    if (status.status && !this.connectedOnce) {
      this.connectedOnce = true;
    }
    this.publishState();
    // 同步过程可能整体替换本地列表，通知界面重读
    this.library.bumpLibraryVersion();
  }

  /** 摘要 / 版本号变了：让界面重读一次 */
  private bumpSummary(): void {
    this.library.bumpLibraryVersion();
    this.publishState();
  }

  private publishState(): void {
    const state: SyncUiState = this.uiState();
    const status: SyncStatus = this.getStatus();
    state.enabled = this.config.enable;
    state.serverUrl = this.config.host;
    state.deviceName = this.deviceName();
    state.connected = status.status;
    state.statusText = describeStatus(status.status, status.message);
    state.progress = this.progress;
    state.stage = this.stage;
    state.syncing = this.progress > 0 && this.progress < 100;
    state.hostHistory = this.config.hostHistory.slice();
    state.summaryText = this.summaryText();
    state.authCode = this.authCode;
    state.lastMessage = this.lastMessage;
  }
}

/** 进程内单例（features/sync/Index.ets 对外导出它） */
export let syncManager: SyncManager = SyncManager.getInstance();

// ------------------------------------------------------------------ 工具

/** 按 kind 取同步方式选项（末位固定加「取消同步」） */
function buildModeOptions(kind: string): SyncModeOption[] {
  const out: SyncModeOption[] = [];
  const source: SyncModeOption[] = kind === 'dislike' ? DISLIKE_MODE_OPTIONS : LIST_MODE_OPTIONS;
  for (const option of source) {
    out.push(option);
  }
  out.push(SYNC_MODE_CANCEL);
  return out;
}
