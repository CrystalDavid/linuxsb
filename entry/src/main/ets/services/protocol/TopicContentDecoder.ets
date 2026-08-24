import { HtmlToken, HtmlTokenType, LightweightHtmlTokenizer } from './LightweightHtmlTokenizer';
import { collapseWhitespace, hasClass, parseFirstUnsigned, parsePrefixedId } from './HtmlProbeUtils';
import {
  ProtocolContentBlock,
  ProtocolEditedMetadata,
  ProtocolPostDocument,
  ProtocolRewardExtension
} from './ProductProtocolModels';

const MAX_BLOCKS_PER_POST = 256;
const MAX_TEXT_PER_BLOCK = 8192;

class PostContentDraft {
  postId: number = 0;
  floor: number = 0;
  parentFloor: number = 0;
  author: string = '';
  authorId: number = 0;
  authorAvatarUrl: string = '';
  postedAtLabel: string = '';
  blocks: ProtocolContentBlock[] = [];
  unsupportedTags: Set<string> = new Set<string>();
  editedMetadata: ProtocolEditedMetadata | undefined = undefined;
  rewardExtension: ProtocolRewardExtension | undefined = undefined;
}

/** Streaming, depth-aware post decoder. BBS1 interaction chrome is never emitted as body text. */
export class TopicContentDecoder {
  decode(html: string): ProtocolPostDocument[] {
    const posts: ProtocolPostDocument[] = [];
    let treeDepth = 0;
    let currentPost: PostContentDraft | undefined = undefined;
    let postRootDepth = 0;
    let authorRootDepth = 0;
    let authorText = '';
    let postMetaRootDepth = 0;
    let postMetaSkipRootDepth = 0;
    let postMetaText = '';
    let postContentRootDepth = 0;
    let bodyRootDepth = 0;
    let skippedRootDepth = 0;
    let editedRootDepth = 0;
    let editedText = '';
    let editedLinkRootDepth = 0;
    let editedEditorText = '';
    let rewardRootDepth = 0;
    let rewardText = '';
    let rewardUrl = '';
    let pendingText = '';
    let captureKind = '';
    let captureTag = '';
    let captureRootDepth = 0;
    let captureText = '';
    let captureUrl = '';
    let captureHasEmbeddedImage = false;

    const flushPendingText = (): void => {
      if (currentPost === undefined) {
        pendingText = '';
        return;
      }
      const text = collapseWhitespace(pendingText);
      pendingText = '';
      if (text.length > 0) {
        this.addBlock(currentPost, 'Paragraph', text, '', '');
      }
    };

    const finishCapture = (): void => {
      if (currentPost === undefined || captureKind.length === 0) {
        captureKind = '';
        captureTag = '';
        captureRootDepth = 0;
        captureText = '';
        captureUrl = '';
        return;
      }
      const value = captureKind === 'CodeBlock' ? captureText.trim() : collapseWhitespace(captureText);
      if (value.length > 0 || (captureKind === 'Link' && captureUrl.length > 0 && !captureHasEmbeddedImage)) {
        this.addBlock(currentPost, captureKind, value, captureUrl, '');
      }
      captureKind = '';
      captureTag = '';
      captureRootDepth = 0;
      captureText = '';
      captureUrl = '';
      captureHasEmbeddedImage = false;
    };

    const finishEditedMetadata = (): void => {
      if (currentPost !== undefined) {
        const value = collapseWhitespace(editedText);
        if (value.length > 0) {
          const editedMarker = value.indexOf('编辑于');
          currentPost.editedMetadata = {
            editorName: collapseWhitespace(editedEditorText),
            editedAt: editedMarker >= 0 ? value.substring(editedMarker + 3).trim() : value
          };
        }
      }
      editedText = '';
      editedEditorText = '';
      editedLinkRootDepth = 0;
      editedRootDepth = 0;
    };

    const finishRewardExtension = (): void => {
      if (currentPost !== undefined) {
        let label = collapseWhitespace(rewardText);
        if (label.startsWith('$')) {
          label = label.substring(1).trim();
        }
        if (label.length > 0 || rewardUrl.length > 0) {
          currentPost.rewardExtension = { label: label.length > 0 ? label : '打赏', url: rewardUrl };
        }
      }
      rewardText = '';
      rewardUrl = '';
      rewardRootDepth = 0;
    };

    new LightweightHtmlTokenizer().scan(html, (token: HtmlToken) => {
      if (token.type === HtmlTokenType.START_TAG) {
        const structural = !token.selfClosing && !this.isVoidTag(token.name);
        if (structural) {
          treeDepth++;
        }

        if (currentPost === undefined) {
          if (token.name === 'li' && hasClass(token.attributes, 'post-entry')) {
            currentPost = new PostContentDraft();
            currentPost.postId = parsePrefixedId(token.attributes.get('id') ?? '', 'post-');
            currentPost.floor = parseFirstUnsigned(token.attributes.get('data-floor') ?? '');
            currentPost.parentFloor = parseFirstUnsigned(
              token.attributes.get('data-quote-threads-parent-floor') ?? ''
            );
            postRootDepth = treeDepth;
          }
          return;
        }

        if (token.name === 'a' && hasClass(token.attributes, 'post-author') && postContentRootDepth === 0) {
          authorRootDepth = treeDepth;
          authorText = '';
          currentPost.authorId = this.userIdFromUrl(token.attributes.get('href') ?? '');
          return;
        }
        if (token.name === 'img' && hasClass(token.attributes, 'avatar-img') && postContentRootDepth === 0 &&
          currentPost.authorAvatarUrl.length === 0) {
          currentPost.authorAvatarUrl = this.normalizeUrl(token.attributes.get('src') ?? '');
          return;
        }
        if (token.name === 'div' && hasClass(token.attributes, 'post-meta') && postContentRootDepth === 0) {
          postMetaRootDepth = treeDepth;
          postMetaText = '';
          return;
        }
        if (postMetaRootDepth > 0 && hasClass(token.attributes, 'quote-threads-reference')) {
          postMetaSkipRootDepth = treeDepth;
          return;
        }
        if (token.name === 'div' && hasClass(token.attributes, 'post-content') && postContentRootDepth === 0) {
          postContentRootDepth = treeDepth;
          pendingText = '';
          return;
        }
        if (this.isEditedMetadata(token)) {
          finishCapture();
          flushPendingText();
          editedRootDepth = treeDepth;
          editedText = '';
          editedEditorText = '';
          editedLinkRootDepth = 0;
          return;
        }
        if (this.isRewardExtension(token)) {
          finishCapture();
          flushPendingText();
          rewardRootDepth = treeDepth;
          rewardText = '';
          rewardUrl = '';
          return;
        }
        if (rewardRootDepth > 0) {
          if (token.name === 'a' && rewardUrl.length === 0) {
            rewardUrl = this.normalizeUrl(token.attributes.get('href') ?? '');
          }
          return;
        }
        if (editedRootDepth > 0) {
          if (token.name === 'a') {
            editedLinkRootDepth = treeDepth;
            editedEditorText = '';
          }
          return;
        }
        if (skippedRootDepth > 0) {
          return;
        }
        if (this.isInteractionChrome(token)) {
          finishCapture();
          flushPendingText();
          skippedRootDepth = treeDepth;
          return;
        }
        if (postContentRootDepth <= 0) {
          return;
        }
        if (token.name === 'div' && hasClass(token.attributes, 'long-content-fold-content')) {
          bodyRootDepth = treeDepth;
          return;
        }
        if (bodyRootDepth > 0 && treeDepth < bodyRootDepth) {
          return;
        }
        if (captureKind.length > 0) {
          if (token.name === 'img') {
            const source = this.imageSource(token.attributes);
            const description = collapseWhitespace(token.attributes.get('alt') ?? '');
            if (source.length > 0) {
              this.addBlock(currentPost, 'Image', '', source, description);
              captureHasEmbeddedImage = true;
            }
          } else if (token.name === 'br') {
            captureText += '\n';
          }
          return;
        }

        if (token.name === 'p') {
          flushPendingText();
        } else if (this.isHeadingTag(token.name)) {
          flushPendingText();
          captureKind = 'Heading';
          captureTag = token.name;
          captureRootDepth = treeDepth;
          captureText = '';
        } else if (token.name === 'br') {
          flushPendingText();
          this.addBlock(currentPost, 'LineBreak', '', '', '');
        } else if (token.name === 'a') {
          flushPendingText();
          captureKind = 'Link';
          captureTag = 'a';
          captureRootDepth = treeDepth;
          captureText = '';
          captureUrl = this.normalizeUrl(token.attributes.get('href') ?? '');
        } else if (token.name === 'blockquote') {
          flushPendingText();
          captureKind = 'Quote';
          captureTag = 'blockquote';
          captureRootDepth = treeDepth;
          captureText = '';
        } else if (token.name === 'pre') {
          flushPendingText();
          captureKind = 'CodeBlock';
          captureTag = 'pre';
          captureRootDepth = treeDepth;
          captureText = '';
        } else if (token.name === 'code') {
          flushPendingText();
          captureKind = 'InlineCode';
          captureTag = 'code';
          captureRootDepth = treeDepth;
          captureText = '';
        } else if (token.name === 'li') {
          flushPendingText();
          captureKind = 'ListItem';
          captureTag = 'li';
          captureRootDepth = treeDepth;
          captureText = '';
        } else if (token.name === 'img') {
          flushPendingText();
          const source = this.imageSource(token.attributes);
          const description = collapseWhitespace(token.attributes.get('alt') ?? '');
          if (source.length > 0) {
            this.addBlock(currentPost, 'Image', '', source, description);
          }
        } else if (this.isUnsupportedExtensionTag(token.name) && !currentPost.unsupportedTags.has(token.name)) {
          flushPendingText();
          currentPost.unsupportedTags.add(token.name);
          this.addBlock(currentPost, 'UnsupportedExtension', '', '', token.name);
        }
        return;
      }

      if (token.type === HtmlTokenType.TEXT) {
        if (currentPost === undefined) {
          return;
        }
        if (authorRootDepth > 0) {
          authorText += token.text;
        } else if (postMetaRootDepth > 0 && postMetaSkipRootDepth === 0) {
          postMetaText += token.text;
        } else if (editedRootDepth > 0) {
          editedText += token.text;
          if (editedLinkRootDepth > 0) {
            editedEditorText += token.text;
          }
        } else if (rewardRootDepth > 0) {
          rewardText += token.text;
        } else if (skippedRootDepth === 0 && postContentRootDepth > 0) {
          if (captureKind.length > 0) {
            if (captureText.length < MAX_TEXT_PER_BLOCK) {
              captureText += token.text.substring(0, MAX_TEXT_PER_BLOCK - captureText.length);
            }
          } else if (pendingText.length < MAX_TEXT_PER_BLOCK) {
            pendingText += token.text.substring(0, MAX_TEXT_PER_BLOCK - pendingText.length);
          }
        }
        return;
      }

      if (token.type !== HtmlTokenType.END_TAG || currentPost === undefined) {
        if (token.type === HtmlTokenType.END_TAG && treeDepth > 0) {
          treeDepth--;
        }
        return;
      }
      if (captureRootDepth > 0 && treeDepth === captureRootDepth && token.name === captureTag) {
        finishCapture();
      } else if (captureKind.length === 0 && token.name === 'p' && skippedRootDepth === 0 && editedRootDepth === 0) {
        flushPendingText();
      }
      if (authorRootDepth > 0 && treeDepth === authorRootDepth && token.name === 'a') {
        currentPost.author = collapseWhitespace(authorText);
        authorText = '';
        authorRootDepth = 0;
      }
      if (postMetaSkipRootDepth > 0 && treeDepth === postMetaSkipRootDepth) {
        postMetaSkipRootDepth = 0;
      }
      if (postMetaRootDepth > 0 && treeDepth === postMetaRootDepth && token.name === 'div') {
        currentPost.postedAtLabel = collapseWhitespace(postMetaText);
        postMetaText = '';
        postMetaRootDepth = 0;
      }
      if (editedLinkRootDepth > 0 && treeDepth === editedLinkRootDepth && token.name === 'a') {
        editedLinkRootDepth = 0;
      }
      if (editedRootDepth > 0 && treeDepth === editedRootDepth) {
        finishEditedMetadata();
      }
      if (rewardRootDepth > 0 && treeDepth === rewardRootDepth) {
        finishRewardExtension();
      }
      if (skippedRootDepth > 0 && treeDepth === skippedRootDepth) {
        skippedRootDepth = 0;
      }
      if (bodyRootDepth > 0 && treeDepth === bodyRootDepth) {
        finishCapture();
        flushPendingText();
        bodyRootDepth = 0;
      }
      if (postContentRootDepth > 0 && treeDepth === postContentRootDepth) {
        finishCapture();
        flushPendingText();
        postContentRootDepth = 0;
      }
      if (postRootDepth > 0 && treeDepth === postRootDepth && token.name === 'li') {
        finishCapture();
        flushPendingText();
        this.finalizePost(currentPost, posts);
        currentPost = undefined;
        postRootDepth = 0;
        authorRootDepth = 0;
        postMetaRootDepth = 0;
        postMetaSkipRootDepth = 0;
        postContentRootDepth = 0;
        bodyRootDepth = 0;
        skippedRootDepth = 0;
        editedRootDepth = 0;
        rewardRootDepth = 0;
      }
      if (treeDepth > 0) {
        treeDepth--;
      }
    });

    if (currentPost !== undefined) {
      finishCapture();
      flushPendingText();
      this.finalizePost(currentPost, posts);
    }
    return posts;
  }

