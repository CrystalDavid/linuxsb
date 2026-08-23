export const SMART_REACH_LEFT_HAND_STORAGE_KEY: string = 'smartReachLeftHand';
export const SMART_REACH_ANIMATION_DURATION: number = 300;

export function smartReachBottomAlignRules(leftHanded: boolean): AlignRuleOption {
  if (leftHanded) {
    return {
      left: { anchor: '__container__', align: HorizontalAlign.Start },
      bottom: { anchor: '__container__', align: VerticalAlign.Bottom }
    };
  }
  return {
    right: { anchor: '__container__', align: HorizontalAlign.End },
    bottom: { anchor: '__container__', align: VerticalAlign.Bottom }
  };
}
