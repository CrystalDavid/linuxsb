import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { IMMERSIVE_PANEL_BLUR_RADIUS } from '../../common/ui/ImmersiveLightMaterial';
import { SYS_BOTTOM_INSET_KEY } from '../../common/ui/ImmersiveWindow';

export enum CommunityTab {
  Home = 0,
  Forums = 1,
  Search = 2,
  Profile = 3
}

@Component
export struct ImmersiveBottomTabBar {
  @Prop selectedTab: CommunityTab = CommunityTab.Home;
  onSelect: (tab: CommunityTab) => void = () => {};
  onCompose: () => void = () => {};
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;

  private tabColor(tab: CommunityTab): ResourceColor {
    return this.selectedTab === tab ? $r('app.color.brand_primary') : SemanticColors.textSecondary();
  }

  @Builder
  private tabItem(tab: CommunityTab, label: string, icon: Resource) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 2 }) {
        SymbolGlyph(icon)
          .fontSize(23)
          .fontColor([this.tabColor(tab)])
          .fontWeight(this.selectedTab === tab ? FontWeight.Medium : FontWeight.Regular)
        Text(label)
          .fontSize(Typography.LABEL_SMALL)
          .fontWeight(this.selectedTab === tab ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.tabColor(tab))
          .maxLines(1)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .id(`bottom-tab-${label}`)
    .accessibilityText(label)
    .layoutWeight(1)
    .height(56)
    .borderRadius(Radius.LG)
    .backgroundColor(Color.Transparent)
    .onClick(() => this.onSelect(tab))
  }

  @Builder
  private composeButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(31)
        .fontWeight(FontWeight.Medium)
        .fontColor([Color.White])
    }
    .id('bottom-tab-compose')
    .accessibilityText('发表新主题')
    .width(58)
    .height(58)
    .borderRadius(29)
    .linearGradient({
      angle: 135,
      colors: [[$r('app.color.brand_primary_bright'), 0.0], [$r('app.color.brand_primary'), 1.0]]
    })
    .shadow({ radius: 18, color: $r('app.color.bottom_tab_bar_shadow'), offsetY: 5 })
    .margin({ left: Spacing.XS, right: Spacing.XS, bottom: 12 })
    .onClick(() => this.onCompose())
  }

  build() {
    Row({ space: 0 }) {
      this.tabItem(CommunityTab.Home, '首页', $r('sys.symbol.house'))
      this.tabItem(CommunityTab.Forums, '板块', $r('sys.symbol.square_grid_2x2'))
      this.composeButton()
      this.tabItem(CommunityTab.Search, '搜索', $r('sys.symbol.magnifyingglass'))
      this.tabItem(CommunityTab.Profile, '我的', $r('sys.symbol.person'))
    }
    .id('immersive-bottom-tab-bar')
    .width(`calc(100% - ${PageMetrics.BOTTOM_TAB_BAR_MARGIN * 2}vp)`)
    .height(PageMetrics.BOTTOM_TAB_BAR_HEIGHT)
    .padding({ left: Spacing.XS, right: Spacing.XS, top: Spacing.XS, bottom: Spacing.XS })
    .margin({
      left: PageMetrics.BOTTOM_TAB_BAR_MARGIN,
      right: PageMetrics.BOTTOM_TAB_BAR_MARGIN,
      bottom: PageMetrics.BOTTOM_TAB_BAR_MARGIN + this.bottomInset
    })
    .alignItems(VerticalAlign.Center)
    .backdropBlur(IMMERSIVE_PANEL_BLUR_RADIUS)
    .backgroundColor($r('app.color.bottom_tab_bar_bg'))
    .borderRadius(PageMetrics.BOTTOM_TAB_BAR_RADIUS)
    .border({ width: 0.5, color: $r('app.color.bottom_tab_bar_highlight') })
    .shadow({ radius: 22, color: $r('app.color.bottom_tab_bar_shadow'), offsetY: 8 })
  }
}
