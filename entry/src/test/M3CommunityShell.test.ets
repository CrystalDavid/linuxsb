import { describe, expect, it } from '@ohos/hypium';
import {
  FeedScope,
  FeedSearchField,
  FeedSort,
  HomeFeed,
  HomeFeedRequest,
  TopicSummary
} from '../main/ets/models/HomeModels';
import { AuthSessionPort } from '../main/ets/services/auth/AuthSession';
import {
  HomeProductDecodeResult,
  HomeProtocolDocument,
  ProductDecodePort,
  TopicProductDecodeResult,
  TopicProtocolDocument
} from '../main/ets/services/protocol/ProductProtocolModels';
import { HomeProbeDecoder } from '../main/ets/services/protocol/HomeProbeDecoder';
import { HomeRepository } from '../main/ets/services/repository/HomeRepository';
import { WriteRepository } from '../main/ets/services/repository/WriteRepository';
import {
  HomeDataSourcePort,
  HomeLoadResult,
  RepositoryFailureKind,
  emptyDiagnostics
} from '../main/ets/services/repository/RepositoryModels';
import {
  ForumFormFields,
  ForumTransport,
  TransportCachePolicy,
  TransportProbeMetadata,
  TransportProbeResponse
} from '../main/ets/services/transport/ForumTransport';
import { ForumRouteBuilder } from '../main/ets/services/transport/ForumRouteBuilder';
import { HomeViewModel } from '../main/ets/viewmodels/HomeViewModel';

function metadata(url: string = 'https://linux.sb/'): TransportProbeMetadata {
  return {
    statusCode: 200,
    byteLength: 128,
    contentType: 'text/html',
    contentEncoding: '',
    elapsedMs: 4,
    effectiveUrl: url,
    sha256: 'fixture'
  };
}

function response(url: string = 'https://linux.sb/'): TransportProbeResponse {
  return { metadata: metadata(url), body: '<fixture />' };
}

function topic(id: number): TopicSummary {
  return { topicId: id, title: `虚构主题 ${id}`, forumId: 4, forumName: '虚构板块' };
}

function feed(ids: number[], nextPageUrl: string = '', currentPage: number = 1): HomeFeed {
  const topics: TopicSummary[] = [];
  for (let index = 0; index < ids.length; index++) {
    topics.push(topic(ids[index]));
  }
  return {
    protocolVersion: 'v8.6.5',
    topics: topics,
    currentPage: currentPage,
    totalPages: nextPageUrl.length > 0 ? currentPage + 1 : currentPage,
    nextPageUrl: nextPageUrl
  };
}

class SequenceHomeSource implements HomeDataSourcePort {
  responses: HomeLoadResult[];
  requests: HomeFeedRequest[] = [];

  constructor(responses: HomeLoadResult[]) {
    this.responses = responses;
  }

  async loadHome(request: HomeFeedRequest = HomeFeedRequest.home()): Promise<HomeLoadResult> {
    this.requests.push(request);
    return this.responses[Math.min(this.requests.length - 1, this.responses.length - 1)];
  }
}

class FeedTransport implements ForumTransport {
  homeCalls: number = 0;
  feedCalls: number = 0;
  lastFeedUrl: string = '';
  lastCookieHeader: string = '';

  async getHome(_policy?: TransportCachePolicy): Promise<TransportProbeResponse> {
    this.homeCalls++;
    return response();
  }

  async getFeedPage(pageUrl: string, cookieHeader: string = ''): Promise<TransportProbeResponse> {
    this.feedCalls++;
    this.lastFeedUrl = pageUrl;
    this.lastCookieHeader = cookieHeader;
    return response(pageUrl);
  }

  async getTopic(_topicId: number): Promise<TransportProbeResponse> { return response(); }
  async getAuthenticatedTopic(_topicId: number, _cookieHeader: string): Promise<TransportProbeResponse> {
    return response();
  }
  async getAuthenticatedNotifications(_cookieHeader: string): Promise<TransportProbeResponse> { return response(); }
  cancelAll(): void {}
  close(): void {}
}

class FeedDecoder implements ProductDecodePort {
  homeDocument: HomeProtocolDocument = {
    protocolMatched: true,
    bbsVersion: 'v8.6.5',
    topics: [],
    warnings: []
  };

  async decodeHome(_html: string, _inputBytes: number): Promise<HomeProductDecodeResult> {
    return {
      execution: 'TASKPOOL', executionWarning: '', parseMs: 1, inputBytes: 128,
      document: this.homeDocument
    };
  }

