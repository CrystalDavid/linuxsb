import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { FeedSort, ForumSummary, HomeFeedRequest } from '../../models/HomeModels';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { ViewLoadState } from '../../viewmodels/ViewState';
import { PaginatedTopicList } from '../components/PaginatedTopicList';

@Component
export struct ForumsPage {
  @ObjectLink viewModel: HomeViewModel;
  bottomContentInset: number = PageMetrics.BOTTOM_TAB_BAR_CONTENT_INSET;
  onTopicSelected: (topic: TopicUiModel) => void = () => {};
  @State private selectedForumId: number = 0;
  @State private selectedSort: FeedSort = FeedSort.NewComments;
  @State private forums: ForumSummary[] = [];

  aboutToAppear(): void {
    if (this.viewModel.state === ViewLoadState.Idle) {
      this.load(false);
    } else {
      this.syncForums();
    }
  }

  private async load(refresh: boolean): Promise<void> {
    await this.viewModel.load(refresh);
    this.syncForums();
  }

  private syncForums(): void {
    this.forums = (this.viewModel.forums ?? []).slice();
  }

  private async selectForum(forumId: number): Promise<void> {
    if (forumId === this.selectedForumId && this.viewModel.state !== ViewLoadState.Idle) {
      return;
    }
    this.selectedForumId = forumId;
    this.viewModel.configure(forumId > 0 ?
      HomeFeedRequest.forum(forumId, this.selectedSort) : HomeFeedRequest.home(this.selectedSort));
    await this.load(false);
  }

  private async changeSort(sort: FeedSort): Promise<void> {
    if (this.selectedSort === sort) {
      return;
    }
    this.selectedSort = sort;
    this.viewModel.configure(this.selectedForumId > 0 ?
      HomeFeedRequest.forum(this.selectedForumId, sort) : HomeFeedRequest.home(sort));
    await this.load(false);
  }

  private chipColor(selected: boolean): ResourceColor {
    return selected ? $r('app.color.brand_primary') : SemanticColors.textSecondary();
  }

  @Builder
  private forumChip(id: number, name: string) {
    Button(name, { type: ButtonType.Capsule, stateEffect: true })
      .id(id === 0 ? 'forum-all' : `forum-${id}`)
      .height(38)
      .padding({ left: Spacing.LG, right: Spacing.LG })
      .fontSize(Typography.LABEL)
      .fontWeight(this.selectedForumId === id ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.chipColor(this.selectedForumId === id))
      .backgroundColor(this.selectedForumId === id ? $r('app.color.brand_soft') : SemanticColors.surfaceMuted())
      .borderRadius(Radius.PILL)
      .onClick(() => this.selectForum(id))
  }

  @Builder
  private selector() {
    Column({ space: Spacing.SM }) {
      Scroll() {
        Row({ space: Spacing.SM }) {
          this.forumChip(0, '全部')
          ForEach(this.forums, (forum: ForumSummary) => {
            this.forumChip(forum.forumId, forum.name)
          }, (forum: ForumSummary) => forum.forumId.toString())
        }
        .padding({ left: Spacing.MD, right: Spacing.MD })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)

      Row({ space: Spacing.XS }) {
        Button('新评论', { type: ButtonType.Normal, stateEffect: true })
          .height(30).fontSize(Typography.CAPTION)
          .fontColor(this.selectedSort === FeedSort.NewComments ? $r('app.color.brand_primary') :
            SemanticColors.textSecondary())
          .backgroundColor(Color.Transparent)
          .onClick(() => this.changeSort(FeedSort.NewComments))
        Button('新帖子', { type: ButtonType.Normal, stateEffect: true })
          .height(30).fontSize(Typography.CAPTION)
          .fontColor(this.selectedSort === FeedSort.NewTopics ? $r('app.color.brand_primary') :
            SemanticColors.textSecondary())
          .backgroundColor(Color.Transparent)
          .onClick(() => this.changeSort(FeedSort.NewTopics))
        Blank()
        Text(this.selectedForumId === 0 ? '全部板块' :
          (this.forums.find((forum: ForumSummary) => forum.forumId === this.selectedForumId)?.name ?? '板块'))
          .fontSize(Typography.CAPTION)
          .fontColor(SemanticColors.textTertiary())
      }
      .width('100%')
      .padding({ left: Spacing.MD, right: Spacing.MD })
    }
    .width('100%')
    .padding({ top: Spacing.SM, bottom: Spacing.SM })
    .backgroundColor(SemanticColors.surface())
  }

  @Builder
  private titleBar() {
    Row() {
      Text('板块')
        .fontSize(Typography.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
    }
    .width('100%').height('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    HdsNavigation() {
      Column() {
        this.selector()
        PaginatedTopicList({
          viewModel: this.viewModel,
          bottomInset: this.bottomContentInset,
          semanticPrefix: 'forums',
          emptyTitle: '这个板块还没有主题',
          onTopicSelected: (topic: TopicUiModel) => this.onTopicSelected(topic),
          onRetry: () => this.load(false)
        })
          .layoutWeight(1)
      }
      .id('forums-page')
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
