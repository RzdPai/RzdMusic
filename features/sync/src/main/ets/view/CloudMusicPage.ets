/*
 * 「我的 → 云端音乐」二级页（照搬参考工程 lxmusic-harmony 的 views/WebDavView.ets 版式）
 *
 * ## 它是什么
 *
 * WebDAV 上的曲库（**我们自己的 WebDAV 服务器**，不是洛雪服务端）：
 * 进页面就把配置里那个目录（含子目录）扫一遍，扫到的音频直接列出来，点一下就能放。
 * 数据层在 `../core/WebDavLibrary`，凭据/基址沿用「设置 → 同步 → WebDAV 备份」那套配置
 * （**没有第二份配置，也没有硬编码口令**）。
 *
 * ## 与参考工程的差异（逐条写清，别当成"漏搬"）
 *
 *  1. **版式照搬、色值不照搬**：参考那张列表是洛雪红 + 写死白卡；这里一律换成我们的 token
 *     （`$r('sys.color.*')` / `$r('app.color.*')` / `ThemeState.color`）。
 *  2. **多选 / 入歌单 / 收藏 / 歌曲匹配 / 歌词匹配不搬**：参考那套挂在一个跨页面的
 *     `SelectSession` 会话上，本工程没有对应的东西；而「云端歌进歌单」需要一条
 *     云端侧表（参考是 `SongSideTable`），属于另一个功能面。**没做就是没做，不编**。
 *  3. **播放走「先缓存到沙箱再按本地文件播」**：参考带 `Authorization` 头直链流播，
 *     我们播放器只设 `avPlayer.url`、无处塞请求头（详见 `../core/WebDavLibrary` 文件头
 *     的三条取舍论证），所以首播要等下载完整首。
 *  4. **加入播放队列 / 下一首播放照做了**：用 `MusicAppState.playQueue` 这条既有能力
 *     （与 `features/playlist` 的批量「下一首播放」同一口径）。
 *
 * ## 状态
 *
 *  只用 V2：`@ComponentV2` / `@Local`；路由只用 NavPathStack（本页由 HDS 的返回箭头弹栈，
 *  自己没有 push）。列表用 `List` + `LazyForEach` + 稳定 key（**不用 `Repeat`**）。
 *
 * 日志：`hdc shell hilog | findstr RzdWebDavCloud`
 */

import { AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  BlurStrategy,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions,
  ScrollEffectType,
  TitleSize
} from '@kit.UIDesignKit';
import {
  AmbientState,
  AppStorageKeys,
  MusicAppState,
  PlaybackIntentState,
  SongItem,
  ThemeState,
  TitleBarConstants,
  buildTitleMaterial,
  getStatusBarTopVpFromWindowUtil,
  guardPlayerBack
} from 'musicbasic';
import {
  WebDavDownloadProgress,
  WebDavLibrary,
  WebDavScanResult,
  WebDavSong,
  describeAgo,
  describeScan,
  folderNameOf,
  formatBytes,
  formatDuration,
  webDavCloudConfig,
  webDavCloudConfigured
} from '../core/WebDavLibrary';

const DOMAIN: number = 0x0001;
const LOG_TAG: string = 'RzdWebDavCloud';

/** 行高与封面尺寸：对齐参考 `SongRow`（`coverSize + 22`，封面 48 ⇒ 行高 70） */
const ROW_COVER_SIZE: number = 48;
const ROW_HEIGHT: number = ROW_COVER_SIZE + 22;
/** 分割线左缩进 = 左侧内边距 + 封面 + 间距 */
const ROW_DIVIDER_INSET: number = 16 + ROW_COVER_SIZE + 11;
/**
 * HDS 标题栏那一行的高度（vp）
 *
 * 用 `TitleBarConstants.ROW_HEIGHT_VP`（= 56vp）而不是再写一个 56：
 * 页面内容的顶部避让**必须**与标题栏实际高度一致，两个数字各写一处必然发散。
 *
 * ⚠️ 只在**模块顶层**取这个值（`TitleBarConstants.ROW_HEIGHT_VP` 是常量，不参与响应式）；
 * 别把它搬进 `build()` 里当表达式，那样每帧都要重算一次字符串/尺寸。
 */
