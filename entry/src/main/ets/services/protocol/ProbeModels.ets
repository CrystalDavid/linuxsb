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
  author: string;
  bodyText: string;
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

export interface TopicStructureProbeResult {
  detectedBbsVersion: string;
  tokenCount: number;
  startTagCount: number;
  topicLinkCount: number;
  userLinkCount: number;
  replyReferenceLinkCount: number;
  floorAnchorCount: number;
  postIdPrefixCount: number;
  replyIdPrefixCount: number;
  dataFloorCount: number;
  replyIdParameterCount: number;
  knownPostEntryMarkerCount: number;
  candidateReplyContainerCount: number;
  paginationLinkCount: number;
  loginVisibleMarkerCount: number;
}

export type ProbeDecodeKind = 'home' | 'topic';

export interface ProbeDecodeWireResult {
  kind: ProbeDecodeKind;
  parseMs: number;
  inputBytes: number;
  outputCount: number;
  home?: HomeProbeResult;
  topic?: TopicProbeResult;
  topicStructure?: TopicStructureProbeResult;
}

export interface BackgroundProbeDecodeResult extends ProbeDecodeWireResult {
  execution: 'TASKPOOL' | 'UI_FALLBACK';
  executionWarning: string;
}
