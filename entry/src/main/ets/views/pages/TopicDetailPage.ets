import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { immersiveTitleBarContentTopSpacer } from '../../common/ui/ImmersiveTitleBarLayout';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { SYS_BOTTOM_INSET_KEY, SYS_TOP_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { ReplyUiModel, TopicDetailUiModel, TopicUiModel } from '../../models/presentation/ForumUiModels';
import { ReplyAccess } from '../../models/TopicModels';
import { TopicOpenTrace } from '../../services/logging/TopicOpenTrace';
import { TopicDetailViewModel } from '../../viewmodels/TopicDetailViewModel';
import { ViewLoadState } from '../../viewmodels/ViewState';
import { CommentInputBar } from '../components/CommentInputBar';
import { LoadStateView } from '../components/LoadStateView';
import { LoginRequiredCard } from '../components/LoginRequiredCard';
import { TopicDetailHeader } from '../components/TopicDetailHeader';
import { TopicPostItem } from '../components/TopicPostItem';
import { TopicSummaryCard } from '../components/TopicSummaryCard';

@Component
export struct TopicDetailPage {
  @ObjectLink viewModel: TopicDetailViewModel;
  topicId: number = 0;
  summary: TopicUiModel | undefined = undefined;
  onBack: () => void = () => {};
  onLogin: () => void = () => {};
  @StorageProp(SYS_TOP_INSET_KEY) private topInset: number = 0;
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;
  @State private summaryVisible: boolean = true;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    TopicOpenTrace.markDestinationAppear();
    this.summaryVisible = true;
    if (this.topicId > 0) {
      this.viewModel.open(this.topicId, this.summary);
    }
  }

  private displayTitle(): string {
    if (this.viewModel.presentationDetail !== undefined) {
      return this.viewModel.presentationDetail.title;
    }
    return this.summary?.title ?? '主题详情';
  }

  private displayCategory(): string {
    return this.summary?.category.name ?? '';
  }

  private showWriteUnavailable(): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: '回复功能尚未开放', duration: 1800 });
    } catch (_) {}
  }

  private scrollToSummary(): void {
    this.scroller.scrollToIndex(0, true, ScrollAlign.START);
  }

  @Builder
  private titleBarContent() {
    TopicDetailHeader({
      summaryVisible: this.summaryVisible,
      title: this.displayTitle(),
      categoryName: this.displayCategory(),
      onTitleClick: () => this.scrollToSummary()
    })
  }

  @Builder
  private replySectionHeader(detail: TopicDetailUiModel) {
    Row() {
      Text(`${detail.loadedReplyCount} / ${detail.advertisedReplyCount} 条回复`)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .layoutWeight(1)
      if (detail.totalPages > 1) {
        Text(`第 ${detail.currentPage} / ${detail.totalPages} 页`)
          .fontSize(12)
          .fontColor(SemanticColors.textSecondary())
      }
    }
    .id('topic-reply-summary')
    .width('100%')
    .padding({ left: 10, right: 10, top: 16, bottom: 8 })
    .backgroundColor(SemanticColors.page())
  }

  @Builder
  private loadMoreState(detail: TopicDetailUiModel) {
    if (this.viewModel.loadingMore) {
      Row({ space: 8 }) {
        LoadingProgress().width(18).height(18).color(SemanticColors.textSecondary())
        Text('正在加载下一页')
          .fontSize(13)
          .fontColor(SemanticColors.textSecondary())
      }
      .id('topic-load-more')
      .width('100%')
      .height(52)
      .justifyContent(FlexAlign.Center)
    } else if (this.viewModel.loadMoreError.length > 0) {
      Button('下一页加载失败，点击重试')
        .id('topic-load-more-retry')
        .height(48)
        .fontSize(13)
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor(Color.Transparent)
        .onClick(() => this.viewModel.retryLoadMore())
    } else if (detail.nextPageUrl.length > 0 || this.viewModel.mountedReplyCount < detail.replies.length) {
      Button('继续向下加载')
        .id('topic-load-more-batch')
        .fontSize(12)
        .fontColor(SemanticColors.textTertiary())
        .width('100%')
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.viewModel.onReplyListReachEnd())
    }
  }

  @Builder
  private detailContent(detail: TopicDetailUiModel) {
    List({ scroller: this.scroller }) {
      ListItem() {
        Row().width('100%').height(immersiveTitleBarContentTopSpacer(this.topInset))
      }
      ListItem() {
        TopicSummaryCard({ detail: detail, summary: this.summary })
      }
      ListItem() {
        TopicPostItem({ post: detail.mainPost, mainPost: true })
      }
      if (detail.replyAccess === ReplyAccess.LoginRequired) {
        ListItem() {
          LoginRequiredCard({
            replyCount: detail.advertisedReplyCount,
            onLogin: () => this.onLogin()
          })
            .margin({ left: 10, right: 10, top: 12, bottom: 12 })
        }
      } else if (detail.advertisedReplyCount === 0) {
        ListItem() {
          Text('暂无回复')
            .fontSize(14)
            .fontColor(SemanticColors.textSecondary())
            .width('100%')
            .height(72)
            .textAlign(TextAlign.Center)
        }
      } else {
        ListItem() { this.replySectionHeader(detail) }
        ForEach(this.viewModel.visibleReplies(), (reply: ReplyUiModel) => {
          ListItem() {
            TopicPostItem({ post: reply, mainPost: false })
          }
        }, (reply: ReplyUiModel) => reply.postId.toString())
        ListItem() { this.loadMoreState(detail) }
      }
      ListItem() {
        Row().width('100%').height(PageMetrics.REPLY_BAR_HEIGHT + this.bottomInset + 16)
      }
    }
    .id('topic-post-list')
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onScrollIndex((start: number, end: number) => {
      this.summaryVisible = start <= 1;
      this.viewModel.onReplyListViewport(end);
    })
    .onAppear(() => TopicOpenTrace.markFirstContentFrame())
  }

  @Builder
  private skeleton() {
    List({ scroller: this.scroller }) {
      ListItem() {
        Row().width('100%').height(immersiveTitleBarContentTopSpacer(this.topInset))
      }
      ListItem() {
        Column({ space: 12 }) {
          Text(this.displayTitle())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.textPrimary())
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Row().width('45%').height(12).borderRadius(6).backgroundColor(SemanticColors.skeleton())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 10, right: 10, top: 20, bottom: 16 })
        .border({ width: { bottom: 1 }, color: SemanticColors.divider() })
        .backgroundColor(SemanticColors.surface())
      }
      ListItem() {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            Row().width(40).height(40).borderRadius(20).backgroundColor(SemanticColors.skeleton())
            Column({ space: 7 }) {
              Row().width('38%').height(13).borderRadius(6).backgroundColor(SemanticColors.skeleton())
              Row().width('22%').height(10).borderRadius(5).backgroundColor(SemanticColors.skeleton())
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
          Row().width('100%').height(15).borderRadius(6).backgroundColor(SemanticColors.skeleton())
          Row().width('92%').height(15).borderRadius(6).backgroundColor(SemanticColors.skeleton())
          Row().width('76%').height(15).borderRadius(6).backgroundColor(SemanticColors.skeleton())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 10, right: 10, top: 12, bottom: 20 })
        .backgroundColor(SemanticColors.surface())
      }
    }
    .id('topic-skeleton')
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .onAppear(() => TopicOpenTrace.markSkeletonFrame())
  }

  @Builder
  private mainContent() {
    if ((this.viewModel.state === ViewLoadState.Loading || this.viewModel.state === ViewLoadState.Idle) &&
      this.viewModel.presentationDetail === undefined) {
      this.skeleton()
    } else if (this.viewModel.state === ViewLoadState.Offline) {
      LoadStateView({
        state: ViewLoadState.Offline,
        title: '当前无法联网',
        detail: '请检查网络连接后重试。',
        semanticPrefix: 'topic',
        onRetry: () => this.viewModel.retry()
      }).padding({ top: immersiveTitleBarContentTopSpacer(this.topInset) })
    } else if (this.viewModel.state === ViewLoadState.Error || this.viewModel.presentationDetail === undefined) {
      LoadStateView({
        state: ViewLoadState.Error,
        title: '主题加载失败',
        detail: '服务响应暂时无法转换为稳定主题结构。',
        semanticPrefix: 'topic',
        onRetry: () => this.viewModel.retry()
      }).padding({ top: immersiveTitleBarContentTopSpacer(this.topInset) })
    } else {
      this.detailContent(this.viewModel.presentationDetail)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      this.mainContent()
      HdsNavigation() {
        Column().width('100%').height('100%')
      }
      .titleBar({
        avoidLayoutSafeArea: requiresHdsLayoutSafeAreaAvoidance(ImmersiveLightArea.TITLE_BAR),
        enableComponentSafeArea: requiresHdsComponentSafeArea(ImmersiveLightArea.TITLE_BAR),
        style: buildImmersiveTitleBarStyle(),
        content: {
          backIcon: {
            icon: $r('sys.symbol.chevron_left'),
            label: '返回',
            action: () => this.onBack()
          },
          stackBuilder: () => { this.titleBarContent(); }
        }
      })
      .bindToScrollable([this.scroller])
      .titleMode(HdsNavigationTitleMode.MINI)
      .mode(NavigationMode.Stack)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.Transparent)
      CommentInputBar({ onUnavailable: () => this.showWriteUnavailable() })
    }
    .id('topic-detail-page')
    .width('100%')
    .height('100%')
    .backgroundColor(SemanticColors.page())
  }
}
