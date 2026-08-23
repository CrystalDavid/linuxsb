import { SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { PostUiModel } from '../../models/presentation/ForumUiModels';
import { PostRichContent } from './PostRichContent';
import { UserAvatar } from './UserAvatar';

@Component
export struct TopicPostItem {
  post: PostUiModel = new PostUiModel();
  mainPost: boolean = false;

  private authorName(): string {
    return this.post.author.displayName.length > 0 ? this.post.author.displayName : '社区用户';
  }

  build() {
    Column() {
      Row() {
        UserAvatar({
          user: this.post.author,
          avatarSize: 36,
          semanticId: `post-avatar-${this.post.postId}`
        })
          .margin({ right: Spacing.SM })
        Column({ space: 2 }) {
          Text(this.authorName())
            .fontSize(Typography.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textPrimary())
            .maxLines(1)
          Text(this.mainPost ? '楼主' : `#${this.post.floor}`)
            .fontSize(Typography.LABEL_SMALL)
            .fontColor(SemanticColors.textSecondary())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      PostRichContent({ blocks: this.post.content })
        .width('100%')
        .margin({ top: Spacing.MD })
    }
    .id(this.mainPost ? 'topic-main-post' : `topic-reply-${this.post.floor}`)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.LG, bottom: Spacing.LG })
    .backgroundColor(SemanticColors.surface())
  }
}
