export interface ImmersiveLightSystemMaterialEffect {
  materialType: number;
  materialLevel: number;
}

export const HDS_MATERIAL_TYPE_ADAPTIVE: number = 100;
export const HDS_MATERIAL_LEVEL_ADAPTIVE: number = 10;
export const HDS_SCROLL_EFFECT_TYPE_GRADIENT_BLUR: number = 2;
export const HDS_TITLE_BAR_BLUR_RADIUS: number = 24;
export const HDS_TITLE_BAR_MASK_EXTRA_HEIGHT: number = 16;
export const IMMERSIVE_PANEL_BLUR_RADIUS: number = 30;

export enum ImmersiveLightArea {
  TITLE_BAR = 'titleBar',
  FLOATING_ACTION = 'floatingAction',
  PANEL = 'panel',
  INPUT_BAR = 'inputBar'
}

export function adaptiveSystemMaterialEffect(): ImmersiveLightSystemMaterialEffect {
  return { materialType: HDS_MATERIAL_TYPE_ADAPTIVE, materialLevel: HDS_MATERIAL_LEVEL_ADAPTIVE };
}

export function preferredTitleBarScrollEffectType(): number {
  return HDS_SCROLL_EFFECT_TYPE_GRADIENT_BLUR;
}

export function requiresHdsComponentSafeArea(area: ImmersiveLightArea): boolean {
  return area === ImmersiveLightArea.TITLE_BAR;
}

export function requiresHdsLayoutSafeAreaAvoidance(area: ImmersiveLightArea): boolean {
  return area === ImmersiveLightArea.TITLE_BAR;
}
