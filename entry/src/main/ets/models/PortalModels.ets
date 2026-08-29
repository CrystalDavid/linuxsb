export interface PortalOption {
  label: string;
  value: string;
  title?: string;
  rarity?: string;
}

export interface PortalField {
  name: string;
  value: string;
  type: string;
  placeholder: string;
  options: PortalOption[];
}

export interface PortalLink {
  label: string;
  path: string;
}

export interface PortalAction {
  actionUrl: string;
  label: string;
  context: string;
  disabled: boolean;
  fields: PortalField[];
}

export interface PortalBadge {
  label: string;
  rarity: string;
}

// One selectable title on the forge / recycle centers: the checkbox carries the
// title id and max quantity while the surrounding card provides the display text.
export interface PortalMaterial {
  titleId: string;
  icon: string;
  name: string;
  rarity: string;
  description: string;
  ownedText: string;
  maxQuantity: number;
  checkboxName: string;
  rarityKey: string;
}

export interface PortalCard {
  kind: string;
  key: string;
  lines: string[];
  actionIndexes: number[];
  links: PortalLink[];
  imageUrl?: string;
}

export interface PortalDocument {
  path: string;
  title: string;
  lines: string[];
  actions: PortalAction[];
  links: PortalLink[];
  cards: PortalCard[];
  badges: PortalBadge[];
  materials?: PortalMaterial[];
  subStats?: string;
}

export interface PortalLoadResult {
  ok: boolean;
  message: string;
  document?: PortalDocument;
}

export interface PortalActionResult {
  ok: boolean;
  message: string;
  authExpired?: boolean;
  // The request may have reached the server while its response stream was
  // interrupted. Callers must reload and verify state instead of retrying a
  // non-idempotent write automatically.
  uncertain?: boolean;
}
