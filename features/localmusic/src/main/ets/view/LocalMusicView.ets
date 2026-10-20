/*
 * 「本地音乐」页面（导入设备音频 / 列表 / 删除）
 *
 * 对应 listen 的文件：entry/src/main/ets/views/LocalMusicView.ets
 *
 * 适配点：
 *  - listen 是「我的」页里的一个分段面板（@Component + ArkUI V1 的 @Prop/@State/@StorageLink），
 *    且列表复用 PlaylistView 的 SongListPane。RzdMusic 这里改成路由页（router_map.json 登记为
 *    LocalMusicPage，入口函数 LocalMusicPageBuilder）+ ArkUI 状态管理 V2（@ComponentV2 + @Local/@Monitor），
 *    列表自绘（不复用 listen 的 ui/Widgets，RzdMusic 里没有那几个文件）。
 *  - 主题色走 musicbasic 的 ThemeState（AppStorageV2），颜色 / 字号一律用系统资源
 *    （$r('sys.color.*') / $r('sys.float.*')）：本 HAR 的 resources 下只有一条字符串资源，
 *    用不了 app.* 资源（那是各模块自己的资源表）。
 *  - 进度 / 库版本：listen 的 @StorageLink(K_LOCAL_PROGRESS / K_LOCAL_VERSION) ->
 *    @Local importState: LocalMusicImportState（AppStorageV2，@Monitor 监听 version / progress）。
 *  - 导入 / 删除入口保留：导入按钮的菜单（选音乐文件 / 选音乐文件夹）走
 *    LocalMusic.importFiles / importFolder；删除走 removeLocalSongs（额外把播放队列里的同一条摘掉，
 *    对应 listen 的 PlaySession.dropLocalSongs）。
 *  - 播放：listen 走 PlaySession.playAt。RzdMusic 的播放链路接入由主 agent 负责，这里按
 *    MusicAppState.replaceQueue + MediaService.loadAsset 发起（见 playAt 的注释）。
 */

import { AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions } from '@kit.UIDesignKit';
import { guardPlayerBack } from 'musicbasic';
import {
  AmbientState,
  AppStorageKeys,
  barBlurOptions,
  buildBarBlurStyle,
  MusicAppState,
  PlayedSongRecord,
  RouterUrlConstants,
  SelectionActionCell,
  SongItem,
  SongTitleMarquee,
  ThemeState,
  getStatusBarTopVpFromWindowUtil
} from 'musicbasic';
import { DownloadService, DownloadStatus, DownloadTask, MediaService, OnlinePlayUtil } from 'player';
import {
  ImportResult,
  LocalMusicImportState,
  localMusic,
  localMusicImportState
} from '../core/LocalMusic';
import { LyricMatchSheet } from './LyricMatchSheet';
import type { MatchSongInfo } from '../core/LyricMatch';

const DOMAIN: number = 0x0001;
const TAG: string = 'LocalMusicPage';

/** 歌手 / 专辑格的分组条目（本地库按 `singer` / `albumName` 聚合出来的临时结构）。 */
class LocalGroupEntry {
  /** 组名（歌手名 / 专辑名）。 */
  name: string = '';
  /** 组内首数。 */
  count: number = 0;
  /** 封面（取组里第一首的）。 */
  img: string = '';
  /** 组内第一首在 `items` 里的下标（点一行就从这首开始播）。 */
  firstIndex: number = 0;
}

/**
 * 跳到设置详情页「下载管理」那一档用的路由参数。
 *
 * ⚠️ 形状必须与 `features/setting` 的 `SettingsDetailRouteParam`（`{ index: number }`）一致：
 *    三层架构禁止 features 之间互相 import（`setting → localmusic` 是既有方向，反向会成环），
 *    所以这里放一个**同形**的本地类；接收端 `SettingsDetailPageBuilder` 是按字段读的，跑得通。
 */
class LocalSettingsDetailParam {
  index: number = 10;
}

/** 设置详情页里「下载管理」那一档的下标（与 `MinePage.DOWNLOAD_SHEET_INDEX` 同一口径）。 */
const DOWNLOAD_SHEET_INDEX: number = 10;

/**
 * 本地音乐页（路由页）
 *
 * 为什么是「导入」而不是「扫描本机音乐」：系统不把音乐库开放给三方应用读
 * （ohos.permission.READ_AUDIO 是受限权限，只批克隆/备份/同步场景；也没有枚举
 * 音频媒体的 API），官方给的正路是让用户用 Picker 选。选中的 URI 只有临时权限，
 * 退到后台就失效，所以选中后立刻拷一份进沙箱 —— 从此不看系统脸色。
 */
