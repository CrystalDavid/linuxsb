import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect,
  buildImmersiveSystemMaterialModifier,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';
import { GLASS_STYLE_STORAGE_KEY, GlassStyleMode } from '../../common/ui/GlassStyleParams';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { FeedSearchField, HomeFeedRequest } from '../../models/HomeModels';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { ViewLoadState } from '../../viewmodels/ViewState';
import { AccountLoginGate } from '../components/AccountLoginGate';
import {
  GLASS_ACTION_ARROW_ICON_WEIGHT,
  ImmersiveIconButton,
  TITLE_BAR_BACK_ICON_SIZE,
  TITLE_BAR_BACK_ICON_WEIGHT
} from '../components/ImmersiveIconButton';
import { PaginatedTopicList } from '../components/PaginatedTopicList';

const SEARCH_PRIMARY_CONTROL_HEIGHT: number = 42;
const SEARCH_SEND_ICON_SIZE: number = 20;
const SEARCH_EMPTY_HINT_LIFT: number = 100;
const SEARCH_FIELD_MENU_HEIGHT: number = 134;

@Component({ freezeWhenInactive: true })
export struct SearchPage {
  @ObjectLink viewModel: HomeViewModel;
  @Prop authenticated: boolean = false;
  bottomContentInset: number = PageMetrics.BOTTOM_TAB_BAR_CONTENT_INSET;
  onBack: () => void = () => {};
  onLogin: () => void = () => {};
  onTopicSelected: (topic: TopicUiModel) => void = () => {};
  @State private query: string = '';
  @State private field: FeedSearchField = FeedSearchField.Title;
  @State private hasSearched: boolean = false;
  @State private showFieldMenu: boolean = false;
  @StorageProp(GLASS_STYLE_STORAGE_KEY) private glassStyle: GlassStyleMode = GlassStyleMode.Translucent;

