import { AppColors, Radius, SemanticColors, Typography } from '../../common/theme/DesignSystem';
import { UserUiModel } from '../../models/presentation/ForumUiModels';
import { TopicOpenTrace } from '../../services/logging/TopicOpenTrace';

@Component
export struct UserAvatar {
  user: UserUiModel = new UserUiModel();
  avatarSize: number = 48;
  semanticId: string = 'user-avatar';
  @State private imageFailed: boolean = false;

  @Builder
  private fallback() {
    Text(this.user.initial)
      .fontSize(Math.max(13, Math.round(this.avatarSize * 0.38)))
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
      if (this.user.avatarUrl.length > 0 && !this.imageFailed) {
        Image(this.user.avatarUrl)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .objectFit(ImageFit.Cover)
          .borderRadius(Radius.PILL)
          .draggable(false)
          .onAppear(() => TopicOpenTrace.markImageRequestsStart())
          .onError(() => {
            this.imageFailed = true;
          })
      } else {
        this.fallback()
      }
    }
    .id(this.semanticId)
    .width(this.avatarSize)
    .height(this.avatarSize)
    .accessibilityText(this.user.displayName.length > 0 ? `${this.user.displayName}的头像` : '用户头像')
  }
}