const TITLE_BAR_ROW_VP: number = TitleBarConstants.ROW_HEIGHT_VP;

/** 列表里的一行数据（LazyForEach 的稳定 key 就是 `key`） */
class CloudRow {
  song: WebDavSong = {
    key: '', url: '', folder: '', file: '', name: '', singer: '', album: '',
    durationMs: 0, sizeBytes: -1, seenAt: 0, seen: false, tagsDone: false, local: '', localBytes: 0
  };
  /** 已缓存在本机（列表行给个标记，点播放就不用等下载） */
  cached: boolean = false;
  /** 正在缓存这一行（显示进度条） */
  busy: boolean = false;
}

/**
 * `LazyForEach` 的数据源
 *
 * 只用最朴素的实现：整个列表换一次就 `onDataReloaded()`（刷新/扫描完成后一次性重建），
 * 不做局部通知 —— 云端列表的变更粒度就是"整批"，逐条通知只会多一份容易错的簿记。
 */
class CloudDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private rows: CloudRow[] = [];

  totalCount(): number {
    return this.rows.length;
  }

  getData(index: number): CloudRow {
    return this.rows[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const at: number = this.listeners.indexOf(listener);
    if (at >= 0) {
      this.listeners.splice(at, 1);
    }
  }

  /** 整批换（行数变了/内容变了都走它） */
  replaceAll(rows: CloudRow[]): void {
    this.rows = rows;
    for (const listener of this.listeners) {
      listener.onDataReloaded();
    }
  }
}

/**
 * 「云端音乐」二级页
 *
 * 由 `features/sync/router_map.json` 的 `CloudMusicPage` 登记、`CloudMusicPageBuilder` 渲染；
 * 「我的」页那一格快捷入口推的就是 `RouterUrlConstants.CLOUD_MUSIC`（本页**不自己 push**）。
 */
@ComponentV2
export struct CloudMusicPage {
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** 标题栏沉浸材质的档位（与工程里其它二级页同一口径：环境光档位） */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /** 标题栏返回箭头要弹的栈（`onReady` 里由 NavDestinationContext 给） */
  private pathStack: NavPathStack | undefined = undefined;
  /** 标题栏选项缓存（HDS 要求同一个对象，避免每帧重建） */
  private cachedTitleBar: HdsNavigationTitleBarOptions | undefined = undefined;

  /** 列表数据源（LazyForEach 只认它） */
  private source: CloudDataSource = new CloudDataSource();
  /** 与 source 同步的一份数组：计数/空态判定要走 `@Local` 才会触发重绘 */
  @Local rows: CloudRow[] = [];
  /** 扫描 / 缓存进度文案（空闲空串） */
  @Local progressText: string = '';
  /** 一句状态说明（上次扫描时间 / 本次结果 / 未配置引导） */
  @Local statusText: string = '';
  /** 可读的失败文案（空串 = 没有失败）；有它时列表区显示失败态 + 重试 */
  @Local errorText: string = '';
  /** 首次加载中（还没有任何数据时显示 loading） */
  @Local loading: boolean = false;
  /** 下拉刷新组件的状态（V2 下用 `!!` 双向绑定，见官方 arkts-new-binding） */
  @Local refreshing: boolean = false;
  /** 正在缓存的那一行的 key（空串 = 没有在缓存） */
  @Local cachingKey: string = '';
  /** 缓存进度 0..1（-1 = 未知总长） */
  @Local cacheRatio: number = -1;

  aboutToAppear(): void {
    const library: WebDavLibrary = WebDavLibrary.getInstance();
    // 应用刚起来时 context 可能还没灌进 AppStorage：这里拿 UIContext 的 host context 兜一次
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    const ready: boolean = library.init(context);
    this.reloadRows();
    this.statusText = this.statusLine();
    hilog.info(DOMAIN, LOG_TAG, 'page appear ready=%{public}s configured=%{public}s cached=%{public}d',
      `${ready}`, `${webDavCloudConfigured()}`, this.rows.length);
    void this.autoScanIfNeeded();
  }

