import { common, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { ImmersiveWindow } from '../ui/ImmersiveWindow';

export const APP_IS_DARK_STORAGE_KEY: string = 'appIsDark';
export const APP_THEME_MODE_STORAGE_KEY: string = 'appThemeMode';

export enum AppThemeMode {
  System = 'SYSTEM',
  Light = 'LIGHT',
  Dark = 'DARK'
}

export class ThemeManager {
  private static effectiveIsDark: boolean = false;

  static init(context: common.UIAbilityContext): void {
    AppStorage.setOrCreate(APP_IS_DARK_STORAGE_KEY, false);
    PersistentStorage.persistProp(APP_THEME_MODE_STORAGE_KEY, AppThemeMode.System);
    ThemeManager.setMode(context, ThemeManager.currentMode());
  }

  static currentMode(): AppThemeMode {
    const stored = AppStorage.get<string>(APP_THEME_MODE_STORAGE_KEY) ?? AppThemeMode.System;
    if (stored === AppThemeMode.Light || stored === AppThemeMode.Dark) {
      return stored as AppThemeMode;
    }
    return AppThemeMode.System;
  }

  static setMode(context: common.UIAbilityContext, mode: AppThemeMode): void {
    if (AppStorage.has(APP_THEME_MODE_STORAGE_KEY)) {
      AppStorage.set(APP_THEME_MODE_STORAGE_KEY, mode);
    } else {
      AppStorage.setOrCreate(APP_THEME_MODE_STORAGE_KEY, mode);
    }
    const appContext = context.getApplicationContext();
    try {
      if (mode === AppThemeMode.Light) {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else if (mode === AppThemeMode.Dark) {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (_) {}
    if (mode === AppThemeMode.Light) {
      ThemeManager.publishEffectiveMode(false);
    } else if (mode === AppThemeMode.Dark) {
      ThemeManager.publishEffectiveMode(true);
    } else {
      ThemeManager.applyConfiguration(context.config);
    }
  }

  static applyConfiguration(config: Configuration): void {
    if (config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      ThemeManager.effectiveIsDark = true;
    } else if (config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      ThemeManager.effectiveIsDark = false;
    } else {
      return;
    }
    ThemeManager.publishEffectiveMode(ThemeManager.effectiveIsDark);
  }

  private static publishEffectiveMode(dark: boolean): void {
    ThemeManager.effectiveIsDark = dark;
    if (AppStorage.has(APP_IS_DARK_STORAGE_KEY)) {
      AppStorage.set(APP_IS_DARK_STORAGE_KEY, dark);
    } else {
      AppStorage.setOrCreate(APP_IS_DARK_STORAGE_KEY, dark);
    }
    ImmersiveWindow.applyBarContentColor(ThemeManager.effectiveIsDark);
  }
}
