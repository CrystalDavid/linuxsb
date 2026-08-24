import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
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
import { PaginatedTopicList } from '../components/PaginatedTopicList';

@Component
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

  @Builder
  private fieldChip(label: string, field: FeedSearchField) {
    Button(label, { type: ButtonType.Capsule, stateEffect: true })
      .height(30)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .fontSize(Typography.CAPTION)
      .fontColor(this.field === field ? $r('app.color.brand_primary') : SemanticColors.textSecondary())
      .backgroundColor(this.field === field ? $r('app.color.brand_soft') : Color.Transparent)
      .onClick(() => { this.field = field; })
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
        .backgroundColor(SemanticColors.surfaceMuted())
        .borderRadius(Radius.PILL)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_right'))
            .fontSize(20)
            .fontColor([Color.White])
        }
        .id('search-submit')
        .width(44).height(44)
        .backgroundColor($r('app.color.brand_primary'))
        .onClick(() => this.search())
      }
      .width('100%')

      Row({ space: Spacing.XS }) {
        this.fieldChip('标题', FeedSearchField.Title)
        this.fieldChip('正文', FeedSearchField.Body)
        this.fieldChip('回帖', FeedSearchField.Reply)
        Blank()
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.SM, bottom: Spacing.MD })
    .backgroundColor(SemanticColors.surface())
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
      Text('linux.sb 的站内搜索需要登录。登录只在临时官方页面完成。')
        .fontSize(Typography.BODY)
        .lineHeight(Typography.BODY_LINE_HEIGHT)
        .fontColor(SemanticColors.textSecondary())
        .textAlign(TextAlign.Center)
      Button('打开官方登录页', { type: ButtonType.Capsule, stateEffect: true })
        .height(44)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.brand_primary'))
        .onClick(() => this.onLogin())
    }
    .id('search-login-required')
    .width('100%')
    .padding(Spacing.XL)
    .margin({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XXL })
    .backgroundColor(SemanticColors.surface())
    .borderRadius(Radius.LG)
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
