import { LoginProbePage } from '../../services/auth/LoginProbePage';
import { AuthenticatedSessionProbeResult, SessionProbe } from '../../services/auth/SessionProbe';
import { ProbeDecodeTaskRunner } from '../../services/protocol/ProbeDecodeTask';
import { HomeTopicProbeSummary, ReplyProbeSummary } from '../../services/protocol/ProbeModels';
import { CookieProbeSummary, cookieSessionBroker } from '../../services/transport/CookieSessionBroker';
import { TransportProbeResponse } from '../../services/transport/ForumTransport';
import { RcpForumTransport } from '../../services/transport/RcpForumTransport';
import { DisabledWriteContractProbe } from '../../services/transport/WriteContractProbe';

@Component
export struct P0ProbePage {
  private transport: RcpForumTransport = new RcpForumTransport();
  private decodeRunner: ProbeDecodeTaskRunner = new ProbeDecodeTaskRunner();
  private writeProbe: DisabledWriteContractProbe = new DisabledWriteContractProbe();

  @State private showLogin: boolean = false;
  @State private busyProbe: string = '';
  @State private globalNote: string = '所有结果均为当前设备本次运行结果；未点击的项目保持 NOT RUN。';

  @State private homeOutcome: string = 'NOT RUN';
  @State private homeTransport: string = '尚未请求';
  @State private homeVersion: string = '';
  @State private homeTopics: HomeTopicProbeSummary[] = [];
  @State private homeParse: string = '尚未解析';
  @State private homeWarnings: string = '';

  @State private topicIdText: string = '605';
  @State private topicOutcome: string = 'NOT RUN';
  @State private topicTransport: string = '尚未请求';
  @State private topicTitle: string = '';
  @State private topicCounts: string = '';
  @State private topicReplies: ReplyProbeSummary[] = [];
  @State private topicParse: string = '尚未解析';
  @State private topicWarnings: string = '';

  @State private cookieOutcome: string = 'NOT RUN';
  @State private cookieSummary: string = '尚未检查';
  @State private sessionOutcome: string = 'NOT RUN';
  @State private sessionSummary: string = '尚未执行登录后 RCP 请求';

  aboutToDisappear(): void {
    this.transport.close();
    cookieSessionBroker.clearMemory();
  }

  private async runHomeProbe(): Promise<void> {
    if (this.busyProbe.length > 0) {
      return;
    }
    this.busyProbe = 'home';
    this.homeOutcome = 'RUNNING';
    this.homeTopics = [];
    this.homeWarnings = '';
    try {
      const response = await this.transport.getHome();
      this.homeTransport = this.formatTransport(response);
      if (response.error !== undefined) {
        this.homeOutcome = `FAIL · ${response.error.kind}`;
        return;
      }
      const decoded = await this.decodeRunner.decode('home', response.body, response.metadata.byteLength);
      if (decoded.home === undefined) {
        this.homeOutcome = 'FAIL · DECODER_RESULT_MISSING';
        return;
      }
      this.homeVersion = decoded.home.bbsVersion;
      this.homeTopics = decoded.home.topics;
      this.homeWarnings = decoded.home.warnings.join(' · ');
      this.homeParse = this.formatParse(decoded.execution, decoded.parseMs, decoded.inputBytes,
        decoded.outputCount, decoded.executionWarning);
      this.homeOutcome = decoded.home.protocolMatched && decoded.execution === 'TASKPOOL' ? 'PASS' :
        (decoded.home.protocolMatched ? 'FAIL · TASKPOOL_FALLBACK' : 'FAIL · PROTOCOL_MISMATCH');
    } catch (error) {
      this.homeOutcome = `FAIL · ${this.safeErrorMessage(error as Error)}`;
    } finally {
      this.busyProbe = '';
    }
  }

  private async runTopicProbe(): Promise<void> {
    if (this.busyProbe.length > 0) {
      return;
    }
    const topicId = this.parseTopicId(this.topicIdText);
    if (topicId <= 0) {
      this.topicOutcome = 'FAIL · 请输入正整数主题 ID';
      return;
    }
    this.busyProbe = 'topic';
    this.topicOutcome = 'RUNNING';
    this.topicReplies = [];
    this.topicWarnings = '';
    try {
      const response = await this.transport.getTopic(topicId);
      this.topicTransport = this.formatTransport(response);
      if (response.error !== undefined) {
        this.topicOutcome = `FAIL · ${response.error.kind}`;
        return;
      }
      const decoded = await this.decodeRunner.decode('topic', response.body, response.metadata.byteLength, topicId);
      if (decoded.topic === undefined) {
        this.topicOutcome = 'FAIL · DECODER_RESULT_MISSING';
        return;
      }
      this.topicTitle = decoded.topic.title;
      this.topicReplies = decoded.topic.replies;
      this.topicCounts = `主楼 ID ${decoded.topic.mainPostId} · 浏览 ${decoded.topic.viewCount} · 页面声明回复 ${decoded.topic.advertisedReplyCount} · 本响应含回复 ${decoded.topic.replies.length}`;
      this.topicWarnings = decoded.topic.warnings.join(' · ');
      this.topicParse = this.formatParse(decoded.execution, decoded.parseMs, decoded.inputBytes,
        decoded.outputCount, decoded.executionWarning);
      this.topicOutcome = decoded.topic.protocolMatched && decoded.execution === 'TASKPOOL' ? 'PASS' :
        (decoded.topic.protocolMatched ? 'FAIL · TASKPOOL_FALLBACK' : 'FAIL · PROTOCOL_MISMATCH');
    } catch (error) {
      this.topicOutcome = `FAIL · ${this.safeErrorMessage(error as Error)}`;
    } finally {
      this.busyProbe = '';
    }
  }

