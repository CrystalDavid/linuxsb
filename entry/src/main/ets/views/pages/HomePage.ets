import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { immersiveTitleBarContentTopSpacer } from '../../common/ui/ImmersiveTitleBarLayout';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { SYS_TOP_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { FeedSort, HomeFeedRequest } from '../../models/HomeModels';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { ViewLoadState } from '../../viewmodels/ViewState';
import { LoadStateView } from '../components/LoadStateView';
import { TopicListDataSource } from '../components/TopicListDataSource';
import { TopicListItem } from '../components/TopicListItem';

@Component
export struct HomePage {
  @ObjectLink viewModel: HomeViewModel;
  debugAvailable: boolean = false;
  bottomContentInset: number = PageMetrics.BOTTOM_TAB_BAR_CONTENT_INSET;
  onTopicSelected: (topic: TopicUiModel) => void = () => {};
  onOpenDiagnostics: () => void = () => {};
  onPrefetch: (topicIds: number[]) => void = () => {};
  onCancelPrefetch: () => void = () => {};
  @StorageProp(SYS_TOP_INSET_KEY) private topInset: number = 0;
  @State private selectedSort: FeedSort = FeedSort.NewComments;
  @State private visibleTopics: TopicUiModel[] = [];
  private listScroller: Scroller = new Scroller();
  private topicDataSource: TopicListDataSource = new TopicListDataSource();
  private lastPrefetchKey: string = '';

  aboutToAppear(): void {
    this.syncPresentation();
    if (this.viewModel.state === ViewLoadState.Idle) {
      this.load(false);
    }
  }

  aboutToDisappear(): void {
    this.lastPrefetchKey = '';
    this.onCancelPrefetch();
  }

  private async load(isRefresh: boolean): Promise<void> {
    await this.viewModel.load(isRefresh);
    this.syncPresentation();
  }

  private async changeSort(sort: FeedSort): Promise<void> {
    if (this.selectedSort === sort && this.viewModel.state !== ViewLoadState.Idle) {
      return;
    }
    this.selectedSort = sort;
    this.viewModel.configure(HomeFeedRequest.home(sort));
    this.syncPresentation();
    await this.load(false);
  }

  private async loadMore(): Promise<void> {
    await this.viewModel.loadMore();
    this.syncPresentation();
  }

  private syncPresentation(): void {
    this.visibleTopics = this.viewModel.presentationTopics.slice();
    this.topicDataSource.replace(this.visibleTopics);
    this.prefetchFrom(0);
  }

  private prefetchFrom(firstVisible: number): void {
    const ids: number[] = [];
    for (let index = Math.max(0, firstVisible); index < this.visibleTopics.length && ids.length < 3; index++) {
      ids.push(this.visibleTopics[index].topicId);
    }
    const key = ids.join(',');
    if (key === this.lastPrefetchKey) {
      return;
    }
    this.lastPrefetchKey = key;
    this.onPrefetch(ids);
  }

  @Builder
  private sortButton(label: string, sort: FeedSort) {
    Button(label, { type: ButtonType.Capsule, stateEffect: true })
      .id(sort === FeedSort.NewComments ? 'home-sort-comments' : 'home-sort-topics')
      .height(32)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .fontSize(Typography.CAPTION)
      .fontWeight(this.selectedSort === sort ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selectedSort === sort ? $r('app.color.brand_primary') : SemanticColors.textSecondary())
      .backgroundColor(this.selectedSort === sort ? $r('app.color.brand_soft') : Color.Transparent)
      .borderRadius(Radius.PILL)
      .onClick(() => this.changeSort(sort))
  }

  @Builder
  private titleBarContent() {
    Row({ space: Spacing.SM }) {
      Text('烧饼社区')
        .fontSize(Typography.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .maxLines(1)
        .gesture(
          LongPressGesture({ repeat: false, duration: 1200 })
            .onAction(() => {
              if (this.debugAvailable) {
                this.onOpenDiagnostics();
              }
            })
        )
        .layoutWeight(1)
      this.sortButton('新评论', FeedSort.NewComments)
      this.sortButton('新帖子', FeedSort.NewTopics)
    }
    .width('100%')
    .height('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private listFooter() {
    if (this.viewModel.hasMore()) {
      Row({ space: Spacing.SM }) {
        if (this.viewModel.loadingMore) {
          LoadingProgress().width(20).height(20).color($r('app.color.brand_primary'))
        }
        Text(this.viewModel.loadingMore ? '正在加载更多主题' :
          (this.viewModel.loadMoreError.length > 0 ? '加载失败，点此重试' : '继续加载'))
          .fontSize(Typography.CAPTION)
          .fontColor(this.viewModel.loadMoreError.length > 0 ? SemanticColors.error() : SemanticColors.textTertiary())
      }
      .id('home-load-more')
      .width('100%')
      .height(54)
      .justifyContent(FlexAlign.Center)
      .onAppear(() => this.loadMore())
      .onClick(() => this.loadMore())
    }
    Column().height(this.bottomContentInset)
  }

  @Builder
  private homeContent() {
    Stack() {
      Refresh({ refreshing: this.viewModel.refreshing, promptText: '刷新中' }) {
        List({ scroller: this.listScroller }) {
          ListItem() {
            Column().width('100%').height(immersiveTitleBarContentTopSpacer(this.topInset))
          }
          LazyForEach(this.topicDataSource, (topic: TopicUiModel) => {
            TopicListItem({
              topic: topic,
              contentHorizontalPadding: PageMetrics.HORIZONTAL_PADDING,
              semanticId: this.visibleTopics.length > 0 && this.visibleTopics[0].topicId === topic.topicId ?
                'home-first-topic' : `topic-item-${topic.topicId}`,
              onTopicClick: (selected: TopicUiModel) => this.onTopicSelected(selected)
            })
          }, (topic: TopicUiModel) => topic.topicId.toString())
          if (this.visibleTopics.length > 0) {
            ListItem() { this.listFooter() }
          }
        }
        .id('home-topic-list')
        .width('100%')
        .height(`calc(100% + ${immersiveTitleBarContentTopSpacer(this.topInset)}vp)`)
        .position({ x: 0, y: -immersiveTitleBarContentTopSpacer(this.topInset) })
        .clip(false)
        .scrollBar(BarState.Off)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onScrollIndex((start: number, _end: number) => {
          this.prefetchFrom(Math.max(0, start - 1));
        })
      }
      .width('100%').height('100%')
      .clip(false)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .pullToRefresh(true)
      .refreshOffset(64)
      .onRefreshing(() => this.load(true))

      if (this.viewModel.state !== ViewLoadState.Content) {
        LoadStateView({
          state: this.viewModel.state,
          title: this.viewModel.state === ViewLoadState.Empty ? '暂无主题' :
            this.viewModel.state === ViewLoadState.Offline ? '当前无法联网' :
              this.viewModel.state === ViewLoadState.Error ? '首页加载失败' : '正在读取社区主题',
          detail: this.viewModel.state === ViewLoadState.Offline ? '请检查网络连接后重试。' :
            this.viewModel.state === ViewLoadState.Error ? '服务响应暂时无法转换为稳定列表。' : '',
          semanticPrefix: 'home',
          showSkeleton: this.viewModel.state === ViewLoadState.Loading || this.viewModel.state === ViewLoadState.Idle,
          onRetry: () => this.load(false)
        })
          .padding({ top: immersiveTitleBarContentTopSpacer(this.topInset), bottom: this.bottomContentInset })
      }
    }
    .id('home-page')
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }

  build() {
    HdsNavigation() {
      this.homeContent()
    }
    .titleBar({
      avoidLayoutSafeArea: requiresHdsLayoutSafeAreaAvoidance(ImmersiveLightArea.TITLE_BAR),
      enableComponentSafeArea: requiresHdsComponentSafeArea(ImmersiveLightArea.TITLE_BAR),
      style: buildImmersiveTitleBarStyle({ enableRefreshOffsetChange: true }),
      content: { stackBuilder: () => { this.titleBarContent(); } }
    })
    .bindToScrollable([this.listScroller])
    .titleMode(HdsNavigationTitleMode.MINI)
    .mode(NavigationMode.Stack)
    .hideBackButton(true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }
}
