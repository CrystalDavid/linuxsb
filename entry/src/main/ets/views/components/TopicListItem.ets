import {
  avatarGap,
  AVATAR_SIZE_DEFAULT,
  LINE_HEIGHT_RATIO_DEFAULT,
  metaRowGap,
  ROW_PADDING_DEFAULT,
  SECONDARY_FONT_SIZE_DEFAULT,
  TITLE_FONT_SIZE_DEFAULT,
  TITLE_FONT_WEIGHT_DEFAULT,
  titleLineHeight,
  TopicListLayoutVariant
} from '../../common/theme/TopicListStylePrefs';
import { SemanticColors, Spacing } from '../../common/theme/DesignSystem';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { TopicMetadataBadges } from './TopicBadges';
import { UserAvatar } from './UserAvatar';

@Component
export struct TopicListItem {
  topic: TopicUiModel = new TopicUiModel();
  onTopicClick: (topic: TopicUiModel) => void = () => {};
  contentHorizontalPadding: number = 12;
  semanticId: string = '';
  @Prop layoutVariant: TopicListLayoutVariant = TopicListLayoutVariant.LegacyCompact;
  emphasizeTitle: boolean = false;
  avatarSizeOverride: number = 0;
  metadataGapOverride: number = 0;

  private authorName(): string {
    return this.topic.author.displayName.length > 0 ? this.topic.author.displayName : '社区用户';
  }

  private authorAndReplies(): string {
    return this.topic.authorAndRepliesLabel;
  }

  private replyLabel(): string {
    return this.topic.replyCountLabel;
  }

  private activityTimeLabel(): string {
    return this.topic.activityTimeLabel;
  }

  private headerActivityLabel(): string {
    return this.topic.headerActivityLabel;
  }

  private dividerInset(): number {
    if (this.layoutVariant === TopicListLayoutVariant.AuthorHeader) {
      return this.contentHorizontalPadding;
    }
    return this.contentHorizontalPadding + this.topicAvatarSize() + avatarGap(this.topicAvatarSize());
  }

  private topicTitleSize(): number {
    return this.emphasizeTitle || this.layoutVariant === TopicListLayoutVariant.ThreeMetadataRows ||
      this.layoutVariant === TopicListLayoutVariant.AuthorHeader ? TITLE_FONT_SIZE_DEFAULT + 1 :
      TITLE_FONT_SIZE_DEFAULT;
  }

  private topicTitleWeight(): number {
    return this.emphasizeTitle || this.layoutVariant === TopicListLayoutVariant.ThreeMetadataRows ||
      this.layoutVariant === TopicListLayoutVariant.AuthorHeader ? 500 : TITLE_FONT_WEIGHT_DEFAULT;
  }

  private topicAvatarSize(): number {
    if (this.avatarSizeOverride > 0) {
      return this.avatarSizeOverride;
    }
    return this.layoutVariant === TopicListLayoutVariant.AuthorHeader ? 38 : AVATAR_SIZE_DEFAULT;
  }

  private currentMetadataGap(): number {
    if (this.metadataGapOverride > 0) {
      return this.metadataGapOverride;
    }
    return this.layoutVariant === TopicListLayoutVariant.CurrentWithExpandedGap ?
      Spacing.SM : metaRowGap(ROW_PADDING_DEFAULT);
  }

  @Builder
  private topicTitle() {
    Text(this.topic.title)
      .fontSize(this.topicTitleSize())
      .fontWeight(this.topicTitleWeight())
      .fontColor(SemanticColors.textPrimary())
      .lineHeight(titleLineHeight(this.topicTitleSize(), LINE_HEIGHT_RATIO_DEFAULT))
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
  }

  @Builder
  private avatar() {
    UserAvatar({
      user: this.topic.author,
      avatarSize: this.topicAvatarSize(),
      semanticId: `topic-avatar-${this.topic.topicId}`
    })
  }

