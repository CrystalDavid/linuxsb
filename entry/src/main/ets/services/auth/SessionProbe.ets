import { HtmlToken, HtmlTokenType, LightweightHtmlTokenizer } from '../protocol/LightweightHtmlTokenizer';
import { collapseWhitespace } from '../protocol/HtmlProbeUtils';
import { ForumTransport } from '../transport/ForumTransport';
import { CookieSessionBroker } from './CookieSessionBroker';

export interface AuthenticatedSessionProbeResult {
  attempted: boolean;
  serverRecognized: boolean;
  redirectedToLogin: boolean;
  statusCode: number;
  elapsedMs: number;
  reason: string;
}

export class SessionProbe {
  private transport: ForumTransport;
  private cookieBroker: CookieSessionBroker;

  constructor(transport: ForumTransport, cookieBroker: CookieSessionBroker) {
    this.transport = transport;
    this.cookieBroker = cookieBroker;
  }

  async verify(): Promise<AuthenticatedSessionProbeResult> {
    const cookieSummary = this.cookieBroker.inspectArkWebCookies();
    const cookieHeader = this.cookieBroker.getRequestCookieHeader();
    if (!cookieSummary.bbsAuthPresent || !cookieSummary.bbsCsrfPresent || cookieHeader === undefined) {
      return {
        attempted: false,
        serverRecognized: false,
        redirectedToLogin: false,
        statusCode: 0,
        elapsedMs: 0,
        reason: 'REQUIRED_COOKIE_MISSING'
      };
    }

    const response = await this.transport.getAuthenticatedNotifications(cookieHeader);
    const redirectedToLogin = this.isLoginUrl(response.metadata.effectiveUrl) || this.isLoginDocument(response.body);
    const serverRecognized = response.error === undefined && response.metadata.statusCode >= 200 &&
      response.metadata.statusCode < 300 && !redirectedToLogin;
    return {
      attempted: true,
      serverRecognized: serverRecognized,
      redirectedToLogin: redirectedToLogin,
      statusCode: response.metadata.statusCode,
      elapsedMs: response.metadata.elapsedMs,
      reason: serverRecognized ? 'SERVER_RECOGNIZED_SESSION' : (response.error?.kind ?? 'LOGIN_REDIRECT')
    };
  }

  private isLoginUrl(value: string): boolean {
    const withoutFragment = value.split('#')[0];
    const withoutQuery = withoutFragment.split('?')[0];
    return withoutQuery === 'https://linux.sb/login' || withoutQuery.endsWith('/login');
  }

  private isLoginDocument(html: string): boolean {
    let titleDepth = 0;
    let titleText = '';
    new LightweightHtmlTokenizer().scan(html, (token: HtmlToken) => {
      if (token.type === HtmlTokenType.START_TAG && token.name === 'title') {
        titleDepth = 1;
        return;
      }
      if (token.type === HtmlTokenType.START_TAG && titleDepth > 0) {
        titleDepth++;
      } else if (token.type === HtmlTokenType.TEXT && titleDepth > 0) {
        titleText += token.text;
      } else if (token.type === HtmlTokenType.END_TAG && titleDepth > 0) {
        titleDepth--;
      }
    });
    return collapseWhitespace(titleText).startsWith('登录');
  }
}
