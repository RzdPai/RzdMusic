import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  getPlaylistTransitionState,
  LocalCoverImage,
  PLAYLIST_HERO_COVER_ID,
  PlaylistTransitionState
} from 'musicbasic';

/**
 * 歌单详情页的**唯一**照片层（装饰用）：铺到状态栏、随列表滚动上移，
 * 并在照片之上盖一条「顶部纯透明 → 底部页面取色不透明」的遮罩。
 *
 * 前景（HDS 标题栏按钮、吸顶行、歌曲列表）依旧待在安全区内，本层只做装饰，
 * `HitTestMode.None` 不吃触摸。
 *
 * ⚠️ 一镜到底转场：
 *   1. 落点锚点 `PLAYLIST_HERO_COVER_ID` 挂在本层的照片盒子上，飞行终点矩形与本层照片完全重合，
 *      交棒（`cancel` → `matches` 变 false）时不会有任何跳变；
 *      旧写法把锚点挂在 Hero 里那张 320vp 的图上，和本层 376+状态栏 高的照片裁切不同，必然"跳一下"。
 *   2. 转场进行中（`matches` 为真）本层照片先隐藏：飞行中的封面由壳层 overlay 画在最上层，
 *      这里再显示一次就会**同时出现两张图**。交棒那一刻 overlay 消失、本层照片显示，
 *      位置与裁切完全一致，视觉上是连续的。
 */
@ComponentV2
export struct PlaylistImmersiveBackdrop {
  @Param photo: string = '';
  @Param color: string = '#1f1f22';
  @Param heroHeightVp: number = 320;
  @Param topAvoidVp: number = 0;
  @Param scrollVp: number = 0;
  /** 一镜到底转场的会话 token（由页面 claim 后传入）。 */
  @Param transitionToken: number = 0;
  @Local failed: boolean = false;
  @Local transitionState: PlaylistTransitionState = getPlaylistTransitionState();

  @Monitor('photo')
  onPhotoChanged(): void {
    this.failed = false;
  }

  /** 照片画框总高：Hero 320 + HDS 标题 56 + 状态栏避让。 */
  private frameHeightVp(): number {
    return this.heroHeightVp + 56 + this.topAvoidVp;
  }

  /** 本条照片是否正被转场 overlay 接管（接管时本层不重复画）。 */
  private coveredByTransition(): boolean {
    return this.transitionState.matches(this.photo, this.transitionToken);
  }

  /** 照片加载失败：回退到纯色，并取消正在进行的封面飞行，避免停在空中。 */
  private onPhotoFailed(): void {
    this.failed = true;
    if (this.coveredByTransition()) {
      this.transitionState.cancel('hero-image-failed');
    }
    hilog.warn(0, 'RzdPlaylistImmersive', 'backdrop photo failed, fallback to color');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        // 照片盒：同时是转场的落点锚点（矩形就是这一块）
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.photo.length > 0 && !this.failed) {
            LocalCoverImage({
              src: this.photo,
              imageWidth: '100%',
              imageHeight: this.frameHeightVp(),
              radius: 0,
              fit: ImageFit.Cover,
              onFailed: (): void => { this.onPhotoFailed(); }
            })
          }
        }
        .width('100%')
        .height(this.frameHeightVp())
        .opacity(this.coveredByTransition() ? 0 : 1)
        .id(PLAYLIST_HERO_COVER_ID)
        .onAreaChange((_old: Area, area: Area): void => {
          hilog.info(0, 'RzdPlaylistImmersive',
            'backdrop anchor top=%{public}s height=%{public}s scrollVp=%{public}f',
            String(area.globalPosition.y), String(area.height), this.scrollVp);
          // 落点可量测后启动封面飞行（未 claim / 封面不匹配时方法内部直接返回）
          this.transitionState.start(this.getUIContext(), this.photo, this.transitionToken);
        })

        // 遮罩不受转场影响：飞行过程中目的地也要是同一条渐变
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
    .width(LayoutPolicy.matchParent)
    .height(LayoutPolicy.matchParent)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_old: Area, area: Area): void => {
      hilog.info(0, 'RzdPlaylistImmersive',
        'backdrop areaTopVp=%{public}s avoidTopVp=%{public}f heroVp=%{public}f heightVp=%{public}s',
        String(area.globalPosition.y), this.topAvoidVp, this.heroHeightVp, String(area.height));
    })
  }
}
