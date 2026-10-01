import { HdsListItemCard } from '@kit.UIDesignKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys, Logger, ThemeState } from 'musicbasic';
import { syncManager } from '../core/SyncManager';
import { WebDavBackupService, WebDavConfig } from '../core/WebDavBackupService';

@ComponentV2
export struct WebDavBackupCard {
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local url: string = '';
  @Local user: string = '';
  @Local password: string = '';
  @Local fileName: string = '';
  @Local status: string = '';
  @Local busy: boolean = false;
  private pendingText: string = '';

  aboutToAppear(): void {
    const config = WebDavBackupService.readConfig();
    this.url = config.url;
    this.user = config.user;
    this.password = config.password;
  }

  private config(): WebDavConfig {
    const config = new WebDavConfig();
    config.url = this.url;
    config.user = this.user;
    config.password = this.password;
    return config;
  }

  private async backup(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    Logger.info('RzdSyncAppearance', 'WebDAV operation started');
    try {
      WebDavBackupService.saveConfig(this.config());
      this.fileName = await WebDavBackupService.backup(this.config());
      this.status = '备份成功：' + this.fileName;
    } catch (error) {
      this.status = (error as Error).message;
    } finally {
      this.busy = false;
      Logger.info('RzdSyncAppearance', 'WebDAV operation finished');
    }
  }

  private async prepareRestore(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    Logger.info('RzdSyncAppearance', 'WebDAV operation started');
    try {
      WebDavBackupService.saveConfig(this.config());
      this.pendingText = await WebDavBackupService.fetch(this.config(), this.fileName);
      const result = await this.getUIContext().getPromptAction().showDialog({
        title: '确认覆盖本机数据',
        message: '恢复将使用备份中的设置和歌单覆盖本机对应数据，不合并。请先备份当前数据；恢复期间请勿编辑歌单或切换同步。',
        buttons: [{ text: '取消', color: '#808080' }, { text: '覆盖恢复', color: '#E53935' }]
      });
      if (result.index === 1) {
        if (syncManager.uiState().enabled) {
          throw new Error('请先关闭洛雪同步，再恢复，避免服务端立即覆盖或反向上传恢复数据');
        }
        this.status = await WebDavBackupService.restore(this.pendingText);
      } else {
        this.status = '已取消，未修改本机数据';
      }
    } catch (error) {
      this.status = (error as Error).message;
    } finally {
      this.pendingText = '';
      this.busy = false;
      Logger.info('RzdSyncAppearance', 'WebDAV operation finished');
    }
  }

  build() {
    Column({ space: 10 }) {
      HdsListItemCard({
        textItem: { primaryText: { text: 'WebDAV 配置' } },
        cardBackgroundColor: $r('app.color.sync_card_background')
      })
      Text('独立备份设置和歌单（不含音频）；每次生成独立文件，不覆盖远端。目录须已存在。')
        .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
      TextInput({ text: this.url, placeholder: 'https://服务器/dav/备份目录/' })
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('app.color.sync_input_background'))
        .enabled(!this.busy).onChange((value: string) => { this.url = value; })
      TextInput({ text: this.user, placeholder: '用户名' })
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('app.color.sync_input_background'))
        .enabled(!this.busy).onChange((value: string) => { this.user = value; })
      TextInput({ text: this.password, placeholder: '密码（仅保存于本机，不进入备份）' })
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('app.color.sync_input_background'))
        .type(InputType.Password).enabled(!this.busy)
        .onChange((value: string) => { this.password = value; })
      TextInput({ text: this.fileName, placeholder: '恢复文件名 rzdmusic-backup-….json' })
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('app.color.sync_input_background'))
        .enabled(!this.busy).onChange((value: string) => { this.fileName = value; })
      Row({ space: 12 }) {
        Button('备份')
          .fontColor($r('sys.color.font_on_primary'))
          .backgroundColor(this.themeState.color)
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => { void this.backup(); })
        Button('读取并恢复')
          .fontColor(this.themeState.color)
          .backgroundColor($r('app.color.sync_input_background'))
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => { void this.prepareRestore(); })
      }.width('100%')
      Text(this.busy ? '处理中，请勿离开…' : this.status)
        .fontSize(12).width('100%').textAlign(TextAlign.Start).copyOption(CopyOptions.LocalDevice)
    }
    .width('100%').padding(16).borderRadius($r('sys.float.corner_radius_level12'))
    .backgroundColor($r('app.color.sync_card_background'))
    .border({ width: 1, color: $r('app.color.sync_card_outline') })
  }
}
