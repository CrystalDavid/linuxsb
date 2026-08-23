export enum TopicDetailHeaderMode {
  Summary = 'Summary',
  CollapsedTitle = 'CollapsedTitle'
}

export function resolveTopicDetailHeaderMode(summaryVisible: boolean): TopicDetailHeaderMode {
  return summaryVisible ? TopicDetailHeaderMode.Summary : TopicDetailHeaderMode.CollapsedTitle;
}
