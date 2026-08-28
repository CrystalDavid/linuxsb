import { curves } from '@kit.ArkUI';
import { PageMetrics, Radius, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect
} from '../../common/ui/ImmersiveActionBarStyle';

export enum CommunityTab {
  Home = 0,
  Forums = 1,
  Search = 2,
  Profile = 3
}

const BOTTOM_TAB_SYMBOL_FONT_SIZE: number = 27;
const BOTTOM_TAB_ICON_DISPLAY_SCALE: number = 0.92;
const BOTTOM_TAB_ICON_TRANSLATE_Y_OFFSET: number = 0.7;

// The API 24 house Symbols have a detached roof and therefore cannot reproduce
// the supplied Harmony reference. Draw that one silhouette with ArkUI Path and
// keep the other three glyphs as real system Symbols. The inner sub-path winds
// in the opposite direction, leaving a transparent door with a 1.85-unit sill
// instead of the open-bottom doorway in the reference screenshot.
export const HOME_TAB_ICON_PATH: string =
  'M1.18 9.25C0.64 9.82 0.8 10.77 1.52 11.13C1.96 11.35 2.49 11.3 2.88 11L3.02 10.9V19.55' +
  'C3.02 21.42 4.55 22.95 6.42 22.95H17.58C19.45 22.95 20.98 21.42 20.98 19.55V10.9L21.12 11' +
  'C21.51 11.3 22.04 11.35 22.48 11.13C23.2 10.77 23.36 9.82 22.82 9.25L13.62 1.48' +
  'C12.69 0.7 11.31 0.7 10.38 1.48L1.18 9.25Z' +
  'M9.15 21.1V17.2C9.15 15.62 10.42 14.35 12 14.35C13.58 14.35 14.85 15.62 14.85 17.2V21.1H9.15Z';

export function scaleHomeTabIconPath(scale: number): string {
  return HOME_TAB_ICON_PATH.replace(/-?\d+(?:\.\d+)?/g, (token: string): string => {
    return `${Number(token) * scale}`;
  });
}

@Component
export struct ImmersiveBottomTabBar {
  @Prop @Watch('onSelectedTabChanged') selectedTab: CommunityTab = CommunityTab.Home;
  onSelect: (tab: CommunityTab) => void = () => {};
  @State private visualSelectedTab: CommunityTab = CommunityTab.Home;
  @State private indicatorX: number = 5;
  @State private indicatorScaleX: number = 1;
  @State private indicatorScaleY: number = 1;
  private recoveryTimer: number = -1;
  private dragStartIndicatorX: number = 5;
  private lastDragOffsetX: number = 0;
  private smoothedDragVelocity: number = 0;

  private indicatorHeight(): number { return 50; }

  private itemHeight(): number { return 52; }

  private indicatorTop(): number {
    return (PageMetrics.BOTTOM_TAB_BAR_HEIGHT - this.indicatorHeight()) / 2;
  }

  aboutToAppear(): void {
    this.visualSelectedTab = this.selectedTab;
    this.indicatorX = this.indicatorPosition(this.selectedTab);
  }

  aboutToDisappear(): void {
    if (this.recoveryTimer >= 0) {
      clearTimeout(this.recoveryTimer);
      this.recoveryTimer = -1;
    }
  }

  private tabColor(tab: CommunityTab): ResourceColor {
    return this.visualSelectedTab === tab ? $r('app.color.brand_primary') :
      $r('app.color.bottom_tab_foreground');
  }

  private indicatorPosition(tab: CommunityTab): number {
    return 1 + (tab as number) * PageMetrics.BOTTOM_TAB_ITEM_WIDTH +
      (PageMetrics.BOTTOM_TAB_ITEM_WIDTH - PageMetrics.BOTTOM_TAB_INDICATOR_WIDTH) / 2;
  }

  private minimumIndicatorX(): number {
    return 1 + (PageMetrics.BOTTOM_TAB_ITEM_WIDTH - PageMetrics.BOTTOM_TAB_INDICATOR_WIDTH) / 2;
  }

  private maximumIndicatorX(): number {
    return this.minimumIndicatorX() + PageMetrics.BOTTOM_TAB_ITEM_WIDTH * CommunityTab.Profile;
  }

  private clampIndicatorX(value: number): number {
    return Math.max(this.minimumIndicatorX(), Math.min(this.maximumIndicatorX(), value));
  }

  private tabAtIndicatorPosition(position: number): CommunityTab {
    const rawIndex = Math.round((position - this.minimumIndicatorX()) / PageMetrics.BOTTOM_TAB_ITEM_WIDTH);
    return Math.max(CommunityTab.Home, Math.min(CommunityTab.Profile, rawIndex)) as CommunityTab;
  }

  private cancelRecovery(): void {
    if (this.recoveryTimer >= 0) {
      clearTimeout(this.recoveryTimer);
      this.recoveryTimer = -1;
    }
  }

