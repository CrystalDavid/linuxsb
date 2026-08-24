import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { IMMERSIVE_PANEL_BLUR_RADIUS } from '../../common/ui/ImmersiveLightMaterial';
import { SYS_BOTTOM_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { WriteResult } from '../../services/repository/WriteRepository';

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
        Row({ space: Spacing.SM }) {
          SymbolGlyph($r('sys.symbol.square_and_pencil'))
            .fontSize(18)
            .fontColor([this.authenticated ? SemanticColors.textSecondary() : SemanticColors.disabled()])
          TextInput({ text: this.draft, placeholder: this.authenticated ? '写回复…' : '登录后回复' })
            .id('topic-reply-input')
            .layoutWeight(1)
            .height(42)
            .fontSize(Typography.BODY)
            .backgroundColor(Color.Transparent)
            .enabled(this.authenticated && !this.submitting)
            .enterKeyType(EnterKeyType.Send)
            .onChange((value: string) => { this.draft = value; })
            .onSubmit(() => this.submit())
        }
        .layoutWeight(1)
        .height(44)
        .padding({ left: Spacing.MD, right: Spacing.SM })
        .backgroundColor($r('app.color.immersive_input_field_bg'))
        .borderRadius(Radius.PILL)
        .border({ width: 0.5, color: SemanticColors.outline() })
        .onClick(() => {
          if (!this.authenticated) {
            this.onLogin();
          }
        })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          if (this.submitting) {
            LoadingProgress().width(20).height(20).color(Color.White)
          } else {
            SymbolGlyph($r('sys.symbol.paperplane'))
              .fontSize(19)
              .fontColor([Color.White])
          }
        }
        .id('topic-reply-send')
        .accessibilityText('发送回复')
        .width(42).height(42)
        .backgroundColor($r('app.color.brand_primary'))
        .opacity(this.canSubmit() ? 1 : 0.45)
        .onClick(() => this.submit())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .id('comment-input-bar')
    .width('100%')
    .constraintSize({ minHeight: PageMetrics.REPLY_BAR_HEIGHT + this.bottomInset })
    .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.SM, bottom: Spacing.SM + this.bottomInset })
    .backdropBlur(IMMERSIVE_PANEL_BLUR_RADIUS)
    .backgroundColor($r('app.color.bottom_tab_bar_bg'))
    .border({ width: { top: 0.5 }, color: $r('app.color.bottom_tab_bar_highlight') })
  }
}
