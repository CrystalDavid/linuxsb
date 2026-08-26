import { SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { ImmersiveGlassTextButton } from './ImmersiveGlassTextButton';

@Component
export struct AccountLoginGate {
  title: string = '登录后继续';
  semanticPrefix: string = 'account';
  onLogin: () => void = () => {};

  build() {
    Column({ space: Spacing.MD }) {
      SymbolGlyph($r('sys.symbol.person_badge_lock_fill'))
        .id(`${this.semanticPrefix}-login-icon`)
        .fontSize(54)
        .fontColor([$r('app.color.brand_primary')])
      Text(this.title)
        .id(`${this.semanticPrefix}-login-title`)
        .fontSize(Typography.SECTION_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.textPrimary())
      ImmersiveGlassTextButton({
        label: '打开官方登录页',
        semanticId: `${this.semanticPrefix}-login-action`,
        onAction: () => this.onLogin()
      })
    }
    .id(`${this.semanticPrefix}-login-required`)
    .width('100%')
    .padding(Spacing.XL)
    .backgroundColor(Color.Transparent)
  }
}
