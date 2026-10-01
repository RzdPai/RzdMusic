import { hilog } from '@kit.PerformanceAnalysisKit';

/** Decorative only: safe foreground remains independent of the photo's paint origin. */
@ComponentV2
export struct DetailImmersiveBackdrop {
  @Param photo: string = '';
  @Param color: string = '#1f1f22';
  @Param heroHeightVp: number = 320;
  @Param topAvoidVp: number = 0;
  @Param scrollVp: number = 0;
  @Param page: string = '';
  @Local failed: boolean = false;

  @Monitor('photo')
  onPhotoChanged(): void {
    this.failed = false;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.photo.length > 0 && !this.failed) {
          Image(this.photo)
            .width('100%')
            .height(this.heroHeightVp + 56 + this.topAvoidVp)
            .objectFit(ImageFit.Cover)
            .onError((): void => { this.failed = true; })
        }
        Column()
          .width('100%')
          .height(this.heroHeightVp + 56 + this.topAvoidVp)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [[Color.Transparent, 0], [this.color, 1]]
          })
      }
      .width('100%')
      .height(this.heroHeightVp + 56 + this.topAvoidVp)
      .translate({ y: -this.scrollVp })
    }
    .width(LayoutPolicy.matchParent)
    .height(LayoutPolicy.matchParent)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_old: Area, area: Area): void => {
      hilog.info(0, 'RzdDetailImmersive',
        '%{public}s backdrop areaTopVp=%{public}s avoidTopVp=%{public}f heroVp=%{public}f heightVp=%{public}s',
        this.page, String(area.globalPosition.y), this.topAvoidVp, this.heroHeightVp, String(area.height));
    })
  }
}
