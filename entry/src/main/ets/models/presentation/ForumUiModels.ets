import { ContentBlock } from '../ContentBlock';
import { ReplyAccess } from '../TopicModels';

export class UserUiModel {
  userId: number = 0;
  displayName: string = '';
  avatarUrl: string = '';
  initial: string = '社';
}

export class CategoryUiModel {
  categoryId: number = 0;
  name: string = '';
}

export class TopicUiModel {
  topicId: number = 0;
  title: string = '';
  author: UserUiModel = new UserUiModel();
  category: CategoryUiModel = new CategoryUiModel();
  replyCount: number = -1;
  lastReplyUser: string = '';
  lastReplyAt: number = 0;
  isPinned: boolean = false;
  isFeatured: boolean = false;
  isHot: boolean = false;
  lotteryStatus: string = '';
  cardStatus: string = '';
}

export class PostUiModel {
  postId: number = 0;
  floor: number = 0;
  author: UserUiModel = new UserUiModel();
  content: ContentBlock[] = [];
}

export class ReplyUiModel extends PostUiModel {}

export class TopicDetailUiModel {
  topicId: number = 0;
  title: string = '';
  viewCount: number = 0;
  advertisedReplyCount: number = 0;
  mainPost: PostUiModel = new PostUiModel();
  replies: ReplyUiModel[] = [];
  replyAccess: ReplyAccess = ReplyAccess.Visible;
  protocolVersion: string = '';
}
