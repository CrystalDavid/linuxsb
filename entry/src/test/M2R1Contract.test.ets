import { describe, expect, it } from '@ohos/hypium';
import { paragraphBlock } from '../main/ets/models/ContentBlock';
import { TopicSummary } from '../main/ets/models/HomeModels';
import { ReplyAccess, TopicDetail } from '../main/ets/models/TopicModels';
import { TopicUiModel } from '../main/ets/models/presentation/ForumUiModels';
import { AuthSessionPort } from '../main/ets/services/auth/AuthSession';
import { TopicMemoryCache } from '../main/ets/services/cache/TopicMemoryCache';
import { TopicPrefetchCoordinator, TopicPrefetchPort } from '../main/ets/services/cache/TopicPrefetchCoordinator';
import { TopicPresentationMapper } from '../main/ets/services/presentation/TopicPresentationMapper';
import { HomeProbeDecoder } from '../main/ets/services/protocol/HomeProbeDecoder';
import {
  HomeProductDecodeResult,
  HomeProtocolDocument,
  ProductDecodePort,
  TopicProductDecodeResult,
  TopicProtocolDocument
} from '../main/ets/services/protocol/ProductProtocolModels';
import { HomeRepository } from '../main/ets/services/repository/HomeRepository';
import {
  TopicDataSourcePort,
  TopicLoadResult,
  emptyDiagnostics
} from '../main/ets/services/repository/RepositoryModels';
import { TopicRepository } from '../main/ets/services/repository/TopicRepository';
import {
  ForumTransport,
  TransportCachePolicy,
  TransportProbeMetadata,
  TransportProbeResponse
} from '../main/ets/services/transport/ForumTransport';
import { TopicDetailViewModel } from '../main/ets/viewmodels/TopicDetailViewModel';
import { ViewLoadState } from '../main/ets/viewmodels/ViewState';

const HOME_STRUCTURE_FIXTURE: string = '<link href="/app/assets/index.css?v=v8.6.5">' +
  '<li class="post-item topic-pinned">' +
  '<div class="post-avatar"><a class="avatar-profile-link" href="/user/41">' +
  '<img class="avatar-img" src="/avatar/fictional.png"></a></div>' +
  '<div class="post-title-row"><a class="post-title" href="/topic/605">Fixture topic</a>' +
  '<span class="topic-badge pinned"></span><span class="topic-stamp-badge topic-stamp-hot"></span>' +
  '<span class="community-lottery-title-status open"></span>' +
  '<span class="virtual-card-title-status active"></span></div>' +
  '<div class="post-meta"><span><a href="/user/41">user-a</a></span>' +
  '<span><a href="/forum/4">Fixture forum</a></span><span>1,234</span>' +
  '<span>user-b</span><span data-performance-time="1720000000">recent</span></div></li>';

function metadata(): TransportProbeMetadata {
  return {
    statusCode: 200,
    byteLength: 256,
    contentType: 'text/html',
    contentEncoding: '',
    elapsedMs: 10,
    effectiveUrl: 'https://linux.sb/topic/605',
    sha256: 'fixture-fingerprint'
  };
}

function response(): TransportProbeResponse {
  return { metadata: metadata(), body: '<fixture />' };
}

function detail(topicId: number = 605, title: string = 'Fixture topic'): TopicDetail {
  return {
    topicId: topicId,
    title: title,
    viewCount: 12,
    advertisedReplyCount: 1,
    mainPost: {
      postId: topicId,
      author: { displayName: 'user-a' },
      content: [paragraphBlock('main')]
    },
    replies: [{
      replyId: topicId + 1000,
      floor: 1,
      author: { displayName: 'user-b' },
      content: [paragraphBlock('reply')]
    }],
    replyAccess: ReplyAccess.Visible,
    protocolVersion: 'v8.6.5'
  };
}

function topicDocument(): TopicProtocolDocument {
  return {
    protocolMatched: true,
    bbsVersion: 'v8.6.5',
    title: 'Fixture topic',
    viewCount: 12,
    advertisedReplyCount: 1,
    mainPostId: 605,
    replies: [{ replyId: 1605, floor: 1, author: 'user-b', bodyText: 'reply' }],
    posts: [{
      postId: 605,
      floor: 0,
      author: 'user-a',
      blocks: [{ kind: 'Paragraph', text: 'main', url: '', description: '' }]
    }, {
      postId: 1605,
      floor: 1,
      author: 'user-b',
      blocks: [{ kind: 'Paragraph', text: 'reply', url: '', description: '' }]
    }],
    loginVisibleMarkerCount: 0,
    warnings: []
  };
}

