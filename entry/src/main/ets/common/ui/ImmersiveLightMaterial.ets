import { hdsMaterial, ScrollEffectType, SystemMaterialParams } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GlassStyle, GlassStyleMode } from './GlassStyleParams';

// Keep the progressive title-bar treatment, but cap its sampling footprint on
// API 23-24. The previous 24vp kernel was disproportionately expensive while a
// full-width list was moving underneath it.
export const HDS_TITLE_BAR_BLUR_RADIUS: number = 12;
export const HDS_TITLE_BAR_MASK_EXTRA_HEIGHT: number = 8;
export const IMMERSIVE_PANEL_BLUR_RADIUS: number = 6;

export enum ImmersiveLightArea {
  TITLE_BAR = 'titleBar',
  FLOATING_ACTION = 'floatingAction',
  PANEL = 'panel',
  INPUT_BAR = 'inputBar'
}

let cachedMaterialType: hdsMaterial.MaterialType | undefined = undefined;

export function systemMaterialType(): hdsMaterial.MaterialType {
  if (cachedMaterialType !== undefined) {
    return cachedMaterialType;
  }
  try {
    const supported = hdsMaterial.getSystemMaterialTypes();
    hilog.info(0x0000, 'ImmersiveMaterial', 'system material types: %{public}s',
      JSON.stringify(supported));
    // ADAPTIVE is the spatial-UI material that samples the live content below
    // the control. Prefer it over the fixed immersive variant so colorful feed
    // content remains visible as the lively refracted field seen in the system
    // gallery/app-market bars.
    if (supported.indexOf(hdsMaterial.MaterialType.ADAPTIVE) >= 0) {
      cachedMaterialType = hdsMaterial.MaterialType.ADAPTIVE;
    } else if (supported.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
      cachedMaterialType = hdsMaterial.MaterialType.IMMERSIVE;
    } else {
      cachedMaterialType = hdsMaterial.MaterialType.NONE;
    }
  } catch (err) {
    hilog.warn(0x0000, 'ImmersiveMaterial', 'getSystemMaterialTypes failed: %{public}s',
      JSON.stringify(err));
    cachedMaterialType = hdsMaterial.MaterialType.NONE;
  }
  return cachedMaterialType;
}

export function resetSystemMaterialCapabilityCache(): void {
  cachedMaterialType = undefined;
}

export function hasImmersiveSystemMaterial(): boolean {
  return systemMaterialType() !== hdsMaterial.MaterialType.NONE;
}

// ADAPTIVE 会按设备算力与明暗背景控制滤镜。EXQUISITE 在高亮文字密集的列表
// 上容易把整块材质抬成灰白色，不符合 ultra-thin 参考效果。
function adaptiveEffect(): SystemMaterialParams {
  return {
    materialType: systemMaterialType(),
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  };
}

export function glassAwareSystemMaterialEffect(_style: GlassStyleMode): SystemMaterialParams {
  return adaptiveEffect();
}

export function emphasizedSystemMaterialEffect(): SystemMaterialParams {
  return glassAwareSystemMaterialEffect(GlassStyle.currentMode());
}

export function preferredTitleBarScrollEffectType(): ScrollEffectType {
  return ScrollEffectType.GRADIENT_BLUR;
}

export function requiresHdsComponentSafeArea(area: ImmersiveLightArea): boolean {
  return area === ImmersiveLightArea.TITLE_BAR;
}

export function requiresHdsLayoutSafeAreaAvoidance(area: ImmersiveLightArea): boolean {
  return area === ImmersiveLightArea.TITLE_BAR;
}
