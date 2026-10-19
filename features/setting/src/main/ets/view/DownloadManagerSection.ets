import { AppStorageV2 } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageKeys, MusicAppState, PlayedSongRecord, SongTitleMarquee, ThemeState } from 'musicbasic';
import { DownloadService, DownloadStatus, DownloadTask, OnlinePlayUtil } from 'player';

/**
 * 下载管理面板：任务列表（排队/进度/速度/失败重试/删除/清除已完成）。
 * SettingPage 弹窗与 SettingsDetailPage 详情页共用。
 *
 * 2026-10-19 重构（用户点名）：
 *   · 进度条与文字**跟着刷新**（原来 key 只带整数百分比，同一百分比内字节变了但行不重绘）；
 *   · 完成后显示「已完成 xx / xx」（原来只一句"已完成"，没有体量）；
 *   · 行改成**左滑**出「打开 / 位置 / 删除」（参照 RzdSchool 选人界面的 swipe 图标组）。
 */
@ComponentV2
export struct DownloadManagerSection {
  @Param contentTopOffset: number = 0;
  @Param pageScroller: Scroller = new Scroller();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  /** 左滑「打开」要就地播放，需要共享播放状态。 */
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  @Local tasks: DownloadTask[] = [];
  private listener: ((tasks: DownloadTask[]) => void) | null = null;

  aboutToAppear(): void {
    this.listener = (tasks: DownloadTask[]): void => {
      this.tasks = tasks;
    };
    DownloadService.getInstance().addListener(this.listener);
    this.tasks = DownloadService.getInstance().getTasksSnapshot();
  }

  aboutToDisappear(): void {
    if (this.listener !== null) {
      DownloadService.getInstance().removeListener(this.listener);
      this.listener = null;
    }
  }

  private statusText(t: DownloadTask): string {
    if (t.status === DownloadStatus.WAITING) {
      return '排队中';
    }
    if (t.status === DownloadStatus.PAUSED) {
      return '已暂停';
    }
    if (t.status === DownloadStatus.COMPLETED) {
      return '已完成';
    }
    if (t.status === DownloadStatus.FAILED) {
      return (t.message ?? '').length > 0 ? '失败: ' + t.message : '下载失败';
    }
    return (t.message ?? '').length > 0 ? t.message : '下载中';
  }

  private progressText(t: DownloadTask): string {
    const mb: string = (t.downloaded / 1024 / 1024).toFixed(1) + 'MB';
    if ((t.speed ?? '').length > 0) {
      return t.speed + ' · ' + mb;
    }
    return mb;
  }

  /** 字节 → `xx KB`（用户 2026-10-19 要的口径：一律 KB）。 */
  private kb(bytes: number): string {
    const v: number = Math.max(0, bytes) / 1024;
    return v >= 1024 ? (v / 1024).toFixed(1) + ' MB' : Math.round(v) + ' KB';
  }

  /** 什么时候画进度条：下载中 / 已暂停 / 已完成 / 总量已知的排队任务。 */
  private showProgress(t: DownloadTask): boolean {
    return t.total > 0;
  }

  /**
   * 状态行文案（用户 2026-10-19：「下载完也要已完成 xx KB/xx KB 这种」）：
   *   · 完成 → `已完成 3.4 MB / 3.4 MB`
   *   · 暂停 → `已暂停 · 1.2 MB / 3.4 MB`
   *   · 下载中 → `1.2 MB / 3.4 MB · 220 KB/s（45%）`
   *   · 其它 → 排队中 / 失败原因
   */
  private progressLine(t: DownloadTask): string {
    const totalText: string = t.total > 0 ? this.kb(t.downloaded) + ' / ' + this.kb(t.total) : '';
    if (t.status === DownloadStatus.COMPLETED) {
      const size: string = t.total > 0 ? this.kb(t.total) : this.kb(t.downloaded);
      return '已完成 ' + size + ' / ' + size;
    }
    if (t.status === DownloadStatus.PAUSED) {
      return totalText.length > 0 ? '已暂停 · ' + totalText : '已暂停';
    }
    if (t.status === DownloadStatus.RUNNING) {
      const speed: string = (t.speed ?? '').length > 0 ? ' · ' + t.speed : '';
      return totalText.length > 0 ? totalText + speed + '（' + t.progress + '%）' : '下载中' + speed;
    }
    if (t.status === DownloadStatus.FAILED) {
      return (t.message ?? '').length > 0 ? '失败：' + t.message : '下载失败';
    }
    return totalText.length > 0 ? '排队中 · ' + totalText : '排队中';
  }

