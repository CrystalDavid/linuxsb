import { AppColors, PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { SYS_BOTTOM_INSET_KEY, SYS_TOP_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { CategoryUiModel } from '../../models/presentation/ForumUiModels';
import { ChoiceChip } from './ChoiceChip';

export enum HomeFeedSort {
  Latest = 'Latest',
  NewComments = 'NewComments',
  NewTopics = 'NewTopics',
  Featured = 'Featured'
}

@Component
export struct CategoryDrawer {
  categories: CategoryUiModel[] = [];
  selectedSort: HomeFeedSort = HomeFeedSort.Latest;
  selectedCategoryId: number = 0;
  showFeatured: boolean = false;
  onSortChange: (sort: HomeFeedSort) => void = () => {};
  onCategoryChange: (categoryId: number) => void = () => {};
  onApply: () => void = () => {};
  onClose: () => void = () => {};
  @StorageProp(SYS_TOP_INSET_KEY) private topInset: number = 0;
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;

  @Builder
  private categoryRow(categoryId: number, name: string) {
    Row() {
      Text(name)
        .fontSize(Typography.BODY)
        .fontColor(categoryId === this.selectedCategoryId ? AppColors.brandPrimary() : SemanticColors.textPrimary())
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (categoryId === this.selectedCategoryId) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18)
          .fontColor([AppColors.brandPrimary()])
      }
    }
    .id(`category-${categoryId}`)
    .width('100%')
    .height(48)
    .padding({ left: Spacing.LG, right: Spacing.LG })
    .backgroundColor(categoryId === this.selectedCategoryId ? AppColors.brandSoft() : Color.Transparent)
    .onClick(() => this.onCategoryChange(categoryId))
  }

  build() {
    Column() {
      Row() {
        Text('筛选')
          .fontSize(Typography.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.textPrimary())
          .layoutWeight(1)
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([SemanticColors.textSecondary()])
        }
        .id('category-drawer-close')
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.onClose())
      }
      .width('100%')
      .height(56)
      .padding({ left: Spacing.LG, right: Spacing.SM })
      .margin({ top: this.topInset })

      Scroll() {
        Column() {
          Text('主题')
            .fontSize(Typography.LABEL)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textSecondary())
            .width('100%')
            .margin({ bottom: Spacing.SM })

          Flex({ wrap: FlexWrap.Wrap }) {
            ChoiceChip({
              label: '最新',
              selected: this.selectedSort === HomeFeedSort.Latest,
              onSelect: () => this.onSortChange(HomeFeedSort.Latest)
            })
            ChoiceChip({
              label: '新评论',
              selected: this.selectedSort === HomeFeedSort.NewComments,
              onSelect: () => this.onSortChange(HomeFeedSort.NewComments)
            })
              .margin({ left: Spacing.SM })
            ChoiceChip({
              label: '新帖子',
              selected: this.selectedSort === HomeFeedSort.NewTopics,
              onSelect: () => this.onSortChange(HomeFeedSort.NewTopics)
            })
              .margin({ left: Spacing.SM })
            if (this.showFeatured) {
              ChoiceChip({
                label: '精华',
                selected: this.selectedSort === HomeFeedSort.Featured,
                onSelect: () => this.onSortChange(HomeFeedSort.Featured)
              })
                .margin({ top: Spacing.SM })
            }
          }
          .width('100%')
          .margin({ bottom: Spacing.XL })

          Divider().color(SemanticColors.divider())

          Text('版块')
            .fontSize(Typography.LABEL)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textSecondary())
            .width('100%')
            .margin({ top: Spacing.LG, bottom: Spacing.XS })

          this.categoryRow(0, '全部版块')
          ForEach(this.categories, (category: CategoryUiModel) => {
            this.categoryRow(category.categoryId, category.name)
          }, (category: CategoryUiModel) => category.categoryId.toString())
        }
        .width('100%')
        .padding({ left: Spacing.LG, right: Spacing.LG })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      Row({ space: Spacing.SM }) {
        Button('重置')
          .layoutWeight(1)
          .height(PageMetrics.CONTROL_HEIGHT)
          .fontColor(SemanticColors.textSecondary())
          .backgroundColor(SemanticColors.surfaceMuted())
          .borderRadius(Radius.PILL)
          .onClick(() => {
            this.onSortChange(HomeFeedSort.Latest);
            this.onCategoryChange(0);
          })
        Button('完成')
          .layoutWeight(1)
          .height(PageMetrics.CONTROL_HEIGHT)
          .fontColor(Color.White)
          .backgroundColor(AppColors.brandPrimary())
          .borderRadius(Radius.PILL)
          .onClick(() => this.onApply())
      }
      .width('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD,
        bottom: Spacing.LG + this.bottomInset })
      .border({ width: { top: 1 }, color: SemanticColors.divider() })
    }
    .id('category-drawer')
    .width(PageMetrics.DRAWER_WIDTH)
    .height('100%')
    .backgroundColor(SemanticColors.surfaceElevated())
  }
}
