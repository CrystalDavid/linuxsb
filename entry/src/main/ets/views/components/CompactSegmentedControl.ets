import { curves } from '@kit.ArkUI';
import { Radius, SemanticColors, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect,
  buildImmersiveSystemMaterialModifier,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';
import { GLASS_STYLE_STORAGE_KEY, GlassStyleMode } from '../../common/ui/GlassStyleParams';

export class SegmentOption {
  label: string;
  semanticId: string;

  constructor(label: string, semanticId: string) {
    this.label = label;
    this.semanticId = semanticId;
  }
}

export const TITLE_BAR_SEGMENT_WIDTH: number = 46;
export const TITLE_BAR_SEGMENT_HEIGHT: number = 30;
export const TITLE_BAR_SEGMENT_LABEL_SIZE: number = Typography.CAPTION;

@Component
export struct CompactSegmentedControl {
  @Prop options: SegmentOption[] = [];
  @Prop @Watch('onSelectedIndexChanged') selectedIndex: number = 0;
  @Prop segmentWidth: number = TITLE_BAR_SEGMENT_WIDTH;
  @Prop controlHeight: number = TITLE_BAR_SEGMENT_HEIGHT;
  @Prop labelFontSize: number = Typography.CAPTION;
  @Prop labelOffsetY: number = 0;
  semanticId: string = 'compact-segmented-control';
  onSelect: (index: number) => void = () => {};
  @StorageProp(GLASS_STYLE_STORAGE_KEY) private glassStyle: GlassStyleMode = GlassStyleMode.Translucent;
  @State private visualSelectedIndex: number = 0;
  @State private indicatorX: number = 2;
  @State private indicatorScaleX: number = 1;
  @State private indicatorScaleY: number = 1;
  private recoveryTimer: number = -1;
  private dragStartIndicatorX: number = 2;
  private lastDragOffsetX: number = 0;
  private smoothedDragVelocity: number = 0;

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

  private minimumIndicatorX(): number {
    return 2;
  }

  private maximumIndicatorX(): number {
    return this.minimumIndicatorX() + this.segmentWidth * Math.max(0, this.options.length - 1);
  }

  private clampIndicatorX(value: number): number {
    return Math.max(this.minimumIndicatorX(), Math.min(this.maximumIndicatorX(), value));
  }

  private indexAtIndicatorPosition(position: number): number {
    return this.safeIndex(Math.round((position - this.minimumIndicatorX()) / this.segmentWidth));
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
    if (target === this.visualSelectedIndex && target === this.safeIndex(this.selectedIndex)) {
      return;
    }
    this.animateSelection(target);
    if (target !== this.safeIndex(this.selectedIndex)) {
      this.onSelect(target);
    }
  }

  private animateSelection(index: number): void {
    const distance = Math.abs(index - this.visualSelectedIndex);
    this.visualSelectedIndex = index;
    this.cancelRecovery();
    this.getUIContext().animateTo({ duration: 260, curve: Curve.Friction }, () => {
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

  private beginIndicatorDrag(): void {
    this.cancelRecovery();
    this.dragStartIndicatorX = this.indicatorX;
    this.lastDragOffsetX = 0;
    this.smoothedDragVelocity = 0;
  }

  private updateIndicatorDrag(event: GestureEvent): void {
    const frameVelocity = event.offsetX - this.lastDragOffsetX;
    this.lastDragOffsetX = event.offsetX;
    this.smoothedDragVelocity = this.smoothedDragVelocity * 0.7 + frameVelocity * 0.3;
    this.indicatorX = this.clampIndicatorX(this.dragStartIndicatorX + event.offsetX);
    const deformation = Math.min(0.2, Math.sqrt(Math.abs(this.smoothedDragVelocity) / 12) * 0.1);
    this.indicatorScaleX = 1 + deformation;
    this.indicatorScaleY = 1 - deformation * 0.35;
    this.visualSelectedIndex = this.indexAtIndicatorPosition(this.indicatorX);
  }

  private finishIndicatorDrag(velocityX: number): void {
    const projection = Math.max(-this.segmentWidth * 0.45,
      Math.min(this.segmentWidth * 0.45, velocityX / 80));
    const target = this.indexAtIndicatorPosition(this.clampIndicatorX(this.indicatorX + projection));
    const shouldSwitch = target !== this.safeIndex(this.selectedIndex);
    this.animateSelection(target);
    if (shouldSwitch) {
      this.onSelect(target);
    }
  }

  @Builder
  private segment(option: SegmentOption, index: number) {
    Button({ type: ButtonType.Capsule, stateEffect: false }) {
      Text(option.label)
        .id(`${option.semanticId}-label`)
        .fontSize(this.labelFontSize)
        .fontWeight(this.visualSelectedIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.visualSelectedIndex === index ?
          $r('app.color.brand_primary') : SemanticColors.textSecondary())
        .translate({ y: this.labelOffsetY })
    }
      .id(option.semanticId)
      .accessibilityText(option.label)
      .height(this.segmentHeight())
      .width(this.segmentWidth)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .borderRadius(Radius.PILL)
      .hoverEffect(HoverEffect.None)
      .onClick(() => this.select(index))
  }

  @Builder
  private selectionIndicator() {
    Row()
      .id(`${this.semanticId}-selection-indicator`)
      .width(this.segmentWidth)
      .height(this.segmentHeight())
      .position({ x: 0, y: 2 })
      .translate({ x: this.indicatorX })
      .scale({ x: this.indicatorScaleX, y: this.indicatorScaleY })
      .backgroundColor($r('app.color.bottom_tab_selected_bg'))
      .border({ width: 0.9, color: $r('app.color.bottom_tab_bar_highlight') })
      .borderRadius(Radius.PILL)
      .shadow({ radius: 7, color: $r('app.color.bottom_tab_selected_glow'), offsetY: 1 })
      .opacity(1)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.selectionIndicator()
      Row({ space: 0 }) {
        ForEach(this.options, (option: SegmentOption, index: number) => {
          this.segment(option, index)
        }, (option: SegmentOption) => option.semanticId)
      }
      .width(this.segmentWidth * this.options.length)
      .height(this.controlHeight)
      .position({ x: 2, y: 0 })
      .alignItems(VerticalAlign.Center)
    }
    .id(this.semanticId)
    .width(this.segmentWidth * this.options.length + 4)
    .height(this.controlHeight)
    .backgroundColor(Color.Transparent)
    .backgroundEffect(buildImmersiveGlassEffect(this.glassStyle))
    .border({ width: IMMERSIVE_GLASS_BORDER_WIDTH, color: $r('app.color.bottom_tab_bar_highlight') })
    .borderRadius(Radius.PILL)
    .clip(true)
    .shadow({
      radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
      color: $r('app.color.bottom_tab_bar_shadow'),
      offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
    })
    .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
    .priorityGesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 6 })
        .onActionStart(() => this.beginIndicatorDrag())
        .onActionUpdate((event: GestureEvent) => this.updateIndicatorDrag(event))
        .onActionEnd((event: GestureEvent) => this.finishIndicatorDrag(event.velocityX))
        .onActionCancel(() => this.finishIndicatorDrag(0))
    )
  }
}
