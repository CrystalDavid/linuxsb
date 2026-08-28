import { AuthSessionPort } from '../auth/AuthSession';
import { ForumFormFields, ForumTransport, TransportProbeResponse } from '../transport/ForumTransport';

const FORUM_ORIGIN: string = 'https://linux.sb';
const TOPIC_URL_MARKER: string = '/topic/';

export interface WriteResult {
  ok: boolean;
  topicId: number;
  message: string;
  networkMs: number;
  authExpired?: boolean;
}

export interface WriteVerificationPort {
  findTopicByTitle(forumId: number, title: string): Promise<number>;
}

export class WriteRepository {
  private transport: ForumTransport;
  private authSession: AuthSessionPort;
  private verifier: WriteVerificationPort | undefined;
  private onSessionInvalidated: (() => void) | undefined;

  constructor(transport: ForumTransport, authSession: AuthSessionPort,
    verifier: WriteVerificationPort | undefined = undefined,
    onSessionInvalidated: (() => void) | undefined = undefined) {
    this.transport = transport;
    this.authSession = authSession;
    this.verifier = verifier;
    this.onSessionInvalidated = onSessionInvalidated;
  }

  async createTopic(forumId: number, title: string, body: string): Promise<WriteResult> {
    if (forumId <= 0 || title.trim().length === 0 || body.trim().length === 0) {
      return this.failure('标题、正文和板块不能为空');
    }
    const fields = new ForumFormFields();
    fields._csrf = this.authSession.getCsrfToken?.() ?? '';
    fields.id = 0;
    fields.forum_id = forumId;
    fields.title = title.trim();
    fields.body = body.trim();
    return this.submit(`${FORUM_ORIGIN}/topic_edit`, fields, 0);
  }

  async reply(topicId: number, body: string): Promise<WriteResult> {
    if (topicId <= 0 || body.trim().length === 0) {
      return this.failure('回复内容不能为空');
    }
    const fields = new ForumFormFields();
    fields._csrf = this.authSession.getCsrfToken?.() ?? '';
    fields.topic_id = topicId;
    fields.body = body.trim();
    return this.submit(`${FORUM_ORIGIN}/reply_edit`, fields, topicId);
  }

  private async submit(url: string, fields: ForumFormFields, expectedTopicId: number): Promise<WriteResult> {
    const cookieHeader = this.authSession.getRequestCookieHeader();
    const csrf = this.authSession.getCsrfToken?.();
    if (cookieHeader === undefined || csrf === undefined || csrf.length === 0) {
      return this.authFailure(0);
    }
    if (this.transport.postForm === undefined) {
      return this.failure('当前网络实现不支持写操作');
    }
    const response = await this.transport.postForm(url, fields, cookieHeader);
    const confirmedTopicId = this.confirmTopicId(response, expectedTopicId);
    if (confirmedTopicId > 0) {
      return { ok: true, topicId: confirmedTopicId, message: '', networkMs: response.metadata.elapsedMs };
    }
    if (this.isAuthFailure(response)) {
      return this.authFailure(response.metadata.elapsedMs);
    }
    // The transport outcome is ambiguous while the server may still have accepted
    // the write. Re-read the forum feed before reporting failure so a topic that
    // was actually published is never reported as an error and double-posted.
    if (this.verifier !== undefined && expectedTopicId === 0 && (fields.forum_id ?? 0) > 0) {
      const verifiedTopicId = await this.verifier.findTopicByTitle(fields.forum_id ?? 0, fields.title ?? '');
      if (verifiedTopicId > 0) {
        return { ok: true, topicId: verifiedTopicId, message: '', networkMs: response.metadata.elapsedMs };
      }
    }
    if (response.error !== undefined) {
      return { ok: false, topicId: 0, message: '服务器未接受本次提交',
        networkMs: response.metadata.elapsedMs };
    }
    return { ok: false, topicId: 0, message: '提交结果未返回有效主题页面',
      networkMs: response.metadata.elapsedMs };
  }

  private confirmTopicId(response: TransportProbeResponse, expectedTopicId: number): number {
    const candidates: string[] = [response.metadata.effectiveUrl, response.metadata.location ?? ''];
    for (let index = 0; index < candidates.length; index++) {
      const topicId = this.topicIdFromUrl(candidates[index]);
      if (topicId > 0 && (expectedTopicId === 0 || topicId === expectedTopicId)) {
        return topicId;
      }
    }
    // A 2xx non-HTML answer (JSON acknowledgement) still confirms the write when
    // it references the resulting topic page. HTML pages are skipped because a
    // re-rendered form page also contains unrelated topic links.
    const status = response.metadata.statusCode;
    const contentType = response.metadata.contentType.toLowerCase();
    const nonHtml = contentType.length === 0 || !contentType.startsWith('text/html');
    if (status >= 200 && status < 300 && nonHtml) {
      return this.topicIdFromBody(response.body, expectedTopicId);
    }
    return 0;
  }

  private topicIdFromBody(body: string, expectedTopicId: number): number {
    let cursor = 0;
    while (cursor < body.length) {
      const marker = body.indexOf(TOPIC_URL_MARKER, cursor);
      if (marker < 0) {
        break;
      }
      const topicId = this.digitsAfter(body, marker + TOPIC_URL_MARKER.length);
      if (topicId > 0 && (expectedTopicId === 0 || topicId === expectedTopicId)) {
        return topicId;
      }
      cursor = marker + 1;
    }
    return 0;
  }

  private isAuthFailure(response: TransportProbeResponse): boolean {
    const status = response.metadata.statusCode;
    if (status === 401 || status === 403) {
      return true;
    }
    if (this.isLoginUrl(response.metadata.effectiveUrl) || this.isLoginUrl(response.metadata.location ?? '')) {
      return true;
    }
    if (status >= 200 && status < 300 && response.body.indexOf('name="password"') >= 0) {
      return true;
    }
    return false;
  }

  private isLoginUrl(value: string): boolean {
    if (value.length === 0) {
      return false;
    }
    const withoutFragment = value.split('#')[0];
    const withoutQuery = withoutFragment.split('?')[0];
    return withoutQuery === `${FORUM_ORIGIN}/login` || withoutQuery.endsWith('/login');
  }

  private topicIdFromUrl(url: string): number {
    const offset = url.indexOf(TOPIC_URL_MARKER);
    if (offset < 0) {
      return 0;
    }
    return this.digitsAfter(url, offset + TOPIC_URL_MARKER.length);
  }

  private digitsAfter(source: string, start: number): number {
    let result = 0;
    for (let index = start; index < source.length; index++) {
      const current = source.charAt(index);
      if (current < '0' || current > '9') {
        break;
      }
      result = result * 10 + current.charCodeAt(0) - 48;
    }
    return result;
  }

  private authFailure(networkMs: number): WriteResult {
    this.onSessionInvalidated?.();
    return { ok: false, topicId: 0, message: '登录已过期，请重新登录', networkMs: networkMs, authExpired: true };
  }

  private failure(message: string): WriteResult {
    return { ok: false, topicId: 0, message: message, networkMs: 0 };
  }
}
