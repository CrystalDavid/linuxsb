import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { AuthSession } from '../services/auth/AuthSession';
import { cookieSessionBroker } from '../services/auth/CookieSessionBroker';
import { SessionProbe } from '../services/auth/SessionProbe';
import { TopicPrefetchCoordinator } from '../services/cache/TopicPrefetchCoordinator';
import { TopicPresentationMapper } from '../services/presentation/TopicPresentationMapper';
import { ProductDecodeTaskRunner } from '../services/protocol/ProductDecodeTask';
import { PortalDecodeTaskRunner } from '../services/protocol/PortalDecodeTask';
import { HomeRepository } from '../services/repository/HomeRepository';
import { TopicRepository } from '../services/repository/TopicRepository';
import { PortalRepository } from '../services/repository/PortalRepository';
import {
  AttachmentUploadResult,
  WriteRepository,
  WriteResult,
  WriteVerificationPort
} from '../services/repository/WriteRepository';
import { TransportUploadFile } from '../services/transport/ForumTransport';
import { RcpForumTransport } from '../services/transport/RcpForumTransport';
import { HomeViewModel } from '../viewmodels/HomeViewModel';
import { TopicDetailViewModel } from '../viewmodels/TopicDetailViewModel';
import { PortalAction, PortalActionResult, PortalLoadResult } from '../models/PortalModels';
import { ContentBlock } from '../models/ContentBlock';
import { TopicDetail } from '../models/TopicModels';

const SESSION_PROBE_MIN_INTERVAL_MS: number = 60000;
// 相册原图长边常常 4000+，单张可达数 MB，是"上传慢"的主要来源。上传前统一
// 缩到长边不超过该值并重编码，体积通常能小一个数量级。
const MAX_UPLOAD_IMAGE_EDGE: number = 1600;
const UPLOAD_IMAGE_JPEG_QUALITY: number = 85;

class HomeWriteVerifier implements WriteVerificationPort {
  private homeRepository: HomeRepository;
  private topicRepository: TopicRepository;

  constructor(homeRepository: HomeRepository, topicRepository: TopicRepository) {
    this.homeRepository = homeRepository;
    this.topicRepository = topicRepository;
  }

  findTopicByTitle(forumId: number, title: string): Promise<number> {
    return this.homeRepository.findTopicByTitle(forumId, title);
  }

  // 回复提交后服务端往往不返回可识别的主题地址，直接重新读取主题页（跳过
  // 缓存）确认这条回复是否已经出现，避免把已发出的回复报成失败。
  async hasReplyInTopic(topicId: number, bodySnippet: string): Promise<boolean> {
    if (topicId <= 0 || bodySnippet.length === 0) {
      return false;
    }
    const result = await this.topicRepository.loadTopic(topicId, true);
    if (!result.ok || result.data === undefined) {
      return false;
    }
    return topicContainsSnippet(result.data, bodySnippet);
  }
}

// 把主题正文与所有回复的文字/图片地址拼接成一段纯文本，用于判断刚提交的
// 内容是否已经出现在页面上。
function topicContainsSnippet(topic: TopicDetail, snippet: string): boolean {
  const haystack = collectTopicText(topic).replace(/\s+/g, ' ');
  return haystack.indexOf(snippet) >= 0;
}

function collectTopicText(topic: TopicDetail): string {
  let text = blocksToText(topic.mainPost.content);
  const replies = topic.replies;
  for (let index = 0; index < replies.length; index++) {
    text += ` ${blocksToText(replies[index].content)}`;
  }
  return text;
}

function blocksToText(blocks: ContentBlock[]): string {
  let text = '';
  for (let index = 0; index < blocks.length; index++) {
    const block = blocks[index];
    text += ` ${block.text} ${block.url}`;
  }
  return text;
}

