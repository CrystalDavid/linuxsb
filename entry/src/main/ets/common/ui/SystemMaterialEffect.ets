// =============================================================================
// 沉浸光感（Immersive Light / 液态玻璃）材质 — 统一入口
// =============================================================================
//
// 当前活动产品使用 API 24 编译/target，compatibleSdkVersion 保留到 23。
// 因此统一入口只暴露当前工具链实际可构建的两类能力：
//
//   ① HDS 组件（HdsNavigation 标题栏 / HdsTabs 浮窗）→ 使用真正的
//      systemMaterialEffect，档位用 ADAPTIVE，由系统渲染光感。
//      调用 `preferredSystemMaterialEffect()`。
//
//   ② 普通组件 → 统一使用单层 backgroundEffect。API 26 的通用
//      ImmersiveMaterial 必须在未来 target 26 产品中另行守卫接入，不能在
//      当前 API 24 构建里假装已经命中。
// =============================================================================

import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';
import { systemMaterialType } from './ImmersiveLightMaterial';
import { GlassStyleMode, glassPresetFor } from './GlassStyleParams';
import { buildImmersiveGlassEffect } from './ImmersiveActionBarStyle';

// 让系统按设备算力与当前明暗背景自适应，避免 EXQUISITE 把白色列表抬亮。
export const IMMERSIVE_MATERIAL_LEVEL: hdsMaterial.MaterialLevel =
  hdsMaterial.MaterialLevel.ADAPTIVE;

// HDS 组件的 systemMaterialEffect（标题栏 / HdsTabs 浮窗）。
// 设备能力自适应类型（IMMERSIVE / ADAPTIVE / NONE）。
export function preferredSystemMaterialEffect(): SystemMaterialParams {
  return {
    materialType: systemMaterialType(),
    materialLevel: IMMERSIVE_MATERIAL_LEVEL
  };
}

// 当前普通组件的唯一单层采样；未来 target 26 分支进入前必须清除它。
export function buildImmersiveMaterialEffect(
  style: GlassStyleMode = GlassStyleMode.Translucent,
  overrides?: {
    radius?: number;
    saturation?: number;
    brightness?: number;
    tint?: ResourceColor;
  }
): BackgroundEffectOptions {
  const preset = glassPresetFor(style);
  return buildImmersiveGlassEffect(
    style,
    overrides?.radius ?? preset.radius,
    overrides?.saturation ?? preset.saturation,
    overrides?.tint ?? preset.tint,
    overrides?.brightness ?? preset.brightness
  );
}

// 设备是否声明支持沉浸光感材质（NONE 视为不支持）。
export function hasImmersiveMaterialSupport(): boolean {
  return systemMaterialType() !== hdsMaterial.MaterialType.NONE;
}
