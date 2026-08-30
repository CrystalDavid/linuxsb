import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { webview } from '@kit.ArkWeb';
import {
  ForumFormFields,
  TransportCachePolicy,
  TransportProbeError,
  TransportProbeResponse
} from '../transport/ForumTransport';

const FORUM_ORIGIN: string = 'https://linux.sb';
// The host only needs a same-origin JavaScript context. Loading the complete
// forum homepage behind ArkUI keeps an unnecessary DOM, images and animations
// alive (especially costly in the x86 emulator). A tiny text document keeps
// the same origin and Cookie jar while injected fetch continues to work.
export const FORUM_BOOTSTRAP_URL: string = `${FORUM_ORIGIN}/robots.txt`;
const REQUEST_ID_TOKEN: string = '__SHAOBING_REQUEST_ID__';
const REQUEST_TIMEOUT_MS: number = 20000;
const HOST_READY_TIMEOUT_MS: number = 12000;
const RECOVERY_POLL_INTERVAL_MS: number = 2000;
const RECOVERY_MAX_POLLS: number = 6;
const AVATAR_MAX_CONCURRENCY: number = 5;
const AVATAR_MAX_CACHE_ENTRIES: number = 160;
const AVATAR_MAX_CACHE_BYTES: number = 48 * 1024 * 1024;

interface WebFetchEnvelope {
  statusCode?: number;
  contentType?: string;
  contentEncoding?: string;
  cfMitigated?: string;
  body?: string;
  effectiveUrl?: string;
  byteLength?: number;
  etag?: string;
  lastModified?: string;
  errorMessage?: string;
}

interface WebImageEnvelope {
  statusCode?: number;
  contentType?: string;
  cfMitigated?: string;
  body?: string;
  errorMessage?: string;
}

class PendingWebRequest {
  resolve: (value: string) => void;
  timeoutId: number;

  constructor(resolve: (value: string) => void, timeoutId: number) {
    this.resolve = resolve;
    this.timeoutId = timeoutId;
  }
}

class ArkWebCallbackProxy {
  private bridge: ArkWebForumBridge;

  constructor(bridge: ArkWebForumBridge) {
    this.bridge = bridge;
  }

  onFetchResult(requestId: string, payload: string): void {
    this.bridge.acceptResult(requestId, payload);
  }
}

export class ArkWebForumBridge {
  private controller: webview.WebviewController | undefined = undefined;
  private callbackProxy: ArkWebCallbackProxy = new ArkWebCallbackProxy(this);
  private pending: Map<string, PendingWebRequest> = new Map<string, PendingWebRequest>();
  private readyWaiters: Array<() => void> = [];
  private challengeRequiredListeners: Array<() => void> = [];
  private recoveredListeners: Array<() => void> = [];
  private requestSequence: number = 0;
  private ready: boolean = false;
  private recoveryActive: boolean = false;
  private recoveryPollTimer: number = -1;
  private recoveryPollCount: number = 0;
  private recoveryProbeRunning: boolean = false;
  private avatarCache: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  private avatarCacheBytes: Map<string, number> = new Map<string, number>();
  private avatarCacheTotalBytes: number = 0;
  private avatarInflight: Map<string, Promise<image.PixelMap | undefined>> =
    new Map<string, Promise<image.PixelMap | undefined>>();
  private avatarActive: number = 0;
  private avatarQueue: Array<() => void> = [];

  createJavaScriptProxy(controller: webview.WebviewController): JavaScriptProxy {
    this.controller = controller;
    return {
      object: this.callbackProxy,
      name: 'ShaobingWebBridge',
      methodList: ['onFetchResult'],
      controller: controller
    };
  }

  markReady(controller: webview.WebviewController): void {
    this.controller = controller;
    this.ready = true;
    const waiters = this.readyWaiters.slice();
    this.readyWaiters = [];
    for (let index = 0; index < waiters.length; index++) {
      waiters[index]();
    }
  }

  markUnavailable(): void {
    this.ready = false;
    const waiters = this.readyWaiters.slice();
    this.readyWaiters = [];
    for (let index = 0; index < waiters.length; index++) {
      waiters[index]();
    }
  }

