import { AuthSessionPort } from '../auth/AuthSession';
import { ForumFormFields, ForumTransport } from '../transport/ForumTransport';

const FORUM_ORIGIN: string = 'https://linux.sb';

export interface WriteResult {
  ok: boolean;
  topicId: number;
  message: string;
  networkMs: number;
}

export class WriteRepository {
  private transport: ForumTransport;
  private authSession: AuthSessionPort;

  constructor(transport: ForumTransport, authSession: AuthSessionPort) {
    this.transport = transport;
    this.authSession = authSession;
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
      return this.failure('登录会话不可用，请重新登录');
    }
    if (this.transport.postForm === undefined) {
      return this.failure('当前网络实现不支持写操作');
    }
    const response = await this.transport.postForm(url, fields, cookieHeader);
    if (response.error !== undefined) {
      return { ok: false, topicId: 0, message: '服务器未接受本次提交',
        networkMs: response.metadata.elapsedMs };
    }
    const topicId = this.topicIdFromUrl(response.metadata.effectiveUrl);
    if (topicId <= 0 || (expectedTopicId > 0 && topicId !== expectedTopicId)) {
      return { ok: false, topicId: 0, message: '提交结果未返回有效主题页面',
        networkMs: response.metadata.elapsedMs };
    }
    return { ok: true, topicId: topicId, message: '', networkMs: response.metadata.elapsedMs };
  }

  private topicIdFromUrl(url: string): number {
    const marker = '/topic/';
    const offset = url.indexOf(marker);
    if (offset < 0) {
      return 0;
    }
    let result = 0;
    for (let index = offset + marker.length; index < url.length; index++) {
      const current = url.charAt(index);
      if (current < '0' || current > '9') {
        break;
      }
      result = result * 10 + current.charCodeAt(0) - 48;
    }
    return result;
  }

  private failure(message: string): WriteResult {
    return { ok: false, topicId: 0, message: message, networkMs: 0 };
  }
}
