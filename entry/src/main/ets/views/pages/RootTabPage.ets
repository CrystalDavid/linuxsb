import { bundleManager } from '@kit.AbilityKit';
import {
  buildTopicRouteParam,
  COMPOSE_ROUTE,
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
import { ComposeTopicPage } from './ComposeTopicPage';
import { ForumsPage } from './ForumsPage';
import { P0ProbePage } from './P0ProbePage';
import { ProfilePage } from './ProfilePage';
import { SearchPage } from './SearchPage';
import { TopicDetailPage } from './TopicDetailPage';
import { CommunityTab, ImmersiveBottomTabBar } from '../components/ImmersiveBottomTabBar';

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
  @State private selectedTab: CommunityTab = CommunityTab.Home;
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

  private openComposer(): void {
    this.pathStack.pushPathByName(COMPOSE_ROUTE, null);
  }

  private openCreatedTopic(topicId: number): void {
    if (topicId <= 0) {
      return;
    }
    this.pathStack.pop();
    const topic = new TopicUiModel();
    topic.topicId = topicId;
    topic.title = '刚刚发表的主题';
    this.openTopic(topic);
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
    this.loginReturnsToTopic = false;
    this.loginReturnTopicId = 0;
    // Let ArkUI remove the temporary ArkWeb before synchronously reading its cookie store.
    // This keeps the close interaction responsive even when the Web process is busy.
    setTimeout(() => {
      this.completeOfficialLogin(returnsToTopic, returnTopicId, currentRoute);
    }, 0);
  }

  private completeOfficialLogin(returnsToTopic: boolean, returnTopicId: number,
    currentRoute: TopicRouteParam | undefined): void {
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
    if (this.authenticated) {
      m1Runtime.homeViewModel.load(true);
    }
  }

  @Builder
  private pathMap(routeName: string, param: Object | undefined) {
    if (routeName === TOPIC_ROUTE && isTopicRouteParam(param)) {
      NavDestination() {
        TopicDetailPage({
          viewModel: m1Runtime.topicViewModel,
          topicId: (param as TopicRouteParam).topicId,
          summary: (param as TopicRouteParam).summary,
          authenticated: this.authenticated,
          onBack: () => this.pathStack.pop(),
          onLogin: () => this.requestTopicLogin(param as TopicRouteParam),
          onReply: (body: string) => m1Runtime.reply((param as TopicRouteParam).topicId, body)
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
    } else if (routeName === COMPOSE_ROUTE) {
      NavDestination() {
        ComposeTopicPage({
          catalogViewModel: m1Runtime.homeViewModel,
          authenticated: this.authenticated,
          onBack: () => this.pathStack.pop(),
          onLogin: () => this.requestHomeLogin(),
          onSubmit: (forumId: number, title: string, body: string) =>
            m1Runtime.createTopic(forumId, title, body),
          onCreated: (topicId: number) => this.openCreatedTopic(topicId)
        })
      }
      .hideTitleBar(true)
      .backgroundColor(SemanticColors.page())
    }
  }

  @Builder
  private rootTabContent() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.selectedTab === CommunityTab.Home) {
        HomePage({
          viewModel: m1Runtime.homeViewModel,
          debugAvailable: this.debugPackage,
          onTopicSelected: (topic: TopicUiModel) => this.openTopic(topic),
          onOpenDiagnostics: () => this.openDiagnostics(),
          onPrefetch: (topicIds: number[]) => m1Runtime.prefetchTopics(topicIds),
          onCancelPrefetch: () => m1Runtime.cancelPrefetch()
        })
      } else if (this.selectedTab === CommunityTab.Forums) {
        ForumsPage({
          viewModel: m1Runtime.forumViewModel,
          onTopicSelected: (topic: TopicUiModel) => this.openTopic(topic)
        })
      } else if (this.selectedTab === CommunityTab.Search) {
        SearchPage({
          viewModel: m1Runtime.searchViewModel,
          authenticated: this.authenticated,
          onLogin: () => this.requestHomeLogin(),
          onTopicSelected: (topic: TopicUiModel) => this.openTopic(topic)
        })
      } else {
        ProfilePage({
          sessionViewModel: m1Runtime.homeViewModel,
          profileViewModel: m1Runtime.profileViewModel,
          authenticated: this.authenticated,
          onLogin: () => this.requestHomeLogin(),
          onTopicSelected: (topic: TopicUiModel) => this.openTopic(topic)
        })
      }

      ImmersiveBottomTabBar({
        selectedTab: this.selectedTab,
        onSelect: (tab: CommunityTab) => { this.selectedTab = tab; },
        onCompose: () => this.openComposer()
      })
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }

  build() {
    Stack() {
      Navigation(this.pathStack) {
        this.rootTabContent()
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
