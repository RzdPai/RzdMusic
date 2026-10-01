import { UIContext } from '@kit.ArkUI';

export const MINI_META_TITLE_ID: string = 'rzd_mini_meta_title';
export const MINI_META_SINGER_ID: string = 'rzd_mini_meta_singer';
export const PLAYER_META_TITLE_ID: string = 'rzd_player_meta_title';
export const PLAYER_META_SINGER_ID: string = 'rzd_player_meta_singer';

/** Actual Text layout and typography. Baseline is measured, never inferred from font size. */
export class MorphMetaEndpoint {
  public id: string = '';
  public controller: TextController = new TextController();
  public content: string = '';
  public fontFp: number = 12;
  public family: string = '';
  public weight: number = 400;
  public color: ResourceColor = Color.Black;
  public opacity: number = 1;
  public maxLines: number = 1;
  public x: number = 0;
  public y: number = 0;
  public width: number = 0;
  public height: number = 0;
  public baselineVp: number = 0;
  public lineHeightFp: number = 0;

  public measure(ui: UIContext, naturalLayout: boolean = false): MorphMetaEndpoint | undefined {
    const node = ui.getFrameNodeById(this.id);
    const manager = this.controller.getLayoutManager();
    if (node === null || node === undefined || manager.getLineCount() <= 0) {
      return undefined;
    }
    const size = node.getMeasuredSize();
    // Target must be p=1 layout, not a chrome/container translated paint frame.
    // Source keeps HDS bar transforms because that is the visible capsule position.
    const position = naturalLayout ? node.getPositionToWindow() : node.getPositionToWindowWithTransform();
    const line = manager.getLineMetrics(0);
    if (size.width <= 0 || size.height <= 0 || line.baseline <= 0) {
      return undefined;
    }
    const snapshot = new MorphMetaEndpoint();
    snapshot.content = this.content;
    snapshot.fontFp = this.fontFp;
    // This is the declared Text lineHeight only (0 means system default).
    // LineMetrics.height is round(ascent + descent), NOT the Text lineHeight setting.
    snapshot.lineHeightFp = this.lineHeightFp;
    snapshot.family = this.family;
    snapshot.weight = this.weight;
    snapshot.color = this.color;
    snapshot.opacity = this.opacity;
    snapshot.maxLines = this.maxLines;
    snapshot.x = position.x;
    snapshot.y = position.y;
    snapshot.width = ui.px2vp(size.width);
    snapshot.height = ui.px2vp(size.height);
    // Paragraph-local Y; window baseline is snapshot.y + baselineVp.
    snapshot.baselineVp = ui.px2vp(line.baseline);
    return snapshot;
  }
}

export class MorphMetaFrame {
  public x: number = 0;
  public y: number = 0;
  public width: number = 0;
  public height: number = 0;
  public fontFp: number = 12;
  public scale: number = 1;
  public baselineVp: number = 0;
  public lineHeightFp: number = 0;
  public opacity: number = 1;
}
