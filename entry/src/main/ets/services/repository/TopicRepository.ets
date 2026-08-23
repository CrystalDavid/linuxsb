import { ContentBlock, ContentBlockKind, paragraphBlock, unsupportedBlock } from '../../models/ContentBlock';
import { Author, Reply, ReplyAccess, TopicDetail, TopicPost } from '../../models/TopicModels';
import { AuthSessionPort } from '../auth/AuthSession';
import { TopicOpenTrace } from '../logging/TopicOpenTrace';
import {
  ProductDecodePort,
  ProtocolContentBlock,
  ProtocolPostDocument,
  TopicProtocolDocument,
  TopicProtocolReply
} from '../protocol/ProductProtocolModels';
import { ForumTransport, TransportErrorKind } from '../transport/ForumTransport';
import {
  RepositoryDiagnostics,
  RepositoryFailureKind,
  TopicDataSourcePort,
  TopicLoadResult
} from './RepositoryModels';

export class TopicRepository implements TopicDataSourcePort {
  private transport: ForumTransport;
  private decoder: ProductDecodePort;
  private authSession: AuthSessionPort;

  constructor(transport: ForumTransport, decoder: ProductDecodePort, authSession: AuthSessionPort) {
    this.transport = transport;
    this.decoder = decoder;
    this.authSession = authSession;
  }

  captureOfficialLogin(): boolean {
    return this.authSession.captureOfficialLogin();
  }

  async loadTopic(topicId: number): Promise<TopicLoadResult> {
    const cookieHeader = this.authSession.getRequestCookieHeader();
    TopicOpenTrace.markCacheLookupStart(cookieHeader !== undefined);
    TopicOpenTrace.markCacheLookupEnd(false);
    TopicOpenTrace.markRequestQueued();
    TopicOpenTrace.markRequestStart();
    const response = cookieHeader === undefined ? await this.transport.getTopic(topicId) :
      await this.transport.getAuthenticatedTopic(topicId, cookieHeader);
    TopicOpenTrace.markBodyComplete();
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

    TopicOpenTrace.markTaskPoolSubmit();
    const decoded = await this.decoder.decodeTopic(response.body, response.metadata.byteLength, topicId);
    TopicOpenTrace.markDecodeComplete();
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
        failure: { kind: RepositoryFailureKind.Protocol, message: 'TOPIC_PROTOCOL_MISMATCH' },
        diagnostics: diagnostics
      };
    }

    const mapped = this.mapDocument(topicId, decoded.document);
    TopicOpenTrace.markMappingComplete();
    if (mapped === undefined) {
      return {
        ok: false,
        failure: { kind: RepositoryFailureKind.Protocol, message: 'REPLY_STRUCTURE_MISMATCH' },
        diagnostics: diagnostics
      };
    }
    return { ok: true, data: mapped, diagnostics: diagnostics };
  }

  private mapDocument(topicId: number, document: TopicProtocolDocument): TopicDetail | undefined {
    const mainProtocolPost = this.findPost(document.posts, document.mainPostId);
    const mainContent = mainProtocolPost === undefined ? [unsupportedBlock('MAIN_CONTENT_MISSING')] :
      this.mapBlocks(mainProtocolPost.blocks);
    const mainPost: TopicPost = {
      postId: document.mainPostId,
      author: this.author(mainProtocolPost?.author ?? ''),
      content: mainContent.length > 0 ? mainContent : [unsupportedBlock('MAIN_CONTENT_EMPTY')]
    };

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
      replies.push({
        replyId: item.replyId,
        floor: item.floor,
        author: this.author(protocolPost?.author ?? item.author),
        content: blocks
      });
      replyIds.add(item.replyId);
    }

    const loginRequired = document.advertisedReplyCount > replies.length && replies.length === 0 &&
      document.loginVisibleMarkerCount > 0;
    if (document.advertisedReplyCount > replies.length && !loginRequired) {
      return undefined;
    }
    return {
      topicId: topicId,
      title: document.title,
      viewCount: document.viewCount,
      advertisedReplyCount: document.advertisedReplyCount,
      mainPost: mainPost,
      replies: replies,
      replyAccess: loginRequired ? ReplyAccess.LoginRequired : ReplyAccess.Visible,
      protocolVersion: document.bbsVersion
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

  private author(value: string): Author {
    return { displayName: value.length > 0 ? value : '社区用户' };
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
