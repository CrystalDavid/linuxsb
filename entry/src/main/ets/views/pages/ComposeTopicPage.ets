import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect
} from '../../common/ui/ImmersiveActionBarStyle';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { ForumSummary } from '../../models/HomeModels';
import { WriteResult } from '../../services/repository/WriteRepository';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { ImmersiveGlassTextButton } from '../components/ImmersiveGlassTextButton';
import {
  ImmersiveIconButton,
  TITLE_BAR_BACK_BUTTON_SIZE,
  TITLE_BAR_BACK_ICON_SIZE,
  TITLE_BAR_BACK_ICON_WEIGHT
} from '../components/ImmersiveIconButton';

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

  private forumGridHeight(): number {
    const rowCount = Math.ceil(this.catalogViewModel.forums.length / 2);
    return rowCount > 0 ? rowCount * 42 + (rowCount - 1) * Spacing.SM : 0;
  }

  @Builder
  private titleBar() {
    Row({ space: Spacing.SM }) {
      ImmersiveIconButton({
        icon: $r('sys.symbol.chevron_left'),
        semanticId: 'compose-back',
        semanticLabel: '返回',
        buttonSize: TITLE_BAR_BACK_BUTTON_SIZE,
        iconSize: TITLE_BAR_BACK_ICON_SIZE,
        iconWeight: TITLE_BAR_BACK_ICON_WEIGHT,
        onAction: () => this.onBack()
      })
      Text('发表主题')
        .fontSize(Typography.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .layoutWeight(1)
      if (this.authenticated) {
        ImmersiveGlassTextButton({
          label: this.submitting ? '发布中…' : '发布',
          semanticId: 'compose-submit',
          actionEnabled: !this.submitting,
          controlHeight: 40,
          horizontalPadding: Spacing.LG,
          labelFontSize: Typography.BODY,
          onAction: () => this.requestSubmit()
        })
      }
    }
    .width('100%').height('100%')
    .padding({ left: 10, right: 16 })
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
      if (this.catalogViewModel.forums.length > 0) {
        Grid() {
          ForEach(this.catalogViewModel.forums, (forum: ForumSummary) => {
            GridItem() {
              Button(forum.name, { type: ButtonType.Capsule, stateEffect: false })
                .id(`compose-forum-${forum.forumId}`)
                .width('100%')
                .height(42)
                .padding({ left: Spacing.SM, right: Spacing.SM })
                .fontSize(Typography.LABEL)
                .fontWeight(this.forumId === forum.forumId ? FontWeight.Medium : FontWeight.Regular)
                .fontColor(this.forumId === forum.forumId ? $r('app.color.brand_primary') :
                  SemanticColors.textSecondary())
                .backgroundColor(this.forumId === forum.forumId ? $r('app.color.liquid_segment_selected') :
                  Color.Transparent)
                .border({ width: 1, color: $r('app.color.liquid_glass_highlight') })
                .borderRadius(Radius.PILL)
                .hoverEffect(HoverEffect.None)
                .onClick(() => { this.forumId = forum.forumId; })
            }
          }, (forum: ForumSummary) => forum.forumId.toString())
        }
        .id('compose-forum-grid')
        .columnsTemplate('1fr 1fr')
        .columnsGap(Spacing.SM)
        .rowsGap(Spacing.SM)
        .width('100%')
        .height(this.forumGridHeight())
        .scrollBar(BarState.Off)
      } else {
        Text('暂无可选板块')
          .fontSize(Typography.LABEL)
          .fontColor(SemanticColors.textTertiary())
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private loginGate() {
    Row({ space: Spacing.SM }) {
      SymbolGlyph($r('sys.symbol.person_badge_lock_fill'))
        .fontSize(22)
        .fontColor([$r('app.color.brand_primary')])
      Text('登录后才能发表主题')
        .fontSize(Typography.BODY)
        .fontColor(SemanticColors.textSecondary())
        .layoutWeight(1)
      ImmersiveGlassTextButton({
        label: '登录',
        semanticId: 'compose-login-action',
        controlHeight: 40,
        horizontalPadding: Spacing.MD,
        labelFontSize: Typography.LABEL,
        onAction: () => this.onLogin()
      })
    }
    .id('compose-login-gate')
    .width('100%')
    .height(48)
    .padding({ left: Spacing.XS, right: Spacing.XS })
  }

  build() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Top }) {
        if (!this.authenticated) {
          Column() {
            this.loginGate()
          }
          .width('100%')
          .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.SM })
          .alignItems(HorizontalAlign.Start)
        } else {
          Scroll() {
            Column({ space: Spacing.LG }) {
              this.forumSelector()
              TextInput({ text: this.title, placeholder: '标题' })
                .id('compose-title')
                .width('100%').height(48)
                .fontSize(Typography.BODY_LARGE)
                .backgroundEffect(buildImmersiveGlassEffect())
                .border({ width: 1.1, color: $r('app.color.liquid_glass_highlight') })
                .borderRadius(Radius.MD)
                .shadow({ radius: 8, color: $r('app.color.hds_floating_action_glow'), offsetY: 2 })
                .onChange((value: string) => { this.title = value; })
              TextArea({ text: this.body, placeholder: '写下正文…' })
                .id('compose-body')
                .width('100%')
                .constraintSize({ minHeight: 260 })
                .fontSize(Typography.BODY)
                .lineHeight(Typography.READING_LINE_HEIGHT)
                .backgroundEffect(buildImmersiveGlassEffect())
                .border({ width: 1.1, color: $r('app.color.liquid_glass_highlight') })
                .borderRadius(Radius.MD)
                .shadow({ radius: 8, color: $r('app.color.hds_floating_action_glow'), offsetY: 2 })
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
          .width('100%').height('100%')
          .scrollBar(BarState.Off)
        }
      }
      .id('compose-topic-page')
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
