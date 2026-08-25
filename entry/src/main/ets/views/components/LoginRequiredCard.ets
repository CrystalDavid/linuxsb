import { AppColors, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { ImmersiveGlassTextButton } from './ImmersiveGlassTextButton';

@Component
export struct LoginRequiredCard {
  replyCount: number = 0;
  errorMessage: string = '';
  onLogin: () => void = () => {};

  build() {
    Column({ space: Spacing.SM }) {
      Row({ space: Spacing.MD }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.person_badge_lock_fill'))
            .fontSize(26)
            .fontColor([AppColors.brandPrimary()])
        }
        .width(42).height(42).borderRadius(Radius.PILL).backgroundColor(AppColors.brandSoft())

        Column({ space: Spacing.XXS }) {
          Text(`登录后查看 ${this.replyCount} 条回复`)
            .fontSize(Typography.BODY_LARGE)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textPrimary())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        ImmersiveGlassTextButton({
          label: '登录',
          semanticId: 'topic-login-action',
          controlHeight: 42,
          horizontalPadding: Spacing.MD,
          labelFontSize: Typography.LABEL,
          onAction: () => this.onLogin()
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .id('login-return-error')
          .fontSize(Typography.CAPTION)
          .fontColor(SemanticColors.error())
          .width('100%')
      }
    }
    .id('login-required-card')
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.LG)
    .backgroundColor(SemanticColors.surfaceMuted())
    .borderRadius(Radius.MD)
  }
}
