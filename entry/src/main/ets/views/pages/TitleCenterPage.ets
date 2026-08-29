import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  buildImmersiveGlassEffect,
  buildImmersiveSystemMaterialModifier,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';
import { GLASS_STYLE_STORAGE_KEY, GlassStyleMode } from '../../common/ui/GlassStyleParams';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import {
  PortalAction, PortalActionResult, PortalBadge, PortalCard, PortalDocument, PortalField, PortalLoadResult,
  PortalMaterial, PortalOption
} from '../../models/PortalModels';
import { ArrayDataSource } from '../../models/presentation/ArrayDataSource';
import { AccountLoginGate } from '../components/AccountLoginGate';
import { ImmersiveGlassTextButton } from '../components/ImmersiveGlassTextButton';

const TITLE_SECTION_PATHS: string[] = [
  '/gacha_profile', '/gacha', '/gacha_forge_center', '/gacha_recycle_center', '/gacha_recipes', '/gacha_market'
];
const TITLE_SECTION_LABELS: string[] = ['我的称号', '称号抽取', '称号熔炼', '称号回收', 'UR 合成', '称号交易'];
const MARKET_SECTION_PATHS: string[] = ['/gacha_market', '/gacha_market_mine', '/gacha_market_orders'];
const MARKET_SECTION_LABELS: string[] = ['在售交易', '发布交易', '我的交易'];
const MARKET_RARITY_VALUES: string[] = ['', 'ur', 'ssr', 'sr', 'r', 'n'];
const MARKET_RARITY_LABELS: string[] = ['全部', 'UR', 'SSR', 'SR', 'R', 'N'];
const MARKET_PAGE_SIZE: number = 24;

const FORGE_RARITY_KEYS: string[] = ['n', 'r', 'sr'];
const FORGE_SOURCE_LABELS: string[] = ['N', 'R', 'SR'];
const FORGE_TARGET_LABELS: string[] = ['R', 'SR', 'SSR'];

const MY_TITLE_CARD_HEIGHT: number = 152;
const MATERIAL_CARD_HEIGHT: number = 152;
const MARKET_CARD_HEIGHT: number = 152;
const BADGE_CELL_HEIGHT: number = 66;
const MARKET_DURATION_OPTION_HEIGHT: number = 42;

interface MarketOrderRecord {
  key: string;
  description: string;
  reference: string;
  points: string;
}

@CustomDialog
struct TitleGiftDialog {
  controller?: CustomDialogController;
  titleName: string = '';
  onConfirm: (username: string) => void = () => {};
  @State private username: string = '';

  build() {
    Column({ space: Spacing.MD }) {
      Text(`赠送 ${this.titleName}`)
        .fontSize(Typography.TOPIC_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
      Text('该操作会真实提交到 linux.sb，赠送后不可撤销。')
        .fontSize(Typography.CAPTION)
        .fontColor(SemanticColors.textSecondary())
        .width('100%')
      TextInput({ text: this.username, placeholder: '输入接收者用户名' })
        .height(44)
        .fontSize(Typography.BODY)
        .fontColor(SemanticColors.textPrimary())
        .backgroundColor(SemanticColors.surface())
        .border({ width: 1, color: SemanticColors.outline() })
        .borderRadius(Radius.MD)
        .onChange((value: string) => { this.username = value; })
      Row({ space: Spacing.MD }) {
        Button('取消', { type: ButtonType.Capsule, stateEffect: true })
          .layoutWeight(1)
          .height(40)
          .fontSize(Typography.BODY)
          .fontColor(SemanticColors.textSecondary())
          .backgroundColor(SemanticColors.surfaceMuted())
          .onClick(() => this.controller?.close())
        Button('确认赠送', { type: ButtonType.Capsule, stateEffect: true })
          .layoutWeight(1)
          .height(40)
          .fontSize(Typography.BODY)
          .fontColor(this.username.trim().length > 0 ? $r('app.color.brand_primary') : SemanticColors.disabled())
          .backgroundColor($r('app.color.brand_soft'))
          .enabled(this.username.trim().length > 0)
          .onClick(() => {
            this.controller?.close();
            this.onConfirm(this.username.trim());
          })
      }
      .width('100%')
    }
    .width(320)
    .padding(Spacing.LG)
    .backgroundColor(SemanticColors.surfaceElevated())
    .borderRadius(Radius.LG)
  }
}

@Component({ freezeWhenInactive: true })
export struct TitleCenterPage {
  @Prop @Watch('onAuthenticatedChanged') authenticated: boolean = false;
  bottomContentInset: number = PageMetrics.BOTTOM_TAB_BAR_CONTENT_INSET;
  onLogin: () => void = () => {};
  onLoad: (path: string) => Promise<PortalLoadResult> = async () => ({ ok: false, message: '称号服务不可用' });
  onSubmit: (action: PortalAction, overrides?: Record<string, string | number | boolean | string[]>) =>
    Promise<PortalActionResult> = async () => ({ ok: false, message: '称号操作不可用' });
  @State private sectionIndex: number = 0;
  @State private loading: boolean = false;
  @State private errorMessage: string = '';
  @State private document: PortalDocument | undefined = undefined;
  @State private marketSectionIndex: number = 0;
  @State private marketQuery: string = '';
  @State private marketRarity: string = '';
  @State private marketPage: number = 1;
  @State private materialQuantities: Record<string, number> = {};
  @State private marketQuantities: Record<string, number> = {};
  @State private marketPublishedDocument: PortalDocument | undefined = undefined;
  @State private marketPublishTitleId: string = '';
  @State private marketPublishQuantity: string = '1';
  @State private marketPublishUnitPrice: string = '10';
  @State private marketPublishDuration: string = '24';
  @State private showMarketDurationMenu: boolean = false;
  @StorageProp(GLASS_STYLE_STORAGE_KEY) private glassStyle: GlassStyleMode = GlassStyleMode.Translucent;
  private giftDialogController: CustomDialogController | undefined = undefined;
  private pendingReload: boolean = false;
  private lastMarketListTapAt: number = 0;
  private ownedTitleDataSource: ArrayDataSource<PortalCard> = new ArrayDataSource<PortalCard>();
  private badgeDataSource: ArrayDataSource<PortalBadge> = new ArrayDataSource<PortalBadge>();
  private marketListingDataSource: ArrayDataSource<PortalCard> = new ArrayDataSource<PortalCard>();

  aboutToAppear(): void {
    if (this.authenticated) {
      this.load();
    }
  }

  private onAuthenticatedChanged(): void {
    if (this.authenticated) {
      this.load();
    } else {
      this.document = undefined;
      this.errorMessage = '';
      this.materialQuantities = {};
      this.resetLazyDataSources();
    }
  }

  private async selectSection(index: number): Promise<void> {
    if (index === this.sectionIndex && this.document !== undefined) {
      return;
    }
    this.sectionIndex = index;
    this.document = undefined;
    this.resetLazyDataSources();
    this.materialQuantities = {};
    this.showMarketDurationMenu = false;
    if (index !== 5) {
      this.marketSectionIndex = 0;
      this.marketPage = 1;
    }
    await this.load();
  }

  private async swipeSection(deltaX: number): Promise<void> {
    if (Math.abs(deltaX) < 48) {
      return;
    }
    const next = deltaX < 0 ? Math.min(TITLE_SECTION_PATHS.length - 1, this.sectionIndex + 1) :
      Math.max(0, this.sectionIndex - 1);
    await this.selectSection(next);
  }

  private async selectMarketSection(index: number): Promise<void> {
    if (index === this.marketSectionIndex && this.document !== undefined) {
      return;
    }
    this.marketSectionIndex = index;
    this.document = undefined;
    this.resetLazyDataSources();
    this.marketPublishedDocument = undefined;
    this.showMarketDurationMenu = false;
    this.marketPage = 1;
    await this.load();
  }

  private async handleMarketSectionTap(index: number): Promise<void> {
    const now = Date.now();
    const doubleTappedMarketList = index === 0 && this.marketSectionIndex === 0 &&
      now - this.lastMarketListTapAt <= 450;
    this.lastMarketListTapAt = index === 0 ? now : 0;
    if (doubleTappedMarketList) {
      if (!this.loading) {
        await this.load();
        if (this.document !== undefined && this.errorMessage.length === 0) {
          try {
            this.getUIContext().getPromptAction().showToast({ message: '在售交易已刷新', duration: 1200 });
          } catch (_) {}
        }
      }
      return;
    }
    await this.selectMarketSection(index);
  }

  private resetLazyDataSources(): void {
    this.ownedTitleDataSource.reset([]);
    this.badgeDataSource.reset([]);
    this.marketListingDataSource.reset([]);
  }

  private syncLazyDataSources(path: string, document: PortalDocument): void {
    this.ownedTitleDataSource.reset(path === '/gacha_profile' ? this.ownedCards(document) : []);
    this.badgeDataSource.reset(path === '/gacha' ? document.badges : []);
    this.marketListingDataSource.reset(path.startsWith('/gacha_market?') ? this.marketCards(document) : []);
  }

  private marketPath(): string {
    if (this.marketSectionIndex !== 0) {
      return MARKET_SECTION_PATHS[this.marketSectionIndex];
    }
    const params: string[] = [`p=${this.marketPage}`];
    const query = this.marketQuery.trim();
    if (query.length > 0) {
      params.push(`q=${encodeURIComponent(query)}`);
    }
    if (this.marketRarity.length > 0) {
      params.push(`rarity=${this.marketRarity}`);
    }
    return `/gacha_market?${params.join('&')}`;
  }

  private currentPath(): string {
    return this.sectionIndex === 5 ? this.marketPath() : TITLE_SECTION_PATHS[this.sectionIndex];
  }

