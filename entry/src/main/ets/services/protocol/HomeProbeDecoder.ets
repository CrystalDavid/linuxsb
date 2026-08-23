import { HtmlToken, HtmlTokenType, LightweightHtmlTokenizer } from './LightweightHtmlTokenizer';
import { HomeProbeResult, HomeTopicProbeSummary, ForumProbeSummary } from './ProbeModels';
import { collapseWhitespace, extractBbsVersion, hasClass, parseRouteId } from './HtmlProbeUtils';

class HomeTopicDraft {
  topicId: number = 0;
  title: string = '';
  forumId: number = 0;
  forumName: string = '';
  authorId: number = 0;
  authorName: string = '';
  authorAvatarUrl: string = '';
  replyCount: number = -1;
  lastReplyUser: string = '';
  lastReplyAt: number = 0;
  isPinned: boolean = false;
  isFeatured: boolean = false;
  isHot: boolean = false;
  lotteryStatus: string = '';
  cardStatus: string = '';
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
    let postMetaDepth = 0;
    let postMetaSpanDepth = 0;
    let postMetaSpanIndex = 0;
    let postMetaText = '';
    let postAvatarDepth = 0;

    new LightweightHtmlTokenizer().scan(html, (token: HtmlToken) => {
      if (token.type === HtmlTokenType.START_TAG) {
        if (token.name === 'link' && bbsVersion.length === 0) {
          bbsVersion = extractBbsVersion(token.attributes.get('href') ?? '');
        }
        if (token.name === 'li' && hasClass(token.attributes, 'post-item')) {
          this.finalizeTopic(currentItem, topics, topicIds, warnings);
          currentItem = new HomeTopicDraft();
          currentItem.isPinned = hasClass(token.attributes, 'topic-pinned');
          postMetaDepth = 0;
          postMetaSpanDepth = 0;
          postMetaSpanIndex = 0;
          postMetaText = '';
          postAvatarDepth = 0;
        }
        if (currentItem !== undefined) {
          this.captureStatus(token, currentItem);
          if (token.name === 'div' && hasClass(token.attributes, 'post-avatar')) {
            postAvatarDepth = 1;
          } else if (token.name === 'div' && postAvatarDepth > 0) {
            postAvatarDepth++;
          }
          if (token.name === 'div' && hasClass(token.attributes, 'post-meta')) {
            postMetaDepth = 1;
            postMetaSpanIndex = 0;
          } else if (token.name === 'div' && postMetaDepth > 0) {
            postMetaDepth++;
          }
          if (postMetaDepth > 0 && token.name === 'span') {
            if (postMetaSpanDepth === 0) {
              postMetaSpanIndex++;
              postMetaText = '';
              const performanceTime = token.attributes.get('data-performance-time') ?? '';
              if (performanceTime.length > 0) {
                currentItem.lastReplyAt = this.parsePositiveNumber(performanceTime);
              }
            }
            postMetaSpanDepth++;
          }
          if (postAvatarDepth > 0 && token.name === 'img' && currentItem.authorAvatarUrl.length === 0) {
            currentItem.authorAvatarUrl = this.normalizeAssetUrl(token.attributes.get('src') ?? '');
          }
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
        const authorId = parseRouteId(href, '/user/');
        if (currentItem !== undefined && topicId > 0 && hasClass(token.attributes, 'post-title')) {
          anchorKind = 'topic';
          anchorId = topicId;
        } else if (currentItem !== undefined && authorId > 0) {
          anchorKind = 'author';
          anchorId = authorId;
        } else if (forumId > 0) {
          anchorKind = currentItem !== undefined ? 'item-forum' : 'forum';
          anchorId = forumId;
        } else if (href.startsWith('https://bbs1.org') || href.startsWith('https://www.bbs1.org')) {
          anchorKind = 'version';
        }
        return;
      }

      if (token.type === HtmlTokenType.TEXT) {
        if (anchorKind.length > 0) {
          anchorText += token.text;
        }
        if (currentItem !== undefined && postMetaDepth > 0 && postMetaSpanDepth > 0) {
          postMetaText += token.text;
        }
        return;
      }

      if (token.type === HtmlTokenType.END_TAG && token.name === 'a' && anchorKind.length > 0) {
        const text = collapseWhitespace(anchorText);
        if (anchorKind === 'topic' && currentItem !== undefined) {
          currentItem.topicId = anchorId;
          currentItem.title = text;
        } else if (anchorKind === 'author' && currentItem !== undefined) {
          currentItem.authorId = anchorId;
          if (text.length > 0) {
            currentItem.authorName = text;
          }
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

      if (token.type === HtmlTokenType.END_TAG && currentItem !== undefined) {
        if (token.name === 'span' && postMetaSpanDepth > 0) {
          postMetaSpanDepth--;
          if (postMetaSpanDepth === 0) {
            const text = collapseWhitespace(postMetaText);
            if (postMetaSpanIndex === 3) {
              currentItem.replyCount = this.parseCount(text);
            } else if (postMetaSpanIndex === 4) {
              currentItem.lastReplyUser = text;
            }
            postMetaText = '';
          }
        }
        if (token.name === 'div' && postMetaDepth > 0) {
          postMetaDepth--;
          if (postMetaDepth === 0) {
            postMetaSpanDepth = 0;
          }
        }
        if (token.name === 'div' && postAvatarDepth > 0) {
          postAvatarDepth--;
        }
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
        forumName: draft.forumName,
        authorId: draft.authorId,
        authorName: draft.authorName,
        authorAvatarUrl: draft.authorAvatarUrl,
        replyCount: draft.replyCount >= 0 ? draft.replyCount : undefined,
        lastReplyUser: draft.lastReplyUser,
        lastReplyAt: draft.lastReplyAt,
        isPinned: draft.isPinned,
        isFeatured: draft.isFeatured,
        isHot: draft.isHot,
        lotteryStatus: draft.lotteryStatus,
        cardStatus: draft.cardStatus
      });
    }
  }

  private captureStatus(token: HtmlToken, draft: HomeTopicDraft): void {
    if (hasClass(token.attributes, 'topic-badge') && hasClass(token.attributes, 'pinned')) {
      draft.isPinned = true;
    }
    if (hasClass(token.attributes, 'topic-stamp-hot')) {
      draft.isHot = true;
    }
    if (hasClass(token.attributes, 'topic-stamp-featured') || hasClass(token.attributes, 'topic-stamp-excellent')) {
      draft.isFeatured = true;
    }
    if (hasClass(token.attributes, 'community-lottery-title-status')) {
      draft.lotteryStatus = this.statusClass(token.attributes.get('class') ?? '', 'community-lottery-title-status');
    }
    if (hasClass(token.attributes, 'virtual-card-title-status')) {
      draft.cardStatus = this.statusClass(token.attributes.get('class') ?? '', 'virtual-card-title-status');
    }
  }

  private statusClass(classValue: string, baseClass: string): string {
    const parts = classValue.split(' ');
    for (let index = 0; index < parts.length; index++) {
      const value = parts[index].trim();
      if (value.length > 0 && value !== baseClass) {
        return value;
      }
    }
    return '';
  }

  private normalizeAssetUrl(value: string): string {
    if (value.startsWith('https://linux.sb/')) {
      return value;
    }
    if (value.startsWith('/')) {
      return `https://linux.sb${value}`;
    }
    return '';
  }

  private parseCount(value: string): number {
    let normalized = '';
    for (let index = 0; index < value.length; index++) {
      const current = value.charAt(index);
      if (current >= '0' && current <= '9') {
        normalized += current;
      } else if (current !== ',' && current !== ' ') {
        return -1;
      }
    }
    return normalized.length > 0 ? this.parsePositiveNumber(normalized) : -1;
  }

  private parsePositiveNumber(value: string): number {
    let result = 0;
    for (let index = 0; index < value.length; index++) {
      const current = value.charAt(index);
      if (current < '0' || current > '9') {
        return 0;
      }
      result = result * 10 + current.charCodeAt(0) - 48;
      if (result > 2147483647) {
        return 0;
      }
    }
    return result;
  }
}