  private addBlock(post: PostContentDraft, kind: string, text: string, url: string, description: string): void {
    if (post.blocks.length >= MAX_BLOCKS_PER_POST) {
      return;
    }
    post.blocks.push({ kind: kind, text: text, url: url, description: description });
  }

  private finalizePost(post: PostContentDraft, posts: ProtocolPostDocument[]): void {
    if (post.postId <= 0) {
      return;
    }
    posts.push({
      postId: post.postId,
      floor: post.floor,
      parentFloor: post.parentFloor > 0 ? post.parentFloor : undefined,
      author: post.author,
      authorId: post.authorId,
      authorAvatarUrl: post.authorAvatarUrl,
      postedAtLabel: post.postedAtLabel,
      blocks: post.blocks,
      editedMetadata: post.editedMetadata,
      rewardExtension: post.rewardExtension
    });
  }

  private isEditedMetadata(token: HtmlToken): boolean {
    return hasClass(token.attributes, 'post-edit-meta') || hasClass(token.attributes, 'post-edited') ||
      hasClass(token.attributes, 'edited-metadata') || hasClass(token.attributes, 'post-edit-history') ||
      hasClass(token.attributes, 'sb-limit-edit-time-note') || token.attributes.has('data-post-edited');
  }

  private isRewardExtension(token: HtmlToken): boolean {
    return hasClass(token.attributes, 'donate-area') || token.attributes.has('data-donate-area');
  }

