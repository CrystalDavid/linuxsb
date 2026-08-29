import { AppColors, Radius, SemanticColors, Typography } from '../../common/theme/DesignSystem';
import { UserUiModel } from '../../models/presentation/ForumUiModels';
import { TopicOpenTrace } from '../../services/logging/TopicOpenTrace';

@Component
export struct UserAvatar {
  user: UserUiModel = new UserUiModel();
  avatarSize: number = 48;
  semanticId: string = 'user-avatar';
  // Lazy lists recycle this component. Remember the URL that failed instead of
  // a permanent boolean, otherwise a recycled row suppresses the next user's
  // perfectly valid avatar as well.
  @State private failedAvatarUrl: string = '';

  private initialFontSize(): number {
    if (this.avatarSize >= 60) {
      return Typography.HEADLINE;
    }
    if (this.avatarSize >= 44) {
      return Typography.SECTION_TITLE;
    }
    return this.avatarSize >= 34 ? Typography.BODY_SMALL : Typography.METADATA;
  }

  @Builder
  private fallback() {
    Text(this.user.initial)
      .fontSize(this.initialFontSize())
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.brandPrimary())
      .width(this.avatarSize)
      .height(this.avatarSize)
      .textAlign(TextAlign.Center)
      .backgroundColor(SemanticColors.avatarBackground())
      .borderRadius(Radius.PILL)
  }

  build() {
    Stack() {
      this.fallback()
      if (this.user.avatarUrl.length > 0 && this.user.avatarUrl !== this.failedAvatarUrl) {
        Image(this.user.avatarUrl)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .sourceSize({ width: this.avatarSize, height: this.avatarSize })
          .syncLoad(false)
          .objectFit(ImageFit.Cover)
          .borderRadius(Radius.PILL)
          .draggable(false)
          .onAppear(() => TopicOpenTrace.markImageRequestsStart())
          .onError(() => {
            this.failedAvatarUrl = this.user.avatarUrl;
          })
      }
    }
    .id(this.semanticId)
    .width(this.avatarSize)
    .height(this.avatarSize)
    .accessibilityText(this.user.displayName.length > 0 ? `${this.user.displayName}的头像` : '用户头像')
  }
}
