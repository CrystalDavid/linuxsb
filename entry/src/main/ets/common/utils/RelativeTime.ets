export class RelativeTime {
  static fromEpochSeconds(epochSeconds: number, nowMs: number = Date.now()): string {
    if (epochSeconds <= 0) {
      return '';
    }
    const seconds = Math.max(0, Math.floor(nowMs / 1000) - epochSeconds);
    if (seconds < 60) {
      return '刚刚';
    }
    if (seconds < 3600) {
      return `${Math.floor(seconds / 60)} 分钟前`;
    }
    if (seconds < 86400) {
      return `${Math.floor(seconds / 3600)} 小时前`;
    }
    if (seconds < 2592000) {
      return `${Math.floor(seconds / 86400)} 天前`;
    }
    if (seconds < 31536000) {
      return `${Math.floor(seconds / 2592000)} 个月前`;
    }
    return `${Math.floor(seconds / 31536000)} 年前`;
  }
}
