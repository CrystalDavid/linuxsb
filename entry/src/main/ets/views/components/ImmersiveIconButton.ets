import {
  buildImmersiveGlassEffect,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';

export const TITLE_BAR_BACK_BUTTON_SIZE: number = 40;
export const TITLE_BAR_BACK_ICON_SIZE: number = 28;
export const TITLE_BAR_BACK_ICON_WEIGHT: number = 700;
export const GLASS_ACTION_ARROW_ICON_SIZE: number = 24;
export const GLASS_ACTION_ARROW_ICON_WEIGHT: number = 800;

@Component
export struct ImmersiveIconButton {
  icon: Resource = $r('sys.symbol.chevron_left');
  semanticId: string = 'immersive-icon-button';
  semanticLabel: string = '操作';
  buttonSize: number = TITLE_BAR_BACK_BUTTON_SIZE;
  iconSize: number = 20;
  iconWeight: number = 500;
  iconRotation: number = 0;
  iconColor: ResourceColor = $r('app.color.text_primary');
  onAction: () => void = () => {};

  build() {
    // A single native Button keeps the visual and hit target in the title-bar row.
    // HdsActionBar adds its own internal bar positioning and pushed this 44vp action
    // below the adjacent title even when the outer Row itself was centered.
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph(this.icon)
        .id(`${this.semanticId}-icon`)
        .fontSize(this.iconSize)
        .fontWeight(this.iconWeight)
        .fontColor([this.iconColor])
        .rotate({ angle: this.iconRotation })
    }
      .id(this.semanticId)
      .accessibilityText(this.semanticLabel)
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .backgroundEffect(buildImmersiveGlassEffect())
      .borderWidth(IMMERSIVE_GLASS_BORDER_WIDTH)
      .borderColor($r('app.color.bottom_tab_bar_highlight'))
      .borderRadius(this.buttonSize / 2)
      .shadow({
        radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
        color: $r('app.color.bottom_tab_bar_shadow'),
        offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
      })
      .hoverEffect(HoverEffect.None)
      .onClick(() => this.onAction())
  }
}
