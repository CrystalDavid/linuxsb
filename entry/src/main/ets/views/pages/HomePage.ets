import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { MotionDuration, PageMetrics, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { SCRIM } from '../../common/theme/Palette';
import { immersiveTitleBarContentTopSpacer } from '../../common/ui/ImmersiveTitleBarLayout';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { SYS_BOTTOM_INSET_KEY, SYS_TOP_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { CategoryUiModel, TopicUiModel } from '../../models/presentation/ForumUiModels';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { ViewLoadState } from '../../viewmodels/ViewState';
import { CategoryDrawer, HomeFeedSort } from '../components/CategoryDrawer';
import { HomeFab } from '../components/HomeFab';
import { LoadStateView } from '../components/LoadStateView';
import { TopicListDataSource } from '../components/TopicListDataSource';
import { TopicListItem } from '../components/TopicListItem';

const DRAWER_COMMIT_RATIO: number = 0.4;
const DRAWER_COMMIT_VELOCITY: number = 800;

@Component
export struct HomePage {
  @ObjectLink viewModel: HomeViewModel;
  debugAvailable: boolean = false;
  authenticated: boolean = false;
  onTopicSelected: (topic: TopicUiModel) => void = () => {};
  onOpenDiagnostics: () => void = () => {};
  onLogin: () => void = () => {};
  onPrefetch: (topicIds: number[]) => void = () => {};
  onCancelPrefetch: () => void = () => {};
  @StorageProp(SYS_TOP_INSET_KEY) private topInset: number = 0;
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;
  @State private drawerMounted: boolean = false;
  @State private drawerProgress: number = 0;
  @State private drawerOpen: boolean = false;
  @State private draftSort: HomeFeedSort = HomeFeedSort.Latest;
  @State private appliedSort: HomeFeedSort = HomeFeedSort.Latest;
  @State private draftCategoryId: number = 0;
  @State private appliedCategoryId: number = 0;
  @State private categories: CategoryUiModel[] = [];
  @State private visibleTopics: TopicUiModel[] = [];
  @State private searchVisible: boolean = false;
  @State private searchQuery: string = '';
  private touchDownX: number = -1;
  private listScroller: Scroller = new Scroller();
  private topicDataSource: TopicListDataSource = new TopicListDataSource();

  aboutToAppear(): void {
    this.syncPresentation();
    if (this.viewModel.state === ViewLoadState.Idle) {
      this.load(false);
    }
  }

  aboutToDisappear(): void {
    this.onCancelPrefetch();
  }

  private async load(isRefresh: boolean): Promise<void> {
    await this.viewModel.load(isRefresh);
    this.syncPresentation();
  }

  private syncPresentation(): void {
    this.categories = this.collectCategories(this.viewModel.presentationTopics);
    this.applyFilters();
  }

  private collectCategories(topics: TopicUiModel[]): CategoryUiModel[] {
    const output: CategoryUiModel[] = [];
    const seen = new Set<number>();
    for (let index = 0; index < topics.length; index++) {
      const category = topics[index].category;
      if (category.categoryId > 0 && category.name.length > 0 && !seen.has(category.categoryId)) {
        seen.add(category.categoryId);
        output.push(category);
      }
    }
    return output;
  }

  private applyFilters(): void {
    let topics = this.viewModel.presentationTopics.slice();
    if (this.appliedCategoryId > 0) {
      topics = topics.filter((topic: TopicUiModel) => topic.category.categoryId === this.appliedCategoryId);
    }
    const query = this.searchQuery.trim().toLowerCase();
    if (query.length > 0) {
      topics = topics.filter((topic: TopicUiModel) => topic.title.toLowerCase().includes(query));
    }
    if (this.appliedSort === HomeFeedSort.NewComments) {
      topics.sort((left: TopicUiModel, right: TopicUiModel) => right.lastReplyAt - left.lastReplyAt);
    } else if (this.appliedSort === HomeFeedSort.NewTopics) {
      topics.sort((left: TopicUiModel, right: TopicUiModel) => right.topicId - left.topicId);
    } else if (this.appliedSort === HomeFeedSort.Featured) {
      topics = topics.filter((topic: TopicUiModel) => topic.isFeatured);
    }
    this.visibleTopics = topics;
    this.topicDataSource.replace(topics);
    this.prefetchFrom(0);
  }

  private prefetchFrom(firstVisible: number): void {
    const ids: number[] = [];
    for (let index = Math.max(0, firstVisible); index < this.visibleTopics.length && ids.length < 3; index++) {
      ids.push(this.visibleTopics[index].topicId);
    }
    this.onPrefetch(ids);
  }

  private hasFeatured(): boolean {
    return this.viewModel.presentationTopics.some((topic: TopicUiModel) => topic.isFeatured);
  }

  private openDrawer(): void {
    this.draftSort = this.appliedSort;
    this.draftCategoryId = this.appliedCategoryId;
    this.drawerMounted = true;
    this.getUIContext().animateTo({ duration: MotionDuration.DRAWER_COMMIT, curve: Curve.Friction }, () => {
      this.drawerProgress = 1;
      this.drawerOpen = true;
    });
  }

  private closeDrawer(): void {
    this.drawerOpen = false;
    this.getUIContext().animateTo({ duration: MotionDuration.STANDARD, curve: Curve.Friction }, () => {
      this.drawerProgress = 0;
    });
    setTimeout(() => {
      if (!this.drawerOpen && this.drawerProgress === 0) {
        this.drawerMounted = false;
      }
    }, MotionDuration.STANDARD);
  }

  private settleDrawer(open: boolean): void {
    if (open) {
      this.drawerMounted = true;
      this.drawerOpen = true;
      this.getUIContext().animateTo({ duration: MotionDuration.DRAWER_COMMIT, curve: Curve.Friction }, () => {
        this.drawerProgress = 1;
      });
    } else {
      this.closeDrawer();
    }
  }

  private clampProgress(value: number): number {
    return Math.max(0, Math.min(1, value));
  }

  private applyDrawer(): void {
    this.appliedSort = this.draftSort;
    this.appliedCategoryId = this.draftCategoryId;
    this.applyFilters();
    this.closeDrawer();
  }

  private showWriteUnavailable(): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: '写操作尚未开放', duration: 1800 });
    } catch (_) {}
  }

  @Builder
  private menuButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Column({ space: 4 }) {
        Divider().width(18).strokeWidth(2).color(SemanticColors.textPrimary())
        Divider().width(18).strokeWidth(2).color(SemanticColors.textPrimary())
        Divider().width(18).strokeWidth(2).color(SemanticColors.textPrimary())
      }
    }
    .id('home-menu')
    .accessibilityText('打开筛选抽屉')
    .width(42).height(42).backgroundColor(Color.Transparent)
    .onClick(() => this.openDrawer())
  }

  @Builder
  private searchButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(21)
        .fontColor([SemanticColors.textPrimary()])
    }
    .id('home-search')
    .accessibilityText('搜索当前主题')
    .width(42).height(42).backgroundColor(Color.Transparent)
    .onClick(() => {
      this.searchVisible = !this.searchVisible;
      if (!this.searchVisible) {
        this.searchQuery = '';
        this.applyFilters();
      }
    })
  }

  @Builder
  private accountButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.person'))
          .fontSize(27)
          .fontColor([$r('app.color.brand_primary')])
        if (this.authenticated) {
          Row().width(8).height(8).borderRadius(4).backgroundColor($r('app.color.success'))
            .align(Alignment.BottomEnd)
        }
      }
      .width(36).height(36)
    }
    .id('home-account')
    .accessibilityText(this.authenticated ? '已登录' : '前往官方登录')
    .width(42).height(42).backgroundColor(Color.Transparent)
    .onClick(() => this.onLogin())
  }

  @Builder
  private titleBarContent() {
    Row({ space: Spacing.XS }) {
      this.menuButton()
      Text('烧饼社区')
        .fontSize(Typography.HEADLINE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .maxLines(1)
        .gesture(
          LongPressGesture({ repeat: false, duration: MotionDuration.DEBUG_LONG_PRESS })
            .onAction(() => {
              if (this.debugAvailable) {
                this.onOpenDiagnostics();
              }
            })
        )
      .layoutWeight(1)
      this.searchButton()
      this.accountButton()
    }
    .width('100%')
    .height('100%')
    .padding({ left: Spacing.SM, right: Spacing.SM })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private searchRow() {
    Row({ space: Spacing.SM }) {
      TextInput({ text: this.searchQuery, placeholder: '搜索当前已加载主题' })
        .id('home-search-input')
        .layoutWeight(1)
        .height(42)
        .fontSize(Typography.BODY)
        .backgroundColor(SemanticColors.surfaceMuted())
        .onChange((value: string) => {
          this.searchQuery = value;
          this.applyFilters();
        })
      Button('关闭')
        .height(38)
        .fontSize(Typography.LABEL)
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.searchVisible = false;
          this.searchQuery = '';
          this.applyFilters();
        })
    }
    .width('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.SM, bottom: Spacing.SM })
    .backgroundColor(SemanticColors.surface())
  }

  @Builder
  private homeContent() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Refresh({ refreshing: this.viewModel.refreshing, promptText: '刷新中' }) {
        List({ scroller: this.listScroller }) {
          ListItem() {
            Row() {
              Blank()
            }
            .width('100%')
            .height(immersiveTitleBarContentTopSpacer(this.topInset))
          }
          if (this.searchVisible) {
            ListItem() { this.searchRow() }
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
            ListItem() {
              Text('已加载当前页面主题')
                .fontSize(Typography.CAPTION)
                .fontColor(SemanticColors.textTertiary())
                .width('100%').height(48).textAlign(TextAlign.Center)
            }
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
          const topicIndex = Math.max(0, start - 1 - (this.searchVisible ? 1 : 0));
          this.prefetchFrom(topicIndex);
        })
      }
      .width('100%').height('100%')
      .clip(false)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .pullToRefresh(true)
      .refreshOffset(64)
      .onRefreshing(() => this.load(true))

      if (this.visibleTopics.length > 0) {
        HomeFab({ onAction: () => this.showWriteUnavailable() })
          .margin({ right: Spacing.LG, bottom: Spacing.LG + this.bottomInset })
      }

      if (this.viewModel.state !== ViewLoadState.Content || this.visibleTopics.length === 0) {
        if (this.viewModel.state === ViewLoadState.Content && this.viewModel.presentationTopics.length > 0) {
          LoadStateView({
            state: ViewLoadState.Empty,
            title: '没有匹配的主题',
            detail: '调整筛选条件或清除搜索后再试。',
            semanticPrefix: 'home'
          })
            .padding({ top: immersiveTitleBarContentTopSpacer(this.topInset) })
        } else {
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
            .padding({ top: immersiveTitleBarContentTopSpacer(this.topInset) })
        }
      }
    }
    .id('home-page')
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
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

      if (this.drawerMounted) {
        Column()
          .width('100%').height('100%')
          .backgroundColor(SCRIM)
          .opacity(this.drawerProgress)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .onClick(() => this.closeDrawer())

        Column() {
          CategoryDrawer({
            categories: this.categories,
            selectedSort: this.draftSort,
            selectedCategoryId: this.draftCategoryId,
            appliedSort: this.appliedSort,
            appliedCategoryId: this.appliedCategoryId,
            showFeatured: this.hasFeatured(),
            onSortChange: (sort: HomeFeedSort) => { this.draftSort = sort; },
            onCategoryChange: (categoryId: number) => { this.draftCategoryId = categoryId; },
            onApply: () => this.applyDrawer(),
            onClose: () => this.closeDrawer()
          })
        }
        .width(PageMetrics.DRAWER_WIDTH).height('100%')
        .translate({ x: (this.drawerProgress - 1) * PageMetrics.DRAWER_WIDTH })
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionUpdate((event: GestureEvent) => {
              if (this.drawerOpen) {
                this.drawerProgress = this.clampProgress(1 + event.offsetX / PageMetrics.DRAWER_WIDTH);
              }
            })
            .onActionEnd((event: GestureEvent) => {
              this.settleDrawer(this.drawerProgress >= DRAWER_COMMIT_RATIO || event.velocityX >= DRAWER_COMMIT_VELOCITY);
            })
        )
      }
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down && event.touches.length > 0) {
        this.touchDownX = event.touches[0].windowX;
      }
    })
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 10 })
        .onActionStart((event: GestureEvent) => {
          if (!this.drawerMounted && event.offsetX > 0 && this.touchDownX >= 0 &&
            this.touchDownX <= PageMetrics.DRAWER_EDGE_WIDTH) {
            this.draftSort = this.appliedSort;
            this.draftCategoryId = this.appliedCategoryId;
            this.drawerMounted = true;
            this.drawerProgress = 0;
          }
        })
        .onActionUpdate((event: GestureEvent) => {
          if (this.drawerMounted && !this.drawerOpen && event.offsetX > 0) {
            this.drawerProgress = this.clampProgress(event.offsetX / PageMetrics.DRAWER_WIDTH);
          }
        })
        .onActionEnd((event: GestureEvent) => {
          if (this.drawerMounted && !this.drawerOpen) {
            this.settleDrawer(this.drawerProgress >= DRAWER_COMMIT_RATIO || event.velocityX >= DRAWER_COMMIT_VELOCITY);
          }
        })
    )
  }
}
