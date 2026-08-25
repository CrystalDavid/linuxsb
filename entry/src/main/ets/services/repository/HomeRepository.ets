import {
  CurrentUserSummary,
  FeedScope,
  ForumSummary,
  HomeFeed,
  HomeFeedRequest,
  TopicSummary
} from '../../models/HomeModels';
import { AuthSessionPort } from '../auth/AuthSession';
import { ProductDecodePort } from '../protocol/ProductProtocolModels';
import {
  ForumTransport,
  TransportCachePolicy,
  TransportErrorKind,
  TransportProbeResponse
} from '../transport/ForumTransport';
import { ForumRouteBuilder } from '../transport/ForumRouteBuilder';
import {
  HomeDataSourcePort,
  HomeLoadResult,
  RepositoryDiagnostics,
  RepositoryFailureKind
} from './RepositoryModels';

export class HomeRepository implements HomeDataSourcePort {
  private transport: ForumTransport;
  private decoder: ProductDecodePort;
  private authSession: AuthSessionPort | undefined;

  constructor(transport: ForumTransport, decoder: ProductDecodePort, authSession?: AuthSessionPort) {
    this.transport = transport;
    this.decoder = decoder;
    this.authSession = authSession;
  }

  async loadHome(request: HomeFeedRequest = HomeFeedRequest.home()): Promise<HomeLoadResult> {
    const cookieHeader = this.authSession?.getRequestCookieHeader();
    if (this.requiresAuthentication(request) && cookieHeader === undefined) {
      return {
        ok: false,
        failure: { kind: RepositoryFailureKind.Unauthorized, message: 'LOGIN_REQUIRED' },
        diagnostics: {
          statusCode: 0,
          networkMs: 0,
          parseMs: 0,
          inputBytes: 0,
          execution: ''
        }
      };
    }
    const shouldUseGeneric = this.transport.getFeedPage !== undefined &&
      (request.scope !== FeedScope.Home || request.pageUrl.length > 0 || cookieHeader !== undefined ||
        request.sort !== HomeFeedRequest.home().sort);
    let response: TransportProbeResponse;
    if (shouldUseGeneric && this.transport.getFeedPage !== undefined) {
      response = await this.transport.getFeedPage(ForumRouteBuilder.feed(request), cookieHeader ?? '',
        TransportCachePolicy.Product);
    } else {
      response = await this.transport.getHome(TransportCachePolicy.Product);
    }
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

    const decoded = await this.decoder.decodeHome(response.body, response.metadata.byteLength);
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
    if (!decoded.document.protocolMatched) {
      return {
        ok: false,
        failure: { kind: RepositoryFailureKind.Protocol, message: 'HOME_PROTOCOL_MISMATCH' },
        diagnostics: diagnostics
      };
    }

    const topics: TopicSummary[] = [];
    for (let index = 0; index < decoded.document.topics.length; index++) {
      const item = decoded.document.topics[index];
      topics.push({
        topicId: item.topicId,
        title: item.title,
        forumId: item.forumId,
        forumName: item.forumName,
        authorId: item.authorId,
        authorName: item.authorName,
        authorAvatarUrl: item.authorAvatarUrl,
        replyCount: item.replyCount,
        lastReplyUser: item.lastReplyUser,
        lastReplyAt: item.lastReplyAt,
        isPinned: item.isPinned,
        isFeatured: item.isFeatured,
        isHot: item.isHot,
        lotteryStatus: item.lotteryStatus,
        cardStatus: item.cardStatus
      });
    }
    const forums: ForumSummary[] = [];
    const decodedForums = decoded.document.forums ?? [];
    for (let index = 0; index < decodedForums.length; index++) {
      forums.push({
        forumId: decodedForums[index].forumId,
        name: decodedForums[index].name,
        description: decodedForums[index].description,
        topicCount: decodedForums[index].topicCount,
        colorHex: decodedForums[index].colorHex
      });
    }
    let currentUser: CurrentUserSummary | undefined = undefined;
    if (decoded.document.currentUser !== undefined) {
      currentUser = {
        userId: decoded.document.currentUser.userId,
        name: decoded.document.currentUser.name,
        avatarUrl: decoded.document.currentUser.avatarUrl,
        groupName: decoded.document.currentUser.groupName,
        points: decoded.document.currentUser.points,
        bio: decoded.document.currentUser.bio
      };
    }
    const feed: HomeFeed = {
      protocolVersion: decoded.document.bbsVersion,
      topics: topics,
      forums: forums,
      currentPage: decoded.document.currentPage ?? 1,
      totalPages: decoded.document.totalPages ?? 1,
      nextPageUrl: decoded.document.nextPageUrl ?? '',
      currentUser: currentUser
    };
    return { ok: true, data: feed, diagnostics: diagnostics };
  }

  private requiresAuthentication(request: HomeFeedRequest): boolean {
    return request.scope === FeedScope.Search || request.scope === FeedScope.UserTopics ||
      request.scope === FeedScope.UserReplies;
  }

  private mapTransportFailure(kind: TransportErrorKind): RepositoryFailureKind {
    if (kind === 'NETWORK' || kind === 'TIMEOUT' || kind === 'TLS') {
      return RepositoryFailureKind.Offline;
    }
    return RepositoryFailureKind.Network;
  }
}
