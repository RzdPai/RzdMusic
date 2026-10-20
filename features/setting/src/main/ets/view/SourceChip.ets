/** 搜索页右上角「音源平台」胶囊里的文字（用户 2026-10-20：把平台那个圆点去掉）。 */
@ComponentV2
export struct SourceChip {
  @Param source: string = 'all';
  @Param label: string = '';

  private sourceLabel(): string {
    if (this.label.length > 0) {
      return this.label;
    }
    switch (this.source) {
      case 'kw':
        return '酷我';
      case 'kg':
        return '酷狗';
      case 'tx':
        return 'QQ';
      case 'wy':
        return '网易';
      case 'mg':
        return '咪咕';
      default:
        return '聚合';
    }
  }

  build() {
    Text(this.sourceLabel())
      .fontSize(14)
      .fontColor($r('sys.color.font_primary'))
      .maxLines(1)
  }
}
