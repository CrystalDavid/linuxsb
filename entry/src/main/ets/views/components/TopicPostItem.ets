import { AppColors, Radius, SemanticColors } from '../../common/theme/DesignSystem';
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

  private isThreadedReply(): boolean {
    return !this.mainPost && this.post.parentFloor > 0;
  }

  private threadInset(): number {
    return this.isThreadedReply() ? Math.min(2, Math.max(1, this.post.threadDepth)) * 12 : 0;
  }

  @Builder
  private threadMarker() {
    if (this.isThreadedReply()) {
      Row({ space: 5 }) {
        Text('↳')
          .fontSize(13)
          .fontColor(AppColors.brandPrimary())
        Text(`楼中楼 · 回复 #${this.post.parentFloor}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.brandPrimary())
      }
      .id(`reply-thread-indicator-${this.post.floor}`)
      .alignSelf(ItemAlign.Start)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .margin({ bottom: 8 })
      .borderRadius(Radius.PILL)
      .backgroundColor(AppColors.brandSoft())
    }
  }

  @Builder
  private postBody() {
    Column() {
      this.threadMarker()

      Row() {
        UserAvatar({
          user: this.post.author,
          avatarSize: 40,
          semanticId: `post-avatar-${this.post.postId}`
        })
          .margin({ right: 12 })
        Column({ space: 2 }) {
          Text(this.authorName())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textPrimary())
            .maxLines(1)
          Text(this.postMetaLabel())
            .fontSize(13)
            .fontColor(SemanticColors.textSecondary())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      PostRichContent({ blocks: this.post.content, semanticPrefix: `post-content-${this.post.postId}` })
        .width('100%')
        .margin({ top: 12 })

      if (this.post.editedMetadata !== undefined) {
        Text(this.editedLabel())
          .fontSize(12)
          .fontColor(SemanticColors.textTertiary())
          .width('100%')
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 10 + this.threadInset(), right: 10, top: 12, bottom: 14 })
    .border({ width: { left: this.isThreadedReply() ? 3 : 0 }, color: AppColors.brandPrimary() })
    .backgroundColor(this.isThreadedReply() ? SemanticColors.surfaceMuted() : SemanticColors.surface())
  }

  build() {
    Column() {
      this.postBody()
      Divider().strokeWidth(0.5).color(SemanticColors.divider())
    }
    .id(this.mainPost ? 'topic-main-post' : `topic-reply-${this.post.floor}`)
    .width('100%')
    .backgroundColor(SemanticColors.surface())
  }

  private editedLabel(): string {
    const metadata = this.post.editedMetadata;
    if (metadata === undefined) {
      return '';
    }
    if (metadata.editorName.length > 0) {
      return `最后由 ${metadata.editorName} 编辑于 ${metadata.editedAt}`;
    }
    return metadata.editedAt;
  }

  private postMetaLabel(): string {
    const role = this.mainPost ? '楼主' : `#${this.post.floor} 楼`;
    const time = this.post.postedAtLabel.length > 0 ? ` · ${this.post.postedAtLabel}` : '';
    return `${role}${time}`;
  }
}
