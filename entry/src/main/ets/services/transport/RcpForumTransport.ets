import { BusinessError } from '@kit.BasicServicesKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import {
  ForumTransport,
  ForumFormFields,
  TransportCachePolicy,
  TransportErrorKind,
  TransportProbeError,
  TransportProbeMetadata,
  TransportProbeResponse
} from './ForumTransport';
import { ResponseFingerprint } from './ResponseFingerprint';

const FORUM_ORIGIN = 'https://linux.sb';
const PROBE_USER_AGENT = 'ShaobingCommunity-P0/0.1 (HarmonyOS; technical-probe)';
const PRODUCT_USER_AGENT = 'ShaobingCommunity/1.0 (HarmonyOS; read-only)';

class ResponseValidator {
  etag: string = '';
  lastModified: string = '';
}

export class RcpForumTransport implements ForumTransport {
  private session: rcp.Session | undefined = undefined;
  private activeRequests: rcp.Request[] = [];
  private validators: Map<string, ResponseValidator> = new Map<string, ResponseValidator>();

  async getHome(cachePolicy: TransportCachePolicy = TransportCachePolicy.Product): Promise<TransportProbeResponse> {
    return this.get(`${FORUM_ORIGIN}/`, '', cachePolicy);
  }

  async getFeedPage(pageUrl: string, cookieHeader: string = '',
    cachePolicy: TransportCachePolicy = TransportCachePolicy.Product): Promise<TransportProbeResponse> {
    return this.get(this.validatedFeedUrl(pageUrl), cookieHeader, cachePolicy);
  }

  async getTopic(topicId: number,
    cachePolicy: TransportCachePolicy = TransportCachePolicy.Product,
    allowConditional: boolean = false): Promise<TransportProbeResponse> {
    return this.get(`${FORUM_ORIGIN}/topic/${topicId}`, '', cachePolicy, allowConditional);
  }

  async getAuthenticatedTopic(topicId: number, cookieHeader: string,
    cachePolicy: TransportCachePolicy = TransportCachePolicy.Product,
    allowConditional: boolean = false): Promise<TransportProbeResponse> {
    return this.get(`${FORUM_ORIGIN}/topic/${topicId}`, cookieHeader, cachePolicy, allowConditional);
  }

  async getTopicPage(topicId: number, pageUrl: string,
    cachePolicy: TransportCachePolicy = TransportCachePolicy.Product,
    allowConditional: boolean = false): Promise<TransportProbeResponse> {
    return this.get(this.validatedTopicPageUrl(topicId, pageUrl), '', cachePolicy, allowConditional);
  }

  async getAuthenticatedTopicPage(topicId: number, pageUrl: string, cookieHeader: string,
    cachePolicy: TransportCachePolicy = TransportCachePolicy.Product,
    allowConditional: boolean = false): Promise<TransportProbeResponse> {
    return this.get(this.validatedTopicPageUrl(topicId, pageUrl), cookieHeader, cachePolicy, allowConditional);
  }

  async getAuthenticatedNotifications(cookieHeader: string): Promise<TransportProbeResponse> {
    return this.get(`${FORUM_ORIGIN}/notify`, cookieHeader, TransportCachePolicy.ProbeNoStore);
  }

  cancelAll(): void {
    const currentSession = this.session;
    if (currentSession === undefined) {
      return;
    }
    try {
      currentSession.cancel();
    } catch (_) {
      // Cancellation is best-effort. The request promise still reports its structured error.
    }
    this.activeRequests = [];
  }

  close(): void {
    const currentSession = this.session;
    if (currentSession === undefined) {
      return;
    }
    try {
      currentSession.cancel();
    } catch (_) {
      // A session can already be closing when the page is destroyed.
    }
    try {
      currentSession.close();
    } catch (_) {
      // close() is intentionally idempotent at the probe boundary.
    }
    this.session = undefined;
    this.activeRequests = [];
  }

