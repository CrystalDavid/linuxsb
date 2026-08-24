import { describe, expect, it } from '@ohos/hypium';
import { ContentBlockKind } from '../main/ets/models/ContentBlock';
import { ReplyAccess } from '../main/ets/models/TopicModels';
import { AuthSessionPort } from '../main/ets/services/auth/AuthSession';
import { TopicMemoryCache } from '../main/ets/services/cache/TopicMemoryCache';
import {
  resolveTopicDetailHeaderMode,
  TopicDetailHeaderMode
} from '../main/ets/common/ui/TopicDetailHeaderState';
import { TopicContentDecoder } from '../main/ets/services/protocol/TopicContentDecoder';
import { TopicProbeDecoder } from '../main/ets/services/protocol/TopicProbeDecoder';
import {
  HomeProductDecodeResult,
  HomeProtocolDocument,
  ProductDecodePort,
  ProtocolPostDocument,
  TopicProductDecodeResult,
  TopicProtocolDocument,
  TopicProtocolReply
} from '../main/ets/services/protocol/ProductProtocolModels';
import { TopicRepository } from '../main/ets/services/repository/TopicRepository';
import {
  ForumTransport,
  TransportCachePolicy,
  TransportProbeMetadata,
  TransportProbeResponse
} from '../main/ets/services/transport/ForumTransport';
import { TopicDetailViewModel } from '../main/ets/viewmodels/TopicDetailViewModel';

function replyMarkup(id: number, floor: number, parentFloor: number = 0): string {
  const parent = parentFloor > 0 ? ` data-quote-threads-parent-floor="${parentFloor}"` : '';
  return `<li class="post-item post-entry" id="post-${id}" data-floor="${floor}"${parent}>` +
    `<a class="post-author" href="/user/${id}">user-${floor}</a>` +
    `<div class="post-content"><p>reply-${floor}</p></div></li>`;
}

function pageFixture(total: number, page: number, count: number, firstFloor: number, includeMain: boolean): string {
  let html = '<link href="/app/assets/index.css?v=v8.6.5">' +
    `<h1 class="post-content-title">Paged fixture</h1>` +
    `<div class="post-content-stats"><span>99</span><span>${total}</span></div><ul>`;
  if (includeMain) {
    html += '<li class="post-item post-entry" id="post-15365"><a class="post-author">owner</a>' +
      '<div class="post-content"><p>main</p></div></li>';
  }
  for (let index = 0; index < count; index++) {
    html += replyMarkup(20000 + firstFloor + index, firstFloor + index);
  }
  html += '</ul>';
  if (total > count) {
    html += '<div class="pagination"><ul>' +
      `<li${page === 1 ? ' class="active"' : ''}><a href="/topic/15365?p=1">1</a></li>` +
      `<li${page === 2 ? ' class="active"' : ''}><a href="/topic/15365?p=2">2</a></li>` +
      (page === 1 ? '<li><a href="/topic/15365?p=2">下一页</a></li>' : '') + '</ul></div>';
  }
  return html;
}

function metadata(url: string = 'https://linux.sb/topic/15365'): TransportProbeMetadata {
  return {
    statusCode: 200,
    byteLength: 1024,
    contentType: 'text/html',
    contentEncoding: '',
    elapsedMs: 8,
    effectiveUrl: url,
    sha256: 'fixture'
  };
}

function response(body: string): TransportProbeResponse {
  return { metadata: metadata(), body: body };
}

function protocolDocument(total: number, page: number, count: number, firstFloor: number,
  nextPageUrl: string): TopicProtocolDocument {
  const replies: TopicProtocolReply[] = [];
  const posts: ProtocolPostDocument[] = [];
  if (page === 1) {
    posts.push({
      postId: 15365,
      floor: 0,
      author: 'owner',
      blocks: [{ kind: 'Paragraph', text: 'main', url: '', description: '' }]
    });
  }
  for (let index = 0; index < count; index++) {
    const floor = firstFloor + index;
    const replyId = 20000 + floor;
    replies.push({ replyId: replyId, floor: floor, author: `user-${floor}`, bodyText: `reply-${floor}` });
    posts.push({
      postId: replyId,
      floor: floor,
      author: `user-${floor}`,
      blocks: [{ kind: 'Paragraph', text: `reply-${floor}`, url: '', description: '' }]
    });
  }
  return {
    protocolMatched: true,
    bbsVersion: 'v8.6.5',
    title: 'Paged fixture',
    viewCount: 99,
    advertisedReplyCount: total,
    mainPostId: 15365,
    replies: replies,
    posts: posts,
    loginVisibleMarkerCount: 0,
    currentPage: page,
    pageReplyCount: count,
    totalPages: total > 50 ? 2 : 1,
    nextPageUrl: nextPageUrl,
    warnings: []
  };
}

