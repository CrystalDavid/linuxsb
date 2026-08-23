import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { AppColors, PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
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

@Component
export struct TopicDetailPage {
  @ObjectLink viewModel: TopicDetailViewModel;
  topicId: number = 0;
  summary: TopicUiModel | undefined = undefined;
  onBack: () => void = () => {};
  onLogin: () => void = () => {};
  @StorageProp(SYS_TOP_INSET_KEY) private topInset: number = 0;
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    TopicOpenTrace.markDestinationAppear();
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
      this.getUIContext().getPromptAction().showToast({ message: '写操作尚未开放', duration: 1800 });
    } catch (_) {}
  }

  @Builder
  private titleBarContent() {
    TopicDetailHeader({ title: this.displayTitle(), categoryName: this.displayCategory() })
  }

  @Builder
  private topicIntro(detail: TopicDetailUiModel) {
    Column({ space: Spacing.SM }) {
      Text(detail.title)
        .fontSize(Typography.HEADLINE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .lineHeight(31)
        .width('100%')
      Row({ space: Spacing.MD }) {
        if (this.displayCategory().length > 0) {
          Text(this.displayCategory())
            .fontSize(Typography.CAPTION)
            .fontColor(AppColors.brandPrimary())
            .padding({ left: Spacing.SM, right: Spacing.SM, top: 3, bottom: 3 })
            .backgroundColor(AppColors.brandSoft())
            .borderRadius(Radius.XS)
        }
        Text(`${detail.viewCount} 次浏览`)
          .fontSize(Typography.CAPTION)
          .fontColor(SemanticColors.textSecondary())
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.LG, bottom: Spacing.MD })
    .backgroundColor(SemanticColors.surface())
  }

  @Builder
  private detailContent(detail: TopicDetailUiModel) {
    List({ scroller: this.scroller }) {
      ListItem() {
        Row() {
          Blank()
        }
        .width('100%')
        .height(immersiveTitleBarContentTopSpacer(this.topInset))
      }
      ListItem() { this.topicIntro(detail) }
      ListItem() {
        TopicPostItem({ post: detail.mainPost, mainPost: true })
      }
      if (detail.replyAccess === ReplyAccess.LoginRequired) {
        ListItem() {
          LoginRequiredCard({
            replyCount: detail.advertisedReplyCount,
            onLogin: () => this.onLogin()
          })
            .margin({ left: Spacing.MD, right: Spacing.MD, top: Spacing.MD, bottom: Spacing.MD })
        }
      } else if (detail.replies.length > 0) {
        ListItem() {
          Row() {
            Text(`${detail.replies.length} 条回复`)
              .fontSize(Typography.TITLE_SMALL)
              .fontWeight(FontWeight.Bold)
              .fontColor(SemanticColors.textPrimary())
          }
          .width('100%')
          .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.LG, bottom: Spacing.SM })
          .backgroundColor(SemanticColors.page())
        }
        ForEach(detail.replies, (reply: ReplyUiModel) => {
          ListItem() {
            Column() {
              TopicPostItem({ post: reply, mainPost: false })
              Divider().color(SemanticColors.divider()).margin({ left: Spacing.MD, right: Spacing.MD })
            }
          }
        }, (reply: ReplyUiModel) => reply.postId.toString())
      }
      ListItem() {
        Row() {
          Blank()
        }
        .width('100%')
        .height(PageMetrics.REPLY_BAR_HEIGHT + this.bottomInset + Spacing.LG)
      }
    }
    .id('topic-post-list')
    .width('100%').height('100%')
    .scrollBar(BarState.Off)
    .onAppear(() => TopicOpenTrace.markFirstContentFrame())
  }

  @Builder
  private skeleton() {
    List({ scroller: this.scroller }) {
      ListItem() {
        Row() {
          Blank()
        }
        .width('100%')
        .height(immersiveTitleBarContentTopSpacer(this.topInset))
      }
      ListItem() {
        Column({ space: Spacing.MD }) {
          Text(this.displayTitle())
            .fontSize(Typography.HEADLINE)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.textPrimary())
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Row({ space: Spacing.SM }) {
            Row().width(36).height(36).borderRadius(Radius.PILL).backgroundColor(SemanticColors.skeleton())
            Column({ space: Spacing.SM }) {
              Row().width('38%').height(13).borderRadius(Radius.XS).backgroundColor(SemanticColors.skeleton())
              Row().width('22%').height(10).borderRadius(Radius.XS).backgroundColor(SemanticColors.skeleton())
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
          Row().width('100%').height(16).borderRadius(Radius.XS).backgroundColor(SemanticColors.skeleton())
          Row().width('92%').height(16).borderRadius(Radius.XS).backgroundColor(SemanticColors.skeleton())
          Row().width('76%').height(16).borderRadius(Radius.XS).backgroundColor(SemanticColors.skeleton())
          Row().width('84%').height(16).borderRadius(Radius.XS).backgroundColor(SemanticColors.skeleton())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.LG, bottom: Spacing.XL })
        .backgroundColor(SemanticColors.surface())
      }
    }
    .id('topic-skeleton')
    .width('100%').height('100%')
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
      .width('100%').height('100%')
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.Transparent)

      CommentInputBar({ onUnavailable: () => this.showWriteUnavailable() })
    }
    .id('topic-detail-page')
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }
}