@ComponentV2
export struct LocalMusicPage {
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** 底部操作条的光感档位（与标题栏同档，见 musicbasic `BarMaterial`）。 */
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  /** 导入进度 / 库版本（导入、删除、歌词匹配变化都会 +1） */
  @Local importState: LocalMusicImportState = localMusicImportState();
  /** 当前列表快照（倒序：新导入在最前） */
  @Local items: SongItem[] = [];
  /** 多选删除模式 */
  @Local selectionMode: boolean = false;
  /** 多选勾选表（key = 本地 key） */
  @Local selectedMap: Record<string, boolean> = {};
  /**
   * 分类页签（用户 2026-10-20）：`song` / `singer` / `album` / `download`。
   *
   * 「本地=歌曲/歌手/专辑」是 6a 点名的三格；`download` 是 6b「下载页并入本地页面」的落点
   * （原来「我的 → 下载管理」那一页的内容，已完成的下载任务就在这里）。
   */
  @Local category: string = 'song';
  /** 「已下载」格的数据源（`DownloadService` 里 COMPLETED 的任务快照）。 */
  @Local downloadedTasks: DownloadTask[] = [];
  /**
   * 顶部**浮层头**的实测高度（vp）：文案行 + 页签 + 播放全部。
   * 列表用它做 `contentStartOffset`，这样第一行不会被浮层盖住，而列表滚动时又能**从浮层下面穿过**
   * （材质背板才有东西可采 = 真光感）。
   */
  @Local topOverlayH: number = 128;
  /** 一键匹配进行中 */
  @Local matchingAll: boolean = false;
  @Local matchProgress: string = '';
  /** 单曲手动匹配面板 */
  @Local showMatchSheet: boolean = false;
  @Local matchSheetKey: string = '';
  @Local matchSheetName: string = '';
  @Local matchSheetSinger: string = '';
  @Local matchSheetDurationMs: number = 0;
  /** 路由栈（与 MinePage 同一个 @Provider 名，用于返回） */
  @Consumer('pageIndexInfos') pageStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.ensureInit();
    this.refresh();
  }

  /**
   * 页面销毁时**必须**把 `selectionActive` 复位。
   *
   * 否则用户在多选态直接返回上一页 ⇒ 壳层那条悬浮播放条会一直不显示（全局开关卡在 true）。
   */
  aboutToDisappear(): void {
    if (this.appState.selectionActive) {
      this.appState.selectionActive = false;
      hilog.info(DOMAIN, TAG, 'reset selectionActive on disappear');
    }
  }

  /** 库变化（导入完成 / 删除 / 歌词匹配）后重新读列表 */
  @Monitor('importState.version')
  onLibraryChanged(): void {
    this.refresh();
  }

  /** 兜底：宿主还没调过 init 时这里自己初始化（拿 UIContext 的 host context） */
  private ensureInit(): void {
    if (localMusic.isReady()) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      localMusic.init(context as common.UIAbilityContext);
    }
  }

  private refresh(): void {
    // ★ 2026-10-20：先扫私有目录（下载会**无条件**在这里留一份）⇒ 下载完的曲子直接出现在
    //   歌曲列表里，不需要"下载管理"另存一份数据（用户：「直接扫一下私有目录列出来」）。
    const scanned: number = localMusic.scanDir();
    if (scanned > 0) {
      hilog.info(DOMAIN, TAG, 'scanDir adopted %{public}d file(s)', scanned);
    }
    // ★ 2026-10-20（用户：「看看现在有没有处理本地文件被删除的情况」）：
    //   `sweepOrphans()` 会把「索引里有、文件已经不在」的条目清掉。原来它只在初始化时跑一次，
    //   运行中被删掉的歌要等重启才消失 ⇒ 每次进页/刷新都补跑一次（内部有 ready 判断，很轻）。
    localMusic.sweepOrphans();
    this.items = localMusic.getSongItems();
    this.refreshDownloaded();
  }

  /** 拉一次「已下载」快照（只取 COMPLETED，未完成的仍在下载管理页里看）。 */
  private refreshDownloaded(): void {
    const all: DownloadTask[] = DownloadService.getInstance().getTasksSnapshot();
    const done: DownloadTask[] = [];
    for (let i: number = 0; i < all.length; i++) {
      if (all[i].status === DownloadStatus.COMPLETED) {
        done.push(all[i]);
      }
    }
    this.downloadedTasks = done;
  }

  private toast(message: string): void {
    // 导入可能跨越「切走再回来」：组件已经销毁时 getUIContext 会抛，
    // 那时提示丢掉就行，别让一个 toast 把导入流程带崩
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'toast skipped: %{public}s', JSON.stringify(e));
    }
  }

  private hostContext(): common.UIAbilityContext | null {
    const context = this.getUIContext().getHostContext();
    return context === undefined ? null : context as common.UIAbilityContext;
  }

  // ------------------------------------------------------------ 导入

  @Builder
  private importMenu() {
    Menu() {
      MenuItem({ content: '选择音乐文件' })
        .onClick(() => {
          void this.pickFiles();
        })
      MenuItem({ content: '选择音乐文件夹' })
        .onClick(() => {
          void this.pickFolder();
        })
    }
    .font({ size: 16 })
  }

  /** 选文件：AudioViewPicker（音频专用、可多选、零权限） */
  private async pickFiles(): Promise<void> {
    const context: common.UIAbilityContext | null = this.hostContext();
    if (context === null) {
      this.toast('当前环境不支持选择文件');
      return;
    }
    const result: ImportResult = await localMusic.importFiles(context);
    this.afterImport(result);
  }

  /** 选文件夹：DocumentViewPicker 的 FOLDER 模式（手机一次只能选一个目录） */
  private async pickFolder(): Promise<void> {
    const context: common.UIAbilityContext | null = this.hostContext();
    if (context === null) {
      this.toast('当前环境不支持选择文件夹');
      return;
    }
    const result: ImportResult = await localMusic.importFolder(context);
    this.afterImport(result);
  }


  /**
   * 一键匹配封面 / 歌词 / 评论源（平台顺序 QQ→网易→酷狗→酷我→咪咕）。
   * 匹配结果写入 matchJson，播放页评论可据此拉平台评论。
   */
  private async runMatchAll(): Promise<void> {
    if (this.matchingAll || this.items.length === 0) {
      return;
    }
    this.matchingAll = true;
    this.matchProgress = '准备匹配…';
    try {
      const result = await localMusic.matchAllOnline((done: number, total: number, name: string): void => {
        this.matchProgress = `${done}/${total} ${name}`;
      });
      const msg: string = `匹配完成：成功 ${result.ok} 首，失败 ${result.fail} 首，共 ${result.total} 首`;
      this.matchProgress = msg;
      this.toast(msg);
      try {
        this.getUIContext().getPromptAction().showToast({ message: msg, duration: 3500 });
      } catch (_e) {
      }
      this.refresh();
    } catch (e) {
      this.toast('匹配失败，请检查网络与音源');
      hilog.warn(DOMAIN, TAG, 'matchAll failed: %{public}s', JSON.stringify(e));
    } finally {
      this.matchingAll = false;
      this.matchProgress = '';
    }
  }

  private afterImport(result: ImportResult): void {
    const text: string = result.message.length > 0 ? result.message : describeImport(result);
    this.toast(text);
    this.refresh();
  }

  // ------------------------------------------------------------ 多选 / 删除

  private keyOf(item: SongItem): string {
    return item.songId;
  }

  private isSelected(item: SongItem): boolean {
    return this.selectedMap[this.keyOf(item)] === true;
  }

  private toggleSelect(item: SongItem, on: boolean): void {
    const next: Record<string, boolean> = {};
    const keys: string[] = Object.keys(this.selectedMap);
    for (let i: number = 0; i < keys.length; i++) {
      next[keys[i]] = this.selectedMap[keys[i]];
    }
    next[this.keyOf(item)] = on;
    this.selectedMap = next;
  }

  private selectedKeys(): string[] {
    const out: string[] = [];
    const keys: string[] = Object.keys(this.selectedMap);
    for (let i: number = 0; i < keys.length; i++) {
      if (this.selectedMap[keys[i]] === true) {
        out.push(keys[i]);
      }
    }
    return out;
  }

  private selectedCount(): number {
    return this.selectedKeys().length;
  }

  private enterSelectionMode(): void {
    this.selectionMode = true;
    this.selectedMap = {};
    // ★ 用户 2026-10-19：多选时底部要放操作条 ⇒ 让壳层把那条悬浮播放条**临时隐藏**
    //   （全局唯一开关 `MusicAppState.selectionActive`，与历史/收藏页同一口径）
    this.appState.selectionActive = true;
  }

  private exitSelectionMode(): void {
    this.selectionMode = false;
    this.selectedMap = {};
    this.appState.selectionActive = false;
  }

  private toggleSelectAll(): void {
    const next: Record<string, boolean> = {};
    if (this.selectedCount() < this.items.length) {
      for (let i: number = 0; i < this.items.length; i++) {
        next[this.keyOf(this.items[i])] = true;
      }
    }
    this.selectedMap = next;
  }

  /** 删除前问一句（设备里的原文件不受影响） */
  private confirmRemove(): void {
    const keys: string[] = this.selectedKeys();
    if (keys.length === 0) {
      return;
    }
    const what: string = keys.length === 1 ? '这 1 首' : `这 ${keys.length} 首`;
    this.getUIContext().showAlertDialog({
      title: '从本地音乐移除',
      message: `将删除${what}在应用内的副本（设备里的原文件不受影响）。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: '#E53935',
        action: () => {
          const removed: number = removeLocalSongs(keys);
          this.exitSelectionMode();
          this.refresh();
          this.toast(`已移除 ${removed} 首`);
        }
      }
    });
  }

  // ------------------------------------------------------------ 播放

  /**
   * 播放列表里的一条
   *
   * **主 agent 接线要点**：本地歌的播放直路（source === 'local' -> fs.openSync(url) 拿 fd
   * 交给 AVPlayer，不做音源解析、不预取、不问平台要封面/歌词）要在 MediaService 里补；
   * 补上之后本方法不用改：队列已经换成本地歌条目、url 已是沙箱绝对路径。
   */
  private playAt(index: number): void {
    if (index < 0 || index >= this.items.length) {
      return;
    }
    const target: SongItem = this.items[index];
    if (target.url.length === 0) {
      this.toast('本地文件路径无效，请重新导入');
      return;
    }
    // 复制队列快照，避免列表刷新后引用失效
    const queue: SongItem[] = [];
    for (let i: number = 0; i < this.items.length; i++) {
      queue.push(this.items[i]);
    }
    this.appState.replaceQueue(queue, index);
    this.appState.currentQuality = 'local';
    this.appState.isResolving = false;
    this.appState.isShowPlay = true;
    void MediaService.getInstance().loadAsset(index);
  }

  private openMatchFor(item: SongItem): void {
    this.matchSheetKey = item.songId;
    this.matchSheetName = typeof item.title === 'string' ? item.title : '';
    this.matchSheetSinger = typeof item.singer === 'string' ? item.singer : '';
    this.matchSheetDurationMs = 0;
    try {
      this.matchSheetDurationMs = localMusic.durationMsOf(item.songId);
    } catch (_e) {
    }
    this.showMatchSheet = true;
  }

  private onMatchPicked(_info: MatchSongInfo, _source: string): void {
    this.showMatchSheet = false;
    this.toast('已匹配，封面/歌词/评论将按所选平台使用');
    this.refresh();
  }

  // ------------------------------------------------------------ 界面

  /**
   * 底部预留：壳层那条官方浮动播放条(56) + 间距(16) + 呼吸空间(16)。
   * 与 `RecordListPage.bottomReservedVp()` 同一口径。
   */
  private bottomReservedVp(): number {
    // 多选时壳层那条播放条已临时隐藏（`MusicAppState.selectionActive`），改为给底部操作条让位
    return 56 + 16 + 16 + (this.selectionMode ? 76 : 0);
  }

  /**
   * HDS 标题栏右侧菜单（用户 2026-10-12：「那个匹配、选择、导入像歌单页一样放进菜单」）。
   *
   * 自绘 Header 里那三个按钮/那颗红胶囊全部撤掉，能力一个不少地搬到这里；
   * 选中模式 / 一键匹配进行中时不显示（避免和底部的批量操作条打架）。
   * @returns 标题栏菜单项（按当前状态动态生成）。
   */
  private titleMenus(): HdsNavigationMenuItemOptions[] {
    const out: HdsNavigationMenuItemOptions[] = [];
    if (this.items.length > 0 && !this.selectionMode && !this.matchingAll) {
      out.push({
        content: {
          label: '一键匹配',
          icon: $r('sys.symbol.wand_and_stars'),
          isEnabled: true,
          action: (): void => {
            void this.runMatchAll();
          }
        }
      });
      out.push({
        content: {
          label: '选择',
          icon: $r('sys.symbol.checkmark_circle'),
          isEnabled: true,
          action: (): void => {
            this.enterSelectionMode();
          }
        }
      });
    }
    if (!this.selectionMode && !this.matchingAll) {
      // ★ 用户 2026-10-20：「下载管理页面是放到标题栏的按钮跳转」⇒ 这里加一颗入口，
      //   跳到设置详情页的「下载管理」那一档（`SettingsDetailRouteParam.index = 10`，
      //   与「我的」页原来那一格是同一个页面、同一份实现，没有第二套代码）。
      out.push({
        content: {
          label: '下载管理',
          icon: $r('sys.symbol.download_fill'),
          isEnabled: true,
          action: (): void => {
            const param = new LocalSettingsDetailParam();
            param.index = DOWNLOAD_SHEET_INDEX;
            this.pageStack.pushPathByName(RouterUrlConstants.SETTINGS_DETAIL, param);
            hilog.info(DOMAIN, TAG, 'open download manager');
          }
        }
      });
      out.push({
        content: {
          label: '导入音乐',
          icon: $r('sys.symbol.plus'),
          isEnabled: true,
          action: (): void => {
            void this.pickFiles();
          }
        }
      });
      out.push({
        content: {
          label: '导入文件夹',
          icon: $r('sys.symbol.folder'),
          isEnabled: true,
          action: (): void => {
            void this.pickFolder();
          }
        }
      });
    }
    return out;
  }
  @Builder
  private Header() {
    Column({ space: 8 }) {

      Row({ space: 8 }) {
        Text(this.items.length > 0 ?
          `${this.items.length} 首 · ${formatBytes(localMusic.totalBytes())}` : '还没有导入本地音乐')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  /** 导入进度 + 取消 */
  @Builder
  private ProgressBar() {
    Row({ space: 10 }) {
      Text(this.importState.progress.length > 0 ?
        `正在导入 ${this.importState.progress}` : '正在导入…')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('取消')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor(this.themeState.color)
        .padding({ left: 8, right: 4 })
        .onClick(() => {
          localMusic.cancelImport();
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .margin({ left: 16, right: 16 })
    .borderRadius($r('sys.float.corner_radius_level4'))
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private MatchSheetBuilder() {
    LyricMatchSheet({
      songKey: this.matchSheetKey,
      songName: this.matchSheetName,
      singer: this.matchSheetSinger,
      durationMs: this.matchSheetDurationMs,
      onPick: (info: MatchSongInfo, source: string): void => {
        this.onMatchPicked(info, source);
      }
    })
  }

  @Builder
  private MatchProgressBar() {
    Row({ space: 10 }) {
      Text(this.matchProgress.length > 0 ?
        `正在匹配 ${this.matchProgress}` : '正在匹配封面/歌词…')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('QQ→网易→酷狗→酷我→咪咕')
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .margin({ left: 16, right: 16 })
    .borderRadius($r('sys.float.corner_radius_level4'))
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /**
   * 分类页签（用户 2026-10-20 截图口径）：文字页签，选中项 `font_primary` + 下方主题色短横线。
   *
   * ★ 2026-10-20 第二轮：
   *  · 「已下载」这一格**删掉**（用户：「不要已下载 Tab，已下载直接放歌曲里」），
   *    下载完成的歌现在直接混在「歌曲」列表尾部（见 build 里的 `DownloadedRow`）；
   *  · 页签**左对齐**（原来套了 `Scroll(Horizontal)` 且内容居中，看着像居中排版）——
   *    三格用普通 Row + `justifyContent(Start)` 就够，不需要横滚。
   */
  @Builder
  private CategoryTabs() {
    Row({ space: 0 }) {
      this.CategoryTab('歌曲', 'song')
      this.CategoryTab('歌手', 'singer')
      this.CategoryTab('专辑', 'album')
      Blank()
    }
    .width('100%')
    .height(46)
    .padding({ left: 6 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  /** 单个页签。 */
  @Builder
  private CategoryTab(label: string, key: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(this.category === key ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.category === key ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
      Row()
        .width(this.category === key ? 18 : 0)
        .height(2.5)
        .borderRadius(1.25)
        .backgroundColor(this.themeState.color)
        .animation({ duration: 160, curve: Curve.Friction })
    }
    .height(46)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 10, right: 10 })
    .onClick((): void => {
      if (this.category !== key) {
        this.category = key;
        hilog.info(DOMAIN, TAG, 'category=%{public}s', key);
      }
    })
  }

  /**
   * 「播放全部 N」（用户 2026-10-20：参考歌单页的，不要圆形按钮）。
   * 与 `PlaylistDetailSongListSection.PlayAllHeader()` 逐项对齐：
   * `play_round_triangle_fill` 32vp 描边三角（无圆底）+「播放全部」+ 首数。
   */
  @Builder
  private PlayAllRow() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
        .fontSize(32)
        .fontWeight(FontWeight.Regular)
        .height(32)
        .fontColor([$r('sys.color.font_primary')])
      Text('播放全部')
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .lineHeight(24)
        .fontColor($r('sys.color.font_primary'))
      Text(`${this.playAllCount()}`)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .lineHeight(24)
        .fontColor($r('sys.color.font_primary'))
      Blank()
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.playAll();
    })
  }

  /** 「播放全部」按钮上的条数（歌曲格 = 本地歌 + 已下载）。 */
  private playAllCount(): number {
    if (this.category === 'song') {
      return this.items.length;
    }
    return this.groupEntries().length;
  }

  /** 播放全部：歌曲格 = 整列表；别的格 = 把该分类里能播的歌拼成一队。 */
  private playAll(): void {
    if (this.category === 'song') {
      this.playAt(0);
      return;
    }
    let first: number = -1;
    for (let i: number = 0; i < this.items.length; i++) {
      if (this.matchesCategory(this.items[i])) {
        first = i;
        break;
      }
    }
    if (first < 0) {
      this.toast('这个分类里还没有歌曲');
      return;
    }
    this.playAt(first);
  }

  /** 本地歌是否属于当前分类（歌手/专辑按名字取；已下载走下载任务，与本地库无关）。 */
  private matchesCategory(item: SongItem): boolean {
    if (this.category === 'singer' || this.category === 'album') {
      return this.groupNameOf(item).length > 0;
    }
    return true;
  }

  /** 分组的名字：歌手格取 `singer`，专辑格取 `albumName`。 */
  private groupNameOf(item: SongItem): string {
    if (this.category === 'album') {
      return typeof item.albumName === 'string' ? item.albumName : '';
    }
    return typeof item.singer === 'string' ? item.singer : '';
  }

  /** 歌手 / 专辑格的分组条目（按名字聚合，保留首次出现顺序）。 */
  private groupEntries(): LocalGroupEntry[] {
    if (this.category === 'song') {
      return [];
    }
    const out: LocalGroupEntry[] = [];
    const indexByName: Map<string, number> = new Map<string, number>();
    for (let i: number = 0; i < this.items.length; i++) {
      const item: SongItem = this.items[i];
      const raw: string = this.groupNameOf(item);
      const name: string = raw.length > 0 ? raw : (this.category === 'album' ? '未知专辑' : '未知歌手');
      const hit: number | undefined = indexByName.get(name);
      if (hit === undefined) {
        const entry: LocalGroupEntry = new LocalGroupEntry();
        entry.name = name;
        entry.count = 1;
        entry.img = item.cover;
        entry.firstIndex = i;
        indexByName.set(name, out.length);
        out.push(entry);
      } else {
        out[hit].count = out[hit].count + 1;
      }
    }
    return out;
  }

  /** 歌手 / 专辑格的一行：封面 + 名字 + 首数，点一行就从这组第一首开始播。 */
  @Builder
  private GroupRow(entry: LocalGroupEntry) {
    Row({ space: 12 }) {
      if (entry.img.length > 0) {
        Image(entry.img)
          .width(44)
          .height(44)
          .borderRadius($r('sys.float.corner_radius_level3'))
          .objectFit(ImageFit.Cover)
          .backgroundColor($r('sys.color.background_tertiary'))
      } else {
        Row() {
          SymbolGlyph(this.category === 'album' ?
            $r('sys.symbol.square_stack_3d_fill') : $r('sys.symbol.person_crop_circle_fill_1'))
            .fontSize(18)
            .fontColor([$r('sys.color.font_tertiary')])
        }
        .width(44)
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level3'))
        .backgroundColor($r('sys.color.background_tertiary'))
        .justifyContent(FlexAlign.Center)
      }
      Column({ space: 3 }) {
        Text(entry.name)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(entry.count + ' 首')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(18)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick((): void => {
      this.playAt(entry.firstIndex);
    })
  }

  /** 「已下载」格的一行：点一下就地播这个下载文件。 */
  @Builder
  private DownloadedRow(task: DownloadTask) {
    Row({ space: 12 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.download_fill'))
          .fontSize(18)
          .fontColor([this.themeState.color])
      }
      .width(44)
      .height(44)
      .borderRadius($r('sys.float.corner_radius_level3'))
      .backgroundColor($r('sys.color.background_tertiary'))
      .justifyContent(FlexAlign.Center)
      Column({ space: 3 }) {
        Text(task.name)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(task.singer + (task.quality.length > 0 ? ' · ' + task.quality : ''))
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(18)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick((): void => {
      this.playDownloaded(task);
    })
  }

  /** 播一个已下载的文件（与下载管理页同一条路：`source='local'` 直接播）。 */
  private playDownloaded(task: DownloadTask): void {
    const record: PlayedSongRecord = new PlayedSongRecord();
    record.source = 'local';
    record.songId = task.id;
    record.name = task.name;
    record.singer = task.singer;
    record.albumName = task.albumName;
    record.img = task.imgUrl;
    record.quality = task.quality;
    record.url = task.tempPath.length > 0 ? task.tempPath : task.fileName;
    record.time = Date.now();
    void OnlinePlayUtil.playRecord(this.appState, record, this.getUIContext());
  }

  /**
   * 多选底部操作条（用户 2026-10-19：本地音乐「沿用新样式」）。
   *
   * 与 `RecordListPage.SelectionActionBar()` **同一套观感**（同为 musicbasic 的
   * `SelectionActionCell` + `BarMaterial` 材质背板）：
   * - 悬浮胶囊：材质背板（`adaptiveColor = AVERAGE` 才有光感）+ 细分隔线 + 投影；
   * - ⚠️ 2026-10-20：点光（发光）按用户要求**已删除**，不要再加 `.visualEffect(...)`；
   * - **没有蓝色底**：删除用用户自定义主题色，其余文字走 `font_primary`。
   */
  @Builder
  private SelectionBar() {
    Row({ space: 4 }) {
      SelectionActionCell({
        icon: $r('sys.symbol.checkmark_circle'),
        label: this.selectedCount() === this.items.length && this.items.length > 0 ? '取消全选' : '全选',
        tint: $r('sys.color.font_primary'),
        onTap: (): void => {
          this.toggleSelectAll();
        }
      })
      SelectionActionCell({
        icon: $r('sys.symbol.trash'),
        label: this.selectedCount() > 0 ? `删除(${this.selectedCount()})` : '删除',
        tint: this.themeState.color,
        onTap: (): void => {
          this.confirmRemove();
        }
      })
      SelectionActionCell({
        icon: $r('sys.symbol.xmark'),
        label: '取消',
        tint: $r('sys.color.font_primary'),
        onTap: (): void => {
          this.exitSelectionMode();
        }
      })
    }
    .width('100%')
    .height(66)
    .padding({ left: 6, right: 6 })
    .borderRadius(33)
    .backgroundBlurStyle(buildBarBlurStyle(this.ambientState.level), barBlurOptions())
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.28)', offsetX: 0, offsetY: 8 })
  }

  /** 单条本地歌行 */
  @Builder
  private SongRow(item: SongItem) {
    Row({ space: 12 }) {
      if (this.selectionMode) {
        Toggle({ type: ToggleType.Checkbox, isOn: this.isSelected(item) })
          .width(24)
          .height(24)
          .selectedColor(this.themeState.color)
          .onChange((isOn: boolean) => {
            this.toggleSelect(item, isOn);
          })
      }
      if (item.cover.length > 0) {
        Image(item.cover)
          .width(44)
          .height(44)
          .borderRadius($r('sys.float.corner_radius_level3'))
          .objectFit(ImageFit.Cover)
          .backgroundColor($r('sys.color.background_tertiary'))
      } else {
        Row() {
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(18)
            .fontColor([$r('sys.color.font_tertiary')])
        }
        .width(44)
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level3'))
        .backgroundColor($r('sys.color.background_tertiary'))
        .justifyContent(FlexAlign.Center)
      }

      Column({ space: 3 }) {
        // ★ 歌名过长时跑马灯（用户要求「各个页面歌曲名过长时改为用跑马灯显示」）。
        //   字号/字色逐字保留；`textAlign(TextAlign.Start)` 本来就是默认值，
        //   且 `TextOverflow.MARQUEE` 生效时官方注明 textAlign 不生效 ⇒ 一并去掉。
        SongTitleMarquee({
          text: typeof item.title === 'string' ? item.title : '',
          titleFontSize: $r('sys.float.Body_L'),
          titleFontColor: $r('sys.color.font_primary'),
          titleFontWeight: FontWeight.Normal
        })
        Row({ space: 8 }) {
          Text(typeof item.singer === 'string' ? item.singer : '')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          if (item.interval.length > 0) {
            Text(item.interval)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          // 本地歌没有平台身份：这里固定标「本地」，音质 / 下载入口一概不出现
          Text('本地')
            .fontSize($r('sys.float.Caption_S'))
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius($r('sys.float.corner_radius_level2'))
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor('#4A90D9')
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (!this.selectionMode) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_tertiary')])
          .padding({ left: 4, right: 8 })
          .onClick(() => {
            this.openMatchFor(item);
          })
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_tertiary')])
          .onClick(() => {
            let idx: number = -1;
            for (let i: number = 0; i < this.items.length; i++) {
              if (this.items[i].songId === item.songId) {
                idx = i;
                break;
              }
            }
            this.playAt(idx);
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick(() => {
      if (this.selectionMode) {
        this.toggleSelect(item, !this.isSelected(item));
        return;
      }
      let idx: number = -1;
      for (let i: number = 0; i < this.items.length; i++) {
        if (this.items[i].songId === item.songId) {
          idx = i;
          break;
        }
      }
      this.playAt(idx);
    })
  }

  /** 空状态：把「为什么必须导入」讲清楚 */
  @Builder
  private EmptyGuide() {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.music_note_list'))
        .fontSize(56)
        .fontColor([$r('sys.color.font_tertiary')])
      Text('还没有导入本地音乐')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text('系统不允许应用直接读取设备里的音乐库，所以本地音乐需要手动导入：'
        + '点右上角「导入」选文件或文件夹，选中的音乐会拷一份到应用内（原文件不动）。'
        + '支持 mp3 / flac / m4a / aac / ogg / wav / amr；同目录下的同名 .lrc 歌词会一起导入。')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .lineHeight(18)
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    HdsNavDestination() {
      Column() {
        // ★ 2026-10-20 第五轮（用户：「**本地音乐上方改回去吧**」）：
        //   上一版把头部做成 Stack 浮层（想让材质有东西可采），用户不要那个观感 ⇒ **改回**普通
        //   Column 上下排：文案行 → 页签 → 播放全部 → 列表。列表第一行不会被浮层盖住，
        //   也不再需要 `contentStartOffset`。
        this.Header()

        if (this.importState.importing || this.importState.progress.length > 0) {
          this.ProgressBar()
        }
        if (this.matchingAll) {
          this.MatchProgressBar()
        }

        // 页签 + 播放全部：固定在列表上方（不跟列表滚）
        if (this.items.length > 0) {
          Column() {
            this.CategoryTabs()
            this.PlayAllRow()
          }
          .width('100%')
          .backgroundColor($r('app.color.page_background'))
        }

        if (this.items.length === 0) {
          this.EmptyGuide()
        } else {
          // ★ 多选操作条是**底部悬浮胶囊**，盖在列表上，不压缩列表高度。
          // ★ 2026-10-20 第五轮（用户：「我看到的还是两种分隔的列表」）：
          //   原来「歌曲」格把 `items` 和 `downloadedTasks` **两套**都列了一遍 ——
          //   而下载的文件早被 `scanDir()` 收进 `items` 了，于是同一首歌出现两次、
          //   分隔线也是两套（本地行一套 + DownloadedRow 一套带红图标）。
          //   ⇒ 这里**只列 `items`**，下载来的歌就靠 scanDir 正常混在里面。
          Stack({ alignContent: Alignment.Bottom }) {
            List({ space: 2 }) {
              if (this.category === 'song') {
                ForEach(this.items, (item: SongItem) => {
                  ListItem() {
                    this.SongRow(item)
                  }
                }, (item: SongItem) => `${item.songId}_${item.interval}`)
              } else {
                ForEach(this.groupEntries(), (entry: LocalGroupEntry) => {
                  ListItem() {
                    this.GroupRow(entry)
                  }
                }, (entry: LocalGroupEntry) => 'grp_' + this.category + '_' + entry.name)
              }
            }
            .scrollBar(BarState.Off)
            .width('100%')
            .height('100%')
            .divider({ strokeWidth: 0.6, color: $r('sys.color.background_tertiary') })
            // ★ 底部"给悬浮播放条让位"的留白留在**列表里**（`contentEndOffset` 随内容滚走，
            //   不要写到容器 padding 上 —— 那是固定在屏幕底部的死带）。
            .contentEndOffset(this.bottomReservedVp())

            if (this.selectionMode) {
              Column() {
                this.SelectionBar()
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 28 })
              .hitTestBehavior(HitTestMode.Transparent)
            }
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      // ★ 让位 = 状态栏 + HDS 标题栏 56（本页标题栏交给 HDS，自绘头部退到它下面）。
      .padding({ top: getStatusBarTopVpFromWindowUtil() + 56 })
    }
    .onBackPressed((): boolean => guardPlayerBack('LocalMusicView'))
    .hideTitleBar(false)
    // ★ 用户 2026-10-12：「现在本地音乐页面有两个标题。你把下面那个去掉，然后那个匹配、选择、导入像歌单页一样放进菜单。」
    .titleBar({
      content: {
        title: { mainTitle: '本地音乐' },
        menu: { value: this.titleMenus() }
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .backgroundColor($r('sys.color.background_primary'))
    // ★★ 状态栏三件套（2026-10-11 定稿，用户第三次纠正后）：
    //   ① `expandSafeArea(TOP,BOTTOM)` 把页面底色铺到状态栏/导航条那两条（只扩绘制区）；
    //   ② `ignoreLayoutSafeArea(...[TOP, BOTTOM])` —— **TOP 必须给**：这一页虽然没有 HDS 标题栏，
    //      但自绘 `Header()` 的避让是**容器 padding** 给的，只有盒子从屏幕 y=0 起排，
    //      `padding({ top: 状态栏 })` 才等于"Header 正好落在状态栏下沿"；
    //      只写 BOTTOM 时盒子自己已让开状态栏，再叠一层 padding ⇒ **Header 被推到状态栏 + 状态栏**，
    //      顶部白多一条 38vp（这就是用户说的「上方留的空距有点大了」）。
    .onBackPressed((): boolean => {
      if (this.showMatchSheet) {
        this.showMatchSheet = false;
        return true;
      }
      // ★ 多选态返回 = 先退出多选（与底栏「取消」同义），不要一下子把整页弹掉
      if (this.selectionMode) {
        this.exitSelectionMode();
        return true;
      }
      return guardPlayerBack('LocalMusicView');
    })
    .backgroundColor($r('app.color.page_background'))
    .bindSheet(this.showMatchSheet, this.MatchSheetBuilder, {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: true,
      onDisappear: (): void => {
        this.showMatchSheet = false;
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}

/**
 * 删除一批本地歌：删掉应用内的副本，并把歌单 / 收藏 / 播放队列里的同一条一起摘掉
 *
 * 歌单与收藏在 LocalMusic.removeKeys 里清（侧表 + MusicStoreService）；
 * 播放队列是共享状态（MusicAppState.playQueue），在这里顺手过滤 ——
 * 不摘掉的话，队列里会留下点一下就播不了的幽灵条目（对应 listen 的 PlaySession.dropLocalSongs）。
 * @param keys 本地歌 key 列表
 * @returns 真正删掉的条数
 */
export function removeLocalSongs(keys: string[]): number {
  if (keys.length === 0) {
    return 0;
  }
  const removed: number = localMusic.removeKeys(keys);
  if (removed > 0) {
    pruneQueue(keys);
  }
  return removed;
}

/** 把被删掉的本地歌从播放队列里摘掉（当前播放的那条被摘掉时顺延到同位置的下一首） */
function pruneQueue(removedKeys: string[]): void {
  const state: MusicAppState = AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE,
    () => new MusicAppState())!;
  const kept: SongItem[] = [];
  let newIndex: number = 0;
  for (let i: number = 0; i < state.playQueue.length; i++) {
    const item: SongItem = state.playQueue[i];
    const isRemoved: boolean = item.source === 'local' && removedKeys.includes(item.songId);
    if (isRemoved) {
      if (i < state.selectIndex) {
        newIndex--;
      }
      continue;
    }
    kept.push(item);
  }
  if (kept.length === state.playQueue.length) {
    return;
  }
  newIndex = Math.max(0, Math.min(kept.length - 1, state.selectIndex + newIndex));
  state.playQueue = kept;
  state.selectIndex = kept.length === 0 ? 0 : newIndex;
}

/** 导入结果的一句话说明 */
export function describeImport(result: ImportResult): string {
  const parts: string[] = [];
  if (result.added > 0) {
    parts.push(`已导入 ${result.added} 首`);
  }
  if (result.skipped > 0) {
    parts.push(`跳过 ${result.skipped} 首（已经导入过）`);
  }
  if (result.unsupported > 0) {
    parts.push(`${result.unsupported} 首格式不支持`);
  }
  if (result.failed > 0) {
    parts.push(`${result.failed} 首读取失败`);
  }
  if (parts.length === 0) {
    return '没有可导入的文件';
  }
  return parts.join('，');
}

/** 占用空间（界面上只要一个量级） */
export function formatBytes(bytes: number): string {
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  const kb: number = bytes / 1024;
  if (kb < 1024) {
    return `${Math.round(kb)} KB`;
  }
  const mb: number = kb / 1024;
  if (mb < 1024) {
    return `${mb.toFixed(1)} MB`;
  }
  return `${(mb / 1024).toFixed(2)} GB`;
}

/**
 * 路由入口（router_map.json 登记的 buildFunction）
 * @param name 路由名（此处不用，仅为签名对齐）
 * @param param 路由参数（本地音乐页无参数）
 */
@Builder
export function LocalMusicPageBuilder(name: string, param: Object) {
  LocalMusicPage()
}