import { BlurStrategy } from '@kit.UIDesignKit';
import { ButtonModifier } from '@ohos.arkui.modifier';

// Use one moderate sampling radius for every custom glass control. Six vp keeps
// the content below recognizable without letting its glyphs compete with the
// control's own label.
export const IMMERSIVE_GLASS_RADIUS: number = 6;
export const IMMERSIVE_GLASS_SATURATION: number = 1.08;
export const IMMERSIVE_GLASS_BRIGHTNESS: number = 1.12;
export const IMMERSIVE_GLASS_BORDER_WIDTH: number = 1.25;
export const IMMERSIVE_GLASS_SHADOW_RADIUS: number = 16;
export const IMMERSIVE_GLASS_SHADOW_OFFSET_Y: number = 4;
// The home compose FAB keeps the accepted 52vp reference size. Compact title,
// search and reply actions intentionally use their own smaller scene metrics.
export const IMMERSIVE_FAB_BUTTON_SIZE: number = 52;

export function buildImmersiveGlassEffect(
  radius: number = IMMERSIVE_GLASS_RADIUS,
  saturation: number = IMMERSIVE_GLASS_SATURATION,
  tint: ResourceColor = $r('app.color.bottom_tab_bar_bg'),
  brightness: number = IMMERSIVE_GLASS_BRIGHTNESS
): BackgroundEffectOptions {
  return {
    radius: radius,
    color: tint,
    saturation: saturation,
    brightness: brightness,
    adaptiveColor: AdaptiveColor.DEFAULT,
    policy: BlurStyleActivePolicy.ALWAYS_ACTIVE,
    inactiveColor: tint
  };
}

class ImmersiveFloatingActionButtonModifier extends ButtonModifier {
  applyNormalAttribute(instance: ButtonAttribute): void {
    instance
      .borderWidth(IMMERSIVE_GLASS_BORDER_WIDTH)
      .borderColor($r('app.color.bottom_tab_bar_highlight'))
      .backgroundEffect(buildImmersiveGlassEffect())
      .shadow({
        radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
        color: $r('app.color.bottom_tab_bar_shadow'),
        offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
      });
  }
}

export const IMMERSIVE_ACTION_BAR_BLUR_STRATEGY: BlurStrategy = BlurStrategy.DISABLE;

export function buildImmersiveFloatingActionButtonModifier(): ButtonModifier {
  return new ImmersiveFloatingActionButtonModifier();
}
