import { Radius } from '../../common/theme/DesignSystem';

@Component
export struct AttachmentThumbnail {
  uri: string = '';
  semanticId: string = 'attachment-thumbnail';
  onRemove: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(this.uri)
        .id(`${this.semanticId}-image`)
        .width(64)
        .height(64)
        .borderRadius(Radius.LG)
        .objectFit(ImageFit.Cover)
        .alt($r('app.color.skeleton'))
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor([Color.White])
      }
      .id(`${this.semanticId}-remove`)
      .accessibilityText('移除图片')
      .width(20)
      .height(20)
      .backgroundColor('#C0000000')
      .margin({ top: 4, right: 4 })
      .hoverEffect(HoverEffect.None)
      .onClick(() => this.onRemove())
    }
    .width(64)
    .height(64)
  }
}
