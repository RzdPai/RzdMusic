import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys, ThemeState } from 'musicbasic';
import { DownloadService, DownloadStatus, DownloadTask } from 'player';

/**
 * 下载管理面板：任务列表（排队/进度/速度/失败重试/删除/清除已完成）。
 * SettingPage 弹窗与 SettingsDetailPage 详情页共用。
 */
@ComponentV2
export struct DownloadManagerSection {
  @Param contentTopOffset: number = 0;
  @Param pageScroller: Scroller = new Scroller();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
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
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text(t.name)
                    .fontSize(15)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontColor($r('sys.color.font_primary'))
                  Text(t.singer + ' · ' + t.quality)
                    .fontSize(12)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontColor($r('sys.color.font_tertiary'))
                  if (t.status === DownloadStatus.RUNNING) {
                    if (t.total > 0) {
                      Progress({ value: t.progress, total: 100, type: ProgressType.Linear })
                        .width('100%')
                        .height(16)
                      Text(((t.speed ?? '').length > 0 ? t.speed + ' · ' : '') + t.progress + '%')
                        .fontSize(11)
                        .fontColor($r('sys.color.font_tertiary'))
                    } else {
                      Text(this.progressText(t))
                        .fontSize(11)
                        .fontColor($r('sys.color.font_tertiary'))
                    }
                  } else {
                    Text(this.statusText(t))
                      .fontSize(12)
                      .fontColor(t.status === DownloadStatus.FAILED ?
                        '#E53935' : $r('sys.color.font_tertiary'))
                  }
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
                Text('删除')
                  .fontSize(13)
                  .fontColor($r('sys.color.font_tertiary'))
                  .padding(6)
                  .onClick(() => {
                    DownloadService.getInstance().remove(t.id);
                  })
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .borderRadius($r('sys.float.corner_radius_level12'))
              .backgroundColor($r('app.color.card_background'))
              .alignItems(VerticalAlign.Center)
            }
          }, (t: DownloadTask) => t.id + '_' + t.status + '_' + Math.floor(t.progress))
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 8 + this.contentTopOffset, bottom: 8 })
  }
}
