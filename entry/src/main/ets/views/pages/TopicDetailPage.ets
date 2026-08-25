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
import { PostUiModel, ReplyUiModel, TopicDetailUiModel, TopicUiModel } from '../../models/presentation/ForumUiModels';
import { ReplyAccess } from '../../models/TopicModels';
import { TopicOpenTrace } from '../../services/logging/TopicOpenTrace';
import { WriteResult } from '../../services/repository/WriteRepository';
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
  @Prop authenticated: boolean = false;
  onBack: () => void = () => {};
  onLogin: () => void = () => {};
  onReply: (body: string) => Promise<WriteResult> =
    async () => ({ ok: false, topicId: 0, message: '回复服务不可用', networkMs: 0 });
  @StorageProp(SYS_TOP_INSET_KEY) private topInset: number = 0;
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;
  @State private summaryVisible: boolean = true;
  @State private replyDraft: string = '';
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

  private scrollToSummary(): void {
    this.scroller.scrollToIndex(0, true, ScrollAlign.START);
  }

  private requestReplyTo(post: PostUiModel): void {
    const name = post.author.displayName.trim();
    this.replyDraft = name.length > 0 ? `@${name} #${post.floor} ` : `#${post.floor} `;
    try {
      focusControl.requestFocus('topic-reply-input');
    } catch (_) {}
  }

  private async submitReply(body: string): Promise<WriteResult> {
    return this.onReply(body);
  }

  private async handleReplySubmitted(): Promise<void> {
    await this.viewModel.refreshAfterWrite();
    try {
      this.getUIContext().getPromptAction().showToast({ message: '回复已发表', duration: 1500 });
    } catch (_) {}
  }

  @Builder
  private titleBarContent() {
    TopicDetailHeader({
      summaryVisible: this.summaryVisible,
      title: this.displayTitle(),
      categoryName: this.displayCategory(),
      onBack: () => this.onBack(),
      onTitleClick: () => this.scrollToSummary()
    })
  }

  @Builder
  private replySectionHeader(detail: TopicDetailUiModel) {
    Row() {
      Text('回复')
        .fontSize(Typography.BODY_LARGE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .layoutWeight(1)
      Text(`${detail.loadedReplyCount} / ${detail.advertisedReplyCount}`)
        .fontSize(Typography.CAPTION)
        .fontColor(SemanticColors.textSecondary())
    }
    .id('topic-reply-summary')
    .width('100%')
    .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.LG, bottom: Spacing.SM })
    .backgroundColor(Color.Transparent)
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
            errorMessage: this.viewModel.loginError,
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
            TopicPostItem({
              post: reply,
              mainPost: false,
              onReply: (post: PostUiModel) => this.requestReplyTo(post)
            })
          }
        }, (reply: ReplyUiModel) => reply.postId.toString())
        ListItem() { this.loadMoreState(detail) }
          .onAppear(() => this.viewModel.onReplyListReachEnd())
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
    .onReachEnd(() => this.viewModel.onReplyListReachEnd())
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
        .padding({ left: 10, right: 10, top: Spacing.XXS, bottom: 16 })
        .backgroundColor(Color.Transparent)
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
        .backgroundColor(Color.Transparent)
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
          stackBuilder: () => { this.titleBarContent(); }
        }
      })
      .bindToScrollable([this.scroller])
      .titleMode(HdsNavigationTitleMode.MINI)
      .mode(NavigationMode.Stack)
      .hideBackButton(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.Transparent)
      CommentInputBar({
        draft: $replyDraft,
        authenticated: this.authenticated,
        onLogin: () => this.onLogin(),
        onSubmit: (body: string) => this.submitReply(body),
        onSubmitted: () => this.handleReplySubmitted()
      })
    }
    .id('topic-detail-page')
    .width('100%')
    .height('100%')
    .backgroundColor(SemanticColors.page())
  }
}
