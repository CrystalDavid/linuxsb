import { Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect,
  buildImmersiveSystemMaterialModifier,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';
import { GLASS_STYLE_STORAGE_KEY, GlassStyleMode } from '../../common/ui/GlassStyleParams';

@Component
export struct ImmersiveGlassTextButton {
  @Prop label: string = '操作';
  semanticId: string = 'immersive-glass-text-button';
  @Prop actionEnabled: boolean = true;
  @Prop controlHeight: number = 44;
  @Prop horizontalPadding: number = Spacing.XL;
  @Prop labelFontSize: number = Typography.BODY;
  onAction: () => void = () => {};
  @StorageProp(GLASS_STYLE_STORAGE_KEY) private glassStyle: GlassStyleMode = GlassStyleMode.Translucent;

  build() {
    Button(this.label, { type: ButtonType.Capsule, stateEffect: false })
      .id(this.semanticId)
      .height(this.controlHeight)
      .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
      .fontSize(this.labelFontSize)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.actionEnabled ? $r('app.color.brand_primary') : SemanticColors.disabled())
      .backgroundColor(Color.Transparent)
      // Disabled form actions cannot be pressed and do not need to resample the
      // scrolling content behind them on every frame.
      .backgroundEffect(this.actionEnabled ? buildImmersiveGlassEffect(this.glassStyle) : undefined)
      .borderWidth(IMMERSIVE_GLASS_BORDER_WIDTH)
      .borderColor($r('app.color.bottom_tab_bar_highlight'))
      .borderRadius(Radius.PILL)
      .shadow({
        radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
        color: $r('app.color.bottom_tab_bar_shadow'),
        offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
      })
      .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
      .hoverEffect(HoverEffect.None)
      .opacity(this.actionEnabled ? 1 : 0.55)
      .enabled(this.actionEnabled)
      .onClick(() => this.onAction())
  }
}
