import { TopicSummary } from '../../models/HomeModels';
import {
  CategoryUiModel,
  PostUiModel,
  ReplyUiModel,
  TopicDetailUiModel,
  TopicUiModel,
  UserUiModel
} from '../../models/presentation/ForumUiModels';
import { Author, Reply, TopicDetail, TopicPost } from '../../models/TopicModels';
import { RelativeTime } from '../../common/utils/RelativeTime';

export class TopicPresentationMapper {
  mapSummary(source: TopicSummary): TopicUiModel {
    const output = new TopicUiModel();
    output.topicId = source.topicId;
    output.title = source.title;
    output.author = this.mapSummaryAuthor(source);
    output.category = this.category(source.forumId, source.forumName);
    output.replyCount = source.replyCount ?? -1;
    output.lastReplyUser = source.lastReplyUser ?? '';
    output.lastReplyAt = source.lastReplyAt ?? 0;
    output.activityTimeLabel = RelativeTime.fromEpochSeconds(output.lastReplyAt);
    output.replyCountLabel = output.replyCount >= 0 ? `${output.replyCount} 回复` : '';
    const authorAndReplies: string[] = [];
    if (output.author.displayName.length > 0) {
      authorAndReplies.push(output.author.displayName);
    }
    if (output.replyCountLabel.length > 0) {
      authorAndReplies.push(output.replyCountLabel);
    }
    output.authorAndRepliesLabel = authorAndReplies.join(' · ');
    const headerActivity: string[] = [];
    if (output.activityTimeLabel.length > 0) {
      headerActivity.push(output.activityTimeLabel);
    }
    if (output.replyCountLabel.length > 0) {
      headerActivity.push(output.replyCountLabel);
    }
    output.headerActivityLabel = headerActivity.join(' · ');
    output.isPinned = source.isPinned === true;
    output.isFeatured = source.isFeatured === true;
    output.isHot = source.isHot === true;
    output.lotteryStatus = source.lotteryStatus ?? '';
    output.cardStatus = source.cardStatus ?? '';
    return output;
  }

  mapSummaries(sources: TopicSummary[]): TopicUiModel[] {
    const output: TopicUiModel[] = [];
    for (let index = 0; index < sources.length; index++) {
      output.push(this.mapSummary(sources[index]));
    }
    return output;
  }

  mapDetail(source: TopicDetail): TopicDetailUiModel {
    const output = new TopicDetailUiModel();
    output.topicId = source.topicId;
    output.title = source.title;
    output.viewCount = source.viewCount;
    output.advertisedReplyCount = source.advertisedReplyCount;
    output.mainPost = this.mapPost(source.mainPost);
    output.replyAccess = source.replyAccess;
    output.protocolVersion = source.protocolVersion;
    const replyPage = source.replyPage;
    const replies = replyPage?.replies ?? source.replies;
    output.currentPage = replyPage?.currentPage ?? 1;
    output.pageReplyCount = replyPage?.pageReplyCount ?? replies.length;
    output.loadedReplyCount = replyPage?.loadedReplyCount ?? replies.length;
    output.totalPages = replyPage?.totalPages ?? 1;
    output.nextPageUrl = replyPage?.nextPageUrl ?? '';
    const depthByFloor = new Map<number, number>();
    for (let index = 0; index < replies.length; index++) {
      const reply = this.mapReply(replies[index]);
      if (reply.parentFloor > 0) {
        const parentDepth = depthByFloor.get(reply.parentFloor) ?? 0;
        reply.threadDepth = Math.min(2, parentDepth + 1);
      }
      if (reply.floor > 0) {
        depthByFloor.set(reply.floor, reply.threadDepth);
      }
      output.replies.push(reply);
    }
    return output;
  }

  private mapSummaryAuthor(source: TopicSummary): UserUiModel {
    const author = new UserUiModel();
    author.userId = source.authorId ?? 0;
    author.displayName = source.authorName ?? '';
    author.avatarUrl = source.authorAvatarUrl ?? '';
    author.initial = this.initial(author.displayName);
    return author;
  }

  private mapPost(source: TopicPost): PostUiModel {
    const output = new PostUiModel();
    output.postId = source.postId;
    output.floor = 0;
    output.author = this.mapAuthor(source.author);
    output.postedAtLabel = source.postedAtLabel ?? '';
    output.content = source.content;
    output.editedMetadata = source.editedMetadata;
    output.rewardExtension = source.rewardExtension;
    return output;
  }

  private mapReply(source: Reply): ReplyUiModel {
    const output = new ReplyUiModel();
    output.postId = source.replyId;
    output.floor = source.floor;
    output.parentFloor = source.parentFloor ?? 0;
    output.author = this.mapAuthor(source.author);
    output.postedAtLabel = source.postedAtLabel ?? '';
    output.content = source.content;
    output.editedMetadata = source.editedMetadata;
    output.rewardExtension = source.rewardExtension;
    return output;
  }

  private mapAuthor(source: Author): UserUiModel {
    const output = new UserUiModel();
    output.userId = source.userId ?? 0;
    output.displayName = source.displayName;
    output.avatarUrl = source.avatarUrl ?? '';
    output.initial = this.initial(output.displayName);
    return output;
  }

  private category(categoryId: number, name: string): CategoryUiModel {
    const output = new CategoryUiModel();
    output.categoryId = categoryId;
    output.name = name;
    return output;
  }

  private initial(value: string): string {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed.substring(0, 1).toUpperCase() : '社';
  }
}
