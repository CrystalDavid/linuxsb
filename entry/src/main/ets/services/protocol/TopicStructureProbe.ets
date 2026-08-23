import { HtmlToken, HtmlTokenType, LightweightHtmlTokenizer } from './LightweightHtmlTokenizer';
import { TopicStructureProbeResult } from './ProbeModels';
import { collapseWhitespace, extractBbsVersion, hasClass, parsePrefixedId, parseRouteId } from './HtmlProbeUtils';

export class TopicStructureProbe {
  scan(html: string): TopicStructureProbeResult {
    const result: TopicStructureProbeResult = {
      detectedBbsVersion: '',
      tokenCount: 0,
      startTagCount: 0,
      topicLinkCount: 0,
      userLinkCount: 0,
      replyReferenceLinkCount: 0,
      floorAnchorCount: 0,
      postIdPrefixCount: 0,
      replyIdPrefixCount: 0,
      dataFloorCount: 0,
      replyIdParameterCount: 0,
      knownPostEntryMarkerCount: 0,
      candidateReplyContainerCount: 0,
      paginationLinkCount: 0,
      loginVisibleMarkerCount: 0
    };
    let paginationDepth = 0;
    let anchorDepth = 0;
    let anchorText = '';
    let anchorHasFloorRoute = false;
    let anchorHasReplyReference = false;

    new LightweightHtmlTokenizer().scan(html, (token: HtmlToken) => {
      result.tokenCount++;
      if (token.type === HtmlTokenType.START_TAG) {
        result.startTagCount++;
        const startsPagination = hasClass(token.attributes, 'pagination') || hasClass(token.attributes, 'pagination-bar');
        if (startsPagination) {
          paginationDepth = paginationDepth > 0 ? paginationDepth + 1 : 1;
        } else if (paginationDepth > 0 && !token.selfClosing) {
          paginationDepth++;
        }

        if (result.detectedBbsVersion.length === 0 && token.name === 'link') {
          result.detectedBbsVersion = extractBbsVersion(token.attributes.get('href') ?? '');
        }

        const idValue = token.attributes.get('id') ?? '';
        const postId = parsePrefixedId(idValue, 'post-');
        const replyId = parsePrefixedId(idValue, 'reply-');
        const dataFloor = token.attributes.get('data-floor') ?? '';
        const hasDataFloor = dataFloor.length > 0;
        if (postId > 0) {
          result.postIdPrefixCount++;
        }
        if (replyId > 0) {
          result.replyIdPrefixCount++;
        }
        if (hasDataFloor) {
          result.dataFloorCount++;
        }
        if (hasClass(token.attributes, 'post-entry')) {
          result.knownPostEntryMarkerCount++;
        }
        if (this.isCandidateReplyContainer(token, postId, replyId, hasDataFloor)) {
          result.candidateReplyContainerCount++;
        }
        if (hasClass(token.attributes, 'replies-login-visible') || token.attributes.has('data-replies-login-visible')) {
          result.loginVisibleMarkerCount++;
        }

        if (token.name === 'a') {
          anchorDepth = 1;
          anchorText = '';
          const href = token.attributes.get('href') ?? '';
          const hasTopicRoute = parseRouteId(href, '/topic/') > 0;
          const hasUserRoute = parseRouteId(href, '/user/') > 0;
          const hasReplyId = this.hasQueryParameter(href, 'replyid');
          const hasFloor = this.hasQueryParameter(href, 'floor');
          const hasReplyFragment = this.hasReplyFragment(href);
          if (hasTopicRoute) {
            result.topicLinkCount++;
          }
          if (hasUserRoute) {
            result.userLinkCount++;
          }
          if (hasReplyId) {
            result.replyIdParameterCount++;
          }
          anchorHasFloorRoute = hasFloor || hasReplyId;
          anchorHasReplyReference = hasReplyId || hasFloor || hasReplyFragment || hasClass(token.attributes, 'quote-reply');
          if (anchorHasReplyReference) {
            result.replyReferenceLinkCount++;
          }
          if (paginationDepth > 0) {
            result.paginationLinkCount++;
          }
        } else if (anchorDepth > 0 && !token.selfClosing) {
          anchorDepth++;
        }
        return;
      }

      if (token.type === HtmlTokenType.TEXT) {
        if (anchorDepth > 0 && anchorText.length < 24) {
          anchorText += token.text.substring(0, 24 - anchorText.length);
        }
        return;
      }

      if (token.type !== HtmlTokenType.END_TAG) {
        return;
      }
      if (anchorDepth > 0) {
        anchorDepth--;
        if (anchorDepth === 0 && token.name === 'a') {
          if (anchorHasFloorRoute || this.isFloorLabel(collapseWhitespace(anchorText))) {
            result.floorAnchorCount++;
          }
          anchorText = '';
          anchorHasFloorRoute = false;
          anchorHasReplyReference = false;
        }
      }
      if (paginationDepth > 0) {
        paginationDepth--;
      }
    });
    return result;
  }

  private isCandidateReplyContainer(token: HtmlToken, postId: number, replyId: number, hasDataFloor: boolean): boolean {
    if (token.type !== HtmlTokenType.START_TAG) {
      return false;
    }
    const isContainer = token.name === 'li' || token.name === 'article' || token.name === 'section' || token.name === 'div';
    if (!isContainer) {
      return false;
    }
    if (replyId > 0 || hasDataFloor) {
      return true;
    }
    if (postId > 0 && hasClass(token.attributes, 'reply-entry')) {
      return true;
    }
    return hasClass(token.attributes, 'reply-item') || hasClass(token.attributes, 'comment-entry');
  }

  private hasQueryParameter(href: string, expectedName: string): boolean {
    const queryStart = href.indexOf('?');
    if (queryStart < 0) {
      return false;
    }
    let cursor = queryStart + 1;
    while (cursor < href.length) {
      const segmentEndCandidate = href.indexOf('&', cursor);
      const segmentEnd = segmentEndCandidate < 0 ? href.length : segmentEndCandidate;
      const equals = href.indexOf('=', cursor);
      const nameEnd = equals >= cursor && equals < segmentEnd ? equals : segmentEnd;
      if (href.substring(cursor, nameEnd) === expectedName) {
        return true;
      }
      if (segmentEnd >= href.length) {
        break;
      }
      cursor = segmentEnd + 1;
    }
    return false;
  }

  private hasReplyFragment(href: string): boolean {
    const fragment = href.indexOf('#');
    if (fragment < 0 || fragment + 1 >= href.length) {
      return false;
    }
    const value = href.substring(fragment + 1).toLowerCase();
    return value.startsWith('reply') || value.startsWith('post-');
  }

  private isFloorLabel(value: string): boolean {
    if (value.length < 2 || value.charAt(0) !== '#') {
      return false;
    }
    for (let index = 1; index < value.length; index++) {
      const current = value.charAt(index);
      if (current < '0' || current > '9') {
        return false;
      }
    }
    return true;
  }
}
