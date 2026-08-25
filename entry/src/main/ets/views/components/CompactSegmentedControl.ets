import { curves } from '@kit.ArkUI';
import { Radius, SemanticColors, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect
} from '../../common/ui/ImmersiveActionBarStyle';

export class SegmentOption {
  label: string;
  semanticId: string;

  constructor(label: string, semanticId: string) {
    this.label = label;
    this.semanticId = semanticId;
  }
}

@Component
export struct CompactSegmentedControl {
  @Prop options: SegmentOption[] = [];
  @Prop @Watch('onSelectedIndexChanged') selectedIndex: number = 0;
  @Prop segmentWidth: number = 58;
  @Prop controlHeight: number = 32;
  @Prop labelFontSize: number = Typography.CAPTION;
  onSelect: (index: number) => void = () => {};
  @State private visualSelectedIndex: number = 0;
  @State private indicatorX: number = 2;
  @State private indicatorScaleX: number = 1;
  @State private indicatorScaleY: number = 1;
  private recoveryTimer: number = -1;

  private segmentHeight(): number {
    return Math.max(24, this.controlHeight - 4);
  }

  aboutToAppear(): void {
    this.visualSelectedIndex = this.safeIndex(this.selectedIndex);
    this.indicatorX = this.indicatorPosition(this.visualSelectedIndex);
  }

  aboutToDisappear(): void {
    this.cancelRecovery();
  }

  private safeIndex(index: number): number {
    return Math.max(0, Math.min(Math.max(0, this.options.length - 1), index));
  }

  private indicatorPosition(index: number): number {
    return 2 + this.segmentWidth * this.safeIndex(index);
  }

  private cancelRecovery(): void {
    if (this.recoveryTimer >= 0) {
      clearTimeout(this.recoveryTimer);
      this.recoveryTimer = -1;
    }
  }

  private onSelectedIndexChanged(): void {
    const target = this.safeIndex(this.selectedIndex);
    if (target !== this.visualSelectedIndex) {
      this.animateSelection(target);
    }
  }

  private select(index: number): void {
    const target = this.safeIndex(index);
    if (target === this.visualSelectedIndex) {
      return;
    }
    this.animateSelection(target);
    this.onSelect(target);
  }

  private animateSelection(index: number): void {
    const distance = Math.abs(index - this.visualSelectedIndex);
    this.cancelRecovery();
    this.getUIContext().animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.visualSelectedIndex = index;
      this.indicatorX = this.indicatorPosition(index);
      this.indicatorScaleX = Math.min(1.16, 1.07 + distance * 0.025);
      this.indicatorScaleY = 0.94;
    });
    this.recoveryTimer = setTimeout(() => {
      this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 360, 34) }, () => {
        this.indicatorScaleX = 1;
        this.indicatorScaleY = 1;
      });
      this.recoveryTimer = -1;
    }, 112);
  }

  @Builder
  private segment(option: SegmentOption, index: number) {
    Button(option.label, { type: ButtonType.Normal, stateEffect: false })
      .id(option.semanticId)
      .accessibilityText(option.label)
      .height(this.segmentHeight())
      .width(this.segmentWidth)
      .padding(0)
      .fontSize(this.labelFontSize)
      .fontWeight(this.visualSelectedIndex === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.visualSelectedIndex === index ? $r('app.color.brand_primary') : SemanticColors.textSecondary())
      .backgroundColor(Color.Transparent)
      .borderRadius(Radius.PILL)
      .hoverEffect(HoverEffect.None)
      .onClick(() => this.select(index))
  }

  @Builder
  private selectionIndicator() {
    Row()
      .id('compact-segment-selection-indicator')
      .width(this.segmentWidth)
      .height(this.segmentHeight())
      .position({ x: 0, y: 2 })
      .translate({ x: this.indicatorX })
      .scale({ x: this.indicatorScaleX, y: this.indicatorScaleY })
      .backgroundColor($r('app.color.bottom_tab_selected_bg'))
      .border({ width: 0.8, color: $r('app.color.bottom_tab_bar_highlight') })
      .borderRadius(Radius.PILL)
      .shadow({ radius: 5, color: $r('app.color.bottom_tab_selected_glow'), offsetY: 1 })
      .opacity(1)
  }

  build() {
    Stack() {
      this.selectionIndicator()
      Row({ space: 0 }) {
        ForEach(this.options, (option: SegmentOption, index: number) => {
          this.segment(option, index)
        }, (option: SegmentOption) => option.semanticId)
      }
      .width(this.segmentWidth * this.options.length)
      .height(this.controlHeight)
    }
    .width(this.segmentWidth * this.options.length + 4)
    .height(this.controlHeight)
    .backgroundColor(Color.Transparent)
    .backgroundEffect(buildImmersiveGlassEffect())
    .border({ width: 1.25, color: $r('app.color.hds_floating_action_highlight') })
    .borderRadius(Radius.PILL)
    .shadow({ radius: 10, color: $r('app.color.hds_floating_action_glow'), offsetY: 2 })
  }
}
