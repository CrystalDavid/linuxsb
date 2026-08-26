import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  HOME_TOPIC_LIST_LAYOUT_STORAGE_KEY,
  HomeTopicListLayoutMode
} from '../../common/theme/HomeTopicListLayout';
import { TopicListLayoutVariant } from '../../common/theme/TopicListStylePrefs';
import { immersiveTitleBarContentTopSpacer } from '../../common/ui/ImmersiveTitleBarLayout';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import { shouldAutoLoadNextHomePage } from '../../common/ui/HomePaginationPolicy';
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
import {
  CompactSegmentedControl,
  SegmentOption,
  TITLE_BAR_SEGMENT_HEIGHT,
  TITLE_BAR_SEGMENT_LABEL_SIZE,
  TITLE_BAR_SEGMENT_WIDTH
} from '../components/CompactSegmentedControl';
import { TopicListDataSource } from '../components/TopicListDataSource';
import { TopicListItem } from '../components/TopicListItem';
import { HomeFab } from '../components/HomeFab';

@Component({ freezeWhenInactive: true })
export struct HomePage {
  @ObjectLink viewModel: HomeViewModel;
  debugAvailable: boolean = false;
  bottomContentInset: number = PageMetrics.BOTTOM_TAB_BAR_CONTENT_INSET;
  onTopicSelected: (topic: TopicUiModel) => void = () => {};
  onOpenDiagnostics: () => void = () => {};
  onPrefetch: (topicIds: number[]) => void = () => {};
  onCancelPrefetch: () => void = () => {};
  onCompose: () => void = () => {};
  @StorageProp(SYS_TOP_INSET_KEY) private topInset: number = 0;
  @StorageLink(HOME_TOPIC_LIST_LAYOUT_STORAGE_KEY) private homeTopicListLayout: string =
    HomeTopicListLayoutMode.TitleFirst;
  @State private selectedSort: FeedSort = FeedSort.NewComments;
  @State private contentWidth: number = 0;
  @State private contentHeight: number = 0;
  private listScroller: Scroller = new Scroller();
  private topicDataSource: TopicListDataSource = new TopicListDataSource();
  private lastPrefetchKey: string = '';
  private firstVisibleTopicIndex: number = 0;
  private listIsScrolling: boolean = false;
  private lastAutoLoadTopicCount: number = -1;

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
    const previousCount = this.topicDataSource.totalCount();
    await this.viewModel.loadMore();
    if (this.viewModel.presentationTopics.length < previousCount) {
      this.syncPresentation();
      return;
    }
    this.topicDataSource.appendUnique(this.viewModel.presentationTopics.slice(previousCount));
    if (!this.listIsScrolling) {
      this.prefetchFrom(this.firstVisibleTopicIndex);
    }
  }

  private syncPresentation(): void {
    this.topicDataSource.reset(this.viewModel.presentationTopics);
    this.firstVisibleTopicIndex = 0;
    this.lastAutoLoadTopicCount = -1;
    if (!this.listIsScrolling) {
      this.prefetchFrom(0);
    }
  }

  private prefetchFrom(firstVisible: number): void {
    const ids: number[] = [];
    const topics = this.topicDataSource.getAll();
    for (let index = Math.max(0, firstVisible); index < topics.length && ids.length < 2; index++) {
      ids.push(topics[index].topicId);
    }
    const key = ids.join(',');
    if (key === this.lastPrefetchKey) {
      return;
    }
    this.lastPrefetchKey = key;
    this.onPrefetch(ids);
  }

  private sortOptions(): SegmentOption[] {
    return [
      new SegmentOption('新评论', 'home-sort-comments'),
      new SegmentOption('新帖子', 'home-sort-topics')
    ];
  }

  @Builder
  private titleBarContent() {
    Row({ space: Spacing.SM }) {
      Text('烧饼社区')
        .id('home-page-title')
        .fontSize(Typography.PAGE_TITLE)
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
      CompactSegmentedControl({
        options: this.sortOptions(),
        selectedIndex: this.selectedSort === FeedSort.NewComments ? 0 : 1,
        segmentWidth: TITLE_BAR_SEGMENT_WIDTH,
        controlHeight: TITLE_BAR_SEGMENT_HEIGHT,
        labelFontSize: TITLE_BAR_SEGMENT_LABEL_SIZE,
        semanticId: 'home-sort-control',
        onSelect: (index: number) => this.changeSort(index === 0 ? FeedSort.NewComments : FeedSort.NewTopics)
      })
        .translate({ y: -2 })
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
      .onClick(() => this.loadMore())
    }
    Column().height(this.bottomContentInset)
  }

  @Builder
  private homeTopicItem(topic: TopicUiModel, layoutVariant: TopicListLayoutVariant) {
    TopicListItem({
      topic: topic,
      layoutVariant: layoutVariant,
      contentHorizontalPadding: PageMetrics.HORIZONTAL_PADDING,
      semanticId: this.topicDataSource.totalCount() > 0 &&
        this.topicDataSource.getData(0).topicId === topic.topicId ?
        'home-first-topic' : `topic-item-${topic.topicId}`,
      onTopicClick: (selected: TopicUiModel) => this.onTopicSelected(selected)
    })
  }

  @Builder
  private homeContent() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Refresh({ refreshing: this.viewModel.refreshing, promptText: '刷新中' }) {
        List({ scroller: this.listScroller }) {
          ListItem() {
            Column().width('100%').height(immersiveTitleBarContentTopSpacer(this.topInset))
          }
          if (this.homeTopicListLayout === HomeTopicListLayoutMode.AuthorFirst) {
            LazyForEach(this.topicDataSource, (topic: TopicUiModel) => {
              this.homeTopicItem(topic, TopicListLayoutVariant.AuthorHeader)
            }, (topic: TopicUiModel) => `${topic.topicId}-author-first`)
          } else {
            LazyForEach(this.topicDataSource, (topic: TopicUiModel) => {
              this.homeTopicItem(topic, TopicListLayoutVariant.ThreeMetadataRows)
            }, (topic: TopicUiModel) => `${topic.topicId}-title-first`)
          }
          if (this.topicDataSource.totalCount() > 0) {
            ListItem() { this.listFooter() }
          }
        }
        .id('home-topic-list')
        .accessibilityText(`首页主题列表，第${this.viewModel.currentPage}页，已加载${this.topicDataSource.totalCount()}条`)
        .width('100%')
        .height(`calc(100% + ${immersiveTitleBarContentTopSpacer(this.topInset)}vp)`)
        .position({ x: 0, y: -immersiveTitleBarContentTopSpacer(this.topInset) })
        .clip(false)
        .scrollBar(BarState.Off)
        .cachedCount(6)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onScrollStart(() => {
          this.listIsScrolling = true;
          this.lastPrefetchKey = '';
          this.onCancelPrefetch();
        })
        .onScrollIndex((start: number, end: number) => {
          this.firstVisibleTopicIndex = Math.max(0, start - 1);
          const topicCount = this.topicDataSource.totalCount();
          if (shouldAutoLoadNextHomePage(end, topicCount, this.viewModel.hasMore(),
            this.viewModel.loadingMore, this.lastAutoLoadTopicCount)) {
            this.lastAutoLoadTopicCount = topicCount;
            this.loadMore();
          }
        })
        .onScrollStop(() => {
          this.listIsScrolling = false;
          this.prefetchFrom(this.firstVisibleTopicIndex);
        })
      }
      .id(this.homeTopicListLayout === HomeTopicListLayoutMode.AuthorFirst ?
        'home-layout-author-first-active' : 'home-layout-title-first-active')
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

      HomeFab({
        onAction: () => this.onCompose(),
        maxDragX: Math.max(0, this.contentWidth - PageMetrics.FAB_SIZE - Spacing.XXXL),
        maxDragY: Math.max(0, this.contentHeight - this.topInset - this.bottomContentInset -
          PageMetrics.FAB_SIZE - Spacing.XXXL)
      })
        .margin({ right: Spacing.LG, bottom: this.bottomContentInset + Spacing.XXXL + Spacing.SM })
        .zIndex(4)
    }
    .id('home-page')
    .width('100%').height('100%')
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.contentWidth = Number(newArea.width);
      this.contentHeight = Number(newArea.height);
    })
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
