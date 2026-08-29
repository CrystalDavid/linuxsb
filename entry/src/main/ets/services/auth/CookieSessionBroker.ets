import { webview } from '@kit.ArkWeb';

const COOKIE_SCOPE = 'https://linux.sb/';

export interface CookieProbeSummary {
  bbsAuthPresent: boolean;
  bbsCsrfPresent: boolean;
  cookieHeaderLength: number;
}

export class CookieSessionBroker {
  private requestCookieHeader: string = '';

  inspectArkWebCookies(): CookieProbeSummary {
    this.requestCookieHeader = '';
    try {
      const rawHeader = webview.WebCookieManager.fetchCookieSync(COOKIE_SCOPE);
      const authPair = this.findCookiePair(rawHeader, 'bbs_auth');
      const csrfPair = this.findCookiePair(rawHeader, 'bbs_csrf');
      const requiredPairs: string[] = [];
      if (authPair.length > 0) {
        requiredPairs.push(authPair);
      }
      if (csrfPair.length > 0) {
        requiredPairs.push(csrfPair);
      }
      this.requestCookieHeader = requiredPairs.join('; ');
      return {
        bbsAuthPresent: authPair.length > 0,
        bbsCsrfPresent: csrfPair.length > 0,
        cookieHeaderLength: rawHeader.length
      };
    } catch (_) {
      return {
        bbsAuthPresent: false,
        bbsCsrfPresent: false,
        cookieHeaderLength: 0
      };
    }
  }

  getRequestCookieHeader(): string | undefined {
    return this.requestCookieHeader.length === 0 ? undefined : this.requestCookieHeader;
  }

  getCsrfToken(): string | undefined {
    const pair = this.findCookiePair(this.requestCookieHeader, 'bbs_csrf');
    const equals = pair.indexOf('=');
    if (equals < 0 || equals + 1 >= pair.length) {
      return undefined;
    }
    return this.decodeCookieValue(pair.substring(equals + 1));
  }

  // Cookie 值通常按 URL 编码存储（例如 '=' 写成 %3D、'/' 写成 %2F）。表单
  // 字段必须送解码后的原文，否则服务端拿到的 _csrf 与会话里的值不一致，
  // 写操作会被 403 拒绝。不含 '%' 时原样返回，不引入额外副作用。
  private decodeCookieValue(value: string): string {
    if (value.indexOf('%') < 0) {
      return value;
    }
    try {
      return decodeURIComponent(value);
    } catch (_) {
      return value;
    }
  }

  clearMemory(): void {
    this.requestCookieHeader = '';
  }

  private findCookiePair(header: string, expectedName: string): string {
    let segmentStart = 0;
    while (segmentStart <= header.length) {
      let segmentEnd = header.indexOf(';', segmentStart);
      if (segmentEnd < 0) {
        segmentEnd = header.length;
      }
      const segment = header.substring(segmentStart, segmentEnd).trim();
      const equals = segment.indexOf('=');
      if (equals > 0 && segment.substring(0, equals).trim() === expectedName) {
        const value = segment.substring(equals + 1).trim();
        if (value.length > 0) {
          return `${expectedName}=${value}`;
        }
      }
      if (segmentEnd >= header.length) {
        break;
      }
      segmentStart = segmentEnd + 1;
    }
    return '';
  }
}

export const cookieSessionBroker = new CookieSessionBroker();
