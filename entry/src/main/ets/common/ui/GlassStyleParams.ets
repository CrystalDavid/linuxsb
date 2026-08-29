export const GLASS_STYLE_STORAGE_KEY: string = 'glassStyleMode';

export enum GlassStyleMode {
  Translucent = 'TRANSLUCENT'
}

export interface GlassPreset {
  radius: number;
  saturation: number;
  brightness: number;
  tint: ResourceColor;
}

// 通透降级配方（API 23-25）：只保留一层小半径取样，配合较高饱和度
// 保存后方图片与头像的颜色。4vp 是 Pura90 API 24 上“仍能看见内容”与
// “不直接透出文字笔画”之间的折中；低 alpha 冷色 tint 只负责折射感，
// 不能变成白色遮罩。
export function translucentGlassPreset(): GlassPreset {
  return {
    radius: 4,
    saturation: 1.42,
    brightness: 0.98,
    tint: $r('app.color.glass_translucent_tint')
  };
}

export function glassPresetFor(_style: GlassStyleMode): GlassPreset {
  return translucentGlassPreset();
}

export class GlassStyle {
  static init(): void {
    PersistentStorage.persistProp(GLASS_STYLE_STORAGE_KEY, GlassStyleMode.Translucent);
    // Migrate devices that persisted the removed FROSTED option. The app now
    // has one global optical contract, so a stale preference must not keep a
    // single control on the old opaque-white recipe after an upgrade.
    if (AppStorage.has(GLASS_STYLE_STORAGE_KEY)) {
      AppStorage.set(GLASS_STYLE_STORAGE_KEY, GlassStyleMode.Translucent);
    } else {
      AppStorage.setOrCreate(GLASS_STYLE_STORAGE_KEY, GlassStyleMode.Translucent);
    }
  }

  static currentMode(): GlassStyleMode {
    return GlassStyleMode.Translucent;
  }

}
