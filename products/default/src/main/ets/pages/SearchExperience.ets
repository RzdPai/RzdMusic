import { AnimatorResult, AppStorageV2 } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination } from '@kit.UIDesignKit';
import { AmbientState, AppStorageKeys, buildTitleMaterial, Logger } from 'musicbasic';
import { SearchResults } from './SearchResults';

// Independent search driver: never shares player geometry or lifecycle state.
@ComponentV2
export struct SearchExperience {
  @Param homeVisible: boolean = true;
  @Param scrollOffset: number = 0;
  @Param topInset: number = 0;
  @Param closeRevision: number = 0;
  @Param openRevision: number = 0;

  @Monitor('openRevision')
  openRequested(): void {
    this.open();
  }
  @Event onActiveChange: (active: boolean) => void = () => {};
  @Local active: boolean = false;
  @Local progress: number = 0;
  @Local settled: boolean = false;
  @Local query: string = '';
  @Local submitted: string = '';
  @Local requestRevision: number = 0;
  @Local widthVp: number = 360;
  @Local sourceX: number = 16;
  @Local sourceY: number = 64;
  @Local sourceW: number = 328;
  @Local stack: NavPathStack = new NavPathStack();
  @Local ambient: AmbientState =
    AppStorageV2.connect(AmbientState, AppStorageKeys.AMBIENT_STATE, () => new AmbientState())!;
  private driver: AnimatorResult | undefined = undefined;
  private closing: boolean = false;
  private logBucket: number = -1;

  @Monitor('closeRevision')
  closeRequested(): void {
    if (this.active) {
      this.close();
    }
  }

  private collapse(): number {
    return Math.max(0, Math.min(1, this.scrollOffset / 96));
  }

  private homeWidth(): number {
    return Math.max(48, this.widthVp - 32) * (1 - this.collapse()) + 48 * this.collapse();
  }

  private homeX(): number {
    return this.widthVp - 16 - this.homeWidth();
  }

  private mix(from: number, to: number): number {
    return from + (to - from) * this.progress;
  }

  private fieldX(): number {
    return this.active ? this.mix(this.sourceX, 56) : this.homeX();
  }

  private fieldY(): number {
    return this.active ? this.mix(this.sourceY, this.topInset + 8) : this.topInset + 64;
  }

  private fieldWidth(): number {
    return this.active ? this.mix(this.sourceW, Math.max(48, this.widthVp - 128)) : this.homeWidth();
  }

  private run(to: number): void {
    const previous = this.driver;
    this.driver = undefined;
    if (previous !== undefined) {
      previous.cancel();
    }
    const from = this.progress;
    const driver = this.getUIContext().createAnimator({
      duration: Math.max(1, Math.round(420 * Math.abs(to - from))),
      easing: 'cubic-bezier(0.23, 1, 0.32, 1)', delay: 0,
      fill: 'forwards', direction: 'normal', iterations: 1, begin: from, end: to
    });
    this.driver = driver;
    driver.onFrame = (value: number): void => {
      if (this.driver !== driver) {
        return;
      }
      this.progress = value;
      const bucket = Math.floor(value * 10);
      if (bucket !== this.logBucket) {
        this.logBucket = bucket;
        Logger.info('RzdSearchMorph', `frame p=${value.toFixed(3)} rect=${this.fieldX()},${this.fieldY()},${this.fieldWidth()},48`);
      }
    };
    driver.onFinish = (): void => {
      if (this.driver !== driver) {
        return;
      }
      this.progress = to;
      this.driver = undefined;
      this.settled = to === 1;
      if (to === 0) {
        this.stack.clear(false);
        this.active = false;
        this.closing = false;
        this.onActiveChange(false);
      }
      Logger.info('RzdSearchMorph', `finish target=${to}`);
    };
    driver.play();
  }

  private open(): void {
    if (this.active || !this.homeVisible) {
      return;
    }
    this.sourceX = this.homeX();
    this.sourceY = this.topInset + 64;
    this.sourceW = this.homeWidth();
    this.progress = 0;
    this.settled = false;
    this.active = true;
    this.closing = false;
    this.onActiveChange(true);
    Logger.info('RzdSearchMorph', `open offset=${this.scrollOffset} source=${this.sourceX},${this.sourceY},${this.sourceW},48 target=56,${this.topInset + 8},${Math.max(48, this.widthVp - 128)},48`);
    this.run(1);
  }

