import { describe, expect, it } from '@ohos/hypium';
import { ContentBlockKind, paragraphBlock } from '../main/ets/models/ContentBlock';
import { HomeFeed } from '../main/ets/models/HomeModels';
import { ReplyAccess, TopicDetail } from '../main/ets/models/TopicModels';
import { AuthSessionPort } from '../main/ets/services/auth/AuthSession';
import {
  HomeProductDecodeResult,
  HomeProtocolDocument,
  ProductDecodePort,
  ProtocolPostDocument,
  TopicProductDecodeResult,
  TopicProtocolDocument,
  TopicProtocolReply
} from '../main/ets/services/protocol/ProductProtocolModels';
import { TopicContentDecoder } from '../main/ets/services/protocol/TopicContentDecoder';
import { HomeRepository } from '../main/ets/services/repository/HomeRepository';
import {
  HomeDataSourcePort,
  HomeLoadResult,
  RepositoryFailureKind,
  TopicDataSourcePort,
  TopicLoadResult,
  emptyDiagnostics
} from '../main/ets/services/repository/RepositoryModels';
import { TopicRepository } from '../main/ets/services/repository/TopicRepository';
import {
  ForumTransport,
  TransportProbeMetadata,
  TransportProbeResponse
} from '../main/ets/services/transport/ForumTransport';
import { HomeViewModel } from '../main/ets/viewmodels/HomeViewModel';
import { TopicDetailViewModel } from '../main/ets/viewmodels/TopicDetailViewModel';
import { ViewLoadState } from '../main/ets/viewmodels/ViewState';

function metadata(statusCode: number = 200): TransportProbeMetadata {
  return {
    statusCode: statusCode,
    byteLength: 128,
    contentType: 'text/html',
    contentEncoding: '',
    elapsedMs: 12,
    effectiveUrl: 'https://linux.sb/',
    sha256: 'fixture-sha256'
  };
}

function successResponse(): TransportProbeResponse {
  return { metadata: metadata(), body: '<fixture />' };
}

function networkErrorResponse(): TransportProbeResponse {
  return {
    metadata: metadata(0),
    body: '',
    error: { kind: 'NETWORK', code: -1, message: 'synthetic network error' }
  };
}

function homeDocument(): HomeProtocolDocument {
  return {
    protocolMatched: true,
    bbsVersion: 'v8.6.5',
    topics: [{ topicId: 605, title: 'Fictitious topic', forumId: 4, forumName: 'Test forum' }],
    warnings: []
  };
}

function post(postId: number, floor: number, author: string, text: string): ProtocolPostDocument {
  return {
    postId: postId,
    floor: floor,
    author: author,
    blocks: [{ kind: 'Paragraph', text: text, url: '', description: '' }]
  };
}

function topicDocument(loginRequired: boolean, replyCount: number = 5): TopicProtocolDocument {
  const replies: TopicProtocolReply[] = [];
  const posts: ProtocolPostDocument[] = [post(605, 0, 'topic-author', 'main body')];
  if (!loginRequired) {
    for (let index = 0; index < replyCount; index++) {
      const replyId = 7101 + index;
      replies.push({ replyId: replyId, floor: index + 1, author: `user-${index + 1}`, bodyText: `reply-${index + 1}` });
      posts.push(post(replyId, index + 1, `user-${index + 1}`, `reply-${index + 1}`));
    }
  }
  return {
    protocolMatched: true,
    bbsVersion: 'v8.6.5',
    title: 'Fictitious topic',
    viewCount: 25,
    advertisedReplyCount: replyCount,
    mainPostId: 605,
    replies: replies,
    posts: posts,
    loginVisibleMarkerCount: loginRequired ? 1 : 0,
    warnings: []
  };
}

function homeDecode(document: HomeProtocolDocument = homeDocument()): HomeProductDecodeResult {
  return {
    execution: 'TASKPOOL',
    executionWarning: '',
    parseMs: 3,
    inputBytes: 128,
    document: document
  };
}

function topicDecode(document: TopicProtocolDocument): TopicProductDecodeResult {
  return {
    execution: 'TASKPOOL',
    executionWarning: '',
    parseMs: 4,
    inputBytes: 128,
    document: document
  };
}

class FakeForumTransport implements ForumTransport {
  response: TransportProbeResponse = successResponse();
  homeCalls: number = 0;
  topicCalls: number = 0;
  authenticatedTopicCalls: number = 0;

  async getHome(): Promise<TransportProbeResponse> {
    this.homeCalls++;
    return this.response;
  }

  async getTopic(_topicId: number): Promise<TransportProbeResponse> {
    this.topicCalls++;
    return this.response;
  }

  async getAuthenticatedTopic(_topicId: number, _cookieHeader: string): Promise<TransportProbeResponse> {
    this.authenticatedTopicCalls++;
    return this.response;
  }

  async getAuthenticatedNotifications(_cookieHeader: string): Promise<TransportProbeResponse> {
    return this.response;
  }