  private isInteractionChrome(token: HtmlToken): boolean {
    return hasClass(token.attributes, 'long-content-fold-actions') ||
      hasClass(token.attributes, 'long-content-fold-toggle') ||
      token.attributes.has('data-long-content-fold-actions') ||
      token.attributes.has('data-long-content-fold-toggle') ||
      token.attributes.has('data-long-content-fold-label') ||
      hasClass(token.attributes, 'quick-reply-main-action') ||
      hasClass(token.attributes, 'post-ops') ||
      hasClass(token.attributes, 'reply-panel') ||
      hasClass(token.attributes, 'replies-login-visible');
  }

  private isHeadingTag(name: string): boolean {
    return name === 'h1' || name === 'h2' || name === 'h3' || name === 'h4' || name === 'h5' || name === 'h6';
  }

  private normalizeUrl(value: string): string {
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return `https:${value}`;
    }
    if (value.startsWith('/')) {
      return `https://linux.sb${value}`;
    }
    return value;
  }

  private imageSource(attributes: Map<string, string>): string {
    const candidates = ['data-src', 'data-original', 'data-lazy-src', 'data-url', 'src'];
    for (let index = 0; index < candidates.length; index++) {
      const value = (attributes.get(candidates[index]) ?? '').trim();
      if (value.length > 0 && !value.startsWith('data:image/gif;base64,R0lGODlhAQABA')) {
        return this.normalizeUrl(value);
      }
    }
    const srcset = (attributes.get('srcset') ?? '').trim();
    if (srcset.length === 0) {
      return '';
    }
    const firstCandidateEnd = srcset.indexOf(',');
    const firstCandidate = (firstCandidateEnd >= 0 ? srcset.substring(0, firstCandidateEnd) : srcset).trim();
    const descriptorStart = firstCandidate.indexOf(' ');
    return this.normalizeUrl((descriptorStart >= 0 ? firstCandidate.substring(0, descriptorStart) : firstCandidate).trim());
  }

  private userIdFromUrl(value: string): number {
    const marker = '/user/';
    const markerIndex = value.indexOf(marker);
    return markerIndex < 0 ? 0 : parseFirstUnsigned(value.substring(markerIndex + marker.length));
  }

  private isUnsupportedExtensionTag(name: string): boolean {
    return name.indexOf('-') > 0 && name !== 'post-content';
  }

  private isVoidTag(name: string): boolean {
    return name === 'br' || name === 'img' || name === 'hr' || name === 'input' || name === 'meta' ||
      name === 'link' || name === 'source' || name === 'track' || name === 'wbr';
  }
}
