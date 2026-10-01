import { getPlaylistTransitionState, LocalCoverImage, PlaylistTransitionState } from 'musicbasic';

/** Only mounts drawing nodes during a transition; idle state has no full-screen hit-test area. */
@ComponentV2
export struct PlaylistTransitionOverlay {
  @Local transitionState: PlaylistTransitionState = getPlaylistTransitionState();

  aboutToAppear(): void {
    this.transitionState.hostReady = true;
    console.info('[RzdOverlayInput] playlist host ready; idle drawing nodes=0');
  }

  aboutToDisappear(): void {
    this.transitionState.hostReady = false;
    this.transitionState.cancel('host-disappear');
  }

  build() {
    if (this.transitionState.active) {
      Stack({ alignContent: Alignment.TopStart }) {
        LocalCoverImage({
          src: this.transitionState.cover,
          imageWidth: this.transitionState.rect().width,
          imageHeight: this.transitionState.rect().height,
          radius: 8 * (1 - this.transitionState.progress),
          fit: ImageFit.Cover
        })
          .position({ x: this.transitionState.rect().x, y: this.transitionState.rect().y })
          .hitTestBehavior(HitTestMode.None)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }
}
