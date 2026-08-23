import { TopicUiModel } from '../../models/presentation/ForumUiModels';

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

  replace(items: TopicUiModel[]): void {
    this.items = items.slice();
    for (let index = 0; index < this.listeners.length; index++) {
      this.listeners[index].onDataReloaded();
    }
  }
}
