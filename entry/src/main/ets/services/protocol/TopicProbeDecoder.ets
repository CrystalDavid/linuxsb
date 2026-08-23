import { HtmlToken, HtmlTokenType, LightweightHtmlTokenizer } from './LightweightHtmlTokenizer';
import { ReplyProbeSummary, TopicProbeResult } from './ProbeModels';
import { collapseWhitespace, hasClass, parseFirstUnsigned, parsePrefixedId } from './HtmlProbeUtils';

class PostDraft {
  postId: number = 0;
  floor: number = 0;
  author: string = '';
  bodyText: string = '';
}

export class TopicProbeDecoder {
  decode(html: string, expectedTopicId: number = 0): TopicProbeResult {
    const warnings: string[] = [];
    const replies: ReplyProbeSummary[] = [];
    const replyIds = new Set<number>();
    const statValues: number[] = [];
    let title = '';
    let titleDepth = 0;
    let titleText = '';
    let statsDepth = 0;
    let statSpanDepth = 0;
    let statText = '';
    let floorDepth = 0;
    let floorText = '';
    let authorDepth = 0;
    let authorText = '';
    let contentDepth = 0;
    let contentText = '';
    let postListItemDepth = 0;
    let loginVisibleMarkerCount = 0;
    let currentPost: PostDraft | undefined = undefined;
    let mainPostId = 0;
    let paginationDepth = 0;
    let paginationActiveItemDepth = 0;
    let paginationAnchorDepth = 0;
    let paginationAnchorText = '';
    let paginationAnchorUrl = '';
    let paginationAnchorIsActive = false;
    let currentPage = 1;
    let totalPages = 1;
    let nextPageUrl = '';

    new LightweightHtmlTokenizer().scan(html, (token: HtmlToken) => {
      if (token.type === HtmlTokenType.START_TAG) {
        if (paginationDepth > 0 && !token.selfClosing && !this.isVoidTag(token.name)) {
          paginationDepth++;
        } else if (token.name === 'div' && hasClass(token.attributes, 'pagination')) {
          paginationDepth = 1;
        }
        if (paginationDepth > 0) {
          if (paginationActiveItemDepth > 0 && !token.selfClosing && !this.isVoidTag(token.name)) {
            paginationActiveItemDepth++;
          } else if (token.name === 'li' && hasClass(token.attributes, 'active')) {
            paginationActiveItemDepth = 1;
          }
          if (paginationAnchorDepth > 0 && !token.selfClosing && !this.isVoidTag(token.name)) {
            paginationAnchorDepth++;
          } else if (token.name === 'a') {
            paginationAnchorDepth = 1;
            paginationAnchorText = '';
            paginationAnchorUrl = this.normalizeTopicPageUrl(token.attributes.get('href') ?? '', expectedTopicId);
            paginationAnchorIsActive = paginationActiveItemDepth > 0;
          }
        }
        if (token.name === 'h1' && hasClass(token.attributes, 'post-content-title')) {
          titleDepth = 1;
          titleText = '';
        } else if (titleDepth > 0) {
          titleDepth++;
        }

        if (token.name === 'div' && hasClass(token.attributes, 'post-content-stats')) {
          statsDepth = 1;
        } else if (statsDepth > 0 && token.name === 'div') {
          statsDepth++;
        }
        if (statsDepth > 0 && token.name === 'span' && statSpanDepth === 0) {
          statSpanDepth = 1;
          statText = '';
        } else if (statSpanDepth > 0 && token.name === 'span') {
          statSpanDepth++;
        }

        if (hasClass(token.attributes, 'replies-login-visible') || token.attributes.has('data-replies-login-visible')) {
          loginVisibleMarkerCount++;
        }

        if (token.name === 'li' && hasClass(token.attributes, 'post-entry') && currentPost === undefined) {
          currentPost = new PostDraft();
          postListItemDepth = 1;
          currentPost.postId = parsePrefixedId(token.attributes.get('id') ?? '', 'post-');
          currentPost.floor = parseFirstUnsigned(token.attributes.get('data-floor') ?? '');
          if (mainPostId === 0 && currentPost.postId > 0) {
            mainPostId = currentPost.floor > 0 && expectedTopicId > 0 ? expectedTopicId : currentPost.postId;
          }
        } else if (currentPost !== undefined && token.name === 'li' && !token.selfClosing) {
          postListItemDepth++;
        }
        if (currentPost !== undefined && token.name === 'a' && hasClass(token.attributes, 'post-author')) {
          authorDepth = 1;
          authorText = '';
        }
        if (currentPost !== undefined && token.name === 'div' && hasClass(token.attributes, 'post-content') && contentDepth === 0) {
          contentDepth = 1;
          contentText = '';
        } else if (contentDepth > 0 && token.name === 'div') {
          contentDepth++;
        }
        if (currentPost !== undefined && (hasClass(token.attributes, 'post-floor') || hasClass(token.attributes, 'post-number'))) {
          floorDepth = 1;
          floorText = '';
        } else if (floorDepth > 0) {
          floorDepth++;
        }
        return;
      }

      if (token.type === HtmlTokenType.TEXT) {
        if (titleDepth > 0) {
          titleText += token.text;
        }
        if (statSpanDepth > 0) {
          statText += token.text;
        }
        if (floorDepth > 0) {
          floorText += token.text;
        }
        if (authorDepth > 0) {
          authorText += token.text;
        }
        if (contentDepth > 0 && contentText.length < 512) {
          contentText += token.text.substring(0, 512 - contentText.length);
        }
        if (paginationAnchorDepth > 0) {
          paginationAnchorText += token.text;
        }
        return;
      }

      if (token.type !== HtmlTokenType.END_TAG) {
        return;
      }
      if (paginationAnchorDepth > 0) {
        paginationAnchorDepth--;
        if (paginationAnchorDepth === 0 && token.name === 'a') {
          const label = collapseWhitespace(paginationAnchorText);
          const page = this.pageFromUrl(paginationAnchorUrl);
          if (page > totalPages) {
            totalPages = page;
          }
          if (paginationAnchorIsActive && page > 0) {
            currentPage = page;
          }
          if (label === '下一页' && paginationAnchorUrl.length > 0) {
            nextPageUrl = paginationAnchorUrl;
          }
          paginationAnchorText = '';
          paginationAnchorUrl = '';
          paginationAnchorIsActive = false;
        }
      }
      if (paginationActiveItemDepth > 0) {
        paginationActiveItemDepth--;
      }
      if (paginationDepth > 0) {
        paginationDepth--;
      }
      if (titleDepth > 0) {
        titleDepth--;
        if (titleDepth === 0 && token.name === 'h1') {
          title = collapseWhitespace(titleText);
        }
      }
      if (statSpanDepth > 0 && token.name === 'span') {
        statSpanDepth--;
        if (statSpanDepth === 0) {
          statValues.push(parseFirstUnsigned(collapseWhitespace(statText)));
        }
      }
      if (statsDepth > 0 && token.name === 'div') {
        statsDepth--;
      }
      if (floorDepth > 0) {
        floorDepth--;
        if (floorDepth === 0 && currentPost !== undefined) {
          currentPost.floor = parseFirstUnsigned(collapseWhitespace(floorText));
        }
      }
      if (authorDepth > 0 && token.name === 'a') {
        authorDepth = 0;
        if (currentPost !== undefined) {
          currentPost.author = collapseWhitespace(authorText);
        }
      }
      if (contentDepth > 0 && token.name === 'div') {
        contentDepth--;
        if (contentDepth === 0 && currentPost !== undefined) {
          currentPost.bodyText = collapseWhitespace(contentText);
        }
      }
      if (token.name === 'li' && currentPost !== undefined) {
        postListItemDepth--;
        if (postListItemDepth === 0) {
          this.finalizePost(currentPost, replies, replyIds, warnings, mainPostId);
          currentPost = undefined;
          authorDepth = 0;
          contentDepth = 0;
        }
      }
    });

    this.finalizePost(currentPost, replies, replyIds, warnings, mainPostId);
    const viewCount = statValues.length > 0 ? statValues[0] : 0;
    const advertisedReplyCount = statValues.length > 1 ? statValues[1] : replies.length;
    if (title.length === 0) {
      warnings.push('TOPIC_TITLE_MISSING');
    }
    if (mainPostId <= 0) {
      warnings.push('MAIN_POST_ID_MISSING');
    }
    if (expectedTopicId > 0 && mainPostId > 0 && expectedTopicId !== mainPostId) {
      warnings.push(`TOPIC_ID_MISMATCH:${expectedTopicId}:${mainPostId}`);
    }
    if (advertisedReplyCount > replies.length) {
      if (replies.length === 0 && loginVisibleMarkerCount > 0) {
        warnings.push(`REPLIES_NOT_PRESENT_IN_RESPONSE:${advertisedReplyCount}`);
        warnings.push(`REPLIES_LOGIN_GATED:${advertisedReplyCount}`);
      } else if (totalPages > 1 || nextPageUrl.length > 0 || currentPage > 1) {
        warnings.push(`REPLIES_PAGED:${replies.length}:${advertisedReplyCount}`);
      } else if (replies.length === 0) {
        warnings.push(`REPLIES_NOT_PRESENT_IN_RESPONSE:${advertisedReplyCount}`);
        warnings.push('REPLY_STRUCTURE_MISMATCH');
      } else {
        warnings.push(`REPLIES_NOT_PRESENT_IN_RESPONSE:${advertisedReplyCount - replies.length}`);
        warnings.push('REPLY_STRUCTURE_MISMATCH');
      }
    } else if (advertisedReplyCount < replies.length) {
      warnings.push(`REPLY_COUNT_MISMATCH:${advertisedReplyCount}:${replies.length}`);
    }
    return {
      protocolMatched: title.length > 0 && mainPostId > 0 && (expectedTopicId <= 0 || expectedTopicId === mainPostId),
      title: title,
      viewCount: viewCount,
      advertisedReplyCount: advertisedReplyCount,
      mainPostId: mainPostId,
      replies: replies,
      currentPage: currentPage,
      pageReplyCount: replies.length,
      totalPages: totalPages,
      nextPageUrl: nextPageUrl,
      loginVisibleMarkerCount: loginVisibleMarkerCount,
      warnings: warnings
    };
  }