  isReady(): boolean {
    return this.ready && this.controller !== undefined;
  }

  reloadHost(): boolean {
    const controller = this.controller;
    if (controller === undefined) {
      return false;
    }
    this.ready = false;
    this.resolvePendingWithFailure('ArkWeb host reloading');
    try {
      controller.loadUrl(FORUM_BOOTSTRAP_URL);
      return true;
    } catch (_) {
      this.markUnavailable();
      return false;
    }
  }

  subscribeChallengeRequired(listener: () => void): () => void {
    this.challengeRequiredListeners.push(listener);
    return () => this.removeListener(this.challengeRequiredListeners, listener);
  }

  subscribeRecovered(listener: () => void): () => void {
    this.recoveredListeners.push(listener);
    return () => this.removeListener(this.recoveredListeners, listener);
  }

  confirmChallengeResolved(): void {
    this.completeRecovery();
  }

  dismissChallenge(): void {
    this.recoveryActive = false;
    this.recoveryPollCount = 0;
    this.stopRecoveryTimer();
  }

  async get(url: string, cachePolicy: TransportCachePolicy): Promise<TransportProbeResponse | undefined> {
    if (!this.isSameOriginUrl(url) || !await this.waitUntilReady()) {
      return undefined;
    }
    const script = this.buildFetchScript(url, 'GET', '', cachePolicy === TransportCachePolicy.ProbeNoStore,
      'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8');
    return this.executePageRequest(url, script, false, true);
  }

  async postForm(url: string, fields: ForumFormFields): Promise<TransportProbeResponse | undefined> {
    if (!this.isSameOriginUrl(url) || !await this.waitUntilReady()) {
      return undefined;
    }
    const script = this.buildFetchScript(url, 'POST', this.encodeForm(fields), true, '*/*');
    return this.executePageRequest(url, script, true, true);
  }

  async canAccessForum(): Promise<boolean> {
    if (!await this.waitUntilReady()) {
      return false;
    }
    const url = `${FORUM_ORIGIN}/`;
    const script = this.buildFetchScript(url, 'GET', '', true,
      'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8');
    const response = await this.executePageRequest(url, script, false, false);
    return response !== undefined && response.error === undefined && response.metadata.statusCode >= 200 &&
      response.metadata.statusCode < 300;
  }

  getCachedAvatar(url: string): image.PixelMap | undefined {
    const cached = this.avatarCache.get(url);
    if (cached === undefined) {
      return undefined;
    }
    // Map preserves insertion order. Touch both entries so eviction is LRU,
    // while keeping byte accounting unchanged.
    const bytes = this.avatarCacheBytes.get(url) ?? 0;
    this.avatarCache.delete(url);
    this.avatarCacheBytes.delete(url);
    this.avatarCache.set(url, cached);
    this.avatarCacheBytes.set(url, bytes);
    return cached;
  }

  async loadAvatar(url: string): Promise<image.PixelMap | undefined> {
    if (!this.isSameOriginUrl(url)) {
      return undefined;
    }
    const cached = this.getCachedAvatar(url);
    if (cached !== undefined) {
      return cached;
    }
    const inflight = this.avatarInflight.get(url);
    if (inflight !== undefined) {
      return inflight;
    }
    const task = this.fetchAndDecodeAvatar(url);
    this.avatarInflight.set(url, task);
    try {
      return await task;
    } finally {
      this.avatarInflight.delete(url);
    }
  }

  preloadAvatars(urls: string[]): void {
    const seen: Set<string> = new Set<string>();
    for (let index = 0; index < urls.length; index++) {
      const url = urls[index];
      if (!this.isSameOriginUrl(url) || seen.has(url) || this.avatarCache.has(url)) {
        continue;
      }
      seen.add(url);
      this.loadAvatar(url).catch(() => {});
    }
  }

  acceptResult(requestId: string, payload: string): void {
    const request = this.pending.get(requestId);
    if (request === undefined) {
      return;
    }
    clearTimeout(request.timeoutId);
    this.pending.delete(requestId);
    request.resolve(payload);
  }

