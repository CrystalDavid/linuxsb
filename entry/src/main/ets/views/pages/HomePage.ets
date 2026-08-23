import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../common/theme/AppTheme';
import { TopicSummary } from '../../models/HomeModels';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { ViewLoadState } from '../../viewmodels/ViewState';
import { TopicListDataSource } from '../components/TopicListDataSource';

@Component
export struct HomePage {
  @ObjectLink viewModel: HomeViewModel;
  debugAvailable: boolean = false;
  onTopicSelected: (topicId: number) => void = (_topicId: number) => {};
  onOpenDiagnostics: () => void = () => {};
  private topicDataSource: TopicListDataSource = new TopicListDataSource();

  aboutToAppear(): void {
    this.topicDataSource.replace(this.viewModel.topics);
    if (this.viewModel.state === ViewLoadState.Idle) {
      this.load(false);
    }
  }

  private async load(isRefresh: boolean): Promise<void> {
    await this.viewModel.load(isRefresh);
    this.topicDataSource.replace(this.viewModel.topics);
  }

  @Builder
  private header() {
    Column({ space: AppSpacing.XS }) {
      Row() {
        Text('烧饼社区')
          .fontSize(AppTypography.DISPLAY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .gesture(
            LongPressGesture({ repeat: false, duration: 1200 })
              .onAction(() => {
                if (this.debugAvailable) {
                  this.onOpenDiagnostics();
                }
              })
          )

        Text('非官方客户端')
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.primary'))
          .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS })
          .backgroundColor($r('app.color.primary_soft'))
          .borderRadius(AppRadius.PILL)
          .gesture(
            LongPressGesture({ repeat: false, duration: 1200 })
              .onAction(() => {
                if (this.debugAvailable) {
                  this.onTopicSelected(605);
                }
              })
          )
      }
      .width('100%')

      Text('来自 linux.sb 的实时公开主题')
        .fontSize(AppTypography.BODY)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.XL, bottom: AppSpacing.MD })
  }

  @Builder
  private topicRow(item: TopicSummary) {
    Column({ space: AppSpacing.SM }) {
      Text(item.title)
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: AppSpacing.XS }) {
        Text(item.forumName.length > 0 ? item.forumName : `版块 ${item.forumId}`)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary'))
        Blank()
        Text(`#${item.topicId}`)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppSpacing.MD)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(AppRadius.MD)
    .border({ width: 1, color: $r('app.color.border') })
    .onClick(() => this.onTopicSelected(item.topicId))
  }

  @Builder
  private messageState(title: string, detail: string, action: string) {
    Column({ space: AppSpacing.SM }) {
      Text(title)
        .fontSize(AppTypography.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(detail)
        .fontSize(AppTypography.BODY)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Button(action)
        .onClick(() => this.load(false))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(AppSpacing.XL)
  }

  build() {
    Column() {
      this.header()

      if (this.viewModel.state === ViewLoadState.Loading || this.viewModel.state === ViewLoadState.Idle) {
        Column({ space: AppSpacing.SM }) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color($r('app.color.primary'))
          Text('正在获取主题…')
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.viewModel.state === ViewLoadState.Empty) {
        this.messageState('暂时没有主题', '站点返回了可识别页面，但主题列表为空。', '重新加载')
      } else if (this.viewModel.state === ViewLoadState.Offline) {
        this.messageState('当前无法联网', '请检查网络连接后重试。', '重试')
      } else if (this.viewModel.state === ViewLoadState.Error) {
        this.messageState('主题加载失败', '页面结构或服务暂时不可用。', '重试')
      } else {
        Refresh({ refreshing: this.viewModel.refreshing }) {
          List({ space: AppSpacing.SM }) {
            LazyForEach(this.topicDataSource, (item: TopicSummary) => {
              ListItem() {
                this.topicRow(item)
              }
            }, (item: TopicSummary) => item.topicId.toString())
          }
          .width('100%')
          .height('100%')
          .padding({ left: AppSpacing.MD, right: AppSpacing.MD, bottom: AppSpacing.XL })
          .edgeEffect(EdgeEffect.Spring)
        }
        .layoutWeight(1)
        .onRefreshing(() => this.load(true))
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppLayout.PHONE_CONTENT_MAX })
    .backgroundColor($r('app.color.page_background'))
  }
}
