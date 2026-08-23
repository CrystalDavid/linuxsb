import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { ContentBlock, ContentBlockKind } from '../../models/ContentBlock';
import { TopicOpenTrace } from '../../services/logging/TopicOpenTrace';

@Component
export struct PostRichContent {
  blocks: ContentBlock[] = [];

  @Builder
  private blockView(block: ContentBlock) {
    if (block.kind === ContentBlockKind.Paragraph) {
      Text(block.text)
        .fontSize(16).lineHeight(26)
        .fontColor(SemanticColors.textPrimary()).width('100%').copyOption(CopyOptions.LocalDevice)
    } else if (block.kind === ContentBlockKind.Heading) {
      Text(block.text)
        .fontSize(19).lineHeight(27).fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary()).width('100%').copyOption(CopyOptions.LocalDevice)
    } else if (block.kind === ContentBlockKind.ListItem) {
      Row({ space: 8 }) {
        Text('•').fontSize(18).fontColor(SemanticColors.textSecondary())
        Text(block.text).fontSize(16).lineHeight(26).fontColor(SemanticColors.textPrimary())
          .layoutWeight(1).copyOption(CopyOptions.LocalDevice)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else if (block.kind === ContentBlockKind.LineBreak) {
      Blank().height(Spacing.SM)
    } else if (block.kind === ContentBlockKind.Link) {
      Text(block.text.length > 0 ? block.text : block.url)
        .fontSize(Typography.BODY).fontColor($r('app.color.brand_primary'))
        .decoration({ type: TextDecorationType.Underline }).width('100%').copyOption(CopyOptions.LocalDevice)
    } else if (block.kind === ContentBlockKind.Quote) {
      Row() {
        Text(block.text).fontSize(Typography.BODY).lineHeight(Typography.BODY_LINE_HEIGHT)
          .fontColor(SemanticColors.textSecondary()).layoutWeight(1)
      }
      .width('100%').padding(Spacing.MD).backgroundColor(SemanticColors.quoteBackground())
      .border({ width: { left: 3 }, color: $r('app.color.brand_primary') })
    } else if (block.kind === ContentBlockKind.InlineCode) {
      Text(block.text).fontSize(Typography.BODY).fontFamily('monospace')
        .fontColor(SemanticColors.textPrimary()).padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .backgroundColor(SemanticColors.codeBackground()).borderRadius(Radius.XS).alignSelf(ItemAlign.Start)
    } else if (block.kind === ContentBlockKind.CodeBlock) {
      Column() {
        Row() {
          Text('代码').fontSize(Typography.CAPTION).fontColor(SemanticColors.textSecondary()).layoutWeight(1)
          Text('可长按复制').fontSize(Typography.LABEL_SMALL).fontColor(SemanticColors.textTertiary())
        }.width('100%').margin({ bottom: Spacing.SM })
        Scroll() {
          Text(block.text).fontSize(Typography.CODE).lineHeight(19).fontFamily('monospace')
            .fontColor(SemanticColors.textPrimary()).constraintSize({ minWidth: '100%' })
            .copyOption(CopyOptions.LocalDevice)
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Auto).width('100%')
      }
      .width('100%').padding(Spacing.MD).backgroundColor(SemanticColors.codeBackground())
      .borderRadius(Radius.SM)
    } else if (block.kind === ContentBlockKind.Image && block.url.length > 0) {
      Image(block.url).width('100%').constraintSize({ maxHeight: PageMetrics.MEDIA_MAX_HEIGHT })
        .objectFit(ImageFit.Contain).backgroundColor(SemanticColors.surfaceMuted())
        .borderRadius(Radius.SM).draggable(false)
        .onAppear(() => TopicOpenTrace.markImageRequestsStart())
        .onComplete(() => TopicOpenTrace.markFirstImageFrame())
    } else {
      Row({ space: Spacing.SM }) {
        SymbolGlyph($r('sys.symbol.puzzle')).fontSize(18)
          .fontColor([SemanticColors.textSecondary()])
        Text('此扩展内容暂不支持').fontSize(Typography.CAPTION)
          .fontColor(SemanticColors.textSecondary()).layoutWeight(1)
      }
      .width('100%').padding(Spacing.MD).backgroundColor(SemanticColors.surfaceMuted())
      .borderRadius(Radius.SM)
    }
  }

  build() {
    Column({ space: Spacing.SM }) {
      ForEach(this.blocks, (block: ContentBlock, index: number) => {
        this.blockView(block)
      }, (_block: ContentBlock, index: number) => index.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
