import {
  BlurStrategy,
  HdsNavigationTitleBarStyle,
  ScrollEffectOptions,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import {
  emphasizedSystemMaterialEffect,
  HDS_TITLE_BAR_BLUR_RADIUS,
  HDS_TITLE_BAR_MASK_EXTRA_HEIGHT,
  preferredTitleBarScrollEffectType
} from './ImmersiveLightMaterial';

export interface ImmersiveTitleBarStyleConfig {
  enableRefreshOffsetChange?: boolean;
}

export function buildImmersiveTitleBarStyle(
  config: ImmersiveTitleBarStyleConfig = {}
): TitleBarStyleOptions {
  const scrollEffectOpts: ScrollEffectOptions = {
    enableScrollEffect: true,
    scrollEffectType: preferredTitleBarScrollEffectType() as ScrollEffectType
  };
  if (config.enableRefreshOffsetChange !== undefined) {
    scrollEffectOpts.enableRefreshOffsetChange = config.enableRefreshOffsetChange;
  }
  const originalStyle: HdsNavigationTitleBarStyle = {
    backgroundStyle: { backgroundColor: Color.Transparent, blurRadius: 0 }
  };
  const scrollEffectStyle: HdsNavigationTitleBarStyle = {
    backgroundStyle: {
      backgroundColor: $r('app.color.hds_title_bar_scrolled_bg'),
      maskExtraHeight: HDS_TITLE_BAR_MASK_EXTRA_HEIGHT,
      blurRadius: HDS_TITLE_BAR_BLUR_RADIUS
    }
  };
  return {
    scrollEffectOpts: scrollEffectOpts,
    originalStyle: originalStyle,
    scrollEffectStyle: scrollEffectStyle,
    blurStrategy: BlurStrategy.ENABLE,
    systemMaterialEffect: emphasizedSystemMaterialEffect()
  };
}
