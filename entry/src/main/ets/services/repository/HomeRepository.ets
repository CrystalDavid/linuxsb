import { HomeFeed, TopicSummary } from '../../models/HomeModels';
import { ProductDecodePort } from '../protocol/ProductProtocolModels';
import { ForumTransport, TransportCachePolicy, TransportErrorKind } from '../transport/ForumTransport';
import {
  HomeDataSourcePort,
  HomeLoadResult,
  RepositoryDiagnostics,
  RepositoryFailureKind
} from './RepositoryModels';

export class HomeRepository implements HomeDataSourcePort {
  private transport: ForumTransport;
  private decoder: ProductDecodePort;

  constructor(transport: ForumTransport, decoder: ProductDecodePort) {
    this.transport = transport;
    this.decoder = decoder;
  }

  async loadHome(): Promise<HomeLoadResult> {
    const response = await this.transport.getHome(TransportCachePolicy.Product);
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
    const feed: HomeFeed = {
      protocolVersion: decoded.document.bbsVersion,
      topics: topics
    };
    return { ok: true, data: feed, diagnostics: diagnostics };
  }

  private mapTransportFailure(kind: TransportErrorKind): RepositoryFailureKind {
    if (kind === 'NETWORK' || kind === 'TIMEOUT' || kind === 'TLS') {
      return RepositoryFailureKind.Offline;
    }
    return RepositoryFailureKind.Network;
  }
}
