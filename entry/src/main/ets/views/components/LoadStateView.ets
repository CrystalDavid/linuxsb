import { AppColors, PageMetrics, Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { ViewLoadState } from '../../viewmodels/ViewState';

@Component
export struct LoadStateView {
  state: ViewLoadState = ViewLoadState.Loading;
  title: string = '';
  detail: string = '';
  semanticPrefix: string = 'load';
  showSkeleton: boolean = false;
  onRetry: () => void = () => {};

  @Builder
  private skeletonRow(width: string) {
    Row({ space: Spacing.SM }) {
      Row()
        .width(48)
        .height(48)
        .borderRadius(Radius.PILL)
        .backgroundColor(SemanticColors.skeleton())
      Column({ space: Spacing.SM }) {
        Row().width(width).height(PageMetrics.SKELETON_TITLE_HEIGHT)
          .borderRadius(Radius.XS).backgroundColor(SemanticColors.skeleton())
        Row().width('48%').height(PageMetrics.SKELETON_META_HEIGHT)
          .borderRadius(Radius.XS).backgroundColor(SemanticColors.skeleton())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: PageMetrics.HORIZONTAL_PADDING, right: PageMetrics.HORIZONTAL_PADDING,
      top: Spacing.SM, bottom: Spacing.SM })
  }

  @Builder
  private loading() {
    if (this.showSkeleton) {
      Column() {
        this.skeletonRow('86%')
        Divider().color(SemanticColors.divider())
        this.skeletonRow('72%')
        Divider().color(SemanticColors.divider())
        this.skeletonRow('92%')
        Divider().color(SemanticColors.divider())
        this.skeletonRow('64%')
      }
      .width('100%')
    } else {
      Column({ space: Spacing.MD }) {
        LoadingProgress().width(32).height(32).color(AppColors.brandPrimary())
        Text(this.title.length > 0 ? this.title : '正在加载…')
          .fontSize(Typography.BODY).fontColor(SemanticColors.textSecondary())
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  private message() {
    Column({ space: Spacing.MD }) {
      SymbolGlyph(this.state === ViewLoadState.Offline ? $r('sys.symbol.wifi_slash') :
        this.state === ViewLoadState.Empty ? $r('sys.symbol.archivebox') : $r('sys.symbol.exclamationmark'))
        .fontSize(30)
        .fontColor([this.state === ViewLoadState.Error ? SemanticColors.error() : AppColors.brandPrimary()])
      Text(this.title).fontSize(Typography.TITLE).fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary()).textAlign(TextAlign.Center)
      Text(this.detail).fontSize(Typography.BODY).fontColor(SemanticColors.textSecondary())
        .textAlign(TextAlign.Center).constraintSize({ maxWidth: PageMetrics.MESSAGE_MAX_WIDTH })
      if (this.state !== ViewLoadState.Empty) {
        Button('重新加载').id(`${this.semanticPrefix}-retry`)
          .fontColor(Color.White).backgroundColor(AppColors.brandPrimary()).borderRadius(Radius.PILL)
          .onClick(() => this.onRetry())
      }
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).padding(Spacing.XXL)
  }

  build() {
    Column() {
      if (this.state === ViewLoadState.Loading || this.state === ViewLoadState.Idle) {
        this.loading()
      } else {
        this.message()
      }
    }
    .id(`${this.semanticPrefix}-${this.state.toLowerCase()}`)
    .width('100%')
    .height('100%')
    .backgroundColor(SemanticColors.page())
  }
}
