export interface TopicPrefetchPort {
  prefetchTopic(topicId: number): Promise<void>;
}

/** Cooperative, low-priority prefetch queue: max three candidates and two workers. */
export class TopicPrefetchCoordinator {
  private source: TopicPrefetchPort;
  private generation: number = 0;
  private startDelayMs: number;

  constructor(source: TopicPrefetchPort, startDelayMs: number = 500) {
    this.source = source;
    this.startDelayMs = Math.max(0, startDelayMs);
  }

  schedule(topicIds: number[]): void {
    const generation = ++this.generation;
    const queue = this.uniquePositive(topicIds, 3);
    if (queue.length === 0) {
      return;
    }
    if (this.startDelayMs === 0) {
      this.startWorkers(queue, generation);
      return;
    }
    setTimeout(() => this.startWorkers(queue, generation), this.startDelayMs);
  }

  cancel(): void {
    this.generation++;
  }

  private async runWorker(queue: number[], startIndex: number, generation: number): Promise<void> {
    let index = startIndex;
    while (index < queue.length && generation === this.generation) {
      try {
        await this.source.prefetchTopic(queue[index]);
      } catch (_) {
        // Prefetch is best-effort and must never change the visible Home state.
      }
      index += 2;
    }
  }

  private startWorkers(queue: number[], generation: number): void {
    if (generation !== this.generation) {
      return;
    }
    this.runWorker(queue, 0, generation);
    if (queue.length > 1) {
      this.runWorker(queue, 1, generation);
    }
  }

  private uniquePositive(values: number[], limit: number): number[] {
    const output: number[] = [];
    const seen = new Set<number>();
    for (let index = 0; index < values.length && output.length < limit; index++) {
      const value = values[index];
      if (value > 0 && !seen.has(value)) {
        seen.add(value);
        output.push(value);
      }
    }
    return output;
  }
}