  cancelAll(): void {}

  close(): void {}
}

class FakeProductDecoder implements ProductDecodePort {
  homeResult: HomeProductDecodeResult = homeDecode();
  topicResult: TopicProductDecodeResult = topicDecode(topicDocument(true));

  async decodeHome(_html: string, _inputBytes: number): Promise<HomeProductDecodeResult> {
    return this.homeResult;
  }

  async decodeTopic(_html: string, _inputBytes: number, _topicId: number): Promise<TopicProductDecodeResult> {
    return this.topicResult;
  }
}

class FakeAuthSession implements AuthSessionPort {
  header: string | undefined = undefined;
  captureResult: boolean = false;

  getRequestCookieHeader(): string | undefined {
    return this.header;
  }

  captureOfficialLogin(): boolean {
    return this.captureResult;
  }

  clearMemory(): void {
    this.header = undefined;
  }
}

function mappedTopic(loginRequired: boolean): TopicDetail {
  return {
    topicId: 605,
    title: 'Fictitious topic',
    viewCount: 25,
    advertisedReplyCount: loginRequired ? 5 : 1,
    mainPost: {
      postId: 605,
      author: { displayName: 'topic-author' },
      content: [paragraphBlock('main body')]
    },
    replies: loginRequired ? [] : [{
      replyId: 7101,
      floor: 1,
      author: { displayName: 'user-1' },
      content: [paragraphBlock('reply-1')]
    }],
    replyAccess: loginRequired ? ReplyAccess.LoginRequired : ReplyAccess.Visible,
    protocolVersion: 'v8.6.5'
  };
}

function homeSuccess(): HomeLoadResult {
  const feed: HomeFeed = { protocolVersion: 'v8.6.5', topics: homeDocument().topics };
  return { ok: true, data: feed, diagnostics: emptyDiagnostics() };
}

class SequenceHomeDataSource implements HomeDataSourcePort {
  responses: HomeLoadResult[];
  calls: number = 0;

  constructor(responses: HomeLoadResult[]) {
    this.responses = responses;
  }

  async loadHome(): Promise<HomeLoadResult> {
    const index = Math.min(this.calls, this.responses.length - 1);
    this.calls++;
    return this.responses[index];
  }
}

class SequenceTopicDataSource implements TopicDataSourcePort {
  responses: TopicLoadResult[];
  requestedTopicIds: number[] = [];
  captureCalls: number = 0;

  constructor(responses: TopicLoadResult[]) {
    this.responses = responses;
  }

  async loadTopic(topicId: number): Promise<TopicLoadResult> {
    const index = Math.min(this.requestedTopicIds.length, this.responses.length - 1);
    this.requestedTopicIds.push(topicId);
    return this.responses[index];
  }

  captureOfficialLogin(): boolean {
    this.captureCalls++;
    return true;
  }
}

