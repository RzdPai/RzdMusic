import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { AccountService } from 'player';
import { HuaweiAccountService } from 'player';
import { PlatformAccount, sourceName } from 'player';
import { QrCodeLoginResult, QrCodeLoginState, QrLoginStatus } from 'player';
import { AppStorageKeys, MusicStoreService, ThemeState } from 'musicbasic';
import { CapsuleSegmentedSelector } from '../view/CapsuleSegmentedSelector';
import { HuaweiAccountCard } from './HuaweiAccountCard';

@ComponentV2
export struct AccountManageSheet {
  @Local accounts: PlatformAccount[] = [];
  @Local source: string = 'wy';
  @Local method: string = 'qrcode';
  @Local cookie: string = '';
  @Local qrUrl: string = '';
  @Local qrStatus: QrLoginStatus = QrLoginStatus.Waiting;
  @Local qrMessage: string = '';
  @Local error: string = '';
  @Local isLoading: boolean = false;
  @Local avatarFailed: Set<string> = new Set();
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  private qrKey: string = '';
  private qrTimer: number = -1;
  private sourceList: string[] = ['wy', 'tx', 'kg'];
  /** 关闭回调（由父组件控制 sheet 关闭）。 */
  @Param onClose: () => void = () => {};

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (context !== undefined) {
      AccountService.init(context);
      // 华为账号：记录上下文并恢复上次的登录态（静默恢复，不会弹授权页）
      HuaweiAccountService.getInstance().init(context);
    }
    this.initAsync();
  }

  aboutToDisappear(): void {
    this.stopQrLogin();
    const source: string = this.source;
    if (source === 'tx' && this.qrKey.length > 0) {
      AccountService.cancelQrCode(source, this.qrKey);
    }
  }

  private async initAsync(): Promise<void> {
    await AccountService.loadAccounts();
    this.reloadAccounts();
    await AccountService.refreshKgAvatars();
    this.reloadAccounts();
    this.startQrLogin();
  }

  private reloadAccounts(): void {
    this.accounts = AccountService.listAccounts();
  }

  private stopQrLogin(): void {
    if (this.qrTimer >= 0) {
      clearTimeout(this.qrTimer);
      this.qrTimer = -1;
    }
  }

  private cancelCurrentQr(): void {
    const source: string = this.source;
    const requestId: string = this.qrKey;
    if (requestId.length > 0 && source === 'tx') {
      AccountService.cancelQrCode(source, requestId);
    }
  }

  private resetQrState(): void {
    this.qrKey = '';
    this.qrUrl = '';
    this.qrStatus = QrLoginStatus.Waiting;
    this.qrMessage = '';
    this.stopQrLogin();
  }

  private startQrLogin(): void {
    this.error = '';
    this.resetQrState();
    const source: string = this.source;
    AccountService.createQrCode(source).then((state: QrCodeLoginState) => {
      if (source !== this.source) return;
      this.qrKey = state.key;
      this.qrUrl = state.qrUrl;
      this.qrStatus = state.status;
      this.qrMessage = state.message;
      if (state.qrUrl.length === 0) {
        this.qrStatus = QrLoginStatus.Failed;
        this.qrMessage = '未获取到二维码内容';
        return;
      }
      this.qrTimer = setTimeout(() => {
        this.pollQrCodeStatus(source, state.key);
      }, 500);
    }).catch((err: Error) => {
      if (source !== this.source) return;
      this.qrStatus = QrLoginStatus.Failed;
      this.qrMessage = err.message ?? '获取二维码失败';
    });
  }

  private pollQrCodeStatus(source: string, requestId: string): void {
    if (requestId.length === 0 || source !== this.source || requestId !== this.qrKey) return;
    AccountService.checkQrCodeStatus(source, requestId).then((result: QrCodeLoginResult) => {
      if (source !== this.source || requestId !== this.qrKey) return;
      this.qrStatus = result.status;
      this.qrMessage = result.message ?? '';
      if (result.status === QrLoginStatus.Confirmed) {
        this.stopQrLogin();
        this.reloadAccounts();
        this.startQrLogin();
        return;
      }
      if (result.status === QrLoginStatus.Expired || result.status === QrLoginStatus.Failed) return;
      this.qrTimer = setTimeout(() => {
        this.pollQrCodeStatus(source, requestId);
      }, 500);
    }).catch((err: Error) => {
      if (source !== this.source || requestId !== this.qrKey) return;
      this.qrStatus = QrLoginStatus.Failed;
      this.qrMessage = err.message ?? '二维码登录失败';
    });
  }

  private handleLogin(): void {
    this.error = '';
    const cookieValue: string = this.cookie.trim();
    if (cookieValue.length === 0) {
      this.error = '请输入 Cookie';
      return;
    }
    this.isLoading = true;
    const source: string = this.source;
    AccountService.loginByCookie(source, cookieValue).then(() => {
      if (source !== this.source) return;
      this.reloadAccounts();
      this.cookie = '';
    }).catch((err: Error) => {
      this.error = err.message ?? '登录失败';
    }).finally(() => {
      this.isLoading = false;
    });
  }

  private handleRemove(id: string): void {
    AccountService.removeAccount(id).then(() => {
      this.reloadAccounts();
    }).catch((err: Error) => {
      this.error = err.message ?? '删除失败';
    });
  }

  private handleClose(): void {
    this.stopQrLogin();
    this.cancelCurrentQr();
    this.onClose();
  }

  private switchSource(target: string): void {
    if (target === this.source) return;
    this.cancelCurrentQr();
    this.source = target;
    this.cookie = '';
    this.error = '';
    this.method = 'qrcode';
    this.startQrLogin();
  }

  private switchMethod(target: string): void {
    if (target === this.method) return;
    this.method = target;
    this.error = '';
    if (target === 'qrcode') {
      this.startQrLogin();
    } else {
      this.cancelCurrentQr();
      this.resetQrState();
    }
  }

  private qrStatusText(): string {
    if (this.qrStatus === QrLoginStatus.Waiting) return '请使用手机客户端扫码登录';
    if (this.qrStatus === QrLoginStatus.Scanned) return '已扫码，请在手机上确认';
    if (this.qrStatus === QrLoginStatus.Confirmed) return '扫码成功，登录中...';
    if (this.qrStatus === QrLoginStatus.Expired) return '二维码已过期';
    if (this.qrStatus === QrLoginStatus.Failed) {
      return this.qrMessage.length > 0 ? this.qrMessage : '二维码登录失败';
    }
    return '';
  }

  @Builder
  accountItem(account: PlatformAccount) {
    Row() {
      if (account.avatar.length > 0 && !this.avatarFailed.has(account.id)) {
        Image(account.avatar)
          .width(40)
          .height(40)
          .borderRadius(20)
          .objectFit(ImageFit.Cover)
          .backgroundColor($r('sys.color.background_tertiary'))
          .onError(() => {
            const failed: Set<string> = new Set(this.avatarFailed);
            failed.add(account.id);
            this.avatarFailed = failed;
          })
      } else {
        Text(account.nickname.length > 0 ? account.nickname.substring(0, 1) : '?')
          .width(40)
          .height(40)
          .borderRadius(20)
          .textAlign(TextAlign.Center)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeState.color)
          .backgroundColor($r('sys.color.background_tertiary'))
      }
      Column() {
        Text(account.nickname)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(sourceName(account.source))
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      Button('删除')
        .type(ButtonType.Normal)
        .fontSize(11)
        .fontColor('#E64545')
        .backgroundColor($r('sys.color.background_tertiary'))
        .height(26)
        .borderRadius(13)
        .onClick(() => {
          this.handleRemove(account.id);
        })
    }
    .width('100%')
    .padding(10)
    .borderRadius(11)
    .backgroundColor($r('sys.color.background_primary'))
    .margin({ bottom: 8 })
  }

  /** 当前平台在切换条中的下标。 */
  private sourceIndex(): number {
    const idx: number = this.sourceList.indexOf(this.source);
    return idx < 0 ? 0 : idx;
  }

  /** 按切换条下标切换平台。 */
  private switchSourceByIndex(index: number): void {
    if (index < 0 || index >= this.sourceList.length) {
      return;
    }
    this.switchSource(this.sourceList[index]);
  }

  build() {
    Column() {
      Scroll() {
      Column({ space: 10 }) {
        // 华为账号（系统账号）在最上面，并用分隔线和下面的音乐平台账号分开
        HuaweiAccountCard()

        if (this.accounts.length > 0) {
          ForEach(this.accounts, (account: PlatformAccount) => {
            this.accountItem(account)
          }, (account: PlatformAccount) => account.id)
        } else {
          Row() {
            Text('+')
              .fontSize(24)
              .fontWeight(FontWeight.Lighter)
              .fontColor(this.themeState.color)
              .width(38)
              .height(38)
              .borderRadius(19)
              .textAlign(TextAlign.Center)
              .backgroundColor($r('sys.color.background_primary'))
            Text('暂无账号，请在下方面板添加')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ left: 10 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        CapsuleSegmentedSelector({
          labels: ['网易云', 'QQ', '酷狗'],
          selectedIndex: this.sourceIndex(),
          accentColor: this.themeState.color,
          onSelect: (index: number): void => {
            this.switchSourceByIndex(index);
          }
        })
        CapsuleSegmentedSelector({
          labels: ['二维码', 'Cookie'],
          selectedIndex: this.method === 'qrcode' ? 0 : 1,
          accentColor: this.themeState.color,
          onSelect: (index: number): void => {
            this.switchMethod(index === 0 ? 'qrcode' : 'cookie');
          }
        })
        .width('100%')

        Column() {
          if (this.method === 'qrcode') {
            Column() {
              if (this.qrUrl.length > 0) {
                if (this.source === 'tx') {
                  Column() {
                    Image(this.qrUrl)
                      .width('100%')
                      .height('100%')
                      .objectFit(ImageFit.Contain)
                      .backgroundColor(Color.White)
                  }
                  .width(160)
                  .height(160)
                  .padding(10)
                  .borderRadius(16)
                  .backgroundColor(Color.White)
                } else {
                  Column() {
                      QRCode(this.qrUrl)
                        .width('100%')
                        .height('100%')
                        .color('#000000')
                        .backgroundColor(Color.White)
                    }
                    .width(160)
                    .height(160)
                    .padding(10)
                    .borderRadius(16)
                    .backgroundColor(Color.White)
                  }
                } else {
                  Column() {
                    Text('加载中...')
                      .fontSize(12)
                      .fontColor($r('sys.color.font_tertiary'))
                  }
                  .width(160)
                  .height(160)
                  .justifyContent(FlexAlign.Center)
                  .borderRadius(16)
                  .backgroundColor($r('sys.color.background_tertiary'))
                }

                Column() {
                  Text('扫码登录')
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeState.color)
                    .letterSpacing(1)
                  Text(this.qrStatusText())
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                    .margin({ top: 7 })
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text('扫码成功后会自动完成登录')
                    .fontSize(12)
                    .fontColor($r('sys.color.font_tertiary'))
                    .margin({ top: 7 })
                  Button('刷新二维码')
                    .type(ButtonType.Normal)
                    .fontSize(12)
                    .fontColor(this.themeState.color)
                    .backgroundColor($r('sys.color.background_tertiary'))
                    .height(30)
                    .margin({ top: 10 })
                    .enabled(this.qrStatus !== QrLoginStatus.Confirmed)
                    .onClick(() => {
                      this.startQrLogin();
                    })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
                .margin({ top: 10 })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else {
              Column() {
                Text('Cookie')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_tertiary'))
                TextArea({ placeholder: '粘贴平台的 Cookie（需登录后从浏览器复制）', text: this.cookie })
                  .width('100%')
                  .layoutWeight(1)
                  .fontSize(12)
                  .fontColor($r('sys.color.font_primary'))
                  .placeholderColor($r('sys.color.font_tertiary'))
                  .backgroundColor($r('sys.color.background_tertiary'))
                  .borderRadius(10)
                  .margin({ top: 7 })
                  .onChange((value: string) => {
                    this.cookie = value;
                  })
              }
              .width('100%')
              .height('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .height(330)
          .padding(18)
          .borderRadius(12)
          .backgroundColor($r('sys.color.background_tertiary'))
          .margin({ top: 10 })

          if (this.error.length > 0) {
            Text(this.error)
              .width('100%')
              .fontSize(12)
              .fontColor('#E64545')
              .padding(10)
              .borderRadius(9)
              .backgroundColor('#FDECEC')
              .margin({ top: 10 })
          }

          if (this.method !== 'qrcode') {
            Row() {
              Blank()
              Button(this.isLoading ? '登录中...' : '登录')
                .type(ButtonType.Normal)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_on_primary'))
                .backgroundColor(this.themeState.color)
                .height(34)
                .width(112)
                .borderRadius(17)
                .enabled(!this.isLoading)
                .onClick(() => {
                  this.handleLogin();
                })
          }
          .width('100%')
          .margin({ top: 10 })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
  }
}
