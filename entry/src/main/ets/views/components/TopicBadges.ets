import { Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { ForumVisuals } from '../../common/theme/ForumVisuals';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { topicStatusLabels } from './TopicBadgeUtils';

class TopicStatusVisuals {
  static accent(label: string): ResourceColor {
    switch (label) {
      case '置顶':
        return $r('app.color.topic_status_pinned');
      case '精华':
        return $r('app.color.topic_status_featured');
      case '热':
        return $r('app.color.topic_status_hot');
      case '抽奖中':
        return $r('app.color.topic_status_lottery');
      case '卡片':
        return $r('app.color.topic_status_card_active');
      case '卡片已结束':
        return $r('app.color.topic_status_card_finished');
      default:
        return SemanticColors.textSecondary();
    }
  }

  static softAccent(label: string): ResourceColor {
    switch (label) {
      case '置顶':
        return $r('app.color.topic_status_pinned_soft');
      case '精华':
        return $r('app.color.topic_status_featured_soft');
      case '热':
        return $r('app.color.topic_status_hot_soft');
      case '抽奖中':
        return $r('app.color.topic_status_lottery_soft');
      case '卡片':
        return $r('app.color.topic_status_card_active_soft');
      case '卡片已结束':
        return $r('app.color.topic_status_card_finished_soft');
      default:
        return SemanticColors.surfaceMuted();
    }
  }
}

@Component
export struct TopicMetadataBadges {
  topic: TopicUiModel = new TopicUiModel();

  build() {
    Row({ space: Spacing.XS }) {
      if (this.topic.category.name.length > 0) {
        Text(this.topic.category.name)
          .fontSize(Typography.CAPTION)
          .fontColor(ForumVisuals.accent(this.topic.category.categoryId))
          .maxLines(1)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(ForumVisuals.softAccent(this.topic.category.categoryId))
          .borderRadius(Radius.XS)
      }
      ForEach(topicStatusLabels(this.topic), (label: string) => {
        Text(label)
          .fontSize(Typography.LABEL_SMALL)
          .fontColor(TopicStatusVisuals.accent(label))
          .maxLines(1)
          .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          .backgroundColor(TopicStatusVisuals.softAccent(label))
          .borderRadius(Radius.XS)
      }, (label: string) => label)
    }
    .alignItems(VerticalAlign.Center)
  }
}
