import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { m1Runtime } from '../app/M1Runtime';
import { ThemeManager } from '../common/theme/ThemeManager';
import { HomeTopicListLayout } from '../common/theme/HomeTopicListLayout';
import { TopicListStylePrefs } from '../common/theme/TopicListStylePrefs';
import { ImmersiveWindow } from '../common/ui/ImmersiveWindow';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    ThemeManager.init(this.context);
    HomeTopicListLayout.init();
    TopicListStylePrefs.seedDefaults();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    m1Runtime.close();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    try {
      ImmersiveWindow.init(windowStage.getMainWindowSync());
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Immersive init failed. Cause: %{public}s', JSON.stringify(err));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    ThemeManager.applyConfiguration(this.context.config);
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    ThemeManager.applyConfiguration(newConfig);
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
