import { AppStorageV2, LengthMetrics } from '@kit.ArkUI';
import { abilityAccessCtrl, common, ConfigurationConstant, PermissionRequestResult } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { pasteboard } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BlurStrategy, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, TitleSize } from '@kit.UIDesignKit';
import { AppStorageKeys, AmbientState, MusicAppState, MusicStoreService, ThemeState, TitleBarConstants, buildTitleMaterial, getStatusBarTopVpFromWindowUtil } from 'musicbasic';
import { RecognitionResult, RecognitionStatus, EngineReport, EngineResultGroup } from '../recognize/RecognitionTypes';
import { MicCancelledError, MicPermissionError, MicRecorder } from '../recognize/MicRecorder';
import { RecognitionNetworkError } from '../recognize/errors';
import { HistoryStore } from '../recognize/HistoryStore';
import { MultiEngineOutput, recognizeAll } from '../recognize/RecognitionEngine';
import { NeteaseRecognizer } from '../recognize/NeteaseRecognizer';
import { LXSearchSong, lxSearch } from '../source/LXMusicSDK';
import { OnlinePlayUtil } from '../util/OnlinePlayUtil';

const LOG_DOMAIN = 0x0000;
const LOG_TAG = 'RzdRecognitionPage';

class AfpBridge {
  private netease: NeteaseRecognizer;

  constructor(netease: NeteaseRecognizer) {
    this.netease = netease;
  }

  onResult(result: string): void {
    this.netease.handleAfpResult(result);
  }
}

/**
 * 听歌识曲页面：酷狗 + 网易云双引擎，麦克风采集 12 秒后识别。
 */