  private async executePageRequest(url: string, script: string, write: boolean,
    notifyChallenge: boolean): Promise<TransportProbeResponse | undefined> {
    const startedAt = Date.now();
    const raw = await this.runScript(script);
    if (raw === undefined) {
      return undefined;
    }
    let envelope: WebFetchEnvelope;
    try {
      envelope = JSON.parse(raw) as WebFetchEnvelope;
    } catch (_) {
      return this.failedResponse(url, startedAt, 'BODY_DECODE', 'ArkWeb response envelope is invalid.');
    }
    const statusCode = envelope.statusCode ?? 0;
    const contentType = envelope.contentType ?? '';
    const body = envelope.body ?? '';
    const cfMitigated = (envelope.cfMitigated ?? '').toLowerCase();
    const challenged = cfMitigated === 'challenge' || this.looksLikeChallenge(statusCode, contentType, body);
    if (challenged && notifyChallenge) {
      this.beginChallengeRecovery();
    }
    const response: TransportProbeResponse = {
      metadata: {
        statusCode: statusCode,
        byteLength: envelope.byteLength ?? body.length,
        contentType: contentType,
        contentEncoding: envelope.contentEncoding ?? '',
        elapsedMs: Date.now() - startedAt,
        effectiveUrl: envelope.effectiveUrl ?? url,
        sha256: '',
        etag: envelope.etag ?? '',
        lastModified: envelope.lastModified ?? ''
      },
      body: body
    };
    if (envelope.errorMessage !== undefined && envelope.errorMessage.length > 0) {
      response.error = { kind: 'NETWORK', code: 0, message: 'ArkWeb request failed.' };
      return response;
    }
    if (challenged) {
      response.error = { kind: 'HTTP_CLIENT', code: statusCode, message: 'Cloudflare verification required.' };
      return response;
    }
    response.error = write ? this.classifyWrite(statusCode) : this.classifyRead(statusCode, contentType);
    return response;
  }

  private buildFetchScript(url: string, method: string, body: string, noStore: boolean,
    accept: string): string {
    const encodedUrl = JSON.stringify(url);
    const encodedMethod = JSON.stringify(method);
    const encodedBody = JSON.stringify(body);
    const encodedAccept = JSON.stringify(accept);
    const cacheMode = noStore ? 'no-store' : 'default';
    const bodyBlock = method === 'POST' ?
      `, body: ${encodedBody}` : '';
    const contentTypeBlock = method === 'POST' ?
      `, 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8', ` +
        `'X-Requested-With': 'XMLHttpRequest'` : '';
    return `(() => {
      const requestId = '${REQUEST_ID_TOKEN}';
      const fail = (error) => window.ShaobingWebBridge.onFetchResult(requestId, JSON.stringify({
        statusCode: 0, contentType: '', body: '', errorMessage: String(error)
      }));
      fetch(${encodedUrl}, {
        method: ${encodedMethod}, credentials: 'include', redirect: 'follow', cache: '${cacheMode}',
        headers: { 'Accept': ${encodedAccept}${contentTypeBlock} }${bodyBlock}
      }).then((response) => response.text().then((responseBody) => {
        window.ShaobingWebBridge.onFetchResult(requestId, JSON.stringify({
          statusCode: response.status,
          contentType: response.headers.get('content-type') || '',
          contentEncoding: response.headers.get('content-encoding') || '',
          cfMitigated: response.headers.get('cf-mitigated') || '',
          body: responseBody,
          effectiveUrl: response.url || ${encodedUrl},
          byteLength: new Blob([responseBody]).size,
          etag: response.headers.get('etag') || '',
          lastModified: response.headers.get('last-modified') || ''
        }));
      }).catch(fail)).catch(fail);
      return requestId;
    })();`;
  }