  private async get(url: string, cookieHeader: string,
    cachePolicy: TransportCachePolicy, allowConditional: boolean = false): Promise<TransportProbeResponse> {
    const startedAt = Date.now();
    const session = this.ensureSession();
    if (session === undefined) {
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
        error: { kind: 'UNKNOWN', code: 0, message: 'Unable to create the RCP session.' }
      };
    }
    const headers: rcp.RequestHeaders = {
      'accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.5',
      'user-agent': cachePolicy === TransportCachePolicy.ProbeNoStore ? PROBE_USER_AGENT : PRODUCT_USER_AGENT
    };
    if (cachePolicy === TransportCachePolicy.ProbeNoStore) {
      headers['cache-control'] = 'no-cache';
    }
    if (cookieHeader.length > 0) {
      headers['cookie'] = cookieHeader;
    }
    const validatorKey = `${cookieHeader.length > 0 ? 'auth' : 'anon'}:${url}`;
    const validator = cachePolicy === TransportCachePolicy.Product && allowConditional ?
      this.validators.get(validatorKey) : undefined;
    if (validator !== undefined && validator.etag.length > 0) {
      headers['if-none-match'] = validator.etag;
    }
    if (validator !== undefined && validator.lastModified.length > 0) {
      headers['if-modified-since'] = validator.lastModified;
    }
    const request = new rcp.Request(url, 'GET', headers);
    request.destination = 'array-buffer';
    if (cachePolicy === TransportCachePolicy.ProbeNoStore) {
      request.cacheControl = { noCache: true, noStore: true };
    }
    this.activeRequests.push(request);

