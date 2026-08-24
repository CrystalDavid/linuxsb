import { AppColors, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { PostUiModel } from '../../models/presentation/ForumUiModels';
import { PostRichContent } from './PostRichContent';
import { UserAvatar } from './UserAvatar';

@Component
export struct TopicPostItem {
  post: PostUiModel = new PostUiModel();
  mainPost: boolean = false;
  onReply: (post: PostUiModel) => void = () => {};

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
  private threadContext() {
    if (this.isThreadedReply()) {
      Text(`回复 #${this.post.parentFloor}`)
        .id(`reply-thread-indicator-${this.post.floor}`)
        .fontSize(Typography.CAPTION)
        .fontColor(AppColors.brandPrimary())
        .margin({ top: Spacing.XS, bottom: Spacing.XS })
    }
  }

  @Builder
  private bodyColumn() {
    Column({ space: 0 }) {
      this.authorHeader()
      this.threadContext()
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
        Row() {
          Blank()
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: Spacing.XXS }) {
              SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left'))
                .fontSize(15)
                .fontColor([SemanticColors.textTertiary()])
              Text('回复')
                .fontSize(Typography.CAPTION)
                .fontColor(SemanticColors.textTertiary())
            }
          }
          .id(`reply-action-${this.post.floor}`)
          .height(30)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.onReply(this.post))
        }
        .width('100%')
        .margin({ top: Spacing.XS })
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
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
          .strokeWidth(0.5)
          .color(SemanticColors.divider())
          .margin({ left: Spacing.LG + this.avatarSize() + Spacing.MD, right: Spacing.LG })
      }
    }
    .id(this.mainPost ? 'topic-main-post' : `topic-reply-${this.post.floor}`)
    .width(`calc(100% - ${this.horizontalInset()}vp)`)
    .margin({ left: this.horizontalInset(), right: this.isThreadedReply() ? Spacing.LG : 0,
      top: this.isThreadedReply() ? Spacing.XS : 0, bottom: this.isThreadedReply() ? Spacing.XS : 0 })
    .backgroundColor(this.isThreadedReply() ? SemanticColors.surfaceMuted() : SemanticColors.surface())
    .borderRadius(this.isThreadedReply() ? Radius.MD : 0)
  }
}
