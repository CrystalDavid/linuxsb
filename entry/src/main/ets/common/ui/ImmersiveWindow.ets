import window from '@ohos.window';
import display from '@ohos.display';

export const SYS_TOP_INSET_KEY: string = 'sysTopInsetVp';
export const SYS_BOTTOM_INSET_KEY: string = 'sysBottomInsetVp';

export class ImmersiveWindow {
  private static win: window.Window | undefined = undefined;
  private static lastDark: boolean = false;

  static init(win: window.Window): void {
    ImmersiveWindow.win = win;
    win.setWindowLayoutFullScreen(true).catch(() => {});
    ImmersiveWindow.applyBarContentColor(ImmersiveWindow.lastDark);
    ImmersiveWindow.syncInsets(win);
    try {
      win.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM ||
          data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          ImmersiveWindow.syncInsets(win);
        }
      });
    } catch (_) {}
  }

  static applyBarContentColor(dark: boolean): void {
    ImmersiveWindow.lastDark = dark;
    const current = ImmersiveWindow.win;
    if (current === undefined) {
      return;
    }
    const color = dark ? '#FFFFFF' : '#000000';
    current.setWindowSystemBarProperties({
      statusBarContentColor: color,
      navigationBarContentColor: color,
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000'
    }).catch(() => {});
  }

  private static syncInsets(win: window.Window): void {
    try {
      const system = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const indicator = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const density = display.getDefaultDisplaySync().densityPixels;
      if (density <= 0) {
        return;
      }
      AppStorage.setOrCreate(SYS_TOP_INSET_KEY, system.topRect.height / density);
      AppStorage.setOrCreate(SYS_BOTTOM_INSET_KEY, indicator.bottomRect.height / density);
    } catch (_) {}
  }
}
