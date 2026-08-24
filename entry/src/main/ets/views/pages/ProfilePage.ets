import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
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
import { PaginatedTopicList } from '../components/PaginatedTopicList';
import { UserAvatar } from '../components/UserAvatar';

enum ProfileTab {
  Topics = 0,
  Replies = 1
}

@Component
export struct ProfilePage {
  @ObjectLink sessionViewModel: HomeViewModel;
  @ObjectLink profileViewModel: HomeViewModel;
  @Prop @Watch('onAuthenticatedChanged') authenticated: boolean = false;
  bottomContentInset: number = PageMetrics.BOTTOM_TAB_BAR_CONTENT_INSET;
  onLogin: () => void = () => {};
  onTopicSelected: (topic: TopicUiModel) => void = () => {};
  @State private selectedTab: ProfileTab = ProfileTab.Topics;
  @State private resolvingProfile: boolean = false;
  @State private profileError: string = '';
  @State private user: CurrentUserSummary | undefined = undefined;

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

  @Builder
  private titleBar() {
    Row() {
      Text('我的')
        .fontSize(Typography.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
    }
    .width('100%').height('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private loginGate() {
    Column({ space: Spacing.MD }) {
      SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
        .fontSize(54)
        .fontColor([$r('app.color.brand_primary')])
      Text('登录后查看个人主页')
        .fontSize(Typography.TITLE_SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.textPrimary())
      Text('登录在 linux.sb 官方页面完成，App 不保存账号密码。')
        .fontSize(Typography.BODY)
        .fontColor(SemanticColors.textSecondary())
        .textAlign(TextAlign.Center)
      Button('打开官方登录页', { type: ButtonType.Capsule, stateEffect: true })
        .id('profile-login-action')
        .height(44)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.brand_primary'))
        .onClick(() => this.onLogin())
    }
    .id('profile-login-required')
    .width('100%')
    .padding(Spacing.XL)
    .backgroundColor(SemanticColors.surface())
    .borderRadius(Radius.LG)
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
          this.profileTabButton('主题', ProfileTab.Topics)
          this.profileTabButton('回帖', ProfileTab.Replies)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.LG, bottom: Spacing.SM })
      .backgroundColor(SemanticColors.surface())
    }
  }

  @Builder
  private profileTabButton(label: string, tab: ProfileTab) {
    Button(label, { type: ButtonType.Normal, stateEffect: true })
      .layoutWeight(1)
      .height(40)
      .fontSize(Typography.BODY)
      .fontWeight(this.selectedTab === tab ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selectedTab === tab ? $r('app.color.brand_primary') : SemanticColors.textSecondary())
      .backgroundColor(this.selectedTab === tab ? $r('app.color.brand_soft') : Color.Transparent)
      .borderRadius(Radius.PILL)
      .onClick(() => this.changeTab(tab))
  }

  build() {
    HdsNavigation() {
      Column() {
        if (!this.authenticated) {
          Column() {
            this.loginGate()
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
  }
}