  @Monitor('themeState.color')
  onThemeColorChanged(): void {
    hilog.info(DOMAIN, LOG_TAG, 'theme changed accent=%{public}s', `${this.themeState.color}`);
  }

  /**
   * 本机已缓存的字节数（`@Computed`：只在 `rows` 变时重算，不要在 build 里现算）
   *
   * 用它决定「已缓存的加入队列」这个入口出不出来 —— 本机一首都没缓存时那个按钮没有意义。
   */
  @Computed
  get cachedBytes(): number {
    let sum: number = 0;
    for (const row of this.rows) {
      sum += row.song.localBytes;
    }
    return sum;
  }

  /**
   * 环境光档位变了：标题栏材质要跟着换
   *
   * HDS 的 `titleBar()` 选项在页面里被缓存了一份（`cachedTitleBar`），
   * 档位变化时**必须显式失效**，否则用户改了「沉浸光感」设置后本页一直是旧材质。
   */
  @Monitor('ambientState.level')
  onAmbientLevelChanged(): void {
    this.cachedTitleBar = undefined;
    hilog.info(DOMAIN, LOG_TAG, 'ambient level=%{public}d rebuild title material',
      this.ambientState.level);
  }

  // ───────────────────────────────────────────── 状态行与空/失败态

  /** 顶部那一行状态：没配置 → 引导；没扫过 → 「还没扫过」；扫过 → 上次时间 + 条数 + 占用 */
  private statusLine(): string {
    if (!webDavCloudConfigured()) {
      return '还没有配置 WebDAV 服务器';
    }
    const library: WebDavLibrary = WebDavLibrary.getInstance();
    if (library.scanTime() <= 0) {
      return '还没扫过这台服务器';
    }
    const parts: string[] = [`上次扫描：${describeAgo(library.scanTime())}`];
    if (this.rows.length > 0) {
      parts.push(`${this.rows.length} 首 · ${formatBytes(library.totalBytes())}`);
    }
    const cached: number = library.cachedBytes();
    if (cached > 0) {
      parts.push(`本机缓存 ${formatBytes(cached)}`);
    }
    return parts.join(' · ');
  }

  /** 从曲库重建行（刷新/扫描/缓存变化后统一走这里） */
  private reloadRows(): void {
    const library: WebDavLibrary = WebDavLibrary.getInstance();
    // 首次可能因为「应用上下文还没就绪」而 init 失败（见 CloudMusicPage.aboutToAppear）；
    // 这里补一次 —— 只在没就绪时进，就绪之后是白跑一次布尔判断。
    if (!library.isReady()) {
      library.init(this.getUIContext().getHostContext());
    }
    const songs: WebDavSong[] = library.songsForUi();
    const rows: CloudRow[] = [];
    for (const song of songs) {
      const row = new CloudRow();
      row.song = song;
      row.cached = library.isCached(song.key);
      row.busy = this.cachingKey.length > 0 && this.cachingKey === song.key;
      rows.push(row);
    }
    this.rows = rows;
    this.source.replaceAll(rows);
  }

  // ───────────────────────────────────────────── 扫描

  /** 配好服务器但还没扫过（或换了地址）时自动扫一次，用户不用先点一下刷新 */
  private async autoScanIfNeeded(): Promise<void> {
    if (!webDavCloudConfigured()) {
      return;
    }
    const library: WebDavLibrary = WebDavLibrary.getInstance();
    const config = webDavCloudConfig();
    if (library.scanRoot() === config.url && library.scanTime() > 0) {
      // 扫过同一地址：直接用缓存（这就是「别每次进页面都重拉整个目录」）
      hilog.info(DOMAIN, LOG_TAG, 'use cached scan rows=%{public}d', this.rows.length);
      return;
    }
    await this.scan(false);
  }

