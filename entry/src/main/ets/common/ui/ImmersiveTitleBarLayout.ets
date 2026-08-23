const HDS_TITLE_BAR_BASE_HEIGHT: number = 56;
const HDS_TITLE_BAR_CONTENT_GAP: number = 8;

export function immersiveTitleBarBottomOffset(sysTopInset: number): number {
  return Math.max(0, sysTopInset) + HDS_TITLE_BAR_BASE_HEIGHT;
}

export function immersiveTitleBarContentTopSpacer(sysTopInset: number): number {
  return immersiveTitleBarBottomOffset(sysTopInset) + HDS_TITLE_BAR_CONTENT_GAP;
}