  @Builder
  private currentWithExpandedGap() {
    Row() {
      this.avatar()
      Column() {
        this.topicTitle()

        Row() {
          Row({ space: Spacing.XS }) {
            TopicMetadataBadges({ topic: this.topic })
            if (this.authorAndReplies().length > 0) {
              Text(this.authorAndReplies())
                .fontSize(SECONDARY_FONT_SIZE_DEFAULT)
                .fontColor(SemanticColors.textSecondary())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .layoutWeight(1)
          .clip(true)

          if (this.activityTimeLabel().length > 0) {
            Text(this.activityTimeLabel())
              .fontSize(SECONDARY_FONT_SIZE_DEFAULT)
              .fontColor(SemanticColors.textSecondary())
              .margin({ left: Spacing.SM })
              .maxLines(1)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: this.currentMetadataGap() })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: avatarGap(this.topicAvatarSize()) })
    }
    .width('100%')
    .padding({
      left: this.contentHorizontalPadding,
      right: this.contentHorizontalPadding,
      top: ROW_PADDING_DEFAULT,
      bottom: ROW_PADDING_DEFAULT
    })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private threeMetadataRows() {
    Row() {
      this.avatar()
      Column() {
        this.topicTitle()

        Row() {
          TopicMetadataBadges({ topic: this.topic })
        }
        .width('100%')
        .margin({ top: Spacing.XS })

        Row() {
          Text(this.authorName())
            .fontSize(SECONDARY_FONT_SIZE_DEFAULT)
            .fontColor(SemanticColors.textSecondary())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (this.replyLabel().length > 0) {
            Text(this.replyLabel())
              .fontSize(SECONDARY_FONT_SIZE_DEFAULT)
              .fontColor(SemanticColors.textSecondary())
              .margin({ left: Spacing.SM })
              .maxLines(1)
          }
          if (this.activityTimeLabel().length > 0) {
            Text(this.activityTimeLabel())
              .fontSize(SECONDARY_FONT_SIZE_DEFAULT)
              .fontColor(SemanticColors.textSecondary())
              .margin({ left: Spacing.MD })
              .maxLines(1)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: Spacing.XS })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: avatarGap(this.topicAvatarSize()) })
    }
    .width('100%')
    .padding({
      left: this.contentHorizontalPadding,
      right: this.contentHorizontalPadding,
      top: ROW_PADDING_DEFAULT,
      bottom: ROW_PADDING_DEFAULT
    })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private authorHeader() {
    Column() {
      Row() {
        this.avatar()
        Column() {
          Text(this.authorName())
            .fontSize(SECONDARY_FONT_SIZE_DEFAULT + 1)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textPrimary())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          if (this.headerActivityLabel().length > 0) {
            Text(this.headerActivityLabel())
              .fontSize(SECONDARY_FONT_SIZE_DEFAULT)
              .fontColor(SemanticColors.textSecondary())
              .maxLines(1)
              .margin({ top: Spacing.XXS })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: avatarGap(this.topicAvatarSize()) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column() {
        this.topicTitle()
      }
      .width('100%')
      .margin({ top: Spacing.SM })

      Row() {
        TopicMetadataBadges({ topic: this.topic })
      }
      .width('100%')
      .margin({ top: Spacing.XS })
    }
    .width('100%')
    .padding({
      left: this.contentHorizontalPadding,
      right: this.contentHorizontalPadding,
      top: ROW_PADDING_DEFAULT,
      bottom: ROW_PADDING_DEFAULT
    })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    ListItem() {
      Column() {
        if (this.layoutVariant === TopicListLayoutVariant.ThreeMetadataRows) {
          this.threeMetadataRows()
        } else if (this.layoutVariant === TopicListLayoutVariant.AuthorHeader) {
          this.authorHeader()
        } else {
          this.currentWithExpandedGap()
        }

        Divider()
          .color(SemanticColors.divider())
          .strokeWidth(1)
          .margin({ left: this.dividerInset() })
      }
      .width('100%')
      .onClick(() => this.onTopicClick(this.topic))
    }
    .id(this.semanticId.length > 0 ? this.semanticId : `topic-item-${this.topic.topicId}`)
    .accessibilityText(this.topic.title)
  }
}
