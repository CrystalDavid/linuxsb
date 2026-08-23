export interface HomeProtocolTopic {
  topicId: number;
  title: string;
  forumId: number;
  forumName: string;
}

export interface HomeProtocolDocument {
  protocolMatched: boolean;
  bbsVersion: string;
  topics: HomeProtocolTopic[];
  warnings: string[];
}

export interface ProtocolContentBlock {
  kind: string;
  text: string;
  url: string;
  description: string;
}

export interface ProtocolPostDocument {
  postId: number;
  floor: number;
  author: string;
  blocks: ProtocolContentBlock[];
}

export interface TopicProtocolReply {
  replyId: number;
  floor: number;
  author: string;
  bodyText: string;
}

export interface TopicProtocolDocument {
  protocolMatched: boolean;
  bbsVersion: string;
  title: string;
  viewCount: number;
  advertisedReplyCount: number;
  mainPostId: number;
  replies: TopicProtocolReply[];
  posts: ProtocolPostDocument[];
  loginVisibleMarkerCount: number;
  warnings: string[];
}

export interface HomeProductDecodeResult {
  execution: 'TASKPOOL' | 'UI_FALLBACK';
  executionWarning: string;
  parseMs: number;
  inputBytes: number;
  document: HomeProtocolDocument;
}

export interface TopicProductDecodeResult {
  execution: 'TASKPOOL' | 'UI_FALLBACK';
  executionWarning: string;
  parseMs: number;
  inputBytes: number;
  document: TopicProtocolDocument;
}

export interface ProductDecodePort {
  decodeHome(html: string, inputBytes: number): Promise<HomeProductDecodeResult>;
  decodeTopic(html: string, inputBytes: number, topicId: number): Promise<TopicProductDecodeResult>;
}
