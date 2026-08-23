import { AppColors, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { topicStatusLabels } from './TopicBadgeUtils';

@Component
export struct TopicMetadataBadges {
  topic: TopicUiModel = new TopicUiModel();

  build() {
    Row({ space: Spacing.XS }) {
      if (this.topic.category.name.length > 0) {
        Text(this.topic.category.name)
          .fontSize(Typography.CAPTION)
          .fontColor(AppColors.brandPrimary())
          .maxLines(1)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(AppColors.brandSoft())
          .borderRadius(Radius.XS)
      }
      ForEach(topicStatusLabels(this.topic), (label: string) => {
        Text(label)
          .fontSize(Typography.LABEL_SMALL)
          .fontColor(SemanticColors.textSecondary())
          .maxLines(1)
          .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          .backgroundColor(SemanticColors.surfaceMuted())
          .borderRadius(Radius.XS)
      }, (label: string) => label)
    }
    .alignItems(VerticalAlign.Center)
  }
}
