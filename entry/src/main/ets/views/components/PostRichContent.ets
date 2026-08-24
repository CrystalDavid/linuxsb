import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { ContentBlock, ContentBlockKind } from '../../models/ContentBlock';
import { TopicOpenTrace } from '../../services/logging/TopicOpenTrace';

@Component
struct PostImageBlock {
  url: string = '';
  description: string = '';
  semanticId: string = 'post-image';
  @State private loaded: boolean = false;
  @State private failed: boolean = false;

  build() {
    if (this.failed) {
      Row({ space: Spacing.SM }) {
        Text('图')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.textSecondary())
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .borderRadius(Radius.PILL)
          .backgroundColor(SemanticColors.skeleton())
        Column({ space: 3 }) {
          Text('图片加载失败')
            .fontSize(Typography.CAPTION)
            .fontColor(SemanticColors.textSecondary())
          Text('点击重试')
            .fontSize(Typography.LABEL_SMALL)
            .fontColor($r('app.color.brand_primary'))
        }
        .alignItems(HorizontalAlign.Start)
      }
      .id(`${this.semanticId}-error`)
      .width('100%')
      .height(112)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(SemanticColors.surfaceMuted())
      .borderRadius(Radius.SM)
      .onClick(() => {
        this.loaded = false;
        this.failed = false;
      })
    } else {
      Stack() {
        if (!this.loaded) {
          Column({ space: Spacing.SM }) {
            LoadingProgress().width(24).height(24).color(SemanticColors.textSecondary())
            Text('图片加载中')
              .fontSize(Typography.LABEL_SMALL)
              .fontColor(SemanticColors.textTertiary())
          }
          .width('100%')
          .height(112)
          .justifyContent(FlexAlign.Center)
        }
        Image(this.url)
          .id(this.semanticId)
          .width('100%')
          .constraintSize({ minHeight: this.loaded ? 1 : 112, maxHeight: PageMetrics.MEDIA_MAX_HEIGHT })
          .objectFit(ImageFit.Contain)
          .borderRadius(Radius.SM)
          .draggable(false)
          .accessibilityText(this.description.length > 0 ? this.description : '帖子图片')
          .onAppear(() => TopicOpenTrace.markImageRequestsStart())
          .onComplete(() => {
            this.loaded = true;
            TopicOpenTrace.markFirstImageFrame();
          })
          .onError(() => {
            this.failed = true;
          })
      }
      .width('100%')
      .constraintSize({ minHeight: this.loaded ? 1 : 112 })
      .backgroundColor(SemanticColors.surfaceMuted())
      .borderRadius(Radius.SM)
    }
  }
}

@Component
export struct PostRichContent {
  blocks: ContentBlock[] = [];
  semanticPrefix: string = 'post-content';

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
      PostImageBlock({
        url: block.url,
        description: block.description,
        semanticId: `${this.semanticPrefix}-image`
      })
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
        if (block.kind === ContentBlockKind.Image && block.url.length > 0) {
          PostImageBlock({
            url: block.url,
            description: block.description,
            semanticId: `${this.semanticPrefix}-image-${index}`
          })
        } else {
          this.blockView(block)
        }
      }, (_block: ContentBlock, index: number) => index.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
