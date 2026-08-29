import { AuthSessionPort } from '../auth/AuthSession';
import { ForumFormFields, ForumTransport, TransportProbeResponse, TransportUploadFile } from '../transport/ForumTransport';

const FORUM_ORIGIN: string = 'https://linux.sb';
const TOPIC_URL_MARKER: string = '/topic/';
// linux.sb 账号组的附件配额被站方限制为 0MB，服务端上传通道不可用；图片
// 改走美团图床（https://695402.xyz/mt/）的匿名接口，成功后把返回的图片
// URL 包成 markdown 片段进入正文。
const IMAGE_BED_UPLOAD_URL: string = 'https://aapi.helioho.st/upload.php';

export interface WriteResult {
  ok: boolean;
  topicId: number;
  message: string;
  networkMs: number;
  authExpired?: boolean;
}

export interface AttachmentUploadResult {
  ok: boolean;
  markdown: string;
  message: string;
  networkMs: number;
  authExpired?: boolean;
}

interface ImageBedUploadDataJson {
  url?: string;
  name?: string;
}

interface ImageBedUploadJson {
  code?: number;
  msg?: string;
  data?: ImageBedUploadDataJson;
}

export interface WriteVerificationPort {
  findTopicByTitle(forumId: number, title: string): Promise<number>;
  // 回复提交后的二次确认：重新读取主题页，确认指定正文片段已经出现在页面
  // 上。可选实现；缺失时回复只走重定向确认。
  hasReplyInTopic?(topicId: number, bodySnippet: string): Promise<boolean>;
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

  async reportReply(replyId: number, reasonType: string, details: string = ''): Promise<WriteResult> {
    const allowedReasons: string[] = [
      'advertising', 'abuse', 'illegal', 'adult', 'misinformation', 'privacy', 'spam', 'copyright'
    ];
    if (replyId <= 0 || allowedReasons.indexOf(reasonType) < 0) {
      return this.failure('请选择有效的举报原因');
    }
    const cookieHeader = this.authSession.getRequestCookieHeader();
    const csrf = this.authSession.getCsrfToken?.();
    if (cookieHeader === undefined || csrf === undefined || csrf.length === 0) {
      return this.authFailure(0);
    }
    if (this.transport.postForm === undefined) {
      return this.failure('当前网络实现不支持举报');
    }
    const fields = new ForumFormFields();
    fields._csrf = csrf;
    fields.extra = {
      'target_type': 'reply',
      'target_id': replyId,
      'reason_type': reasonType,
      'reason_details': details.trim()
    };
    const response = await this.transport.postForm(`${FORUM_ORIGIN}/content_report/${replyId}?type=reply`,
      fields, cookieHeader);
    if (this.isAuthFailure(response)) {
      return this.authFailure(response.metadata.elapsedMs);
    }
    if (response.error !== undefined || response.metadata.statusCode < 200 || response.metadata.statusCode >= 400) {
      return { ok: false, topicId: 0, message: '服务器未接受本次举报', networkMs: response.metadata.elapsedMs };
    }
    return { ok: true, topicId: 0, message: '举报已提交', networkMs: response.metadata.elapsedMs };
  }

  // 外链图床上传：匿名 multipart POST（字段名 image，无 Cookie、无 CSRF）
  // 到美团图床，成功时把返回的图片 URL 包成 ![name](url) 的 markdown 片段
  // 交给编辑器插入正文。论坛会话只约束发帖/回帖本身，不再参与图片上传，
  // 也不会向第三方图床泄露任何 linux.sb 凭据。
  async uploadAttachment(file: TransportUploadFile): Promise<AttachmentUploadResult> {
    if (this.transport.postMultipartFile === undefined) {
      return { ok: false, markdown: '', message: '当前网络实现不支持上传', networkMs: 0 };
    }
    const fields = new ForumFormFields();
    const response = await this.transport.postMultipartFile(IMAGE_BED_UPLOAD_URL, fields, file, '');
    const parsed = this.parseImageBedJson(response.body);
    if (parsed !== undefined) {
      const data = parsed.data;
      const url = data !== undefined ? (data.url ?? '') : '';
      if (parsed.code === 200 && url.length > 0) {
        const alt = this.imageBedAltText(data !== undefined ? data.name : undefined);
        return { ok: true, markdown: `![${alt}](${url})`, message: '',
          networkMs: response.metadata.elapsedMs };
      }
      const message = parsed.msg ?? '';
      if (message.length > 0) {
        return { ok: false, markdown: '', message: message, networkMs: response.metadata.elapsedMs };
      }
    }
    if (response.error !== undefined) {
      return { ok: false, markdown: '', message: '图床暂时无法访问，请稍后重试',
        networkMs: response.metadata.elapsedMs };
    }
    return { ok: false, markdown: '', message: '上传失败，请重试', networkMs: response.metadata.elapsedMs };
  }

