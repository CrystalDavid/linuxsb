import { SemanticColors, Typography } from '../../common/theme/DesignSystem';
import { resolveTopicDetailHeaderMode, TopicDetailHeaderMode } from '../../common/ui/TopicDetailHeaderState';
import {
  ImmersiveIconButton,
  TITLE_BAR_BACK_ICON_SIZE,
  TITLE_BAR_BACK_ICON_WEIGHT
} from './ImmersiveIconButton';

@Component
export struct TopicDetailHeader {
  @Prop summaryVisible: boolean = true;
  @Prop title: string = '';
  @Prop categoryName: string = '';
  onBack: () => void = () => {};
  onTitleClick: () => void = () => {};

  private showsSummaryLabel(): boolean {
    return resolveTopicDetailHeaderMode(this.summaryVisible) === TopicDetailHeaderMode.Summary;
  }

  build() {
    Row({ space: 8 }) {
      ImmersiveIconButton({
        semanticId: 'topic-back',
        semanticLabel: '返回',
        icon: $r('sys.symbol.chevron_left'),
        iconSize: TITLE_BAR_BACK_ICON_SIZE,
        iconWeight: TITLE_BAR_BACK_ICON_WEIGHT,
        onAction: () => this.onBack()
      })
      Stack({ alignContent: Alignment.Start }) {
        Text('帖子详情')
          .id('topic-header-summary-label')
          .fontSize(Typography.PAGE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .opacity(this.showsSummaryLabel() ? 1 : 0)
          .translate({ y: this.showsSummaryLabel() ? 0 : -8 })
          .hitTestBehavior(this.showsSummaryLabel() ? HitTestMode.Default : HitTestMode.None)
          .animation({ duration: 250, curve: Curve.EaseInOut })
        Column({ space: 2 }) {
          Text(this.title.length > 0 ? this.title : '主题详情')
            .fontSize(Typography.LIST_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.textPrimary())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          if (this.categoryName.length > 0) {
            Text(this.categoryName)
              .fontSize(Typography.LABEL_SMALL)
              .fontColor(SemanticColors.textSecondary())
              .maxLines(1)
          }
        }
        .id('topic-header-collapsed-title')
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
        .opacity(this.showsSummaryLabel() ? 0 : 1)
        .translate({ y: this.showsSummaryLabel() ? 8 : 0 })
        .hitTestBehavior(this.showsSummaryLabel() ? HitTestMode.None : HitTestMode.Default)
        .animation({ duration: 250, curve: Curve.EaseInOut })
        .onClick(() => this.onTitleClick())
      }
      .layoutWeight(1)
      .alignContent(Alignment.Start)
    }
    .id('topic-detail-header')
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 10, right: 16 })
  }
}
