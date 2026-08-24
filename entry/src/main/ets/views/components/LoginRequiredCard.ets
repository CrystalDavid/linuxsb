import { AppColors, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';

@Component
export struct LoginRequiredCard {
  replyCount: number = 0;
  errorMessage: string = '';
  onLogin: () => void = () => {};

  build() {
    Column({ space: Spacing.SM }) {
      Row({ space: Spacing.MD }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.lock'))
            .fontSize(22)
            .fontColor([AppColors.brandPrimary()])
        }
        .width(42).height(42).borderRadius(Radius.PILL).backgroundColor(AppColors.brandSoft())

        Column({ space: Spacing.XXS }) {
          Text(`登录后查看 ${this.replyCount} 条回复`)
            .fontSize(Typography.BODY_LARGE)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textPrimary())
          Text('在 linux.sb 官方页面完成登录')
            .fontSize(Typography.CAPTION)
            .fontColor(SemanticColors.textSecondary())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button('登录')
          .fontColor(Color.White)
          .backgroundColor(AppColors.brandPrimary())
          .borderRadius(Radius.PILL)
          .onClick(() => this.onLogin())
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