  /**
   * 左滑操作组：打开 / 位置 / 删除（参照 RzdSchool `PickPage`/`ManagePage` 的 swipe 图标组）。
   *
   * · 打开 = 就地播放这首（下载文件已在本地，走 `source='local'` 直路）；
   * · 位置 = 把文件路径复制到剪贴板（下载目录是用户挑的授权目录，没法直接拉起系统文件管理器）；
   * · 删除 = 移除任务（已有能力）。
   */
  @Builder
  private SwipeActions(t: DownloadTask) {
    Row({ space: 8 }) {
      this.SwipeIcon($r('sys.symbol.play_fill'), '打开', this.themeState.color, (): void => {
        this.openDownloaded(t);
      })
      this.SwipeIcon($r('sys.symbol.folder'), '位置', '#4C7DFF', (): void => {
        this.revealPath(t);
      })
      this.SwipeIcon($r('sys.symbol.trash'), '删除', '#E53935', (): void => {
        DownloadService.getInstance().remove(t.id);
      })
    }
    .padding({ left: 8, right: 10 })
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }

  /** 左滑里的一颗按钮（图标 + 小字，圆角方块）。 */
  @Builder
  private SwipeIcon(icon: Resource, label: string, bg: string, action: () => void) {
    Column({ space: 2 }) {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([Color.White])
      Text(label)
        .fontSize(10)
        .fontColor(Color.White)
        .maxLines(1)
    }
    .width(56)
    .height(56)
    .borderRadius(14)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(bg)
    .onClick(() => {
      action();
    })
  }

  /** 打开：就地播放这个下载文件。 */
  private openDownloaded(t: DownloadTask): void {
    const record: PlayedSongRecord = new PlayedSongRecord();
    record.source = 'local';
    record.songId = t.id;
    record.name = t.name;
    record.singer = t.singer;
    record.albumName = t.albumName;
    record.img = t.imgUrl;
    record.quality = t.quality;
    record.url = t.tempPath.length > 0 ? t.tempPath : t.fileName;
    record.time = Date.now();
    hilog.info(0x0000, 'RzdDownload',
      'open downloaded name=%{public}s path=%{public}s', t.name, record.url);
    void OnlinePlayUtil.playRecord(this.appState, record, this.getUIContext());
  }

