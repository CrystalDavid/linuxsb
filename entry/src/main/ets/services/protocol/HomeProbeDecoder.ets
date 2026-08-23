import { HtmlToken, HtmlTokenType, LightweightHtmlTokenizer } from './LightweightHtmlTokenizer';
import { HomeProbeResult, HomeTopicProbeSummary, ForumProbeSummary } from './ProbeModels';
import { collapseWhitespace, extractBbsVersion, hasClass, parseRouteId } from './HtmlProbeUtils';

class HomeTopicDraft {
  topicId: number = 0;
  title: string = '';
  forumId: number = 0;
  forumName: string = '';
}

export class HomeProbeDecoder {
  decode(html: string): HomeProbeResult {
    const topics: HomeTopicProbeSummary[] = [];
    const forums: ForumProbeSummary[] = [];
    const warnings: string[] = [];
    const forumIds = new Set<number>();
    const topicIds = new Set<number>();
    let bbsVersion = '';
    let currentItem: HomeTopicDraft | undefined = undefined;
    let anchorKind = '';
    let anchorText = '';
    let anchorId = 0;

    new LightweightHtmlTokenizer().scan(html, (token: HtmlToken) => {
      if (token.type === HtmlTokenType.START_TAG) {
        if (token.name === 'link' && bbsVersion.length === 0) {
          bbsVersion = extractBbsVersion(token.attributes.get('href') ?? '');
        }
        if (token.name === 'li' && hasClass(token.attributes, 'post-item')) {
          this.finalizeTopic(currentItem, topics, topicIds, warnings);
          currentItem = new HomeTopicDraft();
        }
        if (token.name !== 'a') {
          return;
        }

        anchorKind = '';
        anchorText = '';
        anchorId = 0;
        const href = token.attributes.get('href') ?? '';
        const topicId = parseRouteId(href, '/topic/');
        const forumId = parseRouteId(href, '/forum/');
        if (currentItem !== undefined && topicId > 0 && hasClass(token.attributes, 'post-title')) {
          anchorKind = 'topic';
          anchorId = topicId;
        } else if (forumId > 0) {
          anchorKind = currentItem !== undefined && hasClass(token.attributes, 'post-forum-badge') ? 'item-forum' : 'forum';
          anchorId = forumId;
        } else if (href.startsWith('https://bbs1.org') || href.startsWith('https://www.bbs1.org')) {
          anchorKind = 'version';
        }
        return;
      }

      if (token.type === HtmlTokenType.TEXT && anchorKind.length > 0) {
        anchorText += token.text;
        return;
      }

      if (token.type === HtmlTokenType.END_TAG && token.name === 'a' && anchorKind.length > 0) {
        const text = collapseWhitespace(anchorText);
        if (anchorKind === 'topic' && currentItem !== undefined) {
          currentItem.topicId = anchorId;
          currentItem.title = text;
        } else if (anchorKind === 'item-forum' && currentItem !== undefined) {
          currentItem.forumId = anchorId;
          currentItem.forumName = text;
          this.addForum(forums, forumIds, anchorId, text);
        } else if (anchorKind === 'forum') {
          this.addForum(forums, forumIds, anchorId, text);
        } else if (anchorKind === 'version' && bbsVersion.length === 0) {
          bbsVersion = extractBbsVersion(text);
        }
        anchorKind = '';
        anchorText = '';
        anchorId = 0;
        return;
      }

      if (token.type === HtmlTokenType.END_TAG && token.name === 'li') {
        this.finalizeTopic(currentItem, topics, topicIds, warnings);
        currentItem = undefined;
      }
    });

    this.finalizeTopic(currentItem, topics, topicIds, warnings);
    if (bbsVersion.length === 0) {
      warnings.push('BBS_VERSION_MISSING');
    }
    if (topics.length === 0) {
      warnings.push('HOME_TOPIC_LIST_MISSING');
    }
    return {
      protocolMatched: bbsVersion.length > 0 && topics.length > 0,
      bbsVersion: bbsVersion,
      forums: forums,
      topics: topics,
      warnings: warnings
    };
  }

  private addForum(forums: ForumProbeSummary[], ids: Set<number>, forumId: number, name: string): void {
    if (forumId <= 0 || name.length === 0 || ids.has(forumId)) {
      return;
    }
    ids.add(forumId);
    forums.push({ forumId: forumId, name: name });
  }

  private finalizeTopic(draft: HomeTopicDraft | undefined, topics: HomeTopicProbeSummary[], ids: Set<number>, warnings: string[]): void {
    if (draft === undefined || draft.topicId <= 0 || draft.title.length === 0 || ids.has(draft.topicId)) {
      return;
    }
    if (draft.forumId <= 0) {
      warnings.push(`TOPIC_FORUM_MISSING:${draft.topicId}`);
    }
    ids.add(draft.topicId);
    if (topics.length < 30) {
      topics.push({
        topicId: draft.topicId,
        title: draft.title,
        forumId: draft.forumId,
        forumName: draft.forumName
      });
    }
  }
}
