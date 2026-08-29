import { AppColors, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { PostUiModel } from '../../models/presentation/ForumUiModels';
import { PostRichContent } from './PostRichContent';
import { UserAvatar } from './UserAvatar';

@Component
export struct TopicPostItem {
  post: PostUiModel = new PostUiModel();
  mainPost: boolean = false;
  onReply: (post: PostUiModel) => void = () => {};
  onReport: (post: PostUiModel) => void = () => {};

  private authorName(): string {
    return this.post.author.displayName.length > 0 ? this.post.author.displayName : '社区用户';
  }

  private isThreadedReply(): boolean {
    return !this.mainPost && this.post.parentFloor > 0;
  }

  private avatarSize(): number {
    return this.mainPost ? 44 : (this.isThreadedReply() ? 32 : 40);
  }

  private horizontalInset(): number {
    return this.isThreadedReply() ? 54 : 0;
  }

  private editedLabel(): string {
    const metadata = this.post.editedMetadata;
    if (metadata === undefined) {
      return '';
    }
    if (metadata.editorName.length > 0) {
      return `由 ${metadata.editorName} 编辑于 ${metadata.editedAt}`;
    }
    return metadata.editedAt;
  }

  private postMetaLabel(): string {
    const role = this.mainPost ? '楼主' : `#${this.post.floor}`;
    const time = this.post.postedAtLabel.length > 0 ? ` · ${this.post.postedAtLabel}` : '';
    return `${role}${time}`;
  }

  @Builder
  private authorHeader() {
    Row({ space: Spacing.XS }) {
      Text(this.authorName())
        .fontSize(this.mainPost ? Typography.BODY_LARGE : Typography.BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.textPrimary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.mainPost) {
        Text('楼主')
          .fontSize(Typography.LABEL_SMALL)
          .fontColor(AppColors.brandPrimary())
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(AppColors.brandSoft())
          .borderRadius(Radius.PILL)
      }
      Blank()
      Text(this.postMetaLabel())
        .fontSize(Typography.CAPTION)
        .fontColor(SemanticColors.textTertiary())
        .maxLines(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private bodyColumn() {
    Column({ space: 0 }) {
      this.authorHeader()
      PostRichContent({ blocks: this.post.content, semanticPrefix: `post-content-${this.post.postId}` })
        .width('100%')
        .margin({ top: this.isThreadedReply() ? 0 : Spacing.SM })
      if (this.post.editedMetadata !== undefined) {
        Text(this.editedLabel())
          .fontSize(Typography.CAPTION)
          .fontColor(SemanticColors.textTertiary())
          .width('100%')
          .margin({ top: Spacing.SM })
      }
      if (!this.mainPost) {
        Row({ space: Spacing.XS }) {
          Blank()
          Button({ type: ButtonType.Capsule, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.heart'))
              .fontSize(15)
              .fontColor([SemanticColors.textTertiary()])
          }
          .id(`reply-like-${this.post.floor}`)
          .accessibilityText('点赞')
          .height(30)
          .padding({ left: Spacing.SM, right: Spacing.SM })
          .backgroundColor(Color.Transparent)
          .borderRadius(Radius.PILL)
          .clip(true)
          .hoverEffect(HoverEffect.None)
          .onClick(() => this.requestLike())
          Button({ type: ButtonType.Capsule, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.flag'))
              .fontSize(15)
              .fontColor([SemanticColors.textTertiary()])
          }
          .id(`reply-report-${this.post.floor}`)
          .accessibilityText('举报')
          .height(30)
          .padding({ left: Spacing.SM, right: Spacing.SM })
          .backgroundColor(Color.Transparent)
          .borderRadius(Radius.PILL)
          .clip(true)
          .hoverEffect(HoverEffect.None)
          .onClick(() => this.onReport(this.post))
          Button({ type: ButtonType.Capsule, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left'))
              .fontSize(15)
              .fontColor([SemanticColors.textTertiary()])
          }
          .id(`reply-action-${this.post.floor}`)
          .accessibilityText('回复')
          .height(30)
          .padding({ left: Spacing.SM, right: Spacing.SM })
          .backgroundColor(Color.Transparent)
          .borderRadius(Radius.PILL)
          .clip(true)
          .hoverEffect(HoverEffect.None)
          .onClick(() => this.onReply(this.post))
        }
        .width('100%')
        .margin({ top: Spacing.XS })
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  private requestLike(): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: '官方点赞打赏功能暂未接入', duration: 1600 });
    } catch (_) {}
  }

  build() {
    Column() {
      Row({ space: Spacing.MD }) {
        UserAvatar({
          user: this.post.author,
          avatarSize: this.avatarSize(),
          semanticId: `post-avatar-${this.post.postId}`
        })
        this.bodyColumn()
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({
        left: Spacing.LG,
        right: Spacing.LG,
        top: this.mainPost ? Spacing.LG : Spacing.MD,
        bottom: this.mainPost ? Spacing.LG : Spacing.MD
      })

      if (!this.isThreadedReply()) {
        Divider()
          .strokeWidth(0.35)
          .color(SemanticColors.divider())
          .margin({ left: Spacing.LG + this.avatarSize() + Spacing.MD, right: Spacing.LG })
      }
    }
    .id(this.mainPost ? 'topic-main-post' : `topic-reply-${this.post.floor}`)
    .width(`calc(100% - ${this.horizontalInset()}vp)`)
    .margin({ left: this.horizontalInset(), right: this.isThreadedReply() ? Spacing.LG : 0,
      top: this.isThreadedReply() ? Spacing.XS : 0, bottom: this.isThreadedReply() ? Spacing.XS : 0 })
    .backgroundColor(Color.Transparent)
    .borderRadius(0)
  }
}
