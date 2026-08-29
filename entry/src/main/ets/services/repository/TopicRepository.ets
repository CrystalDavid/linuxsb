import { ContentBlock, ContentBlockKind, paragraphBlock, unsupportedBlock } from '../../models/ContentBlock';
import {
  Author,
  EditedMetadata,
  Reply,
  ReplyAccess,
  RewardExtension,
  TopicDetail,
  TopicPost,
  TopicReplyPage
} from '../../models/TopicModels';
import { AuthSessionPort } from '../auth/AuthSession';
import { TopicMemoryCache } from '../cache/TopicMemoryCache';
import { TopicPrefetchPort } from '../cache/TopicPrefetchCoordinator';
import { TopicOpenTrace } from '../logging/TopicOpenTrace';
import {
  ProductDecodePort,
  ProtocolContentBlock,
  ProtocolPostDocument,
  TopicProtocolDocument,
  TopicProtocolReply
} from '../protocol/ProductProtocolModels';
import {
  ForumTransport,
  TransportCachePolicy,
  TransportErrorKind,
  TransportProbeResponse
} from '../transport/ForumTransport';
import {
  RepositoryDiagnostics,
  RepositoryFailureKind,
  TopicDataSourcePort,
  TopicLoadResult
} from './RepositoryModels';

export class TopicRepository implements TopicDataSourcePort, TopicPrefetchPort {
  private transport: ForumTransport;
  private decoder: ProductDecodePort;
  private authSession: AuthSessionPort;
  private cache: TopicMemoryCache;
  private inFlight: Map<string, Promise<TopicLoadResult>> = new Map<string, Promise<TopicLoadResult>>();

  constructor(transport: ForumTransport, decoder: ProductDecodePort, authSession: AuthSessionPort,
    cache: TopicMemoryCache = new TopicMemoryCache()) {
    this.transport = transport;
    this.decoder = decoder;
    this.authSession = authSession;
    this.cache = cache;
  }

  captureOfficialLogin(): boolean {
    const wasAuthenticated = this.authSession.getRequestCookieHeader() !== undefined;
    const captured = this.authSession.captureOfficialLogin();
    const isAuthenticated = this.authSession.getRequestCookieHeader() !== undefined;
    if (captured && !wasAuthenticated && isAuthenticated) {
      this.cache.clearAnonymous();
    }
    return captured;
  }

  peekTopic(topicId: number): TopicDetail | undefined {
    const cookieHeader = this.authSession.getRequestCookieHeader();
    TopicOpenTrace.markCacheLookupStart(topicId, cookieHeader !== undefined);
    const lookup = this.cache.peek(topicId, cookieHeader !== undefined);
    TopicOpenTrace.markCacheLookupEnd(topicId, lookup.hit);
    return lookup.data;
  }

  async prefetchTopic(topicId: number): Promise<void> {
    await this.loadTopic(topicId, false);
  }

  async loadNextReplyPage(topicId: number): Promise<TopicLoadResult> {
    const cookieHeader = this.authSession.getRequestCookieHeader();
    const authenticated = cookieHeader !== undefined;
    const cached = this.cache.peek(topicId, authenticated);
    const current = cached.data;
    const nextPageUrl = current?.replyPage?.nextPageUrl ?? '';
    if (current === undefined || nextPageUrl.length === 0) {
      if (current !== undefined && (current.replyPage?.loadedReplyCount ?? current.replies.length) >=
        current.advertisedReplyCount) {
        return this.cachedResult(current, cached.ageMs);
      }
      return {
        ok: false,
        failure: { kind: RepositoryFailureKind.Protocol, message: 'REPLY_PAGE_URL_MISSING' },
        diagnostics: {
          statusCode: 0,
          networkMs: 0,
          parseMs: 0,
          inputBytes: 0,
          execution: ''
        }
      };
    }
    const key = `${authenticated ? 'auth' : 'anon'}:${topicId}:${nextPageUrl}`;
    const pending = this.inFlight.get(key);
    if (pending !== undefined) {
      const joined = await pending;
      joined.diagnostics.joinedInFlight = true;
      return joined;
    }
    const request = this.fetchAndDecode(topicId, cookieHeader, authenticated, nextPageUrl, current);
    this.inFlight.set(key, request);
    try {
      return await request;
    } finally {
      this.inFlight.delete(key);
    }
  }

