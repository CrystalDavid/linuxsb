import { PortalAction, PortalActionResult, PortalLoadResult } from '../../models/PortalModels';
import { AuthSessionPort } from '../auth/AuthSession';
import { PortalDecodeTaskRunner } from '../protocol/PortalDecodeTask';
import { ForumFormFields, ForumTransport, TransportUploadFile } from '../transport/ForumTransport';

const FORUM_ORIGIN: string = 'https://linux.sb';

interface PortalJsonResult {
  ok?: boolean;
  message?: string;
}

export class PortalRepository {
  private transport: ForumTransport;
  private authSession: AuthSessionPort;
  private decoder: PortalDecodeTaskRunner;
  private onSessionInvalidated: (() => void) | undefined;

  constructor(transport: ForumTransport, authSession: AuthSessionPort,
    decoder: PortalDecodeTaskRunner = new PortalDecodeTaskRunner(),
    onSessionInvalidated: (() => void) | undefined = undefined) {
    this.transport = transport;
    this.authSession = authSession;
    this.decoder = decoder;
    this.onSessionInvalidated = onSessionInvalidated;
  }

  async load(path: string): Promise<PortalLoadResult> {
    const cookieHeader = this.authSession.getRequestCookieHeader();
    if (cookieHeader === undefined) {
      return { ok: false, message: '请先登录' };
    }
    if (this.transport.getAuthenticatedPage === undefined) {
      return { ok: false, message: '当前网络实现不支持此页面' };
    }
    const response = await this.transport.getAuthenticatedPage(this.absoluteUrl(path), cookieHeader);
    if (this.isAuthFailure(response.metadata.statusCode, response.metadata.effectiveUrl, response.body)) {
      this.onSessionInvalidated?.();
      return { ok: false, message: '登录已过期，请重新登录' };
    }
    if (response.error !== undefined) {
      return { ok: false, message: '页面加载失败，请稍后重试' };
    }
    try {
      return { ok: true, message: '', document: await this.decoder.decode(response.body, path) };
    } catch (_) {
      return { ok: false, message: '页面数据解析失败' };
    }
  }

  async submit(action: PortalAction,
    overrides: Record<string, string | number | boolean | string[]> = {}): Promise<PortalActionResult> {
    const cookieHeader = this.authSession.getRequestCookieHeader();
    const csrf = this.authSession.getCsrfToken?.();
    if (cookieHeader === undefined || csrf === undefined || csrf.length === 0) {
      this.onSessionInvalidated?.();
      return { ok: false, message: '登录已过期，请重新登录', authExpired: true };
    }
    if (this.transport.postForm === undefined || action.disabled) {
      return { ok: false, message: action.disabled ? '当前条件不足，暂不能执行' : '当前网络实现不支持此操作' };
    }
    const extra: Record<string, string | number | boolean | string[]> = {};
    for (let index = 0; index < action.fields.length; index++) {
      const field = action.fields[index];
      if (field.name.startsWith('_client_') || (field.type === 'checkbox' && field.value.length === 0)) {
        continue;
      }
      if (field.name.endsWith('[]')) {
        const existing = extra[field.name];
        const values: string[] = Array.isArray(existing) ? existing as string[] : [];
        values.push(field.value);
        extra[field.name] = values;
      } else {
        extra[field.name] = field.value;
      }
    }
    const overrideKeys = Object.keys(overrides);
    for (let index = 0; index < overrideKeys.length; index++) {
      extra[overrideKeys[index]] = overrides[overrideKeys[index]];
    }
    const fields = new ForumFormFields();
    fields._csrf = csrf;
    fields.extra = extra;
    const response = await this.transport.postForm(this.absoluteUrl(action.actionUrl), fields, cookieHeader);
    console.info(`[PortalWrite] action=${action.actionUrl} status=${response.metadata.statusCode} ` +
      `type=${response.metadata.contentType} error=${response.error?.kind ?? 'none'}`);
    if (this.isAuthFailure(response.metadata.statusCode, response.metadata.effectiveUrl, response.body)) {
      this.onSessionInvalidated?.();
      return { ok: false, message: '登录已过期，请重新登录', authExpired: true };
    }
    const acceptedRedirect = (response.metadata.location ?? '').startsWith(`${FORUM_ORIGIN}/`);
    if ((response.error !== undefined || response.metadata.statusCode < 200 || response.metadata.statusCode >= 400) &&
      !acceptedRedirect) {
      const uncertain = response.metadata.statusCode === 0 && response.error !== undefined &&
        (response.error.kind === 'NETWORK' || response.error.kind === 'TIMEOUT' ||
          response.error.kind === 'SESSION_CLOSED' || response.error.kind === 'UNKNOWN');
      if (uncertain) {
        return { ok: false, uncertain: true, message: '网络回执中断，正在同步服务器状态' };
      }
      return { ok: false, message: `服务器未接受本次操作（HTTP ${response.metadata.statusCode}）` };
    }
    const normalizedType = response.metadata.contentType.toLowerCase();
    const trimmedBody = response.body.trim();
    if (normalizedType.startsWith('application/json') || trimmedBody.startsWith('{')) {
      try {
        const result = JSON.parse(trimmedBody) as PortalJsonResult;
        if (result.ok === false) {
          return { ok: false, message: result.message ?? '服务器拒绝了本次操作' };
        }
        if (result.ok === true) {
          return { ok: true, message: result.message ?? this.successMessage(action.actionUrl) };
        }
      } catch (_) {}
    }
    return { ok: true, message: this.successMessage(action.actionUrl) };
  }