  /**
   * 扫描云端目录
   *
   * @param readTags 是否逐首读远端标签（首次扫描读一次，之后缓存里已有就不再问）
   */
  private async scan(readTags: boolean): Promise<void> {
    if (!webDavCloudConfigured()) {
      this.errorText = '';
      this.statusText = '还没有配置 WebDAV 服务器';
      return;
    }
    if (this.rows.length === 0) {
      this.loading = true;
    }
    this.errorText = '';
    this.progressText = '正在连接云服务器…';
    try {
      const result: WebDavScanResult = await WebDavLibrary.getInstance()
        .refresh(webDavCloudConfig(), readTags, (text: string) => {
          this.progressText = text;
        });
      this.progressText = '';
      if (WebDavLibrary.getInstance().lastScanCancelled()) {
        // 用户自己按的取消：不要报成「读不到云端曲库」（那会冤枉服务器）
        this.statusText = '已取消本次扫描';
        hilog.info(DOMAIN, LOG_TAG, 'scan cancelled by user');
      } else if (result.total === 0 && result.failedFolders > 0) {
        // 一个音频都没找到、还有目录读不到：这是失败态，给出可读文案 + 重试
        this.errorText = describeScan(result);
      } else {
        this.statusText = describeScan(result);
      }
      hilog.info(DOMAIN, LOG_TAG, 'scan finished total=%{public}d added=%{public}d dropped=%{public}d',
        result.total, result.added, result.dropped);
    } catch (e) {
      this.progressText = '';
      this.errorText = (e as Error).message;
      hilog.warn(DOMAIN, LOG_TAG, 'scan failed: %{public}s', (e as Error).message);
    } finally {
      this.loading = false;
      this.reloadRows();
      if (this.errorText.length === 0) {
        this.statusText = this.statusLine();
      }
    }
  }

  /** 下拉刷新：重新扫一遍（不重读远端标签，标签已经落盘了） */
  private async pullRefresh(): Promise<void> {
    this.refreshing = true;
    await this.scan(false);
    this.refreshing = false;
  }

  // ───────────────────────────────────────────── 播放

  /**
   * 点一行 = 播放这一首（**必须走全局播放入口**，不自己 push 播放页、不自己 new 播放器）
   *
   * 编排照 `features/setting` 的 `MinePage.playAllFavorites()`：
   *   1) `appState.replaceQueue([item], 0)` —— 队列真源在 `MusicAppState`；
   *   2) `intent.pendingQueueIndex = 0` + `openPlayerUi = true` + `requestVersion++`
   *      —— 壳层的 `@Monitor('intentState.requestVersion')` 会调
   *      `dispatchShellPlaybackIntent(...)`，由它去 `MediaService.loadAsset(0)` 并打开播放页。
   *
   * 与那条路的唯一差别：云端歌**要先落一份沙箱音频**（见 WebDavLibrary 文件头的取舍），
   * 所以这里先 await 下载、再入队；下载期间行上显示进度、并挡住重复点击。
   */
  private async playSong(song: WebDavSong, playNextOnly: boolean): Promise<void> {
    if (this.cachingKey.length > 0) {
      this.toast('正在缓存另一首，请稍候');
      return;
    }
    const library: WebDavLibrary = WebDavLibrary.getInstance();
    const cachedPath: string = library.localPathOf(song.key);
    if (cachedPath.length === 0) {
      this.cachingKey = song.key;
      this.cacheRatio = -1;
      this.reloadRows();
      this.toast(`正在把「${song.name}」缓存到本机…`);
      try {
        await library.download(song.key, webDavCloudConfig(), (progress: WebDavDownloadProgress) => {
          this.cacheRatio = progress.ratio;
        });
      } catch (e) {
        this.errorText = (e as Error).message;
        hilog.warn(DOMAIN, LOG_TAG, 'cache failed: %{public}s', (e as Error).message);
        this.toast((e as Error).message);
        // ★ 必须在这里返回：`finally` 只管收尾状态，**不会**取消这次播放 ——
        //   少了这一行，下载失败后还会往下走去入队/插队（用一条不存在的沙箱路径）。
        return;
      } finally {
        this.cachingKey = '';
        this.cacheRatio = -1;
        this.reloadRows();
      }
    }
    if (!library.isCached(song.key)) {
      this.errorText = '这一首没有落到本机，请重试';
      return;
    }
    if (playNextOnly) {
      const inserted: boolean = library.insertNext(song, this.appState);
      this.toast(inserted ? `已把「${song.name}」插到下一首` : '插队失败，刷新后再试');
      this.reloadRows();
      return;
    }
    const path: string = library.localPathOf(song.key);
    if (path.length === 0) {
      this.errorText = '缓存文件不见了，请重试';
      return;
    }
    const item: SongItem = library.songItemOf(song, path);
    this.appState.replaceQueue([item], 0);
    const intent: PlaybackIntentState = AppStorageV2.connect(PlaybackIntentState,
      AppStorageKeys.PLAYBACK_INTENT_STATE, (): PlaybackIntentState => new PlaybackIntentState())!;
    intent.pendingPlaySongId = -1;
    intent.pendingQueueIndex = 0;
    intent.openPlayerUi = true;
    intent.requestVersion++;
    hilog.info(DOMAIN, LOG_TAG, 'play requested key=%{public}s queue=1', song.key);
  }

