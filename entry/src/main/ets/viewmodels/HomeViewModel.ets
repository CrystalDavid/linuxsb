import {
  CurrentUserSummary,
  ForumSummary,
  HomeFeed,
  HomeFeedRequest,
  TopicSummary
} from '../models/HomeModels';
import { TopicUiModel } from '../models/presentation/ForumUiModels';
import { TopicPresentationMapper } from '../services/presentation/TopicPresentationMapper';
import { HomeDataSourcePort, RepositoryDiagnostics, RepositoryFailureKind, emptyDiagnostics } from '../services/repository/RepositoryModels';
import { ViewLoadState } from './ViewState';

@Observed
export class HomeViewModel {
  state: ViewLoadState = ViewLoadState.Idle;
  topics: TopicSummary[] = [];
  presentationTopics: TopicUiModel[] = [];
  forums: ForumSummary[] = [];
  currentUser: CurrentUserSummary | undefined = undefined;
  protocolVersion: string = '';
  errorMessage: string = '';
  loadMoreError: string = '';
  refreshing: boolean = false;
  loadingMore: boolean = false;
  currentPage: number = 1;
  totalPages: number = 1;
  nextPageUrl: string = '';
  diagnostics: RepositoryDiagnostics = emptyDiagnostics();
  private dataSource: HomeDataSourcePort;
  private mapper: TopicPresentationMapper;
  private request: HomeFeedRequest;

  constructor(dataSource: HomeDataSourcePort, mapper: TopicPresentationMapper = new TopicPresentationMapper(),
    request: HomeFeedRequest = HomeFeedRequest.home()) {
    this.dataSource = dataSource;
    this.mapper = mapper;
    this.request = request;
  }

  configure(request: HomeFeedRequest): void {
    if (this.requestKey(this.request) === this.requestKey(request)) {
      return;
    }
    this.request = request;
    this.reset();
  }

  async load(isRefresh: boolean = false): Promise<void> {
    this.refreshing = isRefresh;
    if (!isRefresh || this.topics.length === 0) {
      this.state = ViewLoadState.Loading;
    }
    this.errorMessage = '';
    const result = await this.dataSource.loadHome(this.request);
    this.diagnostics = result.diagnostics;
    this.refreshing = false;
    if (!result.ok || result.data === undefined) {
      const failureKind = result.failure?.kind ?? RepositoryFailureKind.Network;
      this.errorMessage = result.failure?.message ?? 'UNKNOWN_HOME_ERROR';
      if (isRefresh && this.topics.length > 0) {
        this.state = ViewLoadState.Content;
      } else {
        this.state = failureKind === RepositoryFailureKind.Offline ? ViewLoadState.Offline : ViewLoadState.Error;
      }
      return;
    }
    this.applyFeed(result.data, false);
    this.state = this.topics.length === 0 ? ViewLoadState.Empty : ViewLoadState.Content;
  }

  async loadMore(): Promise<void> {
    if (this.loadingMore || this.nextPageUrl.length === 0) {
      return;
    }
    this.loadingMore = true;
    this.loadMoreError = '';
    const result = await this.dataSource.loadHome(this.request.withPage(this.nextPageUrl));
    this.loadingMore = false;
    this.diagnostics = result.diagnostics;
    if (!result.ok || result.data === undefined) {
      this.loadMoreError = result.failure?.message ?? 'LOAD_MORE_FAILED';
      return;
    }
    this.applyFeed(result.data, true);
    this.state = this.topics.length === 0 ? ViewLoadState.Empty : ViewLoadState.Content;
  }

  hasMore(): boolean {
    return this.nextPageUrl.length > 0;
  }

  async retry(): Promise<void> {
    await this.load(false);
  }

  private applyFeed(feed: HomeFeed, append: boolean): void {
    if (append) {
      const ids = new Set<number>();
      const merged: TopicSummary[] = [];
      for (let index = 0; index < this.topics.length; index++) {
        ids.add(this.topics[index].topicId);
        merged.push(this.topics[index]);
      }
      for (let index = 0; index < feed.topics.length; index++) {
        if (!ids.has(feed.topics[index].topicId)) {
          ids.add(feed.topics[index].topicId);
          merged.push(feed.topics[index]);
        }
      }
      this.topics = merged;
    } else {
      this.topics = feed.topics;
    }
    this.presentationTopics = this.mapper.mapSummaries(this.topics);
    this.protocolVersion = feed.protocolVersion;
    this.currentPage = feed.currentPage ?? 1;
    this.totalPages = feed.totalPages ?? Math.max(1, this.currentPage);
    this.nextPageUrl = feed.nextPageUrl ?? '';
    if ((feed.forums ?? []).length > 0) {
      this.forums = this.mergeForums(this.forums, feed.forums ?? []);
    }
    if (feed.currentUser !== undefined) {
      this.currentUser = feed.currentUser;
    }
  }

  private mergeForums(existing: ForumSummary[], incoming: ForumSummary[]): ForumSummary[] {
    const output: ForumSummary[] = [];
    const ids = new Set<number>();
    for (let index = 0; index < existing.length; index++) {
      if (!ids.has(existing[index].forumId)) {
        ids.add(existing[index].forumId);
        output.push(existing[index]);
      }
    }
    for (let index = 0; index < incoming.length; index++) {
      if (!ids.has(incoming[index].forumId)) {
        ids.add(incoming[index].forumId);
        output.push(incoming[index]);
      }
    }
    return output;
  }

  private reset(): void {
    this.state = ViewLoadState.Idle;
    this.topics = [];
    this.presentationTopics = [];
    this.protocolVersion = '';
    this.errorMessage = '';
    this.loadMoreError = '';
    this.refreshing = false;
    this.loadingMore = false;
    this.currentPage = 1;
    this.totalPages = 1;
    this.nextPageUrl = '';
  }

  private requestKey(request: HomeFeedRequest): string {
    return `${request.scope}:${request.sort}:${request.forumId}:${request.userId}:${request.query}:${request.searchField}`;
  }
}
