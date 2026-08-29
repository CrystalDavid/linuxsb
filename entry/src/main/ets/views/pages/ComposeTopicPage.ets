import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect,
  buildImmersiveSystemMaterialModifier,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';
import { GLASS_STYLE_STORAGE_KEY, GlassStyleMode } from '../../common/ui/GlassStyleParams';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { insertMarkdownAtCaret, PendingMarkdownInsert } from '../../common/utils/MarkdownInsert';
import { MAX_IMAGE_PICK_COUNT, pickImagesFromGallery } from '../../common/utils/PhotoPicker';
import { ForumSummary } from '../../models/HomeModels';
import { AttachmentUploadResult, WriteResult } from '../../services/repository/WriteRepository';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { AttachmentThumbnail } from '../components/AttachmentThumbnail';
import { ImmersiveGlassTextButton } from '../components/ImmersiveGlassTextButton';
import {
  GLASS_ACTION_ARROW_ICON_SIZE,
  GLASS_ACTION_ARROW_ICON_WEIGHT,
  ImmersiveIconButton,
  TITLE_BAR_BACK_ICON_SIZE,
  TITLE_BAR_BACK_ICON_WEIGHT
} from '../components/ImmersiveIconButton';

const COMPOSE_ATTACH_BUTTON_SIZE: number = 40;

@Component
export struct ComposeTopicPage {
  @ObjectLink catalogViewModel: HomeViewModel;
  @Prop authenticated: boolean = false;
  onBack: () => void = () => {};
  onLogin: () => void = () => {};
  onSubmit: (forumId: number, title: string, body: string) => Promise<WriteResult> =
    async () => ({ ok: false, topicId: 0, message: '写入服务不可用', networkMs: 0 });
  onUploadImage: (uri: string) => Promise<AttachmentUploadResult> =
    async () => ({ ok: false, markdown: '', message: '上传服务不可用', networkMs: 0 });
  onCreated: (topicId: number) => void = () => {};
  @State private forumId: number = 0;
  @State private title: string = '';
  @State private body: string = '';
  @State private attachments: string[] = [];
  private bodyController: TextAreaController = new TextAreaController();
  // 与 attachments 平行：选图那一刻正文光标的位置（-1 表示未取到，提交时
  // 退化为末尾追加，与旧行为一致）。
  private attachmentInsertOffsets: number[] = [];
  @State private submitting: boolean = false;
  @State private resultMessage: string = '';
  @StorageProp(GLASS_STYLE_STORAGE_KEY) private glassStyle: GlassStyleMode = GlassStyleMode.Translucent;

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

  private async pickImages(): Promise<void> {
    if (this.authenticated && this.attachments.length >= MAX_IMAGE_PICK_COUNT) {
      try {
        this.getUIContext().getPromptAction().showToast({
          message: `最多添加 ${MAX_IMAGE_PICK_COUNT} 张图片`,
          duration: 1600
        });
      } catch (_) {}
      return;
    }
    const picked = await pickImagesFromGallery(MAX_IMAGE_PICK_COUNT - this.attachments.length);
    if (picked.length === 0) {
      return;
    }
    // 快照“点添加图片那一刻”正文光标的位置：用户意图就是在这里插图。
    const caretOffset = this.currentBodyCaretOffset();
    for (let index = 0; index < picked.length; index++) {
      this.attachmentInsertOffsets.push(caretOffset);
    }
    this.attachments = this.attachments.concat(picked);
  }

  private removeAttachment(index: number): void {
    this.attachments = this.attachments.filter((_uri: string, itemIndex: number) => itemIndex !== index);
    this.attachmentInsertOffsets = this.attachmentInsertOffsets
      .filter((_offset: number, itemIndex: number) => itemIndex !== index);
  }

