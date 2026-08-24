import { FeedScope, HomeFeedRequest } from '../../models/HomeModels';

const FORUM_ORIGIN: string = 'https://linux.sb';

export class ForumRouteBuilder {
  static feed(request: HomeFeedRequest): string {
    if (request.pageUrl.length > 0) {
      return request.pageUrl;
    }
    if (request.scope === FeedScope.Forum && request.forumId > 0) {
      return `${FORUM_ORIGIN}/forum/${request.forumId}?sort=${request.sort}`;
    }
    if ((request.scope === FeedScope.UserTopics || request.scope === FeedScope.UserReplies) && request.userId > 0) {
      const tab = request.scope === FeedScope.UserReplies ? 'replies' : 'topics';
      return `${FORUM_ORIGIN}/user/${request.userId}?tab=${tab}`;
    }
    if (request.scope === FeedScope.Search && request.query.length > 0) {
      return `${FORUM_ORIGIN}/?q=${encodeURIComponent(request.query)}&field=${request.searchField}&sort=${request.sort}`;
    }
    return `${FORUM_ORIGIN}/?sort=${request.sort}`;
  }
}
