import { webview } from '@kit.ArkWeb';
import { AppSpacing, AppTypography } from '../../common/theme/AppTheme';
import { SYS_TOP_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { CookieProbeSummary, cookieSessionBroker } from './CookieSessionBroker';

const LOGIN_URL = 'https://linux.sb/login';

@Component
export struct OfficialLoginPage {
  onClose: () => void = () => {};
  showDiagnostics: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController('official-login');
  @StorageProp(SYS_TOP_INSET_KEY) private topInset: number = 0;
  @State private authPresent: boolean = false;
  @State private csrfPresent: boolean = false;
  @State private cookieHeaderLength: number = 0;
  @State private blockedRequestCount: number = 0;
  @State private closing: boolean = false;

  aboutToDisappear(): void {
    try {
      this.controller.stop();
    } catch (_) {
      // Removing this component destroys the only ArkWeb instance used for official login.
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
    if (this.closing) {
      return;
    }
    this.closing = true;
    this.onClose();
  }

  build() {
    Column() {
      Row({ space: AppSpacing.SM }) {
        Text('LinuxSB 官方登录')
          .id('official-login-title')
          .fontSize(AppTypography.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Button(this.closing ? '正在返回' : '完成并返回')
          .id('official-login-complete')
          .enabled(!this.closing)
          .onClick(() => this.finish())
      }
      .width('100%')
      .height(this.topInset + 64)
      .padding({
        left: AppSpacing.MD,
        right: AppSpacing.MD,
        top: this.topInset + AppSpacing.XS,
        bottom: AppSpacing.XS
      })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.surface'))

      if (this.showDiagnostics) {
        Row({ space: AppSpacing.SM }) {
          Text(`bbs_auth：${this.authPresent ? '存在' : '不存在'}`)
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
          Text(`bbs_csrf：${this.csrfPresent ? '存在' : '不存在'}`)
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
          Text(`Header 长度：${this.cookieHeaderLength}`)
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding({ left: AppSpacing.MD, right: AppSpacing.MD, bottom: AppSpacing.XS })
        .backgroundColor($r('app.color.surface'))
      }

      if (this.blockedRequestCount > 0) {
        Text(`已阻止 ${this.blockedRequestCount} 个非受信域请求`)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.warning'))
          .width('100%')
          .padding({ left: AppSpacing.MD, right: AppSpacing.MD, bottom: AppSpacing.XS })
          .backgroundColor($r('app.color.surface'))
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
    .backgroundColor($r('app.color.page_background'))
  }
}
