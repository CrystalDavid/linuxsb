import {
  CategoryUiModel,
  TopicUiModel,
  UserUiModel
} from '../models/presentation/ForumUiModels';

export const TOPIC_ROUTE: string = 'TopicDetail';
export const DIAGNOSTICS_ROUTE: string = 'P0Diagnostics';

export interface TopicRouteParam {
  topicId: number;
  summary: TopicUiModel;
}

function copyUser(source: UserUiModel): UserUiModel {
  const result = new UserUiModel();
  result.userId = source.userId;
  result.displayName = source.displayName;
  result.avatarUrl = source.avatarUrl;
  result.initial = source.initial;
  return result;
}

function copyCategory(source: CategoryUiModel): CategoryUiModel {
  const result = new CategoryUiModel();
  result.categoryId = source.categoryId;
  result.name = source.name;
  return result;
}

export function copyTopicSummary(source: TopicUiModel): TopicUiModel {
  const result = new TopicUiModel();
  result.topicId = source.topicId;
  result.title = source.title;
  result.author = copyUser(source.author);
  result.category = copyCategory(source.category);
  result.replyCount = source.replyCount;
  result.lastReplyUser = source.lastReplyUser;
  result.lastReplyAt = source.lastReplyAt;
  result.isPinned = source.isPinned;
  result.isFeatured = source.isFeatured;
  result.isHot = source.isHot;
  result.lotteryStatus = source.lotteryStatus;
  result.cardStatus = source.cardStatus;
  return result;
}

export function buildTopicRouteParam(topicId: number, source: TopicUiModel | undefined): TopicRouteParam {
  const summary = source === undefined ? new TopicUiModel() : copyTopicSummary(source);
  summary.topicId = topicId;
  return {
    topicId: topicId,
    summary: summary
  };
}

export function isTopicRouteParam(param: Object | undefined): boolean {
  if (param === undefined) {
    return false;
  }
  const candidate = param as TopicRouteParam;
  return typeof candidate.topicId === 'number' && candidate.topicId > 0 &&
    candidate.summary !== undefined && candidate.summary.topicId === candidate.topicId;
}
