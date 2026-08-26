import { PageMetrics, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { TopicListLayoutVariant } from '../../common/theme/TopicListStylePrefs';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { ViewLoadState } from '../../viewmodels/ViewState';
import { LoadStateView } from './LoadStateView';
import { TopicListItem } from './TopicListItem';

@Component
export struct PaginatedTopicList {
  @ObjectLink viewModel: HomeViewModel;
  topSpacer: number = 0;
  bottomInset: number = PageMetrics.BOTTOM_TAB_BAR_CONTENT_INSET;
  semanticPrefix: string = 'feed';
  emptyTitle: string = '暂无主题';
  onTopicSelected: (topic: TopicUiModel) => void = () => {};
  onRetry: () => void = () => {};
  layoutVariant: TopicListLayoutVariant = TopicListLayoutVariant.LegacyCompact;
  emphasizeTopicTitle: boolean = false;

  private async loadMore(): Promise<void> {
    await this.viewModel.loadMore();
  }

  @Builder
  private footer() {
    if (this.viewModel.hasMore()) {
      Row({ space: Spacing.SM }) {
        if (this.viewModel.loadingMore) {
          LoadingProgress().width(20).height(20).color($r('app.color.brand_primary'))
        }
        Text(this.viewModel.loadingMore ? '正在加载更多' :
          (this.viewModel.loadMoreError.length > 0 ? '加载失败，点此重试' : '继续加载'))
          .fontSize(Typography.CAPTION)
          .fontColor(this.viewModel.loadMoreError.length > 0 ? SemanticColors.error() : SemanticColors.textTertiary())
      }
      .id(`${this.semanticPrefix}-load-more`)
      .width('100%').height(54)
      .justifyContent(FlexAlign.Center)
      .onAppear(() => this.loadMore())
      .onClick(() => this.loadMore())
    }
    Column().height(this.bottomInset)
  }

  build() {
    Stack() {
      if (this.viewModel.state === ViewLoadState.Content) {
        List() {
          if (this.topSpacer > 0) {
            ListItem() { Column().width('100%').height(this.topSpacer) }
          }
          LazyForEach(this.viewModel.presentationDataSource, (topic: TopicUiModel) => {
            TopicListItem({
              topic: topic,
              layoutVariant: this.layoutVariant,
              emphasizeTitle: this.emphasizeTopicTitle,
              semanticId: `${this.semanticPrefix}-topic-${topic.topicId}`,
              onTopicClick: (selected: TopicUiModel) => this.onTopicSelected(selected)
            })
          }, (topic: TopicUiModel) => topic.topicId.toString())
          ListItem() { this.footer() }
        }
        .id(`${this.semanticPrefix}-topic-list`)
        .width('100%').height('100%')
        .scrollBar(BarState.Off)
        .cachedCount(6)
      } else {
        LoadStateView({
          state: this.viewModel.state,
          title: this.viewModel.state === ViewLoadState.Empty ? this.emptyTitle :
            this.viewModel.state === ViewLoadState.Offline ? '当前无法联网' :
              this.viewModel.state === ViewLoadState.Error ? '加载失败' : '正在加载',
          detail: this.viewModel.state === ViewLoadState.Offline ? '请检查网络连接后重试。' : '',
          semanticPrefix: this.semanticPrefix,
          showSkeleton: this.viewModel.state === ViewLoadState.Loading || this.viewModel.state === ViewLoadState.Idle,
          onRetry: () => this.onRetry()
        })
          .padding({ top: this.topSpacer, bottom: this.bottomInset })
      }
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }
}
