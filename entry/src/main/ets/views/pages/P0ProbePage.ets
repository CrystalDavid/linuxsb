import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { LoginProbePage } from '../../services/auth/LoginProbePage';
import { AuthenticatedSessionProbeResult, SessionProbe } from '../../services/auth/SessionProbe';
import { ProbeDecodeTaskRunner } from '../../services/protocol/ProbeDecodeTask';
import {
  BackgroundProbeDecodeResult,
  HomeTopicProbeSummary,
  ReplyProbeSummary,
  TopicStructureProbeResult
} from '../../services/protocol/ProbeModels';
import { CookieProbeSummary, cookieSessionBroker } from '../../services/auth/CookieSessionBroker';
import { TransportProbeResponse } from '../../services/transport/ForumTransport';
import { RcpForumTransport } from '../../services/transport/RcpForumTransport';
import { TransportCachePolicy } from '../../services/transport/ForumTransport';
import { DisabledWriteContractProbe } from '../../services/transport/WriteContractProbe';

@Component
export struct P0ProbePage {
  onOpenFormalTopic: (topicId: number) => void = () => {};
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
  @State private topicStructure: string = '尚未扫描结构';
  @State private topicWarnings: string = '';

  @State private authenticatedTopicOutcome: string = 'NOT RUN';
  @State private authenticatedTopicTransport: string = '尚未请求';
  @State private authenticatedTopicCounts: string = '尚未解码';
  @State private authenticatedTopicReplyContract: string = '尚未验证回复 ID、楼层和最小字段';
  @State private authenticatedTopicParse: string = '尚未解析';
  @State private authenticatedTopicStructure: string = '尚未扫描结构';
  @State private authenticatedTopicWarnings: string = '';
  @State private authenticatedSnapshotStatus: string = '登录后 HTML 快照：NOT RUN';
  @State private topicComparison: string = '匿名与登录后响应尚未完成比较';

