import { webview } from '@kit.ArkWeb';
import { CookieProbeSummary, cookieSessionBroker } from '../transport/CookieSessionBroker';

const LOGIN_URL = 'https://linux.sb/login';

@Component
export struct LoginProbePage {
  onClose: () => void = () => {};
  private controller: webview.WebviewController = new webview.WebviewController('p0-login-probe');
  @State private authPresent: boolean = false;
  @State private csrfPresent: boolean = false;
  @State private cookieHeaderLength: number = 0;
  @State private blockedRequestCount: number = 0;

  aboutToDisappear(): void {
    try {
      this.controller.stop();
    } catch (_) {
      // Removing this component destroys the only ArkWeb instance used by P0.
    }
  }

  private refreshCookieProbe(): void {
    const summary: CookieProbeSummary = cookieSessionBroker.inspectArkWebCookies();
    this.authPresent = summary.bbsAuthPresent;
    this.csrfPresent = summary.bbsCsrfPresent;
    this.cookieHeaderLength = summary.cookieHeaderLength;
  }

  private isTrustedUrl(value: string): boolean {
    const origin = 'https://linux.sb';
    if (!value.startsWith(origin)) {
      return false;
    }
    if (value.length === origin.length) {
      return true;
    }
    const boundary = value.charAt(origin.length);
    return boundary === '/' || boundary === '?' || boundary === '#';
  }

  private finish(): void {
    this.refreshCookieProbe();
    try {
      this.controller.stop();
    } catch (_) {
      // The controller may already be detached during a fast close.
    }
    this.onClose();
  }

  build() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('LinuxSB 官方登录')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Text('临时 ArkWeb，仅允许 linux.sb；应用不收集账号密码')
            .fontSize(12)
            .fontColor('#666666')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('完成并关闭')
          .onClick(() => this.finish())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 })

      Row({ space: 10 }) {
        Text(`bbs_auth：${this.authPresent ? '存在' : '不存在'}`)
          .fontSize(12)
        Text(`bbs_csrf：${this.csrfPresent ? '存在' : '不存在'}`)
          .fontSize(12)
        Text(`Header 长度：${this.cookieHeaderLength}`)
          .fontSize(12)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.blockedRequestCount > 0) {
        Text(`已阻止 ${this.blockedRequestCount} 个非受信域请求`)
          .fontSize(12)
          .fontColor('#B54708')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      Web({ src: LOGIN_URL, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(false)
        .onlineImageAccess(true)
        .onLoadIntercept((event) => {
          const trusted = this.isTrustedUrl(event.data.getRequestUrl());
          if (!trusted) {
            this.blockedRequestCount++;
          }
          return !trusted;
        })
        .onPageEnd((event) => {
          if (this.isTrustedUrl(event.url)) {
            this.refreshCookieProbe();
          }
        })
        .width('100%')
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