  async decodeTopic(_html: string, _inputBytes: number, _topicId: number): Promise<TopicProductDecodeResult> {
    const document: TopicProtocolDocument = {
      protocolMatched: false, bbsVersion: '', title: '', viewCount: 0, advertisedReplyCount: 0,
      mainPostId: 0, replies: [], posts: [], loginVisibleMarkerCount: 0, warnings: []
    };
    return { execution: 'TASKPOOL', executionWarning: '', parseMs: 1, inputBytes: 1, document: document };
  }
}

class TestSession implements AuthSessionPort {
  header: string | undefined = undefined;
  csrf: string | undefined = undefined;

  getRequestCookieHeader(): string | undefined { return this.header; }
  getCsrfToken(): string | undefined { return this.csrf; }
  captureOfficialLogin(): boolean { return false; }
  clearMemory(): void {
    this.header = undefined;
    this.csrf = undefined;
  }
}

class WriteTransport extends FeedTransport {
  postCalls: number = 0;
  lastPostUrl: string = '';
  lastFields: ForumFormFields | undefined = undefined;

  async postForm(pageUrl: string, fields: ForumFormFields,
    _cookieHeader: string): Promise<TransportProbeResponse> {
    this.postCalls++;
    this.lastPostUrl = pageUrl;
    this.lastFields = fields;
    return response(fields.topic_id !== undefined ?
      `https://linux.sb/topic/${fields.topic_id}` : 'https://linux.sb/topic/9001');
  }
}

function homeMarkup(count: number): string {
  let html = '<link href="/app/assets/index.css?v=v8.6.5"><nav>' +
    '<a href="/forum/1">板块一</a><a href="/forum/4">板块四</a></nav><ul>';
  for (let index = 1; index <= count; index++) {
    html += `<li class="post-item"><div class="post-avatar"><img src="/avatar/${index}.png"></div>` +
      `<a class="post-title" href="/topic/${index}">主题 ${index}</a>` +
      '<div class="post-meta"><span><a href="/user/7">作者</a></span>' +
      '<span><a href="/forum/4">板块四</a></span><span>3</span><span>最后回复者</span>' +
      '<span data-performance-time="123">刚刚</span></div></li>';
  }
  return html + '</ul><div class="pagination"><ul>' +
    '<li class="active"><a href="/index.php?sort=comment&amp;p=1">1</a></li>' +
    '<li><a href="/index.php?sort=comment&amp;p=2">2</a></li>' +
    '<li><a href="/index.php?sort=comment&amp;p=50">50</a></li>' +
    '<li><a href="/index.php?sort=comment&amp;p=2">下一页</a></li></ul></div>';
}

