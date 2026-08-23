import { SemanticColors } from '../../common/theme/DesignSystem';
import { TopicDetailUiModel, TopicUiModel } from '../../models/presentation/ForumUiModels';
import { TopicMetadataBadges } from './TopicBadges';

@Component
export struct TopicSummaryCard {
  @Prop detail: TopicDetailUiModel = new TopicDetailUiModel();
  @Prop summary: TopicUiModel | undefined = undefined;

  build() {
    Column() {
      Text(this.detail.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .width('100%')
      if (this.summary !== undefined) {
        TopicMetadataBadges({ topic: this.summary as TopicUiModel })
          .width('100%')
          .margin({ top: 8 })
      }
      Text(`${this.detail.advertisedReplyCount} 条回复 · ${this.detail.viewCount} 次浏览`)
        .fontSize(12)
        .fontColor(SemanticColors.textSecondary())
        .margin({ top: 8 })
    }
    .id('topic-summary-card')
    .width('100%')
    .padding({ left: 10, right: 10, top: 20, bottom: 16 })
    .border({ width: { bottom: 1 }, color: SemanticColors.divider() })
    .backgroundColor(SemanticColors.surface())
    .alignItems(HorizontalAlign.Start)
  }
}
