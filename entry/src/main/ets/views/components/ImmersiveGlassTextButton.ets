import { Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { buildImmersiveGlassEffect } from '../../common/ui/ImmersiveActionBarStyle';

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
      .borderWidth(1.25)
      .borderColor($r('app.color.hds_floating_action_highlight'))
      .borderRadius(Radius.PILL)
      .shadow({ radius: 12, color: $r('app.color.hds_floating_action_glow'), offsetY: 2 })
      .hoverEffect(HoverEffect.None)
      .opacity(this.actionEnabled ? 1 : 0.55)
      .enabled(this.actionEnabled)
      .onClick(() => this.onAction())
  }
}
