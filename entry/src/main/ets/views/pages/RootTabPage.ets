import { bundleManager } from '@kit.AbilityKit';
import {
  buildTopicRouteParam,
  DIAGNOSTICS_ROUTE,
  isTopicRouteParam,
  TOPIC_ROUTE,
  TopicRouteParam
} from '../../app/AppRoutes';
import { m1Runtime } from '../../app/M1Runtime';
import { SemanticColors } from '../../common/theme/DesignSystem';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { OfficialLoginPage } from '../../services/auth/OfficialLoginPage';
import { TopicOpenTrace } from '../../services/logging/TopicOpenTrace';
import { HomePage } from './HomePage';
import { P0ProbePage } from './P0ProbePage';
import { TopicDetailPage } from './TopicDetailPage';

function isDebugPackage(): boolean {
  try {
    return bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    ).appInfo.debug;
  } catch (_) {
    return false;
  }
}

@Component
export struct RootTabPage {
  @Provide('appPathStack') private pathStack: NavPathStack = new NavPathStack();
  @State private showOfficialLogin: boolean = false;
  @State private loginReturnsToTopic: boolean = false;
  @State private authenticated: boolean = false;
  @State private loginReturnTopicId: number = 0;
  @State private ignoreTopicTapUntil: number = 0;
  private debugPackage: boolean = isDebugPackage();

  aboutToAppear(): void {
    TopicOpenTrace.configure(this.debugPackage);
    this.authenticated = m1Runtime.hasMemorySession();
  }

  private openTopic(topic: TopicUiModel): void {
    if (Date.now() < this.ignoreTopicTapUntil) {
      return;
    }
    TopicOpenTrace.begin(topic.topicId);
    this.pathStack.pushPath(new NavPathInfo(TOPIC_ROUTE, buildTopicRouteParam(topic.topicId, topic)));
    TopicOpenTrace.markRoutePush();
  }

  private openDiagnostics(): void {
    if (this.debugPackage) {
      this.pathStack.pushPathByName(DIAGNOSTICS_ROUTE, null);
    }
  }

  private openDebugTopic(topicId: number): void {
    if (!this.debugPackage || topicId <= 0) {
      return;
    }
    const topic = new TopicUiModel();
    topic.topicId = topicId;
    topic.title = `Topic ${topicId}`;
    this.openTopic(topic);
  }

  private requestHomeLogin(): void {
    if (this.authenticated) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '当前登录会话已就绪', duration: 1600 });
      } catch (_) {}
      return;
    }
    this.loginReturnsToTopic = false;
    this.showOfficialLogin = true;
  }

  private requestTopicLogin(routeParam: TopicRouteParam): void {
    this.loginReturnsToTopic = true;
    this.loginReturnTopicId = routeParam.topicId;
    this.showOfficialLogin = true;
  }

  private currentTopicRoute(): TopicRouteParam | undefined {
    const names = this.pathStack.getAllPathName();
    const topIndex = names.length - 1;
    if (topIndex < 0 || names[topIndex] !== TOPIC_ROUTE) {
      return undefined;
    }
    const param = this.pathStack.getParamByIndex(topIndex) as Object | undefined;
    return isTopicRouteParam(param) ? param as TopicRouteParam : undefined;
  }

  private finishOfficialLogin(): void {
    const returnsToTopic = this.loginReturnsToTopic;
    const returnTopicId = this.loginReturnTopicId;
    const currentRoute = this.currentTopicRoute();
    this.showOfficialLogin = false;
    if (returnsToTopic && returnTopicId > 0) {
      const returnSummary = currentRoute !== undefined && currentRoute.topicId === returnTopicId ?
        currentRoute.summary : m1Runtime.topicViewModel.summary;
      const restoredRoute = buildTopicRouteParam(returnTopicId, returnSummary);
      this.ignoreTopicTapUntil = Date.now() + 700;
      m1Runtime.topicViewModel.onOfficialLoginCompleted(returnTopicId, restoredRoute.summary);
      if (currentRoute === undefined || currentRoute.topicId !== returnTopicId) {
        this.pathStack.pushPath(new NavPathInfo(TOPIC_ROUTE, restoredRoute));
      }
    } else {
      m1Runtime.captureOfficialLogin();
    }
    this.authenticated = m1Runtime.hasMemorySession();
    this.loginReturnsToTopic = false;
    this.loginReturnTopicId = 0;
  }

  @Builder
  private pathMap(routeName: string, param: Object | undefined) {
    if (routeName === TOPIC_ROUTE && isTopicRouteParam(param)) {
      NavDestination() {
        TopicDetailPage({
          viewModel: m1Runtime.topicViewModel,
          topicId: (param as TopicRouteParam).topicId,
          summary: (param as TopicRouteParam).summary,
          onBack: () => this.pathStack.pop(),
          onLogin: () => this.requestTopicLogin(param as TopicRouteParam)
        })
      }
      .hideTitleBar(true)
      .backgroundColor(SemanticColors.page())
    } else if (routeName === DIAGNOSTICS_ROUTE && this.debugPackage) {
      NavDestination() {
        P0ProbePage({
          onOpenFormalTopic: (topicId: number) => this.openDebugTopic(topicId)
        })
      }
      .title('P0 开发诊断')
      .backgroundColor(SemanticColors.page())
    }
  }

  build() {
    Stack() {
      Navigation(this.pathStack) {
        HomePage({
          viewModel: m1Runtime.homeViewModel,
          debugAvailable: this.debugPackage,
          authenticated: this.authenticated,
          onTopicSelected: (topic: TopicUiModel) => this.openTopic(topic),
          onOpenDiagnostics: () => this.openDiagnostics(),
          onLogin: () => this.requestHomeLogin(),
          onPrefetch: (topicIds: number[]) => m1Runtime.prefetchTopics(topicIds),
          onCancelPrefetch: () => m1Runtime.cancelPrefetch()
        })
      }
      .hideTitleBar(true)
      .navDestination(this.pathMap)
      .mode(NavigationMode.Stack)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width('100%').height('100%')

      if (this.showOfficialLogin) {
        OfficialLoginPage({
          onClose: () => this.finishOfficialLogin(),
          showDiagnostics: false
        })
          .zIndex(10)
      }
    }
    .id('root-tab-page')
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }
}