class ContractTransport implements ForumTransport {
  homeCalls: number = 0;
  topicCalls: number = 0;
  authenticatedTopicCalls: number = 0;
  lastHomePolicy: TransportCachePolicy | undefined = undefined;
  lastTopicPolicy: TransportCachePolicy | undefined = undefined;

  async getHome(cachePolicy?: TransportCachePolicy): Promise<TransportProbeResponse> {
    this.homeCalls++;
    this.lastHomePolicy = cachePolicy;
    return response();
  }

  async getTopic(_topicId: number, cachePolicy?: TransportCachePolicy): Promise<TransportProbeResponse> {
    this.topicCalls++;
    this.lastTopicPolicy = cachePolicy;
    return response();
  }

  async getAuthenticatedTopic(_topicId: number, _header: string,
    cachePolicy?: TransportCachePolicy): Promise<TransportProbeResponse> {
    this.authenticatedTopicCalls++;
    this.lastTopicPolicy = cachePolicy;
    return response();
  }

  async getAuthenticatedNotifications(_header: string): Promise<TransportProbeResponse> {
    return response();
  }

  cancelAll(): void {}
  close(): void {}
}

class ContractDecoder implements ProductDecodePort {
  topicDecodeCalls: number = 0;

  async decodeHome(_html: string, _inputBytes: number): Promise<HomeProductDecodeResult> {
    const document: HomeProtocolDocument = {
      protocolMatched: true,
      bbsVersion: 'v8.6.5',
      topics: [{ topicId: 605, title: 'Fixture topic', forumId: 4, forumName: 'Fixture forum' }],
      warnings: []
    };
    return { execution: 'TASKPOOL', executionWarning: '', parseMs: 3, inputBytes: 256, document: document };
  }

  async decodeTopic(_html: string, _inputBytes: number, _topicId: number): Promise<TopicProductDecodeResult> {
    this.topicDecodeCalls++;
    return {
      execution: 'TASKPOOL',
      executionWarning: '',
      parseMs: 4,
      inputBytes: 256,
      document: topicDocument()
    };
  }
}

class ContractAuthSession implements AuthSessionPort {
  header: string | undefined = undefined;
  captureResult: boolean = false;

  getRequestCookieHeader(): string | undefined {
    return this.header;
  }

  captureOfficialLogin(): boolean {
    if (this.captureResult) {
      this.header = 'synthetic-session-marker';
    }
    return this.captureResult;
  }

  clearMemory(): void {
    this.header = undefined;
  }
}

class SingleTopicSource implements TopicDataSourcePort {
  cached: TopicDetail | undefined = undefined;
  result: TopicLoadResult = { ok: true, data: detail(), diagnostics: emptyDiagnostics() };
  requestedIds: number[] = [];
  forceRefreshes: boolean[] = [];

  peekTopic(_topicId: number): TopicDetail | undefined {
    return this.cached;
  }

  async loadTopic(topicId: number, forceRefresh: boolean = false): Promise<TopicLoadResult> {
    this.requestedIds.push(topicId);
    this.forceRefreshes.push(forceRefresh);
    return this.result;
  }

  captureOfficialLogin(): boolean {
    return true;
  }
}

class BlockingPrefetchSource implements TopicPrefetchPort {
  calls: number[] = [];
  active: number = 0;
  maxActive: number = 0;
  private releases: Array<() => void> = [];

  async prefetchTopic(topicId: number): Promise<void> {
    this.calls.push(topicId);
    this.active++;
    this.maxActive = Math.max(this.maxActive, this.active);
    await new Promise<void>((resolve: () => void) => {
      this.releases.push(() => {
        this.active--;
        resolve();
      });
    });
  }

  releaseAll(): void {
    const pending = this.releases.slice();
    this.releases = [];
    for (let index = 0; index < pending.length; index++) {
      pending[index]();
    }
  }
}