  private async load(): Promise<void> {
    if (!this.authenticated) {
      console.info(`[TitleCenter] load skipped auth=${this.authenticated} loading=${this.loading}`);
      return;
    }
    if (this.loading) {
      this.pendingReload = true;
      console.info(`[TitleCenter] load queued ${this.currentPath()}`);
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    const path = this.currentPath();
    console.info(`[TitleCenter] load start ${path}`);
    try {
      const result = await this.onLoad(path);
      let publishedDocument: PortalDocument | undefined = undefined;
      if (path === '/gacha_market_orders') {
        const publishedResult = await this.onLoad('/gacha_market_mine');
        if (publishedResult.ok) {
          publishedDocument = publishedResult.document;
        }
      }
      let cardKinds = '';
      if (result.document !== undefined) {
        for (let cardIndex = 0; cardIndex < result.document.cards.length; cardIndex++) {
          cardKinds = cardKinds.length === 0 ? result.document.cards[cardIndex].kind :
            `${cardKinds},${result.document.cards[cardIndex].kind}`;
        }
      }
      console.info(`[TitleCenter] load done ${path} ok=${result.ok} msg=${result.message} cards=${result.document?.cards.length ?? -1} kinds=${cardKinds} actions=${result.document?.actions.length ?? -1} materials=${result.document?.materials?.length ?? -1} badges=${result.document?.badges.length ?? -1} sub=${result.document?.subStats ?? ''}`);
      if (!result.ok || result.document === undefined) {
        if (path === this.currentPath()) {
          this.document = undefined;
          this.resetLazyDataSources();
          this.errorMessage = result.message;
        }
        return;
      }
      if (path === this.currentPath()) {
        this.document = result.document;
        this.marketPublishedDocument = publishedDocument;
        this.syncLazyDataSources(path, result.document);
        if (path === '/gacha_market_mine') {
          this.hydrateMarketPublish(result.document);
        }
      }
    } catch (error) {
      console.error(`[TitleCenter] load threw ${path} ${JSON.stringify(error)}`);
      if (path === this.currentPath()) {
        this.document = undefined;
        this.errorMessage = '页面加载失败';
      }
    } finally {
      this.loading = false;
      if (this.pendingReload || path !== this.currentPath()) {
        this.pendingReload = false;
        this.load();
      }
    }
  }

  private requestAction(action: PortalAction, context: string = '',
    overrides?: Record<string, string | number | boolean | string[]>): void {
    if (action.disabled) {
      return;
    }
    const isPull = action.actionUrl === '/gacha_pull' || action.actionUrl === '/gacha_pull_10';
    const detail = context.length > 0 ? context : (isPull ? '' : action.context);
    AlertDialog.show({
      title: `确认${action.label}`,
      message: `该操作会真实提交到 linux.sb。${detail.length > 0 ? `\n${detail}` : ''}`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确认提交',
        fontColor: $r('app.color.brand_primary'),
        action: () => { this.submit(action, overrides); }
      }
    });
  }

