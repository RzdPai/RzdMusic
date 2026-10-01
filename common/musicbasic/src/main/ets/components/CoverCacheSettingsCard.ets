import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { CoverCacheService, CoverCacheState } from '../services/CoverCacheService';
import { ThemeState } from '../model/ThemeState';
import { AppStorageKeys } from '../constants/Constants';

@ComponentV2
export struct CoverCacheSettingsCard {
  @Local state: CoverCacheState = CoverCacheService.getInstance().state;
  @Local sizeText: string = '正在统计…';
  @Local busy: boolean = false;
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;

  aboutToAppear(): void {
    void this.refresh();
  }

  @Monitor('state.bytes')
  onSizeChanged(): void {
    this.sizeText = (this.state.bytes / 1024 / 1024).toFixed(2) + ' MB / 100 MB';
  }

  private async refresh(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.sizeText = '统计失败';
      return;
    }
    try {
      const bytes = await CoverCacheService.getInstance().refreshSize(context as common.Context);
      this.sizeText = (bytes / 1024 / 1024).toFixed(2) + ' MB / 100 MB';
    } catch (_error) {
      this.sizeText = '统计失败';
    }
  }

  private async confirmClear(): Promise<void> {
    if (this.busy || this.state.clearing) {
      return;
    }
    this.busy = true;
    try {
      const answer = await this.getUIContext().getPromptAction().showDialog({
        title: '清空封面缓存？',
        message: '仅删除歌单歌曲的网络封面缓存，不会删除下载音乐、用户歌单或账号。下次打开歌单时按需重新加载。',
        buttons: [{ text: '取消', color: '#666666' }, { text: '清空', color: '#E84026' }]
      });
      if (answer.index !== 1) {
        return;
      }
      const context = this.getUIContext().getHostContext();
      if (context === undefined) {
        throw new Error('context unavailable');
      }
      await CoverCacheService.getInstance().clear(context as common.Context);
      await this.refresh();
      this.getUIContext().getPromptAction().showToast({ message: '封面缓存已清空' });
    } catch (_error) {
      await this.refresh();
      this.getUIContext().getPromptAction().showToast({ message: '未能完成清理，请稍后重试' });
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 4 }) {
          Text('封面缓存')
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('sys.color.font_primary'))
          Text(this.sizeText)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button(this.state.clearing ? '清理中…' : '清空缓存')
          .fontSize($r('sys.float.Body_S'))
          .backgroundColor(this.themeState.color)
          .fontColor(Color.White)
          .enabled(!this.busy && !this.state.clearing)
          .onClick((): void => { void this.confirmClear(); })
      }
      .width('100%')
      Text('仅缓存网络封面，最多 100 MB，7 天过期。')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius($r('sys.float.corner_radius_level12'))
    .backgroundColor($r('app.color.card_background'))
  }
}