@ComponentV2
export struct MusicRecognitionPage {
  @Consumer('pageIndexInfos') pageStack: NavPathStack = new NavPathStack();
  @Local status: RecognitionStatus = RecognitionStatus.Idle;
  @Local captureProgress: number = 0;
  @Local errorText: string = '';
  @Local result: RecognitionResult | undefined = undefined;
  @Local groups: EngineResultGroup[] = [];
  @Local engineReports: EngineReport[] = [];
  @Local history: RecognitionResult[] = [];
  @Local themeState: ThemeState =
    AppStorageV2.connect(ThemeState, AppStorageKeys.THEME_STATE, () => new ThemeState())!;
  @Local ambientState: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!;
  private recorder: MicRecorder = new MicRecorder();
  private webController: webview.WebviewController = new webview.WebviewController();
  private netease: NeteaseRecognizer = new NeteaseRecognizer(this.webController);
  private afpBridge: AfpBridge = new AfpBridge(this.netease);
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    HistoryStore.init(this.getUIContext().getHostContext() as common.UIAbilityContext);
    this.history = HistoryStore.load();
  }

  aboutToDisappear(): void {
    this.recorder.stop();
  }

  private isBusy(): boolean {
    return this.status === RecognitionStatus.Capturing ||
      this.status === RecognitionStatus.Recognizing ||
      this.status === RecognitionStatus.RequestingPermission;
  }

  private statusText(): string {
    switch (this.status) {
      case RecognitionStatus.Idle:
        return '就绪，点击开始识别';
      case RecognitionStatus.RequestingPermission:
        return '请求麦克风权限';
      case RecognitionStatus.Capturing:
        return '正在聆听…';
      case RecognitionStatus.Recognizing:
        return '正在识别…';
      case RecognitionStatus.Matched:
        return '识别成功';
      case RecognitionStatus.NotMatched:
        return '未识别到歌曲';
      case RecognitionStatus.PermissionDenied:
        return '麦克风权限被拒绝';
      case RecognitionStatus.NoAudio:
        return '未检测到声音';
      case RecognitionStatus.NetworkError:
        return '网络错误';
      default:
        return '识别出错';
    }
  }

  private statusDetail(): string {
    if (this.status === RecognitionStatus.Capturing) {
      return `采集进度 ${Math.round(this.captureProgress * 100)}%`;
    }
    if (this.status === RecognitionStatus.PermissionDenied ||
      this.status === RecognitionStatus.NoAudio || this.status === RecognitionStatus.NetworkError ||
      this.status === RecognitionStatus.Error) {
      return this.errorText;
    }
    return '';
  }

  private async requestMicPermission(): Promise<boolean> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, ['ohos.permission.MICROPHONE']);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (_err) {
      return false;
    }
  }

  private providerName(provider: string): string {
    if (provider === 'kg') {
      return '酷狗';
    }
    if (provider === 'wy') {
      return '网易云';
    }
    return provider;
  }

  /** True when the app currently renders in dark color mode (drives status bar icon color). */
  private isDarkTheme(): boolean {
    const store = MusicStoreService.getInstance();
    const mode: number = store.getColorMode();
    if (mode === 0) {
      return false;
    }
    if (mode === 1) {
      return true;
    }
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined || ctx.config === undefined) {
      return false;
    }
    return ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  private async handleStart(): Promise<void> {
    if (this.isBusy()) {
      return;
    }
    this.status = RecognitionStatus.RequestingPermission;
    const granted: boolean = await this.requestMicPermission();
    if (!granted) {
      this.status = RecognitionStatus.PermissionDenied;
      this.errorText = '麦克风权限请求被拒绝';
      return;
    }
    this.status = RecognitionStatus.Capturing;
    this.captureProgress = 0;
    this.errorText = '';
    this.engineReports = [];
    this.groups = [];
    let samples: Int16Array;
    try {
      samples = await this.recorder.capture((progress: number): void => {
        this.captureProgress = progress;
      });
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, '麦克风采集异常: %{public}s', JSON.stringify(err));
      this.handleError(err);
      return;
    }
    const rms: number = MicRecorder.computeRms(samples);
    const durationSec: number = samples.length / 16000;
    hilog.info(LOG_DOMAIN, LOG_TAG, '采集完成 样本数=%{public}d RMS=%{public}f 时长=%{public}fs',
      samples.length, rms, durationSec);
    if (rms < 32 / 32768) {
      this.status = RecognitionStatus.NoAudio;
      this.errorText = '未检测到有效声音，请靠近音源后重试';
      return;
    }
    this.status = RecognitionStatus.Recognizing;
    try {
      const output: MultiEngineOutput = await recognizeAll(samples, this.netease);
      this.engineReports = output.engineReports;
      this.groups = output.groups;
      for (const report of output.engineReports) {
        hilog.info(LOG_DOMAIN, LOG_TAG, '引擎报告 %{public}s status=%{public}s', report.engine, report.status);
      }
      for (const group of output.groups) {
        hilog.info(LOG_DOMAIN, LOG_TAG, '引擎 %{public}s 结果数=%{public}d 错误=%{public}s',
          group.engine, group.results.length, group.error);
      }
      if (output.match !== undefined) {
        this.result = output.match;
        this.status = RecognitionStatus.Matched;
        hilog.info(LOG_DOMAIN, LOG_TAG, '识别成功: %{public}s id=%{public}s',
          output.match.title, output.match.providerTrackId);
        await HistoryStore.add(output.match);
        this.history = HistoryStore.load();
      } else {
        this.result = undefined;
        this.status = RecognitionStatus.NotMatched;
        hilog.warn(LOG_DOMAIN, LOG_TAG, '两个引擎均未返回可展示结果');
      }
    } catch (err) {
      this.handleError(err);
    }
  }

  private handleError(err: Object): void {
    if (err instanceof MicCancelledError) {
      this.status = RecognitionStatus.Idle;
      this.errorText = '';
      return;
    }
    if (err instanceof MicPermissionError) {
      this.status = RecognitionStatus.PermissionDenied;
      this.errorText = err.message;
      return;
    }
    if (err instanceof RecognitionNetworkError) {
      this.status = RecognitionStatus.NetworkError;
      this.errorText = err.message;
      return;
    }
    this.status = RecognitionStatus.Error;
    this.errorText = err instanceof Error ? err.message : String(err);
  }

  private handleStop(): void {
    this.recorder.stop();
    this.status = RecognitionStatus.Idle;
    this.errorText = '';
  }

  /** 播放识别结果：解析 providerTrackId（如 kg:123）为来源+歌曲ID，走在线播放链路；
   *  直连 ID 解析播放地址失败时，回退到按歌名+歌手搜索同源歌曲（识别返回的 ID 不一定是可播放哈希）。 */
  private async playResult(item: RecognitionResult): Promise<void> {
    const sep: number = item.providerTrackId.indexOf(':');
    const source: string = sep > 0 ? item.providerTrackId.substring(0, sep) : 'kg';
    const songId: string = sep > 0 ? item.providerTrackId.substring(sep + 1) : item.providerTrackId;
    const buildSong = (id: string): LXSearchSong => {
      const song: LXSearchSong = {
        songId: id,
        name: item.title,
        singer: item.artist,
        albumName: item.album,
        albumId: '',
        source: source,
        interval: '',
        img: item.coverUrl,
        types: []
      };
      return song;
    };
    hilog.info(LOG_DOMAIN, LOG_TAG, '播放识别结果 source=%{public}s id=%{public}s', source, songId);
    const played: boolean =
      await OnlinePlayUtil.playSearchSong(this.appState, buildSong(songId), this.getUIContext());
    if (!played && (source === 'kg' || source === 'wy')) {
      hilog.info(LOG_DOMAIN, LOG_TAG, '直连播放失败，按歌名搜索补播: %{public}s - %{public}s', item.title, item.artist);
      try {
        const res = await lxSearch(source, `${item.title} ${item.artist}`.trim(), 1, 10);
        if (res.list.length > 0) {
          const alt: LXSearchSong = res.list[0];
          hilog.info(LOG_DOMAIN, LOG_TAG, '搜索补播命中: %{public}s id=%{public}s', alt.name, alt.songId);
          void OnlinePlayUtil.playSearchSong(this.appState, alt, this.getUIContext());
        } else {
          this.getUIContext().getPromptAction().showToast({ message: '未能找到可播放版本', duration: 2000 });
        }
      } catch (_err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, '搜索补播异常: %{public}s', JSON.stringify(_err));
      }
    }
  }

  private getTitleBar(): HdsNavigationTitleBarOptions {
    return {
      padding: {
        start: LengthMetrics.vp(16),
        end: LengthMetrics.vp(16)
      },
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
          mainTitle: '听歌识曲',
          mainTitleSize: TitleSize.TITLE_ML
        },
        backIcon: {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true,
          action: (): void => {
            this.pageStack.pop();
          }
        },
        menu: {
          value: []
        }
      }
    };
  }

  @Builder
  private ResultRow(item: RecognitionResult) {
    Row({ space: 10 }) {
      if (item.coverUrl.length > 0) {
        Image(item.coverUrl)
          .width(44)
          .height(44)
          .borderRadius($r('sys.float.corner_radius_level3'))
          .objectFit(ImageFit.Cover)
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
      Column({ space: 2 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text((item.artist.length > 0 ? item.artist : '未知歌手') +
          (item.album.length > 0 ? ' · ' + item.album : ''))
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.providerName(item.providerTrackId.substring(0, item.providerTrackId.indexOf(':'))))
        .fontSize($r('sys.float.Caption_S'))
        .fontColor(this.themeState.color)
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .borderRadius(3)
        .backgroundColor($r('app.color.card_background'))

      SymbolGlyph($r('sys.symbol.dot_grid_1x2_circle'))
        .fontSize(20)
        .fontColor([$r('sys.color.font_tertiary')])
        .bindMenu([
          {
            value: '播放',
            action: (): void => {
              void this.playResult(item);
            }
          },
          {
            value: '复制信息',
            action: (): void => {
              const pasteData: pasteboard.PasteData = pasteboard.createData(
                pasteboard.MIMETYPE_TEXT_PLAIN, `${item.title} - ${item.artist}`);
              void pasteboard.getSystemPasteboard().setData(pasteData);
              this.getUIContext().getPromptAction().showToast({ message: '已复制', duration: 1500 });
            }
          }
        ])
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .onClick(() => {
      void this.playResult(item);
    })
  }

  build() {
    HdsNavDestination() {
      Column() {
        Scroll(this.pageScroller) {
          Column({ space: 16 }) {
            Column({ space: 10 }) {
              Text(this.statusText())
                .fontSize($r('sys.float.Subtitle_L'))
                .fontWeight(FontWeight.Medium)
                .fontColor(this.status === RecognitionStatus.Matched ? '#34c759' : $r('sys.color.font_primary'))

              if (this.statusDetail().length > 0) {
                Text(this.statusDetail())
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor($r('sys.color.font_tertiary'))
              }

              if (this.isBusy() && this.status === RecognitionStatus.Capturing) {
                Progress({ value: Math.round(this.captureProgress * 100), total: 100, type: ProgressType.Linear })
                  .width('70%')
                  .color(this.themeState.color)
                  .margin({ top: 8 })
              }

              Button(this.isBusy() ? '停止' : '开始识别')
                .width(168)
                .height(42)
                .fontSize($r('sys.float.Body_L'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor(this.isBusy() ? $r('sys.color.font_tertiary') : this.themeState.color)
                .fontColor($r('sys.color.font_on_primary'))
                .margin({ top: 10 })
                .onClick(() => {
                  if (this.isBusy()) {
                    this.handleStop();
                  } else {
                    void this.handleStart();
                  }
                })
            }
            .width('100%')
            .padding({ top: 18, bottom: 18 })

            if (this.result !== undefined && this.status === RecognitionStatus.Matched) {
              Column({ space: 6 }) {
                Text('识别结果')
                  .fontSize($r('sys.float.Body_L'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                  .width('100%')
                this.ResultRow(this.result)
              }
              .width('100%')
              .padding(14)
              .borderRadius($r('sys.float.corner_radius_level12'))
              .backgroundColor($r('app.color.card_background'))
            }

            if (this.groups.length > 0) {
              Column({ space: 6 }) {
                Text('引擎结果')
                  .fontSize($r('sys.float.Body_L'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                  .width('100%')
                ForEach(this.groups, (group: EngineResultGroup) => {
                  Column({ space: 4 }) {
                    Row() {
                      Text(this.providerName(group.engine))
                        .fontSize($r('sys.float.Body_S'))
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('sys.color.font_primary'))
                      Blank()
                      if (group.error.length > 0) {
                        Text(group.error)
                          .fontSize($r('sys.float.Caption_S'))
                          .fontColor('#ff5f57')
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      } else if (group.results.length === 0) {
                        Text('未匹配')
                          .fontSize($r('sys.float.Caption_S'))
                          .fontColor($r('sys.color.font_tertiary'))
                      } else {
                        Text(`${group.results.length} 条`)
                          .fontSize($r('sys.float.Caption_S'))
                          .fontColor($r('sys.color.font_tertiary'))
                      }
                    }
                    .width('100%')

                    ForEach(group.results, (item: RecognitionResult) => {
                      this.ResultRow(item)
                    }, (item: RecognitionResult) => item.id)
                  }
                  .width('100%')
                }, (group: EngineResultGroup) => group.engine)
              }
              .width('100%')
              .padding(14)
              .borderRadius($r('sys.float.corner_radius_level12'))
              .backgroundColor($r('app.color.card_background'))
            }

            if (this.status === RecognitionStatus.NotMatched) {
              Text('没有找到匹配的歌曲，换一首再试试')
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_tertiary'))
            }

            Column({ space: 8 }) {
              Row() {
                Text('识别历史')
                  .fontSize($r('sys.float.Body_L'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                if (this.history.length > 0) {
                  Text('清空')
                    .fontSize($r('sys.float.Caption_L'))
                    .fontColor($r('sys.color.font_tertiary'))
                    .onClick(() => {
                      void HistoryStore.clear();
                      this.history = [];
                    })
                }
              }
              .width('100%')

              if (this.history.length === 0) {
                Text('暂无识别记录')
                  .fontSize($r('sys.float.Caption_L'))
                  .fontColor($r('sys.color.font_tertiary'))
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 12, bottom: 12 })
              } else {
                ForEach(this.history.slice(0, 20), (item: RecognitionResult) => {
                  this.ResultRow(item)
                }, (item: RecognitionResult) => item.id)
              }
            }
            .width('100%')
            .padding(14)
            .borderRadius($r('sys.float.corner_radius_level12'))
            .backgroundColor($r('app.color.card_background'))

            Blank()
          }
          .width('100%')
          .padding({
            top: getStatusBarTopVpFromWindowUtil() + TitleBarConstants.ROW_HEIGHT_VP,
            left: 16,
            right: 16,
            bottom: 24
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.Top)

        // 网易云 AFP 指纹 WASM 的隐藏宿主（与 LXSourceEngine 同款配置）：
        // 使用 1x1 + opacity(0) 而非负坐标定位，保证 WebView 在
        // HdsNavDestination 内能正常加载 afp_worker.html，onPageEnd 触发 markReady。
        Web({ src: $rawfile('afp/afp_worker.html'), controller: this.webController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(true)
          .onlineImageAccess(true)
          .mixedMode(MixedMode.All)
          .javaScriptProxy({
            object: this.afpBridge,
            name: 'afpBridge',
            methodList: ['onResult'],
            controller: this.webController,
          })
          .width(1)
          .height(1)
          .opacity(0)
          .onPageEnd(() => {
            hilog.info(LOG_DOMAIN, LOG_TAG, 'AFP WebView 加载完成 onPageEnd');
            this.netease.markReady();
          })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(false)
    .titleBar(this.getTitleBar())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.pageScroller])
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .systemBarStyle(
      { statusBarContentColor: this.isDarkTheme() ? '#FFFFFF' : '#000000' },
      { statusBarContentColor: this.isDarkTheme() ? '#FFFFFF' : '#000000' })
    .backgroundColor($r('app.color.background_secondary'))
  }
}

@Builder
export function MusicRecognitionPageBuilder(name: string, param: Object) {
  MusicRecognitionPage()
}
