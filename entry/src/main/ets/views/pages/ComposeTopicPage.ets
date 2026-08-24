import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { ForumSummary } from '../../models/HomeModels';
import { WriteResult } from '../../services/repository/WriteRepository';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';

@Component
export struct ComposeTopicPage {
  @ObjectLink catalogViewModel: HomeViewModel;
  @Prop authenticated: boolean = false;
  onBack: () => void = () => {};
  onLogin: () => void = () => {};
  onSubmit: (forumId: number, title: string, body: string) => Promise<WriteResult> =
    async () => ({ ok: false, topicId: 0, message: '写入服务不可用', networkMs: 0 });
  onCreated: (topicId: number) => void = () => {};
  @State private forumId: number = 0;
  @State private title: string = '';
  @State private body: string = '';
  @State private submitting: boolean = false;
  @State private resultMessage: string = '';

  aboutToAppear(): void {
    if (this.forumId === 0 && this.catalogViewModel.forums.length > 0) {
      this.forumId = this.catalogViewModel.forums[0].forumId;
    }
  }

  private validate(): string {
    if (!this.authenticated) {
      return '请先登录';
    }
    if (this.forumId <= 0) {
      return '请选择板块';
    }
    if (this.title.trim().length === 0) {
      return '请输入标题';
    }
    if (this.body.trim().length === 0) {
      return '请输入正文';
    }
    return '';
  }

  private requestSubmit(): void {
    const message = this.validate();
    if (message.length > 0) {
      this.resultMessage = message;
      if (!this.authenticated) {
        this.onLogin();
      }
      return;
    }
    AlertDialog.show({
      title: '确认发表主题',
      message: '内容将真实发布到 linux.sb。请确认板块、标题和正文无误。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认发表',
        fontColor: $r('app.color.brand_primary'),
        action: () => { this.submit(); }
      }
    });
  }

  private async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    this.resultMessage = '';
    const result = await this.onSubmit(this.forumId, this.title, this.body);
    this.submitting = false;
    if (!result.ok) {
      this.resultMessage = result.message;
      return;
    }
    this.onCreated(result.topicId);
  }

  @Builder
  private titleBar() {
    Row({ space: Spacing.SM }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(23)
          .fontColor([SemanticColors.textPrimary()])
      }
      .id('compose-back')
      .width(42).height(42)
      .backgroundColor(Color.Transparent)
      .onClick(() => this.onBack())
      Text('发表主题')
        .fontSize(Typography.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .layoutWeight(1)
      Button('发布', { type: ButtonType.Capsule, stateEffect: true })
        .id('compose-submit')
        .height(38)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.brand_primary'))
        .opacity(this.submitting ? 0.6 : 1)
        .onClick(() => this.requestSubmit())
    }
    .width('100%').height('100%')
    .padding({ left: Spacing.SM, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private forumSelector() {
    Column({ space: Spacing.SM }) {
      Text('选择板块')
        .fontSize(Typography.LABEL)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.textSecondary())
        .width('100%')
      Scroll() {
        Row({ space: Spacing.SM }) {
          ForEach(this.catalogViewModel.forums, (forum: ForumSummary) => {
            Button(forum.name, { type: ButtonType.Capsule, stateEffect: true })
              .height(36)
              .padding({ left: Spacing.MD, right: Spacing.MD })
              .fontSize(Typography.LABEL)
              .fontColor(this.forumId === forum.forumId ? $r('app.color.brand_primary') :
                SemanticColors.textSecondary())
              .backgroundColor(this.forumId === forum.forumId ? $r('app.color.brand_soft') :
                SemanticColors.surfaceMuted())
              .onClick(() => { this.forumId = forum.forumId; })
          }, (forum: ForumSummary) => forum.forumId.toString())
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column({ space: Spacing.LG }) {
          if (!this.authenticated) {
            Row({ space: Spacing.SM }) {
              SymbolGlyph($r('sys.symbol.person_badge_lock_fill'))
                .fontSize(20)
                .fontColor([$r('app.color.brand_primary')])
              Text('登录后才能发表主题')
                .fontSize(Typography.BODY)
                .fontColor(SemanticColors.textSecondary())
                .layoutWeight(1)
              Button('登录', { type: ButtonType.Capsule }).onClick(() => this.onLogin())
            }
            .width('100%')
            .padding(Spacing.MD)
            .backgroundColor($r('app.color.brand_soft'))
            .borderRadius(Radius.MD)
          }
          this.forumSelector()
          TextInput({ text: this.title, placeholder: '标题' })
            .id('compose-title')
            .width('100%').height(48)
            .fontSize(Typography.BODY_LARGE)
            .backgroundColor(SemanticColors.surfaceMuted())
            .borderRadius(Radius.MD)
            .onChange((value: string) => { this.title = value; })
          TextArea({ text: this.body, placeholder: '写下正文…' })
            .id('compose-body')
            .width('100%')
            .constraintSize({ minHeight: 260 })
            .fontSize(Typography.BODY)
            .lineHeight(Typography.READING_LINE_HEIGHT)
            .backgroundColor(SemanticColors.surfaceMuted())
            .borderRadius(Radius.MD)
            .onChange((value: string) => { this.body = value; })
          if (this.resultMessage.length > 0) {
            Text(this.resultMessage)
              .fontSize(Typography.LABEL)
              .fontColor(SemanticColors.error())
              .width('100%')
          }
          Blank().height(32)
        }
        .width('100%')
        .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.LG })
        .alignItems(HorizontalAlign.Start)
      }
      .id('compose-topic-page')
      .width('100%').height('100%')
      .scrollBar(BarState.Off)
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
