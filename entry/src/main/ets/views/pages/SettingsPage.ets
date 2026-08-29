import { common } from '@kit.AbilityKit';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  APP_IS_DARK_STORAGE_KEY,
  AppThemeMode,
  ThemeManager
} from '../../common/theme/ThemeManager';
import {
  HomeTopicListLayout,
  HomeTopicListLayoutMode
} from '../../common/theme/HomeTopicListLayout';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import {
  ImmersiveIconButton,
  TITLE_BAR_BACK_ICON_SIZE,
  TITLE_BAR_BACK_ICON_WEIGHT
} from '../components/ImmersiveIconButton';
import {
  DEVELOPER_SUPPORT_PRODUCTS,
  DeveloperSupportProduct,
  developerSupportService
} from '../../services/payment/DeveloperSupportService';

enum SettingsSection {
  Overview = 0,
  Theme = 1,
  HomeLayout = 2
}

const SETTINGS_GROUP_RADIUS: number = 18;
const SETTINGS_ROW_HEIGHT: number = 56;
const THEME_PREVIEW_HEIGHT: number = 250;
const LAYOUT_PREVIEW_HEIGHT: number = 118;

@CustomDialog
struct DeveloperSupportDialog {
  controller?: CustomDialogController;
  onPurchase: (product: DeveloperSupportProduct) => void = () => {};

  @Builder
  private supportProductRow(product: DeveloperSupportProduct, index: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: Spacing.MD }) {
        SymbolGlyph($r('sys.symbol.gift'))
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor([SemanticColors.textPrimary()])
        Text(product.label)
          .fontSize(Typography.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(1)
        Blank()
        Text(product.priceLabel)
          .width(112)
          .height(38)
          .fontSize(Typography.BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.support_price_text'))
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.support_price_bg'))
          .borderRadius(Radius.PILL)
      }
      .width('100%')
      .height('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG })
      .alignItems(VerticalAlign.Center)
    }
    .id(`developer-support-product-${index}`)
    .accessibilityText(`${product.label}，${product.priceLabel}，一次性支付`)
    .width('100%')
    .height(56)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .borderRadius(Radius.MD)
    .onClick(() => {
      this.controller?.close();
      this.onPurchase(product);
    })
  }

  build() {
    Column({ space: Spacing.MD }) {
      Row() {
        Column({ space: Spacing.XS }) {
          Text('投喂开发者')
            .fontSize(Typography.PAGE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.textPrimary())
          Text('感谢支持这个非官方客户端，以下均为一次性支付，不会自动续费')
            .fontSize(Typography.CAPTION)
            .fontColor(SemanticColors.textSecondary())
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor([SemanticColors.textPrimary()])
        }
        .id('developer-support-close')
        .accessibilityText('关闭投喂弹窗')
        .width(40)
        .height(40)
        .padding(0)
        .backgroundColor(SemanticColors.surfaceMuted())
        .onClick(() => this.controller?.close())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Column() {
        ForEach(DEVELOPER_SUPPORT_PRODUCTS, (product: DeveloperSupportProduct, index: number) => {
          this.supportProductRow(product, index)
          if (index + 1 < DEVELOPER_SUPPORT_PRODUCTS.length) {
            Divider()
              .strokeWidth(0.5)
              .color(SemanticColors.outline())
              .margin({ left: 52, right: Spacing.LG })
          }
        }, (product: DeveloperSupportProduct) => product.productId)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XL, bottom: Spacing.XXL })
    .backgroundColor($r('app.color.settings_overview_card_bg'))
    .borderRadius({ topLeft: 28, topRight: 28 })
  }
}

@Component
struct SettingsSelectionMark {
  @Prop selected: boolean = false;
  semanticId: string = 'settings-selection';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.selected) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .id(`${this.semanticId}-checkmark`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor([Color.White])
      }
    }
    .id(this.semanticId)
    .width(24)
    .height(24)
    .borderRadius(Radius.PILL)
    .border({
      width: this.selected ? 0 : 1.5,
      color: this.selected ? Color.Transparent : SemanticColors.outline()
    })
    .backgroundColor(this.selected ? $r('app.color.brand_primary') : Color.Transparent)
  }
}

