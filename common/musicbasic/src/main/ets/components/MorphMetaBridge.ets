import { AppStorageV2 } from '@kit.ArkUI';
import { AppStorageKeys } from '../constants/Constants';
import { PlayerExpandState } from '../model/PlayerExpandState';
import { Logger } from '../util/Logger';

/** The bridge is the sole metadata paint owner during an active morph session. */
@ComponentV2
export struct MorphMetaBridge {
  @Local expandState: PlayerExpandState =
    AppStorageV2.connect(PlayerExpandState, AppStorageKeys.PLAYER_EXPAND_STATE,
      () => new PlayerExpandState())!;
  private titleController: TextController = new TextController();
  private singerController: TextController = new TextController();
  @Local titleBaseline: number = 0;
  @Local singerBaseline: number = 0;
  @Local titleBaselineGeneration: number = -1;
  @Local singerBaselineGeneration: number = -1;

  private measureBaseline(singer: boolean): void {
    const manager = (singer ? this.singerController : this.titleController).getLayoutManager();
    if (manager.getLineCount() <= 0) {
      return;
    }
    // Baseline is paragraph-local px, NOT an absolute/window Y coordinate.
    // Both clone and genuine target use natural-height Text and default content alignment.
    const line = manager.getLineMetrics(0);
    const baseline = this.getUIContext().px2vp(line.baseline);
    if (baseline <= 0) {
      return;
    }
    const end = singer ? this.expandState.metaEndSinger : this.expandState.metaEndTitle;
    const frame = this.expandState.morphMetaFrame(singer);
    Logger.info('RzdMetaFont', `event=bridge-layout gen=${this.expandState.morphGen} singer=${singer} ` +
      `endFp=${end.fontFp} bridgefontFp=${frame.fontFp} paintScale=${frame.scale} ` +
      `bridgeBaselineVp=${baseline} endBaselineVp=${end.baselineVp} ` +
      `bridgeWidthVp=${end.width} endpointHeightVp=${end.height} fontScaleAppliedByTextOnly=1`);
    Logger.info('RzdMetaMorph', `actualbridgebaseline gen=${this.expandState.morphGen} singer=${singer} ` +
      `baselineVp=${baseline} endbaseline=${end.baselineVp} deltaVp=${baseline - end.baselineVp} ` +
      `glyphHeightPx=${line.height} endpointdimensions=${end.width}x${end.height} ` +
      `targetLineHeightFp=${end.lineHeightFp} trueendnatural=1 cloneNaturalHeight=1 clip=0`);
    if (singer) {
      this.singerBaseline = baseline;
      this.singerBaselineGeneration = this.expandState.metaBridgeGeneration;
    } else {
      this.titleBaseline = baseline;
      this.titleBaselineGeneration = this.expandState.metaBridgeGeneration;
    }
  }

  private naturalBaseline(singer: boolean): number {
    const measured = singer ? this.singerBaseline : this.titleBaseline;
    const generation = singer ? this.singerBaselineGeneration : this.titleBaselineGeneration;
    // A new subtree starts at the genuine target baseline, never a previous track/session.
    return measured > 0 && generation === this.expandState.metaBridgeGeneration ? measured :
      (singer ? this.expandState.metaEndSinger.baselineVp : this.expandState.metaEndTitle.baselineVp);
  }

  @Builder
  MetaText(singer: boolean) {
    Stack({ alignContent: Alignment.TopStart }) {
      Text(singer ? this.expandState.metaEndSinger.content : this.expandState.metaEndTitle.content,
        { controller: singer ? this.singerController : this.titleController })
        .fontSize(this.expandState.morphMetaFrame(singer).fontFp)
        .fontWeight(singer ? this.expandState.metaEndSinger.weight : this.expandState.metaEndTitle.weight)
        .fontFamily(singer ? this.expandState.metaEndSinger.family : this.expandState.metaEndTitle.family)
        .fontColor(singer ? this.expandState.metaEndSinger.color : this.expandState.metaEndTitle.color)
        // Fixed genuine target layout: no font/width reflow on intermediate animation frames.
        .width(singer ? this.expandState.metaEndSinger.width : this.expandState.metaEndTitle.width)
        .maxLines(singer ? this.expandState.metaEndSinger.maxLines : this.expandState.metaEndTitle.maxLines)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        // Keep default Text content alignment, identical to MusicPlayInfoBlock.
        .scale({ x: this.expandState.morphMetaFrame(singer).scale,
          y: this.expandState.morphMetaFrame(singer).scale, centerX: 0, centerY: 0 })
        .translate({ y: this.expandState.morphMetaFrame(singer).baselineVp -
          this.naturalBaseline(singer) * this.expandState.morphMetaFrame(singer).scale })
        .onAreaChange((): void => {
          this.measureBaseline(singer);
        })
        .hitTestBehavior(HitTestMode.None)
    }
    // Full genuine target layout space, never the smaller interpolated source box.
    // Baseline translation can place glyphs outside this box; do not clip their ascent.
    .width(singer ? this.expandState.metaEndSinger.width : this.expandState.metaEndTitle.width)
    .height(singer ? this.expandState.metaEndSinger.height : this.expandState.metaEndTitle.height)
    .clip(false)
    .position({ x: this.expandState.morphMetaFrame(singer).x,
      y: this.expandState.morphMetaFrame(singer).y })
    .opacity(this.expandState.morphMetaFrame(singer).opacity)
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    if (this.expandState.metaBridgeOwnsPaint()) {
      Stack({ alignContent: Alignment.TopStart }) {
        this.MetaText(false)
        this.MetaText(true)
      }
      .width(LayoutPolicy.matchParent)
      .height(LayoutPolicy.matchParent)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }
}
