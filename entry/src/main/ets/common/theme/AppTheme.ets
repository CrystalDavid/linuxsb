import { Typography } from './DesignSystem';

export class AppSpacing {
  static readonly XXS: number = 4;
  static readonly XS: number = 8;
  static readonly SM: number = 12;
  static readonly MD: number = 16;
  static readonly LG: number = 20;
  static readonly XL: number = 24;
  static readonly XXL: number = 32;
}

export class AppRadius {
  static readonly SM: number = 8;
  static readonly MD: number = 12;
  static readonly LG: number = 18;
  static readonly PILL: number = 999;
}

export class AppTypography {
  static readonly CAPTION: number = Typography.CAPTION;
  static readonly BODY: number = Typography.BODY;
  static readonly BODY_LARGE: number = Typography.TOPIC_TITLE;
  static readonly TITLE: number = Typography.CONTENT_TITLE;
  static readonly DISPLAY: number = Typography.DISPLAY;
}

export class AppLayout {
  static readonly PHONE_CONTENT_MAX: number = 720;
  static readonly DETAIL_CONTENT_MAX: number = 840;
  static readonly TABLET_TWO_COLUMN_MIN: number = 900;
  static readonly TABLET_MASTER_PANE: number = 360;
}
