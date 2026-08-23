import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../common/theme/AppTheme';
import { Reply, ReplyAccess, TopicDetail } from '../../models/TopicModels';
import { TopicDetailViewModel } from '../../viewmodels/TopicDetailViewModel';
import { ViewLoadState } from '../../viewmodels/ViewState';
import { ContentBlockRenderer } from '../components/ContentBlockRenderer';
import { LoginRequiredCard } from '../components/LoginRequiredCard';

@Component
export struct TopicDetailPage {
  @ObjectLink viewModel: TopicDetailViewModel;
  topicId: number = 0;
  onLogin: () => void = () => {};

  aboutToAppear(): void {
    if (this.topicId > 0 && (this.viewModel.topicId !== this.topicId || this.viewModel.detail === undefined)) {
      this.viewModel.load(this.topicId);
    }
  }

  @Builder
  private stateMessage(title: string, detail: string) {
    Column({ space: AppSpacing.SM }) {
      Text(title)
        .fontSize(AppTypography.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(detail)
        .fontSize(AppTypography.BODY)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Button('重试')
        .onClick(() => this.viewModel.retry())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(AppSpacing.XL)
  }

  @Builder
  private mainPost(detail: TopicDetail) {
    Column({ space: AppSpacing.MD }) {
      Column({ space: AppSpacing.XS }) {
        Text(detail.title)
          .fontSize(AppTypography.DISPLAY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Row({ space: AppSpacing.SM }) {
          Text(detail.mainPost.author.displayName)
            .fontSize(AppTypography.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(`主题 #${detail.topicId}`)
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_tertiary'))
          Text(`${detail.viewCount} 次浏览`)
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      ContentBlockRenderer({ blocks: detail.mainPost.content })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border') })
  }

  @Builder
  private replyCard(reply: Reply) {
    Column({ space: AppSpacing.MD }) {
      Row({ space: AppSpacing.SM }) {
        Text(reply.author.displayName)
          .fontSize(AppTypography.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(`#${reply.floor}`)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.primary'))
      }
      .width('100%')

      ContentBlockRenderer({ blocks: reply.content })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border') })
  }

  @Builder
  private content(detail: TopicDetail) {
    Scroll() {
      Column({ space: AppSpacing.MD }) {
        this.mainPost(detail)

        if (detail.replyAccess === ReplyAccess.LoginRequired) {
          LoginRequiredCard({
            replyCount: detail.advertisedReplyCount,
            onLogin: () => this.onLogin()
          })
        } else if (detail.replies.length > 0) {
          Row() {
            Text(`${detail.replies.length} 条回复`)
              .fontSize(AppTypography.TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .width('100%')
          .padding({ top: AppSpacing.XS })

          ForEach(detail.replies, (reply: Reply) => {
            this.replyCard(reply)
          }, (reply: Reply) => reply.replyId.toString())
        }

        if (this.viewModel.loginError.length > 0) {
          Text(this.viewModel.loginError)
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.error'))
            .width('100%')
            .padding(AppSpacing.SM)
            .backgroundColor($r('app.color.error_soft'))
            .borderRadius(AppRadius.SM)
        }
      }
      .width('100%')
      .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.MD, bottom: AppSpacing.XXL })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      if (this.viewModel.state === ViewLoadState.Loading || this.viewModel.state === ViewLoadState.Idle) {
        Column({ space: AppSpacing.SM }) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color($r('app.color.primary'))
          Text('正在加载主题…')
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.viewModel.state === ViewLoadState.Offline) {
        this.stateMessage('当前无法联网', '请检查网络连接后重试。')
      } else if (this.viewModel.state === ViewLoadState.Error || this.viewModel.detail === undefined) {
        this.stateMessage('主题加载失败', '服务响应无法转换为稳定的主题结构。')
      } else {
        this.content(this.viewModel.detail)
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppLayout.DETAIL_CONTENT_MAX })
    .backgroundColor($r('app.color.page_background'))
  }
}
