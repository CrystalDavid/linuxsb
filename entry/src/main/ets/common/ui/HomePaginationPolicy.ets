/**
 * Triggers the next real server page when the viewport approaches the end of the currently loaded list.
 * The loaded-count latch prevents repeated callbacks for the same page while preserving retry by tap.
 */
export function shouldAutoLoadNextHomePage(
  lastVisibleIndex: number,
  loadedTopicCount: number,
  hasMore: boolean,
  loadingMore: boolean,
  lastTriggeredTopicCount: number
): boolean {
  if (!hasMore || loadingMore || loadedTopicCount <= 0 || loadedTopicCount === lastTriggeredTopicCount) {
    return false;
  }
  return lastVisibleIndex >= Math.max(0, loadedTopicCount - 3);
}
