export interface HomeProtocolTopic {
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

export interface ProtocolEditedMetadata {
  editorName: string;
  editedAt: string;
}

export interface ProtocolRewardExtension {
  label: string;
  url: string;
}

export interface ProtocolPostDocument {
  postId: number;
  floor: number;
  parentFloor?: number;
  author: string;
  authorId?: number;
  authorAvatarUrl?: string;
  postedAtLabel?: string;
  blocks: ProtocolContentBlock[];
  editedMetadata?: ProtocolEditedMetadata;
  rewardExtension?: ProtocolRewardExtension;
}

export interface TopicProtocolReply {
  replyId: number;
  floor: number;
  parentFloor?: number;
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
  currentPage?: number;
  pageReplyCount?: number;
  totalPages?: number;
  nextPageUrl?: string;
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
