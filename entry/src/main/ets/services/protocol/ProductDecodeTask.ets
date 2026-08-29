import { taskpool } from '@kit.ArkTS';
import { HomeProbeDecoder } from './HomeProbeDecoder';
import {
  HomeProductDecodeResult,
  HomeProtocolDocument,
  HomeProtocolForum,
  HomeProtocolTopic,
  HomeProtocolUser,
  ProductDecodePort,
  ProtocolPostDocument,
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
    const forums: HomeProtocolForum[] = [];
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
    for (let index = 0; index < decoded.forums.length; index++) {
      forums.push({
        forumId: decoded.forums[index].forumId,
        name: decoded.forums[index].name,
        description: decoded.forums[index].description,
        topicCount: decoded.forums[index].topicCount,
        colorHex: decoded.forums[index].colorHex
      });
    }
    let currentUser: HomeProtocolUser | undefined = undefined;
    if (decoded.currentUser !== undefined) {
      currentUser = {
        userId: decoded.currentUser.userId,
        name: decoded.currentUser.name,
        avatarUrl: decoded.currentUser.avatarUrl,
        groupName: decoded.currentUser.groupName,
        points: decoded.currentUser.points,
        bio: decoded.currentUser.bio
      };
    }
    const home: HomeProtocolDocument = {
      protocolMatched: decoded.protocolMatched,
      bbsVersion: decoded.bbsVersion,
      forums: forums,
      topics: topics,
      currentPage: decoded.currentPage,
      totalPages: decoded.totalPages,
      nextPageUrl: decoded.nextPageUrl,
      currentUser: currentUser,
      warnings: decoded.warnings
    };
    const wire: ProductDecodeWireResult = {
      kind: 'home',
      parseMs: Date.now() - startedAt,
      inputBytes: inputBytes,
      home: home
    };
    return JSON.stringify(wire);
  }

  const topic = new TopicProbeDecoder().decode(html, topicId);
  const structure = new TopicStructureProbe().scan(html);
  const posts = new TopicContentDecoder().decode(html);
  const replies: TopicProtocolReply[] = [];
  const replyIds = new Set<number>();
  for (let index = 0; index < topic.replies.length; index++) {
    const item = topic.replies[index];
    let matchingPost: ProtocolPostDocument | undefined = undefined;
    for (let postIndex = 0; postIndex < posts.length; postIndex++) {
      if (posts[postIndex].postId === item.replyId) {
        matchingPost = posts[postIndex];
        break;
      }
    }
    replies.push({
      replyId: item.replyId,
      floor: item.floor,
      parentFloor: (item.parentFloor ?? 0) > 0 ? item.parentFloor : matchingPost?.parentFloor,
      author: item.author.length > 0 ? item.author : (matchingPost?.author ?? ''),
      bodyText: item.bodyText
    });
    replyIds.add(item.replyId);
  }
  // The content decoder has independent post boundaries and can recover a row
  // that the compact structural probe rejected. Merge those rows instead of
  // letting one decoder silently erase valid replies and their avatars.
  for (let postIndex = 0; postIndex < posts.length; postIndex++) {
    const post = posts[postIndex];
    if (post.postId <= 0 || post.postId === topic.mainPostId || replyIds.has(post.postId)) {
      continue;
    }
    replies.push({
      replyId: post.postId,
      floor: post.floor,
      parentFloor: post.parentFloor,
      author: post.author,
      bodyText: ''
    });
    replyIds.add(post.postId);
  }
  replies.sort((left: TopicProtocolReply, right: TopicProtocolReply) => {
    if (left.floor > 0 && right.floor > 0 && left.floor !== right.floor) {
      return left.floor - right.floor;
    }
    return left.replyId - right.replyId;
  });
  const wire: ProductDecodeWireResult = {
    kind: 'topic',
    parseMs: Date.now() - startedAt,
    inputBytes: inputBytes,
    topic: {
      protocolMatched: topic.protocolMatched,
      canonicalTopicId: topic.canonicalTopicId,
      bbsVersion: structure.detectedBbsVersion,
      title: topic.title,
      viewCount: topic.viewCount,
      advertisedReplyCount: topic.advertisedReplyCount,
      mainPostId: topic.mainPostId,
      replies: replies,
      posts: posts,
      loginVisibleMarkerCount: structure.loginVisibleMarkerCount,
      currentPage: topic.currentPage,
      pageReplyCount: replies.length,
      totalPages: topic.totalPages,
      nextPageUrl: topic.nextPageUrl,
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