export default function m2r1ContractTest() {
  describe('M2-R1 authorized UI and topic-open contracts', () => {
    it('decodes the stable Home author avatar metadata counts and badges', 0, () => {
      const result = new HomeProbeDecoder().decode(HOME_STRUCTURE_FIXTURE);
      expect(result.protocolMatched).assertTrue();
      expect(result.topics.length).assertEqual(1);
      expect(result.topics[0].authorId).assertEqual(41);
      expect(result.topics[0].authorName).assertEqual('user-a');
      expect(result.topics[0].authorAvatarUrl).assertEqual('https://linux.sb/avatar/fictional.png');
      expect(result.topics[0].replyCount).assertEqual(1234);
      expect(result.topics[0].lastReplyUser).assertEqual('user-b');
      expect(result.topics[0].lastReplyAt).assertEqual(1720000000);
      expect(result.topics[0].isPinned).assertTrue();
      expect(result.topics[0].isHot).assertTrue();
      expect(result.topics[0].lotteryStatus).assertEqual('open');
      expect(result.topics[0].cardStatus).assertEqual('active');
    });

    it('does not invent optional Home metadata when the response omits it', 0, () => {
      const fixture = '<link href="/app/assets/index.css?v=v8.6.5">' +
        '<li class="post-item"><a class="post-title" href="/topic/9">Minimal</a></li>';
      const topic = new HomeProbeDecoder().decode(fixture).topics[0];
      expect(topic.authorName).assertEqual('');
      expect(topic.authorAvatarUrl).assertEqual('');
      expect(topic.replyCount === undefined).assertTrue();
      expect(topic.lastReplyAt).assertEqual(0);
      expect(topic.isPinned).assertFalse();
    });

    it('maps domain summaries through the Shaobing presentation adapter', 0, () => {
      const source: TopicSummary = {
        topicId: 605,
        title: 'Fixture topic',
        forumId: 4,
        forumName: 'Fixture forum',
        authorId: 41,
        authorName: 'user-a',
        authorAvatarUrl: 'https://linux.sb/avatar/fictional.png',
        replyCount: 12,
        lastReplyAt: 1720000000,
        isPinned: true,
        isHot: true
      };
      const mapped = new TopicPresentationMapper().mapSummary(source);
      expect(mapped.topicId).assertEqual(605);
      expect(mapped.author.userId).assertEqual(41);
      expect(mapped.author.initial).assertEqual('U');
      expect(mapped.category.name).assertEqual('Fixture forum');
      expect(mapped.replyCount).assertEqual(12);
      expect(mapped.isPinned).assertTrue();
      expect(mapped.isHot).assertTrue();
    });

    it('keeps the memory cache at twenty entries with LRU eviction', 0, () => {
      const cache = new TopicMemoryCache(20, 120000, () => 1000);
      for (let topicId = 1; topicId <= 20; topicId++) {
        cache.put(topicId, false, detail(topicId));
      }
      expect(cache.get(1, false).hit).assertTrue();
      cache.put(21, false, detail(21));
      expect(cache.size()).assertEqual(20);
      expect(cache.get(2, false).hit).assertFalse();
      expect(cache.get(1, false).hit).assertTrue();
      expect(cache.get(21, false).hit).assertTrue();
    });

    it('expires cache entries after the two-minute TTL', 0, () => {
      let now = 1000;
      const cache = new TopicMemoryCache(20, 120000, () => now);
      cache.put(605, false, detail());
      now = 120999;
      expect(cache.get(605, false).hit).assertTrue();
      now = 121001;
      expect(cache.get(605, false).hit).assertFalse();
    });

    it('partitions anonymous and authenticated cache entries', 0, () => {
      const cache = new TopicMemoryCache(4, 120000, () => 1000);
      cache.put(605, false, detail(605, 'Anonymous'));
      cache.put(605, true, detail(605, 'Authenticated'));
      expect(cache.get(605, false).data?.title).assertEqual('Anonymous');
      expect(cache.get(605, true).data?.title).assertEqual('Authenticated');
    });

    it('clears permission-sensitive anonymous cache after login capture', 0, () => {
      const cache = new TopicMemoryCache(4, 120000, () => 1000);
      cache.put(605, false, detail());
      const auth = new ContractAuthSession();
      auth.captureResult = true;
      const repository = new TopicRepository(new ContractTransport(), new ContractDecoder(), auth, cache);
      expect(repository.captureOfficialLogin()).assertTrue();
      expect(cache.get(605, false).hit).assertFalse();
    });

    it('deduplicates concurrent requests for the same topic and auth state', 0, async () => {
      const transport = new ContractTransport();
      const decoder = new ContractDecoder();
      const repository = new TopicRepository(transport, decoder, new ContractAuthSession());
      const results = await Promise.all([repository.loadTopic(605), repository.loadTopic(605)]);
      expect(results[0].ok).assertTrue();
      expect(results[1].ok).assertTrue();
      expect(transport.topicCalls).assertEqual(1);
      expect(decoder.topicDecodeCalls).assertEqual(1);
      expect(results[1].diagnostics.joinedInFlight === true).assertTrue();
    });

    it('serves a warm topic from memory without a second network request', 0, async () => {
      const transport = new ContractTransport();
      const repository = new TopicRepository(transport, new ContractDecoder(), new ContractAuthSession());
      await repository.loadTopic(605);
      const warm = await repository.loadTopic(605);
      expect(warm.ok).assertTrue();
      expect(warm.diagnostics.cacheHit === true).assertTrue();
      expect(warm.diagnostics.execution).assertEqual('MEMORY_CACHE');
      expect(transport.topicCalls).assertEqual(1);
    });

    it('uses the Product cache policy for formal Home and Topic requests', 0, async () => {
      const transport = new ContractTransport();
      const decoder = new ContractDecoder();
      await new HomeRepository(transport, decoder).loadHome();
      await new TopicRepository(transport, decoder, new ContractAuthSession()).loadTopic(605);
      expect(transport.lastHomePolicy).assertEqual(TransportCachePolicy.Product);
      expect(transport.lastTopicPolicy).assertEqual(TransportCachePolicy.Product);
    });

    it('shows summary-first Loading state before a cold response resolves', 0, async () => {
      const source = new SingleTopicSource();
      const viewModel = new TopicDetailViewModel(source);
      const summary = new TopicUiModel();
      summary.topicId = 605;
      summary.title = 'Summary first';
      const pending = viewModel.open(605, summary);
      expect(viewModel.state).assertEqual(ViewLoadState.Loading);
      expect(viewModel.summary?.title).assertEqual('Summary first');
      await pending;
      expect(viewModel.state).assertEqual(ViewLoadState.Content);
    });

    it('clears the previous topic before a different uncached topic starts loading', 0, async () => {
      const source = new SingleTopicSource();
      const viewModel = new TopicDetailViewModel(source);
      await viewModel.open(605, undefined);
      expect(viewModel.presentationDetail?.topicId).assertEqual(605);
      source.result = { ok: true, data: detail(606, 'Second topic'), diagnostics: emptyDiagnostics() };
      const pending = viewModel.open(606, undefined);
      expect(viewModel.state).assertEqual(ViewLoadState.Loading);
      expect(viewModel.presentationDetail === undefined).assertTrue();
      await pending;
      expect(viewModel.presentationDetail?.topicId).assertEqual(606);
    });

    it('keeps the same topic visible while its permission-aware state refreshes', 0, async () => {
      const source = new SingleTopicSource();
      const viewModel = new TopicDetailViewModel(source);
      await viewModel.open(605, undefined);
      source.result = { ok: true, data: detail(605, 'Refreshed topic'), diagnostics: emptyDiagnostics() };
      const pending = viewModel.open(605, undefined);
      expect(viewModel.state).assertEqual(ViewLoadState.Content);
      expect(viewModel.presentationDetail?.title).assertEqual('Fixture topic');
      await pending;
      expect(viewModel.presentationDetail?.title).assertEqual('Refreshed topic');
    });

    it('renders a warm cache synchronously without forcing a fresh network request', 0, async () => {
      const source = new SingleTopicSource();
      source.cached = detail(605, 'Cached');
      source.result = { ok: true, data: detail(605, 'Revalidated'), diagnostics: emptyDiagnostics() };
      const viewModel = new TopicDetailViewModel(source);
      await viewModel.open(605, undefined);
      expect(source.requestedIds.length).assertEqual(1);
      expect(source.forceRefreshes[0]).assertFalse();
      expect(viewModel.state).assertEqual(ViewLoadState.Content);
      expect(viewModel.detail?.title).assertEqual('Revalidated');
    });

    it('limits prefetch to three unique topics and two concurrent workers', 0, async () => {
      const source = new BlockingPrefetchSource();
      const coordinator = new TopicPrefetchCoordinator(source, 0);
      coordinator.schedule([1, 1, -1, 2, 3, 4]);
      expect(source.calls.length).assertEqual(2);
      expect(source.maxActive).assertEqual(2);
      source.releaseAll();
      await Promise.resolve();
      await Promise.resolve();
      expect(source.calls.length).assertEqual(3);
      source.releaseAll();
    });

    it('cancels queued prefetch work when the visible region changes', 0, async () => {
      const source = new BlockingPrefetchSource();
      const coordinator = new TopicPrefetchCoordinator(source, 0);
      coordinator.schedule([1, 2, 3]);
      expect(source.calls.length).assertEqual(2);
      coordinator.cancel();
      source.releaseAll();
      await Promise.resolve();
      await Promise.resolve();
      expect(source.calls.length).assertEqual(2);
    });

    it('does not reschedule the same visible prefetch window on every scroll callback', 0, async () => {
      const source = new BlockingPrefetchSource();
      const coordinator = new TopicPrefetchCoordinator(source, 0);
      coordinator.schedule([1, 2, 3]);
      coordinator.schedule([1, 2, 3]);
      expect(source.calls.length).assertEqual(2);
      source.releaseAll();
      await Promise.resolve();
      await Promise.resolve();
      expect(source.calls.length).assertEqual(3);
      source.releaseAll();
    });
  });
}
