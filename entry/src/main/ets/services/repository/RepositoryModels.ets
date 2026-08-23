import { HomeFeed } from '../../models/HomeModels';
import { TopicDetail } from '../../models/TopicModels';

export enum RepositoryFailureKind {
  Offline = 'Offline',
  Network = 'Network',
  Protocol = 'Protocol',
  TaskPool = 'TaskPool',
  Unauthorized = 'Unauthorized'
}

export interface RepositoryFailure {
  kind: RepositoryFailureKind;
  message: string;
}

export interface RepositoryDiagnostics {
  statusCode: number;
  networkMs: number;
  parseMs: number;
  inputBytes: number;
  execution: string;
  cacheHit?: boolean;
  cacheAgeMs?: number;
  joinedInFlight?: boolean;
}

export interface HomeLoadResult {
  ok: boolean;
  data?: HomeFeed;
  failure?: RepositoryFailure;
  diagnostics: RepositoryDiagnostics;
}

export interface TopicLoadResult {
  ok: boolean;
  data?: TopicDetail;
  failure?: RepositoryFailure;
  diagnostics: RepositoryDiagnostics;
}

export interface HomeDataSourcePort {
  loadHome(): Promise<HomeLoadResult>;
}

export interface TopicDataSourcePort {
  loadTopic(topicId: number, forceRefresh?: boolean): Promise<TopicLoadResult>;
  peekTopic?(topicId: number): TopicDetail | undefined;
  loadNextReplyPage?(topicId: number): Promise<TopicLoadResult>;
  prefetchTopic?(topicId: number): Promise<void>;
  clearTopicCache?(): void;
  captureOfficialLogin(): boolean;
}

export function emptyDiagnostics(): RepositoryDiagnostics {
  return {
    statusCode: 0,
    networkMs: 0,
    parseMs: 0,
    inputBytes: 0,
    execution: ''
  };
}
