import { BlurStrategy } from '@kit.UIDesignKit';
import { ButtonModifier } from '@ohos.arkui.modifier';

// Use one moderate sampling radius for every custom glass control. Six vp keeps
// the content below recognizable without letting its glyphs compete with the
// control's own label.
export const IMMERSIVE_GLASS_RADIUS: number = 6;

export function buildImmersiveGlassEffect(
  radius: number = IMMERSIVE_GLASS_RADIUS,
  saturation: number = 1.08,
  tint: ResourceColor = $r('app.color.hds_floating_action_bg'),
  brightness: number = 1.12
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
      .borderWidth(1.25)
      .borderColor($r('app.color.hds_floating_action_highlight'))
      .backgroundEffect(buildImmersiveGlassEffect())
      .shadow({
        radius: 14,
        color: $r('app.color.hds_floating_action_glow'),
        offsetY: 3
      });
  }
}

export const IMMERSIVE_ACTION_BAR_BLUR_STRATEGY: BlurStrategy = BlurStrategy.DISABLE;

export function buildImmersiveFloatingActionButtonModifier(): ButtonModifier {
  return new ImmersiveFloatingActionButtonModifier();
}