  /** 把当前列表里已缓存的歌整批追加到播放队列（没有缓存的不动，避免静默下几十首） */
  private appendAllCachedToQueue(): void {
    const library: WebDavLibrary = WebDavLibrary.getInstance();
    const cached: WebDavSong[] = [];
    for (const row of this.rows) {
      if (row.cached) {
        cached.push(row.song);
      }
    }
    if (cached.length === 0) {
      this.toast('本机还没有缓存任何云端歌曲');
      return;
    }
    const added: number = library.appendToQueue(cached, this.appState);
    this.toast(added > 0 ? `已把 ${added} 首加入播放队列` : '这些歌已经在播放队列里了');
  }

  // ───────────────────────────────────────────── 缓存管理

  private dropCacheOf(song: WebDavSong): void {
    const library: WebDavLibrary = WebDavLibrary.getInstance();
    const before: WebDavSong | undefined = library.byKeyOf(song.key);
    const freed: number = before === undefined ? 0 : before.localBytes;
    const dropped: boolean = library.dropLocal(song.key);
    this.reloadRows();
    this.statusText = this.statusLine();
    if (dropped) {
      this.toast(`已删除本机缓存${freed > 0 ? `（释放 ${formatBytes(freed)}）` : ''}`);
    }
  }

  private clearAllCache(): void {
    const freed: number = WebDavLibrary.getInstance().clearLocalCache();
    this.reloadRows();
    this.statusText = this.statusLine();
    this.toast(freed > 0 ? `已清空本机缓存（释放 ${formatBytes(freed)}）` : '本机本来就没有缓存');
  }

  private openSettings(): void {
    // 这里**只给一句指路提示**，不自己 push 「设置」页：
    // 那条路要跨到 features/setting（本模块不许动别人，反向 import 也会绕出依赖环），
    // 而「我的 → 设置 → 同步 → WebDAV 备份」本来就摆在那儿 —— 编一个跳不过去的入口
    // 比老实告诉用户去哪填更糟。
    this.toast('请到「我的 → 设置 → 同步 → WebDAV 备份」里填服务器地址与账号（与云端音乐同一套配置）');
  }

