import { BlurStrategy } from '@kit.UIDesignKit';
import { ButtonModifier } from '@ohos.arkui.modifier';
import { GlassStyleMode, glassPresetFor } from './GlassStyleParams';

// Shared geometry for the one global translucent glass contract. Sampling
// parameters live in GlassStyleParams so every glass control uses the same
// low-alpha, colour-preserving API 23-25 fallback.
export const IMMERSIVE_GLASS_BORDER_WIDTH: number = 0.8;
export const IMMERSIVE_GLASS_SHADOW_RADIUS: number = 10;
export const IMMERSIVE_GLASS_SHADOW_OFFSET_Y: number = 2;
// The home compose FAB keeps the accepted 52vp reference size. Compact title,
// search and reply actions intentionally use their own smaller scene metrics.
export const IMMERSIVE_FAB_BUTTON_SIZE: number = 52;

// ---- Locked bottom tab bar recipe (CheckBottomTabVisualLock revision) ----
// The accepted bottom bar look: on API 24 one ArkUI backgroundEffect samples
// the content below. Light and dark resources use an 8/255-alpha cool tint,
// never a white fill; a bright 0.8vp rim provides the watery edge while the
// 4vp radius keeps avatars and colour blocks visible. Selection is carried by
// the brand-blue glyph/text plus a faint local glow, not a solid white capsule.
export const BOTTOM_TAB_GLASS_RADIUS: number = 4;
export const BOTTOM_TAB_GLASS_SATURATION: number = 1.42;
export const BOTTOM_TAB_GLASS_BRIGHTNESS: number = 0.98;
export const BOTTOM_TAB_GLASS_BORDER_WIDTH: number = 0.8;
export const BOTTOM_TAB_GLASS_SHADOW_RADIUS: number = 12;
export const BOTTOM_TAB_GLASS_SHADOW_OFFSET_Y: number = 3;

export function buildBottomTabGlassEffect(): BackgroundEffectOptions {
  return {
    radius: BOTTOM_TAB_GLASS_RADIUS,
    color: $r('app.color.bottom_tab_bar_bg'),
    saturation: BOTTOM_TAB_GLASS_SATURATION,
    brightness: BOTTOM_TAB_GLASS_BRIGHTNESS,
    policy: BlurStyleActivePolicy.ALWAYS_ACTIVE,
    inactiveColor: $r('app.color.bottom_tab_bar_bg')
  };
}

// 单层 backgroundEffect 降级配方（targetSdkVersion 已降回 API 24，编译 SDK
// 不再暴露 uiMaterial.ImmersiveMaterial / deviceInfo.apiAvailable 等 API 26
// 接口）。调用方已声明一层 backgroundEffect 作为采样层，这里只补充共享的
// 细边与中性阴影，与升级前的 API 23-25 行为一致。
export class ImmersiveSystemMaterialModifier implements AttributeModifier<CommonAttribute> {
  private readonly enabled: boolean;

  constructor(style: GlassStyleMode, enabled: boolean) {
    this.enabled = enabled;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    if (!this.enabled) {
      return;
    }
    instance
      .borderWidth(IMMERSIVE_GLASS_BORDER_WIDTH)
      .borderColor($r('app.color.bottom_tab_bar_highlight'))
      .shadow({
        radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
        color: $r('app.color.bottom_tab_bar_shadow'),
        offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
      });
  }
}

export function buildImmersiveSystemMaterialModifier(
  style: GlassStyleMode = GlassStyleMode.Translucent,
  enabled: boolean = true
): ImmersiveSystemMaterialModifier {
  return new ImmersiveSystemMaterialModifier(style, enabled);
}

export function buildImmersiveGlassEffect(
  style: GlassStyleMode = GlassStyleMode.Translucent,
  radius?: number,
  saturation?: number,
  tint?: ResourceColor,
  brightness?: number
): BackgroundEffectOptions {
  const preset = glassPresetFor(style);
  const resolvedTint = tint ?? preset.tint;
  return {
    radius: radius ?? preset.radius,
    color: resolvedTint,
    saturation: saturation ?? preset.saturation,
    brightness: brightness ?? preset.brightness,
    // Keep the established low-alpha tint static. The adaptive average mode
    // asks RenderService to recalculate the sampled mean colour whenever feed or
    // transition content changes; that extra per-frame pass was visible as
    // scroll and tab-switch jank on the Pura 90 emulator.
    policy: BlurStyleActivePolicy.ALWAYS_ACTIVE,
    inactiveColor: resolvedTint
  };
}

class ImmersiveFloatingActionButtonModifier extends ButtonModifier {
  private readonly style: GlassStyleMode;

  constructor(style: GlassStyleMode) {
    super();
    this.style = style;
  }

  applyNormalAttribute(instance: ButtonAttribute): void {
    instance
      .borderWidth(IMMERSIVE_GLASS_BORDER_WIDTH)
      .borderColor($r('app.color.bottom_tab_bar_highlight'))
      .backgroundEffect(buildImmersiveGlassEffect(this.style))
      .shadow({
        radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
        color: $r('app.color.bottom_tab_bar_shadow'),
        offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
      });
  }
}

export const IMMERSIVE_ACTION_BAR_BLUR_STRATEGY: BlurStrategy = BlurStrategy.DISABLE;

export function buildImmersiveFloatingActionButtonModifier(
  style: GlassStyleMode = GlassStyleMode.Translucent
): ButtonModifier {
  return new ImmersiveFloatingActionButtonModifier(style);
}
