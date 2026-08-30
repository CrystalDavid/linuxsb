import { webview } from '@kit.ArkWeb';

// Cloudflare ties cf_clearance to the browser User-Agent. The hidden transport
// host and the visible login/challenge page must therefore use the exact same
// browser identity. Keep this value browser-shaped; do not append app markers.
export const FORUM_ARKWEB_USER_AGENT: string =
  'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 ' +
    '(KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36';

export class ArkWebSession {
  static configureCookies(): void {
    try {
      webview.WebCookieManager.putAcceptCookieEnabled(true);
      webview.WebCookieManager.putAcceptThirdPartyCookieEnabled(true);
    } catch (_) {
      // Older compatible systems may not expose every cookie switch. ArkWeb's
      // defaults remain usable, so configuration is best-effort.
    }
  }

  static applyUserAgent(controller: webview.WebviewController): void {
    try {
      controller.setCustomUserAgent(FORUM_ARKWEB_USER_AGENT);
    } catch (_) {
      // A controller can be destroyed while an overlay is closing.
    }
  }

  static saveCookies(): void {
    try {
      webview.WebCookieManager.saveCookieAsync().catch(() => {});
    } catch (_) {
      // Cookie persistence is a best-effort durability step. The in-memory jar
      // is already shared by every ArkWeb instance in the process.
    }
  }
}