  private buildImageFetchScript(url: string): string {
    const encodedUrl = JSON.stringify(url);
    return `(() => {
      const requestId = '${REQUEST_ID_TOKEN}';
      const requestUrl = new URL(${encodedUrl}, window.location.origin);
      const sameOrigin = requestUrl.origin === window.location.origin;
      const fail = (error) => window.ShaobingWebBridge.onFetchResult(requestId, JSON.stringify({
        statusCode: 0, contentType: '', body: '', errorMessage: String(error)
      }));
      fetch(requestUrl.toString(), {
        credentials: sameOrigin ? 'include' : 'omit', cache: 'default', headers: { 'Accept': 'image/*' }
      }).then((response) => response.arrayBuffer().then((buffer) => {
        const bytes = new Uint8Array(buffer);
        let binary = '';
        const chunk = 8192;
        for (let index = 0; index < bytes.length; index += chunk) {
          binary += String.fromCharCode.apply(null, bytes.subarray(index, index + chunk));
        }
        window.ShaobingWebBridge.onFetchResult(requestId, JSON.stringify({
          statusCode: response.status,
          contentType: response.headers.get('content-type') || '',
          cfMitigated: response.headers.get('cf-mitigated') || '',
          body: btoa(binary)
        }));
      }).catch(fail)).catch(fail);
      return requestId;
    })();`;
  }

  private runScript(script: string): Promise<string | undefined> {
    const controller = this.controller;
    if (!this.ready || controller === undefined) {
      return Promise.resolve(undefined);
    }
    const requestId = `shaobing_${this.requestSequence}`;
    this.requestSequence++;
    return new Promise<string | undefined>((resolve: (value: string | undefined) => void) => {
      const timeoutId = setTimeout(() => {
        const request = this.pending.get(requestId);
        if (request !== undefined) {
          this.pending.delete(requestId);
          request.resolve('');
        }
      }, REQUEST_TIMEOUT_MS);
      this.pending.set(requestId, new PendingWebRequest((value: string) => {
        resolve(value.length > 0 ? value : undefined);
      }, timeoutId));
      try {
        controller.runJavaScript(script.replace(REQUEST_ID_TOKEN, requestId)).catch(() => {
          const request = this.pending.get(requestId);
          if (request !== undefined) {
            clearTimeout(request.timeoutId);
            this.pending.delete(requestId);
            request.resolve('');
          }
        });
      } catch (_) {
        const request = this.pending.get(requestId);
        if (request !== undefined) {
          clearTimeout(request.timeoutId);
          this.pending.delete(requestId);
          request.resolve('');
        }
      }
    });
  }

  private waitUntilReady(): Promise<boolean> {
    if (this.isReady()) {
      return Promise.resolve(true);
    }
    return new Promise<boolean>((resolve: (value: boolean) => void) => {
      let settled = false;
      const finish = (): void => {
        if (settled) {
          return;
        }
        settled = true;
        resolve(this.isReady());
      };
      this.readyWaiters.push(finish);
      setTimeout(finish, HOST_READY_TIMEOUT_MS);
    });
  }

  private beginChallengeRecovery(): void {
    if (this.recoveryActive) {
      return;
    }
    this.recoveryActive = true;
    this.recoveryPollCount = 0;
    this.reloadHost();
    this.stopRecoveryTimer();
    this.recoveryPollTimer = setInterval(() => this.pollRecovery(), RECOVERY_POLL_INTERVAL_MS);
  }

  private async pollRecovery(): Promise<void> {
    if (!this.recoveryActive || this.recoveryProbeRunning) {
      return;
    }
    this.recoveryProbeRunning = true;
    this.recoveryPollCount++;
    const recovered = await this.canAccessForum();
    this.recoveryProbeRunning = false;
    if (!this.recoveryActive) {
      return;
    }
    if (recovered) {
      this.completeRecovery();
      return;
    }
    if (this.recoveryPollCount === 3) {
      this.reloadHost();
    }
    if (this.recoveryPollCount >= RECOVERY_MAX_POLLS) {
      this.stopRecoveryTimer();
      for (let index = 0; index < this.challengeRequiredListeners.length; index++) {
        this.challengeRequiredListeners[index]();
      }
    }
  }

  private completeRecovery(): void {
    const shouldReturnToBootstrap = this.recoveryActive;
    this.recoveryActive = false;
    this.recoveryPollCount = 0;
    this.stopRecoveryTimer();
    // The hidden host may still contain Cloudflare's full challenge document.
    // Once the shared Cookie jar is valid, navigate it back to the tiny
    // same-origin bootstrap before native lists resume their requests.
    if (shouldReturnToBootstrap) {
      this.reloadHost();
    }
    for (let index = 0; index < this.recoveredListeners.length; index++) {
      this.recoveredListeners[index]();
    }
  }