    try {
      const response = await session.fetch(request);
      const contentType = this.headerValue(response.headers['content-type']);
      const contentEncoding = this.headerValue(response.headers['content-encoding']);
      const etag = this.headerValue(response.headers['etag']);
      const lastModified = this.headerValue(response.headers['last-modified']);
      if (cachePolicy === TransportCachePolicy.Product && response.statusCode >= 200 && response.statusCode < 300 &&
        (etag.length > 0 || lastModified.length > 0)) {
        const nextValidator = new ResponseValidator();
        nextValidator.etag = etag;
        nextValidator.lastModified = lastModified;
        this.validators.set(validatorKey, nextValidator);
      }
      const body = response.toString();
      const metadata: TransportProbeMetadata = {
        statusCode: response.statusCode,
        byteLength: response.body?.byteLength ?? 0,
        contentType: contentType,
        contentEncoding: contentEncoding,
        elapsedMs: Date.now() - startedAt,
        effectiveUrl: response.effectiveUrl?.toString() ?? url,
        sha256: cachePolicy === TransportCachePolicy.ProbeNoStore ?
          ResponseFingerprint.sha256Hex(response.body) : '',
        etag: etag,
        lastModified: lastModified
      };
      if (body === null) {
        return {
          metadata: metadata,
          body: '',
          error: { kind: 'BODY_DECODE', code: 0, message: 'Response body is not valid UTF-8.' }
        };
      }
      const responseError = this.classifyResponse(response.statusCode, contentType);
      return {
        metadata: metadata,
        body: body,
        error: responseError
      };
    } catch (error) {
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
        error: this.classifyException(error as BusinessError)
      };
    } finally {
      const requestIndex = this.activeRequests.indexOf(request);
      if (requestIndex >= 0) {
        this.activeRequests.splice(requestIndex, 1);
      }
    }
  }

  async postForm(pageUrl: string, fields: ForumFormFields,
    cookieHeader: string): Promise<TransportProbeResponse> {
    const url = this.validatedWriteUrl(pageUrl);
    const startedAt = Date.now();
    const session = this.ensureSession();
    if (session === undefined) {
      return this.failedResponse(url, startedAt, 'UNKNOWN', 0, 'Unable to create the RCP session.');
    }
    const headers: rcp.RequestHeaders = {
      'accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.5',
      'user-agent': PRODUCT_USER_AGENT,
      'origin': FORUM_ORIGIN,
      'referer': `${FORUM_ORIGIN}/`
    };
    if (cookieHeader.length > 0) {
      headers['cookie'] = cookieHeader;
    }
    let form: rcp.Form;
    if (fields.topic_id !== undefined) {
      form = new rcp.Form({
        '_csrf': fields._csrf,
        'topic_id': fields.topic_id,
        'body': fields.body ?? ''
      });
    } else {
      form = new rcp.Form({
        '_csrf': fields._csrf,
        'id': fields.id ?? 0,
        'forum_id': fields.forum_id ?? 0,
        'title': fields.title ?? '',
        'body': fields.body ?? ''
      });
    }
    const request = new rcp.Request(url, 'POST', headers, form);
    request.destination = 'array-buffer';
    this.activeRequests.push(request);
    try {
      let response = await session.fetch(request);
      // BBS1 accepts a write and answers 302 to the resulting topic page. RCP
      // does not reliably follow redirects on form POSTs, so follow them here
      // with GET hops and report the final page as the effective response.
      let currentUrl = url;
      let lastLocation = '';
      for (let hop = 0; hop < 3 && this.isRedirectStatus(response.statusCode); hop++) {
        const location = this.headerValue(response.headers['location']);
        if (location.length === 0) {
          break;
        }
        lastLocation = location;
        const nextUrl = this.resolveSameOriginUrl(location);
        if (nextUrl.length === 0) {
          break;
        }
        currentUrl = nextUrl;
        response = await this.fetchWriteRedirect(currentUrl, url, cookieHeader, session);
      }
      const body = response.toString();
      const metadata: TransportProbeMetadata = {
        statusCode: response.statusCode,
        byteLength: response.body?.byteLength ?? 0,
        contentType: this.headerValue(response.headers['content-type']),
        contentEncoding: this.headerValue(response.headers['content-encoding']),
        elapsedMs: Date.now() - startedAt,
        effectiveUrl: response.effectiveUrl?.toString() ?? currentUrl,
        sha256: ResponseFingerprint.sha256Hex(response.body)
      };
      if (lastLocation.length > 0) {
        const resolvedLocation = this.resolveSameOriginUrl(lastLocation);
        metadata.location = resolvedLocation.length > 0 ? resolvedLocation : lastLocation;
      }
      if (body === null) {
        return { metadata: metadata, body: '', error: { kind: 'BODY_DECODE', code: 0,
          message: 'Response body is not valid UTF-8.' } };
      }
      return { metadata: metadata, body: body,
        error: this.classifyResponse(response.statusCode, metadata.contentType) };
    } catch (error) {
      const classified = this.classifyException(error as BusinessError);
      return this.failedResponse(url, startedAt, classified.kind, classified.code, classified.message);
    } finally {
      const requestIndex = this.activeRequests.indexOf(request);
      if (requestIndex >= 0) {
        this.activeRequests.splice(requestIndex, 1);
      }
    }
  }

  private async fetchWriteRedirect(targetUrl: string, writeUrl: string, cookieHeader: string,
    session: rcp.Session): Promise<rcp.Response> {
    const headers: rcp.RequestHeaders = {
      'accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.5',
      'user-agent': PRODUCT_USER_AGENT,
      'referer': writeUrl
    };
    if (cookieHeader.length > 0) {
      headers['cookie'] = cookieHeader;
    }
    const request = new rcp.Request(targetUrl, 'GET', headers);
    request.destination = 'array-buffer';
    this.activeRequests.push(request);
    try {
      return await session.fetch(request);
    } finally {
      const requestIndex = this.activeRequests.indexOf(request);
      if (requestIndex >= 0) {
        this.activeRequests.splice(requestIndex, 1);
      }
    }
  }

  private isRedirectStatus(statusCode: number): boolean {
    return statusCode >= 300 && statusCode < 400 && statusCode !== 304;
  }

  private resolveSameOriginUrl(location: string): string {
    if (location.startsWith('https://') || location.startsWith('http://')) {
      return location.startsWith(`${FORUM_ORIGIN}/`) ? location : '';
    }
    if (location.startsWith('/')) {
      return `${FORUM_ORIGIN}${location}`;
    }
    return '';
  }

  private validatedTopicPageUrl(topicId: number, pageUrl: string): string {
    const canonical = `${FORUM_ORIGIN}/topic/${topicId}`;
    if (pageUrl === canonical || pageUrl.startsWith(`${canonical}?`)) {
      return pageUrl;
    }
    return canonical;
  }

  private validatedFeedUrl(pageUrl: string): string {
    if (!pageUrl.startsWith(`${FORUM_ORIGIN}/`)) {
      return `${FORUM_ORIGIN}/`;
    }
    const relative = pageUrl.substring(FORUM_ORIGIN.length);
    if (relative === '/' || relative.startsWith('/?') || relative.startsWith('/index.php?')) {
      return pageUrl;
    }
    if (this.isNumericRoute(relative, '/forum/') || this.isNumericRoute(relative, '/user/')) {
      return pageUrl;
    }
    return `${FORUM_ORIGIN}/`;
  }

  private validatedWriteUrl(pageUrl: string): string {
    if (pageUrl === `${FORUM_ORIGIN}/topic_edit` || pageUrl === `${FORUM_ORIGIN}/reply_edit`) {
      return pageUrl;
    }
    return `${FORUM_ORIGIN}/`;
  }

  private failedResponse(url: string, startedAt: number, kind: TransportErrorKind,
    code: number, message: string): TransportProbeResponse {
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
      error: { kind: kind, code: code, message: message }
    };
  }

  private isNumericRoute(relative: string, prefix: string): boolean {
    if (!relative.startsWith(prefix)) {
      return false;
    }
    let cursor = prefix.length;
    let digitCount = 0;
    while (cursor < relative.length) {
      const current = relative.charAt(cursor);
      if (current < '0' || current > '9') {
        break;
      }
      digitCount++;
      cursor++;
    }
    return digitCount > 0 && (cursor === relative.length || relative.charAt(cursor) === '?');
  }

  private ensureSession(): rcp.Session | undefined {
    if (this.session !== undefined) {
      return this.session;
    }
    try {
      const created = rcp.createSession({
        requestConfiguration: {
          transfer: {
            autoRedirect: true,
            maxAutoRedirects: 5,
            connectionReusePolicy: 'balanced',
            timeout: {
              connectMs: 8000,
              transferMs: 20000,
              inactivityMs: 10000
            }
          }
        }
      });
      this.session = created;
      return created;
    } catch (_) {
      return undefined;
    }
  }

  private classifyResponse(statusCode: number, contentType: string): TransportProbeError | undefined {
    if (statusCode === 304) {
      return undefined;
    }
    if (statusCode >= 300 && statusCode < 400) {
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

  private classifyException(error: BusinessError): TransportProbeError {
    const code = error.code ?? 0;
    let kind: TransportErrorKind = 'NETWORK';
    if (code === 1007900992 || code === 1007900042) {
      kind = 'CANCELED';
    } else if (code === 1007900993) {
      kind = 'SESSION_CLOSED';
    } else if (code === 1007900028) {
      kind = 'TIMEOUT';
    } else if (code === 1007900035 || code === 1007900058 || code === 1007900060) {
      kind = 'TLS';
    } else if (code === 0) {
      kind = 'UNKNOWN';
    }
    const message = error.message === undefined || error.message.length === 0 ? 'RCP request failed.' : error.message;
    return { kind: kind, code: code, message: message };
  }

  private headerValue(value: string | string[] | undefined): string {
    if (value === undefined) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    return value.join(', ');
  }
}