  private currentBodyCaretOffset(): number {
    try {
      const caret = this.bodyController.getCaretOffset();
      if (caret.index >= 0 && caret.index <= this.body.length) {
        return caret.index;
      }
    } catch (_) {
    }
    return -1;
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
    const imageHint = this.attachments.length > 0 ?
      `所选 ${this.attachments.length} 张图片将随正文一并上传。` : '';
    AlertDialog.show({
      title: '确认发表主题',
      message: `内容将真实发布到 linux.sb。请确认板块、标题和正文无误。${imageHint}`,
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
    // 并发上传：多张图同时发起，避免串行往返把发帖拖慢。
    const pending: Promise<AttachmentUploadResult>[] = [];
    for (let index = 0; index < this.attachments.length; index++) {
      pending.push(this.onUploadImage(this.attachments[index]));
    }
    const uploads: AttachmentUploadResult[] = await Promise.all(pending);
    const pendingInserts: PendingMarkdownInsert[] = [];
    for (let index = 0; index < uploads.length; index++) {
      const uploaded = uploads[index];
      if (!uploaded.ok) {
        this.submitting = false;
        this.resultMessage = uploaded.message;
        return;
      }
      const caretOffset = index < this.attachmentInsertOffsets.length ?
        this.attachmentInsertOffsets[index] : -1;
      pendingInserts.push({ caretOffset: caretOffset, markdown: uploaded.markdown, pickOrder: index });
    }
    // 图片按各自选图时的光标位置插入正文，而不是一律追加到末尾。
    const finalBody = insertMarkdownAtCaret(this.body, pendingInserts);
    const result = await this.onSubmit(this.forumId, this.title, finalBody);
    this.submitting = false;
    if (!result.ok) {
      this.resultMessage = result.message;
      return;
    }
    this.onCreated(result.topicId);
  }

  private forumGridHeight(): number {
    const rowCount = Math.ceil(this.catalogViewModel.forums.length / 3);
    return rowCount > 0 ? rowCount * 40 + (rowCount - 1) * Spacing.SM : 0;
  }

  @Builder
  private titleBar() {
    Row({ space: Spacing.SM }) {
      ImmersiveIconButton({
        icon: $r('sys.symbol.chevron_left'),
        semanticId: 'compose-back',
        semanticLabel: '返回',
        iconSize: TITLE_BAR_BACK_ICON_SIZE,
        iconWeight: TITLE_BAR_BACK_ICON_WEIGHT,
        onAction: () => this.onBack()
      })
      Text('发表主题')
        .id('compose-page-title')
        .fontSize(Typography.PAGE_TITLE)
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
              Button({ type: ButtonType.Capsule, stateEffect: false }) {
                Text(forum.name)
                  .id(`compose-forum-${forum.forumId}-label`)
                  .fontSize(Typography.LABEL)
                  .fontWeight(this.forumId === forum.forumId ? FontWeight.Medium : FontWeight.Regular)
                  .fontColor(this.forumId === forum.forumId ? $r('app.color.brand_primary') :
                    SemanticColors.textSecondary())
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .id(`compose-forum-${forum.forumId}`)
              .accessibilityText(forum.name)
              .width('100%')
              .height(40)
              .padding({ left: Spacing.XS, right: Spacing.XS })
              // Unselected chips reuse the bottom tab tray recipe: one shared
              // 16vp/1.05/1.0 frosted sample layer with the 1.25vp highlight edge.
              .backgroundColor(this.forumId === forum.forumId ?
                $r('app.color.compose_forum_selected_bg') : Color.Transparent)
              .backgroundEffect(this.forumId === forum.forumId ? undefined : buildImmersiveGlassEffect(this.glassStyle))
              .border({
                width: IMMERSIVE_GLASS_BORDER_WIDTH,
                color: this.forumId === forum.forumId ?
                  $r('app.color.brand_primary') : $r('app.color.bottom_tab_bar_highlight')
              })
              .borderRadius(Radius.PILL)
              .shadow({
                radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
                color: $r('app.color.bottom_tab_bar_shadow'),
                offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
              })
              .attributeModifier(buildImmersiveSystemMaterialModifier(
                this.glassStyle, this.forumId !== forum.forumId))
              .hoverEffect(HoverEffect.None)
              .onClick(() => { this.forumId = forum.forumId; })
            }
          }, (forum: ForumSummary) => forum.forumId.toString())
        }
        .id('compose-forum-grid')
        .columnsTemplate('1fr 1fr 1fr')
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

  @Builder
  private attachmentPicker() {
    Column({ space: Spacing.XS }) {
      Row({ space: Spacing.XS }) {
        ImmersiveIconButton({
          icon: $r('sys.symbol.plus'),
          semanticId: 'compose-attach',
          semanticLabel: '添加图片',
          buttonSize: COMPOSE_ATTACH_BUTTON_SIZE,
          iconSize: GLASS_ACTION_ARROW_ICON_SIZE,
          iconWeight: GLASS_ACTION_ARROW_ICON_WEIGHT,
          iconColor: $r('app.color.brand_primary'),
          onAction: () => this.pickImages()
        })
        Text('添加图片')
          .fontSize(Typography.CAPTION)
          .fontColor(SemanticColors.textSecondary())
        Blank()
      }
      .id('compose-attach-row')
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.attachments.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.attachments, (uri: string, index: number) => {
            AttachmentThumbnail({
              uri: uri,
              semanticId: `compose-attachment-${index}`,
              onRemove: () => this.removeAttachment(index)
            })
              .margin({ right: Spacing.SM, bottom: Spacing.SM })
          }, (uri: string, index: number) => `${uri}-${index}`)
        }
        .id('compose-attachment-strip')
        .width('100%')
      }
    }
    .width('100%')
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
              TextInput({ text: this.title, placeholder: '标题' })
                .id('compose-title')
                .width('100%').height(48)
                .fontSize(Typography.BODY_LARGE)
                .fontColor(SemanticColors.textPrimary())
                .placeholderColor(SemanticColors.textSecondary())
                .caretColor($r('app.color.brand_primary'))
                .backgroundEffect(buildImmersiveGlassEffect(this.glassStyle))
                .border({ width: IMMERSIVE_GLASS_BORDER_WIDTH,
                  color: $r('app.color.bottom_tab_bar_highlight') })
                .borderRadius(Radius.MD)
                .shadow({
                  radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
                  color: $r('app.color.bottom_tab_bar_shadow'),
                  offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
                })
                .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
                .onChange((value: string) => { this.title = value; })
              TextArea({ text: this.body, placeholder: '写下正文…', controller: this.bodyController })
                .id('compose-body')
                .width('100%')
                .constraintSize({ minHeight: 260 })
                .fontSize(Typography.BODY)
                .lineHeight(Typography.READING_LINE_HEIGHT)
                .fontColor(SemanticColors.textPrimary())
                .placeholderColor(SemanticColors.textSecondary())
                .caretColor($r('app.color.brand_primary'))
                .backgroundEffect(buildImmersiveGlassEffect(this.glassStyle))
                .border({ width: IMMERSIVE_GLASS_BORDER_WIDTH,
                  color: $r('app.color.bottom_tab_bar_highlight') })
                .borderRadius(Radius.MD)
                .shadow({
                  radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
                  color: $r('app.color.bottom_tab_bar_shadow'),
                  offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
                })
                .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
                .onChange((value: string) => { this.body = value; })
              this.attachmentPicker()
              this.forumSelector()
              if (this.resultMessage.length > 0) {
                Text(this.resultMessage)
                  .fontSize(Typography.LABEL)
                  .fontColor(SemanticColors.error())
                  .width('100%')
              }
              Blank().height(32)
            }
            .width('100%')
            .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.SM })
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