export default function m3CommunityShellTest() {
  describe('M3 native community shell contracts', () => {
    it('decodes more than one server page size without a thirty-topic client cap', 0, () => {
      const result = new HomeProbeDecoder().decode(homeMarkup(35));
      expect(result.protocolMatched).assertTrue();
      expect(result.topics.length).assertEqual(35);
      expect(result.topics[34].topicId).assertEqual(35);
    });

    it('extracts the real next page href and page count', 0, () => {
      const result = new HomeProbeDecoder().decode(homeMarkup(2));
      expect(result.currentPage).assertEqual(1);
      expect(result.totalPages).assertEqual(50);
      expect(result.nextPageUrl).assertEqual('https://linux.sb/index.php?sort=comment&p=2');
    });

    it('accepts a real empty-state page as an empty feed', 0, () => {
      const result = new HomeProbeDecoder().decode(
        '<link href="/app/assets/index.css?v=v8.6.5"><li class="empty-state">没有主题</li>');
      expect(result.protocolMatched).assertTrue();
      expect(result.topics.length).assertEqual(0);
      expect(result.warnings.indexOf('HOME_TOPIC_LIST_MISSING')).assertEqual(-1);
    });

    it('decodes the signed-in user card and real external avatar URL', 0, () => {
      const fixture = '<link href="/app/assets/index.css?v=v8.6.5">' +
        '<div class="user-card"><a class="user-avatar-big" href="/user/42">' +
        '<img src="https://avatars.example.test/user-42.png"></a>' +
        '<a class="user-name" href="/user/42">虚构用户</a>' +
        '<div class="user-rank">普通用户 · 积分 88</div></div>' +
        '<div class="sidebar-bio">虚构简介</div><li class="empty-state">没有主题</li>';
      const result = new HomeProbeDecoder().decode(fixture);
      expect(result.currentUser?.userId).assertEqual(42);
      expect(result.currentUser?.name).assertEqual('虚构用户');
      expect(result.currentUser?.avatarUrl).assertEqual('https://avatars.example.test/user-42.png');
      expect(result.currentUser?.groupName).assertEqual('普通用户');
      expect(result.currentUser?.points).assertEqual(88);
      expect(result.currentUser?.bio).assertEqual('虚构简介');
    });

    it('builds only verified home forum search and user feed routes', 0, () => {
      expect(ForumRouteBuilder.feed(HomeFeedRequest.home(FeedSort.NewTopics)))
        .assertEqual('https://linux.sb/?sort=post');
      expect(ForumRouteBuilder.feed(HomeFeedRequest.forum(4)))
        .assertEqual('https://linux.sb/forum/4?sort=comment');
      expect(ForumRouteBuilder.feed(HomeFeedRequest.search('蓝色 UI', FeedSearchField.Body)))
        .assertEqual('https://linux.sb/?q=%E8%93%9D%E8%89%B2%20UI&field=body&sort=comment');
      expect(ForumRouteBuilder.feed(HomeFeedRequest.user(42, true)))
        .assertEqual('https://linux.sb/user/42?tab=replies');
    });

    it('appends the next home page and removes duplicate topic ids', 0, async () => {
      const next = 'https://linux.sb/index.php?sort=comment&p=2';
      const source = new SequenceHomeSource([
        { ok: true, data: feed([1, 2], next, 1), diagnostics: emptyDiagnostics() },
        { ok: true, data: feed([2, 3], '', 2), diagnostics: emptyDiagnostics() }
      ]);
      const viewModel = new HomeViewModel(source);
      await viewModel.load();
      await viewModel.loadMore();
      expect(viewModel.topics.length).assertEqual(3);
      expect(viewModel.topics[2].topicId).assertEqual(3);
      expect(source.requests[1].pageUrl).assertEqual(next);
      expect(viewModel.hasMore()).assertFalse();
    });

    it('rejects search before transport when no memory login exists', 0, async () => {
      const transport = new FeedTransport();
      const result = await new HomeRepository(transport, new FeedDecoder(), new TestSession())
        .loadHome(HomeFeedRequest.search('虚构关键词'));
      expect(result.ok).assertFalse();
      expect(result.failure?.kind).assertEqual(RepositoryFailureKind.Unauthorized);
      expect(transport.feedCalls).assertEqual(0);
    });

    it('uses the authenticated generic feed path for search', 0, async () => {
      const transport = new FeedTransport();
      const decoder = new FeedDecoder();
      const session = new TestSession();
      session.header = 'synthetic-session';
      const request = HomeFeedRequest.search('虚构关键词', FeedSearchField.Reply);
      const result = await new HomeRepository(transport, decoder, session).loadHome(request);
      expect(result.ok).assertTrue();
      expect(transport.feedCalls).assertEqual(1);
      expect(transport.lastFeedUrl).assertEqual(ForumRouteBuilder.feed(request));
      expect(transport.lastCookieHeader).assertEqual('synthetic-session');
    });

    it('does not attempt a write without both in-memory session values', 0, async () => {
      const transport = new WriteTransport();
      const result = await new WriteRepository(transport, new TestSession()).reply(605, '虚构回复');
      expect(result.ok).assertFalse();
      expect(transport.postCalls).assertEqual(0);
    });

    it('maps create and reply fields to the verified form contracts using only a fake transport', 0, async () => {
      const transport = new WriteTransport();
      const session = new TestSession();
      session.header = 'synthetic-session';
      session.csrf = 'synthetic-csrf';
      const repository = new WriteRepository(transport, session);
      const created = await repository.createTopic(4, '虚构标题', '虚构正文');
      expect(created.ok).assertTrue();
      expect(created.topicId).assertEqual(9001);
      expect(transport.lastPostUrl).assertEqual('https://linux.sb/topic_edit');
      expect(transport.lastFields?.forum_id).assertEqual(4);
      expect(transport.lastFields?.title).assertEqual('虚构标题');
      expect(transport.lastFields?.body).assertEqual('虚构正文');
      const replied = await repository.reply(605, '虚构回复');
      expect(replied.ok).assertTrue();
      expect(transport.lastPostUrl).assertEqual('https://linux.sb/reply_edit');
      expect(transport.lastFields?.topic_id).assertEqual(605);
      expect(transport.lastFields?._csrf).assertEqual('synthetic-csrf');
    });
  });
}
