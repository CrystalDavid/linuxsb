import { SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { TopicDetailUiModel, TopicUiModel } from '../../models/presentation/ForumUiModels';
import { TopicMetadataBadges } from './TopicBadges';

@Component
export struct TopicSummaryCard {
  @Prop detail: TopicDetailUiModel = new TopicDetailUiModel();
  @Prop summary: TopicUiModel | undefined = undefined;

  build() {
    Column() {
      Text(this.detail.title)
        .fontSize(24)
        .lineHeight(32)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .width('100%')
      if (this.summary !== undefined) {
        TopicMetadataBadges({ topic: this.summary as TopicUiModel })
          .width('100%')
          .margin({ top: Spacing.SM })
      }
      Text(`${this.detail.advertisedReplyCount} 条回复 · ${this.detail.viewCount} 次浏览`)
        .fontSize(Typography.CAPTION)
        .fontColor(SemanticColors.textSecondary())
        .margin({ top: Spacing.SM })
    }
    .id('topic-summary-card')
    .width('100%')
    .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XXS, bottom: Spacing.MD })
    .backgroundColor(Color.Transparent)
    .alignItems(HorizontalAlign.Start)
  }
}