class PageTransport implements ForumTransport {
  firstPageCalls: number = 0;
  nextPageCalls: number = 0;
  returnNotModifiedWhenConditional: boolean = false;
  lastAllowConditional: boolean = false;

  async getHome(_policy?: TransportCachePolicy): Promise<TransportProbeResponse> {
    return response('home');
  }

  async getTopic(_topicId: number, _policy?: TransportCachePolicy,
    allowConditional: boolean = false): Promise<TransportProbeResponse> {
    this.firstPageCalls++;
    this.lastAllowConditional = allowConditional;
    if (allowConditional && this.returnNotModifiedWhenConditional) {
      const notModified = metadata();
      notModified.statusCode = 304;
      notModified.byteLength = 0;
      return { metadata: notModified, body: '' };
    }
    return response('page-1');
  }

  async getAuthenticatedTopic(_topicId: number, _header: string,
    _policy?: TransportCachePolicy, allowConditional: boolean = false): Promise<TransportProbeResponse> {
    return this.getTopic(_topicId, _policy, allowConditional);
  }

  async getTopicPage(_topicId: number, _url: string,
    _policy?: TransportCachePolicy): Promise<TransportProbeResponse> {
    this.nextPageCalls++;
    return response('page-2');
  }

  async getAuthenticatedTopicPage(_topicId: number, _url: string, _header: string,
    _policy?: TransportCachePolicy): Promise<TransportProbeResponse> {
    return this.getTopicPage(_topicId, _url, _policy);
  }

  async getAuthenticatedNotifications(_header: string): Promise<TransportProbeResponse> {
    return response('notify');
  }

  cancelAll(): void {}
  close(): void {}
}

class PageDecoder implements ProductDecodePort {
  pageTwoTotal: number = 75;
  pageTwoCount: number = 25;
  failPageTwoOnce: boolean = false;
  threadedOrder: boolean = false;

  async decodeHome(_html: string, _inputBytes: number): Promise<HomeProductDecodeResult> {
    const document: HomeProtocolDocument = { protocolMatched: true, bbsVersion: 'v8.6.5', topics: [], warnings: [] };
    return { execution: 'TASKPOOL', executionWarning: '', parseMs: 1, inputBytes: 1, document: document };
  }

  async decodeTopic(html: string, _inputBytes: number, _topicId: number): Promise<TopicProductDecodeResult> {
    if (this.threadedOrder) {
      const threaded = html === 'page-2' ? protocolDocument(5, 2, 2, 4, '') :
        protocolDocument(5, 1, 3, 1, 'https://linux.sb/topic/15365?p=2');
      threaded.totalPages = 2;
      if (html === 'page-2') {
        threaded.replies = [threaded.replies[1], threaded.replies[0]];
        threaded.posts = [threaded.posts[1], threaded.posts[0]];
        threaded.replies[0].parentFloor = 1;
      } else {
        threaded.replies = [threaded.replies[0], threaded.replies[2], threaded.replies[1]];
        threaded.posts = [threaded.posts[0], threaded.posts[1], threaded.posts[3], threaded.posts[2]];
        threaded.replies[1].parentFloor = 1;
      }
      return { execution: 'TASKPOOL', executionWarning: '', parseMs: 2, inputBytes: 1024, document: threaded };
    }
    if (html === 'page-2' && this.failPageTwoOnce) {
      this.failPageTwoOnce = false;
      const failedDocument = protocolDocument(75, 2, 25, 51, '');
      failedDocument.protocolMatched = false;
      return {
        execution: 'TASKPOOL', executionWarning: '', parseMs: 1, inputBytes: 1,
        document: failedDocument
      };
    }
    const document = html === 'page-2' ? protocolDocument(this.pageTwoTotal, 2, this.pageTwoCount, 51, '') :
      protocolDocument(75, 1, 50, 1, 'https://linux.sb/topic/15365?p=2');
    return { execution: 'TASKPOOL', executionWarning: '', parseMs: 2, inputBytes: 1024, document: document };
  }
}