  /** 位置：把文件路径复制到剪贴板（目录是用户授权的外部目录，无法直接拉起文件管理器定位）。 */
  private revealPath(t: DownloadTask): void {
    const path: string = t.tempPath.length > 0 ? t.tempPath : t.fileName;
    const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, path);
    pasteboard.getSystemPasteboard().setData(data).then((): void => {
      this.getUIContext().getPromptAction().showToast({ message: '文件路径已复制', duration: 1600 });
    }).catch((err: Error): void => {
      hilog.error(0x0000, 'RzdDownload', 'copy path failed: %{public}s', err.message);
    });
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('下载任务')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text('全部继续')
          .fontSize(13)
          .fontColor(this.themeState.color)
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .onClick(() => {
            DownloadService.getInstance().resumeAll();
          })
        Text('全部暂停')
          .fontSize(13)
          .fontColor(this.themeState.color)
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .onClick(() => {
            DownloadService.getInstance().pauseAll();
          })
        Text('清除已完成')
          .fontSize(13)
          .fontColor(this.themeState.color)
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .onClick(() => {
            DownloadService.getInstance().clearCompleted();
          })
      }
      .width('100%')

      if (this.tasks.length === 0) {
        Column() {
          Text('暂无下载任务')
            .fontSize(14)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8, scroller: this.pageScroller }) {
          ForEach(this.tasks, (t: DownloadTask) => {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    // ★ 2026-10-15：任务名（= 歌曲名）过长改跑马灯。这一行原来**没写** fontSize（走 Text
                    //   默认字号），换成自定义组件后字号不再由调用点决定 ⇒ 按同一行副标题/卡片的既有尺度
                    //   显式给 15（与 `ArtistDetailPage`/`AlbumDetailPage` 歌曲行同档），真机看一眼观感。
                    //   父容器是 `Column` ⇒ 用默认 `fillByWidth`（`width('100%')`）。
                    SongTitleMarquee({
                      text: t.name,
                      titleFontSize: 15,
                      titleFontColor: $r('sys.color.font_primary'),
                      titleFontWeight: FontWeight.Normal
                    })
                    Text(t.singer + ' · ' + t.quality)
                      .fontSize(12)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .fontColor($r('sys.color.font_tertiary'))
                    // ★ 用户 2026-10-19：进度条要一直跟着刷新；完成后也要有「已完成 xx KB / xx KB」
                    if (this.showProgress(t)) {
                      Progress({ value: t.progress, total: 100, type: ProgressType.Linear })
                        .width('100%')
                        .height(4)
                        .color(t.status === DownloadStatus.COMPLETED ? '#34C759' : this.themeState.color)
                    }
                    Text(this.progressLine(t))
                      .fontSize(11)
                      .fontColor(t.status === DownloadStatus.FAILED ?
                        '#E53935' : $r('sys.color.font_tertiary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  if (t.status === DownloadStatus.FAILED) {
                    Text('重试')
                      .fontSize(13)
                      .fontColor(this.themeState.color)
                      .padding(6)
                      .onClick(() => {
                        DownloadService.getInstance().retry(t.id);
                      })
                  }
                  if (t.status === DownloadStatus.RUNNING || t.status === DownloadStatus.WAITING) {
                    Text('暂停')
                      .fontSize(13)
                      .fontColor(this.themeState.color)
                      .padding(6)
                      .onClick(() => {
                        DownloadService.getInstance().pause(t.id);
                      })
                  }
                  if (t.status === DownloadStatus.PAUSED) {
                    Text('继续')
                      .fontSize(13)
                      .fontColor(this.themeState.color)
                      .padding(6)
                      .onClick(() => {
                        DownloadService.getInstance().resume(t.id);
                      })
                  }
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .borderRadius($r('sys.float.corner_radius_level12'))
              .backgroundColor($r('app.color.card_background'))
            }
            // ★ 用户 2026-10-19：左滑出「打开 / 位置 / 删除」（参照 RzdSchool 选人界面的 swipe 图标组）
            .swipeAction({
              end: {
                builder: (): void => {
                  this.SwipeActions(t);
                }
              },
              edgeEffect: SwipeEdgeEffect.Spring
            })
            // ★ 刷新修复：key 里带上 **downloaded**（原来只带 progress 的整数百分比，
          //   同一个百分比内字节在变但 key 不变 ⇒ 行不重绘，进度条/文字卡住）
          }, (t: DownloadTask) => t.id + '_' + t.status + '_' + t.downloaded + '_' + t.total)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        // ★ 用户 2026-10-11：下载管理页要**回弹**（List 的 EdgeEffectOptions.alwaysEnabled 默认 false）
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
    }
    .width('100%')
    .height('100%')
      .padding({ left: 8, right: 8, top: 8 + this.contentTopOffset, bottom: 8 })
  }
}