  private parseImageBedJson(body: string): ImageBedUploadJson | undefined {
    const trimmed = body.trim();
    if (trimmed.length === 0 || trimmed.charAt(0) !== '{') {
      return undefined;
    }
    try {
      return JSON.parse(trimmed) as ImageBedUploadJson;
    } catch (_) {
      return undefined;
    }
  }

  // Alt text must never break the surrounding markdown image/link syntax.
  private imageBedAltText(name: string | undefined): string {
    const cleaned = (name ?? '').replace(/\[|\]|\r|\n/g, ' ').trim();
    return cleaned.length > 0 ? cleaned : 'image';
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
    const elapsedMs = response.metadata.elapsedMs;
    const confirmedTopicId = this.confirmTopicId(response, expectedTopicId);
    if (confirmedTopicId > 0) {
      return { ok: true, topicId: confirmedTopicId, message: '', networkMs: elapsedMs };
    }
    if (this.isAuthFailure(response)) {
      return this.authFailure(elapsedMs);
    }
    if (this.isRejected(response)) {
      return { ok: false, topicId: 0,
        message: this.submitFailureMessage(response, '服务器未接受本次提交'), networkMs: elapsedMs };
    }
    // BBS1 经常在写入成功后不返回可识别的主题地址（直接 200 返回页面，或重
    // 定向未决）。此时以服务端当前内容为唯一事实来源做二次确认，绝不能把已
    // 经发出去的内容报成失败——那会诱发用户重复发帖。
    const verifiedTopicId = await this.verifyAcceptedWrite(fields, expectedTopicId);
    if (verifiedTopicId > 0) {
      return { ok: true, topicId: verifiedTopicId, message: '', networkMs: elapsedMs };
    }
    // 结果不明：不谎报失败，也不诱导重复提交。
    return { ok: false, topicId: 0,
      message: this.submitFailureMessage(response, '已提交但结果未确认，请刷新确认，请勿重复发送'),
      networkMs: elapsedMs };
  }

  // 只有服务端明确拒绝（4xx/5xx）才算失败。未决重定向、非 HTML 响应、网络
  // 异常都可能是“写入成功但返回形式不符合预期”，一律交给二次确认判定。
  private isRejected(response: TransportProbeResponse): boolean {
    const error = response.error;
    if (error === undefined) {
      return false;
    }
    return error.kind === 'HTTP_CLIENT' || error.kind === 'HTTP_SERVER';
  }

  // 以服务端内容为事实来源反查写入结果：新主题按标题在板块列表里找，回复
  // 则重新拉取主题页确认内容已出现。
  private async verifyAcceptedWrite(fields: ForumFormFields, expectedTopicId: number): Promise<number> {
    if (this.verifier === undefined) {
      return 0;
    }
    if (expectedTopicId === 0 && (fields.forum_id ?? 0) > 0) {
      return this.verifier.findTopicByTitle(fields.forum_id ?? 0, fields.title ?? '');
    }
    if (expectedTopicId > 0 && this.verifier.hasReplyInTopic !== undefined) {
      const snippet = this.searchableSnippet(fields.body ?? '');
      if (snippet.length === 0) {
        return 0;
      }
      const accepted = await this.verifier.hasReplyInTopic(expectedTopicId, snippet);
      if (accepted) {
        return expectedTopicId;
      }
    }
    return 0;
  }

  // 提取可用于页面比对的纯文本片段：去掉 markdown 图片与链接语法、压缩空
  // 白，只取前 24 个字符，避免与页面 HTML 结构或排版差异纠缠。
  private searchableSnippet(body: string): string {
    const withoutImages = body.replace(/!\[[^\]]*\]\([^)]*\)/g, ' ');
    const withoutLinks = withoutImages.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1');
    const collapsed = withoutLinks.replace(/\s+/g, ' ').trim();
    return collapsed.length > 24 ? collapsed.substring(0, 24) : collapsed;
  }

  // 写失败时把服务端的真实回应带进提示：HTTP 状态码、传输层错误类型和正文
  // 片段。泛化的“服务器未接受本次提交”无法区分 403（CSRF/权限失效）、5xx、
  // 网络异常，也会掩盖“内容其实已写入、只是没识别出主题页”的假失败。
  private submitFailureMessage(response: TransportProbeResponse, summary: string): string {
    const parts: string[] = [`${summary}（HTTP ${response.metadata.statusCode}）`];
    const detail = response.error?.message ?? '';
    if (detail.length > 0) {
      parts.push(detail);
    }
    const snippet = this.serverTextSnippet(response.body);
    if (snippet.length > 0) {
      parts.push(snippet);
    }
    return parts.join(' · ');
  }

  // 去掉标签后压缩空白，取正文前 120 字，把服务端的校验/错误提示直接显示
  // 给用户，便于一次定位真实原因。
  private serverTextSnippet(body: string): string {
    const text = body.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
    return text.length > 0 ? text.substring(0, 120) : '';
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
