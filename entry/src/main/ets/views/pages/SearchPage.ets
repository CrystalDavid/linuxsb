import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';
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
import { CompactSegmentedControl, SegmentOption } from '../components/CompactSegmentedControl';
import {
  GLASS_ACTION_ARROW_ICON_SIZE,
  GLASS_ACTION_ARROW_ICON_WEIGHT,
  ImmersiveIconButton
} from '../components/ImmersiveIconButton';
import { PaginatedTopicList } from '../components/PaginatedTopicList';

const SEARCH_FIELD_SEGMENT_WIDTH: number = 52;
const SEARCH_FIELD_CONTROL_HEIGHT: number = 32;
const SEARCH_PRIMARY_CONTROL_HEIGHT: number = 42;
const SEARCH_EMPTY_HINT_LIFT: number = 100;

@Component({ freezeWhenInactive: true })
export struct SearchPage {
  @ObjectLink viewModel: HomeViewModel;
  @Prop authenticated: boolean = false;
  bottomContentInset: number = PageMetrics.BOTTOM_TAB_BAR_CONTENT_INSET;
  onLogin: () => void = () => {};
  onTopicSelected: (topic: TopicUiModel) => void = () => {};
  @State private query: string = '';
  @State private field: FeedSearchField = FeedSearchField.Title;
  @State private hasSearched: boolean = false;

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
    this.hasSearched = true;
    this.viewModel.configure(HomeFeedRequest.search(normalized, this.field));
    await this.viewModel.load(false);
  }

  @Builder
  private titleBar() {
    Row() {
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

  private fieldOptions(): SegmentOption[] {
    return [
      new SegmentOption('标题', 'search-field-title'),
      new SegmentOption('正文', 'search-field-body'),
      new SegmentOption('回帖', 'search-field-reply')
    ];
  }

  private fieldIndex(): number {
    if (this.field === FeedSearchField.Body) {
      return 1;
    }
    return this.field === FeedSearchField.Reply ? 2 : 0;
  }

  private selectField(index: number): void {
    this.field = index === 1 ? FeedSearchField.Body : (index === 2 ? FeedSearchField.Reply : FeedSearchField.Title);
  }

  @Builder
  private searchControls() {
    Column({ space: Spacing.LG }) {
      Row({ space: Spacing.SM }) {
        Row({ space: Spacing.XS }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(20)
            .fontColor([SemanticColors.textSecondary()])
          TextInput({ text: this.query, placeholder: '搜索社区帖子' })
            .id('search-input')
            .layoutWeight(1)
            .height(SEARCH_PRIMARY_CONTROL_HEIGHT - 2)
            .fontSize(Typography.BODY)
            .fontColor(SemanticColors.textPrimary())
            .placeholderColor(SemanticColors.textSecondary())
            .caretColor($r('app.color.brand_primary'))
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
        .backgroundEffect(buildImmersiveGlassEffect())
        .border({ width: IMMERSIVE_GLASS_BORDER_WIDTH, color: $r('app.color.bottom_tab_bar_highlight') })
        .borderRadius(Radius.PILL)
        .shadow({
          radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
          color: $r('app.color.bottom_tab_bar_shadow'),
          offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
        })

        ImmersiveIconButton({
          icon: $r('sys.symbol.arrow_up'),
          semanticId: 'search-submit',
          semanticLabel: '搜索',
          buttonSize: SEARCH_PRIMARY_CONTROL_HEIGHT,
          iconSize: GLASS_ACTION_ARROW_ICON_SIZE,
          iconWeight: GLASS_ACTION_ARROW_ICON_WEIGHT,
          iconRotation: 90,
          iconColor: $r('app.color.brand_primary'),
          onAction: () => this.search()
        })
      }
      .width('100%')

      Row() {
        CompactSegmentedControl({
          options: this.fieldOptions(),
          selectedIndex: this.fieldIndex(),
          segmentWidth: SEARCH_FIELD_SEGMENT_WIDTH,
          controlHeight: SEARCH_FIELD_CONTROL_HEIGHT,
          labelFontSize: Typography.BODY_SMALL,
          semanticId: 'search-field-control',
          onSelect: (index: number) => this.selectField(index)
        })
        Blank()
      }
      .width('100%')
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
