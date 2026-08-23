export interface TopicSummary {
  topicId: number;
  title: string;
  forumId: number;
  forumName: string;
}

export interface HomeFeed {
  protocolVersion: string;
  topics: TopicSummary[];
}
