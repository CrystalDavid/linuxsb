/**
 * Native presentation metadata for linux.sb forums.
 *
 * Counts and server colors remain protocol data. Descriptions below are fallbacks
 * sampled from each public /forum/{id} header so the directory stays useful before
 * a forum page has been opened in the current process.
 */
export class ForumVisuals {
  static accent(forumId: number, serverColor: string = ''): ResourceColor {
    switch (forumId) {
      case 1:
        return '#FF2F6BFF';
      case 2:
        return '#FFF43F7A';
      case 3:
        return '#FF8B5CF6';
      case 4:
        return '#FF00A9A5';
      case 5:
        return '#FF3BA55D';
      case 6:
        return '#FF4C789E';
      case 7:
        return '#FF7C3AED';
      case 8:
        return '#FFF59E0B';
      case 9:
        return '#FFE15241';
      default:
        return serverColor.length > 0 ? serverColor : $r('app.color.brand_primary');
    }
  }

  static softAccent(forumId: number): ResourceColor {
    switch (forumId) {
      case 1:
        return '#242F6BFF';
      case 2:
        return '#24F43F7A';
      case 3:
        return '#248B5CF6';
      case 4:
        return '#2400A9A5';
      case 5:
        return '#243BA55D';
      case 6:
        return '#244C789E';
      case 7:
        return '#247C3AED';
      case 8:
        return '#24F59E0B';
      case 9:
        return '#24E15241';
      default:
        return $r('app.color.brand_soft');
    }
  }

  static description(forumId: number, serverDescription: string = ''): string {
    if (serverDescription.trim().length > 0) {
      return serverDescription.trim();
    }
    switch (forumId) {
      case 1:
        return '闲聊区域，不知道发哪个版块就发这里！';
      case 2:
        return '抽抽抽抽 狠狠滴抽！非必要，不要停！';
      case 3:
        return '分享软件、源码、资料、文件、素材等。';
      case 4:
        return '编程、AI、建站、设计等互联网技术交流。';
      case 5:
        return '寻求社区大佬的版主专区，解决大家的各种难题！';
      case 6:
        return '关于社区发展、功能、使用问题、管理问题等相关话题';
      case 8:
        return '推广帖专区，拉人，aff 都可以发这里，首页不展示。';
      case 9:
        return '发布社区重要公告';
      default:
        return '';
    }
  }
}
