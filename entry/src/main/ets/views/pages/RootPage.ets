import { bundleManager } from '@kit.AbilityKit';
import { m1Runtime } from '../../app/M1Runtime';
import { OfficialLoginPage } from '../../services/auth/OfficialLoginPage';
import { TopicOpenTrace } from '../../services/logging/TopicOpenTrace';
import { HomePage } from './HomePage';
import { P0ProbePage } from './P0ProbePage';
import { TopicDetailPage } from './TopicDetailPage';

const TOPIC_ROUTE = 'TopicDetail';
const DIAGNOSTICS_ROUTE = 'P0Diagnostics';

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
export struct RootPage {
  @Provide('appPathStack') private pathStack: NavPathStack = new NavPathStack();
  @State private selectedTopicId: number = 0;
  @State private showOfficialLogin: boolean = false;
  private debugPackage: boolean = isDebugPackage();

  aboutToAppear(): void {
    TopicOpenTrace.configure(this.debugPackage);
  }

  aboutToDisappear(): void {
    m1Runtime.close();
  }

  private openTopic(topicId: number): void {
    TopicOpenTrace.begin(topicId);
    this.selectedTopicId = topicId;
    this.pathStack.pushPathByName(TOPIC_ROUTE, null);
    TopicOpenTrace.markRoutePush();
  }

  private openDiagnostics(): void {
    if (this.debugPackage) {
      this.pathStack.pushPathByName(DIAGNOSTICS_ROUTE, null);
    }
  }

  private finishOfficialLogin(): void {
    this.showOfficialLogin = false;
    m1Runtime.topicViewModel.onOfficialLoginCompleted();
  }

  @Builder
  private pathMap(routeName: string) {
    if (routeName === TOPIC_ROUTE) {
      NavDestination() {
        TopicDetailPage({
          viewModel: m1Runtime.topicViewModel,
          topicId: this.selectedTopicId,
          onLogin: () => {
            this.showOfficialLogin = true;
          }
        })
      }
      .title('主题详情')
      .backgroundColor($r('app.color.page_background'))
    } else if (routeName === DIAGNOSTICS_ROUTE && this.debugPackage) {
      NavDestination() {
        P0ProbePage()
      }
      .title('P0 开发诊断')
      .backgroundColor($r('app.color.page_background'))
    }
  }

  build() {
    Stack() {
      Navigation(this.pathStack) {
        HomePage({
          viewModel: m1Runtime.homeViewModel,
          debugAvailable: this.debugPackage,
          onTopicSelected: (topicId: number) => this.openTopic(topicId),
          onOpenDiagnostics: () => this.openDiagnostics()
        })
      }
      .hideTitleBar(true)
      .navDestination(this.pathMap)
      .mode(NavigationMode.Stack)
      .width('100%')
      .height('100%')

      if (this.showOfficialLogin) {
        OfficialLoginPage({
          onClose: () => this.finishOfficialLogin(),
          showDiagnostics: false
        })
          .zIndex(10)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
