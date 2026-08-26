import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { HomeFeed } from '../../models/HomeModels';

const HOME_CACHE_FILE: string = 'shaobing_home_feed_cache';
const HOME_CACHE_SCHEMA_VERSION: number = 1;
const HOME_CACHE_MAX_AGE_MS: number = 12 * 60 * 60 * 1000;
const HOME_CACHE_WRITE_DELAY_MS: number = 300;

interface HomeFeedCacheEnvelope {
  schemaVersion: number;
  storedAt: number;
  feed: HomeFeed;
}

export interface HomeFeedCacheLookup {
  feed: HomeFeed;
  ageMs: number;
}

/**
 * Native Preferences-backed, anonymous-home-only snapshot cache.
 *
 * The cache exists to make a process-cold launch useful before the network round trip completes.
 * The repository always revalidates after presenting the snapshot, and authenticated/search/user
 * feeds never enter this store.
 */
export class HomeFeedDiskCache {
  private storePromise: Promise<preferences.Preferences>;
  private clock: () => number;

  constructor(context: common.UIAbilityContext, clock: () => number = () => Date.now()) {
    this.storePromise = preferences.getPreferences(context, HOME_CACHE_FILE);
    this.clock = clock;
  }

  async read(key: string): Promise<HomeFeedCacheLookup | undefined> {
    try {
      const store = await this.storePromise;
      const value = await store.get(key, '');
      if (typeof value !== 'string' || value.length === 0) {
        return undefined;
      }
      const envelope = JSON.parse(value) as HomeFeedCacheEnvelope;
      if (envelope.schemaVersion !== HOME_CACHE_SCHEMA_VERSION || envelope.storedAt <= 0 ||
        envelope.feed === undefined || !Array.isArray(envelope.feed.topics) ||
        envelope.feed.protocolVersion.length === 0) {
        return undefined;
      }
      const ageMs = Math.max(0, this.clock() - envelope.storedAt);
      if (ageMs > HOME_CACHE_MAX_AGE_MS) {
        return undefined;
      }
      return { feed: envelope.feed, ageMs: ageMs };
    } catch (_) {
      return undefined;
    }
  }

  scheduleWrite(key: string, feed: HomeFeed): void {
    setTimeout(() => {
      this.write(key, feed);
    }, HOME_CACHE_WRITE_DELAY_MS);
  }

  private async write(key: string, feed: HomeFeed): Promise<void> {
    try {
      const store = await this.storePromise;
      const envelope: HomeFeedCacheEnvelope = {
        schemaVersion: HOME_CACHE_SCHEMA_VERSION,
        storedAt: this.clock(),
        feed: feed
      };
      await store.put(key, JSON.stringify(envelope));
      await store.flush();
    } catch (_) {
      // A disk-cache failure must never block or replace the live network feed.
    }
  }
}
