import { AppRadius, AppSpacing, AppTypography } from '../../common/theme/AppTheme';
import { ContentBlock, ContentBlockKind } from '../../models/ContentBlock';

@Component
export struct ContentBlockRenderer {
  blocks: ContentBlock[] = [];

  build() {
    Column({ space: AppSpacing.XS }) {
      ForEach(this.blocks, (block: ContentBlock, index: number) => {
        if (block.kind === ContentBlockKind.Paragraph) {
          Text(block.text)
            .fontSize(AppTypography.BODY_LARGE)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(27)
            .width('100%')
        } else if (block.kind === ContentBlockKind.LineBreak) {
          Blank().height(AppSpacing.XS)
        } else if (block.kind === ContentBlockKind.Link) {
          Text(block.text.length > 0 ? block.text : block.url)
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.primary'))
            .decoration({ type: TextDecorationType.Underline })
            .width('100%')
        } else if (block.kind === ContentBlockKind.Quote) {
          Row() {
            Text(block.text)
              .fontSize(AppTypography.BODY)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(24)
              .layoutWeight(1)
          }
          .width('100%')
          .padding(AppSpacing.SM)
          .backgroundColor($r('app.color.quote_background'))
          .border({ width: { left: 3 }, color: $r('app.color.primary') })
          .borderRadius(AppRadius.SM)
        } else if (block.kind === ContentBlockKind.InlineCode) {
          Text(block.text)
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_primary'))
            .fontFamily('monospace')
            .padding({ left: AppSpacing.XS, right: AppSpacing.XS, top: AppSpacing.XXS, bottom: AppSpacing.XXS })
            .backgroundColor($r('app.color.code_background'))
            .borderRadius(AppRadius.SM)
            .alignSelf(ItemAlign.Start)
        } else if (block.kind === ContentBlockKind.CodeBlock) {
          Scroll() {
            Text(block.text)
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .fontFamily('monospace')
              .width('100%')
          }
          .scrollable(ScrollDirection.Horizontal)
          .width('100%')
          .padding(AppSpacing.SM)
          .backgroundColor($r('app.color.code_background'))
          .borderRadius(AppRadius.MD)
        } else if (block.kind === ContentBlockKind.Image && block.url.length > 0) {
          Image(block.url)
            .objectFit(ImageFit.Contain)
            .width('100%')
            .constraintSize({ maxHeight: 480 })
            .borderRadius(AppRadius.MD)
        } else {
          Row({ space: AppSpacing.XS }) {
            Text('暂不支持的扩展内容')
              .fontSize(AppTypography.CAPTION)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding(AppSpacing.SM)
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM)
        }
      }, (_block: ContentBlock, index: number) => index.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
