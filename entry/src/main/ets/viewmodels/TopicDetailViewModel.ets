import { TopicDetail } from '../models/TopicModels';
import { ReplyUiModel, TopicDetailUiModel, TopicUiModel } from '../models/presentation/ForumUiModels';
import { TopicOpenTrace } from '../services/logging/TopicOpenTrace';
import { TopicPresentationMapper } from '../services/presentation/TopicPresentationMapper';
import { RepositoryDiagnostics, RepositoryFailureKind, TopicDataSourcePort, emptyDiagnostics } from '../services/repository/RepositoryModels';
import { ViewLoadState } from './ViewState';

@Observed
export class TopicDetailViewModel {
  state: ViewLoadState = ViewLoadState.Idle;
  topicId: number = 0;
  detail: TopicDetail | undefined = undefined;
  presentationDetail: TopicDetailUiModel | undefined = undefined;
  summary: TopicUiModel | undefined = undefined;
  errorMessage: string = '';
  loginError: string = '';
  loadingMore: boolean = false;
  loadMoreError: string = '';
  mountedReplyCount: number = 10;
  diagnostics: RepositoryDiagnostics = emptyDiagnostics();
  private dataSource: TopicDataSourcePort;
  private mapper: TopicPresentationMapper;
  private generation: number = 0;

  constructor(dataSource: TopicDataSourcePort, mapper: TopicPresentationMapper = new TopicPresentationMapper()) {
    this.dataSource = dataSource;
    this.mapper = mapper;
  }

  async load(topicId: number): Promise<void> {
    await this.open(topicId, undefined);
  }

  async open(topicId: number, summary: TopicUiModel | undefined): Promise<void> {
    const generation = ++this.generation;
    const preserveSameTopic = this.topicId === topicId && this.presentationDetail !== undefined;
    this.topicId = topicId;
    this.summary = summary;
    this.mountedReplyCount = 10;
    this.loadingMore = false;
    this.loadMoreError = '';
    const cached = this.dataSource.peekTopic === undefined ? undefined : this.dataSource.peekTopic(topicId);
    if (cached !== undefined) {
      this.applyDetail(cached);
      this.state = ViewLoadState.Content;
      this.errorMessage = '';
      this.refreshFromSource(topicId, true, generation, true);
      return;
    }
    if (preserveSameTopic) {
      this.state = ViewLoadState.Content;
      this.errorMessage = '';
      await this.refreshFromSource(topicId, false, generation, true);
      return;
    }
    this.detail = undefined;
    this.presentationDetail = undefined;
    this.state = ViewLoadState.Loading;
    this.errorMessage = '';
    await this.refreshFromSource(topicId, false, generation, false);
  }

  private async refreshFromSource(topicId: number, forceRefresh: boolean, generation: number,
    preserveContentOnError: boolean): Promise<void> {
    const result = await this.dataSource.loadTopic(topicId, forceRefresh);
    if (generation !== this.generation || topicId !== this.topicId) {
      return;
    }
    this.diagnostics = result.diagnostics;
    if (!result.ok || result.data === undefined) {
      if (preserveContentOnError && this.detail !== undefined) {
        return;
      }
      this.detail = undefined;
      this.presentationDetail = undefined;
      const failureKind = result.failure?.kind ?? RepositoryFailureKind.Network;
      this.errorMessage = result.failure?.message ?? 'UNKNOWN_TOPIC_ERROR';
      this.state = failureKind === RepositoryFailureKind.Offline ? ViewLoadState.Offline : ViewLoadState.Error;
      TopicOpenTrace.fail(this.errorMessage);
      return;
    }
    this.applyDetail(result.data);
    this.state = ViewLoadState.Content;
  }

  private applyDetail(detail: TopicDetail): void {
    this.detail = detail;
    this.presentationDetail = this.mapper.mapDetail(detail);
    TopicOpenTrace.markMappingComplete(detail.topicId);
  }

  visibleReplies(): ReplyUiModel[] {
    const replies = this.presentationDetail?.replies ?? [];
    return replies.slice(0, Math.min(this.mountedReplyCount, replies.length));
  }

  async onReplyListViewport(lastVisibleListIndex: number): Promise<void> {
    // The first four list items are spacer, topic summary, main post and reply summary.
    const visibleReplyIndex = lastVisibleListIndex - 4;
    const triggerReplyIndex = Math.max(0, this.mountedReplyCount - 3);
    if (visibleReplyIndex < triggerReplyIndex) {
      return;
    }
    await this.onReplyListReachEnd();
  }

  async onReplyListReachEnd(): Promise<void> {
    const detail = this.presentationDetail;
    if (detail === undefined) {
      return;
    }
    if (this.mountedReplyCount < detail.replies.length) {
      this.mountedReplyCount = Math.min(detail.replies.length, this.mountedReplyCount + 10);
      return;
    }
    if (detail.nextPageUrl.length === 0 || this.loadingMore || this.dataSource.loadNextReplyPage === undefined) {
      return;
    }
    this.loadingMore = true;
    this.loadMoreError = '';
    const result = await this.dataSource.loadNextReplyPage(this.topicId);
    this.loadingMore = false;
    if (!result.ok || result.data === undefined) {
      this.loadMoreError = result.failure?.message ?? 'REPLY_PAGE_LOAD_FAILED';
      return;
    }
    this.diagnostics = result.diagnostics;
    this.applyDetail(result.data);
    this.mountedReplyCount = Math.min(result.data.replies.length, this.mountedReplyCount + 10);
  }

  async retryLoadMore(): Promise<void> {
    this.loadMoreError = '';
    await this.onReplyListReachEnd();
  }

  async retry(): Promise<void> {
    if (this.topicId > 0) {
      const generation = ++this.generation;
      this.state = ViewLoadState.Loading;
      this.mountedReplyCount = 10;
      await this.refreshFromSource(this.topicId, true, generation, false);
    }
  }

  async onOfficialLoginCompleted(): Promise<void> {
    this.loginError = '';
    if (!this.dataSource.captureOfficialLogin()) {
      this.loginError = '登录 Cookie 尚未就绪，请重新完成官方登录。';
      return;
    }
    if (this.topicId > 0) {
      const generation = ++this.generation;
      const preserveContent = this.presentationDetail !== undefined;
      this.state = preserveContent ? ViewLoadState.Content : ViewLoadState.Loading;
      await this.refreshFromSource(this.topicId, true, generation, preserveContent);
    }
  }
}