  private refreshCookieProbe(): void {
    const summary: CookieProbeSummary = cookieSessionBroker.inspectArkWebCookies();
    this.cookieOutcome = summary.bbsAuthPresent && summary.bbsCsrfPresent ? 'PASS' : 'FAIL';
    this.cookieSummary = `bbs_auth：${summary.bbsAuthPresent ? '存在' : '不存在'} · bbs_csrf：${summary.bbsCsrfPresent ? '存在' : '不存在'} · Cookie Header 总长度：${summary.cookieHeaderLength}`;
  }

  private async runAuthenticatedProbe(): Promise<void> {
    if (this.busyProbe.length > 0) {
      return;
    }
    this.busyProbe = 'session';
    this.sessionOutcome = 'RUNNING';
    try {
      const probe = new SessionProbe(this.transport, cookieSessionBroker);
      const result: AuthenticatedSessionProbeResult = await probe.verify();
      if (!result.attempted) {
        this.sessionOutcome = 'NOT RUN';
        this.sessionSummary = '缺少 bbs_auth 或 bbs_csrf，未发送登录后请求。';
        return;
      }
      this.sessionOutcome = result.serverRecognized ? 'PASS' : 'FAIL';
      this.sessionSummary = `HTTP ${result.statusCode} · ${result.elapsedMs} ms · 跳回登录：${result.redirectedToLogin ? '是' : '否'} · ${result.reason}`;
    } catch (error) {
      this.sessionOutcome = `FAIL · ${this.safeErrorMessage(error as Error)}`;
    } finally {
      this.busyProbe = '';
    }
  }

  private clearProbeSession(): void {
    this.transport.close();
    cookieSessionBroker.clearMemory();
    this.cookieOutcome = 'NOT RUN';
    this.cookieSummary = '内存 Cookie Header 已清除；ArkWeb 登录页未常驻。';
    this.sessionOutcome = 'NOT RUN';
    this.sessionSummary = 'RCP session 已关闭；下一次请求将创建新 session。';
    this.globalNote = '已清理 P0 内存会话。未修改 ArkWeb 的站点 Cookie 存储。';
  }

  private cancelRequests(): void {
    this.transport.cancelAll();
    this.globalNote = '已向复用的 RCP session 发出取消请求。';
  }

  private parseTopicId(value: string): number {
    const normalized = value.trim();
    if (normalized.length === 0) {
      return 0;
    }
    let result = 0;
    for (let index = 0; index < normalized.length; index++) {
      const current = normalized.charAt(index);
      if (current < '0' || current > '9') {
        return 0;
      }
      result = result * 10 + current.charCodeAt(0) - 48;
      if (result > 2147483647) {
        return 0;
      }
    }
    return result;
  }

  private formatTransport(response: TransportProbeResponse): string {
    const metadata = response.metadata;
    const error = response.error === undefined ? '' : ` · ${response.error.kind}(${response.error.code})`;
    return `HTTP ${metadata.statusCode} · ${metadata.byteLength} bytes · ${metadata.contentType.length > 0 ? metadata.contentType : 'Content-Type 缺失'} · ${metadata.elapsedMs} ms${error}`;
  }

  private formatParse(execution: string, elapsedMs: number, inputBytes: number, outputCount: number, warning: string): string {
    const suffix = warning.length === 0 ? '' : ` · ${warning}`;
    return `${execution} · ${elapsedMs} ms · 输入 ${inputBytes} bytes · 输出 ${outputCount}${suffix}`;
  }

  private safeErrorMessage(error: Error): string {
    return error.message === undefined || error.message.length === 0 ? 'UNKNOWN_ERROR' : error.message;
  }