  private async submit(action: PortalAction,
    overrides?: Record<string, string | number | boolean | string[]>): Promise<void> {
    if (this.loading) {
      return;
    }
    const isPull = action.actionUrl === '/gacha_pull' || action.actionUrl === '/gacha_pull_10';
    const beforeStats = isPull && this.document !== undefined ? this.subStatNumbers(this.document) : [];
    const beforeSignature = JSON.stringify({
      document: this.document,
      published: this.marketPublishedDocument
    });
    this.loading = true;
    const result = await this.onSubmit(action, overrides);
    this.loading = false;
    let message = result.message;
    if (result.ok || result.uncertain === true) {
      this.materialQuantities = {};
      // Drop the previous document before reloading so ArkUI cannot reuse the
      // old object tree after a write whose network acknowledgement was lost.
      this.document = undefined;
      await this.load();
      if (!result.ok && result.uncertain === true) {
        const afterSignature = JSON.stringify({
          document: this.document,
          published: this.marketPublishedDocument
        });
        if (beforeSignature.length > 0 && afterSignature.length > 0 && beforeSignature !== afterSignature) {
          message = `${action.label}已完成，已同步服务器状态`;
        } else {
          message = '网络回执中断，服务器状态未变化，请稍后手动刷新后再试';
        }
      }
      if (isPull && this.document !== undefined) {
        const afterStats = this.subStatNumbers(this.document);
        if (beforeStats.length >= 3 && afterStats.length >= 3) {
          const titleChange = beforeStats[1] === afterStats[1] ? '称号种类未增加' :
            `称号种类 ${beforeStats[1]} → ${afterStats[1]}`;
          message = `抽取完成：积分 ${beforeStats[0]} → ${afterStats[0]}，${titleChange}`;
        }
      }
    }
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2200 });
    } catch (_) {}
  }

  // ---------- shared helpers ----------

  private rarityAccent(rarity: string): ResourceColor {
    switch (rarity.toUpperCase()) {
      case 'UR':
        return $r('app.color.gacha_rarity_ur');
      case 'SSR':
        return $r('app.color.gacha_rarity_ssr');
      case 'SR':
        return $r('app.color.gacha_rarity_sr');
      case 'R':
        return $r('app.color.gacha_rarity_r');
      default:
        return $r('app.color.gacha_rarity_n');
    }
  }

  private raritySoft(rarity: string): ResourceColor {
    switch (rarity.toUpperCase()) {
      case 'UR':
        return $r('app.color.gacha_rarity_ur_soft');
      case 'SSR':
        return $r('app.color.gacha_rarity_ssr_soft');
      case 'SR':
        return $r('app.color.gacha_rarity_sr_soft');
      case 'R':
        return $r('app.color.gacha_rarity_r_soft');
      default:
        return $r('app.color.gacha_rarity_n_soft');
    }
  }

  private cardActions(document: PortalDocument, card: PortalCard): PortalAction[] {
    const output: PortalAction[] = [];
    for (let index = 0; index < card.actionIndexes.length; index++) {
      const actionIndex = card.actionIndexes[index];
      if (actionIndex >= 0 && actionIndex < document.actions.length) {
        output.push(document.actions[actionIndex]);
      }
    }
    return output;
  }

  private findCardAction(document: PortalDocument, card: PortalCard, actionUrl: string): PortalAction | undefined {
    const actions = this.cardActions(document, card);
    for (let index = 0; index < actions.length; index++) {
      if (actions[index].actionUrl === actionUrl) {
        return actions[index];
      }
    }
    return undefined;
  }

  private materials(document: PortalDocument, checkboxName: string): PortalMaterial[] {
    const source = document.materials ?? [];
    const output: PortalMaterial[] = [];
    for (let index = 0; index < source.length; index++) {
      if (source[index].checkboxName === checkboxName) {
        output.push(source[index]);
      }
    }
    return output;
  }

  private hiddenFieldValue(action: PortalAction, name: string): string {
    for (let index = 0; index < action.fields.length; index++) {
      if (action.fields[index].name === name) {
        return action.fields[index].value;
      }
    }
    return '';
  }

  private selectedQuantity(rarityKey: string): number {
    const document = this.document;
    if (document === undefined) {
      return 0;
    }
    let total = 0;
    const materials = this.materials(document, 'material_title_ids[]');
    for (let index = 0; index < materials.length; index++) {
      if (materials[index].rarityKey === rarityKey) {
        total += this.materialQuantities[materials[index].titleId] ?? 0;
      }
    }
    return total;
  }

  private setMaterialQuantity(titleId: string, quantity: number): void {
    const next: Record<string, number> = {};
    const keys = Object.keys(this.materialQuantities);
    for (let index = 0; index < keys.length; index++) {
      if (keys[index] !== titleId) {
        next[keys[index]] = this.materialQuantities[keys[index]];
      }
    }
    if (quantity > 0) {
      next[titleId] = quantity;
    }
    this.materialQuantities = next;
  }

  private setMarketQuantity(key: string, quantity: number): void {
    const next: Record<string, number> = {};
    const keys = Object.keys(this.marketQuantities);
    for (let index = 0; index < keys.length; index++) {
      next[keys[index]] = this.marketQuantities[keys[index]];
    }
    next[key] = quantity;
    this.marketQuantities = next;
  }

  private subStatNumbers(document: PortalDocument): number[] {
    const text = document.subStats ?? '';
    const output: number[] = [];
    let current = '';
    for (let index = 0; index < text.length; index++) {
      const ch = text.charAt(index);
      if (ch >= '0' && ch <= '9') {
        current += ch;
      } else if (current.length > 0) {
        output.push(Number(current));
        current = '';
      }
    }
    if (current.length > 0) {
      output.push(Number(current));
    }
    return output;
  }

  // ---------- shared builders ----------

  @Builder
  private titleBar() {
    Row() {
      Text('称号')
        .id('titles-page-title')
        .fontSize(Typography.ROOT_PAGE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
    }
    .width('100%').height('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private sectionTabs() {
    Scroll() {
      Row({ space: Spacing.SM }) {
        ForEach(TITLE_SECTION_LABELS, (label: string, index: number) => {
          Button(label, { type: ButtonType.Capsule, stateEffect: false })
            .id(`title-section-${index}`)
            .height(38)
            .padding({ left: Spacing.LG, right: Spacing.LG })
            .fontSize(Typography.LABEL)
            .fontWeight(this.sectionIndex === index ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(this.sectionIndex === index ? SemanticColors.page() : SemanticColors.textPrimary())
            .backgroundColor(this.sectionIndex === index ? SemanticColors.textPrimary() : Color.Transparent)
            .backgroundEffect(this.sectionIndex === index ? undefined : buildImmersiveGlassEffect(this.glassStyle))
            .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
            .hoverEffect(HoverEffect.None)
            .onClick(() => this.selectSection(index))
        }, (label: string, index: number) => `${index}-${label}`)
      }
      .padding({ left: Spacing.MD, right: Spacing.MD })
    }
    .width('100%')
    .height(44)
    .margin({ top: Spacing.XS })
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  private rarityBadge(icon: string, name: string, rarity: string) {
    Row({ space: Spacing.XXS }) {
      if (icon.length > 0) {
        Text(icon).fontSize(Typography.BODY_SMALL)
      }
      Text(name)
        .fontSize(Typography.BODY_SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.rarityAccent(rarity))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (rarity.length > 0) {
        Text(rarity)
          .fontSize(Typography.MICRO)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.rarityAccent(rarity))
      }
    }
    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
    .backgroundColor(this.raritySoft(rarity))
    .borderRadius(Radius.PILL)
  }

  @Builder
  private emptyState(text: string) {
    Column() {
      Text(text)
        .fontSize(Typography.BODY)
        .fontColor(SemanticColors.textTertiary())
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(120)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.settings_group_bg'))
    .borderRadius(Radius.LG)
  }

  @Builder
  private quantityStepper(value: number, max: number, enabled: boolean, onChange: (next: number) => void) {
    Row({ space: Spacing.XS }) {
      Button('−', { type: ButtonType.Circle, stateEffect: enabled })
        .width(26).height(26)
        .fontSize(Typography.BODY_SMALL)
        .fontColor(enabled && value > 1 ? SemanticColors.textPrimary() : SemanticColors.disabled())
        .backgroundColor(SemanticColors.surfaceMuted())
        .enabled(enabled && value > 1)
        .onClick(() => onChange(value - 1))
      Text(`${value}`)
        .fontSize(Typography.BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(enabled ? SemanticColors.textPrimary() : SemanticColors.disabled())
        .width(30)
        .textAlign(TextAlign.Center)
      Button('＋', { type: ButtonType.Circle, stateEffect: enabled })
        .width(26).height(26)
        .fontSize(Typography.BODY_SMALL)
        .fontColor(enabled && value < max ? SemanticColors.textPrimary() : SemanticColors.disabled())
        .backgroundColor(SemanticColors.surfaceMuted())
        .enabled(enabled && value < max)
        .onClick(() => onChange(value + 1))
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private compactQuantityStepper(value: number, max: number, onChange: (next: number) => void) {
    Row({ space: Spacing.XXS }) {
      Button('−', { type: ButtonType.Circle, stateEffect: value > 1 })
        .width(22).height(22)
        .fontSize(Typography.CAPTION)
        .fontColor(value > 1 ? SemanticColors.textPrimary() : SemanticColors.disabled())
        .backgroundColor(Color.Transparent)
        .enabled(value > 1)
        .onClick(() => onChange(value - 1))
      Text(`${value}`)
        .width(22)
        .fontSize(Typography.BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.textPrimary())
        .textAlign(TextAlign.Center)
      Button('＋', { type: ButtonType.Circle, stateEffect: value < max })
        .width(22).height(22)
        .fontSize(Typography.CAPTION)
        .fontColor(value < max ? SemanticColors.textPrimary() : SemanticColors.disabled())
        .backgroundColor(Color.Transparent)
        .enabled(value < max)
        .onClick(() => onChange(value + 1))
    }
    .alignItems(VerticalAlign.Center)
  }

  // ---------- 我的称号 ----------

  private ownedCards(document: PortalDocument): PortalCard[] {
    return document.cards.filter((card: PortalCard) => card.kind === 'title-owned');
  }

  private ownedCardLine(card: PortalCard, index: number): string {
    return index < card.lines.length ? card.lines[index] : '';
  }

  private openGiftDialog(action: PortalAction, titleName: string): void {
    this.giftDialogController = new CustomDialogController({
      builder: TitleGiftDialog({
        titleName: titleName,
        onConfirm: (username: string) => {
          for (let index = 0; index < action.fields.length; index++) {
            if (action.fields[index].name === 'username') {
              action.fields[index].value = username;
            }
          }
          this.submit(action);
        }
      }),
      autoCancel: true,
      customStyle: true
    });
    this.giftDialogController.open();
  }

  @Builder
  private ownedTitleCard(document: PortalDocument, card: PortalCard, index: number) {
    Column({ space: Spacing.SM }) {
      this.rarityBadge(this.ownedCardLine(card, 0), this.ownedCardLine(card, 1), this.ownedCardLine(card, 2))
      Text(this.ownedCardLine(card, 3))
        .fontSize(Typography.BODY)
        .fontColor(SemanticColors.textSecondary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(`${this.ownedCardLine(card, 4)} · ${this.ownedCardLine(card, 5)}`)
        .fontSize(Typography.MICRO)
        .fontColor(SemanticColors.textTertiary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      Row({ space: Spacing.SM }) {
        if (this.findCardAction(document, card, '/gacha_equip') !== undefined) {
          Button('装备', { type: ButtonType.Capsule, stateEffect: true })
            .id(`title-equip-${index}`)
            .layoutWeight(1)
            .height(34)
            .fontSize(Typography.METADATA)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.brand_soft'))
            .onClick(() => {
              const action = this.findCardAction(document, card, '/gacha_equip');
              if (action !== undefined) {
                this.requestAction(action, `装备「${this.ownedCardLine(card, 1)}」`);
              }
            })
        } else {
          Text('已装备')
            .layoutWeight(1)
            .height(34)
            .fontSize(Typography.METADATA)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textTertiary())
            .textAlign(TextAlign.Center)
            .backgroundColor(SemanticColors.surfaceMuted())
            .borderRadius(Radius.PILL)
        }
        Button('赠送', { type: ButtonType.Capsule, stateEffect: true })
          .id(`title-gift-${index}`)
          .layoutWeight(1)
          .height(34)
          .fontSize(Typography.METADATA)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.textPrimary())
          .backgroundColor(SemanticColors.surface())
          .border({ width: 1, color: SemanticColors.outline() })
          .onClick(() => {
            const action = this.findCardAction(document, card, '/gacha_gift');
            if (action !== undefined) {
              this.openGiftDialog(action, this.ownedCardLine(card, 1));
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .height(MY_TITLE_CARD_HEIGHT)
    .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.LG, bottom: Spacing.MD })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.gacha_rarity_n_soft'))
    .border({ width: 1, color: SemanticColors.outline() })
    .borderRadius(20)
  }

  @Builder
  private myTitlesSection(document: PortalDocument) {
    Scroll() {
      Column({ space: Spacing.MD }) {
        if (this.ownedCards(document).length === 0) {
          this.emptyState('还没有称号，去称号抽取试试手气吧')
        } else {
          Grid() {
            LazyForEach(this.ownedTitleDataSource, (card: PortalCard, index: number) => {
              GridItem() { this.ownedTitleCard(document, card, index) }
            }, (card: PortalCard, index: number) => `${card.key}-${index}`)
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(Spacing.SM)
          .rowsGap(Spacing.SM)
          .width('100%')
          .height(Math.ceil(this.ownedTitleDataSource.totalCount() / 2) *
            (MY_TITLE_CARD_HEIGHT + Spacing.SM) - Spacing.SM)
          .scrollBar(BarState.Off)
        }
        Column().height(this.bottomContentInset)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: Spacing.LG, right: Spacing.LG })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .id('title-my-content')
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 18 })
      .onActionEnd((event: GestureEvent) => this.swipeSection(event.offsetX)))
  }

  // ---------- 称号抽取 ----------

  private pullAction(document: PortalDocument, actionUrl: string): PortalAction | undefined {
    for (let index = 0; index < document.actions.length; index++) {
      if (document.actions[index].actionUrl === actionUrl) {
        return document.actions[index];
      }
    }
    return undefined;
  }

  @Builder
  private gachaSection(document: PortalDocument) {
    Scroll() {
      Column({ space: Spacing.MD }) {
        Row({ space: Spacing.MD }) {
          Column() {
            ImmersiveGlassTextButton({
              label: this.pullAction(document, '/gacha_pull')?.label ?? '抽一次',
              semanticId: 'gacha-pull-1',
              actionEnabled: this.pullAction(document, '/gacha_pull') !== undefined &&
                !(this.pullAction(document, '/gacha_pull') as PortalAction).disabled,
              controlHeight: 48,
              horizontalPadding: Spacing.XL,
              labelFontSize: Typography.BODY,
              onAction: () => {
                const action = this.pullAction(document, '/gacha_pull');
                if (action !== undefined) {
                  this.requestAction(action);
                }
              }
            })
          }
          .layoutWeight(1)
          Column() {
            ImmersiveGlassTextButton({
              label: this.pullAction(document, '/gacha_pull_10')?.label ?? '十连抽',
              semanticId: 'gacha-pull-10',
              actionEnabled: this.pullAction(document, '/gacha_pull_10') !== undefined &&
                !(this.pullAction(document, '/gacha_pull_10') as PortalAction).disabled,
              controlHeight: 48,
              horizontalPadding: Spacing.XL,
              labelFontSize: Typography.BODY,
              onAction: () => {
                const action = this.pullAction(document, '/gacha_pull_10');
                if (action !== undefined) {
                  this.requestAction(action);
                }
              }
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
        Row({ space: Spacing.SM }) {
          Text('积分：')
            .fontSize(Typography.METADATA)
            .fontColor(SemanticColors.textSecondary())
          Text(`${this.subStatNumbers(document).length > 0 ? this.subStatNumbers(document)[0] : '-'}`)
            .fontSize(Typography.BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.textPrimary())
          Text('｜')
            .fontSize(Typography.METADATA)
            .fontColor(SemanticColors.textTertiary())
          Text('称号：')
            .fontSize(Typography.METADATA)
            .fontColor(SemanticColors.textSecondary())
          Text(this.subStatNumbers(document).length > 2 ?
            `${this.subStatNumbers(document)[1]} / ${this.subStatNumbers(document)[2]}` : '-')
            .fontSize(Typography.BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.textPrimary())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        Text(`全部称号（${document.badges.length} / 22）`)
          .fontSize(Typography.SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.textPrimary())
          .width('100%')
        this.badgeGrid(document.badges.length)
        Column().height(this.bottomContentInset)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: Spacing.LG, right: Spacing.LG })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .id('title-gacha-content')
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 18 })
      .onActionEnd((event: GestureEvent) => this.swipeSection(event.offsetX)))
  }

  @Builder
  private badgeGrid(badgeCount: number) {
    if (badgeCount > 0) {
      Grid() {
        LazyForEach(this.badgeDataSource, (badge: PortalBadge, index: number) => {
          GridItem() {
            Column({ space: Spacing.XXS }) {
              Text(badge.label.substring(0, badge.label.length - badge.rarity.length).trim())
                .fontSize(Typography.METADATA)
                .fontWeight(FontWeight.Medium)
                .fontColor(SemanticColors.textPrimary())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (badge.rarity.length > 0) {
                Text(badge.rarity)
                  .fontSize(Typography.MICRO)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.rarityAccent(badge.rarity))
              }
            }
            .width('100%').height(BADGE_CELL_HEIGHT - Spacing.SM)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.raritySoft(badge.rarity))
            .borderRadius(Radius.MD)
          }
        }, (badge: PortalBadge, index: number) => `${index}-${badge.label}`)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(Spacing.SM)
      .rowsGap(Spacing.SM)
      .width('100%')
      .height(Math.ceil(badgeCount / 3) * BADGE_CELL_HEIGHT - Spacing.SM)
      .scrollBar(BarState.Off)
    }
  }

  // ---------- 称号熔炼 ----------

  private forgeAction(document: PortalDocument, rarityKey: string): PortalAction | undefined {
    for (let index = 0; index < document.actions.length; index++) {
      const action = document.actions[index];
      if (action.actionUrl === '/gacha_forge' && this.hiddenFieldValue(action, 'source_rarity') === rarityKey) {
        return action;
      }
    }
    return undefined;
  }

  private forgeCost(document: PortalDocument, rarityKey: string): number {
    const action = this.forgeAction(document, rarityKey);
    if (action === undefined) {
      return 1;
    }
    const cost = Number(this.hiddenFieldValue(action, '_client_forge_cost'));
    return Number.isFinite(cost) && cost > 0 ? Math.floor(cost) : 1;
  }

  private requestForge(rarityKey: string, cost: number): void {
    const document = this.document;
    if (document === undefined) {
      return;
    }
    const action = this.forgeAction(document, rarityKey);
    if (action === undefined) {
      return;
    }
    const rarityIndex = FORGE_RARITY_KEYS.indexOf(rarityKey);
    const source = rarityIndex >= 0 ? FORGE_SOURCE_LABELS[rarityIndex] : rarityKey.toUpperCase();
    const target = rarityIndex >= 0 ? FORGE_TARGET_LABELS[rarityIndex] : '';
    const selected = this.selectedQuantity(rarityKey);
    const forgeCount = Math.floor(selected / cost);
    if (forgeCount < 1) {
      return;
    }
    const ids: string[] = [];
    const overrides: Record<string, string | number | boolean | string[]> = {};
    const materials = this.materials(document, 'material_title_ids[]');
    for (let index = 0; index < materials.length; index++) {
      const material = materials[index];
      if (material.rarityKey !== rarityKey) {
        continue;
      }
      const quantity = this.materialQuantities[material.titleId] ?? 0;
      if (quantity > 0) {
        ids.push(material.titleId);
        overrides[`material_quantities[${material.titleId}]`] = quantity;
      }
    }
    overrides['material_title_ids[]'] = ids;
    overrides['forge_count'] = forgeCount;
    action.label = '熔炼';
    this.requestAction(action, `消耗 ${forgeCount * cost} 个 ${source}，产生 ${forgeCount} 个 ${target}`, overrides);
  }

  @Builder
  private forgePanel(document: PortalDocument) {
    Row({ space: Spacing.XXS }) {
      ForEach(FORGE_RARITY_KEYS, (rarityKey: string, index: number) => {
        Column({ space: Spacing.XXS }) {
          Text(`${FORGE_SOURCE_LABELS[index]} × ${this.forgeCost(document, rarityKey)} → ${FORGE_TARGET_LABELS[index]}`)
            .fontSize(Typography.CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.textSecondary())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`已选 ${this.selectedQuantity(rarityKey)} 个`)
            .fontSize(Typography.MICRO)
            .fontColor(SemanticColors.textSecondary())
            .maxLines(1)
          Text(`可熔炼 ${Math.floor(this.selectedQuantity(rarityKey) / this.forgeCost(document, rarityKey))} 次`)
            .fontSize(Typography.MICRO)
            .fontColor(SemanticColors.textSecondary())
            .maxLines(1)
          Text(`消耗 ${Math.floor(this.selectedQuantity(rarityKey) / this.forgeCost(document, rarityKey)) *
            this.forgeCost(document, rarityKey)} 个 ${FORGE_SOURCE_LABELS[index]}`)
            .fontSize(Typography.MICRO)
            .fontColor(SemanticColors.textTertiary())
            .maxLines(1)
          Text(`产生 ${Math.floor(this.selectedQuantity(rarityKey) / this.forgeCost(document, rarityKey))} 个 ${FORGE_TARGET_LABELS[index]}`)
            .fontSize(Typography.MICRO)
            .fontColor(SemanticColors.textTertiary())
            .maxLines(1)
          Button('熔炼', { type: ButtonType.Capsule, stateEffect: true })
            .id(`forge-submit-${rarityKey}`)
            .width('100%')
            .height(28)
            .fontSize(Typography.CAPTION)
            .fontColor(Math.floor(this.selectedQuantity(rarityKey) / this.forgeCost(document, rarityKey)) >= 1 ?
              $r('app.color.brand_primary') : SemanticColors.disabled())
            .backgroundColor($r('app.color.brand_soft'))
            .enabled(Math.floor(this.selectedQuantity(rarityKey) / this.forgeCost(document, rarityKey)) >= 1)
            .onClick(() => this.requestForge(rarityKey, this.forgeCost(document, rarityKey)))
        }
        .layoutWeight(1)
        .padding(Spacing.SM)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.settings_group_bg'))
        .border({ width: 1, color: SemanticColors.outline() })
        .borderRadius(Radius.LG)
      }, (rarityKey: string) => rarityKey)
    }
    .width('100%')
    .height(150)
    .padding({ left: Spacing.SM, right: Spacing.SM })
  }

  @Builder
  private materialCard(material: PortalMaterial, recycleMode: boolean) {
    Column({ space: Spacing.XS }) {
      this.rarityBadge(material.icon, material.name, material.rarity)
      if (material.description.length > 0) {
        Text(material.description)
          .fontSize(Typography.CAPTION)
          .fontColor(SemanticColors.textSecondary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Text(material.ownedText.length > 0 ? material.ownedText : `最多 ${material.maxQuantity} 个`)
        .fontSize(Typography.MICRO)
        .fontColor(SemanticColors.textTertiary())
        .maxLines(1)
      Blank()
      if (recycleMode) {
        Row({ space: Spacing.XS }) {
          this.quantityStepper(this.materialQuantities[material.titleId] ?? 1, material.maxQuantity, true,
            (next: number) => this.setMaterialQuantity(material.titleId, next))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        Button('回收', { type: ButtonType.Capsule, stateEffect: true })
          .id(`recycle-submit-${material.titleId}`)
          .width('100%')
          .height(32)
          .fontSize(Typography.METADATA)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.brand_soft'))
          .onClick(() => this.requestRecycle(material))
      } else {
        Row({ space: Spacing.XS }) {
          Toggle({ type: ToggleType.Switch, isOn: (this.materialQuantities[material.titleId] ?? 0) > 0 })
            .selectedColor($r('app.color.brand_primary'))
            .onChange((selected: boolean) => {
              this.setMaterialQuantity(material.titleId, selected ? material.maxQuantity : 0);
            })
          Text('选择')
            .fontSize(Typography.CAPTION)
            .fontColor(SemanticColors.textSecondary())
          Blank()
          this.quantityStepper(this.materialQuantities[material.titleId] ?? material.maxQuantity,
            material.maxQuantity, (this.materialQuantities[material.titleId] ?? 0) > 0,
            (next: number) => this.setMaterialQuantity(material.titleId, next))
        }
        .width('100%')
        .height(30)
      }
    }
    .width('100%')
    .height(MATERIAL_CARD_HEIGHT)
    .padding(Spacing.SM)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.settings_group_bg'))
    .border({ width: 1, color: SemanticColors.outline() })
    .borderRadius(Radius.LG)
  }

  @Builder
  private forgeSection(document: PortalDocument) {
    Column({ space: Spacing.MD }) {
      this.forgePanel(document)
      Text('选择熔炼材料')
        .fontSize(Typography.SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .width('100%')
        .padding({ left: Spacing.LG, right: Spacing.LG })
      Scroll() {
        Column({ space: Spacing.MD }) {
          if (this.materials(document, 'material_title_ids[]').length === 0) {
            this.emptyState('暂无可熔炼的称号')
          } else {
            Grid() {
              ForEach(this.materials(document, 'material_title_ids[]'), (material: PortalMaterial) => {
                GridItem() { this.materialCard(material, false) }
              }, (material: PortalMaterial) =>
                `${material.titleId}-${this.materialQuantities[material.titleId] ?? 0}`)
            }
            .columnsTemplate('1fr 1fr')
            .columnsGap(Spacing.SM)
            .rowsGap(Spacing.SM)
            .width('100%')
            .height(Math.ceil(this.materials(document, 'material_title_ids[]').length / 2) *
              (MATERIAL_CARD_HEIGHT + Spacing.SM) - Spacing.SM)
            .scrollBar(BarState.Off)
          }
          Column().height(this.bottomContentInset)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ left: Spacing.LG, right: Spacing.LG })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
      }
      .id('title-forge-content')
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 18 })
        .onActionEnd((event: GestureEvent) => this.swipeSection(event.offsetX)))
    }
    .width('100%')
    .layoutWeight(1)
  }

  // ---------- 称号回收 ----------

  private recycleAction(document: PortalDocument): PortalAction | undefined {
    for (let index = 0; index < document.actions.length; index++) {
      if (document.actions[index].actionUrl === '/gacha_recycle') {
        return document.actions[index];
      }
    }
    return undefined;
  }

  private recyclePrice(document: PortalDocument): number {
    const action = this.recycleAction(document);
    const label = action === undefined ? '' : action.label;
    let digits = '';
    for (let index = 0; index < label.length; index++) {
      const ch = label.charAt(index);
      if (ch >= '0' && ch <= '9') {
        digits += ch;
      } else if (digits.length > 0) {
        break;
      }
    }
    const price = Number(digits);
    return Number.isFinite(price) && price > 0 ? price : 0;
  }

  private requestRecycle(material: PortalMaterial): void {
    const document = this.document;
    if (document === undefined) {
      return;
    }
    const action = this.recycleAction(document);
    if (action === undefined) {
      return;
    }
    const quantity = Math.min(material.maxQuantity, Math.max(1, this.materialQuantities[material.titleId] ?? 1));
    const price = this.recyclePrice(document);
    const overrides: Record<string, string | number | boolean | string[]> = {};
    overrides['recycle_title_ids[]'] = [material.titleId];
    overrides[`recycle_quantities[${material.titleId}]`] = quantity;
    const priceText = price > 0 ? `，预计到账 ${price * quantity} 积分` : '';
    this.requestAction(action, `回收 ${quantity} 个「${material.name}」${priceText}，回收后不可恢复`, overrides);
  }

  @Builder
  private recycleSection(document: PortalDocument) {
    Scroll() {
      Column({ space: Spacing.MD }) {
        Row({ space: Spacing.XS }) {
          Text('♻️')
            .fontSize(Typography.BODY)
          Text(this.recyclePrice(document) > 0 ?
            `SSR 回收 · 今日回收价：${this.recyclePrice(document)} 积分 / 个` : 'SSR 回收')
            .fontSize(Typography.METADATA)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textPrimary())
        }
        .width('100%')
        .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.SM, bottom: Spacing.SM })
        .backgroundColor($r('app.color.settings_group_bg'))
        .borderRadius(Radius.LG)
        if (this.materials(document, 'recycle_title_ids[]').length === 0) {
          this.emptyState('暂无可回收的 SSR 称号')
        } else {
          Grid() {
            ForEach(this.materials(document, 'recycle_title_ids[]'), (material: PortalMaterial) => {
              GridItem() { this.materialCard(material, true) }
            }, (material: PortalMaterial) =>
              `${material.titleId}-${this.materialQuantities[material.titleId] ?? 1}`)
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(Spacing.SM)
          .rowsGap(Spacing.SM)
          .width('100%')
          .height(Math.ceil(this.materials(document, 'recycle_title_ids[]').length / 2) *
            (MATERIAL_CARD_HEIGHT + Spacing.SM) - Spacing.SM)
          .scrollBar(BarState.Off)
        }
        Column().height(this.bottomContentInset)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: Spacing.LG, right: Spacing.LG })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .id('title-recycle-content')
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 18 })
      .onActionEnd((event: GestureEvent) => this.swipeSection(event.offsetX)))
  }

  // ---------- UR 合成 ----------

  private recipeMaterials(card: PortalCard): string[] {
    const output: string[] = [];
    for (let index = 4; index < card.lines.length; index++) {
      const line = card.lines[index];
      if (line.indexOf('/') > 0) {
        output.push(line);
      }
    }
    return output;
  }

  private recipeMaterialDone(line: string): boolean {
    const slash = line.lastIndexOf('/');
    if (slash <= 0) {
      return false;
    }
    const have = Number(line.substring(line.lastIndexOf(' ', slash) + 1, slash));
    const need = Number(line.substring(slash + 1));
    return Number.isFinite(have) && Number.isFinite(need) && need > 0 && have >= need;
  }

  @Builder
  private recipeCard(document: PortalDocument, card: PortalCard, index: number) {
    Column({ space: Spacing.SM }) {
      Row() {
        this.rarityBadge(this.ownedCardLine(card, 0), this.ownedCardLine(card, 1), this.ownedCardLine(card, 2))
        Blank()
        Text(this.ownedCardLine(card, 3))
          .fontSize(Typography.TOPIC_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.recipeMaterials(card), (line: string) => {
          Text(line)
            .fontSize(Typography.CAPTION)
            .fontColor(this.recipeMaterialDone(line) ? $r('app.color.brand_primary') :
              SemanticColors.textSecondary())
            .padding({ left: Spacing.SM, right: Spacing.SM, top: Spacing.XXS, bottom: Spacing.XXS })
            .backgroundColor(this.recipeMaterialDone(line) ? $r('app.color.brand_soft') :
              SemanticColors.surfaceMuted())
            .borderRadius(Radius.SM)
            .margin({ right: Spacing.XS, bottom: Spacing.XS })
        }, (line: string) => line)
      }
      .width('100%')
      ForEach(this.cardActions(document, card), (action: PortalAction, actionIndex: number) => {
        Button(action.disabled ? '材料不足' : (action.label.length > 0 ? action.label : '合成'),
          { type: ButtonType.Capsule, stateEffect: !action.disabled })
          .id(`recipe-craft-${index}-${actionIndex}`)
          .width('100%')
          .height(40)
          .fontSize(Typography.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(action.disabled ? SemanticColors.disabled() : $r('app.color.brand_primary'))
          .backgroundColor(action.disabled ? SemanticColors.disabledSurface() : $r('app.color.brand_soft'))
          .enabled(!action.disabled)
          .onClick(() => this.requestAction(action, `合成「${this.ownedCardLine(card, 1)}」`))
      }, (action: PortalAction, actionIndex: number) => `${action.actionUrl}-${actionIndex}`)
    }
    .width('100%')
    .padding(Spacing.MD)
    .backgroundColor($r('app.color.settings_group_bg'))
    .border({ width: 1, color: SemanticColors.outline() })
    .borderRadius(20)
  }

  @Builder
  private recipeSection(document: PortalDocument) {
    Scroll() {
      Column({ space: Spacing.MD }) {
        if (document.cards.filter((card: PortalCard) => card.kind === 'title-recipe').length === 0) {
          this.emptyState('暂无可用配方')
        } else {
          ForEach(document.cards.filter((card: PortalCard) => card.kind === 'title-recipe'),
            (card: PortalCard, index: number) => {
              this.recipeCard(document, card, index)
            }, (card: PortalCard, index: number) => `${card.key}-${index}`)
        }
        Column().height(this.bottomContentInset)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: Spacing.LG, right: Spacing.LG })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .id('title-recipe-content')
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 18 })
      .onActionEnd((event: GestureEvent) => this.swipeSection(event.offsetX)))
  }

  // ---------- 称号交易 ----------

  private marketPublishAction(document: PortalDocument): PortalAction | undefined {
    for (let index = 0; index < document.actions.length; index++) {
      if (document.actions[index].actionUrl === '/gacha_market_publish') {
        return document.actions[index];
      }
    }
    return undefined;
  }

  private actionField(action: PortalAction | undefined, name: string): PortalField | undefined {
    if (action === undefined) {
      return undefined;
    }
    for (let index = 0; index < action.fields.length; index++) {
      if (action.fields[index].name === name) {
        return action.fields[index];
      }
    }
    return undefined;
  }

  private hydrateMarketPublish(document: PortalDocument): void {
    const action = this.marketPublishAction(document);
    const quantityField = this.actionField(action, 'quantity');
    const priceField = this.actionField(action, 'unit_price');
    const durationField = this.actionField(action, 'duration_hours');
    this.marketPublishQuantity = quantityField?.value.length ? quantityField.value : '1';
    this.marketPublishUnitPrice = priceField?.value.length ? priceField.value : '10';
    this.marketPublishDuration = durationField?.value.length ? durationField.value : '24';
  }

  private publishOptionParts(option: PortalOption): string[] {
    const clean = option.label.replace(/（.*$/, '').trim();
    const firstSpace = clean.indexOf(' ');
    if ((option.title ?? '').length > 0) {
      return [firstSpace < 0 ? '🏷️' : clean.substring(0, firstSpace), option.title as string];
    }
    if (firstSpace < 0) {
      return ['🏷️', clean];
    }
    return [clean.substring(0, firstSpace), clean.substring(firstSpace + 1).trim()];
  }

  private publishOptionMax(option: PortalOption | undefined): number {
    if (option === undefined) {
      return 0;
    }
    const match = option.label.match(/可出售\s*(\d+)/);
    const parsed = Number(match?.[1] ?? '0');
    return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 1;
  }

  private selectedPublishOption(action: PortalAction | undefined): PortalOption | undefined {
    const field = this.actionField(action, 'title_id');
    const options = field?.options ?? [];
    for (let index = 0; index < options.length; index++) {
      if (options[index].value === this.marketPublishTitleId) {
        return options[index];
      }
    }
    return undefined;
  }

  private durationLabel(action: PortalAction | undefined): string {
    const field = this.actionField(action, 'duration_hours');
    const options = field?.options ?? [];
    for (let index = 0; index < options.length; index++) {
      if (options[index].value === this.marketPublishDuration) {
        return options[index].label;
      }
    }
    return '请选择有效期';
  }

  private chooseMarketDuration(action: PortalAction): void {
    const options = this.actionField(action, 'duration_hours')?.options ?? [];
    this.showMarketDurationMenu = options.length > 0 && !this.showMarketDurationMenu;
  }

  @Builder
  private marketDurationMenuItem(option: PortalOption) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Row() {
        Text(option.label)
          .fontSize(Typography.BODY)
          .fontColor(SemanticColors.textPrimary())
          .fontWeight(this.marketPublishDuration === option.value ? FontWeight.Medium : FontWeight.Regular)
        Blank()
        if (this.marketPublishDuration === option.value) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(15)
            .fontColor([SemanticColors.textPrimary()])
        }
      }
      .width('100%')
    }
    .id(`market-publish-duration-${option.value}`)
    .width(204)
    .height(42)
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .backgroundColor(Color.Transparent)
    .borderRadius(Radius.MD)
    .hoverEffect(HoverEffect.None)
    .onClick(() => {
      this.marketPublishDuration = option.value;
      this.showMarketDurationMenu = false;
    })
  }

  @Builder
  private marketDurationMenu(action: PortalAction) {
    Column() {
      ForEach(this.actionField(action, 'duration_hours')?.options ?? [], (option: PortalOption) => {
        this.marketDurationMenuItem(option)
      }, (option: PortalOption) => option.value)
    }
    .id('market-publish-duration-menu')
    .width(220)
    .height((this.actionField(action, 'duration_hours')?.options.length ?? 0) * MARKET_DURATION_OPTION_HEIGHT +
      Spacing.XS * 2)
    .padding(Spacing.XS)
    .backgroundEffect(buildImmersiveGlassEffect(this.glassStyle))
    .border({ width: IMMERSIVE_GLASS_BORDER_WIDTH, color: $r('app.color.bottom_tab_bar_highlight') })
    .borderRadius(Radius.LG)
    .shadow({
      radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
      color: $r('app.color.bottom_tab_bar_shadow'),
      offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
    })
    .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
    .clip(true)
    .translate({
      y: -((this.actionField(action, 'duration_hours')?.options.length ?? 0) *
        MARKET_DURATION_OPTION_HEIGHT + Spacing.XS * 2 + Spacing.XS)
    })
    .zIndex(12)
  }

  private canPublishMarket(action: PortalAction | undefined): boolean {
    const quantity = Number(this.marketPublishQuantity);
    const price = Number(this.marketPublishUnitPrice);
    const max = this.publishOptionMax(this.selectedPublishOption(action));
    return action !== undefined && !action.disabled && this.marketPublishTitleId.length > 0 &&
      Number.isFinite(quantity) && quantity >= 1 && quantity <= max &&
      Number.isFinite(price) && price >= 1 && price <= 10000 && this.marketPublishDuration.length > 0;
  }

  private requestMarketPublish(action: PortalAction): void {
    if (!this.canPublishMarket(action)) {
      return;
    }
    const option = this.selectedPublishOption(action);
    const overrides: Record<string, string | number | boolean | string[]> = {};
    overrides['title_id'] = this.marketPublishTitleId;
    overrides['quantity'] = Math.floor(Number(this.marketPublishQuantity));
    overrides['unit_price'] = Math.floor(Number(this.marketPublishUnitPrice));
    overrides['duration_hours'] = this.marketPublishDuration;
    this.requestAction(action,
      `出售「${this.publishOptionParts(option as PortalOption)[1]}」× ${overrides['quantity']}，单价 ${overrides['unit_price']} 积分，有效期 ${this.durationLabel(action)}`,
      overrides);
  }

  private marketCards(document: PortalDocument): PortalCard[] {
    return document.cards.filter((card: PortalCard) => card.kind === 'title-market');
  }

  private marketCardMeta(card: PortalCard, marker: string): string {
    for (let index = 0; index < card.lines.length; index++) {
      if (card.lines[index] === marker) {
        return index + 1 < card.lines.length ? card.lines[index + 1] : '';
      }
      if (card.lines[index].startsWith(`${marker} `)) {
        return card.lines[index].substring(marker.length + 1).trim();
      }
    }
    return '';
  }

  private marketPublishedSummary(card: PortalCard): string {
    const price = this.marketCardMeta(card, '单价');
    return `单价 ${price} 积分`;
  }

  private marketPublishedReference(card: PortalCard): string {
    for (let index = 0; index < card.lines.length; index++) {
      if (card.lines[index].startsWith('#')) {
        return card.lines[index];
      }
    }
    return '';
  }

  private marketPublishedStatus(document: PortalDocument, card: PortalCard): string {
    for (let index = 0; index < card.lines.length; index++) {
      if (card.lines[index] === '在售' || card.lines[index] === '已撤回' || card.lines[index] === '已售出') {
        return card.lines[index];
      }
      if (card.lines[index] === '已售罄' || card.lines[index] === '已成交') {
        return '已售出';
      }
    }
    if (this.cardActions(document, card).length > 0) {
      return '在售';
    }
    for (let index = 0; index < card.lines.length; index++) {
      const soldMatch = card.lines[index].match(/^已售\s*(\d+)\s*\/\s*(\d+)$/);
      if (soldMatch !== null && Number(soldMatch[2]) > 0 && Number(soldMatch[1]) >= Number(soldMatch[2])) {
        return '已售出';
      }
    }
    return '已撤回';
  }

  private marketCardTime(card: PortalCard): string {
    for (let index = 0; index < card.lines.length - 1; index++) {
      if (card.lines[index] === '剩余时间') {
        const values: string[] = [];
        for (let lineIndex = index + 1; lineIndex < card.lines.length; lineIndex++) {
          if (card.lines[lineIndex] === '购买' || card.lines[lineIndex] === '取消交易') {
            break;
          }
          values.push(card.lines[lineIndex]);
        }
        return values.join(' ');
      }
    }
    let reference = '';
    let status = '';
    for (let index = 0; index < card.lines.length; index++) {
      if (card.lines[index].startsWith('#')) {
        reference = card.lines[index];
      } else if (card.lines[index] === '在售' || card.lines[index] === '已撤回' ||
        card.lines[index] === '已售罄') {
        status = card.lines[index];
      }
    }
    return status.length > 0 && reference.length > 0 ? `${reference} · ${status}` : reference;
  }

  private marketCountText(document: PortalDocument): string {
    for (let index = 0; index < document.lines.length; index++) {
      const line = document.lines[index];
      if (line.startsWith('共 ') && line.indexOf('条') > 0) {
        return line;
      }
    }
    return '';
  }

  private requestBuy(document: PortalDocument, card: PortalCard, cardKey: string): void {
    const action = this.findCardAction(document, card, '/gacha_market_buy');
    if (action === undefined) {
      return;
    }
    const remaining = Number(this.marketCardMeta(card, '剩余'));
    const max = Number.isFinite(remaining) && remaining > 0 ? Math.floor(remaining) : 1;
    const quantity = Math.min(max, Math.max(1, this.marketQuantities[cardKey] ?? 1));
    const price = this.marketCardMeta(card, '单价');
    const overrides: Record<string, string | number | boolean | string[]> = {};
    overrides['quantity'] = quantity;
    this.requestAction(action,
      `购买 ${quantity} 个「${this.ownedCardLine(card, 1)}」，单价 ${price} 积分`, overrides);
  }

  @Builder
  private marketControls() {
    Row({ space: Spacing.SM }) {
      ForEach(MARKET_SECTION_LABELS, (label: string, index: number) => {
        Button(label, { type: ButtonType.Capsule, stateEffect: false })
          .id(`title-market-section-${index}`)
          .layoutWeight(1).height(36)
          .fontSize(Typography.CAPTION)
          .fontWeight(this.marketSectionIndex === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.marketSectionIndex === index ? SemanticColors.page() : SemanticColors.textPrimary())
          .backgroundColor(this.marketSectionIndex === index ? SemanticColors.textPrimary() : Color.Transparent)
          .backgroundEffect(this.marketSectionIndex === index ? undefined :
            buildImmersiveGlassEffect(this.glassStyle))
          .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
          .hoverEffect(HoverEffect.None)
          .onClick(() => this.handleMarketSectionTap(index))
      }, (label: string, index: number) => `${index}-${label}`)
    }
    .width('100%')
  }

  @Builder
  private marketFilters() {
    Column({ space: Spacing.SM }) {
      Row({ space: Spacing.SM }) {
        TextInput({ text: this.marketQuery, placeholder: '搜索称号' })
          .id('title-market-query')
          .layoutWeight(1).height(40)
          .fontSize(Typography.BODY)
          .backgroundColor($r('app.color.settings_group_bg'))
          .border({ width: 1, color: SemanticColors.outline() })
          .borderRadius(Radius.PILL)
          .onChange((value: string) => { this.marketQuery = value; })
          .onSubmit(() => {
            this.marketPage = 1;
            this.document = undefined;
            this.load();
          })
        Button('搜索', { type: ButtonType.Capsule, stateEffect: true })
          .id('title-market-search')
          .height(40)
          .fontSize(Typography.METADATA)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.brand_soft'))
          .onClick(() => {
            this.marketPage = 1;
            this.document = undefined;
            this.load();
          })
      }
      .width('100%')
      Scroll() {
        Row({ space: Spacing.XS }) {
          ForEach(MARKET_RARITY_LABELS, (label: string, index: number) => {
            Button(label, { type: ButtonType.Capsule, stateEffect: true })
              .height(30)
              .padding({ left: Spacing.MD, right: Spacing.MD })
              .fontSize(Typography.CAPTION)
              .fontWeight(this.marketRarity === MARKET_RARITY_VALUES[index] ? FontWeight.Bold : FontWeight.Regular)
              .fontColor(this.marketRarity === MARKET_RARITY_VALUES[index] ? $r('app.color.brand_primary') :
                SemanticColors.textSecondary())
              .backgroundColor(this.marketRarity === MARKET_RARITY_VALUES[index] ? $r('app.color.brand_soft') :
                $r('app.color.settings_group_bg'))
              .onClick(() => {
                this.marketRarity = MARKET_RARITY_VALUES[index];
                this.marketPage = 1;
                this.document = undefined;
                this.load();
              })
          }, (label: string, index: number) => `${index}-${label}`)
        }
      }
      .width('100%')
      .height(32)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
  }

  @Builder
  private marketCard(document: PortalDocument, card: PortalCard, index: number) {
    Column({ space: Spacing.XS }) {
      this.rarityBadge(this.ownedCardLine(card, 0), this.ownedCardLine(card, 1), this.ownedCardLine(card, 2))
      Row({ space: Spacing.XXS }) {
        Text(this.marketCardMeta(card, '单价'))
          .fontSize(Typography.TOPIC_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
        Text('积分 / 个')
          .fontSize(Typography.MICRO)
          .fontColor(SemanticColors.textTertiary())
      }
      .alignItems(VerticalAlign.Bottom)
      Text(`剩余 ${this.marketCardMeta(card, '剩余')} 个 · ${this.marketCardTime(card)}`)
        .fontSize(Typography.MICRO)
        .fontColor(SemanticColors.textTertiary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      Row({ space: Spacing.XS }) {
        this.compactQuantityStepper(this.marketQuantities[card.key] ?? 1,
          Math.max(1, Number(this.marketCardMeta(card, '剩余')) || 1),
          (next: number) => this.setMarketQuantity(card.key, next))
        Button('购买', { type: ButtonType.Capsule, stateEffect: true })
          .id(`market-buy-${index}`)
          .width(58)
          .height(32)
          .padding(0)
          .fontSize(Typography.METADATA)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.brand_soft'))
          .onClick(() => this.requestBuy(document, card, card.key))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height(MARKET_CARD_HEIGHT)
    .padding(Spacing.MD)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.settings_group_bg'))
    .border({ width: 1, color: SemanticColors.outline() })
    .borderRadius(20)
  }

  @Builder
  private marketPager(document: PortalDocument) {
    Row({ space: Spacing.MD }) {
      Button('上一页', { type: ButtonType.Capsule, stateEffect: this.marketPage > 1 })
        .layoutWeight(1)
        .height(38)
        .fontSize(Typography.METADATA)
        .fontColor(this.marketPage > 1 ? SemanticColors.textPrimary() : SemanticColors.disabled())
        .backgroundColor($r('app.color.settings_group_bg'))
        .enabled(this.marketPage > 1)
        .onClick(() => {
          this.marketPage = Math.max(1, this.marketPage - 1);
          this.document = undefined;
          this.load();
        })
      Text(`第 ${this.marketPage} 页`)
        .fontSize(Typography.METADATA)
        .fontColor(SemanticColors.textSecondary())
      Button('下一页', { type: ButtonType.Capsule, stateEffect: this.marketCards(document).length >= MARKET_PAGE_SIZE })
        .layoutWeight(1)
        .height(38)
        .fontSize(Typography.METADATA)
        .fontColor(this.marketCards(document).length >= MARKET_PAGE_SIZE ? SemanticColors.textPrimary() :
          SemanticColors.disabled())
        .backgroundColor($r('app.color.settings_group_bg'))
        .enabled(this.marketCards(document).length >= MARKET_PAGE_SIZE)
        .onClick(() => {
          this.marketPage++;
          this.document = undefined;
          this.load();
        })
    }
    .width('100%')
  }

  @Builder
  private marketListSection(document: PortalDocument) {
    Column({ space: Spacing.MD }) {
      this.marketFilters()
      if (this.marketCountText(document).length > 0) {
        Text(this.marketCountText(document))
          .fontSize(Typography.CAPTION)
          .fontColor(SemanticColors.textTertiary())
          .width('100%')
      }
      if (this.marketCards(document).length === 0) {
        this.emptyState('暂无符合条件的在售称号')
      } else {
        Grid() {
          LazyForEach(this.marketListingDataSource, (card: PortalCard, index: number) => {
            GridItem() { this.marketCard(document, card, index) }
          }, (card: PortalCard, index: number) => `${card.key}-${index}`)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(Spacing.SM)
        .rowsGap(Spacing.SM)
        .width('100%')
        .height(Math.ceil(this.marketListingDataSource.totalCount() / 2) *
          (MARKET_CARD_HEIGHT + Spacing.SM) - Spacing.SM)
        .scrollBar(BarState.Off)
        this.marketPager(document)
      }
    }
    .width('100%')
  }

  @Builder
  private marketPublishOptionCard(option: PortalOption, index: number) {
    Column({ space: Spacing.SM }) {
      this.rarityBadge(this.publishOptionParts(option)[0], this.publishOptionParts(option)[1],
        (option.rarity ?? '').toUpperCase())
      Text(`可出售 ${this.publishOptionMax(option)} 个`)
        .fontSize(Typography.CAPTION)
        .fontColor(SemanticColors.textSecondary())
      Blank()
      Text(this.marketPublishTitleId === option.value ? '已选择' : '选择')
        .width('100%')
        .height(32)
        .fontSize(Typography.METADATA)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.marketPublishTitleId === option.value ? $r('app.color.brand_primary') :
          SemanticColors.textSecondary())
        .textAlign(TextAlign.Center)
        .backgroundColor(this.marketPublishTitleId === option.value ? $r('app.color.brand_soft') :
          SemanticColors.surface())
        .borderRadius(Radius.PILL)
    }
    .id(`market-publish-title-${index}`)
    .width('100%')
    .height(MY_TITLE_CARD_HEIGHT)
    .padding(Spacing.MD)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.settings_group_bg'))
    .border({ width: this.marketPublishTitleId === option.value ? 2 : 1,
      color: this.marketPublishTitleId === option.value ? $r('app.color.brand_primary') : SemanticColors.outline() })
    .borderRadius(20)
    .onClick(() => {
      this.marketPublishTitleId = this.marketPublishTitleId === option.value ? '' : option.value;
      this.marketPublishQuantity = '1';
      this.showMarketDurationMenu = false;
    })
  }

  @Builder
  private myPublishedMarketCard(document: PortalDocument, card: PortalCard, index: number) {
    Column({ space: Spacing.XS }) {
      this.rarityBadge(this.ownedCardLine(card, 0), this.ownedCardLine(card, 1), this.ownedCardLine(card, 2))
      Text(this.marketPublishedSummary(card))
        .fontSize(Typography.CAPTION)
        .fontColor(SemanticColors.textSecondary())
        .maxLines(1)
      Text(`状态：${this.marketPublishedStatus(document, card)}`)
        .fontSize(Typography.CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.marketPublishedStatus(document, card) === '在售' ?
          $r('app.color.brand_primary') : SemanticColors.textSecondary())
        .maxLines(1)
      Text(this.marketPublishedReference(card))
        .fontSize(Typography.MICRO)
        .fontColor(SemanticColors.textTertiary())
        .maxLines(1)
      Blank()
      ForEach(this.cardActions(document, card), (action: PortalAction, actionIndex: number) => {
        Button(action.label.length > 0 ? action.label : '撤回', { type: ButtonType.Capsule, stateEffect: true })
          .id(`market-cancel-${index}-${actionIndex}`)
          .width('100%')
          .height(32)
          .fontSize(Typography.METADATA)
          .fontColor(SemanticColors.textPrimary())
          .backgroundColor(SemanticColors.surface())
          .border({ width: 1, color: SemanticColors.outline() })
          .onClick(() => this.requestAction(action))
      }, (action: PortalAction, actionIndex: number) => `${action.actionUrl}-${actionIndex}`)
    }
    .width('100%')
    .height(MARKET_CARD_HEIGHT)
    .padding(Spacing.MD)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.settings_group_bg'))
    .border({ width: 1, color: SemanticColors.outline() })
    .borderRadius(20)
  }

  @Builder
  private publishedMarketGrid(document: PortalDocument) {
    Grid() {
      ForEach(this.marketCards(document), (card: PortalCard, index: number) => {
        GridItem() { this.myPublishedMarketCard(document, card, index) }
      }, (card: PortalCard, index: number) => `${card.key}-${index}`)
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(Spacing.SM)
    .rowsGap(Spacing.SM)
    .width('100%')
    .height(Math.ceil(this.marketCards(document).length / 2) * (MARKET_CARD_HEIGHT + Spacing.SM) - Spacing.SM)
    .scrollBar(BarState.Off)
  }

  @Builder
  private marketPublishSection(document: PortalDocument) {
    Column({ space: Spacing.MD }) {
      if (this.marketPublishAction(document) !== undefined) {
        Text('选择要出售的称号')
          .fontSize(Typography.SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.textPrimary())
          .width('100%')
        if ((this.actionField(this.marketPublishAction(document), 'title_id')?.options.length ?? 0) === 0) {
          this.emptyState('当前没有可出售的称号')
        } else {
          Grid() {
            ForEach(this.actionField(this.marketPublishAction(document), 'title_id')?.options ?? [],
              (option: PortalOption, index: number) => {
                GridItem() { this.marketPublishOptionCard(option, index) }
              }, (option: PortalOption) => option.value)
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(Spacing.SM)
          .rowsGap(Spacing.SM)
          .width('100%')
          .height(Math.ceil((this.actionField(this.marketPublishAction(document), 'title_id')?.options.length ?? 0) / 2) *
            (MY_TITLE_CARD_HEIGHT + Spacing.SM) - Spacing.SM)
          .scrollBar(BarState.Off)
        }
        if (this.selectedPublishOption(this.marketPublishAction(document)) !== undefined) {
          Column({ space: Spacing.SM }) {
            Text('交易信息')
              .fontSize(Typography.SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(SemanticColors.textPrimary())
              .width('100%')
            Text('出售数量')
              .fontSize(Typography.CAPTION)
              .fontColor(SemanticColors.textSecondary())
              .width('100%')
            TextInput({ text: this.marketPublishQuantity,
              placeholder: `最多 ${this.publishOptionMax(this.selectedPublishOption(this.marketPublishAction(document)))} 个` })
              .id('market-publish-quantity')
              .width('100%').height(42)
              .type(InputType.Number)
              .fontSize(Typography.BODY)
              .backgroundColor(SemanticColors.surface())
              .border({ width: 1, color: SemanticColors.outline() })
              .borderRadius(Radius.MD)
              .onChange((value: string) => { this.marketPublishQuantity = value; })
            Text('单价（积分，最高 10,000）')
              .fontSize(Typography.CAPTION)
              .fontColor(SemanticColors.textSecondary())
              .width('100%')
            TextInput({ text: this.marketPublishUnitPrice, placeholder: '输入每个称号的积分价格' })
              .id('market-publish-unit-price')
              .width('100%').height(42)
              .type(InputType.Number)
              .fontSize(Typography.BODY)
              .backgroundColor(SemanticColors.surface())
              .border({ width: 1, color: SemanticColors.outline() })
              .borderRadius(Radius.MD)
              .onChange((value: string) => { this.marketPublishUnitPrice = value; })
            Text('有效期')
              .fontSize(Typography.CAPTION)
              .fontColor(SemanticColors.textSecondary())
              .width('100%')
            Stack({ alignContent: Alignment.TopEnd }) {
              Button(this.durationLabel(this.marketPublishAction(document)),
                { type: ButtonType.Capsule, stateEffect: true })
                .id('market-publish-duration')
                .width('100%').height(42)
                .fontSize(Typography.BODY)
                .fontColor(SemanticColors.textPrimary())
                .backgroundColor(SemanticColors.surface())
                .border({ width: 1, color: SemanticColors.outline() })
                .onClick(() => this.chooseMarketDuration(this.marketPublishAction(document) as PortalAction))
              if (this.showMarketDurationMenu) {
                this.marketDurationMenu(this.marketPublishAction(document) as PortalAction)
              }
            }
            .width('100%')
            .height(42)
            .clip(false)
            .zIndex(this.showMarketDurationMenu ? 12 : 0)
            Button('发布交易', { type: ButtonType.Capsule,
              stateEffect: this.canPublishMarket(this.marketPublishAction(document)) })
              .id('market-publish-submit')
              .width('100%').height(42)
              .fontSize(Typography.BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.canPublishMarket(this.marketPublishAction(document)) ?
                $r('app.color.brand_primary') : SemanticColors.disabled())
              .backgroundColor($r('app.color.brand_soft'))
              .enabled(this.canPublishMarket(this.marketPublishAction(document)))
              .onClick(() => this.requestMarketPublish(this.marketPublishAction(document) as PortalAction))
          }
          .width('100%')
          .padding(Spacing.MD)
          .backgroundColor($r('app.color.settings_group_bg'))
          .borderRadius(Radius.LG)
          .alignItems(HorizontalAlign.Start)
        }
      }
    }
    .width('100%')
  }

  private marketOrderRecords(document: PortalDocument): MarketOrderRecord[] {
    const output: MarketOrderRecord[] = [];
    for (let index = 0; index < document.lines.length; index++) {
      const line = document.lines[index];
      if (!line.startsWith('订单 #')) {
        continue;
      }
      const title = index >= 2 ? document.lines[index - 2] : '称号';
      const action = index + 1 < document.lines.length ? document.lines[index + 1] : '';
      const quantityMatch = action.match(/(\d+)/);
      const quantity = quantityMatch?.[1] ?? '1';
      let verb = '交易称号';
      if (action.startsWith('卖出')) {
        verb = '出售称号';
      } else if (action.startsWith('买入')) {
        verb = '购买称号';
      }
      let points = '';
      for (let offset = 1; offset <= 4 && index + offset < document.lines.length; offset++) {
        const candidate = document.lines[index + offset];
        if ((candidate.startsWith('+') || candidate.startsWith('-')) && candidate.indexOf('积分') > 0) {
          points = candidate;
          break;
        }
      }
      output.push({
        key: `${line}-${index}`,
        description: `${verb}「${title}」×${quantity}`,
        reference: line.replace(/^订单\s*/, ''),
        points: points
      });
    }
    return output;
  }

  @Builder
  private marketOrderRow(record: MarketOrderRecord, index: number, total: number) {
    Row({ space: Spacing.MD }) {
      Column({ space: Spacing.XS }) {
        Text(record.description)
          .fontSize(Typography.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(record.reference)
          .fontSize(Typography.METADATA)
          .fontColor(SemanticColors.textTertiary())
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (record.points.length > 0) {
        Text(record.points)
          .fontSize(Typography.BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(record.points.startsWith('-') ? Color.Red : $r('app.color.brand_primary'))
          .padding({ left: Spacing.SM, right: Spacing.SM, top: Spacing.XS, bottom: Spacing.XS })
          .border({ width: 1, color: record.points.startsWith('-') ? Color.Red : $r('app.color.brand_primary') })
          .borderRadius(Radius.PILL)
      }
    }
    .id(`market-order-${index}`)
    .width('100%')
    .height(76)
    .padding({ left: Spacing.SM, right: Spacing.SM })
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: index + 1 < total ? 1 : 0 }, color: SemanticColors.outline() })
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private marketOrdersSection(document: PortalDocument) {
    Column({ space: Spacing.MD }) {
      Text('发布记录')
        .fontSize(Typography.SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .width('100%')
      if (this.marketPublishedDocument !== undefined &&
        this.marketCards(this.marketPublishedDocument as PortalDocument).length > 0) {
        this.publishedMarketGrid(this.marketPublishedDocument as PortalDocument)
      } else {
        Text('还没有发布记录')
          .width('100%')
          .height(72)
          .fontSize(Typography.BODY)
          .fontColor(SemanticColors.textTertiary())
          .textAlign(TextAlign.Center)
      }
      Text('交易记录')
        .fontSize(Typography.SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .width('100%')
        .margin({ top: Spacing.SM })
      if (document.lines.indexOf('暂无成交记录') >= 0 || this.marketOrderRecords(document).length === 0) {
        Text('暂无交易记录')
          .width('100%')
          .height(72)
          .fontSize(Typography.BODY)
          .fontColor(SemanticColors.textTertiary())
          .textAlign(TextAlign.Center)
      } else {
        Column() {
          ForEach(this.marketOrderRecords(document), (record: MarketOrderRecord, index: number) => {
            this.marketOrderRow(record, index, this.marketOrderRecords(document).length)
          }, (record: MarketOrderRecord) => record.key)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private marketSection(document: PortalDocument) {
    Column({ space: Spacing.MD }) {
      Column({ space: Spacing.MD }) {
        this.marketControls()
      }
      .width('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG })
      Scroll() {
        Column({ space: Spacing.MD }) {
          if (this.marketSectionIndex === 0) {
            this.marketListSection(document)
          } else if (this.marketSectionIndex === 1) {
            this.marketPublishSection(document)
          } else {
            this.marketOrdersSection(document)
          }
          Column().height(this.bottomContentInset)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ left: Spacing.LG, right: Spacing.LG })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
      }
      .id('title-market-content')
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 18 })
        .onActionEnd((event: GestureEvent) => this.swipeSection(event.offsetX)))
    }
    .width('100%')
    .layoutWeight(1)
  }

  // ---------- root ----------

  build() {
    HdsNavigation() {
      Column({ space: Spacing.MD }) {
        if (!this.authenticated) {
          AccountLoginGate({
            title: '登录后使用称号系统',
            semanticPrefix: 'titles',
            onLogin: () => this.onLogin()
          })
            .margin({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XXL })
        } else {
          this.sectionTabs()
          if (this.loading && this.document === undefined) {
            Column() {
              LoadingProgress().width(30).height(30).color($r('app.color.brand_primary'))
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else if (this.document !== undefined) {
            if (this.sectionIndex === 0) {
              this.myTitlesSection(this.document as PortalDocument)
            } else if (this.sectionIndex === 1) {
              this.gachaSection(this.document as PortalDocument)
            } else if (this.sectionIndex === 2) {
              this.forgeSection(this.document as PortalDocument)
            } else if (this.sectionIndex === 3) {
              this.recycleSection(this.document as PortalDocument)
            } else if (this.sectionIndex === 4) {
              this.recipeSection(this.document as PortalDocument)
            } else {
              this.marketSection(this.document as PortalDocument)
            }
          } else {
            Column({ space: Spacing.MD }) {
              Text(this.errorMessage.length > 0 ? this.errorMessage : '暂无称号数据')
                .fontSize(Typography.BODY)
                .fontColor(SemanticColors.textSecondary())
              ImmersiveGlassTextButton({
                label: '重试', semanticId: 'titles-retry', onAction: () => this.load()
              })
            }
            .width('100%')
            .padding({ top: Spacing.XL })
            .justifyContent(FlexAlign.Start)
          }
        }
      }
      .id('title-center-page')
      .width('100%').height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(SemanticColors.page())
    }
    .titleBar({
      avoidLayoutSafeArea: requiresHdsLayoutSafeAreaAvoidance(ImmersiveLightArea.TITLE_BAR),
      enableComponentSafeArea: requiresHdsComponentSafeArea(ImmersiveLightArea.TITLE_BAR),
      style: buildImmersiveTitleBarStyle(),
      content: { stackBuilder: () => { this.titleBar(); } }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .mode(NavigationMode.Stack)
    .hideBackButton(true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%').height('100%')
  }
}
