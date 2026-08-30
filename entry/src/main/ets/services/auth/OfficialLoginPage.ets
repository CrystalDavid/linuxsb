import { webview } from '@kit.ArkWeb';
import { AppSpacing, AppTypography } from '../../common/theme/AppTheme';
import { Typography } from '../../common/theme/DesignSystem';
import { SYS_TOP_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { CookieProbeSummary, cookieSessionBroker } from './CookieSessionBroker';
import { arkWebForumBridge } from './ArkWebForumBridge';
import { ArkWebSession } from './ArkWebSession';

const LOGIN_URL = 'https://linux.sb/login';
const CHALLENGE_URL = 'https://linux.sb/';
const CLOUDFLARE_CHALLENGE_ORIGIN = 'https://challenges.cloudflare.com';
const CHALLENGE_POLL_INTERVAL_MS = 2000;

@Component
export struct OfficialLoginPage {
  onClose: () => void = () => {};
  onChallengeResolved: () => void = () => {};
  showDiagnostics: boolean = false;
  challengeMode: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController('official-login');
  @StorageProp(SYS_TOP_INSET_KEY) private topInset: number = 0;
  @State private authPresent: boolean = false;
  @State private csrfPresent: boolean = false;
  @State private cookieHeaderLength: number = 0;
  @State private blockedRequestCount: number = 0;
  @State private closing: boolean = false;
  private challengePollTimer: number = -1;
  private challengeProbeRunning: boolean = false;

  aboutToAppear(): void {
    webview.WebviewController.initializeWebEngine();
    ArkWebSession.configureCookies();
    if (this.challengeMode) {
      this.startChallengePolling();
    }
  }

  aboutToDisappear(): void {
    this.stopChallengePolling();
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
    if (value.startsWith(CLOUDFLARE_CHALLENGE_ORIGIN)) {
      const cloudflareBoundary = value.charAt(CLOUDFLARE_CHALLENGE_ORIGIN.length);
      return value.length === CLOUDFLARE_CHALLENGE_ORIGIN.length || cloudflareBoundary === '/' ||
        cloudflareBoundary === '?' || cloudflareBoundary === '#';
    }
    if (value.startsWith(origin)) {
      if (value.length === origin.length) {
        return true;
      }
      const boundary = value.charAt(origin.length);
      return boundary === '/' || boundary === '?' || boundary === '#';
    }
    return false;
  }

  private finish(): void {
    if (this.closing) {
      return;
    }
    this.closing = true;
    this.onClose();
  }

  private pageTitle(): string {
    return this.challengeMode ? 'Cloudflare 验证' : 'LinuxSB 官方登录';
  }

  private actionLabel(): string {
    if (this.closing) {
      return '正在返回';
    }
    return this.challengeMode ? '返回应用' : '完成并返回';
  }

  private startUrl(): string {
    return this.challengeMode ? CHALLENGE_URL : LOGIN_URL;
  }

  build() {
    Column() {
      Row({ space: AppSpacing.SM }) {
        Text(this.pageTitle())
          .id('official-login-title')
          .fontSize(Typography.PAGE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Button(this.actionLabel())
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

      Web({ src: this.startUrl(), controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .databaseAccess(true)
        .fileAccess(false)
        .onlineImageAccess(true)
        .imageAccess(true)
        .mixedMode(MixedMode.All)
        .cacheMode(CacheMode.Default)
        .onControllerAttached(() => ArkWebSession.applyUserAgent(this.controller))
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
            ArkWebSession.saveCookies();
            if (this.challengeMode) {
              this.pollChallenge();
            }
          }
        })
        .width('100%')
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  private startChallengePolling(): void {
    this.stopChallengePolling();
    this.challengePollTimer = setInterval(() => this.pollChallenge(), CHALLENGE_POLL_INTERVAL_MS);
  }

  private stopChallengePolling(): void {
    if (this.challengePollTimer >= 0) {
      clearInterval(this.challengePollTimer);
      this.challengePollTimer = -1;
    }
  }

  private async pollChallenge(): Promise<void> {
    if (!this.challengeMode || this.closing || this.challengeProbeRunning) {
      return;
    }
    this.challengeProbeRunning = true;
    const resolved = await arkWebForumBridge.canAccessForum();
    this.challengeProbeRunning = false;
    if (!resolved || this.closing) {
      return;
    }
    this.closing = true;
    ArkWebSession.saveCookies();
    this.stopChallengePolling();
    this.onChallengeResolved();
  }
}
