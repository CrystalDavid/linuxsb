import { hdsMaterial, ScrollEffectType, SystemMaterialParams } from '@kit.UIDesignKit';

export const HDS_TITLE_BAR_BLUR_RADIUS: number = 24;
export const HDS_TITLE_BAR_MASK_EXTRA_HEIGHT: number = 16;
export const IMMERSIVE_PANEL_BLUR_RADIUS: number = 6;

export enum ImmersiveMaterialLevelPreference {
  Adaptive = 'ADAPTIVE',
  Exquisite = 'EXQUISITE',
  Gentle = 'GENTLE',
  Smooth = 'SMOOTH'
}

export enum ImmersiveLightArea {
  TITLE_BAR = 'titleBar',
  FLOATING_ACTION = 'floatingAction',
  PANEL = 'panel',
  INPUT_BAR = 'inputBar'
}

let preferredLevel: ImmersiveMaterialLevelPreference = ImmersiveMaterialLevelPreference.Adaptive;
let cachedMaterialType: hdsMaterial.MaterialType | undefined = undefined;

export function setImmersiveMaterialLevel(level: ImmersiveMaterialLevelPreference): void {
  preferredLevel = level;
}

export function getImmersiveMaterialLevel(): ImmersiveMaterialLevelPreference {
  return preferredLevel;
}

export function systemMaterialType(): hdsMaterial.MaterialType {
  if (cachedMaterialType !== undefined) {
    return cachedMaterialType;
  }
  try {
    const supported = hdsMaterial.getSystemMaterialTypes();
    if (supported.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
      cachedMaterialType = hdsMaterial.MaterialType.IMMERSIVE;
    } else if (supported.indexOf(hdsMaterial.MaterialType.ADAPTIVE) >= 0) {
      cachedMaterialType = hdsMaterial.MaterialType.ADAPTIVE;
    } else {
      cachedMaterialType = hdsMaterial.MaterialType.NONE;
    }
  } catch (_) {
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

export function adaptiveSystemMaterialEffect(): SystemMaterialParams {
  return {
    materialType: systemMaterialType(),
    materialLevel: resolveMaterialLevel(preferredLevel)
  };
}

export function emphasizedSystemMaterialEffect(): SystemMaterialParams {
  const materialType = systemMaterialType();
  return {
    materialType: materialType,
    materialLevel: materialType === hdsMaterial.MaterialType.IMMERSIVE ?
      hdsMaterial.MaterialLevel.EXQUISITE : hdsMaterial.MaterialLevel.ADAPTIVE
  };
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

function resolveMaterialLevel(level: ImmersiveMaterialLevelPreference): hdsMaterial.MaterialLevel {
  switch (level) {
    case ImmersiveMaterialLevelPreference.Exquisite:
      return hdsMaterial.MaterialLevel.EXQUISITE;
    case ImmersiveMaterialLevelPreference.Gentle:
      return hdsMaterial.MaterialLevel.GENTLE;
    case ImmersiveMaterialLevelPreference.Smooth:
      return hdsMaterial.MaterialLevel.SMOOTH;
    default:
      return hdsMaterial.MaterialLevel.ADAPTIVE;
  }
}