  clearTopicCache(): void {
    this.cache.clear();
  }

  async loadTopic(topicId: number, forceRefresh: boolean = false): Promise<TopicLoadResult> {
    const cookieHeader = this.authSession.getRequestCookieHeader();
    const authenticated = cookieHeader !== undefined;
    if (!forceRefresh) {
      const lookup = this.cache.get(topicId, authenticated);
      if (lookup.hit && lookup.data !== undefined) {
        return {
          ok: true,
          data: lookup.data,
          diagnostics: {
            statusCode: 200,
            networkMs: 0,
            parseMs: 0,
            inputBytes: 0,
            execution: 'MEMORY_CACHE',
            cacheHit: true,
            cacheAgeMs: lookup.ageMs
          }
        };
      }
    }
    const key = `${authenticated ? 'auth' : 'anon'}:${topicId}`;
    const pending = this.inFlight.get(key);
    if (pending !== undefined) {
      const joined = await pending;
      joined.diagnostics.joinedInFlight = true;
      return joined;
    }
    const existing = this.cache.peek(topicId, authenticated).data;
    const request = this.fetchAndDecode(topicId, cookieHeader, authenticated, '', existing);
    this.inFlight.set(key, request);
    try {
      return await request;
    } finally {
      this.inFlight.delete(key);
    }
  }

  private async fetchAndDecode(topicId: number, cookieHeader: string | undefined,
    authenticated: boolean, pageUrl: string, existing: TopicDetail | undefined): Promise<TopicLoadResult> {
    TopicOpenTrace.markRequestQueued(topicId);
    TopicOpenTrace.markRequestStart(topicId);
    let response: TransportProbeResponse;
    if (pageUrl.length === 0) {
      response = cookieHeader === undefined ?
        await this.transport.getTopic(topicId, TransportCachePolicy.Product, existing !== undefined) :
        await this.transport.getAuthenticatedTopic(topicId, cookieHeader, TransportCachePolicy.Product,
          existing !== undefined);
    } else if (cookieHeader === undefined && this.transport.getTopicPage !== undefined) {
      response = await this.transport.getTopicPage(topicId, pageUrl, TransportCachePolicy.Product);
    } else if (cookieHeader !== undefined && this.transport.getAuthenticatedTopicPage !== undefined) {
      response = await this.transport.getAuthenticatedTopicPage(topicId, pageUrl, cookieHeader,
        TransportCachePolicy.Product);
    } else {
      return {
        ok: false,
        failure: { kind: RepositoryFailureKind.Protocol, message: 'REPLY_PAGE_TRANSPORT_UNAVAILABLE' },
        diagnostics: {
          statusCode: 0,
          networkMs: 0,
          parseMs: 0,
          inputBytes: 0,
          execution: ''
        }
      };
    }
    TopicOpenTrace.markBodyComplete(topicId);
    const networkDiagnostics: RepositoryDiagnostics = {
      statusCode: response.metadata.statusCode,
      networkMs: response.metadata.elapsedMs,
      parseMs: 0,
      inputBytes: response.metadata.byteLength,
      execution: ''
    };
    if (response.error !== undefined) {
      return {
        ok: false,
        failure: {
          kind: this.mapTransportFailure(response.error.kind),
          message: response.error.kind
        },
        diagnostics: networkDiagnostics
      };
    }

    if (response.metadata.statusCode === 304) {
      if (existing === undefined) {
        return {
          ok: false,
          failure: { kind: RepositoryFailureKind.Protocol, message: 'HTTP_NOT_MODIFIED_WITHOUT_CACHE' },
          diagnostics: networkDiagnostics
        };
      }
      this.cache.put(topicId, authenticated, existing);
      const result = this.cachedResult(existing, 0);
      result.diagnostics.statusCode = 304;
      result.diagnostics.execution = 'HTTP_NOT_MODIFIED';
      return result;
    }

    TopicOpenTrace.markTaskPoolSubmit(topicId);
    const decoded = await this.decoder.decodeTopic(response.body, response.metadata.byteLength, topicId);
    TopicOpenTrace.markDecodeComplete(topicId);
    const diagnostics: RepositoryDiagnostics = {
      statusCode: response.metadata.statusCode,
      networkMs: response.metadata.elapsedMs,
      parseMs: decoded.parseMs,
      inputBytes: decoded.inputBytes,
      execution: decoded.execution
    };
    if (decoded.execution !== 'TASKPOOL') {
      return {
        ok: false,
        failure: { kind: RepositoryFailureKind.TaskPool, message: 'UI_FALLBACK' },
        diagnostics: diagnostics
      };
    }
    if ((decoded.document.canonicalTopicId ?? 0) > 0 && decoded.document.canonicalTopicId !== topicId) {
      return {
        ok: false,
        failure: { kind: RepositoryFailureKind.Protocol, message: 'TOPIC_IDENTITY_MISMATCH' },
        diagnostics: diagnostics
      };
    }
    if (!decoded.document.protocolMatched) {
      return {
        ok: false,
        failure: { kind: RepositoryFailureKind.Protocol, message: 'TOPIC_PROTOCOL_MISMATCH' },
        diagnostics: diagnostics
      };
    }

    let mapped = pageUrl.length === 0 ? this.mapDocument(topicId, decoded.document) :
      this.mergeReplyPage(existing, decoded.document);
    if (pageUrl.length === 0 && mapped !== undefined && existing !== undefined) {
      mapped = this.preserveLoadedPages(mapped, existing);
    }
    if (mapped === undefined) {
      return {
        ok: false,
        failure: { kind: RepositoryFailureKind.Protocol, message: 'REPLY_STRUCTURE_MISMATCH' },
        diagnostics: diagnostics
      };
    }
    this.cache.put(topicId, authenticated, mapped);
    return { ok: true, data: mapped, diagnostics: diagnostics };
  }

