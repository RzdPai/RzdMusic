import { ColorMetrics, LengthMetrics } from '@ohos.arkui.node';
import {
  CapsuleSegmentButtonV2,
  SegmentButtonV2ItemOptions,
  SegmentButtonV2Items
} from '@ohos.arkui.advanced.SegmentButtonV2';

@ComponentV2
export struct CapsuleSegmentedSelector {
  @Param labels: string[] = [];
  @Param selectedIndex: number = 0;
  @Param accentColor: ResourceColor = '#E60012';
  @Param compact: boolean = false;
  @Param onSelect: (index: number) => void = (): void => {};
  @Local items: SegmentButtonV2Items = new SegmentButtonV2Items([]);
  @Local current: number = 0;

  aboutToAppear(): void {
    this.current = this.selectedIndex;
    this.rebuildItems();
  }

  @Monitor('selectedIndex')
  onSelectedIndexChanged(): void {
    this.current = this.selectedIndex;
  }

  @Monitor('labels')
  onLabelsChanged(): void {
    this.rebuildItems();
  }

  private rebuildItems(): void {
    const opts: SegmentButtonV2ItemOptions[] = [];
    for (let i = 0; i < this.labels.length; i++) {
      opts.push({ text: this.labels[i] });
    }
    this.items = new SegmentButtonV2Items(opts);
  }

  build() {
    CapsuleSegmentButtonV2({
      items: this.items,
      selectedIndex: this.current,
      onItemClicked: (index: number): void => {
        this.current = index;
        this.onSelect(index);
      },
      buttonBackgroundColor: ColorMetrics.resourceColor($r('app.color.capsule_background')),
      buttonMinHeight: this.compact ? LengthMetrics.vp(30) : LengthMetrics.vp(40),
      buttonBorderRadius: this.compact ? LengthMetrics.vp(15) : LengthMetrics.vp(20),
      itemMinHeight: this.compact ? LengthMetrics.vp(30) : LengthMetrics.vp(40),
      itemBorderRadius: this.compact ? LengthMetrics.vp(15) : LengthMetrics.vp(20),
      itemFontSize: this.compact ? LengthMetrics.vp(13) : undefined,
      itemSelectedFontSize: this.compact ? LengthMetrics.vp(13) : undefined,
      itemFontColor: ColorMetrics.resourceColor($r('sys.color.font_primary')),
      itemSelectedFontColor: ColorMetrics.resourceColor($r('sys.color.font_on_primary')),
      itemSelectedBackgroundColor: ColorMetrics.resourceColor(this.accentColor)
    })
    .width('100%')
  }
}