@Component
export struct SettingsPage {
  onBack: () => void = () => {};
  onFeedback: () => void = () => {};
  @State private selectedThemeMode: AppThemeMode = AppThemeMode.System;
  @State private selectedHomeTopicListLayout: HomeTopicListLayoutMode =
    HomeTopicListLayoutMode.TitleFirst;
  @State private section: SettingsSection = SettingsSection.Overview;
  @StorageProp(APP_IS_DARK_STORAGE_KEY) private effectiveIsDark: boolean = false;
  private supportDialogController: CustomDialogController | undefined = undefined;

  aboutToAppear(): void {
    this.selectedThemeMode = ThemeManager.currentMode();
    this.selectedHomeTopicListLayout = HomeTopicListLayout.currentMode();
  }

  private pageTitle(): string {
    if (this.section === SettingsSection.Theme) {
      return '外观主题';
    }
    if (this.section === SettingsSection.HomeLayout) {
      return '首页帖子样式';
    }
    return '设置';
  }

  private handleBack(): void {
    if (this.section === SettingsSection.Overview) {
      this.onBack();
      return;
    }
    this.section = SettingsSection.Overview;
  }

  private themeModeLabel(): string {
    if (this.selectedThemeMode === AppThemeMode.Light) {
      return '浅色';
    }
    if (this.selectedThemeMode === AppThemeMode.Dark) {
      return '深色';
    }
    return '跟随系统';
  }

  private homeLayoutLabel(): string {
    return this.selectedHomeTopicListLayout === HomeTopicListLayoutMode.AuthorFirst ? '作者优先' : '标题优先';
  }

  private changeTheme(mode: AppThemeMode): void {
    // Update the linked field first so the selected card and checkmark repaint in
    // the same frame as the tap. ThemeManager then applies and persists the mode.
    this.selectedThemeMode = mode;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ThemeManager.setMode(context, mode);
  }

  private changeFollowSystem(enabled: boolean): void {
    if (enabled) {
      this.changeTheme(AppThemeMode.System);
      return;
    }
    this.changeTheme(this.effectiveIsDark ? AppThemeMode.Dark : AppThemeMode.Light);
  }

  private changeHomeLayout(mode: HomeTopicListLayoutMode): void {
    // Keep the detail-page selection state reactive as well as persisted.
    this.selectedHomeTopicListLayout = mode;
    HomeTopicListLayout.setMode(mode);
  }

  private openDeveloperSupport(): void {
    this.supportDialogController = new CustomDialogController({
      builder: DeveloperSupportDialog({
        onPurchase: (product: DeveloperSupportProduct) => this.purchaseDeveloperSupport(product)
      }),
      autoCancel: true,
      customStyle: true,
      alignment: DialogAlignment.Bottom
    });
    this.supportDialogController.open();
  }

