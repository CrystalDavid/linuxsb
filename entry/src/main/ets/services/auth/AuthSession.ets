import { CookieProbeSummary, CookieSessionBroker, cookieSessionBroker } from './CookieSessionBroker';

export interface AuthSessionPort {
  getRequestCookieHeader(): string | undefined;
  getCsrfToken?(): string | undefined;
  captureOfficialLogin(): boolean;
  clearMemory(): void;
}

export class AuthSession implements AuthSessionPort {
  private broker: CookieSessionBroker;

  constructor(broker: CookieSessionBroker = cookieSessionBroker) {
    this.broker = broker;
  }

  getRequestCookieHeader(): string | undefined {
    return this.broker.getRequestCookieHeader();
  }

  getCsrfToken(): string | undefined {
    return this.broker.getCsrfToken();
  }

  captureOfficialLogin(): boolean {
    const summary: CookieProbeSummary = this.broker.inspectArkWebCookies();
    return summary.bbsAuthPresent && summary.bbsCsrfPresent &&
      this.broker.getRequestCookieHeader() !== undefined;
  }

  clearMemory(): void {
    this.broker.clearMemory();
  }
}
