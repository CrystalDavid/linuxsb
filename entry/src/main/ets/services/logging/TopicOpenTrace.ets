import { hilog } from '@kit.PerformanceAnalysisKit';

const TRACE_DOMAIN: number = 0x0000;
const TRACE_TAG: string = 'M2R1TopicOpen';

class TopicOpenTraceSnapshot {
  traceId: number = 0;
  topicId: number = 0;
  authenticated: boolean = false;
  cacheHit: boolean = false;
  firstByteAvailable: boolean = false;
  tapAt: number = 0;
  routePushAt: number = 0;
  destinationAppearAt: number = 0;
  skeletonFrameAt: number = 0;
  cacheLookupStart: number = 0;
  cacheLookupEnd: number = 0;
  requestQueuedAt: number = 0;
  requestStartAt: number = 0;
  firstByteAt: number = 0;
  bodyCompleteAt: number = 0;
  taskPoolSubmitAt: number = 0;
  decodeCompleteAt: number = 0;
  mappingCompleteAt: number = 0;
  firstContentFrameAt: number = 0;
  imageRequestsStartAt: number = 0;
  networkRequestCount: number = 0;
  result: string = 'RUNNING';
}

/** Debug-only, metadata-only trace for the topic opening critical path. */
export class TopicOpenTrace {
  private static enabled: boolean = false;
  private static nextTraceId: number = 1;
  private static active: TopicOpenTraceSnapshot | undefined = undefined;

  static configure(enabled: boolean): void {
    TopicOpenTrace.enabled = enabled;
    if (!enabled) {
      TopicOpenTrace.active = undefined;
    }
  }

  static begin(topicId: number): void {
    if (!TopicOpenTrace.enabled || topicId <= 0) {
      return;
    }
    const snapshot = new TopicOpenTraceSnapshot();
    snapshot.traceId = TopicOpenTrace.nextTraceId++;
    snapshot.topicId = topicId;
    snapshot.tapAt = Date.now();
    TopicOpenTrace.active = snapshot;
    TopicOpenTrace.logEvent('tapAt', snapshot.tapAt);
  }

  static markRoutePush(): void {
    TopicOpenTrace.mark('routePushAt');
  }

  static markDestinationAppear(): void {
    TopicOpenTrace.mark('destinationAppearAt');
  }

  static markSkeletonFrame(): void {
    TopicOpenTrace.markOnce('skeletonFrameAt');
  }

  static markCacheLookupStart(authenticated: boolean): void {
    const snapshot = TopicOpenTrace.active;
    if (snapshot === undefined) {
      return;
    }
    snapshot.authenticated = authenticated;
    TopicOpenTrace.mark('cacheLookupStart');
  }

  static markCacheLookupEnd(cacheHit: boolean): void {
    const snapshot = TopicOpenTrace.active;
    if (snapshot === undefined) {
      return;
    }
    snapshot.cacheHit = cacheHit;
    TopicOpenTrace.mark('cacheLookupEnd');
  }

  static markRequestQueued(): void {
    TopicOpenTrace.mark('requestQueuedAt');
  }

  static markRequestStart(): void {
    const snapshot = TopicOpenTrace.active;
    if (snapshot !== undefined) {
      snapshot.networkRequestCount++;
    }
    TopicOpenTrace.mark('requestStartAt');
  }

  static markBodyComplete(): void {
    TopicOpenTrace.mark('bodyCompleteAt');
  }

  static markTaskPoolSubmit(): void {
    TopicOpenTrace.mark('taskPoolSubmitAt');
  }

  static markDecodeComplete(): void {
    TopicOpenTrace.mark('decodeCompleteAt');
  }

  static markMappingComplete(): void {
    TopicOpenTrace.mark('mappingCompleteAt');
  }

  static markFirstContentFrame(): void {
    TopicOpenTrace.markOnce('firstContentFrameAt');
    TopicOpenTrace.complete('CONTENT');
  }

  static markImageRequestsStart(): void {
    TopicOpenTrace.markOnce('imageRequestsStartAt');
  }

  static fail(result: string): void {
    TopicOpenTrace.complete(result.length > 0 ? result : 'FAILED');
  }

  private static mark(field: string): void {
    const snapshot = TopicOpenTrace.active;
    if (snapshot === undefined) {
      return;
    }
    const now = Date.now();
    if (field === 'routePushAt') {
      snapshot.routePushAt = now;
    } else if (field === 'destinationAppearAt') {
      snapshot.destinationAppearAt = now;
    } else if (field === 'cacheLookupStart') {
      snapshot.cacheLookupStart = now;
    } else if (field === 'cacheLookupEnd') {
      snapshot.cacheLookupEnd = now;
    } else if (field === 'requestQueuedAt') {
      snapshot.requestQueuedAt = now;
    } else if (field === 'requestStartAt') {
      snapshot.requestStartAt = now;
    } else if (field === 'bodyCompleteAt') {
      snapshot.bodyCompleteAt = now;
    } else if (field === 'taskPoolSubmitAt') {
      snapshot.taskPoolSubmitAt = now;
    } else if (field === 'decodeCompleteAt') {
      snapshot.decodeCompleteAt = now;
    } else if (field === 'mappingCompleteAt') {
      snapshot.mappingCompleteAt = now;
    }
    TopicOpenTrace.logEvent(field, now);
  }

  private static markOnce(field: string): void {
    const snapshot = TopicOpenTrace.active;
    if (snapshot === undefined) {
      return;
    }
    if (field === 'skeletonFrameAt' && snapshot.skeletonFrameAt === 0) {
      snapshot.skeletonFrameAt = Date.now();
      TopicOpenTrace.logEvent(field, snapshot.skeletonFrameAt);
    } else if (field === 'firstContentFrameAt' && snapshot.firstContentFrameAt === 0) {
      snapshot.firstContentFrameAt = Date.now();
      TopicOpenTrace.logEvent(field, snapshot.firstContentFrameAt);
    } else if (field === 'imageRequestsStartAt' && snapshot.imageRequestsStartAt === 0) {
      snapshot.imageRequestsStartAt = Date.now();
      TopicOpenTrace.logEvent(field, snapshot.imageRequestsStartAt);
    }
  }

  private static complete(result: string): void {
    const snapshot = TopicOpenTrace.active;
    if (snapshot === undefined) {
      return;
    }
    snapshot.result = result;
    hilog.info(TRACE_DOMAIN, TRACE_TAG, '[M2R1_TRACE] %{public}s', JSON.stringify(snapshot));
    TopicOpenTrace.active = undefined;
  }

  private static logEvent(stage: string, at: number): void {
    const snapshot = TopicOpenTrace.active;
    if (snapshot === undefined) {
      return;
    }
    hilog.info(
      TRACE_DOMAIN,
      TRACE_TAG,
      '[M2R1_TRACE_EVENT] id=%{public}d topic=%{public}d stage=%{public}s offsetMs=%{public}d',
      snapshot.traceId,
      snapshot.topicId,
      stage,
      at - snapshot.tapAt
    );
  }
}