  async uploadAvatar(file: TransportUploadFile): Promise<PortalActionResult> {
    const cookieHeader = this.authSession.getRequestCookieHeader();
    const csrf = this.authSession.getCsrfToken?.();
    if (cookieHeader === undefined || csrf === undefined || csrf.length === 0) {
      this.onSessionInvalidated?.();
      return { ok: false, message: '登录已过期，请重新登录', authExpired: true };
    }
    if (this.transport.postMultipartFile === undefined) {
      return { ok: false, message: '当前网络实现不支持头像上传' };
    }
    const fields = new ForumFormFields();
    fields._csrf = csrf;
    file.fieldName = 'avatar';
    const response = await this.transport.postMultipartFile(`${FORUM_ORIGIN}/avatar_upload`, fields,
      file, cookieHeader);
    if (this.isAuthFailure(response.metadata.statusCode, response.metadata.effectiveUrl, response.body)) {
      this.onSessionInvalidated?.();
      return { ok: false, message: '登录已过期，请重新登录', authExpired: true };
    }
    if (response.error !== undefined || response.metadata.statusCode < 200 || response.metadata.statusCode >= 400) {
      return { ok: false, message: '头像上传失败，请稍后重试' };
    }
    try {
      const result = JSON.parse(response.body) as PortalJsonResult;
      return { ok: result.ok === true, message: result.message ?? (result.ok ? '头像已更新' : '头像上传失败') };
    } catch (_) {
      return { ok: false, message: '头像上传结果无法识别' };
    }
  }

  private absoluteUrl(path: string): string {
    if (path.startsWith(`${FORUM_ORIGIN}/`)) {
      return path;
    }
    return path.startsWith('/') ? `${FORUM_ORIGIN}${path}` : `${FORUM_ORIGIN}/${path}`;
  }

  private successMessage(actionUrl: string): string {
    if (actionUrl.startsWith('/direct_messages/')) {
      return '私信已发送';
    }
    if (actionUrl === '/gacha_pull' || actionUrl === '/gacha_pull_10') {
      return '抽取已完成，正在同步称号与积分';
    }
    if (actionUrl === '/gacha_market_publish') {
      return '交易已发布';
    }
    if (actionUrl === '/gacha_market_buy') {
      return '购买已完成';
    }
    return '操作已完成';
  }

  private isAuthFailure(status: number, effectiveUrl: string, body: string): boolean {
    const hasLoginForm = body.indexOf('action="/login"') >= 0 && body.indexOf('name="password"') >= 0;
    return status === 401 || status === 403 || effectiveUrl.endsWith('/login') || hasLoginForm;
  }
}
