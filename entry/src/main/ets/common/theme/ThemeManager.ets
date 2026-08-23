import { common, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { ImmersiveWindow } from '../ui/ImmersiveWindow';

export const APP_IS_DARK_STORAGE_KEY: string = 'appIsDark';

export class ThemeManager {
  private static effectiveIsDark: boolean = false;

  static init(context: common.UIAbilityContext): void {
    AppStorage.setOrCreate(APP_IS_DARK_STORAGE_KEY, false);
    ThemeManager.applyConfiguration(context.config);
  }

  static applyConfiguration(config: Configuration): void {
    if (config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      ThemeManager.effectiveIsDark = true;
    } else if (config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      ThemeManager.effectiveIsDark = false;
    } else {
      return;
    }
    AppStorage.setOrCreate(APP_IS_DARK_STORAGE_KEY, ThemeManager.effectiveIsDark);
    ImmersiveWindow.applyBarContentColor(ThemeManager.effectiveIsDark);
  }
}
