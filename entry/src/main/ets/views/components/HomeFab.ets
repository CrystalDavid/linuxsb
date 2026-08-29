import { ActionBarButton, ActionBarStyle, HdsActionBar } from '@kit.UIDesignKit';
import { FrameCallback } from '@kit.ArkUI';
import { ColorMetrics, LengthMetrics } from '@ohos.arkui.node';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import {
  buildImmersiveFloatingActionButtonModifier,
  IMMERSIVE_ACTION_BAR_BLUR_STRATEGY,
  IMMERSIVE_FAB_BUTTON_SIZE
} from '../../common/ui/ImmersiveActionBarStyle';
import { GLASS_STYLE_STORAGE_KEY, GlassStyleMode } from '../../common/ui/GlassStyleParams';

class FabDragOffset {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

class FabDragFrameTask extends FrameCallback {
  private readonly run: () => void;

  constructor(run: () => void) {
    super();
    this.run = run;
  }

  onFrame(_frameTimeInNano: number): void {
    this.run();
  }
}

@Component
export struct HomeFab {
  onAction: () => void = () => {};
  icon: Resource = $r('sys.symbol.plus');
  semanticId: string = 'home-write-fab';
  semanticLabel: string = '发表新主题';
  @Prop maxDragX: number = 0;
  @Prop maxDragY: number = 0;
  @StorageProp(GLASS_STYLE_STORAGE_KEY) private glassStyle: GlassStyleMode = GlassStyleMode.Translucent;
  @State private dragOffset: FabDragOffset = new FabDragOffset(0, 0);
  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private pendingDragX: number = 0;
  private pendingDragY: number = 0;
  private dragFramePosted: boolean = false;
  private dragActive: boolean = true;
  private didDrag: boolean = false;
  private suppressClickUntil: number = 0;

  private clamp(value: number, minimum: number, maximum: number): number {
    return Math.max(minimum, Math.min(maximum, value));
  }

  private beginDrag(): void {
    this.dragStartX = this.dragOffset.x;
    this.dragStartY = this.dragOffset.y;
    this.pendingDragX = this.dragStartX;
    this.pendingDragY = this.dragStartY;
    this.didDrag = false;
  }

  private updateDrag(event: GestureEvent): void {
    this.pendingDragX = this.clamp(this.dragStartX + event.offsetX, -Math.max(0, this.maxDragX), 0);
    this.pendingDragY = this.clamp(this.dragStartY + event.offsetY, -Math.max(0, this.maxDragY), 0);
    if (Math.abs(event.offsetX) + Math.abs(event.offsetY) > 6) {
      this.didDrag = true;
    }
    this.scheduleDragFrame();
  }

  private finishDrag(): void {
    this.commitDragFrame();
    if (this.didDrag) {
      this.suppressClickUntil = Date.now() + 250;
    }
  }

  private scheduleDragFrame(): void {
    if (this.dragFramePosted) {
      return;
    }
    this.dragFramePosted = true;
    try {
      this.getUIContext().postFrameCallback(new FabDragFrameTask(() => this.commitDragFrame()));
    } catch (_error) {
      this.commitDragFrame();
    }
  }

  private commitDragFrame(): void {
    if (!this.dragFramePosted && this.dragOffset.x === this.pendingDragX &&
      this.dragOffset.y === this.pendingDragY) {
      return;
    }
    this.dragFramePosted = false;
    if (!this.dragActive) {
      return;
    }
    this.dragOffset = new FabDragOffset(this.pendingDragX, this.pendingDragY);
  }

  private invokeAction(): void {
    if (Date.now() >= this.suppressClickUntil) {
      this.onAction();
    }
  }

  aboutToAppear(): void {
    this.dragActive = true;
  }

  aboutToDisappear(): void {
    this.dragActive = false;
    this.dragFramePosted = false;
  }

  build() {
    HdsActionBar({
      primaryButton: this.actionButton(),
      actionBarStyle: this.actionBarStyle(),
      blurStrategy: IMMERSIVE_ACTION_BAR_BLUR_STRATEGY
    })
    .id(this.semanticId)
    .width(IMMERSIVE_FAB_BUTTON_SIZE)
    .height(IMMERSIVE_FAB_BUTTON_SIZE)
    .translate({ x: this.dragOffset.x, y: this.dragOffset.y })
    .priorityGesture(
      PanGesture({ direction: PanDirection.All, distance: 1 })
        .onActionStart(() => this.beginDrag())
        .onActionUpdate((event: GestureEvent) => this.updateDrag(event))
        .onActionEnd(() => this.finishDrag())
        .onActionCancel(() => this.finishDrag())
    )
  }

  private actionButton(): ActionBarButton {
    return new ActionBarButton({
      width: LengthMetrics.vp(IMMERSIVE_FAB_BUTTON_SIZE),
      backgroundColor: ColorMetrics.resourceColor(Color.Transparent),
      buttonModifier: buildImmersiveFloatingActionButtonModifier(this.glassStyle),
      iconSize: LengthMetrics.vp(23),
      iconFillColor: ColorMetrics.resourceColor($r('app.color.fab_compose_bg')),
      baseIconSymbolGlyphModifier: this.iconSymbol(),
      accessibilityText: this.semanticLabel,
      onClick: () => this.invokeAction()
    });
  }

  private actionBarStyle(): ActionBarStyle {
    return new ActionBarStyle({
      height: LengthMetrics.vp(IMMERSIVE_FAB_BUTTON_SIZE),
      backgroundBlurStyle: BlurStyle.NONE,
      backgroundColor: ColorMetrics.resourceColor(Color.Transparent),
      innerSpace: LengthMetrics.vp(0),
      startSpace: LengthMetrics.vp(0),
      endSpace: LengthMetrics.vp(0),
      isHorizontal: true
    });
  }

  private iconSymbol(): SymbolGlyphModifier {
    const modifier = new SymbolGlyphModifier(this.icon);
    modifier.fontSize(23);
    modifier.fontWeight(900);
    modifier.fontColor([$r('app.color.fab_compose_bg')]);
    return modifier;
  }
}
