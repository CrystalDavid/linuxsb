import { AuthSession } from '../services/auth/AuthSession';
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
  private homeRepository: HomeRepository = new HomeRepository(this.transport, this.decoder);
  private topicRepository: TopicRepository = new TopicRepository(this.transport, this.decoder, this.authSession);
  readonly homeViewModel: HomeViewModel = new HomeViewModel(this.homeRepository);
  readonly topicViewModel: TopicDetailViewModel = new TopicDetailViewModel(this.topicRepository);

  close(): void {
    this.transport.close();
    this.authSession.clearMemory();
  }
}

export const m1Runtime = new M1Runtime();
