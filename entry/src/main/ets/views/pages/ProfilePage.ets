import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { CurrentUserSummary, HomeFeedRequest } from '../../models/HomeModels';
import { TopicUiModel, UserUiModel } from '../../models/presentation/ForumUiModels';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { ViewLoadState } from '../../viewmodels/ViewState';
import { AccountLoginGate } from '../components/AccountLoginGate';
import { CompactSegmentedControl, SegmentOption } from '../components/CompactSegmentedControl';
import { HomeFab } from '../components/HomeFab';
import { PaginatedTopicList } from '../components/PaginatedTopicList';
import { UserAvatar } from '../components/UserAvatar';

enum ProfileTab {
  Topics = 0,
  Replies = 1
}

@Component({ freezeWhenInactive: true })
export struct ProfilePage {
  @ObjectLink sessionViewModel: HomeViewModel;
  @ObjectLink profileViewModel: HomeViewModel;
  @Prop @Watch('onAuthenticatedChanged') authenticated: boolean = false;
  bottomContentInset: number = PageMetrics.BOTTOM_TAB_BAR_CONTENT_INSET;
  onLogin: () => void = () => {};
  onOpenSettings: () => void = () => {};
  onTopicSelected: (topic: TopicUiModel) => void = () => {};
  @State private selectedTab: ProfileTab = ProfileTab.Topics;
  @State private resolvingProfile: boolean = false;
  @State private profileError: string = '';
  @State private user: CurrentUserSummary | undefined = undefined;
  @State private contentWidth: number = 0;
  @State private contentHeight: number = 0;

  aboutToAppear(): void {
    this.resolveProfile();
  }

  private onAuthenticatedChanged(): void {
    if (this.authenticated) {
      this.resolveProfile(true);
    } else {
      this.user = undefined;
      this.profileError = '';
    }
  }

  private async resolveProfile(forceRefresh: boolean = false): Promise<void> {
    if (!this.authenticated || this.resolvingProfile) {
      return;
    }
    this.resolvingProfile = true;
    this.profileError = '';
    if (forceRefresh || this.sessionViewModel.currentUser === undefined) {
      await this.sessionViewModel.load(true);
    }
    this.user = this.sessionViewModel.currentUser;
    if (this.user === undefined || this.user.userId <= 0) {
      this.profileError = '暂时无法识别当前登录用户';
      this.resolvingProfile = false;
      return;
    }
    this.profileViewModel.configure(HomeFeedRequest.user(this.user.userId, this.selectedTab === ProfileTab.Replies));
    if (this.profileViewModel.state === ViewLoadState.Idle || forceRefresh) {
      await this.profileViewModel.load(forceRefresh);
    }
    this.resolvingProfile = false;
  }

  private async changeTab(tab: ProfileTab): Promise<void> {
    if (this.selectedTab === tab || this.user === undefined) {
      return;
    }
    this.selectedTab = tab;
    this.profileViewModel.configure(HomeFeedRequest.user(this.user.userId, tab === ProfileTab.Replies));
    await this.profileViewModel.load(false);
  }

  private userUiModel(): UserUiModel {
    const output = new UserUiModel();
    const source = this.user;
    if (source !== undefined) {
      output.userId = source.userId;
      output.displayName = source.name;
      output.avatarUrl = source.avatarUrl;
      output.initial = source.name.length > 0 ? source.name.substring(0, 1).toUpperCase() : '我';
    }
    return output;
  }

  private profileOptions(): SegmentOption[] {
    return [
      new SegmentOption('主题', 'profile-tab-topics'),
      new SegmentOption('回帖', 'profile-tab-replies')
    ];
  }

