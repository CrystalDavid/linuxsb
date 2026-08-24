import { AppColors, PageMetrics, Radius, SemanticColors, Typography } from '../../common/theme/DesignSystem';
import { SYS_BOTTOM_INSET_KEY, SYS_TOP_INSET_KEY } from '../../common/ui/ImmersiveWindow';
import { CategoryUiModel } from '../../models/presentation/ForumUiModels';
import { ChoiceChip } from './ChoiceChip';

export enum HomeFeedSort {
  NewComments = 'NewComments',
  NewTopics = 'NewTopics'
}

@Component
export struct CategoryDrawer {
  @Prop categories: CategoryUiModel[] = [];
  @Prop selectedSort: HomeFeedSort = HomeFeedSort.NewComments;
  @Prop selectedCategoryId: number = 0;
  @Prop appliedSort: HomeFeedSort = HomeFeedSort.NewComments;
  @Prop appliedCategoryId: number = 0;
  onSortChange: (sort: HomeFeedSort) => void = () => {};
  onCategoryChange: (categoryId: number) => void = () => {};
  onApply: () => void = () => {};
  onClose: () => void = () => {};
  @StorageProp(SYS_TOP_INSET_KEY) private topInset: number = 0;
  @StorageProp(SYS_BOTTOM_INSET_KEY) private bottomInset: number = 0;

  @Builder
  private drawerHeader() {
    Row() {
      Blank().layoutWeight(1)
      if (this.isDirty()) {
        Text('重置')
          .fontSize(13)
          .fontColor(AppColors.brandPrimary())
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .onClick(() => {
            this.onSortChange(HomeFeedSort.NewComments);
            this.onCategoryChange(0);
          })
      }
      Row() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(18)
          .fontColor([SemanticColors.textSecondary()])
      }
      .id('category-drawer-close')
      .accessibilityText('关闭主题选项')
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.onClose())
    }
    .id('category-drawer-header')
    .width('100%')
    .padding({ left: 16, right: 12, top: 14, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private filterSection() {
    Column() {
      Flex({ wrap: FlexWrap.Wrap }) {
        ChoiceChip({
          label: '新评论',
          selected: this.selectedSort === HomeFeedSort.NewComments,
          onSelect: () => this.onSortChange(HomeFeedSort.NewComments)
        })
        ChoiceChip({
          label: '新帖子',
          selected: this.selectedSort === HomeFeedSort.NewTopics,
          onSelect: () => this.onSortChange(HomeFeedSort.NewTopics)
        })
      }
      .width('100%')
    }
    .id('category-drawer-filters')
    .width('100%')
    .padding({ left: 16, right: 16, top: 2 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private categoryRow(categoryId: number, name: string) {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.archivebox'))
          .fontSize(18)
          .fontColor([categoryId === this.selectedCategoryId ? AppColors.brandPrimary() :
            SemanticColors.textSecondary()])
      }
      .width(28)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 10 })
      Text(name)
        .fontSize(Typography.BODY)
        .fontColor(categoryId === this.selectedCategoryId ? AppColors.brandPrimary() :
          SemanticColors.textPrimary())
        .fontWeight(categoryId === this.selectedCategoryId ? FontWeight.Medium : FontWeight.Regular)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (categoryId === this.selectedCategoryId) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(17)
          .fontColor([AppColors.brandPrimary()])
      }
    }
    .id(`category-${categoryId}`)
    .accessibilityText(`${name}${categoryId === this.selectedCategoryId ? '，已选择' : ''}`)
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor(categoryId === this.selectedCategoryId ? AppColors.brandSoft() : Color.Transparent)
    .onClick(() => this.onCategoryChange(categoryId))
  }

  @Builder
  private confirmBar() {
    Column({ space: 8 }) {
      Text(this.selectionSummary())
        .fontSize(12)
        .fontColor(SemanticColors.textSecondary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
      Button(this.isDirty() ? '查看结果' : '关闭')
        .id('category-drawer-apply')
        .width('100%')
        .height(42)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(AppColors.brandPrimary())
        .borderRadius(Radius.MD)
        .onClick(() => this.isDirty() ? this.onApply() : this.onClose())
    }
    .id('category-drawer-confirm-bar')
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 12 + this.bottomInset })
    .border({ width: { top: 0.5 }, color: SemanticColors.divider() })
  }

  build() {
    Column() {
      this.drawerHeader()
      this.filterSection()
      Divider()
        .strokeWidth(0.5)
        .color(SemanticColors.divider())
        .margin({ left: 16, right: 16, top: 6, bottom: 4 })
      Scroll() {
        Column() {
          this.categoryRow(0, '全部版块')
          ForEach(this.categories, (category: CategoryUiModel) => {
            this.categoryRow(category.categoryId, category.name)
          }, (category: CategoryUiModel) => category.categoryId.toString())
          Row().width('100%').height(12)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .id('category-drawer-scroll')
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
      this.confirmBar()
    }
    .id('category-drawer')
    .width(PageMetrics.DRAWER_WIDTH)
    .height('100%')
    .padding({ top: this.topInset })
    .backgroundColor(SemanticColors.surfaceElevated())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  private isDirty(): boolean {
    return this.selectedSort !== this.appliedSort || this.selectedCategoryId !== this.appliedCategoryId;
  }

  private selectionSummary(): string {
    return `${this.selectedCategoryName()} · ${this.sortName()}`;
  }

  private selectedCategoryName(): string {
    if (this.selectedCategoryId === 0) {
      return '全部版块';
    }
    for (let index = 0; index < this.categories.length; index++) {
      if (this.categories[index].categoryId === this.selectedCategoryId) {
        return this.categories[index].name;
      }
    }
    return '当前版块';
  }

  private sortName(): string {
    if (this.selectedSort === HomeFeedSort.NewComments) {
      return '新评论';
    }
    if (this.selectedSort === HomeFeedSort.NewTopics) {
      return '新帖子';
    }
    return '新评论';
  }
}
