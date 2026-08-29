import { Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import {
  buildImmersiveGlassEffect,
  buildImmersiveSystemMaterialModifier,
  IMMERSIVE_GLASS_BORDER_WIDTH,
  IMMERSIVE_GLASS_SHADOW_OFFSET_Y,
  IMMERSIVE_GLASS_SHADOW_RADIUS
} from '../../common/ui/ImmersiveActionBarStyle';
import { GLASS_STYLE_STORAGE_KEY, GlassStyleMode } from '../../common/ui/GlassStyleParams';
import { FeedSort } from '../../models/HomeModels';

export function feedSortLabel(sort: FeedSort): string {
  switch (sort) {
    case FeedSort.NewTopics:
      return '新帖子';
    case FeedSort.Featured:
      return '精华';
    case FeedSort.Lottery:
      return '抽奖';
    case FeedSort.Card:
      return '发卡';
    case FeedSort.Footprint:
      return '足迹';
    default:
      return '新评论';
  }
}

// Title-bar filter entry: a glass capsule showing the currently selected feed
// label as centered primary text. It replaces both the segmented 新评论/新帖子
// switcher and the plain icon button so the active selection is readable in
// place. Tapping toggles the shared FeedFilterMenu; the menu itself provides
// enough affordance, so the title-bar entry deliberately has no chevron.
@Component
export struct FeedFilterButton {
  @Prop label: string = '新评论';
  semanticId: string = 'feed-filter-button';
  onAction: () => void = () => {};
  @StorageProp(GLASS_STYLE_STORAGE_KEY) private glassStyle: GlassStyleMode = GlassStyleMode.Translucent;

  build() {
    Button({ type: ButtonType.Capsule, stateEffect: false }) {
      Text(this.label)
        .id(`${this.semanticId}-label`)
        .textAlign(TextAlign.Center)
        .fontSize(Typography.BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.textPrimary())
    }
      .id(this.semanticId)
      .accessibilityText(`帖子筛选，当前${this.label}`)
      .height(40)
      .padding({ left: Spacing.LG, right: Spacing.LG })
      .backgroundColor(Color.Transparent)
      .backgroundEffect(buildImmersiveGlassEffect(this.glassStyle))
      .border({
        width: IMMERSIVE_GLASS_BORDER_WIDTH,
        color: $r('app.color.bottom_tab_bar_highlight')
      })
      .borderRadius(Radius.PILL)
      .shadow({
        radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
        color: $r('app.color.bottom_tab_bar_shadow'),
        offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
      })
      .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
      .hoverEffect(HoverEffect.None)
      .onClick(() => this.onAction())
  }
}

// Shared dropdown for the feed filters. 新评论/新帖子 moved in from the old
// segmented control; 精华/抽奖/发卡/足迹 continue the previous quick menu.
@Component
export struct FeedFilterMenu {
  @Prop selectedSort: FeedSort = FeedSort.NewComments;
  semanticPrefix: string = 'feed-filter';
  onSelect: (sort: FeedSort) => void = () => {};
  @StorageProp(GLASS_STYLE_STORAGE_KEY) private glassStyle: GlassStyleMode = GlassStyleMode.Translucent;

  @Builder
  private item(label: string, sort: FeedSort, semanticId: string) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Row() {
        Text(label)
          .fontSize(Typography.BODY)
          .fontColor(this.selectedSort === sort ? $r('app.color.brand_primary') :
            SemanticColors.textPrimary())
          .fontWeight(this.selectedSort === sort ? FontWeight.Medium : FontWeight.Regular)
        Blank()
        if (this.selectedSort === sort) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(15)
            .fontColor([$r('app.color.brand_primary')])
        }
      }
      .width('100%')
    }
      .id(semanticId)
      .accessibilityText(label)
      .width(132)
      .height(42)
      .padding({ left: Spacing.MD, right: Spacing.MD })
      .backgroundColor(Color.Transparent)
      .borderRadius(Radius.MD)
      .hoverEffect(HoverEffect.None)
      .onClick(() => this.onSelect(sort))
  }

  build() {
    Column() {
      this.item('新评论', FeedSort.NewComments, `${this.semanticPrefix}-quick-comments`)
      this.item('新帖子', FeedSort.NewTopics, `${this.semanticPrefix}-quick-topics`)
      this.item('精华', FeedSort.Featured, `${this.semanticPrefix}-quick-featured`)
      this.item('抽奖', FeedSort.Lottery, `${this.semanticPrefix}-quick-lottery`)
      this.item('发卡', FeedSort.Card, `${this.semanticPrefix}-quick-card`)
      this.item('足迹', FeedSort.Footprint, `${this.semanticPrefix}-quick-footprint`)
    }
      .id(`${this.semanticPrefix}-quick-menu`)
      .width(148)
      .padding(Spacing.XS)
      .backgroundEffect(buildImmersiveGlassEffect(this.glassStyle))
      .border({
        width: IMMERSIVE_GLASS_BORDER_WIDTH,
        color: $r('app.color.bottom_tab_bar_highlight')
      })
      .borderRadius(Radius.LG)
      .shadow({
        radius: IMMERSIVE_GLASS_SHADOW_RADIUS,
        color: $r('app.color.bottom_tab_bar_shadow'),
        offsetY: IMMERSIVE_GLASS_SHADOW_OFFSET_Y
      })
      .attributeModifier(buildImmersiveSystemMaterialModifier(this.glassStyle))
      .clip(true)
  }
}