export default function m1VerticalSliceTest() {
  describe('M1 read-only vertical slice', () => {
    it('maps a successful HomeRepository response to TopicSummary', 0, async () => {
      const transport = new FakeForumTransport();
      const decoder = new FakeProductDecoder();
      const result = await new HomeRepository(transport, decoder).loadHome();
      expect(result.ok).assertTrue();
      expect(result.data?.topics.length).assertEqual(1);
      expect(result.data?.topics[0].topicId).assertEqual(605);
      expect(result.data?.topics[0].forumName).assertEqual('Test forum');
      expect(transport.homeCalls).assertEqual(1);
    });

    it('maps a HomeRepository network error to Offline', 0, async () => {
      const transport = new FakeForumTransport();
      transport.response = networkErrorResponse();
      const result = await new HomeRepository(transport, new FakeProductDecoder()).loadHome();
      expect(result.ok).assertFalse();
      expect(result.failure?.kind).assertEqual(RepositoryFailureKind.Offline);
    });

    it('maps an anonymous hidden reply response to LoginRequired', 0, async () => {
      const decoder = new FakeProductDecoder();
      decoder.topicResult = topicDecode(topicDocument(true));
      const result = await new TopicRepository(new FakeForumTransport(), decoder, new FakeAuthSession()).loadTopic(605);
      expect(result.ok).assertTrue();
      expect(result.data?.replyAccess).assertEqual(ReplyAccess.LoginRequired);
      expect(result.data?.advertisedReplyCount).assertEqual(5);
      expect(result.data?.replies.length).assertEqual(0);
    });

    it('maps five authenticated replies and uses the authenticated GET path', 0, async () => {
      const transport = new FakeForumTransport();
      const decoder = new FakeProductDecoder();
      decoder.topicResult = topicDecode(topicDocument(false));
      const auth = new FakeAuthSession();
      auth.header = 'synthetic-memory-session';
      const result = await new TopicRepository(transport, decoder, auth).loadTopic(605);
      expect(result.ok).assertTrue();
      expect(result.data?.replies.length).assertEqual(5);
      expect(result.data?.replies[4].floor).assertEqual(5);
      expect(transport.authenticatedTopicCalls).assertEqual(1);
      expect(transport.topicCalls).assertEqual(0);
    });

    it('deduplicates replies and never repeats the main post', 0, async () => {
      const document = topicDocument(false, 1);
      document.replies.push({ replyId: 7101, floor: 1, author: 'duplicate', bodyText: 'duplicate' });
      document.replies.push({ replyId: 605, floor: 2, author: 'main', bodyText: 'main duplicate' });
      const decoder = new FakeProductDecoder();
      decoder.topicResult = topicDecode(document);
      const result = await new TopicRepository(new FakeForumTransport(), decoder, new FakeAuthSession()).loadTopic(605);
      expect(result.ok).assertTrue();
      expect(result.data?.replies.length).assertEqual(1);
      expect(result.data?.replies[0].replyId).assertEqual(7101);
    });

    it('keeps LoginRequired as content instead of mapping it to Empty', 0, async () => {
      const source = new SequenceTopicDataSource([
        { ok: true, data: mappedTopic(true), diagnostics: emptyDiagnostics() }
      ]);
      const viewModel = new TopicDetailViewModel(source);
      await viewModel.load(605);
      expect(viewModel.state).assertEqual(ViewLoadState.Content);
      expect(viewModel.detail?.replyAccess).assertEqual(ReplyAccess.LoginRequired);
    });

    it('refreshes the same topic after official login completes', 0, async () => {
      const source = new SequenceTopicDataSource([
        { ok: true, data: mappedTopic(true), diagnostics: emptyDiagnostics() },
        { ok: true, data: mappedTopic(false), diagnostics: emptyDiagnostics() }
      ]);
      const viewModel = new TopicDetailViewModel(source);
      await viewModel.load(605);
      await viewModel.onOfficialLoginCompleted();
      expect(source.captureCalls).assertEqual(1);
      expect(source.requestedTopicIds.length).assertEqual(2);
      expect(source.requestedTopicIds[0]).assertEqual(605);
      expect(source.requestedTopicIds[1]).assertEqual(605);
      expect(viewModel.detail?.replies.length).assertEqual(1);
    });

    it('downgrades an unknown content extension without crashing', 0, () => {
      const fixture = '<li class="post-entry" id="post-605"><div class="post-content">before' +
        '<plugin-card>extension</plugin-card>after</div></li>';
      const posts = new TopicContentDecoder().decode(fixture);
      expect(posts.length).assertEqual(1);
      expect(posts[0].blocks.findIndex(block => block.kind === ContentBlockKind.UnsupportedExtension) >= 0).assertTrue();
    });

    it('decodes the supported ContentBlock v1 structures', 0, () => {
      const fixture = '<li class="post-entry" id="post-605"><div class="post-content">' +
        '<p>paragraph</p><br><a href="/topic/1">link</a><blockquote>quote</blockquote>' +
        '<code>inline</code><pre>code block</pre><img src="/image.png" alt="image">' +
        '</div></li>';
      const blocks = new TopicContentDecoder().decode(fixture)[0].blocks;
      expect(blocks.findIndex(block => block.kind === ContentBlockKind.Paragraph) >= 0).assertTrue();
      expect(blocks.findIndex(block => block.kind === ContentBlockKind.LineBreak) >= 0).assertTrue();
      expect(blocks.findIndex(block => block.kind === ContentBlockKind.Link) >= 0).assertTrue();
      expect(blocks.findIndex(block => block.kind === ContentBlockKind.Quote) >= 0).assertTrue();
      expect(blocks.findIndex(block => block.kind === ContentBlockKind.InlineCode) >= 0).assertTrue();
      expect(blocks.findIndex(block => block.kind === ContentBlockKind.CodeBlock) >= 0).assertTrue();
      expect(blocks.findIndex(block => block.kind === ContentBlockKind.Image) >= 0).assertTrue();
    });

    it('moves HomeViewModel from Loading to Content', 0, async () => {
      const source = new SequenceHomeDataSource([homeSuccess()]);
      const viewModel = new HomeViewModel(source);
      const pending = viewModel.load();
      expect(viewModel.state).assertEqual(ViewLoadState.Loading);
      await pending;
      expect(viewModel.state).assertEqual(ViewLoadState.Content);
      expect(viewModel.topics.length).assertEqual(1);
    });

    it('moves HomeViewModel from Error through Retry to Content', 0, async () => {
      const source = new SequenceHomeDataSource([
        {
          ok: false,
          failure: { kind: RepositoryFailureKind.Protocol, message: 'synthetic protocol error' },
          diagnostics: emptyDiagnostics()
        },
        homeSuccess()
      ]);
      const viewModel = new HomeViewModel(source);
      await viewModel.load();
      expect(viewModel.state).assertEqual(ViewLoadState.Error);
      await viewModel.retry();
      expect(viewModel.state).assertEqual(ViewLoadState.Content);
      expect(source.calls).assertEqual(2);
    });
  });
}
