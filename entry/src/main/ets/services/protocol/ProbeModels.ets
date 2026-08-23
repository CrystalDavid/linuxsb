export interface ForumProbeSummary {
  forumId: number;
  name: string;
}

export interface HomeTopicProbeSummary {
  topicId: number;
  title: string;
  forumId: number;
  forumName: string;
}

export interface HomeProbeResult {
  protocolMatched: boolean;
  bbsVersion: string;
  forums: ForumProbeSummary[];
  topics: HomeTopicProbeSummary[];
  warnings: string[];
}

export interface ReplyProbeSummary {
  replyId: number;
  floor: number;
}

export interface TopicProbeResult {
  protocolMatched: boolean;
  title: string;
  viewCount: number;
  advertisedReplyCount: number;
  mainPostId: number;
  replies: ReplyProbeSummary[];
  warnings: string[];
}

export type ProbeDecodeKind = 'home' | 'topic';

export interface ProbeDecodeWireResult {
  kind: ProbeDecodeKind;
  parseMs: number;
  inputBytes: number;
  outputCount: number;
  home?: HomeProbeResult;
  topic?: TopicProbeResult;
}

export interface BackgroundProbeDecodeResult extends ProbeDecodeWireResult {
  execution: 'TASKPOOL' | 'UI_FALLBACK';
  executionWarning: string;
}
