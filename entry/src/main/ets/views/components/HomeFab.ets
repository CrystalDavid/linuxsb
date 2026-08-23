import { AppColors, PageMetrics, Radius, SemanticColors } from '../../common/theme/DesignSystem';
import { SHADOW_CARD } from '../../common/theme/Palette';

@Component
export struct HomeFab {
  onAction: () => void = () => {};

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(24)
        .fontColor([Color.White])
    }
    .id('home-write-fab')
    .accessibilityText('写主题，当前未开放')
    .width(PageMetrics.FAB_SIZE)
    .height(PageMetrics.FAB_SIZE)
    .backgroundColor(AppColors.brandPrimary())
    .borderRadius(Radius.PILL)
    .shadow({ radius: 18, color: SHADOW_CARD, offsetY: 6 })
    .onClick(() => this.onAction())
  }
}