  @Builder
  private titleBar() {
    Row() {
      Text('我的')
        .id('profile-page-title')
        .fontSize(Typography.PAGE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
    }
    .width('100%').height('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private profileHeader() {
    if (this.user !== undefined) {
      Column({ space: Spacing.MD }) {
        Row({ space: Spacing.MD }) {
          UserAvatar({ user: this.userUiModel(), avatarSize: 64, semanticId: 'profile-avatar' })
          Column({ space: Spacing.XS }) {
            Text(this.user?.name ?? '')
              .fontSize(Typography.TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(SemanticColors.textPrimary())
              .maxLines(1)
            Text(`${this.user?.groupName ?? '用户'} · 积分 ${this.user?.points ?? 0}`)
              .fontSize(Typography.LABEL)
              .fontColor(SemanticColors.textSecondary())
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        if ((this.user?.bio ?? '').length > 0) {
          Text(this.user?.bio ?? '')
            .fontSize(Typography.BODY)
            .lineHeight(Typography.BODY_LINE_HEIGHT)
            .fontColor(SemanticColors.textSecondary())
            .width('100%')
        }

        Row() {
          CompactSegmentedControl({
            options: this.profileOptions(),
            selectedIndex: this.selectedTab === ProfileTab.Topics ? 0 : 1,
            onSelect: (index: number) => this.changeTab(index === 0 ? ProfileTab.Topics : ProfileTab.Replies)
          })
          Blank()
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.LG, bottom: Spacing.SM })
      .backgroundColor(Color.Transparent)
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      HdsNavigation() {
        Column() {
          if (!this.authenticated) {
            Column() {
              AccountLoginGate({
                title: '登录后查看个人主页',
                semanticPrefix: 'profile',
                onLogin: () => this.onLogin()
              })
              Blank()
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XXL,
              bottom: this.bottomContentInset })
          } else if (this.resolvingProfile && this.user === undefined) {
            Column({ space: Spacing.SM }) {
              LoadingProgress().width(30).height(30).color($r('app.color.brand_primary'))
              Text('正在读取个人主页')
                .fontSize(Typography.BODY)
                .fontColor(SemanticColors.textSecondary())
            }
            .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
            .padding({ bottom: this.bottomContentInset })
          } else if (this.profileError.length > 0) {
            Column({ space: Spacing.MD }) {
              Text(this.profileError).fontSize(Typography.BODY).fontColor(SemanticColors.textSecondary())
              Button('重试', { type: ButtonType.Capsule }).onClick(() => this.resolveProfile(true))
            }
            .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
            .padding({ bottom: this.bottomContentInset })
          } else {
            this.profileHeader()
            PaginatedTopicList({
              viewModel: this.profileViewModel,
              bottomInset: this.bottomContentInset,
              semanticPrefix: 'profile',
              emptyTitle: this.selectedTab === ProfileTab.Replies ? '还没有回帖' : '还没有主题',
              onTopicSelected: (topic: TopicUiModel) => this.onTopicSelected(topic),
              onRetry: () => this.resolveProfile(true)
            })
              .layoutWeight(1)
          }
        }
        .id('profile-page')
        .width('100%').height('100%')
        .backgroundColor(SemanticColors.page())
      }
      .titleBar({
        avoidLayoutSafeArea: requiresHdsLayoutSafeAreaAvoidance(ImmersiveLightArea.TITLE_BAR),
        enableComponentSafeArea: requiresHdsComponentSafeArea(ImmersiveLightArea.TITLE_BAR),
        style: buildImmersiveTitleBarStyle(),
        content: { stackBuilder: () => { this.titleBar(); } }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .mode(NavigationMode.Stack)
      .hideBackButton(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width('100%').height('100%')

      HomeFab({
        icon: $r('sys.symbol.gearshape_fill'),
        semanticId: 'profile-settings-fab',
        semanticLabel: '设置',
        onAction: () => this.onOpenSettings(),
        maxDragX: Math.max(0, this.contentWidth - PageMetrics.FAB_SIZE - Spacing.XXXL),
        maxDragY: Math.max(0, this.contentHeight - PageMetrics.TOP_BAR_HEIGHT - this.bottomContentInset -
          PageMetrics.FAB_SIZE - Spacing.XXXL)
      })
        .margin({ right: Spacing.LG, bottom: this.bottomContentInset + Spacing.XXXL + Spacing.SM })
        .zIndex(4)
    }
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.contentWidth = Number(newArea.width);
      this.contentHeight = Number(newArea.height);
    })
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }
}
