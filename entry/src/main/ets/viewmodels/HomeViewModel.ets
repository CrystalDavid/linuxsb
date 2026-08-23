import { TopicSummary } from '../models/HomeModels';
import { TopicUiModel } from '../models/presentation/ForumUiModels';
import { TopicPresentationMapper } from '../services/presentation/TopicPresentationMapper';
import { HomeDataSourcePort, RepositoryDiagnostics, RepositoryFailureKind, emptyDiagnostics } from '../services/repository/RepositoryModels';
import { ViewLoadState } from './ViewState';

@Observed
export class HomeViewModel {
  state: ViewLoadState = ViewLoadState.Idle;
  topics: TopicSummary[] = [];
  presentationTopics: TopicUiModel[] = [];
  protocolVersion: string = '';
  errorMessage: string = '';
  refreshing: boolean = false;
  diagnostics: RepositoryDiagnostics = emptyDiagnostics();
  private dataSource: HomeDataSourcePort;
  private mapper: TopicPresentationMapper;

  constructor(dataSource: HomeDataSourcePort, mapper: TopicPresentationMapper = new TopicPresentationMapper()) {
    this.dataSource = dataSource;
    this.mapper = mapper;
  }

  async load(isRefresh: boolean = false): Promise<void> {
    this.refreshing = isRefresh;
    if (!isRefresh || this.topics.length === 0) {
      this.state = ViewLoadState.Loading;
    }
    this.errorMessage = '';
    const result = await this.dataSource.loadHome();
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
    this.topics = result.data.topics;
    this.presentationTopics = this.mapper.mapSummaries(this.topics);
    this.protocolVersion = result.data.protocolVersion;
    this.state = this.topics.length === 0 ? ViewLoadState.Empty : ViewLoadState.Content;
  }

  async retry(): Promise<void> {
    await this.load(false);
  }
}