  build() {
    if (this.showLogin) {
      LoginProbePage({
        onClose: () => {
          this.showLogin = false;
          this.refreshCookieProbe();
        }
      })
    } else {
      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 5 }) {
            Text('烧饼社区 · P0 技术验证')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
            Text('非官方客户端 · 技术验证，不是正式 UI')
              .fontSize(14)
              .fontColor('#B54708')
            Text(this.globalNote)
              .fontSize(12)
              .fontColor('#667085')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 4, right: 4, top: 8, bottom: 4 })

          Column({ space: 10 }) {
            Text('P0-1 / P0-2  匿名首页与首页协议')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Text(this.homeOutcome).fontSize(14).fontWeight(FontWeight.Medium).width('100%')
            Text(this.homeTransport).fontSize(12).fontColor('#475467').width('100%')
            Text(this.homeParse).fontSize(12).fontColor('#475467').width('100%')
            if (this.homeVersion.length > 0) {
              Text(`BBS1：${this.homeVersion} · 主题数：${this.homeTopics.length}`)
                .fontSize(13)
                .width('100%')
            }
            ForEach(this.homeTopics.slice(0, 5), (item: HomeTopicProbeSummary) => {
              Text(`#${item.topicId}  ${item.title}  ·  ${item.forumName.length > 0 ? item.forumName : '版块缺失'}`)
                .fontSize(12)
                .maxLines(2)
                .width('100%')
            }, (item: HomeTopicProbeSummary) => item.topicId.toString())
            if (this.homeWarnings.length > 0) {
              Text(this.homeWarnings).fontSize(11).fontColor('#B54708').width('100%')
            }
            Button(this.busyProbe === 'home' ? '请求中…' : '运行匿名首页 RCP')
              .enabled(this.busyProbe.length === 0)
              .onClick(() => this.runHomeProbe())
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(16)

          Column({ space: 10 }) {
            Text('P0-3  匿名主题与主题协议')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            TextInput({ text: this.topicIdText, placeholder: '公开主题 ID' })
              .onChange((value: string) => this.topicIdText = value)
              .width('100%')
            Text(this.topicOutcome).fontSize(14).fontWeight(FontWeight.Medium).width('100%')
            Text(this.topicTransport).fontSize(12).fontColor('#475467').width('100%')
            Text(this.topicParse).fontSize(12).fontColor('#475467').width('100%')
            if (this.topicTitle.length > 0) {
              Text(this.topicTitle).fontSize(14).fontWeight(FontWeight.Medium).width('100%')
              Text(this.topicCounts).fontSize(12).fontColor('#475467').width('100%')
            }
            ForEach(this.topicReplies.slice(0, 8), (item: ReplyProbeSummary) => {
              Text(`回复 ID ${item.replyId} · 楼层 ${item.floor > 0 ? item.floor : '缺失'}`)
                .fontSize(12)
                .width('100%')
            }, (item: ReplyProbeSummary) => item.replyId.toString())
            if (this.topicWarnings.length > 0) {
              Text(this.topicWarnings).fontSize(11).fontColor('#B54708').width('100%')
            }
            Button(this.busyProbe === 'topic' ? '请求中…' : '运行公开主题 RCP')
              .enabled(this.busyProbe.length === 0)
              .onClick(() => this.runTopicProbe())
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(16)

          Column({ space: 10 }) {
            Text('P0-4 / P0-5 / P0-6  官方登录与会话衔接')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Text('ArkWeb 只在登录页打开期间存在；关闭后业务请求仍只走 RCP。')
              .fontSize(12)
              .fontColor('#475467')
              .width('100%')
            Text(`Cookie 探针：${this.cookieOutcome}`).fontSize(14).width('100%')
            Text(this.cookieSummary).fontSize(12).fontColor('#475467').width('100%')
            Text(`登录后 RCP：${this.sessionOutcome}`).fontSize(14).width('100%')
            Text(this.sessionSummary).fontSize(12).fontColor('#475467').width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              Button('打开官方登录')
                .margin({ right: 8, bottom: 8 })
                .onClick(() => this.showLogin = true)
              Button('只检查 Cookie')
                .margin({ right: 8, bottom: 8 })
                .onClick(() => this.refreshCookieProbe())
              Button(this.busyProbe === 'session' ? '验证中…' : '用内存 Header 验证 RCP')
                .enabled(this.busyProbe.length === 0)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => this.runAuthenticatedProbe())
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(16)

          Column({ space: 10 }) {
            Text('P0-8  写契约保护')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Text(this.writeProbe.statusText)
              .fontSize(13)
              .fontColor('#B42318')
              .width('100%')
            Button('发帖 / 回复（已禁用）')
              .enabled(this.writeProbe.enabled)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(16)

          Flex({ wrap: FlexWrap.Wrap }) {
            Button('取消当前 RCP 请求')
              .enabled(this.busyProbe.length > 0)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => this.cancelRequests())
            Button('清理 P0 内存会话')
              .margin({ right: 8, bottom: 8 })
              .onClick(() => this.clearProbeSession())
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 28 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F4F7')
      .scrollBar(BarState.Auto)
    }
  }
}
