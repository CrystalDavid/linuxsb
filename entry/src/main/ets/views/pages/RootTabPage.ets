import { bundleManager } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import {
  BlurStrategy,
  HdsNavDestination,
  HdsNavigation,
  HdsTabs,
  HdsTabsController
} from '@kit.UIDesignKit';
import {
  buildTopicRouteParam,
  COMPOSE_ROUTE,
  DIAGNOSTICS_ROUTE,
  isTopicRouteParam,
  SEARCH_ROUTE,
  SETTINGS_ROUTE,
  TOPIC_ROUTE,
  TopicRouteParam
} from '../../app/AppRoutes';
import { m1Runtime } from '../../app/M1Runtime';
import { PageMetrics, SemanticColors, Typography } from '../../common/theme/DesignSystem';
import { SYS_BOTTOM_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { PortalAction } from '../../models/PortalModels';
import { arkWebForumBridge } from '../../services/auth/ArkWebForumBridge';
import { ArkWebTransportHost } from '../../services/auth/ArkWebTransportHost';
import { OfficialLoginPage } from '../../services/auth/OfficialLoginPage';
import { TopicOpenTrace } from '../../services/logging/TopicOpenTrace';
import { HomePage } from './HomePage';
import { ComposeTopicPage } from './ComposeTopicPage';
import { ForumsPage } from './ForumsPage';
import { P0ProbePage } from './P0ProbePage';
import { ProfilePage } from './ProfilePage';
import { SearchPage } from './SearchPage';
import { SettingsPage } from './SettingsPage';
import { TopicDetailPage } from './TopicDetailPage';
import { TitleCenterPage } from './TitleCenterPage';
import { CommunityTab, ImmersiveBottomTabBar } from '../components/ImmersiveBottomTabBar';
import { ImmersiveIconButton } from '../components/ImmersiveIconButton';

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
  @State private showCloudflareChallenge: boolean = false;
  @State private loginReturnsToTopic: boolean = false;
  @State private authenticated: boolean = false;
  @State private loginGeneration: number = 0;
  @State private loginReturnTopicId: number = 0;
  @State private ignoreTopicTapUntil: number = 0;
  @State private selectedTab: CommunityTab = CommunityTab.Home;
  @State private dockBarOffsetX: number = 0;
  @State private homeIconActionGeneration: number = 0;
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;
  private tabsController: HdsTabsController = new HdsTabsController();
  private debugPackage: boolean = isDebugPackage();
  private unsubscribeChallengeRequired: (() => void) | undefined = undefined;
  private unsubscribeChallengeRecovered: (() => void) | undefined = undefined;

  aboutToAppear(): void {
    TopicOpenTrace.configure(this.debugPackage);
    m1Runtime.onSessionStateChanged = (authenticated: boolean) => {
      this.authenticated = authenticated;
    };
    this.authenticated = m1Runtime.restorePersistedSession();
    if (this.authenticated) {
      m1Runtime.verifyActiveSession(true);
    }
    this.unsubscribeChallengeRequired = arkWebForumBridge.subscribeChallengeRequired(() => {
      if (!this.showOfficialLogin) {
        this.showCloudflareChallenge = true;
      }
    });
    this.unsubscribeChallengeRecovered = arkWebForumBridge.subscribeRecovered(() => {
      this.handleCloudflareRecovered();
    });
  }

  aboutToDisappear(): void {
    if (this.unsubscribeChallengeRequired !== undefined) {
      this.unsubscribeChallengeRequired();
      this.unsubscribeChallengeRequired = undefined;
    }
    if (this.unsubscribeChallengeRecovered !== undefined) {
      this.unsubscribeChallengeRecovered();
      this.unsubscribeChallengeRecovered = undefined;
    }
  }

  private handleCloudflareRecovered(): void {
    this.showCloudflareChallenge = false;
    m1Runtime.homeViewModel.load(true);
    const currentRoute = this.currentTopicRoute();
    if (currentRoute !== undefined) {
      m1Runtime.topicViewModel.load(currentRoute.topicId);
    }
  }

  private openTopic(topic: TopicUiModel, focusReplyId: number = 0): void {
    if (Date.now() < this.ignoreTopicTapUntil) {
      return;
    }
    TopicOpenTrace.begin(topic.topicId);
    this.pathStack.pushPath(new NavPathInfo(TOPIC_ROUTE,
      buildTopicRouteParam(topic.topicId, topic, focusReplyId)));
    TopicOpenTrace.markRoutePush();
  }

  private openTopicLocation(topicId: number, replyId: number, title: string): void {
    if (topicId <= 0) {
      return;
    }
    const topic = new TopicUiModel();
    topic.topicId = topicId;
    topic.title = title.length > 0 ? title : `Topic ${topicId}`;
    this.openTopic(topic, replyId);
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

  private openSettings(): void {
    this.pathStack.pushPathByName(SETTINGS_ROUTE, null);
  }

  private openSearch(): void {
    this.pathStack.pushPathByName(SEARCH_ROUTE, null);
  }

  private dockOffsetFor(tab: CommunityTab): number {
    return tab === CommunityTab.Forums || tab === CommunityTab.Titles ?
      PageMetrics.BOTTOM_DOCK_CENTER_OFFSET : 0;
  }

  private animateDockForTab(tab: CommunityTab): void {
    this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 360, 34) }, () => {
      this.dockBarOffsetX = this.dockOffsetFor(tab);
    });
  }

  private syncSelectedTab(tab: CommunityTab): void {
    if (tab === this.selectedTab) {
      return;
    }
    this.selectedTab = tab;
    this.animateDockForTab(tab);
    if (tab === CommunityTab.Profile && m1Runtime.hasMemorySession()) {
      m1Runtime.verifyActiveSession();
    }
  }

  private switchTab(tab: CommunityTab): void {
    if (tab === this.selectedTab) {
      return;
    }
    this.syncSelectedTab(tab);
    this.tabsController.changeIndex(tab as number);
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
      this.loginGeneration++;
      m1Runtime.homeViewModel.load(true);
    }
  }

  @Builder
  private diagnosticsTitleBar() {
    Row() {
      Text('P0 开发诊断')
        .fontSize(Typography.PAGE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private pathMap(routeName: string, param: Object | undefined) {
    if (routeName === TOPIC_ROUTE && isTopicRouteParam(param)) {
      HdsNavDestination() {
        TopicDetailPage({
          viewModel: m1Runtime.topicViewModel,
          topicId: (param as TopicRouteParam).topicId,
          summary: (param as TopicRouteParam).summary,
          focusReplyId: (param as TopicRouteParam).focusReplyId ?? 0,
          authenticated: this.authenticated,
          onBack: () => this.pathStack.pop(),
          onLogin: () => this.requestTopicLogin(param as TopicRouteParam),
          onReply: (body: string) => m1Runtime.reply((param as TopicRouteParam).topicId, body),
          onUploadImage: (uri: string) => m1Runtime.uploadImage(uri),
          onReportReply: (replyId: number, reasonType: string, details: string) =>
            m1Runtime.reportReply(replyId, reasonType, details)
        })
      }
      .hideTitleBar(true)
      .backgroundColor(SemanticColors.page())
    } else if (routeName === DIAGNOSTICS_ROUTE && this.debugPackage) {
      HdsNavDestination() {
        P0ProbePage({
          onOpenFormalTopic: (topicId: number) => this.openDebugTopic(topicId)
        })
      }
      .titleBar({ content: { stackBuilder: () => this.diagnosticsTitleBar() } })
      .backgroundColor(SemanticColors.page())
    } else if (routeName === COMPOSE_ROUTE) {
      HdsNavDestination() {
        ComposeTopicPage({
          catalogViewModel: m1Runtime.homeViewModel,
          authenticated: this.authenticated,
          onBack: () => this.pathStack.pop(),
          onLogin: () => this.requestHomeLogin(),
          onSubmit: (forumId: number, title: string, body: string) =>
            m1Runtime.createTopic(forumId, title, body),
          onUploadImage: (uri: string) => m1Runtime.uploadImage(uri),
          onCreated: (topicId: number) => this.openCreatedTopic(topicId)
        })
      }
      .hideTitleBar(true)
      .backgroundColor(SemanticColors.page())
    } else if (routeName === SETTINGS_ROUTE) {
      HdsNavDestination() {
        SettingsPage({
          onBack: () => this.pathStack.pop(),
          onFeedback: () => this.openTopicLocation(17803, 0, '烧饼社区鸿蒙客户端反馈')
        })
      }
      .hideTitleBar(true)
      .backgroundColor(SemanticColors.page())
    } else if (routeName === SEARCH_ROUTE) {
      HdsNavDestination() {
        SearchPage({
          viewModel: m1Runtime.searchViewModel,
          authenticated: this.authenticated,
          bottomContentInset: 0,
          onBack: () => this.pathStack.pop(),
          onLogin: () => this.requestHomeLogin(),
          onTopicSelected: (topic: TopicUiModel) => this.openTopic(topic)
        })
      }
      .hideTitleBar(true)
      .backgroundColor(SemanticColors.page())
    }
  }

  @Builder
  private hiddenTabBar() {
    Row().width(1).height(1).opacity(0)
  }

  @Builder
  private immersiveMiniBar() {
    ImmersiveBottomTabBar({
      selectedTab: this.selectedTab,
      onSelect: (tab: CommunityTab) => this.switchTab(tab),
      onHomeDoubleTap: () => { this.homeIconActionGeneration++; }
    })
  }

  @Builder
  private rootTabContent() {
    Stack({ alignContent: Alignment.Bottom }) {
      HdsTabs({ controller: this.tabsController, index: this.selectedTab as number }) {
        TabContent() {
          HomePage({
            viewModel: m1Runtime.homeViewModel,
            debugAvailable: this.debugPackage,
            onTopicSelected: (topic: TopicUiModel) => this.openTopic(topic),
            onOpenDiagnostics: () => this.openDiagnostics(),
            onPrefetch: (topicIds: number[]) => m1Runtime.prefetchTopics(topicIds),
            onCancelPrefetch: () => m1Runtime.cancelPrefetch(),
            onSearch: () => this.openSearch(),
            homeIconActionGeneration: this.homeIconActionGeneration
          })
        }
        .tabBar(this.hiddenTabBar())

        TabContent() {
          ForumsPage({
            viewModel: m1Runtime.forumViewModel,
            onTopicSelected: (topic: TopicUiModel) => this.openTopic(topic)
          })
        }
        .tabBar(this.hiddenTabBar())

        TabContent() {
          TitleCenterPage({
            authenticated: this.authenticated,
            onLogin: () => this.requestHomeLogin(),
            onLoad: (path: string) => m1Runtime.loadPortal(path),
            onSubmit: (action: PortalAction, overrides?: Record<string, string | number | boolean | string[]>) =>
              m1Runtime.submitPortalAction(action, overrides ?? {})
          })
        }
        .tabBar(this.hiddenTabBar())

        TabContent() {
          ProfilePage({
            sessionViewModel: m1Runtime.homeViewModel,
            profileViewModel: m1Runtime.profileViewModel,
            authenticated: this.authenticated,
            loginGeneration: this.loginGeneration,
            onLogin: () => this.requestHomeLogin(),
            onTopicSelected: (topic: TopicUiModel) => this.openTopic(topic),
            onOpenTopicLocation: (topicId: number, replyId: number, title: string) =>
              this.openTopicLocation(topicId, replyId, title),
            onLoadPortal: (path: string) => m1Runtime.loadPortal(path),
            onSubmitPortal: (action: PortalAction) => m1Runtime.submitPortalAction(action),
            onUploadImage: (uri: string) => m1Runtime.uploadImage(uri),
            onUploadAvatar: (uri: string) => m1Runtime.uploadAvatar(uri)
          })
        }
        .tabBar(this.hiddenTabBar())
      }
      .id('hds-community-tabs')
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .vertical(false)
      .scrollable(false)
      // HdsTabs remains the native page container, but its own visual bar is
      // deliberately collapsed. The visible tray below is the only glass layer
      // (the locked CheckBottomTabVisualLock recipe); rendering both the HDS
      // floating material and the self-drawn glass would double-sample and
      // muddy the smoked immersive light.
      .barWidth(1)
      .barHeight(1)
      .barBackgroundColor(Color.Transparent)
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .blurStrategy(BlurStrategy.DISABLE)
      // HdsTabs content animation cannot be customized. Keep page replacement immediate and let the
      // single native glass indicator provide the continuous cross-tab motion.
      .animationDuration(0)
      .onSelected((index: number) => {
        if (index >= CommunityTab.Home && index <= CommunityTab.Profile) {
          this.syncSelectedTab(index as CommunityTab);
        }
      })
      .onChange((index: number) => {
        if (index >= CommunityTab.Home && index <= CommunityTab.Profile) {
          this.syncSelectedTab(index as CommunityTab);
        }
      })
      .width('100%')
      .height('100%')
      .backgroundColor(SemanticColors.page())

      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          this.immersiveMiniBar()
        }
        .width(PageMetrics.BOTTOM_TAB_BAR_WIDTH)
        .height(PageMetrics.BOTTOM_TAB_BAR_HEIGHT)
        .position({ x: 0, y: 0 })
        .translate({ x: this.dockBarOffsetX })

        if (this.selectedTab === CommunityTab.Home) {
          Row() {
            ImmersiveIconButton({
              icon: $r('sys.symbol.plus'),
              semanticId: 'home-write-fab',
              semanticLabel: '发表新主题',
              buttonSize: PageMetrics.BOTTOM_DOCK_ACTION_SIZE,
              iconSize: 27,
              iconWeight: 900,
              iconColor: SemanticColors.textPrimary(),
              onAction: () => this.openComposer()
            })
          }
          .width(PageMetrics.BOTTOM_DOCK_ACTION_SIZE)
          .height(PageMetrics.BOTTOM_DOCK_ACTION_SIZE)
          .position({ x: PageMetrics.BOTTOM_TAB_BAR_WIDTH + PageMetrics.BOTTOM_DOCK_GAP, y: 0 })
        } else if (this.selectedTab === CommunityTab.Profile) {
          Row() {
            ImmersiveIconButton({
              icon: $r('sys.symbol.gearshape_fill'),
              semanticId: 'profile-settings-dock',
              semanticLabel: '设置',
              buttonSize: PageMetrics.BOTTOM_DOCK_ACTION_SIZE,
              iconSize: 27,
              iconWeight: 500,
              iconColor: SemanticColors.textPrimary(),
              onAction: () => this.openSettings()
            })
          }
          .width(PageMetrics.BOTTOM_DOCK_ACTION_SIZE)
          .height(PageMetrics.BOTTOM_DOCK_ACTION_SIZE)
          .position({ x: PageMetrics.BOTTOM_TAB_BAR_WIDTH + PageMetrics.BOTTOM_DOCK_GAP, y: 0 })
        }
      }
        .width(PageMetrics.BOTTOM_DOCK_WIDTH)
        .height(PageMetrics.BOTTOM_TAB_BAR_HEIGHT)
        .margin({ bottom: PageMetrics.BOTTOM_TAB_BAR_BOTTOM_MARGIN + this.bottomInset })
        .zIndex(2)
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }

  build() {
    Stack() {
      ArkWebTransportHost()

      HdsNavigation(this.pathStack) {
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

      if (this.showCloudflareChallenge && !this.showOfficialLogin) {
        OfficialLoginPage({
          challengeMode: true,
          onClose: () => {
            arkWebForumBridge.dismissChallenge();
            this.showCloudflareChallenge = false;
          },
          onChallengeResolved: () => arkWebForumBridge.confirmChallengeResolved(),
          showDiagnostics: false
        })
          .zIndex(11)
      }
    }
    .id('root-tab-page')
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }
}
