import { AuthSession } from '../services/auth/AuthSession';
import { TopicPrefetchCoordinator } from '../services/cache/TopicPrefetchCoordinator';
import { TopicPresentationMapper } from '../services/presentation/TopicPresentationMapper';
import { ProductDecodeTaskRunner } from '../services/protocol/ProductDecodeTask';
import { HomeRepository } from '../services/repository/HomeRepository';
import { TopicRepository } from '../services/repository/TopicRepository';
import { WriteRepository, WriteResult } from '../services/repository/WriteRepository';
import { RcpForumTransport } from '../services/transport/RcpForumTransport';
import { HomeViewModel } from '../viewmodels/HomeViewModel';
import { TopicDetailViewModel } from '../viewmodels/TopicDetailViewModel';

export class M1Runtime {
  private transport: RcpForumTransport = new RcpForumTransport();
  private decoder: ProductDecodeTaskRunner = new ProductDecodeTaskRunner();
  private authSession: AuthSession = new AuthSession();
  private mapper: TopicPresentationMapper = new TopicPresentationMapper();
  private homeRepository: HomeRepository = new HomeRepository(this.transport, this.decoder, this.authSession);
  private topicRepository: TopicRepository = new TopicRepository(this.transport, this.decoder, this.authSession);
  private writeRepository: WriteRepository = new WriteRepository(this.transport, this.authSession);
  private prefetchCoordinator: TopicPrefetchCoordinator = new TopicPrefetchCoordinator(this.topicRepository, 900);
  readonly homeViewModel: HomeViewModel = new HomeViewModel(this.homeRepository, this.mapper);
  readonly forumViewModel: HomeViewModel = new HomeViewModel(this.homeRepository, this.mapper);
  readonly searchViewModel: HomeViewModel = new HomeViewModel(this.homeRepository, this.mapper);
  readonly profileViewModel: HomeViewModel = new HomeViewModel(this.homeRepository, this.mapper);
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

  createTopic(forumId: number, title: string, body: string): Promise<WriteResult> {
    return this.writeRepository.createTopic(forumId, title, body);
  }

  reply(topicId: number, body: string): Promise<WriteResult> {
    return this.writeRepository.reply(topicId, body);
  }

  close(): void {
    this.prefetchCoordinator.cancel();
    this.topicRepository.clearTopicCache();
    this.transport.close();
    this.authSession.clearMemory();
  }
}

export const m1Runtime = new M1Runtime();
