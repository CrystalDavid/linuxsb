import { AuthSession } from '../services/auth/AuthSession';
import { TopicPrefetchCoordinator } from '../services/cache/TopicPrefetchCoordinator';
import { TopicPresentationMapper } from '../services/presentation/TopicPresentationMapper';
import { ProductDecodeTaskRunner } from '../services/protocol/ProductDecodeTask';
import { HomeRepository } from '../services/repository/HomeRepository';
import { TopicRepository } from '../services/repository/TopicRepository';
import { RcpForumTransport } from '../services/transport/RcpForumTransport';
import { HomeViewModel } from '../viewmodels/HomeViewModel';
import { TopicDetailViewModel } from '../viewmodels/TopicDetailViewModel';

export class M1Runtime {
  private transport: RcpForumTransport = new RcpForumTransport();
  private decoder: ProductDecodeTaskRunner = new ProductDecodeTaskRunner();
  private authSession: AuthSession = new AuthSession();
  private mapper: TopicPresentationMapper = new TopicPresentationMapper();
  private homeRepository: HomeRepository = new HomeRepository(this.transport, this.decoder);
  private topicRepository: TopicRepository = new TopicRepository(this.transport, this.decoder, this.authSession);
  private prefetchCoordinator: TopicPrefetchCoordinator = new TopicPrefetchCoordinator(this.topicRepository);
  readonly homeViewModel: HomeViewModel = new HomeViewModel(this.homeRepository, this.mapper);
  readonly topicViewModel: TopicDetailViewModel = new TopicDetailViewModel(this.topicRepository, this.mapper);

  prefetchTopics(topicIds: number[]): void {
    this.prefetchCoordinator.schedule(topicIds);
  }

  cancelPrefetch(): void {
    this.prefetchCoordinator.cancel();
  }

  hasMemorySession(): boolean {
    return this.authSession.getRequestCookieHeader() !== undefined;
  }

  captureOfficialLogin(): boolean {
    return this.topicRepository.captureOfficialLogin();
  }

  close(): void {
    this.prefetchCoordinator.cancel();
    this.topicRepository.clearTopicCache();
    this.transport.close();
    this.authSession.clearMemory();
  }
}

export const m1Runtime = new M1Runtime();
