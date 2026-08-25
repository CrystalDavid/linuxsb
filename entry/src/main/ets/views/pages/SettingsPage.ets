import { common } from '@kit.AbilityKit';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  APP_THEME_MODE_STORAGE_KEY,
  AppThemeMode,
  ThemeManager
} from '../../common/theme/ThemeManager';
import {
  HOME_TOPIC_LIST_LAYOUT_STORAGE_KEY,
  HomeTopicListLayout,
  HomeTopicListLayoutMode
} from '../../common/theme/HomeTopicListLayout';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { CompactSegmentedControl, SegmentOption } from '../components/CompactSegmentedControl';
import { ImmersiveIconButton } from '../components/ImmersiveIconButton';

@Component
export struct SettingsPage {
  onBack: () => void = () => {};
  @StorageLink(APP_THEME_MODE_STORAGE_KEY) private themeMode: string = AppThemeMode.System;
  @StorageLink(HOME_TOPIC_LIST_LAYOUT_STORAGE_KEY) private homeTopicListLayout: string =
    HomeTopicListLayoutMode.TitleFirst;

  private themeOptions(): SegmentOption[] {
    return [
      new SegmentOption('跟随系统', 'theme-mode-system'),
      new SegmentOption('浅色', 'theme-mode-light'),
      new SegmentOption('深色', 'theme-mode-dark')
    ];
  }

  private selectedThemeIndex(): number {
    if (this.themeMode === AppThemeMode.Light) {
      return 1;
    }
    if (this.themeMode === AppThemeMode.Dark) {
      return 2;
    }
    return 0;
  }

  private changeTheme(index: number): void {
    const mode = index === 1 ? AppThemeMode.Light : index === 2 ? AppThemeMode.Dark : AppThemeMode.System;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ThemeManager.setMode(context, mode);
  }

  private homeLayoutOptions(): SegmentOption[] {
    return [
      new SegmentOption('标题优先', 'home-layout-title-first'),
      new SegmentOption('作者优先', 'home-layout-author-first')
    ];
  }

  private selectedHomeLayoutIndex(): number {
    return this.homeTopicListLayout === HomeTopicListLayoutMode.AuthorFirst ? 1 : 0;
  }

  private changeHomeLayout(index: number): void {
    HomeTopicListLayout.setMode(index === 1 ?
      HomeTopicListLayoutMode.AuthorFirst : HomeTopicListLayoutMode.TitleFirst);
  }

  @Builder
  private titleBar() {
    Row({ space: Spacing.SM }) {
      ImmersiveIconButton({
        icon: $r('sys.symbol.chevron_backward'),
        semanticId: 'settings-back',
        semanticLabel: '返回',
        buttonSize: 42,
        iconSize: 21,
        onAction: () => this.onBack()
      })
      Text('设置')
        .fontSize(Typography.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .layoutWeight(1)
    }
    .width('100%').height('100%')
    .padding({ left: Spacing.SM, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column({ space: Spacing.MD }) {
          Text('外观')
            .fontSize(Typography.TITLE_SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.textPrimary())
            .width('100%')

          Text('主题模式')
            .fontSize(Typography.LABEL)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textSecondary())
            .width('100%')

          Row() {
            CompactSegmentedControl({
              options: this.themeOptions(),
              selectedIndex: this.selectedThemeIndex(),
              onSelect: (index: number) => this.changeTheme(index)
            })
            Blank()
          }
          .id('settings-theme-picker')
          .width('100%')

          Divider()
            .color(SemanticColors.divider())
            .margin({ top: Spacing.SM, bottom: Spacing.SM })

          Text('首页')
            .fontSize(Typography.TITLE_SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.textPrimary())
            .width('100%')

          Text('帖子展示')
            .fontSize(Typography.LABEL)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textSecondary())
            .width('100%')

          Row() {
            CompactSegmentedControl({
              options: this.homeLayoutOptions(),
              selectedIndex: this.selectedHomeLayoutIndex(),
              segmentWidth: 80,
              controlHeight: 36,
              labelFontSize: Typography.LABEL,
              onSelect: (index: number) => this.changeHomeLayout(index)
            })
            Blank()
          }
          .id('settings-home-layout-picker')
          .width('100%')

        }
        .id('settings-page')
        .width('100%')
        .height('100%')
        .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.LG, bottom: Spacing.XXXL })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%').height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(SemanticColors.page())
    }
    .titleBar({
      avoidLayoutSafeArea: requiresHdsLayoutSafeAreaAvoidance(ImmersiveLightArea.TITLE_BAR),
      enableComponentSafeArea: requiresHdsComponentSafeArea(ImmersiveLightArea.TITLE_BAR),
      style: buildImmersiveTitleBarStyle(),
      content: { stackBuilder: () => { this.titleBar(); } }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .mode(NavigationMode.Stack)
    .hideBackButton(true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%').height('100%')
  }
}
