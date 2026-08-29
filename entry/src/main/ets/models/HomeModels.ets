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

export interface ForumSummary {
  forumId: number;
  name: string;
  description?: string;
  topicCount?: number;
  colorHex?: string;
}

export interface CurrentUserSummary {
  userId: number;
  name: string;
  avatarUrl: string;
  groupName: string;
  points: number;
  bio: string;
}

export enum FeedScope {
  Home = 'Home',
  Forum = 'Forum',
  Search = 'Search',
  UserTopics = 'UserTopics',
  UserReplies = 'UserReplies'
}

export enum FeedSort {
  NewComments = 'comment',
  NewTopics = 'post',
  Featured = 'featured',
  Lottery = 'lucky',
  Card = 'card',
  Footprint = 'footprint'
}

export enum FeedSearchField {
  Title = 'title',
  Body = 'body',
  Reply = 'reply'
}

export class HomeFeedRequest {
  scope: FeedScope = FeedScope.Home;
  sort: FeedSort = FeedSort.NewComments;
  forumId: number = 0;
  userId: number = 0;
  query: string = '';
  searchField: FeedSearchField = FeedSearchField.Title;
  pageUrl: string = '';

  static home(sort: FeedSort = FeedSort.NewComments): HomeFeedRequest {
    const request = new HomeFeedRequest();
    request.sort = sort;
    return request;
  }

  static forum(forumId: number, sort: FeedSort = FeedSort.NewComments): HomeFeedRequest {
    const request = new HomeFeedRequest();
    request.scope = FeedScope.Forum;
    request.forumId = forumId;
    request.sort = sort;
    return request;
  }

  static search(query: string, field: FeedSearchField = FeedSearchField.Title): HomeFeedRequest {
    const request = new HomeFeedRequest();
    request.scope = FeedScope.Search;
    request.query = query.trim();
    request.searchField = field;
    return request;
  }

  static user(userId: number, replies: boolean = false): HomeFeedRequest {
    const request = new HomeFeedRequest();
    request.scope = replies ? FeedScope.UserReplies : FeedScope.UserTopics;
    request.userId = userId;
    request.sort = FeedSort.NewTopics;
    return request;
  }

  withPage(pageUrl: string): HomeFeedRequest {
    const request = new HomeFeedRequest();
    request.scope = this.scope;
    request.sort = this.sort;
    request.forumId = this.forumId;
    request.userId = this.userId;
    request.query = this.query;
    request.searchField = this.searchField;
    request.pageUrl = pageUrl;
    return request;
  }
}

export interface HomeFeed {
  protocolVersion: string;
  topics: TopicSummary[];
  forums?: ForumSummary[];
  currentPage?: number;
  totalPages?: number;
  nextPageUrl?: string;
  currentUser?: CurrentUserSummary;
}