  /**
   * HDS 标题栏（照 `SettingPage.getTitleBar()` 的那一套：透明 + 沉浸材质 + 滚动渐变模糊）
   *
   * `systemMaterialEffect` 用 `buildTitleMaterial(this.ambientState.level)` ——
   * **不要**写死 `MaterialType.NONE`，那正是「原本有光感、后来没了」的那个坑（见工程记忆 §17.2）。
   */
  private getTitleBar(): HdsNavigationTitleBarOptions {
    if (this.cachedTitleBar !== undefined) {
      return this.cachedTitleBar;
    }
    const back = (): void => {
      this.pathStack?.pop();
    };
    this.cachedTitleBar = {
      avoidLayoutSafeArea: true,
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            backIconStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary')
            },
            backIconStyle: {
              iconColor: $r('sys.color.font_primary'),
              backgroundColor: '#1AFFFFFF'
            }
          }
        },
        systemMaterialEffect: buildTitleMaterial(this.ambientState.level)
      },
      content: {
        title: {
          mainTitle: '云端音乐',
          mainTitleSize: TitleSize.TITLE_ML
        },
        backIcon: {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true,
          action: back
        }
      }
    };
    return this.cachedTitleBar;
  }

  private toast(message: string): void {
    if (message.length === 0) {
      return;
    }
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2600 });
  }

  // ───────────────────────────────────────────── 界面

  /** 顶部状态区：状态文案 + 动作胶囊 + 进度 */
  @Builder
  private statusBar() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text(this.statusText)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start)

        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(16)
            .fontColor([this.themeState.color])
          Text(webDavCloudConfigured() ? '刷新' : '去配置')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(this.themeState.color)
        }
        .padding({ left: 12, right: 14, top: 7, bottom: 7 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.capsule_background'))
        .accessibilityText(webDavCloudConfigured() ? '重新扫描云端目录' : '去配置 WebDAV 服务器')
        .accessibilityLevel('yes')
        .onClick(() => {
          if (!webDavCloudConfigured()) {
            this.openSettings();
            return;
          }
          // 手动刷新这一下**重新读一遍远端标签**（列表里显示的就是真名字而不是文件名）；
          // 下拉刷新与自动扫描都不读标签（缓存里已经有就别再问一遍）。
          void this.scan(true);
        })
      }
      .width('100%')

      // 缓存相关的两个入口只在有意义时出现（都在下面这一行，别挤占上面那条）
      if (this.rows.length > 0 && this.cachedBytes > 0) {
        Row({ space: 10 }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.music_note_list'))
              .fontSize(15)
              .fontColor([$r('sys.color.font_secondary')])
            Text('已缓存的入队')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius($r('sys.float.corner_radius_level12'))
          .backgroundColor($r('app.color.capsule_background'))
          .accessibilityText('把本机已缓存的云端歌曲加入播放队列')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.appendAllCachedToQueue();
          })

          Text('清空本机缓存')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(this.themeState.color)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius($r('sys.float.corner_radius_level12'))
            .backgroundColor($r('app.color.capsule_background'))
            .accessibilityText('清空本机缓存')
            .accessibilityLevel('yes')
            .onClick(() => {
              this.clearAllCache();
            })

          Blank()
        }
        .width('100%')
      }

      // 扫描 / 缓存进度（有进度才占位，避免空行）
      if (this.progressText.length > 0 || this.cachingKey.length > 0) {
        Row({ space: 10 }) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(this.themeState.color)
          Text(this.cacheProgressLabel())
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.progressText.length > 0) {
            Text('取消')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor(this.themeState.color)
              .padding({ left: 8, right: 4, top: 4, bottom: 4 })
              .onClick(() => {
                WebDavLibrary.getInstance().cancelScan();
              })
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 8 })
  }

  /** 进度那一行的文案：缓存优先（它是阻塞播放的那一步） */
  private cacheProgressLabel(): string {
    if (this.cachingKey.length > 0) {
      const percent: string = this.cacheRatio > 0 ? `${Math.round(this.cacheRatio * 100)}%` : '…';
      return `正在缓存到本机 ${percent}`;
    }
    return this.progressText;
  }

  /** 列表里的一行（版式照参考 `SongRow`：封面 / 名字 / 副标题 / 右侧更多） */
  @Builder
  private songRow(row: CloudRow) {
    Row({ space: 11 }) {
      // 封面占位：云端曲库没有内嵌封面（AVMetadataExtractor 的网络源读不到），
      // 也不去抓同目录图片（那会多一轮 PROPFIND + 下载），所以统一给一个音符占位块。
      // 这是**有意**的简化，不是漏做。
      Stack() {
        Text('♪')
          .fontSize(20)
          .fontColor(this.themeState.color)
      }
      .width(ROW_COVER_SIZE)
      .height(ROW_COVER_SIZE)
      .borderRadius($r('sys.float.corner_radius_level12'))
      .backgroundColor($r('app.color.capsule_background'))

      Column({ space: 4 }) {
        Text(row.song.name.length > 0 ? row.song.name : row.song.file)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
        Text(this.subtitleOf(row.song))
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (row.busy) {
        // 正在缓存这一行：进度条替代"更多"按钮（此刻点它也没有别的意义）
        Progress({ value: this.cacheRatio > 0 ? this.cacheRatio * 100 : 0, total: 100,
          type: ProgressType.Ring })
          .width(20)
          .height(20)
          .color(this.themeState.color)
          .style({ strokeWidth: 3 })
          .accessibilityLevel('no')
      } else {
        Text(row.cached ? '已缓存' : formatDuration(row.song.durationMs))
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .margin({ right: 2 })
        SymbolGlyph($r('sys.symbol.more'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_tertiary')])
          .padding({ left: 6, right: 2, top: 8, bottom: 8 })
          .bindMenu(this.rowMenu(row))
          .accessibilityText(`${row.song.name} 的更多操作`)
          .accessibilityLevel('yes')
      }
    }
    .width('100%')
    .height(ROW_HEIGHT)
    .padding({ left: 16, right: 14 })
    .onClick(() => {
      void this.playSong(row.song, false);
    })
    // 整行当一个节点：读屏读「歌名，副标题」，而不是把占位块、文字、图标逐个念一遍
    .accessibilityGroup(true)
    .accessibilityText(`${row.song.name.length > 0 ? row.song.name : row.song.file}，`
      + `${this.subtitleOf(row.song)}`)
    .accessibilityLevel('yes')
  }

  /** 行的副标题：`歌手 · 目录 · 大小`（缺哪项就少哪项，不留空 `·`） */
  private subtitleOf(song: WebDavSong): string {
    const parts: string[] = [];
    if (song.singer.length > 0) {
      parts.push(song.singer);
    }
    if (song.album.length > 0) {
      parts.push(song.album);
    } else {
      const folder: string = folderNameOf(song.folder);
      if (folder.length > 0) {
        parts.push(folder);
      }
    }
    if (song.sizeBytes > 0) {
      parts.push(formatBytes(song.sizeBytes));
    }
    return parts.join(' · ');
  }

  /** 行尾「更多」菜单：播放 / 下一首播放 / 加入播放队列 / 删除本机缓存 */
  private rowMenu(row: CloudRow): MenuElement[] {
    const items: MenuElement[] = [];
    items.push({
      value: '播放',
      action: (): void => {
        void this.playSong(row.song, false);
      }
    });
    items.push({
      value: '下一首播放',
      action: (): void => {
        void this.playSong(row.song, true);
      }
    });
    items.push({
      value: '加入播放队列',
      action: (): void => {
        const added: number = WebDavLibrary.getInstance().appendToQueue([row.song], this.appState);
        this.toast(added > 0 ? '已加入播放队列' : '这首歌已经在播放队列里了');
      }
    });
    if (row.cached) {
      items.push({
        value: '删除本机缓存',
        action: (): void => {
          this.dropCacheOf(row.song);
        }
      });
    }
    return items;
  }

  /** 空态 / 失败态 / 加载中：都放在 List 里，保证下拉刷新在这些状态下也能用 */
  @Builder
  private placeholder() {
    Column({ space: 12 }) {
      if (this.loading) {
        LoadingProgress()
          .width(34)
          .height(34)
          .color(this.themeState.color)
        Text('正在扫描云端目录…')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      } else if (this.errorText.length > 0) {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
          .fontSize(36)
          .fontColor([$r('sys.color.font_tertiary')])
        Text('读不到云端曲库')
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.errorText)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(16)
            .fontColor([this.themeState.color])
          Text('重试')
            .fontSize($r('sys.float.Body_S'))
            .fontColor(this.themeState.color)
        }
        .padding({ left: 16, right: 18, top: 9, bottom: 9 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('app.color.capsule_background'))
        .accessibilityText('重试扫描')
        .accessibilityLevel('yes')
        .onClick(() => {
          void this.scan(false);
        })
      } else if (!webDavCloudConfigured()) {
        SymbolGlyph($r('sys.symbol.cloud'))
          .fontSize(36)
          .fontColor([$r('sys.color.font_tertiary')])
        Text('云端音乐 = 自己 WebDAV 服务器上的音乐')
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('还没有配置服务器。凭据与基址沿用「设置 → 同步 → WebDAV 备份」那一套，'
          + '配置好之后回到这里扫一遍，目录里的音乐就直接能播 —— 不用先导入什么。')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
      } else {
        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize(36)
          .fontColor([$r('sys.color.font_tertiary')])
        Text('云端曲库还是空的')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
        Text('这个目录（含子目录）里没有扫到能播的音频。'
          + '检查一下「设置 → 同步 → WebDAV 备份」里填的目录是不是音乐目录，或下拉刷新重扫一次。')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
      }
    }
    .width('100%')
    .padding({ top: 72, bottom: 40 })
    .justifyContent(FlexAlign.Center)
  }

  build() {
    // HdsNavDestination 放在页面自己的 build 里（与 `SyncSettingsView` / `SettingPage` 同构）：
    // 这样 `.titleBar(this.getTitleBar())` / `.onReady(...)` 里的 `this` 就是本页面实例，
    // 能直接拿到 `ambientState.level` 与 `pathStack` —— 全局 `@Builder` 里拿不到组件的 `this`。
    HdsNavDestination() {
      Column() {
        this.statusBar()

        Refresh({ refreshing: this.refreshing!! }) {
          List({ space: 0 }) {
            ListItem() {
              this.placeholder()
            }
            .width('100%')
            // 有内容时不渲染占位块（用 visibility 而不是 if：占位块就是这个 ListItem 的内容，
            // 包一层 if 反而要在 LazyForEach 前后各切一次结构）
            .visibility(this.rows.length === 0 ? Visibility.Visible : Visibility.None)

            LazyForEach(this.source, (row: CloudRow) => {
              ListItem() {
                Column() {
                  this.songRow(row)
                  Divider()
                    .strokeWidth(0.5)
                    .color($r('sys.color.comp_divider'))
                    .margin({ left: ROW_DIVIDER_INSET, right: 14 })
                }
                .width('100%')
              }
              .width('100%')
              .accessibilityLevel('yes')
            }, (row: CloudRow) => row.song.key)

            // 底部预留：避开系统手势条（本页不挂壳层迷你条，二级页也不需要 56 的页签高度）
            ListItem() {
              Row() {
              }
              .width('100%')
              .height(32)
            }
            .width('100%')
            .accessibilityLevel('no')
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .cachedCount(6)
        }
        .width('100%')
        .layoutWeight(1)
        .refreshOffset(64)
        .pullToRefresh(true)
        .onRefreshing(() => {
          void this.pullRefresh();
        })
      }
      .width('100%')
      .height('100%')
      // HDS 标题栏是 overlay：页面自己留出「状态栏 + 标题栏那一行」的顶部内边距，
      // 否则内容会从标题底下穿过去（工程里 24+ 个二级页都这么做）
      .padding({ top: getStatusBarTopVpFromWindowUtil() + TITLE_BAR_ROW_VP })
      .backgroundColor($r('app.color.background_secondary'))
    }
    .titleBar(this.getTitleBar())
    .hideTitleBar(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .onBackPressed((): boolean => guardPlayerBack('CloudMusicPage'))
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .backgroundColor($r('app.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

/**
 * 路由页入口（`features/sync/router_map.json` 的 `CloudMusicPage`）
 *
 * 只负责new 出页面；标题栏 / 返回 / 安全区全在页面自己的 `build()` 里挂（见上）。
 */
@Builder
export function CloudMusicPageBuilder(name: string, param: Object) {
  CloudMusicPage()
}
