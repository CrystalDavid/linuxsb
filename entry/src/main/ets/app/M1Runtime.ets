import { common } from '@kit.AbilityKit';
import { AuthSession } from '../services/auth/AuthSession';
import { cookieSessionBroker } from '../services/auth/CookieSessionBroker';
import { SessionProbe } from '../services/auth/SessionProbe';
import { TopicPrefetchCoordinator } from '../services/cache/TopicPrefetchCoordinator';
import { TopicPresentationMapper } from '../services/presentation/TopicPresentationMapper';
import { ProductDecodeTaskRunner } from '../services/protocol/ProductDecodeTask';
import { HomeRepository } from '../services/repository/HomeRepository';
import { TopicRepository } from '../services/repository/TopicRepository';
import { WriteRepository, WriteResult, WriteVerificationPort } from '../services/repository/WriteRepository';
import { RcpForumTransport } from '../services/transport/RcpForumTransport';
import { HomeViewModel } from '../viewmodels/HomeViewModel';
import { TopicDetailViewModel } from '../viewmodels/TopicDetailViewModel';

const SESSION_PROBE_MIN_INTERVAL_MS: number = 60000;

class HomeWriteVerifier implements WriteVerificationPort {
  private homeRepository: HomeRepository;

  constructor(homeRepository: HomeRepository) {
    this.homeRepository = homeRepository;
  }

  findTopicByTitle(forumId: number, title: string): Promise<number> {
    return this.homeRepository.findTopicByTitle(forumId, title);
  }
}

export class M1Runtime {
  private transport: RcpForumTransport = new RcpForumTransport();
  private decoder: ProductDecodeTaskRunner = new ProductDecodeTaskRunner();
  private authSession: AuthSession = new AuthSession();
  private mapper: TopicPresentationMapper = new TopicPresentationMapper();
  private homeRepository: HomeRepository = new HomeRepository(this.transport, this.decoder, this.authSession);
  private topicRepository: TopicRepository = new TopicRepository(this.transport, this.decoder, this.authSession);
  private writeRepository: WriteRepository = new WriteRepository(this.transport, this.authSession,
    new HomeWriteVerifier(this.homeRepository), () => this.handleSessionInvalidated());
  private prefetchCoordinator: TopicPrefetchCoordinator = new TopicPrefetchCoordinator(this.topicRepository, 900);
  private sessionProbe: SessionProbe = new SessionProbe(this.transport, cookieSessionBroker);
  private lastSessionProbeAt: number = 0;
  private sessionProbeInFlight: Promise<boolean> | undefined = undefined;
  onSessionStateChanged: ((authenticated: boolean) => void) | undefined = undefined;
  readonly homeViewModel: HomeViewModel = new HomeViewModel(this.homeRepository, this.mapper);
  readonly forumViewModel: HomeViewModel = new HomeViewModel(this.homeRepository, this.mapper);
  readonly searchViewModel: HomeViewModel = new HomeViewModel(this.homeRepository, this.mapper);
  readonly profileViewModel: HomeViewModel = new HomeViewModel(this.homeRepository, this.mapper);
  readonly topicViewModel: TopicDetailViewModel = new TopicDetailViewModel(this.topicRepository, this.mapper);

  initialize(context: common.UIAbilityContext): void {
    this.homeRepository.configurePersistentCache(context);
  }

  prefetchTopics(topicIds: number[]): void {
    this.prefetchCoordinator.schedule(topicIds);
  }

  cancelPrefetch(): void {
    this.prefetchCoordinator.cancel();
  }

  hasMemorySession(): boolean {
    return this.authSession.getRequestCookieHeader() !== undefined;
  }

  // ArkWeb persists the official-login cookies on disk. Re-read them into the
  // memory header on cold start so a returning user does not face login gates
  // until they manually reopen the official login page.
  restorePersistedSession(): boolean {
    if (this.hasMemorySession()) {
      return true;
    }
    this.topicRepository.captureOfficialLogin();
    return this.hasMemorySession();
  }

  verifyActiveSession(force: boolean = false): Promise<boolean> {
    if (this.sessionProbeInFlight !== undefined) {
      return this.sessionProbeInFlight;
    }
    const now = Date.now();
    if (!force && now - this.lastSessionProbeAt < SESSION_PROBE_MIN_INTERVAL_MS) {
      return Promise.resolve(this.hasMemorySession());
    }
    if (!this.hasMemorySession()) {
      this.notifySessionState(false);
      return Promise.resolve(false);
    }
    this.lastSessionProbeAt = now;
    const probe = this.verifyActiveSessionInternal();
    this.sessionProbeInFlight = probe;
    probe.then(() => {
      this.sessionProbeInFlight = undefined;
    }, () => {
      this.sessionProbeInFlight = undefined;
    });
    return probe;
  }

  handleSessionInvalidated(): void {
    if (this.hasMemorySession()) {
      this.authSession.clearMemory();
      this.notifySessionState(false);
    }
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

  private async verifyActiveSessionInternal(): Promise<boolean> {
    const result = await this.sessionProbe.verify(false);
    if (result.attempted && !result.serverRecognized) {
      this.authSession.clearMemory();
      this.notifySessionState(false);
      return false;
    }
    if (result.serverRecognized) {
      this.notifySessionState(true);
      return true;
    }
    return this.hasMemorySession();
  }

  private notifySessionState(authenticated: boolean): void {
    this.onSessionStateChanged?.(authenticated);
  }
}

export const m1Runtime = new M1Runtime();
