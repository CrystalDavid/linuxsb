import { AppColors, SemanticColors } from '../../common/theme/DesignSystem';

@Component
export struct ChoiceChip {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  @State private pressed: boolean = false;

  build() {
    Row() {
      Text(this.label)
        .fontSize(14)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selected ? AppColors.brandPrimary() : SemanticColors.textPrimary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
      .id(`choice-${this.label}`)
      .height(32)
      .backgroundColor(this.selected ? AppColors.brandSoft() : SemanticColors.surfaceMuted())
      .borderRadius(16)
      .padding({ left: 14, right: 14 })
      .margin({ right: 8, bottom: 8 })
      .opacity(this.pressed ? 0.7 : 1)
      .alignItems(VerticalAlign.Center)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressed = false;
        }
      })
      .onClick(() => this.onSelect())
  }
}
