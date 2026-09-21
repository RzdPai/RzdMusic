/*
 * 「本地音乐」内嵌面板（设置页 - 本地音乐）
 *
 * 与 features/localmusic 的 LocalMusicPage 是同一份能力（导入设备音频 / 列表 / 删除），
 * 但那个页面自带 NavDestination（整屏路由页，标题栏自绘），没法直接塞进设置页的内嵌右栏
 * （宽屏 MD/LG/XL 的 SettingsDetailPage 是内嵌渲染，不是导航；NavDestination 也不能嵌套），
 * 而 features/localmusic 不允许改，所以这里做一个「设置页版」的面板：
 *   - 数据与逻辑全部复用 localmusic 的对外接口：localMusic / localMusicImportState /
 *     removeLocalSongs / formatBytes / describeImport；
 *   - 只重写表现层（卡片式列表 + 内嵌页头），颜色 / 字号用系统的 sys.* 资源与主题色；
 *   - 播放链路与 LocalMusicPage.playAt 一致（换队列 + MediaService.loadAsset），
 *     本地歌的播放直路由主 agent 在 MediaService 里补。
 */

import { AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppStorageKeys, MusicAppState, SongItem, ThemeState } from 'musicbasic';
import { MediaService } from 'player';
import {
  LocalMusicImportState,
  describeImport,
  formatBytes,
  localMusic,
  localMusicImportState,
  removeLocalSongs
} from 'localmusic';
import type { ImportResult } from 'localmusic';

@ComponentV2
export struct LocalMusicSection {
  /**
   * 内容顶部要额外避让的高度（vp）
   *
   * 作为 SettingsDetailPage 的二级页时传标题栏高度；宽屏内嵌右栏时传 0。
   */
  @Param topOffset: number = 0;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  /** 导入进度 / 库版本（导入、删除、歌词匹配变化都会 +1） */
  @Local importState: LocalMusicImportState = localMusicImportState();
  @Local items: SongItem[] = [];
  @Local selectionMode: boolean = false;
  @Local selectedMap: Record<string, boolean> = {};

  aboutToAppear(): void {
    this.ensureInit();
    this.refresh();
  }

  /** 库变化（导入完成 / 删除 / 歌词匹配）后重新读列表 */
  @Monitor('importState.version')
  onLibraryChanged(): void {
    this.refresh();
  }

  /** 宿主还没调过 init 时这里自己初始化 */
  private ensureInit(): void {
    if (localMusic.isReady()) {
      return;
    }
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      localMusic.init(context as common.UIAbilityContext);
    }
  }

  private refresh(): void {
    this.items = localMusic.getSongItems();
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  private hostContext(): common.UIAbilityContext | null {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
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

  private async pickFiles(): Promise<void> {
    const context: common.UIAbilityContext | null = this.hostContext();
    if (context === null) {
      this.toast('当前环境不支持选择文件');
      return;
    }
    const result: ImportResult = await localMusic.importFiles(context);
    this.afterImport(result);
  }

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
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text('本地音乐')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
          .textAlign(TextAlign.Start)
        Text(this.items.length > 0 ?
          `${this.items.length} 首 · ${formatBytes(localMusic.totalBytes())}` : '还没有导入本地音乐')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.items.length > 0 && !this.selectionMode) {
        Text('选择')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .borderRadius($r('sys.float.corner_radius_level12'))
          .backgroundColor($r('sys.color.background_secondary'))
          .onClick(() => {
            this.enterSelectionMode();
          })
      }

      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_on_primary')])
        Text('导入')
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_on_primary'))
      }
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .borderRadius($r('sys.float.corner_radius_level12'))
      .backgroundColor(this.themeState.color)
      .bindMenu(this.importMenu())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 8 })
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
    .margin({ left: 20, right: 20 })
    .borderRadius($r('sys.float.corner_radius_level4'))
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /** 多选模式操作条：全选 / 删除(n) / 取消 */
  @Builder
  private SelectionBar() {
    Row({ space: 12 }) {
      Text(this.selectedCount() === this.items.length && this.items.length > 0 ? '取消全选' : '全选')
        .fontSize($r('sys.float.Caption_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor($r('sys.color.background_secondary'))
        .onClick(() => {
          this.toggleSelectAll();
        })
      Text(this.selectedCount() > 0 ? `删除(${this.selectedCount()})` : '删除')
        .fontSize($r('sys.float.Caption_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedCount() > 0 ?
          $r('sys.color.font_on_primary') : $r('sys.color.font_tertiary'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius($r('sys.float.corner_radius_level12'))
        .backgroundColor(this.selectedCount() > 0 ? this.themeState.color : $r('sys.color.background_tertiary'))
        .onClick(() => {
          this.confirmRemove();
        })
      Text('取消')
        .fontSize($r('sys.float.Caption_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: 4, right: 4 })
        .onClick(() => {
          this.exitSelectionMode();
        })
      Blank()
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 4, bottom: 4 })
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
          .fontSize($r('sys.float.Body_M'))
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
          Text('本地')
            .fontSize($r('sys.float.Caption_S'))
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius($r('sys.float.corner_radius_level2'))
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor(this.themeState.color)
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
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .borderRadius($r('sys.float.corner_radius_level12'))
    .backgroundColor($r('sys.color.background_secondary'))
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
        .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        this.Header()

        if (this.importState.importing || this.importState.progress.length > 0) {
          this.ProgressBar()
        }

        if (this.selectionMode) {
          this.SelectionBar()
        }
      }
      .width('100%')
      .padding({ top: this.topOffset })

      if (this.items.length === 0) {
        this.EmptyGuide()
      } else {
        List({ space: 8 }) {
          ForEach(this.items, (item: SongItem) => {
            ListItem() {
              this.SongRow(item)
            }
          }, (item: SongItem) => `${item.songId}_${item.interval}`)
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 12 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
