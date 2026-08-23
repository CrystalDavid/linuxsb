import { TopicDetail } from '../../models/TopicModels';

export interface TopicCacheLookup {
  hit: boolean;
  ageMs: number;
  data?: TopicDetail;
}

class TopicCacheEntry {
  key: string = '';
  storedAt: number = 0;
  data: TopicDetail | undefined = undefined;
}

export type CacheClock = () => number;

/** Process-memory-only LRU cache. It never stores HTML, cookies or request headers. */
export class TopicMemoryCache {
  private entries: Map<string, TopicCacheEntry> = new Map<string, TopicCacheEntry>();
  private capacity: number;
  private ttlMs: number;
  private clock: CacheClock;

  constructor(capacity: number = 20, ttlMs: number = 120000, clock: CacheClock = () => Date.now()) {
    this.capacity = Math.max(1, capacity);
    this.ttlMs = Math.max(1, ttlMs);
    this.clock = clock;
  }

  get(topicId: number, authenticated: boolean): TopicCacheLookup {
    const key = this.key(topicId, authenticated);
    const entry = this.entries.get(key);
    if (entry === undefined || entry.data === undefined) {
      return { hit: false, ageMs: 0 };
    }
    const ageMs = Math.max(0, this.clock() - entry.storedAt);
    if (ageMs > this.ttlMs) {
      this.entries.delete(key);
      return { hit: false, ageMs: ageMs };
    }
    this.entries.delete(key);
    this.entries.set(key, entry);
    return { hit: true, ageMs: ageMs, data: entry.data };
  }

  put(topicId: number, authenticated: boolean, data: TopicDetail): void {
    const key = this.key(topicId, authenticated);
    const entry = new TopicCacheEntry();
    entry.key = key;
    entry.storedAt = this.clock();
    entry.data = data;
    this.entries.delete(key);
    this.entries.set(key, entry);
    while (this.entries.size > this.capacity) {
      const oldest = this.entries.keys().next();
      if (oldest.done) {
        break;
      }
      this.entries.delete(oldest.value);
    }
  }

  clearAnonymous(): void {
    const keys: string[] = [];
    this.entries.forEach((_value: TopicCacheEntry, key: string) => {
      if (key.startsWith('anon:')) {
        keys.push(key);
      }
    });
    for (let index = 0; index < keys.length; index++) {
      this.entries.delete(keys[index]);
    }
  }

  clear(): void {
    this.entries.clear();
  }

  size(): number {
    return this.entries.size;
  }

  private key(topicId: number, authenticated: boolean): string {
    return `${authenticated ? 'auth' : 'anon'}:${topicId}`;
  }
}
