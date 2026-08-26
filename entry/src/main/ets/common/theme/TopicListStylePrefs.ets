// Authorized geometry adaptation of ArkDO TopicListStylePrefs.ets at the fixed upstream commit.
import { Typography } from './DesignSystem';

export const TOPIC_LIST_TITLE_FONT_SIZE_KEY: string = 'topicListTitleFontSize';
export const TOPIC_LIST_TITLE_FONT_WEIGHT_KEY: string = 'topicListTitleFontWeight';
export const TOPIC_LIST_LINE_HEIGHT_RATIO_KEY: string = 'topicListLineHeightRatio';
export const TOPIC_LIST_ROW_PADDING_KEY: string = 'topicListRowPadding';
export const TOPIC_LIST_AVATAR_SIZE_KEY: string = 'topicListAvatarSize';

export const TITLE_FONT_SIZE_DEFAULT: number = Typography.LIST_TITLE;
export const TITLE_FONT_WEIGHT_DEFAULT: number = 400;
export const SECONDARY_FONT_SIZE_DEFAULT: number = Typography.METADATA;
export const LINE_HEIGHT_RATIO_DEFAULT: number = 1.35;
export const ROW_PADDING_DEFAULT: number = 8;
export const AVATAR_SIZE_DEFAULT: number = 48;

export enum TopicListLayoutVariant {
  LegacyCompact = 0,
  CurrentWithExpandedGap = 1,
  ThreeMetadataRows = 2,
  AuthorHeader = 3
}

export function titleLineHeight(fontSize: number = TITLE_FONT_SIZE_DEFAULT,
  ratio: number = LINE_HEIGHT_RATIO_DEFAULT): number {
  return Math.round(fontSize * ratio);
}

export function secondaryFontSize(fontSize: number = TITLE_FONT_SIZE_DEFAULT): number {
  return Math.max(10, Math.min(17, Math.round(fontSize) - 4));
}

export function avatarGap(avatarSize: number = AVATAR_SIZE_DEFAULT): number {
  return Math.max(6, Math.round(avatarSize / 6));
}

export function metaRowGap(rowPadding: number = ROW_PADDING_DEFAULT): number {
  return Math.max(2, Math.round(rowPadding * 3 / 8));
}

export class TopicListStylePrefs {
  static seedDefaults(): void {
    AppStorage.setOrCreate(TOPIC_LIST_TITLE_FONT_SIZE_KEY, TITLE_FONT_SIZE_DEFAULT);
    AppStorage.setOrCreate(TOPIC_LIST_TITLE_FONT_WEIGHT_KEY, TITLE_FONT_WEIGHT_DEFAULT);
    AppStorage.setOrCreate(TOPIC_LIST_LINE_HEIGHT_RATIO_KEY, LINE_HEIGHT_RATIO_DEFAULT);
    AppStorage.setOrCreate(TOPIC_LIST_ROW_PADDING_KEY, ROW_PADDING_DEFAULT);
    AppStorage.setOrCreate(TOPIC_LIST_AVATAR_SIZE_KEY, AVATAR_SIZE_DEFAULT);
  }
}
