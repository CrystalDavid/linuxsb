import { TopicUiModel } from './ForumUiModels';

/**
 * ArkUI-native observable topic source shared by every lazy topic list.
 * It keeps list-node creation proportional to the viewport instead of the
 * total number of pages already loaded.
 */
export class TopicListDataSource implements IDataSource {
  private items: TopicUiModel[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): TopicUiModel {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  getAll(): TopicUiModel[] {
    return this.items;
  }

  reset(items: TopicUiModel[]): void {
    this.items = items.slice();
    for (let index = 0; index < this.listeners.length; index++) {
      this.listeners[index].onDataReloaded();
    }
  }

  replace(items: TopicUiModel[]): void {
    this.reset(items);
  }

  appendUnique(items: TopicUiModel[]): number {
    const existingIds = new Set<number>();
    for (let index = 0; index < this.items.length; index++) {
      existingIds.add(this.items[index].topicId);
    }
    const fresh: TopicUiModel[] = [];
    for (let index = 0; index < items.length; index++) {
      const topic = items[index];
      if (!existingIds.has(topic.topicId)) {
        existingIds.add(topic.topicId);
        fresh.push(topic);
      }
    }
    if (fresh.length === 0) {
      return 0;
    }
    const startIndex = this.items.length;
    this.items = this.items.concat(fresh);
    for (let itemIndex = 0; itemIndex < fresh.length; itemIndex++) {
      for (let listenerIndex = 0; listenerIndex < this.listeners.length; listenerIndex++) {
        this.listeners[listenerIndex].onDataAdd(startIndex + itemIndex);
      }
    }
    return fresh.length;
  }
}