  private mapDocument(topicId: number, document: TopicProtocolDocument): TopicDetail | undefined {
    const mainProtocolPost = this.findPost(document.posts, document.mainPostId);
    const mainContent = mainProtocolPost === undefined ? [unsupportedBlock('MAIN_CONTENT_MISSING')] :
      this.mapBlocks(mainProtocolPost.blocks);
    const normalizedMainContent = mainContent.length > 0 ? mainContent : [unsupportedBlock('MAIN_CONTENT_EMPTY')];
    const mainPost: TopicPost = {
      postId: document.mainPostId,
      author: this.author(mainProtocolPost?.author ?? '', mainProtocolPost?.authorId ?? 0,
        mainProtocolPost?.authorAvatarUrl ?? ''),
      postedAtLabel: mainProtocolPost?.postedAtLabel,
      content: normalizedMainContent,
      postContent: { blocks: normalizedMainContent },
      editedMetadata: this.mapEditedMetadata(mainProtocolPost),
      rewardExtension: this.mapRewardExtension(mainProtocolPost)
    };

    const replies = this.mapReplies(document);

    const loginRequired = document.advertisedReplyCount > replies.length && replies.length === 0 &&
      document.loginVisibleMarkerCount > 0;
    const currentPage = document.currentPage ?? 1;
    const totalPages = Math.max(1, document.totalPages ?? 1);
    const nextPageUrl = document.nextPageUrl ?? '';
    const paged = totalPages > 1 && (nextPageUrl.length > 0 || currentPage > 1);
    if (document.advertisedReplyCount > replies.length && !loginRequired && !paged) {
      return undefined;
    }
    const replyPage: TopicReplyPage = {
      totalReplyCount: document.advertisedReplyCount,
      currentPage: currentPage,
      pageReplyCount: document.pageReplyCount ?? replies.length,
      loadedReplyCount: replies.length,
      totalPages: totalPages,
      nextPageUrl: nextPageUrl,
      replies: replies
    };
    return {
      topicId: topicId,
      title: document.title,
      viewCount: document.viewCount,
      advertisedReplyCount: document.advertisedReplyCount,
      mainPost: mainPost,
      replies: replies,
      replyPage: replyPage,
      loginGate: loginRequired ? { replyCount: document.advertisedReplyCount } : undefined,
      replySummary: {
        totalReplyCount: document.advertisedReplyCount,
        loadedReplyCount: replies.length,
        currentPage: currentPage,
        totalPages: totalPages
      },
      replyAccess: loginRequired ? ReplyAccess.LoginRequired : ReplyAccess.Visible,
      protocolVersion: document.bbsVersion
    };
  }

