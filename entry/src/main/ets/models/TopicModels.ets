import { ContentBlock } from './ContentBlock';

export interface Author {
  displayName: string;
  userId?: number;
  avatarUrl?: string;
}

export interface PostContent {
  blocks: ContentBlock[];
}

export interface EditedMetadata {
  editorName: string;
  editedAt: string;
}

export interface RewardExtension {
  label: string;
  url: string;
  available: boolean;
}

export interface LoginGate {
  replyCount: number;
}

export interface ReplySummary {
  totalReplyCount: number;
  loadedReplyCount: number;
  currentPage: number;
  totalPages: number;
}

export interface TopicPost {
  postId: number;
  author: Author;
  postedAtLabel?: string;
  content: ContentBlock[];
  postContent?: PostContent;
  editedMetadata?: EditedMetadata;
  rewardExtension?: RewardExtension;
}

export interface Reply {
  replyId: number;
  floor: number;
  parentFloor?: number;
  author: Author;
  postedAtLabel?: string;
  content: ContentBlock[];
  postContent?: PostContent;
  editedMetadata?: EditedMetadata;
  rewardExtension?: RewardExtension;
}

export interface TopicReplyPage {
  totalReplyCount: number;
  currentPage: number;
  pageReplyCount: number;
  loadedReplyCount: number;
  totalPages: number;
  nextPageUrl: string;
  replies: Reply[];
}

export enum ReplyAccess {
  Visible = 'Visible',
  LoginRequired = 'LoginRequired'
}

export interface TopicDetail {
  topicId: number;
  title: string;
  viewCount: number;
  advertisedReplyCount: number;
  mainPost: TopicPost;
  replies: Reply[];
  replyPage?: TopicReplyPage;
  loginGate?: LoginGate;
  replySummary?: ReplySummary;
  replyAccess: ReplyAccess;
  protocolVersion: string;
}
