import {
  buildImmersiveGlassEffect
} from '../../common/ui/ImmersiveActionBarStyle';

export const TITLE_BAR_BACK_BUTTON_SIZE: number = 40;
export const TITLE_BAR_BACK_ICON_SIZE: number = 28;
export const TITLE_BAR_BACK_ICON_WEIGHT: number = 700;

@Component
export struct ImmersiveIconButton {
  icon: Resource = $r('sys.symbol.chevron_left');
  semanticId: string = 'immersive-icon-button';
  semanticLabel: string = '操作';
  buttonSize: number = 44;
  iconSize: number = 20;
  iconWeight: number = 500;
  iconColor: ResourceColor = $r('app.color.text_primary');
  onAction: () => void = () => {};

  build() {
    // A single native Button keeps the visual and hit target in the title-bar row.
    // HdsActionBar adds its own internal bar positioning and pushed this 44vp action
    // below the adjacent title even when the outer Row itself was centered.
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph(this.icon)
        .fontSize(this.iconSize)
        .fontWeight(this.iconWeight)
        .fontColor([this.iconColor])
    }
      .id(this.semanticId)
      .accessibilityText(this.semanticLabel)
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .backgroundEffect(buildImmersiveGlassEffect())
      .borderWidth(1.25)
      .borderColor($r('app.color.hds_floating_action_highlight'))
      .borderRadius(this.buttonSize / 2)
      .shadow({ radius: 12, color: $r('app.color.hds_floating_action_glow'), offsetY: 2 })
      .hoverEffect(HoverEffect.None)
      .onClick(() => this.onAction())
  }
}
