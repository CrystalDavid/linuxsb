import { webview } from '@kit.ArkWeb';
import { arkWebForumBridge, FORUM_BOOTSTRAP_URL } from './ArkWebForumBridge';
import { ArkWebSession } from './ArkWebSession';

const HOST_WATCHDOG_MS: number = 12000;

@Component
export struct ArkWebTransportHost {
  private controller: webview.WebviewController = new webview.WebviewController('forum-transport-host');
  private ready: boolean = false;
  private watchdogTimer: number = -1;

  aboutToAppear(): void {
    webview.WebviewController.initializeWebEngine();
    ArkWebSession.configureCookies();
    this.startWatchdog();
  }

  aboutToDisappear(): void {
    this.clearWatchdog();
    try {
      this.controller.stop();
    } catch (_) {}
    arkWebForumBridge.markUnavailable();
  }

  build() {
    Web({ src: FORUM_BOOTSTRAP_URL, controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .databaseAccess(true)
      .fileAccess(false)
      .onlineImageAccess(true)
      .imageAccess(true)
      .mixedMode(MixedMode.All)
      .cacheMode(CacheMode.Default)
      .javaScriptProxy(arkWebForumBridge.createJavaScriptProxy(this.controller))
      .onControllerAttached(() => ArkWebSession.applyUserAgent(this.controller))
      .onPageEnd(() => {
        this.ready = true;
        this.clearWatchdog();
        ArkWebSession.saveCookies();
        arkWebForumBridge.markReady(this.controller);
      })
      .onErrorReceive((event: OnErrorReceiveEvent) => {
        if (!this.ready && event.request.isMainFrame()) {
          this.clearWatchdog();
          arkWebForumBridge.markUnavailable();
        }
      })
      // Cloudflare rejects a 1x1 automation-looking viewport. A real viewport
      // stays behind the opaque native UI, while the document itself is the
      // tiny same-origin robots.txt bootstrap rather than the heavy homepage.
      .width('100%')
      .height('100%')
      .opacity(0.01)
      .hitTestBehavior(HitTestMode.None)
  }

  private startWatchdog(): void {
    this.clearWatchdog();
    this.watchdogTimer = setTimeout(() => {
      this.watchdogTimer = -1;
      if (!this.ready) {
        arkWebForumBridge.markUnavailable();
      }
    }, HOST_WATCHDOG_MS);
  }

  private clearWatchdog(): void {
    if (this.watchdogTimer >= 0) {
      clearTimeout(this.watchdogTimer);
      this.watchdogTimer = -1;
    }
  }
}
