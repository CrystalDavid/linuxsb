import { AppColors, PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { SYS_BOTTOM_INSET_KEY } from '../../common/ui/ImmersiveWindow';

@Component
export struct CommentInputBar {
  onUnavailable: () => void = () => {};
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;

  build() {
    Row({ space: Spacing.SM }) {
      Row({ space: Spacing.SM }) {
        SymbolGlyph($r('sys.symbol.square_and_pencil'))
          .fontSize(18)
          .fontColor([SemanticColors.disabled()])
        Text('回复功能尚未开放')
          .fontSize(Typography.BODY)
          .fontColor(SemanticColors.disabled())
          .layoutWeight(1)
      }
      .layoutWeight(1)
      .height(44)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .backgroundColor($r('app.color.immersive_input_field_bg'))
      .borderRadius(Radius.SM)

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.paperplane'))
          .fontSize(19)
          .fontColor([SemanticColors.disabled()])
      }
      .width(42).height(42)
      .backgroundColor(SemanticColors.disabledSurface())
    }
    .id('comment-input-disabled')
    .accessibilityText('回复功能尚未开放')
    .width('100%')
    .height(PageMetrics.REPLY_BAR_HEIGHT + this.bottomInset)
    .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.SM, bottom: Spacing.SM + this.bottomInset })
    .backgroundColor(SemanticColors.surfaceElevated())
    .border({ width: { top: 1 }, color: SemanticColors.divider() })
    .onClick(() => this.onUnavailable())
  }
}