  private mapReplies(document: TopicProtocolDocument): Reply[] {
    const replies: Reply[] = [];
    const replyIds = new Set<number>();
    for (let index = 0; index < document.replies.length; index++) {
      const item: TopicProtocolReply = document.replies[index];
      if (item.replyId <= 0 || item.replyId === document.mainPostId || replyIds.has(item.replyId)) {
        continue;
      }
      const protocolPost = this.findPost(document.posts, item.replyId);
      let blocks = protocolPost === undefined ? [] : this.mapBlocks(protocolPost.blocks);
      if (blocks.length === 0 && item.bodyText.length > 0) {
        blocks = [paragraphBlock(item.bodyText)];
      }
      if (blocks.length === 0) {
        blocks = [unsupportedBlock('REPLY_CONTENT_EMPTY')];
      }
      const resolvedParentFloor = (item.parentFloor ?? 0) > 0 ? item.parentFloor : protocolPost?.parentFloor;
      replies.push({
        replyId: item.replyId,
        floor: item.floor,
        parentFloor: resolvedParentFloor,
        author: this.author(protocolPost?.author ?? item.author, protocolPost?.authorId ?? 0,
          protocolPost?.authorAvatarUrl ?? ''),
        postedAtLabel: protocolPost?.postedAtLabel,
        content: blocks,
        postContent: { blocks: blocks },
        editedMetadata: this.mapEditedMetadata(protocolPost),
        rewardExtension: this.mapRewardExtension(protocolPost)
      });
      replyIds.add(item.replyId);
    }
    return replies;
  }

  private mergeReplyPage(existing: TopicDetail | undefined,
    document: TopicProtocolDocument): TopicDetail | undefined {
    if (existing === undefined || existing.replyAccess !== ReplyAccess.Visible) {
      return undefined;
    }
    const page = document.currentPage ?? 1;
    const currentPage = existing.replyPage?.currentPage ?? 1;
    if (page < currentPage || page > currentPage + 1) {
      return undefined;
    }
    const incoming = this.mapReplies(document);
    const merged: Reply[] = [];
    const replyIds = new Set<number>();
    const appendUnique = (reply: Reply): void => {
      if (reply.replyId <= 0 || reply.replyId === existing.mainPost.postId || replyIds.has(reply.replyId)) {
        return;
      }
      replyIds.add(reply.replyId);
      merged.push(reply);
    };
    for (let index = 0; index < existing.replies.length; index++) {
      appendUnique(existing.replies[index]);
    }
    for (let index = 0; index < incoming.length; index++) {
      appendUnique(incoming[index]);
    }
    const totalReplyCount = document.advertisedReplyCount;
    const totalPages = Math.max(existing.replyPage?.totalPages ?? 1, document.totalPages ?? 1);
    const nextPageUrl = document.nextPageUrl ?? '';
    const replyPage: TopicReplyPage = {
      totalReplyCount: totalReplyCount,
      currentPage: Math.max(currentPage, page),
      pageReplyCount: document.pageReplyCount ?? incoming.length,
      loadedReplyCount: merged.length,
      totalPages: totalPages,
      nextPageUrl: merged.length >= totalReplyCount ? '' : nextPageUrl,
      replies: merged
    };
    return {
      topicId: existing.topicId,
      title: document.title.length > 0 ? document.title : existing.title,
      viewCount: document.viewCount,
      advertisedReplyCount: totalReplyCount,
      mainPost: existing.mainPost,
      replies: merged,
      replyPage: replyPage,
      replySummary: {
        totalReplyCount: totalReplyCount,
        loadedReplyCount: merged.length,
        currentPage: replyPage.currentPage,
        totalPages: totalPages
      },
      replyAccess: ReplyAccess.Visible,
      protocolVersion: document.bbsVersion.length > 0 ? document.bbsVersion : existing.protocolVersion
    };
  }

