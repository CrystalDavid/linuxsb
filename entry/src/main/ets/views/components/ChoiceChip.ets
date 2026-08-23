import { AppColors, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';

@Component
export struct ChoiceChip {
  label: string = '';
  selected: boolean = false;
  onSelect: () => void = () => {};

  build() {
    Button(this.label, { type: ButtonType.Capsule, stateEffect: true })
      .id(`choice-${this.label}`)
      .height(32)
      .fontSize(Typography.LABEL)
      .fontColor(this.selected ? AppColors.brandPrimary() : SemanticColors.textSecondary())
      .backgroundColor(this.selected ? AppColors.brandSoft() : SemanticColors.surfaceMuted())
      .borderRadius(Radius.PILL)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .onClick(() => this.onSelect())
  }
}
