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
import { AppStorageKeys, MusicAppState, SongItem, ThemeState } from 'musicbasic';
import { MediaService } from 'player';
import {
  ImportResult,
  LocalMusicImportState,
  localMusic,
  localMusicImportState
} from '../core/LocalMusic';

const DOMAIN: number = 0x0001;
const TAG: string = 'LocalMusicPage';

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
  /** 导入进度 / 库版本（导入、删除、歌词匹配变化都会 +1） */
  @Local importState: LocalMusicImportState = localMusicImportState();
  /** 当前列表快照（倒序：新导入在最前） */
  @Local items: SongItem[] = [];
  /** 多选删除模式 */
  @Local selectionMode: boolean = false;
  /** 多选勾选表（key = 本地 key） */
  @Local selectedMap: Record<string, boolean> = {};
  /** 路由栈（与 MinePage 同一个 @Provider 名，用于返回） */
  @Consumer('pageIndexInfos') pageStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.ensureInit();
    this.refresh();
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
    this.items = localMusic.getSongItems();
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
  }

  private exitSelectionMode(): void {
    this.selectionMode = false;
    this.selectedMap = {};
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
    const queue: SongItem[] = this.items;
    if (index < 0 || index >= queue.length) {
      return;
    }
    this.appState.replaceQueue(queue, index);
    this.appState.currentQuality = 'local';
    this.appState.isResolving = false;
    void MediaService.getInstance().loadAsset(index);
    this.appState.isShowPlay = true;
  }

  // ------------------------------------------------------------ 界面

  @Builder
  private Header() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        if (this.pageStack.size() > 0) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([$r('sys.color.icon_primary')])
            .onClick(() => {
              this.pageStack.pop();
            })
        }
        Text('本地音乐')
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        if (this.items.length > 0 && !this.selectionMode) {
          Text('选择')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: 8, right: 8, top: 6, bottom: 6 })
            .onClick(() => {
              this.enterSelectionMode();
            })
        }
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(16)
            .fontColor([$r('sys.color.font_on_primary')])
          Text('导入')
            .fontSize($r('sys.float.Body_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_on_primary'))
        }
        .padding({ left: 14, right: 16, top: 7, bottom: 7 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor(this.themeState.color)
        .bindMenu(this.importMenu())
      }
      .width('100%')

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

  /** 多选模式操作条：全选 / 删除(n) / 取消 */
  @Builder
  private SelectionBar() {
    Row({ space: 12 }) {
      Text(this.selectedCount() === this.items.length && this.items.length > 0 ? '取消全选' : '全选')
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('sys.color.background_secondary'))
        .onClick(() => {
          this.toggleSelectAll();
        })
      Text(this.selectedCount() > 0 ? `删除(${this.selectedCount()})` : '删除')
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedCount() > 0 ?
          $r('sys.color.font_on_primary') : $r('sys.color.font_tertiary'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor(this.selectedCount() > 0 ? this.themeState.color : '#1A000000')
        .onClick(() => {
          this.confirmRemove();
        })
      Text('取消')
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: 4, right: 4 })
        .onClick(() => {
          this.exitSelectionMode();
        })
      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
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
        Text(typeof item.title === 'string' ? item.title : '')
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
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
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_tertiary')])
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick(() => {
      if (this.selectionMode) {
        this.toggleSelect(item, !this.isSelected(item));
        return;
      }
      this.playAt(this.items.indexOf(item));
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
    NavDestination() {
      Column() {
        this.Header()

        if (this.importState.importing || this.importState.progress.length > 0) {
          this.ProgressBar()
        }

        if (this.selectionMode) {
          this.SelectionBar()
        }

        if (this.items.length === 0) {
          this.EmptyGuide()
        } else {
          List({ space: 2 }) {
            ForEach(this.items, (item: SongItem) => {
              ListItem() {
                this.SongRow(item)
              }
            }, (item: SongItem) => `${item.songId}_${item.interval}`)
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          .width('100%')
          .divider({ strokeWidth: 0.6, color: $r('sys.color.background_tertiary') })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
