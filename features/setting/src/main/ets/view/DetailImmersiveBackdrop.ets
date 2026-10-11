import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 歌手页 / 专辑页的**唯一照片层**（装饰用）：铺到状态栏、随列表滚动上移，
 * 并在照片之上盖一条「顶部纯透明 → 底部页面取色不透明」的遮罩。
 *
 * ⚠️ 尺寸为什么给**显式数值**而不是 `LayoutPolicy.matchParent` / `'100%'`：
 *   本层挂在一个**内容驱动的 Stack** 里（`Stack(){ 本层; List{…} }`，List 的高度是
 *   `calc(100% - 56vp)`）。给本层写 `height(LayoutPolicy.matchParent)` 时，
 *   父 Stack 的高度又取决于子节点 ⇒ 本层量到 0 高，照片**整张不画**，
 *   屏上只剩 `HdsNavDestination.backgroundColor(avgColor)` ⇒ 用户报的
 *   「歌手页顶部不是歌手照片，是纯色」。
 *   `PlaylistImmersiveBackdrop`（歌单页那份）结构一模一样但它那一层量得到高度，
 *   所以同一个组件在歌单页正常、在这两页不出图 —— 这就是差异所在。
 *   现在改为由页面传入**页内可用高度 vp**（`windowSize.height` − 状态栏避让），
 *   本层只按数值排布，不再依赖任何百分比解析时机。
 *
 * 前景（HDS 标题栏按钮、吸顶行、歌曲列表）依旧待在安全区内，本层只做装饰，
 * `HitTestMode.None` 不吃触摸。
 */
@ComponentV2
export struct DetailImmersiveBackdrop {
  /** 照片地址（空串 / 加载失败 ⇒ 只画渐变底色，不再回退到灰底占位块）。 */
  @Param photo: string = '';
  /** 遮罩底部色 = 页面取色（与 HdsNavDestination.backgroundColor 同源）。 */
  @Param color: string = '#1f1f22';
  /** Hero 高度（vp）。 */
  @Param heroHeightVp: number = 320;
  /** HDS 标题栏行高（vp）：照片要盖到标题栏下面，接缝才看不出来。 */
  @Param rowHeightVp: number = 56;
  /** 状态栏避让高度（vp）。 */
  @Param topAvoidVp: number = 0;
  /** 页内可用高度（vp，不含状态栏避让）：本层的画框高度就是它。 */
  @Param pageHeightVp: number = 0;
  /** 列表滚动位移（vp）：照片跟着上移。 */
  @Param scrollVp: number = 0;
  @Param page: string = '';
  @Local failed: boolean = false;

  @Monitor('photo')
  onPhotoChanged(): void {
    this.failed = false;
    hilog.info(0, 'RzdDetailImmersive', '%{public}s backdrop photo len=%{public}d pageH=%{public}f avoidVp=%{public}f',
      this.page, this.photo.length, this.pageHeightVp, this.topAvoidVp);
  }

  /** 照片画框总高：Hero + 标题栏行高 + 状态栏避让。 */
  private frameHeightVp(): number {
    return this.heroHeightVp + this.rowHeightVp + this.topAvoidVp;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.photo.length > 0 && !this.failed) {
          Image(this.photo)
            .width('100%')
            .height(this.frameHeightVp())
            .objectFit(ImageFit.Cover)
            .draggable(false)
            .onError((): void => {
              this.failed = true;
              hilog.warn(0, 'RzdDetailImmersive', '%{public}s backdrop photo failed, fallback to color',
                this.page);
            })
        }
        Column()
          .width('100%')
          .height(this.frameHeightVp())
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [[Color.Transparent, 0], [this.color, 1]]
          })
      }
      .width('100%')
      .height(this.frameHeightVp())
      .translate({ y: -this.scrollVp })
    }
    .width('100%')
    // ★ 显式高度（vp）：见类注释 —— 这里绝不能用 matchParent / 百分比。
    .height(this.pageHeightVp > 0 ? this.pageHeightVp : this.frameHeightVp())
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_old: Area, area: Area): void => {
      hilog.info(0, 'RzdDetailImmersive',
        '%{public}s backdrop areaTopVp=%{public}s widthVp=%{public}s heightVp=%{public}s avoidTopVp=%{public}f photoLen=%{public}d',
        this.page, String(area.globalPosition.y), String(area.width), String(area.height),
        this.topAvoidVp, this.photo.length);
    })
  }
}
