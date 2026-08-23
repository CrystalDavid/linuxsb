import { SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';

@Component
export struct TopicDetailHeader {
  title: string = '';
  categoryName: string = '';

  build() {
    Row({ space: Spacing.SM }) {
      // HDS draws the native back action underneath stackBuilder; reserve its hit and visual area.
      Blank().width(40).height(40)
      Column({ space: 1 }) {
        Text(this.title.length > 0 ? this.title : '主题详情')
          .fontSize(Typography.TITLE_SMALL)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.categoryName.length > 0) {
          Text(this.categoryName)
            .fontSize(Typography.LABEL_SMALL)
            .fontColor(SemanticColors.textSecondary())
            .maxLines(1)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .id('topic-detail-header')
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
    .padding({ left: Spacing.MD, right: Spacing.MD })
  }
}
