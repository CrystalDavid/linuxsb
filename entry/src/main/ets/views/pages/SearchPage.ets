import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect
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
import { CompactSegmentedControl, SegmentOption } from '../components/CompactSegmentedControl';
import { ImmersiveGlassTextButton } from '../components/ImmersiveGlassTextButton';
import { ImmersiveIconButton } from '../components/ImmersiveIconButton';
import { PaginatedTopicList } from '../components/PaginatedTopicList';

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
        .fontSize(Typography.TITLE)
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
    Column({ space: Spacing.SM }) {
      Row({ space: Spacing.SM }) {
        Row({ space: Spacing.SM }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(20)
            .fontColor([SemanticColors.textSecondary()])
          TextInput({ text: this.query, placeholder: '搜索社区帖子' })
            .id('search-input')
            .layoutWeight(1)
            .height(44)
            .fontSize(Typography.BODY)
            .backgroundColor(Color.Transparent)
            .enterKeyType(EnterKeyType.Search)
            .onChange((value: string) => { this.query = value; })
            .onSubmit(() => this.search())
        }
        .layoutWeight(1)
        .height(46)
        .padding({ left: Spacing.MD, right: Spacing.SM })
        .backgroundEffect(buildImmersiveGlassEffect())
        .border({ width: 1.1, color: $r('app.color.liquid_glass_highlight') })
        .borderRadius(Radius.PILL)
        .shadow({ radius: 8, color: $r('app.color.hds_floating_action_glow'), offsetY: 2 })

        ImmersiveIconButton({
          icon: $r('sys.symbol.arrow_right'),
          semanticId: 'search-submit',
          semanticLabel: '搜索',
          buttonSize: 44,
          iconSize: 20,
          iconColor: $r('app.color.brand_primary'),
          onAction: () => this.search()
        })
      }
      .width('100%')

      Row() {
        CompactSegmentedControl({
          options: this.fieldOptions(),
          selectedIndex: this.fieldIndex(),
          onSelect: (index: number) => this.selectField(index)
        })
        Blank()
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.SM, bottom: Spacing.MD })
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private loginGate() {
    Column({ space: Spacing.MD }) {
      SymbolGlyph($r('sys.symbol.person_badge_lock_fill'))
        .fontSize(34)
        .fontColor([$r('app.color.brand_primary')])
      Text('登录后搜索')
        .fontSize(Typography.TITLE_SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.textPrimary())
      ImmersiveGlassTextButton({
        label: '打开官方登录页',
        semanticId: 'search-login-action',
        onAction: () => this.onLogin()
      })
    }
    .id('search-login-required')
    .width('100%')
    .padding(Spacing.XL)
    .margin({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XXL })
    .backgroundColor(Color.Transparent)
  }

  build() {
    HdsNavigation() {
      Column() {
        this.searchControls()
        if (!this.authenticated) {
          this.loginGate()
        } else if (!this.hasSearched && this.viewModel.state === ViewLoadState.Idle) {
          Column({ space: Spacing.SM }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(32)
              .fontColor([SemanticColors.textTertiary()])
            Text('输入关键词搜索标题、正文或回帖')
              .fontSize(Typography.BODY)
              .fontColor(SemanticColors.textSecondary())
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
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
      .id('search-page')
      .width('100%').height('100%')
      .padding({ bottom: this.authenticated && this.hasSearched ? 0 : this.bottomContentInset })
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
