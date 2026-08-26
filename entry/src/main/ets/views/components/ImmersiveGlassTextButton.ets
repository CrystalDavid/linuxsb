import { Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';

@Component
export struct ImmersiveGlassTextButton {
  label: string = '操作';
  semanticId: string = 'immersive-glass-text-button';
  actionEnabled: boolean = true;
  controlHeight: number = 44;
  horizontalPadding: number = Spacing.XL;
  labelFontSize: number = Typography.BODY;
  onAction: () => void = () => {};

  build() {
    Button(this.label, { type: ButtonType.Capsule, stateEffect: false })
      .id(this.semanticId)
      .height(this.controlHeight)
      .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
      .fontSize(this.labelFontSize)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.actionEnabled ? $r('app.color.brand_primary') : SemanticColors.disabled())
      .backgroundColor(Color.Transparent)
      .backgroundEffect(buildImmersiveGlassEffect())
      .borderWidth(IMMERSIVE_GLASS_BORDER_WIDTH)
      .borderColor($r('app.color.bottom_tab_bar_highlight'))
      .borderRadius(Radius.PILL)
      .shadow({
        radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
        color: $r('app.color.bottom_tab_bar_shadow'),
        offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
      })
      .hoverEffect(HoverEffect.None)
      .opacity(this.actionEnabled ? 1 : 0.55)
      .enabled(this.actionEnabled)
      .onClick(() => this.onAction())
  }
}