  private async purchaseDeveloperSupport(product: DeveloperSupportProduct): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await developerSupportService.purchase(context, product);
    try {
      this.getUIContext().getPromptAction().showToast({ message: result.message, duration: 2200 });
    } catch (_) {}
  }

  @Builder
  private titleBar() {
    Row({ space: Spacing.SM }) {
      ImmersiveIconButton({
        icon: $r('sys.symbol.chevron_left'),
        semanticId: 'settings-back',
        semanticLabel: this.section === SettingsSection.Overview ? '返回个人页' : '返回设置',
        iconSize: TITLE_BAR_BACK_ICON_SIZE,
        iconWeight: TITLE_BAR_BACK_ICON_WEIGHT,
        onAction: () => this.handleBack()
      })
      Text(this.pageTitle())
        .id('settings-page-title')
        .fontSize(Typography.PAGE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .maxLines(1)
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 10, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private settingRow(title: string, value: string, semanticId: string, target: SettingsSection) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: Spacing.SM }) {
        Text(title)
          .fontSize(Typography.TOPIC_TITLE)
          .fontWeight(500)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(1)
        Blank()
        Text(value)
          .fontSize(Typography.LIST_TITLE)
          .fontColor(SemanticColors.textSecondary())
          .maxLines(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor([SemanticColors.textTertiary()])
      }
      .width('100%')
      .height('100%')
      .padding({ left: Spacing.LG, right: Spacing.MD })
      .alignItems(VerticalAlign.Center)
    }
    .id(semanticId)
    .accessibilityText(`${title}，当前${value}`)
    .width('100%')
    .height(SETTINGS_ROW_HEIGHT)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .borderRadius(0)
    .onClick(() => this.section = target)
  }

  @Builder
  private actionSettingRow(title: string, value: string, semanticId: string, onAction: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: Spacing.SM }) {
        Text(title)
          .fontSize(Typography.TOPIC_TITLE)
          .fontWeight(500)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(1)
        Blank()
        Text(value)
          .fontSize(Typography.LIST_TITLE)
          .fontColor(SemanticColors.textSecondary())
          .maxLines(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor([SemanticColors.textTertiary()])
      }
      .width('100%')
      .height('100%')
      .padding({ left: Spacing.LG, right: Spacing.MD })
      .alignItems(VerticalAlign.Center)
    }
    .id(semanticId)
    .accessibilityText(`${title}，${value}`)
    .width('100%')
    .height(SETTINGS_ROW_HEIGHT)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .borderRadius(0)
    .onClick(onAction)
  }

  @Builder
  private themeMiniPanel(dark: boolean) {
    Column({ space: 7 }) {
      Row()
        .width('52%')
        .height(10)
        .borderRadius(Radius.PILL)
        .backgroundColor(dark ? '#FFEAF0F5' : '#FF24313D')
      Row()
        .width('100%')
        .height(27)
        .borderRadius(Radius.SM)
        .backgroundColor(dark ? '#FF353D46' : '#FFFFFFFF')
      Row()
        .width('100%')
        .height(27)
        .borderRadius(Radius.SM)
        .backgroundColor(dark ? '#FF353D46' : '#FFFFFFFF')
      Row()
        .width('100%')
        .height(27)
        .borderRadius(Radius.SM)
        .backgroundColor(dark ? '#FF263A59' : '#FFE8F1FF')
      Row()
        .width('100%')
        .height(27)
        .borderRadius(Radius.SM)
        .backgroundColor(dark ? '#FF353D46' : '#FFFFFFFF')
      Row()
        .width('100%')
        .height(27)
        .borderRadius(Radius.SM)
        .backgroundColor(dark ? '#FF2C333B' : '#FFF7F8FA')
      Blank()
      Row({ space: 7 }) {
        Row().width(17).height(17).borderRadius(Radius.PILL)
          .backgroundColor(dark ? '#FF78A8FF' : '#FF0A59F7')
        Row().width(17).height(17).borderRadius(Radius.PILL)
          .backgroundColor(dark ? '#FFFF8D86' : '#FFD92D20')
        Row().width(17).height(17).borderRadius(Radius.PILL)
          .backgroundColor(dark ? '#FF61D8C9' : '#FF078A83')
        Row().width(17).height(17).borderRadius(Radius.PILL)
          .backgroundColor(dark ? '#FF506B8D' : '#FFB9D8FF')
      }
      .id(dark ? 'theme-preview-dark-color-row' : 'theme-preview-light-color-row')
      .justifyContent(FlexAlign.Center)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 18, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(dark ? '#FF171C22' : '#FFF1F4F7')
  }

  @Builder
  private themePreview(mode: AppThemeMode) {
    Stack({ alignContent: Alignment.Center }) {
      this.themeMiniPanel(mode === AppThemeMode.Dark)
    }
    .id(mode === AppThemeMode.Dark ? 'theme-preview-dark' : 'theme-preview-light')
    .width('100%')
    .height(THEME_PREVIEW_HEIGHT)
    .borderRadius(Radius.LG)
    .clip(true)
    .border({ width: 1, color: SemanticColors.outline() })
  }

  @Builder
  private themeChoice(mode: AppThemeMode, label: string, semanticId: string) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: Spacing.SM }) {
        this.themePreview(mode)
        Text(label)
          .fontSize(Typography.TOPIC_TITLE)
          .fontWeight(this.selectedThemeMode === mode ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(1)
        SettingsSelectionMark({
          selected: this.selectedThemeMode === mode,
          semanticId: `${semanticId}-selected`
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .id(semanticId)
    .accessibilityText(`${label}主题`)
    .layoutWeight(1)
    .height(338)
    .padding({ left: Spacing.XS, right: Spacing.XS, top: Spacing.SM, bottom: Spacing.SM })
    .backgroundColor(Color.Transparent)
    .border({ width: 0, color: Color.Transparent })
    .borderRadius(Radius.LG)
    .onClick(() => this.changeTheme(mode))
  }

  @Builder
  private previewBadge(label: string) {
    Text(label)
      .fontSize(Typography.MICRO)
      .fontColor($r('app.color.brand_primary'))
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .backgroundColor($r('app.color.brand_soft'))
      .borderRadius(Radius.XS)
  }

  @Builder
  private layoutPreview(authorFirst: boolean) {
    Column() {
      if (authorFirst) {
        Column({ space: 7 }) {
          Row({ space: Spacing.SM }) {
            Row()
              .width(26)
              .height(26)
              .borderRadius(Radius.PILL)
              .backgroundColor($r('app.color.avatar_background'))
            Column({ space: 2 }) {
              Text('示例作者')
                .fontSize(Typography.METADATA)
                .fontWeight(FontWeight.Medium)
                .fontColor(SemanticColors.textPrimary())
              Text('3 分钟前 · 12 回复')
                .fontSize(Typography.MICRO)
                .fontColor(SemanticColors.textSecondary())
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          Text('示例主题标题：看看帖子如何排列')
            .fontSize(Typography.BODY_SMALL)
            .fontWeight(500)
            .fontColor(SemanticColors.textPrimary())
            .maxLines(1)
          Row({ space: Spacing.XS }) {
            this.previewBadge('错误地方')
            this.previewBadge('热')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else {
        Row({ space: Spacing.MD }) {
          Row()
            .width(38)
            .height(38)
            .borderRadius(Radius.PILL)
            .backgroundColor($r('app.color.avatar_background'))
          Column({ space: 7 }) {
            Text('示例主题标题：看看帖子如何排列')
              .fontSize(Typography.BODY_SMALL)
              .fontWeight(500)
              .fontColor(SemanticColors.textPrimary())
              .maxLines(1)
            Row({ space: Spacing.XS }) {
              this.previewBadge('错误地方')
              this.previewBadge('热')
            }
            Text('示例作者 · 12 回复 · 3 分钟前')
              .fontSize(Typography.MICRO)
              .fontColor(SemanticColors.textSecondary())
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .height(LAYOUT_PREVIEW_HEIGHT)
    .padding(Spacing.MD)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.settings_preview_bg'))
    .borderRadius(Radius.LG)
  }

  @Builder
  private layoutChoice(mode: HomeTopicListLayoutMode, label: string, detail: string, semanticId: string) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: Spacing.MD }) {
        this.layoutPreview(mode === HomeTopicListLayoutMode.AuthorFirst)
        Row({ space: Spacing.MD }) {
          Column({ space: 3 }) {
            Text(label)
              .fontSize(Typography.TOPIC_TITLE)
              .fontWeight(this.selectedHomeTopicListLayout === mode ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(SemanticColors.textPrimary())
            Text(detail)
              .fontSize(Typography.CAPTION)
              .fontColor(SemanticColors.textSecondary())
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          SettingsSelectionMark({
            selected: this.selectedHomeTopicListLayout === mode,
            semanticId: `${semanticId}-selected`
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
    }
    .id(semanticId)
    .accessibilityText(`${label}，${detail}`)
    .width('100%')
    .padding(Spacing.MD)
    .backgroundColor(this.selectedHomeTopicListLayout === mode ? $r('app.color.brand_soft') : Color.Transparent)
    .border({
      width: this.selectedHomeTopicListLayout === mode ? 1.5 : 1,
      color: this.selectedHomeTopicListLayout === mode ? $r('app.color.brand_primary') : SemanticColors.outline()
    })
    .borderRadius(Radius.LG)
    .onClick(() => this.changeHomeLayout(mode))
  }

  @Builder
  private overviewPage() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        Column() {
          this.settingRow('外观主题', this.themeModeLabel(), 'settings-theme-row', SettingsSection.Theme)
          Divider()
            .strokeWidth(0.5)
            .color(SemanticColors.outline())
            .margin({ left: Spacing.LG, right: Spacing.LG })
          this.settingRow('首页帖子样式', this.homeLayoutLabel(), 'settings-home-layout-row',
            SettingsSection.HomeLayout)
        }
        .width('100%')
        .backgroundColor($r('app.color.settings_overview_card_bg'))
        .borderRadius(SETTINGS_GROUP_RADIUS)
        .clip(true)
        Column() {
          this.actionSettingRow('投喂开发者', '支持维护', 'settings-developer-support-row',
            () => this.openDeveloperSupport())
          Divider()
            .strokeWidth(0.5)
            .color(SemanticColors.outline())
            .margin({ left: Spacing.LG, right: Spacing.LG })
          this.actionSettingRow('反馈', '查看社区帖子', 'settings-feedback-row', () => this.onFeedback())
        }
        .width('100%')
        .backgroundColor($r('app.color.settings_overview_card_bg'))
        .borderRadius(SETTINGS_GROUP_RADIUS)
        .clip(true)
      }
      .id('settings-page')
      .width('100%')
      .height('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XXL, bottom: Spacing.XXXL })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private themeDetailPage() {
    Scroll() {
      Column({ space: Spacing.MD }) {
        Text('显示模式')
          .fontSize(Typography.BODY_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.textSecondary())
          .width('100%')
        Column() {
          Row({ space: Spacing.SM }) {
            this.themeChoice(AppThemeMode.Light, '浅色', 'theme-mode-light')
            this.themeChoice(AppThemeMode.Dark, '深色', 'theme-mode-dark')
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          Divider()
            .color(SemanticColors.divider())
            .margin({ left: Spacing.MD, right: Spacing.MD })
          Row() {
            Text('跟随系统')
              .fontSize(Typography.TOPIC_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(SemanticColors.textPrimary())
            Blank()
            Toggle({
              type: ToggleType.Switch,
              isOn: this.selectedThemeMode === AppThemeMode.System
            })
              .id('theme-follow-system-switch')
              .accessibilityText('跟随系统')
              .selectedColor($r('app.color.brand_primary'))
              .onChange((isOn: boolean) => this.changeFollowSystem(isOn))
          }
          .width('100%')
          .height(60)
          .padding({ left: Spacing.LG, right: Spacing.LG })
          .alignItems(VerticalAlign.Center)
        }
        .id('settings-theme-picker')
        .width('100%')
        .padding(Spacing.SM)
        .backgroundColor($r('app.color.settings_group_bg'))
        .borderRadius(SETTINGS_GROUP_RADIUS)
      }
      .id('settings-theme-detail')
      .width('100%')
      .height('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XXL, bottom: Spacing.XXXL })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private homeLayoutDetailPage() {
    Scroll() {
      Column({ space: Spacing.MD }) {
        Text('帖子展示方式')
          .fontSize(Typography.BODY_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.textSecondary())
          .width('100%')
        Column({ space: Spacing.SM }) {
          this.layoutChoice(HomeTopicListLayoutMode.TitleFirst, '标题优先', '先看标题、标签，再看作者信息',
            'home-layout-title-first')
          this.layoutChoice(HomeTopicListLayoutMode.AuthorFirst, '作者优先', '先看作者与时间，再看帖子标题',
            'home-layout-author-first')
        }
        .id('settings-home-layout-picker')
        .width('100%')
        .padding(Spacing.SM)
        .backgroundColor($r('app.color.settings_group_bg'))
        .borderRadius(SETTINGS_GROUP_RADIUS)
      }
      .id('settings-home-layout-detail')
      .width('100%')
      .height('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XXL, bottom: Spacing.XXXL })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  build() {
    HdsNavigation() {
      Stack() {
        if (this.section === SettingsSection.Theme) {
          this.themeDetailPage()
        } else if (this.section === SettingsSection.HomeLayout) {
          this.homeLayoutDetailPage()
        } else {
          this.overviewPage()
        }
      }
      .width('100%')
      .height('100%')
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
    .width('100%')
    .height('100%')
  }
}
