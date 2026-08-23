import { TopicUiModel } from '../../models/presentation/ForumUiModels';

export function topicStatusLabels(topic: TopicUiModel): string[] {
  const labels: string[] = [];
  if (topic.isPinned) {
    labels.push('置顶');
  }
  if (topic.isFeatured) {
    labels.push('精华');
  }
  if (topic.isHot) {
    labels.push('热');
  }
  if (topic.lotteryStatus === 'open') {
    labels.push('抽奖中');
  }
  if (topic.cardStatus === 'active') {
    labels.push('卡片');
  } else if (topic.cardStatus === 'finished') {
    labels.push('卡片已结束');
  }
  return labels;
}