  private stopRecoveryTimer(): void {
    if (this.recoveryPollTimer >= 0) {
      clearInterval(this.recoveryPollTimer);
      this.recoveryPollTimer = -1;
    }
  }

  private resolvePendingWithFailure(_reason: string): void {
    this.pending.forEach((request: PendingWebRequest) => {
      clearTimeout(request.timeoutId);
      request.resolve('');
    });
    this.pending.clear();
  }

  private removeListener(listeners: Array<() => void>, listener: () => void): void {
    const index = listeners.indexOf(listener);
    if (index >= 0) {
      listeners.splice(index, 1);
    }
  }

  private isSameOriginUrl(url: string): boolean {
    return url === FORUM_ORIGIN || url.startsWith(`${FORUM_ORIGIN}/`);
  }

  private looksLikeChallenge(statusCode: number, contentType: string, body: string): boolean {
    if (contentType.toLowerCase().indexOf('text/html') < 0) {
      return false;
    }
    if (statusCode !== 403 && statusCode !== 429 && statusCode !== 503) {
      return false;
    }
    const probe = body.substring(0, Math.min(body.length, 12000)).toLowerCase();
    return probe.indexOf('challenge-platform') >= 0 || probe.indexOf('cf-chl-') >= 0 ||
      probe.indexOf('just a moment') >= 0 || probe.indexOf('challenges.cloudflare.com') >= 0;
  }

  private classifyRead(statusCode: number, contentType: string): TransportProbeError | undefined {
    if (statusCode >= 300 && statusCode < 400 && statusCode !== 304) {
      return { kind: 'REDIRECT', code: statusCode, message: 'Unexpected redirect response.' };
    }
    if (statusCode >= 400 && statusCode < 500) {
      return { kind: 'HTTP_CLIENT', code: statusCode, message: 'Server returned a client error.' };
    }
    if (statusCode >= 500) {
      return { kind: 'HTTP_SERVER', code: statusCode, message: 'Server returned an error.' };
    }
    const normalized = contentType.toLowerCase();
    if (!normalized.startsWith('text/html') && !normalized.startsWith('application/xhtml+xml')) {
      return { kind: 'CONTENT_TYPE', code: statusCode, message: 'Expected an HTML response.' };
    }
    return undefined;
  }

  private classifyWrite(statusCode: number): TransportProbeError | undefined {
    if (statusCode >= 300 && statusCode < 400) {
      return { kind: 'REDIRECT', code: statusCode, message: 'Unexpected redirect response.' };
    }
    if (statusCode >= 400 && statusCode < 500) {
      return { kind: 'HTTP_CLIENT', code: statusCode, message: 'Server returned a client error.' };
    }
    if (statusCode >= 500) {
      return { kind: 'HTTP_SERVER', code: statusCode, message: 'Server returned an error.' };
    }
    return undefined;
  }

  private failedResponse(url: string, startedAt: number,
    kind: 'BODY_DECODE' | 'NETWORK', message: string): TransportProbeResponse {
    return {
      metadata: {
        statusCode: 0,
        byteLength: 0,
        contentType: '',
        contentEncoding: '',
        elapsedMs: Date.now() - startedAt,
        effectiveUrl: url,
        sha256: ''
      },
      body: '',
      error: { kind: kind, code: 0, message: message }
    };
  }

  private encodeForm(fields: ForumFormFields): string {
    const pairs: string[] = [];
    this.appendFormValue(pairs, '_csrf', fields._csrf);
    if (fields.extra !== undefined) {
      const keys = Object.keys(fields.extra);
      for (let index = 0; index < keys.length; index++) {
        const key = keys[index];
        const value = fields.extra[key];
        if (Array.isArray(value)) {
          const values = value as string[];
          for (let valueIndex = 0; valueIndex < values.length; valueIndex++) {
            this.appendFormValue(pairs, key, values[valueIndex]);
          }
        } else {
          this.appendFormValue(pairs, key, `${value}`);
        }
      }
    } else if (fields.topic_id !== undefined) {
      this.appendFormValue(pairs, 'topic_id', `${fields.topic_id}`);
      this.appendFormValue(pairs, 'body', fields.body ?? '');
    } else {
      this.appendFormValue(pairs, 'id', `${fields.id ?? 0}`);
      this.appendFormValue(pairs, 'forum_id', `${fields.forum_id ?? 0}`);
      this.appendFormValue(pairs, 'title', fields.title ?? '');
      this.appendFormValue(pairs, 'body', fields.body ?? '');
    }
    return pairs.join('&');
  }

