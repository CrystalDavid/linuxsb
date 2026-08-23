import { ContentBlock } from './ContentBlock';

export interface Author {
  displayName: string;
}

export interface TopicPost {
  postId: number;
  author: Author;
  content: ContentBlock[];
}

export interface Reply {
  replyId: number;
  floor: number;
  author: Author;
  content: ContentBlock[];
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
  replyAccess: ReplyAccess;
  protocolVersion: string;
}
