/**
 * Small reusable IDataSource for ArkUI LazyForEach collections.
 *
 * Keeping this adapter independent of page state lets long grids and horizontal
 * pickers create only the nodes near the viewport instead of eagerly building
 * every item during the first layout pass.
 */
export class ArrayDataSource<T> implements IDataSource {
  private items: T[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(items: T[] = []) {
    this.items = items.slice();
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): T {
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

  reset(items: T[]): void {
    this.items = items.slice();
    for (let index = 0; index < this.listeners.length; index++) {
      this.listeners[index].onDataReloaded();
    }
  }
}