  private onSelectedTabChanged(): void {
    if (this.selectedTab !== this.visualSelectedTab) {
      this.animateSelection(this.selectedTab);
    }
  }

  private selectTab(tab: CommunityTab): void {
    if (tab === this.visualSelectedTab) {
      return;
    }
    this.animateSelection(tab);
    this.onSelect(tab);
  }

  private animateSelection(tab: CommunityTab): void {
    const distance = Math.abs((tab as number) - (this.visualSelectedTab as number));
    this.visualSelectedTab = tab;
    this.getUIContext().animateTo({ duration: 280, curve: Curve.Friction }, () => {
      this.indicatorX = this.indicatorPosition(tab);
      this.indicatorScaleX = Math.min(1.18, 1.08 + distance * 0.025);
      this.indicatorScaleY = 0.94;
    });
    this.cancelRecovery();
    this.recoveryTimer = setTimeout(() => {
      this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 360, 34) }, () => {
        this.indicatorScaleX = 1;
        this.indicatorScaleY = 1;
      });
      this.recoveryTimer = -1;
    }, 118);
  }

  private beginIndicatorDrag(): void {
    this.cancelRecovery();
    this.dragStartIndicatorX = this.indicatorX;
    this.lastDragOffsetX = 0;
    this.smoothedDragVelocity = 0;
  }

  private updateIndicatorDrag(event: GestureEvent): void {
    const frameVelocity = event.offsetX - this.lastDragOffsetX;
    this.lastDragOffsetX = event.offsetX;
    this.smoothedDragVelocity = this.smoothedDragVelocity * 0.7 + frameVelocity * 0.3;
    this.indicatorX = this.clampIndicatorX(this.dragStartIndicatorX + event.offsetX);
    const deformation = Math.min(0.2, Math.sqrt(Math.abs(this.smoothedDragVelocity) / 12) * 0.1);
    this.indicatorScaleX = 1 + deformation;
    this.indicatorScaleY = 1 - deformation * 0.35;
    this.visualSelectedTab = this.tabAtIndicatorPosition(this.indicatorX);
  }

  private finishIndicatorDrag(velocityX: number): void {
    const projection = Math.max(-PageMetrics.BOTTOM_TAB_ITEM_WIDTH * 0.45,
      Math.min(PageMetrics.BOTTOM_TAB_ITEM_WIDTH * 0.45, velocityX / 80));
    const target = this.tabAtIndicatorPosition(this.clampIndicatorX(this.indicatorX + projection));
    const shouldSwitch = target !== this.selectedTab;
    this.animateSelection(target);
    if (shouldSwitch) {
      this.onSelect(target);
    }
  }

  private nativeSymbolResource(tab: CommunityTab): Resource {
    if (tab === CommunityTab.Forums) {
      return $r('sys.symbol.folder_fill');
    }
    if (tab === CommunityTab.Search) {
      return $r('sys.symbol.doc_text_magnifyingglass_fill');
    }
    return $r('sys.symbol.person_fill');
  }

  private iconSemanticName(tab: CommunityTab): string {
    if (tab === CommunityTab.Home) {
      return '首页';
    }
    if (tab === CommunityTab.Forums) {
      return '板块';
    }
    if (tab === CommunityTab.Search) {
      return '搜索';
    }
    return '我的';
  }

  private nativeScaleX(tab: CommunityTab): number {
    if (tab === CommunityTab.Forums) {
      return 0.90;
    }
    if (tab === CommunityTab.Search) {
      return 1.01;
    }
    return 1.10;
  }

  private nativeScaleY(tab: CommunityTab): number {
    if (tab === CommunityTab.Forums) {
      return 1.12;
    }
    if (tab === CommunityTab.Search) {
      return 0.875;
    }
    return 0.955;
  }

  private nativeFontWeight(tab: CommunityTab): number {
    if (tab === CommunityTab.Forums) {
      return 340;
    }
    if (tab === CommunityTab.Search) {
      return 460;
    }
    return 320;
  }

  private nativeTranslateX(tab: CommunityTab): number {
    return tab === CommunityTab.Search ? -1.5 : -0.5;
  }

  private nativeTranslateY(tab: CommunityTab): number {
    return tab === CommunityTab.Profile ? -1.4 : -1.5;
  }

  @Builder
  private tabIcon(tab: CommunityTab) {
    if (tab === CommunityTab.Home) {
      Path({
        width: 24,
        height: 24,
        commands: scaleHomeTabIconPath(this.getUIContext().vp2px(1))
      })
        .id(`bottom-tab-native-icon-${this.iconSemanticName(tab)}`)
        .fill(this.tabColor(tab))
        .stroke(Color.Transparent)
        .strokeWidth(0)
        .scale({ x: BOTTOM_TAB_ICON_DISPLAY_SCALE, y: BOTTOM_TAB_ICON_DISPLAY_SCALE })
        .translate({ y: BOTTOM_TAB_ICON_TRANSLATE_Y_OFFSET })
    } else {
      SymbolGlyph(this.nativeSymbolResource(tab))
        .id(`bottom-tab-native-icon-${this.iconSemanticName(tab)}`)
        .fontSize(BOTTOM_TAB_SYMBOL_FONT_SIZE)
        .fontWeight(this.nativeFontWeight(tab))
        .fontColor([this.tabColor(tab)])
        .width(26)
        .height(24)
        .scale({
          x: this.nativeScaleX(tab) * BOTTOM_TAB_ICON_DISPLAY_SCALE,
          y: this.nativeScaleY(tab) * BOTTOM_TAB_ICON_DISPLAY_SCALE
        })
        .translate({
          x: this.nativeTranslateX(tab),
          y: this.nativeTranslateY(tab) + BOTTOM_TAB_ICON_TRANSLATE_Y_OFFSET
        })
    }
  }

  @Builder
  private tabItem(tab: CommunityTab, label: string) {
    // The moving indicator is the only selected/pressed surface. ArkUI's default
    // Button state layer leaves a dark frame behind while the glass indicator is
    // being dragged, which looks like a second button.
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Column({ space: 0 }) {
        Stack() {
          this.tabIcon(tab)
        }
        .id(`bottom-tab-icon-${label}`)
        .width(28)
        .height(26)
        .alignContent(Alignment.Center)

        Text(label)
          .id(`bottom-tab-label-${label}`)
          .fontSize(Typography.LABEL_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tabColor(tab))
          .width('100%')
          .height(16)
          .lineHeight(16)
          .textAlign(TextAlign.Center)
          .maxLines(1)
      }
      .width('100%')
      .height(42)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .id(`bottom-tab-${label}`)
    .accessibilityText(label)
    .width(PageMetrics.BOTTOM_TAB_ITEM_WIDTH)
    .height(this.itemHeight())
    .borderRadius(this.itemHeight() / 2)
    .backgroundColor(Color.Transparent)
    .hoverEffect(HoverEffect.None)
    .onClick(() => this.selectTab(tab))
  }

  @Builder
  private selectionIndicator() {
    Row()
      .id('bottom-tab-selection-indicator')
      .width(PageMetrics.BOTTOM_TAB_INDICATOR_WIDTH)
      .height(this.indicatorHeight())
      .position({ x: 0, y: this.indicatorTop() })
      .translate({ x: this.indicatorX })
      .scale({ x: this.indicatorScaleX, y: this.indicatorScaleY })
      .backgroundColor($r('app.color.bottom_tab_selected_bg'))
      .border({ width: 0.9, color: $r('app.color.bottom_tab_bar_highlight') })
      .borderRadius(Radius.PILL)
      .shadow({ radius: 7, color: $r('app.color.bottom_tab_selected_glow'), offsetY: 1 })
      .opacity(1)
  }

  build() {
    Stack() {
      this.selectionIndicator()
      Row({ space: 0 }) {
        this.tabItem(CommunityTab.Home, '首页')
        this.tabItem(CommunityTab.Forums, '板块')
        this.tabItem(CommunityTab.Search, '搜索')
        this.tabItem(CommunityTab.Profile, '我的')
      }
      .width('100%')
      .height(PageMetrics.BOTTOM_TAB_BAR_HEIGHT)
    }
    .id('immersive-bottom-tab-bar')
    .accessibilityText('鸿蒙高亮玻璃底部导航')
    .width(PageMetrics.BOTTOM_TAB_BAR_WIDTH)
    .height(PageMetrics.BOTTOM_TAB_BAR_HEIGHT)
    .clip(false)
    .backgroundColor(Color.Transparent)
    // One sampling layer, one moving capsule, and a bright edge with a single
    // neutral shadow. The bar is the hero glass surface: a deeper 24vp frost with
    // a brightness lift melts scrolling content into the soft luminous field the
    // reference floating bars show, while small controls keep the shared 6vp glass.
    .backgroundEffect(buildImmersiveGlassEffect(24, 1.15, $r('app.color.bottom_tab_bar_frost'), 1.35))
    .borderWidth(1.25)
    .borderColor($r('app.color.bottom_tab_bar_highlight'))
    .borderRadius(Radius.PILL)
    .shadow({ radius: 16, color: $r('app.color.bottom_tab_bar_shadow'), offsetY: 4 })
    .priorityGesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 6 })
        .onActionStart(() => this.beginIndicatorDrag())
        .onActionUpdate((event: GestureEvent) => this.updateIndicatorDrag(event))
        .onActionEnd((event: GestureEvent) => this.finishIndicatorDrag(event.velocityX))
        .onActionCancel(() => this.finishIndicatorDrag(0))
    )
  }
}