  private preserveLoadedPages(fresh: TopicDetail, existing: TopicDetail): TopicDetail {
    const existingPage = existing.replyPage;
    if (existingPage === undefined || existingPage.currentPage <= 1 || fresh.replyAccess !== ReplyAccess.Visible) {
      return fresh;
    }
    const merged: Reply[] = [];
    const ids = new Set<number>();
    const appendUnique = (reply: Reply): void => {
      if (!ids.has(reply.replyId) && reply.replyId !== fresh.mainPost.postId) {
        ids.add(reply.replyId);
        merged.push(reply);
      }
    };
    for (let index = 0; index < fresh.replies.length; index++) {
      appendUnique(fresh.replies[index]);
    }
    for (let index = 0; index < existing.replies.length; index++) {
      appendUnique(existing.replies[index]);
    }
    const freshPage = fresh.replyPage as TopicReplyPage;
    const needsPageRefresh = merged.length < fresh.advertisedReplyCount;
    fresh.replies = merged;
    fresh.replyPage = {
      totalReplyCount: fresh.advertisedReplyCount,
      currentPage: existingPage.currentPage,
      pageReplyCount: freshPage.pageReplyCount,
      loadedReplyCount: merged.length,
      totalPages: freshPage.totalPages,
      nextPageUrl: needsPageRefresh ? freshPage.nextPageUrl : '',
      replies: merged
    };
    fresh.replySummary = {
      totalReplyCount: fresh.advertisedReplyCount,
      loadedReplyCount: merged.length,
      currentPage: existingPage.currentPage,
      totalPages: freshPage.totalPages
    };
    return fresh;
  }

  private mapEditedMetadata(post: ProtocolPostDocument | undefined): EditedMetadata | undefined {
    if (post?.editedMetadata === undefined) {
      return undefined;
    }
    return {
      editorName: post.editedMetadata.editorName,
      editedAt: post.editedMetadata.editedAt
    };
  }

  private mapRewardExtension(post: ProtocolPostDocument | undefined): RewardExtension | undefined {
    if (post?.rewardExtension === undefined) {
      return undefined;
    }
    return {
      label: post.rewardExtension.label,
      url: post.rewardExtension.url,
      available: false
    };
  }

  private cachedResult(data: TopicDetail, ageMs: number): TopicLoadResult {
    return {
      ok: true,
      data: data,
      diagnostics: {
        statusCode: 200,
        networkMs: 0,
        parseMs: 0,
        inputBytes: 0,
        execution: 'MEMORY_CACHE',
        cacheHit: true,
        cacheAgeMs: ageMs
      }
    };
  }

  private mapBlocks(blocks: ProtocolContentBlock[]): ContentBlock[] {
    const output: ContentBlock[] = [];
    for (let index = 0; index < blocks.length; index++) {
      const block = blocks[index];
      const kind = this.mapBlockKind(block.kind);
      output.push({
        kind: kind,
        text: block.text,
        url: block.url,
        description: block.description
      });
    }
    return output;
  }

  private mapBlockKind(value: string): ContentBlockKind {
    if (value === 'Paragraph') {
      return ContentBlockKind.Paragraph;
    }
    if (value === 'Heading') {
      return ContentBlockKind.Heading;
    }
    if (value === 'ListItem') {
      return ContentBlockKind.ListItem;
    }
    if (value === 'LineBreak') {
      return ContentBlockKind.LineBreak;
    }
    if (value === 'Link') {
      return ContentBlockKind.Link;
    }
    if (value === 'Quote') {
      return ContentBlockKind.Quote;
    }
    if (value === 'InlineCode') {
      return ContentBlockKind.InlineCode;
    }
    if (value === 'CodeBlock') {
      return ContentBlockKind.CodeBlock;
    }
    if (value === 'Image') {
      return ContentBlockKind.Image;
    }
    return ContentBlockKind.UnsupportedExtension;
  }

  private findPost(posts: ProtocolPostDocument[], postId: number): ProtocolPostDocument | undefined {
    for (let index = 0; index < posts.length; index++) {
      if (posts[index].postId === postId) {
        return posts[index];
      }
    }
    return undefined;
  }

  private author(value: string, userId: number = 0, avatarUrl: string = ''): Author {
    return {
      displayName: value.length > 0 ? value : '社区用户',
      userId: userId > 0 ? userId : undefined,
      avatarUrl: avatarUrl.length > 0 ? avatarUrl : undefined
    };
  }

  private mapTransportFailure(kind: TransportErrorKind): RepositoryFailureKind {
    if (kind === 'NETWORK' || kind === 'TIMEOUT' || kind === 'TLS') {
      return RepositoryFailureKind.Offline;
    }
    if (kind === 'HTTP_CLIENT') {
      return RepositoryFailureKind.Unauthorized;
    }
    return RepositoryFailureKind.Network;
  }
}
