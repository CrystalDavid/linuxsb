import { BusinessError } from '@kit.BasicServicesKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import {
  ForumTransport,
  TransportErrorKind,
  TransportProbeError,
  TransportProbeMetadata,
  TransportProbeResponse
} from './ForumTransport';

const FORUM_ORIGIN = 'https://linux.sb';
const USER_AGENT = 'ShaobingCommunity-P0/0.1 (HarmonyOS; technical-probe)';

export class RcpForumTransport implements ForumTransport {
  private session: rcp.Session | undefined = undefined;
  private activeRequests: rcp.Request[] = [];

  async getHome(): Promise<TransportProbeResponse> {
    return this.get(`${FORUM_ORIGIN}/`);
  }

  async getTopic(topicId: number): Promise<TransportProbeResponse> {
    return this.get(`${FORUM_ORIGIN}/topic/${topicId}`);
  }

  async getAuthenticatedNotifications(cookieHeader: string): Promise<TransportProbeResponse> {
    return this.get(`${FORUM_ORIGIN}/notify`, cookieHeader);
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

  private async get(url: string, cookieHeader: string = ''): Promise<TransportProbeResponse> {
    const startedAt = Date.now();
    const session = this.ensureSession();
    if (session === undefined) {
      return {
        metadata: {
          statusCode: 0,
          byteLength: 0,
          contentType: '',
          elapsedMs: Date.now() - startedAt,
          effectiveUrl: url
        },
        body: '',
        error: { kind: 'UNKNOWN', code: 0, message: 'Unable to create the RCP session.' }
      };
    }
    const headers: rcp.RequestHeaders = {
      'accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.5',
      'cache-control': 'no-cache',
      'user-agent': USER_AGENT
    };
    if (cookieHeader.length > 0) {
      headers['cookie'] = cookieHeader;
    }
    const request = new rcp.Request(url, 'GET', headers);
    request.destination = 'array-buffer';
    this.activeRequests.push(request);

    try {
      const response = await session.fetch(request);
      const contentType = this.headerValue(response.headers['content-type']);
      const body = response.toString();
      const metadata: TransportProbeMetadata = {
        statusCode: response.statusCode,
        byteLength: response.body?.byteLength ?? 0,
        contentType: contentType,
        elapsedMs: Date.now() - startedAt,
        effectiveUrl: response.effectiveUrl?.toString() ?? url
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
          elapsedMs: Date.now() - startedAt,
          effectiveUrl: url
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
