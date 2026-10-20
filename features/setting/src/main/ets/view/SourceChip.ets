/** Native source identity shared by the search title pill and its menu. */
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

  private gradientStart(): string {
    switch (this.source) {
      case 'kw':
        return '#FFB13D';
      case 'kg':
        return '#4DA6FF';
      case 'tx':
        return '#4BD97F';
      case 'wy':
        return '#FF5A5A';
      case 'mg':
        return '#FF7BA8';
      default:
        return '#8E97A6';
    }
  }

  private gradientEnd(): string {
    switch (this.source) {
      case 'kw':
        return '#F5860A';
      case 'kg':
        return '#1273E6';
      case 'tx':
        return '#12B04B';
      case 'wy':
        return '#D81E17';
      case 'mg':
        return '#E62E6B';
      default:
        return '#5A6472';
    }
  }

  build() {
    Row({ space: 6 }) {
      Circle()
        .width('10vp')
        .height('10vp')
        .fill(Color.Transparent)
        .borderRadius(5)
        .clip(true)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[this.gradientStart(), 0], [this.gradientEnd(), 1]]
        })
      Text(this.sourceLabel())
        .fontSize('14fp')
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
    }
    .alignItems(VerticalAlign.Center)
  }
}
