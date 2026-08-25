import { TopicListLayoutVariant } from './TopicListStylePrefs';

export const HOME_TOPIC_LIST_LAYOUT_STORAGE_KEY: string = 'homeTopicListLayoutMode';

export enum HomeTopicListLayoutMode {
  TitleFirst = 'TITLE_FIRST',
  AuthorFirst = 'AUTHOR_FIRST'
}

export function resolveHomeTopicListLayout(mode: string): TopicListLayoutVariant {
  return mode === HomeTopicListLayoutMode.AuthorFirst ?
    TopicListLayoutVariant.AuthorHeader : TopicListLayoutVariant.ThreeMetadataRows;
}

export class HomeTopicListLayout {
  static init(): void {
    PersistentStorage.persistProp(HOME_TOPIC_LIST_LAYOUT_STORAGE_KEY, HomeTopicListLayoutMode.TitleFirst);
  }

  static setMode(mode: HomeTopicListLayoutMode): void {
    if (AppStorage.has(HOME_TOPIC_LIST_LAYOUT_STORAGE_KEY)) {
      AppStorage.set(HOME_TOPIC_LIST_LAYOUT_STORAGE_KEY, mode);
    } else {
      AppStorage.setOrCreate(HOME_TOPIC_LIST_LAYOUT_STORAGE_KEY, mode);
    }
  }
}
