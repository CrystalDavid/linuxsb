export class AppColors {
  static brandPrimary(): ResourceColor { return $r('app.color.brand_primary'); }
  static brandAccent(): ResourceColor { return $r('app.color.brand_accent'); }
  static brandSoft(): ResourceColor { return $r('app.color.brand_soft'); }
}

export class SemanticColors {
  static page(): ResourceColor { return $r('app.color.page_background'); }
  static surface(): ResourceColor { return $r('app.color.surface'); }
  static surfaceElevated(): ResourceColor { return $r('app.color.surface_elevated'); }
  static surfaceMuted(): ResourceColor { return $r('app.color.surface_secondary'); }
  static textPrimary(): ResourceColor { return $r('app.color.text_primary'); }
  static textSecondary(): ResourceColor { return $r('app.color.text_secondary'); }
  static textTertiary(): ResourceColor { return $r('app.color.text_tertiary'); }
  static divider(): ResourceColor { return $r('app.color.divider'); }
  static outline(): ResourceColor { return $r('app.color.border'); }
  static error(): ResourceColor { return $r('app.color.error'); }
  static errorSoft(): ResourceColor { return $r('app.color.error_soft'); }
  static warning(): ResourceColor { return $r('app.color.warning'); }
  static warningSoft(): ResourceColor { return $r('app.color.warning_soft'); }
  static success(): ResourceColor { return $r('app.color.success'); }
  static disabled(): ResourceColor { return $r('app.color.disabled'); }
  static disabledSurface(): ResourceColor { return $r('app.color.disabled_surface'); }
  static codeBackground(): ResourceColor { return $r('app.color.code_background'); }
  static quoteBackground(): ResourceColor { return $r('app.color.quote_background'); }
  static skeleton(): ResourceColor { return $r('app.color.skeleton'); }
  static avatarBackground(): ResourceColor { return $r('app.color.avatar_background'); }
}

export class Typography {
  // Fixed text scale: every business-facing Text/Button/TextInput size maps to
  // one of these 12 values. SymbolGlyph/icon geometry is intentionally separate.
  static readonly MICRO: number = 11;
  static readonly CAPTION: number = 12;
  static readonly METADATA: number = 13;
  static readonly BODY_SMALL: number = 14;
  static readonly BODY: number = 15;
  static readonly LIST_TITLE: number = 16;
  static readonly TOPIC_TITLE: number = 17;
  static readonly SECTION_TITLE: number = 18;
  static readonly CONTENT_TITLE: number = 20;
  static readonly PAGE_TITLE: number = 22;
  static readonly HEADLINE: number = 24;
  static readonly DISPLAY: number = 26;

  // Compatibility names keep older call sites readable while resolving to the
  // same canonical scale above; they do not introduce additional font sizes.
  static readonly LABEL_SMALL: number = Typography.MICRO;
  static readonly LABEL: number = Typography.METADATA;
  static readonly BODY_LARGE: number = Typography.TOPIC_TITLE;
  static readonly TITLE_SMALL: number = Typography.SECTION_TITLE;
  static readonly TITLE: number = Typography.CONTENT_TITLE;
  static readonly TITLE_LARGE: number = Typography.PAGE_TITLE;
  static readonly BODY_LINE_HEIGHT: number = 23;
  static readonly READING_LINE_HEIGHT: number = 25;
  static readonly CODE: number = Typography.METADATA;
}

export class Spacing {
  static readonly XXS: number = 4;
  static readonly XS: number = 6;
  static readonly SM: number = 8;
  static readonly MD: number = 12;
  static readonly LG: number = 16;
  static readonly XL: number = 20;
  static readonly XXL: number = 24;
  static readonly XXXL: number = 32;
}

export class Radius {
  static readonly XS: number = 6;
  static readonly SM: number = 8;
  static readonly MD: number = 12;
  static readonly LG: number = 18;
  static readonly PILL: number = 999;
}

export class Elevation {
  static readonly FLOATING_RADIUS: number = 18;
  static readonly FLOATING_OFFSET_Y: number = 6;
  static readonly APP_BAR_RADIUS: number = 10;
  static readonly APP_BAR_OFFSET_Y: number = 2;
}

export class MotionDuration {
  static readonly QUICK: number = 120;
  static readonly STANDARD: number = 220;
  static readonly DRAWER_COMMIT: number = 280;
  static readonly EMPHASIZED: number = 320;
  static readonly DEBUG_LONG_PRESS: number = 1200;
}

export class PageMetrics {
  static readonly PHONE_CONTENT_MAX: number = 720;
  static readonly DETAIL_CONTENT_MAX: number = 840;
  static readonly HORIZONTAL_PADDING: number = 12;
  static readonly TOP_BAR_HEIGHT: number = 56;
  static readonly TOP_BAR_GAP: number = 8;
  static readonly AVATAR_SIZE: number = 48;
  static readonly AVATAR_SMALL: number = 36;
  static readonly ICON_BUTTON_SIZE: number = 44;
  static readonly CONTROL_HEIGHT: number = 44;
  static readonly DRAWER_WIDTH: number = 288;
  static readonly DRAWER_EDGE_WIDTH: number = 56;
  static readonly FAB_SIZE: number = 52;
  static readonly REPLY_BAR_HEIGHT: number = 60;
  static readonly BOTTOM_TAB_BAR_HEIGHT: number = 56;
  static readonly BOTTOM_TAB_BAR_WIDTH: number = 288;
  static readonly BOTTOM_TAB_ITEM_WIDTH: number = 72;
  static readonly BOTTOM_TAB_INDICATOR_WIDTH: number = 64;
  static readonly BOTTOM_TAB_BAR_HORIZONTAL_MARGIN: number = 28;
  static readonly BOTTOM_TAB_BAR_BOTTOM_MARGIN: number = 4;
  static readonly BOTTOM_TAB_BAR_RADIUS: number = 31;
  static readonly BOTTOM_TAB_BAR_CONTENT_INSET: number = 94;
  static readonly MEDIA_MAX_HEIGHT: number = 520;
  static readonly SKELETON_TITLE_HEIGHT: number = 16;
  static readonly SKELETON_META_HEIGHT: number = 12;
  static readonly MESSAGE_MAX_WIDTH: number = 320;
}

export class Breakpoints {
  static readonly TABLET_TWO_COLUMN_MIN: number = 900;
  static readonly TABLET_MASTER_PANE: number = 360;
}

export enum ComponentState {
  Enabled = 'Enabled',
  Pressed = 'Pressed',
  Selected = 'Selected',
  Disabled = 'Disabled',
  Loading = 'Loading'
}