  private appendFormValue(pairs: string[], name: string, value: string): void {
    pairs.push(`${encodeURIComponent(name)}=${encodeURIComponent(value)}`);
  }

  private async fetchAndDecodeAvatar(url: string): Promise<image.PixelMap | undefined> {
    if (!await this.waitUntilReady()) {
      return undefined;
    }
    await this.acquireAvatarSlot();
    try {
      const raw = await this.runScript(this.buildImageFetchScript(url));
      if (raw === undefined) {
        return undefined;
      }
      const envelope = JSON.parse(raw) as WebImageEnvelope;
      const statusCode = envelope.statusCode ?? 0;
      const base64 = envelope.body ?? '';
      if ((envelope.cfMitigated ?? '').toLowerCase() === 'challenge' || statusCode === 403 || statusCode === 429 ||
        statusCode === 503) {
        this.beginChallengeRecovery();
        return undefined;
      }
      if (statusCode < 200 || statusCode >= 300 || base64.length === 0) {
        return undefined;
      }
      const bytes = new util.Base64Helper().decodeSync(base64, util.Type.BASIC);
      if (this.isSvg(envelope.contentType ?? '', bytes)) {
        return undefined;
      }
      const buffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
      const source = image.createImageSource(buffer);
      let pixelMap: image.PixelMap;
      try {
        pixelMap = await source.createPixelMap();
      } finally {
        source.release();
      }
      this.putAvatar(url, pixelMap);
      return pixelMap;
    } catch (_) {
      return undefined;
    } finally {
      this.releaseAvatarSlot();
    }
  }

  private acquireAvatarSlot(): Promise<void> {
    if (this.avatarActive < AVATAR_MAX_CONCURRENCY) {
      this.avatarActive++;
      return Promise.resolve();
    }
    return new Promise<void>((resolve: () => void) => {
      this.avatarQueue.push(() => {
        this.avatarActive++;
        resolve();
      });
    });
  }

  private releaseAvatarSlot(): void {
    this.avatarActive--;
    const next = this.avatarQueue.shift();
    if (next !== undefined) {
      next();
    }
  }

  private putAvatar(url: string, pixelMap: image.PixelMap): void {
    let bytes = 0;
    try {
      bytes = pixelMap.getPixelBytesNumber();
    } catch (_) {}
    this.avatarCache.set(url, pixelMap);
    this.avatarCacheBytes.set(url, bytes);
    this.avatarCacheTotalBytes += bytes;
    while (this.avatarCache.size > 1 &&
      (this.avatarCache.size > AVATAR_MAX_CACHE_ENTRIES ||
        this.avatarCacheTotalBytes > AVATAR_MAX_CACHE_BYTES)) {
      const oldest: string | undefined = this.avatarCache.keys().next().value;
      if (oldest === undefined) {
        break;
      }
      this.avatarCache.delete(oldest);
      this.avatarCacheTotalBytes -= this.avatarCacheBytes.get(oldest) ?? 0;
      this.avatarCacheBytes.delete(oldest);
    }
  }

  private isSvg(contentType: string, bytes: Uint8Array): boolean {
    if (contentType.toLowerCase().indexOf('svg') >= 0) {
      return true;
    }
    const probeLength = Math.min(bytes.byteLength, 128);
    let head = '';
    for (let index = 0; index < probeLength; index++) {
      head += String.fromCharCode(bytes[index]);
    }
    return head.trim().toLowerCase().indexOf('<svg') >= 0;
  }
}

export const arkWebForumBridge: ArkWebForumBridge = new ArkWebForumBridge();
