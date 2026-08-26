import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';
import { SYS_BOTTOM_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { WriteResult } from '../../services/repository/WriteRepository';
import {
  GLASS_ACTION_ARROW_ICON_SIZE,
  GLASS_ACTION_ARROW_ICON_WEIGHT,
  ImmersiveIconButton
} from './ImmersiveIconButton';

export const REPLY_CONTROL_HEIGHT: number = 42;

@Component
export struct CommentInputBar {
  @Link draft: string;
  @Prop authenticated: boolean = false;
  onLogin: () => void = () => {};
  onSubmit: (body: string) => Promise<WriteResult> =
    async () => ({ ok: false, topicId: 0, message: '回复服务不可用', networkMs: 0 });
  onSubmitted: () => void = () => {};
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;
  @State private submitting: boolean = false;
  @State private errorMessage: string = '';

  private canSubmit(): boolean {
    return !this.submitting && this.draft.trim().length > 0;
  }

  private async submit(): Promise<void> {
    if (!this.authenticated) {
      this.onLogin();
      return;
    }
    if (!this.canSubmit()) {
      return;
    }
    this.submitting = true;
    this.errorMessage = '';
    const result = await this.onSubmit(this.draft.trim());
    this.submitting = false;
    if (!result.ok) {
      this.errorMessage = result.message;
      return;
    }
    this.draft = '';
    this.onSubmitted();
  }

  build() {
    Column({ space: Spacing.XXS }) {
      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(Typography.LABEL_SMALL)
          .fontColor(SemanticColors.error())
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Row({ space: Spacing.SM }) {
        Row() {
          TextInput({ text: this.draft, placeholder: this.authenticated ? '写回复…' : '登录后回复' })
            .id('topic-reply-input')
            .layoutWeight(1)
            .height(REPLY_CONTROL_HEIGHT - 2)
            .fontSize(Typography.BODY)
            .backgroundColor(Color.Transparent)
            .enabled(this.authenticated && !this.submitting)
            .enterKeyType(EnterKeyType.Send)
            .onChange((value: string) => { this.draft = value; })
            .onSubmit(() => this.submit())
        }
        .layoutWeight(1)
        .id('topic-reply-input-surface')
        .height(REPLY_CONTROL_HEIGHT)
        .padding({ left: 0, right: Spacing.SM })
        .backgroundEffect(buildImmersiveGlassEffect())
        .borderRadius(Radius.PILL)
        .border({ width: IMMERSIVE_GLASS_BORDER_WIDTH, color: $r('app.color.bottom_tab_bar_highlight') })
        .shadow({
          radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
          color: $r('app.color.bottom_tab_bar_shadow'),
          offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
        })
        .onClick(() => {
          if (!this.authenticated) {
            this.onLogin();
          }
        })

        ImmersiveIconButton({
          icon: $r('sys.symbol.arrow_up'),
          semanticId: 'topic-reply-send',
          semanticLabel: '发送回复',
          buttonSize: REPLY_CONTROL_HEIGHT,
          iconSize: GLASS_ACTION_ARROW_ICON_SIZE,
          iconWeight: GLASS_ACTION_ARROW_ICON_WEIGHT,
          iconColor: $r('app.color.brand_primary'),
          onAction: () => this.submit()
        })
          .opacity(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .id('comment-input-bar')
    .width('100%')
    .constraintSize({ minHeight: PageMetrics.REPLY_BAR_HEIGHT + this.bottomInset })
    .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.SM, bottom: Spacing.SM + this.bottomInset })
    .backgroundColor(Color.Transparent)
  }
}
