import { TopicDetail } from '../models/TopicModels';
import { RepositoryDiagnostics, RepositoryFailureKind, TopicDataSourcePort, emptyDiagnostics } from '../services/repository/RepositoryModels';
import { ViewLoadState } from './ViewState';

@Observed
export class TopicDetailViewModel {
  state: ViewLoadState = ViewLoadState.Idle;
  topicId: number = 0;
  detail: TopicDetail | undefined = undefined;
  errorMessage: string = '';
  loginError: string = '';
  diagnostics: RepositoryDiagnostics = emptyDiagnostics();
  private dataSource: TopicDataSourcePort;

  constructor(dataSource: TopicDataSourcePort) {
    this.dataSource = dataSource;
  }

  async load(topicId: number): Promise<void> {
    this.topicId = topicId;
    this.state = ViewLoadState.Loading;
    this.errorMessage = '';
    const result = await this.dataSource.loadTopic(topicId);
    this.diagnostics = result.diagnostics;
    if (!result.ok || result.data === undefined) {
      this.detail = undefined;
      const failureKind = result.failure?.kind ?? RepositoryFailureKind.Network;
      this.errorMessage = result.failure?.message ?? 'UNKNOWN_TOPIC_ERROR';
      this.state = failureKind === RepositoryFailureKind.Offline ? ViewLoadState.Offline : ViewLoadState.Error;
      return;
    }
    this.detail = result.data;
    this.state = ViewLoadState.Content;
  }

  async retry(): Promise<void> {
    if (this.topicId > 0) {
      await this.load(this.topicId);
    }
  }

  async onOfficialLoginCompleted(): Promise<void> {
    this.loginError = '';
    if (!this.dataSource.captureOfficialLogin()) {
      this.loginError = '登录 Cookie 尚未就绪，请重新完成官方登录。';
      return;
    }
    if (this.topicId > 0) {
      await this.load(this.topicId);
    }
  }
}