  private async search(): Promise<void> {
    const normalized = this.query.trim();
    if (!this.authenticated) {
      this.onLogin();
      return;
    }
    if (normalized.length < 2) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '请至少输入 2 个字符', duration: 1600 });
      } catch (_) {}
      return;
    }
    this.showFieldMenu = false;
    this.hasSearched = true;
    this.viewModel.configure(HomeFeedRequest.search(normalized, this.field));
    await this.viewModel.load(false);
  }

  @Builder
  private titleBar() {
    Row({ space: Spacing.SM }) {
      ImmersiveIconButton({
        icon: $r('sys.symbol.chevron_left'),
        semanticId: 'search-back',
        semanticLabel: '返回',
        iconSize: TITLE_BAR_BACK_ICON_SIZE,
        iconWeight: TITLE_BAR_BACK_ICON_WEIGHT,
        onAction: () => this.onBack()
      })
      Text('搜索')
        .id('search-page-title')
        .fontSize(Typography.PAGE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
    }
    .width('100%').height('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  private fieldLabel(): string {
    if (this.field === FeedSearchField.Body) {
      return '正文';
    }
    return this.field === FeedSearchField.Reply ? '回帖' : '标题';
  }

  private chooseField(): void {
    this.showFieldMenu = !this.showFieldMenu;
  }

  @Builder
  private fieldMenuItem(label: string, field: FeedSearchField, semanticId: string) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Row() {
        Text(label)
          .fontSize(Typography.BODY)
          .fontColor(SemanticColors.textPrimary())
          .fontWeight(this.field === field ? FontWeight.Medium : FontWeight.Regular)
        Blank()
        if (this.field === field) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(15)
            .fontColor([SemanticColors.textPrimary()])
        }
      }
      .width('100%')
    }
    .id(semanticId)
    .width(132)
    .height(42)
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .backgroundColor(Color.Transparent)
    .borderRadius(Radius.MD)
    .hoverEffect(HoverEffect.None)
    .onClick(() => {
      this.field = field;
      this.showFieldMenu = false;
    })
  }

  @Builder
  private fieldMenu() {
    Column() {
      this.fieldMenuItem('标题', FeedSearchField.Title, 'search-field-title')
      this.fieldMenuItem('正文', FeedSearchField.Body, 'search-field-body')
      this.fieldMenuItem('回帖', FeedSearchField.Reply, 'search-field-reply')
    }
    .id('search-field-menu')
    .width(148)
    .height(SEARCH_FIELD_MENU_HEIGHT)
    .padding(Spacing.XS)
    .backgroundEffect(buildImmersiveGlassEffect(this.glassStyle))
    .border({ width: IMMERSIVE_GLASS_BORDER_WIDTH, color: $r('app.color.bottom_tab_bar_highlight') })
    .borderRadius(Radius.LG)
    .shadow({
      radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
      color: $r('app.color.bottom_tab_bar_shadow'),
      offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
    })
    .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
    .clip(true)
    .translate({ x: Spacing.MD, y: SEARCH_PRIMARY_CONTROL_HEIGHT + Spacing.XS })
    .zIndex(10)
  }

  @Builder
  private searchControls() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
      Row({ space: Spacing.SM }) {
        Row({ space: Spacing.XS }) {
          Button({ type: ButtonType.Capsule, stateEffect: false }) {
            Row({ space: Spacing.XXS }) {
              Text(this.fieldLabel())
                .fontSize(Typography.BODY_SMALL)
                .fontWeight(FontWeight.Medium)
                .fontColor(SemanticColors.textPrimary())
              SymbolGlyph($r('sys.symbol.chevron_down'))
                .fontSize(13)
                .fontColor([SemanticColors.textPrimary()])
            }
          }
          .id('search-field-picker')
          .accessibilityText(`搜索范围：${this.fieldLabel()}`)
          .height(32)
          .padding({ left: Spacing.SM, right: Spacing.SM })
          .backgroundColor($r('app.color.bottom_tab_selected_bg'))
          .borderRadius(Radius.PILL)
          .hoverEffect(HoverEffect.None)
          .onClick(() => this.chooseField())
          TextInput({ text: this.query, placeholder: '搜索社区帖子' })
            .id('search-input')
            .layoutWeight(1)
            .height(SEARCH_PRIMARY_CONTROL_HEIGHT - 2)
            .fontSize(Typography.BODY)
            .fontColor(SemanticColors.textPrimary())
            .placeholderColor(SemanticColors.textSecondary())
            .caretColor(SemanticColors.textPrimary())
            .padding({ left: 0, right: 0 })
            .backgroundColor(Color.Transparent)
            .enterKeyType(EnterKeyType.Search)
            .onChange((value: string) => { this.query = value; })
            .onSubmit(() => this.search())
        }
        .layoutWeight(1)
        .id('search-input-surface')
        .height(SEARCH_PRIMARY_CONTROL_HEIGHT)
        .padding({ left: Spacing.MD, right: Spacing.SM })
        .backgroundEffect(buildImmersiveGlassEffect(this.glassStyle))
        .border({ width: IMMERSIVE_GLASS_BORDER_WIDTH, color: $r('app.color.bottom_tab_bar_highlight') })
        .borderRadius(Radius.PILL)
        .shadow({
          radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
          color: $r('app.color.bottom_tab_bar_shadow'),
          offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
        })
        .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))

        ImmersiveIconButton({
          icon: $r('sys.symbol.arrow_up'),
          semanticId: 'search-submit',
          semanticLabel: '搜索',
          buttonSize: SEARCH_PRIMARY_CONTROL_HEIGHT,
          iconSize: SEARCH_SEND_ICON_SIZE,
          iconWeight: GLASS_ACTION_ARROW_ICON_WEIGHT,
          iconRotation: 90,
          iconColor: SemanticColors.textPrimary(),
          onAction: () => this.search()
        })
      }
      .width('100%')
      if (this.showFieldMenu) {
        this.fieldMenu()
      }
      }
      .width('100%')
      .height(this.showFieldMenu ? SEARCH_PRIMARY_CONTROL_HEIGHT + Spacing.XS + SEARCH_FIELD_MENU_HEIGHT :
        SEARCH_PRIMARY_CONTROL_HEIGHT)
      .clip(false)
    }
    .width('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD, top: 0, bottom: Spacing.MD })
    .backgroundColor(Color.Transparent)
  }

  build() {
    HdsNavigation() {
      Column() {
        if (!this.authenticated) {
          Column() {
            AccountLoginGate({
              title: '登录后搜索',
              semanticPrefix: 'search',
              onLogin: () => this.onLogin()
            })
            Blank()
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XXL,
            bottom: this.bottomContentInset })
        } else {
          this.searchControls()
          if (!this.hasSearched && this.viewModel.state === ViewLoadState.Idle) {
            Column({ space: Spacing.SM }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(32)
                .fontColor([SemanticColors.textTertiary()])
              Text('输入关键词搜索标题、正文或回帖')
                .fontSize(Typography.BODY)
                .fontColor(SemanticColors.textSecondary())
            }
            .id('search-empty-hint')
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
            // The hint is lifted over the search controls for visual centering, but
            // a full-width transparent column still intercepts touches there. Let
            // every tap fall through so the input and field picker stay clickable.
            .hitTestBehavior(HitTestMode.None)
            .translate({ y: -SEARCH_EMPTY_HINT_LIFT })
          } else {
            PaginatedTopicList({
              viewModel: this.viewModel,
              bottomInset: this.bottomContentInset,
              semanticPrefix: 'search',
              emptyTitle: '没有找到匹配的帖子',
              onTopicSelected: (topic: TopicUiModel) => this.onTopicSelected(topic),
              onRetry: () => this.search()
            })
              .layoutWeight(1)
          }
        }
      }
      .id('search-page')
      .width('100%').height('100%')
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