class AnonymousSession implements AuthSessionPort {
  getRequestCookieHeader(): string | undefined { return undefined; }
  captureOfficialLogin(): boolean { return false; }
  clearMemory(): void {}
}

export default function m2r11ContractTest() {
  describe('M2-R1.1 pagination content boundary and performance contracts', () => {
    it('accepts five replies on one page', 0, () => {
      const result = new TopicProbeDecoder().decode(pageFixture(5, 1, 5, 1, true), 15365);
      expect(result.replies.length).assertEqual(5);
      expect(result.totalPages).assertEqual(1);
      expect(result.warnings.indexOf('REPLY_STRUCTURE_MISMATCH')).assertEqual(-1);
    });

    it('accepts thirty-five replies on one page', 0, () => {
      const result = new TopicProbeDecoder().decode(pageFixture(35, 1, 35, 1, true), 15365);
      expect(result.replies.length).assertEqual(35);
      expect(result.warnings.indexOf('REPLY_STRUCTURE_MISMATCH')).assertEqual(-1);
    });

    it('recognizes seventy-five replies as a fifty plus twenty-five page contract', 0, () => {
      const first = new TopicProbeDecoder().decode(pageFixture(75, 1, 50, 1, true), 15365);
      const second = new TopicProbeDecoder().decode(pageFixture(75, 2, 25, 51, false), 15365);
      expect(first.pageReplyCount).assertEqual(50);
      expect(first.nextPageUrl).assertEqual('https://linux.sb/topic/15365?p=2');
      expect(second.mainPostId).assertEqual(15365);
      expect(second.currentPage).assertEqual(2);
      expect(second.replies[0].floor).assertEqual(51);
      expect(second.replies.length).assertEqual(25);
    });

    it('preserves quote-thread server order and captures the real parent floor', 0, () => {
      const fixture = '<h1 class="post-content-title">Threaded</h1>' +
        '<div class="post-content-stats"><span>9</span><span>3</span></div><ul>' +
        '<li class="post-entry" id="post-15365"></li>' +
        replyMarkup(20001, 1) + replyMarkup(20006, 6, 1) + replyMarkup(20002, 2) + '</ul>';
      const result = new TopicProbeDecoder().decode(fixture, 15365);
      expect(result.replies[0].floor).assertEqual(1);
      expect(result.replies[1].floor).assertEqual(6);
      expect(result.replies[1].parentFloor).assertEqual(1);
      expect(result.replies[2].floor).assertEqual(2);
    });

    it('deduplicates duplicate reply identifiers', 0, () => {
      const fixture = pageFixture(2, 1, 1, 1, true).replace('</ul>', replyMarkup(20001, 2) + '</ul>');
      const result = new TopicProbeDecoder().decode(fixture, 15365);
      expect(result.replies.length).assertEqual(1);
      expect(result.warnings.indexOf('DUPLICATE_REPLY_ID:20001') >= 0).assertTrue();
    });

    it('rejects node shortage when no pagination or login gate exists', 0, () => {
      const fixture = pageFixture(2, 1, 2, 1, true).replace('<span>2</span>', '<span>5</span>');
      const result = new TopicProbeDecoder().decode(fixture, 15365);
      expect(result.warnings.indexOf('REPLY_STRUCTURE_MISMATCH') >= 0).assertTrue();
    });

    it('keeps anonymous reply hiding as a login gate', 0, () => {
      const fixture = '<h1 class="post-content-title">Gate</h1>' +
        '<div class="post-content-stats"><span>9</span><span>5</span></div>' +
        '<li class="post-entry" id="post-15365"></li><section data-replies-login-visible="1"></section>';
      const result = new TopicProbeDecoder().decode(fixture, 15365);
      expect(result.loginVisibleMarkerCount).assertEqual(1);
      expect(result.warnings.indexOf('REPLIES_LOGIN_GATED:5') >= 0).assertTrue();
    });

    it('excludes the web expand control from post content', 0, () => {
      const fixture = '<li class="post-entry" id="post-605"><a class="post-author">author</a>' +
        '<div class="post-content"><div class="long-content-fold-content"><p>正文</p></div>' +
        '<div class="long-content-fold-actions"><button><span>展开全文</span></button></div></div></li>';
      const post = new TopicContentDecoder().decode(fixture)[0];
      expect(post.blocks.length).assertEqual(1);
      expect(post.blocks[0].text).assertEqual('正文');
    });

    it('preserves expand words authored inside the real body', 0, () => {
      const fixture = '<li class="post-entry" id="post-605"><div class="post-content">' +
        '<div class="long-content-fold-content"><p>用户正文真的写了展开全文</p></div></div></li>';
      expect(new TopicContentDecoder().decode(fixture)[0].blocks[0].text).assertEqual('用户正文真的写了展开全文');
    });

    it('separates edited metadata from the post body', 0, () => {
      const fixture = '<li class="post-entry" id="post-605"><div class="post-avatar">' +
        '<a href="/user/1"><img class="avatar-img" src="/avatar/1.jpg"></a></div>' +
        '<div class="post-body"><a class="post-author" href="/user/1">editor</a>' +
        '<div class="post-meta"><span class="quote-threads-reference">回复 #1</span>' +
        '<span data-performance-time="1">10 分钟前</span></div></div><div class="post-content">' +
        '<div class="long-content-fold-content"><p>正文</p><div class="sb-limit-edit-time-note">' +
        '最后由 <a href="/user/1">editor</a> 编辑于 now</div>' +
        '</div></div></li>';
      const post = new TopicContentDecoder().decode(fixture)[0];
      expect(post.blocks.length).assertEqual(1);
      expect(post.editedMetadata?.editorName).assertEqual('editor');
      expect(post.editedMetadata?.editedAt).assertEqual('now');
      expect(post.authorId).assertEqual(1);
      expect(post.authorAvatarUrl).assertEqual('https://linux.sb/avatar/1.jpg');
      expect(post.postedAtLabel).assertEqual('10 分钟前');
    });

    it('separates reward extension from the post body', 0, () => {
      const fixture = '<li class="post-entry" id="post-605"><div class="post-content"><p>正文</p></div>' +
        '<div class="quick-reply-main-action"><div class="donate-area" data-donate-area="605">' +
        '<a class="donate-entry" href="/donate?topic_id=605"><span>$</span><span>打赏</span></a></div></div></li>';
      const post = new TopicContentDecoder().decode(fixture)[0];
      expect(post.blocks.length).assertEqual(1);
      expect(post.rewardExtension?.label).assertEqual('打赏');
      expect(post.rewardExtension?.url).assertEqual('https://linux.sb/donate?topic_id=605');
    });

    it('downgrades unknown custom elements without polluting paragraphs', 0, () => {
      const fixture = '<li class="post-entry" id="post-605"><div class="post-content">' +
        '<p>正文</p><fictional-plugin>extension</fictional-plugin></div></li>';
      const post = new TopicContentDecoder().decode(fixture)[0];
      expect(post.blocks[0].text).assertEqual('正文');
      expect(post.blocks[1].kind).assertEqual('UnsupportedExtension');
    });

    it('merges real next-page data with unique ordered floors', 0, async () => {
      const repository = new TopicRepository(new PageTransport(), new PageDecoder(), new AnonymousSession());
      const first = await repository.loadTopic(15365);
      const complete = await repository.loadNextReplyPage(15365);
      expect(first.ok).assertTrue();
      expect(first.data?.replies.length).assertEqual(50);
      expect(complete.ok).assertTrue();
      expect(complete.data?.replies.length).assertEqual(75);
      expect(complete.data?.replies[0].floor).assertEqual(1);
      expect(complete.data?.replies[74].floor).assertEqual(75);
      expect(complete.data?.replyPage?.nextPageUrl).assertEqual('');
    });

    it('keeps BBS1 quote-thread order while appending the next page', 0, async () => {
      const decoder = new PageDecoder();
      decoder.threadedOrder = true;
      const repository = new TopicRepository(new PageTransport(), decoder, new AnonymousSession());
      expect((await repository.loadTopic(15365)).ok).assertTrue();
      const complete = await repository.loadNextReplyPage(15365);
      expect(complete.ok).assertTrue();
      expect(complete.data?.replies[0].floor).assertEqual(1);
      expect(complete.data?.replies[1].floor).assertEqual(3);
      expect(complete.data?.replies[2].floor).assertEqual(2);
      expect(complete.data?.replies[3].floor).assertEqual(5);
      expect(complete.data?.replies[4].floor).assertEqual(4);
      expect(complete.data?.replies[1].parentFloor).assertEqual(1);
    });

    it('retries page two without duplicating appended replies', 0, async () => {
      const decoder = new PageDecoder();
      decoder.failPageTwoOnce = true;
      const repository = new TopicRepository(new PageTransport(), decoder, new AnonymousSession());
      await repository.loadTopic(15365);
      expect((await repository.loadNextReplyPage(15365)).ok).assertFalse();
      const retry = await repository.loadNextReplyPage(15365);
      expect(retry.ok).assertTrue();
      expect(retry.data?.replies.length).assertEqual(75);
    });

    it('accepts a changed reply total on the next page', 0, async () => {
      const decoder = new PageDecoder();
      decoder.pageTwoTotal = 76;
      decoder.pageTwoCount = 26;
      const repository = new TopicRepository(new PageTransport(), decoder, new AnonymousSession());
      await repository.loadTopic(15365);
      const result = await repository.loadNextReplyPage(15365);
      expect(result.data?.advertisedReplyCount).assertEqual(76);
      expect(result.data?.replies.length).assertEqual(76);
    });

    it('exposes stale cache content for stale-while-revalidate', 0, () => {
      let now = 0;
      const cache = new TopicMemoryCache(20, 120000, () => now);
      const repository = new TopicRepository(new PageTransport(), new PageDecoder(), new AnonymousSession(), cache);
      cache.put(15365, false, {
        topicId: 15365, title: 'cached', viewCount: 1, advertisedReplyCount: 0,
        mainPost: { postId: 15365, author: { displayName: 'owner' }, content: [] }, replies: [],
        replyAccess: ReplyAccess.Visible, protocolVersion: 'v8.6.5'
      });
      now = 120001;
      expect(cache.get(15365, false).hit).assertFalse();
      expect(repository.peekTopic(15365)?.title).assertEqual('cached');
    });

    it('uses a conditional GET only when structured topic cache exists and consumes 304 before decoding', 0,
      async () => {
        const transport = new PageTransport();
        const repository = new TopicRepository(transport, new PageDecoder(), new AnonymousSession());
        expect((await repository.loadTopic(15365)).ok).assertTrue();
        expect(transport.lastAllowConditional).assertFalse();
        transport.returnNotModifiedWhenConditional = true;
        const refreshed = await repository.loadTopic(15365, true);
        expect(transport.lastAllowConditional).assertTrue();
        expect(refreshed.ok).assertTrue();
        expect(refreshed.data?.replies.length).assertEqual(50);
        expect(refreshed.diagnostics.execution).assertEqual('HTTP_NOT_MODIFIED');
      });

    it('mounts large reply lists in batches of ten', 0, async () => {
      const transport = new PageTransport();
      const repository = new TopicRepository(transport, new PageDecoder(), new AnonymousSession());
      const viewModel = new TopicDetailViewModel(repository);
      await viewModel.open(15365, undefined);
      expect(viewModel.presentationDetail?.replies.length).assertEqual(50);
      expect(viewModel.visibleReplies().length).assertEqual(10);
      await viewModel.onReplyListViewport(7);
      expect(viewModel.visibleReplies().length).assertEqual(10);
      expect(transport.nextPageCalls).assertEqual(0);
      await viewModel.onReplyListViewport(11);
      expect(viewModel.visibleReplies().length).assertEqual(20);
      expect(transport.nextPageCalls).assertEqual(0);
    });

    it('loads page two after mounting page one and never fetches it twice', 0, async () => {
      const transport = new PageTransport();
      const repository = new TopicRepository(transport, new PageDecoder(), new AnonymousSession());
      const viewModel = new TopicDetailViewModel(repository);
      await viewModel.open(15365, undefined);
      for (let batch = 0; batch < 4; batch++) {
        await viewModel.onReplyListReachEnd();
      }
      expect(viewModel.visibleReplies().length).assertEqual(50);
      expect(transport.nextPageCalls).assertEqual(0);
      await viewModel.onReplyListReachEnd();
      expect(transport.nextPageCalls).assertEqual(1);
      expect(viewModel.presentationDetail?.replies.length).assertEqual(75);
      expect(viewModel.visibleReplies().length).assertEqual(60);
      await viewModel.onReplyListReachEnd();
      await viewModel.onReplyListReachEnd();
      await viewModel.onReplyListReachEnd();
      expect(viewModel.visibleReplies().length).assertEqual(75);
      expect(transport.nextPageCalls).assertEqual(1);
    });

    it('switches the TopicDetailHeader between summary and collapsed title states', 0, () => {
      expect(resolveTopicDetailHeaderMode(true)).assertEqual(TopicDetailHeaderMode.Summary);
      expect(resolveTopicDetailHeaderMode(false)).assertEqual(TopicDetailHeaderMode.CollapsedTitle);
    });
  });
}
