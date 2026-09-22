@ComponentV2
export struct CustomColorSheetContent {
  @Param customColor: string = '';
  @Param accentColor: ResourceColor = '#E60012';
  @Param presetColors: string[] = [];
  @Event onColorSelected: (color: string) => void = (): void => {};
  @Event onTextChange: (value: string) => void = (): void => {};
  @Event onApply: () => void = (): void => {};
  @Event onCancel: () => void = (): void => {};
  @Local inputColor: string = '';

  aboutToAppear(): void {
    this.inputColor = this.customColor;
  }

  build() {
    Column({ space: 16 }) {
      Text('自定义主题颜色')
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')

      Row({ space: 12 }) {
        ForEach(this.presetColors.slice(0, 5), (color: string) => {
          Row()
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor(color)
            .border({ width: 2, color: this.inputColor.toLowerCase() === color.toLowerCase() ?
              $r('sys.color.font_primary') : Color.Transparent })
            .onClick(() => {
              this.inputColor = color;
              this.onColorSelected(color);
            })
        }, (color: string) => 'sheet-' + color)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      TextInput({ text: this.inputColor, placeholder: '#RRGGBB' })
        .width('100%')
        .height(44)
        .borderRadius($r('sys.float.corner_radius_level6'))
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.inputColor = value;
          this.onTextChange(value);
        })

      Button('应用')
        .width('100%')
        .height(44)
        .fontSize($r('sys.float.Body_L'))
        .borderRadius($r('sys.float.corner_radius_level6'))
        .backgroundColor(this.accentColor)
        .fontColor($r('sys.color.font_on_primary'))
        .onClick(() => {
          this.onApply();
        })

      Button('取消')
        .width('100%')
        .height(40)
        .fontSize($r('sys.float.Body_M'))
        .borderRadius($r('sys.float.corner_radius_level6'))
        .backgroundColor($r('sys.color.background_secondary'))
        .fontColor($r('sys.color.font_tertiary'))
        .onClick(() => {
          this.onCancel();
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 32 })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