function imageExtensionFromUri(sourceUri: string): string {
  const queryStart = sourceUri.indexOf('?');
  const path = queryStart >= 0 ? sourceUri.substring(0, queryStart) : sourceUri;
  const dot = path.lastIndexOf('.');
  if (dot < 0 || dot === path.length - 1) {
    return 'jpg';
  }
  const extension = path.substring(dot + 1).toLowerCase();
  if (extension === 'png' || extension === 'webp' || extension === 'gif' || extension === 'jpeg') {
    return extension === 'jpeg' ? 'jpg' : extension;
  }
  return 'jpg';
}

function imageContentTypeFromExtension(extension: string): string {
  if (extension === 'png') {
    return 'image/png';
  }
  if (extension === 'webp') {
    return 'image/webp';
  }
  if (extension === 'gif') {
    return 'image/gif';
  }
  return 'image/jpeg';
}

export class M1Runtime {
  private transport: RcpForumTransport = new RcpForumTransport();
  private decoder: ProductDecodeTaskRunner = new ProductDecodeTaskRunner();
  private authSession: AuthSession = new AuthSession();
  private abilityContext: common.UIAbilityContext | undefined = undefined;
  private uploadSequence: number = 0;
  private mapper: TopicPresentationMapper = new TopicPresentationMapper();
  private homeRepository: HomeRepository = new HomeRepository(this.transport, this.decoder, this.authSession);
  private topicRepository: TopicRepository = new TopicRepository(this.transport, this.decoder, this.authSession);
  private writeRepository: WriteRepository = new WriteRepository(this.transport, this.authSession,
    new HomeWriteVerifier(this.homeRepository, this.topicRepository), () => this.handleSessionInvalidated());
  private portalRepository: PortalRepository = new PortalRepository(this.transport, this.authSession,
    new PortalDecodeTaskRunner(), () => this.handleSessionInvalidated());
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
    this.abilityContext = context;
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

  reportReply(replyId: number, reasonType: string, details: string = ''): Promise<WriteResult> {
    return this.writeRepository.reportReply(replyId, reasonType, details);
  }

  loadPortal(path: string): Promise<PortalLoadResult> {
    return this.portalRepository.load(path);
  }

  submitPortalAction(action: PortalAction,
    overrides: Record<string, string | number | boolean | string[]> = {}): Promise<PortalActionResult> {
    return this.portalRepository.submit(action, overrides);
  }

  async uploadAvatar(sourceUri: string): Promise<PortalActionResult> {
    const context = this.abilityContext;
    if (context === undefined) {
      return { ok: false, message: '头像上传服务不可用' };
    }
    const staged = await this.stagePickedAvatar(context, sourceUri);
    if (staged === undefined) {
      return { ok: false, message: '无法读取所选头像' };
    }
    return this.portalRepository.uploadAvatar(staged);
  }

  // Copies a picker URI into the app sandbox and uploads it to the external
  // image bed (anonymous, no forum credentials). The forum session only gates
  // the final topic/reply submission, not the image upload itself. Only called
  // from an explicit user action in an editor.
  async uploadImage(sourceUri: string): Promise<AttachmentUploadResult> {
    const context = this.abilityContext;
    if (context === undefined) {
      return { ok: false, markdown: '', message: '上传服务不可用', networkMs: 0 };
    }
    const staged = await this.stagePickedImage(context, sourceUri);
    if (staged === undefined) {
      return { ok: false, markdown: '', message: '无法读取所选图片', networkMs: 0 };
    }
    return this.writeRepository.uploadAttachment(staged);
  }

