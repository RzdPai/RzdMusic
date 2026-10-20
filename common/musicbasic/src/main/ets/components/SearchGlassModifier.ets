/** Shared search-capsule material for the home and destination title bar. */
export class SearchGlassModifier implements AttributeModifier<StackAttribute> {
  applyNormalAttribute(instance: StackAttribute): void {
    instance.height(40)
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.AVERAGE
      })
      .backgroundColor('#1AFFFFFF')
      .borderRadius(20);
  }
}
