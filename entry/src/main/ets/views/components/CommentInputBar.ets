import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect,
  buildImmersiveSystemMaterialModifier,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';
import { GLASS_STYLE_STORAGE_KEY, GlassStyleMode } from '../../common/ui/GlassStyleParams';
import { SYS_BOTTOM_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { insertMarkdownAtCaret, PendingMarkdownInsert } from '../../common/utils/MarkdownInsert';
import { MAX_IMAGE_PICK_COUNT, pickImagesFromGallery } from '../../common/utils/PhotoPicker';
import { AttachmentUploadResult, WriteResult } from '../../services/repository/WriteRepository';
import { AttachmentThumbnail } from './AttachmentThumbnail';
import {
  GLASS_ACTION_ARROW_ICON_SIZE,
  GLASS_ACTION_ARROW_ICON_WEIGHT,
  ImmersiveIconButton
} from './ImmersiveIconButton';

export const REPLY_CONTROL_HEIGHT: number = 42;

@Component
export struct CommentInputBar {
  @Link draft: string;
  @Prop authenticated: boolean = false;
  bottomAvoidance: number = 0;
  onLogin: () => void = () => {};
  onSubmit: (body: string) => Promise<WriteResult> =
    async () => ({ ok: false, topicId: 0, message: '回复服务不可用', networkMs: 0 });
  onUploadImage: (uri: string) => Promise<AttachmentUploadResult> =
    async () => ({ ok: false, markdown: '', message: '上传服务不可用', networkMs: 0 });
  onSubmitted: () => void = () => {};
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;
  @StorageProp(GLASS_STYLE_STORAGE_KEY) private glassStyle: GlassStyleMode = GlassStyleMode.Translucent;
  @State private attachments: string[] = [];
  private draftController: TextInputController = new TextInputController();
  // 与 attachments 平行：选图那一刻回复输入框光标的位置（-1 表示未取到，
  // 提交时退化为末尾追加，与旧行为一致）。
  private attachmentInsertOffsets: number[] = [];
  @State private submitting: boolean = false;
  @State private errorMessage: string = '';

  private effectiveBottomInset(): number {
    return Math.max(this.bottomInset, this.bottomAvoidance);
  }

  private canSubmit(): boolean {
    return !this.submitting && (this.draft.trim().length > 0 || this.attachments.length > 0);
  }

  private async pickImages(): Promise<void> {
    if (!this.authenticated) {
      this.onLogin();
      return;
    }
    if (this.attachments.length >= MAX_IMAGE_PICK_COUNT) {
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
    // 快照“点添加图片那一刻”回复框光标的位置：用户意图就是在这里插图。
    const caretOffset = this.currentDraftCaretOffset();
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

  private currentDraftCaretOffset(): number {
    try {
      const caret = this.draftController.getCaretOffset();
      if (caret.index >= 0 && caret.index <= this.draft.length) {
        return caret.index;
      }
    } catch (_) {
    }
    return -1;
  }

  private async submit(): Promise<void> {
    if (!this.authenticated) {
      this.onLogin();
      return;
    }
    if (!this.canSubmit()) {
      return;
    }
    this.submitting = true;
    this.errorMessage = '';
    // 并发上传：多张图同时发起，避免串行往返把回复拖慢。
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
        this.errorMessage = uploaded.message;
        return;
      }
      const caretOffset = index < this.attachmentInsertOffsets.length ?
        this.attachmentInsertOffsets[index] : -1;
      pendingInserts.push({ caretOffset: caretOffset, markdown: uploaded.markdown, pickOrder: index });
    }
    // 图片按各自选图时的光标位置插入草稿（先插入原始文本再整体 trim，
    // 保证光标偏移始终相对未裁剪的草稿计算）。
    const body = insertMarkdownAtCaret(this.draft, pendingInserts).trim();
    const result = await this.onSubmit(body);
    this.submitting = false;
    if (!result.ok) {
      this.errorMessage = result.message;
      return;
    }
    this.draft = '';
    this.attachments = [];
    this.attachmentInsertOffsets = [];
    this.onSubmitted();
  }

  build() {
    Column({ space: Spacing.XXS }) {
      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(Typography.LABEL_SMALL)
          .fontColor(SemanticColors.error())
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (this.attachments.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.attachments, (uri: string, index: number) => {
            AttachmentThumbnail({
              uri: uri,
              semanticId: `reply-attachment-${index}`,
              onRemove: () => this.removeAttachment(index)
            })
              .margin({ right: Spacing.SM, bottom: Spacing.SM })
          }, (uri: string, index: number) => `${uri}-${index}`)
        }
        .id('reply-attachment-strip')
        .width('100%')
      }
      Row({ space: Spacing.SM }) {
        ImmersiveIconButton({
          icon: $r('sys.symbol.plus'),
          semanticId: 'topic-reply-attach',
          semanticLabel: '添加图片',
          buttonSize: REPLY_CONTROL_HEIGHT,
          iconSize: GLASS_ACTION_ARROW_ICON_SIZE,
          iconWeight: GLASS_ACTION_ARROW_ICON_WEIGHT,
          iconColor: $r('app.color.brand_primary'),
          onAction: () => this.pickImages()
        })
        Row() {
          TextInput({
            text: this.draft,
            placeholder: this.authenticated ? '写回复…' : '登录后回复',
            controller: this.draftController
          })
            .id('topic-reply-input')
            .layoutWeight(1)
            .height(REPLY_CONTROL_HEIGHT - 2)
            .fontSize(Typography.BODY)
            .fontColor(SemanticColors.textPrimary())
            .placeholderColor(SemanticColors.textSecondary())
            .caretColor($r('app.color.brand_primary'))
            .backgroundColor(Color.Transparent)
            .enabled(this.authenticated && !this.submitting)
            .enterKeyType(EnterKeyType.Send)
            .onChange((value: string) => { this.draft = value; })
            .onSubmit(() => this.submit())
        }
        .layoutWeight(1)
        .id('topic-reply-input-surface')
        .height(REPLY_CONTROL_HEIGHT)
        .padding({ left: 0, right: Spacing.SM })
        .backgroundEffect(buildImmersiveGlassEffect(this.glassStyle))
        .borderRadius(Radius.PILL)
        .border({ width: IMMERSIVE_GLASS_BORDER_WIDTH, color: $r('app.color.bottom_tab_bar_highlight') })
        .shadow({
          radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
          color: $r('app.color.bottom_tab_bar_shadow'),
          offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
        })
        .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
        .onClick(() => {
          if (!this.authenticated) {
            this.onLogin();
          }
        })

        ImmersiveIconButton({
          icon: $r('sys.symbol.arrow_up'),
          semanticId: 'topic-reply-send',
          semanticLabel: '发送回复',
          buttonSize: REPLY_CONTROL_HEIGHT,
          iconSize: GLASS_ACTION_ARROW_ICON_SIZE,
          iconWeight: GLASS_ACTION_ARROW_ICON_WEIGHT,
          iconColor: $r('app.color.brand_primary'),
          onAction: () => this.submit()
        })
          .opacity(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .id('comment-input-bar')
    .width('100%')
    .constraintSize({ minHeight: PageMetrics.REPLY_BAR_HEIGHT + this.effectiveBottomInset() })
    .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.SM,
      bottom: Spacing.SM + this.effectiveBottomInset() })
    .backgroundColor(Color.Transparent)
  }
}