  private async stagePickedImage(context: common.UIAbilityContext,
    sourceUri: string): Promise<TransportUploadFile | undefined> {
    const extension = imageExtensionFromUri(sourceUri);
    this.uploadSequence++;
    const fileName = `upload_${Date.now()}_${this.uploadSequence}.${extension}`;
    const sandboxPath = `${context.cacheDir}/${fileName}`;
    try {
      const source = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      try {
        const destination = fileIo.openSync(sandboxPath,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          fileIo.copyFileSync(source.fd, destination.fd);
        } finally {
          fileIo.closeSync(destination);
        }
      } finally {
        fileIo.closeSync(source);
      }
    } catch (_) {
      return undefined;
    }
    // 原图先落盘保证可用，再尝试压缩一份更小的用于上传。
    const compressedFileName = `compressed_${Date.now()}_${this.uploadSequence}.jpg`;
    const compressedPath = `${context.cacheDir}/${compressedFileName}`;
    if (await this.compressStagedImage(sandboxPath, compressedPath, extension)) {
      return {
        fileName: compressedFileName,
        contentType: imageContentTypeFromExtension('jpg'),
        path: compressedPath
      };
    }
    return {
      fileName: fileName,
      contentType: imageContentTypeFromExtension(extension),
      path: sandboxPath
    };
  }

  private async stagePickedAvatar(context: common.UIAbilityContext,
    sourceUri: string): Promise<TransportUploadFile | undefined> {
    this.uploadSequence++;
    const fileName = `avatar_${Date.now()}_${this.uploadSequence}.jpg`;
    const targetPath = `${context.cacheDir}/${fileName}`;
    let source: fileIo.File | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      source = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      const imageSource = image.createImageSource(source.fd);
      const info = imageSource.getImageInfoSync();
      const side = Math.min(info.size.width, info.size.height);
      if (side <= 0) {
        return undefined;
      }
      pixelMap = imageSource.createPixelMapSync({
        desiredRegion: {
          x: Math.floor((info.size.width - side) / 2),
          y: Math.floor((info.size.height - side) / 2),
          size: { width: side, height: side }
        },
        desiredSize: { width: 200, height: 200 }
      });
      const packer = image.createImagePacker();
      const packed = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 90 });
      const output = fileIo.openSync(targetPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(output.fd, packed);
      } finally {
        fileIo.closeSync(output);
      }
      return { fileName: fileName, contentType: 'image/jpeg', path: targetPath, fieldName: 'avatar' };
    } catch (_) {
      return undefined;
    } finally {
      if (pixelMap !== undefined) {
        try { pixelMap.release(); } catch (_) {}
      }
      if (source !== undefined) {
        try { fileIo.closeSync(source); } catch (_) {}
      }
    }
  }

  // 缩放 + JPEG 重编码。GIF 不压缩以保留动画；任何环节失败、或压缩后反而
  // 更大，都返回 false 让调用方回退到原图，不影响可用性。
  private async compressStagedImage(sourcePath: string, targetPath: string,
    extension: string): Promise<boolean> {
    if (extension === 'gif') {
      return false;
    }
    let source: fileIo.File | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
      const originalSize = fileIo.statSync(sourcePath).size;
      const imageSource = image.createImageSource(source.fd);
      const info = imageSource.getImageInfoSync();
      const longEdge = Math.max(info.size.width, info.size.height);
      const scale = longEdge > MAX_UPLOAD_IMAGE_EDGE ? MAX_UPLOAD_IMAGE_EDGE / longEdge : 1;
      const pixel = imageSource.createPixelMapSync({
        desiredSize: {
          width: Math.max(1, Math.round(info.size.width * scale)),
          height: Math.max(1, Math.round(info.size.height * scale))
        }
      });
      pixelMap = pixel;
      const packer = image.createImagePacker();
      const packed = await packer.packToData(pixel, {
        format: 'image/jpeg',
        quality: UPLOAD_IMAGE_JPEG_QUALITY
      });
      if (packed.byteLength <= 0 || packed.byteLength >= originalSize) {
        return false;
      }
      const out = fileIo.openSync(targetPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(out.fd, packed);
      } finally {
        fileIo.closeSync(out);
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (pixelMap !== undefined) {
        try {
          pixelMap.release();
        } catch (_) {}
      }
      if (source !== undefined) {
        try {
          fileIo.closeSync(source);
        } catch (_) {}
      }
    }
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
