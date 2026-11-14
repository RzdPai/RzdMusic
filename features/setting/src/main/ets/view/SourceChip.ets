import { platformLabel } from 'player';

/**
 * 搜索页右上角「音源平台」胶囊里的文字（用户 2026-10-20：把平台那个圆点去掉）。
 * ★ 2026-11-14：中文名不再自带一份 switch —— 统一取 `platformLabel()`
 *   （`SourceDeclaredInfo` 里的唯一一份）。原来这里把 `wy` 写成「网易」，
 *   而别处（首页/分享导入）已经是「网易云」，同一平台两个名字。
 */
@ComponentV2
export struct SourceChip {
  @Param source: string = 'all';
  @Param label: string = '';

  private sourceLabel(): string {
    if (this.label.length > 0) {
      return this.label;
    }
    const id: string = this.source.length > 0 ? this.source : 'all';
    if (id === 'all') {
      return '聚合';
    }
    const text: string = platformLabel(id);
    // 取不到名字（未知 id / `local` 之类）仍显示「聚合」，与旧行为一致
    return text.length > 0 && text !== id ? text : '聚合';
  }

  build() {
    Text(this.sourceLabel())
      .fontSize(14)
      .fontColor($r('sys.color.font_primary'))
      .maxLines(1)
  }
}