  private normalizeTopicPageUrl(value: string, expectedTopicId: number): string {
    if (value.length === 0 || expectedTopicId <= 0) {
      return '';
    }
    const relativePrefix = `/topic/${expectedTopicId}`;
    const absolutePrefix = `https://linux.sb${relativePrefix}`;
    if (value === relativePrefix || value.startsWith(`${relativePrefix}?`)) {
      return `https://linux.sb${value}`;
    }
    if (value === absolutePrefix || value.startsWith(`${absolutePrefix}?`)) {
      return value;
    }
    return '';
  }

  private pageFromUrl(value: string): number {
    const marker = 'p=';
    const markerIndex = value.indexOf(marker);
    if (markerIndex < 0) {
      return 1;
    }
    return parseFirstUnsigned(value.substring(markerIndex + marker.length));
  }

  private isVoidTag(name: string): boolean {
    return name === 'br' || name === 'img' || name === 'hr' || name === 'input' || name === 'meta' ||
      name === 'link' || name === 'source' || name === 'track' || name === 'wbr';
  }

  private finalizePost(post: PostDraft | undefined, replies: ReplyProbeSummary[], replyIds: Set<number>, warnings: string[], mainPostId: number): void {
    if (post === undefined || post.postId <= 0 || post.postId === mainPostId) {
      return;
    }
    if (replyIds.has(post.postId)) {
      warnings.push(`DUPLICATE_REPLY_ID:${post.postId}`);
      return;
    }
    if (post.floor <= 0) {
      warnings.push(`REPLY_FLOOR_MISSING:${post.postId}`);
    }
    if (post.author.length === 0) {
      warnings.push(`REPLY_AUTHOR_MISSING:${post.postId}`);
    }
    if (post.bodyText.length === 0) {
      warnings.push(`REPLY_BODY_MISSING:${post.postId}`);
    }
    replyIds.add(post.postId);
    replies.push({ replyId: post.postId, floor: post.floor, author: post.author, bodyText: post.bodyText });
  }
}