  private close(): void {
    if (!this.active || this.closing) {
      return;
    }
    this.closing = true;
    this.settled = false;
    this.getUIContext().getFocusController().clearFocus();
    this.run(0);
  }

  private submit(): void {
    if (!this.settled || this.query.trim().length === 0) {
      return;
    }
    this.submitted = this.query.trim();
    this.requestRevision++;
    this.getUIContext().getFocusController().clearFocus();
  }

  aboutToDisappear(): void {
    const driver = this.driver;
    this.driver = undefined;
    if (driver !== undefined) {
      driver.cancel();
    }
  }

  @Builder
  destination(name: string) {
    if (name === 'search') {
      HdsNavDestination() {
        Column() {
          SearchResults({ query: this.submitted, requestRevision: this.requestRevision, interactive: this.settled })
        }
        .padding({ top: this.topInset + 72, bottom: 16 })
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.background_secondary'))
      }
      .hideTitleBar(false)
      .titleBar({
        content: { title: { mainTitle: '' } },
        style: { systemMaterialEffect: buildTitleMaterial(this.ambient.level) }
      })
      .hideBackButton(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .onBackPressed((): boolean => {
        this.close();
        return true;
      })
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.active) {
        HdsNavigation(this.stack) {
          Column().width('100%').height('100%')
            .backgroundColor($r('app.color.background_secondary'))
        }
        .navDestination(this.destination)
        .hideTitleBar(true)
        .mode(NavigationMode.Stack)
        .opacity(this.progress)
        .width('100%')
        .height('100%')
        .onAppear((): void => {
          this.stack.pushPath({ name: 'search' }, false);
        })
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20)
              .fontColor([$r('sys.color.font_primary')])
          }
          .width(40).height(48).backgroundColor(Color.Transparent)
          .accessibilityText('返回').onClick(() => { this.close(); })
          Blank()
          Button('搜索').fontSize(16).width(64).height(48)
            .fontColor($r('app.color.mini_bar_primary')).backgroundColor(Color.Transparent)
            .onClick(() => { this.submit(); })
        }
        .width('100%').padding({ left: 8, right: 8 })
        .position({ x: 0, y: this.topInset + 8 }).opacity(this.progress)
      }
      if (this.homeVisible || this.active) {
        Row({ space: this.active ? 8 : 8 * (1 - this.collapse()) }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(22)
            .fontColor([$r('sys.color.font_secondary')])
          TextInput({ text: this.query, placeholder: '艺人、歌曲或专辑' })
            .fontSize(16).fontColor($r('sys.color.font_primary'))
            .placeholderColor($r('sys.color.font_secondary'))
            .backgroundColor(Color.Transparent).height(48).layoutWeight(1)
            .padding(0).enterKeyType(EnterKeyType.Search)
            .focusable(this.settled).hitTestBehavior(this.settled ? HitTestMode.Default : HitTestMode.None)
            .opacity(this.active ? this.progress : 1 - this.collapse())
            .onChange((value: string): void => { this.query = value; })
            .onSubmit((): void => { this.submit(); })
          if (this.active && this.query.length > 0) {
            Button('×').fontSize(20).width(32).height(40)
              .fontColor($r('sys.color.font_secondary')).backgroundColor(Color.Transparent)
              .accessibilityText('清空').onClick((): void => { this.query = ''; })
          }
        }
        .width(this.fieldWidth()).height(48)
        .padding({ left: 13, right: this.active ? 4 : 8 * (1 - this.collapse()) })
        .clip(true).borderRadius(24)
        .backgroundColor($r('app.color.card_background'))
        .position({ x: this.fieldX(), y: this.fieldY() })
        .onClick((): void => { this.open(); })
        .accessibilityText(this.active ? '搜索输入框' : '搜索音乐')
      }
    }
    .width('100%').height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
    .onAreaChange((_old: Area, area: Area): void => {
      const width = Number(area.width);
      if (width > 0 && Math.abs(width - this.widthVp) > 0.5) {
        this.widthVp = width;
        Logger.info('RzdSearchMorph', `measure width=${width} top=${this.topInset}`);
      }
    })
  }
}
