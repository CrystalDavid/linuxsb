import {
  avatarGap,
  AVATAR_SIZE_DEFAULT,
  LINE_HEIGHT_RATIO_DEFAULT,
  metaRowGap,
  ROW_PADDING_DEFAULT,
  secondaryFontSize,
  TITLE_FONT_SIZE_DEFAULT,
  TITLE_FONT_WEIGHT_DEFAULT,
  titleLineHeight
} from '../../common/theme/TopicListStylePrefs';
import { SemanticColors, Spacing } from '../../common/theme/DesignSystem';
import { RelativeTime } from '../../common/utils/RelativeTime';
import { TopicUiModel } from '../../models/presentation/ForumUiModels';
import { TopicMetadataBadges } from './TopicBadges';
import { UserAvatar } from './UserAvatar';

@Component
export struct TopicListItem {
  topic: TopicUiModel = new TopicUiModel();
  onTopicClick: (topic: TopicUiModel) => void = () => {};
  contentHorizontalPadding: number = 12;
  semanticId: string = '';

  private authorAndReplies(): string {
    const parts: string[] = [];
    if (this.topic.author.displayName.length > 0) {
      parts.push(this.topic.author.displayName);
    }
    if (this.topic.replyCount >= 0) {
      parts.push(`${this.topic.replyCount} 回复`);
    }
    return parts.join(' · ');
  }

  build() {
    ListItem() {
      Column() {
        Row() {
          UserAvatar({
            user: this.topic.author,
            avatarSize: AVATAR_SIZE_DEFAULT,
            semanticId: `topic-avatar-${this.topic.topicId}`
          })
            .margin({ right: avatarGap(AVATAR_SIZE_DEFAULT) })

          Column() {
            Text(this.topic.title)
              .fontSize(TITLE_FONT_SIZE_DEFAULT)
              .fontWeight(TITLE_FONT_WEIGHT_DEFAULT)
              .fontColor(SemanticColors.textPrimary())
              .lineHeight(titleLineHeight(TITLE_FONT_SIZE_DEFAULT, LINE_HEIGHT_RATIO_DEFAULT))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')

            Row() {
              Row({ space: Spacing.XS }) {
                TopicMetadataBadges({ topic: this.topic })
                if (this.authorAndReplies().length > 0) {
                  Text(this.authorAndReplies())
                    .fontSize(secondaryFontSize(TITLE_FONT_SIZE_DEFAULT))
                    .fontColor(SemanticColors.textSecondary())
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .layoutWeight(1)
              .clip(true)

              if (this.topic.lastReplyAt > 0) {
                Text(RelativeTime.fromEpochSeconds(this.topic.lastReplyAt))
                  .fontSize(secondaryFontSize(TITLE_FONT_SIZE_DEFAULT))
                  .fontColor(SemanticColors.textSecondary())
                  .margin({ left: Spacing.SM })
                  .maxLines(1)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: metaRowGap(ROW_PADDING_DEFAULT) })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({
          left: this.contentHorizontalPadding,
          right: this.contentHorizontalPadding,
          top: ROW_PADDING_DEFAULT,
          bottom: ROW_PADDING_DEFAULT
        })
        .alignItems(VerticalAlign.Top)

        Divider()
          .color(SemanticColors.divider())
          .strokeWidth(1)
          .margin({ left: this.contentHorizontalPadding + AVATAR_SIZE_DEFAULT + avatarGap(AVATAR_SIZE_DEFAULT) })
      }
      .width('100%')
      .onClick(() => this.onTopicClick(this.topic))
    }
    .id(this.semanticId.length > 0 ? this.semanticId : `topic-item-${this.topic.topicId}`)
    .accessibilityText(this.topic.title)
  }
}
