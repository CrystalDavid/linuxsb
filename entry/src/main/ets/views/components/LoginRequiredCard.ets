import { AppRadius, AppSpacing, AppTypography } from '../../common/theme/AppTheme';

@Component
export struct LoginRequiredCard {
  replyCount: number = 0;
  onLogin: () => void = () => {};

  build() {
    Column({ space: AppSpacing.SM }) {
      Text(`登录后查看 ${this.replyCount} 条回复`)
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text('回复由站点在登录后同一主题页面中提供。')
        .fontSize(AppTypography.CAPTION)
        .fontColor($r('app.color.text_secondary'))
      Button('前往官方登录')
        .onClick(() => this.onLogin())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppSpacing.MD)
    .backgroundColor($r('app.color.surface_secondary'))
    .borderRadius(AppRadius.LG)
  }
}
