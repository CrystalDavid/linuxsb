import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { ForumVisuals } from '../../common/theme/ForumVisuals';
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
import {
  CompactSegmentedControl,
  SegmentOption,
  TITLE_BAR_SEGMENT_HEIGHT,
  TITLE_BAR_SEGMENT_LABEL_SIZE,
  TITLE_BAR_SEGMENT_WIDTH
} from '../components/CompactSegmentedControl';
import {
  ImmersiveIconButton,
  TITLE_BAR_BACK_ICON_SIZE,
  TITLE_BAR_BACK_ICON_WEIGHT
} from '../components/ImmersiveIconButton';
import { PaginatedTopicList } from '../components/PaginatedTopicList';

@Component({ freezeWhenInactive: true })
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
    const discovered = (this.viewModel.forums ?? []).slice();
    const directoryForums = discovered.filter((forum: ForumSummary) =>
      (forum.topicCount ?? -1) >= 0 || (forum.description ?? '').length > 0 || (forum.colorHex ?? '').length > 0);
    // The BBS page also repeats recently visited/topic category links. They are
    // useful as topic metadata, but only the enriched directory entries are
    // stable public board destinations. Fall back only if an older BBS1 theme
    // omits the directory metadata entirely.
    this.forums = directoryForums.length > 0 ? directoryForums : discovered;
  }

  private selectForum(forumId: number): void {
    if (forumId <= 0 || (forumId === this.selectedForumId && this.viewModel.state !== ViewLoadState.Idle)) {
      return;
    }
    this.selectedForumId = forumId;
    this.viewModel.configure(HomeFeedRequest.forum(forumId, this.selectedSort));
    // Navigation must complete before the board request. Keeping the click
    // callback synchronous avoids TestKit and the user gesture waiting on a
    // slow network response before the native board screen can render.
    this.load(false);
  }

  private showForumDirectory(): void {
    this.selectedForumId = 0;
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

  private selectedForumName(): string {
    return this.forums.find((forum: ForumSummary) => forum.forumId === this.selectedForumId)?.name ?? '板块';
  }

  private sortOptions(): SegmentOption[] {
    return [
      new SegmentOption('新评论', 'forums-sort-comments'),
      new SegmentOption('新帖子', 'forums-sort-topics')
    ];
  }

  @Builder
  private forumRow(forum: ForumSummary, first: boolean) {
    Column() {
      Row({ space: Spacing.MD }) {
        Row()
          .width(16).height(16)
          .backgroundColor(ForumVisuals.accent(forum.forumId, forum.colorHex ?? ''))
          .borderRadius(4)

        Column({ space: 2 }) {
          Text(forum.name)
            .id(first ? 'forum-first-title' : `forum-title-${forum.forumId}`)
            .fontSize(Typography.TOPIC_TITLE)
            .fontWeight(500)
            .fontColor(SemanticColors.textPrimary())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(ForumVisuals.description(forum.forumId, forum.description ?? ''))
            .fontSize(Typography.CAPTION)
            .fontColor(SemanticColors.textTertiary())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

        if ((forum.topicCount ?? -1) >= 0) {
          Text((forum.topicCount ?? 0).toString())
            .fontSize(Typography.CAPTION)
            .fontColor(SemanticColors.textTertiary())
            .maxLines(1)
        }

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([SemanticColors.textTertiary()])
      }
      .id(first ? 'forum-first-row' : `forum-${forum.forumId}`)
      .accessibilityText(`${forum.name}板块${(forum.topicCount ?? -1) >= 0 ? `，${forum.topicCount}个主题` : ''}`)
      .width('100%')
      .height(64)
      .padding({ left: Spacing.LG, right: Spacing.LG })
      .alignItems(VerticalAlign.Center)
      .onClick(() => this.selectForum(forum.forumId))

      Divider()
        .strokeWidth(0.5)
        .color(SemanticColors.divider())
        .margin({ left: Spacing.LG + 16 + Spacing.MD, right: Spacing.LG })
    }
    .width('100%')
  }

  @Builder
  private titleBar() {
    Row({ space: Spacing.SM }) {
      if (this.selectedForumId > 0) {
        ImmersiveIconButton({
          icon: $r('sys.symbol.chevron_left'),
          semanticId: 'forums-back',
          semanticLabel: '返回板块目录',
          iconSize: TITLE_BAR_BACK_ICON_SIZE,
          iconWeight: TITLE_BAR_BACK_ICON_WEIGHT,
          onAction: () => this.showForumDirectory()
        })
      }
      Text(this.selectedForumId > 0 ? this.selectedForumName() : '板块')
        .id('forums-page-title')
        .fontSize(Typography.PAGE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (this.selectedForumId > 0) {
        CompactSegmentedControl({
          options: this.sortOptions(),
          selectedIndex: this.selectedSort === FeedSort.NewComments ? 0 : 1,
          segmentWidth: TITLE_BAR_SEGMENT_WIDTH,
          controlHeight: TITLE_BAR_SEGMENT_HEIGHT,
          labelFontSize: TITLE_BAR_SEGMENT_LABEL_SIZE,
          semanticId: 'forums-sort-control',
          onSelect: (index: number) => this.changeSort(index === 0 ? FeedSort.NewComments : FeedSort.NewTopics)
        })
          .translate({ y: -2 })
      }
    }
    .width('100%').height('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private forumDirectory() {
    if (this.forums.length > 0) {
      List() {
        ForEach(this.forums, (forum: ForumSummary, index: number) => {
          ListItem() { this.forumRow(forum, index === 0) }
        }, (forum: ForumSummary) => forum.forumId.toString())
        ListItem() { Column().height(this.bottomContentInset) }
      }
      .id('forum-directory')
      .width('100%')
      .height(`calc(100% + ${Spacing.MD}vp)`)
      .position({ x: 0, y: -Spacing.MD })
      .scrollBar(BarState.Off)
    } else if (this.viewModel.state === ViewLoadState.Loading || this.viewModel.state === ViewLoadState.Idle) {
      Column({ space: Spacing.SM }) {
        LoadingProgress().width(28).height(28).color($r('app.color.brand_primary'))
        Text('正在读取板块').fontSize(Typography.BODY).fontColor(SemanticColors.textSecondary())
      }
      .width('100%').height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: this.bottomContentInset })
    } else {
      Column({ space: Spacing.MD }) {
        Text('暂时无法读取板块').fontSize(Typography.BODY).fontColor(SemanticColors.textSecondary())
        Button('重试', { type: ButtonType.Capsule, stateEffect: true }).onClick(() => this.load(false))
      }
      .width('100%').height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: this.bottomContentInset })
    }
  }

  @Builder
  private forumTopics() {
    PaginatedTopicList({
      viewModel: this.viewModel,
      bottomInset: this.bottomContentInset,
      semanticPrefix: 'forums',
      emptyTitle: '这个板块还没有主题',
      emphasizeTopicTitle: true,
      onTopicSelected: (topic: TopicUiModel) => this.onTopicSelected(topic),
      onRetry: () => this.load(false)
    })
    .width('100%').height('100%')
  }

  build() {
    HdsNavigation() {
      Column() {
        if (this.selectedForumId === 0) {
          this.forumDirectory()
        } else {
          this.forumTopics()
        }
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
