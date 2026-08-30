import { image } from '@kit.ImageKit';
import { AppColors, Radius, SemanticColors, Typography } from '../../common/theme/DesignSystem';
import { UserUiModel } from '../../models/presentation/ForumUiModels';
import { arkWebForumBridge } from '../../services/auth/ArkWebForumBridge';
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
  @State private avatarPixelMap: image.PixelMap | undefined = undefined;
  @State private bridgedAvatarUrl: string = '';
  @State private nativeFallbackAvatarUrl: string = '';
  private loadingAvatarUrl: string = '';
  private recoveryRetryTimer: number = -1;
  private unsubscribeRecovery: (() => void) | undefined = undefined;

  aboutToAppear(): void {
    this.unsubscribeRecovery = arkWebForumBridge.subscribeRecovered(() => this.retryAfterRecovery());
  }

  aboutToDisappear(): void {
    if (this.unsubscribeRecovery !== undefined) {
      this.unsubscribeRecovery();
      this.unsubscribeRecovery = undefined;
    }
    if (this.recoveryRetryTimer >= 0) {
      clearTimeout(this.recoveryRetryTimer);
      this.recoveryRetryTimer = -1;
    }
  }

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

  private needsBrowserBridge(url: string): boolean {
    return url === 'https://linux.sb' || url.startsWith('https://linux.sb/');
  }

  private async prepareBridgedAvatar(): Promise<void> {
    const url = this.user.avatarUrl;
    if (!this.needsBrowserBridge(url) || url === this.failedAvatarUrl || url === this.bridgedAvatarUrl ||
      url === this.loadingAvatarUrl) {
      return;
    }
    const cached = arkWebForumBridge.getCachedAvatar(url);
    if (cached !== undefined) {
      this.avatarPixelMap = cached;
      this.bridgedAvatarUrl = url;
      return;
    }
    this.loadingAvatarUrl = url;
    TopicOpenTrace.markImageRequestsStart();
    const pixelMap = await arkWebForumBridge.loadAvatar(url);
    if (this.loadingAvatarUrl === url) {
      this.loadingAvatarUrl = '';
    }
    // A lazy row may have been recycled while the asynchronous fetch was in
    // flight. Never bind the previous user's PixelMap to the new row.
    if (this.user.avatarUrl !== url) {
      return;
    }
    if (pixelMap !== undefined) {
      this.avatarPixelMap = pixelMap;
      this.bridgedAvatarUrl = url;
    } else {
      // A same-origin URL can redirect to a CDN which does not expose CORS
      // headers. The Web bridge then cannot read the bytes, while ArkUI Image
      // can still follow that redirect. ArkDO uses the same bridge-to-native
      // fallback instead of permanently replacing a valid avatar with initials.
      this.nativeFallbackAvatarUrl = url;
    }
  }

  private retryAfterRecovery(): void {
    if (!this.needsBrowserBridge(this.user.avatarUrl)) {
      return;
    }
    this.failedAvatarUrl = '';
    this.nativeFallbackAvatarUrl = '';
    this.loadingAvatarUrl = '';
    if (this.recoveryRetryTimer >= 0) {
      clearTimeout(this.recoveryRetryTimer);
    }
    // Let requests aborted by the host navigation leave the global inflight
    // map, then refill visible rows through the bounded queue.
    this.recoveryRetryTimer = setTimeout(() => {
      this.recoveryRetryTimer = -1;
      this.prepareBridgedAvatar();
    }, 400);
  }

  build() {
    Stack() {
      this.fallback()
      if (this.needsBrowserBridge(this.user.avatarUrl) && this.bridgedAvatarUrl === this.user.avatarUrl &&
        this.avatarPixelMap !== undefined) {
        Image(this.avatarPixelMap)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .objectFit(ImageFit.Cover)
          .borderRadius(Radius.PILL)
          .draggable(false)
      } else if (this.needsBrowserBridge(this.user.avatarUrl) &&
        this.nativeFallbackAvatarUrl === this.user.avatarUrl && this.user.avatarUrl !== this.failedAvatarUrl) {
        Image(this.user.avatarUrl)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .sourceSize({ width: this.avatarSize, height: this.avatarSize })
          .syncLoad(false)
          .objectFit(ImageFit.Cover)
          .borderRadius(Radius.PILL)
          .draggable(false)
          .onError(() => {
            this.failedAvatarUrl = this.user.avatarUrl;
          })
      } else if (!this.needsBrowserBridge(this.user.avatarUrl) && this.user.avatarUrl.length > 0 &&
        this.user.avatarUrl !== this.failedAvatarUrl) {
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
    .onAppear(() => this.prepareBridgedAvatar())
  }
}