  private anonymousTopicSha256: string = '';
  private anonymousTopicBytes: number = -1;
  private anonymousTopicMarkers: number = -1;
  private authenticatedTopicSha256: string = '';
  private authenticatedTopicBytes: number = -1;
  private authenticatedTopicMarkers: number = -1;

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
        const response = await this.transport.getHome(TransportCachePolicy.ProbeNoStore);
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
    this.topicStructure = '尚未扫描结构';
    this.anonymousTopicSha256 = '';
    this.anonymousTopicBytes = -1;
    this.anonymousTopicMarkers = -1;
    try {
        const response = await this.transport.getTopic(topicId, TransportCachePolicy.ProbeNoStore);
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
      if (decoded.topicStructure === undefined) {
        this.topicOutcome = 'FAIL · STRUCTURE_PROBE_RESULT_MISSING';
        return;
      }
      this.topicTitle = decoded.topic.title;
      this.topicReplies = decoded.topic.replies;
      this.topicCounts = `主楼 ID ${decoded.topic.mainPostId} · 浏览 ${decoded.topic.viewCount} · 页面声明回复 ${decoded.topic.advertisedReplyCount} · 本响应含回复 ${decoded.topic.replies.length}`;
      this.topicWarnings = decoded.topic.warnings.join(' · ');
      this.topicParse = this.formatParse(decoded.execution, decoded.parseMs, decoded.inputBytes,
        decoded.outputCount, decoded.executionWarning);
      this.topicStructure = this.formatStructure(decoded.topicStructure);
      this.topicTransport = this.formatTransport(response, decoded.topicStructure.detectedBbsVersion);
      this.anonymousTopicSha256 = response.metadata.sha256;
      this.anonymousTopicBytes = response.metadata.byteLength;
      this.anonymousTopicMarkers = this.structureMarkerCount(decoded.topicStructure);
      this.refreshTopicComparison();
      const fingerprintReady = response.metadata.sha256.length === 64;
      this.topicOutcome = decoded.topic.protocolMatched && decoded.execution === 'TASKPOOL' && fingerprintReady ? 'PASS' :
        (!decoded.topic.protocolMatched ? 'FAIL · PROTOCOL_MISMATCH' :
          (decoded.execution !== 'TASKPOOL' ? 'FAIL · TASKPOOL_FALLBACK' : 'FAIL · SHA256_UNAVAILABLE'));
    } catch (error) {
      this.topicOutcome = `FAIL · ${this.safeErrorMessage(error as Error)}`;
    } finally {
      this.busyProbe = '';
    }
  }

  private async runAuthenticatedTopicProbe(): Promise<void> {
    if (this.busyProbe.length > 0) {
      return;
    }
    const topicId = this.parseTopicId(this.topicIdText);
    if (topicId <= 0) {
      this.authenticatedTopicOutcome = 'FAIL · 请输入正整数主题 ID';
      return;
    }
    const cookieSummary = cookieSessionBroker.inspectArkWebCookies();
    const cookieHeader = cookieSessionBroker.getRequestCookieHeader();
    if (!cookieSummary.bbsAuthPresent || !cookieSummary.bbsCsrfPresent || cookieHeader === undefined) {
      this.authenticatedTopicOutcome = 'NOT RUN';
      this.authenticatedTopicTransport = '缺少 bbs_auth 或 bbs_csrf，未发送登录后主题请求。';
      return;
    }
    this.busyProbe = 'authenticated-topic';
    this.authenticatedTopicOutcome = 'RUNNING';
    this.authenticatedTopicReplyContract = '尚未验证回复 ID、楼层和最小字段';
    this.authenticatedTopicWarnings = '';
    this.authenticatedTopicStructure = '尚未扫描结构';
    this.authenticatedTopicSha256 = '';
    this.authenticatedTopicBytes = -1;
    this.authenticatedTopicMarkers = -1;
    try {
        const response = await this.transport.getAuthenticatedTopic(
          topicId,
          cookieHeader,
          TransportCachePolicy.ProbeNoStore
        );
      this.authenticatedTopicTransport = this.formatTransport(response);
      if (response.error !== undefined) {
        this.authenticatedTopicOutcome = `FAIL · ${response.error.kind}`;
        return;
      }
      this.authenticatedSnapshotStatus = this.saveAuthenticatedTopicSnapshot(topicId, response.body);
      const decoded: BackgroundProbeDecodeResult = await this.decodeRunner.decode('topic', response.body,
        response.metadata.byteLength, topicId);
      if (decoded.topic === undefined || decoded.topicStructure === undefined) {
        this.authenticatedTopicOutcome = 'FAIL · PROBE_RESULT_MISSING';
        return;
      }
      this.authenticatedTopicCounts = `主楼 ID ${decoded.topic.mainPostId} · 页面声明回复 ${decoded.topic.advertisedReplyCount} · 本响应含回复 ${decoded.topic.replies.length} · 第 ${decoded.topic.currentPage} / ${decoded.topic.totalPages} 页`;
      this.authenticatedTopicReplyContract = this.formatReplyContract(decoded.topic.replies,
        decoded.topic.mainPostId);
      this.authenticatedTopicParse = this.formatParse(decoded.execution, decoded.parseMs, decoded.inputBytes,
        decoded.outputCount, decoded.executionWarning);
      this.authenticatedTopicStructure = this.formatStructure(decoded.topicStructure);
      this.authenticatedTopicWarnings = decoded.topic.warnings.join(' · ');
      this.authenticatedTopicTransport = this.formatTransport(response, decoded.topicStructure.detectedBbsVersion);
      this.authenticatedTopicSha256 = response.metadata.sha256;
      this.authenticatedTopicBytes = response.metadata.byteLength;
      this.authenticatedTopicMarkers = this.structureMarkerCount(decoded.topicStructure);
      this.refreshTopicComparison();
      const repliesMatch = decoded.topic.advertisedReplyCount === decoded.topic.replies.length ||
        (decoded.topic.nextPageUrl.length > 0 && decoded.topic.replies.length > 0);
      const replyContractMatches = this.replyContractMatches(decoded.topic.replies, decoded.topic.mainPostId);
      const fingerprintReady = response.metadata.sha256.length === 64;
      if (decoded.topic.protocolMatched && repliesMatch && replyContractMatches &&
        !this.hasFatalTopicWarning(decoded.topic.warnings) && decoded.execution === 'TASKPOOL' && fingerprintReady) {
        this.authenticatedTopicOutcome = decoded.topic.nextPageUrl.length > 0 ?
          'PASS · PAGED_REPLY_PAGE' : 'PASS · SAME_PAGE_REPLIES';
      } else if (!decoded.topic.protocolMatched) {
        this.authenticatedTopicOutcome = 'FAIL · PROTOCOL_MISMATCH';
      } else if (decoded.execution !== 'TASKPOOL') {
        this.authenticatedTopicOutcome = 'FAIL · TASKPOOL_FALLBACK';
      } else if (!fingerprintReady) {
        this.authenticatedTopicOutcome = 'FAIL · SHA256_UNAVAILABLE';
      } else if (!replyContractMatches) {
        this.authenticatedTopicOutcome = 'FAIL · REPLY_ID_FLOOR_OR_FIELD_MISMATCH';
      } else if (decoded.topicStructure.loginVisibleMarkerCount > 0) {
        this.authenticatedTopicOutcome = 'FAIL · AUTH_RESPONSE_LOGIN_GATED';
      } else {
        this.authenticatedTopicOutcome = 'FAIL · REPLY_CONTRACT_MISMATCH';
      }
    } catch (error) {
      this.authenticatedTopicOutcome = `FAIL · ${this.safeErrorMessage(error as Error)}`;
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
    this.authenticatedTopicOutcome = 'NOT RUN';
    this.authenticatedTopicTransport = '内存 Cookie Header 已清除；未发送登录后主题请求。';
    this.authenticatedTopicCounts = '尚未解码';
    this.authenticatedTopicReplyContract = '尚未验证回复 ID、楼层和最小字段';
    this.authenticatedTopicParse = '尚未解析';
    this.authenticatedTopicStructure = '尚未扫描结构';
    this.authenticatedTopicWarnings = '';
    this.authenticatedSnapshotStatus = '登录后 HTML 快照：NOT RUN';
    this.authenticatedTopicSha256 = '';
    this.authenticatedTopicBytes = -1;
    this.authenticatedTopicMarkers = -1;
    this.topicComparison = '匿名与登录后响应尚未完成比较';
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

  private saveAuthenticatedTopicSnapshot(topicId: number, body: string): string {
    if (topicId !== 15365 || body.length === 0) {
      return '登录后 HTML 快照：仅 Topic 15365 的非空响应会保存';
    }
    const fileName = 'm2-r1-1-topic-15365-authenticated.html';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const snapshot = fileIo.openSync(`${context.cacheDir}/${fileName}`,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(snapshot.fd, body);
        fileIo.fsyncSync(snapshot.fd);
      } finally {
        fileIo.closeSync(snapshot);
      }
      return `登录后 HTML 快照：PASS · ${fileName} · ${body.length} chars`;
    } catch (_) {
      return '登录后 HTML 快照：FAIL · CACHE_WRITE_ERROR';
    }
  }

  private formatTransport(response: TransportProbeResponse, bbsVersion: string = ''): string {
    const metadata = response.metadata;
    const error = response.error === undefined ? '' : ` · ${response.error.kind}(${response.error.code})`;
    const encoding = metadata.contentEncoding.length > 0 ? metadata.contentEncoding : 'identity/未声明';
    const fingerprint = metadata.sha256.length > 0 ? metadata.sha256 : '不可用';
    const version = bbsVersion.length > 0 ? ` · BBS1 ${bbsVersion}` : '';
    return `HTTP ${metadata.statusCode} · 最终 URL ${metadata.effectiveUrl} · ${metadata.contentType.length > 0 ? metadata.contentType : 'Content-Type 缺失'} · Content-Encoding ${encoding} · ${metadata.byteLength} bytes · SHA-256 ${fingerprint}${version} · ${metadata.elapsedMs} ms${error}`;
  }

  private formatStructure(value: TopicStructureProbeResult): string {
    return `结构：topic/user/reply 链接 ${value.topicLinkCount}/${value.userLinkCount}/${value.replyReferenceLinkCount} · 楼层锚点 ${value.floorAnchorCount} · post-/reply- ID ${value.postIdPrefixCount}/${value.replyIdPrefixCount} · data-floor ${value.dataFloorCount} · replyid ${value.replyIdParameterCount} · post-entry ${value.knownPostEntryMarkerCount} · 候选回复容器 ${value.candidateReplyContainerCount} · 分页链接 ${value.paginationLinkCount} · 登录可见标记 ${value.loginVisibleMarkerCount}`;
  }

  private replyContractMatches(replies: ReplyProbeSummary[], mainPostId: number): boolean {
    const replyIds = new Set<number>();
    for (let index = 0; index < replies.length; index++) {
      const reply = replies[index];
      if (reply.replyId <= 0 || reply.replyId === mainPostId || replyIds.has(reply.replyId) ||
        reply.floor !== index + 1 || reply.author.length === 0 || reply.bodyText.length === 0) {
        return false;
      }
      replyIds.add(reply.replyId);
    }
    return replies.length > 0;
  }

  private hasFatalTopicWarning(warnings: string[]): boolean {
    for (let index = 0; index < warnings.length; index++) {
      if (!warnings[index].startsWith('REPLIES_PAGED:')) {
        return true;
      }
    }
    return false;
  }

  private formatReplyContract(replies: ReplyProbeSummary[], mainPostId: number): string {
    const replyIds = new Set<number>();
    let idsUnique = true;
    let mainRepeated = false;
    let fieldsComplete = true;
    let floors = '';
    for (let index = 0; index < replies.length; index++) {
      const reply = replies[index];
      if (reply.replyId <= 0 || replyIds.has(reply.replyId)) {
        idsUnique = false;
      }
      if (reply.replyId === mainPostId) {
        mainRepeated = true;
      }
      if (reply.author.length === 0 || reply.bodyText.length === 0) {
        fieldsComplete = false;
      }
      replyIds.add(reply.replyId);
      floors += `${index === 0 ? '' : ','}${reply.floor}`;
    }
    return `回复 ID 唯一：${idsUnique ? '是' : '否'} · 主楼重复：${mainRepeated ? '是' : '否'} · 楼层：${floors.length > 0 ? floors : '无'} · 作者/正文最小字段：${fieldsComplete && replies.length > 0 ? '完整' : '不完整'}`;
  }

  private structureMarkerCount(value: TopicStructureProbeResult): number {
    return value.topicLinkCount + value.userLinkCount + value.replyReferenceLinkCount + value.floorAnchorCount +
      value.postIdPrefixCount + value.replyIdPrefixCount + value.dataFloorCount + value.replyIdParameterCount +
      value.knownPostEntryMarkerCount + value.candidateReplyContainerCount + value.paginationLinkCount +
      value.loginVisibleMarkerCount;
  }

  private refreshTopicComparison(): void {
    if (this.anonymousTopicBytes < 0 || this.authenticatedTopicBytes < 0) {
      return;
    }
    const hashEqual = this.anonymousTopicSha256.length > 0 &&
      this.anonymousTopicSha256 === this.authenticatedTopicSha256;
    this.topicComparison = `匿名/登录后：字节 ${this.anonymousTopicBytes}/${this.authenticatedTopicBytes} · SHA-256 ${hashEqual ? '相同' : '不同'} · 结构标记总数 ${this.anonymousTopicMarkers}/${this.authenticatedTopicMarkers}`;
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
            Text('P0-B  Topic 605 回复来源与解码契约')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            TextInput({ text: this.topicIdText, placeholder: '公开主题 ID' })
              .onChange((value: string) => this.topicIdText = value)
              .width('100%')
            Button('用正式原生页面打开当前主题')
              .id('diagnostics-open-formal-topic')
              .enabled(this.parseTopicId(this.topicIdText) > 0)
              .onClick(() => this.onOpenFormalTopic(this.parseTopicId(this.topicIdText)))
            Text(this.topicOutcome).fontSize(14).fontWeight(FontWeight.Medium).width('100%')
            Text(this.topicTransport).fontSize(12).fontColor('#475467').width('100%')
            Text(this.topicParse).fontSize(12).fontColor('#475467').width('100%')
            Text(this.topicStructure).fontSize(12).fontColor('#475467').width('100%')
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
            Text(`登录后主题：${this.authenticatedTopicOutcome}`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            Text(this.authenticatedTopicTransport).fontSize(12).fontColor('#475467').width('100%')
            Text(this.authenticatedTopicCounts).fontSize(12).fontColor('#475467').width('100%')
            Text(this.authenticatedTopicReplyContract).fontSize(12).fontColor('#475467').width('100%')
            Text(this.authenticatedTopicParse).fontSize(12).fontColor('#475467').width('100%')
            Text(this.authenticatedTopicStructure).fontSize(12).fontColor('#475467').width('100%')
            Text(this.authenticatedSnapshotStatus).fontSize(12).fontColor('#475467').width('100%')
            if (this.authenticatedTopicWarnings.length > 0) {
              Text(this.authenticatedTopicWarnings).fontSize(11).fontColor('#B54708').width('100%')
            }
            Text(this.topicComparison).fontSize(12).fontColor('#344054').width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              Button(this.busyProbe === 'topic' ? '请求中…' : '运行匿名 Topic 结构探针')
                .enabled(this.busyProbe.length === 0)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => this.runTopicProbe())
              Button(this.busyProbe === 'authenticated-topic' ? '请求中…' : '运行登录后 Topic 结构探针')
                .enabled(this.busyProbe.length === 0)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => this.runAuthenticatedTopicProbe())
            }
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
