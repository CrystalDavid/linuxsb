import { bundleManager } from '@kit.AbilityKit';
import { m1Runtime } from '../../app/M1Runtime';
import { SemanticColors } from '../../common/theme/DesignSystem';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { OfficialLoginPage } from '../../services/auth/OfficialLoginPage';
import { TopicOpenTrace } from '../../services/logging/TopicOpenTrace';
import { HomePage } from './HomePage';
import { P0ProbePage } from './P0ProbePage';
import { TopicDetailPage } from './TopicDetailPage';

const TOPIC_ROUTE: string = 'TopicDetail';
const DIAGNOSTICS_ROUTE: string = 'P0Diagnostics';

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
  @State private selectedTopic: TopicUiModel = new TopicUiModel();
  @State private showOfficialLogin: boolean = false;
  @State private loginReturnsToTopic: boolean = false;
  @State private authenticated: boolean = false;
  private debugPackage: boolean = isDebugPackage();

  aboutToAppear(): void {
    TopicOpenTrace.configure(this.debugPackage);
    this.authenticated = m1Runtime.hasMemorySession();
  }

  private openTopic(topic: TopicUiModel): void {
    TopicOpenTrace.begin(topic.topicId);
    this.selectedTopic = topic;
    this.pathStack.pushPathByName(TOPIC_ROUTE, null);
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

  private requestTopicLogin(): void {
    this.loginReturnsToTopic = true;
    this.showOfficialLogin = true;
  }

  private finishOfficialLogin(): void {
    this.showOfficialLogin = false;
    if (this.loginReturnsToTopic) {
      m1Runtime.topicViewModel.onOfficialLoginCompleted();
    } else {
      m1Runtime.captureOfficialLogin();
    }
    this.authenticated = m1Runtime.hasMemorySession();
  }

  @Builder
  private pathMap(routeName: string) {
    if (routeName === TOPIC_ROUTE) {
      NavDestination() {
        TopicDetailPage({
          viewModel: m1Runtime.topicViewModel,
          topicId: this.selectedTopic.topicId,
          summary: this.selectedTopic,
          onBack: () => this.pathStack.pop(),
          onLogin: () => this.requestTopicLogin()
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
