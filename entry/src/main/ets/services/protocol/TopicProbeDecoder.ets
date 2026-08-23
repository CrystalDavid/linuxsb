import { HtmlToken, HtmlTokenType, LightweightHtmlTokenizer } from './LightweightHtmlTokenizer';
import { ReplyProbeSummary, TopicProbeResult } from './ProbeModels';
import { collapseWhitespace, hasClass, parseFirstUnsigned, parsePrefixedId } from './HtmlProbeUtils';

class PostDraft {
  postId: number = 0;
  floor: number = 0;
}

export class TopicProbeDecoder {
  decode(html: string, expectedTopicId: number = 0): TopicProbeResult {
    const warnings: string[] = [];
    const replies: ReplyProbeSummary[] = [];
    const statValues: number[] = [];
    let title = '';
    let titleDepth = 0;
    let titleText = '';
    let statsDepth = 0;
    let statSpanDepth = 0;
    let statText = '';
    let floorDepth = 0;
    let floorText = '';
    let currentPost: PostDraft | undefined = undefined;
    let mainPostId = 0;

    new LightweightHtmlTokenizer().scan(html, (token: HtmlToken) => {
      if (token.type === HtmlTokenType.START_TAG) {
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

        if (token.name === 'li' && hasClass(token.attributes, 'post-entry')) {
          this.finalizePost(currentPost, replies, warnings, mainPostId);
          currentPost = new PostDraft();
          currentPost.postId = parsePrefixedId(token.attributes.get('id') ?? '', 'post-');
          currentPost.floor = parseFirstUnsigned(token.attributes.get('data-floor') ?? '');
          if (mainPostId === 0 && currentPost.postId > 0) {
            mainPostId = currentPost.postId;
          }
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
        return;
      }

      if (token.type !== HtmlTokenType.END_TAG) {
        return;
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
      if (token.name === 'li' && currentPost !== undefined) {
        this.finalizePost(currentPost, replies, warnings, mainPostId);
        currentPost = undefined;
      }
    });

    this.finalizePost(currentPost, replies, warnings, mainPostId);
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
      warnings.push(`REPLIES_NOT_PRESENT_IN_RESPONSE:${advertisedReplyCount - replies.length}`);
    }
    return {
      protocolMatched: title.length > 0 && mainPostId > 0 && (expectedTopicId <= 0 || expectedTopicId === mainPostId),
      title: title,
      viewCount: viewCount,
      advertisedReplyCount: advertisedReplyCount,
      mainPostId: mainPostId,
      replies: replies,
      warnings: warnings
    };
  }

  private finalizePost(post: PostDraft | undefined, replies: ReplyProbeSummary[], warnings: string[], mainPostId: number): void {
    if (post === undefined || post.postId <= 0 || post.postId === mainPostId) {
      return;
    }
    if (post.floor <= 0) {
      warnings.push(`REPLY_FLOOR_MISSING:${post.postId}`);
    }
    replies.push({ replyId: post.postId, floor: post.floor });
  }
}
