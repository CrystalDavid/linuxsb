import { taskpool } from '@kit.ArkTS';
import { HomeProbeDecoder } from './HomeProbeDecoder';
import {
  HomeProductDecodeResult,
  HomeProtocolDocument,
  HomeProtocolTopic,
  ProductDecodePort,
  TopicProductDecodeResult,
  TopicProtocolDocument,
  TopicProtocolReply
} from './ProductProtocolModels';
import { TopicContentDecoder } from './TopicContentDecoder';
import { TopicProbeDecoder } from './TopicProbeDecoder';
import { TopicStructureProbe } from './TopicStructureProbe';

interface ProductDecodeWireResult {
  kind: 'home' | 'topic';
  parseMs: number;
  inputBytes: number;
  home?: HomeProtocolDocument;
  topic?: TopicProtocolDocument;
}

@Concurrent
export function executeProductDecode(kind: 'home' | 'topic', html: string, inputBytes: number,
  topicId: number): string {
  const startedAt = Date.now();
  if (kind === 'home') {
    const decoded = new HomeProbeDecoder().decode(html);
    const topics: HomeProtocolTopic[] = [];
    for (let index = 0; index < decoded.topics.length; index++) {
      const item = decoded.topics[index];
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
    const wire: ProductDecodeWireResult = {
      kind: 'home',
      parseMs: Date.now() - startedAt,
      inputBytes: inputBytes,
      home: {
        protocolMatched: decoded.protocolMatched,
        bbsVersion: decoded.bbsVersion,
        topics: topics,
        warnings: decoded.warnings
      }
    };
    return JSON.stringify(wire);
  }

  const topic = new TopicProbeDecoder().decode(html, topicId);
  const structure = new TopicStructureProbe().scan(html);
  const posts = new TopicContentDecoder().decode(html);
  const replies: TopicProtocolReply[] = [];
  for (let index = 0; index < topic.replies.length; index++) {
    const item = topic.replies[index];
    replies.push({
      replyId: item.replyId,
      floor: item.floor,
      author: item.author,
      bodyText: item.bodyText
    });
  }
  const wire: ProductDecodeWireResult = {
    kind: 'topic',
    parseMs: Date.now() - startedAt,
    inputBytes: inputBytes,
    topic: {
      protocolMatched: topic.protocolMatched,
      bbsVersion: structure.detectedBbsVersion,
      title: topic.title,
      viewCount: topic.viewCount,
      advertisedReplyCount: topic.advertisedReplyCount,
      mainPostId: topic.mainPostId,
      replies: replies,
      posts: posts,
      loginVisibleMarkerCount: structure.loginVisibleMarkerCount,
      warnings: topic.warnings
    }
  };
  return JSON.stringify(wire);
}

export class ProductDecodeTaskRunner implements ProductDecodePort {
  async decodeHome(html: string, inputBytes: number): Promise<HomeProductDecodeResult> {
    try {
      const serialized = await taskpool.execute(executeProductDecode, 'home', html, inputBytes, 0) as string;
      const wire = JSON.parse(serialized) as ProductDecodeWireResult;
      return {
        execution: 'TASKPOOL',
        executionWarning: '',
        parseMs: wire.parseMs,
        inputBytes: wire.inputBytes,
        document: wire.home as HomeProtocolDocument
      };
    } catch (error) {
      const wire = JSON.parse(executeProductDecode('home', html, inputBytes, 0)) as ProductDecodeWireResult;
      return {
        execution: 'UI_FALLBACK',
        executionWarning: this.safeErrorMessage(error),
        parseMs: wire.parseMs,
        inputBytes: wire.inputBytes,
        document: wire.home as HomeProtocolDocument
      };
    }
  }

  async decodeTopic(html: string, inputBytes: number, topicId: number): Promise<TopicProductDecodeResult> {
    try {
      const serialized = await taskpool.execute(executeProductDecode, 'topic', html, inputBytes, topicId) as string;
      const wire = JSON.parse(serialized) as ProductDecodeWireResult;
      return {
        execution: 'TASKPOOL',
        executionWarning: '',
        parseMs: wire.parseMs,
        inputBytes: wire.inputBytes,
        document: wire.topic as TopicProtocolDocument
      };
    } catch (error) {
      const wire = JSON.parse(executeProductDecode('topic', html, inputBytes, topicId)) as ProductDecodeWireResult;
      return {
        execution: 'UI_FALLBACK',
        executionWarning: this.safeErrorMessage(error),
        parseMs: wire.parseMs,
        inputBytes: wire.inputBytes,
        document: wire.topic as TopicProtocolDocument
      };
    }
  }

  private safeErrorMessage(error: Object): string {
    const message = (error as Error).message;
    return message === undefined || message.length === 0 ? 'TaskPool execution failed' : message;
  }
}
