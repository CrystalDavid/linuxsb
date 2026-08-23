export interface TopicSummary {
  topicId: number;
  title: string;
  forumId: number;
  forumName: string;
  authorId?: number;
  authorName?: string;
  authorAvatarUrl?: string;
  replyCount?: number;
  lastReplyUser?: string;
  lastReplyAt?: number;
  isPinned?: boolean;
  isFeatured?: boolean;
  isHot?: boolean;
  lotteryStatus?: string;
  cardStatus?: string;
}

export interface HomeFeed {
  protocolVersion: string;
  topics: TopicSummary[];
}
